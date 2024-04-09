# See LICENSE for license details.

#*****************************************************************************
# page_ma_access.S
#-----------------------------------------------------------------------------
#
# test that accesses on page boundaries actually access
# two adjecent pages in virtual, not physical memory
#

#include "riscv_test.h"
#include "test_macros.h"

#define PAGE_MA_ACCESS_TESTCASE(test_num, misalignement) \
test_##test_num: \
  li TESTNUM, test_num; \
  la s11, 1f; \
  li a0, misalignement; \
  li t0, 0x200000; \
  csrw mepc, t0; \
  mret; \

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 2

  # set up intermediate page tables

  la t0, page_table_3
  srl t0, t0, RISCV_PGSHIFT - PTE_PPN_SHIFT
  ori t0, t0, PTE_V
  sd t0, page_table_2 + 8, t1

  la t0, page_table_2
  srl t0, t0, RISCV_PGSHIFT - PTE_PPN_SHIFT
  ori t0, t0, PTE_V
  sd t0, page_table_1, t1

  # set up leaf mappings
  # virtual data pages 0,1,2 are mapped into physical pages 0,2,1

  la t0, code_page
  srl t0, t0, RISCV_PGSHIFT - PTE_PPN_SHIFT
  ori t0, t0, PTE_V | PTE_X | PTE_A
  sd t0, page_table_3, t1

  la t0, data_page_0
  srl t0, t0, RISCV_PGSHIFT - PTE_PPN_SHIFT
  ori t0, t0, PTE_V | PTE_R | PTE_W | PTE_A
  sd t0, page_table_3 + 8, t1

  la t0, data_page_2
  srl t0, t0, RISCV_PGSHIFT - PTE_PPN_SHIFT
  ori t0, t0, PTE_V | PTE_R | PTE_W | PTE_A
  sd t0, page_table_3 + 0x10, t1

  la t0, data_page_1
  srl t0, t0, RISCV_PGSHIFT - PTE_PPN_SHIFT
  ori t0, t0, PTE_V | PTE_R | PTE_W | PTE_A
  sd t0, page_table_3 + 0x18, t1

  # Turn on VM

  li a0, (SATP_MODE & ~(SATP_MODE<<1)) * SATP_MODE_SV39
  la a1, page_table_1
  srl a1, a1, RISCV_PGSHIFT
  or a1, a1, a0
  csrw sptbr, a1
  sfence.vma

  # Enter supervisor mode and make sure correct page is accessed
  li a1, ((MSTATUS_MPP & ~(MSTATUS_MPP<<1)) * PRV_S)
  csrs mstatus, a1

PAGE_MA_ACCESS_TESTCASE(2, 1)
  .align 2
1:
PAGE_MA_ACCESS_TESTCASE(3, 2)
  .align 2
1:
PAGE_MA_ACCESS_TESTCASE(4, 3)
  .align 2
1:
PAGE_MA_ACCESS_TESTCASE(5, 4)
  .align 2
1:
PAGE_MA_ACCESS_TESTCASE(6, 5)
  .align 2
1:
PAGE_MA_ACCESS_TESTCASE(7, 6)
  .align 2
1:
PAGE_MA_ACCESS_TESTCASE(8, 7)

  .align 2
1:
  RVTEST_PASS

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  # exception on misaligned load/store: allowed, pass
  csrr t0, mcause
  li t1, CAUSE_MISALIGNED_LOAD
  beq t0, t1, pass
  li t1, CAUSE_MISALIGNED_STORE
  beq t0, t1, pass

  li t1, CAUSE_BREAKPOINT
  bne t0, t1, fail

  bnez a0, fail # test was a failure

  jr s11

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

.align 12
page_table_1: .dword 0
.align 12
page_table_2: .dword 0
.align 12
page_table_3: .dword 0
.align 12
data_page_0: .dword 0
.align 12
data_page_1: .dword 0
.align 12
data_page_2: .dword 0
.align 12
code_page:
  # a0 - "misalignment" in bytes
#define DP0_ADDR 0x201000
#define DP1_ADDR 0x202000
#define DP2_ADDR 0x203000

#define LAST_PAGE_VAL 0xffffffffffffffff
#define MISALIGNED_VAL 0x0102030405060708

  li t0, DP1_ADDR
  sub t0, t0, a0 # t0 - load-store address (on a page boundary)

  # canary in page that shouldn't be touched by misaligned
  li t1, LAST_PAGE_VAL
  li t2, DP2_ADDR
  sd t1, 0(t2)

  # do a misaligned store
  li t1, MISALIGNED_VAL
  sd t1, 0(t0)

  # canary shouldn't be touched
  ld t1, 0(t2)
  li t3, LAST_PAGE_VAL
  sub t1, t1, t3
  bnez t1, s_fail

  # store in the last page again: shouldn't have any bearing on subsequent misaligned load
  li t1, LAST_PAGE_VAL
  li t2, DP2_ADDR
  sd t1, 0(t2)

  # misaligned load should succeed
  ld t1, 0(t0)
  li t2, MISALIGNED_VAL
  sub t1, t1, t2
  bnez t1, s_fail

  j s_pass

s_fail:
  li a0, 1 # return: fail
  sbreak
s_pass:
  li a0, 0 # return: pass
  sbreak

RVTEST_DATA_END
