#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# zram-dict-setup.sh — zstd dictionary를 사용하는 zram 스왑 초기화 예제
#
# 대상: Tizen on BCM2711 (ARMv7 32bit, RAM 1.5GB)
# 커널: 6.12+ (algorithm_params sysfs 지원 필요)
#
# 의존성:
#   - CONFIG_ZRAM=y
#   - CONFIG_ZRAM_BACKEND_ZSTD=y
#   - CONFIG_ZRAM_DEF_COMP_ZSTD=y (or set comp_algorithm manually)
#
# 실행 순서 (중요):
#   comp_algorithm → algorithm_params → disksize → mkswap → swapon
#   disksize 설정 후에는 comp_algorithm, algorithm_params 변경 불가 (EBUSY)
#
# ===========================================================================

set -e

ZRAM_DEV="/dev/zram0"
ZRAM_SYS="/sys/block/zram0"

# ARMv7 1.5GB RAM 기준: 스왑 크기 = RAM의 50~67%
# zstd+dict 압축률 ~3.5:1 가정 시 실제 점유 메모리 ≈ 286MB
ZRAM_SIZE="1G"

# 딕셔너리 파일 경로 (rootfs에 포함, 부팅 초기 접근 가능해야 함)
DICT_PATH="/etc/zram/zstd.dict"

# zstd 압축 레벨 (1~22, zram 기본=3)
# ARMv7에서 레벨 1: ~압축률 3.0:1, 지연 ~10us
# ARMv7에서 레벨 3: ~압축률 3.5:1, 지연 ~25us  ← 권장
# 레벨 5 이상은 스왑 I/O 레이턴시 증가로 비권장
ZSTD_LEVEL=3

# ===========================================================================
# 사전 조건 확인
# ===========================================================================

if [ ! -b "$ZRAM_DEV" ]; then
    echo "zram: $ZRAM_DEV not found, loading module..."
    modprobe zram num_devices=1 || { echo "zram: modprobe failed"; exit 1; }
fi

if [ ! -f "$DICT_PATH" ]; then
    echo "zram: dictionary not found at $DICT_PATH, using no-dict mode"
    DICT_PATH=""
fi

# ===========================================================================
# Step 1: 압축 알고리즘 설정
# 반드시 disksize 설정 전에 해야 함
# ===========================================================================

echo "zstd" > "${ZRAM_SYS}/comp_algorithm"
echo "zram: comp_algorithm set to zstd"

# ===========================================================================
# Step 2: algorithm_params — 딕셔너리 + 레벨 설정
# 반드시 disksize 설정 전에 해야 함
#
# 파라미터 형식: "key=value key=value ..."
#   algo=NAME      : 알고리즘 이름으로 우선순위 자동 선택
#   priority=N     : 우선순위 직접 지정 (0=primary, 1~3=secondary)
#   level=N        : 압축 레벨
#   dict=/path     : 딕셔너리 파일 경로 (커널이 직접 읽음, GFP_KERNEL)
#
# 주의(ARMv7): kernel_read_file_from_path()는 vmalloc으로 dict 버퍼를
#   할당하므로 HIGHMEM 영역 주의. 4K 정렬 보장됨.
# ===========================================================================

if [ -n "$DICT_PATH" ]; then
    printf "algo=zstd level=%d dict=%s" "$ZSTD_LEVEL" "$DICT_PATH" \
        > "${ZRAM_SYS}/algorithm_params"
    echo "zram: algorithm_params set (level=${ZSTD_LEVEL}, dict=${DICT_PATH})"
else
    printf "algo=zstd level=%d" "$ZSTD_LEVEL" \
        > "${ZRAM_SYS}/algorithm_params"
    echo "zram: algorithm_params set (level=${ZSTD_LEVEL}, no dict)"
fi

# ===========================================================================
# Step 3: 디스크 크기 설정 — 이 시점부터 알고리즘 변경 불가
# ===========================================================================

echo "$ZRAM_SIZE" > "${ZRAM_SYS}/disksize"
echo "zram: disksize set to ${ZRAM_SIZE}"

# ===========================================================================
# Step 4: 스왑 초기화 및 활성화
# ARMv7 note: mkswap은 userspace, swapd는 커널 kswapd 스레드 사용
# ===========================================================================

mkswap "$ZRAM_DEV"
# 우선순위 100: 일반 디스크 스왑(-1~0)보다 높게, 항상 먼저 사용
swapon -p 100 "$ZRAM_DEV"
echo "zram: swap activated on ${ZRAM_DEV} (priority=100)"

# ===========================================================================
# 검증 (선택)
# ===========================================================================

echo "=== zram status ==="
cat "${ZRAM_SYS}/mm_stat"
# 출력 형식:
# orig_data_size compr_data_size mem_used_total mem_limit mem_used_max \
#   same_pages pages_compacted huge_pages huge_pages_since
# compr / orig 비율로 실제 압축률 확인 가능

# ===========================================================================
# 딕셔너리 학습 방법 (오프라인, 별도 실행)
# ===========================================================================
#
# 1. 타겟 시스템에서 대표 페이지 샘플 수집:
#
#    mkdir -p /tmp/zram-samples
#    # zram이 swap으로 활성화된 상태에서 충분히 사용 후:
#    # /dev/zram0에서 raw 압축 데이터 직접 학습은 불가 (압축 포맷)
#    # 대신 /proc/$pid/mem에서 실제 익명 페이지를 샘플링:
#    for pid in $(ls /proc | grep -E '^[0-9]+$' | head -50); do
#        dd if=/proc/$pid/mem bs=4096 count=4 skip=128 \
#           of=/tmp/zram-samples/${pid}.bin 2>/dev/null || true
#    done
#
# 2. 샘플을 4K 단위 청크로 분리:
#
#    cd /tmp/zram-samples
#    for f in *.bin; do
#        split -b 4096 "$f" "chunk_${f%.bin}_"
#    done
#    ls chunk_* | wc -l   # 최소 500개 이상 권장
#
# 3. zstd 딕셔너리 학습 (호스트에서, zstd 1.4+ 필요):
#
#    zstd --train /tmp/zram-samples/chunk_* \
#         --maxdict=112640 \
#         -o /tmp/zstd.dict
#    # --maxdict=110KB: zstd 내부 최적 크기 (112640 = 110*1024)
#    # 결과 파일 크기는 보통 64~112KB
#
# 4. 딕셔너리를 타겟 rootfs에 포함:
#
#    install -D -m 644 /tmp/zstd.dict ${ROOTFS}/etc/zram/zstd.dict
#
# ===========================================================================
