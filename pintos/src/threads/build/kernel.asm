
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
c002019f:	c7 04 24 39 e1 02 c0 	movl   $0xc002e139,(%esp)
c00201a6:	e8 c3 69 00 00       	call   c0026b6e <printf>
#ifdef USERPROG
  process_wait (process_execute (task));
#else
  run_test (task);
c00201ab:	89 1c 24             	mov    %ebx,(%esp)
c00201ae:	e8 06 a6 00 00       	call   c002a7b9 <run_test>
#endif
  printf ("Execution of '%s' complete.\n", task);
c00201b3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00201b7:	c7 04 24 4a e1 02 c0 	movl   $0xc002e14a,(%esp)
c00201be:	e8 ab 69 00 00       	call   c0026b6e <printf>
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
c00201cf:	b8 cc 7b 03 c0       	mov    $0xc0037bcc,%eax
c00201d4:	2d 98 5a 03 c0       	sub    $0xc0035a98,%eax
c00201d9:	89 44 24 08          	mov    %eax,0x8(%esp)
c00201dd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00201e4:	00 
c00201e5:	c7 04 24 98 5a 03 c0 	movl   $0xc0035a98,(%esp)
c00201ec:	e8 90 7c 00 00       	call   c0027e81 <memset>
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
c0020217:	c7 44 24 0c 74 e2 02 	movl   $0xc002e274,0xc(%esp)
c002021e:	c0 
c002021f:	c7 44 24 08 a7 d0 02 	movl   $0xc002d0a7,0x8(%esp)
c0020226:	c0 
c0020227:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c002022e:	00 
c002022f:	c7 04 24 67 e1 02 c0 	movl   $0xc002e167,(%esp)
c0020236:	e8 88 87 00 00       	call   c00289c3 <debug_panic>
      argv[i] = p;
c002023b:	89 1c b5 a0 5a 03 c0 	mov    %ebx,-0x3ffca560(,%esi,4)
      p += strnlen (p, end - p) + 1;
c0020242:	89 e8                	mov    %ebp,%eax
c0020244:	29 d8                	sub    %ebx,%eax
c0020246:	89 44 24 04          	mov    %eax,0x4(%esp)
c002024a:	89 1c 24             	mov    %ebx,(%esp)
c002024d:	e8 58 7d 00 00       	call   c0027faa <strnlen>
c0020252:	8d 5c 03 01          	lea    0x1(%ebx,%eax,1),%ebx
  for (i = 0; i < argc; i++) 
c0020256:	83 c6 01             	add    $0x1,%esi
c0020259:	39 f7                	cmp    %esi,%edi
c002025b:	75 b2                	jne    c002020f <pintos_init+0x47>
  argv[argc] = NULL;
c002025d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020264:	00 00 00 00 
  printf ("Kernel command line:");
c0020268:	c7 04 24 5d e2 02 c0 	movl   $0xc002e25d,(%esp)
c002026f:	e8 fa 68 00 00       	call   c0026b6e <printf>
  for (i = 0; i < argc; i++)
c0020274:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (argv[i], ' ') == NULL)
c0020279:	8b 34 9d a0 5a 03 c0 	mov    -0x3ffca560(,%ebx,4),%esi
c0020280:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c0020287:	00 
c0020288:	89 34 24             	mov    %esi,(%esp)
c002028b:	e8 66 79 00 00       	call   c0027bf6 <strchr>
c0020290:	85 c0                	test   %eax,%eax
c0020292:	75 12                	jne    c00202a6 <pintos_init+0xde>
      printf (" %s", argv[i]);
c0020294:	89 74 24 04          	mov    %esi,0x4(%esp)
c0020298:	c7 04 24 87 ef 02 c0 	movl   $0xc002ef87,(%esp)
c002029f:	e8 ca 68 00 00       	call   c0026b6e <printf>
c00202a4:	eb 10                	jmp    c00202b6 <pintos_init+0xee>
      printf (" '%s'", argv[i]);
c00202a6:	89 74 24 04          	mov    %esi,0x4(%esp)
c00202aa:	c7 04 24 7c e1 02 c0 	movl   $0xc002e17c,(%esp)
c00202b1:	e8 b8 68 00 00       	call   c0026b6e <printf>
  for (i = 0; i < argc; i++)
c00202b6:	83 c3 01             	add    $0x1,%ebx
c00202b9:	39 df                	cmp    %ebx,%edi
c00202bb:	75 bc                	jne    c0020279 <pintos_init+0xb1>
  printf ("\n");
c00202bd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00202c4:	e8 93 a4 00 00       	call   c002a75c <putchar>
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
c00202ec:	c7 44 24 04 19 ee 02 	movl   $0xc002ee19,0x4(%esp)
c00202f3:	c0 
c00202f4:	89 04 24             	mov    %eax,(%esp)
c00202f7:	e8 68 7a 00 00       	call   c0027d64 <strtok_r>
c00202fc:	89 c3                	mov    %eax,%ebx
      char *value = strtok_r (NULL, "", &save_ptr);
c00202fe:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020302:	89 44 24 08          	mov    %eax,0x8(%esp)
c0020306:	c7 44 24 04 2b ee 02 	movl   $0xc002ee2b,0x4(%esp)
c002030d:	c0 
c002030e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0020315:	e8 4a 7a 00 00       	call   c0027d64 <strtok_r>
      if (!strcmp (name, "-h"))
c002031a:	bf 82 e1 02 c0       	mov    $0xc002e182,%edi
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
c0020332:	c7 04 24 94 e2 02 c0 	movl   $0xc002e294,(%esp)
c0020339:	e8 ad a3 00 00       	call   c002a6eb <puts>
          "  -mlfqs             Use multi-level feedback queue scheduler.\n"
#ifdef USERPROG
          "  -ul=COUNT          Limit user memory to COUNT pages.\n"
#endif
          );
  shutdown_power_off ();
c002033e:	e8 0c 61 00 00       	call   c002644f <shutdown_power_off>
      else if (!strcmp (name, "-q"))
c0020343:	bf 85 e1 02 c0       	mov    $0xc002e185,%edi
c0020348:	89 de                	mov    %ebx,%esi
c002034a:	b9 03 00 00 00       	mov    $0x3,%ecx
c002034f:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c0020351:	0f 97 c1             	seta   %cl
c0020354:	0f 92 c2             	setb   %dl
c0020357:	38 d1                	cmp    %dl,%cl
c0020359:	75 11                	jne    c002036c <pintos_init+0x1a4>
        shutdown_configure (SHUTDOWN_POWER_OFF);
c002035b:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0020362:	e8 69 60 00 00       	call   c00263d0 <shutdown_configure>
c0020367:	e9 99 00 00 00       	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-r"))
c002036c:	bf 88 e1 02 c0       	mov    $0xc002e188,%edi
c0020371:	89 de                	mov    %ebx,%esi
c0020373:	b9 03 00 00 00       	mov    $0x3,%ecx
c0020378:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c002037a:	0f 97 c1             	seta   %cl
c002037d:	0f 92 c2             	setb   %dl
c0020380:	38 d1                	cmp    %dl,%cl
c0020382:	75 0e                	jne    c0020392 <pintos_init+0x1ca>
        shutdown_configure (SHUTDOWN_REBOOT);
c0020384:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c002038b:	e8 40 60 00 00       	call   c00263d0 <shutdown_configure>
c0020390:	eb 73                	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-rs"))
c0020392:	bf 8b e1 02 c0       	mov    $0xc002e18b,%edi
c0020397:	b9 04 00 00 00       	mov    $0x4,%ecx
c002039c:	89 de                	mov    %ebx,%esi
c002039e:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00203a0:	0f 97 c1             	seta   %cl
c00203a3:	0f 92 c2             	setb   %dl
c00203a6:	38 d1                	cmp    %dl,%cl
c00203a8:	75 12                	jne    c00203bc <pintos_init+0x1f4>
        random_init (atoi (value));
c00203aa:	89 04 24             	mov    %eax,(%esp)
c00203ad:	e8 1e 72 00 00       	call   c00275d0 <atoi>
c00203b2:	89 04 24             	mov    %eax,(%esp)
c00203b5:	e8 61 62 00 00       	call   c002661b <random_init>
c00203ba:	eb 49                	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-mlfqs"))
c00203bc:	bf 8f e1 02 c0       	mov    $0xc002e18f,%edi
c00203c1:	b9 07 00 00 00       	mov    $0x7,%ecx
c00203c6:	89 de                	mov    %ebx,%esi
c00203c8:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00203ca:	0f 97 c2             	seta   %dl
c00203cd:	0f 92 c0             	setb   %al
c00203d0:	38 c2                	cmp    %al,%dl
c00203d2:	75 09                	jne    c00203dd <pintos_init+0x215>
        thread_mlfqs = true;
c00203d4:	c6 05 c0 7b 03 c0 01 	movb   $0x1,0xc0037bc0
c00203db:	eb 28                	jmp    c0020405 <pintos_init+0x23d>
        PANIC ("unknown option `%s' (use -h for help)", name);
c00203dd:	89 5c 24 10          	mov    %ebx,0x10(%esp)
c00203e1:	c7 44 24 0c 64 e4 02 	movl   $0xc002e464,0xc(%esp)
c00203e8:	c0 
c00203e9:	c7 44 24 08 94 d0 02 	movl   $0xc002d094,0x8(%esp)
c00203f0:	c0 
c00203f1:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c00203f8:	00 
c00203f9:	c7 04 24 67 e1 02 c0 	movl   $0xc002e167,(%esp)
c0020400:	e8 be 85 00 00       	call   c00289c3 <debug_panic>
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
c0020427:	e8 40 5e 00 00       	call   c002626c <rtc_get_time>
c002042c:	89 04 24             	mov    %eax,(%esp)
c002042f:	e8 e7 61 00 00       	call   c002661b <random_init>
  thread_init ();
c0020434:	e8 ce 07 00 00       	call   c0020c07 <thread_init>
  console_init ();  
c0020439:	e8 24 a2 00 00       	call   c002a662 <console_init>
          init_ram_pages * PGSIZE / 1024);
c002043e:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c0020443:	c1 e0 0c             	shl    $0xc,%eax
  printf ("Pintos booting with %'"PRIu32" kB RAM...\n",
c0020446:	c1 e8 0a             	shr    $0xa,%eax
c0020449:	89 44 24 04          	mov    %eax,0x4(%esp)
c002044d:	c7 04 24 8c e4 02 c0 	movl   $0xc002e48c,(%esp)
c0020454:	e8 15 67 00 00       	call   c0026b6e <printf>
  palloc_init (user_page_limit);
c0020459:	c7 04 24 ff ff ff ff 	movl   $0xffffffff,(%esp)
c0020460:	e8 ab 30 00 00       	call   c0023510 <palloc_init>
  malloc_init ();
c0020465:	e8 2d 35 00 00       	call   c0023997 <malloc_init>
  pd = init_page_dir = palloc_get_page (PAL_ASSERT | PAL_ZERO);
c002046a:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
c0020471:	e8 00 32 00 00       	call   c0023676 <palloc_get_page>
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
c00204a9:	c7 44 24 10 96 e1 02 	movl   $0xc002e196,0x10(%esp)
c00204b0:	c0 
c00204b1:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00204b8:	c0 
c00204b9:	c7 44 24 08 a2 d0 02 	movl   $0xc002d0a2,0x8(%esp)
c00204c0:	c0 
c00204c1:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c00204c8:	00 
c00204c9:	c7 04 24 c8 e1 02 c0 	movl   $0xc002e1c8,(%esp)
c00204d0:	e8 ee 84 00 00       	call   c00289c3 <debug_panic>
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
c0020526:	e8 4b 31 00 00       	call   c0023676 <palloc_get_page>
  return (uintptr_t) va & PGMASK;
c002052b:	89 c2                	mov    %eax,%edx
#define PTE_A 0x20              /* 1=accessed, 0=not acccessed. */
#define PTE_D 0x40              /* 1=dirty, 0=not dirty (PTEs only). */

/* Returns a PDE that points to page table PT. */
static inline uint32_t pde_create (uint32_t *pt) {
  ASSERT (pg_ofs (pt) == 0);
c002052d:	a9 ff 0f 00 00       	test   $0xfff,%eax
c0020532:	74 2c                	je     c0020560 <pintos_init+0x398>
c0020534:	c7 44 24 10 de e1 02 	movl   $0xc002e1de,0x10(%esp)
c002053b:	c0 
c002053c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020543:	c0 
c0020544:	c7 44 24 08 89 d0 02 	movl   $0xc002d089,0x8(%esp)
c002054b:	c0 
c002054c:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c0020553:	00 
c0020554:	c7 04 24 ef e1 02 c0 	movl   $0xc002e1ef,(%esp)
c002055b:	e8 63 84 00 00       	call   c00289c3 <debug_panic>
/* Returns physical address at which kernel virtual address VADDR
   is mapped. */
static inline uintptr_t
vtop (const void *vaddr)
{
  ASSERT (is_kernel_vaddr (vaddr));
c0020560:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c0020565:	77 2c                	ja     c0020593 <pintos_init+0x3cb>
c0020567:	c7 44 24 10 03 e2 02 	movl   $0xc002e203,0x10(%esp)
c002056e:	c0 
c002056f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020576:	c0 
c0020577:	c7 44 24 08 84 d0 02 	movl   $0xc002d084,0x8(%esp)
c002057e:	c0 
c002057f:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0020586:	00 
c0020587:	c7 04 24 c8 e1 02 c0 	movl   $0xc002e1c8,(%esp)
c002058e:	e8 30 84 00 00       	call   c00289c3 <debug_panic>

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
c00205b1:	c7 44 24 10 03 e2 02 	movl   $0xc002e203,0x10(%esp)
c00205b8:	c0 
c00205b9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00205c0:	c0 
c00205c1:	c7 44 24 08 84 d0 02 	movl   $0xc002d084,0x8(%esp)
c00205c8:	c0 
c00205c9:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c00205d0:	00 
c00205d1:	c7 04 24 c8 e1 02 c0 	movl   $0xc002e1c8,(%esp)
c00205d8:	e8 e6 83 00 00       	call   c00289c3 <debug_panic>
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
c0020611:	c7 44 24 10 03 e2 02 	movl   $0xc002e203,0x10(%esp)
c0020618:	c0 
c0020619:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020620:	c0 
c0020621:	c7 44 24 08 84 d0 02 	movl   $0xc002d084,0x8(%esp)
c0020628:	c0 
c0020629:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0020630:	00 
c0020631:	c7 04 24 c8 e1 02 c0 	movl   $0xc002e1c8,(%esp)
c0020638:	e8 86 83 00 00       	call   c00289c3 <debug_panic>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c002063d:	05 00 00 00 40       	add    $0x40000000,%eax
c0020642:	0f 22 d8             	mov    %eax,%cr3
  intr_init ();
c0020645:	e8 e7 13 00 00       	call   c0021a31 <intr_init>
  timer_init ();
c002064a:	e8 8e 3a 00 00       	call   c00240dd <timer_init>
  kbd_init ();
c002064f:	e8 37 40 00 00       	call   c002468b <kbd_init>
  input_init ();
c0020654:	e8 fc 56 00 00       	call   c0025d55 <input_init>
  thread_start ();
c0020659:	e8 47 10 00 00       	call   c00216a5 <thread_start>
c002065e:	66 90                	xchg   %ax,%ax
  serial_init_queue ();
c0020660:	e8 71 44 00 00       	call   c0024ad6 <serial_init_queue>
  timer_calibrate ();
c0020665:	e8 00 3b 00 00       	call   c002416a <timer_calibrate>
  printf ("Boot complete.\n");
c002066a:	c7 04 24 1b e2 02 c0 	movl   $0xc002e21b,(%esp)
c0020671:	e8 75 a0 00 00       	call   c002a6eb <puts>
  if (*argv != NULL) {
c0020676:	8b 75 00             	mov    0x0(%ebp),%esi
c0020679:	85 f6                	test   %esi,%esi
c002067b:	0f 84 c9 00 00 00    	je     c002074a <pintos_init+0x582>
        if (a->name == NULL)
c0020681:	b8 ce e7 02 c0       	mov    $0xc002e7ce,%eax
  if (*argv != NULL) {
c0020686:	bb 6c d0 02 c0       	mov    $0xc002d06c,%ebx
c002068b:	eb 0c                	jmp    c0020699 <pintos_init+0x4d1>
        if (a->name == NULL)
c002068d:	b8 ce e7 02 c0       	mov    $0xc002e7ce,%eax
  while (*argv != NULL)
c0020692:	ba 6c d0 02 c0       	mov    $0xc002d06c,%edx
c0020697:	89 d3                	mov    %edx,%ebx
        else if (!strcmp (*argv, a->name))
c0020699:	89 44 24 04          	mov    %eax,0x4(%esp)
c002069d:	89 34 24             	mov    %esi,(%esp)
c00206a0:	e8 32 74 00 00       	call   c0027ad7 <strcmp>
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
c00206c7:	c7 44 24 0c b0 e4 02 	movl   $0xc002e4b0,0xc(%esp)
c00206ce:	c0 
c00206cf:	c7 44 24 08 60 d0 02 	movl   $0xc002d060,0x8(%esp)
c00206d6:	c0 
c00206d7:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c00206de:	00 
c00206df:	c7 04 24 67 e1 02 c0 	movl   $0xc002e167,(%esp)
c00206e6:	e8 d8 82 00 00       	call   c00289c3 <debug_panic>
        if (argv[i] == NULL)
c00206eb:	83 7c 85 00 00       	cmpl   $0x0,0x0(%ebp,%eax,4)
c00206f0:	75 34                	jne    c0020726 <pintos_init+0x55e>
          PANIC ("action `%s' requires %d argument(s)", *argv, a->argc - 1);
c00206f2:	83 ea 01             	sub    $0x1,%edx
c00206f5:	89 54 24 14          	mov    %edx,0x14(%esp)
c00206f9:	89 74 24 10          	mov    %esi,0x10(%esp)
c00206fd:	c7 44 24 0c d8 e4 02 	movl   $0xc002e4d8,0xc(%esp)
c0020704:	c0 
c0020705:	c7 44 24 08 60 d0 02 	movl   $0xc002d060,0x8(%esp)
c002070c:	c0 
c002070d:	c7 44 24 04 72 01 00 	movl   $0x172,0x4(%esp)
c0020714:	00 
c0020715:	c7 04 24 67 e1 02 c0 	movl   $0xc002e167,(%esp)
c002071c:	e8 a2 82 00 00       	call   c00289c3 <debug_panic>
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
c0020757:	c7 44 24 04 2b ee 02 	movl   $0xc002ee2b,0x4(%esp)
c002075e:	c0 
c002075f:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020763:	89 04 24             	mov    %eax,(%esp)
c0020766:	e8 6b 78 00 00       	call   c0027fd6 <strlcpy>
      printf("ICS143A>");
c002076b:	c7 04 24 2a e2 02 c0 	movl   $0xc002e22a,(%esp)
c0020772:	e8 f7 63 00 00       	call   c0026b6e <printf>
        char l = input_getc();
c0020777:	e8 82 56 00 00       	call   c0025dfe <input_getc>
c002077c:	89 c3                	mov    %eax,%ebx
        while(l != '\n'){
c002077e:	3c 0a                	cmp    $0xa,%al
c0020780:	74 24                	je     c00207a6 <pintos_init+0x5de>
c0020782:	be 00 00 00 00       	mov    $0x0,%esi
          printf("%c",l);
c0020787:	0f be c3             	movsbl %bl,%eax
c002078a:	89 04 24             	mov    %eax,(%esp)
c002078d:	e8 ca 9f 00 00       	call   c002a75c <putchar>
          cmdline[i] = l;
c0020792:	88 5c 34 3c          	mov    %bl,0x3c(%esp,%esi,1)
          l = input_getc();
c0020796:	e8 63 56 00 00       	call   c0025dfe <input_getc>
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
c00207b0:	bf 33 e2 02 c0       	mov    $0xc002e233,%edi
c00207b5:	8d 74 24 3c          	lea    0x3c(%esp),%esi
c00207b9:	89 e9                	mov    %ebp,%ecx
c00207bb:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00207bd:	0f 97 c2             	seta   %dl
c00207c0:	0f 92 c0             	setb   %al
c00207c3:	38 c2                	cmp    %al,%dl
c00207c5:	75 0e                	jne    c00207d5 <pintos_init+0x60d>
          printf("\nSydney Eads\n");
c00207c7:	c7 04 24 3a e2 02 c0 	movl   $0xc002e23a,(%esp)
c00207ce:	e8 18 9f 00 00       	call   c002a6eb <puts>
c00207d3:	eb 34                	jmp    c0020809 <pintos_init+0x641>
        else if(!strcmp(cmdline,"exit")){
c00207d5:	bf 47 e2 02 c0       	mov    $0xc002e247,%edi
c00207da:	b9 05 00 00 00       	mov    $0x5,%ecx
c00207df:	8d 74 24 3c          	lea    0x3c(%esp),%esi
c00207e3:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00207e5:	0f 97 c2             	seta   %dl
c00207e8:	0f 92 c0             	setb   %al
c00207eb:	38 c2                	cmp    %al,%dl
c00207ed:	75 0e                	jne    c00207fd <pintos_init+0x635>
          printf("\n");
c00207ef:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00207f6:	e8 61 9f 00 00       	call   c002a75c <putchar>
c00207fb:	eb 26                	jmp    c0020823 <pintos_init+0x65b>
          printf("\ninvalid command\n");
c00207fd:	c7 04 24 4c e2 02 c0 	movl   $0xc002e24c,(%esp)
c0020804:	e8 e2 9e 00 00       	call   c002a6eb <puts>
        memset(&cmdline[0], 0, sizeof(cmdline));
c0020809:	b9 0c 00 00 00       	mov    $0xc,%ecx
c002080e:	b8 00 00 00 00       	mov    $0x0,%eax
c0020813:	8d 7c 24 3c          	lea    0x3c(%esp),%edi
c0020817:	f3 ab                	rep stos %eax,%es:(%edi)
c0020819:	66 c7 07 00 00       	movw   $0x0,(%edi)
    }
c002081e:	e9 2c ff ff ff       	jmp    c002074f <pintos_init+0x587>
  shutdown ();
c0020823:	e8 a8 5c 00 00       	call   c00264d0 <shutdown>
  thread_exit ();
c0020828:	e8 e5 0b 00 00       	call   c0021412 <thread_exit>
  argv[argc] = NULL;
c002082d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020834:	00 00 00 00 
  printf ("Kernel command line:");
c0020838:	c7 04 24 5d e2 02 c0 	movl   $0xc002e25d,(%esp)
c002083f:	e8 2a 63 00 00       	call   c0026b6e <printf>
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
c0020876:	c7 44 24 10 fc e4 02 	movl   $0xc002e4fc,0x10(%esp)
c002087d:	c0 
c002087e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020885:	c0 
c0020886:	c7 44 24 08 3e d1 02 	movl   $0xc002d13e,0x8(%esp)
c002088d:	c0 
c002088e:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
c0020895:	00 
c0020896:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c002089d:	e8 21 81 00 00       	call   c00289c3 <debug_panic>
c00208a2:	f6 c2 03             	test   $0x3,%dl
c00208a5:	74 2e                	je     c00208d5 <alloc_frame+0x73>
c00208a7:	eb cd                	jmp    c0020876 <alloc_frame+0x14>
  ASSERT (is_thread (t));
c00208a9:	c7 44 24 10 31 e5 02 	movl   $0xc002e531,0x10(%esp)
c00208b0:	c0 
c00208b1:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00208b8:	c0 
c00208b9:	c7 44 24 08 3e d1 02 	movl   $0xc002d13e,0x8(%esp)
c00208c0:	c0 
c00208c1:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
c00208c8:	00 
c00208c9:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00208d0:	e8 ee 80 00 00       	call   c00289c3 <debug_panic>

  t->stack -= size;
c00208d5:	8b 40 18             	mov    0x18(%eax),%eax
c00208d8:	29 d0                	sub    %edx,%eax
c00208da:	89 41 18             	mov    %eax,0x18(%ecx)
  return t->stack;
}
c00208dd:	83 c4 2c             	add    $0x2c,%esp
c00208e0:	c3                   	ret    

c00208e1 <power>:
{
c00208e1:	83 ec 1c             	sub    $0x1c,%esp
c00208e4:	8b 54 24 24          	mov    0x24(%esp),%edx
    return 1;
c00208e8:	b8 01 00 00 00       	mov    $0x1,%eax
  if (pow == 0)
c00208ed:	85 d2                	test   %edx,%edx
c00208ef:	74 46                	je     c0020937 <power+0x56>
  else if (pow % 2 == 0)
c00208f1:	f6 c2 01             	test   $0x1,%dl
c00208f4:	75 1e                	jne    c0020914 <power+0x33>
    return power(base, pow / 2) * power(base, pow / 2);
c00208f6:	89 d0                	mov    %edx,%eax
c00208f8:	c1 e8 1f             	shr    $0x1f,%eax
c00208fb:	01 c2                	add    %eax,%edx
c00208fd:	d1 fa                	sar    %edx
c00208ff:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020903:	8b 44 24 20          	mov    0x20(%esp),%eax
c0020907:	89 04 24             	mov    %eax,(%esp)
c002090a:	e8 d2 ff ff ff       	call   c00208e1 <power>
c002090f:	0f af c0             	imul   %eax,%eax
c0020912:	eb 23                	jmp    c0020937 <power+0x56>
    return base * power(base, pow / 2) * power(base, pow / 2);
c0020914:	89 d0                	mov    %edx,%eax
c0020916:	c1 e8 1f             	shr    $0x1f,%eax
c0020919:	01 c2                	add    %eax,%edx
c002091b:	d1 fa                	sar    %edx
c002091d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020921:	8b 44 24 20          	mov    0x20(%esp),%eax
c0020925:	89 04 24             	mov    %eax,(%esp)
c0020928:	e8 b4 ff ff ff       	call   c00208e1 <power>
c002092d:	89 c2                	mov    %eax,%edx
c002092f:	0f af 54 24 20       	imul   0x20(%esp),%edx
c0020934:	0f af c2             	imul   %edx,%eax
}
c0020937:	83 c4 1c             	add    $0x1c,%esp
c002093a:	c3                   	ret    

c002093b <convertNtoFixedPoint>:
    return n * f;
c002093b:	8b 44 24 04          	mov    0x4(%esp),%eax
c002093f:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
}
c0020946:	c3                   	ret    

c0020947 <convertXtoInt>:
{
c0020947:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / f;
c002094b:	99                   	cltd   
c002094c:	f7 3d bc 7b 03 c0    	idivl  0xc0037bbc
}
c0020952:	c3                   	ret    

c0020953 <convertXtoIntRoundNear>:
{
c0020953:	8b 44 24 04          	mov    0x4(%esp),%eax
    if(x >= 0)
c0020957:	85 c0                	test   %eax,%eax
c0020959:	78 15                	js     c0020970 <convertXtoIntRoundNear+0x1d>
        return (x + f / 2) / f;
c002095b:	8b 0d bc 7b 03 c0    	mov    0xc0037bbc,%ecx
c0020961:	89 ca                	mov    %ecx,%edx
c0020963:	c1 ea 1f             	shr    $0x1f,%edx
c0020966:	01 ca                	add    %ecx,%edx
c0020968:	d1 fa                	sar    %edx
c002096a:	01 d0                	add    %edx,%eax
c002096c:	99                   	cltd   
c002096d:	f7 f9                	idiv   %ecx
c002096f:	c3                   	ret    
        return (x - f / 2) / f;
c0020970:	8b 0d bc 7b 03 c0    	mov    0xc0037bbc,%ecx
c0020976:	89 ca                	mov    %ecx,%edx
c0020978:	c1 ea 1f             	shr    $0x1f,%edx
c002097b:	01 ca                	add    %ecx,%edx
c002097d:	d1 fa                	sar    %edx
c002097f:	29 d0                	sub    %edx,%eax
c0020981:	99                   	cltd   
c0020982:	f7 f9                	idiv   %ecx
}
c0020984:	c3                   	ret    

c0020985 <init_thread>:
{
c0020985:	55                   	push   %ebp
c0020986:	57                   	push   %edi
c0020987:	56                   	push   %esi
c0020988:	53                   	push   %ebx
c0020989:	83 ec 2c             	sub    $0x2c,%esp
c002098c:	89 c3                	mov    %eax,%ebx
  ASSERT (t != NULL);
c002098e:	85 c0                	test   %eax,%eax
c0020990:	75 2c                	jne    c00209be <init_thread+0x39>
c0020992:	c7 44 24 10 77 fa 02 	movl   $0xc002fa77,0x10(%esp)
c0020999:	c0 
c002099a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00209a1:	c0 
c00209a2:	c7 44 24 08 66 d1 02 	movl   $0xc002d166,0x8(%esp)
c00209a9:	c0 
c00209aa:	c7 44 24 04 04 03 00 	movl   $0x304,0x4(%esp)
c00209b1:	00 
c00209b2:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00209b9:	e8 05 80 00 00       	call   c00289c3 <debug_panic>
c00209be:	89 ce                	mov    %ecx,%esi
  ASSERT (PRI_MIN <= priority && priority <= PRI_MAX);
c00209c0:	83 f9 3f             	cmp    $0x3f,%ecx
c00209c3:	76 2c                	jbe    c00209f1 <init_thread+0x6c>
c00209c5:	c7 44 24 10 20 e6 02 	movl   $0xc002e620,0x10(%esp)
c00209cc:	c0 
c00209cd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00209d4:	c0 
c00209d5:	c7 44 24 08 66 d1 02 	movl   $0xc002d166,0x8(%esp)
c00209dc:	c0 
c00209dd:	c7 44 24 04 05 03 00 	movl   $0x305,0x4(%esp)
c00209e4:	00 
c00209e5:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00209ec:	e8 d2 7f 00 00       	call   c00289c3 <debug_panic>
  ASSERT (name != NULL);
c00209f1:	85 d2                	test   %edx,%edx
c00209f3:	75 2c                	jne    c0020a21 <init_thread+0x9c>
c00209f5:	c7 44 24 10 3f e5 02 	movl   $0xc002e53f,0x10(%esp)
c00209fc:	c0 
c00209fd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020a04:	c0 
c0020a05:	c7 44 24 08 66 d1 02 	movl   $0xc002d166,0x8(%esp)
c0020a0c:	c0 
c0020a0d:	c7 44 24 04 06 03 00 	movl   $0x306,0x4(%esp)
c0020a14:	00 
c0020a15:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020a1c:	e8 a2 7f 00 00       	call   c00289c3 <debug_panic>
  memset (t, 0, sizeof *t);
c0020a21:	89 c7                	mov    %eax,%edi
c0020a23:	bd 5c 00 00 00       	mov    $0x5c,%ebp
c0020a28:	a8 01                	test   $0x1,%al
c0020a2a:	74 0a                	je     c0020a36 <init_thread+0xb1>
c0020a2c:	c6 00 00             	movb   $0x0,(%eax)
c0020a2f:	8d 78 01             	lea    0x1(%eax),%edi
c0020a32:	66 bd 5b 00          	mov    $0x5b,%bp
c0020a36:	f7 c7 02 00 00 00    	test   $0x2,%edi
c0020a3c:	74 0b                	je     c0020a49 <init_thread+0xc4>
c0020a3e:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0020a43:	83 c7 02             	add    $0x2,%edi
c0020a46:	83 ed 02             	sub    $0x2,%ebp
c0020a49:	89 e9                	mov    %ebp,%ecx
c0020a4b:	c1 e9 02             	shr    $0x2,%ecx
c0020a4e:	b8 00 00 00 00       	mov    $0x0,%eax
c0020a53:	f3 ab                	rep stos %eax,%es:(%edi)
c0020a55:	f7 c5 02 00 00 00    	test   $0x2,%ebp
c0020a5b:	74 08                	je     c0020a65 <init_thread+0xe0>
c0020a5d:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0020a62:	83 c7 02             	add    $0x2,%edi
c0020a65:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c0020a6b:	74 03                	je     c0020a70 <init_thread+0xeb>
c0020a6d:	c6 07 00             	movb   $0x0,(%edi)
  t->status = THREAD_BLOCKED;
c0020a70:	c7 43 04 02 00 00 00 	movl   $0x2,0x4(%ebx)
  strlcpy (t->name, name, sizeof t->name);
c0020a77:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c0020a7e:	00 
c0020a7f:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020a83:	8d 43 08             	lea    0x8(%ebx),%eax
c0020a86:	89 04 24             	mov    %eax,(%esp)
c0020a89:	e8 48 75 00 00       	call   c0027fd6 <strlcpy>
  t->stack = (uint8_t *) t + PGSIZE;
c0020a8e:	8d 83 00 10 00 00    	lea    0x1000(%ebx),%eax
c0020a94:	89 43 18             	mov    %eax,0x18(%ebx)
  t->priority = priority;
c0020a97:	89 73 1c             	mov    %esi,0x1c(%ebx)
  t->magic = THREAD_MAGIC;
c0020a9a:	c7 43 30 4b bf 6a cd 	movl   $0xcd6abf4b,0x30(%ebx)
  list_push_back (&all_list, &t->allelem);
c0020aa1:	8d 43 20             	lea    0x20(%ebx),%eax
c0020aa4:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020aa8:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020aaf:	e8 5d 85 00 00       	call   c0029011 <list_push_back>
  if(!thread_mlfqs)
c0020ab4:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020abb:	75 08                	jne    c0020ac5 <init_thread+0x140>
    t->priority = priority;
c0020abd:	89 73 1c             	mov    %esi,0x1c(%ebx)
    t->old_priority = priority;
c0020ac0:	89 73 3c             	mov    %esi,0x3c(%ebx)
c0020ac3:	eb 43                	jmp    c0020b08 <init_thread+0x183>
    t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020ac5:	8b 43 58             	mov    0x58(%ebx),%eax
c0020ac8:	8d 50 03             	lea    0x3(%eax),%edx
c0020acb:	85 c0                	test   %eax,%eax
c0020acd:	0f 48 c2             	cmovs  %edx,%eax
c0020ad0:	c1 f8 02             	sar    $0x2,%eax
c0020ad3:	89 04 24             	mov    %eax,(%esp)
c0020ad6:	e8 78 fe ff ff       	call   c0020953 <convertXtoIntRoundNear>
c0020adb:	ba 3f 00 00 00       	mov    $0x3f,%edx
c0020ae0:	29 c2                	sub    %eax,%edx
c0020ae2:	89 d0                	mov    %edx,%eax
c0020ae4:	8b 53 54             	mov    0x54(%ebx),%edx
c0020ae7:	f7 da                	neg    %edx
c0020ae9:	8d 04 50             	lea    (%eax,%edx,2),%eax
c0020aec:	89 43 1c             	mov    %eax,0x1c(%ebx)
    if(t->priority > PRI_MAX)
c0020aef:	83 f8 3f             	cmp    $0x3f,%eax
c0020af2:	7e 09                	jle    c0020afd <init_thread+0x178>
      t->priority = PRI_MAX;
c0020af4:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c0020afb:	eb 0b                	jmp    c0020b08 <init_thread+0x183>
    if(t->priority < PRI_MIN)
c0020afd:	85 c0                	test   %eax,%eax
c0020aff:	79 07                	jns    c0020b08 <init_thread+0x183>
      t->priority = PRI_MIN;
c0020b01:	c7 43 1c 00 00 00 00 	movl   $0x0,0x1c(%ebx)
  list_init (&t->locks_held);
c0020b08:	8d 43 40             	lea    0x40(%ebx),%eax
c0020b0b:	89 04 24             	mov    %eax,(%esp)
c0020b0e:	e8 7d 7f 00 00       	call   c0028a90 <list_init>
  t->wait_on_lock = NULL;
c0020b13:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
}
c0020b1a:	83 c4 2c             	add    $0x2c,%esp
c0020b1d:	5b                   	pop    %ebx
c0020b1e:	5e                   	pop    %esi
c0020b1f:	5f                   	pop    %edi
c0020b20:	5d                   	pop    %ebp
c0020b21:	c3                   	ret    

c0020b22 <addXandY>:
    return x + y;
c0020b22:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b26:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020b2a:	c3                   	ret    

c0020b2b <subtractYfromX>:
    return x - y;
c0020b2b:	8b 44 24 04          	mov    0x4(%esp),%eax
c0020b2f:	2b 44 24 08          	sub    0x8(%esp),%eax
}
c0020b33:	c3                   	ret    

c0020b34 <addXandN>:
    return x + (n * f);
c0020b34:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b38:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
c0020b3f:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020b43:	c3                   	ret    

c0020b44 <subNfromX>:
    return x - (n * f);
c0020b44:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b48:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
c0020b4f:	8b 54 24 04          	mov    0x4(%esp),%edx
c0020b53:	29 c2                	sub    %eax,%edx
c0020b55:	89 d0                	mov    %edx,%eax
}
c0020b57:	c3                   	ret    

c0020b58 <multXbyY>:
{
c0020b58:	57                   	push   %edi
c0020b59:	56                   	push   %esi
c0020b5a:	53                   	push   %ebx
c0020b5b:	83 ec 10             	sub    $0x10,%esp
c0020b5e:	8b 54 24 20          	mov    0x20(%esp),%edx
c0020b62:	8b 44 24 24          	mov    0x24(%esp),%eax
    return ((int64_t) x) * y / f;
c0020b66:	89 d7                	mov    %edx,%edi
c0020b68:	c1 ff 1f             	sar    $0x1f,%edi
c0020b6b:	89 c3                	mov    %eax,%ebx
c0020b6d:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b70:	89 fe                	mov    %edi,%esi
c0020b72:	0f af f0             	imul   %eax,%esi
c0020b75:	89 d9                	mov    %ebx,%ecx
c0020b77:	0f af ca             	imul   %edx,%ecx
c0020b7a:	01 f1                	add    %esi,%ecx
c0020b7c:	f7 e2                	mul    %edx
c0020b7e:	01 ca                	add    %ecx,%edx
c0020b80:	8b 0d bc 7b 03 c0    	mov    0xc0037bbc,%ecx
c0020b86:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020b8a:	89 cb                	mov    %ecx,%ebx
c0020b8c:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b8f:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020b93:	89 04 24             	mov    %eax,(%esp)
c0020b96:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020b9a:	e8 84 77 00 00       	call   c0028323 <__divdi3>
}
c0020b9f:	83 c4 10             	add    $0x10,%esp
c0020ba2:	5b                   	pop    %ebx
c0020ba3:	5e                   	pop    %esi
c0020ba4:	5f                   	pop    %edi
c0020ba5:	c3                   	ret    

c0020ba6 <multXbyN>:
    return x * n;
c0020ba6:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020baa:	0f af 44 24 04       	imul   0x4(%esp),%eax
}
c0020baf:	c3                   	ret    

c0020bb0 <divXbyY>:
{
c0020bb0:	57                   	push   %edi
c0020bb1:	56                   	push   %esi
c0020bb2:	53                   	push   %ebx
c0020bb3:	83 ec 10             	sub    $0x10,%esp
c0020bb6:	8b 54 24 20          	mov    0x20(%esp),%edx
    return ((int64_t) x) * f / y;
c0020bba:	89 d7                	mov    %edx,%edi
c0020bbc:	c1 ff 1f             	sar    $0x1f,%edi
c0020bbf:	a1 bc 7b 03 c0       	mov    0xc0037bbc,%eax
c0020bc4:	89 c3                	mov    %eax,%ebx
c0020bc6:	c1 fb 1f             	sar    $0x1f,%ebx
c0020bc9:	89 fe                	mov    %edi,%esi
c0020bcb:	0f af f0             	imul   %eax,%esi
c0020bce:	89 d9                	mov    %ebx,%ecx
c0020bd0:	0f af ca             	imul   %edx,%ecx
c0020bd3:	01 f1                	add    %esi,%ecx
c0020bd5:	f7 e2                	mul    %edx
c0020bd7:	01 ca                	add    %ecx,%edx
c0020bd9:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c0020bdd:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020be1:	89 cb                	mov    %ecx,%ebx
c0020be3:	c1 fb 1f             	sar    $0x1f,%ebx
c0020be6:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020bea:	89 04 24             	mov    %eax,(%esp)
c0020bed:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020bf1:	e8 2d 77 00 00       	call   c0028323 <__divdi3>
}
c0020bf6:	83 c4 10             	add    $0x10,%esp
c0020bf9:	5b                   	pop    %ebx
c0020bfa:	5e                   	pop    %esi
c0020bfb:	5f                   	pop    %edi
c0020bfc:	c3                   	ret    

c0020bfd <divXbyN>:
{
c0020bfd:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / n;
c0020c01:	99                   	cltd   
c0020c02:	f7 7c 24 08          	idivl  0x8(%esp)
}
c0020c06:	c3                   	ret    

c0020c07 <thread_init>:
{
c0020c07:	56                   	push   %esi
c0020c08:	53                   	push   %ebx
c0020c09:	83 ec 24             	sub    $0x24,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0020c0c:	e8 b3 0d 00 00       	call   c00219c4 <intr_get_level>
c0020c11:	85 c0                	test   %eax,%eax
c0020c13:	74 2c                	je     c0020c41 <thread_init+0x3a>
c0020c15:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0020c1c:	c0 
c0020c1d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020c24:	c0 
c0020c25:	c7 44 24 08 72 d1 02 	movl   $0xc002d172,0x8(%esp)
c0020c2c:	c0 
c0020c2d:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
c0020c34:	00 
c0020c35:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020c3c:	e8 82 7d 00 00       	call   c00289c3 <debug_panic>
  lock_init (&tid_lock);
c0020c41:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020c48:	e8 c0 21 00 00       	call   c0022e0d <lock_init>
  list_init (&all_list);
c0020c4d:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020c54:	e8 37 7e 00 00       	call   c0028a90 <list_init>
  if(thread_mlfqs) {
c0020c59:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020c60:	74 1b                	je     c0020c7d <thread_init+0x76>
c0020c62:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0020c67:	be 20 60 03 c0       	mov    $0xc0036020,%esi
      list_init (&mlfqs_list[i]);
c0020c6c:	89 1c 24             	mov    %ebx,(%esp)
c0020c6f:	e8 1c 7e 00 00       	call   c0028a90 <list_init>
c0020c74:	83 c3 10             	add    $0x10,%ebx
    for(i=0;i<64;i++)
c0020c77:	39 f3                	cmp    %esi,%ebx
c0020c79:	75 f1                	jne    c0020c6c <thread_init+0x65>
c0020c7b:	eb 0c                	jmp    c0020c89 <thread_init+0x82>
    list_init (&ready_list);
c0020c7d:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020c84:	e8 07 7e 00 00       	call   c0028a90 <list_init>
  f = power(2,14);
c0020c89:	c7 44 24 04 0e 00 00 	movl   $0xe,0x4(%esp)
c0020c90:	00 
c0020c91:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c0020c98:	e8 44 fc ff ff       	call   c00208e1 <power>
c0020c9d:	a3 bc 7b 03 c0       	mov    %eax,0xc0037bbc
  initial_thread->nice = 0; //nice value of first thread is zero
c0020ca2:	a1 04 5c 03 c0       	mov    0xc0035c04,%eax
c0020ca7:	c7 40 54 00 00 00 00 	movl   $0x0,0x54(%eax)
  initial_thread->recent_cpu = 0; //recent_cpu of first thread is zero
c0020cae:	c7 40 58 00 00 00 00 	movl   $0x0,0x58(%eax)
  asm ("mov %%esp, %0" : "=g" (esp));
c0020cb5:	89 e0                	mov    %esp,%eax
  return (void *) ((uintptr_t) va & ~PGMASK);
c0020cb7:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  initial_thread = running_thread ();
c0020cbc:	a3 04 5c 03 c0       	mov    %eax,0xc0035c04
  init_thread (initial_thread, "main", PRI_DEFAULT);
c0020cc1:	b9 1f 00 00 00       	mov    $0x1f,%ecx
c0020cc6:	ba 6a e5 02 c0       	mov    $0xc002e56a,%edx
c0020ccb:	e8 b5 fc ff ff       	call   c0020985 <init_thread>
  initial_thread->status = THREAD_RUNNING;
c0020cd0:	8b 1d 04 5c 03 c0    	mov    0xc0035c04,%ebx
c0020cd6:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
allocate_tid (void) 
{
  static tid_t next_tid = 1;
  tid_t tid;

  lock_acquire (&tid_lock);
c0020cdd:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020ce4:	e8 c1 21 00 00       	call   c0022eaa <lock_acquire>
  tid = next_tid++;
c0020ce9:	8b 35 54 56 03 c0    	mov    0xc0035654,%esi
c0020cef:	8d 46 01             	lea    0x1(%esi),%eax
c0020cf2:	a3 54 56 03 c0       	mov    %eax,0xc0035654
  lock_release (&tid_lock);
c0020cf7:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020cfe:	e8 71 23 00 00       	call   c0023074 <lock_release>
  initial_thread->tid = allocate_tid ();
c0020d03:	89 33                	mov    %esi,(%ebx)
}
c0020d05:	83 c4 24             	add    $0x24,%esp
c0020d08:	5b                   	pop    %ebx
c0020d09:	5e                   	pop    %esi
c0020d0a:	c3                   	ret    

c0020d0b <thread_print_stats>:
{
c0020d0b:	83 ec 2c             	sub    $0x2c,%esp
  printf ("Thread: %lld idle ticks, %lld kernel ticks, %lld user ticks\n",
c0020d0e:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0020d15:	00 
c0020d16:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c0020d1d:	00 
c0020d1e:	a1 c8 5b 03 c0       	mov    0xc0035bc8,%eax
c0020d23:	8b 15 cc 5b 03 c0    	mov    0xc0035bcc,%edx
c0020d29:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0020d2d:	89 54 24 10          	mov    %edx,0x10(%esp)
c0020d31:	a1 d0 5b 03 c0       	mov    0xc0035bd0,%eax
c0020d36:	8b 15 d4 5b 03 c0    	mov    0xc0035bd4,%edx
c0020d3c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020d40:	89 54 24 08          	mov    %edx,0x8(%esp)
c0020d44:	c7 04 24 4c e6 02 c0 	movl   $0xc002e64c,(%esp)
c0020d4b:	e8 1e 5e 00 00       	call   c0026b6e <printf>
}
c0020d50:	83 c4 2c             	add    $0x2c,%esp
c0020d53:	c3                   	ret    

c0020d54 <thread_unblock>:
{
c0020d54:	56                   	push   %esi
c0020d55:	53                   	push   %ebx
c0020d56:	83 ec 24             	sub    $0x24,%esp
c0020d59:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  return t != NULL && t->magic == THREAD_MAGIC;
c0020d5d:	85 db                	test   %ebx,%ebx
c0020d5f:	0f 84 96 00 00 00    	je     c0020dfb <thread_unblock+0xa7>
c0020d65:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c0020d6c:	0f 85 89 00 00 00    	jne    c0020dfb <thread_unblock+0xa7>
c0020d72:	eb 75                	jmp    c0020de9 <thread_unblock+0x95>
  ASSERT (t->status == THREAD_BLOCKED);
c0020d74:	c7 44 24 10 6f e5 02 	movl   $0xc002e56f,0x10(%esp)
c0020d7b:	c0 
c0020d7c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020d83:	c0 
c0020d84:	c7 44 24 08 19 d1 02 	movl   $0xc002d119,0x8(%esp)
c0020d8b:	c0 
c0020d8c:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
c0020d93:	00 
c0020d94:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020d9b:	e8 23 7c 00 00       	call   c00289c3 <debug_panic>
  if(thread_mlfqs) {
c0020da0:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020da7:	74 1c                	je     c0020dc5 <thread_unblock+0x71>
    list_push_back (&mlfqs_list[t->priority], &t->elem);
c0020da9:	8d 43 28             	lea    0x28(%ebx),%eax
c0020dac:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020db0:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0020db3:	c1 e0 04             	shl    $0x4,%eax
c0020db6:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c0020dbb:	89 04 24             	mov    %eax,(%esp)
c0020dbe:	e8 4e 82 00 00       	call   c0029011 <list_push_back>
c0020dc3:	eb 13                	jmp    c0020dd8 <thread_unblock+0x84>
    list_push_back (&ready_list, &t->elem);
c0020dc5:	8d 53 28             	lea    0x28(%ebx),%edx
c0020dc8:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020dcc:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020dd3:	e8 39 82 00 00       	call   c0029011 <list_push_back>
  t->status = THREAD_READY;
c0020dd8:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  intr_set_level (old_level);
c0020ddf:	89 34 24             	mov    %esi,(%esp)
c0020de2:	e8 2f 0c 00 00       	call   c0021a16 <intr_set_level>
c0020de7:	eb 3e                	jmp    c0020e27 <thread_unblock+0xd3>
  old_level = intr_disable ();
c0020de9:	e8 21 0c 00 00       	call   c0021a0f <intr_disable>
c0020dee:	89 c6                	mov    %eax,%esi
  ASSERT (t->status == THREAD_BLOCKED);
c0020df0:	83 7b 04 02          	cmpl   $0x2,0x4(%ebx)
c0020df4:	74 aa                	je     c0020da0 <thread_unblock+0x4c>
c0020df6:	e9 79 ff ff ff       	jmp    c0020d74 <thread_unblock+0x20>
  ASSERT (is_thread (t));
c0020dfb:	c7 44 24 10 31 e5 02 	movl   $0xc002e531,0x10(%esp)
c0020e02:	c0 
c0020e03:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020e0a:	c0 
c0020e0b:	c7 44 24 08 19 d1 02 	movl   $0xc002d119,0x8(%esp)
c0020e12:	c0 
c0020e13:	c7 44 24 04 7f 01 00 	movl   $0x17f,0x4(%esp)
c0020e1a:	00 
c0020e1b:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020e22:	e8 9c 7b 00 00       	call   c00289c3 <debug_panic>
}
c0020e27:	83 c4 24             	add    $0x24,%esp
c0020e2a:	5b                   	pop    %ebx
c0020e2b:	5e                   	pop    %esi
c0020e2c:	c3                   	ret    

c0020e2d <thread_current>:
{
c0020e2d:	83 ec 2c             	sub    $0x2c,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0020e30:	89 e0                	mov    %esp,%eax
  return t != NULL && t->magic == THREAD_MAGIC;
c0020e32:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0020e37:	74 3f                	je     c0020e78 <thread_current+0x4b>
c0020e39:	81 78 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%eax)
c0020e40:	75 36                	jne    c0020e78 <thread_current+0x4b>
c0020e42:	eb 2c                	jmp    c0020e70 <thread_current+0x43>
  ASSERT (t->status == THREAD_RUNNING);
c0020e44:	c7 44 24 10 8b e5 02 	movl   $0xc002e58b,0x10(%esp)
c0020e4b:	c0 
c0020e4c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020e53:	c0 
c0020e54:	c7 44 24 08 0a d1 02 	movl   $0xc002d10a,0x8(%esp)
c0020e5b:	c0 
c0020e5c:	c7 44 24 04 af 01 00 	movl   $0x1af,0x4(%esp)
c0020e63:	00 
c0020e64:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020e6b:	e8 53 7b 00 00       	call   c00289c3 <debug_panic>
c0020e70:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0020e74:	74 2e                	je     c0020ea4 <thread_current+0x77>
c0020e76:	eb cc                	jmp    c0020e44 <thread_current+0x17>
  ASSERT (is_thread (t));
c0020e78:	c7 44 24 10 31 e5 02 	movl   $0xc002e531,0x10(%esp)
c0020e7f:	c0 
c0020e80:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020e87:	c0 
c0020e88:	c7 44 24 08 0a d1 02 	movl   $0xc002d10a,0x8(%esp)
c0020e8f:	c0 
c0020e90:	c7 44 24 04 ae 01 00 	movl   $0x1ae,0x4(%esp)
c0020e97:	00 
c0020e98:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020e9f:	e8 1f 7b 00 00       	call   c00289c3 <debug_panic>
}
c0020ea4:	83 c4 2c             	add    $0x2c,%esp
c0020ea7:	c3                   	ret    

c0020ea8 <thread_tick>:
{
c0020ea8:	83 ec 0c             	sub    $0xc,%esp
  struct thread *t = thread_current ();
c0020eab:	e8 7d ff ff ff       	call   c0020e2d <thread_current>
  if (t == idle_thread)
c0020eb0:	3b 05 08 5c 03 c0    	cmp    0xc0035c08,%eax
c0020eb6:	75 10                	jne    c0020ec8 <thread_tick+0x20>
    idle_ticks++;
c0020eb8:	83 05 d0 5b 03 c0 01 	addl   $0x1,0xc0035bd0
c0020ebf:	83 15 d4 5b 03 c0 00 	adcl   $0x0,0xc0035bd4
c0020ec6:	eb 0e                	jmp    c0020ed6 <thread_tick+0x2e>
    kernel_ticks++;
c0020ec8:	83 05 c8 5b 03 c0 01 	addl   $0x1,0xc0035bc8
c0020ecf:	83 15 cc 5b 03 c0 00 	adcl   $0x0,0xc0035bcc
  if (++thread_ticks >= TIME_SLICE)
c0020ed6:	a1 c0 5b 03 c0       	mov    0xc0035bc0,%eax
c0020edb:	83 c0 01             	add    $0x1,%eax
c0020ede:	a3 c0 5b 03 c0       	mov    %eax,0xc0035bc0
c0020ee3:	83 f8 03             	cmp    $0x3,%eax
c0020ee6:	76 05                	jbe    c0020eed <thread_tick+0x45>
    intr_yield_on_return ();
c0020ee8:	e8 8c 0d 00 00       	call   c0021c79 <intr_yield_on_return>
}
c0020eed:	83 c4 0c             	add    $0xc,%esp
c0020ef0:	c3                   	ret    

c0020ef1 <thread_name>:
{
c0020ef1:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->name;
c0020ef4:	e8 34 ff ff ff       	call   c0020e2d <thread_current>
c0020ef9:	83 c0 08             	add    $0x8,%eax
}
c0020efc:	83 c4 0c             	add    $0xc,%esp
c0020eff:	c3                   	ret    

c0020f00 <thread_tid>:
{
c0020f00:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->tid;
c0020f03:	e8 25 ff ff ff       	call   c0020e2d <thread_current>
c0020f08:	8b 00                	mov    (%eax),%eax
}
c0020f0a:	83 c4 0c             	add    $0xc,%esp
c0020f0d:	c3                   	ret    

c0020f0e <thread_foreach>:
{
c0020f0e:	57                   	push   %edi
c0020f0f:	56                   	push   %esi
c0020f10:	53                   	push   %ebx
c0020f11:	83 ec 20             	sub    $0x20,%esp
c0020f14:	8b 74 24 30          	mov    0x30(%esp),%esi
c0020f18:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0020f1c:	e8 a3 0a 00 00       	call   c00219c4 <intr_get_level>
c0020f21:	85 c0                	test   %eax,%eax
c0020f23:	74 2c                	je     c0020f51 <thread_foreach+0x43>
c0020f25:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0020f2c:	c0 
c0020f2d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020f34:	c0 
c0020f35:	c7 44 24 08 e2 d0 02 	movl   $0xc002d0e2,0x8(%esp)
c0020f3c:	c0 
c0020f3d:	c7 44 24 04 f5 01 00 	movl   $0x1f5,0x4(%esp)
c0020f44:	00 
c0020f45:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020f4c:	e8 72 7a 00 00       	call   c00289c3 <debug_panic>
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020f51:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f58:	e8 84 7b 00 00       	call   c0028ae1 <list_begin>
c0020f5d:	89 c3                	mov    %eax,%ebx
c0020f5f:	eb 16                	jmp    c0020f77 <thread_foreach+0x69>
      func (t, aux);
c0020f61:	89 7c 24 04          	mov    %edi,0x4(%esp)
      struct thread *t = list_entry (e, struct thread, allelem);
c0020f65:	8d 43 e0             	lea    -0x20(%ebx),%eax
      func (t, aux);
c0020f68:	89 04 24             	mov    %eax,(%esp)
c0020f6b:	ff d6                	call   *%esi
       e = list_next (e))
c0020f6d:	89 1c 24             	mov    %ebx,(%esp)
c0020f70:	e8 aa 7b 00 00       	call   c0028b1f <list_next>
c0020f75:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020f77:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f7e:	e8 f0 7b 00 00       	call   c0028b73 <list_end>
c0020f83:	39 d8                	cmp    %ebx,%eax
c0020f85:	75 da                	jne    c0020f61 <thread_foreach+0x53>
}
c0020f87:	83 c4 20             	add    $0x20,%esp
c0020f8a:	5b                   	pop    %ebx
c0020f8b:	5e                   	pop    %esi
c0020f8c:	5f                   	pop    %edi
c0020f8d:	c3                   	ret    

c0020f8e <thread_get_priority>:
{
c0020f8e:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->priority;
c0020f91:	e8 97 fe ff ff       	call   c0020e2d <thread_current>
c0020f96:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0020f99:	83 c4 0c             	add    $0xc,%esp
c0020f9c:	c3                   	ret    

c0020f9d <thread_get_nice>:
{
c0020f9d:	83 ec 0c             	sub    $0xc,%esp
  return thread_current()->nice;
c0020fa0:	e8 88 fe ff ff       	call   c0020e2d <thread_current>
c0020fa5:	8b 40 54             	mov    0x54(%eax),%eax
}
c0020fa8:	83 c4 0c             	add    $0xc,%esp
c0020fab:	c3                   	ret    

c0020fac <thread_get_load_avg>:
{
c0020fac:	83 ec 04             	sub    $0x4,%esp
    return x * n;
c0020faf:	6b 05 1c 5c 03 c0 64 	imul   $0x64,0xc0035c1c,%eax
  return convertXtoIntRoundNear(i);
c0020fb6:	89 04 24             	mov    %eax,(%esp)
c0020fb9:	e8 95 f9 ff ff       	call   c0020953 <convertXtoIntRoundNear>
}
c0020fbe:	83 c4 04             	add    $0x4,%esp
c0020fc1:	c3                   	ret    

c0020fc2 <thread_get_recent_cpu>:
{
c0020fc2:	83 ec 1c             	sub    $0x1c,%esp
  int i = multXbyN(thread_current()->recent_cpu,100);
c0020fc5:	e8 63 fe ff ff       	call   c0020e2d <thread_current>
    return x * n;
c0020fca:	6b 40 58 64          	imul   $0x64,0x58(%eax),%eax
  return convertXtoIntRoundNear(i);
c0020fce:	89 04 24             	mov    %eax,(%esp)
c0020fd1:	e8 7d f9 ff ff       	call   c0020953 <convertXtoIntRoundNear>
}
c0020fd6:	83 c4 1c             	add    $0x1c,%esp
c0020fd9:	c3                   	ret    

c0020fda <calculate_recent_cpu>:
{
c0020fda:	55                   	push   %ebp
c0020fdb:	57                   	push   %edi
c0020fdc:	56                   	push   %esi
c0020fdd:	53                   	push   %ebx
c0020fde:	83 ec 2c             	sub    $0x2c,%esp
c0020fe1:	8b 7c 24 40          	mov    0x40(%esp),%edi
  int doub_load = 2 * system_load_avg;
c0020fe5:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0020fea:	8d 0c 00             	lea    (%eax,%eax,1),%ecx
    return x + (n * f);
c0020fed:	8b 35 bc 7b 03 c0    	mov    0xc0037bbc,%esi
    return ((int64_t) x) * f / y;
c0020ff3:	89 74 24 18          	mov    %esi,0x18(%esp)
c0020ff7:	89 f0                	mov    %esi,%eax
c0020ff9:	c1 f8 1f             	sar    $0x1f,%eax
c0020ffc:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0021000:	89 c8                	mov    %ecx,%eax
c0021002:	99                   	cltd   
c0021003:	89 d3                	mov    %edx,%ebx
c0021005:	0f af de             	imul   %esi,%ebx
c0021008:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002100c:	0f af c1             	imul   %ecx,%eax
c002100f:	01 c3                	add    %eax,%ebx
c0021011:	89 c8                	mov    %ecx,%eax
c0021013:	f7 e6                	mul    %esi
c0021015:	01 da                	add    %ebx,%edx
    return x + (n * f);
c0021017:	01 f1                	add    %esi,%ecx
    return ((int64_t) x) * f / y;
c0021019:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002101d:	89 cb                	mov    %ecx,%ebx
c002101f:	c1 fb 1f             	sar    $0x1f,%ebx
c0021022:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0021026:	89 04 24             	mov    %eax,(%esp)
c0021029:	89 54 24 04          	mov    %edx,0x4(%esp)
c002102d:	e8 f1 72 00 00       	call   c0028323 <__divdi3>
    return ((int64_t) x) * y / f;
c0021032:	89 c3                	mov    %eax,%ebx
c0021034:	c1 fb 1f             	sar    $0x1f,%ebx
c0021037:	8b 6f 58             	mov    0x58(%edi),%ebp
c002103a:	89 e9                	mov    %ebp,%ecx
c002103c:	c1 f9 1f             	sar    $0x1f,%ecx
c002103f:	0f af dd             	imul   %ebp,%ebx
c0021042:	89 ca                	mov    %ecx,%edx
c0021044:	0f af d0             	imul   %eax,%edx
c0021047:	8d 0c 13             	lea    (%ebx,%edx,1),%ecx
c002104a:	f7 e5                	mul    %ebp
c002104c:	01 ca                	add    %ecx,%edx
c002104e:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c0021052:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
c0021056:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002105a:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002105e:	89 04 24             	mov    %eax,(%esp)
c0021061:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021065:	e8 b9 72 00 00       	call   c0028323 <__divdi3>
    return x + (n * f);
c002106a:	0f af 77 54          	imul   0x54(%edi),%esi
c002106e:	01 f0                	add    %esi,%eax
c0021070:	89 47 58             	mov    %eax,0x58(%edi)
}
c0021073:	83 c4 2c             	add    $0x2c,%esp
c0021076:	5b                   	pop    %ebx
c0021077:	5e                   	pop    %esi
c0021078:	5f                   	pop    %edi
c0021079:	5d                   	pop    %ebp
c002107a:	c3                   	ret    

c002107b <calcPrio>:
{
c002107b:	56                   	push   %esi
c002107c:	53                   	push   %ebx
c002107d:	83 ec 14             	sub    $0x14,%esp
c0021080:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  int old_p = t->priority;
c0021084:	8b 73 1c             	mov    0x1c(%ebx),%esi
  t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0021087:	8b 43 58             	mov    0x58(%ebx),%eax
c002108a:	8d 50 03             	lea    0x3(%eax),%edx
c002108d:	85 c0                	test   %eax,%eax
c002108f:	0f 48 c2             	cmovs  %edx,%eax
c0021092:	c1 f8 02             	sar    $0x2,%eax
c0021095:	89 04 24             	mov    %eax,(%esp)
c0021098:	e8 b6 f8 ff ff       	call   c0020953 <convertXtoIntRoundNear>
c002109d:	ba 3f 00 00 00       	mov    $0x3f,%edx
c00210a2:	29 c2                	sub    %eax,%edx
c00210a4:	89 d0                	mov    %edx,%eax
c00210a6:	8b 53 54             	mov    0x54(%ebx),%edx
c00210a9:	f7 da                	neg    %edx
c00210ab:	8d 04 50             	lea    (%eax,%edx,2),%eax
  if(t->priority > PRI_MAX)
c00210ae:	83 f8 3f             	cmp    $0x3f,%eax
c00210b1:	7e 09                	jle    c00210bc <calcPrio+0x41>
    t->priority = PRI_MAX;
c00210b3:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c00210ba:	eb 0d                	jmp    c00210c9 <calcPrio+0x4e>
  t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c00210bc:	85 c0                	test   %eax,%eax
c00210be:	ba 00 00 00 00       	mov    $0x0,%edx
c00210c3:	0f 48 c2             	cmovs  %edx,%eax
c00210c6:	89 43 1c             	mov    %eax,0x1c(%ebx)
  if(old_p != t->priority && t->status == THREAD_READY)
c00210c9:	39 73 1c             	cmp    %esi,0x1c(%ebx)
c00210cc:	74 28                	je     c00210f6 <calcPrio+0x7b>
c00210ce:	83 7b 04 01          	cmpl   $0x1,0x4(%ebx)
c00210d2:	75 22                	jne    c00210f6 <calcPrio+0x7b>
     list_remove(&t->elem);
c00210d4:	8d 73 28             	lea    0x28(%ebx),%esi
c00210d7:	89 34 24             	mov    %esi,(%esp)
c00210da:	e8 55 7f 00 00       	call   c0029034 <list_remove>
     list_push_back (&mlfqs_list[t->priority], &t->elem);
c00210df:	89 74 24 04          	mov    %esi,0x4(%esp)
c00210e3:	8b 43 1c             	mov    0x1c(%ebx),%eax
c00210e6:	c1 e0 04             	shl    $0x4,%eax
c00210e9:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c00210ee:	89 04 24             	mov    %eax,(%esp)
c00210f1:	e8 1b 7f 00 00       	call   c0029011 <list_push_back>
}
c00210f6:	83 c4 14             	add    $0x14,%esp
c00210f9:	5b                   	pop    %ebx
c00210fa:	5e                   	pop    %esi
c00210fb:	c3                   	ret    

c00210fc <get_ready_threads>:
{
c00210fc:	57                   	push   %edi
c00210fd:	56                   	push   %esi
c00210fe:	53                   	push   %ebx
c00210ff:	83 ec 10             	sub    $0x10,%esp
c0021102:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0021107:	bf 20 60 03 c0       	mov    $0xc0036020,%edi
  int i,ready_threads = 0;
c002110c:	be 00 00 00 00       	mov    $0x0,%esi
     ready_threads += list_size(&mlfqs_list[i]);
c0021111:	89 1c 24             	mov    %ebx,(%esp)
c0021114:	e8 70 7f 00 00       	call   c0029089 <list_size>
c0021119:	01 c6                	add    %eax,%esi
c002111b:	83 c3 10             	add    $0x10,%ebx
  for(i=0;i<64;i++)
c002111e:	39 fb                	cmp    %edi,%ebx
c0021120:	75 ef                	jne    c0021111 <get_ready_threads+0x15>
  asm ("mov %%esp, %0" : "=g" (esp));
c0021122:	89 e0                	mov    %esp,%eax
c0021124:	25 00 f0 ff ff       	and    $0xfffff000,%eax
     ready_threads += 1;
c0021129:	39 05 08 5c 03 c0    	cmp    %eax,0xc0035c08
c002112f:	0f 95 c0             	setne  %al
c0021132:	0f b6 c0             	movzbl %al,%eax
c0021135:	01 c6                	add    %eax,%esi
}
c0021137:	89 f0                	mov    %esi,%eax
c0021139:	83 c4 10             	add    $0x10,%esp
c002113c:	5b                   	pop    %ebx
c002113d:	5e                   	pop    %esi
c002113e:	5f                   	pop    %edi
c002113f:	c3                   	ret    

c0021140 <getLoadAv>:
}
c0021140:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0021145:	c3                   	ret    

c0021146 <setLoadAv>:
  system_load_avg = load;
c0021146:	8b 44 24 04          	mov    0x4(%esp),%eax
c002114a:	a3 1c 5c 03 c0       	mov    %eax,0xc0035c1c
c002114f:	c3                   	ret    

c0021150 <get_idle_thread>:
}
c0021150:	a1 08 5c 03 c0       	mov    0xc0035c08,%eax
c0021155:	c3                   	ret    

c0021156 <thread_schedule_tail>:
{
c0021156:	56                   	push   %esi
c0021157:	53                   	push   %ebx
c0021158:	83 ec 24             	sub    $0x24,%esp
c002115b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  asm ("mov %%esp, %0" : "=g" (esp));
c002115f:	89 e6                	mov    %esp,%esi
c0021161:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
  ASSERT (intr_get_level () == INTR_OFF);
c0021167:	e8 58 08 00 00       	call   c00219c4 <intr_get_level>
c002116c:	85 c0                	test   %eax,%eax
c002116e:	74 2c                	je     c002119c <thread_schedule_tail+0x46>
c0021170:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0021177:	c0 
c0021178:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002117f:	c0 
c0021180:	c7 44 24 08 b9 d0 02 	movl   $0xc002d0b9,0x8(%esp)
c0021187:	c0 
c0021188:	c7 44 24 04 74 03 00 	movl   $0x374,0x4(%esp)
c002118f:	00 
c0021190:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021197:	e8 27 78 00 00       	call   c00289c3 <debug_panic>
  cur->status = THREAD_RUNNING;
c002119c:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
  thread_ticks = 0;
c00211a3:	c7 05 c0 5b 03 c0 00 	movl   $0x0,0xc0035bc0
c00211aa:	00 00 00 
  if (prev != NULL && prev->status == THREAD_DYING && prev != initial_thread) 
c00211ad:	85 db                	test   %ebx,%ebx
c00211af:	74 46                	je     c00211f7 <thread_schedule_tail+0xa1>
c00211b1:	83 7b 04 03          	cmpl   $0x3,0x4(%ebx)
c00211b5:	75 40                	jne    c00211f7 <thread_schedule_tail+0xa1>
c00211b7:	3b 1d 04 5c 03 c0    	cmp    0xc0035c04,%ebx
c00211bd:	74 38                	je     c00211f7 <thread_schedule_tail+0xa1>
      ASSERT (prev != cur);
c00211bf:	39 f3                	cmp    %esi,%ebx
c00211c1:	75 2c                	jne    c00211ef <thread_schedule_tail+0x99>
c00211c3:	c7 44 24 10 a7 e5 02 	movl   $0xc002e5a7,0x10(%esp)
c00211ca:	c0 
c00211cb:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00211d2:	c0 
c00211d3:	c7 44 24 08 b9 d0 02 	movl   $0xc002d0b9,0x8(%esp)
c00211da:	c0 
c00211db:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
c00211e2:	00 
c00211e3:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00211ea:	e8 d4 77 00 00       	call   c00289c3 <debug_panic>
      palloc_free_page (prev);
c00211ef:	89 1c 24             	mov    %ebx,(%esp)
c00211f2:	e8 e9 25 00 00       	call   c00237e0 <palloc_free_page>
}
c00211f7:	83 c4 24             	add    $0x24,%esp
c00211fa:	5b                   	pop    %ebx
c00211fb:	5e                   	pop    %esi
c00211fc:	c3                   	ret    

c00211fd <schedule>:
{
c00211fd:	57                   	push   %edi
c00211fe:	56                   	push   %esi
c00211ff:	53                   	push   %ebx
c0021200:	83 ec 20             	sub    $0x20,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0021203:	89 e7                	mov    %esp,%edi
c0021205:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
  if(thread_mlfqs)
c002120b:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0021212:	74 45                	je     c0021259 <schedule+0x5c>
c0021214:	be 10 60 03 c0       	mov    $0xc0036010,%esi
c0021219:	bb 3f 00 00 00       	mov    $0x3f,%ebx
c002121e:	eb 0b                	jmp    c002122b <schedule+0x2e>
      i--;
c0021220:	83 eb 01             	sub    $0x1,%ebx
c0021223:	83 ee 10             	sub    $0x10,%esi
    while(i>=0 && list_empty(&mlfqs_list[i]))
c0021226:	83 fb ff             	cmp    $0xffffffff,%ebx
c0021229:	74 26                	je     c0021251 <schedule+0x54>
c002122b:	89 34 24             	mov    %esi,(%esp)
c002122e:	e8 93 7e 00 00       	call   c00290c6 <list_empty>
c0021233:	84 c0                	test   %al,%al
c0021235:	75 e9                	jne    c0021220 <schedule+0x23>
    if(i>=0)
c0021237:	85 db                	test   %ebx,%ebx
c0021239:	78 16                	js     c0021251 <schedule+0x54>
      return list_entry(list_pop_front (&mlfqs_list[i]), struct thread, elem);
c002123b:	c1 e3 04             	shl    $0x4,%ebx
c002123e:	81 c3 20 5c 03 c0    	add    $0xc0035c20,%ebx
c0021244:	89 1c 24             	mov    %ebx,(%esp)
c0021247:	e8 e8 7e 00 00       	call   c0029134 <list_pop_front>
c002124c:	8d 58 d8             	lea    -0x28(%eax),%ebx
c002124f:	eb 47                	jmp    c0021298 <schedule+0x9b>
      return idle_thread;
c0021251:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
c0021257:	eb 3f                	jmp    c0021298 <schedule+0x9b>
    if (list_empty (&ready_list))
c0021259:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021260:	e8 61 7e 00 00       	call   c00290c6 <list_empty>
      return idle_thread;
c0021265:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
    if (list_empty (&ready_list))
c002126b:	84 c0                	test   %al,%al
c002126d:	75 29                	jne    c0021298 <schedule+0x9b>
      struct list_elem *temp = list_max (&ready_list,threadPrioCompare,NULL); 
c002126f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0021276:	00 
c0021277:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c002127e:	c0 
c002127f:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021286:	e8 0f 84 00 00       	call   c002969a <list_max>
c002128b:	89 c3                	mov    %eax,%ebx
      list_remove(temp);
c002128d:	89 04 24             	mov    %eax,(%esp)
c0021290:	e8 9f 7d 00 00       	call   c0029034 <list_remove>
      return list_entry(temp,struct thread,elem);
c0021295:	83 eb 28             	sub    $0x28,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0021298:	e8 27 07 00 00       	call   c00219c4 <intr_get_level>
c002129d:	85 c0                	test   %eax,%eax
c002129f:	74 2c                	je     c00212cd <schedule+0xd0>
c00212a1:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00212a8:	c0 
c00212a9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00212b0:	c0 
c00212b1:	c7 44 24 08 28 d1 02 	movl   $0xc002d128,0x8(%esp)
c00212b8:	c0 
c00212b9:	c7 44 24 04 9a 03 00 	movl   $0x39a,0x4(%esp)
c00212c0:	00 
c00212c1:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00212c8:	e8 f6 76 00 00       	call   c00289c3 <debug_panic>
  ASSERT (cur->status != THREAD_RUNNING);
c00212cd:	83 7f 04 00          	cmpl   $0x0,0x4(%edi)
c00212d1:	75 2c                	jne    c00212ff <schedule+0x102>
c00212d3:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c00212da:	c0 
c00212db:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00212e2:	c0 
c00212e3:	c7 44 24 08 28 d1 02 	movl   $0xc002d128,0x8(%esp)
c00212ea:	c0 
c00212eb:	c7 44 24 04 9b 03 00 	movl   $0x39b,0x4(%esp)
c00212f2:	00 
c00212f3:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00212fa:	e8 c4 76 00 00       	call   c00289c3 <debug_panic>
  return t != NULL && t->magic == THREAD_MAGIC;
c00212ff:	85 db                	test   %ebx,%ebx
c0021301:	74 2f                	je     c0021332 <schedule+0x135>
c0021303:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c002130a:	75 26                	jne    c0021332 <schedule+0x135>
c002130c:	eb 16                	jmp    c0021324 <schedule+0x127>
    prev = switch_threads (cur, next);
c002130e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0021312:	89 3c 24             	mov    %edi,(%esp)
c0021315:	e8 23 05 00 00       	call   c002183d <switch_threads>
  thread_schedule_tail (prev);
c002131a:	89 04 24             	mov    %eax,(%esp)
c002131d:	e8 34 fe ff ff       	call   c0021156 <thread_schedule_tail>
c0021322:	eb 3a                	jmp    c002135e <schedule+0x161>
  struct thread *prev = NULL;
c0021324:	b8 00 00 00 00       	mov    $0x0,%eax
  if (cur != next)
c0021329:	39 df                	cmp    %ebx,%edi
c002132b:	74 ed                	je     c002131a <schedule+0x11d>
c002132d:	8d 76 00             	lea    0x0(%esi),%esi
c0021330:	eb dc                	jmp    c002130e <schedule+0x111>
  ASSERT (is_thread (next));
c0021332:	c7 44 24 10 d1 e5 02 	movl   $0xc002e5d1,0x10(%esp)
c0021339:	c0 
c002133a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021341:	c0 
c0021342:	c7 44 24 08 28 d1 02 	movl   $0xc002d128,0x8(%esp)
c0021349:	c0 
c002134a:	c7 44 24 04 9c 03 00 	movl   $0x39c,0x4(%esp)
c0021351:	00 
c0021352:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021359:	e8 65 76 00 00       	call   c00289c3 <debug_panic>
}
c002135e:	83 c4 20             	add    $0x20,%esp
c0021361:	5b                   	pop    %ebx
c0021362:	5e                   	pop    %esi
c0021363:	5f                   	pop    %edi
c0021364:	c3                   	ret    

c0021365 <thread_block>:
{
c0021365:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c0021368:	e8 04 09 00 00       	call   c0021c71 <intr_context>
c002136d:	84 c0                	test   %al,%al
c002136f:	74 2c                	je     c002139d <thread_block+0x38>
c0021371:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0021378:	c0 
c0021379:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021380:	c0 
c0021381:	c7 44 24 08 31 d1 02 	movl   $0xc002d131,0x8(%esp)
c0021388:	c0 
c0021389:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c0021390:	00 
c0021391:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021398:	e8 26 76 00 00       	call   c00289c3 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c002139d:	e8 22 06 00 00       	call   c00219c4 <intr_get_level>
c00213a2:	85 c0                	test   %eax,%eax
c00213a4:	74 2c                	je     c00213d2 <thread_block+0x6d>
c00213a6:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00213ad:	c0 
c00213ae:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00213b5:	c0 
c00213b6:	c7 44 24 08 31 d1 02 	movl   $0xc002d131,0x8(%esp)
c00213bd:	c0 
c00213be:	c7 44 24 04 6d 01 00 	movl   $0x16d,0x4(%esp)
c00213c5:	00 
c00213c6:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00213cd:	e8 f1 75 00 00       	call   c00289c3 <debug_panic>
  thread_current ()->status = THREAD_BLOCKED;
c00213d2:	e8 56 fa ff ff       	call   c0020e2d <thread_current>
c00213d7:	c7 40 04 02 00 00 00 	movl   $0x2,0x4(%eax)
  schedule ();
c00213de:	e8 1a fe ff ff       	call   c00211fd <schedule>
}
c00213e3:	83 c4 2c             	add    $0x2c,%esp
c00213e6:	c3                   	ret    

c00213e7 <idle>:
{
c00213e7:	83 ec 1c             	sub    $0x1c,%esp
  idle_thread = thread_current ();
c00213ea:	e8 3e fa ff ff       	call   c0020e2d <thread_current>
c00213ef:	a3 08 5c 03 c0       	mov    %eax,0xc0035c08
  sema_up (idle_started);
c00213f4:	8b 44 24 20          	mov    0x20(%esp),%eax
c00213f8:	89 04 24             	mov    %eax,(%esp)
c00213fb:	e8 97 18 00 00       	call   c0022c97 <sema_up>
      intr_disable ();
c0021400:	e8 0a 06 00 00       	call   c0021a0f <intr_disable>
      thread_block ();
c0021405:	e8 5b ff ff ff       	call   c0021365 <thread_block>
      asm volatile ("sti; hlt" : : : "memory");
c002140a:	fb                   	sti    
c002140b:	f4                   	hlt    
c002140c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0021410:	eb ee                	jmp    c0021400 <idle+0x19>

c0021412 <thread_exit>:
{
c0021412:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c0021415:	e8 57 08 00 00       	call   c0021c71 <intr_context>
c002141a:	84 c0                	test   %al,%al
c002141c:	74 2c                	je     c002144a <thread_exit+0x38>
c002141e:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0021425:	c0 
c0021426:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002142d:	c0 
c002142e:	c7 44 24 08 fe d0 02 	movl   $0xc002d0fe,0x8(%esp)
c0021435:	c0 
c0021436:	c7 44 24 04 c0 01 00 	movl   $0x1c0,0x4(%esp)
c002143d:	00 
c002143e:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021445:	e8 79 75 00 00       	call   c00289c3 <debug_panic>
  intr_disable ();
c002144a:	e8 c0 05 00 00       	call   c0021a0f <intr_disable>
  list_remove (&thread_current()->allelem);
c002144f:	e8 d9 f9 ff ff       	call   c0020e2d <thread_current>
c0021454:	83 c0 20             	add    $0x20,%eax
c0021457:	89 04 24             	mov    %eax,(%esp)
c002145a:	e8 d5 7b 00 00       	call   c0029034 <list_remove>
  thread_current ()->status = THREAD_DYING;
c002145f:	e8 c9 f9 ff ff       	call   c0020e2d <thread_current>
c0021464:	c7 40 04 03 00 00 00 	movl   $0x3,0x4(%eax)
  schedule ();
c002146b:	e8 8d fd ff ff       	call   c00211fd <schedule>
  NOT_REACHED ();
c0021470:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0021477:	c0 
c0021478:	c7 44 24 08 fe d0 02 	movl   $0xc002d0fe,0x8(%esp)
c002147f:	c0 
c0021480:	c7 44 24 04 cd 01 00 	movl   $0x1cd,0x4(%esp)
c0021487:	00 
c0021488:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c002148f:	e8 2f 75 00 00       	call   c00289c3 <debug_panic>

c0021494 <kernel_thread>:
{
c0021494:	53                   	push   %ebx
c0021495:	83 ec 28             	sub    $0x28,%esp
c0021498:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (function != NULL);
c002149c:	85 db                	test   %ebx,%ebx
c002149e:	75 2c                	jne    c00214cc <kernel_thread+0x38>
c00214a0:	c7 44 24 10 f3 e5 02 	movl   $0xc002e5f3,0x10(%esp)
c00214a7:	c0 
c00214a8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00214af:	c0 
c00214b0:	c7 44 24 08 4a d1 02 	movl   $0xc002d14a,0x8(%esp)
c00214b7:	c0 
c00214b8:	c7 44 24 04 e2 02 00 	movl   $0x2e2,0x4(%esp)
c00214bf:	00 
c00214c0:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00214c7:	e8 f7 74 00 00       	call   c00289c3 <debug_panic>
  intr_enable ();       /* The scheduler runs with interrupts off. */
c00214cc:	e8 fc 04 00 00       	call   c00219cd <intr_enable>
  function (aux);       /* Execute the thread function. */
c00214d1:	8b 44 24 34          	mov    0x34(%esp),%eax
c00214d5:	89 04 24             	mov    %eax,(%esp)
c00214d8:	ff d3                	call   *%ebx
  thread_exit ();       /* If function() returns, kill the thread. */
c00214da:	e8 33 ff ff ff       	call   c0021412 <thread_exit>

c00214df <thread_yield>:
{
c00214df:	56                   	push   %esi
c00214e0:	53                   	push   %ebx
c00214e1:	83 ec 24             	sub    $0x24,%esp
  struct thread *cur = thread_current ();
c00214e4:	e8 44 f9 ff ff       	call   c0020e2d <thread_current>
c00214e9:	89 c3                	mov    %eax,%ebx
  ASSERT (!intr_context ());
c00214eb:	e8 81 07 00 00       	call   c0021c71 <intr_context>
c00214f0:	84 c0                	test   %al,%al
c00214f2:	74 2c                	je     c0021520 <thread_yield+0x41>
c00214f4:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c00214fb:	c0 
c00214fc:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021503:	c0 
c0021504:	c7 44 24 08 f1 d0 02 	movl   $0xc002d0f1,0x8(%esp)
c002150b:	c0 
c002150c:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
c0021513:	00 
c0021514:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c002151b:	e8 a3 74 00 00       	call   c00289c3 <debug_panic>
  old_level = intr_disable ();
c0021520:	e8 ea 04 00 00       	call   c0021a0f <intr_disable>
c0021525:	89 c6                	mov    %eax,%esi
  if (cur != idle_thread) 
c0021527:	3b 1d 08 5c 03 c0    	cmp    0xc0035c08,%ebx
c002152d:	74 38                	je     c0021567 <thread_yield+0x88>
    if(thread_mlfqs) {
c002152f:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0021536:	74 1c                	je     c0021554 <thread_yield+0x75>
      list_push_back (&mlfqs_list[cur->priority], &cur->elem);
c0021538:	8d 43 28             	lea    0x28(%ebx),%eax
c002153b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002153f:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021542:	c1 e0 04             	shl    $0x4,%eax
c0021545:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c002154a:	89 04 24             	mov    %eax,(%esp)
c002154d:	e8 bf 7a 00 00       	call   c0029011 <list_push_back>
c0021552:	eb 13                	jmp    c0021567 <thread_yield+0x88>
      list_push_back (&ready_list, &cur->elem);
c0021554:	8d 43 28             	lea    0x28(%ebx),%eax
c0021557:	89 44 24 04          	mov    %eax,0x4(%esp)
c002155b:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021562:	e8 aa 7a 00 00       	call   c0029011 <list_push_back>
  cur->status = THREAD_READY;
c0021567:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  schedule ();
c002156e:	e8 8a fc ff ff       	call   c00211fd <schedule>
  intr_set_level (old_level);
c0021573:	89 34 24             	mov    %esi,(%esp)
c0021576:	e8 9b 04 00 00       	call   c0021a16 <intr_set_level>
}
c002157b:	83 c4 24             	add    $0x24,%esp
c002157e:	5b                   	pop    %ebx
c002157f:	5e                   	pop    %esi
c0021580:	c3                   	ret    

c0021581 <thread_create>:
{
c0021581:	55                   	push   %ebp
c0021582:	57                   	push   %edi
c0021583:	56                   	push   %esi
c0021584:	53                   	push   %ebx
c0021585:	83 ec 2c             	sub    $0x2c,%esp
c0021588:	8b 7c 24 48          	mov    0x48(%esp),%edi
  ASSERT (function != NULL);
c002158c:	85 ff                	test   %edi,%edi
c002158e:	75 2c                	jne    c00215bc <thread_create+0x3b>
c0021590:	c7 44 24 10 f3 e5 02 	movl   $0xc002e5f3,0x10(%esp)
c0021597:	c0 
c0021598:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002159f:	c0 
c00215a0:	c7 44 24 08 58 d1 02 	movl   $0xc002d158,0x8(%esp)
c00215a7:	c0 
c00215a8:	c7 44 24 04 2f 01 00 	movl   $0x12f,0x4(%esp)
c00215af:	00 
c00215b0:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00215b7:	e8 07 74 00 00       	call   c00289c3 <debug_panic>
  t = palloc_get_page (PAL_ZERO);
c00215bc:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00215c3:	e8 ae 20 00 00       	call   c0023676 <palloc_get_page>
c00215c8:	89 c3                	mov    %eax,%ebx
  if (t == NULL)
c00215ca:	85 c0                	test   %eax,%eax
c00215cc:	0f 84 c4 00 00 00    	je     c0021696 <thread_create+0x115>
  t->nice = thread_current()->nice; //get parent's nice value
c00215d2:	e8 56 f8 ff ff       	call   c0020e2d <thread_current>
c00215d7:	8b 40 54             	mov    0x54(%eax),%eax
c00215da:	89 43 54             	mov    %eax,0x54(%ebx)
  t->recent_cpu = thread_current()->recent_cpu; //get parent's recent_cpu value
c00215dd:	e8 4b f8 ff ff       	call   c0020e2d <thread_current>
c00215e2:	8b 40 58             	mov    0x58(%eax),%eax
c00215e5:	89 43 58             	mov    %eax,0x58(%ebx)
  init_thread (t, name, priority);
c00215e8:	8b 4c 24 44          	mov    0x44(%esp),%ecx
c00215ec:	8b 54 24 40          	mov    0x40(%esp),%edx
c00215f0:	89 d8                	mov    %ebx,%eax
c00215f2:	e8 8e f3 ff ff       	call   c0020985 <init_thread>
  lock_acquire (&tid_lock);
c00215f7:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c00215fe:	e8 a7 18 00 00       	call   c0022eaa <lock_acquire>
  tid = next_tid++;
c0021603:	8b 35 54 56 03 c0    	mov    0xc0035654,%esi
c0021609:	8d 46 01             	lea    0x1(%esi),%eax
c002160c:	a3 54 56 03 c0       	mov    %eax,0xc0035654
  lock_release (&tid_lock);
c0021611:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0021618:	e8 57 1a 00 00       	call   c0023074 <lock_release>
  tid = t->tid = allocate_tid ();
c002161d:	89 33                	mov    %esi,(%ebx)
  old_level = intr_disable ();
c002161f:	e8 eb 03 00 00       	call   c0021a0f <intr_disable>
c0021624:	89 c5                	mov    %eax,%ebp
  kf = alloc_frame (t, sizeof *kf);
c0021626:	ba 0c 00 00 00       	mov    $0xc,%edx
c002162b:	89 d8                	mov    %ebx,%eax
c002162d:	e8 30 f2 ff ff       	call   c0020862 <alloc_frame>
  kf->eip = NULL;
c0021632:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  kf->function = function;
c0021638:	89 78 04             	mov    %edi,0x4(%eax)
  kf->aux = aux;
c002163b:	8b 54 24 4c          	mov    0x4c(%esp),%edx
c002163f:	89 50 08             	mov    %edx,0x8(%eax)
  ef = alloc_frame (t, sizeof *ef);
c0021642:	ba 04 00 00 00       	mov    $0x4,%edx
c0021647:	89 d8                	mov    %ebx,%eax
c0021649:	e8 14 f2 ff ff       	call   c0020862 <alloc_frame>
  ef->eip = (void (*) (void)) kernel_thread;
c002164e:	c7 00 94 14 02 c0    	movl   $0xc0021494,(%eax)
  sf = alloc_frame (t, sizeof *sf);
c0021654:	ba 1c 00 00 00       	mov    $0x1c,%edx
c0021659:	89 d8                	mov    %ebx,%eax
c002165b:	e8 02 f2 ff ff       	call   c0020862 <alloc_frame>
  sf->eip = switch_entry;
c0021660:	c7 40 10 5a 18 02 c0 	movl   $0xc002185a,0x10(%eax)
  sf->ebp = 0;
c0021667:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
  intr_set_level (old_level);
c002166e:	89 2c 24             	mov    %ebp,(%esp)
c0021671:	e8 a0 03 00 00       	call   c0021a16 <intr_set_level>
  thread_unblock (t);
c0021676:	89 1c 24             	mov    %ebx,(%esp)
c0021679:	e8 d6 f6 ff ff       	call   c0020d54 <thread_unblock>
  if(t->priority > thread_current()->priority)
c002167e:	e8 aa f7 ff ff       	call   c0020e2d <thread_current>
  return tid;
c0021683:	89 f2                	mov    %esi,%edx
  if(t->priority > thread_current()->priority)
c0021685:	8b 40 1c             	mov    0x1c(%eax),%eax
c0021688:	39 43 1c             	cmp    %eax,0x1c(%ebx)
c002168b:	7e 0e                	jle    c002169b <thread_create+0x11a>
    thread_yield();
c002168d:	e8 4d fe ff ff       	call   c00214df <thread_yield>
  return tid;
c0021692:	89 f2                	mov    %esi,%edx
c0021694:	eb 05                	jmp    c002169b <thread_create+0x11a>
    return TID_ERROR;
c0021696:	ba ff ff ff ff       	mov    $0xffffffff,%edx
}
c002169b:	89 d0                	mov    %edx,%eax
c002169d:	83 c4 2c             	add    $0x2c,%esp
c00216a0:	5b                   	pop    %ebx
c00216a1:	5e                   	pop    %esi
c00216a2:	5f                   	pop    %edi
c00216a3:	5d                   	pop    %ebp
c00216a4:	c3                   	ret    

c00216a5 <thread_start>:
{
c00216a5:	53                   	push   %ebx
c00216a6:	83 ec 38             	sub    $0x38,%esp
  sema_init (&idle_started, 0);
c00216a9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00216b0:	00 
c00216b1:	8d 5c 24 1c          	lea    0x1c(%esp),%ebx
c00216b5:	89 1c 24             	mov    %ebx,(%esp)
c00216b8:	e8 79 14 00 00       	call   c0022b36 <sema_init>
  thread_create ("idle", PRI_MIN, idle, &idle_started);
c00216bd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c00216c1:	c7 44 24 08 e7 13 02 	movl   $0xc00213e7,0x8(%esp)
c00216c8:	c0 
c00216c9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00216d0:	00 
c00216d1:	c7 04 24 04 e6 02 c0 	movl   $0xc002e604,(%esp)
c00216d8:	e8 a4 fe ff ff       	call   c0021581 <thread_create>
  intr_enable ();
c00216dd:	e8 eb 02 00 00       	call   c00219cd <intr_enable>
  sema_down (&idle_started);
c00216e2:	89 1c 24             	mov    %ebx,(%esp)
c00216e5:	e8 98 14 00 00       	call   c0022b82 <sema_down>
}
c00216ea:	83 c4 38             	add    $0x38,%esp
c00216ed:	5b                   	pop    %ebx
c00216ee:	c3                   	ret    

c00216ef <thread_set_priority>:
{
c00216ef:	56                   	push   %esi
c00216f0:	53                   	push   %ebx
c00216f1:	83 ec 24             	sub    $0x24,%esp
c00216f4:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT(thread_mlfqs == false);
c00216f8:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c00216ff:	74 2c                	je     c002172d <thread_set_priority+0x3e>
c0021701:	c7 44 24 10 09 e6 02 	movl   $0xc002e609,0x10(%esp)
c0021708:	c0 
c0021709:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021710:	c0 
c0021711:	c7 44 24 08 ce d0 02 	movl   $0xc002d0ce,0x8(%esp)
c0021718:	c0 
c0021719:	c7 44 24 04 04 02 00 	movl   $0x204,0x4(%esp)
c0021720:	00 
c0021721:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021728:	e8 96 72 00 00       	call   c00289c3 <debug_panic>
  old_level = intr_disable ();
c002172d:	e8 dd 02 00 00       	call   c0021a0f <intr_disable>
c0021732:	89 c6                	mov    %eax,%esi
  if(new_priority >= PRI_MIN && new_priority <= PRI_MAX) //REMOVE COMMENT: flipped this
c0021734:	83 fb 3f             	cmp    $0x3f,%ebx
c0021737:	77 68                	ja     c00217a1 <thread_set_priority+0xb2>
    if(new_priority > thread_current ()->priority)
c0021739:	e8 ef f6 ff ff       	call   c0020e2d <thread_current>
c002173e:	89 c2                	mov    %eax,%edx
c0021740:	8b 40 1c             	mov    0x1c(%eax),%eax
c0021743:	39 c3                	cmp    %eax,%ebx
c0021745:	7e 0d                	jle    c0021754 <thread_set_priority+0x65>
      thread_current ()->priority = new_priority;
c0021747:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c002174a:	e8 de f6 ff ff       	call   c0020e2d <thread_current>
c002174f:	89 58 3c             	mov    %ebx,0x3c(%eax)
c0021752:	eb 15                	jmp    c0021769 <thread_set_priority+0x7a>
    else if(thread_current ()->priority == thread_current ()->old_priority)
c0021754:	3b 42 3c             	cmp    0x3c(%edx),%eax
c0021757:	75 0d                	jne    c0021766 <thread_set_priority+0x77>
      thread_current ()->priority = new_priority;
c0021759:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c002175c:	e8 cc f6 ff ff       	call   c0020e2d <thread_current>
c0021761:	89 58 3c             	mov    %ebx,0x3c(%eax)
c0021764:	eb 03                	jmp    c0021769 <thread_set_priority+0x7a>
      thread_current ()->old_priority = new_priority;
c0021766:	89 5a 3c             	mov    %ebx,0x3c(%edx)
    intr_set_level (old_level);
c0021769:	89 34 24             	mov    %esi,(%esp)
c002176c:	e8 a5 02 00 00       	call   c0021a16 <intr_set_level>
    t = list_entry(list_max (&ready_list,threadPrioCompare,NULL),struct thread,elem)->priority;
c0021771:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0021778:	00 
c0021779:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c0021780:	c0 
c0021781:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021788:	e8 0d 7f 00 00       	call   c002969a <list_max>
c002178d:	89 c3                	mov    %eax,%ebx
    if(t > thread_current ()->priority)
c002178f:	e8 99 f6 ff ff       	call   c0020e2d <thread_current>
c0021794:	8b 40 1c             	mov    0x1c(%eax),%eax
c0021797:	39 43 f4             	cmp    %eax,-0xc(%ebx)
c002179a:	7e 05                	jle    c00217a1 <thread_set_priority+0xb2>
      thread_yield();
c002179c:	e8 3e fd ff ff       	call   c00214df <thread_yield>
}
c00217a1:	83 c4 24             	add    $0x24,%esp
c00217a4:	5b                   	pop    %ebx
c00217a5:	5e                   	pop    %esi
c00217a6:	c3                   	ret    

c00217a7 <thread_set_nice>:
{
c00217a7:	57                   	push   %edi
c00217a8:	56                   	push   %esi
c00217a9:	53                   	push   %ebx
c00217aa:	83 ec 10             	sub    $0x10,%esp
c00217ad:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread *curr_thread = thread_current();
c00217b1:	e8 77 f6 ff ff       	call   c0020e2d <thread_current>
c00217b6:	89 c7                	mov    %eax,%edi
  if(nice >= -20 && nice <= 20)
c00217b8:	8d 43 14             	lea    0x14(%ebx),%eax
c00217bb:	83 f8 28             	cmp    $0x28,%eax
c00217be:	77 03                	ja     c00217c3 <thread_set_nice+0x1c>
    curr_thread->nice = nice;
c00217c0:	89 5f 54             	mov    %ebx,0x54(%edi)
  curr_thread->priority = PRI_MAX - convertXtoIntRoundNear(curr_thread->recent_cpu / 4) - (curr_thread->nice * 2);
c00217c3:	8b 47 58             	mov    0x58(%edi),%eax
c00217c6:	8d 50 03             	lea    0x3(%eax),%edx
c00217c9:	85 c0                	test   %eax,%eax
c00217cb:	0f 48 c2             	cmovs  %edx,%eax
c00217ce:	c1 f8 02             	sar    $0x2,%eax
c00217d1:	89 04 24             	mov    %eax,(%esp)
c00217d4:	e8 7a f1 ff ff       	call   c0020953 <convertXtoIntRoundNear>
c00217d9:	ba 3f 00 00 00       	mov    $0x3f,%edx
c00217de:	29 c2                	sub    %eax,%edx
c00217e0:	89 d0                	mov    %edx,%eax
c00217e2:	8b 57 54             	mov    0x54(%edi),%edx
c00217e5:	f7 da                	neg    %edx
c00217e7:	8d 04 50             	lea    (%eax,%edx,2),%eax
  if(curr_thread->priority > PRI_MAX)
c00217ea:	83 f8 3f             	cmp    $0x3f,%eax
c00217ed:	7e 09                	jle    c00217f8 <thread_set_nice+0x51>
    curr_thread->priority = PRI_MAX;
c00217ef:	c7 47 1c 3f 00 00 00 	movl   $0x3f,0x1c(%edi)
c00217f6:	eb 32                	jmp    c002182a <thread_set_nice+0x83>
    curr_thread->priority = PRI_MIN;
c00217f8:	85 c0                	test   %eax,%eax
c00217fa:	ba 00 00 00 00       	mov    $0x0,%edx
c00217ff:	0f 48 c2             	cmovs  %edx,%eax
c0021802:	89 47 1c             	mov    %eax,0x1c(%edi)
c0021805:	eb 23                	jmp    c002182a <thread_set_nice+0x83>
    if(list_empty(&mlfqs_list[i]) && curr_thread->priority > i){
c0021807:	89 34 24             	mov    %esi,(%esp)
c002180a:	e8 b7 78 00 00       	call   c00290c6 <list_empty>
c002180f:	84 c0                	test   %al,%al
c0021811:	74 0a                	je     c002181d <thread_set_nice+0x76>
c0021813:	39 5f 1c             	cmp    %ebx,0x1c(%edi)
c0021816:	7e 05                	jle    c002181d <thread_set_nice+0x76>
      thread_yield();  
c0021818:	e8 c2 fc ff ff       	call   c00214df <thread_yield>
  for(i = 0; i < 64; i++){
c002181d:	83 c3 01             	add    $0x1,%ebx
c0021820:	83 c6 10             	add    $0x10,%esi
c0021823:	83 fb 40             	cmp    $0x40,%ebx
c0021826:	75 df                	jne    c0021807 <thread_set_nice+0x60>
c0021828:	eb 0c                	jmp    c0021836 <thread_set_nice+0x8f>
c002182a:	be 20 5c 03 c0       	mov    $0xc0035c20,%esi
{
c002182f:	bb 00 00 00 00       	mov    $0x0,%ebx
c0021834:	eb d1                	jmp    c0021807 <thread_set_nice+0x60>
}
c0021836:	83 c4 10             	add    $0x10,%esp
c0021839:	5b                   	pop    %ebx
c002183a:	5e                   	pop    %esi
c002183b:	5f                   	pop    %edi
c002183c:	c3                   	ret    

c002183d <switch_threads>:
	# but requires us to preserve %ebx, %ebp, %esi, %edi.  See
	# [SysV-ABI-386] pages 3-11 and 3-12 for details.
	#
	# This stack frame must match the one set up by thread_create()
	# in size.
	pushl %ebx
c002183d:	53                   	push   %ebx
	pushl %ebp
c002183e:	55                   	push   %ebp
	pushl %esi
c002183f:	56                   	push   %esi
	pushl %edi
c0021840:	57                   	push   %edi

	# Get offsetof (struct thread, stack).
.globl thread_stack_ofs
	mov thread_stack_ofs, %edx
c0021841:	8b 15 58 56 03 c0    	mov    0xc0035658,%edx

	# Save current stack pointer to old thread's stack, if any.
	movl SWITCH_CUR(%esp), %eax
c0021847:	8b 44 24 14          	mov    0x14(%esp),%eax
	movl %esp, (%eax,%edx,1)
c002184b:	89 24 10             	mov    %esp,(%eax,%edx,1)

	# Restore stack pointer from new thread's stack.
	movl SWITCH_NEXT(%esp), %ecx
c002184e:	8b 4c 24 18          	mov    0x18(%esp),%ecx
	movl (%ecx,%edx,1), %esp
c0021852:	8b 24 11             	mov    (%ecx,%edx,1),%esp

	# Restore caller's register state.
	popl %edi
c0021855:	5f                   	pop    %edi
	popl %esi
c0021856:	5e                   	pop    %esi
	popl %ebp
c0021857:	5d                   	pop    %ebp
	popl %ebx
c0021858:	5b                   	pop    %ebx
        ret
c0021859:	c3                   	ret    

c002185a <switch_entry>:

.globl switch_entry
.func switch_entry
switch_entry:
	# Discard switch_threads() arguments.
	addl $8, %esp
c002185a:	83 c4 08             	add    $0x8,%esp

	# Call thread_schedule_tail(prev).
	pushl %eax
c002185d:	50                   	push   %eax
.globl thread_schedule_tail
	call thread_schedule_tail
c002185e:	e8 f3 f8 ff ff       	call   c0021156 <thread_schedule_tail>
	addl $4, %esp
c0021863:	83 c4 04             	add    $0x4,%esp

	# Start thread proper.
	ret
c0021866:	c3                   	ret    
c0021867:	90                   	nop
c0021868:	90                   	nop
c0021869:	90                   	nop
c002186a:	90                   	nop
c002186b:	90                   	nop
c002186c:	90                   	nop
c002186d:	90                   	nop
c002186e:	90                   	nop
c002186f:	90                   	nop

c0021870 <make_gate>:
   disables interrupts, but entering a trap gate does not.  See
   [IA32-v3a] section 5.12.1.2 "Flag Usage By Exception- or
   Interrupt-Handler Procedure" for discussion. */
static uint64_t
make_gate (void (*function) (void), int dpl, int type)
{
c0021870:	53                   	push   %ebx
c0021871:	83 ec 28             	sub    $0x28,%esp
  uint32_t e0, e1;

  ASSERT (function != NULL);
c0021874:	85 c0                	test   %eax,%eax
c0021876:	75 2c                	jne    c00218a4 <make_gate+0x34>
c0021878:	c7 44 24 10 f3 e5 02 	movl   $0xc002e5f3,0x10(%esp)
c002187f:	c0 
c0021880:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021887:	c0 
c0021888:	c7 44 24 08 ea d1 02 	movl   $0xc002d1ea,0x8(%esp)
c002188f:	c0 
c0021890:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0021897:	00 
c0021898:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c002189f:	e8 1f 71 00 00       	call   c00289c3 <debug_panic>
  ASSERT (dpl >= 0 && dpl <= 3);
c00218a4:	83 fa 03             	cmp    $0x3,%edx
c00218a7:	76 2c                	jbe    c00218d5 <make_gate+0x65>
c00218a9:	c7 44 24 10 c8 e6 02 	movl   $0xc002e6c8,0x10(%esp)
c00218b0:	c0 
c00218b1:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00218b8:	c0 
c00218b9:	c7 44 24 08 ea d1 02 	movl   $0xc002d1ea,0x8(%esp)
c00218c0:	c0 
c00218c1:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c00218c8:	00 
c00218c9:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c00218d0:	e8 ee 70 00 00       	call   c00289c3 <debug_panic>
  ASSERT (type >= 0 && type <= 15);
c00218d5:	83 f9 0f             	cmp    $0xf,%ecx
c00218d8:	76 2c                	jbe    c0021906 <make_gate+0x96>
c00218da:	c7 44 24 10 dd e6 02 	movl   $0xc002e6dd,0x10(%esp)
c00218e1:	c0 
c00218e2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00218e9:	c0 
c00218ea:	c7 44 24 08 ea d1 02 	movl   $0xc002d1ea,0x8(%esp)
c00218f1:	c0 
c00218f2:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
c00218f9:	00 
c00218fa:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021901:	e8 bd 70 00 00       	call   c00289c3 <debug_panic>

  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
        | (1 << 15)                        /* Present. */
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
        | (0 << 12)                        /* System. */
        | ((uint32_t) type << 8));         /* Gate type. */
c0021906:	c1 e1 08             	shl    $0x8,%ecx
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
c0021909:	80 cd 80             	or     $0x80,%ch
c002190c:	89 d3                	mov    %edx,%ebx
c002190e:	c1 e3 0d             	shl    $0xd,%ebx
        | ((uint32_t) type << 8));         /* Gate type. */
c0021911:	09 d9                	or     %ebx,%ecx
c0021913:	89 ca                	mov    %ecx,%edx
  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
c0021915:	89 c3                	mov    %eax,%ebx
c0021917:	66 bb 00 00          	mov    $0x0,%bx
c002191b:	09 da                	or     %ebx,%edx
  e0 = (((uint32_t) function & 0xffff)     /* Offset 15:0. */
c002191d:	0f b7 c0             	movzwl %ax,%eax
c0021920:	0d 00 00 08 00       	or     $0x80000,%eax

  return e0 | ((uint64_t) e1 << 32);
}
c0021925:	83 c4 28             	add    $0x28,%esp
c0021928:	5b                   	pop    %ebx
c0021929:	c3                   	ret    

c002192a <register_handler>:
{
c002192a:	53                   	push   %ebx
c002192b:	83 ec 28             	sub    $0x28,%esp
  ASSERT (intr_handlers[vec_no] == NULL);
c002192e:	0f b6 d8             	movzbl %al,%ebx
c0021931:	83 3c 9d 60 68 03 c0 	cmpl   $0x0,-0x3ffc97a0(,%ebx,4)
c0021938:	00 
c0021939:	74 2c                	je     c0021967 <register_handler+0x3d>
c002193b:	c7 44 24 10 f5 e6 02 	movl   $0xc002e6f5,0x10(%esp)
c0021942:	c0 
c0021943:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002194a:	c0 
c002194b:	c7 44 24 08 c7 d1 02 	movl   $0xc002d1c7,0x8(%esp)
c0021952:	c0 
c0021953:	c7 44 24 04 a8 00 00 	movl   $0xa8,0x4(%esp)
c002195a:	00 
c002195b:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021962:	e8 5c 70 00 00       	call   c00289c3 <debug_panic>
  if (level == INTR_ON)
c0021967:	83 f9 01             	cmp    $0x1,%ecx
c002196a:	75 1e                	jne    c002198a <register_handler+0x60>
/* Creates a trap gate that invokes FUNCTION with the given
   DPL. */
static uint64_t
make_trap_gate (void (*function) (void), int dpl)
{
  return make_gate (function, dpl, 15);
c002196c:	8b 04 9d 5c 56 03 c0 	mov    -0x3ffca9a4(,%ebx,4),%eax
c0021973:	b1 0f                	mov    $0xf,%cl
c0021975:	e8 f6 fe ff ff       	call   c0021870 <make_gate>
    idt[vec_no] = make_trap_gate (intr_stubs[vec_no], dpl);
c002197a:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021981:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
c0021988:	eb 1f                	jmp    c00219a9 <register_handler+0x7f>
  return make_gate (function, dpl, 14);
c002198a:	8b 04 9d 5c 56 03 c0 	mov    -0x3ffca9a4(,%ebx,4),%eax
c0021991:	b9 0e 00 00 00       	mov    $0xe,%ecx
c0021996:	e8 d5 fe ff ff       	call   c0021870 <make_gate>
    idt[vec_no] = make_intr_gate (intr_stubs[vec_no], dpl);
c002199b:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c00219a2:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  intr_handlers[vec_no] = handler;
c00219a9:	8b 44 24 30          	mov    0x30(%esp),%eax
c00219ad:	89 04 9d 60 68 03 c0 	mov    %eax,-0x3ffc97a0(,%ebx,4)
  intr_names[vec_no] = name;
c00219b4:	8b 44 24 34          	mov    0x34(%esp),%eax
c00219b8:	89 04 9d 60 64 03 c0 	mov    %eax,-0x3ffc9ba0(,%ebx,4)
}
c00219bf:	83 c4 28             	add    $0x28,%esp
c00219c2:	5b                   	pop    %ebx
c00219c3:	c3                   	ret    

c00219c4 <intr_get_level>:
  asm volatile ("pushfl; popl %0" : "=g" (flags));
c00219c4:	9c                   	pushf  
c00219c5:	58                   	pop    %eax
  return flags & FLAG_IF ? INTR_ON : INTR_OFF;
c00219c6:	c1 e8 09             	shr    $0x9,%eax
c00219c9:	83 e0 01             	and    $0x1,%eax
}
c00219cc:	c3                   	ret    

c00219cd <intr_enable>:
{
c00219cd:	83 ec 2c             	sub    $0x2c,%esp
  enum intr_level old_level = intr_get_level ();
c00219d0:	e8 ef ff ff ff       	call   c00219c4 <intr_get_level>
  ASSERT (!intr_context ());
c00219d5:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c00219dc:	74 2c                	je     c0021a0a <intr_enable+0x3d>
c00219de:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c00219e5:	c0 
c00219e6:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00219ed:	c0 
c00219ee:	c7 44 24 08 f4 d1 02 	movl   $0xc002d1f4,0x8(%esp)
c00219f5:	c0 
c00219f6:	c7 44 24 04 5b 00 00 	movl   $0x5b,0x4(%esp)
c00219fd:	00 
c00219fe:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021a05:	e8 b9 6f 00 00       	call   c00289c3 <debug_panic>
  asm volatile ("sti");
c0021a0a:	fb                   	sti    
}
c0021a0b:	83 c4 2c             	add    $0x2c,%esp
c0021a0e:	c3                   	ret    

c0021a0f <intr_disable>:
  enum intr_level old_level = intr_get_level ();
c0021a0f:	e8 b0 ff ff ff       	call   c00219c4 <intr_get_level>
  asm volatile ("cli" : : : "memory");
c0021a14:	fa                   	cli    
}
c0021a15:	c3                   	ret    

c0021a16 <intr_set_level>:
{
c0021a16:	83 ec 0c             	sub    $0xc,%esp
  return level == INTR_ON ? intr_enable () : intr_disable ();
c0021a19:	83 7c 24 10 01       	cmpl   $0x1,0x10(%esp)
c0021a1e:	75 07                	jne    c0021a27 <intr_set_level+0x11>
c0021a20:	e8 a8 ff ff ff       	call   c00219cd <intr_enable>
c0021a25:	eb 05                	jmp    c0021a2c <intr_set_level+0x16>
c0021a27:	e8 e3 ff ff ff       	call   c0021a0f <intr_disable>
}
c0021a2c:	83 c4 0c             	add    $0xc,%esp
c0021a2f:	90                   	nop
c0021a30:	c3                   	ret    

c0021a31 <intr_init>:
{
c0021a31:	53                   	push   %ebx
c0021a32:	83 ec 18             	sub    $0x18,%esp
/* Writes byte DATA to PORT. */
static inline void
outb (uint16_t port, uint8_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0021a35:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0021a3a:	e6 21                	out    %al,$0x21
c0021a3c:	e6 a1                	out    %al,$0xa1
c0021a3e:	b8 11 00 00 00       	mov    $0x11,%eax
c0021a43:	e6 20                	out    %al,$0x20
c0021a45:	b8 20 00 00 00       	mov    $0x20,%eax
c0021a4a:	e6 21                	out    %al,$0x21
c0021a4c:	b8 04 00 00 00       	mov    $0x4,%eax
c0021a51:	e6 21                	out    %al,$0x21
c0021a53:	b8 01 00 00 00       	mov    $0x1,%eax
c0021a58:	e6 21                	out    %al,$0x21
c0021a5a:	b8 11 00 00 00       	mov    $0x11,%eax
c0021a5f:	e6 a0                	out    %al,$0xa0
c0021a61:	b8 28 00 00 00       	mov    $0x28,%eax
c0021a66:	e6 a1                	out    %al,$0xa1
c0021a68:	b8 02 00 00 00       	mov    $0x2,%eax
c0021a6d:	e6 a1                	out    %al,$0xa1
c0021a6f:	b8 01 00 00 00       	mov    $0x1,%eax
c0021a74:	e6 a1                	out    %al,$0xa1
c0021a76:	b8 00 00 00 00       	mov    $0x0,%eax
c0021a7b:	e6 21                	out    %al,$0x21
c0021a7d:	e6 a1                	out    %al,$0xa1
  for (i = 0; i < INTR_CNT; i++)
c0021a7f:	bb 00 00 00 00       	mov    $0x0,%ebx
  return make_gate (function, dpl, 14);
c0021a84:	8b 04 9d 5c 56 03 c0 	mov    -0x3ffca9a4(,%ebx,4),%eax
c0021a8b:	b9 0e 00 00 00       	mov    $0xe,%ecx
c0021a90:	ba 00 00 00 00       	mov    $0x0,%edx
c0021a95:	e8 d6 fd ff ff       	call   c0021870 <make_gate>
    idt[i] = make_intr_gate (intr_stubs[i], 0);
c0021a9a:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021aa1:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  for (i = 0; i < INTR_CNT; i++)
c0021aa8:	83 c3 01             	add    $0x1,%ebx
c0021aab:	81 fb 00 01 00 00    	cmp    $0x100,%ebx
c0021ab1:	75 d1                	jne    c0021a84 <intr_init+0x53>
/* Returns a descriptor that yields the given LIMIT and BASE when
   used as an operand for the LIDT instruction. */
static inline uint64_t
make_idtr_operand (uint16_t limit, void *base)
{
  return limit | ((uint64_t) (uint32_t) base << 16);
c0021ab3:	b8 60 6c 03 c0       	mov    $0xc0036c60,%eax
c0021ab8:	ba 00 00 00 00       	mov    $0x0,%edx
c0021abd:	0f a4 c2 10          	shld   $0x10,%eax,%edx
c0021ac1:	c1 e0 10             	shl    $0x10,%eax
c0021ac4:	0d ff 07 00 00       	or     $0x7ff,%eax
c0021ac9:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021acd:	89 54 24 0c          	mov    %edx,0xc(%esp)
  asm volatile ("lidt %0" : : "m" (idtr_operand));
c0021ad1:	0f 01 5c 24 08       	lidtl  0x8(%esp)
  for (i = 0; i < INTR_CNT; i++)
c0021ad6:	b8 00 00 00 00       	mov    $0x0,%eax
    intr_names[i] = "unknown";
c0021adb:	c7 04 85 60 64 03 c0 	movl   $0xc002e713,-0x3ffc9ba0(,%eax,4)
c0021ae2:	13 e7 02 c0 
  for (i = 0; i < INTR_CNT; i++)
c0021ae6:	83 c0 01             	add    $0x1,%eax
c0021ae9:	3d 00 01 00 00       	cmp    $0x100,%eax
c0021aee:	75 eb                	jne    c0021adb <intr_init+0xaa>
  intr_names[0] = "#DE Divide Error";
c0021af0:	c7 05 60 64 03 c0 1b 	movl   $0xc002e71b,0xc0036460
c0021af7:	e7 02 c0 
  intr_names[1] = "#DB Debug Exception";
c0021afa:	c7 05 64 64 03 c0 2c 	movl   $0xc002e72c,0xc0036464
c0021b01:	e7 02 c0 
  intr_names[2] = "NMI Interrupt";
c0021b04:	c7 05 68 64 03 c0 40 	movl   $0xc002e740,0xc0036468
c0021b0b:	e7 02 c0 
  intr_names[3] = "#BP Breakpoint Exception";
c0021b0e:	c7 05 6c 64 03 c0 4e 	movl   $0xc002e74e,0xc003646c
c0021b15:	e7 02 c0 
  intr_names[4] = "#OF Overflow Exception";
c0021b18:	c7 05 70 64 03 c0 67 	movl   $0xc002e767,0xc0036470
c0021b1f:	e7 02 c0 
  intr_names[5] = "#BR BOUND Range Exceeded Exception";
c0021b22:	c7 05 74 64 03 c0 a4 	movl   $0xc002e8a4,0xc0036474
c0021b29:	e8 02 c0 
  intr_names[6] = "#UD Invalid Opcode Exception";
c0021b2c:	c7 05 78 64 03 c0 7e 	movl   $0xc002e77e,0xc0036478
c0021b33:	e7 02 c0 
  intr_names[7] = "#NM Device Not Available Exception";
c0021b36:	c7 05 7c 64 03 c0 c8 	movl   $0xc002e8c8,0xc003647c
c0021b3d:	e8 02 c0 
  intr_names[8] = "#DF Double Fault Exception";
c0021b40:	c7 05 80 64 03 c0 9b 	movl   $0xc002e79b,0xc0036480
c0021b47:	e7 02 c0 
  intr_names[9] = "Coprocessor Segment Overrun";
c0021b4a:	c7 05 84 64 03 c0 b6 	movl   $0xc002e7b6,0xc0036484
c0021b51:	e7 02 c0 
  intr_names[10] = "#TS Invalid TSS Exception";
c0021b54:	c7 05 88 64 03 c0 d2 	movl   $0xc002e7d2,0xc0036488
c0021b5b:	e7 02 c0 
  intr_names[11] = "#NP Segment Not Present";
c0021b5e:	c7 05 8c 64 03 c0 ec 	movl   $0xc002e7ec,0xc003648c
c0021b65:	e7 02 c0 
  intr_names[12] = "#SS Stack Fault Exception";
c0021b68:	c7 05 90 64 03 c0 04 	movl   $0xc002e804,0xc0036490
c0021b6f:	e8 02 c0 
  intr_names[13] = "#GP General Protection Exception";
c0021b72:	c7 05 94 64 03 c0 ec 	movl   $0xc002e8ec,0xc0036494
c0021b79:	e8 02 c0 
  intr_names[14] = "#PF Page-Fault Exception";
c0021b7c:	c7 05 98 64 03 c0 1e 	movl   $0xc002e81e,0xc0036498
c0021b83:	e8 02 c0 
  intr_names[16] = "#MF x87 FPU Floating-Point Error";
c0021b86:	c7 05 a0 64 03 c0 10 	movl   $0xc002e910,0xc00364a0
c0021b8d:	e9 02 c0 
  intr_names[17] = "#AC Alignment Check Exception";
c0021b90:	c7 05 a4 64 03 c0 37 	movl   $0xc002e837,0xc00364a4
c0021b97:	e8 02 c0 
  intr_names[18] = "#MC Machine-Check Exception";
c0021b9a:	c7 05 a8 64 03 c0 55 	movl   $0xc002e855,0xc00364a8
c0021ba1:	e8 02 c0 
  intr_names[19] = "#XF SIMD Floating-Point Exception";
c0021ba4:	c7 05 ac 64 03 c0 34 	movl   $0xc002e934,0xc00364ac
c0021bab:	e9 02 c0 
}
c0021bae:	83 c4 18             	add    $0x18,%esp
c0021bb1:	5b                   	pop    %ebx
c0021bb2:	c3                   	ret    

c0021bb3 <intr_register_ext>:
{
c0021bb3:	83 ec 2c             	sub    $0x2c,%esp
c0021bb6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no >= 0x20 && vec_no <= 0x2f);
c0021bba:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021bbd:	80 fa 0f             	cmp    $0xf,%dl
c0021bc0:	76 2c                	jbe    c0021bee <intr_register_ext+0x3b>
c0021bc2:	c7 44 24 10 58 e9 02 	movl   $0xc002e958,0x10(%esp)
c0021bc9:	c0 
c0021bca:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021bd1:	c0 
c0021bd2:	c7 44 24 08 d8 d1 02 	movl   $0xc002d1d8,0x8(%esp)
c0021bd9:	c0 
c0021bda:	c7 44 24 04 b8 00 00 	movl   $0xb8,0x4(%esp)
c0021be1:	00 
c0021be2:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021be9:	e8 d5 6d 00 00       	call   c00289c3 <debug_panic>
  register_handler (vec_no, 0, INTR_OFF, handler, name);
c0021bee:	0f b6 c0             	movzbl %al,%eax
c0021bf1:	8b 54 24 38          	mov    0x38(%esp),%edx
c0021bf5:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021bf9:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021bfd:	89 14 24             	mov    %edx,(%esp)
c0021c00:	b9 00 00 00 00       	mov    $0x0,%ecx
c0021c05:	ba 00 00 00 00       	mov    $0x0,%edx
c0021c0a:	e8 1b fd ff ff       	call   c002192a <register_handler>
}
c0021c0f:	83 c4 2c             	add    $0x2c,%esp
c0021c12:	c3                   	ret    

c0021c13 <intr_register_int>:
{
c0021c13:	83 ec 2c             	sub    $0x2c,%esp
c0021c16:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no < 0x20 || vec_no > 0x2f);
c0021c1a:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021c1d:	80 fa 0f             	cmp    $0xf,%dl
c0021c20:	77 2c                	ja     c0021c4e <intr_register_int+0x3b>
c0021c22:	c7 44 24 10 7c e9 02 	movl   $0xc002e97c,0x10(%esp)
c0021c29:	c0 
c0021c2a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021c31:	c0 
c0021c32:	c7 44 24 08 b5 d1 02 	movl   $0xc002d1b5,0x8(%esp)
c0021c39:	c0 
c0021c3a:	c7 44 24 04 cd 00 00 	movl   $0xcd,0x4(%esp)
c0021c41:	00 
c0021c42:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021c49:	e8 75 6d 00 00       	call   c00289c3 <debug_panic>
  register_handler (vec_no, dpl, level, handler, name);
c0021c4e:	0f b6 c0             	movzbl %al,%eax
c0021c51:	8b 54 24 40          	mov    0x40(%esp),%edx
c0021c55:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021c59:	8b 54 24 3c          	mov    0x3c(%esp),%edx
c0021c5d:	89 14 24             	mov    %edx,(%esp)
c0021c60:	8b 4c 24 38          	mov    0x38(%esp),%ecx
c0021c64:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021c68:	e8 bd fc ff ff       	call   c002192a <register_handler>
}
c0021c6d:	83 c4 2c             	add    $0x2c,%esp
c0021c70:	c3                   	ret    

c0021c71 <intr_context>:
}
c0021c71:	0f b6 05 41 60 03 c0 	movzbl 0xc0036041,%eax
c0021c78:	c3                   	ret    

c0021c79 <intr_yield_on_return>:
  ASSERT (intr_context ());
c0021c79:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021c80:	75 2f                	jne    c0021cb1 <intr_yield_on_return+0x38>
{
c0021c82:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_context ());
c0021c85:	c7 44 24 10 e3 e5 02 	movl   $0xc002e5e3,0x10(%esp)
c0021c8c:	c0 
c0021c8d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021c94:	c0 
c0021c95:	c7 44 24 08 a0 d1 02 	movl   $0xc002d1a0,0x8(%esp)
c0021c9c:	c0 
c0021c9d:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c0021ca4:	00 
c0021ca5:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021cac:	e8 12 6d 00 00       	call   c00289c3 <debug_panic>
  yield_on_return = true;
c0021cb1:	c6 05 40 60 03 c0 01 	movb   $0x1,0xc0036040
c0021cb8:	c3                   	ret    

c0021cb9 <intr_handler>:
   function is called by the assembly language interrupt stubs in
   intr-stubs.S.  FRAME describes the interrupt and the
   interrupted thread's registers. */
void
intr_handler (struct intr_frame *frame) 
{
c0021cb9:	56                   	push   %esi
c0021cba:	53                   	push   %ebx
c0021cbb:	83 ec 24             	sub    $0x24,%esp
c0021cbe:	8b 5c 24 30          	mov    0x30(%esp),%ebx

  /* External interrupts are special.
     We only handle one at a time (so interrupts must be off)
     and they need to be acknowledged on the PIC (see below).
     An external interrupt handler cannot sleep. */
  external = frame->vec_no >= 0x20 && frame->vec_no < 0x30;
c0021cc2:	8b 43 30             	mov    0x30(%ebx),%eax
c0021cc5:	83 e8 20             	sub    $0x20,%eax
c0021cc8:	83 f8 0f             	cmp    $0xf,%eax
  if (external) 
c0021ccb:	0f 96 c0             	setbe  %al
c0021cce:	89 c6                	mov    %eax,%esi
c0021cd0:	77 78                	ja     c0021d4a <intr_handler+0x91>
    {
      ASSERT (intr_get_level () == INTR_OFF);
c0021cd2:	e8 ed fc ff ff       	call   c00219c4 <intr_get_level>
c0021cd7:	85 c0                	test   %eax,%eax
c0021cd9:	74 2c                	je     c0021d07 <intr_handler+0x4e>
c0021cdb:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0021ce2:	c0 
c0021ce3:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021cea:	c0 
c0021ceb:	c7 44 24 08 93 d1 02 	movl   $0xc002d193,0x8(%esp)
c0021cf2:	c0 
c0021cf3:	c7 44 24 04 65 01 00 	movl   $0x165,0x4(%esp)
c0021cfa:	00 
c0021cfb:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021d02:	e8 bc 6c 00 00       	call   c00289c3 <debug_panic>
      ASSERT (!intr_context ());
c0021d07:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021d0e:	74 2c                	je     c0021d3c <intr_handler+0x83>
c0021d10:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0021d17:	c0 
c0021d18:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021d1f:	c0 
c0021d20:	c7 44 24 08 93 d1 02 	movl   $0xc002d193,0x8(%esp)
c0021d27:	c0 
c0021d28:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0021d2f:	00 
c0021d30:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021d37:	e8 87 6c 00 00       	call   c00289c3 <debug_panic>

      in_external_intr = true;
c0021d3c:	c6 05 41 60 03 c0 01 	movb   $0x1,0xc0036041
      yield_on_return = false;
c0021d43:	c6 05 40 60 03 c0 00 	movb   $0x0,0xc0036040
    }

  /* Invoke the interrupt's handler. */
  handler = intr_handlers[frame->vec_no];
c0021d4a:	8b 53 30             	mov    0x30(%ebx),%edx
c0021d4d:	8b 04 95 60 68 03 c0 	mov    -0x3ffc97a0(,%edx,4),%eax
  if (handler != NULL)
c0021d54:	85 c0                	test   %eax,%eax
c0021d56:	74 07                	je     c0021d5f <intr_handler+0xa6>
    handler (frame);
c0021d58:	89 1c 24             	mov    %ebx,(%esp)
c0021d5b:	ff d0                	call   *%eax
c0021d5d:	eb 3a                	jmp    c0021d99 <intr_handler+0xe0>
  else if (frame->vec_no == 0x27 || frame->vec_no == 0x2f)
c0021d5f:	89 d0                	mov    %edx,%eax
c0021d61:	83 e0 f7             	and    $0xfffffff7,%eax
c0021d64:	83 f8 27             	cmp    $0x27,%eax
c0021d67:	74 30                	je     c0021d99 <intr_handler+0xe0>
   unexpected interrupt is one that has no registered handler. */
static void
unexpected_interrupt (const struct intr_frame *f)
{
  /* Count the number so far. */
  unsigned int n = ++unexpected_cnt[f->vec_no];
c0021d69:	8b 04 95 60 60 03 c0 	mov    -0x3ffc9fa0(,%edx,4),%eax
c0021d70:	8d 48 01             	lea    0x1(%eax),%ecx
c0021d73:	89 0c 95 60 60 03 c0 	mov    %ecx,-0x3ffc9fa0(,%edx,4)
  /* If the number is a power of 2, print a message.  This rate
     limiting means that we get information about an uncommon
     unexpected interrupt the first time and fairly often after
     that, but one that occurs many times will not overwhelm the
     console. */
  if ((n & (n - 1)) == 0)
c0021d7a:	85 c1                	test   %eax,%ecx
c0021d7c:	75 1b                	jne    c0021d99 <intr_handler+0xe0>
    printf ("Unexpected interrupt %#04x (%s)\n",
c0021d7e:	8b 04 95 60 64 03 c0 	mov    -0x3ffc9ba0(,%edx,4),%eax
c0021d85:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021d89:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021d8d:	c7 04 24 9c e9 02 c0 	movl   $0xc002e99c,(%esp)
c0021d94:	e8 d5 4d 00 00       	call   c0026b6e <printf>
  if (external) 
c0021d99:	89 f0                	mov    %esi,%eax
c0021d9b:	84 c0                	test   %al,%al
c0021d9d:	0f 84 c4 00 00 00    	je     c0021e67 <intr_handler+0x1ae>
      ASSERT (intr_get_level () == INTR_OFF);
c0021da3:	e8 1c fc ff ff       	call   c00219c4 <intr_get_level>
c0021da8:	85 c0                	test   %eax,%eax
c0021daa:	74 2c                	je     c0021dd8 <intr_handler+0x11f>
c0021dac:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0021db3:	c0 
c0021db4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021dbb:	c0 
c0021dbc:	c7 44 24 08 93 d1 02 	movl   $0xc002d193,0x8(%esp)
c0021dc3:	c0 
c0021dc4:	c7 44 24 04 7c 01 00 	movl   $0x17c,0x4(%esp)
c0021dcb:	00 
c0021dcc:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021dd3:	e8 eb 6b 00 00       	call   c00289c3 <debug_panic>
      ASSERT (intr_context ());
c0021dd8:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021ddf:	75 2c                	jne    c0021e0d <intr_handler+0x154>
c0021de1:	c7 44 24 10 e3 e5 02 	movl   $0xc002e5e3,0x10(%esp)
c0021de8:	c0 
c0021de9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021df0:	c0 
c0021df1:	c7 44 24 08 93 d1 02 	movl   $0xc002d193,0x8(%esp)
c0021df8:	c0 
c0021df9:	c7 44 24 04 7d 01 00 	movl   $0x17d,0x4(%esp)
c0021e00:	00 
c0021e01:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021e08:	e8 b6 6b 00 00       	call   c00289c3 <debug_panic>
      in_external_intr = false;
c0021e0d:	c6 05 41 60 03 c0 00 	movb   $0x0,0xc0036041
      pic_end_of_interrupt (frame->vec_no); 
c0021e14:	8b 53 30             	mov    0x30(%ebx),%edx
  ASSERT (irq >= 0x20 && irq < 0x30);
c0021e17:	8d 42 e0             	lea    -0x20(%edx),%eax
c0021e1a:	83 f8 0f             	cmp    $0xf,%eax
c0021e1d:	76 2c                	jbe    c0021e4b <intr_handler+0x192>
c0021e1f:	c7 44 24 10 71 e8 02 	movl   $0xc002e871,0x10(%esp)
c0021e26:	c0 
c0021e27:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021e2e:	c0 
c0021e2f:	c7 44 24 08 7e d1 02 	movl   $0xc002d17e,0x8(%esp)
c0021e36:	c0 
c0021e37:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0021e3e:	00 
c0021e3f:	c7 04 24 ae e6 02 c0 	movl   $0xc002e6ae,(%esp)
c0021e46:	e8 78 6b 00 00       	call   c00289c3 <debug_panic>
c0021e4b:	b8 20 00 00 00       	mov    $0x20,%eax
c0021e50:	e6 20                	out    %al,$0x20
  if (irq >= 0x28)
c0021e52:	83 fa 27             	cmp    $0x27,%edx
c0021e55:	7e 02                	jle    c0021e59 <intr_handler+0x1a0>
c0021e57:	e6 a0                	out    %al,$0xa0
      if (yield_on_return) 
c0021e59:	80 3d 40 60 03 c0 00 	cmpb   $0x0,0xc0036040
c0021e60:	74 05                	je     c0021e67 <intr_handler+0x1ae>
        thread_yield (); 
c0021e62:	e8 78 f6 ff ff       	call   c00214df <thread_yield>
}
c0021e67:	83 c4 24             	add    $0x24,%esp
c0021e6a:	5b                   	pop    %ebx
c0021e6b:	5e                   	pop    %esi
c0021e6c:	c3                   	ret    

c0021e6d <intr_dump_frame>:
}

/* Dumps interrupt frame F to the console, for debugging. */
void
intr_dump_frame (const struct intr_frame *f) 
{
c0021e6d:	56                   	push   %esi
c0021e6e:	53                   	push   %ebx
c0021e6f:	83 ec 24             	sub    $0x24,%esp
c0021e72:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  /* Store current value of CR2 into `cr2'.
     CR2 is the linear address of the last page fault.
     See [IA32-v2a] "MOV--Move to/from Control Registers" and
     [IA32-v3a] 5.14 "Interrupt 14--Page Fault Exception
     (#PF)". */
  asm ("movl %%cr2, %0" : "=r" (cr2));
c0021e76:	0f 20 d6             	mov    %cr2,%esi

  printf ("Interrupt %#04x (%s) at eip=%p\n",
          f->vec_no, intr_names[f->vec_no], f->eip);
c0021e79:	8b 43 30             	mov    0x30(%ebx),%eax
  printf ("Interrupt %#04x (%s) at eip=%p\n",
c0021e7c:	8b 53 3c             	mov    0x3c(%ebx),%edx
c0021e7f:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0021e83:	8b 14 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%edx
c0021e8a:	89 54 24 08          	mov    %edx,0x8(%esp)
c0021e8e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021e92:	c7 04 24 c0 e9 02 c0 	movl   $0xc002e9c0,(%esp)
c0021e99:	e8 d0 4c 00 00       	call   c0026b6e <printf>
  printf (" cr2=%08"PRIx32" error=%08"PRIx32"\n", cr2, f->error_code);
c0021e9e:	8b 43 34             	mov    0x34(%ebx),%eax
c0021ea1:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021ea5:	89 74 24 04          	mov    %esi,0x4(%esp)
c0021ea9:	c7 04 24 8b e8 02 c0 	movl   $0xc002e88b,(%esp)
c0021eb0:	e8 b9 4c 00 00       	call   c0026b6e <printf>
  printf (" eax=%08"PRIx32" ebx=%08"PRIx32" ecx=%08"PRIx32" edx=%08"PRIx32"\n",
c0021eb5:	8b 43 14             	mov    0x14(%ebx),%eax
c0021eb8:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021ebc:	8b 43 18             	mov    0x18(%ebx),%eax
c0021ebf:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021ec3:	8b 43 10             	mov    0x10(%ebx),%eax
c0021ec6:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021eca:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021ecd:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021ed1:	c7 04 24 e0 e9 02 c0 	movl   $0xc002e9e0,(%esp)
c0021ed8:	e8 91 4c 00 00       	call   c0026b6e <printf>
          f->eax, f->ebx, f->ecx, f->edx);
  printf (" esi=%08"PRIx32" edi=%08"PRIx32" esp=%08"PRIx32" ebp=%08"PRIx32"\n",
c0021edd:	8b 43 08             	mov    0x8(%ebx),%eax
c0021ee0:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021ee4:	8b 43 48             	mov    0x48(%ebx),%eax
c0021ee7:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021eeb:	8b 03                	mov    (%ebx),%eax
c0021eed:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021ef1:	8b 43 04             	mov    0x4(%ebx),%eax
c0021ef4:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021ef8:	c7 04 24 08 ea 02 c0 	movl   $0xc002ea08,(%esp)
c0021eff:	e8 6a 4c 00 00       	call   c0026b6e <printf>
          f->esi, f->edi, (uint32_t) f->esp, f->ebp);
  printf (" cs=%04"PRIx16" ds=%04"PRIx16" es=%04"PRIx16" ss=%04"PRIx16"\n",
c0021f04:	0f b7 43 4c          	movzwl 0x4c(%ebx),%eax
c0021f08:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021f0c:	0f b7 43 28          	movzwl 0x28(%ebx),%eax
c0021f10:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021f14:	0f b7 43 2c          	movzwl 0x2c(%ebx),%eax
c0021f18:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021f1c:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
c0021f20:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021f24:	c7 04 24 30 ea 02 c0 	movl   $0xc002ea30,(%esp)
c0021f2b:	e8 3e 4c 00 00       	call   c0026b6e <printf>
          f->cs, f->ds, f->es, f->ss);
}
c0021f30:	83 c4 24             	add    $0x24,%esp
c0021f33:	5b                   	pop    %ebx
c0021f34:	5e                   	pop    %esi
c0021f35:	c3                   	ret    

c0021f36 <intr_name>:

/* Returns the name of interrupt VEC. */
const char *
intr_name (uint8_t vec) 
{
  return intr_names[vec];
c0021f36:	0f b6 44 24 04       	movzbl 0x4(%esp),%eax
c0021f3b:	8b 04 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%eax
}
c0021f42:	c3                   	ret    

c0021f43 <intr_entry>:
   We "fall through" to intr_exit to return from the interrupt.
*/
.func intr_entry
intr_entry:
	/* Save caller's registers. */
	pushl %ds
c0021f43:	1e                   	push   %ds
	pushl %es
c0021f44:	06                   	push   %es
	pushl %fs
c0021f45:	0f a0                	push   %fs
	pushl %gs
c0021f47:	0f a8                	push   %gs
	pushal
c0021f49:	60                   	pusha  
        
	/* Set up kernel environment. */
	cld			/* String instructions go upward. */
c0021f4a:	fc                   	cld    
	mov $SEL_KDSEG, %eax	/* Initialize segment registers. */
c0021f4b:	b8 10 00 00 00       	mov    $0x10,%eax
	mov %eax, %ds
c0021f50:	8e d8                	mov    %eax,%ds
	mov %eax, %es
c0021f52:	8e c0                	mov    %eax,%es
	leal 56(%esp), %ebp	/* Set up frame pointer. */
c0021f54:	8d 6c 24 38          	lea    0x38(%esp),%ebp

	/* Call interrupt handler. */
	pushl %esp
c0021f58:	54                   	push   %esp
.globl intr_handler
	call intr_handler
c0021f59:	e8 5b fd ff ff       	call   c0021cb9 <intr_handler>
	addl $4, %esp
c0021f5e:	83 c4 04             	add    $0x4,%esp

c0021f61 <intr_exit>:
   userprog/process.c). */
.globl intr_exit
.func intr_exit
intr_exit:
        /* Restore caller's registers. */
	popal
c0021f61:	61                   	popa   
	popl %gs
c0021f62:	0f a9                	pop    %gs
	popl %fs
c0021f64:	0f a1                	pop    %fs
	popl %es
c0021f66:	07                   	pop    %es
	popl %ds
c0021f67:	1f                   	pop    %ds

        /* Discard `struct intr_frame' vec_no, error_code,
           frame_pointer members. */
	addl $12, %esp
c0021f68:	83 c4 0c             	add    $0xc,%esp

        /* Return to caller. */
	iret
c0021f6b:	cf                   	iret   

c0021f6c <intr00_stub>:
                                                \
	.data;                                  \
	.long intr##NUMBER##_stub;

/* All the stubs. */
STUB(00, zero) STUB(01, zero) STUB(02, zero) STUB(03, zero)
c0021f6c:	55                   	push   %ebp
c0021f6d:	6a 00                	push   $0x0
c0021f6f:	6a 00                	push   $0x0
c0021f71:	eb d0                	jmp    c0021f43 <intr_entry>

c0021f73 <intr01_stub>:
c0021f73:	55                   	push   %ebp
c0021f74:	6a 00                	push   $0x0
c0021f76:	6a 01                	push   $0x1
c0021f78:	eb c9                	jmp    c0021f43 <intr_entry>

c0021f7a <intr02_stub>:
c0021f7a:	55                   	push   %ebp
c0021f7b:	6a 00                	push   $0x0
c0021f7d:	6a 02                	push   $0x2
c0021f7f:	eb c2                	jmp    c0021f43 <intr_entry>

c0021f81 <intr03_stub>:
c0021f81:	55                   	push   %ebp
c0021f82:	6a 00                	push   $0x0
c0021f84:	6a 03                	push   $0x3
c0021f86:	eb bb                	jmp    c0021f43 <intr_entry>

c0021f88 <intr04_stub>:
STUB(04, zero) STUB(05, zero) STUB(06, zero) STUB(07, zero)
c0021f88:	55                   	push   %ebp
c0021f89:	6a 00                	push   $0x0
c0021f8b:	6a 04                	push   $0x4
c0021f8d:	eb b4                	jmp    c0021f43 <intr_entry>

c0021f8f <intr05_stub>:
c0021f8f:	55                   	push   %ebp
c0021f90:	6a 00                	push   $0x0
c0021f92:	6a 05                	push   $0x5
c0021f94:	eb ad                	jmp    c0021f43 <intr_entry>

c0021f96 <intr06_stub>:
c0021f96:	55                   	push   %ebp
c0021f97:	6a 00                	push   $0x0
c0021f99:	6a 06                	push   $0x6
c0021f9b:	eb a6                	jmp    c0021f43 <intr_entry>

c0021f9d <intr07_stub>:
c0021f9d:	55                   	push   %ebp
c0021f9e:	6a 00                	push   $0x0
c0021fa0:	6a 07                	push   $0x7
c0021fa2:	eb 9f                	jmp    c0021f43 <intr_entry>

c0021fa4 <intr08_stub>:
STUB(08, REAL) STUB(09, zero) STUB(0a, REAL) STUB(0b, REAL)
c0021fa4:	ff 34 24             	pushl  (%esp)
c0021fa7:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fab:	6a 08                	push   $0x8
c0021fad:	eb 94                	jmp    c0021f43 <intr_entry>

c0021faf <intr09_stub>:
c0021faf:	55                   	push   %ebp
c0021fb0:	6a 00                	push   $0x0
c0021fb2:	6a 09                	push   $0x9
c0021fb4:	eb 8d                	jmp    c0021f43 <intr_entry>

c0021fb6 <intr0a_stub>:
c0021fb6:	ff 34 24             	pushl  (%esp)
c0021fb9:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fbd:	6a 0a                	push   $0xa
c0021fbf:	eb 82                	jmp    c0021f43 <intr_entry>

c0021fc1 <intr0b_stub>:
c0021fc1:	ff 34 24             	pushl  (%esp)
c0021fc4:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fc8:	6a 0b                	push   $0xb
c0021fca:	e9 74 ff ff ff       	jmp    c0021f43 <intr_entry>

c0021fcf <intr0c_stub>:
STUB(0c, zero) STUB(0d, REAL) STUB(0e, REAL) STUB(0f, zero)
c0021fcf:	55                   	push   %ebp
c0021fd0:	6a 00                	push   $0x0
c0021fd2:	6a 0c                	push   $0xc
c0021fd4:	e9 6a ff ff ff       	jmp    c0021f43 <intr_entry>

c0021fd9 <intr0d_stub>:
c0021fd9:	ff 34 24             	pushl  (%esp)
c0021fdc:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fe0:	6a 0d                	push   $0xd
c0021fe2:	e9 5c ff ff ff       	jmp    c0021f43 <intr_entry>

c0021fe7 <intr0e_stub>:
c0021fe7:	ff 34 24             	pushl  (%esp)
c0021fea:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fee:	6a 0e                	push   $0xe
c0021ff0:	e9 4e ff ff ff       	jmp    c0021f43 <intr_entry>

c0021ff5 <intr0f_stub>:
c0021ff5:	55                   	push   %ebp
c0021ff6:	6a 00                	push   $0x0
c0021ff8:	6a 0f                	push   $0xf
c0021ffa:	e9 44 ff ff ff       	jmp    c0021f43 <intr_entry>

c0021fff <intr10_stub>:

STUB(10, zero) STUB(11, REAL) STUB(12, zero) STUB(13, zero)
c0021fff:	55                   	push   %ebp
c0022000:	6a 00                	push   $0x0
c0022002:	6a 10                	push   $0x10
c0022004:	e9 3a ff ff ff       	jmp    c0021f43 <intr_entry>

c0022009 <intr11_stub>:
c0022009:	ff 34 24             	pushl  (%esp)
c002200c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022010:	6a 11                	push   $0x11
c0022012:	e9 2c ff ff ff       	jmp    c0021f43 <intr_entry>

c0022017 <intr12_stub>:
c0022017:	55                   	push   %ebp
c0022018:	6a 00                	push   $0x0
c002201a:	6a 12                	push   $0x12
c002201c:	e9 22 ff ff ff       	jmp    c0021f43 <intr_entry>

c0022021 <intr13_stub>:
c0022021:	55                   	push   %ebp
c0022022:	6a 00                	push   $0x0
c0022024:	6a 13                	push   $0x13
c0022026:	e9 18 ff ff ff       	jmp    c0021f43 <intr_entry>

c002202b <intr14_stub>:
STUB(14, zero) STUB(15, zero) STUB(16, zero) STUB(17, zero)
c002202b:	55                   	push   %ebp
c002202c:	6a 00                	push   $0x0
c002202e:	6a 14                	push   $0x14
c0022030:	e9 0e ff ff ff       	jmp    c0021f43 <intr_entry>

c0022035 <intr15_stub>:
c0022035:	55                   	push   %ebp
c0022036:	6a 00                	push   $0x0
c0022038:	6a 15                	push   $0x15
c002203a:	e9 04 ff ff ff       	jmp    c0021f43 <intr_entry>

c002203f <intr16_stub>:
c002203f:	55                   	push   %ebp
c0022040:	6a 00                	push   $0x0
c0022042:	6a 16                	push   $0x16
c0022044:	e9 fa fe ff ff       	jmp    c0021f43 <intr_entry>

c0022049 <intr17_stub>:
c0022049:	55                   	push   %ebp
c002204a:	6a 00                	push   $0x0
c002204c:	6a 17                	push   $0x17
c002204e:	e9 f0 fe ff ff       	jmp    c0021f43 <intr_entry>

c0022053 <intr18_stub>:
STUB(18, REAL) STUB(19, zero) STUB(1a, REAL) STUB(1b, REAL)
c0022053:	ff 34 24             	pushl  (%esp)
c0022056:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002205a:	6a 18                	push   $0x18
c002205c:	e9 e2 fe ff ff       	jmp    c0021f43 <intr_entry>

c0022061 <intr19_stub>:
c0022061:	55                   	push   %ebp
c0022062:	6a 00                	push   $0x0
c0022064:	6a 19                	push   $0x19
c0022066:	e9 d8 fe ff ff       	jmp    c0021f43 <intr_entry>

c002206b <intr1a_stub>:
c002206b:	ff 34 24             	pushl  (%esp)
c002206e:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022072:	6a 1a                	push   $0x1a
c0022074:	e9 ca fe ff ff       	jmp    c0021f43 <intr_entry>

c0022079 <intr1b_stub>:
c0022079:	ff 34 24             	pushl  (%esp)
c002207c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022080:	6a 1b                	push   $0x1b
c0022082:	e9 bc fe ff ff       	jmp    c0021f43 <intr_entry>

c0022087 <intr1c_stub>:
STUB(1c, zero) STUB(1d, REAL) STUB(1e, REAL) STUB(1f, zero)
c0022087:	55                   	push   %ebp
c0022088:	6a 00                	push   $0x0
c002208a:	6a 1c                	push   $0x1c
c002208c:	e9 b2 fe ff ff       	jmp    c0021f43 <intr_entry>

c0022091 <intr1d_stub>:
c0022091:	ff 34 24             	pushl  (%esp)
c0022094:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022098:	6a 1d                	push   $0x1d
c002209a:	e9 a4 fe ff ff       	jmp    c0021f43 <intr_entry>

c002209f <intr1e_stub>:
c002209f:	ff 34 24             	pushl  (%esp)
c00220a2:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00220a6:	6a 1e                	push   $0x1e
c00220a8:	e9 96 fe ff ff       	jmp    c0021f43 <intr_entry>

c00220ad <intr1f_stub>:
c00220ad:	55                   	push   %ebp
c00220ae:	6a 00                	push   $0x0
c00220b0:	6a 1f                	push   $0x1f
c00220b2:	e9 8c fe ff ff       	jmp    c0021f43 <intr_entry>

c00220b7 <intr20_stub>:

STUB(20, zero) STUB(21, zero) STUB(22, zero) STUB(23, zero)
c00220b7:	55                   	push   %ebp
c00220b8:	6a 00                	push   $0x0
c00220ba:	6a 20                	push   $0x20
c00220bc:	e9 82 fe ff ff       	jmp    c0021f43 <intr_entry>

c00220c1 <intr21_stub>:
c00220c1:	55                   	push   %ebp
c00220c2:	6a 00                	push   $0x0
c00220c4:	6a 21                	push   $0x21
c00220c6:	e9 78 fe ff ff       	jmp    c0021f43 <intr_entry>

c00220cb <intr22_stub>:
c00220cb:	55                   	push   %ebp
c00220cc:	6a 00                	push   $0x0
c00220ce:	6a 22                	push   $0x22
c00220d0:	e9 6e fe ff ff       	jmp    c0021f43 <intr_entry>

c00220d5 <intr23_stub>:
c00220d5:	55                   	push   %ebp
c00220d6:	6a 00                	push   $0x0
c00220d8:	6a 23                	push   $0x23
c00220da:	e9 64 fe ff ff       	jmp    c0021f43 <intr_entry>

c00220df <intr24_stub>:
STUB(24, zero) STUB(25, zero) STUB(26, zero) STUB(27, zero)
c00220df:	55                   	push   %ebp
c00220e0:	6a 00                	push   $0x0
c00220e2:	6a 24                	push   $0x24
c00220e4:	e9 5a fe ff ff       	jmp    c0021f43 <intr_entry>

c00220e9 <intr25_stub>:
c00220e9:	55                   	push   %ebp
c00220ea:	6a 00                	push   $0x0
c00220ec:	6a 25                	push   $0x25
c00220ee:	e9 50 fe ff ff       	jmp    c0021f43 <intr_entry>

c00220f3 <intr26_stub>:
c00220f3:	55                   	push   %ebp
c00220f4:	6a 00                	push   $0x0
c00220f6:	6a 26                	push   $0x26
c00220f8:	e9 46 fe ff ff       	jmp    c0021f43 <intr_entry>

c00220fd <intr27_stub>:
c00220fd:	55                   	push   %ebp
c00220fe:	6a 00                	push   $0x0
c0022100:	6a 27                	push   $0x27
c0022102:	e9 3c fe ff ff       	jmp    c0021f43 <intr_entry>

c0022107 <intr28_stub>:
STUB(28, zero) STUB(29, zero) STUB(2a, zero) STUB(2b, zero)
c0022107:	55                   	push   %ebp
c0022108:	6a 00                	push   $0x0
c002210a:	6a 28                	push   $0x28
c002210c:	e9 32 fe ff ff       	jmp    c0021f43 <intr_entry>

c0022111 <intr29_stub>:
c0022111:	55                   	push   %ebp
c0022112:	6a 00                	push   $0x0
c0022114:	6a 29                	push   $0x29
c0022116:	e9 28 fe ff ff       	jmp    c0021f43 <intr_entry>

c002211b <intr2a_stub>:
c002211b:	55                   	push   %ebp
c002211c:	6a 00                	push   $0x0
c002211e:	6a 2a                	push   $0x2a
c0022120:	e9 1e fe ff ff       	jmp    c0021f43 <intr_entry>

c0022125 <intr2b_stub>:
c0022125:	55                   	push   %ebp
c0022126:	6a 00                	push   $0x0
c0022128:	6a 2b                	push   $0x2b
c002212a:	e9 14 fe ff ff       	jmp    c0021f43 <intr_entry>

c002212f <intr2c_stub>:
STUB(2c, zero) STUB(2d, zero) STUB(2e, zero) STUB(2f, zero)
c002212f:	55                   	push   %ebp
c0022130:	6a 00                	push   $0x0
c0022132:	6a 2c                	push   $0x2c
c0022134:	e9 0a fe ff ff       	jmp    c0021f43 <intr_entry>

c0022139 <intr2d_stub>:
c0022139:	55                   	push   %ebp
c002213a:	6a 00                	push   $0x0
c002213c:	6a 2d                	push   $0x2d
c002213e:	e9 00 fe ff ff       	jmp    c0021f43 <intr_entry>

c0022143 <intr2e_stub>:
c0022143:	55                   	push   %ebp
c0022144:	6a 00                	push   $0x0
c0022146:	6a 2e                	push   $0x2e
c0022148:	e9 f6 fd ff ff       	jmp    c0021f43 <intr_entry>

c002214d <intr2f_stub>:
c002214d:	55                   	push   %ebp
c002214e:	6a 00                	push   $0x0
c0022150:	6a 2f                	push   $0x2f
c0022152:	e9 ec fd ff ff       	jmp    c0021f43 <intr_entry>

c0022157 <intr30_stub>:

STUB(30, zero) STUB(31, zero) STUB(32, zero) STUB(33, zero)
c0022157:	55                   	push   %ebp
c0022158:	6a 00                	push   $0x0
c002215a:	6a 30                	push   $0x30
c002215c:	e9 e2 fd ff ff       	jmp    c0021f43 <intr_entry>

c0022161 <intr31_stub>:
c0022161:	55                   	push   %ebp
c0022162:	6a 00                	push   $0x0
c0022164:	6a 31                	push   $0x31
c0022166:	e9 d8 fd ff ff       	jmp    c0021f43 <intr_entry>

c002216b <intr32_stub>:
c002216b:	55                   	push   %ebp
c002216c:	6a 00                	push   $0x0
c002216e:	6a 32                	push   $0x32
c0022170:	e9 ce fd ff ff       	jmp    c0021f43 <intr_entry>

c0022175 <intr33_stub>:
c0022175:	55                   	push   %ebp
c0022176:	6a 00                	push   $0x0
c0022178:	6a 33                	push   $0x33
c002217a:	e9 c4 fd ff ff       	jmp    c0021f43 <intr_entry>

c002217f <intr34_stub>:
STUB(34, zero) STUB(35, zero) STUB(36, zero) STUB(37, zero)
c002217f:	55                   	push   %ebp
c0022180:	6a 00                	push   $0x0
c0022182:	6a 34                	push   $0x34
c0022184:	e9 ba fd ff ff       	jmp    c0021f43 <intr_entry>

c0022189 <intr35_stub>:
c0022189:	55                   	push   %ebp
c002218a:	6a 00                	push   $0x0
c002218c:	6a 35                	push   $0x35
c002218e:	e9 b0 fd ff ff       	jmp    c0021f43 <intr_entry>

c0022193 <intr36_stub>:
c0022193:	55                   	push   %ebp
c0022194:	6a 00                	push   $0x0
c0022196:	6a 36                	push   $0x36
c0022198:	e9 a6 fd ff ff       	jmp    c0021f43 <intr_entry>

c002219d <intr37_stub>:
c002219d:	55                   	push   %ebp
c002219e:	6a 00                	push   $0x0
c00221a0:	6a 37                	push   $0x37
c00221a2:	e9 9c fd ff ff       	jmp    c0021f43 <intr_entry>

c00221a7 <intr38_stub>:
STUB(38, zero) STUB(39, zero) STUB(3a, zero) STUB(3b, zero)
c00221a7:	55                   	push   %ebp
c00221a8:	6a 00                	push   $0x0
c00221aa:	6a 38                	push   $0x38
c00221ac:	e9 92 fd ff ff       	jmp    c0021f43 <intr_entry>

c00221b1 <intr39_stub>:
c00221b1:	55                   	push   %ebp
c00221b2:	6a 00                	push   $0x0
c00221b4:	6a 39                	push   $0x39
c00221b6:	e9 88 fd ff ff       	jmp    c0021f43 <intr_entry>

c00221bb <intr3a_stub>:
c00221bb:	55                   	push   %ebp
c00221bc:	6a 00                	push   $0x0
c00221be:	6a 3a                	push   $0x3a
c00221c0:	e9 7e fd ff ff       	jmp    c0021f43 <intr_entry>

c00221c5 <intr3b_stub>:
c00221c5:	55                   	push   %ebp
c00221c6:	6a 00                	push   $0x0
c00221c8:	6a 3b                	push   $0x3b
c00221ca:	e9 74 fd ff ff       	jmp    c0021f43 <intr_entry>

c00221cf <intr3c_stub>:
STUB(3c, zero) STUB(3d, zero) STUB(3e, zero) STUB(3f, zero)
c00221cf:	55                   	push   %ebp
c00221d0:	6a 00                	push   $0x0
c00221d2:	6a 3c                	push   $0x3c
c00221d4:	e9 6a fd ff ff       	jmp    c0021f43 <intr_entry>

c00221d9 <intr3d_stub>:
c00221d9:	55                   	push   %ebp
c00221da:	6a 00                	push   $0x0
c00221dc:	6a 3d                	push   $0x3d
c00221de:	e9 60 fd ff ff       	jmp    c0021f43 <intr_entry>

c00221e3 <intr3e_stub>:
c00221e3:	55                   	push   %ebp
c00221e4:	6a 00                	push   $0x0
c00221e6:	6a 3e                	push   $0x3e
c00221e8:	e9 56 fd ff ff       	jmp    c0021f43 <intr_entry>

c00221ed <intr3f_stub>:
c00221ed:	55                   	push   %ebp
c00221ee:	6a 00                	push   $0x0
c00221f0:	6a 3f                	push   $0x3f
c00221f2:	e9 4c fd ff ff       	jmp    c0021f43 <intr_entry>

c00221f7 <intr40_stub>:

STUB(40, zero) STUB(41, zero) STUB(42, zero) STUB(43, zero)
c00221f7:	55                   	push   %ebp
c00221f8:	6a 00                	push   $0x0
c00221fa:	6a 40                	push   $0x40
c00221fc:	e9 42 fd ff ff       	jmp    c0021f43 <intr_entry>

c0022201 <intr41_stub>:
c0022201:	55                   	push   %ebp
c0022202:	6a 00                	push   $0x0
c0022204:	6a 41                	push   $0x41
c0022206:	e9 38 fd ff ff       	jmp    c0021f43 <intr_entry>

c002220b <intr42_stub>:
c002220b:	55                   	push   %ebp
c002220c:	6a 00                	push   $0x0
c002220e:	6a 42                	push   $0x42
c0022210:	e9 2e fd ff ff       	jmp    c0021f43 <intr_entry>

c0022215 <intr43_stub>:
c0022215:	55                   	push   %ebp
c0022216:	6a 00                	push   $0x0
c0022218:	6a 43                	push   $0x43
c002221a:	e9 24 fd ff ff       	jmp    c0021f43 <intr_entry>

c002221f <intr44_stub>:
STUB(44, zero) STUB(45, zero) STUB(46, zero) STUB(47, zero)
c002221f:	55                   	push   %ebp
c0022220:	6a 00                	push   $0x0
c0022222:	6a 44                	push   $0x44
c0022224:	e9 1a fd ff ff       	jmp    c0021f43 <intr_entry>

c0022229 <intr45_stub>:
c0022229:	55                   	push   %ebp
c002222a:	6a 00                	push   $0x0
c002222c:	6a 45                	push   $0x45
c002222e:	e9 10 fd ff ff       	jmp    c0021f43 <intr_entry>

c0022233 <intr46_stub>:
c0022233:	55                   	push   %ebp
c0022234:	6a 00                	push   $0x0
c0022236:	6a 46                	push   $0x46
c0022238:	e9 06 fd ff ff       	jmp    c0021f43 <intr_entry>

c002223d <intr47_stub>:
c002223d:	55                   	push   %ebp
c002223e:	6a 00                	push   $0x0
c0022240:	6a 47                	push   $0x47
c0022242:	e9 fc fc ff ff       	jmp    c0021f43 <intr_entry>

c0022247 <intr48_stub>:
STUB(48, zero) STUB(49, zero) STUB(4a, zero) STUB(4b, zero)
c0022247:	55                   	push   %ebp
c0022248:	6a 00                	push   $0x0
c002224a:	6a 48                	push   $0x48
c002224c:	e9 f2 fc ff ff       	jmp    c0021f43 <intr_entry>

c0022251 <intr49_stub>:
c0022251:	55                   	push   %ebp
c0022252:	6a 00                	push   $0x0
c0022254:	6a 49                	push   $0x49
c0022256:	e9 e8 fc ff ff       	jmp    c0021f43 <intr_entry>

c002225b <intr4a_stub>:
c002225b:	55                   	push   %ebp
c002225c:	6a 00                	push   $0x0
c002225e:	6a 4a                	push   $0x4a
c0022260:	e9 de fc ff ff       	jmp    c0021f43 <intr_entry>

c0022265 <intr4b_stub>:
c0022265:	55                   	push   %ebp
c0022266:	6a 00                	push   $0x0
c0022268:	6a 4b                	push   $0x4b
c002226a:	e9 d4 fc ff ff       	jmp    c0021f43 <intr_entry>

c002226f <intr4c_stub>:
STUB(4c, zero) STUB(4d, zero) STUB(4e, zero) STUB(4f, zero)
c002226f:	55                   	push   %ebp
c0022270:	6a 00                	push   $0x0
c0022272:	6a 4c                	push   $0x4c
c0022274:	e9 ca fc ff ff       	jmp    c0021f43 <intr_entry>

c0022279 <intr4d_stub>:
c0022279:	55                   	push   %ebp
c002227a:	6a 00                	push   $0x0
c002227c:	6a 4d                	push   $0x4d
c002227e:	e9 c0 fc ff ff       	jmp    c0021f43 <intr_entry>

c0022283 <intr4e_stub>:
c0022283:	55                   	push   %ebp
c0022284:	6a 00                	push   $0x0
c0022286:	6a 4e                	push   $0x4e
c0022288:	e9 b6 fc ff ff       	jmp    c0021f43 <intr_entry>

c002228d <intr4f_stub>:
c002228d:	55                   	push   %ebp
c002228e:	6a 00                	push   $0x0
c0022290:	6a 4f                	push   $0x4f
c0022292:	e9 ac fc ff ff       	jmp    c0021f43 <intr_entry>

c0022297 <intr50_stub>:

STUB(50, zero) STUB(51, zero) STUB(52, zero) STUB(53, zero)
c0022297:	55                   	push   %ebp
c0022298:	6a 00                	push   $0x0
c002229a:	6a 50                	push   $0x50
c002229c:	e9 a2 fc ff ff       	jmp    c0021f43 <intr_entry>

c00222a1 <intr51_stub>:
c00222a1:	55                   	push   %ebp
c00222a2:	6a 00                	push   $0x0
c00222a4:	6a 51                	push   $0x51
c00222a6:	e9 98 fc ff ff       	jmp    c0021f43 <intr_entry>

c00222ab <intr52_stub>:
c00222ab:	55                   	push   %ebp
c00222ac:	6a 00                	push   $0x0
c00222ae:	6a 52                	push   $0x52
c00222b0:	e9 8e fc ff ff       	jmp    c0021f43 <intr_entry>

c00222b5 <intr53_stub>:
c00222b5:	55                   	push   %ebp
c00222b6:	6a 00                	push   $0x0
c00222b8:	6a 53                	push   $0x53
c00222ba:	e9 84 fc ff ff       	jmp    c0021f43 <intr_entry>

c00222bf <intr54_stub>:
STUB(54, zero) STUB(55, zero) STUB(56, zero) STUB(57, zero)
c00222bf:	55                   	push   %ebp
c00222c0:	6a 00                	push   $0x0
c00222c2:	6a 54                	push   $0x54
c00222c4:	e9 7a fc ff ff       	jmp    c0021f43 <intr_entry>

c00222c9 <intr55_stub>:
c00222c9:	55                   	push   %ebp
c00222ca:	6a 00                	push   $0x0
c00222cc:	6a 55                	push   $0x55
c00222ce:	e9 70 fc ff ff       	jmp    c0021f43 <intr_entry>

c00222d3 <intr56_stub>:
c00222d3:	55                   	push   %ebp
c00222d4:	6a 00                	push   $0x0
c00222d6:	6a 56                	push   $0x56
c00222d8:	e9 66 fc ff ff       	jmp    c0021f43 <intr_entry>

c00222dd <intr57_stub>:
c00222dd:	55                   	push   %ebp
c00222de:	6a 00                	push   $0x0
c00222e0:	6a 57                	push   $0x57
c00222e2:	e9 5c fc ff ff       	jmp    c0021f43 <intr_entry>

c00222e7 <intr58_stub>:
STUB(58, zero) STUB(59, zero) STUB(5a, zero) STUB(5b, zero)
c00222e7:	55                   	push   %ebp
c00222e8:	6a 00                	push   $0x0
c00222ea:	6a 58                	push   $0x58
c00222ec:	e9 52 fc ff ff       	jmp    c0021f43 <intr_entry>

c00222f1 <intr59_stub>:
c00222f1:	55                   	push   %ebp
c00222f2:	6a 00                	push   $0x0
c00222f4:	6a 59                	push   $0x59
c00222f6:	e9 48 fc ff ff       	jmp    c0021f43 <intr_entry>

c00222fb <intr5a_stub>:
c00222fb:	55                   	push   %ebp
c00222fc:	6a 00                	push   $0x0
c00222fe:	6a 5a                	push   $0x5a
c0022300:	e9 3e fc ff ff       	jmp    c0021f43 <intr_entry>

c0022305 <intr5b_stub>:
c0022305:	55                   	push   %ebp
c0022306:	6a 00                	push   $0x0
c0022308:	6a 5b                	push   $0x5b
c002230a:	e9 34 fc ff ff       	jmp    c0021f43 <intr_entry>

c002230f <intr5c_stub>:
STUB(5c, zero) STUB(5d, zero) STUB(5e, zero) STUB(5f, zero)
c002230f:	55                   	push   %ebp
c0022310:	6a 00                	push   $0x0
c0022312:	6a 5c                	push   $0x5c
c0022314:	e9 2a fc ff ff       	jmp    c0021f43 <intr_entry>

c0022319 <intr5d_stub>:
c0022319:	55                   	push   %ebp
c002231a:	6a 00                	push   $0x0
c002231c:	6a 5d                	push   $0x5d
c002231e:	e9 20 fc ff ff       	jmp    c0021f43 <intr_entry>

c0022323 <intr5e_stub>:
c0022323:	55                   	push   %ebp
c0022324:	6a 00                	push   $0x0
c0022326:	6a 5e                	push   $0x5e
c0022328:	e9 16 fc ff ff       	jmp    c0021f43 <intr_entry>

c002232d <intr5f_stub>:
c002232d:	55                   	push   %ebp
c002232e:	6a 00                	push   $0x0
c0022330:	6a 5f                	push   $0x5f
c0022332:	e9 0c fc ff ff       	jmp    c0021f43 <intr_entry>

c0022337 <intr60_stub>:

STUB(60, zero) STUB(61, zero) STUB(62, zero) STUB(63, zero)
c0022337:	55                   	push   %ebp
c0022338:	6a 00                	push   $0x0
c002233a:	6a 60                	push   $0x60
c002233c:	e9 02 fc ff ff       	jmp    c0021f43 <intr_entry>

c0022341 <intr61_stub>:
c0022341:	55                   	push   %ebp
c0022342:	6a 00                	push   $0x0
c0022344:	6a 61                	push   $0x61
c0022346:	e9 f8 fb ff ff       	jmp    c0021f43 <intr_entry>

c002234b <intr62_stub>:
c002234b:	55                   	push   %ebp
c002234c:	6a 00                	push   $0x0
c002234e:	6a 62                	push   $0x62
c0022350:	e9 ee fb ff ff       	jmp    c0021f43 <intr_entry>

c0022355 <intr63_stub>:
c0022355:	55                   	push   %ebp
c0022356:	6a 00                	push   $0x0
c0022358:	6a 63                	push   $0x63
c002235a:	e9 e4 fb ff ff       	jmp    c0021f43 <intr_entry>

c002235f <intr64_stub>:
STUB(64, zero) STUB(65, zero) STUB(66, zero) STUB(67, zero)
c002235f:	55                   	push   %ebp
c0022360:	6a 00                	push   $0x0
c0022362:	6a 64                	push   $0x64
c0022364:	e9 da fb ff ff       	jmp    c0021f43 <intr_entry>

c0022369 <intr65_stub>:
c0022369:	55                   	push   %ebp
c002236a:	6a 00                	push   $0x0
c002236c:	6a 65                	push   $0x65
c002236e:	e9 d0 fb ff ff       	jmp    c0021f43 <intr_entry>

c0022373 <intr66_stub>:
c0022373:	55                   	push   %ebp
c0022374:	6a 00                	push   $0x0
c0022376:	6a 66                	push   $0x66
c0022378:	e9 c6 fb ff ff       	jmp    c0021f43 <intr_entry>

c002237d <intr67_stub>:
c002237d:	55                   	push   %ebp
c002237e:	6a 00                	push   $0x0
c0022380:	6a 67                	push   $0x67
c0022382:	e9 bc fb ff ff       	jmp    c0021f43 <intr_entry>

c0022387 <intr68_stub>:
STUB(68, zero) STUB(69, zero) STUB(6a, zero) STUB(6b, zero)
c0022387:	55                   	push   %ebp
c0022388:	6a 00                	push   $0x0
c002238a:	6a 68                	push   $0x68
c002238c:	e9 b2 fb ff ff       	jmp    c0021f43 <intr_entry>

c0022391 <intr69_stub>:
c0022391:	55                   	push   %ebp
c0022392:	6a 00                	push   $0x0
c0022394:	6a 69                	push   $0x69
c0022396:	e9 a8 fb ff ff       	jmp    c0021f43 <intr_entry>

c002239b <intr6a_stub>:
c002239b:	55                   	push   %ebp
c002239c:	6a 00                	push   $0x0
c002239e:	6a 6a                	push   $0x6a
c00223a0:	e9 9e fb ff ff       	jmp    c0021f43 <intr_entry>

c00223a5 <intr6b_stub>:
c00223a5:	55                   	push   %ebp
c00223a6:	6a 00                	push   $0x0
c00223a8:	6a 6b                	push   $0x6b
c00223aa:	e9 94 fb ff ff       	jmp    c0021f43 <intr_entry>

c00223af <intr6c_stub>:
STUB(6c, zero) STUB(6d, zero) STUB(6e, zero) STUB(6f, zero)
c00223af:	55                   	push   %ebp
c00223b0:	6a 00                	push   $0x0
c00223b2:	6a 6c                	push   $0x6c
c00223b4:	e9 8a fb ff ff       	jmp    c0021f43 <intr_entry>

c00223b9 <intr6d_stub>:
c00223b9:	55                   	push   %ebp
c00223ba:	6a 00                	push   $0x0
c00223bc:	6a 6d                	push   $0x6d
c00223be:	e9 80 fb ff ff       	jmp    c0021f43 <intr_entry>

c00223c3 <intr6e_stub>:
c00223c3:	55                   	push   %ebp
c00223c4:	6a 00                	push   $0x0
c00223c6:	6a 6e                	push   $0x6e
c00223c8:	e9 76 fb ff ff       	jmp    c0021f43 <intr_entry>

c00223cd <intr6f_stub>:
c00223cd:	55                   	push   %ebp
c00223ce:	6a 00                	push   $0x0
c00223d0:	6a 6f                	push   $0x6f
c00223d2:	e9 6c fb ff ff       	jmp    c0021f43 <intr_entry>

c00223d7 <intr70_stub>:

STUB(70, zero) STUB(71, zero) STUB(72, zero) STUB(73, zero)
c00223d7:	55                   	push   %ebp
c00223d8:	6a 00                	push   $0x0
c00223da:	6a 70                	push   $0x70
c00223dc:	e9 62 fb ff ff       	jmp    c0021f43 <intr_entry>

c00223e1 <intr71_stub>:
c00223e1:	55                   	push   %ebp
c00223e2:	6a 00                	push   $0x0
c00223e4:	6a 71                	push   $0x71
c00223e6:	e9 58 fb ff ff       	jmp    c0021f43 <intr_entry>

c00223eb <intr72_stub>:
c00223eb:	55                   	push   %ebp
c00223ec:	6a 00                	push   $0x0
c00223ee:	6a 72                	push   $0x72
c00223f0:	e9 4e fb ff ff       	jmp    c0021f43 <intr_entry>

c00223f5 <intr73_stub>:
c00223f5:	55                   	push   %ebp
c00223f6:	6a 00                	push   $0x0
c00223f8:	6a 73                	push   $0x73
c00223fa:	e9 44 fb ff ff       	jmp    c0021f43 <intr_entry>

c00223ff <intr74_stub>:
STUB(74, zero) STUB(75, zero) STUB(76, zero) STUB(77, zero)
c00223ff:	55                   	push   %ebp
c0022400:	6a 00                	push   $0x0
c0022402:	6a 74                	push   $0x74
c0022404:	e9 3a fb ff ff       	jmp    c0021f43 <intr_entry>

c0022409 <intr75_stub>:
c0022409:	55                   	push   %ebp
c002240a:	6a 00                	push   $0x0
c002240c:	6a 75                	push   $0x75
c002240e:	e9 30 fb ff ff       	jmp    c0021f43 <intr_entry>

c0022413 <intr76_stub>:
c0022413:	55                   	push   %ebp
c0022414:	6a 00                	push   $0x0
c0022416:	6a 76                	push   $0x76
c0022418:	e9 26 fb ff ff       	jmp    c0021f43 <intr_entry>

c002241d <intr77_stub>:
c002241d:	55                   	push   %ebp
c002241e:	6a 00                	push   $0x0
c0022420:	6a 77                	push   $0x77
c0022422:	e9 1c fb ff ff       	jmp    c0021f43 <intr_entry>

c0022427 <intr78_stub>:
STUB(78, zero) STUB(79, zero) STUB(7a, zero) STUB(7b, zero)
c0022427:	55                   	push   %ebp
c0022428:	6a 00                	push   $0x0
c002242a:	6a 78                	push   $0x78
c002242c:	e9 12 fb ff ff       	jmp    c0021f43 <intr_entry>

c0022431 <intr79_stub>:
c0022431:	55                   	push   %ebp
c0022432:	6a 00                	push   $0x0
c0022434:	6a 79                	push   $0x79
c0022436:	e9 08 fb ff ff       	jmp    c0021f43 <intr_entry>

c002243b <intr7a_stub>:
c002243b:	55                   	push   %ebp
c002243c:	6a 00                	push   $0x0
c002243e:	6a 7a                	push   $0x7a
c0022440:	e9 fe fa ff ff       	jmp    c0021f43 <intr_entry>

c0022445 <intr7b_stub>:
c0022445:	55                   	push   %ebp
c0022446:	6a 00                	push   $0x0
c0022448:	6a 7b                	push   $0x7b
c002244a:	e9 f4 fa ff ff       	jmp    c0021f43 <intr_entry>

c002244f <intr7c_stub>:
STUB(7c, zero) STUB(7d, zero) STUB(7e, zero) STUB(7f, zero)
c002244f:	55                   	push   %ebp
c0022450:	6a 00                	push   $0x0
c0022452:	6a 7c                	push   $0x7c
c0022454:	e9 ea fa ff ff       	jmp    c0021f43 <intr_entry>

c0022459 <intr7d_stub>:
c0022459:	55                   	push   %ebp
c002245a:	6a 00                	push   $0x0
c002245c:	6a 7d                	push   $0x7d
c002245e:	e9 e0 fa ff ff       	jmp    c0021f43 <intr_entry>

c0022463 <intr7e_stub>:
c0022463:	55                   	push   %ebp
c0022464:	6a 00                	push   $0x0
c0022466:	6a 7e                	push   $0x7e
c0022468:	e9 d6 fa ff ff       	jmp    c0021f43 <intr_entry>

c002246d <intr7f_stub>:
c002246d:	55                   	push   %ebp
c002246e:	6a 00                	push   $0x0
c0022470:	6a 7f                	push   $0x7f
c0022472:	e9 cc fa ff ff       	jmp    c0021f43 <intr_entry>

c0022477 <intr80_stub>:

STUB(80, zero) STUB(81, zero) STUB(82, zero) STUB(83, zero)
c0022477:	55                   	push   %ebp
c0022478:	6a 00                	push   $0x0
c002247a:	68 80 00 00 00       	push   $0x80
c002247f:	e9 bf fa ff ff       	jmp    c0021f43 <intr_entry>

c0022484 <intr81_stub>:
c0022484:	55                   	push   %ebp
c0022485:	6a 00                	push   $0x0
c0022487:	68 81 00 00 00       	push   $0x81
c002248c:	e9 b2 fa ff ff       	jmp    c0021f43 <intr_entry>

c0022491 <intr82_stub>:
c0022491:	55                   	push   %ebp
c0022492:	6a 00                	push   $0x0
c0022494:	68 82 00 00 00       	push   $0x82
c0022499:	e9 a5 fa ff ff       	jmp    c0021f43 <intr_entry>

c002249e <intr83_stub>:
c002249e:	55                   	push   %ebp
c002249f:	6a 00                	push   $0x0
c00224a1:	68 83 00 00 00       	push   $0x83
c00224a6:	e9 98 fa ff ff       	jmp    c0021f43 <intr_entry>

c00224ab <intr84_stub>:
STUB(84, zero) STUB(85, zero) STUB(86, zero) STUB(87, zero)
c00224ab:	55                   	push   %ebp
c00224ac:	6a 00                	push   $0x0
c00224ae:	68 84 00 00 00       	push   $0x84
c00224b3:	e9 8b fa ff ff       	jmp    c0021f43 <intr_entry>

c00224b8 <intr85_stub>:
c00224b8:	55                   	push   %ebp
c00224b9:	6a 00                	push   $0x0
c00224bb:	68 85 00 00 00       	push   $0x85
c00224c0:	e9 7e fa ff ff       	jmp    c0021f43 <intr_entry>

c00224c5 <intr86_stub>:
c00224c5:	55                   	push   %ebp
c00224c6:	6a 00                	push   $0x0
c00224c8:	68 86 00 00 00       	push   $0x86
c00224cd:	e9 71 fa ff ff       	jmp    c0021f43 <intr_entry>

c00224d2 <intr87_stub>:
c00224d2:	55                   	push   %ebp
c00224d3:	6a 00                	push   $0x0
c00224d5:	68 87 00 00 00       	push   $0x87
c00224da:	e9 64 fa ff ff       	jmp    c0021f43 <intr_entry>

c00224df <intr88_stub>:
STUB(88, zero) STUB(89, zero) STUB(8a, zero) STUB(8b, zero)
c00224df:	55                   	push   %ebp
c00224e0:	6a 00                	push   $0x0
c00224e2:	68 88 00 00 00       	push   $0x88
c00224e7:	e9 57 fa ff ff       	jmp    c0021f43 <intr_entry>

c00224ec <intr89_stub>:
c00224ec:	55                   	push   %ebp
c00224ed:	6a 00                	push   $0x0
c00224ef:	68 89 00 00 00       	push   $0x89
c00224f4:	e9 4a fa ff ff       	jmp    c0021f43 <intr_entry>

c00224f9 <intr8a_stub>:
c00224f9:	55                   	push   %ebp
c00224fa:	6a 00                	push   $0x0
c00224fc:	68 8a 00 00 00       	push   $0x8a
c0022501:	e9 3d fa ff ff       	jmp    c0021f43 <intr_entry>

c0022506 <intr8b_stub>:
c0022506:	55                   	push   %ebp
c0022507:	6a 00                	push   $0x0
c0022509:	68 8b 00 00 00       	push   $0x8b
c002250e:	e9 30 fa ff ff       	jmp    c0021f43 <intr_entry>

c0022513 <intr8c_stub>:
STUB(8c, zero) STUB(8d, zero) STUB(8e, zero) STUB(8f, zero)
c0022513:	55                   	push   %ebp
c0022514:	6a 00                	push   $0x0
c0022516:	68 8c 00 00 00       	push   $0x8c
c002251b:	e9 23 fa ff ff       	jmp    c0021f43 <intr_entry>

c0022520 <intr8d_stub>:
c0022520:	55                   	push   %ebp
c0022521:	6a 00                	push   $0x0
c0022523:	68 8d 00 00 00       	push   $0x8d
c0022528:	e9 16 fa ff ff       	jmp    c0021f43 <intr_entry>

c002252d <intr8e_stub>:
c002252d:	55                   	push   %ebp
c002252e:	6a 00                	push   $0x0
c0022530:	68 8e 00 00 00       	push   $0x8e
c0022535:	e9 09 fa ff ff       	jmp    c0021f43 <intr_entry>

c002253a <intr8f_stub>:
c002253a:	55                   	push   %ebp
c002253b:	6a 00                	push   $0x0
c002253d:	68 8f 00 00 00       	push   $0x8f
c0022542:	e9 fc f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022547 <intr90_stub>:

STUB(90, zero) STUB(91, zero) STUB(92, zero) STUB(93, zero)
c0022547:	55                   	push   %ebp
c0022548:	6a 00                	push   $0x0
c002254a:	68 90 00 00 00       	push   $0x90
c002254f:	e9 ef f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022554 <intr91_stub>:
c0022554:	55                   	push   %ebp
c0022555:	6a 00                	push   $0x0
c0022557:	68 91 00 00 00       	push   $0x91
c002255c:	e9 e2 f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022561 <intr92_stub>:
c0022561:	55                   	push   %ebp
c0022562:	6a 00                	push   $0x0
c0022564:	68 92 00 00 00       	push   $0x92
c0022569:	e9 d5 f9 ff ff       	jmp    c0021f43 <intr_entry>

c002256e <intr93_stub>:
c002256e:	55                   	push   %ebp
c002256f:	6a 00                	push   $0x0
c0022571:	68 93 00 00 00       	push   $0x93
c0022576:	e9 c8 f9 ff ff       	jmp    c0021f43 <intr_entry>

c002257b <intr94_stub>:
STUB(94, zero) STUB(95, zero) STUB(96, zero) STUB(97, zero)
c002257b:	55                   	push   %ebp
c002257c:	6a 00                	push   $0x0
c002257e:	68 94 00 00 00       	push   $0x94
c0022583:	e9 bb f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022588 <intr95_stub>:
c0022588:	55                   	push   %ebp
c0022589:	6a 00                	push   $0x0
c002258b:	68 95 00 00 00       	push   $0x95
c0022590:	e9 ae f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022595 <intr96_stub>:
c0022595:	55                   	push   %ebp
c0022596:	6a 00                	push   $0x0
c0022598:	68 96 00 00 00       	push   $0x96
c002259d:	e9 a1 f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225a2 <intr97_stub>:
c00225a2:	55                   	push   %ebp
c00225a3:	6a 00                	push   $0x0
c00225a5:	68 97 00 00 00       	push   $0x97
c00225aa:	e9 94 f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225af <intr98_stub>:
STUB(98, zero) STUB(99, zero) STUB(9a, zero) STUB(9b, zero)
c00225af:	55                   	push   %ebp
c00225b0:	6a 00                	push   $0x0
c00225b2:	68 98 00 00 00       	push   $0x98
c00225b7:	e9 87 f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225bc <intr99_stub>:
c00225bc:	55                   	push   %ebp
c00225bd:	6a 00                	push   $0x0
c00225bf:	68 99 00 00 00       	push   $0x99
c00225c4:	e9 7a f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225c9 <intr9a_stub>:
c00225c9:	55                   	push   %ebp
c00225ca:	6a 00                	push   $0x0
c00225cc:	68 9a 00 00 00       	push   $0x9a
c00225d1:	e9 6d f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225d6 <intr9b_stub>:
c00225d6:	55                   	push   %ebp
c00225d7:	6a 00                	push   $0x0
c00225d9:	68 9b 00 00 00       	push   $0x9b
c00225de:	e9 60 f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225e3 <intr9c_stub>:
STUB(9c, zero) STUB(9d, zero) STUB(9e, zero) STUB(9f, zero)
c00225e3:	55                   	push   %ebp
c00225e4:	6a 00                	push   $0x0
c00225e6:	68 9c 00 00 00       	push   $0x9c
c00225eb:	e9 53 f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225f0 <intr9d_stub>:
c00225f0:	55                   	push   %ebp
c00225f1:	6a 00                	push   $0x0
c00225f3:	68 9d 00 00 00       	push   $0x9d
c00225f8:	e9 46 f9 ff ff       	jmp    c0021f43 <intr_entry>

c00225fd <intr9e_stub>:
c00225fd:	55                   	push   %ebp
c00225fe:	6a 00                	push   $0x0
c0022600:	68 9e 00 00 00       	push   $0x9e
c0022605:	e9 39 f9 ff ff       	jmp    c0021f43 <intr_entry>

c002260a <intr9f_stub>:
c002260a:	55                   	push   %ebp
c002260b:	6a 00                	push   $0x0
c002260d:	68 9f 00 00 00       	push   $0x9f
c0022612:	e9 2c f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022617 <intra0_stub>:

STUB(a0, zero) STUB(a1, zero) STUB(a2, zero) STUB(a3, zero)
c0022617:	55                   	push   %ebp
c0022618:	6a 00                	push   $0x0
c002261a:	68 a0 00 00 00       	push   $0xa0
c002261f:	e9 1f f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022624 <intra1_stub>:
c0022624:	55                   	push   %ebp
c0022625:	6a 00                	push   $0x0
c0022627:	68 a1 00 00 00       	push   $0xa1
c002262c:	e9 12 f9 ff ff       	jmp    c0021f43 <intr_entry>

c0022631 <intra2_stub>:
c0022631:	55                   	push   %ebp
c0022632:	6a 00                	push   $0x0
c0022634:	68 a2 00 00 00       	push   $0xa2
c0022639:	e9 05 f9 ff ff       	jmp    c0021f43 <intr_entry>

c002263e <intra3_stub>:
c002263e:	55                   	push   %ebp
c002263f:	6a 00                	push   $0x0
c0022641:	68 a3 00 00 00       	push   $0xa3
c0022646:	e9 f8 f8 ff ff       	jmp    c0021f43 <intr_entry>

c002264b <intra4_stub>:
STUB(a4, zero) STUB(a5, zero) STUB(a6, zero) STUB(a7, zero)
c002264b:	55                   	push   %ebp
c002264c:	6a 00                	push   $0x0
c002264e:	68 a4 00 00 00       	push   $0xa4
c0022653:	e9 eb f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022658 <intra5_stub>:
c0022658:	55                   	push   %ebp
c0022659:	6a 00                	push   $0x0
c002265b:	68 a5 00 00 00       	push   $0xa5
c0022660:	e9 de f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022665 <intra6_stub>:
c0022665:	55                   	push   %ebp
c0022666:	6a 00                	push   $0x0
c0022668:	68 a6 00 00 00       	push   $0xa6
c002266d:	e9 d1 f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022672 <intra7_stub>:
c0022672:	55                   	push   %ebp
c0022673:	6a 00                	push   $0x0
c0022675:	68 a7 00 00 00       	push   $0xa7
c002267a:	e9 c4 f8 ff ff       	jmp    c0021f43 <intr_entry>

c002267f <intra8_stub>:
STUB(a8, zero) STUB(a9, zero) STUB(aa, zero) STUB(ab, zero)
c002267f:	55                   	push   %ebp
c0022680:	6a 00                	push   $0x0
c0022682:	68 a8 00 00 00       	push   $0xa8
c0022687:	e9 b7 f8 ff ff       	jmp    c0021f43 <intr_entry>

c002268c <intra9_stub>:
c002268c:	55                   	push   %ebp
c002268d:	6a 00                	push   $0x0
c002268f:	68 a9 00 00 00       	push   $0xa9
c0022694:	e9 aa f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022699 <intraa_stub>:
c0022699:	55                   	push   %ebp
c002269a:	6a 00                	push   $0x0
c002269c:	68 aa 00 00 00       	push   $0xaa
c00226a1:	e9 9d f8 ff ff       	jmp    c0021f43 <intr_entry>

c00226a6 <intrab_stub>:
c00226a6:	55                   	push   %ebp
c00226a7:	6a 00                	push   $0x0
c00226a9:	68 ab 00 00 00       	push   $0xab
c00226ae:	e9 90 f8 ff ff       	jmp    c0021f43 <intr_entry>

c00226b3 <intrac_stub>:
STUB(ac, zero) STUB(ad, zero) STUB(ae, zero) STUB(af, zero)
c00226b3:	55                   	push   %ebp
c00226b4:	6a 00                	push   $0x0
c00226b6:	68 ac 00 00 00       	push   $0xac
c00226bb:	e9 83 f8 ff ff       	jmp    c0021f43 <intr_entry>

c00226c0 <intrad_stub>:
c00226c0:	55                   	push   %ebp
c00226c1:	6a 00                	push   $0x0
c00226c3:	68 ad 00 00 00       	push   $0xad
c00226c8:	e9 76 f8 ff ff       	jmp    c0021f43 <intr_entry>

c00226cd <intrae_stub>:
c00226cd:	55                   	push   %ebp
c00226ce:	6a 00                	push   $0x0
c00226d0:	68 ae 00 00 00       	push   $0xae
c00226d5:	e9 69 f8 ff ff       	jmp    c0021f43 <intr_entry>

c00226da <intraf_stub>:
c00226da:	55                   	push   %ebp
c00226db:	6a 00                	push   $0x0
c00226dd:	68 af 00 00 00       	push   $0xaf
c00226e2:	e9 5c f8 ff ff       	jmp    c0021f43 <intr_entry>

c00226e7 <intrb0_stub>:

STUB(b0, zero) STUB(b1, zero) STUB(b2, zero) STUB(b3, zero)
c00226e7:	55                   	push   %ebp
c00226e8:	6a 00                	push   $0x0
c00226ea:	68 b0 00 00 00       	push   $0xb0
c00226ef:	e9 4f f8 ff ff       	jmp    c0021f43 <intr_entry>

c00226f4 <intrb1_stub>:
c00226f4:	55                   	push   %ebp
c00226f5:	6a 00                	push   $0x0
c00226f7:	68 b1 00 00 00       	push   $0xb1
c00226fc:	e9 42 f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022701 <intrb2_stub>:
c0022701:	55                   	push   %ebp
c0022702:	6a 00                	push   $0x0
c0022704:	68 b2 00 00 00       	push   $0xb2
c0022709:	e9 35 f8 ff ff       	jmp    c0021f43 <intr_entry>

c002270e <intrb3_stub>:
c002270e:	55                   	push   %ebp
c002270f:	6a 00                	push   $0x0
c0022711:	68 b3 00 00 00       	push   $0xb3
c0022716:	e9 28 f8 ff ff       	jmp    c0021f43 <intr_entry>

c002271b <intrb4_stub>:
STUB(b4, zero) STUB(b5, zero) STUB(b6, zero) STUB(b7, zero)
c002271b:	55                   	push   %ebp
c002271c:	6a 00                	push   $0x0
c002271e:	68 b4 00 00 00       	push   $0xb4
c0022723:	e9 1b f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022728 <intrb5_stub>:
c0022728:	55                   	push   %ebp
c0022729:	6a 00                	push   $0x0
c002272b:	68 b5 00 00 00       	push   $0xb5
c0022730:	e9 0e f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022735 <intrb6_stub>:
c0022735:	55                   	push   %ebp
c0022736:	6a 00                	push   $0x0
c0022738:	68 b6 00 00 00       	push   $0xb6
c002273d:	e9 01 f8 ff ff       	jmp    c0021f43 <intr_entry>

c0022742 <intrb7_stub>:
c0022742:	55                   	push   %ebp
c0022743:	6a 00                	push   $0x0
c0022745:	68 b7 00 00 00       	push   $0xb7
c002274a:	e9 f4 f7 ff ff       	jmp    c0021f43 <intr_entry>

c002274f <intrb8_stub>:
STUB(b8, zero) STUB(b9, zero) STUB(ba, zero) STUB(bb, zero)
c002274f:	55                   	push   %ebp
c0022750:	6a 00                	push   $0x0
c0022752:	68 b8 00 00 00       	push   $0xb8
c0022757:	e9 e7 f7 ff ff       	jmp    c0021f43 <intr_entry>

c002275c <intrb9_stub>:
c002275c:	55                   	push   %ebp
c002275d:	6a 00                	push   $0x0
c002275f:	68 b9 00 00 00       	push   $0xb9
c0022764:	e9 da f7 ff ff       	jmp    c0021f43 <intr_entry>

c0022769 <intrba_stub>:
c0022769:	55                   	push   %ebp
c002276a:	6a 00                	push   $0x0
c002276c:	68 ba 00 00 00       	push   $0xba
c0022771:	e9 cd f7 ff ff       	jmp    c0021f43 <intr_entry>

c0022776 <intrbb_stub>:
c0022776:	55                   	push   %ebp
c0022777:	6a 00                	push   $0x0
c0022779:	68 bb 00 00 00       	push   $0xbb
c002277e:	e9 c0 f7 ff ff       	jmp    c0021f43 <intr_entry>

c0022783 <intrbc_stub>:
STUB(bc, zero) STUB(bd, zero) STUB(be, zero) STUB(bf, zero)
c0022783:	55                   	push   %ebp
c0022784:	6a 00                	push   $0x0
c0022786:	68 bc 00 00 00       	push   $0xbc
c002278b:	e9 b3 f7 ff ff       	jmp    c0021f43 <intr_entry>

c0022790 <intrbd_stub>:
c0022790:	55                   	push   %ebp
c0022791:	6a 00                	push   $0x0
c0022793:	68 bd 00 00 00       	push   $0xbd
c0022798:	e9 a6 f7 ff ff       	jmp    c0021f43 <intr_entry>

c002279d <intrbe_stub>:
c002279d:	55                   	push   %ebp
c002279e:	6a 00                	push   $0x0
c00227a0:	68 be 00 00 00       	push   $0xbe
c00227a5:	e9 99 f7 ff ff       	jmp    c0021f43 <intr_entry>

c00227aa <intrbf_stub>:
c00227aa:	55                   	push   %ebp
c00227ab:	6a 00                	push   $0x0
c00227ad:	68 bf 00 00 00       	push   $0xbf
c00227b2:	e9 8c f7 ff ff       	jmp    c0021f43 <intr_entry>

c00227b7 <intrc0_stub>:

STUB(c0, zero) STUB(c1, zero) STUB(c2, zero) STUB(c3, zero)
c00227b7:	55                   	push   %ebp
c00227b8:	6a 00                	push   $0x0
c00227ba:	68 c0 00 00 00       	push   $0xc0
c00227bf:	e9 7f f7 ff ff       	jmp    c0021f43 <intr_entry>

c00227c4 <intrc1_stub>:
c00227c4:	55                   	push   %ebp
c00227c5:	6a 00                	push   $0x0
c00227c7:	68 c1 00 00 00       	push   $0xc1
c00227cc:	e9 72 f7 ff ff       	jmp    c0021f43 <intr_entry>

c00227d1 <intrc2_stub>:
c00227d1:	55                   	push   %ebp
c00227d2:	6a 00                	push   $0x0
c00227d4:	68 c2 00 00 00       	push   $0xc2
c00227d9:	e9 65 f7 ff ff       	jmp    c0021f43 <intr_entry>

c00227de <intrc3_stub>:
c00227de:	55                   	push   %ebp
c00227df:	6a 00                	push   $0x0
c00227e1:	68 c3 00 00 00       	push   $0xc3
c00227e6:	e9 58 f7 ff ff       	jmp    c0021f43 <intr_entry>

c00227eb <intrc4_stub>:
STUB(c4, zero) STUB(c5, zero) STUB(c6, zero) STUB(c7, zero)
c00227eb:	55                   	push   %ebp
c00227ec:	6a 00                	push   $0x0
c00227ee:	68 c4 00 00 00       	push   $0xc4
c00227f3:	e9 4b f7 ff ff       	jmp    c0021f43 <intr_entry>

c00227f8 <intrc5_stub>:
c00227f8:	55                   	push   %ebp
c00227f9:	6a 00                	push   $0x0
c00227fb:	68 c5 00 00 00       	push   $0xc5
c0022800:	e9 3e f7 ff ff       	jmp    c0021f43 <intr_entry>

c0022805 <intrc6_stub>:
c0022805:	55                   	push   %ebp
c0022806:	6a 00                	push   $0x0
c0022808:	68 c6 00 00 00       	push   $0xc6
c002280d:	e9 31 f7 ff ff       	jmp    c0021f43 <intr_entry>

c0022812 <intrc7_stub>:
c0022812:	55                   	push   %ebp
c0022813:	6a 00                	push   $0x0
c0022815:	68 c7 00 00 00       	push   $0xc7
c002281a:	e9 24 f7 ff ff       	jmp    c0021f43 <intr_entry>

c002281f <intrc8_stub>:
STUB(c8, zero) STUB(c9, zero) STUB(ca, zero) STUB(cb, zero)
c002281f:	55                   	push   %ebp
c0022820:	6a 00                	push   $0x0
c0022822:	68 c8 00 00 00       	push   $0xc8
c0022827:	e9 17 f7 ff ff       	jmp    c0021f43 <intr_entry>

c002282c <intrc9_stub>:
c002282c:	55                   	push   %ebp
c002282d:	6a 00                	push   $0x0
c002282f:	68 c9 00 00 00       	push   $0xc9
c0022834:	e9 0a f7 ff ff       	jmp    c0021f43 <intr_entry>

c0022839 <intrca_stub>:
c0022839:	55                   	push   %ebp
c002283a:	6a 00                	push   $0x0
c002283c:	68 ca 00 00 00       	push   $0xca
c0022841:	e9 fd f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022846 <intrcb_stub>:
c0022846:	55                   	push   %ebp
c0022847:	6a 00                	push   $0x0
c0022849:	68 cb 00 00 00       	push   $0xcb
c002284e:	e9 f0 f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022853 <intrcc_stub>:
STUB(cc, zero) STUB(cd, zero) STUB(ce, zero) STUB(cf, zero)
c0022853:	55                   	push   %ebp
c0022854:	6a 00                	push   $0x0
c0022856:	68 cc 00 00 00       	push   $0xcc
c002285b:	e9 e3 f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022860 <intrcd_stub>:
c0022860:	55                   	push   %ebp
c0022861:	6a 00                	push   $0x0
c0022863:	68 cd 00 00 00       	push   $0xcd
c0022868:	e9 d6 f6 ff ff       	jmp    c0021f43 <intr_entry>

c002286d <intrce_stub>:
c002286d:	55                   	push   %ebp
c002286e:	6a 00                	push   $0x0
c0022870:	68 ce 00 00 00       	push   $0xce
c0022875:	e9 c9 f6 ff ff       	jmp    c0021f43 <intr_entry>

c002287a <intrcf_stub>:
c002287a:	55                   	push   %ebp
c002287b:	6a 00                	push   $0x0
c002287d:	68 cf 00 00 00       	push   $0xcf
c0022882:	e9 bc f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022887 <intrd0_stub>:

STUB(d0, zero) STUB(d1, zero) STUB(d2, zero) STUB(d3, zero)
c0022887:	55                   	push   %ebp
c0022888:	6a 00                	push   $0x0
c002288a:	68 d0 00 00 00       	push   $0xd0
c002288f:	e9 af f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022894 <intrd1_stub>:
c0022894:	55                   	push   %ebp
c0022895:	6a 00                	push   $0x0
c0022897:	68 d1 00 00 00       	push   $0xd1
c002289c:	e9 a2 f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228a1 <intrd2_stub>:
c00228a1:	55                   	push   %ebp
c00228a2:	6a 00                	push   $0x0
c00228a4:	68 d2 00 00 00       	push   $0xd2
c00228a9:	e9 95 f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228ae <intrd3_stub>:
c00228ae:	55                   	push   %ebp
c00228af:	6a 00                	push   $0x0
c00228b1:	68 d3 00 00 00       	push   $0xd3
c00228b6:	e9 88 f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228bb <intrd4_stub>:
STUB(d4, zero) STUB(d5, zero) STUB(d6, zero) STUB(d7, zero)
c00228bb:	55                   	push   %ebp
c00228bc:	6a 00                	push   $0x0
c00228be:	68 d4 00 00 00       	push   $0xd4
c00228c3:	e9 7b f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228c8 <intrd5_stub>:
c00228c8:	55                   	push   %ebp
c00228c9:	6a 00                	push   $0x0
c00228cb:	68 d5 00 00 00       	push   $0xd5
c00228d0:	e9 6e f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228d5 <intrd6_stub>:
c00228d5:	55                   	push   %ebp
c00228d6:	6a 00                	push   $0x0
c00228d8:	68 d6 00 00 00       	push   $0xd6
c00228dd:	e9 61 f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228e2 <intrd7_stub>:
c00228e2:	55                   	push   %ebp
c00228e3:	6a 00                	push   $0x0
c00228e5:	68 d7 00 00 00       	push   $0xd7
c00228ea:	e9 54 f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228ef <intrd8_stub>:
STUB(d8, zero) STUB(d9, zero) STUB(da, zero) STUB(db, zero)
c00228ef:	55                   	push   %ebp
c00228f0:	6a 00                	push   $0x0
c00228f2:	68 d8 00 00 00       	push   $0xd8
c00228f7:	e9 47 f6 ff ff       	jmp    c0021f43 <intr_entry>

c00228fc <intrd9_stub>:
c00228fc:	55                   	push   %ebp
c00228fd:	6a 00                	push   $0x0
c00228ff:	68 d9 00 00 00       	push   $0xd9
c0022904:	e9 3a f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022909 <intrda_stub>:
c0022909:	55                   	push   %ebp
c002290a:	6a 00                	push   $0x0
c002290c:	68 da 00 00 00       	push   $0xda
c0022911:	e9 2d f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022916 <intrdb_stub>:
c0022916:	55                   	push   %ebp
c0022917:	6a 00                	push   $0x0
c0022919:	68 db 00 00 00       	push   $0xdb
c002291e:	e9 20 f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022923 <intrdc_stub>:
STUB(dc, zero) STUB(dd, zero) STUB(de, zero) STUB(df, zero)
c0022923:	55                   	push   %ebp
c0022924:	6a 00                	push   $0x0
c0022926:	68 dc 00 00 00       	push   $0xdc
c002292b:	e9 13 f6 ff ff       	jmp    c0021f43 <intr_entry>

c0022930 <intrdd_stub>:
c0022930:	55                   	push   %ebp
c0022931:	6a 00                	push   $0x0
c0022933:	68 dd 00 00 00       	push   $0xdd
c0022938:	e9 06 f6 ff ff       	jmp    c0021f43 <intr_entry>

c002293d <intrde_stub>:
c002293d:	55                   	push   %ebp
c002293e:	6a 00                	push   $0x0
c0022940:	68 de 00 00 00       	push   $0xde
c0022945:	e9 f9 f5 ff ff       	jmp    c0021f43 <intr_entry>

c002294a <intrdf_stub>:
c002294a:	55                   	push   %ebp
c002294b:	6a 00                	push   $0x0
c002294d:	68 df 00 00 00       	push   $0xdf
c0022952:	e9 ec f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022957 <intre0_stub>:

STUB(e0, zero) STUB(e1, zero) STUB(e2, zero) STUB(e3, zero)
c0022957:	55                   	push   %ebp
c0022958:	6a 00                	push   $0x0
c002295a:	68 e0 00 00 00       	push   $0xe0
c002295f:	e9 df f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022964 <intre1_stub>:
c0022964:	55                   	push   %ebp
c0022965:	6a 00                	push   $0x0
c0022967:	68 e1 00 00 00       	push   $0xe1
c002296c:	e9 d2 f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022971 <intre2_stub>:
c0022971:	55                   	push   %ebp
c0022972:	6a 00                	push   $0x0
c0022974:	68 e2 00 00 00       	push   $0xe2
c0022979:	e9 c5 f5 ff ff       	jmp    c0021f43 <intr_entry>

c002297e <intre3_stub>:
c002297e:	55                   	push   %ebp
c002297f:	6a 00                	push   $0x0
c0022981:	68 e3 00 00 00       	push   $0xe3
c0022986:	e9 b8 f5 ff ff       	jmp    c0021f43 <intr_entry>

c002298b <intre4_stub>:
STUB(e4, zero) STUB(e5, zero) STUB(e6, zero) STUB(e7, zero)
c002298b:	55                   	push   %ebp
c002298c:	6a 00                	push   $0x0
c002298e:	68 e4 00 00 00       	push   $0xe4
c0022993:	e9 ab f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022998 <intre5_stub>:
c0022998:	55                   	push   %ebp
c0022999:	6a 00                	push   $0x0
c002299b:	68 e5 00 00 00       	push   $0xe5
c00229a0:	e9 9e f5 ff ff       	jmp    c0021f43 <intr_entry>

c00229a5 <intre6_stub>:
c00229a5:	55                   	push   %ebp
c00229a6:	6a 00                	push   $0x0
c00229a8:	68 e6 00 00 00       	push   $0xe6
c00229ad:	e9 91 f5 ff ff       	jmp    c0021f43 <intr_entry>

c00229b2 <intre7_stub>:
c00229b2:	55                   	push   %ebp
c00229b3:	6a 00                	push   $0x0
c00229b5:	68 e7 00 00 00       	push   $0xe7
c00229ba:	e9 84 f5 ff ff       	jmp    c0021f43 <intr_entry>

c00229bf <intre8_stub>:
STUB(e8, zero) STUB(e9, zero) STUB(ea, zero) STUB(eb, zero)
c00229bf:	55                   	push   %ebp
c00229c0:	6a 00                	push   $0x0
c00229c2:	68 e8 00 00 00       	push   $0xe8
c00229c7:	e9 77 f5 ff ff       	jmp    c0021f43 <intr_entry>

c00229cc <intre9_stub>:
c00229cc:	55                   	push   %ebp
c00229cd:	6a 00                	push   $0x0
c00229cf:	68 e9 00 00 00       	push   $0xe9
c00229d4:	e9 6a f5 ff ff       	jmp    c0021f43 <intr_entry>

c00229d9 <intrea_stub>:
c00229d9:	55                   	push   %ebp
c00229da:	6a 00                	push   $0x0
c00229dc:	68 ea 00 00 00       	push   $0xea
c00229e1:	e9 5d f5 ff ff       	jmp    c0021f43 <intr_entry>

c00229e6 <intreb_stub>:
c00229e6:	55                   	push   %ebp
c00229e7:	6a 00                	push   $0x0
c00229e9:	68 eb 00 00 00       	push   $0xeb
c00229ee:	e9 50 f5 ff ff       	jmp    c0021f43 <intr_entry>

c00229f3 <intrec_stub>:
STUB(ec, zero) STUB(ed, zero) STUB(ee, zero) STUB(ef, zero)
c00229f3:	55                   	push   %ebp
c00229f4:	6a 00                	push   $0x0
c00229f6:	68 ec 00 00 00       	push   $0xec
c00229fb:	e9 43 f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022a00 <intred_stub>:
c0022a00:	55                   	push   %ebp
c0022a01:	6a 00                	push   $0x0
c0022a03:	68 ed 00 00 00       	push   $0xed
c0022a08:	e9 36 f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022a0d <intree_stub>:
c0022a0d:	55                   	push   %ebp
c0022a0e:	6a 00                	push   $0x0
c0022a10:	68 ee 00 00 00       	push   $0xee
c0022a15:	e9 29 f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022a1a <intref_stub>:
c0022a1a:	55                   	push   %ebp
c0022a1b:	6a 00                	push   $0x0
c0022a1d:	68 ef 00 00 00       	push   $0xef
c0022a22:	e9 1c f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022a27 <intrf0_stub>:

STUB(f0, zero) STUB(f1, zero) STUB(f2, zero) STUB(f3, zero)
c0022a27:	55                   	push   %ebp
c0022a28:	6a 00                	push   $0x0
c0022a2a:	68 f0 00 00 00       	push   $0xf0
c0022a2f:	e9 0f f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022a34 <intrf1_stub>:
c0022a34:	55                   	push   %ebp
c0022a35:	6a 00                	push   $0x0
c0022a37:	68 f1 00 00 00       	push   $0xf1
c0022a3c:	e9 02 f5 ff ff       	jmp    c0021f43 <intr_entry>

c0022a41 <intrf2_stub>:
c0022a41:	55                   	push   %ebp
c0022a42:	6a 00                	push   $0x0
c0022a44:	68 f2 00 00 00       	push   $0xf2
c0022a49:	e9 f5 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022a4e <intrf3_stub>:
c0022a4e:	55                   	push   %ebp
c0022a4f:	6a 00                	push   $0x0
c0022a51:	68 f3 00 00 00       	push   $0xf3
c0022a56:	e9 e8 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022a5b <intrf4_stub>:
STUB(f4, zero) STUB(f5, zero) STUB(f6, zero) STUB(f7, zero)
c0022a5b:	55                   	push   %ebp
c0022a5c:	6a 00                	push   $0x0
c0022a5e:	68 f4 00 00 00       	push   $0xf4
c0022a63:	e9 db f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022a68 <intrf5_stub>:
c0022a68:	55                   	push   %ebp
c0022a69:	6a 00                	push   $0x0
c0022a6b:	68 f5 00 00 00       	push   $0xf5
c0022a70:	e9 ce f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022a75 <intrf6_stub>:
c0022a75:	55                   	push   %ebp
c0022a76:	6a 00                	push   $0x0
c0022a78:	68 f6 00 00 00       	push   $0xf6
c0022a7d:	e9 c1 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022a82 <intrf7_stub>:
c0022a82:	55                   	push   %ebp
c0022a83:	6a 00                	push   $0x0
c0022a85:	68 f7 00 00 00       	push   $0xf7
c0022a8a:	e9 b4 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022a8f <intrf8_stub>:
STUB(f8, zero) STUB(f9, zero) STUB(fa, zero) STUB(fb, zero)
c0022a8f:	55                   	push   %ebp
c0022a90:	6a 00                	push   $0x0
c0022a92:	68 f8 00 00 00       	push   $0xf8
c0022a97:	e9 a7 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022a9c <intrf9_stub>:
c0022a9c:	55                   	push   %ebp
c0022a9d:	6a 00                	push   $0x0
c0022a9f:	68 f9 00 00 00       	push   $0xf9
c0022aa4:	e9 9a f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022aa9 <intrfa_stub>:
c0022aa9:	55                   	push   %ebp
c0022aaa:	6a 00                	push   $0x0
c0022aac:	68 fa 00 00 00       	push   $0xfa
c0022ab1:	e9 8d f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022ab6 <intrfb_stub>:
c0022ab6:	55                   	push   %ebp
c0022ab7:	6a 00                	push   $0x0
c0022ab9:	68 fb 00 00 00       	push   $0xfb
c0022abe:	e9 80 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022ac3 <intrfc_stub>:
STUB(fc, zero) STUB(fd, zero) STUB(fe, zero) STUB(ff, zero)
c0022ac3:	55                   	push   %ebp
c0022ac4:	6a 00                	push   $0x0
c0022ac6:	68 fc 00 00 00       	push   $0xfc
c0022acb:	e9 73 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022ad0 <intrfd_stub>:
c0022ad0:	55                   	push   %ebp
c0022ad1:	6a 00                	push   $0x0
c0022ad3:	68 fd 00 00 00       	push   $0xfd
c0022ad8:	e9 66 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022add <intrfe_stub>:
c0022add:	55                   	push   %ebp
c0022ade:	6a 00                	push   $0x0
c0022ae0:	68 fe 00 00 00       	push   $0xfe
c0022ae5:	e9 59 f4 ff ff       	jmp    c0021f43 <intr_entry>

c0022aea <intrff_stub>:
c0022aea:	55                   	push   %ebp
c0022aeb:	6a 00                	push   $0x0
c0022aed:	68 ff 00 00 00       	push   $0xff
c0022af2:	e9 4c f4 ff ff       	jmp    c0021f43 <intr_entry>
c0022af7:	90                   	nop
c0022af8:	90                   	nop
c0022af9:	90                   	nop
c0022afa:	90                   	nop
c0022afb:	90                   	nop
c0022afc:	90                   	nop
c0022afd:	90                   	nop
c0022afe:	90                   	nop
c0022aff:	90                   	nop

c0022b00 <threadPrioCompare>:
static bool threadPrioCompare(const struct list_elem *t1,
                             const struct list_elem *t2, void *aux UNUSED)
{ 
  const struct thread *tPointer1 = list_entry (t1, struct thread, elem);
  const struct thread *tPointer2 = list_entry (t2, struct thread, elem);
  if(tPointer1->priority < tPointer2->priority){
c0022b00:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022b04:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022b08:	8b 40 f4             	mov    -0xc(%eax),%eax
c0022b0b:	39 42 f4             	cmp    %eax,-0xc(%edx)
c0022b0e:	0f 9c c0             	setl   %al
    return true;
  }
  else{
    return false;
  }
}
c0022b11:	c3                   	ret    

c0022b12 <lockPrioCompare>:
static bool lockPrioCompare(const struct list_elem *l1,
                             const struct list_elem *l2, void *aux UNUSED)
{
  const struct lock *lPointer1 = list_entry (l1, struct lock, elem);
  const struct lock *lPointer2 = list_entry (l2, struct lock, elem);
  if(lPointer1->max_priority > lPointer2->max_priority) {
c0022b12:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022b16:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022b1a:	8b 40 08             	mov    0x8(%eax),%eax
c0022b1d:	39 42 08             	cmp    %eax,0x8(%edx)
c0022b20:	0f 9f c0             	setg   %al
    return true;
  }
  else {
    return false;
  }
}
c0022b23:	c3                   	ret    

c0022b24 <semaPrioCompare>:
static bool semaPrioCompare(const struct list_elem *s1,
                             const struct list_elem *s2, void *aux UNUSED)
{
  const struct semaphore_elem *sPointer1 = list_entry (s1, struct semaphore_elem, elem);
  const struct semaphore_elem *sPointer2 = list_entry (s2, struct semaphore_elem, elem);
  if(sPointer1->priority < sPointer2->priority){
c0022b24:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022b28:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022b2c:	8b 40 1c             	mov    0x1c(%eax),%eax
c0022b2f:	39 42 1c             	cmp    %eax,0x1c(%edx)
c0022b32:	0f 9c c0             	setl   %al
    return true;
  }
  else{
    return false;
  }
}
c0022b35:	c3                   	ret    

c0022b36 <sema_init>:
{
c0022b36:	83 ec 2c             	sub    $0x2c,%esp
c0022b39:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (sema != NULL);
c0022b3d:	85 c0                	test   %eax,%eax
c0022b3f:	75 2c                	jne    c0022b6d <sema_init+0x37>
c0022b41:	c7 44 24 10 56 ea 02 	movl   $0xc002ea56,0x10(%esp)
c0022b48:	c0 
c0022b49:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022b50:	c0 
c0022b51:	c7 44 24 08 a0 d2 02 	movl   $0xc002d2a0,0x8(%esp)
c0022b58:	c0 
c0022b59:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c0022b60:	00 
c0022b61:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022b68:	e8 56 5e 00 00       	call   c00289c3 <debug_panic>
  sema->value = value;
c0022b6d:	8b 54 24 34          	mov    0x34(%esp),%edx
c0022b71:	89 10                	mov    %edx,(%eax)
  list_init (&sema->waiters);
c0022b73:	83 c0 04             	add    $0x4,%eax
c0022b76:	89 04 24             	mov    %eax,(%esp)
c0022b79:	e8 12 5f 00 00       	call   c0028a90 <list_init>
}
c0022b7e:	83 c4 2c             	add    $0x2c,%esp
c0022b81:	c3                   	ret    

c0022b82 <sema_down>:
{
c0022b82:	57                   	push   %edi
c0022b83:	56                   	push   %esi
c0022b84:	53                   	push   %ebx
c0022b85:	83 ec 20             	sub    $0x20,%esp
c0022b88:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c0022b8c:	85 db                	test   %ebx,%ebx
c0022b8e:	75 2c                	jne    c0022bbc <sema_down+0x3a>
c0022b90:	c7 44 24 10 56 ea 02 	movl   $0xc002ea56,0x10(%esp)
c0022b97:	c0 
c0022b98:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022b9f:	c0 
c0022ba0:	c7 44 24 08 96 d2 02 	movl   $0xc002d296,0x8(%esp)
c0022ba7:	c0 
c0022ba8:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0022baf:	00 
c0022bb0:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022bb7:	e8 07 5e 00 00       	call   c00289c3 <debug_panic>
  ASSERT (!intr_context ());
c0022bbc:	e8 b0 f0 ff ff       	call   c0021c71 <intr_context>
c0022bc1:	84 c0                	test   %al,%al
c0022bc3:	74 2c                	je     c0022bf1 <sema_down+0x6f>
c0022bc5:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0022bcc:	c0 
c0022bcd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022bd4:	c0 
c0022bd5:	c7 44 24 08 96 d2 02 	movl   $0xc002d296,0x8(%esp)
c0022bdc:	c0 
c0022bdd:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c0022be4:	00 
c0022be5:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022bec:	e8 d2 5d 00 00       	call   c00289c3 <debug_panic>
  old_level = intr_disable ();
c0022bf1:	e8 19 ee ff ff       	call   c0021a0f <intr_disable>
c0022bf6:	89 c7                	mov    %eax,%edi
  while (sema->value == 0) 
c0022bf8:	8b 13                	mov    (%ebx),%edx
c0022bfa:	85 d2                	test   %edx,%edx
c0022bfc:	75 22                	jne    c0022c20 <sema_down+0x9e>
      list_push_back (&sema->waiters, &thread_current ()->elem);
c0022bfe:	8d 73 04             	lea    0x4(%ebx),%esi
c0022c01:	e8 27 e2 ff ff       	call   c0020e2d <thread_current>
c0022c06:	83 c0 28             	add    $0x28,%eax
c0022c09:	89 44 24 04          	mov    %eax,0x4(%esp)
c0022c0d:	89 34 24             	mov    %esi,(%esp)
c0022c10:	e8 fc 63 00 00       	call   c0029011 <list_push_back>
      thread_block ();
c0022c15:	e8 4b e7 ff ff       	call   c0021365 <thread_block>
  while (sema->value == 0) 
c0022c1a:	8b 13                	mov    (%ebx),%edx
c0022c1c:	85 d2                	test   %edx,%edx
c0022c1e:	74 e1                	je     c0022c01 <sema_down+0x7f>
  sema->value--;
c0022c20:	83 ea 01             	sub    $0x1,%edx
c0022c23:	89 13                	mov    %edx,(%ebx)
  intr_set_level (old_level);
c0022c25:	89 3c 24             	mov    %edi,(%esp)
c0022c28:	e8 e9 ed ff ff       	call   c0021a16 <intr_set_level>
}
c0022c2d:	83 c4 20             	add    $0x20,%esp
c0022c30:	5b                   	pop    %ebx
c0022c31:	5e                   	pop    %esi
c0022c32:	5f                   	pop    %edi
c0022c33:	c3                   	ret    

c0022c34 <sema_try_down>:
{
c0022c34:	56                   	push   %esi
c0022c35:	53                   	push   %ebx
c0022c36:	83 ec 24             	sub    $0x24,%esp
c0022c39:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c0022c3d:	85 db                	test   %ebx,%ebx
c0022c3f:	75 2c                	jne    c0022c6d <sema_try_down+0x39>
c0022c41:	c7 44 24 10 56 ea 02 	movl   $0xc002ea56,0x10(%esp)
c0022c48:	c0 
c0022c49:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022c50:	c0 
c0022c51:	c7 44 24 08 88 d2 02 	movl   $0xc002d288,0x8(%esp)
c0022c58:	c0 
c0022c59:	c7 44 24 04 61 00 00 	movl   $0x61,0x4(%esp)
c0022c60:	00 
c0022c61:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022c68:	e8 56 5d 00 00       	call   c00289c3 <debug_panic>
  old_level = intr_disable ();
c0022c6d:	e8 9d ed ff ff       	call   c0021a0f <intr_disable>
  if (sema->value > 0) 
c0022c72:	8b 13                	mov    (%ebx),%edx
    success = false;
c0022c74:	be 00 00 00 00       	mov    $0x0,%esi
  if (sema->value > 0) 
c0022c79:	85 d2                	test   %edx,%edx
c0022c7b:	74 0a                	je     c0022c87 <sema_try_down+0x53>
      sema->value--;
c0022c7d:	83 ea 01             	sub    $0x1,%edx
c0022c80:	89 13                	mov    %edx,(%ebx)
      success = true; 
c0022c82:	be 01 00 00 00       	mov    $0x1,%esi
  intr_set_level (old_level);
c0022c87:	89 04 24             	mov    %eax,(%esp)
c0022c8a:	e8 87 ed ff ff       	call   c0021a16 <intr_set_level>
}
c0022c8f:	89 f0                	mov    %esi,%eax
c0022c91:	83 c4 24             	add    $0x24,%esp
c0022c94:	5b                   	pop    %ebx
c0022c95:	5e                   	pop    %esi
c0022c96:	c3                   	ret    

c0022c97 <sema_up>:
{
c0022c97:	55                   	push   %ebp
c0022c98:	57                   	push   %edi
c0022c99:	56                   	push   %esi
c0022c9a:	53                   	push   %ebx
c0022c9b:	83 ec 2c             	sub    $0x2c,%esp
c0022c9e:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  ASSERT (sema != NULL);
c0022ca2:	85 db                	test   %ebx,%ebx
c0022ca4:	75 2c                	jne    c0022cd2 <sema_up+0x3b>
c0022ca6:	c7 44 24 10 56 ea 02 	movl   $0xc002ea56,0x10(%esp)
c0022cad:	c0 
c0022cae:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022cb5:	c0 
c0022cb6:	c7 44 24 08 80 d2 02 	movl   $0xc002d280,0x8(%esp)
c0022cbd:	c0 
c0022cbe:	c7 44 24 04 7c 00 00 	movl   $0x7c,0x4(%esp)
c0022cc5:	00 
c0022cc6:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022ccd:	e8 f1 5c 00 00       	call   c00289c3 <debug_panic>
  old_level = intr_disable ();
c0022cd2:	e8 38 ed ff ff       	call   c0021a0f <intr_disable>
c0022cd7:	89 c7                	mov    %eax,%edi
  if (!list_empty (&sema->waiters)) 
c0022cd9:	8d 73 04             	lea    0x4(%ebx),%esi
c0022cdc:	89 34 24             	mov    %esi,(%esp)
c0022cdf:	e8 e2 63 00 00       	call   c00290c6 <list_empty>
c0022ce4:	84 c0                	test   %al,%al
c0022ce6:	75 55                	jne    c0022d3d <sema_up+0xa6>
    max_prio_sema = list_max (&sema->waiters,threadPrioCompare,0);
c0022ce8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0022cef:	00 
c0022cf0:	c7 44 24 04 00 2b 02 	movl   $0xc0022b00,0x4(%esp)
c0022cf7:	c0 
c0022cf8:	89 34 24             	mov    %esi,(%esp)
c0022cfb:	e8 9a 69 00 00       	call   c002969a <list_max>
c0022d00:	89 c6                	mov    %eax,%esi
    list_remove(max_prio_sema);
c0022d02:	89 04 24             	mov    %eax,(%esp)
c0022d05:	e8 2a 63 00 00       	call   c0029034 <list_remove>
    freed_thread = list_entry(max_prio_sema,struct thread,elem);
c0022d0a:	8d 6e d8             	lea    -0x28(%esi),%ebp
    thread_unblock (freed_thread);
c0022d0d:	89 2c 24             	mov    %ebp,(%esp)
c0022d10:	e8 3f e0 ff ff       	call   c0020d54 <thread_unblock>
  sema->value++;
c0022d15:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022d18:	89 3c 24             	mov    %edi,(%esp)
c0022d1b:	e8 f6 ec ff ff       	call   c0021a16 <intr_set_level>
  if(old_level == INTR_ON && freed_thread!=NULL) {
c0022d20:	83 ff 01             	cmp    $0x1,%edi
c0022d23:	75 23                	jne    c0022d48 <sema_up+0xb1>
c0022d25:	85 ed                	test   %ebp,%ebp
c0022d27:	74 1f                	je     c0022d48 <sema_up+0xb1>
    if(thread_current()->priority < freed_thread->priority)
c0022d29:	e8 ff e0 ff ff       	call   c0020e2d <thread_current>
c0022d2e:	8b 56 f4             	mov    -0xc(%esi),%edx
c0022d31:	39 50 1c             	cmp    %edx,0x1c(%eax)
c0022d34:	7d 12                	jge    c0022d48 <sema_up+0xb1>
      thread_yield ();
c0022d36:	e8 a4 e7 ff ff       	call   c00214df <thread_yield>
c0022d3b:	eb 0b                	jmp    c0022d48 <sema_up+0xb1>
  sema->value++;
c0022d3d:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022d40:	89 3c 24             	mov    %edi,(%esp)
c0022d43:	e8 ce ec ff ff       	call   c0021a16 <intr_set_level>
}
c0022d48:	83 c4 2c             	add    $0x2c,%esp
c0022d4b:	5b                   	pop    %ebx
c0022d4c:	5e                   	pop    %esi
c0022d4d:	5f                   	pop    %edi
c0022d4e:	5d                   	pop    %ebp
c0022d4f:	c3                   	ret    

c0022d50 <sema_test_helper>:
{
c0022d50:	57                   	push   %edi
c0022d51:	56                   	push   %esi
c0022d52:	53                   	push   %ebx
c0022d53:	83 ec 10             	sub    $0x10,%esp
c0022d56:	8b 74 24 20          	mov    0x20(%esp),%esi
c0022d5a:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[1]);
c0022d5f:	8d 7e 14             	lea    0x14(%esi),%edi
      sema_down (&sema[0]);
c0022d62:	89 34 24             	mov    %esi,(%esp)
c0022d65:	e8 18 fe ff ff       	call   c0022b82 <sema_down>
      sema_up (&sema[1]);
c0022d6a:	89 3c 24             	mov    %edi,(%esp)
c0022d6d:	e8 25 ff ff ff       	call   c0022c97 <sema_up>
  for (i = 0; i < 10; i++) 
c0022d72:	83 eb 01             	sub    $0x1,%ebx
c0022d75:	75 eb                	jne    c0022d62 <sema_test_helper+0x12>
}
c0022d77:	83 c4 10             	add    $0x10,%esp
c0022d7a:	5b                   	pop    %ebx
c0022d7b:	5e                   	pop    %esi
c0022d7c:	5f                   	pop    %edi
c0022d7d:	c3                   	ret    

c0022d7e <sema_self_test>:
{
c0022d7e:	57                   	push   %edi
c0022d7f:	56                   	push   %esi
c0022d80:	53                   	push   %ebx
c0022d81:	83 ec 40             	sub    $0x40,%esp
  printf ("Testing semaphores...");
c0022d84:	c7 04 24 79 ea 02 c0 	movl   $0xc002ea79,(%esp)
c0022d8b:	e8 de 3d 00 00       	call   c0026b6e <printf>
  sema_init (&sema[0], 0);
c0022d90:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022d97:	00 
c0022d98:	8d 5c 24 18          	lea    0x18(%esp),%ebx
c0022d9c:	89 1c 24             	mov    %ebx,(%esp)
c0022d9f:	e8 92 fd ff ff       	call   c0022b36 <sema_init>
  sema_init (&sema[1], 0);
c0022da4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022dab:	00 
c0022dac:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c0022db0:	89 04 24             	mov    %eax,(%esp)
c0022db3:	e8 7e fd ff ff       	call   c0022b36 <sema_init>
  thread_create ("sema-test", PRI_DEFAULT, sema_test_helper, &sema);
c0022db8:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0022dbc:	c7 44 24 08 50 2d 02 	movl   $0xc0022d50,0x8(%esp)
c0022dc3:	c0 
c0022dc4:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c0022dcb:	00 
c0022dcc:	c7 04 24 8f ea 02 c0 	movl   $0xc002ea8f,(%esp)
c0022dd3:	e8 a9 e7 ff ff       	call   c0021581 <thread_create>
c0022dd8:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[0]);
c0022ddd:	8d 7c 24 18          	lea    0x18(%esp),%edi
      sema_down (&sema[1]);
c0022de1:	8d 74 24 2c          	lea    0x2c(%esp),%esi
      sema_up (&sema[0]);
c0022de5:	89 3c 24             	mov    %edi,(%esp)
c0022de8:	e8 aa fe ff ff       	call   c0022c97 <sema_up>
      sema_down (&sema[1]);
c0022ded:	89 34 24             	mov    %esi,(%esp)
c0022df0:	e8 8d fd ff ff       	call   c0022b82 <sema_down>
  for (i = 0; i < 10; i++) 
c0022df5:	83 eb 01             	sub    $0x1,%ebx
c0022df8:	75 eb                	jne    c0022de5 <sema_self_test+0x67>
  printf ("done.\n");
c0022dfa:	c7 04 24 99 ea 02 c0 	movl   $0xc002ea99,(%esp)
c0022e01:	e8 e5 78 00 00       	call   c002a6eb <puts>
}
c0022e06:	83 c4 40             	add    $0x40,%esp
c0022e09:	5b                   	pop    %ebx
c0022e0a:	5e                   	pop    %esi
c0022e0b:	5f                   	pop    %edi
c0022e0c:	c3                   	ret    

c0022e0d <lock_init>:
{
c0022e0d:	83 ec 2c             	sub    $0x2c,%esp
c0022e10:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022e14:	85 c0                	test   %eax,%eax
c0022e16:	75 2c                	jne    c0022e44 <lock_init+0x37>
c0022e18:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c0022e1f:	c0 
c0022e20:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022e27:	c0 
c0022e28:	c7 44 24 08 76 d2 02 	movl   $0xc002d276,0x8(%esp)
c0022e2f:	c0 
c0022e30:	c7 44 24 04 c7 00 00 	movl   $0xc7,0x4(%esp)
c0022e37:	00 
c0022e38:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022e3f:	e8 7f 5b 00 00       	call   c00289c3 <debug_panic>
  lock->holder = NULL;
c0022e44:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  sema_init (&lock->semaphore, 1);
c0022e4a:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0022e51:	00 
c0022e52:	83 c0 04             	add    $0x4,%eax
c0022e55:	89 04 24             	mov    %eax,(%esp)
c0022e58:	e8 d9 fc ff ff       	call   c0022b36 <sema_init>
}
c0022e5d:	83 c4 2c             	add    $0x2c,%esp
c0022e60:	c3                   	ret    

c0022e61 <lock_held_by_current_thread>:
{
c0022e61:	53                   	push   %ebx
c0022e62:	83 ec 28             	sub    $0x28,%esp
c0022e65:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022e69:	85 c0                	test   %eax,%eax
c0022e6b:	75 2c                	jne    c0022e99 <lock_held_by_current_thread+0x38>
c0022e6d:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c0022e74:	c0 
c0022e75:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022e7c:	c0 
c0022e7d:	c7 44 24 08 2f d2 02 	movl   $0xc002d22f,0x8(%esp)
c0022e84:	c0 
c0022e85:	c7 44 24 04 4c 01 00 	movl   $0x14c,0x4(%esp)
c0022e8c:	00 
c0022e8d:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022e94:	e8 2a 5b 00 00       	call   c00289c3 <debug_panic>
  return lock->holder == thread_current ();
c0022e99:	8b 18                	mov    (%eax),%ebx
c0022e9b:	e8 8d df ff ff       	call   c0020e2d <thread_current>
c0022ea0:	39 c3                	cmp    %eax,%ebx
c0022ea2:	0f 94 c0             	sete   %al
}
c0022ea5:	83 c4 28             	add    $0x28,%esp
c0022ea8:	5b                   	pop    %ebx
c0022ea9:	c3                   	ret    

c0022eaa <lock_acquire>:
{
c0022eaa:	56                   	push   %esi
c0022eab:	53                   	push   %ebx
c0022eac:	83 ec 24             	sub    $0x24,%esp
c0022eaf:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022eb3:	85 db                	test   %ebx,%ebx
c0022eb5:	75 2c                	jne    c0022ee3 <lock_acquire+0x39>
c0022eb7:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c0022ebe:	c0 
c0022ebf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022ec6:	c0 
c0022ec7:	c7 44 24 08 69 d2 02 	movl   $0xc002d269,0x8(%esp)
c0022ece:	c0 
c0022ecf:	c7 44 24 04 e8 00 00 	movl   $0xe8,0x4(%esp)
c0022ed6:	00 
c0022ed7:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022ede:	e8 e0 5a 00 00       	call   c00289c3 <debug_panic>
  ASSERT (!intr_context ());
c0022ee3:	e8 89 ed ff ff       	call   c0021c71 <intr_context>
c0022ee8:	84 c0                	test   %al,%al
c0022eea:	74 2c                	je     c0022f18 <lock_acquire+0x6e>
c0022eec:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0022ef3:	c0 
c0022ef4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022efb:	c0 
c0022efc:	c7 44 24 08 69 d2 02 	movl   $0xc002d269,0x8(%esp)
c0022f03:	c0 
c0022f04:	c7 44 24 04 e9 00 00 	movl   $0xe9,0x4(%esp)
c0022f0b:	00 
c0022f0c:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022f13:	e8 ab 5a 00 00       	call   c00289c3 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022f18:	89 1c 24             	mov    %ebx,(%esp)
c0022f1b:	e8 41 ff ff ff       	call   c0022e61 <lock_held_by_current_thread>
c0022f20:	84 c0                	test   %al,%al
c0022f22:	74 2c                	je     c0022f50 <lock_acquire+0xa6>
c0022f24:	c7 44 24 10 bc ea 02 	movl   $0xc002eabc,0x10(%esp)
c0022f2b:	c0 
c0022f2c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022f33:	c0 
c0022f34:	c7 44 24 08 69 d2 02 	movl   $0xc002d269,0x8(%esp)
c0022f3b:	c0 
c0022f3c:	c7 44 24 04 ea 00 00 	movl   $0xea,0x4(%esp)
c0022f43:	00 
c0022f44:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0022f4b:	e8 73 5a 00 00       	call   c00289c3 <debug_panic>
  old_level = intr_disable ();
c0022f50:	e8 ba ea ff ff       	call   c0021a0f <intr_disable>
c0022f55:	89 c6                	mov    %eax,%esi
  if(!thread_mlfqs && lock->holder != NULL)
c0022f57:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0022f5e:	75 20                	jne    c0022f80 <lock_acquire+0xd6>
c0022f60:	83 3b 00             	cmpl   $0x0,(%ebx)
c0022f63:	74 1b                	je     c0022f80 <lock_acquire+0xd6>
    int curr_prio = thread_get_priority();
c0022f65:	e8 24 e0 ff ff       	call   c0020f8e <thread_get_priority>
    struct lock * lock_copy = lock;
c0022f6a:	89 da                	mov    %ebx,%edx
        l_holder = lock_copy->holder;
c0022f6c:	8b 0a                	mov    (%edx),%ecx
        if( l_holder->priority < curr_prio)
c0022f6e:	3b 41 1c             	cmp    0x1c(%ecx),%eax
c0022f71:	7e 06                	jle    c0022f79 <lock_acquire+0xcf>
          l_holder->priority = curr_prio;
c0022f73:	89 41 1c             	mov    %eax,0x1c(%ecx)
          lock_copy->max_priority = curr_prio;
c0022f76:	89 42 20             	mov    %eax,0x20(%edx)
        lock_copy = l_holder->wait_on_lock;
c0022f79:	8b 51 50             	mov    0x50(%ecx),%edx
    while(lock_copy != NULL){ 
c0022f7c:	85 d2                	test   %edx,%edx
c0022f7e:	75 ec                	jne    c0022f6c <lock_acquire+0xc2>
  thread_current()->wait_on_lock = lock; //I'm waiting on this lock
c0022f80:	e8 a8 de ff ff       	call   c0020e2d <thread_current>
c0022f85:	89 58 50             	mov    %ebx,0x50(%eax)
  intr_set_level (old_level);
c0022f88:	89 34 24             	mov    %esi,(%esp)
c0022f8b:	e8 86 ea ff ff       	call   c0021a16 <intr_set_level>
  sema_down (&lock->semaphore);          //lock acquired
c0022f90:	8d 43 04             	lea    0x4(%ebx),%eax
c0022f93:	89 04 24             	mov    %eax,(%esp)
c0022f96:	e8 e7 fb ff ff       	call   c0022b82 <sema_down>
  lock->holder = thread_current ();      //Now I'm the owner of this lock
c0022f9b:	e8 8d de ff ff       	call   c0020e2d <thread_current>
c0022fa0:	89 03                	mov    %eax,(%ebx)
  thread_current()->wait_on_lock = NULL; //and now no more waiting for this lock
c0022fa2:	e8 86 de ff ff       	call   c0020e2d <thread_current>
c0022fa7:	c7 40 50 00 00 00 00 	movl   $0x0,0x50(%eax)
  list_insert_ordered(&(thread_current()->locks_held), &lock->elem, lockPrioCompare,NULL);
c0022fae:	e8 7a de ff ff       	call   c0020e2d <thread_current>
c0022fb3:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0022fba:	00 
c0022fbb:	c7 44 24 08 12 2b 02 	movl   $0xc0022b12,0x8(%esp)
c0022fc2:	c0 
c0022fc3:	8d 53 18             	lea    0x18(%ebx),%edx
c0022fc6:	89 54 24 04          	mov    %edx,0x4(%esp)
c0022fca:	83 c0 40             	add    $0x40,%eax
c0022fcd:	89 04 24             	mov    %eax,(%esp)
c0022fd0:	e8 e1 64 00 00       	call   c00294b6 <list_insert_ordered>
  lock->max_priority = thread_get_priority();
c0022fd5:	e8 b4 df ff ff       	call   c0020f8e <thread_get_priority>
c0022fda:	89 43 20             	mov    %eax,0x20(%ebx)
}
c0022fdd:	83 c4 24             	add    $0x24,%esp
c0022fe0:	5b                   	pop    %ebx
c0022fe1:	5e                   	pop    %esi
c0022fe2:	c3                   	ret    

c0022fe3 <lock_try_acquire>:
{
c0022fe3:	56                   	push   %esi
c0022fe4:	53                   	push   %ebx
c0022fe5:	83 ec 24             	sub    $0x24,%esp
c0022fe8:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022fec:	85 db                	test   %ebx,%ebx
c0022fee:	75 2c                	jne    c002301c <lock_try_acquire+0x39>
c0022ff0:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c0022ff7:	c0 
c0022ff8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0022fff:	c0 
c0023000:	c7 44 24 08 58 d2 02 	movl   $0xc002d258,0x8(%esp)
c0023007:	c0 
c0023008:	c7 44 24 04 15 01 00 	movl   $0x115,0x4(%esp)
c002300f:	00 
c0023010:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0023017:	e8 a7 59 00 00       	call   c00289c3 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c002301c:	89 1c 24             	mov    %ebx,(%esp)
c002301f:	e8 3d fe ff ff       	call   c0022e61 <lock_held_by_current_thread>
c0023024:	84 c0                	test   %al,%al
c0023026:	74 2c                	je     c0023054 <lock_try_acquire+0x71>
c0023028:	c7 44 24 10 bc ea 02 	movl   $0xc002eabc,0x10(%esp)
c002302f:	c0 
c0023030:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023037:	c0 
c0023038:	c7 44 24 08 58 d2 02 	movl   $0xc002d258,0x8(%esp)
c002303f:	c0 
c0023040:	c7 44 24 04 16 01 00 	movl   $0x116,0x4(%esp)
c0023047:	00 
c0023048:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c002304f:	e8 6f 59 00 00       	call   c00289c3 <debug_panic>
  success = sema_try_down (&lock->semaphore);
c0023054:	8d 43 04             	lea    0x4(%ebx),%eax
c0023057:	89 04 24             	mov    %eax,(%esp)
c002305a:	e8 d5 fb ff ff       	call   c0022c34 <sema_try_down>
c002305f:	89 c6                	mov    %eax,%esi
  if (success)
c0023061:	84 c0                	test   %al,%al
c0023063:	74 07                	je     c002306c <lock_try_acquire+0x89>
    lock->holder = thread_current ();
c0023065:	e8 c3 dd ff ff       	call   c0020e2d <thread_current>
c002306a:	89 03                	mov    %eax,(%ebx)
}
c002306c:	89 f0                	mov    %esi,%eax
c002306e:	83 c4 24             	add    $0x24,%esp
c0023071:	5b                   	pop    %ebx
c0023072:	5e                   	pop    %esi
c0023073:	c3                   	ret    

c0023074 <lock_release>:
{
c0023074:	57                   	push   %edi
c0023075:	56                   	push   %esi
c0023076:	53                   	push   %ebx
c0023077:	83 ec 20             	sub    $0x20,%esp
c002307a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c002307e:	85 db                	test   %ebx,%ebx
c0023080:	75 2c                	jne    c00230ae <lock_release+0x3a>
c0023082:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c0023089:	c0 
c002308a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023091:	c0 
c0023092:	c7 44 24 08 4b d2 02 	movl   $0xc002d24b,0x8(%esp)
c0023099:	c0 
c002309a:	c7 44 24 04 26 01 00 	movl   $0x126,0x4(%esp)
c00230a1:	00 
c00230a2:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c00230a9:	e8 15 59 00 00       	call   c00289c3 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c00230ae:	89 1c 24             	mov    %ebx,(%esp)
c00230b1:	e8 ab fd ff ff       	call   c0022e61 <lock_held_by_current_thread>
c00230b6:	84 c0                	test   %al,%al
c00230b8:	75 2c                	jne    c00230e6 <lock_release+0x72>
c00230ba:	c7 44 24 10 e0 ea 02 	movl   $0xc002eae0,0x10(%esp)
c00230c1:	c0 
c00230c2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00230c9:	c0 
c00230ca:	c7 44 24 08 4b d2 02 	movl   $0xc002d24b,0x8(%esp)
c00230d1:	c0 
c00230d2:	c7 44 24 04 27 01 00 	movl   $0x127,0x4(%esp)
c00230d9:	00 
c00230da:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c00230e1:	e8 dd 58 00 00       	call   c00289c3 <debug_panic>
  old_level = intr_disable ();
c00230e6:	e8 24 e9 ff ff       	call   c0021a0f <intr_disable>
c00230eb:	89 c6                	mov    %eax,%esi
  lock->holder = NULL;
c00230ed:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  lock->max_priority = -1;
c00230f3:	c7 43 20 ff ff ff ff 	movl   $0xffffffff,0x20(%ebx)
  list_remove(&lock->elem);
c00230fa:	8d 43 18             	lea    0x18(%ebx),%eax
c00230fd:	89 04 24             	mov    %eax,(%esp)
c0023100:	e8 2f 5f 00 00       	call   c0029034 <list_remove>
  if(!thread_mlfqs)
c0023105:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002310c:	75 45                	jne    c0023153 <lock_release+0xdf>
    if(!list_empty(&(thread_current()->locks_held)))
c002310e:	e8 1a dd ff ff       	call   c0020e2d <thread_current>
c0023113:	83 c0 40             	add    $0x40,%eax
c0023116:	89 04 24             	mov    %eax,(%esp)
c0023119:	e8 a8 5f 00 00       	call   c00290c6 <list_empty>
c002311e:	84 c0                	test   %al,%al
c0023120:	75 1f                	jne    c0023141 <lock_release+0xcd>
      struct list_elem *first_elem = list_begin(&(thread_current()->locks_held));
c0023122:	e8 06 dd ff ff       	call   c0020e2d <thread_current>
c0023127:	83 c0 40             	add    $0x40,%eax
c002312a:	89 04 24             	mov    %eax,(%esp)
c002312d:	e8 af 59 00 00       	call   c0028ae1 <list_begin>
c0023132:	89 c7                	mov    %eax,%edi
      thread_current()->priority = l->max_priority;
c0023134:	e8 f4 dc ff ff       	call   c0020e2d <thread_current>
c0023139:	8b 57 08             	mov    0x8(%edi),%edx
c002313c:	89 50 1c             	mov    %edx,0x1c(%eax)
c002313f:	eb 12                	jmp    c0023153 <lock_release+0xdf>
      thread_current()->priority = thread_current()->old_priority;
c0023141:	e8 e7 dc ff ff       	call   c0020e2d <thread_current>
c0023146:	89 c7                	mov    %eax,%edi
c0023148:	e8 e0 dc ff ff       	call   c0020e2d <thread_current>
c002314d:	8b 40 3c             	mov    0x3c(%eax),%eax
c0023150:	89 47 1c             	mov    %eax,0x1c(%edi)
  intr_set_level (old_level);
c0023153:	89 34 24             	mov    %esi,(%esp)
c0023156:	e8 bb e8 ff ff       	call   c0021a16 <intr_set_level>
  sema_up (&lock->semaphore);
c002315b:	83 c3 04             	add    $0x4,%ebx
c002315e:	89 1c 24             	mov    %ebx,(%esp)
c0023161:	e8 31 fb ff ff       	call   c0022c97 <sema_up>
}
c0023166:	83 c4 20             	add    $0x20,%esp
c0023169:	5b                   	pop    %ebx
c002316a:	5e                   	pop    %esi
c002316b:	5f                   	pop    %edi
c002316c:	c3                   	ret    

c002316d <cond_init>:
/* Initializes condition variable COND.  A condition variable
   allows one piece of code to signal a condition and cooperating
   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
c002316d:	83 ec 2c             	sub    $0x2c,%esp
c0023170:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (cond != NULL);
c0023174:	85 c0                	test   %eax,%eax
c0023176:	75 2c                	jne    c00231a4 <cond_init+0x37>
c0023178:	c7 44 24 10 ac ea 02 	movl   $0xc002eaac,0x10(%esp)
c002317f:	c0 
c0023180:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023187:	c0 
c0023188:	c7 44 24 08 25 d2 02 	movl   $0xc002d225,0x8(%esp)
c002318f:	c0 
c0023190:	c7 44 24 04 6f 01 00 	movl   $0x16f,0x4(%esp)
c0023197:	00 
c0023198:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c002319f:	e8 1f 58 00 00       	call   c00289c3 <debug_panic>

  list_init (&cond->waiters);
c00231a4:	89 04 24             	mov    %eax,(%esp)
c00231a7:	e8 e4 58 00 00       	call   c0028a90 <list_init>
}
c00231ac:	83 c4 2c             	add    $0x2c,%esp
c00231af:	c3                   	ret    

c00231b0 <cond_wait>:
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
cond_wait (struct condition *cond, struct lock *lock) 
{
c00231b0:	55                   	push   %ebp
c00231b1:	57                   	push   %edi
c00231b2:	56                   	push   %esi
c00231b3:	53                   	push   %ebx
c00231b4:	83 ec 4c             	sub    $0x4c,%esp
c00231b7:	8b 74 24 60          	mov    0x60(%esp),%esi
c00231bb:	8b 5c 24 64          	mov    0x64(%esp),%ebx
  struct semaphore_elem waiter;

  ASSERT (cond != NULL);
c00231bf:	85 f6                	test   %esi,%esi
c00231c1:	75 2c                	jne    c00231ef <cond_wait+0x3f>
c00231c3:	c7 44 24 10 ac ea 02 	movl   $0xc002eaac,0x10(%esp)
c00231ca:	c0 
c00231cb:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00231d2:	c0 
c00231d3:	c7 44 24 08 1b d2 02 	movl   $0xc002d21b,0x8(%esp)
c00231da:	c0 
c00231db:	c7 44 24 04 8a 01 00 	movl   $0x18a,0x4(%esp)
c00231e2:	00 
c00231e3:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c00231ea:	e8 d4 57 00 00       	call   c00289c3 <debug_panic>
  ASSERT (lock != NULL);
c00231ef:	85 db                	test   %ebx,%ebx
c00231f1:	75 2c                	jne    c002321f <cond_wait+0x6f>
c00231f3:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c00231fa:	c0 
c00231fb:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023202:	c0 
c0023203:	c7 44 24 08 1b d2 02 	movl   $0xc002d21b,0x8(%esp)
c002320a:	c0 
c002320b:	c7 44 24 04 8b 01 00 	movl   $0x18b,0x4(%esp)
c0023212:	00 
c0023213:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c002321a:	e8 a4 57 00 00       	call   c00289c3 <debug_panic>
  ASSERT (!intr_context ());
c002321f:	e8 4d ea ff ff       	call   c0021c71 <intr_context>
c0023224:	84 c0                	test   %al,%al
c0023226:	74 2c                	je     c0023254 <cond_wait+0xa4>
c0023228:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c002322f:	c0 
c0023230:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023237:	c0 
c0023238:	c7 44 24 08 1b d2 02 	movl   $0xc002d21b,0x8(%esp)
c002323f:	c0 
c0023240:	c7 44 24 04 8c 01 00 	movl   $0x18c,0x4(%esp)
c0023247:	00 
c0023248:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c002324f:	e8 6f 57 00 00       	call   c00289c3 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c0023254:	89 1c 24             	mov    %ebx,(%esp)
c0023257:	e8 05 fc ff ff       	call   c0022e61 <lock_held_by_current_thread>
c002325c:	84 c0                	test   %al,%al
c002325e:	75 2c                	jne    c002328c <cond_wait+0xdc>
c0023260:	c7 44 24 10 e0 ea 02 	movl   $0xc002eae0,0x10(%esp)
c0023267:	c0 
c0023268:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002326f:	c0 
c0023270:	c7 44 24 08 1b d2 02 	movl   $0xc002d21b,0x8(%esp)
c0023277:	c0 
c0023278:	c7 44 24 04 8d 01 00 	movl   $0x18d,0x4(%esp)
c002327f:	00 
c0023280:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0023287:	e8 37 57 00 00       	call   c00289c3 <debug_panic>
  
  sema_init (&waiter.semaphore, 0);
c002328c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023293:	00 
c0023294:	8d 6c 24 20          	lea    0x20(%esp),%ebp
c0023298:	8d 7c 24 28          	lea    0x28(%esp),%edi
c002329c:	89 3c 24             	mov    %edi,(%esp)
c002329f:	e8 92 f8 ff ff       	call   c0022b36 <sema_init>
  waiter.priority = thread_get_priority(); //(ADDED) sets sema's prio value to the threads prio
c00232a4:	e8 e5 dc ff ff       	call   c0020f8e <thread_get_priority>
c00232a9:	89 44 24 3c          	mov    %eax,0x3c(%esp)

  list_push_back (&cond->waiters, &waiter.elem);
c00232ad:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00232b1:	89 34 24             	mov    %esi,(%esp)
c00232b4:	e8 58 5d 00 00       	call   c0029011 <list_push_back>
  lock_release (lock);
c00232b9:	89 1c 24             	mov    %ebx,(%esp)
c00232bc:	e8 b3 fd ff ff       	call   c0023074 <lock_release>
  sema_down (&waiter.semaphore);
c00232c1:	89 3c 24             	mov    %edi,(%esp)
c00232c4:	e8 b9 f8 ff ff       	call   c0022b82 <sema_down>
  lock_acquire (lock);
c00232c9:	89 1c 24             	mov    %ebx,(%esp)
c00232cc:	e8 d9 fb ff ff       	call   c0022eaa <lock_acquire>
}
c00232d1:	83 c4 4c             	add    $0x4c,%esp
c00232d4:	5b                   	pop    %ebx
c00232d5:	5e                   	pop    %esi
c00232d6:	5f                   	pop    %edi
c00232d7:	5d                   	pop    %ebp
c00232d8:	c3                   	ret    

c00232d9 <cond_signal>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_signal (struct condition *cond, struct lock *lock UNUSED) 
{
c00232d9:	56                   	push   %esi
c00232da:	53                   	push   %ebx
c00232db:	83 ec 24             	sub    $0x24,%esp
c00232de:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00232e2:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c00232e6:	85 db                	test   %ebx,%ebx
c00232e8:	75 2c                	jne    c0023316 <cond_signal+0x3d>
c00232ea:	c7 44 24 10 ac ea 02 	movl   $0xc002eaac,0x10(%esp)
c00232f1:	c0 
c00232f2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00232f9:	c0 
c00232fa:	c7 44 24 08 0f d2 02 	movl   $0xc002d20f,0x8(%esp)
c0023301:	c0 
c0023302:	c7 44 24 04 a1 01 00 	movl   $0x1a1,0x4(%esp)
c0023309:	00 
c002330a:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0023311:	e8 ad 56 00 00       	call   c00289c3 <debug_panic>
  ASSERT (lock != NULL);
c0023316:	85 f6                	test   %esi,%esi
c0023318:	75 2c                	jne    c0023346 <cond_signal+0x6d>
c002331a:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c0023321:	c0 
c0023322:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023329:	c0 
c002332a:	c7 44 24 08 0f d2 02 	movl   $0xc002d20f,0x8(%esp)
c0023331:	c0 
c0023332:	c7 44 24 04 a2 01 00 	movl   $0x1a2,0x4(%esp)
c0023339:	00 
c002333a:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0023341:	e8 7d 56 00 00       	call   c00289c3 <debug_panic>
  ASSERT (!intr_context ());
c0023346:	e8 26 e9 ff ff       	call   c0021c71 <intr_context>
c002334b:	84 c0                	test   %al,%al
c002334d:	74 2c                	je     c002337b <cond_signal+0xa2>
c002334f:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0023356:	c0 
c0023357:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002335e:	c0 
c002335f:	c7 44 24 08 0f d2 02 	movl   $0xc002d20f,0x8(%esp)
c0023366:	c0 
c0023367:	c7 44 24 04 a3 01 00 	movl   $0x1a3,0x4(%esp)
c002336e:	00 
c002336f:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c0023376:	e8 48 56 00 00       	call   c00289c3 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c002337b:	89 34 24             	mov    %esi,(%esp)
c002337e:	e8 de fa ff ff       	call   c0022e61 <lock_held_by_current_thread>
c0023383:	84 c0                	test   %al,%al
c0023385:	75 2c                	jne    c00233b3 <cond_signal+0xda>
c0023387:	c7 44 24 10 e0 ea 02 	movl   $0xc002eae0,0x10(%esp)
c002338e:	c0 
c002338f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023396:	c0 
c0023397:	c7 44 24 08 0f d2 02 	movl   $0xc002d20f,0x8(%esp)
c002339e:	c0 
c002339f:	c7 44 24 04 a4 01 00 	movl   $0x1a4,0x4(%esp)
c00233a6:	00 
c00233a7:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c00233ae:	e8 10 56 00 00       	call   c00289c3 <debug_panic>

  struct list_elem *max_cond_waiter; //(ADDED) to be used below
  if (!list_empty (&cond->waiters)) 
c00233b3:	89 1c 24             	mov    %ebx,(%esp)
c00233b6:	e8 0b 5d 00 00       	call   c00290c6 <list_empty>
c00233bb:	84 c0                	test   %al,%al
c00233bd:	75 2d                	jne    c00233ec <cond_signal+0x113>
  {
    //(ADDED) wakes max prio thread
    /* MODIFY PRIORITY: max priority blocked thread on cond should be woken up */
    //sema_up (&list_entry (list_pop_front (&cond->waiters), struct semaphore_elem, elem)->semaphore);
    max_cond_waiter = list_max (&cond->waiters,semaPrioCompare,NULL);
c00233bf:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00233c6:	00 
c00233c7:	c7 44 24 04 24 2b 02 	movl   $0xc0022b24,0x4(%esp)
c00233ce:	c0 
c00233cf:	89 1c 24             	mov    %ebx,(%esp)
c00233d2:	e8 c3 62 00 00       	call   c002969a <list_max>
c00233d7:	89 c3                	mov    %eax,%ebx
    list_remove(max_cond_waiter);
c00233d9:	89 04 24             	mov    %eax,(%esp)
c00233dc:	e8 53 5c 00 00       	call   c0029034 <list_remove>
    sema_up (&list_entry(max_cond_waiter,struct semaphore_elem,elem)->semaphore);
c00233e1:	83 c3 08             	add    $0x8,%ebx
c00233e4:	89 1c 24             	mov    %ebx,(%esp)
c00233e7:	e8 ab f8 ff ff       	call   c0022c97 <sema_up>
  }
}
c00233ec:	83 c4 24             	add    $0x24,%esp
c00233ef:	5b                   	pop    %ebx
c00233f0:	5e                   	pop    %esi
c00233f1:	c3                   	ret    

c00233f2 <cond_broadcast>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock) 
{
c00233f2:	56                   	push   %esi
c00233f3:	53                   	push   %ebx
c00233f4:	83 ec 24             	sub    $0x24,%esp
c00233f7:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00233fb:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c00233ff:	85 db                	test   %ebx,%ebx
c0023401:	75 2c                	jne    c002342f <cond_broadcast+0x3d>
c0023403:	c7 44 24 10 ac ea 02 	movl   $0xc002eaac,0x10(%esp)
c002340a:	c0 
c002340b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023412:	c0 
c0023413:	c7 44 24 08 00 d2 02 	movl   $0xc002d200,0x8(%esp)
c002341a:	c0 
c002341b:	c7 44 24 04 ba 01 00 	movl   $0x1ba,0x4(%esp)
c0023422:	00 
c0023423:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c002342a:	e8 94 55 00 00       	call   c00289c3 <debug_panic>
  ASSERT (lock != NULL);
c002342f:	85 f6                	test   %esi,%esi
c0023431:	75 38                	jne    c002346b <cond_broadcast+0x79>
c0023433:	c7 44 24 10 9f ea 02 	movl   $0xc002ea9f,0x10(%esp)
c002343a:	c0 
c002343b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023442:	c0 
c0023443:	c7 44 24 08 00 d2 02 	movl   $0xc002d200,0x8(%esp)
c002344a:	c0 
c002344b:	c7 44 24 04 bb 01 00 	movl   $0x1bb,0x4(%esp)
c0023452:	00 
c0023453:	c7 04 24 63 ea 02 c0 	movl   $0xc002ea63,(%esp)
c002345a:	e8 64 55 00 00       	call   c00289c3 <debug_panic>

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
c002345f:	89 74 24 04          	mov    %esi,0x4(%esp)
c0023463:	89 1c 24             	mov    %ebx,(%esp)
c0023466:	e8 6e fe ff ff       	call   c00232d9 <cond_signal>
  while (!list_empty (&cond->waiters))
c002346b:	89 1c 24             	mov    %ebx,(%esp)
c002346e:	e8 53 5c 00 00       	call   c00290c6 <list_empty>
c0023473:	84 c0                	test   %al,%al
c0023475:	74 e8                	je     c002345f <cond_broadcast+0x6d>
c0023477:	83 c4 24             	add    $0x24,%esp
c002347a:	5b                   	pop    %ebx
c002347b:	5e                   	pop    %esi
c002347c:	c3                   	ret    

c002347d <init_pool>:

/* Initializes pool P as starting at START and ending at END,
   naming it NAME for debugging purposes. */
static void
init_pool (struct pool *p, void *base, size_t page_cnt, const char *name) 
{
c002347d:	55                   	push   %ebp
c002347e:	57                   	push   %edi
c002347f:	56                   	push   %esi
c0023480:	53                   	push   %ebx
c0023481:	83 ec 2c             	sub    $0x2c,%esp
c0023484:	89 c7                	mov    %eax,%edi
c0023486:	89 d5                	mov    %edx,%ebp
c0023488:	89 cb                	mov    %ecx,%ebx
  /* We'll put the pool's used_map at its base.
     Calculate the space needed for the bitmap
     and subtract it from the pool's size. */
  size_t bm_pages = DIV_ROUND_UP (bitmap_buf_size (page_cnt), PGSIZE);
c002348a:	89 0c 24             	mov    %ecx,(%esp)
c002348d:	e8 de 62 00 00       	call   c0029770 <bitmap_buf_size>
c0023492:	8d b0 ff 0f 00 00    	lea    0xfff(%eax),%esi
c0023498:	c1 ee 0c             	shr    $0xc,%esi
  if (bm_pages > page_cnt)
c002349b:	39 f3                	cmp    %esi,%ebx
c002349d:	73 2c                	jae    c00234cb <init_pool+0x4e>
    PANIC ("Not enough memory in %s for bitmap.", name);
c002349f:	8b 44 24 40          	mov    0x40(%esp),%eax
c00234a3:	89 44 24 10          	mov    %eax,0x10(%esp)
c00234a7:	c7 44 24 0c 04 eb 02 	movl   $0xc002eb04,0xc(%esp)
c00234ae:	c0 
c00234af:	c7 44 24 08 d3 d2 02 	movl   $0xc002d2d3,0x8(%esp)
c00234b6:	c0 
c00234b7:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c00234be:	00 
c00234bf:	c7 04 24 58 eb 02 c0 	movl   $0xc002eb58,(%esp)
c00234c6:	e8 f8 54 00 00       	call   c00289c3 <debug_panic>
  page_cnt -= bm_pages;
c00234cb:	29 f3                	sub    %esi,%ebx

  printf ("%zu pages available in %s.\n", page_cnt, name);
c00234cd:	8b 44 24 40          	mov    0x40(%esp),%eax
c00234d1:	89 44 24 08          	mov    %eax,0x8(%esp)
c00234d5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00234d9:	c7 04 24 6f eb 02 c0 	movl   $0xc002eb6f,(%esp)
c00234e0:	e8 89 36 00 00       	call   c0026b6e <printf>

  /* Initialize the pool. */
  lock_init (&p->lock);
c00234e5:	89 3c 24             	mov    %edi,(%esp)
c00234e8:	e8 20 f9 ff ff       	call   c0022e0d <lock_init>
  p->used_map = bitmap_create_in_buf (page_cnt, base, bm_pages * PGSIZE);
c00234ed:	c1 e6 0c             	shl    $0xc,%esi
c00234f0:	89 74 24 08          	mov    %esi,0x8(%esp)
c00234f4:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00234f8:	89 1c 24             	mov    %ebx,(%esp)
c00234fb:	e8 b5 65 00 00       	call   c0029ab5 <bitmap_create_in_buf>
c0023500:	89 47 24             	mov    %eax,0x24(%edi)
  p->base = base + bm_pages * PGSIZE;
c0023503:	01 ee                	add    %ebp,%esi
c0023505:	89 77 28             	mov    %esi,0x28(%edi)
}
c0023508:	83 c4 2c             	add    $0x2c,%esp
c002350b:	5b                   	pop    %ebx
c002350c:	5e                   	pop    %esi
c002350d:	5f                   	pop    %edi
c002350e:	5d                   	pop    %ebp
c002350f:	c3                   	ret    

c0023510 <palloc_init>:
{
c0023510:	56                   	push   %esi
c0023511:	53                   	push   %ebx
c0023512:	83 ec 24             	sub    $0x24,%esp
c0023515:	8b 54 24 30          	mov    0x30(%esp),%edx
  uint8_t *free_end = ptov (init_ram_pages * PGSIZE);
c0023519:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c002351e:	c1 e0 0c             	shl    $0xc,%eax
  ASSERT ((void *) paddr < PHYS_BASE);
c0023521:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c0023526:	76 2c                	jbe    c0023554 <palloc_init+0x44>
c0023528:	c7 44 24 10 96 e1 02 	movl   $0xc002e196,0x10(%esp)
c002352f:	c0 
c0023530:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023537:	c0 
c0023538:	c7 44 24 08 dd d2 02 	movl   $0xc002d2dd,0x8(%esp)
c002353f:	c0 
c0023540:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0023547:	00 
c0023548:	c7 04 24 c8 e1 02 c0 	movl   $0xc002e1c8,(%esp)
c002354f:	e8 6f 54 00 00       	call   c00289c3 <debug_panic>
  size_t free_pages = (free_end - free_start) / PGSIZE;
c0023554:	8d b0 ff 0f f0 ff    	lea    -0xff001(%eax),%esi
c002355a:	2d 00 00 10 00       	sub    $0x100000,%eax
c002355f:	0f 49 f0             	cmovns %eax,%esi
c0023562:	c1 fe 0c             	sar    $0xc,%esi
  size_t user_pages = free_pages / 2;
c0023565:	89 f3                	mov    %esi,%ebx
c0023567:	d1 eb                	shr    %ebx
c0023569:	39 d3                	cmp    %edx,%ebx
c002356b:	0f 47 da             	cmova  %edx,%ebx
  kernel_pages = free_pages - user_pages;
c002356e:	29 de                	sub    %ebx,%esi
  init_pool (&kernel_pool, free_start, kernel_pages, "kernel pool");
c0023570:	c7 04 24 8b eb 02 c0 	movl   $0xc002eb8b,(%esp)
c0023577:	89 f1                	mov    %esi,%ecx
c0023579:	ba 00 00 10 c0       	mov    $0xc0100000,%edx
c002357e:	b8 a0 74 03 c0       	mov    $0xc00374a0,%eax
c0023583:	e8 f5 fe ff ff       	call   c002347d <init_pool>
  init_pool (&user_pool, free_start + kernel_pages * PGSIZE,
c0023588:	c1 e6 0c             	shl    $0xc,%esi
c002358b:	8d 96 00 00 10 c0    	lea    -0x3ff00000(%esi),%edx
c0023591:	c7 04 24 97 eb 02 c0 	movl   $0xc002eb97,(%esp)
c0023598:	89 d9                	mov    %ebx,%ecx
c002359a:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c002359f:	e8 d9 fe ff ff       	call   c002347d <init_pool>
}
c00235a4:	83 c4 24             	add    $0x24,%esp
c00235a7:	5b                   	pop    %ebx
c00235a8:	5e                   	pop    %esi
c00235a9:	c3                   	ret    

c00235aa <palloc_get_multiple>:
{
c00235aa:	55                   	push   %ebp
c00235ab:	57                   	push   %edi
c00235ac:	56                   	push   %esi
c00235ad:	53                   	push   %ebx
c00235ae:	83 ec 1c             	sub    $0x1c,%esp
c00235b1:	8b 74 24 30          	mov    0x30(%esp),%esi
c00235b5:	8b 7c 24 34          	mov    0x34(%esp),%edi
  struct pool *pool = flags & PAL_USER ? &user_pool : &kernel_pool;
c00235b9:	89 f0                	mov    %esi,%eax
c00235bb:	83 e0 04             	and    $0x4,%eax
c00235be:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c00235c3:	bb a0 74 03 c0       	mov    $0xc00374a0,%ebx
c00235c8:	0f 45 d8             	cmovne %eax,%ebx
  if (page_cnt == 0)
c00235cb:	85 ff                	test   %edi,%edi
c00235cd:	0f 84 8f 00 00 00    	je     c0023662 <palloc_get_multiple+0xb8>
  lock_acquire (&pool->lock);
c00235d3:	89 1c 24             	mov    %ebx,(%esp)
c00235d6:	e8 cf f8 ff ff       	call   c0022eaa <lock_acquire>
  page_idx = bitmap_scan_and_flip (pool->used_map, 0, page_cnt, false);
c00235db:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00235e2:	00 
c00235e3:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00235e7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00235ee:	00 
c00235ef:	8b 43 24             	mov    0x24(%ebx),%eax
c00235f2:	89 04 24             	mov    %eax,(%esp)
c00235f5:	e8 40 68 00 00       	call   c0029e3a <bitmap_scan_and_flip>
c00235fa:	89 c5                	mov    %eax,%ebp
  lock_release (&pool->lock);
c00235fc:	89 1c 24             	mov    %ebx,(%esp)
c00235ff:	e8 70 fa ff ff       	call   c0023074 <lock_release>
  if (page_idx != BITMAP_ERROR)
c0023604:	83 fd ff             	cmp    $0xffffffff,%ebp
c0023607:	74 2d                	je     c0023636 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c0023609:	c1 e5 0c             	shl    $0xc,%ebp
  if (pages != NULL) 
c002360c:	03 6b 28             	add    0x28(%ebx),%ebp
c002360f:	74 25                	je     c0023636 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c0023611:	89 e8                	mov    %ebp,%eax
      if (flags & PAL_ZERO)
c0023613:	f7 c6 02 00 00 00    	test   $0x2,%esi
c0023619:	74 53                	je     c002366e <palloc_get_multiple+0xc4>
        memset (pages, 0, PGSIZE * page_cnt);
c002361b:	c1 e7 0c             	shl    $0xc,%edi
c002361e:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0023622:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023629:	00 
c002362a:	89 2c 24             	mov    %ebp,(%esp)
c002362d:	e8 4f 48 00 00       	call   c0027e81 <memset>
    pages = pool->base + PGSIZE * page_idx;
c0023632:	89 e8                	mov    %ebp,%eax
c0023634:	eb 38                	jmp    c002366e <palloc_get_multiple+0xc4>
      if (flags & PAL_ASSERT)
c0023636:	f7 c6 01 00 00 00    	test   $0x1,%esi
c002363c:	74 2b                	je     c0023669 <palloc_get_multiple+0xbf>
        PANIC ("palloc_get: out of pages");
c002363e:	c7 44 24 0c a1 eb 02 	movl   $0xc002eba1,0xc(%esp)
c0023645:	c0 
c0023646:	c7 44 24 08 bf d2 02 	movl   $0xc002d2bf,0x8(%esp)
c002364d:	c0 
c002364e:	c7 44 24 04 61 00 00 	movl   $0x61,0x4(%esp)
c0023655:	00 
c0023656:	c7 04 24 58 eb 02 c0 	movl   $0xc002eb58,(%esp)
c002365d:	e8 61 53 00 00       	call   c00289c3 <debug_panic>
    return NULL;
c0023662:	b8 00 00 00 00       	mov    $0x0,%eax
c0023667:	eb 05                	jmp    c002366e <palloc_get_multiple+0xc4>
  return pages;
c0023669:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002366e:	83 c4 1c             	add    $0x1c,%esp
c0023671:	5b                   	pop    %ebx
c0023672:	5e                   	pop    %esi
c0023673:	5f                   	pop    %edi
c0023674:	5d                   	pop    %ebp
c0023675:	c3                   	ret    

c0023676 <palloc_get_page>:
{
c0023676:	83 ec 1c             	sub    $0x1c,%esp
  return palloc_get_multiple (flags, 1);
c0023679:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023680:	00 
c0023681:	8b 44 24 20          	mov    0x20(%esp),%eax
c0023685:	89 04 24             	mov    %eax,(%esp)
c0023688:	e8 1d ff ff ff       	call   c00235aa <palloc_get_multiple>
}
c002368d:	83 c4 1c             	add    $0x1c,%esp
c0023690:	c3                   	ret    

c0023691 <palloc_free_multiple>:
{
c0023691:	55                   	push   %ebp
c0023692:	57                   	push   %edi
c0023693:	56                   	push   %esi
c0023694:	53                   	push   %ebx
c0023695:	83 ec 2c             	sub    $0x2c,%esp
c0023698:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c002369c:	8b 74 24 44          	mov    0x44(%esp),%esi
  ASSERT (pg_ofs (pages) == 0);
c00236a0:	f7 c3 ff 0f 00 00    	test   $0xfff,%ebx
c00236a6:	74 2c                	je     c00236d4 <palloc_free_multiple+0x43>
c00236a8:	c7 44 24 10 ba eb 02 	movl   $0xc002ebba,0x10(%esp)
c00236af:	c0 
c00236b0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00236b7:	c0 
c00236b8:	c7 44 24 08 aa d2 02 	movl   $0xc002d2aa,0x8(%esp)
c00236bf:	c0 
c00236c0:	c7 44 24 04 7b 00 00 	movl   $0x7b,0x4(%esp)
c00236c7:	00 
c00236c8:	c7 04 24 58 eb 02 c0 	movl   $0xc002eb58,(%esp)
c00236cf:	e8 ef 52 00 00       	call   c00289c3 <debug_panic>
  if (pages == NULL || page_cnt == 0)
c00236d4:	85 db                	test   %ebx,%ebx
c00236d6:	0f 84 fc 00 00 00    	je     c00237d8 <palloc_free_multiple+0x147>
c00236dc:	85 f6                	test   %esi,%esi
c00236de:	0f 84 f4 00 00 00    	je     c00237d8 <palloc_free_multiple+0x147>
  return (uintptr_t) va >> PGBITS;
c00236e4:	89 df                	mov    %ebx,%edi
c00236e6:	c1 ef 0c             	shr    $0xc,%edi
c00236e9:	8b 2d c8 74 03 c0    	mov    0xc00374c8,%ebp
c00236ef:	c1 ed 0c             	shr    $0xc,%ebp
static bool
page_from_pool (const struct pool *pool, void *page) 
{
  size_t page_no = pg_no (page);
  size_t start_page = pg_no (pool->base);
  size_t end_page = start_page + bitmap_size (pool->used_map);
c00236f2:	a1 c4 74 03 c0       	mov    0xc00374c4,%eax
c00236f7:	89 04 24             	mov    %eax,(%esp)
c00236fa:	e8 a7 60 00 00       	call   c00297a6 <bitmap_size>
c00236ff:	01 e8                	add    %ebp,%eax
  if (page_from_pool (&kernel_pool, pages))
c0023701:	39 c7                	cmp    %eax,%edi
c0023703:	73 04                	jae    c0023709 <palloc_free_multiple+0x78>
c0023705:	39 ef                	cmp    %ebp,%edi
c0023707:	73 44                	jae    c002374d <palloc_free_multiple+0xbc>
c0023709:	8b 2d 88 74 03 c0    	mov    0xc0037488,%ebp
c002370f:	c1 ed 0c             	shr    $0xc,%ebp
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0023712:	a1 84 74 03 c0       	mov    0xc0037484,%eax
c0023717:	89 04 24             	mov    %eax,(%esp)
c002371a:	e8 87 60 00 00       	call   c00297a6 <bitmap_size>
c002371f:	01 e8                	add    %ebp,%eax
  else if (page_from_pool (&user_pool, pages))
c0023721:	39 c7                	cmp    %eax,%edi
c0023723:	73 04                	jae    c0023729 <palloc_free_multiple+0x98>
c0023725:	39 ef                	cmp    %ebp,%edi
c0023727:	73 2b                	jae    c0023754 <palloc_free_multiple+0xc3>
    NOT_REACHED ();
c0023729:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0023730:	c0 
c0023731:	c7 44 24 08 aa d2 02 	movl   $0xc002d2aa,0x8(%esp)
c0023738:	c0 
c0023739:	c7 44 24 04 84 00 00 	movl   $0x84,0x4(%esp)
c0023740:	00 
c0023741:	c7 04 24 58 eb 02 c0 	movl   $0xc002eb58,(%esp)
c0023748:	e8 76 52 00 00       	call   c00289c3 <debug_panic>
    pool = &kernel_pool;
c002374d:	bd a0 74 03 c0       	mov    $0xc00374a0,%ebp
c0023752:	eb 05                	jmp    c0023759 <palloc_free_multiple+0xc8>
    pool = &user_pool;
c0023754:	bd 60 74 03 c0       	mov    $0xc0037460,%ebp
c0023759:	8b 45 28             	mov    0x28(%ebp),%eax
c002375c:	c1 e8 0c             	shr    $0xc,%eax
  page_idx = pg_no (pages) - pg_no (pool->base);
c002375f:	29 c7                	sub    %eax,%edi
  memset (pages, 0xcc, PGSIZE * page_cnt);
c0023761:	89 f0                	mov    %esi,%eax
c0023763:	c1 e0 0c             	shl    $0xc,%eax
c0023766:	89 44 24 08          	mov    %eax,0x8(%esp)
c002376a:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c0023771:	00 
c0023772:	89 1c 24             	mov    %ebx,(%esp)
c0023775:	e8 07 47 00 00       	call   c0027e81 <memset>
  ASSERT (bitmap_all (pool->used_map, page_idx, page_cnt));
c002377a:	89 74 24 08          	mov    %esi,0x8(%esp)
c002377e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023782:	8b 45 24             	mov    0x24(%ebp),%eax
c0023785:	89 04 24             	mov    %eax,(%esp)
c0023788:	e8 af 65 00 00       	call   c0029d3c <bitmap_all>
c002378d:	84 c0                	test   %al,%al
c002378f:	75 2c                	jne    c00237bd <palloc_free_multiple+0x12c>
c0023791:	c7 44 24 10 28 eb 02 	movl   $0xc002eb28,0x10(%esp)
c0023798:	c0 
c0023799:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00237a0:	c0 
c00237a1:	c7 44 24 08 aa d2 02 	movl   $0xc002d2aa,0x8(%esp)
c00237a8:	c0 
c00237a9:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c00237b0:	00 
c00237b1:	c7 04 24 58 eb 02 c0 	movl   $0xc002eb58,(%esp)
c00237b8:	e8 06 52 00 00       	call   c00289c3 <debug_panic>
  bitmap_set_multiple (pool->used_map, page_idx, page_cnt, false);
c00237bd:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00237c4:	00 
c00237c5:	89 74 24 08          	mov    %esi,0x8(%esp)
c00237c9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00237cd:	8b 45 24             	mov    0x24(%ebp),%eax
c00237d0:	89 04 24             	mov    %eax,(%esp)
c00237d3:	e8 45 61 00 00       	call   c002991d <bitmap_set_multiple>
}
c00237d8:	83 c4 2c             	add    $0x2c,%esp
c00237db:	5b                   	pop    %ebx
c00237dc:	5e                   	pop    %esi
c00237dd:	5f                   	pop    %edi
c00237de:	5d                   	pop    %ebp
c00237df:	c3                   	ret    

c00237e0 <palloc_free_page>:
{
c00237e0:	83 ec 1c             	sub    $0x1c,%esp
  palloc_free_multiple (page, 1);
c00237e3:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c00237ea:	00 
c00237eb:	8b 44 24 20          	mov    0x20(%esp),%eax
c00237ef:	89 04 24             	mov    %eax,(%esp)
c00237f2:	e8 9a fe ff ff       	call   c0023691 <palloc_free_multiple>
}
c00237f7:	83 c4 1c             	add    $0x1c,%esp
c00237fa:	c3                   	ret    
c00237fb:	90                   	nop
c00237fc:	90                   	nop
c00237fd:	90                   	nop
c00237fe:	90                   	nop
c00237ff:	90                   	nop

c0023800 <arena_to_block>:
}

/* Returns the (IDX - 1)'th block within arena A. */
static struct block *
arena_to_block (struct arena *a, size_t idx) 
{
c0023800:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (a != NULL);
c0023803:	85 c0                	test   %eax,%eax
c0023805:	75 2c                	jne    c0023833 <arena_to_block+0x33>
c0023807:	c7 44 24 10 59 ea 02 	movl   $0xc002ea59,0x10(%esp)
c002380e:	c0 
c002380f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023816:	c0 
c0023817:	c7 44 24 08 f6 d2 02 	movl   $0xc002d2f6,0x8(%esp)
c002381e:	c0 
c002381f:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c0023826:	00 
c0023827:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c002382e:	e8 90 51 00 00       	call   c00289c3 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c0023833:	81 38 ed 8e 54 9a    	cmpl   $0x9a548eed,(%eax)
c0023839:	74 2c                	je     c0023867 <arena_to_block+0x67>
c002383b:	c7 44 24 10 e5 eb 02 	movl   $0xc002ebe5,0x10(%esp)
c0023842:	c0 
c0023843:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002384a:	c0 
c002384b:	c7 44 24 08 f6 d2 02 	movl   $0xc002d2f6,0x8(%esp)
c0023852:	c0 
c0023853:	c7 44 24 04 21 01 00 	movl   $0x121,0x4(%esp)
c002385a:	00 
c002385b:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c0023862:	e8 5c 51 00 00       	call   c00289c3 <debug_panic>
  ASSERT (idx < a->desc->blocks_per_arena);
c0023867:	8b 48 04             	mov    0x4(%eax),%ecx
c002386a:	39 51 04             	cmp    %edx,0x4(%ecx)
c002386d:	77 2c                	ja     c002389b <arena_to_block+0x9b>
c002386f:	c7 44 24 10 00 ec 02 	movl   $0xc002ec00,0x10(%esp)
c0023876:	c0 
c0023877:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002387e:	c0 
c002387f:	c7 44 24 08 f6 d2 02 	movl   $0xc002d2f6,0x8(%esp)
c0023886:	c0 
c0023887:	c7 44 24 04 22 01 00 	movl   $0x122,0x4(%esp)
c002388e:	00 
c002388f:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c0023896:	e8 28 51 00 00       	call   c00289c3 <debug_panic>
  return (struct block *) ((uint8_t *) a
                           + sizeof *a
                           + idx * a->desc->block_size);
c002389b:	0f af 11             	imul   (%ecx),%edx
  return (struct block *) ((uint8_t *) a
c002389e:	8d 44 10 0c          	lea    0xc(%eax,%edx,1),%eax
}
c00238a2:	83 c4 2c             	add    $0x2c,%esp
c00238a5:	c3                   	ret    

c00238a6 <block_to_arena>:
{
c00238a6:	53                   	push   %ebx
c00238a7:	83 ec 28             	sub    $0x28,%esp
  ASSERT (a != NULL);
c00238aa:	89 c1                	mov    %eax,%ecx
c00238ac:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
c00238b2:	75 2c                	jne    c00238e0 <block_to_arena+0x3a>
c00238b4:	c7 44 24 10 59 ea 02 	movl   $0xc002ea59,0x10(%esp)
c00238bb:	c0 
c00238bc:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00238c3:	c0 
c00238c4:	c7 44 24 08 e7 d2 02 	movl   $0xc002d2e7,0x8(%esp)
c00238cb:	c0 
c00238cc:	c7 44 24 04 11 01 00 	movl   $0x111,0x4(%esp)
c00238d3:	00 
c00238d4:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c00238db:	e8 e3 50 00 00       	call   c00289c3 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c00238e0:	81 39 ed 8e 54 9a    	cmpl   $0x9a548eed,(%ecx)
c00238e6:	74 2c                	je     c0023914 <block_to_arena+0x6e>
c00238e8:	c7 44 24 10 e5 eb 02 	movl   $0xc002ebe5,0x10(%esp)
c00238ef:	c0 
c00238f0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00238f7:	c0 
c00238f8:	c7 44 24 08 e7 d2 02 	movl   $0xc002d2e7,0x8(%esp)
c00238ff:	c0 
c0023900:	c7 44 24 04 12 01 00 	movl   $0x112,0x4(%esp)
c0023907:	00 
c0023908:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c002390f:	e8 af 50 00 00       	call   c00289c3 <debug_panic>
  ASSERT (a->desc == NULL
c0023914:	8b 59 04             	mov    0x4(%ecx),%ebx
c0023917:	85 db                	test   %ebx,%ebx
c0023919:	74 3f                	je     c002395a <block_to_arena+0xb4>
  return (uintptr_t) va & PGMASK;
c002391b:	25 ff 0f 00 00       	and    $0xfff,%eax
c0023920:	8d 40 f4             	lea    -0xc(%eax),%eax
c0023923:	ba 00 00 00 00       	mov    $0x0,%edx
c0023928:	f7 33                	divl   (%ebx)
c002392a:	85 d2                	test   %edx,%edx
c002392c:	74 62                	je     c0023990 <block_to_arena+0xea>
c002392e:	c7 44 24 10 20 ec 02 	movl   $0xc002ec20,0x10(%esp)
c0023935:	c0 
c0023936:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002393d:	c0 
c002393e:	c7 44 24 08 e7 d2 02 	movl   $0xc002d2e7,0x8(%esp)
c0023945:	c0 
c0023946:	c7 44 24 04 16 01 00 	movl   $0x116,0x4(%esp)
c002394d:	00 
c002394e:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c0023955:	e8 69 50 00 00       	call   c00289c3 <debug_panic>
c002395a:	25 ff 0f 00 00       	and    $0xfff,%eax
  ASSERT (a->desc != NULL || pg_ofs (b) == sizeof *a);
c002395f:	83 f8 0c             	cmp    $0xc,%eax
c0023962:	74 2c                	je     c0023990 <block_to_arena+0xea>
c0023964:	c7 44 24 10 68 ec 02 	movl   $0xc002ec68,0x10(%esp)
c002396b:	c0 
c002396c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023973:	c0 
c0023974:	c7 44 24 08 e7 d2 02 	movl   $0xc002d2e7,0x8(%esp)
c002397b:	c0 
c002397c:	c7 44 24 04 17 01 00 	movl   $0x117,0x4(%esp)
c0023983:	00 
c0023984:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c002398b:	e8 33 50 00 00       	call   c00289c3 <debug_panic>
}
c0023990:	89 c8                	mov    %ecx,%eax
c0023992:	83 c4 28             	add    $0x28,%esp
c0023995:	5b                   	pop    %ebx
c0023996:	c3                   	ret    

c0023997 <malloc_init>:
{
c0023997:	57                   	push   %edi
c0023998:	56                   	push   %esi
c0023999:	53                   	push   %ebx
c002399a:	83 ec 20             	sub    $0x20,%esp
      struct desc *d = &descs[desc_cnt++];
c002399d:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c00239a2:	8d 50 01             	lea    0x1(%eax),%edx
c00239a5:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c00239ab:	6b c0 3c             	imul   $0x3c,%eax,%eax
c00239ae:	8d 98 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%ebx
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c00239b4:	83 fa 0a             	cmp    $0xa,%edx
c00239b7:	76 7e                	jbe    c0023a37 <malloc_init+0xa0>
c00239b9:	eb 1c                	jmp    c00239d7 <malloc_init+0x40>
      struct desc *d = &descs[desc_cnt++];
c00239bb:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c00239c0:	8d 50 01             	lea    0x1(%eax),%edx
c00239c3:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c00239c9:	6b c0 3c             	imul   $0x3c,%eax,%eax
c00239cc:	8d b0 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%esi
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c00239d2:	83 fa 0a             	cmp    $0xa,%edx
c00239d5:	76 2c                	jbe    c0023a03 <malloc_init+0x6c>
c00239d7:	c7 44 24 10 94 ec 02 	movl   $0xc002ec94,0x10(%esp)
c00239de:	c0 
c00239df:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00239e6:	c0 
c00239e7:	c7 44 24 08 05 d3 02 	movl   $0xc002d305,0x8(%esp)
c00239ee:	c0 
c00239ef:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c00239f6:	00 
c00239f7:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c00239fe:	e8 c0 4f 00 00       	call   c00289c3 <debug_panic>
      d->block_size = block_size;
c0023a03:	89 98 00 75 03 c0    	mov    %ebx,-0x3ffc8b00(%eax)
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0023a09:	89 f8                	mov    %edi,%eax
c0023a0b:	ba 00 00 00 00       	mov    $0x0,%edx
c0023a10:	f7 f3                	div    %ebx
c0023a12:	89 46 04             	mov    %eax,0x4(%esi)
      list_init (&d->free_list);
c0023a15:	8d 46 08             	lea    0x8(%esi),%eax
c0023a18:	89 04 24             	mov    %eax,(%esp)
c0023a1b:	e8 70 50 00 00       	call   c0028a90 <list_init>
      lock_init (&d->lock);
c0023a20:	83 c6 18             	add    $0x18,%esi
c0023a23:	89 34 24             	mov    %esi,(%esp)
c0023a26:	e8 e2 f3 ff ff       	call   c0022e0d <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c0023a2b:	01 db                	add    %ebx,%ebx
c0023a2d:	81 fb ff 07 00 00    	cmp    $0x7ff,%ebx
c0023a33:	76 86                	jbe    c00239bb <malloc_init+0x24>
c0023a35:	eb 36                	jmp    c0023a6d <malloc_init+0xd6>
      d->block_size = block_size;
c0023a37:	c7 80 00 75 03 c0 10 	movl   $0x10,-0x3ffc8b00(%eax)
c0023a3e:	00 00 00 
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0023a41:	c7 43 04 ff 00 00 00 	movl   $0xff,0x4(%ebx)
      list_init (&d->free_list);
c0023a48:	8d 43 08             	lea    0x8(%ebx),%eax
c0023a4b:	89 04 24             	mov    %eax,(%esp)
c0023a4e:	e8 3d 50 00 00       	call   c0028a90 <list_init>
      lock_init (&d->lock);
c0023a53:	83 c3 18             	add    $0x18,%ebx
c0023a56:	89 1c 24             	mov    %ebx,(%esp)
c0023a59:	e8 af f3 ff ff       	call   c0022e0d <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c0023a5e:	bb 20 00 00 00       	mov    $0x20,%ebx
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0023a63:	bf f4 0f 00 00       	mov    $0xff4,%edi
c0023a68:	e9 4e ff ff ff       	jmp    c00239bb <malloc_init+0x24>
}
c0023a6d:	83 c4 20             	add    $0x20,%esp
c0023a70:	5b                   	pop    %ebx
c0023a71:	5e                   	pop    %esi
c0023a72:	5f                   	pop    %edi
c0023a73:	c3                   	ret    

c0023a74 <malloc>:
{
c0023a74:	55                   	push   %ebp
c0023a75:	57                   	push   %edi
c0023a76:	56                   	push   %esi
c0023a77:	53                   	push   %ebx
c0023a78:	83 ec 1c             	sub    $0x1c,%esp
c0023a7b:	8b 54 24 30          	mov    0x30(%esp),%edx
  if (size == 0)
c0023a7f:	85 d2                	test   %edx,%edx
c0023a81:	0f 84 15 01 00 00    	je     c0023b9c <malloc+0x128>
  for (d = descs; d < descs + desc_cnt; d++)
c0023a87:	6b 05 e0 74 03 c0 3c 	imul   $0x3c,0xc00374e0,%eax
c0023a8e:	05 00 75 03 c0       	add    $0xc0037500,%eax
c0023a93:	3d 00 75 03 c0       	cmp    $0xc0037500,%eax
c0023a98:	76 1c                	jbe    c0023ab6 <malloc+0x42>
    if (d->block_size >= size)
c0023a9a:	3b 15 00 75 03 c0    	cmp    0xc0037500,%edx
c0023aa0:	76 1b                	jbe    c0023abd <malloc+0x49>
c0023aa2:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c0023aa7:	eb 04                	jmp    c0023aad <malloc+0x39>
c0023aa9:	3b 13                	cmp    (%ebx),%edx
c0023aab:	76 15                	jbe    c0023ac2 <malloc+0x4e>
  for (d = descs; d < descs + desc_cnt; d++)
c0023aad:	83 c3 3c             	add    $0x3c,%ebx
c0023ab0:	39 c3                	cmp    %eax,%ebx
c0023ab2:	72 f5                	jb     c0023aa9 <malloc+0x35>
c0023ab4:	eb 0c                	jmp    c0023ac2 <malloc+0x4e>
c0023ab6:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c0023abb:	eb 05                	jmp    c0023ac2 <malloc+0x4e>
    if (d->block_size >= size)
c0023abd:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
  if (d == descs + desc_cnt) 
c0023ac2:	39 d8                	cmp    %ebx,%eax
c0023ac4:	75 39                	jne    c0023aff <malloc+0x8b>
      size_t page_cnt = DIV_ROUND_UP (size + sizeof *a, PGSIZE);
c0023ac6:	8d 9a 0b 10 00 00    	lea    0x100b(%edx),%ebx
c0023acc:	c1 eb 0c             	shr    $0xc,%ebx
      a = palloc_get_multiple (0, page_cnt);
c0023acf:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023ad3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0023ada:	e8 cb fa ff ff       	call   c00235aa <palloc_get_multiple>
      if (a == NULL)
c0023adf:	85 c0                	test   %eax,%eax
c0023ae1:	0f 84 bc 00 00 00    	je     c0023ba3 <malloc+0x12f>
      a->magic = ARENA_MAGIC;
c0023ae7:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = NULL;
c0023aed:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
      a->free_cnt = page_cnt;
c0023af4:	89 58 08             	mov    %ebx,0x8(%eax)
      return a + 1;
c0023af7:	83 c0 0c             	add    $0xc,%eax
c0023afa:	e9 a9 00 00 00       	jmp    c0023ba8 <malloc+0x134>
  lock_acquire (&d->lock);
c0023aff:	8d 43 18             	lea    0x18(%ebx),%eax
c0023b02:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0023b06:	89 04 24             	mov    %eax,(%esp)
c0023b09:	e8 9c f3 ff ff       	call   c0022eaa <lock_acquire>
  if (list_empty (&d->free_list))
c0023b0e:	8d 7b 08             	lea    0x8(%ebx),%edi
c0023b11:	89 3c 24             	mov    %edi,(%esp)
c0023b14:	e8 ad 55 00 00       	call   c00290c6 <list_empty>
c0023b19:	84 c0                	test   %al,%al
c0023b1b:	74 5c                	je     c0023b79 <malloc+0x105>
      a = palloc_get_page (0);
c0023b1d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0023b24:	e8 4d fb ff ff       	call   c0023676 <palloc_get_page>
c0023b29:	89 c5                	mov    %eax,%ebp
      if (a == NULL) 
c0023b2b:	85 c0                	test   %eax,%eax
c0023b2d:	75 13                	jne    c0023b42 <malloc+0xce>
          lock_release (&d->lock);
c0023b2f:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0023b33:	89 04 24             	mov    %eax,(%esp)
c0023b36:	e8 39 f5 ff ff       	call   c0023074 <lock_release>
          return NULL; 
c0023b3b:	b8 00 00 00 00       	mov    $0x0,%eax
c0023b40:	eb 66                	jmp    c0023ba8 <malloc+0x134>
      a->magic = ARENA_MAGIC;
c0023b42:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = d;
c0023b48:	89 58 04             	mov    %ebx,0x4(%eax)
      a->free_cnt = d->blocks_per_arena;
c0023b4b:	8b 43 04             	mov    0x4(%ebx),%eax
c0023b4e:	89 45 08             	mov    %eax,0x8(%ebp)
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023b51:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0023b55:	74 22                	je     c0023b79 <malloc+0x105>
c0023b57:	be 00 00 00 00       	mov    $0x0,%esi
          struct block *b = arena_to_block (a, i);
c0023b5c:	89 f2                	mov    %esi,%edx
c0023b5e:	89 e8                	mov    %ebp,%eax
c0023b60:	e8 9b fc ff ff       	call   c0023800 <arena_to_block>
          list_push_back (&d->free_list, &b->free_elem);
c0023b65:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023b69:	89 3c 24             	mov    %edi,(%esp)
c0023b6c:	e8 a0 54 00 00       	call   c0029011 <list_push_back>
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023b71:	83 c6 01             	add    $0x1,%esi
c0023b74:	39 73 04             	cmp    %esi,0x4(%ebx)
c0023b77:	77 e3                	ja     c0023b5c <malloc+0xe8>
  b = list_entry (list_pop_front (&d->free_list), struct block, free_elem);
c0023b79:	89 3c 24             	mov    %edi,(%esp)
c0023b7c:	e8 b3 55 00 00       	call   c0029134 <list_pop_front>
c0023b81:	89 c3                	mov    %eax,%ebx
  a = block_to_arena (b);
c0023b83:	e8 1e fd ff ff       	call   c00238a6 <block_to_arena>
  a->free_cnt--;
c0023b88:	83 68 08 01          	subl   $0x1,0x8(%eax)
  lock_release (&d->lock);
c0023b8c:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0023b90:	89 04 24             	mov    %eax,(%esp)
c0023b93:	e8 dc f4 ff ff       	call   c0023074 <lock_release>
  return b;
c0023b98:	89 d8                	mov    %ebx,%eax
c0023b9a:	eb 0c                	jmp    c0023ba8 <malloc+0x134>
    return NULL;
c0023b9c:	b8 00 00 00 00       	mov    $0x0,%eax
c0023ba1:	eb 05                	jmp    c0023ba8 <malloc+0x134>
        return NULL;
c0023ba3:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023ba8:	83 c4 1c             	add    $0x1c,%esp
c0023bab:	5b                   	pop    %ebx
c0023bac:	5e                   	pop    %esi
c0023bad:	5f                   	pop    %edi
c0023bae:	5d                   	pop    %ebp
c0023baf:	c3                   	ret    

c0023bb0 <calloc>:
{
c0023bb0:	56                   	push   %esi
c0023bb1:	53                   	push   %ebx
c0023bb2:	83 ec 14             	sub    $0x14,%esp
c0023bb5:	8b 54 24 20          	mov    0x20(%esp),%edx
c0023bb9:	8b 44 24 24          	mov    0x24(%esp),%eax
  size = a * b;
c0023bbd:	89 d3                	mov    %edx,%ebx
c0023bbf:	0f af d8             	imul   %eax,%ebx
  if (size < a || size < b)
c0023bc2:	39 c3                	cmp    %eax,%ebx
c0023bc4:	72 2a                	jb     c0023bf0 <calloc+0x40>
c0023bc6:	39 d3                	cmp    %edx,%ebx
c0023bc8:	72 26                	jb     c0023bf0 <calloc+0x40>
  p = malloc (size);
c0023bca:	89 1c 24             	mov    %ebx,(%esp)
c0023bcd:	e8 a2 fe ff ff       	call   c0023a74 <malloc>
c0023bd2:	89 c6                	mov    %eax,%esi
  if (p != NULL)
c0023bd4:	85 f6                	test   %esi,%esi
c0023bd6:	74 1d                	je     c0023bf5 <calloc+0x45>
    memset (p, 0, size);
c0023bd8:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023bdc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023be3:	00 
c0023be4:	89 34 24             	mov    %esi,(%esp)
c0023be7:	e8 95 42 00 00       	call   c0027e81 <memset>
  return p;
c0023bec:	89 f0                	mov    %esi,%eax
c0023bee:	eb 05                	jmp    c0023bf5 <calloc+0x45>
    return NULL;
c0023bf0:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023bf5:	83 c4 14             	add    $0x14,%esp
c0023bf8:	5b                   	pop    %ebx
c0023bf9:	5e                   	pop    %esi
c0023bfa:	c3                   	ret    

c0023bfb <free>:
{
c0023bfb:	55                   	push   %ebp
c0023bfc:	57                   	push   %edi
c0023bfd:	56                   	push   %esi
c0023bfe:	53                   	push   %ebx
c0023bff:	83 ec 2c             	sub    $0x2c,%esp
c0023c02:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  if (p != NULL)
c0023c06:	85 db                	test   %ebx,%ebx
c0023c08:	0f 84 ca 00 00 00    	je     c0023cd8 <free+0xdd>
      struct arena *a = block_to_arena (b);
c0023c0e:	89 d8                	mov    %ebx,%eax
c0023c10:	e8 91 fc ff ff       	call   c00238a6 <block_to_arena>
c0023c15:	89 c7                	mov    %eax,%edi
      struct desc *d = a->desc;
c0023c17:	8b 70 04             	mov    0x4(%eax),%esi
      if (d != NULL) 
c0023c1a:	85 f6                	test   %esi,%esi
c0023c1c:	0f 84 a7 00 00 00    	je     c0023cc9 <free+0xce>
          memset (b, 0xcc, d->block_size);
c0023c22:	8b 06                	mov    (%esi),%eax
c0023c24:	89 44 24 08          	mov    %eax,0x8(%esp)
c0023c28:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c0023c2f:	00 
c0023c30:	89 1c 24             	mov    %ebx,(%esp)
c0023c33:	e8 49 42 00 00       	call   c0027e81 <memset>
          lock_acquire (&d->lock);
c0023c38:	8d 6e 18             	lea    0x18(%esi),%ebp
c0023c3b:	89 2c 24             	mov    %ebp,(%esp)
c0023c3e:	e8 67 f2 ff ff       	call   c0022eaa <lock_acquire>
          list_push_front (&d->free_list, &b->free_elem);
c0023c43:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023c47:	8d 46 08             	lea    0x8(%esi),%eax
c0023c4a:	89 04 24             	mov    %eax,(%esp)
c0023c4d:	e8 9c 53 00 00       	call   c0028fee <list_push_front>
          if (++a->free_cnt >= d->blocks_per_arena) 
c0023c52:	8b 47 08             	mov    0x8(%edi),%eax
c0023c55:	83 c0 01             	add    $0x1,%eax
c0023c58:	89 47 08             	mov    %eax,0x8(%edi)
c0023c5b:	8b 56 04             	mov    0x4(%esi),%edx
c0023c5e:	39 d0                	cmp    %edx,%eax
c0023c60:	72 5d                	jb     c0023cbf <free+0xc4>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023c62:	39 d0                	cmp    %edx,%eax
c0023c64:	75 0c                	jne    c0023c72 <free+0x77>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023c66:	bb 00 00 00 00       	mov    $0x0,%ebx
c0023c6b:	85 c0                	test   %eax,%eax
c0023c6d:	75 2f                	jne    c0023c9e <free+0xa3>
c0023c6f:	90                   	nop
c0023c70:	eb 45                	jmp    c0023cb7 <free+0xbc>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023c72:	c7 44 24 10 c0 ec 02 	movl   $0xc002ecc0,0x10(%esp)
c0023c79:	c0 
c0023c7a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023c81:	c0 
c0023c82:	c7 44 24 08 e2 d2 02 	movl   $0xc002d2e2,0x8(%esp)
c0023c89:	c0 
c0023c8a:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0023c91:	00 
c0023c92:	c7 04 24 ce eb 02 c0 	movl   $0xc002ebce,(%esp)
c0023c99:	e8 25 4d 00 00       	call   c00289c3 <debug_panic>
                  struct block *b = arena_to_block (a, i);
c0023c9e:	89 da                	mov    %ebx,%edx
c0023ca0:	89 f8                	mov    %edi,%eax
c0023ca2:	e8 59 fb ff ff       	call   c0023800 <arena_to_block>
                  list_remove (&b->free_elem);
c0023ca7:	89 04 24             	mov    %eax,(%esp)
c0023caa:	e8 85 53 00 00       	call   c0029034 <list_remove>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023caf:	83 c3 01             	add    $0x1,%ebx
c0023cb2:	39 5e 04             	cmp    %ebx,0x4(%esi)
c0023cb5:	77 e7                	ja     c0023c9e <free+0xa3>
              palloc_free_page (a);
c0023cb7:	89 3c 24             	mov    %edi,(%esp)
c0023cba:	e8 21 fb ff ff       	call   c00237e0 <palloc_free_page>
          lock_release (&d->lock);
c0023cbf:	89 2c 24             	mov    %ebp,(%esp)
c0023cc2:	e8 ad f3 ff ff       	call   c0023074 <lock_release>
c0023cc7:	eb 0f                	jmp    c0023cd8 <free+0xdd>
          palloc_free_multiple (a, a->free_cnt);
c0023cc9:	8b 40 08             	mov    0x8(%eax),%eax
c0023ccc:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023cd0:	89 3c 24             	mov    %edi,(%esp)
c0023cd3:	e8 b9 f9 ff ff       	call   c0023691 <palloc_free_multiple>
}
c0023cd8:	83 c4 2c             	add    $0x2c,%esp
c0023cdb:	5b                   	pop    %ebx
c0023cdc:	5e                   	pop    %esi
c0023cdd:	5f                   	pop    %edi
c0023cde:	5d                   	pop    %ebp
c0023cdf:	c3                   	ret    

c0023ce0 <realloc>:
{
c0023ce0:	57                   	push   %edi
c0023ce1:	56                   	push   %esi
c0023ce2:	53                   	push   %ebx
c0023ce3:	83 ec 10             	sub    $0x10,%esp
c0023ce6:	8b 7c 24 20          	mov    0x20(%esp),%edi
c0023cea:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (new_size == 0) 
c0023cee:	85 db                	test   %ebx,%ebx
c0023cf0:	75 0f                	jne    c0023d01 <realloc+0x21>
      free (old_block);
c0023cf2:	89 3c 24             	mov    %edi,(%esp)
c0023cf5:	e8 01 ff ff ff       	call   c0023bfb <free>
      return NULL;
c0023cfa:	b8 00 00 00 00       	mov    $0x0,%eax
c0023cff:	eb 57                	jmp    c0023d58 <realloc+0x78>
      void *new_block = malloc (new_size);
c0023d01:	89 1c 24             	mov    %ebx,(%esp)
c0023d04:	e8 6b fd ff ff       	call   c0023a74 <malloc>
c0023d09:	89 c6                	mov    %eax,%esi
      if (old_block != NULL && new_block != NULL)
c0023d0b:	85 c0                	test   %eax,%eax
c0023d0d:	74 47                	je     c0023d56 <realloc+0x76>
c0023d0f:	85 ff                	test   %edi,%edi
c0023d11:	74 43                	je     c0023d56 <realloc+0x76>
  struct arena *a = block_to_arena (b);
c0023d13:	89 f8                	mov    %edi,%eax
c0023d15:	e8 8c fb ff ff       	call   c00238a6 <block_to_arena>
  struct desc *d = a->desc;
c0023d1a:	8b 50 04             	mov    0x4(%eax),%edx
  return d != NULL ? d->block_size : PGSIZE * a->free_cnt - pg_ofs (block);
c0023d1d:	85 d2                	test   %edx,%edx
c0023d1f:	74 04                	je     c0023d25 <realloc+0x45>
c0023d21:	8b 02                	mov    (%edx),%eax
c0023d23:	eb 10                	jmp    c0023d35 <realloc+0x55>
c0023d25:	8b 40 08             	mov    0x8(%eax),%eax
c0023d28:	c1 e0 0c             	shl    $0xc,%eax
c0023d2b:	89 fa                	mov    %edi,%edx
c0023d2d:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
c0023d33:	29 d0                	sub    %edx,%eax
          size_t min_size = new_size < old_size ? new_size : old_size;
c0023d35:	39 d8                	cmp    %ebx,%eax
c0023d37:	0f 46 d8             	cmovbe %eax,%ebx
          memcpy (new_block, old_block, min_size);
c0023d3a:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023d3e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023d42:	89 34 24             	mov    %esi,(%esp)
c0023d45:	e8 56 3b 00 00       	call   c00278a0 <memcpy>
          free (old_block);
c0023d4a:	89 3c 24             	mov    %edi,(%esp)
c0023d4d:	e8 a9 fe ff ff       	call   c0023bfb <free>
      return new_block;
c0023d52:	89 f0                	mov    %esi,%eax
c0023d54:	eb 02                	jmp    c0023d58 <realloc+0x78>
c0023d56:	89 f0                	mov    %esi,%eax
}
c0023d58:	83 c4 10             	add    $0x10,%esp
c0023d5b:	5b                   	pop    %ebx
c0023d5c:	5e                   	pop    %esi
c0023d5d:	5f                   	pop    %edi
c0023d5e:	c3                   	ret    

c0023d5f <pit_configure_channel>:
     - Other modes are less useful.

   FREQUENCY is the number of periods per second, in Hz. */
void
pit_configure_channel (int channel, int mode, int frequency)
{
c0023d5f:	57                   	push   %edi
c0023d60:	56                   	push   %esi
c0023d61:	53                   	push   %ebx
c0023d62:	83 ec 20             	sub    $0x20,%esp
c0023d65:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0023d69:	8b 7c 24 34          	mov    0x34(%esp),%edi
c0023d6d:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  uint16_t count;
  enum intr_level old_level;

  ASSERT (channel == 0 || channel == 2);
c0023d71:	f7 c3 fd ff ff ff    	test   $0xfffffffd,%ebx
c0023d77:	74 2c                	je     c0023da5 <pit_configure_channel+0x46>
c0023d79:	c7 44 24 10 e3 ec 02 	movl   $0xc002ece3,0x10(%esp)
c0023d80:	c0 
c0023d81:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023d88:	c0 
c0023d89:	c7 44 24 08 11 d3 02 	movl   $0xc002d311,0x8(%esp)
c0023d90:	c0 
c0023d91:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
c0023d98:	00 
c0023d99:	c7 04 24 00 ed 02 c0 	movl   $0xc002ed00,(%esp)
c0023da0:	e8 1e 4c 00 00       	call   c00289c3 <debug_panic>
  ASSERT (mode == 2 || mode == 3);
c0023da5:	8d 47 fe             	lea    -0x2(%edi),%eax
c0023da8:	83 f8 01             	cmp    $0x1,%eax
c0023dab:	76 2c                	jbe    c0023dd9 <pit_configure_channel+0x7a>
c0023dad:	c7 44 24 10 14 ed 02 	movl   $0xc002ed14,0x10(%esp)
c0023db4:	c0 
c0023db5:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0023dbc:	c0 
c0023dbd:	c7 44 24 08 11 d3 02 	movl   $0xc002d311,0x8(%esp)
c0023dc4:	c0 
c0023dc5:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c0023dcc:	00 
c0023dcd:	c7 04 24 00 ed 02 c0 	movl   $0xc002ed00,(%esp)
c0023dd4:	e8 ea 4b 00 00       	call   c00289c3 <debug_panic>
    {
      /* Frequency is too low: the quotient would overflow the
         16-bit counter.  Force it to 0, which the PIT treats as
         65536, the highest possible count.  This yields a 18.2
         Hz timer, approximately. */
      count = 0;
c0023dd9:	be 00 00 00 00       	mov    $0x0,%esi
  if (frequency < 19)
c0023dde:	83 f9 12             	cmp    $0x12,%ecx
c0023de1:	7e 20                	jle    c0023e03 <pit_configure_channel+0xa4>
      /* Frequency is too high: the quotient would underflow to
         0, which the PIT would interpret as 65536.  A count of 1
         is illegal in mode 2, so we force it to 2, which yields
         a 596.590 kHz timer, approximately.  (This timer rate is
         probably too fast to be useful anyhow.) */
      count = 2;
c0023de3:	be 02 00 00 00       	mov    $0x2,%esi
  else if (frequency > PIT_HZ)
c0023de8:	81 f9 dc 34 12 00    	cmp    $0x1234dc,%ecx
c0023dee:	7f 13                	jg     c0023e03 <pit_configure_channel+0xa4>
    }
  else
    count = (PIT_HZ + frequency / 2) / frequency;
c0023df0:	89 c8                	mov    %ecx,%eax
c0023df2:	c1 e8 1f             	shr    $0x1f,%eax
c0023df5:	01 c8                	add    %ecx,%eax
c0023df7:	d1 f8                	sar    %eax
c0023df9:	05 dc 34 12 00       	add    $0x1234dc,%eax
c0023dfe:	99                   	cltd   
c0023dff:	f7 f9                	idiv   %ecx
c0023e01:	89 c6                	mov    %eax,%esi

  /* Configure the PIT mode and load its counters. */
  old_level = intr_disable ();
c0023e03:	e8 07 dc ff ff       	call   c0021a0f <intr_disable>
c0023e08:	89 c1                	mov    %eax,%ecx
  outb (PIT_PORT_CONTROL, (channel << 6) | 0x30 | (mode << 1));
c0023e0a:	8d 04 3f             	lea    (%edi,%edi,1),%eax
c0023e0d:	83 c8 30             	or     $0x30,%eax
c0023e10:	89 da                	mov    %ebx,%edx
c0023e12:	c1 e2 06             	shl    $0x6,%edx
c0023e15:	09 d0                	or     %edx,%eax
c0023e17:	e6 43                	out    %al,$0x43
  outb (PIT_PORT_COUNTER (channel), count);
c0023e19:	8d 53 40             	lea    0x40(%ebx),%edx
c0023e1c:	89 f0                	mov    %esi,%eax
c0023e1e:	ee                   	out    %al,(%dx)
  outb (PIT_PORT_COUNTER (channel), count >> 8);
c0023e1f:	89 f0                	mov    %esi,%eax
c0023e21:	66 c1 e8 08          	shr    $0x8,%ax
c0023e25:	ee                   	out    %al,(%dx)
  intr_set_level (old_level);
c0023e26:	89 0c 24             	mov    %ecx,(%esp)
c0023e29:	e8 e8 db ff ff       	call   c0021a16 <intr_set_level>
}
c0023e2e:	83 c4 20             	add    $0x20,%esp
c0023e31:	5b                   	pop    %ebx
c0023e32:	5e                   	pop    %esi
c0023e33:	5f                   	pop    %edi
c0023e34:	c3                   	ret    
c0023e35:	90                   	nop
c0023e36:	90                   	nop
c0023e37:	90                   	nop
c0023e38:	90                   	nop
c0023e39:	90                   	nop
c0023e3a:	90                   	nop
c0023e3b:	90                   	nop
c0023e3c:	90                   	nop
c0023e3d:	90                   	nop
c0023e3e:	90                   	nop
c0023e3f:	90                   	nop

c0023e40 <compareSleep>:
        return true;
    }
    //then check if the wakeup times are equal
    else if (tPointer1->wakeup == tPointer1->wakeup) {
        //if they are, then comapare using priority
        if (tPointer1->priority > tPointer2->priority) {
c0023e40:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023e44:	8b 54 24 04          	mov    0x4(%esp),%edx
c0023e48:	8b 40 f4             	mov    -0xc(%eax),%eax
c0023e4b:	39 42 f4             	cmp    %eax,-0xc(%edx)
c0023e4e:	0f 9f c0             	setg   %al
        }
    }
    //if all tests fail, return false
    return false;

}
c0023e51:	c3                   	ret    

c0023e52 <busy_wait>:
   affect timings, so that if this function was inlined
   differently in different places the results would be difficult
   to predict. */
static void NO_INLINE
busy_wait (int64_t loops) 
{
c0023e52:	53                   	push   %ebx
  while (loops-- > 0)
c0023e53:	89 c1                	mov    %eax,%ecx
c0023e55:	89 d3                	mov    %edx,%ebx
c0023e57:	83 c1 ff             	add    $0xffffffff,%ecx
c0023e5a:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023e5d:	85 d2                	test   %edx,%edx
c0023e5f:	78 18                	js     c0023e79 <busy_wait+0x27>
c0023e61:	85 d2                	test   %edx,%edx
c0023e63:	7f 05                	jg     c0023e6a <busy_wait+0x18>
c0023e65:	83 f8 00             	cmp    $0x0,%eax
c0023e68:	76 0f                	jbe    c0023e79 <busy_wait+0x27>
c0023e6a:	83 c1 ff             	add    $0xffffffff,%ecx
c0023e6d:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023e70:	89 c8                	mov    %ecx,%eax
c0023e72:	21 d8                	and    %ebx,%eax
c0023e74:	83 f8 ff             	cmp    $0xffffffff,%eax
c0023e77:	75 f1                	jne    c0023e6a <busy_wait+0x18>
    barrier ();
}
c0023e79:	5b                   	pop    %ebx
c0023e7a:	c3                   	ret    

c0023e7b <too_many_loops>:
{
c0023e7b:	55                   	push   %ebp
c0023e7c:	57                   	push   %edi
c0023e7d:	56                   	push   %esi
c0023e7e:	53                   	push   %ebx
c0023e7f:	83 ec 04             	sub    $0x4,%esp
  int64_t start = ticks;
c0023e82:	8b 2d 70 77 03 c0    	mov    0xc0037770,%ebp
c0023e88:	8b 3d 74 77 03 c0    	mov    0xc0037774,%edi
  while (ticks == start)
c0023e8e:	8b 35 70 77 03 c0    	mov    0xc0037770,%esi
c0023e94:	8b 1d 74 77 03 c0    	mov    0xc0037774,%ebx
c0023e9a:	89 d9                	mov    %ebx,%ecx
c0023e9c:	31 f9                	xor    %edi,%ecx
c0023e9e:	89 f2                	mov    %esi,%edx
c0023ea0:	31 ea                	xor    %ebp,%edx
c0023ea2:	09 d1                	or     %edx,%ecx
c0023ea4:	74 e8                	je     c0023e8e <too_many_loops+0x13>
  busy_wait (loops);
c0023ea6:	ba 00 00 00 00       	mov    $0x0,%edx
c0023eab:	e8 a2 ff ff ff       	call   c0023e52 <busy_wait>
  return start != ticks;
c0023eb0:	33 35 70 77 03 c0    	xor    0xc0037770,%esi
c0023eb6:	33 1d 74 77 03 c0    	xor    0xc0037774,%ebx
c0023ebc:	09 de                	or     %ebx,%esi
c0023ebe:	0f 95 c0             	setne  %al
}
c0023ec1:	83 c4 04             	add    $0x4,%esp
c0023ec4:	5b                   	pop    %ebx
c0023ec5:	5e                   	pop    %esi
c0023ec6:	5f                   	pop    %edi
c0023ec7:	5d                   	pop    %ebp
c0023ec8:	c3                   	ret    

c0023ec9 <timer_interrupt>:
{
c0023ec9:	56                   	push   %esi
c0023eca:	53                   	push   %ebx
c0023ecb:	83 ec 14             	sub    $0x14,%esp
  ticks++;
c0023ece:	83 05 70 77 03 c0 01 	addl   $0x1,0xc0037770
c0023ed5:	83 15 74 77 03 c0 00 	adcl   $0x0,0xc0037774
  struct list_elem *e = list_begin(&sleep_list);
c0023edc:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023ee3:	e8 f9 4b 00 00       	call   c0028ae1 <list_begin>
c0023ee8:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023eea:	eb 39                	jmp    c0023f25 <timer_interrupt+0x5c>
      if(ticks >= t->wakeup)
c0023eec:	8b 53 0c             	mov    0xc(%ebx),%edx
c0023eef:	8b 43 10             	mov    0x10(%ebx),%eax
c0023ef2:	3b 05 74 77 03 c0    	cmp    0xc0037774,%eax
c0023ef8:	7f 21                	jg     c0023f1b <timer_interrupt+0x52>
c0023efa:	7c 08                	jl     c0023f04 <timer_interrupt+0x3b>
c0023efc:	3b 15 70 77 03 c0    	cmp    0xc0037770,%edx
c0023f02:	77 17                	ja     c0023f1b <timer_interrupt+0x52>
          e = list_remove(&t->elem);
c0023f04:	8d 73 d8             	lea    -0x28(%ebx),%esi
c0023f07:	89 1c 24             	mov    %ebx,(%esp)
c0023f0a:	e8 25 51 00 00       	call   c0029034 <list_remove>
c0023f0f:	89 c3                	mov    %eax,%ebx
          thread_unblock(t);
c0023f11:	89 34 24             	mov    %esi,(%esp)
c0023f14:	e8 3b ce ff ff       	call   c0020d54 <thread_unblock>
c0023f19:	eb 0a                	jmp    c0023f25 <timer_interrupt+0x5c>
          e = list_next(e);
c0023f1b:	89 1c 24             	mov    %ebx,(%esp)
c0023f1e:	e8 fc 4b 00 00       	call   c0028b1f <list_next>
c0023f23:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023f25:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023f2c:	e8 42 4c 00 00       	call   c0028b73 <list_end>
c0023f31:	39 d8                	cmp    %ebx,%eax
c0023f33:	75 b7                	jne    c0023eec <timer_interrupt+0x23>
  if(thread_mlfqs)
c0023f35:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0023f3c:	0f 84 cb 00 00 00    	je     c002400d <timer_interrupt+0x144>
    if(thread_current() != get_idle_thread())
c0023f42:	e8 e6 ce ff ff       	call   c0020e2d <thread_current>
c0023f47:	89 c3                	mov    %eax,%ebx
c0023f49:	e8 02 d2 ff ff       	call   c0021150 <get_idle_thread>
c0023f4e:	39 c3                	cmp    %eax,%ebx
c0023f50:	74 22                	je     c0023f74 <timer_interrupt+0xab>
      thread_current()->recent_cpu = addXandN(thread_current()->recent_cpu,1);
c0023f52:	e8 d6 ce ff ff       	call   c0020e2d <thread_current>
c0023f57:	89 c3                	mov    %eax,%ebx
c0023f59:	e8 cf ce ff ff       	call   c0020e2d <thread_current>
c0023f5e:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023f65:	00 
c0023f66:	8b 40 58             	mov    0x58(%eax),%eax
c0023f69:	89 04 24             	mov    %eax,(%esp)
c0023f6c:	e8 c3 cb ff ff       	call   c0020b34 <addXandN>
c0023f71:	89 43 58             	mov    %eax,0x58(%ebx)
    if(ticks % TIMER_FREQ == 0)
c0023f74:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0023f7b:	00 
c0023f7c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023f83:	00 
c0023f84:	a1 70 77 03 c0       	mov    0xc0037770,%eax
c0023f89:	8b 15 74 77 03 c0    	mov    0xc0037774,%edx
c0023f8f:	89 04 24             	mov    %eax,(%esp)
c0023f92:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023f96:	e8 ab 43 00 00       	call   c0028346 <__moddi3>
c0023f9b:	09 c2                	or     %eax,%edx
c0023f9d:	75 4c                	jne    c0023feb <timer_interrupt+0x122>
       setLoadAv(multXbyY(constant1,getLoadAv()) + multXbyN(constant2,get_ready_threads()));
c0023f9f:	e8 9c d1 ff ff       	call   c0021140 <getLoadAv>
c0023fa4:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023fa8:	a1 c8 7b 03 c0       	mov    0xc0037bc8,%eax
c0023fad:	89 04 24             	mov    %eax,(%esp)
c0023fb0:	e8 a3 cb ff ff       	call   c0020b58 <multXbyY>
c0023fb5:	89 c3                	mov    %eax,%ebx
c0023fb7:	e8 40 d1 ff ff       	call   c00210fc <get_ready_threads>
c0023fbc:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023fc0:	a1 c4 7b 03 c0       	mov    0xc0037bc4,%eax
c0023fc5:	89 04 24             	mov    %eax,(%esp)
c0023fc8:	e8 d9 cb ff ff       	call   c0020ba6 <multXbyN>
c0023fcd:	01 c3                	add    %eax,%ebx
c0023fcf:	89 1c 24             	mov    %ebx,(%esp)
c0023fd2:	e8 6f d1 ff ff       	call   c0021146 <setLoadAv>
       thread_foreach (calculate_recent_cpu, 0);
c0023fd7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023fde:	00 
c0023fdf:	c7 04 24 da 0f 02 c0 	movl   $0xc0020fda,(%esp)
c0023fe6:	e8 23 cf ff ff       	call   c0020f0e <thread_foreach>
     if(ticks % 2 == 0) //--- responsible for test mlfqs-fair-20 passing, change to 2 org = 4
c0023feb:	f6 05 70 77 03 c0 01 	testb  $0x1,0xc0037770
c0023ff2:	75 19                	jne    c002400d <timer_interrupt+0x144>
       thread_foreach (calcPrio, 0);
c0023ff4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023ffb:	00 
c0023ffc:	c7 04 24 7b 10 02 c0 	movl   $0xc002107b,(%esp)
c0024003:	e8 06 cf ff ff       	call   c0020f0e <thread_foreach>
       intr_yield_on_return ();
c0024008:	e8 6c dc ff ff       	call   c0021c79 <intr_yield_on_return>
  thread_tick ();
c002400d:	e8 96 ce ff ff       	call   c0020ea8 <thread_tick>
}
c0024012:	83 c4 14             	add    $0x14,%esp
c0024015:	5b                   	pop    %ebx
c0024016:	5e                   	pop    %esi
c0024017:	c3                   	ret    

c0024018 <real_time_delay>:
}

/* Busy-wait for approximately NUM/DENOM seconds. */
static void
real_time_delay (int64_t num, int32_t denom)
{
c0024018:	55                   	push   %ebp
c0024019:	57                   	push   %edi
c002401a:	56                   	push   %esi
c002401b:	53                   	push   %ebx
c002401c:	83 ec 2c             	sub    $0x2c,%esp
c002401f:	89 c7                	mov    %eax,%edi
c0024021:	89 d6                	mov    %edx,%esi
c0024023:	89 cb                	mov    %ecx,%ebx
  /* Scale the numerator and denominator down by 1000 to avoid
     the possibility of overflow. */
  ASSERT (denom % 1000 == 0);
c0024025:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c002402a:	89 c8                	mov    %ecx,%eax
c002402c:	f7 ea                	imul   %edx
c002402e:	c1 fa 06             	sar    $0x6,%edx
c0024031:	89 c8                	mov    %ecx,%eax
c0024033:	c1 f8 1f             	sar    $0x1f,%eax
c0024036:	29 c2                	sub    %eax,%edx
c0024038:	69 d2 e8 03 00 00    	imul   $0x3e8,%edx,%edx
c002403e:	39 d1                	cmp    %edx,%ecx
c0024040:	74 2c                	je     c002406e <real_time_delay+0x56>
c0024042:	c7 44 24 10 2b ed 02 	movl   $0xc002ed2b,0x10(%esp)
c0024049:	c0 
c002404a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024051:	c0 
c0024052:	c7 44 24 08 27 d3 02 	movl   $0xc002d327,0x8(%esp)
c0024059:	c0 
c002405a:	c7 44 24 04 49 01 00 	movl   $0x149,0x4(%esp)
c0024061:	00 
c0024062:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c0024069:	e8 55 49 00 00       	call   c00289c3 <debug_panic>
  busy_wait (loops_per_tick * num / 1000 * TIMER_FREQ / (denom / 1000)); 
c002406e:	a1 68 77 03 c0       	mov    0xc0037768,%eax
c0024073:	0f af f0             	imul   %eax,%esi
c0024076:	f7 e7                	mul    %edi
c0024078:	01 f2                	add    %esi,%edx
c002407a:	c7 44 24 08 e8 03 00 	movl   $0x3e8,0x8(%esp)
c0024081:	00 
c0024082:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0024089:	00 
c002408a:	89 04 24             	mov    %eax,(%esp)
c002408d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0024091:	e8 8d 42 00 00       	call   c0028323 <__divdi3>
c0024096:	6b ea 64             	imul   $0x64,%edx,%ebp
c0024099:	b9 64 00 00 00       	mov    $0x64,%ecx
c002409e:	f7 e1                	mul    %ecx
c00240a0:	89 c6                	mov    %eax,%esi
c00240a2:	89 d7                	mov    %edx,%edi
c00240a4:	01 ef                	add    %ebp,%edi
c00240a6:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c00240ab:	89 d8                	mov    %ebx,%eax
c00240ad:	f7 ea                	imul   %edx
c00240af:	c1 fa 06             	sar    $0x6,%edx
c00240b2:	c1 fb 1f             	sar    $0x1f,%ebx
c00240b5:	29 da                	sub    %ebx,%edx
c00240b7:	89 54 24 08          	mov    %edx,0x8(%esp)
c00240bb:	89 d0                	mov    %edx,%eax
c00240bd:	c1 f8 1f             	sar    $0x1f,%eax
c00240c0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00240c4:	89 34 24             	mov    %esi,(%esp)
c00240c7:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00240cb:	e8 53 42 00 00       	call   c0028323 <__divdi3>
c00240d0:	e8 7d fd ff ff       	call   c0023e52 <busy_wait>
c00240d5:	83 c4 2c             	add    $0x2c,%esp
c00240d8:	5b                   	pop    %ebx
c00240d9:	5e                   	pop    %esi
c00240da:	5f                   	pop    %edi
c00240db:	5d                   	pop    %ebp
c00240dc:	c3                   	ret    

c00240dd <timer_init>:
{
c00240dd:	83 ec 1c             	sub    $0x1c,%esp
  pit_configure_channel (0, 2, TIMER_FREQ);
c00240e0:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c00240e7:	00 
c00240e8:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
c00240ef:	00 
c00240f0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c00240f7:	e8 63 fc ff ff       	call   c0023d5f <pit_configure_channel>
  intr_register_ext (0x20, timer_interrupt, "8254 Timer");
c00240fc:	c7 44 24 08 53 ed 02 	movl   $0xc002ed53,0x8(%esp)
c0024103:	c0 
c0024104:	c7 44 24 04 c9 3e 02 	movl   $0xc0023ec9,0x4(%esp)
c002410b:	c0 
c002410c:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0024113:	e8 9b da ff ff       	call   c0021bb3 <intr_register_ext>
  list_init (&sleep_list);
c0024118:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c002411f:	e8 6c 49 00 00       	call   c0028a90 <list_init>
  constant1 = divXbyN(convertNtoFixedPoint(59),60);
c0024124:	c7 04 24 3b 00 00 00 	movl   $0x3b,(%esp)
c002412b:	e8 0b c8 ff ff       	call   c002093b <convertNtoFixedPoint>
c0024130:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c0024137:	00 
c0024138:	89 04 24             	mov    %eax,(%esp)
c002413b:	e8 bd ca ff ff       	call   c0020bfd <divXbyN>
c0024140:	a3 c8 7b 03 c0       	mov    %eax,0xc0037bc8
  constant2 = divXbyN(convertNtoFixedPoint(1),60);
c0024145:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c002414c:	e8 ea c7 ff ff       	call   c002093b <convertNtoFixedPoint>
c0024151:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c0024158:	00 
c0024159:	89 04 24             	mov    %eax,(%esp)
c002415c:	e8 9c ca ff ff       	call   c0020bfd <divXbyN>
c0024161:	a3 c4 7b 03 c0       	mov    %eax,0xc0037bc4
}
c0024166:	83 c4 1c             	add    $0x1c,%esp
c0024169:	c3                   	ret    

c002416a <timer_calibrate>:
{
c002416a:	57                   	push   %edi
c002416b:	56                   	push   %esi
c002416c:	53                   	push   %ebx
c002416d:	83 ec 20             	sub    $0x20,%esp
  ASSERT (intr_get_level () == INTR_ON);
c0024170:	e8 4f d8 ff ff       	call   c00219c4 <intr_get_level>
c0024175:	83 f8 01             	cmp    $0x1,%eax
c0024178:	74 2c                	je     c00241a6 <timer_calibrate+0x3c>
c002417a:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c0024181:	c0 
c0024182:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024189:	c0 
c002418a:	c7 44 24 08 53 d3 02 	movl   $0xc002d353,0x8(%esp)
c0024191:	c0 
c0024192:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c0024199:	00 
c002419a:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c00241a1:	e8 1d 48 00 00       	call   c00289c3 <debug_panic>
  printf ("Calibrating timer...  ");
c00241a6:	c7 04 24 7b ed 02 c0 	movl   $0xc002ed7b,(%esp)
c00241ad:	e8 bc 29 00 00       	call   c0026b6e <printf>
  loops_per_tick = 1u << 10;
c00241b2:	c7 05 68 77 03 c0 00 	movl   $0x400,0xc0037768
c00241b9:	04 00 00 
  while (!too_many_loops (loops_per_tick << 1)) 
c00241bc:	eb 36                	jmp    c00241f4 <timer_calibrate+0x8a>
      loops_per_tick <<= 1;
c00241be:	89 1d 68 77 03 c0    	mov    %ebx,0xc0037768
      ASSERT (loops_per_tick != 0);
c00241c4:	85 db                	test   %ebx,%ebx
c00241c6:	75 2c                	jne    c00241f4 <timer_calibrate+0x8a>
c00241c8:	c7 44 24 10 92 ed 02 	movl   $0xc002ed92,0x10(%esp)
c00241cf:	c0 
c00241d0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00241d7:	c0 
c00241d8:	c7 44 24 08 53 d3 02 	movl   $0xc002d353,0x8(%esp)
c00241df:	c0 
c00241e0:	c7 44 24 04 4e 00 00 	movl   $0x4e,0x4(%esp)
c00241e7:	00 
c00241e8:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c00241ef:	e8 cf 47 00 00       	call   c00289c3 <debug_panic>
  while (!too_many_loops (loops_per_tick << 1)) 
c00241f4:	8b 35 68 77 03 c0    	mov    0xc0037768,%esi
c00241fa:	8d 1c 36             	lea    (%esi,%esi,1),%ebx
c00241fd:	89 d8                	mov    %ebx,%eax
c00241ff:	e8 77 fc ff ff       	call   c0023e7b <too_many_loops>
c0024204:	84 c0                	test   %al,%al
c0024206:	74 b6                	je     c00241be <timer_calibrate+0x54>
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c0024208:	89 f3                	mov    %esi,%ebx
c002420a:	d1 eb                	shr    %ebx
c002420c:	89 f7                	mov    %esi,%edi
c002420e:	c1 ef 0a             	shr    $0xa,%edi
c0024211:	39 df                	cmp    %ebx,%edi
c0024213:	74 19                	je     c002422e <timer_calibrate+0xc4>
    if (!too_many_loops (high_bit | test_bit))
c0024215:	89 d8                	mov    %ebx,%eax
c0024217:	09 f0                	or     %esi,%eax
c0024219:	e8 5d fc ff ff       	call   c0023e7b <too_many_loops>
c002421e:	84 c0                	test   %al,%al
c0024220:	75 06                	jne    c0024228 <timer_calibrate+0xbe>
      loops_per_tick |= test_bit;
c0024222:	09 1d 68 77 03 c0    	or     %ebx,0xc0037768
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c0024228:	d1 eb                	shr    %ebx
c002422a:	39 df                	cmp    %ebx,%edi
c002422c:	75 e7                	jne    c0024215 <timer_calibrate+0xab>
  printf ("%'"PRIu64" loops/s.\n", (uint64_t) loops_per_tick * TIMER_FREQ);
c002422e:	b8 64 00 00 00       	mov    $0x64,%eax
c0024233:	f7 25 68 77 03 c0    	mull   0xc0037768
c0024239:	89 44 24 04          	mov    %eax,0x4(%esp)
c002423d:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024241:	c7 04 24 a6 ed 02 c0 	movl   $0xc002eda6,(%esp)
c0024248:	e8 21 29 00 00       	call   c0026b6e <printf>
}
c002424d:	83 c4 20             	add    $0x20,%esp
c0024250:	5b                   	pop    %ebx
c0024251:	5e                   	pop    %esi
c0024252:	5f                   	pop    %edi
c0024253:	c3                   	ret    

c0024254 <timer_ticks>:
{
c0024254:	56                   	push   %esi
c0024255:	53                   	push   %ebx
c0024256:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level = intr_disable ();
c0024259:	e8 b1 d7 ff ff       	call   c0021a0f <intr_disable>
  int64_t t = ticks;
c002425e:	8b 15 70 77 03 c0    	mov    0xc0037770,%edx
c0024264:	8b 0d 74 77 03 c0    	mov    0xc0037774,%ecx
c002426a:	89 d3                	mov    %edx,%ebx
c002426c:	89 ce                	mov    %ecx,%esi
  intr_set_level (old_level);
c002426e:	89 04 24             	mov    %eax,(%esp)
c0024271:	e8 a0 d7 ff ff       	call   c0021a16 <intr_set_level>
}
c0024276:	89 d8                	mov    %ebx,%eax
c0024278:	89 f2                	mov    %esi,%edx
c002427a:	83 c4 14             	add    $0x14,%esp
c002427d:	5b                   	pop    %ebx
c002427e:	5e                   	pop    %esi
c002427f:	c3                   	ret    

c0024280 <timer_elapsed>:
{
c0024280:	57                   	push   %edi
c0024281:	56                   	push   %esi
c0024282:	83 ec 04             	sub    $0x4,%esp
c0024285:	8b 74 24 10          	mov    0x10(%esp),%esi
c0024289:	8b 7c 24 14          	mov    0x14(%esp),%edi
  return timer_ticks () - then;
c002428d:	e8 c2 ff ff ff       	call   c0024254 <timer_ticks>
c0024292:	29 f0                	sub    %esi,%eax
c0024294:	19 fa                	sbb    %edi,%edx
}
c0024296:	83 c4 04             	add    $0x4,%esp
c0024299:	5e                   	pop    %esi
c002429a:	5f                   	pop    %edi
c002429b:	c3                   	ret    

c002429c <timer_sleep>:
{
c002429c:	57                   	push   %edi
c002429d:	56                   	push   %esi
c002429e:	53                   	push   %ebx
c002429f:	83 ec 20             	sub    $0x20,%esp
c00242a2:	8b 74 24 30          	mov    0x30(%esp),%esi
c00242a6:	8b 7c 24 34          	mov    0x34(%esp),%edi
    ASSERT (intr_get_level () == INTR_ON);
c00242aa:	e8 15 d7 ff ff       	call   c00219c4 <intr_get_level>
c00242af:	83 f8 01             	cmp    $0x1,%eax
c00242b2:	74 2c                	je     c00242e0 <timer_sleep+0x44>
c00242b4:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c00242bb:	c0 
c00242bc:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00242c3:	c0 
c00242c4:	c7 44 24 08 47 d3 02 	movl   $0xc002d347,0x8(%esp)
c00242cb:	c0 
c00242cc:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
c00242d3:	00 
c00242d4:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c00242db:	e8 e3 46 00 00       	call   c00289c3 <debug_panic>
    struct thread *cur = thread_current ();
c00242e0:	e8 48 cb ff ff       	call   c0020e2d <thread_current>
c00242e5:	89 c3                	mov    %eax,%ebx
    cur->wakeup = timer_ticks () + ticks; //save the wakeup time of each thread as a struct attribute
c00242e7:	e8 68 ff ff ff       	call   c0024254 <timer_ticks>
c00242ec:	01 f0                	add    %esi,%eax
c00242ee:	11 fa                	adc    %edi,%edx
c00242f0:	89 43 34             	mov    %eax,0x34(%ebx)
c00242f3:	89 53 38             	mov    %edx,0x38(%ebx)
    old_level = intr_disable ();
c00242f6:	e8 14 d7 ff ff       	call   c0021a0f <intr_disable>
c00242fb:	89 c6                	mov    %eax,%esi
    list_insert_ordered(&sleep_list, &cur->elem, compareSleep, 0); //add each thread as a list elem to the sleep_list based on wakeup time
c00242fd:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0024304:	00 
c0024305:	c7 44 24 08 40 3e 02 	movl   $0xc0023e40,0x8(%esp)
c002430c:	c0 
c002430d:	83 c3 28             	add    $0x28,%ebx
c0024310:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024314:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c002431b:	e8 96 51 00 00       	call   c00294b6 <list_insert_ordered>
    thread_block(); //block the thread 
c0024320:	e8 40 d0 ff ff       	call   c0021365 <thread_block>
    intr_set_level (old_level); //set interrupts back to orginal status
c0024325:	89 34 24             	mov    %esi,(%esp)
c0024328:	e8 e9 d6 ff ff       	call   c0021a16 <intr_set_level>
}
c002432d:	83 c4 20             	add    $0x20,%esp
c0024330:	5b                   	pop    %ebx
c0024331:	5e                   	pop    %esi
c0024332:	5f                   	pop    %edi
c0024333:	c3                   	ret    

c0024334 <real_time_sleep>:
{
c0024334:	55                   	push   %ebp
c0024335:	57                   	push   %edi
c0024336:	56                   	push   %esi
c0024337:	53                   	push   %ebx
c0024338:	83 ec 2c             	sub    $0x2c,%esp
c002433b:	89 c7                	mov    %eax,%edi
c002433d:	89 d6                	mov    %edx,%esi
c002433f:	89 cd                	mov    %ecx,%ebp
  int64_t ticks = num * TIMER_FREQ / denom;
c0024341:	6b ca 64             	imul   $0x64,%edx,%ecx
c0024344:	b8 64 00 00 00       	mov    $0x64,%eax
c0024349:	f7 e7                	mul    %edi
c002434b:	01 ca                	add    %ecx,%edx
c002434d:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0024351:	89 e9                	mov    %ebp,%ecx
c0024353:	c1 f9 1f             	sar    $0x1f,%ecx
c0024356:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002435a:	89 04 24             	mov    %eax,(%esp)
c002435d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0024361:	e8 bd 3f 00 00       	call   c0028323 <__divdi3>
c0024366:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002436a:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_ON);
c002436c:	e8 53 d6 ff ff       	call   c00219c4 <intr_get_level>
c0024371:	83 f8 01             	cmp    $0x1,%eax
c0024374:	74 2c                	je     c00243a2 <real_time_sleep+0x6e>
c0024376:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c002437d:	c0 
c002437e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024385:	c0 
c0024386:	c7 44 24 08 37 d3 02 	movl   $0xc002d337,0x8(%esp)
c002438d:	c0 
c002438e:	c7 44 24 04 33 01 00 	movl   $0x133,0x4(%esp)
c0024395:	00 
c0024396:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c002439d:	e8 21 46 00 00       	call   c00289c3 <debug_panic>
  if (ticks > 0)
c00243a2:	85 db                	test   %ebx,%ebx
c00243a4:	78 1e                	js     c00243c4 <real_time_sleep+0x90>
c00243a6:	85 db                	test   %ebx,%ebx
c00243a8:	7f 08                	jg     c00243b2 <real_time_sleep+0x7e>
c00243aa:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c00243af:	90                   	nop
c00243b0:	76 12                	jbe    c00243c4 <real_time_sleep+0x90>
      timer_sleep (ticks); 
c00243b2:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c00243b6:	89 04 24             	mov    %eax,(%esp)
c00243b9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00243bd:	e8 da fe ff ff       	call   c002429c <timer_sleep>
c00243c2:	eb 0b                	jmp    c00243cf <real_time_sleep+0x9b>
      real_time_delay (num, denom); 
c00243c4:	89 e9                	mov    %ebp,%ecx
c00243c6:	89 f8                	mov    %edi,%eax
c00243c8:	89 f2                	mov    %esi,%edx
c00243ca:	e8 49 fc ff ff       	call   c0024018 <real_time_delay>
}
c00243cf:	83 c4 2c             	add    $0x2c,%esp
c00243d2:	5b                   	pop    %ebx
c00243d3:	5e                   	pop    %esi
c00243d4:	5f                   	pop    %edi
c00243d5:	5d                   	pop    %ebp
c00243d6:	c3                   	ret    

c00243d7 <timer_msleep>:
{
c00243d7:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ms, 1000);
c00243da:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c00243df:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243e3:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243e7:	e8 48 ff ff ff       	call   c0024334 <real_time_sleep>
}
c00243ec:	83 c4 0c             	add    $0xc,%esp
c00243ef:	c3                   	ret    

c00243f0 <timer_usleep>:
{
c00243f0:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (us, 1000 * 1000);
c00243f3:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00243f8:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243fc:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024400:	e8 2f ff ff ff       	call   c0024334 <real_time_sleep>
}
c0024405:	83 c4 0c             	add    $0xc,%esp
c0024408:	c3                   	ret    

c0024409 <timer_nsleep>:
{
c0024409:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ns, 1000 * 1000 * 1000);
c002440c:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c0024411:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024415:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024419:	e8 16 ff ff ff       	call   c0024334 <real_time_sleep>
}
c002441e:	83 c4 0c             	add    $0xc,%esp
c0024421:	c3                   	ret    

c0024422 <timer_mdelay>:
{
c0024422:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ms, 1000);
c0024425:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002442a:	8b 44 24 10          	mov    0x10(%esp),%eax
c002442e:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024432:	e8 e1 fb ff ff       	call   c0024018 <real_time_delay>
}
c0024437:	83 c4 0c             	add    $0xc,%esp
c002443a:	c3                   	ret    

c002443b <timer_udelay>:
{
c002443b:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (us, 1000 * 1000);
c002443e:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c0024443:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024447:	8b 54 24 14          	mov    0x14(%esp),%edx
c002444b:	e8 c8 fb ff ff       	call   c0024018 <real_time_delay>
}
c0024450:	83 c4 0c             	add    $0xc,%esp
c0024453:	c3                   	ret    

c0024454 <timer_ndelay>:
{
c0024454:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ns, 1000 * 1000 * 1000);
c0024457:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c002445c:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024460:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024464:	e8 af fb ff ff       	call   c0024018 <real_time_delay>
}
c0024469:	83 c4 0c             	add    $0xc,%esp
c002446c:	c3                   	ret    

c002446d <timer_print_stats>:
{
c002446d:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Timer: %"PRId64" ticks\n", timer_ticks ());
c0024470:	e8 df fd ff ff       	call   c0024254 <timer_ticks>
c0024475:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024479:	89 54 24 08          	mov    %edx,0x8(%esp)
c002447d:	c7 04 24 b6 ed 02 c0 	movl   $0xc002edb6,(%esp)
c0024484:	e8 e5 26 00 00       	call   c0026b6e <printf>
}
c0024489:	83 c4 1c             	add    $0x1c,%esp
c002448c:	c3                   	ret    
c002448d:	90                   	nop
c002448e:	90                   	nop
c002448f:	90                   	nop

c0024490 <map_key>:
   If found, sets *C to the corresponding character and returns
   true.
   If not found, returns false and C is ignored. */
static bool
map_key (const struct keymap k[], unsigned scancode, uint8_t *c) 
{
c0024490:	55                   	push   %ebp
c0024491:	57                   	push   %edi
c0024492:	56                   	push   %esi
c0024493:	53                   	push   %ebx
c0024494:	83 ec 04             	sub    $0x4,%esp
c0024497:	89 c3                	mov    %eax,%ebx
c0024499:	89 0c 24             	mov    %ecx,(%esp)
  for (; k->first_scancode != 0; k++)
c002449c:	0f b6 08             	movzbl (%eax),%ecx
c002449f:	84 c9                	test   %cl,%cl
c00244a1:	74 41                	je     c00244e4 <map_key+0x54>
    if (scancode >= k->first_scancode
        && scancode < k->first_scancode + strlen (k->chars)) 
c00244a3:	b8 00 00 00 00       	mov    $0x0,%eax
    if (scancode >= k->first_scancode
c00244a8:	0f b6 f1             	movzbl %cl,%esi
c00244ab:	39 d6                	cmp    %edx,%esi
c00244ad:	77 29                	ja     c00244d8 <map_key+0x48>
        && scancode < k->first_scancode + strlen (k->chars)) 
c00244af:	8b 6b 04             	mov    0x4(%ebx),%ebp
c00244b2:	89 ef                	mov    %ebp,%edi
c00244b4:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c00244b9:	f2 ae                	repnz scas %es:(%edi),%al
c00244bb:	f7 d1                	not    %ecx
c00244bd:	8d 4c 0e ff          	lea    -0x1(%esi,%ecx,1),%ecx
c00244c1:	39 ca                	cmp    %ecx,%edx
c00244c3:	73 13                	jae    c00244d8 <map_key+0x48>
      {
        *c = k->chars[scancode - k->first_scancode];
c00244c5:	29 f2                	sub    %esi,%edx
c00244c7:	0f b6 44 15 00       	movzbl 0x0(%ebp,%edx,1),%eax
c00244cc:	8b 3c 24             	mov    (%esp),%edi
c00244cf:	88 07                	mov    %al,(%edi)
        return true; 
c00244d1:	b8 01 00 00 00       	mov    $0x1,%eax
c00244d6:	eb 18                	jmp    c00244f0 <map_key+0x60>
  for (; k->first_scancode != 0; k++)
c00244d8:	83 c3 08             	add    $0x8,%ebx
c00244db:	0f b6 0b             	movzbl (%ebx),%ecx
c00244de:	84 c9                	test   %cl,%cl
c00244e0:	75 c6                	jne    c00244a8 <map_key+0x18>
c00244e2:	eb 07                	jmp    c00244eb <map_key+0x5b>
      }

  return false;
c00244e4:	b8 00 00 00 00       	mov    $0x0,%eax
c00244e9:	eb 05                	jmp    c00244f0 <map_key+0x60>
c00244eb:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00244f0:	83 c4 04             	add    $0x4,%esp
c00244f3:	5b                   	pop    %ebx
c00244f4:	5e                   	pop    %esi
c00244f5:	5f                   	pop    %edi
c00244f6:	5d                   	pop    %ebp
c00244f7:	c3                   	ret    

c00244f8 <keyboard_interrupt>:
{
c00244f8:	55                   	push   %ebp
c00244f9:	57                   	push   %edi
c00244fa:	56                   	push   %esi
c00244fb:	53                   	push   %ebx
c00244fc:	83 ec 2c             	sub    $0x2c,%esp
  bool shift = left_shift || right_shift;
c00244ff:	0f b6 15 85 77 03 c0 	movzbl 0xc0037785,%edx
c0024506:	80 3d 86 77 03 c0 00 	cmpb   $0x0,0xc0037786
c002450d:	b8 01 00 00 00       	mov    $0x1,%eax
c0024512:	0f 45 d0             	cmovne %eax,%edx
  bool alt = left_alt || right_alt;
c0024515:	0f b6 3d 83 77 03 c0 	movzbl 0xc0037783,%edi
c002451c:	80 3d 84 77 03 c0 00 	cmpb   $0x0,0xc0037784
c0024523:	0f 45 f8             	cmovne %eax,%edi
  bool ctrl = left_ctrl || right_ctrl;
c0024526:	0f b6 2d 81 77 03 c0 	movzbl 0xc0037781,%ebp
c002452d:	80 3d 82 77 03 c0 00 	cmpb   $0x0,0xc0037782
c0024534:	0f 45 e8             	cmovne %eax,%ebp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024537:	e4 60                	in     $0x60,%al
  code = inb (DATA_REG);
c0024539:	0f b6 d8             	movzbl %al,%ebx
  if (code == 0xe0)
c002453c:	81 fb e0 00 00 00    	cmp    $0xe0,%ebx
c0024542:	75 08                	jne    c002454c <keyboard_interrupt+0x54>
c0024544:	e4 60                	in     $0x60,%al
    code = (code << 8) | inb (DATA_REG);
c0024546:	0f b6 d8             	movzbl %al,%ebx
c0024549:	80 cf e0             	or     $0xe0,%bh
  release = (code & 0x80) != 0;
c002454c:	89 de                	mov    %ebx,%esi
c002454e:	c1 ee 07             	shr    $0x7,%esi
c0024551:	83 e6 01             	and    $0x1,%esi
  code &= ~0x80u;
c0024554:	80 e3 7f             	and    $0x7f,%bl
  if (code == 0x3a) 
c0024557:	83 fb 3a             	cmp    $0x3a,%ebx
c002455a:	75 16                	jne    c0024572 <keyboard_interrupt+0x7a>
      if (!release)
c002455c:	89 f0                	mov    %esi,%eax
c002455e:	84 c0                	test   %al,%al
c0024560:	0f 85 1d 01 00 00    	jne    c0024683 <keyboard_interrupt+0x18b>
        caps_lock = !caps_lock;
c0024566:	80 35 80 77 03 c0 01 	xorb   $0x1,0xc0037780
c002456d:	e9 11 01 00 00       	jmp    c0024683 <keyboard_interrupt+0x18b>
  bool shift = left_shift || right_shift;
c0024572:	89 d0                	mov    %edx,%eax
c0024574:	83 e0 01             	and    $0x1,%eax
c0024577:	88 44 24 0f          	mov    %al,0xf(%esp)
  else if (map_key (invariant_keymap, code, &c)
c002457b:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002457f:	89 da                	mov    %ebx,%edx
c0024581:	b8 40 d4 02 c0       	mov    $0xc002d440,%eax
c0024586:	e8 05 ff ff ff       	call   c0024490 <map_key>
c002458b:	84 c0                	test   %al,%al
c002458d:	75 23                	jne    c00245b2 <keyboard_interrupt+0xba>
           || (!shift && map_key (unshifted_keymap, code, &c))
c002458f:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0024594:	0f 85 c5 00 00 00    	jne    c002465f <keyboard_interrupt+0x167>
c002459a:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002459e:	89 da                	mov    %ebx,%edx
c00245a0:	b8 00 d4 02 c0       	mov    $0xc002d400,%eax
c00245a5:	e8 e6 fe ff ff       	call   c0024490 <map_key>
c00245aa:	84 c0                	test   %al,%al
c00245ac:	0f 84 c5 00 00 00    	je     c0024677 <keyboard_interrupt+0x17f>
      if (!release) 
c00245b2:	89 f0                	mov    %esi,%eax
c00245b4:	84 c0                	test   %al,%al
c00245b6:	0f 85 c7 00 00 00    	jne    c0024683 <keyboard_interrupt+0x18b>
          if (c == 0177 && ctrl && alt)
c00245bc:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c00245c1:	3c 7f                	cmp    $0x7f,%al
c00245c3:	75 0f                	jne    c00245d4 <keyboard_interrupt+0xdc>
c00245c5:	21 fd                	and    %edi,%ebp
c00245c7:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c00245cd:	74 1b                	je     c00245ea <keyboard_interrupt+0xf2>
            shutdown_reboot ();
c00245cf:	e8 06 1e 00 00       	call   c00263da <shutdown_reboot>
          if (ctrl && c >= 0x40 && c < 0x60) 
c00245d4:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c00245da:	74 0e                	je     c00245ea <keyboard_interrupt+0xf2>
c00245dc:	8d 50 c0             	lea    -0x40(%eax),%edx
c00245df:	80 fa 1f             	cmp    $0x1f,%dl
c00245e2:	77 06                	ja     c00245ea <keyboard_interrupt+0xf2>
              c -= 0x40; 
c00245e4:	88 54 24 1f          	mov    %dl,0x1f(%esp)
c00245e8:	eb 20                	jmp    c002460a <keyboard_interrupt+0x112>
          else if (shift == caps_lock)
c00245ea:	0f b6 4c 24 0f       	movzbl 0xf(%esp),%ecx
c00245ef:	3a 0d 80 77 03 c0    	cmp    0xc0037780,%cl
c00245f5:	75 13                	jne    c002460a <keyboard_interrupt+0x112>
            c = tolower (c);
c00245f7:	0f b6 c0             	movzbl %al,%eax
#ifndef __LIB_CTYPE_H
#define __LIB_CTYPE_H

static inline int islower (int c) { return c >= 'a' && c <= 'z'; }
static inline int isupper (int c) { return c >= 'A' && c <= 'Z'; }
c00245fa:	8d 48 bf             	lea    -0x41(%eax),%ecx
static inline int isascii (int c) { return c >= 0 && c < 128; }
static inline int ispunct (int c) {
  return isprint (c) && !isalnum (c) && !isspace (c);
}

static inline int tolower (int c) { return isupper (c) ? c - 'A' + 'a' : c; }
c00245fd:	8d 50 20             	lea    0x20(%eax),%edx
c0024600:	83 f9 19             	cmp    $0x19,%ecx
c0024603:	0f 46 c2             	cmovbe %edx,%eax
c0024606:	88 44 24 1f          	mov    %al,0x1f(%esp)
          if (alt)
c002460a:	f7 c7 01 00 00 00    	test   $0x1,%edi
c0024610:	74 05                	je     c0024617 <keyboard_interrupt+0x11f>
            c += 0x80;
c0024612:	80 44 24 1f 80       	addb   $0x80,0x1f(%esp)
          if (!input_full ())
c0024617:	e8 11 18 00 00       	call   c0025e2d <input_full>
c002461c:	84 c0                	test   %al,%al
c002461e:	75 63                	jne    c0024683 <keyboard_interrupt+0x18b>
              key_cnt++;
c0024620:	83 05 78 77 03 c0 01 	addl   $0x1,0xc0037778
c0024627:	83 15 7c 77 03 c0 00 	adcl   $0x0,0xc003777c
              input_putc (c);
c002462e:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c0024633:	89 04 24             	mov    %eax,(%esp)
c0024636:	e8 2d 17 00 00       	call   c0025d68 <input_putc>
c002463b:	eb 46                	jmp    c0024683 <keyboard_interrupt+0x18b>
        if (key->scancode == code)
c002463d:	39 d3                	cmp    %edx,%ebx
c002463f:	75 13                	jne    c0024654 <keyboard_interrupt+0x15c>
c0024641:	eb 05                	jmp    c0024648 <keyboard_interrupt+0x150>
      for (key = shift_keys; key->scancode != 0; key++) 
c0024643:	b8 80 d3 02 c0       	mov    $0xc002d380,%eax
            *key->state_var = !release;
c0024648:	8b 40 04             	mov    0x4(%eax),%eax
c002464b:	89 f2                	mov    %esi,%edx
c002464d:	83 f2 01             	xor    $0x1,%edx
c0024650:	88 10                	mov    %dl,(%eax)
            break;
c0024652:	eb 2f                	jmp    c0024683 <keyboard_interrupt+0x18b>
      for (key = shift_keys; key->scancode != 0; key++) 
c0024654:	83 c0 08             	add    $0x8,%eax
c0024657:	8b 10                	mov    (%eax),%edx
c0024659:	85 d2                	test   %edx,%edx
c002465b:	75 e0                	jne    c002463d <keyboard_interrupt+0x145>
c002465d:	eb 24                	jmp    c0024683 <keyboard_interrupt+0x18b>
           || (shift && map_key (shifted_keymap, code, &c)))
c002465f:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c0024663:	89 da                	mov    %ebx,%edx
c0024665:	b8 c0 d3 02 c0       	mov    $0xc002d3c0,%eax
c002466a:	e8 21 fe ff ff       	call   c0024490 <map_key>
c002466f:	84 c0                	test   %al,%al
c0024671:	0f 85 3b ff ff ff    	jne    c00245b2 <keyboard_interrupt+0xba>
        if (key->scancode == code)
c0024677:	83 fb 2a             	cmp    $0x2a,%ebx
c002467a:	74 c7                	je     c0024643 <keyboard_interrupt+0x14b>
      for (key = shift_keys; key->scancode != 0; key++) 
c002467c:	b8 80 d3 02 c0       	mov    $0xc002d380,%eax
c0024681:	eb d1                	jmp    c0024654 <keyboard_interrupt+0x15c>
}
c0024683:	83 c4 2c             	add    $0x2c,%esp
c0024686:	5b                   	pop    %ebx
c0024687:	5e                   	pop    %esi
c0024688:	5f                   	pop    %edi
c0024689:	5d                   	pop    %ebp
c002468a:	c3                   	ret    

c002468b <kbd_init>:
{
c002468b:	83 ec 1c             	sub    $0x1c,%esp
  intr_register_ext (0x21, keyboard_interrupt, "8042 Keyboard");
c002468e:	c7 44 24 08 c9 ed 02 	movl   $0xc002edc9,0x8(%esp)
c0024695:	c0 
c0024696:	c7 44 24 04 f8 44 02 	movl   $0xc00244f8,0x4(%esp)
c002469d:	c0 
c002469e:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c00246a5:	e8 09 d5 ff ff       	call   c0021bb3 <intr_register_ext>
}
c00246aa:	83 c4 1c             	add    $0x1c,%esp
c00246ad:	c3                   	ret    

c00246ae <kbd_print_stats>:
{
c00246ae:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Keyboard: %lld keys pressed\n", key_cnt);
c00246b1:	a1 78 77 03 c0       	mov    0xc0037778,%eax
c00246b6:	8b 15 7c 77 03 c0    	mov    0xc003777c,%edx
c00246bc:	89 44 24 04          	mov    %eax,0x4(%esp)
c00246c0:	89 54 24 08          	mov    %edx,0x8(%esp)
c00246c4:	c7 04 24 d7 ed 02 c0 	movl   $0xc002edd7,(%esp)
c00246cb:	e8 9e 24 00 00       	call   c0026b6e <printf>
}
c00246d0:	83 c4 1c             	add    $0x1c,%esp
c00246d3:	c3                   	ret    
c00246d4:	90                   	nop
c00246d5:	90                   	nop
c00246d6:	90                   	nop
c00246d7:	90                   	nop
c00246d8:	90                   	nop
c00246d9:	90                   	nop
c00246da:	90                   	nop
c00246db:	90                   	nop
c00246dc:	90                   	nop
c00246dd:	90                   	nop
c00246de:	90                   	nop
c00246df:	90                   	nop

c00246e0 <move_cursor>:
/* Moves the hardware cursor to (cx,cy). */
static void
move_cursor (void) 
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp = cx + COL_CNT * cy;
c00246e0:	8b 0d 90 77 03 c0    	mov    0xc0037790,%ecx
c00246e6:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c00246e9:	c1 e1 04             	shl    $0x4,%ecx
c00246ec:	66 03 0d 94 77 03 c0 	add    0xc0037794,%cx
  outw (0x3d4, 0x0e | (cp & 0xff00));
c00246f3:	89 c8                	mov    %ecx,%eax
c00246f5:	b0 00                	mov    $0x0,%al
c00246f7:	83 c8 0e             	or     $0xe,%eax
/* Writes the 16-bit DATA to PORT. */
static inline void
outw (uint16_t port, uint16_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c00246fa:	ba d4 03 00 00       	mov    $0x3d4,%edx
c00246ff:	66 ef                	out    %ax,(%dx)
  outw (0x3d4, 0x0f | (cp << 8));
c0024701:	89 c8                	mov    %ecx,%eax
c0024703:	c1 e0 08             	shl    $0x8,%eax
c0024706:	83 c8 0f             	or     $0xf,%eax
c0024709:	66 ef                	out    %ax,(%dx)
c002470b:	c3                   	ret    

c002470c <newline>:
  cx = 0;
c002470c:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024713:	00 00 00 
  cy++;
c0024716:	a1 90 77 03 c0       	mov    0xc0037790,%eax
c002471b:	83 c0 01             	add    $0x1,%eax
  if (cy >= ROW_CNT)
c002471e:	83 f8 18             	cmp    $0x18,%eax
c0024721:	77 06                	ja     c0024729 <newline+0x1d>
  cy++;
c0024723:	a3 90 77 03 c0       	mov    %eax,0xc0037790
c0024728:	c3                   	ret    
{
c0024729:	53                   	push   %ebx
c002472a:	83 ec 18             	sub    $0x18,%esp
      cy = ROW_CNT - 1;
c002472d:	c7 05 90 77 03 c0 18 	movl   $0x18,0xc0037790
c0024734:	00 00 00 
      memmove (&fb[0], &fb[1], sizeof fb[0] * (ROW_CNT - 1));
c0024737:	8b 1d 8c 77 03 c0    	mov    0xc003778c,%ebx
c002473d:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
c0024744:	00 
c0024745:	8d 83 a0 00 00 00    	lea    0xa0(%ebx),%eax
c002474b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002474f:	89 1c 24             	mov    %ebx,(%esp)
c0024752:	e8 e6 31 00 00       	call   c002793d <memmove>
  for (x = 0; x < COL_CNT; x++)
c0024757:	b8 00 00 00 00       	mov    $0x0,%eax
      fb[y][x][0] = ' ';
c002475c:	c6 84 43 00 0f 00 00 	movb   $0x20,0xf00(%ebx,%eax,2)
c0024763:	20 
      fb[y][x][1] = GRAY_ON_BLACK;
c0024764:	c6 84 43 01 0f 00 00 	movb   $0x7,0xf01(%ebx,%eax,2)
c002476b:	07 
  for (x = 0; x < COL_CNT; x++)
c002476c:	83 c0 01             	add    $0x1,%eax
c002476f:	83 f8 50             	cmp    $0x50,%eax
c0024772:	75 e8                	jne    c002475c <newline+0x50>
}
c0024774:	83 c4 18             	add    $0x18,%esp
c0024777:	5b                   	pop    %ebx
c0024778:	c3                   	ret    

c0024779 <vga_putc>:
{
c0024779:	57                   	push   %edi
c002477a:	56                   	push   %esi
c002477b:	53                   	push   %ebx
c002477c:	83 ec 10             	sub    $0x10,%esp
c002477f:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  enum intr_level old_level = intr_disable ();
c0024783:	e8 87 d2 ff ff       	call   c0021a0f <intr_disable>
c0024788:	89 c6                	mov    %eax,%esi
  if (!inited)
c002478a:	80 3d 88 77 03 c0 00 	cmpb   $0x0,0xc0037788
c0024791:	75 5e                	jne    c00247f1 <vga_putc+0x78>
      fb = ptov (0xb8000);
c0024793:	c7 05 8c 77 03 c0 00 	movl   $0xc00b8000,0xc003778c
c002479a:	80 0b c0 
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002479d:	ba d4 03 00 00       	mov    $0x3d4,%edx
c00247a2:	b8 0e 00 00 00       	mov    $0xe,%eax
c00247a7:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00247a8:	b9 d5 03 00 00       	mov    $0x3d5,%ecx
c00247ad:	89 ca                	mov    %ecx,%edx
c00247af:	ec                   	in     (%dx),%al
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp;

  outb (0x3d4, 0x0e);
  cp = inb (0x3d5) << 8;
c00247b0:	89 c7                	mov    %eax,%edi
c00247b2:	c1 e7 08             	shl    $0x8,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00247b5:	b2 d4                	mov    $0xd4,%dl
c00247b7:	b8 0f 00 00 00       	mov    $0xf,%eax
c00247bc:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00247bd:	89 ca                	mov    %ecx,%edx
c00247bf:	ec                   	in     (%dx),%al

  outb (0x3d4, 0x0f);
  cp |= inb (0x3d5);
c00247c0:	0f b6 d0             	movzbl %al,%edx
c00247c3:	09 fa                	or     %edi,%edx

  *x = cp % COL_CNT;
c00247c5:	0f b7 c2             	movzwl %dx,%eax
c00247c8:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
c00247ce:	c1 e8 16             	shr    $0x16,%eax
c00247d1:	8d 0c 80             	lea    (%eax,%eax,4),%ecx
c00247d4:	c1 e1 04             	shl    $0x4,%ecx
c00247d7:	29 ca                	sub    %ecx,%edx
c00247d9:	0f b7 d2             	movzwl %dx,%edx
c00247dc:	89 15 94 77 03 c0    	mov    %edx,0xc0037794
  *y = cp / COL_CNT;
c00247e2:	0f b7 c0             	movzwl %ax,%eax
c00247e5:	a3 90 77 03 c0       	mov    %eax,0xc0037790
      inited = true; 
c00247ea:	c6 05 88 77 03 c0 01 	movb   $0x1,0xc0037788
  switch (c) 
c00247f1:	8d 43 f9             	lea    -0x7(%ebx),%eax
c00247f4:	83 f8 06             	cmp    $0x6,%eax
c00247f7:	0f 87 b8 00 00 00    	ja     c00248b5 <vga_putc+0x13c>
c00247fd:	ff 24 85 90 d4 02 c0 	jmp    *-0x3ffd2b70(,%eax,4)
c0024804:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
      fb[y][x][0] = ' ';
c0024809:	bb 00 00 00 00       	mov    $0x0,%ebx
c002480e:	eb 28                	jmp    c0024838 <vga_putc+0xbf>
      newline ();
c0024810:	e8 f7 fe ff ff       	call   c002470c <newline>
      break;
c0024815:	e9 e7 00 00 00       	jmp    c0024901 <vga_putc+0x188>
      fb[y][x][0] = ' ';
c002481a:	c6 04 51 20          	movb   $0x20,(%ecx,%edx,2)
      fb[y][x][1] = GRAY_ON_BLACK;
c002481e:	c6 44 51 01 07       	movb   $0x7,0x1(%ecx,%edx,2)
  for (x = 0; x < COL_CNT; x++)
c0024823:	83 c2 01             	add    $0x1,%edx
c0024826:	83 fa 50             	cmp    $0x50,%edx
c0024829:	75 ef                	jne    c002481a <vga_putc+0xa1>
  for (y = 0; y < ROW_CNT; y++)
c002482b:	83 c3 01             	add    $0x1,%ebx
c002482e:	05 a0 00 00 00       	add    $0xa0,%eax
c0024833:	83 fb 19             	cmp    $0x19,%ebx
c0024836:	74 09                	je     c0024841 <vga_putc+0xc8>
      fb[y][x][0] = ' ';
c0024838:	89 c1                	mov    %eax,%ecx
c002483a:	ba 00 00 00 00       	mov    $0x0,%edx
c002483f:	eb d9                	jmp    c002481a <vga_putc+0xa1>
  cx = cy = 0;
c0024841:	c7 05 90 77 03 c0 00 	movl   $0x0,0xc0037790
c0024848:	00 00 00 
c002484b:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024852:	00 00 00 
  move_cursor ();
c0024855:	e8 86 fe ff ff       	call   c00246e0 <move_cursor>
c002485a:	e9 a2 00 00 00       	jmp    c0024901 <vga_putc+0x188>
      if (cx > 0)
c002485f:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c0024864:	85 c0                	test   %eax,%eax
c0024866:	0f 84 95 00 00 00    	je     c0024901 <vga_putc+0x188>
        cx--;
c002486c:	83 e8 01             	sub    $0x1,%eax
c002486f:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c0024874:	e9 88 00 00 00       	jmp    c0024901 <vga_putc+0x188>
      cx = 0;
c0024879:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024880:	00 00 00 
      break;
c0024883:	eb 7c                	jmp    c0024901 <vga_putc+0x188>
      cx = ROUND_UP (cx + 1, 8);
c0024885:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c002488a:	83 c0 08             	add    $0x8,%eax
c002488d:	83 e0 f8             	and    $0xfffffff8,%eax
c0024890:	a3 94 77 03 c0       	mov    %eax,0xc0037794
      if (cx >= COL_CNT)
c0024895:	83 f8 4f             	cmp    $0x4f,%eax
c0024898:	76 67                	jbe    c0024901 <vga_putc+0x188>
        newline ();
c002489a:	e8 6d fe ff ff       	call   c002470c <newline>
c002489f:	eb 60                	jmp    c0024901 <vga_putc+0x188>
      intr_set_level (old_level);
c00248a1:	89 34 24             	mov    %esi,(%esp)
c00248a4:	e8 6d d1 ff ff       	call   c0021a16 <intr_set_level>
      speaker_beep ();
c00248a9:	e8 bd 1c 00 00       	call   c002656b <speaker_beep>
      intr_disable ();
c00248ae:	e8 5c d1 ff ff       	call   c0021a0f <intr_disable>
      break;
c00248b3:	eb 4c                	jmp    c0024901 <vga_putc+0x188>
      fb[cy][cx][0] = c;
c00248b5:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
c00248ba:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c00248c0:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00248c3:	c1 e2 05             	shl    $0x5,%edx
c00248c6:	01 c2                	add    %eax,%edx
c00248c8:	8b 0d 94 77 03 c0    	mov    0xc0037794,%ecx
c00248ce:	88 1c 4a             	mov    %bl,(%edx,%ecx,2)
      fb[cy][cx][1] = GRAY_ON_BLACK;
c00248d1:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c00248d7:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00248da:	c1 e2 05             	shl    $0x5,%edx
c00248dd:	01 d0                	add    %edx,%eax
c00248df:	8b 15 94 77 03 c0    	mov    0xc0037794,%edx
c00248e5:	c6 44 50 01 07       	movb   $0x7,0x1(%eax,%edx,2)
      if (++cx >= COL_CNT)
c00248ea:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c00248ef:	83 c0 01             	add    $0x1,%eax
c00248f2:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c00248f7:	83 f8 4f             	cmp    $0x4f,%eax
c00248fa:	76 05                	jbe    c0024901 <vga_putc+0x188>
        newline ();
c00248fc:	e8 0b fe ff ff       	call   c002470c <newline>
  move_cursor ();
c0024901:	e8 da fd ff ff       	call   c00246e0 <move_cursor>
  intr_set_level (old_level);
c0024906:	89 34 24             	mov    %esi,(%esp)
c0024909:	e8 08 d1 ff ff       	call   c0021a16 <intr_set_level>
}
c002490e:	83 c4 10             	add    $0x10,%esp
c0024911:	5b                   	pop    %ebx
c0024912:	5e                   	pop    %esi
c0024913:	5f                   	pop    %edi
c0024914:	c3                   	ret    
c0024915:	90                   	nop
c0024916:	90                   	nop
c0024917:	90                   	nop
c0024918:	90                   	nop
c0024919:	90                   	nop
c002491a:	90                   	nop
c002491b:	90                   	nop
c002491c:	90                   	nop
c002491d:	90                   	nop
c002491e:	90                   	nop
c002491f:	90                   	nop

c0024920 <init_poll>:
   Polling mode busy-waits for the serial port to become free
   before writing to it.  It's slow, but until interrupts have
   been initialized it's all we can do. */
static void
init_poll (void) 
{
c0024920:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (mode == UNINIT);
c0024923:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c002492a:	74 2c                	je     c0024958 <init_poll+0x38>
c002492c:	c7 44 24 10 50 ee 02 	movl   $0xc002ee50,0x10(%esp)
c0024933:	c0 
c0024934:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002493b:	c0 
c002493c:	c7 44 24 08 ce d4 02 	movl   $0xc002d4ce,0x8(%esp)
c0024943:	c0 
c0024944:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c002494b:	00 
c002494c:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024953:	e8 6b 40 00 00       	call   c00289c3 <debug_panic>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024958:	ba f9 03 00 00       	mov    $0x3f9,%edx
c002495d:	b8 00 00 00 00       	mov    $0x0,%eax
c0024962:	ee                   	out    %al,(%dx)
c0024963:	b2 fa                	mov    $0xfa,%dl
c0024965:	ee                   	out    %al,(%dx)
c0024966:	b2 fb                	mov    $0xfb,%dl
c0024968:	b8 83 ff ff ff       	mov    $0xffffff83,%eax
c002496d:	ee                   	out    %al,(%dx)
c002496e:	b2 f8                	mov    $0xf8,%dl
c0024970:	b8 0c 00 00 00       	mov    $0xc,%eax
c0024975:	ee                   	out    %al,(%dx)
c0024976:	b2 f9                	mov    $0xf9,%dl
c0024978:	b8 00 00 00 00       	mov    $0x0,%eax
c002497d:	ee                   	out    %al,(%dx)
c002497e:	b2 fb                	mov    $0xfb,%dl
c0024980:	b8 03 00 00 00       	mov    $0x3,%eax
c0024985:	ee                   	out    %al,(%dx)
c0024986:	b2 fc                	mov    $0xfc,%dl
c0024988:	b8 08 00 00 00       	mov    $0x8,%eax
c002498d:	ee                   	out    %al,(%dx)
  outb (IER_REG, 0);                    /* Turn off all interrupts. */
  outb (FCR_REG, 0);                    /* Disable FIFO. */
  set_serial (9600);                    /* 9.6 kbps, N-8-1. */
  outb (MCR_REG, MCR_OUT2);             /* Required to enable interrupts. */
  intq_init (&txq);
c002498e:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024995:	e8 db 14 00 00       	call   c0025e75 <intq_init>
  mode = POLL;
c002499a:	c7 05 14 78 03 c0 01 	movl   $0x1,0xc0037814
c00249a1:	00 00 00 
} 
c00249a4:	83 c4 2c             	add    $0x2c,%esp
c00249a7:	c3                   	ret    

c00249a8 <write_ier>:
}

/* Update interrupt enable register. */
static void
write_ier (void) 
{
c00249a8:	53                   	push   %ebx
c00249a9:	83 ec 28             	sub    $0x28,%esp
  uint8_t ier = 0;

  ASSERT (intr_get_level () == INTR_OFF);
c00249ac:	e8 13 d0 ff ff       	call   c00219c4 <intr_get_level>
c00249b1:	85 c0                	test   %eax,%eax
c00249b3:	74 2c                	je     c00249e1 <write_ier+0x39>
c00249b5:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00249bc:	c0 
c00249bd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00249c4:	c0 
c00249c5:	c7 44 24 08 c4 d4 02 	movl   $0xc002d4c4,0x8(%esp)
c00249cc:	c0 
c00249cd:	c7 44 24 04 b5 00 00 	movl   $0xb5,0x4(%esp)
c00249d4:	00 
c00249d5:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c00249dc:	e8 e2 3f 00 00       	call   c00289c3 <debug_panic>

  /* Enable transmit interrupt if we have any characters to
     transmit. */
  if (!intq_empty (&txq))
c00249e1:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c00249e8:	e8 b9 14 00 00       	call   c0025ea6 <intq_empty>
  uint8_t ier = 0;
c00249ed:	3c 01                	cmp    $0x1,%al
c00249ef:	19 db                	sbb    %ebx,%ebx
c00249f1:	83 e3 02             	and    $0x2,%ebx
    ier |= IER_XMIT;

  /* Enable receive interrupt if we have room to store any
     characters we receive. */
  if (!input_full ())
c00249f4:	e8 34 14 00 00       	call   c0025e2d <input_full>
    ier |= IER_RECV;
c00249f9:	89 da                	mov    %ebx,%edx
c00249fb:	83 ca 01             	or     $0x1,%edx
c00249fe:	84 c0                	test   %al,%al
c0024a00:	0f 44 da             	cmove  %edx,%ebx
c0024a03:	ba f9 03 00 00       	mov    $0x3f9,%edx
c0024a08:	89 d8                	mov    %ebx,%eax
c0024a0a:	ee                   	out    %al,(%dx)
  
  outb (IER_REG, ier);
}
c0024a0b:	83 c4 28             	add    $0x28,%esp
c0024a0e:	5b                   	pop    %ebx
c0024a0f:	c3                   	ret    

c0024a10 <serial_interrupt>:
}

/* Serial interrupt handler. */
static void
serial_interrupt (struct intr_frame *f UNUSED) 
{
c0024a10:	56                   	push   %esi
c0024a11:	53                   	push   %ebx
c0024a12:	83 ec 14             	sub    $0x14,%esp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a15:	ba fa 03 00 00       	mov    $0x3fa,%edx
c0024a1a:	ec                   	in     (%dx),%al
c0024a1b:	bb fd 03 00 00       	mov    $0x3fd,%ebx
c0024a20:	be f8 03 00 00       	mov    $0x3f8,%esi
c0024a25:	eb 0e                	jmp    c0024a35 <serial_interrupt+0x25>
c0024a27:	89 f2                	mov    %esi,%edx
c0024a29:	ec                   	in     (%dx),%al
  inb (IIR_REG);

  /* As long as we have room to receive a byte, and the hardware
     has a byte for us, receive a byte.  */
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
    input_putc (inb (RBR_REG));
c0024a2a:	0f b6 c0             	movzbl %al,%eax
c0024a2d:	89 04 24             	mov    %eax,(%esp)
c0024a30:	e8 33 13 00 00       	call   c0025d68 <input_putc>
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
c0024a35:	e8 f3 13 00 00       	call   c0025e2d <input_full>
c0024a3a:	84 c0                	test   %al,%al
c0024a3c:	74 0c                	je     c0024a4a <serial_interrupt+0x3a>
c0024a3e:	bb fd 03 00 00       	mov    $0x3fd,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a43:	be f8 03 00 00       	mov    $0x3f8,%esi
c0024a48:	eb 18                	jmp    c0024a62 <serial_interrupt+0x52>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a4a:	89 da                	mov    %ebx,%edx
c0024a4c:	ec                   	in     (%dx),%al
c0024a4d:	a8 01                	test   $0x1,%al
c0024a4f:	75 d6                	jne    c0024a27 <serial_interrupt+0x17>
c0024a51:	eb eb                	jmp    c0024a3e <serial_interrupt+0x2e>

  /* As long as we have a byte to transmit, and the hardware is
     ready to accept a byte for transmission, transmit a byte. */
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
    outb (THR_REG, intq_getc (&txq));
c0024a53:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a5a:	e8 70 16 00 00       	call   c00260cf <intq_getc>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a5f:	89 f2                	mov    %esi,%edx
c0024a61:	ee                   	out    %al,(%dx)
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
c0024a62:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a69:	e8 38 14 00 00       	call   c0025ea6 <intq_empty>
c0024a6e:	84 c0                	test   %al,%al
c0024a70:	75 07                	jne    c0024a79 <serial_interrupt+0x69>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a72:	89 da                	mov    %ebx,%edx
c0024a74:	ec                   	in     (%dx),%al
c0024a75:	a8 20                	test   $0x20,%al
c0024a77:	75 da                	jne    c0024a53 <serial_interrupt+0x43>

  /* Update interrupt enable register based on queue status. */
  write_ier ();
c0024a79:	e8 2a ff ff ff       	call   c00249a8 <write_ier>
}
c0024a7e:	83 c4 14             	add    $0x14,%esp
c0024a81:	5b                   	pop    %ebx
c0024a82:	5e                   	pop    %esi
c0024a83:	c3                   	ret    

c0024a84 <putc_poll>:
{
c0024a84:	53                   	push   %ebx
c0024a85:	83 ec 28             	sub    $0x28,%esp
c0024a88:	89 c3                	mov    %eax,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0024a8a:	e8 35 cf ff ff       	call   c00219c4 <intr_get_level>
c0024a8f:	85 c0                	test   %eax,%eax
c0024a91:	74 2c                	je     c0024abf <putc_poll+0x3b>
c0024a93:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0024a9a:	c0 
c0024a9b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024aa2:	c0 
c0024aa3:	c7 44 24 08 ba d4 02 	movl   $0xc002d4ba,0x8(%esp)
c0024aaa:	c0 
c0024aab:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c0024ab2:	00 
c0024ab3:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024aba:	e8 04 3f 00 00       	call   c00289c3 <debug_panic>
c0024abf:	ba fd 03 00 00       	mov    $0x3fd,%edx
c0024ac4:	ec                   	in     (%dx),%al
  while ((inb (LSR_REG) & LSR_THRE) == 0)
c0024ac5:	a8 20                	test   $0x20,%al
c0024ac7:	74 fb                	je     c0024ac4 <putc_poll+0x40>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024ac9:	ba f8 03 00 00       	mov    $0x3f8,%edx
c0024ace:	89 d8                	mov    %ebx,%eax
c0024ad0:	ee                   	out    %al,(%dx)
}
c0024ad1:	83 c4 28             	add    $0x28,%esp
c0024ad4:	5b                   	pop    %ebx
c0024ad5:	c3                   	ret    

c0024ad6 <serial_init_queue>:
{
c0024ad6:	53                   	push   %ebx
c0024ad7:	83 ec 28             	sub    $0x28,%esp
  if (mode == UNINIT)
c0024ada:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c0024ae1:	75 05                	jne    c0024ae8 <serial_init_queue+0x12>
    init_poll ();
c0024ae3:	e8 38 fe ff ff       	call   c0024920 <init_poll>
  ASSERT (mode == POLL);
c0024ae8:	83 3d 14 78 03 c0 01 	cmpl   $0x1,0xc0037814
c0024aef:	74 2c                	je     c0024b1d <serial_init_queue+0x47>
c0024af1:	c7 44 24 10 76 ee 02 	movl   $0xc002ee76,0x10(%esp)
c0024af8:	c0 
c0024af9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024b00:	c0 
c0024b01:	c7 44 24 08 d8 d4 02 	movl   $0xc002d4d8,0x8(%esp)
c0024b08:	c0 
c0024b09:	c7 44 24 04 58 00 00 	movl   $0x58,0x4(%esp)
c0024b10:	00 
c0024b11:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024b18:	e8 a6 3e 00 00       	call   c00289c3 <debug_panic>
  intr_register_ext (0x20 + 4, serial_interrupt, "serial");
c0024b1d:	c7 44 24 08 83 ee 02 	movl   $0xc002ee83,0x8(%esp)
c0024b24:	c0 
c0024b25:	c7 44 24 04 10 4a 02 	movl   $0xc0024a10,0x4(%esp)
c0024b2c:	c0 
c0024b2d:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
c0024b34:	e8 7a d0 ff ff       	call   c0021bb3 <intr_register_ext>
  mode = QUEUE;
c0024b39:	c7 05 14 78 03 c0 02 	movl   $0x2,0xc0037814
c0024b40:	00 00 00 
  old_level = intr_disable ();
c0024b43:	e8 c7 ce ff ff       	call   c0021a0f <intr_disable>
c0024b48:	89 c3                	mov    %eax,%ebx
  write_ier ();
c0024b4a:	e8 59 fe ff ff       	call   c00249a8 <write_ier>
  intr_set_level (old_level);
c0024b4f:	89 1c 24             	mov    %ebx,(%esp)
c0024b52:	e8 bf ce ff ff       	call   c0021a16 <intr_set_level>
}
c0024b57:	83 c4 28             	add    $0x28,%esp
c0024b5a:	5b                   	pop    %ebx
c0024b5b:	c3                   	ret    

c0024b5c <serial_putc>:
{
c0024b5c:	56                   	push   %esi
c0024b5d:	53                   	push   %ebx
c0024b5e:	83 ec 14             	sub    $0x14,%esp
c0024b61:	8b 74 24 20          	mov    0x20(%esp),%esi
  enum intr_level old_level = intr_disable ();
c0024b65:	e8 a5 ce ff ff       	call   c0021a0f <intr_disable>
c0024b6a:	89 c3                	mov    %eax,%ebx
  if (mode != QUEUE)
c0024b6c:	8b 15 14 78 03 c0    	mov    0xc0037814,%edx
c0024b72:	83 fa 02             	cmp    $0x2,%edx
c0024b75:	74 15                	je     c0024b8c <serial_putc+0x30>
      if (mode == UNINIT)
c0024b77:	85 d2                	test   %edx,%edx
c0024b79:	75 05                	jne    c0024b80 <serial_putc+0x24>
        init_poll ();
c0024b7b:	e8 a0 fd ff ff       	call   c0024920 <init_poll>
      putc_poll (byte); 
c0024b80:	89 f0                	mov    %esi,%eax
c0024b82:	0f b6 c0             	movzbl %al,%eax
c0024b85:	e8 fa fe ff ff       	call   c0024a84 <putc_poll>
c0024b8a:	eb 42                	jmp    c0024bce <serial_putc+0x72>
      if (old_level == INTR_OFF && intq_full (&txq)) 
c0024b8c:	85 c0                	test   %eax,%eax
c0024b8e:	75 24                	jne    c0024bb4 <serial_putc+0x58>
c0024b90:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b97:	e8 55 13 00 00       	call   c0025ef1 <intq_full>
c0024b9c:	84 c0                	test   %al,%al
c0024b9e:	74 14                	je     c0024bb4 <serial_putc+0x58>
          putc_poll (intq_getc (&txq)); 
c0024ba0:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024ba7:	e8 23 15 00 00       	call   c00260cf <intq_getc>
c0024bac:	0f b6 c0             	movzbl %al,%eax
c0024baf:	e8 d0 fe ff ff       	call   c0024a84 <putc_poll>
      intq_putc (&txq, byte); 
c0024bb4:	89 f0                	mov    %esi,%eax
c0024bb6:	0f b6 f0             	movzbl %al,%esi
c0024bb9:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024bbd:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024bc4:	e8 d2 15 00 00       	call   c002619b <intq_putc>
      write_ier ();
c0024bc9:	e8 da fd ff ff       	call   c00249a8 <write_ier>
  intr_set_level (old_level);
c0024bce:	89 1c 24             	mov    %ebx,(%esp)
c0024bd1:	e8 40 ce ff ff       	call   c0021a16 <intr_set_level>
}
c0024bd6:	83 c4 14             	add    $0x14,%esp
c0024bd9:	5b                   	pop    %ebx
c0024bda:	5e                   	pop    %esi
c0024bdb:	c3                   	ret    

c0024bdc <serial_flush>:
{
c0024bdc:	53                   	push   %ebx
c0024bdd:	83 ec 18             	sub    $0x18,%esp
  enum intr_level old_level = intr_disable ();
c0024be0:	e8 2a ce ff ff       	call   c0021a0f <intr_disable>
c0024be5:	89 c3                	mov    %eax,%ebx
  while (!intq_empty (&txq))
c0024be7:	eb 14                	jmp    c0024bfd <serial_flush+0x21>
    putc_poll (intq_getc (&txq));
c0024be9:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024bf0:	e8 da 14 00 00       	call   c00260cf <intq_getc>
c0024bf5:	0f b6 c0             	movzbl %al,%eax
c0024bf8:	e8 87 fe ff ff       	call   c0024a84 <putc_poll>
  while (!intq_empty (&txq))
c0024bfd:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024c04:	e8 9d 12 00 00       	call   c0025ea6 <intq_empty>
c0024c09:	84 c0                	test   %al,%al
c0024c0b:	74 dc                	je     c0024be9 <serial_flush+0xd>
  intr_set_level (old_level);
c0024c0d:	89 1c 24             	mov    %ebx,(%esp)
c0024c10:	e8 01 ce ff ff       	call   c0021a16 <intr_set_level>
}
c0024c15:	83 c4 18             	add    $0x18,%esp
c0024c18:	5b                   	pop    %ebx
c0024c19:	c3                   	ret    

c0024c1a <serial_notify>:
{
c0024c1a:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0024c1d:	e8 a2 cd ff ff       	call   c00219c4 <intr_get_level>
c0024c22:	85 c0                	test   %eax,%eax
c0024c24:	74 2c                	je     c0024c52 <serial_notify+0x38>
c0024c26:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0024c2d:	c0 
c0024c2e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024c35:	c0 
c0024c36:	c7 44 24 08 ac d4 02 	movl   $0xc002d4ac,0x8(%esp)
c0024c3d:	c0 
c0024c3e:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
c0024c45:	00 
c0024c46:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024c4d:	e8 71 3d 00 00       	call   c00289c3 <debug_panic>
  if (mode == QUEUE)
c0024c52:	83 3d 14 78 03 c0 02 	cmpl   $0x2,0xc0037814
c0024c59:	75 05                	jne    c0024c60 <serial_notify+0x46>
    write_ier ();
c0024c5b:	e8 48 fd ff ff       	call   c00249a8 <write_ier>
}
c0024c60:	83 c4 2c             	add    $0x2c,%esp
c0024c63:	c3                   	ret    

c0024c64 <check_sector>:
/* Verifies that SECTOR is a valid offset within BLOCK.
   Panics if not. */
static void
check_sector (struct block *block, block_sector_t sector)
{
  if (sector >= block->size)
c0024c64:	8b 48 1c             	mov    0x1c(%eax),%ecx
c0024c67:	39 d1                	cmp    %edx,%ecx
c0024c69:	77 36                	ja     c0024ca1 <check_sector+0x3d>
{
c0024c6b:	83 ec 2c             	sub    $0x2c,%esp
    {
      /* We do not use ASSERT because we want to panic here
         regardless of whether NDEBUG is defined. */
      PANIC ("Access past end of device %s (sector=%"PRDSNu", "
c0024c6e:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024c72:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024c76:	83 c0 08             	add    $0x8,%eax
c0024c79:	89 44 24 10          	mov    %eax,0x10(%esp)
c0024c7d:	c7 44 24 0c 8c ee 02 	movl   $0xc002ee8c,0xc(%esp)
c0024c84:	c0 
c0024c85:	c7 44 24 08 07 d5 02 	movl   $0xc002d507,0x8(%esp)
c0024c8c:	c0 
c0024c8d:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
c0024c94:	00 
c0024c95:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024c9c:	e8 22 3d 00 00       	call   c00289c3 <debug_panic>
c0024ca1:	f3 c3                	repz ret 

c0024ca3 <block_type_name>:
{
c0024ca3:	83 ec 2c             	sub    $0x2c,%esp
c0024ca6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (type < BLOCK_CNT);
c0024caa:	83 f8 05             	cmp    $0x5,%eax
c0024cad:	76 2c                	jbe    c0024cdb <block_type_name+0x38>
c0024caf:	c7 44 24 10 30 ef 02 	movl   $0xc002ef30,0x10(%esp)
c0024cb6:	c0 
c0024cb7:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024cbe:	c0 
c0024cbf:	c7 44 24 08 4c d5 02 	movl   $0xc002d54c,0x8(%esp)
c0024cc6:	c0 
c0024cc7:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0024cce:	00 
c0024ccf:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024cd6:	e8 e8 3c 00 00       	call   c00289c3 <debug_panic>
  return block_type_names[type];
c0024cdb:	8b 04 85 34 d5 02 c0 	mov    -0x3ffd2acc(,%eax,4),%eax
}
c0024ce2:	83 c4 2c             	add    $0x2c,%esp
c0024ce5:	c3                   	ret    

c0024ce6 <block_get_role>:
{
c0024ce6:	83 ec 2c             	sub    $0x2c,%esp
c0024ce9:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024ced:	83 f8 03             	cmp    $0x3,%eax
c0024cf0:	76 2c                	jbe    c0024d1e <block_get_role+0x38>
c0024cf2:	c7 44 24 10 41 ef 02 	movl   $0xc002ef41,0x10(%esp)
c0024cf9:	c0 
c0024cfa:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024d01:	c0 
c0024d02:	c7 44 24 08 23 d5 02 	movl   $0xc002d523,0x8(%esp)
c0024d09:	c0 
c0024d0a:	c7 44 24 04 38 00 00 	movl   $0x38,0x4(%esp)
c0024d11:	00 
c0024d12:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024d19:	e8 a5 3c 00 00       	call   c00289c3 <debug_panic>
  return block_by_role[role];
c0024d1e:	8b 04 85 18 78 03 c0 	mov    -0x3ffc87e8(,%eax,4),%eax
}
c0024d25:	83 c4 2c             	add    $0x2c,%esp
c0024d28:	c3                   	ret    

c0024d29 <block_set_role>:
{
c0024d29:	83 ec 2c             	sub    $0x2c,%esp
c0024d2c:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024d30:	83 f8 03             	cmp    $0x3,%eax
c0024d33:	76 2c                	jbe    c0024d61 <block_set_role+0x38>
c0024d35:	c7 44 24 10 41 ef 02 	movl   $0xc002ef41,0x10(%esp)
c0024d3c:	c0 
c0024d3d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024d44:	c0 
c0024d45:	c7 44 24 08 14 d5 02 	movl   $0xc002d514,0x8(%esp)
c0024d4c:	c0 
c0024d4d:	c7 44 24 04 40 00 00 	movl   $0x40,0x4(%esp)
c0024d54:	00 
c0024d55:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024d5c:	e8 62 3c 00 00       	call   c00289c3 <debug_panic>
  block_by_role[role] = block;
c0024d61:	8b 54 24 34          	mov    0x34(%esp),%edx
c0024d65:	89 14 85 18 78 03 c0 	mov    %edx,-0x3ffc87e8(,%eax,4)
}
c0024d6c:	83 c4 2c             	add    $0x2c,%esp
c0024d6f:	c3                   	ret    

c0024d70 <block_first>:
{
c0024d70:	53                   	push   %ebx
c0024d71:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_begin (&all_blocks));
c0024d74:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024d7b:	e8 61 3d 00 00       	call   c0028ae1 <list_begin>
c0024d80:	89 c3                	mov    %eax,%ebx
/* Returns the block device corresponding to LIST_ELEM, or a null
   pointer if LIST_ELEM is the list end of all_blocks. */
static struct block *
list_elem_to_block (struct list_elem *list_elem)
{
  return (list_elem != list_end (&all_blocks)
c0024d82:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024d89:	e8 e5 3d 00 00       	call   c0028b73 <list_end>
          ? list_entry (list_elem, struct block, list_elem)
          : NULL);
c0024d8e:	39 c3                	cmp    %eax,%ebx
c0024d90:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d95:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d98:	83 c4 18             	add    $0x18,%esp
c0024d9b:	5b                   	pop    %ebx
c0024d9c:	c3                   	ret    

c0024d9d <block_next>:
{
c0024d9d:	53                   	push   %ebx
c0024d9e:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_next (&block->list_elem));
c0024da1:	8b 44 24 20          	mov    0x20(%esp),%eax
c0024da5:	89 04 24             	mov    %eax,(%esp)
c0024da8:	e8 72 3d 00 00       	call   c0028b1f <list_next>
c0024dad:	89 c3                	mov    %eax,%ebx
  return (list_elem != list_end (&all_blocks)
c0024daf:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024db6:	e8 b8 3d 00 00       	call   c0028b73 <list_end>
          : NULL);
c0024dbb:	39 c3                	cmp    %eax,%ebx
c0024dbd:	b8 00 00 00 00       	mov    $0x0,%eax
c0024dc2:	0f 45 c3             	cmovne %ebx,%eax
}
c0024dc5:	83 c4 18             	add    $0x18,%esp
c0024dc8:	5b                   	pop    %ebx
c0024dc9:	c3                   	ret    

c0024dca <block_get_by_name>:
{
c0024dca:	56                   	push   %esi
c0024dcb:	53                   	push   %ebx
c0024dcc:	83 ec 14             	sub    $0x14,%esp
c0024dcf:	8b 74 24 20          	mov    0x20(%esp),%esi
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024dd3:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024dda:	e8 02 3d 00 00       	call   c0028ae1 <list_begin>
c0024ddf:	89 c3                	mov    %eax,%ebx
c0024de1:	eb 1d                	jmp    c0024e00 <block_get_by_name+0x36>
      if (!strcmp (name, block->name))
c0024de3:	8d 43 08             	lea    0x8(%ebx),%eax
c0024de6:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024dea:	89 34 24             	mov    %esi,(%esp)
c0024ded:	e8 e5 2c 00 00       	call   c0027ad7 <strcmp>
c0024df2:	85 c0                	test   %eax,%eax
c0024df4:	74 21                	je     c0024e17 <block_get_by_name+0x4d>
       e = list_next (e))
c0024df6:	89 1c 24             	mov    %ebx,(%esp)
c0024df9:	e8 21 3d 00 00       	call   c0028b1f <list_next>
c0024dfe:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024e00:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024e07:	e8 67 3d 00 00       	call   c0028b73 <list_end>
c0024e0c:	39 d8                	cmp    %ebx,%eax
c0024e0e:	75 d3                	jne    c0024de3 <block_get_by_name+0x19>
  return NULL;
c0024e10:	b8 00 00 00 00       	mov    $0x0,%eax
c0024e15:	eb 02                	jmp    c0024e19 <block_get_by_name+0x4f>
c0024e17:	89 d8                	mov    %ebx,%eax
}
c0024e19:	83 c4 14             	add    $0x14,%esp
c0024e1c:	5b                   	pop    %ebx
c0024e1d:	5e                   	pop    %esi
c0024e1e:	c3                   	ret    

c0024e1f <block_read>:
{
c0024e1f:	56                   	push   %esi
c0024e20:	53                   	push   %ebx
c0024e21:	83 ec 14             	sub    $0x14,%esp
c0024e24:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0024e28:	8b 74 24 24          	mov    0x24(%esp),%esi
  check_sector (block, sector);
c0024e2c:	89 f2                	mov    %esi,%edx
c0024e2e:	89 d8                	mov    %ebx,%eax
c0024e30:	e8 2f fe ff ff       	call   c0024c64 <check_sector>
  block->ops->read (block->aux, sector, buffer);
c0024e35:	8b 43 20             	mov    0x20(%ebx),%eax
c0024e38:	8b 54 24 28          	mov    0x28(%esp),%edx
c0024e3c:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024e40:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024e44:	8b 53 24             	mov    0x24(%ebx),%edx
c0024e47:	89 14 24             	mov    %edx,(%esp)
c0024e4a:	ff 10                	call   *(%eax)
  block->read_cnt++;
c0024e4c:	83 43 28 01          	addl   $0x1,0x28(%ebx)
c0024e50:	83 53 2c 00          	adcl   $0x0,0x2c(%ebx)
}
c0024e54:	83 c4 14             	add    $0x14,%esp
c0024e57:	5b                   	pop    %ebx
c0024e58:	5e                   	pop    %esi
c0024e59:	c3                   	ret    

c0024e5a <block_write>:
{
c0024e5a:	56                   	push   %esi
c0024e5b:	53                   	push   %ebx
c0024e5c:	83 ec 24             	sub    $0x24,%esp
c0024e5f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0024e63:	8b 74 24 34          	mov    0x34(%esp),%esi
  check_sector (block, sector);
c0024e67:	89 f2                	mov    %esi,%edx
c0024e69:	89 d8                	mov    %ebx,%eax
c0024e6b:	e8 f4 fd ff ff       	call   c0024c64 <check_sector>
  ASSERT (block->type != BLOCK_FOREIGN);
c0024e70:	83 7b 18 05          	cmpl   $0x5,0x18(%ebx)
c0024e74:	75 2c                	jne    c0024ea2 <block_write+0x48>
c0024e76:	c7 44 24 10 57 ef 02 	movl   $0xc002ef57,0x10(%esp)
c0024e7d:	c0 
c0024e7e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024e85:	c0 
c0024e86:	c7 44 24 08 fb d4 02 	movl   $0xc002d4fb,0x8(%esp)
c0024e8d:	c0 
c0024e8e:	c7 44 24 04 89 00 00 	movl   $0x89,0x4(%esp)
c0024e95:	00 
c0024e96:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024e9d:	e8 21 3b 00 00       	call   c00289c3 <debug_panic>
  block->ops->write (block->aux, sector, buffer);
c0024ea2:	8b 43 20             	mov    0x20(%ebx),%eax
c0024ea5:	8b 54 24 38          	mov    0x38(%esp),%edx
c0024ea9:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024ead:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024eb1:	8b 53 24             	mov    0x24(%ebx),%edx
c0024eb4:	89 14 24             	mov    %edx,(%esp)
c0024eb7:	ff 50 04             	call   *0x4(%eax)
  block->write_cnt++;
c0024eba:	83 43 30 01          	addl   $0x1,0x30(%ebx)
c0024ebe:	83 53 34 00          	adcl   $0x0,0x34(%ebx)
}
c0024ec2:	83 c4 24             	add    $0x24,%esp
c0024ec5:	5b                   	pop    %ebx
c0024ec6:	5e                   	pop    %esi
c0024ec7:	c3                   	ret    

c0024ec8 <block_size>:
  return block->size;
c0024ec8:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024ecc:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0024ecf:	c3                   	ret    

c0024ed0 <block_name>:
  return block->name;
c0024ed0:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024ed4:	83 c0 08             	add    $0x8,%eax
}
c0024ed7:	c3                   	ret    

c0024ed8 <block_type>:
  return block->type;
c0024ed8:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024edc:	8b 40 18             	mov    0x18(%eax),%eax
}
c0024edf:	c3                   	ret    

c0024ee0 <block_print_stats>:
{
c0024ee0:	56                   	push   %esi
c0024ee1:	53                   	push   %ebx
c0024ee2:	83 ec 24             	sub    $0x24,%esp
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024ee5:	be 00 00 00 00       	mov    $0x0,%esi
      struct block *block = block_by_role[i];
c0024eea:	8b 1c b5 18 78 03 c0 	mov    -0x3ffc87e8(,%esi,4),%ebx
      if (block != NULL)
c0024ef1:	85 db                	test   %ebx,%ebx
c0024ef3:	74 3e                	je     c0024f33 <block_print_stats+0x53>
          printf ("%s (%s): %llu reads, %llu writes\n",
c0024ef5:	8b 43 18             	mov    0x18(%ebx),%eax
c0024ef8:	89 04 24             	mov    %eax,(%esp)
c0024efb:	e8 a3 fd ff ff       	call   c0024ca3 <block_type_name>
c0024f00:	8b 53 30             	mov    0x30(%ebx),%edx
c0024f03:	8b 4b 34             	mov    0x34(%ebx),%ecx
c0024f06:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024f0a:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024f0e:	8b 53 28             	mov    0x28(%ebx),%edx
c0024f11:	8b 4b 2c             	mov    0x2c(%ebx),%ecx
c0024f14:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0024f18:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0024f1c:	89 44 24 08          	mov    %eax,0x8(%esp)
c0024f20:	83 c3 08             	add    $0x8,%ebx
c0024f23:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024f27:	c7 04 24 c0 ee 02 c0 	movl   $0xc002eec0,(%esp)
c0024f2e:	e8 3b 1c 00 00       	call   c0026b6e <printf>
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024f33:	83 c6 01             	add    $0x1,%esi
c0024f36:	83 fe 04             	cmp    $0x4,%esi
c0024f39:	75 af                	jne    c0024eea <block_print_stats+0xa>
}
c0024f3b:	83 c4 24             	add    $0x24,%esp
c0024f3e:	5b                   	pop    %ebx
c0024f3f:	5e                   	pop    %esi
c0024f40:	c3                   	ret    

c0024f41 <block_register>:
{
c0024f41:	55                   	push   %ebp
c0024f42:	57                   	push   %edi
c0024f43:	56                   	push   %esi
c0024f44:	53                   	push   %ebx
c0024f45:	83 ec 1c             	sub    $0x1c,%esp
c0024f48:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0024f4c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
  struct block *block = malloc (sizeof *block);
c0024f50:	c7 04 24 38 00 00 00 	movl   $0x38,(%esp)
c0024f57:	e8 18 eb ff ff       	call   c0023a74 <malloc>
c0024f5c:	89 c6                	mov    %eax,%esi
  if (block == NULL)
c0024f5e:	85 c0                	test   %eax,%eax
c0024f60:	75 24                	jne    c0024f86 <block_register+0x45>
    PANIC ("Failed to allocate memory for block device descriptor");
c0024f62:	c7 44 24 0c e4 ee 02 	movl   $0xc002eee4,0xc(%esp)
c0024f69:	c0 
c0024f6a:	c7 44 24 08 ec d4 02 	movl   $0xc002d4ec,0x8(%esp)
c0024f71:	c0 
c0024f72:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0024f79:	00 
c0024f7a:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024f81:	e8 3d 3a 00 00       	call   c00289c3 <debug_panic>
  list_push_back (&all_blocks, &block->list_elem);
c0024f86:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f8a:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024f91:	e8 7b 40 00 00       	call   c0029011 <list_push_back>
  strlcpy (block->name, name, sizeof block->name);
c0024f96:	8d 6e 08             	lea    0x8(%esi),%ebp
c0024f99:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c0024fa0:	00 
c0024fa1:	8b 44 24 30          	mov    0x30(%esp),%eax
c0024fa5:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024fa9:	89 2c 24             	mov    %ebp,(%esp)
c0024fac:	e8 25 30 00 00       	call   c0027fd6 <strlcpy>
  block->type = type;
c0024fb1:	8b 44 24 34          	mov    0x34(%esp),%eax
c0024fb5:	89 46 18             	mov    %eax,0x18(%esi)
  block->size = size;
c0024fb8:	89 5e 1c             	mov    %ebx,0x1c(%esi)
  block->ops = ops;
c0024fbb:	8b 44 24 40          	mov    0x40(%esp),%eax
c0024fbf:	89 46 20             	mov    %eax,0x20(%esi)
  block->aux = aux;
c0024fc2:	8b 44 24 44          	mov    0x44(%esp),%eax
c0024fc6:	89 46 24             	mov    %eax,0x24(%esi)
  block->read_cnt = 0;
c0024fc9:	c7 46 28 00 00 00 00 	movl   $0x0,0x28(%esi)
c0024fd0:	c7 46 2c 00 00 00 00 	movl   $0x0,0x2c(%esi)
  block->write_cnt = 0;
c0024fd7:	c7 46 30 00 00 00 00 	movl   $0x0,0x30(%esi)
c0024fde:	c7 46 34 00 00 00 00 	movl   $0x0,0x34(%esi)
  printf ("%s: %'"PRDSNu" sectors (", block->name, block->size);
c0024fe5:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0024fe9:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0024fed:	c7 04 24 74 ef 02 c0 	movl   $0xc002ef74,(%esp)
c0024ff4:	e8 75 1b 00 00       	call   c0026b6e <printf>
  print_human_readable_size ((uint64_t) block->size * BLOCK_SECTOR_SIZE);
c0024ff9:	8b 4e 1c             	mov    0x1c(%esi),%ecx
c0024ffc:	bb 00 00 00 00       	mov    $0x0,%ebx
c0025001:	0f a4 cb 09          	shld   $0x9,%ecx,%ebx
c0025005:	c1 e1 09             	shl    $0x9,%ecx
c0025008:	89 0c 24             	mov    %ecx,(%esp)
c002500b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002500f:	e8 25 24 00 00       	call   c0027439 <print_human_readable_size>
  printf (")");
c0025014:	c7 04 24 29 00 00 00 	movl   $0x29,(%esp)
c002501b:	e8 3c 57 00 00       	call   c002a75c <putchar>
  if (extra_info != NULL)
c0025020:	85 ff                	test   %edi,%edi
c0025022:	74 10                	je     c0025034 <block_register+0xf3>
    printf (", %s", extra_info);
c0025024:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0025028:	c7 04 24 86 ef 02 c0 	movl   $0xc002ef86,(%esp)
c002502f:	e8 3a 1b 00 00       	call   c0026b6e <printf>
  printf ("\n");
c0025034:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002503b:	e8 1c 57 00 00       	call   c002a75c <putchar>
}
c0025040:	89 f0                	mov    %esi,%eax
c0025042:	83 c4 1c             	add    $0x1c,%esp
c0025045:	5b                   	pop    %ebx
c0025046:	5e                   	pop    %esi
c0025047:	5f                   	pop    %edi
c0025048:	5d                   	pop    %ebp
c0025049:	c3                   	ret    

c002504a <partition_read>:

/* Reads sector SECTOR from partition P into BUFFER, which must
   have room for BLOCK_SECTOR_SIZE bytes. */
static void
partition_read (void *p_, block_sector_t sector, void *buffer)
{
c002504a:	83 ec 1c             	sub    $0x1c,%esp
c002504d:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_read (p->block, p->start + sector, buffer);
c0025051:	8b 54 24 28          	mov    0x28(%esp),%edx
c0025055:	89 54 24 08          	mov    %edx,0x8(%esp)
c0025059:	8b 54 24 24          	mov    0x24(%esp),%edx
c002505d:	03 50 04             	add    0x4(%eax),%edx
c0025060:	89 54 24 04          	mov    %edx,0x4(%esp)
c0025064:	8b 00                	mov    (%eax),%eax
c0025066:	89 04 24             	mov    %eax,(%esp)
c0025069:	e8 b1 fd ff ff       	call   c0024e1f <block_read>
}
c002506e:	83 c4 1c             	add    $0x1c,%esp
c0025071:	c3                   	ret    

c0025072 <read_partition_table>:
{
c0025072:	55                   	push   %ebp
c0025073:	57                   	push   %edi
c0025074:	56                   	push   %esi
c0025075:	53                   	push   %ebx
c0025076:	81 ec dc 00 00 00    	sub    $0xdc,%esp
c002507c:	89 c5                	mov    %eax,%ebp
c002507e:	89 d6                	mov    %edx,%esi
c0025080:	89 4c 24 20          	mov    %ecx,0x20(%esp)
  if (sector >= block_size (block))
c0025084:	89 04 24             	mov    %eax,(%esp)
c0025087:	e8 3c fe ff ff       	call   c0024ec8 <block_size>
c002508c:	39 f0                	cmp    %esi,%eax
c002508e:	77 21                	ja     c00250b1 <read_partition_table+0x3f>
      printf ("%s: Partition table at sector %"PRDSNu" past end of device.\n",
c0025090:	89 2c 24             	mov    %ebp,(%esp)
c0025093:	e8 38 fe ff ff       	call   c0024ed0 <block_name>
c0025098:	89 74 24 08          	mov    %esi,0x8(%esp)
c002509c:	89 44 24 04          	mov    %eax,0x4(%esp)
c00250a0:	c7 04 24 38 f4 02 c0 	movl   $0xc002f438,(%esp)
c00250a7:	e8 c2 1a 00 00       	call   c0026b6e <printf>
      return;
c00250ac:	e9 3b 03 00 00       	jmp    c00253ec <read_partition_table+0x37a>
  pt = malloc (sizeof *pt);
c00250b1:	c7 04 24 00 02 00 00 	movl   $0x200,(%esp)
c00250b8:	e8 b7 e9 ff ff       	call   c0023a74 <malloc>
c00250bd:	89 c7                	mov    %eax,%edi
  if (pt == NULL)
c00250bf:	85 c0                	test   %eax,%eax
c00250c1:	75 24                	jne    c00250e7 <read_partition_table+0x75>
    PANIC ("Failed to allocate memory for partition table.");
c00250c3:	c7 44 24 0c 70 f4 02 	movl   $0xc002f470,0xc(%esp)
c00250ca:	c0 
c00250cb:	c7 44 24 08 70 d9 02 	movl   $0xc002d970,0x8(%esp)
c00250d2:	c0 
c00250d3:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c00250da:	00 
c00250db:	c7 04 24 a7 ef 02 c0 	movl   $0xc002efa7,(%esp)
c00250e2:	e8 dc 38 00 00       	call   c00289c3 <debug_panic>
  block_read (block, 0, pt);
c00250e7:	89 44 24 08          	mov    %eax,0x8(%esp)
c00250eb:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00250f2:	00 
c00250f3:	89 2c 24             	mov    %ebp,(%esp)
c00250f6:	e8 24 fd ff ff       	call   c0024e1f <block_read>
  if (pt->signature != 0xaa55)
c00250fb:	66 81 bf fe 01 00 00 	cmpw   $0xaa55,0x1fe(%edi)
c0025102:	55 aa 
c0025104:	74 4a                	je     c0025150 <read_partition_table+0xde>
      if (primary_extended_sector == 0)
c0025106:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c002510b:	75 1a                	jne    c0025127 <read_partition_table+0xb5>
        printf ("%s: Invalid partition table signature\n", block_name (block));
c002510d:	89 2c 24             	mov    %ebp,(%esp)
c0025110:	e8 bb fd ff ff       	call   c0024ed0 <block_name>
c0025115:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025119:	c7 04 24 a0 f4 02 c0 	movl   $0xc002f4a0,(%esp)
c0025120:	e8 49 1a 00 00       	call   c0026b6e <printf>
c0025125:	eb 1c                	jmp    c0025143 <read_partition_table+0xd1>
        printf ("%s: Invalid extended partition table in sector %"PRDSNu"\n",
c0025127:	89 2c 24             	mov    %ebp,(%esp)
c002512a:	e8 a1 fd ff ff       	call   c0024ed0 <block_name>
c002512f:	89 74 24 08          	mov    %esi,0x8(%esp)
c0025133:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025137:	c7 04 24 c8 f4 02 c0 	movl   $0xc002f4c8,(%esp)
c002513e:	e8 2b 1a 00 00       	call   c0026b6e <printf>
      free (pt);
c0025143:	89 3c 24             	mov    %edi,(%esp)
c0025146:	e8 b0 ea ff ff       	call   c0023bfb <free>
      return;
c002514b:	e9 9c 02 00 00       	jmp    c00253ec <read_partition_table+0x37a>
c0025150:	89 fb                	mov    %edi,%ebx
  if (pt->signature != 0xaa55)
c0025152:	b8 04 00 00 00       	mov    $0x4,%eax
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025157:	89 7c 24 28          	mov    %edi,0x28(%esp)
c002515b:	89 74 24 24          	mov    %esi,0x24(%esp)
c002515f:	89 c6                	mov    %eax,%esi
c0025161:	89 df                	mov    %ebx,%edi
      if (e->size == 0 || e->type == 0)
c0025163:	83 bb ca 01 00 00 00 	cmpl   $0x0,0x1ca(%ebx)
c002516a:	0f 84 64 02 00 00    	je     c00253d4 <read_partition_table+0x362>
c0025170:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c0025177:	84 c0                	test   %al,%al
c0025179:	0f 84 55 02 00 00    	je     c00253d4 <read_partition_table+0x362>
               || e->type == 0x0f    /* Windows 98 extended partition. */
c002517f:	89 c2                	mov    %eax,%edx
c0025181:	83 e2 7f             	and    $0x7f,%edx
      else if (e->type == 0x05       /* Extended partition. */
c0025184:	80 fa 05             	cmp    $0x5,%dl
c0025187:	74 08                	je     c0025191 <read_partition_table+0x11f>
c0025189:	3c 0f                	cmp    $0xf,%al
c002518b:	74 04                	je     c0025191 <read_partition_table+0x11f>
               || e->type == 0xc5)   /* DR-DOS extended partition. */
c002518d:	3c c5                	cmp    $0xc5,%al
c002518f:	75 67                	jne    c00251f8 <read_partition_table+0x186>
          printf ("%s: Extended partition in sector %"PRDSNu"\n",
c0025191:	89 2c 24             	mov    %ebp,(%esp)
c0025194:	e8 37 fd ff ff       	call   c0024ed0 <block_name>
c0025199:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c002519d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c00251a1:	89 44 24 04          	mov    %eax,0x4(%esp)
c00251a5:	c7 04 24 fc f4 02 c0 	movl   $0xc002f4fc,(%esp)
c00251ac:	e8 bd 19 00 00       	call   c0026b6e <printf>
          if (sector == 0)
c00251b1:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c00251b6:	75 1e                	jne    c00251d6 <read_partition_table+0x164>
            read_partition_table (block, e->offset, e->offset, part_nr);
c00251b8:	8b 97 c6 01 00 00    	mov    0x1c6(%edi),%edx
c00251be:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251c5:	89 04 24             	mov    %eax,(%esp)
c00251c8:	89 d1                	mov    %edx,%ecx
c00251ca:	89 e8                	mov    %ebp,%eax
c00251cc:	e8 a1 fe ff ff       	call   c0025072 <read_partition_table>
c00251d1:	e9 fe 01 00 00       	jmp    c00253d4 <read_partition_table+0x362>
            read_partition_table (block, e->offset + primary_extended_sector,
c00251d6:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c00251da:	89 ca                	mov    %ecx,%edx
c00251dc:	03 97 c6 01 00 00    	add    0x1c6(%edi),%edx
c00251e2:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251e9:	89 04 24             	mov    %eax,(%esp)
c00251ec:	89 e8                	mov    %ebp,%eax
c00251ee:	e8 7f fe ff ff       	call   c0025072 <read_partition_table>
c00251f3:	e9 dc 01 00 00       	jmp    c00253d4 <read_partition_table+0x362>
          ++*part_nr;
c00251f8:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251ff:	8b 00                	mov    (%eax),%eax
c0025201:	83 c0 01             	add    $0x1,%eax
c0025204:	89 44 24 34          	mov    %eax,0x34(%esp)
c0025208:	8b 8c 24 f0 00 00 00 	mov    0xf0(%esp),%ecx
c002520f:	89 01                	mov    %eax,(%ecx)
          found_partition (block, e->type, e->offset + sector,
c0025211:	8b 83 ca 01 00 00    	mov    0x1ca(%ebx),%eax
c0025217:	89 44 24 30          	mov    %eax,0x30(%esp)
c002521b:	8b 44 24 24          	mov    0x24(%esp),%eax
c002521f:	03 83 c6 01 00 00    	add    0x1c6(%ebx),%eax
c0025225:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c0025229:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c0025230:	88 44 24 3b          	mov    %al,0x3b(%esp)
  if (start >= block_size (block))
c0025234:	89 2c 24             	mov    %ebp,(%esp)
c0025237:	e8 8c fc ff ff       	call   c0024ec8 <block_size>
c002523c:	39 44 24 2c          	cmp    %eax,0x2c(%esp)
c0025240:	72 2d                	jb     c002526f <read_partition_table+0x1fd>
    printf ("%s%d: Partition starts past end of device (sector %"PRDSNu")\n",
c0025242:	89 2c 24             	mov    %ebp,(%esp)
c0025245:	e8 86 fc ff ff       	call   c0024ed0 <block_name>
c002524a:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002524e:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0025252:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025256:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002525a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002525e:	c7 04 24 24 f5 02 c0 	movl   $0xc002f524,(%esp)
c0025265:	e8 04 19 00 00       	call   c0026b6e <printf>
c002526a:	e9 65 01 00 00       	jmp    c00253d4 <read_partition_table+0x362>
  else if (start + size < start || start + size > block_size (block))
c002526f:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
c0025273:	03 7c 24 30          	add    0x30(%esp),%edi
c0025277:	72 0c                	jb     c0025285 <read_partition_table+0x213>
c0025279:	89 2c 24             	mov    %ebp,(%esp)
c002527c:	e8 47 fc ff ff       	call   c0024ec8 <block_size>
c0025281:	39 c7                	cmp    %eax,%edi
c0025283:	76 3d                	jbe    c00252c2 <read_partition_table+0x250>
    printf ("%s%d: Partition end (%"PRDSNu") past end of device (%"PRDSNu")\n",
c0025285:	89 2c 24             	mov    %ebp,(%esp)
c0025288:	e8 3b fc ff ff       	call   c0024ec8 <block_size>
c002528d:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c0025291:	89 2c 24             	mov    %ebp,(%esp)
c0025294:	e8 37 fc ff ff       	call   c0024ed0 <block_name>
c0025299:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002529d:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c00252a1:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00252a5:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c00252a9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c00252ad:	89 44 24 04          	mov    %eax,0x4(%esp)
c00252b1:	c7 04 24 5c f5 02 c0 	movl   $0xc002f55c,(%esp)
c00252b8:	e8 b1 18 00 00       	call   c0026b6e <printf>
c00252bd:	e9 12 01 00 00       	jmp    c00253d4 <read_partition_table+0x362>
      enum block_type type = (part_type == 0x20 ? BLOCK_KERNEL
c00252c2:	c7 44 24 3c 00 00 00 	movl   $0x0,0x3c(%esp)
c00252c9:	00 
c00252ca:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
c00252cf:	3c 20                	cmp    $0x20,%al
c00252d1:	74 28                	je     c00252fb <read_partition_table+0x289>
c00252d3:	c7 44 24 3c 01 00 00 	movl   $0x1,0x3c(%esp)
c00252da:	00 
c00252db:	3c 21                	cmp    $0x21,%al
c00252dd:	74 1c                	je     c00252fb <read_partition_table+0x289>
c00252df:	c7 44 24 3c 02 00 00 	movl   $0x2,0x3c(%esp)
c00252e6:	00 
c00252e7:	3c 22                	cmp    $0x22,%al
c00252e9:	74 10                	je     c00252fb <read_partition_table+0x289>
c00252eb:	3c 23                	cmp    $0x23,%al
c00252ed:	0f 95 c0             	setne  %al
c00252f0:	0f b6 c0             	movzbl %al,%eax
c00252f3:	8d 44 00 03          	lea    0x3(%eax,%eax,1),%eax
c00252f7:	89 44 24 3c          	mov    %eax,0x3c(%esp)
      p = malloc (sizeof *p);
c00252fb:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c0025302:	e8 6d e7 ff ff       	call   c0023a74 <malloc>
c0025307:	89 c7                	mov    %eax,%edi
      if (p == NULL)
c0025309:	85 c0                	test   %eax,%eax
c002530b:	75 24                	jne    c0025331 <read_partition_table+0x2bf>
        PANIC ("Failed to allocate memory for partition descriptor");
c002530d:	c7 44 24 0c 90 f5 02 	movl   $0xc002f590,0xc(%esp)
c0025314:	c0 
c0025315:	c7 44 24 08 60 d9 02 	movl   $0xc002d960,0x8(%esp)
c002531c:	c0 
c002531d:	c7 44 24 04 b1 00 00 	movl   $0xb1,0x4(%esp)
c0025324:	00 
c0025325:	c7 04 24 a7 ef 02 c0 	movl   $0xc002efa7,(%esp)
c002532c:	e8 92 36 00 00       	call   c00289c3 <debug_panic>
      p->block = block;
c0025331:	89 28                	mov    %ebp,(%eax)
      p->start = start;
c0025333:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c0025337:	89 47 04             	mov    %eax,0x4(%edi)
      snprintf (name, sizeof name, "%s%d", block_name (block), part_nr);
c002533a:	89 2c 24             	mov    %ebp,(%esp)
c002533d:	e8 8e fb ff ff       	call   c0024ed0 <block_name>
c0025342:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025346:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c002534a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002534e:	c7 44 24 08 c1 ef 02 	movl   $0xc002efc1,0x8(%esp)
c0025355:	c0 
c0025356:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002535d:	00 
c002535e:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025362:	89 04 24             	mov    %eax,(%esp)
c0025365:	e8 05 1f 00 00       	call   c002726f <snprintf>
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c002536a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c002536f:	8b 14 85 60 d5 02 c0 	mov    -0x3ffd2aa0(,%eax,4),%edx
c0025376:	85 d2                	test   %edx,%edx
c0025378:	b9 9f ef 02 c0       	mov    $0xc002ef9f,%ecx
c002537d:	0f 44 d1             	cmove  %ecx,%edx
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025380:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025384:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0025388:	c7 44 24 08 c6 ef 02 	movl   $0xc002efc6,0x8(%esp)
c002538f:	c0 
c0025390:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025397:	00 
c0025398:	8d 44 24 50          	lea    0x50(%esp),%eax
c002539c:	89 04 24             	mov    %eax,(%esp)
c002539f:	e8 cb 1e 00 00       	call   c002726f <snprintf>
      block_register (name, type, extra_info, size, &partition_operations, p);
c00253a4:	89 7c 24 14          	mov    %edi,0x14(%esp)
c00253a8:	c7 44 24 10 6c 5a 03 	movl   $0xc0035a6c,0x10(%esp)
c00253af:	c0 
c00253b0:	8b 44 24 30          	mov    0x30(%esp),%eax
c00253b4:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00253b8:	8d 44 24 50          	lea    0x50(%esp),%eax
c00253bc:	89 44 24 08          	mov    %eax,0x8(%esp)
c00253c0:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c00253c4:	89 44 24 04          	mov    %eax,0x4(%esp)
c00253c8:	8d 44 24 40          	lea    0x40(%esp),%eax
c00253cc:	89 04 24             	mov    %eax,(%esp)
c00253cf:	e8 6d fb ff ff       	call   c0024f41 <block_register>
c00253d4:	83 c3 10             	add    $0x10,%ebx
  for (i = 0; i < sizeof pt->partitions / sizeof *pt->partitions; i++)
c00253d7:	83 ee 01             	sub    $0x1,%esi
c00253da:	0f 85 81 fd ff ff    	jne    c0025161 <read_partition_table+0xef>
c00253e0:	8b 7c 24 28          	mov    0x28(%esp),%edi
  free (pt);
c00253e4:	89 3c 24             	mov    %edi,(%esp)
c00253e7:	e8 0f e8 ff ff       	call   c0023bfb <free>
}
c00253ec:	81 c4 dc 00 00 00    	add    $0xdc,%esp
c00253f2:	5b                   	pop    %ebx
c00253f3:	5e                   	pop    %esi
c00253f4:	5f                   	pop    %edi
c00253f5:	5d                   	pop    %ebp
c00253f6:	c3                   	ret    

c00253f7 <partition_write>:
/* Write sector SECTOR to partition P from BUFFER, which must
   contain BLOCK_SECTOR_SIZE bytes.  Returns after the block has
   acknowledged receiving the data. */
static void
partition_write (void *p_, block_sector_t sector, const void *buffer)
{
c00253f7:	83 ec 1c             	sub    $0x1c,%esp
c00253fa:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_write (p->block, p->start + sector, buffer);
c00253fe:	8b 54 24 28          	mov    0x28(%esp),%edx
c0025402:	89 54 24 08          	mov    %edx,0x8(%esp)
c0025406:	8b 54 24 24          	mov    0x24(%esp),%edx
c002540a:	03 50 04             	add    0x4(%eax),%edx
c002540d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0025411:	8b 00                	mov    (%eax),%eax
c0025413:	89 04 24             	mov    %eax,(%esp)
c0025416:	e8 3f fa ff ff       	call   c0024e5a <block_write>
}
c002541b:	83 c4 1c             	add    $0x1c,%esp
c002541e:	c3                   	ret    

c002541f <partition_scan>:
{
c002541f:	53                   	push   %ebx
c0025420:	83 ec 28             	sub    $0x28,%esp
c0025423:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  int part_nr = 0;
c0025427:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002542e:	00 
  read_partition_table (block, 0, 0, &part_nr);
c002542f:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c0025433:	89 04 24             	mov    %eax,(%esp)
c0025436:	b9 00 00 00 00       	mov    $0x0,%ecx
c002543b:	ba 00 00 00 00       	mov    $0x0,%edx
c0025440:	89 d8                	mov    %ebx,%eax
c0025442:	e8 2b fc ff ff       	call   c0025072 <read_partition_table>
  if (part_nr == 0)
c0025447:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c002544c:	75 18                	jne    c0025466 <partition_scan+0x47>
    printf ("%s: Device contains no partitions\n", block_name (block));
c002544e:	89 1c 24             	mov    %ebx,(%esp)
c0025451:	e8 7a fa ff ff       	call   c0024ed0 <block_name>
c0025456:	89 44 24 04          	mov    %eax,0x4(%esp)
c002545a:	c7 04 24 c4 f5 02 c0 	movl   $0xc002f5c4,(%esp)
c0025461:	e8 08 17 00 00       	call   c0026b6e <printf>
}
c0025466:	83 c4 28             	add    $0x28,%esp
c0025469:	5b                   	pop    %ebx
c002546a:	c3                   	ret    
c002546b:	90                   	nop
c002546c:	90                   	nop
c002546d:	90                   	nop
c002546e:	90                   	nop
c002546f:	90                   	nop

c0025470 <descramble_ata_string>:
/* Translates STRING, which consists of SIZE bytes in a funky
   format, into a null-terminated string in-place.  Drops
   trailing whitespace and null bytes.  Returns STRING.  */
static char *
descramble_ata_string (char *string, int size) 
{
c0025470:	57                   	push   %edi
c0025471:	56                   	push   %esi
c0025472:	53                   	push   %ebx
c0025473:	89 d7                	mov    %edx,%edi
  int i;

  /* Swap all pairs of bytes. */
  for (i = 0; i + 1 < size; i += 2)
c0025475:	83 fa 01             	cmp    $0x1,%edx
c0025478:	7e 1f                	jle    c0025499 <descramble_ata_string+0x29>
c002547a:	89 c1                	mov    %eax,%ecx
c002547c:	8d 5a fe             	lea    -0x2(%edx),%ebx
c002547f:	83 e3 fe             	and    $0xfffffffe,%ebx
c0025482:	8d 74 18 02          	lea    0x2(%eax,%ebx,1),%esi
    {
      char tmp = string[i];
c0025486:	0f b6 19             	movzbl (%ecx),%ebx
      string[i] = string[i + 1];
c0025489:	0f b6 51 01          	movzbl 0x1(%ecx),%edx
c002548d:	88 11                	mov    %dl,(%ecx)
      string[i + 1] = tmp;
c002548f:	88 59 01             	mov    %bl,0x1(%ecx)
c0025492:	83 c1 02             	add    $0x2,%ecx
  for (i = 0; i + 1 < size; i += 2)
c0025495:	39 f1                	cmp    %esi,%ecx
c0025497:	75 ed                	jne    c0025486 <descramble_ata_string+0x16>
    }

  /* Find the last non-white, non-null character. */
  for (size--; size > 0; size--)
c0025499:	8d 57 ff             	lea    -0x1(%edi),%edx
c002549c:	85 d2                	test   %edx,%edx
c002549e:	7e 24                	jle    c00254c4 <descramble_ata_string+0x54>
    {
      int c = string[size - 1];
c00254a0:	0f b6 4c 10 ff       	movzbl -0x1(%eax,%edx,1),%ecx
      if (c != '\0' && !isspace (c))
c00254a5:	f6 c1 df             	test   $0xdf,%cl
c00254a8:	74 15                	je     c00254bf <descramble_ata_string+0x4f>
  return (c == ' ' || c == '\f' || c == '\n'
c00254aa:	8d 59 f4             	lea    -0xc(%ecx),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c00254ad:	80 fb 01             	cmp    $0x1,%bl
c00254b0:	76 0d                	jbe    c00254bf <descramble_ata_string+0x4f>
c00254b2:	80 f9 0a             	cmp    $0xa,%cl
c00254b5:	74 08                	je     c00254bf <descramble_ata_string+0x4f>
c00254b7:	83 e1 fd             	and    $0xfffffffd,%ecx
c00254ba:	80 f9 09             	cmp    $0x9,%cl
c00254bd:	75 05                	jne    c00254c4 <descramble_ata_string+0x54>
  for (size--; size > 0; size--)
c00254bf:	83 ea 01             	sub    $0x1,%edx
c00254c2:	75 dc                	jne    c00254a0 <descramble_ata_string+0x30>
        break; 
    }
  string[size] = '\0';
c00254c4:	c6 04 10 00          	movb   $0x0,(%eax,%edx,1)

  return string;
}
c00254c8:	5b                   	pop    %ebx
c00254c9:	5e                   	pop    %esi
c00254ca:	5f                   	pop    %edi
c00254cb:	c3                   	ret    

c00254cc <interrupt_handler>:
}

/* ATA interrupt handler. */
static void
interrupt_handler (struct intr_frame *f) 
{
c00254cc:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c;

  for (c = channels; c < channels + CHANNEL_CNT; c++)
    if (f->vec_no == c->irq)
c00254cf:	8b 44 24 20          	mov    0x20(%esp),%eax
c00254d3:	8b 40 30             	mov    0x30(%eax),%eax
c00254d6:	0f b6 15 4a 78 03 c0 	movzbl 0xc003784a,%edx
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254dd:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
    if (f->vec_no == c->irq)
c00254e2:	39 d0                	cmp    %edx,%eax
c00254e4:	75 3e                	jne    c0025524 <interrupt_handler+0x58>
c00254e6:	eb 0a                	jmp    c00254f2 <interrupt_handler+0x26>
c00254e8:	0f b6 51 0a          	movzbl 0xa(%ecx),%edx
c00254ec:	39 c2                	cmp    %eax,%edx
c00254ee:	75 34                	jne    c0025524 <interrupt_handler+0x58>
c00254f0:	eb 05                	jmp    c00254f7 <interrupt_handler+0x2b>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254f2:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
      {
        if (c->expecting_interrupt) 
c00254f7:	80 79 30 00          	cmpb   $0x0,0x30(%ecx)
c00254fb:	74 15                	je     c0025512 <interrupt_handler+0x46>
          {
            inb (reg_status (c));               /* Acknowledge interrupt. */
c00254fd:	0f b7 41 08          	movzwl 0x8(%ecx),%eax
c0025501:	8d 50 07             	lea    0x7(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025504:	ec                   	in     (%dx),%al
            sema_up (&c->completion_wait);      /* Wake up waiter. */
c0025505:	83 c1 34             	add    $0x34,%ecx
c0025508:	89 0c 24             	mov    %ecx,(%esp)
c002550b:	e8 87 d7 ff ff       	call   c0022c97 <sema_up>
c0025510:	eb 41                	jmp    c0025553 <interrupt_handler+0x87>
          }
        else
          printf ("%s: unexpected interrupt\n", c->name);
c0025512:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0025516:	c7 04 24 e7 f5 02 c0 	movl   $0xc002f5e7,(%esp)
c002551d:	e8 4c 16 00 00       	call   c0026b6e <printf>
c0025522:	eb 2f                	jmp    c0025553 <interrupt_handler+0x87>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c0025524:	83 c1 70             	add    $0x70,%ecx
c0025527:	81 f9 20 79 03 c0    	cmp    $0xc0037920,%ecx
c002552d:	72 b9                	jb     c00254e8 <interrupt_handler+0x1c>
        return;
      }

  NOT_REACHED ();
c002552f:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0025536:	c0 
c0025537:	c7 44 24 08 cc d9 02 	movl   $0xc002d9cc,0x8(%esp)
c002553e:	c0 
c002553f:	c7 44 24 04 0c 02 00 	movl   $0x20c,0x4(%esp)
c0025546:	00 
c0025547:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c002554e:	e8 70 34 00 00       	call   c00289c3 <debug_panic>
}
c0025553:	83 c4 1c             	add    $0x1c,%esp
c0025556:	c3                   	ret    

c0025557 <wait_until_idle>:
{
c0025557:	56                   	push   %esi
c0025558:	53                   	push   %ebx
c0025559:	83 ec 14             	sub    $0x14,%esp
c002555c:	89 c6                	mov    %eax,%esi
      if ((inb (reg_status (d->channel)) & (STA_BSY | STA_DRQ)) == 0)
c002555e:	8b 40 08             	mov    0x8(%eax),%eax
c0025561:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025565:	83 c2 07             	add    $0x7,%edx
c0025568:	ec                   	in     (%dx),%al
c0025569:	a8 88                	test   $0x88,%al
c002556b:	75 3c                	jne    c00255a9 <wait_until_idle+0x52>
c002556d:	eb 55                	jmp    c00255c4 <wait_until_idle+0x6d>
c002556f:	8b 46 08             	mov    0x8(%esi),%eax
c0025572:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025576:	83 c2 07             	add    $0x7,%edx
c0025579:	ec                   	in     (%dx),%al
c002557a:	a8 88                	test   $0x88,%al
c002557c:	74 46                	je     c00255c4 <wait_until_idle+0x6d>
      timer_usleep (10);
c002557e:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025585:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002558c:	00 
c002558d:	e8 5e ee ff ff       	call   c00243f0 <timer_usleep>
  for (i = 0; i < 1000; i++) 
c0025592:	83 eb 01             	sub    $0x1,%ebx
c0025595:	75 d8                	jne    c002556f <wait_until_idle+0x18>
  printf ("%s: idle timeout\n", d->name);
c0025597:	89 74 24 04          	mov    %esi,0x4(%esp)
c002559b:	c7 04 24 15 f6 02 c0 	movl   $0xc002f615,(%esp)
c00255a2:	e8 c7 15 00 00       	call   c0026b6e <printf>
c00255a7:	eb 1b                	jmp    c00255c4 <wait_until_idle+0x6d>
      timer_usleep (10);
c00255a9:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00255b0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00255b7:	00 
c00255b8:	e8 33 ee ff ff       	call   c00243f0 <timer_usleep>
c00255bd:	bb e7 03 00 00       	mov    $0x3e7,%ebx
c00255c2:	eb ab                	jmp    c002556f <wait_until_idle+0x18>
}
c00255c4:	83 c4 14             	add    $0x14,%esp
c00255c7:	5b                   	pop    %ebx
c00255c8:	5e                   	pop    %esi
c00255c9:	c3                   	ret    

c00255ca <select_device>:
{
c00255ca:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c = d->channel;
c00255cd:	8b 50 08             	mov    0x8(%eax),%edx
  if (d->dev_no == 1)
c00255d0:	83 78 0c 01          	cmpl   $0x1,0xc(%eax)
  uint8_t dev = DEV_MBS;
c00255d4:	b8 a0 ff ff ff       	mov    $0xffffffa0,%eax
c00255d9:	b9 b0 ff ff ff       	mov    $0xffffffb0,%ecx
c00255de:	0f 44 c1             	cmove  %ecx,%eax
  outb (reg_device (c), dev);
c00255e1:	0f b7 4a 08          	movzwl 0x8(%edx),%ecx
c00255e5:	8d 51 06             	lea    0x6(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00255e8:	ee                   	out    %al,(%dx)
  inb (reg_alt_status (c));
c00255e9:	8d 91 06 02 00 00    	lea    0x206(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00255ef:	ec                   	in     (%dx),%al
  timer_nsleep (400);
c00255f0:	c7 04 24 90 01 00 00 	movl   $0x190,(%esp)
c00255f7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00255fe:	00 
c00255ff:	e8 05 ee ff ff       	call   c0024409 <timer_nsleep>
}
c0025604:	83 c4 1c             	add    $0x1c,%esp
c0025607:	c3                   	ret    

c0025608 <check_device_type>:
{
c0025608:	55                   	push   %ebp
c0025609:	57                   	push   %edi
c002560a:	56                   	push   %esi
c002560b:	53                   	push   %ebx
c002560c:	83 ec 0c             	sub    $0xc,%esp
c002560f:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c0025611:	8b 70 08             	mov    0x8(%eax),%esi
  select_device (d);
c0025614:	e8 b1 ff ff ff       	call   c00255ca <select_device>
  error = inb (reg_error (c));
c0025619:	0f b7 4e 08          	movzwl 0x8(%esi),%ecx
c002561d:	8d 51 01             	lea    0x1(%ecx),%edx
c0025620:	ec                   	in     (%dx),%al
c0025621:	89 c6                	mov    %eax,%esi
  lbam = inb (reg_lbam (c));
c0025623:	8d 51 04             	lea    0x4(%ecx),%edx
c0025626:	ec                   	in     (%dx),%al
c0025627:	89 c7                	mov    %eax,%edi
  lbah = inb (reg_lbah (c));
c0025629:	8d 51 05             	lea    0x5(%ecx),%edx
c002562c:	ec                   	in     (%dx),%al
c002562d:	89 c5                	mov    %eax,%ebp
  status = inb (reg_status (c));
c002562f:	8d 51 07             	lea    0x7(%ecx),%edx
c0025632:	ec                   	in     (%dx),%al
  if ((error != 1 && (error != 0x81 || d->dev_no == 1))
c0025633:	89 f1                	mov    %esi,%ecx
c0025635:	80 f9 01             	cmp    $0x1,%cl
c0025638:	74 0b                	je     c0025645 <check_device_type+0x3d>
c002563a:	80 f9 81             	cmp    $0x81,%cl
c002563d:	75 0e                	jne    c002564d <check_device_type+0x45>
c002563f:	83 7b 0c 01          	cmpl   $0x1,0xc(%ebx)
c0025643:	74 08                	je     c002564d <check_device_type+0x45>
      || (status & STA_DRDY) == 0
c0025645:	a8 40                	test   $0x40,%al
c0025647:	74 04                	je     c002564d <check_device_type+0x45>
      || (status & STA_BSY) != 0)
c0025649:	84 c0                	test   %al,%al
c002564b:	79 0d                	jns    c002565a <check_device_type+0x52>
      d->is_ata = false;
c002564d:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return error != 0x81;      
c0025651:	89 f0                	mov    %esi,%eax
c0025653:	3c 81                	cmp    $0x81,%al
c0025655:	0f 95 c0             	setne  %al
c0025658:	eb 2b                	jmp    c0025685 <check_device_type+0x7d>
      d->is_ata = (lbam == 0 && lbah == 0) || (lbam == 0x3c && lbah == 0xc3);
c002565a:	b8 01 00 00 00       	mov    $0x1,%eax
c002565f:	89 ea                	mov    %ebp,%edx
c0025661:	89 f9                	mov    %edi,%ecx
c0025663:	08 ca                	or     %cl,%dl
c0025665:	74 12                	je     c0025679 <check_device_type+0x71>
c0025667:	89 e8                	mov    %ebp,%eax
c0025669:	3c c3                	cmp    $0xc3,%al
c002566b:	0f 94 c0             	sete   %al
c002566e:	80 f9 3c             	cmp    $0x3c,%cl
c0025671:	0f 94 c2             	sete   %dl
c0025674:	0f b6 d2             	movzbl %dl,%edx
c0025677:	21 d0                	and    %edx,%eax
c0025679:	88 43 10             	mov    %al,0x10(%ebx)
c002567c:	80 63 10 01          	andb   $0x1,0x10(%ebx)
      return true; 
c0025680:	b8 01 00 00 00       	mov    $0x1,%eax
}
c0025685:	83 c4 0c             	add    $0xc,%esp
c0025688:	5b                   	pop    %ebx
c0025689:	5e                   	pop    %esi
c002568a:	5f                   	pop    %edi
c002568b:	5d                   	pop    %ebp
c002568c:	c3                   	ret    

c002568d <select_sector>:
{
c002568d:	57                   	push   %edi
c002568e:	56                   	push   %esi
c002568f:	53                   	push   %ebx
c0025690:	83 ec 20             	sub    $0x20,%esp
c0025693:	89 c6                	mov    %eax,%esi
c0025695:	89 d3                	mov    %edx,%ebx
  struct channel *c = d->channel;
c0025697:	8b 78 08             	mov    0x8(%eax),%edi
  ASSERT (sec_no < (1UL << 28));
c002569a:	81 fa ff ff ff 0f    	cmp    $0xfffffff,%edx
c00256a0:	76 2c                	jbe    c00256ce <select_sector+0x41>
c00256a2:	c7 44 24 10 27 f6 02 	movl   $0xc002f627,0x10(%esp)
c00256a9:	c0 
c00256aa:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00256b1:	c0 
c00256b2:	c7 44 24 08 a0 d9 02 	movl   $0xc002d9a0,0x8(%esp)
c00256b9:	c0 
c00256ba:	c7 44 24 04 89 01 00 	movl   $0x189,0x4(%esp)
c00256c1:	00 
c00256c2:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c00256c9:	e8 f5 32 00 00       	call   c00289c3 <debug_panic>
  wait_until_idle (d);
c00256ce:	e8 84 fe ff ff       	call   c0025557 <wait_until_idle>
  select_device (d);
c00256d3:	89 f0                	mov    %esi,%eax
c00256d5:	e8 f0 fe ff ff       	call   c00255ca <select_device>
  wait_until_idle (d);
c00256da:	89 f0                	mov    %esi,%eax
c00256dc:	e8 76 fe ff ff       	call   c0025557 <wait_until_idle>
  outb (reg_nsect (c), 1);
c00256e1:	0f b7 4f 08          	movzwl 0x8(%edi),%ecx
c00256e5:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00256e8:	b8 01 00 00 00       	mov    $0x1,%eax
c00256ed:	ee                   	out    %al,(%dx)
  outb (reg_lbal (c), sec_no);
c00256ee:	8d 51 03             	lea    0x3(%ecx),%edx
c00256f1:	89 d8                	mov    %ebx,%eax
c00256f3:	ee                   	out    %al,(%dx)
c00256f4:	0f b6 c7             	movzbl %bh,%eax
  outb (reg_lbam (c), sec_no >> 8);
c00256f7:	8d 51 04             	lea    0x4(%ecx),%edx
c00256fa:	ee                   	out    %al,(%dx)
  outb (reg_lbah (c), (sec_no >> 16));
c00256fb:	89 d8                	mov    %ebx,%eax
c00256fd:	c1 e8 10             	shr    $0x10,%eax
c0025700:	8d 51 05             	lea    0x5(%ecx),%edx
c0025703:	ee                   	out    %al,(%dx)
  outb (reg_device (c),
c0025704:	83 7e 0c 01          	cmpl   $0x1,0xc(%esi)
c0025708:	b8 f0 ff ff ff       	mov    $0xfffffff0,%eax
c002570d:	ba e0 ff ff ff       	mov    $0xffffffe0,%edx
c0025712:	0f 45 c2             	cmovne %edx,%eax
        DEV_MBS | DEV_LBA | (d->dev_no == 1 ? DEV_DEV : 0) | (sec_no >> 24));
c0025715:	c1 eb 18             	shr    $0x18,%ebx
  outb (reg_device (c),
c0025718:	09 d8                	or     %ebx,%eax
c002571a:	8d 51 06             	lea    0x6(%ecx),%edx
c002571d:	ee                   	out    %al,(%dx)
}
c002571e:	83 c4 20             	add    $0x20,%esp
c0025721:	5b                   	pop    %ebx
c0025722:	5e                   	pop    %esi
c0025723:	5f                   	pop    %edi
c0025724:	c3                   	ret    

c0025725 <wait_while_busy>:
{
c0025725:	57                   	push   %edi
c0025726:	56                   	push   %esi
c0025727:	53                   	push   %ebx
c0025728:	83 ec 10             	sub    $0x10,%esp
c002572b:	89 c7                	mov    %eax,%edi
  struct channel *c = d->channel;
c002572d:	8b 70 08             	mov    0x8(%eax),%esi
  for (i = 0; i < 3000; i++)
c0025730:	bb 00 00 00 00       	mov    $0x0,%ebx
c0025735:	eb 18                	jmp    c002574f <wait_while_busy+0x2a>
      if (i == 700)
c0025737:	81 fb bc 02 00 00    	cmp    $0x2bc,%ebx
c002573d:	75 10                	jne    c002574f <wait_while_busy+0x2a>
        printf ("%s: busy, waiting...", d->name);
c002573f:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0025743:	c7 04 24 3c f6 02 c0 	movl   $0xc002f63c,(%esp)
c002574a:	e8 1f 14 00 00       	call   c0026b6e <printf>
      if (!(inb (reg_alt_status (c)) & STA_BSY)) 
c002574f:	0f b7 46 08          	movzwl 0x8(%esi),%eax
c0025753:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025759:	ec                   	in     (%dx),%al
c002575a:	84 c0                	test   %al,%al
c002575c:	78 26                	js     c0025784 <wait_while_busy+0x5f>
          if (i >= 700)
c002575e:	81 fb bb 02 00 00    	cmp    $0x2bb,%ebx
c0025764:	7e 0c                	jle    c0025772 <wait_while_busy+0x4d>
            printf ("ok\n");
c0025766:	c7 04 24 51 f6 02 c0 	movl   $0xc002f651,(%esp)
c002576d:	e8 79 4f 00 00       	call   c002a6eb <puts>
          return (inb (reg_alt_status (c)) & STA_DRQ) != 0;
c0025772:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c0025776:	66 81 c2 06 02       	add    $0x206,%dx
c002577b:	ec                   	in     (%dx),%al
c002577c:	c0 e8 03             	shr    $0x3,%al
c002577f:	83 e0 01             	and    $0x1,%eax
c0025782:	eb 30                	jmp    c00257b4 <wait_while_busy+0x8f>
      timer_msleep (10);
c0025784:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002578b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025792:	00 
c0025793:	e8 3f ec ff ff       	call   c00243d7 <timer_msleep>
  for (i = 0; i < 3000; i++)
c0025798:	83 c3 01             	add    $0x1,%ebx
c002579b:	81 fb b8 0b 00 00    	cmp    $0xbb8,%ebx
c00257a1:	75 94                	jne    c0025737 <wait_while_busy+0x12>
  printf ("failed\n");
c00257a3:	c7 04 24 6c ff 02 c0 	movl   $0xc002ff6c,(%esp)
c00257aa:	e8 3c 4f 00 00       	call   c002a6eb <puts>
  return false;
c00257af:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00257b4:	83 c4 10             	add    $0x10,%esp
c00257b7:	5b                   	pop    %ebx
c00257b8:	5e                   	pop    %esi
c00257b9:	5f                   	pop    %edi
c00257ba:	c3                   	ret    

c00257bb <issue_pio_command>:
{
c00257bb:	56                   	push   %esi
c00257bc:	53                   	push   %ebx
c00257bd:	83 ec 24             	sub    $0x24,%esp
c00257c0:	89 c3                	mov    %eax,%ebx
c00257c2:	89 d6                	mov    %edx,%esi
  ASSERT (intr_get_level () == INTR_ON);
c00257c4:	e8 fb c1 ff ff       	call   c00219c4 <intr_get_level>
c00257c9:	83 f8 01             	cmp    $0x1,%eax
c00257cc:	74 2c                	je     c00257fa <issue_pio_command+0x3f>
c00257ce:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c00257d5:	c0 
c00257d6:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00257dd:	c0 
c00257de:	c7 44 24 08 85 d9 02 	movl   $0xc002d985,0x8(%esp)
c00257e5:	c0 
c00257e6:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c00257ed:	00 
c00257ee:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c00257f5:	e8 c9 31 00 00       	call   c00289c3 <debug_panic>
  c->expecting_interrupt = true;
c00257fa:	c6 43 30 01          	movb   $0x1,0x30(%ebx)
  outb (reg_command (c), command);
c00257fe:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c0025802:	83 c2 07             	add    $0x7,%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025805:	89 f0                	mov    %esi,%eax
c0025807:	ee                   	out    %al,(%dx)
}
c0025808:	83 c4 24             	add    $0x24,%esp
c002580b:	5b                   	pop    %ebx
c002580c:	5e                   	pop    %esi
c002580d:	c3                   	ret    

c002580e <ide_write>:
{
c002580e:	57                   	push   %edi
c002580f:	56                   	push   %esi
c0025810:	53                   	push   %ebx
c0025811:	83 ec 20             	sub    $0x20,%esp
c0025814:	8b 74 24 30          	mov    0x30(%esp),%esi
  struct channel *c = d->channel;
c0025818:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c002581b:	8d 7b 0c             	lea    0xc(%ebx),%edi
c002581e:	89 3c 24             	mov    %edi,(%esp)
c0025821:	e8 84 d6 ff ff       	call   c0022eaa <lock_acquire>
  select_sector (d, sec_no);
c0025826:	8b 54 24 34          	mov    0x34(%esp),%edx
c002582a:	89 f0                	mov    %esi,%eax
c002582c:	e8 5c fe ff ff       	call   c002568d <select_sector>
  issue_pio_command (c, CMD_WRITE_SECTOR_RETRY);
c0025831:	ba 30 00 00 00       	mov    $0x30,%edx
c0025836:	89 d8                	mov    %ebx,%eax
c0025838:	e8 7e ff ff ff       	call   c00257bb <issue_pio_command>
  if (!wait_while_busy (d))
c002583d:	89 f0                	mov    %esi,%eax
c002583f:	e8 e1 fe ff ff       	call   c0025725 <wait_while_busy>
c0025844:	84 c0                	test   %al,%al
c0025846:	75 30                	jne    c0025878 <ide_write+0x6a>
    PANIC ("%s: disk write failed, sector=%"PRDSNu, d->name, sec_no);
c0025848:	8b 44 24 34          	mov    0x34(%esp),%eax
c002584c:	89 44 24 14          	mov    %eax,0x14(%esp)
c0025850:	89 74 24 10          	mov    %esi,0x10(%esp)
c0025854:	c7 44 24 0c a0 f6 02 	movl   $0xc002f6a0,0xc(%esp)
c002585b:	c0 
c002585c:	c7 44 24 08 ae d9 02 	movl   $0xc002d9ae,0x8(%esp)
c0025863:	c0 
c0025864:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
c002586b:	00 
c002586c:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c0025873:	e8 4b 31 00 00       	call   c00289c3 <debug_panic>
   CNT-halfword buffer starting at ADDR. */
static inline void
outsw (uint16_t port, const void *addr, size_t cnt)
{
  /* See [IA32-v2b] "OUTS". */
  asm volatile ("rep outsw" : "+S" (addr), "+c" (cnt) : "d" (port));
c0025878:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c002587c:	8b 74 24 38          	mov    0x38(%esp),%esi
c0025880:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025885:	66 f3 6f             	rep outsw %ds:(%esi),(%dx)
  sema_down (&c->completion_wait);
c0025888:	83 c3 34             	add    $0x34,%ebx
c002588b:	89 1c 24             	mov    %ebx,(%esp)
c002588e:	e8 ef d2 ff ff       	call   c0022b82 <sema_down>
  lock_release (&c->lock);
c0025893:	89 3c 24             	mov    %edi,(%esp)
c0025896:	e8 d9 d7 ff ff       	call   c0023074 <lock_release>
}
c002589b:	83 c4 20             	add    $0x20,%esp
c002589e:	5b                   	pop    %ebx
c002589f:	5e                   	pop    %esi
c00258a0:	5f                   	pop    %edi
c00258a1:	c3                   	ret    

c00258a2 <identify_ata_device>:
{
c00258a2:	57                   	push   %edi
c00258a3:	56                   	push   %esi
c00258a4:	53                   	push   %ebx
c00258a5:	81 ec a0 02 00 00    	sub    $0x2a0,%esp
c00258ab:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c00258ad:	8b 70 08             	mov    0x8(%eax),%esi
  ASSERT (d->is_ata);
c00258b0:	80 78 10 00          	cmpb   $0x0,0x10(%eax)
c00258b4:	75 2c                	jne    c00258e2 <identify_ata_device+0x40>
c00258b6:	c7 44 24 10 54 f6 02 	movl   $0xc002f654,0x10(%esp)
c00258bd:	c0 
c00258be:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00258c5:	c0 
c00258c6:	c7 44 24 08 b8 d9 02 	movl   $0xc002d9b8,0x8(%esp)
c00258cd:	c0 
c00258ce:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
c00258d5:	00 
c00258d6:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c00258dd:	e8 e1 30 00 00       	call   c00289c3 <debug_panic>
  wait_until_idle (d);
c00258e2:	e8 70 fc ff ff       	call   c0025557 <wait_until_idle>
  select_device (d);
c00258e7:	89 d8                	mov    %ebx,%eax
c00258e9:	e8 dc fc ff ff       	call   c00255ca <select_device>
  wait_until_idle (d);
c00258ee:	89 d8                	mov    %ebx,%eax
c00258f0:	e8 62 fc ff ff       	call   c0025557 <wait_until_idle>
  issue_pio_command (c, CMD_IDENTIFY_DEVICE);
c00258f5:	ba ec 00 00 00       	mov    $0xec,%edx
c00258fa:	89 f0                	mov    %esi,%eax
c00258fc:	e8 ba fe ff ff       	call   c00257bb <issue_pio_command>
  sema_down (&c->completion_wait);
c0025901:	8d 46 34             	lea    0x34(%esi),%eax
c0025904:	89 04 24             	mov    %eax,(%esp)
c0025907:	e8 76 d2 ff ff       	call   c0022b82 <sema_down>
  if (!wait_while_busy (d))
c002590c:	89 d8                	mov    %ebx,%eax
c002590e:	e8 12 fe ff ff       	call   c0025725 <wait_while_busy>
c0025913:	84 c0                	test   %al,%al
c0025915:	75 09                	jne    c0025920 <identify_ata_device+0x7e>
      d->is_ata = false;
c0025917:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c002591b:	e9 cf 00 00 00       	jmp    c00259ef <identify_ata_device+0x14d>
  asm volatile ("rep insw" : "+D" (addr), "+c" (cnt) : "d" (port) : "memory");
c0025920:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c0025924:	8d bc 24 a0 00 00 00 	lea    0xa0(%esp),%edi
c002592b:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025930:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  capacity = *(uint32_t *) &id[60 * 2];
c0025933:	8b b4 24 18 01 00 00 	mov    0x118(%esp),%esi
  model = descramble_ata_string (&id[10 * 2], 20);
c002593a:	ba 14 00 00 00       	mov    $0x14,%edx
c002593f:	8d 84 24 b4 00 00 00 	lea    0xb4(%esp),%eax
c0025946:	e8 25 fb ff ff       	call   c0025470 <descramble_ata_string>
c002594b:	89 c7                	mov    %eax,%edi
  serial = descramble_ata_string (&id[27 * 2], 40);
c002594d:	ba 28 00 00 00       	mov    $0x28,%edx
c0025952:	8d 84 24 d6 00 00 00 	lea    0xd6(%esp),%eax
c0025959:	e8 12 fb ff ff       	call   c0025470 <descramble_ata_string>
  snprintf (extra_info, sizeof extra_info,
c002595e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025962:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025966:	c7 44 24 08 5e f6 02 	movl   $0xc002f65e,0x8(%esp)
c002596d:	c0 
c002596e:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025975:	00 
c0025976:	8d 44 24 20          	lea    0x20(%esp),%eax
c002597a:	89 04 24             	mov    %eax,(%esp)
c002597d:	e8 ed 18 00 00       	call   c002726f <snprintf>
  if (capacity >= 1024 * 1024 * 1024 / BLOCK_SECTOR_SIZE)
c0025982:	81 fe ff ff 1f 00    	cmp    $0x1fffff,%esi
c0025988:	76 35                	jbe    c00259bf <identify_ata_device+0x11d>
      printf ("%s: ignoring ", d->name);
c002598a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002598e:	c7 04 24 76 f6 02 c0 	movl   $0xc002f676,(%esp)
c0025995:	e8 d4 11 00 00       	call   c0026b6e <printf>
      print_human_readable_size (capacity * 512);
c002599a:	c1 e6 09             	shl    $0x9,%esi
c002599d:	89 34 24             	mov    %esi,(%esp)
c00259a0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00259a7:	00 
c00259a8:	e8 8c 1a 00 00       	call   c0027439 <print_human_readable_size>
      printf ("disk for safety\n");
c00259ad:	c7 04 24 84 f6 02 c0 	movl   $0xc002f684,(%esp)
c00259b4:	e8 32 4d 00 00       	call   c002a6eb <puts>
      d->is_ata = false;
c00259b9:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c00259bd:	eb 30                	jmp    c00259ef <identify_ata_device+0x14d>
  block = block_register (d->name, BLOCK_RAW, extra_info, capacity,
c00259bf:	89 5c 24 14          	mov    %ebx,0x14(%esp)
c00259c3:	c7 44 24 10 74 5a 03 	movl   $0xc0035a74,0x10(%esp)
c00259ca:	c0 
c00259cb:	89 74 24 0c          	mov    %esi,0xc(%esp)
c00259cf:	8d 44 24 20          	lea    0x20(%esp),%eax
c00259d3:	89 44 24 08          	mov    %eax,0x8(%esp)
c00259d7:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c00259de:	00 
c00259df:	89 1c 24             	mov    %ebx,(%esp)
c00259e2:	e8 5a f5 ff ff       	call   c0024f41 <block_register>
  partition_scan (block);
c00259e7:	89 04 24             	mov    %eax,(%esp)
c00259ea:	e8 30 fa ff ff       	call   c002541f <partition_scan>
}
c00259ef:	81 c4 a0 02 00 00    	add    $0x2a0,%esp
c00259f5:	5b                   	pop    %ebx
c00259f6:	5e                   	pop    %esi
c00259f7:	5f                   	pop    %edi
c00259f8:	c3                   	ret    

c00259f9 <ide_read>:
{
c00259f9:	55                   	push   %ebp
c00259fa:	57                   	push   %edi
c00259fb:	56                   	push   %esi
c00259fc:	53                   	push   %ebx
c00259fd:	83 ec 2c             	sub    $0x2c,%esp
c0025a00:	8b 74 24 40          	mov    0x40(%esp),%esi
  struct channel *c = d->channel;
c0025a04:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c0025a07:	8d 6b 0c             	lea    0xc(%ebx),%ebp
c0025a0a:	89 2c 24             	mov    %ebp,(%esp)
c0025a0d:	e8 98 d4 ff ff       	call   c0022eaa <lock_acquire>
  select_sector (d, sec_no);
c0025a12:	8b 54 24 44          	mov    0x44(%esp),%edx
c0025a16:	89 f0                	mov    %esi,%eax
c0025a18:	e8 70 fc ff ff       	call   c002568d <select_sector>
  issue_pio_command (c, CMD_READ_SECTOR_RETRY);
c0025a1d:	ba 20 00 00 00       	mov    $0x20,%edx
c0025a22:	89 d8                	mov    %ebx,%eax
c0025a24:	e8 92 fd ff ff       	call   c00257bb <issue_pio_command>
  sema_down (&c->completion_wait);
c0025a29:	8d 43 34             	lea    0x34(%ebx),%eax
c0025a2c:	89 04 24             	mov    %eax,(%esp)
c0025a2f:	e8 4e d1 ff ff       	call   c0022b82 <sema_down>
  if (!wait_while_busy (d))
c0025a34:	89 f0                	mov    %esi,%eax
c0025a36:	e8 ea fc ff ff       	call   c0025725 <wait_while_busy>
c0025a3b:	84 c0                	test   %al,%al
c0025a3d:	75 30                	jne    c0025a6f <ide_read+0x76>
    PANIC ("%s: disk read failed, sector=%"PRDSNu, d->name, sec_no);
c0025a3f:	8b 44 24 44          	mov    0x44(%esp),%eax
c0025a43:	89 44 24 14          	mov    %eax,0x14(%esp)
c0025a47:	89 74 24 10          	mov    %esi,0x10(%esp)
c0025a4b:	c7 44 24 0c c4 f6 02 	movl   $0xc002f6c4,0xc(%esp)
c0025a52:	c0 
c0025a53:	c7 44 24 08 97 d9 02 	movl   $0xc002d997,0x8(%esp)
c0025a5a:	c0 
c0025a5b:	c7 44 24 04 62 01 00 	movl   $0x162,0x4(%esp)
c0025a62:	00 
c0025a63:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c0025a6a:	e8 54 2f 00 00       	call   c00289c3 <debug_panic>
c0025a6f:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c0025a73:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0025a77:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025a7c:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  lock_release (&c->lock);
c0025a7f:	89 2c 24             	mov    %ebp,(%esp)
c0025a82:	e8 ed d5 ff ff       	call   c0023074 <lock_release>
}
c0025a87:	83 c4 2c             	add    $0x2c,%esp
c0025a8a:	5b                   	pop    %ebx
c0025a8b:	5e                   	pop    %esi
c0025a8c:	5f                   	pop    %edi
c0025a8d:	5d                   	pop    %ebp
c0025a8e:	c3                   	ret    

c0025a8f <ide_init>:
{
c0025a8f:	55                   	push   %ebp
c0025a90:	57                   	push   %edi
c0025a91:	56                   	push   %esi
c0025a92:	53                   	push   %ebx
c0025a93:	83 ec 4c             	sub    $0x4c,%esp
c0025a96:	c7 44 24 1c 9c 78 03 	movl   $0xc003789c,0x1c(%esp)
c0025a9d:	c0 
c0025a9e:	bd 88 78 03 c0       	mov    $0xc0037888,%ebp
c0025aa3:	c7 44 24 20 61 00 00 	movl   $0x61,0x20(%esp)
c0025aaa:	00 
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025aab:	bf 00 00 00 00       	mov    $0x0,%edi
c0025ab0:	8d 75 b8             	lea    -0x48(%ebp),%esi
      snprintf (c->name, sizeof c->name, "ide%zu", chan_no);
c0025ab3:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025ab7:	c7 44 24 08 94 f6 02 	movl   $0xc002f694,0x8(%esp)
c0025abe:	c0 
c0025abf:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025ac6:	00 
c0025ac7:	89 34 24             	mov    %esi,(%esp)
c0025aca:	e8 a0 17 00 00       	call   c002726f <snprintf>
      switch (chan_no) 
c0025acf:	85 ff                	test   %edi,%edi
c0025ad1:	74 07                	je     c0025ada <ide_init+0x4b>
c0025ad3:	83 ff 01             	cmp    $0x1,%edi
c0025ad6:	74 0e                	je     c0025ae6 <ide_init+0x57>
c0025ad8:	eb 18                	jmp    c0025af2 <ide_init+0x63>
          c->reg_base = 0x1f0;
c0025ada:	66 c7 45 c0 f0 01    	movw   $0x1f0,-0x40(%ebp)
          c->irq = 14 + 0x20;
c0025ae0:	c6 45 c2 2e          	movb   $0x2e,-0x3e(%ebp)
          break;
c0025ae4:	eb 30                	jmp    c0025b16 <ide_init+0x87>
          c->reg_base = 0x170;
c0025ae6:	66 c7 45 c0 70 01    	movw   $0x170,-0x40(%ebp)
          c->irq = 15 + 0x20;
c0025aec:	c6 45 c2 2f          	movb   $0x2f,-0x3e(%ebp)
          break;
c0025af0:	eb 24                	jmp    c0025b16 <ide_init+0x87>
          NOT_REACHED ();
c0025af2:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0025af9:	c0 
c0025afa:	c7 44 24 08 de d9 02 	movl   $0xc002d9de,0x8(%esp)
c0025b01:	c0 
c0025b02:	c7 44 24 04 7c 00 00 	movl   $0x7c,0x4(%esp)
c0025b09:	00 
c0025b0a:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c0025b11:	e8 ad 2e 00 00       	call   c00289c3 <debug_panic>
c0025b16:	8d 45 c4             	lea    -0x3c(%ebp),%eax
      lock_init (&c->lock);
c0025b19:	89 04 24             	mov    %eax,(%esp)
c0025b1c:	e8 ec d2 ff ff       	call   c0022e0d <lock_init>
c0025b21:	89 eb                	mov    %ebp,%ebx
      c->expecting_interrupt = false;
c0025b23:	c6 45 e8 00          	movb   $0x0,-0x18(%ebp)
      sema_init (&c->completion_wait, 0);
c0025b27:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025b2e:	00 
c0025b2f:	8d 45 ec             	lea    -0x14(%ebp),%eax
c0025b32:	89 04 24             	mov    %eax,(%esp)
c0025b35:	e8 fc cf ff ff       	call   c0022b36 <sema_init>
          snprintf (d->name, sizeof d->name,
c0025b3a:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025b3e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b42:	c7 44 24 08 9b f6 02 	movl   $0xc002f69b,0x8(%esp)
c0025b49:	c0 
c0025b4a:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b51:	00 
c0025b52:	89 2c 24             	mov    %ebp,(%esp)
c0025b55:	e8 15 17 00 00       	call   c002726f <snprintf>
          d->channel = c;
c0025b5a:	89 75 08             	mov    %esi,0x8(%ebp)
          d->dev_no = dev_no;
c0025b5d:	c7 45 0c 00 00 00 00 	movl   $0x0,0xc(%ebp)
          d->is_ata = false;
c0025b64:	c6 45 10 00          	movb   $0x0,0x10(%ebp)
          snprintf (d->name, sizeof d->name,
c0025b68:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0025b6c:	89 4c 24 24          	mov    %ecx,0x24(%esp)
c0025b70:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025b74:	83 c0 01             	add    $0x1,%eax
c0025b77:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b7b:	c7 44 24 08 9b f6 02 	movl   $0xc002f69b,0x8(%esp)
c0025b82:	c0 
c0025b83:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b8a:	00 
c0025b8b:	89 0c 24             	mov    %ecx,(%esp)
c0025b8e:	e8 dc 16 00 00       	call   c002726f <snprintf>
          d->channel = c;
c0025b93:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0025b97:	89 70 08             	mov    %esi,0x8(%eax)
          d->dev_no = dev_no;
c0025b9a:	c7 40 0c 01 00 00 00 	movl   $0x1,0xc(%eax)
          d->is_ata = false;
c0025ba1:	c6 45 24 00          	movb   $0x0,0x24(%ebp)
      intr_register_ext (c->irq, interrupt_handler, c->name);
c0025ba5:	89 74 24 08          	mov    %esi,0x8(%esp)
c0025ba9:	c7 44 24 04 cc 54 02 	movl   $0xc00254cc,0x4(%esp)
c0025bb0:	c0 
c0025bb1:	0f b6 45 c2          	movzbl -0x3e(%ebp),%eax
c0025bb5:	89 04 24             	mov    %eax,(%esp)
c0025bb8:	e8 f6 bf ff ff       	call   c0021bb3 <intr_register_ext>
c0025bbd:	8d 74 24 3e          	lea    0x3e(%esp),%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025bc1:	89 7c 24 28          	mov    %edi,0x28(%esp)
c0025bc5:	89 6c 24 2c          	mov    %ebp,0x2c(%esp)
      select_device (d);
c0025bc9:	89 e8                	mov    %ebp,%eax
c0025bcb:	e8 fa f9 ff ff       	call   c00255ca <select_device>
      outb (reg_nsect (c), 0x55);
c0025bd0:	0f b7 7b c0          	movzwl -0x40(%ebx),%edi
c0025bd4:	8d 4f 02             	lea    0x2(%edi),%ecx
c0025bd7:	b8 55 00 00 00       	mov    $0x55,%eax
c0025bdc:	89 ca                	mov    %ecx,%edx
c0025bde:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0025bdf:	83 c7 03             	add    $0x3,%edi
c0025be2:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025be7:	89 fa                	mov    %edi,%edx
c0025be9:	ee                   	out    %al,(%dx)
c0025bea:	89 ca                	mov    %ecx,%edx
c0025bec:	ee                   	out    %al,(%dx)
c0025bed:	b8 55 00 00 00       	mov    $0x55,%eax
c0025bf2:	89 fa                	mov    %edi,%edx
c0025bf4:	ee                   	out    %al,(%dx)
c0025bf5:	89 ca                	mov    %ecx,%edx
c0025bf7:	ee                   	out    %al,(%dx)
c0025bf8:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025bfd:	89 fa                	mov    %edi,%edx
c0025bff:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025c00:	89 ca                	mov    %ecx,%edx
c0025c02:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0025c03:	ba 00 00 00 00       	mov    $0x0,%edx
c0025c08:	3c 55                	cmp    $0x55,%al
c0025c0a:	75 0b                	jne    c0025c17 <ide_init+0x188>
c0025c0c:	89 fa                	mov    %edi,%edx
c0025c0e:	ec                   	in     (%dx),%al
c0025c0f:	3c aa                	cmp    $0xaa,%al
c0025c11:	0f 94 c2             	sete   %dl
c0025c14:	0f b6 d2             	movzbl %dl,%edx
c0025c17:	88 16                	mov    %dl,(%esi)
c0025c19:	80 26 01             	andb   $0x1,(%esi)
c0025c1c:	83 c5 14             	add    $0x14,%ebp
c0025c1f:	83 c6 01             	add    $0x1,%esi
  for (dev_no = 0; dev_no < 2; dev_no++)
c0025c22:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025c26:	39 c6                	cmp    %eax,%esi
c0025c28:	75 9f                	jne    c0025bc9 <ide_init+0x13a>
c0025c2a:	8b 7c 24 28          	mov    0x28(%esp),%edi
c0025c2e:	8b 6c 24 2c          	mov    0x2c(%esp),%ebp
  outb (reg_ctl (c), 0);
c0025c32:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c36:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025c3c:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c41:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c42:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c49:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c50:	00 
c0025c51:	e8 9a e7 ff ff       	call   c00243f0 <timer_usleep>
  outb (reg_ctl (c), CTL_SRST);
c0025c56:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c5a:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c60:	b8 04 00 00 00       	mov    $0x4,%eax
c0025c65:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c66:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c6d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c74:	00 
c0025c75:	e8 76 e7 ff ff       	call   c00243f0 <timer_usleep>
  outb (reg_ctl (c), 0);
c0025c7a:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c7e:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c84:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c89:	ee                   	out    %al,(%dx)
  timer_msleep (150);
c0025c8a:	c7 04 24 96 00 00 00 	movl   $0x96,(%esp)
c0025c91:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c98:	00 
c0025c99:	e8 39 e7 ff ff       	call   c00243d7 <timer_msleep>
  if (present[0]) 
c0025c9e:	80 7c 24 3e 00       	cmpb   $0x0,0x3e(%esp)
c0025ca3:	74 0e                	je     c0025cb3 <ide_init+0x224>
      select_device (&c->devices[0]);
c0025ca5:	89 d8                	mov    %ebx,%eax
c0025ca7:	e8 1e f9 ff ff       	call   c00255ca <select_device>
      wait_while_busy (&c->devices[0]); 
c0025cac:	89 d8                	mov    %ebx,%eax
c0025cae:	e8 72 fa ff ff       	call   c0025725 <wait_while_busy>
  if (present[1])
c0025cb3:	80 7c 24 3f 00       	cmpb   $0x0,0x3f(%esp)
c0025cb8:	74 44                	je     c0025cfe <ide_init+0x26f>
      select_device (&c->devices[1]);
c0025cba:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cbe:	e8 07 f9 ff ff       	call   c00255ca <select_device>
c0025cc3:	be b8 0b 00 00       	mov    $0xbb8,%esi
          if (inb (reg_nsect (c)) == 1 && inb (reg_lbal (c)) == 1)
c0025cc8:	0f b7 4b c0          	movzwl -0x40(%ebx),%ecx
c0025ccc:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025ccf:	ec                   	in     (%dx),%al
c0025cd0:	3c 01                	cmp    $0x1,%al
c0025cd2:	75 08                	jne    c0025cdc <ide_init+0x24d>
c0025cd4:	8d 51 03             	lea    0x3(%ecx),%edx
c0025cd7:	ec                   	in     (%dx),%al
c0025cd8:	3c 01                	cmp    $0x1,%al
c0025cda:	74 19                	je     c0025cf5 <ide_init+0x266>
          timer_msleep (10);
c0025cdc:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025ce3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025cea:	00 
c0025ceb:	e8 e7 e6 ff ff       	call   c00243d7 <timer_msleep>
      for (i = 0; i < 3000; i++) 
c0025cf0:	83 ee 01             	sub    $0x1,%esi
c0025cf3:	75 d3                	jne    c0025cc8 <ide_init+0x239>
      wait_while_busy (&c->devices[1]);
c0025cf5:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cf9:	e8 27 fa ff ff       	call   c0025725 <wait_while_busy>
      if (check_device_type (&c->devices[0]))
c0025cfe:	89 d8                	mov    %ebx,%eax
c0025d00:	e8 03 f9 ff ff       	call   c0025608 <check_device_type>
c0025d05:	84 c0                	test   %al,%al
c0025d07:	74 2f                	je     c0025d38 <ide_init+0x2a9>
        check_device_type (&c->devices[1]);
c0025d09:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025d0d:	e8 f6 f8 ff ff       	call   c0025608 <check_device_type>
c0025d12:	eb 24                	jmp    c0025d38 <ide_init+0x2a9>
          identify_ata_device (&c->devices[dev_no]);
c0025d14:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025d18:	e8 85 fb ff ff       	call   c00258a2 <identify_ata_device>
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025d1d:	83 c7 01             	add    $0x1,%edi
c0025d20:	83 44 24 1c 70       	addl   $0x70,0x1c(%esp)
c0025d25:	83 c5 70             	add    $0x70,%ebp
c0025d28:	83 44 24 20 02       	addl   $0x2,0x20(%esp)
c0025d2d:	83 ff 02             	cmp    $0x2,%edi
c0025d30:	0f 85 7a fd ff ff    	jne    c0025ab0 <ide_init+0x21>
c0025d36:	eb 15                	jmp    c0025d4d <ide_init+0x2be>
        if (c->devices[dev_no].is_ata)
c0025d38:	80 7b 10 00          	cmpb   $0x0,0x10(%ebx)
c0025d3c:	74 07                	je     c0025d45 <ide_init+0x2b6>
          identify_ata_device (&c->devices[dev_no]);
c0025d3e:	89 d8                	mov    %ebx,%eax
c0025d40:	e8 5d fb ff ff       	call   c00258a2 <identify_ata_device>
        if (c->devices[dev_no].is_ata)
c0025d45:	80 7b 24 00          	cmpb   $0x0,0x24(%ebx)
c0025d49:	74 d2                	je     c0025d1d <ide_init+0x28e>
c0025d4b:	eb c7                	jmp    c0025d14 <ide_init+0x285>
}
c0025d4d:	83 c4 4c             	add    $0x4c,%esp
c0025d50:	5b                   	pop    %ebx
c0025d51:	5e                   	pop    %esi
c0025d52:	5f                   	pop    %edi
c0025d53:	5d                   	pop    %ebp
c0025d54:	c3                   	ret    

c0025d55 <input_init>:
static struct intq buffer;

/* Initializes the input buffer. */
void
input_init (void) 
{
c0025d55:	83 ec 1c             	sub    $0x1c,%esp
  intq_init (&buffer);
c0025d58:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d5f:	e8 11 01 00 00       	call   c0025e75 <intq_init>
}
c0025d64:	83 c4 1c             	add    $0x1c,%esp
c0025d67:	c3                   	ret    

c0025d68 <input_putc>:

/* Adds a key to the input buffer.
   Interrupts must be off and the buffer must not be full. */
void
input_putc (uint8_t key) 
{
c0025d68:	53                   	push   %ebx
c0025d69:	83 ec 28             	sub    $0x28,%esp
c0025d6c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025d70:	e8 4f bc ff ff       	call   c00219c4 <intr_get_level>
c0025d75:	85 c0                	test   %eax,%eax
c0025d77:	74 2c                	je     c0025da5 <input_putc+0x3d>
c0025d79:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025d80:	c0 
c0025d81:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025d88:	c0 
c0025d89:	c7 44 24 08 f2 d9 02 	movl   $0xc002d9f2,0x8(%esp)
c0025d90:	c0 
c0025d91:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c0025d98:	00 
c0025d99:	c7 04 24 e4 f6 02 c0 	movl   $0xc002f6e4,(%esp)
c0025da0:	e8 1e 2c 00 00       	call   c00289c3 <debug_panic>
  ASSERT (!intq_full (&buffer));
c0025da5:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025dac:	e8 40 01 00 00       	call   c0025ef1 <intq_full>
c0025db1:	84 c0                	test   %al,%al
c0025db3:	74 2c                	je     c0025de1 <input_putc+0x79>
c0025db5:	c7 44 24 10 fa f6 02 	movl   $0xc002f6fa,0x10(%esp)
c0025dbc:	c0 
c0025dbd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025dc4:	c0 
c0025dc5:	c7 44 24 08 f2 d9 02 	movl   $0xc002d9f2,0x8(%esp)
c0025dcc:	c0 
c0025dcd:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025dd4:	00 
c0025dd5:	c7 04 24 e4 f6 02 c0 	movl   $0xc002f6e4,(%esp)
c0025ddc:	e8 e2 2b 00 00       	call   c00289c3 <debug_panic>

  intq_putc (&buffer, key);
c0025de1:	0f b6 db             	movzbl %bl,%ebx
c0025de4:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0025de8:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025def:	e8 a7 03 00 00       	call   c002619b <intq_putc>
  serial_notify ();
c0025df4:	e8 21 ee ff ff       	call   c0024c1a <serial_notify>
}
c0025df9:	83 c4 28             	add    $0x28,%esp
c0025dfc:	5b                   	pop    %ebx
c0025dfd:	c3                   	ret    

c0025dfe <input_getc>:

/* Retrieves a key from the input buffer.
   If the buffer is empty, waits for a key to be pressed. */
uint8_t
input_getc (void) 
{
c0025dfe:	56                   	push   %esi
c0025dff:	53                   	push   %ebx
c0025e00:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level;
  uint8_t key;

  old_level = intr_disable ();
c0025e03:	e8 07 bc ff ff       	call   c0021a0f <intr_disable>
c0025e08:	89 c6                	mov    %eax,%esi
  key = intq_getc (&buffer);
c0025e0a:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025e11:	e8 b9 02 00 00       	call   c00260cf <intq_getc>
c0025e16:	89 c3                	mov    %eax,%ebx
  serial_notify ();
c0025e18:	e8 fd ed ff ff       	call   c0024c1a <serial_notify>
  intr_set_level (old_level);
c0025e1d:	89 34 24             	mov    %esi,(%esp)
c0025e20:	e8 f1 bb ff ff       	call   c0021a16 <intr_set_level>
  
  return key;
}
c0025e25:	89 d8                	mov    %ebx,%eax
c0025e27:	83 c4 14             	add    $0x14,%esp
c0025e2a:	5b                   	pop    %ebx
c0025e2b:	5e                   	pop    %esi
c0025e2c:	c3                   	ret    

c0025e2d <input_full>:
/* Returns true if the input buffer is full,
   false otherwise.
   Interrupts must be off. */
bool
input_full (void) 
{
c0025e2d:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0025e30:	e8 8f bb ff ff       	call   c00219c4 <intr_get_level>
c0025e35:	85 c0                	test   %eax,%eax
c0025e37:	74 2c                	je     c0025e65 <input_full+0x38>
c0025e39:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025e40:	c0 
c0025e41:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025e48:	c0 
c0025e49:	c7 44 24 08 e7 d9 02 	movl   $0xc002d9e7,0x8(%esp)
c0025e50:	c0 
c0025e51:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c0025e58:	00 
c0025e59:	c7 04 24 e4 f6 02 c0 	movl   $0xc002f6e4,(%esp)
c0025e60:	e8 5e 2b 00 00       	call   c00289c3 <debug_panic>
  return intq_full (&buffer);
c0025e65:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025e6c:	e8 80 00 00 00       	call   c0025ef1 <intq_full>
}
c0025e71:	83 c4 2c             	add    $0x2c,%esp
c0025e74:	c3                   	ret    

c0025e75 <intq_init>:
static void signal (struct intq *q, struct thread **waiter);

/* Initializes interrupt queue Q. */
void
intq_init (struct intq *q) 
{
c0025e75:	53                   	push   %ebx
c0025e76:	83 ec 18             	sub    $0x18,%esp
c0025e79:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_init (&q->lock);
c0025e7d:	89 1c 24             	mov    %ebx,(%esp)
c0025e80:	e8 88 cf ff ff       	call   c0022e0d <lock_init>
  q->not_full = q->not_empty = NULL;
c0025e85:	c7 43 28 00 00 00 00 	movl   $0x0,0x28(%ebx)
c0025e8c:	c7 43 24 00 00 00 00 	movl   $0x0,0x24(%ebx)
  q->head = q->tail = 0;
c0025e93:	c7 43 70 00 00 00 00 	movl   $0x0,0x70(%ebx)
c0025e9a:	c7 43 6c 00 00 00 00 	movl   $0x0,0x6c(%ebx)
}
c0025ea1:	83 c4 18             	add    $0x18,%esp
c0025ea4:	5b                   	pop    %ebx
c0025ea5:	c3                   	ret    

c0025ea6 <intq_empty>:

/* Returns true if Q is empty, false otherwise. */
bool
intq_empty (const struct intq *q) 
{
c0025ea6:	53                   	push   %ebx
c0025ea7:	83 ec 28             	sub    $0x28,%esp
c0025eaa:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025eae:	e8 11 bb ff ff       	call   c00219c4 <intr_get_level>
c0025eb3:	85 c0                	test   %eax,%eax
c0025eb5:	74 2c                	je     c0025ee3 <intq_empty+0x3d>
c0025eb7:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025ebe:	c0 
c0025ebf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025ec6:	c0 
c0025ec7:	c7 44 24 08 27 da 02 	movl   $0xc002da27,0x8(%esp)
c0025ece:	c0 
c0025ecf:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025ed6:	00 
c0025ed7:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025ede:	e8 e0 2a 00 00       	call   c00289c3 <debug_panic>
  return q->head == q->tail;
c0025ee3:	8b 43 70             	mov    0x70(%ebx),%eax
c0025ee6:	39 43 6c             	cmp    %eax,0x6c(%ebx)
c0025ee9:	0f 94 c0             	sete   %al
}
c0025eec:	83 c4 28             	add    $0x28,%esp
c0025eef:	5b                   	pop    %ebx
c0025ef0:	c3                   	ret    

c0025ef1 <intq_full>:

/* Returns true if Q is full, false otherwise. */
bool
intq_full (const struct intq *q) 
{
c0025ef1:	53                   	push   %ebx
c0025ef2:	83 ec 28             	sub    $0x28,%esp
c0025ef5:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025ef9:	e8 c6 ba ff ff       	call   c00219c4 <intr_get_level>
c0025efe:	85 c0                	test   %eax,%eax
c0025f00:	74 2c                	je     c0025f2e <intq_full+0x3d>
c0025f02:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025f09:	c0 
c0025f0a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025f11:	c0 
c0025f12:	c7 44 24 08 1d da 02 	movl   $0xc002da1d,0x8(%esp)
c0025f19:	c0 
c0025f1a:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c0025f21:	00 
c0025f22:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025f29:	e8 95 2a 00 00       	call   c00289c3 <debug_panic>

/* Returns the position after POS within an intq. */
static int
next (int pos) 
{
  return (pos + 1) % INTQ_BUFSIZE;
c0025f2e:	8b 43 6c             	mov    0x6c(%ebx),%eax
c0025f31:	8d 50 01             	lea    0x1(%eax),%edx
c0025f34:	89 d0                	mov    %edx,%eax
c0025f36:	c1 f8 1f             	sar    $0x1f,%eax
c0025f39:	c1 e8 1a             	shr    $0x1a,%eax
c0025f3c:	01 c2                	add    %eax,%edx
c0025f3e:	83 e2 3f             	and    $0x3f,%edx
c0025f41:	29 c2                	sub    %eax,%edx
  return next (q->head) == q->tail;
c0025f43:	39 53 70             	cmp    %edx,0x70(%ebx)
c0025f46:	0f 94 c0             	sete   %al
}
c0025f49:	83 c4 28             	add    $0x28,%esp
c0025f4c:	5b                   	pop    %ebx
c0025f4d:	c3                   	ret    

c0025f4e <wait>:

/* WAITER must be the address of Q's not_empty or not_full
   member.  Waits until the given condition is true. */
static void
wait (struct intq *q UNUSED, struct thread **waiter) 
{
c0025f4e:	56                   	push   %esi
c0025f4f:	53                   	push   %ebx
c0025f50:	83 ec 24             	sub    $0x24,%esp
c0025f53:	89 c3                	mov    %eax,%ebx
c0025f55:	89 d6                	mov    %edx,%esi
  ASSERT (!intr_context ());
c0025f57:	e8 15 bd ff ff       	call   c0021c71 <intr_context>
c0025f5c:	84 c0                	test   %al,%al
c0025f5e:	74 2c                	je     c0025f8c <wait+0x3e>
c0025f60:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0025f67:	c0 
c0025f68:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025f6f:	c0 
c0025f70:	c7 44 24 08 0e da 02 	movl   $0xc002da0e,0x8(%esp)
c0025f77:	c0 
c0025f78:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c0025f7f:	00 
c0025f80:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025f87:	e8 37 2a 00 00       	call   c00289c3 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0025f8c:	e8 33 ba ff ff       	call   c00219c4 <intr_get_level>
c0025f91:	85 c0                	test   %eax,%eax
c0025f93:	74 2c                	je     c0025fc1 <wait+0x73>
c0025f95:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025f9c:	c0 
c0025f9d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025fa4:	c0 
c0025fa5:	c7 44 24 08 0e da 02 	movl   $0xc002da0e,0x8(%esp)
c0025fac:	c0 
c0025fad:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c0025fb4:	00 
c0025fb5:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025fbc:	e8 02 2a 00 00       	call   c00289c3 <debug_panic>
  ASSERT ((waiter == &q->not_empty && intq_empty (q))
c0025fc1:	8d 43 28             	lea    0x28(%ebx),%eax
c0025fc4:	39 c6                	cmp    %eax,%esi
c0025fc6:	75 0c                	jne    c0025fd4 <wait+0x86>
c0025fc8:	89 1c 24             	mov    %ebx,(%esp)
c0025fcb:	e8 d6 fe ff ff       	call   c0025ea6 <intq_empty>
c0025fd0:	84 c0                	test   %al,%al
c0025fd2:	75 3f                	jne    c0026013 <wait+0xc5>
c0025fd4:	8d 43 24             	lea    0x24(%ebx),%eax
c0025fd7:	39 c6                	cmp    %eax,%esi
c0025fd9:	75 0c                	jne    c0025fe7 <wait+0x99>
c0025fdb:	89 1c 24             	mov    %ebx,(%esp)
c0025fde:	e8 0e ff ff ff       	call   c0025ef1 <intq_full>
c0025fe3:	84 c0                	test   %al,%al
c0025fe5:	75 2c                	jne    c0026013 <wait+0xc5>
c0025fe7:	c7 44 24 10 24 f7 02 	movl   $0xc002f724,0x10(%esp)
c0025fee:	c0 
c0025fef:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025ff6:	c0 
c0025ff7:	c7 44 24 08 0e da 02 	movl   $0xc002da0e,0x8(%esp)
c0025ffe:	c0 
c0025fff:	c7 44 24 04 5c 00 00 	movl   $0x5c,0x4(%esp)
c0026006:	00 
c0026007:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c002600e:	e8 b0 29 00 00       	call   c00289c3 <debug_panic>
          || (waiter == &q->not_full && intq_full (q)));

  *waiter = thread_current ();
c0026013:	e8 15 ae ff ff       	call   c0020e2d <thread_current>
c0026018:	89 06                	mov    %eax,(%esi)
  thread_block ();
c002601a:	e8 46 b3 ff ff       	call   c0021365 <thread_block>
}
c002601f:	83 c4 24             	add    $0x24,%esp
c0026022:	5b                   	pop    %ebx
c0026023:	5e                   	pop    %esi
c0026024:	c3                   	ret    

c0026025 <signal>:
   member, and the associated condition must be true.  If a
   thread is waiting for the condition, wakes it up and resets
   the waiting thread. */
static void
signal (struct intq *q UNUSED, struct thread **waiter) 
{
c0026025:	56                   	push   %esi
c0026026:	53                   	push   %ebx
c0026027:	83 ec 24             	sub    $0x24,%esp
c002602a:	89 c6                	mov    %eax,%esi
c002602c:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c002602e:	e8 91 b9 ff ff       	call   c00219c4 <intr_get_level>
c0026033:	85 c0                	test   %eax,%eax
c0026035:	74 2c                	je     c0026063 <signal+0x3e>
c0026037:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c002603e:	c0 
c002603f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0026046:	c0 
c0026047:	c7 44 24 08 07 da 02 	movl   $0xc002da07,0x8(%esp)
c002604e:	c0 
c002604f:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0026056:	00 
c0026057:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c002605e:	e8 60 29 00 00       	call   c00289c3 <debug_panic>
  ASSERT ((waiter == &q->not_empty && !intq_empty (q))
c0026063:	8d 46 28             	lea    0x28(%esi),%eax
c0026066:	39 c3                	cmp    %eax,%ebx
c0026068:	75 0c                	jne    c0026076 <signal+0x51>
c002606a:	89 34 24             	mov    %esi,(%esp)
c002606d:	e8 34 fe ff ff       	call   c0025ea6 <intq_empty>
c0026072:	84 c0                	test   %al,%al
c0026074:	74 3f                	je     c00260b5 <signal+0x90>
c0026076:	8d 46 24             	lea    0x24(%esi),%eax
c0026079:	39 c3                	cmp    %eax,%ebx
c002607b:	75 0c                	jne    c0026089 <signal+0x64>
c002607d:	89 34 24             	mov    %esi,(%esp)
c0026080:	e8 6c fe ff ff       	call   c0025ef1 <intq_full>
c0026085:	84 c0                	test   %al,%al
c0026087:	74 2c                	je     c00260b5 <signal+0x90>
c0026089:	c7 44 24 10 80 f7 02 	movl   $0xc002f780,0x10(%esp)
c0026090:	c0 
c0026091:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0026098:	c0 
c0026099:	c7 44 24 08 07 da 02 	movl   $0xc002da07,0x8(%esp)
c00260a0:	c0 
c00260a1:	c7 44 24 04 6b 00 00 	movl   $0x6b,0x4(%esp)
c00260a8:	00 
c00260a9:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c00260b0:	e8 0e 29 00 00       	call   c00289c3 <debug_panic>
          || (waiter == &q->not_full && !intq_full (q)));

  if (*waiter != NULL) 
c00260b5:	8b 03                	mov    (%ebx),%eax
c00260b7:	85 c0                	test   %eax,%eax
c00260b9:	74 0e                	je     c00260c9 <signal+0xa4>
    {
      thread_unblock (*waiter);
c00260bb:	89 04 24             	mov    %eax,(%esp)
c00260be:	e8 91 ac ff ff       	call   c0020d54 <thread_unblock>
      *waiter = NULL;
c00260c3:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
    }
}
c00260c9:	83 c4 24             	add    $0x24,%esp
c00260cc:	5b                   	pop    %ebx
c00260cd:	5e                   	pop    %esi
c00260ce:	c3                   	ret    

c00260cf <intq_getc>:
{
c00260cf:	56                   	push   %esi
c00260d0:	53                   	push   %ebx
c00260d1:	83 ec 24             	sub    $0x24,%esp
c00260d4:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c00260d8:	e8 e7 b8 ff ff       	call   c00219c4 <intr_get_level>
c00260dd:	85 c0                	test   %eax,%eax
c00260df:	75 05                	jne    c00260e6 <intq_getc+0x17>
      wait (q, &q->not_empty);
c00260e1:	8d 73 28             	lea    0x28(%ebx),%esi
c00260e4:	eb 7a                	jmp    c0026160 <intq_getc+0x91>
  ASSERT (intr_get_level () == INTR_OFF);
c00260e6:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00260ed:	c0 
c00260ee:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00260f5:	c0 
c00260f6:	c7 44 24 08 13 da 02 	movl   $0xc002da13,0x8(%esp)
c00260fd:	c0 
c00260fe:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c0026105:	00 
c0026106:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c002610d:	e8 b1 28 00 00       	call   c00289c3 <debug_panic>
      ASSERT (!intr_context ());
c0026112:	e8 5a bb ff ff       	call   c0021c71 <intr_context>
c0026117:	84 c0                	test   %al,%al
c0026119:	74 2c                	je     c0026147 <intq_getc+0x78>
c002611b:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0026122:	c0 
c0026123:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002612a:	c0 
c002612b:	c7 44 24 08 13 da 02 	movl   $0xc002da13,0x8(%esp)
c0026132:	c0 
c0026133:	c7 44 24 04 2d 00 00 	movl   $0x2d,0x4(%esp)
c002613a:	00 
c002613b:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0026142:	e8 7c 28 00 00       	call   c00289c3 <debug_panic>
      lock_acquire (&q->lock);
c0026147:	89 1c 24             	mov    %ebx,(%esp)
c002614a:	e8 5b cd ff ff       	call   c0022eaa <lock_acquire>
      wait (q, &q->not_empty);
c002614f:	89 f2                	mov    %esi,%edx
c0026151:	89 d8                	mov    %ebx,%eax
c0026153:	e8 f6 fd ff ff       	call   c0025f4e <wait>
      lock_release (&q->lock);
c0026158:	89 1c 24             	mov    %ebx,(%esp)
c002615b:	e8 14 cf ff ff       	call   c0023074 <lock_release>
  while (intq_empty (q)) 
c0026160:	89 1c 24             	mov    %ebx,(%esp)
c0026163:	e8 3e fd ff ff       	call   c0025ea6 <intq_empty>
c0026168:	84 c0                	test   %al,%al
c002616a:	75 a6                	jne    c0026112 <intq_getc+0x43>
  byte = q->buf[q->tail];
c002616c:	8b 4b 70             	mov    0x70(%ebx),%ecx
c002616f:	0f b6 74 0b 2c       	movzbl 0x2c(%ebx,%ecx,1),%esi
  return (pos + 1) % INTQ_BUFSIZE;
c0026174:	83 c1 01             	add    $0x1,%ecx
c0026177:	89 ca                	mov    %ecx,%edx
c0026179:	c1 fa 1f             	sar    $0x1f,%edx
c002617c:	c1 ea 1a             	shr    $0x1a,%edx
c002617f:	01 d1                	add    %edx,%ecx
c0026181:	83 e1 3f             	and    $0x3f,%ecx
c0026184:	29 d1                	sub    %edx,%ecx
  q->tail = next (q->tail);
c0026186:	89 4b 70             	mov    %ecx,0x70(%ebx)
  signal (q, &q->not_full);
c0026189:	8d 53 24             	lea    0x24(%ebx),%edx
c002618c:	89 d8                	mov    %ebx,%eax
c002618e:	e8 92 fe ff ff       	call   c0026025 <signal>
}
c0026193:	89 f0                	mov    %esi,%eax
c0026195:	83 c4 24             	add    $0x24,%esp
c0026198:	5b                   	pop    %ebx
c0026199:	5e                   	pop    %esi
c002619a:	c3                   	ret    

c002619b <intq_putc>:
{
c002619b:	57                   	push   %edi
c002619c:	56                   	push   %esi
c002619d:	53                   	push   %ebx
c002619e:	83 ec 20             	sub    $0x20,%esp
c00261a1:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00261a5:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c00261a9:	e8 16 b8 ff ff       	call   c00219c4 <intr_get_level>
c00261ae:	85 c0                	test   %eax,%eax
c00261b0:	75 05                	jne    c00261b7 <intq_putc+0x1c>
      wait (q, &q->not_full);
c00261b2:	8d 73 24             	lea    0x24(%ebx),%esi
c00261b5:	eb 7a                	jmp    c0026231 <intq_putc+0x96>
  ASSERT (intr_get_level () == INTR_OFF);
c00261b7:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00261be:	c0 
c00261bf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00261c6:	c0 
c00261c7:	c7 44 24 08 fd d9 02 	movl   $0xc002d9fd,0x8(%esp)
c00261ce:	c0 
c00261cf:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c00261d6:	00 
c00261d7:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c00261de:	e8 e0 27 00 00       	call   c00289c3 <debug_panic>
      ASSERT (!intr_context ());
c00261e3:	e8 89 ba ff ff       	call   c0021c71 <intr_context>
c00261e8:	84 c0                	test   %al,%al
c00261ea:	74 2c                	je     c0026218 <intq_putc+0x7d>
c00261ec:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c00261f3:	c0 
c00261f4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00261fb:	c0 
c00261fc:	c7 44 24 08 fd d9 02 	movl   $0xc002d9fd,0x8(%esp)
c0026203:	c0 
c0026204:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
c002620b:	00 
c002620c:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0026213:	e8 ab 27 00 00       	call   c00289c3 <debug_panic>
      lock_acquire (&q->lock);
c0026218:	89 1c 24             	mov    %ebx,(%esp)
c002621b:	e8 8a cc ff ff       	call   c0022eaa <lock_acquire>
      wait (q, &q->not_full);
c0026220:	89 f2                	mov    %esi,%edx
c0026222:	89 d8                	mov    %ebx,%eax
c0026224:	e8 25 fd ff ff       	call   c0025f4e <wait>
      lock_release (&q->lock);
c0026229:	89 1c 24             	mov    %ebx,(%esp)
c002622c:	e8 43 ce ff ff       	call   c0023074 <lock_release>
  while (intq_full (q))
c0026231:	89 1c 24             	mov    %ebx,(%esp)
c0026234:	e8 b8 fc ff ff       	call   c0025ef1 <intq_full>
c0026239:	84 c0                	test   %al,%al
c002623b:	75 a6                	jne    c00261e3 <intq_putc+0x48>
  q->buf[q->head] = byte;
c002623d:	8b 53 6c             	mov    0x6c(%ebx),%edx
c0026240:	89 f8                	mov    %edi,%eax
c0026242:	88 44 13 2c          	mov    %al,0x2c(%ebx,%edx,1)
  return (pos + 1) % INTQ_BUFSIZE;
c0026246:	83 c2 01             	add    $0x1,%edx
c0026249:	89 d0                	mov    %edx,%eax
c002624b:	c1 f8 1f             	sar    $0x1f,%eax
c002624e:	c1 e8 1a             	shr    $0x1a,%eax
c0026251:	01 c2                	add    %eax,%edx
c0026253:	83 e2 3f             	and    $0x3f,%edx
c0026256:	29 c2                	sub    %eax,%edx
  q->head = next (q->head);
c0026258:	89 53 6c             	mov    %edx,0x6c(%ebx)
  signal (q, &q->not_empty);
c002625b:	8d 53 28             	lea    0x28(%ebx),%edx
c002625e:	89 d8                	mov    %ebx,%eax
c0026260:	e8 c0 fd ff ff       	call   c0026025 <signal>
}
c0026265:	83 c4 20             	add    $0x20,%esp
c0026268:	5b                   	pop    %ebx
c0026269:	5e                   	pop    %esi
c002626a:	5f                   	pop    %edi
c002626b:	c3                   	ret    

c002626c <rtc_get_time>:

/* Returns number of seconds since Unix epoch of January 1,
   1970. */
time_t
rtc_get_time (void)
{
c002626c:	55                   	push   %ebp
c002626d:	57                   	push   %edi
c002626e:	56                   	push   %esi
c002626f:	53                   	push   %ebx
c0026270:	83 ec 03             	sub    $0x3,%esp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026273:	bb 00 00 00 00       	mov    $0x0,%ebx
c0026278:	bd 02 00 00 00       	mov    $0x2,%ebp
c002627d:	89 d8                	mov    %ebx,%eax
c002627f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026281:	e4 71                	in     $0x71,%al

/* Returns the integer value of the given BCD byte. */
static int
bcd_to_bin (uint8_t x)
{
  return (x & 0x0f) + ((x >> 4) * 10);
c0026283:	89 c2                	mov    %eax,%edx
c0026285:	83 e2 0f             	and    $0xf,%edx
c0026288:	c0 e8 04             	shr    $0x4,%al
c002628b:	0f b6 c0             	movzbl %al,%eax
c002628e:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0026291:	8d 0c 42             	lea    (%edx,%eax,2),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026294:	89 e8                	mov    %ebp,%eax
c0026296:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026298:	e4 71                	in     $0x71,%al
c002629a:	88 04 24             	mov    %al,(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002629d:	b8 04 00 00 00       	mov    $0x4,%eax
c00262a2:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262a4:	e4 71                	in     $0x71,%al
c00262a6:	88 44 24 01          	mov    %al,0x1(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00262aa:	b8 07 00 00 00       	mov    $0x7,%eax
c00262af:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262b1:	e4 71                	in     $0x71,%al
c00262b3:	88 44 24 02          	mov    %al,0x2(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00262b7:	b8 08 00 00 00       	mov    $0x8,%eax
c00262bc:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262be:	e4 71                	in     $0x71,%al
c00262c0:	89 c6                	mov    %eax,%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00262c2:	b8 09 00 00 00       	mov    $0x9,%eax
c00262c7:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262c9:	e4 71                	in     $0x71,%al
c00262cb:	89 c7                	mov    %eax,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00262cd:	89 d8                	mov    %ebx,%eax
c00262cf:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262d1:	e4 71                	in     $0x71,%al
c00262d3:	89 c2                	mov    %eax,%edx
c00262d5:	89 d0                	mov    %edx,%eax
c00262d7:	83 e0 0f             	and    $0xf,%eax
c00262da:	c0 ea 04             	shr    $0x4,%dl
c00262dd:	0f b6 d2             	movzbl %dl,%edx
c00262e0:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00262e3:	8d 04 50             	lea    (%eax,%edx,2),%eax
  while (sec != bcd_to_bin (cmos_read (RTC_REG_SEC)));
c00262e6:	39 c1                	cmp    %eax,%ecx
c00262e8:	75 93                	jne    c002627d <rtc_get_time+0x11>
  return (x & 0x0f) + ((x >> 4) * 10);
c00262ea:	89 fa                	mov    %edi,%edx
c00262ec:	83 e2 0f             	and    $0xf,%edx
c00262ef:	89 f8                	mov    %edi,%eax
c00262f1:	c0 e8 04             	shr    $0x4,%al
c00262f4:	0f b6 f8             	movzbl %al,%edi
c00262f7:	8d 04 bf             	lea    (%edi,%edi,4),%eax
  if (year < 70)
c00262fa:	8d 04 42             	lea    (%edx,%eax,2),%eax
    year += 100;
c00262fd:	8d 50 64             	lea    0x64(%eax),%edx
c0026300:	83 f8 45             	cmp    $0x45,%eax
c0026303:	0f 4e c2             	cmovle %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c0026306:	89 f2                	mov    %esi,%edx
c0026308:	83 e2 0f             	and    $0xf,%edx
c002630b:	89 f3                	mov    %esi,%ebx
c002630d:	c0 eb 04             	shr    $0x4,%bl
c0026310:	0f b6 f3             	movzbl %bl,%esi
c0026313:	8d 1c b6             	lea    (%esi,%esi,4),%ebx
c0026316:	8d 34 5a             	lea    (%edx,%ebx,2),%esi
  year -= 70;
c0026319:	8d 78 ba             	lea    -0x46(%eax),%edi
  time = (year * 365 + (year - 1) / 4) * 24 * 60 * 60;
c002631c:	69 df 6d 01 00 00    	imul   $0x16d,%edi,%ebx
c0026322:	8d 50 bc             	lea    -0x44(%eax),%edx
c0026325:	83 e8 47             	sub    $0x47,%eax
c0026328:	0f 48 c2             	cmovs  %edx,%eax
c002632b:	c1 f8 02             	sar    $0x2,%eax
c002632e:	01 d8                	add    %ebx,%eax
c0026330:	69 c0 80 51 01 00    	imul   $0x15180,%eax,%eax
  for (i = 1; i <= mon; i++)
c0026336:	85 f6                	test   %esi,%esi
c0026338:	7e 19                	jle    c0026353 <rtc_get_time+0xe7>
c002633a:	ba 01 00 00 00       	mov    $0x1,%edx
    time += days_per_month[i - 1] * 24 * 60 * 60;
c002633f:	69 1c 95 3c da 02 c0 	imul   $0x15180,-0x3ffd25c4(,%edx,4),%ebx
c0026346:	80 51 01 00 
c002634a:	01 d8                	add    %ebx,%eax
  for (i = 1; i <= mon; i++)
c002634c:	83 c2 01             	add    $0x1,%edx
c002634f:	39 f2                	cmp    %esi,%edx
c0026351:	7e ec                	jle    c002633f <rtc_get_time+0xd3>
  if (mon > 2 && year % 4 == 0)
c0026353:	83 fe 02             	cmp    $0x2,%esi
c0026356:	7e 0e                	jle    c0026366 <rtc_get_time+0xfa>
c0026358:	83 e7 03             	and    $0x3,%edi
    time += 24 * 60 * 60;
c002635b:	8d 90 80 51 01 00    	lea    0x15180(%eax),%edx
c0026361:	85 ff                	test   %edi,%edi
c0026363:	0f 44 c2             	cmove  %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c0026366:	0f b6 54 24 01       	movzbl 0x1(%esp),%edx
c002636b:	89 d3                	mov    %edx,%ebx
c002636d:	83 e3 0f             	and    $0xf,%ebx
c0026370:	c0 ea 04             	shr    $0x4,%dl
c0026373:	0f b6 d2             	movzbl %dl,%edx
c0026376:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026379:	8d 1c 53             	lea    (%ebx,%edx,2),%ebx
  time += hour * 60 * 60;
c002637c:	69 db 10 0e 00 00    	imul   $0xe10,%ebx,%ebx
  return (x & 0x0f) + ((x >> 4) * 10);
c0026382:	0f b6 14 24          	movzbl (%esp),%edx
c0026386:	89 d6                	mov    %edx,%esi
c0026388:	83 e6 0f             	and    $0xf,%esi
c002638b:	c0 ea 04             	shr    $0x4,%dl
c002638e:	0f b6 d2             	movzbl %dl,%edx
c0026391:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026394:	8d 14 56             	lea    (%esi,%edx,2),%edx
  time += min * 60;
c0026397:	6b d2 3c             	imul   $0x3c,%edx,%edx
  time += (mday - 1) * 24 * 60 * 60;
c002639a:	01 da                	add    %ebx,%edx
  time += hour * 60 * 60;
c002639c:	01 d1                	add    %edx,%ecx
  return (x & 0x0f) + ((x >> 4) * 10);
c002639e:	0f b6 54 24 02       	movzbl 0x2(%esp),%edx
c00263a3:	89 d3                	mov    %edx,%ebx
c00263a5:	83 e3 0f             	and    $0xf,%ebx
c00263a8:	c0 ea 04             	shr    $0x4,%dl
c00263ab:	0f b6 d2             	movzbl %dl,%edx
c00263ae:	8d 14 92             	lea    (%edx,%edx,4),%edx
  time += (mday - 1) * 24 * 60 * 60;
c00263b1:	8d 54 53 ff          	lea    -0x1(%ebx,%edx,2),%edx
c00263b5:	69 d2 80 51 01 00    	imul   $0x15180,%edx,%edx
  time += min * 60;
c00263bb:	01 d1                	add    %edx,%ecx
  time += sec;
c00263bd:	01 c8                	add    %ecx,%eax
}
c00263bf:	83 c4 03             	add    $0x3,%esp
c00263c2:	5b                   	pop    %ebx
c00263c3:	5e                   	pop    %esi
c00263c4:	5f                   	pop    %edi
c00263c5:	5d                   	pop    %ebp
c00263c6:	c3                   	ret    
c00263c7:	90                   	nop
c00263c8:	90                   	nop
c00263c9:	90                   	nop
c00263ca:	90                   	nop
c00263cb:	90                   	nop
c00263cc:	90                   	nop
c00263cd:	90                   	nop
c00263ce:	90                   	nop
c00263cf:	90                   	nop

c00263d0 <shutdown_configure>:
/* Sets TYPE as the way that machine will shut down when Pintos
   execution is complete. */
void
shutdown_configure (enum shutdown_type type)
{
  how = type;
c00263d0:	8b 44 24 04          	mov    0x4(%esp),%eax
c00263d4:	a3 94 79 03 c0       	mov    %eax,0xc0037994
c00263d9:	c3                   	ret    

c00263da <shutdown_reboot>:
}

/* Reboots the machine via the keyboard controller. */
void
shutdown_reboot (void)
{
c00263da:	56                   	push   %esi
c00263db:	53                   	push   %ebx
c00263dc:	83 ec 14             	sub    $0x14,%esp
  printf ("Rebooting...\n");
c00263df:	c7 04 24 db f7 02 c0 	movl   $0xc002f7db,(%esp)
c00263e6:	e8 00 43 00 00       	call   c002a6eb <puts>
    {
      int i;

      /* Poll keyboard controller's status byte until
       * 'input buffer empty' is reported. */
      for (i = 0; i < 0x10000; i++)
c00263eb:	bb 00 00 00 00       	mov    $0x0,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00263f0:	be fe ff ff ff       	mov    $0xfffffffe,%esi
c00263f5:	eb 1d                	jmp    c0026414 <shutdown_reboot+0x3a>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00263f7:	e4 64                	in     $0x64,%al
        {
          if ((inb (CONTROL_REG) & 0x02) == 0)
c00263f9:	a8 02                	test   $0x2,%al
c00263fb:	74 1f                	je     c002641c <shutdown_reboot+0x42>
            break;
          timer_udelay (2);
c00263fd:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c0026404:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002640b:	00 
c002640c:	e8 2a e0 ff ff       	call   c002443b <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c0026411:	83 c3 01             	add    $0x1,%ebx
c0026414:	81 fb ff ff 00 00    	cmp    $0xffff,%ebx
c002641a:	7e db                	jle    c00263f7 <shutdown_reboot+0x1d>
        }

      timer_udelay (50);
c002641c:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c0026423:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002642a:	00 
c002642b:	e8 0b e0 ff ff       	call   c002443b <timer_udelay>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026430:	89 f0                	mov    %esi,%eax
c0026432:	e6 64                	out    %al,$0x64

      /* Pulse bit 0 of the output port P2 of the keyboard controller.
       * This will reset the CPU. */
      outb (CONTROL_REG, 0xfe);
      timer_udelay (50);
c0026434:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c002643b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026442:	00 
c0026443:	e8 f3 df ff ff       	call   c002443b <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c0026448:	bb 00 00 00 00       	mov    $0x0,%ebx
    }
c002644d:	eb c5                	jmp    c0026414 <shutdown_reboot+0x3a>

c002644f <shutdown_power_off>:

/* Powers down the machine we're running on,
   as long as we're running on Bochs or QEMU. */
void
shutdown_power_off (void)
{
c002644f:	83 ec 2c             	sub    $0x2c,%esp
  const char s[] = "Shutdown";
c0026452:	c7 44 24 17 53 68 75 	movl   $0x74756853,0x17(%esp)
c0026459:	74 
c002645a:	c7 44 24 1b 64 6f 77 	movl   $0x6e776f64,0x1b(%esp)
c0026461:	6e 
c0026462:	c6 44 24 1f 00       	movb   $0x0,0x1f(%esp)

/* Print statistics about Pintos execution. */
static void
print_stats (void)
{
  timer_print_stats ();
c0026467:	e8 01 e0 ff ff       	call   c002446d <timer_print_stats>
  thread_print_stats ();
c002646c:	e8 9a a8 ff ff       	call   c0020d0b <thread_print_stats>
#ifdef FILESYS
  block_print_stats ();
#endif
  console_print_stats ();
c0026471:	e8 0e 42 00 00       	call   c002a684 <console_print_stats>
  kbd_print_stats ();
c0026476:	e8 33 e2 ff ff       	call   c00246ae <kbd_print_stats>
  printf ("Powering off...\n");
c002647b:	c7 04 24 e8 f7 02 c0 	movl   $0xc002f7e8,(%esp)
c0026482:	e8 64 42 00 00       	call   c002a6eb <puts>
  serial_flush ();
c0026487:	e8 50 e7 ff ff       	call   c0024bdc <serial_flush>
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c002648c:	ba 04 b0 ff ff       	mov    $0xffffb004,%edx
c0026491:	b8 00 20 00 00       	mov    $0x2000,%eax
c0026496:	66 ef                	out    %ax,(%dx)
  for (p = s; *p != '\0'; p++)
c0026498:	0f b6 44 24 17       	movzbl 0x17(%esp),%eax
c002649d:	84 c0                	test   %al,%al
c002649f:	74 14                	je     c00264b5 <shutdown_power_off+0x66>
c00264a1:	8d 4c 24 17          	lea    0x17(%esp),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00264a5:	ba 00 89 ff ff       	mov    $0xffff8900,%edx
c00264aa:	ee                   	out    %al,(%dx)
c00264ab:	83 c1 01             	add    $0x1,%ecx
c00264ae:	0f b6 01             	movzbl (%ecx),%eax
c00264b1:	84 c0                	test   %al,%al
c00264b3:	75 f5                	jne    c00264aa <shutdown_power_off+0x5b>
c00264b5:	ba 01 05 00 00       	mov    $0x501,%edx
c00264ba:	b8 31 00 00 00       	mov    $0x31,%eax
c00264bf:	ee                   	out    %al,(%dx)
  asm volatile ("cli; hlt" : : : "memory");
c00264c0:	fa                   	cli    
c00264c1:	f4                   	hlt    
  printf ("still running...\n");
c00264c2:	c7 04 24 f8 f7 02 c0 	movl   $0xc002f7f8,(%esp)
c00264c9:	e8 1d 42 00 00       	call   c002a6eb <puts>
c00264ce:	eb fe                	jmp    c00264ce <shutdown_power_off+0x7f>

c00264d0 <shutdown>:
{
c00264d0:	83 ec 0c             	sub    $0xc,%esp
  switch (how)
c00264d3:	a1 94 79 03 c0       	mov    0xc0037994,%eax
c00264d8:	83 f8 01             	cmp    $0x1,%eax
c00264db:	74 07                	je     c00264e4 <shutdown+0x14>
c00264dd:	83 f8 02             	cmp    $0x2,%eax
c00264e0:	74 07                	je     c00264e9 <shutdown+0x19>
c00264e2:	eb 11                	jmp    c00264f5 <shutdown+0x25>
      shutdown_power_off ();
c00264e4:	e8 66 ff ff ff       	call   c002644f <shutdown_power_off>
c00264e9:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
      shutdown_reboot ();
c00264f0:	e8 e5 fe ff ff       	call   c00263da <shutdown_reboot>
}
c00264f5:	83 c4 0c             	add    $0xc,%esp
c00264f8:	c3                   	ret    
c00264f9:	90                   	nop
c00264fa:	90                   	nop
c00264fb:	90                   	nop
c00264fc:	90                   	nop
c00264fd:	90                   	nop
c00264fe:	90                   	nop
c00264ff:	90                   	nop

c0026500 <speaker_off>:

/* Turn off the PC speaker, by disconnecting the timer channel's
   output from the speaker. */
void
speaker_off (void)
{
c0026500:	83 ec 1c             	sub    $0x1c,%esp
  enum intr_level old_level = intr_disable ();
c0026503:	e8 07 b5 ff ff       	call   c0021a0f <intr_disable>
c0026508:	89 c2                	mov    %eax,%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002650a:	e4 61                	in     $0x61,%al
  outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) & ~SPEAKER_GATE_ENABLE);
c002650c:	83 e0 fc             	and    $0xfffffffc,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002650f:	e6 61                	out    %al,$0x61
  intr_set_level (old_level);
c0026511:	89 14 24             	mov    %edx,(%esp)
c0026514:	e8 fd b4 ff ff       	call   c0021a16 <intr_set_level>
}
c0026519:	83 c4 1c             	add    $0x1c,%esp
c002651c:	c3                   	ret    

c002651d <speaker_on>:
{
c002651d:	56                   	push   %esi
c002651e:	53                   	push   %ebx
c002651f:	83 ec 14             	sub    $0x14,%esp
c0026522:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (frequency >= 20 && frequency <= 20000)
c0026526:	8d 43 ec             	lea    -0x14(%ebx),%eax
c0026529:	3d 0c 4e 00 00       	cmp    $0x4e0c,%eax
c002652e:	77 30                	ja     c0026560 <speaker_on+0x43>
      enum intr_level old_level = intr_disable ();
c0026530:	e8 da b4 ff ff       	call   c0021a0f <intr_disable>
c0026535:	89 c6                	mov    %eax,%esi
      pit_configure_channel (2, 3, frequency);
c0026537:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002653b:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c0026542:	00 
c0026543:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c002654a:	e8 10 d8 ff ff       	call   c0023d5f <pit_configure_channel>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002654f:	e4 61                	in     $0x61,%al
      outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) | SPEAKER_GATE_ENABLE);
c0026551:	83 c8 03             	or     $0x3,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026554:	e6 61                	out    %al,$0x61
      intr_set_level (old_level);
c0026556:	89 34 24             	mov    %esi,(%esp)
c0026559:	e8 b8 b4 ff ff       	call   c0021a16 <intr_set_level>
c002655e:	eb 05                	jmp    c0026565 <speaker_on+0x48>
      speaker_off ();
c0026560:	e8 9b ff ff ff       	call   c0026500 <speaker_off>
}
c0026565:	83 c4 14             	add    $0x14,%esp
c0026568:	5b                   	pop    %ebx
c0026569:	5e                   	pop    %esi
c002656a:	c3                   	ret    

c002656b <speaker_beep>:

/* Briefly beep the PC speaker. */
void
speaker_beep (void)
{
c002656b:	83 ec 1c             	sub    $0x1c,%esp

     We can't just enable interrupts while we sleep.  For one
     thing, we get called (indirectly) from printf, which should
     always work, even during boot before we're ready to enable
     interrupts. */
  if (intr_get_level () == INTR_ON)
c002656e:	e8 51 b4 ff ff       	call   c00219c4 <intr_get_level>
c0026573:	83 f8 01             	cmp    $0x1,%eax
c0026576:	75 25                	jne    c002659d <speaker_beep+0x32>
    {
      speaker_on (440);
c0026578:	c7 04 24 b8 01 00 00 	movl   $0x1b8,(%esp)
c002657f:	e8 99 ff ff ff       	call   c002651d <speaker_on>
      timer_msleep (250);
c0026584:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002658b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026592:	00 
c0026593:	e8 3f de ff ff       	call   c00243d7 <timer_msleep>
      speaker_off ();
c0026598:	e8 63 ff ff ff       	call   c0026500 <speaker_off>
    }
}
c002659d:	83 c4 1c             	add    $0x1c,%esp
c00265a0:	c3                   	ret    

c00265a1 <debug_backtrace>:
   each of the functions we are nested within.  gdb or addr2line
   may be applied to kernel.o to translate these into file names,
   line numbers, and function names.  */
void
debug_backtrace (void) 
{
c00265a1:	55                   	push   %ebp
c00265a2:	89 e5                	mov    %esp,%ebp
c00265a4:	53                   	push   %ebx
c00265a5:	83 ec 14             	sub    $0x14,%esp
  static bool explained;
  void **frame;
  
  printf ("Call stack: %p", __builtin_return_address (0));
c00265a8:	8b 45 04             	mov    0x4(%ebp),%eax
c00265ab:	89 44 24 04          	mov    %eax,0x4(%esp)
c00265af:	c7 04 24 09 f8 02 c0 	movl   $0xc002f809,(%esp)
c00265b6:	e8 b3 05 00 00       	call   c0026b6e <printf>
  for (frame = __builtin_frame_address (1);
c00265bb:	8b 5d 00             	mov    0x0(%ebp),%ebx
c00265be:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00265c4:	76 27                	jbe    c00265ed <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c00265c6:	83 3b 00             	cmpl   $0x0,(%ebx)
c00265c9:	74 22                	je     c00265ed <debug_backtrace+0x4c>
       frame = frame[0]) 
    printf (" %p", frame[1]);
c00265cb:	8b 43 04             	mov    0x4(%ebx),%eax
c00265ce:	89 44 24 04          	mov    %eax,0x4(%esp)
c00265d2:	c7 04 24 14 f8 02 c0 	movl   $0xc002f814,(%esp)
c00265d9:	e8 90 05 00 00       	call   c0026b6e <printf>
       frame = frame[0]) 
c00265de:	8b 1b                	mov    (%ebx),%ebx
  for (frame = __builtin_frame_address (1);
c00265e0:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00265e6:	76 05                	jbe    c00265ed <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c00265e8:	83 3b 00             	cmpl   $0x0,(%ebx)
c00265eb:	75 de                	jne    c00265cb <debug_backtrace+0x2a>
  printf (".\n");
c00265ed:	c7 04 24 ab f3 02 c0 	movl   $0xc002f3ab,(%esp)
c00265f4:	e8 f2 40 00 00       	call   c002a6eb <puts>

  if (!explained) 
c00265f9:	80 3d 98 79 03 c0 00 	cmpb   $0x0,0xc0037998
c0026600:	75 13                	jne    c0026615 <debug_backtrace+0x74>
    {
      explained = true;
c0026602:	c6 05 98 79 03 c0 01 	movb   $0x1,0xc0037998
      printf ("The `backtrace' program can make call stacks useful.\n"
c0026609:	c7 04 24 18 f8 02 c0 	movl   $0xc002f818,(%esp)
c0026610:	e8 d6 40 00 00       	call   c002a6eb <puts>
              "Read \"Backtraces\" in the \"Debugging Tools\" chapter\n"
              "of the Pintos documentation for more information.\n");
    }
}
c0026615:	83 c4 14             	add    $0x14,%esp
c0026618:	5b                   	pop    %ebx
c0026619:	5d                   	pop    %ebp
c002661a:	c3                   	ret    

c002661b <random_init>:
{
  uint8_t *seedp = (uint8_t *) &seed;
  int i;
  uint8_t j;

  for (i = 0; i < 256; i++) 
c002661b:	b8 00 00 00 00       	mov    $0x0,%eax
    s[i] = i;
c0026620:	88 80 c0 79 03 c0    	mov    %al,-0x3ffc8640(%eax)
  for (i = 0; i < 256; i++) 
c0026626:	83 c0 01             	add    $0x1,%eax
c0026629:	3d 00 01 00 00       	cmp    $0x100,%eax
c002662e:	75 f0                	jne    c0026620 <random_init+0x5>
{
c0026630:	56                   	push   %esi
c0026631:	53                   	push   %ebx
  for (i = 0; i < 256; i++) 
c0026632:	be 00 00 00 00       	mov    $0x0,%esi
c0026637:	66 b8 00 00          	mov    $0x0,%ax
  for (i = j = 0; i < 256; i++) 
    {
      j += s[i] + seedp[i % sizeof seed];
c002663b:	89 c1                	mov    %eax,%ecx
c002663d:	83 e1 03             	and    $0x3,%ecx
c0026640:	0f b6 98 c0 79 03 c0 	movzbl -0x3ffc8640(%eax),%ebx
c0026647:	89 da                	mov    %ebx,%edx
c0026649:	02 54 0c 0c          	add    0xc(%esp,%ecx,1),%dl
c002664d:	89 d1                	mov    %edx,%ecx
c002664f:	01 ce                	add    %ecx,%esi
      swap_byte (s + i, s + j);
c0026651:	89 f2                	mov    %esi,%edx
c0026653:	0f b6 ca             	movzbl %dl,%ecx
  *a = *b;
c0026656:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c002665d:	88 90 c0 79 03 c0    	mov    %dl,-0x3ffc8640(%eax)
  *b = t;
c0026663:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)
  for (i = j = 0; i < 256; i++) 
c0026669:	83 c0 01             	add    $0x1,%eax
c002666c:	3d 00 01 00 00       	cmp    $0x100,%eax
c0026671:	75 c8                	jne    c002663b <random_init+0x20>
    }

  s_i = s_j = 0;
c0026673:	c6 05 a1 79 03 c0 00 	movb   $0x0,0xc00379a1
c002667a:	c6 05 a2 79 03 c0 00 	movb   $0x0,0xc00379a2
  inited = true;
c0026681:	c6 05 a0 79 03 c0 01 	movb   $0x1,0xc00379a0
}
c0026688:	5b                   	pop    %ebx
c0026689:	5e                   	pop    %esi
c002668a:	c3                   	ret    

c002668b <random_bytes>:

/* Writes SIZE random bytes into BUF. */
void
random_bytes (void *buf_, size_t size) 
{
c002668b:	55                   	push   %ebp
c002668c:	57                   	push   %edi
c002668d:	56                   	push   %esi
c002668e:	53                   	push   %ebx
c002668f:	83 ec 0c             	sub    $0xc,%esp
  uint8_t *buf;

  if (!inited)
c0026692:	80 3d a0 79 03 c0 00 	cmpb   $0x0,0xc00379a0
c0026699:	75 0c                	jne    c00266a7 <random_bytes+0x1c>
    random_init (0);
c002669b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c00266a2:	e8 74 ff ff ff       	call   c002661b <random_init>

  for (buf = buf_; size-- > 0; buf++)
c00266a7:	8b 44 24 24          	mov    0x24(%esp),%eax
c00266ab:	83 e8 01             	sub    $0x1,%eax
c00266ae:	89 44 24 08          	mov    %eax,0x8(%esp)
c00266b2:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c00266b7:	0f 84 87 00 00 00    	je     c0026744 <random_bytes+0xb9>
c00266bd:	0f b6 1d a1 79 03 c0 	movzbl 0xc00379a1,%ebx
c00266c4:	b8 00 00 00 00       	mov    $0x0,%eax
c00266c9:	0f b6 35 a2 79 03 c0 	movzbl 0xc00379a2,%esi
c00266d0:	83 c6 01             	add    $0x1,%esi
c00266d3:	89 f5                	mov    %esi,%ebp
c00266d5:	8d 14 06             	lea    (%esi,%eax,1),%edx
    {
      uint8_t s_k;
      
      s_i++;
      s_j += s[s_i];
c00266d8:	0f b6 d2             	movzbl %dl,%edx
c00266db:	02 9a c0 79 03 c0    	add    -0x3ffc8640(%edx),%bl
c00266e1:	88 5c 24 07          	mov    %bl,0x7(%esp)
      swap_byte (s + s_i, s + s_j);
c00266e5:	0f b6 cb             	movzbl %bl,%ecx
  uint8_t t = *a;
c00266e8:	0f b6 ba c0 79 03 c0 	movzbl -0x3ffc8640(%edx),%edi
  *a = *b;
c00266ef:	0f b6 99 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%ebx
c00266f6:	88 9a c0 79 03 c0    	mov    %bl,-0x3ffc8640(%edx)
  *b = t;
c00266fc:	89 fb                	mov    %edi,%ebx
c00266fe:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)

      s_k = s[s_i] + s[s_j];
c0026704:	89 f9                	mov    %edi,%ecx
c0026706:	02 8a c0 79 03 c0    	add    -0x3ffc8640(%edx),%cl
      *buf = s[s_k];
c002670c:	0f b6 c9             	movzbl %cl,%ecx
c002670f:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c0026716:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002671a:	88 14 07             	mov    %dl,(%edi,%eax,1)
c002671d:	83 c0 01             	add    $0x1,%eax
  for (buf = buf_; size-- > 0; buf++)
c0026720:	3b 44 24 24          	cmp    0x24(%esp),%eax
c0026724:	74 07                	je     c002672d <random_bytes+0xa2>
      s_j += s[s_i];
c0026726:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c002672b:	eb a6                	jmp    c00266d3 <random_bytes+0x48>
c002672d:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c0026732:	0f b6 44 24 08       	movzbl 0x8(%esp),%eax
c0026737:	01 e8                	add    %ebp,%eax
c0026739:	a2 a2 79 03 c0       	mov    %al,0xc00379a2
c002673e:	88 1d a1 79 03 c0    	mov    %bl,0xc00379a1
    }
}
c0026744:	83 c4 0c             	add    $0xc,%esp
c0026747:	5b                   	pop    %ebx
c0026748:	5e                   	pop    %esi
c0026749:	5f                   	pop    %edi
c002674a:	5d                   	pop    %ebp
c002674b:	c3                   	ret    

c002674c <random_ulong>:
/* Returns a pseudo-random unsigned long.
   Use random_ulong() % n to obtain a random number in the range
   0...n (exclusive). */
unsigned long
random_ulong (void) 
{
c002674c:	83 ec 18             	sub    $0x18,%esp
  unsigned long ul;
  random_bytes (&ul, sizeof ul);
c002674f:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c0026756:	00 
c0026757:	8d 44 24 14          	lea    0x14(%esp),%eax
c002675b:	89 04 24             	mov    %eax,(%esp)
c002675e:	e8 28 ff ff ff       	call   c002668b <random_bytes>
  return ul;
}
c0026763:	8b 44 24 14          	mov    0x14(%esp),%eax
c0026767:	83 c4 18             	add    $0x18,%esp
c002676a:	c3                   	ret    
c002676b:	90                   	nop
c002676c:	90                   	nop
c002676d:	90                   	nop
c002676e:	90                   	nop
c002676f:	90                   	nop

c0026770 <vsnprintf_helper>:
}

/* Helper function for vsnprintf(). */
static void
vsnprintf_helper (char ch, void *aux_)
{
c0026770:	53                   	push   %ebx
c0026771:	8b 5c 24 08          	mov    0x8(%esp),%ebx
c0026775:	8b 44 24 0c          	mov    0xc(%esp),%eax
  struct vsnprintf_aux *aux = aux_;

  if (aux->length++ < aux->max_length)
c0026779:	8b 50 04             	mov    0x4(%eax),%edx
c002677c:	8d 4a 01             	lea    0x1(%edx),%ecx
c002677f:	89 48 04             	mov    %ecx,0x4(%eax)
c0026782:	3b 50 08             	cmp    0x8(%eax),%edx
c0026785:	7d 09                	jge    c0026790 <vsnprintf_helper+0x20>
    *aux->p++ = ch;
c0026787:	8b 10                	mov    (%eax),%edx
c0026789:	8d 4a 01             	lea    0x1(%edx),%ecx
c002678c:	89 08                	mov    %ecx,(%eax)
c002678e:	88 1a                	mov    %bl,(%edx)
}
c0026790:	5b                   	pop    %ebx
c0026791:	c3                   	ret    

c0026792 <output_dup>:
}

/* Writes CH to OUTPUT with auxiliary data AUX, CNT times. */
static void
output_dup (char ch, size_t cnt, void (*output) (char, void *), void *aux) 
{
c0026792:	55                   	push   %ebp
c0026793:	57                   	push   %edi
c0026794:	56                   	push   %esi
c0026795:	53                   	push   %ebx
c0026796:	83 ec 1c             	sub    $0x1c,%esp
c0026799:	8b 7c 24 30          	mov    0x30(%esp),%edi
  while (cnt-- > 0)
c002679d:	85 d2                	test   %edx,%edx
c002679f:	74 15                	je     c00267b6 <output_dup+0x24>
c00267a1:	89 ce                	mov    %ecx,%esi
c00267a3:	89 d3                	mov    %edx,%ebx
    output (ch, aux);
c00267a5:	0f be e8             	movsbl %al,%ebp
c00267a8:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00267ac:	89 2c 24             	mov    %ebp,(%esp)
c00267af:	ff d6                	call   *%esi
  while (cnt-- > 0)
c00267b1:	83 eb 01             	sub    $0x1,%ebx
c00267b4:	75 f2                	jne    c00267a8 <output_dup+0x16>
}
c00267b6:	83 c4 1c             	add    $0x1c,%esp
c00267b9:	5b                   	pop    %ebx
c00267ba:	5e                   	pop    %esi
c00267bb:	5f                   	pop    %edi
c00267bc:	5d                   	pop    %ebp
c00267bd:	c3                   	ret    

c00267be <format_integer>:
{
c00267be:	55                   	push   %ebp
c00267bf:	57                   	push   %edi
c00267c0:	56                   	push   %esi
c00267c1:	53                   	push   %ebx
c00267c2:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c00267c8:	89 c6                	mov    %eax,%esi
c00267ca:	89 d7                	mov    %edx,%edi
c00267cc:	8b 84 24 a0 00 00 00 	mov    0xa0(%esp),%eax
  sign = 0;
c00267d3:	c7 44 24 30 00 00 00 	movl   $0x0,0x30(%esp)
c00267da:	00 
  if (is_signed) 
c00267db:	84 c9                	test   %cl,%cl
c00267dd:	74 4c                	je     c002682b <format_integer+0x6d>
      if (c->flags & PLUS)
c00267df:	8b 8c 24 a8 00 00 00 	mov    0xa8(%esp),%ecx
c00267e6:	8b 11                	mov    (%ecx),%edx
c00267e8:	f6 c2 02             	test   $0x2,%dl
c00267eb:	74 14                	je     c0026801 <format_integer+0x43>
        sign = negative ? '-' : '+';
c00267ed:	3c 01                	cmp    $0x1,%al
c00267ef:	19 c0                	sbb    %eax,%eax
c00267f1:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267f5:	83 64 24 30 fe       	andl   $0xfffffffe,0x30(%esp)
c00267fa:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c00267ff:	eb 2a                	jmp    c002682b <format_integer+0x6d>
      else if (c->flags & SPACE)
c0026801:	f6 c2 04             	test   $0x4,%dl
c0026804:	74 14                	je     c002681a <format_integer+0x5c>
        sign = negative ? '-' : ' ';
c0026806:	3c 01                	cmp    $0x1,%al
c0026808:	19 c0                	sbb    %eax,%eax
c002680a:	89 44 24 30          	mov    %eax,0x30(%esp)
c002680e:	83 64 24 30 f3       	andl   $0xfffffff3,0x30(%esp)
c0026813:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c0026818:	eb 11                	jmp    c002682b <format_integer+0x6d>
  sign = 0;
c002681a:	3c 01                	cmp    $0x1,%al
c002681c:	19 c0                	sbb    %eax,%eax
c002681e:	89 44 24 30          	mov    %eax,0x30(%esp)
c0026822:	f7 54 24 30          	notl   0x30(%esp)
c0026826:	83 64 24 30 2d       	andl   $0x2d,0x30(%esp)
  x = (c->flags & POUND) && value ? b->x : 0;
c002682b:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026832:	8b 00                	mov    (%eax),%eax
c0026834:	89 44 24 38          	mov    %eax,0x38(%esp)
c0026838:	83 e0 08             	and    $0x8,%eax
c002683b:	89 44 24 3c          	mov    %eax,0x3c(%esp)
c002683f:	74 5c                	je     c002689d <format_integer+0xdf>
c0026841:	89 f8                	mov    %edi,%eax
c0026843:	09 f0                	or     %esi,%eax
c0026845:	0f 84 e9 00 00 00    	je     c0026934 <format_integer+0x176>
c002684b:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026852:	8b 40 08             	mov    0x8(%eax),%eax
c0026855:	89 44 24 34          	mov    %eax,0x34(%esp)
c0026859:	eb 08                	jmp    c0026863 <format_integer+0xa5>
c002685b:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c0026862:	00 
      *cp++ = b->digits[value % b->base];
c0026863:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c002686a:	8b 40 04             	mov    0x4(%eax),%eax
c002686d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026871:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026878:	8b 00                	mov    (%eax),%eax
c002687a:	89 44 24 18          	mov    %eax,0x18(%esp)
c002687e:	89 c1                	mov    %eax,%ecx
c0026880:	c1 f9 1f             	sar    $0x1f,%ecx
c0026883:	89 4c 24 1c          	mov    %ecx,0x1c(%esp)
c0026887:	bb 00 00 00 00       	mov    $0x0,%ebx
c002688c:	8d 6c 24 40          	lea    0x40(%esp),%ebp
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026890:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026894:	83 e0 20             	and    $0x20,%eax
c0026897:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c002689b:	eb 17                	jmp    c00268b4 <format_integer+0xf6>
  while (value > 0) 
c002689d:	89 f8                	mov    %edi,%eax
c002689f:	09 f0                	or     %esi,%eax
c00268a1:	75 b8                	jne    c002685b <format_integer+0x9d>
  x = (c->flags & POUND) && value ? b->x : 0;
c00268a3:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c00268aa:	00 
  cp = buf;
c00268ab:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c00268af:	e9 92 00 00 00       	jmp    c0026946 <format_integer+0x188>
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c00268b4:	83 7c 24 2c 00       	cmpl   $0x0,0x2c(%esp)
c00268b9:	74 1c                	je     c00268d7 <format_integer+0x119>
c00268bb:	85 db                	test   %ebx,%ebx
c00268bd:	7e 18                	jle    c00268d7 <format_integer+0x119>
c00268bf:	8b 8c 24 a4 00 00 00 	mov    0xa4(%esp),%ecx
c00268c6:	89 d8                	mov    %ebx,%eax
c00268c8:	99                   	cltd   
c00268c9:	f7 79 0c             	idivl  0xc(%ecx)
c00268cc:	85 d2                	test   %edx,%edx
c00268ce:	75 07                	jne    c00268d7 <format_integer+0x119>
        *cp++ = ',';
c00268d0:	c6 45 00 2c          	movb   $0x2c,0x0(%ebp)
c00268d4:	8d 6d 01             	lea    0x1(%ebp),%ebp
      *cp++ = b->digits[value % b->base];
c00268d7:	8d 45 01             	lea    0x1(%ebp),%eax
c00268da:	89 44 24 24          	mov    %eax,0x24(%esp)
c00268de:	8b 44 24 18          	mov    0x18(%esp),%eax
c00268e2:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00268e6:	89 44 24 08          	mov    %eax,0x8(%esp)
c00268ea:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00268ee:	89 34 24             	mov    %esi,(%esp)
c00268f1:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00268f5:	e8 a0 1a 00 00       	call   c002839a <__umoddi3>
c00268fa:	8b 4c 24 28          	mov    0x28(%esp),%ecx
c00268fe:	0f b6 04 01          	movzbl (%ecx,%eax,1),%eax
c0026902:	88 45 00             	mov    %al,0x0(%ebp)
      value /= b->base;
c0026905:	8b 44 24 18          	mov    0x18(%esp),%eax
c0026909:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002690d:	89 44 24 08          	mov    %eax,0x8(%esp)
c0026911:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0026915:	89 34 24             	mov    %esi,(%esp)
c0026918:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002691c:	e8 56 1a 00 00       	call   c0028377 <__udivdi3>
c0026921:	89 c6                	mov    %eax,%esi
c0026923:	89 d7                	mov    %edx,%edi
      digit_cnt++;
c0026925:	83 c3 01             	add    $0x1,%ebx
  while (value > 0) 
c0026928:	89 d1                	mov    %edx,%ecx
c002692a:	09 c1                	or     %eax,%ecx
c002692c:	74 14                	je     c0026942 <format_integer+0x184>
      *cp++ = b->digits[value % b->base];
c002692e:	8b 6c 24 24          	mov    0x24(%esp),%ebp
c0026932:	eb 80                	jmp    c00268b4 <format_integer+0xf6>
  x = (c->flags & POUND) && value ? b->x : 0;
c0026934:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c002693b:	00 
  cp = buf;
c002693c:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c0026940:	eb 04                	jmp    c0026946 <format_integer+0x188>
c0026942:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  precision = c->precision < 0 ? 1 : c->precision;
c0026946:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c002694d:	8b 50 08             	mov    0x8(%eax),%edx
c0026950:	85 d2                	test   %edx,%edx
c0026952:	b8 01 00 00 00       	mov    $0x1,%eax
c0026957:	0f 48 d0             	cmovs  %eax,%edx
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002695a:	8d 7c 24 40          	lea    0x40(%esp),%edi
c002695e:	89 d8                	mov    %ebx,%eax
c0026960:	29 f8                	sub    %edi,%eax
c0026962:	39 c2                	cmp    %eax,%edx
c0026964:	7e 1f                	jle    c0026985 <format_integer+0x1c7>
c0026966:	8d 44 24 7f          	lea    0x7f(%esp),%eax
c002696a:	39 c3                	cmp    %eax,%ebx
c002696c:	73 17                	jae    c0026985 <format_integer+0x1c7>
c002696e:	89 f9                	mov    %edi,%ecx
c0026970:	89 c6                	mov    %eax,%esi
    *cp++ = '0';
c0026972:	83 c3 01             	add    $0x1,%ebx
c0026975:	c6 43 ff 30          	movb   $0x30,-0x1(%ebx)
c0026979:	89 d8                	mov    %ebx,%eax
c002697b:	29 c8                	sub    %ecx,%eax
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002697d:	39 c2                	cmp    %eax,%edx
c002697f:	7e 04                	jle    c0026985 <format_integer+0x1c7>
c0026981:	39 f3                	cmp    %esi,%ebx
c0026983:	75 ed                	jne    c0026972 <format_integer+0x1b4>
  if ((c->flags & POUND) && b->base == 8 && (cp == buf || cp[-1] != '0'))
c0026985:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002698a:	74 20                	je     c00269ac <format_integer+0x1ee>
c002698c:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026993:	83 38 08             	cmpl   $0x8,(%eax)
c0026996:	75 14                	jne    c00269ac <format_integer+0x1ee>
c0026998:	8d 44 24 40          	lea    0x40(%esp),%eax
c002699c:	39 c3                	cmp    %eax,%ebx
c002699e:	74 06                	je     c00269a6 <format_integer+0x1e8>
c00269a0:	80 7b ff 30          	cmpb   $0x30,-0x1(%ebx)
c00269a4:	74 06                	je     c00269ac <format_integer+0x1ee>
    *cp++ = '0';
c00269a6:	c6 03 30             	movb   $0x30,(%ebx)
c00269a9:	8d 5b 01             	lea    0x1(%ebx),%ebx
  pad_cnt = c->width - (cp - buf) - (x ? 2 : 0) - (sign != 0);
c00269ac:	29 df                	sub    %ebx,%edi
c00269ae:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c00269b5:	03 78 04             	add    0x4(%eax),%edi
c00269b8:	83 7c 24 34 01       	cmpl   $0x1,0x34(%esp)
c00269bd:	19 c0                	sbb    %eax,%eax
c00269bf:	f7 d0                	not    %eax
c00269c1:	83 e0 02             	and    $0x2,%eax
c00269c4:	83 7c 24 30 00       	cmpl   $0x0,0x30(%esp)
c00269c9:	0f 95 c1             	setne  %cl
c00269cc:	89 ce                	mov    %ecx,%esi
c00269ce:	29 c7                	sub    %eax,%edi
c00269d0:	0f b6 c1             	movzbl %cl,%eax
c00269d3:	29 c7                	sub    %eax,%edi
c00269d5:	b8 00 00 00 00       	mov    $0x0,%eax
c00269da:	0f 48 f8             	cmovs  %eax,%edi
  if ((c->flags & (MINUS | ZERO)) == 0)
c00269dd:	f6 44 24 38 11       	testb  $0x11,0x38(%esp)
c00269e2:	75 1d                	jne    c0026a01 <format_integer+0x243>
    output_dup (' ', pad_cnt, output, aux);
c00269e4:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269eb:	89 04 24             	mov    %eax,(%esp)
c00269ee:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c00269f5:	89 fa                	mov    %edi,%edx
c00269f7:	b8 20 00 00 00       	mov    $0x20,%eax
c00269fc:	e8 91 fd ff ff       	call   c0026792 <output_dup>
  if (sign)
c0026a01:	89 f0                	mov    %esi,%eax
c0026a03:	84 c0                	test   %al,%al
c0026a05:	74 19                	je     c0026a20 <format_integer+0x262>
    output (sign, aux);
c0026a07:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a0e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026a12:	8b 44 24 30          	mov    0x30(%esp),%eax
c0026a16:	89 04 24             	mov    %eax,(%esp)
c0026a19:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (x) 
c0026a20:	83 7c 24 34 00       	cmpl   $0x0,0x34(%esp)
c0026a25:	74 33                	je     c0026a5a <format_integer+0x29c>
      output ('0', aux);
c0026a27:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a2e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026a32:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
c0026a39:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
      output (x, aux); 
c0026a40:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a47:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026a4b:	0f be 44 24 34       	movsbl 0x34(%esp),%eax
c0026a50:	89 04 24             	mov    %eax,(%esp)
c0026a53:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (c->flags & ZERO)
c0026a5a:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a61:	f6 00 10             	testb  $0x10,(%eax)
c0026a64:	74 1d                	je     c0026a83 <format_integer+0x2c5>
    output_dup ('0', pad_cnt, output, aux);
c0026a66:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a6d:	89 04 24             	mov    %eax,(%esp)
c0026a70:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a77:	89 fa                	mov    %edi,%edx
c0026a79:	b8 30 00 00 00       	mov    $0x30,%eax
c0026a7e:	e8 0f fd ff ff       	call   c0026792 <output_dup>
  while (cp > buf)
c0026a83:	8d 44 24 40          	lea    0x40(%esp),%eax
c0026a87:	39 c3                	cmp    %eax,%ebx
c0026a89:	76 2b                	jbe    c0026ab6 <format_integer+0x2f8>
c0026a8b:	89 c6                	mov    %eax,%esi
c0026a8d:	89 7c 24 18          	mov    %edi,0x18(%esp)
c0026a91:	8b bc 24 ac 00 00 00 	mov    0xac(%esp),%edi
c0026a98:	8b ac 24 b0 00 00 00 	mov    0xb0(%esp),%ebp
    output (*--cp, aux);
c0026a9f:	83 eb 01             	sub    $0x1,%ebx
c0026aa2:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0026aa6:	0f be 03             	movsbl (%ebx),%eax
c0026aa9:	89 04 24             	mov    %eax,(%esp)
c0026aac:	ff d7                	call   *%edi
  while (cp > buf)
c0026aae:	39 f3                	cmp    %esi,%ebx
c0026ab0:	75 ed                	jne    c0026a9f <format_integer+0x2e1>
c0026ab2:	8b 7c 24 18          	mov    0x18(%esp),%edi
  if (c->flags & MINUS)
c0026ab6:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026abd:	f6 00 01             	testb  $0x1,(%eax)
c0026ac0:	74 1d                	je     c0026adf <format_integer+0x321>
    output_dup (' ', pad_cnt, output, aux);
c0026ac2:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026ac9:	89 04 24             	mov    %eax,(%esp)
c0026acc:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026ad3:	89 fa                	mov    %edi,%edx
c0026ad5:	b8 20 00 00 00       	mov    $0x20,%eax
c0026ada:	e8 b3 fc ff ff       	call   c0026792 <output_dup>
}
c0026adf:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c0026ae5:	5b                   	pop    %ebx
c0026ae6:	5e                   	pop    %esi
c0026ae7:	5f                   	pop    %edi
c0026ae8:	5d                   	pop    %ebp
c0026ae9:	c3                   	ret    

c0026aea <format_string>:
   auxiliary data AUX. */
static void
format_string (const char *string, int length,
               struct printf_conversion *c,
               void (*output) (char, void *), void *aux) 
{
c0026aea:	55                   	push   %ebp
c0026aeb:	57                   	push   %edi
c0026aec:	56                   	push   %esi
c0026aed:	53                   	push   %ebx
c0026aee:	83 ec 1c             	sub    $0x1c,%esp
c0026af1:	89 c5                	mov    %eax,%ebp
c0026af3:	89 d3                	mov    %edx,%ebx
c0026af5:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026af9:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0026afd:	8b 74 24 30          	mov    0x30(%esp),%esi
c0026b01:	8b 7c 24 34          	mov    0x34(%esp),%edi
  int i;
  if (c->width > length && (c->flags & MINUS) == 0)
c0026b05:	8b 51 04             	mov    0x4(%ecx),%edx
c0026b08:	39 da                	cmp    %ebx,%edx
c0026b0a:	7e 16                	jle    c0026b22 <format_string+0x38>
c0026b0c:	f6 01 01             	testb  $0x1,(%ecx)
c0026b0f:	75 11                	jne    c0026b22 <format_string+0x38>
    output_dup (' ', c->width - length, output, aux);
c0026b11:	29 da                	sub    %ebx,%edx
c0026b13:	89 3c 24             	mov    %edi,(%esp)
c0026b16:	89 f1                	mov    %esi,%ecx
c0026b18:	b8 20 00 00 00       	mov    $0x20,%eax
c0026b1d:	e8 70 fc ff ff       	call   c0026792 <output_dup>
  for (i = 0; i < length; i++)
c0026b22:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026b26:	85 c0                	test   %eax,%eax
c0026b28:	7e 17                	jle    c0026b41 <format_string+0x57>
c0026b2a:	89 eb                	mov    %ebp,%ebx
c0026b2c:	01 c5                	add    %eax,%ebp
    output (string[i], aux);
c0026b2e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0026b32:	0f be 03             	movsbl (%ebx),%eax
c0026b35:	89 04 24             	mov    %eax,(%esp)
c0026b38:	ff d6                	call   *%esi
c0026b3a:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < length; i++)
c0026b3d:	39 eb                	cmp    %ebp,%ebx
c0026b3f:	75 ed                	jne    c0026b2e <format_string+0x44>
  if (c->width > length && (c->flags & MINUS) != 0)
c0026b41:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0026b45:	8b 50 04             	mov    0x4(%eax),%edx
c0026b48:	39 54 24 08          	cmp    %edx,0x8(%esp)
c0026b4c:	7d 18                	jge    c0026b66 <format_string+0x7c>
c0026b4e:	f6 00 01             	testb  $0x1,(%eax)
c0026b51:	74 13                	je     c0026b66 <format_string+0x7c>
    output_dup (' ', c->width - length, output, aux);
c0026b53:	2b 54 24 08          	sub    0x8(%esp),%edx
c0026b57:	89 3c 24             	mov    %edi,(%esp)
c0026b5a:	89 f1                	mov    %esi,%ecx
c0026b5c:	b8 20 00 00 00       	mov    $0x20,%eax
c0026b61:	e8 2c fc ff ff       	call   c0026792 <output_dup>
}
c0026b66:	83 c4 1c             	add    $0x1c,%esp
c0026b69:	5b                   	pop    %ebx
c0026b6a:	5e                   	pop    %esi
c0026b6b:	5f                   	pop    %edi
c0026b6c:	5d                   	pop    %ebp
c0026b6d:	c3                   	ret    

c0026b6e <printf>:
{
c0026b6e:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0026b71:	8d 44 24 24          	lea    0x24(%esp),%eax
  retval = vprintf (format, args);
c0026b75:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b79:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b7d:	89 04 24             	mov    %eax,(%esp)
c0026b80:	e8 25 3b 00 00       	call   c002a6aa <vprintf>
}
c0026b85:	83 c4 1c             	add    $0x1c,%esp
c0026b88:	c3                   	ret    

c0026b89 <__printf>:
/* Wrapper for __vprintf() that converts varargs into a
   va_list. */
void
__printf (const char *format,
          void (*output) (char, void *), void *aux, ...) 
{
c0026b89:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;

  va_start (args, aux);
c0026b8c:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  __vprintf (format, args, output, aux);
c0026b90:	8b 54 24 28          	mov    0x28(%esp),%edx
c0026b94:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0026b98:	8b 54 24 24          	mov    0x24(%esp),%edx
c0026b9c:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026ba0:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026ba4:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026ba8:	89 04 24             	mov    %eax,(%esp)
c0026bab:	e8 04 00 00 00       	call   c0026bb4 <__vprintf>
  va_end (args);
}
c0026bb0:	83 c4 1c             	add    $0x1c,%esp
c0026bb3:	c3                   	ret    

c0026bb4 <__vprintf>:
{
c0026bb4:	55                   	push   %ebp
c0026bb5:	57                   	push   %edi
c0026bb6:	56                   	push   %esi
c0026bb7:	53                   	push   %ebx
c0026bb8:	83 ec 5c             	sub    $0x5c,%esp
c0026bbb:	8b 7c 24 70          	mov    0x70(%esp),%edi
c0026bbf:	8b 6c 24 74          	mov    0x74(%esp),%ebp
  for (; *format != '\0'; format++)
c0026bc3:	0f b6 07             	movzbl (%edi),%eax
c0026bc6:	84 c0                	test   %al,%al
c0026bc8:	0f 84 1c 06 00 00    	je     c00271ea <__vprintf+0x636>
      if (*format != '%') 
c0026bce:	3c 25                	cmp    $0x25,%al
c0026bd0:	74 19                	je     c0026beb <__vprintf+0x37>
          output (*format, aux);
c0026bd2:	8b 5c 24 7c          	mov    0x7c(%esp),%ebx
c0026bd6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0026bda:	0f be c0             	movsbl %al,%eax
c0026bdd:	89 04 24             	mov    %eax,(%esp)
c0026be0:	ff 54 24 78          	call   *0x78(%esp)
          continue;
c0026be4:	89 fb                	mov    %edi,%ebx
c0026be6:	e9 d5 05 00 00       	jmp    c00271c0 <__vprintf+0x60c>
      format++;
c0026beb:	8d 77 01             	lea    0x1(%edi),%esi
      if (*format == '%') 
c0026bee:	b9 00 00 00 00       	mov    $0x0,%ecx
c0026bf3:	80 7f 01 25          	cmpb   $0x25,0x1(%edi)
c0026bf7:	75 1c                	jne    c0026c15 <__vprintf+0x61>
          output ('%', aux);
c0026bf9:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0026bfd:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026c01:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
c0026c08:	ff 54 24 78          	call   *0x78(%esp)
      format++;
c0026c0c:	89 f3                	mov    %esi,%ebx
          continue;
c0026c0e:	e9 ad 05 00 00       	jmp    c00271c0 <__vprintf+0x60c>
      switch (*format++) 
c0026c13:	89 d6                	mov    %edx,%esi
c0026c15:	8d 56 01             	lea    0x1(%esi),%edx
c0026c18:	0f b6 5a ff          	movzbl -0x1(%edx),%ebx
c0026c1c:	8d 43 e0             	lea    -0x20(%ebx),%eax
c0026c1f:	3c 10                	cmp    $0x10,%al
c0026c21:	77 29                	ja     c0026c4c <__vprintf+0x98>
c0026c23:	0f b6 c0             	movzbl %al,%eax
c0026c26:	ff 24 85 70 da 02 c0 	jmp    *-0x3ffd2590(,%eax,4)
          c->flags |= MINUS;
c0026c2d:	83 c9 01             	or     $0x1,%ecx
c0026c30:	eb e1                	jmp    c0026c13 <__vprintf+0x5f>
          c->flags |= PLUS;
c0026c32:	83 c9 02             	or     $0x2,%ecx
c0026c35:	eb dc                	jmp    c0026c13 <__vprintf+0x5f>
          c->flags |= SPACE;
c0026c37:	83 c9 04             	or     $0x4,%ecx
c0026c3a:	eb d7                	jmp    c0026c13 <__vprintf+0x5f>
          c->flags |= POUND;
c0026c3c:	83 c9 08             	or     $0x8,%ecx
c0026c3f:	90                   	nop
c0026c40:	eb d1                	jmp    c0026c13 <__vprintf+0x5f>
          c->flags |= ZERO;
c0026c42:	83 c9 10             	or     $0x10,%ecx
c0026c45:	eb cc                	jmp    c0026c13 <__vprintf+0x5f>
          c->flags |= GROUP;
c0026c47:	83 c9 20             	or     $0x20,%ecx
c0026c4a:	eb c7                	jmp    c0026c13 <__vprintf+0x5f>
      switch (*format++) 
c0026c4c:	89 f0                	mov    %esi,%eax
c0026c4e:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & MINUS)
c0026c52:	f6 c1 01             	test   $0x1,%cl
c0026c55:	74 07                	je     c0026c5e <__vprintf+0xaa>
    c->flags &= ~ZERO;
c0026c57:	83 e1 ef             	and    $0xffffffef,%ecx
c0026c5a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & PLUS)
c0026c5e:	8b 4c 24 40          	mov    0x40(%esp),%ecx
c0026c62:	f6 c1 02             	test   $0x2,%cl
c0026c65:	74 07                	je     c0026c6e <__vprintf+0xba>
    c->flags &= ~SPACE;
c0026c67:	83 e1 fb             	and    $0xfffffffb,%ecx
c0026c6a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  c->width = 0;
c0026c6e:	c7 44 24 44 00 00 00 	movl   $0x0,0x44(%esp)
c0026c75:	00 
  if (*format == '*')
c0026c76:	80 fb 2a             	cmp    $0x2a,%bl
c0026c79:	74 15                	je     c0026c90 <__vprintf+0xdc>
      for (; isdigit (*format); format++)
c0026c7b:	0f b6 00             	movzbl (%eax),%eax
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0026c7e:	0f be c8             	movsbl %al,%ecx
c0026c81:	83 e9 30             	sub    $0x30,%ecx
c0026c84:	ba 00 00 00 00       	mov    $0x0,%edx
c0026c89:	83 f9 09             	cmp    $0x9,%ecx
c0026c8c:	76 10                	jbe    c0026c9e <__vprintf+0xea>
c0026c8e:	eb 40                	jmp    c0026cd0 <__vprintf+0x11c>
      c->width = va_arg (*args, int);
c0026c90:	8b 45 00             	mov    0x0(%ebp),%eax
c0026c93:	89 44 24 44          	mov    %eax,0x44(%esp)
c0026c97:	8d 6d 04             	lea    0x4(%ebp),%ebp
      switch (*format++) 
c0026c9a:	89 d6                	mov    %edx,%esi
c0026c9c:	eb 1f                	jmp    c0026cbd <__vprintf+0x109>
        c->width = c->width * 10 + *format - '0';
c0026c9e:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026ca1:	0f be c0             	movsbl %al,%eax
c0026ca4:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
      for (; isdigit (*format); format++)
c0026ca8:	83 c6 01             	add    $0x1,%esi
c0026cab:	0f b6 06             	movzbl (%esi),%eax
c0026cae:	0f be c8             	movsbl %al,%ecx
c0026cb1:	83 e9 30             	sub    $0x30,%ecx
c0026cb4:	83 f9 09             	cmp    $0x9,%ecx
c0026cb7:	76 e5                	jbe    c0026c9e <__vprintf+0xea>
c0026cb9:	89 54 24 44          	mov    %edx,0x44(%esp)
  if (c->width < 0) 
c0026cbd:	8b 44 24 44          	mov    0x44(%esp),%eax
c0026cc1:	85 c0                	test   %eax,%eax
c0026cc3:	79 0b                	jns    c0026cd0 <__vprintf+0x11c>
      c->width = -c->width;
c0026cc5:	f7 d8                	neg    %eax
c0026cc7:	89 44 24 44          	mov    %eax,0x44(%esp)
      c->flags |= MINUS;
c0026ccb:	83 4c 24 40 01       	orl    $0x1,0x40(%esp)
  c->precision = -1;
c0026cd0:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026cd7:	ff 
  if (*format == '.') 
c0026cd8:	80 3e 2e             	cmpb   $0x2e,(%esi)
c0026cdb:	0f 85 f0 04 00 00    	jne    c00271d1 <__vprintf+0x61d>
      if (*format == '*') 
c0026ce1:	80 7e 01 2a          	cmpb   $0x2a,0x1(%esi)
c0026ce5:	75 0f                	jne    c0026cf6 <__vprintf+0x142>
          format++;
c0026ce7:	83 c6 02             	add    $0x2,%esi
          c->precision = va_arg (*args, int);
c0026cea:	8b 45 00             	mov    0x0(%ebp),%eax
c0026ced:	89 44 24 48          	mov    %eax,0x48(%esp)
c0026cf1:	8d 6d 04             	lea    0x4(%ebp),%ebp
c0026cf4:	eb 44                	jmp    c0026d3a <__vprintf+0x186>
      format++;
c0026cf6:	8d 56 01             	lea    0x1(%esi),%edx
          c->precision = 0;
c0026cf9:	c7 44 24 48 00 00 00 	movl   $0x0,0x48(%esp)
c0026d00:	00 
          for (; isdigit (*format); format++)
c0026d01:	0f b6 46 01          	movzbl 0x1(%esi),%eax
c0026d05:	0f be c8             	movsbl %al,%ecx
c0026d08:	83 e9 30             	sub    $0x30,%ecx
c0026d0b:	83 f9 09             	cmp    $0x9,%ecx
c0026d0e:	0f 87 c6 04 00 00    	ja     c00271da <__vprintf+0x626>
c0026d14:	b9 00 00 00 00       	mov    $0x0,%ecx
            c->precision = c->precision * 10 + *format - '0';
c0026d19:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0026d1c:	0f be c0             	movsbl %al,%eax
c0026d1f:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
          for (; isdigit (*format); format++)
c0026d23:	83 c2 01             	add    $0x1,%edx
c0026d26:	0f b6 02             	movzbl (%edx),%eax
c0026d29:	0f be d8             	movsbl %al,%ebx
c0026d2c:	83 eb 30             	sub    $0x30,%ebx
c0026d2f:	83 fb 09             	cmp    $0x9,%ebx
c0026d32:	76 e5                	jbe    c0026d19 <__vprintf+0x165>
c0026d34:	89 4c 24 48          	mov    %ecx,0x48(%esp)
c0026d38:	89 d6                	mov    %edx,%esi
      if (c->precision < 0) 
c0026d3a:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0026d3f:	0f 89 97 04 00 00    	jns    c00271dc <__vprintf+0x628>
        c->precision = -1;
c0026d45:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026d4c:	ff 
c0026d4d:	e9 7f 04 00 00       	jmp    c00271d1 <__vprintf+0x61d>
  c->type = INT;
c0026d52:	c7 44 24 4c 03 00 00 	movl   $0x3,0x4c(%esp)
c0026d59:	00 
  switch (*format++) 
c0026d5a:	8d 5e 01             	lea    0x1(%esi),%ebx
c0026d5d:	0f b6 3e             	movzbl (%esi),%edi
c0026d60:	8d 57 98             	lea    -0x68(%edi),%edx
c0026d63:	80 fa 12             	cmp    $0x12,%dl
c0026d66:	77 62                	ja     c0026dca <__vprintf+0x216>
c0026d68:	0f b6 d2             	movzbl %dl,%edx
c0026d6b:	ff 24 95 b4 da 02 c0 	jmp    *-0x3ffd254c(,%edx,4)
      if (*format == 'h') 
c0026d72:	80 7e 01 68          	cmpb   $0x68,0x1(%esi)
c0026d76:	75 0d                	jne    c0026d85 <__vprintf+0x1d1>
          format++;
c0026d78:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = CHAR;
c0026d7b:	c7 44 24 4c 01 00 00 	movl   $0x1,0x4c(%esp)
c0026d82:	00 
c0026d83:	eb 47                	jmp    c0026dcc <__vprintf+0x218>
        c->type = SHORT;
c0026d85:	c7 44 24 4c 02 00 00 	movl   $0x2,0x4c(%esp)
c0026d8c:	00 
c0026d8d:	eb 3d                	jmp    c0026dcc <__vprintf+0x218>
      c->type = INTMAX;
c0026d8f:	c7 44 24 4c 04 00 00 	movl   $0x4,0x4c(%esp)
c0026d96:	00 
c0026d97:	eb 33                	jmp    c0026dcc <__vprintf+0x218>
      if (*format == 'l')
c0026d99:	80 7e 01 6c          	cmpb   $0x6c,0x1(%esi)
c0026d9d:	75 0d                	jne    c0026dac <__vprintf+0x1f8>
          format++;
c0026d9f:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = LONGLONG;
c0026da2:	c7 44 24 4c 06 00 00 	movl   $0x6,0x4c(%esp)
c0026da9:	00 
c0026daa:	eb 20                	jmp    c0026dcc <__vprintf+0x218>
        c->type = LONG;
c0026dac:	c7 44 24 4c 05 00 00 	movl   $0x5,0x4c(%esp)
c0026db3:	00 
c0026db4:	eb 16                	jmp    c0026dcc <__vprintf+0x218>
      c->type = PTRDIFFT;
c0026db6:	c7 44 24 4c 07 00 00 	movl   $0x7,0x4c(%esp)
c0026dbd:	00 
c0026dbe:	eb 0c                	jmp    c0026dcc <__vprintf+0x218>
      c->type = SIZET;
c0026dc0:	c7 44 24 4c 08 00 00 	movl   $0x8,0x4c(%esp)
c0026dc7:	00 
c0026dc8:	eb 02                	jmp    c0026dcc <__vprintf+0x218>
  switch (*format++) 
c0026dca:	89 f3                	mov    %esi,%ebx
      switch (*format) 
c0026dcc:	0f b6 0b             	movzbl (%ebx),%ecx
c0026dcf:	8d 51 bb             	lea    -0x45(%ecx),%edx
c0026dd2:	80 fa 33             	cmp    $0x33,%dl
c0026dd5:	0f 87 c2 03 00 00    	ja     c002719d <__vprintf+0x5e9>
c0026ddb:	0f b6 d2             	movzbl %dl,%edx
c0026dde:	ff 24 95 00 db 02 c0 	jmp    *-0x3ffd2500(,%edx,4)
            switch (c.type) 
c0026de5:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026dea:	0f 87 c9 00 00 00    	ja     c0026eb9 <__vprintf+0x305>
c0026df0:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026df4:	ff 24 85 d0 db 02 c0 	jmp    *-0x3ffd2430(,%eax,4)
                value = (signed char) va_arg (args, int);
c0026dfb:	0f be 75 00          	movsbl 0x0(%ebp),%esi
c0026dff:	89 f0                	mov    %esi,%eax
c0026e01:	99                   	cltd   
c0026e02:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e06:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e0a:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e0d:	e9 cb 00 00 00       	jmp    c0026edd <__vprintf+0x329>
                value = (short) va_arg (args, int);
c0026e12:	0f bf 75 00          	movswl 0x0(%ebp),%esi
c0026e16:	89 f0                	mov    %esi,%eax
c0026e18:	99                   	cltd   
c0026e19:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e1d:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e21:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e24:	e9 b4 00 00 00       	jmp    c0026edd <__vprintf+0x329>
                value = va_arg (args, int);
c0026e29:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e2c:	89 f0                	mov    %esi,%eax
c0026e2e:	99                   	cltd   
c0026e2f:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e33:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e37:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e3a:	e9 9e 00 00 00       	jmp    c0026edd <__vprintf+0x329>
                value = va_arg (args, intmax_t);
c0026e3f:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e42:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e45:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e49:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e4d:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e50:	e9 88 00 00 00       	jmp    c0026edd <__vprintf+0x329>
                value = va_arg (args, long);
c0026e55:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e58:	89 f0                	mov    %esi,%eax
c0026e5a:	99                   	cltd   
c0026e5b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e5f:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e63:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e66:	eb 75                	jmp    c0026edd <__vprintf+0x329>
                value = va_arg (args, long long);
c0026e68:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e6b:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e6e:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e72:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e76:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e79:	eb 62                	jmp    c0026edd <__vprintf+0x329>
                value = va_arg (args, ptrdiff_t);
c0026e7b:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e7e:	89 f0                	mov    %esi,%eax
c0026e80:	99                   	cltd   
c0026e81:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e85:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e89:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e8c:	eb 4f                	jmp    c0026edd <__vprintf+0x329>
                value = va_arg (args, size_t);
c0026e8e:	8d 45 04             	lea    0x4(%ebp),%eax
                if (value > SIZE_MAX / 2)
c0026e91:	8b 7d 00             	mov    0x0(%ebp),%edi
c0026e94:	bd 00 00 00 00       	mov    $0x0,%ebp
c0026e99:	89 fe                	mov    %edi,%esi
c0026e9b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e9f:	89 6c 24 1c          	mov    %ebp,0x1c(%esp)
                value = va_arg (args, size_t);
c0026ea3:	89 c5                	mov    %eax,%ebp
                if (value > SIZE_MAX / 2)
c0026ea5:	81 fe ff ff ff 7f    	cmp    $0x7fffffff,%esi
c0026eab:	76 30                	jbe    c0026edd <__vprintf+0x329>
                  value = value - SIZE_MAX - 1;
c0026ead:	83 44 24 18 00       	addl   $0x0,0x18(%esp)
c0026eb2:	83 54 24 1c ff       	adcl   $0xffffffff,0x1c(%esp)
c0026eb7:	eb 24                	jmp    c0026edd <__vprintf+0x329>
                NOT_REACHED ();
c0026eb9:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0026ec0:	c0 
c0026ec1:	c7 44 24 08 18 dc 02 	movl   $0xc002dc18,0x8(%esp)
c0026ec8:	c0 
c0026ec9:	c7 44 24 04 dc 00 00 	movl   $0xdc,0x4(%esp)
c0026ed0:	00 
c0026ed1:	c7 04 24 b9 f8 02 c0 	movl   $0xc002f8b9,(%esp)
c0026ed8:	e8 e6 1a 00 00       	call   c00289c3 <debug_panic>
            format_integer (value < 0 ? -value : value,
c0026edd:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0026ee1:	c1 fa 1f             	sar    $0x1f,%edx
c0026ee4:	89 d7                	mov    %edx,%edi
c0026ee6:	33 7c 24 18          	xor    0x18(%esp),%edi
c0026eea:	89 7c 24 20          	mov    %edi,0x20(%esp)
c0026eee:	89 d7                	mov    %edx,%edi
c0026ef0:	33 7c 24 1c          	xor    0x1c(%esp),%edi
c0026ef4:	89 7c 24 24          	mov    %edi,0x24(%esp)
c0026ef8:	8b 74 24 20          	mov    0x20(%esp),%esi
c0026efc:	8b 7c 24 24          	mov    0x24(%esp),%edi
c0026f00:	29 d6                	sub    %edx,%esi
c0026f02:	19 d7                	sbb    %edx,%edi
c0026f04:	89 f0                	mov    %esi,%eax
c0026f06:	89 fa                	mov    %edi,%edx
c0026f08:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0026f0c:	89 7c 24 10          	mov    %edi,0x10(%esp)
c0026f10:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0026f14:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0026f18:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0026f1c:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0026f20:	c7 44 24 04 54 dc 02 	movl   $0xc002dc54,0x4(%esp)
c0026f27:	c0 
c0026f28:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0026f2c:	c1 e9 1f             	shr    $0x1f,%ecx
c0026f2f:	89 0c 24             	mov    %ecx,(%esp)
c0026f32:	b9 01 00 00 00       	mov    $0x1,%ecx
c0026f37:	e8 82 f8 ff ff       	call   c00267be <format_integer>
          break;
c0026f3c:	e9 7f 02 00 00       	jmp    c00271c0 <__vprintf+0x60c>
            switch (c.type) 
c0026f41:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026f46:	0f 87 b7 00 00 00    	ja     c0027003 <__vprintf+0x44f>
c0026f4c:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026f50:	ff 24 85 f4 db 02 c0 	jmp    *-0x3ffd240c(,%eax,4)
                value = (unsigned char) va_arg (args, unsigned);
c0026f57:	0f b6 45 00          	movzbl 0x0(%ebp),%eax
c0026f5b:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f5f:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f66:	00 
c0026f67:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f6a:	e9 b8 00 00 00       	jmp    c0027027 <__vprintf+0x473>
                value = (unsigned short) va_arg (args, unsigned);
c0026f6f:	0f b7 45 00          	movzwl 0x0(%ebp),%eax
c0026f73:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f77:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f7e:	00 
c0026f7f:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f82:	e9 a0 00 00 00       	jmp    c0027027 <__vprintf+0x473>
                value = va_arg (args, unsigned);
c0026f87:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f8a:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f8f:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f93:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f97:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f9a:	e9 88 00 00 00       	jmp    c0027027 <__vprintf+0x473>
                value = va_arg (args, uintmax_t);
c0026f9f:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fa2:	8b 55 04             	mov    0x4(%ebp),%edx
c0026fa5:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fa9:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fad:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026fb0:	eb 75                	jmp    c0027027 <__vprintf+0x473>
                value = va_arg (args, unsigned long);
c0026fb2:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fb5:	ba 00 00 00 00       	mov    $0x0,%edx
c0026fba:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fbe:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fc2:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fc5:	eb 60                	jmp    c0027027 <__vprintf+0x473>
                value = va_arg (args, unsigned long long);
c0026fc7:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fca:	8b 55 04             	mov    0x4(%ebp),%edx
c0026fcd:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fd1:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fd5:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026fd8:	eb 4d                	jmp    c0027027 <__vprintf+0x473>
                value &= ((uintmax_t) PTRDIFF_MAX << 1) | 1;
c0026fda:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fdd:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fe1:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026fe8:	00 
                value = va_arg (args, ptrdiff_t);
c0026fe9:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fec:	eb 39                	jmp    c0027027 <__vprintf+0x473>
                value = va_arg (args, size_t);
c0026fee:	8b 45 00             	mov    0x0(%ebp),%eax
c0026ff1:	ba 00 00 00 00       	mov    $0x0,%edx
c0026ff6:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026ffa:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026ffe:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0027001:	eb 24                	jmp    c0027027 <__vprintf+0x473>
                NOT_REACHED ();
c0027003:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c002700a:	c0 
c002700b:	c7 44 24 08 18 dc 02 	movl   $0xc002dc18,0x8(%esp)
c0027012:	c0 
c0027013:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c002701a:	00 
c002701b:	c7 04 24 b9 f8 02 c0 	movl   $0xc002f8b9,(%esp)
c0027022:	e8 9c 19 00 00       	call   c00289c3 <debug_panic>
            switch (*format) 
c0027027:	80 f9 6f             	cmp    $0x6f,%cl
c002702a:	74 4d                	je     c0027079 <__vprintf+0x4c5>
c002702c:	80 f9 6f             	cmp    $0x6f,%cl
c002702f:	7f 07                	jg     c0027038 <__vprintf+0x484>
c0027031:	80 f9 58             	cmp    $0x58,%cl
c0027034:	74 18                	je     c002704e <__vprintf+0x49a>
c0027036:	eb 1d                	jmp    c0027055 <__vprintf+0x4a1>
c0027038:	80 f9 75             	cmp    $0x75,%cl
c002703b:	90                   	nop
c002703c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027040:	74 3e                	je     c0027080 <__vprintf+0x4cc>
c0027042:	80 f9 78             	cmp    $0x78,%cl
c0027045:	75 0e                	jne    c0027055 <__vprintf+0x4a1>
              case 'x': b = &base_x; break;
c0027047:	b8 34 dc 02 c0       	mov    $0xc002dc34,%eax
c002704c:	eb 37                	jmp    c0027085 <__vprintf+0x4d1>
              case 'X': b = &base_X; break;
c002704e:	b8 24 dc 02 c0       	mov    $0xc002dc24,%eax
c0027053:	eb 30                	jmp    c0027085 <__vprintf+0x4d1>
              default: NOT_REACHED ();
c0027055:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c002705c:	c0 
c002705d:	c7 44 24 08 18 dc 02 	movl   $0xc002dc18,0x8(%esp)
c0027064:	c0 
c0027065:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
c002706c:	00 
c002706d:	c7 04 24 b9 f8 02 c0 	movl   $0xc002f8b9,(%esp)
c0027074:	e8 4a 19 00 00       	call   c00289c3 <debug_panic>
              case 'o': b = &base_o; break;
c0027079:	b8 44 dc 02 c0       	mov    $0xc002dc44,%eax
c002707e:	eb 05                	jmp    c0027085 <__vprintf+0x4d1>
              case 'u': b = &base_d; break;
c0027080:	b8 54 dc 02 c0       	mov    $0xc002dc54,%eax
            format_integer (value, false, false, b, &c, output, aux);
c0027085:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027089:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002708d:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0027091:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027095:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027099:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002709d:	89 44 24 04          	mov    %eax,0x4(%esp)
c00270a1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c00270a8:	b9 00 00 00 00       	mov    $0x0,%ecx
c00270ad:	8b 44 24 28          	mov    0x28(%esp),%eax
c00270b1:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c00270b5:	e8 04 f7 ff ff       	call   c00267be <format_integer>
          break;
c00270ba:	e9 01 01 00 00       	jmp    c00271c0 <__vprintf+0x60c>
            char ch = va_arg (args, int);
c00270bf:	8d 75 04             	lea    0x4(%ebp),%esi
c00270c2:	8b 45 00             	mov    0x0(%ebp),%eax
c00270c5:	88 44 24 3f          	mov    %al,0x3f(%esp)
            format_string (&ch, 1, &c, output, aux);
c00270c9:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c00270cd:	89 44 24 04          	mov    %eax,0x4(%esp)
c00270d1:	8b 44 24 78          	mov    0x78(%esp),%eax
c00270d5:	89 04 24             	mov    %eax,(%esp)
c00270d8:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c00270dc:	ba 01 00 00 00       	mov    $0x1,%edx
c00270e1:	8d 44 24 3f          	lea    0x3f(%esp),%eax
c00270e5:	e8 00 fa ff ff       	call   c0026aea <format_string>
            char ch = va_arg (args, int);
c00270ea:	89 f5                	mov    %esi,%ebp
          break;
c00270ec:	e9 cf 00 00 00       	jmp    c00271c0 <__vprintf+0x60c>
            const char *s = va_arg (args, char *);
c00270f1:	8d 75 04             	lea    0x4(%ebp),%esi
c00270f4:	8b 7d 00             	mov    0x0(%ebp),%edi
              s = "(null)";
c00270f7:	85 ff                	test   %edi,%edi
c00270f9:	ba b2 f8 02 c0       	mov    $0xc002f8b2,%edx
c00270fe:	0f 44 fa             	cmove  %edx,%edi
            format_string (s, strnlen (s, c.precision), &c, output, aux);
c0027101:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027105:	89 3c 24             	mov    %edi,(%esp)
c0027108:	e8 9d 0e 00 00       	call   c0027faa <strnlen>
c002710d:	8b 4c 24 7c          	mov    0x7c(%esp),%ecx
c0027111:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0027115:	8b 4c 24 78          	mov    0x78(%esp),%ecx
c0027119:	89 0c 24             	mov    %ecx,(%esp)
c002711c:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c0027120:	89 c2                	mov    %eax,%edx
c0027122:	89 f8                	mov    %edi,%eax
c0027124:	e8 c1 f9 ff ff       	call   c0026aea <format_string>
            const char *s = va_arg (args, char *);
c0027129:	89 f5                	mov    %esi,%ebp
          break;
c002712b:	e9 90 00 00 00       	jmp    c00271c0 <__vprintf+0x60c>
            void *p = va_arg (args, void *);
c0027130:	8d 75 04             	lea    0x4(%ebp),%esi
c0027133:	8b 45 00             	mov    0x0(%ebp),%eax
            c.flags = POUND;
c0027136:	c7 44 24 40 08 00 00 	movl   $0x8,0x40(%esp)
c002713d:	00 
            format_integer ((uintptr_t) p, false, false,
c002713e:	ba 00 00 00 00       	mov    $0x0,%edx
c0027143:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027147:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002714b:	8b 7c 24 78          	mov    0x78(%esp),%edi
c002714f:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027153:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027157:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002715b:	c7 44 24 04 34 dc 02 	movl   $0xc002dc34,0x4(%esp)
c0027162:	c0 
c0027163:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002716a:	b9 00 00 00 00       	mov    $0x0,%ecx
c002716f:	e8 4a f6 ff ff       	call   c00267be <format_integer>
            void *p = va_arg (args, void *);
c0027174:	89 f5                	mov    %esi,%ebp
          break;
c0027176:	eb 48                	jmp    c00271c0 <__vprintf+0x60c>
          __printf ("<<no %%%c in kernel>>", output, aux, *format);
c0027178:	0f be c9             	movsbl %cl,%ecx
c002717b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002717f:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027183:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027187:	8b 44 24 78          	mov    0x78(%esp),%eax
c002718b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002718f:	c7 04 24 cb f8 02 c0 	movl   $0xc002f8cb,(%esp)
c0027196:	e8 ee f9 ff ff       	call   c0026b89 <__printf>
          break;
c002719b:	eb 23                	jmp    c00271c0 <__vprintf+0x60c>
          __printf ("<<no %%%c conversion>>", output, aux, *format);
c002719d:	0f be c9             	movsbl %cl,%ecx
c00271a0:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c00271a4:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c00271a8:	89 44 24 08          	mov    %eax,0x8(%esp)
c00271ac:	8b 44 24 78          	mov    0x78(%esp),%eax
c00271b0:	89 44 24 04          	mov    %eax,0x4(%esp)
c00271b4:	c7 04 24 e1 f8 02 c0 	movl   $0xc002f8e1,(%esp)
c00271bb:	e8 c9 f9 ff ff       	call   c0026b89 <__printf>
  for (; *format != '\0'; format++)
c00271c0:	8d 7b 01             	lea    0x1(%ebx),%edi
c00271c3:	0f b6 43 01          	movzbl 0x1(%ebx),%eax
c00271c7:	84 c0                	test   %al,%al
c00271c9:	0f 85 ff f9 ff ff    	jne    c0026bce <__vprintf+0x1a>
c00271cf:	eb 19                	jmp    c00271ea <__vprintf+0x636>
  if (c->precision >= 0)
c00271d1:	8b 44 24 48          	mov    0x48(%esp),%eax
c00271d5:	e9 78 fb ff ff       	jmp    c0026d52 <__vprintf+0x19e>
      format++;
c00271da:	89 d6                	mov    %edx,%esi
  if (c->precision >= 0)
c00271dc:	8b 44 24 48          	mov    0x48(%esp),%eax
    c->flags &= ~ZERO;
c00271e0:	83 64 24 40 ef       	andl   $0xffffffef,0x40(%esp)
c00271e5:	e9 68 fb ff ff       	jmp    c0026d52 <__vprintf+0x19e>
}
c00271ea:	83 c4 5c             	add    $0x5c,%esp
c00271ed:	5b                   	pop    %ebx
c00271ee:	5e                   	pop    %esi
c00271ef:	5f                   	pop    %edi
c00271f0:	5d                   	pop    %ebp
c00271f1:	c3                   	ret    

c00271f2 <vsnprintf>:
{
c00271f2:	53                   	push   %ebx
c00271f3:	83 ec 28             	sub    $0x28,%esp
c00271f6:	8b 44 24 34          	mov    0x34(%esp),%eax
c00271fa:	8b 54 24 38          	mov    0x38(%esp),%edx
c00271fe:	8b 4c 24 3c          	mov    0x3c(%esp),%ecx
  aux.p = buffer;
c0027202:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027206:	89 5c 24 14          	mov    %ebx,0x14(%esp)
  aux.length = 0;
c002720a:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c0027211:	00 
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c0027212:	85 c0                	test   %eax,%eax
c0027214:	74 2c                	je     c0027242 <vsnprintf+0x50>
c0027216:	83 e8 01             	sub    $0x1,%eax
c0027219:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  __vprintf (format, args, vsnprintf_helper, &aux);
c002721d:	8d 44 24 14          	lea    0x14(%esp),%eax
c0027221:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027225:	c7 44 24 08 70 67 02 	movl   $0xc0026770,0x8(%esp)
c002722c:	c0 
c002722d:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0027231:	89 14 24             	mov    %edx,(%esp)
c0027234:	e8 7b f9 ff ff       	call   c0026bb4 <__vprintf>
    *aux.p = '\0';
c0027239:	8b 44 24 14          	mov    0x14(%esp),%eax
c002723d:	c6 00 00             	movb   $0x0,(%eax)
c0027240:	eb 24                	jmp    c0027266 <vsnprintf+0x74>
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c0027242:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c0027249:	00 
  __vprintf (format, args, vsnprintf_helper, &aux);
c002724a:	8d 44 24 14          	lea    0x14(%esp),%eax
c002724e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027252:	c7 44 24 08 70 67 02 	movl   $0xc0026770,0x8(%esp)
c0027259:	c0 
c002725a:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002725e:	89 14 24             	mov    %edx,(%esp)
c0027261:	e8 4e f9 ff ff       	call   c0026bb4 <__vprintf>
  return aux.length;
c0027266:	8b 44 24 18          	mov    0x18(%esp),%eax
}
c002726a:	83 c4 28             	add    $0x28,%esp
c002726d:	5b                   	pop    %ebx
c002726e:	c3                   	ret    

c002726f <snprintf>:
{
c002726f:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0027272:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  retval = vsnprintf (buffer, buf_size, format, args);
c0027276:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002727a:	8b 44 24 28          	mov    0x28(%esp),%eax
c002727e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027282:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027286:	89 44 24 04          	mov    %eax,0x4(%esp)
c002728a:	8b 44 24 20          	mov    0x20(%esp),%eax
c002728e:	89 04 24             	mov    %eax,(%esp)
c0027291:	e8 5c ff ff ff       	call   c00271f2 <vsnprintf>
}
c0027296:	83 c4 1c             	add    $0x1c,%esp
c0027299:	c3                   	ret    

c002729a <hex_dump>:
   starting at OFS for the first byte in BUF.  If ASCII is true
   then the corresponding ASCII characters are also rendered
   alongside. */   
void
hex_dump (uintptr_t ofs, const void *buf_, size_t size, bool ascii)
{
c002729a:	55                   	push   %ebp
c002729b:	57                   	push   %edi
c002729c:	56                   	push   %esi
c002729d:	53                   	push   %ebx
c002729e:	83 ec 2c             	sub    $0x2c,%esp
c00272a1:	0f b6 44 24 4c       	movzbl 0x4c(%esp),%eax
c00272a6:	88 44 24 1f          	mov    %al,0x1f(%esp)
  const uint8_t *buf = buf_;
  const size_t per_line = 16; /* Maximum bytes per line. */

  while (size > 0)
c00272aa:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c00272af:	0f 84 7c 01 00 00    	je     c0027431 <hex_dump+0x197>
    {
      size_t start, end, n;
      size_t i;
      
      /* Number of bytes on this line. */
      start = ofs % per_line;
c00272b5:	8b 7c 24 40          	mov    0x40(%esp),%edi
c00272b9:	83 e7 0f             	and    $0xf,%edi
      end = per_line;
      if (end - start > size)
c00272bc:	b8 10 00 00 00       	mov    $0x10,%eax
c00272c1:	29 f8                	sub    %edi,%eax
        end = start + size;
c00272c3:	89 fe                	mov    %edi,%esi
c00272c5:	03 74 24 48          	add    0x48(%esp),%esi
c00272c9:	3b 44 24 48          	cmp    0x48(%esp),%eax
c00272cd:	b8 10 00 00 00       	mov    $0x10,%eax
c00272d2:	0f 46 f0             	cmovbe %eax,%esi
      n = end - start;
c00272d5:	89 f0                	mov    %esi,%eax
c00272d7:	29 f8                	sub    %edi,%eax
c00272d9:	89 44 24 18          	mov    %eax,0x18(%esp)

      /* Print line. */
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
c00272dd:	8b 44 24 40          	mov    0x40(%esp),%eax
c00272e1:	83 e0 f0             	and    $0xfffffff0,%eax
c00272e4:	89 44 24 04          	mov    %eax,0x4(%esp)
c00272e8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00272ef:	00 
c00272f0:	c7 04 24 f8 f8 02 c0 	movl   $0xc002f8f8,(%esp)
c00272f7:	e8 72 f8 ff ff       	call   c0026b6e <printf>
      for (i = 0; i < start; i++)
c00272fc:	85 ff                	test   %edi,%edi
c00272fe:	74 1a                	je     c002731a <hex_dump+0x80>
c0027300:	bb 00 00 00 00       	mov    $0x0,%ebx
        printf ("   ");
c0027305:	c7 04 24 00 f9 02 c0 	movl   $0xc002f900,(%esp)
c002730c:	e8 5d f8 ff ff       	call   c0026b6e <printf>
      for (i = 0; i < start; i++)
c0027311:	83 c3 01             	add    $0x1,%ebx
c0027314:	39 fb                	cmp    %edi,%ebx
c0027316:	75 ed                	jne    c0027305 <hex_dump+0x6b>
c0027318:	eb 08                	jmp    c0027322 <hex_dump+0x88>
c002731a:	89 fb                	mov    %edi,%ebx
c002731c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027320:	eb 02                	jmp    c0027324 <hex_dump+0x8a>
c0027322:	89 fb                	mov    %edi,%ebx
      for (; i < end; i++) 
c0027324:	39 de                	cmp    %ebx,%esi
c0027326:	76 38                	jbe    c0027360 <hex_dump+0xc6>
c0027328:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c002732c:	29 fd                	sub    %edi,%ebp
        printf ("%02hhx%c",
c002732e:	83 fb 07             	cmp    $0x7,%ebx
c0027331:	b8 2d 00 00 00       	mov    $0x2d,%eax
c0027336:	b9 20 00 00 00       	mov    $0x20,%ecx
c002733b:	0f 45 c1             	cmovne %ecx,%eax
c002733e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027342:	0f b6 44 1d 00       	movzbl 0x0(%ebp,%ebx,1),%eax
c0027347:	89 44 24 04          	mov    %eax,0x4(%esp)
c002734b:	c7 04 24 04 f9 02 c0 	movl   $0xc002f904,(%esp)
c0027352:	e8 17 f8 ff ff       	call   c0026b6e <printf>
      for (; i < end; i++) 
c0027357:	83 c3 01             	add    $0x1,%ebx
c002735a:	39 de                	cmp    %ebx,%esi
c002735c:	77 d0                	ja     c002732e <hex_dump+0x94>
c002735e:	89 f3                	mov    %esi,%ebx
                buf[i - start], i == per_line / 2 - 1? '-' : ' ');
      if (ascii) 
c0027360:	80 7c 24 1f 00       	cmpb   $0x0,0x1f(%esp)
c0027365:	0f 84 a4 00 00 00    	je     c002740f <hex_dump+0x175>
        {
          for (; i < per_line; i++)
c002736b:	83 fb 0f             	cmp    $0xf,%ebx
c002736e:	77 14                	ja     c0027384 <hex_dump+0xea>
            printf ("   ");
c0027370:	c7 04 24 00 f9 02 c0 	movl   $0xc002f900,(%esp)
c0027377:	e8 f2 f7 ff ff       	call   c0026b6e <printf>
          for (; i < per_line; i++)
c002737c:	83 c3 01             	add    $0x1,%ebx
c002737f:	83 fb 10             	cmp    $0x10,%ebx
c0027382:	75 ec                	jne    c0027370 <hex_dump+0xd6>
          printf ("|");
c0027384:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c002738b:	e8 cc 33 00 00       	call   c002a75c <putchar>
          for (i = 0; i < start; i++)
c0027390:	85 ff                	test   %edi,%edi
c0027392:	74 1a                	je     c00273ae <hex_dump+0x114>
c0027394:	bb 00 00 00 00       	mov    $0x0,%ebx
            printf (" ");
c0027399:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c00273a0:	e8 b7 33 00 00       	call   c002a75c <putchar>
          for (i = 0; i < start; i++)
c00273a5:	83 c3 01             	add    $0x1,%ebx
c00273a8:	39 fb                	cmp    %edi,%ebx
c00273aa:	75 ed                	jne    c0027399 <hex_dump+0xff>
c00273ac:	eb 04                	jmp    c00273b2 <hex_dump+0x118>
c00273ae:	89 fb                	mov    %edi,%ebx
c00273b0:	eb 02                	jmp    c00273b4 <hex_dump+0x11a>
c00273b2:	89 fb                	mov    %edi,%ebx
          for (; i < end; i++)
c00273b4:	39 de                	cmp    %ebx,%esi
c00273b6:	76 30                	jbe    c00273e8 <hex_dump+0x14e>
c00273b8:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00273bc:	29 fd                	sub    %edi,%ebp
            printf ("%c",
c00273be:	bf 2e 00 00 00       	mov    $0x2e,%edi
                    isprint (buf[i - start]) ? buf[i - start] : '.');
c00273c3:	0f b6 54 1d 00       	movzbl 0x0(%ebp,%ebx,1),%edx
static inline int isprint (int c) { return c >= 32 && c < 127; }
c00273c8:	0f b6 c2             	movzbl %dl,%eax
            printf ("%c",
c00273cb:	8d 40 e0             	lea    -0x20(%eax),%eax
c00273ce:	0f b6 d2             	movzbl %dl,%edx
c00273d1:	83 f8 5e             	cmp    $0x5e,%eax
c00273d4:	0f 47 d7             	cmova  %edi,%edx
c00273d7:	89 14 24             	mov    %edx,(%esp)
c00273da:	e8 7d 33 00 00       	call   c002a75c <putchar>
          for (; i < end; i++)
c00273df:	83 c3 01             	add    $0x1,%ebx
c00273e2:	39 de                	cmp    %ebx,%esi
c00273e4:	77 dd                	ja     c00273c3 <hex_dump+0x129>
c00273e6:	eb 02                	jmp    c00273ea <hex_dump+0x150>
c00273e8:	89 de                	mov    %ebx,%esi
          for (; i < per_line; i++)
c00273ea:	83 fe 0f             	cmp    $0xf,%esi
c00273ed:	77 14                	ja     c0027403 <hex_dump+0x169>
            printf (" ");
c00273ef:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c00273f6:	e8 61 33 00 00       	call   c002a75c <putchar>
          for (; i < per_line; i++)
c00273fb:	83 c6 01             	add    $0x1,%esi
c00273fe:	83 fe 10             	cmp    $0x10,%esi
c0027401:	75 ec                	jne    c00273ef <hex_dump+0x155>
          printf ("|");
c0027403:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c002740a:	e8 4d 33 00 00       	call   c002a75c <putchar>
        }
      printf ("\n");
c002740f:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0027416:	e8 41 33 00 00       	call   c002a75c <putchar>

      ofs += n;
c002741b:	8b 44 24 18          	mov    0x18(%esp),%eax
c002741f:	01 44 24 40          	add    %eax,0x40(%esp)
      buf += n;
c0027423:	01 44 24 44          	add    %eax,0x44(%esp)
  while (size > 0)
c0027427:	29 44 24 48          	sub    %eax,0x48(%esp)
c002742b:	0f 85 84 fe ff ff    	jne    c00272b5 <hex_dump+0x1b>
      size -= n;
    }
}
c0027431:	83 c4 2c             	add    $0x2c,%esp
c0027434:	5b                   	pop    %ebx
c0027435:	5e                   	pop    %esi
c0027436:	5f                   	pop    %edi
c0027437:	5d                   	pop    %ebp
c0027438:	c3                   	ret    

c0027439 <print_human_readable_size>:

/* Prints SIZE, which represents a number of bytes, in a
   human-readable format, e.g. "256 kB". */
void
print_human_readable_size (uint64_t size) 
{
c0027439:	56                   	push   %esi
c002743a:	53                   	push   %ebx
c002743b:	83 ec 14             	sub    $0x14,%esp
c002743e:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c0027442:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (size == 1)
c0027446:	89 c8                	mov    %ecx,%eax
c0027448:	83 f0 01             	xor    $0x1,%eax
c002744b:	09 d8                	or     %ebx,%eax
c002744d:	74 22                	je     c0027471 <print_human_readable_size+0x38>
  else 
    {
      static const char *factors[] = {"bytes", "kB", "MB", "GB", "TB", NULL};
      const char **fp;

      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002744f:	83 fb 00             	cmp    $0x0,%ebx
c0027452:	77 0d                	ja     c0027461 <print_human_readable_size+0x28>
c0027454:	be 7c 5a 03 c0       	mov    $0xc0035a7c,%esi
c0027459:	81 f9 ff 03 00 00    	cmp    $0x3ff,%ecx
c002745f:	76 42                	jbe    c00274a3 <print_human_readable_size+0x6a>
c0027461:	be 7c 5a 03 c0       	mov    $0xc0035a7c,%esi
c0027466:	83 3d 80 5a 03 c0 00 	cmpl   $0x0,0xc0035a80
c002746d:	75 10                	jne    c002747f <print_human_readable_size+0x46>
c002746f:	eb 32                	jmp    c00274a3 <print_human_readable_size+0x6a>
    printf ("1 byte");
c0027471:	c7 04 24 0d f9 02 c0 	movl   $0xc002f90d,(%esp)
c0027478:	e8 f1 f6 ff ff       	call   c0026b6e <printf>
c002747d:	eb 3e                	jmp    c00274bd <print_human_readable_size+0x84>
        size /= 1024;
c002747f:	89 c8                	mov    %ecx,%eax
c0027481:	89 da                	mov    %ebx,%edx
c0027483:	0f ac d8 0a          	shrd   $0xa,%ebx,%eax
c0027487:	c1 ea 0a             	shr    $0xa,%edx
c002748a:	89 c1                	mov    %eax,%ecx
c002748c:	89 d3                	mov    %edx,%ebx
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002748e:	83 c6 04             	add    $0x4,%esi
c0027491:	83 fa 00             	cmp    $0x0,%edx
c0027494:	77 07                	ja     c002749d <print_human_readable_size+0x64>
c0027496:	3d ff 03 00 00       	cmp    $0x3ff,%eax
c002749b:	76 06                	jbe    c00274a3 <print_human_readable_size+0x6a>
c002749d:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c00274a1:	75 dc                	jne    c002747f <print_human_readable_size+0x46>
      printf ("%"PRIu64" %s", size, *fp);
c00274a3:	8b 06                	mov    (%esi),%eax
c00274a5:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00274a9:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00274ad:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00274b1:	c7 04 24 14 f9 02 c0 	movl   $0xc002f914,(%esp)
c00274b8:	e8 b1 f6 ff ff       	call   c0026b6e <printf>
    }
}
c00274bd:	83 c4 14             	add    $0x14,%esp
c00274c0:	5b                   	pop    %ebx
c00274c1:	5e                   	pop    %esi
c00274c2:	c3                   	ret    
c00274c3:	90                   	nop
c00274c4:	90                   	nop
c00274c5:	90                   	nop
c00274c6:	90                   	nop
c00274c7:	90                   	nop
c00274c8:	90                   	nop
c00274c9:	90                   	nop
c00274ca:	90                   	nop
c00274cb:	90                   	nop
c00274cc:	90                   	nop
c00274cd:	90                   	nop
c00274ce:	90                   	nop
c00274cf:	90                   	nop

c00274d0 <compare_thunk>:
}

/* Compares A and B by calling the AUX function. */
static int
compare_thunk (const void *a, const void *b, void *aux) 
{
c00274d0:	83 ec 1c             	sub    $0x1c,%esp
  int (**compare) (const void *, const void *) = aux;
  return (*compare) (a, b);
c00274d3:	8b 44 24 24          	mov    0x24(%esp),%eax
c00274d7:	89 44 24 04          	mov    %eax,0x4(%esp)
c00274db:	8b 44 24 20          	mov    0x20(%esp),%eax
c00274df:	89 04 24             	mov    %eax,(%esp)
c00274e2:	8b 44 24 28          	mov    0x28(%esp),%eax
c00274e6:	ff 10                	call   *(%eax)
}
c00274e8:	83 c4 1c             	add    $0x1c,%esp
c00274eb:	c3                   	ret    

c00274ec <do_swap>:

/* Swaps elements with 1-based indexes A_IDX and B_IDX in ARRAY
   with elements of SIZE bytes each. */
static void
do_swap (unsigned char *array, size_t a_idx, size_t b_idx, size_t size)
{
c00274ec:	57                   	push   %edi
c00274ed:	56                   	push   %esi
c00274ee:	53                   	push   %ebx
c00274ef:	8b 7c 24 10          	mov    0x10(%esp),%edi
  unsigned char *a = array + (a_idx - 1) * size;
c00274f3:	8d 5a ff             	lea    -0x1(%edx),%ebx
c00274f6:	0f af df             	imul   %edi,%ebx
c00274f9:	01 c3                	add    %eax,%ebx
  unsigned char *b = array + (b_idx - 1) * size;
c00274fb:	8d 51 ff             	lea    -0x1(%ecx),%edx
c00274fe:	0f af d7             	imul   %edi,%edx
c0027501:	01 d0                	add    %edx,%eax
  size_t i;

  for (i = 0; i < size; i++)
c0027503:	85 ff                	test   %edi,%edi
c0027505:	74 1c                	je     c0027523 <do_swap+0x37>
c0027507:	ba 00 00 00 00       	mov    $0x0,%edx
    {
      unsigned char t = a[i];
c002750c:	0f b6 34 13          	movzbl (%ebx,%edx,1),%esi
      a[i] = b[i];
c0027510:	0f b6 0c 10          	movzbl (%eax,%edx,1),%ecx
c0027514:	88 0c 13             	mov    %cl,(%ebx,%edx,1)
      b[i] = t;
c0027517:	89 f1                	mov    %esi,%ecx
c0027519:	88 0c 10             	mov    %cl,(%eax,%edx,1)
  for (i = 0; i < size; i++)
c002751c:	83 c2 01             	add    $0x1,%edx
c002751f:	39 fa                	cmp    %edi,%edx
c0027521:	75 e9                	jne    c002750c <do_swap+0x20>
    }
}
c0027523:	5b                   	pop    %ebx
c0027524:	5e                   	pop    %esi
c0027525:	5f                   	pop    %edi
c0027526:	c3                   	ret    

c0027527 <heapify>:
   elements, passing AUX as auxiliary data. */
static void
heapify (unsigned char *array, size_t i, size_t cnt, size_t size,
         int (*compare) (const void *, const void *, void *aux),
         void *aux) 
{
c0027527:	55                   	push   %ebp
c0027528:	57                   	push   %edi
c0027529:	56                   	push   %esi
c002752a:	53                   	push   %ebx
c002752b:	83 ec 2c             	sub    $0x2c,%esp
c002752e:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0027532:	89 d3                	mov    %edx,%ebx
c0027534:	89 4c 24 18          	mov    %ecx,0x18(%esp)
  for (;;) 
    {
      /* Set `max' to the index of the largest element among I
         and its children (if any). */
      size_t left = 2 * i;
c0027538:	8d 3c 1b             	lea    (%ebx,%ebx,1),%edi
      size_t right = 2 * i + 1;
c002753b:	8d 6f 01             	lea    0x1(%edi),%ebp
      size_t max = i;
c002753e:	89 de                	mov    %ebx,%esi
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027540:	3b 7c 24 18          	cmp    0x18(%esp),%edi
c0027544:	77 30                	ja     c0027576 <heapify+0x4f>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c0027546:	8b 44 24 48          	mov    0x48(%esp),%eax
c002754a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002754e:	8d 43 ff             	lea    -0x1(%ebx),%eax
c0027551:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027556:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002755a:	01 d0                	add    %edx,%eax
c002755c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027560:	8d 47 ff             	lea    -0x1(%edi),%eax
c0027563:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027568:	01 d0                	add    %edx,%eax
c002756a:	89 04 24             	mov    %eax,(%esp)
c002756d:	ff 54 24 44          	call   *0x44(%esp)
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027571:	85 c0                	test   %eax,%eax
      size_t max = i;
c0027573:	0f 4f f7             	cmovg  %edi,%esi
        max = left;
      if (right <= cnt
c0027576:	3b 6c 24 18          	cmp    0x18(%esp),%ebp
c002757a:	77 2d                	ja     c00275a9 <heapify+0x82>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c002757c:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027580:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027584:	8d 46 ff             	lea    -0x1(%esi),%eax
c0027587:	0f af 44 24 40       	imul   0x40(%esp),%eax
c002758c:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0027590:	01 c8                	add    %ecx,%eax
c0027592:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027596:	0f af 7c 24 40       	imul   0x40(%esp),%edi
c002759b:	01 cf                	add    %ecx,%edi
c002759d:	89 3c 24             	mov    %edi,(%esp)
c00275a0:	ff 54 24 44          	call   *0x44(%esp)
          && do_compare (array, right, max, size, compare, aux) > 0) 
c00275a4:	85 c0                	test   %eax,%eax
        max = right;
c00275a6:	0f 4f f5             	cmovg  %ebp,%esi

      /* If the maximum value is already in element I, we're
         done. */
      if (max == i)
c00275a9:	39 de                	cmp    %ebx,%esi
c00275ab:	74 1b                	je     c00275c8 <heapify+0xa1>
        break;

      /* Swap and continue down the heap. */
      do_swap (array, i, max, size);
c00275ad:	8b 44 24 40          	mov    0x40(%esp),%eax
c00275b1:	89 04 24             	mov    %eax,(%esp)
c00275b4:	89 f1                	mov    %esi,%ecx
c00275b6:	89 da                	mov    %ebx,%edx
c00275b8:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c00275bc:	e8 2b ff ff ff       	call   c00274ec <do_swap>
      i = max;
c00275c1:	89 f3                	mov    %esi,%ebx
    }
c00275c3:	e9 70 ff ff ff       	jmp    c0027538 <heapify+0x11>
}
c00275c8:	83 c4 2c             	add    $0x2c,%esp
c00275cb:	5b                   	pop    %ebx
c00275cc:	5e                   	pop    %esi
c00275cd:	5f                   	pop    %edi
c00275ce:	5d                   	pop    %ebp
c00275cf:	c3                   	ret    

c00275d0 <atoi>:
{
c00275d0:	57                   	push   %edi
c00275d1:	56                   	push   %esi
c00275d2:	53                   	push   %ebx
c00275d3:	83 ec 20             	sub    $0x20,%esp
c00275d6:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c00275da:	85 d2                	test   %edx,%edx
c00275dc:	75 2f                	jne    c002760d <atoi+0x3d>
c00275de:	c7 44 24 10 5a fa 02 	movl   $0xc002fa5a,0x10(%esp)
c00275e5:	c0 
c00275e6:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00275ed:	c0 
c00275ee:	c7 44 24 08 69 dc 02 	movl   $0xc002dc69,0x8(%esp)
c00275f5:	c0 
c00275f6:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
c00275fd:	00 
c00275fe:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c0027605:	e8 b9 13 00 00       	call   c00289c3 <debug_panic>
    s++;
c002760a:	83 c2 01             	add    $0x1,%edx
  while (isspace ((unsigned char) *s))
c002760d:	0f b6 02             	movzbl (%edx),%eax
c0027610:	0f b6 c8             	movzbl %al,%ecx
          || c == '\r' || c == '\t' || c == '\v');
c0027613:	83 f9 20             	cmp    $0x20,%ecx
c0027616:	74 f2                	je     c002760a <atoi+0x3a>
  return (c == ' ' || c == '\f' || c == '\n'
c0027618:	8d 58 f4             	lea    -0xc(%eax),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c002761b:	80 fb 01             	cmp    $0x1,%bl
c002761e:	76 ea                	jbe    c002760a <atoi+0x3a>
c0027620:	83 f9 0a             	cmp    $0xa,%ecx
c0027623:	74 e5                	je     c002760a <atoi+0x3a>
c0027625:	89 c1                	mov    %eax,%ecx
c0027627:	83 e1 fd             	and    $0xfffffffd,%ecx
c002762a:	80 f9 09             	cmp    $0x9,%cl
c002762d:	74 db                	je     c002760a <atoi+0x3a>
  if (*s == '+')
c002762f:	3c 2b                	cmp    $0x2b,%al
c0027631:	75 0a                	jne    c002763d <atoi+0x6d>
    s++;
c0027633:	83 c2 01             	add    $0x1,%edx
  negative = false;
c0027636:	be 00 00 00 00       	mov    $0x0,%esi
c002763b:	eb 11                	jmp    c002764e <atoi+0x7e>
c002763d:	be 00 00 00 00       	mov    $0x0,%esi
  else if (*s == '-')
c0027642:	3c 2d                	cmp    $0x2d,%al
c0027644:	75 08                	jne    c002764e <atoi+0x7e>
      s++;
c0027646:	8d 52 01             	lea    0x1(%edx),%edx
      negative = true;
c0027649:	be 01 00 00 00       	mov    $0x1,%esi
  for (value = 0; isdigit (*s); s++)
c002764e:	0f b6 0a             	movzbl (%edx),%ecx
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0027651:	0f be c1             	movsbl %cl,%eax
c0027654:	83 e8 30             	sub    $0x30,%eax
c0027657:	83 f8 09             	cmp    $0x9,%eax
c002765a:	77 2a                	ja     c0027686 <atoi+0xb6>
c002765c:	b8 00 00 00 00       	mov    $0x0,%eax
    value = value * 10 - (*s - '0');
c0027661:	bf 30 00 00 00       	mov    $0x30,%edi
c0027666:	8d 1c 80             	lea    (%eax,%eax,4),%ebx
c0027669:	0f be c9             	movsbl %cl,%ecx
c002766c:	89 f8                	mov    %edi,%eax
c002766e:	29 c8                	sub    %ecx,%eax
c0027670:	8d 04 58             	lea    (%eax,%ebx,2),%eax
  for (value = 0; isdigit (*s); s++)
c0027673:	83 c2 01             	add    $0x1,%edx
c0027676:	0f b6 0a             	movzbl (%edx),%ecx
c0027679:	0f be d9             	movsbl %cl,%ebx
c002767c:	83 eb 30             	sub    $0x30,%ebx
c002767f:	83 fb 09             	cmp    $0x9,%ebx
c0027682:	76 e2                	jbe    c0027666 <atoi+0x96>
c0027684:	eb 05                	jmp    c002768b <atoi+0xbb>
c0027686:	b8 00 00 00 00       	mov    $0x0,%eax
    value = -value;
c002768b:	89 c2                	mov    %eax,%edx
c002768d:	f7 da                	neg    %edx
c002768f:	89 f3                	mov    %esi,%ebx
c0027691:	84 db                	test   %bl,%bl
c0027693:	0f 44 c2             	cmove  %edx,%eax
}
c0027696:	83 c4 20             	add    $0x20,%esp
c0027699:	5b                   	pop    %ebx
c002769a:	5e                   	pop    %esi
c002769b:	5f                   	pop    %edi
c002769c:	c3                   	ret    

c002769d <sort>:
   B.  Runs in O(n lg n) time and O(1) space in CNT. */
void
sort (void *array, size_t cnt, size_t size,
      int (*compare) (const void *, const void *, void *aux),
      void *aux) 
{
c002769d:	55                   	push   %ebp
c002769e:	57                   	push   %edi
c002769f:	56                   	push   %esi
c00276a0:	53                   	push   %ebx
c00276a1:	83 ec 2c             	sub    $0x2c,%esp
c00276a4:	8b 7c 24 40          	mov    0x40(%esp),%edi
c00276a8:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c00276ac:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  size_t i;

  ASSERT (array != NULL || cnt == 0);
c00276b0:	85 ff                	test   %edi,%edi
c00276b2:	75 30                	jne    c00276e4 <sort+0x47>
c00276b4:	85 db                	test   %ebx,%ebx
c00276b6:	74 2c                	je     c00276e4 <sort+0x47>
c00276b8:	c7 44 24 10 77 f9 02 	movl   $0xc002f977,0x10(%esp)
c00276bf:	c0 
c00276c0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00276c7:	c0 
c00276c8:	c7 44 24 08 64 dc 02 	movl   $0xc002dc64,0x8(%esp)
c00276cf:	c0 
c00276d0:	c7 44 24 04 8a 00 00 	movl   $0x8a,0x4(%esp)
c00276d7:	00 
c00276d8:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c00276df:	e8 df 12 00 00       	call   c00289c3 <debug_panic>
  ASSERT (compare != NULL);
c00276e4:	83 7c 24 4c 00       	cmpl   $0x0,0x4c(%esp)
c00276e9:	75 2c                	jne    c0027717 <sort+0x7a>
c00276eb:	c7 44 24 10 91 f9 02 	movl   $0xc002f991,0x10(%esp)
c00276f2:	c0 
c00276f3:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00276fa:	c0 
c00276fb:	c7 44 24 08 64 dc 02 	movl   $0xc002dc64,0x8(%esp)
c0027702:	c0 
c0027703:	c7 44 24 04 8b 00 00 	movl   $0x8b,0x4(%esp)
c002770a:	00 
c002770b:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c0027712:	e8 ac 12 00 00       	call   c00289c3 <debug_panic>
  ASSERT (size > 0);
c0027717:	85 ed                	test   %ebp,%ebp
c0027719:	75 2c                	jne    c0027747 <sort+0xaa>
c002771b:	c7 44 24 10 a1 f9 02 	movl   $0xc002f9a1,0x10(%esp)
c0027722:	c0 
c0027723:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002772a:	c0 
c002772b:	c7 44 24 08 64 dc 02 	movl   $0xc002dc64,0x8(%esp)
c0027732:	c0 
c0027733:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c002773a:	00 
c002773b:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c0027742:	e8 7c 12 00 00       	call   c00289c3 <debug_panic>

  /* Build a heap. */
  for (i = cnt / 2; i > 0; i--)
c0027747:	89 de                	mov    %ebx,%esi
c0027749:	d1 ee                	shr    %esi
c002774b:	74 23                	je     c0027770 <sort+0xd3>
    heapify (array, i, cnt, size, compare, aux);
c002774d:	8b 44 24 50          	mov    0x50(%esp),%eax
c0027751:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027755:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027759:	89 44 24 04          	mov    %eax,0x4(%esp)
c002775d:	89 2c 24             	mov    %ebp,(%esp)
c0027760:	89 d9                	mov    %ebx,%ecx
c0027762:	89 f2                	mov    %esi,%edx
c0027764:	89 f8                	mov    %edi,%eax
c0027766:	e8 bc fd ff ff       	call   c0027527 <heapify>
  for (i = cnt / 2; i > 0; i--)
c002776b:	83 ee 01             	sub    $0x1,%esi
c002776e:	75 dd                	jne    c002774d <sort+0xb0>

  /* Sort the heap. */
  for (i = cnt; i > 1; i--) 
c0027770:	83 fb 01             	cmp    $0x1,%ebx
c0027773:	76 3a                	jbe    c00277af <sort+0x112>
c0027775:	8b 74 24 50          	mov    0x50(%esp),%esi
    {
      do_swap (array, 1, i, size);
c0027779:	89 2c 24             	mov    %ebp,(%esp)
c002777c:	89 d9                	mov    %ebx,%ecx
c002777e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027783:	89 f8                	mov    %edi,%eax
c0027785:	e8 62 fd ff ff       	call   c00274ec <do_swap>
      heapify (array, 1, i - 1, size, compare, aux); 
c002778a:	83 eb 01             	sub    $0x1,%ebx
c002778d:	89 74 24 08          	mov    %esi,0x8(%esp)
c0027791:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027795:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027799:	89 2c 24             	mov    %ebp,(%esp)
c002779c:	89 d9                	mov    %ebx,%ecx
c002779e:	ba 01 00 00 00       	mov    $0x1,%edx
c00277a3:	89 f8                	mov    %edi,%eax
c00277a5:	e8 7d fd ff ff       	call   c0027527 <heapify>
  for (i = cnt; i > 1; i--) 
c00277aa:	83 fb 01             	cmp    $0x1,%ebx
c00277ad:	75 ca                	jne    c0027779 <sort+0xdc>
    }
}
c00277af:	83 c4 2c             	add    $0x2c,%esp
c00277b2:	5b                   	pop    %ebx
c00277b3:	5e                   	pop    %esi
c00277b4:	5f                   	pop    %edi
c00277b5:	5d                   	pop    %ebp
c00277b6:	c3                   	ret    

c00277b7 <qsort>:
{
c00277b7:	83 ec 2c             	sub    $0x2c,%esp
  sort (array, cnt, size, compare_thunk, &compare);
c00277ba:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c00277be:	89 44 24 10          	mov    %eax,0x10(%esp)
c00277c2:	c7 44 24 0c d0 74 02 	movl   $0xc00274d0,0xc(%esp)
c00277c9:	c0 
c00277ca:	8b 44 24 38          	mov    0x38(%esp),%eax
c00277ce:	89 44 24 08          	mov    %eax,0x8(%esp)
c00277d2:	8b 44 24 34          	mov    0x34(%esp),%eax
c00277d6:	89 44 24 04          	mov    %eax,0x4(%esp)
c00277da:	8b 44 24 30          	mov    0x30(%esp),%eax
c00277de:	89 04 24             	mov    %eax,(%esp)
c00277e1:	e8 b7 fe ff ff       	call   c002769d <sort>
}
c00277e6:	83 c4 2c             	add    $0x2c,%esp
c00277e9:	c3                   	ret    

c00277ea <binary_search>:
   B. */
void *
binary_search (const void *key, const void *array, size_t cnt, size_t size,
               int (*compare) (const void *, const void *, void *aux),
               void *aux) 
{
c00277ea:	55                   	push   %ebp
c00277eb:	57                   	push   %edi
c00277ec:	56                   	push   %esi
c00277ed:	53                   	push   %ebx
c00277ee:	83 ec 1c             	sub    $0x1c,%esp
c00277f1:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c00277f5:	8b 74 24 3c          	mov    0x3c(%esp),%esi
  const unsigned char *first = array;
  const unsigned char *last = array + size * cnt;
c00277f9:	89 f5                	mov    %esi,%ebp
c00277fb:	0f af 6c 24 38       	imul   0x38(%esp),%ebp
c0027800:	01 dd                	add    %ebx,%ebp

  while (first < last) 
c0027802:	39 eb                	cmp    %ebp,%ebx
c0027804:	73 44                	jae    c002784a <binary_search+0x60>
    {
      size_t range = (last - first) / size;
c0027806:	89 e8                	mov    %ebp,%eax
c0027808:	29 d8                	sub    %ebx,%eax
c002780a:	ba 00 00 00 00       	mov    $0x0,%edx
c002780f:	f7 f6                	div    %esi
      const unsigned char *middle = first + (range / 2) * size;
c0027811:	d1 e8                	shr    %eax
c0027813:	0f af c6             	imul   %esi,%eax
c0027816:	89 c7                	mov    %eax,%edi
c0027818:	01 df                	add    %ebx,%edi
      int cmp = compare (key, middle, aux);
c002781a:	8b 44 24 44          	mov    0x44(%esp),%eax
c002781e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027822:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0027826:	8b 44 24 30          	mov    0x30(%esp),%eax
c002782a:	89 04 24             	mov    %eax,(%esp)
c002782d:	ff 54 24 40          	call   *0x40(%esp)

      if (cmp < 0) 
c0027831:	85 c0                	test   %eax,%eax
c0027833:	78 0d                	js     c0027842 <binary_search+0x58>
        last = middle;
      else if (cmp > 0) 
c0027835:	85 c0                	test   %eax,%eax
c0027837:	7e 19                	jle    c0027852 <binary_search+0x68>
        first = middle + size;
c0027839:	8d 1c 37             	lea    (%edi,%esi,1),%ebx
c002783c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027840:	eb 02                	jmp    c0027844 <binary_search+0x5a>
      const unsigned char *middle = first + (range / 2) * size;
c0027842:	89 fd                	mov    %edi,%ebp
  while (first < last) 
c0027844:	39 dd                	cmp    %ebx,%ebp
c0027846:	77 be                	ja     c0027806 <binary_search+0x1c>
c0027848:	eb 0c                	jmp    c0027856 <binary_search+0x6c>
      else
        return (void *) middle;
    }
  
  return NULL;
c002784a:	b8 00 00 00 00       	mov    $0x0,%eax
c002784f:	90                   	nop
c0027850:	eb 09                	jmp    c002785b <binary_search+0x71>
      const unsigned char *middle = first + (range / 2) * size;
c0027852:	89 f8                	mov    %edi,%eax
c0027854:	eb 05                	jmp    c002785b <binary_search+0x71>
  return NULL;
c0027856:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002785b:	83 c4 1c             	add    $0x1c,%esp
c002785e:	5b                   	pop    %ebx
c002785f:	5e                   	pop    %esi
c0027860:	5f                   	pop    %edi
c0027861:	5d                   	pop    %ebp
c0027862:	c3                   	ret    

c0027863 <bsearch>:
{
c0027863:	83 ec 2c             	sub    $0x2c,%esp
  return binary_search (key, array, cnt, size, compare_thunk, &compare);
c0027866:	8d 44 24 40          	lea    0x40(%esp),%eax
c002786a:	89 44 24 14          	mov    %eax,0x14(%esp)
c002786e:	c7 44 24 10 d0 74 02 	movl   $0xc00274d0,0x10(%esp)
c0027875:	c0 
c0027876:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c002787a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002787e:	8b 44 24 38          	mov    0x38(%esp),%eax
c0027882:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027886:	8b 44 24 34          	mov    0x34(%esp),%eax
c002788a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002788e:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027892:	89 04 24             	mov    %eax,(%esp)
c0027895:	e8 50 ff ff ff       	call   c00277ea <binary_search>
}
c002789a:	83 c4 2c             	add    $0x2c,%esp
c002789d:	c3                   	ret    
c002789e:	90                   	nop
c002789f:	90                   	nop

c00278a0 <memcpy>:

/* Copies SIZE bytes from SRC to DST, which must not overlap.
   Returns DST. */
void *
memcpy (void *dst_, const void *src_, size_t size) 
{
c00278a0:	56                   	push   %esi
c00278a1:	53                   	push   %ebx
c00278a2:	83 ec 24             	sub    $0x24,%esp
c00278a5:	8b 44 24 30          	mov    0x30(%esp),%eax
c00278a9:	8b 74 24 34          	mov    0x34(%esp),%esi
c00278ad:	8b 5c 24 38          	mov    0x38(%esp),%ebx
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c00278b1:	85 db                	test   %ebx,%ebx
c00278b3:	0f 94 c2             	sete   %dl
c00278b6:	85 c0                	test   %eax,%eax
c00278b8:	75 30                	jne    c00278ea <memcpy+0x4a>
c00278ba:	84 d2                	test   %dl,%dl
c00278bc:	75 2c                	jne    c00278ea <memcpy+0x4a>
c00278be:	c7 44 24 10 aa f9 02 	movl   $0xc002f9aa,0x10(%esp)
c00278c5:	c0 
c00278c6:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00278cd:	c0 
c00278ce:	c7 44 24 08 b9 dc 02 	movl   $0xc002dcb9,0x8(%esp)
c00278d5:	c0 
c00278d6:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c00278dd:	00 
c00278de:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00278e5:	e8 d9 10 00 00       	call   c00289c3 <debug_panic>
  ASSERT (src != NULL || size == 0);
c00278ea:	85 f6                	test   %esi,%esi
c00278ec:	75 04                	jne    c00278f2 <memcpy+0x52>
c00278ee:	84 d2                	test   %dl,%dl
c00278f0:	74 0b                	je     c00278fd <memcpy+0x5d>

  while (size-- > 0)
c00278f2:	ba 00 00 00 00       	mov    $0x0,%edx
c00278f7:	85 db                	test   %ebx,%ebx
c00278f9:	75 2e                	jne    c0027929 <memcpy+0x89>
c00278fb:	eb 3a                	jmp    c0027937 <memcpy+0x97>
  ASSERT (src != NULL || size == 0);
c00278fd:	c7 44 24 10 d6 f9 02 	movl   $0xc002f9d6,0x10(%esp)
c0027904:	c0 
c0027905:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002790c:	c0 
c002790d:	c7 44 24 08 b9 dc 02 	movl   $0xc002dcb9,0x8(%esp)
c0027914:	c0 
c0027915:	c7 44 24 04 0d 00 00 	movl   $0xd,0x4(%esp)
c002791c:	00 
c002791d:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027924:	e8 9a 10 00 00       	call   c00289c3 <debug_panic>
    *dst++ = *src++;
c0027929:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
c002792d:	88 0c 10             	mov    %cl,(%eax,%edx,1)
c0027930:	83 c2 01             	add    $0x1,%edx
  while (size-- > 0)
c0027933:	39 da                	cmp    %ebx,%edx
c0027935:	75 f2                	jne    c0027929 <memcpy+0x89>

  return dst_;
}
c0027937:	83 c4 24             	add    $0x24,%esp
c002793a:	5b                   	pop    %ebx
c002793b:	5e                   	pop    %esi
c002793c:	c3                   	ret    

c002793d <memmove>:

/* Copies SIZE bytes from SRC to DST, which are allowed to
   overlap.  Returns DST. */
void *
memmove (void *dst_, const void *src_, size_t size) 
{
c002793d:	57                   	push   %edi
c002793e:	56                   	push   %esi
c002793f:	53                   	push   %ebx
c0027940:	83 ec 20             	sub    $0x20,%esp
c0027943:	8b 74 24 30          	mov    0x30(%esp),%esi
c0027947:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c002794b:	8b 7c 24 38          	mov    0x38(%esp),%edi
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c002794f:	85 ff                	test   %edi,%edi
c0027951:	0f 94 c2             	sete   %dl
c0027954:	85 f6                	test   %esi,%esi
c0027956:	75 30                	jne    c0027988 <memmove+0x4b>
c0027958:	84 d2                	test   %dl,%dl
c002795a:	75 2c                	jne    c0027988 <memmove+0x4b>
c002795c:	c7 44 24 10 aa f9 02 	movl   $0xc002f9aa,0x10(%esp)
c0027963:	c0 
c0027964:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002796b:	c0 
c002796c:	c7 44 24 08 b1 dc 02 	movl   $0xc002dcb1,0x8(%esp)
c0027973:	c0 
c0027974:	c7 44 24 04 1d 00 00 	movl   $0x1d,0x4(%esp)
c002797b:	00 
c002797c:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027983:	e8 3b 10 00 00       	call   c00289c3 <debug_panic>
  ASSERT (src != NULL || size == 0);
c0027988:	85 db                	test   %ebx,%ebx
c002798a:	75 30                	jne    c00279bc <memmove+0x7f>
c002798c:	84 d2                	test   %dl,%dl
c002798e:	75 2c                	jne    c00279bc <memmove+0x7f>
c0027990:	c7 44 24 10 d6 f9 02 	movl   $0xc002f9d6,0x10(%esp)
c0027997:	c0 
c0027998:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002799f:	c0 
c00279a0:	c7 44 24 08 b1 dc 02 	movl   $0xc002dcb1,0x8(%esp)
c00279a7:	c0 
c00279a8:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c00279af:	00 
c00279b0:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00279b7:	e8 07 10 00 00       	call   c00289c3 <debug_panic>

  if (dst < src) 
c00279bc:	39 de                	cmp    %ebx,%esi
c00279be:	73 1b                	jae    c00279db <memmove+0x9e>
    {
      while (size-- > 0)
c00279c0:	85 ff                	test   %edi,%edi
c00279c2:	74 40                	je     c0027a04 <memmove+0xc7>
c00279c4:	ba 00 00 00 00       	mov    $0x0,%edx
        *dst++ = *src++;
c00279c9:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
c00279cd:	88 0c 16             	mov    %cl,(%esi,%edx,1)
c00279d0:	83 c2 01             	add    $0x1,%edx
      while (size-- > 0)
c00279d3:	39 fa                	cmp    %edi,%edx
c00279d5:	75 f2                	jne    c00279c9 <memmove+0x8c>
c00279d7:	01 fe                	add    %edi,%esi
c00279d9:	eb 29                	jmp    c0027a04 <memmove+0xc7>
    }
  else 
    {
      dst += size;
c00279db:	8d 04 3e             	lea    (%esi,%edi,1),%eax
      src += size;
c00279de:	01 fb                	add    %edi,%ebx
      while (size-- > 0)
c00279e0:	8d 57 ff             	lea    -0x1(%edi),%edx
c00279e3:	85 ff                	test   %edi,%edi
c00279e5:	74 1b                	je     c0027a02 <memmove+0xc5>
c00279e7:	f7 df                	neg    %edi
c00279e9:	89 f9                	mov    %edi,%ecx
c00279eb:	01 fb                	add    %edi,%ebx
c00279ed:	01 c1                	add    %eax,%ecx
c00279ef:	89 ce                	mov    %ecx,%esi
        *--dst = *--src;
c00279f1:	0f b6 04 13          	movzbl (%ebx,%edx,1),%eax
c00279f5:	88 04 11             	mov    %al,(%ecx,%edx,1)
      while (size-- > 0)
c00279f8:	83 ea 01             	sub    $0x1,%edx
c00279fb:	83 fa ff             	cmp    $0xffffffff,%edx
c00279fe:	75 ef                	jne    c00279ef <memmove+0xb2>
c0027a00:	eb 02                	jmp    c0027a04 <memmove+0xc7>
      dst += size;
c0027a02:	89 c6                	mov    %eax,%esi
    }

  return dst;
}
c0027a04:	89 f0                	mov    %esi,%eax
c0027a06:	83 c4 20             	add    $0x20,%esp
c0027a09:	5b                   	pop    %ebx
c0027a0a:	5e                   	pop    %esi
c0027a0b:	5f                   	pop    %edi
c0027a0c:	c3                   	ret    

c0027a0d <memcmp>:
   at A and B.  Returns a positive value if the byte in A is
   greater, a negative value if the byte in B is greater, or zero
   if blocks A and B are equal. */
int
memcmp (const void *a_, const void *b_, size_t size) 
{
c0027a0d:	57                   	push   %edi
c0027a0e:	56                   	push   %esi
c0027a0f:	53                   	push   %ebx
c0027a10:	83 ec 20             	sub    $0x20,%esp
c0027a13:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027a17:	8b 74 24 34          	mov    0x34(%esp),%esi
c0027a1b:	8b 44 24 38          	mov    0x38(%esp),%eax
  const unsigned char *a = a_;
  const unsigned char *b = b_;

  ASSERT (a != NULL || size == 0);
c0027a1f:	85 c0                	test   %eax,%eax
c0027a21:	0f 94 c2             	sete   %dl
c0027a24:	85 db                	test   %ebx,%ebx
c0027a26:	75 30                	jne    c0027a58 <memcmp+0x4b>
c0027a28:	84 d2                	test   %dl,%dl
c0027a2a:	75 2c                	jne    c0027a58 <memcmp+0x4b>
c0027a2c:	c7 44 24 10 ef f9 02 	movl   $0xc002f9ef,0x10(%esp)
c0027a33:	c0 
c0027a34:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027a3b:	c0 
c0027a3c:	c7 44 24 08 aa dc 02 	movl   $0xc002dcaa,0x8(%esp)
c0027a43:	c0 
c0027a44:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
c0027a4b:	00 
c0027a4c:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027a53:	e8 6b 0f 00 00       	call   c00289c3 <debug_panic>
  ASSERT (b != NULL || size == 0);
c0027a58:	85 f6                	test   %esi,%esi
c0027a5a:	75 04                	jne    c0027a60 <memcmp+0x53>
c0027a5c:	84 d2                	test   %dl,%dl
c0027a5e:	74 18                	je     c0027a78 <memcmp+0x6b>

  for (; size-- > 0; a++, b++)
c0027a60:	8d 78 ff             	lea    -0x1(%eax),%edi
c0027a63:	85 c0                	test   %eax,%eax
c0027a65:	74 64                	je     c0027acb <memcmp+0xbe>
    if (*a != *b)
c0027a67:	0f b6 13             	movzbl (%ebx),%edx
c0027a6a:	0f b6 0e             	movzbl (%esi),%ecx
c0027a6d:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a72:	38 ca                	cmp    %cl,%dl
c0027a74:	74 4a                	je     c0027ac0 <memcmp+0xb3>
c0027a76:	eb 3c                	jmp    c0027ab4 <memcmp+0xa7>
  ASSERT (b != NULL || size == 0);
c0027a78:	c7 44 24 10 06 fa 02 	movl   $0xc002fa06,0x10(%esp)
c0027a7f:	c0 
c0027a80:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027a87:	c0 
c0027a88:	c7 44 24 08 aa dc 02 	movl   $0xc002dcaa,0x8(%esp)
c0027a8f:	c0 
c0027a90:	c7 44 24 04 3b 00 00 	movl   $0x3b,0x4(%esp)
c0027a97:	00 
c0027a98:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027a9f:	e8 1f 0f 00 00       	call   c00289c3 <debug_panic>
    if (*a != *b)
c0027aa4:	0f b6 54 03 01       	movzbl 0x1(%ebx,%eax,1),%edx
c0027aa9:	83 c0 01             	add    $0x1,%eax
c0027aac:	0f b6 0c 06          	movzbl (%esi,%eax,1),%ecx
c0027ab0:	38 ca                	cmp    %cl,%dl
c0027ab2:	74 0c                	je     c0027ac0 <memcmp+0xb3>
      return *a > *b ? +1 : -1;
c0027ab4:	38 d1                	cmp    %dl,%cl
c0027ab6:	19 c0                	sbb    %eax,%eax
c0027ab8:	83 e0 02             	and    $0x2,%eax
c0027abb:	83 e8 01             	sub    $0x1,%eax
c0027abe:	eb 10                	jmp    c0027ad0 <memcmp+0xc3>
  for (; size-- > 0; a++, b++)
c0027ac0:	39 f8                	cmp    %edi,%eax
c0027ac2:	75 e0                	jne    c0027aa4 <memcmp+0x97>
  return 0;
c0027ac4:	b8 00 00 00 00       	mov    $0x0,%eax
c0027ac9:	eb 05                	jmp    c0027ad0 <memcmp+0xc3>
c0027acb:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027ad0:	83 c4 20             	add    $0x20,%esp
c0027ad3:	5b                   	pop    %ebx
c0027ad4:	5e                   	pop    %esi
c0027ad5:	5f                   	pop    %edi
c0027ad6:	c3                   	ret    

c0027ad7 <strcmp>:
   char) is greater, a negative value if the character in B (as
   an unsigned char) is greater, or zero if strings A and B are
   equal. */
int
strcmp (const char *a_, const char *b_) 
{
c0027ad7:	83 ec 2c             	sub    $0x2c,%esp
c0027ada:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c0027ade:	8b 54 24 34          	mov    0x34(%esp),%edx
  const unsigned char *a = (const unsigned char *) a_;
  const unsigned char *b = (const unsigned char *) b_;

  ASSERT (a != NULL);
c0027ae2:	85 c9                	test   %ecx,%ecx
c0027ae4:	75 2c                	jne    c0027b12 <strcmp+0x3b>
c0027ae6:	c7 44 24 10 59 ea 02 	movl   $0xc002ea59,0x10(%esp)
c0027aed:	c0 
c0027aee:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027af5:	c0 
c0027af6:	c7 44 24 08 a3 dc 02 	movl   $0xc002dca3,0x8(%esp)
c0027afd:	c0 
c0027afe:	c7 44 24 04 4e 00 00 	movl   $0x4e,0x4(%esp)
c0027b05:	00 
c0027b06:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027b0d:	e8 b1 0e 00 00       	call   c00289c3 <debug_panic>
  ASSERT (b != NULL);
c0027b12:	85 d2                	test   %edx,%edx
c0027b14:	74 0e                	je     c0027b24 <strcmp+0x4d>

  while (*a != '\0' && *a == *b) 
c0027b16:	0f b6 01             	movzbl (%ecx),%eax
c0027b19:	84 c0                	test   %al,%al
c0027b1b:	74 44                	je     c0027b61 <strcmp+0x8a>
c0027b1d:	3a 02                	cmp    (%edx),%al
c0027b1f:	90                   	nop
c0027b20:	74 2e                	je     c0027b50 <strcmp+0x79>
c0027b22:	eb 3d                	jmp    c0027b61 <strcmp+0x8a>
  ASSERT (b != NULL);
c0027b24:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0027b2b:	c0 
c0027b2c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027b33:	c0 
c0027b34:	c7 44 24 08 a3 dc 02 	movl   $0xc002dca3,0x8(%esp)
c0027b3b:	c0 
c0027b3c:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c0027b43:	00 
c0027b44:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027b4b:	e8 73 0e 00 00       	call   c00289c3 <debug_panic>
    {
      a++;
c0027b50:	83 c1 01             	add    $0x1,%ecx
      b++;
c0027b53:	83 c2 01             	add    $0x1,%edx
  while (*a != '\0' && *a == *b) 
c0027b56:	0f b6 01             	movzbl (%ecx),%eax
c0027b59:	84 c0                	test   %al,%al
c0027b5b:	74 04                	je     c0027b61 <strcmp+0x8a>
c0027b5d:	3a 02                	cmp    (%edx),%al
c0027b5f:	74 ef                	je     c0027b50 <strcmp+0x79>
    }

  return *a < *b ? -1 : *a > *b;
c0027b61:	0f b6 12             	movzbl (%edx),%edx
c0027b64:	38 c2                	cmp    %al,%dl
c0027b66:	77 0a                	ja     c0027b72 <strcmp+0x9b>
c0027b68:	38 d0                	cmp    %dl,%al
c0027b6a:	0f 97 c0             	seta   %al
c0027b6d:	0f b6 c0             	movzbl %al,%eax
c0027b70:	eb 05                	jmp    c0027b77 <strcmp+0xa0>
c0027b72:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0027b77:	83 c4 2c             	add    $0x2c,%esp
c0027b7a:	c3                   	ret    

c0027b7b <memchr>:
/* Returns a pointer to the first occurrence of CH in the first
   SIZE bytes starting at BLOCK.  Returns a null pointer if CH
   does not occur in BLOCK. */
void *
memchr (const void *block_, int ch_, size_t size) 
{
c0027b7b:	56                   	push   %esi
c0027b7c:	53                   	push   %ebx
c0027b7d:	83 ec 24             	sub    $0x24,%esp
c0027b80:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027b84:	8b 74 24 34          	mov    0x34(%esp),%esi
c0027b88:	8b 54 24 38          	mov    0x38(%esp),%edx
  const unsigned char *block = block_;
  unsigned char ch = ch_;
c0027b8c:	89 f3                	mov    %esi,%ebx

  ASSERT (block != NULL || size == 0);
c0027b8e:	85 c0                	test   %eax,%eax
c0027b90:	75 04                	jne    c0027b96 <memchr+0x1b>
c0027b92:	85 d2                	test   %edx,%edx
c0027b94:	75 14                	jne    c0027baa <memchr+0x2f>

  for (; size-- > 0; block++)
c0027b96:	8d 4a ff             	lea    -0x1(%edx),%ecx
c0027b99:	85 d2                	test   %edx,%edx
c0027b9b:	74 4e                	je     c0027beb <memchr+0x70>
    if (*block == ch)
c0027b9d:	89 f2                	mov    %esi,%edx
c0027b9f:	38 10                	cmp    %dl,(%eax)
c0027ba1:	74 4d                	je     c0027bf0 <memchr+0x75>
c0027ba3:	ba 00 00 00 00       	mov    $0x0,%edx
c0027ba8:	eb 33                	jmp    c0027bdd <memchr+0x62>
  ASSERT (block != NULL || size == 0);
c0027baa:	c7 44 24 10 27 fa 02 	movl   $0xc002fa27,0x10(%esp)
c0027bb1:	c0 
c0027bb2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027bb9:	c0 
c0027bba:	c7 44 24 08 9c dc 02 	movl   $0xc002dc9c,0x8(%esp)
c0027bc1:	c0 
c0027bc2:	c7 44 24 04 63 00 00 	movl   $0x63,0x4(%esp)
c0027bc9:	00 
c0027bca:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027bd1:	e8 ed 0d 00 00       	call   c00289c3 <debug_panic>
c0027bd6:	83 c2 01             	add    $0x1,%edx
    if (*block == ch)
c0027bd9:	38 18                	cmp    %bl,(%eax)
c0027bdb:	74 13                	je     c0027bf0 <memchr+0x75>
  for (; size-- > 0; block++)
c0027bdd:	83 c0 01             	add    $0x1,%eax
c0027be0:	39 ca                	cmp    %ecx,%edx
c0027be2:	75 f2                	jne    c0027bd6 <memchr+0x5b>
      return (void *) block;

  return NULL;
c0027be4:	b8 00 00 00 00       	mov    $0x0,%eax
c0027be9:	eb 05                	jmp    c0027bf0 <memchr+0x75>
c0027beb:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027bf0:	83 c4 24             	add    $0x24,%esp
c0027bf3:	5b                   	pop    %ebx
c0027bf4:	5e                   	pop    %esi
c0027bf5:	c3                   	ret    

c0027bf6 <strchr>:
   null pointer if C does not appear in STRING.  If C == '\0'
   then returns a pointer to the null terminator at the end of
   STRING. */
char *
strchr (const char *string, int c_) 
{
c0027bf6:	53                   	push   %ebx
c0027bf7:	83 ec 28             	sub    $0x28,%esp
c0027bfa:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027bfe:	8b 54 24 34          	mov    0x34(%esp),%edx
  char c = c_;

  ASSERT (string != NULL);
c0027c02:	85 c0                	test   %eax,%eax
c0027c04:	74 0b                	je     c0027c11 <strchr+0x1b>
c0027c06:	89 d1                	mov    %edx,%ecx

  for (;;) 
    if (*string == c)
c0027c08:	0f b6 18             	movzbl (%eax),%ebx
c0027c0b:	38 d3                	cmp    %dl,%bl
c0027c0d:	75 2e                	jne    c0027c3d <strchr+0x47>
c0027c0f:	eb 4e                	jmp    c0027c5f <strchr+0x69>
  ASSERT (string != NULL);
c0027c11:	c7 44 24 10 42 fa 02 	movl   $0xc002fa42,0x10(%esp)
c0027c18:	c0 
c0027c19:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027c20:	c0 
c0027c21:	c7 44 24 08 95 dc 02 	movl   $0xc002dc95,0x8(%esp)
c0027c28:	c0 
c0027c29:	c7 44 24 04 75 00 00 	movl   $0x75,0x4(%esp)
c0027c30:	00 
c0027c31:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027c38:	e8 86 0d 00 00       	call   c00289c3 <debug_panic>
      return (char *) string;
    else if (*string == '\0')
c0027c3d:	84 db                	test   %bl,%bl
c0027c3f:	75 06                	jne    c0027c47 <strchr+0x51>
c0027c41:	eb 10                	jmp    c0027c53 <strchr+0x5d>
c0027c43:	84 d2                	test   %dl,%dl
c0027c45:	74 13                	je     c0027c5a <strchr+0x64>
      return NULL;
    else
      string++;
c0027c47:	83 c0 01             	add    $0x1,%eax
    if (*string == c)
c0027c4a:	0f b6 10             	movzbl (%eax),%edx
c0027c4d:	38 ca                	cmp    %cl,%dl
c0027c4f:	75 f2                	jne    c0027c43 <strchr+0x4d>
c0027c51:	eb 0c                	jmp    c0027c5f <strchr+0x69>
      return NULL;
c0027c53:	b8 00 00 00 00       	mov    $0x0,%eax
c0027c58:	eb 05                	jmp    c0027c5f <strchr+0x69>
c0027c5a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027c5f:	83 c4 28             	add    $0x28,%esp
c0027c62:	5b                   	pop    %ebx
c0027c63:	c3                   	ret    

c0027c64 <strcspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters that are not in STOP. */
size_t
strcspn (const char *string, const char *stop) 
{
c0027c64:	57                   	push   %edi
c0027c65:	56                   	push   %esi
c0027c66:	53                   	push   %ebx
c0027c67:	83 ec 10             	sub    $0x10,%esp
c0027c6a:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027c6e:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;

  for (length = 0; string[length] != '\0'; length++)
c0027c72:	0f b6 16             	movzbl (%esi),%edx
c0027c75:	84 d2                	test   %dl,%dl
c0027c77:	74 25                	je     c0027c9e <strcspn+0x3a>
c0027c79:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (stop, string[length]) != NULL)
c0027c7e:	0f be d2             	movsbl %dl,%edx
c0027c81:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c85:	89 3c 24             	mov    %edi,(%esp)
c0027c88:	e8 69 ff ff ff       	call   c0027bf6 <strchr>
c0027c8d:	85 c0                	test   %eax,%eax
c0027c8f:	75 12                	jne    c0027ca3 <strcspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027c91:	83 c3 01             	add    $0x1,%ebx
c0027c94:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027c98:	84 d2                	test   %dl,%dl
c0027c9a:	75 e2                	jne    c0027c7e <strcspn+0x1a>
c0027c9c:	eb 05                	jmp    c0027ca3 <strcspn+0x3f>
c0027c9e:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027ca3:	89 d8                	mov    %ebx,%eax
c0027ca5:	83 c4 10             	add    $0x10,%esp
c0027ca8:	5b                   	pop    %ebx
c0027ca9:	5e                   	pop    %esi
c0027caa:	5f                   	pop    %edi
c0027cab:	c3                   	ret    

c0027cac <strpbrk>:
/* Returns a pointer to the first character in STRING that is
   also in STOP.  If no character in STRING is in STOP, returns a
   null pointer. */
char *
strpbrk (const char *string, const char *stop) 
{
c0027cac:	56                   	push   %esi
c0027cad:	53                   	push   %ebx
c0027cae:	83 ec 14             	sub    $0x14,%esp
c0027cb1:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0027cb5:	8b 74 24 24          	mov    0x24(%esp),%esi
  for (; *string != '\0'; string++)
c0027cb9:	0f b6 13             	movzbl (%ebx),%edx
c0027cbc:	84 d2                	test   %dl,%dl
c0027cbe:	74 1f                	je     c0027cdf <strpbrk+0x33>
    if (strchr (stop, *string) != NULL)
c0027cc0:	0f be d2             	movsbl %dl,%edx
c0027cc3:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027cc7:	89 34 24             	mov    %esi,(%esp)
c0027cca:	e8 27 ff ff ff       	call   c0027bf6 <strchr>
c0027ccf:	85 c0                	test   %eax,%eax
c0027cd1:	75 13                	jne    c0027ce6 <strpbrk+0x3a>
  for (; *string != '\0'; string++)
c0027cd3:	83 c3 01             	add    $0x1,%ebx
c0027cd6:	0f b6 13             	movzbl (%ebx),%edx
c0027cd9:	84 d2                	test   %dl,%dl
c0027cdb:	75 e3                	jne    c0027cc0 <strpbrk+0x14>
c0027cdd:	eb 09                	jmp    c0027ce8 <strpbrk+0x3c>
      return (char *) string;
  return NULL;
c0027cdf:	b8 00 00 00 00       	mov    $0x0,%eax
c0027ce4:	eb 02                	jmp    c0027ce8 <strpbrk+0x3c>
c0027ce6:	89 d8                	mov    %ebx,%eax
}
c0027ce8:	83 c4 14             	add    $0x14,%esp
c0027ceb:	5b                   	pop    %ebx
c0027cec:	5e                   	pop    %esi
c0027ced:	c3                   	ret    

c0027cee <strrchr>:

/* Returns a pointer to the last occurrence of C in STRING.
   Returns a null pointer if C does not occur in STRING. */
char *
strrchr (const char *string, int c_) 
{
c0027cee:	53                   	push   %ebx
c0027cef:	8b 54 24 08          	mov    0x8(%esp),%edx
  char c = c_;
c0027cf3:	0f b6 5c 24 0c       	movzbl 0xc(%esp),%ebx
  const char *p = NULL;

  for (; *string != '\0'; string++)
c0027cf8:	0f b6 0a             	movzbl (%edx),%ecx
c0027cfb:	84 c9                	test   %cl,%cl
c0027cfd:	74 16                	je     c0027d15 <strrchr+0x27>
  const char *p = NULL;
c0027cff:	b8 00 00 00 00       	mov    $0x0,%eax
c0027d04:	38 cb                	cmp    %cl,%bl
c0027d06:	0f 44 c2             	cmove  %edx,%eax
  for (; *string != '\0'; string++)
c0027d09:	83 c2 01             	add    $0x1,%edx
c0027d0c:	0f b6 0a             	movzbl (%edx),%ecx
c0027d0f:	84 c9                	test   %cl,%cl
c0027d11:	75 f1                	jne    c0027d04 <strrchr+0x16>
c0027d13:	eb 05                	jmp    c0027d1a <strrchr+0x2c>
  const char *p = NULL;
c0027d15:	b8 00 00 00 00       	mov    $0x0,%eax
    if (*string == c)
      p = string;
  return (char *) p;
}
c0027d1a:	5b                   	pop    %ebx
c0027d1b:	c3                   	ret    

c0027d1c <strspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters in SKIP. */
size_t
strspn (const char *string, const char *skip) 
{
c0027d1c:	57                   	push   %edi
c0027d1d:	56                   	push   %esi
c0027d1e:	53                   	push   %ebx
c0027d1f:	83 ec 10             	sub    $0x10,%esp
c0027d22:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027d26:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;
  
  for (length = 0; string[length] != '\0'; length++)
c0027d2a:	0f b6 16             	movzbl (%esi),%edx
c0027d2d:	84 d2                	test   %dl,%dl
c0027d2f:	74 25                	je     c0027d56 <strspn+0x3a>
c0027d31:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (skip, string[length]) == NULL)
c0027d36:	0f be d2             	movsbl %dl,%edx
c0027d39:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027d3d:	89 3c 24             	mov    %edi,(%esp)
c0027d40:	e8 b1 fe ff ff       	call   c0027bf6 <strchr>
c0027d45:	85 c0                	test   %eax,%eax
c0027d47:	74 12                	je     c0027d5b <strspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027d49:	83 c3 01             	add    $0x1,%ebx
c0027d4c:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027d50:	84 d2                	test   %dl,%dl
c0027d52:	75 e2                	jne    c0027d36 <strspn+0x1a>
c0027d54:	eb 05                	jmp    c0027d5b <strspn+0x3f>
c0027d56:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027d5b:	89 d8                	mov    %ebx,%eax
c0027d5d:	83 c4 10             	add    $0x10,%esp
c0027d60:	5b                   	pop    %ebx
c0027d61:	5e                   	pop    %esi
c0027d62:	5f                   	pop    %edi
c0027d63:	c3                   	ret    

c0027d64 <strtok_r>:
     'to'
     'tokenize.'
*/
char *
strtok_r (char *s, const char *delimiters, char **save_ptr) 
{
c0027d64:	55                   	push   %ebp
c0027d65:	57                   	push   %edi
c0027d66:	56                   	push   %esi
c0027d67:	53                   	push   %ebx
c0027d68:	83 ec 2c             	sub    $0x2c,%esp
c0027d6b:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c0027d6f:	8b 74 24 44          	mov    0x44(%esp),%esi
  char *token;
  
  ASSERT (delimiters != NULL);
c0027d73:	85 f6                	test   %esi,%esi
c0027d75:	75 2c                	jne    c0027da3 <strtok_r+0x3f>
c0027d77:	c7 44 24 10 51 fa 02 	movl   $0xc002fa51,0x10(%esp)
c0027d7e:	c0 
c0027d7f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027d86:	c0 
c0027d87:	c7 44 24 08 8c dc 02 	movl   $0xc002dc8c,0x8(%esp)
c0027d8e:	c0 
c0027d8f:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0027d96:	00 
c0027d97:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027d9e:	e8 20 0c 00 00       	call   c00289c3 <debug_panic>
  ASSERT (save_ptr != NULL);
c0027da3:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0027da8:	75 2c                	jne    c0027dd6 <strtok_r+0x72>
c0027daa:	c7 44 24 10 64 fa 02 	movl   $0xc002fa64,0x10(%esp)
c0027db1:	c0 
c0027db2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027db9:	c0 
c0027dba:	c7 44 24 08 8c dc 02 	movl   $0xc002dc8c,0x8(%esp)
c0027dc1:	c0 
c0027dc2:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c0027dc9:	00 
c0027dca:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027dd1:	e8 ed 0b 00 00       	call   c00289c3 <debug_panic>

  /* If S is nonnull, start from it.
     If S is null, start from saved position. */
  if (s == NULL)
c0027dd6:	85 db                	test   %ebx,%ebx
c0027dd8:	75 4c                	jne    c0027e26 <strtok_r+0xc2>
    s = *save_ptr;
c0027dda:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027dde:	8b 18                	mov    (%eax),%ebx
  ASSERT (s != NULL);
c0027de0:	85 db                	test   %ebx,%ebx
c0027de2:	75 42                	jne    c0027e26 <strtok_r+0xc2>
c0027de4:	c7 44 24 10 5a fa 02 	movl   $0xc002fa5a,0x10(%esp)
c0027deb:	c0 
c0027dec:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027df3:	c0 
c0027df4:	c7 44 24 08 8c dc 02 	movl   $0xc002dc8c,0x8(%esp)
c0027dfb:	c0 
c0027dfc:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0027e03:	00 
c0027e04:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027e0b:	e8 b3 0b 00 00       	call   c00289c3 <debug_panic>
  while (strchr (delimiters, *s) != NULL) 
    {
      /* strchr() will always return nonnull if we're searching
         for a null byte, because every string contains a null
         byte (at the end). */
      if (*s == '\0')
c0027e10:	89 f8                	mov    %edi,%eax
c0027e12:	84 c0                	test   %al,%al
c0027e14:	75 0d                	jne    c0027e23 <strtok_r+0xbf>
        {
          *save_ptr = s;
c0027e16:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e1a:	89 18                	mov    %ebx,(%eax)
          return NULL;
c0027e1c:	b8 00 00 00 00       	mov    $0x0,%eax
c0027e21:	eb 56                	jmp    c0027e79 <strtok_r+0x115>
        }

      s++;
c0027e23:	83 c3 01             	add    $0x1,%ebx
  while (strchr (delimiters, *s) != NULL) 
c0027e26:	0f b6 3b             	movzbl (%ebx),%edi
c0027e29:	89 f8                	mov    %edi,%eax
c0027e2b:	0f be c0             	movsbl %al,%eax
c0027e2e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027e32:	89 34 24             	mov    %esi,(%esp)
c0027e35:	e8 bc fd ff ff       	call   c0027bf6 <strchr>
c0027e3a:	85 c0                	test   %eax,%eax
c0027e3c:	75 d2                	jne    c0027e10 <strtok_r+0xac>
c0027e3e:	89 df                	mov    %ebx,%edi
    }

  /* Skip any non-DELIMITERS up to the end of the string. */
  token = s;
  while (strchr (delimiters, *s) == NULL)
    s++;
c0027e40:	83 c7 01             	add    $0x1,%edi
  while (strchr (delimiters, *s) == NULL)
c0027e43:	0f b6 2f             	movzbl (%edi),%ebp
c0027e46:	89 e8                	mov    %ebp,%eax
c0027e48:	0f be c0             	movsbl %al,%eax
c0027e4b:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027e4f:	89 34 24             	mov    %esi,(%esp)
c0027e52:	e8 9f fd ff ff       	call   c0027bf6 <strchr>
c0027e57:	85 c0                	test   %eax,%eax
c0027e59:	74 e5                	je     c0027e40 <strtok_r+0xdc>
  if (*s != '\0') 
c0027e5b:	89 e8                	mov    %ebp,%eax
c0027e5d:	84 c0                	test   %al,%al
c0027e5f:	74 10                	je     c0027e71 <strtok_r+0x10d>
    {
      *s = '\0';
c0027e61:	c6 07 00             	movb   $0x0,(%edi)
      *save_ptr = s + 1;
c0027e64:	83 c7 01             	add    $0x1,%edi
c0027e67:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e6b:	89 38                	mov    %edi,(%eax)
c0027e6d:	89 d8                	mov    %ebx,%eax
c0027e6f:	eb 08                	jmp    c0027e79 <strtok_r+0x115>
    }
  else 
    *save_ptr = s;
c0027e71:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e75:	89 38                	mov    %edi,(%eax)
c0027e77:	89 d8                	mov    %ebx,%eax
  return token;
}
c0027e79:	83 c4 2c             	add    $0x2c,%esp
c0027e7c:	5b                   	pop    %ebx
c0027e7d:	5e                   	pop    %esi
c0027e7e:	5f                   	pop    %edi
c0027e7f:	5d                   	pop    %ebp
c0027e80:	c3                   	ret    

c0027e81 <memset>:

/* Sets the SIZE bytes in DST to VALUE. */
void *
memset (void *dst_, int value, size_t size) 
{
c0027e81:	56                   	push   %esi
c0027e82:	53                   	push   %ebx
c0027e83:	83 ec 24             	sub    $0x24,%esp
c0027e86:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027e8a:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c0027e8e:	8b 74 24 38          	mov    0x38(%esp),%esi
  unsigned char *dst = dst_;

  ASSERT (dst != NULL || size == 0);
c0027e92:	85 c0                	test   %eax,%eax
c0027e94:	75 04                	jne    c0027e9a <memset+0x19>
c0027e96:	85 f6                	test   %esi,%esi
c0027e98:	75 0b                	jne    c0027ea5 <memset+0x24>
c0027e9a:	8d 0c 30             	lea    (%eax,%esi,1),%ecx
  
  while (size-- > 0)
c0027e9d:	89 c2                	mov    %eax,%edx
c0027e9f:	85 f6                	test   %esi,%esi
c0027ea1:	75 2e                	jne    c0027ed1 <memset+0x50>
c0027ea3:	eb 36                	jmp    c0027edb <memset+0x5a>
  ASSERT (dst != NULL || size == 0);
c0027ea5:	c7 44 24 10 aa f9 02 	movl   $0xc002f9aa,0x10(%esp)
c0027eac:	c0 
c0027ead:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027eb4:	c0 
c0027eb5:	c7 44 24 08 85 dc 02 	movl   $0xc002dc85,0x8(%esp)
c0027ebc:	c0 
c0027ebd:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c0027ec4:	00 
c0027ec5:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027ecc:	e8 f2 0a 00 00       	call   c00289c3 <debug_panic>
    *dst++ = value;
c0027ed1:	83 c2 01             	add    $0x1,%edx
c0027ed4:	88 5a ff             	mov    %bl,-0x1(%edx)
  while (size-- > 0)
c0027ed7:	39 ca                	cmp    %ecx,%edx
c0027ed9:	75 f6                	jne    c0027ed1 <memset+0x50>

  return dst_;
}
c0027edb:	83 c4 24             	add    $0x24,%esp
c0027ede:	5b                   	pop    %ebx
c0027edf:	5e                   	pop    %esi
c0027ee0:	c3                   	ret    

c0027ee1 <strlen>:

/* Returns the length of STRING. */
size_t
strlen (const char *string) 
{
c0027ee1:	83 ec 2c             	sub    $0x2c,%esp
c0027ee4:	8b 54 24 30          	mov    0x30(%esp),%edx
  const char *p;

  ASSERT (string != NULL);
c0027ee8:	85 d2                	test   %edx,%edx
c0027eea:	74 09                	je     c0027ef5 <strlen+0x14>

  for (p = string; *p != '\0'; p++)
c0027eec:	89 d0                	mov    %edx,%eax
c0027eee:	80 3a 00             	cmpb   $0x0,(%edx)
c0027ef1:	74 38                	je     c0027f2b <strlen+0x4a>
c0027ef3:	eb 2c                	jmp    c0027f21 <strlen+0x40>
  ASSERT (string != NULL);
c0027ef5:	c7 44 24 10 42 fa 02 	movl   $0xc002fa42,0x10(%esp)
c0027efc:	c0 
c0027efd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027f04:	c0 
c0027f05:	c7 44 24 08 7e dc 02 	movl   $0xc002dc7e,0x8(%esp)
c0027f0c:	c0 
c0027f0d:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c0027f14:	00 
c0027f15:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027f1c:	e8 a2 0a 00 00       	call   c00289c3 <debug_panic>
  for (p = string; *p != '\0'; p++)
c0027f21:	89 d0                	mov    %edx,%eax
c0027f23:	83 c0 01             	add    $0x1,%eax
c0027f26:	80 38 00             	cmpb   $0x0,(%eax)
c0027f29:	75 f8                	jne    c0027f23 <strlen+0x42>
    continue;
  return p - string;
c0027f2b:	29 d0                	sub    %edx,%eax
}
c0027f2d:	83 c4 2c             	add    $0x2c,%esp
c0027f30:	c3                   	ret    

c0027f31 <strstr>:
{
c0027f31:	55                   	push   %ebp
c0027f32:	57                   	push   %edi
c0027f33:	56                   	push   %esi
c0027f34:	53                   	push   %ebx
c0027f35:	83 ec 1c             	sub    $0x1c,%esp
c0027f38:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  size_t haystack_len = strlen (haystack);
c0027f3c:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c0027f41:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0027f45:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f4a:	89 d9                	mov    %ebx,%ecx
c0027f4c:	f2 ae                	repnz scas %es:(%edi),%al
c0027f4e:	f7 d1                	not    %ecx
c0027f50:	8d 51 ff             	lea    -0x1(%ecx),%edx
  size_t needle_len = strlen (needle);
c0027f53:	89 ef                	mov    %ebp,%edi
c0027f55:	89 d9                	mov    %ebx,%ecx
c0027f57:	f2 ae                	repnz scas %es:(%edi),%al
c0027f59:	f7 d1                	not    %ecx
c0027f5b:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (haystack_len >= needle_len) 
c0027f5e:	39 fa                	cmp    %edi,%edx
c0027f60:	72 30                	jb     c0027f92 <strstr+0x61>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f62:	29 fa                	sub    %edi,%edx
c0027f64:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0027f68:	bb 00 00 00 00       	mov    $0x0,%ebx
c0027f6d:	89 de                	mov    %ebx,%esi
c0027f6f:	03 74 24 30          	add    0x30(%esp),%esi
        if (!memcmp (haystack + i, needle, needle_len))
c0027f73:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0027f77:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0027f7b:	89 34 24             	mov    %esi,(%esp)
c0027f7e:	e8 8a fa ff ff       	call   c0027a0d <memcmp>
c0027f83:	85 c0                	test   %eax,%eax
c0027f85:	74 12                	je     c0027f99 <strstr+0x68>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f87:	83 c3 01             	add    $0x1,%ebx
c0027f8a:	3b 5c 24 0c          	cmp    0xc(%esp),%ebx
c0027f8e:	76 dd                	jbe    c0027f6d <strstr+0x3c>
c0027f90:	eb 0b                	jmp    c0027f9d <strstr+0x6c>
  return NULL;
c0027f92:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f97:	eb 09                	jmp    c0027fa2 <strstr+0x71>
        if (!memcmp (haystack + i, needle, needle_len))
c0027f99:	89 f0                	mov    %esi,%eax
c0027f9b:	eb 05                	jmp    c0027fa2 <strstr+0x71>
  return NULL;
c0027f9d:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027fa2:	83 c4 1c             	add    $0x1c,%esp
c0027fa5:	5b                   	pop    %ebx
c0027fa6:	5e                   	pop    %esi
c0027fa7:	5f                   	pop    %edi
c0027fa8:	5d                   	pop    %ebp
c0027fa9:	c3                   	ret    

c0027faa <strnlen>:

/* If STRING is less than MAXLEN characters in length, returns
   its actual length.  Otherwise, returns MAXLEN. */
size_t
strnlen (const char *string, size_t maxlen) 
{
c0027faa:	8b 54 24 04          	mov    0x4(%esp),%edx
c0027fae:	8b 4c 24 08          	mov    0x8(%esp),%ecx
  size_t length;

  for (length = 0; string[length] != '\0' && length < maxlen; length++)
c0027fb2:	80 3a 00             	cmpb   $0x0,(%edx)
c0027fb5:	74 18                	je     c0027fcf <strnlen+0x25>
c0027fb7:	b8 00 00 00 00       	mov    $0x0,%eax
c0027fbc:	85 c9                	test   %ecx,%ecx
c0027fbe:	74 14                	je     c0027fd4 <strnlen+0x2a>
c0027fc0:	83 c0 01             	add    $0x1,%eax
c0027fc3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
c0027fc7:	74 0b                	je     c0027fd4 <strnlen+0x2a>
c0027fc9:	39 c8                	cmp    %ecx,%eax
c0027fcb:	74 07                	je     c0027fd4 <strnlen+0x2a>
c0027fcd:	eb f1                	jmp    c0027fc0 <strnlen+0x16>
c0027fcf:	b8 00 00 00 00       	mov    $0x0,%eax
    continue;
  return length;
}
c0027fd4:	f3 c3                	repz ret 

c0027fd6 <strlcpy>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcpy (char *dst, const char *src, size_t size) 
{
c0027fd6:	57                   	push   %edi
c0027fd7:	56                   	push   %esi
c0027fd8:	53                   	push   %ebx
c0027fd9:	83 ec 20             	sub    $0x20,%esp
c0027fdc:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027fe0:	8b 54 24 34          	mov    0x34(%esp),%edx
c0027fe4:	8b 74 24 38          	mov    0x38(%esp),%esi
  size_t src_len;

  ASSERT (dst != NULL);
c0027fe8:	85 db                	test   %ebx,%ebx
c0027fea:	75 2c                	jne    c0028018 <strlcpy+0x42>
c0027fec:	c7 44 24 10 75 fa 02 	movl   $0xc002fa75,0x10(%esp)
c0027ff3:	c0 
c0027ff4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027ffb:	c0 
c0027ffc:	c7 44 24 08 76 dc 02 	movl   $0xc002dc76,0x8(%esp)
c0028003:	c0 
c0028004:	c7 44 24 04 4a 01 00 	movl   $0x14a,0x4(%esp)
c002800b:	00 
c002800c:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0028013:	e8 ab 09 00 00       	call   c00289c3 <debug_panic>
  ASSERT (src != NULL);
c0028018:	85 d2                	test   %edx,%edx
c002801a:	75 2c                	jne    c0028048 <strlcpy+0x72>
c002801c:	c7 44 24 10 81 fa 02 	movl   $0xc002fa81,0x10(%esp)
c0028023:	c0 
c0028024:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002802b:	c0 
c002802c:	c7 44 24 08 76 dc 02 	movl   $0xc002dc76,0x8(%esp)
c0028033:	c0 
c0028034:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
c002803b:	00 
c002803c:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0028043:	e8 7b 09 00 00       	call   c00289c3 <debug_panic>

  src_len = strlen (src);
c0028048:	89 d7                	mov    %edx,%edi
c002804a:	b8 00 00 00 00       	mov    $0x0,%eax
c002804f:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028054:	f2 ae                	repnz scas %es:(%edi),%al
c0028056:	f7 d1                	not    %ecx
c0028058:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (size > 0) 
c002805b:	85 f6                	test   %esi,%esi
c002805d:	74 1c                	je     c002807b <strlcpy+0xa5>
    {
      size_t dst_len = size - 1;
c002805f:	83 ee 01             	sub    $0x1,%esi
c0028062:	39 f7                	cmp    %esi,%edi
c0028064:	0f 46 f7             	cmovbe %edi,%esi
      if (src_len < dst_len)
        dst_len = src_len;
      memcpy (dst, src, dst_len);
c0028067:	89 74 24 08          	mov    %esi,0x8(%esp)
c002806b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002806f:	89 1c 24             	mov    %ebx,(%esp)
c0028072:	e8 29 f8 ff ff       	call   c00278a0 <memcpy>
      dst[dst_len] = '\0';
c0028077:	c6 04 33 00          	movb   $0x0,(%ebx,%esi,1)
    }
  return src_len;
}
c002807b:	89 f8                	mov    %edi,%eax
c002807d:	83 c4 20             	add    $0x20,%esp
c0028080:	5b                   	pop    %ebx
c0028081:	5e                   	pop    %esi
c0028082:	5f                   	pop    %edi
c0028083:	c3                   	ret    

c0028084 <strlcat>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcat (char *dst, const char *src, size_t size) 
{
c0028084:	55                   	push   %ebp
c0028085:	57                   	push   %edi
c0028086:	56                   	push   %esi
c0028087:	53                   	push   %ebx
c0028088:	83 ec 2c             	sub    $0x2c,%esp
c002808b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
c002808f:	8b 54 24 44          	mov    0x44(%esp),%edx
  size_t src_len, dst_len;

  ASSERT (dst != NULL);
c0028093:	85 ed                	test   %ebp,%ebp
c0028095:	75 2c                	jne    c00280c3 <strlcat+0x3f>
c0028097:	c7 44 24 10 75 fa 02 	movl   $0xc002fa75,0x10(%esp)
c002809e:	c0 
c002809f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00280a6:	c0 
c00280a7:	c7 44 24 08 6e dc 02 	movl   $0xc002dc6e,0x8(%esp)
c00280ae:	c0 
c00280af:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
c00280b6:	00 
c00280b7:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00280be:	e8 00 09 00 00       	call   c00289c3 <debug_panic>
  ASSERT (src != NULL);
c00280c3:	85 d2                	test   %edx,%edx
c00280c5:	75 2c                	jne    c00280f3 <strlcat+0x6f>
c00280c7:	c7 44 24 10 81 fa 02 	movl   $0xc002fa81,0x10(%esp)
c00280ce:	c0 
c00280cf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00280d6:	c0 
c00280d7:	c7 44 24 08 6e dc 02 	movl   $0xc002dc6e,0x8(%esp)
c00280de:	c0 
c00280df:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
c00280e6:	00 
c00280e7:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00280ee:	e8 d0 08 00 00       	call   c00289c3 <debug_panic>

  src_len = strlen (src);
c00280f3:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c00280f8:	89 d7                	mov    %edx,%edi
c00280fa:	b8 00 00 00 00       	mov    $0x0,%eax
c00280ff:	89 d9                	mov    %ebx,%ecx
c0028101:	f2 ae                	repnz scas %es:(%edi),%al
c0028103:	f7 d1                	not    %ecx
c0028105:	8d 71 ff             	lea    -0x1(%ecx),%esi
  dst_len = strlen (dst);
c0028108:	89 ef                	mov    %ebp,%edi
c002810a:	89 d9                	mov    %ebx,%ecx
c002810c:	f2 ae                	repnz scas %es:(%edi),%al
c002810e:	89 cb                	mov    %ecx,%ebx
c0028110:	f7 d3                	not    %ebx
c0028112:	83 eb 01             	sub    $0x1,%ebx
  if (size > 0 && dst_len < size) 
c0028115:	3b 5c 24 48          	cmp    0x48(%esp),%ebx
c0028119:	73 2c                	jae    c0028147 <strlcat+0xc3>
c002811b:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0028120:	74 25                	je     c0028147 <strlcat+0xc3>
    {
      size_t copy_cnt = size - dst_len - 1;
c0028122:	8b 44 24 48          	mov    0x48(%esp),%eax
c0028126:	8d 78 ff             	lea    -0x1(%eax),%edi
c0028129:	29 df                	sub    %ebx,%edi
c002812b:	39 f7                	cmp    %esi,%edi
c002812d:	0f 47 fe             	cmova  %esi,%edi
      if (src_len < copy_cnt)
        copy_cnt = src_len;
      memcpy (dst + dst_len, src, copy_cnt);
c0028130:	01 dd                	add    %ebx,%ebp
c0028132:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0028136:	89 54 24 04          	mov    %edx,0x4(%esp)
c002813a:	89 2c 24             	mov    %ebp,(%esp)
c002813d:	e8 5e f7 ff ff       	call   c00278a0 <memcpy>
      dst[dst_len + copy_cnt] = '\0';
c0028142:	c6 44 3d 00 00       	movb   $0x0,0x0(%ebp,%edi,1)
    }
  return src_len + dst_len;
c0028147:	8d 04 33             	lea    (%ebx,%esi,1),%eax
}
c002814a:	83 c4 2c             	add    $0x2c,%esp
c002814d:	5b                   	pop    %ebx
c002814e:	5e                   	pop    %esi
c002814f:	5f                   	pop    %edi
c0028150:	5d                   	pop    %ebp
c0028151:	c3                   	ret    
c0028152:	90                   	nop
c0028153:	90                   	nop
c0028154:	90                   	nop
c0028155:	90                   	nop
c0028156:	90                   	nop
c0028157:	90                   	nop
c0028158:	90                   	nop
c0028159:	90                   	nop
c002815a:	90                   	nop
c002815b:	90                   	nop
c002815c:	90                   	nop
c002815d:	90                   	nop
c002815e:	90                   	nop
c002815f:	90                   	nop

c0028160 <udiv64>:

/* Divides unsigned 64-bit N by unsigned 64-bit D and returns the
   quotient. */
static uint64_t
udiv64 (uint64_t n, uint64_t d)
{
c0028160:	55                   	push   %ebp
c0028161:	57                   	push   %edi
c0028162:	56                   	push   %esi
c0028163:	53                   	push   %ebx
c0028164:	83 ec 1c             	sub    $0x1c,%esp
c0028167:	89 04 24             	mov    %eax,(%esp)
c002816a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002816e:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0028172:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  if ((d >> 32) == 0) 
c0028176:	89 ea                	mov    %ebp,%edx
c0028178:	85 ed                	test   %ebp,%ebp
c002817a:	75 37                	jne    c00281b3 <udiv64+0x53>
             <=> [b - 1/d] < b
         which is a tautology.

         Therefore, this code is correct and will not trap. */
      uint64_t b = 1ULL << 32;
      uint32_t n1 = n >> 32;
c002817c:	8b 44 24 04          	mov    0x4(%esp),%eax
      uint32_t n0 = n; 
      uint32_t d0 = d;

      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c0028180:	ba 00 00 00 00       	mov    $0x0,%edx
c0028185:	f7 f7                	div    %edi
c0028187:	89 c6                	mov    %eax,%esi
c0028189:	89 d3                	mov    %edx,%ebx
c002818b:	b9 00 00 00 00       	mov    $0x0,%ecx
c0028190:	8b 04 24             	mov    (%esp),%eax
c0028193:	ba 00 00 00 00       	mov    $0x0,%edx
c0028198:	01 c8                	add    %ecx,%eax
c002819a:	11 da                	adc    %ebx,%edx
  asm ("divl %4"
c002819c:	f7 f7                	div    %edi
      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c002819e:	ba 00 00 00 00       	mov    $0x0,%edx
c00281a3:	89 f7                	mov    %esi,%edi
c00281a5:	be 00 00 00 00       	mov    $0x0,%esi
c00281aa:	01 f0                	add    %esi,%eax
c00281ac:	11 fa                	adc    %edi,%edx
c00281ae:	e9 f2 00 00 00       	jmp    c00282a5 <udiv64+0x145>
    }
  else 
    {
      /* Based on the algorithm and proof available from
         http://www.hackersdelight.org/revisions.pdf. */
      if (n < d)
c00281b3:	3b 6c 24 04          	cmp    0x4(%esp),%ebp
c00281b7:	0f 87 d4 00 00 00    	ja     c0028291 <udiv64+0x131>
c00281bd:	72 09                	jb     c00281c8 <udiv64+0x68>
c00281bf:	3b 3c 24             	cmp    (%esp),%edi
c00281c2:	0f 87 c9 00 00 00    	ja     c0028291 <udiv64+0x131>
        return 0;
      else 
        {
          uint32_t d1 = d >> 32;
c00281c8:	89 d0                	mov    %edx,%eax
  int n = 0;
c00281ca:	b9 00 00 00 00       	mov    $0x0,%ecx
  if (x <= 0x0000FFFF)
c00281cf:	81 fa ff ff 00 00    	cmp    $0xffff,%edx
c00281d5:	77 05                	ja     c00281dc <udiv64+0x7c>
      x <<= 16; 
c00281d7:	c1 e0 10             	shl    $0x10,%eax
      n += 16;
c00281da:	b1 10                	mov    $0x10,%cl
  if (x <= 0x00FFFFFF)
c00281dc:	3d ff ff ff 00       	cmp    $0xffffff,%eax
c00281e1:	77 06                	ja     c00281e9 <udiv64+0x89>
      n += 8;
c00281e3:	83 c1 08             	add    $0x8,%ecx
      x <<= 8; 
c00281e6:	c1 e0 08             	shl    $0x8,%eax
  if (x <= 0x0FFFFFFF)
c00281e9:	3d ff ff ff 0f       	cmp    $0xfffffff,%eax
c00281ee:	77 06                	ja     c00281f6 <udiv64+0x96>
      n += 4;
c00281f0:	83 c1 04             	add    $0x4,%ecx
      x <<= 4;
c00281f3:	c1 e0 04             	shl    $0x4,%eax
  if (x <= 0x3FFFFFFF)
c00281f6:	3d ff ff ff 3f       	cmp    $0x3fffffff,%eax
c00281fb:	77 06                	ja     c0028203 <udiv64+0xa3>
      n += 2;
c00281fd:	83 c1 02             	add    $0x2,%ecx
      x <<= 2; 
c0028200:	c1 e0 02             	shl    $0x2,%eax
    n++;
c0028203:	3d 00 00 00 80       	cmp    $0x80000000,%eax
c0028208:	83 d1 00             	adc    $0x0,%ecx
          int s = nlz (d1);
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c002820b:	8b 04 24             	mov    (%esp),%eax
c002820e:	8b 54 24 04          	mov    0x4(%esp),%edx
c0028212:	0f ac d0 01          	shrd   $0x1,%edx,%eax
c0028216:	d1 ea                	shr    %edx
c0028218:	89 fb                	mov    %edi,%ebx
c002821a:	89 ee                	mov    %ebp,%esi
c002821c:	0f a5 fe             	shld   %cl,%edi,%esi
c002821f:	d3 e3                	shl    %cl,%ebx
c0028221:	f6 c1 20             	test   $0x20,%cl
c0028224:	74 02                	je     c0028228 <udiv64+0xc8>
c0028226:	89 de                	mov    %ebx,%esi
c0028228:	89 74 24 0c          	mov    %esi,0xc(%esp)
  asm ("divl %4"
c002822c:	f7 74 24 0c          	divl   0xc(%esp)
c0028230:	89 c6                	mov    %eax,%esi
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c0028232:	b8 1f 00 00 00       	mov    $0x1f,%eax
c0028237:	29 c8                	sub    %ecx,%eax
c0028239:	89 c1                	mov    %eax,%ecx
c002823b:	d3 ee                	shr    %cl,%esi
c002823d:	89 74 24 10          	mov    %esi,0x10(%esp)
c0028241:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0028248:	00 
          return n - (q - 1) * d < d ? q - 1 : q; 
c0028249:	8b 44 24 10          	mov    0x10(%esp),%eax
c002824d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028251:	83 c0 ff             	add    $0xffffffff,%eax
c0028254:	83 d2 ff             	adc    $0xffffffff,%edx
c0028257:	89 44 24 08          	mov    %eax,0x8(%esp)
c002825b:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002825f:	89 c1                	mov    %eax,%ecx
c0028261:	0f af d7             	imul   %edi,%edx
c0028264:	0f af cd             	imul   %ebp,%ecx
c0028267:	8d 34 0a             	lea    (%edx,%ecx,1),%esi
c002826a:	8b 44 24 08          	mov    0x8(%esp),%eax
c002826e:	f7 e7                	mul    %edi
c0028270:	01 f2                	add    %esi,%edx
c0028272:	8b 1c 24             	mov    (%esp),%ebx
c0028275:	8b 74 24 04          	mov    0x4(%esp),%esi
c0028279:	29 c3                	sub    %eax,%ebx
c002827b:	19 d6                	sbb    %edx,%esi
c002827d:	39 f5                	cmp    %esi,%ebp
c002827f:	72 1c                	jb     c002829d <udiv64+0x13d>
c0028281:	77 04                	ja     c0028287 <udiv64+0x127>
c0028283:	39 df                	cmp    %ebx,%edi
c0028285:	76 16                	jbe    c002829d <udiv64+0x13d>
c0028287:	8b 44 24 08          	mov    0x8(%esp),%eax
c002828b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002828f:	eb 14                	jmp    c00282a5 <udiv64+0x145>
        return 0;
c0028291:	b8 00 00 00 00       	mov    $0x0,%eax
c0028296:	ba 00 00 00 00       	mov    $0x0,%edx
c002829b:	eb 08                	jmp    c00282a5 <udiv64+0x145>
          return n - (q - 1) * d < d ? q - 1 : q; 
c002829d:	8b 44 24 10          	mov    0x10(%esp),%eax
c00282a1:	8b 54 24 14          	mov    0x14(%esp),%edx
        }
    }
}
c00282a5:	83 c4 1c             	add    $0x1c,%esp
c00282a8:	5b                   	pop    %ebx
c00282a9:	5e                   	pop    %esi
c00282aa:	5f                   	pop    %edi
c00282ab:	5d                   	pop    %ebp
c00282ac:	c3                   	ret    

c00282ad <sdiv64>:

/* Divides signed 64-bit N by signed 64-bit D and returns the
   quotient. */
static int64_t
sdiv64 (int64_t n, int64_t d)
{
c00282ad:	57                   	push   %edi
c00282ae:	56                   	push   %esi
c00282af:	53                   	push   %ebx
c00282b0:	83 ec 10             	sub    $0x10,%esp
c00282b3:	89 44 24 08          	mov    %eax,0x8(%esp)
c00282b7:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00282bb:	8b 74 24 20          	mov    0x20(%esp),%esi
c00282bf:	8b 7c 24 24          	mov    0x24(%esp),%edi
  uint64_t n_abs = n >= 0 ? (uint64_t) n : -(uint64_t) n;
c00282c3:	85 d2                	test   %edx,%edx
c00282c5:	79 0f                	jns    c00282d6 <sdiv64+0x29>
c00282c7:	8b 44 24 08          	mov    0x8(%esp),%eax
c00282cb:	8b 54 24 0c          	mov    0xc(%esp),%edx
c00282cf:	f7 d8                	neg    %eax
c00282d1:	83 d2 00             	adc    $0x0,%edx
c00282d4:	f7 da                	neg    %edx
  uint64_t d_abs = d >= 0 ? (uint64_t) d : -(uint64_t) d;
c00282d6:	85 ff                	test   %edi,%edi
c00282d8:	78 06                	js     c00282e0 <sdiv64+0x33>
c00282da:	89 f1                	mov    %esi,%ecx
c00282dc:	89 fb                	mov    %edi,%ebx
c00282de:	eb 0b                	jmp    c00282eb <sdiv64+0x3e>
c00282e0:	89 f1                	mov    %esi,%ecx
c00282e2:	89 fb                	mov    %edi,%ebx
c00282e4:	f7 d9                	neg    %ecx
c00282e6:	83 d3 00             	adc    $0x0,%ebx
c00282e9:	f7 db                	neg    %ebx
  uint64_t q_abs = udiv64 (n_abs, d_abs);
c00282eb:	89 0c 24             	mov    %ecx,(%esp)
c00282ee:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00282f2:	e8 69 fe ff ff       	call   c0028160 <udiv64>
  return (n < 0) == (d < 0) ? (int64_t) q_abs : -(int64_t) q_abs;
c00282f7:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
c00282fb:	f7 d1                	not    %ecx
c00282fd:	c1 e9 1f             	shr    $0x1f,%ecx
c0028300:	89 fb                	mov    %edi,%ebx
c0028302:	c1 eb 1f             	shr    $0x1f,%ebx
c0028305:	89 c6                	mov    %eax,%esi
c0028307:	89 d7                	mov    %edx,%edi
c0028309:	f7 de                	neg    %esi
c002830b:	83 d7 00             	adc    $0x0,%edi
c002830e:	f7 df                	neg    %edi
c0028310:	39 cb                	cmp    %ecx,%ebx
c0028312:	74 04                	je     c0028318 <sdiv64+0x6b>
c0028314:	89 c6                	mov    %eax,%esi
c0028316:	89 d7                	mov    %edx,%edi
}
c0028318:	89 f0                	mov    %esi,%eax
c002831a:	89 fa                	mov    %edi,%edx
c002831c:	83 c4 10             	add    $0x10,%esp
c002831f:	5b                   	pop    %ebx
c0028320:	5e                   	pop    %esi
c0028321:	5f                   	pop    %edi
c0028322:	c3                   	ret    

c0028323 <__divdi3>:
unsigned long long __umoddi3 (unsigned long long n, unsigned long long d);

/* Signed 64-bit division. */
long long
__divdi3 (long long n, long long d) 
{
c0028323:	83 ec 0c             	sub    $0xc,%esp
  return sdiv64 (n, d);
c0028326:	8b 44 24 18          	mov    0x18(%esp),%eax
c002832a:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002832e:	89 04 24             	mov    %eax,(%esp)
c0028331:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028335:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028339:	8b 54 24 14          	mov    0x14(%esp),%edx
c002833d:	e8 6b ff ff ff       	call   c00282ad <sdiv64>
}
c0028342:	83 c4 0c             	add    $0xc,%esp
c0028345:	c3                   	ret    

c0028346 <__moddi3>:

/* Signed 64-bit remainder. */
long long
__moddi3 (long long n, long long d) 
{
c0028346:	56                   	push   %esi
c0028347:	53                   	push   %ebx
c0028348:	83 ec 0c             	sub    $0xc,%esp
c002834b:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c002834f:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * sdiv64 (n, d);
c0028353:	89 34 24             	mov    %esi,(%esp)
c0028356:	8b 44 24 24          	mov    0x24(%esp),%eax
c002835a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002835e:	89 d8                	mov    %ebx,%eax
c0028360:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028364:	e8 44 ff ff ff       	call   c00282ad <sdiv64>
c0028369:	0f af f0             	imul   %eax,%esi
c002836c:	89 d8                	mov    %ebx,%eax
c002836e:	29 f0                	sub    %esi,%eax
  return smod64 (n, d);
c0028370:	99                   	cltd   
}
c0028371:	83 c4 0c             	add    $0xc,%esp
c0028374:	5b                   	pop    %ebx
c0028375:	5e                   	pop    %esi
c0028376:	c3                   	ret    

c0028377 <__udivdi3>:

/* Unsigned 64-bit division. */
unsigned long long
__udivdi3 (unsigned long long n, unsigned long long d) 
{
c0028377:	83 ec 0c             	sub    $0xc,%esp
  return udiv64 (n, d);
c002837a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002837e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028382:	89 04 24             	mov    %eax,(%esp)
c0028385:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028389:	8b 44 24 10          	mov    0x10(%esp),%eax
c002838d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028391:	e8 ca fd ff ff       	call   c0028160 <udiv64>
}
c0028396:	83 c4 0c             	add    $0xc,%esp
c0028399:	c3                   	ret    

c002839a <__umoddi3>:

/* Unsigned 64-bit remainder. */
unsigned long long
__umoddi3 (unsigned long long n, unsigned long long d) 
{
c002839a:	56                   	push   %esi
c002839b:	53                   	push   %ebx
c002839c:	83 ec 0c             	sub    $0xc,%esp
c002839f:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c00283a3:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * udiv64 (n, d);
c00283a7:	89 34 24             	mov    %esi,(%esp)
c00283aa:	8b 44 24 24          	mov    0x24(%esp),%eax
c00283ae:	89 44 24 04          	mov    %eax,0x4(%esp)
c00283b2:	89 d8                	mov    %ebx,%eax
c00283b4:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00283b8:	e8 a3 fd ff ff       	call   c0028160 <udiv64>
c00283bd:	0f af f0             	imul   %eax,%esi
c00283c0:	89 d8                	mov    %ebx,%eax
c00283c2:	29 f0                	sub    %esi,%eax
  return umod64 (n, d);
c00283c4:	ba 00 00 00 00       	mov    $0x0,%edx
}
c00283c9:	83 c4 0c             	add    $0xc,%esp
c00283cc:	5b                   	pop    %ebx
c00283cd:	5e                   	pop    %esi
c00283ce:	c3                   	ret    

c00283cf <parse_octal_field>:
   seems ambiguous as to whether these fields must be padded on
   the left with '0's, so we accept any field that fits in the
   available space, regardless of whether it fills the space. */
static bool
parse_octal_field (const char *s, size_t size, unsigned long int *value)
{
c00283cf:	55                   	push   %ebp
c00283d0:	57                   	push   %edi
c00283d1:	56                   	push   %esi
c00283d2:	53                   	push   %ebx
c00283d3:	83 ec 04             	sub    $0x4,%esp
c00283d6:	89 04 24             	mov    %eax,(%esp)
c00283d9:	89 d5                	mov    %edx,%ebp
  size_t ofs;

  *value = 0;
c00283db:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
          return false;
        }
    }

  /* Field did not end in space or null byte. */
  return false;
c00283e1:	b8 00 00 00 00       	mov    $0x0,%eax
  for (ofs = 0; ofs < size; ofs++)
c00283e6:	85 d2                	test   %edx,%edx
c00283e8:	74 66                	je     c0028450 <parse_octal_field+0x81>
c00283ea:	eb 45                	jmp    c0028431 <parse_octal_field+0x62>
      char c = s[ofs];
c00283ec:	8b 04 24             	mov    (%esp),%eax
c00283ef:	0f b6 14 18          	movzbl (%eax,%ebx,1),%edx
      if (c >= '0' && c <= '7')
c00283f3:	8d 7a d0             	lea    -0x30(%edx),%edi
c00283f6:	89 f8                	mov    %edi,%eax
c00283f8:	3c 07                	cmp    $0x7,%al
c00283fa:	77 24                	ja     c0028420 <parse_octal_field+0x51>
          if (*value > ULONG_MAX / 8)
c00283fc:	81 fe ff ff ff 1f    	cmp    $0x1fffffff,%esi
c0028402:	77 47                	ja     c002844b <parse_octal_field+0x7c>
          *value = c - '0' + *value * 8;
c0028404:	0f be fa             	movsbl %dl,%edi
c0028407:	8d 74 f7 d0          	lea    -0x30(%edi,%esi,8),%esi
c002840b:	89 31                	mov    %esi,(%ecx)
  for (ofs = 0; ofs < size; ofs++)
c002840d:	83 c3 01             	add    $0x1,%ebx
c0028410:	39 eb                	cmp    %ebp,%ebx
c0028412:	75 d8                	jne    c00283ec <parse_octal_field+0x1d>
  return false;
c0028414:	b8 00 00 00 00       	mov    $0x0,%eax
c0028419:	eb 35                	jmp    c0028450 <parse_octal_field+0x81>
  for (ofs = 0; ofs < size; ofs++)
c002841b:	bb 00 00 00 00       	mov    $0x0,%ebx
          return false;
c0028420:	b8 00 00 00 00       	mov    $0x0,%eax
      else if (c == ' ' || c == '\0')
c0028425:	f6 c2 df             	test   $0xdf,%dl
c0028428:	75 26                	jne    c0028450 <parse_octal_field+0x81>
          return ofs > 0;
c002842a:	85 db                	test   %ebx,%ebx
c002842c:	0f 95 c0             	setne  %al
c002842f:	eb 1f                	jmp    c0028450 <parse_octal_field+0x81>
      char c = s[ofs];
c0028431:	8b 04 24             	mov    (%esp),%eax
c0028434:	0f b6 10             	movzbl (%eax),%edx
      if (c >= '0' && c <= '7')
c0028437:	8d 5a d0             	lea    -0x30(%edx),%ebx
c002843a:	80 fb 07             	cmp    $0x7,%bl
c002843d:	77 dc                	ja     c002841b <parse_octal_field+0x4c>
          if (*value > ULONG_MAX / 8)
c002843f:	be 00 00 00 00       	mov    $0x0,%esi
  for (ofs = 0; ofs < size; ofs++)
c0028444:	bb 00 00 00 00       	mov    $0x0,%ebx
c0028449:	eb b9                	jmp    c0028404 <parse_octal_field+0x35>
              return false;
c002844b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028450:	83 c4 04             	add    $0x4,%esp
c0028453:	5b                   	pop    %ebx
c0028454:	5e                   	pop    %esi
c0028455:	5f                   	pop    %edi
c0028456:	5d                   	pop    %ebp
c0028457:	c3                   	ret    

c0028458 <strip_antisocial_prefixes>:
{
c0028458:	57                   	push   %edi
c0028459:	56                   	push   %esi
c002845a:	53                   	push   %ebx
c002845b:	83 ec 10             	sub    $0x10,%esp
c002845e:	89 c3                	mov    %eax,%ebx
  while (*file_name == '/'
c0028460:	eb 13                	jmp    c0028475 <strip_antisocial_prefixes+0x1d>
    file_name = strchr (file_name, '/') + 1;
c0028462:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0028469:	00 
c002846a:	89 1c 24             	mov    %ebx,(%esp)
c002846d:	e8 84 f7 ff ff       	call   c0027bf6 <strchr>
c0028472:	8d 58 01             	lea    0x1(%eax),%ebx
  while (*file_name == '/'
c0028475:	0f b6 33             	movzbl (%ebx),%esi
c0028478:	89 f0                	mov    %esi,%eax
c002847a:	3c 2f                	cmp    $0x2f,%al
c002847c:	74 e4                	je     c0028462 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "./", 2)
c002847e:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
c0028485:	00 
c0028486:	c7 44 24 04 25 ee 02 	movl   $0xc002ee25,0x4(%esp)
c002848d:	c0 
c002848e:	89 1c 24             	mov    %ebx,(%esp)
c0028491:	e8 77 f5 ff ff       	call   c0027a0d <memcmp>
c0028496:	85 c0                	test   %eax,%eax
c0028498:	74 c8                	je     c0028462 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "../", 3))
c002849a:	c7 44 24 08 03 00 00 	movl   $0x3,0x8(%esp)
c00284a1:	00 
c00284a2:	c7 44 24 04 8d fa 02 	movl   $0xc002fa8d,0x4(%esp)
c00284a9:	c0 
c00284aa:	89 1c 24             	mov    %ebx,(%esp)
c00284ad:	e8 5b f5 ff ff       	call   c0027a0d <memcmp>
c00284b2:	85 c0                	test   %eax,%eax
c00284b4:	74 ac                	je     c0028462 <strip_antisocial_prefixes+0xa>
  return *file_name == '\0' || !strcmp (file_name, "..") ? "." : file_name;
c00284b6:	b8 ab f3 02 c0       	mov    $0xc002f3ab,%eax
c00284bb:	89 f2                	mov    %esi,%edx
c00284bd:	84 d2                	test   %dl,%dl
c00284bf:	74 23                	je     c00284e4 <strip_antisocial_prefixes+0x8c>
c00284c1:	bf aa f3 02 c0       	mov    $0xc002f3aa,%edi
c00284c6:	b9 03 00 00 00       	mov    $0x3,%ecx
c00284cb:	89 de                	mov    %ebx,%esi
c00284cd:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00284cf:	0f 97 c0             	seta   %al
c00284d2:	0f 92 c2             	setb   %dl
c00284d5:	29 d0                	sub    %edx,%eax
c00284d7:	0f be c0             	movsbl %al,%eax
c00284da:	85 c0                	test   %eax,%eax
c00284dc:	b8 ab f3 02 c0       	mov    $0xc002f3ab,%eax
c00284e1:	0f 45 c3             	cmovne %ebx,%eax
}
c00284e4:	83 c4 10             	add    $0x10,%esp
c00284e7:	5b                   	pop    %ebx
c00284e8:	5e                   	pop    %esi
c00284e9:	5f                   	pop    %edi
c00284ea:	c3                   	ret    

c00284eb <ustar_make_header>:
{
c00284eb:	55                   	push   %ebp
c00284ec:	57                   	push   %edi
c00284ed:	56                   	push   %esi
c00284ee:	53                   	push   %ebx
c00284ef:	83 ec 2c             	sub    $0x2c,%esp
c00284f2:	8b 5c 24 4c          	mov    0x4c(%esp),%ebx
  ASSERT (type == USTAR_REGULAR || type == USTAR_DIRECTORY);
c00284f6:	83 7c 24 44 30       	cmpl   $0x30,0x44(%esp)
c00284fb:	0f 94 c0             	sete   %al
c00284fe:	89 c6                	mov    %eax,%esi
c0028500:	88 44 24 1f          	mov    %al,0x1f(%esp)
c0028504:	83 7c 24 44 35       	cmpl   $0x35,0x44(%esp)
c0028509:	0f 94 c0             	sete   %al
c002850c:	89 f2                	mov    %esi,%edx
c002850e:	08 d0                	or     %dl,%al
c0028510:	75 2c                	jne    c002853e <ustar_make_header+0x53>
c0028512:	c7 44 24 10 78 fb 02 	movl   $0xc002fb78,0x10(%esp)
c0028519:	c0 
c002851a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028521:	c0 
c0028522:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028529:	c0 
c002852a:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c0028531:	00 
c0028532:	c7 04 24 91 fa 02 c0 	movl   $0xc002fa91,(%esp)
c0028539:	e8 85 04 00 00       	call   c00289c3 <debug_panic>
c002853e:	89 c5                	mov    %eax,%ebp
  file_name = strip_antisocial_prefixes (file_name);
c0028540:	8b 44 24 40          	mov    0x40(%esp),%eax
c0028544:	e8 0f ff ff ff       	call   c0028458 <strip_antisocial_prefixes>
c0028549:	89 c2                	mov    %eax,%edx
  if (strlen (file_name) > 99)
c002854b:	89 c7                	mov    %eax,%edi
c002854d:	b8 00 00 00 00       	mov    $0x0,%eax
c0028552:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028557:	f2 ae                	repnz scas %es:(%edi),%al
c0028559:	f7 d1                	not    %ecx
c002855b:	83 e9 01             	sub    $0x1,%ecx
c002855e:	83 f9 63             	cmp    $0x63,%ecx
c0028561:	76 1a                	jbe    c002857d <ustar_make_header+0x92>
      printf ("%s: file name too long\n", file_name);
c0028563:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028567:	c7 04 24 a3 fa 02 c0 	movl   $0xc002faa3,(%esp)
c002856e:	e8 fb e5 ff ff       	call   c0026b6e <printf>
      return false;
c0028573:	bd 00 00 00 00       	mov    $0x0,%ebp
c0028578:	e9 d0 01 00 00       	jmp    c002874d <ustar_make_header+0x262>
  memset (h, 0, sizeof *h);
c002857d:	89 df                	mov    %ebx,%edi
c002857f:	be 00 02 00 00       	mov    $0x200,%esi
c0028584:	f6 c3 01             	test   $0x1,%bl
c0028587:	74 0a                	je     c0028593 <ustar_make_header+0xa8>
c0028589:	c6 03 00             	movb   $0x0,(%ebx)
c002858c:	8d 7b 01             	lea    0x1(%ebx),%edi
c002858f:	66 be ff 01          	mov    $0x1ff,%si
c0028593:	f7 c7 02 00 00 00    	test   $0x2,%edi
c0028599:	74 0b                	je     c00285a6 <ustar_make_header+0xbb>
c002859b:	66 c7 07 00 00       	movw   $0x0,(%edi)
c00285a0:	83 c7 02             	add    $0x2,%edi
c00285a3:	83 ee 02             	sub    $0x2,%esi
c00285a6:	89 f1                	mov    %esi,%ecx
c00285a8:	c1 e9 02             	shr    $0x2,%ecx
c00285ab:	b8 00 00 00 00       	mov    $0x0,%eax
c00285b0:	f3 ab                	rep stos %eax,%es:(%edi)
c00285b2:	f7 c6 02 00 00 00    	test   $0x2,%esi
c00285b8:	74 08                	je     c00285c2 <ustar_make_header+0xd7>
c00285ba:	66 c7 07 00 00       	movw   $0x0,(%edi)
c00285bf:	83 c7 02             	add    $0x2,%edi
c00285c2:	f7 c6 01 00 00 00    	test   $0x1,%esi
c00285c8:	74 03                	je     c00285cd <ustar_make_header+0xe2>
c00285ca:	c6 07 00             	movb   $0x0,(%edi)
  strlcpy (h->name, file_name, sizeof h->name);
c00285cd:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c00285d4:	00 
c00285d5:	89 54 24 04          	mov    %edx,0x4(%esp)
c00285d9:	89 1c 24             	mov    %ebx,(%esp)
c00285dc:	e8 f5 f9 ff ff       	call   c0027fd6 <strlcpy>
  snprintf (h->mode, sizeof h->mode, "%07o",
c00285e1:	80 7c 24 1f 01       	cmpb   $0x1,0x1f(%esp)
c00285e6:	19 c0                	sbb    %eax,%eax
c00285e8:	83 e0 49             	and    $0x49,%eax
c00285eb:	05 a4 01 00 00       	add    $0x1a4,%eax
c00285f0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00285f4:	c7 44 24 08 bb fa 02 	movl   $0xc002fabb,0x8(%esp)
c00285fb:	c0 
c00285fc:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0028603:	00 
c0028604:	8d 43 64             	lea    0x64(%ebx),%eax
c0028607:	89 04 24             	mov    %eax,(%esp)
c002860a:	e8 60 ec ff ff       	call   c002726f <snprintf>
  strlcpy (h->uid, "0000000", sizeof h->uid);
c002860f:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c0028616:	00 
c0028617:	c7 44 24 04 c0 fa 02 	movl   $0xc002fac0,0x4(%esp)
c002861e:	c0 
c002861f:	8d 43 6c             	lea    0x6c(%ebx),%eax
c0028622:	89 04 24             	mov    %eax,(%esp)
c0028625:	e8 ac f9 ff ff       	call   c0027fd6 <strlcpy>
  strlcpy (h->gid, "0000000", sizeof h->gid);
c002862a:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c0028631:	00 
c0028632:	c7 44 24 04 c0 fa 02 	movl   $0xc002fac0,0x4(%esp)
c0028639:	c0 
c002863a:	8d 43 74             	lea    0x74(%ebx),%eax
c002863d:	89 04 24             	mov    %eax,(%esp)
c0028640:	e8 91 f9 ff ff       	call   c0027fd6 <strlcpy>
  snprintf (h->size, sizeof h->size, "%011o", size);
c0028645:	8b 44 24 48          	mov    0x48(%esp),%eax
c0028649:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002864d:	c7 44 24 08 c8 fa 02 	movl   $0xc002fac8,0x8(%esp)
c0028654:	c0 
c0028655:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002865c:	00 
c002865d:	8d 43 7c             	lea    0x7c(%ebx),%eax
c0028660:	89 04 24             	mov    %eax,(%esp)
c0028663:	e8 07 ec ff ff       	call   c002726f <snprintf>
  snprintf (h->mtime, sizeof h->size, "%011o", 1136102400);
c0028668:	c7 44 24 0c 00 8c b7 	movl   $0x43b78c00,0xc(%esp)
c002866f:	43 
c0028670:	c7 44 24 08 c8 fa 02 	movl   $0xc002fac8,0x8(%esp)
c0028677:	c0 
c0028678:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002867f:	00 
c0028680:	8d 83 88 00 00 00    	lea    0x88(%ebx),%eax
c0028686:	89 04 24             	mov    %eax,(%esp)
c0028689:	e8 e1 eb ff ff       	call   c002726f <snprintf>
  h->typeflag = type;
c002868e:	0f b6 44 24 44       	movzbl 0x44(%esp),%eax
c0028693:	88 83 9c 00 00 00    	mov    %al,0x9c(%ebx)
  strlcpy (h->magic, "ustar", sizeof h->magic);
c0028699:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c00286a0:	00 
c00286a1:	c7 44 24 04 ce fa 02 	movl   $0xc002face,0x4(%esp)
c00286a8:	c0 
c00286a9:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c00286af:	89 04 24             	mov    %eax,(%esp)
c00286b2:	e8 1f f9 ff ff       	call   c0027fd6 <strlcpy>
  h->version[0] = h->version[1] = '0';
c00286b7:	c6 83 08 01 00 00 30 	movb   $0x30,0x108(%ebx)
c00286be:	c6 83 07 01 00 00 30 	movb   $0x30,0x107(%ebx)
  strlcpy (h->gname, "root", sizeof h->gname);
c00286c5:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c00286cc:	00 
c00286cd:	c7 44 24 04 dc ef 02 	movl   $0xc002efdc,0x4(%esp)
c00286d4:	c0 
c00286d5:	8d 83 29 01 00 00    	lea    0x129(%ebx),%eax
c00286db:	89 04 24             	mov    %eax,(%esp)
c00286de:	e8 f3 f8 ff ff       	call   c0027fd6 <strlcpy>
  strlcpy (h->uname, "root", sizeof h->uname);
c00286e3:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c00286ea:	00 
c00286eb:	c7 44 24 04 dc ef 02 	movl   $0xc002efdc,0x4(%esp)
c00286f2:	c0 
c00286f3:	8d 83 09 01 00 00    	lea    0x109(%ebx),%eax
c00286f9:	89 04 24             	mov    %eax,(%esp)
c00286fc:	e8 d5 f8 ff ff       	call   c0027fd6 <strlcpy>
c0028701:	b8 6c ff ff ff       	mov    $0xffffff6c,%eax
  chksum = 0;
c0028706:	ba 00 00 00 00       	mov    $0x0,%edx
      chksum += in_chksum_field ? ' ' : header[i];
c002870b:	83 f8 07             	cmp    $0x7,%eax
c002870e:	76 0a                	jbe    c002871a <ustar_make_header+0x22f>
c0028710:	0f b6 8c 03 94 00 00 	movzbl 0x94(%ebx,%eax,1),%ecx
c0028717:	00 
c0028718:	eb 05                	jmp    c002871f <ustar_make_header+0x234>
c002871a:	b9 20 00 00 00       	mov    $0x20,%ecx
c002871f:	01 ca                	add    %ecx,%edx
c0028721:	83 c0 01             	add    $0x1,%eax
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c0028724:	3d 6c 01 00 00       	cmp    $0x16c,%eax
c0028729:	75 e0                	jne    c002870b <ustar_make_header+0x220>
  snprintf (h->chksum, sizeof h->chksum, "%07o", calculate_chksum (h));
c002872b:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002872f:	c7 44 24 08 bb fa 02 	movl   $0xc002fabb,0x8(%esp)
c0028736:	c0 
c0028737:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c002873e:	00 
c002873f:	81 c3 94 00 00 00    	add    $0x94,%ebx
c0028745:	89 1c 24             	mov    %ebx,(%esp)
c0028748:	e8 22 eb ff ff       	call   c002726f <snprintf>
}
c002874d:	89 e8                	mov    %ebp,%eax
c002874f:	83 c4 2c             	add    $0x2c,%esp
c0028752:	5b                   	pop    %ebx
c0028753:	5e                   	pop    %esi
c0028754:	5f                   	pop    %edi
c0028755:	5d                   	pop    %ebp
c0028756:	c3                   	ret    

c0028757 <ustar_parse_header>:
   and returns a null pointer.  On failure, returns a
   human-readable error message. */
const char *
ustar_parse_header (const char header[USTAR_HEADER_SIZE],
                    const char **file_name, enum ustar_type *type, int *size)
{
c0028757:	53                   	push   %ebx
c0028758:	83 ec 28             	sub    $0x28,%esp
c002875b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002875f:	8d 8b 00 02 00 00    	lea    0x200(%ebx),%ecx
c0028765:	89 da                	mov    %ebx,%edx
    if (*block++ != 0)
c0028767:	83 c2 01             	add    $0x1,%edx
c002876a:	80 7a ff 00          	cmpb   $0x0,-0x1(%edx)
c002876e:	0f 85 25 01 00 00    	jne    c0028899 <ustar_parse_header+0x142>
  while (cnt-- > 0)
c0028774:	39 ca                	cmp    %ecx,%edx
c0028776:	75 ef                	jne    c0028767 <ustar_parse_header+0x10>
c0028778:	e9 4b 01 00 00       	jmp    c00288c8 <ustar_parse_header+0x171>

  /* Validate ustar header. */
  if (memcmp (h->magic, "ustar", 6))
    return "not a ustar archive";
  else if (h->version[0] != '0' || h->version[1] != '0')
    return "invalid ustar version";
c002877d:	b8 e8 fa 02 c0       	mov    $0xc002fae8,%eax
  else if (h->version[0] != '0' || h->version[1] != '0')
c0028782:	80 bb 07 01 00 00 30 	cmpb   $0x30,0x107(%ebx)
c0028789:	0f 85 5c 01 00 00    	jne    c00288eb <ustar_parse_header+0x194>
c002878f:	80 bb 08 01 00 00 30 	cmpb   $0x30,0x108(%ebx)
c0028796:	0f 85 4f 01 00 00    	jne    c00288eb <ustar_parse_header+0x194>
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c002879c:	8d 83 94 00 00 00    	lea    0x94(%ebx),%eax
c00287a2:	8d 4c 24 1c          	lea    0x1c(%esp),%ecx
c00287a6:	ba 08 00 00 00       	mov    $0x8,%edx
c00287ab:	e8 1f fc ff ff       	call   c00283cf <parse_octal_field>
c00287b0:	89 c2                	mov    %eax,%edx
    return "corrupt chksum field";
c00287b2:	b8 fe fa 02 c0       	mov    $0xc002fafe,%eax
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c00287b7:	84 d2                	test   %dl,%dl
c00287b9:	0f 84 2c 01 00 00    	je     c00288eb <ustar_parse_header+0x194>
c00287bf:	ba 6c ff ff ff       	mov    $0xffffff6c,%edx
c00287c4:	b9 00 00 00 00       	mov    $0x0,%ecx
      chksum += in_chksum_field ? ' ' : header[i];
c00287c9:	83 fa 07             	cmp    $0x7,%edx
c00287cc:	76 0a                	jbe    c00287d8 <ustar_parse_header+0x81>
c00287ce:	0f b6 84 13 94 00 00 	movzbl 0x94(%ebx,%edx,1),%eax
c00287d5:	00 
c00287d6:	eb 05                	jmp    c00287dd <ustar_parse_header+0x86>
c00287d8:	b8 20 00 00 00       	mov    $0x20,%eax
c00287dd:	01 c1                	add    %eax,%ecx
c00287df:	83 c2 01             	add    $0x1,%edx
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c00287e2:	81 fa 6c 01 00 00    	cmp    $0x16c,%edx
c00287e8:	75 df                	jne    c00287c9 <ustar_parse_header+0x72>
  else if (chksum != calculate_chksum (h))
    return "checksum mismatch";
c00287ea:	b8 13 fb 02 c0       	mov    $0xc002fb13,%eax
  else if (chksum != calculate_chksum (h))
c00287ef:	39 4c 24 1c          	cmp    %ecx,0x1c(%esp)
c00287f3:	0f 85 f2 00 00 00    	jne    c00288eb <ustar_parse_header+0x194>
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
    return "file name too long";
c00287f9:	b8 25 fb 02 c0       	mov    $0xc002fb25,%eax
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
c00287fe:	80 7b 63 00          	cmpb   $0x0,0x63(%ebx)
c0028802:	0f 85 e3 00 00 00    	jne    c00288eb <ustar_parse_header+0x194>
c0028808:	80 bb 59 01 00 00 00 	cmpb   $0x0,0x159(%ebx)
c002880f:	0f 85 d6 00 00 00    	jne    c00288eb <ustar_parse_header+0x194>
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c0028815:	0f b6 93 9c 00 00 00 	movzbl 0x9c(%ebx),%edx
c002881c:	80 fa 35             	cmp    $0x35,%dl
c002881f:	74 0e                	je     c002882f <ustar_parse_header+0xd8>
    return "unimplemented file type";
c0028821:	b8 38 fb 02 c0       	mov    $0xc002fb38,%eax
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c0028826:	80 fa 30             	cmp    $0x30,%dl
c0028829:	0f 85 bc 00 00 00    	jne    c00288eb <ustar_parse_header+0x194>
  if (h->typeflag == USTAR_REGULAR)
c002882f:	80 fa 30             	cmp    $0x30,%dl
c0028832:	75 32                	jne    c0028866 <ustar_parse_header+0x10f>
    {
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c0028834:	8d 43 7c             	lea    0x7c(%ebx),%eax
c0028837:	8d 4c 24 18          	lea    0x18(%esp),%ecx
c002883b:	ba 0c 00 00 00       	mov    $0xc,%edx
c0028840:	e8 8a fb ff ff       	call   c00283cf <parse_octal_field>
c0028845:	89 c2                	mov    %eax,%edx
        return "corrupt file size field";
c0028847:	b8 50 fb 02 c0       	mov    $0xc002fb50,%eax
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c002884c:	84 d2                	test   %dl,%dl
c002884e:	0f 84 97 00 00 00    	je     c00288eb <ustar_parse_header+0x194>
      else if (size_ul > INT_MAX)
        return "file too large";
c0028854:	b8 68 fb 02 c0       	mov    $0xc002fb68,%eax
      else if (size_ul > INT_MAX)
c0028859:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c002885e:	0f 88 87 00 00 00    	js     c00288eb <ustar_parse_header+0x194>
c0028864:	eb 08                	jmp    c002886e <ustar_parse_header+0x117>
    }
  else
    size_ul = 0;
c0028866:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c002886d:	00 

  /* Success. */
  *file_name = strip_antisocial_prefixes (h->name);
c002886e:	89 d8                	mov    %ebx,%eax
c0028870:	e8 e3 fb ff ff       	call   c0028458 <strip_antisocial_prefixes>
c0028875:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0028879:	89 01                	mov    %eax,(%ecx)
  *type = h->typeflag;
c002887b:	0f be 83 9c 00 00 00 	movsbl 0x9c(%ebx),%eax
c0028882:	8b 5c 24 38          	mov    0x38(%esp),%ebx
c0028886:	89 03                	mov    %eax,(%ebx)
  *size = size_ul;
c0028888:	8b 44 24 18          	mov    0x18(%esp),%eax
c002888c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
c0028890:	89 03                	mov    %eax,(%ebx)
  return NULL;
c0028892:	b8 00 00 00 00       	mov    $0x0,%eax
c0028897:	eb 52                	jmp    c00288eb <ustar_parse_header+0x194>
  if (memcmp (h->magic, "ustar", 6))
c0028899:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c00288a0:	00 
c00288a1:	c7 44 24 04 ce fa 02 	movl   $0xc002face,0x4(%esp)
c00288a8:	c0 
c00288a9:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c00288af:	89 04 24             	mov    %eax,(%esp)
c00288b2:	e8 56 f1 ff ff       	call   c0027a0d <memcmp>
c00288b7:	89 c2                	mov    %eax,%edx
    return "not a ustar archive";
c00288b9:	b8 d4 fa 02 c0       	mov    $0xc002fad4,%eax
  if (memcmp (h->magic, "ustar", 6))
c00288be:	85 d2                	test   %edx,%edx
c00288c0:	0f 84 b7 fe ff ff    	je     c002877d <ustar_parse_header+0x26>
c00288c6:	eb 23                	jmp    c00288eb <ustar_parse_header+0x194>
      *file_name = NULL;
c00288c8:	8b 44 24 34          	mov    0x34(%esp),%eax
c00288cc:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      *type = USTAR_EOF;
c00288d2:	8b 44 24 38          	mov    0x38(%esp),%eax
c00288d6:	c7 00 ff ff ff ff    	movl   $0xffffffff,(%eax)
      *size = 0;
c00288dc:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c00288e0:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      return NULL;
c00288e6:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00288eb:	83 c4 28             	add    $0x28,%esp
c00288ee:	5b                   	pop    %ebx
c00288ef:	c3                   	ret    

c00288f0 <print_stacktrace>:

/* Print call stack of a thread.
   The thread may be running, ready, or blocked. */
static void
print_stacktrace(struct thread *t, void *aux UNUSED)
{
c00288f0:	55                   	push   %ebp
c00288f1:	89 e5                	mov    %esp,%ebp
c00288f3:	53                   	push   %ebx
c00288f4:	83 ec 14             	sub    $0x14,%esp
c00288f7:	8b 5d 08             	mov    0x8(%ebp),%ebx
  void *retaddr = NULL, **frame = NULL;
  const char *status = "UNKNOWN";

  switch (t->status) {
c00288fa:	8b 43 04             	mov    0x4(%ebx),%eax
    case THREAD_RUNNING:  
      status = "RUNNING";
      break;

    case THREAD_READY:  
      status = "READY";
c00288fd:	ba a9 fb 02 c0       	mov    $0xc002fba9,%edx
  switch (t->status) {
c0028902:	83 f8 01             	cmp    $0x1,%eax
c0028905:	74 1a                	je     c0028921 <print_stacktrace+0x31>
      status = "RUNNING";
c0028907:	ba c9 e5 02 c0       	mov    $0xc002e5c9,%edx
  switch (t->status) {
c002890c:	83 f8 01             	cmp    $0x1,%eax
c002890f:	72 10                	jb     c0028921 <print_stacktrace+0x31>
c0028911:	83 f8 02             	cmp    $0x2,%eax
  const char *status = "UNKNOWN";
c0028914:	b8 af fb 02 c0       	mov    $0xc002fbaf,%eax
c0028919:	ba 83 e5 02 c0       	mov    $0xc002e583,%edx
c002891e:	0f 45 d0             	cmovne %eax,%edx

    default:
      break;
  }

  printf ("Call stack of thread `%s' (status %s):", t->name, status);
c0028921:	89 54 24 08          	mov    %edx,0x8(%esp)
c0028925:	8d 43 08             	lea    0x8(%ebx),%eax
c0028928:	89 44 24 04          	mov    %eax,0x4(%esp)
c002892c:	c7 04 24 d4 fb 02 c0 	movl   $0xc002fbd4,(%esp)
c0028933:	e8 36 e2 ff ff       	call   c0026b6e <printf>

  if (t == thread_current()) 
c0028938:	e8 f0 84 ff ff       	call   c0020e2d <thread_current>
c002893d:	39 d8                	cmp    %ebx,%eax
c002893f:	75 08                	jne    c0028949 <print_stacktrace+0x59>
    {
      frame = __builtin_frame_address (1);
c0028941:	8b 5d 00             	mov    0x0(%ebp),%ebx
      retaddr = __builtin_return_address (0);
c0028944:	8b 55 04             	mov    0x4(%ebp),%edx
c0028947:	eb 29                	jmp    c0028972 <print_stacktrace+0x82>
    {
      /* Retrieve the values of the base and instruction pointers
         as they were saved when this thread called switch_threads. */
      struct switch_threads_frame * saved_frame;

      saved_frame = (struct switch_threads_frame *)t->stack;
c0028949:	8b 43 18             	mov    0x18(%ebx),%eax
         list, but have never been scheduled.
         We can identify because their `stack' member either points 
         at the top of their kernel stack page, or the 
         switch_threads_frame's 'eip' member points at switch_entry.
         See also threads.c. */
      if (t->stack == (uint8_t *)t + PGSIZE || saved_frame->eip == switch_entry)
c002894c:	81 c3 00 10 00 00    	add    $0x1000,%ebx
c0028952:	39 d8                	cmp    %ebx,%eax
c0028954:	74 0b                	je     c0028961 <print_stacktrace+0x71>
c0028956:	8b 50 10             	mov    0x10(%eax),%edx
c0028959:	81 fa 5a 18 02 c0    	cmp    $0xc002185a,%edx
c002895f:	75 0e                	jne    c002896f <print_stacktrace+0x7f>
        {
          printf (" thread was never scheduled.\n");
c0028961:	c7 04 24 b7 fb 02 c0 	movl   $0xc002fbb7,(%esp)
c0028968:	e8 7e 1d 00 00       	call   c002a6eb <puts>
          return;
c002896d:	eb 4e                	jmp    c00289bd <print_stacktrace+0xcd>
        }

      frame = (void **) saved_frame->ebp;
c002896f:	8b 58 08             	mov    0x8(%eax),%ebx
      retaddr = (void *) saved_frame->eip;
    }

  printf (" %p", retaddr);
c0028972:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028976:	c7 04 24 14 f8 02 c0 	movl   $0xc002f814,(%esp)
c002897d:	e8 ec e1 ff ff       	call   c0026b6e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028982:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0028988:	76 27                	jbe    c00289b1 <print_stacktrace+0xc1>
c002898a:	83 3b 00             	cmpl   $0x0,(%ebx)
c002898d:	74 22                	je     c00289b1 <print_stacktrace+0xc1>
    printf (" %p", frame[1]);
c002898f:	8b 43 04             	mov    0x4(%ebx),%eax
c0028992:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028996:	c7 04 24 14 f8 02 c0 	movl   $0xc002f814,(%esp)
c002899d:	e8 cc e1 ff ff       	call   c0026b6e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c00289a2:	8b 1b                	mov    (%ebx),%ebx
c00289a4:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00289aa:	76 05                	jbe    c00289b1 <print_stacktrace+0xc1>
c00289ac:	83 3b 00             	cmpl   $0x0,(%ebx)
c00289af:	75 de                	jne    c002898f <print_stacktrace+0x9f>
  printf (".\n");
c00289b1:	c7 04 24 ab f3 02 c0 	movl   $0xc002f3ab,(%esp)
c00289b8:	e8 2e 1d 00 00       	call   c002a6eb <puts>
}
c00289bd:	83 c4 14             	add    $0x14,%esp
c00289c0:	5b                   	pop    %ebx
c00289c1:	5d                   	pop    %ebp
c00289c2:	c3                   	ret    

c00289c3 <debug_panic>:
{
c00289c3:	57                   	push   %edi
c00289c4:	56                   	push   %esi
c00289c5:	53                   	push   %ebx
c00289c6:	83 ec 10             	sub    $0x10,%esp
c00289c9:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c00289cd:	8b 74 24 24          	mov    0x24(%esp),%esi
c00289d1:	8b 7c 24 28          	mov    0x28(%esp),%edi
  intr_disable ();
c00289d5:	e8 35 90 ff ff       	call   c0021a0f <intr_disable>
  console_panic ();
c00289da:	e8 9d 1c 00 00       	call   c002a67c <console_panic>
  level++;
c00289df:	a1 c0 7a 03 c0       	mov    0xc0037ac0,%eax
c00289e4:	83 c0 01             	add    $0x1,%eax
c00289e7:	a3 c0 7a 03 c0       	mov    %eax,0xc0037ac0
  if (level == 1) 
c00289ec:	83 f8 01             	cmp    $0x1,%eax
c00289ef:	75 3f                	jne    c0028a30 <debug_panic+0x6d>
      printf ("Kernel PANIC at %s:%d in %s(): ", file, line, function);
c00289f1:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00289f5:	89 74 24 08          	mov    %esi,0x8(%esp)
c00289f9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00289fd:	c7 04 24 fc fb 02 c0 	movl   $0xc002fbfc,(%esp)
c0028a04:	e8 65 e1 ff ff       	call   c0026b6e <printf>
      va_start (args, message);
c0028a09:	8d 44 24 30          	lea    0x30(%esp),%eax
      vprintf (message, args);
c0028a0d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028a11:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c0028a15:	89 04 24             	mov    %eax,(%esp)
c0028a18:	e8 8d 1c 00 00       	call   c002a6aa <vprintf>
      printf ("\n");
c0028a1d:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0028a24:	e8 33 1d 00 00       	call   c002a75c <putchar>
      debug_backtrace ();
c0028a29:	e8 73 db ff ff       	call   c00265a1 <debug_backtrace>
c0028a2e:	eb 1d                	jmp    c0028a4d <debug_panic+0x8a>
  else if (level == 2)
c0028a30:	83 f8 02             	cmp    $0x2,%eax
c0028a33:	75 18                	jne    c0028a4d <debug_panic+0x8a>
    printf ("Kernel PANIC recursion at %s:%d in %s().\n",
c0028a35:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0028a39:	89 74 24 08          	mov    %esi,0x8(%esp)
c0028a3d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0028a41:	c7 04 24 1c fc 02 c0 	movl   $0xc002fc1c,(%esp)
c0028a48:	e8 21 e1 ff ff       	call   c0026b6e <printf>
  serial_flush ();
c0028a4d:	e8 8a c1 ff ff       	call   c0024bdc <serial_flush>
  shutdown ();
c0028a52:	e8 79 da ff ff       	call   c00264d0 <shutdown>
c0028a57:	eb fe                	jmp    c0028a57 <debug_panic+0x94>

c0028a59 <debug_backtrace_all>:

/* Prints call stack of all threads. */
void
debug_backtrace_all (void)
{
c0028a59:	53                   	push   %ebx
c0028a5a:	83 ec 18             	sub    $0x18,%esp
  enum intr_level oldlevel = intr_disable ();
c0028a5d:	e8 ad 8f ff ff       	call   c0021a0f <intr_disable>
c0028a62:	89 c3                	mov    %eax,%ebx

  thread_foreach (print_stacktrace, 0);
c0028a64:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0028a6b:	00 
c0028a6c:	c7 04 24 f0 88 02 c0 	movl   $0xc00288f0,(%esp)
c0028a73:	e8 96 84 ff ff       	call   c0020f0e <thread_foreach>
  intr_set_level (oldlevel);
c0028a78:	89 1c 24             	mov    %ebx,(%esp)
c0028a7b:	e8 96 8f ff ff       	call   c0021a16 <intr_set_level>
}
c0028a80:	83 c4 18             	add    $0x18,%esp
c0028a83:	5b                   	pop    %ebx
c0028a84:	c3                   	ret    
c0028a85:	90                   	nop
c0028a86:	90                   	nop
c0028a87:	90                   	nop
c0028a88:	90                   	nop
c0028a89:	90                   	nop
c0028a8a:	90                   	nop
c0028a8b:	90                   	nop
c0028a8c:	90                   	nop
c0028a8d:	90                   	nop
c0028a8e:	90                   	nop
c0028a8f:	90                   	nop

c0028a90 <list_init>:
}

/* Initializes LIST as an empty list. */
void
list_init (struct list *list)
{
c0028a90:	83 ec 2c             	sub    $0x2c,%esp
c0028a93:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028a97:	85 c0                	test   %eax,%eax
c0028a99:	75 2c                	jne    c0028ac7 <list_init+0x37>
c0028a9b:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028aa2:	c0 
c0028aa3:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028aaa:	c0 
c0028aab:	c7 44 24 08 a5 dd 02 	movl   $0xc002dda5,0x8(%esp)
c0028ab2:	c0 
c0028ab3:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0028aba:	00 
c0028abb:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028ac2:	e8 fc fe ff ff       	call   c00289c3 <debug_panic>
  list->head.prev = NULL;
c0028ac7:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  list->head.next = &list->tail;
c0028acd:	8d 50 08             	lea    0x8(%eax),%edx
c0028ad0:	89 50 04             	mov    %edx,0x4(%eax)
  list->tail.prev = &list->head;
c0028ad3:	89 40 08             	mov    %eax,0x8(%eax)
  list->tail.next = NULL;
c0028ad6:	c7 40 0c 00 00 00 00 	movl   $0x0,0xc(%eax)
}
c0028add:	83 c4 2c             	add    $0x2c,%esp
c0028ae0:	c3                   	ret    

c0028ae1 <list_begin>:

/* Returns the beginning of LIST.  */
struct list_elem *
list_begin (struct list *list)
{
c0028ae1:	83 ec 2c             	sub    $0x2c,%esp
c0028ae4:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028ae8:	85 c0                	test   %eax,%eax
c0028aea:	75 2c                	jne    c0028b18 <list_begin+0x37>
c0028aec:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028af3:	c0 
c0028af4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028afb:	c0 
c0028afc:	c7 44 24 08 9a dd 02 	movl   $0xc002dd9a,0x8(%esp)
c0028b03:	c0 
c0028b04:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0028b0b:	00 
c0028b0c:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028b13:	e8 ab fe ff ff       	call   c00289c3 <debug_panic>
  return list->head.next;
c0028b18:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028b1b:	83 c4 2c             	add    $0x2c,%esp
c0028b1e:	c3                   	ret    

c0028b1f <list_next>:
/* Returns the element after ELEM in its list.  If ELEM is the
   last element in its list, returns the list tail.  Results are
   undefined if ELEM is itself a list tail. */
struct list_elem *
list_next (struct list_elem *elem)
{
c0028b1f:	83 ec 2c             	sub    $0x2c,%esp
c0028b22:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev == NULL && elem->next != NULL;
c0028b26:	85 c0                	test   %eax,%eax
c0028b28:	74 16                	je     c0028b40 <list_next+0x21>
c0028b2a:	83 38 00             	cmpl   $0x0,(%eax)
c0028b2d:	75 06                	jne    c0028b35 <list_next+0x16>
c0028b2f:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028b33:	75 37                	jne    c0028b6c <list_next+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028b35:	83 38 00             	cmpl   $0x0,(%eax)
c0028b38:	74 06                	je     c0028b40 <list_next+0x21>
c0028b3a:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028b3e:	75 2c                	jne    c0028b6c <list_next+0x4d>
  ASSERT (is_head (elem) || is_interior (elem));
c0028b40:	c7 44 24 10 fc fc 02 	movl   $0xc002fcfc,0x10(%esp)
c0028b47:	c0 
c0028b48:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028b4f:	c0 
c0028b50:	c7 44 24 08 90 dd 02 	movl   $0xc002dd90,0x8(%esp)
c0028b57:	c0 
c0028b58:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0028b5f:	00 
c0028b60:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028b67:	e8 57 fe ff ff       	call   c00289c3 <debug_panic>
  return elem->next;
c0028b6c:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028b6f:	83 c4 2c             	add    $0x2c,%esp
c0028b72:	c3                   	ret    

c0028b73 <list_end>:
   list_end() is often used in iterating through a list from
   front to back.  See the big comment at the top of list.h for
   an example. */
struct list_elem *
list_end (struct list *list)
{
c0028b73:	83 ec 2c             	sub    $0x2c,%esp
c0028b76:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b7a:	85 c0                	test   %eax,%eax
c0028b7c:	75 2c                	jne    c0028baa <list_end+0x37>
c0028b7e:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028b85:	c0 
c0028b86:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028b8d:	c0 
c0028b8e:	c7 44 24 08 87 dd 02 	movl   $0xc002dd87,0x8(%esp)
c0028b95:	c0 
c0028b96:	c7 44 24 04 60 00 00 	movl   $0x60,0x4(%esp)
c0028b9d:	00 
c0028b9e:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028ba5:	e8 19 fe ff ff       	call   c00289c3 <debug_panic>
  return &list->tail;
c0028baa:	83 c0 08             	add    $0x8,%eax
}
c0028bad:	83 c4 2c             	add    $0x2c,%esp
c0028bb0:	c3                   	ret    

c0028bb1 <list_rbegin>:

/* Returns the LIST's reverse beginning, for iterating through
   LIST in reverse order, from back to front. */
struct list_elem *
list_rbegin (struct list *list) 
{
c0028bb1:	83 ec 2c             	sub    $0x2c,%esp
c0028bb4:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028bb8:	85 c0                	test   %eax,%eax
c0028bba:	75 2c                	jne    c0028be8 <list_rbegin+0x37>
c0028bbc:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028bc3:	c0 
c0028bc4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028bcb:	c0 
c0028bcc:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0028bd3:	c0 
c0028bd4:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0028bdb:	00 
c0028bdc:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028be3:	e8 db fd ff ff       	call   c00289c3 <debug_panic>
  return list->tail.prev;
c0028be8:	8b 40 08             	mov    0x8(%eax),%eax
}
c0028beb:	83 c4 2c             	add    $0x2c,%esp
c0028bee:	c3                   	ret    

c0028bef <list_prev>:
/* Returns the element before ELEM in its list.  If ELEM is the
   first element in its list, returns the list head.  Results are
   undefined if ELEM is itself a list head. */
struct list_elem *
list_prev (struct list_elem *elem)
{
c0028bef:	83 ec 2c             	sub    $0x2c,%esp
c0028bf2:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028bf6:	85 c0                	test   %eax,%eax
c0028bf8:	74 16                	je     c0028c10 <list_prev+0x21>
c0028bfa:	83 38 00             	cmpl   $0x0,(%eax)
c0028bfd:	74 06                	je     c0028c05 <list_prev+0x16>
c0028bff:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028c03:	75 37                	jne    c0028c3c <list_prev+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028c05:	83 38 00             	cmpl   $0x0,(%eax)
c0028c08:	74 06                	je     c0028c10 <list_prev+0x21>
c0028c0a:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028c0e:	74 2c                	je     c0028c3c <list_prev+0x4d>
  ASSERT (is_interior (elem) || is_tail (elem));
c0028c10:	c7 44 24 10 24 fd 02 	movl   $0xc002fd24,0x10(%esp)
c0028c17:	c0 
c0028c18:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028c1f:	c0 
c0028c20:	c7 44 24 08 71 dd 02 	movl   $0xc002dd71,0x8(%esp)
c0028c27:	c0 
c0028c28:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c0028c2f:	00 
c0028c30:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028c37:	e8 87 fd ff ff       	call   c00289c3 <debug_panic>
  return elem->prev;
c0028c3c:	8b 00                	mov    (%eax),%eax
}
c0028c3e:	83 c4 2c             	add    $0x2c,%esp
c0028c41:	c3                   	ret    

c0028c42 <find_end_of_run>:
   run.
   A through B (exclusive) must form a non-empty range. */
static struct list_elem *
find_end_of_run (struct list_elem *a, struct list_elem *b,
                 list_less_func *less, void *aux)
{
c0028c42:	55                   	push   %ebp
c0028c43:	57                   	push   %edi
c0028c44:	56                   	push   %esi
c0028c45:	53                   	push   %ebx
c0028c46:	83 ec 2c             	sub    $0x2c,%esp
c0028c49:	89 c3                	mov    %eax,%ebx
c0028c4b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (a != NULL);
c0028c4f:	85 c0                	test   %eax,%eax
c0028c51:	75 2c                	jne    c0028c7f <find_end_of_run+0x3d>
c0028c53:	c7 44 24 10 59 ea 02 	movl   $0xc002ea59,0x10(%esp)
c0028c5a:	c0 
c0028c5b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028c62:	c0 
c0028c63:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028c6a:	c0 
c0028c6b:	c7 44 24 04 6a 01 00 	movl   $0x16a,0x4(%esp)
c0028c72:	00 
c0028c73:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028c7a:	e8 44 fd ff ff       	call   c00289c3 <debug_panic>
c0028c7f:	89 d6                	mov    %edx,%esi
c0028c81:	89 cf                	mov    %ecx,%edi
  ASSERT (b != NULL);
c0028c83:	85 d2                	test   %edx,%edx
c0028c85:	75 2c                	jne    c0028cb3 <find_end_of_run+0x71>
c0028c87:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0028c8e:	c0 
c0028c8f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028c96:	c0 
c0028c97:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028c9e:	c0 
c0028c9f:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c0028ca6:	00 
c0028ca7:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028cae:	e8 10 fd ff ff       	call   c00289c3 <debug_panic>
  ASSERT (less != NULL);
c0028cb3:	85 c9                	test   %ecx,%ecx
c0028cb5:	75 2c                	jne    c0028ce3 <find_end_of_run+0xa1>
c0028cb7:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c0028cbe:	c0 
c0028cbf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028cc6:	c0 
c0028cc7:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028cce:	c0 
c0028ccf:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c0028cd6:	00 
c0028cd7:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028cde:	e8 e0 fc ff ff       	call   c00289c3 <debug_panic>
  ASSERT (a != b);
c0028ce3:	39 d0                	cmp    %edx,%eax
c0028ce5:	75 2c                	jne    c0028d13 <find_end_of_run+0xd1>
c0028ce7:	c7 44 24 10 78 fc 02 	movl   $0xc002fc78,0x10(%esp)
c0028cee:	c0 
c0028cef:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028cf6:	c0 
c0028cf7:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028cfe:	c0 
c0028cff:	c7 44 24 04 6d 01 00 	movl   $0x16d,0x4(%esp)
c0028d06:	00 
c0028d07:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028d0e:	e8 b0 fc ff ff       	call   c00289c3 <debug_panic>
  
  do 
    {
      a = list_next (a);
c0028d13:	89 1c 24             	mov    %ebx,(%esp)
c0028d16:	e8 04 fe ff ff       	call   c0028b1f <list_next>
c0028d1b:	89 c3                	mov    %eax,%ebx
    }
  while (a != b && !less (a, list_prev (a), aux));
c0028d1d:	39 f0                	cmp    %esi,%eax
c0028d1f:	74 19                	je     c0028d3a <find_end_of_run+0xf8>
c0028d21:	89 04 24             	mov    %eax,(%esp)
c0028d24:	e8 c6 fe ff ff       	call   c0028bef <list_prev>
c0028d29:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0028d2d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028d31:	89 1c 24             	mov    %ebx,(%esp)
c0028d34:	ff d7                	call   *%edi
c0028d36:	84 c0                	test   %al,%al
c0028d38:	74 d9                	je     c0028d13 <find_end_of_run+0xd1>
  return a;
}
c0028d3a:	89 d8                	mov    %ebx,%eax
c0028d3c:	83 c4 2c             	add    $0x2c,%esp
c0028d3f:	5b                   	pop    %ebx
c0028d40:	5e                   	pop    %esi
c0028d41:	5f                   	pop    %edi
c0028d42:	5d                   	pop    %ebp
c0028d43:	c3                   	ret    

c0028d44 <is_sorted>:
{
c0028d44:	55                   	push   %ebp
c0028d45:	57                   	push   %edi
c0028d46:	56                   	push   %esi
c0028d47:	53                   	push   %ebx
c0028d48:	83 ec 1c             	sub    $0x1c,%esp
c0028d4b:	89 c3                	mov    %eax,%ebx
c0028d4d:	89 d6                	mov    %edx,%esi
c0028d4f:	89 cd                	mov    %ecx,%ebp
c0028d51:	8b 7c 24 30          	mov    0x30(%esp),%edi
  if (a != b)
c0028d55:	39 d0                	cmp    %edx,%eax
c0028d57:	75 1b                	jne    c0028d74 <is_sorted+0x30>
c0028d59:	eb 2e                	jmp    c0028d89 <is_sorted+0x45>
      if (less (a, list_prev (a), aux))
c0028d5b:	89 1c 24             	mov    %ebx,(%esp)
c0028d5e:	e8 8c fe ff ff       	call   c0028bef <list_prev>
c0028d63:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0028d67:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028d6b:	89 1c 24             	mov    %ebx,(%esp)
c0028d6e:	ff d5                	call   *%ebp
c0028d70:	84 c0                	test   %al,%al
c0028d72:	75 1c                	jne    c0028d90 <is_sorted+0x4c>
    while ((a = list_next (a)) != b) 
c0028d74:	89 1c 24             	mov    %ebx,(%esp)
c0028d77:	e8 a3 fd ff ff       	call   c0028b1f <list_next>
c0028d7c:	89 c3                	mov    %eax,%ebx
c0028d7e:	39 f0                	cmp    %esi,%eax
c0028d80:	75 d9                	jne    c0028d5b <is_sorted+0x17>
  return true;
c0028d82:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d87:	eb 0c                	jmp    c0028d95 <is_sorted+0x51>
c0028d89:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d8e:	eb 05                	jmp    c0028d95 <is_sorted+0x51>
        return false;
c0028d90:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028d95:	83 c4 1c             	add    $0x1c,%esp
c0028d98:	5b                   	pop    %ebx
c0028d99:	5e                   	pop    %esi
c0028d9a:	5f                   	pop    %edi
c0028d9b:	5d                   	pop    %ebp
c0028d9c:	c3                   	ret    

c0028d9d <list_rend>:
{
c0028d9d:	83 ec 2c             	sub    $0x2c,%esp
c0028da0:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028da4:	85 c0                	test   %eax,%eax
c0028da6:	75 2c                	jne    c0028dd4 <list_rend+0x37>
c0028da8:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028daf:	c0 
c0028db0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028db7:	c0 
c0028db8:	c7 44 24 08 67 dd 02 	movl   $0xc002dd67,0x8(%esp)
c0028dbf:	c0 
c0028dc0:	c7 44 24 04 87 00 00 	movl   $0x87,0x4(%esp)
c0028dc7:	00 
c0028dc8:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028dcf:	e8 ef fb ff ff       	call   c00289c3 <debug_panic>
}
c0028dd4:	83 c4 2c             	add    $0x2c,%esp
c0028dd7:	c3                   	ret    

c0028dd8 <list_head>:
{
c0028dd8:	83 ec 2c             	sub    $0x2c,%esp
c0028ddb:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028ddf:	85 c0                	test   %eax,%eax
c0028de1:	75 2c                	jne    c0028e0f <list_head+0x37>
c0028de3:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028dea:	c0 
c0028deb:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028df2:	c0 
c0028df3:	c7 44 24 08 5d dd 02 	movl   $0xc002dd5d,0x8(%esp)
c0028dfa:	c0 
c0028dfb:	c7 44 24 04 99 00 00 	movl   $0x99,0x4(%esp)
c0028e02:	00 
c0028e03:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028e0a:	e8 b4 fb ff ff       	call   c00289c3 <debug_panic>
}
c0028e0f:	83 c4 2c             	add    $0x2c,%esp
c0028e12:	c3                   	ret    

c0028e13 <list_tail>:
{
c0028e13:	83 ec 2c             	sub    $0x2c,%esp
c0028e16:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028e1a:	85 c0                	test   %eax,%eax
c0028e1c:	75 2c                	jne    c0028e4a <list_tail+0x37>
c0028e1e:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028e25:	c0 
c0028e26:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028e2d:	c0 
c0028e2e:	c7 44 24 08 53 dd 02 	movl   $0xc002dd53,0x8(%esp)
c0028e35:	c0 
c0028e36:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c0028e3d:	00 
c0028e3e:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028e45:	e8 79 fb ff ff       	call   c00289c3 <debug_panic>
  return &list->tail;
c0028e4a:	83 c0 08             	add    $0x8,%eax
}
c0028e4d:	83 c4 2c             	add    $0x2c,%esp
c0028e50:	c3                   	ret    

c0028e51 <list_insert>:
{
c0028e51:	83 ec 2c             	sub    $0x2c,%esp
c0028e54:	8b 44 24 30          	mov    0x30(%esp),%eax
c0028e58:	8b 54 24 34          	mov    0x34(%esp),%edx
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028e5c:	85 c0                	test   %eax,%eax
c0028e5e:	74 56                	je     c0028eb6 <list_insert+0x65>
c0028e60:	83 38 00             	cmpl   $0x0,(%eax)
c0028e63:	74 06                	je     c0028e6b <list_insert+0x1a>
c0028e65:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e69:	75 0b                	jne    c0028e76 <list_insert+0x25>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028e6b:	83 38 00             	cmpl   $0x0,(%eax)
c0028e6e:	74 46                	je     c0028eb6 <list_insert+0x65>
c0028e70:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e74:	75 40                	jne    c0028eb6 <list_insert+0x65>
  ASSERT (elem != NULL);
c0028e76:	85 d2                	test   %edx,%edx
c0028e78:	75 2c                	jne    c0028ea6 <list_insert+0x55>
c0028e7a:	c7 44 24 10 7f fc 02 	movl   $0xc002fc7f,0x10(%esp)
c0028e81:	c0 
c0028e82:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028e89:	c0 
c0028e8a:	c7 44 24 08 47 dd 02 	movl   $0xc002dd47,0x8(%esp)
c0028e91:	c0 
c0028e92:	c7 44 24 04 ac 00 00 	movl   $0xac,0x4(%esp)
c0028e99:	00 
c0028e9a:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028ea1:	e8 1d fb ff ff       	call   c00289c3 <debug_panic>
  elem->prev = before->prev;
c0028ea6:	8b 08                	mov    (%eax),%ecx
c0028ea8:	89 0a                	mov    %ecx,(%edx)
  elem->next = before;
c0028eaa:	89 42 04             	mov    %eax,0x4(%edx)
  before->prev->next = elem;
c0028ead:	8b 08                	mov    (%eax),%ecx
c0028eaf:	89 51 04             	mov    %edx,0x4(%ecx)
  before->prev = elem;
c0028eb2:	89 10                	mov    %edx,(%eax)
c0028eb4:	eb 2c                	jmp    c0028ee2 <list_insert+0x91>
  ASSERT (is_interior (before) || is_tail (before));
c0028eb6:	c7 44 24 10 4c fd 02 	movl   $0xc002fd4c,0x10(%esp)
c0028ebd:	c0 
c0028ebe:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028ec5:	c0 
c0028ec6:	c7 44 24 08 47 dd 02 	movl   $0xc002dd47,0x8(%esp)
c0028ecd:	c0 
c0028ece:	c7 44 24 04 ab 00 00 	movl   $0xab,0x4(%esp)
c0028ed5:	00 
c0028ed6:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028edd:	e8 e1 fa ff ff       	call   c00289c3 <debug_panic>
}
c0028ee2:	83 c4 2c             	add    $0x2c,%esp
c0028ee5:	c3                   	ret    

c0028ee6 <list_splice>:
{
c0028ee6:	56                   	push   %esi
c0028ee7:	53                   	push   %ebx
c0028ee8:	83 ec 24             	sub    $0x24,%esp
c0028eeb:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0028eef:	8b 74 24 34          	mov    0x34(%esp),%esi
c0028ef3:	8b 44 24 38          	mov    0x38(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ef7:	85 db                	test   %ebx,%ebx
c0028ef9:	74 4d                	je     c0028f48 <list_splice+0x62>
c0028efb:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028efe:	74 06                	je     c0028f06 <list_splice+0x20>
c0028f00:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028f04:	75 0b                	jne    c0028f11 <list_splice+0x2b>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028f06:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028f09:	74 3d                	je     c0028f48 <list_splice+0x62>
c0028f0b:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028f0f:	75 37                	jne    c0028f48 <list_splice+0x62>
  if (first == last)
c0028f11:	39 c6                	cmp    %eax,%esi
c0028f13:	0f 84 cf 00 00 00    	je     c0028fe8 <list_splice+0x102>
  last = list_prev (last);
c0028f19:	89 04 24             	mov    %eax,(%esp)
c0028f1c:	e8 ce fc ff ff       	call   c0028bef <list_prev>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028f21:	85 f6                	test   %esi,%esi
c0028f23:	74 4f                	je     c0028f74 <list_splice+0x8e>
c0028f25:	8b 16                	mov    (%esi),%edx
c0028f27:	85 d2                	test   %edx,%edx
c0028f29:	74 49                	je     c0028f74 <list_splice+0x8e>
c0028f2b:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0028f2f:	75 6f                	jne    c0028fa0 <list_splice+0xba>
c0028f31:	eb 41                	jmp    c0028f74 <list_splice+0x8e>
c0028f33:	83 38 00             	cmpl   $0x0,(%eax)
c0028f36:	74 6c                	je     c0028fa4 <list_splice+0xbe>
c0028f38:	8b 48 04             	mov    0x4(%eax),%ecx
c0028f3b:	85 c9                	test   %ecx,%ecx
c0028f3d:	8d 76 00             	lea    0x0(%esi),%esi
c0028f40:	0f 85 8a 00 00 00    	jne    c0028fd0 <list_splice+0xea>
c0028f46:	eb 5c                	jmp    c0028fa4 <list_splice+0xbe>
  ASSERT (is_interior (before) || is_tail (before));
c0028f48:	c7 44 24 10 4c fd 02 	movl   $0xc002fd4c,0x10(%esp)
c0028f4f:	c0 
c0028f50:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028f57:	c0 
c0028f58:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028f5f:	c0 
c0028f60:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c0028f67:	00 
c0028f68:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028f6f:	e8 4f fa ff ff       	call   c00289c3 <debug_panic>
  ASSERT (is_interior (first));
c0028f74:	c7 44 24 10 8c fc 02 	movl   $0xc002fc8c,0x10(%esp)
c0028f7b:	c0 
c0028f7c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028f83:	c0 
c0028f84:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028f8b:	c0 
c0028f8c:	c7 44 24 04 c0 00 00 	movl   $0xc0,0x4(%esp)
c0028f93:	00 
c0028f94:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028f9b:	e8 23 fa ff ff       	call   c00289c3 <debug_panic>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028fa0:	85 c0                	test   %eax,%eax
c0028fa2:	75 8f                	jne    c0028f33 <list_splice+0x4d>
  ASSERT (is_interior (last));
c0028fa4:	c7 44 24 10 a0 fc 02 	movl   $0xc002fca0,0x10(%esp)
c0028fab:	c0 
c0028fac:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028fb3:	c0 
c0028fb4:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028fbb:	c0 
c0028fbc:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0028fc3:	00 
c0028fc4:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028fcb:	e8 f3 f9 ff ff       	call   c00289c3 <debug_panic>
  first->prev->next = last->next;
c0028fd0:	89 4a 04             	mov    %ecx,0x4(%edx)
  last->next->prev = first->prev;
c0028fd3:	8b 50 04             	mov    0x4(%eax),%edx
c0028fd6:	8b 0e                	mov    (%esi),%ecx
c0028fd8:	89 0a                	mov    %ecx,(%edx)
  first->prev = before->prev;
c0028fda:	8b 13                	mov    (%ebx),%edx
c0028fdc:	89 16                	mov    %edx,(%esi)
  last->next = before;
c0028fde:	89 58 04             	mov    %ebx,0x4(%eax)
  before->prev->next = first;
c0028fe1:	8b 13                	mov    (%ebx),%edx
c0028fe3:	89 72 04             	mov    %esi,0x4(%edx)
  before->prev = last;
c0028fe6:	89 03                	mov    %eax,(%ebx)
}
c0028fe8:	83 c4 24             	add    $0x24,%esp
c0028feb:	5b                   	pop    %ebx
c0028fec:	5e                   	pop    %esi
c0028fed:	c3                   	ret    

c0028fee <list_push_front>:
{
c0028fee:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_begin (list), elem);
c0028ff1:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028ff5:	89 04 24             	mov    %eax,(%esp)
c0028ff8:	e8 e4 fa ff ff       	call   c0028ae1 <list_begin>
c0028ffd:	8b 54 24 24          	mov    0x24(%esp),%edx
c0029001:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029005:	89 04 24             	mov    %eax,(%esp)
c0029008:	e8 44 fe ff ff       	call   c0028e51 <list_insert>
}
c002900d:	83 c4 1c             	add    $0x1c,%esp
c0029010:	c3                   	ret    

c0029011 <list_push_back>:
{
c0029011:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_end (list), elem);
c0029014:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029018:	89 04 24             	mov    %eax,(%esp)
c002901b:	e8 53 fb ff ff       	call   c0028b73 <list_end>
c0029020:	8b 54 24 24          	mov    0x24(%esp),%edx
c0029024:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029028:	89 04 24             	mov    %eax,(%esp)
c002902b:	e8 21 fe ff ff       	call   c0028e51 <list_insert>
}
c0029030:	83 c4 1c             	add    $0x1c,%esp
c0029033:	c3                   	ret    

c0029034 <list_remove>:
{
c0029034:	83 ec 2c             	sub    $0x2c,%esp
c0029037:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c002903b:	85 c0                	test   %eax,%eax
c002903d:	74 0d                	je     c002904c <list_remove+0x18>
c002903f:	8b 10                	mov    (%eax),%edx
c0029041:	85 d2                	test   %edx,%edx
c0029043:	74 07                	je     c002904c <list_remove+0x18>
c0029045:	8b 48 04             	mov    0x4(%eax),%ecx
c0029048:	85 c9                	test   %ecx,%ecx
c002904a:	75 2c                	jne    c0029078 <list_remove+0x44>
  ASSERT (is_interior (elem));
c002904c:	c7 44 24 10 b3 fc 02 	movl   $0xc002fcb3,0x10(%esp)
c0029053:	c0 
c0029054:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002905b:	c0 
c002905c:	c7 44 24 08 2f dd 02 	movl   $0xc002dd2f,0x8(%esp)
c0029063:	c0 
c0029064:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
c002906b:	00 
c002906c:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029073:	e8 4b f9 ff ff       	call   c00289c3 <debug_panic>
  elem->prev->next = elem->next;
c0029078:	89 4a 04             	mov    %ecx,0x4(%edx)
  elem->next->prev = elem->prev;
c002907b:	8b 50 04             	mov    0x4(%eax),%edx
c002907e:	8b 08                	mov    (%eax),%ecx
c0029080:	89 0a                	mov    %ecx,(%edx)
  return elem->next;
c0029082:	8b 40 04             	mov    0x4(%eax),%eax
}
c0029085:	83 c4 2c             	add    $0x2c,%esp
c0029088:	c3                   	ret    

c0029089 <list_size>:
{
c0029089:	57                   	push   %edi
c002908a:	56                   	push   %esi
c002908b:	53                   	push   %ebx
c002908c:	83 ec 10             	sub    $0x10,%esp
c002908f:	8b 7c 24 20          	mov    0x20(%esp),%edi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029093:	89 3c 24             	mov    %edi,(%esp)
c0029096:	e8 46 fa ff ff       	call   c0028ae1 <list_begin>
c002909b:	89 c3                	mov    %eax,%ebx
  size_t cnt = 0;
c002909d:	be 00 00 00 00       	mov    $0x0,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c00290a2:	eb 0d                	jmp    c00290b1 <list_size+0x28>
    cnt++;
c00290a4:	83 c6 01             	add    $0x1,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c00290a7:	89 1c 24             	mov    %ebx,(%esp)
c00290aa:	e8 70 fa ff ff       	call   c0028b1f <list_next>
c00290af:	89 c3                	mov    %eax,%ebx
c00290b1:	89 3c 24             	mov    %edi,(%esp)
c00290b4:	e8 ba fa ff ff       	call   c0028b73 <list_end>
c00290b9:	39 d8                	cmp    %ebx,%eax
c00290bb:	75 e7                	jne    c00290a4 <list_size+0x1b>
}
c00290bd:	89 f0                	mov    %esi,%eax
c00290bf:	83 c4 10             	add    $0x10,%esp
c00290c2:	5b                   	pop    %ebx
c00290c3:	5e                   	pop    %esi
c00290c4:	5f                   	pop    %edi
c00290c5:	c3                   	ret    

c00290c6 <list_empty>:
{
c00290c6:	56                   	push   %esi
c00290c7:	53                   	push   %ebx
c00290c8:	83 ec 14             	sub    $0x14,%esp
c00290cb:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  return list_begin (list) == list_end (list);
c00290cf:	89 1c 24             	mov    %ebx,(%esp)
c00290d2:	e8 0a fa ff ff       	call   c0028ae1 <list_begin>
c00290d7:	89 c6                	mov    %eax,%esi
c00290d9:	89 1c 24             	mov    %ebx,(%esp)
c00290dc:	e8 92 fa ff ff       	call   c0028b73 <list_end>
c00290e1:	39 c6                	cmp    %eax,%esi
c00290e3:	0f 94 c0             	sete   %al
}
c00290e6:	83 c4 14             	add    $0x14,%esp
c00290e9:	5b                   	pop    %ebx
c00290ea:	5e                   	pop    %esi
c00290eb:	c3                   	ret    

c00290ec <list_front>:
{
c00290ec:	53                   	push   %ebx
c00290ed:	83 ec 28             	sub    $0x28,%esp
c00290f0:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c00290f4:	89 1c 24             	mov    %ebx,(%esp)
c00290f7:	e8 ca ff ff ff       	call   c00290c6 <list_empty>
c00290fc:	84 c0                	test   %al,%al
c00290fe:	74 2c                	je     c002912c <list_front+0x40>
c0029100:	c7 44 24 10 c6 fc 02 	movl   $0xc002fcc6,0x10(%esp)
c0029107:	c0 
c0029108:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002910f:	c0 
c0029110:	c7 44 24 08 24 dd 02 	movl   $0xc002dd24,0x8(%esp)
c0029117:	c0 
c0029118:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c002911f:	00 
c0029120:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029127:	e8 97 f8 ff ff       	call   c00289c3 <debug_panic>
  return list->head.next;
c002912c:	8b 43 04             	mov    0x4(%ebx),%eax
}
c002912f:	83 c4 28             	add    $0x28,%esp
c0029132:	5b                   	pop    %ebx
c0029133:	c3                   	ret    

c0029134 <list_pop_front>:
{
c0029134:	53                   	push   %ebx
c0029135:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *front = list_front (list);
c0029138:	8b 44 24 20          	mov    0x20(%esp),%eax
c002913c:	89 04 24             	mov    %eax,(%esp)
c002913f:	e8 a8 ff ff ff       	call   c00290ec <list_front>
c0029144:	89 c3                	mov    %eax,%ebx
  list_remove (front);
c0029146:	89 04 24             	mov    %eax,(%esp)
c0029149:	e8 e6 fe ff ff       	call   c0029034 <list_remove>
}
c002914e:	89 d8                	mov    %ebx,%eax
c0029150:	83 c4 18             	add    $0x18,%esp
c0029153:	5b                   	pop    %ebx
c0029154:	c3                   	ret    

c0029155 <list_back>:
{
c0029155:	53                   	push   %ebx
c0029156:	83 ec 28             	sub    $0x28,%esp
c0029159:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c002915d:	89 1c 24             	mov    %ebx,(%esp)
c0029160:	e8 61 ff ff ff       	call   c00290c6 <list_empty>
c0029165:	84 c0                	test   %al,%al
c0029167:	74 2c                	je     c0029195 <list_back+0x40>
c0029169:	c7 44 24 10 c6 fc 02 	movl   $0xc002fcc6,0x10(%esp)
c0029170:	c0 
c0029171:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029178:	c0 
c0029179:	c7 44 24 08 1a dd 02 	movl   $0xc002dd1a,0x8(%esp)
c0029180:	c0 
c0029181:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
c0029188:	00 
c0029189:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029190:	e8 2e f8 ff ff       	call   c00289c3 <debug_panic>
  return list->tail.prev;
c0029195:	8b 43 08             	mov    0x8(%ebx),%eax
}
c0029198:	83 c4 28             	add    $0x28,%esp
c002919b:	5b                   	pop    %ebx
c002919c:	c3                   	ret    

c002919d <list_pop_back>:
{
c002919d:	53                   	push   %ebx
c002919e:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *back = list_back (list);
c00291a1:	8b 44 24 20          	mov    0x20(%esp),%eax
c00291a5:	89 04 24             	mov    %eax,(%esp)
c00291a8:	e8 a8 ff ff ff       	call   c0029155 <list_back>
c00291ad:	89 c3                	mov    %eax,%ebx
  list_remove (back);
c00291af:	89 04 24             	mov    %eax,(%esp)
c00291b2:	e8 7d fe ff ff       	call   c0029034 <list_remove>
}
c00291b7:	89 d8                	mov    %ebx,%eax
c00291b9:	83 c4 18             	add    $0x18,%esp
c00291bc:	5b                   	pop    %ebx
c00291bd:	c3                   	ret    

c00291be <list_reverse>:
{
c00291be:	56                   	push   %esi
c00291bf:	53                   	push   %ebx
c00291c0:	83 ec 14             	sub    $0x14,%esp
c00291c3:	8b 74 24 20          	mov    0x20(%esp),%esi
  if (!list_empty (list)) 
c00291c7:	89 34 24             	mov    %esi,(%esp)
c00291ca:	e8 f7 fe ff ff       	call   c00290c6 <list_empty>
c00291cf:	84 c0                	test   %al,%al
c00291d1:	75 3a                	jne    c002920d <list_reverse+0x4f>
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c00291d3:	89 34 24             	mov    %esi,(%esp)
c00291d6:	e8 06 f9 ff ff       	call   c0028ae1 <list_begin>
c00291db:	89 c3                	mov    %eax,%ebx
c00291dd:	eb 0c                	jmp    c00291eb <list_reverse+0x2d>
  struct list_elem *t = *a;
c00291df:	8b 13                	mov    (%ebx),%edx
  *a = *b;
c00291e1:	8b 43 04             	mov    0x4(%ebx),%eax
c00291e4:	89 03                	mov    %eax,(%ebx)
  *b = t;
c00291e6:	89 53 04             	mov    %edx,0x4(%ebx)
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c00291e9:	89 c3                	mov    %eax,%ebx
c00291eb:	89 34 24             	mov    %esi,(%esp)
c00291ee:	e8 80 f9 ff ff       	call   c0028b73 <list_end>
c00291f3:	39 d8                	cmp    %ebx,%eax
c00291f5:	75 e8                	jne    c00291df <list_reverse+0x21>
  struct list_elem *t = *a;
c00291f7:	8b 46 04             	mov    0x4(%esi),%eax
  *a = *b;
c00291fa:	8b 56 08             	mov    0x8(%esi),%edx
c00291fd:	89 56 04             	mov    %edx,0x4(%esi)
  *b = t;
c0029200:	89 46 08             	mov    %eax,0x8(%esi)
  struct list_elem *t = *a;
c0029203:	8b 0a                	mov    (%edx),%ecx
  *a = *b;
c0029205:	8b 58 04             	mov    0x4(%eax),%ebx
c0029208:	89 1a                	mov    %ebx,(%edx)
  *b = t;
c002920a:	89 48 04             	mov    %ecx,0x4(%eax)
}
c002920d:	83 c4 14             	add    $0x14,%esp
c0029210:	5b                   	pop    %ebx
c0029211:	5e                   	pop    %esi
c0029212:	c3                   	ret    

c0029213 <list_sort>:
/* Sorts LIST according to LESS given auxiliary data AUX, using a
   natural iterative merge sort that runs in O(n lg n) time and
   O(1) space in the number of elements in LIST. */
void
list_sort (struct list *list, list_less_func *less, void *aux)
{
c0029213:	55                   	push   %ebp
c0029214:	57                   	push   %edi
c0029215:	56                   	push   %esi
c0029216:	53                   	push   %ebx
c0029217:	83 ec 2c             	sub    $0x2c,%esp
c002921a:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c002921e:	8b 7c 24 48          	mov    0x48(%esp),%edi
  size_t output_run_cnt;        /* Number of runs output in current pass. */

  ASSERT (list != NULL);
c0029222:	83 7c 24 40 00       	cmpl   $0x0,0x40(%esp)
c0029227:	75 2c                	jne    c0029255 <list_sort+0x42>
c0029229:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0029230:	c0 
c0029231:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029238:	c0 
c0029239:	c7 44 24 08 10 dd 02 	movl   $0xc002dd10,0x8(%esp)
c0029240:	c0 
c0029241:	c7 44 24 04 9a 01 00 	movl   $0x19a,0x4(%esp)
c0029248:	00 
c0029249:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029250:	e8 6e f7 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (less != NULL);
c0029255:	85 ed                	test   %ebp,%ebp
c0029257:	75 2c                	jne    c0029285 <list_sort+0x72>
c0029259:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c0029260:	c0 
c0029261:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029268:	c0 
c0029269:	c7 44 24 08 10 dd 02 	movl   $0xc002dd10,0x8(%esp)
c0029270:	c0 
c0029271:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c0029278:	00 
c0029279:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029280:	e8 3e f7 ff ff       	call   c00289c3 <debug_panic>
      struct list_elem *a0;     /* Start of first run. */
      struct list_elem *a1b0;   /* End of first run, start of second. */
      struct list_elem *b1;     /* End of second run. */

      output_run_cnt = 0;
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0029285:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029289:	89 04 24             	mov    %eax,(%esp)
c002928c:	e8 50 f8 ff ff       	call   c0028ae1 <list_begin>
c0029291:	89 c6                	mov    %eax,%esi
      output_run_cnt = 0;
c0029293:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002929a:	00 
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c002929b:	e9 99 01 00 00       	jmp    c0029439 <list_sort+0x226>
        {
          /* Each iteration produces one output run. */
          output_run_cnt++;
c00292a0:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)

          /* Locate two adjacent runs of nondecreasing elements
             A0...A1B0 and A1B0...B1. */
          a1b0 = find_end_of_run (a0, list_end (list), less, aux);
c00292a5:	89 3c 24             	mov    %edi,(%esp)
c00292a8:	89 e9                	mov    %ebp,%ecx
c00292aa:	89 c2                	mov    %eax,%edx
c00292ac:	89 f0                	mov    %esi,%eax
c00292ae:	e8 8f f9 ff ff       	call   c0028c42 <find_end_of_run>
c00292b3:	89 c3                	mov    %eax,%ebx
          if (a1b0 == list_end (list))
c00292b5:	8b 44 24 40          	mov    0x40(%esp),%eax
c00292b9:	89 04 24             	mov    %eax,(%esp)
c00292bc:	e8 b2 f8 ff ff       	call   c0028b73 <list_end>
c00292c1:	39 d8                	cmp    %ebx,%eax
c00292c3:	0f 84 84 01 00 00    	je     c002944d <list_sort+0x23a>
            break;
          b1 = find_end_of_run (a1b0, list_end (list), less, aux);
c00292c9:	89 3c 24             	mov    %edi,(%esp)
c00292cc:	89 e9                	mov    %ebp,%ecx
c00292ce:	89 c2                	mov    %eax,%edx
c00292d0:	89 d8                	mov    %ebx,%eax
c00292d2:	e8 6b f9 ff ff       	call   c0028c42 <find_end_of_run>
c00292d7:	89 44 24 18          	mov    %eax,0x18(%esp)
  ASSERT (a0 != NULL);
c00292db:	85 f6                	test   %esi,%esi
c00292dd:	75 2c                	jne    c002930b <list_sort+0xf8>
c00292df:	c7 44 24 10 d9 fc 02 	movl   $0xc002fcd9,0x10(%esp)
c00292e6:	c0 
c00292e7:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00292ee:	c0 
c00292ef:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c00292f6:	c0 
c00292f7:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
c00292fe:	00 
c00292ff:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029306:	e8 b8 f6 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (a1b0 != NULL);
c002930b:	85 db                	test   %ebx,%ebx
c002930d:	75 2c                	jne    c002933b <list_sort+0x128>
c002930f:	c7 44 24 10 e4 fc 02 	movl   $0xc002fce4,0x10(%esp)
c0029316:	c0 
c0029317:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002931e:	c0 
c002931f:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c0029326:	c0 
c0029327:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
c002932e:	00 
c002932f:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029336:	e8 88 f6 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (b1 != NULL);
c002933b:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c0029340:	75 2c                	jne    c002936e <list_sort+0x15b>
c0029342:	c7 44 24 10 f1 fc 02 	movl   $0xc002fcf1,0x10(%esp)
c0029349:	c0 
c002934a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029351:	c0 
c0029352:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c0029359:	c0 
c002935a:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
c0029361:	00 
c0029362:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029369:	e8 55 f6 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (is_sorted (a0, a1b0, less, aux));
c002936e:	89 3c 24             	mov    %edi,(%esp)
c0029371:	89 e9                	mov    %ebp,%ecx
c0029373:	89 da                	mov    %ebx,%edx
c0029375:	89 f0                	mov    %esi,%eax
c0029377:	e8 c8 f9 ff ff       	call   c0028d44 <is_sorted>
c002937c:	84 c0                	test   %al,%al
c002937e:	75 2c                	jne    c00293ac <list_sort+0x199>
c0029380:	c7 44 24 10 78 fd 02 	movl   $0xc002fd78,0x10(%esp)
c0029387:	c0 
c0029388:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002938f:	c0 
c0029390:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c0029397:	c0 
c0029398:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
c002939f:	00 
c00293a0:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00293a7:	e8 17 f6 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (is_sorted (a1b0, b1, less, aux));
c00293ac:	89 3c 24             	mov    %edi,(%esp)
c00293af:	89 e9                	mov    %ebp,%ecx
c00293b1:	8b 54 24 18          	mov    0x18(%esp),%edx
c00293b5:	89 d8                	mov    %ebx,%eax
c00293b7:	e8 88 f9 ff ff       	call   c0028d44 <is_sorted>
c00293bc:	84 c0                	test   %al,%al
c00293be:	75 6b                	jne    c002942b <list_sort+0x218>
c00293c0:	c7 44 24 10 98 fd 02 	movl   $0xc002fd98,0x10(%esp)
c00293c7:	c0 
c00293c8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00293cf:	c0 
c00293d0:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c00293d7:	c0 
c00293d8:	c7 44 24 04 86 01 00 	movl   $0x186,0x4(%esp)
c00293df:	00 
c00293e0:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00293e7:	e8 d7 f5 ff ff       	call   c00289c3 <debug_panic>
    if (!less (a1b0, a0, aux)) 
c00293ec:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00293f0:	89 74 24 04          	mov    %esi,0x4(%esp)
c00293f4:	89 1c 24             	mov    %ebx,(%esp)
c00293f7:	ff d5                	call   *%ebp
c00293f9:	84 c0                	test   %al,%al
c00293fb:	75 0c                	jne    c0029409 <list_sort+0x1f6>
      a0 = list_next (a0);
c00293fd:	89 34 24             	mov    %esi,(%esp)
c0029400:	e8 1a f7 ff ff       	call   c0028b1f <list_next>
c0029405:	89 c6                	mov    %eax,%esi
c0029407:	eb 22                	jmp    c002942b <list_sort+0x218>
        a1b0 = list_next (a1b0);
c0029409:	89 1c 24             	mov    %ebx,(%esp)
c002940c:	e8 0e f7 ff ff       	call   c0028b1f <list_next>
c0029411:	89 c3                	mov    %eax,%ebx
        list_splice (a0, list_prev (a1b0), a1b0);
c0029413:	89 04 24             	mov    %eax,(%esp)
c0029416:	e8 d4 f7 ff ff       	call   c0028bef <list_prev>
c002941b:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002941f:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029423:	89 34 24             	mov    %esi,(%esp)
c0029426:	e8 bb fa ff ff       	call   c0028ee6 <list_splice>
  while (a0 != a1b0 && a1b0 != b1)
c002942b:	39 5c 24 18          	cmp    %ebx,0x18(%esp)
c002942f:	74 04                	je     c0029435 <list_sort+0x222>
c0029431:	39 f3                	cmp    %esi,%ebx
c0029433:	75 b7                	jne    c00293ec <list_sort+0x1d9>
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0029435:	8b 74 24 18          	mov    0x18(%esp),%esi
c0029439:	8b 44 24 40          	mov    0x40(%esp),%eax
c002943d:	89 04 24             	mov    %eax,(%esp)
c0029440:	e8 2e f7 ff ff       	call   c0028b73 <list_end>
c0029445:	39 f0                	cmp    %esi,%eax
c0029447:	0f 85 53 fe ff ff    	jne    c00292a0 <list_sort+0x8d>

          /* Merge the runs. */
          inplace_merge (a0, a1b0, b1, less, aux);
        }
    }
  while (output_run_cnt > 1);
c002944d:	83 7c 24 1c 01       	cmpl   $0x1,0x1c(%esp)
c0029452:	0f 87 2d fe ff ff    	ja     c0029285 <list_sort+0x72>

  ASSERT (is_sorted (list_begin (list), list_end (list), less, aux));
c0029458:	8b 44 24 40          	mov    0x40(%esp),%eax
c002945c:	89 04 24             	mov    %eax,(%esp)
c002945f:	e8 0f f7 ff ff       	call   c0028b73 <list_end>
c0029464:	89 c3                	mov    %eax,%ebx
c0029466:	8b 44 24 40          	mov    0x40(%esp),%eax
c002946a:	89 04 24             	mov    %eax,(%esp)
c002946d:	e8 6f f6 ff ff       	call   c0028ae1 <list_begin>
c0029472:	89 3c 24             	mov    %edi,(%esp)
c0029475:	89 e9                	mov    %ebp,%ecx
c0029477:	89 da                	mov    %ebx,%edx
c0029479:	e8 c6 f8 ff ff       	call   c0028d44 <is_sorted>
c002947e:	84 c0                	test   %al,%al
c0029480:	75 2c                	jne    c00294ae <list_sort+0x29b>
c0029482:	c7 44 24 10 b8 fd 02 	movl   $0xc002fdb8,0x10(%esp)
c0029489:	c0 
c002948a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029491:	c0 
c0029492:	c7 44 24 08 10 dd 02 	movl   $0xc002dd10,0x8(%esp)
c0029499:	c0 
c002949a:	c7 44 24 04 b8 01 00 	movl   $0x1b8,0x4(%esp)
c00294a1:	00 
c00294a2:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00294a9:	e8 15 f5 ff ff       	call   c00289c3 <debug_panic>
}
c00294ae:	83 c4 2c             	add    $0x2c,%esp
c00294b1:	5b                   	pop    %ebx
c00294b2:	5e                   	pop    %esi
c00294b3:	5f                   	pop    %edi
c00294b4:	5d                   	pop    %ebp
c00294b5:	c3                   	ret    

c00294b6 <list_insert_ordered>:
   sorted according to LESS given auxiliary data AUX.
   Runs in O(n) average case in the number of elements in LIST. */
void
list_insert_ordered (struct list *list, struct list_elem *elem,
                     list_less_func *less, void *aux)
{
c00294b6:	55                   	push   %ebp
c00294b7:	57                   	push   %edi
c00294b8:	56                   	push   %esi
c00294b9:	53                   	push   %ebx
c00294ba:	83 ec 2c             	sub    $0x2c,%esp
c00294bd:	8b 74 24 40          	mov    0x40(%esp),%esi
c00294c1:	8b 7c 24 44          	mov    0x44(%esp),%edi
c00294c5:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *e;

  ASSERT (list != NULL);
c00294c9:	85 f6                	test   %esi,%esi
c00294cb:	75 2c                	jne    c00294f9 <list_insert_ordered+0x43>
c00294cd:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c00294d4:	c0 
c00294d5:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00294dc:	c0 
c00294dd:	c7 44 24 08 de dc 02 	movl   $0xc002dcde,0x8(%esp)
c00294e4:	c0 
c00294e5:	c7 44 24 04 c4 01 00 	movl   $0x1c4,0x4(%esp)
c00294ec:	00 
c00294ed:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00294f4:	e8 ca f4 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (elem != NULL);
c00294f9:	85 ff                	test   %edi,%edi
c00294fb:	75 2c                	jne    c0029529 <list_insert_ordered+0x73>
c00294fd:	c7 44 24 10 7f fc 02 	movl   $0xc002fc7f,0x10(%esp)
c0029504:	c0 
c0029505:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002950c:	c0 
c002950d:	c7 44 24 08 de dc 02 	movl   $0xc002dcde,0x8(%esp)
c0029514:	c0 
c0029515:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
c002951c:	00 
c002951d:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029524:	e8 9a f4 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (less != NULL);
c0029529:	85 ed                	test   %ebp,%ebp
c002952b:	75 2c                	jne    c0029559 <list_insert_ordered+0xa3>
c002952d:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c0029534:	c0 
c0029535:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002953c:	c0 
c002953d:	c7 44 24 08 de dc 02 	movl   $0xc002dcde,0x8(%esp)
c0029544:	c0 
c0029545:	c7 44 24 04 c6 01 00 	movl   $0x1c6,0x4(%esp)
c002954c:	00 
c002954d:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029554:	e8 6a f4 ff ff       	call   c00289c3 <debug_panic>

  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029559:	89 34 24             	mov    %esi,(%esp)
c002955c:	e8 80 f5 ff ff       	call   c0028ae1 <list_begin>
c0029561:	89 c3                	mov    %eax,%ebx
c0029563:	eb 1f                	jmp    c0029584 <list_insert_ordered+0xce>
    if (less (elem, e, aux))
c0029565:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029569:	89 44 24 08          	mov    %eax,0x8(%esp)
c002956d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029571:	89 3c 24             	mov    %edi,(%esp)
c0029574:	ff d5                	call   *%ebp
c0029576:	84 c0                	test   %al,%al
c0029578:	75 16                	jne    c0029590 <list_insert_ordered+0xda>
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c002957a:	89 1c 24             	mov    %ebx,(%esp)
c002957d:	e8 9d f5 ff ff       	call   c0028b1f <list_next>
c0029582:	89 c3                	mov    %eax,%ebx
c0029584:	89 34 24             	mov    %esi,(%esp)
c0029587:	e8 e7 f5 ff ff       	call   c0028b73 <list_end>
c002958c:	39 d8                	cmp    %ebx,%eax
c002958e:	75 d5                	jne    c0029565 <list_insert_ordered+0xaf>
      break;
  return list_insert (e, elem);
c0029590:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029594:	89 1c 24             	mov    %ebx,(%esp)
c0029597:	e8 b5 f8 ff ff       	call   c0028e51 <list_insert>
}
c002959c:	83 c4 2c             	add    $0x2c,%esp
c002959f:	5b                   	pop    %ebx
c00295a0:	5e                   	pop    %esi
c00295a1:	5f                   	pop    %edi
c00295a2:	5d                   	pop    %ebp
c00295a3:	c3                   	ret    

c00295a4 <list_unique>:
   given auxiliary data AUX.  If DUPLICATES is non-null, then the
   elements from LIST are appended to DUPLICATES. */
void
list_unique (struct list *list, struct list *duplicates,
             list_less_func *less, void *aux)
{
c00295a4:	55                   	push   %ebp
c00295a5:	57                   	push   %edi
c00295a6:	56                   	push   %esi
c00295a7:	53                   	push   %ebx
c00295a8:	83 ec 2c             	sub    $0x2c,%esp
c00295ab:	8b 7c 24 40          	mov    0x40(%esp),%edi
c00295af:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *elem, *next;

  ASSERT (list != NULL);
c00295b3:	85 ff                	test   %edi,%edi
c00295b5:	75 2c                	jne    c00295e3 <list_unique+0x3f>
c00295b7:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c00295be:	c0 
c00295bf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00295c6:	c0 
c00295c7:	c7 44 24 08 d2 dc 02 	movl   $0xc002dcd2,0x8(%esp)
c00295ce:	c0 
c00295cf:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
c00295d6:	00 
c00295d7:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00295de:	e8 e0 f3 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (less != NULL);
c00295e3:	85 ed                	test   %ebp,%ebp
c00295e5:	75 2c                	jne    c0029613 <list_unique+0x6f>
c00295e7:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c00295ee:	c0 
c00295ef:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00295f6:	c0 
c00295f7:	c7 44 24 08 d2 dc 02 	movl   $0xc002dcd2,0x8(%esp)
c00295fe:	c0 
c00295ff:	c7 44 24 04 d9 01 00 	movl   $0x1d9,0x4(%esp)
c0029606:	00 
c0029607:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c002960e:	e8 b0 f3 ff ff       	call   c00289c3 <debug_panic>
  if (list_empty (list))
c0029613:	89 3c 24             	mov    %edi,(%esp)
c0029616:	e8 ab fa ff ff       	call   c00290c6 <list_empty>
c002961b:	84 c0                	test   %al,%al
c002961d:	75 73                	jne    c0029692 <list_unique+0xee>
    return;

  elem = list_begin (list);
c002961f:	89 3c 24             	mov    %edi,(%esp)
c0029622:	e8 ba f4 ff ff       	call   c0028ae1 <list_begin>
c0029627:	89 c6                	mov    %eax,%esi
  while ((next = list_next (elem)) != list_end (list))
c0029629:	eb 51                	jmp    c002967c <list_unique+0xd8>
    if (!less (elem, next, aux) && !less (next, elem, aux)) 
c002962b:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c002962f:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029633:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029637:	89 34 24             	mov    %esi,(%esp)
c002963a:	ff d5                	call   *%ebp
c002963c:	84 c0                	test   %al,%al
c002963e:	75 3a                	jne    c002967a <list_unique+0xd6>
c0029640:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029644:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029648:	89 74 24 04          	mov    %esi,0x4(%esp)
c002964c:	89 1c 24             	mov    %ebx,(%esp)
c002964f:	ff d5                	call   *%ebp
c0029651:	84 c0                	test   %al,%al
c0029653:	75 25                	jne    c002967a <list_unique+0xd6>
      {
        list_remove (next);
c0029655:	89 1c 24             	mov    %ebx,(%esp)
c0029658:	e8 d7 f9 ff ff       	call   c0029034 <list_remove>
        if (duplicates != NULL)
c002965d:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c0029662:	74 14                	je     c0029678 <list_unique+0xd4>
          list_push_back (duplicates, next);
c0029664:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029668:	8b 44 24 44          	mov    0x44(%esp),%eax
c002966c:	89 04 24             	mov    %eax,(%esp)
c002966f:	e8 9d f9 ff ff       	call   c0029011 <list_push_back>
c0029674:	89 f3                	mov    %esi,%ebx
c0029676:	eb 02                	jmp    c002967a <list_unique+0xd6>
c0029678:	89 f3                	mov    %esi,%ebx
c002967a:	89 de                	mov    %ebx,%esi
  while ((next = list_next (elem)) != list_end (list))
c002967c:	89 34 24             	mov    %esi,(%esp)
c002967f:	e8 9b f4 ff ff       	call   c0028b1f <list_next>
c0029684:	89 c3                	mov    %eax,%ebx
c0029686:	89 3c 24             	mov    %edi,(%esp)
c0029689:	e8 e5 f4 ff ff       	call   c0028b73 <list_end>
c002968e:	39 c3                	cmp    %eax,%ebx
c0029690:	75 99                	jne    c002962b <list_unique+0x87>
      }
    else
      elem = next;
}
c0029692:	83 c4 2c             	add    $0x2c,%esp
c0029695:	5b                   	pop    %ebx
c0029696:	5e                   	pop    %esi
c0029697:	5f                   	pop    %edi
c0029698:	5d                   	pop    %ebp
c0029699:	c3                   	ret    

c002969a <list_max>:
   to LESS given auxiliary data AUX.  If there is more than one
   maximum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_max (struct list *list, list_less_func *less, void *aux)
{
c002969a:	55                   	push   %ebp
c002969b:	57                   	push   %edi
c002969c:	56                   	push   %esi
c002969d:	53                   	push   %ebx
c002969e:	83 ec 1c             	sub    $0x1c,%esp
c00296a1:	8b 7c 24 30          	mov    0x30(%esp),%edi
c00296a5:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *max = list_begin (list);
c00296a9:	89 3c 24             	mov    %edi,(%esp)
c00296ac:	e8 30 f4 ff ff       	call   c0028ae1 <list_begin>
c00296b1:	89 c6                	mov    %eax,%esi
  if (max != list_end (list)) 
c00296b3:	89 3c 24             	mov    %edi,(%esp)
c00296b6:	e8 b8 f4 ff ff       	call   c0028b73 <list_end>
c00296bb:	39 f0                	cmp    %esi,%eax
c00296bd:	74 36                	je     c00296f5 <list_max+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c00296bf:	89 34 24             	mov    %esi,(%esp)
c00296c2:	e8 58 f4 ff ff       	call   c0028b1f <list_next>
c00296c7:	89 c3                	mov    %eax,%ebx
c00296c9:	eb 1e                	jmp    c00296e9 <list_max+0x4f>
        if (less (max, e, aux))
c00296cb:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00296cf:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00296d3:	89 34 24             	mov    %esi,(%esp)
c00296d6:	ff 54 24 34          	call   *0x34(%esp)
c00296da:	84 c0                	test   %al,%al
          max = e; 
c00296dc:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c00296df:	89 1c 24             	mov    %ebx,(%esp)
c00296e2:	e8 38 f4 ff ff       	call   c0028b1f <list_next>
c00296e7:	89 c3                	mov    %eax,%ebx
c00296e9:	89 3c 24             	mov    %edi,(%esp)
c00296ec:	e8 82 f4 ff ff       	call   c0028b73 <list_end>
c00296f1:	39 d8                	cmp    %ebx,%eax
c00296f3:	75 d6                	jne    c00296cb <list_max+0x31>
    }
  return max;
}
c00296f5:	89 f0                	mov    %esi,%eax
c00296f7:	83 c4 1c             	add    $0x1c,%esp
c00296fa:	5b                   	pop    %ebx
c00296fb:	5e                   	pop    %esi
c00296fc:	5f                   	pop    %edi
c00296fd:	5d                   	pop    %ebp
c00296fe:	c3                   	ret    

c00296ff <list_min>:
   to LESS given auxiliary data AUX.  If there is more than one
   minimum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_min (struct list *list, list_less_func *less, void *aux)
{
c00296ff:	55                   	push   %ebp
c0029700:	57                   	push   %edi
c0029701:	56                   	push   %esi
c0029702:	53                   	push   %ebx
c0029703:	83 ec 1c             	sub    $0x1c,%esp
c0029706:	8b 7c 24 30          	mov    0x30(%esp),%edi
c002970a:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *min = list_begin (list);
c002970e:	89 3c 24             	mov    %edi,(%esp)
c0029711:	e8 cb f3 ff ff       	call   c0028ae1 <list_begin>
c0029716:	89 c6                	mov    %eax,%esi
  if (min != list_end (list)) 
c0029718:	89 3c 24             	mov    %edi,(%esp)
c002971b:	e8 53 f4 ff ff       	call   c0028b73 <list_end>
c0029720:	39 f0                	cmp    %esi,%eax
c0029722:	74 36                	je     c002975a <list_min+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c0029724:	89 34 24             	mov    %esi,(%esp)
c0029727:	e8 f3 f3 ff ff       	call   c0028b1f <list_next>
c002972c:	89 c3                	mov    %eax,%ebx
c002972e:	eb 1e                	jmp    c002974e <list_min+0x4f>
        if (less (e, min, aux))
c0029730:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0029734:	89 74 24 04          	mov    %esi,0x4(%esp)
c0029738:	89 1c 24             	mov    %ebx,(%esp)
c002973b:	ff 54 24 34          	call   *0x34(%esp)
c002973f:	84 c0                	test   %al,%al
          min = e; 
c0029741:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c0029744:	89 1c 24             	mov    %ebx,(%esp)
c0029747:	e8 d3 f3 ff ff       	call   c0028b1f <list_next>
c002974c:	89 c3                	mov    %eax,%ebx
c002974e:	89 3c 24             	mov    %edi,(%esp)
c0029751:	e8 1d f4 ff ff       	call   c0028b73 <list_end>
c0029756:	39 d8                	cmp    %ebx,%eax
c0029758:	75 d6                	jne    c0029730 <list_min+0x31>
    }
  return min;
}
c002975a:	89 f0                	mov    %esi,%eax
c002975c:	83 c4 1c             	add    $0x1c,%esp
c002975f:	5b                   	pop    %ebx
c0029760:	5e                   	pop    %esi
c0029761:	5f                   	pop    %edi
c0029762:	5d                   	pop    %ebp
c0029763:	c3                   	ret    
c0029764:	90                   	nop
c0029765:	90                   	nop
c0029766:	90                   	nop
c0029767:	90                   	nop
c0029768:	90                   	nop
c0029769:	90                   	nop
c002976a:	90                   	nop
c002976b:	90                   	nop
c002976c:	90                   	nop
c002976d:	90                   	nop
c002976e:	90                   	nop
c002976f:	90                   	nop

c0029770 <bitmap_buf_size>:

/* Returns the number of elements required for BIT_CNT bits. */
static inline size_t
elem_cnt (size_t bit_cnt)
{
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029770:	8b 44 24 04          	mov    0x4(%esp),%eax
c0029774:	83 c0 1f             	add    $0x1f,%eax
c0029777:	c1 e8 05             	shr    $0x5,%eax
/* Returns the number of bytes required to accomodate a bitmap
   with BIT_CNT bits (for use with bitmap_create_in_buf()). */
size_t
bitmap_buf_size (size_t bit_cnt) 
{
  return sizeof (struct bitmap) + byte_cnt (bit_cnt);
c002977a:	8d 04 85 08 00 00 00 	lea    0x8(,%eax,4),%eax
}
c0029781:	c3                   	ret    

c0029782 <bitmap_destroy>:

/* Destroys bitmap B, freeing its storage.
   Not for use on bitmaps created by bitmap_create_in_buf(). */
void
bitmap_destroy (struct bitmap *b) 
{
c0029782:	53                   	push   %ebx
c0029783:	83 ec 18             	sub    $0x18,%esp
c0029786:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (b != NULL) 
c002978a:	85 db                	test   %ebx,%ebx
c002978c:	74 13                	je     c00297a1 <bitmap_destroy+0x1f>
    {
      free (b->bits);
c002978e:	8b 43 04             	mov    0x4(%ebx),%eax
c0029791:	89 04 24             	mov    %eax,(%esp)
c0029794:	e8 62 a4 ff ff       	call   c0023bfb <free>
      free (b);
c0029799:	89 1c 24             	mov    %ebx,(%esp)
c002979c:	e8 5a a4 ff ff       	call   c0023bfb <free>
    }
}
c00297a1:	83 c4 18             	add    $0x18,%esp
c00297a4:	5b                   	pop    %ebx
c00297a5:	c3                   	ret    

c00297a6 <bitmap_size>:

/* Returns the number of bits in B. */
size_t
bitmap_size (const struct bitmap *b)
{
  return b->bit_cnt;
c00297a6:	8b 44 24 04          	mov    0x4(%esp),%eax
c00297aa:	8b 00                	mov    (%eax),%eax
}
c00297ac:	c3                   	ret    

c00297ad <bitmap_mark>:
}

/* Atomically sets the bit numbered BIT_IDX in B to true. */
void
bitmap_mark (struct bitmap *b, size_t bit_idx) 
{
c00297ad:	53                   	push   %ebx
c00297ae:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c00297b2:	89 ca                	mov    %ecx,%edx
c00297b4:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] |= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the OR instruction in [IA32-v2b]. */
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c00297b7:	8b 44 24 08          	mov    0x8(%esp),%eax
c00297bb:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00297be:	bb 01 00 00 00       	mov    $0x1,%ebx
c00297c3:	d3 e3                	shl    %cl,%ebx
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c00297c5:	09 1c 90             	or     %ebx,(%eax,%edx,4)
}
c00297c8:	5b                   	pop    %ebx
c00297c9:	c3                   	ret    

c00297ca <bitmap_reset>:

/* Atomically sets the bit numbered BIT_IDX in B to false. */
void
bitmap_reset (struct bitmap *b, size_t bit_idx) 
{
c00297ca:	53                   	push   %ebx
c00297cb:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c00297cf:	89 ca                	mov    %ecx,%edx
c00297d1:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] &= ~mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the AND instruction in [IA32-v2a]. */
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c00297d4:	8b 44 24 08          	mov    0x8(%esp),%eax
c00297d8:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00297db:	bb 01 00 00 00       	mov    $0x1,%ebx
c00297e0:	d3 e3                	shl    %cl,%ebx
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c00297e2:	f7 d3                	not    %ebx
c00297e4:	21 1c 90             	and    %ebx,(%eax,%edx,4)
}
c00297e7:	5b                   	pop    %ebx
c00297e8:	c3                   	ret    

c00297e9 <bitmap_set>:
{
c00297e9:	83 ec 2c             	sub    $0x2c,%esp
c00297ec:	8b 44 24 30          	mov    0x30(%esp),%eax
c00297f0:	8b 54 24 34          	mov    0x34(%esp),%edx
c00297f4:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  ASSERT (b != NULL);
c00297f8:	85 c0                	test   %eax,%eax
c00297fa:	75 2c                	jne    c0029828 <bitmap_set+0x3f>
c00297fc:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029803:	c0 
c0029804:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002980b:	c0 
c002980c:	c7 44 24 08 07 de 02 	movl   $0xc002de07,0x8(%esp)
c0029813:	c0 
c0029814:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
c002981b:	00 
c002981c:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029823:	e8 9b f1 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c0029828:	39 10                	cmp    %edx,(%eax)
c002982a:	77 2c                	ja     c0029858 <bitmap_set+0x6f>
c002982c:	c7 44 24 10 0c fe 02 	movl   $0xc002fe0c,0x10(%esp)
c0029833:	c0 
c0029834:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002983b:	c0 
c002983c:	c7 44 24 08 07 de 02 	movl   $0xc002de07,0x8(%esp)
c0029843:	c0 
c0029844:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
c002984b:	00 
c002984c:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029853:	e8 6b f1 ff ff       	call   c00289c3 <debug_panic>
  if (value)
c0029858:	84 c9                	test   %cl,%cl
c002985a:	74 0e                	je     c002986a <bitmap_set+0x81>
    bitmap_mark (b, idx);
c002985c:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029860:	89 04 24             	mov    %eax,(%esp)
c0029863:	e8 45 ff ff ff       	call   c00297ad <bitmap_mark>
c0029868:	eb 0c                	jmp    c0029876 <bitmap_set+0x8d>
    bitmap_reset (b, idx);
c002986a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002986e:	89 04 24             	mov    %eax,(%esp)
c0029871:	e8 54 ff ff ff       	call   c00297ca <bitmap_reset>
}
c0029876:	83 c4 2c             	add    $0x2c,%esp
c0029879:	c3                   	ret    

c002987a <bitmap_flip>:
/* Atomically toggles the bit numbered IDX in B;
   that is, if it is true, makes it false,
   and if it is false, makes it true. */
void
bitmap_flip (struct bitmap *b, size_t bit_idx) 
{
c002987a:	53                   	push   %ebx
c002987b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002987f:	89 ca                	mov    %ecx,%edx
c0029881:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] ^= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the XOR instruction in [IA32-v2b]. */
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029884:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029888:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002988b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029890:	d3 e3                	shl    %cl,%ebx
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029892:	31 1c 90             	xor    %ebx,(%eax,%edx,4)
}
c0029895:	5b                   	pop    %ebx
c0029896:	c3                   	ret    

c0029897 <bitmap_test>:

/* Returns the value of the bit numbered IDX in B. */
bool
bitmap_test (const struct bitmap *b, size_t idx) 
{
c0029897:	53                   	push   %ebx
c0029898:	83 ec 28             	sub    $0x28,%esp
c002989b:	8b 44 24 30          	mov    0x30(%esp),%eax
c002989f:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (b != NULL);
c00298a3:	85 c0                	test   %eax,%eax
c00298a5:	75 2c                	jne    c00298d3 <bitmap_test+0x3c>
c00298a7:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c00298ae:	c0 
c00298af:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00298b6:	c0 
c00298b7:	c7 44 24 08 fb dd 02 	movl   $0xc002ddfb,0x8(%esp)
c00298be:	c0 
c00298bf:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
c00298c6:	00 
c00298c7:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c00298ce:	e8 f0 f0 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c00298d3:	39 08                	cmp    %ecx,(%eax)
c00298d5:	77 2c                	ja     c0029903 <bitmap_test+0x6c>
c00298d7:	c7 44 24 10 0c fe 02 	movl   $0xc002fe0c,0x10(%esp)
c00298de:	c0 
c00298df:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00298e6:	c0 
c00298e7:	c7 44 24 08 fb dd 02 	movl   $0xc002ddfb,0x8(%esp)
c00298ee:	c0 
c00298ef:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c00298f6:	00 
c00298f7:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c00298fe:	e8 c0 f0 ff ff       	call   c00289c3 <debug_panic>
  return bit_idx / ELEM_BITS;
c0029903:	89 ca                	mov    %ecx,%edx
c0029905:	c1 ea 05             	shr    $0x5,%edx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c0029908:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002990b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029910:	d3 e3                	shl    %cl,%ebx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c0029912:	85 1c 90             	test   %ebx,(%eax,%edx,4)
c0029915:	0f 95 c0             	setne  %al
}
c0029918:	83 c4 28             	add    $0x28,%esp
c002991b:	5b                   	pop    %ebx
c002991c:	c3                   	ret    

c002991d <bitmap_set_multiple>:
}

/* Sets the CNT bits starting at START in B to VALUE. */
void
bitmap_set_multiple (struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c002991d:	55                   	push   %ebp
c002991e:	57                   	push   %edi
c002991f:	56                   	push   %esi
c0029920:	53                   	push   %ebx
c0029921:	83 ec 2c             	sub    $0x2c,%esp
c0029924:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029928:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c002992c:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029930:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  size_t i;
  
  ASSERT (b != NULL);
c0029935:	85 f6                	test   %esi,%esi
c0029937:	75 2c                	jne    c0029965 <bitmap_set_multiple+0x48>
c0029939:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029940:	c0 
c0029941:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029948:	c0 
c0029949:	c7 44 24 08 d8 dd 02 	movl   $0xc002ddd8,0x8(%esp)
c0029950:	c0 
c0029951:	c7 44 24 04 de 00 00 	movl   $0xde,0x4(%esp)
c0029958:	00 
c0029959:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029960:	e8 5e f0 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029965:	8b 16                	mov    (%esi),%edx
c0029967:	39 da                	cmp    %ebx,%edx
c0029969:	73 2c                	jae    c0029997 <bitmap_set_multiple+0x7a>
c002996b:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029972:	c0 
c0029973:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002997a:	c0 
c002997b:	c7 44 24 08 d8 dd 02 	movl   $0xc002ddd8,0x8(%esp)
c0029982:	c0 
c0029983:	c7 44 24 04 df 00 00 	movl   $0xdf,0x4(%esp)
c002998a:	00 
c002998b:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029992:	e8 2c f0 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029997:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c002999a:	39 fa                	cmp    %edi,%edx
c002999c:	72 09                	jb     c00299a7 <bitmap_set_multiple+0x8a>

  for (i = 0; i < cnt; i++)
    bitmap_set (b, start + i, value);
c002999e:	0f b6 e9             	movzbl %cl,%ebp
  for (i = 0; i < cnt; i++)
c00299a1:	85 c0                	test   %eax,%eax
c00299a3:	75 2e                	jne    c00299d3 <bitmap_set_multiple+0xb6>
c00299a5:	eb 43                	jmp    c00299ea <bitmap_set_multiple+0xcd>
  ASSERT (start + cnt <= b->bit_cnt);
c00299a7:	c7 44 24 10 31 fe 02 	movl   $0xc002fe31,0x10(%esp)
c00299ae:	c0 
c00299af:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00299b6:	c0 
c00299b7:	c7 44 24 08 d8 dd 02 	movl   $0xc002ddd8,0x8(%esp)
c00299be:	c0 
c00299bf:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c00299c6:	00 
c00299c7:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c00299ce:	e8 f0 ef ff ff       	call   c00289c3 <debug_panic>
    bitmap_set (b, start + i, value);
c00299d3:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00299d7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00299db:	89 34 24             	mov    %esi,(%esp)
c00299de:	e8 06 fe ff ff       	call   c00297e9 <bitmap_set>
c00299e3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c00299e6:	39 df                	cmp    %ebx,%edi
c00299e8:	75 e9                	jne    c00299d3 <bitmap_set_multiple+0xb6>
}
c00299ea:	83 c4 2c             	add    $0x2c,%esp
c00299ed:	5b                   	pop    %ebx
c00299ee:	5e                   	pop    %esi
c00299ef:	5f                   	pop    %edi
c00299f0:	5d                   	pop    %ebp
c00299f1:	c3                   	ret    

c00299f2 <bitmap_set_all>:
{
c00299f2:	83 ec 2c             	sub    $0x2c,%esp
c00299f5:	8b 44 24 30          	mov    0x30(%esp),%eax
c00299f9:	8b 54 24 34          	mov    0x34(%esp),%edx
  ASSERT (b != NULL);
c00299fd:	85 c0                	test   %eax,%eax
c00299ff:	75 2c                	jne    c0029a2d <bitmap_set_all+0x3b>
c0029a01:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029a08:	c0 
c0029a09:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029a10:	c0 
c0029a11:	c7 44 24 08 ec dd 02 	movl   $0xc002ddec,0x8(%esp)
c0029a18:	c0 
c0029a19:	c7 44 24 04 d3 00 00 	movl   $0xd3,0x4(%esp)
c0029a20:	00 
c0029a21:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029a28:	e8 96 ef ff ff       	call   c00289c3 <debug_panic>
  bitmap_set_multiple (b, 0, bitmap_size (b), value);
c0029a2d:	0f b6 d2             	movzbl %dl,%edx
c0029a30:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0029a34:	8b 10                	mov    (%eax),%edx
c0029a36:	89 54 24 08          	mov    %edx,0x8(%esp)
c0029a3a:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a41:	00 
c0029a42:	89 04 24             	mov    %eax,(%esp)
c0029a45:	e8 d3 fe ff ff       	call   c002991d <bitmap_set_multiple>
}
c0029a4a:	83 c4 2c             	add    $0x2c,%esp
c0029a4d:	c3                   	ret    

c0029a4e <bitmap_create>:
{
c0029a4e:	56                   	push   %esi
c0029a4f:	53                   	push   %ebx
c0029a50:	83 ec 14             	sub    $0x14,%esp
c0029a53:	8b 74 24 20          	mov    0x20(%esp),%esi
  struct bitmap *b = malloc (sizeof *b);
c0029a57:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c0029a5e:	e8 11 a0 ff ff       	call   c0023a74 <malloc>
c0029a63:	89 c3                	mov    %eax,%ebx
  if (b != NULL)
c0029a65:	85 c0                	test   %eax,%eax
c0029a67:	74 41                	je     c0029aaa <bitmap_create+0x5c>
      b->bit_cnt = bit_cnt;
c0029a69:	89 30                	mov    %esi,(%eax)
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029a6b:	8d 46 1f             	lea    0x1f(%esi),%eax
c0029a6e:	c1 e8 05             	shr    $0x5,%eax
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029a71:	c1 e0 02             	shl    $0x2,%eax
      b->bits = malloc (byte_cnt (bit_cnt));
c0029a74:	89 04 24             	mov    %eax,(%esp)
c0029a77:	e8 f8 9f ff ff       	call   c0023a74 <malloc>
c0029a7c:	89 43 04             	mov    %eax,0x4(%ebx)
      if (b->bits != NULL || bit_cnt == 0)
c0029a7f:	85 c0                	test   %eax,%eax
c0029a81:	75 04                	jne    c0029a87 <bitmap_create+0x39>
c0029a83:	85 f6                	test   %esi,%esi
c0029a85:	75 14                	jne    c0029a9b <bitmap_create+0x4d>
          bitmap_set_all (b, false);
c0029a87:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a8e:	00 
c0029a8f:	89 1c 24             	mov    %ebx,(%esp)
c0029a92:	e8 5b ff ff ff       	call   c00299f2 <bitmap_set_all>
          return b;
c0029a97:	89 d8                	mov    %ebx,%eax
c0029a99:	eb 14                	jmp    c0029aaf <bitmap_create+0x61>
      free (b);
c0029a9b:	89 1c 24             	mov    %ebx,(%esp)
c0029a9e:	e8 58 a1 ff ff       	call   c0023bfb <free>
  return NULL;
c0029aa3:	b8 00 00 00 00       	mov    $0x0,%eax
c0029aa8:	eb 05                	jmp    c0029aaf <bitmap_create+0x61>
c0029aaa:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029aaf:	83 c4 14             	add    $0x14,%esp
c0029ab2:	5b                   	pop    %ebx
c0029ab3:	5e                   	pop    %esi
c0029ab4:	c3                   	ret    

c0029ab5 <bitmap_create_in_buf>:
{
c0029ab5:	56                   	push   %esi
c0029ab6:	53                   	push   %ebx
c0029ab7:	83 ec 24             	sub    $0x24,%esp
c0029aba:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029abe:	8b 5c 24 34          	mov    0x34(%esp),%ebx
  ASSERT (block_size >= bitmap_buf_size (bit_cnt));
c0029ac2:	89 34 24             	mov    %esi,(%esp)
c0029ac5:	e8 a6 fc ff ff       	call   c0029770 <bitmap_buf_size>
c0029aca:	3b 44 24 38          	cmp    0x38(%esp),%eax
c0029ace:	76 2c                	jbe    c0029afc <bitmap_create_in_buf+0x47>
c0029ad0:	c7 44 24 10 4c fe 02 	movl   $0xc002fe4c,0x10(%esp)
c0029ad7:	c0 
c0029ad8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029adf:	c0 
c0029ae0:	c7 44 24 08 12 de 02 	movl   $0xc002de12,0x8(%esp)
c0029ae7:	c0 
c0029ae8:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
c0029aef:	00 
c0029af0:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029af7:	e8 c7 ee ff ff       	call   c00289c3 <debug_panic>
  b->bit_cnt = bit_cnt;
c0029afc:	89 33                	mov    %esi,(%ebx)
  b->bits = (elem_type *) (b + 1);
c0029afe:	8d 43 08             	lea    0x8(%ebx),%eax
c0029b01:	89 43 04             	mov    %eax,0x4(%ebx)
  bitmap_set_all (b, false);
c0029b04:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029b0b:	00 
c0029b0c:	89 1c 24             	mov    %ebx,(%esp)
c0029b0f:	e8 de fe ff ff       	call   c00299f2 <bitmap_set_all>
}
c0029b14:	89 d8                	mov    %ebx,%eax
c0029b16:	83 c4 24             	add    $0x24,%esp
c0029b19:	5b                   	pop    %ebx
c0029b1a:	5e                   	pop    %esi
c0029b1b:	c3                   	ret    

c0029b1c <bitmap_count>:

/* Returns the number of bits in B between START and START + CNT,
   exclusive, that are set to VALUE. */
size_t
bitmap_count (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029b1c:	55                   	push   %ebp
c0029b1d:	57                   	push   %edi
c0029b1e:	56                   	push   %esi
c0029b1f:	53                   	push   %ebx
c0029b20:	83 ec 2c             	sub    $0x2c,%esp
c0029b23:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0029b27:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029b2b:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029b2f:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
c0029b34:	88 4c 24 1f          	mov    %cl,0x1f(%esp)
  size_t i, value_cnt;

  ASSERT (b != NULL);
c0029b38:	85 ff                	test   %edi,%edi
c0029b3a:	75 2c                	jne    c0029b68 <bitmap_count+0x4c>
c0029b3c:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029b43:	c0 
c0029b44:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029b4b:	c0 
c0029b4c:	c7 44 24 08 cb dd 02 	movl   $0xc002ddcb,0x8(%esp)
c0029b53:	c0 
c0029b54:	c7 44 24 04 ed 00 00 	movl   $0xed,0x4(%esp)
c0029b5b:	00 
c0029b5c:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029b63:	e8 5b ee ff ff       	call   c00289c3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029b68:	8b 17                	mov    (%edi),%edx
c0029b6a:	39 da                	cmp    %ebx,%edx
c0029b6c:	73 2c                	jae    c0029b9a <bitmap_count+0x7e>
c0029b6e:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029b75:	c0 
c0029b76:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029b7d:	c0 
c0029b7e:	c7 44 24 08 cb dd 02 	movl   $0xc002ddcb,0x8(%esp)
c0029b85:	c0 
c0029b86:	c7 44 24 04 ee 00 00 	movl   $0xee,0x4(%esp)
c0029b8d:	00 
c0029b8e:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029b95:	e8 29 ee ff ff       	call   c00289c3 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b9a:	8d 2c 03             	lea    (%ebx,%eax,1),%ebp
c0029b9d:	39 ea                	cmp    %ebp,%edx
c0029b9f:	72 0b                	jb     c0029bac <bitmap_count+0x90>

  value_cnt = 0;
  for (i = 0; i < cnt; i++)
c0029ba1:	be 00 00 00 00       	mov    $0x0,%esi
c0029ba6:	85 c0                	test   %eax,%eax
c0029ba8:	75 2e                	jne    c0029bd8 <bitmap_count+0xbc>
c0029baa:	eb 4b                	jmp    c0029bf7 <bitmap_count+0xdb>
  ASSERT (start + cnt <= b->bit_cnt);
c0029bac:	c7 44 24 10 31 fe 02 	movl   $0xc002fe31,0x10(%esp)
c0029bb3:	c0 
c0029bb4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029bbb:	c0 
c0029bbc:	c7 44 24 08 cb dd 02 	movl   $0xc002ddcb,0x8(%esp)
c0029bc3:	c0 
c0029bc4:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0029bcb:	00 
c0029bcc:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029bd3:	e8 eb ed ff ff       	call   c00289c3 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029bd8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029bdc:	89 3c 24             	mov    %edi,(%esp)
c0029bdf:	e8 b3 fc ff ff       	call   c0029897 <bitmap_test>
      value_cnt++;
c0029be4:	3a 44 24 1f          	cmp    0x1f(%esp),%al
c0029be8:	0f 94 c0             	sete   %al
c0029beb:	0f b6 c0             	movzbl %al,%eax
c0029bee:	01 c6                	add    %eax,%esi
c0029bf0:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029bf3:	39 dd                	cmp    %ebx,%ebp
c0029bf5:	75 e1                	jne    c0029bd8 <bitmap_count+0xbc>
  return value_cnt;
}
c0029bf7:	89 f0                	mov    %esi,%eax
c0029bf9:	83 c4 2c             	add    $0x2c,%esp
c0029bfc:	5b                   	pop    %ebx
c0029bfd:	5e                   	pop    %esi
c0029bfe:	5f                   	pop    %edi
c0029bff:	5d                   	pop    %ebp
c0029c00:	c3                   	ret    

c0029c01 <bitmap_contains>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to VALUE, and false otherwise. */
bool
bitmap_contains (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029c01:	55                   	push   %ebp
c0029c02:	57                   	push   %edi
c0029c03:	56                   	push   %esi
c0029c04:	53                   	push   %ebx
c0029c05:	83 ec 2c             	sub    $0x2c,%esp
c0029c08:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029c0c:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029c10:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029c14:	0f b6 6c 24 4c       	movzbl 0x4c(%esp),%ebp
  size_t i;
  
  ASSERT (b != NULL);
c0029c19:	85 f6                	test   %esi,%esi
c0029c1b:	75 2c                	jne    c0029c49 <bitmap_contains+0x48>
c0029c1d:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029c24:	c0 
c0029c25:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029c2c:	c0 
c0029c2d:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c0029c34:	c0 
c0029c35:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
c0029c3c:	00 
c0029c3d:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029c44:	e8 7a ed ff ff       	call   c00289c3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029c49:	8b 16                	mov    (%esi),%edx
c0029c4b:	39 da                	cmp    %ebx,%edx
c0029c4d:	73 2c                	jae    c0029c7b <bitmap_contains+0x7a>
c0029c4f:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029c56:	c0 
c0029c57:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029c5e:	c0 
c0029c5f:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c0029c66:	c0 
c0029c67:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
c0029c6e:	00 
c0029c6f:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029c76:	e8 48 ed ff ff       	call   c00289c3 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c7b:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c0029c7e:	39 fa                	cmp    %edi,%edx
c0029c80:	72 06                	jb     c0029c88 <bitmap_contains+0x87>

  for (i = 0; i < cnt; i++)
c0029c82:	85 c0                	test   %eax,%eax
c0029c84:	75 2e                	jne    c0029cb4 <bitmap_contains+0xb3>
c0029c86:	eb 53                	jmp    c0029cdb <bitmap_contains+0xda>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c88:	c7 44 24 10 31 fe 02 	movl   $0xc002fe31,0x10(%esp)
c0029c8f:	c0 
c0029c90:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029c97:	c0 
c0029c98:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c0029c9f:	c0 
c0029ca0:	c7 44 24 04 01 01 00 	movl   $0x101,0x4(%esp)
c0029ca7:	00 
c0029ca8:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029caf:	e8 0f ed ff ff       	call   c00289c3 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029cb4:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029cb8:	89 34 24             	mov    %esi,(%esp)
c0029cbb:	e8 d7 fb ff ff       	call   c0029897 <bitmap_test>
c0029cc0:	89 e9                	mov    %ebp,%ecx
c0029cc2:	38 c8                	cmp    %cl,%al
c0029cc4:	74 09                	je     c0029ccf <bitmap_contains+0xce>
c0029cc6:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029cc9:	39 df                	cmp    %ebx,%edi
c0029ccb:	75 e7                	jne    c0029cb4 <bitmap_contains+0xb3>
c0029ccd:	eb 07                	jmp    c0029cd6 <bitmap_contains+0xd5>
      return true;
c0029ccf:	b8 01 00 00 00       	mov    $0x1,%eax
c0029cd4:	eb 05                	jmp    c0029cdb <bitmap_contains+0xda>
  return false;
c0029cd6:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029cdb:	83 c4 2c             	add    $0x2c,%esp
c0029cde:	5b                   	pop    %ebx
c0029cdf:	5e                   	pop    %esi
c0029ce0:	5f                   	pop    %edi
c0029ce1:	5d                   	pop    %ebp
c0029ce2:	c3                   	ret    

c0029ce3 <bitmap_any>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_any (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029ce3:	83 ec 1c             	sub    $0x1c,%esp
  return bitmap_contains (b, start, cnt, true);
c0029ce6:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029ced:	00 
c0029cee:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029cf2:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029cf6:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029cfa:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029cfe:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029d02:	89 04 24             	mov    %eax,(%esp)
c0029d05:	e8 f7 fe ff ff       	call   c0029c01 <bitmap_contains>
}
c0029d0a:	83 c4 1c             	add    $0x1c,%esp
c0029d0d:	c3                   	ret    

c0029d0e <bitmap_none>:

/* Returns true if no bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_none (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029d0e:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, true);
c0029d11:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029d18:	00 
c0029d19:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029d1d:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029d21:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029d25:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029d29:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029d2d:	89 04 24             	mov    %eax,(%esp)
c0029d30:	e8 cc fe ff ff       	call   c0029c01 <bitmap_contains>
c0029d35:	83 f0 01             	xor    $0x1,%eax
}
c0029d38:	83 c4 1c             	add    $0x1c,%esp
c0029d3b:	c3                   	ret    

c0029d3c <bitmap_all>:

/* Returns true if every bit in B between START and START + CNT,
   exclusive, is set to true, and false otherwise. */
bool
bitmap_all (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029d3c:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, false);
c0029d3f:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029d46:	00 
c0029d47:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029d4b:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029d4f:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029d53:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029d57:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029d5b:	89 04 24             	mov    %eax,(%esp)
c0029d5e:	e8 9e fe ff ff       	call   c0029c01 <bitmap_contains>
c0029d63:	83 f0 01             	xor    $0x1,%eax
}
c0029d66:	83 c4 1c             	add    $0x1c,%esp
c0029d69:	c3                   	ret    

c0029d6a <bitmap_scan>:
   consecutive bits in B at or after START that are all set to
   VALUE.
   If there is no such group, returns BITMAP_ERROR. */
size_t
bitmap_scan (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029d6a:	55                   	push   %ebp
c0029d6b:	57                   	push   %edi
c0029d6c:	56                   	push   %esi
c0029d6d:	53                   	push   %ebx
c0029d6e:	83 ec 2c             	sub    $0x2c,%esp
c0029d71:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029d75:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029d79:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0029d7d:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  ASSERT (b != NULL);
c0029d82:	85 f6                	test   %esi,%esi
c0029d84:	75 2c                	jne    c0029db2 <bitmap_scan+0x48>
c0029d86:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029d8d:	c0 
c0029d8e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029d95:	c0 
c0029d96:	c7 44 24 08 af dd 02 	movl   $0xc002ddaf,0x8(%esp)
c0029d9d:	c0 
c0029d9e:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0029da5:	00 
c0029da6:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029dad:	e8 11 ec ff ff       	call   c00289c3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029db2:	8b 16                	mov    (%esi),%edx
c0029db4:	39 da                	cmp    %ebx,%edx
c0029db6:	73 2c                	jae    c0029de4 <bitmap_scan+0x7a>
c0029db8:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029dbf:	c0 
c0029dc0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029dc7:	c0 
c0029dc8:	c7 44 24 08 af dd 02 	movl   $0xc002ddaf,0x8(%esp)
c0029dcf:	c0 
c0029dd0:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0029dd7:	00 
c0029dd8:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029ddf:	e8 df eb ff ff       	call   c00289c3 <debug_panic>
      size_t i;
      for (i = start; i <= last; i++)
        if (!bitmap_contains (b, i, cnt, !value))
          return i; 
    }
  return BITMAP_ERROR;
c0029de4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  if (cnt <= b->bit_cnt) 
c0029de9:	39 fa                	cmp    %edi,%edx
c0029deb:	72 45                	jb     c0029e32 <bitmap_scan+0xc8>
      size_t last = b->bit_cnt - cnt;
c0029ded:	29 fa                	sub    %edi,%edx
c0029def:	89 54 24 1c          	mov    %edx,0x1c(%esp)
      for (i = start; i <= last; i++)
c0029df3:	39 d3                	cmp    %edx,%ebx
c0029df5:	77 2b                	ja     c0029e22 <bitmap_scan+0xb8>
        if (!bitmap_contains (b, i, cnt, !value))
c0029df7:	83 f1 01             	xor    $0x1,%ecx
c0029dfa:	0f b6 e9             	movzbl %cl,%ebp
c0029dfd:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029e01:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e05:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029e09:	89 34 24             	mov    %esi,(%esp)
c0029e0c:	e8 f0 fd ff ff       	call   c0029c01 <bitmap_contains>
c0029e11:	84 c0                	test   %al,%al
c0029e13:	74 14                	je     c0029e29 <bitmap_scan+0xbf>
      for (i = start; i <= last; i++)
c0029e15:	83 c3 01             	add    $0x1,%ebx
c0029e18:	39 5c 24 1c          	cmp    %ebx,0x1c(%esp)
c0029e1c:	73 df                	jae    c0029dfd <bitmap_scan+0x93>
c0029e1e:	66 90                	xchg   %ax,%ax
c0029e20:	eb 0b                	jmp    c0029e2d <bitmap_scan+0xc3>
  return BITMAP_ERROR;
c0029e22:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0029e27:	eb 09                	jmp    c0029e32 <bitmap_scan+0xc8>
c0029e29:	89 d8                	mov    %ebx,%eax
c0029e2b:	eb 05                	jmp    c0029e32 <bitmap_scan+0xc8>
c0029e2d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0029e32:	83 c4 2c             	add    $0x2c,%esp
c0029e35:	5b                   	pop    %ebx
c0029e36:	5e                   	pop    %esi
c0029e37:	5f                   	pop    %edi
c0029e38:	5d                   	pop    %ebp
c0029e39:	c3                   	ret    

c0029e3a <bitmap_scan_and_flip>:
   If CNT is zero, returns 0.
   Bits are set atomically, but testing bits is not atomic with
   setting them. */
size_t
bitmap_scan_and_flip (struct bitmap *b, size_t start, size_t cnt, bool value)
{
c0029e3a:	55                   	push   %ebp
c0029e3b:	57                   	push   %edi
c0029e3c:	56                   	push   %esi
c0029e3d:	53                   	push   %ebx
c0029e3e:	83 ec 1c             	sub    $0x1c,%esp
c0029e41:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029e45:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0029e49:	8b 6c 24 3c          	mov    0x3c(%esp),%ebp
  size_t idx = bitmap_scan (b, start, cnt, value);
c0029e4d:	89 e8                	mov    %ebp,%eax
c0029e4f:	0f b6 c0             	movzbl %al,%eax
c0029e52:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0029e56:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e5a:	8b 44 24 34          	mov    0x34(%esp),%eax
c0029e5e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e62:	89 34 24             	mov    %esi,(%esp)
c0029e65:	e8 00 ff ff ff       	call   c0029d6a <bitmap_scan>
c0029e6a:	89 c3                	mov    %eax,%ebx
  if (idx != BITMAP_ERROR) 
c0029e6c:	83 f8 ff             	cmp    $0xffffffff,%eax
c0029e6f:	74 1c                	je     c0029e8d <bitmap_scan_and_flip+0x53>
    bitmap_set_multiple (b, idx, cnt, !value);
c0029e71:	89 e8                	mov    %ebp,%eax
c0029e73:	83 f0 01             	xor    $0x1,%eax
c0029e76:	0f b6 e8             	movzbl %al,%ebp
c0029e79:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029e7d:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e81:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029e85:	89 34 24             	mov    %esi,(%esp)
c0029e88:	e8 90 fa ff ff       	call   c002991d <bitmap_set_multiple>
  return idx;
}
c0029e8d:	89 d8                	mov    %ebx,%eax
c0029e8f:	83 c4 1c             	add    $0x1c,%esp
c0029e92:	5b                   	pop    %ebx
c0029e93:	5e                   	pop    %esi
c0029e94:	5f                   	pop    %edi
c0029e95:	5d                   	pop    %ebp
c0029e96:	c3                   	ret    

c0029e97 <bitmap_dump>:
/* Debugging. */

/* Dumps the contents of B to the console as hexadecimal. */
void
bitmap_dump (const struct bitmap *b) 
{
c0029e97:	83 ec 1c             	sub    $0x1c,%esp
c0029e9a:	8b 44 24 20          	mov    0x20(%esp),%eax
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e9e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029ea5:	00 
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029ea6:	8b 08                	mov    (%eax),%ecx
c0029ea8:	8d 51 1f             	lea    0x1f(%ecx),%edx
c0029eab:	c1 ea 05             	shr    $0x5,%edx
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029eae:	c1 e2 02             	shl    $0x2,%edx
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029eb1:	89 54 24 08          	mov    %edx,0x8(%esp)
c0029eb5:	8b 40 04             	mov    0x4(%eax),%eax
c0029eb8:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029ebc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0029ec3:	e8 d2 d3 ff ff       	call   c002729a <hex_dump>
}
c0029ec8:	83 c4 1c             	add    $0x1c,%esp
c0029ecb:	c3                   	ret    
c0029ecc:	90                   	nop
c0029ecd:	90                   	nop
c0029ece:	90                   	nop
c0029ecf:	90                   	nop

c0029ed0 <find_bucket>:
}

/* Returns the bucket in H that E belongs in. */
static struct list *
find_bucket (struct hash *h, struct hash_elem *e) 
{
c0029ed0:	53                   	push   %ebx
c0029ed1:	83 ec 18             	sub    $0x18,%esp
c0029ed4:	89 c3                	mov    %eax,%ebx
  size_t bucket_idx = h->hash (e, h->aux) & (h->bucket_cnt - 1);
c0029ed6:	8b 40 14             	mov    0x14(%eax),%eax
c0029ed9:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029edd:	89 14 24             	mov    %edx,(%esp)
c0029ee0:	ff 53 0c             	call   *0xc(%ebx)
c0029ee3:	8b 4b 04             	mov    0x4(%ebx),%ecx
c0029ee6:	8d 51 ff             	lea    -0x1(%ecx),%edx
c0029ee9:	21 d0                	and    %edx,%eax
  return &h->buckets[bucket_idx];
c0029eeb:	c1 e0 04             	shl    $0x4,%eax
c0029eee:	03 43 08             	add    0x8(%ebx),%eax
}
c0029ef1:	83 c4 18             	add    $0x18,%esp
c0029ef4:	5b                   	pop    %ebx
c0029ef5:	c3                   	ret    

c0029ef6 <find_elem>:

/* Searches BUCKET in H for a hash element equal to E.  Returns
   it if found or a null pointer otherwise. */
static struct hash_elem *
find_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
c0029ef6:	55                   	push   %ebp
c0029ef7:	57                   	push   %edi
c0029ef8:	56                   	push   %esi
c0029ef9:	53                   	push   %ebx
c0029efa:	83 ec 1c             	sub    $0x1c,%esp
c0029efd:	89 c6                	mov    %eax,%esi
c0029eff:	89 d5                	mov    %edx,%ebp
c0029f01:	89 cf                	mov    %ecx,%edi
  struct list_elem *i;

  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029f03:	89 14 24             	mov    %edx,(%esp)
c0029f06:	e8 d6 eb ff ff       	call   c0028ae1 <list_begin>
c0029f0b:	89 c3                	mov    %eax,%ebx
c0029f0d:	eb 34                	jmp    c0029f43 <find_elem+0x4d>
    {
      struct hash_elem *hi = list_elem_to_hash_elem (i);
      if (!h->less (hi, e, h->aux) && !h->less (e, hi, h->aux))
c0029f0f:	8b 46 14             	mov    0x14(%esi),%eax
c0029f12:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029f16:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029f1a:	89 1c 24             	mov    %ebx,(%esp)
c0029f1d:	ff 56 10             	call   *0x10(%esi)
c0029f20:	84 c0                	test   %al,%al
c0029f22:	75 15                	jne    c0029f39 <find_elem+0x43>
c0029f24:	8b 46 14             	mov    0x14(%esi),%eax
c0029f27:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029f2b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029f2f:	89 3c 24             	mov    %edi,(%esp)
c0029f32:	ff 56 10             	call   *0x10(%esi)
c0029f35:	84 c0                	test   %al,%al
c0029f37:	74 1d                	je     c0029f56 <find_elem+0x60>
  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029f39:	89 1c 24             	mov    %ebx,(%esp)
c0029f3c:	e8 de eb ff ff       	call   c0028b1f <list_next>
c0029f41:	89 c3                	mov    %eax,%ebx
c0029f43:	89 2c 24             	mov    %ebp,(%esp)
c0029f46:	e8 28 ec ff ff       	call   c0028b73 <list_end>
c0029f4b:	39 d8                	cmp    %ebx,%eax
c0029f4d:	75 c0                	jne    c0029f0f <find_elem+0x19>
        return hi; 
    }
  return NULL;
c0029f4f:	b8 00 00 00 00       	mov    $0x0,%eax
c0029f54:	eb 02                	jmp    c0029f58 <find_elem+0x62>
c0029f56:	89 d8                	mov    %ebx,%eax
}
c0029f58:	83 c4 1c             	add    $0x1c,%esp
c0029f5b:	5b                   	pop    %ebx
c0029f5c:	5e                   	pop    %esi
c0029f5d:	5f                   	pop    %edi
c0029f5e:	5d                   	pop    %ebp
c0029f5f:	c3                   	ret    

c0029f60 <rehash>:
   ideal.  This function can fail because of an out-of-memory
   condition, but that'll just make hash accesses less efficient;
   we can still continue. */
static void
rehash (struct hash *h) 
{
c0029f60:	55                   	push   %ebp
c0029f61:	57                   	push   %edi
c0029f62:	56                   	push   %esi
c0029f63:	53                   	push   %ebx
c0029f64:	83 ec 3c             	sub    $0x3c,%esp
c0029f67:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  size_t old_bucket_cnt, new_bucket_cnt;
  struct list *new_buckets, *old_buckets;
  size_t i;

  ASSERT (h != NULL);
c0029f6b:	85 c0                	test   %eax,%eax
c0029f6d:	75 2c                	jne    c0029f9b <rehash+0x3b>
c0029f6f:	c7 44 24 10 74 fe 02 	movl   $0xc002fe74,0x10(%esp)
c0029f76:	c0 
c0029f77:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029f7e:	c0 
c0029f7f:	c7 44 24 08 5e de 02 	movl   $0xc002de5e,0x8(%esp)
c0029f86:	c0 
c0029f87:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0029f8e:	00 
c0029f8f:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c0029f96:	e8 28 ea ff ff       	call   c00289c3 <debug_panic>

  /* Save old bucket info for later use. */
  old_buckets = h->buckets;
c0029f9b:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029f9f:	8b 48 08             	mov    0x8(%eax),%ecx
c0029fa2:	89 4c 24 2c          	mov    %ecx,0x2c(%esp)
  old_bucket_cnt = h->bucket_cnt;
c0029fa6:	8b 48 04             	mov    0x4(%eax),%ecx
c0029fa9:	89 4c 24 28          	mov    %ecx,0x28(%esp)

  /* Calculate the number of buckets to use now.
     We want one bucket for about every BEST_ELEMS_PER_BUCKET.
     We must have at least four buckets, and the number of
     buckets must be a power of 2. */
  new_bucket_cnt = h->elem_cnt / BEST_ELEMS_PER_BUCKET;
c0029fad:	8b 00                	mov    (%eax),%eax
c0029faf:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029fb3:	89 c3                	mov    %eax,%ebx
c0029fb5:	d1 eb                	shr    %ebx
  if (new_bucket_cnt < 4)
    new_bucket_cnt = 4;
c0029fb7:	83 fb 03             	cmp    $0x3,%ebx
c0029fba:	b8 04 00 00 00       	mov    $0x4,%eax
c0029fbf:	0f 46 d8             	cmovbe %eax,%ebx
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029fc2:	85 db                	test   %ebx,%ebx
c0029fc4:	0f 84 d2 00 00 00    	je     c002a09c <rehash+0x13c>
  return x & (x - 1);
c0029fca:	8d 43 ff             	lea    -0x1(%ebx),%eax
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029fcd:	85 d8                	test   %ebx,%eax
c0029fcf:	0f 85 c7 00 00 00    	jne    c002a09c <rehash+0x13c>
c0029fd5:	e9 cc 00 00 00       	jmp    c002a0a6 <rehash+0x146>
  /* Don't do anything if the bucket count wouldn't change. */
  if (new_bucket_cnt == old_bucket_cnt)
    return;

  /* Allocate new buckets and initialize them as empty. */
  new_buckets = malloc (sizeof *new_buckets * new_bucket_cnt);
c0029fda:	89 d8                	mov    %ebx,%eax
c0029fdc:	c1 e0 04             	shl    $0x4,%eax
c0029fdf:	89 04 24             	mov    %eax,(%esp)
c0029fe2:	e8 8d 9a ff ff       	call   c0023a74 <malloc>
c0029fe7:	89 c5                	mov    %eax,%ebp
  if (new_buckets == NULL) 
c0029fe9:	85 c0                	test   %eax,%eax
c0029feb:	0f 84 bf 00 00 00    	je     c002a0b0 <rehash+0x150>
      /* Allocation failed.  This means that use of the hash table will
         be less efficient.  However, it is still usable, so
         there's no reason for it to be an error. */
      return;
    }
  for (i = 0; i < new_bucket_cnt; i++) 
c0029ff1:	85 db                	test   %ebx,%ebx
c0029ff3:	74 19                	je     c002a00e <rehash+0xae>
c0029ff5:	89 c7                	mov    %eax,%edi
c0029ff7:	be 00 00 00 00       	mov    $0x0,%esi
    list_init (&new_buckets[i]);
c0029ffc:	89 3c 24             	mov    %edi,(%esp)
c0029fff:	e8 8c ea ff ff       	call   c0028a90 <list_init>
  for (i = 0; i < new_bucket_cnt; i++) 
c002a004:	83 c6 01             	add    $0x1,%esi
c002a007:	83 c7 10             	add    $0x10,%edi
c002a00a:	39 de                	cmp    %ebx,%esi
c002a00c:	75 ee                	jne    c0029ffc <rehash+0x9c>

  /* Install new bucket info. */
  h->buckets = new_buckets;
c002a00e:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a012:	89 68 08             	mov    %ebp,0x8(%eax)
  h->bucket_cnt = new_bucket_cnt;
c002a015:	89 58 04             	mov    %ebx,0x4(%eax)

  /* Move each old element into the appropriate new bucket. */
  for (i = 0; i < old_bucket_cnt; i++) 
c002a018:	83 7c 24 28 00       	cmpl   $0x0,0x28(%esp)
c002a01d:	74 6f                	je     c002a08e <rehash+0x12e>
c002a01f:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a023:	89 44 24 20          	mov    %eax,0x20(%esp)
c002a027:	c7 44 24 24 00 00 00 	movl   $0x0,0x24(%esp)
c002a02e:	00 
    {
      struct list *old_bucket;
      struct list_elem *elem, *next;

      old_bucket = &old_buckets[i];
c002a02f:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a033:	89 c5                	mov    %eax,%ebp
      for (elem = list_begin (old_bucket);
c002a035:	89 04 24             	mov    %eax,(%esp)
c002a038:	e8 a4 ea ff ff       	call   c0028ae1 <list_begin>
c002a03d:	89 c3                	mov    %eax,%ebx
c002a03f:	eb 2d                	jmp    c002a06e <rehash+0x10e>
           elem != list_end (old_bucket); elem = next) 
        {
          struct list *new_bucket
c002a041:	89 da                	mov    %ebx,%edx
c002a043:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a047:	e8 84 fe ff ff       	call   c0029ed0 <find_bucket>
c002a04c:	89 c7                	mov    %eax,%edi
            = find_bucket (h, list_elem_to_hash_elem (elem));
          next = list_next (elem);
c002a04e:	89 1c 24             	mov    %ebx,(%esp)
c002a051:	e8 c9 ea ff ff       	call   c0028b1f <list_next>
c002a056:	89 c6                	mov    %eax,%esi
          list_remove (elem);
c002a058:	89 1c 24             	mov    %ebx,(%esp)
c002a05b:	e8 d4 ef ff ff       	call   c0029034 <list_remove>
          list_push_front (new_bucket, elem);
c002a060:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002a064:	89 3c 24             	mov    %edi,(%esp)
c002a067:	e8 82 ef ff ff       	call   c0028fee <list_push_front>
           elem != list_end (old_bucket); elem = next) 
c002a06c:	89 f3                	mov    %esi,%ebx
c002a06e:	89 2c 24             	mov    %ebp,(%esp)
c002a071:	e8 fd ea ff ff       	call   c0028b73 <list_end>
      for (elem = list_begin (old_bucket);
c002a076:	39 d8                	cmp    %ebx,%eax
c002a078:	75 c7                	jne    c002a041 <rehash+0xe1>
  for (i = 0; i < old_bucket_cnt; i++) 
c002a07a:	83 44 24 24 01       	addl   $0x1,0x24(%esp)
c002a07f:	83 44 24 20 10       	addl   $0x10,0x20(%esp)
c002a084:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a088:	39 44 24 24          	cmp    %eax,0x24(%esp)
c002a08c:	75 a1                	jne    c002a02f <rehash+0xcf>
        }
    }

  free (old_buckets);
c002a08e:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a092:	89 04 24             	mov    %eax,(%esp)
c002a095:	e8 61 9b ff ff       	call   c0023bfb <free>
c002a09a:	eb 14                	jmp    c002a0b0 <rehash+0x150>
  return x & (x - 1);
c002a09c:	8d 43 ff             	lea    -0x1(%ebx),%eax
c002a09f:	21 c3                	and    %eax,%ebx
c002a0a1:	e9 1c ff ff ff       	jmp    c0029fc2 <rehash+0x62>
  if (new_bucket_cnt == old_bucket_cnt)
c002a0a6:	3b 5c 24 28          	cmp    0x28(%esp),%ebx
c002a0aa:	0f 85 2a ff ff ff    	jne    c0029fda <rehash+0x7a>
}
c002a0b0:	83 c4 3c             	add    $0x3c,%esp
c002a0b3:	5b                   	pop    %ebx
c002a0b4:	5e                   	pop    %esi
c002a0b5:	5f                   	pop    %edi
c002a0b6:	5d                   	pop    %ebp
c002a0b7:	c3                   	ret    

c002a0b8 <hash_clear>:
{
c002a0b8:	55                   	push   %ebp
c002a0b9:	57                   	push   %edi
c002a0ba:	56                   	push   %esi
c002a0bb:	53                   	push   %ebx
c002a0bc:	83 ec 1c             	sub    $0x1c,%esp
c002a0bf:	8b 74 24 30          	mov    0x30(%esp),%esi
c002a0c3:	8b 7c 24 34          	mov    0x34(%esp),%edi
  for (i = 0; i < h->bucket_cnt; i++) 
c002a0c7:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c002a0cb:	74 43                	je     c002a110 <hash_clear+0x58>
c002a0cd:	bd 00 00 00 00       	mov    $0x0,%ebp
c002a0d2:	89 eb                	mov    %ebp,%ebx
c002a0d4:	c1 e3 04             	shl    $0x4,%ebx
      struct list *bucket = &h->buckets[i];
c002a0d7:	03 5e 08             	add    0x8(%esi),%ebx
      if (destructor != NULL) 
c002a0da:	85 ff                	test   %edi,%edi
c002a0dc:	75 16                	jne    c002a0f4 <hash_clear+0x3c>
c002a0de:	eb 20                	jmp    c002a100 <hash_clear+0x48>
            struct list_elem *list_elem = list_pop_front (bucket);
c002a0e0:	89 1c 24             	mov    %ebx,(%esp)
c002a0e3:	e8 4c f0 ff ff       	call   c0029134 <list_pop_front>
            destructor (hash_elem, h->aux);
c002a0e8:	8b 56 14             	mov    0x14(%esi),%edx
c002a0eb:	89 54 24 04          	mov    %edx,0x4(%esp)
c002a0ef:	89 04 24             	mov    %eax,(%esp)
c002a0f2:	ff d7                	call   *%edi
        while (!list_empty (bucket)) 
c002a0f4:	89 1c 24             	mov    %ebx,(%esp)
c002a0f7:	e8 ca ef ff ff       	call   c00290c6 <list_empty>
c002a0fc:	84 c0                	test   %al,%al
c002a0fe:	74 e0                	je     c002a0e0 <hash_clear+0x28>
      list_init (bucket); 
c002a100:	89 1c 24             	mov    %ebx,(%esp)
c002a103:	e8 88 e9 ff ff       	call   c0028a90 <list_init>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a108:	83 c5 01             	add    $0x1,%ebp
c002a10b:	39 6e 04             	cmp    %ebp,0x4(%esi)
c002a10e:	77 c2                	ja     c002a0d2 <hash_clear+0x1a>
  h->elem_cnt = 0;
c002a110:	c7 06 00 00 00 00    	movl   $0x0,(%esi)
}
c002a116:	83 c4 1c             	add    $0x1c,%esp
c002a119:	5b                   	pop    %ebx
c002a11a:	5e                   	pop    %esi
c002a11b:	5f                   	pop    %edi
c002a11c:	5d                   	pop    %ebp
c002a11d:	c3                   	ret    

c002a11e <hash_init>:
{
c002a11e:	53                   	push   %ebx
c002a11f:	83 ec 18             	sub    $0x18,%esp
c002a122:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  h->elem_cnt = 0;
c002a126:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  h->bucket_cnt = 4;
c002a12c:	c7 43 04 04 00 00 00 	movl   $0x4,0x4(%ebx)
  h->buckets = malloc (sizeof *h->buckets * h->bucket_cnt);
c002a133:	c7 04 24 40 00 00 00 	movl   $0x40,(%esp)
c002a13a:	e8 35 99 ff ff       	call   c0023a74 <malloc>
c002a13f:	89 c2                	mov    %eax,%edx
c002a141:	89 43 08             	mov    %eax,0x8(%ebx)
  h->hash = hash;
c002a144:	8b 44 24 24          	mov    0x24(%esp),%eax
c002a148:	89 43 0c             	mov    %eax,0xc(%ebx)
  h->less = less;
c002a14b:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a14f:	89 43 10             	mov    %eax,0x10(%ebx)
  h->aux = aux;
c002a152:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a156:	89 43 14             	mov    %eax,0x14(%ebx)
    return false;
c002a159:	b8 00 00 00 00       	mov    $0x0,%eax
  if (h->buckets != NULL) 
c002a15e:	85 d2                	test   %edx,%edx
c002a160:	74 15                	je     c002a177 <hash_init+0x59>
      hash_clear (h, NULL);
c002a162:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002a169:	00 
c002a16a:	89 1c 24             	mov    %ebx,(%esp)
c002a16d:	e8 46 ff ff ff       	call   c002a0b8 <hash_clear>
      return true;
c002a172:	b8 01 00 00 00       	mov    $0x1,%eax
}
c002a177:	83 c4 18             	add    $0x18,%esp
c002a17a:	5b                   	pop    %ebx
c002a17b:	c3                   	ret    

c002a17c <hash_destroy>:
{
c002a17c:	53                   	push   %ebx
c002a17d:	83 ec 18             	sub    $0x18,%esp
c002a180:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a184:	8b 44 24 24          	mov    0x24(%esp),%eax
  if (destructor != NULL)
c002a188:	85 c0                	test   %eax,%eax
c002a18a:	74 0c                	je     c002a198 <hash_destroy+0x1c>
    hash_clear (h, destructor);
c002a18c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a190:	89 1c 24             	mov    %ebx,(%esp)
c002a193:	e8 20 ff ff ff       	call   c002a0b8 <hash_clear>
  free (h->buckets);
c002a198:	8b 43 08             	mov    0x8(%ebx),%eax
c002a19b:	89 04 24             	mov    %eax,(%esp)
c002a19e:	e8 58 9a ff ff       	call   c0023bfb <free>
}
c002a1a3:	83 c4 18             	add    $0x18,%esp
c002a1a6:	5b                   	pop    %ebx
c002a1a7:	c3                   	ret    

c002a1a8 <hash_insert>:
{
c002a1a8:	55                   	push   %ebp
c002a1a9:	57                   	push   %edi
c002a1aa:	56                   	push   %esi
c002a1ab:	53                   	push   %ebx
c002a1ac:	83 ec 1c             	sub    $0x1c,%esp
c002a1af:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a1b3:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a1b7:	89 f2                	mov    %esi,%edx
c002a1b9:	89 d8                	mov    %ebx,%eax
c002a1bb:	e8 10 fd ff ff       	call   c0029ed0 <find_bucket>
c002a1c0:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a1c2:	89 f1                	mov    %esi,%ecx
c002a1c4:	89 c2                	mov    %eax,%edx
c002a1c6:	89 d8                	mov    %ebx,%eax
c002a1c8:	e8 29 fd ff ff       	call   c0029ef6 <find_elem>
c002a1cd:	89 c7                	mov    %eax,%edi
  if (old == NULL) 
c002a1cf:	85 c0                	test   %eax,%eax
c002a1d1:	75 0f                	jne    c002a1e2 <hash_insert+0x3a>

/* Inserts E into BUCKET (in hash table H). */
static void
insert_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
  h->elem_cnt++;
c002a1d3:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a1d6:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a1da:	89 2c 24             	mov    %ebp,(%esp)
c002a1dd:	e8 0c ee ff ff       	call   c0028fee <list_push_front>
  rehash (h);
c002a1e2:	89 d8                	mov    %ebx,%eax
c002a1e4:	e8 77 fd ff ff       	call   c0029f60 <rehash>
}
c002a1e9:	89 f8                	mov    %edi,%eax
c002a1eb:	83 c4 1c             	add    $0x1c,%esp
c002a1ee:	5b                   	pop    %ebx
c002a1ef:	5e                   	pop    %esi
c002a1f0:	5f                   	pop    %edi
c002a1f1:	5d                   	pop    %ebp
c002a1f2:	c3                   	ret    

c002a1f3 <hash_replace>:
{
c002a1f3:	55                   	push   %ebp
c002a1f4:	57                   	push   %edi
c002a1f5:	56                   	push   %esi
c002a1f6:	53                   	push   %ebx
c002a1f7:	83 ec 1c             	sub    $0x1c,%esp
c002a1fa:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a1fe:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a202:	89 f2                	mov    %esi,%edx
c002a204:	89 d8                	mov    %ebx,%eax
c002a206:	e8 c5 fc ff ff       	call   c0029ed0 <find_bucket>
c002a20b:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a20d:	89 f1                	mov    %esi,%ecx
c002a20f:	89 c2                	mov    %eax,%edx
c002a211:	89 d8                	mov    %ebx,%eax
c002a213:	e8 de fc ff ff       	call   c0029ef6 <find_elem>
c002a218:	89 c7                	mov    %eax,%edi
  if (old != NULL)
c002a21a:	85 c0                	test   %eax,%eax
c002a21c:	74 0b                	je     c002a229 <hash_replace+0x36>

/* Removes E from hash table H. */
static void
remove_elem (struct hash *h, struct hash_elem *e) 
{
  h->elem_cnt--;
c002a21e:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a221:	89 04 24             	mov    %eax,(%esp)
c002a224:	e8 0b ee ff ff       	call   c0029034 <list_remove>
  h->elem_cnt++;
c002a229:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a22c:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a230:	89 2c 24             	mov    %ebp,(%esp)
c002a233:	e8 b6 ed ff ff       	call   c0028fee <list_push_front>
  rehash (h);
c002a238:	89 d8                	mov    %ebx,%eax
c002a23a:	e8 21 fd ff ff       	call   c0029f60 <rehash>
}
c002a23f:	89 f8                	mov    %edi,%eax
c002a241:	83 c4 1c             	add    $0x1c,%esp
c002a244:	5b                   	pop    %ebx
c002a245:	5e                   	pop    %esi
c002a246:	5f                   	pop    %edi
c002a247:	5d                   	pop    %ebp
c002a248:	c3                   	ret    

c002a249 <hash_find>:
{
c002a249:	56                   	push   %esi
c002a24a:	53                   	push   %ebx
c002a24b:	83 ec 04             	sub    $0x4,%esp
c002a24e:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a252:	8b 74 24 14          	mov    0x14(%esp),%esi
  return find_elem (h, find_bucket (h, e), e);
c002a256:	89 f2                	mov    %esi,%edx
c002a258:	89 d8                	mov    %ebx,%eax
c002a25a:	e8 71 fc ff ff       	call   c0029ed0 <find_bucket>
c002a25f:	89 f1                	mov    %esi,%ecx
c002a261:	89 c2                	mov    %eax,%edx
c002a263:	89 d8                	mov    %ebx,%eax
c002a265:	e8 8c fc ff ff       	call   c0029ef6 <find_elem>
}
c002a26a:	83 c4 04             	add    $0x4,%esp
c002a26d:	5b                   	pop    %ebx
c002a26e:	5e                   	pop    %esi
c002a26f:	c3                   	ret    

c002a270 <hash_delete>:
{
c002a270:	56                   	push   %esi
c002a271:	53                   	push   %ebx
c002a272:	83 ec 14             	sub    $0x14,%esp
c002a275:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a279:	8b 74 24 24          	mov    0x24(%esp),%esi
  struct hash_elem *found = find_elem (h, find_bucket (h, e), e);
c002a27d:	89 f2                	mov    %esi,%edx
c002a27f:	89 d8                	mov    %ebx,%eax
c002a281:	e8 4a fc ff ff       	call   c0029ed0 <find_bucket>
c002a286:	89 f1                	mov    %esi,%ecx
c002a288:	89 c2                	mov    %eax,%edx
c002a28a:	89 d8                	mov    %ebx,%eax
c002a28c:	e8 65 fc ff ff       	call   c0029ef6 <find_elem>
c002a291:	89 c6                	mov    %eax,%esi
  if (found != NULL) 
c002a293:	85 c0                	test   %eax,%eax
c002a295:	74 12                	je     c002a2a9 <hash_delete+0x39>
  h->elem_cnt--;
c002a297:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a29a:	89 04 24             	mov    %eax,(%esp)
c002a29d:	e8 92 ed ff ff       	call   c0029034 <list_remove>
      rehash (h); 
c002a2a2:	89 d8                	mov    %ebx,%eax
c002a2a4:	e8 b7 fc ff ff       	call   c0029f60 <rehash>
}
c002a2a9:	89 f0                	mov    %esi,%eax
c002a2ab:	83 c4 14             	add    $0x14,%esp
c002a2ae:	5b                   	pop    %ebx
c002a2af:	5e                   	pop    %esi
c002a2b0:	c3                   	ret    

c002a2b1 <hash_apply>:
{
c002a2b1:	55                   	push   %ebp
c002a2b2:	57                   	push   %edi
c002a2b3:	56                   	push   %esi
c002a2b4:	53                   	push   %ebx
c002a2b5:	83 ec 2c             	sub    $0x2c,%esp
c002a2b8:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (action != NULL);
c002a2bc:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c002a2c1:	74 10                	je     c002a2d3 <hash_apply+0x22>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a2c3:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a2ca:	00 
c002a2cb:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c002a2cf:	75 2e                	jne    c002a2ff <hash_apply+0x4e>
c002a2d1:	eb 76                	jmp    c002a349 <hash_apply+0x98>
  ASSERT (action != NULL);
c002a2d3:	c7 44 24 10 96 fe 02 	movl   $0xc002fe96,0x10(%esp)
c002a2da:	c0 
c002a2db:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a2e2:	c0 
c002a2e3:	c7 44 24 08 53 de 02 	movl   $0xc002de53,0x8(%esp)
c002a2ea:	c0 
c002a2eb:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
c002a2f2:	00 
c002a2f3:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a2fa:	e8 c4 e6 ff ff       	call   c00289c3 <debug_panic>
c002a2ff:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
c002a303:	c1 e7 04             	shl    $0x4,%edi
      struct list *bucket = &h->buckets[i];
c002a306:	03 7d 08             	add    0x8(%ebp),%edi
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a309:	89 3c 24             	mov    %edi,(%esp)
c002a30c:	e8 d0 e7 ff ff       	call   c0028ae1 <list_begin>
c002a311:	89 c3                	mov    %eax,%ebx
c002a313:	eb 1a                	jmp    c002a32f <hash_apply+0x7e>
          next = list_next (elem);
c002a315:	89 1c 24             	mov    %ebx,(%esp)
c002a318:	e8 02 e8 ff ff       	call   c0028b1f <list_next>
c002a31d:	89 c6                	mov    %eax,%esi
          action (list_elem_to_hash_elem (elem), h->aux);
c002a31f:	8b 45 14             	mov    0x14(%ebp),%eax
c002a322:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a326:	89 1c 24             	mov    %ebx,(%esp)
c002a329:	ff 54 24 44          	call   *0x44(%esp)
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a32d:	89 f3                	mov    %esi,%ebx
c002a32f:	89 3c 24             	mov    %edi,(%esp)
c002a332:	e8 3c e8 ff ff       	call   c0028b73 <list_end>
c002a337:	39 d8                	cmp    %ebx,%eax
c002a339:	75 da                	jne    c002a315 <hash_apply+0x64>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a33b:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)
c002a340:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a344:	39 45 04             	cmp    %eax,0x4(%ebp)
c002a347:	77 b6                	ja     c002a2ff <hash_apply+0x4e>
}
c002a349:	83 c4 2c             	add    $0x2c,%esp
c002a34c:	5b                   	pop    %ebx
c002a34d:	5e                   	pop    %esi
c002a34e:	5f                   	pop    %edi
c002a34f:	5d                   	pop    %ebp
c002a350:	c3                   	ret    

c002a351 <hash_first>:
{
c002a351:	53                   	push   %ebx
c002a352:	83 ec 28             	sub    $0x28,%esp
c002a355:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a359:	8b 44 24 34          	mov    0x34(%esp),%eax
  ASSERT (i != NULL);
c002a35d:	85 db                	test   %ebx,%ebx
c002a35f:	75 2c                	jne    c002a38d <hash_first+0x3c>
c002a361:	c7 44 24 10 a5 fe 02 	movl   $0xc002fea5,0x10(%esp)
c002a368:	c0 
c002a369:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a370:	c0 
c002a371:	c7 44 24 08 48 de 02 	movl   $0xc002de48,0x8(%esp)
c002a378:	c0 
c002a379:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
c002a380:	00 
c002a381:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a388:	e8 36 e6 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (h != NULL);
c002a38d:	85 c0                	test   %eax,%eax
c002a38f:	75 2c                	jne    c002a3bd <hash_first+0x6c>
c002a391:	c7 44 24 10 74 fe 02 	movl   $0xc002fe74,0x10(%esp)
c002a398:	c0 
c002a399:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a3a0:	c0 
c002a3a1:	c7 44 24 08 48 de 02 	movl   $0xc002de48,0x8(%esp)
c002a3a8:	c0 
c002a3a9:	c7 44 24 04 cb 00 00 	movl   $0xcb,0x4(%esp)
c002a3b0:	00 
c002a3b1:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a3b8:	e8 06 e6 ff ff       	call   c00289c3 <debug_panic>
  i->hash = h;
c002a3bd:	89 03                	mov    %eax,(%ebx)
  i->bucket = i->hash->buckets;
c002a3bf:	8b 40 08             	mov    0x8(%eax),%eax
c002a3c2:	89 43 04             	mov    %eax,0x4(%ebx)
  i->elem = list_elem_to_hash_elem (list_head (i->bucket));
c002a3c5:	89 04 24             	mov    %eax,(%esp)
c002a3c8:	e8 0b ea ff ff       	call   c0028dd8 <list_head>
c002a3cd:	89 43 08             	mov    %eax,0x8(%ebx)
}
c002a3d0:	83 c4 28             	add    $0x28,%esp
c002a3d3:	5b                   	pop    %ebx
c002a3d4:	c3                   	ret    

c002a3d5 <hash_next>:
{
c002a3d5:	56                   	push   %esi
c002a3d6:	53                   	push   %ebx
c002a3d7:	83 ec 24             	sub    $0x24,%esp
c002a3da:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (i != NULL);
c002a3de:	85 db                	test   %ebx,%ebx
c002a3e0:	75 2c                	jne    c002a40e <hash_next+0x39>
c002a3e2:	c7 44 24 10 a5 fe 02 	movl   $0xc002fea5,0x10(%esp)
c002a3e9:	c0 
c002a3ea:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a3f1:	c0 
c002a3f2:	c7 44 24 08 3e de 02 	movl   $0xc002de3e,0x8(%esp)
c002a3f9:	c0 
c002a3fa:	c7 44 24 04 dd 00 00 	movl   $0xdd,0x4(%esp)
c002a401:	00 
c002a402:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a409:	e8 b5 e5 ff ff       	call   c00289c3 <debug_panic>
  i->elem = list_elem_to_hash_elem (list_next (&i->elem->list_elem));
c002a40e:	8b 43 08             	mov    0x8(%ebx),%eax
c002a411:	89 04 24             	mov    %eax,(%esp)
c002a414:	e8 06 e7 ff ff       	call   c0028b1f <list_next>
c002a419:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a41c:	eb 2c                	jmp    c002a44a <hash_next+0x75>
      if (++i->bucket >= i->hash->buckets + i->hash->bucket_cnt)
c002a41e:	8b 43 04             	mov    0x4(%ebx),%eax
c002a421:	83 c0 10             	add    $0x10,%eax
c002a424:	89 43 04             	mov    %eax,0x4(%ebx)
c002a427:	8b 13                	mov    (%ebx),%edx
c002a429:	8b 4a 04             	mov    0x4(%edx),%ecx
c002a42c:	c1 e1 04             	shl    $0x4,%ecx
c002a42f:	03 4a 08             	add    0x8(%edx),%ecx
c002a432:	39 c8                	cmp    %ecx,%eax
c002a434:	72 09                	jb     c002a43f <hash_next+0x6a>
          i->elem = NULL;
c002a436:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
          break;
c002a43d:	eb 1d                	jmp    c002a45c <hash_next+0x87>
      i->elem = list_elem_to_hash_elem (list_begin (i->bucket));
c002a43f:	89 04 24             	mov    %eax,(%esp)
c002a442:	e8 9a e6 ff ff       	call   c0028ae1 <list_begin>
c002a447:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a44a:	8b 73 08             	mov    0x8(%ebx),%esi
c002a44d:	8b 43 04             	mov    0x4(%ebx),%eax
c002a450:	89 04 24             	mov    %eax,(%esp)
c002a453:	e8 1b e7 ff ff       	call   c0028b73 <list_end>
c002a458:	39 c6                	cmp    %eax,%esi
c002a45a:	74 c2                	je     c002a41e <hash_next+0x49>
  return i->elem;
c002a45c:	8b 43 08             	mov    0x8(%ebx),%eax
}
c002a45f:	83 c4 24             	add    $0x24,%esp
c002a462:	5b                   	pop    %ebx
c002a463:	5e                   	pop    %esi
c002a464:	c3                   	ret    

c002a465 <hash_cur>:
  return i->elem;
c002a465:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a469:	8b 40 08             	mov    0x8(%eax),%eax
}
c002a46c:	c3                   	ret    

c002a46d <hash_size>:
  return h->elem_cnt;
c002a46d:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a471:	8b 00                	mov    (%eax),%eax
}
c002a473:	c3                   	ret    

c002a474 <hash_empty>:
  return h->elem_cnt == 0;
c002a474:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a478:	83 38 00             	cmpl   $0x0,(%eax)
c002a47b:	0f 94 c0             	sete   %al
}
c002a47e:	c3                   	ret    

c002a47f <hash_bytes>:
{
c002a47f:	53                   	push   %ebx
c002a480:	83 ec 28             	sub    $0x28,%esp
c002a483:	8b 54 24 30          	mov    0x30(%esp),%edx
c002a487:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (buf != NULL);
c002a48b:	85 d2                	test   %edx,%edx
c002a48d:	74 0e                	je     c002a49d <hash_bytes+0x1e>
c002a48f:	8d 1c 0a             	lea    (%edx,%ecx,1),%ebx
  while (size-- > 0)
c002a492:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a497:	85 c9                	test   %ecx,%ecx
c002a499:	75 2e                	jne    c002a4c9 <hash_bytes+0x4a>
c002a49b:	eb 3f                	jmp    c002a4dc <hash_bytes+0x5d>
  ASSERT (buf != NULL);
c002a49d:	c7 44 24 10 af fe 02 	movl   $0xc002feaf,0x10(%esp)
c002a4a4:	c0 
c002a4a5:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a4ac:	c0 
c002a4ad:	c7 44 24 08 33 de 02 	movl   $0xc002de33,0x8(%esp)
c002a4b4:	c0 
c002a4b5:	c7 44 24 04 10 01 00 	movl   $0x110,0x4(%esp)
c002a4bc:	00 
c002a4bd:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a4c4:	e8 fa e4 ff ff       	call   c00289c3 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *buf++;
c002a4c9:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a4cf:	83 c2 01             	add    $0x1,%edx
c002a4d2:	0f b6 4a ff          	movzbl -0x1(%edx),%ecx
c002a4d6:	31 c8                	xor    %ecx,%eax
  while (size-- > 0)
c002a4d8:	39 da                	cmp    %ebx,%edx
c002a4da:	75 ed                	jne    c002a4c9 <hash_bytes+0x4a>
} 
c002a4dc:	83 c4 28             	add    $0x28,%esp
c002a4df:	5b                   	pop    %ebx
c002a4e0:	c3                   	ret    

c002a4e1 <hash_string>:
{
c002a4e1:	83 ec 2c             	sub    $0x2c,%esp
c002a4e4:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002a4e8:	85 d2                	test   %edx,%edx
c002a4ea:	74 0e                	je     c002a4fa <hash_string+0x19>
  while (*s != '\0')
c002a4ec:	0f b6 0a             	movzbl (%edx),%ecx
c002a4ef:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a4f4:	84 c9                	test   %cl,%cl
c002a4f6:	75 2e                	jne    c002a526 <hash_string+0x45>
c002a4f8:	eb 41                	jmp    c002a53b <hash_string+0x5a>
  ASSERT (s != NULL);
c002a4fa:	c7 44 24 10 5a fa 02 	movl   $0xc002fa5a,0x10(%esp)
c002a501:	c0 
c002a502:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a509:	c0 
c002a50a:	c7 44 24 08 27 de 02 	movl   $0xc002de27,0x8(%esp)
c002a511:	c0 
c002a512:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c002a519:	00 
c002a51a:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a521:	e8 9d e4 ff ff       	call   c00289c3 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *s++;
c002a526:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a52c:	83 c2 01             	add    $0x1,%edx
c002a52f:	0f b6 c9             	movzbl %cl,%ecx
c002a532:	31 c8                	xor    %ecx,%eax
  while (*s != '\0')
c002a534:	0f b6 0a             	movzbl (%edx),%ecx
c002a537:	84 c9                	test   %cl,%cl
c002a539:	75 eb                	jne    c002a526 <hash_string+0x45>
}
c002a53b:	83 c4 2c             	add    $0x2c,%esp
c002a53e:	c3                   	ret    

c002a53f <hash_int>:
{
c002a53f:	83 ec 1c             	sub    $0x1c,%esp
  return hash_bytes (&i, sizeof i);
c002a542:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002a549:	00 
c002a54a:	8d 44 24 20          	lea    0x20(%esp),%eax
c002a54e:	89 04 24             	mov    %eax,(%esp)
c002a551:	e8 29 ff ff ff       	call   c002a47f <hash_bytes>
}
c002a556:	83 c4 1c             	add    $0x1c,%esp
c002a559:	c3                   	ret    

c002a55a <putchar_have_lock>:
/* Writes C to the vga display and serial port.
   The caller has already acquired the console lock if
   appropriate. */
static void
putchar_have_lock (uint8_t c) 
{
c002a55a:	53                   	push   %ebx
c002a55b:	83 ec 28             	sub    $0x28,%esp
c002a55e:	89 c3                	mov    %eax,%ebx
  return (intr_context ()
c002a560:	e8 0c 77 ff ff       	call   c0021c71 <intr_context>
          || lock_held_by_current_thread (&console_lock));
c002a565:	84 c0                	test   %al,%al
c002a567:	75 45                	jne    c002a5ae <putchar_have_lock+0x54>
          || !use_console_lock
c002a569:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a570:	74 3c                	je     c002a5ae <putchar_have_lock+0x54>
          || lock_held_by_current_thread (&console_lock));
c002a572:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a579:	e8 e3 88 ff ff       	call   c0022e61 <lock_held_by_current_thread>
  ASSERT (console_locked_by_current_thread ());
c002a57e:	84 c0                	test   %al,%al
c002a580:	75 2c                	jne    c002a5ae <putchar_have_lock+0x54>
c002a582:	c7 44 24 10 bc fe 02 	movl   $0xc002febc,0x10(%esp)
c002a589:	c0 
c002a58a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a591:	c0 
c002a592:	c7 44 24 08 65 de 02 	movl   $0xc002de65,0x8(%esp)
c002a599:	c0 
c002a59a:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c002a5a1:	00 
c002a5a2:	c7 04 24 01 ff 02 c0 	movl   $0xc002ff01,(%esp)
c002a5a9:	e8 15 e4 ff ff       	call   c00289c3 <debug_panic>
  write_cnt++;
c002a5ae:	83 05 e0 7a 03 c0 01 	addl   $0x1,0xc0037ae0
c002a5b5:	83 15 e4 7a 03 c0 00 	adcl   $0x0,0xc0037ae4
  serial_putc (c);
c002a5bc:	0f b6 db             	movzbl %bl,%ebx
c002a5bf:	89 1c 24             	mov    %ebx,(%esp)
c002a5c2:	e8 95 a5 ff ff       	call   c0024b5c <serial_putc>
  vga_putc (c);
c002a5c7:	89 1c 24             	mov    %ebx,(%esp)
c002a5ca:	e8 aa a1 ff ff       	call   c0024779 <vga_putc>
}
c002a5cf:	83 c4 28             	add    $0x28,%esp
c002a5d2:	5b                   	pop    %ebx
c002a5d3:	c3                   	ret    

c002a5d4 <vprintf_helper>:
{
c002a5d4:	83 ec 0c             	sub    $0xc,%esp
c002a5d7:	8b 44 24 14          	mov    0x14(%esp),%eax
  (*char_cnt)++;
c002a5db:	83 00 01             	addl   $0x1,(%eax)
  putchar_have_lock (c);
c002a5de:	0f b6 44 24 10       	movzbl 0x10(%esp),%eax
c002a5e3:	e8 72 ff ff ff       	call   c002a55a <putchar_have_lock>
}
c002a5e8:	83 c4 0c             	add    $0xc,%esp
c002a5eb:	c3                   	ret    

c002a5ec <acquire_console>:
{
c002a5ec:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a5ef:	e8 7d 76 ff ff       	call   c0021c71 <intr_context>
c002a5f4:	84 c0                	test   %al,%al
c002a5f6:	75 2e                	jne    c002a626 <acquire_console+0x3a>
c002a5f8:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a5ff:	74 25                	je     c002a626 <acquire_console+0x3a>
      if (lock_held_by_current_thread (&console_lock)) 
c002a601:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a608:	e8 54 88 ff ff       	call   c0022e61 <lock_held_by_current_thread>
c002a60d:	84 c0                	test   %al,%al
c002a60f:	74 09                	je     c002a61a <acquire_console+0x2e>
        console_lock_depth++; 
c002a611:	83 05 e8 7a 03 c0 01 	addl   $0x1,0xc0037ae8
c002a618:	eb 0c                	jmp    c002a626 <acquire_console+0x3a>
        lock_acquire (&console_lock); 
c002a61a:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a621:	e8 84 88 ff ff       	call   c0022eaa <lock_acquire>
}
c002a626:	83 c4 1c             	add    $0x1c,%esp
c002a629:	c3                   	ret    

c002a62a <release_console>:
{
c002a62a:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a62d:	e8 3f 76 ff ff       	call   c0021c71 <intr_context>
c002a632:	84 c0                	test   %al,%al
c002a634:	75 28                	jne    c002a65e <release_console+0x34>
c002a636:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a63d:	74 1f                	je     c002a65e <release_console+0x34>
      if (console_lock_depth > 0)
c002a63f:	a1 e8 7a 03 c0       	mov    0xc0037ae8,%eax
c002a644:	85 c0                	test   %eax,%eax
c002a646:	7e 0a                	jle    c002a652 <release_console+0x28>
        console_lock_depth--;
c002a648:	83 e8 01             	sub    $0x1,%eax
c002a64b:	a3 e8 7a 03 c0       	mov    %eax,0xc0037ae8
c002a650:	eb 0c                	jmp    c002a65e <release_console+0x34>
        lock_release (&console_lock); 
c002a652:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a659:	e8 16 8a ff ff       	call   c0023074 <lock_release>
}
c002a65e:	83 c4 1c             	add    $0x1c,%esp
c002a661:	c3                   	ret    

c002a662 <console_init>:
{
c002a662:	83 ec 1c             	sub    $0x1c,%esp
  lock_init (&console_lock);
c002a665:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a66c:	e8 9c 87 ff ff       	call   c0022e0d <lock_init>
  use_console_lock = true;
c002a671:	c6 05 ec 7a 03 c0 01 	movb   $0x1,0xc0037aec
}
c002a678:	83 c4 1c             	add    $0x1c,%esp
c002a67b:	c3                   	ret    

c002a67c <console_panic>:
  use_console_lock = false;
c002a67c:	c6 05 ec 7a 03 c0 00 	movb   $0x0,0xc0037aec
c002a683:	c3                   	ret    

c002a684 <console_print_stats>:
{
c002a684:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Console: %lld characters output\n", write_cnt);
c002a687:	a1 e0 7a 03 c0       	mov    0xc0037ae0,%eax
c002a68c:	8b 15 e4 7a 03 c0    	mov    0xc0037ae4,%edx
c002a692:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a696:	89 54 24 08          	mov    %edx,0x8(%esp)
c002a69a:	c7 04 24 e0 fe 02 c0 	movl   $0xc002fee0,(%esp)
c002a6a1:	e8 c8 c4 ff ff       	call   c0026b6e <printf>
}
c002a6a6:	83 c4 1c             	add    $0x1c,%esp
c002a6a9:	c3                   	ret    

c002a6aa <vprintf>:
{
c002a6aa:	83 ec 2c             	sub    $0x2c,%esp
  int char_cnt = 0;
c002a6ad:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a6b4:	00 
  acquire_console ();
c002a6b5:	e8 32 ff ff ff       	call   c002a5ec <acquire_console>
  __vprintf (format, args, vprintf_helper, &char_cnt);
c002a6ba:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c002a6be:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002a6c2:	c7 44 24 08 d4 a5 02 	movl   $0xc002a5d4,0x8(%esp)
c002a6c9:	c0 
c002a6ca:	8b 44 24 34          	mov    0x34(%esp),%eax
c002a6ce:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a6d2:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a6d6:	89 04 24             	mov    %eax,(%esp)
c002a6d9:	e8 d6 c4 ff ff       	call   c0026bb4 <__vprintf>
  release_console ();
c002a6de:	e8 47 ff ff ff       	call   c002a62a <release_console>
}
c002a6e3:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a6e7:	83 c4 2c             	add    $0x2c,%esp
c002a6ea:	c3                   	ret    

c002a6eb <puts>:
{
c002a6eb:	53                   	push   %ebx
c002a6ec:	83 ec 08             	sub    $0x8,%esp
c002a6ef:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a6f3:	e8 f4 fe ff ff       	call   c002a5ec <acquire_console>
  while (*s != '\0')
c002a6f8:	0f b6 03             	movzbl (%ebx),%eax
c002a6fb:	84 c0                	test   %al,%al
c002a6fd:	74 12                	je     c002a711 <puts+0x26>
    putchar_have_lock (*s++);
c002a6ff:	83 c3 01             	add    $0x1,%ebx
c002a702:	0f b6 c0             	movzbl %al,%eax
c002a705:	e8 50 fe ff ff       	call   c002a55a <putchar_have_lock>
  while (*s != '\0')
c002a70a:	0f b6 03             	movzbl (%ebx),%eax
c002a70d:	84 c0                	test   %al,%al
c002a70f:	75 ee                	jne    c002a6ff <puts+0x14>
  putchar_have_lock ('\n');
c002a711:	b8 0a 00 00 00       	mov    $0xa,%eax
c002a716:	e8 3f fe ff ff       	call   c002a55a <putchar_have_lock>
  release_console ();
c002a71b:	e8 0a ff ff ff       	call   c002a62a <release_console>
}
c002a720:	b8 00 00 00 00       	mov    $0x0,%eax
c002a725:	83 c4 08             	add    $0x8,%esp
c002a728:	5b                   	pop    %ebx
c002a729:	c3                   	ret    

c002a72a <putbuf>:
{
c002a72a:	56                   	push   %esi
c002a72b:	53                   	push   %ebx
c002a72c:	83 ec 04             	sub    $0x4,%esp
c002a72f:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a733:	8b 74 24 14          	mov    0x14(%esp),%esi
  acquire_console ();
c002a737:	e8 b0 fe ff ff       	call   c002a5ec <acquire_console>
  while (n-- > 0)
c002a73c:	85 f6                	test   %esi,%esi
c002a73e:	74 11                	je     c002a751 <putbuf+0x27>
    putchar_have_lock (*buffer++);
c002a740:	83 c3 01             	add    $0x1,%ebx
c002a743:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
c002a747:	e8 0e fe ff ff       	call   c002a55a <putchar_have_lock>
  while (n-- > 0)
c002a74c:	83 ee 01             	sub    $0x1,%esi
c002a74f:	75 ef                	jne    c002a740 <putbuf+0x16>
  release_console ();
c002a751:	e8 d4 fe ff ff       	call   c002a62a <release_console>
}
c002a756:	83 c4 04             	add    $0x4,%esp
c002a759:	5b                   	pop    %ebx
c002a75a:	5e                   	pop    %esi
c002a75b:	c3                   	ret    

c002a75c <putchar>:
{
c002a75c:	53                   	push   %ebx
c002a75d:	83 ec 08             	sub    $0x8,%esp
c002a760:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a764:	e8 83 fe ff ff       	call   c002a5ec <acquire_console>
  putchar_have_lock (c);
c002a769:	0f b6 c3             	movzbl %bl,%eax
c002a76c:	e8 e9 fd ff ff       	call   c002a55a <putchar_have_lock>
  release_console ();
c002a771:	e8 b4 fe ff ff       	call   c002a62a <release_console>
}
c002a776:	89 d8                	mov    %ebx,%eax
c002a778:	83 c4 08             	add    $0x8,%esp
c002a77b:	5b                   	pop    %ebx
c002a77c:	c3                   	ret    

c002a77d <msg>:
/* Prints FORMAT as if with printf(),
   prefixing the output by the name of the test
   and following it with a new-line character. */
void
msg (const char *format, ...) 
{
c002a77d:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) ", test_name);
c002a780:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a785:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a789:	c7 04 24 1c ff 02 c0 	movl   $0xc002ff1c,(%esp)
c002a790:	e8 d9 c3 ff ff       	call   c0026b6e <printf>
  va_start (args, format);
c002a795:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a799:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a79d:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a7a1:	89 04 24             	mov    %eax,(%esp)
c002a7a4:	e8 01 ff ff ff       	call   c002a6aa <vprintf>
  va_end (args);
  putchar ('\n');
c002a7a9:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a7b0:	e8 a7 ff ff ff       	call   c002a75c <putchar>
}
c002a7b5:	83 c4 1c             	add    $0x1c,%esp
c002a7b8:	c3                   	ret    

c002a7b9 <run_test>:
{
c002a7b9:	56                   	push   %esi
c002a7ba:	53                   	push   %ebx
c002a7bb:	83 ec 24             	sub    $0x24,%esp
c002a7be:	8b 74 24 30          	mov    0x30(%esp),%esi
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a7c2:	bb a0 de 02 c0       	mov    $0xc002dea0,%ebx
    if (!strcmp (name, t->name))
c002a7c7:	8b 03                	mov    (%ebx),%eax
c002a7c9:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a7cd:	89 34 24             	mov    %esi,(%esp)
c002a7d0:	e8 02 d3 ff ff       	call   c0027ad7 <strcmp>
c002a7d5:	85 c0                	test   %eax,%eax
c002a7d7:	75 23                	jne    c002a7fc <run_test+0x43>
        test_name = name;
c002a7d9:	89 35 24 7b 03 c0    	mov    %esi,0xc0037b24
        msg ("begin");
c002a7df:	c7 04 24 22 ff 02 c0 	movl   $0xc002ff22,(%esp)
c002a7e6:	e8 92 ff ff ff       	call   c002a77d <msg>
        t->function ();
c002a7eb:	ff 53 04             	call   *0x4(%ebx)
        msg ("end");
c002a7ee:	c7 04 24 28 ff 02 c0 	movl   $0xc002ff28,(%esp)
c002a7f5:	e8 83 ff ff ff       	call   c002a77d <msg>
c002a7fa:	eb 33                	jmp    c002a82f <run_test+0x76>
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a7fc:	83 c3 08             	add    $0x8,%ebx
c002a7ff:	81 fb 78 df 02 c0    	cmp    $0xc002df78,%ebx
c002a805:	72 c0                	jb     c002a7c7 <run_test+0xe>
  PANIC ("no test named \"%s\"", name);
c002a807:	89 74 24 10          	mov    %esi,0x10(%esp)
c002a80b:	c7 44 24 0c 2c ff 02 	movl   $0xc002ff2c,0xc(%esp)
c002a812:	c0 
c002a813:	c7 44 24 08 85 de 02 	movl   $0xc002de85,0x8(%esp)
c002a81a:	c0 
c002a81b:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a822:	00 
c002a823:	c7 04 24 3f ff 02 c0 	movl   $0xc002ff3f,(%esp)
c002a82a:	e8 94 e1 ff ff       	call   c00289c3 <debug_panic>
}
c002a82f:	83 c4 24             	add    $0x24,%esp
c002a832:	5b                   	pop    %ebx
c002a833:	5e                   	pop    %esi
c002a834:	c3                   	ret    

c002a835 <fail>:
   prefixing the output by the name of the test and FAIL:
   and following it with a new-line character,
   and then panics the kernel. */
void
fail (const char *format, ...) 
{
c002a835:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) FAIL: ", test_name);
c002a838:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a83d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a841:	c7 04 24 5b ff 02 c0 	movl   $0xc002ff5b,(%esp)
c002a848:	e8 21 c3 ff ff       	call   c0026b6e <printf>
  va_start (args, format);
c002a84d:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a851:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a855:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a859:	89 04 24             	mov    %eax,(%esp)
c002a85c:	e8 49 fe ff ff       	call   c002a6aa <vprintf>
  va_end (args);
  putchar ('\n');
c002a861:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a868:	e8 ef fe ff ff       	call   c002a75c <putchar>

  PANIC ("test failed");
c002a86d:	c7 44 24 0c 67 ff 02 	movl   $0xc002ff67,0xc(%esp)
c002a874:	c0 
c002a875:	c7 44 24 08 80 de 02 	movl   $0xc002de80,0x8(%esp)
c002a87c:	c0 
c002a87d:	c7 44 24 04 5d 00 00 	movl   $0x5d,0x4(%esp)
c002a884:	00 
c002a885:	c7 04 24 3f ff 02 c0 	movl   $0xc002ff3f,(%esp)
c002a88c:	e8 32 e1 ff ff       	call   c00289c3 <debug_panic>

c002a891 <pass>:
}

/* Prints a message indicating the current test passed. */
void
pass (void) 
{
c002a891:	83 ec 1c             	sub    $0x1c,%esp
  printf ("(%s) PASS\n", test_name);
c002a894:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a899:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a89d:	c7 04 24 73 ff 02 c0 	movl   $0xc002ff73,(%esp)
c002a8a4:	e8 c5 c2 ff ff       	call   c0026b6e <printf>
}
c002a8a9:	83 c4 1c             	add    $0x1c,%esp
c002a8ac:	c3                   	ret    
c002a8ad:	90                   	nop
c002a8ae:	90                   	nop
c002a8af:	90                   	nop

c002a8b0 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *t_) 
{
c002a8b0:	55                   	push   %ebp
c002a8b1:	57                   	push   %edi
c002a8b2:	56                   	push   %esi
c002a8b3:	53                   	push   %ebx
c002a8b4:	83 ec 1c             	sub    $0x1c,%esp
  struct sleep_thread *t = t_;
  struct sleep_test *test = t->test;
c002a8b7:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a8bb:	8b 18                	mov    (%eax),%ebx
  int i;

  for (i = 1; i <= test->iterations; i++) 
c002a8bd:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002a8c1:	7e 63                	jle    c002a926 <sleeper+0x76>
c002a8c3:	bd 01 00 00 00       	mov    $0x1,%ebp
    {
      int64_t sleep_until = test->start + i * t->duration;
      timer_sleep (sleep_until - timer_ticks ());
      lock_acquire (&test->output_lock);
c002a8c8:	8d 43 0c             	lea    0xc(%ebx),%eax
c002a8cb:	89 44 24 0c          	mov    %eax,0xc(%esp)
      int64_t sleep_until = test->start + i * t->duration;
c002a8cf:	89 e8                	mov    %ebp,%eax
c002a8d1:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a8d5:	0f af 41 08          	imul   0x8(%ecx),%eax
c002a8d9:	99                   	cltd   
c002a8da:	03 03                	add    (%ebx),%eax
c002a8dc:	13 53 04             	adc    0x4(%ebx),%edx
c002a8df:	89 c6                	mov    %eax,%esi
c002a8e1:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002a8e3:	e8 6c 99 ff ff       	call   c0024254 <timer_ticks>
c002a8e8:	29 c6                	sub    %eax,%esi
c002a8ea:	19 d7                	sbb    %edx,%edi
c002a8ec:	89 34 24             	mov    %esi,(%esp)
c002a8ef:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a8f3:	e8 a4 99 ff ff       	call   c002429c <timer_sleep>
      lock_acquire (&test->output_lock);
c002a8f8:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c002a8fc:	89 3c 24             	mov    %edi,(%esp)
c002a8ff:	e8 a6 85 ff ff       	call   c0022eaa <lock_acquire>
      *test->output_pos++ = t->id;
c002a904:	8b 43 30             	mov    0x30(%ebx),%eax
c002a907:	8d 50 04             	lea    0x4(%eax),%edx
c002a90a:	89 53 30             	mov    %edx,0x30(%ebx)
c002a90d:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a911:	8b 51 04             	mov    0x4(%ecx),%edx
c002a914:	89 10                	mov    %edx,(%eax)
      lock_release (&test->output_lock);
c002a916:	89 3c 24             	mov    %edi,(%esp)
c002a919:	e8 56 87 ff ff       	call   c0023074 <lock_release>
  for (i = 1; i <= test->iterations; i++) 
c002a91e:	83 c5 01             	add    $0x1,%ebp
c002a921:	39 6b 08             	cmp    %ebp,0x8(%ebx)
c002a924:	7d a9                	jge    c002a8cf <sleeper+0x1f>
    }
}
c002a926:	83 c4 1c             	add    $0x1c,%esp
c002a929:	5b                   	pop    %ebx
c002a92a:	5e                   	pop    %esi
c002a92b:	5f                   	pop    %edi
c002a92c:	5d                   	pop    %ebp
c002a92d:	c3                   	ret    

c002a92e <test_sleep>:
{
c002a92e:	55                   	push   %ebp
c002a92f:	57                   	push   %edi
c002a930:	56                   	push   %esi
c002a931:	53                   	push   %ebx
c002a932:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c002a938:	89 44 24 20          	mov    %eax,0x20(%esp)
c002a93c:	89 54 24 2c          	mov    %edx,0x2c(%esp)
  ASSERT (!thread_mlfqs);
c002a940:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002a947:	74 2c                	je     c002a975 <test_sleep+0x47>
c002a949:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002a950:	c0 
c002a951:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a958:	c0 
c002a959:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002a960:	c0 
c002a961:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a968:	00 
c002a969:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002a970:	e8 4e e0 ff ff       	call   c00289c3 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002a975:	8b 74 24 2c          	mov    0x2c(%esp),%esi
c002a979:	89 74 24 08          	mov    %esi,0x8(%esp)
c002a97d:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002a981:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a985:	c7 04 24 a4 01 03 c0 	movl   $0xc00301a4,(%esp)
c002a98c:	e8 ec fd ff ff       	call   c002a77d <msg>
  msg ("Thread 0 sleeps 10 ticks each time,");
c002a991:	c7 04 24 d0 01 03 c0 	movl   $0xc00301d0,(%esp)
c002a998:	e8 e0 fd ff ff       	call   c002a77d <msg>
  msg ("thread 1 sleeps 20 ticks each time, and so on.");
c002a99d:	c7 04 24 f4 01 03 c0 	movl   $0xc00301f4,(%esp)
c002a9a4:	e8 d4 fd ff ff       	call   c002a77d <msg>
  msg ("If successful, product of iteration count and");
c002a9a9:	c7 04 24 24 02 03 c0 	movl   $0xc0030224,(%esp)
c002a9b0:	e8 c8 fd ff ff       	call   c002a77d <msg>
  msg ("sleep duration will appear in nondescending order.");
c002a9b5:	c7 04 24 54 02 03 c0 	movl   $0xc0030254,(%esp)
c002a9bc:	e8 bc fd ff ff       	call   c002a77d <msg>
  threads = malloc (sizeof *threads * thread_cnt);
c002a9c1:	89 f8                	mov    %edi,%eax
c002a9c3:	c1 e0 04             	shl    $0x4,%eax
c002a9c6:	89 04 24             	mov    %eax,(%esp)
c002a9c9:	e8 a6 90 ff ff       	call   c0023a74 <malloc>
c002a9ce:	89 c3                	mov    %eax,%ebx
c002a9d0:	89 44 24 24          	mov    %eax,0x24(%esp)
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002a9d4:	8d 04 f5 00 00 00 00 	lea    0x0(,%esi,8),%eax
c002a9db:	0f af c7             	imul   %edi,%eax
c002a9de:	89 04 24             	mov    %eax,(%esp)
c002a9e1:	e8 8e 90 ff ff       	call   c0023a74 <malloc>
c002a9e6:	89 44 24 28          	mov    %eax,0x28(%esp)
  if (threads == NULL || output == NULL)
c002a9ea:	85 c0                	test   %eax,%eax
c002a9ec:	74 04                	je     c002a9f2 <test_sleep+0xc4>
c002a9ee:	85 db                	test   %ebx,%ebx
c002a9f0:	75 24                	jne    c002aa16 <test_sleep+0xe8>
    PANIC ("couldn't allocate memory for test");
c002a9f2:	c7 44 24 0c 88 02 03 	movl   $0xc0030288,0xc(%esp)
c002a9f9:	c0 
c002a9fa:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002aa01:	c0 
c002aa02:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c002aa09:	00 
c002aa0a:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002aa11:	e8 ad df ff ff       	call   c00289c3 <debug_panic>
  test.start = timer_ticks () + 100;
c002aa16:	e8 39 98 ff ff       	call   c0024254 <timer_ticks>
c002aa1b:	83 c0 64             	add    $0x64,%eax
c002aa1e:	83 d2 00             	adc    $0x0,%edx
c002aa21:	89 44 24 4c          	mov    %eax,0x4c(%esp)
c002aa25:	89 54 24 50          	mov    %edx,0x50(%esp)
  test.iterations = iterations;
c002aa29:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002aa2d:	89 44 24 54          	mov    %eax,0x54(%esp)
  lock_init (&test.output_lock);
c002aa31:	8d 44 24 58          	lea    0x58(%esp),%eax
c002aa35:	89 04 24             	mov    %eax,(%esp)
c002aa38:	e8 d0 83 ff ff       	call   c0022e0d <lock_init>
  test.output_pos = output;
c002aa3d:	8b 44 24 28          	mov    0x28(%esp),%eax
c002aa41:	89 44 24 7c          	mov    %eax,0x7c(%esp)
  ASSERT (output != NULL);
c002aa45:	85 c0                	test   %eax,%eax
c002aa47:	74 1e                	je     c002aa67 <test_sleep+0x139>
c002aa49:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  for (i = 0; i < thread_cnt; i++)
c002aa4d:	be 0a 00 00 00       	mov    $0xa,%esi
c002aa52:	b8 00 00 00 00       	mov    $0x0,%eax
      snprintf (name, sizeof name, "thread %d", i);
c002aa57:	8d 6c 24 3c          	lea    0x3c(%esp),%ebp
  for (i = 0; i < thread_cnt; i++)
c002aa5b:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c002aa60:	7f 31                	jg     c002aa93 <test_sleep+0x165>
c002aa62:	e9 8a 00 00 00       	jmp    c002aaf1 <test_sleep+0x1c3>
  ASSERT (output != NULL);
c002aa67:	c7 44 24 10 4a 01 03 	movl   $0xc003014a,0x10(%esp)
c002aa6e:	c0 
c002aa6f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002aa76:	c0 
c002aa77:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002aa7e:	c0 
c002aa7f:	c7 44 24 04 51 00 00 	movl   $0x51,0x4(%esp)
c002aa86:	00 
c002aa87:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002aa8e:	e8 30 df ff ff       	call   c00289c3 <debug_panic>
      t->test = &test;
c002aa93:	8d 4c 24 4c          	lea    0x4c(%esp),%ecx
c002aa97:	89 0b                	mov    %ecx,(%ebx)
      t->id = i;
c002aa99:	89 43 04             	mov    %eax,0x4(%ebx)
      t->duration = (i + 1) * 10;
c002aa9c:	8d 78 01             	lea    0x1(%eax),%edi
c002aa9f:	89 73 08             	mov    %esi,0x8(%ebx)
      t->iterations = 0;
c002aaa2:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
      snprintf (name, sizeof name, "thread %d", i);
c002aaa9:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002aaad:	c7 44 24 08 59 01 03 	movl   $0xc0030159,0x8(%esp)
c002aab4:	c0 
c002aab5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002aabc:	00 
c002aabd:	89 2c 24             	mov    %ebp,(%esp)
c002aac0:	e8 aa c7 ff ff       	call   c002726f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, t);
c002aac5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002aac9:	c7 44 24 08 b0 a8 02 	movl   $0xc002a8b0,0x8(%esp)
c002aad0:	c0 
c002aad1:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002aad8:	00 
c002aad9:	89 2c 24             	mov    %ebp,(%esp)
c002aadc:	e8 a0 6a ff ff       	call   c0021581 <thread_create>
c002aae1:	83 c3 10             	add    $0x10,%ebx
c002aae4:	83 c6 0a             	add    $0xa,%esi
  for (i = 0; i < thread_cnt; i++)
c002aae7:	3b 7c 24 20          	cmp    0x20(%esp),%edi
c002aaeb:	74 04                	je     c002aaf1 <test_sleep+0x1c3>
c002aaed:	89 f8                	mov    %edi,%eax
c002aaef:	eb a2                	jmp    c002aa93 <test_sleep+0x165>
  timer_sleep (100 + thread_cnt * iterations * 10 + 100);
c002aaf1:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002aaf5:	89 f8                	mov    %edi,%eax
c002aaf7:	0f af 44 24 2c       	imul   0x2c(%esp),%eax
c002aafc:	8d 04 80             	lea    (%eax,%eax,4),%eax
c002aaff:	8d 84 00 c8 00 00 00 	lea    0xc8(%eax,%eax,1),%eax
c002ab06:	89 04 24             	mov    %eax,(%esp)
c002ab09:	89 c1                	mov    %eax,%ecx
c002ab0b:	c1 f9 1f             	sar    $0x1f,%ecx
c002ab0e:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002ab12:	e8 85 97 ff ff       	call   c002429c <timer_sleep>
  lock_acquire (&test.output_lock);
c002ab17:	8d 44 24 58          	lea    0x58(%esp),%eax
c002ab1b:	89 04 24             	mov    %eax,(%esp)
c002ab1e:	e8 87 83 ff ff       	call   c0022eaa <lock_acquire>
  for (op = output; op < test.output_pos; op++) 
c002ab23:	8b 44 24 28          	mov    0x28(%esp),%eax
c002ab27:	3b 44 24 7c          	cmp    0x7c(%esp),%eax
c002ab2b:	0f 83 bb 00 00 00    	jae    c002abec <test_sleep+0x2be>
      ASSERT (*op >= 0 && *op < thread_cnt);
c002ab31:	8b 18                	mov    (%eax),%ebx
c002ab33:	85 db                	test   %ebx,%ebx
c002ab35:	78 1b                	js     c002ab52 <test_sleep+0x224>
c002ab37:	39 df                	cmp    %ebx,%edi
c002ab39:	7f 43                	jg     c002ab7e <test_sleep+0x250>
c002ab3b:	90                   	nop
c002ab3c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c002ab40:	eb 10                	jmp    c002ab52 <test_sleep+0x224>
c002ab42:	8b 1f                	mov    (%edi),%ebx
c002ab44:	85 db                	test   %ebx,%ebx
c002ab46:	78 0a                	js     c002ab52 <test_sleep+0x224>
c002ab48:	39 5c 24 20          	cmp    %ebx,0x20(%esp)
c002ab4c:	7e 04                	jle    c002ab52 <test_sleep+0x224>
c002ab4e:	89 f5                	mov    %esi,%ebp
c002ab50:	eb 35                	jmp    c002ab87 <test_sleep+0x259>
c002ab52:	c7 44 24 10 63 01 03 	movl   $0xc0030163,0x10(%esp)
c002ab59:	c0 
c002ab5a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ab61:	c0 
c002ab62:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002ab69:	c0 
c002ab6a:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
c002ab71:	00 
c002ab72:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002ab79:	e8 45 de ff ff       	call   c00289c3 <debug_panic>
  for (op = output; op < test.output_pos; op++) 
c002ab7e:	8b 7c 24 28          	mov    0x28(%esp),%edi
  product = 0;
c002ab82:	bd 00 00 00 00       	mov    $0x0,%ebp
      t = threads + *op;
c002ab87:	c1 e3 04             	shl    $0x4,%ebx
c002ab8a:	03 5c 24 24          	add    0x24(%esp),%ebx
      new_prod = ++t->iterations * t->duration;
c002ab8e:	8b 43 0c             	mov    0xc(%ebx),%eax
c002ab91:	83 c0 01             	add    $0x1,%eax
c002ab94:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ab97:	8b 53 08             	mov    0x8(%ebx),%edx
c002ab9a:	89 c6                	mov    %eax,%esi
c002ab9c:	0f af f2             	imul   %edx,%esi
      msg ("thread %d: duration=%d, iteration=%d, product=%d",
c002ab9f:	89 74 24 10          	mov    %esi,0x10(%esp)
c002aba3:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002aba7:	89 54 24 08          	mov    %edx,0x8(%esp)
c002abab:	8b 43 04             	mov    0x4(%ebx),%eax
c002abae:	89 44 24 04          	mov    %eax,0x4(%esp)
c002abb2:	c7 04 24 ac 02 03 c0 	movl   $0xc00302ac,(%esp)
c002abb9:	e8 bf fb ff ff       	call   c002a77d <msg>
      if (new_prod >= product)
c002abbe:	39 ee                	cmp    %ebp,%esi
c002abc0:	7d 1d                	jge    c002abdf <test_sleep+0x2b1>
        fail ("thread %d woke up out of order (%d > %d)!",
c002abc2:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002abc6:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002abca:	8b 43 04             	mov    0x4(%ebx),%eax
c002abcd:	89 44 24 04          	mov    %eax,0x4(%esp)
c002abd1:	c7 04 24 e0 02 03 c0 	movl   $0xc00302e0,(%esp)
c002abd8:	e8 58 fc ff ff       	call   c002a835 <fail>
c002abdd:	89 ee                	mov    %ebp,%esi
  for (op = output; op < test.output_pos; op++) 
c002abdf:	83 c7 04             	add    $0x4,%edi
c002abe2:	39 7c 24 7c          	cmp    %edi,0x7c(%esp)
c002abe6:	0f 87 56 ff ff ff    	ja     c002ab42 <test_sleep+0x214>
  for (i = 0; i < thread_cnt; i++)
c002abec:	8b 6c 24 20          	mov    0x20(%esp),%ebp
c002abf0:	85 ed                	test   %ebp,%ebp
c002abf2:	7e 36                	jle    c002ac2a <test_sleep+0x2fc>
c002abf4:	8b 74 24 24          	mov    0x24(%esp),%esi
c002abf8:	bb 00 00 00 00       	mov    $0x0,%ebx
c002abfd:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
    if (threads[i].iterations != iterations)
c002ac01:	8b 46 0c             	mov    0xc(%esi),%eax
c002ac04:	39 f8                	cmp    %edi,%eax
c002ac06:	74 18                	je     c002ac20 <test_sleep+0x2f2>
      fail ("thread %d woke up %d times instead of %d",
c002ac08:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002ac0c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002ac10:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002ac14:	c7 04 24 0c 03 03 c0 	movl   $0xc003030c,(%esp)
c002ac1b:	e8 15 fc ff ff       	call   c002a835 <fail>
  for (i = 0; i < thread_cnt; i++)
c002ac20:	83 c3 01             	add    $0x1,%ebx
c002ac23:	83 c6 10             	add    $0x10,%esi
c002ac26:	39 eb                	cmp    %ebp,%ebx
c002ac28:	75 d7                	jne    c002ac01 <test_sleep+0x2d3>
  lock_release (&test.output_lock);
c002ac2a:	8d 44 24 58          	lea    0x58(%esp),%eax
c002ac2e:	89 04 24             	mov    %eax,(%esp)
c002ac31:	e8 3e 84 ff ff       	call   c0023074 <lock_release>
  free (output);
c002ac36:	8b 44 24 28          	mov    0x28(%esp),%eax
c002ac3a:	89 04 24             	mov    %eax,(%esp)
c002ac3d:	e8 b9 8f ff ff       	call   c0023bfb <free>
  free (threads);
c002ac42:	8b 44 24 24          	mov    0x24(%esp),%eax
c002ac46:	89 04 24             	mov    %eax,(%esp)
c002ac49:	e8 ad 8f ff ff       	call   c0023bfb <free>
}
c002ac4e:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c002ac54:	5b                   	pop    %ebx
c002ac55:	5e                   	pop    %esi
c002ac56:	5f                   	pop    %edi
c002ac57:	5d                   	pop    %ebp
c002ac58:	c3                   	ret    

c002ac59 <test_alarm_single>:
{
c002ac59:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 1);
c002ac5c:	ba 01 00 00 00       	mov    $0x1,%edx
c002ac61:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac66:	e8 c3 fc ff ff       	call   c002a92e <test_sleep>
}
c002ac6b:	83 c4 0c             	add    $0xc,%esp
c002ac6e:	c3                   	ret    

c002ac6f <test_alarm_multiple>:
{
c002ac6f:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 7);
c002ac72:	ba 07 00 00 00       	mov    $0x7,%edx
c002ac77:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac7c:	e8 ad fc ff ff       	call   c002a92e <test_sleep>
}
c002ac81:	83 c4 0c             	add    $0xc,%esp
c002ac84:	c3                   	ret    

c002ac85 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *test_) 
{
c002ac85:	55                   	push   %ebp
c002ac86:	57                   	push   %edi
c002ac87:	56                   	push   %esi
c002ac88:	53                   	push   %ebx
c002ac89:	83 ec 1c             	sub    $0x1c,%esp
c002ac8c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  struct sleep_test *test = test_;
  int i;

  /* Make sure we're at the beginning of a timer tick. */
  timer_sleep (1);
c002ac90:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c002ac97:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ac9e:	00 
c002ac9f:	e8 f8 95 ff ff       	call   c002429c <timer_sleep>

  for (i = 1; i <= test->iterations; i++) 
c002aca4:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002aca8:	7e 56                	jle    c002ad00 <sleeper+0x7b>
c002acaa:	bd 0a 00 00 00       	mov    $0xa,%ebp
c002acaf:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c002acb6:	00 
    {
      int64_t sleep_until = test->start + i * 10;
c002acb7:	89 ee                	mov    %ebp,%esi
c002acb9:	89 ef                	mov    %ebp,%edi
c002acbb:	c1 ff 1f             	sar    $0x1f,%edi
c002acbe:	03 33                	add    (%ebx),%esi
c002acc0:	13 7b 04             	adc    0x4(%ebx),%edi
      timer_sleep (sleep_until - timer_ticks ());
c002acc3:	e8 8c 95 ff ff       	call   c0024254 <timer_ticks>
c002acc8:	29 c6                	sub    %eax,%esi
c002acca:	19 d7                	sbb    %edx,%edi
c002accc:	89 34 24             	mov    %esi,(%esp)
c002accf:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002acd3:	e8 c4 95 ff ff       	call   c002429c <timer_sleep>
      *test->output_pos++ = timer_ticks () - test->start;
c002acd8:	8b 73 0c             	mov    0xc(%ebx),%esi
c002acdb:	8d 46 04             	lea    0x4(%esi),%eax
c002acde:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ace1:	e8 6e 95 ff ff       	call   c0024254 <timer_ticks>
c002ace6:	2b 03                	sub    (%ebx),%eax
c002ace8:	89 06                	mov    %eax,(%esi)
      thread_yield ();
c002acea:	e8 f0 67 ff ff       	call   c00214df <thread_yield>
  for (i = 1; i <= test->iterations; i++) 
c002acef:	83 44 24 0c 01       	addl   $0x1,0xc(%esp)
c002acf4:	83 c5 0a             	add    $0xa,%ebp
c002acf7:	8b 44 24 0c          	mov    0xc(%esp),%eax
c002acfb:	39 43 08             	cmp    %eax,0x8(%ebx)
c002acfe:	7d b7                	jge    c002acb7 <sleeper+0x32>
    }
}
c002ad00:	83 c4 1c             	add    $0x1c,%esp
c002ad03:	5b                   	pop    %ebx
c002ad04:	5e                   	pop    %esi
c002ad05:	5f                   	pop    %edi
c002ad06:	5d                   	pop    %ebp
c002ad07:	c3                   	ret    

c002ad08 <test_alarm_simultaneous>:
{
c002ad08:	55                   	push   %ebp
c002ad09:	57                   	push   %edi
c002ad0a:	56                   	push   %esi
c002ad0b:	53                   	push   %ebx
c002ad0c:	83 ec 4c             	sub    $0x4c,%esp
  ASSERT (!thread_mlfqs);
c002ad0f:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002ad16:	74 2c                	je     c002ad44 <test_alarm_simultaneous+0x3c>
c002ad18:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002ad1f:	c0 
c002ad20:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ad27:	c0 
c002ad28:	c7 44 24 08 83 df 02 	movl   $0xc002df83,0x8(%esp)
c002ad2f:	c0 
c002ad30:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002ad37:	00 
c002ad38:	c7 04 24 38 03 03 c0 	movl   $0xc0030338,(%esp)
c002ad3f:	e8 7f dc ff ff       	call   c00289c3 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002ad44:	c7 44 24 08 05 00 00 	movl   $0x5,0x8(%esp)
c002ad4b:	00 
c002ad4c:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c002ad53:	00 
c002ad54:	c7 04 24 a4 01 03 c0 	movl   $0xc00301a4,(%esp)
c002ad5b:	e8 1d fa ff ff       	call   c002a77d <msg>
  msg ("Each thread sleeps 10 ticks each time.");
c002ad60:	c7 04 24 64 03 03 c0 	movl   $0xc0030364,(%esp)
c002ad67:	e8 11 fa ff ff       	call   c002a77d <msg>
  msg ("Within an iteration, all threads should wake up on the same tick.");
c002ad6c:	c7 04 24 8c 03 03 c0 	movl   $0xc003038c,(%esp)
c002ad73:	e8 05 fa ff ff       	call   c002a77d <msg>
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002ad78:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
c002ad7f:	e8 f0 8c ff ff       	call   c0023a74 <malloc>
c002ad84:	89 c3                	mov    %eax,%ebx
  if (output == NULL)
c002ad86:	85 c0                	test   %eax,%eax
c002ad88:	75 24                	jne    c002adae <test_alarm_simultaneous+0xa6>
    PANIC ("couldn't allocate memory for test");
c002ad8a:	c7 44 24 0c 88 02 03 	movl   $0xc0030288,0xc(%esp)
c002ad91:	c0 
c002ad92:	c7 44 24 08 83 df 02 	movl   $0xc002df83,0x8(%esp)
c002ad99:	c0 
c002ad9a:	c7 44 24 04 31 00 00 	movl   $0x31,0x4(%esp)
c002ada1:	00 
c002ada2:	c7 04 24 38 03 03 c0 	movl   $0xc0030338,(%esp)
c002ada9:	e8 15 dc ff ff       	call   c00289c3 <debug_panic>
  test.start = timer_ticks () + 100;
c002adae:	e8 a1 94 ff ff       	call   c0024254 <timer_ticks>
c002adb3:	83 c0 64             	add    $0x64,%eax
c002adb6:	83 d2 00             	adc    $0x0,%edx
c002adb9:	89 44 24 20          	mov    %eax,0x20(%esp)
c002adbd:	89 54 24 24          	mov    %edx,0x24(%esp)
  test.iterations = iterations;
c002adc1:	c7 44 24 28 05 00 00 	movl   $0x5,0x28(%esp)
c002adc8:	00 
  test.output_pos = output;
c002adc9:	89 5c 24 2c          	mov    %ebx,0x2c(%esp)
c002adcd:	be 00 00 00 00       	mov    $0x0,%esi
      snprintf (name, sizeof name, "thread %d", i);
c002add2:	8d 7c 24 30          	lea    0x30(%esp),%edi
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002add6:	8d 6c 24 20          	lea    0x20(%esp),%ebp
      snprintf (name, sizeof name, "thread %d", i);
c002adda:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002adde:	c7 44 24 08 59 01 03 	movl   $0xc0030159,0x8(%esp)
c002ade5:	c0 
c002ade6:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002aded:	00 
c002adee:	89 3c 24             	mov    %edi,(%esp)
c002adf1:	e8 79 c4 ff ff       	call   c002726f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002adf6:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c002adfa:	c7 44 24 08 85 ac 02 	movl   $0xc002ac85,0x8(%esp)
c002ae01:	c0 
c002ae02:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002ae09:	00 
c002ae0a:	89 3c 24             	mov    %edi,(%esp)
c002ae0d:	e8 6f 67 ff ff       	call   c0021581 <thread_create>
  for (i = 0; i < thread_cnt; i++)
c002ae12:	83 c6 01             	add    $0x1,%esi
c002ae15:	83 fe 03             	cmp    $0x3,%esi
c002ae18:	75 c0                	jne    c002adda <test_alarm_simultaneous+0xd2>
  timer_sleep (100 + iterations * 10 + 100);
c002ae1a:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002ae21:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ae28:	00 
c002ae29:	e8 6e 94 ff ff       	call   c002429c <timer_sleep>
  msg ("iteration 0, thread 0: woke up after %d ticks", output[0]);
c002ae2e:	8b 03                	mov    (%ebx),%eax
c002ae30:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ae34:	c7 04 24 d0 03 03 c0 	movl   $0xc00303d0,(%esp)
c002ae3b:	e8 3d f9 ff ff       	call   c002a77d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae40:	89 df                	mov    %ebx,%edi
c002ae42:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae46:	29 d8                	sub    %ebx,%eax
c002ae48:	83 f8 07             	cmp    $0x7,%eax
c002ae4b:	7e 4a                	jle    c002ae97 <test_alarm_simultaneous+0x18f>
c002ae4d:	66 be 01 00          	mov    $0x1,%si
    msg ("iteration %d, thread %d: woke up %d ticks later",
c002ae51:	bd 56 55 55 55       	mov    $0x55555556,%ebp
c002ae56:	8b 04 b3             	mov    (%ebx,%esi,4),%eax
c002ae59:	2b 44 b3 fc          	sub    -0x4(%ebx,%esi,4),%eax
c002ae5d:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ae61:	89 f0                	mov    %esi,%eax
c002ae63:	f7 ed                	imul   %ebp
c002ae65:	89 f0                	mov    %esi,%eax
c002ae67:	c1 f8 1f             	sar    $0x1f,%eax
c002ae6a:	29 c2                	sub    %eax,%edx
c002ae6c:	8d 04 52             	lea    (%edx,%edx,2),%eax
c002ae6f:	89 f1                	mov    %esi,%ecx
c002ae71:	29 c1                	sub    %eax,%ecx
c002ae73:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002ae77:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ae7b:	c7 04 24 00 04 03 c0 	movl   $0xc0030400,(%esp)
c002ae82:	e8 f6 f8 ff ff       	call   c002a77d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae87:	83 c6 01             	add    $0x1,%esi
c002ae8a:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae8e:	29 f8                	sub    %edi,%eax
c002ae90:	c1 f8 02             	sar    $0x2,%eax
c002ae93:	39 c6                	cmp    %eax,%esi
c002ae95:	7c bf                	jl     c002ae56 <test_alarm_simultaneous+0x14e>
  free (output);
c002ae97:	89 1c 24             	mov    %ebx,(%esp)
c002ae9a:	e8 5c 8d ff ff       	call   c0023bfb <free>
}
c002ae9f:	83 c4 4c             	add    $0x4c,%esp
c002aea2:	5b                   	pop    %ebx
c002aea3:	5e                   	pop    %esi
c002aea4:	5f                   	pop    %edi
c002aea5:	5d                   	pop    %ebp
c002aea6:	c3                   	ret    

c002aea7 <alarm_priority_thread>:
    sema_down (&wait_sema);
}

static void
alarm_priority_thread (void *aux UNUSED) 
{
c002aea7:	57                   	push   %edi
c002aea8:	56                   	push   %esi
c002aea9:	83 ec 14             	sub    $0x14,%esp
  /* Busy-wait until the current time changes. */
  int64_t start_time = timer_ticks ();
c002aeac:	e8 a3 93 ff ff       	call   c0024254 <timer_ticks>
c002aeb1:	89 c6                	mov    %eax,%esi
c002aeb3:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) == 0)
c002aeb5:	89 34 24             	mov    %esi,(%esp)
c002aeb8:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002aebc:	e8 bf 93 ff ff       	call   c0024280 <timer_elapsed>
c002aec1:	09 c2                	or     %eax,%edx
c002aec3:	74 f0                	je     c002aeb5 <alarm_priority_thread+0xe>
    continue;

  /* Now we know we're at the very beginning of a timer tick, so
     we can call timer_sleep() without worrying about races
     between checking the time and a timer interrupt. */
  timer_sleep (wake_time - timer_ticks ());
c002aec5:	8b 35 40 7b 03 c0    	mov    0xc0037b40,%esi
c002aecb:	8b 3d 44 7b 03 c0    	mov    0xc0037b44,%edi
c002aed1:	e8 7e 93 ff ff       	call   c0024254 <timer_ticks>
c002aed6:	29 c6                	sub    %eax,%esi
c002aed8:	19 d7                	sbb    %edx,%edi
c002aeda:	89 34 24             	mov    %esi,(%esp)
c002aedd:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002aee1:	e8 b6 93 ff ff       	call   c002429c <timer_sleep>

  /* Print a message on wake-up. */
  msg ("Thread %s woke up.", thread_name ());
c002aee6:	e8 06 60 ff ff       	call   c0020ef1 <thread_name>
c002aeeb:	89 44 24 04          	mov    %eax,0x4(%esp)
c002aeef:	c7 04 24 30 04 03 c0 	movl   $0xc0030430,(%esp)
c002aef6:	e8 82 f8 ff ff       	call   c002a77d <msg>

  sema_up (&wait_sema);
c002aefb:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002af02:	e8 90 7d ff ff       	call   c0022c97 <sema_up>
}
c002af07:	83 c4 14             	add    $0x14,%esp
c002af0a:	5e                   	pop    %esi
c002af0b:	5f                   	pop    %edi
c002af0c:	c3                   	ret    

c002af0d <test_alarm_priority>:
{
c002af0d:	55                   	push   %ebp
c002af0e:	57                   	push   %edi
c002af0f:	56                   	push   %esi
c002af10:	53                   	push   %ebx
c002af11:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002af14:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002af1b:	74 2c                	je     c002af49 <test_alarm_priority+0x3c>
c002af1d:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002af24:	c0 
c002af25:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002af2c:	c0 
c002af2d:	c7 44 24 08 8e df 02 	movl   $0xc002df8e,0x8(%esp)
c002af34:	c0 
c002af35:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002af3c:	00 
c002af3d:	c7 04 24 50 04 03 c0 	movl   $0xc0030450,(%esp)
c002af44:	e8 7a da ff ff       	call   c00289c3 <debug_panic>
  wake_time = timer_ticks () + 5 * TIMER_FREQ;
c002af49:	e8 06 93 ff ff       	call   c0024254 <timer_ticks>
c002af4e:	05 f4 01 00 00       	add    $0x1f4,%eax
c002af53:	83 d2 00             	adc    $0x0,%edx
c002af56:	a3 40 7b 03 c0       	mov    %eax,0xc0037b40
c002af5b:	89 15 44 7b 03 c0    	mov    %edx,0xc0037b44
  sema_init (&wait_sema, 0);
c002af61:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002af68:	00 
c002af69:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002af70:	e8 c1 7b ff ff       	call   c0022b36 <sema_init>
c002af75:	bb 05 00 00 00       	mov    $0x5,%ebx
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af7a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002af7f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af83:	89 d8                	mov    %ebx,%eax
c002af85:	f7 ed                	imul   %ebp
c002af87:	c1 fa 02             	sar    $0x2,%edx
c002af8a:	89 d8                	mov    %ebx,%eax
c002af8c:	c1 f8 1f             	sar    $0x1f,%eax
c002af8f:	29 c2                	sub    %eax,%edx
c002af91:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002af94:	01 c0                	add    %eax,%eax
c002af96:	29 d8                	sub    %ebx,%eax
c002af98:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002af9b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002af9f:	c7 44 24 08 43 04 03 	movl   $0xc0030443,0x8(%esp)
c002afa6:	c0 
c002afa7:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002afae:	00 
c002afaf:	89 3c 24             	mov    %edi,(%esp)
c002afb2:	e8 b8 c2 ff ff       	call   c002726f <snprintf>
      thread_create (name, priority, alarm_priority_thread, NULL);
c002afb7:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002afbe:	00 
c002afbf:	c7 44 24 08 a7 ae 02 	movl   $0xc002aea7,0x8(%esp)
c002afc6:	c0 
c002afc7:	89 74 24 04          	mov    %esi,0x4(%esp)
c002afcb:	89 3c 24             	mov    %edi,(%esp)
c002afce:	e8 ae 65 ff ff       	call   c0021581 <thread_create>
c002afd3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002afd6:	83 fb 0f             	cmp    $0xf,%ebx
c002afd9:	75 a8                	jne    c002af83 <test_alarm_priority+0x76>
  thread_set_priority (PRI_MIN);
c002afdb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002afe2:	e8 08 67 ff ff       	call   c00216ef <thread_set_priority>
c002afe7:	b3 0a                	mov    $0xa,%bl
    sema_down (&wait_sema);
c002afe9:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002aff0:	e8 8d 7b ff ff       	call   c0022b82 <sema_down>
  for (i = 0; i < 10; i++)
c002aff5:	83 eb 01             	sub    $0x1,%ebx
c002aff8:	75 ef                	jne    c002afe9 <test_alarm_priority+0xdc>
}
c002affa:	83 c4 3c             	add    $0x3c,%esp
c002affd:	5b                   	pop    %ebx
c002affe:	5e                   	pop    %esi
c002afff:	5f                   	pop    %edi
c002b000:	5d                   	pop    %ebp
c002b001:	c3                   	ret    

c002b002 <test_alarm_zero>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_zero (void) 
{
c002b002:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (0);
c002b005:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002b00c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002b013:	00 
c002b014:	e8 83 92 ff ff       	call   c002429c <timer_sleep>
  pass ();
c002b019:	e8 73 f8 ff ff       	call   c002a891 <pass>
}
c002b01e:	83 c4 1c             	add    $0x1c,%esp
c002b021:	c3                   	ret    

c002b022 <test_alarm_negative>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_negative (void) 
{
c002b022:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (-100);
c002b025:	c7 04 24 9c ff ff ff 	movl   $0xffffff9c,(%esp)
c002b02c:	c7 44 24 04 ff ff ff 	movl   $0xffffffff,0x4(%esp)
c002b033:	ff 
c002b034:	e8 63 92 ff ff       	call   c002429c <timer_sleep>
  pass ();
c002b039:	e8 53 f8 ff ff       	call   c002a891 <pass>
}
c002b03e:	83 c4 1c             	add    $0x1c,%esp
c002b041:	c3                   	ret    

c002b042 <changing_thread>:
  msg ("Thread 2 should have just exited.");
}

static void
changing_thread (void *aux UNUSED) 
{
c002b042:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread 2 now lowering priority.");
c002b045:	c7 04 24 78 04 03 c0 	movl   $0xc0030478,(%esp)
c002b04c:	e8 2c f7 ff ff       	call   c002a77d <msg>
  thread_set_priority (PRI_DEFAULT - 1);
c002b051:	c7 04 24 1e 00 00 00 	movl   $0x1e,(%esp)
c002b058:	e8 92 66 ff ff       	call   c00216ef <thread_set_priority>
  msg ("Thread 2 exiting.");
c002b05d:	c7 04 24 36 05 03 c0 	movl   $0xc0030536,(%esp)
c002b064:	e8 14 f7 ff ff       	call   c002a77d <msg>
}
c002b069:	83 c4 1c             	add    $0x1c,%esp
c002b06c:	c3                   	ret    

c002b06d <test_priority_change>:
{
c002b06d:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002b070:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b077:	74 2c                	je     c002b0a5 <test_priority_change+0x38>
c002b079:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b080:	c0 
c002b081:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b088:	c0 
c002b089:	c7 44 24 08 a2 df 02 	movl   $0xc002dfa2,0x8(%esp)
c002b090:	c0 
c002b091:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002b098:	00 
c002b099:	c7 04 24 98 04 03 c0 	movl   $0xc0030498,(%esp)
c002b0a0:	e8 1e d9 ff ff       	call   c00289c3 <debug_panic>
  msg ("Creating a high-priority thread 2.");
c002b0a5:	c7 04 24 c0 04 03 c0 	movl   $0xc00304c0,(%esp)
c002b0ac:	e8 cc f6 ff ff       	call   c002a77d <msg>
  thread_create ("thread 2", PRI_DEFAULT + 1, changing_thread, NULL);
c002b0b1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b0b8:	00 
c002b0b9:	c7 44 24 08 42 b0 02 	movl   $0xc002b042,0x8(%esp)
c002b0c0:	c0 
c002b0c1:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b0c8:	00 
c002b0c9:	c7 04 24 48 05 03 c0 	movl   $0xc0030548,(%esp)
c002b0d0:	e8 ac 64 ff ff       	call   c0021581 <thread_create>
  msg ("Thread 2 should have just lowered its priority.");
c002b0d5:	c7 04 24 e4 04 03 c0 	movl   $0xc00304e4,(%esp)
c002b0dc:	e8 9c f6 ff ff       	call   c002a77d <msg>
  thread_set_priority (PRI_DEFAULT - 2);
c002b0e1:	c7 04 24 1d 00 00 00 	movl   $0x1d,(%esp)
c002b0e8:	e8 02 66 ff ff       	call   c00216ef <thread_set_priority>
  msg ("Thread 2 should have just exited.");
c002b0ed:	c7 04 24 14 05 03 c0 	movl   $0xc0030514,(%esp)
c002b0f4:	e8 84 f6 ff ff       	call   c002a77d <msg>
}
c002b0f9:	83 c4 2c             	add    $0x2c,%esp
c002b0fc:	c3                   	ret    

c002b0fd <acquire2_thread_func>:
  msg ("acquire1: done");
}

static void
acquire2_thread_func (void *lock_) 
{
c002b0fd:	53                   	push   %ebx
c002b0fe:	83 ec 18             	sub    $0x18,%esp
c002b101:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b105:	89 1c 24             	mov    %ebx,(%esp)
c002b108:	e8 9d 7d ff ff       	call   c0022eaa <lock_acquire>
  msg ("acquire2: got the lock");
c002b10d:	c7 04 24 51 05 03 c0 	movl   $0xc0030551,(%esp)
c002b114:	e8 64 f6 ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002b119:	89 1c 24             	mov    %ebx,(%esp)
c002b11c:	e8 53 7f ff ff       	call   c0023074 <lock_release>
  msg ("acquire2: done");
c002b121:	c7 04 24 68 05 03 c0 	movl   $0xc0030568,(%esp)
c002b128:	e8 50 f6 ff ff       	call   c002a77d <msg>
}
c002b12d:	83 c4 18             	add    $0x18,%esp
c002b130:	5b                   	pop    %ebx
c002b131:	c3                   	ret    

c002b132 <acquire1_thread_func>:
{
c002b132:	53                   	push   %ebx
c002b133:	83 ec 18             	sub    $0x18,%esp
c002b136:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b13a:	89 1c 24             	mov    %ebx,(%esp)
c002b13d:	e8 68 7d ff ff       	call   c0022eaa <lock_acquire>
  msg ("acquire1: got the lock");
c002b142:	c7 04 24 77 05 03 c0 	movl   $0xc0030577,(%esp)
c002b149:	e8 2f f6 ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002b14e:	89 1c 24             	mov    %ebx,(%esp)
c002b151:	e8 1e 7f ff ff       	call   c0023074 <lock_release>
  msg ("acquire1: done");
c002b156:	c7 04 24 8e 05 03 c0 	movl   $0xc003058e,(%esp)
c002b15d:	e8 1b f6 ff ff       	call   c002a77d <msg>
}
c002b162:	83 c4 18             	add    $0x18,%esp
c002b165:	5b                   	pop    %ebx
c002b166:	c3                   	ret    

c002b167 <test_priority_donate_one>:
{
c002b167:	53                   	push   %ebx
c002b168:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002b16b:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b172:	74 2c                	je     c002b1a0 <test_priority_donate_one+0x39>
c002b174:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b17b:	c0 
c002b17c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b183:	c0 
c002b184:	c7 44 24 08 b7 df 02 	movl   $0xc002dfb7,0x8(%esp)
c002b18b:	c0 
c002b18c:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b193:	00 
c002b194:	c7 04 24 b0 05 03 c0 	movl   $0xc00305b0,(%esp)
c002b19b:	e8 23 d8 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b1a0:	e8 e9 5d ff ff       	call   c0020f8e <thread_get_priority>
c002b1a5:	83 f8 1f             	cmp    $0x1f,%eax
c002b1a8:	74 2c                	je     c002b1d6 <test_priority_donate_one+0x6f>
c002b1aa:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b1b1:	c0 
c002b1b2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b1b9:	c0 
c002b1ba:	c7 44 24 08 b7 df 02 	movl   $0xc002dfb7,0x8(%esp)
c002b1c1:	c0 
c002b1c2:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b1c9:	00 
c002b1ca:	c7 04 24 b0 05 03 c0 	movl   $0xc00305b0,(%esp)
c002b1d1:	e8 ed d7 ff ff       	call   c00289c3 <debug_panic>
  lock_init (&lock);
c002b1d6:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002b1da:	89 1c 24             	mov    %ebx,(%esp)
c002b1dd:	e8 2b 7c ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&lock);
c002b1e2:	89 1c 24             	mov    %ebx,(%esp)
c002b1e5:	e8 c0 7c ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("acquire1", PRI_DEFAULT + 1, acquire1_thread_func, &lock);
c002b1ea:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b1ee:	c7 44 24 08 32 b1 02 	movl   $0xc002b132,0x8(%esp)
c002b1f5:	c0 
c002b1f6:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b1fd:	00 
c002b1fe:	c7 04 24 9d 05 03 c0 	movl   $0xc003059d,(%esp)
c002b205:	e8 77 63 ff ff       	call   c0021581 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b20a:	e8 7f 5d ff ff       	call   c0020f8e <thread_get_priority>
c002b20f:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b213:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b21a:	00 
c002b21b:	c7 04 24 04 06 03 c0 	movl   $0xc0030604,(%esp)
c002b222:	e8 56 f5 ff ff       	call   c002a77d <msg>
  thread_create ("acquire2", PRI_DEFAULT + 2, acquire2_thread_func, &lock);
c002b227:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b22b:	c7 44 24 08 fd b0 02 	movl   $0xc002b0fd,0x8(%esp)
c002b232:	c0 
c002b233:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b23a:	00 
c002b23b:	c7 04 24 a6 05 03 c0 	movl   $0xc00305a6,(%esp)
c002b242:	e8 3a 63 ff ff       	call   c0021581 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b247:	e8 42 5d ff ff       	call   c0020f8e <thread_get_priority>
c002b24c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b250:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b257:	00 
c002b258:	c7 04 24 04 06 03 c0 	movl   $0xc0030604,(%esp)
c002b25f:	e8 19 f5 ff ff       	call   c002a77d <msg>
  lock_release (&lock);
c002b264:	89 1c 24             	mov    %ebx,(%esp)
c002b267:	e8 08 7e ff ff       	call   c0023074 <lock_release>
  msg ("acquire2, acquire1 must already have finished, in that order.");
c002b26c:	c7 04 24 40 06 03 c0 	movl   $0xc0030640,(%esp)
c002b273:	e8 05 f5 ff ff       	call   c002a77d <msg>
  msg ("This should be the last line before finishing this test.");
c002b278:	c7 04 24 80 06 03 c0 	movl   $0xc0030680,(%esp)
c002b27f:	e8 f9 f4 ff ff       	call   c002a77d <msg>
}
c002b284:	83 c4 58             	add    $0x58,%esp
c002b287:	5b                   	pop    %ebx
c002b288:	c3                   	ret    

c002b289 <b_thread_func>:
  msg ("Thread a finished.");
}

static void
b_thread_func (void *lock_) 
{
c002b289:	53                   	push   %ebx
c002b28a:	83 ec 18             	sub    $0x18,%esp
c002b28d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b291:	89 1c 24             	mov    %ebx,(%esp)
c002b294:	e8 11 7c ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b299:	c7 04 24 b9 06 03 c0 	movl   $0xc00306b9,(%esp)
c002b2a0:	e8 d8 f4 ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002b2a5:	89 1c 24             	mov    %ebx,(%esp)
c002b2a8:	e8 c7 7d ff ff       	call   c0023074 <lock_release>
  msg ("Thread b finished.");
c002b2ad:	c7 04 24 d3 06 03 c0 	movl   $0xc00306d3,(%esp)
c002b2b4:	e8 c4 f4 ff ff       	call   c002a77d <msg>
}
c002b2b9:	83 c4 18             	add    $0x18,%esp
c002b2bc:	5b                   	pop    %ebx
c002b2bd:	c3                   	ret    

c002b2be <a_thread_func>:
{
c002b2be:	53                   	push   %ebx
c002b2bf:	83 ec 18             	sub    $0x18,%esp
c002b2c2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b2c6:	89 1c 24             	mov    %ebx,(%esp)
c002b2c9:	e8 dc 7b ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b2ce:	c7 04 24 e6 06 03 c0 	movl   $0xc00306e6,(%esp)
c002b2d5:	e8 a3 f4 ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002b2da:	89 1c 24             	mov    %ebx,(%esp)
c002b2dd:	e8 92 7d ff ff       	call   c0023074 <lock_release>
  msg ("Thread a finished.");
c002b2e2:	c7 04 24 00 07 03 c0 	movl   $0xc0030700,(%esp)
c002b2e9:	e8 8f f4 ff ff       	call   c002a77d <msg>
}
c002b2ee:	83 c4 18             	add    $0x18,%esp
c002b2f1:	5b                   	pop    %ebx
c002b2f2:	c3                   	ret    

c002b2f3 <test_priority_donate_multiple>:
{
c002b2f3:	56                   	push   %esi
c002b2f4:	53                   	push   %ebx
c002b2f5:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b2f8:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b2ff:	74 2c                	je     c002b32d <test_priority_donate_multiple+0x3a>
c002b301:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b308:	c0 
c002b309:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b310:	c0 
c002b311:	c7 44 24 08 d0 df 02 	movl   $0xc002dfd0,0x8(%esp)
c002b318:	c0 
c002b319:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b320:	00 
c002b321:	c7 04 24 14 07 03 c0 	movl   $0xc0030714,(%esp)
c002b328:	e8 96 d6 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b32d:	e8 5c 5c ff ff       	call   c0020f8e <thread_get_priority>
c002b332:	83 f8 1f             	cmp    $0x1f,%eax
c002b335:	74 2c                	je     c002b363 <test_priority_donate_multiple+0x70>
c002b337:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b33e:	c0 
c002b33f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b346:	c0 
c002b347:	c7 44 24 08 d0 df 02 	movl   $0xc002dfd0,0x8(%esp)
c002b34e:	c0 
c002b34f:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b356:	00 
c002b357:	c7 04 24 14 07 03 c0 	movl   $0xc0030714,(%esp)
c002b35e:	e8 60 d6 ff ff       	call   c00289c3 <debug_panic>
  lock_init (&a);
c002b363:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b367:	89 1c 24             	mov    %ebx,(%esp)
c002b36a:	e8 9e 7a ff ff       	call   c0022e0d <lock_init>
  lock_init (&b);
c002b36f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b373:	89 34 24             	mov    %esi,(%esp)
c002b376:	e8 92 7a ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&a);
c002b37b:	89 1c 24             	mov    %ebx,(%esp)
c002b37e:	e8 27 7b ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (&b);
c002b383:	89 34 24             	mov    %esi,(%esp)
c002b386:	e8 1f 7b ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 1, a_thread_func, &a);
c002b38b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b38f:	c7 44 24 08 be b2 02 	movl   $0xc002b2be,0x8(%esp)
c002b396:	c0 
c002b397:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b39e:	00 
c002b39f:	c7 04 24 b3 f2 02 c0 	movl   $0xc002f2b3,(%esp)
c002b3a6:	e8 d6 61 ff ff       	call   c0021581 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3ab:	e8 de 5b ff ff       	call   c0020f8e <thread_get_priority>
c002b3b0:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3b4:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b3bb:	00 
c002b3bc:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b3c3:	e8 b5 f3 ff ff       	call   c002a77d <msg>
  thread_create ("b", PRI_DEFAULT + 2, b_thread_func, &b);
c002b3c8:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b3cc:	c7 44 24 08 89 b2 02 	movl   $0xc002b289,0x8(%esp)
c002b3d3:	c0 
c002b3d4:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b3db:	00 
c002b3dc:	c7 04 24 7d fc 02 c0 	movl   $0xc002fc7d,(%esp)
c002b3e3:	e8 99 61 ff ff       	call   c0021581 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3e8:	e8 a1 5b ff ff       	call   c0020f8e <thread_get_priority>
c002b3ed:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3f1:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b3f8:	00 
c002b3f9:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b400:	e8 78 f3 ff ff       	call   c002a77d <msg>
  lock_release (&b);
c002b405:	89 34 24             	mov    %esi,(%esp)
c002b408:	e8 67 7c ff ff       	call   c0023074 <lock_release>
  msg ("Thread b should have just finished.");
c002b40d:	c7 04 24 80 07 03 c0 	movl   $0xc0030780,(%esp)
c002b414:	e8 64 f3 ff ff       	call   c002a77d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b419:	e8 70 5b ff ff       	call   c0020f8e <thread_get_priority>
c002b41e:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b422:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b429:	00 
c002b42a:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b431:	e8 47 f3 ff ff       	call   c002a77d <msg>
  lock_release (&a);
c002b436:	89 1c 24             	mov    %ebx,(%esp)
c002b439:	e8 36 7c ff ff       	call   c0023074 <lock_release>
  msg ("Thread a should have just finished.");
c002b43e:	c7 04 24 a4 07 03 c0 	movl   $0xc00307a4,(%esp)
c002b445:	e8 33 f3 ff ff       	call   c002a77d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b44a:	e8 3f 5b ff ff       	call   c0020f8e <thread_get_priority>
c002b44f:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b453:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b45a:	00 
c002b45b:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b462:	e8 16 f3 ff ff       	call   c002a77d <msg>
}
c002b467:	83 c4 74             	add    $0x74,%esp
c002b46a:	5b                   	pop    %ebx
c002b46b:	5e                   	pop    %esi
c002b46c:	c3                   	ret    

c002b46d <c_thread_func>:
  msg ("Thread b finished.");
}

static void
c_thread_func (void *a_ UNUSED) 
{
c002b46d:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread c finished.");
c002b470:	c7 04 24 c8 07 03 c0 	movl   $0xc00307c8,(%esp)
c002b477:	e8 01 f3 ff ff       	call   c002a77d <msg>
}
c002b47c:	83 c4 1c             	add    $0x1c,%esp
c002b47f:	c3                   	ret    

c002b480 <b_thread_func>:
{
c002b480:	53                   	push   %ebx
c002b481:	83 ec 18             	sub    $0x18,%esp
c002b484:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b488:	89 1c 24             	mov    %ebx,(%esp)
c002b48b:	e8 1a 7a ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b490:	c7 04 24 b9 06 03 c0 	movl   $0xc00306b9,(%esp)
c002b497:	e8 e1 f2 ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002b49c:	89 1c 24             	mov    %ebx,(%esp)
c002b49f:	e8 d0 7b ff ff       	call   c0023074 <lock_release>
  msg ("Thread b finished.");
c002b4a4:	c7 04 24 d3 06 03 c0 	movl   $0xc00306d3,(%esp)
c002b4ab:	e8 cd f2 ff ff       	call   c002a77d <msg>
}
c002b4b0:	83 c4 18             	add    $0x18,%esp
c002b4b3:	5b                   	pop    %ebx
c002b4b4:	c3                   	ret    

c002b4b5 <a_thread_func>:
{
c002b4b5:	53                   	push   %ebx
c002b4b6:	83 ec 18             	sub    $0x18,%esp
c002b4b9:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b4bd:	89 1c 24             	mov    %ebx,(%esp)
c002b4c0:	e8 e5 79 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b4c5:	c7 04 24 e6 06 03 c0 	movl   $0xc00306e6,(%esp)
c002b4cc:	e8 ac f2 ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002b4d1:	89 1c 24             	mov    %ebx,(%esp)
c002b4d4:	e8 9b 7b ff ff       	call   c0023074 <lock_release>
  msg ("Thread a finished.");
c002b4d9:	c7 04 24 00 07 03 c0 	movl   $0xc0030700,(%esp)
c002b4e0:	e8 98 f2 ff ff       	call   c002a77d <msg>
}
c002b4e5:	83 c4 18             	add    $0x18,%esp
c002b4e8:	5b                   	pop    %ebx
c002b4e9:	c3                   	ret    

c002b4ea <test_priority_donate_multiple2>:
{
c002b4ea:	56                   	push   %esi
c002b4eb:	53                   	push   %ebx
c002b4ec:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b4ef:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b4f6:	74 2c                	je     c002b524 <test_priority_donate_multiple2+0x3a>
c002b4f8:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b4ff:	c0 
c002b500:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b507:	c0 
c002b508:	c7 44 24 08 f0 df 02 	movl   $0xc002dff0,0x8(%esp)
c002b50f:	c0 
c002b510:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b517:	00 
c002b518:	c7 04 24 dc 07 03 c0 	movl   $0xc00307dc,(%esp)
c002b51f:	e8 9f d4 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b524:	e8 65 5a ff ff       	call   c0020f8e <thread_get_priority>
c002b529:	83 f8 1f             	cmp    $0x1f,%eax
c002b52c:	74 2c                	je     c002b55a <test_priority_donate_multiple2+0x70>
c002b52e:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b535:	c0 
c002b536:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b53d:	c0 
c002b53e:	c7 44 24 08 f0 df 02 	movl   $0xc002dff0,0x8(%esp)
c002b545:	c0 
c002b546:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b54d:	00 
c002b54e:	c7 04 24 dc 07 03 c0 	movl   $0xc00307dc,(%esp)
c002b555:	e8 69 d4 ff ff       	call   c00289c3 <debug_panic>
  lock_init (&a);
c002b55a:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b55e:	89 34 24             	mov    %esi,(%esp)
c002b561:	e8 a7 78 ff ff       	call   c0022e0d <lock_init>
  lock_init (&b);
c002b566:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b56a:	89 1c 24             	mov    %ebx,(%esp)
c002b56d:	e8 9b 78 ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&a);
c002b572:	89 34 24             	mov    %esi,(%esp)
c002b575:	e8 30 79 ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (&b);
c002b57a:	89 1c 24             	mov    %ebx,(%esp)
c002b57d:	e8 28 79 ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 3, a_thread_func, &a);
c002b582:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b586:	c7 44 24 08 b5 b4 02 	movl   $0xc002b4b5,0x8(%esp)
c002b58d:	c0 
c002b58e:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b595:	00 
c002b596:	c7 04 24 b3 f2 02 c0 	movl   $0xc002f2b3,(%esp)
c002b59d:	e8 df 5f ff ff       	call   c0021581 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5a2:	e8 e7 59 ff ff       	call   c0020f8e <thread_get_priority>
c002b5a7:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5ab:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b5b2:	00 
c002b5b3:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b5ba:	e8 be f1 ff ff       	call   c002a77d <msg>
  thread_create ("c", PRI_DEFAULT + 1, c_thread_func, NULL);
c002b5bf:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b5c6:	00 
c002b5c7:	c7 44 24 08 6d b4 02 	movl   $0xc002b46d,0x8(%esp)
c002b5ce:	c0 
c002b5cf:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b5d6:	00 
c002b5d7:	c7 04 24 9e f6 02 c0 	movl   $0xc002f69e,(%esp)
c002b5de:	e8 9e 5f ff ff       	call   c0021581 <thread_create>
  thread_create ("b", PRI_DEFAULT + 5, b_thread_func, &b);
c002b5e3:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b5e7:	c7 44 24 08 80 b4 02 	movl   $0xc002b480,0x8(%esp)
c002b5ee:	c0 
c002b5ef:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5f6:	00 
c002b5f7:	c7 04 24 7d fc 02 c0 	movl   $0xc002fc7d,(%esp)
c002b5fe:	e8 7e 5f ff ff       	call   c0021581 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b603:	e8 86 59 ff ff       	call   c0020f8e <thread_get_priority>
c002b608:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b60c:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b613:	00 
c002b614:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b61b:	e8 5d f1 ff ff       	call   c002a77d <msg>
  lock_release (&a);
c002b620:	89 34 24             	mov    %esi,(%esp)
c002b623:	e8 4c 7a ff ff       	call   c0023074 <lock_release>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b628:	e8 61 59 ff ff       	call   c0020f8e <thread_get_priority>
c002b62d:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b631:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b638:	00 
c002b639:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b640:	e8 38 f1 ff ff       	call   c002a77d <msg>
  lock_release (&b);
c002b645:	89 1c 24             	mov    %ebx,(%esp)
c002b648:	e8 27 7a ff ff       	call   c0023074 <lock_release>
  msg ("Threads b, a, c should have just finished, in that order.");
c002b64d:	c7 04 24 0c 08 03 c0 	movl   $0xc003080c,(%esp)
c002b654:	e8 24 f1 ff ff       	call   c002a77d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b659:	e8 30 59 ff ff       	call   c0020f8e <thread_get_priority>
c002b65e:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b662:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b669:	00 
c002b66a:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b671:	e8 07 f1 ff ff       	call   c002a77d <msg>
}
c002b676:	83 c4 74             	add    $0x74,%esp
c002b679:	5b                   	pop    %ebx
c002b67a:	5e                   	pop    %esi
c002b67b:	c3                   	ret    

c002b67c <high_thread_func>:
  msg ("Middle thread finished.");
}

static void
high_thread_func (void *lock_) 
{
c002b67c:	53                   	push   %ebx
c002b67d:	83 ec 18             	sub    $0x18,%esp
c002b680:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b684:	89 1c 24             	mov    %ebx,(%esp)
c002b687:	e8 1e 78 ff ff       	call   c0022eaa <lock_acquire>
  msg ("High thread got the lock.");
c002b68c:	c7 04 24 46 08 03 c0 	movl   $0xc0030846,(%esp)
c002b693:	e8 e5 f0 ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002b698:	89 1c 24             	mov    %ebx,(%esp)
c002b69b:	e8 d4 79 ff ff       	call   c0023074 <lock_release>
  msg ("High thread finished.");
c002b6a0:	c7 04 24 60 08 03 c0 	movl   $0xc0030860,(%esp)
c002b6a7:	e8 d1 f0 ff ff       	call   c002a77d <msg>
}
c002b6ac:	83 c4 18             	add    $0x18,%esp
c002b6af:	5b                   	pop    %ebx
c002b6b0:	c3                   	ret    

c002b6b1 <medium_thread_func>:
{
c002b6b1:	53                   	push   %ebx
c002b6b2:	83 ec 18             	sub    $0x18,%esp
c002b6b5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (locks->b);
c002b6b9:	8b 43 04             	mov    0x4(%ebx),%eax
c002b6bc:	89 04 24             	mov    %eax,(%esp)
c002b6bf:	e8 e6 77 ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (locks->a);
c002b6c4:	8b 03                	mov    (%ebx),%eax
c002b6c6:	89 04 24             	mov    %eax,(%esp)
c002b6c9:	e8 dc 77 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Medium thread should have priority %d.  Actual priority: %d.",
c002b6ce:	e8 bb 58 ff ff       	call   c0020f8e <thread_get_priority>
c002b6d3:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b6d7:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b6de:	00 
c002b6df:	c7 04 24 b8 08 03 c0 	movl   $0xc00308b8,(%esp)
c002b6e6:	e8 92 f0 ff ff       	call   c002a77d <msg>
  msg ("Medium thread got the lock.");
c002b6eb:	c7 04 24 76 08 03 c0 	movl   $0xc0030876,(%esp)
c002b6f2:	e8 86 f0 ff ff       	call   c002a77d <msg>
  lock_release (locks->a);
c002b6f7:	8b 03                	mov    (%ebx),%eax
c002b6f9:	89 04 24             	mov    %eax,(%esp)
c002b6fc:	e8 73 79 ff ff       	call   c0023074 <lock_release>
  thread_yield ();
c002b701:	e8 d9 5d ff ff       	call   c00214df <thread_yield>
  lock_release (locks->b);
c002b706:	8b 43 04             	mov    0x4(%ebx),%eax
c002b709:	89 04 24             	mov    %eax,(%esp)
c002b70c:	e8 63 79 ff ff       	call   c0023074 <lock_release>
  thread_yield ();
c002b711:	e8 c9 5d ff ff       	call   c00214df <thread_yield>
  msg ("High thread should have just finished.");
c002b716:	c7 04 24 f8 08 03 c0 	movl   $0xc00308f8,(%esp)
c002b71d:	e8 5b f0 ff ff       	call   c002a77d <msg>
  msg ("Middle thread finished.");
c002b722:	c7 04 24 92 08 03 c0 	movl   $0xc0030892,(%esp)
c002b729:	e8 4f f0 ff ff       	call   c002a77d <msg>
}
c002b72e:	83 c4 18             	add    $0x18,%esp
c002b731:	5b                   	pop    %ebx
c002b732:	c3                   	ret    

c002b733 <test_priority_donate_nest>:
{
c002b733:	56                   	push   %esi
c002b734:	53                   	push   %ebx
c002b735:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b738:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b73f:	74 2c                	je     c002b76d <test_priority_donate_nest+0x3a>
c002b741:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b748:	c0 
c002b749:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b750:	c0 
c002b751:	c7 44 24 08 0f e0 02 	movl   $0xc002e00f,0x8(%esp)
c002b758:	c0 
c002b759:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b760:	00 
c002b761:	c7 04 24 20 09 03 c0 	movl   $0xc0030920,(%esp)
c002b768:	e8 56 d2 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b76d:	e8 1c 58 ff ff       	call   c0020f8e <thread_get_priority>
c002b772:	83 f8 1f             	cmp    $0x1f,%eax
c002b775:	74 2c                	je     c002b7a3 <test_priority_donate_nest+0x70>
c002b777:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b77e:	c0 
c002b77f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b786:	c0 
c002b787:	c7 44 24 08 0f e0 02 	movl   $0xc002e00f,0x8(%esp)
c002b78e:	c0 
c002b78f:	c7 44 24 04 25 00 00 	movl   $0x25,0x4(%esp)
c002b796:	00 
c002b797:	c7 04 24 20 09 03 c0 	movl   $0xc0030920,(%esp)
c002b79e:	e8 20 d2 ff ff       	call   c00289c3 <debug_panic>
  lock_init (&a);
c002b7a3:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b7a7:	89 1c 24             	mov    %ebx,(%esp)
c002b7aa:	e8 5e 76 ff ff       	call   c0022e0d <lock_init>
  lock_init (&b);
c002b7af:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b7b3:	89 34 24             	mov    %esi,(%esp)
c002b7b6:	e8 52 76 ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&a);
c002b7bb:	89 1c 24             	mov    %ebx,(%esp)
c002b7be:	e8 e7 76 ff ff       	call   c0022eaa <lock_acquire>
  locks.a = &a;
c002b7c3:	89 5c 24 20          	mov    %ebx,0x20(%esp)
  locks.b = &b;
c002b7c7:	89 74 24 24          	mov    %esi,0x24(%esp)
  thread_create ("medium", PRI_DEFAULT + 1, medium_thread_func, &locks);
c002b7cb:	8d 44 24 20          	lea    0x20(%esp),%eax
c002b7cf:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002b7d3:	c7 44 24 08 b1 b6 02 	movl   $0xc002b6b1,0x8(%esp)
c002b7da:	c0 
c002b7db:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b7e2:	00 
c002b7e3:	c7 04 24 aa 08 03 c0 	movl   $0xc00308aa,(%esp)
c002b7ea:	e8 92 5d ff ff       	call   c0021581 <thread_create>
  thread_yield ();
c002b7ef:	e8 eb 5c ff ff       	call   c00214df <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b7f4:	e8 95 57 ff ff       	call   c0020f8e <thread_get_priority>
c002b7f9:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b7fd:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b804:	00 
c002b805:	c7 04 24 4c 09 03 c0 	movl   $0xc003094c,(%esp)
c002b80c:	e8 6c ef ff ff       	call   c002a77d <msg>
  thread_create ("high", PRI_DEFAULT + 2, high_thread_func, &b);
c002b811:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b815:	c7 44 24 08 7c b6 02 	movl   $0xc002b67c,0x8(%esp)
c002b81c:	c0 
c002b81d:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b824:	00 
c002b825:	c7 04 24 b1 08 03 c0 	movl   $0xc00308b1,(%esp)
c002b82c:	e8 50 5d ff ff       	call   c0021581 <thread_create>
  thread_yield ();
c002b831:	e8 a9 5c ff ff       	call   c00214df <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b836:	e8 53 57 ff ff       	call   c0020f8e <thread_get_priority>
c002b83b:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b83f:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b846:	00 
c002b847:	c7 04 24 4c 09 03 c0 	movl   $0xc003094c,(%esp)
c002b84e:	e8 2a ef ff ff       	call   c002a77d <msg>
  lock_release (&a);
c002b853:	89 1c 24             	mov    %ebx,(%esp)
c002b856:	e8 19 78 ff ff       	call   c0023074 <lock_release>
  thread_yield ();
c002b85b:	e8 7f 5c ff ff       	call   c00214df <thread_yield>
  msg ("Medium thread should just have finished.");
c002b860:	c7 04 24 88 09 03 c0 	movl   $0xc0030988,(%esp)
c002b867:	e8 11 ef ff ff       	call   c002a77d <msg>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b86c:	e8 1d 57 ff ff       	call   c0020f8e <thread_get_priority>
c002b871:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b875:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b87c:	00 
c002b87d:	c7 04 24 4c 09 03 c0 	movl   $0xc003094c,(%esp)
c002b884:	e8 f4 ee ff ff       	call   c002a77d <msg>
}
c002b889:	83 c4 74             	add    $0x74,%esp
c002b88c:	5b                   	pop    %ebx
c002b88d:	5e                   	pop    %esi
c002b88e:	c3                   	ret    

c002b88f <h_thread_func>:
  msg ("Thread M finished.");
}

static void
h_thread_func (void *ls_) 
{
c002b88f:	53                   	push   %ebx
c002b890:	83 ec 18             	sub    $0x18,%esp
c002b893:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock_and_sema *ls = ls_;

  lock_acquire (&ls->lock);
c002b897:	89 1c 24             	mov    %ebx,(%esp)
c002b89a:	e8 0b 76 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread H acquired lock.");
c002b89f:	c7 04 24 b1 09 03 c0 	movl   $0xc00309b1,(%esp)
c002b8a6:	e8 d2 ee ff ff       	call   c002a77d <msg>

  sema_up (&ls->sema);
c002b8ab:	8d 43 24             	lea    0x24(%ebx),%eax
c002b8ae:	89 04 24             	mov    %eax,(%esp)
c002b8b1:	e8 e1 73 ff ff       	call   c0022c97 <sema_up>
  lock_release (&ls->lock);
c002b8b6:	89 1c 24             	mov    %ebx,(%esp)
c002b8b9:	e8 b6 77 ff ff       	call   c0023074 <lock_release>
  msg ("Thread H finished.");
c002b8be:	c7 04 24 c9 09 03 c0 	movl   $0xc00309c9,(%esp)
c002b8c5:	e8 b3 ee ff ff       	call   c002a77d <msg>
}
c002b8ca:	83 c4 18             	add    $0x18,%esp
c002b8cd:	5b                   	pop    %ebx
c002b8ce:	c3                   	ret    

c002b8cf <m_thread_func>:
{
c002b8cf:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&ls->sema);
c002b8d2:	8b 44 24 20          	mov    0x20(%esp),%eax
c002b8d6:	83 c0 24             	add    $0x24,%eax
c002b8d9:	89 04 24             	mov    %eax,(%esp)
c002b8dc:	e8 a1 72 ff ff       	call   c0022b82 <sema_down>
  msg ("Thread M finished.");
c002b8e1:	c7 04 24 dc 09 03 c0 	movl   $0xc00309dc,(%esp)
c002b8e8:	e8 90 ee ff ff       	call   c002a77d <msg>
}
c002b8ed:	83 c4 1c             	add    $0x1c,%esp
c002b8f0:	c3                   	ret    

c002b8f1 <l_thread_func>:
{
c002b8f1:	53                   	push   %ebx
c002b8f2:	83 ec 18             	sub    $0x18,%esp
c002b8f5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (&ls->lock);
c002b8f9:	89 1c 24             	mov    %ebx,(%esp)
c002b8fc:	e8 a9 75 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread L acquired lock.");
c002b901:	c7 04 24 ef 09 03 c0 	movl   $0xc00309ef,(%esp)
c002b908:	e8 70 ee ff ff       	call   c002a77d <msg>
  sema_down (&ls->sema);
c002b90d:	8d 43 24             	lea    0x24(%ebx),%eax
c002b910:	89 04 24             	mov    %eax,(%esp)
c002b913:	e8 6a 72 ff ff       	call   c0022b82 <sema_down>
  msg ("Thread L downed semaphore.");
c002b918:	c7 04 24 07 0a 03 c0 	movl   $0xc0030a07,(%esp)
c002b91f:	e8 59 ee ff ff       	call   c002a77d <msg>
  lock_release (&ls->lock);
c002b924:	89 1c 24             	mov    %ebx,(%esp)
c002b927:	e8 48 77 ff ff       	call   c0023074 <lock_release>
  msg ("Thread L finished.");
c002b92c:	c7 04 24 22 0a 03 c0 	movl   $0xc0030a22,(%esp)
c002b933:	e8 45 ee ff ff       	call   c002a77d <msg>
}
c002b938:	83 c4 18             	add    $0x18,%esp
c002b93b:	5b                   	pop    %ebx
c002b93c:	c3                   	ret    

c002b93d <test_priority_donate_sema>:
{
c002b93d:	56                   	push   %esi
c002b93e:	53                   	push   %ebx
c002b93f:	83 ec 64             	sub    $0x64,%esp
  ASSERT (!thread_mlfqs);
c002b942:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b949:	74 2c                	je     c002b977 <test_priority_donate_sema+0x3a>
c002b94b:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b952:	c0 
c002b953:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b95a:	c0 
c002b95b:	c7 44 24 08 29 e0 02 	movl   $0xc002e029,0x8(%esp)
c002b962:	c0 
c002b963:	c7 44 24 04 23 00 00 	movl   $0x23,0x4(%esp)
c002b96a:	00 
c002b96b:	c7 04 24 54 0a 03 c0 	movl   $0xc0030a54,(%esp)
c002b972:	e8 4c d0 ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b977:	e8 12 56 ff ff       	call   c0020f8e <thread_get_priority>
c002b97c:	83 f8 1f             	cmp    $0x1f,%eax
c002b97f:	74 2c                	je     c002b9ad <test_priority_donate_sema+0x70>
c002b981:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b988:	c0 
c002b989:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b990:	c0 
c002b991:	c7 44 24 08 29 e0 02 	movl   $0xc002e029,0x8(%esp)
c002b998:	c0 
c002b999:	c7 44 24 04 26 00 00 	movl   $0x26,0x4(%esp)
c002b9a0:	00 
c002b9a1:	c7 04 24 54 0a 03 c0 	movl   $0xc0030a54,(%esp)
c002b9a8:	e8 16 d0 ff ff       	call   c00289c3 <debug_panic>
  lock_init (&ls.lock);
c002b9ad:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b9b1:	89 1c 24             	mov    %ebx,(%esp)
c002b9b4:	e8 54 74 ff ff       	call   c0022e0d <lock_init>
  sema_init (&ls.sema, 0);
c002b9b9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002b9c0:	00 
c002b9c1:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b9c5:	89 34 24             	mov    %esi,(%esp)
c002b9c8:	e8 69 71 ff ff       	call   c0022b36 <sema_init>
  thread_create ("low", PRI_DEFAULT + 1, l_thread_func, &ls);
c002b9cd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9d1:	c7 44 24 08 f1 b8 02 	movl   $0xc002b8f1,0x8(%esp)
c002b9d8:	c0 
c002b9d9:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b9e0:	00 
c002b9e1:	c7 04 24 35 0a 03 c0 	movl   $0xc0030a35,(%esp)
c002b9e8:	e8 94 5b ff ff       	call   c0021581 <thread_create>
  thread_create ("med", PRI_DEFAULT + 3, m_thread_func, &ls);
c002b9ed:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9f1:	c7 44 24 08 cf b8 02 	movl   $0xc002b8cf,0x8(%esp)
c002b9f8:	c0 
c002b9f9:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002ba00:	00 
c002ba01:	c7 04 24 39 0a 03 c0 	movl   $0xc0030a39,(%esp)
c002ba08:	e8 74 5b ff ff       	call   c0021581 <thread_create>
  thread_create ("high", PRI_DEFAULT + 5, h_thread_func, &ls);
c002ba0d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002ba11:	c7 44 24 08 8f b8 02 	movl   $0xc002b88f,0x8(%esp)
c002ba18:	c0 
c002ba19:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002ba20:	00 
c002ba21:	c7 04 24 b1 08 03 c0 	movl   $0xc00308b1,(%esp)
c002ba28:	e8 54 5b ff ff       	call   c0021581 <thread_create>
  sema_up (&ls.sema);
c002ba2d:	89 34 24             	mov    %esi,(%esp)
c002ba30:	e8 62 72 ff ff       	call   c0022c97 <sema_up>
  msg ("Main thread finished.");
c002ba35:	c7 04 24 3d 0a 03 c0 	movl   $0xc0030a3d,(%esp)
c002ba3c:	e8 3c ed ff ff       	call   c002a77d <msg>
}
c002ba41:	83 c4 64             	add    $0x64,%esp
c002ba44:	5b                   	pop    %ebx
c002ba45:	5e                   	pop    %esi
c002ba46:	c3                   	ret    

c002ba47 <acquire_thread_func>:
       PRI_DEFAULT - 10, thread_get_priority ());
}

static void
acquire_thread_func (void *lock_) 
{
c002ba47:	53                   	push   %ebx
c002ba48:	83 ec 18             	sub    $0x18,%esp
c002ba4b:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002ba4f:	89 1c 24             	mov    %ebx,(%esp)
c002ba52:	e8 53 74 ff ff       	call   c0022eaa <lock_acquire>
  msg ("acquire: got the lock");
c002ba57:	c7 04 24 7f 0a 03 c0 	movl   $0xc0030a7f,(%esp)
c002ba5e:	e8 1a ed ff ff       	call   c002a77d <msg>
  lock_release (lock);
c002ba63:	89 1c 24             	mov    %ebx,(%esp)
c002ba66:	e8 09 76 ff ff       	call   c0023074 <lock_release>
  msg ("acquire: done");
c002ba6b:	c7 04 24 95 0a 03 c0 	movl   $0xc0030a95,(%esp)
c002ba72:	e8 06 ed ff ff       	call   c002a77d <msg>
}
c002ba77:	83 c4 18             	add    $0x18,%esp
c002ba7a:	5b                   	pop    %ebx
c002ba7b:	c3                   	ret    

c002ba7c <test_priority_donate_lower>:
{
c002ba7c:	53                   	push   %ebx
c002ba7d:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002ba80:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002ba87:	74 2c                	je     c002bab5 <test_priority_donate_lower+0x39>
c002ba89:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002ba90:	c0 
c002ba91:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ba98:	c0 
c002ba99:	c7 44 24 08 43 e0 02 	movl   $0xc002e043,0x8(%esp)
c002baa0:	c0 
c002baa1:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002baa8:	00 
c002baa9:	c7 04 24 c8 0a 03 c0 	movl   $0xc0030ac8,(%esp)
c002bab0:	e8 0e cf ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002bab5:	e8 d4 54 ff ff       	call   c0020f8e <thread_get_priority>
c002baba:	83 f8 1f             	cmp    $0x1f,%eax
c002babd:	74 2c                	je     c002baeb <test_priority_donate_lower+0x6f>
c002babf:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002bac6:	c0 
c002bac7:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bace:	c0 
c002bacf:	c7 44 24 08 43 e0 02 	movl   $0xc002e043,0x8(%esp)
c002bad6:	c0 
c002bad7:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002bade:	00 
c002badf:	c7 04 24 c8 0a 03 c0 	movl   $0xc0030ac8,(%esp)
c002bae6:	e8 d8 ce ff ff       	call   c00289c3 <debug_panic>
  lock_init (&lock);
c002baeb:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002baef:	89 1c 24             	mov    %ebx,(%esp)
c002baf2:	e8 16 73 ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&lock);
c002baf7:	89 1c 24             	mov    %ebx,(%esp)
c002bafa:	e8 ab 73 ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("acquire", PRI_DEFAULT + 10, acquire_thread_func, &lock);
c002baff:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bb03:	c7 44 24 08 47 ba 02 	movl   $0xc002ba47,0x8(%esp)
c002bb0a:	c0 
c002bb0b:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb12:	00 
c002bb13:	c7 04 24 a3 0a 03 c0 	movl   $0xc0030aa3,(%esp)
c002bb1a:	e8 62 5a ff ff       	call   c0021581 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb1f:	e8 6a 54 ff ff       	call   c0020f8e <thread_get_priority>
c002bb24:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb28:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb2f:	00 
c002bb30:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002bb37:	e8 41 ec ff ff       	call   c002a77d <msg>
  msg ("Lowering base priority...");
c002bb3c:	c7 04 24 ab 0a 03 c0 	movl   $0xc0030aab,(%esp)
c002bb43:	e8 35 ec ff ff       	call   c002a77d <msg>
  thread_set_priority (PRI_DEFAULT - 10);
c002bb48:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
c002bb4f:	e8 9b 5b ff ff       	call   c00216ef <thread_set_priority>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb54:	e8 35 54 ff ff       	call   c0020f8e <thread_get_priority>
c002bb59:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb5d:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb64:	00 
c002bb65:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002bb6c:	e8 0c ec ff ff       	call   c002a77d <msg>
  lock_release (&lock);
c002bb71:	89 1c 24             	mov    %ebx,(%esp)
c002bb74:	e8 fb 74 ff ff       	call   c0023074 <lock_release>
  msg ("acquire must already have finished.");
c002bb79:	c7 04 24 f4 0a 03 c0 	movl   $0xc0030af4,(%esp)
c002bb80:	e8 f8 eb ff ff       	call   c002a77d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb85:	e8 04 54 ff ff       	call   c0020f8e <thread_get_priority>
c002bb8a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb8e:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bb95:	00 
c002bb96:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002bb9d:	e8 db eb ff ff       	call   c002a77d <msg>
}
c002bba2:	83 c4 58             	add    $0x58,%esp
c002bba5:	5b                   	pop    %ebx
c002bba6:	c3                   	ret    
c002bba7:	90                   	nop
c002bba8:	90                   	nop
c002bba9:	90                   	nop
c002bbaa:	90                   	nop
c002bbab:	90                   	nop
c002bbac:	90                   	nop
c002bbad:	90                   	nop
c002bbae:	90                   	nop
c002bbaf:	90                   	nop

c002bbb0 <simple_thread_func>:
    }
}

static void 
simple_thread_func (void *data_) 
{
c002bbb0:	56                   	push   %esi
c002bbb1:	53                   	push   %ebx
c002bbb2:	83 ec 14             	sub    $0x14,%esp
c002bbb5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002bbb9:	be 10 00 00 00       	mov    $0x10,%esi
  struct simple_thread_data *data = data_;
  int i;
  
  for (i = 0; i < ITER_CNT; i++) 
    {
      lock_acquire (data->lock);
c002bbbe:	8b 43 08             	mov    0x8(%ebx),%eax
c002bbc1:	89 04 24             	mov    %eax,(%esp)
c002bbc4:	e8 e1 72 ff ff       	call   c0022eaa <lock_acquire>
      *(*data->op)++ = data->id;
c002bbc9:	8b 53 0c             	mov    0xc(%ebx),%edx
c002bbcc:	8b 02                	mov    (%edx),%eax
c002bbce:	8d 48 04             	lea    0x4(%eax),%ecx
c002bbd1:	89 0a                	mov    %ecx,(%edx)
c002bbd3:	8b 13                	mov    (%ebx),%edx
c002bbd5:	89 10                	mov    %edx,(%eax)
      lock_release (data->lock);
c002bbd7:	8b 43 08             	mov    0x8(%ebx),%eax
c002bbda:	89 04 24             	mov    %eax,(%esp)
c002bbdd:	e8 92 74 ff ff       	call   c0023074 <lock_release>
      thread_yield ();
c002bbe2:	e8 f8 58 ff ff       	call   c00214df <thread_yield>
  for (i = 0; i < ITER_CNT; i++) 
c002bbe7:	83 ee 01             	sub    $0x1,%esi
c002bbea:	75 d2                	jne    c002bbbe <simple_thread_func+0xe>
    }
}
c002bbec:	83 c4 14             	add    $0x14,%esp
c002bbef:	5b                   	pop    %ebx
c002bbf0:	5e                   	pop    %esi
c002bbf1:	c3                   	ret    

c002bbf2 <test_priority_fifo>:
{
c002bbf2:	55                   	push   %ebp
c002bbf3:	57                   	push   %edi
c002bbf4:	56                   	push   %esi
c002bbf5:	53                   	push   %ebx
c002bbf6:	81 ec 6c 01 00 00    	sub    $0x16c,%esp
  ASSERT (!thread_mlfqs);
c002bbfc:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002bc03:	74 2c                	je     c002bc31 <test_priority_fifo+0x3f>
c002bc05:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002bc0c:	c0 
c002bc0d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bc14:	c0 
c002bc15:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bc1c:	c0 
c002bc1d:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002bc24:	00 
c002bc25:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bc2c:	e8 92 cd ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002bc31:	e8 58 53 ff ff       	call   c0020f8e <thread_get_priority>
c002bc36:	83 f8 1f             	cmp    $0x1f,%eax
c002bc39:	74 2c                	je     c002bc67 <test_priority_fifo+0x75>
c002bc3b:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002bc42:	c0 
c002bc43:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bc4a:	c0 
c002bc4b:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bc52:	c0 
c002bc53:	c7 44 24 04 2b 00 00 	movl   $0x2b,0x4(%esp)
c002bc5a:	00 
c002bc5b:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bc62:	e8 5c cd ff ff       	call   c00289c3 <debug_panic>
  msg ("%d threads will iterate %d times in the same order each time.",
c002bc67:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c002bc6e:	00 
c002bc6f:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bc76:	00 
c002bc77:	c7 04 24 6c 0b 03 c0 	movl   $0xc0030b6c,(%esp)
c002bc7e:	e8 fa ea ff ff       	call   c002a77d <msg>
  msg ("If the order varies then there is a bug.");
c002bc83:	c7 04 24 ac 0b 03 c0 	movl   $0xc0030bac,(%esp)
c002bc8a:	e8 ee ea ff ff       	call   c002a77d <msg>
  output = op = malloc (sizeof *output * THREAD_CNT * ITER_CNT * 2);
c002bc8f:	c7 04 24 00 08 00 00 	movl   $0x800,(%esp)
c002bc96:	e8 d9 7d ff ff       	call   c0023a74 <malloc>
c002bc9b:	89 c6                	mov    %eax,%esi
c002bc9d:	89 44 24 38          	mov    %eax,0x38(%esp)
  ASSERT (output != NULL);
c002bca1:	85 c0                	test   %eax,%eax
c002bca3:	75 2c                	jne    c002bcd1 <test_priority_fifo+0xdf>
c002bca5:	c7 44 24 10 4a 01 03 	movl   $0xc003014a,0x10(%esp)
c002bcac:	c0 
c002bcad:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bcb4:	c0 
c002bcb5:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bcbc:	c0 
c002bcbd:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c002bcc4:	00 
c002bcc5:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bccc:	e8 f2 cc ff ff       	call   c00289c3 <debug_panic>
  lock_init (&lock);
c002bcd1:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bcd5:	89 04 24             	mov    %eax,(%esp)
c002bcd8:	e8 30 71 ff ff       	call   c0022e0d <lock_init>
  thread_set_priority (PRI_DEFAULT + 2);
c002bcdd:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c002bce4:	e8 06 5a ff ff       	call   c00216ef <thread_set_priority>
c002bce9:	8d 5c 24 60          	lea    0x60(%esp),%ebx
  for (i = 0; i < THREAD_CNT; i++) 
c002bced:	bf 00 00 00 00       	mov    $0x0,%edi
      snprintf (name, sizeof name, "%d", i);
c002bcf2:	8d 6c 24 28          	lea    0x28(%esp),%ebp
c002bcf6:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002bcfa:	c7 44 24 08 60 01 03 	movl   $0xc0030160,0x8(%esp)
c002bd01:	c0 
c002bd02:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bd09:	00 
c002bd0a:	89 2c 24             	mov    %ebp,(%esp)
c002bd0d:	e8 5d b5 ff ff       	call   c002726f <snprintf>
      d->id = i;
c002bd12:	89 3b                	mov    %edi,(%ebx)
      d->iterations = 0;
c002bd14:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
      d->lock = &lock;
c002bd1b:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bd1f:	89 43 08             	mov    %eax,0x8(%ebx)
      d->op = &op;
c002bd22:	8d 44 24 38          	lea    0x38(%esp),%eax
c002bd26:	89 43 0c             	mov    %eax,0xc(%ebx)
      thread_create (name, PRI_DEFAULT + 1, simple_thread_func, d);
c002bd29:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bd2d:	c7 44 24 08 b0 bb 02 	movl   $0xc002bbb0,0x8(%esp)
c002bd34:	c0 
c002bd35:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bd3c:	00 
c002bd3d:	89 2c 24             	mov    %ebp,(%esp)
c002bd40:	e8 3c 58 ff ff       	call   c0021581 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002bd45:	83 c7 01             	add    $0x1,%edi
c002bd48:	83 c3 10             	add    $0x10,%ebx
c002bd4b:	83 ff 10             	cmp    $0x10,%edi
c002bd4e:	75 a6                	jne    c002bcf6 <test_priority_fifo+0x104>
  thread_set_priority (PRI_DEFAULT);
c002bd50:	c7 04 24 1f 00 00 00 	movl   $0x1f,(%esp)
c002bd57:	e8 93 59 ff ff       	call   c00216ef <thread_set_priority>
  ASSERT (lock.holder == NULL);
c002bd5c:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002bd61:	75 13                	jne    c002bd76 <test_priority_fifo+0x184>
  for (; output < op; output++) 
c002bd63:	3b 74 24 38          	cmp    0x38(%esp),%esi
c002bd67:	0f 83 be 00 00 00    	jae    c002be2b <test_priority_fifo+0x239>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd6d:	8b 3e                	mov    (%esi),%edi
c002bd6f:	83 ff 0f             	cmp    $0xf,%edi
c002bd72:	76 61                	jbe    c002bdd5 <test_priority_fifo+0x1e3>
c002bd74:	eb 33                	jmp    c002bda9 <test_priority_fifo+0x1b7>
  ASSERT (lock.holder == NULL);
c002bd76:	c7 44 24 10 18 0b 03 	movl   $0xc0030b18,0x10(%esp)
c002bd7d:	c0 
c002bd7e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bd85:	c0 
c002bd86:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bd8d:	c0 
c002bd8e:	c7 44 24 04 44 00 00 	movl   $0x44,0x4(%esp)
c002bd95:	00 
c002bd96:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bd9d:	e8 21 cc ff ff       	call   c00289c3 <debug_panic>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bda2:	8b 3e                	mov    (%esi),%edi
c002bda4:	83 ff 0f             	cmp    $0xf,%edi
c002bda7:	76 31                	jbe    c002bdda <test_priority_fifo+0x1e8>
c002bda9:	c7 44 24 10 d8 0b 03 	movl   $0xc0030bd8,0x10(%esp)
c002bdb0:	c0 
c002bdb1:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bdb8:	c0 
c002bdb9:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bdc0:	c0 
c002bdc1:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002bdc8:	00 
c002bdc9:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bdd0:	e8 ee cb ff ff       	call   c00289c3 <debug_panic>
c002bdd5:	bb 00 00 00 00       	mov    $0x0,%ebx
      d = data + *output;
c002bdda:	c1 e7 04             	shl    $0x4,%edi
c002bddd:	8d 44 24 60          	lea    0x60(%esp),%eax
c002bde1:	01 c7                	add    %eax,%edi
      if (cnt % THREAD_CNT == 0)
c002bde3:	f6 c3 0f             	test   $0xf,%bl
c002bde6:	75 0c                	jne    c002bdf4 <test_priority_fifo+0x202>
        printf ("(priority-fifo) iteration:");
c002bde8:	c7 04 24 2c 0b 03 c0 	movl   $0xc0030b2c,(%esp)
c002bdef:	e8 7a ad ff ff       	call   c0026b6e <printf>
      printf (" %d", d->id);
c002bdf4:	8b 07                	mov    (%edi),%eax
c002bdf6:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bdfa:	c7 04 24 5f 01 03 c0 	movl   $0xc003015f,(%esp)
c002be01:	e8 68 ad ff ff       	call   c0026b6e <printf>
      if (++cnt % THREAD_CNT == 0)
c002be06:	83 c3 01             	add    $0x1,%ebx
c002be09:	f6 c3 0f             	test   $0xf,%bl
c002be0c:	75 0c                	jne    c002be1a <test_priority_fifo+0x228>
        printf ("\n");
c002be0e:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002be15:	e8 42 e9 ff ff       	call   c002a75c <putchar>
      d->iterations++;
c002be1a:	83 47 04 01          	addl   $0x1,0x4(%edi)
  for (; output < op; output++) 
c002be1e:	83 c6 04             	add    $0x4,%esi
c002be21:	39 74 24 38          	cmp    %esi,0x38(%esp)
c002be25:	0f 87 77 ff ff ff    	ja     c002bda2 <test_priority_fifo+0x1b0>
}
c002be2b:	81 c4 6c 01 00 00    	add    $0x16c,%esp
c002be31:	5b                   	pop    %ebx
c002be32:	5e                   	pop    %esi
c002be33:	5f                   	pop    %edi
c002be34:	5d                   	pop    %ebp
c002be35:	c3                   	ret    

c002be36 <simple_thread_func>:
  msg ("The high-priority thread should have already completed.");
}

static void 
simple_thread_func (void *aux UNUSED) 
{
c002be36:	53                   	push   %ebx
c002be37:	83 ec 18             	sub    $0x18,%esp
  int i;
  
  for (i = 0; i < 5; i++) 
c002be3a:	bb 00 00 00 00       	mov    $0x0,%ebx
    {
      msg ("Thread %s iteration %d", thread_name (), i);
c002be3f:	e8 ad 50 ff ff       	call   c0020ef1 <thread_name>
c002be44:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002be48:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be4c:	c7 04 24 fd 0b 03 c0 	movl   $0xc0030bfd,(%esp)
c002be53:	e8 25 e9 ff ff       	call   c002a77d <msg>
      thread_yield ();
c002be58:	e8 82 56 ff ff       	call   c00214df <thread_yield>
  for (i = 0; i < 5; i++) 
c002be5d:	83 c3 01             	add    $0x1,%ebx
c002be60:	83 fb 05             	cmp    $0x5,%ebx
c002be63:	75 da                	jne    c002be3f <simple_thread_func+0x9>
    }
  msg ("Thread %s done!", thread_name ());
c002be65:	e8 87 50 ff ff       	call   c0020ef1 <thread_name>
c002be6a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be6e:	c7 04 24 14 0c 03 c0 	movl   $0xc0030c14,(%esp)
c002be75:	e8 03 e9 ff ff       	call   c002a77d <msg>
}
c002be7a:	83 c4 18             	add    $0x18,%esp
c002be7d:	5b                   	pop    %ebx
c002be7e:	c3                   	ret    

c002be7f <test_priority_preempt>:
{
c002be7f:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002be82:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002be89:	74 2c                	je     c002beb7 <test_priority_preempt+0x38>
c002be8b:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002be92:	c0 
c002be93:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002be9a:	c0 
c002be9b:	c7 44 24 08 71 e0 02 	movl   $0xc002e071,0x8(%esp)
c002bea2:	c0 
c002bea3:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002beaa:	00 
c002beab:	c7 04 24 34 0c 03 c0 	movl   $0xc0030c34,(%esp)
c002beb2:	e8 0c cb ff ff       	call   c00289c3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002beb7:	e8 d2 50 ff ff       	call   c0020f8e <thread_get_priority>
c002bebc:	83 f8 1f             	cmp    $0x1f,%eax
c002bebf:	74 2c                	je     c002beed <test_priority_preempt+0x6e>
c002bec1:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002bec8:	c0 
c002bec9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bed0:	c0 
c002bed1:	c7 44 24 08 71 e0 02 	movl   $0xc002e071,0x8(%esp)
c002bed8:	c0 
c002bed9:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002bee0:	00 
c002bee1:	c7 04 24 34 0c 03 c0 	movl   $0xc0030c34,(%esp)
c002bee8:	e8 d6 ca ff ff       	call   c00289c3 <debug_panic>
  thread_create ("high-priority", PRI_DEFAULT + 1, simple_thread_func, NULL);
c002beed:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bef4:	00 
c002bef5:	c7 44 24 08 36 be 02 	movl   $0xc002be36,0x8(%esp)
c002befc:	c0 
c002befd:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bf04:	00 
c002bf05:	c7 04 24 24 0c 03 c0 	movl   $0xc0030c24,(%esp)
c002bf0c:	e8 70 56 ff ff       	call   c0021581 <thread_create>
  msg ("The high-priority thread should have already completed.");
c002bf11:	c7 04 24 5c 0c 03 c0 	movl   $0xc0030c5c,(%esp)
c002bf18:	e8 60 e8 ff ff       	call   c002a77d <msg>
}
c002bf1d:	83 c4 2c             	add    $0x2c,%esp
c002bf20:	c3                   	ret    

c002bf21 <priority_sema_thread>:
    }
}

static void
priority_sema_thread (void *aux UNUSED) 
{
c002bf21:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&sema);
c002bf24:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bf2b:	e8 52 6c ff ff       	call   c0022b82 <sema_down>
  msg ("Thread %s woke up.", thread_name ());
c002bf30:	e8 bc 4f ff ff       	call   c0020ef1 <thread_name>
c002bf35:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bf39:	c7 04 24 30 04 03 c0 	movl   $0xc0030430,(%esp)
c002bf40:	e8 38 e8 ff ff       	call   c002a77d <msg>
}
c002bf45:	83 c4 1c             	add    $0x1c,%esp
c002bf48:	c3                   	ret    

c002bf49 <test_priority_sema>:
{
c002bf49:	55                   	push   %ebp
c002bf4a:	57                   	push   %edi
c002bf4b:	56                   	push   %esi
c002bf4c:	53                   	push   %ebx
c002bf4d:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002bf50:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002bf57:	74 2c                	je     c002bf85 <test_priority_sema+0x3c>
c002bf59:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002bf60:	c0 
c002bf61:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bf68:	c0 
c002bf69:	c7 44 24 08 87 e0 02 	movl   $0xc002e087,0x8(%esp)
c002bf70:	c0 
c002bf71:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bf78:	00 
c002bf79:	c7 04 24 ac 0c 03 c0 	movl   $0xc0030cac,(%esp)
c002bf80:	e8 3e ca ff ff       	call   c00289c3 <debug_panic>
  sema_init (&sema, 0);
c002bf85:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002bf8c:	00 
c002bf8d:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bf94:	e8 9d 6b ff ff       	call   c0022b36 <sema_init>
  thread_set_priority (PRI_MIN);
c002bf99:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002bfa0:	e8 4a 57 ff ff       	call   c00216ef <thread_set_priority>
c002bfa5:	bb 03 00 00 00       	mov    $0x3,%ebx
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bfaa:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002bfaf:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bfb3:	89 d8                	mov    %ebx,%eax
c002bfb5:	f7 ed                	imul   %ebp
c002bfb7:	c1 fa 02             	sar    $0x2,%edx
c002bfba:	89 d8                	mov    %ebx,%eax
c002bfbc:	c1 f8 1f             	sar    $0x1f,%eax
c002bfbf:	29 c2                	sub    %eax,%edx
c002bfc1:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002bfc4:	01 c0                	add    %eax,%eax
c002bfc6:	29 d8                	sub    %ebx,%eax
c002bfc8:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002bfcb:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002bfcf:	c7 44 24 08 43 04 03 	movl   $0xc0030443,0x8(%esp)
c002bfd6:	c0 
c002bfd7:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bfde:	00 
c002bfdf:	89 3c 24             	mov    %edi,(%esp)
c002bfe2:	e8 88 b2 ff ff       	call   c002726f <snprintf>
      thread_create (name, priority, priority_sema_thread, NULL);
c002bfe7:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bfee:	00 
c002bfef:	c7 44 24 08 21 bf 02 	movl   $0xc002bf21,0x8(%esp)
c002bff6:	c0 
c002bff7:	89 74 24 04          	mov    %esi,0x4(%esp)
c002bffb:	89 3c 24             	mov    %edi,(%esp)
c002bffe:	e8 7e 55 ff ff       	call   c0021581 <thread_create>
c002c003:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002c006:	83 fb 0d             	cmp    $0xd,%ebx
c002c009:	75 a8                	jne    c002bfb3 <test_priority_sema+0x6a>
c002c00b:	b3 0a                	mov    $0xa,%bl
      sema_up (&sema);
c002c00d:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002c014:	e8 7e 6c ff ff       	call   c0022c97 <sema_up>
      msg ("Back in main thread."); 
c002c019:	c7 04 24 94 0c 03 c0 	movl   $0xc0030c94,(%esp)
c002c020:	e8 58 e7 ff ff       	call   c002a77d <msg>
  for (i = 0; i < 10; i++) 
c002c025:	83 eb 01             	sub    $0x1,%ebx
c002c028:	75 e3                	jne    c002c00d <test_priority_sema+0xc4>
}
c002c02a:	83 c4 3c             	add    $0x3c,%esp
c002c02d:	5b                   	pop    %ebx
c002c02e:	5e                   	pop    %esi
c002c02f:	5f                   	pop    %edi
c002c030:	5d                   	pop    %ebp
c002c031:	c3                   	ret    

c002c032 <priority_condvar_thread>:
    }
}

static void
priority_condvar_thread (void *aux UNUSED) 
{
c002c032:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread %s starting.", thread_name ());
c002c035:	e8 b7 4e ff ff       	call   c0020ef1 <thread_name>
c002c03a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c03e:	c7 04 24 d0 0c 03 c0 	movl   $0xc0030cd0,(%esp)
c002c045:	e8 33 e7 ff ff       	call   c002a77d <msg>
  lock_acquire (&lock);
c002c04a:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c051:	e8 54 6e ff ff       	call   c0022eaa <lock_acquire>
  cond_wait (&condition, &lock);
c002c056:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c05d:	c0 
c002c05e:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c065:	e8 46 71 ff ff       	call   c00231b0 <cond_wait>
  msg ("Thread %s woke up.", thread_name ());
c002c06a:	e8 82 4e ff ff       	call   c0020ef1 <thread_name>
c002c06f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c073:	c7 04 24 30 04 03 c0 	movl   $0xc0030430,(%esp)
c002c07a:	e8 fe e6 ff ff       	call   c002a77d <msg>
  lock_release (&lock);
c002c07f:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c086:	e8 e9 6f ff ff       	call   c0023074 <lock_release>
}
c002c08b:	83 c4 1c             	add    $0x1c,%esp
c002c08e:	c3                   	ret    

c002c08f <test_priority_condvar>:
{
c002c08f:	55                   	push   %ebp
c002c090:	57                   	push   %edi
c002c091:	56                   	push   %esi
c002c092:	53                   	push   %ebx
c002c093:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002c096:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c09d:	74 2c                	je     c002c0cb <test_priority_condvar+0x3c>
c002c09f:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002c0a6:	c0 
c002c0a7:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c0ae:	c0 
c002c0af:	c7 44 24 08 9a e0 02 	movl   $0xc002e09a,0x8(%esp)
c002c0b6:	c0 
c002c0b7:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002c0be:	00 
c002c0bf:	c7 04 24 f4 0c 03 c0 	movl   $0xc0030cf4,(%esp)
c002c0c6:	e8 f8 c8 ff ff       	call   c00289c3 <debug_panic>
  lock_init (&lock);
c002c0cb:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c0d2:	e8 36 6d ff ff       	call   c0022e0d <lock_init>
  cond_init (&condition);
c002c0d7:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c0de:	e8 8a 70 ff ff       	call   c002316d <cond_init>
  thread_set_priority (PRI_MIN);
c002c0e3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c0ea:	e8 00 56 ff ff       	call   c00216ef <thread_set_priority>
c002c0ef:	bb 07 00 00 00       	mov    $0x7,%ebx
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0f4:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002c0f9:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0fd:	89 d8                	mov    %ebx,%eax
c002c0ff:	f7 ed                	imul   %ebp
c002c101:	c1 fa 02             	sar    $0x2,%edx
c002c104:	89 d8                	mov    %ebx,%eax
c002c106:	c1 f8 1f             	sar    $0x1f,%eax
c002c109:	29 c2                	sub    %eax,%edx
c002c10b:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002c10e:	01 c0                	add    %eax,%eax
c002c110:	29 d8                	sub    %ebx,%eax
c002c112:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002c115:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c119:	c7 44 24 08 43 04 03 	movl   $0xc0030443,0x8(%esp)
c002c120:	c0 
c002c121:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c128:	00 
c002c129:	89 3c 24             	mov    %edi,(%esp)
c002c12c:	e8 3e b1 ff ff       	call   c002726f <snprintf>
      thread_create (name, priority, priority_condvar_thread, NULL);
c002c131:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c138:	00 
c002c139:	c7 44 24 08 32 c0 02 	movl   $0xc002c032,0x8(%esp)
c002c140:	c0 
c002c141:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c145:	89 3c 24             	mov    %edi,(%esp)
c002c148:	e8 34 54 ff ff       	call   c0021581 <thread_create>
c002c14d:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002c150:	83 fb 11             	cmp    $0x11,%ebx
c002c153:	75 a8                	jne    c002c0fd <test_priority_condvar+0x6e>
c002c155:	b3 0a                	mov    $0xa,%bl
      lock_acquire (&lock);
c002c157:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c15e:	e8 47 6d ff ff       	call   c0022eaa <lock_acquire>
      msg ("Signaling...");
c002c163:	c7 04 24 e4 0c 03 c0 	movl   $0xc0030ce4,(%esp)
c002c16a:	e8 0e e6 ff ff       	call   c002a77d <msg>
      cond_signal (&condition, &lock);
c002c16f:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c176:	c0 
c002c177:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c17e:	e8 56 71 ff ff       	call   c00232d9 <cond_signal>
      lock_release (&lock);
c002c183:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c18a:	e8 e5 6e ff ff       	call   c0023074 <lock_release>
  for (i = 0; i < 10; i++) 
c002c18f:	83 eb 01             	sub    $0x1,%ebx
c002c192:	75 c3                	jne    c002c157 <test_priority_condvar+0xc8>
}
c002c194:	83 c4 3c             	add    $0x3c,%esp
c002c197:	5b                   	pop    %ebx
c002c198:	5e                   	pop    %esi
c002c199:	5f                   	pop    %edi
c002c19a:	5d                   	pop    %ebp
c002c19b:	c3                   	ret    

c002c19c <interloper_thread_func>:
                                         thread_get_priority ());
}

static void
interloper_thread_func (void *arg_ UNUSED)
{
c002c19c:	83 ec 1c             	sub    $0x1c,%esp
  msg ("%s finished.", thread_name ());
c002c19f:	e8 4d 4d ff ff       	call   c0020ef1 <thread_name>
c002c1a4:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1a8:	c7 04 24 1b 0d 03 c0 	movl   $0xc0030d1b,(%esp)
c002c1af:	e8 c9 e5 ff ff       	call   c002a77d <msg>
}
c002c1b4:	83 c4 1c             	add    $0x1c,%esp
c002c1b7:	c3                   	ret    

c002c1b8 <donor_thread_func>:
{
c002c1b8:	56                   	push   %esi
c002c1b9:	53                   	push   %ebx
c002c1ba:	83 ec 14             	sub    $0x14,%esp
c002c1bd:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (locks->first)
c002c1c1:	8b 43 04             	mov    0x4(%ebx),%eax
c002c1c4:	85 c0                	test   %eax,%eax
c002c1c6:	74 08                	je     c002c1d0 <donor_thread_func+0x18>
    lock_acquire (locks->first);
c002c1c8:	89 04 24             	mov    %eax,(%esp)
c002c1cb:	e8 da 6c ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (locks->second);
c002c1d0:	8b 03                	mov    (%ebx),%eax
c002c1d2:	89 04 24             	mov    %eax,(%esp)
c002c1d5:	e8 d0 6c ff ff       	call   c0022eaa <lock_acquire>
  msg ("%s got lock", thread_name ());
c002c1da:	e8 12 4d ff ff       	call   c0020ef1 <thread_name>
c002c1df:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1e3:	c7 04 24 28 0d 03 c0 	movl   $0xc0030d28,(%esp)
c002c1ea:	e8 8e e5 ff ff       	call   c002a77d <msg>
  lock_release (locks->second);
c002c1ef:	8b 03                	mov    (%ebx),%eax
c002c1f1:	89 04 24             	mov    %eax,(%esp)
c002c1f4:	e8 7b 6e ff ff       	call   c0023074 <lock_release>
  msg ("%s should have priority %d. Actual priority: %d", 
c002c1f9:	e8 90 4d ff ff       	call   c0020f8e <thread_get_priority>
c002c1fe:	89 c6                	mov    %eax,%esi
c002c200:	e8 ec 4c ff ff       	call   c0020ef1 <thread_name>
c002c205:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c209:	c7 44 24 08 15 00 00 	movl   $0x15,0x8(%esp)
c002c210:	00 
c002c211:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c215:	c7 04 24 50 0d 03 c0 	movl   $0xc0030d50,(%esp)
c002c21c:	e8 5c e5 ff ff       	call   c002a77d <msg>
  if (locks->first)
c002c221:	8b 43 04             	mov    0x4(%ebx),%eax
c002c224:	85 c0                	test   %eax,%eax
c002c226:	74 08                	je     c002c230 <donor_thread_func+0x78>
    lock_release (locks->first);
c002c228:	89 04 24             	mov    %eax,(%esp)
c002c22b:	e8 44 6e ff ff       	call   c0023074 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c230:	e8 59 4d ff ff       	call   c0020f8e <thread_get_priority>
c002c235:	89 c3                	mov    %eax,%ebx
c002c237:	e8 b5 4c ff ff       	call   c0020ef1 <thread_name>
c002c23c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c240:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c244:	c7 04 24 80 0d 03 c0 	movl   $0xc0030d80,(%esp)
c002c24b:	e8 2d e5 ff ff       	call   c002a77d <msg>
}
c002c250:	83 c4 14             	add    $0x14,%esp
c002c253:	5b                   	pop    %ebx
c002c254:	5e                   	pop    %esi
c002c255:	c3                   	ret    

c002c256 <test_priority_donate_chain>:
{
c002c256:	55                   	push   %ebp
c002c257:	57                   	push   %edi
c002c258:	56                   	push   %esi
c002c259:	53                   	push   %ebx
c002c25a:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
  ASSERT (!thread_mlfqs);
c002c260:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c267:	74 2c                	je     c002c295 <test_priority_donate_chain+0x3f>
c002c269:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002c270:	c0 
c002c271:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c278:	c0 
c002c279:	c7 44 24 08 b0 e0 02 	movl   $0xc002e0b0,0x8(%esp)
c002c280:	c0 
c002c281:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c002c288:	00 
c002c289:	c7 04 24 a0 0d 03 c0 	movl   $0xc0030da0,(%esp)
c002c290:	e8 2e c7 ff ff       	call   c00289c3 <debug_panic>
  thread_set_priority (PRI_MIN);
c002c295:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c29c:	e8 4e 54 ff ff       	call   c00216ef <thread_set_priority>
c002c2a1:	8d 5c 24 74          	lea    0x74(%esp),%ebx
c002c2a5:	8d b4 24 70 01 00 00 	lea    0x170(%esp),%esi
    lock_init (&locks[i]);
c002c2ac:	89 1c 24             	mov    %ebx,(%esp)
c002c2af:	e8 59 6b ff ff       	call   c0022e0d <lock_init>
c002c2b4:	83 c3 24             	add    $0x24,%ebx
  for (i = 0; i < NESTING_DEPTH - 1; i++)
c002c2b7:	39 f3                	cmp    %esi,%ebx
c002c2b9:	75 f1                	jne    c002c2ac <test_priority_donate_chain+0x56>
  lock_acquire (&locks[0]);
c002c2bb:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c2bf:	89 04 24             	mov    %eax,(%esp)
c002c2c2:	e8 e3 6b ff ff       	call   c0022eaa <lock_acquire>
  msg ("%s got lock.", thread_name ());
c002c2c7:	e8 25 4c ff ff       	call   c0020ef1 <thread_name>
c002c2cc:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c2d0:	c7 04 24 34 0d 03 c0 	movl   $0xc0030d34,(%esp)
c002c2d7:	e8 a1 e4 ff ff       	call   c002a77d <msg>
c002c2dc:	8d 84 24 98 00 00 00 	lea    0x98(%esp),%eax
c002c2e3:	89 44 24 14          	mov    %eax,0x14(%esp)
c002c2e7:	8d 74 24 40          	lea    0x40(%esp),%esi
c002c2eb:	bf 03 00 00 00       	mov    $0x3,%edi
  for (i = 1; i < NESTING_DEPTH; i++)
c002c2f0:	bb 01 00 00 00       	mov    $0x1,%ebx
      snprintf (name, sizeof name, "thread %d", i);
c002c2f5:	8d 6c 24 24          	lea    0x24(%esp),%ebp
c002c2f9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c2fd:	c7 44 24 08 59 01 03 	movl   $0xc0030159,0x8(%esp)
c002c304:	c0 
c002c305:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c30c:	00 
c002c30d:	89 2c 24             	mov    %ebp,(%esp)
c002c310:	e8 5a af ff ff       	call   c002726f <snprintf>
      lock_pairs[i].first = i < NESTING_DEPTH - 1 ? locks + i: NULL;
c002c315:	83 fb 06             	cmp    $0x6,%ebx
c002c318:	b8 00 00 00 00       	mov    $0x0,%eax
c002c31d:	8b 54 24 14          	mov    0x14(%esp),%edx
c002c321:	0f 4e c2             	cmovle %edx,%eax
c002c324:	89 06                	mov    %eax,(%esi)
c002c326:	89 d0                	mov    %edx,%eax
c002c328:	83 e8 24             	sub    $0x24,%eax
c002c32b:	89 46 fc             	mov    %eax,-0x4(%esi)
c002c32e:	8d 46 fc             	lea    -0x4(%esi),%eax
      thread_create (name, thread_priority, donor_thread_func, lock_pairs + i);
c002c331:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c335:	c7 44 24 08 b8 c1 02 	movl   $0xc002c1b8,0x8(%esp)
c002c33c:	c0 
c002c33d:	89 7c 24 18          	mov    %edi,0x18(%esp)
c002c341:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c345:	89 2c 24             	mov    %ebp,(%esp)
c002c348:	e8 34 52 ff ff       	call   c0021581 <thread_create>
      msg ("%s should have priority %d.  Actual priority: %d.",
c002c34d:	e8 3c 4c ff ff       	call   c0020f8e <thread_get_priority>
c002c352:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002c356:	e8 96 4b ff ff       	call   c0020ef1 <thread_name>
c002c35b:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c35f:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002c363:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c002c367:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002c36b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c36f:	c7 04 24 cc 0d 03 c0 	movl   $0xc0030dcc,(%esp)
c002c376:	e8 02 e4 ff ff       	call   c002a77d <msg>
      snprintf (name, sizeof name, "interloper %d", i);
c002c37b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c37f:	c7 44 24 08 41 0d 03 	movl   $0xc0030d41,0x8(%esp)
c002c386:	c0 
c002c387:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c38e:	00 
c002c38f:	89 2c 24             	mov    %ebp,(%esp)
c002c392:	e8 d8 ae ff ff       	call   c002726f <snprintf>
      thread_create (name, thread_priority - 1, interloper_thread_func, NULL);
c002c397:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c39e:	00 
c002c39f:	c7 44 24 08 9c c1 02 	movl   $0xc002c19c,0x8(%esp)
c002c3a6:	c0 
c002c3a7:	8d 47 ff             	lea    -0x1(%edi),%eax
c002c3aa:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c3ae:	89 2c 24             	mov    %ebp,(%esp)
c002c3b1:	e8 cb 51 ff ff       	call   c0021581 <thread_create>
  for (i = 1; i < NESTING_DEPTH; i++)
c002c3b6:	83 c3 01             	add    $0x1,%ebx
c002c3b9:	83 44 24 14 24       	addl   $0x24,0x14(%esp)
c002c3be:	83 c6 08             	add    $0x8,%esi
c002c3c1:	83 c7 03             	add    $0x3,%edi
c002c3c4:	83 fb 08             	cmp    $0x8,%ebx
c002c3c7:	0f 85 2c ff ff ff    	jne    c002c2f9 <test_priority_donate_chain+0xa3>
  lock_release (&locks[0]);
c002c3cd:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c3d1:	89 04 24             	mov    %eax,(%esp)
c002c3d4:	e8 9b 6c ff ff       	call   c0023074 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c3d9:	e8 b0 4b ff ff       	call   c0020f8e <thread_get_priority>
c002c3de:	89 c3                	mov    %eax,%ebx
c002c3e0:	e8 0c 4b ff ff       	call   c0020ef1 <thread_name>
c002c3e5:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c3e9:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c3ed:	c7 04 24 80 0d 03 c0 	movl   $0xc0030d80,(%esp)
c002c3f4:	e8 84 e3 ff ff       	call   c002a77d <msg>
}
c002c3f9:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002c3ff:	5b                   	pop    %ebx
c002c400:	5e                   	pop    %esi
c002c401:	5f                   	pop    %edi
c002c402:	5d                   	pop    %ebp
c002c403:	c3                   	ret    
c002c404:	90                   	nop
c002c405:	90                   	nop
c002c406:	90                   	nop
c002c407:	90                   	nop
c002c408:	90                   	nop
c002c409:	90                   	nop
c002c40a:	90                   	nop
c002c40b:	90                   	nop
c002c40c:	90                   	nop
c002c40d:	90                   	nop
c002c40e:	90                   	nop
c002c40f:	90                   	nop

c002c410 <test_mlfqs_load_1>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_mlfqs_load_1 (void) 
{
c002c410:	57                   	push   %edi
c002c411:	56                   	push   %esi
c002c412:	53                   	push   %ebx
c002c413:	83 ec 20             	sub    $0x20,%esp
  int64_t start_time;
  int elapsed;
  int load_avg;
  
  ASSERT (thread_mlfqs);
c002c416:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c41d:	75 2c                	jne    c002c44b <test_mlfqs_load_1+0x3b>
c002c41f:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002c426:	c0 
c002c427:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c42e:	c0 
c002c42f:	c7 44 24 08 cb e0 02 	movl   $0xc002e0cb,0x8(%esp)
c002c436:	c0 
c002c437:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002c43e:	00 
c002c43f:	c7 04 24 28 0e 03 c0 	movl   $0xc0030e28,(%esp)
c002c446:	e8 78 c5 ff ff       	call   c00289c3 <debug_panic>

  msg ("spinning for up to 45 seconds, please wait...");
c002c44b:	c7 04 24 4c 0e 03 c0 	movl   $0xc0030e4c,(%esp)
c002c452:	e8 26 e3 ff ff       	call   c002a77d <msg>

  start_time = timer_ticks ();
c002c457:	e8 f8 7d ff ff       	call   c0024254 <timer_ticks>
c002c45c:	89 44 24 18          	mov    %eax,0x18(%esp)
c002c460:	89 54 24 1c          	mov    %edx,0x1c(%esp)
    {
      load_avg = thread_get_load_avg ();
      ASSERT (load_avg >= 0);
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
      if (load_avg > 100)
        fail ("load average is %d.%02d "
c002c464:	bf 1f 85 eb 51       	mov    $0x51eb851f,%edi
      load_avg = thread_get_load_avg ();
c002c469:	e8 3e 4b ff ff       	call   c0020fac <thread_get_load_avg>
c002c46e:	89 c3                	mov    %eax,%ebx
      ASSERT (load_avg >= 0);
c002c470:	85 c0                	test   %eax,%eax
c002c472:	79 2c                	jns    c002c4a0 <test_mlfqs_load_1+0x90>
c002c474:	c7 44 24 10 fe 0d 03 	movl   $0xc0030dfe,0x10(%esp)
c002c47b:	c0 
c002c47c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c483:	c0 
c002c484:	c7 44 24 08 cb e0 02 	movl   $0xc002e0cb,0x8(%esp)
c002c48b:	c0 
c002c48c:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002c493:	00 
c002c494:	c7 04 24 28 0e 03 c0 	movl   $0xc0030e28,(%esp)
c002c49b:	e8 23 c5 ff ff       	call   c00289c3 <debug_panic>
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
c002c4a0:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c4a4:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c4a8:	89 04 24             	mov    %eax,(%esp)
c002c4ab:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c4af:	e8 cc 7d ff ff       	call   c0024280 <timer_elapsed>
c002c4b4:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c4bb:	00 
c002c4bc:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c4c3:	00 
c002c4c4:	89 04 24             	mov    %eax,(%esp)
c002c4c7:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c4cb:	e8 53 be ff ff       	call   c0028323 <__divdi3>
c002c4d0:	89 c6                	mov    %eax,%esi
      if (load_avg > 100)
c002c4d2:	83 fb 64             	cmp    $0x64,%ebx
c002c4d5:	7e 30                	jle    c002c507 <test_mlfqs_load_1+0xf7>
        fail ("load average is %d.%02d "
c002c4d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c4db:	89 d8                	mov    %ebx,%eax
c002c4dd:	f7 ef                	imul   %edi
c002c4df:	c1 fa 05             	sar    $0x5,%edx
c002c4e2:	89 d8                	mov    %ebx,%eax
c002c4e4:	c1 f8 1f             	sar    $0x1f,%eax
c002c4e7:	29 c2                	sub    %eax,%edx
c002c4e9:	6b c2 64             	imul   $0x64,%edx,%eax
c002c4ec:	29 c3                	sub    %eax,%ebx
c002c4ee:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c4f2:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c4f6:	c7 04 24 7c 0e 03 c0 	movl   $0xc0030e7c,(%esp)
c002c4fd:	e8 33 e3 ff ff       	call   c002a835 <fail>
c002c502:	e9 62 ff ff ff       	jmp    c002c469 <test_mlfqs_load_1+0x59>
              "but should be between 0 and 1 (after %d seconds)",
              load_avg / 100, load_avg % 100, elapsed);
      else if (load_avg > 50)
c002c507:	83 fb 32             	cmp    $0x32,%ebx
c002c50a:	7f 1b                	jg     c002c527 <test_mlfqs_load_1+0x117>
        break;
      else if (elapsed > 45)
c002c50c:	83 f8 2d             	cmp    $0x2d,%eax
c002c50f:	90                   	nop
c002c510:	0f 8e 53 ff ff ff    	jle    c002c469 <test_mlfqs_load_1+0x59>
        fail ("load average stayed below 0.5 for more than 45 seconds");
c002c516:	c7 04 24 c8 0e 03 c0 	movl   $0xc0030ec8,(%esp)
c002c51d:	e8 13 e3 ff ff       	call   c002a835 <fail>
c002c522:	e9 42 ff ff ff       	jmp    c002c469 <test_mlfqs_load_1+0x59>
    }

  if (elapsed < 38)
c002c527:	83 f8 25             	cmp    $0x25,%eax
c002c52a:	7f 10                	jg     c002c53c <test_mlfqs_load_1+0x12c>
    fail ("load average took only %d seconds to rise above 0.5", elapsed);
c002c52c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c530:	c7 04 24 00 0f 03 c0 	movl   $0xc0030f00,(%esp)
c002c537:	e8 f9 e2 ff ff       	call   c002a835 <fail>
  msg ("load average rose to 0.5 after %d seconds", elapsed);
c002c53c:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c540:	c7 04 24 34 0f 03 c0 	movl   $0xc0030f34,(%esp)
c002c547:	e8 31 e2 ff ff       	call   c002a77d <msg>

  msg ("sleeping for another 10 seconds, please wait...");
c002c54c:	c7 04 24 60 0f 03 c0 	movl   $0xc0030f60,(%esp)
c002c553:	e8 25 e2 ff ff       	call   c002a77d <msg>
  timer_sleep (TIMER_FREQ * 10);
c002c558:	c7 04 24 e8 03 00 00 	movl   $0x3e8,(%esp)
c002c55f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002c566:	00 
c002c567:	e8 30 7d ff ff       	call   c002429c <timer_sleep>

  load_avg = thread_get_load_avg ();
c002c56c:	e8 3b 4a ff ff       	call   c0020fac <thread_get_load_avg>
c002c571:	89 c3                	mov    %eax,%ebx
  if (load_avg < 0)
c002c573:	85 c0                	test   %eax,%eax
c002c575:	79 0c                	jns    c002c583 <test_mlfqs_load_1+0x173>
    fail ("load average fell below 0");
c002c577:	c7 04 24 0c 0e 03 c0 	movl   $0xc0030e0c,(%esp)
c002c57e:	e8 b2 e2 ff ff       	call   c002a835 <fail>
  if (load_avg > 50)
c002c583:	83 fb 32             	cmp    $0x32,%ebx
c002c586:	7e 0c                	jle    c002c594 <test_mlfqs_load_1+0x184>
    fail ("load average stayed above 0.5 for more than 10 seconds");
c002c588:	c7 04 24 90 0f 03 c0 	movl   $0xc0030f90,(%esp)
c002c58f:	e8 a1 e2 ff ff       	call   c002a835 <fail>
  msg ("load average fell back below 0.5 (to %d.%02d)",
c002c594:	ba 1f 85 eb 51       	mov    $0x51eb851f,%edx
c002c599:	89 d8                	mov    %ebx,%eax
c002c59b:	f7 ea                	imul   %edx
c002c59d:	c1 fa 05             	sar    $0x5,%edx
c002c5a0:	89 d8                	mov    %ebx,%eax
c002c5a2:	c1 f8 1f             	sar    $0x1f,%eax
c002c5a5:	29 c2                	sub    %eax,%edx
c002c5a7:	6b c2 64             	imul   $0x64,%edx,%eax
c002c5aa:	29 c3                	sub    %eax,%ebx
c002c5ac:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c5b0:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5b4:	c7 04 24 c8 0f 03 c0 	movl   $0xc0030fc8,(%esp)
c002c5bb:	e8 bd e1 ff ff       	call   c002a77d <msg>
       load_avg / 100, load_avg % 100);

  pass ();
c002c5c0:	e8 cc e2 ff ff       	call   c002a891 <pass>
}
c002c5c5:	83 c4 20             	add    $0x20,%esp
c002c5c8:	5b                   	pop    %ebx
c002c5c9:	5e                   	pop    %esi
c002c5ca:	5f                   	pop    %edi
c002c5cb:	c3                   	ret    
c002c5cc:	90                   	nop
c002c5cd:	90                   	nop
c002c5ce:	90                   	nop
c002c5cf:	90                   	nop

c002c5d0 <load_thread>:
    }
}

static void
load_thread (void *aux UNUSED) 
{
c002c5d0:	53                   	push   %ebx
c002c5d1:	83 ec 18             	sub    $0x18,%esp
  int64_t sleep_time = 10 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 60 * TIMER_FREQ;
  int64_t exit_time = spin_time + 60 * TIMER_FREQ;

  thread_set_nice (20);
c002c5d4:	c7 04 24 14 00 00 00 	movl   $0x14,(%esp)
c002c5db:	e8 c7 51 ff ff       	call   c00217a7 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c5e0:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5e5:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5eb:	89 04 24             	mov    %eax,(%esp)
c002c5ee:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5f2:	e8 89 7c ff ff       	call   c0024280 <timer_elapsed>
c002c5f7:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002c5fc:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c601:	29 c1                	sub    %eax,%ecx
c002c603:	19 d3                	sbb    %edx,%ebx
c002c605:	89 0c 24             	mov    %ecx,(%esp)
c002c608:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c60c:	e8 8b 7c ff ff       	call   c002429c <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c611:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c616:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c61c:	89 04 24             	mov    %eax,(%esp)
c002c61f:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c623:	e8 58 7c ff ff       	call   c0024280 <timer_elapsed>
c002c628:	85 d2                	test   %edx,%edx
c002c62a:	7f 0b                	jg     c002c637 <load_thread+0x67>
c002c62c:	85 d2                	test   %edx,%edx
c002c62e:	78 e1                	js     c002c611 <load_thread+0x41>
c002c630:	3d 57 1b 00 00       	cmp    $0x1b57,%eax
c002c635:	76 da                	jbe    c002c611 <load_thread+0x41>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c637:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c63c:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c642:	89 04 24             	mov    %eax,(%esp)
c002c645:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c649:	e8 32 7c ff ff       	call   c0024280 <timer_elapsed>
c002c64e:	b9 c8 32 00 00       	mov    $0x32c8,%ecx
c002c653:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c658:	29 c1                	sub    %eax,%ecx
c002c65a:	19 d3                	sbb    %edx,%ebx
c002c65c:	89 0c 24             	mov    %ecx,(%esp)
c002c65f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c663:	e8 34 7c ff ff       	call   c002429c <timer_sleep>
}
c002c668:	83 c4 18             	add    $0x18,%esp
c002c66b:	5b                   	pop    %ebx
c002c66c:	c3                   	ret    

c002c66d <test_mlfqs_load_60>:
{
c002c66d:	55                   	push   %ebp
c002c66e:	57                   	push   %edi
c002c66f:	56                   	push   %esi
c002c670:	53                   	push   %ebx
c002c671:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c674:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c67b:	75 2c                	jne    c002c6a9 <test_mlfqs_load_60+0x3c>
c002c67d:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002c684:	c0 
c002c685:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c68c:	c0 
c002c68d:	c7 44 24 08 dd e0 02 	movl   $0xc002e0dd,0x8(%esp)
c002c694:	c0 
c002c695:	c7 44 24 04 77 00 00 	movl   $0x77,0x4(%esp)
c002c69c:	00 
c002c69d:	c7 04 24 00 10 03 c0 	movl   $0xc0031000,(%esp)
c002c6a4:	e8 1a c3 ff ff       	call   c00289c3 <debug_panic>
  start_time = timer_ticks ();
c002c6a9:	e8 a6 7b ff ff       	call   c0024254 <timer_ticks>
c002c6ae:	a3 a8 7b 03 c0       	mov    %eax,0xc0037ba8
c002c6b3:	89 15 ac 7b 03 c0    	mov    %edx,0xc0037bac
  msg ("Starting %d niced load threads...", THREAD_CNT);
c002c6b9:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c6c0:	00 
c002c6c1:	c7 04 24 24 10 03 c0 	movl   $0xc0031024,(%esp)
c002c6c8:	e8 b0 e0 ff ff       	call   c002a77d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c6cd:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c6d2:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c6d6:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c6da:	c7 44 24 08 f6 0f 03 	movl   $0xc0030ff6,0x8(%esp)
c002c6e1:	c0 
c002c6e2:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c6e9:	00 
c002c6ea:	89 34 24             	mov    %esi,(%esp)
c002c6ed:	e8 7d ab ff ff       	call   c002726f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, NULL);
c002c6f2:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c6f9:	00 
c002c6fa:	c7 44 24 08 d0 c5 02 	movl   $0xc002c5d0,0x8(%esp)
c002c701:	c0 
c002c702:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c709:	00 
c002c70a:	89 34 24             	mov    %esi,(%esp)
c002c70d:	e8 6f 4e ff ff       	call   c0021581 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c712:	83 c3 01             	add    $0x1,%ebx
c002c715:	83 fb 3c             	cmp    $0x3c,%ebx
c002c718:	75 bc                	jne    c002c6d6 <test_mlfqs_load_60+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c71a:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c71f:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c725:	89 04 24             	mov    %eax,(%esp)
c002c728:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c72c:	e8 4f 7b ff ff       	call   c0024280 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c731:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c738:	00 
c002c739:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c740:	00 
c002c741:	89 04 24             	mov    %eax,(%esp)
c002c744:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c748:	e8 d6 bb ff ff       	call   c0028323 <__divdi3>
c002c74d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c751:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c755:	c7 04 24 48 10 03 c0 	movl   $0xc0031048,(%esp)
c002c75c:	e8 1c e0 ff ff       	call   c002a77d <msg>
c002c761:	b3 00                	mov    $0x0,%bl
c002c763:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c768:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c76d:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c772:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c776:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c77a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c77e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c782:	03 05 a8 7b 03 c0    	add    0xc0037ba8,%eax
c002c788:	13 15 ac 7b 03 c0    	adc    0xc0037bac,%edx
c002c78e:	89 c6                	mov    %eax,%esi
c002c790:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c792:	e8 bd 7a ff ff       	call   c0024254 <timer_ticks>
c002c797:	29 c6                	sub    %eax,%esi
c002c799:	19 d7                	sbb    %edx,%edi
c002c79b:	89 34 24             	mov    %esi,(%esp)
c002c79e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c7a2:	e8 f5 7a ff ff       	call   c002429c <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c7a7:	e8 00 48 ff ff       	call   c0020fac <thread_get_load_avg>
c002c7ac:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c7ae:	f7 ed                	imul   %ebp
c002c7b0:	c1 fa 05             	sar    $0x5,%edx
c002c7b3:	89 c8                	mov    %ecx,%eax
c002c7b5:	c1 f8 1f             	sar    $0x1f,%eax
c002c7b8:	29 c2                	sub    %eax,%edx
c002c7ba:	6b c2 64             	imul   $0x64,%edx,%eax
c002c7bd:	29 c1                	sub    %eax,%ecx
c002c7bf:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c7c3:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c7c7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c7cb:	c7 04 24 6c 10 03 c0 	movl   $0xc003106c,(%esp)
c002c7d2:	e8 a6 df ff ff       	call   c002a77d <msg>
c002c7d7:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c7de:	00 
c002c7df:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c7e4:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c7e7:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c7ed:	75 8b                	jne    c002c77a <test_mlfqs_load_60+0x10d>
}
c002c7ef:	83 c4 3c             	add    $0x3c,%esp
c002c7f2:	5b                   	pop    %ebx
c002c7f3:	5e                   	pop    %esi
c002c7f4:	5f                   	pop    %edi
c002c7f5:	5d                   	pop    %ebp
c002c7f6:	c3                   	ret    
c002c7f7:	90                   	nop
c002c7f8:	90                   	nop
c002c7f9:	90                   	nop
c002c7fa:	90                   	nop
c002c7fb:	90                   	nop
c002c7fc:	90                   	nop
c002c7fd:	90                   	nop
c002c7fe:	90                   	nop
c002c7ff:	90                   	nop

c002c800 <load_thread>:
    }
}

static void
load_thread (void *seq_no_) 
{
c002c800:	57                   	push   %edi
c002c801:	56                   	push   %esi
c002c802:	53                   	push   %ebx
c002c803:	83 ec 10             	sub    $0x10,%esp
  int seq_no = (int) seq_no_;
  int sleep_time = TIMER_FREQ * (10 + seq_no);
c002c806:	8b 44 24 20          	mov    0x20(%esp),%eax
c002c80a:	8d 70 0a             	lea    0xa(%eax),%esi
c002c80d:	6b f6 64             	imul   $0x64,%esi,%esi
  int spin_time = sleep_time + TIMER_FREQ * THREAD_CNT;
c002c810:	8d 9e 70 17 00 00    	lea    0x1770(%esi),%ebx
  int exit_time = TIMER_FREQ * (THREAD_CNT * 2);

  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c816:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c81b:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c821:	89 04 24             	mov    %eax,(%esp)
c002c824:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c828:	e8 53 7a ff ff       	call   c0024280 <timer_elapsed>
c002c82d:	89 f7                	mov    %esi,%edi
c002c82f:	c1 ff 1f             	sar    $0x1f,%edi
c002c832:	29 c6                	sub    %eax,%esi
c002c834:	19 d7                	sbb    %edx,%edi
c002c836:	89 34 24             	mov    %esi,(%esp)
c002c839:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c83d:	e8 5a 7a ff ff       	call   c002429c <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c842:	89 df                	mov    %ebx,%edi
c002c844:	c1 ff 1f             	sar    $0x1f,%edi
c002c847:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c84c:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c852:	89 04 24             	mov    %eax,(%esp)
c002c855:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c859:	e8 22 7a ff ff       	call   c0024280 <timer_elapsed>
c002c85e:	39 fa                	cmp    %edi,%edx
c002c860:	7f 06                	jg     c002c868 <load_thread+0x68>
c002c862:	7c e3                	jl     c002c847 <load_thread+0x47>
c002c864:	39 d8                	cmp    %ebx,%eax
c002c866:	72 df                	jb     c002c847 <load_thread+0x47>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c868:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c86d:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c873:	89 04 24             	mov    %eax,(%esp)
c002c876:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c87a:	e8 01 7a ff ff       	call   c0024280 <timer_elapsed>
c002c87f:	b9 e0 2e 00 00       	mov    $0x2ee0,%ecx
c002c884:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c889:	29 c1                	sub    %eax,%ecx
c002c88b:	19 d3                	sbb    %edx,%ebx
c002c88d:	89 0c 24             	mov    %ecx,(%esp)
c002c890:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c894:	e8 03 7a ff ff       	call   c002429c <timer_sleep>
}
c002c899:	83 c4 10             	add    $0x10,%esp
c002c89c:	5b                   	pop    %ebx
c002c89d:	5e                   	pop    %esi
c002c89e:	5f                   	pop    %edi
c002c89f:	c3                   	ret    

c002c8a0 <test_mlfqs_load_avg>:
{
c002c8a0:	55                   	push   %ebp
c002c8a1:	57                   	push   %edi
c002c8a2:	56                   	push   %esi
c002c8a3:	53                   	push   %ebx
c002c8a4:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c8a7:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c8ae:	75 2c                	jne    c002c8dc <test_mlfqs_load_avg+0x3c>
c002c8b0:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002c8b7:	c0 
c002c8b8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c8bf:	c0 
c002c8c0:	c7 44 24 08 f0 e0 02 	movl   $0xc002e0f0,0x8(%esp)
c002c8c7:	c0 
c002c8c8:	c7 44 24 04 82 00 00 	movl   $0x82,0x4(%esp)
c002c8cf:	00 
c002c8d0:	c7 04 24 b0 10 03 c0 	movl   $0xc00310b0,(%esp)
c002c8d7:	e8 e7 c0 ff ff       	call   c00289c3 <debug_panic>
  start_time = timer_ticks ();
c002c8dc:	e8 73 79 ff ff       	call   c0024254 <timer_ticks>
c002c8e1:	a3 b0 7b 03 c0       	mov    %eax,0xc0037bb0
c002c8e6:	89 15 b4 7b 03 c0    	mov    %edx,0xc0037bb4
  msg ("Starting %d load threads...", THREAD_CNT);
c002c8ec:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c8f3:	00 
c002c8f4:	c7 04 24 94 10 03 c0 	movl   $0xc0031094,(%esp)
c002c8fb:	e8 7d de ff ff       	call   c002a77d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c900:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c905:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c909:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c90d:	c7 44 24 08 f6 0f 03 	movl   $0xc0030ff6,0x8(%esp)
c002c914:	c0 
c002c915:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c91c:	00 
c002c91d:	89 34 24             	mov    %esi,(%esp)
c002c920:	e8 4a a9 ff ff       	call   c002726f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, (void *) i);
c002c925:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c929:	c7 44 24 08 00 c8 02 	movl   $0xc002c800,0x8(%esp)
c002c930:	c0 
c002c931:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c938:	00 
c002c939:	89 34 24             	mov    %esi,(%esp)
c002c93c:	e8 40 4c ff ff       	call   c0021581 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c941:	83 c3 01             	add    $0x1,%ebx
c002c944:	83 fb 3c             	cmp    $0x3c,%ebx
c002c947:	75 c0                	jne    c002c909 <test_mlfqs_load_avg+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c949:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c94e:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c954:	89 04 24             	mov    %eax,(%esp)
c002c957:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c95b:	e8 20 79 ff ff       	call   c0024280 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c960:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c967:	00 
c002c968:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c96f:	00 
c002c970:	89 04 24             	mov    %eax,(%esp)
c002c973:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c977:	e8 a7 b9 ff ff       	call   c0028323 <__divdi3>
c002c97c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c980:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c984:	c7 04 24 48 10 03 c0 	movl   $0xc0031048,(%esp)
c002c98b:	e8 ed dd ff ff       	call   c002a77d <msg>
  thread_set_nice (-20);
c002c990:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002c997:	e8 0b 4e ff ff       	call   c00217a7 <thread_set_nice>
c002c99c:	b3 00                	mov    $0x0,%bl
c002c99e:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c9a3:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c9a8:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c9ad:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c9b1:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c9b5:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c9b9:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c9bd:	03 05 b0 7b 03 c0    	add    0xc0037bb0,%eax
c002c9c3:	13 15 b4 7b 03 c0    	adc    0xc0037bb4,%edx
c002c9c9:	89 c6                	mov    %eax,%esi
c002c9cb:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c9cd:	e8 82 78 ff ff       	call   c0024254 <timer_ticks>
c002c9d2:	29 c6                	sub    %eax,%esi
c002c9d4:	19 d7                	sbb    %edx,%edi
c002c9d6:	89 34 24             	mov    %esi,(%esp)
c002c9d9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c9dd:	e8 ba 78 ff ff       	call   c002429c <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c9e2:	e8 c5 45 ff ff       	call   c0020fac <thread_get_load_avg>
c002c9e7:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c9e9:	f7 ed                	imul   %ebp
c002c9eb:	c1 fa 05             	sar    $0x5,%edx
c002c9ee:	89 c8                	mov    %ecx,%eax
c002c9f0:	c1 f8 1f             	sar    $0x1f,%eax
c002c9f3:	29 c2                	sub    %eax,%edx
c002c9f5:	6b c2 64             	imul   $0x64,%edx,%eax
c002c9f8:	29 c1                	sub    %eax,%ecx
c002c9fa:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c9fe:	89 54 24 08          	mov    %edx,0x8(%esp)
c002ca02:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002ca06:	c7 04 24 6c 10 03 c0 	movl   $0xc003106c,(%esp)
c002ca0d:	e8 6b dd ff ff       	call   c002a77d <msg>
c002ca12:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002ca19:	00 
c002ca1a:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002ca1f:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002ca22:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002ca28:	75 8b                	jne    c002c9b5 <test_mlfqs_load_avg+0x115>
}
c002ca2a:	83 c4 3c             	add    $0x3c,%esp
c002ca2d:	5b                   	pop    %ebx
c002ca2e:	5e                   	pop    %esi
c002ca2f:	5f                   	pop    %edi
c002ca30:	5d                   	pop    %ebp
c002ca31:	c3                   	ret    

c002ca32 <test_mlfqs_recent_1>:
/* Sensitive to assumption that recent_cpu updates happen exactly
   when timer_ticks() % TIMER_FREQ == 0. */

void
test_mlfqs_recent_1 (void) 
{
c002ca32:	55                   	push   %ebp
c002ca33:	57                   	push   %edi
c002ca34:	56                   	push   %esi
c002ca35:	53                   	push   %ebx
c002ca36:	83 ec 2c             	sub    $0x2c,%esp
  int64_t start_time;
  int last_elapsed = 0;
  
  ASSERT (thread_mlfqs);
c002ca39:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002ca40:	75 2c                	jne    c002ca6e <test_mlfqs_recent_1+0x3c>
c002ca42:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002ca49:	c0 
c002ca4a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ca51:	c0 
c002ca52:	c7 44 24 08 04 e1 02 	movl   $0xc002e104,0x8(%esp)
c002ca59:	c0 
c002ca5a:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c002ca61:	00 
c002ca62:	c7 04 24 d8 10 03 c0 	movl   $0xc00310d8,(%esp)
c002ca69:	e8 55 bf ff ff       	call   c00289c3 <debug_panic>

  do 
    {
      msg ("Sleeping 10 seconds to allow recent_cpu to decay, please wait...");
c002ca6e:	c7 04 24 00 11 03 c0 	movl   $0xc0031100,(%esp)
c002ca75:	e8 03 dd ff ff       	call   c002a77d <msg>
      start_time = timer_ticks ();
c002ca7a:	e8 d5 77 ff ff       	call   c0024254 <timer_ticks>
c002ca7f:	89 c7                	mov    %eax,%edi
c002ca81:	89 d5                	mov    %edx,%ebp
      timer_sleep (DIV_ROUND_UP (start_time, TIMER_FREQ) - start_time
c002ca83:	83 c0 63             	add    $0x63,%eax
c002ca86:	83 d2 00             	adc    $0x0,%edx
c002ca89:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002ca90:	00 
c002ca91:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002ca98:	00 
c002ca99:	89 04 24             	mov    %eax,(%esp)
c002ca9c:	89 54 24 04          	mov    %edx,0x4(%esp)
c002caa0:	e8 7e b8 ff ff       	call   c0028323 <__divdi3>
c002caa5:	29 f8                	sub    %edi,%eax
c002caa7:	19 ea                	sbb    %ebp,%edx
c002caa9:	05 e8 03 00 00       	add    $0x3e8,%eax
c002caae:	83 d2 00             	adc    $0x0,%edx
c002cab1:	89 04 24             	mov    %eax,(%esp)
c002cab4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cab8:	e8 df 77 ff ff       	call   c002429c <timer_sleep>
                   + 10 * TIMER_FREQ);
    }
  while (thread_get_recent_cpu () > 700);
c002cabd:	e8 00 45 ff ff       	call   c0020fc2 <thread_get_recent_cpu>
c002cac2:	3d bc 02 00 00       	cmp    $0x2bc,%eax
c002cac7:	7f a5                	jg     c002ca6e <test_mlfqs_recent_1+0x3c>

  start_time = timer_ticks ();
c002cac9:	e8 86 77 ff ff       	call   c0024254 <timer_ticks>
c002cace:	89 44 24 18          	mov    %eax,0x18(%esp)
c002cad2:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  int last_elapsed = 0;
c002cad6:	be 00 00 00 00       	mov    $0x0,%esi
  for (;;) 
    {
      int elapsed = timer_elapsed (start_time);
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002cadb:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002cae0:	eb 02                	jmp    c002cae4 <test_mlfqs_recent_1+0xb2>
c002cae2:	89 de                	mov    %ebx,%esi
      int elapsed = timer_elapsed (start_time);
c002cae4:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cae8:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002caec:	89 04 24             	mov    %eax,(%esp)
c002caef:	89 54 24 04          	mov    %edx,0x4(%esp)
c002caf3:	e8 88 77 ff ff       	call   c0024280 <timer_elapsed>
c002caf8:	89 c3                	mov    %eax,%ebx
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002cafa:	f7 ed                	imul   %ebp
c002cafc:	c1 fa 06             	sar    $0x6,%edx
c002caff:	89 d8                	mov    %ebx,%eax
c002cb01:	c1 f8 1f             	sar    $0x1f,%eax
c002cb04:	29 c2                	sub    %eax,%edx
c002cb06:	69 d2 c8 00 00 00    	imul   $0xc8,%edx,%edx
c002cb0c:	39 d3                	cmp    %edx,%ebx
c002cb0e:	75 d2                	jne    c002cae2 <test_mlfqs_recent_1+0xb0>
c002cb10:	39 de                	cmp    %ebx,%esi
c002cb12:	7d ce                	jge    c002cae2 <test_mlfqs_recent_1+0xb0>
        {
          int recent_cpu = thread_get_recent_cpu ();
c002cb14:	e8 a9 44 ff ff       	call   c0020fc2 <thread_get_recent_cpu>
c002cb19:	89 c6                	mov    %eax,%esi
          int load_avg = thread_get_load_avg ();
c002cb1b:	e8 8c 44 ff ff       	call   c0020fac <thread_get_load_avg>
c002cb20:	89 c1                	mov    %eax,%ecx
          int elapsed_seconds = elapsed / TIMER_FREQ;
c002cb22:	89 d8                	mov    %ebx,%eax
c002cb24:	f7 ed                	imul   %ebp
c002cb26:	89 d7                	mov    %edx,%edi
c002cb28:	c1 ff 05             	sar    $0x5,%edi
c002cb2b:	89 d8                	mov    %ebx,%eax
c002cb2d:	c1 f8 1f             	sar    $0x1f,%eax
c002cb30:	29 c7                	sub    %eax,%edi
          msg ("After %d seconds, recent_cpu is %d.%02d, load_avg is %d.%02d.",
c002cb32:	89 c8                	mov    %ecx,%eax
c002cb34:	f7 ed                	imul   %ebp
c002cb36:	c1 fa 05             	sar    $0x5,%edx
c002cb39:	89 c8                	mov    %ecx,%eax
c002cb3b:	c1 f8 1f             	sar    $0x1f,%eax
c002cb3e:	29 c2                	sub    %eax,%edx
c002cb40:	6b c2 64             	imul   $0x64,%edx,%eax
c002cb43:	29 c1                	sub    %eax,%ecx
c002cb45:	89 4c 24 14          	mov    %ecx,0x14(%esp)
c002cb49:	89 54 24 10          	mov    %edx,0x10(%esp)
c002cb4d:	89 f0                	mov    %esi,%eax
c002cb4f:	f7 ed                	imul   %ebp
c002cb51:	c1 fa 05             	sar    $0x5,%edx
c002cb54:	89 f0                	mov    %esi,%eax
c002cb56:	c1 f8 1f             	sar    $0x1f,%eax
c002cb59:	29 c2                	sub    %eax,%edx
c002cb5b:	6b c2 64             	imul   $0x64,%edx,%eax
c002cb5e:	29 c6                	sub    %eax,%esi
c002cb60:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002cb64:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cb68:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002cb6c:	c7 04 24 44 11 03 c0 	movl   $0xc0031144,(%esp)
c002cb73:	e8 05 dc ff ff       	call   c002a77d <msg>
               elapsed_seconds,
               recent_cpu / 100, recent_cpu % 100,
               load_avg / 100, load_avg % 100);
          if (elapsed_seconds >= 180)
c002cb78:	81 ff b3 00 00 00    	cmp    $0xb3,%edi
c002cb7e:	0f 8e 5e ff ff ff    	jle    c002cae2 <test_mlfqs_recent_1+0xb0>
            break;
        } 
      last_elapsed = elapsed;
    }
}
c002cb84:	83 c4 2c             	add    $0x2c,%esp
c002cb87:	5b                   	pop    %ebx
c002cb88:	5e                   	pop    %esi
c002cb89:	5f                   	pop    %edi
c002cb8a:	5d                   	pop    %ebp
c002cb8b:	c3                   	ret    
c002cb8c:	90                   	nop
c002cb8d:	90                   	nop
c002cb8e:	90                   	nop
c002cb8f:	90                   	nop

c002cb90 <test_mlfqs_fair>:

static void load_thread (void *aux);

static void
test_mlfqs_fair (int thread_cnt, int nice_min, int nice_step)
{
c002cb90:	55                   	push   %ebp
c002cb91:	57                   	push   %edi
c002cb92:	56                   	push   %esi
c002cb93:	53                   	push   %ebx
c002cb94:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
c002cb9a:	89 4c 24 14          	mov    %ecx,0x14(%esp)
  struct thread_info info[MAX_THREAD_CNT];
  int64_t start_time;
  int nice;
  int i;

  ASSERT (thread_mlfqs);
c002cb9e:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002cba5:	75 2c                	jne    c002cbd3 <test_mlfqs_fair+0x43>
c002cba7:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002cbae:	c0 
c002cbaf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cbb6:	c0 
c002cbb7:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cbbe:	c0 
c002cbbf:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
c002cbc6:	00 
c002cbc7:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cbce:	e8 f0 bd ff ff       	call   c00289c3 <debug_panic>
c002cbd3:	89 c5                	mov    %eax,%ebp
c002cbd5:	89 d7                	mov    %edx,%edi
  ASSERT (thread_cnt <= MAX_THREAD_CNT);
c002cbd7:	83 f8 14             	cmp    $0x14,%eax
c002cbda:	7e 2c                	jle    c002cc08 <test_mlfqs_fair+0x78>
c002cbdc:	c7 44 24 10 82 11 03 	movl   $0xc0031182,0x10(%esp)
c002cbe3:	c0 
c002cbe4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cbeb:	c0 
c002cbec:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cbf3:	c0 
c002cbf4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c002cbfb:	00 
c002cbfc:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cc03:	e8 bb bd ff ff       	call   c00289c3 <debug_panic>
  ASSERT (nice_min >= -10);
c002cc08:	83 fa f6             	cmp    $0xfffffff6,%edx
c002cc0b:	7d 2c                	jge    c002cc39 <test_mlfqs_fair+0xa9>
c002cc0d:	c7 44 24 10 9f 11 03 	movl   $0xc003119f,0x10(%esp)
c002cc14:	c0 
c002cc15:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cc1c:	c0 
c002cc1d:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cc24:	c0 
c002cc25:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002cc2c:	00 
c002cc2d:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cc34:	e8 8a bd ff ff       	call   c00289c3 <debug_panic>
  ASSERT (nice_step >= 0);
c002cc39:	83 7c 24 14 00       	cmpl   $0x0,0x14(%esp)
c002cc3e:	79 2c                	jns    c002cc6c <test_mlfqs_fair+0xdc>
c002cc40:	c7 44 24 10 af 11 03 	movl   $0xc00311af,0x10(%esp)
c002cc47:	c0 
c002cc48:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cc4f:	c0 
c002cc50:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cc57:	c0 
c002cc58:	c7 44 24 04 4c 00 00 	movl   $0x4c,0x4(%esp)
c002cc5f:	00 
c002cc60:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cc67:	e8 57 bd ff ff       	call   c00289c3 <debug_panic>
  ASSERT (nice_min + nice_step * (thread_cnt - 1) <= 20);
c002cc6c:	8d 40 ff             	lea    -0x1(%eax),%eax
c002cc6f:	0f af 44 24 14       	imul   0x14(%esp),%eax
c002cc74:	01 d0                	add    %edx,%eax
c002cc76:	83 f8 14             	cmp    $0x14,%eax
c002cc79:	7e 2c                	jle    c002cca7 <test_mlfqs_fair+0x117>
c002cc7b:	c7 44 24 10 18 12 03 	movl   $0xc0031218,0x10(%esp)
c002cc82:	c0 
c002cc83:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cc8a:	c0 
c002cc8b:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cc92:	c0 
c002cc93:	c7 44 24 04 4d 00 00 	movl   $0x4d,0x4(%esp)
c002cc9a:	00 
c002cc9b:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cca2:	e8 1c bd ff ff       	call   c00289c3 <debug_panic>

  thread_set_nice (-20);
c002cca7:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002ccae:	e8 f4 4a ff ff       	call   c00217a7 <thread_set_nice>

  start_time = timer_ticks ();
c002ccb3:	e8 9c 75 ff ff       	call   c0024254 <timer_ticks>
c002ccb8:	89 44 24 18          	mov    %eax,0x18(%esp)
c002ccbc:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  msg ("Starting %d threads...", thread_cnt);
c002ccc0:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002ccc4:	c7 04 24 be 11 03 c0 	movl   $0xc00311be,(%esp)
c002cccb:	e8 ad da ff ff       	call   c002a77d <msg>
  nice = nice_min;
  for (i = 0; i < thread_cnt; i++) 
c002ccd0:	85 ed                	test   %ebp,%ebp
c002ccd2:	0f 8e e1 00 00 00    	jle    c002cdb9 <test_mlfqs_fair+0x229>
c002ccd8:	8d 5c 24 30          	lea    0x30(%esp),%ebx
c002ccdc:	be 00 00 00 00       	mov    $0x0,%esi
    {
      struct thread_info *ti = &info[i];
      char name[16];

      ti->start_time = start_time;
c002cce1:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cce5:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cce9:	89 03                	mov    %eax,(%ebx)
c002cceb:	89 53 04             	mov    %edx,0x4(%ebx)
      ti->tick_count = 0;
c002ccee:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
      ti->nice = nice;
c002ccf5:	89 7b 0c             	mov    %edi,0xc(%ebx)

      snprintf(name, sizeof name, "load %d", i);
c002ccf8:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ccfc:	c7 44 24 08 f6 0f 03 	movl   $0xc0030ff6,0x8(%esp)
c002cd03:	c0 
c002cd04:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002cd0b:	00 
c002cd0c:	8d 44 24 20          	lea    0x20(%esp),%eax
c002cd10:	89 04 24             	mov    %eax,(%esp)
c002cd13:	e8 57 a5 ff ff       	call   c002726f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, ti);
c002cd18:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cd1c:	c7 44 24 08 0c ce 02 	movl   $0xc002ce0c,0x8(%esp)
c002cd23:	c0 
c002cd24:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cd2b:	00 
c002cd2c:	8d 44 24 20          	lea    0x20(%esp),%eax
c002cd30:	89 04 24             	mov    %eax,(%esp)
c002cd33:	e8 49 48 ff ff       	call   c0021581 <thread_create>

      nice += nice_step;
c002cd38:	03 7c 24 14          	add    0x14(%esp),%edi
  for (i = 0; i < thread_cnt; i++) 
c002cd3c:	83 c6 01             	add    $0x1,%esi
c002cd3f:	83 c3 10             	add    $0x10,%ebx
c002cd42:	39 ee                	cmp    %ebp,%esi
c002cd44:	75 9b                	jne    c002cce1 <test_mlfqs_fair+0x151>
    }
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cd46:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cd4a:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cd4e:	89 04 24             	mov    %eax,(%esp)
c002cd51:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cd55:	e8 26 75 ff ff       	call   c0024280 <timer_elapsed>
c002cd5a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cd5e:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd62:	c7 04 24 48 12 03 c0 	movl   $0xc0031248,(%esp)
c002cd69:	e8 0f da ff ff       	call   c002a77d <msg>

  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cd6e:	c7 04 24 6c 12 03 c0 	movl   $0xc003126c,(%esp)
c002cd75:	e8 03 da ff ff       	call   c002a77d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cd7a:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cd81:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cd88:	00 
c002cd89:	e8 0e 75 ff ff       	call   c002429c <timer_sleep>
  
  for (i = 0; i < thread_cnt; i++)
c002cd8e:	bb 00 00 00 00       	mov    $0x0,%ebx
c002cd93:	89 d8                	mov    %ebx,%eax
c002cd95:	c1 e0 04             	shl    $0x4,%eax
    msg ("Thread %d received %d ticks.", i, info[i].tick_count);
c002cd98:	8b 44 04 38          	mov    0x38(%esp,%eax,1),%eax
c002cd9c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002cda0:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002cda4:	c7 04 24 d5 11 03 c0 	movl   $0xc00311d5,(%esp)
c002cdab:	e8 cd d9 ff ff       	call   c002a77d <msg>
  for (i = 0; i < thread_cnt; i++)
c002cdb0:	83 c3 01             	add    $0x1,%ebx
c002cdb3:	39 eb                	cmp    %ebp,%ebx
c002cdb5:	75 dc                	jne    c002cd93 <test_mlfqs_fair+0x203>
c002cdb7:	eb 48                	jmp    c002ce01 <test_mlfqs_fair+0x271>
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cdb9:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cdbd:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cdc1:	89 04 24             	mov    %eax,(%esp)
c002cdc4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cdc8:	e8 b3 74 ff ff       	call   c0024280 <timer_elapsed>
c002cdcd:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cdd1:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cdd5:	c7 04 24 48 12 03 c0 	movl   $0xc0031248,(%esp)
c002cddc:	e8 9c d9 ff ff       	call   c002a77d <msg>
  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cde1:	c7 04 24 6c 12 03 c0 	movl   $0xc003126c,(%esp)
c002cde8:	e8 90 d9 ff ff       	call   c002a77d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cded:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cdf4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cdfb:	00 
c002cdfc:	e8 9b 74 ff ff       	call   c002429c <timer_sleep>
}
c002ce01:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002ce07:	5b                   	pop    %ebx
c002ce08:	5e                   	pop    %esi
c002ce09:	5f                   	pop    %edi
c002ce0a:	5d                   	pop    %ebp
c002ce0b:	c3                   	ret    

c002ce0c <load_thread>:

static void
load_thread (void *ti_) 
{
c002ce0c:	57                   	push   %edi
c002ce0d:	56                   	push   %esi
c002ce0e:	53                   	push   %ebx
c002ce0f:	83 ec 10             	sub    $0x10,%esp
c002ce12:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread_info *ti = ti_;
  int64_t sleep_time = 5 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 30 * TIMER_FREQ;
  int64_t last_time = 0;

  thread_set_nice (ti->nice);
c002ce16:	8b 43 0c             	mov    0xc(%ebx),%eax
c002ce19:	89 04 24             	mov    %eax,(%esp)
c002ce1c:	e8 86 49 ff ff       	call   c00217a7 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (ti->start_time));
c002ce21:	8b 03                	mov    (%ebx),%eax
c002ce23:	8b 53 04             	mov    0x4(%ebx),%edx
c002ce26:	89 04 24             	mov    %eax,(%esp)
c002ce29:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ce2d:	e8 4e 74 ff ff       	call   c0024280 <timer_elapsed>
c002ce32:	be f4 01 00 00       	mov    $0x1f4,%esi
c002ce37:	bf 00 00 00 00       	mov    $0x0,%edi
c002ce3c:	29 c6                	sub    %eax,%esi
c002ce3e:	19 d7                	sbb    %edx,%edi
c002ce40:	89 34 24             	mov    %esi,(%esp)
c002ce43:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ce47:	e8 50 74 ff ff       	call   c002429c <timer_sleep>
  int64_t last_time = 0;
c002ce4c:	bf 00 00 00 00       	mov    $0x0,%edi
c002ce51:	be 00 00 00 00       	mov    $0x0,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce56:	eb 15                	jmp    c002ce6d <load_thread+0x61>
    {
      int64_t cur_time = timer_ticks ();
c002ce58:	e8 f7 73 ff ff       	call   c0024254 <timer_ticks>
      if (cur_time != last_time)
c002ce5d:	31 d6                	xor    %edx,%esi
c002ce5f:	31 c7                	xor    %eax,%edi
c002ce61:	09 fe                	or     %edi,%esi
c002ce63:	74 04                	je     c002ce69 <load_thread+0x5d>
        ti->tick_count++;
c002ce65:	83 43 08 01          	addl   $0x1,0x8(%ebx)
{
c002ce69:	89 c7                	mov    %eax,%edi
c002ce6b:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce6d:	8b 03                	mov    (%ebx),%eax
c002ce6f:	8b 53 04             	mov    0x4(%ebx),%edx
c002ce72:	89 04 24             	mov    %eax,(%esp)
c002ce75:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ce79:	e8 02 74 ff ff       	call   c0024280 <timer_elapsed>
c002ce7e:	85 d2                	test   %edx,%edx
c002ce80:	78 d6                	js     c002ce58 <load_thread+0x4c>
c002ce82:	85 d2                	test   %edx,%edx
c002ce84:	7f 07                	jg     c002ce8d <load_thread+0x81>
c002ce86:	3d ab 0d 00 00       	cmp    $0xdab,%eax
c002ce8b:	76 cb                	jbe    c002ce58 <load_thread+0x4c>
      last_time = cur_time;
    }
}
c002ce8d:	83 c4 10             	add    $0x10,%esp
c002ce90:	5b                   	pop    %ebx
c002ce91:	5e                   	pop    %esi
c002ce92:	5f                   	pop    %edi
c002ce93:	c3                   	ret    

c002ce94 <test_mlfqs_fair_2>:
{
c002ce94:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 0);
c002ce97:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce9c:	ba 00 00 00 00       	mov    $0x0,%edx
c002cea1:	b8 02 00 00 00       	mov    $0x2,%eax
c002cea6:	e8 e5 fc ff ff       	call   c002cb90 <test_mlfqs_fair>
}
c002ceab:	83 c4 0c             	add    $0xc,%esp
c002ceae:	c3                   	ret    

c002ceaf <test_mlfqs_fair_20>:
{
c002ceaf:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (20, 0, 0);
c002ceb2:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ceb7:	ba 00 00 00 00       	mov    $0x0,%edx
c002cebc:	b8 14 00 00 00       	mov    $0x14,%eax
c002cec1:	e8 ca fc ff ff       	call   c002cb90 <test_mlfqs_fair>
}
c002cec6:	83 c4 0c             	add    $0xc,%esp
c002cec9:	c3                   	ret    

c002ceca <test_mlfqs_nice_2>:
{
c002ceca:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 5);
c002cecd:	b9 05 00 00 00       	mov    $0x5,%ecx
c002ced2:	ba 00 00 00 00       	mov    $0x0,%edx
c002ced7:	b8 02 00 00 00       	mov    $0x2,%eax
c002cedc:	e8 af fc ff ff       	call   c002cb90 <test_mlfqs_fair>
}
c002cee1:	83 c4 0c             	add    $0xc,%esp
c002cee4:	c3                   	ret    

c002cee5 <test_mlfqs_nice_10>:
{
c002cee5:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (10, 0, 1);
c002cee8:	b9 01 00 00 00       	mov    $0x1,%ecx
c002ceed:	ba 00 00 00 00       	mov    $0x0,%edx
c002cef2:	b8 0a 00 00 00       	mov    $0xa,%eax
c002cef7:	e8 94 fc ff ff       	call   c002cb90 <test_mlfqs_fair>
}
c002cefc:	83 c4 0c             	add    $0xc,%esp
c002ceff:	c3                   	ret    

c002cf00 <block_thread>:
  msg ("Block thread should have already acquired lock.");
}

static void
block_thread (void *lock_) 
{
c002cf00:	56                   	push   %esi
c002cf01:	53                   	push   %ebx
c002cf02:	83 ec 14             	sub    $0x14,%esp
  struct lock *lock = lock_;
  int64_t start_time;

  msg ("Block thread spinning for 20 seconds...");
c002cf05:	c7 04 24 a4 12 03 c0 	movl   $0xc00312a4,(%esp)
c002cf0c:	e8 6c d8 ff ff       	call   c002a77d <msg>
  start_time = timer_ticks ();
c002cf11:	e8 3e 73 ff ff       	call   c0024254 <timer_ticks>
c002cf16:	89 c3                	mov    %eax,%ebx
c002cf18:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 20 * TIMER_FREQ)
c002cf1a:	89 1c 24             	mov    %ebx,(%esp)
c002cf1d:	89 74 24 04          	mov    %esi,0x4(%esp)
c002cf21:	e8 5a 73 ff ff       	call   c0024280 <timer_elapsed>
c002cf26:	85 d2                	test   %edx,%edx
c002cf28:	7f 0b                	jg     c002cf35 <block_thread+0x35>
c002cf2a:	85 d2                	test   %edx,%edx
c002cf2c:	78 ec                	js     c002cf1a <block_thread+0x1a>
c002cf2e:	3d cf 07 00 00       	cmp    $0x7cf,%eax
c002cf33:	76 e5                	jbe    c002cf1a <block_thread+0x1a>
    continue;

  msg ("Block thread acquiring lock...");
c002cf35:	c7 04 24 cc 12 03 c0 	movl   $0xc00312cc,(%esp)
c002cf3c:	e8 3c d8 ff ff       	call   c002a77d <msg>
  lock_acquire (lock);
c002cf41:	8b 44 24 20          	mov    0x20(%esp),%eax
c002cf45:	89 04 24             	mov    %eax,(%esp)
c002cf48:	e8 5d 5f ff ff       	call   c0022eaa <lock_acquire>

  msg ("...got it.");
c002cf4d:	c7 04 24 a4 13 03 c0 	movl   $0xc00313a4,(%esp)
c002cf54:	e8 24 d8 ff ff       	call   c002a77d <msg>
}
c002cf59:	83 c4 14             	add    $0x14,%esp
c002cf5c:	5b                   	pop    %ebx
c002cf5d:	5e                   	pop    %esi
c002cf5e:	c3                   	ret    

c002cf5f <test_mlfqs_block>:
{
c002cf5f:	56                   	push   %esi
c002cf60:	53                   	push   %ebx
c002cf61:	83 ec 54             	sub    $0x54,%esp
  ASSERT (thread_mlfqs);
c002cf64:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002cf6b:	75 2c                	jne    c002cf99 <test_mlfqs_block+0x3a>
c002cf6d:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002cf74:	c0 
c002cf75:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cf7c:	c0 
c002cf7d:	c7 44 24 08 28 e1 02 	movl   $0xc002e128,0x8(%esp)
c002cf84:	c0 
c002cf85:	c7 44 24 04 1c 00 00 	movl   $0x1c,0x4(%esp)
c002cf8c:	00 
c002cf8d:	c7 04 24 ec 12 03 c0 	movl   $0xc00312ec,(%esp)
c002cf94:	e8 2a ba ff ff       	call   c00289c3 <debug_panic>
  msg ("Main thread acquiring lock.");
c002cf99:	c7 04 24 af 13 03 c0 	movl   $0xc00313af,(%esp)
c002cfa0:	e8 d8 d7 ff ff       	call   c002a77d <msg>
  lock_init (&lock);
c002cfa5:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002cfa9:	89 1c 24             	mov    %ebx,(%esp)
c002cfac:	e8 5c 5e ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&lock);
c002cfb1:	89 1c 24             	mov    %ebx,(%esp)
c002cfb4:	e8 f1 5e ff ff       	call   c0022eaa <lock_acquire>
  msg ("Main thread creating block thread, sleeping 25 seconds...");
c002cfb9:	c7 04 24 10 13 03 c0 	movl   $0xc0031310,(%esp)
c002cfc0:	e8 b8 d7 ff ff       	call   c002a77d <msg>
  thread_create ("block", PRI_DEFAULT, block_thread, &lock);
c002cfc5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cfc9:	c7 44 24 08 00 cf 02 	movl   $0xc002cf00,0x8(%esp)
c002cfd0:	c0 
c002cfd1:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cfd8:	00 
c002cfd9:	c7 04 24 36 01 03 c0 	movl   $0xc0030136,(%esp)
c002cfe0:	e8 9c 45 ff ff       	call   c0021581 <thread_create>
  timer_sleep (25 * TIMER_FREQ);
c002cfe5:	c7 04 24 c4 09 00 00 	movl   $0x9c4,(%esp)
c002cfec:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cff3:	00 
c002cff4:	e8 a3 72 ff ff       	call   c002429c <timer_sleep>
  msg ("Main thread spinning for 5 seconds...");
c002cff9:	c7 04 24 4c 13 03 c0 	movl   $0xc003134c,(%esp)
c002d000:	e8 78 d7 ff ff       	call   c002a77d <msg>
  start_time = timer_ticks ();
c002d005:	e8 4a 72 ff ff       	call   c0024254 <timer_ticks>
c002d00a:	89 c3                	mov    %eax,%ebx
c002d00c:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 5 * TIMER_FREQ)
c002d00e:	89 1c 24             	mov    %ebx,(%esp)
c002d011:	89 74 24 04          	mov    %esi,0x4(%esp)
c002d015:	e8 66 72 ff ff       	call   c0024280 <timer_elapsed>
c002d01a:	85 d2                	test   %edx,%edx
c002d01c:	7f 0b                	jg     c002d029 <test_mlfqs_block+0xca>
c002d01e:	85 d2                	test   %edx,%edx
c002d020:	78 ec                	js     c002d00e <test_mlfqs_block+0xaf>
c002d022:	3d f3 01 00 00       	cmp    $0x1f3,%eax
c002d027:	76 e5                	jbe    c002d00e <test_mlfqs_block+0xaf>
  msg ("Main thread releasing lock.");
c002d029:	c7 04 24 cb 13 03 c0 	movl   $0xc00313cb,(%esp)
c002d030:	e8 48 d7 ff ff       	call   c002a77d <msg>
  lock_release (&lock);
c002d035:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c002d039:	89 04 24             	mov    %eax,(%esp)
c002d03c:	e8 33 60 ff ff       	call   c0023074 <lock_release>
  msg ("Block thread should have already acquired lock.");
c002d041:	c7 04 24 74 13 03 c0 	movl   $0xc0031374,(%esp)
c002d048:	e8 30 d7 ff ff       	call   c002a77d <msg>
}
c002d04d:	83 c4 54             	add    $0x54,%esp
c002d050:	5b                   	pop    %ebx
c002d051:	5e                   	pop    %esi
c002d052:	c3                   	ret    
