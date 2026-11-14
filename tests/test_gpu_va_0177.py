"""0177: the GPU address-space allocator (first/best fit, spesgpu_va_mb up to 960 MiB, refusal
counters) of the backend as patches 0001-0177 leave it, with mocked hardware."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
PATCHES = sorted((ROOT / 'xnu/patches').glob('0*.patch'))
prefix = r'''
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
typedef uintptr_t vm_offset_t;
typedef size_t vm_size_t;
typedef uintptr_t addr64_t;
typedef uint64_t vm_map_address_t;
#define PAGE_SIZE 16384
#define PAGE_MASK 16383
#define KMA_DATA 1
#define KMA_ZERO 2
#define KMA_PERMANENT 4
#define VM_KERN_MEMORY_IOKIT 1
#define KERN_SUCCESS 0
static int kernel_map, kernel_pmap;
static unsigned allocs, starts;
static int kmem_alloc_contig(int k,vm_offset_t *p,size_t n,unsigned mask,int a,int b,int f,int tag){
 (void)k;(void)mask;(void)a;(void)b;(void)f;(void)tag;*p=(uintptr_t)calloc(1,n);++allocs;return *p?0:1;}
static uint64_t pmap_find_phys(int p,addr64_t v){(void)p;(void)v;return (0x100000000ULL+allocs*16384)>>14;}
#define ptoa_64(p) ((p)<<14)
static void to_memory(vm_offset_t p,vm_size_t n){(void)p;(void)n;}
static bool spes_gpu_tlb_sync(vm_offset_t s,uint32_t c){(void)s;(void)c;return true;}
static void touch_wr(vm_offset_t g,uint32_t r,uint32_t v){(void)g;(void)r;(void)v;}
static uint32_t touch_rd(vm_offset_t g,uint32_t r){(void)g;(void)r;return 0;}
static void delay(int us){(void)us;}
static uint64_t mach_absolute_time(void){return 0;}
static int spes_rpm_kvp(int a,uint32_t b,int c,uint32_t d,uint32_t e){(void)a;(void)b;(void)c;(void)d;(void)e;return 0;}
vm_map_address_t phystokv(uint64_t pa){(void)pa;static uint32_t z;return (vm_map_address_t)(uintptr_t)&z;}
static uint32_t arg_va=0, arg_fit=0;
static bool PE_parse_boot_argn(const char *n,void *v,int s){(void)s;
 if(!strcmp(n,"spesgpu_va_mb")&&arg_va){*(uint32_t*)v=arg_va;return true;}
 if(!strcmp(n,"spesgpu_va_fit")&&arg_fit){*(uint32_t*)v=arg_fit;return true;}
 return false;}
void RedwoodGPUStart(void){++starts;}
'''
suffix = r'''
static uint64_t l2[512], l2h[512]; static uint8_t dma[65536];
static void reset(uint32_t va,uint32_t fit){memset(&sg,0,sizeof(sg));memset(l2,0,sizeof l2);memset(l2h,0,sizeof l2h);
 l2h[224]=1;l2h[229]=1;arg_va=va;arg_fit=fit;assert(spes_gpu_backend_start(1,2,0x8000,(uintptr_t)dma,l2,l2h,0));}
int main(void){
 /* default: 512 MiB, first fit, as before */
 reset(0,0);assert(sg.size==0x20000000ull && !sg.best_fit);
 uint64_t a=redwood_gpu_address(12<<20),b=redwood_gpu_address(4096),c=redwood_gpu_address(1<<20);
 assert(a==0x20000000 && b==a+(12<<20) && c==b+0x10000);
 assert(redwood_gpu_unmap(b,4096));redwood_gpu_address_free(b,4096);
 /* first fit puts 4 KiB into the 64 KiB hole */
 uint64_t d=redwood_gpu_address(4096);assert(d==b);
 /* fill: 511 MiB more cannot fit */
 assert(!redwood_gpu_address(0x20000000ull-(12<<20)) && sg.refused_va==1);
 assert(!redwood_gpu_address(0x20000000ull+4096));
 uint32_t va,sl;uint64_t sz;redwood_gpu_refusals(&va,&sl,&sz);assert(va==1 && sl==0 && sz==0x20000000ull);
 /* best fit: a small buffer goes into the smallest hole, not the first */
 reset(0,1);
 uint64_t x=redwood_gpu_address(2<<20),y=redwood_gpu_address(64<<10),z=redwood_gpu_address(1<<20),w=redwood_gpu_address(64<<10);
 (void)w;
 assert(redwood_gpu_unmap(x,2<<20));redwood_gpu_address_free(x,2<<20);   /* 2 MiB hole first */
 assert(redwood_gpu_unmap(z,1<<20));redwood_gpu_address_free(z,1<<20);   /* 1 MiB hole after y */
 uint64_t s=redwood_gpu_address(64<<10);assert(s==z);
 arg_fit=0;sg.best_fit=false;assert(redwood_gpu_address(64<<10)==x); /* first fit would have taken x */
 (void)y;                    /* smallest fitting hole: z's */
 /* 960 MiB: the space runs on into l2_high */
 reset(960,0);assert(sg.size==960ull<<20);
 uint64_t big=redwood_gpu_address(900ull<<20);assert(big==0x20000000);
 assert(redwood_gpu_map(big+(600ull<<20),0x100000000ULL,false));          /* 0x45800000: second GiB */
 unsigned idx=(unsigned)((big+(600ull<<20)-0x20000000)>>21);
 assert(idx>=256 && l2h[idx-256] && !l2[256+ (idx&255)] );
 assert(spes_gpu_leaf(0x5c000000ull,false)==NULL);                       /* the FB table stays outside */
 assert(redwood_gpu_address(60ull<<20)==0x20000000+(900ull<<20));
 assert(!redwood_gpu_address(64<<10));
 /* out of range values: stay at 512 */
 reset(2048,0);assert(sg.size==0x20000000ull);
 reset(100,0);assert(sg.size==0x20000000ull);
 /* a taken L2 entry above 512 MiB: stays at 512 */
 memset(&sg,0,sizeof(sg));memset(l2h,0,sizeof l2h);l2h[10]=1;arg_va=960;
 assert(spes_gpu_backend_start(1,2,0x8000,(uintptr_t)dma,l2,l2h,0) && sg.size==0x20000000ull);
 /* slots */
 reset(0,0);unsigned n=0;while(redwood_gpu_address(4096))++n;assert(n==2048);
 redwood_gpu_refusals(&va,&sl,&sz);assert(sl==1);
 puts("ok");return 0;
}
'''


def backend_source(d):
    """bsd/dev/spes_gpu_backend.h after every patch (they create it; nothing else is needed)."""
    for p in PATCHES:
        if p.name > '0177~':
            break
        subprocess.run(['patch', '-p1', '-f', '-s'], cwd=d, stdin=p.open('rb'), capture_output=True)
    return (Path(d) / 'bsd/dev/spes_gpu_backend.h').read_text().replace('__asm__ volatile("dsb sy" ::: "memory");', '')


class GpuAddressSpaceTests(unittest.TestCase):
    def test_allocator(self):
        with tempfile.TemporaryDirectory() as d:
            src = backend_source(d)
            self.assertIn('spesgpu_va_mb', src)
            c = Path(d) / 'b.c'; exe = Path(d) / 'b'
            c.write_text(prefix + src + suffix)
            subprocess.run(['clang', '-Wall', '-Wno-unused-function', '-Wno-unused-variable',
                            '-fsanitize=address,undefined', str(c), '-o', str(exe)], check=True, capture_output=True)
            r = subprocess.run([str(exe)], capture_output=True, text=True,
                               env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0'))
            self.assertEqual(r.returncode, 0, r.stderr[-2000:])
            self.assertIn('ok', r.stdout)


if __name__ == '__main__':
    unittest.main()
