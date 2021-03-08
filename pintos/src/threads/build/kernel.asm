
kernel.o:     file format elf32-i386


Disassembly of section .text:

c0020080 <start>:
start:

# The loader called into us with CS = 0x2000, SS = 0x0000, ESP = 0xf000,
# but we should initialize the other segment registers.

	mov $0x2000, %ax
c0020080:	b8 00 20 8e d8       	mov    $0xd88e2000,%eax
	mov %ax, %ds
	mov %ax, %es
c0020085:	8e c0                	mov    %eax,%es

# Set string instructions to go upward.
	cld
c0020087:	fc                   	cld    
#### which returns AX = (kB of physical memory) - 1024.  This only
#### works for memory sizes <= 65 MB, which should be fine for our
#### purposes.  We cap memory at 64 MB because that's all we prepare
#### page tables for, below.

	movb $0x88, %ah
c0020088:	b4 88                	mov    $0x88,%ah
	int $0x15
c002008a:	cd 15                	int    $0x15
	addl $1024, %eax	# Total kB memory
c002008c:	66 05 00 04          	add    $0x400,%ax
c0020090:	00 00                	add    %al,(%eax)
	cmp $0x10000, %eax	# Cap at 64 MB
c0020092:	66 3d 00 00          	cmp    $0x0,%ax
c0020096:	01 00                	add    %eax,(%eax)
	jbe 1f
c0020098:	76 06                	jbe    c00200a0 <start+0x20>
	mov $0x10000, %eax
c002009a:	66 b8 00 00          	mov    $0x0,%ax
c002009e:	01 00                	add    %eax,(%eax)
1:	shrl $2, %eax		# Total 4 kB pages
c00200a0:	66 c1 e8 02          	shr    $0x2,%ax
	addr32 movl %eax, init_ram_pages - LOADER_PHYS_BASE - 0x20000
c00200a4:	67 66 a3 86 01       	addr16 mov %ax,0x186
c00200a9:	00 00                	add    %al,(%eax)
#### Enable A20.  Address line 20 is tied low when the machine boots,
#### which prevents addressing memory about 1 MB.  This code fixes it.

# Poll status register while busy.

1:	inb $0x64, %al
c00200ab:	e4 64                	in     $0x64,%al
	testb $0x2, %al
c00200ad:	a8 02                	test   $0x2,%al
	jnz 1b
c00200af:	75 fa                	jne    c00200ab <start+0x2b>

# Send command for writing output port.

	movb $0xd1, %al
c00200b1:	b0 d1                	mov    $0xd1,%al
	outb %al, $0x64
c00200b3:	e6 64                	out    %al,$0x64

# Poll status register while busy.

1:	inb $0x64, %al
c00200b5:	e4 64                	in     $0x64,%al
	testb $0x2, %al
c00200b7:	a8 02                	test   $0x2,%al
	jnz 1b
c00200b9:	75 fa                	jne    c00200b5 <start+0x35>

# Enable A20 line.

	movb $0xdf, %al
c00200bb:	b0 df                	mov    $0xdf,%al
	outb %al, $0x60
c00200bd:	e6 60                	out    %al,$0x60

# Poll status register while busy.

1:	inb $0x64, %al
c00200bf:	e4 64                	in     $0x64,%al
	testb $0x2, %al
c00200c1:	a8 02                	test   $0x2,%al
	jnz 1b
c00200c3:	75 fa                	jne    c00200bf <start+0x3f>

#### Create temporary page directory and page table and set page
#### directory base register.

# Create page directory at 0xf000 (60 kB) and fill with zeroes.
	mov $0xf00, %ax
c00200c5:	b8 00 0f 8e c0       	mov    $0xc08e0f00,%eax
	mov %ax, %es
	subl %eax, %eax
c00200ca:	66 29 c0             	sub    %ax,%ax
	subl %edi, %edi
c00200cd:	66 29 ff             	sub    %di,%di
	movl $0x400, %ecx
c00200d0:	66 b9 00 04          	mov    $0x400,%cx
c00200d4:	00 00                	add    %al,(%eax)
	rep stosl
c00200d6:	66 f3 ab             	rep stos %ax,%es:(%edi)
# Add PDEs to point to page tables for the first 64 MB of RAM.
# Also add identical PDEs starting at LOADER_PHYS_BASE.
# See [IA32-v3a] section 3.7.6 "Page-Directory and Page-Table Entries"
# for a description of the bits in %eax.

	movl $0x10007, %eax
c00200d9:	66 b8 07 00          	mov    $0x7,%ax
c00200dd:	01 00                	add    %eax,(%eax)
	movl $0x11, %ecx
c00200df:	66 b9 11 00          	mov    $0x11,%cx
c00200e3:	00 00                	add    %al,(%eax)
	subl %edi, %edi
c00200e5:	66 29 ff             	sub    %di,%di
1:	movl %eax, %es:(%di)
c00200e8:	26 66 89 05 26 66 89 	mov    %ax,%es:0x85896626
c00200ef:	85 
	movl %eax, %es:LOADER_PHYS_BASE >> 20(%di)
c00200f0:	00 0c 83             	add    %cl,(%ebx,%eax,4)
	addw $4, %di
c00200f3:	c7 04 66 05 00 10 00 	movl   $0x100005,(%esi,%eiz,2)
	addl $0x1000, %eax
c00200fa:	00 e2                	add    %ah,%dl
	loop 1b
c00200fc:	eb b8                	jmp    c00200b6 <start+0x36>
# Set up page tables for one-to-map linear to physical map for the
# first 64 MB of RAM.
# See [IA32-v3a] section 3.7.6 "Page-Directory and Page-Table Entries"
# for a description of the bits in %eax.

	movw $0x1000, %ax
c00200fe:	00 10                	add    %dl,(%eax)
	movw %ax, %es
c0020100:	8e c0                	mov    %eax,%es
	movl $0x7, %eax
c0020102:	66 b8 07 00          	mov    $0x7,%ax
c0020106:	00 00                	add    %al,(%eax)
	movl $0x4000, %ecx
c0020108:	66 b9 00 40          	mov    $0x4000,%cx
c002010c:	00 00                	add    %al,(%eax)
	subl %edi, %edi
c002010e:	66 29 ff             	sub    %di,%di
1:	movl %eax, %es:(%di)
c0020111:	26 66 89 05 83 c7 04 	mov    %ax,%es:0x6604c783
c0020118:	66 
	addw $4, %di
	addl $0x1000, %eax
c0020119:	05 00 10 00 00       	add    $0x1000,%eax
	loop 1b
c002011e:	e2 f1                	loop   c0020111 <start+0x91>

# Set page directory base register.

	movl $0xf000, %eax
c0020120:	66 b8 00 f0          	mov    $0xf000,%ax
c0020124:	00 00                	add    %al,(%eax)
	movl %eax, %cr3
c0020126:	0f 22 d8             	mov    %eax,%cr3
#### Switch to protected mode.

# First, disable interrupts.  We won't set up the IDT until we get
# into C code, so any interrupt would blow us away.

	cli
c0020129:	fa                   	cli    
# We need a data32 prefix to ensure that all 32 bits of the GDT
# descriptor are loaded (default is to load only 24 bits).
# The CPU doesn't need an addr32 prefix but ELF doesn't do 16-bit
# relocations.

	data32 addr32 lgdt gdtdesc - LOADER_PHYS_BASE - 0x20000
c002012a:	67 66 0f 01 15       	lgdtw  (%di)
c002012f:	80 01 00             	addb   $0x0,(%ecx)
c0020132:	00 0f                	add    %cl,(%edi)
#    WP (Write Protect): if unset, ring 0 code ignores
#       write-protect bits in page tables (!).
#    EM (Emulation): forces floating-point instructions to trap.
#       We don't support floating point.

	movl %cr0, %eax
c0020134:	20 c0                	and    %al,%al
	orl $CR0_PE | CR0_PG | CR0_WP | CR0_EM, %eax
c0020136:	66 0d 05 00          	or     $0x5,%ax
c002013a:	01 80 0f 22 c0 66    	add    %eax,0x66c0220f(%eax)
# the real-mode code segment cached in %cs's segment descriptor.  We
# need to reload %cs, and the easiest way is to use a far jump.
# Because we're not running in a 32-bit segment the data32 prefix is
# needed to jump to a 32-bit offset in the target segment.

	data32 ljmp $SEL_KCSEG, $1f
c0020140:	ea 47 01 02 c0 08 00 	ljmp   $0x8,$0xc0020147
	.code32

# Reload all the other segment registers and the stack pointer to
# point into our new GDT.

1:	mov $SEL_KDSEG, %ax
c0020147:	66 b8 10 00          	mov    $0x10,%ax
	mov %ax, %ds
c002014b:	8e d8                	mov    %eax,%ds
	mov %ax, %es
c002014d:	8e c0                	mov    %eax,%es
	mov %ax, %fs
c002014f:	8e e0                	mov    %eax,%fs
	mov %ax, %gs
c0020151:	8e e8                	mov    %eax,%gs
	mov %ax, %ss
c0020153:	8e d0                	mov    %eax,%ss
	addl $LOADER_PHYS_BASE, %esp
c0020155:	81 c4 00 00 00 c0    	add    $0xc0000000,%esp
	movl $0, %ebp			# Null-terminate main()'s backtrace
c002015b:	bd 00 00 00 00       	mov    $0x0,%ebp

#### Call pintos_init().

	call pintos_init
c0020160:	e8 63 00 00 00       	call   c00201c8 <pintos_init>

# pintos_init() shouldn't ever return.  If it does, spin.

1:	jmp 1b
c0020165:	eb fe                	jmp    c0020165 <start+0xe5>
	...

c0020168 <gdt>:
	...
c0020170:	ff                   	(bad)  
c0020171:	ff 00                	incl   (%eax)
c0020173:	00 00                	add    %al,(%eax)
c0020175:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
c002017c:	00                   	.byte 0x0
c002017d:	92                   	xchg   %eax,%edx
c002017e:	cf                   	iret   
	...

c0020180 <gdtdesc>:
c0020180:	17                   	pop    %ss
c0020181:	00 68 01             	add    %ch,0x1(%eax)
c0020184:	02 c0                	add    %al,%al

c0020186 <init_ram_pages>:
c0020186:	00 00                	add    %al,(%eax)
c0020188:	00 00                	add    %al,(%eax)
c002018a:	90                   	nop
c002018b:	90                   	nop
c002018c:	90                   	nop
c002018d:	90                   	nop
c002018e:	90                   	nop
c002018f:	90                   	nop

c0020190 <run_task>:
}

/* Runs the task specified in ARGV[1]. */
static void
run_task (char **argv)
{
c0020190:	53                   	push   %ebx
c0020191:	83 ec 18             	sub    $0x18,%esp
  const char *task = argv[1];
c0020194:	8b 44 24 20          	mov    0x20(%esp),%eax
c0020198:	8b 58 04             	mov    0x4(%eax),%ebx
  
  printf ("Executing '%s':\n", task);
c002019b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002019f:	c7 04 24 f9 e0 02 c0 	movl   $0xc002e0f9,(%esp)
c00201a6:	e8 83 69 00 00       	call   c0026b2e <printf>
#ifdef USERPROG
  process_wait (process_execute (task));
#else
  run_test (task);
c00201ab:	89 1c 24             	mov    %ebx,(%esp)
c00201ae:	e8 c6 a5 00 00       	call   c002a779 <run_test>
#endif
  printf ("Execution of '%s' complete.\n", task);
c00201b3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00201b7:	c7 04 24 0a e1 02 c0 	movl   $0xc002e10a,(%esp)
c00201be:	e8 6b 69 00 00       	call   c0026b2e <printf>
}
c00201c3:	83 c4 18             	add    $0x18,%esp
c00201c6:	5b                   	pop    %ebx
c00201c7:	c3                   	ret    

c00201c8 <pintos_init>:
{
c00201c8:	55                   	push   %ebp
c00201c9:	57                   	push   %edi
c00201ca:	56                   	push   %esi
c00201cb:	53                   	push   %ebx
c00201cc:	83 ec 7c             	sub    $0x7c,%esp
  memset (&_start_bss, 0, &_end_bss - &_start_bss);
c00201cf:	b8 d0 7b 03 c0       	mov    $0xc0037bd0,%eax
c00201d4:	2d 94 5a 03 c0       	sub    $0xc0035a94,%eax
c00201d9:	89 44 24 08          	mov    %eax,0x8(%esp)
c00201dd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00201e4:	00 
c00201e5:	c7 04 24 94 5a 03 c0 	movl   $0xc0035a94,(%esp)
c00201ec:	e8 50 7c 00 00       	call   c0027e41 <memset>
  argc = *(uint32_t *) ptov (LOADER_ARG_CNT);
c00201f1:	8b 3d 3a 7d 00 c0    	mov    0xc0007d3a,%edi
  for (i = 0; i < argc; i++) 
c00201f7:	be 00 00 00 00       	mov    $0x0,%esi
  p = ptov (LOADER_ARGS);
c00201fc:	bb 3e 7d 00 c0       	mov    $0xc0007d3e,%ebx
      p += strnlen (p, end - p) + 1;
c0020201:	bd be 7d 00 c0       	mov    $0xc0007dbe,%ebp
  for (i = 0; i < argc; i++) 
c0020206:	85 ff                	test   %edi,%edi
c0020208:	7f 31                	jg     c002023b <pintos_init+0x73>
c002020a:	e9 1e 06 00 00       	jmp    c002082d <pintos_init+0x665>
      if (p >= end)
c002020f:	81 fb bd 7d 00 c0    	cmp    $0xc0007dbd,%ebx
c0020215:	76 24                	jbe    c002023b <pintos_init+0x73>
        PANIC ("command line arguments overflow");
c0020217:	c7 44 24 0c 34 e2 02 	movl   $0xc002e234,0xc(%esp)
c002021e:	c0 
c002021f:	c7 44 24 08 67 d0 02 	movl   $0xc002d067,0x8(%esp)
c0020226:	c0 
c0020227:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c002022e:	00 
c002022f:	c7 04 24 27 e1 02 c0 	movl   $0xc002e127,(%esp)
c0020236:	e8 48 87 00 00       	call   c0028983 <debug_panic>
      argv[i] = p;
c002023b:	89 1c b5 a0 5a 03 c0 	mov    %ebx,-0x3ffca560(,%esi,4)
      p += strnlen (p, end - p) + 1;
c0020242:	89 e8                	mov    %ebp,%eax
c0020244:	29 d8                	sub    %ebx,%eax
c0020246:	89 44 24 04          	mov    %eax,0x4(%esp)
c002024a:	89 1c 24             	mov    %ebx,(%esp)
c002024d:	e8 18 7d 00 00       	call   c0027f6a <strnlen>
c0020252:	8d 5c 03 01          	lea    0x1(%ebx,%eax,1),%ebx
  for (i = 0; i < argc; i++) 
c0020256:	83 c6 01             	add    $0x1,%esi
c0020259:	39 f7                	cmp    %esi,%edi
c002025b:	75 b2                	jne    c002020f <pintos_init+0x47>
  argv[argc] = NULL;
c002025d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020264:	00 00 00 00 
  printf ("Kernel command line:");
c0020268:	c7 04 24 1d e2 02 c0 	movl   $0xc002e21d,(%esp)
c002026f:	e8 ba 68 00 00       	call   c0026b2e <printf>
  for (i = 0; i < argc; i++)
c0020274:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (argv[i], ' ') == NULL)
c0020279:	8b 34 9d a0 5a 03 c0 	mov    -0x3ffca560(,%ebx,4),%esi
c0020280:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c0020287:	00 
c0020288:	89 34 24             	mov    %esi,(%esp)
c002028b:	e8 26 79 00 00       	call   c0027bb6 <strchr>
c0020290:	85 c0                	test   %eax,%eax
c0020292:	75 12                	jne    c00202a6 <pintos_init+0xde>
      printf (" %s", argv[i]);
c0020294:	89 74 24 04          	mov    %esi,0x4(%esp)
c0020298:	c7 04 24 47 ef 02 c0 	movl   $0xc002ef47,(%esp)
c002029f:	e8 8a 68 00 00       	call   c0026b2e <printf>
c00202a4:	eb 10                	jmp    c00202b6 <pintos_init+0xee>
      printf (" '%s'", argv[i]);
c00202a6:	89 74 24 04          	mov    %esi,0x4(%esp)
c00202aa:	c7 04 24 3c e1 02 c0 	movl   $0xc002e13c,(%esp)
c00202b1:	e8 78 68 00 00       	call   c0026b2e <printf>
  for (i = 0; i < argc; i++)
c00202b6:	83 c3 01             	add    $0x1,%ebx
c00202b9:	39 df                	cmp    %ebx,%edi
c00202bb:	75 bc                	jne    c0020279 <pintos_init+0xb1>
  printf ("\n");
c00202bd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00202c4:	e8 53 a4 00 00       	call   c002a71c <putchar>
  for (; *argv != NULL && **argv == '-'; argv++)
c00202c9:	a1 a0 5a 03 c0       	mov    0xc0035aa0,%eax
c00202ce:	85 c0                	test   %eax,%eax
c00202d0:	0f 84 44 01 00 00    	je     c002041a <pintos_init+0x252>
c00202d6:	80 38 2d             	cmpb   $0x2d,(%eax)
c00202d9:	0f 85 43 01 00 00    	jne    c0020422 <pintos_init+0x25a>
c00202df:	bd a0 5a 03 c0       	mov    $0xc0035aa0,%ebp
      char *name = strtok_r (*argv, "=", &save_ptr);
c00202e4:	8d 7c 24 3c          	lea    0x3c(%esp),%edi
c00202e8:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00202ec:	c7 44 24 04 d9 ed 02 	movl   $0xc002edd9,0x4(%esp)
c00202f3:	c0 
c00202f4:	89 04 24             	mov    %eax,(%esp)
c00202f7:	e8 28 7a 00 00       	call   c0027d24 <strtok_r>
c00202fc:	89 c3                	mov    %eax,%ebx
      char *value = strtok_r (NULL, "", &save_ptr);
c00202fe:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020302:	89 44 24 08          	mov    %eax,0x8(%esp)
c0020306:	c7 44 24 04 eb ed 02 	movl   $0xc002edeb,0x4(%esp)
c002030d:	c0 
c002030e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0020315:	e8 0a 7a 00 00       	call   c0027d24 <strtok_r>
      if (!strcmp (name, "-h"))
c002031a:	bf 42 e1 02 c0       	mov    $0xc002e142,%edi
c002031f:	89 de                	mov    %ebx,%esi
c0020321:	b9 03 00 00 00       	mov    $0x3,%ecx
c0020326:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c0020328:	0f 97 c1             	seta   %cl
c002032b:	0f 92 c2             	setb   %dl
c002032e:	38 d1                	cmp    %dl,%cl
c0020330:	75 11                	jne    c0020343 <pintos_init+0x17b>
/* Prints a kernel command line help message and powers off the
   machine. */
static void
usage (void)
{
  printf ("\nCommand line syntax: [OPTION...] [ACTION...]\n"
c0020332:	c7 04 24 54 e2 02 c0 	movl   $0xc002e254,(%esp)
c0020339:	e8 6d a3 00 00       	call   c002a6ab <puts>
          "  -mlfqs             Use multi-level feedback queue scheduler.\n"
#ifdef USERPROG
          "  -ul=COUNT          Limit user memory to COUNT pages.\n"
#endif
          );
  shutdown_power_off ();
c002033e:	e8 cc 60 00 00       	call   c002640f <shutdown_power_off>
      else if (!strcmp (name, "-q"))
c0020343:	bf 45 e1 02 c0       	mov    $0xc002e145,%edi
c0020348:	89 de                	mov    %ebx,%esi
c002034a:	b9 03 00 00 00       	mov    $0x3,%ecx
c002034f:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c0020351:	0f 97 c1             	seta   %cl
c0020354:	0f 92 c2             	setb   %dl
c0020357:	38 d1                	cmp    %dl,%cl
c0020359:	75 11                	jne    c002036c <pintos_init+0x1a4>
        shutdown_configure (SHUTDOWN_POWER_OFF);
c002035b:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0020362:	e8 29 60 00 00       	call   c0026390 <shutdown_configure>
c0020367:	e9 99 00 00 00       	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-r"))
c002036c:	bf 48 e1 02 c0       	mov    $0xc002e148,%edi
c0020371:	89 de                	mov    %ebx,%esi
c0020373:	b9 03 00 00 00       	mov    $0x3,%ecx
c0020378:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c002037a:	0f 97 c1             	seta   %cl
c002037d:	0f 92 c2             	setb   %dl
c0020380:	38 d1                	cmp    %dl,%cl
c0020382:	75 0e                	jne    c0020392 <pintos_init+0x1ca>
        shutdown_configure (SHUTDOWN_REBOOT);
c0020384:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c002038b:	e8 00 60 00 00       	call   c0026390 <shutdown_configure>
c0020390:	eb 73                	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-rs"))
c0020392:	bf 4b e1 02 c0       	mov    $0xc002e14b,%edi
c0020397:	b9 04 00 00 00       	mov    $0x4,%ecx
c002039c:	89 de                	mov    %ebx,%esi
c002039e:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00203a0:	0f 97 c1             	seta   %cl
c00203a3:	0f 92 c2             	setb   %dl
c00203a6:	38 d1                	cmp    %dl,%cl
c00203a8:	75 12                	jne    c00203bc <pintos_init+0x1f4>
        random_init (atoi (value));
c00203aa:	89 04 24             	mov    %eax,(%esp)
c00203ad:	e8 de 71 00 00       	call   c0027590 <atoi>
c00203b2:	89 04 24             	mov    %eax,(%esp)
c00203b5:	e8 21 62 00 00       	call   c00265db <random_init>
c00203ba:	eb 49                	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-mlfqs"))
c00203bc:	bf 4f e1 02 c0       	mov    $0xc002e14f,%edi
c00203c1:	b9 07 00 00 00       	mov    $0x7,%ecx
c00203c6:	89 de                	mov    %ebx,%esi
c00203c8:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00203ca:	0f 97 c2             	seta   %dl
c00203cd:	0f 92 c0             	setb   %al
c00203d0:	38 c2                	cmp    %al,%dl
c00203d2:	75 09                	jne    c00203dd <pintos_init+0x215>
        thread_mlfqs = true;
c00203d4:	c6 05 bc 7b 03 c0 01 	movb   $0x1,0xc0037bbc
c00203db:	eb 28                	jmp    c0020405 <pintos_init+0x23d>
        PANIC ("unknown option `%s' (use -h for help)", name);
c00203dd:	89 5c 24 10          	mov    %ebx,0x10(%esp)
c00203e1:	c7 44 24 0c 24 e4 02 	movl   $0xc002e424,0xc(%esp)
c00203e8:	c0 
c00203e9:	c7 44 24 08 54 d0 02 	movl   $0xc002d054,0x8(%esp)
c00203f0:	c0 
c00203f1:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c00203f8:	00 
c00203f9:	c7 04 24 27 e1 02 c0 	movl   $0xc002e127,(%esp)
c0020400:	e8 7e 85 00 00       	call   c0028983 <debug_panic>
  for (; *argv != NULL && **argv == '-'; argv++)
c0020405:	83 c5 04             	add    $0x4,%ebp
c0020408:	8b 45 00             	mov    0x0(%ebp),%eax
c002040b:	85 c0                	test   %eax,%eax
c002040d:	74 18                	je     c0020427 <pintos_init+0x25f>
c002040f:	80 38 2d             	cmpb   $0x2d,(%eax)
c0020412:	0f 84 cc fe ff ff    	je     c00202e4 <pintos_init+0x11c>
c0020418:	eb 0d                	jmp    c0020427 <pintos_init+0x25f>
c002041a:	bd a0 5a 03 c0       	mov    $0xc0035aa0,%ebp
c002041f:	90                   	nop
c0020420:	eb 05                	jmp    c0020427 <pintos_init+0x25f>
c0020422:	bd a0 5a 03 c0       	mov    $0xc0035aa0,%ebp
  random_init (rtc_get_time ());
c0020427:	e8 00 5e 00 00       	call   c002622c <rtc_get_time>
c002042c:	89 04 24             	mov    %eax,(%esp)
c002042f:	e8 a7 61 00 00       	call   c00265db <random_init>
  thread_init ();
c0020434:	e8 8c 07 00 00       	call   c0020bc5 <thread_init>
  console_init ();  
c0020439:	e8 e4 a1 00 00       	call   c002a622 <console_init>
          init_ram_pages * PGSIZE / 1024);
c002043e:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c0020443:	c1 e0 0c             	shl    $0xc,%eax
  printf ("Pintos booting with %'"PRIu32" kB RAM...\n",
c0020446:	c1 e8 0a             	shr    $0xa,%eax
c0020449:	89 44 24 04          	mov    %eax,0x4(%esp)
c002044d:	c7 04 24 4c e4 02 c0 	movl   $0xc002e44c,(%esp)
c0020454:	e8 d5 66 00 00       	call   c0026b2e <printf>
  palloc_init (user_page_limit);
c0020459:	c7 04 24 ff ff ff ff 	movl   $0xffffffff,(%esp)
c0020460:	e8 5b 30 00 00       	call   c00234c0 <palloc_init>
  malloc_init ();
c0020465:	e8 dd 34 00 00       	call   c0023947 <malloc_init>
  pd = init_page_dir = palloc_get_page (PAL_ASSERT | PAL_ZERO);
c002046a:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
c0020471:	e8 b0 31 00 00       	call   c0023626 <palloc_get_page>
c0020476:	89 44 24 28          	mov    %eax,0x28(%esp)
c002047a:	a3 b8 7b 03 c0       	mov    %eax,0xc0037bb8
  pt = NULL;
c002047f:	b8 00 00 00 00       	mov    $0x0,%eax
      uintptr_t paddr = page * PGSIZE;
c0020484:	bb 00 00 00 00       	mov    $0x0,%ebx
  for (page = 0; page < init_ram_pages; page++)
c0020489:	be 00 00 00 00       	mov    $0x0,%esi
c002048e:	83 3d 86 01 02 c0 00 	cmpl   $0x0,0xc0020186
c0020495:	75 3e                	jne    c00204d5 <pintos_init+0x30d>
c0020497:	e9 69 01 00 00       	jmp    c0020605 <pintos_init+0x43d>
c002049c:	89 f3                	mov    %esi,%ebx
c002049e:	c1 e3 0c             	shl    $0xc,%ebx
/* Returns kernel virtual address at which physical address PADDR
   is mapped. */
static inline void *
ptov (uintptr_t paddr)
{
  ASSERT ((void *) paddr < PHYS_BASE);
c00204a1:	81 fe 00 00 0c 00    	cmp    $0xc0000,%esi
c00204a7:	75 30                	jne    c00204d9 <pintos_init+0x311>
c00204a9:	c7 44 24 10 56 e1 02 	movl   $0xc002e156,0x10(%esp)
c00204b0:	c0 
c00204b1:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00204b8:	c0 
c00204b9:	c7 44 24 08 62 d0 02 	movl   $0xc002d062,0x8(%esp)
c00204c0:	c0 
c00204c1:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c00204c8:	00 
c00204c9:	c7 04 24 88 e1 02 c0 	movl   $0xc002e188,(%esp)
c00204d0:	e8 ae 84 00 00       	call   c0028983 <debug_panic>
c00204d5:	89 6c 24 2c          	mov    %ebp,0x2c(%esp)

  return (void *) (paddr + PHYS_BASE);
c00204d9:	81 eb 00 00 00 40    	sub    $0x40000000,%ebx
  return ((uintptr_t) va & PTMASK) >> PTSHIFT;
}

/* Obtains page directory index from a virtual address. */
static inline uintptr_t pd_no (const void *va) {
  return (uintptr_t) va >> PDSHIFT;
c00204df:	89 da                	mov    %ebx,%edx
c00204e1:	c1 ea 16             	shr    $0x16,%edx
  return ((uintptr_t) va & PTMASK) >> PTSHIFT;
c00204e4:	89 d9                	mov    %ebx,%ecx
c00204e6:	81 e1 00 f0 3f 00    	and    $0x3ff000,%ecx
c00204ec:	c1 e9 0c             	shr    $0xc,%ecx
c00204ef:	89 4c 24 24          	mov    %ecx,0x24(%esp)
      bool in_kernel_text = &_start <= vaddr && vaddr < &_end_kernel_text;
c00204f3:	bf 00 00 00 00       	mov    $0x0,%edi
c00204f8:	81 fb 00 00 02 c0    	cmp    $0xc0020000,%ebx
c00204fe:	72 0e                	jb     c002050e <pintos_init+0x346>
c0020500:	81 fb 00 20 03 c0    	cmp    $0xc0032000,%ebx
c0020506:	0f 92 c1             	setb   %cl
c0020509:	0f b6 c9             	movzbl %cl,%ecx
c002050c:	89 cf                	mov    %ecx,%edi
      if (pd[pde_idx] == 0)
c002050e:	8b 4c 24 28          	mov    0x28(%esp),%ecx
c0020512:	8d 2c 91             	lea    (%ecx,%edx,4),%ebp
c0020515:	83 7d 00 00          	cmpl   $0x0,0x0(%ebp)
c0020519:	0f 85 80 00 00 00    	jne    c002059f <pintos_init+0x3d7>
          pt = palloc_get_page (PAL_ASSERT | PAL_ZERO);
c002051f:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
c0020526:	e8 fb 30 00 00       	call   c0023626 <palloc_get_page>
  return (uintptr_t) va & PGMASK;
c002052b:	89 c2                	mov    %eax,%edx
#define PTE_A 0x20              /* 1=accessed, 0=not acccessed. */
#define PTE_D 0x40              /* 1=dirty, 0=not dirty (PTEs only). */

/* Returns a PDE that points to page table PT. */
static inline uint32_t pde_create (uint32_t *pt) {
  ASSERT (pg_ofs (pt) == 0);
c002052d:	a9 ff 0f 00 00       	test   $0xfff,%eax
c0020532:	74 2c                	je     c0020560 <pintos_init+0x398>
c0020534:	c7 44 24 10 9e e1 02 	movl   $0xc002e19e,0x10(%esp)
c002053b:	c0 
c002053c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020543:	c0 
c0020544:	c7 44 24 08 49 d0 02 	movl   $0xc002d049,0x8(%esp)
c002054b:	c0 
c002054c:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c0020553:	00 
c0020554:	c7 04 24 af e1 02 c0 	movl   $0xc002e1af,(%esp)
c002055b:	e8 23 84 00 00       	call   c0028983 <debug_panic>
/* Returns physical address at which kernel virtual address VADDR
   is mapped. */
static inline uintptr_t
vtop (const void *vaddr)
{
  ASSERT (is_kernel_vaddr (vaddr));
c0020560:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c0020565:	77 2c                	ja     c0020593 <pintos_init+0x3cb>
c0020567:	c7 44 24 10 c3 e1 02 	movl   $0xc002e1c3,0x10(%esp)
c002056e:	c0 
c002056f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020576:	c0 
c0020577:	c7 44 24 08 44 d0 02 	movl   $0xc002d044,0x8(%esp)
c002057e:	c0 
c002057f:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0020586:	00 
c0020587:	c7 04 24 88 e1 02 c0 	movl   $0xc002e188,(%esp)
c002058e:	e8 f0 83 00 00       	call   c0028983 <debug_panic>

  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c0020593:	81 c2 00 00 00 40    	add    $0x40000000,%edx
  return vtop (pt) | PTE_U | PTE_P | PTE_W;
c0020599:	83 ca 07             	or     $0x7,%edx
c002059c:	89 55 00             	mov    %edx,0x0(%ebp)
      pt[pte_idx] = pte_create_kernel (vaddr, !in_kernel_text);
c002059f:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c00205a3:	8d 14 88             	lea    (%eax,%ecx,4),%edx
c00205a6:	83 e7 01             	and    $0x1,%edi
  ASSERT (is_kernel_vaddr (vaddr));
c00205a9:	81 fb ff ff ff bf    	cmp    $0xbfffffff,%ebx
c00205af:	77 2c                	ja     c00205dd <pintos_init+0x415>
c00205b1:	c7 44 24 10 c3 e1 02 	movl   $0xc002e1c3,0x10(%esp)
c00205b8:	c0 
c00205b9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00205c0:	c0 
c00205c1:	c7 44 24 08 44 d0 02 	movl   $0xc002d044,0x8(%esp)
c00205c8:	c0 
c00205c9:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c00205d0:	00 
c00205d1:	c7 04 24 88 e1 02 c0 	movl   $0xc002e188,(%esp)
c00205d8:	e8 a6 83 00 00       	call   c0028983 <debug_panic>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c00205dd:	81 c3 00 00 00 40    	add    $0x40000000,%ebx
   The PTE's page is readable.
   If WRITABLE is true then it will be writable as well.
   The page will be usable only by ring 0 code (the kernel). */
static inline uint32_t pte_create_kernel (void *page, bool writable) {
  ASSERT (pg_ofs (page) == 0);
  return vtop (page) | PTE_P | (writable ? PTE_W : 0);
c00205e3:	83 ff 01             	cmp    $0x1,%edi
c00205e6:	19 c9                	sbb    %ecx,%ecx
c00205e8:	83 e1 02             	and    $0x2,%ecx
c00205eb:	83 cb 01             	or     $0x1,%ebx
c00205ee:	09 d9                	or     %ebx,%ecx
c00205f0:	89 0a                	mov    %ecx,(%edx)
  for (page = 0; page < init_ram_pages; page++)
c00205f2:	83 c6 01             	add    $0x1,%esi
c00205f5:	3b 35 86 01 02 c0    	cmp    0xc0020186,%esi
c00205fb:	0f 82 9b fe ff ff    	jb     c002049c <pintos_init+0x2d4>
c0020601:	8b 6c 24 2c          	mov    0x2c(%esp),%ebp
  asm volatile ("movl %0, %%cr3" : : "r" (vtop (init_page_dir)));
c0020605:	a1 b8 7b 03 c0       	mov    0xc0037bb8,%eax
  ASSERT (is_kernel_vaddr (vaddr));
c002060a:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c002060f:	77 2c                	ja     c002063d <pintos_init+0x475>
c0020611:	c7 44 24 10 c3 e1 02 	movl   $0xc002e1c3,0x10(%esp)
c0020618:	c0 
c0020619:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020620:	c0 
c0020621:	c7 44 24 08 44 d0 02 	movl   $0xc002d044,0x8(%esp)
c0020628:	c0 
c0020629:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0020630:	00 
c0020631:	c7 04 24 88 e1 02 c0 	movl   $0xc002e188,(%esp)
c0020638:	e8 46 83 00 00       	call   c0028983 <debug_panic>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c002063d:	05 00 00 00 40       	add    $0x40000000,%eax
c0020642:	0f 22 d8             	mov    %eax,%cr3
  intr_init ();
c0020645:	e8 97 13 00 00       	call   c00219e1 <intr_init>
  timer_init ();
c002064a:	e8 4a 3a 00 00       	call   c0024099 <timer_init>
  kbd_init ();
c002064f:	e8 f7 3f 00 00       	call   c002464b <kbd_init>
  input_init ();
c0020654:	e8 bc 56 00 00       	call   c0025d15 <input_init>
  thread_start ();
c0020659:	e8 ed 0f 00 00       	call   c002164b <thread_start>
c002065e:	66 90                	xchg   %ax,%ax
  serial_init_queue ();
c0020660:	e8 31 44 00 00       	call   c0024a96 <serial_init_queue>
  timer_calibrate ();
c0020665:	e8 bc 3a 00 00       	call   c0024126 <timer_calibrate>
  printf ("Boot complete.\n");
c002066a:	c7 04 24 db e1 02 c0 	movl   $0xc002e1db,(%esp)
c0020671:	e8 35 a0 00 00       	call   c002a6ab <puts>
  if (*argv != NULL) {
c0020676:	8b 75 00             	mov    0x0(%ebp),%esi
c0020679:	85 f6                	test   %esi,%esi
c002067b:	0f 84 c9 00 00 00    	je     c002074a <pintos_init+0x582>
        if (a->name == NULL)
c0020681:	b8 8e e7 02 c0       	mov    $0xc002e78e,%eax
  if (*argv != NULL) {
c0020686:	bb 2c d0 02 c0       	mov    $0xc002d02c,%ebx
c002068b:	eb 0c                	jmp    c0020699 <pintos_init+0x4d1>
        if (a->name == NULL)
c002068d:	b8 8e e7 02 c0       	mov    $0xc002e78e,%eax
  while (*argv != NULL)
c0020692:	ba 2c d0 02 c0       	mov    $0xc002d02c,%edx
c0020697:	89 d3                	mov    %edx,%ebx
        else if (!strcmp (*argv, a->name))
c0020699:	89 44 24 04          	mov    %eax,0x4(%esp)
c002069d:	89 34 24             	mov    %esi,(%esp)
c00206a0:	e8 f2 73 00 00       	call   c0027a97 <strcmp>
c00206a5:	85 c0                	test   %eax,%eax
c00206a7:	75 10                	jne    c00206b9 <pintos_init+0x4f1>
      for (i = 1; i < a->argc; i++)
c00206a9:	8b 53 04             	mov    0x4(%ebx),%edx
c00206ac:	83 fa 01             	cmp    $0x1,%edx
c00206af:	7e 7c                	jle    c002072d <pintos_init+0x565>
        if (argv[i] == NULL)
c00206b1:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c00206b5:	75 6a                	jne    c0020721 <pintos_init+0x559>
c00206b7:	eb 39                	jmp    c00206f2 <pintos_init+0x52a>
      for (a = actions; ; a++)
c00206b9:	8d 53 0c             	lea    0xc(%ebx),%edx
        if (a->name == NULL)
c00206bc:	8b 43 0c             	mov    0xc(%ebx),%eax
c00206bf:	85 c0                	test   %eax,%eax
c00206c1:	75 d4                	jne    c0020697 <pintos_init+0x4cf>
          PANIC ("unknown action `%s' (use -h for help)", *argv);
c00206c3:	89 74 24 10          	mov    %esi,0x10(%esp)
c00206c7:	c7 44 24 0c 70 e4 02 	movl   $0xc002e470,0xc(%esp)
c00206ce:	c0 
c00206cf:	c7 44 24 08 20 d0 02 	movl   $0xc002d020,0x8(%esp)
c00206d6:	c0 
c00206d7:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c00206de:	00 
c00206df:	c7 04 24 27 e1 02 c0 	movl   $0xc002e127,(%esp)
c00206e6:	e8 98 82 00 00       	call   c0028983 <debug_panic>
        if (argv[i] == NULL)
c00206eb:	83 7c 85 00 00       	cmpl   $0x0,0x0(%ebp,%eax,4)
c00206f0:	75 34                	jne    c0020726 <pintos_init+0x55e>
          PANIC ("action `%s' requires %d argument(s)", *argv, a->argc - 1);
c00206f2:	83 ea 01             	sub    $0x1,%edx
c00206f5:	89 54 24 14          	mov    %edx,0x14(%esp)
c00206f9:	89 74 24 10          	mov    %esi,0x10(%esp)
c00206fd:	c7 44 24 0c 98 e4 02 	movl   $0xc002e498,0xc(%esp)
c0020704:	c0 
c0020705:	c7 44 24 08 20 d0 02 	movl   $0xc002d020,0x8(%esp)
c002070c:	c0 
c002070d:	c7 44 24 04 72 01 00 	movl   $0x172,0x4(%esp)
c0020714:	00 
c0020715:	c7 04 24 27 e1 02 c0 	movl   $0xc002e127,(%esp)
c002071c:	e8 62 82 00 00       	call   c0028983 <debug_panic>
        if (argv[i] == NULL)
c0020721:	b8 01 00 00 00       	mov    $0x1,%eax
      for (i = 1; i < a->argc; i++)
c0020726:	83 c0 01             	add    $0x1,%eax
c0020729:	39 d0                	cmp    %edx,%eax
c002072b:	75 be                	jne    c00206eb <pintos_init+0x523>
      a->function (argv);
c002072d:	89 2c 24             	mov    %ebp,(%esp)
c0020730:	ff 53 08             	call   *0x8(%ebx)
      argv += a->argc;
c0020733:	8b 43 04             	mov    0x4(%ebx),%eax
c0020736:	8d 6c 85 00          	lea    0x0(%ebp,%eax,4),%ebp
  while (*argv != NULL)
c002073a:	8b 75 00             	mov    0x0(%ebp),%esi
c002073d:	85 f6                	test   %esi,%esi
c002073f:	0f 85 48 ff ff ff    	jne    c002068d <pintos_init+0x4c5>
c0020745:	e9 d9 00 00 00       	jmp    c0020823 <pintos_init+0x65b>
        if(!strcmp(cmdline,"whoami")){
c002074a:	bd 07 00 00 00       	mov    $0x7,%ebp
      strlcpy(cmdline,"",50);
c002074f:	c7 44 24 08 32 00 00 	movl   $0x32,0x8(%esp)
c0020756:	00 
c0020757:	c7 44 24 04 eb ed 02 	movl   $0xc002edeb,0x4(%esp)
c002075e:	c0 
c002075f:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020763:	89 04 24             	mov    %eax,(%esp)
c0020766:	e8 2b 78 00 00       	call   c0027f96 <strlcpy>
      printf("ICS143A>");
c002076b:	c7 04 24 ea e1 02 c0 	movl   $0xc002e1ea,(%esp)
c0020772:	e8 b7 63 00 00       	call   c0026b2e <printf>
        char l = input_getc();
c0020777:	e8 42 56 00 00       	call   c0025dbe <input_getc>
c002077c:	89 c3                	mov    %eax,%ebx
        while(l != '\n'){
c002077e:	3c 0a                	cmp    $0xa,%al
c0020780:	74 24                	je     c00207a6 <pintos_init+0x5de>
c0020782:	be 00 00 00 00       	mov    $0x0,%esi
          printf("%c",l);
c0020787:	0f be c3             	movsbl %bl,%eax
c002078a:	89 04 24             	mov    %eax,(%esp)
c002078d:	e8 8a 9f 00 00       	call   c002a71c <putchar>
          cmdline[i] = l;
c0020792:	88 5c 34 3c          	mov    %bl,0x3c(%esp,%esi,1)
          l = input_getc();
c0020796:	e8 23 56 00 00       	call   c0025dbe <input_getc>
c002079b:	89 c3                	mov    %eax,%ebx
          i++;
c002079d:	83 c6 01             	add    $0x1,%esi
        while(l != '\n'){
c00207a0:	3c 0a                	cmp    $0xa,%al
c00207a2:	75 e3                	jne    c0020787 <pintos_init+0x5bf>
c00207a4:	eb 05                	jmp    c00207ab <pintos_init+0x5e3>
c00207a6:	be 00 00 00 00       	mov    $0x0,%esi
        cmdline[i] = '\0';
c00207ab:	c6 44 34 3c 00       	movb   $0x0,0x3c(%esp,%esi,1)
        if(!strcmp(cmdline,"whoami")){
c00207b0:	bf f3 e1 02 c0       	mov    $0xc002e1f3,%edi
c00207b5:	8d 74 24 3c          	lea    0x3c(%esp),%esi
c00207b9:	89 e9                	mov    %ebp,%ecx
c00207bb:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00207bd:	0f 97 c2             	seta   %dl
c00207c0:	0f 92 c0             	setb   %al
c00207c3:	38 c2                	cmp    %al,%dl
c00207c5:	75 0e                	jne    c00207d5 <pintos_init+0x60d>
          printf("\nSydney Eads\n");
c00207c7:	c7 04 24 fa e1 02 c0 	movl   $0xc002e1fa,(%esp)
c00207ce:	e8 d8 9e 00 00       	call   c002a6ab <puts>
c00207d3:	eb 34                	jmp    c0020809 <pintos_init+0x641>
        else if(!strcmp(cmdline,"exit")){
c00207d5:	bf 07 e2 02 c0       	mov    $0xc002e207,%edi
c00207da:	b9 05 00 00 00       	mov    $0x5,%ecx
c00207df:	8d 74 24 3c          	lea    0x3c(%esp),%esi
c00207e3:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00207e5:	0f 97 c2             	seta   %dl
c00207e8:	0f 92 c0             	setb   %al
c00207eb:	38 c2                	cmp    %al,%dl
c00207ed:	75 0e                	jne    c00207fd <pintos_init+0x635>
          printf("\n");
c00207ef:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00207f6:	e8 21 9f 00 00       	call   c002a71c <putchar>
c00207fb:	eb 26                	jmp    c0020823 <pintos_init+0x65b>
          printf("\ninvalid command\n");
c00207fd:	c7 04 24 0c e2 02 c0 	movl   $0xc002e20c,(%esp)
c0020804:	e8 a2 9e 00 00       	call   c002a6ab <puts>
        memset(&cmdline[0], 0, sizeof(cmdline));
c0020809:	b9 0c 00 00 00       	mov    $0xc,%ecx
c002080e:	b8 00 00 00 00       	mov    $0x0,%eax
c0020813:	8d 7c 24 3c          	lea    0x3c(%esp),%edi
c0020817:	f3 ab                	rep stos %eax,%es:(%edi)
c0020819:	66 c7 07 00 00       	movw   $0x0,(%edi)
    }
c002081e:	e9 2c ff ff ff       	jmp    c002074f <pintos_init+0x587>
  shutdown ();
c0020823:	e8 68 5c 00 00       	call   c0026490 <shutdown>
  thread_exit ();
c0020828:	e8 8b 0b 00 00       	call   c00213b8 <thread_exit>
  argv[argc] = NULL;
c002082d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020834:	00 00 00 00 
  printf ("Kernel command line:");
c0020838:	c7 04 24 1d e2 02 c0 	movl   $0xc002e21d,(%esp)
c002083f:	e8 ea 62 00 00       	call   c0026b2e <printf>
c0020844:	e9 74 fa ff ff       	jmp    c00202bd <pintos_init+0xf5>
c0020849:	90                   	nop
c002084a:	90                   	nop
c002084b:	90                   	nop
c002084c:	90                   	nop
c002084d:	90                   	nop
c002084e:	90                   	nop
c002084f:	90                   	nop

c0020850 <threadPrioCompare>:
static bool threadPrioCompare(const struct list_elem *t1,
                             const struct list_elem *t2, void *aux UNUSED)
{ 
  const struct thread *tPointer1 = list_entry (t1, struct thread, elem);
  const struct thread *tPointer2 = list_entry (t2, struct thread, elem);
  if(tPointer1->priority < tPointer2->priority){
c0020850:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020854:	8b 54 24 04          	mov    0x4(%esp),%edx
c0020858:	8b 40 f4             	mov    -0xc(%eax),%eax
c002085b:	39 42 f4             	cmp    %eax,-0xc(%edx)
c002085e:	0f 9c c0             	setl   %al
    return true;
  }
  else{
    return false;
  }
}
c0020861:	c3                   	ret    

c0020862 <alloc_frame>:

/* Allocates a SIZE-byte frame at the top of thread T's stack and
   returns a pointer to the frame's base. */
static void *
alloc_frame (struct thread *t, size_t size) 
{
c0020862:	83 ec 2c             	sub    $0x2c,%esp
c0020865:	89 c1                	mov    %eax,%ecx
  return t != NULL && t->magic == THREAD_MAGIC;
c0020867:	85 c0                	test   %eax,%eax
c0020869:	74 3e                	je     c00208a9 <alloc_frame+0x47>
c002086b:	81 78 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%eax)
c0020872:	75 35                	jne    c00208a9 <alloc_frame+0x47>
c0020874:	eb 2c                	jmp    c00208a2 <alloc_frame+0x40>
  /* Stack data is always allocated in word-size units. */
  ASSERT (is_thread (t));
  ASSERT (size % sizeof (uint32_t) == 0);
c0020876:	c7 44 24 10 bc e4 02 	movl   $0xc002e4bc,0x10(%esp)
c002087d:	c0 
c002087e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020885:	c0 
c0020886:	c7 44 24 08 fe d0 02 	movl   $0xc002d0fe,0x8(%esp)
c002088d:	c0 
c002088e:	c7 44 24 04 25 03 00 	movl   $0x325,0x4(%esp)
c0020895:	00 
c0020896:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c002089d:	e8 e1 80 00 00       	call   c0028983 <debug_panic>
c00208a2:	f6 c2 03             	test   $0x3,%dl
c00208a5:	74 2e                	je     c00208d5 <alloc_frame+0x73>
c00208a7:	eb cd                	jmp    c0020876 <alloc_frame+0x14>
  ASSERT (is_thread (t));
c00208a9:	c7 44 24 10 f1 e4 02 	movl   $0xc002e4f1,0x10(%esp)
c00208b0:	c0 
c00208b1:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00208b8:	c0 
c00208b9:	c7 44 24 08 fe d0 02 	movl   $0xc002d0fe,0x8(%esp)
c00208c0:	c0 
c00208c1:	c7 44 24 04 24 03 00 	movl   $0x324,0x4(%esp)
c00208c8:	00 
c00208c9:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00208d0:	e8 ae 80 00 00       	call   c0028983 <debug_panic>

  t->stack -= size;
c00208d5:	8b 40 18             	mov    0x18(%eax),%eax
c00208d8:	29 d0                	sub    %edx,%eax
c00208da:	89 41 18             	mov    %eax,0x18(%ecx)
  return t->stack;
}
c00208dd:	83 c4 2c             	add    $0x2c,%esp
c00208e0:	c3                   	ret    

c00208e1 <init_f_value>:
{
c00208e1:	b8 0d 00 00 00       	mov    $0xd,%eax
c00208e6:	ba 02 00 00 00       	mov    $0x2,%edx
        f = f*2;
c00208eb:	01 d2                	add    %edx,%edx
    while(i < 14)
c00208ed:	83 e8 01             	sub    $0x1,%eax
c00208f0:	75 f9                	jne    c00208eb <init_f_value+0xa>
c00208f2:	89 15 c0 5b 03 c0    	mov    %edx,0xc0035bc0
c00208f8:	c3                   	ret    

c00208f9 <convertNtoFixedPoint>:
    return n * f;
c00208f9:	8b 44 24 04          	mov    0x4(%esp),%eax
c00208fd:	0f af 05 c0 5b 03 c0 	imul   0xc0035bc0,%eax
}
c0020904:	c3                   	ret    

c0020905 <convertXtoInt>:
{
c0020905:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / f;
c0020909:	99                   	cltd   
c002090a:	f7 3d c0 5b 03 c0    	idivl  0xc0035bc0
}
c0020910:	c3                   	ret    

c0020911 <convertXtoIntRoundNear>:
{
c0020911:	8b 44 24 04          	mov    0x4(%esp),%eax
    if(x >= 0)
c0020915:	85 c0                	test   %eax,%eax
c0020917:	78 15                	js     c002092e <convertXtoIntRoundNear+0x1d>
        return (x + f / 2) / f;
c0020919:	8b 0d c0 5b 03 c0    	mov    0xc0035bc0,%ecx
c002091f:	89 ca                	mov    %ecx,%edx
c0020921:	c1 ea 1f             	shr    $0x1f,%edx
c0020924:	01 ca                	add    %ecx,%edx
c0020926:	d1 fa                	sar    %edx
c0020928:	01 d0                	add    %edx,%eax
c002092a:	99                   	cltd   
c002092b:	f7 f9                	idiv   %ecx
c002092d:	c3                   	ret    
        return (x - f / 2) / f;
c002092e:	8b 0d c0 5b 03 c0    	mov    0xc0035bc0,%ecx
c0020934:	89 ca                	mov    %ecx,%edx
c0020936:	c1 ea 1f             	shr    $0x1f,%edx
c0020939:	01 ca                	add    %ecx,%edx
c002093b:	d1 fa                	sar    %edx
c002093d:	29 d0                	sub    %edx,%eax
c002093f:	99                   	cltd   
c0020940:	f7 f9                	idiv   %ecx
}
c0020942:	c3                   	ret    

c0020943 <init_thread>:
{
c0020943:	55                   	push   %ebp
c0020944:	57                   	push   %edi
c0020945:	56                   	push   %esi
c0020946:	53                   	push   %ebx
c0020947:	83 ec 2c             	sub    $0x2c,%esp
c002094a:	89 c3                	mov    %eax,%ebx
  ASSERT (t != NULL);
c002094c:	85 c0                	test   %eax,%eax
c002094e:	75 2c                	jne    c002097c <init_thread+0x39>
c0020950:	c7 44 24 10 37 fa 02 	movl   $0xc002fa37,0x10(%esp)
c0020957:	c0 
c0020958:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002095f:	c0 
c0020960:	c7 44 24 08 26 d1 02 	movl   $0xc002d126,0x8(%esp)
c0020967:	c0 
c0020968:	c7 44 24 04 f7 02 00 	movl   $0x2f7,0x4(%esp)
c002096f:	00 
c0020970:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020977:	e8 07 80 00 00       	call   c0028983 <debug_panic>
c002097c:	89 ce                	mov    %ecx,%esi
  ASSERT (PRI_MIN <= priority && priority <= PRI_MAX);
c002097e:	83 f9 3f             	cmp    $0x3f,%ecx
c0020981:	76 2c                	jbe    c00209af <init_thread+0x6c>
c0020983:	c7 44 24 10 e0 e5 02 	movl   $0xc002e5e0,0x10(%esp)
c002098a:	c0 
c002098b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020992:	c0 
c0020993:	c7 44 24 08 26 d1 02 	movl   $0xc002d126,0x8(%esp)
c002099a:	c0 
c002099b:	c7 44 24 04 f8 02 00 	movl   $0x2f8,0x4(%esp)
c00209a2:	00 
c00209a3:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00209aa:	e8 d4 7f 00 00       	call   c0028983 <debug_panic>
  ASSERT (name != NULL);
c00209af:	85 d2                	test   %edx,%edx
c00209b1:	75 2c                	jne    c00209df <init_thread+0x9c>
c00209b3:	c7 44 24 10 ff e4 02 	movl   $0xc002e4ff,0x10(%esp)
c00209ba:	c0 
c00209bb:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00209c2:	c0 
c00209c3:	c7 44 24 08 26 d1 02 	movl   $0xc002d126,0x8(%esp)
c00209ca:	c0 
c00209cb:	c7 44 24 04 f9 02 00 	movl   $0x2f9,0x4(%esp)
c00209d2:	00 
c00209d3:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00209da:	e8 a4 7f 00 00       	call   c0028983 <debug_panic>
  memset (t, 0, sizeof *t);
c00209df:	89 c7                	mov    %eax,%edi
c00209e1:	bd 5c 00 00 00       	mov    $0x5c,%ebp
c00209e6:	a8 01                	test   $0x1,%al
c00209e8:	74 0a                	je     c00209f4 <init_thread+0xb1>
c00209ea:	c6 00 00             	movb   $0x0,(%eax)
c00209ed:	8d 78 01             	lea    0x1(%eax),%edi
c00209f0:	66 bd 5b 00          	mov    $0x5b,%bp
c00209f4:	f7 c7 02 00 00 00    	test   $0x2,%edi
c00209fa:	74 0b                	je     c0020a07 <init_thread+0xc4>
c00209fc:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0020a01:	83 c7 02             	add    $0x2,%edi
c0020a04:	83 ed 02             	sub    $0x2,%ebp
c0020a07:	89 e9                	mov    %ebp,%ecx
c0020a09:	c1 e9 02             	shr    $0x2,%ecx
c0020a0c:	b8 00 00 00 00       	mov    $0x0,%eax
c0020a11:	f3 ab                	rep stos %eax,%es:(%edi)
c0020a13:	f7 c5 02 00 00 00    	test   $0x2,%ebp
c0020a19:	74 08                	je     c0020a23 <init_thread+0xe0>
c0020a1b:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0020a20:	83 c7 02             	add    $0x2,%edi
c0020a23:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c0020a29:	74 03                	je     c0020a2e <init_thread+0xeb>
c0020a2b:	c6 07 00             	movb   $0x0,(%edi)
  t->status = THREAD_BLOCKED;
c0020a2e:	c7 43 04 02 00 00 00 	movl   $0x2,0x4(%ebx)
  strlcpy (t->name, name, sizeof t->name);
c0020a35:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c0020a3c:	00 
c0020a3d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020a41:	8d 43 08             	lea    0x8(%ebx),%eax
c0020a44:	89 04 24             	mov    %eax,(%esp)
c0020a47:	e8 4a 75 00 00       	call   c0027f96 <strlcpy>
  t->stack = (uint8_t *) t + PGSIZE;
c0020a4c:	8d 83 00 10 00 00    	lea    0x1000(%ebx),%eax
c0020a52:	89 43 18             	mov    %eax,0x18(%ebx)
  t->priority = priority;
c0020a55:	89 73 1c             	mov    %esi,0x1c(%ebx)
  t->magic = THREAD_MAGIC;
c0020a58:	c7 43 30 4b bf 6a cd 	movl   $0xcd6abf4b,0x30(%ebx)
  list_push_back (&all_list, &t->allelem);
c0020a5f:	8d 43 20             	lea    0x20(%ebx),%eax
c0020a62:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020a66:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020a6d:	e8 5f 85 00 00       	call   c0028fd1 <list_push_back>
  if(!thread_mlfqs)
c0020a72:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0020a79:	75 08                	jne    c0020a83 <init_thread+0x140>
    t->priority = priority;
c0020a7b:	89 73 1c             	mov    %esi,0x1c(%ebx)
    t->old_priority = priority;
c0020a7e:	89 73 3c             	mov    %esi,0x3c(%ebx)
c0020a81:	eb 43                	jmp    c0020ac6 <init_thread+0x183>
    t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020a83:	8b 43 58             	mov    0x58(%ebx),%eax
c0020a86:	8d 50 03             	lea    0x3(%eax),%edx
c0020a89:	85 c0                	test   %eax,%eax
c0020a8b:	0f 48 c2             	cmovs  %edx,%eax
c0020a8e:	c1 f8 02             	sar    $0x2,%eax
c0020a91:	89 04 24             	mov    %eax,(%esp)
c0020a94:	e8 78 fe ff ff       	call   c0020911 <convertXtoIntRoundNear>
c0020a99:	ba 3f 00 00 00       	mov    $0x3f,%edx
c0020a9e:	29 c2                	sub    %eax,%edx
c0020aa0:	89 d0                	mov    %edx,%eax
c0020aa2:	8b 53 54             	mov    0x54(%ebx),%edx
c0020aa5:	f7 da                	neg    %edx
c0020aa7:	8d 04 50             	lea    (%eax,%edx,2),%eax
c0020aaa:	89 43 1c             	mov    %eax,0x1c(%ebx)
    if(t->priority > PRI_MAX)
c0020aad:	83 f8 3f             	cmp    $0x3f,%eax
c0020ab0:	7e 09                	jle    c0020abb <init_thread+0x178>
      t->priority = PRI_MAX;
c0020ab2:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c0020ab9:	eb 0b                	jmp    c0020ac6 <init_thread+0x183>
    if(t->priority < PRI_MIN)
c0020abb:	85 c0                	test   %eax,%eax
c0020abd:	79 07                	jns    c0020ac6 <init_thread+0x183>
      t->priority = PRI_MIN;
c0020abf:	c7 43 1c 00 00 00 00 	movl   $0x0,0x1c(%ebx)
  list_init (&t->locks_held);
c0020ac6:	8d 43 40             	lea    0x40(%ebx),%eax
c0020ac9:	89 04 24             	mov    %eax,(%esp)
c0020acc:	e8 7f 7f 00 00       	call   c0028a50 <list_init>
  t->wait_on_lock = NULL;
c0020ad1:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
}
c0020ad8:	83 c4 2c             	add    $0x2c,%esp
c0020adb:	5b                   	pop    %ebx
c0020adc:	5e                   	pop    %esi
c0020add:	5f                   	pop    %edi
c0020ade:	5d                   	pop    %ebp
c0020adf:	c3                   	ret    

c0020ae0 <addXandY>:
    return x + y;
c0020ae0:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020ae4:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020ae8:	c3                   	ret    

c0020ae9 <subtractYfromX>:
    return x - y;
c0020ae9:	8b 44 24 04          	mov    0x4(%esp),%eax
c0020aed:	2b 44 24 08          	sub    0x8(%esp),%eax
}
c0020af1:	c3                   	ret    

c0020af2 <addXandN>:
    return x + (n * f);
c0020af2:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020af6:	0f af 05 c0 5b 03 c0 	imul   0xc0035bc0,%eax
c0020afd:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020b01:	c3                   	ret    

c0020b02 <subNfromX>:
    return x - (n * f);
c0020b02:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b06:	0f af 05 c0 5b 03 c0 	imul   0xc0035bc0,%eax
c0020b0d:	8b 54 24 04          	mov    0x4(%esp),%edx
c0020b11:	29 c2                	sub    %eax,%edx
c0020b13:	89 d0                	mov    %edx,%eax
}
c0020b15:	c3                   	ret    

c0020b16 <multXbyY>:
{
c0020b16:	57                   	push   %edi
c0020b17:	56                   	push   %esi
c0020b18:	53                   	push   %ebx
c0020b19:	83 ec 10             	sub    $0x10,%esp
c0020b1c:	8b 54 24 20          	mov    0x20(%esp),%edx
c0020b20:	8b 44 24 24          	mov    0x24(%esp),%eax
    return ((int64_t) x) * y / f;
c0020b24:	89 d7                	mov    %edx,%edi
c0020b26:	c1 ff 1f             	sar    $0x1f,%edi
c0020b29:	89 c3                	mov    %eax,%ebx
c0020b2b:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b2e:	89 fe                	mov    %edi,%esi
c0020b30:	0f af f0             	imul   %eax,%esi
c0020b33:	89 d9                	mov    %ebx,%ecx
c0020b35:	0f af ca             	imul   %edx,%ecx
c0020b38:	01 f1                	add    %esi,%ecx
c0020b3a:	f7 e2                	mul    %edx
c0020b3c:	01 ca                	add    %ecx,%edx
c0020b3e:	8b 0d c0 5b 03 c0    	mov    0xc0035bc0,%ecx
c0020b44:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020b48:	89 cb                	mov    %ecx,%ebx
c0020b4a:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b4d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020b51:	89 04 24             	mov    %eax,(%esp)
c0020b54:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020b58:	e8 86 77 00 00       	call   c00282e3 <__divdi3>
}
c0020b5d:	83 c4 10             	add    $0x10,%esp
c0020b60:	5b                   	pop    %ebx
c0020b61:	5e                   	pop    %esi
c0020b62:	5f                   	pop    %edi
c0020b63:	c3                   	ret    

c0020b64 <multXbyN>:
    return x * n;
c0020b64:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b68:	0f af 44 24 04       	imul   0x4(%esp),%eax
}
c0020b6d:	c3                   	ret    

c0020b6e <divXbyY>:
{
c0020b6e:	57                   	push   %edi
c0020b6f:	56                   	push   %esi
c0020b70:	53                   	push   %ebx
c0020b71:	83 ec 10             	sub    $0x10,%esp
c0020b74:	8b 54 24 20          	mov    0x20(%esp),%edx
    return ((int64_t) x) * f / y;
c0020b78:	89 d7                	mov    %edx,%edi
c0020b7a:	c1 ff 1f             	sar    $0x1f,%edi
c0020b7d:	a1 c0 5b 03 c0       	mov    0xc0035bc0,%eax
c0020b82:	89 c3                	mov    %eax,%ebx
c0020b84:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b87:	89 fe                	mov    %edi,%esi
c0020b89:	0f af f0             	imul   %eax,%esi
c0020b8c:	89 d9                	mov    %ebx,%ecx
c0020b8e:	0f af ca             	imul   %edx,%ecx
c0020b91:	01 f1                	add    %esi,%ecx
c0020b93:	f7 e2                	mul    %edx
c0020b95:	01 ca                	add    %ecx,%edx
c0020b97:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c0020b9b:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020b9f:	89 cb                	mov    %ecx,%ebx
c0020ba1:	c1 fb 1f             	sar    $0x1f,%ebx
c0020ba4:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020ba8:	89 04 24             	mov    %eax,(%esp)
c0020bab:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020baf:	e8 2f 77 00 00       	call   c00282e3 <__divdi3>
}
c0020bb4:	83 c4 10             	add    $0x10,%esp
c0020bb7:	5b                   	pop    %ebx
c0020bb8:	5e                   	pop    %esi
c0020bb9:	5f                   	pop    %edi
c0020bba:	c3                   	ret    

c0020bbb <divXbyN>:
{
c0020bbb:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / n;
c0020bbf:	99                   	cltd   
c0020bc0:	f7 7c 24 08          	idivl  0x8(%esp)
}
c0020bc4:	c3                   	ret    

c0020bc5 <thread_init>:
{
c0020bc5:	56                   	push   %esi
c0020bc6:	53                   	push   %ebx
c0020bc7:	83 ec 24             	sub    $0x24,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0020bca:	e8 a5 0d 00 00       	call   c0021974 <intr_get_level>
c0020bcf:	85 c0                	test   %eax,%eax
c0020bd1:	74 2c                	je     c0020bff <thread_init+0x3a>
c0020bd3:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0020bda:	c0 
c0020bdb:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020be2:	c0 
c0020be3:	c7 44 24 08 32 d1 02 	movl   $0xc002d132,0x8(%esp)
c0020bea:	c0 
c0020beb:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
c0020bf2:	00 
c0020bf3:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020bfa:	e8 84 7d 00 00       	call   c0028983 <debug_panic>
  lock_init (&tid_lock);
c0020bff:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020c06:	e8 b2 21 00 00       	call   c0022dbd <lock_init>
  list_init (&all_list);
c0020c0b:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020c12:	e8 39 7e 00 00       	call   c0028a50 <list_init>
  if(thread_mlfqs) {
c0020c17:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0020c1e:	74 1b                	je     c0020c3b <thread_init+0x76>
c0020c20:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0020c25:	be 20 60 03 c0       	mov    $0xc0036020,%esi
      list_init (&mlfqs_list[i]);
c0020c2a:	89 1c 24             	mov    %ebx,(%esp)
c0020c2d:	e8 1e 7e 00 00       	call   c0028a50 <list_init>
c0020c32:	83 c3 10             	add    $0x10,%ebx
    for(i=0;i<64;i++)
c0020c35:	39 f3                	cmp    %esi,%ebx
c0020c37:	75 f1                	jne    c0020c2a <thread_init+0x65>
c0020c39:	eb 0c                	jmp    c0020c47 <thread_init+0x82>
    list_init (&ready_list);
c0020c3b:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020c42:	e8 09 7e 00 00       	call   c0028a50 <list_init>
  init_f_value(); //initialize floating point arithmatic
c0020c47:	e8 95 fc ff ff       	call   c00208e1 <init_f_value>
  initial_thread->nice = 0; //nice value of first thread is zero
c0020c4c:	a1 04 5c 03 c0       	mov    0xc0035c04,%eax
c0020c51:	c7 40 54 00 00 00 00 	movl   $0x0,0x54(%eax)
  initial_thread->recent_cpu = 0; //recent_cpu of first thread is zero
c0020c58:	c7 40 58 00 00 00 00 	movl   $0x0,0x58(%eax)
  asm ("mov %%esp, %0" : "=g" (esp));
c0020c5f:	89 e0                	mov    %esp,%eax
  return (void *) ((uintptr_t) va & ~PGMASK);
c0020c61:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  initial_thread = running_thread ();
c0020c66:	a3 04 5c 03 c0       	mov    %eax,0xc0035c04
  init_thread (initial_thread, "main", PRI_DEFAULT);
c0020c6b:	b9 1f 00 00 00       	mov    $0x1f,%ecx
c0020c70:	ba 2a e5 02 c0       	mov    $0xc002e52a,%edx
c0020c75:	e8 c9 fc ff ff       	call   c0020943 <init_thread>
  initial_thread->status = THREAD_RUNNING;
c0020c7a:	8b 1d 04 5c 03 c0    	mov    0xc0035c04,%ebx
c0020c80:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
allocate_tid (void) 
{
  static tid_t next_tid = 1;
  tid_t tid;

  lock_acquire (&tid_lock);
c0020c87:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020c8e:	e8 c7 21 00 00       	call   c0022e5a <lock_acquire>
  tid = next_tid++;
c0020c93:	8b 35 50 56 03 c0    	mov    0xc0035650,%esi
c0020c99:	8d 46 01             	lea    0x1(%esi),%eax
c0020c9c:	a3 50 56 03 c0       	mov    %eax,0xc0035650
  lock_release (&tid_lock);
c0020ca1:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020ca8:	e8 77 23 00 00       	call   c0023024 <lock_release>
  initial_thread->tid = allocate_tid ();
c0020cad:	89 33                	mov    %esi,(%ebx)
}
c0020caf:	83 c4 24             	add    $0x24,%esp
c0020cb2:	5b                   	pop    %ebx
c0020cb3:	5e                   	pop    %esi
c0020cb4:	c3                   	ret    

c0020cb5 <thread_print_stats>:
{
c0020cb5:	83 ec 2c             	sub    $0x2c,%esp
  printf ("Thread: %lld idle ticks, %lld kernel ticks, %lld user ticks\n",
c0020cb8:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0020cbf:	00 
c0020cc0:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c0020cc7:	00 
c0020cc8:	a1 c8 5b 03 c0       	mov    0xc0035bc8,%eax
c0020ccd:	8b 15 cc 5b 03 c0    	mov    0xc0035bcc,%edx
c0020cd3:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0020cd7:	89 54 24 10          	mov    %edx,0x10(%esp)
c0020cdb:	a1 d0 5b 03 c0       	mov    0xc0035bd0,%eax
c0020ce0:	8b 15 d4 5b 03 c0    	mov    0xc0035bd4,%edx
c0020ce6:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020cea:	89 54 24 08          	mov    %edx,0x8(%esp)
c0020cee:	c7 04 24 0c e6 02 c0 	movl   $0xc002e60c,(%esp)
c0020cf5:	e8 34 5e 00 00       	call   c0026b2e <printf>
}
c0020cfa:	83 c4 2c             	add    $0x2c,%esp
c0020cfd:	c3                   	ret    

c0020cfe <thread_unblock>:
{
c0020cfe:	56                   	push   %esi
c0020cff:	53                   	push   %ebx
c0020d00:	83 ec 24             	sub    $0x24,%esp
c0020d03:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  return t != NULL && t->magic == THREAD_MAGIC;
c0020d07:	85 db                	test   %ebx,%ebx
c0020d09:	0f 84 98 00 00 00    	je     c0020da7 <thread_unblock+0xa9>
c0020d0f:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c0020d16:	0f 85 8b 00 00 00    	jne    c0020da7 <thread_unblock+0xa9>
c0020d1c:	eb 75                	jmp    c0020d93 <thread_unblock+0x95>
  ASSERT (t->status == THREAD_BLOCKED);
c0020d1e:	c7 44 24 10 2f e5 02 	movl   $0xc002e52f,0x10(%esp)
c0020d25:	c0 
c0020d26:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020d2d:	c0 
c0020d2e:	c7 44 24 08 d9 d0 02 	movl   $0xc002d0d9,0x8(%esp)
c0020d35:	c0 
c0020d36:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
c0020d3d:	00 
c0020d3e:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020d45:	e8 39 7c 00 00       	call   c0028983 <debug_panic>
  if(thread_mlfqs) {
c0020d4a:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0020d51:	74 1c                	je     c0020d6f <thread_unblock+0x71>
    list_push_back (&mlfqs_list[t->priority], &t->elem);
c0020d53:	8d 43 28             	lea    0x28(%ebx),%eax
c0020d56:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020d5a:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0020d5d:	c1 e0 04             	shl    $0x4,%eax
c0020d60:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c0020d65:	89 04 24             	mov    %eax,(%esp)
c0020d68:	e8 64 82 00 00       	call   c0028fd1 <list_push_back>
c0020d6d:	eb 13                	jmp    c0020d82 <thread_unblock+0x84>
    list_push_back (&ready_list, &t->elem);
c0020d6f:	8d 53 28             	lea    0x28(%ebx),%edx
c0020d72:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020d76:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020d7d:	e8 4f 82 00 00       	call   c0028fd1 <list_push_back>
  t->status = THREAD_READY;
c0020d82:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  intr_set_level (old_level);
c0020d89:	89 34 24             	mov    %esi,(%esp)
c0020d8c:	e8 35 0c 00 00       	call   c00219c6 <intr_set_level>
c0020d91:	eb 40                	jmp    c0020dd3 <thread_unblock+0xd5>
  old_level = intr_disable ();
c0020d93:	e8 27 0c 00 00       	call   c00219bf <intr_disable>
c0020d98:	89 c6                	mov    %eax,%esi
  ASSERT (t->status == THREAD_BLOCKED);
c0020d9a:	83 7b 04 02          	cmpl   $0x2,0x4(%ebx)
c0020d9e:	66 90                	xchg   %ax,%ax
c0020da0:	74 a8                	je     c0020d4a <thread_unblock+0x4c>
c0020da2:	e9 77 ff ff ff       	jmp    c0020d1e <thread_unblock+0x20>
  ASSERT (is_thread (t));
c0020da7:	c7 44 24 10 f1 e4 02 	movl   $0xc002e4f1,0x10(%esp)
c0020dae:	c0 
c0020daf:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020db6:	c0 
c0020db7:	c7 44 24 08 d9 d0 02 	movl   $0xc002d0d9,0x8(%esp)
c0020dbe:	c0 
c0020dbf:	c7 44 24 04 7e 01 00 	movl   $0x17e,0x4(%esp)
c0020dc6:	00 
c0020dc7:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020dce:	e8 b0 7b 00 00       	call   c0028983 <debug_panic>
}
c0020dd3:	83 c4 24             	add    $0x24,%esp
c0020dd6:	5b                   	pop    %ebx
c0020dd7:	5e                   	pop    %esi
c0020dd8:	c3                   	ret    

c0020dd9 <thread_current>:
{
c0020dd9:	83 ec 2c             	sub    $0x2c,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0020ddc:	89 e0                	mov    %esp,%eax
  return t != NULL && t->magic == THREAD_MAGIC;
c0020dde:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0020de3:	74 3f                	je     c0020e24 <thread_current+0x4b>
c0020de5:	81 78 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%eax)
c0020dec:	75 36                	jne    c0020e24 <thread_current+0x4b>
c0020dee:	eb 2c                	jmp    c0020e1c <thread_current+0x43>
  ASSERT (t->status == THREAD_RUNNING);
c0020df0:	c7 44 24 10 4b e5 02 	movl   $0xc002e54b,0x10(%esp)
c0020df7:	c0 
c0020df8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020dff:	c0 
c0020e00:	c7 44 24 08 ca d0 02 	movl   $0xc002d0ca,0x8(%esp)
c0020e07:	c0 
c0020e08:	c7 44 24 04 ae 01 00 	movl   $0x1ae,0x4(%esp)
c0020e0f:	00 
c0020e10:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020e17:	e8 67 7b 00 00       	call   c0028983 <debug_panic>
c0020e1c:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0020e20:	74 2e                	je     c0020e50 <thread_current+0x77>
c0020e22:	eb cc                	jmp    c0020df0 <thread_current+0x17>
  ASSERT (is_thread (t));
c0020e24:	c7 44 24 10 f1 e4 02 	movl   $0xc002e4f1,0x10(%esp)
c0020e2b:	c0 
c0020e2c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020e33:	c0 
c0020e34:	c7 44 24 08 ca d0 02 	movl   $0xc002d0ca,0x8(%esp)
c0020e3b:	c0 
c0020e3c:	c7 44 24 04 ad 01 00 	movl   $0x1ad,0x4(%esp)
c0020e43:	00 
c0020e44:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020e4b:	e8 33 7b 00 00       	call   c0028983 <debug_panic>
}
c0020e50:	83 c4 2c             	add    $0x2c,%esp
c0020e53:	c3                   	ret    

c0020e54 <thread_tick>:
{
c0020e54:	83 ec 0c             	sub    $0xc,%esp
  struct thread *t = thread_current ();
c0020e57:	e8 7d ff ff ff       	call   c0020dd9 <thread_current>
  if (t == idle_thread)
c0020e5c:	3b 05 08 5c 03 c0    	cmp    0xc0035c08,%eax
c0020e62:	75 10                	jne    c0020e74 <thread_tick+0x20>
    idle_ticks++;
c0020e64:	83 05 d0 5b 03 c0 01 	addl   $0x1,0xc0035bd0
c0020e6b:	83 15 d4 5b 03 c0 00 	adcl   $0x0,0xc0035bd4
c0020e72:	eb 0e                	jmp    c0020e82 <thread_tick+0x2e>
    kernel_ticks++;
c0020e74:	83 05 c8 5b 03 c0 01 	addl   $0x1,0xc0035bc8
c0020e7b:	83 15 cc 5b 03 c0 00 	adcl   $0x0,0xc0035bcc
  if (++thread_ticks >= TIME_SLICE)
c0020e82:	a1 c4 5b 03 c0       	mov    0xc0035bc4,%eax
c0020e87:	83 c0 01             	add    $0x1,%eax
c0020e8a:	a3 c4 5b 03 c0       	mov    %eax,0xc0035bc4
c0020e8f:	83 f8 03             	cmp    $0x3,%eax
c0020e92:	76 05                	jbe    c0020e99 <thread_tick+0x45>
    intr_yield_on_return ();
c0020e94:	e8 90 0d 00 00       	call   c0021c29 <intr_yield_on_return>
}
c0020e99:	83 c4 0c             	add    $0xc,%esp
c0020e9c:	c3                   	ret    

c0020e9d <thread_name>:
{
c0020e9d:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->name;
c0020ea0:	e8 34 ff ff ff       	call   c0020dd9 <thread_current>
c0020ea5:	83 c0 08             	add    $0x8,%eax
}
c0020ea8:	83 c4 0c             	add    $0xc,%esp
c0020eab:	c3                   	ret    

c0020eac <thread_tid>:
{
c0020eac:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->tid;
c0020eaf:	e8 25 ff ff ff       	call   c0020dd9 <thread_current>
c0020eb4:	8b 00                	mov    (%eax),%eax
}
c0020eb6:	83 c4 0c             	add    $0xc,%esp
c0020eb9:	c3                   	ret    

c0020eba <thread_foreach>:
{
c0020eba:	57                   	push   %edi
c0020ebb:	56                   	push   %esi
c0020ebc:	53                   	push   %ebx
c0020ebd:	83 ec 20             	sub    $0x20,%esp
c0020ec0:	8b 74 24 30          	mov    0x30(%esp),%esi
c0020ec4:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0020ec8:	e8 a7 0a 00 00       	call   c0021974 <intr_get_level>
c0020ecd:	85 c0                	test   %eax,%eax
c0020ecf:	74 2c                	je     c0020efd <thread_foreach+0x43>
c0020ed1:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0020ed8:	c0 
c0020ed9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020ee0:	c0 
c0020ee1:	c7 44 24 08 a2 d0 02 	movl   $0xc002d0a2,0x8(%esp)
c0020ee8:	c0 
c0020ee9:	c7 44 24 04 f4 01 00 	movl   $0x1f4,0x4(%esp)
c0020ef0:	00 
c0020ef1:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020ef8:	e8 86 7a 00 00       	call   c0028983 <debug_panic>
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020efd:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f04:	e8 98 7b 00 00       	call   c0028aa1 <list_begin>
c0020f09:	89 c3                	mov    %eax,%ebx
c0020f0b:	eb 16                	jmp    c0020f23 <thread_foreach+0x69>
      func (t, aux);
c0020f0d:	89 7c 24 04          	mov    %edi,0x4(%esp)
      struct thread *t = list_entry (e, struct thread, allelem);
c0020f11:	8d 43 e0             	lea    -0x20(%ebx),%eax
      func (t, aux);
c0020f14:	89 04 24             	mov    %eax,(%esp)
c0020f17:	ff d6                	call   *%esi
       e = list_next (e))
c0020f19:	89 1c 24             	mov    %ebx,(%esp)
c0020f1c:	e8 be 7b 00 00       	call   c0028adf <list_next>
c0020f21:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020f23:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f2a:	e8 04 7c 00 00       	call   c0028b33 <list_end>
c0020f2f:	39 d8                	cmp    %ebx,%eax
c0020f31:	75 da                	jne    c0020f0d <thread_foreach+0x53>
}
c0020f33:	83 c4 20             	add    $0x20,%esp
c0020f36:	5b                   	pop    %ebx
c0020f37:	5e                   	pop    %esi
c0020f38:	5f                   	pop    %edi
c0020f39:	c3                   	ret    

c0020f3a <thread_get_priority>:
{
c0020f3a:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->priority;
c0020f3d:	e8 97 fe ff ff       	call   c0020dd9 <thread_current>
c0020f42:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0020f45:	83 c4 0c             	add    $0xc,%esp
c0020f48:	c3                   	ret    

c0020f49 <thread_get_nice>:
{
c0020f49:	83 ec 0c             	sub    $0xc,%esp
  return thread_current()->nice;
c0020f4c:	e8 88 fe ff ff       	call   c0020dd9 <thread_current>
c0020f51:	8b 40 54             	mov    0x54(%eax),%eax
}
c0020f54:	83 c4 0c             	add    $0xc,%esp
c0020f57:	c3                   	ret    

c0020f58 <thread_get_load_avg>:
{
c0020f58:	83 ec 04             	sub    $0x4,%esp
    return x * n;
c0020f5b:	6b 05 1c 5c 03 c0 64 	imul   $0x64,0xc0035c1c,%eax
  return convertXtoIntRoundNear(i);
c0020f62:	89 04 24             	mov    %eax,(%esp)
c0020f65:	e8 a7 f9 ff ff       	call   c0020911 <convertXtoIntRoundNear>
}
c0020f6a:	83 c4 04             	add    $0x4,%esp
c0020f6d:	c3                   	ret    

c0020f6e <thread_get_recent_cpu>:
{
c0020f6e:	83 ec 1c             	sub    $0x1c,%esp
  int i = multXbyN(thread_current()->recent_cpu,100);
c0020f71:	e8 63 fe ff ff       	call   c0020dd9 <thread_current>
    return x * n;
c0020f76:	6b 40 58 64          	imul   $0x64,0x58(%eax),%eax
  return convertXtoIntRoundNear(i);
c0020f7a:	89 04 24             	mov    %eax,(%esp)
c0020f7d:	e8 8f f9 ff ff       	call   c0020911 <convertXtoIntRoundNear>
}
c0020f82:	83 c4 1c             	add    $0x1c,%esp
c0020f85:	c3                   	ret    

c0020f86 <calculate_recent_cpu>:
{
c0020f86:	55                   	push   %ebp
c0020f87:	57                   	push   %edi
c0020f88:	56                   	push   %esi
c0020f89:	53                   	push   %ebx
c0020f8a:	83 ec 2c             	sub    $0x2c,%esp
c0020f8d:	8b 7c 24 40          	mov    0x40(%esp),%edi
  i = 2 * system_load_avg;
c0020f91:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0020f96:	8d 0c 00             	lea    (%eax,%eax,1),%ecx
    return x + (n * f);
c0020f99:	8b 35 c0 5b 03 c0    	mov    0xc0035bc0,%esi
    return ((int64_t) x) * f / y;
c0020f9f:	89 74 24 18          	mov    %esi,0x18(%esp)
c0020fa3:	89 f0                	mov    %esi,%eax
c0020fa5:	c1 f8 1f             	sar    $0x1f,%eax
c0020fa8:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0020fac:	89 c8                	mov    %ecx,%eax
c0020fae:	99                   	cltd   
c0020faf:	89 d3                	mov    %edx,%ebx
c0020fb1:	0f af de             	imul   %esi,%ebx
c0020fb4:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0020fb8:	0f af c1             	imul   %ecx,%eax
c0020fbb:	01 c3                	add    %eax,%ebx
c0020fbd:	89 c8                	mov    %ecx,%eax
c0020fbf:	f7 e6                	mul    %esi
c0020fc1:	01 da                	add    %ebx,%edx
    return x + (n * f);
c0020fc3:	01 f1                	add    %esi,%ecx
    return ((int64_t) x) * f / y;
c0020fc5:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020fc9:	89 cb                	mov    %ecx,%ebx
c0020fcb:	c1 fb 1f             	sar    $0x1f,%ebx
c0020fce:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020fd2:	89 04 24             	mov    %eax,(%esp)
c0020fd5:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020fd9:	e8 05 73 00 00       	call   c00282e3 <__divdi3>
    return ((int64_t) x) * y / f;
c0020fde:	89 c3                	mov    %eax,%ebx
c0020fe0:	c1 fb 1f             	sar    $0x1f,%ebx
c0020fe3:	8b 6f 58             	mov    0x58(%edi),%ebp
c0020fe6:	89 e9                	mov    %ebp,%ecx
c0020fe8:	c1 f9 1f             	sar    $0x1f,%ecx
c0020feb:	0f af dd             	imul   %ebp,%ebx
c0020fee:	89 ca                	mov    %ecx,%edx
c0020ff0:	0f af d0             	imul   %eax,%edx
c0020ff3:	8d 0c 13             	lea    (%ebx,%edx,1),%ecx
c0020ff6:	f7 e5                	mul    %ebp
c0020ff8:	01 ca                	add    %ecx,%edx
c0020ffa:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c0020ffe:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
c0021002:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0021006:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002100a:	89 04 24             	mov    %eax,(%esp)
c002100d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021011:	e8 cd 72 00 00       	call   c00282e3 <__divdi3>
    return x + (n * f);
c0021016:	0f af 77 54          	imul   0x54(%edi),%esi
c002101a:	01 f0                	add    %esi,%eax
c002101c:	89 47 58             	mov    %eax,0x58(%edi)
}
c002101f:	83 c4 2c             	add    $0x2c,%esp
c0021022:	5b                   	pop    %ebx
c0021023:	5e                   	pop    %esi
c0021024:	5f                   	pop    %edi
c0021025:	5d                   	pop    %ebp
c0021026:	c3                   	ret    

c0021027 <calculate_priority>:
{
c0021027:	56                   	push   %esi
c0021028:	53                   	push   %ebx
c0021029:	83 ec 14             	sub    $0x14,%esp
c002102c:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  int old_p = t->priority;
c0021030:	8b 73 1c             	mov    0x1c(%ebx),%esi
  t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0021033:	8b 43 58             	mov    0x58(%ebx),%eax
c0021036:	8d 50 03             	lea    0x3(%eax),%edx
c0021039:	85 c0                	test   %eax,%eax
c002103b:	0f 48 c2             	cmovs  %edx,%eax
c002103e:	c1 f8 02             	sar    $0x2,%eax
c0021041:	89 04 24             	mov    %eax,(%esp)
c0021044:	e8 c8 f8 ff ff       	call   c0020911 <convertXtoIntRoundNear>
c0021049:	ba 3f 00 00 00       	mov    $0x3f,%edx
c002104e:	29 c2                	sub    %eax,%edx
c0021050:	89 d0                	mov    %edx,%eax
c0021052:	8b 53 54             	mov    0x54(%ebx),%edx
c0021055:	f7 da                	neg    %edx
c0021057:	8d 04 50             	lea    (%eax,%edx,2),%eax
c002105a:	89 43 1c             	mov    %eax,0x1c(%ebx)
  if(t->priority > PRI_MAX)
c002105d:	83 f8 3f             	cmp    $0x3f,%eax
c0021060:	7e 09                	jle    c002106b <calculate_priority+0x44>
    t->priority = PRI_MAX;
c0021062:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c0021069:	eb 0b                	jmp    c0021076 <calculate_priority+0x4f>
  if(t->priority < PRI_MIN)
c002106b:	85 c0                	test   %eax,%eax
c002106d:	79 07                	jns    c0021076 <calculate_priority+0x4f>
    t->priority = PRI_MIN;
c002106f:	c7 43 1c 00 00 00 00 	movl   $0x0,0x1c(%ebx)
  if(old_p != t->priority && t->status == THREAD_READY)
c0021076:	39 73 1c             	cmp    %esi,0x1c(%ebx)
c0021079:	74 28                	je     c00210a3 <calculate_priority+0x7c>
c002107b:	83 7b 04 01          	cmpl   $0x1,0x4(%ebx)
c002107f:	75 22                	jne    c00210a3 <calculate_priority+0x7c>
     list_remove(&t->elem);
c0021081:	8d 73 28             	lea    0x28(%ebx),%esi
c0021084:	89 34 24             	mov    %esi,(%esp)
c0021087:	e8 68 7f 00 00       	call   c0028ff4 <list_remove>
     list_push_back (&mlfqs_list[t->priority], &t->elem);
c002108c:	89 74 24 04          	mov    %esi,0x4(%esp)
c0021090:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021093:	c1 e0 04             	shl    $0x4,%eax
c0021096:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c002109b:	89 04 24             	mov    %eax,(%esp)
c002109e:	e8 2e 7f 00 00       	call   c0028fd1 <list_push_back>
}
c00210a3:	83 c4 14             	add    $0x14,%esp
c00210a6:	5b                   	pop    %ebx
c00210a7:	5e                   	pop    %esi
c00210a8:	c3                   	ret    

c00210a9 <get_ready_threads>:
{
c00210a9:	57                   	push   %edi
c00210aa:	56                   	push   %esi
c00210ab:	53                   	push   %ebx
c00210ac:	83 ec 10             	sub    $0x10,%esp
c00210af:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c00210b4:	bf 20 60 03 c0       	mov    $0xc0036020,%edi
  int i,ready_threads = 0;
c00210b9:	be 00 00 00 00       	mov    $0x0,%esi
     ready_threads += list_size(&mlfqs_list[i]);
c00210be:	89 1c 24             	mov    %ebx,(%esp)
c00210c1:	e8 83 7f 00 00       	call   c0029049 <list_size>
c00210c6:	01 c6                	add    %eax,%esi
c00210c8:	83 c3 10             	add    $0x10,%ebx
  for(i=0;i<64;i++)
c00210cb:	39 fb                	cmp    %edi,%ebx
c00210cd:	75 ef                	jne    c00210be <get_ready_threads+0x15>
  asm ("mov %%esp, %0" : "=g" (esp));
c00210cf:	89 e0                	mov    %esp,%eax
c00210d1:	25 00 f0 ff ff       	and    $0xfffff000,%eax
     ready_threads += 1;
c00210d6:	39 05 08 5c 03 c0    	cmp    %eax,0xc0035c08
c00210dc:	0f 95 c0             	setne  %al
c00210df:	0f b6 c0             	movzbl %al,%eax
c00210e2:	01 c6                	add    %eax,%esi
}
c00210e4:	89 f0                	mov    %esi,%eax
c00210e6:	83 c4 10             	add    $0x10,%esp
c00210e9:	5b                   	pop    %ebx
c00210ea:	5e                   	pop    %esi
c00210eb:	5f                   	pop    %edi
c00210ec:	c3                   	ret    

c00210ed <get_system_load_avg>:
}
c00210ed:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c00210f2:	c3                   	ret    

c00210f3 <set_system_load_avg>:
  system_load_avg = load;
c00210f3:	8b 44 24 04          	mov    0x4(%esp),%eax
c00210f7:	a3 1c 5c 03 c0       	mov    %eax,0xc0035c1c
c00210fc:	c3                   	ret    

c00210fd <get_idle_thread>:
}
c00210fd:	a1 08 5c 03 c0       	mov    0xc0035c08,%eax
c0021102:	c3                   	ret    

c0021103 <thread_schedule_tail>:
{
c0021103:	56                   	push   %esi
c0021104:	53                   	push   %ebx
c0021105:	83 ec 24             	sub    $0x24,%esp
c0021108:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  asm ("mov %%esp, %0" : "=g" (esp));
c002110c:	89 e6                	mov    %esp,%esi
c002110e:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
  ASSERT (intr_get_level () == INTR_OFF);
c0021114:	e8 5b 08 00 00       	call   c0021974 <intr_get_level>
c0021119:	85 c0                	test   %eax,%eax
c002111b:	74 2c                	je     c0021149 <thread_schedule_tail+0x46>
c002111d:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0021124:	c0 
c0021125:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002112c:	c0 
c002112d:	c7 44 24 08 79 d0 02 	movl   $0xc002d079,0x8(%esp)
c0021134:	c0 
c0021135:	c7 44 24 04 67 03 00 	movl   $0x367,0x4(%esp)
c002113c:	00 
c002113d:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021144:	e8 3a 78 00 00       	call   c0028983 <debug_panic>
  cur->status = THREAD_RUNNING;
c0021149:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
  thread_ticks = 0;
c0021150:	c7 05 c4 5b 03 c0 00 	movl   $0x0,0xc0035bc4
c0021157:	00 00 00 
  if (prev != NULL && prev->status == THREAD_DYING && prev != initial_thread) 
c002115a:	85 db                	test   %ebx,%ebx
c002115c:	74 46                	je     c00211a4 <thread_schedule_tail+0xa1>
c002115e:	83 7b 04 03          	cmpl   $0x3,0x4(%ebx)
c0021162:	75 40                	jne    c00211a4 <thread_schedule_tail+0xa1>
c0021164:	3b 1d 04 5c 03 c0    	cmp    0xc0035c04,%ebx
c002116a:	74 38                	je     c00211a4 <thread_schedule_tail+0xa1>
      ASSERT (prev != cur);
c002116c:	39 f3                	cmp    %esi,%ebx
c002116e:	75 2c                	jne    c002119c <thread_schedule_tail+0x99>
c0021170:	c7 44 24 10 67 e5 02 	movl   $0xc002e567,0x10(%esp)
c0021177:	c0 
c0021178:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002117f:	c0 
c0021180:	c7 44 24 08 79 d0 02 	movl   $0xc002d079,0x8(%esp)
c0021187:	c0 
c0021188:	c7 44 24 04 7b 03 00 	movl   $0x37b,0x4(%esp)
c002118f:	00 
c0021190:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021197:	e8 e7 77 00 00       	call   c0028983 <debug_panic>
      palloc_free_page (prev);
c002119c:	89 1c 24             	mov    %ebx,(%esp)
c002119f:	e8 ec 25 00 00       	call   c0023790 <palloc_free_page>
}
c00211a4:	83 c4 24             	add    $0x24,%esp
c00211a7:	5b                   	pop    %ebx
c00211a8:	5e                   	pop    %esi
c00211a9:	c3                   	ret    

c00211aa <schedule>:
{
c00211aa:	57                   	push   %edi
c00211ab:	56                   	push   %esi
c00211ac:	53                   	push   %ebx
c00211ad:	83 ec 20             	sub    $0x20,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c00211b0:	89 e7                	mov    %esp,%edi
c00211b2:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
  if(thread_mlfqs)
c00211b8:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c00211bf:	74 45                	je     c0021206 <schedule+0x5c>
c00211c1:	be 10 60 03 c0       	mov    $0xc0036010,%esi
c00211c6:	bb 3f 00 00 00       	mov    $0x3f,%ebx
c00211cb:	eb 0b                	jmp    c00211d8 <schedule+0x2e>
      i--;
c00211cd:	83 eb 01             	sub    $0x1,%ebx
c00211d0:	83 ee 10             	sub    $0x10,%esi
    while(i>=0 && list_empty(&mlfqs_list[i]))
c00211d3:	83 fb ff             	cmp    $0xffffffff,%ebx
c00211d6:	74 26                	je     c00211fe <schedule+0x54>
c00211d8:	89 34 24             	mov    %esi,(%esp)
c00211db:	e8 a6 7e 00 00       	call   c0029086 <list_empty>
c00211e0:	84 c0                	test   %al,%al
c00211e2:	75 e9                	jne    c00211cd <schedule+0x23>
    if(i>=0)
c00211e4:	85 db                	test   %ebx,%ebx
c00211e6:	78 16                	js     c00211fe <schedule+0x54>
      return list_entry(list_pop_front (&mlfqs_list[i]), struct thread, elem);
c00211e8:	c1 e3 04             	shl    $0x4,%ebx
c00211eb:	81 c3 20 5c 03 c0    	add    $0xc0035c20,%ebx
c00211f1:	89 1c 24             	mov    %ebx,(%esp)
c00211f4:	e8 fb 7e 00 00       	call   c00290f4 <list_pop_front>
c00211f9:	8d 58 d8             	lea    -0x28(%eax),%ebx
c00211fc:	eb 47                	jmp    c0021245 <schedule+0x9b>
      return idle_thread;
c00211fe:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
c0021204:	eb 3f                	jmp    c0021245 <schedule+0x9b>
    if (list_empty (&ready_list))
c0021206:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c002120d:	e8 74 7e 00 00       	call   c0029086 <list_empty>
      return idle_thread;
c0021212:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
    if (list_empty (&ready_list))
c0021218:	84 c0                	test   %al,%al
c002121a:	75 29                	jne    c0021245 <schedule+0x9b>
      struct list_elem *temp = list_max (&ready_list,threadPrioCompare,NULL); 
c002121c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0021223:	00 
c0021224:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c002122b:	c0 
c002122c:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021233:	e8 22 84 00 00       	call   c002965a <list_max>
c0021238:	89 c3                	mov    %eax,%ebx
      list_remove(temp);
c002123a:	89 04 24             	mov    %eax,(%esp)
c002123d:	e8 b2 7d 00 00       	call   c0028ff4 <list_remove>
      return list_entry(temp,struct thread,elem);
c0021242:	83 eb 28             	sub    $0x28,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0021245:	e8 2a 07 00 00       	call   c0021974 <intr_get_level>
c002124a:	85 c0                	test   %eax,%eax
c002124c:	74 2c                	je     c002127a <schedule+0xd0>
c002124e:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0021255:	c0 
c0021256:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002125d:	c0 
c002125e:	c7 44 24 08 e8 d0 02 	movl   $0xc002d0e8,0x8(%esp)
c0021265:	c0 
c0021266:	c7 44 24 04 8d 03 00 	movl   $0x38d,0x4(%esp)
c002126d:	00 
c002126e:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021275:	e8 09 77 00 00       	call   c0028983 <debug_panic>
  ASSERT (cur->status != THREAD_RUNNING);
c002127a:	83 7f 04 00          	cmpl   $0x0,0x4(%edi)
c002127e:	75 2c                	jne    c00212ac <schedule+0x102>
c0021280:	c7 44 24 10 73 e5 02 	movl   $0xc002e573,0x10(%esp)
c0021287:	c0 
c0021288:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002128f:	c0 
c0021290:	c7 44 24 08 e8 d0 02 	movl   $0xc002d0e8,0x8(%esp)
c0021297:	c0 
c0021298:	c7 44 24 04 8e 03 00 	movl   $0x38e,0x4(%esp)
c002129f:	00 
c00212a0:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00212a7:	e8 d7 76 00 00       	call   c0028983 <debug_panic>
  return t != NULL && t->magic == THREAD_MAGIC;
c00212ac:	85 db                	test   %ebx,%ebx
c00212ae:	74 2c                	je     c00212dc <schedule+0x132>
c00212b0:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c00212b7:	75 23                	jne    c00212dc <schedule+0x132>
c00212b9:	eb 16                	jmp    c00212d1 <schedule+0x127>
    prev = switch_threads (cur, next);
c00212bb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00212bf:	89 3c 24             	mov    %edi,(%esp)
c00212c2:	e8 23 05 00 00       	call   c00217ea <switch_threads>
  thread_schedule_tail (prev);
c00212c7:	89 04 24             	mov    %eax,(%esp)
c00212ca:	e8 34 fe ff ff       	call   c0021103 <thread_schedule_tail>
c00212cf:	eb 37                	jmp    c0021308 <schedule+0x15e>
  struct thread *prev = NULL;
c00212d1:	b8 00 00 00 00       	mov    $0x0,%eax
  if (cur != next)
c00212d6:	39 df                	cmp    %ebx,%edi
c00212d8:	74 ed                	je     c00212c7 <schedule+0x11d>
c00212da:	eb df                	jmp    c00212bb <schedule+0x111>
  ASSERT (is_thread (next));
c00212dc:	c7 44 24 10 91 e5 02 	movl   $0xc002e591,0x10(%esp)
c00212e3:	c0 
c00212e4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00212eb:	c0 
c00212ec:	c7 44 24 08 e8 d0 02 	movl   $0xc002d0e8,0x8(%esp)
c00212f3:	c0 
c00212f4:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
c00212fb:	00 
c00212fc:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021303:	e8 7b 76 00 00       	call   c0028983 <debug_panic>
}
c0021308:	83 c4 20             	add    $0x20,%esp
c002130b:	5b                   	pop    %ebx
c002130c:	5e                   	pop    %esi
c002130d:	5f                   	pop    %edi
c002130e:	c3                   	ret    

c002130f <thread_block>:
{
c002130f:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c0021312:	e8 0a 09 00 00       	call   c0021c21 <intr_context>
c0021317:	84 c0                	test   %al,%al
c0021319:	74 2c                	je     c0021347 <thread_block+0x38>
c002131b:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0021322:	c0 
c0021323:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002132a:	c0 
c002132b:	c7 44 24 08 f1 d0 02 	movl   $0xc002d0f1,0x8(%esp)
c0021332:	c0 
c0021333:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c002133a:	00 
c002133b:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021342:	e8 3c 76 00 00       	call   c0028983 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0021347:	e8 28 06 00 00       	call   c0021974 <intr_get_level>
c002134c:	85 c0                	test   %eax,%eax
c002134e:	74 2c                	je     c002137c <thread_block+0x6d>
c0021350:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0021357:	c0 
c0021358:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002135f:	c0 
c0021360:	c7 44 24 08 f1 d0 02 	movl   $0xc002d0f1,0x8(%esp)
c0021367:	c0 
c0021368:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c002136f:	00 
c0021370:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021377:	e8 07 76 00 00       	call   c0028983 <debug_panic>
  thread_current ()->status = THREAD_BLOCKED;
c002137c:	e8 58 fa ff ff       	call   c0020dd9 <thread_current>
c0021381:	c7 40 04 02 00 00 00 	movl   $0x2,0x4(%eax)
  schedule ();
c0021388:	e8 1d fe ff ff       	call   c00211aa <schedule>
}
c002138d:	83 c4 2c             	add    $0x2c,%esp
c0021390:	c3                   	ret    

c0021391 <idle>:
{
c0021391:	83 ec 1c             	sub    $0x1c,%esp
  idle_thread = thread_current ();
c0021394:	e8 40 fa ff ff       	call   c0020dd9 <thread_current>
c0021399:	a3 08 5c 03 c0       	mov    %eax,0xc0035c08
  sema_up (idle_started);
c002139e:	8b 44 24 20          	mov    0x20(%esp),%eax
c00213a2:	89 04 24             	mov    %eax,(%esp)
c00213a5:	e8 9d 18 00 00       	call   c0022c47 <sema_up>
      intr_disable ();
c00213aa:	e8 10 06 00 00       	call   c00219bf <intr_disable>
      thread_block ();
c00213af:	e8 5b ff ff ff       	call   c002130f <thread_block>
      asm volatile ("sti; hlt" : : : "memory");
c00213b4:	fb                   	sti    
c00213b5:	f4                   	hlt    
c00213b6:	eb f2                	jmp    c00213aa <idle+0x19>

c00213b8 <thread_exit>:
{
c00213b8:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c00213bb:	e8 61 08 00 00       	call   c0021c21 <intr_context>
c00213c0:	84 c0                	test   %al,%al
c00213c2:	74 2c                	je     c00213f0 <thread_exit+0x38>
c00213c4:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00213cb:	c0 
c00213cc:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00213d3:	c0 
c00213d4:	c7 44 24 08 be d0 02 	movl   $0xc002d0be,0x8(%esp)
c00213db:	c0 
c00213dc:	c7 44 24 04 bf 01 00 	movl   $0x1bf,0x4(%esp)
c00213e3:	00 
c00213e4:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00213eb:	e8 93 75 00 00       	call   c0028983 <debug_panic>
  intr_disable ();
c00213f0:	e8 ca 05 00 00       	call   c00219bf <intr_disable>
  list_remove (&thread_current()->allelem);
c00213f5:	e8 df f9 ff ff       	call   c0020dd9 <thread_current>
c00213fa:	83 c0 20             	add    $0x20,%eax
c00213fd:	89 04 24             	mov    %eax,(%esp)
c0021400:	e8 ef 7b 00 00       	call   c0028ff4 <list_remove>
  thread_current ()->status = THREAD_DYING;
c0021405:	e8 cf f9 ff ff       	call   c0020dd9 <thread_current>
c002140a:	c7 40 04 03 00 00 00 	movl   $0x3,0x4(%eax)
  schedule ();
c0021411:	e8 94 fd ff ff       	call   c00211aa <schedule>
  NOT_REACHED ();
c0021416:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c002141d:	c0 
c002141e:	c7 44 24 08 be d0 02 	movl   $0xc002d0be,0x8(%esp)
c0021425:	c0 
c0021426:	c7 44 24 04 cc 01 00 	movl   $0x1cc,0x4(%esp)
c002142d:	00 
c002142e:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021435:	e8 49 75 00 00       	call   c0028983 <debug_panic>

c002143a <kernel_thread>:
{
c002143a:	53                   	push   %ebx
c002143b:	83 ec 28             	sub    $0x28,%esp
c002143e:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (function != NULL);
c0021442:	85 db                	test   %ebx,%ebx
c0021444:	75 2c                	jne    c0021472 <kernel_thread+0x38>
c0021446:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c002144d:	c0 
c002144e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021455:	c0 
c0021456:	c7 44 24 08 0a d1 02 	movl   $0xc002d10a,0x8(%esp)
c002145d:	c0 
c002145e:	c7 44 24 04 d5 02 00 	movl   $0x2d5,0x4(%esp)
c0021465:	00 
c0021466:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c002146d:	e8 11 75 00 00       	call   c0028983 <debug_panic>
  intr_enable ();       /* The scheduler runs with interrupts off. */
c0021472:	e8 06 05 00 00       	call   c002197d <intr_enable>
  function (aux);       /* Execute the thread function. */
c0021477:	8b 44 24 34          	mov    0x34(%esp),%eax
c002147b:	89 04 24             	mov    %eax,(%esp)
c002147e:	ff d3                	call   *%ebx
  thread_exit ();       /* If function() returns, kill the thread. */
c0021480:	e8 33 ff ff ff       	call   c00213b8 <thread_exit>

c0021485 <thread_yield>:
{
c0021485:	56                   	push   %esi
c0021486:	53                   	push   %ebx
c0021487:	83 ec 24             	sub    $0x24,%esp
  struct thread *cur = thread_current ();
c002148a:	e8 4a f9 ff ff       	call   c0020dd9 <thread_current>
c002148f:	89 c3                	mov    %eax,%ebx
  ASSERT (!intr_context ());
c0021491:	e8 8b 07 00 00       	call   c0021c21 <intr_context>
c0021496:	84 c0                	test   %al,%al
c0021498:	74 2c                	je     c00214c6 <thread_yield+0x41>
c002149a:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00214a1:	c0 
c00214a2:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00214a9:	c0 
c00214aa:	c7 44 24 08 b1 d0 02 	movl   $0xc002d0b1,0x8(%esp)
c00214b1:	c0 
c00214b2:	c7 44 24 04 d7 01 00 	movl   $0x1d7,0x4(%esp)
c00214b9:	00 
c00214ba:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00214c1:	e8 bd 74 00 00       	call   c0028983 <debug_panic>
  old_level = intr_disable ();
c00214c6:	e8 f4 04 00 00       	call   c00219bf <intr_disable>
c00214cb:	89 c6                	mov    %eax,%esi
  if (cur != idle_thread) 
c00214cd:	3b 1d 08 5c 03 c0    	cmp    0xc0035c08,%ebx
c00214d3:	74 38                	je     c002150d <thread_yield+0x88>
    if(thread_mlfqs) {
c00214d5:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c00214dc:	74 1c                	je     c00214fa <thread_yield+0x75>
      list_push_back (&mlfqs_list[cur->priority], &cur->elem);
c00214de:	8d 43 28             	lea    0x28(%ebx),%eax
c00214e1:	89 44 24 04          	mov    %eax,0x4(%esp)
c00214e5:	8b 43 1c             	mov    0x1c(%ebx),%eax
c00214e8:	c1 e0 04             	shl    $0x4,%eax
c00214eb:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c00214f0:	89 04 24             	mov    %eax,(%esp)
c00214f3:	e8 d9 7a 00 00       	call   c0028fd1 <list_push_back>
c00214f8:	eb 13                	jmp    c002150d <thread_yield+0x88>
      list_push_back (&ready_list, &cur->elem);
c00214fa:	8d 43 28             	lea    0x28(%ebx),%eax
c00214fd:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021501:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021508:	e8 c4 7a 00 00       	call   c0028fd1 <list_push_back>
  cur->status = THREAD_READY;
c002150d:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  schedule ();
c0021514:	e8 91 fc ff ff       	call   c00211aa <schedule>
  intr_set_level (old_level);
c0021519:	89 34 24             	mov    %esi,(%esp)
c002151c:	e8 a5 04 00 00       	call   c00219c6 <intr_set_level>
}
c0021521:	83 c4 24             	add    $0x24,%esp
c0021524:	5b                   	pop    %ebx
c0021525:	5e                   	pop    %esi
c0021526:	c3                   	ret    

c0021527 <thread_create>:
{
c0021527:	55                   	push   %ebp
c0021528:	57                   	push   %edi
c0021529:	56                   	push   %esi
c002152a:	53                   	push   %ebx
c002152b:	83 ec 2c             	sub    $0x2c,%esp
c002152e:	8b 7c 24 48          	mov    0x48(%esp),%edi
  ASSERT (function != NULL);
c0021532:	85 ff                	test   %edi,%edi
c0021534:	75 2c                	jne    c0021562 <thread_create+0x3b>
c0021536:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c002153d:	c0 
c002153e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021545:	c0 
c0021546:	c7 44 24 08 18 d1 02 	movl   $0xc002d118,0x8(%esp)
c002154d:	c0 
c002154e:	c7 44 24 04 2e 01 00 	movl   $0x12e,0x4(%esp)
c0021555:	00 
c0021556:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c002155d:	e8 21 74 00 00       	call   c0028983 <debug_panic>
  t = palloc_get_page (PAL_ZERO);
c0021562:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c0021569:	e8 b8 20 00 00       	call   c0023626 <palloc_get_page>
c002156e:	89 c3                	mov    %eax,%ebx
  if (t == NULL)
c0021570:	85 c0                	test   %eax,%eax
c0021572:	0f 84 c4 00 00 00    	je     c002163c <thread_create+0x115>
  t->nice = thread_current()->nice; //get parent's nice value
c0021578:	e8 5c f8 ff ff       	call   c0020dd9 <thread_current>
c002157d:	8b 40 54             	mov    0x54(%eax),%eax
c0021580:	89 43 54             	mov    %eax,0x54(%ebx)
  t->recent_cpu = thread_current()->recent_cpu; //get parent's recent_cpu value
c0021583:	e8 51 f8 ff ff       	call   c0020dd9 <thread_current>
c0021588:	8b 40 58             	mov    0x58(%eax),%eax
c002158b:	89 43 58             	mov    %eax,0x58(%ebx)
  init_thread (t, name, priority);
c002158e:	8b 4c 24 44          	mov    0x44(%esp),%ecx
c0021592:	8b 54 24 40          	mov    0x40(%esp),%edx
c0021596:	89 d8                	mov    %ebx,%eax
c0021598:	e8 a6 f3 ff ff       	call   c0020943 <init_thread>
  lock_acquire (&tid_lock);
c002159d:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c00215a4:	e8 b1 18 00 00       	call   c0022e5a <lock_acquire>
  tid = next_tid++;
c00215a9:	8b 35 50 56 03 c0    	mov    0xc0035650,%esi
c00215af:	8d 46 01             	lea    0x1(%esi),%eax
c00215b2:	a3 50 56 03 c0       	mov    %eax,0xc0035650
  lock_release (&tid_lock);
c00215b7:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c00215be:	e8 61 1a 00 00       	call   c0023024 <lock_release>
  tid = t->tid = allocate_tid ();
c00215c3:	89 33                	mov    %esi,(%ebx)
  old_level = intr_disable ();
c00215c5:	e8 f5 03 00 00       	call   c00219bf <intr_disable>
c00215ca:	89 c5                	mov    %eax,%ebp
  kf = alloc_frame (t, sizeof *kf);
c00215cc:	ba 0c 00 00 00       	mov    $0xc,%edx
c00215d1:	89 d8                	mov    %ebx,%eax
c00215d3:	e8 8a f2 ff ff       	call   c0020862 <alloc_frame>
  kf->eip = NULL;
c00215d8:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  kf->function = function;
c00215de:	89 78 04             	mov    %edi,0x4(%eax)
  kf->aux = aux;
c00215e1:	8b 54 24 4c          	mov    0x4c(%esp),%edx
c00215e5:	89 50 08             	mov    %edx,0x8(%eax)
  ef = alloc_frame (t, sizeof *ef);
c00215e8:	ba 04 00 00 00       	mov    $0x4,%edx
c00215ed:	89 d8                	mov    %ebx,%eax
c00215ef:	e8 6e f2 ff ff       	call   c0020862 <alloc_frame>
  ef->eip = (void (*) (void)) kernel_thread;
c00215f4:	c7 00 3a 14 02 c0    	movl   $0xc002143a,(%eax)
  sf = alloc_frame (t, sizeof *sf);
c00215fa:	ba 1c 00 00 00       	mov    $0x1c,%edx
c00215ff:	89 d8                	mov    %ebx,%eax
c0021601:	e8 5c f2 ff ff       	call   c0020862 <alloc_frame>
  sf->eip = switch_entry;
c0021606:	c7 40 10 07 18 02 c0 	movl   $0xc0021807,0x10(%eax)
  sf->ebp = 0;
c002160d:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
  intr_set_level (old_level);
c0021614:	89 2c 24             	mov    %ebp,(%esp)
c0021617:	e8 aa 03 00 00       	call   c00219c6 <intr_set_level>
  thread_unblock (t);
c002161c:	89 1c 24             	mov    %ebx,(%esp)
c002161f:	e8 da f6 ff ff       	call   c0020cfe <thread_unblock>
  if(t->priority > thread_current()->priority)
c0021624:	e8 b0 f7 ff ff       	call   c0020dd9 <thread_current>
  return tid;
c0021629:	89 f2                	mov    %esi,%edx
  if(t->priority > thread_current()->priority)
c002162b:	8b 40 1c             	mov    0x1c(%eax),%eax
c002162e:	39 43 1c             	cmp    %eax,0x1c(%ebx)
c0021631:	7e 0e                	jle    c0021641 <thread_create+0x11a>
    thread_yield();
c0021633:	e8 4d fe ff ff       	call   c0021485 <thread_yield>
  return tid;
c0021638:	89 f2                	mov    %esi,%edx
c002163a:	eb 05                	jmp    c0021641 <thread_create+0x11a>
    return TID_ERROR;
c002163c:	ba ff ff ff ff       	mov    $0xffffffff,%edx
}
c0021641:	89 d0                	mov    %edx,%eax
c0021643:	83 c4 2c             	add    $0x2c,%esp
c0021646:	5b                   	pop    %ebx
c0021647:	5e                   	pop    %esi
c0021648:	5f                   	pop    %edi
c0021649:	5d                   	pop    %ebp
c002164a:	c3                   	ret    

c002164b <thread_start>:
{
c002164b:	53                   	push   %ebx
c002164c:	83 ec 38             	sub    $0x38,%esp
  sema_init (&idle_started, 0);
c002164f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0021656:	00 
c0021657:	8d 5c 24 1c          	lea    0x1c(%esp),%ebx
c002165b:	89 1c 24             	mov    %ebx,(%esp)
c002165e:	e8 83 14 00 00       	call   c0022ae6 <sema_init>
  thread_create ("idle", PRI_MIN, idle, &idle_started);
c0021663:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0021667:	c7 44 24 08 91 13 02 	movl   $0xc0021391,0x8(%esp)
c002166e:	c0 
c002166f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0021676:	00 
c0021677:	c7 04 24 c4 e5 02 c0 	movl   $0xc002e5c4,(%esp)
c002167e:	e8 a4 fe ff ff       	call   c0021527 <thread_create>
  intr_enable ();
c0021683:	e8 f5 02 00 00       	call   c002197d <intr_enable>
  sema_down (&idle_started);
c0021688:	89 1c 24             	mov    %ebx,(%esp)
c002168b:	e8 a2 14 00 00       	call   c0022b32 <sema_down>
}
c0021690:	83 c4 38             	add    $0x38,%esp
c0021693:	5b                   	pop    %ebx
c0021694:	c3                   	ret    

c0021695 <thread_set_priority>:
{
c0021695:	56                   	push   %esi
c0021696:	53                   	push   %ebx
c0021697:	83 ec 24             	sub    $0x24,%esp
c002169a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT(thread_mlfqs == false);
c002169e:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c00216a5:	74 2c                	je     c00216d3 <thread_set_priority+0x3e>
c00216a7:	c7 44 24 10 c9 e5 02 	movl   $0xc002e5c9,0x10(%esp)
c00216ae:	c0 
c00216af:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00216b6:	c0 
c00216b7:	c7 44 24 08 8e d0 02 	movl   $0xc002d08e,0x8(%esp)
c00216be:	c0 
c00216bf:	c7 44 24 04 03 02 00 	movl   $0x203,0x4(%esp)
c00216c6:	00 
c00216c7:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00216ce:	e8 b0 72 00 00       	call   c0028983 <debug_panic>
  old_level = intr_disable ();
c00216d3:	e8 e7 02 00 00       	call   c00219bf <intr_disable>
c00216d8:	89 c6                	mov    %eax,%esi
  if(new_priority >= PRI_MIN && new_priority <= PRI_MAX) //REMOVE COMMENT: flipped this
c00216da:	83 fb 3f             	cmp    $0x3f,%ebx
c00216dd:	77 68                	ja     c0021747 <thread_set_priority+0xb2>
    if(new_priority > thread_current ()->priority)
c00216df:	e8 f5 f6 ff ff       	call   c0020dd9 <thread_current>
c00216e4:	89 c2                	mov    %eax,%edx
c00216e6:	8b 40 1c             	mov    0x1c(%eax),%eax
c00216e9:	39 c3                	cmp    %eax,%ebx
c00216eb:	7e 0d                	jle    c00216fa <thread_set_priority+0x65>
      thread_current ()->priority = new_priority;
c00216ed:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c00216f0:	e8 e4 f6 ff ff       	call   c0020dd9 <thread_current>
c00216f5:	89 58 3c             	mov    %ebx,0x3c(%eax)
c00216f8:	eb 15                	jmp    c002170f <thread_set_priority+0x7a>
    else if(thread_current ()->priority == thread_current ()->old_priority)
c00216fa:	3b 42 3c             	cmp    0x3c(%edx),%eax
c00216fd:	75 0d                	jne    c002170c <thread_set_priority+0x77>
      thread_current ()->priority = new_priority;
c00216ff:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c0021702:	e8 d2 f6 ff ff       	call   c0020dd9 <thread_current>
c0021707:	89 58 3c             	mov    %ebx,0x3c(%eax)
c002170a:	eb 03                	jmp    c002170f <thread_set_priority+0x7a>
      thread_current ()->old_priority = new_priority;
c002170c:	89 5a 3c             	mov    %ebx,0x3c(%edx)
    intr_set_level (old_level);
c002170f:	89 34 24             	mov    %esi,(%esp)
c0021712:	e8 af 02 00 00       	call   c00219c6 <intr_set_level>
    t = list_entry(list_max (&ready_list,threadPrioCompare,NULL),struct thread,elem)->priority;
c0021717:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c002171e:	00 
c002171f:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c0021726:	c0 
c0021727:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c002172e:	e8 27 7f 00 00       	call   c002965a <list_max>
c0021733:	89 c3                	mov    %eax,%ebx
    if(t > thread_current ()->priority)
c0021735:	e8 9f f6 ff ff       	call   c0020dd9 <thread_current>
c002173a:	8b 40 1c             	mov    0x1c(%eax),%eax
c002173d:	39 43 f4             	cmp    %eax,-0xc(%ebx)
c0021740:	7e 05                	jle    c0021747 <thread_set_priority+0xb2>
      thread_yield();
c0021742:	e8 3e fd ff ff       	call   c0021485 <thread_yield>
}
c0021747:	83 c4 24             	add    $0x24,%esp
c002174a:	5b                   	pop    %ebx
c002174b:	5e                   	pop    %esi
c002174c:	c3                   	ret    

c002174d <thread_set_nice>:
{
c002174d:	57                   	push   %edi
c002174e:	56                   	push   %esi
c002174f:	53                   	push   %ebx
c0021750:	83 ec 10             	sub    $0x10,%esp
c0021753:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread *cur = thread_current();
c0021757:	e8 7d f6 ff ff       	call   c0020dd9 <thread_current>
c002175c:	89 c7                	mov    %eax,%edi
  if(nice >= -20 && nice <= 20)
c002175e:	8d 43 14             	lea    0x14(%ebx),%eax
c0021761:	83 f8 28             	cmp    $0x28,%eax
c0021764:	77 03                	ja     c0021769 <thread_set_nice+0x1c>
    cur->nice = nice;
c0021766:	89 5f 54             	mov    %ebx,0x54(%edi)
  cur->priority = PRI_MAX - convertXtoIntRoundNear(cur->recent_cpu / 4) - (cur->nice * 2);
c0021769:	8b 47 58             	mov    0x58(%edi),%eax
c002176c:	8d 50 03             	lea    0x3(%eax),%edx
c002176f:	85 c0                	test   %eax,%eax
c0021771:	0f 48 c2             	cmovs  %edx,%eax
c0021774:	c1 f8 02             	sar    $0x2,%eax
c0021777:	89 04 24             	mov    %eax,(%esp)
c002177a:	e8 92 f1 ff ff       	call   c0020911 <convertXtoIntRoundNear>
c002177f:	ba 3f 00 00 00       	mov    $0x3f,%edx
c0021784:	29 c2                	sub    %eax,%edx
c0021786:	89 d0                	mov    %edx,%eax
c0021788:	8b 57 54             	mov    0x54(%edi),%edx
c002178b:	f7 da                	neg    %edx
c002178d:	8d 04 50             	lea    (%eax,%edx,2),%eax
c0021790:	89 47 1c             	mov    %eax,0x1c(%edi)
  if(cur->priority > PRI_MAX)
c0021793:	83 f8 3f             	cmp    $0x3f,%eax
c0021796:	7e 09                	jle    c00217a1 <thread_set_nice+0x54>
    cur->priority = PRI_MAX;
c0021798:	c7 47 1c 3f 00 00 00 	movl   $0x3f,0x1c(%edi)
c002179f:	eb 36                	jmp    c00217d7 <thread_set_nice+0x8a>
  if(cur->priority < PRI_MIN)
c00217a1:	85 c0                	test   %eax,%eax
c00217a3:	79 32                	jns    c00217d7 <thread_set_nice+0x8a>
    cur->priority = PRI_MIN;
c00217a5:	c7 47 1c 00 00 00 00 	movl   $0x0,0x1c(%edi)
c00217ac:	eb 29                	jmp    c00217d7 <thread_set_nice+0x8a>
    i--;
c00217ae:	83 eb 01             	sub    $0x1,%ebx
c00217b1:	83 ee 10             	sub    $0x10,%esi
  while(i>=0 && list_empty(&mlfqs_list[i]))
c00217b4:	83 fb ff             	cmp    $0xffffffff,%ebx
c00217b7:	74 0c                	je     c00217c5 <thread_set_nice+0x78>
c00217b9:	89 34 24             	mov    %esi,(%esp)
c00217bc:	e8 c5 78 00 00       	call   c0029086 <list_empty>
c00217c1:	84 c0                	test   %al,%al
c00217c3:	75 e9                	jne    c00217ae <thread_set_nice+0x61>
  if(cur->priority < i)
c00217c5:	39 5f 1c             	cmp    %ebx,0x1c(%edi)
c00217c8:	7d 19                	jge    c00217e3 <thread_set_nice+0x96>
c00217ca:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
    thread_yield();
c00217d0:	e8 b0 fc ff ff       	call   c0021485 <thread_yield>
c00217d5:	eb 0c                	jmp    c00217e3 <thread_set_nice+0x96>
c00217d7:	be 10 60 03 c0       	mov    $0xc0036010,%esi
{
c00217dc:	bb 3f 00 00 00       	mov    $0x3f,%ebx
c00217e1:	eb d6                	jmp    c00217b9 <thread_set_nice+0x6c>
}
c00217e3:	83 c4 10             	add    $0x10,%esp
c00217e6:	5b                   	pop    %ebx
c00217e7:	5e                   	pop    %esi
c00217e8:	5f                   	pop    %edi
c00217e9:	c3                   	ret    

c00217ea <switch_threads>:
	# but requires us to preserve %ebx, %ebp, %esi, %edi.  See
	# [SysV-ABI-386] pages 3-11 and 3-12 for details.
	#
	# This stack frame must match the one set up by thread_create()
	# in size.
	pushl %ebx
c00217ea:	53                   	push   %ebx
	pushl %ebp
c00217eb:	55                   	push   %ebp
	pushl %esi
c00217ec:	56                   	push   %esi
	pushl %edi
c00217ed:	57                   	push   %edi

	# Get offsetof (struct thread, stack).
.globl thread_stack_ofs
	mov thread_stack_ofs, %edx
c00217ee:	8b 15 54 56 03 c0    	mov    0xc0035654,%edx

	# Save current stack pointer to old thread's stack, if any.
	movl SWITCH_CUR(%esp), %eax
c00217f4:	8b 44 24 14          	mov    0x14(%esp),%eax
	movl %esp, (%eax,%edx,1)
c00217f8:	89 24 10             	mov    %esp,(%eax,%edx,1)

	# Restore stack pointer from new thread's stack.
	movl SWITCH_NEXT(%esp), %ecx
c00217fb:	8b 4c 24 18          	mov    0x18(%esp),%ecx
	movl (%ecx,%edx,1), %esp
c00217ff:	8b 24 11             	mov    (%ecx,%edx,1),%esp

	# Restore caller's register state.
	popl %edi
c0021802:	5f                   	pop    %edi
	popl %esi
c0021803:	5e                   	pop    %esi
	popl %ebp
c0021804:	5d                   	pop    %ebp
	popl %ebx
c0021805:	5b                   	pop    %ebx
        ret
c0021806:	c3                   	ret    

c0021807 <switch_entry>:

.globl switch_entry
.func switch_entry
switch_entry:
	# Discard switch_threads() arguments.
	addl $8, %esp
c0021807:	83 c4 08             	add    $0x8,%esp

	# Call thread_schedule_tail(prev).
	pushl %eax
c002180a:	50                   	push   %eax
.globl thread_schedule_tail
	call thread_schedule_tail
c002180b:	e8 f3 f8 ff ff       	call   c0021103 <thread_schedule_tail>
	addl $4, %esp
c0021810:	83 c4 04             	add    $0x4,%esp

	# Start thread proper.
	ret
c0021813:	c3                   	ret    
c0021814:	90                   	nop
c0021815:	90                   	nop
c0021816:	90                   	nop
c0021817:	90                   	nop
c0021818:	90                   	nop
c0021819:	90                   	nop
c002181a:	90                   	nop
c002181b:	90                   	nop
c002181c:	90                   	nop
c002181d:	90                   	nop
c002181e:	90                   	nop
c002181f:	90                   	nop

c0021820 <make_gate>:
   disables interrupts, but entering a trap gate does not.  See
   [IA32-v3a] section 5.12.1.2 "Flag Usage By Exception- or
   Interrupt-Handler Procedure" for discussion. */
static uint64_t
make_gate (void (*function) (void), int dpl, int type)
{
c0021820:	53                   	push   %ebx
c0021821:	83 ec 28             	sub    $0x28,%esp
  uint32_t e0, e1;

  ASSERT (function != NULL);
c0021824:	85 c0                	test   %eax,%eax
c0021826:	75 2c                	jne    c0021854 <make_gate+0x34>
c0021828:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c002182f:	c0 
c0021830:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021837:	c0 
c0021838:	c7 44 24 08 aa d1 02 	movl   $0xc002d1aa,0x8(%esp)
c002183f:	c0 
c0021840:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0021847:	00 
c0021848:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c002184f:	e8 2f 71 00 00       	call   c0028983 <debug_panic>
  ASSERT (dpl >= 0 && dpl <= 3);
c0021854:	83 fa 03             	cmp    $0x3,%edx
c0021857:	76 2c                	jbe    c0021885 <make_gate+0x65>
c0021859:	c7 44 24 10 88 e6 02 	movl   $0xc002e688,0x10(%esp)
c0021860:	c0 
c0021861:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021868:	c0 
c0021869:	c7 44 24 08 aa d1 02 	movl   $0xc002d1aa,0x8(%esp)
c0021870:	c0 
c0021871:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0021878:	00 
c0021879:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021880:	e8 fe 70 00 00       	call   c0028983 <debug_panic>
  ASSERT (type >= 0 && type <= 15);
c0021885:	83 f9 0f             	cmp    $0xf,%ecx
c0021888:	76 2c                	jbe    c00218b6 <make_gate+0x96>
c002188a:	c7 44 24 10 9d e6 02 	movl   $0xc002e69d,0x10(%esp)
c0021891:	c0 
c0021892:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021899:	c0 
c002189a:	c7 44 24 08 aa d1 02 	movl   $0xc002d1aa,0x8(%esp)
c00218a1:	c0 
c00218a2:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
c00218a9:	00 
c00218aa:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c00218b1:	e8 cd 70 00 00       	call   c0028983 <debug_panic>

  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
        | (1 << 15)                        /* Present. */
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
        | (0 << 12)                        /* System. */
        | ((uint32_t) type << 8));         /* Gate type. */
c00218b6:	c1 e1 08             	shl    $0x8,%ecx
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
c00218b9:	80 cd 80             	or     $0x80,%ch
c00218bc:	89 d3                	mov    %edx,%ebx
c00218be:	c1 e3 0d             	shl    $0xd,%ebx
        | ((uint32_t) type << 8));         /* Gate type. */
c00218c1:	09 d9                	or     %ebx,%ecx
c00218c3:	89 ca                	mov    %ecx,%edx
  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
c00218c5:	89 c3                	mov    %eax,%ebx
c00218c7:	66 bb 00 00          	mov    $0x0,%bx
c00218cb:	09 da                	or     %ebx,%edx
  e0 = (((uint32_t) function & 0xffff)     /* Offset 15:0. */
c00218cd:	0f b7 c0             	movzwl %ax,%eax
c00218d0:	0d 00 00 08 00       	or     $0x80000,%eax

  return e0 | ((uint64_t) e1 << 32);
}
c00218d5:	83 c4 28             	add    $0x28,%esp
c00218d8:	5b                   	pop    %ebx
c00218d9:	c3                   	ret    

c00218da <register_handler>:
{
c00218da:	53                   	push   %ebx
c00218db:	83 ec 28             	sub    $0x28,%esp
  ASSERT (intr_handlers[vec_no] == NULL);
c00218de:	0f b6 d8             	movzbl %al,%ebx
c00218e1:	83 3c 9d 60 68 03 c0 	cmpl   $0x0,-0x3ffc97a0(,%ebx,4)
c00218e8:	00 
c00218e9:	74 2c                	je     c0021917 <register_handler+0x3d>
c00218eb:	c7 44 24 10 b5 e6 02 	movl   $0xc002e6b5,0x10(%esp)
c00218f2:	c0 
c00218f3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00218fa:	c0 
c00218fb:	c7 44 24 08 87 d1 02 	movl   $0xc002d187,0x8(%esp)
c0021902:	c0 
c0021903:	c7 44 24 04 a8 00 00 	movl   $0xa8,0x4(%esp)
c002190a:	00 
c002190b:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021912:	e8 6c 70 00 00       	call   c0028983 <debug_panic>
  if (level == INTR_ON)
c0021917:	83 f9 01             	cmp    $0x1,%ecx
c002191a:	75 1e                	jne    c002193a <register_handler+0x60>
/* Creates a trap gate that invokes FUNCTION with the given
   DPL. */
static uint64_t
make_trap_gate (void (*function) (void), int dpl)
{
  return make_gate (function, dpl, 15);
c002191c:	8b 04 9d 58 56 03 c0 	mov    -0x3ffca9a8(,%ebx,4),%eax
c0021923:	b1 0f                	mov    $0xf,%cl
c0021925:	e8 f6 fe ff ff       	call   c0021820 <make_gate>
    idt[vec_no] = make_trap_gate (intr_stubs[vec_no], dpl);
c002192a:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021931:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
c0021938:	eb 1f                	jmp    c0021959 <register_handler+0x7f>
  return make_gate (function, dpl, 14);
c002193a:	8b 04 9d 58 56 03 c0 	mov    -0x3ffca9a8(,%ebx,4),%eax
c0021941:	b9 0e 00 00 00       	mov    $0xe,%ecx
c0021946:	e8 d5 fe ff ff       	call   c0021820 <make_gate>
    idt[vec_no] = make_intr_gate (intr_stubs[vec_no], dpl);
c002194b:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021952:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  intr_handlers[vec_no] = handler;
c0021959:	8b 44 24 30          	mov    0x30(%esp),%eax
c002195d:	89 04 9d 60 68 03 c0 	mov    %eax,-0x3ffc97a0(,%ebx,4)
  intr_names[vec_no] = name;
c0021964:	8b 44 24 34          	mov    0x34(%esp),%eax
c0021968:	89 04 9d 60 64 03 c0 	mov    %eax,-0x3ffc9ba0(,%ebx,4)
}
c002196f:	83 c4 28             	add    $0x28,%esp
c0021972:	5b                   	pop    %ebx
c0021973:	c3                   	ret    

c0021974 <intr_get_level>:
  asm volatile ("pushfl; popl %0" : "=g" (flags));
c0021974:	9c                   	pushf  
c0021975:	58                   	pop    %eax
  return flags & FLAG_IF ? INTR_ON : INTR_OFF;
c0021976:	c1 e8 09             	shr    $0x9,%eax
c0021979:	83 e0 01             	and    $0x1,%eax
}
c002197c:	c3                   	ret    

c002197d <intr_enable>:
{
c002197d:	83 ec 2c             	sub    $0x2c,%esp
  enum intr_level old_level = intr_get_level ();
c0021980:	e8 ef ff ff ff       	call   c0021974 <intr_get_level>
  ASSERT (!intr_context ());
c0021985:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c002198c:	74 2c                	je     c00219ba <intr_enable+0x3d>
c002198e:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0021995:	c0 
c0021996:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002199d:	c0 
c002199e:	c7 44 24 08 b4 d1 02 	movl   $0xc002d1b4,0x8(%esp)
c00219a5:	c0 
c00219a6:	c7 44 24 04 5b 00 00 	movl   $0x5b,0x4(%esp)
c00219ad:	00 
c00219ae:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c00219b5:	e8 c9 6f 00 00       	call   c0028983 <debug_panic>
  asm volatile ("sti");
c00219ba:	fb                   	sti    
}
c00219bb:	83 c4 2c             	add    $0x2c,%esp
c00219be:	c3                   	ret    

c00219bf <intr_disable>:
  enum intr_level old_level = intr_get_level ();
c00219bf:	e8 b0 ff ff ff       	call   c0021974 <intr_get_level>
  asm volatile ("cli" : : : "memory");
c00219c4:	fa                   	cli    
}
c00219c5:	c3                   	ret    

c00219c6 <intr_set_level>:
{
c00219c6:	83 ec 0c             	sub    $0xc,%esp
  return level == INTR_ON ? intr_enable () : intr_disable ();
c00219c9:	83 7c 24 10 01       	cmpl   $0x1,0x10(%esp)
c00219ce:	75 07                	jne    c00219d7 <intr_set_level+0x11>
c00219d0:	e8 a8 ff ff ff       	call   c002197d <intr_enable>
c00219d5:	eb 05                	jmp    c00219dc <intr_set_level+0x16>
c00219d7:	e8 e3 ff ff ff       	call   c00219bf <intr_disable>
}
c00219dc:	83 c4 0c             	add    $0xc,%esp
c00219df:	90                   	nop
c00219e0:	c3                   	ret    

c00219e1 <intr_init>:
{
c00219e1:	53                   	push   %ebx
c00219e2:	83 ec 18             	sub    $0x18,%esp
/* Writes byte DATA to PORT. */
static inline void
outb (uint16_t port, uint8_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00219e5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c00219ea:	e6 21                	out    %al,$0x21
c00219ec:	e6 a1                	out    %al,$0xa1
c00219ee:	b8 11 00 00 00       	mov    $0x11,%eax
c00219f3:	e6 20                	out    %al,$0x20
c00219f5:	b8 20 00 00 00       	mov    $0x20,%eax
c00219fa:	e6 21                	out    %al,$0x21
c00219fc:	b8 04 00 00 00       	mov    $0x4,%eax
c0021a01:	e6 21                	out    %al,$0x21
c0021a03:	b8 01 00 00 00       	mov    $0x1,%eax
c0021a08:	e6 21                	out    %al,$0x21
c0021a0a:	b8 11 00 00 00       	mov    $0x11,%eax
c0021a0f:	e6 a0                	out    %al,$0xa0
c0021a11:	b8 28 00 00 00       	mov    $0x28,%eax
c0021a16:	e6 a1                	out    %al,$0xa1
c0021a18:	b8 02 00 00 00       	mov    $0x2,%eax
c0021a1d:	e6 a1                	out    %al,$0xa1
c0021a1f:	b8 01 00 00 00       	mov    $0x1,%eax
c0021a24:	e6 a1                	out    %al,$0xa1
c0021a26:	b8 00 00 00 00       	mov    $0x0,%eax
c0021a2b:	e6 21                	out    %al,$0x21
c0021a2d:	e6 a1                	out    %al,$0xa1
  for (i = 0; i < INTR_CNT; i++)
c0021a2f:	bb 00 00 00 00       	mov    $0x0,%ebx
  return make_gate (function, dpl, 14);
c0021a34:	8b 04 9d 58 56 03 c0 	mov    -0x3ffca9a8(,%ebx,4),%eax
c0021a3b:	b9 0e 00 00 00       	mov    $0xe,%ecx
c0021a40:	ba 00 00 00 00       	mov    $0x0,%edx
c0021a45:	e8 d6 fd ff ff       	call   c0021820 <make_gate>
    idt[i] = make_intr_gate (intr_stubs[i], 0);
c0021a4a:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021a51:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  for (i = 0; i < INTR_CNT; i++)
c0021a58:	83 c3 01             	add    $0x1,%ebx
c0021a5b:	81 fb 00 01 00 00    	cmp    $0x100,%ebx
c0021a61:	75 d1                	jne    c0021a34 <intr_init+0x53>
/* Returns a descriptor that yields the given LIMIT and BASE when
   used as an operand for the LIDT instruction. */
static inline uint64_t
make_idtr_operand (uint16_t limit, void *base)
{
  return limit | ((uint64_t) (uint32_t) base << 16);
c0021a63:	b8 60 6c 03 c0       	mov    $0xc0036c60,%eax
c0021a68:	ba 00 00 00 00       	mov    $0x0,%edx
c0021a6d:	0f a4 c2 10          	shld   $0x10,%eax,%edx
c0021a71:	c1 e0 10             	shl    $0x10,%eax
c0021a74:	0d ff 07 00 00       	or     $0x7ff,%eax
c0021a79:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021a7d:	89 54 24 0c          	mov    %edx,0xc(%esp)
  asm volatile ("lidt %0" : : "m" (idtr_operand));
c0021a81:	0f 01 5c 24 08       	lidtl  0x8(%esp)
  for (i = 0; i < INTR_CNT; i++)
c0021a86:	b8 00 00 00 00       	mov    $0x0,%eax
    intr_names[i] = "unknown";
c0021a8b:	c7 04 85 60 64 03 c0 	movl   $0xc002e6d3,-0x3ffc9ba0(,%eax,4)
c0021a92:	d3 e6 02 c0 
  for (i = 0; i < INTR_CNT; i++)
c0021a96:	83 c0 01             	add    $0x1,%eax
c0021a99:	3d 00 01 00 00       	cmp    $0x100,%eax
c0021a9e:	75 eb                	jne    c0021a8b <intr_init+0xaa>
  intr_names[0] = "#DE Divide Error";
c0021aa0:	c7 05 60 64 03 c0 db 	movl   $0xc002e6db,0xc0036460
c0021aa7:	e6 02 c0 
  intr_names[1] = "#DB Debug Exception";
c0021aaa:	c7 05 64 64 03 c0 ec 	movl   $0xc002e6ec,0xc0036464
c0021ab1:	e6 02 c0 
  intr_names[2] = "NMI Interrupt";
c0021ab4:	c7 05 68 64 03 c0 00 	movl   $0xc002e700,0xc0036468
c0021abb:	e7 02 c0 
  intr_names[3] = "#BP Breakpoint Exception";
c0021abe:	c7 05 6c 64 03 c0 0e 	movl   $0xc002e70e,0xc003646c
c0021ac5:	e7 02 c0 
  intr_names[4] = "#OF Overflow Exception";
c0021ac8:	c7 05 70 64 03 c0 27 	movl   $0xc002e727,0xc0036470
c0021acf:	e7 02 c0 
  intr_names[5] = "#BR BOUND Range Exceeded Exception";
c0021ad2:	c7 05 74 64 03 c0 64 	movl   $0xc002e864,0xc0036474
c0021ad9:	e8 02 c0 
  intr_names[6] = "#UD Invalid Opcode Exception";
c0021adc:	c7 05 78 64 03 c0 3e 	movl   $0xc002e73e,0xc0036478
c0021ae3:	e7 02 c0 
  intr_names[7] = "#NM Device Not Available Exception";
c0021ae6:	c7 05 7c 64 03 c0 88 	movl   $0xc002e888,0xc003647c
c0021aed:	e8 02 c0 
  intr_names[8] = "#DF Double Fault Exception";
c0021af0:	c7 05 80 64 03 c0 5b 	movl   $0xc002e75b,0xc0036480
c0021af7:	e7 02 c0 
  intr_names[9] = "Coprocessor Segment Overrun";
c0021afa:	c7 05 84 64 03 c0 76 	movl   $0xc002e776,0xc0036484
c0021b01:	e7 02 c0 
  intr_names[10] = "#TS Invalid TSS Exception";
c0021b04:	c7 05 88 64 03 c0 92 	movl   $0xc002e792,0xc0036488
c0021b0b:	e7 02 c0 
  intr_names[11] = "#NP Segment Not Present";
c0021b0e:	c7 05 8c 64 03 c0 ac 	movl   $0xc002e7ac,0xc003648c
c0021b15:	e7 02 c0 
  intr_names[12] = "#SS Stack Fault Exception";
c0021b18:	c7 05 90 64 03 c0 c4 	movl   $0xc002e7c4,0xc0036490
c0021b1f:	e7 02 c0 
  intr_names[13] = "#GP General Protection Exception";
c0021b22:	c7 05 94 64 03 c0 ac 	movl   $0xc002e8ac,0xc0036494
c0021b29:	e8 02 c0 
  intr_names[14] = "#PF Page-Fault Exception";
c0021b2c:	c7 05 98 64 03 c0 de 	movl   $0xc002e7de,0xc0036498
c0021b33:	e7 02 c0 
  intr_names[16] = "#MF x87 FPU Floating-Point Error";
c0021b36:	c7 05 a0 64 03 c0 d0 	movl   $0xc002e8d0,0xc00364a0
c0021b3d:	e8 02 c0 
  intr_names[17] = "#AC Alignment Check Exception";
c0021b40:	c7 05 a4 64 03 c0 f7 	movl   $0xc002e7f7,0xc00364a4
c0021b47:	e7 02 c0 
  intr_names[18] = "#MC Machine-Check Exception";
c0021b4a:	c7 05 a8 64 03 c0 15 	movl   $0xc002e815,0xc00364a8
c0021b51:	e8 02 c0 
  intr_names[19] = "#XF SIMD Floating-Point Exception";
c0021b54:	c7 05 ac 64 03 c0 f4 	movl   $0xc002e8f4,0xc00364ac
c0021b5b:	e8 02 c0 
}
c0021b5e:	83 c4 18             	add    $0x18,%esp
c0021b61:	5b                   	pop    %ebx
c0021b62:	c3                   	ret    

c0021b63 <intr_register_ext>:
{
c0021b63:	83 ec 2c             	sub    $0x2c,%esp
c0021b66:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no >= 0x20 && vec_no <= 0x2f);
c0021b6a:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021b6d:	80 fa 0f             	cmp    $0xf,%dl
c0021b70:	76 2c                	jbe    c0021b9e <intr_register_ext+0x3b>
c0021b72:	c7 44 24 10 18 e9 02 	movl   $0xc002e918,0x10(%esp)
c0021b79:	c0 
c0021b7a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021b81:	c0 
c0021b82:	c7 44 24 08 98 d1 02 	movl   $0xc002d198,0x8(%esp)
c0021b89:	c0 
c0021b8a:	c7 44 24 04 b8 00 00 	movl   $0xb8,0x4(%esp)
c0021b91:	00 
c0021b92:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021b99:	e8 e5 6d 00 00       	call   c0028983 <debug_panic>
  register_handler (vec_no, 0, INTR_OFF, handler, name);
c0021b9e:	0f b6 c0             	movzbl %al,%eax
c0021ba1:	8b 54 24 38          	mov    0x38(%esp),%edx
c0021ba5:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021ba9:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021bad:	89 14 24             	mov    %edx,(%esp)
c0021bb0:	b9 00 00 00 00       	mov    $0x0,%ecx
c0021bb5:	ba 00 00 00 00       	mov    $0x0,%edx
c0021bba:	e8 1b fd ff ff       	call   c00218da <register_handler>
}
c0021bbf:	83 c4 2c             	add    $0x2c,%esp
c0021bc2:	c3                   	ret    

c0021bc3 <intr_register_int>:
{
c0021bc3:	83 ec 2c             	sub    $0x2c,%esp
c0021bc6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no < 0x20 || vec_no > 0x2f);
c0021bca:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021bcd:	80 fa 0f             	cmp    $0xf,%dl
c0021bd0:	77 2c                	ja     c0021bfe <intr_register_int+0x3b>
c0021bd2:	c7 44 24 10 3c e9 02 	movl   $0xc002e93c,0x10(%esp)
c0021bd9:	c0 
c0021bda:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021be1:	c0 
c0021be2:	c7 44 24 08 75 d1 02 	movl   $0xc002d175,0x8(%esp)
c0021be9:	c0 
c0021bea:	c7 44 24 04 cd 00 00 	movl   $0xcd,0x4(%esp)
c0021bf1:	00 
c0021bf2:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021bf9:	e8 85 6d 00 00       	call   c0028983 <debug_panic>
  register_handler (vec_no, dpl, level, handler, name);
c0021bfe:	0f b6 c0             	movzbl %al,%eax
c0021c01:	8b 54 24 40          	mov    0x40(%esp),%edx
c0021c05:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021c09:	8b 54 24 3c          	mov    0x3c(%esp),%edx
c0021c0d:	89 14 24             	mov    %edx,(%esp)
c0021c10:	8b 4c 24 38          	mov    0x38(%esp),%ecx
c0021c14:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021c18:	e8 bd fc ff ff       	call   c00218da <register_handler>
}
c0021c1d:	83 c4 2c             	add    $0x2c,%esp
c0021c20:	c3                   	ret    

c0021c21 <intr_context>:
}
c0021c21:	0f b6 05 41 60 03 c0 	movzbl 0xc0036041,%eax
c0021c28:	c3                   	ret    

c0021c29 <intr_yield_on_return>:
  ASSERT (intr_context ());
c0021c29:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021c30:	75 2f                	jne    c0021c61 <intr_yield_on_return+0x38>
{
c0021c32:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_context ());
c0021c35:	c7 44 24 10 a3 e5 02 	movl   $0xc002e5a3,0x10(%esp)
c0021c3c:	c0 
c0021c3d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021c44:	c0 
c0021c45:	c7 44 24 08 60 d1 02 	movl   $0xc002d160,0x8(%esp)
c0021c4c:	c0 
c0021c4d:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c0021c54:	00 
c0021c55:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021c5c:	e8 22 6d 00 00       	call   c0028983 <debug_panic>
  yield_on_return = true;
c0021c61:	c6 05 40 60 03 c0 01 	movb   $0x1,0xc0036040
c0021c68:	c3                   	ret    

c0021c69 <intr_handler>:
   function is called by the assembly language interrupt stubs in
   intr-stubs.S.  FRAME describes the interrupt and the
   interrupted thread's registers. */
void
intr_handler (struct intr_frame *frame) 
{
c0021c69:	56                   	push   %esi
c0021c6a:	53                   	push   %ebx
c0021c6b:	83 ec 24             	sub    $0x24,%esp
c0021c6e:	8b 5c 24 30          	mov    0x30(%esp),%ebx

  /* External interrupts are special.
     We only handle one at a time (so interrupts must be off)
     and they need to be acknowledged on the PIC (see below).
     An external interrupt handler cannot sleep. */
  external = frame->vec_no >= 0x20 && frame->vec_no < 0x30;
c0021c72:	8b 43 30             	mov    0x30(%ebx),%eax
c0021c75:	83 e8 20             	sub    $0x20,%eax
c0021c78:	83 f8 0f             	cmp    $0xf,%eax
  if (external) 
c0021c7b:	0f 96 c0             	setbe  %al
c0021c7e:	89 c6                	mov    %eax,%esi
c0021c80:	77 78                	ja     c0021cfa <intr_handler+0x91>
    {
      ASSERT (intr_get_level () == INTR_OFF);
c0021c82:	e8 ed fc ff ff       	call   c0021974 <intr_get_level>
c0021c87:	85 c0                	test   %eax,%eax
c0021c89:	74 2c                	je     c0021cb7 <intr_handler+0x4e>
c0021c8b:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0021c92:	c0 
c0021c93:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021c9a:	c0 
c0021c9b:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021ca2:	c0 
c0021ca3:	c7 44 24 04 65 01 00 	movl   $0x165,0x4(%esp)
c0021caa:	00 
c0021cab:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021cb2:	e8 cc 6c 00 00       	call   c0028983 <debug_panic>
      ASSERT (!intr_context ());
c0021cb7:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021cbe:	74 2c                	je     c0021cec <intr_handler+0x83>
c0021cc0:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0021cc7:	c0 
c0021cc8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021ccf:	c0 
c0021cd0:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021cd7:	c0 
c0021cd8:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0021cdf:	00 
c0021ce0:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021ce7:	e8 97 6c 00 00       	call   c0028983 <debug_panic>

      in_external_intr = true;
c0021cec:	c6 05 41 60 03 c0 01 	movb   $0x1,0xc0036041
      yield_on_return = false;
c0021cf3:	c6 05 40 60 03 c0 00 	movb   $0x0,0xc0036040
    }

  /* Invoke the interrupt's handler. */
  handler = intr_handlers[frame->vec_no];
c0021cfa:	8b 53 30             	mov    0x30(%ebx),%edx
c0021cfd:	8b 04 95 60 68 03 c0 	mov    -0x3ffc97a0(,%edx,4),%eax
  if (handler != NULL)
c0021d04:	85 c0                	test   %eax,%eax
c0021d06:	74 07                	je     c0021d0f <intr_handler+0xa6>
    handler (frame);
c0021d08:	89 1c 24             	mov    %ebx,(%esp)
c0021d0b:	ff d0                	call   *%eax
c0021d0d:	eb 3a                	jmp    c0021d49 <intr_handler+0xe0>
  else if (frame->vec_no == 0x27 || frame->vec_no == 0x2f)
c0021d0f:	89 d0                	mov    %edx,%eax
c0021d11:	83 e0 f7             	and    $0xfffffff7,%eax
c0021d14:	83 f8 27             	cmp    $0x27,%eax
c0021d17:	74 30                	je     c0021d49 <intr_handler+0xe0>
   unexpected interrupt is one that has no registered handler. */
static void
unexpected_interrupt (const struct intr_frame *f)
{
  /* Count the number so far. */
  unsigned int n = ++unexpected_cnt[f->vec_no];
c0021d19:	8b 04 95 60 60 03 c0 	mov    -0x3ffc9fa0(,%edx,4),%eax
c0021d20:	8d 48 01             	lea    0x1(%eax),%ecx
c0021d23:	89 0c 95 60 60 03 c0 	mov    %ecx,-0x3ffc9fa0(,%edx,4)
  /* If the number is a power of 2, print a message.  This rate
     limiting means that we get information about an uncommon
     unexpected interrupt the first time and fairly often after
     that, but one that occurs many times will not overwhelm the
     console. */
  if ((n & (n - 1)) == 0)
c0021d2a:	85 c1                	test   %eax,%ecx
c0021d2c:	75 1b                	jne    c0021d49 <intr_handler+0xe0>
    printf ("Unexpected interrupt %#04x (%s)\n",
c0021d2e:	8b 04 95 60 64 03 c0 	mov    -0x3ffc9ba0(,%edx,4),%eax
c0021d35:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021d39:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021d3d:	c7 04 24 5c e9 02 c0 	movl   $0xc002e95c,(%esp)
c0021d44:	e8 e5 4d 00 00       	call   c0026b2e <printf>
  if (external) 
c0021d49:	89 f0                	mov    %esi,%eax
c0021d4b:	84 c0                	test   %al,%al
c0021d4d:	0f 84 c4 00 00 00    	je     c0021e17 <intr_handler+0x1ae>
      ASSERT (intr_get_level () == INTR_OFF);
c0021d53:	e8 1c fc ff ff       	call   c0021974 <intr_get_level>
c0021d58:	85 c0                	test   %eax,%eax
c0021d5a:	74 2c                	je     c0021d88 <intr_handler+0x11f>
c0021d5c:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0021d63:	c0 
c0021d64:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021d6b:	c0 
c0021d6c:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021d73:	c0 
c0021d74:	c7 44 24 04 7c 01 00 	movl   $0x17c,0x4(%esp)
c0021d7b:	00 
c0021d7c:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021d83:	e8 fb 6b 00 00       	call   c0028983 <debug_panic>
      ASSERT (intr_context ());
c0021d88:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021d8f:	75 2c                	jne    c0021dbd <intr_handler+0x154>
c0021d91:	c7 44 24 10 a3 e5 02 	movl   $0xc002e5a3,0x10(%esp)
c0021d98:	c0 
c0021d99:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021da0:	c0 
c0021da1:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021da8:	c0 
c0021da9:	c7 44 24 04 7d 01 00 	movl   $0x17d,0x4(%esp)
c0021db0:	00 
c0021db1:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021db8:	e8 c6 6b 00 00       	call   c0028983 <debug_panic>
      in_external_intr = false;
c0021dbd:	c6 05 41 60 03 c0 00 	movb   $0x0,0xc0036041
      pic_end_of_interrupt (frame->vec_no); 
c0021dc4:	8b 53 30             	mov    0x30(%ebx),%edx
  ASSERT (irq >= 0x20 && irq < 0x30);
c0021dc7:	8d 42 e0             	lea    -0x20(%edx),%eax
c0021dca:	83 f8 0f             	cmp    $0xf,%eax
c0021dcd:	76 2c                	jbe    c0021dfb <intr_handler+0x192>
c0021dcf:	c7 44 24 10 31 e8 02 	movl   $0xc002e831,0x10(%esp)
c0021dd6:	c0 
c0021dd7:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021dde:	c0 
c0021ddf:	c7 44 24 08 3e d1 02 	movl   $0xc002d13e,0x8(%esp)
c0021de6:	c0 
c0021de7:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0021dee:	00 
c0021def:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021df6:	e8 88 6b 00 00       	call   c0028983 <debug_panic>
c0021dfb:	b8 20 00 00 00       	mov    $0x20,%eax
c0021e00:	e6 20                	out    %al,$0x20
  if (irq >= 0x28)
c0021e02:	83 fa 27             	cmp    $0x27,%edx
c0021e05:	7e 02                	jle    c0021e09 <intr_handler+0x1a0>
c0021e07:	e6 a0                	out    %al,$0xa0
      if (yield_on_return) 
c0021e09:	80 3d 40 60 03 c0 00 	cmpb   $0x0,0xc0036040
c0021e10:	74 05                	je     c0021e17 <intr_handler+0x1ae>
        thread_yield (); 
c0021e12:	e8 6e f6 ff ff       	call   c0021485 <thread_yield>
}
c0021e17:	83 c4 24             	add    $0x24,%esp
c0021e1a:	5b                   	pop    %ebx
c0021e1b:	5e                   	pop    %esi
c0021e1c:	c3                   	ret    

c0021e1d <intr_dump_frame>:
}

/* Dumps interrupt frame F to the console, for debugging. */
void
intr_dump_frame (const struct intr_frame *f) 
{
c0021e1d:	56                   	push   %esi
c0021e1e:	53                   	push   %ebx
c0021e1f:	83 ec 24             	sub    $0x24,%esp
c0021e22:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  /* Store current value of CR2 into `cr2'.
     CR2 is the linear address of the last page fault.
     See [IA32-v2a] "MOV--Move to/from Control Registers" and
     [IA32-v3a] 5.14 "Interrupt 14--Page Fault Exception
     (#PF)". */
  asm ("movl %%cr2, %0" : "=r" (cr2));
c0021e26:	0f 20 d6             	mov    %cr2,%esi

  printf ("Interrupt %#04x (%s) at eip=%p\n",
          f->vec_no, intr_names[f->vec_no], f->eip);
c0021e29:	8b 43 30             	mov    0x30(%ebx),%eax
  printf ("Interrupt %#04x (%s) at eip=%p\n",
c0021e2c:	8b 53 3c             	mov    0x3c(%ebx),%edx
c0021e2f:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0021e33:	8b 14 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%edx
c0021e3a:	89 54 24 08          	mov    %edx,0x8(%esp)
c0021e3e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021e42:	c7 04 24 80 e9 02 c0 	movl   $0xc002e980,(%esp)
c0021e49:	e8 e0 4c 00 00       	call   c0026b2e <printf>
  printf (" cr2=%08"PRIx32" error=%08"PRIx32"\n", cr2, f->error_code);
c0021e4e:	8b 43 34             	mov    0x34(%ebx),%eax
c0021e51:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021e55:	89 74 24 04          	mov    %esi,0x4(%esp)
c0021e59:	c7 04 24 4b e8 02 c0 	movl   $0xc002e84b,(%esp)
c0021e60:	e8 c9 4c 00 00       	call   c0026b2e <printf>
  printf (" eax=%08"PRIx32" ebx=%08"PRIx32" ecx=%08"PRIx32" edx=%08"PRIx32"\n",
c0021e65:	8b 43 14             	mov    0x14(%ebx),%eax
c0021e68:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021e6c:	8b 43 18             	mov    0x18(%ebx),%eax
c0021e6f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021e73:	8b 43 10             	mov    0x10(%ebx),%eax
c0021e76:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021e7a:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021e7d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021e81:	c7 04 24 a0 e9 02 c0 	movl   $0xc002e9a0,(%esp)
c0021e88:	e8 a1 4c 00 00       	call   c0026b2e <printf>
          f->eax, f->ebx, f->ecx, f->edx);
  printf (" esi=%08"PRIx32" edi=%08"PRIx32" esp=%08"PRIx32" ebp=%08"PRIx32"\n",
c0021e8d:	8b 43 08             	mov    0x8(%ebx),%eax
c0021e90:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021e94:	8b 43 48             	mov    0x48(%ebx),%eax
c0021e97:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021e9b:	8b 03                	mov    (%ebx),%eax
c0021e9d:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021ea1:	8b 43 04             	mov    0x4(%ebx),%eax
c0021ea4:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021ea8:	c7 04 24 c8 e9 02 c0 	movl   $0xc002e9c8,(%esp)
c0021eaf:	e8 7a 4c 00 00       	call   c0026b2e <printf>
          f->esi, f->edi, (uint32_t) f->esp, f->ebp);
  printf (" cs=%04"PRIx16" ds=%04"PRIx16" es=%04"PRIx16" ss=%04"PRIx16"\n",
c0021eb4:	0f b7 43 4c          	movzwl 0x4c(%ebx),%eax
c0021eb8:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021ebc:	0f b7 43 28          	movzwl 0x28(%ebx),%eax
c0021ec0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021ec4:	0f b7 43 2c          	movzwl 0x2c(%ebx),%eax
c0021ec8:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021ecc:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
c0021ed0:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021ed4:	c7 04 24 f0 e9 02 c0 	movl   $0xc002e9f0,(%esp)
c0021edb:	e8 4e 4c 00 00       	call   c0026b2e <printf>
          f->cs, f->ds, f->es, f->ss);
}
c0021ee0:	83 c4 24             	add    $0x24,%esp
c0021ee3:	5b                   	pop    %ebx
c0021ee4:	5e                   	pop    %esi
c0021ee5:	c3                   	ret    

c0021ee6 <intr_name>:

/* Returns the name of interrupt VEC. */
const char *
intr_name (uint8_t vec) 
{
  return intr_names[vec];
c0021ee6:	0f b6 44 24 04       	movzbl 0x4(%esp),%eax
c0021eeb:	8b 04 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%eax
}
c0021ef2:	c3                   	ret    

c0021ef3 <intr_entry>:
   We "fall through" to intr_exit to return from the interrupt.
*/
.func intr_entry
intr_entry:
	/* Save caller's registers. */
	pushl %ds
c0021ef3:	1e                   	push   %ds
	pushl %es
c0021ef4:	06                   	push   %es
	pushl %fs
c0021ef5:	0f a0                	push   %fs
	pushl %gs
c0021ef7:	0f a8                	push   %gs
	pushal
c0021ef9:	60                   	pusha  
        
	/* Set up kernel environment. */
	cld			/* String instructions go upward. */
c0021efa:	fc                   	cld    
	mov $SEL_KDSEG, %eax	/* Initialize segment registers. */
c0021efb:	b8 10 00 00 00       	mov    $0x10,%eax
	mov %eax, %ds
c0021f00:	8e d8                	mov    %eax,%ds
	mov %eax, %es
c0021f02:	8e c0                	mov    %eax,%es
	leal 56(%esp), %ebp	/* Set up frame pointer. */
c0021f04:	8d 6c 24 38          	lea    0x38(%esp),%ebp

	/* Call interrupt handler. */
	pushl %esp
c0021f08:	54                   	push   %esp
.globl intr_handler
	call intr_handler
c0021f09:	e8 5b fd ff ff       	call   c0021c69 <intr_handler>
	addl $4, %esp
c0021f0e:	83 c4 04             	add    $0x4,%esp

c0021f11 <intr_exit>:
   userprog/process.c). */
.globl intr_exit
.func intr_exit
intr_exit:
        /* Restore caller's registers. */
	popal
c0021f11:	61                   	popa   
	popl %gs
c0021f12:	0f a9                	pop    %gs
	popl %fs
c0021f14:	0f a1                	pop    %fs
	popl %es
c0021f16:	07                   	pop    %es
	popl %ds
c0021f17:	1f                   	pop    %ds

        /* Discard `struct intr_frame' vec_no, error_code,
           frame_pointer members. */
	addl $12, %esp
c0021f18:	83 c4 0c             	add    $0xc,%esp

        /* Return to caller. */
	iret
c0021f1b:	cf                   	iret   

c0021f1c <intr00_stub>:
                                                \
	.data;                                  \
	.long intr##NUMBER##_stub;

/* All the stubs. */
STUB(00, zero) STUB(01, zero) STUB(02, zero) STUB(03, zero)
c0021f1c:	55                   	push   %ebp
c0021f1d:	6a 00                	push   $0x0
c0021f1f:	6a 00                	push   $0x0
c0021f21:	eb d0                	jmp    c0021ef3 <intr_entry>

c0021f23 <intr01_stub>:
c0021f23:	55                   	push   %ebp
c0021f24:	6a 00                	push   $0x0
c0021f26:	6a 01                	push   $0x1
c0021f28:	eb c9                	jmp    c0021ef3 <intr_entry>

c0021f2a <intr02_stub>:
c0021f2a:	55                   	push   %ebp
c0021f2b:	6a 00                	push   $0x0
c0021f2d:	6a 02                	push   $0x2
c0021f2f:	eb c2                	jmp    c0021ef3 <intr_entry>

c0021f31 <intr03_stub>:
c0021f31:	55                   	push   %ebp
c0021f32:	6a 00                	push   $0x0
c0021f34:	6a 03                	push   $0x3
c0021f36:	eb bb                	jmp    c0021ef3 <intr_entry>

c0021f38 <intr04_stub>:
STUB(04, zero) STUB(05, zero) STUB(06, zero) STUB(07, zero)
c0021f38:	55                   	push   %ebp
c0021f39:	6a 00                	push   $0x0
c0021f3b:	6a 04                	push   $0x4
c0021f3d:	eb b4                	jmp    c0021ef3 <intr_entry>

c0021f3f <intr05_stub>:
c0021f3f:	55                   	push   %ebp
c0021f40:	6a 00                	push   $0x0
c0021f42:	6a 05                	push   $0x5
c0021f44:	eb ad                	jmp    c0021ef3 <intr_entry>

c0021f46 <intr06_stub>:
c0021f46:	55                   	push   %ebp
c0021f47:	6a 00                	push   $0x0
c0021f49:	6a 06                	push   $0x6
c0021f4b:	eb a6                	jmp    c0021ef3 <intr_entry>

c0021f4d <intr07_stub>:
c0021f4d:	55                   	push   %ebp
c0021f4e:	6a 00                	push   $0x0
c0021f50:	6a 07                	push   $0x7
c0021f52:	eb 9f                	jmp    c0021ef3 <intr_entry>

c0021f54 <intr08_stub>:
STUB(08, REAL) STUB(09, zero) STUB(0a, REAL) STUB(0b, REAL)
c0021f54:	ff 34 24             	pushl  (%esp)
c0021f57:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f5b:	6a 08                	push   $0x8
c0021f5d:	eb 94                	jmp    c0021ef3 <intr_entry>

c0021f5f <intr09_stub>:
c0021f5f:	55                   	push   %ebp
c0021f60:	6a 00                	push   $0x0
c0021f62:	6a 09                	push   $0x9
c0021f64:	eb 8d                	jmp    c0021ef3 <intr_entry>

c0021f66 <intr0a_stub>:
c0021f66:	ff 34 24             	pushl  (%esp)
c0021f69:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f6d:	6a 0a                	push   $0xa
c0021f6f:	eb 82                	jmp    c0021ef3 <intr_entry>

c0021f71 <intr0b_stub>:
c0021f71:	ff 34 24             	pushl  (%esp)
c0021f74:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f78:	6a 0b                	push   $0xb
c0021f7a:	e9 74 ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021f7f <intr0c_stub>:
STUB(0c, zero) STUB(0d, REAL) STUB(0e, REAL) STUB(0f, zero)
c0021f7f:	55                   	push   %ebp
c0021f80:	6a 00                	push   $0x0
c0021f82:	6a 0c                	push   $0xc
c0021f84:	e9 6a ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021f89 <intr0d_stub>:
c0021f89:	ff 34 24             	pushl  (%esp)
c0021f8c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f90:	6a 0d                	push   $0xd
c0021f92:	e9 5c ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021f97 <intr0e_stub>:
c0021f97:	ff 34 24             	pushl  (%esp)
c0021f9a:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f9e:	6a 0e                	push   $0xe
c0021fa0:	e9 4e ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021fa5 <intr0f_stub>:
c0021fa5:	55                   	push   %ebp
c0021fa6:	6a 00                	push   $0x0
c0021fa8:	6a 0f                	push   $0xf
c0021faa:	e9 44 ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021faf <intr10_stub>:

STUB(10, zero) STUB(11, REAL) STUB(12, zero) STUB(13, zero)
c0021faf:	55                   	push   %ebp
c0021fb0:	6a 00                	push   $0x0
c0021fb2:	6a 10                	push   $0x10
c0021fb4:	e9 3a ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021fb9 <intr11_stub>:
c0021fb9:	ff 34 24             	pushl  (%esp)
c0021fbc:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fc0:	6a 11                	push   $0x11
c0021fc2:	e9 2c ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021fc7 <intr12_stub>:
c0021fc7:	55                   	push   %ebp
c0021fc8:	6a 00                	push   $0x0
c0021fca:	6a 12                	push   $0x12
c0021fcc:	e9 22 ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021fd1 <intr13_stub>:
c0021fd1:	55                   	push   %ebp
c0021fd2:	6a 00                	push   $0x0
c0021fd4:	6a 13                	push   $0x13
c0021fd6:	e9 18 ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021fdb <intr14_stub>:
STUB(14, zero) STUB(15, zero) STUB(16, zero) STUB(17, zero)
c0021fdb:	55                   	push   %ebp
c0021fdc:	6a 00                	push   $0x0
c0021fde:	6a 14                	push   $0x14
c0021fe0:	e9 0e ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021fe5 <intr15_stub>:
c0021fe5:	55                   	push   %ebp
c0021fe6:	6a 00                	push   $0x0
c0021fe8:	6a 15                	push   $0x15
c0021fea:	e9 04 ff ff ff       	jmp    c0021ef3 <intr_entry>

c0021fef <intr16_stub>:
c0021fef:	55                   	push   %ebp
c0021ff0:	6a 00                	push   $0x0
c0021ff2:	6a 16                	push   $0x16
c0021ff4:	e9 fa fe ff ff       	jmp    c0021ef3 <intr_entry>

c0021ff9 <intr17_stub>:
c0021ff9:	55                   	push   %ebp
c0021ffa:	6a 00                	push   $0x0
c0021ffc:	6a 17                	push   $0x17
c0021ffe:	e9 f0 fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022003 <intr18_stub>:
STUB(18, REAL) STUB(19, zero) STUB(1a, REAL) STUB(1b, REAL)
c0022003:	ff 34 24             	pushl  (%esp)
c0022006:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002200a:	6a 18                	push   $0x18
c002200c:	e9 e2 fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022011 <intr19_stub>:
c0022011:	55                   	push   %ebp
c0022012:	6a 00                	push   $0x0
c0022014:	6a 19                	push   $0x19
c0022016:	e9 d8 fe ff ff       	jmp    c0021ef3 <intr_entry>

c002201b <intr1a_stub>:
c002201b:	ff 34 24             	pushl  (%esp)
c002201e:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022022:	6a 1a                	push   $0x1a
c0022024:	e9 ca fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022029 <intr1b_stub>:
c0022029:	ff 34 24             	pushl  (%esp)
c002202c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022030:	6a 1b                	push   $0x1b
c0022032:	e9 bc fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022037 <intr1c_stub>:
STUB(1c, zero) STUB(1d, REAL) STUB(1e, REAL) STUB(1f, zero)
c0022037:	55                   	push   %ebp
c0022038:	6a 00                	push   $0x0
c002203a:	6a 1c                	push   $0x1c
c002203c:	e9 b2 fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022041 <intr1d_stub>:
c0022041:	ff 34 24             	pushl  (%esp)
c0022044:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022048:	6a 1d                	push   $0x1d
c002204a:	e9 a4 fe ff ff       	jmp    c0021ef3 <intr_entry>

c002204f <intr1e_stub>:
c002204f:	ff 34 24             	pushl  (%esp)
c0022052:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022056:	6a 1e                	push   $0x1e
c0022058:	e9 96 fe ff ff       	jmp    c0021ef3 <intr_entry>

c002205d <intr1f_stub>:
c002205d:	55                   	push   %ebp
c002205e:	6a 00                	push   $0x0
c0022060:	6a 1f                	push   $0x1f
c0022062:	e9 8c fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022067 <intr20_stub>:

STUB(20, zero) STUB(21, zero) STUB(22, zero) STUB(23, zero)
c0022067:	55                   	push   %ebp
c0022068:	6a 00                	push   $0x0
c002206a:	6a 20                	push   $0x20
c002206c:	e9 82 fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022071 <intr21_stub>:
c0022071:	55                   	push   %ebp
c0022072:	6a 00                	push   $0x0
c0022074:	6a 21                	push   $0x21
c0022076:	e9 78 fe ff ff       	jmp    c0021ef3 <intr_entry>

c002207b <intr22_stub>:
c002207b:	55                   	push   %ebp
c002207c:	6a 00                	push   $0x0
c002207e:	6a 22                	push   $0x22
c0022080:	e9 6e fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022085 <intr23_stub>:
c0022085:	55                   	push   %ebp
c0022086:	6a 00                	push   $0x0
c0022088:	6a 23                	push   $0x23
c002208a:	e9 64 fe ff ff       	jmp    c0021ef3 <intr_entry>

c002208f <intr24_stub>:
STUB(24, zero) STUB(25, zero) STUB(26, zero) STUB(27, zero)
c002208f:	55                   	push   %ebp
c0022090:	6a 00                	push   $0x0
c0022092:	6a 24                	push   $0x24
c0022094:	e9 5a fe ff ff       	jmp    c0021ef3 <intr_entry>

c0022099 <intr25_stub>:
c0022099:	55                   	push   %ebp
c002209a:	6a 00                	push   $0x0
c002209c:	6a 25                	push   $0x25
c002209e:	e9 50 fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220a3 <intr26_stub>:
c00220a3:	55                   	push   %ebp
c00220a4:	6a 00                	push   $0x0
c00220a6:	6a 26                	push   $0x26
c00220a8:	e9 46 fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220ad <intr27_stub>:
c00220ad:	55                   	push   %ebp
c00220ae:	6a 00                	push   $0x0
c00220b0:	6a 27                	push   $0x27
c00220b2:	e9 3c fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220b7 <intr28_stub>:
STUB(28, zero) STUB(29, zero) STUB(2a, zero) STUB(2b, zero)
c00220b7:	55                   	push   %ebp
c00220b8:	6a 00                	push   $0x0
c00220ba:	6a 28                	push   $0x28
c00220bc:	e9 32 fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220c1 <intr29_stub>:
c00220c1:	55                   	push   %ebp
c00220c2:	6a 00                	push   $0x0
c00220c4:	6a 29                	push   $0x29
c00220c6:	e9 28 fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220cb <intr2a_stub>:
c00220cb:	55                   	push   %ebp
c00220cc:	6a 00                	push   $0x0
c00220ce:	6a 2a                	push   $0x2a
c00220d0:	e9 1e fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220d5 <intr2b_stub>:
c00220d5:	55                   	push   %ebp
c00220d6:	6a 00                	push   $0x0
c00220d8:	6a 2b                	push   $0x2b
c00220da:	e9 14 fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220df <intr2c_stub>:
STUB(2c, zero) STUB(2d, zero) STUB(2e, zero) STUB(2f, zero)
c00220df:	55                   	push   %ebp
c00220e0:	6a 00                	push   $0x0
c00220e2:	6a 2c                	push   $0x2c
c00220e4:	e9 0a fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220e9 <intr2d_stub>:
c00220e9:	55                   	push   %ebp
c00220ea:	6a 00                	push   $0x0
c00220ec:	6a 2d                	push   $0x2d
c00220ee:	e9 00 fe ff ff       	jmp    c0021ef3 <intr_entry>

c00220f3 <intr2e_stub>:
c00220f3:	55                   	push   %ebp
c00220f4:	6a 00                	push   $0x0
c00220f6:	6a 2e                	push   $0x2e
c00220f8:	e9 f6 fd ff ff       	jmp    c0021ef3 <intr_entry>

c00220fd <intr2f_stub>:
c00220fd:	55                   	push   %ebp
c00220fe:	6a 00                	push   $0x0
c0022100:	6a 2f                	push   $0x2f
c0022102:	e9 ec fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022107 <intr30_stub>:

STUB(30, zero) STUB(31, zero) STUB(32, zero) STUB(33, zero)
c0022107:	55                   	push   %ebp
c0022108:	6a 00                	push   $0x0
c002210a:	6a 30                	push   $0x30
c002210c:	e9 e2 fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022111 <intr31_stub>:
c0022111:	55                   	push   %ebp
c0022112:	6a 00                	push   $0x0
c0022114:	6a 31                	push   $0x31
c0022116:	e9 d8 fd ff ff       	jmp    c0021ef3 <intr_entry>

c002211b <intr32_stub>:
c002211b:	55                   	push   %ebp
c002211c:	6a 00                	push   $0x0
c002211e:	6a 32                	push   $0x32
c0022120:	e9 ce fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022125 <intr33_stub>:
c0022125:	55                   	push   %ebp
c0022126:	6a 00                	push   $0x0
c0022128:	6a 33                	push   $0x33
c002212a:	e9 c4 fd ff ff       	jmp    c0021ef3 <intr_entry>

c002212f <intr34_stub>:
STUB(34, zero) STUB(35, zero) STUB(36, zero) STUB(37, zero)
c002212f:	55                   	push   %ebp
c0022130:	6a 00                	push   $0x0
c0022132:	6a 34                	push   $0x34
c0022134:	e9 ba fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022139 <intr35_stub>:
c0022139:	55                   	push   %ebp
c002213a:	6a 00                	push   $0x0
c002213c:	6a 35                	push   $0x35
c002213e:	e9 b0 fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022143 <intr36_stub>:
c0022143:	55                   	push   %ebp
c0022144:	6a 00                	push   $0x0
c0022146:	6a 36                	push   $0x36
c0022148:	e9 a6 fd ff ff       	jmp    c0021ef3 <intr_entry>

c002214d <intr37_stub>:
c002214d:	55                   	push   %ebp
c002214e:	6a 00                	push   $0x0
c0022150:	6a 37                	push   $0x37
c0022152:	e9 9c fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022157 <intr38_stub>:
STUB(38, zero) STUB(39, zero) STUB(3a, zero) STUB(3b, zero)
c0022157:	55                   	push   %ebp
c0022158:	6a 00                	push   $0x0
c002215a:	6a 38                	push   $0x38
c002215c:	e9 92 fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022161 <intr39_stub>:
c0022161:	55                   	push   %ebp
c0022162:	6a 00                	push   $0x0
c0022164:	6a 39                	push   $0x39
c0022166:	e9 88 fd ff ff       	jmp    c0021ef3 <intr_entry>

c002216b <intr3a_stub>:
c002216b:	55                   	push   %ebp
c002216c:	6a 00                	push   $0x0
c002216e:	6a 3a                	push   $0x3a
c0022170:	e9 7e fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022175 <intr3b_stub>:
c0022175:	55                   	push   %ebp
c0022176:	6a 00                	push   $0x0
c0022178:	6a 3b                	push   $0x3b
c002217a:	e9 74 fd ff ff       	jmp    c0021ef3 <intr_entry>

c002217f <intr3c_stub>:
STUB(3c, zero) STUB(3d, zero) STUB(3e, zero) STUB(3f, zero)
c002217f:	55                   	push   %ebp
c0022180:	6a 00                	push   $0x0
c0022182:	6a 3c                	push   $0x3c
c0022184:	e9 6a fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022189 <intr3d_stub>:
c0022189:	55                   	push   %ebp
c002218a:	6a 00                	push   $0x0
c002218c:	6a 3d                	push   $0x3d
c002218e:	e9 60 fd ff ff       	jmp    c0021ef3 <intr_entry>

c0022193 <intr3e_stub>:
c0022193:	55                   	push   %ebp
c0022194:	6a 00                	push   $0x0
c0022196:	6a 3e                	push   $0x3e
c0022198:	e9 56 fd ff ff       	jmp    c0021ef3 <intr_entry>

c002219d <intr3f_stub>:
c002219d:	55                   	push   %ebp
c002219e:	6a 00                	push   $0x0
c00221a0:	6a 3f                	push   $0x3f
c00221a2:	e9 4c fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221a7 <intr40_stub>:

STUB(40, zero) STUB(41, zero) STUB(42, zero) STUB(43, zero)
c00221a7:	55                   	push   %ebp
c00221a8:	6a 00                	push   $0x0
c00221aa:	6a 40                	push   $0x40
c00221ac:	e9 42 fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221b1 <intr41_stub>:
c00221b1:	55                   	push   %ebp
c00221b2:	6a 00                	push   $0x0
c00221b4:	6a 41                	push   $0x41
c00221b6:	e9 38 fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221bb <intr42_stub>:
c00221bb:	55                   	push   %ebp
c00221bc:	6a 00                	push   $0x0
c00221be:	6a 42                	push   $0x42
c00221c0:	e9 2e fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221c5 <intr43_stub>:
c00221c5:	55                   	push   %ebp
c00221c6:	6a 00                	push   $0x0
c00221c8:	6a 43                	push   $0x43
c00221ca:	e9 24 fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221cf <intr44_stub>:
STUB(44, zero) STUB(45, zero) STUB(46, zero) STUB(47, zero)
c00221cf:	55                   	push   %ebp
c00221d0:	6a 00                	push   $0x0
c00221d2:	6a 44                	push   $0x44
c00221d4:	e9 1a fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221d9 <intr45_stub>:
c00221d9:	55                   	push   %ebp
c00221da:	6a 00                	push   $0x0
c00221dc:	6a 45                	push   $0x45
c00221de:	e9 10 fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221e3 <intr46_stub>:
c00221e3:	55                   	push   %ebp
c00221e4:	6a 00                	push   $0x0
c00221e6:	6a 46                	push   $0x46
c00221e8:	e9 06 fd ff ff       	jmp    c0021ef3 <intr_entry>

c00221ed <intr47_stub>:
c00221ed:	55                   	push   %ebp
c00221ee:	6a 00                	push   $0x0
c00221f0:	6a 47                	push   $0x47
c00221f2:	e9 fc fc ff ff       	jmp    c0021ef3 <intr_entry>

c00221f7 <intr48_stub>:
STUB(48, zero) STUB(49, zero) STUB(4a, zero) STUB(4b, zero)
c00221f7:	55                   	push   %ebp
c00221f8:	6a 00                	push   $0x0
c00221fa:	6a 48                	push   $0x48
c00221fc:	e9 f2 fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022201 <intr49_stub>:
c0022201:	55                   	push   %ebp
c0022202:	6a 00                	push   $0x0
c0022204:	6a 49                	push   $0x49
c0022206:	e9 e8 fc ff ff       	jmp    c0021ef3 <intr_entry>

c002220b <intr4a_stub>:
c002220b:	55                   	push   %ebp
c002220c:	6a 00                	push   $0x0
c002220e:	6a 4a                	push   $0x4a
c0022210:	e9 de fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022215 <intr4b_stub>:
c0022215:	55                   	push   %ebp
c0022216:	6a 00                	push   $0x0
c0022218:	6a 4b                	push   $0x4b
c002221a:	e9 d4 fc ff ff       	jmp    c0021ef3 <intr_entry>

c002221f <intr4c_stub>:
STUB(4c, zero) STUB(4d, zero) STUB(4e, zero) STUB(4f, zero)
c002221f:	55                   	push   %ebp
c0022220:	6a 00                	push   $0x0
c0022222:	6a 4c                	push   $0x4c
c0022224:	e9 ca fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022229 <intr4d_stub>:
c0022229:	55                   	push   %ebp
c002222a:	6a 00                	push   $0x0
c002222c:	6a 4d                	push   $0x4d
c002222e:	e9 c0 fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022233 <intr4e_stub>:
c0022233:	55                   	push   %ebp
c0022234:	6a 00                	push   $0x0
c0022236:	6a 4e                	push   $0x4e
c0022238:	e9 b6 fc ff ff       	jmp    c0021ef3 <intr_entry>

c002223d <intr4f_stub>:
c002223d:	55                   	push   %ebp
c002223e:	6a 00                	push   $0x0
c0022240:	6a 4f                	push   $0x4f
c0022242:	e9 ac fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022247 <intr50_stub>:

STUB(50, zero) STUB(51, zero) STUB(52, zero) STUB(53, zero)
c0022247:	55                   	push   %ebp
c0022248:	6a 00                	push   $0x0
c002224a:	6a 50                	push   $0x50
c002224c:	e9 a2 fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022251 <intr51_stub>:
c0022251:	55                   	push   %ebp
c0022252:	6a 00                	push   $0x0
c0022254:	6a 51                	push   $0x51
c0022256:	e9 98 fc ff ff       	jmp    c0021ef3 <intr_entry>

c002225b <intr52_stub>:
c002225b:	55                   	push   %ebp
c002225c:	6a 00                	push   $0x0
c002225e:	6a 52                	push   $0x52
c0022260:	e9 8e fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022265 <intr53_stub>:
c0022265:	55                   	push   %ebp
c0022266:	6a 00                	push   $0x0
c0022268:	6a 53                	push   $0x53
c002226a:	e9 84 fc ff ff       	jmp    c0021ef3 <intr_entry>

c002226f <intr54_stub>:
STUB(54, zero) STUB(55, zero) STUB(56, zero) STUB(57, zero)
c002226f:	55                   	push   %ebp
c0022270:	6a 00                	push   $0x0
c0022272:	6a 54                	push   $0x54
c0022274:	e9 7a fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022279 <intr55_stub>:
c0022279:	55                   	push   %ebp
c002227a:	6a 00                	push   $0x0
c002227c:	6a 55                	push   $0x55
c002227e:	e9 70 fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022283 <intr56_stub>:
c0022283:	55                   	push   %ebp
c0022284:	6a 00                	push   $0x0
c0022286:	6a 56                	push   $0x56
c0022288:	e9 66 fc ff ff       	jmp    c0021ef3 <intr_entry>

c002228d <intr57_stub>:
c002228d:	55                   	push   %ebp
c002228e:	6a 00                	push   $0x0
c0022290:	6a 57                	push   $0x57
c0022292:	e9 5c fc ff ff       	jmp    c0021ef3 <intr_entry>

c0022297 <intr58_stub>:
STUB(58, zero) STUB(59, zero) STUB(5a, zero) STUB(5b, zero)
c0022297:	55                   	push   %ebp
c0022298:	6a 00                	push   $0x0
c002229a:	6a 58                	push   $0x58
c002229c:	e9 52 fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222a1 <intr59_stub>:
c00222a1:	55                   	push   %ebp
c00222a2:	6a 00                	push   $0x0
c00222a4:	6a 59                	push   $0x59
c00222a6:	e9 48 fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222ab <intr5a_stub>:
c00222ab:	55                   	push   %ebp
c00222ac:	6a 00                	push   $0x0
c00222ae:	6a 5a                	push   $0x5a
c00222b0:	e9 3e fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222b5 <intr5b_stub>:
c00222b5:	55                   	push   %ebp
c00222b6:	6a 00                	push   $0x0
c00222b8:	6a 5b                	push   $0x5b
c00222ba:	e9 34 fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222bf <intr5c_stub>:
STUB(5c, zero) STUB(5d, zero) STUB(5e, zero) STUB(5f, zero)
c00222bf:	55                   	push   %ebp
c00222c0:	6a 00                	push   $0x0
c00222c2:	6a 5c                	push   $0x5c
c00222c4:	e9 2a fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222c9 <intr5d_stub>:
c00222c9:	55                   	push   %ebp
c00222ca:	6a 00                	push   $0x0
c00222cc:	6a 5d                	push   $0x5d
c00222ce:	e9 20 fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222d3 <intr5e_stub>:
c00222d3:	55                   	push   %ebp
c00222d4:	6a 00                	push   $0x0
c00222d6:	6a 5e                	push   $0x5e
c00222d8:	e9 16 fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222dd <intr5f_stub>:
c00222dd:	55                   	push   %ebp
c00222de:	6a 00                	push   $0x0
c00222e0:	6a 5f                	push   $0x5f
c00222e2:	e9 0c fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222e7 <intr60_stub>:

STUB(60, zero) STUB(61, zero) STUB(62, zero) STUB(63, zero)
c00222e7:	55                   	push   %ebp
c00222e8:	6a 00                	push   $0x0
c00222ea:	6a 60                	push   $0x60
c00222ec:	e9 02 fc ff ff       	jmp    c0021ef3 <intr_entry>

c00222f1 <intr61_stub>:
c00222f1:	55                   	push   %ebp
c00222f2:	6a 00                	push   $0x0
c00222f4:	6a 61                	push   $0x61
c00222f6:	e9 f8 fb ff ff       	jmp    c0021ef3 <intr_entry>

c00222fb <intr62_stub>:
c00222fb:	55                   	push   %ebp
c00222fc:	6a 00                	push   $0x0
c00222fe:	6a 62                	push   $0x62
c0022300:	e9 ee fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022305 <intr63_stub>:
c0022305:	55                   	push   %ebp
c0022306:	6a 00                	push   $0x0
c0022308:	6a 63                	push   $0x63
c002230a:	e9 e4 fb ff ff       	jmp    c0021ef3 <intr_entry>

c002230f <intr64_stub>:
STUB(64, zero) STUB(65, zero) STUB(66, zero) STUB(67, zero)
c002230f:	55                   	push   %ebp
c0022310:	6a 00                	push   $0x0
c0022312:	6a 64                	push   $0x64
c0022314:	e9 da fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022319 <intr65_stub>:
c0022319:	55                   	push   %ebp
c002231a:	6a 00                	push   $0x0
c002231c:	6a 65                	push   $0x65
c002231e:	e9 d0 fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022323 <intr66_stub>:
c0022323:	55                   	push   %ebp
c0022324:	6a 00                	push   $0x0
c0022326:	6a 66                	push   $0x66
c0022328:	e9 c6 fb ff ff       	jmp    c0021ef3 <intr_entry>

c002232d <intr67_stub>:
c002232d:	55                   	push   %ebp
c002232e:	6a 00                	push   $0x0
c0022330:	6a 67                	push   $0x67
c0022332:	e9 bc fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022337 <intr68_stub>:
STUB(68, zero) STUB(69, zero) STUB(6a, zero) STUB(6b, zero)
c0022337:	55                   	push   %ebp
c0022338:	6a 00                	push   $0x0
c002233a:	6a 68                	push   $0x68
c002233c:	e9 b2 fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022341 <intr69_stub>:
c0022341:	55                   	push   %ebp
c0022342:	6a 00                	push   $0x0
c0022344:	6a 69                	push   $0x69
c0022346:	e9 a8 fb ff ff       	jmp    c0021ef3 <intr_entry>

c002234b <intr6a_stub>:
c002234b:	55                   	push   %ebp
c002234c:	6a 00                	push   $0x0
c002234e:	6a 6a                	push   $0x6a
c0022350:	e9 9e fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022355 <intr6b_stub>:
c0022355:	55                   	push   %ebp
c0022356:	6a 00                	push   $0x0
c0022358:	6a 6b                	push   $0x6b
c002235a:	e9 94 fb ff ff       	jmp    c0021ef3 <intr_entry>

c002235f <intr6c_stub>:
STUB(6c, zero) STUB(6d, zero) STUB(6e, zero) STUB(6f, zero)
c002235f:	55                   	push   %ebp
c0022360:	6a 00                	push   $0x0
c0022362:	6a 6c                	push   $0x6c
c0022364:	e9 8a fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022369 <intr6d_stub>:
c0022369:	55                   	push   %ebp
c002236a:	6a 00                	push   $0x0
c002236c:	6a 6d                	push   $0x6d
c002236e:	e9 80 fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022373 <intr6e_stub>:
c0022373:	55                   	push   %ebp
c0022374:	6a 00                	push   $0x0
c0022376:	6a 6e                	push   $0x6e
c0022378:	e9 76 fb ff ff       	jmp    c0021ef3 <intr_entry>

c002237d <intr6f_stub>:
c002237d:	55                   	push   %ebp
c002237e:	6a 00                	push   $0x0
c0022380:	6a 6f                	push   $0x6f
c0022382:	e9 6c fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022387 <intr70_stub>:

STUB(70, zero) STUB(71, zero) STUB(72, zero) STUB(73, zero)
c0022387:	55                   	push   %ebp
c0022388:	6a 00                	push   $0x0
c002238a:	6a 70                	push   $0x70
c002238c:	e9 62 fb ff ff       	jmp    c0021ef3 <intr_entry>

c0022391 <intr71_stub>:
c0022391:	55                   	push   %ebp
c0022392:	6a 00                	push   $0x0
c0022394:	6a 71                	push   $0x71
c0022396:	e9 58 fb ff ff       	jmp    c0021ef3 <intr_entry>

c002239b <intr72_stub>:
c002239b:	55                   	push   %ebp
c002239c:	6a 00                	push   $0x0
c002239e:	6a 72                	push   $0x72
c00223a0:	e9 4e fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223a5 <intr73_stub>:
c00223a5:	55                   	push   %ebp
c00223a6:	6a 00                	push   $0x0
c00223a8:	6a 73                	push   $0x73
c00223aa:	e9 44 fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223af <intr74_stub>:
STUB(74, zero) STUB(75, zero) STUB(76, zero) STUB(77, zero)
c00223af:	55                   	push   %ebp
c00223b0:	6a 00                	push   $0x0
c00223b2:	6a 74                	push   $0x74
c00223b4:	e9 3a fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223b9 <intr75_stub>:
c00223b9:	55                   	push   %ebp
c00223ba:	6a 00                	push   $0x0
c00223bc:	6a 75                	push   $0x75
c00223be:	e9 30 fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223c3 <intr76_stub>:
c00223c3:	55                   	push   %ebp
c00223c4:	6a 00                	push   $0x0
c00223c6:	6a 76                	push   $0x76
c00223c8:	e9 26 fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223cd <intr77_stub>:
c00223cd:	55                   	push   %ebp
c00223ce:	6a 00                	push   $0x0
c00223d0:	6a 77                	push   $0x77
c00223d2:	e9 1c fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223d7 <intr78_stub>:
STUB(78, zero) STUB(79, zero) STUB(7a, zero) STUB(7b, zero)
c00223d7:	55                   	push   %ebp
c00223d8:	6a 00                	push   $0x0
c00223da:	6a 78                	push   $0x78
c00223dc:	e9 12 fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223e1 <intr79_stub>:
c00223e1:	55                   	push   %ebp
c00223e2:	6a 00                	push   $0x0
c00223e4:	6a 79                	push   $0x79
c00223e6:	e9 08 fb ff ff       	jmp    c0021ef3 <intr_entry>

c00223eb <intr7a_stub>:
c00223eb:	55                   	push   %ebp
c00223ec:	6a 00                	push   $0x0
c00223ee:	6a 7a                	push   $0x7a
c00223f0:	e9 fe fa ff ff       	jmp    c0021ef3 <intr_entry>

c00223f5 <intr7b_stub>:
c00223f5:	55                   	push   %ebp
c00223f6:	6a 00                	push   $0x0
c00223f8:	6a 7b                	push   $0x7b
c00223fa:	e9 f4 fa ff ff       	jmp    c0021ef3 <intr_entry>

c00223ff <intr7c_stub>:
STUB(7c, zero) STUB(7d, zero) STUB(7e, zero) STUB(7f, zero)
c00223ff:	55                   	push   %ebp
c0022400:	6a 00                	push   $0x0
c0022402:	6a 7c                	push   $0x7c
c0022404:	e9 ea fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022409 <intr7d_stub>:
c0022409:	55                   	push   %ebp
c002240a:	6a 00                	push   $0x0
c002240c:	6a 7d                	push   $0x7d
c002240e:	e9 e0 fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022413 <intr7e_stub>:
c0022413:	55                   	push   %ebp
c0022414:	6a 00                	push   $0x0
c0022416:	6a 7e                	push   $0x7e
c0022418:	e9 d6 fa ff ff       	jmp    c0021ef3 <intr_entry>

c002241d <intr7f_stub>:
c002241d:	55                   	push   %ebp
c002241e:	6a 00                	push   $0x0
c0022420:	6a 7f                	push   $0x7f
c0022422:	e9 cc fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022427 <intr80_stub>:

STUB(80, zero) STUB(81, zero) STUB(82, zero) STUB(83, zero)
c0022427:	55                   	push   %ebp
c0022428:	6a 00                	push   $0x0
c002242a:	68 80 00 00 00       	push   $0x80
c002242f:	e9 bf fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022434 <intr81_stub>:
c0022434:	55                   	push   %ebp
c0022435:	6a 00                	push   $0x0
c0022437:	68 81 00 00 00       	push   $0x81
c002243c:	e9 b2 fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022441 <intr82_stub>:
c0022441:	55                   	push   %ebp
c0022442:	6a 00                	push   $0x0
c0022444:	68 82 00 00 00       	push   $0x82
c0022449:	e9 a5 fa ff ff       	jmp    c0021ef3 <intr_entry>

c002244e <intr83_stub>:
c002244e:	55                   	push   %ebp
c002244f:	6a 00                	push   $0x0
c0022451:	68 83 00 00 00       	push   $0x83
c0022456:	e9 98 fa ff ff       	jmp    c0021ef3 <intr_entry>

c002245b <intr84_stub>:
STUB(84, zero) STUB(85, zero) STUB(86, zero) STUB(87, zero)
c002245b:	55                   	push   %ebp
c002245c:	6a 00                	push   $0x0
c002245e:	68 84 00 00 00       	push   $0x84
c0022463:	e9 8b fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022468 <intr85_stub>:
c0022468:	55                   	push   %ebp
c0022469:	6a 00                	push   $0x0
c002246b:	68 85 00 00 00       	push   $0x85
c0022470:	e9 7e fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022475 <intr86_stub>:
c0022475:	55                   	push   %ebp
c0022476:	6a 00                	push   $0x0
c0022478:	68 86 00 00 00       	push   $0x86
c002247d:	e9 71 fa ff ff       	jmp    c0021ef3 <intr_entry>

c0022482 <intr87_stub>:
c0022482:	55                   	push   %ebp
c0022483:	6a 00                	push   $0x0
c0022485:	68 87 00 00 00       	push   $0x87
c002248a:	e9 64 fa ff ff       	jmp    c0021ef3 <intr_entry>

c002248f <intr88_stub>:
STUB(88, zero) STUB(89, zero) STUB(8a, zero) STUB(8b, zero)
c002248f:	55                   	push   %ebp
c0022490:	6a 00                	push   $0x0
c0022492:	68 88 00 00 00       	push   $0x88
c0022497:	e9 57 fa ff ff       	jmp    c0021ef3 <intr_entry>

c002249c <intr89_stub>:
c002249c:	55                   	push   %ebp
c002249d:	6a 00                	push   $0x0
c002249f:	68 89 00 00 00       	push   $0x89
c00224a4:	e9 4a fa ff ff       	jmp    c0021ef3 <intr_entry>

c00224a9 <intr8a_stub>:
c00224a9:	55                   	push   %ebp
c00224aa:	6a 00                	push   $0x0
c00224ac:	68 8a 00 00 00       	push   $0x8a
c00224b1:	e9 3d fa ff ff       	jmp    c0021ef3 <intr_entry>

c00224b6 <intr8b_stub>:
c00224b6:	55                   	push   %ebp
c00224b7:	6a 00                	push   $0x0
c00224b9:	68 8b 00 00 00       	push   $0x8b
c00224be:	e9 30 fa ff ff       	jmp    c0021ef3 <intr_entry>

c00224c3 <intr8c_stub>:
STUB(8c, zero) STUB(8d, zero) STUB(8e, zero) STUB(8f, zero)
c00224c3:	55                   	push   %ebp
c00224c4:	6a 00                	push   $0x0
c00224c6:	68 8c 00 00 00       	push   $0x8c
c00224cb:	e9 23 fa ff ff       	jmp    c0021ef3 <intr_entry>

c00224d0 <intr8d_stub>:
c00224d0:	55                   	push   %ebp
c00224d1:	6a 00                	push   $0x0
c00224d3:	68 8d 00 00 00       	push   $0x8d
c00224d8:	e9 16 fa ff ff       	jmp    c0021ef3 <intr_entry>

c00224dd <intr8e_stub>:
c00224dd:	55                   	push   %ebp
c00224de:	6a 00                	push   $0x0
c00224e0:	68 8e 00 00 00       	push   $0x8e
c00224e5:	e9 09 fa ff ff       	jmp    c0021ef3 <intr_entry>

c00224ea <intr8f_stub>:
c00224ea:	55                   	push   %ebp
c00224eb:	6a 00                	push   $0x0
c00224ed:	68 8f 00 00 00       	push   $0x8f
c00224f2:	e9 fc f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00224f7 <intr90_stub>:

STUB(90, zero) STUB(91, zero) STUB(92, zero) STUB(93, zero)
c00224f7:	55                   	push   %ebp
c00224f8:	6a 00                	push   $0x0
c00224fa:	68 90 00 00 00       	push   $0x90
c00224ff:	e9 ef f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022504 <intr91_stub>:
c0022504:	55                   	push   %ebp
c0022505:	6a 00                	push   $0x0
c0022507:	68 91 00 00 00       	push   $0x91
c002250c:	e9 e2 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022511 <intr92_stub>:
c0022511:	55                   	push   %ebp
c0022512:	6a 00                	push   $0x0
c0022514:	68 92 00 00 00       	push   $0x92
c0022519:	e9 d5 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c002251e <intr93_stub>:
c002251e:	55                   	push   %ebp
c002251f:	6a 00                	push   $0x0
c0022521:	68 93 00 00 00       	push   $0x93
c0022526:	e9 c8 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c002252b <intr94_stub>:
STUB(94, zero) STUB(95, zero) STUB(96, zero) STUB(97, zero)
c002252b:	55                   	push   %ebp
c002252c:	6a 00                	push   $0x0
c002252e:	68 94 00 00 00       	push   $0x94
c0022533:	e9 bb f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022538 <intr95_stub>:
c0022538:	55                   	push   %ebp
c0022539:	6a 00                	push   $0x0
c002253b:	68 95 00 00 00       	push   $0x95
c0022540:	e9 ae f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022545 <intr96_stub>:
c0022545:	55                   	push   %ebp
c0022546:	6a 00                	push   $0x0
c0022548:	68 96 00 00 00       	push   $0x96
c002254d:	e9 a1 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022552 <intr97_stub>:
c0022552:	55                   	push   %ebp
c0022553:	6a 00                	push   $0x0
c0022555:	68 97 00 00 00       	push   $0x97
c002255a:	e9 94 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c002255f <intr98_stub>:
STUB(98, zero) STUB(99, zero) STUB(9a, zero) STUB(9b, zero)
c002255f:	55                   	push   %ebp
c0022560:	6a 00                	push   $0x0
c0022562:	68 98 00 00 00       	push   $0x98
c0022567:	e9 87 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c002256c <intr99_stub>:
c002256c:	55                   	push   %ebp
c002256d:	6a 00                	push   $0x0
c002256f:	68 99 00 00 00       	push   $0x99
c0022574:	e9 7a f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022579 <intr9a_stub>:
c0022579:	55                   	push   %ebp
c002257a:	6a 00                	push   $0x0
c002257c:	68 9a 00 00 00       	push   $0x9a
c0022581:	e9 6d f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022586 <intr9b_stub>:
c0022586:	55                   	push   %ebp
c0022587:	6a 00                	push   $0x0
c0022589:	68 9b 00 00 00       	push   $0x9b
c002258e:	e9 60 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c0022593 <intr9c_stub>:
STUB(9c, zero) STUB(9d, zero) STUB(9e, zero) STUB(9f, zero)
c0022593:	55                   	push   %ebp
c0022594:	6a 00                	push   $0x0
c0022596:	68 9c 00 00 00       	push   $0x9c
c002259b:	e9 53 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00225a0 <intr9d_stub>:
c00225a0:	55                   	push   %ebp
c00225a1:	6a 00                	push   $0x0
c00225a3:	68 9d 00 00 00       	push   $0x9d
c00225a8:	e9 46 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00225ad <intr9e_stub>:
c00225ad:	55                   	push   %ebp
c00225ae:	6a 00                	push   $0x0
c00225b0:	68 9e 00 00 00       	push   $0x9e
c00225b5:	e9 39 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00225ba <intr9f_stub>:
c00225ba:	55                   	push   %ebp
c00225bb:	6a 00                	push   $0x0
c00225bd:	68 9f 00 00 00       	push   $0x9f
c00225c2:	e9 2c f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00225c7 <intra0_stub>:

STUB(a0, zero) STUB(a1, zero) STUB(a2, zero) STUB(a3, zero)
c00225c7:	55                   	push   %ebp
c00225c8:	6a 00                	push   $0x0
c00225ca:	68 a0 00 00 00       	push   $0xa0
c00225cf:	e9 1f f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00225d4 <intra1_stub>:
c00225d4:	55                   	push   %ebp
c00225d5:	6a 00                	push   $0x0
c00225d7:	68 a1 00 00 00       	push   $0xa1
c00225dc:	e9 12 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00225e1 <intra2_stub>:
c00225e1:	55                   	push   %ebp
c00225e2:	6a 00                	push   $0x0
c00225e4:	68 a2 00 00 00       	push   $0xa2
c00225e9:	e9 05 f9 ff ff       	jmp    c0021ef3 <intr_entry>

c00225ee <intra3_stub>:
c00225ee:	55                   	push   %ebp
c00225ef:	6a 00                	push   $0x0
c00225f1:	68 a3 00 00 00       	push   $0xa3
c00225f6:	e9 f8 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00225fb <intra4_stub>:
STUB(a4, zero) STUB(a5, zero) STUB(a6, zero) STUB(a7, zero)
c00225fb:	55                   	push   %ebp
c00225fc:	6a 00                	push   $0x0
c00225fe:	68 a4 00 00 00       	push   $0xa4
c0022603:	e9 eb f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022608 <intra5_stub>:
c0022608:	55                   	push   %ebp
c0022609:	6a 00                	push   $0x0
c002260b:	68 a5 00 00 00       	push   $0xa5
c0022610:	e9 de f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022615 <intra6_stub>:
c0022615:	55                   	push   %ebp
c0022616:	6a 00                	push   $0x0
c0022618:	68 a6 00 00 00       	push   $0xa6
c002261d:	e9 d1 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022622 <intra7_stub>:
c0022622:	55                   	push   %ebp
c0022623:	6a 00                	push   $0x0
c0022625:	68 a7 00 00 00       	push   $0xa7
c002262a:	e9 c4 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c002262f <intra8_stub>:
STUB(a8, zero) STUB(a9, zero) STUB(aa, zero) STUB(ab, zero)
c002262f:	55                   	push   %ebp
c0022630:	6a 00                	push   $0x0
c0022632:	68 a8 00 00 00       	push   $0xa8
c0022637:	e9 b7 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c002263c <intra9_stub>:
c002263c:	55                   	push   %ebp
c002263d:	6a 00                	push   $0x0
c002263f:	68 a9 00 00 00       	push   $0xa9
c0022644:	e9 aa f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022649 <intraa_stub>:
c0022649:	55                   	push   %ebp
c002264a:	6a 00                	push   $0x0
c002264c:	68 aa 00 00 00       	push   $0xaa
c0022651:	e9 9d f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022656 <intrab_stub>:
c0022656:	55                   	push   %ebp
c0022657:	6a 00                	push   $0x0
c0022659:	68 ab 00 00 00       	push   $0xab
c002265e:	e9 90 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022663 <intrac_stub>:
STUB(ac, zero) STUB(ad, zero) STUB(ae, zero) STUB(af, zero)
c0022663:	55                   	push   %ebp
c0022664:	6a 00                	push   $0x0
c0022666:	68 ac 00 00 00       	push   $0xac
c002266b:	e9 83 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022670 <intrad_stub>:
c0022670:	55                   	push   %ebp
c0022671:	6a 00                	push   $0x0
c0022673:	68 ad 00 00 00       	push   $0xad
c0022678:	e9 76 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c002267d <intrae_stub>:
c002267d:	55                   	push   %ebp
c002267e:	6a 00                	push   $0x0
c0022680:	68 ae 00 00 00       	push   $0xae
c0022685:	e9 69 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c002268a <intraf_stub>:
c002268a:	55                   	push   %ebp
c002268b:	6a 00                	push   $0x0
c002268d:	68 af 00 00 00       	push   $0xaf
c0022692:	e9 5c f8 ff ff       	jmp    c0021ef3 <intr_entry>

c0022697 <intrb0_stub>:

STUB(b0, zero) STUB(b1, zero) STUB(b2, zero) STUB(b3, zero)
c0022697:	55                   	push   %ebp
c0022698:	6a 00                	push   $0x0
c002269a:	68 b0 00 00 00       	push   $0xb0
c002269f:	e9 4f f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00226a4 <intrb1_stub>:
c00226a4:	55                   	push   %ebp
c00226a5:	6a 00                	push   $0x0
c00226a7:	68 b1 00 00 00       	push   $0xb1
c00226ac:	e9 42 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00226b1 <intrb2_stub>:
c00226b1:	55                   	push   %ebp
c00226b2:	6a 00                	push   $0x0
c00226b4:	68 b2 00 00 00       	push   $0xb2
c00226b9:	e9 35 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00226be <intrb3_stub>:
c00226be:	55                   	push   %ebp
c00226bf:	6a 00                	push   $0x0
c00226c1:	68 b3 00 00 00       	push   $0xb3
c00226c6:	e9 28 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00226cb <intrb4_stub>:
STUB(b4, zero) STUB(b5, zero) STUB(b6, zero) STUB(b7, zero)
c00226cb:	55                   	push   %ebp
c00226cc:	6a 00                	push   $0x0
c00226ce:	68 b4 00 00 00       	push   $0xb4
c00226d3:	e9 1b f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00226d8 <intrb5_stub>:
c00226d8:	55                   	push   %ebp
c00226d9:	6a 00                	push   $0x0
c00226db:	68 b5 00 00 00       	push   $0xb5
c00226e0:	e9 0e f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00226e5 <intrb6_stub>:
c00226e5:	55                   	push   %ebp
c00226e6:	6a 00                	push   $0x0
c00226e8:	68 b6 00 00 00       	push   $0xb6
c00226ed:	e9 01 f8 ff ff       	jmp    c0021ef3 <intr_entry>

c00226f2 <intrb7_stub>:
c00226f2:	55                   	push   %ebp
c00226f3:	6a 00                	push   $0x0
c00226f5:	68 b7 00 00 00       	push   $0xb7
c00226fa:	e9 f4 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c00226ff <intrb8_stub>:
STUB(b8, zero) STUB(b9, zero) STUB(ba, zero) STUB(bb, zero)
c00226ff:	55                   	push   %ebp
c0022700:	6a 00                	push   $0x0
c0022702:	68 b8 00 00 00       	push   $0xb8
c0022707:	e9 e7 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c002270c <intrb9_stub>:
c002270c:	55                   	push   %ebp
c002270d:	6a 00                	push   $0x0
c002270f:	68 b9 00 00 00       	push   $0xb9
c0022714:	e9 da f7 ff ff       	jmp    c0021ef3 <intr_entry>

c0022719 <intrba_stub>:
c0022719:	55                   	push   %ebp
c002271a:	6a 00                	push   $0x0
c002271c:	68 ba 00 00 00       	push   $0xba
c0022721:	e9 cd f7 ff ff       	jmp    c0021ef3 <intr_entry>

c0022726 <intrbb_stub>:
c0022726:	55                   	push   %ebp
c0022727:	6a 00                	push   $0x0
c0022729:	68 bb 00 00 00       	push   $0xbb
c002272e:	e9 c0 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c0022733 <intrbc_stub>:
STUB(bc, zero) STUB(bd, zero) STUB(be, zero) STUB(bf, zero)
c0022733:	55                   	push   %ebp
c0022734:	6a 00                	push   $0x0
c0022736:	68 bc 00 00 00       	push   $0xbc
c002273b:	e9 b3 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c0022740 <intrbd_stub>:
c0022740:	55                   	push   %ebp
c0022741:	6a 00                	push   $0x0
c0022743:	68 bd 00 00 00       	push   $0xbd
c0022748:	e9 a6 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c002274d <intrbe_stub>:
c002274d:	55                   	push   %ebp
c002274e:	6a 00                	push   $0x0
c0022750:	68 be 00 00 00       	push   $0xbe
c0022755:	e9 99 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c002275a <intrbf_stub>:
c002275a:	55                   	push   %ebp
c002275b:	6a 00                	push   $0x0
c002275d:	68 bf 00 00 00       	push   $0xbf
c0022762:	e9 8c f7 ff ff       	jmp    c0021ef3 <intr_entry>

c0022767 <intrc0_stub>:

STUB(c0, zero) STUB(c1, zero) STUB(c2, zero) STUB(c3, zero)
c0022767:	55                   	push   %ebp
c0022768:	6a 00                	push   $0x0
c002276a:	68 c0 00 00 00       	push   $0xc0
c002276f:	e9 7f f7 ff ff       	jmp    c0021ef3 <intr_entry>

c0022774 <intrc1_stub>:
c0022774:	55                   	push   %ebp
c0022775:	6a 00                	push   $0x0
c0022777:	68 c1 00 00 00       	push   $0xc1
c002277c:	e9 72 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c0022781 <intrc2_stub>:
c0022781:	55                   	push   %ebp
c0022782:	6a 00                	push   $0x0
c0022784:	68 c2 00 00 00       	push   $0xc2
c0022789:	e9 65 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c002278e <intrc3_stub>:
c002278e:	55                   	push   %ebp
c002278f:	6a 00                	push   $0x0
c0022791:	68 c3 00 00 00       	push   $0xc3
c0022796:	e9 58 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c002279b <intrc4_stub>:
STUB(c4, zero) STUB(c5, zero) STUB(c6, zero) STUB(c7, zero)
c002279b:	55                   	push   %ebp
c002279c:	6a 00                	push   $0x0
c002279e:	68 c4 00 00 00       	push   $0xc4
c00227a3:	e9 4b f7 ff ff       	jmp    c0021ef3 <intr_entry>

c00227a8 <intrc5_stub>:
c00227a8:	55                   	push   %ebp
c00227a9:	6a 00                	push   $0x0
c00227ab:	68 c5 00 00 00       	push   $0xc5
c00227b0:	e9 3e f7 ff ff       	jmp    c0021ef3 <intr_entry>

c00227b5 <intrc6_stub>:
c00227b5:	55                   	push   %ebp
c00227b6:	6a 00                	push   $0x0
c00227b8:	68 c6 00 00 00       	push   $0xc6
c00227bd:	e9 31 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c00227c2 <intrc7_stub>:
c00227c2:	55                   	push   %ebp
c00227c3:	6a 00                	push   $0x0
c00227c5:	68 c7 00 00 00       	push   $0xc7
c00227ca:	e9 24 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c00227cf <intrc8_stub>:
STUB(c8, zero) STUB(c9, zero) STUB(ca, zero) STUB(cb, zero)
c00227cf:	55                   	push   %ebp
c00227d0:	6a 00                	push   $0x0
c00227d2:	68 c8 00 00 00       	push   $0xc8
c00227d7:	e9 17 f7 ff ff       	jmp    c0021ef3 <intr_entry>

c00227dc <intrc9_stub>:
c00227dc:	55                   	push   %ebp
c00227dd:	6a 00                	push   $0x0
c00227df:	68 c9 00 00 00       	push   $0xc9
c00227e4:	e9 0a f7 ff ff       	jmp    c0021ef3 <intr_entry>

c00227e9 <intrca_stub>:
c00227e9:	55                   	push   %ebp
c00227ea:	6a 00                	push   $0x0
c00227ec:	68 ca 00 00 00       	push   $0xca
c00227f1:	e9 fd f6 ff ff       	jmp    c0021ef3 <intr_entry>

c00227f6 <intrcb_stub>:
c00227f6:	55                   	push   %ebp
c00227f7:	6a 00                	push   $0x0
c00227f9:	68 cb 00 00 00       	push   $0xcb
c00227fe:	e9 f0 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022803 <intrcc_stub>:
STUB(cc, zero) STUB(cd, zero) STUB(ce, zero) STUB(cf, zero)
c0022803:	55                   	push   %ebp
c0022804:	6a 00                	push   $0x0
c0022806:	68 cc 00 00 00       	push   $0xcc
c002280b:	e9 e3 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022810 <intrcd_stub>:
c0022810:	55                   	push   %ebp
c0022811:	6a 00                	push   $0x0
c0022813:	68 cd 00 00 00       	push   $0xcd
c0022818:	e9 d6 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c002281d <intrce_stub>:
c002281d:	55                   	push   %ebp
c002281e:	6a 00                	push   $0x0
c0022820:	68 ce 00 00 00       	push   $0xce
c0022825:	e9 c9 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c002282a <intrcf_stub>:
c002282a:	55                   	push   %ebp
c002282b:	6a 00                	push   $0x0
c002282d:	68 cf 00 00 00       	push   $0xcf
c0022832:	e9 bc f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022837 <intrd0_stub>:

STUB(d0, zero) STUB(d1, zero) STUB(d2, zero) STUB(d3, zero)
c0022837:	55                   	push   %ebp
c0022838:	6a 00                	push   $0x0
c002283a:	68 d0 00 00 00       	push   $0xd0
c002283f:	e9 af f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022844 <intrd1_stub>:
c0022844:	55                   	push   %ebp
c0022845:	6a 00                	push   $0x0
c0022847:	68 d1 00 00 00       	push   $0xd1
c002284c:	e9 a2 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022851 <intrd2_stub>:
c0022851:	55                   	push   %ebp
c0022852:	6a 00                	push   $0x0
c0022854:	68 d2 00 00 00       	push   $0xd2
c0022859:	e9 95 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c002285e <intrd3_stub>:
c002285e:	55                   	push   %ebp
c002285f:	6a 00                	push   $0x0
c0022861:	68 d3 00 00 00       	push   $0xd3
c0022866:	e9 88 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c002286b <intrd4_stub>:
STUB(d4, zero) STUB(d5, zero) STUB(d6, zero) STUB(d7, zero)
c002286b:	55                   	push   %ebp
c002286c:	6a 00                	push   $0x0
c002286e:	68 d4 00 00 00       	push   $0xd4
c0022873:	e9 7b f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022878 <intrd5_stub>:
c0022878:	55                   	push   %ebp
c0022879:	6a 00                	push   $0x0
c002287b:	68 d5 00 00 00       	push   $0xd5
c0022880:	e9 6e f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022885 <intrd6_stub>:
c0022885:	55                   	push   %ebp
c0022886:	6a 00                	push   $0x0
c0022888:	68 d6 00 00 00       	push   $0xd6
c002288d:	e9 61 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c0022892 <intrd7_stub>:
c0022892:	55                   	push   %ebp
c0022893:	6a 00                	push   $0x0
c0022895:	68 d7 00 00 00       	push   $0xd7
c002289a:	e9 54 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c002289f <intrd8_stub>:
STUB(d8, zero) STUB(d9, zero) STUB(da, zero) STUB(db, zero)
c002289f:	55                   	push   %ebp
c00228a0:	6a 00                	push   $0x0
c00228a2:	68 d8 00 00 00       	push   $0xd8
c00228a7:	e9 47 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c00228ac <intrd9_stub>:
c00228ac:	55                   	push   %ebp
c00228ad:	6a 00                	push   $0x0
c00228af:	68 d9 00 00 00       	push   $0xd9
c00228b4:	e9 3a f6 ff ff       	jmp    c0021ef3 <intr_entry>

c00228b9 <intrda_stub>:
c00228b9:	55                   	push   %ebp
c00228ba:	6a 00                	push   $0x0
c00228bc:	68 da 00 00 00       	push   $0xda
c00228c1:	e9 2d f6 ff ff       	jmp    c0021ef3 <intr_entry>

c00228c6 <intrdb_stub>:
c00228c6:	55                   	push   %ebp
c00228c7:	6a 00                	push   $0x0
c00228c9:	68 db 00 00 00       	push   $0xdb
c00228ce:	e9 20 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c00228d3 <intrdc_stub>:
STUB(dc, zero) STUB(dd, zero) STUB(de, zero) STUB(df, zero)
c00228d3:	55                   	push   %ebp
c00228d4:	6a 00                	push   $0x0
c00228d6:	68 dc 00 00 00       	push   $0xdc
c00228db:	e9 13 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c00228e0 <intrdd_stub>:
c00228e0:	55                   	push   %ebp
c00228e1:	6a 00                	push   $0x0
c00228e3:	68 dd 00 00 00       	push   $0xdd
c00228e8:	e9 06 f6 ff ff       	jmp    c0021ef3 <intr_entry>

c00228ed <intrde_stub>:
c00228ed:	55                   	push   %ebp
c00228ee:	6a 00                	push   $0x0
c00228f0:	68 de 00 00 00       	push   $0xde
c00228f5:	e9 f9 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00228fa <intrdf_stub>:
c00228fa:	55                   	push   %ebp
c00228fb:	6a 00                	push   $0x0
c00228fd:	68 df 00 00 00       	push   $0xdf
c0022902:	e9 ec f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022907 <intre0_stub>:

STUB(e0, zero) STUB(e1, zero) STUB(e2, zero) STUB(e3, zero)
c0022907:	55                   	push   %ebp
c0022908:	6a 00                	push   $0x0
c002290a:	68 e0 00 00 00       	push   $0xe0
c002290f:	e9 df f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022914 <intre1_stub>:
c0022914:	55                   	push   %ebp
c0022915:	6a 00                	push   $0x0
c0022917:	68 e1 00 00 00       	push   $0xe1
c002291c:	e9 d2 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022921 <intre2_stub>:
c0022921:	55                   	push   %ebp
c0022922:	6a 00                	push   $0x0
c0022924:	68 e2 00 00 00       	push   $0xe2
c0022929:	e9 c5 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c002292e <intre3_stub>:
c002292e:	55                   	push   %ebp
c002292f:	6a 00                	push   $0x0
c0022931:	68 e3 00 00 00       	push   $0xe3
c0022936:	e9 b8 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c002293b <intre4_stub>:
STUB(e4, zero) STUB(e5, zero) STUB(e6, zero) STUB(e7, zero)
c002293b:	55                   	push   %ebp
c002293c:	6a 00                	push   $0x0
c002293e:	68 e4 00 00 00       	push   $0xe4
c0022943:	e9 ab f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022948 <intre5_stub>:
c0022948:	55                   	push   %ebp
c0022949:	6a 00                	push   $0x0
c002294b:	68 e5 00 00 00       	push   $0xe5
c0022950:	e9 9e f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022955 <intre6_stub>:
c0022955:	55                   	push   %ebp
c0022956:	6a 00                	push   $0x0
c0022958:	68 e6 00 00 00       	push   $0xe6
c002295d:	e9 91 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022962 <intre7_stub>:
c0022962:	55                   	push   %ebp
c0022963:	6a 00                	push   $0x0
c0022965:	68 e7 00 00 00       	push   $0xe7
c002296a:	e9 84 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c002296f <intre8_stub>:
STUB(e8, zero) STUB(e9, zero) STUB(ea, zero) STUB(eb, zero)
c002296f:	55                   	push   %ebp
c0022970:	6a 00                	push   $0x0
c0022972:	68 e8 00 00 00       	push   $0xe8
c0022977:	e9 77 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c002297c <intre9_stub>:
c002297c:	55                   	push   %ebp
c002297d:	6a 00                	push   $0x0
c002297f:	68 e9 00 00 00       	push   $0xe9
c0022984:	e9 6a f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022989 <intrea_stub>:
c0022989:	55                   	push   %ebp
c002298a:	6a 00                	push   $0x0
c002298c:	68 ea 00 00 00       	push   $0xea
c0022991:	e9 5d f5 ff ff       	jmp    c0021ef3 <intr_entry>

c0022996 <intreb_stub>:
c0022996:	55                   	push   %ebp
c0022997:	6a 00                	push   $0x0
c0022999:	68 eb 00 00 00       	push   $0xeb
c002299e:	e9 50 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00229a3 <intrec_stub>:
STUB(ec, zero) STUB(ed, zero) STUB(ee, zero) STUB(ef, zero)
c00229a3:	55                   	push   %ebp
c00229a4:	6a 00                	push   $0x0
c00229a6:	68 ec 00 00 00       	push   $0xec
c00229ab:	e9 43 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00229b0 <intred_stub>:
c00229b0:	55                   	push   %ebp
c00229b1:	6a 00                	push   $0x0
c00229b3:	68 ed 00 00 00       	push   $0xed
c00229b8:	e9 36 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00229bd <intree_stub>:
c00229bd:	55                   	push   %ebp
c00229be:	6a 00                	push   $0x0
c00229c0:	68 ee 00 00 00       	push   $0xee
c00229c5:	e9 29 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00229ca <intref_stub>:
c00229ca:	55                   	push   %ebp
c00229cb:	6a 00                	push   $0x0
c00229cd:	68 ef 00 00 00       	push   $0xef
c00229d2:	e9 1c f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00229d7 <intrf0_stub>:

STUB(f0, zero) STUB(f1, zero) STUB(f2, zero) STUB(f3, zero)
c00229d7:	55                   	push   %ebp
c00229d8:	6a 00                	push   $0x0
c00229da:	68 f0 00 00 00       	push   $0xf0
c00229df:	e9 0f f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00229e4 <intrf1_stub>:
c00229e4:	55                   	push   %ebp
c00229e5:	6a 00                	push   $0x0
c00229e7:	68 f1 00 00 00       	push   $0xf1
c00229ec:	e9 02 f5 ff ff       	jmp    c0021ef3 <intr_entry>

c00229f1 <intrf2_stub>:
c00229f1:	55                   	push   %ebp
c00229f2:	6a 00                	push   $0x0
c00229f4:	68 f2 00 00 00       	push   $0xf2
c00229f9:	e9 f5 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c00229fe <intrf3_stub>:
c00229fe:	55                   	push   %ebp
c00229ff:	6a 00                	push   $0x0
c0022a01:	68 f3 00 00 00       	push   $0xf3
c0022a06:	e9 e8 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a0b <intrf4_stub>:
STUB(f4, zero) STUB(f5, zero) STUB(f6, zero) STUB(f7, zero)
c0022a0b:	55                   	push   %ebp
c0022a0c:	6a 00                	push   $0x0
c0022a0e:	68 f4 00 00 00       	push   $0xf4
c0022a13:	e9 db f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a18 <intrf5_stub>:
c0022a18:	55                   	push   %ebp
c0022a19:	6a 00                	push   $0x0
c0022a1b:	68 f5 00 00 00       	push   $0xf5
c0022a20:	e9 ce f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a25 <intrf6_stub>:
c0022a25:	55                   	push   %ebp
c0022a26:	6a 00                	push   $0x0
c0022a28:	68 f6 00 00 00       	push   $0xf6
c0022a2d:	e9 c1 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a32 <intrf7_stub>:
c0022a32:	55                   	push   %ebp
c0022a33:	6a 00                	push   $0x0
c0022a35:	68 f7 00 00 00       	push   $0xf7
c0022a3a:	e9 b4 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a3f <intrf8_stub>:
STUB(f8, zero) STUB(f9, zero) STUB(fa, zero) STUB(fb, zero)
c0022a3f:	55                   	push   %ebp
c0022a40:	6a 00                	push   $0x0
c0022a42:	68 f8 00 00 00       	push   $0xf8
c0022a47:	e9 a7 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a4c <intrf9_stub>:
c0022a4c:	55                   	push   %ebp
c0022a4d:	6a 00                	push   $0x0
c0022a4f:	68 f9 00 00 00       	push   $0xf9
c0022a54:	e9 9a f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a59 <intrfa_stub>:
c0022a59:	55                   	push   %ebp
c0022a5a:	6a 00                	push   $0x0
c0022a5c:	68 fa 00 00 00       	push   $0xfa
c0022a61:	e9 8d f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a66 <intrfb_stub>:
c0022a66:	55                   	push   %ebp
c0022a67:	6a 00                	push   $0x0
c0022a69:	68 fb 00 00 00       	push   $0xfb
c0022a6e:	e9 80 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a73 <intrfc_stub>:
STUB(fc, zero) STUB(fd, zero) STUB(fe, zero) STUB(ff, zero)
c0022a73:	55                   	push   %ebp
c0022a74:	6a 00                	push   $0x0
c0022a76:	68 fc 00 00 00       	push   $0xfc
c0022a7b:	e9 73 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a80 <intrfd_stub>:
c0022a80:	55                   	push   %ebp
c0022a81:	6a 00                	push   $0x0
c0022a83:	68 fd 00 00 00       	push   $0xfd
c0022a88:	e9 66 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a8d <intrfe_stub>:
c0022a8d:	55                   	push   %ebp
c0022a8e:	6a 00                	push   $0x0
c0022a90:	68 fe 00 00 00       	push   $0xfe
c0022a95:	e9 59 f4 ff ff       	jmp    c0021ef3 <intr_entry>

c0022a9a <intrff_stub>:
c0022a9a:	55                   	push   %ebp
c0022a9b:	6a 00                	push   $0x0
c0022a9d:	68 ff 00 00 00       	push   $0xff
c0022aa2:	e9 4c f4 ff ff       	jmp    c0021ef3 <intr_entry>
c0022aa7:	90                   	nop
c0022aa8:	90                   	nop
c0022aa9:	90                   	nop
c0022aaa:	90                   	nop
c0022aab:	90                   	nop
c0022aac:	90                   	nop
c0022aad:	90                   	nop
c0022aae:	90                   	nop
c0022aaf:	90                   	nop

c0022ab0 <threadPrioCompare>:
static bool threadPrioCompare(const struct list_elem *t1,
                             const struct list_elem *t2, void *aux UNUSED)
{ 
  const struct thread *tPointer1 = list_entry (t1, struct thread, elem);
  const struct thread *tPointer2 = list_entry (t2, struct thread, elem);
  if(tPointer1->priority < tPointer2->priority){
c0022ab0:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022ab4:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022ab8:	8b 40 f4             	mov    -0xc(%eax),%eax
c0022abb:	39 42 f4             	cmp    %eax,-0xc(%edx)
c0022abe:	0f 9c c0             	setl   %al
    return true;
  }
  else{
    return false;
  }
}
c0022ac1:	c3                   	ret    

c0022ac2 <lockPrioCompare>:
static bool lockPrioCompare(const struct list_elem *l1,
                             const struct list_elem *l2, void *aux UNUSED)
{
  const struct lock *lPointer1 = list_entry (l1, struct lock, elem);
  const struct lock *lPointer2 = list_entry (l2, struct lock, elem);
  if(lPointer1->max_priority > lPointer2->max_priority) {
c0022ac2:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022ac6:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022aca:	8b 40 08             	mov    0x8(%eax),%eax
c0022acd:	39 42 08             	cmp    %eax,0x8(%edx)
c0022ad0:	0f 9f c0             	setg   %al
    return true;
  }
  else {
    return false;
  }
}
c0022ad3:	c3                   	ret    

c0022ad4 <semaPrioCompare>:
static bool semaPrioCompare(const struct list_elem *s1,
                             const struct list_elem *s2, void *aux UNUSED)
{
  const struct semaphore_elem *sPointer1 = list_entry (s1, struct semaphore_elem, elem);
  const struct semaphore_elem *sPointer2 = list_entry (s2, struct semaphore_elem, elem);
  if(sPointer1->priority < sPointer2->priority){
c0022ad4:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022ad8:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022adc:	8b 40 1c             	mov    0x1c(%eax),%eax
c0022adf:	39 42 1c             	cmp    %eax,0x1c(%edx)
c0022ae2:	0f 9c c0             	setl   %al
    return true;
  }
  else{
    return false;
  }
}
c0022ae5:	c3                   	ret    

c0022ae6 <sema_init>:
{
c0022ae6:	83 ec 2c             	sub    $0x2c,%esp
c0022ae9:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (sema != NULL);
c0022aed:	85 c0                	test   %eax,%eax
c0022aef:	75 2c                	jne    c0022b1d <sema_init+0x37>
c0022af1:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c0022af8:	c0 
c0022af9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022b00:	c0 
c0022b01:	c7 44 24 08 60 d2 02 	movl   $0xc002d260,0x8(%esp)
c0022b08:	c0 
c0022b09:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c0022b10:	00 
c0022b11:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022b18:	e8 66 5e 00 00       	call   c0028983 <debug_panic>
  sema->value = value;
c0022b1d:	8b 54 24 34          	mov    0x34(%esp),%edx
c0022b21:	89 10                	mov    %edx,(%eax)
  list_init (&sema->waiters);
c0022b23:	83 c0 04             	add    $0x4,%eax
c0022b26:	89 04 24             	mov    %eax,(%esp)
c0022b29:	e8 22 5f 00 00       	call   c0028a50 <list_init>
}
c0022b2e:	83 c4 2c             	add    $0x2c,%esp
c0022b31:	c3                   	ret    

c0022b32 <sema_down>:
{
c0022b32:	57                   	push   %edi
c0022b33:	56                   	push   %esi
c0022b34:	53                   	push   %ebx
c0022b35:	83 ec 20             	sub    $0x20,%esp
c0022b38:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c0022b3c:	85 db                	test   %ebx,%ebx
c0022b3e:	75 2c                	jne    c0022b6c <sema_down+0x3a>
c0022b40:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c0022b47:	c0 
c0022b48:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022b4f:	c0 
c0022b50:	c7 44 24 08 56 d2 02 	movl   $0xc002d256,0x8(%esp)
c0022b57:	c0 
c0022b58:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0022b5f:	00 
c0022b60:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022b67:	e8 17 5e 00 00       	call   c0028983 <debug_panic>
  ASSERT (!intr_context ());
c0022b6c:	e8 b0 f0 ff ff       	call   c0021c21 <intr_context>
c0022b71:	84 c0                	test   %al,%al
c0022b73:	74 2c                	je     c0022ba1 <sema_down+0x6f>
c0022b75:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0022b7c:	c0 
c0022b7d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022b84:	c0 
c0022b85:	c7 44 24 08 56 d2 02 	movl   $0xc002d256,0x8(%esp)
c0022b8c:	c0 
c0022b8d:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c0022b94:	00 
c0022b95:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022b9c:	e8 e2 5d 00 00       	call   c0028983 <debug_panic>
  old_level = intr_disable ();
c0022ba1:	e8 19 ee ff ff       	call   c00219bf <intr_disable>
c0022ba6:	89 c7                	mov    %eax,%edi
  while (sema->value == 0) 
c0022ba8:	8b 13                	mov    (%ebx),%edx
c0022baa:	85 d2                	test   %edx,%edx
c0022bac:	75 22                	jne    c0022bd0 <sema_down+0x9e>
      list_push_back (&sema->waiters, &thread_current ()->elem);
c0022bae:	8d 73 04             	lea    0x4(%ebx),%esi
c0022bb1:	e8 23 e2 ff ff       	call   c0020dd9 <thread_current>
c0022bb6:	83 c0 28             	add    $0x28,%eax
c0022bb9:	89 44 24 04          	mov    %eax,0x4(%esp)
c0022bbd:	89 34 24             	mov    %esi,(%esp)
c0022bc0:	e8 0c 64 00 00       	call   c0028fd1 <list_push_back>
      thread_block ();
c0022bc5:	e8 45 e7 ff ff       	call   c002130f <thread_block>
  while (sema->value == 0) 
c0022bca:	8b 13                	mov    (%ebx),%edx
c0022bcc:	85 d2                	test   %edx,%edx
c0022bce:	74 e1                	je     c0022bb1 <sema_down+0x7f>
  sema->value--;
c0022bd0:	83 ea 01             	sub    $0x1,%edx
c0022bd3:	89 13                	mov    %edx,(%ebx)
  intr_set_level (old_level);
c0022bd5:	89 3c 24             	mov    %edi,(%esp)
c0022bd8:	e8 e9 ed ff ff       	call   c00219c6 <intr_set_level>
}
c0022bdd:	83 c4 20             	add    $0x20,%esp
c0022be0:	5b                   	pop    %ebx
c0022be1:	5e                   	pop    %esi
c0022be2:	5f                   	pop    %edi
c0022be3:	c3                   	ret    

c0022be4 <sema_try_down>:
{
c0022be4:	56                   	push   %esi
c0022be5:	53                   	push   %ebx
c0022be6:	83 ec 24             	sub    $0x24,%esp
c0022be9:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c0022bed:	85 db                	test   %ebx,%ebx
c0022bef:	75 2c                	jne    c0022c1d <sema_try_down+0x39>
c0022bf1:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c0022bf8:	c0 
c0022bf9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022c00:	c0 
c0022c01:	c7 44 24 08 48 d2 02 	movl   $0xc002d248,0x8(%esp)
c0022c08:	c0 
c0022c09:	c7 44 24 04 61 00 00 	movl   $0x61,0x4(%esp)
c0022c10:	00 
c0022c11:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022c18:	e8 66 5d 00 00       	call   c0028983 <debug_panic>
  old_level = intr_disable ();
c0022c1d:	e8 9d ed ff ff       	call   c00219bf <intr_disable>
  if (sema->value > 0) 
c0022c22:	8b 13                	mov    (%ebx),%edx
    success = false;
c0022c24:	be 00 00 00 00       	mov    $0x0,%esi
  if (sema->value > 0) 
c0022c29:	85 d2                	test   %edx,%edx
c0022c2b:	74 0a                	je     c0022c37 <sema_try_down+0x53>
      sema->value--;
c0022c2d:	83 ea 01             	sub    $0x1,%edx
c0022c30:	89 13                	mov    %edx,(%ebx)
      success = true; 
c0022c32:	be 01 00 00 00       	mov    $0x1,%esi
  intr_set_level (old_level);
c0022c37:	89 04 24             	mov    %eax,(%esp)
c0022c3a:	e8 87 ed ff ff       	call   c00219c6 <intr_set_level>
}
c0022c3f:	89 f0                	mov    %esi,%eax
c0022c41:	83 c4 24             	add    $0x24,%esp
c0022c44:	5b                   	pop    %ebx
c0022c45:	5e                   	pop    %esi
c0022c46:	c3                   	ret    

c0022c47 <sema_up>:
{
c0022c47:	55                   	push   %ebp
c0022c48:	57                   	push   %edi
c0022c49:	56                   	push   %esi
c0022c4a:	53                   	push   %ebx
c0022c4b:	83 ec 2c             	sub    $0x2c,%esp
c0022c4e:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  ASSERT (sema != NULL);
c0022c52:	85 db                	test   %ebx,%ebx
c0022c54:	75 2c                	jne    c0022c82 <sema_up+0x3b>
c0022c56:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c0022c5d:	c0 
c0022c5e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022c65:	c0 
c0022c66:	c7 44 24 08 40 d2 02 	movl   $0xc002d240,0x8(%esp)
c0022c6d:	c0 
c0022c6e:	c7 44 24 04 7c 00 00 	movl   $0x7c,0x4(%esp)
c0022c75:	00 
c0022c76:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022c7d:	e8 01 5d 00 00       	call   c0028983 <debug_panic>
  old_level = intr_disable ();
c0022c82:	e8 38 ed ff ff       	call   c00219bf <intr_disable>
c0022c87:	89 c7                	mov    %eax,%edi
  if (!list_empty (&sema->waiters)) 
c0022c89:	8d 73 04             	lea    0x4(%ebx),%esi
c0022c8c:	89 34 24             	mov    %esi,(%esp)
c0022c8f:	e8 f2 63 00 00       	call   c0029086 <list_empty>
c0022c94:	84 c0                	test   %al,%al
c0022c96:	75 55                	jne    c0022ced <sema_up+0xa6>
    max_prio_sema = list_max (&sema->waiters,threadPrioCompare,0);
c0022c98:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0022c9f:	00 
c0022ca0:	c7 44 24 04 b0 2a 02 	movl   $0xc0022ab0,0x4(%esp)
c0022ca7:	c0 
c0022ca8:	89 34 24             	mov    %esi,(%esp)
c0022cab:	e8 aa 69 00 00       	call   c002965a <list_max>
c0022cb0:	89 c6                	mov    %eax,%esi
    list_remove(max_prio_sema);
c0022cb2:	89 04 24             	mov    %eax,(%esp)
c0022cb5:	e8 3a 63 00 00       	call   c0028ff4 <list_remove>
    freed_thread = list_entry(max_prio_sema,struct thread,elem);
c0022cba:	8d 6e d8             	lea    -0x28(%esi),%ebp
    thread_unblock (freed_thread);
c0022cbd:	89 2c 24             	mov    %ebp,(%esp)
c0022cc0:	e8 39 e0 ff ff       	call   c0020cfe <thread_unblock>
  sema->value++;
c0022cc5:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022cc8:	89 3c 24             	mov    %edi,(%esp)
c0022ccb:	e8 f6 ec ff ff       	call   c00219c6 <intr_set_level>
  if(old_level == INTR_ON && freed_thread!=NULL) {
c0022cd0:	83 ff 01             	cmp    $0x1,%edi
c0022cd3:	75 23                	jne    c0022cf8 <sema_up+0xb1>
c0022cd5:	85 ed                	test   %ebp,%ebp
c0022cd7:	74 1f                	je     c0022cf8 <sema_up+0xb1>
    if(thread_current()->priority < freed_thread->priority)
c0022cd9:	e8 fb e0 ff ff       	call   c0020dd9 <thread_current>
c0022cde:	8b 56 f4             	mov    -0xc(%esi),%edx
c0022ce1:	39 50 1c             	cmp    %edx,0x1c(%eax)
c0022ce4:	7d 12                	jge    c0022cf8 <sema_up+0xb1>
      thread_yield ();
c0022ce6:	e8 9a e7 ff ff       	call   c0021485 <thread_yield>
c0022ceb:	eb 0b                	jmp    c0022cf8 <sema_up+0xb1>
  sema->value++;
c0022ced:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022cf0:	89 3c 24             	mov    %edi,(%esp)
c0022cf3:	e8 ce ec ff ff       	call   c00219c6 <intr_set_level>
}
c0022cf8:	83 c4 2c             	add    $0x2c,%esp
c0022cfb:	5b                   	pop    %ebx
c0022cfc:	5e                   	pop    %esi
c0022cfd:	5f                   	pop    %edi
c0022cfe:	5d                   	pop    %ebp
c0022cff:	c3                   	ret    

c0022d00 <sema_test_helper>:
{
c0022d00:	57                   	push   %edi
c0022d01:	56                   	push   %esi
c0022d02:	53                   	push   %ebx
c0022d03:	83 ec 10             	sub    $0x10,%esp
c0022d06:	8b 74 24 20          	mov    0x20(%esp),%esi
c0022d0a:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[1]);
c0022d0f:	8d 7e 14             	lea    0x14(%esi),%edi
      sema_down (&sema[0]);
c0022d12:	89 34 24             	mov    %esi,(%esp)
c0022d15:	e8 18 fe ff ff       	call   c0022b32 <sema_down>
      sema_up (&sema[1]);
c0022d1a:	89 3c 24             	mov    %edi,(%esp)
c0022d1d:	e8 25 ff ff ff       	call   c0022c47 <sema_up>
  for (i = 0; i < 10; i++) 
c0022d22:	83 eb 01             	sub    $0x1,%ebx
c0022d25:	75 eb                	jne    c0022d12 <sema_test_helper+0x12>
}
c0022d27:	83 c4 10             	add    $0x10,%esp
c0022d2a:	5b                   	pop    %ebx
c0022d2b:	5e                   	pop    %esi
c0022d2c:	5f                   	pop    %edi
c0022d2d:	c3                   	ret    

c0022d2e <sema_self_test>:
{
c0022d2e:	57                   	push   %edi
c0022d2f:	56                   	push   %esi
c0022d30:	53                   	push   %ebx
c0022d31:	83 ec 40             	sub    $0x40,%esp
  printf ("Testing semaphores...");
c0022d34:	c7 04 24 39 ea 02 c0 	movl   $0xc002ea39,(%esp)
c0022d3b:	e8 ee 3d 00 00       	call   c0026b2e <printf>
  sema_init (&sema[0], 0);
c0022d40:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022d47:	00 
c0022d48:	8d 5c 24 18          	lea    0x18(%esp),%ebx
c0022d4c:	89 1c 24             	mov    %ebx,(%esp)
c0022d4f:	e8 92 fd ff ff       	call   c0022ae6 <sema_init>
  sema_init (&sema[1], 0);
c0022d54:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022d5b:	00 
c0022d5c:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c0022d60:	89 04 24             	mov    %eax,(%esp)
c0022d63:	e8 7e fd ff ff       	call   c0022ae6 <sema_init>
  thread_create ("sema-test", PRI_DEFAULT, sema_test_helper, &sema);
c0022d68:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0022d6c:	c7 44 24 08 00 2d 02 	movl   $0xc0022d00,0x8(%esp)
c0022d73:	c0 
c0022d74:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c0022d7b:	00 
c0022d7c:	c7 04 24 4f ea 02 c0 	movl   $0xc002ea4f,(%esp)
c0022d83:	e8 9f e7 ff ff       	call   c0021527 <thread_create>
c0022d88:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[0]);
c0022d8d:	8d 7c 24 18          	lea    0x18(%esp),%edi
      sema_down (&sema[1]);
c0022d91:	8d 74 24 2c          	lea    0x2c(%esp),%esi
      sema_up (&sema[0]);
c0022d95:	89 3c 24             	mov    %edi,(%esp)
c0022d98:	e8 aa fe ff ff       	call   c0022c47 <sema_up>
      sema_down (&sema[1]);
c0022d9d:	89 34 24             	mov    %esi,(%esp)
c0022da0:	e8 8d fd ff ff       	call   c0022b32 <sema_down>
  for (i = 0; i < 10; i++) 
c0022da5:	83 eb 01             	sub    $0x1,%ebx
c0022da8:	75 eb                	jne    c0022d95 <sema_self_test+0x67>
  printf ("done.\n");
c0022daa:	c7 04 24 59 ea 02 c0 	movl   $0xc002ea59,(%esp)
c0022db1:	e8 f5 78 00 00       	call   c002a6ab <puts>
}
c0022db6:	83 c4 40             	add    $0x40,%esp
c0022db9:	5b                   	pop    %ebx
c0022dba:	5e                   	pop    %esi
c0022dbb:	5f                   	pop    %edi
c0022dbc:	c3                   	ret    

c0022dbd <lock_init>:
{
c0022dbd:	83 ec 2c             	sub    $0x2c,%esp
c0022dc0:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022dc4:	85 c0                	test   %eax,%eax
c0022dc6:	75 2c                	jne    c0022df4 <lock_init+0x37>
c0022dc8:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022dcf:	c0 
c0022dd0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022dd7:	c0 
c0022dd8:	c7 44 24 08 36 d2 02 	movl   $0xc002d236,0x8(%esp)
c0022ddf:	c0 
c0022de0:	c7 44 24 04 c7 00 00 	movl   $0xc7,0x4(%esp)
c0022de7:	00 
c0022de8:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022def:	e8 8f 5b 00 00       	call   c0028983 <debug_panic>
  lock->holder = NULL;
c0022df4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  sema_init (&lock->semaphore, 1);
c0022dfa:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0022e01:	00 
c0022e02:	83 c0 04             	add    $0x4,%eax
c0022e05:	89 04 24             	mov    %eax,(%esp)
c0022e08:	e8 d9 fc ff ff       	call   c0022ae6 <sema_init>
}
c0022e0d:	83 c4 2c             	add    $0x2c,%esp
c0022e10:	c3                   	ret    

c0022e11 <lock_held_by_current_thread>:
{
c0022e11:	53                   	push   %ebx
c0022e12:	83 ec 28             	sub    $0x28,%esp
c0022e15:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022e19:	85 c0                	test   %eax,%eax
c0022e1b:	75 2c                	jne    c0022e49 <lock_held_by_current_thread+0x38>
c0022e1d:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022e24:	c0 
c0022e25:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022e2c:	c0 
c0022e2d:	c7 44 24 08 ef d1 02 	movl   $0xc002d1ef,0x8(%esp)
c0022e34:	c0 
c0022e35:	c7 44 24 04 4c 01 00 	movl   $0x14c,0x4(%esp)
c0022e3c:	00 
c0022e3d:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022e44:	e8 3a 5b 00 00       	call   c0028983 <debug_panic>
  return lock->holder == thread_current ();
c0022e49:	8b 18                	mov    (%eax),%ebx
c0022e4b:	e8 89 df ff ff       	call   c0020dd9 <thread_current>
c0022e50:	39 c3                	cmp    %eax,%ebx
c0022e52:	0f 94 c0             	sete   %al
}
c0022e55:	83 c4 28             	add    $0x28,%esp
c0022e58:	5b                   	pop    %ebx
c0022e59:	c3                   	ret    

c0022e5a <lock_acquire>:
{
c0022e5a:	56                   	push   %esi
c0022e5b:	53                   	push   %ebx
c0022e5c:	83 ec 24             	sub    $0x24,%esp
c0022e5f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022e63:	85 db                	test   %ebx,%ebx
c0022e65:	75 2c                	jne    c0022e93 <lock_acquire+0x39>
c0022e67:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022e6e:	c0 
c0022e6f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022e76:	c0 
c0022e77:	c7 44 24 08 29 d2 02 	movl   $0xc002d229,0x8(%esp)
c0022e7e:	c0 
c0022e7f:	c7 44 24 04 e8 00 00 	movl   $0xe8,0x4(%esp)
c0022e86:	00 
c0022e87:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022e8e:	e8 f0 5a 00 00       	call   c0028983 <debug_panic>
  ASSERT (!intr_context ());
c0022e93:	e8 89 ed ff ff       	call   c0021c21 <intr_context>
c0022e98:	84 c0                	test   %al,%al
c0022e9a:	74 2c                	je     c0022ec8 <lock_acquire+0x6e>
c0022e9c:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0022ea3:	c0 
c0022ea4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022eab:	c0 
c0022eac:	c7 44 24 08 29 d2 02 	movl   $0xc002d229,0x8(%esp)
c0022eb3:	c0 
c0022eb4:	c7 44 24 04 e9 00 00 	movl   $0xe9,0x4(%esp)
c0022ebb:	00 
c0022ebc:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022ec3:	e8 bb 5a 00 00       	call   c0028983 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022ec8:	89 1c 24             	mov    %ebx,(%esp)
c0022ecb:	e8 41 ff ff ff       	call   c0022e11 <lock_held_by_current_thread>
c0022ed0:	84 c0                	test   %al,%al
c0022ed2:	74 2c                	je     c0022f00 <lock_acquire+0xa6>
c0022ed4:	c7 44 24 10 7c ea 02 	movl   $0xc002ea7c,0x10(%esp)
c0022edb:	c0 
c0022edc:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022ee3:	c0 
c0022ee4:	c7 44 24 08 29 d2 02 	movl   $0xc002d229,0x8(%esp)
c0022eeb:	c0 
c0022eec:	c7 44 24 04 ea 00 00 	movl   $0xea,0x4(%esp)
c0022ef3:	00 
c0022ef4:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022efb:	e8 83 5a 00 00       	call   c0028983 <debug_panic>
  old_level = intr_disable ();
c0022f00:	e8 ba ea ff ff       	call   c00219bf <intr_disable>
c0022f05:	89 c6                	mov    %eax,%esi
  if(!thread_mlfqs && lock->holder != NULL)
c0022f07:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0022f0e:	75 20                	jne    c0022f30 <lock_acquire+0xd6>
c0022f10:	83 3b 00             	cmpl   $0x0,(%ebx)
c0022f13:	74 1b                	je     c0022f30 <lock_acquire+0xd6>
    int curr_prio = thread_get_priority();
c0022f15:	e8 20 e0 ff ff       	call   c0020f3a <thread_get_priority>
    struct lock * lock_copy = lock;
c0022f1a:	89 da                	mov    %ebx,%edx
        l_holder = lock_copy->holder;
c0022f1c:	8b 0a                	mov    (%edx),%ecx
        if( l_holder->priority < curr_prio)
c0022f1e:	3b 41 1c             	cmp    0x1c(%ecx),%eax
c0022f21:	7e 06                	jle    c0022f29 <lock_acquire+0xcf>
          l_holder->priority = curr_prio;
c0022f23:	89 41 1c             	mov    %eax,0x1c(%ecx)
          lock_copy->max_priority = curr_prio;
c0022f26:	89 42 20             	mov    %eax,0x20(%edx)
        lock_copy = l_holder->wait_on_lock;
c0022f29:	8b 51 50             	mov    0x50(%ecx),%edx
    while(lock_copy != NULL){ 
c0022f2c:	85 d2                	test   %edx,%edx
c0022f2e:	75 ec                	jne    c0022f1c <lock_acquire+0xc2>
  thread_current()->wait_on_lock = lock; //I'm waiting on this lock
c0022f30:	e8 a4 de ff ff       	call   c0020dd9 <thread_current>
c0022f35:	89 58 50             	mov    %ebx,0x50(%eax)
  intr_set_level (old_level);
c0022f38:	89 34 24             	mov    %esi,(%esp)
c0022f3b:	e8 86 ea ff ff       	call   c00219c6 <intr_set_level>
  sema_down (&lock->semaphore);          //lock acquired
c0022f40:	8d 43 04             	lea    0x4(%ebx),%eax
c0022f43:	89 04 24             	mov    %eax,(%esp)
c0022f46:	e8 e7 fb ff ff       	call   c0022b32 <sema_down>
  lock->holder = thread_current ();      //Now I'm the owner of this lock
c0022f4b:	e8 89 de ff ff       	call   c0020dd9 <thread_current>
c0022f50:	89 03                	mov    %eax,(%ebx)
  thread_current()->wait_on_lock = NULL; //and now no more waiting for this lock
c0022f52:	e8 82 de ff ff       	call   c0020dd9 <thread_current>
c0022f57:	c7 40 50 00 00 00 00 	movl   $0x0,0x50(%eax)
  list_insert_ordered(&(thread_current()->locks_held), &lock->elem, lockPrioCompare,NULL);
c0022f5e:	e8 76 de ff ff       	call   c0020dd9 <thread_current>
c0022f63:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0022f6a:	00 
c0022f6b:	c7 44 24 08 c2 2a 02 	movl   $0xc0022ac2,0x8(%esp)
c0022f72:	c0 
c0022f73:	8d 53 18             	lea    0x18(%ebx),%edx
c0022f76:	89 54 24 04          	mov    %edx,0x4(%esp)
c0022f7a:	83 c0 40             	add    $0x40,%eax
c0022f7d:	89 04 24             	mov    %eax,(%esp)
c0022f80:	e8 f1 64 00 00       	call   c0029476 <list_insert_ordered>
  lock->max_priority = thread_get_priority();
c0022f85:	e8 b0 df ff ff       	call   c0020f3a <thread_get_priority>
c0022f8a:	89 43 20             	mov    %eax,0x20(%ebx)
}
c0022f8d:	83 c4 24             	add    $0x24,%esp
c0022f90:	5b                   	pop    %ebx
c0022f91:	5e                   	pop    %esi
c0022f92:	c3                   	ret    

c0022f93 <lock_try_acquire>:
{
c0022f93:	56                   	push   %esi
c0022f94:	53                   	push   %ebx
c0022f95:	83 ec 24             	sub    $0x24,%esp
c0022f98:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022f9c:	85 db                	test   %ebx,%ebx
c0022f9e:	75 2c                	jne    c0022fcc <lock_try_acquire+0x39>
c0022fa0:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022fa7:	c0 
c0022fa8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022faf:	c0 
c0022fb0:	c7 44 24 08 18 d2 02 	movl   $0xc002d218,0x8(%esp)
c0022fb7:	c0 
c0022fb8:	c7 44 24 04 15 01 00 	movl   $0x115,0x4(%esp)
c0022fbf:	00 
c0022fc0:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022fc7:	e8 b7 59 00 00       	call   c0028983 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022fcc:	89 1c 24             	mov    %ebx,(%esp)
c0022fcf:	e8 3d fe ff ff       	call   c0022e11 <lock_held_by_current_thread>
c0022fd4:	84 c0                	test   %al,%al
c0022fd6:	74 2c                	je     c0023004 <lock_try_acquire+0x71>
c0022fd8:	c7 44 24 10 7c ea 02 	movl   $0xc002ea7c,0x10(%esp)
c0022fdf:	c0 
c0022fe0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022fe7:	c0 
c0022fe8:	c7 44 24 08 18 d2 02 	movl   $0xc002d218,0x8(%esp)
c0022fef:	c0 
c0022ff0:	c7 44 24 04 16 01 00 	movl   $0x116,0x4(%esp)
c0022ff7:	00 
c0022ff8:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022fff:	e8 7f 59 00 00       	call   c0028983 <debug_panic>
  success = sema_try_down (&lock->semaphore);
c0023004:	8d 43 04             	lea    0x4(%ebx),%eax
c0023007:	89 04 24             	mov    %eax,(%esp)
c002300a:	e8 d5 fb ff ff       	call   c0022be4 <sema_try_down>
c002300f:	89 c6                	mov    %eax,%esi
  if (success)
c0023011:	84 c0                	test   %al,%al
c0023013:	74 07                	je     c002301c <lock_try_acquire+0x89>
    lock->holder = thread_current ();
c0023015:	e8 bf dd ff ff       	call   c0020dd9 <thread_current>
c002301a:	89 03                	mov    %eax,(%ebx)
}
c002301c:	89 f0                	mov    %esi,%eax
c002301e:	83 c4 24             	add    $0x24,%esp
c0023021:	5b                   	pop    %ebx
c0023022:	5e                   	pop    %esi
c0023023:	c3                   	ret    

c0023024 <lock_release>:
{
c0023024:	57                   	push   %edi
c0023025:	56                   	push   %esi
c0023026:	53                   	push   %ebx
c0023027:	83 ec 20             	sub    $0x20,%esp
c002302a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c002302e:	85 db                	test   %ebx,%ebx
c0023030:	75 2c                	jne    c002305e <lock_release+0x3a>
c0023032:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0023039:	c0 
c002303a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023041:	c0 
c0023042:	c7 44 24 08 0b d2 02 	movl   $0xc002d20b,0x8(%esp)
c0023049:	c0 
c002304a:	c7 44 24 04 26 01 00 	movl   $0x126,0x4(%esp)
c0023051:	00 
c0023052:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0023059:	e8 25 59 00 00       	call   c0028983 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c002305e:	89 1c 24             	mov    %ebx,(%esp)
c0023061:	e8 ab fd ff ff       	call   c0022e11 <lock_held_by_current_thread>
c0023066:	84 c0                	test   %al,%al
c0023068:	75 2c                	jne    c0023096 <lock_release+0x72>
c002306a:	c7 44 24 10 a0 ea 02 	movl   $0xc002eaa0,0x10(%esp)
c0023071:	c0 
c0023072:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023079:	c0 
c002307a:	c7 44 24 08 0b d2 02 	movl   $0xc002d20b,0x8(%esp)
c0023081:	c0 
c0023082:	c7 44 24 04 27 01 00 	movl   $0x127,0x4(%esp)
c0023089:	00 
c002308a:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0023091:	e8 ed 58 00 00       	call   c0028983 <debug_panic>
  old_level = intr_disable ();
c0023096:	e8 24 e9 ff ff       	call   c00219bf <intr_disable>
c002309b:	89 c6                	mov    %eax,%esi
  lock->holder = NULL;
c002309d:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  lock->max_priority = -1;
c00230a3:	c7 43 20 ff ff ff ff 	movl   $0xffffffff,0x20(%ebx)
  list_remove(&lock->elem);
c00230aa:	8d 43 18             	lea    0x18(%ebx),%eax
c00230ad:	89 04 24             	mov    %eax,(%esp)
c00230b0:	e8 3f 5f 00 00       	call   c0028ff4 <list_remove>
  if(!thread_mlfqs)
c00230b5:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c00230bc:	75 45                	jne    c0023103 <lock_release+0xdf>
    if(!list_empty(&(thread_current()->locks_held)))
c00230be:	e8 16 dd ff ff       	call   c0020dd9 <thread_current>
c00230c3:	83 c0 40             	add    $0x40,%eax
c00230c6:	89 04 24             	mov    %eax,(%esp)
c00230c9:	e8 b8 5f 00 00       	call   c0029086 <list_empty>
c00230ce:	84 c0                	test   %al,%al
c00230d0:	75 1f                	jne    c00230f1 <lock_release+0xcd>
      struct list_elem *first_elem = list_begin(&(thread_current()->locks_held));
c00230d2:	e8 02 dd ff ff       	call   c0020dd9 <thread_current>
c00230d7:	83 c0 40             	add    $0x40,%eax
c00230da:	89 04 24             	mov    %eax,(%esp)
c00230dd:	e8 bf 59 00 00       	call   c0028aa1 <list_begin>
c00230e2:	89 c7                	mov    %eax,%edi
      thread_current()->priority = l->max_priority;
c00230e4:	e8 f0 dc ff ff       	call   c0020dd9 <thread_current>
c00230e9:	8b 57 08             	mov    0x8(%edi),%edx
c00230ec:	89 50 1c             	mov    %edx,0x1c(%eax)
c00230ef:	eb 12                	jmp    c0023103 <lock_release+0xdf>
      thread_current()->priority = thread_current()->old_priority;
c00230f1:	e8 e3 dc ff ff       	call   c0020dd9 <thread_current>
c00230f6:	89 c7                	mov    %eax,%edi
c00230f8:	e8 dc dc ff ff       	call   c0020dd9 <thread_current>
c00230fd:	8b 40 3c             	mov    0x3c(%eax),%eax
c0023100:	89 47 1c             	mov    %eax,0x1c(%edi)
  intr_set_level (old_level);
c0023103:	89 34 24             	mov    %esi,(%esp)
c0023106:	e8 bb e8 ff ff       	call   c00219c6 <intr_set_level>
  sema_up (&lock->semaphore);
c002310b:	83 c3 04             	add    $0x4,%ebx
c002310e:	89 1c 24             	mov    %ebx,(%esp)
c0023111:	e8 31 fb ff ff       	call   c0022c47 <sema_up>
}
c0023116:	83 c4 20             	add    $0x20,%esp
c0023119:	5b                   	pop    %ebx
c002311a:	5e                   	pop    %esi
c002311b:	5f                   	pop    %edi
c002311c:	c3                   	ret    

c002311d <cond_init>:
/* Initializes condition variable COND.  A condition variable
   allows one piece of code to signal a condition and cooperating
   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
c002311d:	83 ec 2c             	sub    $0x2c,%esp
c0023120:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (cond != NULL);
c0023124:	85 c0                	test   %eax,%eax
c0023126:	75 2c                	jne    c0023154 <cond_init+0x37>
c0023128:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c002312f:	c0 
c0023130:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023137:	c0 
c0023138:	c7 44 24 08 e5 d1 02 	movl   $0xc002d1e5,0x8(%esp)
c002313f:	c0 
c0023140:	c7 44 24 04 6f 01 00 	movl   $0x16f,0x4(%esp)
c0023147:	00 
c0023148:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002314f:	e8 2f 58 00 00       	call   c0028983 <debug_panic>

  list_init (&cond->waiters);
c0023154:	89 04 24             	mov    %eax,(%esp)
c0023157:	e8 f4 58 00 00       	call   c0028a50 <list_init>
}
c002315c:	83 c4 2c             	add    $0x2c,%esp
c002315f:	c3                   	ret    

c0023160 <cond_wait>:
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
cond_wait (struct condition *cond, struct lock *lock) 
{
c0023160:	55                   	push   %ebp
c0023161:	57                   	push   %edi
c0023162:	56                   	push   %esi
c0023163:	53                   	push   %ebx
c0023164:	83 ec 4c             	sub    $0x4c,%esp
c0023167:	8b 74 24 60          	mov    0x60(%esp),%esi
c002316b:	8b 5c 24 64          	mov    0x64(%esp),%ebx
  struct semaphore_elem waiter;

  ASSERT (cond != NULL);
c002316f:	85 f6                	test   %esi,%esi
c0023171:	75 2c                	jne    c002319f <cond_wait+0x3f>
c0023173:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c002317a:	c0 
c002317b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023182:	c0 
c0023183:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c002318a:	c0 
c002318b:	c7 44 24 04 8a 01 00 	movl   $0x18a,0x4(%esp)
c0023192:	00 
c0023193:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002319a:	e8 e4 57 00 00       	call   c0028983 <debug_panic>
  ASSERT (lock != NULL);
c002319f:	85 db                	test   %ebx,%ebx
c00231a1:	75 2c                	jne    c00231cf <cond_wait+0x6f>
c00231a3:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c00231aa:	c0 
c00231ab:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00231b2:	c0 
c00231b3:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c00231ba:	c0 
c00231bb:	c7 44 24 04 8b 01 00 	movl   $0x18b,0x4(%esp)
c00231c2:	00 
c00231c3:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00231ca:	e8 b4 57 00 00       	call   c0028983 <debug_panic>
  ASSERT (!intr_context ());
c00231cf:	e8 4d ea ff ff       	call   c0021c21 <intr_context>
c00231d4:	84 c0                	test   %al,%al
c00231d6:	74 2c                	je     c0023204 <cond_wait+0xa4>
c00231d8:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00231df:	c0 
c00231e0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00231e7:	c0 
c00231e8:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c00231ef:	c0 
c00231f0:	c7 44 24 04 8c 01 00 	movl   $0x18c,0x4(%esp)
c00231f7:	00 
c00231f8:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00231ff:	e8 7f 57 00 00       	call   c0028983 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c0023204:	89 1c 24             	mov    %ebx,(%esp)
c0023207:	e8 05 fc ff ff       	call   c0022e11 <lock_held_by_current_thread>
c002320c:	84 c0                	test   %al,%al
c002320e:	75 2c                	jne    c002323c <cond_wait+0xdc>
c0023210:	c7 44 24 10 a0 ea 02 	movl   $0xc002eaa0,0x10(%esp)
c0023217:	c0 
c0023218:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002321f:	c0 
c0023220:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c0023227:	c0 
c0023228:	c7 44 24 04 8d 01 00 	movl   $0x18d,0x4(%esp)
c002322f:	00 
c0023230:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0023237:	e8 47 57 00 00       	call   c0028983 <debug_panic>
  
  sema_init (&waiter.semaphore, 0);
c002323c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023243:	00 
c0023244:	8d 6c 24 20          	lea    0x20(%esp),%ebp
c0023248:	8d 7c 24 28          	lea    0x28(%esp),%edi
c002324c:	89 3c 24             	mov    %edi,(%esp)
c002324f:	e8 92 f8 ff ff       	call   c0022ae6 <sema_init>
  waiter.priority = thread_get_priority(); //(ADDED) sets sema's prio value to the threads prio
c0023254:	e8 e1 dc ff ff       	call   c0020f3a <thread_get_priority>
c0023259:	89 44 24 3c          	mov    %eax,0x3c(%esp)

  list_push_back (&cond->waiters, &waiter.elem);
c002325d:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0023261:	89 34 24             	mov    %esi,(%esp)
c0023264:	e8 68 5d 00 00       	call   c0028fd1 <list_push_back>
  lock_release (lock);
c0023269:	89 1c 24             	mov    %ebx,(%esp)
c002326c:	e8 b3 fd ff ff       	call   c0023024 <lock_release>
  sema_down (&waiter.semaphore);
c0023271:	89 3c 24             	mov    %edi,(%esp)
c0023274:	e8 b9 f8 ff ff       	call   c0022b32 <sema_down>
  lock_acquire (lock);
c0023279:	89 1c 24             	mov    %ebx,(%esp)
c002327c:	e8 d9 fb ff ff       	call   c0022e5a <lock_acquire>
}
c0023281:	83 c4 4c             	add    $0x4c,%esp
c0023284:	5b                   	pop    %ebx
c0023285:	5e                   	pop    %esi
c0023286:	5f                   	pop    %edi
c0023287:	5d                   	pop    %ebp
c0023288:	c3                   	ret    

c0023289 <cond_signal>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_signal (struct condition *cond, struct lock *lock UNUSED) 
{
c0023289:	56                   	push   %esi
c002328a:	53                   	push   %ebx
c002328b:	83 ec 24             	sub    $0x24,%esp
c002328e:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0023292:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c0023296:	85 db                	test   %ebx,%ebx
c0023298:	75 2c                	jne    c00232c6 <cond_signal+0x3d>
c002329a:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c00232a1:	c0 
c00232a2:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00232a9:	c0 
c00232aa:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c00232b1:	c0 
c00232b2:	c7 44 24 04 a1 01 00 	movl   $0x1a1,0x4(%esp)
c00232b9:	00 
c00232ba:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00232c1:	e8 bd 56 00 00       	call   c0028983 <debug_panic>
  ASSERT (lock != NULL);
c00232c6:	85 f6                	test   %esi,%esi
c00232c8:	75 2c                	jne    c00232f6 <cond_signal+0x6d>
c00232ca:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c00232d1:	c0 
c00232d2:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00232d9:	c0 
c00232da:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c00232e1:	c0 
c00232e2:	c7 44 24 04 a2 01 00 	movl   $0x1a2,0x4(%esp)
c00232e9:	00 
c00232ea:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00232f1:	e8 8d 56 00 00       	call   c0028983 <debug_panic>
  ASSERT (!intr_context ());
c00232f6:	e8 26 e9 ff ff       	call   c0021c21 <intr_context>
c00232fb:	84 c0                	test   %al,%al
c00232fd:	74 2c                	je     c002332b <cond_signal+0xa2>
c00232ff:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0023306:	c0 
c0023307:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002330e:	c0 
c002330f:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c0023316:	c0 
c0023317:	c7 44 24 04 a3 01 00 	movl   $0x1a3,0x4(%esp)
c002331e:	00 
c002331f:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0023326:	e8 58 56 00 00       	call   c0028983 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c002332b:	89 34 24             	mov    %esi,(%esp)
c002332e:	e8 de fa ff ff       	call   c0022e11 <lock_held_by_current_thread>
c0023333:	84 c0                	test   %al,%al
c0023335:	75 2c                	jne    c0023363 <cond_signal+0xda>
c0023337:	c7 44 24 10 a0 ea 02 	movl   $0xc002eaa0,0x10(%esp)
c002333e:	c0 
c002333f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023346:	c0 
c0023347:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c002334e:	c0 
c002334f:	c7 44 24 04 a4 01 00 	movl   $0x1a4,0x4(%esp)
c0023356:	00 
c0023357:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002335e:	e8 20 56 00 00       	call   c0028983 <debug_panic>

  struct list_elem *max_cond_waiter; //(ADDED) to be used below
  if (!list_empty (&cond->waiters)) 
c0023363:	89 1c 24             	mov    %ebx,(%esp)
c0023366:	e8 1b 5d 00 00       	call   c0029086 <list_empty>
c002336b:	84 c0                	test   %al,%al
c002336d:	75 2d                	jne    c002339c <cond_signal+0x113>
  {
    //(ADDED) wakes max prio thread
    /* MODIFY PRIORITY: max priority blocked thread on cond should be woken up */
    //sema_up (&list_entry (list_pop_front (&cond->waiters), struct semaphore_elem, elem)->semaphore);
    max_cond_waiter = list_max (&cond->waiters,semaPrioCompare,NULL);
c002336f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0023376:	00 
c0023377:	c7 44 24 04 d4 2a 02 	movl   $0xc0022ad4,0x4(%esp)
c002337e:	c0 
c002337f:	89 1c 24             	mov    %ebx,(%esp)
c0023382:	e8 d3 62 00 00       	call   c002965a <list_max>
c0023387:	89 c3                	mov    %eax,%ebx
    list_remove(max_cond_waiter);
c0023389:	89 04 24             	mov    %eax,(%esp)
c002338c:	e8 63 5c 00 00       	call   c0028ff4 <list_remove>
    sema_up (&list_entry(max_cond_waiter,struct semaphore_elem,elem)->semaphore);
c0023391:	83 c3 08             	add    $0x8,%ebx
c0023394:	89 1c 24             	mov    %ebx,(%esp)
c0023397:	e8 ab f8 ff ff       	call   c0022c47 <sema_up>
  }
}
c002339c:	83 c4 24             	add    $0x24,%esp
c002339f:	5b                   	pop    %ebx
c00233a0:	5e                   	pop    %esi
c00233a1:	c3                   	ret    

c00233a2 <cond_broadcast>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock) 
{
c00233a2:	56                   	push   %esi
c00233a3:	53                   	push   %ebx
c00233a4:	83 ec 24             	sub    $0x24,%esp
c00233a7:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00233ab:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c00233af:	85 db                	test   %ebx,%ebx
c00233b1:	75 2c                	jne    c00233df <cond_broadcast+0x3d>
c00233b3:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c00233ba:	c0 
c00233bb:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00233c2:	c0 
c00233c3:	c7 44 24 08 c0 d1 02 	movl   $0xc002d1c0,0x8(%esp)
c00233ca:	c0 
c00233cb:	c7 44 24 04 ba 01 00 	movl   $0x1ba,0x4(%esp)
c00233d2:	00 
c00233d3:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00233da:	e8 a4 55 00 00       	call   c0028983 <debug_panic>
  ASSERT (lock != NULL);
c00233df:	85 f6                	test   %esi,%esi
c00233e1:	75 38                	jne    c002341b <cond_broadcast+0x79>
c00233e3:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c00233ea:	c0 
c00233eb:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00233f2:	c0 
c00233f3:	c7 44 24 08 c0 d1 02 	movl   $0xc002d1c0,0x8(%esp)
c00233fa:	c0 
c00233fb:	c7 44 24 04 bb 01 00 	movl   $0x1bb,0x4(%esp)
c0023402:	00 
c0023403:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002340a:	e8 74 55 00 00       	call   c0028983 <debug_panic>

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
c002340f:	89 74 24 04          	mov    %esi,0x4(%esp)
c0023413:	89 1c 24             	mov    %ebx,(%esp)
c0023416:	e8 6e fe ff ff       	call   c0023289 <cond_signal>
  while (!list_empty (&cond->waiters))
c002341b:	89 1c 24             	mov    %ebx,(%esp)
c002341e:	e8 63 5c 00 00       	call   c0029086 <list_empty>
c0023423:	84 c0                	test   %al,%al
c0023425:	74 e8                	je     c002340f <cond_broadcast+0x6d>
c0023427:	83 c4 24             	add    $0x24,%esp
c002342a:	5b                   	pop    %ebx
c002342b:	5e                   	pop    %esi
c002342c:	c3                   	ret    

c002342d <init_pool>:

/* Initializes pool P as starting at START and ending at END,
   naming it NAME for debugging purposes. */
static void
init_pool (struct pool *p, void *base, size_t page_cnt, const char *name) 
{
c002342d:	55                   	push   %ebp
c002342e:	57                   	push   %edi
c002342f:	56                   	push   %esi
c0023430:	53                   	push   %ebx
c0023431:	83 ec 2c             	sub    $0x2c,%esp
c0023434:	89 c7                	mov    %eax,%edi
c0023436:	89 d5                	mov    %edx,%ebp
c0023438:	89 cb                	mov    %ecx,%ebx
  /* We'll put the pool's used_map at its base.
     Calculate the space needed for the bitmap
     and subtract it from the pool's size. */
  size_t bm_pages = DIV_ROUND_UP (bitmap_buf_size (page_cnt), PGSIZE);
c002343a:	89 0c 24             	mov    %ecx,(%esp)
c002343d:	e8 ee 62 00 00       	call   c0029730 <bitmap_buf_size>
c0023442:	8d b0 ff 0f 00 00    	lea    0xfff(%eax),%esi
c0023448:	c1 ee 0c             	shr    $0xc,%esi
  if (bm_pages > page_cnt)
c002344b:	39 f3                	cmp    %esi,%ebx
c002344d:	73 2c                	jae    c002347b <init_pool+0x4e>
    PANIC ("Not enough memory in %s for bitmap.", name);
c002344f:	8b 44 24 40          	mov    0x40(%esp),%eax
c0023453:	89 44 24 10          	mov    %eax,0x10(%esp)
c0023457:	c7 44 24 0c c4 ea 02 	movl   $0xc002eac4,0xc(%esp)
c002345e:	c0 
c002345f:	c7 44 24 08 93 d2 02 	movl   $0xc002d293,0x8(%esp)
c0023466:	c0 
c0023467:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c002346e:	00 
c002346f:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c0023476:	e8 08 55 00 00       	call   c0028983 <debug_panic>
  page_cnt -= bm_pages;
c002347b:	29 f3                	sub    %esi,%ebx

  printf ("%zu pages available in %s.\n", page_cnt, name);
c002347d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0023481:	89 44 24 08          	mov    %eax,0x8(%esp)
c0023485:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023489:	c7 04 24 2f eb 02 c0 	movl   $0xc002eb2f,(%esp)
c0023490:	e8 99 36 00 00       	call   c0026b2e <printf>

  /* Initialize the pool. */
  lock_init (&p->lock);
c0023495:	89 3c 24             	mov    %edi,(%esp)
c0023498:	e8 20 f9 ff ff       	call   c0022dbd <lock_init>
  p->used_map = bitmap_create_in_buf (page_cnt, base, bm_pages * PGSIZE);
c002349d:	c1 e6 0c             	shl    $0xc,%esi
c00234a0:	89 74 24 08          	mov    %esi,0x8(%esp)
c00234a4:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00234a8:	89 1c 24             	mov    %ebx,(%esp)
c00234ab:	e8 c5 65 00 00       	call   c0029a75 <bitmap_create_in_buf>
c00234b0:	89 47 24             	mov    %eax,0x24(%edi)
  p->base = base + bm_pages * PGSIZE;
c00234b3:	01 ee                	add    %ebp,%esi
c00234b5:	89 77 28             	mov    %esi,0x28(%edi)
}
c00234b8:	83 c4 2c             	add    $0x2c,%esp
c00234bb:	5b                   	pop    %ebx
c00234bc:	5e                   	pop    %esi
c00234bd:	5f                   	pop    %edi
c00234be:	5d                   	pop    %ebp
c00234bf:	c3                   	ret    

c00234c0 <palloc_init>:
{
c00234c0:	56                   	push   %esi
c00234c1:	53                   	push   %ebx
c00234c2:	83 ec 24             	sub    $0x24,%esp
c00234c5:	8b 54 24 30          	mov    0x30(%esp),%edx
  uint8_t *free_end = ptov (init_ram_pages * PGSIZE);
c00234c9:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c00234ce:	c1 e0 0c             	shl    $0xc,%eax
  ASSERT ((void *) paddr < PHYS_BASE);
c00234d1:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c00234d6:	76 2c                	jbe    c0023504 <palloc_init+0x44>
c00234d8:	c7 44 24 10 56 e1 02 	movl   $0xc002e156,0x10(%esp)
c00234df:	c0 
c00234e0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00234e7:	c0 
c00234e8:	c7 44 24 08 9d d2 02 	movl   $0xc002d29d,0x8(%esp)
c00234ef:	c0 
c00234f0:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c00234f7:	00 
c00234f8:	c7 04 24 88 e1 02 c0 	movl   $0xc002e188,(%esp)
c00234ff:	e8 7f 54 00 00       	call   c0028983 <debug_panic>
  size_t free_pages = (free_end - free_start) / PGSIZE;
c0023504:	8d b0 ff 0f f0 ff    	lea    -0xff001(%eax),%esi
c002350a:	2d 00 00 10 00       	sub    $0x100000,%eax
c002350f:	0f 49 f0             	cmovns %eax,%esi
c0023512:	c1 fe 0c             	sar    $0xc,%esi
  size_t user_pages = free_pages / 2;
c0023515:	89 f3                	mov    %esi,%ebx
c0023517:	d1 eb                	shr    %ebx
c0023519:	39 d3                	cmp    %edx,%ebx
c002351b:	0f 47 da             	cmova  %edx,%ebx
  kernel_pages = free_pages - user_pages;
c002351e:	29 de                	sub    %ebx,%esi
  init_pool (&kernel_pool, free_start, kernel_pages, "kernel pool");
c0023520:	c7 04 24 4b eb 02 c0 	movl   $0xc002eb4b,(%esp)
c0023527:	89 f1                	mov    %esi,%ecx
c0023529:	ba 00 00 10 c0       	mov    $0xc0100000,%edx
c002352e:	b8 a0 74 03 c0       	mov    $0xc00374a0,%eax
c0023533:	e8 f5 fe ff ff       	call   c002342d <init_pool>
  init_pool (&user_pool, free_start + kernel_pages * PGSIZE,
c0023538:	c1 e6 0c             	shl    $0xc,%esi
c002353b:	8d 96 00 00 10 c0    	lea    -0x3ff00000(%esi),%edx
c0023541:	c7 04 24 57 eb 02 c0 	movl   $0xc002eb57,(%esp)
c0023548:	89 d9                	mov    %ebx,%ecx
c002354a:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c002354f:	e8 d9 fe ff ff       	call   c002342d <init_pool>
}
c0023554:	83 c4 24             	add    $0x24,%esp
c0023557:	5b                   	pop    %ebx
c0023558:	5e                   	pop    %esi
c0023559:	c3                   	ret    

c002355a <palloc_get_multiple>:
{
c002355a:	55                   	push   %ebp
c002355b:	57                   	push   %edi
c002355c:	56                   	push   %esi
c002355d:	53                   	push   %ebx
c002355e:	83 ec 1c             	sub    $0x1c,%esp
c0023561:	8b 74 24 30          	mov    0x30(%esp),%esi
c0023565:	8b 7c 24 34          	mov    0x34(%esp),%edi
  struct pool *pool = flags & PAL_USER ? &user_pool : &kernel_pool;
c0023569:	89 f0                	mov    %esi,%eax
c002356b:	83 e0 04             	and    $0x4,%eax
c002356e:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c0023573:	bb a0 74 03 c0       	mov    $0xc00374a0,%ebx
c0023578:	0f 45 d8             	cmovne %eax,%ebx
  if (page_cnt == 0)
c002357b:	85 ff                	test   %edi,%edi
c002357d:	0f 84 8f 00 00 00    	je     c0023612 <palloc_get_multiple+0xb8>
  lock_acquire (&pool->lock);
c0023583:	89 1c 24             	mov    %ebx,(%esp)
c0023586:	e8 cf f8 ff ff       	call   c0022e5a <lock_acquire>
  page_idx = bitmap_scan_and_flip (pool->used_map, 0, page_cnt, false);
c002358b:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023592:	00 
c0023593:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0023597:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002359e:	00 
c002359f:	8b 43 24             	mov    0x24(%ebx),%eax
c00235a2:	89 04 24             	mov    %eax,(%esp)
c00235a5:	e8 50 68 00 00       	call   c0029dfa <bitmap_scan_and_flip>
c00235aa:	89 c5                	mov    %eax,%ebp
  lock_release (&pool->lock);
c00235ac:	89 1c 24             	mov    %ebx,(%esp)
c00235af:	e8 70 fa ff ff       	call   c0023024 <lock_release>
  if (page_idx != BITMAP_ERROR)
c00235b4:	83 fd ff             	cmp    $0xffffffff,%ebp
c00235b7:	74 2d                	je     c00235e6 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c00235b9:	c1 e5 0c             	shl    $0xc,%ebp
  if (pages != NULL) 
c00235bc:	03 6b 28             	add    0x28(%ebx),%ebp
c00235bf:	74 25                	je     c00235e6 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c00235c1:	89 e8                	mov    %ebp,%eax
      if (flags & PAL_ZERO)
c00235c3:	f7 c6 02 00 00 00    	test   $0x2,%esi
c00235c9:	74 53                	je     c002361e <palloc_get_multiple+0xc4>
        memset (pages, 0, PGSIZE * page_cnt);
c00235cb:	c1 e7 0c             	shl    $0xc,%edi
c00235ce:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00235d2:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00235d9:	00 
c00235da:	89 2c 24             	mov    %ebp,(%esp)
c00235dd:	e8 5f 48 00 00       	call   c0027e41 <memset>
    pages = pool->base + PGSIZE * page_idx;
c00235e2:	89 e8                	mov    %ebp,%eax
c00235e4:	eb 38                	jmp    c002361e <palloc_get_multiple+0xc4>
      if (flags & PAL_ASSERT)
c00235e6:	f7 c6 01 00 00 00    	test   $0x1,%esi
c00235ec:	74 2b                	je     c0023619 <palloc_get_multiple+0xbf>
        PANIC ("palloc_get: out of pages");
c00235ee:	c7 44 24 0c 61 eb 02 	movl   $0xc002eb61,0xc(%esp)
c00235f5:	c0 
c00235f6:	c7 44 24 08 7f d2 02 	movl   $0xc002d27f,0x8(%esp)
c00235fd:	c0 
c00235fe:	c7 44 24 04 61 00 00 	movl   $0x61,0x4(%esp)
c0023605:	00 
c0023606:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c002360d:	e8 71 53 00 00       	call   c0028983 <debug_panic>
    return NULL;
c0023612:	b8 00 00 00 00       	mov    $0x0,%eax
c0023617:	eb 05                	jmp    c002361e <palloc_get_multiple+0xc4>
  return pages;
c0023619:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002361e:	83 c4 1c             	add    $0x1c,%esp
c0023621:	5b                   	pop    %ebx
c0023622:	5e                   	pop    %esi
c0023623:	5f                   	pop    %edi
c0023624:	5d                   	pop    %ebp
c0023625:	c3                   	ret    

c0023626 <palloc_get_page>:
{
c0023626:	83 ec 1c             	sub    $0x1c,%esp
  return palloc_get_multiple (flags, 1);
c0023629:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023630:	00 
c0023631:	8b 44 24 20          	mov    0x20(%esp),%eax
c0023635:	89 04 24             	mov    %eax,(%esp)
c0023638:	e8 1d ff ff ff       	call   c002355a <palloc_get_multiple>
}
c002363d:	83 c4 1c             	add    $0x1c,%esp
c0023640:	c3                   	ret    

c0023641 <palloc_free_multiple>:
{
c0023641:	55                   	push   %ebp
c0023642:	57                   	push   %edi
c0023643:	56                   	push   %esi
c0023644:	53                   	push   %ebx
c0023645:	83 ec 2c             	sub    $0x2c,%esp
c0023648:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c002364c:	8b 74 24 44          	mov    0x44(%esp),%esi
  ASSERT (pg_ofs (pages) == 0);
c0023650:	f7 c3 ff 0f 00 00    	test   $0xfff,%ebx
c0023656:	74 2c                	je     c0023684 <palloc_free_multiple+0x43>
c0023658:	c7 44 24 10 7a eb 02 	movl   $0xc002eb7a,0x10(%esp)
c002365f:	c0 
c0023660:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023667:	c0 
c0023668:	c7 44 24 08 6a d2 02 	movl   $0xc002d26a,0x8(%esp)
c002366f:	c0 
c0023670:	c7 44 24 04 7b 00 00 	movl   $0x7b,0x4(%esp)
c0023677:	00 
c0023678:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c002367f:	e8 ff 52 00 00       	call   c0028983 <debug_panic>
  if (pages == NULL || page_cnt == 0)
c0023684:	85 db                	test   %ebx,%ebx
c0023686:	0f 84 fc 00 00 00    	je     c0023788 <palloc_free_multiple+0x147>
c002368c:	85 f6                	test   %esi,%esi
c002368e:	0f 84 f4 00 00 00    	je     c0023788 <palloc_free_multiple+0x147>
  return (uintptr_t) va >> PGBITS;
c0023694:	89 df                	mov    %ebx,%edi
c0023696:	c1 ef 0c             	shr    $0xc,%edi
c0023699:	8b 2d c8 74 03 c0    	mov    0xc00374c8,%ebp
c002369f:	c1 ed 0c             	shr    $0xc,%ebp
static bool
page_from_pool (const struct pool *pool, void *page) 
{
  size_t page_no = pg_no (page);
  size_t start_page = pg_no (pool->base);
  size_t end_page = start_page + bitmap_size (pool->used_map);
c00236a2:	a1 c4 74 03 c0       	mov    0xc00374c4,%eax
c00236a7:	89 04 24             	mov    %eax,(%esp)
c00236aa:	e8 b7 60 00 00       	call   c0029766 <bitmap_size>
c00236af:	01 e8                	add    %ebp,%eax
  if (page_from_pool (&kernel_pool, pages))
c00236b1:	39 c7                	cmp    %eax,%edi
c00236b3:	73 04                	jae    c00236b9 <palloc_free_multiple+0x78>
c00236b5:	39 ef                	cmp    %ebp,%edi
c00236b7:	73 44                	jae    c00236fd <palloc_free_multiple+0xbc>
c00236b9:	8b 2d 88 74 03 c0    	mov    0xc0037488,%ebp
c00236bf:	c1 ed 0c             	shr    $0xc,%ebp
  size_t end_page = start_page + bitmap_size (pool->used_map);
c00236c2:	a1 84 74 03 c0       	mov    0xc0037484,%eax
c00236c7:	89 04 24             	mov    %eax,(%esp)
c00236ca:	e8 97 60 00 00       	call   c0029766 <bitmap_size>
c00236cf:	01 e8                	add    %ebp,%eax
  else if (page_from_pool (&user_pool, pages))
c00236d1:	39 c7                	cmp    %eax,%edi
c00236d3:	73 04                	jae    c00236d9 <palloc_free_multiple+0x98>
c00236d5:	39 ef                	cmp    %ebp,%edi
c00236d7:	73 2b                	jae    c0023704 <palloc_free_multiple+0xc3>
    NOT_REACHED ();
c00236d9:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c00236e0:	c0 
c00236e1:	c7 44 24 08 6a d2 02 	movl   $0xc002d26a,0x8(%esp)
c00236e8:	c0 
c00236e9:	c7 44 24 04 84 00 00 	movl   $0x84,0x4(%esp)
c00236f0:	00 
c00236f1:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c00236f8:	e8 86 52 00 00       	call   c0028983 <debug_panic>
    pool = &kernel_pool;
c00236fd:	bd a0 74 03 c0       	mov    $0xc00374a0,%ebp
c0023702:	eb 05                	jmp    c0023709 <palloc_free_multiple+0xc8>
    pool = &user_pool;
c0023704:	bd 60 74 03 c0       	mov    $0xc0037460,%ebp
c0023709:	8b 45 28             	mov    0x28(%ebp),%eax
c002370c:	c1 e8 0c             	shr    $0xc,%eax
  page_idx = pg_no (pages) - pg_no (pool->base);
c002370f:	29 c7                	sub    %eax,%edi
  memset (pages, 0xcc, PGSIZE * page_cnt);
c0023711:	89 f0                	mov    %esi,%eax
c0023713:	c1 e0 0c             	shl    $0xc,%eax
c0023716:	89 44 24 08          	mov    %eax,0x8(%esp)
c002371a:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c0023721:	00 
c0023722:	89 1c 24             	mov    %ebx,(%esp)
c0023725:	e8 17 47 00 00       	call   c0027e41 <memset>
  ASSERT (bitmap_all (pool->used_map, page_idx, page_cnt));
c002372a:	89 74 24 08          	mov    %esi,0x8(%esp)
c002372e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023732:	8b 45 24             	mov    0x24(%ebp),%eax
c0023735:	89 04 24             	mov    %eax,(%esp)
c0023738:	e8 bf 65 00 00       	call   c0029cfc <bitmap_all>
c002373d:	84 c0                	test   %al,%al
c002373f:	75 2c                	jne    c002376d <palloc_free_multiple+0x12c>
c0023741:	c7 44 24 10 e8 ea 02 	movl   $0xc002eae8,0x10(%esp)
c0023748:	c0 
c0023749:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023750:	c0 
c0023751:	c7 44 24 08 6a d2 02 	movl   $0xc002d26a,0x8(%esp)
c0023758:	c0 
c0023759:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c0023760:	00 
c0023761:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c0023768:	e8 16 52 00 00       	call   c0028983 <debug_panic>
  bitmap_set_multiple (pool->used_map, page_idx, page_cnt, false);
c002376d:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023774:	00 
c0023775:	89 74 24 08          	mov    %esi,0x8(%esp)
c0023779:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002377d:	8b 45 24             	mov    0x24(%ebp),%eax
c0023780:	89 04 24             	mov    %eax,(%esp)
c0023783:	e8 55 61 00 00       	call   c00298dd <bitmap_set_multiple>
}
c0023788:	83 c4 2c             	add    $0x2c,%esp
c002378b:	5b                   	pop    %ebx
c002378c:	5e                   	pop    %esi
c002378d:	5f                   	pop    %edi
c002378e:	5d                   	pop    %ebp
c002378f:	c3                   	ret    

c0023790 <palloc_free_page>:
{
c0023790:	83 ec 1c             	sub    $0x1c,%esp
  palloc_free_multiple (page, 1);
c0023793:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c002379a:	00 
c002379b:	8b 44 24 20          	mov    0x20(%esp),%eax
c002379f:	89 04 24             	mov    %eax,(%esp)
c00237a2:	e8 9a fe ff ff       	call   c0023641 <palloc_free_multiple>
}
c00237a7:	83 c4 1c             	add    $0x1c,%esp
c00237aa:	c3                   	ret    
c00237ab:	90                   	nop
c00237ac:	90                   	nop
c00237ad:	90                   	nop
c00237ae:	90                   	nop
c00237af:	90                   	nop

c00237b0 <arena_to_block>:
}

/* Returns the (IDX - 1)'th block within arena A. */
static struct block *
arena_to_block (struct arena *a, size_t idx) 
{
c00237b0:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (a != NULL);
c00237b3:	85 c0                	test   %eax,%eax
c00237b5:	75 2c                	jne    c00237e3 <arena_to_block+0x33>
c00237b7:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c00237be:	c0 
c00237bf:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00237c6:	c0 
c00237c7:	c7 44 24 08 b6 d2 02 	movl   $0xc002d2b6,0x8(%esp)
c00237ce:	c0 
c00237cf:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c00237d6:	00 
c00237d7:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c00237de:	e8 a0 51 00 00       	call   c0028983 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c00237e3:	81 38 ed 8e 54 9a    	cmpl   $0x9a548eed,(%eax)
c00237e9:	74 2c                	je     c0023817 <arena_to_block+0x67>
c00237eb:	c7 44 24 10 a5 eb 02 	movl   $0xc002eba5,0x10(%esp)
c00237f2:	c0 
c00237f3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00237fa:	c0 
c00237fb:	c7 44 24 08 b6 d2 02 	movl   $0xc002d2b6,0x8(%esp)
c0023802:	c0 
c0023803:	c7 44 24 04 21 01 00 	movl   $0x121,0x4(%esp)
c002380a:	00 
c002380b:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c0023812:	e8 6c 51 00 00       	call   c0028983 <debug_panic>
  ASSERT (idx < a->desc->blocks_per_arena);
c0023817:	8b 48 04             	mov    0x4(%eax),%ecx
c002381a:	39 51 04             	cmp    %edx,0x4(%ecx)
c002381d:	77 2c                	ja     c002384b <arena_to_block+0x9b>
c002381f:	c7 44 24 10 c0 eb 02 	movl   $0xc002ebc0,0x10(%esp)
c0023826:	c0 
c0023827:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002382e:	c0 
c002382f:	c7 44 24 08 b6 d2 02 	movl   $0xc002d2b6,0x8(%esp)
c0023836:	c0 
c0023837:	c7 44 24 04 22 01 00 	movl   $0x122,0x4(%esp)
c002383e:	00 
c002383f:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c0023846:	e8 38 51 00 00       	call   c0028983 <debug_panic>
  return (struct block *) ((uint8_t *) a
                           + sizeof *a
                           + idx * a->desc->block_size);
c002384b:	0f af 11             	imul   (%ecx),%edx
  return (struct block *) ((uint8_t *) a
c002384e:	8d 44 10 0c          	lea    0xc(%eax,%edx,1),%eax
}
c0023852:	83 c4 2c             	add    $0x2c,%esp
c0023855:	c3                   	ret    

c0023856 <block_to_arena>:
{
c0023856:	53                   	push   %ebx
c0023857:	83 ec 28             	sub    $0x28,%esp
  ASSERT (a != NULL);
c002385a:	89 c1                	mov    %eax,%ecx
c002385c:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
c0023862:	75 2c                	jne    c0023890 <block_to_arena+0x3a>
c0023864:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c002386b:	c0 
c002386c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023873:	c0 
c0023874:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c002387b:	c0 
c002387c:	c7 44 24 04 11 01 00 	movl   $0x111,0x4(%esp)
c0023883:	00 
c0023884:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c002388b:	e8 f3 50 00 00       	call   c0028983 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c0023890:	81 39 ed 8e 54 9a    	cmpl   $0x9a548eed,(%ecx)
c0023896:	74 2c                	je     c00238c4 <block_to_arena+0x6e>
c0023898:	c7 44 24 10 a5 eb 02 	movl   $0xc002eba5,0x10(%esp)
c002389f:	c0 
c00238a0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00238a7:	c0 
c00238a8:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c00238af:	c0 
c00238b0:	c7 44 24 04 12 01 00 	movl   $0x112,0x4(%esp)
c00238b7:	00 
c00238b8:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c00238bf:	e8 bf 50 00 00       	call   c0028983 <debug_panic>
  ASSERT (a->desc == NULL
c00238c4:	8b 59 04             	mov    0x4(%ecx),%ebx
c00238c7:	85 db                	test   %ebx,%ebx
c00238c9:	74 3f                	je     c002390a <block_to_arena+0xb4>
  return (uintptr_t) va & PGMASK;
c00238cb:	25 ff 0f 00 00       	and    $0xfff,%eax
c00238d0:	8d 40 f4             	lea    -0xc(%eax),%eax
c00238d3:	ba 00 00 00 00       	mov    $0x0,%edx
c00238d8:	f7 33                	divl   (%ebx)
c00238da:	85 d2                	test   %edx,%edx
c00238dc:	74 62                	je     c0023940 <block_to_arena+0xea>
c00238de:	c7 44 24 10 e0 eb 02 	movl   $0xc002ebe0,0x10(%esp)
c00238e5:	c0 
c00238e6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00238ed:	c0 
c00238ee:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c00238f5:	c0 
c00238f6:	c7 44 24 04 16 01 00 	movl   $0x116,0x4(%esp)
c00238fd:	00 
c00238fe:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c0023905:	e8 79 50 00 00       	call   c0028983 <debug_panic>
c002390a:	25 ff 0f 00 00       	and    $0xfff,%eax
  ASSERT (a->desc != NULL || pg_ofs (b) == sizeof *a);
c002390f:	83 f8 0c             	cmp    $0xc,%eax
c0023912:	74 2c                	je     c0023940 <block_to_arena+0xea>
c0023914:	c7 44 24 10 28 ec 02 	movl   $0xc002ec28,0x10(%esp)
c002391b:	c0 
c002391c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023923:	c0 
c0023924:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c002392b:	c0 
c002392c:	c7 44 24 04 17 01 00 	movl   $0x117,0x4(%esp)
c0023933:	00 
c0023934:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c002393b:	e8 43 50 00 00       	call   c0028983 <debug_panic>
}
c0023940:	89 c8                	mov    %ecx,%eax
c0023942:	83 c4 28             	add    $0x28,%esp
c0023945:	5b                   	pop    %ebx
c0023946:	c3                   	ret    

c0023947 <malloc_init>:
{
c0023947:	57                   	push   %edi
c0023948:	56                   	push   %esi
c0023949:	53                   	push   %ebx
c002394a:	83 ec 20             	sub    $0x20,%esp
      struct desc *d = &descs[desc_cnt++];
c002394d:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c0023952:	8d 50 01             	lea    0x1(%eax),%edx
c0023955:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c002395b:	6b c0 3c             	imul   $0x3c,%eax,%eax
c002395e:	8d 98 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%ebx
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0023964:	83 fa 0a             	cmp    $0xa,%edx
c0023967:	76 7e                	jbe    c00239e7 <malloc_init+0xa0>
c0023969:	eb 1c                	jmp    c0023987 <malloc_init+0x40>
      struct desc *d = &descs[desc_cnt++];
c002396b:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c0023970:	8d 50 01             	lea    0x1(%eax),%edx
c0023973:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c0023979:	6b c0 3c             	imul   $0x3c,%eax,%eax
c002397c:	8d b0 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%esi
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0023982:	83 fa 0a             	cmp    $0xa,%edx
c0023985:	76 2c                	jbe    c00239b3 <malloc_init+0x6c>
c0023987:	c7 44 24 10 54 ec 02 	movl   $0xc002ec54,0x10(%esp)
c002398e:	c0 
c002398f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023996:	c0 
c0023997:	c7 44 24 08 c5 d2 02 	movl   $0xc002d2c5,0x8(%esp)
c002399e:	c0 
c002399f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c00239a6:	00 
c00239a7:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c00239ae:	e8 d0 4f 00 00       	call   c0028983 <debug_panic>
      d->block_size = block_size;
c00239b3:	89 98 00 75 03 c0    	mov    %ebx,-0x3ffc8b00(%eax)
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c00239b9:	89 f8                	mov    %edi,%eax
c00239bb:	ba 00 00 00 00       	mov    $0x0,%edx
c00239c0:	f7 f3                	div    %ebx
c00239c2:	89 46 04             	mov    %eax,0x4(%esi)
      list_init (&d->free_list);
c00239c5:	8d 46 08             	lea    0x8(%esi),%eax
c00239c8:	89 04 24             	mov    %eax,(%esp)
c00239cb:	e8 80 50 00 00       	call   c0028a50 <list_init>
      lock_init (&d->lock);
c00239d0:	83 c6 18             	add    $0x18,%esi
c00239d3:	89 34 24             	mov    %esi,(%esp)
c00239d6:	e8 e2 f3 ff ff       	call   c0022dbd <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c00239db:	01 db                	add    %ebx,%ebx
c00239dd:	81 fb ff 07 00 00    	cmp    $0x7ff,%ebx
c00239e3:	76 86                	jbe    c002396b <malloc_init+0x24>
c00239e5:	eb 36                	jmp    c0023a1d <malloc_init+0xd6>
      d->block_size = block_size;
c00239e7:	c7 80 00 75 03 c0 10 	movl   $0x10,-0x3ffc8b00(%eax)
c00239ee:	00 00 00 
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c00239f1:	c7 43 04 ff 00 00 00 	movl   $0xff,0x4(%ebx)
      list_init (&d->free_list);
c00239f8:	8d 43 08             	lea    0x8(%ebx),%eax
c00239fb:	89 04 24             	mov    %eax,(%esp)
c00239fe:	e8 4d 50 00 00       	call   c0028a50 <list_init>
      lock_init (&d->lock);
c0023a03:	83 c3 18             	add    $0x18,%ebx
c0023a06:	89 1c 24             	mov    %ebx,(%esp)
c0023a09:	e8 af f3 ff ff       	call   c0022dbd <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c0023a0e:	bb 20 00 00 00       	mov    $0x20,%ebx
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0023a13:	bf f4 0f 00 00       	mov    $0xff4,%edi
c0023a18:	e9 4e ff ff ff       	jmp    c002396b <malloc_init+0x24>
}
c0023a1d:	83 c4 20             	add    $0x20,%esp
c0023a20:	5b                   	pop    %ebx
c0023a21:	5e                   	pop    %esi
c0023a22:	5f                   	pop    %edi
c0023a23:	c3                   	ret    

c0023a24 <malloc>:
{
c0023a24:	55                   	push   %ebp
c0023a25:	57                   	push   %edi
c0023a26:	56                   	push   %esi
c0023a27:	53                   	push   %ebx
c0023a28:	83 ec 1c             	sub    $0x1c,%esp
c0023a2b:	8b 54 24 30          	mov    0x30(%esp),%edx
  if (size == 0)
c0023a2f:	85 d2                	test   %edx,%edx
c0023a31:	0f 84 15 01 00 00    	je     c0023b4c <malloc+0x128>
  for (d = descs; d < descs + desc_cnt; d++)
c0023a37:	6b 05 e0 74 03 c0 3c 	imul   $0x3c,0xc00374e0,%eax
c0023a3e:	05 00 75 03 c0       	add    $0xc0037500,%eax
c0023a43:	3d 00 75 03 c0       	cmp    $0xc0037500,%eax
c0023a48:	76 1c                	jbe    c0023a66 <malloc+0x42>
    if (d->block_size >= size)
c0023a4a:	3b 15 00 75 03 c0    	cmp    0xc0037500,%edx
c0023a50:	76 1b                	jbe    c0023a6d <malloc+0x49>
c0023a52:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c0023a57:	eb 04                	jmp    c0023a5d <malloc+0x39>
c0023a59:	3b 13                	cmp    (%ebx),%edx
c0023a5b:	76 15                	jbe    c0023a72 <malloc+0x4e>
  for (d = descs; d < descs + desc_cnt; d++)
c0023a5d:	83 c3 3c             	add    $0x3c,%ebx
c0023a60:	39 c3                	cmp    %eax,%ebx
c0023a62:	72 f5                	jb     c0023a59 <malloc+0x35>
c0023a64:	eb 0c                	jmp    c0023a72 <malloc+0x4e>
c0023a66:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c0023a6b:	eb 05                	jmp    c0023a72 <malloc+0x4e>
    if (d->block_size >= size)
c0023a6d:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
  if (d == descs + desc_cnt) 
c0023a72:	39 d8                	cmp    %ebx,%eax
c0023a74:	75 39                	jne    c0023aaf <malloc+0x8b>
      size_t page_cnt = DIV_ROUND_UP (size + sizeof *a, PGSIZE);
c0023a76:	8d 9a 0b 10 00 00    	lea    0x100b(%edx),%ebx
c0023a7c:	c1 eb 0c             	shr    $0xc,%ebx
      a = palloc_get_multiple (0, page_cnt);
c0023a7f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023a83:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0023a8a:	e8 cb fa ff ff       	call   c002355a <palloc_get_multiple>
      if (a == NULL)
c0023a8f:	85 c0                	test   %eax,%eax
c0023a91:	0f 84 bc 00 00 00    	je     c0023b53 <malloc+0x12f>
      a->magic = ARENA_MAGIC;
c0023a97:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = NULL;
c0023a9d:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
      a->free_cnt = page_cnt;
c0023aa4:	89 58 08             	mov    %ebx,0x8(%eax)
      return a + 1;
c0023aa7:	83 c0 0c             	add    $0xc,%eax
c0023aaa:	e9 a9 00 00 00       	jmp    c0023b58 <malloc+0x134>
  lock_acquire (&d->lock);
c0023aaf:	8d 43 18             	lea    0x18(%ebx),%eax
c0023ab2:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0023ab6:	89 04 24             	mov    %eax,(%esp)
c0023ab9:	e8 9c f3 ff ff       	call   c0022e5a <lock_acquire>
  if (list_empty (&d->free_list))
c0023abe:	8d 7b 08             	lea    0x8(%ebx),%edi
c0023ac1:	89 3c 24             	mov    %edi,(%esp)
c0023ac4:	e8 bd 55 00 00       	call   c0029086 <list_empty>
c0023ac9:	84 c0                	test   %al,%al
c0023acb:	74 5c                	je     c0023b29 <malloc+0x105>
      a = palloc_get_page (0);
c0023acd:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0023ad4:	e8 4d fb ff ff       	call   c0023626 <palloc_get_page>
c0023ad9:	89 c5                	mov    %eax,%ebp
      if (a == NULL) 
c0023adb:	85 c0                	test   %eax,%eax
c0023add:	75 13                	jne    c0023af2 <malloc+0xce>
          lock_release (&d->lock);
c0023adf:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0023ae3:	89 04 24             	mov    %eax,(%esp)
c0023ae6:	e8 39 f5 ff ff       	call   c0023024 <lock_release>
          return NULL; 
c0023aeb:	b8 00 00 00 00       	mov    $0x0,%eax
c0023af0:	eb 66                	jmp    c0023b58 <malloc+0x134>
      a->magic = ARENA_MAGIC;
c0023af2:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = d;
c0023af8:	89 58 04             	mov    %ebx,0x4(%eax)
      a->free_cnt = d->blocks_per_arena;
c0023afb:	8b 43 04             	mov    0x4(%ebx),%eax
c0023afe:	89 45 08             	mov    %eax,0x8(%ebp)
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023b01:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0023b05:	74 22                	je     c0023b29 <malloc+0x105>
c0023b07:	be 00 00 00 00       	mov    $0x0,%esi
          struct block *b = arena_to_block (a, i);
c0023b0c:	89 f2                	mov    %esi,%edx
c0023b0e:	89 e8                	mov    %ebp,%eax
c0023b10:	e8 9b fc ff ff       	call   c00237b0 <arena_to_block>
          list_push_back (&d->free_list, &b->free_elem);
c0023b15:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023b19:	89 3c 24             	mov    %edi,(%esp)
c0023b1c:	e8 b0 54 00 00       	call   c0028fd1 <list_push_back>
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023b21:	83 c6 01             	add    $0x1,%esi
c0023b24:	39 73 04             	cmp    %esi,0x4(%ebx)
c0023b27:	77 e3                	ja     c0023b0c <malloc+0xe8>
  b = list_entry (list_pop_front (&d->free_list), struct block, free_elem);
c0023b29:	89 3c 24             	mov    %edi,(%esp)
c0023b2c:	e8 c3 55 00 00       	call   c00290f4 <list_pop_front>
c0023b31:	89 c3                	mov    %eax,%ebx
  a = block_to_arena (b);
c0023b33:	e8 1e fd ff ff       	call   c0023856 <block_to_arena>
  a->free_cnt--;
c0023b38:	83 68 08 01          	subl   $0x1,0x8(%eax)
  lock_release (&d->lock);
c0023b3c:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0023b40:	89 04 24             	mov    %eax,(%esp)
c0023b43:	e8 dc f4 ff ff       	call   c0023024 <lock_release>
  return b;
c0023b48:	89 d8                	mov    %ebx,%eax
c0023b4a:	eb 0c                	jmp    c0023b58 <malloc+0x134>
    return NULL;
c0023b4c:	b8 00 00 00 00       	mov    $0x0,%eax
c0023b51:	eb 05                	jmp    c0023b58 <malloc+0x134>
        return NULL;
c0023b53:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023b58:	83 c4 1c             	add    $0x1c,%esp
c0023b5b:	5b                   	pop    %ebx
c0023b5c:	5e                   	pop    %esi
c0023b5d:	5f                   	pop    %edi
c0023b5e:	5d                   	pop    %ebp
c0023b5f:	c3                   	ret    

c0023b60 <calloc>:
{
c0023b60:	56                   	push   %esi
c0023b61:	53                   	push   %ebx
c0023b62:	83 ec 14             	sub    $0x14,%esp
c0023b65:	8b 54 24 20          	mov    0x20(%esp),%edx
c0023b69:	8b 44 24 24          	mov    0x24(%esp),%eax
  size = a * b;
c0023b6d:	89 d3                	mov    %edx,%ebx
c0023b6f:	0f af d8             	imul   %eax,%ebx
  if (size < a || size < b)
c0023b72:	39 c3                	cmp    %eax,%ebx
c0023b74:	72 2a                	jb     c0023ba0 <calloc+0x40>
c0023b76:	39 d3                	cmp    %edx,%ebx
c0023b78:	72 26                	jb     c0023ba0 <calloc+0x40>
  p = malloc (size);
c0023b7a:	89 1c 24             	mov    %ebx,(%esp)
c0023b7d:	e8 a2 fe ff ff       	call   c0023a24 <malloc>
c0023b82:	89 c6                	mov    %eax,%esi
  if (p != NULL)
c0023b84:	85 f6                	test   %esi,%esi
c0023b86:	74 1d                	je     c0023ba5 <calloc+0x45>
    memset (p, 0, size);
c0023b88:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023b8c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023b93:	00 
c0023b94:	89 34 24             	mov    %esi,(%esp)
c0023b97:	e8 a5 42 00 00       	call   c0027e41 <memset>
  return p;
c0023b9c:	89 f0                	mov    %esi,%eax
c0023b9e:	eb 05                	jmp    c0023ba5 <calloc+0x45>
    return NULL;
c0023ba0:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023ba5:	83 c4 14             	add    $0x14,%esp
c0023ba8:	5b                   	pop    %ebx
c0023ba9:	5e                   	pop    %esi
c0023baa:	c3                   	ret    

c0023bab <free>:
{
c0023bab:	55                   	push   %ebp
c0023bac:	57                   	push   %edi
c0023bad:	56                   	push   %esi
c0023bae:	53                   	push   %ebx
c0023baf:	83 ec 2c             	sub    $0x2c,%esp
c0023bb2:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  if (p != NULL)
c0023bb6:	85 db                	test   %ebx,%ebx
c0023bb8:	0f 84 ca 00 00 00    	je     c0023c88 <free+0xdd>
      struct arena *a = block_to_arena (b);
c0023bbe:	89 d8                	mov    %ebx,%eax
c0023bc0:	e8 91 fc ff ff       	call   c0023856 <block_to_arena>
c0023bc5:	89 c7                	mov    %eax,%edi
      struct desc *d = a->desc;
c0023bc7:	8b 70 04             	mov    0x4(%eax),%esi
      if (d != NULL) 
c0023bca:	85 f6                	test   %esi,%esi
c0023bcc:	0f 84 a7 00 00 00    	je     c0023c79 <free+0xce>
          memset (b, 0xcc, d->block_size);
c0023bd2:	8b 06                	mov    (%esi),%eax
c0023bd4:	89 44 24 08          	mov    %eax,0x8(%esp)
c0023bd8:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c0023bdf:	00 
c0023be0:	89 1c 24             	mov    %ebx,(%esp)
c0023be3:	e8 59 42 00 00       	call   c0027e41 <memset>
          lock_acquire (&d->lock);
c0023be8:	8d 6e 18             	lea    0x18(%esi),%ebp
c0023beb:	89 2c 24             	mov    %ebp,(%esp)
c0023bee:	e8 67 f2 ff ff       	call   c0022e5a <lock_acquire>
          list_push_front (&d->free_list, &b->free_elem);
c0023bf3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023bf7:	8d 46 08             	lea    0x8(%esi),%eax
c0023bfa:	89 04 24             	mov    %eax,(%esp)
c0023bfd:	e8 ac 53 00 00       	call   c0028fae <list_push_front>
          if (++a->free_cnt >= d->blocks_per_arena) 
c0023c02:	8b 47 08             	mov    0x8(%edi),%eax
c0023c05:	83 c0 01             	add    $0x1,%eax
c0023c08:	89 47 08             	mov    %eax,0x8(%edi)
c0023c0b:	8b 56 04             	mov    0x4(%esi),%edx
c0023c0e:	39 d0                	cmp    %edx,%eax
c0023c10:	72 5d                	jb     c0023c6f <free+0xc4>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023c12:	39 d0                	cmp    %edx,%eax
c0023c14:	75 0c                	jne    c0023c22 <free+0x77>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023c16:	bb 00 00 00 00       	mov    $0x0,%ebx
c0023c1b:	85 c0                	test   %eax,%eax
c0023c1d:	75 2f                	jne    c0023c4e <free+0xa3>
c0023c1f:	90                   	nop
c0023c20:	eb 45                	jmp    c0023c67 <free+0xbc>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023c22:	c7 44 24 10 80 ec 02 	movl   $0xc002ec80,0x10(%esp)
c0023c29:	c0 
c0023c2a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023c31:	c0 
c0023c32:	c7 44 24 08 a2 d2 02 	movl   $0xc002d2a2,0x8(%esp)
c0023c39:	c0 
c0023c3a:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0023c41:	00 
c0023c42:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c0023c49:	e8 35 4d 00 00       	call   c0028983 <debug_panic>
                  struct block *b = arena_to_block (a, i);
c0023c4e:	89 da                	mov    %ebx,%edx
c0023c50:	89 f8                	mov    %edi,%eax
c0023c52:	e8 59 fb ff ff       	call   c00237b0 <arena_to_block>
                  list_remove (&b->free_elem);
c0023c57:	89 04 24             	mov    %eax,(%esp)
c0023c5a:	e8 95 53 00 00       	call   c0028ff4 <list_remove>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023c5f:	83 c3 01             	add    $0x1,%ebx
c0023c62:	39 5e 04             	cmp    %ebx,0x4(%esi)
c0023c65:	77 e7                	ja     c0023c4e <free+0xa3>
              palloc_free_page (a);
c0023c67:	89 3c 24             	mov    %edi,(%esp)
c0023c6a:	e8 21 fb ff ff       	call   c0023790 <palloc_free_page>
          lock_release (&d->lock);
c0023c6f:	89 2c 24             	mov    %ebp,(%esp)
c0023c72:	e8 ad f3 ff ff       	call   c0023024 <lock_release>
c0023c77:	eb 0f                	jmp    c0023c88 <free+0xdd>
          palloc_free_multiple (a, a->free_cnt);
c0023c79:	8b 40 08             	mov    0x8(%eax),%eax
c0023c7c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023c80:	89 3c 24             	mov    %edi,(%esp)
c0023c83:	e8 b9 f9 ff ff       	call   c0023641 <palloc_free_multiple>
}
c0023c88:	83 c4 2c             	add    $0x2c,%esp
c0023c8b:	5b                   	pop    %ebx
c0023c8c:	5e                   	pop    %esi
c0023c8d:	5f                   	pop    %edi
c0023c8e:	5d                   	pop    %ebp
c0023c8f:	c3                   	ret    

c0023c90 <realloc>:
{
c0023c90:	57                   	push   %edi
c0023c91:	56                   	push   %esi
c0023c92:	53                   	push   %ebx
c0023c93:	83 ec 10             	sub    $0x10,%esp
c0023c96:	8b 7c 24 20          	mov    0x20(%esp),%edi
c0023c9a:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (new_size == 0) 
c0023c9e:	85 db                	test   %ebx,%ebx
c0023ca0:	75 0f                	jne    c0023cb1 <realloc+0x21>
      free (old_block);
c0023ca2:	89 3c 24             	mov    %edi,(%esp)
c0023ca5:	e8 01 ff ff ff       	call   c0023bab <free>
      return NULL;
c0023caa:	b8 00 00 00 00       	mov    $0x0,%eax
c0023caf:	eb 57                	jmp    c0023d08 <realloc+0x78>
      void *new_block = malloc (new_size);
c0023cb1:	89 1c 24             	mov    %ebx,(%esp)
c0023cb4:	e8 6b fd ff ff       	call   c0023a24 <malloc>
c0023cb9:	89 c6                	mov    %eax,%esi
      if (old_block != NULL && new_block != NULL)
c0023cbb:	85 c0                	test   %eax,%eax
c0023cbd:	74 47                	je     c0023d06 <realloc+0x76>
c0023cbf:	85 ff                	test   %edi,%edi
c0023cc1:	74 43                	je     c0023d06 <realloc+0x76>
  struct arena *a = block_to_arena (b);
c0023cc3:	89 f8                	mov    %edi,%eax
c0023cc5:	e8 8c fb ff ff       	call   c0023856 <block_to_arena>
  struct desc *d = a->desc;
c0023cca:	8b 50 04             	mov    0x4(%eax),%edx
  return d != NULL ? d->block_size : PGSIZE * a->free_cnt - pg_ofs (block);
c0023ccd:	85 d2                	test   %edx,%edx
c0023ccf:	74 04                	je     c0023cd5 <realloc+0x45>
c0023cd1:	8b 02                	mov    (%edx),%eax
c0023cd3:	eb 10                	jmp    c0023ce5 <realloc+0x55>
c0023cd5:	8b 40 08             	mov    0x8(%eax),%eax
c0023cd8:	c1 e0 0c             	shl    $0xc,%eax
c0023cdb:	89 fa                	mov    %edi,%edx
c0023cdd:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
c0023ce3:	29 d0                	sub    %edx,%eax
          size_t min_size = new_size < old_size ? new_size : old_size;
c0023ce5:	39 d8                	cmp    %ebx,%eax
c0023ce7:	0f 46 d8             	cmovbe %eax,%ebx
          memcpy (new_block, old_block, min_size);
c0023cea:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023cee:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023cf2:	89 34 24             	mov    %esi,(%esp)
c0023cf5:	e8 66 3b 00 00       	call   c0027860 <memcpy>
          free (old_block);
c0023cfa:	89 3c 24             	mov    %edi,(%esp)
c0023cfd:	e8 a9 fe ff ff       	call   c0023bab <free>
      return new_block;
c0023d02:	89 f0                	mov    %esi,%eax
c0023d04:	eb 02                	jmp    c0023d08 <realloc+0x78>
c0023d06:	89 f0                	mov    %esi,%eax
}
c0023d08:	83 c4 10             	add    $0x10,%esp
c0023d0b:	5b                   	pop    %ebx
c0023d0c:	5e                   	pop    %esi
c0023d0d:	5f                   	pop    %edi
c0023d0e:	c3                   	ret    

c0023d0f <pit_configure_channel>:
     - Other modes are less useful.

   FREQUENCY is the number of periods per second, in Hz. */
void
pit_configure_channel (int channel, int mode, int frequency)
{
c0023d0f:	57                   	push   %edi
c0023d10:	56                   	push   %esi
c0023d11:	53                   	push   %ebx
c0023d12:	83 ec 20             	sub    $0x20,%esp
c0023d15:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0023d19:	8b 7c 24 34          	mov    0x34(%esp),%edi
c0023d1d:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  uint16_t count;
  enum intr_level old_level;

  ASSERT (channel == 0 || channel == 2);
c0023d21:	f7 c3 fd ff ff ff    	test   $0xfffffffd,%ebx
c0023d27:	74 2c                	je     c0023d55 <pit_configure_channel+0x46>
c0023d29:	c7 44 24 10 a3 ec 02 	movl   $0xc002eca3,0x10(%esp)
c0023d30:	c0 
c0023d31:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023d38:	c0 
c0023d39:	c7 44 24 08 d1 d2 02 	movl   $0xc002d2d1,0x8(%esp)
c0023d40:	c0 
c0023d41:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
c0023d48:	00 
c0023d49:	c7 04 24 c0 ec 02 c0 	movl   $0xc002ecc0,(%esp)
c0023d50:	e8 2e 4c 00 00       	call   c0028983 <debug_panic>
  ASSERT (mode == 2 || mode == 3);
c0023d55:	8d 47 fe             	lea    -0x2(%edi),%eax
c0023d58:	83 f8 01             	cmp    $0x1,%eax
c0023d5b:	76 2c                	jbe    c0023d89 <pit_configure_channel+0x7a>
c0023d5d:	c7 44 24 10 d4 ec 02 	movl   $0xc002ecd4,0x10(%esp)
c0023d64:	c0 
c0023d65:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023d6c:	c0 
c0023d6d:	c7 44 24 08 d1 d2 02 	movl   $0xc002d2d1,0x8(%esp)
c0023d74:	c0 
c0023d75:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c0023d7c:	00 
c0023d7d:	c7 04 24 c0 ec 02 c0 	movl   $0xc002ecc0,(%esp)
c0023d84:	e8 fa 4b 00 00       	call   c0028983 <debug_panic>
    {
      /* Frequency is too low: the quotient would overflow the
         16-bit counter.  Force it to 0, which the PIT treats as
         65536, the highest possible count.  This yields a 18.2
         Hz timer, approximately. */
      count = 0;
c0023d89:	be 00 00 00 00       	mov    $0x0,%esi
  if (frequency < 19)
c0023d8e:	83 f9 12             	cmp    $0x12,%ecx
c0023d91:	7e 20                	jle    c0023db3 <pit_configure_channel+0xa4>
      /* Frequency is too high: the quotient would underflow to
         0, which the PIT would interpret as 65536.  A count of 1
         is illegal in mode 2, so we force it to 2, which yields
         a 596.590 kHz timer, approximately.  (This timer rate is
         probably too fast to be useful anyhow.) */
      count = 2;
c0023d93:	be 02 00 00 00       	mov    $0x2,%esi
  else if (frequency > PIT_HZ)
c0023d98:	81 f9 dc 34 12 00    	cmp    $0x1234dc,%ecx
c0023d9e:	7f 13                	jg     c0023db3 <pit_configure_channel+0xa4>
    }
  else
    count = (PIT_HZ + frequency / 2) / frequency;
c0023da0:	89 c8                	mov    %ecx,%eax
c0023da2:	c1 e8 1f             	shr    $0x1f,%eax
c0023da5:	01 c8                	add    %ecx,%eax
c0023da7:	d1 f8                	sar    %eax
c0023da9:	05 dc 34 12 00       	add    $0x1234dc,%eax
c0023dae:	99                   	cltd   
c0023daf:	f7 f9                	idiv   %ecx
c0023db1:	89 c6                	mov    %eax,%esi

  /* Configure the PIT mode and load its counters. */
  old_level = intr_disable ();
c0023db3:	e8 07 dc ff ff       	call   c00219bf <intr_disable>
c0023db8:	89 c1                	mov    %eax,%ecx
  outb (PIT_PORT_CONTROL, (channel << 6) | 0x30 | (mode << 1));
c0023dba:	8d 04 3f             	lea    (%edi,%edi,1),%eax
c0023dbd:	83 c8 30             	or     $0x30,%eax
c0023dc0:	89 da                	mov    %ebx,%edx
c0023dc2:	c1 e2 06             	shl    $0x6,%edx
c0023dc5:	09 d0                	or     %edx,%eax
c0023dc7:	e6 43                	out    %al,$0x43
  outb (PIT_PORT_COUNTER (channel), count);
c0023dc9:	8d 53 40             	lea    0x40(%ebx),%edx
c0023dcc:	89 f0                	mov    %esi,%eax
c0023dce:	ee                   	out    %al,(%dx)
  outb (PIT_PORT_COUNTER (channel), count >> 8);
c0023dcf:	89 f0                	mov    %esi,%eax
c0023dd1:	66 c1 e8 08          	shr    $0x8,%ax
c0023dd5:	ee                   	out    %al,(%dx)
  intr_set_level (old_level);
c0023dd6:	89 0c 24             	mov    %ecx,(%esp)
c0023dd9:	e8 e8 db ff ff       	call   c00219c6 <intr_set_level>
}
c0023dde:	83 c4 20             	add    $0x20,%esp
c0023de1:	5b                   	pop    %ebx
c0023de2:	5e                   	pop    %esi
c0023de3:	5f                   	pop    %edi
c0023de4:	c3                   	ret    
c0023de5:	90                   	nop
c0023de6:	90                   	nop
c0023de7:	90                   	nop
c0023de8:	90                   	nop
c0023de9:	90                   	nop
c0023dea:	90                   	nop
c0023deb:	90                   	nop
c0023dec:	90                   	nop
c0023ded:	90                   	nop
c0023dee:	90                   	nop
c0023def:	90                   	nop

c0023df0 <compareSleep>:
        return true;
    }
    //then check if the wakeup times are equal
    else if (tPointer1->wakeup == tPointer1->wakeup) {
        //if they are, then comapare using priority
        if (tPointer1->priority > tPointer2->priority) {
c0023df0:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023df4:	8b 54 24 04          	mov    0x4(%esp),%edx
c0023df8:	8b 40 f4             	mov    -0xc(%eax),%eax
c0023dfb:	39 42 f4             	cmp    %eax,-0xc(%edx)
c0023dfe:	0f 9f c0             	setg   %al
        }
    }
    //if all tests fail, return false
    return false;

}
c0023e01:	c3                   	ret    

c0023e02 <busy_wait>:
   affect timings, so that if this function was inlined
   differently in different places the results would be difficult
   to predict. */
static void NO_INLINE
busy_wait (int64_t loops) 
{
c0023e02:	53                   	push   %ebx
  while (loops-- > 0)
c0023e03:	89 c1                	mov    %eax,%ecx
c0023e05:	89 d3                	mov    %edx,%ebx
c0023e07:	83 c1 ff             	add    $0xffffffff,%ecx
c0023e0a:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023e0d:	85 d2                	test   %edx,%edx
c0023e0f:	78 18                	js     c0023e29 <busy_wait+0x27>
c0023e11:	85 d2                	test   %edx,%edx
c0023e13:	7f 05                	jg     c0023e1a <busy_wait+0x18>
c0023e15:	83 f8 00             	cmp    $0x0,%eax
c0023e18:	76 0f                	jbe    c0023e29 <busy_wait+0x27>
c0023e1a:	83 c1 ff             	add    $0xffffffff,%ecx
c0023e1d:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023e20:	89 c8                	mov    %ecx,%eax
c0023e22:	21 d8                	and    %ebx,%eax
c0023e24:	83 f8 ff             	cmp    $0xffffffff,%eax
c0023e27:	75 f1                	jne    c0023e1a <busy_wait+0x18>
    barrier ();
}
c0023e29:	5b                   	pop    %ebx
c0023e2a:	c3                   	ret    

c0023e2b <too_many_loops>:
{
c0023e2b:	55                   	push   %ebp
c0023e2c:	57                   	push   %edi
c0023e2d:	56                   	push   %esi
c0023e2e:	53                   	push   %ebx
c0023e2f:	83 ec 04             	sub    $0x4,%esp
  int64_t start = ticks;
c0023e32:	8b 2d 70 77 03 c0    	mov    0xc0037770,%ebp
c0023e38:	8b 3d 74 77 03 c0    	mov    0xc0037774,%edi
  while (ticks == start)
c0023e3e:	8b 35 70 77 03 c0    	mov    0xc0037770,%esi
c0023e44:	8b 1d 74 77 03 c0    	mov    0xc0037774,%ebx
c0023e4a:	89 d9                	mov    %ebx,%ecx
c0023e4c:	31 f9                	xor    %edi,%ecx
c0023e4e:	89 f2                	mov    %esi,%edx
c0023e50:	31 ea                	xor    %ebp,%edx
c0023e52:	09 d1                	or     %edx,%ecx
c0023e54:	74 e8                	je     c0023e3e <too_many_loops+0x13>
  busy_wait (loops);
c0023e56:	ba 00 00 00 00       	mov    $0x0,%edx
c0023e5b:	e8 a2 ff ff ff       	call   c0023e02 <busy_wait>
  return start != ticks;
c0023e60:	33 35 70 77 03 c0    	xor    0xc0037770,%esi
c0023e66:	33 1d 74 77 03 c0    	xor    0xc0037774,%ebx
c0023e6c:	09 de                	or     %ebx,%esi
c0023e6e:	0f 95 c0             	setne  %al
}
c0023e71:	83 c4 04             	add    $0x4,%esp
c0023e74:	5b                   	pop    %ebx
c0023e75:	5e                   	pop    %esi
c0023e76:	5f                   	pop    %edi
c0023e77:	5d                   	pop    %ebp
c0023e78:	c3                   	ret    

c0023e79 <timer_interrupt>:
{
c0023e79:	56                   	push   %esi
c0023e7a:	53                   	push   %ebx
c0023e7b:	83 ec 14             	sub    $0x14,%esp
  ticks++;
c0023e7e:	83 05 70 77 03 c0 01 	addl   $0x1,0xc0037770
c0023e85:	83 15 74 77 03 c0 00 	adcl   $0x0,0xc0037774
  struct list_elem *e = list_begin(&sleep_list);
c0023e8c:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023e93:	e8 09 4c 00 00       	call   c0028aa1 <list_begin>
c0023e98:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023e9a:	eb 39                	jmp    c0023ed5 <timer_interrupt+0x5c>
      if(ticks >= t->wakeup)
c0023e9c:	8b 53 0c             	mov    0xc(%ebx),%edx
c0023e9f:	8b 43 10             	mov    0x10(%ebx),%eax
c0023ea2:	3b 05 74 77 03 c0    	cmp    0xc0037774,%eax
c0023ea8:	7f 21                	jg     c0023ecb <timer_interrupt+0x52>
c0023eaa:	7c 08                	jl     c0023eb4 <timer_interrupt+0x3b>
c0023eac:	3b 15 70 77 03 c0    	cmp    0xc0037770,%edx
c0023eb2:	77 17                	ja     c0023ecb <timer_interrupt+0x52>
          e = list_remove(&t->elem);
c0023eb4:	8d 73 d8             	lea    -0x28(%ebx),%esi
c0023eb7:	89 1c 24             	mov    %ebx,(%esp)
c0023eba:	e8 35 51 00 00       	call   c0028ff4 <list_remove>
c0023ebf:	89 c3                	mov    %eax,%ebx
          thread_unblock(t);
c0023ec1:	89 34 24             	mov    %esi,(%esp)
c0023ec4:	e8 35 ce ff ff       	call   c0020cfe <thread_unblock>
c0023ec9:	eb 0a                	jmp    c0023ed5 <timer_interrupt+0x5c>
          e = list_next(e);
c0023ecb:	89 1c 24             	mov    %ebx,(%esp)
c0023ece:	e8 0c 4c 00 00       	call   c0028adf <list_next>
c0023ed3:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023ed5:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023edc:	e8 52 4c 00 00       	call   c0028b33 <list_end>
c0023ee1:	39 d8                	cmp    %ebx,%eax
c0023ee3:	75 b7                	jne    c0023e9c <timer_interrupt+0x23>
  if(thread_mlfqs)
c0023ee5:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0023eec:	0f 84 d7 00 00 00    	je     c0023fc9 <timer_interrupt+0x150>
    if(thread_current() != get_idle_thread())
c0023ef2:	e8 e2 ce ff ff       	call   c0020dd9 <thread_current>
c0023ef7:	89 c3                	mov    %eax,%ebx
c0023ef9:	e8 ff d1 ff ff       	call   c00210fd <get_idle_thread>
c0023efe:	39 c3                	cmp    %eax,%ebx
c0023f00:	74 22                	je     c0023f24 <timer_interrupt+0xab>
      thread_current()->recent_cpu = addXandN(thread_current()->recent_cpu,1);
c0023f02:	e8 d2 ce ff ff       	call   c0020dd9 <thread_current>
c0023f07:	89 c3                	mov    %eax,%ebx
c0023f09:	e8 cb ce ff ff       	call   c0020dd9 <thread_current>
c0023f0e:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023f15:	00 
c0023f16:	8b 40 58             	mov    0x58(%eax),%eax
c0023f19:	89 04 24             	mov    %eax,(%esp)
c0023f1c:	e8 d1 cb ff ff       	call   c0020af2 <addXandN>
c0023f21:	89 43 58             	mov    %eax,0x58(%ebx)
    if(ticks % TIMER_FREQ == 0)
c0023f24:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0023f2b:	00 
c0023f2c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023f33:	00 
c0023f34:	a1 70 77 03 c0       	mov    0xc0037770,%eax
c0023f39:	8b 15 74 77 03 c0    	mov    0xc0037774,%edx
c0023f3f:	89 04 24             	mov    %eax,(%esp)
c0023f42:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023f46:	e8 bb 43 00 00       	call   c0028306 <__moddi3>
c0023f4b:	09 c2                	or     %eax,%edx
c0023f4d:	75 58                	jne    c0023fa7 <timer_interrupt+0x12e>
       i = multXbyY(constant1,get_system_load_avg());
c0023f4f:	e8 99 d1 ff ff       	call   c00210ed <get_system_load_avg>
c0023f54:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023f58:	a1 cc 7b 03 c0       	mov    0xc0037bcc,%eax
c0023f5d:	89 04 24             	mov    %eax,(%esp)
c0023f60:	e8 b1 cb ff ff       	call   c0020b16 <multXbyY>
c0023f65:	a3 c8 7b 03 c0       	mov    %eax,0xc0037bc8
       j = multXbyN(constant2,get_ready_threads());
c0023f6a:	e8 3a d1 ff ff       	call   c00210a9 <get_ready_threads>
c0023f6f:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023f73:	a1 c4 7b 03 c0       	mov    0xc0037bc4,%eax
c0023f78:	89 04 24             	mov    %eax,(%esp)
c0023f7b:	e8 e4 cb ff ff       	call   c0020b64 <multXbyN>
c0023f80:	a3 c0 7b 03 c0       	mov    %eax,0xc0037bc0
       set_system_load_avg(i + j);
c0023f85:	03 05 c8 7b 03 c0    	add    0xc0037bc8,%eax
c0023f8b:	89 04 24             	mov    %eax,(%esp)
c0023f8e:	e8 60 d1 ff ff       	call   c00210f3 <set_system_load_avg>
       thread_foreach (calculate_recent_cpu, 0);
c0023f93:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023f9a:	00 
c0023f9b:	c7 04 24 86 0f 02 c0 	movl   $0xc0020f86,(%esp)
c0023fa2:	e8 13 cf ff ff       	call   c0020eba <thread_foreach>
    if(ticks % 4 == 0)
c0023fa7:	f6 05 70 77 03 c0 03 	testb  $0x3,0xc0037770
c0023fae:	75 19                	jne    c0023fc9 <timer_interrupt+0x150>
      thread_foreach (calculate_priority, 0);
c0023fb0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023fb7:	00 
c0023fb8:	c7 04 24 27 10 02 c0 	movl   $0xc0021027,(%esp)
c0023fbf:	e8 f6 ce ff ff       	call   c0020eba <thread_foreach>
      intr_yield_on_return ();
c0023fc4:	e8 60 dc ff ff       	call   c0021c29 <intr_yield_on_return>
  thread_tick ();
c0023fc9:	e8 86 ce ff ff       	call   c0020e54 <thread_tick>
}
c0023fce:	83 c4 14             	add    $0x14,%esp
c0023fd1:	5b                   	pop    %ebx
c0023fd2:	5e                   	pop    %esi
c0023fd3:	c3                   	ret    

c0023fd4 <real_time_delay>:
}

/* Busy-wait for approximately NUM/DENOM seconds. */
static void
real_time_delay (int64_t num, int32_t denom)
{
c0023fd4:	55                   	push   %ebp
c0023fd5:	57                   	push   %edi
c0023fd6:	56                   	push   %esi
c0023fd7:	53                   	push   %ebx
c0023fd8:	83 ec 2c             	sub    $0x2c,%esp
c0023fdb:	89 c7                	mov    %eax,%edi
c0023fdd:	89 d6                	mov    %edx,%esi
c0023fdf:	89 cb                	mov    %ecx,%ebx
  /* Scale the numerator and denominator down by 1000 to avoid
     the possibility of overflow. */
  ASSERT (denom % 1000 == 0);
c0023fe1:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c0023fe6:	89 c8                	mov    %ecx,%eax
c0023fe8:	f7 ea                	imul   %edx
c0023fea:	c1 fa 06             	sar    $0x6,%edx
c0023fed:	89 c8                	mov    %ecx,%eax
c0023fef:	c1 f8 1f             	sar    $0x1f,%eax
c0023ff2:	29 c2                	sub    %eax,%edx
c0023ff4:	69 d2 e8 03 00 00    	imul   $0x3e8,%edx,%edx
c0023ffa:	39 d1                	cmp    %edx,%ecx
c0023ffc:	74 2c                	je     c002402a <real_time_delay+0x56>
c0023ffe:	c7 44 24 10 eb ec 02 	movl   $0xc002eceb,0x10(%esp)
c0024005:	c0 
c0024006:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002400d:	c0 
c002400e:	c7 44 24 08 e7 d2 02 	movl   $0xc002d2e7,0x8(%esp)
c0024015:	c0 
c0024016:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
c002401d:	00 
c002401e:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c0024025:	e8 59 49 00 00       	call   c0028983 <debug_panic>
  busy_wait (loops_per_tick * num / 1000 * TIMER_FREQ / (denom / 1000)); 
c002402a:	a1 68 77 03 c0       	mov    0xc0037768,%eax
c002402f:	0f af f0             	imul   %eax,%esi
c0024032:	f7 e7                	mul    %edi
c0024034:	01 f2                	add    %esi,%edx
c0024036:	c7 44 24 08 e8 03 00 	movl   $0x3e8,0x8(%esp)
c002403d:	00 
c002403e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0024045:	00 
c0024046:	89 04 24             	mov    %eax,(%esp)
c0024049:	89 54 24 04          	mov    %edx,0x4(%esp)
c002404d:	e8 91 42 00 00       	call   c00282e3 <__divdi3>
c0024052:	6b ea 64             	imul   $0x64,%edx,%ebp
c0024055:	b9 64 00 00 00       	mov    $0x64,%ecx
c002405a:	f7 e1                	mul    %ecx
c002405c:	89 c6                	mov    %eax,%esi
c002405e:	89 d7                	mov    %edx,%edi
c0024060:	01 ef                	add    %ebp,%edi
c0024062:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c0024067:	89 d8                	mov    %ebx,%eax
c0024069:	f7 ea                	imul   %edx
c002406b:	c1 fa 06             	sar    $0x6,%edx
c002406e:	c1 fb 1f             	sar    $0x1f,%ebx
c0024071:	29 da                	sub    %ebx,%edx
c0024073:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024077:	89 d0                	mov    %edx,%eax
c0024079:	c1 f8 1f             	sar    $0x1f,%eax
c002407c:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0024080:	89 34 24             	mov    %esi,(%esp)
c0024083:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0024087:	e8 57 42 00 00       	call   c00282e3 <__divdi3>
c002408c:	e8 71 fd ff ff       	call   c0023e02 <busy_wait>
c0024091:	83 c4 2c             	add    $0x2c,%esp
c0024094:	5b                   	pop    %ebx
c0024095:	5e                   	pop    %esi
c0024096:	5f                   	pop    %edi
c0024097:	5d                   	pop    %ebp
c0024098:	c3                   	ret    

c0024099 <timer_init>:
{
c0024099:	83 ec 1c             	sub    $0x1c,%esp
  pit_configure_channel (0, 2, TIMER_FREQ);
c002409c:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c00240a3:	00 
c00240a4:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
c00240ab:	00 
c00240ac:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c00240b3:	e8 57 fc ff ff       	call   c0023d0f <pit_configure_channel>
  intr_register_ext (0x20, timer_interrupt, "8254 Timer");
c00240b8:	c7 44 24 08 13 ed 02 	movl   $0xc002ed13,0x8(%esp)
c00240bf:	c0 
c00240c0:	c7 44 24 04 79 3e 02 	movl   $0xc0023e79,0x4(%esp)
c00240c7:	c0 
c00240c8:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c00240cf:	e8 8f da ff ff       	call   c0021b63 <intr_register_ext>
  list_init (&sleep_list);
c00240d4:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c00240db:	e8 70 49 00 00       	call   c0028a50 <list_init>
  constant1 = divXbyN(convertNtoFixedPoint(59),60);
c00240e0:	c7 04 24 3b 00 00 00 	movl   $0x3b,(%esp)
c00240e7:	e8 0d c8 ff ff       	call   c00208f9 <convertNtoFixedPoint>
c00240ec:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c00240f3:	00 
c00240f4:	89 04 24             	mov    %eax,(%esp)
c00240f7:	e8 bf ca ff ff       	call   c0020bbb <divXbyN>
c00240fc:	a3 cc 7b 03 c0       	mov    %eax,0xc0037bcc
  constant2 = divXbyN(convertNtoFixedPoint(1),60);
c0024101:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0024108:	e8 ec c7 ff ff       	call   c00208f9 <convertNtoFixedPoint>
c002410d:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c0024114:	00 
c0024115:	89 04 24             	mov    %eax,(%esp)
c0024118:	e8 9e ca ff ff       	call   c0020bbb <divXbyN>
c002411d:	a3 c4 7b 03 c0       	mov    %eax,0xc0037bc4
}
c0024122:	83 c4 1c             	add    $0x1c,%esp
c0024125:	c3                   	ret    

c0024126 <timer_calibrate>:
{
c0024126:	57                   	push   %edi
c0024127:	56                   	push   %esi
c0024128:	53                   	push   %ebx
c0024129:	83 ec 20             	sub    $0x20,%esp
  ASSERT (intr_get_level () == INTR_ON);
c002412c:	e8 43 d8 ff ff       	call   c0021974 <intr_get_level>
c0024131:	83 f8 01             	cmp    $0x1,%eax
c0024134:	74 2c                	je     c0024162 <timer_calibrate+0x3c>
c0024136:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c002413d:	c0 
c002413e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024145:	c0 
c0024146:	c7 44 24 08 13 d3 02 	movl   $0xc002d313,0x8(%esp)
c002414d:	c0 
c002414e:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c0024155:	00 
c0024156:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c002415d:	e8 21 48 00 00       	call   c0028983 <debug_panic>
  printf ("Calibrating timer...  ");
c0024162:	c7 04 24 3b ed 02 c0 	movl   $0xc002ed3b,(%esp)
c0024169:	e8 c0 29 00 00       	call   c0026b2e <printf>
  loops_per_tick = 1u << 10;
c002416e:	c7 05 68 77 03 c0 00 	movl   $0x400,0xc0037768
c0024175:	04 00 00 
  while (!too_many_loops (loops_per_tick << 1)) 
c0024178:	eb 36                	jmp    c00241b0 <timer_calibrate+0x8a>
      loops_per_tick <<= 1;
c002417a:	89 1d 68 77 03 c0    	mov    %ebx,0xc0037768
      ASSERT (loops_per_tick != 0);
c0024180:	85 db                	test   %ebx,%ebx
c0024182:	75 2c                	jne    c00241b0 <timer_calibrate+0x8a>
c0024184:	c7 44 24 10 52 ed 02 	movl   $0xc002ed52,0x10(%esp)
c002418b:	c0 
c002418c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024193:	c0 
c0024194:	c7 44 24 08 13 d3 02 	movl   $0xc002d313,0x8(%esp)
c002419b:	c0 
c002419c:	c7 44 24 04 4e 00 00 	movl   $0x4e,0x4(%esp)
c00241a3:	00 
c00241a4:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c00241ab:	e8 d3 47 00 00       	call   c0028983 <debug_panic>
  while (!too_many_loops (loops_per_tick << 1)) 
c00241b0:	8b 35 68 77 03 c0    	mov    0xc0037768,%esi
c00241b6:	8d 1c 36             	lea    (%esi,%esi,1),%ebx
c00241b9:	89 d8                	mov    %ebx,%eax
c00241bb:	e8 6b fc ff ff       	call   c0023e2b <too_many_loops>
c00241c0:	84 c0                	test   %al,%al
c00241c2:	74 b6                	je     c002417a <timer_calibrate+0x54>
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c00241c4:	89 f3                	mov    %esi,%ebx
c00241c6:	d1 eb                	shr    %ebx
c00241c8:	89 f7                	mov    %esi,%edi
c00241ca:	c1 ef 0a             	shr    $0xa,%edi
c00241cd:	39 df                	cmp    %ebx,%edi
c00241cf:	74 19                	je     c00241ea <timer_calibrate+0xc4>
    if (!too_many_loops (high_bit | test_bit))
c00241d1:	89 d8                	mov    %ebx,%eax
c00241d3:	09 f0                	or     %esi,%eax
c00241d5:	e8 51 fc ff ff       	call   c0023e2b <too_many_loops>
c00241da:	84 c0                	test   %al,%al
c00241dc:	75 06                	jne    c00241e4 <timer_calibrate+0xbe>
      loops_per_tick |= test_bit;
c00241de:	09 1d 68 77 03 c0    	or     %ebx,0xc0037768
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c00241e4:	d1 eb                	shr    %ebx
c00241e6:	39 df                	cmp    %ebx,%edi
c00241e8:	75 e7                	jne    c00241d1 <timer_calibrate+0xab>
  printf ("%'"PRIu64" loops/s.\n", (uint64_t) loops_per_tick * TIMER_FREQ);
c00241ea:	b8 64 00 00 00       	mov    $0x64,%eax
c00241ef:	f7 25 68 77 03 c0    	mull   0xc0037768
c00241f5:	89 44 24 04          	mov    %eax,0x4(%esp)
c00241f9:	89 54 24 08          	mov    %edx,0x8(%esp)
c00241fd:	c7 04 24 66 ed 02 c0 	movl   $0xc002ed66,(%esp)
c0024204:	e8 25 29 00 00       	call   c0026b2e <printf>
}
c0024209:	83 c4 20             	add    $0x20,%esp
c002420c:	5b                   	pop    %ebx
c002420d:	5e                   	pop    %esi
c002420e:	5f                   	pop    %edi
c002420f:	c3                   	ret    

c0024210 <timer_ticks>:
{
c0024210:	56                   	push   %esi
c0024211:	53                   	push   %ebx
c0024212:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level = intr_disable ();
c0024215:	e8 a5 d7 ff ff       	call   c00219bf <intr_disable>
  int64_t t = ticks;
c002421a:	8b 15 70 77 03 c0    	mov    0xc0037770,%edx
c0024220:	8b 0d 74 77 03 c0    	mov    0xc0037774,%ecx
c0024226:	89 d3                	mov    %edx,%ebx
c0024228:	89 ce                	mov    %ecx,%esi
  intr_set_level (old_level);
c002422a:	89 04 24             	mov    %eax,(%esp)
c002422d:	e8 94 d7 ff ff       	call   c00219c6 <intr_set_level>
}
c0024232:	89 d8                	mov    %ebx,%eax
c0024234:	89 f2                	mov    %esi,%edx
c0024236:	83 c4 14             	add    $0x14,%esp
c0024239:	5b                   	pop    %ebx
c002423a:	5e                   	pop    %esi
c002423b:	c3                   	ret    

c002423c <timer_elapsed>:
{
c002423c:	57                   	push   %edi
c002423d:	56                   	push   %esi
c002423e:	83 ec 04             	sub    $0x4,%esp
c0024241:	8b 74 24 10          	mov    0x10(%esp),%esi
c0024245:	8b 7c 24 14          	mov    0x14(%esp),%edi
  return timer_ticks () - then;
c0024249:	e8 c2 ff ff ff       	call   c0024210 <timer_ticks>
c002424e:	29 f0                	sub    %esi,%eax
c0024250:	19 fa                	sbb    %edi,%edx
}
c0024252:	83 c4 04             	add    $0x4,%esp
c0024255:	5e                   	pop    %esi
c0024256:	5f                   	pop    %edi
c0024257:	c3                   	ret    

c0024258 <timer_sleep>:
{
c0024258:	57                   	push   %edi
c0024259:	56                   	push   %esi
c002425a:	53                   	push   %ebx
c002425b:	83 ec 20             	sub    $0x20,%esp
c002425e:	8b 74 24 30          	mov    0x30(%esp),%esi
c0024262:	8b 7c 24 34          	mov    0x34(%esp),%edi
    ASSERT (intr_get_level () == INTR_ON);
c0024266:	e8 09 d7 ff ff       	call   c0021974 <intr_get_level>
c002426b:	83 f8 01             	cmp    $0x1,%eax
c002426e:	74 2c                	je     c002429c <timer_sleep+0x44>
c0024270:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c0024277:	c0 
c0024278:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002427f:	c0 
c0024280:	c7 44 24 08 07 d3 02 	movl   $0xc002d307,0x8(%esp)
c0024287:	c0 
c0024288:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
c002428f:	00 
c0024290:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c0024297:	e8 e7 46 00 00       	call   c0028983 <debug_panic>
    struct thread *cur = thread_current ();
c002429c:	e8 38 cb ff ff       	call   c0020dd9 <thread_current>
c00242a1:	89 c3                	mov    %eax,%ebx
    cur->wakeup = timer_ticks () + ticks; //save the wakeup time of each thread as a struct attribute
c00242a3:	e8 68 ff ff ff       	call   c0024210 <timer_ticks>
c00242a8:	01 f0                	add    %esi,%eax
c00242aa:	11 fa                	adc    %edi,%edx
c00242ac:	89 43 34             	mov    %eax,0x34(%ebx)
c00242af:	89 53 38             	mov    %edx,0x38(%ebx)
    old_level = intr_disable ();
c00242b2:	e8 08 d7 ff ff       	call   c00219bf <intr_disable>
c00242b7:	89 c6                	mov    %eax,%esi
    list_insert_ordered(&sleep_list, &cur->elem, compareSleep, 0); //add each thread as a list elem to the sleep_list based on wakeup time
c00242b9:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00242c0:	00 
c00242c1:	c7 44 24 08 f0 3d 02 	movl   $0xc0023df0,0x8(%esp)
c00242c8:	c0 
c00242c9:	83 c3 28             	add    $0x28,%ebx
c00242cc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00242d0:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c00242d7:	e8 9a 51 00 00       	call   c0029476 <list_insert_ordered>
    thread_block(); //block the thread 
c00242dc:	e8 2e d0 ff ff       	call   c002130f <thread_block>
    intr_set_level (old_level); //set interrupts back to orginal status
c00242e1:	89 34 24             	mov    %esi,(%esp)
c00242e4:	e8 dd d6 ff ff       	call   c00219c6 <intr_set_level>
}
c00242e9:	83 c4 20             	add    $0x20,%esp
c00242ec:	5b                   	pop    %ebx
c00242ed:	5e                   	pop    %esi
c00242ee:	5f                   	pop    %edi
c00242ef:	c3                   	ret    

c00242f0 <real_time_sleep>:
{
c00242f0:	55                   	push   %ebp
c00242f1:	57                   	push   %edi
c00242f2:	56                   	push   %esi
c00242f3:	53                   	push   %ebx
c00242f4:	83 ec 2c             	sub    $0x2c,%esp
c00242f7:	89 c7                	mov    %eax,%edi
c00242f9:	89 d6                	mov    %edx,%esi
c00242fb:	89 cd                	mov    %ecx,%ebp
  int64_t ticks = num * TIMER_FREQ / denom;
c00242fd:	6b ca 64             	imul   $0x64,%edx,%ecx
c0024300:	b8 64 00 00 00       	mov    $0x64,%eax
c0024305:	f7 e7                	mul    %edi
c0024307:	01 ca                	add    %ecx,%edx
c0024309:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002430d:	89 e9                	mov    %ebp,%ecx
c002430f:	c1 f9 1f             	sar    $0x1f,%ecx
c0024312:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0024316:	89 04 24             	mov    %eax,(%esp)
c0024319:	89 54 24 04          	mov    %edx,0x4(%esp)
c002431d:	e8 c1 3f 00 00       	call   c00282e3 <__divdi3>
c0024322:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0024326:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_ON);
c0024328:	e8 47 d6 ff ff       	call   c0021974 <intr_get_level>
c002432d:	83 f8 01             	cmp    $0x1,%eax
c0024330:	74 2c                	je     c002435e <real_time_sleep+0x6e>
c0024332:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c0024339:	c0 
c002433a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024341:	c0 
c0024342:	c7 44 24 08 f7 d2 02 	movl   $0xc002d2f7,0x8(%esp)
c0024349:	c0 
c002434a:	c7 44 24 04 35 01 00 	movl   $0x135,0x4(%esp)
c0024351:	00 
c0024352:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c0024359:	e8 25 46 00 00       	call   c0028983 <debug_panic>
  if (ticks > 0)
c002435e:	85 db                	test   %ebx,%ebx
c0024360:	78 1d                	js     c002437f <real_time_sleep+0x8f>
c0024362:	85 db                	test   %ebx,%ebx
c0024364:	7f 07                	jg     c002436d <real_time_sleep+0x7d>
c0024366:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c002436b:	76 12                	jbe    c002437f <real_time_sleep+0x8f>
      timer_sleep (ticks); 
c002436d:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0024371:	89 04 24             	mov    %eax,(%esp)
c0024374:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024378:	e8 db fe ff ff       	call   c0024258 <timer_sleep>
c002437d:	eb 0b                	jmp    c002438a <real_time_sleep+0x9a>
      real_time_delay (num, denom); 
c002437f:	89 e9                	mov    %ebp,%ecx
c0024381:	89 f8                	mov    %edi,%eax
c0024383:	89 f2                	mov    %esi,%edx
c0024385:	e8 4a fc ff ff       	call   c0023fd4 <real_time_delay>
}
c002438a:	83 c4 2c             	add    $0x2c,%esp
c002438d:	5b                   	pop    %ebx
c002438e:	5e                   	pop    %esi
c002438f:	5f                   	pop    %edi
c0024390:	5d                   	pop    %ebp
c0024391:	c3                   	ret    

c0024392 <timer_msleep>:
{
c0024392:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ms, 1000);
c0024395:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002439a:	8b 44 24 10          	mov    0x10(%esp),%eax
c002439e:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243a2:	e8 49 ff ff ff       	call   c00242f0 <real_time_sleep>
}
c00243a7:	83 c4 0c             	add    $0xc,%esp
c00243aa:	c3                   	ret    

c00243ab <timer_usleep>:
{
c00243ab:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (us, 1000 * 1000);
c00243ae:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00243b3:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243b7:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243bb:	e8 30 ff ff ff       	call   c00242f0 <real_time_sleep>
}
c00243c0:	83 c4 0c             	add    $0xc,%esp
c00243c3:	c3                   	ret    

c00243c4 <timer_nsleep>:
{
c00243c4:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ns, 1000 * 1000 * 1000);
c00243c7:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c00243cc:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243d0:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243d4:	e8 17 ff ff ff       	call   c00242f0 <real_time_sleep>
}
c00243d9:	83 c4 0c             	add    $0xc,%esp
c00243dc:	c3                   	ret    

c00243dd <timer_mdelay>:
{
c00243dd:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ms, 1000);
c00243e0:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c00243e5:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243e9:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243ed:	e8 e2 fb ff ff       	call   c0023fd4 <real_time_delay>
}
c00243f2:	83 c4 0c             	add    $0xc,%esp
c00243f5:	c3                   	ret    

c00243f6 <timer_udelay>:
{
c00243f6:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (us, 1000 * 1000);
c00243f9:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00243fe:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024402:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024406:	e8 c9 fb ff ff       	call   c0023fd4 <real_time_delay>
}
c002440b:	83 c4 0c             	add    $0xc,%esp
c002440e:	c3                   	ret    

c002440f <timer_ndelay>:
{
c002440f:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ns, 1000 * 1000 * 1000);
c0024412:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c0024417:	8b 44 24 10          	mov    0x10(%esp),%eax
c002441b:	8b 54 24 14          	mov    0x14(%esp),%edx
c002441f:	e8 b0 fb ff ff       	call   c0023fd4 <real_time_delay>
}
c0024424:	83 c4 0c             	add    $0xc,%esp
c0024427:	c3                   	ret    

c0024428 <timer_print_stats>:
{
c0024428:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Timer: %"PRId64" ticks\n", timer_ticks ());
c002442b:	e8 e0 fd ff ff       	call   c0024210 <timer_ticks>
c0024430:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024434:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024438:	c7 04 24 76 ed 02 c0 	movl   $0xc002ed76,(%esp)
c002443f:	e8 ea 26 00 00       	call   c0026b2e <printf>
}
c0024444:	83 c4 1c             	add    $0x1c,%esp
c0024447:	c3                   	ret    
c0024448:	90                   	nop
c0024449:	90                   	nop
c002444a:	90                   	nop
c002444b:	90                   	nop
c002444c:	90                   	nop
c002444d:	90                   	nop
c002444e:	90                   	nop
c002444f:	90                   	nop

c0024450 <map_key>:
   If found, sets *C to the corresponding character and returns
   true.
   If not found, returns false and C is ignored. */
static bool
map_key (const struct keymap k[], unsigned scancode, uint8_t *c) 
{
c0024450:	55                   	push   %ebp
c0024451:	57                   	push   %edi
c0024452:	56                   	push   %esi
c0024453:	53                   	push   %ebx
c0024454:	83 ec 04             	sub    $0x4,%esp
c0024457:	89 c3                	mov    %eax,%ebx
c0024459:	89 0c 24             	mov    %ecx,(%esp)
  for (; k->first_scancode != 0; k++)
c002445c:	0f b6 08             	movzbl (%eax),%ecx
c002445f:	84 c9                	test   %cl,%cl
c0024461:	74 41                	je     c00244a4 <map_key+0x54>
    if (scancode >= k->first_scancode
        && scancode < k->first_scancode + strlen (k->chars)) 
c0024463:	b8 00 00 00 00       	mov    $0x0,%eax
    if (scancode >= k->first_scancode
c0024468:	0f b6 f1             	movzbl %cl,%esi
c002446b:	39 d6                	cmp    %edx,%esi
c002446d:	77 29                	ja     c0024498 <map_key+0x48>
        && scancode < k->first_scancode + strlen (k->chars)) 
c002446f:	8b 6b 04             	mov    0x4(%ebx),%ebp
c0024472:	89 ef                	mov    %ebp,%edi
c0024474:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0024479:	f2 ae                	repnz scas %es:(%edi),%al
c002447b:	f7 d1                	not    %ecx
c002447d:	8d 4c 0e ff          	lea    -0x1(%esi,%ecx,1),%ecx
c0024481:	39 ca                	cmp    %ecx,%edx
c0024483:	73 13                	jae    c0024498 <map_key+0x48>
      {
        *c = k->chars[scancode - k->first_scancode];
c0024485:	29 f2                	sub    %esi,%edx
c0024487:	0f b6 44 15 00       	movzbl 0x0(%ebp,%edx,1),%eax
c002448c:	8b 3c 24             	mov    (%esp),%edi
c002448f:	88 07                	mov    %al,(%edi)
        return true; 
c0024491:	b8 01 00 00 00       	mov    $0x1,%eax
c0024496:	eb 18                	jmp    c00244b0 <map_key+0x60>
  for (; k->first_scancode != 0; k++)
c0024498:	83 c3 08             	add    $0x8,%ebx
c002449b:	0f b6 0b             	movzbl (%ebx),%ecx
c002449e:	84 c9                	test   %cl,%cl
c00244a0:	75 c6                	jne    c0024468 <map_key+0x18>
c00244a2:	eb 07                	jmp    c00244ab <map_key+0x5b>
      }

  return false;
c00244a4:	b8 00 00 00 00       	mov    $0x0,%eax
c00244a9:	eb 05                	jmp    c00244b0 <map_key+0x60>
c00244ab:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00244b0:	83 c4 04             	add    $0x4,%esp
c00244b3:	5b                   	pop    %ebx
c00244b4:	5e                   	pop    %esi
c00244b5:	5f                   	pop    %edi
c00244b6:	5d                   	pop    %ebp
c00244b7:	c3                   	ret    

c00244b8 <keyboard_interrupt>:
{
c00244b8:	55                   	push   %ebp
c00244b9:	57                   	push   %edi
c00244ba:	56                   	push   %esi
c00244bb:	53                   	push   %ebx
c00244bc:	83 ec 2c             	sub    $0x2c,%esp
  bool shift = left_shift || right_shift;
c00244bf:	0f b6 15 85 77 03 c0 	movzbl 0xc0037785,%edx
c00244c6:	80 3d 86 77 03 c0 00 	cmpb   $0x0,0xc0037786
c00244cd:	b8 01 00 00 00       	mov    $0x1,%eax
c00244d2:	0f 45 d0             	cmovne %eax,%edx
  bool alt = left_alt || right_alt;
c00244d5:	0f b6 3d 83 77 03 c0 	movzbl 0xc0037783,%edi
c00244dc:	80 3d 84 77 03 c0 00 	cmpb   $0x0,0xc0037784
c00244e3:	0f 45 f8             	cmovne %eax,%edi
  bool ctrl = left_ctrl || right_ctrl;
c00244e6:	0f b6 2d 81 77 03 c0 	movzbl 0xc0037781,%ebp
c00244ed:	80 3d 82 77 03 c0 00 	cmpb   $0x0,0xc0037782
c00244f4:	0f 45 e8             	cmovne %eax,%ebp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00244f7:	e4 60                	in     $0x60,%al
  code = inb (DATA_REG);
c00244f9:	0f b6 d8             	movzbl %al,%ebx
  if (code == 0xe0)
c00244fc:	81 fb e0 00 00 00    	cmp    $0xe0,%ebx
c0024502:	75 08                	jne    c002450c <keyboard_interrupt+0x54>
c0024504:	e4 60                	in     $0x60,%al
    code = (code << 8) | inb (DATA_REG);
c0024506:	0f b6 d8             	movzbl %al,%ebx
c0024509:	80 cf e0             	or     $0xe0,%bh
  release = (code & 0x80) != 0;
c002450c:	89 de                	mov    %ebx,%esi
c002450e:	c1 ee 07             	shr    $0x7,%esi
c0024511:	83 e6 01             	and    $0x1,%esi
  code &= ~0x80u;
c0024514:	80 e3 7f             	and    $0x7f,%bl
  if (code == 0x3a) 
c0024517:	83 fb 3a             	cmp    $0x3a,%ebx
c002451a:	75 16                	jne    c0024532 <keyboard_interrupt+0x7a>
      if (!release)
c002451c:	89 f0                	mov    %esi,%eax
c002451e:	84 c0                	test   %al,%al
c0024520:	0f 85 1d 01 00 00    	jne    c0024643 <keyboard_interrupt+0x18b>
        caps_lock = !caps_lock;
c0024526:	80 35 80 77 03 c0 01 	xorb   $0x1,0xc0037780
c002452d:	e9 11 01 00 00       	jmp    c0024643 <keyboard_interrupt+0x18b>
  bool shift = left_shift || right_shift;
c0024532:	89 d0                	mov    %edx,%eax
c0024534:	83 e0 01             	and    $0x1,%eax
c0024537:	88 44 24 0f          	mov    %al,0xf(%esp)
  else if (map_key (invariant_keymap, code, &c)
c002453b:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002453f:	89 da                	mov    %ebx,%edx
c0024541:	b8 00 d4 02 c0       	mov    $0xc002d400,%eax
c0024546:	e8 05 ff ff ff       	call   c0024450 <map_key>
c002454b:	84 c0                	test   %al,%al
c002454d:	75 23                	jne    c0024572 <keyboard_interrupt+0xba>
           || (!shift && map_key (unshifted_keymap, code, &c))
c002454f:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0024554:	0f 85 c5 00 00 00    	jne    c002461f <keyboard_interrupt+0x167>
c002455a:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002455e:	89 da                	mov    %ebx,%edx
c0024560:	b8 c0 d3 02 c0       	mov    $0xc002d3c0,%eax
c0024565:	e8 e6 fe ff ff       	call   c0024450 <map_key>
c002456a:	84 c0                	test   %al,%al
c002456c:	0f 84 c5 00 00 00    	je     c0024637 <keyboard_interrupt+0x17f>
      if (!release) 
c0024572:	89 f0                	mov    %esi,%eax
c0024574:	84 c0                	test   %al,%al
c0024576:	0f 85 c7 00 00 00    	jne    c0024643 <keyboard_interrupt+0x18b>
          if (c == 0177 && ctrl && alt)
c002457c:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c0024581:	3c 7f                	cmp    $0x7f,%al
c0024583:	75 0f                	jne    c0024594 <keyboard_interrupt+0xdc>
c0024585:	21 fd                	and    %edi,%ebp
c0024587:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c002458d:	74 1b                	je     c00245aa <keyboard_interrupt+0xf2>
            shutdown_reboot ();
c002458f:	e8 06 1e 00 00       	call   c002639a <shutdown_reboot>
          if (ctrl && c >= 0x40 && c < 0x60) 
c0024594:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c002459a:	74 0e                	je     c00245aa <keyboard_interrupt+0xf2>
c002459c:	8d 50 c0             	lea    -0x40(%eax),%edx
c002459f:	80 fa 1f             	cmp    $0x1f,%dl
c00245a2:	77 06                	ja     c00245aa <keyboard_interrupt+0xf2>
              c -= 0x40; 
c00245a4:	88 54 24 1f          	mov    %dl,0x1f(%esp)
c00245a8:	eb 20                	jmp    c00245ca <keyboard_interrupt+0x112>
          else if (shift == caps_lock)
c00245aa:	0f b6 4c 24 0f       	movzbl 0xf(%esp),%ecx
c00245af:	3a 0d 80 77 03 c0    	cmp    0xc0037780,%cl
c00245b5:	75 13                	jne    c00245ca <keyboard_interrupt+0x112>
            c = tolower (c);
c00245b7:	0f b6 c0             	movzbl %al,%eax
#ifndef __LIB_CTYPE_H
#define __LIB_CTYPE_H

static inline int islower (int c) { return c >= 'a' && c <= 'z'; }
static inline int isupper (int c) { return c >= 'A' && c <= 'Z'; }
c00245ba:	8d 48 bf             	lea    -0x41(%eax),%ecx
static inline int isascii (int c) { return c >= 0 && c < 128; }
static inline int ispunct (int c) {
  return isprint (c) && !isalnum (c) && !isspace (c);
}

static inline int tolower (int c) { return isupper (c) ? c - 'A' + 'a' : c; }
c00245bd:	8d 50 20             	lea    0x20(%eax),%edx
c00245c0:	83 f9 19             	cmp    $0x19,%ecx
c00245c3:	0f 46 c2             	cmovbe %edx,%eax
c00245c6:	88 44 24 1f          	mov    %al,0x1f(%esp)
          if (alt)
c00245ca:	f7 c7 01 00 00 00    	test   $0x1,%edi
c00245d0:	74 05                	je     c00245d7 <keyboard_interrupt+0x11f>
            c += 0x80;
c00245d2:	80 44 24 1f 80       	addb   $0x80,0x1f(%esp)
          if (!input_full ())
c00245d7:	e8 11 18 00 00       	call   c0025ded <input_full>
c00245dc:	84 c0                	test   %al,%al
c00245de:	75 63                	jne    c0024643 <keyboard_interrupt+0x18b>
              key_cnt++;
c00245e0:	83 05 78 77 03 c0 01 	addl   $0x1,0xc0037778
c00245e7:	83 15 7c 77 03 c0 00 	adcl   $0x0,0xc003777c
              input_putc (c);
c00245ee:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c00245f3:	89 04 24             	mov    %eax,(%esp)
c00245f6:	e8 2d 17 00 00       	call   c0025d28 <input_putc>
c00245fb:	eb 46                	jmp    c0024643 <keyboard_interrupt+0x18b>
        if (key->scancode == code)
c00245fd:	39 d3                	cmp    %edx,%ebx
c00245ff:	75 13                	jne    c0024614 <keyboard_interrupt+0x15c>
c0024601:	eb 05                	jmp    c0024608 <keyboard_interrupt+0x150>
      for (key = shift_keys; key->scancode != 0; key++) 
c0024603:	b8 40 d3 02 c0       	mov    $0xc002d340,%eax
            *key->state_var = !release;
c0024608:	8b 40 04             	mov    0x4(%eax),%eax
c002460b:	89 f2                	mov    %esi,%edx
c002460d:	83 f2 01             	xor    $0x1,%edx
c0024610:	88 10                	mov    %dl,(%eax)
            break;
c0024612:	eb 2f                	jmp    c0024643 <keyboard_interrupt+0x18b>
      for (key = shift_keys; key->scancode != 0; key++) 
c0024614:	83 c0 08             	add    $0x8,%eax
c0024617:	8b 10                	mov    (%eax),%edx
c0024619:	85 d2                	test   %edx,%edx
c002461b:	75 e0                	jne    c00245fd <keyboard_interrupt+0x145>
c002461d:	eb 24                	jmp    c0024643 <keyboard_interrupt+0x18b>
           || (shift && map_key (shifted_keymap, code, &c)))
c002461f:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c0024623:	89 da                	mov    %ebx,%edx
c0024625:	b8 80 d3 02 c0       	mov    $0xc002d380,%eax
c002462a:	e8 21 fe ff ff       	call   c0024450 <map_key>
c002462f:	84 c0                	test   %al,%al
c0024631:	0f 85 3b ff ff ff    	jne    c0024572 <keyboard_interrupt+0xba>
        if (key->scancode == code)
c0024637:	83 fb 2a             	cmp    $0x2a,%ebx
c002463a:	74 c7                	je     c0024603 <keyboard_interrupt+0x14b>
      for (key = shift_keys; key->scancode != 0; key++) 
c002463c:	b8 40 d3 02 c0       	mov    $0xc002d340,%eax
c0024641:	eb d1                	jmp    c0024614 <keyboard_interrupt+0x15c>
}
c0024643:	83 c4 2c             	add    $0x2c,%esp
c0024646:	5b                   	pop    %ebx
c0024647:	5e                   	pop    %esi
c0024648:	5f                   	pop    %edi
c0024649:	5d                   	pop    %ebp
c002464a:	c3                   	ret    

c002464b <kbd_init>:
{
c002464b:	83 ec 1c             	sub    $0x1c,%esp
  intr_register_ext (0x21, keyboard_interrupt, "8042 Keyboard");
c002464e:	c7 44 24 08 89 ed 02 	movl   $0xc002ed89,0x8(%esp)
c0024655:	c0 
c0024656:	c7 44 24 04 b8 44 02 	movl   $0xc00244b8,0x4(%esp)
c002465d:	c0 
c002465e:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c0024665:	e8 f9 d4 ff ff       	call   c0021b63 <intr_register_ext>
}
c002466a:	83 c4 1c             	add    $0x1c,%esp
c002466d:	c3                   	ret    

c002466e <kbd_print_stats>:
{
c002466e:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Keyboard: %lld keys pressed\n", key_cnt);
c0024671:	a1 78 77 03 c0       	mov    0xc0037778,%eax
c0024676:	8b 15 7c 77 03 c0    	mov    0xc003777c,%edx
c002467c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024680:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024684:	c7 04 24 97 ed 02 c0 	movl   $0xc002ed97,(%esp)
c002468b:	e8 9e 24 00 00       	call   c0026b2e <printf>
}
c0024690:	83 c4 1c             	add    $0x1c,%esp
c0024693:	c3                   	ret    
c0024694:	90                   	nop
c0024695:	90                   	nop
c0024696:	90                   	nop
c0024697:	90                   	nop
c0024698:	90                   	nop
c0024699:	90                   	nop
c002469a:	90                   	nop
c002469b:	90                   	nop
c002469c:	90                   	nop
c002469d:	90                   	nop
c002469e:	90                   	nop
c002469f:	90                   	nop

c00246a0 <move_cursor>:
/* Moves the hardware cursor to (cx,cy). */
static void
move_cursor (void) 
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp = cx + COL_CNT * cy;
c00246a0:	8b 0d 90 77 03 c0    	mov    0xc0037790,%ecx
c00246a6:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c00246a9:	c1 e1 04             	shl    $0x4,%ecx
c00246ac:	66 03 0d 94 77 03 c0 	add    0xc0037794,%cx
  outw (0x3d4, 0x0e | (cp & 0xff00));
c00246b3:	89 c8                	mov    %ecx,%eax
c00246b5:	b0 00                	mov    $0x0,%al
c00246b7:	83 c8 0e             	or     $0xe,%eax
/* Writes the 16-bit DATA to PORT. */
static inline void
outw (uint16_t port, uint16_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c00246ba:	ba d4 03 00 00       	mov    $0x3d4,%edx
c00246bf:	66 ef                	out    %ax,(%dx)
  outw (0x3d4, 0x0f | (cp << 8));
c00246c1:	89 c8                	mov    %ecx,%eax
c00246c3:	c1 e0 08             	shl    $0x8,%eax
c00246c6:	83 c8 0f             	or     $0xf,%eax
c00246c9:	66 ef                	out    %ax,(%dx)
c00246cb:	c3                   	ret    

c00246cc <newline>:
  cx = 0;
c00246cc:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c00246d3:	00 00 00 
  cy++;
c00246d6:	a1 90 77 03 c0       	mov    0xc0037790,%eax
c00246db:	83 c0 01             	add    $0x1,%eax
  if (cy >= ROW_CNT)
c00246de:	83 f8 18             	cmp    $0x18,%eax
c00246e1:	77 06                	ja     c00246e9 <newline+0x1d>
  cy++;
c00246e3:	a3 90 77 03 c0       	mov    %eax,0xc0037790
c00246e8:	c3                   	ret    
{
c00246e9:	53                   	push   %ebx
c00246ea:	83 ec 18             	sub    $0x18,%esp
      cy = ROW_CNT - 1;
c00246ed:	c7 05 90 77 03 c0 18 	movl   $0x18,0xc0037790
c00246f4:	00 00 00 
      memmove (&fb[0], &fb[1], sizeof fb[0] * (ROW_CNT - 1));
c00246f7:	8b 1d 8c 77 03 c0    	mov    0xc003778c,%ebx
c00246fd:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
c0024704:	00 
c0024705:	8d 83 a0 00 00 00    	lea    0xa0(%ebx),%eax
c002470b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002470f:	89 1c 24             	mov    %ebx,(%esp)
c0024712:	e8 e6 31 00 00       	call   c00278fd <memmove>
  for (x = 0; x < COL_CNT; x++)
c0024717:	b8 00 00 00 00       	mov    $0x0,%eax
      fb[y][x][0] = ' ';
c002471c:	c6 84 43 00 0f 00 00 	movb   $0x20,0xf00(%ebx,%eax,2)
c0024723:	20 
      fb[y][x][1] = GRAY_ON_BLACK;
c0024724:	c6 84 43 01 0f 00 00 	movb   $0x7,0xf01(%ebx,%eax,2)
c002472b:	07 
  for (x = 0; x < COL_CNT; x++)
c002472c:	83 c0 01             	add    $0x1,%eax
c002472f:	83 f8 50             	cmp    $0x50,%eax
c0024732:	75 e8                	jne    c002471c <newline+0x50>
}
c0024734:	83 c4 18             	add    $0x18,%esp
c0024737:	5b                   	pop    %ebx
c0024738:	c3                   	ret    

c0024739 <vga_putc>:
{
c0024739:	57                   	push   %edi
c002473a:	56                   	push   %esi
c002473b:	53                   	push   %ebx
c002473c:	83 ec 10             	sub    $0x10,%esp
c002473f:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  enum intr_level old_level = intr_disable ();
c0024743:	e8 77 d2 ff ff       	call   c00219bf <intr_disable>
c0024748:	89 c6                	mov    %eax,%esi
  if (!inited)
c002474a:	80 3d 88 77 03 c0 00 	cmpb   $0x0,0xc0037788
c0024751:	75 5e                	jne    c00247b1 <vga_putc+0x78>
      fb = ptov (0xb8000);
c0024753:	c7 05 8c 77 03 c0 00 	movl   $0xc00b8000,0xc003778c
c002475a:	80 0b c0 
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002475d:	ba d4 03 00 00       	mov    $0x3d4,%edx
c0024762:	b8 0e 00 00 00       	mov    $0xe,%eax
c0024767:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024768:	b9 d5 03 00 00       	mov    $0x3d5,%ecx
c002476d:	89 ca                	mov    %ecx,%edx
c002476f:	ec                   	in     (%dx),%al
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp;

  outb (0x3d4, 0x0e);
  cp = inb (0x3d5) << 8;
c0024770:	89 c7                	mov    %eax,%edi
c0024772:	c1 e7 08             	shl    $0x8,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024775:	b2 d4                	mov    $0xd4,%dl
c0024777:	b8 0f 00 00 00       	mov    $0xf,%eax
c002477c:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002477d:	89 ca                	mov    %ecx,%edx
c002477f:	ec                   	in     (%dx),%al

  outb (0x3d4, 0x0f);
  cp |= inb (0x3d5);
c0024780:	0f b6 d0             	movzbl %al,%edx
c0024783:	09 fa                	or     %edi,%edx

  *x = cp % COL_CNT;
c0024785:	0f b7 c2             	movzwl %dx,%eax
c0024788:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
c002478e:	c1 e8 16             	shr    $0x16,%eax
c0024791:	8d 0c 80             	lea    (%eax,%eax,4),%ecx
c0024794:	c1 e1 04             	shl    $0x4,%ecx
c0024797:	29 ca                	sub    %ecx,%edx
c0024799:	0f b7 d2             	movzwl %dx,%edx
c002479c:	89 15 94 77 03 c0    	mov    %edx,0xc0037794
  *y = cp / COL_CNT;
c00247a2:	0f b7 c0             	movzwl %ax,%eax
c00247a5:	a3 90 77 03 c0       	mov    %eax,0xc0037790
      inited = true; 
c00247aa:	c6 05 88 77 03 c0 01 	movb   $0x1,0xc0037788
  switch (c) 
c00247b1:	8d 43 f9             	lea    -0x7(%ebx),%eax
c00247b4:	83 f8 06             	cmp    $0x6,%eax
c00247b7:	0f 87 b8 00 00 00    	ja     c0024875 <vga_putc+0x13c>
c00247bd:	ff 24 85 50 d4 02 c0 	jmp    *-0x3ffd2bb0(,%eax,4)
c00247c4:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
      fb[y][x][0] = ' ';
c00247c9:	bb 00 00 00 00       	mov    $0x0,%ebx
c00247ce:	eb 28                	jmp    c00247f8 <vga_putc+0xbf>
      newline ();
c00247d0:	e8 f7 fe ff ff       	call   c00246cc <newline>
      break;
c00247d5:	e9 e7 00 00 00       	jmp    c00248c1 <vga_putc+0x188>
      fb[y][x][0] = ' ';
c00247da:	c6 04 51 20          	movb   $0x20,(%ecx,%edx,2)
      fb[y][x][1] = GRAY_ON_BLACK;
c00247de:	c6 44 51 01 07       	movb   $0x7,0x1(%ecx,%edx,2)
  for (x = 0; x < COL_CNT; x++)
c00247e3:	83 c2 01             	add    $0x1,%edx
c00247e6:	83 fa 50             	cmp    $0x50,%edx
c00247e9:	75 ef                	jne    c00247da <vga_putc+0xa1>
  for (y = 0; y < ROW_CNT; y++)
c00247eb:	83 c3 01             	add    $0x1,%ebx
c00247ee:	05 a0 00 00 00       	add    $0xa0,%eax
c00247f3:	83 fb 19             	cmp    $0x19,%ebx
c00247f6:	74 09                	je     c0024801 <vga_putc+0xc8>
      fb[y][x][0] = ' ';
c00247f8:	89 c1                	mov    %eax,%ecx
c00247fa:	ba 00 00 00 00       	mov    $0x0,%edx
c00247ff:	eb d9                	jmp    c00247da <vga_putc+0xa1>
  cx = cy = 0;
c0024801:	c7 05 90 77 03 c0 00 	movl   $0x0,0xc0037790
c0024808:	00 00 00 
c002480b:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024812:	00 00 00 
  move_cursor ();
c0024815:	e8 86 fe ff ff       	call   c00246a0 <move_cursor>
c002481a:	e9 a2 00 00 00       	jmp    c00248c1 <vga_putc+0x188>
      if (cx > 0)
c002481f:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c0024824:	85 c0                	test   %eax,%eax
c0024826:	0f 84 95 00 00 00    	je     c00248c1 <vga_putc+0x188>
        cx--;
c002482c:	83 e8 01             	sub    $0x1,%eax
c002482f:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c0024834:	e9 88 00 00 00       	jmp    c00248c1 <vga_putc+0x188>
      cx = 0;
c0024839:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024840:	00 00 00 
      break;
c0024843:	eb 7c                	jmp    c00248c1 <vga_putc+0x188>
      cx = ROUND_UP (cx + 1, 8);
c0024845:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c002484a:	83 c0 08             	add    $0x8,%eax
c002484d:	83 e0 f8             	and    $0xfffffff8,%eax
c0024850:	a3 94 77 03 c0       	mov    %eax,0xc0037794
      if (cx >= COL_CNT)
c0024855:	83 f8 4f             	cmp    $0x4f,%eax
c0024858:	76 67                	jbe    c00248c1 <vga_putc+0x188>
        newline ();
c002485a:	e8 6d fe ff ff       	call   c00246cc <newline>
c002485f:	eb 60                	jmp    c00248c1 <vga_putc+0x188>
      intr_set_level (old_level);
c0024861:	89 34 24             	mov    %esi,(%esp)
c0024864:	e8 5d d1 ff ff       	call   c00219c6 <intr_set_level>
      speaker_beep ();
c0024869:	e8 bd 1c 00 00       	call   c002652b <speaker_beep>
      intr_disable ();
c002486e:	e8 4c d1 ff ff       	call   c00219bf <intr_disable>
      break;
c0024873:	eb 4c                	jmp    c00248c1 <vga_putc+0x188>
      fb[cy][cx][0] = c;
c0024875:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
c002487a:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c0024880:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0024883:	c1 e2 05             	shl    $0x5,%edx
c0024886:	01 c2                	add    %eax,%edx
c0024888:	8b 0d 94 77 03 c0    	mov    0xc0037794,%ecx
c002488e:	88 1c 4a             	mov    %bl,(%edx,%ecx,2)
      fb[cy][cx][1] = GRAY_ON_BLACK;
c0024891:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c0024897:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002489a:	c1 e2 05             	shl    $0x5,%edx
c002489d:	01 d0                	add    %edx,%eax
c002489f:	8b 15 94 77 03 c0    	mov    0xc0037794,%edx
c00248a5:	c6 44 50 01 07       	movb   $0x7,0x1(%eax,%edx,2)
      if (++cx >= COL_CNT)
c00248aa:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c00248af:	83 c0 01             	add    $0x1,%eax
c00248b2:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c00248b7:	83 f8 4f             	cmp    $0x4f,%eax
c00248ba:	76 05                	jbe    c00248c1 <vga_putc+0x188>
        newline ();
c00248bc:	e8 0b fe ff ff       	call   c00246cc <newline>
  move_cursor ();
c00248c1:	e8 da fd ff ff       	call   c00246a0 <move_cursor>
  intr_set_level (old_level);
c00248c6:	89 34 24             	mov    %esi,(%esp)
c00248c9:	e8 f8 d0 ff ff       	call   c00219c6 <intr_set_level>
}
c00248ce:	83 c4 10             	add    $0x10,%esp
c00248d1:	5b                   	pop    %ebx
c00248d2:	5e                   	pop    %esi
c00248d3:	5f                   	pop    %edi
c00248d4:	c3                   	ret    
c00248d5:	90                   	nop
c00248d6:	90                   	nop
c00248d7:	90                   	nop
c00248d8:	90                   	nop
c00248d9:	90                   	nop
c00248da:	90                   	nop
c00248db:	90                   	nop
c00248dc:	90                   	nop
c00248dd:	90                   	nop
c00248de:	90                   	nop
c00248df:	90                   	nop

c00248e0 <init_poll>:
   Polling mode busy-waits for the serial port to become free
   before writing to it.  It's slow, but until interrupts have
   been initialized it's all we can do. */
static void
init_poll (void) 
{
c00248e0:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (mode == UNINIT);
c00248e3:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c00248ea:	74 2c                	je     c0024918 <init_poll+0x38>
c00248ec:	c7 44 24 10 10 ee 02 	movl   $0xc002ee10,0x10(%esp)
c00248f3:	c0 
c00248f4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00248fb:	c0 
c00248fc:	c7 44 24 08 8e d4 02 	movl   $0xc002d48e,0x8(%esp)
c0024903:	c0 
c0024904:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c002490b:	00 
c002490c:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024913:	e8 6b 40 00 00       	call   c0028983 <debug_panic>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024918:	ba f9 03 00 00       	mov    $0x3f9,%edx
c002491d:	b8 00 00 00 00       	mov    $0x0,%eax
c0024922:	ee                   	out    %al,(%dx)
c0024923:	b2 fa                	mov    $0xfa,%dl
c0024925:	ee                   	out    %al,(%dx)
c0024926:	b2 fb                	mov    $0xfb,%dl
c0024928:	b8 83 ff ff ff       	mov    $0xffffff83,%eax
c002492d:	ee                   	out    %al,(%dx)
c002492e:	b2 f8                	mov    $0xf8,%dl
c0024930:	b8 0c 00 00 00       	mov    $0xc,%eax
c0024935:	ee                   	out    %al,(%dx)
c0024936:	b2 f9                	mov    $0xf9,%dl
c0024938:	b8 00 00 00 00       	mov    $0x0,%eax
c002493d:	ee                   	out    %al,(%dx)
c002493e:	b2 fb                	mov    $0xfb,%dl
c0024940:	b8 03 00 00 00       	mov    $0x3,%eax
c0024945:	ee                   	out    %al,(%dx)
c0024946:	b2 fc                	mov    $0xfc,%dl
c0024948:	b8 08 00 00 00       	mov    $0x8,%eax
c002494d:	ee                   	out    %al,(%dx)
  outb (IER_REG, 0);                    /* Turn off all interrupts. */
  outb (FCR_REG, 0);                    /* Disable FIFO. */
  set_serial (9600);                    /* 9.6 kbps, N-8-1. */
  outb (MCR_REG, MCR_OUT2);             /* Required to enable interrupts. */
  intq_init (&txq);
c002494e:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024955:	e8 db 14 00 00       	call   c0025e35 <intq_init>
  mode = POLL;
c002495a:	c7 05 14 78 03 c0 01 	movl   $0x1,0xc0037814
c0024961:	00 00 00 
} 
c0024964:	83 c4 2c             	add    $0x2c,%esp
c0024967:	c3                   	ret    

c0024968 <write_ier>:
}

/* Update interrupt enable register. */
static void
write_ier (void) 
{
c0024968:	53                   	push   %ebx
c0024969:	83 ec 28             	sub    $0x28,%esp
  uint8_t ier = 0;

  ASSERT (intr_get_level () == INTR_OFF);
c002496c:	e8 03 d0 ff ff       	call   c0021974 <intr_get_level>
c0024971:	85 c0                	test   %eax,%eax
c0024973:	74 2c                	je     c00249a1 <write_ier+0x39>
c0024975:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c002497c:	c0 
c002497d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024984:	c0 
c0024985:	c7 44 24 08 84 d4 02 	movl   $0xc002d484,0x8(%esp)
c002498c:	c0 
c002498d:	c7 44 24 04 b5 00 00 	movl   $0xb5,0x4(%esp)
c0024994:	00 
c0024995:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c002499c:	e8 e2 3f 00 00       	call   c0028983 <debug_panic>

  /* Enable transmit interrupt if we have any characters to
     transmit. */
  if (!intq_empty (&txq))
c00249a1:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c00249a8:	e8 b9 14 00 00       	call   c0025e66 <intq_empty>
  uint8_t ier = 0;
c00249ad:	3c 01                	cmp    $0x1,%al
c00249af:	19 db                	sbb    %ebx,%ebx
c00249b1:	83 e3 02             	and    $0x2,%ebx
    ier |= IER_XMIT;

  /* Enable receive interrupt if we have room to store any
     characters we receive. */
  if (!input_full ())
c00249b4:	e8 34 14 00 00       	call   c0025ded <input_full>
    ier |= IER_RECV;
c00249b9:	89 da                	mov    %ebx,%edx
c00249bb:	83 ca 01             	or     $0x1,%edx
c00249be:	84 c0                	test   %al,%al
c00249c0:	0f 44 da             	cmove  %edx,%ebx
c00249c3:	ba f9 03 00 00       	mov    $0x3f9,%edx
c00249c8:	89 d8                	mov    %ebx,%eax
c00249ca:	ee                   	out    %al,(%dx)
  
  outb (IER_REG, ier);
}
c00249cb:	83 c4 28             	add    $0x28,%esp
c00249ce:	5b                   	pop    %ebx
c00249cf:	c3                   	ret    

c00249d0 <serial_interrupt>:
}

/* Serial interrupt handler. */
static void
serial_interrupt (struct intr_frame *f UNUSED) 
{
c00249d0:	56                   	push   %esi
c00249d1:	53                   	push   %ebx
c00249d2:	83 ec 14             	sub    $0x14,%esp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00249d5:	ba fa 03 00 00       	mov    $0x3fa,%edx
c00249da:	ec                   	in     (%dx),%al
c00249db:	bb fd 03 00 00       	mov    $0x3fd,%ebx
c00249e0:	be f8 03 00 00       	mov    $0x3f8,%esi
c00249e5:	eb 0e                	jmp    c00249f5 <serial_interrupt+0x25>
c00249e7:	89 f2                	mov    %esi,%edx
c00249e9:	ec                   	in     (%dx),%al
  inb (IIR_REG);

  /* As long as we have room to receive a byte, and the hardware
     has a byte for us, receive a byte.  */
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
    input_putc (inb (RBR_REG));
c00249ea:	0f b6 c0             	movzbl %al,%eax
c00249ed:	89 04 24             	mov    %eax,(%esp)
c00249f0:	e8 33 13 00 00       	call   c0025d28 <input_putc>
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
c00249f5:	e8 f3 13 00 00       	call   c0025ded <input_full>
c00249fa:	84 c0                	test   %al,%al
c00249fc:	74 0c                	je     c0024a0a <serial_interrupt+0x3a>
c00249fe:	bb fd 03 00 00       	mov    $0x3fd,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a03:	be f8 03 00 00       	mov    $0x3f8,%esi
c0024a08:	eb 18                	jmp    c0024a22 <serial_interrupt+0x52>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a0a:	89 da                	mov    %ebx,%edx
c0024a0c:	ec                   	in     (%dx),%al
c0024a0d:	a8 01                	test   $0x1,%al
c0024a0f:	75 d6                	jne    c00249e7 <serial_interrupt+0x17>
c0024a11:	eb eb                	jmp    c00249fe <serial_interrupt+0x2e>

  /* As long as we have a byte to transmit, and the hardware is
     ready to accept a byte for transmission, transmit a byte. */
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
    outb (THR_REG, intq_getc (&txq));
c0024a13:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a1a:	e8 70 16 00 00       	call   c002608f <intq_getc>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a1f:	89 f2                	mov    %esi,%edx
c0024a21:	ee                   	out    %al,(%dx)
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
c0024a22:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a29:	e8 38 14 00 00       	call   c0025e66 <intq_empty>
c0024a2e:	84 c0                	test   %al,%al
c0024a30:	75 07                	jne    c0024a39 <serial_interrupt+0x69>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a32:	89 da                	mov    %ebx,%edx
c0024a34:	ec                   	in     (%dx),%al
c0024a35:	a8 20                	test   $0x20,%al
c0024a37:	75 da                	jne    c0024a13 <serial_interrupt+0x43>

  /* Update interrupt enable register based on queue status. */
  write_ier ();
c0024a39:	e8 2a ff ff ff       	call   c0024968 <write_ier>
}
c0024a3e:	83 c4 14             	add    $0x14,%esp
c0024a41:	5b                   	pop    %ebx
c0024a42:	5e                   	pop    %esi
c0024a43:	c3                   	ret    

c0024a44 <putc_poll>:
{
c0024a44:	53                   	push   %ebx
c0024a45:	83 ec 28             	sub    $0x28,%esp
c0024a48:	89 c3                	mov    %eax,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0024a4a:	e8 25 cf ff ff       	call   c0021974 <intr_get_level>
c0024a4f:	85 c0                	test   %eax,%eax
c0024a51:	74 2c                	je     c0024a7f <putc_poll+0x3b>
c0024a53:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0024a5a:	c0 
c0024a5b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024a62:	c0 
c0024a63:	c7 44 24 08 7a d4 02 	movl   $0xc002d47a,0x8(%esp)
c0024a6a:	c0 
c0024a6b:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c0024a72:	00 
c0024a73:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024a7a:	e8 04 3f 00 00       	call   c0028983 <debug_panic>
c0024a7f:	ba fd 03 00 00       	mov    $0x3fd,%edx
c0024a84:	ec                   	in     (%dx),%al
  while ((inb (LSR_REG) & LSR_THRE) == 0)
c0024a85:	a8 20                	test   $0x20,%al
c0024a87:	74 fb                	je     c0024a84 <putc_poll+0x40>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a89:	ba f8 03 00 00       	mov    $0x3f8,%edx
c0024a8e:	89 d8                	mov    %ebx,%eax
c0024a90:	ee                   	out    %al,(%dx)
}
c0024a91:	83 c4 28             	add    $0x28,%esp
c0024a94:	5b                   	pop    %ebx
c0024a95:	c3                   	ret    

c0024a96 <serial_init_queue>:
{
c0024a96:	53                   	push   %ebx
c0024a97:	83 ec 28             	sub    $0x28,%esp
  if (mode == UNINIT)
c0024a9a:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c0024aa1:	75 05                	jne    c0024aa8 <serial_init_queue+0x12>
    init_poll ();
c0024aa3:	e8 38 fe ff ff       	call   c00248e0 <init_poll>
  ASSERT (mode == POLL);
c0024aa8:	83 3d 14 78 03 c0 01 	cmpl   $0x1,0xc0037814
c0024aaf:	74 2c                	je     c0024add <serial_init_queue+0x47>
c0024ab1:	c7 44 24 10 36 ee 02 	movl   $0xc002ee36,0x10(%esp)
c0024ab8:	c0 
c0024ab9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024ac0:	c0 
c0024ac1:	c7 44 24 08 98 d4 02 	movl   $0xc002d498,0x8(%esp)
c0024ac8:	c0 
c0024ac9:	c7 44 24 04 58 00 00 	movl   $0x58,0x4(%esp)
c0024ad0:	00 
c0024ad1:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024ad8:	e8 a6 3e 00 00       	call   c0028983 <debug_panic>
  intr_register_ext (0x20 + 4, serial_interrupt, "serial");
c0024add:	c7 44 24 08 43 ee 02 	movl   $0xc002ee43,0x8(%esp)
c0024ae4:	c0 
c0024ae5:	c7 44 24 04 d0 49 02 	movl   $0xc00249d0,0x4(%esp)
c0024aec:	c0 
c0024aed:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
c0024af4:	e8 6a d0 ff ff       	call   c0021b63 <intr_register_ext>
  mode = QUEUE;
c0024af9:	c7 05 14 78 03 c0 02 	movl   $0x2,0xc0037814
c0024b00:	00 00 00 
  old_level = intr_disable ();
c0024b03:	e8 b7 ce ff ff       	call   c00219bf <intr_disable>
c0024b08:	89 c3                	mov    %eax,%ebx
  write_ier ();
c0024b0a:	e8 59 fe ff ff       	call   c0024968 <write_ier>
  intr_set_level (old_level);
c0024b0f:	89 1c 24             	mov    %ebx,(%esp)
c0024b12:	e8 af ce ff ff       	call   c00219c6 <intr_set_level>
}
c0024b17:	83 c4 28             	add    $0x28,%esp
c0024b1a:	5b                   	pop    %ebx
c0024b1b:	c3                   	ret    

c0024b1c <serial_putc>:
{
c0024b1c:	56                   	push   %esi
c0024b1d:	53                   	push   %ebx
c0024b1e:	83 ec 14             	sub    $0x14,%esp
c0024b21:	8b 74 24 20          	mov    0x20(%esp),%esi
  enum intr_level old_level = intr_disable ();
c0024b25:	e8 95 ce ff ff       	call   c00219bf <intr_disable>
c0024b2a:	89 c3                	mov    %eax,%ebx
  if (mode != QUEUE)
c0024b2c:	8b 15 14 78 03 c0    	mov    0xc0037814,%edx
c0024b32:	83 fa 02             	cmp    $0x2,%edx
c0024b35:	74 15                	je     c0024b4c <serial_putc+0x30>
      if (mode == UNINIT)
c0024b37:	85 d2                	test   %edx,%edx
c0024b39:	75 05                	jne    c0024b40 <serial_putc+0x24>
        init_poll ();
c0024b3b:	e8 a0 fd ff ff       	call   c00248e0 <init_poll>
      putc_poll (byte); 
c0024b40:	89 f0                	mov    %esi,%eax
c0024b42:	0f b6 c0             	movzbl %al,%eax
c0024b45:	e8 fa fe ff ff       	call   c0024a44 <putc_poll>
c0024b4a:	eb 42                	jmp    c0024b8e <serial_putc+0x72>
      if (old_level == INTR_OFF && intq_full (&txq)) 
c0024b4c:	85 c0                	test   %eax,%eax
c0024b4e:	75 24                	jne    c0024b74 <serial_putc+0x58>
c0024b50:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b57:	e8 55 13 00 00       	call   c0025eb1 <intq_full>
c0024b5c:	84 c0                	test   %al,%al
c0024b5e:	74 14                	je     c0024b74 <serial_putc+0x58>
          putc_poll (intq_getc (&txq)); 
c0024b60:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b67:	e8 23 15 00 00       	call   c002608f <intq_getc>
c0024b6c:	0f b6 c0             	movzbl %al,%eax
c0024b6f:	e8 d0 fe ff ff       	call   c0024a44 <putc_poll>
      intq_putc (&txq, byte); 
c0024b74:	89 f0                	mov    %esi,%eax
c0024b76:	0f b6 f0             	movzbl %al,%esi
c0024b79:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024b7d:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b84:	e8 d2 15 00 00       	call   c002615b <intq_putc>
      write_ier ();
c0024b89:	e8 da fd ff ff       	call   c0024968 <write_ier>
  intr_set_level (old_level);
c0024b8e:	89 1c 24             	mov    %ebx,(%esp)
c0024b91:	e8 30 ce ff ff       	call   c00219c6 <intr_set_level>
}
c0024b96:	83 c4 14             	add    $0x14,%esp
c0024b99:	5b                   	pop    %ebx
c0024b9a:	5e                   	pop    %esi
c0024b9b:	c3                   	ret    

c0024b9c <serial_flush>:
{
c0024b9c:	53                   	push   %ebx
c0024b9d:	83 ec 18             	sub    $0x18,%esp
  enum intr_level old_level = intr_disable ();
c0024ba0:	e8 1a ce ff ff       	call   c00219bf <intr_disable>
c0024ba5:	89 c3                	mov    %eax,%ebx
  while (!intq_empty (&txq))
c0024ba7:	eb 14                	jmp    c0024bbd <serial_flush+0x21>
    putc_poll (intq_getc (&txq));
c0024ba9:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024bb0:	e8 da 14 00 00       	call   c002608f <intq_getc>
c0024bb5:	0f b6 c0             	movzbl %al,%eax
c0024bb8:	e8 87 fe ff ff       	call   c0024a44 <putc_poll>
  while (!intq_empty (&txq))
c0024bbd:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024bc4:	e8 9d 12 00 00       	call   c0025e66 <intq_empty>
c0024bc9:	84 c0                	test   %al,%al
c0024bcb:	74 dc                	je     c0024ba9 <serial_flush+0xd>
  intr_set_level (old_level);
c0024bcd:	89 1c 24             	mov    %ebx,(%esp)
c0024bd0:	e8 f1 cd ff ff       	call   c00219c6 <intr_set_level>
}
c0024bd5:	83 c4 18             	add    $0x18,%esp
c0024bd8:	5b                   	pop    %ebx
c0024bd9:	c3                   	ret    

c0024bda <serial_notify>:
{
c0024bda:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0024bdd:	e8 92 cd ff ff       	call   c0021974 <intr_get_level>
c0024be2:	85 c0                	test   %eax,%eax
c0024be4:	74 2c                	je     c0024c12 <serial_notify+0x38>
c0024be6:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0024bed:	c0 
c0024bee:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024bf5:	c0 
c0024bf6:	c7 44 24 08 6c d4 02 	movl   $0xc002d46c,0x8(%esp)
c0024bfd:	c0 
c0024bfe:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
c0024c05:	00 
c0024c06:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024c0d:	e8 71 3d 00 00       	call   c0028983 <debug_panic>
  if (mode == QUEUE)
c0024c12:	83 3d 14 78 03 c0 02 	cmpl   $0x2,0xc0037814
c0024c19:	75 05                	jne    c0024c20 <serial_notify+0x46>
    write_ier ();
c0024c1b:	e8 48 fd ff ff       	call   c0024968 <write_ier>
}
c0024c20:	83 c4 2c             	add    $0x2c,%esp
c0024c23:	c3                   	ret    

c0024c24 <check_sector>:
/* Verifies that SECTOR is a valid offset within BLOCK.
   Panics if not. */
static void
check_sector (struct block *block, block_sector_t sector)
{
  if (sector >= block->size)
c0024c24:	8b 48 1c             	mov    0x1c(%eax),%ecx
c0024c27:	39 d1                	cmp    %edx,%ecx
c0024c29:	77 36                	ja     c0024c61 <check_sector+0x3d>
{
c0024c2b:	83 ec 2c             	sub    $0x2c,%esp
    {
      /* We do not use ASSERT because we want to panic here
         regardless of whether NDEBUG is defined. */
      PANIC ("Access past end of device %s (sector=%"PRDSNu", "
c0024c2e:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024c32:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024c36:	83 c0 08             	add    $0x8,%eax
c0024c39:	89 44 24 10          	mov    %eax,0x10(%esp)
c0024c3d:	c7 44 24 0c 4c ee 02 	movl   $0xc002ee4c,0xc(%esp)
c0024c44:	c0 
c0024c45:	c7 44 24 08 c7 d4 02 	movl   $0xc002d4c7,0x8(%esp)
c0024c4c:	c0 
c0024c4d:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
c0024c54:	00 
c0024c55:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024c5c:	e8 22 3d 00 00       	call   c0028983 <debug_panic>
c0024c61:	f3 c3                	repz ret 

c0024c63 <block_type_name>:
{
c0024c63:	83 ec 2c             	sub    $0x2c,%esp
c0024c66:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (type < BLOCK_CNT);
c0024c6a:	83 f8 05             	cmp    $0x5,%eax
c0024c6d:	76 2c                	jbe    c0024c9b <block_type_name+0x38>
c0024c6f:	c7 44 24 10 f0 ee 02 	movl   $0xc002eef0,0x10(%esp)
c0024c76:	c0 
c0024c77:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024c7e:	c0 
c0024c7f:	c7 44 24 08 0c d5 02 	movl   $0xc002d50c,0x8(%esp)
c0024c86:	c0 
c0024c87:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0024c8e:	00 
c0024c8f:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024c96:	e8 e8 3c 00 00       	call   c0028983 <debug_panic>
  return block_type_names[type];
c0024c9b:	8b 04 85 f4 d4 02 c0 	mov    -0x3ffd2b0c(,%eax,4),%eax
}
c0024ca2:	83 c4 2c             	add    $0x2c,%esp
c0024ca5:	c3                   	ret    

c0024ca6 <block_get_role>:
{
c0024ca6:	83 ec 2c             	sub    $0x2c,%esp
c0024ca9:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024cad:	83 f8 03             	cmp    $0x3,%eax
c0024cb0:	76 2c                	jbe    c0024cde <block_get_role+0x38>
c0024cb2:	c7 44 24 10 01 ef 02 	movl   $0xc002ef01,0x10(%esp)
c0024cb9:	c0 
c0024cba:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024cc1:	c0 
c0024cc2:	c7 44 24 08 e3 d4 02 	movl   $0xc002d4e3,0x8(%esp)
c0024cc9:	c0 
c0024cca:	c7 44 24 04 38 00 00 	movl   $0x38,0x4(%esp)
c0024cd1:	00 
c0024cd2:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024cd9:	e8 a5 3c 00 00       	call   c0028983 <debug_panic>
  return block_by_role[role];
c0024cde:	8b 04 85 18 78 03 c0 	mov    -0x3ffc87e8(,%eax,4),%eax
}
c0024ce5:	83 c4 2c             	add    $0x2c,%esp
c0024ce8:	c3                   	ret    

c0024ce9 <block_set_role>:
{
c0024ce9:	83 ec 2c             	sub    $0x2c,%esp
c0024cec:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024cf0:	83 f8 03             	cmp    $0x3,%eax
c0024cf3:	76 2c                	jbe    c0024d21 <block_set_role+0x38>
c0024cf5:	c7 44 24 10 01 ef 02 	movl   $0xc002ef01,0x10(%esp)
c0024cfc:	c0 
c0024cfd:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024d04:	c0 
c0024d05:	c7 44 24 08 d4 d4 02 	movl   $0xc002d4d4,0x8(%esp)
c0024d0c:	c0 
c0024d0d:	c7 44 24 04 40 00 00 	movl   $0x40,0x4(%esp)
c0024d14:	00 
c0024d15:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024d1c:	e8 62 3c 00 00       	call   c0028983 <debug_panic>
  block_by_role[role] = block;
c0024d21:	8b 54 24 34          	mov    0x34(%esp),%edx
c0024d25:	89 14 85 18 78 03 c0 	mov    %edx,-0x3ffc87e8(,%eax,4)
}
c0024d2c:	83 c4 2c             	add    $0x2c,%esp
c0024d2f:	c3                   	ret    

c0024d30 <block_first>:
{
c0024d30:	53                   	push   %ebx
c0024d31:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_begin (&all_blocks));
c0024d34:	c7 04 24 58 5a 03 c0 	movl   $0xc0035a58,(%esp)
c0024d3b:	e8 61 3d 00 00       	call   c0028aa1 <list_begin>
c0024d40:	89 c3                	mov    %eax,%ebx
/* Returns the block device corresponding to LIST_ELEM, or a null
   pointer if LIST_ELEM is the list end of all_blocks. */
static struct block *
list_elem_to_block (struct list_elem *list_elem)
{
  return (list_elem != list_end (&all_blocks)
c0024d42:	c7 04 24 58 5a 03 c0 	movl   $0xc0035a58,(%esp)
c0024d49:	e8 e5 3d 00 00       	call   c0028b33 <list_end>
          ? list_entry (list_elem, struct block, list_elem)
          : NULL);
c0024d4e:	39 c3                	cmp    %eax,%ebx
c0024d50:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d55:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d58:	83 c4 18             	add    $0x18,%esp
c0024d5b:	5b                   	pop    %ebx
c0024d5c:	c3                   	ret    

c0024d5d <block_next>:
{
c0024d5d:	53                   	push   %ebx
c0024d5e:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_next (&block->list_elem));
c0024d61:	8b 44 24 20          	mov    0x20(%esp),%eax
c0024d65:	89 04 24             	mov    %eax,(%esp)
c0024d68:	e8 72 3d 00 00       	call   c0028adf <list_next>
c0024d6d:	89 c3                	mov    %eax,%ebx
  return (list_elem != list_end (&all_blocks)
c0024d6f:	c7 04 24 58 5a 03 c0 	movl   $0xc0035a58,(%esp)
c0024d76:	e8 b8 3d 00 00       	call   c0028b33 <list_end>
          : NULL);
c0024d7b:	39 c3                	cmp    %eax,%ebx
c0024d7d:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d82:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d85:	83 c4 18             	add    $0x18,%esp
c0024d88:	5b                   	pop    %ebx
c0024d89:	c3                   	ret    

c0024d8a <block_get_by_name>:
{
c0024d8a:	56                   	push   %esi
c0024d8b:	53                   	push   %ebx
c0024d8c:	83 ec 14             	sub    $0x14,%esp
c0024d8f:	8b 74 24 20          	mov    0x20(%esp),%esi
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024d93:	c7 04 24 58 5a 03 c0 	movl   $0xc0035a58,(%esp)
c0024d9a:	e8 02 3d 00 00       	call   c0028aa1 <list_begin>
c0024d9f:	89 c3                	mov    %eax,%ebx
c0024da1:	eb 1d                	jmp    c0024dc0 <block_get_by_name+0x36>
      if (!strcmp (name, block->name))
c0024da3:	8d 43 08             	lea    0x8(%ebx),%eax
c0024da6:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024daa:	89 34 24             	mov    %esi,(%esp)
c0024dad:	e8 e5 2c 00 00       	call   c0027a97 <strcmp>
c0024db2:	85 c0                	test   %eax,%eax
c0024db4:	74 21                	je     c0024dd7 <block_get_by_name+0x4d>
       e = list_next (e))
c0024db6:	89 1c 24             	mov    %ebx,(%esp)
c0024db9:	e8 21 3d 00 00       	call   c0028adf <list_next>
c0024dbe:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024dc0:	c7 04 24 58 5a 03 c0 	movl   $0xc0035a58,(%esp)
c0024dc7:	e8 67 3d 00 00       	call   c0028b33 <list_end>
c0024dcc:	39 d8                	cmp    %ebx,%eax
c0024dce:	75 d3                	jne    c0024da3 <block_get_by_name+0x19>
  return NULL;
c0024dd0:	b8 00 00 00 00       	mov    $0x0,%eax
c0024dd5:	eb 02                	jmp    c0024dd9 <block_get_by_name+0x4f>
c0024dd7:	89 d8                	mov    %ebx,%eax
}
c0024dd9:	83 c4 14             	add    $0x14,%esp
c0024ddc:	5b                   	pop    %ebx
c0024ddd:	5e                   	pop    %esi
c0024dde:	c3                   	ret    

c0024ddf <block_read>:
{
c0024ddf:	56                   	push   %esi
c0024de0:	53                   	push   %ebx
c0024de1:	83 ec 14             	sub    $0x14,%esp
c0024de4:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0024de8:	8b 74 24 24          	mov    0x24(%esp),%esi
  check_sector (block, sector);
c0024dec:	89 f2                	mov    %esi,%edx
c0024dee:	89 d8                	mov    %ebx,%eax
c0024df0:	e8 2f fe ff ff       	call   c0024c24 <check_sector>
  block->ops->read (block->aux, sector, buffer);
c0024df5:	8b 43 20             	mov    0x20(%ebx),%eax
c0024df8:	8b 54 24 28          	mov    0x28(%esp),%edx
c0024dfc:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024e00:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024e04:	8b 53 24             	mov    0x24(%ebx),%edx
c0024e07:	89 14 24             	mov    %edx,(%esp)
c0024e0a:	ff 10                	call   *(%eax)
  block->read_cnt++;
c0024e0c:	83 43 28 01          	addl   $0x1,0x28(%ebx)
c0024e10:	83 53 2c 00          	adcl   $0x0,0x2c(%ebx)
}
c0024e14:	83 c4 14             	add    $0x14,%esp
c0024e17:	5b                   	pop    %ebx
c0024e18:	5e                   	pop    %esi
c0024e19:	c3                   	ret    

c0024e1a <block_write>:
{
c0024e1a:	56                   	push   %esi
c0024e1b:	53                   	push   %ebx
c0024e1c:	83 ec 24             	sub    $0x24,%esp
c0024e1f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0024e23:	8b 74 24 34          	mov    0x34(%esp),%esi
  check_sector (block, sector);
c0024e27:	89 f2                	mov    %esi,%edx
c0024e29:	89 d8                	mov    %ebx,%eax
c0024e2b:	e8 f4 fd ff ff       	call   c0024c24 <check_sector>
  ASSERT (block->type != BLOCK_FOREIGN);
c0024e30:	83 7b 18 05          	cmpl   $0x5,0x18(%ebx)
c0024e34:	75 2c                	jne    c0024e62 <block_write+0x48>
c0024e36:	c7 44 24 10 17 ef 02 	movl   $0xc002ef17,0x10(%esp)
c0024e3d:	c0 
c0024e3e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024e45:	c0 
c0024e46:	c7 44 24 08 bb d4 02 	movl   $0xc002d4bb,0x8(%esp)
c0024e4d:	c0 
c0024e4e:	c7 44 24 04 89 00 00 	movl   $0x89,0x4(%esp)
c0024e55:	00 
c0024e56:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024e5d:	e8 21 3b 00 00       	call   c0028983 <debug_panic>
  block->ops->write (block->aux, sector, buffer);
c0024e62:	8b 43 20             	mov    0x20(%ebx),%eax
c0024e65:	8b 54 24 38          	mov    0x38(%esp),%edx
c0024e69:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024e6d:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024e71:	8b 53 24             	mov    0x24(%ebx),%edx
c0024e74:	89 14 24             	mov    %edx,(%esp)
c0024e77:	ff 50 04             	call   *0x4(%eax)
  block->write_cnt++;
c0024e7a:	83 43 30 01          	addl   $0x1,0x30(%ebx)
c0024e7e:	83 53 34 00          	adcl   $0x0,0x34(%ebx)
}
c0024e82:	83 c4 24             	add    $0x24,%esp
c0024e85:	5b                   	pop    %ebx
c0024e86:	5e                   	pop    %esi
c0024e87:	c3                   	ret    

c0024e88 <block_size>:
  return block->size;
c0024e88:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e8c:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0024e8f:	c3                   	ret    

c0024e90 <block_name>:
  return block->name;
c0024e90:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e94:	83 c0 08             	add    $0x8,%eax
}
c0024e97:	c3                   	ret    

c0024e98 <block_type>:
  return block->type;
c0024e98:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e9c:	8b 40 18             	mov    0x18(%eax),%eax
}
c0024e9f:	c3                   	ret    

c0024ea0 <block_print_stats>:
{
c0024ea0:	56                   	push   %esi
c0024ea1:	53                   	push   %ebx
c0024ea2:	83 ec 24             	sub    $0x24,%esp
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024ea5:	be 00 00 00 00       	mov    $0x0,%esi
      struct block *block = block_by_role[i];
c0024eaa:	8b 1c b5 18 78 03 c0 	mov    -0x3ffc87e8(,%esi,4),%ebx
      if (block != NULL)
c0024eb1:	85 db                	test   %ebx,%ebx
c0024eb3:	74 3e                	je     c0024ef3 <block_print_stats+0x53>
          printf ("%s (%s): %llu reads, %llu writes\n",
c0024eb5:	8b 43 18             	mov    0x18(%ebx),%eax
c0024eb8:	89 04 24             	mov    %eax,(%esp)
c0024ebb:	e8 a3 fd ff ff       	call   c0024c63 <block_type_name>
c0024ec0:	8b 53 30             	mov    0x30(%ebx),%edx
c0024ec3:	8b 4b 34             	mov    0x34(%ebx),%ecx
c0024ec6:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024eca:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024ece:	8b 53 28             	mov    0x28(%ebx),%edx
c0024ed1:	8b 4b 2c             	mov    0x2c(%ebx),%ecx
c0024ed4:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0024ed8:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0024edc:	89 44 24 08          	mov    %eax,0x8(%esp)
c0024ee0:	83 c3 08             	add    $0x8,%ebx
c0024ee3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024ee7:	c7 04 24 80 ee 02 c0 	movl   $0xc002ee80,(%esp)
c0024eee:	e8 3b 1c 00 00       	call   c0026b2e <printf>
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024ef3:	83 c6 01             	add    $0x1,%esi
c0024ef6:	83 fe 04             	cmp    $0x4,%esi
c0024ef9:	75 af                	jne    c0024eaa <block_print_stats+0xa>
}
c0024efb:	83 c4 24             	add    $0x24,%esp
c0024efe:	5b                   	pop    %ebx
c0024eff:	5e                   	pop    %esi
c0024f00:	c3                   	ret    

c0024f01 <block_register>:
{
c0024f01:	55                   	push   %ebp
c0024f02:	57                   	push   %edi
c0024f03:	56                   	push   %esi
c0024f04:	53                   	push   %ebx
c0024f05:	83 ec 1c             	sub    $0x1c,%esp
c0024f08:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0024f0c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
  struct block *block = malloc (sizeof *block);
c0024f10:	c7 04 24 38 00 00 00 	movl   $0x38,(%esp)
c0024f17:	e8 08 eb ff ff       	call   c0023a24 <malloc>
c0024f1c:	89 c6                	mov    %eax,%esi
  if (block == NULL)
c0024f1e:	85 c0                	test   %eax,%eax
c0024f20:	75 24                	jne    c0024f46 <block_register+0x45>
    PANIC ("Failed to allocate memory for block device descriptor");
c0024f22:	c7 44 24 0c a4 ee 02 	movl   $0xc002eea4,0xc(%esp)
c0024f29:	c0 
c0024f2a:	c7 44 24 08 ac d4 02 	movl   $0xc002d4ac,0x8(%esp)
c0024f31:	c0 
c0024f32:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0024f39:	00 
c0024f3a:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024f41:	e8 3d 3a 00 00       	call   c0028983 <debug_panic>
  list_push_back (&all_blocks, &block->list_elem);
c0024f46:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f4a:	c7 04 24 58 5a 03 c0 	movl   $0xc0035a58,(%esp)
c0024f51:	e8 7b 40 00 00       	call   c0028fd1 <list_push_back>
  strlcpy (block->name, name, sizeof block->name);
c0024f56:	8d 6e 08             	lea    0x8(%esi),%ebp
c0024f59:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c0024f60:	00 
c0024f61:	8b 44 24 30          	mov    0x30(%esp),%eax
c0024f65:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f69:	89 2c 24             	mov    %ebp,(%esp)
c0024f6c:	e8 25 30 00 00       	call   c0027f96 <strlcpy>
  block->type = type;
c0024f71:	8b 44 24 34          	mov    0x34(%esp),%eax
c0024f75:	89 46 18             	mov    %eax,0x18(%esi)
  block->size = size;
c0024f78:	89 5e 1c             	mov    %ebx,0x1c(%esi)
  block->ops = ops;
c0024f7b:	8b 44 24 40          	mov    0x40(%esp),%eax
c0024f7f:	89 46 20             	mov    %eax,0x20(%esi)
  block->aux = aux;
c0024f82:	8b 44 24 44          	mov    0x44(%esp),%eax
c0024f86:	89 46 24             	mov    %eax,0x24(%esi)
  block->read_cnt = 0;
c0024f89:	c7 46 28 00 00 00 00 	movl   $0x0,0x28(%esi)
c0024f90:	c7 46 2c 00 00 00 00 	movl   $0x0,0x2c(%esi)
  block->write_cnt = 0;
c0024f97:	c7 46 30 00 00 00 00 	movl   $0x0,0x30(%esi)
c0024f9e:	c7 46 34 00 00 00 00 	movl   $0x0,0x34(%esi)
  printf ("%s: %'"PRDSNu" sectors (", block->name, block->size);
c0024fa5:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0024fa9:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0024fad:	c7 04 24 34 ef 02 c0 	movl   $0xc002ef34,(%esp)
c0024fb4:	e8 75 1b 00 00       	call   c0026b2e <printf>
  print_human_readable_size ((uint64_t) block->size * BLOCK_SECTOR_SIZE);
c0024fb9:	8b 4e 1c             	mov    0x1c(%esi),%ecx
c0024fbc:	bb 00 00 00 00       	mov    $0x0,%ebx
c0024fc1:	0f a4 cb 09          	shld   $0x9,%ecx,%ebx
c0024fc5:	c1 e1 09             	shl    $0x9,%ecx
c0024fc8:	89 0c 24             	mov    %ecx,(%esp)
c0024fcb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024fcf:	e8 25 24 00 00       	call   c00273f9 <print_human_readable_size>
  printf (")");
c0024fd4:	c7 04 24 29 00 00 00 	movl   $0x29,(%esp)
c0024fdb:	e8 3c 57 00 00       	call   c002a71c <putchar>
  if (extra_info != NULL)
c0024fe0:	85 ff                	test   %edi,%edi
c0024fe2:	74 10                	je     c0024ff4 <block_register+0xf3>
    printf (", %s", extra_info);
c0024fe4:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0024fe8:	c7 04 24 46 ef 02 c0 	movl   $0xc002ef46,(%esp)
c0024fef:	e8 3a 1b 00 00       	call   c0026b2e <printf>
  printf ("\n");
c0024ff4:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0024ffb:	e8 1c 57 00 00       	call   c002a71c <putchar>
}
c0025000:	89 f0                	mov    %esi,%eax
c0025002:	83 c4 1c             	add    $0x1c,%esp
c0025005:	5b                   	pop    %ebx
c0025006:	5e                   	pop    %esi
c0025007:	5f                   	pop    %edi
c0025008:	5d                   	pop    %ebp
c0025009:	c3                   	ret    

c002500a <partition_read>:

/* Reads sector SECTOR from partition P into BUFFER, which must
   have room for BLOCK_SECTOR_SIZE bytes. */
static void
partition_read (void *p_, block_sector_t sector, void *buffer)
{
c002500a:	83 ec 1c             	sub    $0x1c,%esp
c002500d:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_read (p->block, p->start + sector, buffer);
c0025011:	8b 54 24 28          	mov    0x28(%esp),%edx
c0025015:	89 54 24 08          	mov    %edx,0x8(%esp)
c0025019:	8b 54 24 24          	mov    0x24(%esp),%edx
c002501d:	03 50 04             	add    0x4(%eax),%edx
c0025020:	89 54 24 04          	mov    %edx,0x4(%esp)
c0025024:	8b 00                	mov    (%eax),%eax
c0025026:	89 04 24             	mov    %eax,(%esp)
c0025029:	e8 b1 fd ff ff       	call   c0024ddf <block_read>
}
c002502e:	83 c4 1c             	add    $0x1c,%esp
c0025031:	c3                   	ret    

c0025032 <read_partition_table>:
{
c0025032:	55                   	push   %ebp
c0025033:	57                   	push   %edi
c0025034:	56                   	push   %esi
c0025035:	53                   	push   %ebx
c0025036:	81 ec dc 00 00 00    	sub    $0xdc,%esp
c002503c:	89 c5                	mov    %eax,%ebp
c002503e:	89 d6                	mov    %edx,%esi
c0025040:	89 4c 24 20          	mov    %ecx,0x20(%esp)
  if (sector >= block_size (block))
c0025044:	89 04 24             	mov    %eax,(%esp)
c0025047:	e8 3c fe ff ff       	call   c0024e88 <block_size>
c002504c:	39 f0                	cmp    %esi,%eax
c002504e:	77 21                	ja     c0025071 <read_partition_table+0x3f>
      printf ("%s: Partition table at sector %"PRDSNu" past end of device.\n",
c0025050:	89 2c 24             	mov    %ebp,(%esp)
c0025053:	e8 38 fe ff ff       	call   c0024e90 <block_name>
c0025058:	89 74 24 08          	mov    %esi,0x8(%esp)
c002505c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025060:	c7 04 24 f8 f3 02 c0 	movl   $0xc002f3f8,(%esp)
c0025067:	e8 c2 1a 00 00       	call   c0026b2e <printf>
      return;
c002506c:	e9 3b 03 00 00       	jmp    c00253ac <read_partition_table+0x37a>
  pt = malloc (sizeof *pt);
c0025071:	c7 04 24 00 02 00 00 	movl   $0x200,(%esp)
c0025078:	e8 a7 e9 ff ff       	call   c0023a24 <malloc>
c002507d:	89 c7                	mov    %eax,%edi
  if (pt == NULL)
c002507f:	85 c0                	test   %eax,%eax
c0025081:	75 24                	jne    c00250a7 <read_partition_table+0x75>
    PANIC ("Failed to allocate memory for partition table.");
c0025083:	c7 44 24 0c 30 f4 02 	movl   $0xc002f430,0xc(%esp)
c002508a:	c0 
c002508b:	c7 44 24 08 30 d9 02 	movl   $0xc002d930,0x8(%esp)
c0025092:	c0 
c0025093:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c002509a:	00 
c002509b:	c7 04 24 67 ef 02 c0 	movl   $0xc002ef67,(%esp)
c00250a2:	e8 dc 38 00 00       	call   c0028983 <debug_panic>
  block_read (block, 0, pt);
c00250a7:	89 44 24 08          	mov    %eax,0x8(%esp)
c00250ab:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00250b2:	00 
c00250b3:	89 2c 24             	mov    %ebp,(%esp)
c00250b6:	e8 24 fd ff ff       	call   c0024ddf <block_read>
  if (pt->signature != 0xaa55)
c00250bb:	66 81 bf fe 01 00 00 	cmpw   $0xaa55,0x1fe(%edi)
c00250c2:	55 aa 
c00250c4:	74 4a                	je     c0025110 <read_partition_table+0xde>
      if (primary_extended_sector == 0)
c00250c6:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c00250cb:	75 1a                	jne    c00250e7 <read_partition_table+0xb5>
        printf ("%s: Invalid partition table signature\n", block_name (block));
c00250cd:	89 2c 24             	mov    %ebp,(%esp)
c00250d0:	e8 bb fd ff ff       	call   c0024e90 <block_name>
c00250d5:	89 44 24 04          	mov    %eax,0x4(%esp)
c00250d9:	c7 04 24 60 f4 02 c0 	movl   $0xc002f460,(%esp)
c00250e0:	e8 49 1a 00 00       	call   c0026b2e <printf>
c00250e5:	eb 1c                	jmp    c0025103 <read_partition_table+0xd1>
        printf ("%s: Invalid extended partition table in sector %"PRDSNu"\n",
c00250e7:	89 2c 24             	mov    %ebp,(%esp)
c00250ea:	e8 a1 fd ff ff       	call   c0024e90 <block_name>
c00250ef:	89 74 24 08          	mov    %esi,0x8(%esp)
c00250f3:	89 44 24 04          	mov    %eax,0x4(%esp)
c00250f7:	c7 04 24 88 f4 02 c0 	movl   $0xc002f488,(%esp)
c00250fe:	e8 2b 1a 00 00       	call   c0026b2e <printf>
      free (pt);
c0025103:	89 3c 24             	mov    %edi,(%esp)
c0025106:	e8 a0 ea ff ff       	call   c0023bab <free>
      return;
c002510b:	e9 9c 02 00 00       	jmp    c00253ac <read_partition_table+0x37a>
c0025110:	89 fb                	mov    %edi,%ebx
  if (pt->signature != 0xaa55)
c0025112:	b8 04 00 00 00       	mov    $0x4,%eax
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025117:	89 7c 24 28          	mov    %edi,0x28(%esp)
c002511b:	89 74 24 24          	mov    %esi,0x24(%esp)
c002511f:	89 c6                	mov    %eax,%esi
c0025121:	89 df                	mov    %ebx,%edi
      if (e->size == 0 || e->type == 0)
c0025123:	83 bb ca 01 00 00 00 	cmpl   $0x0,0x1ca(%ebx)
c002512a:	0f 84 64 02 00 00    	je     c0025394 <read_partition_table+0x362>
c0025130:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c0025137:	84 c0                	test   %al,%al
c0025139:	0f 84 55 02 00 00    	je     c0025394 <read_partition_table+0x362>
               || e->type == 0x0f    /* Windows 98 extended partition. */
c002513f:	89 c2                	mov    %eax,%edx
c0025141:	83 e2 7f             	and    $0x7f,%edx
      else if (e->type == 0x05       /* Extended partition. */
c0025144:	80 fa 05             	cmp    $0x5,%dl
c0025147:	74 08                	je     c0025151 <read_partition_table+0x11f>
c0025149:	3c 0f                	cmp    $0xf,%al
c002514b:	74 04                	je     c0025151 <read_partition_table+0x11f>
               || e->type == 0xc5)   /* DR-DOS extended partition. */
c002514d:	3c c5                	cmp    $0xc5,%al
c002514f:	75 67                	jne    c00251b8 <read_partition_table+0x186>
          printf ("%s: Extended partition in sector %"PRDSNu"\n",
c0025151:	89 2c 24             	mov    %ebp,(%esp)
c0025154:	e8 37 fd ff ff       	call   c0024e90 <block_name>
c0025159:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c002515d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0025161:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025165:	c7 04 24 bc f4 02 c0 	movl   $0xc002f4bc,(%esp)
c002516c:	e8 bd 19 00 00       	call   c0026b2e <printf>
          if (sector == 0)
c0025171:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0025176:	75 1e                	jne    c0025196 <read_partition_table+0x164>
            read_partition_table (block, e->offset, e->offset, part_nr);
c0025178:	8b 97 c6 01 00 00    	mov    0x1c6(%edi),%edx
c002517e:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c0025185:	89 04 24             	mov    %eax,(%esp)
c0025188:	89 d1                	mov    %edx,%ecx
c002518a:	89 e8                	mov    %ebp,%eax
c002518c:	e8 a1 fe ff ff       	call   c0025032 <read_partition_table>
c0025191:	e9 fe 01 00 00       	jmp    c0025394 <read_partition_table+0x362>
            read_partition_table (block, e->offset + primary_extended_sector,
c0025196:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c002519a:	89 ca                	mov    %ecx,%edx
c002519c:	03 97 c6 01 00 00    	add    0x1c6(%edi),%edx
c00251a2:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251a9:	89 04 24             	mov    %eax,(%esp)
c00251ac:	89 e8                	mov    %ebp,%eax
c00251ae:	e8 7f fe ff ff       	call   c0025032 <read_partition_table>
c00251b3:	e9 dc 01 00 00       	jmp    c0025394 <read_partition_table+0x362>
          ++*part_nr;
c00251b8:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251bf:	8b 00                	mov    (%eax),%eax
c00251c1:	83 c0 01             	add    $0x1,%eax
c00251c4:	89 44 24 34          	mov    %eax,0x34(%esp)
c00251c8:	8b 8c 24 f0 00 00 00 	mov    0xf0(%esp),%ecx
c00251cf:	89 01                	mov    %eax,(%ecx)
          found_partition (block, e->type, e->offset + sector,
c00251d1:	8b 83 ca 01 00 00    	mov    0x1ca(%ebx),%eax
c00251d7:	89 44 24 30          	mov    %eax,0x30(%esp)
c00251db:	8b 44 24 24          	mov    0x24(%esp),%eax
c00251df:	03 83 c6 01 00 00    	add    0x1c6(%ebx),%eax
c00251e5:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c00251e9:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c00251f0:	88 44 24 3b          	mov    %al,0x3b(%esp)
  if (start >= block_size (block))
c00251f4:	89 2c 24             	mov    %ebp,(%esp)
c00251f7:	e8 8c fc ff ff       	call   c0024e88 <block_size>
c00251fc:	39 44 24 2c          	cmp    %eax,0x2c(%esp)
c0025200:	72 2d                	jb     c002522f <read_partition_table+0x1fd>
    printf ("%s%d: Partition starts past end of device (sector %"PRDSNu")\n",
c0025202:	89 2c 24             	mov    %ebp,(%esp)
c0025205:	e8 86 fc ff ff       	call   c0024e90 <block_name>
c002520a:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002520e:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0025212:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025216:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002521a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002521e:	c7 04 24 e4 f4 02 c0 	movl   $0xc002f4e4,(%esp)
c0025225:	e8 04 19 00 00       	call   c0026b2e <printf>
c002522a:	e9 65 01 00 00       	jmp    c0025394 <read_partition_table+0x362>
  else if (start + size < start || start + size > block_size (block))
c002522f:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
c0025233:	03 7c 24 30          	add    0x30(%esp),%edi
c0025237:	72 0c                	jb     c0025245 <read_partition_table+0x213>
c0025239:	89 2c 24             	mov    %ebp,(%esp)
c002523c:	e8 47 fc ff ff       	call   c0024e88 <block_size>
c0025241:	39 c7                	cmp    %eax,%edi
c0025243:	76 3d                	jbe    c0025282 <read_partition_table+0x250>
    printf ("%s%d: Partition end (%"PRDSNu") past end of device (%"PRDSNu")\n",
c0025245:	89 2c 24             	mov    %ebp,(%esp)
c0025248:	e8 3b fc ff ff       	call   c0024e88 <block_size>
c002524d:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c0025251:	89 2c 24             	mov    %ebp,(%esp)
c0025254:	e8 37 fc ff ff       	call   c0024e90 <block_name>
c0025259:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002525d:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0025261:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025265:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025269:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002526d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025271:	c7 04 24 1c f5 02 c0 	movl   $0xc002f51c,(%esp)
c0025278:	e8 b1 18 00 00       	call   c0026b2e <printf>
c002527d:	e9 12 01 00 00       	jmp    c0025394 <read_partition_table+0x362>
      enum block_type type = (part_type == 0x20 ? BLOCK_KERNEL
c0025282:	c7 44 24 3c 00 00 00 	movl   $0x0,0x3c(%esp)
c0025289:	00 
c002528a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
c002528f:	3c 20                	cmp    $0x20,%al
c0025291:	74 28                	je     c00252bb <read_partition_table+0x289>
c0025293:	c7 44 24 3c 01 00 00 	movl   $0x1,0x3c(%esp)
c002529a:	00 
c002529b:	3c 21                	cmp    $0x21,%al
c002529d:	74 1c                	je     c00252bb <read_partition_table+0x289>
c002529f:	c7 44 24 3c 02 00 00 	movl   $0x2,0x3c(%esp)
c00252a6:	00 
c00252a7:	3c 22                	cmp    $0x22,%al
c00252a9:	74 10                	je     c00252bb <read_partition_table+0x289>
c00252ab:	3c 23                	cmp    $0x23,%al
c00252ad:	0f 95 c0             	setne  %al
c00252b0:	0f b6 c0             	movzbl %al,%eax
c00252b3:	8d 44 00 03          	lea    0x3(%eax,%eax,1),%eax
c00252b7:	89 44 24 3c          	mov    %eax,0x3c(%esp)
      p = malloc (sizeof *p);
c00252bb:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c00252c2:	e8 5d e7 ff ff       	call   c0023a24 <malloc>
c00252c7:	89 c7                	mov    %eax,%edi
      if (p == NULL)
c00252c9:	85 c0                	test   %eax,%eax
c00252cb:	75 24                	jne    c00252f1 <read_partition_table+0x2bf>
        PANIC ("Failed to allocate memory for partition descriptor");
c00252cd:	c7 44 24 0c 50 f5 02 	movl   $0xc002f550,0xc(%esp)
c00252d4:	c0 
c00252d5:	c7 44 24 08 20 d9 02 	movl   $0xc002d920,0x8(%esp)
c00252dc:	c0 
c00252dd:	c7 44 24 04 b1 00 00 	movl   $0xb1,0x4(%esp)
c00252e4:	00 
c00252e5:	c7 04 24 67 ef 02 c0 	movl   $0xc002ef67,(%esp)
c00252ec:	e8 92 36 00 00       	call   c0028983 <debug_panic>
      p->block = block;
c00252f1:	89 28                	mov    %ebp,(%eax)
      p->start = start;
c00252f3:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00252f7:	89 47 04             	mov    %eax,0x4(%edi)
      snprintf (name, sizeof name, "%s%d", block_name (block), part_nr);
c00252fa:	89 2c 24             	mov    %ebp,(%esp)
c00252fd:	e8 8e fb ff ff       	call   c0024e90 <block_name>
c0025302:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025306:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c002530a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002530e:	c7 44 24 08 81 ef 02 	movl   $0xc002ef81,0x8(%esp)
c0025315:	c0 
c0025316:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002531d:	00 
c002531e:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025322:	89 04 24             	mov    %eax,(%esp)
c0025325:	e8 05 1f 00 00       	call   c002722f <snprintf>
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c002532a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c002532f:	8b 14 85 20 d5 02 c0 	mov    -0x3ffd2ae0(,%eax,4),%edx
c0025336:	85 d2                	test   %edx,%edx
c0025338:	b9 5f ef 02 c0       	mov    $0xc002ef5f,%ecx
c002533d:	0f 44 d1             	cmove  %ecx,%edx
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025340:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025344:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0025348:	c7 44 24 08 86 ef 02 	movl   $0xc002ef86,0x8(%esp)
c002534f:	c0 
c0025350:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025357:	00 
c0025358:	8d 44 24 50          	lea    0x50(%esp),%eax
c002535c:	89 04 24             	mov    %eax,(%esp)
c002535f:	e8 cb 1e 00 00       	call   c002722f <snprintf>
      block_register (name, type, extra_info, size, &partition_operations, p);
c0025364:	89 7c 24 14          	mov    %edi,0x14(%esp)
c0025368:	c7 44 24 10 68 5a 03 	movl   $0xc0035a68,0x10(%esp)
c002536f:	c0 
c0025370:	8b 44 24 30          	mov    0x30(%esp),%eax
c0025374:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025378:	8d 44 24 50          	lea    0x50(%esp),%eax
c002537c:	89 44 24 08          	mov    %eax,0x8(%esp)
c0025380:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c0025384:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025388:	8d 44 24 40          	lea    0x40(%esp),%eax
c002538c:	89 04 24             	mov    %eax,(%esp)
c002538f:	e8 6d fb ff ff       	call   c0024f01 <block_register>
c0025394:	83 c3 10             	add    $0x10,%ebx
  for (i = 0; i < sizeof pt->partitions / sizeof *pt->partitions; i++)
c0025397:	83 ee 01             	sub    $0x1,%esi
c002539a:	0f 85 81 fd ff ff    	jne    c0025121 <read_partition_table+0xef>
c00253a0:	8b 7c 24 28          	mov    0x28(%esp),%edi
  free (pt);
c00253a4:	89 3c 24             	mov    %edi,(%esp)
c00253a7:	e8 ff e7 ff ff       	call   c0023bab <free>
}
c00253ac:	81 c4 dc 00 00 00    	add    $0xdc,%esp
c00253b2:	5b                   	pop    %ebx
c00253b3:	5e                   	pop    %esi
c00253b4:	5f                   	pop    %edi
c00253b5:	5d                   	pop    %ebp
c00253b6:	c3                   	ret    

c00253b7 <partition_write>:
/* Write sector SECTOR to partition P from BUFFER, which must
   contain BLOCK_SECTOR_SIZE bytes.  Returns after the block has
   acknowledged receiving the data. */
static void
partition_write (void *p_, block_sector_t sector, const void *buffer)
{
c00253b7:	83 ec 1c             	sub    $0x1c,%esp
c00253ba:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_write (p->block, p->start + sector, buffer);
c00253be:	8b 54 24 28          	mov    0x28(%esp),%edx
c00253c2:	89 54 24 08          	mov    %edx,0x8(%esp)
c00253c6:	8b 54 24 24          	mov    0x24(%esp),%edx
c00253ca:	03 50 04             	add    0x4(%eax),%edx
c00253cd:	89 54 24 04          	mov    %edx,0x4(%esp)
c00253d1:	8b 00                	mov    (%eax),%eax
c00253d3:	89 04 24             	mov    %eax,(%esp)
c00253d6:	e8 3f fa ff ff       	call   c0024e1a <block_write>
}
c00253db:	83 c4 1c             	add    $0x1c,%esp
c00253de:	c3                   	ret    

c00253df <partition_scan>:
{
c00253df:	53                   	push   %ebx
c00253e0:	83 ec 28             	sub    $0x28,%esp
c00253e3:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  int part_nr = 0;
c00253e7:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c00253ee:	00 
  read_partition_table (block, 0, 0, &part_nr);
c00253ef:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c00253f3:	89 04 24             	mov    %eax,(%esp)
c00253f6:	b9 00 00 00 00       	mov    $0x0,%ecx
c00253fb:	ba 00 00 00 00       	mov    $0x0,%edx
c0025400:	89 d8                	mov    %ebx,%eax
c0025402:	e8 2b fc ff ff       	call   c0025032 <read_partition_table>
  if (part_nr == 0)
c0025407:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c002540c:	75 18                	jne    c0025426 <partition_scan+0x47>
    printf ("%s: Device contains no partitions\n", block_name (block));
c002540e:	89 1c 24             	mov    %ebx,(%esp)
c0025411:	e8 7a fa ff ff       	call   c0024e90 <block_name>
c0025416:	89 44 24 04          	mov    %eax,0x4(%esp)
c002541a:	c7 04 24 84 f5 02 c0 	movl   $0xc002f584,(%esp)
c0025421:	e8 08 17 00 00       	call   c0026b2e <printf>
}
c0025426:	83 c4 28             	add    $0x28,%esp
c0025429:	5b                   	pop    %ebx
c002542a:	c3                   	ret    
c002542b:	90                   	nop
c002542c:	90                   	nop
c002542d:	90                   	nop
c002542e:	90                   	nop
c002542f:	90                   	nop

c0025430 <descramble_ata_string>:
/* Translates STRING, which consists of SIZE bytes in a funky
   format, into a null-terminated string in-place.  Drops
   trailing whitespace and null bytes.  Returns STRING.  */
static char *
descramble_ata_string (char *string, int size) 
{
c0025430:	57                   	push   %edi
c0025431:	56                   	push   %esi
c0025432:	53                   	push   %ebx
c0025433:	89 d7                	mov    %edx,%edi
  int i;

  /* Swap all pairs of bytes. */
  for (i = 0; i + 1 < size; i += 2)
c0025435:	83 fa 01             	cmp    $0x1,%edx
c0025438:	7e 1f                	jle    c0025459 <descramble_ata_string+0x29>
c002543a:	89 c1                	mov    %eax,%ecx
c002543c:	8d 5a fe             	lea    -0x2(%edx),%ebx
c002543f:	83 e3 fe             	and    $0xfffffffe,%ebx
c0025442:	8d 74 18 02          	lea    0x2(%eax,%ebx,1),%esi
    {
      char tmp = string[i];
c0025446:	0f b6 19             	movzbl (%ecx),%ebx
      string[i] = string[i + 1];
c0025449:	0f b6 51 01          	movzbl 0x1(%ecx),%edx
c002544d:	88 11                	mov    %dl,(%ecx)
      string[i + 1] = tmp;
c002544f:	88 59 01             	mov    %bl,0x1(%ecx)
c0025452:	83 c1 02             	add    $0x2,%ecx
  for (i = 0; i + 1 < size; i += 2)
c0025455:	39 f1                	cmp    %esi,%ecx
c0025457:	75 ed                	jne    c0025446 <descramble_ata_string+0x16>
    }

  /* Find the last non-white, non-null character. */
  for (size--; size > 0; size--)
c0025459:	8d 57 ff             	lea    -0x1(%edi),%edx
c002545c:	85 d2                	test   %edx,%edx
c002545e:	7e 24                	jle    c0025484 <descramble_ata_string+0x54>
    {
      int c = string[size - 1];
c0025460:	0f b6 4c 10 ff       	movzbl -0x1(%eax,%edx,1),%ecx
      if (c != '\0' && !isspace (c))
c0025465:	f6 c1 df             	test   $0xdf,%cl
c0025468:	74 15                	je     c002547f <descramble_ata_string+0x4f>
  return (c == ' ' || c == '\f' || c == '\n'
c002546a:	8d 59 f4             	lea    -0xc(%ecx),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c002546d:	80 fb 01             	cmp    $0x1,%bl
c0025470:	76 0d                	jbe    c002547f <descramble_ata_string+0x4f>
c0025472:	80 f9 0a             	cmp    $0xa,%cl
c0025475:	74 08                	je     c002547f <descramble_ata_string+0x4f>
c0025477:	83 e1 fd             	and    $0xfffffffd,%ecx
c002547a:	80 f9 09             	cmp    $0x9,%cl
c002547d:	75 05                	jne    c0025484 <descramble_ata_string+0x54>
  for (size--; size > 0; size--)
c002547f:	83 ea 01             	sub    $0x1,%edx
c0025482:	75 dc                	jne    c0025460 <descramble_ata_string+0x30>
        break; 
    }
  string[size] = '\0';
c0025484:	c6 04 10 00          	movb   $0x0,(%eax,%edx,1)

  return string;
}
c0025488:	5b                   	pop    %ebx
c0025489:	5e                   	pop    %esi
c002548a:	5f                   	pop    %edi
c002548b:	c3                   	ret    

c002548c <interrupt_handler>:
}

/* ATA interrupt handler. */
static void
interrupt_handler (struct intr_frame *f) 
{
c002548c:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c;

  for (c = channels; c < channels + CHANNEL_CNT; c++)
    if (f->vec_no == c->irq)
c002548f:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025493:	8b 40 30             	mov    0x30(%eax),%eax
c0025496:	0f b6 15 4a 78 03 c0 	movzbl 0xc003784a,%edx
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c002549d:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
    if (f->vec_no == c->irq)
c00254a2:	39 d0                	cmp    %edx,%eax
c00254a4:	75 3e                	jne    c00254e4 <interrupt_handler+0x58>
c00254a6:	eb 0a                	jmp    c00254b2 <interrupt_handler+0x26>
c00254a8:	0f b6 51 0a          	movzbl 0xa(%ecx),%edx
c00254ac:	39 c2                	cmp    %eax,%edx
c00254ae:	75 34                	jne    c00254e4 <interrupt_handler+0x58>
c00254b0:	eb 05                	jmp    c00254b7 <interrupt_handler+0x2b>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254b2:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
      {
        if (c->expecting_interrupt) 
c00254b7:	80 79 30 00          	cmpb   $0x0,0x30(%ecx)
c00254bb:	74 15                	je     c00254d2 <interrupt_handler+0x46>
          {
            inb (reg_status (c));               /* Acknowledge interrupt. */
c00254bd:	0f b7 41 08          	movzwl 0x8(%ecx),%eax
c00254c1:	8d 50 07             	lea    0x7(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00254c4:	ec                   	in     (%dx),%al
            sema_up (&c->completion_wait);      /* Wake up waiter. */
c00254c5:	83 c1 34             	add    $0x34,%ecx
c00254c8:	89 0c 24             	mov    %ecx,(%esp)
c00254cb:	e8 77 d7 ff ff       	call   c0022c47 <sema_up>
c00254d0:	eb 41                	jmp    c0025513 <interrupt_handler+0x87>
          }
        else
          printf ("%s: unexpected interrupt\n", c->name);
c00254d2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00254d6:	c7 04 24 a7 f5 02 c0 	movl   $0xc002f5a7,(%esp)
c00254dd:	e8 4c 16 00 00       	call   c0026b2e <printf>
c00254e2:	eb 2f                	jmp    c0025513 <interrupt_handler+0x87>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254e4:	83 c1 70             	add    $0x70,%ecx
c00254e7:	81 f9 20 79 03 c0    	cmp    $0xc0037920,%ecx
c00254ed:	72 b9                	jb     c00254a8 <interrupt_handler+0x1c>
        return;
      }

  NOT_REACHED ();
c00254ef:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c00254f6:	c0 
c00254f7:	c7 44 24 08 8c d9 02 	movl   $0xc002d98c,0x8(%esp)
c00254fe:	c0 
c00254ff:	c7 44 24 04 0c 02 00 	movl   $0x20c,0x4(%esp)
c0025506:	00 
c0025507:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c002550e:	e8 70 34 00 00       	call   c0028983 <debug_panic>
}
c0025513:	83 c4 1c             	add    $0x1c,%esp
c0025516:	c3                   	ret    

c0025517 <wait_until_idle>:
{
c0025517:	56                   	push   %esi
c0025518:	53                   	push   %ebx
c0025519:	83 ec 14             	sub    $0x14,%esp
c002551c:	89 c6                	mov    %eax,%esi
      if ((inb (reg_status (d->channel)) & (STA_BSY | STA_DRQ)) == 0)
c002551e:	8b 40 08             	mov    0x8(%eax),%eax
c0025521:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025525:	83 c2 07             	add    $0x7,%edx
c0025528:	ec                   	in     (%dx),%al
c0025529:	a8 88                	test   $0x88,%al
c002552b:	75 3c                	jne    c0025569 <wait_until_idle+0x52>
c002552d:	eb 55                	jmp    c0025584 <wait_until_idle+0x6d>
c002552f:	8b 46 08             	mov    0x8(%esi),%eax
c0025532:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025536:	83 c2 07             	add    $0x7,%edx
c0025539:	ec                   	in     (%dx),%al
c002553a:	a8 88                	test   $0x88,%al
c002553c:	74 46                	je     c0025584 <wait_until_idle+0x6d>
      timer_usleep (10);
c002553e:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025545:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002554c:	00 
c002554d:	e8 59 ee ff ff       	call   c00243ab <timer_usleep>
  for (i = 0; i < 1000; i++) 
c0025552:	83 eb 01             	sub    $0x1,%ebx
c0025555:	75 d8                	jne    c002552f <wait_until_idle+0x18>
  printf ("%s: idle timeout\n", d->name);
c0025557:	89 74 24 04          	mov    %esi,0x4(%esp)
c002555b:	c7 04 24 d5 f5 02 c0 	movl   $0xc002f5d5,(%esp)
c0025562:	e8 c7 15 00 00       	call   c0026b2e <printf>
c0025567:	eb 1b                	jmp    c0025584 <wait_until_idle+0x6d>
      timer_usleep (10);
c0025569:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025570:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025577:	00 
c0025578:	e8 2e ee ff ff       	call   c00243ab <timer_usleep>
c002557d:	bb e7 03 00 00       	mov    $0x3e7,%ebx
c0025582:	eb ab                	jmp    c002552f <wait_until_idle+0x18>
}
c0025584:	83 c4 14             	add    $0x14,%esp
c0025587:	5b                   	pop    %ebx
c0025588:	5e                   	pop    %esi
c0025589:	c3                   	ret    

c002558a <select_device>:
{
c002558a:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c = d->channel;
c002558d:	8b 50 08             	mov    0x8(%eax),%edx
  if (d->dev_no == 1)
c0025590:	83 78 0c 01          	cmpl   $0x1,0xc(%eax)
  uint8_t dev = DEV_MBS;
c0025594:	b8 a0 ff ff ff       	mov    $0xffffffa0,%eax
c0025599:	b9 b0 ff ff ff       	mov    $0xffffffb0,%ecx
c002559e:	0f 44 c1             	cmove  %ecx,%eax
  outb (reg_device (c), dev);
c00255a1:	0f b7 4a 08          	movzwl 0x8(%edx),%ecx
c00255a5:	8d 51 06             	lea    0x6(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00255a8:	ee                   	out    %al,(%dx)
  inb (reg_alt_status (c));
c00255a9:	8d 91 06 02 00 00    	lea    0x206(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00255af:	ec                   	in     (%dx),%al
  timer_nsleep (400);
c00255b0:	c7 04 24 90 01 00 00 	movl   $0x190,(%esp)
c00255b7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00255be:	00 
c00255bf:	e8 00 ee ff ff       	call   c00243c4 <timer_nsleep>
}
c00255c4:	83 c4 1c             	add    $0x1c,%esp
c00255c7:	c3                   	ret    

c00255c8 <check_device_type>:
{
c00255c8:	55                   	push   %ebp
c00255c9:	57                   	push   %edi
c00255ca:	56                   	push   %esi
c00255cb:	53                   	push   %ebx
c00255cc:	83 ec 0c             	sub    $0xc,%esp
c00255cf:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c00255d1:	8b 70 08             	mov    0x8(%eax),%esi
  select_device (d);
c00255d4:	e8 b1 ff ff ff       	call   c002558a <select_device>
  error = inb (reg_error (c));
c00255d9:	0f b7 4e 08          	movzwl 0x8(%esi),%ecx
c00255dd:	8d 51 01             	lea    0x1(%ecx),%edx
c00255e0:	ec                   	in     (%dx),%al
c00255e1:	89 c6                	mov    %eax,%esi
  lbam = inb (reg_lbam (c));
c00255e3:	8d 51 04             	lea    0x4(%ecx),%edx
c00255e6:	ec                   	in     (%dx),%al
c00255e7:	89 c7                	mov    %eax,%edi
  lbah = inb (reg_lbah (c));
c00255e9:	8d 51 05             	lea    0x5(%ecx),%edx
c00255ec:	ec                   	in     (%dx),%al
c00255ed:	89 c5                	mov    %eax,%ebp
  status = inb (reg_status (c));
c00255ef:	8d 51 07             	lea    0x7(%ecx),%edx
c00255f2:	ec                   	in     (%dx),%al
  if ((error != 1 && (error != 0x81 || d->dev_no == 1))
c00255f3:	89 f1                	mov    %esi,%ecx
c00255f5:	80 f9 01             	cmp    $0x1,%cl
c00255f8:	74 0b                	je     c0025605 <check_device_type+0x3d>
c00255fa:	80 f9 81             	cmp    $0x81,%cl
c00255fd:	75 0e                	jne    c002560d <check_device_type+0x45>
c00255ff:	83 7b 0c 01          	cmpl   $0x1,0xc(%ebx)
c0025603:	74 08                	je     c002560d <check_device_type+0x45>
      || (status & STA_DRDY) == 0
c0025605:	a8 40                	test   $0x40,%al
c0025607:	74 04                	je     c002560d <check_device_type+0x45>
      || (status & STA_BSY) != 0)
c0025609:	84 c0                	test   %al,%al
c002560b:	79 0d                	jns    c002561a <check_device_type+0x52>
      d->is_ata = false;
c002560d:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return error != 0x81;      
c0025611:	89 f0                	mov    %esi,%eax
c0025613:	3c 81                	cmp    $0x81,%al
c0025615:	0f 95 c0             	setne  %al
c0025618:	eb 2b                	jmp    c0025645 <check_device_type+0x7d>
      d->is_ata = (lbam == 0 && lbah == 0) || (lbam == 0x3c && lbah == 0xc3);
c002561a:	b8 01 00 00 00       	mov    $0x1,%eax
c002561f:	89 ea                	mov    %ebp,%edx
c0025621:	89 f9                	mov    %edi,%ecx
c0025623:	08 ca                	or     %cl,%dl
c0025625:	74 12                	je     c0025639 <check_device_type+0x71>
c0025627:	89 e8                	mov    %ebp,%eax
c0025629:	3c c3                	cmp    $0xc3,%al
c002562b:	0f 94 c0             	sete   %al
c002562e:	80 f9 3c             	cmp    $0x3c,%cl
c0025631:	0f 94 c2             	sete   %dl
c0025634:	0f b6 d2             	movzbl %dl,%edx
c0025637:	21 d0                	and    %edx,%eax
c0025639:	88 43 10             	mov    %al,0x10(%ebx)
c002563c:	80 63 10 01          	andb   $0x1,0x10(%ebx)
      return true; 
c0025640:	b8 01 00 00 00       	mov    $0x1,%eax
}
c0025645:	83 c4 0c             	add    $0xc,%esp
c0025648:	5b                   	pop    %ebx
c0025649:	5e                   	pop    %esi
c002564a:	5f                   	pop    %edi
c002564b:	5d                   	pop    %ebp
c002564c:	c3                   	ret    

c002564d <select_sector>:
{
c002564d:	57                   	push   %edi
c002564e:	56                   	push   %esi
c002564f:	53                   	push   %ebx
c0025650:	83 ec 20             	sub    $0x20,%esp
c0025653:	89 c6                	mov    %eax,%esi
c0025655:	89 d3                	mov    %edx,%ebx
  struct channel *c = d->channel;
c0025657:	8b 78 08             	mov    0x8(%eax),%edi
  ASSERT (sec_no < (1UL << 28));
c002565a:	81 fa ff ff ff 0f    	cmp    $0xfffffff,%edx
c0025660:	76 2c                	jbe    c002568e <select_sector+0x41>
c0025662:	c7 44 24 10 e7 f5 02 	movl   $0xc002f5e7,0x10(%esp)
c0025669:	c0 
c002566a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025671:	c0 
c0025672:	c7 44 24 08 60 d9 02 	movl   $0xc002d960,0x8(%esp)
c0025679:	c0 
c002567a:	c7 44 24 04 89 01 00 	movl   $0x189,0x4(%esp)
c0025681:	00 
c0025682:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025689:	e8 f5 32 00 00       	call   c0028983 <debug_panic>
  wait_until_idle (d);
c002568e:	e8 84 fe ff ff       	call   c0025517 <wait_until_idle>
  select_device (d);
c0025693:	89 f0                	mov    %esi,%eax
c0025695:	e8 f0 fe ff ff       	call   c002558a <select_device>
  wait_until_idle (d);
c002569a:	89 f0                	mov    %esi,%eax
c002569c:	e8 76 fe ff ff       	call   c0025517 <wait_until_idle>
  outb (reg_nsect (c), 1);
c00256a1:	0f b7 4f 08          	movzwl 0x8(%edi),%ecx
c00256a5:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00256a8:	b8 01 00 00 00       	mov    $0x1,%eax
c00256ad:	ee                   	out    %al,(%dx)
  outb (reg_lbal (c), sec_no);
c00256ae:	8d 51 03             	lea    0x3(%ecx),%edx
c00256b1:	89 d8                	mov    %ebx,%eax
c00256b3:	ee                   	out    %al,(%dx)
c00256b4:	0f b6 c7             	movzbl %bh,%eax
  outb (reg_lbam (c), sec_no >> 8);
c00256b7:	8d 51 04             	lea    0x4(%ecx),%edx
c00256ba:	ee                   	out    %al,(%dx)
  outb (reg_lbah (c), (sec_no >> 16));
c00256bb:	89 d8                	mov    %ebx,%eax
c00256bd:	c1 e8 10             	shr    $0x10,%eax
c00256c0:	8d 51 05             	lea    0x5(%ecx),%edx
c00256c3:	ee                   	out    %al,(%dx)
  outb (reg_device (c),
c00256c4:	83 7e 0c 01          	cmpl   $0x1,0xc(%esi)
c00256c8:	b8 f0 ff ff ff       	mov    $0xfffffff0,%eax
c00256cd:	ba e0 ff ff ff       	mov    $0xffffffe0,%edx
c00256d2:	0f 45 c2             	cmovne %edx,%eax
        DEV_MBS | DEV_LBA | (d->dev_no == 1 ? DEV_DEV : 0) | (sec_no >> 24));
c00256d5:	c1 eb 18             	shr    $0x18,%ebx
  outb (reg_device (c),
c00256d8:	09 d8                	or     %ebx,%eax
c00256da:	8d 51 06             	lea    0x6(%ecx),%edx
c00256dd:	ee                   	out    %al,(%dx)
}
c00256de:	83 c4 20             	add    $0x20,%esp
c00256e1:	5b                   	pop    %ebx
c00256e2:	5e                   	pop    %esi
c00256e3:	5f                   	pop    %edi
c00256e4:	c3                   	ret    

c00256e5 <wait_while_busy>:
{
c00256e5:	57                   	push   %edi
c00256e6:	56                   	push   %esi
c00256e7:	53                   	push   %ebx
c00256e8:	83 ec 10             	sub    $0x10,%esp
c00256eb:	89 c7                	mov    %eax,%edi
  struct channel *c = d->channel;
c00256ed:	8b 70 08             	mov    0x8(%eax),%esi
  for (i = 0; i < 3000; i++)
c00256f0:	bb 00 00 00 00       	mov    $0x0,%ebx
c00256f5:	eb 18                	jmp    c002570f <wait_while_busy+0x2a>
      if (i == 700)
c00256f7:	81 fb bc 02 00 00    	cmp    $0x2bc,%ebx
c00256fd:	75 10                	jne    c002570f <wait_while_busy+0x2a>
        printf ("%s: busy, waiting...", d->name);
c00256ff:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0025703:	c7 04 24 fc f5 02 c0 	movl   $0xc002f5fc,(%esp)
c002570a:	e8 1f 14 00 00       	call   c0026b2e <printf>
      if (!(inb (reg_alt_status (c)) & STA_BSY)) 
c002570f:	0f b7 46 08          	movzwl 0x8(%esi),%eax
c0025713:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025719:	ec                   	in     (%dx),%al
c002571a:	84 c0                	test   %al,%al
c002571c:	78 26                	js     c0025744 <wait_while_busy+0x5f>
          if (i >= 700)
c002571e:	81 fb bb 02 00 00    	cmp    $0x2bb,%ebx
c0025724:	7e 0c                	jle    c0025732 <wait_while_busy+0x4d>
            printf ("ok\n");
c0025726:	c7 04 24 11 f6 02 c0 	movl   $0xc002f611,(%esp)
c002572d:	e8 79 4f 00 00       	call   c002a6ab <puts>
          return (inb (reg_alt_status (c)) & STA_DRQ) != 0;
c0025732:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c0025736:	66 81 c2 06 02       	add    $0x206,%dx
c002573b:	ec                   	in     (%dx),%al
c002573c:	c0 e8 03             	shr    $0x3,%al
c002573f:	83 e0 01             	and    $0x1,%eax
c0025742:	eb 30                	jmp    c0025774 <wait_while_busy+0x8f>
      timer_msleep (10);
c0025744:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002574b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025752:	00 
c0025753:	e8 3a ec ff ff       	call   c0024392 <timer_msleep>
  for (i = 0; i < 3000; i++)
c0025758:	83 c3 01             	add    $0x1,%ebx
c002575b:	81 fb b8 0b 00 00    	cmp    $0xbb8,%ebx
c0025761:	75 94                	jne    c00256f7 <wait_while_busy+0x12>
  printf ("failed\n");
c0025763:	c7 04 24 2c ff 02 c0 	movl   $0xc002ff2c,(%esp)
c002576a:	e8 3c 4f 00 00       	call   c002a6ab <puts>
  return false;
c002576f:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0025774:	83 c4 10             	add    $0x10,%esp
c0025777:	5b                   	pop    %ebx
c0025778:	5e                   	pop    %esi
c0025779:	5f                   	pop    %edi
c002577a:	c3                   	ret    

c002577b <issue_pio_command>:
{
c002577b:	56                   	push   %esi
c002577c:	53                   	push   %ebx
c002577d:	83 ec 24             	sub    $0x24,%esp
c0025780:	89 c3                	mov    %eax,%ebx
c0025782:	89 d6                	mov    %edx,%esi
  ASSERT (intr_get_level () == INTR_ON);
c0025784:	e8 eb c1 ff ff       	call   c0021974 <intr_get_level>
c0025789:	83 f8 01             	cmp    $0x1,%eax
c002578c:	74 2c                	je     c00257ba <issue_pio_command+0x3f>
c002578e:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c0025795:	c0 
c0025796:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002579d:	c0 
c002579e:	c7 44 24 08 45 d9 02 	movl   $0xc002d945,0x8(%esp)
c00257a5:	c0 
c00257a6:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c00257ad:	00 
c00257ae:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c00257b5:	e8 c9 31 00 00       	call   c0028983 <debug_panic>
  c->expecting_interrupt = true;
c00257ba:	c6 43 30 01          	movb   $0x1,0x30(%ebx)
  outb (reg_command (c), command);
c00257be:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c00257c2:	83 c2 07             	add    $0x7,%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00257c5:	89 f0                	mov    %esi,%eax
c00257c7:	ee                   	out    %al,(%dx)
}
c00257c8:	83 c4 24             	add    $0x24,%esp
c00257cb:	5b                   	pop    %ebx
c00257cc:	5e                   	pop    %esi
c00257cd:	c3                   	ret    

c00257ce <ide_write>:
{
c00257ce:	57                   	push   %edi
c00257cf:	56                   	push   %esi
c00257d0:	53                   	push   %ebx
c00257d1:	83 ec 20             	sub    $0x20,%esp
c00257d4:	8b 74 24 30          	mov    0x30(%esp),%esi
  struct channel *c = d->channel;
c00257d8:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00257db:	8d 7b 0c             	lea    0xc(%ebx),%edi
c00257de:	89 3c 24             	mov    %edi,(%esp)
c00257e1:	e8 74 d6 ff ff       	call   c0022e5a <lock_acquire>
  select_sector (d, sec_no);
c00257e6:	8b 54 24 34          	mov    0x34(%esp),%edx
c00257ea:	89 f0                	mov    %esi,%eax
c00257ec:	e8 5c fe ff ff       	call   c002564d <select_sector>
  issue_pio_command (c, CMD_WRITE_SECTOR_RETRY);
c00257f1:	ba 30 00 00 00       	mov    $0x30,%edx
c00257f6:	89 d8                	mov    %ebx,%eax
c00257f8:	e8 7e ff ff ff       	call   c002577b <issue_pio_command>
  if (!wait_while_busy (d))
c00257fd:	89 f0                	mov    %esi,%eax
c00257ff:	e8 e1 fe ff ff       	call   c00256e5 <wait_while_busy>
c0025804:	84 c0                	test   %al,%al
c0025806:	75 30                	jne    c0025838 <ide_write+0x6a>
    PANIC ("%s: disk write failed, sector=%"PRDSNu, d->name, sec_no);
c0025808:	8b 44 24 34          	mov    0x34(%esp),%eax
c002580c:	89 44 24 14          	mov    %eax,0x14(%esp)
c0025810:	89 74 24 10          	mov    %esi,0x10(%esp)
c0025814:	c7 44 24 0c 60 f6 02 	movl   $0xc002f660,0xc(%esp)
c002581b:	c0 
c002581c:	c7 44 24 08 6e d9 02 	movl   $0xc002d96e,0x8(%esp)
c0025823:	c0 
c0025824:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
c002582b:	00 
c002582c:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025833:	e8 4b 31 00 00       	call   c0028983 <debug_panic>
   CNT-halfword buffer starting at ADDR. */
static inline void
outsw (uint16_t port, const void *addr, size_t cnt)
{
  /* See [IA32-v2b] "OUTS". */
  asm volatile ("rep outsw" : "+S" (addr), "+c" (cnt) : "d" (port));
c0025838:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c002583c:	8b 74 24 38          	mov    0x38(%esp),%esi
c0025840:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025845:	66 f3 6f             	rep outsw %ds:(%esi),(%dx)
  sema_down (&c->completion_wait);
c0025848:	83 c3 34             	add    $0x34,%ebx
c002584b:	89 1c 24             	mov    %ebx,(%esp)
c002584e:	e8 df d2 ff ff       	call   c0022b32 <sema_down>
  lock_release (&c->lock);
c0025853:	89 3c 24             	mov    %edi,(%esp)
c0025856:	e8 c9 d7 ff ff       	call   c0023024 <lock_release>
}
c002585b:	83 c4 20             	add    $0x20,%esp
c002585e:	5b                   	pop    %ebx
c002585f:	5e                   	pop    %esi
c0025860:	5f                   	pop    %edi
c0025861:	c3                   	ret    

c0025862 <identify_ata_device>:
{
c0025862:	57                   	push   %edi
c0025863:	56                   	push   %esi
c0025864:	53                   	push   %ebx
c0025865:	81 ec a0 02 00 00    	sub    $0x2a0,%esp
c002586b:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c002586d:	8b 70 08             	mov    0x8(%eax),%esi
  ASSERT (d->is_ata);
c0025870:	80 78 10 00          	cmpb   $0x0,0x10(%eax)
c0025874:	75 2c                	jne    c00258a2 <identify_ata_device+0x40>
c0025876:	c7 44 24 10 14 f6 02 	movl   $0xc002f614,0x10(%esp)
c002587d:	c0 
c002587e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025885:	c0 
c0025886:	c7 44 24 08 78 d9 02 	movl   $0xc002d978,0x8(%esp)
c002588d:	c0 
c002588e:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
c0025895:	00 
c0025896:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c002589d:	e8 e1 30 00 00       	call   c0028983 <debug_panic>
  wait_until_idle (d);
c00258a2:	e8 70 fc ff ff       	call   c0025517 <wait_until_idle>
  select_device (d);
c00258a7:	89 d8                	mov    %ebx,%eax
c00258a9:	e8 dc fc ff ff       	call   c002558a <select_device>
  wait_until_idle (d);
c00258ae:	89 d8                	mov    %ebx,%eax
c00258b0:	e8 62 fc ff ff       	call   c0025517 <wait_until_idle>
  issue_pio_command (c, CMD_IDENTIFY_DEVICE);
c00258b5:	ba ec 00 00 00       	mov    $0xec,%edx
c00258ba:	89 f0                	mov    %esi,%eax
c00258bc:	e8 ba fe ff ff       	call   c002577b <issue_pio_command>
  sema_down (&c->completion_wait);
c00258c1:	8d 46 34             	lea    0x34(%esi),%eax
c00258c4:	89 04 24             	mov    %eax,(%esp)
c00258c7:	e8 66 d2 ff ff       	call   c0022b32 <sema_down>
  if (!wait_while_busy (d))
c00258cc:	89 d8                	mov    %ebx,%eax
c00258ce:	e8 12 fe ff ff       	call   c00256e5 <wait_while_busy>
c00258d3:	84 c0                	test   %al,%al
c00258d5:	75 09                	jne    c00258e0 <identify_ata_device+0x7e>
      d->is_ata = false;
c00258d7:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c00258db:	e9 cf 00 00 00       	jmp    c00259af <identify_ata_device+0x14d>
  asm volatile ("rep insw" : "+D" (addr), "+c" (cnt) : "d" (port) : "memory");
c00258e0:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c00258e4:	8d bc 24 a0 00 00 00 	lea    0xa0(%esp),%edi
c00258eb:	b9 00 01 00 00       	mov    $0x100,%ecx
c00258f0:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  capacity = *(uint32_t *) &id[60 * 2];
c00258f3:	8b b4 24 18 01 00 00 	mov    0x118(%esp),%esi
  model = descramble_ata_string (&id[10 * 2], 20);
c00258fa:	ba 14 00 00 00       	mov    $0x14,%edx
c00258ff:	8d 84 24 b4 00 00 00 	lea    0xb4(%esp),%eax
c0025906:	e8 25 fb ff ff       	call   c0025430 <descramble_ata_string>
c002590b:	89 c7                	mov    %eax,%edi
  serial = descramble_ata_string (&id[27 * 2], 40);
c002590d:	ba 28 00 00 00       	mov    $0x28,%edx
c0025912:	8d 84 24 d6 00 00 00 	lea    0xd6(%esp),%eax
c0025919:	e8 12 fb ff ff       	call   c0025430 <descramble_ata_string>
  snprintf (extra_info, sizeof extra_info,
c002591e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025922:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025926:	c7 44 24 08 1e f6 02 	movl   $0xc002f61e,0x8(%esp)
c002592d:	c0 
c002592e:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025935:	00 
c0025936:	8d 44 24 20          	lea    0x20(%esp),%eax
c002593a:	89 04 24             	mov    %eax,(%esp)
c002593d:	e8 ed 18 00 00       	call   c002722f <snprintf>
  if (capacity >= 1024 * 1024 * 1024 / BLOCK_SECTOR_SIZE)
c0025942:	81 fe ff ff 1f 00    	cmp    $0x1fffff,%esi
c0025948:	76 35                	jbe    c002597f <identify_ata_device+0x11d>
      printf ("%s: ignoring ", d->name);
c002594a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002594e:	c7 04 24 36 f6 02 c0 	movl   $0xc002f636,(%esp)
c0025955:	e8 d4 11 00 00       	call   c0026b2e <printf>
      print_human_readable_size (capacity * 512);
c002595a:	c1 e6 09             	shl    $0x9,%esi
c002595d:	89 34 24             	mov    %esi,(%esp)
c0025960:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025967:	00 
c0025968:	e8 8c 1a 00 00       	call   c00273f9 <print_human_readable_size>
      printf ("disk for safety\n");
c002596d:	c7 04 24 44 f6 02 c0 	movl   $0xc002f644,(%esp)
c0025974:	e8 32 4d 00 00       	call   c002a6ab <puts>
      d->is_ata = false;
c0025979:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c002597d:	eb 30                	jmp    c00259af <identify_ata_device+0x14d>
  block = block_register (d->name, BLOCK_RAW, extra_info, capacity,
c002597f:	89 5c 24 14          	mov    %ebx,0x14(%esp)
c0025983:	c7 44 24 10 70 5a 03 	movl   $0xc0035a70,0x10(%esp)
c002598a:	c0 
c002598b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002598f:	8d 44 24 20          	lea    0x20(%esp),%eax
c0025993:	89 44 24 08          	mov    %eax,0x8(%esp)
c0025997:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002599e:	00 
c002599f:	89 1c 24             	mov    %ebx,(%esp)
c00259a2:	e8 5a f5 ff ff       	call   c0024f01 <block_register>
  partition_scan (block);
c00259a7:	89 04 24             	mov    %eax,(%esp)
c00259aa:	e8 30 fa ff ff       	call   c00253df <partition_scan>
}
c00259af:	81 c4 a0 02 00 00    	add    $0x2a0,%esp
c00259b5:	5b                   	pop    %ebx
c00259b6:	5e                   	pop    %esi
c00259b7:	5f                   	pop    %edi
c00259b8:	c3                   	ret    

c00259b9 <ide_read>:
{
c00259b9:	55                   	push   %ebp
c00259ba:	57                   	push   %edi
c00259bb:	56                   	push   %esi
c00259bc:	53                   	push   %ebx
c00259bd:	83 ec 2c             	sub    $0x2c,%esp
c00259c0:	8b 74 24 40          	mov    0x40(%esp),%esi
  struct channel *c = d->channel;
c00259c4:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00259c7:	8d 6b 0c             	lea    0xc(%ebx),%ebp
c00259ca:	89 2c 24             	mov    %ebp,(%esp)
c00259cd:	e8 88 d4 ff ff       	call   c0022e5a <lock_acquire>
  select_sector (d, sec_no);
c00259d2:	8b 54 24 44          	mov    0x44(%esp),%edx
c00259d6:	89 f0                	mov    %esi,%eax
c00259d8:	e8 70 fc ff ff       	call   c002564d <select_sector>
  issue_pio_command (c, CMD_READ_SECTOR_RETRY);
c00259dd:	ba 20 00 00 00       	mov    $0x20,%edx
c00259e2:	89 d8                	mov    %ebx,%eax
c00259e4:	e8 92 fd ff ff       	call   c002577b <issue_pio_command>
  sema_down (&c->completion_wait);
c00259e9:	8d 43 34             	lea    0x34(%ebx),%eax
c00259ec:	89 04 24             	mov    %eax,(%esp)
c00259ef:	e8 3e d1 ff ff       	call   c0022b32 <sema_down>
  if (!wait_while_busy (d))
c00259f4:	89 f0                	mov    %esi,%eax
c00259f6:	e8 ea fc ff ff       	call   c00256e5 <wait_while_busy>
c00259fb:	84 c0                	test   %al,%al
c00259fd:	75 30                	jne    c0025a2f <ide_read+0x76>
    PANIC ("%s: disk read failed, sector=%"PRDSNu, d->name, sec_no);
c00259ff:	8b 44 24 44          	mov    0x44(%esp),%eax
c0025a03:	89 44 24 14          	mov    %eax,0x14(%esp)
c0025a07:	89 74 24 10          	mov    %esi,0x10(%esp)
c0025a0b:	c7 44 24 0c 84 f6 02 	movl   $0xc002f684,0xc(%esp)
c0025a12:	c0 
c0025a13:	c7 44 24 08 57 d9 02 	movl   $0xc002d957,0x8(%esp)
c0025a1a:	c0 
c0025a1b:	c7 44 24 04 62 01 00 	movl   $0x162,0x4(%esp)
c0025a22:	00 
c0025a23:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025a2a:	e8 54 2f 00 00       	call   c0028983 <debug_panic>
c0025a2f:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c0025a33:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0025a37:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025a3c:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  lock_release (&c->lock);
c0025a3f:	89 2c 24             	mov    %ebp,(%esp)
c0025a42:	e8 dd d5 ff ff       	call   c0023024 <lock_release>
}
c0025a47:	83 c4 2c             	add    $0x2c,%esp
c0025a4a:	5b                   	pop    %ebx
c0025a4b:	5e                   	pop    %esi
c0025a4c:	5f                   	pop    %edi
c0025a4d:	5d                   	pop    %ebp
c0025a4e:	c3                   	ret    

c0025a4f <ide_init>:
{
c0025a4f:	55                   	push   %ebp
c0025a50:	57                   	push   %edi
c0025a51:	56                   	push   %esi
c0025a52:	53                   	push   %ebx
c0025a53:	83 ec 4c             	sub    $0x4c,%esp
c0025a56:	c7 44 24 1c 9c 78 03 	movl   $0xc003789c,0x1c(%esp)
c0025a5d:	c0 
c0025a5e:	bd 88 78 03 c0       	mov    $0xc0037888,%ebp
c0025a63:	c7 44 24 20 61 00 00 	movl   $0x61,0x20(%esp)
c0025a6a:	00 
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025a6b:	bf 00 00 00 00       	mov    $0x0,%edi
c0025a70:	8d 75 b8             	lea    -0x48(%ebp),%esi
      snprintf (c->name, sizeof c->name, "ide%zu", chan_no);
c0025a73:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025a77:	c7 44 24 08 54 f6 02 	movl   $0xc002f654,0x8(%esp)
c0025a7e:	c0 
c0025a7f:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025a86:	00 
c0025a87:	89 34 24             	mov    %esi,(%esp)
c0025a8a:	e8 a0 17 00 00       	call   c002722f <snprintf>
      switch (chan_no) 
c0025a8f:	85 ff                	test   %edi,%edi
c0025a91:	74 07                	je     c0025a9a <ide_init+0x4b>
c0025a93:	83 ff 01             	cmp    $0x1,%edi
c0025a96:	74 0e                	je     c0025aa6 <ide_init+0x57>
c0025a98:	eb 18                	jmp    c0025ab2 <ide_init+0x63>
          c->reg_base = 0x1f0;
c0025a9a:	66 c7 45 c0 f0 01    	movw   $0x1f0,-0x40(%ebp)
          c->irq = 14 + 0x20;
c0025aa0:	c6 45 c2 2e          	movb   $0x2e,-0x3e(%ebp)
          break;
c0025aa4:	eb 30                	jmp    c0025ad6 <ide_init+0x87>
          c->reg_base = 0x170;
c0025aa6:	66 c7 45 c0 70 01    	movw   $0x170,-0x40(%ebp)
          c->irq = 15 + 0x20;
c0025aac:	c6 45 c2 2f          	movb   $0x2f,-0x3e(%ebp)
          break;
c0025ab0:	eb 24                	jmp    c0025ad6 <ide_init+0x87>
          NOT_REACHED ();
c0025ab2:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c0025ab9:	c0 
c0025aba:	c7 44 24 08 9e d9 02 	movl   $0xc002d99e,0x8(%esp)
c0025ac1:	c0 
c0025ac2:	c7 44 24 04 7c 00 00 	movl   $0x7c,0x4(%esp)
c0025ac9:	00 
c0025aca:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025ad1:	e8 ad 2e 00 00       	call   c0028983 <debug_panic>
c0025ad6:	8d 45 c4             	lea    -0x3c(%ebp),%eax
      lock_init (&c->lock);
c0025ad9:	89 04 24             	mov    %eax,(%esp)
c0025adc:	e8 dc d2 ff ff       	call   c0022dbd <lock_init>
c0025ae1:	89 eb                	mov    %ebp,%ebx
      c->expecting_interrupt = false;
c0025ae3:	c6 45 e8 00          	movb   $0x0,-0x18(%ebp)
      sema_init (&c->completion_wait, 0);
c0025ae7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025aee:	00 
c0025aef:	8d 45 ec             	lea    -0x14(%ebp),%eax
c0025af2:	89 04 24             	mov    %eax,(%esp)
c0025af5:	e8 ec cf ff ff       	call   c0022ae6 <sema_init>
          snprintf (d->name, sizeof d->name,
c0025afa:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025afe:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b02:	c7 44 24 08 5b f6 02 	movl   $0xc002f65b,0x8(%esp)
c0025b09:	c0 
c0025b0a:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b11:	00 
c0025b12:	89 2c 24             	mov    %ebp,(%esp)
c0025b15:	e8 15 17 00 00       	call   c002722f <snprintf>
          d->channel = c;
c0025b1a:	89 75 08             	mov    %esi,0x8(%ebp)
          d->dev_no = dev_no;
c0025b1d:	c7 45 0c 00 00 00 00 	movl   $0x0,0xc(%ebp)
          d->is_ata = false;
c0025b24:	c6 45 10 00          	movb   $0x0,0x10(%ebp)
          snprintf (d->name, sizeof d->name,
c0025b28:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0025b2c:	89 4c 24 24          	mov    %ecx,0x24(%esp)
c0025b30:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025b34:	83 c0 01             	add    $0x1,%eax
c0025b37:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b3b:	c7 44 24 08 5b f6 02 	movl   $0xc002f65b,0x8(%esp)
c0025b42:	c0 
c0025b43:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b4a:	00 
c0025b4b:	89 0c 24             	mov    %ecx,(%esp)
c0025b4e:	e8 dc 16 00 00       	call   c002722f <snprintf>
          d->channel = c;
c0025b53:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0025b57:	89 70 08             	mov    %esi,0x8(%eax)
          d->dev_no = dev_no;
c0025b5a:	c7 40 0c 01 00 00 00 	movl   $0x1,0xc(%eax)
          d->is_ata = false;
c0025b61:	c6 45 24 00          	movb   $0x0,0x24(%ebp)
      intr_register_ext (c->irq, interrupt_handler, c->name);
c0025b65:	89 74 24 08          	mov    %esi,0x8(%esp)
c0025b69:	c7 44 24 04 8c 54 02 	movl   $0xc002548c,0x4(%esp)
c0025b70:	c0 
c0025b71:	0f b6 45 c2          	movzbl -0x3e(%ebp),%eax
c0025b75:	89 04 24             	mov    %eax,(%esp)
c0025b78:	e8 e6 bf ff ff       	call   c0021b63 <intr_register_ext>
c0025b7d:	8d 74 24 3e          	lea    0x3e(%esp),%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025b81:	89 7c 24 28          	mov    %edi,0x28(%esp)
c0025b85:	89 6c 24 2c          	mov    %ebp,0x2c(%esp)
      select_device (d);
c0025b89:	89 e8                	mov    %ebp,%eax
c0025b8b:	e8 fa f9 ff ff       	call   c002558a <select_device>
      outb (reg_nsect (c), 0x55);
c0025b90:	0f b7 7b c0          	movzwl -0x40(%ebx),%edi
c0025b94:	8d 4f 02             	lea    0x2(%edi),%ecx
c0025b97:	b8 55 00 00 00       	mov    $0x55,%eax
c0025b9c:	89 ca                	mov    %ecx,%edx
c0025b9e:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0025b9f:	83 c7 03             	add    $0x3,%edi
c0025ba2:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025ba7:	89 fa                	mov    %edi,%edx
c0025ba9:	ee                   	out    %al,(%dx)
c0025baa:	89 ca                	mov    %ecx,%edx
c0025bac:	ee                   	out    %al,(%dx)
c0025bad:	b8 55 00 00 00       	mov    $0x55,%eax
c0025bb2:	89 fa                	mov    %edi,%edx
c0025bb4:	ee                   	out    %al,(%dx)
c0025bb5:	89 ca                	mov    %ecx,%edx
c0025bb7:	ee                   	out    %al,(%dx)
c0025bb8:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025bbd:	89 fa                	mov    %edi,%edx
c0025bbf:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025bc0:	89 ca                	mov    %ecx,%edx
c0025bc2:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0025bc3:	ba 00 00 00 00       	mov    $0x0,%edx
c0025bc8:	3c 55                	cmp    $0x55,%al
c0025bca:	75 0b                	jne    c0025bd7 <ide_init+0x188>
c0025bcc:	89 fa                	mov    %edi,%edx
c0025bce:	ec                   	in     (%dx),%al
c0025bcf:	3c aa                	cmp    $0xaa,%al
c0025bd1:	0f 94 c2             	sete   %dl
c0025bd4:	0f b6 d2             	movzbl %dl,%edx
c0025bd7:	88 16                	mov    %dl,(%esi)
c0025bd9:	80 26 01             	andb   $0x1,(%esi)
c0025bdc:	83 c5 14             	add    $0x14,%ebp
c0025bdf:	83 c6 01             	add    $0x1,%esi
  for (dev_no = 0; dev_no < 2; dev_no++)
c0025be2:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025be6:	39 c6                	cmp    %eax,%esi
c0025be8:	75 9f                	jne    c0025b89 <ide_init+0x13a>
c0025bea:	8b 7c 24 28          	mov    0x28(%esp),%edi
c0025bee:	8b 6c 24 2c          	mov    0x2c(%esp),%ebp
  outb (reg_ctl (c), 0);
c0025bf2:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025bf6:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025bfc:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c01:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c02:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c09:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c10:	00 
c0025c11:	e8 95 e7 ff ff       	call   c00243ab <timer_usleep>
  outb (reg_ctl (c), CTL_SRST);
c0025c16:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c1a:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c20:	b8 04 00 00 00       	mov    $0x4,%eax
c0025c25:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c26:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c2d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c34:	00 
c0025c35:	e8 71 e7 ff ff       	call   c00243ab <timer_usleep>
  outb (reg_ctl (c), 0);
c0025c3a:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c3e:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c44:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c49:	ee                   	out    %al,(%dx)
  timer_msleep (150);
c0025c4a:	c7 04 24 96 00 00 00 	movl   $0x96,(%esp)
c0025c51:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c58:	00 
c0025c59:	e8 34 e7 ff ff       	call   c0024392 <timer_msleep>
  if (present[0]) 
c0025c5e:	80 7c 24 3e 00       	cmpb   $0x0,0x3e(%esp)
c0025c63:	74 0e                	je     c0025c73 <ide_init+0x224>
      select_device (&c->devices[0]);
c0025c65:	89 d8                	mov    %ebx,%eax
c0025c67:	e8 1e f9 ff ff       	call   c002558a <select_device>
      wait_while_busy (&c->devices[0]); 
c0025c6c:	89 d8                	mov    %ebx,%eax
c0025c6e:	e8 72 fa ff ff       	call   c00256e5 <wait_while_busy>
  if (present[1])
c0025c73:	80 7c 24 3f 00       	cmpb   $0x0,0x3f(%esp)
c0025c78:	74 44                	je     c0025cbe <ide_init+0x26f>
      select_device (&c->devices[1]);
c0025c7a:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025c7e:	e8 07 f9 ff ff       	call   c002558a <select_device>
c0025c83:	be b8 0b 00 00       	mov    $0xbb8,%esi
          if (inb (reg_nsect (c)) == 1 && inb (reg_lbal (c)) == 1)
c0025c88:	0f b7 4b c0          	movzwl -0x40(%ebx),%ecx
c0025c8c:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025c8f:	ec                   	in     (%dx),%al
c0025c90:	3c 01                	cmp    $0x1,%al
c0025c92:	75 08                	jne    c0025c9c <ide_init+0x24d>
c0025c94:	8d 51 03             	lea    0x3(%ecx),%edx
c0025c97:	ec                   	in     (%dx),%al
c0025c98:	3c 01                	cmp    $0x1,%al
c0025c9a:	74 19                	je     c0025cb5 <ide_init+0x266>
          timer_msleep (10);
c0025c9c:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025ca3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025caa:	00 
c0025cab:	e8 e2 e6 ff ff       	call   c0024392 <timer_msleep>
      for (i = 0; i < 3000; i++) 
c0025cb0:	83 ee 01             	sub    $0x1,%esi
c0025cb3:	75 d3                	jne    c0025c88 <ide_init+0x239>
      wait_while_busy (&c->devices[1]);
c0025cb5:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cb9:	e8 27 fa ff ff       	call   c00256e5 <wait_while_busy>
      if (check_device_type (&c->devices[0]))
c0025cbe:	89 d8                	mov    %ebx,%eax
c0025cc0:	e8 03 f9 ff ff       	call   c00255c8 <check_device_type>
c0025cc5:	84 c0                	test   %al,%al
c0025cc7:	74 2f                	je     c0025cf8 <ide_init+0x2a9>
        check_device_type (&c->devices[1]);
c0025cc9:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025ccd:	e8 f6 f8 ff ff       	call   c00255c8 <check_device_type>
c0025cd2:	eb 24                	jmp    c0025cf8 <ide_init+0x2a9>
          identify_ata_device (&c->devices[dev_no]);
c0025cd4:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cd8:	e8 85 fb ff ff       	call   c0025862 <identify_ata_device>
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025cdd:	83 c7 01             	add    $0x1,%edi
c0025ce0:	83 44 24 1c 70       	addl   $0x70,0x1c(%esp)
c0025ce5:	83 c5 70             	add    $0x70,%ebp
c0025ce8:	83 44 24 20 02       	addl   $0x2,0x20(%esp)
c0025ced:	83 ff 02             	cmp    $0x2,%edi
c0025cf0:	0f 85 7a fd ff ff    	jne    c0025a70 <ide_init+0x21>
c0025cf6:	eb 15                	jmp    c0025d0d <ide_init+0x2be>
        if (c->devices[dev_no].is_ata)
c0025cf8:	80 7b 10 00          	cmpb   $0x0,0x10(%ebx)
c0025cfc:	74 07                	je     c0025d05 <ide_init+0x2b6>
          identify_ata_device (&c->devices[dev_no]);
c0025cfe:	89 d8                	mov    %ebx,%eax
c0025d00:	e8 5d fb ff ff       	call   c0025862 <identify_ata_device>
        if (c->devices[dev_no].is_ata)
c0025d05:	80 7b 24 00          	cmpb   $0x0,0x24(%ebx)
c0025d09:	74 d2                	je     c0025cdd <ide_init+0x28e>
c0025d0b:	eb c7                	jmp    c0025cd4 <ide_init+0x285>
}
c0025d0d:	83 c4 4c             	add    $0x4c,%esp
c0025d10:	5b                   	pop    %ebx
c0025d11:	5e                   	pop    %esi
c0025d12:	5f                   	pop    %edi
c0025d13:	5d                   	pop    %ebp
c0025d14:	c3                   	ret    

c0025d15 <input_init>:
static struct intq buffer;

/* Initializes the input buffer. */
void
input_init (void) 
{
c0025d15:	83 ec 1c             	sub    $0x1c,%esp
  intq_init (&buffer);
c0025d18:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d1f:	e8 11 01 00 00       	call   c0025e35 <intq_init>
}
c0025d24:	83 c4 1c             	add    $0x1c,%esp
c0025d27:	c3                   	ret    

c0025d28 <input_putc>:

/* Adds a key to the input buffer.
   Interrupts must be off and the buffer must not be full. */
void
input_putc (uint8_t key) 
{
c0025d28:	53                   	push   %ebx
c0025d29:	83 ec 28             	sub    $0x28,%esp
c0025d2c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025d30:	e8 3f bc ff ff       	call   c0021974 <intr_get_level>
c0025d35:	85 c0                	test   %eax,%eax
c0025d37:	74 2c                	je     c0025d65 <input_putc+0x3d>
c0025d39:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025d40:	c0 
c0025d41:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025d48:	c0 
c0025d49:	c7 44 24 08 b2 d9 02 	movl   $0xc002d9b2,0x8(%esp)
c0025d50:	c0 
c0025d51:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c0025d58:	00 
c0025d59:	c7 04 24 a4 f6 02 c0 	movl   $0xc002f6a4,(%esp)
c0025d60:	e8 1e 2c 00 00       	call   c0028983 <debug_panic>
  ASSERT (!intq_full (&buffer));
c0025d65:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d6c:	e8 40 01 00 00       	call   c0025eb1 <intq_full>
c0025d71:	84 c0                	test   %al,%al
c0025d73:	74 2c                	je     c0025da1 <input_putc+0x79>
c0025d75:	c7 44 24 10 ba f6 02 	movl   $0xc002f6ba,0x10(%esp)
c0025d7c:	c0 
c0025d7d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025d84:	c0 
c0025d85:	c7 44 24 08 b2 d9 02 	movl   $0xc002d9b2,0x8(%esp)
c0025d8c:	c0 
c0025d8d:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025d94:	00 
c0025d95:	c7 04 24 a4 f6 02 c0 	movl   $0xc002f6a4,(%esp)
c0025d9c:	e8 e2 2b 00 00       	call   c0028983 <debug_panic>

  intq_putc (&buffer, key);
c0025da1:	0f b6 db             	movzbl %bl,%ebx
c0025da4:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0025da8:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025daf:	e8 a7 03 00 00       	call   c002615b <intq_putc>
  serial_notify ();
c0025db4:	e8 21 ee ff ff       	call   c0024bda <serial_notify>
}
c0025db9:	83 c4 28             	add    $0x28,%esp
c0025dbc:	5b                   	pop    %ebx
c0025dbd:	c3                   	ret    

c0025dbe <input_getc>:

/* Retrieves a key from the input buffer.
   If the buffer is empty, waits for a key to be pressed. */
uint8_t
input_getc (void) 
{
c0025dbe:	56                   	push   %esi
c0025dbf:	53                   	push   %ebx
c0025dc0:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level;
  uint8_t key;

  old_level = intr_disable ();
c0025dc3:	e8 f7 bb ff ff       	call   c00219bf <intr_disable>
c0025dc8:	89 c6                	mov    %eax,%esi
  key = intq_getc (&buffer);
c0025dca:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025dd1:	e8 b9 02 00 00       	call   c002608f <intq_getc>
c0025dd6:	89 c3                	mov    %eax,%ebx
  serial_notify ();
c0025dd8:	e8 fd ed ff ff       	call   c0024bda <serial_notify>
  intr_set_level (old_level);
c0025ddd:	89 34 24             	mov    %esi,(%esp)
c0025de0:	e8 e1 bb ff ff       	call   c00219c6 <intr_set_level>
  
  return key;
}
c0025de5:	89 d8                	mov    %ebx,%eax
c0025de7:	83 c4 14             	add    $0x14,%esp
c0025dea:	5b                   	pop    %ebx
c0025deb:	5e                   	pop    %esi
c0025dec:	c3                   	ret    

c0025ded <input_full>:
/* Returns true if the input buffer is full,
   false otherwise.
   Interrupts must be off. */
bool
input_full (void) 
{
c0025ded:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0025df0:	e8 7f bb ff ff       	call   c0021974 <intr_get_level>
c0025df5:	85 c0                	test   %eax,%eax
c0025df7:	74 2c                	je     c0025e25 <input_full+0x38>
c0025df9:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025e00:	c0 
c0025e01:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025e08:	c0 
c0025e09:	c7 44 24 08 a7 d9 02 	movl   $0xc002d9a7,0x8(%esp)
c0025e10:	c0 
c0025e11:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c0025e18:	00 
c0025e19:	c7 04 24 a4 f6 02 c0 	movl   $0xc002f6a4,(%esp)
c0025e20:	e8 5e 2b 00 00       	call   c0028983 <debug_panic>
  return intq_full (&buffer);
c0025e25:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025e2c:	e8 80 00 00 00       	call   c0025eb1 <intq_full>
}
c0025e31:	83 c4 2c             	add    $0x2c,%esp
c0025e34:	c3                   	ret    

c0025e35 <intq_init>:
static void signal (struct intq *q, struct thread **waiter);

/* Initializes interrupt queue Q. */
void
intq_init (struct intq *q) 
{
c0025e35:	53                   	push   %ebx
c0025e36:	83 ec 18             	sub    $0x18,%esp
c0025e39:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_init (&q->lock);
c0025e3d:	89 1c 24             	mov    %ebx,(%esp)
c0025e40:	e8 78 cf ff ff       	call   c0022dbd <lock_init>
  q->not_full = q->not_empty = NULL;
c0025e45:	c7 43 28 00 00 00 00 	movl   $0x0,0x28(%ebx)
c0025e4c:	c7 43 24 00 00 00 00 	movl   $0x0,0x24(%ebx)
  q->head = q->tail = 0;
c0025e53:	c7 43 70 00 00 00 00 	movl   $0x0,0x70(%ebx)
c0025e5a:	c7 43 6c 00 00 00 00 	movl   $0x0,0x6c(%ebx)
}
c0025e61:	83 c4 18             	add    $0x18,%esp
c0025e64:	5b                   	pop    %ebx
c0025e65:	c3                   	ret    

c0025e66 <intq_empty>:

/* Returns true if Q is empty, false otherwise. */
bool
intq_empty (const struct intq *q) 
{
c0025e66:	53                   	push   %ebx
c0025e67:	83 ec 28             	sub    $0x28,%esp
c0025e6a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025e6e:	e8 01 bb ff ff       	call   c0021974 <intr_get_level>
c0025e73:	85 c0                	test   %eax,%eax
c0025e75:	74 2c                	je     c0025ea3 <intq_empty+0x3d>
c0025e77:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025e7e:	c0 
c0025e7f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025e86:	c0 
c0025e87:	c7 44 24 08 e7 d9 02 	movl   $0xc002d9e7,0x8(%esp)
c0025e8e:	c0 
c0025e8f:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025e96:	00 
c0025e97:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025e9e:	e8 e0 2a 00 00       	call   c0028983 <debug_panic>
  return q->head == q->tail;
c0025ea3:	8b 43 70             	mov    0x70(%ebx),%eax
c0025ea6:	39 43 6c             	cmp    %eax,0x6c(%ebx)
c0025ea9:	0f 94 c0             	sete   %al
}
c0025eac:	83 c4 28             	add    $0x28,%esp
c0025eaf:	5b                   	pop    %ebx
c0025eb0:	c3                   	ret    

c0025eb1 <intq_full>:

/* Returns true if Q is full, false otherwise. */
bool
intq_full (const struct intq *q) 
{
c0025eb1:	53                   	push   %ebx
c0025eb2:	83 ec 28             	sub    $0x28,%esp
c0025eb5:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025eb9:	e8 b6 ba ff ff       	call   c0021974 <intr_get_level>
c0025ebe:	85 c0                	test   %eax,%eax
c0025ec0:	74 2c                	je     c0025eee <intq_full+0x3d>
c0025ec2:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025ec9:	c0 
c0025eca:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025ed1:	c0 
c0025ed2:	c7 44 24 08 dd d9 02 	movl   $0xc002d9dd,0x8(%esp)
c0025ed9:	c0 
c0025eda:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c0025ee1:	00 
c0025ee2:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025ee9:	e8 95 2a 00 00       	call   c0028983 <debug_panic>

/* Returns the position after POS within an intq. */
static int
next (int pos) 
{
  return (pos + 1) % INTQ_BUFSIZE;
c0025eee:	8b 43 6c             	mov    0x6c(%ebx),%eax
c0025ef1:	8d 50 01             	lea    0x1(%eax),%edx
c0025ef4:	89 d0                	mov    %edx,%eax
c0025ef6:	c1 f8 1f             	sar    $0x1f,%eax
c0025ef9:	c1 e8 1a             	shr    $0x1a,%eax
c0025efc:	01 c2                	add    %eax,%edx
c0025efe:	83 e2 3f             	and    $0x3f,%edx
c0025f01:	29 c2                	sub    %eax,%edx
  return next (q->head) == q->tail;
c0025f03:	39 53 70             	cmp    %edx,0x70(%ebx)
c0025f06:	0f 94 c0             	sete   %al
}
c0025f09:	83 c4 28             	add    $0x28,%esp
c0025f0c:	5b                   	pop    %ebx
c0025f0d:	c3                   	ret    

c0025f0e <wait>:

/* WAITER must be the address of Q's not_empty or not_full
   member.  Waits until the given condition is true. */
static void
wait (struct intq *q UNUSED, struct thread **waiter) 
{
c0025f0e:	56                   	push   %esi
c0025f0f:	53                   	push   %ebx
c0025f10:	83 ec 24             	sub    $0x24,%esp
c0025f13:	89 c3                	mov    %eax,%ebx
c0025f15:	89 d6                	mov    %edx,%esi
  ASSERT (!intr_context ());
c0025f17:	e8 05 bd ff ff       	call   c0021c21 <intr_context>
c0025f1c:	84 c0                	test   %al,%al
c0025f1e:	74 2c                	je     c0025f4c <wait+0x3e>
c0025f20:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0025f27:	c0 
c0025f28:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025f2f:	c0 
c0025f30:	c7 44 24 08 ce d9 02 	movl   $0xc002d9ce,0x8(%esp)
c0025f37:	c0 
c0025f38:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c0025f3f:	00 
c0025f40:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025f47:	e8 37 2a 00 00       	call   c0028983 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0025f4c:	e8 23 ba ff ff       	call   c0021974 <intr_get_level>
c0025f51:	85 c0                	test   %eax,%eax
c0025f53:	74 2c                	je     c0025f81 <wait+0x73>
c0025f55:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025f5c:	c0 
c0025f5d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025f64:	c0 
c0025f65:	c7 44 24 08 ce d9 02 	movl   $0xc002d9ce,0x8(%esp)
c0025f6c:	c0 
c0025f6d:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c0025f74:	00 
c0025f75:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025f7c:	e8 02 2a 00 00       	call   c0028983 <debug_panic>
  ASSERT ((waiter == &q->not_empty && intq_empty (q))
c0025f81:	8d 43 28             	lea    0x28(%ebx),%eax
c0025f84:	39 c6                	cmp    %eax,%esi
c0025f86:	75 0c                	jne    c0025f94 <wait+0x86>
c0025f88:	89 1c 24             	mov    %ebx,(%esp)
c0025f8b:	e8 d6 fe ff ff       	call   c0025e66 <intq_empty>
c0025f90:	84 c0                	test   %al,%al
c0025f92:	75 3f                	jne    c0025fd3 <wait+0xc5>
c0025f94:	8d 43 24             	lea    0x24(%ebx),%eax
c0025f97:	39 c6                	cmp    %eax,%esi
c0025f99:	75 0c                	jne    c0025fa7 <wait+0x99>
c0025f9b:	89 1c 24             	mov    %ebx,(%esp)
c0025f9e:	e8 0e ff ff ff       	call   c0025eb1 <intq_full>
c0025fa3:	84 c0                	test   %al,%al
c0025fa5:	75 2c                	jne    c0025fd3 <wait+0xc5>
c0025fa7:	c7 44 24 10 e4 f6 02 	movl   $0xc002f6e4,0x10(%esp)
c0025fae:	c0 
c0025faf:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025fb6:	c0 
c0025fb7:	c7 44 24 08 ce d9 02 	movl   $0xc002d9ce,0x8(%esp)
c0025fbe:	c0 
c0025fbf:	c7 44 24 04 5c 00 00 	movl   $0x5c,0x4(%esp)
c0025fc6:	00 
c0025fc7:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025fce:	e8 b0 29 00 00       	call   c0028983 <debug_panic>
          || (waiter == &q->not_full && intq_full (q)));

  *waiter = thread_current ();
c0025fd3:	e8 01 ae ff ff       	call   c0020dd9 <thread_current>
c0025fd8:	89 06                	mov    %eax,(%esi)
  thread_block ();
c0025fda:	e8 30 b3 ff ff       	call   c002130f <thread_block>
}
c0025fdf:	83 c4 24             	add    $0x24,%esp
c0025fe2:	5b                   	pop    %ebx
c0025fe3:	5e                   	pop    %esi
c0025fe4:	c3                   	ret    

c0025fe5 <signal>:
   member, and the associated condition must be true.  If a
   thread is waiting for the condition, wakes it up and resets
   the waiting thread. */
static void
signal (struct intq *q UNUSED, struct thread **waiter) 
{
c0025fe5:	56                   	push   %esi
c0025fe6:	53                   	push   %ebx
c0025fe7:	83 ec 24             	sub    $0x24,%esp
c0025fea:	89 c6                	mov    %eax,%esi
c0025fec:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025fee:	e8 81 b9 ff ff       	call   c0021974 <intr_get_level>
c0025ff3:	85 c0                	test   %eax,%eax
c0025ff5:	74 2c                	je     c0026023 <signal+0x3e>
c0025ff7:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025ffe:	c0 
c0025fff:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0026006:	c0 
c0026007:	c7 44 24 08 c7 d9 02 	movl   $0xc002d9c7,0x8(%esp)
c002600e:	c0 
c002600f:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0026016:	00 
c0026017:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c002601e:	e8 60 29 00 00       	call   c0028983 <debug_panic>
  ASSERT ((waiter == &q->not_empty && !intq_empty (q))
c0026023:	8d 46 28             	lea    0x28(%esi),%eax
c0026026:	39 c3                	cmp    %eax,%ebx
c0026028:	75 0c                	jne    c0026036 <signal+0x51>
c002602a:	89 34 24             	mov    %esi,(%esp)
c002602d:	e8 34 fe ff ff       	call   c0025e66 <intq_empty>
c0026032:	84 c0                	test   %al,%al
c0026034:	74 3f                	je     c0026075 <signal+0x90>
c0026036:	8d 46 24             	lea    0x24(%esi),%eax
c0026039:	39 c3                	cmp    %eax,%ebx
c002603b:	75 0c                	jne    c0026049 <signal+0x64>
c002603d:	89 34 24             	mov    %esi,(%esp)
c0026040:	e8 6c fe ff ff       	call   c0025eb1 <intq_full>
c0026045:	84 c0                	test   %al,%al
c0026047:	74 2c                	je     c0026075 <signal+0x90>
c0026049:	c7 44 24 10 40 f7 02 	movl   $0xc002f740,0x10(%esp)
c0026050:	c0 
c0026051:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0026058:	c0 
c0026059:	c7 44 24 08 c7 d9 02 	movl   $0xc002d9c7,0x8(%esp)
c0026060:	c0 
c0026061:	c7 44 24 04 6b 00 00 	movl   $0x6b,0x4(%esp)
c0026068:	00 
c0026069:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0026070:	e8 0e 29 00 00       	call   c0028983 <debug_panic>
          || (waiter == &q->not_full && !intq_full (q)));

  if (*waiter != NULL) 
c0026075:	8b 03                	mov    (%ebx),%eax
c0026077:	85 c0                	test   %eax,%eax
c0026079:	74 0e                	je     c0026089 <signal+0xa4>
    {
      thread_unblock (*waiter);
c002607b:	89 04 24             	mov    %eax,(%esp)
c002607e:	e8 7b ac ff ff       	call   c0020cfe <thread_unblock>
      *waiter = NULL;
c0026083:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
    }
}
c0026089:	83 c4 24             	add    $0x24,%esp
c002608c:	5b                   	pop    %ebx
c002608d:	5e                   	pop    %esi
c002608e:	c3                   	ret    

c002608f <intq_getc>:
{
c002608f:	56                   	push   %esi
c0026090:	53                   	push   %ebx
c0026091:	83 ec 24             	sub    $0x24,%esp
c0026094:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0026098:	e8 d7 b8 ff ff       	call   c0021974 <intr_get_level>
c002609d:	85 c0                	test   %eax,%eax
c002609f:	75 05                	jne    c00260a6 <intq_getc+0x17>
      wait (q, &q->not_empty);
c00260a1:	8d 73 28             	lea    0x28(%ebx),%esi
c00260a4:	eb 7a                	jmp    c0026120 <intq_getc+0x91>
  ASSERT (intr_get_level () == INTR_OFF);
c00260a6:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c00260ad:	c0 
c00260ae:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00260b5:	c0 
c00260b6:	c7 44 24 08 d3 d9 02 	movl   $0xc002d9d3,0x8(%esp)
c00260bd:	c0 
c00260be:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c00260c5:	00 
c00260c6:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c00260cd:	e8 b1 28 00 00       	call   c0028983 <debug_panic>
      ASSERT (!intr_context ());
c00260d2:	e8 4a bb ff ff       	call   c0021c21 <intr_context>
c00260d7:	84 c0                	test   %al,%al
c00260d9:	74 2c                	je     c0026107 <intq_getc+0x78>
c00260db:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00260e2:	c0 
c00260e3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00260ea:	c0 
c00260eb:	c7 44 24 08 d3 d9 02 	movl   $0xc002d9d3,0x8(%esp)
c00260f2:	c0 
c00260f3:	c7 44 24 04 2d 00 00 	movl   $0x2d,0x4(%esp)
c00260fa:	00 
c00260fb:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0026102:	e8 7c 28 00 00       	call   c0028983 <debug_panic>
      lock_acquire (&q->lock);
c0026107:	89 1c 24             	mov    %ebx,(%esp)
c002610a:	e8 4b cd ff ff       	call   c0022e5a <lock_acquire>
      wait (q, &q->not_empty);
c002610f:	89 f2                	mov    %esi,%edx
c0026111:	89 d8                	mov    %ebx,%eax
c0026113:	e8 f6 fd ff ff       	call   c0025f0e <wait>
      lock_release (&q->lock);
c0026118:	89 1c 24             	mov    %ebx,(%esp)
c002611b:	e8 04 cf ff ff       	call   c0023024 <lock_release>
  while (intq_empty (q)) 
c0026120:	89 1c 24             	mov    %ebx,(%esp)
c0026123:	e8 3e fd ff ff       	call   c0025e66 <intq_empty>
c0026128:	84 c0                	test   %al,%al
c002612a:	75 a6                	jne    c00260d2 <intq_getc+0x43>
  byte = q->buf[q->tail];
c002612c:	8b 4b 70             	mov    0x70(%ebx),%ecx
c002612f:	0f b6 74 0b 2c       	movzbl 0x2c(%ebx,%ecx,1),%esi
  return (pos + 1) % INTQ_BUFSIZE;
c0026134:	83 c1 01             	add    $0x1,%ecx
c0026137:	89 ca                	mov    %ecx,%edx
c0026139:	c1 fa 1f             	sar    $0x1f,%edx
c002613c:	c1 ea 1a             	shr    $0x1a,%edx
c002613f:	01 d1                	add    %edx,%ecx
c0026141:	83 e1 3f             	and    $0x3f,%ecx
c0026144:	29 d1                	sub    %edx,%ecx
  q->tail = next (q->tail);
c0026146:	89 4b 70             	mov    %ecx,0x70(%ebx)
  signal (q, &q->not_full);
c0026149:	8d 53 24             	lea    0x24(%ebx),%edx
c002614c:	89 d8                	mov    %ebx,%eax
c002614e:	e8 92 fe ff ff       	call   c0025fe5 <signal>
}
c0026153:	89 f0                	mov    %esi,%eax
c0026155:	83 c4 24             	add    $0x24,%esp
c0026158:	5b                   	pop    %ebx
c0026159:	5e                   	pop    %esi
c002615a:	c3                   	ret    

c002615b <intq_putc>:
{
c002615b:	57                   	push   %edi
c002615c:	56                   	push   %esi
c002615d:	53                   	push   %ebx
c002615e:	83 ec 20             	sub    $0x20,%esp
c0026161:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0026165:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0026169:	e8 06 b8 ff ff       	call   c0021974 <intr_get_level>
c002616e:	85 c0                	test   %eax,%eax
c0026170:	75 05                	jne    c0026177 <intq_putc+0x1c>
      wait (q, &q->not_full);
c0026172:	8d 73 24             	lea    0x24(%ebx),%esi
c0026175:	eb 7a                	jmp    c00261f1 <intq_putc+0x96>
  ASSERT (intr_get_level () == INTR_OFF);
c0026177:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c002617e:	c0 
c002617f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0026186:	c0 
c0026187:	c7 44 24 08 bd d9 02 	movl   $0xc002d9bd,0x8(%esp)
c002618e:	c0 
c002618f:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0026196:	00 
c0026197:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c002619e:	e8 e0 27 00 00       	call   c0028983 <debug_panic>
      ASSERT (!intr_context ());
c00261a3:	e8 79 ba ff ff       	call   c0021c21 <intr_context>
c00261a8:	84 c0                	test   %al,%al
c00261aa:	74 2c                	je     c00261d8 <intq_putc+0x7d>
c00261ac:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00261b3:	c0 
c00261b4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00261bb:	c0 
c00261bc:	c7 44 24 08 bd d9 02 	movl   $0xc002d9bd,0x8(%esp)
c00261c3:	c0 
c00261c4:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
c00261cb:	00 
c00261cc:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c00261d3:	e8 ab 27 00 00       	call   c0028983 <debug_panic>
      lock_acquire (&q->lock);
c00261d8:	89 1c 24             	mov    %ebx,(%esp)
c00261db:	e8 7a cc ff ff       	call   c0022e5a <lock_acquire>
      wait (q, &q->not_full);
c00261e0:	89 f2                	mov    %esi,%edx
c00261e2:	89 d8                	mov    %ebx,%eax
c00261e4:	e8 25 fd ff ff       	call   c0025f0e <wait>
      lock_release (&q->lock);
c00261e9:	89 1c 24             	mov    %ebx,(%esp)
c00261ec:	e8 33 ce ff ff       	call   c0023024 <lock_release>
  while (intq_full (q))
c00261f1:	89 1c 24             	mov    %ebx,(%esp)
c00261f4:	e8 b8 fc ff ff       	call   c0025eb1 <intq_full>
c00261f9:	84 c0                	test   %al,%al
c00261fb:	75 a6                	jne    c00261a3 <intq_putc+0x48>
  q->buf[q->head] = byte;
c00261fd:	8b 53 6c             	mov    0x6c(%ebx),%edx
c0026200:	89 f8                	mov    %edi,%eax
c0026202:	88 44 13 2c          	mov    %al,0x2c(%ebx,%edx,1)
  return (pos + 1) % INTQ_BUFSIZE;
c0026206:	83 c2 01             	add    $0x1,%edx
c0026209:	89 d0                	mov    %edx,%eax
c002620b:	c1 f8 1f             	sar    $0x1f,%eax
c002620e:	c1 e8 1a             	shr    $0x1a,%eax
c0026211:	01 c2                	add    %eax,%edx
c0026213:	83 e2 3f             	and    $0x3f,%edx
c0026216:	29 c2                	sub    %eax,%edx
  q->head = next (q->head);
c0026218:	89 53 6c             	mov    %edx,0x6c(%ebx)
  signal (q, &q->not_empty);
c002621b:	8d 53 28             	lea    0x28(%ebx),%edx
c002621e:	89 d8                	mov    %ebx,%eax
c0026220:	e8 c0 fd ff ff       	call   c0025fe5 <signal>
}
c0026225:	83 c4 20             	add    $0x20,%esp
c0026228:	5b                   	pop    %ebx
c0026229:	5e                   	pop    %esi
c002622a:	5f                   	pop    %edi
c002622b:	c3                   	ret    

c002622c <rtc_get_time>:

/* Returns number of seconds since Unix epoch of January 1,
   1970. */
time_t
rtc_get_time (void)
{
c002622c:	55                   	push   %ebp
c002622d:	57                   	push   %edi
c002622e:	56                   	push   %esi
c002622f:	53                   	push   %ebx
c0026230:	83 ec 03             	sub    $0x3,%esp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026233:	bb 00 00 00 00       	mov    $0x0,%ebx
c0026238:	bd 02 00 00 00       	mov    $0x2,%ebp
c002623d:	89 d8                	mov    %ebx,%eax
c002623f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026241:	e4 71                	in     $0x71,%al

/* Returns the integer value of the given BCD byte. */
static int
bcd_to_bin (uint8_t x)
{
  return (x & 0x0f) + ((x >> 4) * 10);
c0026243:	89 c2                	mov    %eax,%edx
c0026245:	83 e2 0f             	and    $0xf,%edx
c0026248:	c0 e8 04             	shr    $0x4,%al
c002624b:	0f b6 c0             	movzbl %al,%eax
c002624e:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0026251:	8d 0c 42             	lea    (%edx,%eax,2),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026254:	89 e8                	mov    %ebp,%eax
c0026256:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026258:	e4 71                	in     $0x71,%al
c002625a:	88 04 24             	mov    %al,(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002625d:	b8 04 00 00 00       	mov    $0x4,%eax
c0026262:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026264:	e4 71                	in     $0x71,%al
c0026266:	88 44 24 01          	mov    %al,0x1(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002626a:	b8 07 00 00 00       	mov    $0x7,%eax
c002626f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026271:	e4 71                	in     $0x71,%al
c0026273:	88 44 24 02          	mov    %al,0x2(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026277:	b8 08 00 00 00       	mov    $0x8,%eax
c002627c:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002627e:	e4 71                	in     $0x71,%al
c0026280:	89 c6                	mov    %eax,%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026282:	b8 09 00 00 00       	mov    $0x9,%eax
c0026287:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026289:	e4 71                	in     $0x71,%al
c002628b:	89 c7                	mov    %eax,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002628d:	89 d8                	mov    %ebx,%eax
c002628f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026291:	e4 71                	in     $0x71,%al
c0026293:	89 c2                	mov    %eax,%edx
c0026295:	89 d0                	mov    %edx,%eax
c0026297:	83 e0 0f             	and    $0xf,%eax
c002629a:	c0 ea 04             	shr    $0x4,%dl
c002629d:	0f b6 d2             	movzbl %dl,%edx
c00262a0:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00262a3:	8d 04 50             	lea    (%eax,%edx,2),%eax
  while (sec != bcd_to_bin (cmos_read (RTC_REG_SEC)));
c00262a6:	39 c1                	cmp    %eax,%ecx
c00262a8:	75 93                	jne    c002623d <rtc_get_time+0x11>
  return (x & 0x0f) + ((x >> 4) * 10);
c00262aa:	89 fa                	mov    %edi,%edx
c00262ac:	83 e2 0f             	and    $0xf,%edx
c00262af:	89 f8                	mov    %edi,%eax
c00262b1:	c0 e8 04             	shr    $0x4,%al
c00262b4:	0f b6 f8             	movzbl %al,%edi
c00262b7:	8d 04 bf             	lea    (%edi,%edi,4),%eax
  if (year < 70)
c00262ba:	8d 04 42             	lea    (%edx,%eax,2),%eax
    year += 100;
c00262bd:	8d 50 64             	lea    0x64(%eax),%edx
c00262c0:	83 f8 45             	cmp    $0x45,%eax
c00262c3:	0f 4e c2             	cmovle %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c00262c6:	89 f2                	mov    %esi,%edx
c00262c8:	83 e2 0f             	and    $0xf,%edx
c00262cb:	89 f3                	mov    %esi,%ebx
c00262cd:	c0 eb 04             	shr    $0x4,%bl
c00262d0:	0f b6 f3             	movzbl %bl,%esi
c00262d3:	8d 1c b6             	lea    (%esi,%esi,4),%ebx
c00262d6:	8d 34 5a             	lea    (%edx,%ebx,2),%esi
  year -= 70;
c00262d9:	8d 78 ba             	lea    -0x46(%eax),%edi
  time = (year * 365 + (year - 1) / 4) * 24 * 60 * 60;
c00262dc:	69 df 6d 01 00 00    	imul   $0x16d,%edi,%ebx
c00262e2:	8d 50 bc             	lea    -0x44(%eax),%edx
c00262e5:	83 e8 47             	sub    $0x47,%eax
c00262e8:	0f 48 c2             	cmovs  %edx,%eax
c00262eb:	c1 f8 02             	sar    $0x2,%eax
c00262ee:	01 d8                	add    %ebx,%eax
c00262f0:	69 c0 80 51 01 00    	imul   $0x15180,%eax,%eax
  for (i = 1; i <= mon; i++)
c00262f6:	85 f6                	test   %esi,%esi
c00262f8:	7e 19                	jle    c0026313 <rtc_get_time+0xe7>
c00262fa:	ba 01 00 00 00       	mov    $0x1,%edx
    time += days_per_month[i - 1] * 24 * 60 * 60;
c00262ff:	69 1c 95 fc d9 02 c0 	imul   $0x15180,-0x3ffd2604(,%edx,4),%ebx
c0026306:	80 51 01 00 
c002630a:	01 d8                	add    %ebx,%eax
  for (i = 1; i <= mon; i++)
c002630c:	83 c2 01             	add    $0x1,%edx
c002630f:	39 f2                	cmp    %esi,%edx
c0026311:	7e ec                	jle    c00262ff <rtc_get_time+0xd3>
  if (mon > 2 && year % 4 == 0)
c0026313:	83 fe 02             	cmp    $0x2,%esi
c0026316:	7e 0e                	jle    c0026326 <rtc_get_time+0xfa>
c0026318:	83 e7 03             	and    $0x3,%edi
    time += 24 * 60 * 60;
c002631b:	8d 90 80 51 01 00    	lea    0x15180(%eax),%edx
c0026321:	85 ff                	test   %edi,%edi
c0026323:	0f 44 c2             	cmove  %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c0026326:	0f b6 54 24 01       	movzbl 0x1(%esp),%edx
c002632b:	89 d3                	mov    %edx,%ebx
c002632d:	83 e3 0f             	and    $0xf,%ebx
c0026330:	c0 ea 04             	shr    $0x4,%dl
c0026333:	0f b6 d2             	movzbl %dl,%edx
c0026336:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026339:	8d 1c 53             	lea    (%ebx,%edx,2),%ebx
  time += hour * 60 * 60;
c002633c:	69 db 10 0e 00 00    	imul   $0xe10,%ebx,%ebx
  return (x & 0x0f) + ((x >> 4) * 10);
c0026342:	0f b6 14 24          	movzbl (%esp),%edx
c0026346:	89 d6                	mov    %edx,%esi
c0026348:	83 e6 0f             	and    $0xf,%esi
c002634b:	c0 ea 04             	shr    $0x4,%dl
c002634e:	0f b6 d2             	movzbl %dl,%edx
c0026351:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026354:	8d 14 56             	lea    (%esi,%edx,2),%edx
  time += min * 60;
c0026357:	6b d2 3c             	imul   $0x3c,%edx,%edx
  time += (mday - 1) * 24 * 60 * 60;
c002635a:	01 da                	add    %ebx,%edx
  time += hour * 60 * 60;
c002635c:	01 d1                	add    %edx,%ecx
  return (x & 0x0f) + ((x >> 4) * 10);
c002635e:	0f b6 54 24 02       	movzbl 0x2(%esp),%edx
c0026363:	89 d3                	mov    %edx,%ebx
c0026365:	83 e3 0f             	and    $0xf,%ebx
c0026368:	c0 ea 04             	shr    $0x4,%dl
c002636b:	0f b6 d2             	movzbl %dl,%edx
c002636e:	8d 14 92             	lea    (%edx,%edx,4),%edx
  time += (mday - 1) * 24 * 60 * 60;
c0026371:	8d 54 53 ff          	lea    -0x1(%ebx,%edx,2),%edx
c0026375:	69 d2 80 51 01 00    	imul   $0x15180,%edx,%edx
  time += min * 60;
c002637b:	01 d1                	add    %edx,%ecx
  time += sec;
c002637d:	01 c8                	add    %ecx,%eax
}
c002637f:	83 c4 03             	add    $0x3,%esp
c0026382:	5b                   	pop    %ebx
c0026383:	5e                   	pop    %esi
c0026384:	5f                   	pop    %edi
c0026385:	5d                   	pop    %ebp
c0026386:	c3                   	ret    
c0026387:	90                   	nop
c0026388:	90                   	nop
c0026389:	90                   	nop
c002638a:	90                   	nop
c002638b:	90                   	nop
c002638c:	90                   	nop
c002638d:	90                   	nop
c002638e:	90                   	nop
c002638f:	90                   	nop

c0026390 <shutdown_configure>:
/* Sets TYPE as the way that machine will shut down when Pintos
   execution is complete. */
void
shutdown_configure (enum shutdown_type type)
{
  how = type;
c0026390:	8b 44 24 04          	mov    0x4(%esp),%eax
c0026394:	a3 94 79 03 c0       	mov    %eax,0xc0037994
c0026399:	c3                   	ret    

c002639a <shutdown_reboot>:
}

/* Reboots the machine via the keyboard controller. */
void
shutdown_reboot (void)
{
c002639a:	56                   	push   %esi
c002639b:	53                   	push   %ebx
c002639c:	83 ec 14             	sub    $0x14,%esp
  printf ("Rebooting...\n");
c002639f:	c7 04 24 9b f7 02 c0 	movl   $0xc002f79b,(%esp)
c00263a6:	e8 00 43 00 00       	call   c002a6ab <puts>
    {
      int i;

      /* Poll keyboard controller's status byte until
       * 'input buffer empty' is reported. */
      for (i = 0; i < 0x10000; i++)
c00263ab:	bb 00 00 00 00       	mov    $0x0,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00263b0:	be fe ff ff ff       	mov    $0xfffffffe,%esi
c00263b5:	eb 1d                	jmp    c00263d4 <shutdown_reboot+0x3a>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00263b7:	e4 64                	in     $0x64,%al
        {
          if ((inb (CONTROL_REG) & 0x02) == 0)
c00263b9:	a8 02                	test   $0x2,%al
c00263bb:	74 1f                	je     c00263dc <shutdown_reboot+0x42>
            break;
          timer_udelay (2);
c00263bd:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00263c4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263cb:	00 
c00263cc:	e8 25 e0 ff ff       	call   c00243f6 <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c00263d1:	83 c3 01             	add    $0x1,%ebx
c00263d4:	81 fb ff ff 00 00    	cmp    $0xffff,%ebx
c00263da:	7e db                	jle    c00263b7 <shutdown_reboot+0x1d>
        }

      timer_udelay (50);
c00263dc:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c00263e3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263ea:	00 
c00263eb:	e8 06 e0 ff ff       	call   c00243f6 <timer_udelay>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00263f0:	89 f0                	mov    %esi,%eax
c00263f2:	e6 64                	out    %al,$0x64

      /* Pulse bit 0 of the output port P2 of the keyboard controller.
       * This will reset the CPU. */
      outb (CONTROL_REG, 0xfe);
      timer_udelay (50);
c00263f4:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c00263fb:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026402:	00 
c0026403:	e8 ee df ff ff       	call   c00243f6 <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c0026408:	bb 00 00 00 00       	mov    $0x0,%ebx
    }
c002640d:	eb c5                	jmp    c00263d4 <shutdown_reboot+0x3a>

c002640f <shutdown_power_off>:

/* Powers down the machine we're running on,
   as long as we're running on Bochs or QEMU. */
void
shutdown_power_off (void)
{
c002640f:	83 ec 2c             	sub    $0x2c,%esp
  const char s[] = "Shutdown";
c0026412:	c7 44 24 17 53 68 75 	movl   $0x74756853,0x17(%esp)
c0026419:	74 
c002641a:	c7 44 24 1b 64 6f 77 	movl   $0x6e776f64,0x1b(%esp)
c0026421:	6e 
c0026422:	c6 44 24 1f 00       	movb   $0x0,0x1f(%esp)

/* Print statistics about Pintos execution. */
static void
print_stats (void)
{
  timer_print_stats ();
c0026427:	e8 fc df ff ff       	call   c0024428 <timer_print_stats>
  thread_print_stats ();
c002642c:	e8 84 a8 ff ff       	call   c0020cb5 <thread_print_stats>
#ifdef FILESYS
  block_print_stats ();
#endif
  console_print_stats ();
c0026431:	e8 0e 42 00 00       	call   c002a644 <console_print_stats>
  kbd_print_stats ();
c0026436:	e8 33 e2 ff ff       	call   c002466e <kbd_print_stats>
  printf ("Powering off...\n");
c002643b:	c7 04 24 a8 f7 02 c0 	movl   $0xc002f7a8,(%esp)
c0026442:	e8 64 42 00 00       	call   c002a6ab <puts>
  serial_flush ();
c0026447:	e8 50 e7 ff ff       	call   c0024b9c <serial_flush>
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c002644c:	ba 04 b0 ff ff       	mov    $0xffffb004,%edx
c0026451:	b8 00 20 00 00       	mov    $0x2000,%eax
c0026456:	66 ef                	out    %ax,(%dx)
  for (p = s; *p != '\0'; p++)
c0026458:	0f b6 44 24 17       	movzbl 0x17(%esp),%eax
c002645d:	84 c0                	test   %al,%al
c002645f:	74 14                	je     c0026475 <shutdown_power_off+0x66>
c0026461:	8d 4c 24 17          	lea    0x17(%esp),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026465:	ba 00 89 ff ff       	mov    $0xffff8900,%edx
c002646a:	ee                   	out    %al,(%dx)
c002646b:	83 c1 01             	add    $0x1,%ecx
c002646e:	0f b6 01             	movzbl (%ecx),%eax
c0026471:	84 c0                	test   %al,%al
c0026473:	75 f5                	jne    c002646a <shutdown_power_off+0x5b>
c0026475:	ba 01 05 00 00       	mov    $0x501,%edx
c002647a:	b8 31 00 00 00       	mov    $0x31,%eax
c002647f:	ee                   	out    %al,(%dx)
  asm volatile ("cli; hlt" : : : "memory");
c0026480:	fa                   	cli    
c0026481:	f4                   	hlt    
  printf ("still running...\n");
c0026482:	c7 04 24 b8 f7 02 c0 	movl   $0xc002f7b8,(%esp)
c0026489:	e8 1d 42 00 00       	call   c002a6ab <puts>
c002648e:	eb fe                	jmp    c002648e <shutdown_power_off+0x7f>

c0026490 <shutdown>:
{
c0026490:	83 ec 0c             	sub    $0xc,%esp
  switch (how)
c0026493:	a1 94 79 03 c0       	mov    0xc0037994,%eax
c0026498:	83 f8 01             	cmp    $0x1,%eax
c002649b:	74 07                	je     c00264a4 <shutdown+0x14>
c002649d:	83 f8 02             	cmp    $0x2,%eax
c00264a0:	74 07                	je     c00264a9 <shutdown+0x19>
c00264a2:	eb 11                	jmp    c00264b5 <shutdown+0x25>
      shutdown_power_off ();
c00264a4:	e8 66 ff ff ff       	call   c002640f <shutdown_power_off>
c00264a9:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
      shutdown_reboot ();
c00264b0:	e8 e5 fe ff ff       	call   c002639a <shutdown_reboot>
}
c00264b5:	83 c4 0c             	add    $0xc,%esp
c00264b8:	c3                   	ret    
c00264b9:	90                   	nop
c00264ba:	90                   	nop
c00264bb:	90                   	nop
c00264bc:	90                   	nop
c00264bd:	90                   	nop
c00264be:	90                   	nop
c00264bf:	90                   	nop

c00264c0 <speaker_off>:

/* Turn off the PC speaker, by disconnecting the timer channel's
   output from the speaker. */
void
speaker_off (void)
{
c00264c0:	83 ec 1c             	sub    $0x1c,%esp
  enum intr_level old_level = intr_disable ();
c00264c3:	e8 f7 b4 ff ff       	call   c00219bf <intr_disable>
c00264c8:	89 c2                	mov    %eax,%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00264ca:	e4 61                	in     $0x61,%al
  outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) & ~SPEAKER_GATE_ENABLE);
c00264cc:	83 e0 fc             	and    $0xfffffffc,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00264cf:	e6 61                	out    %al,$0x61
  intr_set_level (old_level);
c00264d1:	89 14 24             	mov    %edx,(%esp)
c00264d4:	e8 ed b4 ff ff       	call   c00219c6 <intr_set_level>
}
c00264d9:	83 c4 1c             	add    $0x1c,%esp
c00264dc:	c3                   	ret    

c00264dd <speaker_on>:
{
c00264dd:	56                   	push   %esi
c00264de:	53                   	push   %ebx
c00264df:	83 ec 14             	sub    $0x14,%esp
c00264e2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (frequency >= 20 && frequency <= 20000)
c00264e6:	8d 43 ec             	lea    -0x14(%ebx),%eax
c00264e9:	3d 0c 4e 00 00       	cmp    $0x4e0c,%eax
c00264ee:	77 30                	ja     c0026520 <speaker_on+0x43>
      enum intr_level old_level = intr_disable ();
c00264f0:	e8 ca b4 ff ff       	call   c00219bf <intr_disable>
c00264f5:	89 c6                	mov    %eax,%esi
      pit_configure_channel (2, 3, frequency);
c00264f7:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00264fb:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c0026502:	00 
c0026503:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c002650a:	e8 00 d8 ff ff       	call   c0023d0f <pit_configure_channel>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002650f:	e4 61                	in     $0x61,%al
      outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) | SPEAKER_GATE_ENABLE);
c0026511:	83 c8 03             	or     $0x3,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026514:	e6 61                	out    %al,$0x61
      intr_set_level (old_level);
c0026516:	89 34 24             	mov    %esi,(%esp)
c0026519:	e8 a8 b4 ff ff       	call   c00219c6 <intr_set_level>
c002651e:	eb 05                	jmp    c0026525 <speaker_on+0x48>
      speaker_off ();
c0026520:	e8 9b ff ff ff       	call   c00264c0 <speaker_off>
}
c0026525:	83 c4 14             	add    $0x14,%esp
c0026528:	5b                   	pop    %ebx
c0026529:	5e                   	pop    %esi
c002652a:	c3                   	ret    

c002652b <speaker_beep>:

/* Briefly beep the PC speaker. */
void
speaker_beep (void)
{
c002652b:	83 ec 1c             	sub    $0x1c,%esp

     We can't just enable interrupts while we sleep.  For one
     thing, we get called (indirectly) from printf, which should
     always work, even during boot before we're ready to enable
     interrupts. */
  if (intr_get_level () == INTR_ON)
c002652e:	e8 41 b4 ff ff       	call   c0021974 <intr_get_level>
c0026533:	83 f8 01             	cmp    $0x1,%eax
c0026536:	75 25                	jne    c002655d <speaker_beep+0x32>
    {
      speaker_on (440);
c0026538:	c7 04 24 b8 01 00 00 	movl   $0x1b8,(%esp)
c002653f:	e8 99 ff ff ff       	call   c00264dd <speaker_on>
      timer_msleep (250);
c0026544:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002654b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026552:	00 
c0026553:	e8 3a de ff ff       	call   c0024392 <timer_msleep>
      speaker_off ();
c0026558:	e8 63 ff ff ff       	call   c00264c0 <speaker_off>
    }
}
c002655d:	83 c4 1c             	add    $0x1c,%esp
c0026560:	c3                   	ret    

c0026561 <debug_backtrace>:
   each of the functions we are nested within.  gdb or addr2line
   may be applied to kernel.o to translate these into file names,
   line numbers, and function names.  */
void
debug_backtrace (void) 
{
c0026561:	55                   	push   %ebp
c0026562:	89 e5                	mov    %esp,%ebp
c0026564:	53                   	push   %ebx
c0026565:	83 ec 14             	sub    $0x14,%esp
  static bool explained;
  void **frame;
  
  printf ("Call stack: %p", __builtin_return_address (0));
c0026568:	8b 45 04             	mov    0x4(%ebp),%eax
c002656b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002656f:	c7 04 24 c9 f7 02 c0 	movl   $0xc002f7c9,(%esp)
c0026576:	e8 b3 05 00 00       	call   c0026b2e <printf>
  for (frame = __builtin_frame_address (1);
c002657b:	8b 5d 00             	mov    0x0(%ebp),%ebx
c002657e:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0026584:	76 27                	jbe    c00265ad <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c0026586:	83 3b 00             	cmpl   $0x0,(%ebx)
c0026589:	74 22                	je     c00265ad <debug_backtrace+0x4c>
       frame = frame[0]) 
    printf (" %p", frame[1]);
c002658b:	8b 43 04             	mov    0x4(%ebx),%eax
c002658e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026592:	c7 04 24 d4 f7 02 c0 	movl   $0xc002f7d4,(%esp)
c0026599:	e8 90 05 00 00       	call   c0026b2e <printf>
       frame = frame[0]) 
c002659e:	8b 1b                	mov    (%ebx),%ebx
  for (frame = __builtin_frame_address (1);
c00265a0:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00265a6:	76 05                	jbe    c00265ad <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c00265a8:	83 3b 00             	cmpl   $0x0,(%ebx)
c00265ab:	75 de                	jne    c002658b <debug_backtrace+0x2a>
  printf (".\n");
c00265ad:	c7 04 24 6b f3 02 c0 	movl   $0xc002f36b,(%esp)
c00265b4:	e8 f2 40 00 00       	call   c002a6ab <puts>

  if (!explained) 
c00265b9:	80 3d 98 79 03 c0 00 	cmpb   $0x0,0xc0037998
c00265c0:	75 13                	jne    c00265d5 <debug_backtrace+0x74>
    {
      explained = true;
c00265c2:	c6 05 98 79 03 c0 01 	movb   $0x1,0xc0037998
      printf ("The `backtrace' program can make call stacks useful.\n"
c00265c9:	c7 04 24 d8 f7 02 c0 	movl   $0xc002f7d8,(%esp)
c00265d0:	e8 d6 40 00 00       	call   c002a6ab <puts>
              "Read \"Backtraces\" in the \"Debugging Tools\" chapter\n"
              "of the Pintos documentation for more information.\n");
    }
}
c00265d5:	83 c4 14             	add    $0x14,%esp
c00265d8:	5b                   	pop    %ebx
c00265d9:	5d                   	pop    %ebp
c00265da:	c3                   	ret    

c00265db <random_init>:
{
  uint8_t *seedp = (uint8_t *) &seed;
  int i;
  uint8_t j;

  for (i = 0; i < 256; i++) 
c00265db:	b8 00 00 00 00       	mov    $0x0,%eax
    s[i] = i;
c00265e0:	88 80 c0 79 03 c0    	mov    %al,-0x3ffc8640(%eax)
  for (i = 0; i < 256; i++) 
c00265e6:	83 c0 01             	add    $0x1,%eax
c00265e9:	3d 00 01 00 00       	cmp    $0x100,%eax
c00265ee:	75 f0                	jne    c00265e0 <random_init+0x5>
{
c00265f0:	56                   	push   %esi
c00265f1:	53                   	push   %ebx
  for (i = 0; i < 256; i++) 
c00265f2:	be 00 00 00 00       	mov    $0x0,%esi
c00265f7:	66 b8 00 00          	mov    $0x0,%ax
  for (i = j = 0; i < 256; i++) 
    {
      j += s[i] + seedp[i % sizeof seed];
c00265fb:	89 c1                	mov    %eax,%ecx
c00265fd:	83 e1 03             	and    $0x3,%ecx
c0026600:	0f b6 98 c0 79 03 c0 	movzbl -0x3ffc8640(%eax),%ebx
c0026607:	89 da                	mov    %ebx,%edx
c0026609:	02 54 0c 0c          	add    0xc(%esp,%ecx,1),%dl
c002660d:	89 d1                	mov    %edx,%ecx
c002660f:	01 ce                	add    %ecx,%esi
      swap_byte (s + i, s + j);
c0026611:	89 f2                	mov    %esi,%edx
c0026613:	0f b6 ca             	movzbl %dl,%ecx
  *a = *b;
c0026616:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c002661d:	88 90 c0 79 03 c0    	mov    %dl,-0x3ffc8640(%eax)
  *b = t;
c0026623:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)
  for (i = j = 0; i < 256; i++) 
c0026629:	83 c0 01             	add    $0x1,%eax
c002662c:	3d 00 01 00 00       	cmp    $0x100,%eax
c0026631:	75 c8                	jne    c00265fb <random_init+0x20>
    }

  s_i = s_j = 0;
c0026633:	c6 05 a1 79 03 c0 00 	movb   $0x0,0xc00379a1
c002663a:	c6 05 a2 79 03 c0 00 	movb   $0x0,0xc00379a2
  inited = true;
c0026641:	c6 05 a0 79 03 c0 01 	movb   $0x1,0xc00379a0
}
c0026648:	5b                   	pop    %ebx
c0026649:	5e                   	pop    %esi
c002664a:	c3                   	ret    

c002664b <random_bytes>:

/* Writes SIZE random bytes into BUF. */
void
random_bytes (void *buf_, size_t size) 
{
c002664b:	55                   	push   %ebp
c002664c:	57                   	push   %edi
c002664d:	56                   	push   %esi
c002664e:	53                   	push   %ebx
c002664f:	83 ec 0c             	sub    $0xc,%esp
  uint8_t *buf;

  if (!inited)
c0026652:	80 3d a0 79 03 c0 00 	cmpb   $0x0,0xc00379a0
c0026659:	75 0c                	jne    c0026667 <random_bytes+0x1c>
    random_init (0);
c002665b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0026662:	e8 74 ff ff ff       	call   c00265db <random_init>

  for (buf = buf_; size-- > 0; buf++)
c0026667:	8b 44 24 24          	mov    0x24(%esp),%eax
c002666b:	83 e8 01             	sub    $0x1,%eax
c002666e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0026672:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0026677:	0f 84 87 00 00 00    	je     c0026704 <random_bytes+0xb9>
c002667d:	0f b6 1d a1 79 03 c0 	movzbl 0xc00379a1,%ebx
c0026684:	b8 00 00 00 00       	mov    $0x0,%eax
c0026689:	0f b6 35 a2 79 03 c0 	movzbl 0xc00379a2,%esi
c0026690:	83 c6 01             	add    $0x1,%esi
c0026693:	89 f5                	mov    %esi,%ebp
c0026695:	8d 14 06             	lea    (%esi,%eax,1),%edx
    {
      uint8_t s_k;
      
      s_i++;
      s_j += s[s_i];
c0026698:	0f b6 d2             	movzbl %dl,%edx
c002669b:	02 9a c0 79 03 c0    	add    -0x3ffc8640(%edx),%bl
c00266a1:	88 5c 24 07          	mov    %bl,0x7(%esp)
      swap_byte (s + s_i, s + s_j);
c00266a5:	0f b6 cb             	movzbl %bl,%ecx
  uint8_t t = *a;
c00266a8:	0f b6 ba c0 79 03 c0 	movzbl -0x3ffc8640(%edx),%edi
  *a = *b;
c00266af:	0f b6 99 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%ebx
c00266b6:	88 9a c0 79 03 c0    	mov    %bl,-0x3ffc8640(%edx)
  *b = t;
c00266bc:	89 fb                	mov    %edi,%ebx
c00266be:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)

      s_k = s[s_i] + s[s_j];
c00266c4:	89 f9                	mov    %edi,%ecx
c00266c6:	02 8a c0 79 03 c0    	add    -0x3ffc8640(%edx),%cl
      *buf = s[s_k];
c00266cc:	0f b6 c9             	movzbl %cl,%ecx
c00266cf:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c00266d6:	8b 7c 24 20          	mov    0x20(%esp),%edi
c00266da:	88 14 07             	mov    %dl,(%edi,%eax,1)
c00266dd:	83 c0 01             	add    $0x1,%eax
  for (buf = buf_; size-- > 0; buf++)
c00266e0:	3b 44 24 24          	cmp    0x24(%esp),%eax
c00266e4:	74 07                	je     c00266ed <random_bytes+0xa2>
      s_j += s[s_i];
c00266e6:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c00266eb:	eb a6                	jmp    c0026693 <random_bytes+0x48>
c00266ed:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c00266f2:	0f b6 44 24 08       	movzbl 0x8(%esp),%eax
c00266f7:	01 e8                	add    %ebp,%eax
c00266f9:	a2 a2 79 03 c0       	mov    %al,0xc00379a2
c00266fe:	88 1d a1 79 03 c0    	mov    %bl,0xc00379a1
    }
}
c0026704:	83 c4 0c             	add    $0xc,%esp
c0026707:	5b                   	pop    %ebx
c0026708:	5e                   	pop    %esi
c0026709:	5f                   	pop    %edi
c002670a:	5d                   	pop    %ebp
c002670b:	c3                   	ret    

c002670c <random_ulong>:
/* Returns a pseudo-random unsigned long.
   Use random_ulong() % n to obtain a random number in the range
   0...n (exclusive). */
unsigned long
random_ulong (void) 
{
c002670c:	83 ec 18             	sub    $0x18,%esp
  unsigned long ul;
  random_bytes (&ul, sizeof ul);
c002670f:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c0026716:	00 
c0026717:	8d 44 24 14          	lea    0x14(%esp),%eax
c002671b:	89 04 24             	mov    %eax,(%esp)
c002671e:	e8 28 ff ff ff       	call   c002664b <random_bytes>
  return ul;
}
c0026723:	8b 44 24 14          	mov    0x14(%esp),%eax
c0026727:	83 c4 18             	add    $0x18,%esp
c002672a:	c3                   	ret    
c002672b:	90                   	nop
c002672c:	90                   	nop
c002672d:	90                   	nop
c002672e:	90                   	nop
c002672f:	90                   	nop

c0026730 <vsnprintf_helper>:
}

/* Helper function for vsnprintf(). */
static void
vsnprintf_helper (char ch, void *aux_)
{
c0026730:	53                   	push   %ebx
c0026731:	8b 5c 24 08          	mov    0x8(%esp),%ebx
c0026735:	8b 44 24 0c          	mov    0xc(%esp),%eax
  struct vsnprintf_aux *aux = aux_;

  if (aux->length++ < aux->max_length)
c0026739:	8b 50 04             	mov    0x4(%eax),%edx
c002673c:	8d 4a 01             	lea    0x1(%edx),%ecx
c002673f:	89 48 04             	mov    %ecx,0x4(%eax)
c0026742:	3b 50 08             	cmp    0x8(%eax),%edx
c0026745:	7d 09                	jge    c0026750 <vsnprintf_helper+0x20>
    *aux->p++ = ch;
c0026747:	8b 10                	mov    (%eax),%edx
c0026749:	8d 4a 01             	lea    0x1(%edx),%ecx
c002674c:	89 08                	mov    %ecx,(%eax)
c002674e:	88 1a                	mov    %bl,(%edx)
}
c0026750:	5b                   	pop    %ebx
c0026751:	c3                   	ret    

c0026752 <output_dup>:
}

/* Writes CH to OUTPUT with auxiliary data AUX, CNT times. */
static void
output_dup (char ch, size_t cnt, void (*output) (char, void *), void *aux) 
{
c0026752:	55                   	push   %ebp
c0026753:	57                   	push   %edi
c0026754:	56                   	push   %esi
c0026755:	53                   	push   %ebx
c0026756:	83 ec 1c             	sub    $0x1c,%esp
c0026759:	8b 7c 24 30          	mov    0x30(%esp),%edi
  while (cnt-- > 0)
c002675d:	85 d2                	test   %edx,%edx
c002675f:	74 15                	je     c0026776 <output_dup+0x24>
c0026761:	89 ce                	mov    %ecx,%esi
c0026763:	89 d3                	mov    %edx,%ebx
    output (ch, aux);
c0026765:	0f be e8             	movsbl %al,%ebp
c0026768:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002676c:	89 2c 24             	mov    %ebp,(%esp)
c002676f:	ff d6                	call   *%esi
  while (cnt-- > 0)
c0026771:	83 eb 01             	sub    $0x1,%ebx
c0026774:	75 f2                	jne    c0026768 <output_dup+0x16>
}
c0026776:	83 c4 1c             	add    $0x1c,%esp
c0026779:	5b                   	pop    %ebx
c002677a:	5e                   	pop    %esi
c002677b:	5f                   	pop    %edi
c002677c:	5d                   	pop    %ebp
c002677d:	c3                   	ret    

c002677e <format_integer>:
{
c002677e:	55                   	push   %ebp
c002677f:	57                   	push   %edi
c0026780:	56                   	push   %esi
c0026781:	53                   	push   %ebx
c0026782:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c0026788:	89 c6                	mov    %eax,%esi
c002678a:	89 d7                	mov    %edx,%edi
c002678c:	8b 84 24 a0 00 00 00 	mov    0xa0(%esp),%eax
  sign = 0;
c0026793:	c7 44 24 30 00 00 00 	movl   $0x0,0x30(%esp)
c002679a:	00 
  if (is_signed) 
c002679b:	84 c9                	test   %cl,%cl
c002679d:	74 4c                	je     c00267eb <format_integer+0x6d>
      if (c->flags & PLUS)
c002679f:	8b 8c 24 a8 00 00 00 	mov    0xa8(%esp),%ecx
c00267a6:	8b 11                	mov    (%ecx),%edx
c00267a8:	f6 c2 02             	test   $0x2,%dl
c00267ab:	74 14                	je     c00267c1 <format_integer+0x43>
        sign = negative ? '-' : '+';
c00267ad:	3c 01                	cmp    $0x1,%al
c00267af:	19 c0                	sbb    %eax,%eax
c00267b1:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267b5:	83 64 24 30 fe       	andl   $0xfffffffe,0x30(%esp)
c00267ba:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c00267bf:	eb 2a                	jmp    c00267eb <format_integer+0x6d>
      else if (c->flags & SPACE)
c00267c1:	f6 c2 04             	test   $0x4,%dl
c00267c4:	74 14                	je     c00267da <format_integer+0x5c>
        sign = negative ? '-' : ' ';
c00267c6:	3c 01                	cmp    $0x1,%al
c00267c8:	19 c0                	sbb    %eax,%eax
c00267ca:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267ce:	83 64 24 30 f3       	andl   $0xfffffff3,0x30(%esp)
c00267d3:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c00267d8:	eb 11                	jmp    c00267eb <format_integer+0x6d>
  sign = 0;
c00267da:	3c 01                	cmp    $0x1,%al
c00267dc:	19 c0                	sbb    %eax,%eax
c00267de:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267e2:	f7 54 24 30          	notl   0x30(%esp)
c00267e6:	83 64 24 30 2d       	andl   $0x2d,0x30(%esp)
  x = (c->flags & POUND) && value ? b->x : 0;
c00267eb:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c00267f2:	8b 00                	mov    (%eax),%eax
c00267f4:	89 44 24 38          	mov    %eax,0x38(%esp)
c00267f8:	83 e0 08             	and    $0x8,%eax
c00267fb:	89 44 24 3c          	mov    %eax,0x3c(%esp)
c00267ff:	74 5c                	je     c002685d <format_integer+0xdf>
c0026801:	89 f8                	mov    %edi,%eax
c0026803:	09 f0                	or     %esi,%eax
c0026805:	0f 84 e9 00 00 00    	je     c00268f4 <format_integer+0x176>
c002680b:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026812:	8b 40 08             	mov    0x8(%eax),%eax
c0026815:	89 44 24 34          	mov    %eax,0x34(%esp)
c0026819:	eb 08                	jmp    c0026823 <format_integer+0xa5>
c002681b:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c0026822:	00 
      *cp++ = b->digits[value % b->base];
c0026823:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c002682a:	8b 40 04             	mov    0x4(%eax),%eax
c002682d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026831:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026838:	8b 00                	mov    (%eax),%eax
c002683a:	89 44 24 18          	mov    %eax,0x18(%esp)
c002683e:	89 c1                	mov    %eax,%ecx
c0026840:	c1 f9 1f             	sar    $0x1f,%ecx
c0026843:	89 4c 24 1c          	mov    %ecx,0x1c(%esp)
c0026847:	bb 00 00 00 00       	mov    $0x0,%ebx
c002684c:	8d 6c 24 40          	lea    0x40(%esp),%ebp
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026850:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026854:	83 e0 20             	and    $0x20,%eax
c0026857:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c002685b:	eb 17                	jmp    c0026874 <format_integer+0xf6>
  while (value > 0) 
c002685d:	89 f8                	mov    %edi,%eax
c002685f:	09 f0                	or     %esi,%eax
c0026861:	75 b8                	jne    c002681b <format_integer+0x9d>
  x = (c->flags & POUND) && value ? b->x : 0;
c0026863:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c002686a:	00 
  cp = buf;
c002686b:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c002686f:	e9 92 00 00 00       	jmp    c0026906 <format_integer+0x188>
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026874:	83 7c 24 2c 00       	cmpl   $0x0,0x2c(%esp)
c0026879:	74 1c                	je     c0026897 <format_integer+0x119>
c002687b:	85 db                	test   %ebx,%ebx
c002687d:	7e 18                	jle    c0026897 <format_integer+0x119>
c002687f:	8b 8c 24 a4 00 00 00 	mov    0xa4(%esp),%ecx
c0026886:	89 d8                	mov    %ebx,%eax
c0026888:	99                   	cltd   
c0026889:	f7 79 0c             	idivl  0xc(%ecx)
c002688c:	85 d2                	test   %edx,%edx
c002688e:	75 07                	jne    c0026897 <format_integer+0x119>
        *cp++ = ',';
c0026890:	c6 45 00 2c          	movb   $0x2c,0x0(%ebp)
c0026894:	8d 6d 01             	lea    0x1(%ebp),%ebp
      *cp++ = b->digits[value % b->base];
c0026897:	8d 45 01             	lea    0x1(%ebp),%eax
c002689a:	89 44 24 24          	mov    %eax,0x24(%esp)
c002689e:	8b 44 24 18          	mov    0x18(%esp),%eax
c00268a2:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00268a6:	89 44 24 08          	mov    %eax,0x8(%esp)
c00268aa:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00268ae:	89 34 24             	mov    %esi,(%esp)
c00268b1:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00268b5:	e8 a0 1a 00 00       	call   c002835a <__umoddi3>
c00268ba:	8b 4c 24 28          	mov    0x28(%esp),%ecx
c00268be:	0f b6 04 01          	movzbl (%ecx,%eax,1),%eax
c00268c2:	88 45 00             	mov    %al,0x0(%ebp)
      value /= b->base;
c00268c5:	8b 44 24 18          	mov    0x18(%esp),%eax
c00268c9:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00268cd:	89 44 24 08          	mov    %eax,0x8(%esp)
c00268d1:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00268d5:	89 34 24             	mov    %esi,(%esp)
c00268d8:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00268dc:	e8 56 1a 00 00       	call   c0028337 <__udivdi3>
c00268e1:	89 c6                	mov    %eax,%esi
c00268e3:	89 d7                	mov    %edx,%edi
      digit_cnt++;
c00268e5:	83 c3 01             	add    $0x1,%ebx
  while (value > 0) 
c00268e8:	89 d1                	mov    %edx,%ecx
c00268ea:	09 c1                	or     %eax,%ecx
c00268ec:	74 14                	je     c0026902 <format_integer+0x184>
      *cp++ = b->digits[value % b->base];
c00268ee:	8b 6c 24 24          	mov    0x24(%esp),%ebp
c00268f2:	eb 80                	jmp    c0026874 <format_integer+0xf6>
  x = (c->flags & POUND) && value ? b->x : 0;
c00268f4:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c00268fb:	00 
  cp = buf;
c00268fc:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c0026900:	eb 04                	jmp    c0026906 <format_integer+0x188>
c0026902:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  precision = c->precision < 0 ? 1 : c->precision;
c0026906:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c002690d:	8b 50 08             	mov    0x8(%eax),%edx
c0026910:	85 d2                	test   %edx,%edx
c0026912:	b8 01 00 00 00       	mov    $0x1,%eax
c0026917:	0f 48 d0             	cmovs  %eax,%edx
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002691a:	8d 7c 24 40          	lea    0x40(%esp),%edi
c002691e:	89 d8                	mov    %ebx,%eax
c0026920:	29 f8                	sub    %edi,%eax
c0026922:	39 c2                	cmp    %eax,%edx
c0026924:	7e 1f                	jle    c0026945 <format_integer+0x1c7>
c0026926:	8d 44 24 7f          	lea    0x7f(%esp),%eax
c002692a:	39 c3                	cmp    %eax,%ebx
c002692c:	73 17                	jae    c0026945 <format_integer+0x1c7>
c002692e:	89 f9                	mov    %edi,%ecx
c0026930:	89 c6                	mov    %eax,%esi
    *cp++ = '0';
c0026932:	83 c3 01             	add    $0x1,%ebx
c0026935:	c6 43 ff 30          	movb   $0x30,-0x1(%ebx)
c0026939:	89 d8                	mov    %ebx,%eax
c002693b:	29 c8                	sub    %ecx,%eax
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002693d:	39 c2                	cmp    %eax,%edx
c002693f:	7e 04                	jle    c0026945 <format_integer+0x1c7>
c0026941:	39 f3                	cmp    %esi,%ebx
c0026943:	75 ed                	jne    c0026932 <format_integer+0x1b4>
  if ((c->flags & POUND) && b->base == 8 && (cp == buf || cp[-1] != '0'))
c0026945:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002694a:	74 20                	je     c002696c <format_integer+0x1ee>
c002694c:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026953:	83 38 08             	cmpl   $0x8,(%eax)
c0026956:	75 14                	jne    c002696c <format_integer+0x1ee>
c0026958:	8d 44 24 40          	lea    0x40(%esp),%eax
c002695c:	39 c3                	cmp    %eax,%ebx
c002695e:	74 06                	je     c0026966 <format_integer+0x1e8>
c0026960:	80 7b ff 30          	cmpb   $0x30,-0x1(%ebx)
c0026964:	74 06                	je     c002696c <format_integer+0x1ee>
    *cp++ = '0';
c0026966:	c6 03 30             	movb   $0x30,(%ebx)
c0026969:	8d 5b 01             	lea    0x1(%ebx),%ebx
  pad_cnt = c->width - (cp - buf) - (x ? 2 : 0) - (sign != 0);
c002696c:	29 df                	sub    %ebx,%edi
c002696e:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026975:	03 78 04             	add    0x4(%eax),%edi
c0026978:	83 7c 24 34 01       	cmpl   $0x1,0x34(%esp)
c002697d:	19 c0                	sbb    %eax,%eax
c002697f:	f7 d0                	not    %eax
c0026981:	83 e0 02             	and    $0x2,%eax
c0026984:	83 7c 24 30 00       	cmpl   $0x0,0x30(%esp)
c0026989:	0f 95 c1             	setne  %cl
c002698c:	89 ce                	mov    %ecx,%esi
c002698e:	29 c7                	sub    %eax,%edi
c0026990:	0f b6 c1             	movzbl %cl,%eax
c0026993:	29 c7                	sub    %eax,%edi
c0026995:	b8 00 00 00 00       	mov    $0x0,%eax
c002699a:	0f 48 f8             	cmovs  %eax,%edi
  if ((c->flags & (MINUS | ZERO)) == 0)
c002699d:	f6 44 24 38 11       	testb  $0x11,0x38(%esp)
c00269a2:	75 1d                	jne    c00269c1 <format_integer+0x243>
    output_dup (' ', pad_cnt, output, aux);
c00269a4:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269ab:	89 04 24             	mov    %eax,(%esp)
c00269ae:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c00269b5:	89 fa                	mov    %edi,%edx
c00269b7:	b8 20 00 00 00       	mov    $0x20,%eax
c00269bc:	e8 91 fd ff ff       	call   c0026752 <output_dup>
  if (sign)
c00269c1:	89 f0                	mov    %esi,%eax
c00269c3:	84 c0                	test   %al,%al
c00269c5:	74 19                	je     c00269e0 <format_integer+0x262>
    output (sign, aux);
c00269c7:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269ce:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269d2:	8b 44 24 30          	mov    0x30(%esp),%eax
c00269d6:	89 04 24             	mov    %eax,(%esp)
c00269d9:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (x) 
c00269e0:	83 7c 24 34 00       	cmpl   $0x0,0x34(%esp)
c00269e5:	74 33                	je     c0026a1a <format_integer+0x29c>
      output ('0', aux);
c00269e7:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269ee:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269f2:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
c00269f9:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
      output (x, aux); 
c0026a00:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a07:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026a0b:	0f be 44 24 34       	movsbl 0x34(%esp),%eax
c0026a10:	89 04 24             	mov    %eax,(%esp)
c0026a13:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (c->flags & ZERO)
c0026a1a:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a21:	f6 00 10             	testb  $0x10,(%eax)
c0026a24:	74 1d                	je     c0026a43 <format_integer+0x2c5>
    output_dup ('0', pad_cnt, output, aux);
c0026a26:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a2d:	89 04 24             	mov    %eax,(%esp)
c0026a30:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a37:	89 fa                	mov    %edi,%edx
c0026a39:	b8 30 00 00 00       	mov    $0x30,%eax
c0026a3e:	e8 0f fd ff ff       	call   c0026752 <output_dup>
  while (cp > buf)
c0026a43:	8d 44 24 40          	lea    0x40(%esp),%eax
c0026a47:	39 c3                	cmp    %eax,%ebx
c0026a49:	76 2b                	jbe    c0026a76 <format_integer+0x2f8>
c0026a4b:	89 c6                	mov    %eax,%esi
c0026a4d:	89 7c 24 18          	mov    %edi,0x18(%esp)
c0026a51:	8b bc 24 ac 00 00 00 	mov    0xac(%esp),%edi
c0026a58:	8b ac 24 b0 00 00 00 	mov    0xb0(%esp),%ebp
    output (*--cp, aux);
c0026a5f:	83 eb 01             	sub    $0x1,%ebx
c0026a62:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0026a66:	0f be 03             	movsbl (%ebx),%eax
c0026a69:	89 04 24             	mov    %eax,(%esp)
c0026a6c:	ff d7                	call   *%edi
  while (cp > buf)
c0026a6e:	39 f3                	cmp    %esi,%ebx
c0026a70:	75 ed                	jne    c0026a5f <format_integer+0x2e1>
c0026a72:	8b 7c 24 18          	mov    0x18(%esp),%edi
  if (c->flags & MINUS)
c0026a76:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a7d:	f6 00 01             	testb  $0x1,(%eax)
c0026a80:	74 1d                	je     c0026a9f <format_integer+0x321>
    output_dup (' ', pad_cnt, output, aux);
c0026a82:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a89:	89 04 24             	mov    %eax,(%esp)
c0026a8c:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a93:	89 fa                	mov    %edi,%edx
c0026a95:	b8 20 00 00 00       	mov    $0x20,%eax
c0026a9a:	e8 b3 fc ff ff       	call   c0026752 <output_dup>
}
c0026a9f:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c0026aa5:	5b                   	pop    %ebx
c0026aa6:	5e                   	pop    %esi
c0026aa7:	5f                   	pop    %edi
c0026aa8:	5d                   	pop    %ebp
c0026aa9:	c3                   	ret    

c0026aaa <format_string>:
   auxiliary data AUX. */
static void
format_string (const char *string, int length,
               struct printf_conversion *c,
               void (*output) (char, void *), void *aux) 
{
c0026aaa:	55                   	push   %ebp
c0026aab:	57                   	push   %edi
c0026aac:	56                   	push   %esi
c0026aad:	53                   	push   %ebx
c0026aae:	83 ec 1c             	sub    $0x1c,%esp
c0026ab1:	89 c5                	mov    %eax,%ebp
c0026ab3:	89 d3                	mov    %edx,%ebx
c0026ab5:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026ab9:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0026abd:	8b 74 24 30          	mov    0x30(%esp),%esi
c0026ac1:	8b 7c 24 34          	mov    0x34(%esp),%edi
  int i;
  if (c->width > length && (c->flags & MINUS) == 0)
c0026ac5:	8b 51 04             	mov    0x4(%ecx),%edx
c0026ac8:	39 da                	cmp    %ebx,%edx
c0026aca:	7e 16                	jle    c0026ae2 <format_string+0x38>
c0026acc:	f6 01 01             	testb  $0x1,(%ecx)
c0026acf:	75 11                	jne    c0026ae2 <format_string+0x38>
    output_dup (' ', c->width - length, output, aux);
c0026ad1:	29 da                	sub    %ebx,%edx
c0026ad3:	89 3c 24             	mov    %edi,(%esp)
c0026ad6:	89 f1                	mov    %esi,%ecx
c0026ad8:	b8 20 00 00 00       	mov    $0x20,%eax
c0026add:	e8 70 fc ff ff       	call   c0026752 <output_dup>
  for (i = 0; i < length; i++)
c0026ae2:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026ae6:	85 c0                	test   %eax,%eax
c0026ae8:	7e 17                	jle    c0026b01 <format_string+0x57>
c0026aea:	89 eb                	mov    %ebp,%ebx
c0026aec:	01 c5                	add    %eax,%ebp
    output (string[i], aux);
c0026aee:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0026af2:	0f be 03             	movsbl (%ebx),%eax
c0026af5:	89 04 24             	mov    %eax,(%esp)
c0026af8:	ff d6                	call   *%esi
c0026afa:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < length; i++)
c0026afd:	39 eb                	cmp    %ebp,%ebx
c0026aff:	75 ed                	jne    c0026aee <format_string+0x44>
  if (c->width > length && (c->flags & MINUS) != 0)
c0026b01:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0026b05:	8b 50 04             	mov    0x4(%eax),%edx
c0026b08:	39 54 24 08          	cmp    %edx,0x8(%esp)
c0026b0c:	7d 18                	jge    c0026b26 <format_string+0x7c>
c0026b0e:	f6 00 01             	testb  $0x1,(%eax)
c0026b11:	74 13                	je     c0026b26 <format_string+0x7c>
    output_dup (' ', c->width - length, output, aux);
c0026b13:	2b 54 24 08          	sub    0x8(%esp),%edx
c0026b17:	89 3c 24             	mov    %edi,(%esp)
c0026b1a:	89 f1                	mov    %esi,%ecx
c0026b1c:	b8 20 00 00 00       	mov    $0x20,%eax
c0026b21:	e8 2c fc ff ff       	call   c0026752 <output_dup>
}
c0026b26:	83 c4 1c             	add    $0x1c,%esp
c0026b29:	5b                   	pop    %ebx
c0026b2a:	5e                   	pop    %esi
c0026b2b:	5f                   	pop    %edi
c0026b2c:	5d                   	pop    %ebp
c0026b2d:	c3                   	ret    

c0026b2e <printf>:
{
c0026b2e:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0026b31:	8d 44 24 24          	lea    0x24(%esp),%eax
  retval = vprintf (format, args);
c0026b35:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b39:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b3d:	89 04 24             	mov    %eax,(%esp)
c0026b40:	e8 25 3b 00 00       	call   c002a66a <vprintf>
}
c0026b45:	83 c4 1c             	add    $0x1c,%esp
c0026b48:	c3                   	ret    

c0026b49 <__printf>:
/* Wrapper for __vprintf() that converts varargs into a
   va_list. */
void
__printf (const char *format,
          void (*output) (char, void *), void *aux, ...) 
{
c0026b49:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;

  va_start (args, aux);
c0026b4c:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  __vprintf (format, args, output, aux);
c0026b50:	8b 54 24 28          	mov    0x28(%esp),%edx
c0026b54:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0026b58:	8b 54 24 24          	mov    0x24(%esp),%edx
c0026b5c:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026b60:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b64:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b68:	89 04 24             	mov    %eax,(%esp)
c0026b6b:	e8 04 00 00 00       	call   c0026b74 <__vprintf>
  va_end (args);
}
c0026b70:	83 c4 1c             	add    $0x1c,%esp
c0026b73:	c3                   	ret    

c0026b74 <__vprintf>:
{
c0026b74:	55                   	push   %ebp
c0026b75:	57                   	push   %edi
c0026b76:	56                   	push   %esi
c0026b77:	53                   	push   %ebx
c0026b78:	83 ec 5c             	sub    $0x5c,%esp
c0026b7b:	8b 7c 24 70          	mov    0x70(%esp),%edi
c0026b7f:	8b 6c 24 74          	mov    0x74(%esp),%ebp
  for (; *format != '\0'; format++)
c0026b83:	0f b6 07             	movzbl (%edi),%eax
c0026b86:	84 c0                	test   %al,%al
c0026b88:	0f 84 1c 06 00 00    	je     c00271aa <__vprintf+0x636>
      if (*format != '%') 
c0026b8e:	3c 25                	cmp    $0x25,%al
c0026b90:	74 19                	je     c0026bab <__vprintf+0x37>
          output (*format, aux);
c0026b92:	8b 5c 24 7c          	mov    0x7c(%esp),%ebx
c0026b96:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0026b9a:	0f be c0             	movsbl %al,%eax
c0026b9d:	89 04 24             	mov    %eax,(%esp)
c0026ba0:	ff 54 24 78          	call   *0x78(%esp)
          continue;
c0026ba4:	89 fb                	mov    %edi,%ebx
c0026ba6:	e9 d5 05 00 00       	jmp    c0027180 <__vprintf+0x60c>
      format++;
c0026bab:	8d 77 01             	lea    0x1(%edi),%esi
      if (*format == '%') 
c0026bae:	b9 00 00 00 00       	mov    $0x0,%ecx
c0026bb3:	80 7f 01 25          	cmpb   $0x25,0x1(%edi)
c0026bb7:	75 1c                	jne    c0026bd5 <__vprintf+0x61>
          output ('%', aux);
c0026bb9:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0026bbd:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026bc1:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
c0026bc8:	ff 54 24 78          	call   *0x78(%esp)
      format++;
c0026bcc:	89 f3                	mov    %esi,%ebx
          continue;
c0026bce:	e9 ad 05 00 00       	jmp    c0027180 <__vprintf+0x60c>
      switch (*format++) 
c0026bd3:	89 d6                	mov    %edx,%esi
c0026bd5:	8d 56 01             	lea    0x1(%esi),%edx
c0026bd8:	0f b6 5a ff          	movzbl -0x1(%edx),%ebx
c0026bdc:	8d 43 e0             	lea    -0x20(%ebx),%eax
c0026bdf:	3c 10                	cmp    $0x10,%al
c0026be1:	77 29                	ja     c0026c0c <__vprintf+0x98>
c0026be3:	0f b6 c0             	movzbl %al,%eax
c0026be6:	ff 24 85 30 da 02 c0 	jmp    *-0x3ffd25d0(,%eax,4)
          c->flags |= MINUS;
c0026bed:	83 c9 01             	or     $0x1,%ecx
c0026bf0:	eb e1                	jmp    c0026bd3 <__vprintf+0x5f>
          c->flags |= PLUS;
c0026bf2:	83 c9 02             	or     $0x2,%ecx
c0026bf5:	eb dc                	jmp    c0026bd3 <__vprintf+0x5f>
          c->flags |= SPACE;
c0026bf7:	83 c9 04             	or     $0x4,%ecx
c0026bfa:	eb d7                	jmp    c0026bd3 <__vprintf+0x5f>
          c->flags |= POUND;
c0026bfc:	83 c9 08             	or     $0x8,%ecx
c0026bff:	90                   	nop
c0026c00:	eb d1                	jmp    c0026bd3 <__vprintf+0x5f>
          c->flags |= ZERO;
c0026c02:	83 c9 10             	or     $0x10,%ecx
c0026c05:	eb cc                	jmp    c0026bd3 <__vprintf+0x5f>
          c->flags |= GROUP;
c0026c07:	83 c9 20             	or     $0x20,%ecx
c0026c0a:	eb c7                	jmp    c0026bd3 <__vprintf+0x5f>
      switch (*format++) 
c0026c0c:	89 f0                	mov    %esi,%eax
c0026c0e:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & MINUS)
c0026c12:	f6 c1 01             	test   $0x1,%cl
c0026c15:	74 07                	je     c0026c1e <__vprintf+0xaa>
    c->flags &= ~ZERO;
c0026c17:	83 e1 ef             	and    $0xffffffef,%ecx
c0026c1a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & PLUS)
c0026c1e:	8b 4c 24 40          	mov    0x40(%esp),%ecx
c0026c22:	f6 c1 02             	test   $0x2,%cl
c0026c25:	74 07                	je     c0026c2e <__vprintf+0xba>
    c->flags &= ~SPACE;
c0026c27:	83 e1 fb             	and    $0xfffffffb,%ecx
c0026c2a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  c->width = 0;
c0026c2e:	c7 44 24 44 00 00 00 	movl   $0x0,0x44(%esp)
c0026c35:	00 
  if (*format == '*')
c0026c36:	80 fb 2a             	cmp    $0x2a,%bl
c0026c39:	74 15                	je     c0026c50 <__vprintf+0xdc>
      for (; isdigit (*format); format++)
c0026c3b:	0f b6 00             	movzbl (%eax),%eax
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0026c3e:	0f be c8             	movsbl %al,%ecx
c0026c41:	83 e9 30             	sub    $0x30,%ecx
c0026c44:	ba 00 00 00 00       	mov    $0x0,%edx
c0026c49:	83 f9 09             	cmp    $0x9,%ecx
c0026c4c:	76 10                	jbe    c0026c5e <__vprintf+0xea>
c0026c4e:	eb 40                	jmp    c0026c90 <__vprintf+0x11c>
      c->width = va_arg (*args, int);
c0026c50:	8b 45 00             	mov    0x0(%ebp),%eax
c0026c53:	89 44 24 44          	mov    %eax,0x44(%esp)
c0026c57:	8d 6d 04             	lea    0x4(%ebp),%ebp
      switch (*format++) 
c0026c5a:	89 d6                	mov    %edx,%esi
c0026c5c:	eb 1f                	jmp    c0026c7d <__vprintf+0x109>
        c->width = c->width * 10 + *format - '0';
c0026c5e:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026c61:	0f be c0             	movsbl %al,%eax
c0026c64:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
      for (; isdigit (*format); format++)
c0026c68:	83 c6 01             	add    $0x1,%esi
c0026c6b:	0f b6 06             	movzbl (%esi),%eax
c0026c6e:	0f be c8             	movsbl %al,%ecx
c0026c71:	83 e9 30             	sub    $0x30,%ecx
c0026c74:	83 f9 09             	cmp    $0x9,%ecx
c0026c77:	76 e5                	jbe    c0026c5e <__vprintf+0xea>
c0026c79:	89 54 24 44          	mov    %edx,0x44(%esp)
  if (c->width < 0) 
c0026c7d:	8b 44 24 44          	mov    0x44(%esp),%eax
c0026c81:	85 c0                	test   %eax,%eax
c0026c83:	79 0b                	jns    c0026c90 <__vprintf+0x11c>
      c->width = -c->width;
c0026c85:	f7 d8                	neg    %eax
c0026c87:	89 44 24 44          	mov    %eax,0x44(%esp)
      c->flags |= MINUS;
c0026c8b:	83 4c 24 40 01       	orl    $0x1,0x40(%esp)
  c->precision = -1;
c0026c90:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026c97:	ff 
  if (*format == '.') 
c0026c98:	80 3e 2e             	cmpb   $0x2e,(%esi)
c0026c9b:	0f 85 f0 04 00 00    	jne    c0027191 <__vprintf+0x61d>
      if (*format == '*') 
c0026ca1:	80 7e 01 2a          	cmpb   $0x2a,0x1(%esi)
c0026ca5:	75 0f                	jne    c0026cb6 <__vprintf+0x142>
          format++;
c0026ca7:	83 c6 02             	add    $0x2,%esi
          c->precision = va_arg (*args, int);
c0026caa:	8b 45 00             	mov    0x0(%ebp),%eax
c0026cad:	89 44 24 48          	mov    %eax,0x48(%esp)
c0026cb1:	8d 6d 04             	lea    0x4(%ebp),%ebp
c0026cb4:	eb 44                	jmp    c0026cfa <__vprintf+0x186>
      format++;
c0026cb6:	8d 56 01             	lea    0x1(%esi),%edx
          c->precision = 0;
c0026cb9:	c7 44 24 48 00 00 00 	movl   $0x0,0x48(%esp)
c0026cc0:	00 
          for (; isdigit (*format); format++)
c0026cc1:	0f b6 46 01          	movzbl 0x1(%esi),%eax
c0026cc5:	0f be c8             	movsbl %al,%ecx
c0026cc8:	83 e9 30             	sub    $0x30,%ecx
c0026ccb:	83 f9 09             	cmp    $0x9,%ecx
c0026cce:	0f 87 c6 04 00 00    	ja     c002719a <__vprintf+0x626>
c0026cd4:	b9 00 00 00 00       	mov    $0x0,%ecx
            c->precision = c->precision * 10 + *format - '0';
c0026cd9:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0026cdc:	0f be c0             	movsbl %al,%eax
c0026cdf:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
          for (; isdigit (*format); format++)
c0026ce3:	83 c2 01             	add    $0x1,%edx
c0026ce6:	0f b6 02             	movzbl (%edx),%eax
c0026ce9:	0f be d8             	movsbl %al,%ebx
c0026cec:	83 eb 30             	sub    $0x30,%ebx
c0026cef:	83 fb 09             	cmp    $0x9,%ebx
c0026cf2:	76 e5                	jbe    c0026cd9 <__vprintf+0x165>
c0026cf4:	89 4c 24 48          	mov    %ecx,0x48(%esp)
c0026cf8:	89 d6                	mov    %edx,%esi
      if (c->precision < 0) 
c0026cfa:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0026cff:	0f 89 97 04 00 00    	jns    c002719c <__vprintf+0x628>
        c->precision = -1;
c0026d05:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026d0c:	ff 
c0026d0d:	e9 7f 04 00 00       	jmp    c0027191 <__vprintf+0x61d>
  c->type = INT;
c0026d12:	c7 44 24 4c 03 00 00 	movl   $0x3,0x4c(%esp)
c0026d19:	00 
  switch (*format++) 
c0026d1a:	8d 5e 01             	lea    0x1(%esi),%ebx
c0026d1d:	0f b6 3e             	movzbl (%esi),%edi
c0026d20:	8d 57 98             	lea    -0x68(%edi),%edx
c0026d23:	80 fa 12             	cmp    $0x12,%dl
c0026d26:	77 62                	ja     c0026d8a <__vprintf+0x216>
c0026d28:	0f b6 d2             	movzbl %dl,%edx
c0026d2b:	ff 24 95 74 da 02 c0 	jmp    *-0x3ffd258c(,%edx,4)
      if (*format == 'h') 
c0026d32:	80 7e 01 68          	cmpb   $0x68,0x1(%esi)
c0026d36:	75 0d                	jne    c0026d45 <__vprintf+0x1d1>
          format++;
c0026d38:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = CHAR;
c0026d3b:	c7 44 24 4c 01 00 00 	movl   $0x1,0x4c(%esp)
c0026d42:	00 
c0026d43:	eb 47                	jmp    c0026d8c <__vprintf+0x218>
        c->type = SHORT;
c0026d45:	c7 44 24 4c 02 00 00 	movl   $0x2,0x4c(%esp)
c0026d4c:	00 
c0026d4d:	eb 3d                	jmp    c0026d8c <__vprintf+0x218>
      c->type = INTMAX;
c0026d4f:	c7 44 24 4c 04 00 00 	movl   $0x4,0x4c(%esp)
c0026d56:	00 
c0026d57:	eb 33                	jmp    c0026d8c <__vprintf+0x218>
      if (*format == 'l')
c0026d59:	80 7e 01 6c          	cmpb   $0x6c,0x1(%esi)
c0026d5d:	75 0d                	jne    c0026d6c <__vprintf+0x1f8>
          format++;
c0026d5f:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = LONGLONG;
c0026d62:	c7 44 24 4c 06 00 00 	movl   $0x6,0x4c(%esp)
c0026d69:	00 
c0026d6a:	eb 20                	jmp    c0026d8c <__vprintf+0x218>
        c->type = LONG;
c0026d6c:	c7 44 24 4c 05 00 00 	movl   $0x5,0x4c(%esp)
c0026d73:	00 
c0026d74:	eb 16                	jmp    c0026d8c <__vprintf+0x218>
      c->type = PTRDIFFT;
c0026d76:	c7 44 24 4c 07 00 00 	movl   $0x7,0x4c(%esp)
c0026d7d:	00 
c0026d7e:	eb 0c                	jmp    c0026d8c <__vprintf+0x218>
      c->type = SIZET;
c0026d80:	c7 44 24 4c 08 00 00 	movl   $0x8,0x4c(%esp)
c0026d87:	00 
c0026d88:	eb 02                	jmp    c0026d8c <__vprintf+0x218>
  switch (*format++) 
c0026d8a:	89 f3                	mov    %esi,%ebx
      switch (*format) 
c0026d8c:	0f b6 0b             	movzbl (%ebx),%ecx
c0026d8f:	8d 51 bb             	lea    -0x45(%ecx),%edx
c0026d92:	80 fa 33             	cmp    $0x33,%dl
c0026d95:	0f 87 c2 03 00 00    	ja     c002715d <__vprintf+0x5e9>
c0026d9b:	0f b6 d2             	movzbl %dl,%edx
c0026d9e:	ff 24 95 c0 da 02 c0 	jmp    *-0x3ffd2540(,%edx,4)
            switch (c.type) 
c0026da5:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026daa:	0f 87 c9 00 00 00    	ja     c0026e79 <__vprintf+0x305>
c0026db0:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026db4:	ff 24 85 90 db 02 c0 	jmp    *-0x3ffd2470(,%eax,4)
                value = (signed char) va_arg (args, int);
c0026dbb:	0f be 75 00          	movsbl 0x0(%ebp),%esi
c0026dbf:	89 f0                	mov    %esi,%eax
c0026dc1:	99                   	cltd   
c0026dc2:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026dc6:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026dca:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dcd:	e9 cb 00 00 00       	jmp    c0026e9d <__vprintf+0x329>
                value = (short) va_arg (args, int);
c0026dd2:	0f bf 75 00          	movswl 0x0(%ebp),%esi
c0026dd6:	89 f0                	mov    %esi,%eax
c0026dd8:	99                   	cltd   
c0026dd9:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026ddd:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026de1:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026de4:	e9 b4 00 00 00       	jmp    c0026e9d <__vprintf+0x329>
                value = va_arg (args, int);
c0026de9:	8b 75 00             	mov    0x0(%ebp),%esi
c0026dec:	89 f0                	mov    %esi,%eax
c0026dee:	99                   	cltd   
c0026def:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026df3:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026df7:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dfa:	e9 9e 00 00 00       	jmp    c0026e9d <__vprintf+0x329>
                value = va_arg (args, intmax_t);
c0026dff:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e02:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e05:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e09:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e0d:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e10:	e9 88 00 00 00       	jmp    c0026e9d <__vprintf+0x329>
                value = va_arg (args, long);
c0026e15:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e18:	89 f0                	mov    %esi,%eax
c0026e1a:	99                   	cltd   
c0026e1b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e1f:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e23:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e26:	eb 75                	jmp    c0026e9d <__vprintf+0x329>
                value = va_arg (args, long long);
c0026e28:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e2b:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e2e:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e32:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e36:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e39:	eb 62                	jmp    c0026e9d <__vprintf+0x329>
                value = va_arg (args, ptrdiff_t);
c0026e3b:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e3e:	89 f0                	mov    %esi,%eax
c0026e40:	99                   	cltd   
c0026e41:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e45:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e49:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e4c:	eb 4f                	jmp    c0026e9d <__vprintf+0x329>
                value = va_arg (args, size_t);
c0026e4e:	8d 45 04             	lea    0x4(%ebp),%eax
                if (value > SIZE_MAX / 2)
c0026e51:	8b 7d 00             	mov    0x0(%ebp),%edi
c0026e54:	bd 00 00 00 00       	mov    $0x0,%ebp
c0026e59:	89 fe                	mov    %edi,%esi
c0026e5b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e5f:	89 6c 24 1c          	mov    %ebp,0x1c(%esp)
                value = va_arg (args, size_t);
c0026e63:	89 c5                	mov    %eax,%ebp
                if (value > SIZE_MAX / 2)
c0026e65:	81 fe ff ff ff 7f    	cmp    $0x7fffffff,%esi
c0026e6b:	76 30                	jbe    c0026e9d <__vprintf+0x329>
                  value = value - SIZE_MAX - 1;
c0026e6d:	83 44 24 18 00       	addl   $0x0,0x18(%esp)
c0026e72:	83 54 24 1c ff       	adcl   $0xffffffff,0x1c(%esp)
c0026e77:	eb 24                	jmp    c0026e9d <__vprintf+0x329>
                NOT_REACHED ();
c0026e79:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c0026e80:	c0 
c0026e81:	c7 44 24 08 d8 db 02 	movl   $0xc002dbd8,0x8(%esp)
c0026e88:	c0 
c0026e89:	c7 44 24 04 dc 00 00 	movl   $0xdc,0x4(%esp)
c0026e90:	00 
c0026e91:	c7 04 24 79 f8 02 c0 	movl   $0xc002f879,(%esp)
c0026e98:	e8 e6 1a 00 00       	call   c0028983 <debug_panic>
            format_integer (value < 0 ? -value : value,
c0026e9d:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0026ea1:	c1 fa 1f             	sar    $0x1f,%edx
c0026ea4:	89 d7                	mov    %edx,%edi
c0026ea6:	33 7c 24 18          	xor    0x18(%esp),%edi
c0026eaa:	89 7c 24 20          	mov    %edi,0x20(%esp)
c0026eae:	89 d7                	mov    %edx,%edi
c0026eb0:	33 7c 24 1c          	xor    0x1c(%esp),%edi
c0026eb4:	89 7c 24 24          	mov    %edi,0x24(%esp)
c0026eb8:	8b 74 24 20          	mov    0x20(%esp),%esi
c0026ebc:	8b 7c 24 24          	mov    0x24(%esp),%edi
c0026ec0:	29 d6                	sub    %edx,%esi
c0026ec2:	19 d7                	sbb    %edx,%edi
c0026ec4:	89 f0                	mov    %esi,%eax
c0026ec6:	89 fa                	mov    %edi,%edx
c0026ec8:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0026ecc:	89 7c 24 10          	mov    %edi,0x10(%esp)
c0026ed0:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0026ed4:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0026ed8:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0026edc:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0026ee0:	c7 44 24 04 14 dc 02 	movl   $0xc002dc14,0x4(%esp)
c0026ee7:	c0 
c0026ee8:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0026eec:	c1 e9 1f             	shr    $0x1f,%ecx
c0026eef:	89 0c 24             	mov    %ecx,(%esp)
c0026ef2:	b9 01 00 00 00       	mov    $0x1,%ecx
c0026ef7:	e8 82 f8 ff ff       	call   c002677e <format_integer>
          break;
c0026efc:	e9 7f 02 00 00       	jmp    c0027180 <__vprintf+0x60c>
            switch (c.type) 
c0026f01:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026f06:	0f 87 b7 00 00 00    	ja     c0026fc3 <__vprintf+0x44f>
c0026f0c:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026f10:	ff 24 85 b4 db 02 c0 	jmp    *-0x3ffd244c(,%eax,4)
                value = (unsigned char) va_arg (args, unsigned);
c0026f17:	0f b6 45 00          	movzbl 0x0(%ebp),%eax
c0026f1b:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f1f:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f26:	00 
c0026f27:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f2a:	e9 b8 00 00 00       	jmp    c0026fe7 <__vprintf+0x473>
                value = (unsigned short) va_arg (args, unsigned);
c0026f2f:	0f b7 45 00          	movzwl 0x0(%ebp),%eax
c0026f33:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f37:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f3e:	00 
c0026f3f:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f42:	e9 a0 00 00 00       	jmp    c0026fe7 <__vprintf+0x473>
                value = va_arg (args, unsigned);
c0026f47:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f4a:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f4f:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f53:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f57:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f5a:	e9 88 00 00 00       	jmp    c0026fe7 <__vprintf+0x473>
                value = va_arg (args, uintmax_t);
c0026f5f:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f62:	8b 55 04             	mov    0x4(%ebp),%edx
c0026f65:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f69:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f6d:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026f70:	eb 75                	jmp    c0026fe7 <__vprintf+0x473>
                value = va_arg (args, unsigned long);
c0026f72:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f75:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f7a:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f7e:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f82:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f85:	eb 60                	jmp    c0026fe7 <__vprintf+0x473>
                value = va_arg (args, unsigned long long);
c0026f87:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f8a:	8b 55 04             	mov    0x4(%ebp),%edx
c0026f8d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f91:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f95:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026f98:	eb 4d                	jmp    c0026fe7 <__vprintf+0x473>
                value &= ((uintmax_t) PTRDIFF_MAX << 1) | 1;
c0026f9a:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f9d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fa1:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026fa8:	00 
                value = va_arg (args, ptrdiff_t);
c0026fa9:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fac:	eb 39                	jmp    c0026fe7 <__vprintf+0x473>
                value = va_arg (args, size_t);
c0026fae:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fb1:	ba 00 00 00 00       	mov    $0x0,%edx
c0026fb6:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fba:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fbe:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fc1:	eb 24                	jmp    c0026fe7 <__vprintf+0x473>
                NOT_REACHED ();
c0026fc3:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c0026fca:	c0 
c0026fcb:	c7 44 24 08 d8 db 02 	movl   $0xc002dbd8,0x8(%esp)
c0026fd2:	c0 
c0026fd3:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0026fda:	00 
c0026fdb:	c7 04 24 79 f8 02 c0 	movl   $0xc002f879,(%esp)
c0026fe2:	e8 9c 19 00 00       	call   c0028983 <debug_panic>
            switch (*format) 
c0026fe7:	80 f9 6f             	cmp    $0x6f,%cl
c0026fea:	74 4d                	je     c0027039 <__vprintf+0x4c5>
c0026fec:	80 f9 6f             	cmp    $0x6f,%cl
c0026fef:	7f 07                	jg     c0026ff8 <__vprintf+0x484>
c0026ff1:	80 f9 58             	cmp    $0x58,%cl
c0026ff4:	74 18                	je     c002700e <__vprintf+0x49a>
c0026ff6:	eb 1d                	jmp    c0027015 <__vprintf+0x4a1>
c0026ff8:	80 f9 75             	cmp    $0x75,%cl
c0026ffb:	90                   	nop
c0026ffc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027000:	74 3e                	je     c0027040 <__vprintf+0x4cc>
c0027002:	80 f9 78             	cmp    $0x78,%cl
c0027005:	75 0e                	jne    c0027015 <__vprintf+0x4a1>
              case 'x': b = &base_x; break;
c0027007:	b8 f4 db 02 c0       	mov    $0xc002dbf4,%eax
c002700c:	eb 37                	jmp    c0027045 <__vprintf+0x4d1>
              case 'X': b = &base_X; break;
c002700e:	b8 e4 db 02 c0       	mov    $0xc002dbe4,%eax
c0027013:	eb 30                	jmp    c0027045 <__vprintf+0x4d1>
              default: NOT_REACHED ();
c0027015:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c002701c:	c0 
c002701d:	c7 44 24 08 d8 db 02 	movl   $0xc002dbd8,0x8(%esp)
c0027024:	c0 
c0027025:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
c002702c:	00 
c002702d:	c7 04 24 79 f8 02 c0 	movl   $0xc002f879,(%esp)
c0027034:	e8 4a 19 00 00       	call   c0028983 <debug_panic>
              case 'o': b = &base_o; break;
c0027039:	b8 04 dc 02 c0       	mov    $0xc002dc04,%eax
c002703e:	eb 05                	jmp    c0027045 <__vprintf+0x4d1>
              case 'u': b = &base_d; break;
c0027040:	b8 14 dc 02 c0       	mov    $0xc002dc14,%eax
            format_integer (value, false, false, b, &c, output, aux);
c0027045:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027049:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002704d:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0027051:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027055:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027059:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002705d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027061:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0027068:	b9 00 00 00 00       	mov    $0x0,%ecx
c002706d:	8b 44 24 28          	mov    0x28(%esp),%eax
c0027071:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c0027075:	e8 04 f7 ff ff       	call   c002677e <format_integer>
          break;
c002707a:	e9 01 01 00 00       	jmp    c0027180 <__vprintf+0x60c>
            char ch = va_arg (args, int);
c002707f:	8d 75 04             	lea    0x4(%ebp),%esi
c0027082:	8b 45 00             	mov    0x0(%ebp),%eax
c0027085:	88 44 24 3f          	mov    %al,0x3f(%esp)
            format_string (&ch, 1, &c, output, aux);
c0027089:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c002708d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027091:	8b 44 24 78          	mov    0x78(%esp),%eax
c0027095:	89 04 24             	mov    %eax,(%esp)
c0027098:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c002709c:	ba 01 00 00 00       	mov    $0x1,%edx
c00270a1:	8d 44 24 3f          	lea    0x3f(%esp),%eax
c00270a5:	e8 00 fa ff ff       	call   c0026aaa <format_string>
            char ch = va_arg (args, int);
c00270aa:	89 f5                	mov    %esi,%ebp
          break;
c00270ac:	e9 cf 00 00 00       	jmp    c0027180 <__vprintf+0x60c>
            const char *s = va_arg (args, char *);
c00270b1:	8d 75 04             	lea    0x4(%ebp),%esi
c00270b4:	8b 7d 00             	mov    0x0(%ebp),%edi
              s = "(null)";
c00270b7:	85 ff                	test   %edi,%edi
c00270b9:	ba 72 f8 02 c0       	mov    $0xc002f872,%edx
c00270be:	0f 44 fa             	cmove  %edx,%edi
            format_string (s, strnlen (s, c.precision), &c, output, aux);
c00270c1:	89 44 24 04          	mov    %eax,0x4(%esp)
c00270c5:	89 3c 24             	mov    %edi,(%esp)
c00270c8:	e8 9d 0e 00 00       	call   c0027f6a <strnlen>
c00270cd:	8b 4c 24 7c          	mov    0x7c(%esp),%ecx
c00270d1:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00270d5:	8b 4c 24 78          	mov    0x78(%esp),%ecx
c00270d9:	89 0c 24             	mov    %ecx,(%esp)
c00270dc:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c00270e0:	89 c2                	mov    %eax,%edx
c00270e2:	89 f8                	mov    %edi,%eax
c00270e4:	e8 c1 f9 ff ff       	call   c0026aaa <format_string>
            const char *s = va_arg (args, char *);
c00270e9:	89 f5                	mov    %esi,%ebp
          break;
c00270eb:	e9 90 00 00 00       	jmp    c0027180 <__vprintf+0x60c>
            void *p = va_arg (args, void *);
c00270f0:	8d 75 04             	lea    0x4(%ebp),%esi
c00270f3:	8b 45 00             	mov    0x0(%ebp),%eax
            c.flags = POUND;
c00270f6:	c7 44 24 40 08 00 00 	movl   $0x8,0x40(%esp)
c00270fd:	00 
            format_integer ((uintptr_t) p, false, false,
c00270fe:	ba 00 00 00 00       	mov    $0x0,%edx
c0027103:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027107:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002710b:	8b 7c 24 78          	mov    0x78(%esp),%edi
c002710f:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027113:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027117:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002711b:	c7 44 24 04 f4 db 02 	movl   $0xc002dbf4,0x4(%esp)
c0027122:	c0 
c0027123:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002712a:	b9 00 00 00 00       	mov    $0x0,%ecx
c002712f:	e8 4a f6 ff ff       	call   c002677e <format_integer>
            void *p = va_arg (args, void *);
c0027134:	89 f5                	mov    %esi,%ebp
          break;
c0027136:	eb 48                	jmp    c0027180 <__vprintf+0x60c>
          __printf ("<<no %%%c in kernel>>", output, aux, *format);
c0027138:	0f be c9             	movsbl %cl,%ecx
c002713b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002713f:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027143:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027147:	8b 44 24 78          	mov    0x78(%esp),%eax
c002714b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002714f:	c7 04 24 8b f8 02 c0 	movl   $0xc002f88b,(%esp)
c0027156:	e8 ee f9 ff ff       	call   c0026b49 <__printf>
          break;
c002715b:	eb 23                	jmp    c0027180 <__vprintf+0x60c>
          __printf ("<<no %%%c conversion>>", output, aux, *format);
c002715d:	0f be c9             	movsbl %cl,%ecx
c0027160:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0027164:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027168:	89 44 24 08          	mov    %eax,0x8(%esp)
c002716c:	8b 44 24 78          	mov    0x78(%esp),%eax
c0027170:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027174:	c7 04 24 a1 f8 02 c0 	movl   $0xc002f8a1,(%esp)
c002717b:	e8 c9 f9 ff ff       	call   c0026b49 <__printf>
  for (; *format != '\0'; format++)
c0027180:	8d 7b 01             	lea    0x1(%ebx),%edi
c0027183:	0f b6 43 01          	movzbl 0x1(%ebx),%eax
c0027187:	84 c0                	test   %al,%al
c0027189:	0f 85 ff f9 ff ff    	jne    c0026b8e <__vprintf+0x1a>
c002718f:	eb 19                	jmp    c00271aa <__vprintf+0x636>
  if (c->precision >= 0)
c0027191:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027195:	e9 78 fb ff ff       	jmp    c0026d12 <__vprintf+0x19e>
      format++;
c002719a:	89 d6                	mov    %edx,%esi
  if (c->precision >= 0)
c002719c:	8b 44 24 48          	mov    0x48(%esp),%eax
    c->flags &= ~ZERO;
c00271a0:	83 64 24 40 ef       	andl   $0xffffffef,0x40(%esp)
c00271a5:	e9 68 fb ff ff       	jmp    c0026d12 <__vprintf+0x19e>
}
c00271aa:	83 c4 5c             	add    $0x5c,%esp
c00271ad:	5b                   	pop    %ebx
c00271ae:	5e                   	pop    %esi
c00271af:	5f                   	pop    %edi
c00271b0:	5d                   	pop    %ebp
c00271b1:	c3                   	ret    

c00271b2 <vsnprintf>:
{
c00271b2:	53                   	push   %ebx
c00271b3:	83 ec 28             	sub    $0x28,%esp
c00271b6:	8b 44 24 34          	mov    0x34(%esp),%eax
c00271ba:	8b 54 24 38          	mov    0x38(%esp),%edx
c00271be:	8b 4c 24 3c          	mov    0x3c(%esp),%ecx
  aux.p = buffer;
c00271c2:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00271c6:	89 5c 24 14          	mov    %ebx,0x14(%esp)
  aux.length = 0;
c00271ca:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c00271d1:	00 
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c00271d2:	85 c0                	test   %eax,%eax
c00271d4:	74 2c                	je     c0027202 <vsnprintf+0x50>
c00271d6:	83 e8 01             	sub    $0x1,%eax
c00271d9:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  __vprintf (format, args, vsnprintf_helper, &aux);
c00271dd:	8d 44 24 14          	lea    0x14(%esp),%eax
c00271e1:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00271e5:	c7 44 24 08 30 67 02 	movl   $0xc0026730,0x8(%esp)
c00271ec:	c0 
c00271ed:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00271f1:	89 14 24             	mov    %edx,(%esp)
c00271f4:	e8 7b f9 ff ff       	call   c0026b74 <__vprintf>
    *aux.p = '\0';
c00271f9:	8b 44 24 14          	mov    0x14(%esp),%eax
c00271fd:	c6 00 00             	movb   $0x0,(%eax)
c0027200:	eb 24                	jmp    c0027226 <vsnprintf+0x74>
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c0027202:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c0027209:	00 
  __vprintf (format, args, vsnprintf_helper, &aux);
c002720a:	8d 44 24 14          	lea    0x14(%esp),%eax
c002720e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027212:	c7 44 24 08 30 67 02 	movl   $0xc0026730,0x8(%esp)
c0027219:	c0 
c002721a:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002721e:	89 14 24             	mov    %edx,(%esp)
c0027221:	e8 4e f9 ff ff       	call   c0026b74 <__vprintf>
  return aux.length;
c0027226:	8b 44 24 18          	mov    0x18(%esp),%eax
}
c002722a:	83 c4 28             	add    $0x28,%esp
c002722d:	5b                   	pop    %ebx
c002722e:	c3                   	ret    

c002722f <snprintf>:
{
c002722f:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0027232:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  retval = vsnprintf (buffer, buf_size, format, args);
c0027236:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002723a:	8b 44 24 28          	mov    0x28(%esp),%eax
c002723e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027242:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027246:	89 44 24 04          	mov    %eax,0x4(%esp)
c002724a:	8b 44 24 20          	mov    0x20(%esp),%eax
c002724e:	89 04 24             	mov    %eax,(%esp)
c0027251:	e8 5c ff ff ff       	call   c00271b2 <vsnprintf>
}
c0027256:	83 c4 1c             	add    $0x1c,%esp
c0027259:	c3                   	ret    

c002725a <hex_dump>:
   starting at OFS for the first byte in BUF.  If ASCII is true
   then the corresponding ASCII characters are also rendered
   alongside. */   
void
hex_dump (uintptr_t ofs, const void *buf_, size_t size, bool ascii)
{
c002725a:	55                   	push   %ebp
c002725b:	57                   	push   %edi
c002725c:	56                   	push   %esi
c002725d:	53                   	push   %ebx
c002725e:	83 ec 2c             	sub    $0x2c,%esp
c0027261:	0f b6 44 24 4c       	movzbl 0x4c(%esp),%eax
c0027266:	88 44 24 1f          	mov    %al,0x1f(%esp)
  const uint8_t *buf = buf_;
  const size_t per_line = 16; /* Maximum bytes per line. */

  while (size > 0)
c002726a:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c002726f:	0f 84 7c 01 00 00    	je     c00273f1 <hex_dump+0x197>
    {
      size_t start, end, n;
      size_t i;
      
      /* Number of bytes on this line. */
      start = ofs % per_line;
c0027275:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0027279:	83 e7 0f             	and    $0xf,%edi
      end = per_line;
      if (end - start > size)
c002727c:	b8 10 00 00 00       	mov    $0x10,%eax
c0027281:	29 f8                	sub    %edi,%eax
        end = start + size;
c0027283:	89 fe                	mov    %edi,%esi
c0027285:	03 74 24 48          	add    0x48(%esp),%esi
c0027289:	3b 44 24 48          	cmp    0x48(%esp),%eax
c002728d:	b8 10 00 00 00       	mov    $0x10,%eax
c0027292:	0f 46 f0             	cmovbe %eax,%esi
      n = end - start;
c0027295:	89 f0                	mov    %esi,%eax
c0027297:	29 f8                	sub    %edi,%eax
c0027299:	89 44 24 18          	mov    %eax,0x18(%esp)

      /* Print line. */
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
c002729d:	8b 44 24 40          	mov    0x40(%esp),%eax
c00272a1:	83 e0 f0             	and    $0xfffffff0,%eax
c00272a4:	89 44 24 04          	mov    %eax,0x4(%esp)
c00272a8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00272af:	00 
c00272b0:	c7 04 24 b8 f8 02 c0 	movl   $0xc002f8b8,(%esp)
c00272b7:	e8 72 f8 ff ff       	call   c0026b2e <printf>
      for (i = 0; i < start; i++)
c00272bc:	85 ff                	test   %edi,%edi
c00272be:	74 1a                	je     c00272da <hex_dump+0x80>
c00272c0:	bb 00 00 00 00       	mov    $0x0,%ebx
        printf ("   ");
c00272c5:	c7 04 24 c0 f8 02 c0 	movl   $0xc002f8c0,(%esp)
c00272cc:	e8 5d f8 ff ff       	call   c0026b2e <printf>
      for (i = 0; i < start; i++)
c00272d1:	83 c3 01             	add    $0x1,%ebx
c00272d4:	39 fb                	cmp    %edi,%ebx
c00272d6:	75 ed                	jne    c00272c5 <hex_dump+0x6b>
c00272d8:	eb 08                	jmp    c00272e2 <hex_dump+0x88>
c00272da:	89 fb                	mov    %edi,%ebx
c00272dc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c00272e0:	eb 02                	jmp    c00272e4 <hex_dump+0x8a>
c00272e2:	89 fb                	mov    %edi,%ebx
      for (; i < end; i++) 
c00272e4:	39 de                	cmp    %ebx,%esi
c00272e6:	76 38                	jbe    c0027320 <hex_dump+0xc6>
c00272e8:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00272ec:	29 fd                	sub    %edi,%ebp
        printf ("%02hhx%c",
c00272ee:	83 fb 07             	cmp    $0x7,%ebx
c00272f1:	b8 2d 00 00 00       	mov    $0x2d,%eax
c00272f6:	b9 20 00 00 00       	mov    $0x20,%ecx
c00272fb:	0f 45 c1             	cmovne %ecx,%eax
c00272fe:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027302:	0f b6 44 1d 00       	movzbl 0x0(%ebp,%ebx,1),%eax
c0027307:	89 44 24 04          	mov    %eax,0x4(%esp)
c002730b:	c7 04 24 c4 f8 02 c0 	movl   $0xc002f8c4,(%esp)
c0027312:	e8 17 f8 ff ff       	call   c0026b2e <printf>
      for (; i < end; i++) 
c0027317:	83 c3 01             	add    $0x1,%ebx
c002731a:	39 de                	cmp    %ebx,%esi
c002731c:	77 d0                	ja     c00272ee <hex_dump+0x94>
c002731e:	89 f3                	mov    %esi,%ebx
                buf[i - start], i == per_line / 2 - 1? '-' : ' ');
      if (ascii) 
c0027320:	80 7c 24 1f 00       	cmpb   $0x0,0x1f(%esp)
c0027325:	0f 84 a4 00 00 00    	je     c00273cf <hex_dump+0x175>
        {
          for (; i < per_line; i++)
c002732b:	83 fb 0f             	cmp    $0xf,%ebx
c002732e:	77 14                	ja     c0027344 <hex_dump+0xea>
            printf ("   ");
c0027330:	c7 04 24 c0 f8 02 c0 	movl   $0xc002f8c0,(%esp)
c0027337:	e8 f2 f7 ff ff       	call   c0026b2e <printf>
          for (; i < per_line; i++)
c002733c:	83 c3 01             	add    $0x1,%ebx
c002733f:	83 fb 10             	cmp    $0x10,%ebx
c0027342:	75 ec                	jne    c0027330 <hex_dump+0xd6>
          printf ("|");
c0027344:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c002734b:	e8 cc 33 00 00       	call   c002a71c <putchar>
          for (i = 0; i < start; i++)
c0027350:	85 ff                	test   %edi,%edi
c0027352:	74 1a                	je     c002736e <hex_dump+0x114>
c0027354:	bb 00 00 00 00       	mov    $0x0,%ebx
            printf (" ");
c0027359:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0027360:	e8 b7 33 00 00       	call   c002a71c <putchar>
          for (i = 0; i < start; i++)
c0027365:	83 c3 01             	add    $0x1,%ebx
c0027368:	39 fb                	cmp    %edi,%ebx
c002736a:	75 ed                	jne    c0027359 <hex_dump+0xff>
c002736c:	eb 04                	jmp    c0027372 <hex_dump+0x118>
c002736e:	89 fb                	mov    %edi,%ebx
c0027370:	eb 02                	jmp    c0027374 <hex_dump+0x11a>
c0027372:	89 fb                	mov    %edi,%ebx
          for (; i < end; i++)
c0027374:	39 de                	cmp    %ebx,%esi
c0027376:	76 30                	jbe    c00273a8 <hex_dump+0x14e>
c0027378:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c002737c:	29 fd                	sub    %edi,%ebp
            printf ("%c",
c002737e:	bf 2e 00 00 00       	mov    $0x2e,%edi
                    isprint (buf[i - start]) ? buf[i - start] : '.');
c0027383:	0f b6 54 1d 00       	movzbl 0x0(%ebp,%ebx,1),%edx
static inline int isprint (int c) { return c >= 32 && c < 127; }
c0027388:	0f b6 c2             	movzbl %dl,%eax
            printf ("%c",
c002738b:	8d 40 e0             	lea    -0x20(%eax),%eax
c002738e:	0f b6 d2             	movzbl %dl,%edx
c0027391:	83 f8 5e             	cmp    $0x5e,%eax
c0027394:	0f 47 d7             	cmova  %edi,%edx
c0027397:	89 14 24             	mov    %edx,(%esp)
c002739a:	e8 7d 33 00 00       	call   c002a71c <putchar>
          for (; i < end; i++)
c002739f:	83 c3 01             	add    $0x1,%ebx
c00273a2:	39 de                	cmp    %ebx,%esi
c00273a4:	77 dd                	ja     c0027383 <hex_dump+0x129>
c00273a6:	eb 02                	jmp    c00273aa <hex_dump+0x150>
c00273a8:	89 de                	mov    %ebx,%esi
          for (; i < per_line; i++)
c00273aa:	83 fe 0f             	cmp    $0xf,%esi
c00273ad:	77 14                	ja     c00273c3 <hex_dump+0x169>
            printf (" ");
c00273af:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c00273b6:	e8 61 33 00 00       	call   c002a71c <putchar>
          for (; i < per_line; i++)
c00273bb:	83 c6 01             	add    $0x1,%esi
c00273be:	83 fe 10             	cmp    $0x10,%esi
c00273c1:	75 ec                	jne    c00273af <hex_dump+0x155>
          printf ("|");
c00273c3:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c00273ca:	e8 4d 33 00 00       	call   c002a71c <putchar>
        }
      printf ("\n");
c00273cf:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00273d6:	e8 41 33 00 00       	call   c002a71c <putchar>

      ofs += n;
c00273db:	8b 44 24 18          	mov    0x18(%esp),%eax
c00273df:	01 44 24 40          	add    %eax,0x40(%esp)
      buf += n;
c00273e3:	01 44 24 44          	add    %eax,0x44(%esp)
  while (size > 0)
c00273e7:	29 44 24 48          	sub    %eax,0x48(%esp)
c00273eb:	0f 85 84 fe ff ff    	jne    c0027275 <hex_dump+0x1b>
      size -= n;
    }
}
c00273f1:	83 c4 2c             	add    $0x2c,%esp
c00273f4:	5b                   	pop    %ebx
c00273f5:	5e                   	pop    %esi
c00273f6:	5f                   	pop    %edi
c00273f7:	5d                   	pop    %ebp
c00273f8:	c3                   	ret    

c00273f9 <print_human_readable_size>:

/* Prints SIZE, which represents a number of bytes, in a
   human-readable format, e.g. "256 kB". */
void
print_human_readable_size (uint64_t size) 
{
c00273f9:	56                   	push   %esi
c00273fa:	53                   	push   %ebx
c00273fb:	83 ec 14             	sub    $0x14,%esp
c00273fe:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c0027402:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (size == 1)
c0027406:	89 c8                	mov    %ecx,%eax
c0027408:	83 f0 01             	xor    $0x1,%eax
c002740b:	09 d8                	or     %ebx,%eax
c002740d:	74 22                	je     c0027431 <print_human_readable_size+0x38>
  else 
    {
      static const char *factors[] = {"bytes", "kB", "MB", "GB", "TB", NULL};
      const char **fp;

      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002740f:	83 fb 00             	cmp    $0x0,%ebx
c0027412:	77 0d                	ja     c0027421 <print_human_readable_size+0x28>
c0027414:	be 78 5a 03 c0       	mov    $0xc0035a78,%esi
c0027419:	81 f9 ff 03 00 00    	cmp    $0x3ff,%ecx
c002741f:	76 42                	jbe    c0027463 <print_human_readable_size+0x6a>
c0027421:	be 78 5a 03 c0       	mov    $0xc0035a78,%esi
c0027426:	83 3d 7c 5a 03 c0 00 	cmpl   $0x0,0xc0035a7c
c002742d:	75 10                	jne    c002743f <print_human_readable_size+0x46>
c002742f:	eb 32                	jmp    c0027463 <print_human_readable_size+0x6a>
    printf ("1 byte");
c0027431:	c7 04 24 cd f8 02 c0 	movl   $0xc002f8cd,(%esp)
c0027438:	e8 f1 f6 ff ff       	call   c0026b2e <printf>
c002743d:	eb 3e                	jmp    c002747d <print_human_readable_size+0x84>
        size /= 1024;
c002743f:	89 c8                	mov    %ecx,%eax
c0027441:	89 da                	mov    %ebx,%edx
c0027443:	0f ac d8 0a          	shrd   $0xa,%ebx,%eax
c0027447:	c1 ea 0a             	shr    $0xa,%edx
c002744a:	89 c1                	mov    %eax,%ecx
c002744c:	89 d3                	mov    %edx,%ebx
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002744e:	83 c6 04             	add    $0x4,%esi
c0027451:	83 fa 00             	cmp    $0x0,%edx
c0027454:	77 07                	ja     c002745d <print_human_readable_size+0x64>
c0027456:	3d ff 03 00 00       	cmp    $0x3ff,%eax
c002745b:	76 06                	jbe    c0027463 <print_human_readable_size+0x6a>
c002745d:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0027461:	75 dc                	jne    c002743f <print_human_readable_size+0x46>
      printf ("%"PRIu64" %s", size, *fp);
c0027463:	8b 06                	mov    (%esi),%eax
c0027465:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027469:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002746d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0027471:	c7 04 24 d4 f8 02 c0 	movl   $0xc002f8d4,(%esp)
c0027478:	e8 b1 f6 ff ff       	call   c0026b2e <printf>
    }
}
c002747d:	83 c4 14             	add    $0x14,%esp
c0027480:	5b                   	pop    %ebx
c0027481:	5e                   	pop    %esi
c0027482:	c3                   	ret    
c0027483:	90                   	nop
c0027484:	90                   	nop
c0027485:	90                   	nop
c0027486:	90                   	nop
c0027487:	90                   	nop
c0027488:	90                   	nop
c0027489:	90                   	nop
c002748a:	90                   	nop
c002748b:	90                   	nop
c002748c:	90                   	nop
c002748d:	90                   	nop
c002748e:	90                   	nop
c002748f:	90                   	nop

c0027490 <compare_thunk>:
}

/* Compares A and B by calling the AUX function. */
static int
compare_thunk (const void *a, const void *b, void *aux) 
{
c0027490:	83 ec 1c             	sub    $0x1c,%esp
  int (**compare) (const void *, const void *) = aux;
  return (*compare) (a, b);
c0027493:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027497:	89 44 24 04          	mov    %eax,0x4(%esp)
c002749b:	8b 44 24 20          	mov    0x20(%esp),%eax
c002749f:	89 04 24             	mov    %eax,(%esp)
c00274a2:	8b 44 24 28          	mov    0x28(%esp),%eax
c00274a6:	ff 10                	call   *(%eax)
}
c00274a8:	83 c4 1c             	add    $0x1c,%esp
c00274ab:	c3                   	ret    

c00274ac <do_swap>:

/* Swaps elements with 1-based indexes A_IDX and B_IDX in ARRAY
   with elements of SIZE bytes each. */
static void
do_swap (unsigned char *array, size_t a_idx, size_t b_idx, size_t size)
{
c00274ac:	57                   	push   %edi
c00274ad:	56                   	push   %esi
c00274ae:	53                   	push   %ebx
c00274af:	8b 7c 24 10          	mov    0x10(%esp),%edi
  unsigned char *a = array + (a_idx - 1) * size;
c00274b3:	8d 5a ff             	lea    -0x1(%edx),%ebx
c00274b6:	0f af df             	imul   %edi,%ebx
c00274b9:	01 c3                	add    %eax,%ebx
  unsigned char *b = array + (b_idx - 1) * size;
c00274bb:	8d 51 ff             	lea    -0x1(%ecx),%edx
c00274be:	0f af d7             	imul   %edi,%edx
c00274c1:	01 d0                	add    %edx,%eax
  size_t i;

  for (i = 0; i < size; i++)
c00274c3:	85 ff                	test   %edi,%edi
c00274c5:	74 1c                	je     c00274e3 <do_swap+0x37>
c00274c7:	ba 00 00 00 00       	mov    $0x0,%edx
    {
      unsigned char t = a[i];
c00274cc:	0f b6 34 13          	movzbl (%ebx,%edx,1),%esi
      a[i] = b[i];
c00274d0:	0f b6 0c 10          	movzbl (%eax,%edx,1),%ecx
c00274d4:	88 0c 13             	mov    %cl,(%ebx,%edx,1)
      b[i] = t;
c00274d7:	89 f1                	mov    %esi,%ecx
c00274d9:	88 0c 10             	mov    %cl,(%eax,%edx,1)
  for (i = 0; i < size; i++)
c00274dc:	83 c2 01             	add    $0x1,%edx
c00274df:	39 fa                	cmp    %edi,%edx
c00274e1:	75 e9                	jne    c00274cc <do_swap+0x20>
    }
}
c00274e3:	5b                   	pop    %ebx
c00274e4:	5e                   	pop    %esi
c00274e5:	5f                   	pop    %edi
c00274e6:	c3                   	ret    

c00274e7 <heapify>:
   elements, passing AUX as auxiliary data. */
static void
heapify (unsigned char *array, size_t i, size_t cnt, size_t size,
         int (*compare) (const void *, const void *, void *aux),
         void *aux) 
{
c00274e7:	55                   	push   %ebp
c00274e8:	57                   	push   %edi
c00274e9:	56                   	push   %esi
c00274ea:	53                   	push   %ebx
c00274eb:	83 ec 2c             	sub    $0x2c,%esp
c00274ee:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c00274f2:	89 d3                	mov    %edx,%ebx
c00274f4:	89 4c 24 18          	mov    %ecx,0x18(%esp)
  for (;;) 
    {
      /* Set `max' to the index of the largest element among I
         and its children (if any). */
      size_t left = 2 * i;
c00274f8:	8d 3c 1b             	lea    (%ebx,%ebx,1),%edi
      size_t right = 2 * i + 1;
c00274fb:	8d 6f 01             	lea    0x1(%edi),%ebp
      size_t max = i;
c00274fe:	89 de                	mov    %ebx,%esi
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027500:	3b 7c 24 18          	cmp    0x18(%esp),%edi
c0027504:	77 30                	ja     c0027536 <heapify+0x4f>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c0027506:	8b 44 24 48          	mov    0x48(%esp),%eax
c002750a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002750e:	8d 43 ff             	lea    -0x1(%ebx),%eax
c0027511:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027516:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002751a:	01 d0                	add    %edx,%eax
c002751c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027520:	8d 47 ff             	lea    -0x1(%edi),%eax
c0027523:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027528:	01 d0                	add    %edx,%eax
c002752a:	89 04 24             	mov    %eax,(%esp)
c002752d:	ff 54 24 44          	call   *0x44(%esp)
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027531:	85 c0                	test   %eax,%eax
      size_t max = i;
c0027533:	0f 4f f7             	cmovg  %edi,%esi
        max = left;
      if (right <= cnt
c0027536:	3b 6c 24 18          	cmp    0x18(%esp),%ebp
c002753a:	77 2d                	ja     c0027569 <heapify+0x82>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c002753c:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027540:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027544:	8d 46 ff             	lea    -0x1(%esi),%eax
c0027547:	0f af 44 24 40       	imul   0x40(%esp),%eax
c002754c:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0027550:	01 c8                	add    %ecx,%eax
c0027552:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027556:	0f af 7c 24 40       	imul   0x40(%esp),%edi
c002755b:	01 cf                	add    %ecx,%edi
c002755d:	89 3c 24             	mov    %edi,(%esp)
c0027560:	ff 54 24 44          	call   *0x44(%esp)
          && do_compare (array, right, max, size, compare, aux) > 0) 
c0027564:	85 c0                	test   %eax,%eax
        max = right;
c0027566:	0f 4f f5             	cmovg  %ebp,%esi

      /* If the maximum value is already in element I, we're
         done. */
      if (max == i)
c0027569:	39 de                	cmp    %ebx,%esi
c002756b:	74 1b                	je     c0027588 <heapify+0xa1>
        break;

      /* Swap and continue down the heap. */
      do_swap (array, i, max, size);
c002756d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0027571:	89 04 24             	mov    %eax,(%esp)
c0027574:	89 f1                	mov    %esi,%ecx
c0027576:	89 da                	mov    %ebx,%edx
c0027578:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002757c:	e8 2b ff ff ff       	call   c00274ac <do_swap>
      i = max;
c0027581:	89 f3                	mov    %esi,%ebx
    }
c0027583:	e9 70 ff ff ff       	jmp    c00274f8 <heapify+0x11>
}
c0027588:	83 c4 2c             	add    $0x2c,%esp
c002758b:	5b                   	pop    %ebx
c002758c:	5e                   	pop    %esi
c002758d:	5f                   	pop    %edi
c002758e:	5d                   	pop    %ebp
c002758f:	c3                   	ret    

c0027590 <atoi>:
{
c0027590:	57                   	push   %edi
c0027591:	56                   	push   %esi
c0027592:	53                   	push   %ebx
c0027593:	83 ec 20             	sub    $0x20,%esp
c0027596:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002759a:	85 d2                	test   %edx,%edx
c002759c:	75 2f                	jne    c00275cd <atoi+0x3d>
c002759e:	c7 44 24 10 1a fa 02 	movl   $0xc002fa1a,0x10(%esp)
c00275a5:	c0 
c00275a6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00275ad:	c0 
c00275ae:	c7 44 24 08 29 dc 02 	movl   $0xc002dc29,0x8(%esp)
c00275b5:	c0 
c00275b6:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
c00275bd:	00 
c00275be:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c00275c5:	e8 b9 13 00 00       	call   c0028983 <debug_panic>
    s++;
c00275ca:	83 c2 01             	add    $0x1,%edx
  while (isspace ((unsigned char) *s))
c00275cd:	0f b6 02             	movzbl (%edx),%eax
c00275d0:	0f b6 c8             	movzbl %al,%ecx
          || c == '\r' || c == '\t' || c == '\v');
c00275d3:	83 f9 20             	cmp    $0x20,%ecx
c00275d6:	74 f2                	je     c00275ca <atoi+0x3a>
  return (c == ' ' || c == '\f' || c == '\n'
c00275d8:	8d 58 f4             	lea    -0xc(%eax),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c00275db:	80 fb 01             	cmp    $0x1,%bl
c00275de:	76 ea                	jbe    c00275ca <atoi+0x3a>
c00275e0:	83 f9 0a             	cmp    $0xa,%ecx
c00275e3:	74 e5                	je     c00275ca <atoi+0x3a>
c00275e5:	89 c1                	mov    %eax,%ecx
c00275e7:	83 e1 fd             	and    $0xfffffffd,%ecx
c00275ea:	80 f9 09             	cmp    $0x9,%cl
c00275ed:	74 db                	je     c00275ca <atoi+0x3a>
  if (*s == '+')
c00275ef:	3c 2b                	cmp    $0x2b,%al
c00275f1:	75 0a                	jne    c00275fd <atoi+0x6d>
    s++;
c00275f3:	83 c2 01             	add    $0x1,%edx
  negative = false;
c00275f6:	be 00 00 00 00       	mov    $0x0,%esi
c00275fb:	eb 11                	jmp    c002760e <atoi+0x7e>
c00275fd:	be 00 00 00 00       	mov    $0x0,%esi
  else if (*s == '-')
c0027602:	3c 2d                	cmp    $0x2d,%al
c0027604:	75 08                	jne    c002760e <atoi+0x7e>
      s++;
c0027606:	8d 52 01             	lea    0x1(%edx),%edx
      negative = true;
c0027609:	be 01 00 00 00       	mov    $0x1,%esi
  for (value = 0; isdigit (*s); s++)
c002760e:	0f b6 0a             	movzbl (%edx),%ecx
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0027611:	0f be c1             	movsbl %cl,%eax
c0027614:	83 e8 30             	sub    $0x30,%eax
c0027617:	83 f8 09             	cmp    $0x9,%eax
c002761a:	77 2a                	ja     c0027646 <atoi+0xb6>
c002761c:	b8 00 00 00 00       	mov    $0x0,%eax
    value = value * 10 - (*s - '0');
c0027621:	bf 30 00 00 00       	mov    $0x30,%edi
c0027626:	8d 1c 80             	lea    (%eax,%eax,4),%ebx
c0027629:	0f be c9             	movsbl %cl,%ecx
c002762c:	89 f8                	mov    %edi,%eax
c002762e:	29 c8                	sub    %ecx,%eax
c0027630:	8d 04 58             	lea    (%eax,%ebx,2),%eax
  for (value = 0; isdigit (*s); s++)
c0027633:	83 c2 01             	add    $0x1,%edx
c0027636:	0f b6 0a             	movzbl (%edx),%ecx
c0027639:	0f be d9             	movsbl %cl,%ebx
c002763c:	83 eb 30             	sub    $0x30,%ebx
c002763f:	83 fb 09             	cmp    $0x9,%ebx
c0027642:	76 e2                	jbe    c0027626 <atoi+0x96>
c0027644:	eb 05                	jmp    c002764b <atoi+0xbb>
c0027646:	b8 00 00 00 00       	mov    $0x0,%eax
    value = -value;
c002764b:	89 c2                	mov    %eax,%edx
c002764d:	f7 da                	neg    %edx
c002764f:	89 f3                	mov    %esi,%ebx
c0027651:	84 db                	test   %bl,%bl
c0027653:	0f 44 c2             	cmove  %edx,%eax
}
c0027656:	83 c4 20             	add    $0x20,%esp
c0027659:	5b                   	pop    %ebx
c002765a:	5e                   	pop    %esi
c002765b:	5f                   	pop    %edi
c002765c:	c3                   	ret    

c002765d <sort>:
   B.  Runs in O(n lg n) time and O(1) space in CNT. */
void
sort (void *array, size_t cnt, size_t size,
      int (*compare) (const void *, const void *, void *aux),
      void *aux) 
{
c002765d:	55                   	push   %ebp
c002765e:	57                   	push   %edi
c002765f:	56                   	push   %esi
c0027660:	53                   	push   %ebx
c0027661:	83 ec 2c             	sub    $0x2c,%esp
c0027664:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0027668:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c002766c:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  size_t i;

  ASSERT (array != NULL || cnt == 0);
c0027670:	85 ff                	test   %edi,%edi
c0027672:	75 30                	jne    c00276a4 <sort+0x47>
c0027674:	85 db                	test   %ebx,%ebx
c0027676:	74 2c                	je     c00276a4 <sort+0x47>
c0027678:	c7 44 24 10 37 f9 02 	movl   $0xc002f937,0x10(%esp)
c002767f:	c0 
c0027680:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027687:	c0 
c0027688:	c7 44 24 08 24 dc 02 	movl   $0xc002dc24,0x8(%esp)
c002768f:	c0 
c0027690:	c7 44 24 04 8a 00 00 	movl   $0x8a,0x4(%esp)
c0027697:	00 
c0027698:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c002769f:	e8 df 12 00 00       	call   c0028983 <debug_panic>
  ASSERT (compare != NULL);
c00276a4:	83 7c 24 4c 00       	cmpl   $0x0,0x4c(%esp)
c00276a9:	75 2c                	jne    c00276d7 <sort+0x7a>
c00276ab:	c7 44 24 10 51 f9 02 	movl   $0xc002f951,0x10(%esp)
c00276b2:	c0 
c00276b3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00276ba:	c0 
c00276bb:	c7 44 24 08 24 dc 02 	movl   $0xc002dc24,0x8(%esp)
c00276c2:	c0 
c00276c3:	c7 44 24 04 8b 00 00 	movl   $0x8b,0x4(%esp)
c00276ca:	00 
c00276cb:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c00276d2:	e8 ac 12 00 00       	call   c0028983 <debug_panic>
  ASSERT (size > 0);
c00276d7:	85 ed                	test   %ebp,%ebp
c00276d9:	75 2c                	jne    c0027707 <sort+0xaa>
c00276db:	c7 44 24 10 61 f9 02 	movl   $0xc002f961,0x10(%esp)
c00276e2:	c0 
c00276e3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00276ea:	c0 
c00276eb:	c7 44 24 08 24 dc 02 	movl   $0xc002dc24,0x8(%esp)
c00276f2:	c0 
c00276f3:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c00276fa:	00 
c00276fb:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c0027702:	e8 7c 12 00 00       	call   c0028983 <debug_panic>

  /* Build a heap. */
  for (i = cnt / 2; i > 0; i--)
c0027707:	89 de                	mov    %ebx,%esi
c0027709:	d1 ee                	shr    %esi
c002770b:	74 23                	je     c0027730 <sort+0xd3>
    heapify (array, i, cnt, size, compare, aux);
c002770d:	8b 44 24 50          	mov    0x50(%esp),%eax
c0027711:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027715:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027719:	89 44 24 04          	mov    %eax,0x4(%esp)
c002771d:	89 2c 24             	mov    %ebp,(%esp)
c0027720:	89 d9                	mov    %ebx,%ecx
c0027722:	89 f2                	mov    %esi,%edx
c0027724:	89 f8                	mov    %edi,%eax
c0027726:	e8 bc fd ff ff       	call   c00274e7 <heapify>
  for (i = cnt / 2; i > 0; i--)
c002772b:	83 ee 01             	sub    $0x1,%esi
c002772e:	75 dd                	jne    c002770d <sort+0xb0>

  /* Sort the heap. */
  for (i = cnt; i > 1; i--) 
c0027730:	83 fb 01             	cmp    $0x1,%ebx
c0027733:	76 3a                	jbe    c002776f <sort+0x112>
c0027735:	8b 74 24 50          	mov    0x50(%esp),%esi
    {
      do_swap (array, 1, i, size);
c0027739:	89 2c 24             	mov    %ebp,(%esp)
c002773c:	89 d9                	mov    %ebx,%ecx
c002773e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027743:	89 f8                	mov    %edi,%eax
c0027745:	e8 62 fd ff ff       	call   c00274ac <do_swap>
      heapify (array, 1, i - 1, size, compare, aux); 
c002774a:	83 eb 01             	sub    $0x1,%ebx
c002774d:	89 74 24 08          	mov    %esi,0x8(%esp)
c0027751:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027755:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027759:	89 2c 24             	mov    %ebp,(%esp)
c002775c:	89 d9                	mov    %ebx,%ecx
c002775e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027763:	89 f8                	mov    %edi,%eax
c0027765:	e8 7d fd ff ff       	call   c00274e7 <heapify>
  for (i = cnt; i > 1; i--) 
c002776a:	83 fb 01             	cmp    $0x1,%ebx
c002776d:	75 ca                	jne    c0027739 <sort+0xdc>
    }
}
c002776f:	83 c4 2c             	add    $0x2c,%esp
c0027772:	5b                   	pop    %ebx
c0027773:	5e                   	pop    %esi
c0027774:	5f                   	pop    %edi
c0027775:	5d                   	pop    %ebp
c0027776:	c3                   	ret    

c0027777 <qsort>:
{
c0027777:	83 ec 2c             	sub    $0x2c,%esp
  sort (array, cnt, size, compare_thunk, &compare);
c002777a:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002777e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0027782:	c7 44 24 0c 90 74 02 	movl   $0xc0027490,0xc(%esp)
c0027789:	c0 
c002778a:	8b 44 24 38          	mov    0x38(%esp),%eax
c002778e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027792:	8b 44 24 34          	mov    0x34(%esp),%eax
c0027796:	89 44 24 04          	mov    %eax,0x4(%esp)
c002779a:	8b 44 24 30          	mov    0x30(%esp),%eax
c002779e:	89 04 24             	mov    %eax,(%esp)
c00277a1:	e8 b7 fe ff ff       	call   c002765d <sort>
}
c00277a6:	83 c4 2c             	add    $0x2c,%esp
c00277a9:	c3                   	ret    

c00277aa <binary_search>:
   B. */
void *
binary_search (const void *key, const void *array, size_t cnt, size_t size,
               int (*compare) (const void *, const void *, void *aux),
               void *aux) 
{
c00277aa:	55                   	push   %ebp
c00277ab:	57                   	push   %edi
c00277ac:	56                   	push   %esi
c00277ad:	53                   	push   %ebx
c00277ae:	83 ec 1c             	sub    $0x1c,%esp
c00277b1:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c00277b5:	8b 74 24 3c          	mov    0x3c(%esp),%esi
  const unsigned char *first = array;
  const unsigned char *last = array + size * cnt;
c00277b9:	89 f5                	mov    %esi,%ebp
c00277bb:	0f af 6c 24 38       	imul   0x38(%esp),%ebp
c00277c0:	01 dd                	add    %ebx,%ebp

  while (first < last) 
c00277c2:	39 eb                	cmp    %ebp,%ebx
c00277c4:	73 44                	jae    c002780a <binary_search+0x60>
    {
      size_t range = (last - first) / size;
c00277c6:	89 e8                	mov    %ebp,%eax
c00277c8:	29 d8                	sub    %ebx,%eax
c00277ca:	ba 00 00 00 00       	mov    $0x0,%edx
c00277cf:	f7 f6                	div    %esi
      const unsigned char *middle = first + (range / 2) * size;
c00277d1:	d1 e8                	shr    %eax
c00277d3:	0f af c6             	imul   %esi,%eax
c00277d6:	89 c7                	mov    %eax,%edi
c00277d8:	01 df                	add    %ebx,%edi
      int cmp = compare (key, middle, aux);
c00277da:	8b 44 24 44          	mov    0x44(%esp),%eax
c00277de:	89 44 24 08          	mov    %eax,0x8(%esp)
c00277e2:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00277e6:	8b 44 24 30          	mov    0x30(%esp),%eax
c00277ea:	89 04 24             	mov    %eax,(%esp)
c00277ed:	ff 54 24 40          	call   *0x40(%esp)

      if (cmp < 0) 
c00277f1:	85 c0                	test   %eax,%eax
c00277f3:	78 0d                	js     c0027802 <binary_search+0x58>
        last = middle;
      else if (cmp > 0) 
c00277f5:	85 c0                	test   %eax,%eax
c00277f7:	7e 19                	jle    c0027812 <binary_search+0x68>
        first = middle + size;
c00277f9:	8d 1c 37             	lea    (%edi,%esi,1),%ebx
c00277fc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027800:	eb 02                	jmp    c0027804 <binary_search+0x5a>
      const unsigned char *middle = first + (range / 2) * size;
c0027802:	89 fd                	mov    %edi,%ebp
  while (first < last) 
c0027804:	39 dd                	cmp    %ebx,%ebp
c0027806:	77 be                	ja     c00277c6 <binary_search+0x1c>
c0027808:	eb 0c                	jmp    c0027816 <binary_search+0x6c>
      else
        return (void *) middle;
    }
  
  return NULL;
c002780a:	b8 00 00 00 00       	mov    $0x0,%eax
c002780f:	90                   	nop
c0027810:	eb 09                	jmp    c002781b <binary_search+0x71>
      const unsigned char *middle = first + (range / 2) * size;
c0027812:	89 f8                	mov    %edi,%eax
c0027814:	eb 05                	jmp    c002781b <binary_search+0x71>
  return NULL;
c0027816:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002781b:	83 c4 1c             	add    $0x1c,%esp
c002781e:	5b                   	pop    %ebx
c002781f:	5e                   	pop    %esi
c0027820:	5f                   	pop    %edi
c0027821:	5d                   	pop    %ebp
c0027822:	c3                   	ret    

c0027823 <bsearch>:
{
c0027823:	83 ec 2c             	sub    $0x2c,%esp
  return binary_search (key, array, cnt, size, compare_thunk, &compare);
c0027826:	8d 44 24 40          	lea    0x40(%esp),%eax
c002782a:	89 44 24 14          	mov    %eax,0x14(%esp)
c002782e:	c7 44 24 10 90 74 02 	movl   $0xc0027490,0x10(%esp)
c0027835:	c0 
c0027836:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c002783a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002783e:	8b 44 24 38          	mov    0x38(%esp),%eax
c0027842:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027846:	8b 44 24 34          	mov    0x34(%esp),%eax
c002784a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002784e:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027852:	89 04 24             	mov    %eax,(%esp)
c0027855:	e8 50 ff ff ff       	call   c00277aa <binary_search>
}
c002785a:	83 c4 2c             	add    $0x2c,%esp
c002785d:	c3                   	ret    
c002785e:	90                   	nop
c002785f:	90                   	nop

c0027860 <memcpy>:

/* Copies SIZE bytes from SRC to DST, which must not overlap.
   Returns DST. */
void *
memcpy (void *dst_, const void *src_, size_t size) 
{
c0027860:	56                   	push   %esi
c0027861:	53                   	push   %ebx
c0027862:	83 ec 24             	sub    $0x24,%esp
c0027865:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027869:	8b 74 24 34          	mov    0x34(%esp),%esi
c002786d:	8b 5c 24 38          	mov    0x38(%esp),%ebx
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c0027871:	85 db                	test   %ebx,%ebx
c0027873:	0f 94 c2             	sete   %dl
c0027876:	85 c0                	test   %eax,%eax
c0027878:	75 30                	jne    c00278aa <memcpy+0x4a>
c002787a:	84 d2                	test   %dl,%dl
c002787c:	75 2c                	jne    c00278aa <memcpy+0x4a>
c002787e:	c7 44 24 10 6a f9 02 	movl   $0xc002f96a,0x10(%esp)
c0027885:	c0 
c0027886:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002788d:	c0 
c002788e:	c7 44 24 08 79 dc 02 	movl   $0xc002dc79,0x8(%esp)
c0027895:	c0 
c0027896:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002789d:	00 
c002789e:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c00278a5:	e8 d9 10 00 00       	call   c0028983 <debug_panic>
  ASSERT (src != NULL || size == 0);
c00278aa:	85 f6                	test   %esi,%esi
c00278ac:	75 04                	jne    c00278b2 <memcpy+0x52>
c00278ae:	84 d2                	test   %dl,%dl
c00278b0:	74 0b                	je     c00278bd <memcpy+0x5d>

  while (size-- > 0)
c00278b2:	ba 00 00 00 00       	mov    $0x0,%edx
c00278b7:	85 db                	test   %ebx,%ebx
c00278b9:	75 2e                	jne    c00278e9 <memcpy+0x89>
c00278bb:	eb 3a                	jmp    c00278f7 <memcpy+0x97>
  ASSERT (src != NULL || size == 0);
c00278bd:	c7 44 24 10 96 f9 02 	movl   $0xc002f996,0x10(%esp)
c00278c4:	c0 
c00278c5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00278cc:	c0 
c00278cd:	c7 44 24 08 79 dc 02 	movl   $0xc002dc79,0x8(%esp)
c00278d4:	c0 
c00278d5:	c7 44 24 04 0d 00 00 	movl   $0xd,0x4(%esp)
c00278dc:	00 
c00278dd:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c00278e4:	e8 9a 10 00 00       	call   c0028983 <debug_panic>
    *dst++ = *src++;
c00278e9:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
c00278ed:	88 0c 10             	mov    %cl,(%eax,%edx,1)
c00278f0:	83 c2 01             	add    $0x1,%edx
  while (size-- > 0)
c00278f3:	39 da                	cmp    %ebx,%edx
c00278f5:	75 f2                	jne    c00278e9 <memcpy+0x89>

  return dst_;
}
c00278f7:	83 c4 24             	add    $0x24,%esp
c00278fa:	5b                   	pop    %ebx
c00278fb:	5e                   	pop    %esi
c00278fc:	c3                   	ret    

c00278fd <memmove>:

/* Copies SIZE bytes from SRC to DST, which are allowed to
   overlap.  Returns DST. */
void *
memmove (void *dst_, const void *src_, size_t size) 
{
c00278fd:	57                   	push   %edi
c00278fe:	56                   	push   %esi
c00278ff:	53                   	push   %ebx
c0027900:	83 ec 20             	sub    $0x20,%esp
c0027903:	8b 74 24 30          	mov    0x30(%esp),%esi
c0027907:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c002790b:	8b 7c 24 38          	mov    0x38(%esp),%edi
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c002790f:	85 ff                	test   %edi,%edi
c0027911:	0f 94 c2             	sete   %dl
c0027914:	85 f6                	test   %esi,%esi
c0027916:	75 30                	jne    c0027948 <memmove+0x4b>
c0027918:	84 d2                	test   %dl,%dl
c002791a:	75 2c                	jne    c0027948 <memmove+0x4b>
c002791c:	c7 44 24 10 6a f9 02 	movl   $0xc002f96a,0x10(%esp)
c0027923:	c0 
c0027924:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002792b:	c0 
c002792c:	c7 44 24 08 71 dc 02 	movl   $0xc002dc71,0x8(%esp)
c0027933:	c0 
c0027934:	c7 44 24 04 1d 00 00 	movl   $0x1d,0x4(%esp)
c002793b:	00 
c002793c:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027943:	e8 3b 10 00 00       	call   c0028983 <debug_panic>
  ASSERT (src != NULL || size == 0);
c0027948:	85 db                	test   %ebx,%ebx
c002794a:	75 30                	jne    c002797c <memmove+0x7f>
c002794c:	84 d2                	test   %dl,%dl
c002794e:	75 2c                	jne    c002797c <memmove+0x7f>
c0027950:	c7 44 24 10 96 f9 02 	movl   $0xc002f996,0x10(%esp)
c0027957:	c0 
c0027958:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002795f:	c0 
c0027960:	c7 44 24 08 71 dc 02 	movl   $0xc002dc71,0x8(%esp)
c0027967:	c0 
c0027968:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002796f:	00 
c0027970:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027977:	e8 07 10 00 00       	call   c0028983 <debug_panic>

  if (dst < src) 
c002797c:	39 de                	cmp    %ebx,%esi
c002797e:	73 1b                	jae    c002799b <memmove+0x9e>
    {
      while (size-- > 0)
c0027980:	85 ff                	test   %edi,%edi
c0027982:	74 40                	je     c00279c4 <memmove+0xc7>
c0027984:	ba 00 00 00 00       	mov    $0x0,%edx
        *dst++ = *src++;
c0027989:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
c002798d:	88 0c 16             	mov    %cl,(%esi,%edx,1)
c0027990:	83 c2 01             	add    $0x1,%edx
      while (size-- > 0)
c0027993:	39 fa                	cmp    %edi,%edx
c0027995:	75 f2                	jne    c0027989 <memmove+0x8c>
c0027997:	01 fe                	add    %edi,%esi
c0027999:	eb 29                	jmp    c00279c4 <memmove+0xc7>
    }
  else 
    {
      dst += size;
c002799b:	8d 04 3e             	lea    (%esi,%edi,1),%eax
      src += size;
c002799e:	01 fb                	add    %edi,%ebx
      while (size-- > 0)
c00279a0:	8d 57 ff             	lea    -0x1(%edi),%edx
c00279a3:	85 ff                	test   %edi,%edi
c00279a5:	74 1b                	je     c00279c2 <memmove+0xc5>
c00279a7:	f7 df                	neg    %edi
c00279a9:	89 f9                	mov    %edi,%ecx
c00279ab:	01 fb                	add    %edi,%ebx
c00279ad:	01 c1                	add    %eax,%ecx
c00279af:	89 ce                	mov    %ecx,%esi
        *--dst = *--src;
c00279b1:	0f b6 04 13          	movzbl (%ebx,%edx,1),%eax
c00279b5:	88 04 11             	mov    %al,(%ecx,%edx,1)
      while (size-- > 0)
c00279b8:	83 ea 01             	sub    $0x1,%edx
c00279bb:	83 fa ff             	cmp    $0xffffffff,%edx
c00279be:	75 ef                	jne    c00279af <memmove+0xb2>
c00279c0:	eb 02                	jmp    c00279c4 <memmove+0xc7>
      dst += size;
c00279c2:	89 c6                	mov    %eax,%esi
    }

  return dst;
}
c00279c4:	89 f0                	mov    %esi,%eax
c00279c6:	83 c4 20             	add    $0x20,%esp
c00279c9:	5b                   	pop    %ebx
c00279ca:	5e                   	pop    %esi
c00279cb:	5f                   	pop    %edi
c00279cc:	c3                   	ret    

c00279cd <memcmp>:
   at A and B.  Returns a positive value if the byte in A is
   greater, a negative value if the byte in B is greater, or zero
   if blocks A and B are equal. */
int
memcmp (const void *a_, const void *b_, size_t size) 
{
c00279cd:	57                   	push   %edi
c00279ce:	56                   	push   %esi
c00279cf:	53                   	push   %ebx
c00279d0:	83 ec 20             	sub    $0x20,%esp
c00279d3:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00279d7:	8b 74 24 34          	mov    0x34(%esp),%esi
c00279db:	8b 44 24 38          	mov    0x38(%esp),%eax
  const unsigned char *a = a_;
  const unsigned char *b = b_;

  ASSERT (a != NULL || size == 0);
c00279df:	85 c0                	test   %eax,%eax
c00279e1:	0f 94 c2             	sete   %dl
c00279e4:	85 db                	test   %ebx,%ebx
c00279e6:	75 30                	jne    c0027a18 <memcmp+0x4b>
c00279e8:	84 d2                	test   %dl,%dl
c00279ea:	75 2c                	jne    c0027a18 <memcmp+0x4b>
c00279ec:	c7 44 24 10 af f9 02 	movl   $0xc002f9af,0x10(%esp)
c00279f3:	c0 
c00279f4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00279fb:	c0 
c00279fc:	c7 44 24 08 6a dc 02 	movl   $0xc002dc6a,0x8(%esp)
c0027a03:	c0 
c0027a04:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
c0027a0b:	00 
c0027a0c:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027a13:	e8 6b 0f 00 00       	call   c0028983 <debug_panic>
  ASSERT (b != NULL || size == 0);
c0027a18:	85 f6                	test   %esi,%esi
c0027a1a:	75 04                	jne    c0027a20 <memcmp+0x53>
c0027a1c:	84 d2                	test   %dl,%dl
c0027a1e:	74 18                	je     c0027a38 <memcmp+0x6b>

  for (; size-- > 0; a++, b++)
c0027a20:	8d 78 ff             	lea    -0x1(%eax),%edi
c0027a23:	85 c0                	test   %eax,%eax
c0027a25:	74 64                	je     c0027a8b <memcmp+0xbe>
    if (*a != *b)
c0027a27:	0f b6 13             	movzbl (%ebx),%edx
c0027a2a:	0f b6 0e             	movzbl (%esi),%ecx
c0027a2d:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a32:	38 ca                	cmp    %cl,%dl
c0027a34:	74 4a                	je     c0027a80 <memcmp+0xb3>
c0027a36:	eb 3c                	jmp    c0027a74 <memcmp+0xa7>
  ASSERT (b != NULL || size == 0);
c0027a38:	c7 44 24 10 c6 f9 02 	movl   $0xc002f9c6,0x10(%esp)
c0027a3f:	c0 
c0027a40:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027a47:	c0 
c0027a48:	c7 44 24 08 6a dc 02 	movl   $0xc002dc6a,0x8(%esp)
c0027a4f:	c0 
c0027a50:	c7 44 24 04 3b 00 00 	movl   $0x3b,0x4(%esp)
c0027a57:	00 
c0027a58:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027a5f:	e8 1f 0f 00 00       	call   c0028983 <debug_panic>
    if (*a != *b)
c0027a64:	0f b6 54 03 01       	movzbl 0x1(%ebx,%eax,1),%edx
c0027a69:	83 c0 01             	add    $0x1,%eax
c0027a6c:	0f b6 0c 06          	movzbl (%esi,%eax,1),%ecx
c0027a70:	38 ca                	cmp    %cl,%dl
c0027a72:	74 0c                	je     c0027a80 <memcmp+0xb3>
      return *a > *b ? +1 : -1;
c0027a74:	38 d1                	cmp    %dl,%cl
c0027a76:	19 c0                	sbb    %eax,%eax
c0027a78:	83 e0 02             	and    $0x2,%eax
c0027a7b:	83 e8 01             	sub    $0x1,%eax
c0027a7e:	eb 10                	jmp    c0027a90 <memcmp+0xc3>
  for (; size-- > 0; a++, b++)
c0027a80:	39 f8                	cmp    %edi,%eax
c0027a82:	75 e0                	jne    c0027a64 <memcmp+0x97>
  return 0;
c0027a84:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a89:	eb 05                	jmp    c0027a90 <memcmp+0xc3>
c0027a8b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027a90:	83 c4 20             	add    $0x20,%esp
c0027a93:	5b                   	pop    %ebx
c0027a94:	5e                   	pop    %esi
c0027a95:	5f                   	pop    %edi
c0027a96:	c3                   	ret    

c0027a97 <strcmp>:
   char) is greater, a negative value if the character in B (as
   an unsigned char) is greater, or zero if strings A and B are
   equal. */
int
strcmp (const char *a_, const char *b_) 
{
c0027a97:	83 ec 2c             	sub    $0x2c,%esp
c0027a9a:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c0027a9e:	8b 54 24 34          	mov    0x34(%esp),%edx
  const unsigned char *a = (const unsigned char *) a_;
  const unsigned char *b = (const unsigned char *) b_;

  ASSERT (a != NULL);
c0027aa2:	85 c9                	test   %ecx,%ecx
c0027aa4:	75 2c                	jne    c0027ad2 <strcmp+0x3b>
c0027aa6:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c0027aad:	c0 
c0027aae:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027ab5:	c0 
c0027ab6:	c7 44 24 08 63 dc 02 	movl   $0xc002dc63,0x8(%esp)
c0027abd:	c0 
c0027abe:	c7 44 24 04 4e 00 00 	movl   $0x4e,0x4(%esp)
c0027ac5:	00 
c0027ac6:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027acd:	e8 b1 0e 00 00       	call   c0028983 <debug_panic>
  ASSERT (b != NULL);
c0027ad2:	85 d2                	test   %edx,%edx
c0027ad4:	74 0e                	je     c0027ae4 <strcmp+0x4d>

  while (*a != '\0' && *a == *b) 
c0027ad6:	0f b6 01             	movzbl (%ecx),%eax
c0027ad9:	84 c0                	test   %al,%al
c0027adb:	74 44                	je     c0027b21 <strcmp+0x8a>
c0027add:	3a 02                	cmp    (%edx),%al
c0027adf:	90                   	nop
c0027ae0:	74 2e                	je     c0027b10 <strcmp+0x79>
c0027ae2:	eb 3d                	jmp    c0027b21 <strcmp+0x8a>
  ASSERT (b != NULL);
c0027ae4:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0027aeb:	c0 
c0027aec:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027af3:	c0 
c0027af4:	c7 44 24 08 63 dc 02 	movl   $0xc002dc63,0x8(%esp)
c0027afb:	c0 
c0027afc:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c0027b03:	00 
c0027b04:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027b0b:	e8 73 0e 00 00       	call   c0028983 <debug_panic>
    {
      a++;
c0027b10:	83 c1 01             	add    $0x1,%ecx
      b++;
c0027b13:	83 c2 01             	add    $0x1,%edx
  while (*a != '\0' && *a == *b) 
c0027b16:	0f b6 01             	movzbl (%ecx),%eax
c0027b19:	84 c0                	test   %al,%al
c0027b1b:	74 04                	je     c0027b21 <strcmp+0x8a>
c0027b1d:	3a 02                	cmp    (%edx),%al
c0027b1f:	74 ef                	je     c0027b10 <strcmp+0x79>
    }

  return *a < *b ? -1 : *a > *b;
c0027b21:	0f b6 12             	movzbl (%edx),%edx
c0027b24:	38 c2                	cmp    %al,%dl
c0027b26:	77 0a                	ja     c0027b32 <strcmp+0x9b>
c0027b28:	38 d0                	cmp    %dl,%al
c0027b2a:	0f 97 c0             	seta   %al
c0027b2d:	0f b6 c0             	movzbl %al,%eax
c0027b30:	eb 05                	jmp    c0027b37 <strcmp+0xa0>
c0027b32:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0027b37:	83 c4 2c             	add    $0x2c,%esp
c0027b3a:	c3                   	ret    

c0027b3b <memchr>:
/* Returns a pointer to the first occurrence of CH in the first
   SIZE bytes starting at BLOCK.  Returns a null pointer if CH
   does not occur in BLOCK. */
void *
memchr (const void *block_, int ch_, size_t size) 
{
c0027b3b:	56                   	push   %esi
c0027b3c:	53                   	push   %ebx
c0027b3d:	83 ec 24             	sub    $0x24,%esp
c0027b40:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027b44:	8b 74 24 34          	mov    0x34(%esp),%esi
c0027b48:	8b 54 24 38          	mov    0x38(%esp),%edx
  const unsigned char *block = block_;
  unsigned char ch = ch_;
c0027b4c:	89 f3                	mov    %esi,%ebx

  ASSERT (block != NULL || size == 0);
c0027b4e:	85 c0                	test   %eax,%eax
c0027b50:	75 04                	jne    c0027b56 <memchr+0x1b>
c0027b52:	85 d2                	test   %edx,%edx
c0027b54:	75 14                	jne    c0027b6a <memchr+0x2f>

  for (; size-- > 0; block++)
c0027b56:	8d 4a ff             	lea    -0x1(%edx),%ecx
c0027b59:	85 d2                	test   %edx,%edx
c0027b5b:	74 4e                	je     c0027bab <memchr+0x70>
    if (*block == ch)
c0027b5d:	89 f2                	mov    %esi,%edx
c0027b5f:	38 10                	cmp    %dl,(%eax)
c0027b61:	74 4d                	je     c0027bb0 <memchr+0x75>
c0027b63:	ba 00 00 00 00       	mov    $0x0,%edx
c0027b68:	eb 33                	jmp    c0027b9d <memchr+0x62>
  ASSERT (block != NULL || size == 0);
c0027b6a:	c7 44 24 10 e7 f9 02 	movl   $0xc002f9e7,0x10(%esp)
c0027b71:	c0 
c0027b72:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027b79:	c0 
c0027b7a:	c7 44 24 08 5c dc 02 	movl   $0xc002dc5c,0x8(%esp)
c0027b81:	c0 
c0027b82:	c7 44 24 04 63 00 00 	movl   $0x63,0x4(%esp)
c0027b89:	00 
c0027b8a:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027b91:	e8 ed 0d 00 00       	call   c0028983 <debug_panic>
c0027b96:	83 c2 01             	add    $0x1,%edx
    if (*block == ch)
c0027b99:	38 18                	cmp    %bl,(%eax)
c0027b9b:	74 13                	je     c0027bb0 <memchr+0x75>
  for (; size-- > 0; block++)
c0027b9d:	83 c0 01             	add    $0x1,%eax
c0027ba0:	39 ca                	cmp    %ecx,%edx
c0027ba2:	75 f2                	jne    c0027b96 <memchr+0x5b>
      return (void *) block;

  return NULL;
c0027ba4:	b8 00 00 00 00       	mov    $0x0,%eax
c0027ba9:	eb 05                	jmp    c0027bb0 <memchr+0x75>
c0027bab:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027bb0:	83 c4 24             	add    $0x24,%esp
c0027bb3:	5b                   	pop    %ebx
c0027bb4:	5e                   	pop    %esi
c0027bb5:	c3                   	ret    

c0027bb6 <strchr>:
   null pointer if C does not appear in STRING.  If C == '\0'
   then returns a pointer to the null terminator at the end of
   STRING. */
char *
strchr (const char *string, int c_) 
{
c0027bb6:	53                   	push   %ebx
c0027bb7:	83 ec 28             	sub    $0x28,%esp
c0027bba:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027bbe:	8b 54 24 34          	mov    0x34(%esp),%edx
  char c = c_;

  ASSERT (string != NULL);
c0027bc2:	85 c0                	test   %eax,%eax
c0027bc4:	74 0b                	je     c0027bd1 <strchr+0x1b>
c0027bc6:	89 d1                	mov    %edx,%ecx

  for (;;) 
    if (*string == c)
c0027bc8:	0f b6 18             	movzbl (%eax),%ebx
c0027bcb:	38 d3                	cmp    %dl,%bl
c0027bcd:	75 2e                	jne    c0027bfd <strchr+0x47>
c0027bcf:	eb 4e                	jmp    c0027c1f <strchr+0x69>
  ASSERT (string != NULL);
c0027bd1:	c7 44 24 10 02 fa 02 	movl   $0xc002fa02,0x10(%esp)
c0027bd8:	c0 
c0027bd9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027be0:	c0 
c0027be1:	c7 44 24 08 55 dc 02 	movl   $0xc002dc55,0x8(%esp)
c0027be8:	c0 
c0027be9:	c7 44 24 04 75 00 00 	movl   $0x75,0x4(%esp)
c0027bf0:	00 
c0027bf1:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027bf8:	e8 86 0d 00 00       	call   c0028983 <debug_panic>
      return (char *) string;
    else if (*string == '\0')
c0027bfd:	84 db                	test   %bl,%bl
c0027bff:	75 06                	jne    c0027c07 <strchr+0x51>
c0027c01:	eb 10                	jmp    c0027c13 <strchr+0x5d>
c0027c03:	84 d2                	test   %dl,%dl
c0027c05:	74 13                	je     c0027c1a <strchr+0x64>
      return NULL;
    else
      string++;
c0027c07:	83 c0 01             	add    $0x1,%eax
    if (*string == c)
c0027c0a:	0f b6 10             	movzbl (%eax),%edx
c0027c0d:	38 ca                	cmp    %cl,%dl
c0027c0f:	75 f2                	jne    c0027c03 <strchr+0x4d>
c0027c11:	eb 0c                	jmp    c0027c1f <strchr+0x69>
      return NULL;
c0027c13:	b8 00 00 00 00       	mov    $0x0,%eax
c0027c18:	eb 05                	jmp    c0027c1f <strchr+0x69>
c0027c1a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027c1f:	83 c4 28             	add    $0x28,%esp
c0027c22:	5b                   	pop    %ebx
c0027c23:	c3                   	ret    

c0027c24 <strcspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters that are not in STOP. */
size_t
strcspn (const char *string, const char *stop) 
{
c0027c24:	57                   	push   %edi
c0027c25:	56                   	push   %esi
c0027c26:	53                   	push   %ebx
c0027c27:	83 ec 10             	sub    $0x10,%esp
c0027c2a:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027c2e:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;

  for (length = 0; string[length] != '\0'; length++)
c0027c32:	0f b6 16             	movzbl (%esi),%edx
c0027c35:	84 d2                	test   %dl,%dl
c0027c37:	74 25                	je     c0027c5e <strcspn+0x3a>
c0027c39:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (stop, string[length]) != NULL)
c0027c3e:	0f be d2             	movsbl %dl,%edx
c0027c41:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c45:	89 3c 24             	mov    %edi,(%esp)
c0027c48:	e8 69 ff ff ff       	call   c0027bb6 <strchr>
c0027c4d:	85 c0                	test   %eax,%eax
c0027c4f:	75 12                	jne    c0027c63 <strcspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027c51:	83 c3 01             	add    $0x1,%ebx
c0027c54:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027c58:	84 d2                	test   %dl,%dl
c0027c5a:	75 e2                	jne    c0027c3e <strcspn+0x1a>
c0027c5c:	eb 05                	jmp    c0027c63 <strcspn+0x3f>
c0027c5e:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027c63:	89 d8                	mov    %ebx,%eax
c0027c65:	83 c4 10             	add    $0x10,%esp
c0027c68:	5b                   	pop    %ebx
c0027c69:	5e                   	pop    %esi
c0027c6a:	5f                   	pop    %edi
c0027c6b:	c3                   	ret    

c0027c6c <strpbrk>:
/* Returns a pointer to the first character in STRING that is
   also in STOP.  If no character in STRING is in STOP, returns a
   null pointer. */
char *
strpbrk (const char *string, const char *stop) 
{
c0027c6c:	56                   	push   %esi
c0027c6d:	53                   	push   %ebx
c0027c6e:	83 ec 14             	sub    $0x14,%esp
c0027c71:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0027c75:	8b 74 24 24          	mov    0x24(%esp),%esi
  for (; *string != '\0'; string++)
c0027c79:	0f b6 13             	movzbl (%ebx),%edx
c0027c7c:	84 d2                	test   %dl,%dl
c0027c7e:	74 1f                	je     c0027c9f <strpbrk+0x33>
    if (strchr (stop, *string) != NULL)
c0027c80:	0f be d2             	movsbl %dl,%edx
c0027c83:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c87:	89 34 24             	mov    %esi,(%esp)
c0027c8a:	e8 27 ff ff ff       	call   c0027bb6 <strchr>
c0027c8f:	85 c0                	test   %eax,%eax
c0027c91:	75 13                	jne    c0027ca6 <strpbrk+0x3a>
  for (; *string != '\0'; string++)
c0027c93:	83 c3 01             	add    $0x1,%ebx
c0027c96:	0f b6 13             	movzbl (%ebx),%edx
c0027c99:	84 d2                	test   %dl,%dl
c0027c9b:	75 e3                	jne    c0027c80 <strpbrk+0x14>
c0027c9d:	eb 09                	jmp    c0027ca8 <strpbrk+0x3c>
      return (char *) string;
  return NULL;
c0027c9f:	b8 00 00 00 00       	mov    $0x0,%eax
c0027ca4:	eb 02                	jmp    c0027ca8 <strpbrk+0x3c>
c0027ca6:	89 d8                	mov    %ebx,%eax
}
c0027ca8:	83 c4 14             	add    $0x14,%esp
c0027cab:	5b                   	pop    %ebx
c0027cac:	5e                   	pop    %esi
c0027cad:	c3                   	ret    

c0027cae <strrchr>:

/* Returns a pointer to the last occurrence of C in STRING.
   Returns a null pointer if C does not occur in STRING. */
char *
strrchr (const char *string, int c_) 
{
c0027cae:	53                   	push   %ebx
c0027caf:	8b 54 24 08          	mov    0x8(%esp),%edx
  char c = c_;
c0027cb3:	0f b6 5c 24 0c       	movzbl 0xc(%esp),%ebx
  const char *p = NULL;

  for (; *string != '\0'; string++)
c0027cb8:	0f b6 0a             	movzbl (%edx),%ecx
c0027cbb:	84 c9                	test   %cl,%cl
c0027cbd:	74 16                	je     c0027cd5 <strrchr+0x27>
  const char *p = NULL;
c0027cbf:	b8 00 00 00 00       	mov    $0x0,%eax
c0027cc4:	38 cb                	cmp    %cl,%bl
c0027cc6:	0f 44 c2             	cmove  %edx,%eax
  for (; *string != '\0'; string++)
c0027cc9:	83 c2 01             	add    $0x1,%edx
c0027ccc:	0f b6 0a             	movzbl (%edx),%ecx
c0027ccf:	84 c9                	test   %cl,%cl
c0027cd1:	75 f1                	jne    c0027cc4 <strrchr+0x16>
c0027cd3:	eb 05                	jmp    c0027cda <strrchr+0x2c>
  const char *p = NULL;
c0027cd5:	b8 00 00 00 00       	mov    $0x0,%eax
    if (*string == c)
      p = string;
  return (char *) p;
}
c0027cda:	5b                   	pop    %ebx
c0027cdb:	c3                   	ret    

c0027cdc <strspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters in SKIP. */
size_t
strspn (const char *string, const char *skip) 
{
c0027cdc:	57                   	push   %edi
c0027cdd:	56                   	push   %esi
c0027cde:	53                   	push   %ebx
c0027cdf:	83 ec 10             	sub    $0x10,%esp
c0027ce2:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027ce6:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;
  
  for (length = 0; string[length] != '\0'; length++)
c0027cea:	0f b6 16             	movzbl (%esi),%edx
c0027ced:	84 d2                	test   %dl,%dl
c0027cef:	74 25                	je     c0027d16 <strspn+0x3a>
c0027cf1:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (skip, string[length]) == NULL)
c0027cf6:	0f be d2             	movsbl %dl,%edx
c0027cf9:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027cfd:	89 3c 24             	mov    %edi,(%esp)
c0027d00:	e8 b1 fe ff ff       	call   c0027bb6 <strchr>
c0027d05:	85 c0                	test   %eax,%eax
c0027d07:	74 12                	je     c0027d1b <strspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027d09:	83 c3 01             	add    $0x1,%ebx
c0027d0c:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027d10:	84 d2                	test   %dl,%dl
c0027d12:	75 e2                	jne    c0027cf6 <strspn+0x1a>
c0027d14:	eb 05                	jmp    c0027d1b <strspn+0x3f>
c0027d16:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027d1b:	89 d8                	mov    %ebx,%eax
c0027d1d:	83 c4 10             	add    $0x10,%esp
c0027d20:	5b                   	pop    %ebx
c0027d21:	5e                   	pop    %esi
c0027d22:	5f                   	pop    %edi
c0027d23:	c3                   	ret    

c0027d24 <strtok_r>:
     'to'
     'tokenize.'
*/
char *
strtok_r (char *s, const char *delimiters, char **save_ptr) 
{
c0027d24:	55                   	push   %ebp
c0027d25:	57                   	push   %edi
c0027d26:	56                   	push   %esi
c0027d27:	53                   	push   %ebx
c0027d28:	83 ec 2c             	sub    $0x2c,%esp
c0027d2b:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c0027d2f:	8b 74 24 44          	mov    0x44(%esp),%esi
  char *token;
  
  ASSERT (delimiters != NULL);
c0027d33:	85 f6                	test   %esi,%esi
c0027d35:	75 2c                	jne    c0027d63 <strtok_r+0x3f>
c0027d37:	c7 44 24 10 11 fa 02 	movl   $0xc002fa11,0x10(%esp)
c0027d3e:	c0 
c0027d3f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027d46:	c0 
c0027d47:	c7 44 24 08 4c dc 02 	movl   $0xc002dc4c,0x8(%esp)
c0027d4e:	c0 
c0027d4f:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0027d56:	00 
c0027d57:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027d5e:	e8 20 0c 00 00       	call   c0028983 <debug_panic>
  ASSERT (save_ptr != NULL);
c0027d63:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0027d68:	75 2c                	jne    c0027d96 <strtok_r+0x72>
c0027d6a:	c7 44 24 10 24 fa 02 	movl   $0xc002fa24,0x10(%esp)
c0027d71:	c0 
c0027d72:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027d79:	c0 
c0027d7a:	c7 44 24 08 4c dc 02 	movl   $0xc002dc4c,0x8(%esp)
c0027d81:	c0 
c0027d82:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c0027d89:	00 
c0027d8a:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027d91:	e8 ed 0b 00 00       	call   c0028983 <debug_panic>

  /* If S is nonnull, start from it.
     If S is null, start from saved position. */
  if (s == NULL)
c0027d96:	85 db                	test   %ebx,%ebx
c0027d98:	75 4c                	jne    c0027de6 <strtok_r+0xc2>
    s = *save_ptr;
c0027d9a:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027d9e:	8b 18                	mov    (%eax),%ebx
  ASSERT (s != NULL);
c0027da0:	85 db                	test   %ebx,%ebx
c0027da2:	75 42                	jne    c0027de6 <strtok_r+0xc2>
c0027da4:	c7 44 24 10 1a fa 02 	movl   $0xc002fa1a,0x10(%esp)
c0027dab:	c0 
c0027dac:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027db3:	c0 
c0027db4:	c7 44 24 08 4c dc 02 	movl   $0xc002dc4c,0x8(%esp)
c0027dbb:	c0 
c0027dbc:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0027dc3:	00 
c0027dc4:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027dcb:	e8 b3 0b 00 00       	call   c0028983 <debug_panic>
  while (strchr (delimiters, *s) != NULL) 
    {
      /* strchr() will always return nonnull if we're searching
         for a null byte, because every string contains a null
         byte (at the end). */
      if (*s == '\0')
c0027dd0:	89 f8                	mov    %edi,%eax
c0027dd2:	84 c0                	test   %al,%al
c0027dd4:	75 0d                	jne    c0027de3 <strtok_r+0xbf>
        {
          *save_ptr = s;
c0027dd6:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027dda:	89 18                	mov    %ebx,(%eax)
          return NULL;
c0027ddc:	b8 00 00 00 00       	mov    $0x0,%eax
c0027de1:	eb 56                	jmp    c0027e39 <strtok_r+0x115>
        }

      s++;
c0027de3:	83 c3 01             	add    $0x1,%ebx
  while (strchr (delimiters, *s) != NULL) 
c0027de6:	0f b6 3b             	movzbl (%ebx),%edi
c0027de9:	89 f8                	mov    %edi,%eax
c0027deb:	0f be c0             	movsbl %al,%eax
c0027dee:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027df2:	89 34 24             	mov    %esi,(%esp)
c0027df5:	e8 bc fd ff ff       	call   c0027bb6 <strchr>
c0027dfa:	85 c0                	test   %eax,%eax
c0027dfc:	75 d2                	jne    c0027dd0 <strtok_r+0xac>
c0027dfe:	89 df                	mov    %ebx,%edi
    }

  /* Skip any non-DELIMITERS up to the end of the string. */
  token = s;
  while (strchr (delimiters, *s) == NULL)
    s++;
c0027e00:	83 c7 01             	add    $0x1,%edi
  while (strchr (delimiters, *s) == NULL)
c0027e03:	0f b6 2f             	movzbl (%edi),%ebp
c0027e06:	89 e8                	mov    %ebp,%eax
c0027e08:	0f be c0             	movsbl %al,%eax
c0027e0b:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027e0f:	89 34 24             	mov    %esi,(%esp)
c0027e12:	e8 9f fd ff ff       	call   c0027bb6 <strchr>
c0027e17:	85 c0                	test   %eax,%eax
c0027e19:	74 e5                	je     c0027e00 <strtok_r+0xdc>
  if (*s != '\0') 
c0027e1b:	89 e8                	mov    %ebp,%eax
c0027e1d:	84 c0                	test   %al,%al
c0027e1f:	74 10                	je     c0027e31 <strtok_r+0x10d>
    {
      *s = '\0';
c0027e21:	c6 07 00             	movb   $0x0,(%edi)
      *save_ptr = s + 1;
c0027e24:	83 c7 01             	add    $0x1,%edi
c0027e27:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e2b:	89 38                	mov    %edi,(%eax)
c0027e2d:	89 d8                	mov    %ebx,%eax
c0027e2f:	eb 08                	jmp    c0027e39 <strtok_r+0x115>
    }
  else 
    *save_ptr = s;
c0027e31:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e35:	89 38                	mov    %edi,(%eax)
c0027e37:	89 d8                	mov    %ebx,%eax
  return token;
}
c0027e39:	83 c4 2c             	add    $0x2c,%esp
c0027e3c:	5b                   	pop    %ebx
c0027e3d:	5e                   	pop    %esi
c0027e3e:	5f                   	pop    %edi
c0027e3f:	5d                   	pop    %ebp
c0027e40:	c3                   	ret    

c0027e41 <memset>:

/* Sets the SIZE bytes in DST to VALUE. */
void *
memset (void *dst_, int value, size_t size) 
{
c0027e41:	56                   	push   %esi
c0027e42:	53                   	push   %ebx
c0027e43:	83 ec 24             	sub    $0x24,%esp
c0027e46:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027e4a:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c0027e4e:	8b 74 24 38          	mov    0x38(%esp),%esi
  unsigned char *dst = dst_;

  ASSERT (dst != NULL || size == 0);
c0027e52:	85 c0                	test   %eax,%eax
c0027e54:	75 04                	jne    c0027e5a <memset+0x19>
c0027e56:	85 f6                	test   %esi,%esi
c0027e58:	75 0b                	jne    c0027e65 <memset+0x24>
c0027e5a:	8d 0c 30             	lea    (%eax,%esi,1),%ecx
  
  while (size-- > 0)
c0027e5d:	89 c2                	mov    %eax,%edx
c0027e5f:	85 f6                	test   %esi,%esi
c0027e61:	75 2e                	jne    c0027e91 <memset+0x50>
c0027e63:	eb 36                	jmp    c0027e9b <memset+0x5a>
  ASSERT (dst != NULL || size == 0);
c0027e65:	c7 44 24 10 6a f9 02 	movl   $0xc002f96a,0x10(%esp)
c0027e6c:	c0 
c0027e6d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027e74:	c0 
c0027e75:	c7 44 24 08 45 dc 02 	movl   $0xc002dc45,0x8(%esp)
c0027e7c:	c0 
c0027e7d:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c0027e84:	00 
c0027e85:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027e8c:	e8 f2 0a 00 00       	call   c0028983 <debug_panic>
    *dst++ = value;
c0027e91:	83 c2 01             	add    $0x1,%edx
c0027e94:	88 5a ff             	mov    %bl,-0x1(%edx)
  while (size-- > 0)
c0027e97:	39 ca                	cmp    %ecx,%edx
c0027e99:	75 f6                	jne    c0027e91 <memset+0x50>

  return dst_;
}
c0027e9b:	83 c4 24             	add    $0x24,%esp
c0027e9e:	5b                   	pop    %ebx
c0027e9f:	5e                   	pop    %esi
c0027ea0:	c3                   	ret    

c0027ea1 <strlen>:

/* Returns the length of STRING. */
size_t
strlen (const char *string) 
{
c0027ea1:	83 ec 2c             	sub    $0x2c,%esp
c0027ea4:	8b 54 24 30          	mov    0x30(%esp),%edx
  const char *p;

  ASSERT (string != NULL);
c0027ea8:	85 d2                	test   %edx,%edx
c0027eaa:	74 09                	je     c0027eb5 <strlen+0x14>

  for (p = string; *p != '\0'; p++)
c0027eac:	89 d0                	mov    %edx,%eax
c0027eae:	80 3a 00             	cmpb   $0x0,(%edx)
c0027eb1:	74 38                	je     c0027eeb <strlen+0x4a>
c0027eb3:	eb 2c                	jmp    c0027ee1 <strlen+0x40>
  ASSERT (string != NULL);
c0027eb5:	c7 44 24 10 02 fa 02 	movl   $0xc002fa02,0x10(%esp)
c0027ebc:	c0 
c0027ebd:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027ec4:	c0 
c0027ec5:	c7 44 24 08 3e dc 02 	movl   $0xc002dc3e,0x8(%esp)
c0027ecc:	c0 
c0027ecd:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c0027ed4:	00 
c0027ed5:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027edc:	e8 a2 0a 00 00       	call   c0028983 <debug_panic>
  for (p = string; *p != '\0'; p++)
c0027ee1:	89 d0                	mov    %edx,%eax
c0027ee3:	83 c0 01             	add    $0x1,%eax
c0027ee6:	80 38 00             	cmpb   $0x0,(%eax)
c0027ee9:	75 f8                	jne    c0027ee3 <strlen+0x42>
    continue;
  return p - string;
c0027eeb:	29 d0                	sub    %edx,%eax
}
c0027eed:	83 c4 2c             	add    $0x2c,%esp
c0027ef0:	c3                   	ret    

c0027ef1 <strstr>:
{
c0027ef1:	55                   	push   %ebp
c0027ef2:	57                   	push   %edi
c0027ef3:	56                   	push   %esi
c0027ef4:	53                   	push   %ebx
c0027ef5:	83 ec 1c             	sub    $0x1c,%esp
c0027ef8:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  size_t haystack_len = strlen (haystack);
c0027efc:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c0027f01:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0027f05:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f0a:	89 d9                	mov    %ebx,%ecx
c0027f0c:	f2 ae                	repnz scas %es:(%edi),%al
c0027f0e:	f7 d1                	not    %ecx
c0027f10:	8d 51 ff             	lea    -0x1(%ecx),%edx
  size_t needle_len = strlen (needle);
c0027f13:	89 ef                	mov    %ebp,%edi
c0027f15:	89 d9                	mov    %ebx,%ecx
c0027f17:	f2 ae                	repnz scas %es:(%edi),%al
c0027f19:	f7 d1                	not    %ecx
c0027f1b:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (haystack_len >= needle_len) 
c0027f1e:	39 fa                	cmp    %edi,%edx
c0027f20:	72 30                	jb     c0027f52 <strstr+0x61>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f22:	29 fa                	sub    %edi,%edx
c0027f24:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0027f28:	bb 00 00 00 00       	mov    $0x0,%ebx
c0027f2d:	89 de                	mov    %ebx,%esi
c0027f2f:	03 74 24 30          	add    0x30(%esp),%esi
        if (!memcmp (haystack + i, needle, needle_len))
c0027f33:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0027f37:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0027f3b:	89 34 24             	mov    %esi,(%esp)
c0027f3e:	e8 8a fa ff ff       	call   c00279cd <memcmp>
c0027f43:	85 c0                	test   %eax,%eax
c0027f45:	74 12                	je     c0027f59 <strstr+0x68>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f47:	83 c3 01             	add    $0x1,%ebx
c0027f4a:	3b 5c 24 0c          	cmp    0xc(%esp),%ebx
c0027f4e:	76 dd                	jbe    c0027f2d <strstr+0x3c>
c0027f50:	eb 0b                	jmp    c0027f5d <strstr+0x6c>
  return NULL;
c0027f52:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f57:	eb 09                	jmp    c0027f62 <strstr+0x71>
        if (!memcmp (haystack + i, needle, needle_len))
c0027f59:	89 f0                	mov    %esi,%eax
c0027f5b:	eb 05                	jmp    c0027f62 <strstr+0x71>
  return NULL;
c0027f5d:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027f62:	83 c4 1c             	add    $0x1c,%esp
c0027f65:	5b                   	pop    %ebx
c0027f66:	5e                   	pop    %esi
c0027f67:	5f                   	pop    %edi
c0027f68:	5d                   	pop    %ebp
c0027f69:	c3                   	ret    

c0027f6a <strnlen>:

/* If STRING is less than MAXLEN characters in length, returns
   its actual length.  Otherwise, returns MAXLEN. */
size_t
strnlen (const char *string, size_t maxlen) 
{
c0027f6a:	8b 54 24 04          	mov    0x4(%esp),%edx
c0027f6e:	8b 4c 24 08          	mov    0x8(%esp),%ecx
  size_t length;

  for (length = 0; string[length] != '\0' && length < maxlen; length++)
c0027f72:	80 3a 00             	cmpb   $0x0,(%edx)
c0027f75:	74 18                	je     c0027f8f <strnlen+0x25>
c0027f77:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f7c:	85 c9                	test   %ecx,%ecx
c0027f7e:	74 14                	je     c0027f94 <strnlen+0x2a>
c0027f80:	83 c0 01             	add    $0x1,%eax
c0027f83:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
c0027f87:	74 0b                	je     c0027f94 <strnlen+0x2a>
c0027f89:	39 c8                	cmp    %ecx,%eax
c0027f8b:	74 07                	je     c0027f94 <strnlen+0x2a>
c0027f8d:	eb f1                	jmp    c0027f80 <strnlen+0x16>
c0027f8f:	b8 00 00 00 00       	mov    $0x0,%eax
    continue;
  return length;
}
c0027f94:	f3 c3                	repz ret 

c0027f96 <strlcpy>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcpy (char *dst, const char *src, size_t size) 
{
c0027f96:	57                   	push   %edi
c0027f97:	56                   	push   %esi
c0027f98:	53                   	push   %ebx
c0027f99:	83 ec 20             	sub    $0x20,%esp
c0027f9c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027fa0:	8b 54 24 34          	mov    0x34(%esp),%edx
c0027fa4:	8b 74 24 38          	mov    0x38(%esp),%esi
  size_t src_len;

  ASSERT (dst != NULL);
c0027fa8:	85 db                	test   %ebx,%ebx
c0027faa:	75 2c                	jne    c0027fd8 <strlcpy+0x42>
c0027fac:	c7 44 24 10 35 fa 02 	movl   $0xc002fa35,0x10(%esp)
c0027fb3:	c0 
c0027fb4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027fbb:	c0 
c0027fbc:	c7 44 24 08 36 dc 02 	movl   $0xc002dc36,0x8(%esp)
c0027fc3:	c0 
c0027fc4:	c7 44 24 04 4a 01 00 	movl   $0x14a,0x4(%esp)
c0027fcb:	00 
c0027fcc:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027fd3:	e8 ab 09 00 00       	call   c0028983 <debug_panic>
  ASSERT (src != NULL);
c0027fd8:	85 d2                	test   %edx,%edx
c0027fda:	75 2c                	jne    c0028008 <strlcpy+0x72>
c0027fdc:	c7 44 24 10 41 fa 02 	movl   $0xc002fa41,0x10(%esp)
c0027fe3:	c0 
c0027fe4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027feb:	c0 
c0027fec:	c7 44 24 08 36 dc 02 	movl   $0xc002dc36,0x8(%esp)
c0027ff3:	c0 
c0027ff4:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
c0027ffb:	00 
c0027ffc:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0028003:	e8 7b 09 00 00       	call   c0028983 <debug_panic>

  src_len = strlen (src);
c0028008:	89 d7                	mov    %edx,%edi
c002800a:	b8 00 00 00 00       	mov    $0x0,%eax
c002800f:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028014:	f2 ae                	repnz scas %es:(%edi),%al
c0028016:	f7 d1                	not    %ecx
c0028018:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (size > 0) 
c002801b:	85 f6                	test   %esi,%esi
c002801d:	74 1c                	je     c002803b <strlcpy+0xa5>
    {
      size_t dst_len = size - 1;
c002801f:	83 ee 01             	sub    $0x1,%esi
c0028022:	39 f7                	cmp    %esi,%edi
c0028024:	0f 46 f7             	cmovbe %edi,%esi
      if (src_len < dst_len)
        dst_len = src_len;
      memcpy (dst, src, dst_len);
c0028027:	89 74 24 08          	mov    %esi,0x8(%esp)
c002802b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002802f:	89 1c 24             	mov    %ebx,(%esp)
c0028032:	e8 29 f8 ff ff       	call   c0027860 <memcpy>
      dst[dst_len] = '\0';
c0028037:	c6 04 33 00          	movb   $0x0,(%ebx,%esi,1)
    }
  return src_len;
}
c002803b:	89 f8                	mov    %edi,%eax
c002803d:	83 c4 20             	add    $0x20,%esp
c0028040:	5b                   	pop    %ebx
c0028041:	5e                   	pop    %esi
c0028042:	5f                   	pop    %edi
c0028043:	c3                   	ret    

c0028044 <strlcat>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcat (char *dst, const char *src, size_t size) 
{
c0028044:	55                   	push   %ebp
c0028045:	57                   	push   %edi
c0028046:	56                   	push   %esi
c0028047:	53                   	push   %ebx
c0028048:	83 ec 2c             	sub    $0x2c,%esp
c002804b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
c002804f:	8b 54 24 44          	mov    0x44(%esp),%edx
  size_t src_len, dst_len;

  ASSERT (dst != NULL);
c0028053:	85 ed                	test   %ebp,%ebp
c0028055:	75 2c                	jne    c0028083 <strlcat+0x3f>
c0028057:	c7 44 24 10 35 fa 02 	movl   $0xc002fa35,0x10(%esp)
c002805e:	c0 
c002805f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028066:	c0 
c0028067:	c7 44 24 08 2e dc 02 	movl   $0xc002dc2e,0x8(%esp)
c002806e:	c0 
c002806f:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
c0028076:	00 
c0028077:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c002807e:	e8 00 09 00 00       	call   c0028983 <debug_panic>
  ASSERT (src != NULL);
c0028083:	85 d2                	test   %edx,%edx
c0028085:	75 2c                	jne    c00280b3 <strlcat+0x6f>
c0028087:	c7 44 24 10 41 fa 02 	movl   $0xc002fa41,0x10(%esp)
c002808e:	c0 
c002808f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028096:	c0 
c0028097:	c7 44 24 08 2e dc 02 	movl   $0xc002dc2e,0x8(%esp)
c002809e:	c0 
c002809f:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
c00280a6:	00 
c00280a7:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c00280ae:	e8 d0 08 00 00       	call   c0028983 <debug_panic>

  src_len = strlen (src);
c00280b3:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c00280b8:	89 d7                	mov    %edx,%edi
c00280ba:	b8 00 00 00 00       	mov    $0x0,%eax
c00280bf:	89 d9                	mov    %ebx,%ecx
c00280c1:	f2 ae                	repnz scas %es:(%edi),%al
c00280c3:	f7 d1                	not    %ecx
c00280c5:	8d 71 ff             	lea    -0x1(%ecx),%esi
  dst_len = strlen (dst);
c00280c8:	89 ef                	mov    %ebp,%edi
c00280ca:	89 d9                	mov    %ebx,%ecx
c00280cc:	f2 ae                	repnz scas %es:(%edi),%al
c00280ce:	89 cb                	mov    %ecx,%ebx
c00280d0:	f7 d3                	not    %ebx
c00280d2:	83 eb 01             	sub    $0x1,%ebx
  if (size > 0 && dst_len < size) 
c00280d5:	3b 5c 24 48          	cmp    0x48(%esp),%ebx
c00280d9:	73 2c                	jae    c0028107 <strlcat+0xc3>
c00280db:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c00280e0:	74 25                	je     c0028107 <strlcat+0xc3>
    {
      size_t copy_cnt = size - dst_len - 1;
c00280e2:	8b 44 24 48          	mov    0x48(%esp),%eax
c00280e6:	8d 78 ff             	lea    -0x1(%eax),%edi
c00280e9:	29 df                	sub    %ebx,%edi
c00280eb:	39 f7                	cmp    %esi,%edi
c00280ed:	0f 47 fe             	cmova  %esi,%edi
      if (src_len < copy_cnt)
        copy_cnt = src_len;
      memcpy (dst + dst_len, src, copy_cnt);
c00280f0:	01 dd                	add    %ebx,%ebp
c00280f2:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00280f6:	89 54 24 04          	mov    %edx,0x4(%esp)
c00280fa:	89 2c 24             	mov    %ebp,(%esp)
c00280fd:	e8 5e f7 ff ff       	call   c0027860 <memcpy>
      dst[dst_len + copy_cnt] = '\0';
c0028102:	c6 44 3d 00 00       	movb   $0x0,0x0(%ebp,%edi,1)
    }
  return src_len + dst_len;
c0028107:	8d 04 33             	lea    (%ebx,%esi,1),%eax
}
c002810a:	83 c4 2c             	add    $0x2c,%esp
c002810d:	5b                   	pop    %ebx
c002810e:	5e                   	pop    %esi
c002810f:	5f                   	pop    %edi
c0028110:	5d                   	pop    %ebp
c0028111:	c3                   	ret    
c0028112:	90                   	nop
c0028113:	90                   	nop
c0028114:	90                   	nop
c0028115:	90                   	nop
c0028116:	90                   	nop
c0028117:	90                   	nop
c0028118:	90                   	nop
c0028119:	90                   	nop
c002811a:	90                   	nop
c002811b:	90                   	nop
c002811c:	90                   	nop
c002811d:	90                   	nop
c002811e:	90                   	nop
c002811f:	90                   	nop

c0028120 <udiv64>:

/* Divides unsigned 64-bit N by unsigned 64-bit D and returns the
   quotient. */
static uint64_t
udiv64 (uint64_t n, uint64_t d)
{
c0028120:	55                   	push   %ebp
c0028121:	57                   	push   %edi
c0028122:	56                   	push   %esi
c0028123:	53                   	push   %ebx
c0028124:	83 ec 1c             	sub    $0x1c,%esp
c0028127:	89 04 24             	mov    %eax,(%esp)
c002812a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002812e:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0028132:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  if ((d >> 32) == 0) 
c0028136:	89 ea                	mov    %ebp,%edx
c0028138:	85 ed                	test   %ebp,%ebp
c002813a:	75 37                	jne    c0028173 <udiv64+0x53>
             <=> [b - 1/d] < b
         which is a tautology.

         Therefore, this code is correct and will not trap. */
      uint64_t b = 1ULL << 32;
      uint32_t n1 = n >> 32;
c002813c:	8b 44 24 04          	mov    0x4(%esp),%eax
      uint32_t n0 = n; 
      uint32_t d0 = d;

      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c0028140:	ba 00 00 00 00       	mov    $0x0,%edx
c0028145:	f7 f7                	div    %edi
c0028147:	89 c6                	mov    %eax,%esi
c0028149:	89 d3                	mov    %edx,%ebx
c002814b:	b9 00 00 00 00       	mov    $0x0,%ecx
c0028150:	8b 04 24             	mov    (%esp),%eax
c0028153:	ba 00 00 00 00       	mov    $0x0,%edx
c0028158:	01 c8                	add    %ecx,%eax
c002815a:	11 da                	adc    %ebx,%edx
  asm ("divl %4"
c002815c:	f7 f7                	div    %edi
      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c002815e:	ba 00 00 00 00       	mov    $0x0,%edx
c0028163:	89 f7                	mov    %esi,%edi
c0028165:	be 00 00 00 00       	mov    $0x0,%esi
c002816a:	01 f0                	add    %esi,%eax
c002816c:	11 fa                	adc    %edi,%edx
c002816e:	e9 f2 00 00 00       	jmp    c0028265 <udiv64+0x145>
    }
  else 
    {
      /* Based on the algorithm and proof available from
         http://www.hackersdelight.org/revisions.pdf. */
      if (n < d)
c0028173:	3b 6c 24 04          	cmp    0x4(%esp),%ebp
c0028177:	0f 87 d4 00 00 00    	ja     c0028251 <udiv64+0x131>
c002817d:	72 09                	jb     c0028188 <udiv64+0x68>
c002817f:	3b 3c 24             	cmp    (%esp),%edi
c0028182:	0f 87 c9 00 00 00    	ja     c0028251 <udiv64+0x131>
        return 0;
      else 
        {
          uint32_t d1 = d >> 32;
c0028188:	89 d0                	mov    %edx,%eax
  int n = 0;
c002818a:	b9 00 00 00 00       	mov    $0x0,%ecx
  if (x <= 0x0000FFFF)
c002818f:	81 fa ff ff 00 00    	cmp    $0xffff,%edx
c0028195:	77 05                	ja     c002819c <udiv64+0x7c>
      x <<= 16; 
c0028197:	c1 e0 10             	shl    $0x10,%eax
      n += 16;
c002819a:	b1 10                	mov    $0x10,%cl
  if (x <= 0x00FFFFFF)
c002819c:	3d ff ff ff 00       	cmp    $0xffffff,%eax
c00281a1:	77 06                	ja     c00281a9 <udiv64+0x89>
      n += 8;
c00281a3:	83 c1 08             	add    $0x8,%ecx
      x <<= 8; 
c00281a6:	c1 e0 08             	shl    $0x8,%eax
  if (x <= 0x0FFFFFFF)
c00281a9:	3d ff ff ff 0f       	cmp    $0xfffffff,%eax
c00281ae:	77 06                	ja     c00281b6 <udiv64+0x96>
      n += 4;
c00281b0:	83 c1 04             	add    $0x4,%ecx
      x <<= 4;
c00281b3:	c1 e0 04             	shl    $0x4,%eax
  if (x <= 0x3FFFFFFF)
c00281b6:	3d ff ff ff 3f       	cmp    $0x3fffffff,%eax
c00281bb:	77 06                	ja     c00281c3 <udiv64+0xa3>
      n += 2;
c00281bd:	83 c1 02             	add    $0x2,%ecx
      x <<= 2; 
c00281c0:	c1 e0 02             	shl    $0x2,%eax
    n++;
c00281c3:	3d 00 00 00 80       	cmp    $0x80000000,%eax
c00281c8:	83 d1 00             	adc    $0x0,%ecx
          int s = nlz (d1);
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c00281cb:	8b 04 24             	mov    (%esp),%eax
c00281ce:	8b 54 24 04          	mov    0x4(%esp),%edx
c00281d2:	0f ac d0 01          	shrd   $0x1,%edx,%eax
c00281d6:	d1 ea                	shr    %edx
c00281d8:	89 fb                	mov    %edi,%ebx
c00281da:	89 ee                	mov    %ebp,%esi
c00281dc:	0f a5 fe             	shld   %cl,%edi,%esi
c00281df:	d3 e3                	shl    %cl,%ebx
c00281e1:	f6 c1 20             	test   $0x20,%cl
c00281e4:	74 02                	je     c00281e8 <udiv64+0xc8>
c00281e6:	89 de                	mov    %ebx,%esi
c00281e8:	89 74 24 0c          	mov    %esi,0xc(%esp)
  asm ("divl %4"
c00281ec:	f7 74 24 0c          	divl   0xc(%esp)
c00281f0:	89 c6                	mov    %eax,%esi
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c00281f2:	b8 1f 00 00 00       	mov    $0x1f,%eax
c00281f7:	29 c8                	sub    %ecx,%eax
c00281f9:	89 c1                	mov    %eax,%ecx
c00281fb:	d3 ee                	shr    %cl,%esi
c00281fd:	89 74 24 10          	mov    %esi,0x10(%esp)
c0028201:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0028208:	00 
          return n - (q - 1) * d < d ? q - 1 : q; 
c0028209:	8b 44 24 10          	mov    0x10(%esp),%eax
c002820d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028211:	83 c0 ff             	add    $0xffffffff,%eax
c0028214:	83 d2 ff             	adc    $0xffffffff,%edx
c0028217:	89 44 24 08          	mov    %eax,0x8(%esp)
c002821b:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002821f:	89 c1                	mov    %eax,%ecx
c0028221:	0f af d7             	imul   %edi,%edx
c0028224:	0f af cd             	imul   %ebp,%ecx
c0028227:	8d 34 0a             	lea    (%edx,%ecx,1),%esi
c002822a:	8b 44 24 08          	mov    0x8(%esp),%eax
c002822e:	f7 e7                	mul    %edi
c0028230:	01 f2                	add    %esi,%edx
c0028232:	8b 1c 24             	mov    (%esp),%ebx
c0028235:	8b 74 24 04          	mov    0x4(%esp),%esi
c0028239:	29 c3                	sub    %eax,%ebx
c002823b:	19 d6                	sbb    %edx,%esi
c002823d:	39 f5                	cmp    %esi,%ebp
c002823f:	72 1c                	jb     c002825d <udiv64+0x13d>
c0028241:	77 04                	ja     c0028247 <udiv64+0x127>
c0028243:	39 df                	cmp    %ebx,%edi
c0028245:	76 16                	jbe    c002825d <udiv64+0x13d>
c0028247:	8b 44 24 08          	mov    0x8(%esp),%eax
c002824b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002824f:	eb 14                	jmp    c0028265 <udiv64+0x145>
        return 0;
c0028251:	b8 00 00 00 00       	mov    $0x0,%eax
c0028256:	ba 00 00 00 00       	mov    $0x0,%edx
c002825b:	eb 08                	jmp    c0028265 <udiv64+0x145>
          return n - (q - 1) * d < d ? q - 1 : q; 
c002825d:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028261:	8b 54 24 14          	mov    0x14(%esp),%edx
        }
    }
}
c0028265:	83 c4 1c             	add    $0x1c,%esp
c0028268:	5b                   	pop    %ebx
c0028269:	5e                   	pop    %esi
c002826a:	5f                   	pop    %edi
c002826b:	5d                   	pop    %ebp
c002826c:	c3                   	ret    

c002826d <sdiv64>:

/* Divides signed 64-bit N by signed 64-bit D and returns the
   quotient. */
static int64_t
sdiv64 (int64_t n, int64_t d)
{
c002826d:	57                   	push   %edi
c002826e:	56                   	push   %esi
c002826f:	53                   	push   %ebx
c0028270:	83 ec 10             	sub    $0x10,%esp
c0028273:	89 44 24 08          	mov    %eax,0x8(%esp)
c0028277:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002827b:	8b 74 24 20          	mov    0x20(%esp),%esi
c002827f:	8b 7c 24 24          	mov    0x24(%esp),%edi
  uint64_t n_abs = n >= 0 ? (uint64_t) n : -(uint64_t) n;
c0028283:	85 d2                	test   %edx,%edx
c0028285:	79 0f                	jns    c0028296 <sdiv64+0x29>
c0028287:	8b 44 24 08          	mov    0x8(%esp),%eax
c002828b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002828f:	f7 d8                	neg    %eax
c0028291:	83 d2 00             	adc    $0x0,%edx
c0028294:	f7 da                	neg    %edx
  uint64_t d_abs = d >= 0 ? (uint64_t) d : -(uint64_t) d;
c0028296:	85 ff                	test   %edi,%edi
c0028298:	78 06                	js     c00282a0 <sdiv64+0x33>
c002829a:	89 f1                	mov    %esi,%ecx
c002829c:	89 fb                	mov    %edi,%ebx
c002829e:	eb 0b                	jmp    c00282ab <sdiv64+0x3e>
c00282a0:	89 f1                	mov    %esi,%ecx
c00282a2:	89 fb                	mov    %edi,%ebx
c00282a4:	f7 d9                	neg    %ecx
c00282a6:	83 d3 00             	adc    $0x0,%ebx
c00282a9:	f7 db                	neg    %ebx
  uint64_t q_abs = udiv64 (n_abs, d_abs);
c00282ab:	89 0c 24             	mov    %ecx,(%esp)
c00282ae:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00282b2:	e8 69 fe ff ff       	call   c0028120 <udiv64>
  return (n < 0) == (d < 0) ? (int64_t) q_abs : -(int64_t) q_abs;
c00282b7:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
c00282bb:	f7 d1                	not    %ecx
c00282bd:	c1 e9 1f             	shr    $0x1f,%ecx
c00282c0:	89 fb                	mov    %edi,%ebx
c00282c2:	c1 eb 1f             	shr    $0x1f,%ebx
c00282c5:	89 c6                	mov    %eax,%esi
c00282c7:	89 d7                	mov    %edx,%edi
c00282c9:	f7 de                	neg    %esi
c00282cb:	83 d7 00             	adc    $0x0,%edi
c00282ce:	f7 df                	neg    %edi
c00282d0:	39 cb                	cmp    %ecx,%ebx
c00282d2:	74 04                	je     c00282d8 <sdiv64+0x6b>
c00282d4:	89 c6                	mov    %eax,%esi
c00282d6:	89 d7                	mov    %edx,%edi
}
c00282d8:	89 f0                	mov    %esi,%eax
c00282da:	89 fa                	mov    %edi,%edx
c00282dc:	83 c4 10             	add    $0x10,%esp
c00282df:	5b                   	pop    %ebx
c00282e0:	5e                   	pop    %esi
c00282e1:	5f                   	pop    %edi
c00282e2:	c3                   	ret    

c00282e3 <__divdi3>:
unsigned long long __umoddi3 (unsigned long long n, unsigned long long d);

/* Signed 64-bit division. */
long long
__divdi3 (long long n, long long d) 
{
c00282e3:	83 ec 0c             	sub    $0xc,%esp
  return sdiv64 (n, d);
c00282e6:	8b 44 24 18          	mov    0x18(%esp),%eax
c00282ea:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00282ee:	89 04 24             	mov    %eax,(%esp)
c00282f1:	89 54 24 04          	mov    %edx,0x4(%esp)
c00282f5:	8b 44 24 10          	mov    0x10(%esp),%eax
c00282f9:	8b 54 24 14          	mov    0x14(%esp),%edx
c00282fd:	e8 6b ff ff ff       	call   c002826d <sdiv64>
}
c0028302:	83 c4 0c             	add    $0xc,%esp
c0028305:	c3                   	ret    

c0028306 <__moddi3>:

/* Signed 64-bit remainder. */
long long
__moddi3 (long long n, long long d) 
{
c0028306:	56                   	push   %esi
c0028307:	53                   	push   %ebx
c0028308:	83 ec 0c             	sub    $0xc,%esp
c002830b:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c002830f:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * sdiv64 (n, d);
c0028313:	89 34 24             	mov    %esi,(%esp)
c0028316:	8b 44 24 24          	mov    0x24(%esp),%eax
c002831a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002831e:	89 d8                	mov    %ebx,%eax
c0028320:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028324:	e8 44 ff ff ff       	call   c002826d <sdiv64>
c0028329:	0f af f0             	imul   %eax,%esi
c002832c:	89 d8                	mov    %ebx,%eax
c002832e:	29 f0                	sub    %esi,%eax
  return smod64 (n, d);
c0028330:	99                   	cltd   
}
c0028331:	83 c4 0c             	add    $0xc,%esp
c0028334:	5b                   	pop    %ebx
c0028335:	5e                   	pop    %esi
c0028336:	c3                   	ret    

c0028337 <__udivdi3>:

/* Unsigned 64-bit division. */
unsigned long long
__udivdi3 (unsigned long long n, unsigned long long d) 
{
c0028337:	83 ec 0c             	sub    $0xc,%esp
  return udiv64 (n, d);
c002833a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002833e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028342:	89 04 24             	mov    %eax,(%esp)
c0028345:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028349:	8b 44 24 10          	mov    0x10(%esp),%eax
c002834d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028351:	e8 ca fd ff ff       	call   c0028120 <udiv64>
}
c0028356:	83 c4 0c             	add    $0xc,%esp
c0028359:	c3                   	ret    

c002835a <__umoddi3>:

/* Unsigned 64-bit remainder. */
unsigned long long
__umoddi3 (unsigned long long n, unsigned long long d) 
{
c002835a:	56                   	push   %esi
c002835b:	53                   	push   %ebx
c002835c:	83 ec 0c             	sub    $0xc,%esp
c002835f:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c0028363:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * udiv64 (n, d);
c0028367:	89 34 24             	mov    %esi,(%esp)
c002836a:	8b 44 24 24          	mov    0x24(%esp),%eax
c002836e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028372:	89 d8                	mov    %ebx,%eax
c0028374:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028378:	e8 a3 fd ff ff       	call   c0028120 <udiv64>
c002837d:	0f af f0             	imul   %eax,%esi
c0028380:	89 d8                	mov    %ebx,%eax
c0028382:	29 f0                	sub    %esi,%eax
  return umod64 (n, d);
c0028384:	ba 00 00 00 00       	mov    $0x0,%edx
}
c0028389:	83 c4 0c             	add    $0xc,%esp
c002838c:	5b                   	pop    %ebx
c002838d:	5e                   	pop    %esi
c002838e:	c3                   	ret    

c002838f <parse_octal_field>:
   seems ambiguous as to whether these fields must be padded on
   the left with '0's, so we accept any field that fits in the
   available space, regardless of whether it fills the space. */
static bool
parse_octal_field (const char *s, size_t size, unsigned long int *value)
{
c002838f:	55                   	push   %ebp
c0028390:	57                   	push   %edi
c0028391:	56                   	push   %esi
c0028392:	53                   	push   %ebx
c0028393:	83 ec 04             	sub    $0x4,%esp
c0028396:	89 04 24             	mov    %eax,(%esp)
c0028399:	89 d5                	mov    %edx,%ebp
  size_t ofs;

  *value = 0;
c002839b:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
          return false;
        }
    }

  /* Field did not end in space or null byte. */
  return false;
c00283a1:	b8 00 00 00 00       	mov    $0x0,%eax
  for (ofs = 0; ofs < size; ofs++)
c00283a6:	85 d2                	test   %edx,%edx
c00283a8:	74 66                	je     c0028410 <parse_octal_field+0x81>
c00283aa:	eb 45                	jmp    c00283f1 <parse_octal_field+0x62>
      char c = s[ofs];
c00283ac:	8b 04 24             	mov    (%esp),%eax
c00283af:	0f b6 14 18          	movzbl (%eax,%ebx,1),%edx
      if (c >= '0' && c <= '7')
c00283b3:	8d 7a d0             	lea    -0x30(%edx),%edi
c00283b6:	89 f8                	mov    %edi,%eax
c00283b8:	3c 07                	cmp    $0x7,%al
c00283ba:	77 24                	ja     c00283e0 <parse_octal_field+0x51>
          if (*value > ULONG_MAX / 8)
c00283bc:	81 fe ff ff ff 1f    	cmp    $0x1fffffff,%esi
c00283c2:	77 47                	ja     c002840b <parse_octal_field+0x7c>
          *value = c - '0' + *value * 8;
c00283c4:	0f be fa             	movsbl %dl,%edi
c00283c7:	8d 74 f7 d0          	lea    -0x30(%edi,%esi,8),%esi
c00283cb:	89 31                	mov    %esi,(%ecx)
  for (ofs = 0; ofs < size; ofs++)
c00283cd:	83 c3 01             	add    $0x1,%ebx
c00283d0:	39 eb                	cmp    %ebp,%ebx
c00283d2:	75 d8                	jne    c00283ac <parse_octal_field+0x1d>
  return false;
c00283d4:	b8 00 00 00 00       	mov    $0x0,%eax
c00283d9:	eb 35                	jmp    c0028410 <parse_octal_field+0x81>
  for (ofs = 0; ofs < size; ofs++)
c00283db:	bb 00 00 00 00       	mov    $0x0,%ebx
          return false;
c00283e0:	b8 00 00 00 00       	mov    $0x0,%eax
      else if (c == ' ' || c == '\0')
c00283e5:	f6 c2 df             	test   $0xdf,%dl
c00283e8:	75 26                	jne    c0028410 <parse_octal_field+0x81>
          return ofs > 0;
c00283ea:	85 db                	test   %ebx,%ebx
c00283ec:	0f 95 c0             	setne  %al
c00283ef:	eb 1f                	jmp    c0028410 <parse_octal_field+0x81>
      char c = s[ofs];
c00283f1:	8b 04 24             	mov    (%esp),%eax
c00283f4:	0f b6 10             	movzbl (%eax),%edx
      if (c >= '0' && c <= '7')
c00283f7:	8d 5a d0             	lea    -0x30(%edx),%ebx
c00283fa:	80 fb 07             	cmp    $0x7,%bl
c00283fd:	77 dc                	ja     c00283db <parse_octal_field+0x4c>
          if (*value > ULONG_MAX / 8)
c00283ff:	be 00 00 00 00       	mov    $0x0,%esi
  for (ofs = 0; ofs < size; ofs++)
c0028404:	bb 00 00 00 00       	mov    $0x0,%ebx
c0028409:	eb b9                	jmp    c00283c4 <parse_octal_field+0x35>
              return false;
c002840b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028410:	83 c4 04             	add    $0x4,%esp
c0028413:	5b                   	pop    %ebx
c0028414:	5e                   	pop    %esi
c0028415:	5f                   	pop    %edi
c0028416:	5d                   	pop    %ebp
c0028417:	c3                   	ret    

c0028418 <strip_antisocial_prefixes>:
{
c0028418:	57                   	push   %edi
c0028419:	56                   	push   %esi
c002841a:	53                   	push   %ebx
c002841b:	83 ec 10             	sub    $0x10,%esp
c002841e:	89 c3                	mov    %eax,%ebx
  while (*file_name == '/'
c0028420:	eb 13                	jmp    c0028435 <strip_antisocial_prefixes+0x1d>
    file_name = strchr (file_name, '/') + 1;
c0028422:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0028429:	00 
c002842a:	89 1c 24             	mov    %ebx,(%esp)
c002842d:	e8 84 f7 ff ff       	call   c0027bb6 <strchr>
c0028432:	8d 58 01             	lea    0x1(%eax),%ebx
  while (*file_name == '/'
c0028435:	0f b6 33             	movzbl (%ebx),%esi
c0028438:	89 f0                	mov    %esi,%eax
c002843a:	3c 2f                	cmp    $0x2f,%al
c002843c:	74 e4                	je     c0028422 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "./", 2)
c002843e:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
c0028445:	00 
c0028446:	c7 44 24 04 e5 ed 02 	movl   $0xc002ede5,0x4(%esp)
c002844d:	c0 
c002844e:	89 1c 24             	mov    %ebx,(%esp)
c0028451:	e8 77 f5 ff ff       	call   c00279cd <memcmp>
c0028456:	85 c0                	test   %eax,%eax
c0028458:	74 c8                	je     c0028422 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "../", 3))
c002845a:	c7 44 24 08 03 00 00 	movl   $0x3,0x8(%esp)
c0028461:	00 
c0028462:	c7 44 24 04 4d fa 02 	movl   $0xc002fa4d,0x4(%esp)
c0028469:	c0 
c002846a:	89 1c 24             	mov    %ebx,(%esp)
c002846d:	e8 5b f5 ff ff       	call   c00279cd <memcmp>
c0028472:	85 c0                	test   %eax,%eax
c0028474:	74 ac                	je     c0028422 <strip_antisocial_prefixes+0xa>
  return *file_name == '\0' || !strcmp (file_name, "..") ? "." : file_name;
c0028476:	b8 6b f3 02 c0       	mov    $0xc002f36b,%eax
c002847b:	89 f2                	mov    %esi,%edx
c002847d:	84 d2                	test   %dl,%dl
c002847f:	74 23                	je     c00284a4 <strip_antisocial_prefixes+0x8c>
c0028481:	bf 6a f3 02 c0       	mov    $0xc002f36a,%edi
c0028486:	b9 03 00 00 00       	mov    $0x3,%ecx
c002848b:	89 de                	mov    %ebx,%esi
c002848d:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c002848f:	0f 97 c0             	seta   %al
c0028492:	0f 92 c2             	setb   %dl
c0028495:	29 d0                	sub    %edx,%eax
c0028497:	0f be c0             	movsbl %al,%eax
c002849a:	85 c0                	test   %eax,%eax
c002849c:	b8 6b f3 02 c0       	mov    $0xc002f36b,%eax
c00284a1:	0f 45 c3             	cmovne %ebx,%eax
}
c00284a4:	83 c4 10             	add    $0x10,%esp
c00284a7:	5b                   	pop    %ebx
c00284a8:	5e                   	pop    %esi
c00284a9:	5f                   	pop    %edi
c00284aa:	c3                   	ret    

c00284ab <ustar_make_header>:
{
c00284ab:	55                   	push   %ebp
c00284ac:	57                   	push   %edi
c00284ad:	56                   	push   %esi
c00284ae:	53                   	push   %ebx
c00284af:	83 ec 2c             	sub    $0x2c,%esp
c00284b2:	8b 5c 24 4c          	mov    0x4c(%esp),%ebx
  ASSERT (type == USTAR_REGULAR || type == USTAR_DIRECTORY);
c00284b6:	83 7c 24 44 30       	cmpl   $0x30,0x44(%esp)
c00284bb:	0f 94 c0             	sete   %al
c00284be:	89 c6                	mov    %eax,%esi
c00284c0:	88 44 24 1f          	mov    %al,0x1f(%esp)
c00284c4:	83 7c 24 44 35       	cmpl   $0x35,0x44(%esp)
c00284c9:	0f 94 c0             	sete   %al
c00284cc:	89 f2                	mov    %esi,%edx
c00284ce:	08 d0                	or     %dl,%al
c00284d0:	75 2c                	jne    c00284fe <ustar_make_header+0x53>
c00284d2:	c7 44 24 10 38 fb 02 	movl   $0xc002fb38,0x10(%esp)
c00284d9:	c0 
c00284da:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00284e1:	c0 
c00284e2:	c7 44 24 08 80 dc 02 	movl   $0xc002dc80,0x8(%esp)
c00284e9:	c0 
c00284ea:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c00284f1:	00 
c00284f2:	c7 04 24 51 fa 02 c0 	movl   $0xc002fa51,(%esp)
c00284f9:	e8 85 04 00 00       	call   c0028983 <debug_panic>
c00284fe:	89 c5                	mov    %eax,%ebp
  file_name = strip_antisocial_prefixes (file_name);
c0028500:	8b 44 24 40          	mov    0x40(%esp),%eax
c0028504:	e8 0f ff ff ff       	call   c0028418 <strip_antisocial_prefixes>
c0028509:	89 c2                	mov    %eax,%edx
  if (strlen (file_name) > 99)
c002850b:	89 c7                	mov    %eax,%edi
c002850d:	b8 00 00 00 00       	mov    $0x0,%eax
c0028512:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028517:	f2 ae                	repnz scas %es:(%edi),%al
c0028519:	f7 d1                	not    %ecx
c002851b:	83 e9 01             	sub    $0x1,%ecx
c002851e:	83 f9 63             	cmp    $0x63,%ecx
c0028521:	76 1a                	jbe    c002853d <ustar_make_header+0x92>
      printf ("%s: file name too long\n", file_name);
c0028523:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028527:	c7 04 24 63 fa 02 c0 	movl   $0xc002fa63,(%esp)
c002852e:	e8 fb e5 ff ff       	call   c0026b2e <printf>
      return false;
c0028533:	bd 00 00 00 00       	mov    $0x0,%ebp
c0028538:	e9 d0 01 00 00       	jmp    c002870d <ustar_make_header+0x262>
  memset (h, 0, sizeof *h);
c002853d:	89 df                	mov    %ebx,%edi
c002853f:	be 00 02 00 00       	mov    $0x200,%esi
c0028544:	f6 c3 01             	test   $0x1,%bl
c0028547:	74 0a                	je     c0028553 <ustar_make_header+0xa8>
c0028549:	c6 03 00             	movb   $0x0,(%ebx)
c002854c:	8d 7b 01             	lea    0x1(%ebx),%edi
c002854f:	66 be ff 01          	mov    $0x1ff,%si
c0028553:	f7 c7 02 00 00 00    	test   $0x2,%edi
c0028559:	74 0b                	je     c0028566 <ustar_make_header+0xbb>
c002855b:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0028560:	83 c7 02             	add    $0x2,%edi
c0028563:	83 ee 02             	sub    $0x2,%esi
c0028566:	89 f1                	mov    %esi,%ecx
c0028568:	c1 e9 02             	shr    $0x2,%ecx
c002856b:	b8 00 00 00 00       	mov    $0x0,%eax
c0028570:	f3 ab                	rep stos %eax,%es:(%edi)
c0028572:	f7 c6 02 00 00 00    	test   $0x2,%esi
c0028578:	74 08                	je     c0028582 <ustar_make_header+0xd7>
c002857a:	66 c7 07 00 00       	movw   $0x0,(%edi)
c002857f:	83 c7 02             	add    $0x2,%edi
c0028582:	f7 c6 01 00 00 00    	test   $0x1,%esi
c0028588:	74 03                	je     c002858d <ustar_make_header+0xe2>
c002858a:	c6 07 00             	movb   $0x0,(%edi)
  strlcpy (h->name, file_name, sizeof h->name);
c002858d:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0028594:	00 
c0028595:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028599:	89 1c 24             	mov    %ebx,(%esp)
c002859c:	e8 f5 f9 ff ff       	call   c0027f96 <strlcpy>
  snprintf (h->mode, sizeof h->mode, "%07o",
c00285a1:	80 7c 24 1f 01       	cmpb   $0x1,0x1f(%esp)
c00285a6:	19 c0                	sbb    %eax,%eax
c00285a8:	83 e0 49             	and    $0x49,%eax
c00285ab:	05 a4 01 00 00       	add    $0x1a4,%eax
c00285b0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00285b4:	c7 44 24 08 7b fa 02 	movl   $0xc002fa7b,0x8(%esp)
c00285bb:	c0 
c00285bc:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c00285c3:	00 
c00285c4:	8d 43 64             	lea    0x64(%ebx),%eax
c00285c7:	89 04 24             	mov    %eax,(%esp)
c00285ca:	e8 60 ec ff ff       	call   c002722f <snprintf>
  strlcpy (h->uid, "0000000", sizeof h->uid);
c00285cf:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c00285d6:	00 
c00285d7:	c7 44 24 04 80 fa 02 	movl   $0xc002fa80,0x4(%esp)
c00285de:	c0 
c00285df:	8d 43 6c             	lea    0x6c(%ebx),%eax
c00285e2:	89 04 24             	mov    %eax,(%esp)
c00285e5:	e8 ac f9 ff ff       	call   c0027f96 <strlcpy>
  strlcpy (h->gid, "0000000", sizeof h->gid);
c00285ea:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c00285f1:	00 
c00285f2:	c7 44 24 04 80 fa 02 	movl   $0xc002fa80,0x4(%esp)
c00285f9:	c0 
c00285fa:	8d 43 74             	lea    0x74(%ebx),%eax
c00285fd:	89 04 24             	mov    %eax,(%esp)
c0028600:	e8 91 f9 ff ff       	call   c0027f96 <strlcpy>
  snprintf (h->size, sizeof h->size, "%011o", size);
c0028605:	8b 44 24 48          	mov    0x48(%esp),%eax
c0028609:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002860d:	c7 44 24 08 88 fa 02 	movl   $0xc002fa88,0x8(%esp)
c0028614:	c0 
c0028615:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002861c:	00 
c002861d:	8d 43 7c             	lea    0x7c(%ebx),%eax
c0028620:	89 04 24             	mov    %eax,(%esp)
c0028623:	e8 07 ec ff ff       	call   c002722f <snprintf>
  snprintf (h->mtime, sizeof h->size, "%011o", 1136102400);
c0028628:	c7 44 24 0c 00 8c b7 	movl   $0x43b78c00,0xc(%esp)
c002862f:	43 
c0028630:	c7 44 24 08 88 fa 02 	movl   $0xc002fa88,0x8(%esp)
c0028637:	c0 
c0028638:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002863f:	00 
c0028640:	8d 83 88 00 00 00    	lea    0x88(%ebx),%eax
c0028646:	89 04 24             	mov    %eax,(%esp)
c0028649:	e8 e1 eb ff ff       	call   c002722f <snprintf>
  h->typeflag = type;
c002864e:	0f b6 44 24 44       	movzbl 0x44(%esp),%eax
c0028653:	88 83 9c 00 00 00    	mov    %al,0x9c(%ebx)
  strlcpy (h->magic, "ustar", sizeof h->magic);
c0028659:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028660:	00 
c0028661:	c7 44 24 04 8e fa 02 	movl   $0xc002fa8e,0x4(%esp)
c0028668:	c0 
c0028669:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002866f:	89 04 24             	mov    %eax,(%esp)
c0028672:	e8 1f f9 ff ff       	call   c0027f96 <strlcpy>
  h->version[0] = h->version[1] = '0';
c0028677:	c6 83 08 01 00 00 30 	movb   $0x30,0x108(%ebx)
c002867e:	c6 83 07 01 00 00 30 	movb   $0x30,0x107(%ebx)
  strlcpy (h->gname, "root", sizeof h->gname);
c0028685:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c002868c:	00 
c002868d:	c7 44 24 04 9c ef 02 	movl   $0xc002ef9c,0x4(%esp)
c0028694:	c0 
c0028695:	8d 83 29 01 00 00    	lea    0x129(%ebx),%eax
c002869b:	89 04 24             	mov    %eax,(%esp)
c002869e:	e8 f3 f8 ff ff       	call   c0027f96 <strlcpy>
  strlcpy (h->uname, "root", sizeof h->uname);
c00286a3:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c00286aa:	00 
c00286ab:	c7 44 24 04 9c ef 02 	movl   $0xc002ef9c,0x4(%esp)
c00286b2:	c0 
c00286b3:	8d 83 09 01 00 00    	lea    0x109(%ebx),%eax
c00286b9:	89 04 24             	mov    %eax,(%esp)
c00286bc:	e8 d5 f8 ff ff       	call   c0027f96 <strlcpy>
c00286c1:	b8 6c ff ff ff       	mov    $0xffffff6c,%eax
  chksum = 0;
c00286c6:	ba 00 00 00 00       	mov    $0x0,%edx
      chksum += in_chksum_field ? ' ' : header[i];
c00286cb:	83 f8 07             	cmp    $0x7,%eax
c00286ce:	76 0a                	jbe    c00286da <ustar_make_header+0x22f>
c00286d0:	0f b6 8c 03 94 00 00 	movzbl 0x94(%ebx,%eax,1),%ecx
c00286d7:	00 
c00286d8:	eb 05                	jmp    c00286df <ustar_make_header+0x234>
c00286da:	b9 20 00 00 00       	mov    $0x20,%ecx
c00286df:	01 ca                	add    %ecx,%edx
c00286e1:	83 c0 01             	add    $0x1,%eax
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c00286e4:	3d 6c 01 00 00       	cmp    $0x16c,%eax
c00286e9:	75 e0                	jne    c00286cb <ustar_make_header+0x220>
  snprintf (h->chksum, sizeof h->chksum, "%07o", calculate_chksum (h));
c00286eb:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00286ef:	c7 44 24 08 7b fa 02 	movl   $0xc002fa7b,0x8(%esp)
c00286f6:	c0 
c00286f7:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c00286fe:	00 
c00286ff:	81 c3 94 00 00 00    	add    $0x94,%ebx
c0028705:	89 1c 24             	mov    %ebx,(%esp)
c0028708:	e8 22 eb ff ff       	call   c002722f <snprintf>
}
c002870d:	89 e8                	mov    %ebp,%eax
c002870f:	83 c4 2c             	add    $0x2c,%esp
c0028712:	5b                   	pop    %ebx
c0028713:	5e                   	pop    %esi
c0028714:	5f                   	pop    %edi
c0028715:	5d                   	pop    %ebp
c0028716:	c3                   	ret    

c0028717 <ustar_parse_header>:
   and returns a null pointer.  On failure, returns a
   human-readable error message. */
const char *
ustar_parse_header (const char header[USTAR_HEADER_SIZE],
                    const char **file_name, enum ustar_type *type, int *size)
{
c0028717:	53                   	push   %ebx
c0028718:	83 ec 28             	sub    $0x28,%esp
c002871b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002871f:	8d 8b 00 02 00 00    	lea    0x200(%ebx),%ecx
c0028725:	89 da                	mov    %ebx,%edx
    if (*block++ != 0)
c0028727:	83 c2 01             	add    $0x1,%edx
c002872a:	80 7a ff 00          	cmpb   $0x0,-0x1(%edx)
c002872e:	0f 85 25 01 00 00    	jne    c0028859 <ustar_parse_header+0x142>
  while (cnt-- > 0)
c0028734:	39 ca                	cmp    %ecx,%edx
c0028736:	75 ef                	jne    c0028727 <ustar_parse_header+0x10>
c0028738:	e9 4b 01 00 00       	jmp    c0028888 <ustar_parse_header+0x171>

  /* Validate ustar header. */
  if (memcmp (h->magic, "ustar", 6))
    return "not a ustar archive";
  else if (h->version[0] != '0' || h->version[1] != '0')
    return "invalid ustar version";
c002873d:	b8 a8 fa 02 c0       	mov    $0xc002faa8,%eax
  else if (h->version[0] != '0' || h->version[1] != '0')
c0028742:	80 bb 07 01 00 00 30 	cmpb   $0x30,0x107(%ebx)
c0028749:	0f 85 5c 01 00 00    	jne    c00288ab <ustar_parse_header+0x194>
c002874f:	80 bb 08 01 00 00 30 	cmpb   $0x30,0x108(%ebx)
c0028756:	0f 85 4f 01 00 00    	jne    c00288ab <ustar_parse_header+0x194>
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c002875c:	8d 83 94 00 00 00    	lea    0x94(%ebx),%eax
c0028762:	8d 4c 24 1c          	lea    0x1c(%esp),%ecx
c0028766:	ba 08 00 00 00       	mov    $0x8,%edx
c002876b:	e8 1f fc ff ff       	call   c002838f <parse_octal_field>
c0028770:	89 c2                	mov    %eax,%edx
    return "corrupt chksum field";
c0028772:	b8 be fa 02 c0       	mov    $0xc002fabe,%eax
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c0028777:	84 d2                	test   %dl,%dl
c0028779:	0f 84 2c 01 00 00    	je     c00288ab <ustar_parse_header+0x194>
c002877f:	ba 6c ff ff ff       	mov    $0xffffff6c,%edx
c0028784:	b9 00 00 00 00       	mov    $0x0,%ecx
      chksum += in_chksum_field ? ' ' : header[i];
c0028789:	83 fa 07             	cmp    $0x7,%edx
c002878c:	76 0a                	jbe    c0028798 <ustar_parse_header+0x81>
c002878e:	0f b6 84 13 94 00 00 	movzbl 0x94(%ebx,%edx,1),%eax
c0028795:	00 
c0028796:	eb 05                	jmp    c002879d <ustar_parse_header+0x86>
c0028798:	b8 20 00 00 00       	mov    $0x20,%eax
c002879d:	01 c1                	add    %eax,%ecx
c002879f:	83 c2 01             	add    $0x1,%edx
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c00287a2:	81 fa 6c 01 00 00    	cmp    $0x16c,%edx
c00287a8:	75 df                	jne    c0028789 <ustar_parse_header+0x72>
  else if (chksum != calculate_chksum (h))
    return "checksum mismatch";
c00287aa:	b8 d3 fa 02 c0       	mov    $0xc002fad3,%eax
  else if (chksum != calculate_chksum (h))
c00287af:	39 4c 24 1c          	cmp    %ecx,0x1c(%esp)
c00287b3:	0f 85 f2 00 00 00    	jne    c00288ab <ustar_parse_header+0x194>
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
    return "file name too long";
c00287b9:	b8 e5 fa 02 c0       	mov    $0xc002fae5,%eax
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
c00287be:	80 7b 63 00          	cmpb   $0x0,0x63(%ebx)
c00287c2:	0f 85 e3 00 00 00    	jne    c00288ab <ustar_parse_header+0x194>
c00287c8:	80 bb 59 01 00 00 00 	cmpb   $0x0,0x159(%ebx)
c00287cf:	0f 85 d6 00 00 00    	jne    c00288ab <ustar_parse_header+0x194>
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c00287d5:	0f b6 93 9c 00 00 00 	movzbl 0x9c(%ebx),%edx
c00287dc:	80 fa 35             	cmp    $0x35,%dl
c00287df:	74 0e                	je     c00287ef <ustar_parse_header+0xd8>
    return "unimplemented file type";
c00287e1:	b8 f8 fa 02 c0       	mov    $0xc002faf8,%eax
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c00287e6:	80 fa 30             	cmp    $0x30,%dl
c00287e9:	0f 85 bc 00 00 00    	jne    c00288ab <ustar_parse_header+0x194>
  if (h->typeflag == USTAR_REGULAR)
c00287ef:	80 fa 30             	cmp    $0x30,%dl
c00287f2:	75 32                	jne    c0028826 <ustar_parse_header+0x10f>
    {
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c00287f4:	8d 43 7c             	lea    0x7c(%ebx),%eax
c00287f7:	8d 4c 24 18          	lea    0x18(%esp),%ecx
c00287fb:	ba 0c 00 00 00       	mov    $0xc,%edx
c0028800:	e8 8a fb ff ff       	call   c002838f <parse_octal_field>
c0028805:	89 c2                	mov    %eax,%edx
        return "corrupt file size field";
c0028807:	b8 10 fb 02 c0       	mov    $0xc002fb10,%eax
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c002880c:	84 d2                	test   %dl,%dl
c002880e:	0f 84 97 00 00 00    	je     c00288ab <ustar_parse_header+0x194>
      else if (size_ul > INT_MAX)
        return "file too large";
c0028814:	b8 28 fb 02 c0       	mov    $0xc002fb28,%eax
      else if (size_ul > INT_MAX)
c0028819:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c002881e:	0f 88 87 00 00 00    	js     c00288ab <ustar_parse_header+0x194>
c0028824:	eb 08                	jmp    c002882e <ustar_parse_header+0x117>
    }
  else
    size_ul = 0;
c0028826:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c002882d:	00 

  /* Success. */
  *file_name = strip_antisocial_prefixes (h->name);
c002882e:	89 d8                	mov    %ebx,%eax
c0028830:	e8 e3 fb ff ff       	call   c0028418 <strip_antisocial_prefixes>
c0028835:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0028839:	89 01                	mov    %eax,(%ecx)
  *type = h->typeflag;
c002883b:	0f be 83 9c 00 00 00 	movsbl 0x9c(%ebx),%eax
c0028842:	8b 5c 24 38          	mov    0x38(%esp),%ebx
c0028846:	89 03                	mov    %eax,(%ebx)
  *size = size_ul;
c0028848:	8b 44 24 18          	mov    0x18(%esp),%eax
c002884c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
c0028850:	89 03                	mov    %eax,(%ebx)
  return NULL;
c0028852:	b8 00 00 00 00       	mov    $0x0,%eax
c0028857:	eb 52                	jmp    c00288ab <ustar_parse_header+0x194>
  if (memcmp (h->magic, "ustar", 6))
c0028859:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028860:	00 
c0028861:	c7 44 24 04 8e fa 02 	movl   $0xc002fa8e,0x4(%esp)
c0028868:	c0 
c0028869:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002886f:	89 04 24             	mov    %eax,(%esp)
c0028872:	e8 56 f1 ff ff       	call   c00279cd <memcmp>
c0028877:	89 c2                	mov    %eax,%edx
    return "not a ustar archive";
c0028879:	b8 94 fa 02 c0       	mov    $0xc002fa94,%eax
  if (memcmp (h->magic, "ustar", 6))
c002887e:	85 d2                	test   %edx,%edx
c0028880:	0f 84 b7 fe ff ff    	je     c002873d <ustar_parse_header+0x26>
c0028886:	eb 23                	jmp    c00288ab <ustar_parse_header+0x194>
      *file_name = NULL;
c0028888:	8b 44 24 34          	mov    0x34(%esp),%eax
c002888c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      *type = USTAR_EOF;
c0028892:	8b 44 24 38          	mov    0x38(%esp),%eax
c0028896:	c7 00 ff ff ff ff    	movl   $0xffffffff,(%eax)
      *size = 0;
c002889c:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c00288a0:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      return NULL;
c00288a6:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00288ab:	83 c4 28             	add    $0x28,%esp
c00288ae:	5b                   	pop    %ebx
c00288af:	c3                   	ret    

c00288b0 <print_stacktrace>:

/* Print call stack of a thread.
   The thread may be running, ready, or blocked. */
static void
print_stacktrace(struct thread *t, void *aux UNUSED)
{
c00288b0:	55                   	push   %ebp
c00288b1:	89 e5                	mov    %esp,%ebp
c00288b3:	53                   	push   %ebx
c00288b4:	83 ec 14             	sub    $0x14,%esp
c00288b7:	8b 5d 08             	mov    0x8(%ebp),%ebx
  void *retaddr = NULL, **frame = NULL;
  const char *status = "UNKNOWN";

  switch (t->status) {
c00288ba:	8b 43 04             	mov    0x4(%ebx),%eax
    case THREAD_RUNNING:  
      status = "RUNNING";
      break;

    case THREAD_READY:  
      status = "READY";
c00288bd:	ba 69 fb 02 c0       	mov    $0xc002fb69,%edx
  switch (t->status) {
c00288c2:	83 f8 01             	cmp    $0x1,%eax
c00288c5:	74 1a                	je     c00288e1 <print_stacktrace+0x31>
      status = "RUNNING";
c00288c7:	ba 89 e5 02 c0       	mov    $0xc002e589,%edx
  switch (t->status) {
c00288cc:	83 f8 01             	cmp    $0x1,%eax
c00288cf:	72 10                	jb     c00288e1 <print_stacktrace+0x31>
c00288d1:	83 f8 02             	cmp    $0x2,%eax
  const char *status = "UNKNOWN";
c00288d4:	b8 6f fb 02 c0       	mov    $0xc002fb6f,%eax
c00288d9:	ba 43 e5 02 c0       	mov    $0xc002e543,%edx
c00288de:	0f 45 d0             	cmovne %eax,%edx

    default:
      break;
  }

  printf ("Call stack of thread `%s' (status %s):", t->name, status);
c00288e1:	89 54 24 08          	mov    %edx,0x8(%esp)
c00288e5:	8d 43 08             	lea    0x8(%ebx),%eax
c00288e8:	89 44 24 04          	mov    %eax,0x4(%esp)
c00288ec:	c7 04 24 94 fb 02 c0 	movl   $0xc002fb94,(%esp)
c00288f3:	e8 36 e2 ff ff       	call   c0026b2e <printf>

  if (t == thread_current()) 
c00288f8:	e8 dc 84 ff ff       	call   c0020dd9 <thread_current>
c00288fd:	39 d8                	cmp    %ebx,%eax
c00288ff:	75 08                	jne    c0028909 <print_stacktrace+0x59>
    {
      frame = __builtin_frame_address (1);
c0028901:	8b 5d 00             	mov    0x0(%ebp),%ebx
      retaddr = __builtin_return_address (0);
c0028904:	8b 55 04             	mov    0x4(%ebp),%edx
c0028907:	eb 29                	jmp    c0028932 <print_stacktrace+0x82>
    {
      /* Retrieve the values of the base and instruction pointers
         as they were saved when this thread called switch_threads. */
      struct switch_threads_frame * saved_frame;

      saved_frame = (struct switch_threads_frame *)t->stack;
c0028909:	8b 43 18             	mov    0x18(%ebx),%eax
         list, but have never been scheduled.
         We can identify because their `stack' member either points 
         at the top of their kernel stack page, or the 
         switch_threads_frame's 'eip' member points at switch_entry.
         See also threads.c. */
      if (t->stack == (uint8_t *)t + PGSIZE || saved_frame->eip == switch_entry)
c002890c:	81 c3 00 10 00 00    	add    $0x1000,%ebx
c0028912:	39 d8                	cmp    %ebx,%eax
c0028914:	74 0b                	je     c0028921 <print_stacktrace+0x71>
c0028916:	8b 50 10             	mov    0x10(%eax),%edx
c0028919:	81 fa 07 18 02 c0    	cmp    $0xc0021807,%edx
c002891f:	75 0e                	jne    c002892f <print_stacktrace+0x7f>
        {
          printf (" thread was never scheduled.\n");
c0028921:	c7 04 24 77 fb 02 c0 	movl   $0xc002fb77,(%esp)
c0028928:	e8 7e 1d 00 00       	call   c002a6ab <puts>
          return;
c002892d:	eb 4e                	jmp    c002897d <print_stacktrace+0xcd>
        }

      frame = (void **) saved_frame->ebp;
c002892f:	8b 58 08             	mov    0x8(%eax),%ebx
      retaddr = (void *) saved_frame->eip;
    }

  printf (" %p", retaddr);
c0028932:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028936:	c7 04 24 d4 f7 02 c0 	movl   $0xc002f7d4,(%esp)
c002893d:	e8 ec e1 ff ff       	call   c0026b2e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028942:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0028948:	76 27                	jbe    c0028971 <print_stacktrace+0xc1>
c002894a:	83 3b 00             	cmpl   $0x0,(%ebx)
c002894d:	74 22                	je     c0028971 <print_stacktrace+0xc1>
    printf (" %p", frame[1]);
c002894f:	8b 43 04             	mov    0x4(%ebx),%eax
c0028952:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028956:	c7 04 24 d4 f7 02 c0 	movl   $0xc002f7d4,(%esp)
c002895d:	e8 cc e1 ff ff       	call   c0026b2e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028962:	8b 1b                	mov    (%ebx),%ebx
c0028964:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c002896a:	76 05                	jbe    c0028971 <print_stacktrace+0xc1>
c002896c:	83 3b 00             	cmpl   $0x0,(%ebx)
c002896f:	75 de                	jne    c002894f <print_stacktrace+0x9f>
  printf (".\n");
c0028971:	c7 04 24 6b f3 02 c0 	movl   $0xc002f36b,(%esp)
c0028978:	e8 2e 1d 00 00       	call   c002a6ab <puts>
}
c002897d:	83 c4 14             	add    $0x14,%esp
c0028980:	5b                   	pop    %ebx
c0028981:	5d                   	pop    %ebp
c0028982:	c3                   	ret    

c0028983 <debug_panic>:
{
c0028983:	57                   	push   %edi
c0028984:	56                   	push   %esi
c0028985:	53                   	push   %ebx
c0028986:	83 ec 10             	sub    $0x10,%esp
c0028989:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002898d:	8b 74 24 24          	mov    0x24(%esp),%esi
c0028991:	8b 7c 24 28          	mov    0x28(%esp),%edi
  intr_disable ();
c0028995:	e8 25 90 ff ff       	call   c00219bf <intr_disable>
  console_panic ();
c002899a:	e8 9d 1c 00 00       	call   c002a63c <console_panic>
  level++;
c002899f:	a1 c0 7a 03 c0       	mov    0xc0037ac0,%eax
c00289a4:	83 c0 01             	add    $0x1,%eax
c00289a7:	a3 c0 7a 03 c0       	mov    %eax,0xc0037ac0
  if (level == 1) 
c00289ac:	83 f8 01             	cmp    $0x1,%eax
c00289af:	75 3f                	jne    c00289f0 <debug_panic+0x6d>
      printf ("Kernel PANIC at %s:%d in %s(): ", file, line, function);
c00289b1:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00289b5:	89 74 24 08          	mov    %esi,0x8(%esp)
c00289b9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00289bd:	c7 04 24 bc fb 02 c0 	movl   $0xc002fbbc,(%esp)
c00289c4:	e8 65 e1 ff ff       	call   c0026b2e <printf>
      va_start (args, message);
c00289c9:	8d 44 24 30          	lea    0x30(%esp),%eax
      vprintf (message, args);
c00289cd:	89 44 24 04          	mov    %eax,0x4(%esp)
c00289d1:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00289d5:	89 04 24             	mov    %eax,(%esp)
c00289d8:	e8 8d 1c 00 00       	call   c002a66a <vprintf>
      printf ("\n");
c00289dd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00289e4:	e8 33 1d 00 00       	call   c002a71c <putchar>
      debug_backtrace ();
c00289e9:	e8 73 db ff ff       	call   c0026561 <debug_backtrace>
c00289ee:	eb 1d                	jmp    c0028a0d <debug_panic+0x8a>
  else if (level == 2)
c00289f0:	83 f8 02             	cmp    $0x2,%eax
c00289f3:	75 18                	jne    c0028a0d <debug_panic+0x8a>
    printf ("Kernel PANIC recursion at %s:%d in %s().\n",
c00289f5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00289f9:	89 74 24 08          	mov    %esi,0x8(%esp)
c00289fd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0028a01:	c7 04 24 dc fb 02 c0 	movl   $0xc002fbdc,(%esp)
c0028a08:	e8 21 e1 ff ff       	call   c0026b2e <printf>
  serial_flush ();
c0028a0d:	e8 8a c1 ff ff       	call   c0024b9c <serial_flush>
  shutdown ();
c0028a12:	e8 79 da ff ff       	call   c0026490 <shutdown>
c0028a17:	eb fe                	jmp    c0028a17 <debug_panic+0x94>

c0028a19 <debug_backtrace_all>:

/* Prints call stack of all threads. */
void
debug_backtrace_all (void)
{
c0028a19:	53                   	push   %ebx
c0028a1a:	83 ec 18             	sub    $0x18,%esp
  enum intr_level oldlevel = intr_disable ();
c0028a1d:	e8 9d 8f ff ff       	call   c00219bf <intr_disable>
c0028a22:	89 c3                	mov    %eax,%ebx

  thread_foreach (print_stacktrace, 0);
c0028a24:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0028a2b:	00 
c0028a2c:	c7 04 24 b0 88 02 c0 	movl   $0xc00288b0,(%esp)
c0028a33:	e8 82 84 ff ff       	call   c0020eba <thread_foreach>
  intr_set_level (oldlevel);
c0028a38:	89 1c 24             	mov    %ebx,(%esp)
c0028a3b:	e8 86 8f ff ff       	call   c00219c6 <intr_set_level>
}
c0028a40:	83 c4 18             	add    $0x18,%esp
c0028a43:	5b                   	pop    %ebx
c0028a44:	c3                   	ret    
c0028a45:	90                   	nop
c0028a46:	90                   	nop
c0028a47:	90                   	nop
c0028a48:	90                   	nop
c0028a49:	90                   	nop
c0028a4a:	90                   	nop
c0028a4b:	90                   	nop
c0028a4c:	90                   	nop
c0028a4d:	90                   	nop
c0028a4e:	90                   	nop
c0028a4f:	90                   	nop

c0028a50 <list_init>:
}

/* Initializes LIST as an empty list. */
void
list_init (struct list *list)
{
c0028a50:	83 ec 2c             	sub    $0x2c,%esp
c0028a53:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028a57:	85 c0                	test   %eax,%eax
c0028a59:	75 2c                	jne    c0028a87 <list_init+0x37>
c0028a5b:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028a62:	c0 
c0028a63:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028a6a:	c0 
c0028a6b:	c7 44 24 08 65 dd 02 	movl   $0xc002dd65,0x8(%esp)
c0028a72:	c0 
c0028a73:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0028a7a:	00 
c0028a7b:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028a82:	e8 fc fe ff ff       	call   c0028983 <debug_panic>
  list->head.prev = NULL;
c0028a87:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  list->head.next = &list->tail;
c0028a8d:	8d 50 08             	lea    0x8(%eax),%edx
c0028a90:	89 50 04             	mov    %edx,0x4(%eax)
  list->tail.prev = &list->head;
c0028a93:	89 40 08             	mov    %eax,0x8(%eax)
  list->tail.next = NULL;
c0028a96:	c7 40 0c 00 00 00 00 	movl   $0x0,0xc(%eax)
}
c0028a9d:	83 c4 2c             	add    $0x2c,%esp
c0028aa0:	c3                   	ret    

c0028aa1 <list_begin>:

/* Returns the beginning of LIST.  */
struct list_elem *
list_begin (struct list *list)
{
c0028aa1:	83 ec 2c             	sub    $0x2c,%esp
c0028aa4:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028aa8:	85 c0                	test   %eax,%eax
c0028aaa:	75 2c                	jne    c0028ad8 <list_begin+0x37>
c0028aac:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028ab3:	c0 
c0028ab4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028abb:	c0 
c0028abc:	c7 44 24 08 5a dd 02 	movl   $0xc002dd5a,0x8(%esp)
c0028ac3:	c0 
c0028ac4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0028acb:	00 
c0028acc:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028ad3:	e8 ab fe ff ff       	call   c0028983 <debug_panic>
  return list->head.next;
c0028ad8:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028adb:	83 c4 2c             	add    $0x2c,%esp
c0028ade:	c3                   	ret    

c0028adf <list_next>:
/* Returns the element after ELEM in its list.  If ELEM is the
   last element in its list, returns the list tail.  Results are
   undefined if ELEM is itself a list tail. */
struct list_elem *
list_next (struct list_elem *elem)
{
c0028adf:	83 ec 2c             	sub    $0x2c,%esp
c0028ae2:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev == NULL && elem->next != NULL;
c0028ae6:	85 c0                	test   %eax,%eax
c0028ae8:	74 16                	je     c0028b00 <list_next+0x21>
c0028aea:	83 38 00             	cmpl   $0x0,(%eax)
c0028aed:	75 06                	jne    c0028af5 <list_next+0x16>
c0028aef:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028af3:	75 37                	jne    c0028b2c <list_next+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028af5:	83 38 00             	cmpl   $0x0,(%eax)
c0028af8:	74 06                	je     c0028b00 <list_next+0x21>
c0028afa:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028afe:	75 2c                	jne    c0028b2c <list_next+0x4d>
  ASSERT (is_head (elem) || is_interior (elem));
c0028b00:	c7 44 24 10 bc fc 02 	movl   $0xc002fcbc,0x10(%esp)
c0028b07:	c0 
c0028b08:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028b0f:	c0 
c0028b10:	c7 44 24 08 50 dd 02 	movl   $0xc002dd50,0x8(%esp)
c0028b17:	c0 
c0028b18:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0028b1f:	00 
c0028b20:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028b27:	e8 57 fe ff ff       	call   c0028983 <debug_panic>
  return elem->next;
c0028b2c:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028b2f:	83 c4 2c             	add    $0x2c,%esp
c0028b32:	c3                   	ret    

c0028b33 <list_end>:
   list_end() is often used in iterating through a list from
   front to back.  See the big comment at the top of list.h for
   an example. */
struct list_elem *
list_end (struct list *list)
{
c0028b33:	83 ec 2c             	sub    $0x2c,%esp
c0028b36:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b3a:	85 c0                	test   %eax,%eax
c0028b3c:	75 2c                	jne    c0028b6a <list_end+0x37>
c0028b3e:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028b45:	c0 
c0028b46:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028b4d:	c0 
c0028b4e:	c7 44 24 08 47 dd 02 	movl   $0xc002dd47,0x8(%esp)
c0028b55:	c0 
c0028b56:	c7 44 24 04 60 00 00 	movl   $0x60,0x4(%esp)
c0028b5d:	00 
c0028b5e:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028b65:	e8 19 fe ff ff       	call   c0028983 <debug_panic>
  return &list->tail;
c0028b6a:	83 c0 08             	add    $0x8,%eax
}
c0028b6d:	83 c4 2c             	add    $0x2c,%esp
c0028b70:	c3                   	ret    

c0028b71 <list_rbegin>:

/* Returns the LIST's reverse beginning, for iterating through
   LIST in reverse order, from back to front. */
struct list_elem *
list_rbegin (struct list *list) 
{
c0028b71:	83 ec 2c             	sub    $0x2c,%esp
c0028b74:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b78:	85 c0                	test   %eax,%eax
c0028b7a:	75 2c                	jne    c0028ba8 <list_rbegin+0x37>
c0028b7c:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028b83:	c0 
c0028b84:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028b8b:	c0 
c0028b8c:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028b93:	c0 
c0028b94:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0028b9b:	00 
c0028b9c:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028ba3:	e8 db fd ff ff       	call   c0028983 <debug_panic>
  return list->tail.prev;
c0028ba8:	8b 40 08             	mov    0x8(%eax),%eax
}
c0028bab:	83 c4 2c             	add    $0x2c,%esp
c0028bae:	c3                   	ret    

c0028baf <list_prev>:
/* Returns the element before ELEM in its list.  If ELEM is the
   first element in its list, returns the list head.  Results are
   undefined if ELEM is itself a list head. */
struct list_elem *
list_prev (struct list_elem *elem)
{
c0028baf:	83 ec 2c             	sub    $0x2c,%esp
c0028bb2:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028bb6:	85 c0                	test   %eax,%eax
c0028bb8:	74 16                	je     c0028bd0 <list_prev+0x21>
c0028bba:	83 38 00             	cmpl   $0x0,(%eax)
c0028bbd:	74 06                	je     c0028bc5 <list_prev+0x16>
c0028bbf:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028bc3:	75 37                	jne    c0028bfc <list_prev+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028bc5:	83 38 00             	cmpl   $0x0,(%eax)
c0028bc8:	74 06                	je     c0028bd0 <list_prev+0x21>
c0028bca:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028bce:	74 2c                	je     c0028bfc <list_prev+0x4d>
  ASSERT (is_interior (elem) || is_tail (elem));
c0028bd0:	c7 44 24 10 e4 fc 02 	movl   $0xc002fce4,0x10(%esp)
c0028bd7:	c0 
c0028bd8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028bdf:	c0 
c0028be0:	c7 44 24 08 31 dd 02 	movl   $0xc002dd31,0x8(%esp)
c0028be7:	c0 
c0028be8:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c0028bef:	00 
c0028bf0:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028bf7:	e8 87 fd ff ff       	call   c0028983 <debug_panic>
  return elem->prev;
c0028bfc:	8b 00                	mov    (%eax),%eax
}
c0028bfe:	83 c4 2c             	add    $0x2c,%esp
c0028c01:	c3                   	ret    

c0028c02 <find_end_of_run>:
   run.
   A through B (exclusive) must form a non-empty range. */
static struct list_elem *
find_end_of_run (struct list_elem *a, struct list_elem *b,
                 list_less_func *less, void *aux)
{
c0028c02:	55                   	push   %ebp
c0028c03:	57                   	push   %edi
c0028c04:	56                   	push   %esi
c0028c05:	53                   	push   %ebx
c0028c06:	83 ec 2c             	sub    $0x2c,%esp
c0028c09:	89 c3                	mov    %eax,%ebx
c0028c0b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (a != NULL);
c0028c0f:	85 c0                	test   %eax,%eax
c0028c11:	75 2c                	jne    c0028c3f <find_end_of_run+0x3d>
c0028c13:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c0028c1a:	c0 
c0028c1b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028c22:	c0 
c0028c23:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028c2a:	c0 
c0028c2b:	c7 44 24 04 6a 01 00 	movl   $0x16a,0x4(%esp)
c0028c32:	00 
c0028c33:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028c3a:	e8 44 fd ff ff       	call   c0028983 <debug_panic>
c0028c3f:	89 d6                	mov    %edx,%esi
c0028c41:	89 cf                	mov    %ecx,%edi
  ASSERT (b != NULL);
c0028c43:	85 d2                	test   %edx,%edx
c0028c45:	75 2c                	jne    c0028c73 <find_end_of_run+0x71>
c0028c47:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0028c4e:	c0 
c0028c4f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028c56:	c0 
c0028c57:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028c5e:	c0 
c0028c5f:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c0028c66:	00 
c0028c67:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028c6e:	e8 10 fd ff ff       	call   c0028983 <debug_panic>
  ASSERT (less != NULL);
c0028c73:	85 c9                	test   %ecx,%ecx
c0028c75:	75 2c                	jne    c0028ca3 <find_end_of_run+0xa1>
c0028c77:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c0028c7e:	c0 
c0028c7f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028c86:	c0 
c0028c87:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028c8e:	c0 
c0028c8f:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c0028c96:	00 
c0028c97:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028c9e:	e8 e0 fc ff ff       	call   c0028983 <debug_panic>
  ASSERT (a != b);
c0028ca3:	39 d0                	cmp    %edx,%eax
c0028ca5:	75 2c                	jne    c0028cd3 <find_end_of_run+0xd1>
c0028ca7:	c7 44 24 10 38 fc 02 	movl   $0xc002fc38,0x10(%esp)
c0028cae:	c0 
c0028caf:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028cb6:	c0 
c0028cb7:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028cbe:	c0 
c0028cbf:	c7 44 24 04 6d 01 00 	movl   $0x16d,0x4(%esp)
c0028cc6:	00 
c0028cc7:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028cce:	e8 b0 fc ff ff       	call   c0028983 <debug_panic>
  
  do 
    {
      a = list_next (a);
c0028cd3:	89 1c 24             	mov    %ebx,(%esp)
c0028cd6:	e8 04 fe ff ff       	call   c0028adf <list_next>
c0028cdb:	89 c3                	mov    %eax,%ebx
    }
  while (a != b && !less (a, list_prev (a), aux));
c0028cdd:	39 f0                	cmp    %esi,%eax
c0028cdf:	74 19                	je     c0028cfa <find_end_of_run+0xf8>
c0028ce1:	89 04 24             	mov    %eax,(%esp)
c0028ce4:	e8 c6 fe ff ff       	call   c0028baf <list_prev>
c0028ce9:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0028ced:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028cf1:	89 1c 24             	mov    %ebx,(%esp)
c0028cf4:	ff d7                	call   *%edi
c0028cf6:	84 c0                	test   %al,%al
c0028cf8:	74 d9                	je     c0028cd3 <find_end_of_run+0xd1>
  return a;
}
c0028cfa:	89 d8                	mov    %ebx,%eax
c0028cfc:	83 c4 2c             	add    $0x2c,%esp
c0028cff:	5b                   	pop    %ebx
c0028d00:	5e                   	pop    %esi
c0028d01:	5f                   	pop    %edi
c0028d02:	5d                   	pop    %ebp
c0028d03:	c3                   	ret    

c0028d04 <is_sorted>:
{
c0028d04:	55                   	push   %ebp
c0028d05:	57                   	push   %edi
c0028d06:	56                   	push   %esi
c0028d07:	53                   	push   %ebx
c0028d08:	83 ec 1c             	sub    $0x1c,%esp
c0028d0b:	89 c3                	mov    %eax,%ebx
c0028d0d:	89 d6                	mov    %edx,%esi
c0028d0f:	89 cd                	mov    %ecx,%ebp
c0028d11:	8b 7c 24 30          	mov    0x30(%esp),%edi
  if (a != b)
c0028d15:	39 d0                	cmp    %edx,%eax
c0028d17:	75 1b                	jne    c0028d34 <is_sorted+0x30>
c0028d19:	eb 2e                	jmp    c0028d49 <is_sorted+0x45>
      if (less (a, list_prev (a), aux))
c0028d1b:	89 1c 24             	mov    %ebx,(%esp)
c0028d1e:	e8 8c fe ff ff       	call   c0028baf <list_prev>
c0028d23:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0028d27:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028d2b:	89 1c 24             	mov    %ebx,(%esp)
c0028d2e:	ff d5                	call   *%ebp
c0028d30:	84 c0                	test   %al,%al
c0028d32:	75 1c                	jne    c0028d50 <is_sorted+0x4c>
    while ((a = list_next (a)) != b) 
c0028d34:	89 1c 24             	mov    %ebx,(%esp)
c0028d37:	e8 a3 fd ff ff       	call   c0028adf <list_next>
c0028d3c:	89 c3                	mov    %eax,%ebx
c0028d3e:	39 f0                	cmp    %esi,%eax
c0028d40:	75 d9                	jne    c0028d1b <is_sorted+0x17>
  return true;
c0028d42:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d47:	eb 0c                	jmp    c0028d55 <is_sorted+0x51>
c0028d49:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d4e:	eb 05                	jmp    c0028d55 <is_sorted+0x51>
        return false;
c0028d50:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028d55:	83 c4 1c             	add    $0x1c,%esp
c0028d58:	5b                   	pop    %ebx
c0028d59:	5e                   	pop    %esi
c0028d5a:	5f                   	pop    %edi
c0028d5b:	5d                   	pop    %ebp
c0028d5c:	c3                   	ret    

c0028d5d <list_rend>:
{
c0028d5d:	83 ec 2c             	sub    $0x2c,%esp
c0028d60:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028d64:	85 c0                	test   %eax,%eax
c0028d66:	75 2c                	jne    c0028d94 <list_rend+0x37>
c0028d68:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028d6f:	c0 
c0028d70:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028d77:	c0 
c0028d78:	c7 44 24 08 27 dd 02 	movl   $0xc002dd27,0x8(%esp)
c0028d7f:	c0 
c0028d80:	c7 44 24 04 87 00 00 	movl   $0x87,0x4(%esp)
c0028d87:	00 
c0028d88:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028d8f:	e8 ef fb ff ff       	call   c0028983 <debug_panic>
}
c0028d94:	83 c4 2c             	add    $0x2c,%esp
c0028d97:	c3                   	ret    

c0028d98 <list_head>:
{
c0028d98:	83 ec 2c             	sub    $0x2c,%esp
c0028d9b:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028d9f:	85 c0                	test   %eax,%eax
c0028da1:	75 2c                	jne    c0028dcf <list_head+0x37>
c0028da3:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028daa:	c0 
c0028dab:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028db2:	c0 
c0028db3:	c7 44 24 08 1d dd 02 	movl   $0xc002dd1d,0x8(%esp)
c0028dba:	c0 
c0028dbb:	c7 44 24 04 99 00 00 	movl   $0x99,0x4(%esp)
c0028dc2:	00 
c0028dc3:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028dca:	e8 b4 fb ff ff       	call   c0028983 <debug_panic>
}
c0028dcf:	83 c4 2c             	add    $0x2c,%esp
c0028dd2:	c3                   	ret    

c0028dd3 <list_tail>:
{
c0028dd3:	83 ec 2c             	sub    $0x2c,%esp
c0028dd6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028dda:	85 c0                	test   %eax,%eax
c0028ddc:	75 2c                	jne    c0028e0a <list_tail+0x37>
c0028dde:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028de5:	c0 
c0028de6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028ded:	c0 
c0028dee:	c7 44 24 08 13 dd 02 	movl   $0xc002dd13,0x8(%esp)
c0028df5:	c0 
c0028df6:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c0028dfd:	00 
c0028dfe:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028e05:	e8 79 fb ff ff       	call   c0028983 <debug_panic>
  return &list->tail;
c0028e0a:	83 c0 08             	add    $0x8,%eax
}
c0028e0d:	83 c4 2c             	add    $0x2c,%esp
c0028e10:	c3                   	ret    

c0028e11 <list_insert>:
{
c0028e11:	83 ec 2c             	sub    $0x2c,%esp
c0028e14:	8b 44 24 30          	mov    0x30(%esp),%eax
c0028e18:	8b 54 24 34          	mov    0x34(%esp),%edx
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028e1c:	85 c0                	test   %eax,%eax
c0028e1e:	74 56                	je     c0028e76 <list_insert+0x65>
c0028e20:	83 38 00             	cmpl   $0x0,(%eax)
c0028e23:	74 06                	je     c0028e2b <list_insert+0x1a>
c0028e25:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e29:	75 0b                	jne    c0028e36 <list_insert+0x25>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028e2b:	83 38 00             	cmpl   $0x0,(%eax)
c0028e2e:	74 46                	je     c0028e76 <list_insert+0x65>
c0028e30:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e34:	75 40                	jne    c0028e76 <list_insert+0x65>
  ASSERT (elem != NULL);
c0028e36:	85 d2                	test   %edx,%edx
c0028e38:	75 2c                	jne    c0028e66 <list_insert+0x55>
c0028e3a:	c7 44 24 10 3f fc 02 	movl   $0xc002fc3f,0x10(%esp)
c0028e41:	c0 
c0028e42:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028e49:	c0 
c0028e4a:	c7 44 24 08 07 dd 02 	movl   $0xc002dd07,0x8(%esp)
c0028e51:	c0 
c0028e52:	c7 44 24 04 ac 00 00 	movl   $0xac,0x4(%esp)
c0028e59:	00 
c0028e5a:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028e61:	e8 1d fb ff ff       	call   c0028983 <debug_panic>
  elem->prev = before->prev;
c0028e66:	8b 08                	mov    (%eax),%ecx
c0028e68:	89 0a                	mov    %ecx,(%edx)
  elem->next = before;
c0028e6a:	89 42 04             	mov    %eax,0x4(%edx)
  before->prev->next = elem;
c0028e6d:	8b 08                	mov    (%eax),%ecx
c0028e6f:	89 51 04             	mov    %edx,0x4(%ecx)
  before->prev = elem;
c0028e72:	89 10                	mov    %edx,(%eax)
c0028e74:	eb 2c                	jmp    c0028ea2 <list_insert+0x91>
  ASSERT (is_interior (before) || is_tail (before));
c0028e76:	c7 44 24 10 0c fd 02 	movl   $0xc002fd0c,0x10(%esp)
c0028e7d:	c0 
c0028e7e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028e85:	c0 
c0028e86:	c7 44 24 08 07 dd 02 	movl   $0xc002dd07,0x8(%esp)
c0028e8d:	c0 
c0028e8e:	c7 44 24 04 ab 00 00 	movl   $0xab,0x4(%esp)
c0028e95:	00 
c0028e96:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028e9d:	e8 e1 fa ff ff       	call   c0028983 <debug_panic>
}
c0028ea2:	83 c4 2c             	add    $0x2c,%esp
c0028ea5:	c3                   	ret    

c0028ea6 <list_splice>:
{
c0028ea6:	56                   	push   %esi
c0028ea7:	53                   	push   %ebx
c0028ea8:	83 ec 24             	sub    $0x24,%esp
c0028eab:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0028eaf:	8b 74 24 34          	mov    0x34(%esp),%esi
c0028eb3:	8b 44 24 38          	mov    0x38(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028eb7:	85 db                	test   %ebx,%ebx
c0028eb9:	74 4d                	je     c0028f08 <list_splice+0x62>
c0028ebb:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028ebe:	74 06                	je     c0028ec6 <list_splice+0x20>
c0028ec0:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028ec4:	75 0b                	jne    c0028ed1 <list_splice+0x2b>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028ec6:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028ec9:	74 3d                	je     c0028f08 <list_splice+0x62>
c0028ecb:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028ecf:	75 37                	jne    c0028f08 <list_splice+0x62>
  if (first == last)
c0028ed1:	39 c6                	cmp    %eax,%esi
c0028ed3:	0f 84 cf 00 00 00    	je     c0028fa8 <list_splice+0x102>
  last = list_prev (last);
c0028ed9:	89 04 24             	mov    %eax,(%esp)
c0028edc:	e8 ce fc ff ff       	call   c0028baf <list_prev>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ee1:	85 f6                	test   %esi,%esi
c0028ee3:	74 4f                	je     c0028f34 <list_splice+0x8e>
c0028ee5:	8b 16                	mov    (%esi),%edx
c0028ee7:	85 d2                	test   %edx,%edx
c0028ee9:	74 49                	je     c0028f34 <list_splice+0x8e>
c0028eeb:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0028eef:	75 6f                	jne    c0028f60 <list_splice+0xba>
c0028ef1:	eb 41                	jmp    c0028f34 <list_splice+0x8e>
c0028ef3:	83 38 00             	cmpl   $0x0,(%eax)
c0028ef6:	74 6c                	je     c0028f64 <list_splice+0xbe>
c0028ef8:	8b 48 04             	mov    0x4(%eax),%ecx
c0028efb:	85 c9                	test   %ecx,%ecx
c0028efd:	8d 76 00             	lea    0x0(%esi),%esi
c0028f00:	0f 85 8a 00 00 00    	jne    c0028f90 <list_splice+0xea>
c0028f06:	eb 5c                	jmp    c0028f64 <list_splice+0xbe>
  ASSERT (is_interior (before) || is_tail (before));
c0028f08:	c7 44 24 10 0c fd 02 	movl   $0xc002fd0c,0x10(%esp)
c0028f0f:	c0 
c0028f10:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028f17:	c0 
c0028f18:	c7 44 24 08 fb dc 02 	movl   $0xc002dcfb,0x8(%esp)
c0028f1f:	c0 
c0028f20:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c0028f27:	00 
c0028f28:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028f2f:	e8 4f fa ff ff       	call   c0028983 <debug_panic>
  ASSERT (is_interior (first));
c0028f34:	c7 44 24 10 4c fc 02 	movl   $0xc002fc4c,0x10(%esp)
c0028f3b:	c0 
c0028f3c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028f43:	c0 
c0028f44:	c7 44 24 08 fb dc 02 	movl   $0xc002dcfb,0x8(%esp)
c0028f4b:	c0 
c0028f4c:	c7 44 24 04 c0 00 00 	movl   $0xc0,0x4(%esp)
c0028f53:	00 
c0028f54:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028f5b:	e8 23 fa ff ff       	call   c0028983 <debug_panic>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028f60:	85 c0                	test   %eax,%eax
c0028f62:	75 8f                	jne    c0028ef3 <list_splice+0x4d>
  ASSERT (is_interior (last));
c0028f64:	c7 44 24 10 60 fc 02 	movl   $0xc002fc60,0x10(%esp)
c0028f6b:	c0 
c0028f6c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028f73:	c0 
c0028f74:	c7 44 24 08 fb dc 02 	movl   $0xc002dcfb,0x8(%esp)
c0028f7b:	c0 
c0028f7c:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0028f83:	00 
c0028f84:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028f8b:	e8 f3 f9 ff ff       	call   c0028983 <debug_panic>
  first->prev->next = last->next;
c0028f90:	89 4a 04             	mov    %ecx,0x4(%edx)
  last->next->prev = first->prev;
c0028f93:	8b 50 04             	mov    0x4(%eax),%edx
c0028f96:	8b 0e                	mov    (%esi),%ecx
c0028f98:	89 0a                	mov    %ecx,(%edx)
  first->prev = before->prev;
c0028f9a:	8b 13                	mov    (%ebx),%edx
c0028f9c:	89 16                	mov    %edx,(%esi)
  last->next = before;
c0028f9e:	89 58 04             	mov    %ebx,0x4(%eax)
  before->prev->next = first;
c0028fa1:	8b 13                	mov    (%ebx),%edx
c0028fa3:	89 72 04             	mov    %esi,0x4(%edx)
  before->prev = last;
c0028fa6:	89 03                	mov    %eax,(%ebx)
}
c0028fa8:	83 c4 24             	add    $0x24,%esp
c0028fab:	5b                   	pop    %ebx
c0028fac:	5e                   	pop    %esi
c0028fad:	c3                   	ret    

c0028fae <list_push_front>:
{
c0028fae:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_begin (list), elem);
c0028fb1:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028fb5:	89 04 24             	mov    %eax,(%esp)
c0028fb8:	e8 e4 fa ff ff       	call   c0028aa1 <list_begin>
c0028fbd:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028fc1:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028fc5:	89 04 24             	mov    %eax,(%esp)
c0028fc8:	e8 44 fe ff ff       	call   c0028e11 <list_insert>
}
c0028fcd:	83 c4 1c             	add    $0x1c,%esp
c0028fd0:	c3                   	ret    

c0028fd1 <list_push_back>:
{
c0028fd1:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_end (list), elem);
c0028fd4:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028fd8:	89 04 24             	mov    %eax,(%esp)
c0028fdb:	e8 53 fb ff ff       	call   c0028b33 <list_end>
c0028fe0:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028fe4:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028fe8:	89 04 24             	mov    %eax,(%esp)
c0028feb:	e8 21 fe ff ff       	call   c0028e11 <list_insert>
}
c0028ff0:	83 c4 1c             	add    $0x1c,%esp
c0028ff3:	c3                   	ret    

c0028ff4 <list_remove>:
{
c0028ff4:	83 ec 2c             	sub    $0x2c,%esp
c0028ff7:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ffb:	85 c0                	test   %eax,%eax
c0028ffd:	74 0d                	je     c002900c <list_remove+0x18>
c0028fff:	8b 10                	mov    (%eax),%edx
c0029001:	85 d2                	test   %edx,%edx
c0029003:	74 07                	je     c002900c <list_remove+0x18>
c0029005:	8b 48 04             	mov    0x4(%eax),%ecx
c0029008:	85 c9                	test   %ecx,%ecx
c002900a:	75 2c                	jne    c0029038 <list_remove+0x44>
  ASSERT (is_interior (elem));
c002900c:	c7 44 24 10 73 fc 02 	movl   $0xc002fc73,0x10(%esp)
c0029013:	c0 
c0029014:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002901b:	c0 
c002901c:	c7 44 24 08 ef dc 02 	movl   $0xc002dcef,0x8(%esp)
c0029023:	c0 
c0029024:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
c002902b:	00 
c002902c:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029033:	e8 4b f9 ff ff       	call   c0028983 <debug_panic>
  elem->prev->next = elem->next;
c0029038:	89 4a 04             	mov    %ecx,0x4(%edx)
  elem->next->prev = elem->prev;
c002903b:	8b 50 04             	mov    0x4(%eax),%edx
c002903e:	8b 08                	mov    (%eax),%ecx
c0029040:	89 0a                	mov    %ecx,(%edx)
  return elem->next;
c0029042:	8b 40 04             	mov    0x4(%eax),%eax
}
c0029045:	83 c4 2c             	add    $0x2c,%esp
c0029048:	c3                   	ret    

c0029049 <list_size>:
{
c0029049:	57                   	push   %edi
c002904a:	56                   	push   %esi
c002904b:	53                   	push   %ebx
c002904c:	83 ec 10             	sub    $0x10,%esp
c002904f:	8b 7c 24 20          	mov    0x20(%esp),%edi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029053:	89 3c 24             	mov    %edi,(%esp)
c0029056:	e8 46 fa ff ff       	call   c0028aa1 <list_begin>
c002905b:	89 c3                	mov    %eax,%ebx
  size_t cnt = 0;
c002905d:	be 00 00 00 00       	mov    $0x0,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029062:	eb 0d                	jmp    c0029071 <list_size+0x28>
    cnt++;
c0029064:	83 c6 01             	add    $0x1,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029067:	89 1c 24             	mov    %ebx,(%esp)
c002906a:	e8 70 fa ff ff       	call   c0028adf <list_next>
c002906f:	89 c3                	mov    %eax,%ebx
c0029071:	89 3c 24             	mov    %edi,(%esp)
c0029074:	e8 ba fa ff ff       	call   c0028b33 <list_end>
c0029079:	39 d8                	cmp    %ebx,%eax
c002907b:	75 e7                	jne    c0029064 <list_size+0x1b>
}
c002907d:	89 f0                	mov    %esi,%eax
c002907f:	83 c4 10             	add    $0x10,%esp
c0029082:	5b                   	pop    %ebx
c0029083:	5e                   	pop    %esi
c0029084:	5f                   	pop    %edi
c0029085:	c3                   	ret    

c0029086 <list_empty>:
{
c0029086:	56                   	push   %esi
c0029087:	53                   	push   %ebx
c0029088:	83 ec 14             	sub    $0x14,%esp
c002908b:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  return list_begin (list) == list_end (list);
c002908f:	89 1c 24             	mov    %ebx,(%esp)
c0029092:	e8 0a fa ff ff       	call   c0028aa1 <list_begin>
c0029097:	89 c6                	mov    %eax,%esi
c0029099:	89 1c 24             	mov    %ebx,(%esp)
c002909c:	e8 92 fa ff ff       	call   c0028b33 <list_end>
c00290a1:	39 c6                	cmp    %eax,%esi
c00290a3:	0f 94 c0             	sete   %al
}
c00290a6:	83 c4 14             	add    $0x14,%esp
c00290a9:	5b                   	pop    %ebx
c00290aa:	5e                   	pop    %esi
c00290ab:	c3                   	ret    

c00290ac <list_front>:
{
c00290ac:	53                   	push   %ebx
c00290ad:	83 ec 28             	sub    $0x28,%esp
c00290b0:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c00290b4:	89 1c 24             	mov    %ebx,(%esp)
c00290b7:	e8 ca ff ff ff       	call   c0029086 <list_empty>
c00290bc:	84 c0                	test   %al,%al
c00290be:	74 2c                	je     c00290ec <list_front+0x40>
c00290c0:	c7 44 24 10 86 fc 02 	movl   $0xc002fc86,0x10(%esp)
c00290c7:	c0 
c00290c8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00290cf:	c0 
c00290d0:	c7 44 24 08 e4 dc 02 	movl   $0xc002dce4,0x8(%esp)
c00290d7:	c0 
c00290d8:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c00290df:	00 
c00290e0:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00290e7:	e8 97 f8 ff ff       	call   c0028983 <debug_panic>
  return list->head.next;
c00290ec:	8b 43 04             	mov    0x4(%ebx),%eax
}
c00290ef:	83 c4 28             	add    $0x28,%esp
c00290f2:	5b                   	pop    %ebx
c00290f3:	c3                   	ret    

c00290f4 <list_pop_front>:
{
c00290f4:	53                   	push   %ebx
c00290f5:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *front = list_front (list);
c00290f8:	8b 44 24 20          	mov    0x20(%esp),%eax
c00290fc:	89 04 24             	mov    %eax,(%esp)
c00290ff:	e8 a8 ff ff ff       	call   c00290ac <list_front>
c0029104:	89 c3                	mov    %eax,%ebx
  list_remove (front);
c0029106:	89 04 24             	mov    %eax,(%esp)
c0029109:	e8 e6 fe ff ff       	call   c0028ff4 <list_remove>
}
c002910e:	89 d8                	mov    %ebx,%eax
c0029110:	83 c4 18             	add    $0x18,%esp
c0029113:	5b                   	pop    %ebx
c0029114:	c3                   	ret    

c0029115 <list_back>:
{
c0029115:	53                   	push   %ebx
c0029116:	83 ec 28             	sub    $0x28,%esp
c0029119:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c002911d:	89 1c 24             	mov    %ebx,(%esp)
c0029120:	e8 61 ff ff ff       	call   c0029086 <list_empty>
c0029125:	84 c0                	test   %al,%al
c0029127:	74 2c                	je     c0029155 <list_back+0x40>
c0029129:	c7 44 24 10 86 fc 02 	movl   $0xc002fc86,0x10(%esp)
c0029130:	c0 
c0029131:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029138:	c0 
c0029139:	c7 44 24 08 da dc 02 	movl   $0xc002dcda,0x8(%esp)
c0029140:	c0 
c0029141:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
c0029148:	00 
c0029149:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029150:	e8 2e f8 ff ff       	call   c0028983 <debug_panic>
  return list->tail.prev;
c0029155:	8b 43 08             	mov    0x8(%ebx),%eax
}
c0029158:	83 c4 28             	add    $0x28,%esp
c002915b:	5b                   	pop    %ebx
c002915c:	c3                   	ret    

c002915d <list_pop_back>:
{
c002915d:	53                   	push   %ebx
c002915e:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *back = list_back (list);
c0029161:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029165:	89 04 24             	mov    %eax,(%esp)
c0029168:	e8 a8 ff ff ff       	call   c0029115 <list_back>
c002916d:	89 c3                	mov    %eax,%ebx
  list_remove (back);
c002916f:	89 04 24             	mov    %eax,(%esp)
c0029172:	e8 7d fe ff ff       	call   c0028ff4 <list_remove>
}
c0029177:	89 d8                	mov    %ebx,%eax
c0029179:	83 c4 18             	add    $0x18,%esp
c002917c:	5b                   	pop    %ebx
c002917d:	c3                   	ret    

c002917e <list_reverse>:
{
c002917e:	56                   	push   %esi
c002917f:	53                   	push   %ebx
c0029180:	83 ec 14             	sub    $0x14,%esp
c0029183:	8b 74 24 20          	mov    0x20(%esp),%esi
  if (!list_empty (list)) 
c0029187:	89 34 24             	mov    %esi,(%esp)
c002918a:	e8 f7 fe ff ff       	call   c0029086 <list_empty>
c002918f:	84 c0                	test   %al,%al
c0029191:	75 3a                	jne    c00291cd <list_reverse+0x4f>
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c0029193:	89 34 24             	mov    %esi,(%esp)
c0029196:	e8 06 f9 ff ff       	call   c0028aa1 <list_begin>
c002919b:	89 c3                	mov    %eax,%ebx
c002919d:	eb 0c                	jmp    c00291ab <list_reverse+0x2d>
  struct list_elem *t = *a;
c002919f:	8b 13                	mov    (%ebx),%edx
  *a = *b;
c00291a1:	8b 43 04             	mov    0x4(%ebx),%eax
c00291a4:	89 03                	mov    %eax,(%ebx)
  *b = t;
c00291a6:	89 53 04             	mov    %edx,0x4(%ebx)
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c00291a9:	89 c3                	mov    %eax,%ebx
c00291ab:	89 34 24             	mov    %esi,(%esp)
c00291ae:	e8 80 f9 ff ff       	call   c0028b33 <list_end>
c00291b3:	39 d8                	cmp    %ebx,%eax
c00291b5:	75 e8                	jne    c002919f <list_reverse+0x21>
  struct list_elem *t = *a;
c00291b7:	8b 46 04             	mov    0x4(%esi),%eax
  *a = *b;
c00291ba:	8b 56 08             	mov    0x8(%esi),%edx
c00291bd:	89 56 04             	mov    %edx,0x4(%esi)
  *b = t;
c00291c0:	89 46 08             	mov    %eax,0x8(%esi)
  struct list_elem *t = *a;
c00291c3:	8b 0a                	mov    (%edx),%ecx
  *a = *b;
c00291c5:	8b 58 04             	mov    0x4(%eax),%ebx
c00291c8:	89 1a                	mov    %ebx,(%edx)
  *b = t;
c00291ca:	89 48 04             	mov    %ecx,0x4(%eax)
}
c00291cd:	83 c4 14             	add    $0x14,%esp
c00291d0:	5b                   	pop    %ebx
c00291d1:	5e                   	pop    %esi
c00291d2:	c3                   	ret    

c00291d3 <list_sort>:
/* Sorts LIST according to LESS given auxiliary data AUX, using a
   natural iterative merge sort that runs in O(n lg n) time and
   O(1) space in the number of elements in LIST. */
void
list_sort (struct list *list, list_less_func *less, void *aux)
{
c00291d3:	55                   	push   %ebp
c00291d4:	57                   	push   %edi
c00291d5:	56                   	push   %esi
c00291d6:	53                   	push   %ebx
c00291d7:	83 ec 2c             	sub    $0x2c,%esp
c00291da:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00291de:	8b 7c 24 48          	mov    0x48(%esp),%edi
  size_t output_run_cnt;        /* Number of runs output in current pass. */

  ASSERT (list != NULL);
c00291e2:	83 7c 24 40 00       	cmpl   $0x0,0x40(%esp)
c00291e7:	75 2c                	jne    c0029215 <list_sort+0x42>
c00291e9:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c00291f0:	c0 
c00291f1:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00291f8:	c0 
c00291f9:	c7 44 24 08 d0 dc 02 	movl   $0xc002dcd0,0x8(%esp)
c0029200:	c0 
c0029201:	c7 44 24 04 9a 01 00 	movl   $0x19a,0x4(%esp)
c0029208:	00 
c0029209:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029210:	e8 6e f7 ff ff       	call   c0028983 <debug_panic>
  ASSERT (less != NULL);
c0029215:	85 ed                	test   %ebp,%ebp
c0029217:	75 2c                	jne    c0029245 <list_sort+0x72>
c0029219:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c0029220:	c0 
c0029221:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029228:	c0 
c0029229:	c7 44 24 08 d0 dc 02 	movl   $0xc002dcd0,0x8(%esp)
c0029230:	c0 
c0029231:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c0029238:	00 
c0029239:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029240:	e8 3e f7 ff ff       	call   c0028983 <debug_panic>
      struct list_elem *a0;     /* Start of first run. */
      struct list_elem *a1b0;   /* End of first run, start of second. */
      struct list_elem *b1;     /* End of second run. */

      output_run_cnt = 0;
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0029245:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029249:	89 04 24             	mov    %eax,(%esp)
c002924c:	e8 50 f8 ff ff       	call   c0028aa1 <list_begin>
c0029251:	89 c6                	mov    %eax,%esi
      output_run_cnt = 0;
c0029253:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002925a:	00 
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c002925b:	e9 99 01 00 00       	jmp    c00293f9 <list_sort+0x226>
        {
          /* Each iteration produces one output run. */
          output_run_cnt++;
c0029260:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)

          /* Locate two adjacent runs of nondecreasing elements
             A0...A1B0 and A1B0...B1. */
          a1b0 = find_end_of_run (a0, list_end (list), less, aux);
c0029265:	89 3c 24             	mov    %edi,(%esp)
c0029268:	89 e9                	mov    %ebp,%ecx
c002926a:	89 c2                	mov    %eax,%edx
c002926c:	89 f0                	mov    %esi,%eax
c002926e:	e8 8f f9 ff ff       	call   c0028c02 <find_end_of_run>
c0029273:	89 c3                	mov    %eax,%ebx
          if (a1b0 == list_end (list))
c0029275:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029279:	89 04 24             	mov    %eax,(%esp)
c002927c:	e8 b2 f8 ff ff       	call   c0028b33 <list_end>
c0029281:	39 d8                	cmp    %ebx,%eax
c0029283:	0f 84 84 01 00 00    	je     c002940d <list_sort+0x23a>
            break;
          b1 = find_end_of_run (a1b0, list_end (list), less, aux);
c0029289:	89 3c 24             	mov    %edi,(%esp)
c002928c:	89 e9                	mov    %ebp,%ecx
c002928e:	89 c2                	mov    %eax,%edx
c0029290:	89 d8                	mov    %ebx,%eax
c0029292:	e8 6b f9 ff ff       	call   c0028c02 <find_end_of_run>
c0029297:	89 44 24 18          	mov    %eax,0x18(%esp)
  ASSERT (a0 != NULL);
c002929b:	85 f6                	test   %esi,%esi
c002929d:	75 2c                	jne    c00292cb <list_sort+0xf8>
c002929f:	c7 44 24 10 99 fc 02 	movl   $0xc002fc99,0x10(%esp)
c00292a6:	c0 
c00292a7:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00292ae:	c0 
c00292af:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c00292b6:	c0 
c00292b7:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
c00292be:	00 
c00292bf:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00292c6:	e8 b8 f6 ff ff       	call   c0028983 <debug_panic>
  ASSERT (a1b0 != NULL);
c00292cb:	85 db                	test   %ebx,%ebx
c00292cd:	75 2c                	jne    c00292fb <list_sort+0x128>
c00292cf:	c7 44 24 10 a4 fc 02 	movl   $0xc002fca4,0x10(%esp)
c00292d6:	c0 
c00292d7:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00292de:	c0 
c00292df:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c00292e6:	c0 
c00292e7:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
c00292ee:	00 
c00292ef:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00292f6:	e8 88 f6 ff ff       	call   c0028983 <debug_panic>
  ASSERT (b1 != NULL);
c00292fb:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c0029300:	75 2c                	jne    c002932e <list_sort+0x15b>
c0029302:	c7 44 24 10 b1 fc 02 	movl   $0xc002fcb1,0x10(%esp)
c0029309:	c0 
c002930a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029311:	c0 
c0029312:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c0029319:	c0 
c002931a:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
c0029321:	00 
c0029322:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029329:	e8 55 f6 ff ff       	call   c0028983 <debug_panic>
  ASSERT (is_sorted (a0, a1b0, less, aux));
c002932e:	89 3c 24             	mov    %edi,(%esp)
c0029331:	89 e9                	mov    %ebp,%ecx
c0029333:	89 da                	mov    %ebx,%edx
c0029335:	89 f0                	mov    %esi,%eax
c0029337:	e8 c8 f9 ff ff       	call   c0028d04 <is_sorted>
c002933c:	84 c0                	test   %al,%al
c002933e:	75 2c                	jne    c002936c <list_sort+0x199>
c0029340:	c7 44 24 10 38 fd 02 	movl   $0xc002fd38,0x10(%esp)
c0029347:	c0 
c0029348:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002934f:	c0 
c0029350:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c0029357:	c0 
c0029358:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
c002935f:	00 
c0029360:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029367:	e8 17 f6 ff ff       	call   c0028983 <debug_panic>
  ASSERT (is_sorted (a1b0, b1, less, aux));
c002936c:	89 3c 24             	mov    %edi,(%esp)
c002936f:	89 e9                	mov    %ebp,%ecx
c0029371:	8b 54 24 18          	mov    0x18(%esp),%edx
c0029375:	89 d8                	mov    %ebx,%eax
c0029377:	e8 88 f9 ff ff       	call   c0028d04 <is_sorted>
c002937c:	84 c0                	test   %al,%al
c002937e:	75 6b                	jne    c00293eb <list_sort+0x218>
c0029380:	c7 44 24 10 58 fd 02 	movl   $0xc002fd58,0x10(%esp)
c0029387:	c0 
c0029388:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002938f:	c0 
c0029390:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c0029397:	c0 
c0029398:	c7 44 24 04 86 01 00 	movl   $0x186,0x4(%esp)
c002939f:	00 
c00293a0:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00293a7:	e8 d7 f5 ff ff       	call   c0028983 <debug_panic>
    if (!less (a1b0, a0, aux)) 
c00293ac:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00293b0:	89 74 24 04          	mov    %esi,0x4(%esp)
c00293b4:	89 1c 24             	mov    %ebx,(%esp)
c00293b7:	ff d5                	call   *%ebp
c00293b9:	84 c0                	test   %al,%al
c00293bb:	75 0c                	jne    c00293c9 <list_sort+0x1f6>
      a0 = list_next (a0);
c00293bd:	89 34 24             	mov    %esi,(%esp)
c00293c0:	e8 1a f7 ff ff       	call   c0028adf <list_next>
c00293c5:	89 c6                	mov    %eax,%esi
c00293c7:	eb 22                	jmp    c00293eb <list_sort+0x218>
        a1b0 = list_next (a1b0);
c00293c9:	89 1c 24             	mov    %ebx,(%esp)
c00293cc:	e8 0e f7 ff ff       	call   c0028adf <list_next>
c00293d1:	89 c3                	mov    %eax,%ebx
        list_splice (a0, list_prev (a1b0), a1b0);
c00293d3:	89 04 24             	mov    %eax,(%esp)
c00293d6:	e8 d4 f7 ff ff       	call   c0028baf <list_prev>
c00293db:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00293df:	89 44 24 04          	mov    %eax,0x4(%esp)
c00293e3:	89 34 24             	mov    %esi,(%esp)
c00293e6:	e8 bb fa ff ff       	call   c0028ea6 <list_splice>
  while (a0 != a1b0 && a1b0 != b1)
c00293eb:	39 5c 24 18          	cmp    %ebx,0x18(%esp)
c00293ef:	74 04                	je     c00293f5 <list_sort+0x222>
c00293f1:	39 f3                	cmp    %esi,%ebx
c00293f3:	75 b7                	jne    c00293ac <list_sort+0x1d9>
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c00293f5:	8b 74 24 18          	mov    0x18(%esp),%esi
c00293f9:	8b 44 24 40          	mov    0x40(%esp),%eax
c00293fd:	89 04 24             	mov    %eax,(%esp)
c0029400:	e8 2e f7 ff ff       	call   c0028b33 <list_end>
c0029405:	39 f0                	cmp    %esi,%eax
c0029407:	0f 85 53 fe ff ff    	jne    c0029260 <list_sort+0x8d>

          /* Merge the runs. */
          inplace_merge (a0, a1b0, b1, less, aux);
        }
    }
  while (output_run_cnt > 1);
c002940d:	83 7c 24 1c 01       	cmpl   $0x1,0x1c(%esp)
c0029412:	0f 87 2d fe ff ff    	ja     c0029245 <list_sort+0x72>

  ASSERT (is_sorted (list_begin (list), list_end (list), less, aux));
c0029418:	8b 44 24 40          	mov    0x40(%esp),%eax
c002941c:	89 04 24             	mov    %eax,(%esp)
c002941f:	e8 0f f7 ff ff       	call   c0028b33 <list_end>
c0029424:	89 c3                	mov    %eax,%ebx
c0029426:	8b 44 24 40          	mov    0x40(%esp),%eax
c002942a:	89 04 24             	mov    %eax,(%esp)
c002942d:	e8 6f f6 ff ff       	call   c0028aa1 <list_begin>
c0029432:	89 3c 24             	mov    %edi,(%esp)
c0029435:	89 e9                	mov    %ebp,%ecx
c0029437:	89 da                	mov    %ebx,%edx
c0029439:	e8 c6 f8 ff ff       	call   c0028d04 <is_sorted>
c002943e:	84 c0                	test   %al,%al
c0029440:	75 2c                	jne    c002946e <list_sort+0x29b>
c0029442:	c7 44 24 10 78 fd 02 	movl   $0xc002fd78,0x10(%esp)
c0029449:	c0 
c002944a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029451:	c0 
c0029452:	c7 44 24 08 d0 dc 02 	movl   $0xc002dcd0,0x8(%esp)
c0029459:	c0 
c002945a:	c7 44 24 04 b8 01 00 	movl   $0x1b8,0x4(%esp)
c0029461:	00 
c0029462:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029469:	e8 15 f5 ff ff       	call   c0028983 <debug_panic>
}
c002946e:	83 c4 2c             	add    $0x2c,%esp
c0029471:	5b                   	pop    %ebx
c0029472:	5e                   	pop    %esi
c0029473:	5f                   	pop    %edi
c0029474:	5d                   	pop    %ebp
c0029475:	c3                   	ret    

c0029476 <list_insert_ordered>:
   sorted according to LESS given auxiliary data AUX.
   Runs in O(n) average case in the number of elements in LIST. */
void
list_insert_ordered (struct list *list, struct list_elem *elem,
                     list_less_func *less, void *aux)
{
c0029476:	55                   	push   %ebp
c0029477:	57                   	push   %edi
c0029478:	56                   	push   %esi
c0029479:	53                   	push   %ebx
c002947a:	83 ec 2c             	sub    $0x2c,%esp
c002947d:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029481:	8b 7c 24 44          	mov    0x44(%esp),%edi
c0029485:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *e;

  ASSERT (list != NULL);
c0029489:	85 f6                	test   %esi,%esi
c002948b:	75 2c                	jne    c00294b9 <list_insert_ordered+0x43>
c002948d:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0029494:	c0 
c0029495:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002949c:	c0 
c002949d:	c7 44 24 08 9e dc 02 	movl   $0xc002dc9e,0x8(%esp)
c00294a4:	c0 
c00294a5:	c7 44 24 04 c4 01 00 	movl   $0x1c4,0x4(%esp)
c00294ac:	00 
c00294ad:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00294b4:	e8 ca f4 ff ff       	call   c0028983 <debug_panic>
  ASSERT (elem != NULL);
c00294b9:	85 ff                	test   %edi,%edi
c00294bb:	75 2c                	jne    c00294e9 <list_insert_ordered+0x73>
c00294bd:	c7 44 24 10 3f fc 02 	movl   $0xc002fc3f,0x10(%esp)
c00294c4:	c0 
c00294c5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00294cc:	c0 
c00294cd:	c7 44 24 08 9e dc 02 	movl   $0xc002dc9e,0x8(%esp)
c00294d4:	c0 
c00294d5:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
c00294dc:	00 
c00294dd:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00294e4:	e8 9a f4 ff ff       	call   c0028983 <debug_panic>
  ASSERT (less != NULL);
c00294e9:	85 ed                	test   %ebp,%ebp
c00294eb:	75 2c                	jne    c0029519 <list_insert_ordered+0xa3>
c00294ed:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c00294f4:	c0 
c00294f5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00294fc:	c0 
c00294fd:	c7 44 24 08 9e dc 02 	movl   $0xc002dc9e,0x8(%esp)
c0029504:	c0 
c0029505:	c7 44 24 04 c6 01 00 	movl   $0x1c6,0x4(%esp)
c002950c:	00 
c002950d:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029514:	e8 6a f4 ff ff       	call   c0028983 <debug_panic>

  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029519:	89 34 24             	mov    %esi,(%esp)
c002951c:	e8 80 f5 ff ff       	call   c0028aa1 <list_begin>
c0029521:	89 c3                	mov    %eax,%ebx
c0029523:	eb 1f                	jmp    c0029544 <list_insert_ordered+0xce>
    if (less (elem, e, aux))
c0029525:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029529:	89 44 24 08          	mov    %eax,0x8(%esp)
c002952d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029531:	89 3c 24             	mov    %edi,(%esp)
c0029534:	ff d5                	call   *%ebp
c0029536:	84 c0                	test   %al,%al
c0029538:	75 16                	jne    c0029550 <list_insert_ordered+0xda>
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c002953a:	89 1c 24             	mov    %ebx,(%esp)
c002953d:	e8 9d f5 ff ff       	call   c0028adf <list_next>
c0029542:	89 c3                	mov    %eax,%ebx
c0029544:	89 34 24             	mov    %esi,(%esp)
c0029547:	e8 e7 f5 ff ff       	call   c0028b33 <list_end>
c002954c:	39 d8                	cmp    %ebx,%eax
c002954e:	75 d5                	jne    c0029525 <list_insert_ordered+0xaf>
      break;
  return list_insert (e, elem);
c0029550:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029554:	89 1c 24             	mov    %ebx,(%esp)
c0029557:	e8 b5 f8 ff ff       	call   c0028e11 <list_insert>
}
c002955c:	83 c4 2c             	add    $0x2c,%esp
c002955f:	5b                   	pop    %ebx
c0029560:	5e                   	pop    %esi
c0029561:	5f                   	pop    %edi
c0029562:	5d                   	pop    %ebp
c0029563:	c3                   	ret    

c0029564 <list_unique>:
   given auxiliary data AUX.  If DUPLICATES is non-null, then the
   elements from LIST are appended to DUPLICATES. */
void
list_unique (struct list *list, struct list *duplicates,
             list_less_func *less, void *aux)
{
c0029564:	55                   	push   %ebp
c0029565:	57                   	push   %edi
c0029566:	56                   	push   %esi
c0029567:	53                   	push   %ebx
c0029568:	83 ec 2c             	sub    $0x2c,%esp
c002956b:	8b 7c 24 40          	mov    0x40(%esp),%edi
c002956f:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *elem, *next;

  ASSERT (list != NULL);
c0029573:	85 ff                	test   %edi,%edi
c0029575:	75 2c                	jne    c00295a3 <list_unique+0x3f>
c0029577:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c002957e:	c0 
c002957f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029586:	c0 
c0029587:	c7 44 24 08 92 dc 02 	movl   $0xc002dc92,0x8(%esp)
c002958e:	c0 
c002958f:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
c0029596:	00 
c0029597:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c002959e:	e8 e0 f3 ff ff       	call   c0028983 <debug_panic>
  ASSERT (less != NULL);
c00295a3:	85 ed                	test   %ebp,%ebp
c00295a5:	75 2c                	jne    c00295d3 <list_unique+0x6f>
c00295a7:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c00295ae:	c0 
c00295af:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00295b6:	c0 
c00295b7:	c7 44 24 08 92 dc 02 	movl   $0xc002dc92,0x8(%esp)
c00295be:	c0 
c00295bf:	c7 44 24 04 d9 01 00 	movl   $0x1d9,0x4(%esp)
c00295c6:	00 
c00295c7:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00295ce:	e8 b0 f3 ff ff       	call   c0028983 <debug_panic>
  if (list_empty (list))
c00295d3:	89 3c 24             	mov    %edi,(%esp)
c00295d6:	e8 ab fa ff ff       	call   c0029086 <list_empty>
c00295db:	84 c0                	test   %al,%al
c00295dd:	75 73                	jne    c0029652 <list_unique+0xee>
    return;

  elem = list_begin (list);
c00295df:	89 3c 24             	mov    %edi,(%esp)
c00295e2:	e8 ba f4 ff ff       	call   c0028aa1 <list_begin>
c00295e7:	89 c6                	mov    %eax,%esi
  while ((next = list_next (elem)) != list_end (list))
c00295e9:	eb 51                	jmp    c002963c <list_unique+0xd8>
    if (!less (elem, next, aux) && !less (next, elem, aux)) 
c00295eb:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c00295ef:	89 44 24 08          	mov    %eax,0x8(%esp)
c00295f3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00295f7:	89 34 24             	mov    %esi,(%esp)
c00295fa:	ff d5                	call   *%ebp
c00295fc:	84 c0                	test   %al,%al
c00295fe:	75 3a                	jne    c002963a <list_unique+0xd6>
c0029600:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029604:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029608:	89 74 24 04          	mov    %esi,0x4(%esp)
c002960c:	89 1c 24             	mov    %ebx,(%esp)
c002960f:	ff d5                	call   *%ebp
c0029611:	84 c0                	test   %al,%al
c0029613:	75 25                	jne    c002963a <list_unique+0xd6>
      {
        list_remove (next);
c0029615:	89 1c 24             	mov    %ebx,(%esp)
c0029618:	e8 d7 f9 ff ff       	call   c0028ff4 <list_remove>
        if (duplicates != NULL)
c002961d:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c0029622:	74 14                	je     c0029638 <list_unique+0xd4>
          list_push_back (duplicates, next);
c0029624:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029628:	8b 44 24 44          	mov    0x44(%esp),%eax
c002962c:	89 04 24             	mov    %eax,(%esp)
c002962f:	e8 9d f9 ff ff       	call   c0028fd1 <list_push_back>
c0029634:	89 f3                	mov    %esi,%ebx
c0029636:	eb 02                	jmp    c002963a <list_unique+0xd6>
c0029638:	89 f3                	mov    %esi,%ebx
c002963a:	89 de                	mov    %ebx,%esi
  while ((next = list_next (elem)) != list_end (list))
c002963c:	89 34 24             	mov    %esi,(%esp)
c002963f:	e8 9b f4 ff ff       	call   c0028adf <list_next>
c0029644:	89 c3                	mov    %eax,%ebx
c0029646:	89 3c 24             	mov    %edi,(%esp)
c0029649:	e8 e5 f4 ff ff       	call   c0028b33 <list_end>
c002964e:	39 c3                	cmp    %eax,%ebx
c0029650:	75 99                	jne    c00295eb <list_unique+0x87>
      }
    else
      elem = next;
}
c0029652:	83 c4 2c             	add    $0x2c,%esp
c0029655:	5b                   	pop    %ebx
c0029656:	5e                   	pop    %esi
c0029657:	5f                   	pop    %edi
c0029658:	5d                   	pop    %ebp
c0029659:	c3                   	ret    

c002965a <list_max>:
   to LESS given auxiliary data AUX.  If there is more than one
   maximum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_max (struct list *list, list_less_func *less, void *aux)
{
c002965a:	55                   	push   %ebp
c002965b:	57                   	push   %edi
c002965c:	56                   	push   %esi
c002965d:	53                   	push   %ebx
c002965e:	83 ec 1c             	sub    $0x1c,%esp
c0029661:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0029665:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *max = list_begin (list);
c0029669:	89 3c 24             	mov    %edi,(%esp)
c002966c:	e8 30 f4 ff ff       	call   c0028aa1 <list_begin>
c0029671:	89 c6                	mov    %eax,%esi
  if (max != list_end (list)) 
c0029673:	89 3c 24             	mov    %edi,(%esp)
c0029676:	e8 b8 f4 ff ff       	call   c0028b33 <list_end>
c002967b:	39 f0                	cmp    %esi,%eax
c002967d:	74 36                	je     c00296b5 <list_max+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c002967f:	89 34 24             	mov    %esi,(%esp)
c0029682:	e8 58 f4 ff ff       	call   c0028adf <list_next>
c0029687:	89 c3                	mov    %eax,%ebx
c0029689:	eb 1e                	jmp    c00296a9 <list_max+0x4f>
        if (less (max, e, aux))
c002968b:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002968f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029693:	89 34 24             	mov    %esi,(%esp)
c0029696:	ff 54 24 34          	call   *0x34(%esp)
c002969a:	84 c0                	test   %al,%al
          max = e; 
c002969c:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c002969f:	89 1c 24             	mov    %ebx,(%esp)
c00296a2:	e8 38 f4 ff ff       	call   c0028adf <list_next>
c00296a7:	89 c3                	mov    %eax,%ebx
c00296a9:	89 3c 24             	mov    %edi,(%esp)
c00296ac:	e8 82 f4 ff ff       	call   c0028b33 <list_end>
c00296b1:	39 d8                	cmp    %ebx,%eax
c00296b3:	75 d6                	jne    c002968b <list_max+0x31>
    }
  return max;
}
c00296b5:	89 f0                	mov    %esi,%eax
c00296b7:	83 c4 1c             	add    $0x1c,%esp
c00296ba:	5b                   	pop    %ebx
c00296bb:	5e                   	pop    %esi
c00296bc:	5f                   	pop    %edi
c00296bd:	5d                   	pop    %ebp
c00296be:	c3                   	ret    

c00296bf <list_min>:
   to LESS given auxiliary data AUX.  If there is more than one
   minimum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_min (struct list *list, list_less_func *less, void *aux)
{
c00296bf:	55                   	push   %ebp
c00296c0:	57                   	push   %edi
c00296c1:	56                   	push   %esi
c00296c2:	53                   	push   %ebx
c00296c3:	83 ec 1c             	sub    $0x1c,%esp
c00296c6:	8b 7c 24 30          	mov    0x30(%esp),%edi
c00296ca:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *min = list_begin (list);
c00296ce:	89 3c 24             	mov    %edi,(%esp)
c00296d1:	e8 cb f3 ff ff       	call   c0028aa1 <list_begin>
c00296d6:	89 c6                	mov    %eax,%esi
  if (min != list_end (list)) 
c00296d8:	89 3c 24             	mov    %edi,(%esp)
c00296db:	e8 53 f4 ff ff       	call   c0028b33 <list_end>
c00296e0:	39 f0                	cmp    %esi,%eax
c00296e2:	74 36                	je     c002971a <list_min+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c00296e4:	89 34 24             	mov    %esi,(%esp)
c00296e7:	e8 f3 f3 ff ff       	call   c0028adf <list_next>
c00296ec:	89 c3                	mov    %eax,%ebx
c00296ee:	eb 1e                	jmp    c002970e <list_min+0x4f>
        if (less (e, min, aux))
c00296f0:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00296f4:	89 74 24 04          	mov    %esi,0x4(%esp)
c00296f8:	89 1c 24             	mov    %ebx,(%esp)
c00296fb:	ff 54 24 34          	call   *0x34(%esp)
c00296ff:	84 c0                	test   %al,%al
          min = e; 
c0029701:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c0029704:	89 1c 24             	mov    %ebx,(%esp)
c0029707:	e8 d3 f3 ff ff       	call   c0028adf <list_next>
c002970c:	89 c3                	mov    %eax,%ebx
c002970e:	89 3c 24             	mov    %edi,(%esp)
c0029711:	e8 1d f4 ff ff       	call   c0028b33 <list_end>
c0029716:	39 d8                	cmp    %ebx,%eax
c0029718:	75 d6                	jne    c00296f0 <list_min+0x31>
    }
  return min;
}
c002971a:	89 f0                	mov    %esi,%eax
c002971c:	83 c4 1c             	add    $0x1c,%esp
c002971f:	5b                   	pop    %ebx
c0029720:	5e                   	pop    %esi
c0029721:	5f                   	pop    %edi
c0029722:	5d                   	pop    %ebp
c0029723:	c3                   	ret    
c0029724:	90                   	nop
c0029725:	90                   	nop
c0029726:	90                   	nop
c0029727:	90                   	nop
c0029728:	90                   	nop
c0029729:	90                   	nop
c002972a:	90                   	nop
c002972b:	90                   	nop
c002972c:	90                   	nop
c002972d:	90                   	nop
c002972e:	90                   	nop
c002972f:	90                   	nop

c0029730 <bitmap_buf_size>:

/* Returns the number of elements required for BIT_CNT bits. */
static inline size_t
elem_cnt (size_t bit_cnt)
{
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029730:	8b 44 24 04          	mov    0x4(%esp),%eax
c0029734:	83 c0 1f             	add    $0x1f,%eax
c0029737:	c1 e8 05             	shr    $0x5,%eax
/* Returns the number of bytes required to accomodate a bitmap
   with BIT_CNT bits (for use with bitmap_create_in_buf()). */
size_t
bitmap_buf_size (size_t bit_cnt) 
{
  return sizeof (struct bitmap) + byte_cnt (bit_cnt);
c002973a:	8d 04 85 08 00 00 00 	lea    0x8(,%eax,4),%eax
}
c0029741:	c3                   	ret    

c0029742 <bitmap_destroy>:

/* Destroys bitmap B, freeing its storage.
   Not for use on bitmaps created by bitmap_create_in_buf(). */
void
bitmap_destroy (struct bitmap *b) 
{
c0029742:	53                   	push   %ebx
c0029743:	83 ec 18             	sub    $0x18,%esp
c0029746:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (b != NULL) 
c002974a:	85 db                	test   %ebx,%ebx
c002974c:	74 13                	je     c0029761 <bitmap_destroy+0x1f>
    {
      free (b->bits);
c002974e:	8b 43 04             	mov    0x4(%ebx),%eax
c0029751:	89 04 24             	mov    %eax,(%esp)
c0029754:	e8 52 a4 ff ff       	call   c0023bab <free>
      free (b);
c0029759:	89 1c 24             	mov    %ebx,(%esp)
c002975c:	e8 4a a4 ff ff       	call   c0023bab <free>
    }
}
c0029761:	83 c4 18             	add    $0x18,%esp
c0029764:	5b                   	pop    %ebx
c0029765:	c3                   	ret    

c0029766 <bitmap_size>:

/* Returns the number of bits in B. */
size_t
bitmap_size (const struct bitmap *b)
{
  return b->bit_cnt;
c0029766:	8b 44 24 04          	mov    0x4(%esp),%eax
c002976a:	8b 00                	mov    (%eax),%eax
}
c002976c:	c3                   	ret    

c002976d <bitmap_mark>:
}

/* Atomically sets the bit numbered BIT_IDX in B to true. */
void
bitmap_mark (struct bitmap *b, size_t bit_idx) 
{
c002976d:	53                   	push   %ebx
c002976e:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c0029772:	89 ca                	mov    %ecx,%edx
c0029774:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] |= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the OR instruction in [IA32-v2b]. */
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029777:	8b 44 24 08          	mov    0x8(%esp),%eax
c002977b:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002977e:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029783:	d3 e3                	shl    %cl,%ebx
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029785:	09 1c 90             	or     %ebx,(%eax,%edx,4)
}
c0029788:	5b                   	pop    %ebx
c0029789:	c3                   	ret    

c002978a <bitmap_reset>:

/* Atomically sets the bit numbered BIT_IDX in B to false. */
void
bitmap_reset (struct bitmap *b, size_t bit_idx) 
{
c002978a:	53                   	push   %ebx
c002978b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002978f:	89 ca                	mov    %ecx,%edx
c0029791:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] &= ~mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the AND instruction in [IA32-v2a]. */
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c0029794:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029798:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002979b:	bb 01 00 00 00       	mov    $0x1,%ebx
c00297a0:	d3 e3                	shl    %cl,%ebx
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c00297a2:	f7 d3                	not    %ebx
c00297a4:	21 1c 90             	and    %ebx,(%eax,%edx,4)
}
c00297a7:	5b                   	pop    %ebx
c00297a8:	c3                   	ret    

c00297a9 <bitmap_set>:
{
c00297a9:	83 ec 2c             	sub    $0x2c,%esp
c00297ac:	8b 44 24 30          	mov    0x30(%esp),%eax
c00297b0:	8b 54 24 34          	mov    0x34(%esp),%edx
c00297b4:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  ASSERT (b != NULL);
c00297b8:	85 c0                	test   %eax,%eax
c00297ba:	75 2c                	jne    c00297e8 <bitmap_set+0x3f>
c00297bc:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c00297c3:	c0 
c00297c4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00297cb:	c0 
c00297cc:	c7 44 24 08 c7 dd 02 	movl   $0xc002ddc7,0x8(%esp)
c00297d3:	c0 
c00297d4:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
c00297db:	00 
c00297dc:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c00297e3:	e8 9b f1 ff ff       	call   c0028983 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c00297e8:	39 10                	cmp    %edx,(%eax)
c00297ea:	77 2c                	ja     c0029818 <bitmap_set+0x6f>
c00297ec:	c7 44 24 10 cc fd 02 	movl   $0xc002fdcc,0x10(%esp)
c00297f3:	c0 
c00297f4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00297fb:	c0 
c00297fc:	c7 44 24 08 c7 dd 02 	movl   $0xc002ddc7,0x8(%esp)
c0029803:	c0 
c0029804:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
c002980b:	00 
c002980c:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029813:	e8 6b f1 ff ff       	call   c0028983 <debug_panic>
  if (value)
c0029818:	84 c9                	test   %cl,%cl
c002981a:	74 0e                	je     c002982a <bitmap_set+0x81>
    bitmap_mark (b, idx);
c002981c:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029820:	89 04 24             	mov    %eax,(%esp)
c0029823:	e8 45 ff ff ff       	call   c002976d <bitmap_mark>
c0029828:	eb 0c                	jmp    c0029836 <bitmap_set+0x8d>
    bitmap_reset (b, idx);
c002982a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002982e:	89 04 24             	mov    %eax,(%esp)
c0029831:	e8 54 ff ff ff       	call   c002978a <bitmap_reset>
}
c0029836:	83 c4 2c             	add    $0x2c,%esp
c0029839:	c3                   	ret    

c002983a <bitmap_flip>:
/* Atomically toggles the bit numbered IDX in B;
   that is, if it is true, makes it false,
   and if it is false, makes it true. */
void
bitmap_flip (struct bitmap *b, size_t bit_idx) 
{
c002983a:	53                   	push   %ebx
c002983b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002983f:	89 ca                	mov    %ecx,%edx
c0029841:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] ^= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the XOR instruction in [IA32-v2b]. */
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029844:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029848:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002984b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029850:	d3 e3                	shl    %cl,%ebx
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029852:	31 1c 90             	xor    %ebx,(%eax,%edx,4)
}
c0029855:	5b                   	pop    %ebx
c0029856:	c3                   	ret    

c0029857 <bitmap_test>:

/* Returns the value of the bit numbered IDX in B. */
bool
bitmap_test (const struct bitmap *b, size_t idx) 
{
c0029857:	53                   	push   %ebx
c0029858:	83 ec 28             	sub    $0x28,%esp
c002985b:	8b 44 24 30          	mov    0x30(%esp),%eax
c002985f:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (b != NULL);
c0029863:	85 c0                	test   %eax,%eax
c0029865:	75 2c                	jne    c0029893 <bitmap_test+0x3c>
c0029867:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c002986e:	c0 
c002986f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029876:	c0 
c0029877:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c002987e:	c0 
c002987f:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
c0029886:	00 
c0029887:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c002988e:	e8 f0 f0 ff ff       	call   c0028983 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c0029893:	39 08                	cmp    %ecx,(%eax)
c0029895:	77 2c                	ja     c00298c3 <bitmap_test+0x6c>
c0029897:	c7 44 24 10 cc fd 02 	movl   $0xc002fdcc,0x10(%esp)
c002989e:	c0 
c002989f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00298a6:	c0 
c00298a7:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c00298ae:	c0 
c00298af:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c00298b6:	00 
c00298b7:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c00298be:	e8 c0 f0 ff ff       	call   c0028983 <debug_panic>
  return bit_idx / ELEM_BITS;
c00298c3:	89 ca                	mov    %ecx,%edx
c00298c5:	c1 ea 05             	shr    $0x5,%edx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00298c8:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00298cb:	bb 01 00 00 00       	mov    $0x1,%ebx
c00298d0:	d3 e3                	shl    %cl,%ebx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00298d2:	85 1c 90             	test   %ebx,(%eax,%edx,4)
c00298d5:	0f 95 c0             	setne  %al
}
c00298d8:	83 c4 28             	add    $0x28,%esp
c00298db:	5b                   	pop    %ebx
c00298dc:	c3                   	ret    

c00298dd <bitmap_set_multiple>:
}

/* Sets the CNT bits starting at START in B to VALUE. */
void
bitmap_set_multiple (struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c00298dd:	55                   	push   %ebp
c00298de:	57                   	push   %edi
c00298df:	56                   	push   %esi
c00298e0:	53                   	push   %ebx
c00298e1:	83 ec 2c             	sub    $0x2c,%esp
c00298e4:	8b 74 24 40          	mov    0x40(%esp),%esi
c00298e8:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c00298ec:	8b 44 24 48          	mov    0x48(%esp),%eax
c00298f0:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  size_t i;
  
  ASSERT (b != NULL);
c00298f5:	85 f6                	test   %esi,%esi
c00298f7:	75 2c                	jne    c0029925 <bitmap_set_multiple+0x48>
c00298f9:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0029900:	c0 
c0029901:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029908:	c0 
c0029909:	c7 44 24 08 98 dd 02 	movl   $0xc002dd98,0x8(%esp)
c0029910:	c0 
c0029911:	c7 44 24 04 de 00 00 	movl   $0xde,0x4(%esp)
c0029918:	00 
c0029919:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029920:	e8 5e f0 ff ff       	call   c0028983 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029925:	8b 16                	mov    (%esi),%edx
c0029927:	39 da                	cmp    %ebx,%edx
c0029929:	73 2c                	jae    c0029957 <bitmap_set_multiple+0x7a>
c002992b:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029932:	c0 
c0029933:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002993a:	c0 
c002993b:	c7 44 24 08 98 dd 02 	movl   $0xc002dd98,0x8(%esp)
c0029942:	c0 
c0029943:	c7 44 24 04 df 00 00 	movl   $0xdf,0x4(%esp)
c002994a:	00 
c002994b:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029952:	e8 2c f0 ff ff       	call   c0028983 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029957:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c002995a:	39 fa                	cmp    %edi,%edx
c002995c:	72 09                	jb     c0029967 <bitmap_set_multiple+0x8a>

  for (i = 0; i < cnt; i++)
    bitmap_set (b, start + i, value);
c002995e:	0f b6 e9             	movzbl %cl,%ebp
  for (i = 0; i < cnt; i++)
c0029961:	85 c0                	test   %eax,%eax
c0029963:	75 2e                	jne    c0029993 <bitmap_set_multiple+0xb6>
c0029965:	eb 43                	jmp    c00299aa <bitmap_set_multiple+0xcd>
  ASSERT (start + cnt <= b->bit_cnt);
c0029967:	c7 44 24 10 f1 fd 02 	movl   $0xc002fdf1,0x10(%esp)
c002996e:	c0 
c002996f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029976:	c0 
c0029977:	c7 44 24 08 98 dd 02 	movl   $0xc002dd98,0x8(%esp)
c002997e:	c0 
c002997f:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c0029986:	00 
c0029987:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c002998e:	e8 f0 ef ff ff       	call   c0028983 <debug_panic>
    bitmap_set (b, start + i, value);
c0029993:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0029997:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002999b:	89 34 24             	mov    %esi,(%esp)
c002999e:	e8 06 fe ff ff       	call   c00297a9 <bitmap_set>
c00299a3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c00299a6:	39 df                	cmp    %ebx,%edi
c00299a8:	75 e9                	jne    c0029993 <bitmap_set_multiple+0xb6>
}
c00299aa:	83 c4 2c             	add    $0x2c,%esp
c00299ad:	5b                   	pop    %ebx
c00299ae:	5e                   	pop    %esi
c00299af:	5f                   	pop    %edi
c00299b0:	5d                   	pop    %ebp
c00299b1:	c3                   	ret    

c00299b2 <bitmap_set_all>:
{
c00299b2:	83 ec 2c             	sub    $0x2c,%esp
c00299b5:	8b 44 24 30          	mov    0x30(%esp),%eax
c00299b9:	8b 54 24 34          	mov    0x34(%esp),%edx
  ASSERT (b != NULL);
c00299bd:	85 c0                	test   %eax,%eax
c00299bf:	75 2c                	jne    c00299ed <bitmap_set_all+0x3b>
c00299c1:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c00299c8:	c0 
c00299c9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00299d0:	c0 
c00299d1:	c7 44 24 08 ac dd 02 	movl   $0xc002ddac,0x8(%esp)
c00299d8:	c0 
c00299d9:	c7 44 24 04 d3 00 00 	movl   $0xd3,0x4(%esp)
c00299e0:	00 
c00299e1:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c00299e8:	e8 96 ef ff ff       	call   c0028983 <debug_panic>
  bitmap_set_multiple (b, 0, bitmap_size (b), value);
c00299ed:	0f b6 d2             	movzbl %dl,%edx
c00299f0:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00299f4:	8b 10                	mov    (%eax),%edx
c00299f6:	89 54 24 08          	mov    %edx,0x8(%esp)
c00299fa:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a01:	00 
c0029a02:	89 04 24             	mov    %eax,(%esp)
c0029a05:	e8 d3 fe ff ff       	call   c00298dd <bitmap_set_multiple>
}
c0029a0a:	83 c4 2c             	add    $0x2c,%esp
c0029a0d:	c3                   	ret    

c0029a0e <bitmap_create>:
{
c0029a0e:	56                   	push   %esi
c0029a0f:	53                   	push   %ebx
c0029a10:	83 ec 14             	sub    $0x14,%esp
c0029a13:	8b 74 24 20          	mov    0x20(%esp),%esi
  struct bitmap *b = malloc (sizeof *b);
c0029a17:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c0029a1e:	e8 01 a0 ff ff       	call   c0023a24 <malloc>
c0029a23:	89 c3                	mov    %eax,%ebx
  if (b != NULL)
c0029a25:	85 c0                	test   %eax,%eax
c0029a27:	74 41                	je     c0029a6a <bitmap_create+0x5c>
      b->bit_cnt = bit_cnt;
c0029a29:	89 30                	mov    %esi,(%eax)
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029a2b:	8d 46 1f             	lea    0x1f(%esi),%eax
c0029a2e:	c1 e8 05             	shr    $0x5,%eax
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029a31:	c1 e0 02             	shl    $0x2,%eax
      b->bits = malloc (byte_cnt (bit_cnt));
c0029a34:	89 04 24             	mov    %eax,(%esp)
c0029a37:	e8 e8 9f ff ff       	call   c0023a24 <malloc>
c0029a3c:	89 43 04             	mov    %eax,0x4(%ebx)
      if (b->bits != NULL || bit_cnt == 0)
c0029a3f:	85 c0                	test   %eax,%eax
c0029a41:	75 04                	jne    c0029a47 <bitmap_create+0x39>
c0029a43:	85 f6                	test   %esi,%esi
c0029a45:	75 14                	jne    c0029a5b <bitmap_create+0x4d>
          bitmap_set_all (b, false);
c0029a47:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a4e:	00 
c0029a4f:	89 1c 24             	mov    %ebx,(%esp)
c0029a52:	e8 5b ff ff ff       	call   c00299b2 <bitmap_set_all>
          return b;
c0029a57:	89 d8                	mov    %ebx,%eax
c0029a59:	eb 14                	jmp    c0029a6f <bitmap_create+0x61>
      free (b);
c0029a5b:	89 1c 24             	mov    %ebx,(%esp)
c0029a5e:	e8 48 a1 ff ff       	call   c0023bab <free>
  return NULL;
c0029a63:	b8 00 00 00 00       	mov    $0x0,%eax
c0029a68:	eb 05                	jmp    c0029a6f <bitmap_create+0x61>
c0029a6a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029a6f:	83 c4 14             	add    $0x14,%esp
c0029a72:	5b                   	pop    %ebx
c0029a73:	5e                   	pop    %esi
c0029a74:	c3                   	ret    

c0029a75 <bitmap_create_in_buf>:
{
c0029a75:	56                   	push   %esi
c0029a76:	53                   	push   %ebx
c0029a77:	83 ec 24             	sub    $0x24,%esp
c0029a7a:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029a7e:	8b 5c 24 34          	mov    0x34(%esp),%ebx
  ASSERT (block_size >= bitmap_buf_size (bit_cnt));
c0029a82:	89 34 24             	mov    %esi,(%esp)
c0029a85:	e8 a6 fc ff ff       	call   c0029730 <bitmap_buf_size>
c0029a8a:	3b 44 24 38          	cmp    0x38(%esp),%eax
c0029a8e:	76 2c                	jbe    c0029abc <bitmap_create_in_buf+0x47>
c0029a90:	c7 44 24 10 0c fe 02 	movl   $0xc002fe0c,0x10(%esp)
c0029a97:	c0 
c0029a98:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029a9f:	c0 
c0029aa0:	c7 44 24 08 d2 dd 02 	movl   $0xc002ddd2,0x8(%esp)
c0029aa7:	c0 
c0029aa8:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
c0029aaf:	00 
c0029ab0:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029ab7:	e8 c7 ee ff ff       	call   c0028983 <debug_panic>
  b->bit_cnt = bit_cnt;
c0029abc:	89 33                	mov    %esi,(%ebx)
  b->bits = (elem_type *) (b + 1);
c0029abe:	8d 43 08             	lea    0x8(%ebx),%eax
c0029ac1:	89 43 04             	mov    %eax,0x4(%ebx)
  bitmap_set_all (b, false);
c0029ac4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029acb:	00 
c0029acc:	89 1c 24             	mov    %ebx,(%esp)
c0029acf:	e8 de fe ff ff       	call   c00299b2 <bitmap_set_all>
}
c0029ad4:	89 d8                	mov    %ebx,%eax
c0029ad6:	83 c4 24             	add    $0x24,%esp
c0029ad9:	5b                   	pop    %ebx
c0029ada:	5e                   	pop    %esi
c0029adb:	c3                   	ret    

c0029adc <bitmap_count>:

/* Returns the number of bits in B between START and START + CNT,
   exclusive, that are set to VALUE. */
size_t
bitmap_count (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029adc:	55                   	push   %ebp
c0029add:	57                   	push   %edi
c0029ade:	56                   	push   %esi
c0029adf:	53                   	push   %ebx
c0029ae0:	83 ec 2c             	sub    $0x2c,%esp
c0029ae3:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0029ae7:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029aeb:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029aef:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
c0029af4:	88 4c 24 1f          	mov    %cl,0x1f(%esp)
  size_t i, value_cnt;

  ASSERT (b != NULL);
c0029af8:	85 ff                	test   %edi,%edi
c0029afa:	75 2c                	jne    c0029b28 <bitmap_count+0x4c>
c0029afc:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0029b03:	c0 
c0029b04:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029b0b:	c0 
c0029b0c:	c7 44 24 08 8b dd 02 	movl   $0xc002dd8b,0x8(%esp)
c0029b13:	c0 
c0029b14:	c7 44 24 04 ed 00 00 	movl   $0xed,0x4(%esp)
c0029b1b:	00 
c0029b1c:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029b23:	e8 5b ee ff ff       	call   c0028983 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029b28:	8b 17                	mov    (%edi),%edx
c0029b2a:	39 da                	cmp    %ebx,%edx
c0029b2c:	73 2c                	jae    c0029b5a <bitmap_count+0x7e>
c0029b2e:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029b35:	c0 
c0029b36:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029b3d:	c0 
c0029b3e:	c7 44 24 08 8b dd 02 	movl   $0xc002dd8b,0x8(%esp)
c0029b45:	c0 
c0029b46:	c7 44 24 04 ee 00 00 	movl   $0xee,0x4(%esp)
c0029b4d:	00 
c0029b4e:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029b55:	e8 29 ee ff ff       	call   c0028983 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b5a:	8d 2c 03             	lea    (%ebx,%eax,1),%ebp
c0029b5d:	39 ea                	cmp    %ebp,%edx
c0029b5f:	72 0b                	jb     c0029b6c <bitmap_count+0x90>

  value_cnt = 0;
  for (i = 0; i < cnt; i++)
c0029b61:	be 00 00 00 00       	mov    $0x0,%esi
c0029b66:	85 c0                	test   %eax,%eax
c0029b68:	75 2e                	jne    c0029b98 <bitmap_count+0xbc>
c0029b6a:	eb 4b                	jmp    c0029bb7 <bitmap_count+0xdb>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b6c:	c7 44 24 10 f1 fd 02 	movl   $0xc002fdf1,0x10(%esp)
c0029b73:	c0 
c0029b74:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029b7b:	c0 
c0029b7c:	c7 44 24 08 8b dd 02 	movl   $0xc002dd8b,0x8(%esp)
c0029b83:	c0 
c0029b84:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0029b8b:	00 
c0029b8c:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029b93:	e8 eb ed ff ff       	call   c0028983 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029b98:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029b9c:	89 3c 24             	mov    %edi,(%esp)
c0029b9f:	e8 b3 fc ff ff       	call   c0029857 <bitmap_test>
      value_cnt++;
c0029ba4:	3a 44 24 1f          	cmp    0x1f(%esp),%al
c0029ba8:	0f 94 c0             	sete   %al
c0029bab:	0f b6 c0             	movzbl %al,%eax
c0029bae:	01 c6                	add    %eax,%esi
c0029bb0:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029bb3:	39 dd                	cmp    %ebx,%ebp
c0029bb5:	75 e1                	jne    c0029b98 <bitmap_count+0xbc>
  return value_cnt;
}
c0029bb7:	89 f0                	mov    %esi,%eax
c0029bb9:	83 c4 2c             	add    $0x2c,%esp
c0029bbc:	5b                   	pop    %ebx
c0029bbd:	5e                   	pop    %esi
c0029bbe:	5f                   	pop    %edi
c0029bbf:	5d                   	pop    %ebp
c0029bc0:	c3                   	ret    

c0029bc1 <bitmap_contains>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to VALUE, and false otherwise. */
bool
bitmap_contains (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029bc1:	55                   	push   %ebp
c0029bc2:	57                   	push   %edi
c0029bc3:	56                   	push   %esi
c0029bc4:	53                   	push   %ebx
c0029bc5:	83 ec 2c             	sub    $0x2c,%esp
c0029bc8:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029bcc:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029bd0:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029bd4:	0f b6 6c 24 4c       	movzbl 0x4c(%esp),%ebp
  size_t i;
  
  ASSERT (b != NULL);
c0029bd9:	85 f6                	test   %esi,%esi
c0029bdb:	75 2c                	jne    c0029c09 <bitmap_contains+0x48>
c0029bdd:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0029be4:	c0 
c0029be5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029bec:	c0 
c0029bed:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0029bf4:	c0 
c0029bf5:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
c0029bfc:	00 
c0029bfd:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029c04:	e8 7a ed ff ff       	call   c0028983 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029c09:	8b 16                	mov    (%esi),%edx
c0029c0b:	39 da                	cmp    %ebx,%edx
c0029c0d:	73 2c                	jae    c0029c3b <bitmap_contains+0x7a>
c0029c0f:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029c16:	c0 
c0029c17:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029c1e:	c0 
c0029c1f:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0029c26:	c0 
c0029c27:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
c0029c2e:	00 
c0029c2f:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029c36:	e8 48 ed ff ff       	call   c0028983 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c3b:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c0029c3e:	39 fa                	cmp    %edi,%edx
c0029c40:	72 06                	jb     c0029c48 <bitmap_contains+0x87>

  for (i = 0; i < cnt; i++)
c0029c42:	85 c0                	test   %eax,%eax
c0029c44:	75 2e                	jne    c0029c74 <bitmap_contains+0xb3>
c0029c46:	eb 53                	jmp    c0029c9b <bitmap_contains+0xda>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c48:	c7 44 24 10 f1 fd 02 	movl   $0xc002fdf1,0x10(%esp)
c0029c4f:	c0 
c0029c50:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029c57:	c0 
c0029c58:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0029c5f:	c0 
c0029c60:	c7 44 24 04 01 01 00 	movl   $0x101,0x4(%esp)
c0029c67:	00 
c0029c68:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029c6f:	e8 0f ed ff ff       	call   c0028983 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029c74:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029c78:	89 34 24             	mov    %esi,(%esp)
c0029c7b:	e8 d7 fb ff ff       	call   c0029857 <bitmap_test>
c0029c80:	89 e9                	mov    %ebp,%ecx
c0029c82:	38 c8                	cmp    %cl,%al
c0029c84:	74 09                	je     c0029c8f <bitmap_contains+0xce>
c0029c86:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029c89:	39 df                	cmp    %ebx,%edi
c0029c8b:	75 e7                	jne    c0029c74 <bitmap_contains+0xb3>
c0029c8d:	eb 07                	jmp    c0029c96 <bitmap_contains+0xd5>
      return true;
c0029c8f:	b8 01 00 00 00       	mov    $0x1,%eax
c0029c94:	eb 05                	jmp    c0029c9b <bitmap_contains+0xda>
  return false;
c0029c96:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029c9b:	83 c4 2c             	add    $0x2c,%esp
c0029c9e:	5b                   	pop    %ebx
c0029c9f:	5e                   	pop    %esi
c0029ca0:	5f                   	pop    %edi
c0029ca1:	5d                   	pop    %ebp
c0029ca2:	c3                   	ret    

c0029ca3 <bitmap_any>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_any (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029ca3:	83 ec 1c             	sub    $0x1c,%esp
  return bitmap_contains (b, start, cnt, true);
c0029ca6:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029cad:	00 
c0029cae:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029cb2:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029cb6:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029cba:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029cbe:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029cc2:	89 04 24             	mov    %eax,(%esp)
c0029cc5:	e8 f7 fe ff ff       	call   c0029bc1 <bitmap_contains>
}
c0029cca:	83 c4 1c             	add    $0x1c,%esp
c0029ccd:	c3                   	ret    

c0029cce <bitmap_none>:

/* Returns true if no bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_none (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cce:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, true);
c0029cd1:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029cd8:	00 
c0029cd9:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029cdd:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029ce1:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029ce5:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029ce9:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029ced:	89 04 24             	mov    %eax,(%esp)
c0029cf0:	e8 cc fe ff ff       	call   c0029bc1 <bitmap_contains>
c0029cf5:	83 f0 01             	xor    $0x1,%eax
}
c0029cf8:	83 c4 1c             	add    $0x1c,%esp
c0029cfb:	c3                   	ret    

c0029cfc <bitmap_all>:

/* Returns true if every bit in B between START and START + CNT,
   exclusive, is set to true, and false otherwise. */
bool
bitmap_all (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cfc:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, false);
c0029cff:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029d06:	00 
c0029d07:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029d0b:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029d0f:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029d13:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029d17:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029d1b:	89 04 24             	mov    %eax,(%esp)
c0029d1e:	e8 9e fe ff ff       	call   c0029bc1 <bitmap_contains>
c0029d23:	83 f0 01             	xor    $0x1,%eax
}
c0029d26:	83 c4 1c             	add    $0x1c,%esp
c0029d29:	c3                   	ret    

c0029d2a <bitmap_scan>:
   consecutive bits in B at or after START that are all set to
   VALUE.
   If there is no such group, returns BITMAP_ERROR. */
size_t
bitmap_scan (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029d2a:	55                   	push   %ebp
c0029d2b:	57                   	push   %edi
c0029d2c:	56                   	push   %esi
c0029d2d:	53                   	push   %ebx
c0029d2e:	83 ec 2c             	sub    $0x2c,%esp
c0029d31:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029d35:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029d39:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0029d3d:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  ASSERT (b != NULL);
c0029d42:	85 f6                	test   %esi,%esi
c0029d44:	75 2c                	jne    c0029d72 <bitmap_scan+0x48>
c0029d46:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0029d4d:	c0 
c0029d4e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029d55:	c0 
c0029d56:	c7 44 24 08 6f dd 02 	movl   $0xc002dd6f,0x8(%esp)
c0029d5d:	c0 
c0029d5e:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0029d65:	00 
c0029d66:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029d6d:	e8 11 ec ff ff       	call   c0028983 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029d72:	8b 16                	mov    (%esi),%edx
c0029d74:	39 da                	cmp    %ebx,%edx
c0029d76:	73 2c                	jae    c0029da4 <bitmap_scan+0x7a>
c0029d78:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029d7f:	c0 
c0029d80:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029d87:	c0 
c0029d88:	c7 44 24 08 6f dd 02 	movl   $0xc002dd6f,0x8(%esp)
c0029d8f:	c0 
c0029d90:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0029d97:	00 
c0029d98:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029d9f:	e8 df eb ff ff       	call   c0028983 <debug_panic>
      size_t i;
      for (i = start; i <= last; i++)
        if (!bitmap_contains (b, i, cnt, !value))
          return i; 
    }
  return BITMAP_ERROR;
c0029da4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  if (cnt <= b->bit_cnt) 
c0029da9:	39 fa                	cmp    %edi,%edx
c0029dab:	72 45                	jb     c0029df2 <bitmap_scan+0xc8>
      size_t last = b->bit_cnt - cnt;
c0029dad:	29 fa                	sub    %edi,%edx
c0029daf:	89 54 24 1c          	mov    %edx,0x1c(%esp)
      for (i = start; i <= last; i++)
c0029db3:	39 d3                	cmp    %edx,%ebx
c0029db5:	77 2b                	ja     c0029de2 <bitmap_scan+0xb8>
        if (!bitmap_contains (b, i, cnt, !value))
c0029db7:	83 f1 01             	xor    $0x1,%ecx
c0029dba:	0f b6 e9             	movzbl %cl,%ebp
c0029dbd:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029dc1:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029dc5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029dc9:	89 34 24             	mov    %esi,(%esp)
c0029dcc:	e8 f0 fd ff ff       	call   c0029bc1 <bitmap_contains>
c0029dd1:	84 c0                	test   %al,%al
c0029dd3:	74 14                	je     c0029de9 <bitmap_scan+0xbf>
      for (i = start; i <= last; i++)
c0029dd5:	83 c3 01             	add    $0x1,%ebx
c0029dd8:	39 5c 24 1c          	cmp    %ebx,0x1c(%esp)
c0029ddc:	73 df                	jae    c0029dbd <bitmap_scan+0x93>
c0029dde:	66 90                	xchg   %ax,%ax
c0029de0:	eb 0b                	jmp    c0029ded <bitmap_scan+0xc3>
  return BITMAP_ERROR;
c0029de2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0029de7:	eb 09                	jmp    c0029df2 <bitmap_scan+0xc8>
c0029de9:	89 d8                	mov    %ebx,%eax
c0029deb:	eb 05                	jmp    c0029df2 <bitmap_scan+0xc8>
c0029ded:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0029df2:	83 c4 2c             	add    $0x2c,%esp
c0029df5:	5b                   	pop    %ebx
c0029df6:	5e                   	pop    %esi
c0029df7:	5f                   	pop    %edi
c0029df8:	5d                   	pop    %ebp
c0029df9:	c3                   	ret    

c0029dfa <bitmap_scan_and_flip>:
   If CNT is zero, returns 0.
   Bits are set atomically, but testing bits is not atomic with
   setting them. */
size_t
bitmap_scan_and_flip (struct bitmap *b, size_t start, size_t cnt, bool value)
{
c0029dfa:	55                   	push   %ebp
c0029dfb:	57                   	push   %edi
c0029dfc:	56                   	push   %esi
c0029dfd:	53                   	push   %ebx
c0029dfe:	83 ec 1c             	sub    $0x1c,%esp
c0029e01:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029e05:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0029e09:	8b 6c 24 3c          	mov    0x3c(%esp),%ebp
  size_t idx = bitmap_scan (b, start, cnt, value);
c0029e0d:	89 e8                	mov    %ebp,%eax
c0029e0f:	0f b6 c0             	movzbl %al,%eax
c0029e12:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0029e16:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e1a:	8b 44 24 34          	mov    0x34(%esp),%eax
c0029e1e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e22:	89 34 24             	mov    %esi,(%esp)
c0029e25:	e8 00 ff ff ff       	call   c0029d2a <bitmap_scan>
c0029e2a:	89 c3                	mov    %eax,%ebx
  if (idx != BITMAP_ERROR) 
c0029e2c:	83 f8 ff             	cmp    $0xffffffff,%eax
c0029e2f:	74 1c                	je     c0029e4d <bitmap_scan_and_flip+0x53>
    bitmap_set_multiple (b, idx, cnt, !value);
c0029e31:	89 e8                	mov    %ebp,%eax
c0029e33:	83 f0 01             	xor    $0x1,%eax
c0029e36:	0f b6 e8             	movzbl %al,%ebp
c0029e39:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029e3d:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e41:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029e45:	89 34 24             	mov    %esi,(%esp)
c0029e48:	e8 90 fa ff ff       	call   c00298dd <bitmap_set_multiple>
  return idx;
}
c0029e4d:	89 d8                	mov    %ebx,%eax
c0029e4f:	83 c4 1c             	add    $0x1c,%esp
c0029e52:	5b                   	pop    %ebx
c0029e53:	5e                   	pop    %esi
c0029e54:	5f                   	pop    %edi
c0029e55:	5d                   	pop    %ebp
c0029e56:	c3                   	ret    

c0029e57 <bitmap_dump>:
/* Debugging. */

/* Dumps the contents of B to the console as hexadecimal. */
void
bitmap_dump (const struct bitmap *b) 
{
c0029e57:	83 ec 1c             	sub    $0x1c,%esp
c0029e5a:	8b 44 24 20          	mov    0x20(%esp),%eax
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e5e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029e65:	00 
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029e66:	8b 08                	mov    (%eax),%ecx
c0029e68:	8d 51 1f             	lea    0x1f(%ecx),%edx
c0029e6b:	c1 ea 05             	shr    $0x5,%edx
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029e6e:	c1 e2 02             	shl    $0x2,%edx
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e71:	89 54 24 08          	mov    %edx,0x8(%esp)
c0029e75:	8b 40 04             	mov    0x4(%eax),%eax
c0029e78:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e7c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0029e83:	e8 d2 d3 ff ff       	call   c002725a <hex_dump>
}
c0029e88:	83 c4 1c             	add    $0x1c,%esp
c0029e8b:	c3                   	ret    
c0029e8c:	90                   	nop
c0029e8d:	90                   	nop
c0029e8e:	90                   	nop
c0029e8f:	90                   	nop

c0029e90 <find_bucket>:
}

/* Returns the bucket in H that E belongs in. */
static struct list *
find_bucket (struct hash *h, struct hash_elem *e) 
{
c0029e90:	53                   	push   %ebx
c0029e91:	83 ec 18             	sub    $0x18,%esp
c0029e94:	89 c3                	mov    %eax,%ebx
  size_t bucket_idx = h->hash (e, h->aux) & (h->bucket_cnt - 1);
c0029e96:	8b 40 14             	mov    0x14(%eax),%eax
c0029e99:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e9d:	89 14 24             	mov    %edx,(%esp)
c0029ea0:	ff 53 0c             	call   *0xc(%ebx)
c0029ea3:	8b 4b 04             	mov    0x4(%ebx),%ecx
c0029ea6:	8d 51 ff             	lea    -0x1(%ecx),%edx
c0029ea9:	21 d0                	and    %edx,%eax
  return &h->buckets[bucket_idx];
c0029eab:	c1 e0 04             	shl    $0x4,%eax
c0029eae:	03 43 08             	add    0x8(%ebx),%eax
}
c0029eb1:	83 c4 18             	add    $0x18,%esp
c0029eb4:	5b                   	pop    %ebx
c0029eb5:	c3                   	ret    

c0029eb6 <find_elem>:

/* Searches BUCKET in H for a hash element equal to E.  Returns
   it if found or a null pointer otherwise. */
static struct hash_elem *
find_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
c0029eb6:	55                   	push   %ebp
c0029eb7:	57                   	push   %edi
c0029eb8:	56                   	push   %esi
c0029eb9:	53                   	push   %ebx
c0029eba:	83 ec 1c             	sub    $0x1c,%esp
c0029ebd:	89 c6                	mov    %eax,%esi
c0029ebf:	89 d5                	mov    %edx,%ebp
c0029ec1:	89 cf                	mov    %ecx,%edi
  struct list_elem *i;

  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029ec3:	89 14 24             	mov    %edx,(%esp)
c0029ec6:	e8 d6 eb ff ff       	call   c0028aa1 <list_begin>
c0029ecb:	89 c3                	mov    %eax,%ebx
c0029ecd:	eb 34                	jmp    c0029f03 <find_elem+0x4d>
    {
      struct hash_elem *hi = list_elem_to_hash_elem (i);
      if (!h->less (hi, e, h->aux) && !h->less (e, hi, h->aux))
c0029ecf:	8b 46 14             	mov    0x14(%esi),%eax
c0029ed2:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029ed6:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029eda:	89 1c 24             	mov    %ebx,(%esp)
c0029edd:	ff 56 10             	call   *0x10(%esi)
c0029ee0:	84 c0                	test   %al,%al
c0029ee2:	75 15                	jne    c0029ef9 <find_elem+0x43>
c0029ee4:	8b 46 14             	mov    0x14(%esi),%eax
c0029ee7:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029eeb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029eef:	89 3c 24             	mov    %edi,(%esp)
c0029ef2:	ff 56 10             	call   *0x10(%esi)
c0029ef5:	84 c0                	test   %al,%al
c0029ef7:	74 1d                	je     c0029f16 <find_elem+0x60>
  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029ef9:	89 1c 24             	mov    %ebx,(%esp)
c0029efc:	e8 de eb ff ff       	call   c0028adf <list_next>
c0029f01:	89 c3                	mov    %eax,%ebx
c0029f03:	89 2c 24             	mov    %ebp,(%esp)
c0029f06:	e8 28 ec ff ff       	call   c0028b33 <list_end>
c0029f0b:	39 d8                	cmp    %ebx,%eax
c0029f0d:	75 c0                	jne    c0029ecf <find_elem+0x19>
        return hi; 
    }
  return NULL;
c0029f0f:	b8 00 00 00 00       	mov    $0x0,%eax
c0029f14:	eb 02                	jmp    c0029f18 <find_elem+0x62>
c0029f16:	89 d8                	mov    %ebx,%eax
}
c0029f18:	83 c4 1c             	add    $0x1c,%esp
c0029f1b:	5b                   	pop    %ebx
c0029f1c:	5e                   	pop    %esi
c0029f1d:	5f                   	pop    %edi
c0029f1e:	5d                   	pop    %ebp
c0029f1f:	c3                   	ret    

c0029f20 <rehash>:
   ideal.  This function can fail because of an out-of-memory
   condition, but that'll just make hash accesses less efficient;
   we can still continue. */
static void
rehash (struct hash *h) 
{
c0029f20:	55                   	push   %ebp
c0029f21:	57                   	push   %edi
c0029f22:	56                   	push   %esi
c0029f23:	53                   	push   %ebx
c0029f24:	83 ec 3c             	sub    $0x3c,%esp
c0029f27:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  size_t old_bucket_cnt, new_bucket_cnt;
  struct list *new_buckets, *old_buckets;
  size_t i;

  ASSERT (h != NULL);
c0029f2b:	85 c0                	test   %eax,%eax
c0029f2d:	75 2c                	jne    c0029f5b <rehash+0x3b>
c0029f2f:	c7 44 24 10 34 fe 02 	movl   $0xc002fe34,0x10(%esp)
c0029f36:	c0 
c0029f37:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029f3e:	c0 
c0029f3f:	c7 44 24 08 1e de 02 	movl   $0xc002de1e,0x8(%esp)
c0029f46:	c0 
c0029f47:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0029f4e:	00 
c0029f4f:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c0029f56:	e8 28 ea ff ff       	call   c0028983 <debug_panic>

  /* Save old bucket info for later use. */
  old_buckets = h->buckets;
c0029f5b:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029f5f:	8b 48 08             	mov    0x8(%eax),%ecx
c0029f62:	89 4c 24 2c          	mov    %ecx,0x2c(%esp)
  old_bucket_cnt = h->bucket_cnt;
c0029f66:	8b 48 04             	mov    0x4(%eax),%ecx
c0029f69:	89 4c 24 28          	mov    %ecx,0x28(%esp)

  /* Calculate the number of buckets to use now.
     We want one bucket for about every BEST_ELEMS_PER_BUCKET.
     We must have at least four buckets, and the number of
     buckets must be a power of 2. */
  new_bucket_cnt = h->elem_cnt / BEST_ELEMS_PER_BUCKET;
c0029f6d:	8b 00                	mov    (%eax),%eax
c0029f6f:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029f73:	89 c3                	mov    %eax,%ebx
c0029f75:	d1 eb                	shr    %ebx
  if (new_bucket_cnt < 4)
    new_bucket_cnt = 4;
c0029f77:	83 fb 03             	cmp    $0x3,%ebx
c0029f7a:	b8 04 00 00 00       	mov    $0x4,%eax
c0029f7f:	0f 46 d8             	cmovbe %eax,%ebx
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029f82:	85 db                	test   %ebx,%ebx
c0029f84:	0f 84 d2 00 00 00    	je     c002a05c <rehash+0x13c>
  return x & (x - 1);
c0029f8a:	8d 43 ff             	lea    -0x1(%ebx),%eax
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029f8d:	85 d8                	test   %ebx,%eax
c0029f8f:	0f 85 c7 00 00 00    	jne    c002a05c <rehash+0x13c>
c0029f95:	e9 cc 00 00 00       	jmp    c002a066 <rehash+0x146>
  /* Don't do anything if the bucket count wouldn't change. */
  if (new_bucket_cnt == old_bucket_cnt)
    return;

  /* Allocate new buckets and initialize them as empty. */
  new_buckets = malloc (sizeof *new_buckets * new_bucket_cnt);
c0029f9a:	89 d8                	mov    %ebx,%eax
c0029f9c:	c1 e0 04             	shl    $0x4,%eax
c0029f9f:	89 04 24             	mov    %eax,(%esp)
c0029fa2:	e8 7d 9a ff ff       	call   c0023a24 <malloc>
c0029fa7:	89 c5                	mov    %eax,%ebp
  if (new_buckets == NULL) 
c0029fa9:	85 c0                	test   %eax,%eax
c0029fab:	0f 84 bf 00 00 00    	je     c002a070 <rehash+0x150>
      /* Allocation failed.  This means that use of the hash table will
         be less efficient.  However, it is still usable, so
         there's no reason for it to be an error. */
      return;
    }
  for (i = 0; i < new_bucket_cnt; i++) 
c0029fb1:	85 db                	test   %ebx,%ebx
c0029fb3:	74 19                	je     c0029fce <rehash+0xae>
c0029fb5:	89 c7                	mov    %eax,%edi
c0029fb7:	be 00 00 00 00       	mov    $0x0,%esi
    list_init (&new_buckets[i]);
c0029fbc:	89 3c 24             	mov    %edi,(%esp)
c0029fbf:	e8 8c ea ff ff       	call   c0028a50 <list_init>
  for (i = 0; i < new_bucket_cnt; i++) 
c0029fc4:	83 c6 01             	add    $0x1,%esi
c0029fc7:	83 c7 10             	add    $0x10,%edi
c0029fca:	39 de                	cmp    %ebx,%esi
c0029fcc:	75 ee                	jne    c0029fbc <rehash+0x9c>

  /* Install new bucket info. */
  h->buckets = new_buckets;
c0029fce:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029fd2:	89 68 08             	mov    %ebp,0x8(%eax)
  h->bucket_cnt = new_bucket_cnt;
c0029fd5:	89 58 04             	mov    %ebx,0x4(%eax)

  /* Move each old element into the appropriate new bucket. */
  for (i = 0; i < old_bucket_cnt; i++) 
c0029fd8:	83 7c 24 28 00       	cmpl   $0x0,0x28(%esp)
c0029fdd:	74 6f                	je     c002a04e <rehash+0x12e>
c0029fdf:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c0029fe3:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029fe7:	c7 44 24 24 00 00 00 	movl   $0x0,0x24(%esp)
c0029fee:	00 
    {
      struct list *old_bucket;
      struct list_elem *elem, *next;

      old_bucket = &old_buckets[i];
c0029fef:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029ff3:	89 c5                	mov    %eax,%ebp
      for (elem = list_begin (old_bucket);
c0029ff5:	89 04 24             	mov    %eax,(%esp)
c0029ff8:	e8 a4 ea ff ff       	call   c0028aa1 <list_begin>
c0029ffd:	89 c3                	mov    %eax,%ebx
c0029fff:	eb 2d                	jmp    c002a02e <rehash+0x10e>
           elem != list_end (old_bucket); elem = next) 
        {
          struct list *new_bucket
c002a001:	89 da                	mov    %ebx,%edx
c002a003:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a007:	e8 84 fe ff ff       	call   c0029e90 <find_bucket>
c002a00c:	89 c7                	mov    %eax,%edi
            = find_bucket (h, list_elem_to_hash_elem (elem));
          next = list_next (elem);
c002a00e:	89 1c 24             	mov    %ebx,(%esp)
c002a011:	e8 c9 ea ff ff       	call   c0028adf <list_next>
c002a016:	89 c6                	mov    %eax,%esi
          list_remove (elem);
c002a018:	89 1c 24             	mov    %ebx,(%esp)
c002a01b:	e8 d4 ef ff ff       	call   c0028ff4 <list_remove>
          list_push_front (new_bucket, elem);
c002a020:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002a024:	89 3c 24             	mov    %edi,(%esp)
c002a027:	e8 82 ef ff ff       	call   c0028fae <list_push_front>
           elem != list_end (old_bucket); elem = next) 
c002a02c:	89 f3                	mov    %esi,%ebx
c002a02e:	89 2c 24             	mov    %ebp,(%esp)
c002a031:	e8 fd ea ff ff       	call   c0028b33 <list_end>
      for (elem = list_begin (old_bucket);
c002a036:	39 d8                	cmp    %ebx,%eax
c002a038:	75 c7                	jne    c002a001 <rehash+0xe1>
  for (i = 0; i < old_bucket_cnt; i++) 
c002a03a:	83 44 24 24 01       	addl   $0x1,0x24(%esp)
c002a03f:	83 44 24 20 10       	addl   $0x10,0x20(%esp)
c002a044:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a048:	39 44 24 24          	cmp    %eax,0x24(%esp)
c002a04c:	75 a1                	jne    c0029fef <rehash+0xcf>
        }
    }

  free (old_buckets);
c002a04e:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a052:	89 04 24             	mov    %eax,(%esp)
c002a055:	e8 51 9b ff ff       	call   c0023bab <free>
c002a05a:	eb 14                	jmp    c002a070 <rehash+0x150>
  return x & (x - 1);
c002a05c:	8d 43 ff             	lea    -0x1(%ebx),%eax
c002a05f:	21 c3                	and    %eax,%ebx
c002a061:	e9 1c ff ff ff       	jmp    c0029f82 <rehash+0x62>
  if (new_bucket_cnt == old_bucket_cnt)
c002a066:	3b 5c 24 28          	cmp    0x28(%esp),%ebx
c002a06a:	0f 85 2a ff ff ff    	jne    c0029f9a <rehash+0x7a>
}
c002a070:	83 c4 3c             	add    $0x3c,%esp
c002a073:	5b                   	pop    %ebx
c002a074:	5e                   	pop    %esi
c002a075:	5f                   	pop    %edi
c002a076:	5d                   	pop    %ebp
c002a077:	c3                   	ret    

c002a078 <hash_clear>:
{
c002a078:	55                   	push   %ebp
c002a079:	57                   	push   %edi
c002a07a:	56                   	push   %esi
c002a07b:	53                   	push   %ebx
c002a07c:	83 ec 1c             	sub    $0x1c,%esp
c002a07f:	8b 74 24 30          	mov    0x30(%esp),%esi
c002a083:	8b 7c 24 34          	mov    0x34(%esp),%edi
  for (i = 0; i < h->bucket_cnt; i++) 
c002a087:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c002a08b:	74 43                	je     c002a0d0 <hash_clear+0x58>
c002a08d:	bd 00 00 00 00       	mov    $0x0,%ebp
c002a092:	89 eb                	mov    %ebp,%ebx
c002a094:	c1 e3 04             	shl    $0x4,%ebx
      struct list *bucket = &h->buckets[i];
c002a097:	03 5e 08             	add    0x8(%esi),%ebx
      if (destructor != NULL) 
c002a09a:	85 ff                	test   %edi,%edi
c002a09c:	75 16                	jne    c002a0b4 <hash_clear+0x3c>
c002a09e:	eb 20                	jmp    c002a0c0 <hash_clear+0x48>
            struct list_elem *list_elem = list_pop_front (bucket);
c002a0a0:	89 1c 24             	mov    %ebx,(%esp)
c002a0a3:	e8 4c f0 ff ff       	call   c00290f4 <list_pop_front>
            destructor (hash_elem, h->aux);
c002a0a8:	8b 56 14             	mov    0x14(%esi),%edx
c002a0ab:	89 54 24 04          	mov    %edx,0x4(%esp)
c002a0af:	89 04 24             	mov    %eax,(%esp)
c002a0b2:	ff d7                	call   *%edi
        while (!list_empty (bucket)) 
c002a0b4:	89 1c 24             	mov    %ebx,(%esp)
c002a0b7:	e8 ca ef ff ff       	call   c0029086 <list_empty>
c002a0bc:	84 c0                	test   %al,%al
c002a0be:	74 e0                	je     c002a0a0 <hash_clear+0x28>
      list_init (bucket); 
c002a0c0:	89 1c 24             	mov    %ebx,(%esp)
c002a0c3:	e8 88 e9 ff ff       	call   c0028a50 <list_init>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a0c8:	83 c5 01             	add    $0x1,%ebp
c002a0cb:	39 6e 04             	cmp    %ebp,0x4(%esi)
c002a0ce:	77 c2                	ja     c002a092 <hash_clear+0x1a>
  h->elem_cnt = 0;
c002a0d0:	c7 06 00 00 00 00    	movl   $0x0,(%esi)
}
c002a0d6:	83 c4 1c             	add    $0x1c,%esp
c002a0d9:	5b                   	pop    %ebx
c002a0da:	5e                   	pop    %esi
c002a0db:	5f                   	pop    %edi
c002a0dc:	5d                   	pop    %ebp
c002a0dd:	c3                   	ret    

c002a0de <hash_init>:
{
c002a0de:	53                   	push   %ebx
c002a0df:	83 ec 18             	sub    $0x18,%esp
c002a0e2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  h->elem_cnt = 0;
c002a0e6:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  h->bucket_cnt = 4;
c002a0ec:	c7 43 04 04 00 00 00 	movl   $0x4,0x4(%ebx)
  h->buckets = malloc (sizeof *h->buckets * h->bucket_cnt);
c002a0f3:	c7 04 24 40 00 00 00 	movl   $0x40,(%esp)
c002a0fa:	e8 25 99 ff ff       	call   c0023a24 <malloc>
c002a0ff:	89 c2                	mov    %eax,%edx
c002a101:	89 43 08             	mov    %eax,0x8(%ebx)
  h->hash = hash;
c002a104:	8b 44 24 24          	mov    0x24(%esp),%eax
c002a108:	89 43 0c             	mov    %eax,0xc(%ebx)
  h->less = less;
c002a10b:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a10f:	89 43 10             	mov    %eax,0x10(%ebx)
  h->aux = aux;
c002a112:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a116:	89 43 14             	mov    %eax,0x14(%ebx)
    return false;
c002a119:	b8 00 00 00 00       	mov    $0x0,%eax
  if (h->buckets != NULL) 
c002a11e:	85 d2                	test   %edx,%edx
c002a120:	74 15                	je     c002a137 <hash_init+0x59>
      hash_clear (h, NULL);
c002a122:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002a129:	00 
c002a12a:	89 1c 24             	mov    %ebx,(%esp)
c002a12d:	e8 46 ff ff ff       	call   c002a078 <hash_clear>
      return true;
c002a132:	b8 01 00 00 00       	mov    $0x1,%eax
}
c002a137:	83 c4 18             	add    $0x18,%esp
c002a13a:	5b                   	pop    %ebx
c002a13b:	c3                   	ret    

c002a13c <hash_destroy>:
{
c002a13c:	53                   	push   %ebx
c002a13d:	83 ec 18             	sub    $0x18,%esp
c002a140:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a144:	8b 44 24 24          	mov    0x24(%esp),%eax
  if (destructor != NULL)
c002a148:	85 c0                	test   %eax,%eax
c002a14a:	74 0c                	je     c002a158 <hash_destroy+0x1c>
    hash_clear (h, destructor);
c002a14c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a150:	89 1c 24             	mov    %ebx,(%esp)
c002a153:	e8 20 ff ff ff       	call   c002a078 <hash_clear>
  free (h->buckets);
c002a158:	8b 43 08             	mov    0x8(%ebx),%eax
c002a15b:	89 04 24             	mov    %eax,(%esp)
c002a15e:	e8 48 9a ff ff       	call   c0023bab <free>
}
c002a163:	83 c4 18             	add    $0x18,%esp
c002a166:	5b                   	pop    %ebx
c002a167:	c3                   	ret    

c002a168 <hash_insert>:
{
c002a168:	55                   	push   %ebp
c002a169:	57                   	push   %edi
c002a16a:	56                   	push   %esi
c002a16b:	53                   	push   %ebx
c002a16c:	83 ec 1c             	sub    $0x1c,%esp
c002a16f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a173:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a177:	89 f2                	mov    %esi,%edx
c002a179:	89 d8                	mov    %ebx,%eax
c002a17b:	e8 10 fd ff ff       	call   c0029e90 <find_bucket>
c002a180:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a182:	89 f1                	mov    %esi,%ecx
c002a184:	89 c2                	mov    %eax,%edx
c002a186:	89 d8                	mov    %ebx,%eax
c002a188:	e8 29 fd ff ff       	call   c0029eb6 <find_elem>
c002a18d:	89 c7                	mov    %eax,%edi
  if (old == NULL) 
c002a18f:	85 c0                	test   %eax,%eax
c002a191:	75 0f                	jne    c002a1a2 <hash_insert+0x3a>

/* Inserts E into BUCKET (in hash table H). */
static void
insert_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
  h->elem_cnt++;
c002a193:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a196:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a19a:	89 2c 24             	mov    %ebp,(%esp)
c002a19d:	e8 0c ee ff ff       	call   c0028fae <list_push_front>
  rehash (h);
c002a1a2:	89 d8                	mov    %ebx,%eax
c002a1a4:	e8 77 fd ff ff       	call   c0029f20 <rehash>
}
c002a1a9:	89 f8                	mov    %edi,%eax
c002a1ab:	83 c4 1c             	add    $0x1c,%esp
c002a1ae:	5b                   	pop    %ebx
c002a1af:	5e                   	pop    %esi
c002a1b0:	5f                   	pop    %edi
c002a1b1:	5d                   	pop    %ebp
c002a1b2:	c3                   	ret    

c002a1b3 <hash_replace>:
{
c002a1b3:	55                   	push   %ebp
c002a1b4:	57                   	push   %edi
c002a1b5:	56                   	push   %esi
c002a1b6:	53                   	push   %ebx
c002a1b7:	83 ec 1c             	sub    $0x1c,%esp
c002a1ba:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a1be:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a1c2:	89 f2                	mov    %esi,%edx
c002a1c4:	89 d8                	mov    %ebx,%eax
c002a1c6:	e8 c5 fc ff ff       	call   c0029e90 <find_bucket>
c002a1cb:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a1cd:	89 f1                	mov    %esi,%ecx
c002a1cf:	89 c2                	mov    %eax,%edx
c002a1d1:	89 d8                	mov    %ebx,%eax
c002a1d3:	e8 de fc ff ff       	call   c0029eb6 <find_elem>
c002a1d8:	89 c7                	mov    %eax,%edi
  if (old != NULL)
c002a1da:	85 c0                	test   %eax,%eax
c002a1dc:	74 0b                	je     c002a1e9 <hash_replace+0x36>

/* Removes E from hash table H. */
static void
remove_elem (struct hash *h, struct hash_elem *e) 
{
  h->elem_cnt--;
c002a1de:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a1e1:	89 04 24             	mov    %eax,(%esp)
c002a1e4:	e8 0b ee ff ff       	call   c0028ff4 <list_remove>
  h->elem_cnt++;
c002a1e9:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a1ec:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a1f0:	89 2c 24             	mov    %ebp,(%esp)
c002a1f3:	e8 b6 ed ff ff       	call   c0028fae <list_push_front>
  rehash (h);
c002a1f8:	89 d8                	mov    %ebx,%eax
c002a1fa:	e8 21 fd ff ff       	call   c0029f20 <rehash>
}
c002a1ff:	89 f8                	mov    %edi,%eax
c002a201:	83 c4 1c             	add    $0x1c,%esp
c002a204:	5b                   	pop    %ebx
c002a205:	5e                   	pop    %esi
c002a206:	5f                   	pop    %edi
c002a207:	5d                   	pop    %ebp
c002a208:	c3                   	ret    

c002a209 <hash_find>:
{
c002a209:	56                   	push   %esi
c002a20a:	53                   	push   %ebx
c002a20b:	83 ec 04             	sub    $0x4,%esp
c002a20e:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a212:	8b 74 24 14          	mov    0x14(%esp),%esi
  return find_elem (h, find_bucket (h, e), e);
c002a216:	89 f2                	mov    %esi,%edx
c002a218:	89 d8                	mov    %ebx,%eax
c002a21a:	e8 71 fc ff ff       	call   c0029e90 <find_bucket>
c002a21f:	89 f1                	mov    %esi,%ecx
c002a221:	89 c2                	mov    %eax,%edx
c002a223:	89 d8                	mov    %ebx,%eax
c002a225:	e8 8c fc ff ff       	call   c0029eb6 <find_elem>
}
c002a22a:	83 c4 04             	add    $0x4,%esp
c002a22d:	5b                   	pop    %ebx
c002a22e:	5e                   	pop    %esi
c002a22f:	c3                   	ret    

c002a230 <hash_delete>:
{
c002a230:	56                   	push   %esi
c002a231:	53                   	push   %ebx
c002a232:	83 ec 14             	sub    $0x14,%esp
c002a235:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a239:	8b 74 24 24          	mov    0x24(%esp),%esi
  struct hash_elem *found = find_elem (h, find_bucket (h, e), e);
c002a23d:	89 f2                	mov    %esi,%edx
c002a23f:	89 d8                	mov    %ebx,%eax
c002a241:	e8 4a fc ff ff       	call   c0029e90 <find_bucket>
c002a246:	89 f1                	mov    %esi,%ecx
c002a248:	89 c2                	mov    %eax,%edx
c002a24a:	89 d8                	mov    %ebx,%eax
c002a24c:	e8 65 fc ff ff       	call   c0029eb6 <find_elem>
c002a251:	89 c6                	mov    %eax,%esi
  if (found != NULL) 
c002a253:	85 c0                	test   %eax,%eax
c002a255:	74 12                	je     c002a269 <hash_delete+0x39>
  h->elem_cnt--;
c002a257:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a25a:	89 04 24             	mov    %eax,(%esp)
c002a25d:	e8 92 ed ff ff       	call   c0028ff4 <list_remove>
      rehash (h); 
c002a262:	89 d8                	mov    %ebx,%eax
c002a264:	e8 b7 fc ff ff       	call   c0029f20 <rehash>
}
c002a269:	89 f0                	mov    %esi,%eax
c002a26b:	83 c4 14             	add    $0x14,%esp
c002a26e:	5b                   	pop    %ebx
c002a26f:	5e                   	pop    %esi
c002a270:	c3                   	ret    

c002a271 <hash_apply>:
{
c002a271:	55                   	push   %ebp
c002a272:	57                   	push   %edi
c002a273:	56                   	push   %esi
c002a274:	53                   	push   %ebx
c002a275:	83 ec 2c             	sub    $0x2c,%esp
c002a278:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (action != NULL);
c002a27c:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c002a281:	74 10                	je     c002a293 <hash_apply+0x22>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a283:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a28a:	00 
c002a28b:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c002a28f:	75 2e                	jne    c002a2bf <hash_apply+0x4e>
c002a291:	eb 76                	jmp    c002a309 <hash_apply+0x98>
  ASSERT (action != NULL);
c002a293:	c7 44 24 10 56 fe 02 	movl   $0xc002fe56,0x10(%esp)
c002a29a:	c0 
c002a29b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a2a2:	c0 
c002a2a3:	c7 44 24 08 13 de 02 	movl   $0xc002de13,0x8(%esp)
c002a2aa:	c0 
c002a2ab:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
c002a2b2:	00 
c002a2b3:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a2ba:	e8 c4 e6 ff ff       	call   c0028983 <debug_panic>
c002a2bf:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
c002a2c3:	c1 e7 04             	shl    $0x4,%edi
      struct list *bucket = &h->buckets[i];
c002a2c6:	03 7d 08             	add    0x8(%ebp),%edi
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a2c9:	89 3c 24             	mov    %edi,(%esp)
c002a2cc:	e8 d0 e7 ff ff       	call   c0028aa1 <list_begin>
c002a2d1:	89 c3                	mov    %eax,%ebx
c002a2d3:	eb 1a                	jmp    c002a2ef <hash_apply+0x7e>
          next = list_next (elem);
c002a2d5:	89 1c 24             	mov    %ebx,(%esp)
c002a2d8:	e8 02 e8 ff ff       	call   c0028adf <list_next>
c002a2dd:	89 c6                	mov    %eax,%esi
          action (list_elem_to_hash_elem (elem), h->aux);
c002a2df:	8b 45 14             	mov    0x14(%ebp),%eax
c002a2e2:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a2e6:	89 1c 24             	mov    %ebx,(%esp)
c002a2e9:	ff 54 24 44          	call   *0x44(%esp)
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a2ed:	89 f3                	mov    %esi,%ebx
c002a2ef:	89 3c 24             	mov    %edi,(%esp)
c002a2f2:	e8 3c e8 ff ff       	call   c0028b33 <list_end>
c002a2f7:	39 d8                	cmp    %ebx,%eax
c002a2f9:	75 da                	jne    c002a2d5 <hash_apply+0x64>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a2fb:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)
c002a300:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a304:	39 45 04             	cmp    %eax,0x4(%ebp)
c002a307:	77 b6                	ja     c002a2bf <hash_apply+0x4e>
}
c002a309:	83 c4 2c             	add    $0x2c,%esp
c002a30c:	5b                   	pop    %ebx
c002a30d:	5e                   	pop    %esi
c002a30e:	5f                   	pop    %edi
c002a30f:	5d                   	pop    %ebp
c002a310:	c3                   	ret    

c002a311 <hash_first>:
{
c002a311:	53                   	push   %ebx
c002a312:	83 ec 28             	sub    $0x28,%esp
c002a315:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a319:	8b 44 24 34          	mov    0x34(%esp),%eax
  ASSERT (i != NULL);
c002a31d:	85 db                	test   %ebx,%ebx
c002a31f:	75 2c                	jne    c002a34d <hash_first+0x3c>
c002a321:	c7 44 24 10 65 fe 02 	movl   $0xc002fe65,0x10(%esp)
c002a328:	c0 
c002a329:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a330:	c0 
c002a331:	c7 44 24 08 08 de 02 	movl   $0xc002de08,0x8(%esp)
c002a338:	c0 
c002a339:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
c002a340:	00 
c002a341:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a348:	e8 36 e6 ff ff       	call   c0028983 <debug_panic>
  ASSERT (h != NULL);
c002a34d:	85 c0                	test   %eax,%eax
c002a34f:	75 2c                	jne    c002a37d <hash_first+0x6c>
c002a351:	c7 44 24 10 34 fe 02 	movl   $0xc002fe34,0x10(%esp)
c002a358:	c0 
c002a359:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a360:	c0 
c002a361:	c7 44 24 08 08 de 02 	movl   $0xc002de08,0x8(%esp)
c002a368:	c0 
c002a369:	c7 44 24 04 cb 00 00 	movl   $0xcb,0x4(%esp)
c002a370:	00 
c002a371:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a378:	e8 06 e6 ff ff       	call   c0028983 <debug_panic>
  i->hash = h;
c002a37d:	89 03                	mov    %eax,(%ebx)
  i->bucket = i->hash->buckets;
c002a37f:	8b 40 08             	mov    0x8(%eax),%eax
c002a382:	89 43 04             	mov    %eax,0x4(%ebx)
  i->elem = list_elem_to_hash_elem (list_head (i->bucket));
c002a385:	89 04 24             	mov    %eax,(%esp)
c002a388:	e8 0b ea ff ff       	call   c0028d98 <list_head>
c002a38d:	89 43 08             	mov    %eax,0x8(%ebx)
}
c002a390:	83 c4 28             	add    $0x28,%esp
c002a393:	5b                   	pop    %ebx
c002a394:	c3                   	ret    

c002a395 <hash_next>:
{
c002a395:	56                   	push   %esi
c002a396:	53                   	push   %ebx
c002a397:	83 ec 24             	sub    $0x24,%esp
c002a39a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (i != NULL);
c002a39e:	85 db                	test   %ebx,%ebx
c002a3a0:	75 2c                	jne    c002a3ce <hash_next+0x39>
c002a3a2:	c7 44 24 10 65 fe 02 	movl   $0xc002fe65,0x10(%esp)
c002a3a9:	c0 
c002a3aa:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a3b1:	c0 
c002a3b2:	c7 44 24 08 fe dd 02 	movl   $0xc002ddfe,0x8(%esp)
c002a3b9:	c0 
c002a3ba:	c7 44 24 04 dd 00 00 	movl   $0xdd,0x4(%esp)
c002a3c1:	00 
c002a3c2:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a3c9:	e8 b5 e5 ff ff       	call   c0028983 <debug_panic>
  i->elem = list_elem_to_hash_elem (list_next (&i->elem->list_elem));
c002a3ce:	8b 43 08             	mov    0x8(%ebx),%eax
c002a3d1:	89 04 24             	mov    %eax,(%esp)
c002a3d4:	e8 06 e7 ff ff       	call   c0028adf <list_next>
c002a3d9:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a3dc:	eb 2c                	jmp    c002a40a <hash_next+0x75>
      if (++i->bucket >= i->hash->buckets + i->hash->bucket_cnt)
c002a3de:	8b 43 04             	mov    0x4(%ebx),%eax
c002a3e1:	83 c0 10             	add    $0x10,%eax
c002a3e4:	89 43 04             	mov    %eax,0x4(%ebx)
c002a3e7:	8b 13                	mov    (%ebx),%edx
c002a3e9:	8b 4a 04             	mov    0x4(%edx),%ecx
c002a3ec:	c1 e1 04             	shl    $0x4,%ecx
c002a3ef:	03 4a 08             	add    0x8(%edx),%ecx
c002a3f2:	39 c8                	cmp    %ecx,%eax
c002a3f4:	72 09                	jb     c002a3ff <hash_next+0x6a>
          i->elem = NULL;
c002a3f6:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
          break;
c002a3fd:	eb 1d                	jmp    c002a41c <hash_next+0x87>
      i->elem = list_elem_to_hash_elem (list_begin (i->bucket));
c002a3ff:	89 04 24             	mov    %eax,(%esp)
c002a402:	e8 9a e6 ff ff       	call   c0028aa1 <list_begin>
c002a407:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a40a:	8b 73 08             	mov    0x8(%ebx),%esi
c002a40d:	8b 43 04             	mov    0x4(%ebx),%eax
c002a410:	89 04 24             	mov    %eax,(%esp)
c002a413:	e8 1b e7 ff ff       	call   c0028b33 <list_end>
c002a418:	39 c6                	cmp    %eax,%esi
c002a41a:	74 c2                	je     c002a3de <hash_next+0x49>
  return i->elem;
c002a41c:	8b 43 08             	mov    0x8(%ebx),%eax
}
c002a41f:	83 c4 24             	add    $0x24,%esp
c002a422:	5b                   	pop    %ebx
c002a423:	5e                   	pop    %esi
c002a424:	c3                   	ret    

c002a425 <hash_cur>:
  return i->elem;
c002a425:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a429:	8b 40 08             	mov    0x8(%eax),%eax
}
c002a42c:	c3                   	ret    

c002a42d <hash_size>:
  return h->elem_cnt;
c002a42d:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a431:	8b 00                	mov    (%eax),%eax
}
c002a433:	c3                   	ret    

c002a434 <hash_empty>:
  return h->elem_cnt == 0;
c002a434:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a438:	83 38 00             	cmpl   $0x0,(%eax)
c002a43b:	0f 94 c0             	sete   %al
}
c002a43e:	c3                   	ret    

c002a43f <hash_bytes>:
{
c002a43f:	53                   	push   %ebx
c002a440:	83 ec 28             	sub    $0x28,%esp
c002a443:	8b 54 24 30          	mov    0x30(%esp),%edx
c002a447:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (buf != NULL);
c002a44b:	85 d2                	test   %edx,%edx
c002a44d:	74 0e                	je     c002a45d <hash_bytes+0x1e>
c002a44f:	8d 1c 0a             	lea    (%edx,%ecx,1),%ebx
  while (size-- > 0)
c002a452:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a457:	85 c9                	test   %ecx,%ecx
c002a459:	75 2e                	jne    c002a489 <hash_bytes+0x4a>
c002a45b:	eb 3f                	jmp    c002a49c <hash_bytes+0x5d>
  ASSERT (buf != NULL);
c002a45d:	c7 44 24 10 6f fe 02 	movl   $0xc002fe6f,0x10(%esp)
c002a464:	c0 
c002a465:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a46c:	c0 
c002a46d:	c7 44 24 08 f3 dd 02 	movl   $0xc002ddf3,0x8(%esp)
c002a474:	c0 
c002a475:	c7 44 24 04 10 01 00 	movl   $0x110,0x4(%esp)
c002a47c:	00 
c002a47d:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a484:	e8 fa e4 ff ff       	call   c0028983 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *buf++;
c002a489:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a48f:	83 c2 01             	add    $0x1,%edx
c002a492:	0f b6 4a ff          	movzbl -0x1(%edx),%ecx
c002a496:	31 c8                	xor    %ecx,%eax
  while (size-- > 0)
c002a498:	39 da                	cmp    %ebx,%edx
c002a49a:	75 ed                	jne    c002a489 <hash_bytes+0x4a>
} 
c002a49c:	83 c4 28             	add    $0x28,%esp
c002a49f:	5b                   	pop    %ebx
c002a4a0:	c3                   	ret    

c002a4a1 <hash_string>:
{
c002a4a1:	83 ec 2c             	sub    $0x2c,%esp
c002a4a4:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002a4a8:	85 d2                	test   %edx,%edx
c002a4aa:	74 0e                	je     c002a4ba <hash_string+0x19>
  while (*s != '\0')
c002a4ac:	0f b6 0a             	movzbl (%edx),%ecx
c002a4af:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a4b4:	84 c9                	test   %cl,%cl
c002a4b6:	75 2e                	jne    c002a4e6 <hash_string+0x45>
c002a4b8:	eb 41                	jmp    c002a4fb <hash_string+0x5a>
  ASSERT (s != NULL);
c002a4ba:	c7 44 24 10 1a fa 02 	movl   $0xc002fa1a,0x10(%esp)
c002a4c1:	c0 
c002a4c2:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a4c9:	c0 
c002a4ca:	c7 44 24 08 e7 dd 02 	movl   $0xc002dde7,0x8(%esp)
c002a4d1:	c0 
c002a4d2:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c002a4d9:	00 
c002a4da:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a4e1:	e8 9d e4 ff ff       	call   c0028983 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *s++;
c002a4e6:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a4ec:	83 c2 01             	add    $0x1,%edx
c002a4ef:	0f b6 c9             	movzbl %cl,%ecx
c002a4f2:	31 c8                	xor    %ecx,%eax
  while (*s != '\0')
c002a4f4:	0f b6 0a             	movzbl (%edx),%ecx
c002a4f7:	84 c9                	test   %cl,%cl
c002a4f9:	75 eb                	jne    c002a4e6 <hash_string+0x45>
}
c002a4fb:	83 c4 2c             	add    $0x2c,%esp
c002a4fe:	c3                   	ret    

c002a4ff <hash_int>:
{
c002a4ff:	83 ec 1c             	sub    $0x1c,%esp
  return hash_bytes (&i, sizeof i);
c002a502:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002a509:	00 
c002a50a:	8d 44 24 20          	lea    0x20(%esp),%eax
c002a50e:	89 04 24             	mov    %eax,(%esp)
c002a511:	e8 29 ff ff ff       	call   c002a43f <hash_bytes>
}
c002a516:	83 c4 1c             	add    $0x1c,%esp
c002a519:	c3                   	ret    

c002a51a <putchar_have_lock>:
/* Writes C to the vga display and serial port.
   The caller has already acquired the console lock if
   appropriate. */
static void
putchar_have_lock (uint8_t c) 
{
c002a51a:	53                   	push   %ebx
c002a51b:	83 ec 28             	sub    $0x28,%esp
c002a51e:	89 c3                	mov    %eax,%ebx
  return (intr_context ()
c002a520:	e8 fc 76 ff ff       	call   c0021c21 <intr_context>
          || lock_held_by_current_thread (&console_lock));
c002a525:	84 c0                	test   %al,%al
c002a527:	75 45                	jne    c002a56e <putchar_have_lock+0x54>
          || !use_console_lock
c002a529:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a530:	74 3c                	je     c002a56e <putchar_have_lock+0x54>
          || lock_held_by_current_thread (&console_lock));
c002a532:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a539:	e8 d3 88 ff ff       	call   c0022e11 <lock_held_by_current_thread>
  ASSERT (console_locked_by_current_thread ());
c002a53e:	84 c0                	test   %al,%al
c002a540:	75 2c                	jne    c002a56e <putchar_have_lock+0x54>
c002a542:	c7 44 24 10 7c fe 02 	movl   $0xc002fe7c,0x10(%esp)
c002a549:	c0 
c002a54a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a551:	c0 
c002a552:	c7 44 24 08 25 de 02 	movl   $0xc002de25,0x8(%esp)
c002a559:	c0 
c002a55a:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c002a561:	00 
c002a562:	c7 04 24 c1 fe 02 c0 	movl   $0xc002fec1,(%esp)
c002a569:	e8 15 e4 ff ff       	call   c0028983 <debug_panic>
  write_cnt++;
c002a56e:	83 05 e0 7a 03 c0 01 	addl   $0x1,0xc0037ae0
c002a575:	83 15 e4 7a 03 c0 00 	adcl   $0x0,0xc0037ae4
  serial_putc (c);
c002a57c:	0f b6 db             	movzbl %bl,%ebx
c002a57f:	89 1c 24             	mov    %ebx,(%esp)
c002a582:	e8 95 a5 ff ff       	call   c0024b1c <serial_putc>
  vga_putc (c);
c002a587:	89 1c 24             	mov    %ebx,(%esp)
c002a58a:	e8 aa a1 ff ff       	call   c0024739 <vga_putc>
}
c002a58f:	83 c4 28             	add    $0x28,%esp
c002a592:	5b                   	pop    %ebx
c002a593:	c3                   	ret    

c002a594 <vprintf_helper>:
{
c002a594:	83 ec 0c             	sub    $0xc,%esp
c002a597:	8b 44 24 14          	mov    0x14(%esp),%eax
  (*char_cnt)++;
c002a59b:	83 00 01             	addl   $0x1,(%eax)
  putchar_have_lock (c);
c002a59e:	0f b6 44 24 10       	movzbl 0x10(%esp),%eax
c002a5a3:	e8 72 ff ff ff       	call   c002a51a <putchar_have_lock>
}
c002a5a8:	83 c4 0c             	add    $0xc,%esp
c002a5ab:	c3                   	ret    

c002a5ac <acquire_console>:
{
c002a5ac:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a5af:	e8 6d 76 ff ff       	call   c0021c21 <intr_context>
c002a5b4:	84 c0                	test   %al,%al
c002a5b6:	75 2e                	jne    c002a5e6 <acquire_console+0x3a>
c002a5b8:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a5bf:	74 25                	je     c002a5e6 <acquire_console+0x3a>
      if (lock_held_by_current_thread (&console_lock)) 
c002a5c1:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5c8:	e8 44 88 ff ff       	call   c0022e11 <lock_held_by_current_thread>
c002a5cd:	84 c0                	test   %al,%al
c002a5cf:	74 09                	je     c002a5da <acquire_console+0x2e>
        console_lock_depth++; 
c002a5d1:	83 05 e8 7a 03 c0 01 	addl   $0x1,0xc0037ae8
c002a5d8:	eb 0c                	jmp    c002a5e6 <acquire_console+0x3a>
        lock_acquire (&console_lock); 
c002a5da:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5e1:	e8 74 88 ff ff       	call   c0022e5a <lock_acquire>
}
c002a5e6:	83 c4 1c             	add    $0x1c,%esp
c002a5e9:	c3                   	ret    

c002a5ea <release_console>:
{
c002a5ea:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a5ed:	e8 2f 76 ff ff       	call   c0021c21 <intr_context>
c002a5f2:	84 c0                	test   %al,%al
c002a5f4:	75 28                	jne    c002a61e <release_console+0x34>
c002a5f6:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a5fd:	74 1f                	je     c002a61e <release_console+0x34>
      if (console_lock_depth > 0)
c002a5ff:	a1 e8 7a 03 c0       	mov    0xc0037ae8,%eax
c002a604:	85 c0                	test   %eax,%eax
c002a606:	7e 0a                	jle    c002a612 <release_console+0x28>
        console_lock_depth--;
c002a608:	83 e8 01             	sub    $0x1,%eax
c002a60b:	a3 e8 7a 03 c0       	mov    %eax,0xc0037ae8
c002a610:	eb 0c                	jmp    c002a61e <release_console+0x34>
        lock_release (&console_lock); 
c002a612:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a619:	e8 06 8a ff ff       	call   c0023024 <lock_release>
}
c002a61e:	83 c4 1c             	add    $0x1c,%esp
c002a621:	c3                   	ret    

c002a622 <console_init>:
{
c002a622:	83 ec 1c             	sub    $0x1c,%esp
  lock_init (&console_lock);
c002a625:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a62c:	e8 8c 87 ff ff       	call   c0022dbd <lock_init>
  use_console_lock = true;
c002a631:	c6 05 ec 7a 03 c0 01 	movb   $0x1,0xc0037aec
}
c002a638:	83 c4 1c             	add    $0x1c,%esp
c002a63b:	c3                   	ret    

c002a63c <console_panic>:
  use_console_lock = false;
c002a63c:	c6 05 ec 7a 03 c0 00 	movb   $0x0,0xc0037aec
c002a643:	c3                   	ret    

c002a644 <console_print_stats>:
{
c002a644:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Console: %lld characters output\n", write_cnt);
c002a647:	a1 e0 7a 03 c0       	mov    0xc0037ae0,%eax
c002a64c:	8b 15 e4 7a 03 c0    	mov    0xc0037ae4,%edx
c002a652:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a656:	89 54 24 08          	mov    %edx,0x8(%esp)
c002a65a:	c7 04 24 a0 fe 02 c0 	movl   $0xc002fea0,(%esp)
c002a661:	e8 c8 c4 ff ff       	call   c0026b2e <printf>
}
c002a666:	83 c4 1c             	add    $0x1c,%esp
c002a669:	c3                   	ret    

c002a66a <vprintf>:
{
c002a66a:	83 ec 2c             	sub    $0x2c,%esp
  int char_cnt = 0;
c002a66d:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a674:	00 
  acquire_console ();
c002a675:	e8 32 ff ff ff       	call   c002a5ac <acquire_console>
  __vprintf (format, args, vprintf_helper, &char_cnt);
c002a67a:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c002a67e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002a682:	c7 44 24 08 94 a5 02 	movl   $0xc002a594,0x8(%esp)
c002a689:	c0 
c002a68a:	8b 44 24 34          	mov    0x34(%esp),%eax
c002a68e:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a692:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a696:	89 04 24             	mov    %eax,(%esp)
c002a699:	e8 d6 c4 ff ff       	call   c0026b74 <__vprintf>
  release_console ();
c002a69e:	e8 47 ff ff ff       	call   c002a5ea <release_console>
}
c002a6a3:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a6a7:	83 c4 2c             	add    $0x2c,%esp
c002a6aa:	c3                   	ret    

c002a6ab <puts>:
{
c002a6ab:	53                   	push   %ebx
c002a6ac:	83 ec 08             	sub    $0x8,%esp
c002a6af:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a6b3:	e8 f4 fe ff ff       	call   c002a5ac <acquire_console>
  while (*s != '\0')
c002a6b8:	0f b6 03             	movzbl (%ebx),%eax
c002a6bb:	84 c0                	test   %al,%al
c002a6bd:	74 12                	je     c002a6d1 <puts+0x26>
    putchar_have_lock (*s++);
c002a6bf:	83 c3 01             	add    $0x1,%ebx
c002a6c2:	0f b6 c0             	movzbl %al,%eax
c002a6c5:	e8 50 fe ff ff       	call   c002a51a <putchar_have_lock>
  while (*s != '\0')
c002a6ca:	0f b6 03             	movzbl (%ebx),%eax
c002a6cd:	84 c0                	test   %al,%al
c002a6cf:	75 ee                	jne    c002a6bf <puts+0x14>
  putchar_have_lock ('\n');
c002a6d1:	b8 0a 00 00 00       	mov    $0xa,%eax
c002a6d6:	e8 3f fe ff ff       	call   c002a51a <putchar_have_lock>
  release_console ();
c002a6db:	e8 0a ff ff ff       	call   c002a5ea <release_console>
}
c002a6e0:	b8 00 00 00 00       	mov    $0x0,%eax
c002a6e5:	83 c4 08             	add    $0x8,%esp
c002a6e8:	5b                   	pop    %ebx
c002a6e9:	c3                   	ret    

c002a6ea <putbuf>:
{
c002a6ea:	56                   	push   %esi
c002a6eb:	53                   	push   %ebx
c002a6ec:	83 ec 04             	sub    $0x4,%esp
c002a6ef:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a6f3:	8b 74 24 14          	mov    0x14(%esp),%esi
  acquire_console ();
c002a6f7:	e8 b0 fe ff ff       	call   c002a5ac <acquire_console>
  while (n-- > 0)
c002a6fc:	85 f6                	test   %esi,%esi
c002a6fe:	74 11                	je     c002a711 <putbuf+0x27>
    putchar_have_lock (*buffer++);
c002a700:	83 c3 01             	add    $0x1,%ebx
c002a703:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
c002a707:	e8 0e fe ff ff       	call   c002a51a <putchar_have_lock>
  while (n-- > 0)
c002a70c:	83 ee 01             	sub    $0x1,%esi
c002a70f:	75 ef                	jne    c002a700 <putbuf+0x16>
  release_console ();
c002a711:	e8 d4 fe ff ff       	call   c002a5ea <release_console>
}
c002a716:	83 c4 04             	add    $0x4,%esp
c002a719:	5b                   	pop    %ebx
c002a71a:	5e                   	pop    %esi
c002a71b:	c3                   	ret    

c002a71c <putchar>:
{
c002a71c:	53                   	push   %ebx
c002a71d:	83 ec 08             	sub    $0x8,%esp
c002a720:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a724:	e8 83 fe ff ff       	call   c002a5ac <acquire_console>
  putchar_have_lock (c);
c002a729:	0f b6 c3             	movzbl %bl,%eax
c002a72c:	e8 e9 fd ff ff       	call   c002a51a <putchar_have_lock>
  release_console ();
c002a731:	e8 b4 fe ff ff       	call   c002a5ea <release_console>
}
c002a736:	89 d8                	mov    %ebx,%eax
c002a738:	83 c4 08             	add    $0x8,%esp
c002a73b:	5b                   	pop    %ebx
c002a73c:	c3                   	ret    

c002a73d <msg>:
/* Prints FORMAT as if with printf(),
   prefixing the output by the name of the test
   and following it with a new-line character. */
void
msg (const char *format, ...) 
{
c002a73d:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) ", test_name);
c002a740:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a745:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a749:	c7 04 24 dc fe 02 c0 	movl   $0xc002fedc,(%esp)
c002a750:	e8 d9 c3 ff ff       	call   c0026b2e <printf>
  va_start (args, format);
c002a755:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a759:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a75d:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a761:	89 04 24             	mov    %eax,(%esp)
c002a764:	e8 01 ff ff ff       	call   c002a66a <vprintf>
  va_end (args);
  putchar ('\n');
c002a769:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a770:	e8 a7 ff ff ff       	call   c002a71c <putchar>
}
c002a775:	83 c4 1c             	add    $0x1c,%esp
c002a778:	c3                   	ret    

c002a779 <run_test>:
{
c002a779:	56                   	push   %esi
c002a77a:	53                   	push   %ebx
c002a77b:	83 ec 24             	sub    $0x24,%esp
c002a77e:	8b 74 24 30          	mov    0x30(%esp),%esi
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a782:	bb 60 de 02 c0       	mov    $0xc002de60,%ebx
    if (!strcmp (name, t->name))
c002a787:	8b 03                	mov    (%ebx),%eax
c002a789:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a78d:	89 34 24             	mov    %esi,(%esp)
c002a790:	e8 02 d3 ff ff       	call   c0027a97 <strcmp>
c002a795:	85 c0                	test   %eax,%eax
c002a797:	75 23                	jne    c002a7bc <run_test+0x43>
        test_name = name;
c002a799:	89 35 24 7b 03 c0    	mov    %esi,0xc0037b24
        msg ("begin");
c002a79f:	c7 04 24 e2 fe 02 c0 	movl   $0xc002fee2,(%esp)
c002a7a6:	e8 92 ff ff ff       	call   c002a73d <msg>
        t->function ();
c002a7ab:	ff 53 04             	call   *0x4(%ebx)
        msg ("end");
c002a7ae:	c7 04 24 e8 fe 02 c0 	movl   $0xc002fee8,(%esp)
c002a7b5:	e8 83 ff ff ff       	call   c002a73d <msg>
c002a7ba:	eb 33                	jmp    c002a7ef <run_test+0x76>
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a7bc:	83 c3 08             	add    $0x8,%ebx
c002a7bf:	81 fb 38 df 02 c0    	cmp    $0xc002df38,%ebx
c002a7c5:	72 c0                	jb     c002a787 <run_test+0xe>
  PANIC ("no test named \"%s\"", name);
c002a7c7:	89 74 24 10          	mov    %esi,0x10(%esp)
c002a7cb:	c7 44 24 0c ec fe 02 	movl   $0xc002feec,0xc(%esp)
c002a7d2:	c0 
c002a7d3:	c7 44 24 08 45 de 02 	movl   $0xc002de45,0x8(%esp)
c002a7da:	c0 
c002a7db:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a7e2:	00 
c002a7e3:	c7 04 24 ff fe 02 c0 	movl   $0xc002feff,(%esp)
c002a7ea:	e8 94 e1 ff ff       	call   c0028983 <debug_panic>
}
c002a7ef:	83 c4 24             	add    $0x24,%esp
c002a7f2:	5b                   	pop    %ebx
c002a7f3:	5e                   	pop    %esi
c002a7f4:	c3                   	ret    

c002a7f5 <fail>:
   prefixing the output by the name of the test and FAIL:
   and following it with a new-line character,
   and then panics the kernel. */
void
fail (const char *format, ...) 
{
c002a7f5:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) FAIL: ", test_name);
c002a7f8:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a7fd:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a801:	c7 04 24 1b ff 02 c0 	movl   $0xc002ff1b,(%esp)
c002a808:	e8 21 c3 ff ff       	call   c0026b2e <printf>
  va_start (args, format);
c002a80d:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a811:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a815:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a819:	89 04 24             	mov    %eax,(%esp)
c002a81c:	e8 49 fe ff ff       	call   c002a66a <vprintf>
  va_end (args);
  putchar ('\n');
c002a821:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a828:	e8 ef fe ff ff       	call   c002a71c <putchar>

  PANIC ("test failed");
c002a82d:	c7 44 24 0c 27 ff 02 	movl   $0xc002ff27,0xc(%esp)
c002a834:	c0 
c002a835:	c7 44 24 08 40 de 02 	movl   $0xc002de40,0x8(%esp)
c002a83c:	c0 
c002a83d:	c7 44 24 04 5d 00 00 	movl   $0x5d,0x4(%esp)
c002a844:	00 
c002a845:	c7 04 24 ff fe 02 c0 	movl   $0xc002feff,(%esp)
c002a84c:	e8 32 e1 ff ff       	call   c0028983 <debug_panic>

c002a851 <pass>:
}

/* Prints a message indicating the current test passed. */
void
pass (void) 
{
c002a851:	83 ec 1c             	sub    $0x1c,%esp
  printf ("(%s) PASS\n", test_name);
c002a854:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a859:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a85d:	c7 04 24 33 ff 02 c0 	movl   $0xc002ff33,(%esp)
c002a864:	e8 c5 c2 ff ff       	call   c0026b2e <printf>
}
c002a869:	83 c4 1c             	add    $0x1c,%esp
c002a86c:	c3                   	ret    
c002a86d:	90                   	nop
c002a86e:	90                   	nop
c002a86f:	90                   	nop

c002a870 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *t_) 
{
c002a870:	55                   	push   %ebp
c002a871:	57                   	push   %edi
c002a872:	56                   	push   %esi
c002a873:	53                   	push   %ebx
c002a874:	83 ec 1c             	sub    $0x1c,%esp
  struct sleep_thread *t = t_;
  struct sleep_test *test = t->test;
c002a877:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a87b:	8b 18                	mov    (%eax),%ebx
  int i;

  for (i = 1; i <= test->iterations; i++) 
c002a87d:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002a881:	7e 63                	jle    c002a8e6 <sleeper+0x76>
c002a883:	bd 01 00 00 00       	mov    $0x1,%ebp
    {
      int64_t sleep_until = test->start + i * t->duration;
      timer_sleep (sleep_until - timer_ticks ());
      lock_acquire (&test->output_lock);
c002a888:	8d 43 0c             	lea    0xc(%ebx),%eax
c002a88b:	89 44 24 0c          	mov    %eax,0xc(%esp)
      int64_t sleep_until = test->start + i * t->duration;
c002a88f:	89 e8                	mov    %ebp,%eax
c002a891:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a895:	0f af 41 08          	imul   0x8(%ecx),%eax
c002a899:	99                   	cltd   
c002a89a:	03 03                	add    (%ebx),%eax
c002a89c:	13 53 04             	adc    0x4(%ebx),%edx
c002a89f:	89 c6                	mov    %eax,%esi
c002a8a1:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002a8a3:	e8 68 99 ff ff       	call   c0024210 <timer_ticks>
c002a8a8:	29 c6                	sub    %eax,%esi
c002a8aa:	19 d7                	sbb    %edx,%edi
c002a8ac:	89 34 24             	mov    %esi,(%esp)
c002a8af:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a8b3:	e8 a0 99 ff ff       	call   c0024258 <timer_sleep>
      lock_acquire (&test->output_lock);
c002a8b8:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c002a8bc:	89 3c 24             	mov    %edi,(%esp)
c002a8bf:	e8 96 85 ff ff       	call   c0022e5a <lock_acquire>
      *test->output_pos++ = t->id;
c002a8c4:	8b 43 30             	mov    0x30(%ebx),%eax
c002a8c7:	8d 50 04             	lea    0x4(%eax),%edx
c002a8ca:	89 53 30             	mov    %edx,0x30(%ebx)
c002a8cd:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a8d1:	8b 51 04             	mov    0x4(%ecx),%edx
c002a8d4:	89 10                	mov    %edx,(%eax)
      lock_release (&test->output_lock);
c002a8d6:	89 3c 24             	mov    %edi,(%esp)
c002a8d9:	e8 46 87 ff ff       	call   c0023024 <lock_release>
  for (i = 1; i <= test->iterations; i++) 
c002a8de:	83 c5 01             	add    $0x1,%ebp
c002a8e1:	39 6b 08             	cmp    %ebp,0x8(%ebx)
c002a8e4:	7d a9                	jge    c002a88f <sleeper+0x1f>
    }
}
c002a8e6:	83 c4 1c             	add    $0x1c,%esp
c002a8e9:	5b                   	pop    %ebx
c002a8ea:	5e                   	pop    %esi
c002a8eb:	5f                   	pop    %edi
c002a8ec:	5d                   	pop    %ebp
c002a8ed:	c3                   	ret    

c002a8ee <test_sleep>:
{
c002a8ee:	55                   	push   %ebp
c002a8ef:	57                   	push   %edi
c002a8f0:	56                   	push   %esi
c002a8f1:	53                   	push   %ebx
c002a8f2:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c002a8f8:	89 44 24 20          	mov    %eax,0x20(%esp)
c002a8fc:	89 54 24 2c          	mov    %edx,0x2c(%esp)
  ASSERT (!thread_mlfqs);
c002a900:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002a907:	74 2c                	je     c002a935 <test_sleep+0x47>
c002a909:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002a910:	c0 
c002a911:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a918:	c0 
c002a919:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002a920:	c0 
c002a921:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a928:	00 
c002a929:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002a930:	e8 4e e0 ff ff       	call   c0028983 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002a935:	8b 74 24 2c          	mov    0x2c(%esp),%esi
c002a939:	89 74 24 08          	mov    %esi,0x8(%esp)
c002a93d:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002a941:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a945:	c7 04 24 64 01 03 c0 	movl   $0xc0030164,(%esp)
c002a94c:	e8 ec fd ff ff       	call   c002a73d <msg>
  msg ("Thread 0 sleeps 10 ticks each time,");
c002a951:	c7 04 24 90 01 03 c0 	movl   $0xc0030190,(%esp)
c002a958:	e8 e0 fd ff ff       	call   c002a73d <msg>
  msg ("thread 1 sleeps 20 ticks each time, and so on.");
c002a95d:	c7 04 24 b4 01 03 c0 	movl   $0xc00301b4,(%esp)
c002a964:	e8 d4 fd ff ff       	call   c002a73d <msg>
  msg ("If successful, product of iteration count and");
c002a969:	c7 04 24 e4 01 03 c0 	movl   $0xc00301e4,(%esp)
c002a970:	e8 c8 fd ff ff       	call   c002a73d <msg>
  msg ("sleep duration will appear in nondescending order.");
c002a975:	c7 04 24 14 02 03 c0 	movl   $0xc0030214,(%esp)
c002a97c:	e8 bc fd ff ff       	call   c002a73d <msg>
  threads = malloc (sizeof *threads * thread_cnt);
c002a981:	89 f8                	mov    %edi,%eax
c002a983:	c1 e0 04             	shl    $0x4,%eax
c002a986:	89 04 24             	mov    %eax,(%esp)
c002a989:	e8 96 90 ff ff       	call   c0023a24 <malloc>
c002a98e:	89 c3                	mov    %eax,%ebx
c002a990:	89 44 24 24          	mov    %eax,0x24(%esp)
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002a994:	8d 04 f5 00 00 00 00 	lea    0x0(,%esi,8),%eax
c002a99b:	0f af c7             	imul   %edi,%eax
c002a99e:	89 04 24             	mov    %eax,(%esp)
c002a9a1:	e8 7e 90 ff ff       	call   c0023a24 <malloc>
c002a9a6:	89 44 24 28          	mov    %eax,0x28(%esp)
  if (threads == NULL || output == NULL)
c002a9aa:	85 c0                	test   %eax,%eax
c002a9ac:	74 04                	je     c002a9b2 <test_sleep+0xc4>
c002a9ae:	85 db                	test   %ebx,%ebx
c002a9b0:	75 24                	jne    c002a9d6 <test_sleep+0xe8>
    PANIC ("couldn't allocate memory for test");
c002a9b2:	c7 44 24 0c 48 02 03 	movl   $0xc0030248,0xc(%esp)
c002a9b9:	c0 
c002a9ba:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002a9c1:	c0 
c002a9c2:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c002a9c9:	00 
c002a9ca:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002a9d1:	e8 ad df ff ff       	call   c0028983 <debug_panic>
  test.start = timer_ticks () + 100;
c002a9d6:	e8 35 98 ff ff       	call   c0024210 <timer_ticks>
c002a9db:	83 c0 64             	add    $0x64,%eax
c002a9de:	83 d2 00             	adc    $0x0,%edx
c002a9e1:	89 44 24 4c          	mov    %eax,0x4c(%esp)
c002a9e5:	89 54 24 50          	mov    %edx,0x50(%esp)
  test.iterations = iterations;
c002a9e9:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a9ed:	89 44 24 54          	mov    %eax,0x54(%esp)
  lock_init (&test.output_lock);
c002a9f1:	8d 44 24 58          	lea    0x58(%esp),%eax
c002a9f5:	89 04 24             	mov    %eax,(%esp)
c002a9f8:	e8 c0 83 ff ff       	call   c0022dbd <lock_init>
  test.output_pos = output;
c002a9fd:	8b 44 24 28          	mov    0x28(%esp),%eax
c002aa01:	89 44 24 7c          	mov    %eax,0x7c(%esp)
  ASSERT (output != NULL);
c002aa05:	85 c0                	test   %eax,%eax
c002aa07:	74 1e                	je     c002aa27 <test_sleep+0x139>
c002aa09:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  for (i = 0; i < thread_cnt; i++)
c002aa0d:	be 0a 00 00 00       	mov    $0xa,%esi
c002aa12:	b8 00 00 00 00       	mov    $0x0,%eax
      snprintf (name, sizeof name, "thread %d", i);
c002aa17:	8d 6c 24 3c          	lea    0x3c(%esp),%ebp
  for (i = 0; i < thread_cnt; i++)
c002aa1b:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c002aa20:	7f 31                	jg     c002aa53 <test_sleep+0x165>
c002aa22:	e9 8a 00 00 00       	jmp    c002aab1 <test_sleep+0x1c3>
  ASSERT (output != NULL);
c002aa27:	c7 44 24 10 0a 01 03 	movl   $0xc003010a,0x10(%esp)
c002aa2e:	c0 
c002aa2f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002aa36:	c0 
c002aa37:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002aa3e:	c0 
c002aa3f:	c7 44 24 04 51 00 00 	movl   $0x51,0x4(%esp)
c002aa46:	00 
c002aa47:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002aa4e:	e8 30 df ff ff       	call   c0028983 <debug_panic>
      t->test = &test;
c002aa53:	8d 4c 24 4c          	lea    0x4c(%esp),%ecx
c002aa57:	89 0b                	mov    %ecx,(%ebx)
      t->id = i;
c002aa59:	89 43 04             	mov    %eax,0x4(%ebx)
      t->duration = (i + 1) * 10;
c002aa5c:	8d 78 01             	lea    0x1(%eax),%edi
c002aa5f:	89 73 08             	mov    %esi,0x8(%ebx)
      t->iterations = 0;
c002aa62:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
      snprintf (name, sizeof name, "thread %d", i);
c002aa69:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002aa6d:	c7 44 24 08 19 01 03 	movl   $0xc0030119,0x8(%esp)
c002aa74:	c0 
c002aa75:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002aa7c:	00 
c002aa7d:	89 2c 24             	mov    %ebp,(%esp)
c002aa80:	e8 aa c7 ff ff       	call   c002722f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, t);
c002aa85:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002aa89:	c7 44 24 08 70 a8 02 	movl   $0xc002a870,0x8(%esp)
c002aa90:	c0 
c002aa91:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002aa98:	00 
c002aa99:	89 2c 24             	mov    %ebp,(%esp)
c002aa9c:	e8 86 6a ff ff       	call   c0021527 <thread_create>
c002aaa1:	83 c3 10             	add    $0x10,%ebx
c002aaa4:	83 c6 0a             	add    $0xa,%esi
  for (i = 0; i < thread_cnt; i++)
c002aaa7:	3b 7c 24 20          	cmp    0x20(%esp),%edi
c002aaab:	74 04                	je     c002aab1 <test_sleep+0x1c3>
c002aaad:	89 f8                	mov    %edi,%eax
c002aaaf:	eb a2                	jmp    c002aa53 <test_sleep+0x165>
  timer_sleep (100 + thread_cnt * iterations * 10 + 100);
c002aab1:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002aab5:	89 f8                	mov    %edi,%eax
c002aab7:	0f af 44 24 2c       	imul   0x2c(%esp),%eax
c002aabc:	8d 04 80             	lea    (%eax,%eax,4),%eax
c002aabf:	8d 84 00 c8 00 00 00 	lea    0xc8(%eax,%eax,1),%eax
c002aac6:	89 04 24             	mov    %eax,(%esp)
c002aac9:	89 c1                	mov    %eax,%ecx
c002aacb:	c1 f9 1f             	sar    $0x1f,%ecx
c002aace:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002aad2:	e8 81 97 ff ff       	call   c0024258 <timer_sleep>
  lock_acquire (&test.output_lock);
c002aad7:	8d 44 24 58          	lea    0x58(%esp),%eax
c002aadb:	89 04 24             	mov    %eax,(%esp)
c002aade:	e8 77 83 ff ff       	call   c0022e5a <lock_acquire>
  for (op = output; op < test.output_pos; op++) 
c002aae3:	8b 44 24 28          	mov    0x28(%esp),%eax
c002aae7:	3b 44 24 7c          	cmp    0x7c(%esp),%eax
c002aaeb:	0f 83 bb 00 00 00    	jae    c002abac <test_sleep+0x2be>
      ASSERT (*op >= 0 && *op < thread_cnt);
c002aaf1:	8b 18                	mov    (%eax),%ebx
c002aaf3:	85 db                	test   %ebx,%ebx
c002aaf5:	78 1b                	js     c002ab12 <test_sleep+0x224>
c002aaf7:	39 df                	cmp    %ebx,%edi
c002aaf9:	7f 43                	jg     c002ab3e <test_sleep+0x250>
c002aafb:	90                   	nop
c002aafc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c002ab00:	eb 10                	jmp    c002ab12 <test_sleep+0x224>
c002ab02:	8b 1f                	mov    (%edi),%ebx
c002ab04:	85 db                	test   %ebx,%ebx
c002ab06:	78 0a                	js     c002ab12 <test_sleep+0x224>
c002ab08:	39 5c 24 20          	cmp    %ebx,0x20(%esp)
c002ab0c:	7e 04                	jle    c002ab12 <test_sleep+0x224>
c002ab0e:	89 f5                	mov    %esi,%ebp
c002ab10:	eb 35                	jmp    c002ab47 <test_sleep+0x259>
c002ab12:	c7 44 24 10 23 01 03 	movl   $0xc0030123,0x10(%esp)
c002ab19:	c0 
c002ab1a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ab21:	c0 
c002ab22:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002ab29:	c0 
c002ab2a:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
c002ab31:	00 
c002ab32:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002ab39:	e8 45 de ff ff       	call   c0028983 <debug_panic>
  for (op = output; op < test.output_pos; op++) 
c002ab3e:	8b 7c 24 28          	mov    0x28(%esp),%edi
  product = 0;
c002ab42:	bd 00 00 00 00       	mov    $0x0,%ebp
      t = threads + *op;
c002ab47:	c1 e3 04             	shl    $0x4,%ebx
c002ab4a:	03 5c 24 24          	add    0x24(%esp),%ebx
      new_prod = ++t->iterations * t->duration;
c002ab4e:	8b 43 0c             	mov    0xc(%ebx),%eax
c002ab51:	83 c0 01             	add    $0x1,%eax
c002ab54:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ab57:	8b 53 08             	mov    0x8(%ebx),%edx
c002ab5a:	89 c6                	mov    %eax,%esi
c002ab5c:	0f af f2             	imul   %edx,%esi
      msg ("thread %d: duration=%d, iteration=%d, product=%d",
c002ab5f:	89 74 24 10          	mov    %esi,0x10(%esp)
c002ab63:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ab67:	89 54 24 08          	mov    %edx,0x8(%esp)
c002ab6b:	8b 43 04             	mov    0x4(%ebx),%eax
c002ab6e:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ab72:	c7 04 24 6c 02 03 c0 	movl   $0xc003026c,(%esp)
c002ab79:	e8 bf fb ff ff       	call   c002a73d <msg>
      if (new_prod >= product)
c002ab7e:	39 ee                	cmp    %ebp,%esi
c002ab80:	7d 1d                	jge    c002ab9f <test_sleep+0x2b1>
        fail ("thread %d woke up out of order (%d > %d)!",
c002ab82:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ab86:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002ab8a:	8b 43 04             	mov    0x4(%ebx),%eax
c002ab8d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ab91:	c7 04 24 a0 02 03 c0 	movl   $0xc00302a0,(%esp)
c002ab98:	e8 58 fc ff ff       	call   c002a7f5 <fail>
c002ab9d:	89 ee                	mov    %ebp,%esi
  for (op = output; op < test.output_pos; op++) 
c002ab9f:	83 c7 04             	add    $0x4,%edi
c002aba2:	39 7c 24 7c          	cmp    %edi,0x7c(%esp)
c002aba6:	0f 87 56 ff ff ff    	ja     c002ab02 <test_sleep+0x214>
  for (i = 0; i < thread_cnt; i++)
c002abac:	8b 6c 24 20          	mov    0x20(%esp),%ebp
c002abb0:	85 ed                	test   %ebp,%ebp
c002abb2:	7e 36                	jle    c002abea <test_sleep+0x2fc>
c002abb4:	8b 74 24 24          	mov    0x24(%esp),%esi
c002abb8:	bb 00 00 00 00       	mov    $0x0,%ebx
c002abbd:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
    if (threads[i].iterations != iterations)
c002abc1:	8b 46 0c             	mov    0xc(%esi),%eax
c002abc4:	39 f8                	cmp    %edi,%eax
c002abc6:	74 18                	je     c002abe0 <test_sleep+0x2f2>
      fail ("thread %d woke up %d times instead of %d",
c002abc8:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002abcc:	89 44 24 08          	mov    %eax,0x8(%esp)
c002abd0:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002abd4:	c7 04 24 cc 02 03 c0 	movl   $0xc00302cc,(%esp)
c002abdb:	e8 15 fc ff ff       	call   c002a7f5 <fail>
  for (i = 0; i < thread_cnt; i++)
c002abe0:	83 c3 01             	add    $0x1,%ebx
c002abe3:	83 c6 10             	add    $0x10,%esi
c002abe6:	39 eb                	cmp    %ebp,%ebx
c002abe8:	75 d7                	jne    c002abc1 <test_sleep+0x2d3>
  lock_release (&test.output_lock);
c002abea:	8d 44 24 58          	lea    0x58(%esp),%eax
c002abee:	89 04 24             	mov    %eax,(%esp)
c002abf1:	e8 2e 84 ff ff       	call   c0023024 <lock_release>
  free (output);
c002abf6:	8b 44 24 28          	mov    0x28(%esp),%eax
c002abfa:	89 04 24             	mov    %eax,(%esp)
c002abfd:	e8 a9 8f ff ff       	call   c0023bab <free>
  free (threads);
c002ac02:	8b 44 24 24          	mov    0x24(%esp),%eax
c002ac06:	89 04 24             	mov    %eax,(%esp)
c002ac09:	e8 9d 8f ff ff       	call   c0023bab <free>
}
c002ac0e:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c002ac14:	5b                   	pop    %ebx
c002ac15:	5e                   	pop    %esi
c002ac16:	5f                   	pop    %edi
c002ac17:	5d                   	pop    %ebp
c002ac18:	c3                   	ret    

c002ac19 <test_alarm_single>:
{
c002ac19:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 1);
c002ac1c:	ba 01 00 00 00       	mov    $0x1,%edx
c002ac21:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac26:	e8 c3 fc ff ff       	call   c002a8ee <test_sleep>
}
c002ac2b:	83 c4 0c             	add    $0xc,%esp
c002ac2e:	c3                   	ret    

c002ac2f <test_alarm_multiple>:
{
c002ac2f:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 7);
c002ac32:	ba 07 00 00 00       	mov    $0x7,%edx
c002ac37:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac3c:	e8 ad fc ff ff       	call   c002a8ee <test_sleep>
}
c002ac41:	83 c4 0c             	add    $0xc,%esp
c002ac44:	c3                   	ret    

c002ac45 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *test_) 
{
c002ac45:	55                   	push   %ebp
c002ac46:	57                   	push   %edi
c002ac47:	56                   	push   %esi
c002ac48:	53                   	push   %ebx
c002ac49:	83 ec 1c             	sub    $0x1c,%esp
c002ac4c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  struct sleep_test *test = test_;
  int i;

  /* Make sure we're at the beginning of a timer tick. */
  timer_sleep (1);
c002ac50:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c002ac57:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ac5e:	00 
c002ac5f:	e8 f4 95 ff ff       	call   c0024258 <timer_sleep>

  for (i = 1; i <= test->iterations; i++) 
c002ac64:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002ac68:	7e 56                	jle    c002acc0 <sleeper+0x7b>
c002ac6a:	bd 0a 00 00 00       	mov    $0xa,%ebp
c002ac6f:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c002ac76:	00 
    {
      int64_t sleep_until = test->start + i * 10;
c002ac77:	89 ee                	mov    %ebp,%esi
c002ac79:	89 ef                	mov    %ebp,%edi
c002ac7b:	c1 ff 1f             	sar    $0x1f,%edi
c002ac7e:	03 33                	add    (%ebx),%esi
c002ac80:	13 7b 04             	adc    0x4(%ebx),%edi
      timer_sleep (sleep_until - timer_ticks ());
c002ac83:	e8 88 95 ff ff       	call   c0024210 <timer_ticks>
c002ac88:	29 c6                	sub    %eax,%esi
c002ac8a:	19 d7                	sbb    %edx,%edi
c002ac8c:	89 34 24             	mov    %esi,(%esp)
c002ac8f:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ac93:	e8 c0 95 ff ff       	call   c0024258 <timer_sleep>
      *test->output_pos++ = timer_ticks () - test->start;
c002ac98:	8b 73 0c             	mov    0xc(%ebx),%esi
c002ac9b:	8d 46 04             	lea    0x4(%esi),%eax
c002ac9e:	89 43 0c             	mov    %eax,0xc(%ebx)
c002aca1:	e8 6a 95 ff ff       	call   c0024210 <timer_ticks>
c002aca6:	2b 03                	sub    (%ebx),%eax
c002aca8:	89 06                	mov    %eax,(%esi)
      thread_yield ();
c002acaa:	e8 d6 67 ff ff       	call   c0021485 <thread_yield>
  for (i = 1; i <= test->iterations; i++) 
c002acaf:	83 44 24 0c 01       	addl   $0x1,0xc(%esp)
c002acb4:	83 c5 0a             	add    $0xa,%ebp
c002acb7:	8b 44 24 0c          	mov    0xc(%esp),%eax
c002acbb:	39 43 08             	cmp    %eax,0x8(%ebx)
c002acbe:	7d b7                	jge    c002ac77 <sleeper+0x32>
    }
}
c002acc0:	83 c4 1c             	add    $0x1c,%esp
c002acc3:	5b                   	pop    %ebx
c002acc4:	5e                   	pop    %esi
c002acc5:	5f                   	pop    %edi
c002acc6:	5d                   	pop    %ebp
c002acc7:	c3                   	ret    

c002acc8 <test_alarm_simultaneous>:
{
c002acc8:	55                   	push   %ebp
c002acc9:	57                   	push   %edi
c002acca:	56                   	push   %esi
c002accb:	53                   	push   %ebx
c002accc:	83 ec 4c             	sub    $0x4c,%esp
  ASSERT (!thread_mlfqs);
c002accf:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002acd6:	74 2c                	je     c002ad04 <test_alarm_simultaneous+0x3c>
c002acd8:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002acdf:	c0 
c002ace0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ace7:	c0 
c002ace8:	c7 44 24 08 43 df 02 	movl   $0xc002df43,0x8(%esp)
c002acef:	c0 
c002acf0:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002acf7:	00 
c002acf8:	c7 04 24 f8 02 03 c0 	movl   $0xc00302f8,(%esp)
c002acff:	e8 7f dc ff ff       	call   c0028983 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002ad04:	c7 44 24 08 05 00 00 	movl   $0x5,0x8(%esp)
c002ad0b:	00 
c002ad0c:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c002ad13:	00 
c002ad14:	c7 04 24 64 01 03 c0 	movl   $0xc0030164,(%esp)
c002ad1b:	e8 1d fa ff ff       	call   c002a73d <msg>
  msg ("Each thread sleeps 10 ticks each time.");
c002ad20:	c7 04 24 24 03 03 c0 	movl   $0xc0030324,(%esp)
c002ad27:	e8 11 fa ff ff       	call   c002a73d <msg>
  msg ("Within an iteration, all threads should wake up on the same tick.");
c002ad2c:	c7 04 24 4c 03 03 c0 	movl   $0xc003034c,(%esp)
c002ad33:	e8 05 fa ff ff       	call   c002a73d <msg>
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002ad38:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
c002ad3f:	e8 e0 8c ff ff       	call   c0023a24 <malloc>
c002ad44:	89 c3                	mov    %eax,%ebx
  if (output == NULL)
c002ad46:	85 c0                	test   %eax,%eax
c002ad48:	75 24                	jne    c002ad6e <test_alarm_simultaneous+0xa6>
    PANIC ("couldn't allocate memory for test");
c002ad4a:	c7 44 24 0c 48 02 03 	movl   $0xc0030248,0xc(%esp)
c002ad51:	c0 
c002ad52:	c7 44 24 08 43 df 02 	movl   $0xc002df43,0x8(%esp)
c002ad59:	c0 
c002ad5a:	c7 44 24 04 31 00 00 	movl   $0x31,0x4(%esp)
c002ad61:	00 
c002ad62:	c7 04 24 f8 02 03 c0 	movl   $0xc00302f8,(%esp)
c002ad69:	e8 15 dc ff ff       	call   c0028983 <debug_panic>
  test.start = timer_ticks () + 100;
c002ad6e:	e8 9d 94 ff ff       	call   c0024210 <timer_ticks>
c002ad73:	83 c0 64             	add    $0x64,%eax
c002ad76:	83 d2 00             	adc    $0x0,%edx
c002ad79:	89 44 24 20          	mov    %eax,0x20(%esp)
c002ad7d:	89 54 24 24          	mov    %edx,0x24(%esp)
  test.iterations = iterations;
c002ad81:	c7 44 24 28 05 00 00 	movl   $0x5,0x28(%esp)
c002ad88:	00 
  test.output_pos = output;
c002ad89:	89 5c 24 2c          	mov    %ebx,0x2c(%esp)
c002ad8d:	be 00 00 00 00       	mov    $0x0,%esi
      snprintf (name, sizeof name, "thread %d", i);
c002ad92:	8d 7c 24 30          	lea    0x30(%esp),%edi
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002ad96:	8d 6c 24 20          	lea    0x20(%esp),%ebp
      snprintf (name, sizeof name, "thread %d", i);
c002ad9a:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ad9e:	c7 44 24 08 19 01 03 	movl   $0xc0030119,0x8(%esp)
c002ada5:	c0 
c002ada6:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002adad:	00 
c002adae:	89 3c 24             	mov    %edi,(%esp)
c002adb1:	e8 79 c4 ff ff       	call   c002722f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002adb6:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c002adba:	c7 44 24 08 45 ac 02 	movl   $0xc002ac45,0x8(%esp)
c002adc1:	c0 
c002adc2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002adc9:	00 
c002adca:	89 3c 24             	mov    %edi,(%esp)
c002adcd:	e8 55 67 ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < thread_cnt; i++)
c002add2:	83 c6 01             	add    $0x1,%esi
c002add5:	83 fe 03             	cmp    $0x3,%esi
c002add8:	75 c0                	jne    c002ad9a <test_alarm_simultaneous+0xd2>
  timer_sleep (100 + iterations * 10 + 100);
c002adda:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002ade1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ade8:	00 
c002ade9:	e8 6a 94 ff ff       	call   c0024258 <timer_sleep>
  msg ("iteration 0, thread 0: woke up after %d ticks", output[0]);
c002adee:	8b 03                	mov    (%ebx),%eax
c002adf0:	89 44 24 04          	mov    %eax,0x4(%esp)
c002adf4:	c7 04 24 90 03 03 c0 	movl   $0xc0030390,(%esp)
c002adfb:	e8 3d f9 ff ff       	call   c002a73d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae00:	89 df                	mov    %ebx,%edi
c002ae02:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae06:	29 d8                	sub    %ebx,%eax
c002ae08:	83 f8 07             	cmp    $0x7,%eax
c002ae0b:	7e 4a                	jle    c002ae57 <test_alarm_simultaneous+0x18f>
c002ae0d:	66 be 01 00          	mov    $0x1,%si
    msg ("iteration %d, thread %d: woke up %d ticks later",
c002ae11:	bd 56 55 55 55       	mov    $0x55555556,%ebp
c002ae16:	8b 04 b3             	mov    (%ebx,%esi,4),%eax
c002ae19:	2b 44 b3 fc          	sub    -0x4(%ebx,%esi,4),%eax
c002ae1d:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ae21:	89 f0                	mov    %esi,%eax
c002ae23:	f7 ed                	imul   %ebp
c002ae25:	89 f0                	mov    %esi,%eax
c002ae27:	c1 f8 1f             	sar    $0x1f,%eax
c002ae2a:	29 c2                	sub    %eax,%edx
c002ae2c:	8d 04 52             	lea    (%edx,%edx,2),%eax
c002ae2f:	89 f1                	mov    %esi,%ecx
c002ae31:	29 c1                	sub    %eax,%ecx
c002ae33:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002ae37:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ae3b:	c7 04 24 c0 03 03 c0 	movl   $0xc00303c0,(%esp)
c002ae42:	e8 f6 f8 ff ff       	call   c002a73d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae47:	83 c6 01             	add    $0x1,%esi
c002ae4a:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae4e:	29 f8                	sub    %edi,%eax
c002ae50:	c1 f8 02             	sar    $0x2,%eax
c002ae53:	39 c6                	cmp    %eax,%esi
c002ae55:	7c bf                	jl     c002ae16 <test_alarm_simultaneous+0x14e>
  free (output);
c002ae57:	89 1c 24             	mov    %ebx,(%esp)
c002ae5a:	e8 4c 8d ff ff       	call   c0023bab <free>
}
c002ae5f:	83 c4 4c             	add    $0x4c,%esp
c002ae62:	5b                   	pop    %ebx
c002ae63:	5e                   	pop    %esi
c002ae64:	5f                   	pop    %edi
c002ae65:	5d                   	pop    %ebp
c002ae66:	c3                   	ret    

c002ae67 <alarm_priority_thread>:
    sema_down (&wait_sema);
}

static void
alarm_priority_thread (void *aux UNUSED) 
{
c002ae67:	57                   	push   %edi
c002ae68:	56                   	push   %esi
c002ae69:	83 ec 14             	sub    $0x14,%esp
  /* Busy-wait until the current time changes. */
  int64_t start_time = timer_ticks ();
c002ae6c:	e8 9f 93 ff ff       	call   c0024210 <timer_ticks>
c002ae71:	89 c6                	mov    %eax,%esi
c002ae73:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) == 0)
c002ae75:	89 34 24             	mov    %esi,(%esp)
c002ae78:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ae7c:	e8 bb 93 ff ff       	call   c002423c <timer_elapsed>
c002ae81:	09 c2                	or     %eax,%edx
c002ae83:	74 f0                	je     c002ae75 <alarm_priority_thread+0xe>
    continue;

  /* Now we know we're at the very beginning of a timer tick, so
     we can call timer_sleep() without worrying about races
     between checking the time and a timer interrupt. */
  timer_sleep (wake_time - timer_ticks ());
c002ae85:	8b 35 40 7b 03 c0    	mov    0xc0037b40,%esi
c002ae8b:	8b 3d 44 7b 03 c0    	mov    0xc0037b44,%edi
c002ae91:	e8 7a 93 ff ff       	call   c0024210 <timer_ticks>
c002ae96:	29 c6                	sub    %eax,%esi
c002ae98:	19 d7                	sbb    %edx,%edi
c002ae9a:	89 34 24             	mov    %esi,(%esp)
c002ae9d:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002aea1:	e8 b2 93 ff ff       	call   c0024258 <timer_sleep>

  /* Print a message on wake-up. */
  msg ("Thread %s woke up.", thread_name ());
c002aea6:	e8 f2 5f ff ff       	call   c0020e9d <thread_name>
c002aeab:	89 44 24 04          	mov    %eax,0x4(%esp)
c002aeaf:	c7 04 24 f0 03 03 c0 	movl   $0xc00303f0,(%esp)
c002aeb6:	e8 82 f8 ff ff       	call   c002a73d <msg>

  sema_up (&wait_sema);
c002aebb:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002aec2:	e8 80 7d ff ff       	call   c0022c47 <sema_up>
}
c002aec7:	83 c4 14             	add    $0x14,%esp
c002aeca:	5e                   	pop    %esi
c002aecb:	5f                   	pop    %edi
c002aecc:	c3                   	ret    

c002aecd <test_alarm_priority>:
{
c002aecd:	55                   	push   %ebp
c002aece:	57                   	push   %edi
c002aecf:	56                   	push   %esi
c002aed0:	53                   	push   %ebx
c002aed1:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002aed4:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002aedb:	74 2c                	je     c002af09 <test_alarm_priority+0x3c>
c002aedd:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002aee4:	c0 
c002aee5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002aeec:	c0 
c002aeed:	c7 44 24 08 4e df 02 	movl   $0xc002df4e,0x8(%esp)
c002aef4:	c0 
c002aef5:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002aefc:	00 
c002aefd:	c7 04 24 10 04 03 c0 	movl   $0xc0030410,(%esp)
c002af04:	e8 7a da ff ff       	call   c0028983 <debug_panic>
  wake_time = timer_ticks () + 5 * TIMER_FREQ;
c002af09:	e8 02 93 ff ff       	call   c0024210 <timer_ticks>
c002af0e:	05 f4 01 00 00       	add    $0x1f4,%eax
c002af13:	83 d2 00             	adc    $0x0,%edx
c002af16:	a3 40 7b 03 c0       	mov    %eax,0xc0037b40
c002af1b:	89 15 44 7b 03 c0    	mov    %edx,0xc0037b44
  sema_init (&wait_sema, 0);
c002af21:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002af28:	00 
c002af29:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002af30:	e8 b1 7b ff ff       	call   c0022ae6 <sema_init>
c002af35:	bb 05 00 00 00       	mov    $0x5,%ebx
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af3a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002af3f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af43:	89 d8                	mov    %ebx,%eax
c002af45:	f7 ed                	imul   %ebp
c002af47:	c1 fa 02             	sar    $0x2,%edx
c002af4a:	89 d8                	mov    %ebx,%eax
c002af4c:	c1 f8 1f             	sar    $0x1f,%eax
c002af4f:	29 c2                	sub    %eax,%edx
c002af51:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002af54:	01 c0                	add    %eax,%eax
c002af56:	29 d8                	sub    %ebx,%eax
c002af58:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002af5b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002af5f:	c7 44 24 08 03 04 03 	movl   $0xc0030403,0x8(%esp)
c002af66:	c0 
c002af67:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002af6e:	00 
c002af6f:	89 3c 24             	mov    %edi,(%esp)
c002af72:	e8 b8 c2 ff ff       	call   c002722f <snprintf>
      thread_create (name, priority, alarm_priority_thread, NULL);
c002af77:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002af7e:	00 
c002af7f:	c7 44 24 08 67 ae 02 	movl   $0xc002ae67,0x8(%esp)
c002af86:	c0 
c002af87:	89 74 24 04          	mov    %esi,0x4(%esp)
c002af8b:	89 3c 24             	mov    %edi,(%esp)
c002af8e:	e8 94 65 ff ff       	call   c0021527 <thread_create>
c002af93:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002af96:	83 fb 0f             	cmp    $0xf,%ebx
c002af99:	75 a8                	jne    c002af43 <test_alarm_priority+0x76>
  thread_set_priority (PRI_MIN);
c002af9b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002afa2:	e8 ee 66 ff ff       	call   c0021695 <thread_set_priority>
c002afa7:	b3 0a                	mov    $0xa,%bl
    sema_down (&wait_sema);
c002afa9:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002afb0:	e8 7d 7b ff ff       	call   c0022b32 <sema_down>
  for (i = 0; i < 10; i++)
c002afb5:	83 eb 01             	sub    $0x1,%ebx
c002afb8:	75 ef                	jne    c002afa9 <test_alarm_priority+0xdc>
}
c002afba:	83 c4 3c             	add    $0x3c,%esp
c002afbd:	5b                   	pop    %ebx
c002afbe:	5e                   	pop    %esi
c002afbf:	5f                   	pop    %edi
c002afc0:	5d                   	pop    %ebp
c002afc1:	c3                   	ret    

c002afc2 <test_alarm_zero>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_zero (void) 
{
c002afc2:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (0);
c002afc5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002afcc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002afd3:	00 
c002afd4:	e8 7f 92 ff ff       	call   c0024258 <timer_sleep>
  pass ();
c002afd9:	e8 73 f8 ff ff       	call   c002a851 <pass>
}
c002afde:	83 c4 1c             	add    $0x1c,%esp
c002afe1:	c3                   	ret    

c002afe2 <test_alarm_negative>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_negative (void) 
{
c002afe2:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (-100);
c002afe5:	c7 04 24 9c ff ff ff 	movl   $0xffffff9c,(%esp)
c002afec:	c7 44 24 04 ff ff ff 	movl   $0xffffffff,0x4(%esp)
c002aff3:	ff 
c002aff4:	e8 5f 92 ff ff       	call   c0024258 <timer_sleep>
  pass ();
c002aff9:	e8 53 f8 ff ff       	call   c002a851 <pass>
}
c002affe:	83 c4 1c             	add    $0x1c,%esp
c002b001:	c3                   	ret    

c002b002 <changing_thread>:
  msg ("Thread 2 should have just exited.");
}

static void
changing_thread (void *aux UNUSED) 
{
c002b002:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread 2 now lowering priority.");
c002b005:	c7 04 24 38 04 03 c0 	movl   $0xc0030438,(%esp)
c002b00c:	e8 2c f7 ff ff       	call   c002a73d <msg>
  thread_set_priority (PRI_DEFAULT - 1);
c002b011:	c7 04 24 1e 00 00 00 	movl   $0x1e,(%esp)
c002b018:	e8 78 66 ff ff       	call   c0021695 <thread_set_priority>
  msg ("Thread 2 exiting.");
c002b01d:	c7 04 24 f6 04 03 c0 	movl   $0xc00304f6,(%esp)
c002b024:	e8 14 f7 ff ff       	call   c002a73d <msg>
}
c002b029:	83 c4 1c             	add    $0x1c,%esp
c002b02c:	c3                   	ret    

c002b02d <test_priority_change>:
{
c002b02d:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002b030:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b037:	74 2c                	je     c002b065 <test_priority_change+0x38>
c002b039:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b040:	c0 
c002b041:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b048:	c0 
c002b049:	c7 44 24 08 62 df 02 	movl   $0xc002df62,0x8(%esp)
c002b050:	c0 
c002b051:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002b058:	00 
c002b059:	c7 04 24 58 04 03 c0 	movl   $0xc0030458,(%esp)
c002b060:	e8 1e d9 ff ff       	call   c0028983 <debug_panic>
  msg ("Creating a high-priority thread 2.");
c002b065:	c7 04 24 80 04 03 c0 	movl   $0xc0030480,(%esp)
c002b06c:	e8 cc f6 ff ff       	call   c002a73d <msg>
  thread_create ("thread 2", PRI_DEFAULT + 1, changing_thread, NULL);
c002b071:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b078:	00 
c002b079:	c7 44 24 08 02 b0 02 	movl   $0xc002b002,0x8(%esp)
c002b080:	c0 
c002b081:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b088:	00 
c002b089:	c7 04 24 08 05 03 c0 	movl   $0xc0030508,(%esp)
c002b090:	e8 92 64 ff ff       	call   c0021527 <thread_create>
  msg ("Thread 2 should have just lowered its priority.");
c002b095:	c7 04 24 a4 04 03 c0 	movl   $0xc00304a4,(%esp)
c002b09c:	e8 9c f6 ff ff       	call   c002a73d <msg>
  thread_set_priority (PRI_DEFAULT - 2);
c002b0a1:	c7 04 24 1d 00 00 00 	movl   $0x1d,(%esp)
c002b0a8:	e8 e8 65 ff ff       	call   c0021695 <thread_set_priority>
  msg ("Thread 2 should have just exited.");
c002b0ad:	c7 04 24 d4 04 03 c0 	movl   $0xc00304d4,(%esp)
c002b0b4:	e8 84 f6 ff ff       	call   c002a73d <msg>
}
c002b0b9:	83 c4 2c             	add    $0x2c,%esp
c002b0bc:	c3                   	ret    

c002b0bd <acquire2_thread_func>:
  msg ("acquire1: done");
}

static void
acquire2_thread_func (void *lock_) 
{
c002b0bd:	53                   	push   %ebx
c002b0be:	83 ec 18             	sub    $0x18,%esp
c002b0c1:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b0c5:	89 1c 24             	mov    %ebx,(%esp)
c002b0c8:	e8 8d 7d ff ff       	call   c0022e5a <lock_acquire>
  msg ("acquire2: got the lock");
c002b0cd:	c7 04 24 11 05 03 c0 	movl   $0xc0030511,(%esp)
c002b0d4:	e8 64 f6 ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002b0d9:	89 1c 24             	mov    %ebx,(%esp)
c002b0dc:	e8 43 7f ff ff       	call   c0023024 <lock_release>
  msg ("acquire2: done");
c002b0e1:	c7 04 24 28 05 03 c0 	movl   $0xc0030528,(%esp)
c002b0e8:	e8 50 f6 ff ff       	call   c002a73d <msg>
}
c002b0ed:	83 c4 18             	add    $0x18,%esp
c002b0f0:	5b                   	pop    %ebx
c002b0f1:	c3                   	ret    

c002b0f2 <acquire1_thread_func>:
{
c002b0f2:	53                   	push   %ebx
c002b0f3:	83 ec 18             	sub    $0x18,%esp
c002b0f6:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b0fa:	89 1c 24             	mov    %ebx,(%esp)
c002b0fd:	e8 58 7d ff ff       	call   c0022e5a <lock_acquire>
  msg ("acquire1: got the lock");
c002b102:	c7 04 24 37 05 03 c0 	movl   $0xc0030537,(%esp)
c002b109:	e8 2f f6 ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002b10e:	89 1c 24             	mov    %ebx,(%esp)
c002b111:	e8 0e 7f ff ff       	call   c0023024 <lock_release>
  msg ("acquire1: done");
c002b116:	c7 04 24 4e 05 03 c0 	movl   $0xc003054e,(%esp)
c002b11d:	e8 1b f6 ff ff       	call   c002a73d <msg>
}
c002b122:	83 c4 18             	add    $0x18,%esp
c002b125:	5b                   	pop    %ebx
c002b126:	c3                   	ret    

c002b127 <test_priority_donate_one>:
{
c002b127:	53                   	push   %ebx
c002b128:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002b12b:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b132:	74 2c                	je     c002b160 <test_priority_donate_one+0x39>
c002b134:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b13b:	c0 
c002b13c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b143:	c0 
c002b144:	c7 44 24 08 77 df 02 	movl   $0xc002df77,0x8(%esp)
c002b14b:	c0 
c002b14c:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b153:	00 
c002b154:	c7 04 24 70 05 03 c0 	movl   $0xc0030570,(%esp)
c002b15b:	e8 23 d8 ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b160:	e8 d5 5d ff ff       	call   c0020f3a <thread_get_priority>
c002b165:	83 f8 1f             	cmp    $0x1f,%eax
c002b168:	74 2c                	je     c002b196 <test_priority_donate_one+0x6f>
c002b16a:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b171:	c0 
c002b172:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b179:	c0 
c002b17a:	c7 44 24 08 77 df 02 	movl   $0xc002df77,0x8(%esp)
c002b181:	c0 
c002b182:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b189:	00 
c002b18a:	c7 04 24 70 05 03 c0 	movl   $0xc0030570,(%esp)
c002b191:	e8 ed d7 ff ff       	call   c0028983 <debug_panic>
  lock_init (&lock);
c002b196:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002b19a:	89 1c 24             	mov    %ebx,(%esp)
c002b19d:	e8 1b 7c ff ff       	call   c0022dbd <lock_init>
  lock_acquire (&lock);
c002b1a2:	89 1c 24             	mov    %ebx,(%esp)
c002b1a5:	e8 b0 7c ff ff       	call   c0022e5a <lock_acquire>
  thread_create ("acquire1", PRI_DEFAULT + 1, acquire1_thread_func, &lock);
c002b1aa:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b1ae:	c7 44 24 08 f2 b0 02 	movl   $0xc002b0f2,0x8(%esp)
c002b1b5:	c0 
c002b1b6:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b1bd:	00 
c002b1be:	c7 04 24 5d 05 03 c0 	movl   $0xc003055d,(%esp)
c002b1c5:	e8 5d 63 ff ff       	call   c0021527 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b1ca:	e8 6b 5d ff ff       	call   c0020f3a <thread_get_priority>
c002b1cf:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b1d3:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b1da:	00 
c002b1db:	c7 04 24 c4 05 03 c0 	movl   $0xc00305c4,(%esp)
c002b1e2:	e8 56 f5 ff ff       	call   c002a73d <msg>
  thread_create ("acquire2", PRI_DEFAULT + 2, acquire2_thread_func, &lock);
c002b1e7:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b1eb:	c7 44 24 08 bd b0 02 	movl   $0xc002b0bd,0x8(%esp)
c002b1f2:	c0 
c002b1f3:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b1fa:	00 
c002b1fb:	c7 04 24 66 05 03 c0 	movl   $0xc0030566,(%esp)
c002b202:	e8 20 63 ff ff       	call   c0021527 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b207:	e8 2e 5d ff ff       	call   c0020f3a <thread_get_priority>
c002b20c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b210:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b217:	00 
c002b218:	c7 04 24 c4 05 03 c0 	movl   $0xc00305c4,(%esp)
c002b21f:	e8 19 f5 ff ff       	call   c002a73d <msg>
  lock_release (&lock);
c002b224:	89 1c 24             	mov    %ebx,(%esp)
c002b227:	e8 f8 7d ff ff       	call   c0023024 <lock_release>
  msg ("acquire2, acquire1 must already have finished, in that order.");
c002b22c:	c7 04 24 00 06 03 c0 	movl   $0xc0030600,(%esp)
c002b233:	e8 05 f5 ff ff       	call   c002a73d <msg>
  msg ("This should be the last line before finishing this test.");
c002b238:	c7 04 24 40 06 03 c0 	movl   $0xc0030640,(%esp)
c002b23f:	e8 f9 f4 ff ff       	call   c002a73d <msg>
}
c002b244:	83 c4 58             	add    $0x58,%esp
c002b247:	5b                   	pop    %ebx
c002b248:	c3                   	ret    

c002b249 <b_thread_func>:
  msg ("Thread a finished.");
}

static void
b_thread_func (void *lock_) 
{
c002b249:	53                   	push   %ebx
c002b24a:	83 ec 18             	sub    $0x18,%esp
c002b24d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b251:	89 1c 24             	mov    %ebx,(%esp)
c002b254:	e8 01 7c ff ff       	call   c0022e5a <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b259:	c7 04 24 79 06 03 c0 	movl   $0xc0030679,(%esp)
c002b260:	e8 d8 f4 ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002b265:	89 1c 24             	mov    %ebx,(%esp)
c002b268:	e8 b7 7d ff ff       	call   c0023024 <lock_release>
  msg ("Thread b finished.");
c002b26d:	c7 04 24 93 06 03 c0 	movl   $0xc0030693,(%esp)
c002b274:	e8 c4 f4 ff ff       	call   c002a73d <msg>
}
c002b279:	83 c4 18             	add    $0x18,%esp
c002b27c:	5b                   	pop    %ebx
c002b27d:	c3                   	ret    

c002b27e <a_thread_func>:
{
c002b27e:	53                   	push   %ebx
c002b27f:	83 ec 18             	sub    $0x18,%esp
c002b282:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b286:	89 1c 24             	mov    %ebx,(%esp)
c002b289:	e8 cc 7b ff ff       	call   c0022e5a <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b28e:	c7 04 24 a6 06 03 c0 	movl   $0xc00306a6,(%esp)
c002b295:	e8 a3 f4 ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002b29a:	89 1c 24             	mov    %ebx,(%esp)
c002b29d:	e8 82 7d ff ff       	call   c0023024 <lock_release>
  msg ("Thread a finished.");
c002b2a2:	c7 04 24 c0 06 03 c0 	movl   $0xc00306c0,(%esp)
c002b2a9:	e8 8f f4 ff ff       	call   c002a73d <msg>
}
c002b2ae:	83 c4 18             	add    $0x18,%esp
c002b2b1:	5b                   	pop    %ebx
c002b2b2:	c3                   	ret    

c002b2b3 <test_priority_donate_multiple>:
{
c002b2b3:	56                   	push   %esi
c002b2b4:	53                   	push   %ebx
c002b2b5:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b2b8:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b2bf:	74 2c                	je     c002b2ed <test_priority_donate_multiple+0x3a>
c002b2c1:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b2c8:	c0 
c002b2c9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b2d0:	c0 
c002b2d1:	c7 44 24 08 90 df 02 	movl   $0xc002df90,0x8(%esp)
c002b2d8:	c0 
c002b2d9:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b2e0:	00 
c002b2e1:	c7 04 24 d4 06 03 c0 	movl   $0xc00306d4,(%esp)
c002b2e8:	e8 96 d6 ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b2ed:	e8 48 5c ff ff       	call   c0020f3a <thread_get_priority>
c002b2f2:	83 f8 1f             	cmp    $0x1f,%eax
c002b2f5:	74 2c                	je     c002b323 <test_priority_donate_multiple+0x70>
c002b2f7:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b2fe:	c0 
c002b2ff:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b306:	c0 
c002b307:	c7 44 24 08 90 df 02 	movl   $0xc002df90,0x8(%esp)
c002b30e:	c0 
c002b30f:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b316:	00 
c002b317:	c7 04 24 d4 06 03 c0 	movl   $0xc00306d4,(%esp)
c002b31e:	e8 60 d6 ff ff       	call   c0028983 <debug_panic>
  lock_init (&a);
c002b323:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b327:	89 1c 24             	mov    %ebx,(%esp)
c002b32a:	e8 8e 7a ff ff       	call   c0022dbd <lock_init>
  lock_init (&b);
c002b32f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b333:	89 34 24             	mov    %esi,(%esp)
c002b336:	e8 82 7a ff ff       	call   c0022dbd <lock_init>
  lock_acquire (&a);
c002b33b:	89 1c 24             	mov    %ebx,(%esp)
c002b33e:	e8 17 7b ff ff       	call   c0022e5a <lock_acquire>
  lock_acquire (&b);
c002b343:	89 34 24             	mov    %esi,(%esp)
c002b346:	e8 0f 7b ff ff       	call   c0022e5a <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 1, a_thread_func, &a);
c002b34b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b34f:	c7 44 24 08 7e b2 02 	movl   $0xc002b27e,0x8(%esp)
c002b356:	c0 
c002b357:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b35e:	00 
c002b35f:	c7 04 24 73 f2 02 c0 	movl   $0xc002f273,(%esp)
c002b366:	e8 bc 61 ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b36b:	e8 ca 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b370:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b374:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b37b:	00 
c002b37c:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b383:	e8 b5 f3 ff ff       	call   c002a73d <msg>
  thread_create ("b", PRI_DEFAULT + 2, b_thread_func, &b);
c002b388:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b38c:	c7 44 24 08 49 b2 02 	movl   $0xc002b249,0x8(%esp)
c002b393:	c0 
c002b394:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b39b:	00 
c002b39c:	c7 04 24 3d fc 02 c0 	movl   $0xc002fc3d,(%esp)
c002b3a3:	e8 7f 61 ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3a8:	e8 8d 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b3ad:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3b1:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b3b8:	00 
c002b3b9:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b3c0:	e8 78 f3 ff ff       	call   c002a73d <msg>
  lock_release (&b);
c002b3c5:	89 34 24             	mov    %esi,(%esp)
c002b3c8:	e8 57 7c ff ff       	call   c0023024 <lock_release>
  msg ("Thread b should have just finished.");
c002b3cd:	c7 04 24 40 07 03 c0 	movl   $0xc0030740,(%esp)
c002b3d4:	e8 64 f3 ff ff       	call   c002a73d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3d9:	e8 5c 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b3de:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3e2:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b3e9:	00 
c002b3ea:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b3f1:	e8 47 f3 ff ff       	call   c002a73d <msg>
  lock_release (&a);
c002b3f6:	89 1c 24             	mov    %ebx,(%esp)
c002b3f9:	e8 26 7c ff ff       	call   c0023024 <lock_release>
  msg ("Thread a should have just finished.");
c002b3fe:	c7 04 24 64 07 03 c0 	movl   $0xc0030764,(%esp)
c002b405:	e8 33 f3 ff ff       	call   c002a73d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b40a:	e8 2b 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b40f:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b413:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b41a:	00 
c002b41b:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b422:	e8 16 f3 ff ff       	call   c002a73d <msg>
}
c002b427:	83 c4 74             	add    $0x74,%esp
c002b42a:	5b                   	pop    %ebx
c002b42b:	5e                   	pop    %esi
c002b42c:	c3                   	ret    

c002b42d <c_thread_func>:
  msg ("Thread b finished.");
}

static void
c_thread_func (void *a_ UNUSED) 
{
c002b42d:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread c finished.");
c002b430:	c7 04 24 88 07 03 c0 	movl   $0xc0030788,(%esp)
c002b437:	e8 01 f3 ff ff       	call   c002a73d <msg>
}
c002b43c:	83 c4 1c             	add    $0x1c,%esp
c002b43f:	c3                   	ret    

c002b440 <b_thread_func>:
{
c002b440:	53                   	push   %ebx
c002b441:	83 ec 18             	sub    $0x18,%esp
c002b444:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b448:	89 1c 24             	mov    %ebx,(%esp)
c002b44b:	e8 0a 7a ff ff       	call   c0022e5a <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b450:	c7 04 24 79 06 03 c0 	movl   $0xc0030679,(%esp)
c002b457:	e8 e1 f2 ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002b45c:	89 1c 24             	mov    %ebx,(%esp)
c002b45f:	e8 c0 7b ff ff       	call   c0023024 <lock_release>
  msg ("Thread b finished.");
c002b464:	c7 04 24 93 06 03 c0 	movl   $0xc0030693,(%esp)
c002b46b:	e8 cd f2 ff ff       	call   c002a73d <msg>
}
c002b470:	83 c4 18             	add    $0x18,%esp
c002b473:	5b                   	pop    %ebx
c002b474:	c3                   	ret    

c002b475 <a_thread_func>:
{
c002b475:	53                   	push   %ebx
c002b476:	83 ec 18             	sub    $0x18,%esp
c002b479:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b47d:	89 1c 24             	mov    %ebx,(%esp)
c002b480:	e8 d5 79 ff ff       	call   c0022e5a <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b485:	c7 04 24 a6 06 03 c0 	movl   $0xc00306a6,(%esp)
c002b48c:	e8 ac f2 ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002b491:	89 1c 24             	mov    %ebx,(%esp)
c002b494:	e8 8b 7b ff ff       	call   c0023024 <lock_release>
  msg ("Thread a finished.");
c002b499:	c7 04 24 c0 06 03 c0 	movl   $0xc00306c0,(%esp)
c002b4a0:	e8 98 f2 ff ff       	call   c002a73d <msg>
}
c002b4a5:	83 c4 18             	add    $0x18,%esp
c002b4a8:	5b                   	pop    %ebx
c002b4a9:	c3                   	ret    

c002b4aa <test_priority_donate_multiple2>:
{
c002b4aa:	56                   	push   %esi
c002b4ab:	53                   	push   %ebx
c002b4ac:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b4af:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b4b6:	74 2c                	je     c002b4e4 <test_priority_donate_multiple2+0x3a>
c002b4b8:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b4bf:	c0 
c002b4c0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b4c7:	c0 
c002b4c8:	c7 44 24 08 b0 df 02 	movl   $0xc002dfb0,0x8(%esp)
c002b4cf:	c0 
c002b4d0:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b4d7:	00 
c002b4d8:	c7 04 24 9c 07 03 c0 	movl   $0xc003079c,(%esp)
c002b4df:	e8 9f d4 ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b4e4:	e8 51 5a ff ff       	call   c0020f3a <thread_get_priority>
c002b4e9:	83 f8 1f             	cmp    $0x1f,%eax
c002b4ec:	74 2c                	je     c002b51a <test_priority_donate_multiple2+0x70>
c002b4ee:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b4f5:	c0 
c002b4f6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b4fd:	c0 
c002b4fe:	c7 44 24 08 b0 df 02 	movl   $0xc002dfb0,0x8(%esp)
c002b505:	c0 
c002b506:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b50d:	00 
c002b50e:	c7 04 24 9c 07 03 c0 	movl   $0xc003079c,(%esp)
c002b515:	e8 69 d4 ff ff       	call   c0028983 <debug_panic>
  lock_init (&a);
c002b51a:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b51e:	89 34 24             	mov    %esi,(%esp)
c002b521:	e8 97 78 ff ff       	call   c0022dbd <lock_init>
  lock_init (&b);
c002b526:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b52a:	89 1c 24             	mov    %ebx,(%esp)
c002b52d:	e8 8b 78 ff ff       	call   c0022dbd <lock_init>
  lock_acquire (&a);
c002b532:	89 34 24             	mov    %esi,(%esp)
c002b535:	e8 20 79 ff ff       	call   c0022e5a <lock_acquire>
  lock_acquire (&b);
c002b53a:	89 1c 24             	mov    %ebx,(%esp)
c002b53d:	e8 18 79 ff ff       	call   c0022e5a <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 3, a_thread_func, &a);
c002b542:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b546:	c7 44 24 08 75 b4 02 	movl   $0xc002b475,0x8(%esp)
c002b54d:	c0 
c002b54e:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b555:	00 
c002b556:	c7 04 24 73 f2 02 c0 	movl   $0xc002f273,(%esp)
c002b55d:	e8 c5 5f ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b562:	e8 d3 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b567:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b56b:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b572:	00 
c002b573:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b57a:	e8 be f1 ff ff       	call   c002a73d <msg>
  thread_create ("c", PRI_DEFAULT + 1, c_thread_func, NULL);
c002b57f:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b586:	00 
c002b587:	c7 44 24 08 2d b4 02 	movl   $0xc002b42d,0x8(%esp)
c002b58e:	c0 
c002b58f:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b596:	00 
c002b597:	c7 04 24 5e f6 02 c0 	movl   $0xc002f65e,(%esp)
c002b59e:	e8 84 5f ff ff       	call   c0021527 <thread_create>
  thread_create ("b", PRI_DEFAULT + 5, b_thread_func, &b);
c002b5a3:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b5a7:	c7 44 24 08 40 b4 02 	movl   $0xc002b440,0x8(%esp)
c002b5ae:	c0 
c002b5af:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5b6:	00 
c002b5b7:	c7 04 24 3d fc 02 c0 	movl   $0xc002fc3d,(%esp)
c002b5be:	e8 64 5f ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5c3:	e8 72 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b5c8:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5cc:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5d3:	00 
c002b5d4:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b5db:	e8 5d f1 ff ff       	call   c002a73d <msg>
  lock_release (&a);
c002b5e0:	89 34 24             	mov    %esi,(%esp)
c002b5e3:	e8 3c 7a ff ff       	call   c0023024 <lock_release>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5e8:	e8 4d 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b5ed:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5f1:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5f8:	00 
c002b5f9:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b600:	e8 38 f1 ff ff       	call   c002a73d <msg>
  lock_release (&b);
c002b605:	89 1c 24             	mov    %ebx,(%esp)
c002b608:	e8 17 7a ff ff       	call   c0023024 <lock_release>
  msg ("Threads b, a, c should have just finished, in that order.");
c002b60d:	c7 04 24 cc 07 03 c0 	movl   $0xc00307cc,(%esp)
c002b614:	e8 24 f1 ff ff       	call   c002a73d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b619:	e8 1c 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b61e:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b622:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b629:	00 
c002b62a:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b631:	e8 07 f1 ff ff       	call   c002a73d <msg>
}
c002b636:	83 c4 74             	add    $0x74,%esp
c002b639:	5b                   	pop    %ebx
c002b63a:	5e                   	pop    %esi
c002b63b:	c3                   	ret    

c002b63c <high_thread_func>:
  msg ("Middle thread finished.");
}

static void
high_thread_func (void *lock_) 
{
c002b63c:	53                   	push   %ebx
c002b63d:	83 ec 18             	sub    $0x18,%esp
c002b640:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b644:	89 1c 24             	mov    %ebx,(%esp)
c002b647:	e8 0e 78 ff ff       	call   c0022e5a <lock_acquire>
  msg ("High thread got the lock.");
c002b64c:	c7 04 24 06 08 03 c0 	movl   $0xc0030806,(%esp)
c002b653:	e8 e5 f0 ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002b658:	89 1c 24             	mov    %ebx,(%esp)
c002b65b:	e8 c4 79 ff ff       	call   c0023024 <lock_release>
  msg ("High thread finished.");
c002b660:	c7 04 24 20 08 03 c0 	movl   $0xc0030820,(%esp)
c002b667:	e8 d1 f0 ff ff       	call   c002a73d <msg>
}
c002b66c:	83 c4 18             	add    $0x18,%esp
c002b66f:	5b                   	pop    %ebx
c002b670:	c3                   	ret    

c002b671 <medium_thread_func>:
{
c002b671:	53                   	push   %ebx
c002b672:	83 ec 18             	sub    $0x18,%esp
c002b675:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (locks->b);
c002b679:	8b 43 04             	mov    0x4(%ebx),%eax
c002b67c:	89 04 24             	mov    %eax,(%esp)
c002b67f:	e8 d6 77 ff ff       	call   c0022e5a <lock_acquire>
  lock_acquire (locks->a);
c002b684:	8b 03                	mov    (%ebx),%eax
c002b686:	89 04 24             	mov    %eax,(%esp)
c002b689:	e8 cc 77 ff ff       	call   c0022e5a <lock_acquire>
  msg ("Medium thread should have priority %d.  Actual priority: %d.",
c002b68e:	e8 a7 58 ff ff       	call   c0020f3a <thread_get_priority>
c002b693:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b697:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b69e:	00 
c002b69f:	c7 04 24 78 08 03 c0 	movl   $0xc0030878,(%esp)
c002b6a6:	e8 92 f0 ff ff       	call   c002a73d <msg>
  msg ("Medium thread got the lock.");
c002b6ab:	c7 04 24 36 08 03 c0 	movl   $0xc0030836,(%esp)
c002b6b2:	e8 86 f0 ff ff       	call   c002a73d <msg>
  lock_release (locks->a);
c002b6b7:	8b 03                	mov    (%ebx),%eax
c002b6b9:	89 04 24             	mov    %eax,(%esp)
c002b6bc:	e8 63 79 ff ff       	call   c0023024 <lock_release>
  thread_yield ();
c002b6c1:	e8 bf 5d ff ff       	call   c0021485 <thread_yield>
  lock_release (locks->b);
c002b6c6:	8b 43 04             	mov    0x4(%ebx),%eax
c002b6c9:	89 04 24             	mov    %eax,(%esp)
c002b6cc:	e8 53 79 ff ff       	call   c0023024 <lock_release>
  thread_yield ();
c002b6d1:	e8 af 5d ff ff       	call   c0021485 <thread_yield>
  msg ("High thread should have just finished.");
c002b6d6:	c7 04 24 b8 08 03 c0 	movl   $0xc00308b8,(%esp)
c002b6dd:	e8 5b f0 ff ff       	call   c002a73d <msg>
  msg ("Middle thread finished.");
c002b6e2:	c7 04 24 52 08 03 c0 	movl   $0xc0030852,(%esp)
c002b6e9:	e8 4f f0 ff ff       	call   c002a73d <msg>
}
c002b6ee:	83 c4 18             	add    $0x18,%esp
c002b6f1:	5b                   	pop    %ebx
c002b6f2:	c3                   	ret    

c002b6f3 <test_priority_donate_nest>:
{
c002b6f3:	56                   	push   %esi
c002b6f4:	53                   	push   %ebx
c002b6f5:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b6f8:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b6ff:	74 2c                	je     c002b72d <test_priority_donate_nest+0x3a>
c002b701:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b708:	c0 
c002b709:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b710:	c0 
c002b711:	c7 44 24 08 cf df 02 	movl   $0xc002dfcf,0x8(%esp)
c002b718:	c0 
c002b719:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b720:	00 
c002b721:	c7 04 24 e0 08 03 c0 	movl   $0xc00308e0,(%esp)
c002b728:	e8 56 d2 ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b72d:	e8 08 58 ff ff       	call   c0020f3a <thread_get_priority>
c002b732:	83 f8 1f             	cmp    $0x1f,%eax
c002b735:	74 2c                	je     c002b763 <test_priority_donate_nest+0x70>
c002b737:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b73e:	c0 
c002b73f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b746:	c0 
c002b747:	c7 44 24 08 cf df 02 	movl   $0xc002dfcf,0x8(%esp)
c002b74e:	c0 
c002b74f:	c7 44 24 04 25 00 00 	movl   $0x25,0x4(%esp)
c002b756:	00 
c002b757:	c7 04 24 e0 08 03 c0 	movl   $0xc00308e0,(%esp)
c002b75e:	e8 20 d2 ff ff       	call   c0028983 <debug_panic>
  lock_init (&a);
c002b763:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b767:	89 1c 24             	mov    %ebx,(%esp)
c002b76a:	e8 4e 76 ff ff       	call   c0022dbd <lock_init>
  lock_init (&b);
c002b76f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b773:	89 34 24             	mov    %esi,(%esp)
c002b776:	e8 42 76 ff ff       	call   c0022dbd <lock_init>
  lock_acquire (&a);
c002b77b:	89 1c 24             	mov    %ebx,(%esp)
c002b77e:	e8 d7 76 ff ff       	call   c0022e5a <lock_acquire>
  locks.a = &a;
c002b783:	89 5c 24 20          	mov    %ebx,0x20(%esp)
  locks.b = &b;
c002b787:	89 74 24 24          	mov    %esi,0x24(%esp)
  thread_create ("medium", PRI_DEFAULT + 1, medium_thread_func, &locks);
c002b78b:	8d 44 24 20          	lea    0x20(%esp),%eax
c002b78f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002b793:	c7 44 24 08 71 b6 02 	movl   $0xc002b671,0x8(%esp)
c002b79a:	c0 
c002b79b:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b7a2:	00 
c002b7a3:	c7 04 24 6a 08 03 c0 	movl   $0xc003086a,(%esp)
c002b7aa:	e8 78 5d ff ff       	call   c0021527 <thread_create>
  thread_yield ();
c002b7af:	e8 d1 5c ff ff       	call   c0021485 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b7b4:	e8 81 57 ff ff       	call   c0020f3a <thread_get_priority>
c002b7b9:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b7bd:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b7c4:	00 
c002b7c5:	c7 04 24 0c 09 03 c0 	movl   $0xc003090c,(%esp)
c002b7cc:	e8 6c ef ff ff       	call   c002a73d <msg>
  thread_create ("high", PRI_DEFAULT + 2, high_thread_func, &b);
c002b7d1:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b7d5:	c7 44 24 08 3c b6 02 	movl   $0xc002b63c,0x8(%esp)
c002b7dc:	c0 
c002b7dd:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b7e4:	00 
c002b7e5:	c7 04 24 71 08 03 c0 	movl   $0xc0030871,(%esp)
c002b7ec:	e8 36 5d ff ff       	call   c0021527 <thread_create>
  thread_yield ();
c002b7f1:	e8 8f 5c ff ff       	call   c0021485 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b7f6:	e8 3f 57 ff ff       	call   c0020f3a <thread_get_priority>
c002b7fb:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b7ff:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b806:	00 
c002b807:	c7 04 24 0c 09 03 c0 	movl   $0xc003090c,(%esp)
c002b80e:	e8 2a ef ff ff       	call   c002a73d <msg>
  lock_release (&a);
c002b813:	89 1c 24             	mov    %ebx,(%esp)
c002b816:	e8 09 78 ff ff       	call   c0023024 <lock_release>
  thread_yield ();
c002b81b:	e8 65 5c ff ff       	call   c0021485 <thread_yield>
  msg ("Medium thread should just have finished.");
c002b820:	c7 04 24 48 09 03 c0 	movl   $0xc0030948,(%esp)
c002b827:	e8 11 ef ff ff       	call   c002a73d <msg>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b82c:	e8 09 57 ff ff       	call   c0020f3a <thread_get_priority>
c002b831:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b835:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b83c:	00 
c002b83d:	c7 04 24 0c 09 03 c0 	movl   $0xc003090c,(%esp)
c002b844:	e8 f4 ee ff ff       	call   c002a73d <msg>
}
c002b849:	83 c4 74             	add    $0x74,%esp
c002b84c:	5b                   	pop    %ebx
c002b84d:	5e                   	pop    %esi
c002b84e:	c3                   	ret    

c002b84f <h_thread_func>:
  msg ("Thread M finished.");
}

static void
h_thread_func (void *ls_) 
{
c002b84f:	53                   	push   %ebx
c002b850:	83 ec 18             	sub    $0x18,%esp
c002b853:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock_and_sema *ls = ls_;

  lock_acquire (&ls->lock);
c002b857:	89 1c 24             	mov    %ebx,(%esp)
c002b85a:	e8 fb 75 ff ff       	call   c0022e5a <lock_acquire>
  msg ("Thread H acquired lock.");
c002b85f:	c7 04 24 71 09 03 c0 	movl   $0xc0030971,(%esp)
c002b866:	e8 d2 ee ff ff       	call   c002a73d <msg>

  sema_up (&ls->sema);
c002b86b:	8d 43 24             	lea    0x24(%ebx),%eax
c002b86e:	89 04 24             	mov    %eax,(%esp)
c002b871:	e8 d1 73 ff ff       	call   c0022c47 <sema_up>
  lock_release (&ls->lock);
c002b876:	89 1c 24             	mov    %ebx,(%esp)
c002b879:	e8 a6 77 ff ff       	call   c0023024 <lock_release>
  msg ("Thread H finished.");
c002b87e:	c7 04 24 89 09 03 c0 	movl   $0xc0030989,(%esp)
c002b885:	e8 b3 ee ff ff       	call   c002a73d <msg>
}
c002b88a:	83 c4 18             	add    $0x18,%esp
c002b88d:	5b                   	pop    %ebx
c002b88e:	c3                   	ret    

c002b88f <m_thread_func>:
{
c002b88f:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&ls->sema);
c002b892:	8b 44 24 20          	mov    0x20(%esp),%eax
c002b896:	83 c0 24             	add    $0x24,%eax
c002b899:	89 04 24             	mov    %eax,(%esp)
c002b89c:	e8 91 72 ff ff       	call   c0022b32 <sema_down>
  msg ("Thread M finished.");
c002b8a1:	c7 04 24 9c 09 03 c0 	movl   $0xc003099c,(%esp)
c002b8a8:	e8 90 ee ff ff       	call   c002a73d <msg>
}
c002b8ad:	83 c4 1c             	add    $0x1c,%esp
c002b8b0:	c3                   	ret    

c002b8b1 <l_thread_func>:
{
c002b8b1:	53                   	push   %ebx
c002b8b2:	83 ec 18             	sub    $0x18,%esp
c002b8b5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (&ls->lock);
c002b8b9:	89 1c 24             	mov    %ebx,(%esp)
c002b8bc:	e8 99 75 ff ff       	call   c0022e5a <lock_acquire>
  msg ("Thread L acquired lock.");
c002b8c1:	c7 04 24 af 09 03 c0 	movl   $0xc00309af,(%esp)
c002b8c8:	e8 70 ee ff ff       	call   c002a73d <msg>
  sema_down (&ls->sema);
c002b8cd:	8d 43 24             	lea    0x24(%ebx),%eax
c002b8d0:	89 04 24             	mov    %eax,(%esp)
c002b8d3:	e8 5a 72 ff ff       	call   c0022b32 <sema_down>
  msg ("Thread L downed semaphore.");
c002b8d8:	c7 04 24 c7 09 03 c0 	movl   $0xc00309c7,(%esp)
c002b8df:	e8 59 ee ff ff       	call   c002a73d <msg>
  lock_release (&ls->lock);
c002b8e4:	89 1c 24             	mov    %ebx,(%esp)
c002b8e7:	e8 38 77 ff ff       	call   c0023024 <lock_release>
  msg ("Thread L finished.");
c002b8ec:	c7 04 24 e2 09 03 c0 	movl   $0xc00309e2,(%esp)
c002b8f3:	e8 45 ee ff ff       	call   c002a73d <msg>
}
c002b8f8:	83 c4 18             	add    $0x18,%esp
c002b8fb:	5b                   	pop    %ebx
c002b8fc:	c3                   	ret    

c002b8fd <test_priority_donate_sema>:
{
c002b8fd:	56                   	push   %esi
c002b8fe:	53                   	push   %ebx
c002b8ff:	83 ec 64             	sub    $0x64,%esp
  ASSERT (!thread_mlfqs);
c002b902:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b909:	74 2c                	je     c002b937 <test_priority_donate_sema+0x3a>
c002b90b:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b912:	c0 
c002b913:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b91a:	c0 
c002b91b:	c7 44 24 08 e9 df 02 	movl   $0xc002dfe9,0x8(%esp)
c002b922:	c0 
c002b923:	c7 44 24 04 23 00 00 	movl   $0x23,0x4(%esp)
c002b92a:	00 
c002b92b:	c7 04 24 14 0a 03 c0 	movl   $0xc0030a14,(%esp)
c002b932:	e8 4c d0 ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b937:	e8 fe 55 ff ff       	call   c0020f3a <thread_get_priority>
c002b93c:	83 f8 1f             	cmp    $0x1f,%eax
c002b93f:	74 2c                	je     c002b96d <test_priority_donate_sema+0x70>
c002b941:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b948:	c0 
c002b949:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b950:	c0 
c002b951:	c7 44 24 08 e9 df 02 	movl   $0xc002dfe9,0x8(%esp)
c002b958:	c0 
c002b959:	c7 44 24 04 26 00 00 	movl   $0x26,0x4(%esp)
c002b960:	00 
c002b961:	c7 04 24 14 0a 03 c0 	movl   $0xc0030a14,(%esp)
c002b968:	e8 16 d0 ff ff       	call   c0028983 <debug_panic>
  lock_init (&ls.lock);
c002b96d:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b971:	89 1c 24             	mov    %ebx,(%esp)
c002b974:	e8 44 74 ff ff       	call   c0022dbd <lock_init>
  sema_init (&ls.sema, 0);
c002b979:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002b980:	00 
c002b981:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b985:	89 34 24             	mov    %esi,(%esp)
c002b988:	e8 59 71 ff ff       	call   c0022ae6 <sema_init>
  thread_create ("low", PRI_DEFAULT + 1, l_thread_func, &ls);
c002b98d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b991:	c7 44 24 08 b1 b8 02 	movl   $0xc002b8b1,0x8(%esp)
c002b998:	c0 
c002b999:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b9a0:	00 
c002b9a1:	c7 04 24 f5 09 03 c0 	movl   $0xc00309f5,(%esp)
c002b9a8:	e8 7a 5b ff ff       	call   c0021527 <thread_create>
  thread_create ("med", PRI_DEFAULT + 3, m_thread_func, &ls);
c002b9ad:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9b1:	c7 44 24 08 8f b8 02 	movl   $0xc002b88f,0x8(%esp)
c002b9b8:	c0 
c002b9b9:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b9c0:	00 
c002b9c1:	c7 04 24 f9 09 03 c0 	movl   $0xc00309f9,(%esp)
c002b9c8:	e8 5a 5b ff ff       	call   c0021527 <thread_create>
  thread_create ("high", PRI_DEFAULT + 5, h_thread_func, &ls);
c002b9cd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9d1:	c7 44 24 08 4f b8 02 	movl   $0xc002b84f,0x8(%esp)
c002b9d8:	c0 
c002b9d9:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b9e0:	00 
c002b9e1:	c7 04 24 71 08 03 c0 	movl   $0xc0030871,(%esp)
c002b9e8:	e8 3a 5b ff ff       	call   c0021527 <thread_create>
  sema_up (&ls.sema);
c002b9ed:	89 34 24             	mov    %esi,(%esp)
c002b9f0:	e8 52 72 ff ff       	call   c0022c47 <sema_up>
  msg ("Main thread finished.");
c002b9f5:	c7 04 24 fd 09 03 c0 	movl   $0xc00309fd,(%esp)
c002b9fc:	e8 3c ed ff ff       	call   c002a73d <msg>
}
c002ba01:	83 c4 64             	add    $0x64,%esp
c002ba04:	5b                   	pop    %ebx
c002ba05:	5e                   	pop    %esi
c002ba06:	c3                   	ret    

c002ba07 <acquire_thread_func>:
       PRI_DEFAULT - 10, thread_get_priority ());
}

static void
acquire_thread_func (void *lock_) 
{
c002ba07:	53                   	push   %ebx
c002ba08:	83 ec 18             	sub    $0x18,%esp
c002ba0b:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002ba0f:	89 1c 24             	mov    %ebx,(%esp)
c002ba12:	e8 43 74 ff ff       	call   c0022e5a <lock_acquire>
  msg ("acquire: got the lock");
c002ba17:	c7 04 24 3f 0a 03 c0 	movl   $0xc0030a3f,(%esp)
c002ba1e:	e8 1a ed ff ff       	call   c002a73d <msg>
  lock_release (lock);
c002ba23:	89 1c 24             	mov    %ebx,(%esp)
c002ba26:	e8 f9 75 ff ff       	call   c0023024 <lock_release>
  msg ("acquire: done");
c002ba2b:	c7 04 24 55 0a 03 c0 	movl   $0xc0030a55,(%esp)
c002ba32:	e8 06 ed ff ff       	call   c002a73d <msg>
}
c002ba37:	83 c4 18             	add    $0x18,%esp
c002ba3a:	5b                   	pop    %ebx
c002ba3b:	c3                   	ret    

c002ba3c <test_priority_donate_lower>:
{
c002ba3c:	53                   	push   %ebx
c002ba3d:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002ba40:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002ba47:	74 2c                	je     c002ba75 <test_priority_donate_lower+0x39>
c002ba49:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002ba50:	c0 
c002ba51:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ba58:	c0 
c002ba59:	c7 44 24 08 03 e0 02 	movl   $0xc002e003,0x8(%esp)
c002ba60:	c0 
c002ba61:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002ba68:	00 
c002ba69:	c7 04 24 88 0a 03 c0 	movl   $0xc0030a88,(%esp)
c002ba70:	e8 0e cf ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002ba75:	e8 c0 54 ff ff       	call   c0020f3a <thread_get_priority>
c002ba7a:	83 f8 1f             	cmp    $0x1f,%eax
c002ba7d:	74 2c                	je     c002baab <test_priority_donate_lower+0x6f>
c002ba7f:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002ba86:	c0 
c002ba87:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ba8e:	c0 
c002ba8f:	c7 44 24 08 03 e0 02 	movl   $0xc002e003,0x8(%esp)
c002ba96:	c0 
c002ba97:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002ba9e:	00 
c002ba9f:	c7 04 24 88 0a 03 c0 	movl   $0xc0030a88,(%esp)
c002baa6:	e8 d8 ce ff ff       	call   c0028983 <debug_panic>
  lock_init (&lock);
c002baab:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002baaf:	89 1c 24             	mov    %ebx,(%esp)
c002bab2:	e8 06 73 ff ff       	call   c0022dbd <lock_init>
  lock_acquire (&lock);
c002bab7:	89 1c 24             	mov    %ebx,(%esp)
c002baba:	e8 9b 73 ff ff       	call   c0022e5a <lock_acquire>
  thread_create ("acquire", PRI_DEFAULT + 10, acquire_thread_func, &lock);
c002babf:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bac3:	c7 44 24 08 07 ba 02 	movl   $0xc002ba07,0x8(%esp)
c002baca:	c0 
c002bacb:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bad2:	00 
c002bad3:	c7 04 24 63 0a 03 c0 	movl   $0xc0030a63,(%esp)
c002bada:	e8 48 5a ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002badf:	e8 56 54 ff ff       	call   c0020f3a <thread_get_priority>
c002bae4:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bae8:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002baef:	00 
c002baf0:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002baf7:	e8 41 ec ff ff       	call   c002a73d <msg>
  msg ("Lowering base priority...");
c002bafc:	c7 04 24 6b 0a 03 c0 	movl   $0xc0030a6b,(%esp)
c002bb03:	e8 35 ec ff ff       	call   c002a73d <msg>
  thread_set_priority (PRI_DEFAULT - 10);
c002bb08:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
c002bb0f:	e8 81 5b ff ff       	call   c0021695 <thread_set_priority>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb14:	e8 21 54 ff ff       	call   c0020f3a <thread_get_priority>
c002bb19:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb1d:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb24:	00 
c002bb25:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002bb2c:	e8 0c ec ff ff       	call   c002a73d <msg>
  lock_release (&lock);
c002bb31:	89 1c 24             	mov    %ebx,(%esp)
c002bb34:	e8 eb 74 ff ff       	call   c0023024 <lock_release>
  msg ("acquire must already have finished.");
c002bb39:	c7 04 24 b4 0a 03 c0 	movl   $0xc0030ab4,(%esp)
c002bb40:	e8 f8 eb ff ff       	call   c002a73d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb45:	e8 f0 53 ff ff       	call   c0020f3a <thread_get_priority>
c002bb4a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb4e:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bb55:	00 
c002bb56:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002bb5d:	e8 db eb ff ff       	call   c002a73d <msg>
}
c002bb62:	83 c4 58             	add    $0x58,%esp
c002bb65:	5b                   	pop    %ebx
c002bb66:	c3                   	ret    
c002bb67:	90                   	nop
c002bb68:	90                   	nop
c002bb69:	90                   	nop
c002bb6a:	90                   	nop
c002bb6b:	90                   	nop
c002bb6c:	90                   	nop
c002bb6d:	90                   	nop
c002bb6e:	90                   	nop
c002bb6f:	90                   	nop

c002bb70 <simple_thread_func>:
    }
}

static void 
simple_thread_func (void *data_) 
{
c002bb70:	56                   	push   %esi
c002bb71:	53                   	push   %ebx
c002bb72:	83 ec 14             	sub    $0x14,%esp
c002bb75:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002bb79:	be 10 00 00 00       	mov    $0x10,%esi
  struct simple_thread_data *data = data_;
  int i;
  
  for (i = 0; i < ITER_CNT; i++) 
    {
      lock_acquire (data->lock);
c002bb7e:	8b 43 08             	mov    0x8(%ebx),%eax
c002bb81:	89 04 24             	mov    %eax,(%esp)
c002bb84:	e8 d1 72 ff ff       	call   c0022e5a <lock_acquire>
      *(*data->op)++ = data->id;
c002bb89:	8b 53 0c             	mov    0xc(%ebx),%edx
c002bb8c:	8b 02                	mov    (%edx),%eax
c002bb8e:	8d 48 04             	lea    0x4(%eax),%ecx
c002bb91:	89 0a                	mov    %ecx,(%edx)
c002bb93:	8b 13                	mov    (%ebx),%edx
c002bb95:	89 10                	mov    %edx,(%eax)
      lock_release (data->lock);
c002bb97:	8b 43 08             	mov    0x8(%ebx),%eax
c002bb9a:	89 04 24             	mov    %eax,(%esp)
c002bb9d:	e8 82 74 ff ff       	call   c0023024 <lock_release>
      thread_yield ();
c002bba2:	e8 de 58 ff ff       	call   c0021485 <thread_yield>
  for (i = 0; i < ITER_CNT; i++) 
c002bba7:	83 ee 01             	sub    $0x1,%esi
c002bbaa:	75 d2                	jne    c002bb7e <simple_thread_func+0xe>
    }
}
c002bbac:	83 c4 14             	add    $0x14,%esp
c002bbaf:	5b                   	pop    %ebx
c002bbb0:	5e                   	pop    %esi
c002bbb1:	c3                   	ret    

c002bbb2 <test_priority_fifo>:
{
c002bbb2:	55                   	push   %ebp
c002bbb3:	57                   	push   %edi
c002bbb4:	56                   	push   %esi
c002bbb5:	53                   	push   %ebx
c002bbb6:	81 ec 6c 01 00 00    	sub    $0x16c,%esp
  ASSERT (!thread_mlfqs);
c002bbbc:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002bbc3:	74 2c                	je     c002bbf1 <test_priority_fifo+0x3f>
c002bbc5:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002bbcc:	c0 
c002bbcd:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bbd4:	c0 
c002bbd5:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bbdc:	c0 
c002bbdd:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002bbe4:	00 
c002bbe5:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bbec:	e8 92 cd ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002bbf1:	e8 44 53 ff ff       	call   c0020f3a <thread_get_priority>
c002bbf6:	83 f8 1f             	cmp    $0x1f,%eax
c002bbf9:	74 2c                	je     c002bc27 <test_priority_fifo+0x75>
c002bbfb:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002bc02:	c0 
c002bc03:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bc0a:	c0 
c002bc0b:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bc12:	c0 
c002bc13:	c7 44 24 04 2b 00 00 	movl   $0x2b,0x4(%esp)
c002bc1a:	00 
c002bc1b:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bc22:	e8 5c cd ff ff       	call   c0028983 <debug_panic>
  msg ("%d threads will iterate %d times in the same order each time.",
c002bc27:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c002bc2e:	00 
c002bc2f:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bc36:	00 
c002bc37:	c7 04 24 2c 0b 03 c0 	movl   $0xc0030b2c,(%esp)
c002bc3e:	e8 fa ea ff ff       	call   c002a73d <msg>
  msg ("If the order varies then there is a bug.");
c002bc43:	c7 04 24 6c 0b 03 c0 	movl   $0xc0030b6c,(%esp)
c002bc4a:	e8 ee ea ff ff       	call   c002a73d <msg>
  output = op = malloc (sizeof *output * THREAD_CNT * ITER_CNT * 2);
c002bc4f:	c7 04 24 00 08 00 00 	movl   $0x800,(%esp)
c002bc56:	e8 c9 7d ff ff       	call   c0023a24 <malloc>
c002bc5b:	89 c6                	mov    %eax,%esi
c002bc5d:	89 44 24 38          	mov    %eax,0x38(%esp)
  ASSERT (output != NULL);
c002bc61:	85 c0                	test   %eax,%eax
c002bc63:	75 2c                	jne    c002bc91 <test_priority_fifo+0xdf>
c002bc65:	c7 44 24 10 0a 01 03 	movl   $0xc003010a,0x10(%esp)
c002bc6c:	c0 
c002bc6d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bc74:	c0 
c002bc75:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bc7c:	c0 
c002bc7d:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c002bc84:	00 
c002bc85:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bc8c:	e8 f2 cc ff ff       	call   c0028983 <debug_panic>
  lock_init (&lock);
c002bc91:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bc95:	89 04 24             	mov    %eax,(%esp)
c002bc98:	e8 20 71 ff ff       	call   c0022dbd <lock_init>
  thread_set_priority (PRI_DEFAULT + 2);
c002bc9d:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c002bca4:	e8 ec 59 ff ff       	call   c0021695 <thread_set_priority>
c002bca9:	8d 5c 24 60          	lea    0x60(%esp),%ebx
  for (i = 0; i < THREAD_CNT; i++) 
c002bcad:	bf 00 00 00 00       	mov    $0x0,%edi
      snprintf (name, sizeof name, "%d", i);
c002bcb2:	8d 6c 24 28          	lea    0x28(%esp),%ebp
c002bcb6:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002bcba:	c7 44 24 08 20 01 03 	movl   $0xc0030120,0x8(%esp)
c002bcc1:	c0 
c002bcc2:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bcc9:	00 
c002bcca:	89 2c 24             	mov    %ebp,(%esp)
c002bccd:	e8 5d b5 ff ff       	call   c002722f <snprintf>
      d->id = i;
c002bcd2:	89 3b                	mov    %edi,(%ebx)
      d->iterations = 0;
c002bcd4:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
      d->lock = &lock;
c002bcdb:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bcdf:	89 43 08             	mov    %eax,0x8(%ebx)
      d->op = &op;
c002bce2:	8d 44 24 38          	lea    0x38(%esp),%eax
c002bce6:	89 43 0c             	mov    %eax,0xc(%ebx)
      thread_create (name, PRI_DEFAULT + 1, simple_thread_func, d);
c002bce9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bced:	c7 44 24 08 70 bb 02 	movl   $0xc002bb70,0x8(%esp)
c002bcf4:	c0 
c002bcf5:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bcfc:	00 
c002bcfd:	89 2c 24             	mov    %ebp,(%esp)
c002bd00:	e8 22 58 ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002bd05:	83 c7 01             	add    $0x1,%edi
c002bd08:	83 c3 10             	add    $0x10,%ebx
c002bd0b:	83 ff 10             	cmp    $0x10,%edi
c002bd0e:	75 a6                	jne    c002bcb6 <test_priority_fifo+0x104>
  thread_set_priority (PRI_DEFAULT);
c002bd10:	c7 04 24 1f 00 00 00 	movl   $0x1f,(%esp)
c002bd17:	e8 79 59 ff ff       	call   c0021695 <thread_set_priority>
  ASSERT (lock.holder == NULL);
c002bd1c:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002bd21:	75 13                	jne    c002bd36 <test_priority_fifo+0x184>
  for (; output < op; output++) 
c002bd23:	3b 74 24 38          	cmp    0x38(%esp),%esi
c002bd27:	0f 83 be 00 00 00    	jae    c002bdeb <test_priority_fifo+0x239>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd2d:	8b 3e                	mov    (%esi),%edi
c002bd2f:	83 ff 0f             	cmp    $0xf,%edi
c002bd32:	76 61                	jbe    c002bd95 <test_priority_fifo+0x1e3>
c002bd34:	eb 33                	jmp    c002bd69 <test_priority_fifo+0x1b7>
  ASSERT (lock.holder == NULL);
c002bd36:	c7 44 24 10 d8 0a 03 	movl   $0xc0030ad8,0x10(%esp)
c002bd3d:	c0 
c002bd3e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bd45:	c0 
c002bd46:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bd4d:	c0 
c002bd4e:	c7 44 24 04 44 00 00 	movl   $0x44,0x4(%esp)
c002bd55:	00 
c002bd56:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bd5d:	e8 21 cc ff ff       	call   c0028983 <debug_panic>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd62:	8b 3e                	mov    (%esi),%edi
c002bd64:	83 ff 0f             	cmp    $0xf,%edi
c002bd67:	76 31                	jbe    c002bd9a <test_priority_fifo+0x1e8>
c002bd69:	c7 44 24 10 98 0b 03 	movl   $0xc0030b98,0x10(%esp)
c002bd70:	c0 
c002bd71:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bd78:	c0 
c002bd79:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bd80:	c0 
c002bd81:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002bd88:	00 
c002bd89:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bd90:	e8 ee cb ff ff       	call   c0028983 <debug_panic>
c002bd95:	bb 00 00 00 00       	mov    $0x0,%ebx
      d = data + *output;
c002bd9a:	c1 e7 04             	shl    $0x4,%edi
c002bd9d:	8d 44 24 60          	lea    0x60(%esp),%eax
c002bda1:	01 c7                	add    %eax,%edi
      if (cnt % THREAD_CNT == 0)
c002bda3:	f6 c3 0f             	test   $0xf,%bl
c002bda6:	75 0c                	jne    c002bdb4 <test_priority_fifo+0x202>
        printf ("(priority-fifo) iteration:");
c002bda8:	c7 04 24 ec 0a 03 c0 	movl   $0xc0030aec,(%esp)
c002bdaf:	e8 7a ad ff ff       	call   c0026b2e <printf>
      printf (" %d", d->id);
c002bdb4:	8b 07                	mov    (%edi),%eax
c002bdb6:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bdba:	c7 04 24 1f 01 03 c0 	movl   $0xc003011f,(%esp)
c002bdc1:	e8 68 ad ff ff       	call   c0026b2e <printf>
      if (++cnt % THREAD_CNT == 0)
c002bdc6:	83 c3 01             	add    $0x1,%ebx
c002bdc9:	f6 c3 0f             	test   $0xf,%bl
c002bdcc:	75 0c                	jne    c002bdda <test_priority_fifo+0x228>
        printf ("\n");
c002bdce:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002bdd5:	e8 42 e9 ff ff       	call   c002a71c <putchar>
      d->iterations++;
c002bdda:	83 47 04 01          	addl   $0x1,0x4(%edi)
  for (; output < op; output++) 
c002bdde:	83 c6 04             	add    $0x4,%esi
c002bde1:	39 74 24 38          	cmp    %esi,0x38(%esp)
c002bde5:	0f 87 77 ff ff ff    	ja     c002bd62 <test_priority_fifo+0x1b0>
}
c002bdeb:	81 c4 6c 01 00 00    	add    $0x16c,%esp
c002bdf1:	5b                   	pop    %ebx
c002bdf2:	5e                   	pop    %esi
c002bdf3:	5f                   	pop    %edi
c002bdf4:	5d                   	pop    %ebp
c002bdf5:	c3                   	ret    

c002bdf6 <simple_thread_func>:
  msg ("The high-priority thread should have already completed.");
}

static void 
simple_thread_func (void *aux UNUSED) 
{
c002bdf6:	53                   	push   %ebx
c002bdf7:	83 ec 18             	sub    $0x18,%esp
  int i;
  
  for (i = 0; i < 5; i++) 
c002bdfa:	bb 00 00 00 00       	mov    $0x0,%ebx
    {
      msg ("Thread %s iteration %d", thread_name (), i);
c002bdff:	e8 99 50 ff ff       	call   c0020e9d <thread_name>
c002be04:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002be08:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be0c:	c7 04 24 bd 0b 03 c0 	movl   $0xc0030bbd,(%esp)
c002be13:	e8 25 e9 ff ff       	call   c002a73d <msg>
      thread_yield ();
c002be18:	e8 68 56 ff ff       	call   c0021485 <thread_yield>
  for (i = 0; i < 5; i++) 
c002be1d:	83 c3 01             	add    $0x1,%ebx
c002be20:	83 fb 05             	cmp    $0x5,%ebx
c002be23:	75 da                	jne    c002bdff <simple_thread_func+0x9>
    }
  msg ("Thread %s done!", thread_name ());
c002be25:	e8 73 50 ff ff       	call   c0020e9d <thread_name>
c002be2a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be2e:	c7 04 24 d4 0b 03 c0 	movl   $0xc0030bd4,(%esp)
c002be35:	e8 03 e9 ff ff       	call   c002a73d <msg>
}
c002be3a:	83 c4 18             	add    $0x18,%esp
c002be3d:	5b                   	pop    %ebx
c002be3e:	c3                   	ret    

c002be3f <test_priority_preempt>:
{
c002be3f:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002be42:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002be49:	74 2c                	je     c002be77 <test_priority_preempt+0x38>
c002be4b:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002be52:	c0 
c002be53:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002be5a:	c0 
c002be5b:	c7 44 24 08 31 e0 02 	movl   $0xc002e031,0x8(%esp)
c002be62:	c0 
c002be63:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002be6a:	00 
c002be6b:	c7 04 24 f4 0b 03 c0 	movl   $0xc0030bf4,(%esp)
c002be72:	e8 0c cb ff ff       	call   c0028983 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002be77:	e8 be 50 ff ff       	call   c0020f3a <thread_get_priority>
c002be7c:	83 f8 1f             	cmp    $0x1f,%eax
c002be7f:	74 2c                	je     c002bead <test_priority_preempt+0x6e>
c002be81:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002be88:	c0 
c002be89:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002be90:	c0 
c002be91:	c7 44 24 08 31 e0 02 	movl   $0xc002e031,0x8(%esp)
c002be98:	c0 
c002be99:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002bea0:	00 
c002bea1:	c7 04 24 f4 0b 03 c0 	movl   $0xc0030bf4,(%esp)
c002bea8:	e8 d6 ca ff ff       	call   c0028983 <debug_panic>
  thread_create ("high-priority", PRI_DEFAULT + 1, simple_thread_func, NULL);
c002bead:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002beb4:	00 
c002beb5:	c7 44 24 08 f6 bd 02 	movl   $0xc002bdf6,0x8(%esp)
c002bebc:	c0 
c002bebd:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bec4:	00 
c002bec5:	c7 04 24 e4 0b 03 c0 	movl   $0xc0030be4,(%esp)
c002becc:	e8 56 56 ff ff       	call   c0021527 <thread_create>
  msg ("The high-priority thread should have already completed.");
c002bed1:	c7 04 24 1c 0c 03 c0 	movl   $0xc0030c1c,(%esp)
c002bed8:	e8 60 e8 ff ff       	call   c002a73d <msg>
}
c002bedd:	83 c4 2c             	add    $0x2c,%esp
c002bee0:	c3                   	ret    

c002bee1 <priority_sema_thread>:
    }
}

static void
priority_sema_thread (void *aux UNUSED) 
{
c002bee1:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&sema);
c002bee4:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002beeb:	e8 42 6c ff ff       	call   c0022b32 <sema_down>
  msg ("Thread %s woke up.", thread_name ());
c002bef0:	e8 a8 4f ff ff       	call   c0020e9d <thread_name>
c002bef5:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bef9:	c7 04 24 f0 03 03 c0 	movl   $0xc00303f0,(%esp)
c002bf00:	e8 38 e8 ff ff       	call   c002a73d <msg>
}
c002bf05:	83 c4 1c             	add    $0x1c,%esp
c002bf08:	c3                   	ret    

c002bf09 <test_priority_sema>:
{
c002bf09:	55                   	push   %ebp
c002bf0a:	57                   	push   %edi
c002bf0b:	56                   	push   %esi
c002bf0c:	53                   	push   %ebx
c002bf0d:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002bf10:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002bf17:	74 2c                	je     c002bf45 <test_priority_sema+0x3c>
c002bf19:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002bf20:	c0 
c002bf21:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bf28:	c0 
c002bf29:	c7 44 24 08 47 e0 02 	movl   $0xc002e047,0x8(%esp)
c002bf30:	c0 
c002bf31:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bf38:	00 
c002bf39:	c7 04 24 6c 0c 03 c0 	movl   $0xc0030c6c,(%esp)
c002bf40:	e8 3e ca ff ff       	call   c0028983 <debug_panic>
  sema_init (&sema, 0);
c002bf45:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002bf4c:	00 
c002bf4d:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bf54:	e8 8d 6b ff ff       	call   c0022ae6 <sema_init>
  thread_set_priority (PRI_MIN);
c002bf59:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002bf60:	e8 30 57 ff ff       	call   c0021695 <thread_set_priority>
c002bf65:	bb 03 00 00 00       	mov    $0x3,%ebx
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bf6a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002bf6f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bf73:	89 d8                	mov    %ebx,%eax
c002bf75:	f7 ed                	imul   %ebp
c002bf77:	c1 fa 02             	sar    $0x2,%edx
c002bf7a:	89 d8                	mov    %ebx,%eax
c002bf7c:	c1 f8 1f             	sar    $0x1f,%eax
c002bf7f:	29 c2                	sub    %eax,%edx
c002bf81:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002bf84:	01 c0                	add    %eax,%eax
c002bf86:	29 d8                	sub    %ebx,%eax
c002bf88:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002bf8b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002bf8f:	c7 44 24 08 03 04 03 	movl   $0xc0030403,0x8(%esp)
c002bf96:	c0 
c002bf97:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bf9e:	00 
c002bf9f:	89 3c 24             	mov    %edi,(%esp)
c002bfa2:	e8 88 b2 ff ff       	call   c002722f <snprintf>
      thread_create (name, priority, priority_sema_thread, NULL);
c002bfa7:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bfae:	00 
c002bfaf:	c7 44 24 08 e1 be 02 	movl   $0xc002bee1,0x8(%esp)
c002bfb6:	c0 
c002bfb7:	89 74 24 04          	mov    %esi,0x4(%esp)
c002bfbb:	89 3c 24             	mov    %edi,(%esp)
c002bfbe:	e8 64 55 ff ff       	call   c0021527 <thread_create>
c002bfc3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002bfc6:	83 fb 0d             	cmp    $0xd,%ebx
c002bfc9:	75 a8                	jne    c002bf73 <test_priority_sema+0x6a>
c002bfcb:	b3 0a                	mov    $0xa,%bl
      sema_up (&sema);
c002bfcd:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bfd4:	e8 6e 6c ff ff       	call   c0022c47 <sema_up>
      msg ("Back in main thread."); 
c002bfd9:	c7 04 24 54 0c 03 c0 	movl   $0xc0030c54,(%esp)
c002bfe0:	e8 58 e7 ff ff       	call   c002a73d <msg>
  for (i = 0; i < 10; i++) 
c002bfe5:	83 eb 01             	sub    $0x1,%ebx
c002bfe8:	75 e3                	jne    c002bfcd <test_priority_sema+0xc4>
}
c002bfea:	83 c4 3c             	add    $0x3c,%esp
c002bfed:	5b                   	pop    %ebx
c002bfee:	5e                   	pop    %esi
c002bfef:	5f                   	pop    %edi
c002bff0:	5d                   	pop    %ebp
c002bff1:	c3                   	ret    

c002bff2 <priority_condvar_thread>:
    }
}

static void
priority_condvar_thread (void *aux UNUSED) 
{
c002bff2:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread %s starting.", thread_name ());
c002bff5:	e8 a3 4e ff ff       	call   c0020e9d <thread_name>
c002bffa:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bffe:	c7 04 24 90 0c 03 c0 	movl   $0xc0030c90,(%esp)
c002c005:	e8 33 e7 ff ff       	call   c002a73d <msg>
  lock_acquire (&lock);
c002c00a:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c011:	e8 44 6e ff ff       	call   c0022e5a <lock_acquire>
  cond_wait (&condition, &lock);
c002c016:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c01d:	c0 
c002c01e:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c025:	e8 36 71 ff ff       	call   c0023160 <cond_wait>
  msg ("Thread %s woke up.", thread_name ());
c002c02a:	e8 6e 4e ff ff       	call   c0020e9d <thread_name>
c002c02f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c033:	c7 04 24 f0 03 03 c0 	movl   $0xc00303f0,(%esp)
c002c03a:	e8 fe e6 ff ff       	call   c002a73d <msg>
  lock_release (&lock);
c002c03f:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c046:	e8 d9 6f ff ff       	call   c0023024 <lock_release>
}
c002c04b:	83 c4 1c             	add    $0x1c,%esp
c002c04e:	c3                   	ret    

c002c04f <test_priority_condvar>:
{
c002c04f:	55                   	push   %ebp
c002c050:	57                   	push   %edi
c002c051:	56                   	push   %esi
c002c052:	53                   	push   %ebx
c002c053:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002c056:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c05d:	74 2c                	je     c002c08b <test_priority_condvar+0x3c>
c002c05f:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002c066:	c0 
c002c067:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c06e:	c0 
c002c06f:	c7 44 24 08 5a e0 02 	movl   $0xc002e05a,0x8(%esp)
c002c076:	c0 
c002c077:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002c07e:	00 
c002c07f:	c7 04 24 b4 0c 03 c0 	movl   $0xc0030cb4,(%esp)
c002c086:	e8 f8 c8 ff ff       	call   c0028983 <debug_panic>
  lock_init (&lock);
c002c08b:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c092:	e8 26 6d ff ff       	call   c0022dbd <lock_init>
  cond_init (&condition);
c002c097:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c09e:	e8 7a 70 ff ff       	call   c002311d <cond_init>
  thread_set_priority (PRI_MIN);
c002c0a3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c0aa:	e8 e6 55 ff ff       	call   c0021695 <thread_set_priority>
c002c0af:	bb 07 00 00 00       	mov    $0x7,%ebx
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0b4:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002c0b9:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0bd:	89 d8                	mov    %ebx,%eax
c002c0bf:	f7 ed                	imul   %ebp
c002c0c1:	c1 fa 02             	sar    $0x2,%edx
c002c0c4:	89 d8                	mov    %ebx,%eax
c002c0c6:	c1 f8 1f             	sar    $0x1f,%eax
c002c0c9:	29 c2                	sub    %eax,%edx
c002c0cb:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002c0ce:	01 c0                	add    %eax,%eax
c002c0d0:	29 d8                	sub    %ebx,%eax
c002c0d2:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002c0d5:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c0d9:	c7 44 24 08 03 04 03 	movl   $0xc0030403,0x8(%esp)
c002c0e0:	c0 
c002c0e1:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c0e8:	00 
c002c0e9:	89 3c 24             	mov    %edi,(%esp)
c002c0ec:	e8 3e b1 ff ff       	call   c002722f <snprintf>
      thread_create (name, priority, priority_condvar_thread, NULL);
c002c0f1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c0f8:	00 
c002c0f9:	c7 44 24 08 f2 bf 02 	movl   $0xc002bff2,0x8(%esp)
c002c100:	c0 
c002c101:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c105:	89 3c 24             	mov    %edi,(%esp)
c002c108:	e8 1a 54 ff ff       	call   c0021527 <thread_create>
c002c10d:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002c110:	83 fb 11             	cmp    $0x11,%ebx
c002c113:	75 a8                	jne    c002c0bd <test_priority_condvar+0x6e>
c002c115:	b3 0a                	mov    $0xa,%bl
      lock_acquire (&lock);
c002c117:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c11e:	e8 37 6d ff ff       	call   c0022e5a <lock_acquire>
      msg ("Signaling...");
c002c123:	c7 04 24 a4 0c 03 c0 	movl   $0xc0030ca4,(%esp)
c002c12a:	e8 0e e6 ff ff       	call   c002a73d <msg>
      cond_signal (&condition, &lock);
c002c12f:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c136:	c0 
c002c137:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c13e:	e8 46 71 ff ff       	call   c0023289 <cond_signal>
      lock_release (&lock);
c002c143:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c14a:	e8 d5 6e ff ff       	call   c0023024 <lock_release>
  for (i = 0; i < 10; i++) 
c002c14f:	83 eb 01             	sub    $0x1,%ebx
c002c152:	75 c3                	jne    c002c117 <test_priority_condvar+0xc8>
}
c002c154:	83 c4 3c             	add    $0x3c,%esp
c002c157:	5b                   	pop    %ebx
c002c158:	5e                   	pop    %esi
c002c159:	5f                   	pop    %edi
c002c15a:	5d                   	pop    %ebp
c002c15b:	c3                   	ret    

c002c15c <interloper_thread_func>:
                                         thread_get_priority ());
}

static void
interloper_thread_func (void *arg_ UNUSED)
{
c002c15c:	83 ec 1c             	sub    $0x1c,%esp
  msg ("%s finished.", thread_name ());
c002c15f:	e8 39 4d ff ff       	call   c0020e9d <thread_name>
c002c164:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c168:	c7 04 24 db 0c 03 c0 	movl   $0xc0030cdb,(%esp)
c002c16f:	e8 c9 e5 ff ff       	call   c002a73d <msg>
}
c002c174:	83 c4 1c             	add    $0x1c,%esp
c002c177:	c3                   	ret    

c002c178 <donor_thread_func>:
{
c002c178:	56                   	push   %esi
c002c179:	53                   	push   %ebx
c002c17a:	83 ec 14             	sub    $0x14,%esp
c002c17d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (locks->first)
c002c181:	8b 43 04             	mov    0x4(%ebx),%eax
c002c184:	85 c0                	test   %eax,%eax
c002c186:	74 08                	je     c002c190 <donor_thread_func+0x18>
    lock_acquire (locks->first);
c002c188:	89 04 24             	mov    %eax,(%esp)
c002c18b:	e8 ca 6c ff ff       	call   c0022e5a <lock_acquire>
  lock_acquire (locks->second);
c002c190:	8b 03                	mov    (%ebx),%eax
c002c192:	89 04 24             	mov    %eax,(%esp)
c002c195:	e8 c0 6c ff ff       	call   c0022e5a <lock_acquire>
  msg ("%s got lock", thread_name ());
c002c19a:	e8 fe 4c ff ff       	call   c0020e9d <thread_name>
c002c19f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1a3:	c7 04 24 e8 0c 03 c0 	movl   $0xc0030ce8,(%esp)
c002c1aa:	e8 8e e5 ff ff       	call   c002a73d <msg>
  lock_release (locks->second);
c002c1af:	8b 03                	mov    (%ebx),%eax
c002c1b1:	89 04 24             	mov    %eax,(%esp)
c002c1b4:	e8 6b 6e ff ff       	call   c0023024 <lock_release>
  msg ("%s should have priority %d. Actual priority: %d", 
c002c1b9:	e8 7c 4d ff ff       	call   c0020f3a <thread_get_priority>
c002c1be:	89 c6                	mov    %eax,%esi
c002c1c0:	e8 d8 4c ff ff       	call   c0020e9d <thread_name>
c002c1c5:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c1c9:	c7 44 24 08 15 00 00 	movl   $0x15,0x8(%esp)
c002c1d0:	00 
c002c1d1:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1d5:	c7 04 24 10 0d 03 c0 	movl   $0xc0030d10,(%esp)
c002c1dc:	e8 5c e5 ff ff       	call   c002a73d <msg>
  if (locks->first)
c002c1e1:	8b 43 04             	mov    0x4(%ebx),%eax
c002c1e4:	85 c0                	test   %eax,%eax
c002c1e6:	74 08                	je     c002c1f0 <donor_thread_func+0x78>
    lock_release (locks->first);
c002c1e8:	89 04 24             	mov    %eax,(%esp)
c002c1eb:	e8 34 6e ff ff       	call   c0023024 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c1f0:	e8 45 4d ff ff       	call   c0020f3a <thread_get_priority>
c002c1f5:	89 c3                	mov    %eax,%ebx
c002c1f7:	e8 a1 4c ff ff       	call   c0020e9d <thread_name>
c002c1fc:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c200:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c204:	c7 04 24 40 0d 03 c0 	movl   $0xc0030d40,(%esp)
c002c20b:	e8 2d e5 ff ff       	call   c002a73d <msg>
}
c002c210:	83 c4 14             	add    $0x14,%esp
c002c213:	5b                   	pop    %ebx
c002c214:	5e                   	pop    %esi
c002c215:	c3                   	ret    

c002c216 <test_priority_donate_chain>:
{
c002c216:	55                   	push   %ebp
c002c217:	57                   	push   %edi
c002c218:	56                   	push   %esi
c002c219:	53                   	push   %ebx
c002c21a:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
  ASSERT (!thread_mlfqs);
c002c220:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c227:	74 2c                	je     c002c255 <test_priority_donate_chain+0x3f>
c002c229:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002c230:	c0 
c002c231:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c238:	c0 
c002c239:	c7 44 24 08 70 e0 02 	movl   $0xc002e070,0x8(%esp)
c002c240:	c0 
c002c241:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c002c248:	00 
c002c249:	c7 04 24 60 0d 03 c0 	movl   $0xc0030d60,(%esp)
c002c250:	e8 2e c7 ff ff       	call   c0028983 <debug_panic>
  thread_set_priority (PRI_MIN);
c002c255:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c25c:	e8 34 54 ff ff       	call   c0021695 <thread_set_priority>
c002c261:	8d 5c 24 74          	lea    0x74(%esp),%ebx
c002c265:	8d b4 24 70 01 00 00 	lea    0x170(%esp),%esi
    lock_init (&locks[i]);
c002c26c:	89 1c 24             	mov    %ebx,(%esp)
c002c26f:	e8 49 6b ff ff       	call   c0022dbd <lock_init>
c002c274:	83 c3 24             	add    $0x24,%ebx
  for (i = 0; i < NESTING_DEPTH - 1; i++)
c002c277:	39 f3                	cmp    %esi,%ebx
c002c279:	75 f1                	jne    c002c26c <test_priority_donate_chain+0x56>
  lock_acquire (&locks[0]);
c002c27b:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c27f:	89 04 24             	mov    %eax,(%esp)
c002c282:	e8 d3 6b ff ff       	call   c0022e5a <lock_acquire>
  msg ("%s got lock.", thread_name ());
c002c287:	e8 11 4c ff ff       	call   c0020e9d <thread_name>
c002c28c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c290:	c7 04 24 f4 0c 03 c0 	movl   $0xc0030cf4,(%esp)
c002c297:	e8 a1 e4 ff ff       	call   c002a73d <msg>
c002c29c:	8d 84 24 98 00 00 00 	lea    0x98(%esp),%eax
c002c2a3:	89 44 24 14          	mov    %eax,0x14(%esp)
c002c2a7:	8d 74 24 40          	lea    0x40(%esp),%esi
c002c2ab:	bf 03 00 00 00       	mov    $0x3,%edi
  for (i = 1; i < NESTING_DEPTH; i++)
c002c2b0:	bb 01 00 00 00       	mov    $0x1,%ebx
      snprintf (name, sizeof name, "thread %d", i);
c002c2b5:	8d 6c 24 24          	lea    0x24(%esp),%ebp
c002c2b9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c2bd:	c7 44 24 08 19 01 03 	movl   $0xc0030119,0x8(%esp)
c002c2c4:	c0 
c002c2c5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c2cc:	00 
c002c2cd:	89 2c 24             	mov    %ebp,(%esp)
c002c2d0:	e8 5a af ff ff       	call   c002722f <snprintf>
      lock_pairs[i].first = i < NESTING_DEPTH - 1 ? locks + i: NULL;
c002c2d5:	83 fb 06             	cmp    $0x6,%ebx
c002c2d8:	b8 00 00 00 00       	mov    $0x0,%eax
c002c2dd:	8b 54 24 14          	mov    0x14(%esp),%edx
c002c2e1:	0f 4e c2             	cmovle %edx,%eax
c002c2e4:	89 06                	mov    %eax,(%esi)
c002c2e6:	89 d0                	mov    %edx,%eax
c002c2e8:	83 e8 24             	sub    $0x24,%eax
c002c2eb:	89 46 fc             	mov    %eax,-0x4(%esi)
c002c2ee:	8d 46 fc             	lea    -0x4(%esi),%eax
      thread_create (name, thread_priority, donor_thread_func, lock_pairs + i);
c002c2f1:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c2f5:	c7 44 24 08 78 c1 02 	movl   $0xc002c178,0x8(%esp)
c002c2fc:	c0 
c002c2fd:	89 7c 24 18          	mov    %edi,0x18(%esp)
c002c301:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c305:	89 2c 24             	mov    %ebp,(%esp)
c002c308:	e8 1a 52 ff ff       	call   c0021527 <thread_create>
      msg ("%s should have priority %d.  Actual priority: %d.",
c002c30d:	e8 28 4c ff ff       	call   c0020f3a <thread_get_priority>
c002c312:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002c316:	e8 82 4b ff ff       	call   c0020e9d <thread_name>
c002c31b:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c31f:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002c323:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c002c327:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002c32b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c32f:	c7 04 24 8c 0d 03 c0 	movl   $0xc0030d8c,(%esp)
c002c336:	e8 02 e4 ff ff       	call   c002a73d <msg>
      snprintf (name, sizeof name, "interloper %d", i);
c002c33b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c33f:	c7 44 24 08 01 0d 03 	movl   $0xc0030d01,0x8(%esp)
c002c346:	c0 
c002c347:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c34e:	00 
c002c34f:	89 2c 24             	mov    %ebp,(%esp)
c002c352:	e8 d8 ae ff ff       	call   c002722f <snprintf>
      thread_create (name, thread_priority - 1, interloper_thread_func, NULL);
c002c357:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c35e:	00 
c002c35f:	c7 44 24 08 5c c1 02 	movl   $0xc002c15c,0x8(%esp)
c002c366:	c0 
c002c367:	8d 47 ff             	lea    -0x1(%edi),%eax
c002c36a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c36e:	89 2c 24             	mov    %ebp,(%esp)
c002c371:	e8 b1 51 ff ff       	call   c0021527 <thread_create>
  for (i = 1; i < NESTING_DEPTH; i++)
c002c376:	83 c3 01             	add    $0x1,%ebx
c002c379:	83 44 24 14 24       	addl   $0x24,0x14(%esp)
c002c37e:	83 c6 08             	add    $0x8,%esi
c002c381:	83 c7 03             	add    $0x3,%edi
c002c384:	83 fb 08             	cmp    $0x8,%ebx
c002c387:	0f 85 2c ff ff ff    	jne    c002c2b9 <test_priority_donate_chain+0xa3>
  lock_release (&locks[0]);
c002c38d:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c391:	89 04 24             	mov    %eax,(%esp)
c002c394:	e8 8b 6c ff ff       	call   c0023024 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c399:	e8 9c 4b ff ff       	call   c0020f3a <thread_get_priority>
c002c39e:	89 c3                	mov    %eax,%ebx
c002c3a0:	e8 f8 4a ff ff       	call   c0020e9d <thread_name>
c002c3a5:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c3a9:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c3ad:	c7 04 24 40 0d 03 c0 	movl   $0xc0030d40,(%esp)
c002c3b4:	e8 84 e3 ff ff       	call   c002a73d <msg>
}
c002c3b9:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002c3bf:	5b                   	pop    %ebx
c002c3c0:	5e                   	pop    %esi
c002c3c1:	5f                   	pop    %edi
c002c3c2:	5d                   	pop    %ebp
c002c3c3:	c3                   	ret    
c002c3c4:	90                   	nop
c002c3c5:	90                   	nop
c002c3c6:	90                   	nop
c002c3c7:	90                   	nop
c002c3c8:	90                   	nop
c002c3c9:	90                   	nop
c002c3ca:	90                   	nop
c002c3cb:	90                   	nop
c002c3cc:	90                   	nop
c002c3cd:	90                   	nop
c002c3ce:	90                   	nop
c002c3cf:	90                   	nop

c002c3d0 <test_mlfqs_load_1>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_mlfqs_load_1 (void) 
{
c002c3d0:	57                   	push   %edi
c002c3d1:	56                   	push   %esi
c002c3d2:	53                   	push   %ebx
c002c3d3:	83 ec 20             	sub    $0x20,%esp
  int64_t start_time;
  int elapsed;
  int load_avg;
  
  ASSERT (thread_mlfqs);
c002c3d6:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c3dd:	75 2c                	jne    c002c40b <test_mlfqs_load_1+0x3b>
c002c3df:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002c3e6:	c0 
c002c3e7:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c3ee:	c0 
c002c3ef:	c7 44 24 08 8b e0 02 	movl   $0xc002e08b,0x8(%esp)
c002c3f6:	c0 
c002c3f7:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002c3fe:	00 
c002c3ff:	c7 04 24 e8 0d 03 c0 	movl   $0xc0030de8,(%esp)
c002c406:	e8 78 c5 ff ff       	call   c0028983 <debug_panic>

  msg ("spinning for up to 45 seconds, please wait...");
c002c40b:	c7 04 24 0c 0e 03 c0 	movl   $0xc0030e0c,(%esp)
c002c412:	e8 26 e3 ff ff       	call   c002a73d <msg>

  start_time = timer_ticks ();
c002c417:	e8 f4 7d ff ff       	call   c0024210 <timer_ticks>
c002c41c:	89 44 24 18          	mov    %eax,0x18(%esp)
c002c420:	89 54 24 1c          	mov    %edx,0x1c(%esp)
    {
      load_avg = thread_get_load_avg ();
      ASSERT (load_avg >= 0);
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
      if (load_avg > 100)
        fail ("load average is %d.%02d "
c002c424:	bf 1f 85 eb 51       	mov    $0x51eb851f,%edi
      load_avg = thread_get_load_avg ();
c002c429:	e8 2a 4b ff ff       	call   c0020f58 <thread_get_load_avg>
c002c42e:	89 c3                	mov    %eax,%ebx
      ASSERT (load_avg >= 0);
c002c430:	85 c0                	test   %eax,%eax
c002c432:	79 2c                	jns    c002c460 <test_mlfqs_load_1+0x90>
c002c434:	c7 44 24 10 be 0d 03 	movl   $0xc0030dbe,0x10(%esp)
c002c43b:	c0 
c002c43c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c443:	c0 
c002c444:	c7 44 24 08 8b e0 02 	movl   $0xc002e08b,0x8(%esp)
c002c44b:	c0 
c002c44c:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002c453:	00 
c002c454:	c7 04 24 e8 0d 03 c0 	movl   $0xc0030de8,(%esp)
c002c45b:	e8 23 c5 ff ff       	call   c0028983 <debug_panic>
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
c002c460:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c464:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c468:	89 04 24             	mov    %eax,(%esp)
c002c46b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c46f:	e8 c8 7d ff ff       	call   c002423c <timer_elapsed>
c002c474:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c47b:	00 
c002c47c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c483:	00 
c002c484:	89 04 24             	mov    %eax,(%esp)
c002c487:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c48b:	e8 53 be ff ff       	call   c00282e3 <__divdi3>
c002c490:	89 c6                	mov    %eax,%esi
      if (load_avg > 100)
c002c492:	83 fb 64             	cmp    $0x64,%ebx
c002c495:	7e 30                	jle    c002c4c7 <test_mlfqs_load_1+0xf7>
        fail ("load average is %d.%02d "
c002c497:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c49b:	89 d8                	mov    %ebx,%eax
c002c49d:	f7 ef                	imul   %edi
c002c49f:	c1 fa 05             	sar    $0x5,%edx
c002c4a2:	89 d8                	mov    %ebx,%eax
c002c4a4:	c1 f8 1f             	sar    $0x1f,%eax
c002c4a7:	29 c2                	sub    %eax,%edx
c002c4a9:	6b c2 64             	imul   $0x64,%edx,%eax
c002c4ac:	29 c3                	sub    %eax,%ebx
c002c4ae:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c4b2:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c4b6:	c7 04 24 3c 0e 03 c0 	movl   $0xc0030e3c,(%esp)
c002c4bd:	e8 33 e3 ff ff       	call   c002a7f5 <fail>
c002c4c2:	e9 62 ff ff ff       	jmp    c002c429 <test_mlfqs_load_1+0x59>
              "but should be between 0 and 1 (after %d seconds)",
              load_avg / 100, load_avg % 100, elapsed);
      else if (load_avg > 50)
c002c4c7:	83 fb 32             	cmp    $0x32,%ebx
c002c4ca:	7f 1b                	jg     c002c4e7 <test_mlfqs_load_1+0x117>
        break;
      else if (elapsed > 45)
c002c4cc:	83 f8 2d             	cmp    $0x2d,%eax
c002c4cf:	90                   	nop
c002c4d0:	0f 8e 53 ff ff ff    	jle    c002c429 <test_mlfqs_load_1+0x59>
        fail ("load average stayed below 0.5 for more than 45 seconds");
c002c4d6:	c7 04 24 88 0e 03 c0 	movl   $0xc0030e88,(%esp)
c002c4dd:	e8 13 e3 ff ff       	call   c002a7f5 <fail>
c002c4e2:	e9 42 ff ff ff       	jmp    c002c429 <test_mlfqs_load_1+0x59>
    }

  if (elapsed < 38)
c002c4e7:	83 f8 25             	cmp    $0x25,%eax
c002c4ea:	7f 10                	jg     c002c4fc <test_mlfqs_load_1+0x12c>
    fail ("load average took only %d seconds to rise above 0.5", elapsed);
c002c4ec:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c4f0:	c7 04 24 c0 0e 03 c0 	movl   $0xc0030ec0,(%esp)
c002c4f7:	e8 f9 e2 ff ff       	call   c002a7f5 <fail>
  msg ("load average rose to 0.5 after %d seconds", elapsed);
c002c4fc:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c500:	c7 04 24 f4 0e 03 c0 	movl   $0xc0030ef4,(%esp)
c002c507:	e8 31 e2 ff ff       	call   c002a73d <msg>

  msg ("sleeping for another 10 seconds, please wait...");
c002c50c:	c7 04 24 20 0f 03 c0 	movl   $0xc0030f20,(%esp)
c002c513:	e8 25 e2 ff ff       	call   c002a73d <msg>
  timer_sleep (TIMER_FREQ * 10);
c002c518:	c7 04 24 e8 03 00 00 	movl   $0x3e8,(%esp)
c002c51f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002c526:	00 
c002c527:	e8 2c 7d ff ff       	call   c0024258 <timer_sleep>

  load_avg = thread_get_load_avg ();
c002c52c:	e8 27 4a ff ff       	call   c0020f58 <thread_get_load_avg>
c002c531:	89 c3                	mov    %eax,%ebx
  if (load_avg < 0)
c002c533:	85 c0                	test   %eax,%eax
c002c535:	79 0c                	jns    c002c543 <test_mlfqs_load_1+0x173>
    fail ("load average fell below 0");
c002c537:	c7 04 24 cc 0d 03 c0 	movl   $0xc0030dcc,(%esp)
c002c53e:	e8 b2 e2 ff ff       	call   c002a7f5 <fail>
  if (load_avg > 50)
c002c543:	83 fb 32             	cmp    $0x32,%ebx
c002c546:	7e 0c                	jle    c002c554 <test_mlfqs_load_1+0x184>
    fail ("load average stayed above 0.5 for more than 10 seconds");
c002c548:	c7 04 24 50 0f 03 c0 	movl   $0xc0030f50,(%esp)
c002c54f:	e8 a1 e2 ff ff       	call   c002a7f5 <fail>
  msg ("load average fell back below 0.5 (to %d.%02d)",
c002c554:	ba 1f 85 eb 51       	mov    $0x51eb851f,%edx
c002c559:	89 d8                	mov    %ebx,%eax
c002c55b:	f7 ea                	imul   %edx
c002c55d:	c1 fa 05             	sar    $0x5,%edx
c002c560:	89 d8                	mov    %ebx,%eax
c002c562:	c1 f8 1f             	sar    $0x1f,%eax
c002c565:	29 c2                	sub    %eax,%edx
c002c567:	6b c2 64             	imul   $0x64,%edx,%eax
c002c56a:	29 c3                	sub    %eax,%ebx
c002c56c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c570:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c574:	c7 04 24 88 0f 03 c0 	movl   $0xc0030f88,(%esp)
c002c57b:	e8 bd e1 ff ff       	call   c002a73d <msg>
       load_avg / 100, load_avg % 100);

  pass ();
c002c580:	e8 cc e2 ff ff       	call   c002a851 <pass>
}
c002c585:	83 c4 20             	add    $0x20,%esp
c002c588:	5b                   	pop    %ebx
c002c589:	5e                   	pop    %esi
c002c58a:	5f                   	pop    %edi
c002c58b:	c3                   	ret    
c002c58c:	90                   	nop
c002c58d:	90                   	nop
c002c58e:	90                   	nop
c002c58f:	90                   	nop

c002c590 <load_thread>:
    }
}

static void
load_thread (void *aux UNUSED) 
{
c002c590:	53                   	push   %ebx
c002c591:	83 ec 18             	sub    $0x18,%esp
  int64_t sleep_time = 10 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 60 * TIMER_FREQ;
  int64_t exit_time = spin_time + 60 * TIMER_FREQ;

  thread_set_nice (20);
c002c594:	c7 04 24 14 00 00 00 	movl   $0x14,(%esp)
c002c59b:	e8 ad 51 ff ff       	call   c002174d <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c5a0:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5a5:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5ab:	89 04 24             	mov    %eax,(%esp)
c002c5ae:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5b2:	e8 85 7c ff ff       	call   c002423c <timer_elapsed>
c002c5b7:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002c5bc:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c5c1:	29 c1                	sub    %eax,%ecx
c002c5c3:	19 d3                	sbb    %edx,%ebx
c002c5c5:	89 0c 24             	mov    %ecx,(%esp)
c002c5c8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c5cc:	e8 87 7c ff ff       	call   c0024258 <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c5d1:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5d6:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5dc:	89 04 24             	mov    %eax,(%esp)
c002c5df:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5e3:	e8 54 7c ff ff       	call   c002423c <timer_elapsed>
c002c5e8:	85 d2                	test   %edx,%edx
c002c5ea:	7f 0b                	jg     c002c5f7 <load_thread+0x67>
c002c5ec:	85 d2                	test   %edx,%edx
c002c5ee:	78 e1                	js     c002c5d1 <load_thread+0x41>
c002c5f0:	3d 57 1b 00 00       	cmp    $0x1b57,%eax
c002c5f5:	76 da                	jbe    c002c5d1 <load_thread+0x41>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c5f7:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5fc:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c602:	89 04 24             	mov    %eax,(%esp)
c002c605:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c609:	e8 2e 7c ff ff       	call   c002423c <timer_elapsed>
c002c60e:	b9 c8 32 00 00       	mov    $0x32c8,%ecx
c002c613:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c618:	29 c1                	sub    %eax,%ecx
c002c61a:	19 d3                	sbb    %edx,%ebx
c002c61c:	89 0c 24             	mov    %ecx,(%esp)
c002c61f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c623:	e8 30 7c ff ff       	call   c0024258 <timer_sleep>
}
c002c628:	83 c4 18             	add    $0x18,%esp
c002c62b:	5b                   	pop    %ebx
c002c62c:	c3                   	ret    

c002c62d <test_mlfqs_load_60>:
{
c002c62d:	55                   	push   %ebp
c002c62e:	57                   	push   %edi
c002c62f:	56                   	push   %esi
c002c630:	53                   	push   %ebx
c002c631:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c634:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c63b:	75 2c                	jne    c002c669 <test_mlfqs_load_60+0x3c>
c002c63d:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002c644:	c0 
c002c645:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c64c:	c0 
c002c64d:	c7 44 24 08 9d e0 02 	movl   $0xc002e09d,0x8(%esp)
c002c654:	c0 
c002c655:	c7 44 24 04 77 00 00 	movl   $0x77,0x4(%esp)
c002c65c:	00 
c002c65d:	c7 04 24 c0 0f 03 c0 	movl   $0xc0030fc0,(%esp)
c002c664:	e8 1a c3 ff ff       	call   c0028983 <debug_panic>
  start_time = timer_ticks ();
c002c669:	e8 a2 7b ff ff       	call   c0024210 <timer_ticks>
c002c66e:	a3 a8 7b 03 c0       	mov    %eax,0xc0037ba8
c002c673:	89 15 ac 7b 03 c0    	mov    %edx,0xc0037bac
  msg ("Starting %d niced load threads...", THREAD_CNT);
c002c679:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c680:	00 
c002c681:	c7 04 24 e4 0f 03 c0 	movl   $0xc0030fe4,(%esp)
c002c688:	e8 b0 e0 ff ff       	call   c002a73d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c68d:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c692:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c696:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c69a:	c7 44 24 08 b6 0f 03 	movl   $0xc0030fb6,0x8(%esp)
c002c6a1:	c0 
c002c6a2:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c6a9:	00 
c002c6aa:	89 34 24             	mov    %esi,(%esp)
c002c6ad:	e8 7d ab ff ff       	call   c002722f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, NULL);
c002c6b2:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c6b9:	00 
c002c6ba:	c7 44 24 08 90 c5 02 	movl   $0xc002c590,0x8(%esp)
c002c6c1:	c0 
c002c6c2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c6c9:	00 
c002c6ca:	89 34 24             	mov    %esi,(%esp)
c002c6cd:	e8 55 4e ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c6d2:	83 c3 01             	add    $0x1,%ebx
c002c6d5:	83 fb 3c             	cmp    $0x3c,%ebx
c002c6d8:	75 bc                	jne    c002c696 <test_mlfqs_load_60+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c6da:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c6df:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c6e5:	89 04 24             	mov    %eax,(%esp)
c002c6e8:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c6ec:	e8 4b 7b ff ff       	call   c002423c <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c6f1:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c6f8:	00 
c002c6f9:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c700:	00 
c002c701:	89 04 24             	mov    %eax,(%esp)
c002c704:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c708:	e8 d6 bb ff ff       	call   c00282e3 <__divdi3>
c002c70d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c711:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c715:	c7 04 24 08 10 03 c0 	movl   $0xc0031008,(%esp)
c002c71c:	e8 1c e0 ff ff       	call   c002a73d <msg>
c002c721:	b3 00                	mov    $0x0,%bl
c002c723:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c728:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c72d:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c732:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c736:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c73a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c73e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c742:	03 05 a8 7b 03 c0    	add    0xc0037ba8,%eax
c002c748:	13 15 ac 7b 03 c0    	adc    0xc0037bac,%edx
c002c74e:	89 c6                	mov    %eax,%esi
c002c750:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c752:	e8 b9 7a ff ff       	call   c0024210 <timer_ticks>
c002c757:	29 c6                	sub    %eax,%esi
c002c759:	19 d7                	sbb    %edx,%edi
c002c75b:	89 34 24             	mov    %esi,(%esp)
c002c75e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c762:	e8 f1 7a ff ff       	call   c0024258 <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c767:	e8 ec 47 ff ff       	call   c0020f58 <thread_get_load_avg>
c002c76c:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c76e:	f7 ed                	imul   %ebp
c002c770:	c1 fa 05             	sar    $0x5,%edx
c002c773:	89 c8                	mov    %ecx,%eax
c002c775:	c1 f8 1f             	sar    $0x1f,%eax
c002c778:	29 c2                	sub    %eax,%edx
c002c77a:	6b c2 64             	imul   $0x64,%edx,%eax
c002c77d:	29 c1                	sub    %eax,%ecx
c002c77f:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c783:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c787:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c78b:	c7 04 24 2c 10 03 c0 	movl   $0xc003102c,(%esp)
c002c792:	e8 a6 df ff ff       	call   c002a73d <msg>
c002c797:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c79e:	00 
c002c79f:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c7a4:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c7a7:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c7ad:	75 8b                	jne    c002c73a <test_mlfqs_load_60+0x10d>
}
c002c7af:	83 c4 3c             	add    $0x3c,%esp
c002c7b2:	5b                   	pop    %ebx
c002c7b3:	5e                   	pop    %esi
c002c7b4:	5f                   	pop    %edi
c002c7b5:	5d                   	pop    %ebp
c002c7b6:	c3                   	ret    
c002c7b7:	90                   	nop
c002c7b8:	90                   	nop
c002c7b9:	90                   	nop
c002c7ba:	90                   	nop
c002c7bb:	90                   	nop
c002c7bc:	90                   	nop
c002c7bd:	90                   	nop
c002c7be:	90                   	nop
c002c7bf:	90                   	nop

c002c7c0 <load_thread>:
    }
}

static void
load_thread (void *seq_no_) 
{
c002c7c0:	57                   	push   %edi
c002c7c1:	56                   	push   %esi
c002c7c2:	53                   	push   %ebx
c002c7c3:	83 ec 10             	sub    $0x10,%esp
  int seq_no = (int) seq_no_;
  int sleep_time = TIMER_FREQ * (10 + seq_no);
c002c7c6:	8b 44 24 20          	mov    0x20(%esp),%eax
c002c7ca:	8d 70 0a             	lea    0xa(%eax),%esi
c002c7cd:	6b f6 64             	imul   $0x64,%esi,%esi
  int spin_time = sleep_time + TIMER_FREQ * THREAD_CNT;
c002c7d0:	8d 9e 70 17 00 00    	lea    0x1770(%esi),%ebx
  int exit_time = TIMER_FREQ * (THREAD_CNT * 2);

  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c7d6:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c7db:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c7e1:	89 04 24             	mov    %eax,(%esp)
c002c7e4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c7e8:	e8 4f 7a ff ff       	call   c002423c <timer_elapsed>
c002c7ed:	89 f7                	mov    %esi,%edi
c002c7ef:	c1 ff 1f             	sar    $0x1f,%edi
c002c7f2:	29 c6                	sub    %eax,%esi
c002c7f4:	19 d7                	sbb    %edx,%edi
c002c7f6:	89 34 24             	mov    %esi,(%esp)
c002c7f9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c7fd:	e8 56 7a ff ff       	call   c0024258 <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c802:	89 df                	mov    %ebx,%edi
c002c804:	c1 ff 1f             	sar    $0x1f,%edi
c002c807:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c80c:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c812:	89 04 24             	mov    %eax,(%esp)
c002c815:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c819:	e8 1e 7a ff ff       	call   c002423c <timer_elapsed>
c002c81e:	39 fa                	cmp    %edi,%edx
c002c820:	7f 06                	jg     c002c828 <load_thread+0x68>
c002c822:	7c e3                	jl     c002c807 <load_thread+0x47>
c002c824:	39 d8                	cmp    %ebx,%eax
c002c826:	72 df                	jb     c002c807 <load_thread+0x47>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c828:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c82d:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c833:	89 04 24             	mov    %eax,(%esp)
c002c836:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c83a:	e8 fd 79 ff ff       	call   c002423c <timer_elapsed>
c002c83f:	b9 e0 2e 00 00       	mov    $0x2ee0,%ecx
c002c844:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c849:	29 c1                	sub    %eax,%ecx
c002c84b:	19 d3                	sbb    %edx,%ebx
c002c84d:	89 0c 24             	mov    %ecx,(%esp)
c002c850:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c854:	e8 ff 79 ff ff       	call   c0024258 <timer_sleep>
}
c002c859:	83 c4 10             	add    $0x10,%esp
c002c85c:	5b                   	pop    %ebx
c002c85d:	5e                   	pop    %esi
c002c85e:	5f                   	pop    %edi
c002c85f:	c3                   	ret    

c002c860 <test_mlfqs_load_avg>:
{
c002c860:	55                   	push   %ebp
c002c861:	57                   	push   %edi
c002c862:	56                   	push   %esi
c002c863:	53                   	push   %ebx
c002c864:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c867:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c86e:	75 2c                	jne    c002c89c <test_mlfqs_load_avg+0x3c>
c002c870:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002c877:	c0 
c002c878:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c87f:	c0 
c002c880:	c7 44 24 08 b0 e0 02 	movl   $0xc002e0b0,0x8(%esp)
c002c887:	c0 
c002c888:	c7 44 24 04 82 00 00 	movl   $0x82,0x4(%esp)
c002c88f:	00 
c002c890:	c7 04 24 70 10 03 c0 	movl   $0xc0031070,(%esp)
c002c897:	e8 e7 c0 ff ff       	call   c0028983 <debug_panic>
  start_time = timer_ticks ();
c002c89c:	e8 6f 79 ff ff       	call   c0024210 <timer_ticks>
c002c8a1:	a3 b0 7b 03 c0       	mov    %eax,0xc0037bb0
c002c8a6:	89 15 b4 7b 03 c0    	mov    %edx,0xc0037bb4
  msg ("Starting %d load threads...", THREAD_CNT);
c002c8ac:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c8b3:	00 
c002c8b4:	c7 04 24 54 10 03 c0 	movl   $0xc0031054,(%esp)
c002c8bb:	e8 7d de ff ff       	call   c002a73d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c8c0:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c8c5:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c8c9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c8cd:	c7 44 24 08 b6 0f 03 	movl   $0xc0030fb6,0x8(%esp)
c002c8d4:	c0 
c002c8d5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c8dc:	00 
c002c8dd:	89 34 24             	mov    %esi,(%esp)
c002c8e0:	e8 4a a9 ff ff       	call   c002722f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, (void *) i);
c002c8e5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c8e9:	c7 44 24 08 c0 c7 02 	movl   $0xc002c7c0,0x8(%esp)
c002c8f0:	c0 
c002c8f1:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c8f8:	00 
c002c8f9:	89 34 24             	mov    %esi,(%esp)
c002c8fc:	e8 26 4c ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c901:	83 c3 01             	add    $0x1,%ebx
c002c904:	83 fb 3c             	cmp    $0x3c,%ebx
c002c907:	75 c0                	jne    c002c8c9 <test_mlfqs_load_avg+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c909:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c90e:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c914:	89 04 24             	mov    %eax,(%esp)
c002c917:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c91b:	e8 1c 79 ff ff       	call   c002423c <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c920:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c927:	00 
c002c928:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c92f:	00 
c002c930:	89 04 24             	mov    %eax,(%esp)
c002c933:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c937:	e8 a7 b9 ff ff       	call   c00282e3 <__divdi3>
c002c93c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c940:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c944:	c7 04 24 08 10 03 c0 	movl   $0xc0031008,(%esp)
c002c94b:	e8 ed dd ff ff       	call   c002a73d <msg>
  thread_set_nice (-20);
c002c950:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002c957:	e8 f1 4d ff ff       	call   c002174d <thread_set_nice>
c002c95c:	b3 00                	mov    $0x0,%bl
c002c95e:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c963:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c968:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c96d:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c971:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c975:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c979:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c97d:	03 05 b0 7b 03 c0    	add    0xc0037bb0,%eax
c002c983:	13 15 b4 7b 03 c0    	adc    0xc0037bb4,%edx
c002c989:	89 c6                	mov    %eax,%esi
c002c98b:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c98d:	e8 7e 78 ff ff       	call   c0024210 <timer_ticks>
c002c992:	29 c6                	sub    %eax,%esi
c002c994:	19 d7                	sbb    %edx,%edi
c002c996:	89 34 24             	mov    %esi,(%esp)
c002c999:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c99d:	e8 b6 78 ff ff       	call   c0024258 <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c9a2:	e8 b1 45 ff ff       	call   c0020f58 <thread_get_load_avg>
c002c9a7:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c9a9:	f7 ed                	imul   %ebp
c002c9ab:	c1 fa 05             	sar    $0x5,%edx
c002c9ae:	89 c8                	mov    %ecx,%eax
c002c9b0:	c1 f8 1f             	sar    $0x1f,%eax
c002c9b3:	29 c2                	sub    %eax,%edx
c002c9b5:	6b c2 64             	imul   $0x64,%edx,%eax
c002c9b8:	29 c1                	sub    %eax,%ecx
c002c9ba:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c9be:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c9c2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c9c6:	c7 04 24 2c 10 03 c0 	movl   $0xc003102c,(%esp)
c002c9cd:	e8 6b dd ff ff       	call   c002a73d <msg>
c002c9d2:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c9d9:	00 
c002c9da:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c9df:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c9e2:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c9e8:	75 8b                	jne    c002c975 <test_mlfqs_load_avg+0x115>
}
c002c9ea:	83 c4 3c             	add    $0x3c,%esp
c002c9ed:	5b                   	pop    %ebx
c002c9ee:	5e                   	pop    %esi
c002c9ef:	5f                   	pop    %edi
c002c9f0:	5d                   	pop    %ebp
c002c9f1:	c3                   	ret    

c002c9f2 <test_mlfqs_recent_1>:
/* Sensitive to assumption that recent_cpu updates happen exactly
   when timer_ticks() % TIMER_FREQ == 0. */

void
test_mlfqs_recent_1 (void) 
{
c002c9f2:	55                   	push   %ebp
c002c9f3:	57                   	push   %edi
c002c9f4:	56                   	push   %esi
c002c9f5:	53                   	push   %ebx
c002c9f6:	83 ec 2c             	sub    $0x2c,%esp
  int64_t start_time;
  int last_elapsed = 0;
  
  ASSERT (thread_mlfqs);
c002c9f9:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002ca00:	75 2c                	jne    c002ca2e <test_mlfqs_recent_1+0x3c>
c002ca02:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002ca09:	c0 
c002ca0a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ca11:	c0 
c002ca12:	c7 44 24 08 c4 e0 02 	movl   $0xc002e0c4,0x8(%esp)
c002ca19:	c0 
c002ca1a:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c002ca21:	00 
c002ca22:	c7 04 24 98 10 03 c0 	movl   $0xc0031098,(%esp)
c002ca29:	e8 55 bf ff ff       	call   c0028983 <debug_panic>

  do 
    {
      msg ("Sleeping 10 seconds to allow recent_cpu to decay, please wait...");
c002ca2e:	c7 04 24 c0 10 03 c0 	movl   $0xc00310c0,(%esp)
c002ca35:	e8 03 dd ff ff       	call   c002a73d <msg>
      start_time = timer_ticks ();
c002ca3a:	e8 d1 77 ff ff       	call   c0024210 <timer_ticks>
c002ca3f:	89 c7                	mov    %eax,%edi
c002ca41:	89 d5                	mov    %edx,%ebp
      timer_sleep (DIV_ROUND_UP (start_time, TIMER_FREQ) - start_time
c002ca43:	83 c0 63             	add    $0x63,%eax
c002ca46:	83 d2 00             	adc    $0x0,%edx
c002ca49:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002ca50:	00 
c002ca51:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002ca58:	00 
c002ca59:	89 04 24             	mov    %eax,(%esp)
c002ca5c:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca60:	e8 7e b8 ff ff       	call   c00282e3 <__divdi3>
c002ca65:	29 f8                	sub    %edi,%eax
c002ca67:	19 ea                	sbb    %ebp,%edx
c002ca69:	05 e8 03 00 00       	add    $0x3e8,%eax
c002ca6e:	83 d2 00             	adc    $0x0,%edx
c002ca71:	89 04 24             	mov    %eax,(%esp)
c002ca74:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca78:	e8 db 77 ff ff       	call   c0024258 <timer_sleep>
                   + 10 * TIMER_FREQ);
    }
  while (thread_get_recent_cpu () > 700);
c002ca7d:	e8 ec 44 ff ff       	call   c0020f6e <thread_get_recent_cpu>
c002ca82:	3d bc 02 00 00       	cmp    $0x2bc,%eax
c002ca87:	7f a5                	jg     c002ca2e <test_mlfqs_recent_1+0x3c>

  start_time = timer_ticks ();
c002ca89:	e8 82 77 ff ff       	call   c0024210 <timer_ticks>
c002ca8e:	89 44 24 18          	mov    %eax,0x18(%esp)
c002ca92:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  int last_elapsed = 0;
c002ca96:	be 00 00 00 00       	mov    $0x0,%esi
  for (;;) 
    {
      int elapsed = timer_elapsed (start_time);
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002ca9b:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002caa0:	eb 02                	jmp    c002caa4 <test_mlfqs_recent_1+0xb2>
c002caa2:	89 de                	mov    %ebx,%esi
      int elapsed = timer_elapsed (start_time);
c002caa4:	8b 44 24 18          	mov    0x18(%esp),%eax
c002caa8:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002caac:	89 04 24             	mov    %eax,(%esp)
c002caaf:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cab3:	e8 84 77 ff ff       	call   c002423c <timer_elapsed>
c002cab8:	89 c3                	mov    %eax,%ebx
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002caba:	f7 ed                	imul   %ebp
c002cabc:	c1 fa 06             	sar    $0x6,%edx
c002cabf:	89 d8                	mov    %ebx,%eax
c002cac1:	c1 f8 1f             	sar    $0x1f,%eax
c002cac4:	29 c2                	sub    %eax,%edx
c002cac6:	69 d2 c8 00 00 00    	imul   $0xc8,%edx,%edx
c002cacc:	39 d3                	cmp    %edx,%ebx
c002cace:	75 d2                	jne    c002caa2 <test_mlfqs_recent_1+0xb0>
c002cad0:	39 de                	cmp    %ebx,%esi
c002cad2:	7d ce                	jge    c002caa2 <test_mlfqs_recent_1+0xb0>
        {
          int recent_cpu = thread_get_recent_cpu ();
c002cad4:	e8 95 44 ff ff       	call   c0020f6e <thread_get_recent_cpu>
c002cad9:	89 c6                	mov    %eax,%esi
          int load_avg = thread_get_load_avg ();
c002cadb:	e8 78 44 ff ff       	call   c0020f58 <thread_get_load_avg>
c002cae0:	89 c1                	mov    %eax,%ecx
          int elapsed_seconds = elapsed / TIMER_FREQ;
c002cae2:	89 d8                	mov    %ebx,%eax
c002cae4:	f7 ed                	imul   %ebp
c002cae6:	89 d7                	mov    %edx,%edi
c002cae8:	c1 ff 05             	sar    $0x5,%edi
c002caeb:	89 d8                	mov    %ebx,%eax
c002caed:	c1 f8 1f             	sar    $0x1f,%eax
c002caf0:	29 c7                	sub    %eax,%edi
          msg ("After %d seconds, recent_cpu is %d.%02d, load_avg is %d.%02d.",
c002caf2:	89 c8                	mov    %ecx,%eax
c002caf4:	f7 ed                	imul   %ebp
c002caf6:	c1 fa 05             	sar    $0x5,%edx
c002caf9:	89 c8                	mov    %ecx,%eax
c002cafb:	c1 f8 1f             	sar    $0x1f,%eax
c002cafe:	29 c2                	sub    %eax,%edx
c002cb00:	6b c2 64             	imul   $0x64,%edx,%eax
c002cb03:	29 c1                	sub    %eax,%ecx
c002cb05:	89 4c 24 14          	mov    %ecx,0x14(%esp)
c002cb09:	89 54 24 10          	mov    %edx,0x10(%esp)
c002cb0d:	89 f0                	mov    %esi,%eax
c002cb0f:	f7 ed                	imul   %ebp
c002cb11:	c1 fa 05             	sar    $0x5,%edx
c002cb14:	89 f0                	mov    %esi,%eax
c002cb16:	c1 f8 1f             	sar    $0x1f,%eax
c002cb19:	29 c2                	sub    %eax,%edx
c002cb1b:	6b c2 64             	imul   $0x64,%edx,%eax
c002cb1e:	29 c6                	sub    %eax,%esi
c002cb20:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002cb24:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cb28:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002cb2c:	c7 04 24 04 11 03 c0 	movl   $0xc0031104,(%esp)
c002cb33:	e8 05 dc ff ff       	call   c002a73d <msg>
               elapsed_seconds,
               recent_cpu / 100, recent_cpu % 100,
               load_avg / 100, load_avg % 100);
          if (elapsed_seconds >= 180)
c002cb38:	81 ff b3 00 00 00    	cmp    $0xb3,%edi
c002cb3e:	0f 8e 5e ff ff ff    	jle    c002caa2 <test_mlfqs_recent_1+0xb0>
            break;
        } 
      last_elapsed = elapsed;
    }
}
c002cb44:	83 c4 2c             	add    $0x2c,%esp
c002cb47:	5b                   	pop    %ebx
c002cb48:	5e                   	pop    %esi
c002cb49:	5f                   	pop    %edi
c002cb4a:	5d                   	pop    %ebp
c002cb4b:	c3                   	ret    
c002cb4c:	90                   	nop
c002cb4d:	90                   	nop
c002cb4e:	90                   	nop
c002cb4f:	90                   	nop

c002cb50 <test_mlfqs_fair>:

static void load_thread (void *aux);

static void
test_mlfqs_fair (int thread_cnt, int nice_min, int nice_step)
{
c002cb50:	55                   	push   %ebp
c002cb51:	57                   	push   %edi
c002cb52:	56                   	push   %esi
c002cb53:	53                   	push   %ebx
c002cb54:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
c002cb5a:	89 4c 24 14          	mov    %ecx,0x14(%esp)
  struct thread_info info[MAX_THREAD_CNT];
  int64_t start_time;
  int nice;
  int i;

  ASSERT (thread_mlfqs);
c002cb5e:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002cb65:	75 2c                	jne    c002cb93 <test_mlfqs_fair+0x43>
c002cb67:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002cb6e:	c0 
c002cb6f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cb76:	c0 
c002cb77:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cb7e:	c0 
c002cb7f:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
c002cb86:	00 
c002cb87:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cb8e:	e8 f0 bd ff ff       	call   c0028983 <debug_panic>
c002cb93:	89 c5                	mov    %eax,%ebp
c002cb95:	89 d7                	mov    %edx,%edi
  ASSERT (thread_cnt <= MAX_THREAD_CNT);
c002cb97:	83 f8 14             	cmp    $0x14,%eax
c002cb9a:	7e 2c                	jle    c002cbc8 <test_mlfqs_fair+0x78>
c002cb9c:	c7 44 24 10 42 11 03 	movl   $0xc0031142,0x10(%esp)
c002cba3:	c0 
c002cba4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cbab:	c0 
c002cbac:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cbb3:	c0 
c002cbb4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c002cbbb:	00 
c002cbbc:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cbc3:	e8 bb bd ff ff       	call   c0028983 <debug_panic>
  ASSERT (nice_min >= -10);
c002cbc8:	83 fa f6             	cmp    $0xfffffff6,%edx
c002cbcb:	7d 2c                	jge    c002cbf9 <test_mlfqs_fair+0xa9>
c002cbcd:	c7 44 24 10 5f 11 03 	movl   $0xc003115f,0x10(%esp)
c002cbd4:	c0 
c002cbd5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cbdc:	c0 
c002cbdd:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cbe4:	c0 
c002cbe5:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002cbec:	00 
c002cbed:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cbf4:	e8 8a bd ff ff       	call   c0028983 <debug_panic>
  ASSERT (nice_step >= 0);
c002cbf9:	83 7c 24 14 00       	cmpl   $0x0,0x14(%esp)
c002cbfe:	79 2c                	jns    c002cc2c <test_mlfqs_fair+0xdc>
c002cc00:	c7 44 24 10 6f 11 03 	movl   $0xc003116f,0x10(%esp)
c002cc07:	c0 
c002cc08:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cc0f:	c0 
c002cc10:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cc17:	c0 
c002cc18:	c7 44 24 04 4c 00 00 	movl   $0x4c,0x4(%esp)
c002cc1f:	00 
c002cc20:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cc27:	e8 57 bd ff ff       	call   c0028983 <debug_panic>
  ASSERT (nice_min + nice_step * (thread_cnt - 1) <= 20);
c002cc2c:	8d 40 ff             	lea    -0x1(%eax),%eax
c002cc2f:	0f af 44 24 14       	imul   0x14(%esp),%eax
c002cc34:	01 d0                	add    %edx,%eax
c002cc36:	83 f8 14             	cmp    $0x14,%eax
c002cc39:	7e 2c                	jle    c002cc67 <test_mlfqs_fair+0x117>
c002cc3b:	c7 44 24 10 d8 11 03 	movl   $0xc00311d8,0x10(%esp)
c002cc42:	c0 
c002cc43:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cc4a:	c0 
c002cc4b:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cc52:	c0 
c002cc53:	c7 44 24 04 4d 00 00 	movl   $0x4d,0x4(%esp)
c002cc5a:	00 
c002cc5b:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cc62:	e8 1c bd ff ff       	call   c0028983 <debug_panic>

  thread_set_nice (-20);
c002cc67:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002cc6e:	e8 da 4a ff ff       	call   c002174d <thread_set_nice>

  start_time = timer_ticks ();
c002cc73:	e8 98 75 ff ff       	call   c0024210 <timer_ticks>
c002cc78:	89 44 24 18          	mov    %eax,0x18(%esp)
c002cc7c:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  msg ("Starting %d threads...", thread_cnt);
c002cc80:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002cc84:	c7 04 24 7e 11 03 c0 	movl   $0xc003117e,(%esp)
c002cc8b:	e8 ad da ff ff       	call   c002a73d <msg>
  nice = nice_min;
  for (i = 0; i < thread_cnt; i++) 
c002cc90:	85 ed                	test   %ebp,%ebp
c002cc92:	0f 8e e1 00 00 00    	jle    c002cd79 <test_mlfqs_fair+0x229>
c002cc98:	8d 5c 24 30          	lea    0x30(%esp),%ebx
c002cc9c:	be 00 00 00 00       	mov    $0x0,%esi
    {
      struct thread_info *ti = &info[i];
      char name[16];

      ti->start_time = start_time;
c002cca1:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cca5:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cca9:	89 03                	mov    %eax,(%ebx)
c002ccab:	89 53 04             	mov    %edx,0x4(%ebx)
      ti->tick_count = 0;
c002ccae:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
      ti->nice = nice;
c002ccb5:	89 7b 0c             	mov    %edi,0xc(%ebx)

      snprintf(name, sizeof name, "load %d", i);
c002ccb8:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ccbc:	c7 44 24 08 b6 0f 03 	movl   $0xc0030fb6,0x8(%esp)
c002ccc3:	c0 
c002ccc4:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002cccb:	00 
c002cccc:	8d 44 24 20          	lea    0x20(%esp),%eax
c002ccd0:	89 04 24             	mov    %eax,(%esp)
c002ccd3:	e8 57 a5 ff ff       	call   c002722f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, ti);
c002ccd8:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002ccdc:	c7 44 24 08 cc cd 02 	movl   $0xc002cdcc,0x8(%esp)
c002cce3:	c0 
c002cce4:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cceb:	00 
c002ccec:	8d 44 24 20          	lea    0x20(%esp),%eax
c002ccf0:	89 04 24             	mov    %eax,(%esp)
c002ccf3:	e8 2f 48 ff ff       	call   c0021527 <thread_create>

      nice += nice_step;
c002ccf8:	03 7c 24 14          	add    0x14(%esp),%edi
  for (i = 0; i < thread_cnt; i++) 
c002ccfc:	83 c6 01             	add    $0x1,%esi
c002ccff:	83 c3 10             	add    $0x10,%ebx
c002cd02:	39 ee                	cmp    %ebp,%esi
c002cd04:	75 9b                	jne    c002cca1 <test_mlfqs_fair+0x151>
    }
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cd06:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cd0a:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cd0e:	89 04 24             	mov    %eax,(%esp)
c002cd11:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cd15:	e8 22 75 ff ff       	call   c002423c <timer_elapsed>
c002cd1a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cd1e:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd22:	c7 04 24 08 12 03 c0 	movl   $0xc0031208,(%esp)
c002cd29:	e8 0f da ff ff       	call   c002a73d <msg>

  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cd2e:	c7 04 24 2c 12 03 c0 	movl   $0xc003122c,(%esp)
c002cd35:	e8 03 da ff ff       	call   c002a73d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cd3a:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cd41:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cd48:	00 
c002cd49:	e8 0a 75 ff ff       	call   c0024258 <timer_sleep>
  
  for (i = 0; i < thread_cnt; i++)
c002cd4e:	bb 00 00 00 00       	mov    $0x0,%ebx
c002cd53:	89 d8                	mov    %ebx,%eax
c002cd55:	c1 e0 04             	shl    $0x4,%eax
    msg ("Thread %d received %d ticks.", i, info[i].tick_count);
c002cd58:	8b 44 04 38          	mov    0x38(%esp,%eax,1),%eax
c002cd5c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002cd60:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002cd64:	c7 04 24 95 11 03 c0 	movl   $0xc0031195,(%esp)
c002cd6b:	e8 cd d9 ff ff       	call   c002a73d <msg>
  for (i = 0; i < thread_cnt; i++)
c002cd70:	83 c3 01             	add    $0x1,%ebx
c002cd73:	39 eb                	cmp    %ebp,%ebx
c002cd75:	75 dc                	jne    c002cd53 <test_mlfqs_fair+0x203>
c002cd77:	eb 48                	jmp    c002cdc1 <test_mlfqs_fair+0x271>
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cd79:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cd7d:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cd81:	89 04 24             	mov    %eax,(%esp)
c002cd84:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cd88:	e8 af 74 ff ff       	call   c002423c <timer_elapsed>
c002cd8d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cd91:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd95:	c7 04 24 08 12 03 c0 	movl   $0xc0031208,(%esp)
c002cd9c:	e8 9c d9 ff ff       	call   c002a73d <msg>
  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cda1:	c7 04 24 2c 12 03 c0 	movl   $0xc003122c,(%esp)
c002cda8:	e8 90 d9 ff ff       	call   c002a73d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cdad:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cdb4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cdbb:	00 
c002cdbc:	e8 97 74 ff ff       	call   c0024258 <timer_sleep>
}
c002cdc1:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002cdc7:	5b                   	pop    %ebx
c002cdc8:	5e                   	pop    %esi
c002cdc9:	5f                   	pop    %edi
c002cdca:	5d                   	pop    %ebp
c002cdcb:	c3                   	ret    

c002cdcc <load_thread>:

static void
load_thread (void *ti_) 
{
c002cdcc:	57                   	push   %edi
c002cdcd:	56                   	push   %esi
c002cdce:	53                   	push   %ebx
c002cdcf:	83 ec 10             	sub    $0x10,%esp
c002cdd2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread_info *ti = ti_;
  int64_t sleep_time = 5 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 30 * TIMER_FREQ;
  int64_t last_time = 0;

  thread_set_nice (ti->nice);
c002cdd6:	8b 43 0c             	mov    0xc(%ebx),%eax
c002cdd9:	89 04 24             	mov    %eax,(%esp)
c002cddc:	e8 6c 49 ff ff       	call   c002174d <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (ti->start_time));
c002cde1:	8b 03                	mov    (%ebx),%eax
c002cde3:	8b 53 04             	mov    0x4(%ebx),%edx
c002cde6:	89 04 24             	mov    %eax,(%esp)
c002cde9:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cded:	e8 4a 74 ff ff       	call   c002423c <timer_elapsed>
c002cdf2:	be f4 01 00 00       	mov    $0x1f4,%esi
c002cdf7:	bf 00 00 00 00       	mov    $0x0,%edi
c002cdfc:	29 c6                	sub    %eax,%esi
c002cdfe:	19 d7                	sbb    %edx,%edi
c002ce00:	89 34 24             	mov    %esi,(%esp)
c002ce03:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ce07:	e8 4c 74 ff ff       	call   c0024258 <timer_sleep>
  int64_t last_time = 0;
c002ce0c:	bf 00 00 00 00       	mov    $0x0,%edi
c002ce11:	be 00 00 00 00       	mov    $0x0,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce16:	eb 15                	jmp    c002ce2d <load_thread+0x61>
    {
      int64_t cur_time = timer_ticks ();
c002ce18:	e8 f3 73 ff ff       	call   c0024210 <timer_ticks>
      if (cur_time != last_time)
c002ce1d:	31 d6                	xor    %edx,%esi
c002ce1f:	31 c7                	xor    %eax,%edi
c002ce21:	09 fe                	or     %edi,%esi
c002ce23:	74 04                	je     c002ce29 <load_thread+0x5d>
        ti->tick_count++;
c002ce25:	83 43 08 01          	addl   $0x1,0x8(%ebx)
{
c002ce29:	89 c7                	mov    %eax,%edi
c002ce2b:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce2d:	8b 03                	mov    (%ebx),%eax
c002ce2f:	8b 53 04             	mov    0x4(%ebx),%edx
c002ce32:	89 04 24             	mov    %eax,(%esp)
c002ce35:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ce39:	e8 fe 73 ff ff       	call   c002423c <timer_elapsed>
c002ce3e:	85 d2                	test   %edx,%edx
c002ce40:	78 d6                	js     c002ce18 <load_thread+0x4c>
c002ce42:	85 d2                	test   %edx,%edx
c002ce44:	7f 07                	jg     c002ce4d <load_thread+0x81>
c002ce46:	3d ab 0d 00 00       	cmp    $0xdab,%eax
c002ce4b:	76 cb                	jbe    c002ce18 <load_thread+0x4c>
      last_time = cur_time;
    }
}
c002ce4d:	83 c4 10             	add    $0x10,%esp
c002ce50:	5b                   	pop    %ebx
c002ce51:	5e                   	pop    %esi
c002ce52:	5f                   	pop    %edi
c002ce53:	c3                   	ret    

c002ce54 <test_mlfqs_fair_2>:
{
c002ce54:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 0);
c002ce57:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce5c:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce61:	b8 02 00 00 00       	mov    $0x2,%eax
c002ce66:	e8 e5 fc ff ff       	call   c002cb50 <test_mlfqs_fair>
}
c002ce6b:	83 c4 0c             	add    $0xc,%esp
c002ce6e:	c3                   	ret    

c002ce6f <test_mlfqs_fair_20>:
{
c002ce6f:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (20, 0, 0);
c002ce72:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce77:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce7c:	b8 14 00 00 00       	mov    $0x14,%eax
c002ce81:	e8 ca fc ff ff       	call   c002cb50 <test_mlfqs_fair>
}
c002ce86:	83 c4 0c             	add    $0xc,%esp
c002ce89:	c3                   	ret    

c002ce8a <test_mlfqs_nice_2>:
{
c002ce8a:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 5);
c002ce8d:	b9 05 00 00 00       	mov    $0x5,%ecx
c002ce92:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce97:	b8 02 00 00 00       	mov    $0x2,%eax
c002ce9c:	e8 af fc ff ff       	call   c002cb50 <test_mlfqs_fair>
}
c002cea1:	83 c4 0c             	add    $0xc,%esp
c002cea4:	c3                   	ret    

c002cea5 <test_mlfqs_nice_10>:
{
c002cea5:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (10, 0, 1);
c002cea8:	b9 01 00 00 00       	mov    $0x1,%ecx
c002cead:	ba 00 00 00 00       	mov    $0x0,%edx
c002ceb2:	b8 0a 00 00 00       	mov    $0xa,%eax
c002ceb7:	e8 94 fc ff ff       	call   c002cb50 <test_mlfqs_fair>
}
c002cebc:	83 c4 0c             	add    $0xc,%esp
c002cebf:	c3                   	ret    

c002cec0 <block_thread>:
  msg ("Block thread should have already acquired lock.");
}

static void
block_thread (void *lock_) 
{
c002cec0:	56                   	push   %esi
c002cec1:	53                   	push   %ebx
c002cec2:	83 ec 14             	sub    $0x14,%esp
  struct lock *lock = lock_;
  int64_t start_time;

  msg ("Block thread spinning for 20 seconds...");
c002cec5:	c7 04 24 64 12 03 c0 	movl   $0xc0031264,(%esp)
c002cecc:	e8 6c d8 ff ff       	call   c002a73d <msg>
  start_time = timer_ticks ();
c002ced1:	e8 3a 73 ff ff       	call   c0024210 <timer_ticks>
c002ced6:	89 c3                	mov    %eax,%ebx
c002ced8:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 20 * TIMER_FREQ)
c002ceda:	89 1c 24             	mov    %ebx,(%esp)
c002cedd:	89 74 24 04          	mov    %esi,0x4(%esp)
c002cee1:	e8 56 73 ff ff       	call   c002423c <timer_elapsed>
c002cee6:	85 d2                	test   %edx,%edx
c002cee8:	7f 0b                	jg     c002cef5 <block_thread+0x35>
c002ceea:	85 d2                	test   %edx,%edx
c002ceec:	78 ec                	js     c002ceda <block_thread+0x1a>
c002ceee:	3d cf 07 00 00       	cmp    $0x7cf,%eax
c002cef3:	76 e5                	jbe    c002ceda <block_thread+0x1a>
    continue;

  msg ("Block thread acquiring lock...");
c002cef5:	c7 04 24 8c 12 03 c0 	movl   $0xc003128c,(%esp)
c002cefc:	e8 3c d8 ff ff       	call   c002a73d <msg>
  lock_acquire (lock);
c002cf01:	8b 44 24 20          	mov    0x20(%esp),%eax
c002cf05:	89 04 24             	mov    %eax,(%esp)
c002cf08:	e8 4d 5f ff ff       	call   c0022e5a <lock_acquire>

  msg ("...got it.");
c002cf0d:	c7 04 24 64 13 03 c0 	movl   $0xc0031364,(%esp)
c002cf14:	e8 24 d8 ff ff       	call   c002a73d <msg>
}
c002cf19:	83 c4 14             	add    $0x14,%esp
c002cf1c:	5b                   	pop    %ebx
c002cf1d:	5e                   	pop    %esi
c002cf1e:	c3                   	ret    

c002cf1f <test_mlfqs_block>:
{
c002cf1f:	56                   	push   %esi
c002cf20:	53                   	push   %ebx
c002cf21:	83 ec 54             	sub    $0x54,%esp
  ASSERT (thread_mlfqs);
c002cf24:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002cf2b:	75 2c                	jne    c002cf59 <test_mlfqs_block+0x3a>
c002cf2d:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002cf34:	c0 
c002cf35:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cf3c:	c0 
c002cf3d:	c7 44 24 08 e8 e0 02 	movl   $0xc002e0e8,0x8(%esp)
c002cf44:	c0 
c002cf45:	c7 44 24 04 1c 00 00 	movl   $0x1c,0x4(%esp)
c002cf4c:	00 
c002cf4d:	c7 04 24 ac 12 03 c0 	movl   $0xc00312ac,(%esp)
c002cf54:	e8 2a ba ff ff       	call   c0028983 <debug_panic>
  msg ("Main thread acquiring lock.");
c002cf59:	c7 04 24 6f 13 03 c0 	movl   $0xc003136f,(%esp)
c002cf60:	e8 d8 d7 ff ff       	call   c002a73d <msg>
  lock_init (&lock);
c002cf65:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002cf69:	89 1c 24             	mov    %ebx,(%esp)
c002cf6c:	e8 4c 5e ff ff       	call   c0022dbd <lock_init>
  lock_acquire (&lock);
c002cf71:	89 1c 24             	mov    %ebx,(%esp)
c002cf74:	e8 e1 5e ff ff       	call   c0022e5a <lock_acquire>
  msg ("Main thread creating block thread, sleeping 25 seconds...");
c002cf79:	c7 04 24 d0 12 03 c0 	movl   $0xc00312d0,(%esp)
c002cf80:	e8 b8 d7 ff ff       	call   c002a73d <msg>
  thread_create ("block", PRI_DEFAULT, block_thread, &lock);
c002cf85:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cf89:	c7 44 24 08 c0 ce 02 	movl   $0xc002cec0,0x8(%esp)
c002cf90:	c0 
c002cf91:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cf98:	00 
c002cf99:	c7 04 24 f6 00 03 c0 	movl   $0xc00300f6,(%esp)
c002cfa0:	e8 82 45 ff ff       	call   c0021527 <thread_create>
  timer_sleep (25 * TIMER_FREQ);
c002cfa5:	c7 04 24 c4 09 00 00 	movl   $0x9c4,(%esp)
c002cfac:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cfb3:	00 
c002cfb4:	e8 9f 72 ff ff       	call   c0024258 <timer_sleep>
  msg ("Main thread spinning for 5 seconds...");
c002cfb9:	c7 04 24 0c 13 03 c0 	movl   $0xc003130c,(%esp)
c002cfc0:	e8 78 d7 ff ff       	call   c002a73d <msg>
  start_time = timer_ticks ();
c002cfc5:	e8 46 72 ff ff       	call   c0024210 <timer_ticks>
c002cfca:	89 c3                	mov    %eax,%ebx
c002cfcc:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 5 * TIMER_FREQ)
c002cfce:	89 1c 24             	mov    %ebx,(%esp)
c002cfd1:	89 74 24 04          	mov    %esi,0x4(%esp)
c002cfd5:	e8 62 72 ff ff       	call   c002423c <timer_elapsed>
c002cfda:	85 d2                	test   %edx,%edx
c002cfdc:	7f 0b                	jg     c002cfe9 <test_mlfqs_block+0xca>
c002cfde:	85 d2                	test   %edx,%edx
c002cfe0:	78 ec                	js     c002cfce <test_mlfqs_block+0xaf>
c002cfe2:	3d f3 01 00 00       	cmp    $0x1f3,%eax
c002cfe7:	76 e5                	jbe    c002cfce <test_mlfqs_block+0xaf>
  msg ("Main thread releasing lock.");
c002cfe9:	c7 04 24 8b 13 03 c0 	movl   $0xc003138b,(%esp)
c002cff0:	e8 48 d7 ff ff       	call   c002a73d <msg>
  lock_release (&lock);
c002cff5:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c002cff9:	89 04 24             	mov    %eax,(%esp)
c002cffc:	e8 23 60 ff ff       	call   c0023024 <lock_release>
  msg ("Block thread should have already acquired lock.");
c002d001:	c7 04 24 34 13 03 c0 	movl   $0xc0031334,(%esp)
c002d008:	e8 30 d7 ff ff       	call   c002a73d <msg>
}
c002d00d:	83 c4 54             	add    $0x54,%esp
c002d010:	5b                   	pop    %ebx
c002d011:	5e                   	pop    %esi
c002d012:	c3                   	ret    
