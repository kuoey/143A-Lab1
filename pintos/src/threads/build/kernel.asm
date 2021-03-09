
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
c00201a6:	e8 b3 69 00 00       	call   c0026b5e <printf>
#ifdef USERPROG
  process_wait (process_execute (task));
#else
  run_test (task);
c00201ab:	89 1c 24             	mov    %ebx,(%esp)
c00201ae:	e8 f6 a5 00 00       	call   c002a7a9 <run_test>
#endif
  printf ("Execution of '%s' complete.\n", task);
c00201b3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00201b7:	c7 04 24 4a e1 02 c0 	movl   $0xc002e14a,(%esp)
c00201be:	e8 9b 69 00 00       	call   c0026b5e <printf>
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
c00201cf:	b8 c1 7b 03 c0       	mov    $0xc0037bc1,%eax
c00201d4:	2d 98 5a 03 c0       	sub    $0xc0035a98,%eax
c00201d9:	89 44 24 08          	mov    %eax,0x8(%esp)
c00201dd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00201e4:	00 
c00201e5:	c7 04 24 98 5a 03 c0 	movl   $0xc0035a98,(%esp)
c00201ec:	e8 80 7c 00 00       	call   c0027e71 <memset>
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
c0020236:	e8 78 87 00 00       	call   c00289b3 <debug_panic>
      argv[i] = p;
c002023b:	89 1c b5 a0 5a 03 c0 	mov    %ebx,-0x3ffca560(,%esi,4)
      p += strnlen (p, end - p) + 1;
c0020242:	89 e8                	mov    %ebp,%eax
c0020244:	29 d8                	sub    %ebx,%eax
c0020246:	89 44 24 04          	mov    %eax,0x4(%esp)
c002024a:	89 1c 24             	mov    %ebx,(%esp)
c002024d:	e8 48 7d 00 00       	call   c0027f9a <strnlen>
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
c002026f:	e8 ea 68 00 00       	call   c0026b5e <printf>
  for (i = 0; i < argc; i++)
c0020274:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (argv[i], ' ') == NULL)
c0020279:	8b 34 9d a0 5a 03 c0 	mov    -0x3ffca560(,%ebx,4),%esi
c0020280:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c0020287:	00 
c0020288:	89 34 24             	mov    %esi,(%esp)
c002028b:	e8 56 79 00 00       	call   c0027be6 <strchr>
c0020290:	85 c0                	test   %eax,%eax
c0020292:	75 12                	jne    c00202a6 <pintos_init+0xde>
      printf (" %s", argv[i]);
c0020294:	89 74 24 04          	mov    %esi,0x4(%esp)
c0020298:	c7 04 24 87 ef 02 c0 	movl   $0xc002ef87,(%esp)
c002029f:	e8 ba 68 00 00       	call   c0026b5e <printf>
c00202a4:	eb 10                	jmp    c00202b6 <pintos_init+0xee>
      printf (" '%s'", argv[i]);
c00202a6:	89 74 24 04          	mov    %esi,0x4(%esp)
c00202aa:	c7 04 24 7c e1 02 c0 	movl   $0xc002e17c,(%esp)
c00202b1:	e8 a8 68 00 00       	call   c0026b5e <printf>
  for (i = 0; i < argc; i++)
c00202b6:	83 c3 01             	add    $0x1,%ebx
c00202b9:	39 df                	cmp    %ebx,%edi
c00202bb:	75 bc                	jne    c0020279 <pintos_init+0xb1>
  printf ("\n");
c00202bd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00202c4:	e8 83 a4 00 00       	call   c002a74c <putchar>
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
c00202f7:	e8 58 7a 00 00       	call   c0027d54 <strtok_r>
c00202fc:	89 c3                	mov    %eax,%ebx
      char *value = strtok_r (NULL, "", &save_ptr);
c00202fe:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020302:	89 44 24 08          	mov    %eax,0x8(%esp)
c0020306:	c7 44 24 04 2b ee 02 	movl   $0xc002ee2b,0x4(%esp)
c002030d:	c0 
c002030e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0020315:	e8 3a 7a 00 00       	call   c0027d54 <strtok_r>
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
c0020339:	e8 9d a3 00 00       	call   c002a6db <puts>
          "  -mlfqs             Use multi-level feedback queue scheduler.\n"
#ifdef USERPROG
          "  -ul=COUNT          Limit user memory to COUNT pages.\n"
#endif
          );
  shutdown_power_off ();
c002033e:	e8 fc 60 00 00       	call   c002643f <shutdown_power_off>
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
c0020362:	e8 59 60 00 00       	call   c00263c0 <shutdown_configure>
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
c002038b:	e8 30 60 00 00       	call   c00263c0 <shutdown_configure>
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
c00203ad:	e8 0e 72 00 00       	call   c00275c0 <atoi>
c00203b2:	89 04 24             	mov    %eax,(%esp)
c00203b5:	e8 51 62 00 00       	call   c002660b <random_init>
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
c0020400:	e8 ae 85 00 00       	call   c00289b3 <debug_panic>
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
c0020427:	e8 30 5e 00 00       	call   c002625c <rtc_get_time>
c002042c:	89 04 24             	mov    %eax,(%esp)
c002042f:	e8 d7 61 00 00       	call   c002660b <random_init>
  thread_init ();
c0020434:	e8 cd 07 00 00       	call   c0020c06 <thread_init>
  console_init ();  
c0020439:	e8 14 a2 00 00       	call   c002a652 <console_init>
          init_ram_pages * PGSIZE / 1024);
c002043e:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c0020443:	c1 e0 0c             	shl    $0xc,%eax
  printf ("Pintos booting with %'"PRIu32" kB RAM...\n",
c0020446:	c1 e8 0a             	shr    $0xa,%eax
c0020449:	89 44 24 04          	mov    %eax,0x4(%esp)
c002044d:	c7 04 24 8c e4 02 c0 	movl   $0xc002e48c,(%esp)
c0020454:	e8 05 67 00 00       	call   c0026b5e <printf>
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
c00204d0:	e8 de 84 00 00       	call   c00289b3 <debug_panic>
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
c002055b:	e8 53 84 00 00       	call   c00289b3 <debug_panic>
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
c002058e:	e8 20 84 00 00       	call   c00289b3 <debug_panic>

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
c00205d8:	e8 d6 83 00 00       	call   c00289b3 <debug_panic>
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
c0020638:	e8 76 83 00 00       	call   c00289b3 <debug_panic>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c002063d:	05 00 00 00 40       	add    $0x40000000,%eax
c0020642:	0f 22 d8             	mov    %eax,%cr3
  intr_init ();
c0020645:	e8 e7 13 00 00       	call   c0021a31 <intr_init>
  timer_init ();
c002064a:	e8 c0 3a 00 00       	call   c002410f <timer_init>
  kbd_init ();
c002064f:	e8 27 40 00 00       	call   c002467b <kbd_init>
  input_init ();
c0020654:	e8 ec 56 00 00       	call   c0025d45 <input_init>
  thread_start ();
c0020659:	e8 48 10 00 00       	call   c00216a6 <thread_start>
c002065e:	66 90                	xchg   %ax,%ax
  serial_init_queue ();
c0020660:	e8 61 44 00 00       	call   c0024ac6 <serial_init_queue>
  timer_calibrate ();
c0020665:	e8 f0 3a 00 00       	call   c002415a <timer_calibrate>
  printf ("Boot complete.\n");
c002066a:	c7 04 24 1b e2 02 c0 	movl   $0xc002e21b,(%esp)
c0020671:	e8 65 a0 00 00       	call   c002a6db <puts>
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
c00206a0:	e8 22 74 00 00       	call   c0027ac7 <strcmp>
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
c00206e6:	e8 c8 82 00 00       	call   c00289b3 <debug_panic>
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
c002071c:	e8 92 82 00 00       	call   c00289b3 <debug_panic>
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
c0020766:	e8 5b 78 00 00       	call   c0027fc6 <strlcpy>
      printf("ICS143A>");
c002076b:	c7 04 24 2a e2 02 c0 	movl   $0xc002e22a,(%esp)
c0020772:	e8 e7 63 00 00       	call   c0026b5e <printf>
        char l = input_getc();
c0020777:	e8 72 56 00 00       	call   c0025dee <input_getc>
c002077c:	89 c3                	mov    %eax,%ebx
        while(l != '\n'){
c002077e:	3c 0a                	cmp    $0xa,%al
c0020780:	74 24                	je     c00207a6 <pintos_init+0x5de>
c0020782:	be 00 00 00 00       	mov    $0x0,%esi
          printf("%c",l);
c0020787:	0f be c3             	movsbl %bl,%eax
c002078a:	89 04 24             	mov    %eax,(%esp)
c002078d:	e8 ba 9f 00 00       	call   c002a74c <putchar>
          cmdline[i] = l;
c0020792:	88 5c 34 3c          	mov    %bl,0x3c(%esp,%esi,1)
          l = input_getc();
c0020796:	e8 53 56 00 00       	call   c0025dee <input_getc>
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
c00207ce:	e8 08 9f 00 00       	call   c002a6db <puts>
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
c00207f6:	e8 51 9f 00 00       	call   c002a74c <putchar>
c00207fb:	eb 26                	jmp    c0020823 <pintos_init+0x65b>
          printf("\ninvalid command\n");
c00207fd:	c7 04 24 4c e2 02 c0 	movl   $0xc002e24c,(%esp)
c0020804:	e8 d2 9e 00 00       	call   c002a6db <puts>
        memset(&cmdline[0], 0, sizeof(cmdline));
c0020809:	b9 0c 00 00 00       	mov    $0xc,%ecx
c002080e:	b8 00 00 00 00       	mov    $0x0,%eax
c0020813:	8d 7c 24 3c          	lea    0x3c(%esp),%edi
c0020817:	f3 ab                	rep stos %eax,%es:(%edi)
c0020819:	66 c7 07 00 00       	movw   $0x0,(%edi)
    }
c002081e:	e9 2c ff ff ff       	jmp    c002074f <pintos_init+0x587>
  shutdown ();
c0020823:	e8 98 5c 00 00       	call   c00264c0 <shutdown>
  thread_exit ();
c0020828:	e8 e6 0b 00 00       	call   c0021413 <thread_exit>
  argv[argc] = NULL;
c002082d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020834:	00 00 00 00 
  printf ("Kernel command line:");
c0020838:	c7 04 24 5d e2 02 c0 	movl   $0xc002e25d,(%esp)
c002083f:	e8 1a 63 00 00       	call   c0026b5e <printf>
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
c002088e:	c7 44 24 04 23 03 00 	movl   $0x323,0x4(%esp)
c0020895:	00 
c0020896:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c002089d:	e8 11 81 00 00       	call   c00289b3 <debug_panic>
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
c00208c1:	c7 44 24 04 22 03 00 	movl   $0x322,0x4(%esp)
c00208c8:	00 
c00208c9:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00208d0:	e8 de 80 00 00       	call   c00289b3 <debug_panic>

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
c00209aa:	c7 44 24 04 f4 02 00 	movl   $0x2f4,0x4(%esp)
c00209b1:	00 
c00209b2:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00209b9:	e8 f5 7f 00 00       	call   c00289b3 <debug_panic>
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
c00209dd:	c7 44 24 04 f5 02 00 	movl   $0x2f5,0x4(%esp)
c00209e4:	00 
c00209e5:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00209ec:	e8 c2 7f 00 00       	call   c00289b3 <debug_panic>
  ASSERT (name != NULL);
c00209f1:	85 d2                	test   %edx,%edx
c00209f3:	75 2c                	jne    c0020a21 <init_thread+0x9c>
c00209f5:	c7 44 24 10 3f e5 02 	movl   $0xc002e53f,0x10(%esp)
c00209fc:	c0 
c00209fd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020a04:	c0 
c0020a05:	c7 44 24 08 66 d1 02 	movl   $0xc002d166,0x8(%esp)
c0020a0c:	c0 
c0020a0d:	c7 44 24 04 f6 02 00 	movl   $0x2f6,0x4(%esp)
c0020a14:	00 
c0020a15:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020a1c:	e8 92 7f 00 00       	call   c00289b3 <debug_panic>
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
c0020a89:	e8 38 75 00 00       	call   c0027fc6 <strlcpy>
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
c0020aaf:	e8 4d 85 00 00       	call   c0029001 <list_push_back>
  if(thread_mlfqs)
c0020ab4:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020abb:	74 44                	je     c0020b01 <init_thread+0x17c>
    t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020abd:	8b 43 58             	mov    0x58(%ebx),%eax
c0020ac0:	8d 50 03             	lea    0x3(%eax),%edx
c0020ac3:	85 c0                	test   %eax,%eax
c0020ac5:	0f 48 c2             	cmovs  %edx,%eax
c0020ac8:	c1 f8 02             	sar    $0x2,%eax
c0020acb:	89 04 24             	mov    %eax,(%esp)
c0020ace:	e8 80 fe ff ff       	call   c0020953 <convertXtoIntRoundNear>
c0020ad3:	ba 3f 00 00 00       	mov    $0x3f,%edx
c0020ad8:	29 c2                	sub    %eax,%edx
c0020ada:	89 d0                	mov    %edx,%eax
c0020adc:	8b 53 54             	mov    0x54(%ebx),%edx
c0020adf:	f7 da                	neg    %edx
c0020ae1:	8d 04 50             	lea    (%eax,%edx,2),%eax
    if(t->priority > PRI_MAX){
c0020ae4:	83 f8 3f             	cmp    $0x3f,%eax
c0020ae7:	7e 09                	jle    c0020af2 <init_thread+0x16d>
      t->priority = PRI_MAX;
c0020ae9:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c0020af0:	eb 15                	jmp    c0020b07 <init_thread+0x182>
    t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020af2:	85 c0                	test   %eax,%eax
c0020af4:	ba 00 00 00 00       	mov    $0x0,%edx
c0020af9:	0f 48 c2             	cmovs  %edx,%eax
c0020afc:	89 43 1c             	mov    %eax,0x1c(%ebx)
c0020aff:	eb 06                	jmp    c0020b07 <init_thread+0x182>
    t->priority = priority;
c0020b01:	89 73 1c             	mov    %esi,0x1c(%ebx)
    t->old_priority = priority;
c0020b04:	89 73 3c             	mov    %esi,0x3c(%ebx)
  list_init (&t->locks_held);
c0020b07:	8d 43 40             	lea    0x40(%ebx),%eax
c0020b0a:	89 04 24             	mov    %eax,(%esp)
c0020b0d:	e8 6e 7f 00 00       	call   c0028a80 <list_init>
  t->wait_on_lock = NULL;
c0020b12:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
}
c0020b19:	83 c4 2c             	add    $0x2c,%esp
c0020b1c:	5b                   	pop    %ebx
c0020b1d:	5e                   	pop    %esi
c0020b1e:	5f                   	pop    %edi
c0020b1f:	5d                   	pop    %ebp
c0020b20:	c3                   	ret    

c0020b21 <addXandY>:
    return x + y;
c0020b21:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b25:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020b29:	c3                   	ret    

c0020b2a <subtractYfromX>:
    return x - y;
c0020b2a:	8b 44 24 04          	mov    0x4(%esp),%eax
c0020b2e:	2b 44 24 08          	sub    0x8(%esp),%eax
}
c0020b32:	c3                   	ret    

c0020b33 <addXandN>:
    return x + (n * f);
c0020b33:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b37:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
c0020b3e:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020b42:	c3                   	ret    

c0020b43 <subNfromX>:
    return x - (n * f);
c0020b43:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b47:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
c0020b4e:	8b 54 24 04          	mov    0x4(%esp),%edx
c0020b52:	29 c2                	sub    %eax,%edx
c0020b54:	89 d0                	mov    %edx,%eax
}
c0020b56:	c3                   	ret    

c0020b57 <multXbyY>:
{
c0020b57:	57                   	push   %edi
c0020b58:	56                   	push   %esi
c0020b59:	53                   	push   %ebx
c0020b5a:	83 ec 10             	sub    $0x10,%esp
c0020b5d:	8b 54 24 20          	mov    0x20(%esp),%edx
c0020b61:	8b 44 24 24          	mov    0x24(%esp),%eax
    return ((int64_t) x) * y / f;
c0020b65:	89 d7                	mov    %edx,%edi
c0020b67:	c1 ff 1f             	sar    $0x1f,%edi
c0020b6a:	89 c3                	mov    %eax,%ebx
c0020b6c:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b6f:	89 fe                	mov    %edi,%esi
c0020b71:	0f af f0             	imul   %eax,%esi
c0020b74:	89 d9                	mov    %ebx,%ecx
c0020b76:	0f af ca             	imul   %edx,%ecx
c0020b79:	01 f1                	add    %esi,%ecx
c0020b7b:	f7 e2                	mul    %edx
c0020b7d:	01 ca                	add    %ecx,%edx
c0020b7f:	8b 0d bc 7b 03 c0    	mov    0xc0037bbc,%ecx
c0020b85:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020b89:	89 cb                	mov    %ecx,%ebx
c0020b8b:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b8e:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020b92:	89 04 24             	mov    %eax,(%esp)
c0020b95:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020b99:	e8 75 77 00 00       	call   c0028313 <__divdi3>
}
c0020b9e:	83 c4 10             	add    $0x10,%esp
c0020ba1:	5b                   	pop    %ebx
c0020ba2:	5e                   	pop    %esi
c0020ba3:	5f                   	pop    %edi
c0020ba4:	c3                   	ret    

c0020ba5 <multXbyN>:
    return x * n;
c0020ba5:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020ba9:	0f af 44 24 04       	imul   0x4(%esp),%eax
}
c0020bae:	c3                   	ret    

c0020baf <divXbyY>:
{
c0020baf:	57                   	push   %edi
c0020bb0:	56                   	push   %esi
c0020bb1:	53                   	push   %ebx
c0020bb2:	83 ec 10             	sub    $0x10,%esp
c0020bb5:	8b 54 24 20          	mov    0x20(%esp),%edx
    return ((int64_t) x) * f / y;
c0020bb9:	89 d7                	mov    %edx,%edi
c0020bbb:	c1 ff 1f             	sar    $0x1f,%edi
c0020bbe:	a1 bc 7b 03 c0       	mov    0xc0037bbc,%eax
c0020bc3:	89 c3                	mov    %eax,%ebx
c0020bc5:	c1 fb 1f             	sar    $0x1f,%ebx
c0020bc8:	89 fe                	mov    %edi,%esi
c0020bca:	0f af f0             	imul   %eax,%esi
c0020bcd:	89 d9                	mov    %ebx,%ecx
c0020bcf:	0f af ca             	imul   %edx,%ecx
c0020bd2:	01 f1                	add    %esi,%ecx
c0020bd4:	f7 e2                	mul    %edx
c0020bd6:	01 ca                	add    %ecx,%edx
c0020bd8:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c0020bdc:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020be0:	89 cb                	mov    %ecx,%ebx
c0020be2:	c1 fb 1f             	sar    $0x1f,%ebx
c0020be5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020be9:	89 04 24             	mov    %eax,(%esp)
c0020bec:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020bf0:	e8 1e 77 00 00       	call   c0028313 <__divdi3>
}
c0020bf5:	83 c4 10             	add    $0x10,%esp
c0020bf8:	5b                   	pop    %ebx
c0020bf9:	5e                   	pop    %esi
c0020bfa:	5f                   	pop    %edi
c0020bfb:	c3                   	ret    

c0020bfc <divXbyN>:
{
c0020bfc:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / n;
c0020c00:	99                   	cltd   
c0020c01:	f7 7c 24 08          	idivl  0x8(%esp)
}
c0020c05:	c3                   	ret    

c0020c06 <thread_init>:
{
c0020c06:	56                   	push   %esi
c0020c07:	53                   	push   %ebx
c0020c08:	83 ec 24             	sub    $0x24,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0020c0b:	e8 b4 0d 00 00       	call   c00219c4 <intr_get_level>
c0020c10:	85 c0                	test   %eax,%eax
c0020c12:	74 2c                	je     c0020c40 <thread_init+0x3a>
c0020c14:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0020c1b:	c0 
c0020c1c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020c23:	c0 
c0020c24:	c7 44 24 08 72 d1 02 	movl   $0xc002d172,0x8(%esp)
c0020c2b:	c0 
c0020c2c:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
c0020c33:	00 
c0020c34:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020c3b:	e8 73 7d 00 00       	call   c00289b3 <debug_panic>
  lock_init (&tid_lock);
c0020c40:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020c47:	e8 c1 21 00 00       	call   c0022e0d <lock_init>
  list_init (&all_list);
c0020c4c:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020c53:	e8 28 7e 00 00       	call   c0028a80 <list_init>
  if(thread_mlfqs) {
c0020c58:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020c5f:	74 1b                	je     c0020c7c <thread_init+0x76>
c0020c61:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0020c66:	be 20 60 03 c0       	mov    $0xc0036020,%esi
      list_init (&mlfqs_list[i]);
c0020c6b:	89 1c 24             	mov    %ebx,(%esp)
c0020c6e:	e8 0d 7e 00 00       	call   c0028a80 <list_init>
c0020c73:	83 c3 10             	add    $0x10,%ebx
    for(i=0;i<64;i++)
c0020c76:	39 f3                	cmp    %esi,%ebx
c0020c78:	75 f1                	jne    c0020c6b <thread_init+0x65>
c0020c7a:	eb 0c                	jmp    c0020c88 <thread_init+0x82>
    list_init (&ready_list);
c0020c7c:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020c83:	e8 f8 7d 00 00       	call   c0028a80 <list_init>
  f = power(2,14);
c0020c88:	c7 44 24 04 0e 00 00 	movl   $0xe,0x4(%esp)
c0020c8f:	00 
c0020c90:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c0020c97:	e8 45 fc ff ff       	call   c00208e1 <power>
c0020c9c:	a3 bc 7b 03 c0       	mov    %eax,0xc0037bbc
  initial_thread->nice = 0; //nice value of first thread is zero
c0020ca1:	a1 04 5c 03 c0       	mov    0xc0035c04,%eax
c0020ca6:	c7 40 54 00 00 00 00 	movl   $0x0,0x54(%eax)
  initial_thread->recent_cpu = 0; //recent_cpu of first thread is zero
c0020cad:	c7 40 58 00 00 00 00 	movl   $0x0,0x58(%eax)
  asm ("mov %%esp, %0" : "=g" (esp));
c0020cb4:	89 e0                	mov    %esp,%eax
  return (void *) ((uintptr_t) va & ~PGMASK);
c0020cb6:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  initial_thread = running_thread ();
c0020cbb:	a3 04 5c 03 c0       	mov    %eax,0xc0035c04
  init_thread (initial_thread, "main", PRI_DEFAULT);
c0020cc0:	b9 1f 00 00 00       	mov    $0x1f,%ecx
c0020cc5:	ba 6a e5 02 c0       	mov    $0xc002e56a,%edx
c0020cca:	e8 b6 fc ff ff       	call   c0020985 <init_thread>
  initial_thread->status = THREAD_RUNNING;
c0020ccf:	8b 1d 04 5c 03 c0    	mov    0xc0035c04,%ebx
c0020cd5:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
allocate_tid (void) 
{
  static tid_t next_tid = 1;
  tid_t tid;

  lock_acquire (&tid_lock);
c0020cdc:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020ce3:	e8 c2 21 00 00       	call   c0022eaa <lock_acquire>
  tid = next_tid++;
c0020ce8:	8b 35 54 56 03 c0    	mov    0xc0035654,%esi
c0020cee:	8d 46 01             	lea    0x1(%esi),%eax
c0020cf1:	a3 54 56 03 c0       	mov    %eax,0xc0035654
  lock_release (&tid_lock);
c0020cf6:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020cfd:	e8 72 23 00 00       	call   c0023074 <lock_release>
  initial_thread->tid = allocate_tid ();
c0020d02:	89 33                	mov    %esi,(%ebx)
}
c0020d04:	83 c4 24             	add    $0x24,%esp
c0020d07:	5b                   	pop    %ebx
c0020d08:	5e                   	pop    %esi
c0020d09:	c3                   	ret    

c0020d0a <thread_print_stats>:
{
c0020d0a:	83 ec 2c             	sub    $0x2c,%esp
  printf ("Thread: %lld idle ticks, %lld kernel ticks, %lld user ticks\n",
c0020d0d:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0020d14:	00 
c0020d15:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c0020d1c:	00 
c0020d1d:	a1 c8 5b 03 c0       	mov    0xc0035bc8,%eax
c0020d22:	8b 15 cc 5b 03 c0    	mov    0xc0035bcc,%edx
c0020d28:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0020d2c:	89 54 24 10          	mov    %edx,0x10(%esp)
c0020d30:	a1 d0 5b 03 c0       	mov    0xc0035bd0,%eax
c0020d35:	8b 15 d4 5b 03 c0    	mov    0xc0035bd4,%edx
c0020d3b:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020d3f:	89 54 24 08          	mov    %edx,0x8(%esp)
c0020d43:	c7 04 24 4c e6 02 c0 	movl   $0xc002e64c,(%esp)
c0020d4a:	e8 0f 5e 00 00       	call   c0026b5e <printf>
}
c0020d4f:	83 c4 2c             	add    $0x2c,%esp
c0020d52:	c3                   	ret    

c0020d53 <thread_unblock>:
{
c0020d53:	56                   	push   %esi
c0020d54:	53                   	push   %ebx
c0020d55:	83 ec 24             	sub    $0x24,%esp
c0020d58:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  return t != NULL && t->magic == THREAD_MAGIC;
c0020d5c:	85 db                	test   %ebx,%ebx
c0020d5e:	0f 84 96 00 00 00    	je     c0020dfa <thread_unblock+0xa7>
c0020d64:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c0020d6b:	0f 85 89 00 00 00    	jne    c0020dfa <thread_unblock+0xa7>
c0020d71:	eb 75                	jmp    c0020de8 <thread_unblock+0x95>
  ASSERT (t->status == THREAD_BLOCKED);
c0020d73:	c7 44 24 10 6f e5 02 	movl   $0xc002e56f,0x10(%esp)
c0020d7a:	c0 
c0020d7b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020d82:	c0 
c0020d83:	c7 44 24 08 19 d1 02 	movl   $0xc002d119,0x8(%esp)
c0020d8a:	c0 
c0020d8b:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
c0020d92:	00 
c0020d93:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020d9a:	e8 14 7c 00 00       	call   c00289b3 <debug_panic>
  if(thread_mlfqs) {
c0020d9f:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020da6:	74 1c                	je     c0020dc4 <thread_unblock+0x71>
    list_push_back (&mlfqs_list[t->priority], &t->elem);
c0020da8:	8d 43 28             	lea    0x28(%ebx),%eax
c0020dab:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020daf:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0020db2:	c1 e0 04             	shl    $0x4,%eax
c0020db5:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c0020dba:	89 04 24             	mov    %eax,(%esp)
c0020dbd:	e8 3f 82 00 00       	call   c0029001 <list_push_back>
c0020dc2:	eb 13                	jmp    c0020dd7 <thread_unblock+0x84>
    list_push_back (&ready_list, &t->elem);
c0020dc4:	8d 53 28             	lea    0x28(%ebx),%edx
c0020dc7:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020dcb:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020dd2:	e8 2a 82 00 00       	call   c0029001 <list_push_back>
  t->status = THREAD_READY;
c0020dd7:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  intr_set_level (old_level);
c0020dde:	89 34 24             	mov    %esi,(%esp)
c0020de1:	e8 30 0c 00 00       	call   c0021a16 <intr_set_level>
c0020de6:	eb 3e                	jmp    c0020e26 <thread_unblock+0xd3>
  old_level = intr_disable ();
c0020de8:	e8 22 0c 00 00       	call   c0021a0f <intr_disable>
c0020ded:	89 c6                	mov    %eax,%esi
  ASSERT (t->status == THREAD_BLOCKED);
c0020def:	83 7b 04 02          	cmpl   $0x2,0x4(%ebx)
c0020df3:	74 aa                	je     c0020d9f <thread_unblock+0x4c>
c0020df5:	e9 79 ff ff ff       	jmp    c0020d73 <thread_unblock+0x20>
  ASSERT (is_thread (t));
c0020dfa:	c7 44 24 10 31 e5 02 	movl   $0xc002e531,0x10(%esp)
c0020e01:	c0 
c0020e02:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020e09:	c0 
c0020e0a:	c7 44 24 08 19 d1 02 	movl   $0xc002d119,0x8(%esp)
c0020e11:	c0 
c0020e12:	c7 44 24 04 7f 01 00 	movl   $0x17f,0x4(%esp)
c0020e19:	00 
c0020e1a:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020e21:	e8 8d 7b 00 00       	call   c00289b3 <debug_panic>
}
c0020e26:	83 c4 24             	add    $0x24,%esp
c0020e29:	5b                   	pop    %ebx
c0020e2a:	5e                   	pop    %esi
c0020e2b:	c3                   	ret    

c0020e2c <thread_current>:
{
c0020e2c:	83 ec 2c             	sub    $0x2c,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0020e2f:	89 e0                	mov    %esp,%eax
  return t != NULL && t->magic == THREAD_MAGIC;
c0020e31:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0020e36:	74 3f                	je     c0020e77 <thread_current+0x4b>
c0020e38:	81 78 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%eax)
c0020e3f:	75 36                	jne    c0020e77 <thread_current+0x4b>
c0020e41:	eb 2c                	jmp    c0020e6f <thread_current+0x43>
  ASSERT (t->status == THREAD_RUNNING);
c0020e43:	c7 44 24 10 8b e5 02 	movl   $0xc002e58b,0x10(%esp)
c0020e4a:	c0 
c0020e4b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020e52:	c0 
c0020e53:	c7 44 24 08 0a d1 02 	movl   $0xc002d10a,0x8(%esp)
c0020e5a:	c0 
c0020e5b:	c7 44 24 04 a6 01 00 	movl   $0x1a6,0x4(%esp)
c0020e62:	00 
c0020e63:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020e6a:	e8 44 7b 00 00       	call   c00289b3 <debug_panic>
c0020e6f:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0020e73:	74 2e                	je     c0020ea3 <thread_current+0x77>
c0020e75:	eb cc                	jmp    c0020e43 <thread_current+0x17>
  ASSERT (is_thread (t));
c0020e77:	c7 44 24 10 31 e5 02 	movl   $0xc002e531,0x10(%esp)
c0020e7e:	c0 
c0020e7f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020e86:	c0 
c0020e87:	c7 44 24 08 0a d1 02 	movl   $0xc002d10a,0x8(%esp)
c0020e8e:	c0 
c0020e8f:	c7 44 24 04 a5 01 00 	movl   $0x1a5,0x4(%esp)
c0020e96:	00 
c0020e97:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020e9e:	e8 10 7b 00 00       	call   c00289b3 <debug_panic>
}
c0020ea3:	83 c4 2c             	add    $0x2c,%esp
c0020ea6:	c3                   	ret    

c0020ea7 <thread_tick>:
{
c0020ea7:	83 ec 0c             	sub    $0xc,%esp
  struct thread *t = thread_current ();
c0020eaa:	e8 7d ff ff ff       	call   c0020e2c <thread_current>
  if (t == idle_thread)
c0020eaf:	3b 05 08 5c 03 c0    	cmp    0xc0035c08,%eax
c0020eb5:	75 10                	jne    c0020ec7 <thread_tick+0x20>
    idle_ticks++;
c0020eb7:	83 05 d0 5b 03 c0 01 	addl   $0x1,0xc0035bd0
c0020ebe:	83 15 d4 5b 03 c0 00 	adcl   $0x0,0xc0035bd4
c0020ec5:	eb 0e                	jmp    c0020ed5 <thread_tick+0x2e>
    kernel_ticks++;
c0020ec7:	83 05 c8 5b 03 c0 01 	addl   $0x1,0xc0035bc8
c0020ece:	83 15 cc 5b 03 c0 00 	adcl   $0x0,0xc0035bcc
  if (++thread_ticks >= TIME_SLICE)
c0020ed5:	a1 c0 5b 03 c0       	mov    0xc0035bc0,%eax
c0020eda:	83 c0 01             	add    $0x1,%eax
c0020edd:	a3 c0 5b 03 c0       	mov    %eax,0xc0035bc0
c0020ee2:	83 f8 03             	cmp    $0x3,%eax
c0020ee5:	76 05                	jbe    c0020eec <thread_tick+0x45>
    intr_yield_on_return ();
c0020ee7:	e8 8d 0d 00 00       	call   c0021c79 <intr_yield_on_return>
}
c0020eec:	83 c4 0c             	add    $0xc,%esp
c0020eef:	c3                   	ret    

c0020ef0 <thread_name>:
{
c0020ef0:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->name;
c0020ef3:	e8 34 ff ff ff       	call   c0020e2c <thread_current>
c0020ef8:	83 c0 08             	add    $0x8,%eax
}
c0020efb:	83 c4 0c             	add    $0xc,%esp
c0020efe:	c3                   	ret    

c0020eff <thread_tid>:
{
c0020eff:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->tid;
c0020f02:	e8 25 ff ff ff       	call   c0020e2c <thread_current>
c0020f07:	8b 00                	mov    (%eax),%eax
}
c0020f09:	83 c4 0c             	add    $0xc,%esp
c0020f0c:	c3                   	ret    

c0020f0d <thread_foreach>:
{
c0020f0d:	57                   	push   %edi
c0020f0e:	56                   	push   %esi
c0020f0f:	53                   	push   %ebx
c0020f10:	83 ec 20             	sub    $0x20,%esp
c0020f13:	8b 74 24 30          	mov    0x30(%esp),%esi
c0020f17:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0020f1b:	e8 a4 0a 00 00       	call   c00219c4 <intr_get_level>
c0020f20:	85 c0                	test   %eax,%eax
c0020f22:	74 2c                	je     c0020f50 <thread_foreach+0x43>
c0020f24:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0020f2b:	c0 
c0020f2c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0020f33:	c0 
c0020f34:	c7 44 24 08 e2 d0 02 	movl   $0xc002d0e2,0x8(%esp)
c0020f3b:	c0 
c0020f3c:	c7 44 24 04 eb 01 00 	movl   $0x1eb,0x4(%esp)
c0020f43:	00 
c0020f44:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0020f4b:	e8 63 7a 00 00       	call   c00289b3 <debug_panic>
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020f50:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f57:	e8 75 7b 00 00       	call   c0028ad1 <list_begin>
c0020f5c:	89 c3                	mov    %eax,%ebx
c0020f5e:	eb 16                	jmp    c0020f76 <thread_foreach+0x69>
      func (t, aux);
c0020f60:	89 7c 24 04          	mov    %edi,0x4(%esp)
      struct thread *t = list_entry (e, struct thread, allelem);
c0020f64:	8d 43 e0             	lea    -0x20(%ebx),%eax
      func (t, aux);
c0020f67:	89 04 24             	mov    %eax,(%esp)
c0020f6a:	ff d6                	call   *%esi
       e = list_next (e))
c0020f6c:	89 1c 24             	mov    %ebx,(%esp)
c0020f6f:	e8 9b 7b 00 00       	call   c0028b0f <list_next>
c0020f74:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020f76:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f7d:	e8 e1 7b 00 00       	call   c0028b63 <list_end>
c0020f82:	39 d8                	cmp    %ebx,%eax
c0020f84:	75 da                	jne    c0020f60 <thread_foreach+0x53>
}
c0020f86:	83 c4 20             	add    $0x20,%esp
c0020f89:	5b                   	pop    %ebx
c0020f8a:	5e                   	pop    %esi
c0020f8b:	5f                   	pop    %edi
c0020f8c:	c3                   	ret    

c0020f8d <thread_get_priority>:
{
c0020f8d:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->priority;
c0020f90:	e8 97 fe ff ff       	call   c0020e2c <thread_current>
c0020f95:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0020f98:	83 c4 0c             	add    $0xc,%esp
c0020f9b:	c3                   	ret    

c0020f9c <thread_get_nice>:
{
c0020f9c:	83 ec 0c             	sub    $0xc,%esp
  return thread_current()->nice;
c0020f9f:	e8 88 fe ff ff       	call   c0020e2c <thread_current>
c0020fa4:	8b 40 54             	mov    0x54(%eax),%eax
}
c0020fa7:	83 c4 0c             	add    $0xc,%esp
c0020faa:	c3                   	ret    

c0020fab <thread_get_load_avg>:
{
c0020fab:	83 ec 04             	sub    $0x4,%esp
    return x * n;
c0020fae:	6b 05 1c 5c 03 c0 64 	imul   $0x64,0xc0035c1c,%eax
  return convertXtoIntRoundNear(i);
c0020fb5:	89 04 24             	mov    %eax,(%esp)
c0020fb8:	e8 96 f9 ff ff       	call   c0020953 <convertXtoIntRoundNear>
}
c0020fbd:	83 c4 04             	add    $0x4,%esp
c0020fc0:	c3                   	ret    

c0020fc1 <thread_get_recent_cpu>:
{
c0020fc1:	83 ec 1c             	sub    $0x1c,%esp
  int i = multXbyN(thread_current()->recent_cpu,100);
c0020fc4:	e8 63 fe ff ff       	call   c0020e2c <thread_current>
    return x * n;
c0020fc9:	6b 40 58 64          	imul   $0x64,0x58(%eax),%eax
  return convertXtoIntRoundNear(i);
c0020fcd:	89 04 24             	mov    %eax,(%esp)
c0020fd0:	e8 7e f9 ff ff       	call   c0020953 <convertXtoIntRoundNear>
}
c0020fd5:	83 c4 1c             	add    $0x1c,%esp
c0020fd8:	c3                   	ret    

c0020fd9 <calculate_recent_cpu>:
{
c0020fd9:	55                   	push   %ebp
c0020fda:	57                   	push   %edi
c0020fdb:	56                   	push   %esi
c0020fdc:	53                   	push   %ebx
c0020fdd:	83 ec 2c             	sub    $0x2c,%esp
c0020fe0:	8b 7c 24 40          	mov    0x40(%esp),%edi
  int doub_load = 2 * system_load_avg;
c0020fe4:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0020fe9:	8d 0c 00             	lea    (%eax,%eax,1),%ecx
    return x + (n * f);
c0020fec:	8b 35 bc 7b 03 c0    	mov    0xc0037bbc,%esi
    return ((int64_t) x) * f / y;
c0020ff2:	89 74 24 18          	mov    %esi,0x18(%esp)
c0020ff6:	89 f0                	mov    %esi,%eax
c0020ff8:	c1 f8 1f             	sar    $0x1f,%eax
c0020ffb:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0020fff:	89 c8                	mov    %ecx,%eax
c0021001:	99                   	cltd   
c0021002:	89 d3                	mov    %edx,%ebx
c0021004:	0f af de             	imul   %esi,%ebx
c0021007:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002100b:	0f af c1             	imul   %ecx,%eax
c002100e:	01 c3                	add    %eax,%ebx
c0021010:	89 c8                	mov    %ecx,%eax
c0021012:	f7 e6                	mul    %esi
c0021014:	01 da                	add    %ebx,%edx
    return x + (n * f);
c0021016:	01 f1                	add    %esi,%ecx
    return ((int64_t) x) * f / y;
c0021018:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002101c:	89 cb                	mov    %ecx,%ebx
c002101e:	c1 fb 1f             	sar    $0x1f,%ebx
c0021021:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0021025:	89 04 24             	mov    %eax,(%esp)
c0021028:	89 54 24 04          	mov    %edx,0x4(%esp)
c002102c:	e8 e2 72 00 00       	call   c0028313 <__divdi3>
    return ((int64_t) x) * y / f;
c0021031:	89 c3                	mov    %eax,%ebx
c0021033:	c1 fb 1f             	sar    $0x1f,%ebx
c0021036:	8b 6f 58             	mov    0x58(%edi),%ebp
c0021039:	89 e9                	mov    %ebp,%ecx
c002103b:	c1 f9 1f             	sar    $0x1f,%ecx
c002103e:	0f af dd             	imul   %ebp,%ebx
c0021041:	89 ca                	mov    %ecx,%edx
c0021043:	0f af d0             	imul   %eax,%edx
c0021046:	8d 0c 13             	lea    (%ebx,%edx,1),%ecx
c0021049:	f7 e5                	mul    %ebp
c002104b:	01 ca                	add    %ecx,%edx
c002104d:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c0021051:	8b 5c 24 1c          	mov    0x1c(%esp),%ebx
c0021055:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0021059:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002105d:	89 04 24             	mov    %eax,(%esp)
c0021060:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021064:	e8 aa 72 00 00       	call   c0028313 <__divdi3>
    return x + (n * f);
c0021069:	0f af 77 54          	imul   0x54(%edi),%esi
c002106d:	01 f0                	add    %esi,%eax
c002106f:	89 47 58             	mov    %eax,0x58(%edi)
}
c0021072:	83 c4 2c             	add    $0x2c,%esp
c0021075:	5b                   	pop    %ebx
c0021076:	5e                   	pop    %esi
c0021077:	5f                   	pop    %edi
c0021078:	5d                   	pop    %ebp
c0021079:	c3                   	ret    

c002107a <calcPrio>:
{
c002107a:	56                   	push   %esi
c002107b:	53                   	push   %ebx
c002107c:	83 ec 14             	sub    $0x14,%esp
c002107f:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  int oldPrio = t->priority;
c0021083:	8b 73 1c             	mov    0x1c(%ebx),%esi
  t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0021086:	8b 43 58             	mov    0x58(%ebx),%eax
c0021089:	8d 50 03             	lea    0x3(%eax),%edx
c002108c:	85 c0                	test   %eax,%eax
c002108e:	0f 48 c2             	cmovs  %edx,%eax
c0021091:	c1 f8 02             	sar    $0x2,%eax
c0021094:	89 04 24             	mov    %eax,(%esp)
c0021097:	e8 b7 f8 ff ff       	call   c0020953 <convertXtoIntRoundNear>
c002109c:	ba 3f 00 00 00       	mov    $0x3f,%edx
c00210a1:	29 c2                	sub    %eax,%edx
c00210a3:	89 d0                	mov    %edx,%eax
c00210a5:	8b 53 54             	mov    0x54(%ebx),%edx
c00210a8:	f7 da                	neg    %edx
c00210aa:	8d 04 50             	lea    (%eax,%edx,2),%eax
  if(t->priority > PRI_MAX)
c00210ad:	83 f8 3f             	cmp    $0x3f,%eax
c00210b0:	7e 09                	jle    c00210bb <calcPrio+0x41>
    t->priority = PRI_MAX;
c00210b2:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c00210b9:	eb 0d                	jmp    c00210c8 <calcPrio+0x4e>
  t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c00210bb:	85 c0                	test   %eax,%eax
c00210bd:	ba 00 00 00 00       	mov    $0x0,%edx
c00210c2:	0f 48 c2             	cmovs  %edx,%eax
c00210c5:	89 43 1c             	mov    %eax,0x1c(%ebx)
  if(oldPrio != t->priority && t->status == THREAD_READY)
c00210c8:	39 73 1c             	cmp    %esi,0x1c(%ebx)
c00210cb:	74 28                	je     c00210f5 <calcPrio+0x7b>
c00210cd:	83 7b 04 01          	cmpl   $0x1,0x4(%ebx)
c00210d1:	75 22                	jne    c00210f5 <calcPrio+0x7b>
     list_remove(&t->elem);
c00210d3:	8d 73 28             	lea    0x28(%ebx),%esi
c00210d6:	89 34 24             	mov    %esi,(%esp)
c00210d9:	e8 46 7f 00 00       	call   c0029024 <list_remove>
     list_push_back (&mlfqs_list[t->priority], &t->elem);
c00210de:	89 74 24 04          	mov    %esi,0x4(%esp)
c00210e2:	8b 43 1c             	mov    0x1c(%ebx),%eax
c00210e5:	c1 e0 04             	shl    $0x4,%eax
c00210e8:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c00210ed:	89 04 24             	mov    %eax,(%esp)
c00210f0:	e8 0c 7f 00 00       	call   c0029001 <list_push_back>
}
c00210f5:	83 c4 14             	add    $0x14,%esp
c00210f8:	5b                   	pop    %ebx
c00210f9:	5e                   	pop    %esi
c00210fa:	c3                   	ret    

c00210fb <get_ready_threads>:
{
c00210fb:	57                   	push   %edi
c00210fc:	56                   	push   %esi
c00210fd:	53                   	push   %ebx
c00210fe:	83 ec 10             	sub    $0x10,%esp
c0021101:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0021106:	bf 20 60 03 c0       	mov    $0xc0036020,%edi
  int all_ready = 0;
c002110b:	be 00 00 00 00       	mov    $0x0,%esi
     all_ready += list_size(&mlfqs_list[i]);
c0021110:	89 1c 24             	mov    %ebx,(%esp)
c0021113:	e8 61 7f 00 00       	call   c0029079 <list_size>
c0021118:	01 c6                	add    %eax,%esi
c002111a:	83 c3 10             	add    $0x10,%ebx
  for(i=0;i<64;i++)
c002111d:	39 fb                	cmp    %edi,%ebx
c002111f:	75 ef                	jne    c0021110 <get_ready_threads+0x15>
  asm ("mov %%esp, %0" : "=g" (esp));
c0021121:	89 e0                	mov    %esp,%eax
c0021123:	25 00 f0 ff ff       	and    $0xfffff000,%eax
     all_ready++;
c0021128:	39 05 08 5c 03 c0    	cmp    %eax,0xc0035c08
c002112e:	0f 95 c0             	setne  %al
c0021131:	0f b6 c0             	movzbl %al,%eax
c0021134:	01 c6                	add    %eax,%esi
}
c0021136:	89 f0                	mov    %esi,%eax
c0021138:	83 c4 10             	add    $0x10,%esp
c002113b:	5b                   	pop    %ebx
c002113c:	5e                   	pop    %esi
c002113d:	5f                   	pop    %edi
c002113e:	c3                   	ret    

c002113f <getLoadAv>:
}
c002113f:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0021144:	c3                   	ret    

c0021145 <setLoadAv>:
  system_load_avg = load;
c0021145:	8b 44 24 04          	mov    0x4(%esp),%eax
c0021149:	a3 1c 5c 03 c0       	mov    %eax,0xc0035c1c
c002114e:	c3                   	ret    

c002114f <get_idle_thread>:
}
c002114f:	a1 08 5c 03 c0       	mov    0xc0035c08,%eax
c0021154:	c3                   	ret    

c0021155 <thread_schedule_tail>:
{
c0021155:	56                   	push   %esi
c0021156:	53                   	push   %ebx
c0021157:	83 ec 24             	sub    $0x24,%esp
c002115a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  asm ("mov %%esp, %0" : "=g" (esp));
c002115e:	89 e6                	mov    %esp,%esi
c0021160:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
  ASSERT (intr_get_level () == INTR_OFF);
c0021166:	e8 59 08 00 00       	call   c00219c4 <intr_get_level>
c002116b:	85 c0                	test   %eax,%eax
c002116d:	74 2c                	je     c002119b <thread_schedule_tail+0x46>
c002116f:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0021176:	c0 
c0021177:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002117e:	c0 
c002117f:	c7 44 24 08 b9 d0 02 	movl   $0xc002d0b9,0x8(%esp)
c0021186:	c0 
c0021187:	c7 44 24 04 68 03 00 	movl   $0x368,0x4(%esp)
c002118e:	00 
c002118f:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021196:	e8 18 78 00 00       	call   c00289b3 <debug_panic>
  cur->status = THREAD_RUNNING;
c002119b:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
  thread_ticks = 0;
c00211a2:	c7 05 c0 5b 03 c0 00 	movl   $0x0,0xc0035bc0
c00211a9:	00 00 00 
  if (prev != NULL && prev->status == THREAD_DYING && prev != initial_thread) 
c00211ac:	85 db                	test   %ebx,%ebx
c00211ae:	74 46                	je     c00211f6 <thread_schedule_tail+0xa1>
c00211b0:	83 7b 04 03          	cmpl   $0x3,0x4(%ebx)
c00211b4:	75 40                	jne    c00211f6 <thread_schedule_tail+0xa1>
c00211b6:	3b 1d 04 5c 03 c0    	cmp    0xc0035c04,%ebx
c00211bc:	74 38                	je     c00211f6 <thread_schedule_tail+0xa1>
      ASSERT (prev != cur);
c00211be:	39 f3                	cmp    %esi,%ebx
c00211c0:	75 2c                	jne    c00211ee <thread_schedule_tail+0x99>
c00211c2:	c7 44 24 10 a7 e5 02 	movl   $0xc002e5a7,0x10(%esp)
c00211c9:	c0 
c00211ca:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00211d1:	c0 
c00211d2:	c7 44 24 08 b9 d0 02 	movl   $0xc002d0b9,0x8(%esp)
c00211d9:	c0 
c00211da:	c7 44 24 04 7c 03 00 	movl   $0x37c,0x4(%esp)
c00211e1:	00 
c00211e2:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00211e9:	e8 c5 77 00 00       	call   c00289b3 <debug_panic>
      palloc_free_page (prev);
c00211ee:	89 1c 24             	mov    %ebx,(%esp)
c00211f1:	e8 ea 25 00 00       	call   c00237e0 <palloc_free_page>
}
c00211f6:	83 c4 24             	add    $0x24,%esp
c00211f9:	5b                   	pop    %ebx
c00211fa:	5e                   	pop    %esi
c00211fb:	c3                   	ret    

c00211fc <schedule>:
{
c00211fc:	57                   	push   %edi
c00211fd:	56                   	push   %esi
c00211fe:	53                   	push   %ebx
c00211ff:	83 ec 20             	sub    $0x20,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0021202:	89 e7                	mov    %esp,%edi
c0021204:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
  if(thread_mlfqs)
c002120a:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0021211:	74 2a                	je     c002123d <schedule+0x41>
c0021213:	be 10 60 03 c0       	mov    $0xc0036010,%esi
c0021218:	bb 3f 00 00 00       	mov    $0x3f,%ebx
      if(list_empty(&mlfqs_list[i])){
c002121d:	89 34 24             	mov    %esi,(%esp)
c0021220:	e8 91 7e 00 00       	call   c00290b6 <list_empty>
c0021225:	84 c0                	test   %al,%al
c0021227:	0f 84 db 00 00 00    	je     c0021308 <schedule+0x10c>
         i--;
c002122d:	83 eb 01             	sub    $0x1,%ebx
c0021230:	83 ee 10             	sub    $0x10,%esi
    while(i>=0){
c0021233:	83 fb ff             	cmp    $0xffffffff,%ebx
c0021236:	75 e5                	jne    c002121d <schedule+0x21>
c0021238:	e9 e4 00 00 00       	jmp    c0021321 <schedule+0x125>
    if (list_empty (&ready_list))
c002123d:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021244:	e8 6d 7e 00 00       	call   c00290b6 <list_empty>
      return idle_thread;
c0021249:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
    if (list_empty (&ready_list))
c002124f:	84 c0                	test   %al,%al
c0021251:	75 29                	jne    c002127c <schedule+0x80>
      struct list_elem *temp = list_max (&ready_list,threadPrioCompare,NULL); 
c0021253:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c002125a:	00 
c002125b:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c0021262:	c0 
c0021263:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c002126a:	e8 1b 84 00 00       	call   c002968a <list_max>
c002126f:	89 c3                	mov    %eax,%ebx
      list_remove(temp);
c0021271:	89 04 24             	mov    %eax,(%esp)
c0021274:	e8 ab 7d 00 00       	call   c0029024 <list_remove>
      return list_entry(temp,struct thread,elem);
c0021279:	83 eb 28             	sub    $0x28,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c002127c:	e8 43 07 00 00       	call   c00219c4 <intr_get_level>
c0021281:	85 c0                	test   %eax,%eax
c0021283:	74 2c                	je     c00212b1 <schedule+0xb5>
c0021285:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c002128c:	c0 
c002128d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021294:	c0 
c0021295:	c7 44 24 08 28 d1 02 	movl   $0xc002d128,0x8(%esp)
c002129c:	c0 
c002129d:	c7 44 24 04 8e 03 00 	movl   $0x38e,0x4(%esp)
c00212a4:	00 
c00212a5:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00212ac:	e8 02 77 00 00       	call   c00289b3 <debug_panic>
  ASSERT (cur->status != THREAD_RUNNING);
c00212b1:	83 7f 04 00          	cmpl   $0x0,0x4(%edi)
c00212b5:	75 2c                	jne    c00212e3 <schedule+0xe7>
c00212b7:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c00212be:	c0 
c00212bf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00212c6:	c0 
c00212c7:	c7 44 24 08 28 d1 02 	movl   $0xc002d128,0x8(%esp)
c00212ce:	c0 
c00212cf:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
c00212d6:	00 
c00212d7:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00212de:	e8 d0 76 00 00       	call   c00289b3 <debug_panic>
  return t != NULL && t->magic == THREAD_MAGIC;
c00212e3:	85 db                	test   %ebx,%ebx
c00212e5:	74 50                	je     c0021337 <schedule+0x13b>
c00212e7:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c00212ee:	75 47                	jne    c0021337 <schedule+0x13b>
c00212f0:	eb 3a                	jmp    c002132c <schedule+0x130>
    prev = switch_threads (cur, next);
c00212f2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00212f6:	89 3c 24             	mov    %edi,(%esp)
c00212f9:	e8 40 05 00 00       	call   c002183e <switch_threads>
  thread_schedule_tail (prev);
c00212fe:	89 04 24             	mov    %eax,(%esp)
c0021301:	e8 4f fe ff ff       	call   c0021155 <thread_schedule_tail>
c0021306:	eb 5b                	jmp    c0021363 <schedule+0x167>
      return list_entry(list_pop_front (&mlfqs_list[i]), struct thread, elem); 
c0021308:	c1 e3 04             	shl    $0x4,%ebx
c002130b:	81 c3 20 5c 03 c0    	add    $0xc0035c20,%ebx
c0021311:	89 1c 24             	mov    %ebx,(%esp)
c0021314:	e8 0b 7e 00 00       	call   c0029124 <list_pop_front>
c0021319:	8d 58 d8             	lea    -0x28(%eax),%ebx
c002131c:	e9 5b ff ff ff       	jmp    c002127c <schedule+0x80>
      return idle_thread;
c0021321:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
c0021327:	e9 50 ff ff ff       	jmp    c002127c <schedule+0x80>
  struct thread *prev = NULL;
c002132c:	b8 00 00 00 00       	mov    $0x0,%eax
  if (cur != next)
c0021331:	39 df                	cmp    %ebx,%edi
c0021333:	74 c9                	je     c00212fe <schedule+0x102>
c0021335:	eb bb                	jmp    c00212f2 <schedule+0xf6>
  ASSERT (is_thread (next));
c0021337:	c7 44 24 10 d1 e5 02 	movl   $0xc002e5d1,0x10(%esp)
c002133e:	c0 
c002133f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021346:	c0 
c0021347:	c7 44 24 08 28 d1 02 	movl   $0xc002d128,0x8(%esp)
c002134e:	c0 
c002134f:	c7 44 24 04 90 03 00 	movl   $0x390,0x4(%esp)
c0021356:	00 
c0021357:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c002135e:	e8 50 76 00 00       	call   c00289b3 <debug_panic>
}
c0021363:	83 c4 20             	add    $0x20,%esp
c0021366:	5b                   	pop    %ebx
c0021367:	5e                   	pop    %esi
c0021368:	5f                   	pop    %edi
c0021369:	c3                   	ret    

c002136a <thread_block>:
{
c002136a:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c002136d:	e8 ff 08 00 00       	call   c0021c71 <intr_context>
c0021372:	84 c0                	test   %al,%al
c0021374:	74 2c                	je     c00213a2 <thread_block+0x38>
c0021376:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c002137d:	c0 
c002137e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021385:	c0 
c0021386:	c7 44 24 08 31 d1 02 	movl   $0xc002d131,0x8(%esp)
c002138d:	c0 
c002138e:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c0021395:	00 
c0021396:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c002139d:	e8 11 76 00 00       	call   c00289b3 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c00213a2:	e8 1d 06 00 00       	call   c00219c4 <intr_get_level>
c00213a7:	85 c0                	test   %eax,%eax
c00213a9:	74 2c                	je     c00213d7 <thread_block+0x6d>
c00213ab:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00213b2:	c0 
c00213b3:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00213ba:	c0 
c00213bb:	c7 44 24 08 31 d1 02 	movl   $0xc002d131,0x8(%esp)
c00213c2:	c0 
c00213c3:	c7 44 24 04 6d 01 00 	movl   $0x16d,0x4(%esp)
c00213ca:	00 
c00213cb:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00213d2:	e8 dc 75 00 00       	call   c00289b3 <debug_panic>
  thread_current ()->status = THREAD_BLOCKED;
c00213d7:	e8 50 fa ff ff       	call   c0020e2c <thread_current>
c00213dc:	c7 40 04 02 00 00 00 	movl   $0x2,0x4(%eax)
  schedule ();
c00213e3:	e8 14 fe ff ff       	call   c00211fc <schedule>
}
c00213e8:	83 c4 2c             	add    $0x2c,%esp
c00213eb:	c3                   	ret    

c00213ec <idle>:
{
c00213ec:	83 ec 1c             	sub    $0x1c,%esp
  idle_thread = thread_current ();
c00213ef:	e8 38 fa ff ff       	call   c0020e2c <thread_current>
c00213f4:	a3 08 5c 03 c0       	mov    %eax,0xc0035c08
  sema_up (idle_started);
c00213f9:	8b 44 24 20          	mov    0x20(%esp),%eax
c00213fd:	89 04 24             	mov    %eax,(%esp)
c0021400:	e8 92 18 00 00       	call   c0022c97 <sema_up>
      intr_disable ();
c0021405:	e8 05 06 00 00       	call   c0021a0f <intr_disable>
      thread_block ();
c002140a:	e8 5b ff ff ff       	call   c002136a <thread_block>
      asm volatile ("sti; hlt" : : : "memory");
c002140f:	fb                   	sti    
c0021410:	f4                   	hlt    
c0021411:	eb f2                	jmp    c0021405 <idle+0x19>

c0021413 <thread_exit>:
{
c0021413:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c0021416:	e8 56 08 00 00       	call   c0021c71 <intr_context>
c002141b:	84 c0                	test   %al,%al
c002141d:	74 2c                	je     c002144b <thread_exit+0x38>
c002141f:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0021426:	c0 
c0021427:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002142e:	c0 
c002142f:	c7 44 24 08 fe d0 02 	movl   $0xc002d0fe,0x8(%esp)
c0021436:	c0 
c0021437:	c7 44 24 04 b7 01 00 	movl   $0x1b7,0x4(%esp)
c002143e:	00 
c002143f:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021446:	e8 68 75 00 00       	call   c00289b3 <debug_panic>
  intr_disable ();
c002144b:	e8 bf 05 00 00       	call   c0021a0f <intr_disable>
  list_remove (&thread_current()->allelem);
c0021450:	e8 d7 f9 ff ff       	call   c0020e2c <thread_current>
c0021455:	83 c0 20             	add    $0x20,%eax
c0021458:	89 04 24             	mov    %eax,(%esp)
c002145b:	e8 c4 7b 00 00       	call   c0029024 <list_remove>
  thread_current ()->status = THREAD_DYING;
c0021460:	e8 c7 f9 ff ff       	call   c0020e2c <thread_current>
c0021465:	c7 40 04 03 00 00 00 	movl   $0x3,0x4(%eax)
  schedule ();
c002146c:	e8 8b fd ff ff       	call   c00211fc <schedule>
  NOT_REACHED ();
c0021471:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0021478:	c0 
c0021479:	c7 44 24 08 fe d0 02 	movl   $0xc002d0fe,0x8(%esp)
c0021480:	c0 
c0021481:	c7 44 24 04 c4 01 00 	movl   $0x1c4,0x4(%esp)
c0021488:	00 
c0021489:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021490:	e8 1e 75 00 00       	call   c00289b3 <debug_panic>

c0021495 <kernel_thread>:
{
c0021495:	53                   	push   %ebx
c0021496:	83 ec 28             	sub    $0x28,%esp
c0021499:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (function != NULL);
c002149d:	85 db                	test   %ebx,%ebx
c002149f:	75 2c                	jne    c00214cd <kernel_thread+0x38>
c00214a1:	c7 44 24 10 f3 e5 02 	movl   $0xc002e5f3,0x10(%esp)
c00214a8:	c0 
c00214a9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00214b0:	c0 
c00214b1:	c7 44 24 08 4a d1 02 	movl   $0xc002d14a,0x8(%esp)
c00214b8:	c0 
c00214b9:	c7 44 24 04 d2 02 00 	movl   $0x2d2,0x4(%esp)
c00214c0:	00 
c00214c1:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00214c8:	e8 e6 74 00 00       	call   c00289b3 <debug_panic>
  intr_enable ();       /* The scheduler runs with interrupts off. */
c00214cd:	e8 fb 04 00 00       	call   c00219cd <intr_enable>
  function (aux);       /* Execute the thread function. */
c00214d2:	8b 44 24 34          	mov    0x34(%esp),%eax
c00214d6:	89 04 24             	mov    %eax,(%esp)
c00214d9:	ff d3                	call   *%ebx
  thread_exit ();       /* If function() returns, kill the thread. */
c00214db:	e8 33 ff ff ff       	call   c0021413 <thread_exit>

c00214e0 <thread_yield>:
{
c00214e0:	56                   	push   %esi
c00214e1:	53                   	push   %ebx
c00214e2:	83 ec 24             	sub    $0x24,%esp
  struct thread *cur = thread_current ();
c00214e5:	e8 42 f9 ff ff       	call   c0020e2c <thread_current>
c00214ea:	89 c3                	mov    %eax,%ebx
  ASSERT (!intr_context ());
c00214ec:	e8 80 07 00 00       	call   c0021c71 <intr_context>
c00214f1:	84 c0                	test   %al,%al
c00214f3:	74 2c                	je     c0021521 <thread_yield+0x41>
c00214f5:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c00214fc:	c0 
c00214fd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021504:	c0 
c0021505:	c7 44 24 08 f1 d0 02 	movl   $0xc002d0f1,0x8(%esp)
c002150c:	c0 
c002150d:	c7 44 24 04 cf 01 00 	movl   $0x1cf,0x4(%esp)
c0021514:	00 
c0021515:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c002151c:	e8 92 74 00 00       	call   c00289b3 <debug_panic>
  old_level = intr_disable ();
c0021521:	e8 e9 04 00 00       	call   c0021a0f <intr_disable>
c0021526:	89 c6                	mov    %eax,%esi
  if (cur != idle_thread) 
c0021528:	3b 1d 08 5c 03 c0    	cmp    0xc0035c08,%ebx
c002152e:	74 38                	je     c0021568 <thread_yield+0x88>
    if(thread_mlfqs) {
c0021530:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0021537:	74 1c                	je     c0021555 <thread_yield+0x75>
      list_push_back (&mlfqs_list[cur->priority], &cur->elem);
c0021539:	8d 43 28             	lea    0x28(%ebx),%eax
c002153c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021540:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021543:	c1 e0 04             	shl    $0x4,%eax
c0021546:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c002154b:	89 04 24             	mov    %eax,(%esp)
c002154e:	e8 ae 7a 00 00       	call   c0029001 <list_push_back>
c0021553:	eb 13                	jmp    c0021568 <thread_yield+0x88>
      list_push_back (&ready_list, &cur->elem);
c0021555:	8d 43 28             	lea    0x28(%ebx),%eax
c0021558:	89 44 24 04          	mov    %eax,0x4(%esp)
c002155c:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021563:	e8 99 7a 00 00       	call   c0029001 <list_push_back>
  cur->status = THREAD_READY;
c0021568:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  schedule ();
c002156f:	e8 88 fc ff ff       	call   c00211fc <schedule>
  intr_set_level (old_level);
c0021574:	89 34 24             	mov    %esi,(%esp)
c0021577:	e8 9a 04 00 00       	call   c0021a16 <intr_set_level>
}
c002157c:	83 c4 24             	add    $0x24,%esp
c002157f:	5b                   	pop    %ebx
c0021580:	5e                   	pop    %esi
c0021581:	c3                   	ret    

c0021582 <thread_create>:
{
c0021582:	55                   	push   %ebp
c0021583:	57                   	push   %edi
c0021584:	56                   	push   %esi
c0021585:	53                   	push   %ebx
c0021586:	83 ec 2c             	sub    $0x2c,%esp
c0021589:	8b 7c 24 48          	mov    0x48(%esp),%edi
  ASSERT (function != NULL);
c002158d:	85 ff                	test   %edi,%edi
c002158f:	75 2c                	jne    c00215bd <thread_create+0x3b>
c0021591:	c7 44 24 10 f3 e5 02 	movl   $0xc002e5f3,0x10(%esp)
c0021598:	c0 
c0021599:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00215a0:	c0 
c00215a1:	c7 44 24 08 58 d1 02 	movl   $0xc002d158,0x8(%esp)
c00215a8:	c0 
c00215a9:	c7 44 24 04 2f 01 00 	movl   $0x12f,0x4(%esp)
c00215b0:	00 
c00215b1:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c00215b8:	e8 f6 73 00 00       	call   c00289b3 <debug_panic>
  t = palloc_get_page (PAL_ZERO);
c00215bd:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00215c4:	e8 ad 20 00 00       	call   c0023676 <palloc_get_page>
c00215c9:	89 c3                	mov    %eax,%ebx
  if (t == NULL)
c00215cb:	85 c0                	test   %eax,%eax
c00215cd:	0f 84 c4 00 00 00    	je     c0021697 <thread_create+0x115>
  t->nice = thread_current()->nice; //get parent's nice value
c00215d3:	e8 54 f8 ff ff       	call   c0020e2c <thread_current>
c00215d8:	8b 40 54             	mov    0x54(%eax),%eax
c00215db:	89 43 54             	mov    %eax,0x54(%ebx)
  t->recent_cpu = thread_current()->recent_cpu; //get parent's recent_cpu value
c00215de:	e8 49 f8 ff ff       	call   c0020e2c <thread_current>
c00215e3:	8b 40 58             	mov    0x58(%eax),%eax
c00215e6:	89 43 58             	mov    %eax,0x58(%ebx)
  init_thread (t, name, priority);
c00215e9:	8b 4c 24 44          	mov    0x44(%esp),%ecx
c00215ed:	8b 54 24 40          	mov    0x40(%esp),%edx
c00215f1:	89 d8                	mov    %ebx,%eax
c00215f3:	e8 8d f3 ff ff       	call   c0020985 <init_thread>
  lock_acquire (&tid_lock);
c00215f8:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c00215ff:	e8 a6 18 00 00       	call   c0022eaa <lock_acquire>
  tid = next_tid++;
c0021604:	8b 35 54 56 03 c0    	mov    0xc0035654,%esi
c002160a:	8d 46 01             	lea    0x1(%esi),%eax
c002160d:	a3 54 56 03 c0       	mov    %eax,0xc0035654
  lock_release (&tid_lock);
c0021612:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0021619:	e8 56 1a 00 00       	call   c0023074 <lock_release>
  tid = t->tid = allocate_tid ();
c002161e:	89 33                	mov    %esi,(%ebx)
  old_level = intr_disable ();
c0021620:	e8 ea 03 00 00       	call   c0021a0f <intr_disable>
c0021625:	89 c5                	mov    %eax,%ebp
  kf = alloc_frame (t, sizeof *kf);
c0021627:	ba 0c 00 00 00       	mov    $0xc,%edx
c002162c:	89 d8                	mov    %ebx,%eax
c002162e:	e8 2f f2 ff ff       	call   c0020862 <alloc_frame>
  kf->eip = NULL;
c0021633:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  kf->function = function;
c0021639:	89 78 04             	mov    %edi,0x4(%eax)
  kf->aux = aux;
c002163c:	8b 54 24 4c          	mov    0x4c(%esp),%edx
c0021640:	89 50 08             	mov    %edx,0x8(%eax)
  ef = alloc_frame (t, sizeof *ef);
c0021643:	ba 04 00 00 00       	mov    $0x4,%edx
c0021648:	89 d8                	mov    %ebx,%eax
c002164a:	e8 13 f2 ff ff       	call   c0020862 <alloc_frame>
  ef->eip = (void (*) (void)) kernel_thread;
c002164f:	c7 00 95 14 02 c0    	movl   $0xc0021495,(%eax)
  sf = alloc_frame (t, sizeof *sf);
c0021655:	ba 1c 00 00 00       	mov    $0x1c,%edx
c002165a:	89 d8                	mov    %ebx,%eax
c002165c:	e8 01 f2 ff ff       	call   c0020862 <alloc_frame>
  sf->eip = switch_entry;
c0021661:	c7 40 10 5b 18 02 c0 	movl   $0xc002185b,0x10(%eax)
  sf->ebp = 0;
c0021668:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
  intr_set_level (old_level);
c002166f:	89 2c 24             	mov    %ebp,(%esp)
c0021672:	e8 9f 03 00 00       	call   c0021a16 <intr_set_level>
  thread_unblock (t);
c0021677:	89 1c 24             	mov    %ebx,(%esp)
c002167a:	e8 d4 f6 ff ff       	call   c0020d53 <thread_unblock>
  if(t->priority > thread_current()->priority)
c002167f:	e8 a8 f7 ff ff       	call   c0020e2c <thread_current>
  return tid;
c0021684:	89 f2                	mov    %esi,%edx
  if(t->priority > thread_current()->priority)
c0021686:	8b 40 1c             	mov    0x1c(%eax),%eax
c0021689:	39 43 1c             	cmp    %eax,0x1c(%ebx)
c002168c:	7e 0e                	jle    c002169c <thread_create+0x11a>
    thread_yield();
c002168e:	e8 4d fe ff ff       	call   c00214e0 <thread_yield>
  return tid;
c0021693:	89 f2                	mov    %esi,%edx
c0021695:	eb 05                	jmp    c002169c <thread_create+0x11a>
    return TID_ERROR;
c0021697:	ba ff ff ff ff       	mov    $0xffffffff,%edx
}
c002169c:	89 d0                	mov    %edx,%eax
c002169e:	83 c4 2c             	add    $0x2c,%esp
c00216a1:	5b                   	pop    %ebx
c00216a2:	5e                   	pop    %esi
c00216a3:	5f                   	pop    %edi
c00216a4:	5d                   	pop    %ebp
c00216a5:	c3                   	ret    

c00216a6 <thread_start>:
{
c00216a6:	53                   	push   %ebx
c00216a7:	83 ec 38             	sub    $0x38,%esp
  sema_init (&idle_started, 0);
c00216aa:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00216b1:	00 
c00216b2:	8d 5c 24 1c          	lea    0x1c(%esp),%ebx
c00216b6:	89 1c 24             	mov    %ebx,(%esp)
c00216b9:	e8 78 14 00 00       	call   c0022b36 <sema_init>
  thread_create ("idle", PRI_MIN, idle, &idle_started);
c00216be:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c00216c2:	c7 44 24 08 ec 13 02 	movl   $0xc00213ec,0x8(%esp)
c00216c9:	c0 
c00216ca:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00216d1:	00 
c00216d2:	c7 04 24 04 e6 02 c0 	movl   $0xc002e604,(%esp)
c00216d9:	e8 a4 fe ff ff       	call   c0021582 <thread_create>
  intr_enable ();
c00216de:	e8 ea 02 00 00       	call   c00219cd <intr_enable>
  sema_down (&idle_started);
c00216e3:	89 1c 24             	mov    %ebx,(%esp)
c00216e6:	e8 97 14 00 00       	call   c0022b82 <sema_down>
}
c00216eb:	83 c4 38             	add    $0x38,%esp
c00216ee:	5b                   	pop    %ebx
c00216ef:	c3                   	ret    

c00216f0 <thread_set_priority>:
{
c00216f0:	56                   	push   %esi
c00216f1:	53                   	push   %ebx
c00216f2:	83 ec 24             	sub    $0x24,%esp
c00216f5:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT(thread_mlfqs == false);
c00216f9:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0021700:	74 2c                	je     c002172e <thread_set_priority+0x3e>
c0021702:	c7 44 24 10 09 e6 02 	movl   $0xc002e609,0x10(%esp)
c0021709:	c0 
c002170a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0021711:	c0 
c0021712:	c7 44 24 08 ce d0 02 	movl   $0xc002d0ce,0x8(%esp)
c0021719:	c0 
c002171a:	c7 44 24 04 fa 01 00 	movl   $0x1fa,0x4(%esp)
c0021721:	00 
c0021722:	c7 04 24 1a e5 02 c0 	movl   $0xc002e51a,(%esp)
c0021729:	e8 85 72 00 00       	call   c00289b3 <debug_panic>
  old_level = intr_disable ();
c002172e:	e8 dc 02 00 00       	call   c0021a0f <intr_disable>
c0021733:	89 c6                	mov    %eax,%esi
  if(new_priority >= PRI_MIN && new_priority <= PRI_MAX) //REMOVE COMMENT: flipped this
c0021735:	83 fb 3f             	cmp    $0x3f,%ebx
c0021738:	77 68                	ja     c00217a2 <thread_set_priority+0xb2>
    if(new_priority > thread_current ()->priority)
c002173a:	e8 ed f6 ff ff       	call   c0020e2c <thread_current>
c002173f:	89 c2                	mov    %eax,%edx
c0021741:	8b 40 1c             	mov    0x1c(%eax),%eax
c0021744:	39 c3                	cmp    %eax,%ebx
c0021746:	7e 0d                	jle    c0021755 <thread_set_priority+0x65>
      thread_current ()->priority = new_priority;
c0021748:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c002174b:	e8 dc f6 ff ff       	call   c0020e2c <thread_current>
c0021750:	89 58 3c             	mov    %ebx,0x3c(%eax)
c0021753:	eb 15                	jmp    c002176a <thread_set_priority+0x7a>
    else if(thread_current ()->priority == thread_current ()->old_priority)
c0021755:	3b 42 3c             	cmp    0x3c(%edx),%eax
c0021758:	75 0d                	jne    c0021767 <thread_set_priority+0x77>
      thread_current ()->priority = new_priority;
c002175a:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c002175d:	e8 ca f6 ff ff       	call   c0020e2c <thread_current>
c0021762:	89 58 3c             	mov    %ebx,0x3c(%eax)
c0021765:	eb 03                	jmp    c002176a <thread_set_priority+0x7a>
      thread_current ()->old_priority = new_priority;
c0021767:	89 5a 3c             	mov    %ebx,0x3c(%edx)
    intr_set_level (old_level);
c002176a:	89 34 24             	mov    %esi,(%esp)
c002176d:	e8 a4 02 00 00       	call   c0021a16 <intr_set_level>
    int max_prio = list_entry(list_max (&ready_list,threadPrioCompare,NULL),struct thread,elem)->priority;
c0021772:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0021779:	00 
c002177a:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c0021781:	c0 
c0021782:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021789:	e8 fc 7e 00 00       	call   c002968a <list_max>
c002178e:	89 c3                	mov    %eax,%ebx
    if(max_prio > thread_current ()->priority)
c0021790:	e8 97 f6 ff ff       	call   c0020e2c <thread_current>
c0021795:	8b 40 1c             	mov    0x1c(%eax),%eax
c0021798:	39 43 f4             	cmp    %eax,-0xc(%ebx)
c002179b:	7e 05                	jle    c00217a2 <thread_set_priority+0xb2>
      thread_yield();
c002179d:	e8 3e fd ff ff       	call   c00214e0 <thread_yield>
}
c00217a2:	83 c4 24             	add    $0x24,%esp
c00217a5:	5b                   	pop    %ebx
c00217a6:	5e                   	pop    %esi
c00217a7:	c3                   	ret    

c00217a8 <thread_set_nice>:
{
c00217a8:	57                   	push   %edi
c00217a9:	56                   	push   %esi
c00217aa:	53                   	push   %ebx
c00217ab:	83 ec 10             	sub    $0x10,%esp
c00217ae:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread *curr_thread = thread_current();
c00217b2:	e8 75 f6 ff ff       	call   c0020e2c <thread_current>
c00217b7:	89 c7                	mov    %eax,%edi
  if(nice >= -20 && nice <= 20)
c00217b9:	8d 43 14             	lea    0x14(%ebx),%eax
c00217bc:	83 f8 28             	cmp    $0x28,%eax
c00217bf:	77 03                	ja     c00217c4 <thread_set_nice+0x1c>
    curr_thread->nice = nice;
c00217c1:	89 5f 54             	mov    %ebx,0x54(%edi)
  curr_thread->priority = PRI_MAX - convertXtoIntRoundNear(curr_thread->recent_cpu / 4) - (curr_thread->nice * 2);
c00217c4:	8b 47 58             	mov    0x58(%edi),%eax
c00217c7:	8d 50 03             	lea    0x3(%eax),%edx
c00217ca:	85 c0                	test   %eax,%eax
c00217cc:	0f 48 c2             	cmovs  %edx,%eax
c00217cf:	c1 f8 02             	sar    $0x2,%eax
c00217d2:	89 04 24             	mov    %eax,(%esp)
c00217d5:	e8 79 f1 ff ff       	call   c0020953 <convertXtoIntRoundNear>
c00217da:	ba 3f 00 00 00       	mov    $0x3f,%edx
c00217df:	29 c2                	sub    %eax,%edx
c00217e1:	89 d0                	mov    %edx,%eax
c00217e3:	8b 57 54             	mov    0x54(%edi),%edx
c00217e6:	f7 da                	neg    %edx
c00217e8:	8d 04 50             	lea    (%eax,%edx,2),%eax
  if(curr_thread->priority > PRI_MAX)
c00217eb:	83 f8 3f             	cmp    $0x3f,%eax
c00217ee:	7e 09                	jle    c00217f9 <thread_set_nice+0x51>
    curr_thread->priority = PRI_MAX;
c00217f0:	c7 47 1c 3f 00 00 00 	movl   $0x3f,0x1c(%edi)
c00217f7:	eb 32                	jmp    c002182b <thread_set_nice+0x83>
    curr_thread->priority = PRI_MIN;
c00217f9:	85 c0                	test   %eax,%eax
c00217fb:	ba 00 00 00 00       	mov    $0x0,%edx
c0021800:	0f 48 c2             	cmovs  %edx,%eax
c0021803:	89 47 1c             	mov    %eax,0x1c(%edi)
c0021806:	eb 23                	jmp    c002182b <thread_set_nice+0x83>
    if(list_empty(&mlfqs_list[i]) && curr_thread->priority > i){
c0021808:	89 34 24             	mov    %esi,(%esp)
c002180b:	e8 a6 78 00 00       	call   c00290b6 <list_empty>
c0021810:	84 c0                	test   %al,%al
c0021812:	74 0a                	je     c002181e <thread_set_nice+0x76>
c0021814:	39 5f 1c             	cmp    %ebx,0x1c(%edi)
c0021817:	7e 05                	jle    c002181e <thread_set_nice+0x76>
      thread_yield();  
c0021819:	e8 c2 fc ff ff       	call   c00214e0 <thread_yield>
  for(i = 0; i < 64; i++){
c002181e:	83 c3 01             	add    $0x1,%ebx
c0021821:	83 c6 10             	add    $0x10,%esi
c0021824:	83 fb 40             	cmp    $0x40,%ebx
c0021827:	75 df                	jne    c0021808 <thread_set_nice+0x60>
c0021829:	eb 0c                	jmp    c0021837 <thread_set_nice+0x8f>
c002182b:	be 20 5c 03 c0       	mov    $0xc0035c20,%esi
{
c0021830:	bb 00 00 00 00       	mov    $0x0,%ebx
c0021835:	eb d1                	jmp    c0021808 <thread_set_nice+0x60>
}
c0021837:	83 c4 10             	add    $0x10,%esp
c002183a:	5b                   	pop    %ebx
c002183b:	5e                   	pop    %esi
c002183c:	5f                   	pop    %edi
c002183d:	c3                   	ret    

c002183e <switch_threads>:
	# but requires us to preserve %ebx, %ebp, %esi, %edi.  See
	# [SysV-ABI-386] pages 3-11 and 3-12 for details.
	#
	# This stack frame must match the one set up by thread_create()
	# in size.
	pushl %ebx
c002183e:	53                   	push   %ebx
	pushl %ebp
c002183f:	55                   	push   %ebp
	pushl %esi
c0021840:	56                   	push   %esi
	pushl %edi
c0021841:	57                   	push   %edi

	# Get offsetof (struct thread, stack).
.globl thread_stack_ofs
	mov thread_stack_ofs, %edx
c0021842:	8b 15 58 56 03 c0    	mov    0xc0035658,%edx

	# Save current stack pointer to old thread's stack, if any.
	movl SWITCH_CUR(%esp), %eax
c0021848:	8b 44 24 14          	mov    0x14(%esp),%eax
	movl %esp, (%eax,%edx,1)
c002184c:	89 24 10             	mov    %esp,(%eax,%edx,1)

	# Restore stack pointer from new thread's stack.
	movl SWITCH_NEXT(%esp), %ecx
c002184f:	8b 4c 24 18          	mov    0x18(%esp),%ecx
	movl (%ecx,%edx,1), %esp
c0021853:	8b 24 11             	mov    (%ecx,%edx,1),%esp

	# Restore caller's register state.
	popl %edi
c0021856:	5f                   	pop    %edi
	popl %esi
c0021857:	5e                   	pop    %esi
	popl %ebp
c0021858:	5d                   	pop    %ebp
	popl %ebx
c0021859:	5b                   	pop    %ebx
        ret
c002185a:	c3                   	ret    

c002185b <switch_entry>:

.globl switch_entry
.func switch_entry
switch_entry:
	# Discard switch_threads() arguments.
	addl $8, %esp
c002185b:	83 c4 08             	add    $0x8,%esp

	# Call thread_schedule_tail(prev).
	pushl %eax
c002185e:	50                   	push   %eax
.globl thread_schedule_tail
	call thread_schedule_tail
c002185f:	e8 f1 f8 ff ff       	call   c0021155 <thread_schedule_tail>
	addl $4, %esp
c0021864:	83 c4 04             	add    $0x4,%esp

	# Start thread proper.
	ret
c0021867:	c3                   	ret    
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
c002189f:	e8 0f 71 00 00       	call   c00289b3 <debug_panic>
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
c00218d0:	e8 de 70 00 00       	call   c00289b3 <debug_panic>
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
c0021901:	e8 ad 70 00 00       	call   c00289b3 <debug_panic>

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
c0021962:	e8 4c 70 00 00       	call   c00289b3 <debug_panic>
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
c0021a05:	e8 a9 6f 00 00       	call   c00289b3 <debug_panic>
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
c0021be9:	e8 c5 6d 00 00       	call   c00289b3 <debug_panic>
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
c0021c49:	e8 65 6d 00 00       	call   c00289b3 <debug_panic>
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
c0021cac:	e8 02 6d 00 00       	call   c00289b3 <debug_panic>
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
c0021d02:	e8 ac 6c 00 00       	call   c00289b3 <debug_panic>
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
c0021d37:	e8 77 6c 00 00       	call   c00289b3 <debug_panic>

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
c0021d94:	e8 c5 4d 00 00       	call   c0026b5e <printf>
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
c0021dd3:	e8 db 6b 00 00       	call   c00289b3 <debug_panic>
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
c0021e08:	e8 a6 6b 00 00       	call   c00289b3 <debug_panic>
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
c0021e46:	e8 68 6b 00 00       	call   c00289b3 <debug_panic>
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
c0021e62:	e8 79 f6 ff ff       	call   c00214e0 <thread_yield>
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
c0021e99:	e8 c0 4c 00 00       	call   c0026b5e <printf>
  printf (" cr2=%08"PRIx32" error=%08"PRIx32"\n", cr2, f->error_code);
c0021e9e:	8b 43 34             	mov    0x34(%ebx),%eax
c0021ea1:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021ea5:	89 74 24 04          	mov    %esi,0x4(%esp)
c0021ea9:	c7 04 24 8b e8 02 c0 	movl   $0xc002e88b,(%esp)
c0021eb0:	e8 a9 4c 00 00       	call   c0026b5e <printf>
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
c0021ed8:	e8 81 4c 00 00       	call   c0026b5e <printf>
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
c0021eff:	e8 5a 4c 00 00       	call   c0026b5e <printf>
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
c0021f2b:	e8 2e 4c 00 00       	call   c0026b5e <printf>
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
c0022b68:	e8 46 5e 00 00       	call   c00289b3 <debug_panic>
  sema->value = value;
c0022b6d:	8b 54 24 34          	mov    0x34(%esp),%edx
c0022b71:	89 10                	mov    %edx,(%eax)
  list_init (&sema->waiters);
c0022b73:	83 c0 04             	add    $0x4,%eax
c0022b76:	89 04 24             	mov    %eax,(%esp)
c0022b79:	e8 02 5f 00 00       	call   c0028a80 <list_init>
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
c0022bb7:	e8 f7 5d 00 00       	call   c00289b3 <debug_panic>
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
c0022bec:	e8 c2 5d 00 00       	call   c00289b3 <debug_panic>
  old_level = intr_disable ();
c0022bf1:	e8 19 ee ff ff       	call   c0021a0f <intr_disable>
c0022bf6:	89 c7                	mov    %eax,%edi
  while (sema->value == 0) 
c0022bf8:	8b 13                	mov    (%ebx),%edx
c0022bfa:	85 d2                	test   %edx,%edx
c0022bfc:	75 22                	jne    c0022c20 <sema_down+0x9e>
      list_push_back (&sema->waiters, &thread_current ()->elem);
c0022bfe:	8d 73 04             	lea    0x4(%ebx),%esi
c0022c01:	e8 26 e2 ff ff       	call   c0020e2c <thread_current>
c0022c06:	83 c0 28             	add    $0x28,%eax
c0022c09:	89 44 24 04          	mov    %eax,0x4(%esp)
c0022c0d:	89 34 24             	mov    %esi,(%esp)
c0022c10:	e8 ec 63 00 00       	call   c0029001 <list_push_back>
      thread_block ();
c0022c15:	e8 50 e7 ff ff       	call   c002136a <thread_block>
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
c0022c68:	e8 46 5d 00 00       	call   c00289b3 <debug_panic>
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
c0022ccd:	e8 e1 5c 00 00       	call   c00289b3 <debug_panic>
  old_level = intr_disable ();
c0022cd2:	e8 38 ed ff ff       	call   c0021a0f <intr_disable>
c0022cd7:	89 c7                	mov    %eax,%edi
  if (!list_empty (&sema->waiters)) 
c0022cd9:	8d 73 04             	lea    0x4(%ebx),%esi
c0022cdc:	89 34 24             	mov    %esi,(%esp)
c0022cdf:	e8 d2 63 00 00       	call   c00290b6 <list_empty>
c0022ce4:	84 c0                	test   %al,%al
c0022ce6:	75 55                	jne    c0022d3d <sema_up+0xa6>
    max_prio_sema = list_max (&sema->waiters,threadPrioCompare,0);
c0022ce8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0022cef:	00 
c0022cf0:	c7 44 24 04 00 2b 02 	movl   $0xc0022b00,0x4(%esp)
c0022cf7:	c0 
c0022cf8:	89 34 24             	mov    %esi,(%esp)
c0022cfb:	e8 8a 69 00 00       	call   c002968a <list_max>
c0022d00:	89 c6                	mov    %eax,%esi
    list_remove(max_prio_sema);
c0022d02:	89 04 24             	mov    %eax,(%esp)
c0022d05:	e8 1a 63 00 00       	call   c0029024 <list_remove>
    freed_thread = list_entry(max_prio_sema,struct thread,elem);
c0022d0a:	8d 6e d8             	lea    -0x28(%esi),%ebp
    thread_unblock (freed_thread);
c0022d0d:	89 2c 24             	mov    %ebp,(%esp)
c0022d10:	e8 3e e0 ff ff       	call   c0020d53 <thread_unblock>
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
c0022d29:	e8 fe e0 ff ff       	call   c0020e2c <thread_current>
c0022d2e:	8b 56 f4             	mov    -0xc(%esi),%edx
c0022d31:	39 50 1c             	cmp    %edx,0x1c(%eax)
c0022d34:	7d 12                	jge    c0022d48 <sema_up+0xb1>
      thread_yield ();
c0022d36:	e8 a5 e7 ff ff       	call   c00214e0 <thread_yield>
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
c0022d8b:	e8 ce 3d 00 00       	call   c0026b5e <printf>
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
c0022dd3:	e8 aa e7 ff ff       	call   c0021582 <thread_create>
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
c0022e01:	e8 d5 78 00 00       	call   c002a6db <puts>
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
c0022e3f:	e8 6f 5b 00 00       	call   c00289b3 <debug_panic>
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
c0022e94:	e8 1a 5b 00 00       	call   c00289b3 <debug_panic>
  return lock->holder == thread_current ();
c0022e99:	8b 18                	mov    (%eax),%ebx
c0022e9b:	e8 8c df ff ff       	call   c0020e2c <thread_current>
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
c0022ede:	e8 d0 5a 00 00       	call   c00289b3 <debug_panic>
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
c0022f13:	e8 9b 5a 00 00       	call   c00289b3 <debug_panic>
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
c0022f4b:	e8 63 5a 00 00       	call   c00289b3 <debug_panic>
  old_level = intr_disable ();
c0022f50:	e8 ba ea ff ff       	call   c0021a0f <intr_disable>
c0022f55:	89 c6                	mov    %eax,%esi
  if(!thread_mlfqs && lock->holder != NULL)
c0022f57:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0022f5e:	75 20                	jne    c0022f80 <lock_acquire+0xd6>
c0022f60:	83 3b 00             	cmpl   $0x0,(%ebx)
c0022f63:	74 1b                	je     c0022f80 <lock_acquire+0xd6>
    int curr_prio = thread_get_priority();
c0022f65:	e8 23 e0 ff ff       	call   c0020f8d <thread_get_priority>
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
c0022f80:	e8 a7 de ff ff       	call   c0020e2c <thread_current>
c0022f85:	89 58 50             	mov    %ebx,0x50(%eax)
  intr_set_level (old_level);
c0022f88:	89 34 24             	mov    %esi,(%esp)
c0022f8b:	e8 86 ea ff ff       	call   c0021a16 <intr_set_level>
  sema_down (&lock->semaphore);          //lock acquired
c0022f90:	8d 43 04             	lea    0x4(%ebx),%eax
c0022f93:	89 04 24             	mov    %eax,(%esp)
c0022f96:	e8 e7 fb ff ff       	call   c0022b82 <sema_down>
  lock->holder = thread_current ();      //Now I'm the owner of this lock
c0022f9b:	e8 8c de ff ff       	call   c0020e2c <thread_current>
c0022fa0:	89 03                	mov    %eax,(%ebx)
  thread_current()->wait_on_lock = NULL; //and now no more waiting for this lock
c0022fa2:	e8 85 de ff ff       	call   c0020e2c <thread_current>
c0022fa7:	c7 40 50 00 00 00 00 	movl   $0x0,0x50(%eax)
  list_insert_ordered(&(thread_current()->locks_held), &lock->elem, lockPrioCompare,NULL);
c0022fae:	e8 79 de ff ff       	call   c0020e2c <thread_current>
c0022fb3:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0022fba:	00 
c0022fbb:	c7 44 24 08 12 2b 02 	movl   $0xc0022b12,0x8(%esp)
c0022fc2:	c0 
c0022fc3:	8d 53 18             	lea    0x18(%ebx),%edx
c0022fc6:	89 54 24 04          	mov    %edx,0x4(%esp)
c0022fca:	83 c0 40             	add    $0x40,%eax
c0022fcd:	89 04 24             	mov    %eax,(%esp)
c0022fd0:	e8 d1 64 00 00       	call   c00294a6 <list_insert_ordered>
  lock->max_priority = thread_get_priority();
c0022fd5:	e8 b3 df ff ff       	call   c0020f8d <thread_get_priority>
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
c0023017:	e8 97 59 00 00       	call   c00289b3 <debug_panic>
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
c002304f:	e8 5f 59 00 00       	call   c00289b3 <debug_panic>
  success = sema_try_down (&lock->semaphore);
c0023054:	8d 43 04             	lea    0x4(%ebx),%eax
c0023057:	89 04 24             	mov    %eax,(%esp)
c002305a:	e8 d5 fb ff ff       	call   c0022c34 <sema_try_down>
c002305f:	89 c6                	mov    %eax,%esi
  if (success)
c0023061:	84 c0                	test   %al,%al
c0023063:	74 07                	je     c002306c <lock_try_acquire+0x89>
    lock->holder = thread_current ();
c0023065:	e8 c2 dd ff ff       	call   c0020e2c <thread_current>
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
c00230a9:	e8 05 59 00 00       	call   c00289b3 <debug_panic>
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
c00230e1:	e8 cd 58 00 00       	call   c00289b3 <debug_panic>
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
c0023100:	e8 1f 5f 00 00       	call   c0029024 <list_remove>
  if(!thread_mlfqs)
c0023105:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002310c:	75 45                	jne    c0023153 <lock_release+0xdf>
    if(!list_empty(&(thread_current()->locks_held)))
c002310e:	e8 19 dd ff ff       	call   c0020e2c <thread_current>
c0023113:	83 c0 40             	add    $0x40,%eax
c0023116:	89 04 24             	mov    %eax,(%esp)
c0023119:	e8 98 5f 00 00       	call   c00290b6 <list_empty>
c002311e:	84 c0                	test   %al,%al
c0023120:	75 1f                	jne    c0023141 <lock_release+0xcd>
      struct list_elem *first_elem = list_begin(&(thread_current()->locks_held));
c0023122:	e8 05 dd ff ff       	call   c0020e2c <thread_current>
c0023127:	83 c0 40             	add    $0x40,%eax
c002312a:	89 04 24             	mov    %eax,(%esp)
c002312d:	e8 9f 59 00 00       	call   c0028ad1 <list_begin>
c0023132:	89 c7                	mov    %eax,%edi
      thread_current()->priority = l->max_priority;
c0023134:	e8 f3 dc ff ff       	call   c0020e2c <thread_current>
c0023139:	8b 57 08             	mov    0x8(%edi),%edx
c002313c:	89 50 1c             	mov    %edx,0x1c(%eax)
c002313f:	eb 12                	jmp    c0023153 <lock_release+0xdf>
      thread_current()->priority = thread_current()->old_priority;
c0023141:	e8 e6 dc ff ff       	call   c0020e2c <thread_current>
c0023146:	89 c7                	mov    %eax,%edi
c0023148:	e8 df dc ff ff       	call   c0020e2c <thread_current>
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
c002319f:	e8 0f 58 00 00       	call   c00289b3 <debug_panic>

  list_init (&cond->waiters);
c00231a4:	89 04 24             	mov    %eax,(%esp)
c00231a7:	e8 d4 58 00 00       	call   c0028a80 <list_init>
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
c00231ea:	e8 c4 57 00 00       	call   c00289b3 <debug_panic>
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
c002321a:	e8 94 57 00 00       	call   c00289b3 <debug_panic>
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
c002324f:	e8 5f 57 00 00       	call   c00289b3 <debug_panic>
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
c0023287:	e8 27 57 00 00       	call   c00289b3 <debug_panic>
  
  sema_init (&waiter.semaphore, 0);
c002328c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023293:	00 
c0023294:	8d 6c 24 20          	lea    0x20(%esp),%ebp
c0023298:	8d 7c 24 28          	lea    0x28(%esp),%edi
c002329c:	89 3c 24             	mov    %edi,(%esp)
c002329f:	e8 92 f8 ff ff       	call   c0022b36 <sema_init>
  waiter.priority = thread_get_priority(); //(ADDED) sets sema's prio value to the threads prio
c00232a4:	e8 e4 dc ff ff       	call   c0020f8d <thread_get_priority>
c00232a9:	89 44 24 3c          	mov    %eax,0x3c(%esp)

  list_push_back (&cond->waiters, &waiter.elem);
c00232ad:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00232b1:	89 34 24             	mov    %esi,(%esp)
c00232b4:	e8 48 5d 00 00       	call   c0029001 <list_push_back>
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
c0023311:	e8 9d 56 00 00       	call   c00289b3 <debug_panic>
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
c0023341:	e8 6d 56 00 00       	call   c00289b3 <debug_panic>
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
c0023376:	e8 38 56 00 00       	call   c00289b3 <debug_panic>
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
c00233ae:	e8 00 56 00 00       	call   c00289b3 <debug_panic>

  struct list_elem *max_cond_waiter; //(ADDED) to be used below
  if (!list_empty (&cond->waiters)) 
c00233b3:	89 1c 24             	mov    %ebx,(%esp)
c00233b6:	e8 fb 5c 00 00       	call   c00290b6 <list_empty>
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
c00233d2:	e8 b3 62 00 00       	call   c002968a <list_max>
c00233d7:	89 c3                	mov    %eax,%ebx
    list_remove(max_cond_waiter);
c00233d9:	89 04 24             	mov    %eax,(%esp)
c00233dc:	e8 43 5c 00 00       	call   c0029024 <list_remove>
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
c002342a:	e8 84 55 00 00       	call   c00289b3 <debug_panic>
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
c002345a:	e8 54 55 00 00       	call   c00289b3 <debug_panic>

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
c002345f:	89 74 24 04          	mov    %esi,0x4(%esp)
c0023463:	89 1c 24             	mov    %ebx,(%esp)
c0023466:	e8 6e fe ff ff       	call   c00232d9 <cond_signal>
  while (!list_empty (&cond->waiters))
c002346b:	89 1c 24             	mov    %ebx,(%esp)
c002346e:	e8 43 5c 00 00       	call   c00290b6 <list_empty>
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
c002348d:	e8 ce 62 00 00       	call   c0029760 <bitmap_buf_size>
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
c00234c6:	e8 e8 54 00 00       	call   c00289b3 <debug_panic>
  page_cnt -= bm_pages;
c00234cb:	29 f3                	sub    %esi,%ebx

  printf ("%zu pages available in %s.\n", page_cnt, name);
c00234cd:	8b 44 24 40          	mov    0x40(%esp),%eax
c00234d1:	89 44 24 08          	mov    %eax,0x8(%esp)
c00234d5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00234d9:	c7 04 24 6f eb 02 c0 	movl   $0xc002eb6f,(%esp)
c00234e0:	e8 79 36 00 00       	call   c0026b5e <printf>

  /* Initialize the pool. */
  lock_init (&p->lock);
c00234e5:	89 3c 24             	mov    %edi,(%esp)
c00234e8:	e8 20 f9 ff ff       	call   c0022e0d <lock_init>
  p->used_map = bitmap_create_in_buf (page_cnt, base, bm_pages * PGSIZE);
c00234ed:	c1 e6 0c             	shl    $0xc,%esi
c00234f0:	89 74 24 08          	mov    %esi,0x8(%esp)
c00234f4:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00234f8:	89 1c 24             	mov    %ebx,(%esp)
c00234fb:	e8 a5 65 00 00       	call   c0029aa5 <bitmap_create_in_buf>
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
c002354f:	e8 5f 54 00 00       	call   c00289b3 <debug_panic>
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
c00235f5:	e8 30 68 00 00       	call   c0029e2a <bitmap_scan_and_flip>
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
c002362d:	e8 3f 48 00 00       	call   c0027e71 <memset>
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
c002365d:	e8 51 53 00 00       	call   c00289b3 <debug_panic>
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
c00236cf:	e8 df 52 00 00       	call   c00289b3 <debug_panic>
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
c00236fa:	e8 97 60 00 00       	call   c0029796 <bitmap_size>
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
c002371a:	e8 77 60 00 00       	call   c0029796 <bitmap_size>
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
c0023748:	e8 66 52 00 00       	call   c00289b3 <debug_panic>
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
c0023775:	e8 f7 46 00 00       	call   c0027e71 <memset>
  ASSERT (bitmap_all (pool->used_map, page_idx, page_cnt));
c002377a:	89 74 24 08          	mov    %esi,0x8(%esp)
c002377e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023782:	8b 45 24             	mov    0x24(%ebp),%eax
c0023785:	89 04 24             	mov    %eax,(%esp)
c0023788:	e8 9f 65 00 00       	call   c0029d2c <bitmap_all>
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
c00237b8:	e8 f6 51 00 00       	call   c00289b3 <debug_panic>
  bitmap_set_multiple (pool->used_map, page_idx, page_cnt, false);
c00237bd:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00237c4:	00 
c00237c5:	89 74 24 08          	mov    %esi,0x8(%esp)
c00237c9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00237cd:	8b 45 24             	mov    0x24(%ebp),%eax
c00237d0:	89 04 24             	mov    %eax,(%esp)
c00237d3:	e8 35 61 00 00       	call   c002990d <bitmap_set_multiple>
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
c002382e:	e8 80 51 00 00       	call   c00289b3 <debug_panic>
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
c0023862:	e8 4c 51 00 00       	call   c00289b3 <debug_panic>
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
c0023896:	e8 18 51 00 00       	call   c00289b3 <debug_panic>
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
c00238db:	e8 d3 50 00 00       	call   c00289b3 <debug_panic>
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
c002390f:	e8 9f 50 00 00       	call   c00289b3 <debug_panic>
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
c0023955:	e8 59 50 00 00       	call   c00289b3 <debug_panic>
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
c002398b:	e8 23 50 00 00       	call   c00289b3 <debug_panic>
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
c00239fe:	e8 b0 4f 00 00       	call   c00289b3 <debug_panic>
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
c0023a1b:	e8 60 50 00 00       	call   c0028a80 <list_init>
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
c0023a4e:	e8 2d 50 00 00       	call   c0028a80 <list_init>
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
c0023b14:	e8 9d 55 00 00       	call   c00290b6 <list_empty>
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
c0023b6c:	e8 90 54 00 00       	call   c0029001 <list_push_back>
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023b71:	83 c6 01             	add    $0x1,%esi
c0023b74:	39 73 04             	cmp    %esi,0x4(%ebx)
c0023b77:	77 e3                	ja     c0023b5c <malloc+0xe8>
  b = list_entry (list_pop_front (&d->free_list), struct block, free_elem);
c0023b79:	89 3c 24             	mov    %edi,(%esp)
c0023b7c:	e8 a3 55 00 00       	call   c0029124 <list_pop_front>
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
c0023be7:	e8 85 42 00 00       	call   c0027e71 <memset>
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
c0023c33:	e8 39 42 00 00       	call   c0027e71 <memset>
          lock_acquire (&d->lock);
c0023c38:	8d 6e 18             	lea    0x18(%esi),%ebp
c0023c3b:	89 2c 24             	mov    %ebp,(%esp)
c0023c3e:	e8 67 f2 ff ff       	call   c0022eaa <lock_acquire>
          list_push_front (&d->free_list, &b->free_elem);
c0023c43:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023c47:	8d 46 08             	lea    0x8(%esi),%eax
c0023c4a:	89 04 24             	mov    %eax,(%esp)
c0023c4d:	e8 8c 53 00 00       	call   c0028fde <list_push_front>
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
c0023c99:	e8 15 4d 00 00       	call   c00289b3 <debug_panic>
                  struct block *b = arena_to_block (a, i);
c0023c9e:	89 da                	mov    %ebx,%edx
c0023ca0:	89 f8                	mov    %edi,%eax
c0023ca2:	e8 59 fb ff ff       	call   c0023800 <arena_to_block>
                  list_remove (&b->free_elem);
c0023ca7:	89 04 24             	mov    %eax,(%esp)
c0023caa:	e8 75 53 00 00       	call   c0029024 <list_remove>
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
c0023d45:	e8 46 3b 00 00       	call   c0027890 <memcpy>
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
c0023da0:	e8 0e 4c 00 00       	call   c00289b3 <debug_panic>
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
c0023dd4:	e8 da 4b 00 00       	call   c00289b3 <debug_panic>
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
c0023ee3:	e8 e9 4b 00 00       	call   c0028ad1 <list_begin>
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
c0023f0a:	e8 15 51 00 00       	call   c0029024 <list_remove>
c0023f0f:	89 c3                	mov    %eax,%ebx
          thread_unblock(t);
c0023f11:	89 34 24             	mov    %esi,(%esp)
c0023f14:	e8 3a ce ff ff       	call   c0020d53 <thread_unblock>
c0023f19:	eb 0a                	jmp    c0023f25 <timer_interrupt+0x5c>
          e = list_next(e);
c0023f1b:	89 1c 24             	mov    %ebx,(%esp)
c0023f1e:	e8 ec 4b 00 00       	call   c0028b0f <list_next>
c0023f23:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023f25:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023f2c:	e8 32 4c 00 00       	call   c0028b63 <list_end>
c0023f31:	39 d8                	cmp    %ebx,%eax
c0023f33:	75 b7                	jne    c0023eec <timer_interrupt+0x23>
  if(thread_mlfqs)
c0023f35:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0023f3c:	0f 84 fd 00 00 00    	je     c002403f <timer_interrupt+0x176>
    if(thread_current() != get_idle_thread()){
c0023f42:	e8 e5 ce ff ff       	call   c0020e2c <thread_current>
c0023f47:	89 c3                	mov    %eax,%ebx
c0023f49:	e8 01 d2 ff ff       	call   c002114f <get_idle_thread>
c0023f4e:	39 c3                	cmp    %eax,%ebx
c0023f50:	74 22                	je     c0023f74 <timer_interrupt+0xab>
      thread_current()->recent_cpu = addXandN(thread_current()->recent_cpu,1);
c0023f52:	e8 d5 ce ff ff       	call   c0020e2c <thread_current>
c0023f57:	89 c3                	mov    %eax,%ebx
c0023f59:	e8 ce ce ff ff       	call   c0020e2c <thread_current>
c0023f5e:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023f65:	00 
c0023f66:	8b 40 58             	mov    0x58(%eax),%eax
c0023f69:	89 04 24             	mov    %eax,(%esp)
c0023f6c:	e8 c2 cb ff ff       	call   c0020b33 <addXandN>
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
c0023f96:	e8 9b 43 00 00       	call   c0028336 <__moddi3>
c0023f9b:	09 c2                	or     %eax,%edx
c0023f9d:	75 7e                	jne    c002401d <timer_interrupt+0x154>
      setLoadAv(multXbyY(divXbyN(convertNtoFixedPoint(59),60),getLoadAv()) + multXbyN(divXbyN(convertNtoFixedPoint(1),60),get_ready_threads()));
c0023f9f:	e8 9b d1 ff ff       	call   c002113f <getLoadAv>
c0023fa4:	89 c3                	mov    %eax,%ebx
c0023fa6:	c7 04 24 3b 00 00 00 	movl   $0x3b,(%esp)
c0023fad:	e8 89 c9 ff ff       	call   c002093b <convertNtoFixedPoint>
c0023fb2:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c0023fb9:	00 
c0023fba:	89 04 24             	mov    %eax,(%esp)
c0023fbd:	e8 3a cc ff ff       	call   c0020bfc <divXbyN>
c0023fc2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023fc6:	89 04 24             	mov    %eax,(%esp)
c0023fc9:	e8 89 cb ff ff       	call   c0020b57 <multXbyY>
c0023fce:	89 c3                	mov    %eax,%ebx
c0023fd0:	e8 26 d1 ff ff       	call   c00210fb <get_ready_threads>
c0023fd5:	89 c6                	mov    %eax,%esi
c0023fd7:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0023fde:	e8 58 c9 ff ff       	call   c002093b <convertNtoFixedPoint>
c0023fe3:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c0023fea:	00 
c0023feb:	89 04 24             	mov    %eax,(%esp)
c0023fee:	e8 09 cc ff ff       	call   c0020bfc <divXbyN>
c0023ff3:	89 74 24 04          	mov    %esi,0x4(%esp)
c0023ff7:	89 04 24             	mov    %eax,(%esp)
c0023ffa:	e8 a6 cb ff ff       	call   c0020ba5 <multXbyN>
c0023fff:	01 c3                	add    %eax,%ebx
c0024001:	89 1c 24             	mov    %ebx,(%esp)
c0024004:	e8 3c d1 ff ff       	call   c0021145 <setLoadAv>
      thread_foreach (calculate_recent_cpu, 0);
c0024009:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0024010:	00 
c0024011:	c7 04 24 d9 0f 02 c0 	movl   $0xc0020fd9,(%esp)
c0024018:	e8 f0 ce ff ff       	call   c0020f0d <thread_foreach>
     if(ticks % 4 == 0) //--- responsible for test mlfqs-fair-20 passing
c002401d:	f6 05 70 77 03 c0 03 	testb  $0x3,0xc0037770
c0024024:	75 19                	jne    c002403f <timer_interrupt+0x176>
       thread_foreach (calcPrio, 0);
c0024026:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002402d:	00 
c002402e:	c7 04 24 7a 10 02 c0 	movl   $0xc002107a,(%esp)
c0024035:	e8 d3 ce ff ff       	call   c0020f0d <thread_foreach>
       intr_yield_on_return ();
c002403a:	e8 3a dc ff ff       	call   c0021c79 <intr_yield_on_return>
  thread_tick (); 
c002403f:	e8 63 ce ff ff       	call   c0020ea7 <thread_tick>
}
c0024044:	83 c4 14             	add    $0x14,%esp
c0024047:	5b                   	pop    %ebx
c0024048:	5e                   	pop    %esi
c0024049:	c3                   	ret    

c002404a <real_time_delay>:
}

/* Busy-wait for approximately NUM/DENOM seconds. */
static void
real_time_delay (int64_t num, int32_t denom)
{
c002404a:	55                   	push   %ebp
c002404b:	57                   	push   %edi
c002404c:	56                   	push   %esi
c002404d:	53                   	push   %ebx
c002404e:	83 ec 2c             	sub    $0x2c,%esp
c0024051:	89 c7                	mov    %eax,%edi
c0024053:	89 d6                	mov    %edx,%esi
c0024055:	89 cb                	mov    %ecx,%ebx
  /* Scale the numerator and denominator down by 1000 to avoid
     the possibility of overflow. */
  ASSERT (denom % 1000 == 0);
c0024057:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c002405c:	89 c8                	mov    %ecx,%eax
c002405e:	f7 ea                	imul   %edx
c0024060:	c1 fa 06             	sar    $0x6,%edx
c0024063:	89 c8                	mov    %ecx,%eax
c0024065:	c1 f8 1f             	sar    $0x1f,%eax
c0024068:	29 c2                	sub    %eax,%edx
c002406a:	69 d2 e8 03 00 00    	imul   $0x3e8,%edx,%edx
c0024070:	39 d1                	cmp    %edx,%ecx
c0024072:	74 2c                	je     c00240a0 <real_time_delay+0x56>
c0024074:	c7 44 24 10 2b ed 02 	movl   $0xc002ed2b,0x10(%esp)
c002407b:	c0 
c002407c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024083:	c0 
c0024084:	c7 44 24 08 27 d3 02 	movl   $0xc002d327,0x8(%esp)
c002408b:	c0 
c002408c:	c7 44 24 04 45 01 00 	movl   $0x145,0x4(%esp)
c0024093:	00 
c0024094:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c002409b:	e8 13 49 00 00       	call   c00289b3 <debug_panic>
  busy_wait (loops_per_tick * num / 1000 * TIMER_FREQ / (denom / 1000)); 
c00240a0:	a1 68 77 03 c0       	mov    0xc0037768,%eax
c00240a5:	0f af f0             	imul   %eax,%esi
c00240a8:	f7 e7                	mul    %edi
c00240aa:	01 f2                	add    %esi,%edx
c00240ac:	c7 44 24 08 e8 03 00 	movl   $0x3e8,0x8(%esp)
c00240b3:	00 
c00240b4:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00240bb:	00 
c00240bc:	89 04 24             	mov    %eax,(%esp)
c00240bf:	89 54 24 04          	mov    %edx,0x4(%esp)
c00240c3:	e8 4b 42 00 00       	call   c0028313 <__divdi3>
c00240c8:	6b ea 64             	imul   $0x64,%edx,%ebp
c00240cb:	b9 64 00 00 00       	mov    $0x64,%ecx
c00240d0:	f7 e1                	mul    %ecx
c00240d2:	89 c6                	mov    %eax,%esi
c00240d4:	89 d7                	mov    %edx,%edi
c00240d6:	01 ef                	add    %ebp,%edi
c00240d8:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c00240dd:	89 d8                	mov    %ebx,%eax
c00240df:	f7 ea                	imul   %edx
c00240e1:	c1 fa 06             	sar    $0x6,%edx
c00240e4:	c1 fb 1f             	sar    $0x1f,%ebx
c00240e7:	29 da                	sub    %ebx,%edx
c00240e9:	89 54 24 08          	mov    %edx,0x8(%esp)
c00240ed:	89 d0                	mov    %edx,%eax
c00240ef:	c1 f8 1f             	sar    $0x1f,%eax
c00240f2:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00240f6:	89 34 24             	mov    %esi,(%esp)
c00240f9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00240fd:	e8 11 42 00 00       	call   c0028313 <__divdi3>
c0024102:	e8 4b fd ff ff       	call   c0023e52 <busy_wait>
c0024107:	83 c4 2c             	add    $0x2c,%esp
c002410a:	5b                   	pop    %ebx
c002410b:	5e                   	pop    %esi
c002410c:	5f                   	pop    %edi
c002410d:	5d                   	pop    %ebp
c002410e:	c3                   	ret    

c002410f <timer_init>:
{
c002410f:	83 ec 1c             	sub    $0x1c,%esp
  pit_configure_channel (0, 2, TIMER_FREQ);
c0024112:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0024119:	00 
c002411a:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
c0024121:	00 
c0024122:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0024129:	e8 31 fc ff ff       	call   c0023d5f <pit_configure_channel>
  intr_register_ext (0x20, timer_interrupt, "8254 Timer");
c002412e:	c7 44 24 08 53 ed 02 	movl   $0xc002ed53,0x8(%esp)
c0024135:	c0 
c0024136:	c7 44 24 04 c9 3e 02 	movl   $0xc0023ec9,0x4(%esp)
c002413d:	c0 
c002413e:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0024145:	e8 69 da ff ff       	call   c0021bb3 <intr_register_ext>
  list_init (&sleep_list);
c002414a:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0024151:	e8 2a 49 00 00       	call   c0028a80 <list_init>
}
c0024156:	83 c4 1c             	add    $0x1c,%esp
c0024159:	c3                   	ret    

c002415a <timer_calibrate>:
{
c002415a:	57                   	push   %edi
c002415b:	56                   	push   %esi
c002415c:	53                   	push   %ebx
c002415d:	83 ec 20             	sub    $0x20,%esp
  ASSERT (intr_get_level () == INTR_ON);
c0024160:	e8 5f d8 ff ff       	call   c00219c4 <intr_get_level>
c0024165:	83 f8 01             	cmp    $0x1,%eax
c0024168:	74 2c                	je     c0024196 <timer_calibrate+0x3c>
c002416a:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c0024171:	c0 
c0024172:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024179:	c0 
c002417a:	c7 44 24 08 53 d3 02 	movl   $0xc002d353,0x8(%esp)
c0024181:	c0 
c0024182:	c7 44 24 04 41 00 00 	movl   $0x41,0x4(%esp)
c0024189:	00 
c002418a:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c0024191:	e8 1d 48 00 00       	call   c00289b3 <debug_panic>
  printf ("Calibrating timer...  ");
c0024196:	c7 04 24 7b ed 02 c0 	movl   $0xc002ed7b,(%esp)
c002419d:	e8 bc 29 00 00       	call   c0026b5e <printf>
  loops_per_tick = 1u << 10;
c00241a2:	c7 05 68 77 03 c0 00 	movl   $0x400,0xc0037768
c00241a9:	04 00 00 
  while (!too_many_loops (loops_per_tick << 1)) 
c00241ac:	eb 36                	jmp    c00241e4 <timer_calibrate+0x8a>
      loops_per_tick <<= 1;
c00241ae:	89 1d 68 77 03 c0    	mov    %ebx,0xc0037768
      ASSERT (loops_per_tick != 0);
c00241b4:	85 db                	test   %ebx,%ebx
c00241b6:	75 2c                	jne    c00241e4 <timer_calibrate+0x8a>
c00241b8:	c7 44 24 10 92 ed 02 	movl   $0xc002ed92,0x10(%esp)
c00241bf:	c0 
c00241c0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00241c7:	c0 
c00241c8:	c7 44 24 08 53 d3 02 	movl   $0xc002d353,0x8(%esp)
c00241cf:	c0 
c00241d0:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c00241d7:	00 
c00241d8:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c00241df:	e8 cf 47 00 00       	call   c00289b3 <debug_panic>
  while (!too_many_loops (loops_per_tick << 1)) 
c00241e4:	8b 35 68 77 03 c0    	mov    0xc0037768,%esi
c00241ea:	8d 1c 36             	lea    (%esi,%esi,1),%ebx
c00241ed:	89 d8                	mov    %ebx,%eax
c00241ef:	e8 87 fc ff ff       	call   c0023e7b <too_many_loops>
c00241f4:	84 c0                	test   %al,%al
c00241f6:	74 b6                	je     c00241ae <timer_calibrate+0x54>
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c00241f8:	89 f3                	mov    %esi,%ebx
c00241fa:	d1 eb                	shr    %ebx
c00241fc:	89 f7                	mov    %esi,%edi
c00241fe:	c1 ef 0a             	shr    $0xa,%edi
c0024201:	39 df                	cmp    %ebx,%edi
c0024203:	74 19                	je     c002421e <timer_calibrate+0xc4>
    if (!too_many_loops (high_bit | test_bit))
c0024205:	89 d8                	mov    %ebx,%eax
c0024207:	09 f0                	or     %esi,%eax
c0024209:	e8 6d fc ff ff       	call   c0023e7b <too_many_loops>
c002420e:	84 c0                	test   %al,%al
c0024210:	75 06                	jne    c0024218 <timer_calibrate+0xbe>
      loops_per_tick |= test_bit;
c0024212:	09 1d 68 77 03 c0    	or     %ebx,0xc0037768
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c0024218:	d1 eb                	shr    %ebx
c002421a:	39 df                	cmp    %ebx,%edi
c002421c:	75 e7                	jne    c0024205 <timer_calibrate+0xab>
  printf ("%'"PRIu64" loops/s.\n", (uint64_t) loops_per_tick * TIMER_FREQ);
c002421e:	b8 64 00 00 00       	mov    $0x64,%eax
c0024223:	f7 25 68 77 03 c0    	mull   0xc0037768
c0024229:	89 44 24 04          	mov    %eax,0x4(%esp)
c002422d:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024231:	c7 04 24 a6 ed 02 c0 	movl   $0xc002eda6,(%esp)
c0024238:	e8 21 29 00 00       	call   c0026b5e <printf>
}
c002423d:	83 c4 20             	add    $0x20,%esp
c0024240:	5b                   	pop    %ebx
c0024241:	5e                   	pop    %esi
c0024242:	5f                   	pop    %edi
c0024243:	c3                   	ret    

c0024244 <timer_ticks>:
{
c0024244:	56                   	push   %esi
c0024245:	53                   	push   %ebx
c0024246:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level = intr_disable ();
c0024249:	e8 c1 d7 ff ff       	call   c0021a0f <intr_disable>
  int64_t t = ticks;
c002424e:	8b 15 70 77 03 c0    	mov    0xc0037770,%edx
c0024254:	8b 0d 74 77 03 c0    	mov    0xc0037774,%ecx
c002425a:	89 d3                	mov    %edx,%ebx
c002425c:	89 ce                	mov    %ecx,%esi
  intr_set_level (old_level);
c002425e:	89 04 24             	mov    %eax,(%esp)
c0024261:	e8 b0 d7 ff ff       	call   c0021a16 <intr_set_level>
}
c0024266:	89 d8                	mov    %ebx,%eax
c0024268:	89 f2                	mov    %esi,%edx
c002426a:	83 c4 14             	add    $0x14,%esp
c002426d:	5b                   	pop    %ebx
c002426e:	5e                   	pop    %esi
c002426f:	c3                   	ret    

c0024270 <timer_elapsed>:
{
c0024270:	57                   	push   %edi
c0024271:	56                   	push   %esi
c0024272:	83 ec 04             	sub    $0x4,%esp
c0024275:	8b 74 24 10          	mov    0x10(%esp),%esi
c0024279:	8b 7c 24 14          	mov    0x14(%esp),%edi
  return timer_ticks () - then;
c002427d:	e8 c2 ff ff ff       	call   c0024244 <timer_ticks>
c0024282:	29 f0                	sub    %esi,%eax
c0024284:	19 fa                	sbb    %edi,%edx
}
c0024286:	83 c4 04             	add    $0x4,%esp
c0024289:	5e                   	pop    %esi
c002428a:	5f                   	pop    %edi
c002428b:	c3                   	ret    

c002428c <timer_sleep>:
{
c002428c:	57                   	push   %edi
c002428d:	56                   	push   %esi
c002428e:	53                   	push   %ebx
c002428f:	83 ec 20             	sub    $0x20,%esp
c0024292:	8b 74 24 30          	mov    0x30(%esp),%esi
c0024296:	8b 7c 24 34          	mov    0x34(%esp),%edi
    ASSERT (intr_get_level () == INTR_ON);
c002429a:	e8 25 d7 ff ff       	call   c00219c4 <intr_get_level>
c002429f:	83 f8 01             	cmp    $0x1,%eax
c00242a2:	74 2c                	je     c00242d0 <timer_sleep+0x44>
c00242a4:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c00242ab:	c0 
c00242ac:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00242b3:	c0 
c00242b4:	c7 44 24 08 47 d3 02 	movl   $0xc002d347,0x8(%esp)
c00242bb:	c0 
c00242bc:	c7 44 24 04 6c 00 00 	movl   $0x6c,0x4(%esp)
c00242c3:	00 
c00242c4:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c00242cb:	e8 e3 46 00 00       	call   c00289b3 <debug_panic>
    struct thread *cur = thread_current ();
c00242d0:	e8 57 cb ff ff       	call   c0020e2c <thread_current>
c00242d5:	89 c3                	mov    %eax,%ebx
    cur->wakeup = timer_ticks () + ticks; //save the wakeup time of each thread as a struct attribute
c00242d7:	e8 68 ff ff ff       	call   c0024244 <timer_ticks>
c00242dc:	01 f0                	add    %esi,%eax
c00242de:	11 fa                	adc    %edi,%edx
c00242e0:	89 43 34             	mov    %eax,0x34(%ebx)
c00242e3:	89 53 38             	mov    %edx,0x38(%ebx)
    old_level = intr_disable ();
c00242e6:	e8 24 d7 ff ff       	call   c0021a0f <intr_disable>
c00242eb:	89 c6                	mov    %eax,%esi
    list_insert_ordered(&sleep_list, &cur->elem, compareSleep, 0); //add each thread as a list elem to the sleep_list based on wakeup time
c00242ed:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00242f4:	00 
c00242f5:	c7 44 24 08 40 3e 02 	movl   $0xc0023e40,0x8(%esp)
c00242fc:	c0 
c00242fd:	83 c3 28             	add    $0x28,%ebx
c0024300:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024304:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c002430b:	e8 96 51 00 00       	call   c00294a6 <list_insert_ordered>
    thread_block(); //block the thread 
c0024310:	e8 55 d0 ff ff       	call   c002136a <thread_block>
    intr_set_level (old_level); //set interrupts back to orginal status
c0024315:	89 34 24             	mov    %esi,(%esp)
c0024318:	e8 f9 d6 ff ff       	call   c0021a16 <intr_set_level>
}
c002431d:	83 c4 20             	add    $0x20,%esp
c0024320:	5b                   	pop    %ebx
c0024321:	5e                   	pop    %esi
c0024322:	5f                   	pop    %edi
c0024323:	c3                   	ret    

c0024324 <real_time_sleep>:
{
c0024324:	55                   	push   %ebp
c0024325:	57                   	push   %edi
c0024326:	56                   	push   %esi
c0024327:	53                   	push   %ebx
c0024328:	83 ec 2c             	sub    $0x2c,%esp
c002432b:	89 c7                	mov    %eax,%edi
c002432d:	89 d6                	mov    %edx,%esi
c002432f:	89 cd                	mov    %ecx,%ebp
  int64_t ticks = num * TIMER_FREQ / denom;
c0024331:	6b ca 64             	imul   $0x64,%edx,%ecx
c0024334:	b8 64 00 00 00       	mov    $0x64,%eax
c0024339:	f7 e7                	mul    %edi
c002433b:	01 ca                	add    %ecx,%edx
c002433d:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0024341:	89 e9                	mov    %ebp,%ecx
c0024343:	c1 f9 1f             	sar    $0x1f,%ecx
c0024346:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002434a:	89 04 24             	mov    %eax,(%esp)
c002434d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0024351:	e8 bd 3f 00 00       	call   c0028313 <__divdi3>
c0024356:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002435a:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_ON);
c002435c:	e8 63 d6 ff ff       	call   c00219c4 <intr_get_level>
c0024361:	83 f8 01             	cmp    $0x1,%eax
c0024364:	74 2c                	je     c0024392 <real_time_sleep+0x6e>
c0024366:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c002436d:	c0 
c002436e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024375:	c0 
c0024376:	c7 44 24 08 37 d3 02 	movl   $0xc002d337,0x8(%esp)
c002437d:	c0 
c002437e:	c7 44 24 04 2f 01 00 	movl   $0x12f,0x4(%esp)
c0024385:	00 
c0024386:	c7 04 24 3d ed 02 c0 	movl   $0xc002ed3d,(%esp)
c002438d:	e8 21 46 00 00       	call   c00289b3 <debug_panic>
  if (ticks > 0)
c0024392:	85 db                	test   %ebx,%ebx
c0024394:	78 1e                	js     c00243b4 <real_time_sleep+0x90>
c0024396:	85 db                	test   %ebx,%ebx
c0024398:	7f 08                	jg     c00243a2 <real_time_sleep+0x7e>
c002439a:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c002439f:	90                   	nop
c00243a0:	76 12                	jbe    c00243b4 <real_time_sleep+0x90>
      timer_sleep (ticks); 
c00243a2:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c00243a6:	89 04 24             	mov    %eax,(%esp)
c00243a9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00243ad:	e8 da fe ff ff       	call   c002428c <timer_sleep>
c00243b2:	eb 0b                	jmp    c00243bf <real_time_sleep+0x9b>
      real_time_delay (num, denom); 
c00243b4:	89 e9                	mov    %ebp,%ecx
c00243b6:	89 f8                	mov    %edi,%eax
c00243b8:	89 f2                	mov    %esi,%edx
c00243ba:	e8 8b fc ff ff       	call   c002404a <real_time_delay>
}
c00243bf:	83 c4 2c             	add    $0x2c,%esp
c00243c2:	5b                   	pop    %ebx
c00243c3:	5e                   	pop    %esi
c00243c4:	5f                   	pop    %edi
c00243c5:	5d                   	pop    %ebp
c00243c6:	c3                   	ret    

c00243c7 <timer_msleep>:
{
c00243c7:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ms, 1000);
c00243ca:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c00243cf:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243d3:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243d7:	e8 48 ff ff ff       	call   c0024324 <real_time_sleep>
}
c00243dc:	83 c4 0c             	add    $0xc,%esp
c00243df:	c3                   	ret    

c00243e0 <timer_usleep>:
{
c00243e0:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (us, 1000 * 1000);
c00243e3:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00243e8:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243ec:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243f0:	e8 2f ff ff ff       	call   c0024324 <real_time_sleep>
}
c00243f5:	83 c4 0c             	add    $0xc,%esp
c00243f8:	c3                   	ret    

c00243f9 <timer_nsleep>:
{
c00243f9:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ns, 1000 * 1000 * 1000);
c00243fc:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c0024401:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024405:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024409:	e8 16 ff ff ff       	call   c0024324 <real_time_sleep>
}
c002440e:	83 c4 0c             	add    $0xc,%esp
c0024411:	c3                   	ret    

c0024412 <timer_mdelay>:
{
c0024412:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ms, 1000);
c0024415:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002441a:	8b 44 24 10          	mov    0x10(%esp),%eax
c002441e:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024422:	e8 23 fc ff ff       	call   c002404a <real_time_delay>
}
c0024427:	83 c4 0c             	add    $0xc,%esp
c002442a:	c3                   	ret    

c002442b <timer_udelay>:
{
c002442b:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (us, 1000 * 1000);
c002442e:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c0024433:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024437:	8b 54 24 14          	mov    0x14(%esp),%edx
c002443b:	e8 0a fc ff ff       	call   c002404a <real_time_delay>
}
c0024440:	83 c4 0c             	add    $0xc,%esp
c0024443:	c3                   	ret    

c0024444 <timer_ndelay>:
{
c0024444:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ns, 1000 * 1000 * 1000);
c0024447:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c002444c:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024450:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024454:	e8 f1 fb ff ff       	call   c002404a <real_time_delay>
}
c0024459:	83 c4 0c             	add    $0xc,%esp
c002445c:	c3                   	ret    

c002445d <timer_print_stats>:
{
c002445d:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Timer: %"PRId64" ticks\n", timer_ticks ());
c0024460:	e8 df fd ff ff       	call   c0024244 <timer_ticks>
c0024465:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024469:	89 54 24 08          	mov    %edx,0x8(%esp)
c002446d:	c7 04 24 b6 ed 02 c0 	movl   $0xc002edb6,(%esp)
c0024474:	e8 e5 26 00 00       	call   c0026b5e <printf>
}
c0024479:	83 c4 1c             	add    $0x1c,%esp
c002447c:	c3                   	ret    
c002447d:	90                   	nop
c002447e:	90                   	nop
c002447f:	90                   	nop

c0024480 <map_key>:
   If found, sets *C to the corresponding character and returns
   true.
   If not found, returns false and C is ignored. */
static bool
map_key (const struct keymap k[], unsigned scancode, uint8_t *c) 
{
c0024480:	55                   	push   %ebp
c0024481:	57                   	push   %edi
c0024482:	56                   	push   %esi
c0024483:	53                   	push   %ebx
c0024484:	83 ec 04             	sub    $0x4,%esp
c0024487:	89 c3                	mov    %eax,%ebx
c0024489:	89 0c 24             	mov    %ecx,(%esp)
  for (; k->first_scancode != 0; k++)
c002448c:	0f b6 08             	movzbl (%eax),%ecx
c002448f:	84 c9                	test   %cl,%cl
c0024491:	74 41                	je     c00244d4 <map_key+0x54>
    if (scancode >= k->first_scancode
        && scancode < k->first_scancode + strlen (k->chars)) 
c0024493:	b8 00 00 00 00       	mov    $0x0,%eax
    if (scancode >= k->first_scancode
c0024498:	0f b6 f1             	movzbl %cl,%esi
c002449b:	39 d6                	cmp    %edx,%esi
c002449d:	77 29                	ja     c00244c8 <map_key+0x48>
        && scancode < k->first_scancode + strlen (k->chars)) 
c002449f:	8b 6b 04             	mov    0x4(%ebx),%ebp
c00244a2:	89 ef                	mov    %ebp,%edi
c00244a4:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c00244a9:	f2 ae                	repnz scas %es:(%edi),%al
c00244ab:	f7 d1                	not    %ecx
c00244ad:	8d 4c 0e ff          	lea    -0x1(%esi,%ecx,1),%ecx
c00244b1:	39 ca                	cmp    %ecx,%edx
c00244b3:	73 13                	jae    c00244c8 <map_key+0x48>
      {
        *c = k->chars[scancode - k->first_scancode];
c00244b5:	29 f2                	sub    %esi,%edx
c00244b7:	0f b6 44 15 00       	movzbl 0x0(%ebp,%edx,1),%eax
c00244bc:	8b 3c 24             	mov    (%esp),%edi
c00244bf:	88 07                	mov    %al,(%edi)
        return true; 
c00244c1:	b8 01 00 00 00       	mov    $0x1,%eax
c00244c6:	eb 18                	jmp    c00244e0 <map_key+0x60>
  for (; k->first_scancode != 0; k++)
c00244c8:	83 c3 08             	add    $0x8,%ebx
c00244cb:	0f b6 0b             	movzbl (%ebx),%ecx
c00244ce:	84 c9                	test   %cl,%cl
c00244d0:	75 c6                	jne    c0024498 <map_key+0x18>
c00244d2:	eb 07                	jmp    c00244db <map_key+0x5b>
      }

  return false;
c00244d4:	b8 00 00 00 00       	mov    $0x0,%eax
c00244d9:	eb 05                	jmp    c00244e0 <map_key+0x60>
c00244db:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00244e0:	83 c4 04             	add    $0x4,%esp
c00244e3:	5b                   	pop    %ebx
c00244e4:	5e                   	pop    %esi
c00244e5:	5f                   	pop    %edi
c00244e6:	5d                   	pop    %ebp
c00244e7:	c3                   	ret    

c00244e8 <keyboard_interrupt>:
{
c00244e8:	55                   	push   %ebp
c00244e9:	57                   	push   %edi
c00244ea:	56                   	push   %esi
c00244eb:	53                   	push   %ebx
c00244ec:	83 ec 2c             	sub    $0x2c,%esp
  bool shift = left_shift || right_shift;
c00244ef:	0f b6 15 85 77 03 c0 	movzbl 0xc0037785,%edx
c00244f6:	80 3d 86 77 03 c0 00 	cmpb   $0x0,0xc0037786
c00244fd:	b8 01 00 00 00       	mov    $0x1,%eax
c0024502:	0f 45 d0             	cmovne %eax,%edx
  bool alt = left_alt || right_alt;
c0024505:	0f b6 3d 83 77 03 c0 	movzbl 0xc0037783,%edi
c002450c:	80 3d 84 77 03 c0 00 	cmpb   $0x0,0xc0037784
c0024513:	0f 45 f8             	cmovne %eax,%edi
  bool ctrl = left_ctrl || right_ctrl;
c0024516:	0f b6 2d 81 77 03 c0 	movzbl 0xc0037781,%ebp
c002451d:	80 3d 82 77 03 c0 00 	cmpb   $0x0,0xc0037782
c0024524:	0f 45 e8             	cmovne %eax,%ebp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024527:	e4 60                	in     $0x60,%al
  code = inb (DATA_REG);
c0024529:	0f b6 d8             	movzbl %al,%ebx
  if (code == 0xe0)
c002452c:	81 fb e0 00 00 00    	cmp    $0xe0,%ebx
c0024532:	75 08                	jne    c002453c <keyboard_interrupt+0x54>
c0024534:	e4 60                	in     $0x60,%al
    code = (code << 8) | inb (DATA_REG);
c0024536:	0f b6 d8             	movzbl %al,%ebx
c0024539:	80 cf e0             	or     $0xe0,%bh
  release = (code & 0x80) != 0;
c002453c:	89 de                	mov    %ebx,%esi
c002453e:	c1 ee 07             	shr    $0x7,%esi
c0024541:	83 e6 01             	and    $0x1,%esi
  code &= ~0x80u;
c0024544:	80 e3 7f             	and    $0x7f,%bl
  if (code == 0x3a) 
c0024547:	83 fb 3a             	cmp    $0x3a,%ebx
c002454a:	75 16                	jne    c0024562 <keyboard_interrupt+0x7a>
      if (!release)
c002454c:	89 f0                	mov    %esi,%eax
c002454e:	84 c0                	test   %al,%al
c0024550:	0f 85 1d 01 00 00    	jne    c0024673 <keyboard_interrupt+0x18b>
        caps_lock = !caps_lock;
c0024556:	80 35 80 77 03 c0 01 	xorb   $0x1,0xc0037780
c002455d:	e9 11 01 00 00       	jmp    c0024673 <keyboard_interrupt+0x18b>
  bool shift = left_shift || right_shift;
c0024562:	89 d0                	mov    %edx,%eax
c0024564:	83 e0 01             	and    $0x1,%eax
c0024567:	88 44 24 0f          	mov    %al,0xf(%esp)
  else if (map_key (invariant_keymap, code, &c)
c002456b:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002456f:	89 da                	mov    %ebx,%edx
c0024571:	b8 40 d4 02 c0       	mov    $0xc002d440,%eax
c0024576:	e8 05 ff ff ff       	call   c0024480 <map_key>
c002457b:	84 c0                	test   %al,%al
c002457d:	75 23                	jne    c00245a2 <keyboard_interrupt+0xba>
           || (!shift && map_key (unshifted_keymap, code, &c))
c002457f:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0024584:	0f 85 c5 00 00 00    	jne    c002464f <keyboard_interrupt+0x167>
c002458a:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002458e:	89 da                	mov    %ebx,%edx
c0024590:	b8 00 d4 02 c0       	mov    $0xc002d400,%eax
c0024595:	e8 e6 fe ff ff       	call   c0024480 <map_key>
c002459a:	84 c0                	test   %al,%al
c002459c:	0f 84 c5 00 00 00    	je     c0024667 <keyboard_interrupt+0x17f>
      if (!release) 
c00245a2:	89 f0                	mov    %esi,%eax
c00245a4:	84 c0                	test   %al,%al
c00245a6:	0f 85 c7 00 00 00    	jne    c0024673 <keyboard_interrupt+0x18b>
          if (c == 0177 && ctrl && alt)
c00245ac:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c00245b1:	3c 7f                	cmp    $0x7f,%al
c00245b3:	75 0f                	jne    c00245c4 <keyboard_interrupt+0xdc>
c00245b5:	21 fd                	and    %edi,%ebp
c00245b7:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c00245bd:	74 1b                	je     c00245da <keyboard_interrupt+0xf2>
            shutdown_reboot ();
c00245bf:	e8 06 1e 00 00       	call   c00263ca <shutdown_reboot>
          if (ctrl && c >= 0x40 && c < 0x60) 
c00245c4:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c00245ca:	74 0e                	je     c00245da <keyboard_interrupt+0xf2>
c00245cc:	8d 50 c0             	lea    -0x40(%eax),%edx
c00245cf:	80 fa 1f             	cmp    $0x1f,%dl
c00245d2:	77 06                	ja     c00245da <keyboard_interrupt+0xf2>
              c -= 0x40; 
c00245d4:	88 54 24 1f          	mov    %dl,0x1f(%esp)
c00245d8:	eb 20                	jmp    c00245fa <keyboard_interrupt+0x112>
          else if (shift == caps_lock)
c00245da:	0f b6 4c 24 0f       	movzbl 0xf(%esp),%ecx
c00245df:	3a 0d 80 77 03 c0    	cmp    0xc0037780,%cl
c00245e5:	75 13                	jne    c00245fa <keyboard_interrupt+0x112>
            c = tolower (c);
c00245e7:	0f b6 c0             	movzbl %al,%eax
#ifndef __LIB_CTYPE_H
#define __LIB_CTYPE_H

static inline int islower (int c) { return c >= 'a' && c <= 'z'; }
static inline int isupper (int c) { return c >= 'A' && c <= 'Z'; }
c00245ea:	8d 48 bf             	lea    -0x41(%eax),%ecx
static inline int isascii (int c) { return c >= 0 && c < 128; }
static inline int ispunct (int c) {
  return isprint (c) && !isalnum (c) && !isspace (c);
}

static inline int tolower (int c) { return isupper (c) ? c - 'A' + 'a' : c; }
c00245ed:	8d 50 20             	lea    0x20(%eax),%edx
c00245f0:	83 f9 19             	cmp    $0x19,%ecx
c00245f3:	0f 46 c2             	cmovbe %edx,%eax
c00245f6:	88 44 24 1f          	mov    %al,0x1f(%esp)
          if (alt)
c00245fa:	f7 c7 01 00 00 00    	test   $0x1,%edi
c0024600:	74 05                	je     c0024607 <keyboard_interrupt+0x11f>
            c += 0x80;
c0024602:	80 44 24 1f 80       	addb   $0x80,0x1f(%esp)
          if (!input_full ())
c0024607:	e8 11 18 00 00       	call   c0025e1d <input_full>
c002460c:	84 c0                	test   %al,%al
c002460e:	75 63                	jne    c0024673 <keyboard_interrupt+0x18b>
              key_cnt++;
c0024610:	83 05 78 77 03 c0 01 	addl   $0x1,0xc0037778
c0024617:	83 15 7c 77 03 c0 00 	adcl   $0x0,0xc003777c
              input_putc (c);
c002461e:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c0024623:	89 04 24             	mov    %eax,(%esp)
c0024626:	e8 2d 17 00 00       	call   c0025d58 <input_putc>
c002462b:	eb 46                	jmp    c0024673 <keyboard_interrupt+0x18b>
        if (key->scancode == code)
c002462d:	39 d3                	cmp    %edx,%ebx
c002462f:	75 13                	jne    c0024644 <keyboard_interrupt+0x15c>
c0024631:	eb 05                	jmp    c0024638 <keyboard_interrupt+0x150>
      for (key = shift_keys; key->scancode != 0; key++) 
c0024633:	b8 80 d3 02 c0       	mov    $0xc002d380,%eax
            *key->state_var = !release;
c0024638:	8b 40 04             	mov    0x4(%eax),%eax
c002463b:	89 f2                	mov    %esi,%edx
c002463d:	83 f2 01             	xor    $0x1,%edx
c0024640:	88 10                	mov    %dl,(%eax)
            break;
c0024642:	eb 2f                	jmp    c0024673 <keyboard_interrupt+0x18b>
      for (key = shift_keys; key->scancode != 0; key++) 
c0024644:	83 c0 08             	add    $0x8,%eax
c0024647:	8b 10                	mov    (%eax),%edx
c0024649:	85 d2                	test   %edx,%edx
c002464b:	75 e0                	jne    c002462d <keyboard_interrupt+0x145>
c002464d:	eb 24                	jmp    c0024673 <keyboard_interrupt+0x18b>
           || (shift && map_key (shifted_keymap, code, &c)))
c002464f:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c0024653:	89 da                	mov    %ebx,%edx
c0024655:	b8 c0 d3 02 c0       	mov    $0xc002d3c0,%eax
c002465a:	e8 21 fe ff ff       	call   c0024480 <map_key>
c002465f:	84 c0                	test   %al,%al
c0024661:	0f 85 3b ff ff ff    	jne    c00245a2 <keyboard_interrupt+0xba>
        if (key->scancode == code)
c0024667:	83 fb 2a             	cmp    $0x2a,%ebx
c002466a:	74 c7                	je     c0024633 <keyboard_interrupt+0x14b>
      for (key = shift_keys; key->scancode != 0; key++) 
c002466c:	b8 80 d3 02 c0       	mov    $0xc002d380,%eax
c0024671:	eb d1                	jmp    c0024644 <keyboard_interrupt+0x15c>
}
c0024673:	83 c4 2c             	add    $0x2c,%esp
c0024676:	5b                   	pop    %ebx
c0024677:	5e                   	pop    %esi
c0024678:	5f                   	pop    %edi
c0024679:	5d                   	pop    %ebp
c002467a:	c3                   	ret    

c002467b <kbd_init>:
{
c002467b:	83 ec 1c             	sub    $0x1c,%esp
  intr_register_ext (0x21, keyboard_interrupt, "8042 Keyboard");
c002467e:	c7 44 24 08 c9 ed 02 	movl   $0xc002edc9,0x8(%esp)
c0024685:	c0 
c0024686:	c7 44 24 04 e8 44 02 	movl   $0xc00244e8,0x4(%esp)
c002468d:	c0 
c002468e:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c0024695:	e8 19 d5 ff ff       	call   c0021bb3 <intr_register_ext>
}
c002469a:	83 c4 1c             	add    $0x1c,%esp
c002469d:	c3                   	ret    

c002469e <kbd_print_stats>:
{
c002469e:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Keyboard: %lld keys pressed\n", key_cnt);
c00246a1:	a1 78 77 03 c0       	mov    0xc0037778,%eax
c00246a6:	8b 15 7c 77 03 c0    	mov    0xc003777c,%edx
c00246ac:	89 44 24 04          	mov    %eax,0x4(%esp)
c00246b0:	89 54 24 08          	mov    %edx,0x8(%esp)
c00246b4:	c7 04 24 d7 ed 02 c0 	movl   $0xc002edd7,(%esp)
c00246bb:	e8 9e 24 00 00       	call   c0026b5e <printf>
}
c00246c0:	83 c4 1c             	add    $0x1c,%esp
c00246c3:	c3                   	ret    
c00246c4:	90                   	nop
c00246c5:	90                   	nop
c00246c6:	90                   	nop
c00246c7:	90                   	nop
c00246c8:	90                   	nop
c00246c9:	90                   	nop
c00246ca:	90                   	nop
c00246cb:	90                   	nop
c00246cc:	90                   	nop
c00246cd:	90                   	nop
c00246ce:	90                   	nop
c00246cf:	90                   	nop

c00246d0 <move_cursor>:
/* Moves the hardware cursor to (cx,cy). */
static void
move_cursor (void) 
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp = cx + COL_CNT * cy;
c00246d0:	8b 0d 90 77 03 c0    	mov    0xc0037790,%ecx
c00246d6:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c00246d9:	c1 e1 04             	shl    $0x4,%ecx
c00246dc:	66 03 0d 94 77 03 c0 	add    0xc0037794,%cx
  outw (0x3d4, 0x0e | (cp & 0xff00));
c00246e3:	89 c8                	mov    %ecx,%eax
c00246e5:	b0 00                	mov    $0x0,%al
c00246e7:	83 c8 0e             	or     $0xe,%eax
/* Writes the 16-bit DATA to PORT. */
static inline void
outw (uint16_t port, uint16_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c00246ea:	ba d4 03 00 00       	mov    $0x3d4,%edx
c00246ef:	66 ef                	out    %ax,(%dx)
  outw (0x3d4, 0x0f | (cp << 8));
c00246f1:	89 c8                	mov    %ecx,%eax
c00246f3:	c1 e0 08             	shl    $0x8,%eax
c00246f6:	83 c8 0f             	or     $0xf,%eax
c00246f9:	66 ef                	out    %ax,(%dx)
c00246fb:	c3                   	ret    

c00246fc <newline>:
  cx = 0;
c00246fc:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024703:	00 00 00 
  cy++;
c0024706:	a1 90 77 03 c0       	mov    0xc0037790,%eax
c002470b:	83 c0 01             	add    $0x1,%eax
  if (cy >= ROW_CNT)
c002470e:	83 f8 18             	cmp    $0x18,%eax
c0024711:	77 06                	ja     c0024719 <newline+0x1d>
  cy++;
c0024713:	a3 90 77 03 c0       	mov    %eax,0xc0037790
c0024718:	c3                   	ret    
{
c0024719:	53                   	push   %ebx
c002471a:	83 ec 18             	sub    $0x18,%esp
      cy = ROW_CNT - 1;
c002471d:	c7 05 90 77 03 c0 18 	movl   $0x18,0xc0037790
c0024724:	00 00 00 
      memmove (&fb[0], &fb[1], sizeof fb[0] * (ROW_CNT - 1));
c0024727:	8b 1d 8c 77 03 c0    	mov    0xc003778c,%ebx
c002472d:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
c0024734:	00 
c0024735:	8d 83 a0 00 00 00    	lea    0xa0(%ebx),%eax
c002473b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002473f:	89 1c 24             	mov    %ebx,(%esp)
c0024742:	e8 e6 31 00 00       	call   c002792d <memmove>
  for (x = 0; x < COL_CNT; x++)
c0024747:	b8 00 00 00 00       	mov    $0x0,%eax
      fb[y][x][0] = ' ';
c002474c:	c6 84 43 00 0f 00 00 	movb   $0x20,0xf00(%ebx,%eax,2)
c0024753:	20 
      fb[y][x][1] = GRAY_ON_BLACK;
c0024754:	c6 84 43 01 0f 00 00 	movb   $0x7,0xf01(%ebx,%eax,2)
c002475b:	07 
  for (x = 0; x < COL_CNT; x++)
c002475c:	83 c0 01             	add    $0x1,%eax
c002475f:	83 f8 50             	cmp    $0x50,%eax
c0024762:	75 e8                	jne    c002474c <newline+0x50>
}
c0024764:	83 c4 18             	add    $0x18,%esp
c0024767:	5b                   	pop    %ebx
c0024768:	c3                   	ret    

c0024769 <vga_putc>:
{
c0024769:	57                   	push   %edi
c002476a:	56                   	push   %esi
c002476b:	53                   	push   %ebx
c002476c:	83 ec 10             	sub    $0x10,%esp
c002476f:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  enum intr_level old_level = intr_disable ();
c0024773:	e8 97 d2 ff ff       	call   c0021a0f <intr_disable>
c0024778:	89 c6                	mov    %eax,%esi
  if (!inited)
c002477a:	80 3d 88 77 03 c0 00 	cmpb   $0x0,0xc0037788
c0024781:	75 5e                	jne    c00247e1 <vga_putc+0x78>
      fb = ptov (0xb8000);
c0024783:	c7 05 8c 77 03 c0 00 	movl   $0xc00b8000,0xc003778c
c002478a:	80 0b c0 
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002478d:	ba d4 03 00 00       	mov    $0x3d4,%edx
c0024792:	b8 0e 00 00 00       	mov    $0xe,%eax
c0024797:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024798:	b9 d5 03 00 00       	mov    $0x3d5,%ecx
c002479d:	89 ca                	mov    %ecx,%edx
c002479f:	ec                   	in     (%dx),%al
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp;

  outb (0x3d4, 0x0e);
  cp = inb (0x3d5) << 8;
c00247a0:	89 c7                	mov    %eax,%edi
c00247a2:	c1 e7 08             	shl    $0x8,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00247a5:	b2 d4                	mov    $0xd4,%dl
c00247a7:	b8 0f 00 00 00       	mov    $0xf,%eax
c00247ac:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00247ad:	89 ca                	mov    %ecx,%edx
c00247af:	ec                   	in     (%dx),%al

  outb (0x3d4, 0x0f);
  cp |= inb (0x3d5);
c00247b0:	0f b6 d0             	movzbl %al,%edx
c00247b3:	09 fa                	or     %edi,%edx

  *x = cp % COL_CNT;
c00247b5:	0f b7 c2             	movzwl %dx,%eax
c00247b8:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
c00247be:	c1 e8 16             	shr    $0x16,%eax
c00247c1:	8d 0c 80             	lea    (%eax,%eax,4),%ecx
c00247c4:	c1 e1 04             	shl    $0x4,%ecx
c00247c7:	29 ca                	sub    %ecx,%edx
c00247c9:	0f b7 d2             	movzwl %dx,%edx
c00247cc:	89 15 94 77 03 c0    	mov    %edx,0xc0037794
  *y = cp / COL_CNT;
c00247d2:	0f b7 c0             	movzwl %ax,%eax
c00247d5:	a3 90 77 03 c0       	mov    %eax,0xc0037790
      inited = true; 
c00247da:	c6 05 88 77 03 c0 01 	movb   $0x1,0xc0037788
  switch (c) 
c00247e1:	8d 43 f9             	lea    -0x7(%ebx),%eax
c00247e4:	83 f8 06             	cmp    $0x6,%eax
c00247e7:	0f 87 b8 00 00 00    	ja     c00248a5 <vga_putc+0x13c>
c00247ed:	ff 24 85 90 d4 02 c0 	jmp    *-0x3ffd2b70(,%eax,4)
c00247f4:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
      fb[y][x][0] = ' ';
c00247f9:	bb 00 00 00 00       	mov    $0x0,%ebx
c00247fe:	eb 28                	jmp    c0024828 <vga_putc+0xbf>
      newline ();
c0024800:	e8 f7 fe ff ff       	call   c00246fc <newline>
      break;
c0024805:	e9 e7 00 00 00       	jmp    c00248f1 <vga_putc+0x188>
      fb[y][x][0] = ' ';
c002480a:	c6 04 51 20          	movb   $0x20,(%ecx,%edx,2)
      fb[y][x][1] = GRAY_ON_BLACK;
c002480e:	c6 44 51 01 07       	movb   $0x7,0x1(%ecx,%edx,2)
  for (x = 0; x < COL_CNT; x++)
c0024813:	83 c2 01             	add    $0x1,%edx
c0024816:	83 fa 50             	cmp    $0x50,%edx
c0024819:	75 ef                	jne    c002480a <vga_putc+0xa1>
  for (y = 0; y < ROW_CNT; y++)
c002481b:	83 c3 01             	add    $0x1,%ebx
c002481e:	05 a0 00 00 00       	add    $0xa0,%eax
c0024823:	83 fb 19             	cmp    $0x19,%ebx
c0024826:	74 09                	je     c0024831 <vga_putc+0xc8>
      fb[y][x][0] = ' ';
c0024828:	89 c1                	mov    %eax,%ecx
c002482a:	ba 00 00 00 00       	mov    $0x0,%edx
c002482f:	eb d9                	jmp    c002480a <vga_putc+0xa1>
  cx = cy = 0;
c0024831:	c7 05 90 77 03 c0 00 	movl   $0x0,0xc0037790
c0024838:	00 00 00 
c002483b:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024842:	00 00 00 
  move_cursor ();
c0024845:	e8 86 fe ff ff       	call   c00246d0 <move_cursor>
c002484a:	e9 a2 00 00 00       	jmp    c00248f1 <vga_putc+0x188>
      if (cx > 0)
c002484f:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c0024854:	85 c0                	test   %eax,%eax
c0024856:	0f 84 95 00 00 00    	je     c00248f1 <vga_putc+0x188>
        cx--;
c002485c:	83 e8 01             	sub    $0x1,%eax
c002485f:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c0024864:	e9 88 00 00 00       	jmp    c00248f1 <vga_putc+0x188>
      cx = 0;
c0024869:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024870:	00 00 00 
      break;
c0024873:	eb 7c                	jmp    c00248f1 <vga_putc+0x188>
      cx = ROUND_UP (cx + 1, 8);
c0024875:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c002487a:	83 c0 08             	add    $0x8,%eax
c002487d:	83 e0 f8             	and    $0xfffffff8,%eax
c0024880:	a3 94 77 03 c0       	mov    %eax,0xc0037794
      if (cx >= COL_CNT)
c0024885:	83 f8 4f             	cmp    $0x4f,%eax
c0024888:	76 67                	jbe    c00248f1 <vga_putc+0x188>
        newline ();
c002488a:	e8 6d fe ff ff       	call   c00246fc <newline>
c002488f:	eb 60                	jmp    c00248f1 <vga_putc+0x188>
      intr_set_level (old_level);
c0024891:	89 34 24             	mov    %esi,(%esp)
c0024894:	e8 7d d1 ff ff       	call   c0021a16 <intr_set_level>
      speaker_beep ();
c0024899:	e8 bd 1c 00 00       	call   c002655b <speaker_beep>
      intr_disable ();
c002489e:	e8 6c d1 ff ff       	call   c0021a0f <intr_disable>
      break;
c00248a3:	eb 4c                	jmp    c00248f1 <vga_putc+0x188>
      fb[cy][cx][0] = c;
c00248a5:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
c00248aa:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c00248b0:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00248b3:	c1 e2 05             	shl    $0x5,%edx
c00248b6:	01 c2                	add    %eax,%edx
c00248b8:	8b 0d 94 77 03 c0    	mov    0xc0037794,%ecx
c00248be:	88 1c 4a             	mov    %bl,(%edx,%ecx,2)
      fb[cy][cx][1] = GRAY_ON_BLACK;
c00248c1:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c00248c7:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00248ca:	c1 e2 05             	shl    $0x5,%edx
c00248cd:	01 d0                	add    %edx,%eax
c00248cf:	8b 15 94 77 03 c0    	mov    0xc0037794,%edx
c00248d5:	c6 44 50 01 07       	movb   $0x7,0x1(%eax,%edx,2)
      if (++cx >= COL_CNT)
c00248da:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c00248df:	83 c0 01             	add    $0x1,%eax
c00248e2:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c00248e7:	83 f8 4f             	cmp    $0x4f,%eax
c00248ea:	76 05                	jbe    c00248f1 <vga_putc+0x188>
        newline ();
c00248ec:	e8 0b fe ff ff       	call   c00246fc <newline>
  move_cursor ();
c00248f1:	e8 da fd ff ff       	call   c00246d0 <move_cursor>
  intr_set_level (old_level);
c00248f6:	89 34 24             	mov    %esi,(%esp)
c00248f9:	e8 18 d1 ff ff       	call   c0021a16 <intr_set_level>
}
c00248fe:	83 c4 10             	add    $0x10,%esp
c0024901:	5b                   	pop    %ebx
c0024902:	5e                   	pop    %esi
c0024903:	5f                   	pop    %edi
c0024904:	c3                   	ret    
c0024905:	90                   	nop
c0024906:	90                   	nop
c0024907:	90                   	nop
c0024908:	90                   	nop
c0024909:	90                   	nop
c002490a:	90                   	nop
c002490b:	90                   	nop
c002490c:	90                   	nop
c002490d:	90                   	nop
c002490e:	90                   	nop
c002490f:	90                   	nop

c0024910 <init_poll>:
   Polling mode busy-waits for the serial port to become free
   before writing to it.  It's slow, but until interrupts have
   been initialized it's all we can do. */
static void
init_poll (void) 
{
c0024910:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (mode == UNINIT);
c0024913:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c002491a:	74 2c                	je     c0024948 <init_poll+0x38>
c002491c:	c7 44 24 10 50 ee 02 	movl   $0xc002ee50,0x10(%esp)
c0024923:	c0 
c0024924:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002492b:	c0 
c002492c:	c7 44 24 08 ce d4 02 	movl   $0xc002d4ce,0x8(%esp)
c0024933:	c0 
c0024934:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c002493b:	00 
c002493c:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024943:	e8 6b 40 00 00       	call   c00289b3 <debug_panic>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024948:	ba f9 03 00 00       	mov    $0x3f9,%edx
c002494d:	b8 00 00 00 00       	mov    $0x0,%eax
c0024952:	ee                   	out    %al,(%dx)
c0024953:	b2 fa                	mov    $0xfa,%dl
c0024955:	ee                   	out    %al,(%dx)
c0024956:	b2 fb                	mov    $0xfb,%dl
c0024958:	b8 83 ff ff ff       	mov    $0xffffff83,%eax
c002495d:	ee                   	out    %al,(%dx)
c002495e:	b2 f8                	mov    $0xf8,%dl
c0024960:	b8 0c 00 00 00       	mov    $0xc,%eax
c0024965:	ee                   	out    %al,(%dx)
c0024966:	b2 f9                	mov    $0xf9,%dl
c0024968:	b8 00 00 00 00       	mov    $0x0,%eax
c002496d:	ee                   	out    %al,(%dx)
c002496e:	b2 fb                	mov    $0xfb,%dl
c0024970:	b8 03 00 00 00       	mov    $0x3,%eax
c0024975:	ee                   	out    %al,(%dx)
c0024976:	b2 fc                	mov    $0xfc,%dl
c0024978:	b8 08 00 00 00       	mov    $0x8,%eax
c002497d:	ee                   	out    %al,(%dx)
  outb (IER_REG, 0);                    /* Turn off all interrupts. */
  outb (FCR_REG, 0);                    /* Disable FIFO. */
  set_serial (9600);                    /* 9.6 kbps, N-8-1. */
  outb (MCR_REG, MCR_OUT2);             /* Required to enable interrupts. */
  intq_init (&txq);
c002497e:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024985:	e8 db 14 00 00       	call   c0025e65 <intq_init>
  mode = POLL;
c002498a:	c7 05 14 78 03 c0 01 	movl   $0x1,0xc0037814
c0024991:	00 00 00 
} 
c0024994:	83 c4 2c             	add    $0x2c,%esp
c0024997:	c3                   	ret    

c0024998 <write_ier>:
}

/* Update interrupt enable register. */
static void
write_ier (void) 
{
c0024998:	53                   	push   %ebx
c0024999:	83 ec 28             	sub    $0x28,%esp
  uint8_t ier = 0;

  ASSERT (intr_get_level () == INTR_OFF);
c002499c:	e8 23 d0 ff ff       	call   c00219c4 <intr_get_level>
c00249a1:	85 c0                	test   %eax,%eax
c00249a3:	74 2c                	je     c00249d1 <write_ier+0x39>
c00249a5:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00249ac:	c0 
c00249ad:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00249b4:	c0 
c00249b5:	c7 44 24 08 c4 d4 02 	movl   $0xc002d4c4,0x8(%esp)
c00249bc:	c0 
c00249bd:	c7 44 24 04 b5 00 00 	movl   $0xb5,0x4(%esp)
c00249c4:	00 
c00249c5:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c00249cc:	e8 e2 3f 00 00       	call   c00289b3 <debug_panic>

  /* Enable transmit interrupt if we have any characters to
     transmit. */
  if (!intq_empty (&txq))
c00249d1:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c00249d8:	e8 b9 14 00 00       	call   c0025e96 <intq_empty>
  uint8_t ier = 0;
c00249dd:	3c 01                	cmp    $0x1,%al
c00249df:	19 db                	sbb    %ebx,%ebx
c00249e1:	83 e3 02             	and    $0x2,%ebx
    ier |= IER_XMIT;

  /* Enable receive interrupt if we have room to store any
     characters we receive. */
  if (!input_full ())
c00249e4:	e8 34 14 00 00       	call   c0025e1d <input_full>
    ier |= IER_RECV;
c00249e9:	89 da                	mov    %ebx,%edx
c00249eb:	83 ca 01             	or     $0x1,%edx
c00249ee:	84 c0                	test   %al,%al
c00249f0:	0f 44 da             	cmove  %edx,%ebx
c00249f3:	ba f9 03 00 00       	mov    $0x3f9,%edx
c00249f8:	89 d8                	mov    %ebx,%eax
c00249fa:	ee                   	out    %al,(%dx)
  
  outb (IER_REG, ier);
}
c00249fb:	83 c4 28             	add    $0x28,%esp
c00249fe:	5b                   	pop    %ebx
c00249ff:	c3                   	ret    

c0024a00 <serial_interrupt>:
}

/* Serial interrupt handler. */
static void
serial_interrupt (struct intr_frame *f UNUSED) 
{
c0024a00:	56                   	push   %esi
c0024a01:	53                   	push   %ebx
c0024a02:	83 ec 14             	sub    $0x14,%esp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a05:	ba fa 03 00 00       	mov    $0x3fa,%edx
c0024a0a:	ec                   	in     (%dx),%al
c0024a0b:	bb fd 03 00 00       	mov    $0x3fd,%ebx
c0024a10:	be f8 03 00 00       	mov    $0x3f8,%esi
c0024a15:	eb 0e                	jmp    c0024a25 <serial_interrupt+0x25>
c0024a17:	89 f2                	mov    %esi,%edx
c0024a19:	ec                   	in     (%dx),%al
  inb (IIR_REG);

  /* As long as we have room to receive a byte, and the hardware
     has a byte for us, receive a byte.  */
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
    input_putc (inb (RBR_REG));
c0024a1a:	0f b6 c0             	movzbl %al,%eax
c0024a1d:	89 04 24             	mov    %eax,(%esp)
c0024a20:	e8 33 13 00 00       	call   c0025d58 <input_putc>
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
c0024a25:	e8 f3 13 00 00       	call   c0025e1d <input_full>
c0024a2a:	84 c0                	test   %al,%al
c0024a2c:	74 0c                	je     c0024a3a <serial_interrupt+0x3a>
c0024a2e:	bb fd 03 00 00       	mov    $0x3fd,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a33:	be f8 03 00 00       	mov    $0x3f8,%esi
c0024a38:	eb 18                	jmp    c0024a52 <serial_interrupt+0x52>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a3a:	89 da                	mov    %ebx,%edx
c0024a3c:	ec                   	in     (%dx),%al
c0024a3d:	a8 01                	test   $0x1,%al
c0024a3f:	75 d6                	jne    c0024a17 <serial_interrupt+0x17>
c0024a41:	eb eb                	jmp    c0024a2e <serial_interrupt+0x2e>

  /* As long as we have a byte to transmit, and the hardware is
     ready to accept a byte for transmission, transmit a byte. */
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
    outb (THR_REG, intq_getc (&txq));
c0024a43:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a4a:	e8 70 16 00 00       	call   c00260bf <intq_getc>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a4f:	89 f2                	mov    %esi,%edx
c0024a51:	ee                   	out    %al,(%dx)
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
c0024a52:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a59:	e8 38 14 00 00       	call   c0025e96 <intq_empty>
c0024a5e:	84 c0                	test   %al,%al
c0024a60:	75 07                	jne    c0024a69 <serial_interrupt+0x69>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a62:	89 da                	mov    %ebx,%edx
c0024a64:	ec                   	in     (%dx),%al
c0024a65:	a8 20                	test   $0x20,%al
c0024a67:	75 da                	jne    c0024a43 <serial_interrupt+0x43>

  /* Update interrupt enable register based on queue status. */
  write_ier ();
c0024a69:	e8 2a ff ff ff       	call   c0024998 <write_ier>
}
c0024a6e:	83 c4 14             	add    $0x14,%esp
c0024a71:	5b                   	pop    %ebx
c0024a72:	5e                   	pop    %esi
c0024a73:	c3                   	ret    

c0024a74 <putc_poll>:
{
c0024a74:	53                   	push   %ebx
c0024a75:	83 ec 28             	sub    $0x28,%esp
c0024a78:	89 c3                	mov    %eax,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0024a7a:	e8 45 cf ff ff       	call   c00219c4 <intr_get_level>
c0024a7f:	85 c0                	test   %eax,%eax
c0024a81:	74 2c                	je     c0024aaf <putc_poll+0x3b>
c0024a83:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0024a8a:	c0 
c0024a8b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024a92:	c0 
c0024a93:	c7 44 24 08 ba d4 02 	movl   $0xc002d4ba,0x8(%esp)
c0024a9a:	c0 
c0024a9b:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c0024aa2:	00 
c0024aa3:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024aaa:	e8 04 3f 00 00       	call   c00289b3 <debug_panic>
c0024aaf:	ba fd 03 00 00       	mov    $0x3fd,%edx
c0024ab4:	ec                   	in     (%dx),%al
  while ((inb (LSR_REG) & LSR_THRE) == 0)
c0024ab5:	a8 20                	test   $0x20,%al
c0024ab7:	74 fb                	je     c0024ab4 <putc_poll+0x40>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024ab9:	ba f8 03 00 00       	mov    $0x3f8,%edx
c0024abe:	89 d8                	mov    %ebx,%eax
c0024ac0:	ee                   	out    %al,(%dx)
}
c0024ac1:	83 c4 28             	add    $0x28,%esp
c0024ac4:	5b                   	pop    %ebx
c0024ac5:	c3                   	ret    

c0024ac6 <serial_init_queue>:
{
c0024ac6:	53                   	push   %ebx
c0024ac7:	83 ec 28             	sub    $0x28,%esp
  if (mode == UNINIT)
c0024aca:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c0024ad1:	75 05                	jne    c0024ad8 <serial_init_queue+0x12>
    init_poll ();
c0024ad3:	e8 38 fe ff ff       	call   c0024910 <init_poll>
  ASSERT (mode == POLL);
c0024ad8:	83 3d 14 78 03 c0 01 	cmpl   $0x1,0xc0037814
c0024adf:	74 2c                	je     c0024b0d <serial_init_queue+0x47>
c0024ae1:	c7 44 24 10 76 ee 02 	movl   $0xc002ee76,0x10(%esp)
c0024ae8:	c0 
c0024ae9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024af0:	c0 
c0024af1:	c7 44 24 08 d8 d4 02 	movl   $0xc002d4d8,0x8(%esp)
c0024af8:	c0 
c0024af9:	c7 44 24 04 58 00 00 	movl   $0x58,0x4(%esp)
c0024b00:	00 
c0024b01:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024b08:	e8 a6 3e 00 00       	call   c00289b3 <debug_panic>
  intr_register_ext (0x20 + 4, serial_interrupt, "serial");
c0024b0d:	c7 44 24 08 83 ee 02 	movl   $0xc002ee83,0x8(%esp)
c0024b14:	c0 
c0024b15:	c7 44 24 04 00 4a 02 	movl   $0xc0024a00,0x4(%esp)
c0024b1c:	c0 
c0024b1d:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
c0024b24:	e8 8a d0 ff ff       	call   c0021bb3 <intr_register_ext>
  mode = QUEUE;
c0024b29:	c7 05 14 78 03 c0 02 	movl   $0x2,0xc0037814
c0024b30:	00 00 00 
  old_level = intr_disable ();
c0024b33:	e8 d7 ce ff ff       	call   c0021a0f <intr_disable>
c0024b38:	89 c3                	mov    %eax,%ebx
  write_ier ();
c0024b3a:	e8 59 fe ff ff       	call   c0024998 <write_ier>
  intr_set_level (old_level);
c0024b3f:	89 1c 24             	mov    %ebx,(%esp)
c0024b42:	e8 cf ce ff ff       	call   c0021a16 <intr_set_level>
}
c0024b47:	83 c4 28             	add    $0x28,%esp
c0024b4a:	5b                   	pop    %ebx
c0024b4b:	c3                   	ret    

c0024b4c <serial_putc>:
{
c0024b4c:	56                   	push   %esi
c0024b4d:	53                   	push   %ebx
c0024b4e:	83 ec 14             	sub    $0x14,%esp
c0024b51:	8b 74 24 20          	mov    0x20(%esp),%esi
  enum intr_level old_level = intr_disable ();
c0024b55:	e8 b5 ce ff ff       	call   c0021a0f <intr_disable>
c0024b5a:	89 c3                	mov    %eax,%ebx
  if (mode != QUEUE)
c0024b5c:	8b 15 14 78 03 c0    	mov    0xc0037814,%edx
c0024b62:	83 fa 02             	cmp    $0x2,%edx
c0024b65:	74 15                	je     c0024b7c <serial_putc+0x30>
      if (mode == UNINIT)
c0024b67:	85 d2                	test   %edx,%edx
c0024b69:	75 05                	jne    c0024b70 <serial_putc+0x24>
        init_poll ();
c0024b6b:	e8 a0 fd ff ff       	call   c0024910 <init_poll>
      putc_poll (byte); 
c0024b70:	89 f0                	mov    %esi,%eax
c0024b72:	0f b6 c0             	movzbl %al,%eax
c0024b75:	e8 fa fe ff ff       	call   c0024a74 <putc_poll>
c0024b7a:	eb 42                	jmp    c0024bbe <serial_putc+0x72>
      if (old_level == INTR_OFF && intq_full (&txq)) 
c0024b7c:	85 c0                	test   %eax,%eax
c0024b7e:	75 24                	jne    c0024ba4 <serial_putc+0x58>
c0024b80:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b87:	e8 55 13 00 00       	call   c0025ee1 <intq_full>
c0024b8c:	84 c0                	test   %al,%al
c0024b8e:	74 14                	je     c0024ba4 <serial_putc+0x58>
          putc_poll (intq_getc (&txq)); 
c0024b90:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b97:	e8 23 15 00 00       	call   c00260bf <intq_getc>
c0024b9c:	0f b6 c0             	movzbl %al,%eax
c0024b9f:	e8 d0 fe ff ff       	call   c0024a74 <putc_poll>
      intq_putc (&txq, byte); 
c0024ba4:	89 f0                	mov    %esi,%eax
c0024ba6:	0f b6 f0             	movzbl %al,%esi
c0024ba9:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024bad:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024bb4:	e8 d2 15 00 00       	call   c002618b <intq_putc>
      write_ier ();
c0024bb9:	e8 da fd ff ff       	call   c0024998 <write_ier>
  intr_set_level (old_level);
c0024bbe:	89 1c 24             	mov    %ebx,(%esp)
c0024bc1:	e8 50 ce ff ff       	call   c0021a16 <intr_set_level>
}
c0024bc6:	83 c4 14             	add    $0x14,%esp
c0024bc9:	5b                   	pop    %ebx
c0024bca:	5e                   	pop    %esi
c0024bcb:	c3                   	ret    

c0024bcc <serial_flush>:
{
c0024bcc:	53                   	push   %ebx
c0024bcd:	83 ec 18             	sub    $0x18,%esp
  enum intr_level old_level = intr_disable ();
c0024bd0:	e8 3a ce ff ff       	call   c0021a0f <intr_disable>
c0024bd5:	89 c3                	mov    %eax,%ebx
  while (!intq_empty (&txq))
c0024bd7:	eb 14                	jmp    c0024bed <serial_flush+0x21>
    putc_poll (intq_getc (&txq));
c0024bd9:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024be0:	e8 da 14 00 00       	call   c00260bf <intq_getc>
c0024be5:	0f b6 c0             	movzbl %al,%eax
c0024be8:	e8 87 fe ff ff       	call   c0024a74 <putc_poll>
  while (!intq_empty (&txq))
c0024bed:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024bf4:	e8 9d 12 00 00       	call   c0025e96 <intq_empty>
c0024bf9:	84 c0                	test   %al,%al
c0024bfb:	74 dc                	je     c0024bd9 <serial_flush+0xd>
  intr_set_level (old_level);
c0024bfd:	89 1c 24             	mov    %ebx,(%esp)
c0024c00:	e8 11 ce ff ff       	call   c0021a16 <intr_set_level>
}
c0024c05:	83 c4 18             	add    $0x18,%esp
c0024c08:	5b                   	pop    %ebx
c0024c09:	c3                   	ret    

c0024c0a <serial_notify>:
{
c0024c0a:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0024c0d:	e8 b2 cd ff ff       	call   c00219c4 <intr_get_level>
c0024c12:	85 c0                	test   %eax,%eax
c0024c14:	74 2c                	je     c0024c42 <serial_notify+0x38>
c0024c16:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0024c1d:	c0 
c0024c1e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024c25:	c0 
c0024c26:	c7 44 24 08 ac d4 02 	movl   $0xc002d4ac,0x8(%esp)
c0024c2d:	c0 
c0024c2e:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
c0024c35:	00 
c0024c36:	c7 04 24 5f ee 02 c0 	movl   $0xc002ee5f,(%esp)
c0024c3d:	e8 71 3d 00 00       	call   c00289b3 <debug_panic>
  if (mode == QUEUE)
c0024c42:	83 3d 14 78 03 c0 02 	cmpl   $0x2,0xc0037814
c0024c49:	75 05                	jne    c0024c50 <serial_notify+0x46>
    write_ier ();
c0024c4b:	e8 48 fd ff ff       	call   c0024998 <write_ier>
}
c0024c50:	83 c4 2c             	add    $0x2c,%esp
c0024c53:	c3                   	ret    

c0024c54 <check_sector>:
/* Verifies that SECTOR is a valid offset within BLOCK.
   Panics if not. */
static void
check_sector (struct block *block, block_sector_t sector)
{
  if (sector >= block->size)
c0024c54:	8b 48 1c             	mov    0x1c(%eax),%ecx
c0024c57:	39 d1                	cmp    %edx,%ecx
c0024c59:	77 36                	ja     c0024c91 <check_sector+0x3d>
{
c0024c5b:	83 ec 2c             	sub    $0x2c,%esp
    {
      /* We do not use ASSERT because we want to panic here
         regardless of whether NDEBUG is defined. */
      PANIC ("Access past end of device %s (sector=%"PRDSNu", "
c0024c5e:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024c62:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024c66:	83 c0 08             	add    $0x8,%eax
c0024c69:	89 44 24 10          	mov    %eax,0x10(%esp)
c0024c6d:	c7 44 24 0c 8c ee 02 	movl   $0xc002ee8c,0xc(%esp)
c0024c74:	c0 
c0024c75:	c7 44 24 08 07 d5 02 	movl   $0xc002d507,0x8(%esp)
c0024c7c:	c0 
c0024c7d:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
c0024c84:	00 
c0024c85:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024c8c:	e8 22 3d 00 00       	call   c00289b3 <debug_panic>
c0024c91:	f3 c3                	repz ret 

c0024c93 <block_type_name>:
{
c0024c93:	83 ec 2c             	sub    $0x2c,%esp
c0024c96:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (type < BLOCK_CNT);
c0024c9a:	83 f8 05             	cmp    $0x5,%eax
c0024c9d:	76 2c                	jbe    c0024ccb <block_type_name+0x38>
c0024c9f:	c7 44 24 10 30 ef 02 	movl   $0xc002ef30,0x10(%esp)
c0024ca6:	c0 
c0024ca7:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024cae:	c0 
c0024caf:	c7 44 24 08 4c d5 02 	movl   $0xc002d54c,0x8(%esp)
c0024cb6:	c0 
c0024cb7:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0024cbe:	00 
c0024cbf:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024cc6:	e8 e8 3c 00 00       	call   c00289b3 <debug_panic>
  return block_type_names[type];
c0024ccb:	8b 04 85 34 d5 02 c0 	mov    -0x3ffd2acc(,%eax,4),%eax
}
c0024cd2:	83 c4 2c             	add    $0x2c,%esp
c0024cd5:	c3                   	ret    

c0024cd6 <block_get_role>:
{
c0024cd6:	83 ec 2c             	sub    $0x2c,%esp
c0024cd9:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024cdd:	83 f8 03             	cmp    $0x3,%eax
c0024ce0:	76 2c                	jbe    c0024d0e <block_get_role+0x38>
c0024ce2:	c7 44 24 10 41 ef 02 	movl   $0xc002ef41,0x10(%esp)
c0024ce9:	c0 
c0024cea:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024cf1:	c0 
c0024cf2:	c7 44 24 08 23 d5 02 	movl   $0xc002d523,0x8(%esp)
c0024cf9:	c0 
c0024cfa:	c7 44 24 04 38 00 00 	movl   $0x38,0x4(%esp)
c0024d01:	00 
c0024d02:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024d09:	e8 a5 3c 00 00       	call   c00289b3 <debug_panic>
  return block_by_role[role];
c0024d0e:	8b 04 85 18 78 03 c0 	mov    -0x3ffc87e8(,%eax,4),%eax
}
c0024d15:	83 c4 2c             	add    $0x2c,%esp
c0024d18:	c3                   	ret    

c0024d19 <block_set_role>:
{
c0024d19:	83 ec 2c             	sub    $0x2c,%esp
c0024d1c:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024d20:	83 f8 03             	cmp    $0x3,%eax
c0024d23:	76 2c                	jbe    c0024d51 <block_set_role+0x38>
c0024d25:	c7 44 24 10 41 ef 02 	movl   $0xc002ef41,0x10(%esp)
c0024d2c:	c0 
c0024d2d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024d34:	c0 
c0024d35:	c7 44 24 08 14 d5 02 	movl   $0xc002d514,0x8(%esp)
c0024d3c:	c0 
c0024d3d:	c7 44 24 04 40 00 00 	movl   $0x40,0x4(%esp)
c0024d44:	00 
c0024d45:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024d4c:	e8 62 3c 00 00       	call   c00289b3 <debug_panic>
  block_by_role[role] = block;
c0024d51:	8b 54 24 34          	mov    0x34(%esp),%edx
c0024d55:	89 14 85 18 78 03 c0 	mov    %edx,-0x3ffc87e8(,%eax,4)
}
c0024d5c:	83 c4 2c             	add    $0x2c,%esp
c0024d5f:	c3                   	ret    

c0024d60 <block_first>:
{
c0024d60:	53                   	push   %ebx
c0024d61:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_begin (&all_blocks));
c0024d64:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024d6b:	e8 61 3d 00 00       	call   c0028ad1 <list_begin>
c0024d70:	89 c3                	mov    %eax,%ebx
/* Returns the block device corresponding to LIST_ELEM, or a null
   pointer if LIST_ELEM is the list end of all_blocks. */
static struct block *
list_elem_to_block (struct list_elem *list_elem)
{
  return (list_elem != list_end (&all_blocks)
c0024d72:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024d79:	e8 e5 3d 00 00       	call   c0028b63 <list_end>
          ? list_entry (list_elem, struct block, list_elem)
          : NULL);
c0024d7e:	39 c3                	cmp    %eax,%ebx
c0024d80:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d85:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d88:	83 c4 18             	add    $0x18,%esp
c0024d8b:	5b                   	pop    %ebx
c0024d8c:	c3                   	ret    

c0024d8d <block_next>:
{
c0024d8d:	53                   	push   %ebx
c0024d8e:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_next (&block->list_elem));
c0024d91:	8b 44 24 20          	mov    0x20(%esp),%eax
c0024d95:	89 04 24             	mov    %eax,(%esp)
c0024d98:	e8 72 3d 00 00       	call   c0028b0f <list_next>
c0024d9d:	89 c3                	mov    %eax,%ebx
  return (list_elem != list_end (&all_blocks)
c0024d9f:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024da6:	e8 b8 3d 00 00       	call   c0028b63 <list_end>
          : NULL);
c0024dab:	39 c3                	cmp    %eax,%ebx
c0024dad:	b8 00 00 00 00       	mov    $0x0,%eax
c0024db2:	0f 45 c3             	cmovne %ebx,%eax
}
c0024db5:	83 c4 18             	add    $0x18,%esp
c0024db8:	5b                   	pop    %ebx
c0024db9:	c3                   	ret    

c0024dba <block_get_by_name>:
{
c0024dba:	56                   	push   %esi
c0024dbb:	53                   	push   %ebx
c0024dbc:	83 ec 14             	sub    $0x14,%esp
c0024dbf:	8b 74 24 20          	mov    0x20(%esp),%esi
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024dc3:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024dca:	e8 02 3d 00 00       	call   c0028ad1 <list_begin>
c0024dcf:	89 c3                	mov    %eax,%ebx
c0024dd1:	eb 1d                	jmp    c0024df0 <block_get_by_name+0x36>
      if (!strcmp (name, block->name))
c0024dd3:	8d 43 08             	lea    0x8(%ebx),%eax
c0024dd6:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024dda:	89 34 24             	mov    %esi,(%esp)
c0024ddd:	e8 e5 2c 00 00       	call   c0027ac7 <strcmp>
c0024de2:	85 c0                	test   %eax,%eax
c0024de4:	74 21                	je     c0024e07 <block_get_by_name+0x4d>
       e = list_next (e))
c0024de6:	89 1c 24             	mov    %ebx,(%esp)
c0024de9:	e8 21 3d 00 00       	call   c0028b0f <list_next>
c0024dee:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024df0:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024df7:	e8 67 3d 00 00       	call   c0028b63 <list_end>
c0024dfc:	39 d8                	cmp    %ebx,%eax
c0024dfe:	75 d3                	jne    c0024dd3 <block_get_by_name+0x19>
  return NULL;
c0024e00:	b8 00 00 00 00       	mov    $0x0,%eax
c0024e05:	eb 02                	jmp    c0024e09 <block_get_by_name+0x4f>
c0024e07:	89 d8                	mov    %ebx,%eax
}
c0024e09:	83 c4 14             	add    $0x14,%esp
c0024e0c:	5b                   	pop    %ebx
c0024e0d:	5e                   	pop    %esi
c0024e0e:	c3                   	ret    

c0024e0f <block_read>:
{
c0024e0f:	56                   	push   %esi
c0024e10:	53                   	push   %ebx
c0024e11:	83 ec 14             	sub    $0x14,%esp
c0024e14:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0024e18:	8b 74 24 24          	mov    0x24(%esp),%esi
  check_sector (block, sector);
c0024e1c:	89 f2                	mov    %esi,%edx
c0024e1e:	89 d8                	mov    %ebx,%eax
c0024e20:	e8 2f fe ff ff       	call   c0024c54 <check_sector>
  block->ops->read (block->aux, sector, buffer);
c0024e25:	8b 43 20             	mov    0x20(%ebx),%eax
c0024e28:	8b 54 24 28          	mov    0x28(%esp),%edx
c0024e2c:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024e30:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024e34:	8b 53 24             	mov    0x24(%ebx),%edx
c0024e37:	89 14 24             	mov    %edx,(%esp)
c0024e3a:	ff 10                	call   *(%eax)
  block->read_cnt++;
c0024e3c:	83 43 28 01          	addl   $0x1,0x28(%ebx)
c0024e40:	83 53 2c 00          	adcl   $0x0,0x2c(%ebx)
}
c0024e44:	83 c4 14             	add    $0x14,%esp
c0024e47:	5b                   	pop    %ebx
c0024e48:	5e                   	pop    %esi
c0024e49:	c3                   	ret    

c0024e4a <block_write>:
{
c0024e4a:	56                   	push   %esi
c0024e4b:	53                   	push   %ebx
c0024e4c:	83 ec 24             	sub    $0x24,%esp
c0024e4f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0024e53:	8b 74 24 34          	mov    0x34(%esp),%esi
  check_sector (block, sector);
c0024e57:	89 f2                	mov    %esi,%edx
c0024e59:	89 d8                	mov    %ebx,%eax
c0024e5b:	e8 f4 fd ff ff       	call   c0024c54 <check_sector>
  ASSERT (block->type != BLOCK_FOREIGN);
c0024e60:	83 7b 18 05          	cmpl   $0x5,0x18(%ebx)
c0024e64:	75 2c                	jne    c0024e92 <block_write+0x48>
c0024e66:	c7 44 24 10 57 ef 02 	movl   $0xc002ef57,0x10(%esp)
c0024e6d:	c0 
c0024e6e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0024e75:	c0 
c0024e76:	c7 44 24 08 fb d4 02 	movl   $0xc002d4fb,0x8(%esp)
c0024e7d:	c0 
c0024e7e:	c7 44 24 04 89 00 00 	movl   $0x89,0x4(%esp)
c0024e85:	00 
c0024e86:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024e8d:	e8 21 3b 00 00       	call   c00289b3 <debug_panic>
  block->ops->write (block->aux, sector, buffer);
c0024e92:	8b 43 20             	mov    0x20(%ebx),%eax
c0024e95:	8b 54 24 38          	mov    0x38(%esp),%edx
c0024e99:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024e9d:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024ea1:	8b 53 24             	mov    0x24(%ebx),%edx
c0024ea4:	89 14 24             	mov    %edx,(%esp)
c0024ea7:	ff 50 04             	call   *0x4(%eax)
  block->write_cnt++;
c0024eaa:	83 43 30 01          	addl   $0x1,0x30(%ebx)
c0024eae:	83 53 34 00          	adcl   $0x0,0x34(%ebx)
}
c0024eb2:	83 c4 24             	add    $0x24,%esp
c0024eb5:	5b                   	pop    %ebx
c0024eb6:	5e                   	pop    %esi
c0024eb7:	c3                   	ret    

c0024eb8 <block_size>:
  return block->size;
c0024eb8:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024ebc:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0024ebf:	c3                   	ret    

c0024ec0 <block_name>:
  return block->name;
c0024ec0:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024ec4:	83 c0 08             	add    $0x8,%eax
}
c0024ec7:	c3                   	ret    

c0024ec8 <block_type>:
  return block->type;
c0024ec8:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024ecc:	8b 40 18             	mov    0x18(%eax),%eax
}
c0024ecf:	c3                   	ret    

c0024ed0 <block_print_stats>:
{
c0024ed0:	56                   	push   %esi
c0024ed1:	53                   	push   %ebx
c0024ed2:	83 ec 24             	sub    $0x24,%esp
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024ed5:	be 00 00 00 00       	mov    $0x0,%esi
      struct block *block = block_by_role[i];
c0024eda:	8b 1c b5 18 78 03 c0 	mov    -0x3ffc87e8(,%esi,4),%ebx
      if (block != NULL)
c0024ee1:	85 db                	test   %ebx,%ebx
c0024ee3:	74 3e                	je     c0024f23 <block_print_stats+0x53>
          printf ("%s (%s): %llu reads, %llu writes\n",
c0024ee5:	8b 43 18             	mov    0x18(%ebx),%eax
c0024ee8:	89 04 24             	mov    %eax,(%esp)
c0024eeb:	e8 a3 fd ff ff       	call   c0024c93 <block_type_name>
c0024ef0:	8b 53 30             	mov    0x30(%ebx),%edx
c0024ef3:	8b 4b 34             	mov    0x34(%ebx),%ecx
c0024ef6:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024efa:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024efe:	8b 53 28             	mov    0x28(%ebx),%edx
c0024f01:	8b 4b 2c             	mov    0x2c(%ebx),%ecx
c0024f04:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0024f08:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0024f0c:	89 44 24 08          	mov    %eax,0x8(%esp)
c0024f10:	83 c3 08             	add    $0x8,%ebx
c0024f13:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024f17:	c7 04 24 c0 ee 02 c0 	movl   $0xc002eec0,(%esp)
c0024f1e:	e8 3b 1c 00 00       	call   c0026b5e <printf>
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024f23:	83 c6 01             	add    $0x1,%esi
c0024f26:	83 fe 04             	cmp    $0x4,%esi
c0024f29:	75 af                	jne    c0024eda <block_print_stats+0xa>
}
c0024f2b:	83 c4 24             	add    $0x24,%esp
c0024f2e:	5b                   	pop    %ebx
c0024f2f:	5e                   	pop    %esi
c0024f30:	c3                   	ret    

c0024f31 <block_register>:
{
c0024f31:	55                   	push   %ebp
c0024f32:	57                   	push   %edi
c0024f33:	56                   	push   %esi
c0024f34:	53                   	push   %ebx
c0024f35:	83 ec 1c             	sub    $0x1c,%esp
c0024f38:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0024f3c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
  struct block *block = malloc (sizeof *block);
c0024f40:	c7 04 24 38 00 00 00 	movl   $0x38,(%esp)
c0024f47:	e8 28 eb ff ff       	call   c0023a74 <malloc>
c0024f4c:	89 c6                	mov    %eax,%esi
  if (block == NULL)
c0024f4e:	85 c0                	test   %eax,%eax
c0024f50:	75 24                	jne    c0024f76 <block_register+0x45>
    PANIC ("Failed to allocate memory for block device descriptor");
c0024f52:	c7 44 24 0c e4 ee 02 	movl   $0xc002eee4,0xc(%esp)
c0024f59:	c0 
c0024f5a:	c7 44 24 08 ec d4 02 	movl   $0xc002d4ec,0x8(%esp)
c0024f61:	c0 
c0024f62:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0024f69:	00 
c0024f6a:	c7 04 24 1a ef 02 c0 	movl   $0xc002ef1a,(%esp)
c0024f71:	e8 3d 3a 00 00       	call   c00289b3 <debug_panic>
  list_push_back (&all_blocks, &block->list_elem);
c0024f76:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f7a:	c7 04 24 5c 5a 03 c0 	movl   $0xc0035a5c,(%esp)
c0024f81:	e8 7b 40 00 00       	call   c0029001 <list_push_back>
  strlcpy (block->name, name, sizeof block->name);
c0024f86:	8d 6e 08             	lea    0x8(%esi),%ebp
c0024f89:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c0024f90:	00 
c0024f91:	8b 44 24 30          	mov    0x30(%esp),%eax
c0024f95:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f99:	89 2c 24             	mov    %ebp,(%esp)
c0024f9c:	e8 25 30 00 00       	call   c0027fc6 <strlcpy>
  block->type = type;
c0024fa1:	8b 44 24 34          	mov    0x34(%esp),%eax
c0024fa5:	89 46 18             	mov    %eax,0x18(%esi)
  block->size = size;
c0024fa8:	89 5e 1c             	mov    %ebx,0x1c(%esi)
  block->ops = ops;
c0024fab:	8b 44 24 40          	mov    0x40(%esp),%eax
c0024faf:	89 46 20             	mov    %eax,0x20(%esi)
  block->aux = aux;
c0024fb2:	8b 44 24 44          	mov    0x44(%esp),%eax
c0024fb6:	89 46 24             	mov    %eax,0x24(%esi)
  block->read_cnt = 0;
c0024fb9:	c7 46 28 00 00 00 00 	movl   $0x0,0x28(%esi)
c0024fc0:	c7 46 2c 00 00 00 00 	movl   $0x0,0x2c(%esi)
  block->write_cnt = 0;
c0024fc7:	c7 46 30 00 00 00 00 	movl   $0x0,0x30(%esi)
c0024fce:	c7 46 34 00 00 00 00 	movl   $0x0,0x34(%esi)
  printf ("%s: %'"PRDSNu" sectors (", block->name, block->size);
c0024fd5:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0024fd9:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0024fdd:	c7 04 24 74 ef 02 c0 	movl   $0xc002ef74,(%esp)
c0024fe4:	e8 75 1b 00 00       	call   c0026b5e <printf>
  print_human_readable_size ((uint64_t) block->size * BLOCK_SECTOR_SIZE);
c0024fe9:	8b 4e 1c             	mov    0x1c(%esi),%ecx
c0024fec:	bb 00 00 00 00       	mov    $0x0,%ebx
c0024ff1:	0f a4 cb 09          	shld   $0x9,%ecx,%ebx
c0024ff5:	c1 e1 09             	shl    $0x9,%ecx
c0024ff8:	89 0c 24             	mov    %ecx,(%esp)
c0024ffb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024fff:	e8 25 24 00 00       	call   c0027429 <print_human_readable_size>
  printf (")");
c0025004:	c7 04 24 29 00 00 00 	movl   $0x29,(%esp)
c002500b:	e8 3c 57 00 00       	call   c002a74c <putchar>
  if (extra_info != NULL)
c0025010:	85 ff                	test   %edi,%edi
c0025012:	74 10                	je     c0025024 <block_register+0xf3>
    printf (", %s", extra_info);
c0025014:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0025018:	c7 04 24 86 ef 02 c0 	movl   $0xc002ef86,(%esp)
c002501f:	e8 3a 1b 00 00       	call   c0026b5e <printf>
  printf ("\n");
c0025024:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002502b:	e8 1c 57 00 00       	call   c002a74c <putchar>
}
c0025030:	89 f0                	mov    %esi,%eax
c0025032:	83 c4 1c             	add    $0x1c,%esp
c0025035:	5b                   	pop    %ebx
c0025036:	5e                   	pop    %esi
c0025037:	5f                   	pop    %edi
c0025038:	5d                   	pop    %ebp
c0025039:	c3                   	ret    

c002503a <partition_read>:

/* Reads sector SECTOR from partition P into BUFFER, which must
   have room for BLOCK_SECTOR_SIZE bytes. */
static void
partition_read (void *p_, block_sector_t sector, void *buffer)
{
c002503a:	83 ec 1c             	sub    $0x1c,%esp
c002503d:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_read (p->block, p->start + sector, buffer);
c0025041:	8b 54 24 28          	mov    0x28(%esp),%edx
c0025045:	89 54 24 08          	mov    %edx,0x8(%esp)
c0025049:	8b 54 24 24          	mov    0x24(%esp),%edx
c002504d:	03 50 04             	add    0x4(%eax),%edx
c0025050:	89 54 24 04          	mov    %edx,0x4(%esp)
c0025054:	8b 00                	mov    (%eax),%eax
c0025056:	89 04 24             	mov    %eax,(%esp)
c0025059:	e8 b1 fd ff ff       	call   c0024e0f <block_read>
}
c002505e:	83 c4 1c             	add    $0x1c,%esp
c0025061:	c3                   	ret    

c0025062 <read_partition_table>:
{
c0025062:	55                   	push   %ebp
c0025063:	57                   	push   %edi
c0025064:	56                   	push   %esi
c0025065:	53                   	push   %ebx
c0025066:	81 ec dc 00 00 00    	sub    $0xdc,%esp
c002506c:	89 c5                	mov    %eax,%ebp
c002506e:	89 d6                	mov    %edx,%esi
c0025070:	89 4c 24 20          	mov    %ecx,0x20(%esp)
  if (sector >= block_size (block))
c0025074:	89 04 24             	mov    %eax,(%esp)
c0025077:	e8 3c fe ff ff       	call   c0024eb8 <block_size>
c002507c:	39 f0                	cmp    %esi,%eax
c002507e:	77 21                	ja     c00250a1 <read_partition_table+0x3f>
      printf ("%s: Partition table at sector %"PRDSNu" past end of device.\n",
c0025080:	89 2c 24             	mov    %ebp,(%esp)
c0025083:	e8 38 fe ff ff       	call   c0024ec0 <block_name>
c0025088:	89 74 24 08          	mov    %esi,0x8(%esp)
c002508c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025090:	c7 04 24 38 f4 02 c0 	movl   $0xc002f438,(%esp)
c0025097:	e8 c2 1a 00 00       	call   c0026b5e <printf>
      return;
c002509c:	e9 3b 03 00 00       	jmp    c00253dc <read_partition_table+0x37a>
  pt = malloc (sizeof *pt);
c00250a1:	c7 04 24 00 02 00 00 	movl   $0x200,(%esp)
c00250a8:	e8 c7 e9 ff ff       	call   c0023a74 <malloc>
c00250ad:	89 c7                	mov    %eax,%edi
  if (pt == NULL)
c00250af:	85 c0                	test   %eax,%eax
c00250b1:	75 24                	jne    c00250d7 <read_partition_table+0x75>
    PANIC ("Failed to allocate memory for partition table.");
c00250b3:	c7 44 24 0c 70 f4 02 	movl   $0xc002f470,0xc(%esp)
c00250ba:	c0 
c00250bb:	c7 44 24 08 70 d9 02 	movl   $0xc002d970,0x8(%esp)
c00250c2:	c0 
c00250c3:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c00250ca:	00 
c00250cb:	c7 04 24 a7 ef 02 c0 	movl   $0xc002efa7,(%esp)
c00250d2:	e8 dc 38 00 00       	call   c00289b3 <debug_panic>
  block_read (block, 0, pt);
c00250d7:	89 44 24 08          	mov    %eax,0x8(%esp)
c00250db:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00250e2:	00 
c00250e3:	89 2c 24             	mov    %ebp,(%esp)
c00250e6:	e8 24 fd ff ff       	call   c0024e0f <block_read>
  if (pt->signature != 0xaa55)
c00250eb:	66 81 bf fe 01 00 00 	cmpw   $0xaa55,0x1fe(%edi)
c00250f2:	55 aa 
c00250f4:	74 4a                	je     c0025140 <read_partition_table+0xde>
      if (primary_extended_sector == 0)
c00250f6:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c00250fb:	75 1a                	jne    c0025117 <read_partition_table+0xb5>
        printf ("%s: Invalid partition table signature\n", block_name (block));
c00250fd:	89 2c 24             	mov    %ebp,(%esp)
c0025100:	e8 bb fd ff ff       	call   c0024ec0 <block_name>
c0025105:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025109:	c7 04 24 a0 f4 02 c0 	movl   $0xc002f4a0,(%esp)
c0025110:	e8 49 1a 00 00       	call   c0026b5e <printf>
c0025115:	eb 1c                	jmp    c0025133 <read_partition_table+0xd1>
        printf ("%s: Invalid extended partition table in sector %"PRDSNu"\n",
c0025117:	89 2c 24             	mov    %ebp,(%esp)
c002511a:	e8 a1 fd ff ff       	call   c0024ec0 <block_name>
c002511f:	89 74 24 08          	mov    %esi,0x8(%esp)
c0025123:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025127:	c7 04 24 c8 f4 02 c0 	movl   $0xc002f4c8,(%esp)
c002512e:	e8 2b 1a 00 00       	call   c0026b5e <printf>
      free (pt);
c0025133:	89 3c 24             	mov    %edi,(%esp)
c0025136:	e8 c0 ea ff ff       	call   c0023bfb <free>
      return;
c002513b:	e9 9c 02 00 00       	jmp    c00253dc <read_partition_table+0x37a>
c0025140:	89 fb                	mov    %edi,%ebx
  if (pt->signature != 0xaa55)
c0025142:	b8 04 00 00 00       	mov    $0x4,%eax
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025147:	89 7c 24 28          	mov    %edi,0x28(%esp)
c002514b:	89 74 24 24          	mov    %esi,0x24(%esp)
c002514f:	89 c6                	mov    %eax,%esi
c0025151:	89 df                	mov    %ebx,%edi
      if (e->size == 0 || e->type == 0)
c0025153:	83 bb ca 01 00 00 00 	cmpl   $0x0,0x1ca(%ebx)
c002515a:	0f 84 64 02 00 00    	je     c00253c4 <read_partition_table+0x362>
c0025160:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c0025167:	84 c0                	test   %al,%al
c0025169:	0f 84 55 02 00 00    	je     c00253c4 <read_partition_table+0x362>
               || e->type == 0x0f    /* Windows 98 extended partition. */
c002516f:	89 c2                	mov    %eax,%edx
c0025171:	83 e2 7f             	and    $0x7f,%edx
      else if (e->type == 0x05       /* Extended partition. */
c0025174:	80 fa 05             	cmp    $0x5,%dl
c0025177:	74 08                	je     c0025181 <read_partition_table+0x11f>
c0025179:	3c 0f                	cmp    $0xf,%al
c002517b:	74 04                	je     c0025181 <read_partition_table+0x11f>
               || e->type == 0xc5)   /* DR-DOS extended partition. */
c002517d:	3c c5                	cmp    $0xc5,%al
c002517f:	75 67                	jne    c00251e8 <read_partition_table+0x186>
          printf ("%s: Extended partition in sector %"PRDSNu"\n",
c0025181:	89 2c 24             	mov    %ebp,(%esp)
c0025184:	e8 37 fd ff ff       	call   c0024ec0 <block_name>
c0025189:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c002518d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0025191:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025195:	c7 04 24 fc f4 02 c0 	movl   $0xc002f4fc,(%esp)
c002519c:	e8 bd 19 00 00       	call   c0026b5e <printf>
          if (sector == 0)
c00251a1:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c00251a6:	75 1e                	jne    c00251c6 <read_partition_table+0x164>
            read_partition_table (block, e->offset, e->offset, part_nr);
c00251a8:	8b 97 c6 01 00 00    	mov    0x1c6(%edi),%edx
c00251ae:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251b5:	89 04 24             	mov    %eax,(%esp)
c00251b8:	89 d1                	mov    %edx,%ecx
c00251ba:	89 e8                	mov    %ebp,%eax
c00251bc:	e8 a1 fe ff ff       	call   c0025062 <read_partition_table>
c00251c1:	e9 fe 01 00 00       	jmp    c00253c4 <read_partition_table+0x362>
            read_partition_table (block, e->offset + primary_extended_sector,
c00251c6:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c00251ca:	89 ca                	mov    %ecx,%edx
c00251cc:	03 97 c6 01 00 00    	add    0x1c6(%edi),%edx
c00251d2:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251d9:	89 04 24             	mov    %eax,(%esp)
c00251dc:	89 e8                	mov    %ebp,%eax
c00251de:	e8 7f fe ff ff       	call   c0025062 <read_partition_table>
c00251e3:	e9 dc 01 00 00       	jmp    c00253c4 <read_partition_table+0x362>
          ++*part_nr;
c00251e8:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251ef:	8b 00                	mov    (%eax),%eax
c00251f1:	83 c0 01             	add    $0x1,%eax
c00251f4:	89 44 24 34          	mov    %eax,0x34(%esp)
c00251f8:	8b 8c 24 f0 00 00 00 	mov    0xf0(%esp),%ecx
c00251ff:	89 01                	mov    %eax,(%ecx)
          found_partition (block, e->type, e->offset + sector,
c0025201:	8b 83 ca 01 00 00    	mov    0x1ca(%ebx),%eax
c0025207:	89 44 24 30          	mov    %eax,0x30(%esp)
c002520b:	8b 44 24 24          	mov    0x24(%esp),%eax
c002520f:	03 83 c6 01 00 00    	add    0x1c6(%ebx),%eax
c0025215:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c0025219:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c0025220:	88 44 24 3b          	mov    %al,0x3b(%esp)
  if (start >= block_size (block))
c0025224:	89 2c 24             	mov    %ebp,(%esp)
c0025227:	e8 8c fc ff ff       	call   c0024eb8 <block_size>
c002522c:	39 44 24 2c          	cmp    %eax,0x2c(%esp)
c0025230:	72 2d                	jb     c002525f <read_partition_table+0x1fd>
    printf ("%s%d: Partition starts past end of device (sector %"PRDSNu")\n",
c0025232:	89 2c 24             	mov    %ebp,(%esp)
c0025235:	e8 86 fc ff ff       	call   c0024ec0 <block_name>
c002523a:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002523e:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0025242:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025246:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002524a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002524e:	c7 04 24 24 f5 02 c0 	movl   $0xc002f524,(%esp)
c0025255:	e8 04 19 00 00       	call   c0026b5e <printf>
c002525a:	e9 65 01 00 00       	jmp    c00253c4 <read_partition_table+0x362>
  else if (start + size < start || start + size > block_size (block))
c002525f:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
c0025263:	03 7c 24 30          	add    0x30(%esp),%edi
c0025267:	72 0c                	jb     c0025275 <read_partition_table+0x213>
c0025269:	89 2c 24             	mov    %ebp,(%esp)
c002526c:	e8 47 fc ff ff       	call   c0024eb8 <block_size>
c0025271:	39 c7                	cmp    %eax,%edi
c0025273:	76 3d                	jbe    c00252b2 <read_partition_table+0x250>
    printf ("%s%d: Partition end (%"PRDSNu") past end of device (%"PRDSNu")\n",
c0025275:	89 2c 24             	mov    %ebp,(%esp)
c0025278:	e8 3b fc ff ff       	call   c0024eb8 <block_size>
c002527d:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c0025281:	89 2c 24             	mov    %ebp,(%esp)
c0025284:	e8 37 fc ff ff       	call   c0024ec0 <block_name>
c0025289:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002528d:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0025291:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025295:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025299:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002529d:	89 44 24 04          	mov    %eax,0x4(%esp)
c00252a1:	c7 04 24 5c f5 02 c0 	movl   $0xc002f55c,(%esp)
c00252a8:	e8 b1 18 00 00       	call   c0026b5e <printf>
c00252ad:	e9 12 01 00 00       	jmp    c00253c4 <read_partition_table+0x362>
      enum block_type type = (part_type == 0x20 ? BLOCK_KERNEL
c00252b2:	c7 44 24 3c 00 00 00 	movl   $0x0,0x3c(%esp)
c00252b9:	00 
c00252ba:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
c00252bf:	3c 20                	cmp    $0x20,%al
c00252c1:	74 28                	je     c00252eb <read_partition_table+0x289>
c00252c3:	c7 44 24 3c 01 00 00 	movl   $0x1,0x3c(%esp)
c00252ca:	00 
c00252cb:	3c 21                	cmp    $0x21,%al
c00252cd:	74 1c                	je     c00252eb <read_partition_table+0x289>
c00252cf:	c7 44 24 3c 02 00 00 	movl   $0x2,0x3c(%esp)
c00252d6:	00 
c00252d7:	3c 22                	cmp    $0x22,%al
c00252d9:	74 10                	je     c00252eb <read_partition_table+0x289>
c00252db:	3c 23                	cmp    $0x23,%al
c00252dd:	0f 95 c0             	setne  %al
c00252e0:	0f b6 c0             	movzbl %al,%eax
c00252e3:	8d 44 00 03          	lea    0x3(%eax,%eax,1),%eax
c00252e7:	89 44 24 3c          	mov    %eax,0x3c(%esp)
      p = malloc (sizeof *p);
c00252eb:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c00252f2:	e8 7d e7 ff ff       	call   c0023a74 <malloc>
c00252f7:	89 c7                	mov    %eax,%edi
      if (p == NULL)
c00252f9:	85 c0                	test   %eax,%eax
c00252fb:	75 24                	jne    c0025321 <read_partition_table+0x2bf>
        PANIC ("Failed to allocate memory for partition descriptor");
c00252fd:	c7 44 24 0c 90 f5 02 	movl   $0xc002f590,0xc(%esp)
c0025304:	c0 
c0025305:	c7 44 24 08 60 d9 02 	movl   $0xc002d960,0x8(%esp)
c002530c:	c0 
c002530d:	c7 44 24 04 b1 00 00 	movl   $0xb1,0x4(%esp)
c0025314:	00 
c0025315:	c7 04 24 a7 ef 02 c0 	movl   $0xc002efa7,(%esp)
c002531c:	e8 92 36 00 00       	call   c00289b3 <debug_panic>
      p->block = block;
c0025321:	89 28                	mov    %ebp,(%eax)
      p->start = start;
c0025323:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c0025327:	89 47 04             	mov    %eax,0x4(%edi)
      snprintf (name, sizeof name, "%s%d", block_name (block), part_nr);
c002532a:	89 2c 24             	mov    %ebp,(%esp)
c002532d:	e8 8e fb ff ff       	call   c0024ec0 <block_name>
c0025332:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025336:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c002533a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002533e:	c7 44 24 08 c1 ef 02 	movl   $0xc002efc1,0x8(%esp)
c0025345:	c0 
c0025346:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002534d:	00 
c002534e:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025352:	89 04 24             	mov    %eax,(%esp)
c0025355:	e8 05 1f 00 00       	call   c002725f <snprintf>
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c002535a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c002535f:	8b 14 85 60 d5 02 c0 	mov    -0x3ffd2aa0(,%eax,4),%edx
c0025366:	85 d2                	test   %edx,%edx
c0025368:	b9 9f ef 02 c0       	mov    $0xc002ef9f,%ecx
c002536d:	0f 44 d1             	cmove  %ecx,%edx
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025370:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025374:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0025378:	c7 44 24 08 c6 ef 02 	movl   $0xc002efc6,0x8(%esp)
c002537f:	c0 
c0025380:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025387:	00 
c0025388:	8d 44 24 50          	lea    0x50(%esp),%eax
c002538c:	89 04 24             	mov    %eax,(%esp)
c002538f:	e8 cb 1e 00 00       	call   c002725f <snprintf>
      block_register (name, type, extra_info, size, &partition_operations, p);
c0025394:	89 7c 24 14          	mov    %edi,0x14(%esp)
c0025398:	c7 44 24 10 6c 5a 03 	movl   $0xc0035a6c,0x10(%esp)
c002539f:	c0 
c00253a0:	8b 44 24 30          	mov    0x30(%esp),%eax
c00253a4:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00253a8:	8d 44 24 50          	lea    0x50(%esp),%eax
c00253ac:	89 44 24 08          	mov    %eax,0x8(%esp)
c00253b0:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c00253b4:	89 44 24 04          	mov    %eax,0x4(%esp)
c00253b8:	8d 44 24 40          	lea    0x40(%esp),%eax
c00253bc:	89 04 24             	mov    %eax,(%esp)
c00253bf:	e8 6d fb ff ff       	call   c0024f31 <block_register>
c00253c4:	83 c3 10             	add    $0x10,%ebx
  for (i = 0; i < sizeof pt->partitions / sizeof *pt->partitions; i++)
c00253c7:	83 ee 01             	sub    $0x1,%esi
c00253ca:	0f 85 81 fd ff ff    	jne    c0025151 <read_partition_table+0xef>
c00253d0:	8b 7c 24 28          	mov    0x28(%esp),%edi
  free (pt);
c00253d4:	89 3c 24             	mov    %edi,(%esp)
c00253d7:	e8 1f e8 ff ff       	call   c0023bfb <free>
}
c00253dc:	81 c4 dc 00 00 00    	add    $0xdc,%esp
c00253e2:	5b                   	pop    %ebx
c00253e3:	5e                   	pop    %esi
c00253e4:	5f                   	pop    %edi
c00253e5:	5d                   	pop    %ebp
c00253e6:	c3                   	ret    

c00253e7 <partition_write>:
/* Write sector SECTOR to partition P from BUFFER, which must
   contain BLOCK_SECTOR_SIZE bytes.  Returns after the block has
   acknowledged receiving the data. */
static void
partition_write (void *p_, block_sector_t sector, const void *buffer)
{
c00253e7:	83 ec 1c             	sub    $0x1c,%esp
c00253ea:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_write (p->block, p->start + sector, buffer);
c00253ee:	8b 54 24 28          	mov    0x28(%esp),%edx
c00253f2:	89 54 24 08          	mov    %edx,0x8(%esp)
c00253f6:	8b 54 24 24          	mov    0x24(%esp),%edx
c00253fa:	03 50 04             	add    0x4(%eax),%edx
c00253fd:	89 54 24 04          	mov    %edx,0x4(%esp)
c0025401:	8b 00                	mov    (%eax),%eax
c0025403:	89 04 24             	mov    %eax,(%esp)
c0025406:	e8 3f fa ff ff       	call   c0024e4a <block_write>
}
c002540b:	83 c4 1c             	add    $0x1c,%esp
c002540e:	c3                   	ret    

c002540f <partition_scan>:
{
c002540f:	53                   	push   %ebx
c0025410:	83 ec 28             	sub    $0x28,%esp
c0025413:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  int part_nr = 0;
c0025417:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002541e:	00 
  read_partition_table (block, 0, 0, &part_nr);
c002541f:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c0025423:	89 04 24             	mov    %eax,(%esp)
c0025426:	b9 00 00 00 00       	mov    $0x0,%ecx
c002542b:	ba 00 00 00 00       	mov    $0x0,%edx
c0025430:	89 d8                	mov    %ebx,%eax
c0025432:	e8 2b fc ff ff       	call   c0025062 <read_partition_table>
  if (part_nr == 0)
c0025437:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c002543c:	75 18                	jne    c0025456 <partition_scan+0x47>
    printf ("%s: Device contains no partitions\n", block_name (block));
c002543e:	89 1c 24             	mov    %ebx,(%esp)
c0025441:	e8 7a fa ff ff       	call   c0024ec0 <block_name>
c0025446:	89 44 24 04          	mov    %eax,0x4(%esp)
c002544a:	c7 04 24 c4 f5 02 c0 	movl   $0xc002f5c4,(%esp)
c0025451:	e8 08 17 00 00       	call   c0026b5e <printf>
}
c0025456:	83 c4 28             	add    $0x28,%esp
c0025459:	5b                   	pop    %ebx
c002545a:	c3                   	ret    
c002545b:	90                   	nop
c002545c:	90                   	nop
c002545d:	90                   	nop
c002545e:	90                   	nop
c002545f:	90                   	nop

c0025460 <descramble_ata_string>:
/* Translates STRING, which consists of SIZE bytes in a funky
   format, into a null-terminated string in-place.  Drops
   trailing whitespace and null bytes.  Returns STRING.  */
static char *
descramble_ata_string (char *string, int size) 
{
c0025460:	57                   	push   %edi
c0025461:	56                   	push   %esi
c0025462:	53                   	push   %ebx
c0025463:	89 d7                	mov    %edx,%edi
  int i;

  /* Swap all pairs of bytes. */
  for (i = 0; i + 1 < size; i += 2)
c0025465:	83 fa 01             	cmp    $0x1,%edx
c0025468:	7e 1f                	jle    c0025489 <descramble_ata_string+0x29>
c002546a:	89 c1                	mov    %eax,%ecx
c002546c:	8d 5a fe             	lea    -0x2(%edx),%ebx
c002546f:	83 e3 fe             	and    $0xfffffffe,%ebx
c0025472:	8d 74 18 02          	lea    0x2(%eax,%ebx,1),%esi
    {
      char tmp = string[i];
c0025476:	0f b6 19             	movzbl (%ecx),%ebx
      string[i] = string[i + 1];
c0025479:	0f b6 51 01          	movzbl 0x1(%ecx),%edx
c002547d:	88 11                	mov    %dl,(%ecx)
      string[i + 1] = tmp;
c002547f:	88 59 01             	mov    %bl,0x1(%ecx)
c0025482:	83 c1 02             	add    $0x2,%ecx
  for (i = 0; i + 1 < size; i += 2)
c0025485:	39 f1                	cmp    %esi,%ecx
c0025487:	75 ed                	jne    c0025476 <descramble_ata_string+0x16>
    }

  /* Find the last non-white, non-null character. */
  for (size--; size > 0; size--)
c0025489:	8d 57 ff             	lea    -0x1(%edi),%edx
c002548c:	85 d2                	test   %edx,%edx
c002548e:	7e 24                	jle    c00254b4 <descramble_ata_string+0x54>
    {
      int c = string[size - 1];
c0025490:	0f b6 4c 10 ff       	movzbl -0x1(%eax,%edx,1),%ecx
      if (c != '\0' && !isspace (c))
c0025495:	f6 c1 df             	test   $0xdf,%cl
c0025498:	74 15                	je     c00254af <descramble_ata_string+0x4f>
  return (c == ' ' || c == '\f' || c == '\n'
c002549a:	8d 59 f4             	lea    -0xc(%ecx),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c002549d:	80 fb 01             	cmp    $0x1,%bl
c00254a0:	76 0d                	jbe    c00254af <descramble_ata_string+0x4f>
c00254a2:	80 f9 0a             	cmp    $0xa,%cl
c00254a5:	74 08                	je     c00254af <descramble_ata_string+0x4f>
c00254a7:	83 e1 fd             	and    $0xfffffffd,%ecx
c00254aa:	80 f9 09             	cmp    $0x9,%cl
c00254ad:	75 05                	jne    c00254b4 <descramble_ata_string+0x54>
  for (size--; size > 0; size--)
c00254af:	83 ea 01             	sub    $0x1,%edx
c00254b2:	75 dc                	jne    c0025490 <descramble_ata_string+0x30>
        break; 
    }
  string[size] = '\0';
c00254b4:	c6 04 10 00          	movb   $0x0,(%eax,%edx,1)

  return string;
}
c00254b8:	5b                   	pop    %ebx
c00254b9:	5e                   	pop    %esi
c00254ba:	5f                   	pop    %edi
c00254bb:	c3                   	ret    

c00254bc <interrupt_handler>:
}

/* ATA interrupt handler. */
static void
interrupt_handler (struct intr_frame *f) 
{
c00254bc:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c;

  for (c = channels; c < channels + CHANNEL_CNT; c++)
    if (f->vec_no == c->irq)
c00254bf:	8b 44 24 20          	mov    0x20(%esp),%eax
c00254c3:	8b 40 30             	mov    0x30(%eax),%eax
c00254c6:	0f b6 15 4a 78 03 c0 	movzbl 0xc003784a,%edx
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254cd:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
    if (f->vec_no == c->irq)
c00254d2:	39 d0                	cmp    %edx,%eax
c00254d4:	75 3e                	jne    c0025514 <interrupt_handler+0x58>
c00254d6:	eb 0a                	jmp    c00254e2 <interrupt_handler+0x26>
c00254d8:	0f b6 51 0a          	movzbl 0xa(%ecx),%edx
c00254dc:	39 c2                	cmp    %eax,%edx
c00254de:	75 34                	jne    c0025514 <interrupt_handler+0x58>
c00254e0:	eb 05                	jmp    c00254e7 <interrupt_handler+0x2b>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254e2:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
      {
        if (c->expecting_interrupt) 
c00254e7:	80 79 30 00          	cmpb   $0x0,0x30(%ecx)
c00254eb:	74 15                	je     c0025502 <interrupt_handler+0x46>
          {
            inb (reg_status (c));               /* Acknowledge interrupt. */
c00254ed:	0f b7 41 08          	movzwl 0x8(%ecx),%eax
c00254f1:	8d 50 07             	lea    0x7(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00254f4:	ec                   	in     (%dx),%al
            sema_up (&c->completion_wait);      /* Wake up waiter. */
c00254f5:	83 c1 34             	add    $0x34,%ecx
c00254f8:	89 0c 24             	mov    %ecx,(%esp)
c00254fb:	e8 97 d7 ff ff       	call   c0022c97 <sema_up>
c0025500:	eb 41                	jmp    c0025543 <interrupt_handler+0x87>
          }
        else
          printf ("%s: unexpected interrupt\n", c->name);
c0025502:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0025506:	c7 04 24 e7 f5 02 c0 	movl   $0xc002f5e7,(%esp)
c002550d:	e8 4c 16 00 00       	call   c0026b5e <printf>
c0025512:	eb 2f                	jmp    c0025543 <interrupt_handler+0x87>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c0025514:	83 c1 70             	add    $0x70,%ecx
c0025517:	81 f9 20 79 03 c0    	cmp    $0xc0037920,%ecx
c002551d:	72 b9                	jb     c00254d8 <interrupt_handler+0x1c>
        return;
      }

  NOT_REACHED ();
c002551f:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0025526:	c0 
c0025527:	c7 44 24 08 cc d9 02 	movl   $0xc002d9cc,0x8(%esp)
c002552e:	c0 
c002552f:	c7 44 24 04 0c 02 00 	movl   $0x20c,0x4(%esp)
c0025536:	00 
c0025537:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c002553e:	e8 70 34 00 00       	call   c00289b3 <debug_panic>
}
c0025543:	83 c4 1c             	add    $0x1c,%esp
c0025546:	c3                   	ret    

c0025547 <wait_until_idle>:
{
c0025547:	56                   	push   %esi
c0025548:	53                   	push   %ebx
c0025549:	83 ec 14             	sub    $0x14,%esp
c002554c:	89 c6                	mov    %eax,%esi
      if ((inb (reg_status (d->channel)) & (STA_BSY | STA_DRQ)) == 0)
c002554e:	8b 40 08             	mov    0x8(%eax),%eax
c0025551:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025555:	83 c2 07             	add    $0x7,%edx
c0025558:	ec                   	in     (%dx),%al
c0025559:	a8 88                	test   $0x88,%al
c002555b:	75 3c                	jne    c0025599 <wait_until_idle+0x52>
c002555d:	eb 55                	jmp    c00255b4 <wait_until_idle+0x6d>
c002555f:	8b 46 08             	mov    0x8(%esi),%eax
c0025562:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025566:	83 c2 07             	add    $0x7,%edx
c0025569:	ec                   	in     (%dx),%al
c002556a:	a8 88                	test   $0x88,%al
c002556c:	74 46                	je     c00255b4 <wait_until_idle+0x6d>
      timer_usleep (10);
c002556e:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025575:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002557c:	00 
c002557d:	e8 5e ee ff ff       	call   c00243e0 <timer_usleep>
  for (i = 0; i < 1000; i++) 
c0025582:	83 eb 01             	sub    $0x1,%ebx
c0025585:	75 d8                	jne    c002555f <wait_until_idle+0x18>
  printf ("%s: idle timeout\n", d->name);
c0025587:	89 74 24 04          	mov    %esi,0x4(%esp)
c002558b:	c7 04 24 15 f6 02 c0 	movl   $0xc002f615,(%esp)
c0025592:	e8 c7 15 00 00       	call   c0026b5e <printf>
c0025597:	eb 1b                	jmp    c00255b4 <wait_until_idle+0x6d>
      timer_usleep (10);
c0025599:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00255a0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00255a7:	00 
c00255a8:	e8 33 ee ff ff       	call   c00243e0 <timer_usleep>
c00255ad:	bb e7 03 00 00       	mov    $0x3e7,%ebx
c00255b2:	eb ab                	jmp    c002555f <wait_until_idle+0x18>
}
c00255b4:	83 c4 14             	add    $0x14,%esp
c00255b7:	5b                   	pop    %ebx
c00255b8:	5e                   	pop    %esi
c00255b9:	c3                   	ret    

c00255ba <select_device>:
{
c00255ba:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c = d->channel;
c00255bd:	8b 50 08             	mov    0x8(%eax),%edx
  if (d->dev_no == 1)
c00255c0:	83 78 0c 01          	cmpl   $0x1,0xc(%eax)
  uint8_t dev = DEV_MBS;
c00255c4:	b8 a0 ff ff ff       	mov    $0xffffffa0,%eax
c00255c9:	b9 b0 ff ff ff       	mov    $0xffffffb0,%ecx
c00255ce:	0f 44 c1             	cmove  %ecx,%eax
  outb (reg_device (c), dev);
c00255d1:	0f b7 4a 08          	movzwl 0x8(%edx),%ecx
c00255d5:	8d 51 06             	lea    0x6(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00255d8:	ee                   	out    %al,(%dx)
  inb (reg_alt_status (c));
c00255d9:	8d 91 06 02 00 00    	lea    0x206(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00255df:	ec                   	in     (%dx),%al
  timer_nsleep (400);
c00255e0:	c7 04 24 90 01 00 00 	movl   $0x190,(%esp)
c00255e7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00255ee:	00 
c00255ef:	e8 05 ee ff ff       	call   c00243f9 <timer_nsleep>
}
c00255f4:	83 c4 1c             	add    $0x1c,%esp
c00255f7:	c3                   	ret    

c00255f8 <check_device_type>:
{
c00255f8:	55                   	push   %ebp
c00255f9:	57                   	push   %edi
c00255fa:	56                   	push   %esi
c00255fb:	53                   	push   %ebx
c00255fc:	83 ec 0c             	sub    $0xc,%esp
c00255ff:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c0025601:	8b 70 08             	mov    0x8(%eax),%esi
  select_device (d);
c0025604:	e8 b1 ff ff ff       	call   c00255ba <select_device>
  error = inb (reg_error (c));
c0025609:	0f b7 4e 08          	movzwl 0x8(%esi),%ecx
c002560d:	8d 51 01             	lea    0x1(%ecx),%edx
c0025610:	ec                   	in     (%dx),%al
c0025611:	89 c6                	mov    %eax,%esi
  lbam = inb (reg_lbam (c));
c0025613:	8d 51 04             	lea    0x4(%ecx),%edx
c0025616:	ec                   	in     (%dx),%al
c0025617:	89 c7                	mov    %eax,%edi
  lbah = inb (reg_lbah (c));
c0025619:	8d 51 05             	lea    0x5(%ecx),%edx
c002561c:	ec                   	in     (%dx),%al
c002561d:	89 c5                	mov    %eax,%ebp
  status = inb (reg_status (c));
c002561f:	8d 51 07             	lea    0x7(%ecx),%edx
c0025622:	ec                   	in     (%dx),%al
  if ((error != 1 && (error != 0x81 || d->dev_no == 1))
c0025623:	89 f1                	mov    %esi,%ecx
c0025625:	80 f9 01             	cmp    $0x1,%cl
c0025628:	74 0b                	je     c0025635 <check_device_type+0x3d>
c002562a:	80 f9 81             	cmp    $0x81,%cl
c002562d:	75 0e                	jne    c002563d <check_device_type+0x45>
c002562f:	83 7b 0c 01          	cmpl   $0x1,0xc(%ebx)
c0025633:	74 08                	je     c002563d <check_device_type+0x45>
      || (status & STA_DRDY) == 0
c0025635:	a8 40                	test   $0x40,%al
c0025637:	74 04                	je     c002563d <check_device_type+0x45>
      || (status & STA_BSY) != 0)
c0025639:	84 c0                	test   %al,%al
c002563b:	79 0d                	jns    c002564a <check_device_type+0x52>
      d->is_ata = false;
c002563d:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return error != 0x81;      
c0025641:	89 f0                	mov    %esi,%eax
c0025643:	3c 81                	cmp    $0x81,%al
c0025645:	0f 95 c0             	setne  %al
c0025648:	eb 2b                	jmp    c0025675 <check_device_type+0x7d>
      d->is_ata = (lbam == 0 && lbah == 0) || (lbam == 0x3c && lbah == 0xc3);
c002564a:	b8 01 00 00 00       	mov    $0x1,%eax
c002564f:	89 ea                	mov    %ebp,%edx
c0025651:	89 f9                	mov    %edi,%ecx
c0025653:	08 ca                	or     %cl,%dl
c0025655:	74 12                	je     c0025669 <check_device_type+0x71>
c0025657:	89 e8                	mov    %ebp,%eax
c0025659:	3c c3                	cmp    $0xc3,%al
c002565b:	0f 94 c0             	sete   %al
c002565e:	80 f9 3c             	cmp    $0x3c,%cl
c0025661:	0f 94 c2             	sete   %dl
c0025664:	0f b6 d2             	movzbl %dl,%edx
c0025667:	21 d0                	and    %edx,%eax
c0025669:	88 43 10             	mov    %al,0x10(%ebx)
c002566c:	80 63 10 01          	andb   $0x1,0x10(%ebx)
      return true; 
c0025670:	b8 01 00 00 00       	mov    $0x1,%eax
}
c0025675:	83 c4 0c             	add    $0xc,%esp
c0025678:	5b                   	pop    %ebx
c0025679:	5e                   	pop    %esi
c002567a:	5f                   	pop    %edi
c002567b:	5d                   	pop    %ebp
c002567c:	c3                   	ret    

c002567d <select_sector>:
{
c002567d:	57                   	push   %edi
c002567e:	56                   	push   %esi
c002567f:	53                   	push   %ebx
c0025680:	83 ec 20             	sub    $0x20,%esp
c0025683:	89 c6                	mov    %eax,%esi
c0025685:	89 d3                	mov    %edx,%ebx
  struct channel *c = d->channel;
c0025687:	8b 78 08             	mov    0x8(%eax),%edi
  ASSERT (sec_no < (1UL << 28));
c002568a:	81 fa ff ff ff 0f    	cmp    $0xfffffff,%edx
c0025690:	76 2c                	jbe    c00256be <select_sector+0x41>
c0025692:	c7 44 24 10 27 f6 02 	movl   $0xc002f627,0x10(%esp)
c0025699:	c0 
c002569a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00256a1:	c0 
c00256a2:	c7 44 24 08 a0 d9 02 	movl   $0xc002d9a0,0x8(%esp)
c00256a9:	c0 
c00256aa:	c7 44 24 04 89 01 00 	movl   $0x189,0x4(%esp)
c00256b1:	00 
c00256b2:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c00256b9:	e8 f5 32 00 00       	call   c00289b3 <debug_panic>
  wait_until_idle (d);
c00256be:	e8 84 fe ff ff       	call   c0025547 <wait_until_idle>
  select_device (d);
c00256c3:	89 f0                	mov    %esi,%eax
c00256c5:	e8 f0 fe ff ff       	call   c00255ba <select_device>
  wait_until_idle (d);
c00256ca:	89 f0                	mov    %esi,%eax
c00256cc:	e8 76 fe ff ff       	call   c0025547 <wait_until_idle>
  outb (reg_nsect (c), 1);
c00256d1:	0f b7 4f 08          	movzwl 0x8(%edi),%ecx
c00256d5:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00256d8:	b8 01 00 00 00       	mov    $0x1,%eax
c00256dd:	ee                   	out    %al,(%dx)
  outb (reg_lbal (c), sec_no);
c00256de:	8d 51 03             	lea    0x3(%ecx),%edx
c00256e1:	89 d8                	mov    %ebx,%eax
c00256e3:	ee                   	out    %al,(%dx)
c00256e4:	0f b6 c7             	movzbl %bh,%eax
  outb (reg_lbam (c), sec_no >> 8);
c00256e7:	8d 51 04             	lea    0x4(%ecx),%edx
c00256ea:	ee                   	out    %al,(%dx)
  outb (reg_lbah (c), (sec_no >> 16));
c00256eb:	89 d8                	mov    %ebx,%eax
c00256ed:	c1 e8 10             	shr    $0x10,%eax
c00256f0:	8d 51 05             	lea    0x5(%ecx),%edx
c00256f3:	ee                   	out    %al,(%dx)
  outb (reg_device (c),
c00256f4:	83 7e 0c 01          	cmpl   $0x1,0xc(%esi)
c00256f8:	b8 f0 ff ff ff       	mov    $0xfffffff0,%eax
c00256fd:	ba e0 ff ff ff       	mov    $0xffffffe0,%edx
c0025702:	0f 45 c2             	cmovne %edx,%eax
        DEV_MBS | DEV_LBA | (d->dev_no == 1 ? DEV_DEV : 0) | (sec_no >> 24));
c0025705:	c1 eb 18             	shr    $0x18,%ebx
  outb (reg_device (c),
c0025708:	09 d8                	or     %ebx,%eax
c002570a:	8d 51 06             	lea    0x6(%ecx),%edx
c002570d:	ee                   	out    %al,(%dx)
}
c002570e:	83 c4 20             	add    $0x20,%esp
c0025711:	5b                   	pop    %ebx
c0025712:	5e                   	pop    %esi
c0025713:	5f                   	pop    %edi
c0025714:	c3                   	ret    

c0025715 <wait_while_busy>:
{
c0025715:	57                   	push   %edi
c0025716:	56                   	push   %esi
c0025717:	53                   	push   %ebx
c0025718:	83 ec 10             	sub    $0x10,%esp
c002571b:	89 c7                	mov    %eax,%edi
  struct channel *c = d->channel;
c002571d:	8b 70 08             	mov    0x8(%eax),%esi
  for (i = 0; i < 3000; i++)
c0025720:	bb 00 00 00 00       	mov    $0x0,%ebx
c0025725:	eb 18                	jmp    c002573f <wait_while_busy+0x2a>
      if (i == 700)
c0025727:	81 fb bc 02 00 00    	cmp    $0x2bc,%ebx
c002572d:	75 10                	jne    c002573f <wait_while_busy+0x2a>
        printf ("%s: busy, waiting...", d->name);
c002572f:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0025733:	c7 04 24 3c f6 02 c0 	movl   $0xc002f63c,(%esp)
c002573a:	e8 1f 14 00 00       	call   c0026b5e <printf>
      if (!(inb (reg_alt_status (c)) & STA_BSY)) 
c002573f:	0f b7 46 08          	movzwl 0x8(%esi),%eax
c0025743:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025749:	ec                   	in     (%dx),%al
c002574a:	84 c0                	test   %al,%al
c002574c:	78 26                	js     c0025774 <wait_while_busy+0x5f>
          if (i >= 700)
c002574e:	81 fb bb 02 00 00    	cmp    $0x2bb,%ebx
c0025754:	7e 0c                	jle    c0025762 <wait_while_busy+0x4d>
            printf ("ok\n");
c0025756:	c7 04 24 51 f6 02 c0 	movl   $0xc002f651,(%esp)
c002575d:	e8 79 4f 00 00       	call   c002a6db <puts>
          return (inb (reg_alt_status (c)) & STA_DRQ) != 0;
c0025762:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c0025766:	66 81 c2 06 02       	add    $0x206,%dx
c002576b:	ec                   	in     (%dx),%al
c002576c:	c0 e8 03             	shr    $0x3,%al
c002576f:	83 e0 01             	and    $0x1,%eax
c0025772:	eb 30                	jmp    c00257a4 <wait_while_busy+0x8f>
      timer_msleep (10);
c0025774:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002577b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025782:	00 
c0025783:	e8 3f ec ff ff       	call   c00243c7 <timer_msleep>
  for (i = 0; i < 3000; i++)
c0025788:	83 c3 01             	add    $0x1,%ebx
c002578b:	81 fb b8 0b 00 00    	cmp    $0xbb8,%ebx
c0025791:	75 94                	jne    c0025727 <wait_while_busy+0x12>
  printf ("failed\n");
c0025793:	c7 04 24 6c ff 02 c0 	movl   $0xc002ff6c,(%esp)
c002579a:	e8 3c 4f 00 00       	call   c002a6db <puts>
  return false;
c002579f:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00257a4:	83 c4 10             	add    $0x10,%esp
c00257a7:	5b                   	pop    %ebx
c00257a8:	5e                   	pop    %esi
c00257a9:	5f                   	pop    %edi
c00257aa:	c3                   	ret    

c00257ab <issue_pio_command>:
{
c00257ab:	56                   	push   %esi
c00257ac:	53                   	push   %ebx
c00257ad:	83 ec 24             	sub    $0x24,%esp
c00257b0:	89 c3                	mov    %eax,%ebx
c00257b2:	89 d6                	mov    %edx,%esi
  ASSERT (intr_get_level () == INTR_ON);
c00257b4:	e8 0b c2 ff ff       	call   c00219c4 <intr_get_level>
c00257b9:	83 f8 01             	cmp    $0x1,%eax
c00257bc:	74 2c                	je     c00257ea <issue_pio_command+0x3f>
c00257be:	c7 44 24 10 5e ed 02 	movl   $0xc002ed5e,0x10(%esp)
c00257c5:	c0 
c00257c6:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00257cd:	c0 
c00257ce:	c7 44 24 08 85 d9 02 	movl   $0xc002d985,0x8(%esp)
c00257d5:	c0 
c00257d6:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c00257dd:	00 
c00257de:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c00257e5:	e8 c9 31 00 00       	call   c00289b3 <debug_panic>
  c->expecting_interrupt = true;
c00257ea:	c6 43 30 01          	movb   $0x1,0x30(%ebx)
  outb (reg_command (c), command);
c00257ee:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c00257f2:	83 c2 07             	add    $0x7,%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00257f5:	89 f0                	mov    %esi,%eax
c00257f7:	ee                   	out    %al,(%dx)
}
c00257f8:	83 c4 24             	add    $0x24,%esp
c00257fb:	5b                   	pop    %ebx
c00257fc:	5e                   	pop    %esi
c00257fd:	c3                   	ret    

c00257fe <ide_write>:
{
c00257fe:	57                   	push   %edi
c00257ff:	56                   	push   %esi
c0025800:	53                   	push   %ebx
c0025801:	83 ec 20             	sub    $0x20,%esp
c0025804:	8b 74 24 30          	mov    0x30(%esp),%esi
  struct channel *c = d->channel;
c0025808:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c002580b:	8d 7b 0c             	lea    0xc(%ebx),%edi
c002580e:	89 3c 24             	mov    %edi,(%esp)
c0025811:	e8 94 d6 ff ff       	call   c0022eaa <lock_acquire>
  select_sector (d, sec_no);
c0025816:	8b 54 24 34          	mov    0x34(%esp),%edx
c002581a:	89 f0                	mov    %esi,%eax
c002581c:	e8 5c fe ff ff       	call   c002567d <select_sector>
  issue_pio_command (c, CMD_WRITE_SECTOR_RETRY);
c0025821:	ba 30 00 00 00       	mov    $0x30,%edx
c0025826:	89 d8                	mov    %ebx,%eax
c0025828:	e8 7e ff ff ff       	call   c00257ab <issue_pio_command>
  if (!wait_while_busy (d))
c002582d:	89 f0                	mov    %esi,%eax
c002582f:	e8 e1 fe ff ff       	call   c0025715 <wait_while_busy>
c0025834:	84 c0                	test   %al,%al
c0025836:	75 30                	jne    c0025868 <ide_write+0x6a>
    PANIC ("%s: disk write failed, sector=%"PRDSNu, d->name, sec_no);
c0025838:	8b 44 24 34          	mov    0x34(%esp),%eax
c002583c:	89 44 24 14          	mov    %eax,0x14(%esp)
c0025840:	89 74 24 10          	mov    %esi,0x10(%esp)
c0025844:	c7 44 24 0c a0 f6 02 	movl   $0xc002f6a0,0xc(%esp)
c002584b:	c0 
c002584c:	c7 44 24 08 ae d9 02 	movl   $0xc002d9ae,0x8(%esp)
c0025853:	c0 
c0025854:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
c002585b:	00 
c002585c:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c0025863:	e8 4b 31 00 00       	call   c00289b3 <debug_panic>
   CNT-halfword buffer starting at ADDR. */
static inline void
outsw (uint16_t port, const void *addr, size_t cnt)
{
  /* See [IA32-v2b] "OUTS". */
  asm volatile ("rep outsw" : "+S" (addr), "+c" (cnt) : "d" (port));
c0025868:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c002586c:	8b 74 24 38          	mov    0x38(%esp),%esi
c0025870:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025875:	66 f3 6f             	rep outsw %ds:(%esi),(%dx)
  sema_down (&c->completion_wait);
c0025878:	83 c3 34             	add    $0x34,%ebx
c002587b:	89 1c 24             	mov    %ebx,(%esp)
c002587e:	e8 ff d2 ff ff       	call   c0022b82 <sema_down>
  lock_release (&c->lock);
c0025883:	89 3c 24             	mov    %edi,(%esp)
c0025886:	e8 e9 d7 ff ff       	call   c0023074 <lock_release>
}
c002588b:	83 c4 20             	add    $0x20,%esp
c002588e:	5b                   	pop    %ebx
c002588f:	5e                   	pop    %esi
c0025890:	5f                   	pop    %edi
c0025891:	c3                   	ret    

c0025892 <identify_ata_device>:
{
c0025892:	57                   	push   %edi
c0025893:	56                   	push   %esi
c0025894:	53                   	push   %ebx
c0025895:	81 ec a0 02 00 00    	sub    $0x2a0,%esp
c002589b:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c002589d:	8b 70 08             	mov    0x8(%eax),%esi
  ASSERT (d->is_ata);
c00258a0:	80 78 10 00          	cmpb   $0x0,0x10(%eax)
c00258a4:	75 2c                	jne    c00258d2 <identify_ata_device+0x40>
c00258a6:	c7 44 24 10 54 f6 02 	movl   $0xc002f654,0x10(%esp)
c00258ad:	c0 
c00258ae:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00258b5:	c0 
c00258b6:	c7 44 24 08 b8 d9 02 	movl   $0xc002d9b8,0x8(%esp)
c00258bd:	c0 
c00258be:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
c00258c5:	00 
c00258c6:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c00258cd:	e8 e1 30 00 00       	call   c00289b3 <debug_panic>
  wait_until_idle (d);
c00258d2:	e8 70 fc ff ff       	call   c0025547 <wait_until_idle>
  select_device (d);
c00258d7:	89 d8                	mov    %ebx,%eax
c00258d9:	e8 dc fc ff ff       	call   c00255ba <select_device>
  wait_until_idle (d);
c00258de:	89 d8                	mov    %ebx,%eax
c00258e0:	e8 62 fc ff ff       	call   c0025547 <wait_until_idle>
  issue_pio_command (c, CMD_IDENTIFY_DEVICE);
c00258e5:	ba ec 00 00 00       	mov    $0xec,%edx
c00258ea:	89 f0                	mov    %esi,%eax
c00258ec:	e8 ba fe ff ff       	call   c00257ab <issue_pio_command>
  sema_down (&c->completion_wait);
c00258f1:	8d 46 34             	lea    0x34(%esi),%eax
c00258f4:	89 04 24             	mov    %eax,(%esp)
c00258f7:	e8 86 d2 ff ff       	call   c0022b82 <sema_down>
  if (!wait_while_busy (d))
c00258fc:	89 d8                	mov    %ebx,%eax
c00258fe:	e8 12 fe ff ff       	call   c0025715 <wait_while_busy>
c0025903:	84 c0                	test   %al,%al
c0025905:	75 09                	jne    c0025910 <identify_ata_device+0x7e>
      d->is_ata = false;
c0025907:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c002590b:	e9 cf 00 00 00       	jmp    c00259df <identify_ata_device+0x14d>
  asm volatile ("rep insw" : "+D" (addr), "+c" (cnt) : "d" (port) : "memory");
c0025910:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c0025914:	8d bc 24 a0 00 00 00 	lea    0xa0(%esp),%edi
c002591b:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025920:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  capacity = *(uint32_t *) &id[60 * 2];
c0025923:	8b b4 24 18 01 00 00 	mov    0x118(%esp),%esi
  model = descramble_ata_string (&id[10 * 2], 20);
c002592a:	ba 14 00 00 00       	mov    $0x14,%edx
c002592f:	8d 84 24 b4 00 00 00 	lea    0xb4(%esp),%eax
c0025936:	e8 25 fb ff ff       	call   c0025460 <descramble_ata_string>
c002593b:	89 c7                	mov    %eax,%edi
  serial = descramble_ata_string (&id[27 * 2], 40);
c002593d:	ba 28 00 00 00       	mov    $0x28,%edx
c0025942:	8d 84 24 d6 00 00 00 	lea    0xd6(%esp),%eax
c0025949:	e8 12 fb ff ff       	call   c0025460 <descramble_ata_string>
  snprintf (extra_info, sizeof extra_info,
c002594e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025952:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025956:	c7 44 24 08 5e f6 02 	movl   $0xc002f65e,0x8(%esp)
c002595d:	c0 
c002595e:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025965:	00 
c0025966:	8d 44 24 20          	lea    0x20(%esp),%eax
c002596a:	89 04 24             	mov    %eax,(%esp)
c002596d:	e8 ed 18 00 00       	call   c002725f <snprintf>
  if (capacity >= 1024 * 1024 * 1024 / BLOCK_SECTOR_SIZE)
c0025972:	81 fe ff ff 1f 00    	cmp    $0x1fffff,%esi
c0025978:	76 35                	jbe    c00259af <identify_ata_device+0x11d>
      printf ("%s: ignoring ", d->name);
c002597a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002597e:	c7 04 24 76 f6 02 c0 	movl   $0xc002f676,(%esp)
c0025985:	e8 d4 11 00 00       	call   c0026b5e <printf>
      print_human_readable_size (capacity * 512);
c002598a:	c1 e6 09             	shl    $0x9,%esi
c002598d:	89 34 24             	mov    %esi,(%esp)
c0025990:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025997:	00 
c0025998:	e8 8c 1a 00 00       	call   c0027429 <print_human_readable_size>
      printf ("disk for safety\n");
c002599d:	c7 04 24 84 f6 02 c0 	movl   $0xc002f684,(%esp)
c00259a4:	e8 32 4d 00 00       	call   c002a6db <puts>
      d->is_ata = false;
c00259a9:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c00259ad:	eb 30                	jmp    c00259df <identify_ata_device+0x14d>
  block = block_register (d->name, BLOCK_RAW, extra_info, capacity,
c00259af:	89 5c 24 14          	mov    %ebx,0x14(%esp)
c00259b3:	c7 44 24 10 74 5a 03 	movl   $0xc0035a74,0x10(%esp)
c00259ba:	c0 
c00259bb:	89 74 24 0c          	mov    %esi,0xc(%esp)
c00259bf:	8d 44 24 20          	lea    0x20(%esp),%eax
c00259c3:	89 44 24 08          	mov    %eax,0x8(%esp)
c00259c7:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c00259ce:	00 
c00259cf:	89 1c 24             	mov    %ebx,(%esp)
c00259d2:	e8 5a f5 ff ff       	call   c0024f31 <block_register>
  partition_scan (block);
c00259d7:	89 04 24             	mov    %eax,(%esp)
c00259da:	e8 30 fa ff ff       	call   c002540f <partition_scan>
}
c00259df:	81 c4 a0 02 00 00    	add    $0x2a0,%esp
c00259e5:	5b                   	pop    %ebx
c00259e6:	5e                   	pop    %esi
c00259e7:	5f                   	pop    %edi
c00259e8:	c3                   	ret    

c00259e9 <ide_read>:
{
c00259e9:	55                   	push   %ebp
c00259ea:	57                   	push   %edi
c00259eb:	56                   	push   %esi
c00259ec:	53                   	push   %ebx
c00259ed:	83 ec 2c             	sub    $0x2c,%esp
c00259f0:	8b 74 24 40          	mov    0x40(%esp),%esi
  struct channel *c = d->channel;
c00259f4:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00259f7:	8d 6b 0c             	lea    0xc(%ebx),%ebp
c00259fa:	89 2c 24             	mov    %ebp,(%esp)
c00259fd:	e8 a8 d4 ff ff       	call   c0022eaa <lock_acquire>
  select_sector (d, sec_no);
c0025a02:	8b 54 24 44          	mov    0x44(%esp),%edx
c0025a06:	89 f0                	mov    %esi,%eax
c0025a08:	e8 70 fc ff ff       	call   c002567d <select_sector>
  issue_pio_command (c, CMD_READ_SECTOR_RETRY);
c0025a0d:	ba 20 00 00 00       	mov    $0x20,%edx
c0025a12:	89 d8                	mov    %ebx,%eax
c0025a14:	e8 92 fd ff ff       	call   c00257ab <issue_pio_command>
  sema_down (&c->completion_wait);
c0025a19:	8d 43 34             	lea    0x34(%ebx),%eax
c0025a1c:	89 04 24             	mov    %eax,(%esp)
c0025a1f:	e8 5e d1 ff ff       	call   c0022b82 <sema_down>
  if (!wait_while_busy (d))
c0025a24:	89 f0                	mov    %esi,%eax
c0025a26:	e8 ea fc ff ff       	call   c0025715 <wait_while_busy>
c0025a2b:	84 c0                	test   %al,%al
c0025a2d:	75 30                	jne    c0025a5f <ide_read+0x76>
    PANIC ("%s: disk read failed, sector=%"PRDSNu, d->name, sec_no);
c0025a2f:	8b 44 24 44          	mov    0x44(%esp),%eax
c0025a33:	89 44 24 14          	mov    %eax,0x14(%esp)
c0025a37:	89 74 24 10          	mov    %esi,0x10(%esp)
c0025a3b:	c7 44 24 0c c4 f6 02 	movl   $0xc002f6c4,0xc(%esp)
c0025a42:	c0 
c0025a43:	c7 44 24 08 97 d9 02 	movl   $0xc002d997,0x8(%esp)
c0025a4a:	c0 
c0025a4b:	c7 44 24 04 62 01 00 	movl   $0x162,0x4(%esp)
c0025a52:	00 
c0025a53:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c0025a5a:	e8 54 2f 00 00       	call   c00289b3 <debug_panic>
c0025a5f:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c0025a63:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0025a67:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025a6c:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  lock_release (&c->lock);
c0025a6f:	89 2c 24             	mov    %ebp,(%esp)
c0025a72:	e8 fd d5 ff ff       	call   c0023074 <lock_release>
}
c0025a77:	83 c4 2c             	add    $0x2c,%esp
c0025a7a:	5b                   	pop    %ebx
c0025a7b:	5e                   	pop    %esi
c0025a7c:	5f                   	pop    %edi
c0025a7d:	5d                   	pop    %ebp
c0025a7e:	c3                   	ret    

c0025a7f <ide_init>:
{
c0025a7f:	55                   	push   %ebp
c0025a80:	57                   	push   %edi
c0025a81:	56                   	push   %esi
c0025a82:	53                   	push   %ebx
c0025a83:	83 ec 4c             	sub    $0x4c,%esp
c0025a86:	c7 44 24 1c 9c 78 03 	movl   $0xc003789c,0x1c(%esp)
c0025a8d:	c0 
c0025a8e:	bd 88 78 03 c0       	mov    $0xc0037888,%ebp
c0025a93:	c7 44 24 20 61 00 00 	movl   $0x61,0x20(%esp)
c0025a9a:	00 
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025a9b:	bf 00 00 00 00       	mov    $0x0,%edi
c0025aa0:	8d 75 b8             	lea    -0x48(%ebp),%esi
      snprintf (c->name, sizeof c->name, "ide%zu", chan_no);
c0025aa3:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025aa7:	c7 44 24 08 94 f6 02 	movl   $0xc002f694,0x8(%esp)
c0025aae:	c0 
c0025aaf:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025ab6:	00 
c0025ab7:	89 34 24             	mov    %esi,(%esp)
c0025aba:	e8 a0 17 00 00       	call   c002725f <snprintf>
      switch (chan_no) 
c0025abf:	85 ff                	test   %edi,%edi
c0025ac1:	74 07                	je     c0025aca <ide_init+0x4b>
c0025ac3:	83 ff 01             	cmp    $0x1,%edi
c0025ac6:	74 0e                	je     c0025ad6 <ide_init+0x57>
c0025ac8:	eb 18                	jmp    c0025ae2 <ide_init+0x63>
          c->reg_base = 0x1f0;
c0025aca:	66 c7 45 c0 f0 01    	movw   $0x1f0,-0x40(%ebp)
          c->irq = 14 + 0x20;
c0025ad0:	c6 45 c2 2e          	movb   $0x2e,-0x3e(%ebp)
          break;
c0025ad4:	eb 30                	jmp    c0025b06 <ide_init+0x87>
          c->reg_base = 0x170;
c0025ad6:	66 c7 45 c0 70 01    	movw   $0x170,-0x40(%ebp)
          c->irq = 15 + 0x20;
c0025adc:	c6 45 c2 2f          	movb   $0x2f,-0x3e(%ebp)
          break;
c0025ae0:	eb 24                	jmp    c0025b06 <ide_init+0x87>
          NOT_REACHED ();
c0025ae2:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0025ae9:	c0 
c0025aea:	c7 44 24 08 de d9 02 	movl   $0xc002d9de,0x8(%esp)
c0025af1:	c0 
c0025af2:	c7 44 24 04 7c 00 00 	movl   $0x7c,0x4(%esp)
c0025af9:	00 
c0025afa:	c7 04 24 01 f6 02 c0 	movl   $0xc002f601,(%esp)
c0025b01:	e8 ad 2e 00 00       	call   c00289b3 <debug_panic>
c0025b06:	8d 45 c4             	lea    -0x3c(%ebp),%eax
      lock_init (&c->lock);
c0025b09:	89 04 24             	mov    %eax,(%esp)
c0025b0c:	e8 fc d2 ff ff       	call   c0022e0d <lock_init>
c0025b11:	89 eb                	mov    %ebp,%ebx
      c->expecting_interrupt = false;
c0025b13:	c6 45 e8 00          	movb   $0x0,-0x18(%ebp)
      sema_init (&c->completion_wait, 0);
c0025b17:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025b1e:	00 
c0025b1f:	8d 45 ec             	lea    -0x14(%ebp),%eax
c0025b22:	89 04 24             	mov    %eax,(%esp)
c0025b25:	e8 0c d0 ff ff       	call   c0022b36 <sema_init>
          snprintf (d->name, sizeof d->name,
c0025b2a:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025b2e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b32:	c7 44 24 08 9b f6 02 	movl   $0xc002f69b,0x8(%esp)
c0025b39:	c0 
c0025b3a:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b41:	00 
c0025b42:	89 2c 24             	mov    %ebp,(%esp)
c0025b45:	e8 15 17 00 00       	call   c002725f <snprintf>
          d->channel = c;
c0025b4a:	89 75 08             	mov    %esi,0x8(%ebp)
          d->dev_no = dev_no;
c0025b4d:	c7 45 0c 00 00 00 00 	movl   $0x0,0xc(%ebp)
          d->is_ata = false;
c0025b54:	c6 45 10 00          	movb   $0x0,0x10(%ebp)
          snprintf (d->name, sizeof d->name,
c0025b58:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0025b5c:	89 4c 24 24          	mov    %ecx,0x24(%esp)
c0025b60:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025b64:	83 c0 01             	add    $0x1,%eax
c0025b67:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b6b:	c7 44 24 08 9b f6 02 	movl   $0xc002f69b,0x8(%esp)
c0025b72:	c0 
c0025b73:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b7a:	00 
c0025b7b:	89 0c 24             	mov    %ecx,(%esp)
c0025b7e:	e8 dc 16 00 00       	call   c002725f <snprintf>
          d->channel = c;
c0025b83:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0025b87:	89 70 08             	mov    %esi,0x8(%eax)
          d->dev_no = dev_no;
c0025b8a:	c7 40 0c 01 00 00 00 	movl   $0x1,0xc(%eax)
          d->is_ata = false;
c0025b91:	c6 45 24 00          	movb   $0x0,0x24(%ebp)
      intr_register_ext (c->irq, interrupt_handler, c->name);
c0025b95:	89 74 24 08          	mov    %esi,0x8(%esp)
c0025b99:	c7 44 24 04 bc 54 02 	movl   $0xc00254bc,0x4(%esp)
c0025ba0:	c0 
c0025ba1:	0f b6 45 c2          	movzbl -0x3e(%ebp),%eax
c0025ba5:	89 04 24             	mov    %eax,(%esp)
c0025ba8:	e8 06 c0 ff ff       	call   c0021bb3 <intr_register_ext>
c0025bad:	8d 74 24 3e          	lea    0x3e(%esp),%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025bb1:	89 7c 24 28          	mov    %edi,0x28(%esp)
c0025bb5:	89 6c 24 2c          	mov    %ebp,0x2c(%esp)
      select_device (d);
c0025bb9:	89 e8                	mov    %ebp,%eax
c0025bbb:	e8 fa f9 ff ff       	call   c00255ba <select_device>
      outb (reg_nsect (c), 0x55);
c0025bc0:	0f b7 7b c0          	movzwl -0x40(%ebx),%edi
c0025bc4:	8d 4f 02             	lea    0x2(%edi),%ecx
c0025bc7:	b8 55 00 00 00       	mov    $0x55,%eax
c0025bcc:	89 ca                	mov    %ecx,%edx
c0025bce:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0025bcf:	83 c7 03             	add    $0x3,%edi
c0025bd2:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025bd7:	89 fa                	mov    %edi,%edx
c0025bd9:	ee                   	out    %al,(%dx)
c0025bda:	89 ca                	mov    %ecx,%edx
c0025bdc:	ee                   	out    %al,(%dx)
c0025bdd:	b8 55 00 00 00       	mov    $0x55,%eax
c0025be2:	89 fa                	mov    %edi,%edx
c0025be4:	ee                   	out    %al,(%dx)
c0025be5:	89 ca                	mov    %ecx,%edx
c0025be7:	ee                   	out    %al,(%dx)
c0025be8:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025bed:	89 fa                	mov    %edi,%edx
c0025bef:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025bf0:	89 ca                	mov    %ecx,%edx
c0025bf2:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0025bf3:	ba 00 00 00 00       	mov    $0x0,%edx
c0025bf8:	3c 55                	cmp    $0x55,%al
c0025bfa:	75 0b                	jne    c0025c07 <ide_init+0x188>
c0025bfc:	89 fa                	mov    %edi,%edx
c0025bfe:	ec                   	in     (%dx),%al
c0025bff:	3c aa                	cmp    $0xaa,%al
c0025c01:	0f 94 c2             	sete   %dl
c0025c04:	0f b6 d2             	movzbl %dl,%edx
c0025c07:	88 16                	mov    %dl,(%esi)
c0025c09:	80 26 01             	andb   $0x1,(%esi)
c0025c0c:	83 c5 14             	add    $0x14,%ebp
c0025c0f:	83 c6 01             	add    $0x1,%esi
  for (dev_no = 0; dev_no < 2; dev_no++)
c0025c12:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025c16:	39 c6                	cmp    %eax,%esi
c0025c18:	75 9f                	jne    c0025bb9 <ide_init+0x13a>
c0025c1a:	8b 7c 24 28          	mov    0x28(%esp),%edi
c0025c1e:	8b 6c 24 2c          	mov    0x2c(%esp),%ebp
  outb (reg_ctl (c), 0);
c0025c22:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c26:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025c2c:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c31:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c32:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c39:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c40:	00 
c0025c41:	e8 9a e7 ff ff       	call   c00243e0 <timer_usleep>
  outb (reg_ctl (c), CTL_SRST);
c0025c46:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c4a:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c50:	b8 04 00 00 00       	mov    $0x4,%eax
c0025c55:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c56:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c5d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c64:	00 
c0025c65:	e8 76 e7 ff ff       	call   c00243e0 <timer_usleep>
  outb (reg_ctl (c), 0);
c0025c6a:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c6e:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c74:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c79:	ee                   	out    %al,(%dx)
  timer_msleep (150);
c0025c7a:	c7 04 24 96 00 00 00 	movl   $0x96,(%esp)
c0025c81:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c88:	00 
c0025c89:	e8 39 e7 ff ff       	call   c00243c7 <timer_msleep>
  if (present[0]) 
c0025c8e:	80 7c 24 3e 00       	cmpb   $0x0,0x3e(%esp)
c0025c93:	74 0e                	je     c0025ca3 <ide_init+0x224>
      select_device (&c->devices[0]);
c0025c95:	89 d8                	mov    %ebx,%eax
c0025c97:	e8 1e f9 ff ff       	call   c00255ba <select_device>
      wait_while_busy (&c->devices[0]); 
c0025c9c:	89 d8                	mov    %ebx,%eax
c0025c9e:	e8 72 fa ff ff       	call   c0025715 <wait_while_busy>
  if (present[1])
c0025ca3:	80 7c 24 3f 00       	cmpb   $0x0,0x3f(%esp)
c0025ca8:	74 44                	je     c0025cee <ide_init+0x26f>
      select_device (&c->devices[1]);
c0025caa:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cae:	e8 07 f9 ff ff       	call   c00255ba <select_device>
c0025cb3:	be b8 0b 00 00       	mov    $0xbb8,%esi
          if (inb (reg_nsect (c)) == 1 && inb (reg_lbal (c)) == 1)
c0025cb8:	0f b7 4b c0          	movzwl -0x40(%ebx),%ecx
c0025cbc:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025cbf:	ec                   	in     (%dx),%al
c0025cc0:	3c 01                	cmp    $0x1,%al
c0025cc2:	75 08                	jne    c0025ccc <ide_init+0x24d>
c0025cc4:	8d 51 03             	lea    0x3(%ecx),%edx
c0025cc7:	ec                   	in     (%dx),%al
c0025cc8:	3c 01                	cmp    $0x1,%al
c0025cca:	74 19                	je     c0025ce5 <ide_init+0x266>
          timer_msleep (10);
c0025ccc:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025cd3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025cda:	00 
c0025cdb:	e8 e7 e6 ff ff       	call   c00243c7 <timer_msleep>
      for (i = 0; i < 3000; i++) 
c0025ce0:	83 ee 01             	sub    $0x1,%esi
c0025ce3:	75 d3                	jne    c0025cb8 <ide_init+0x239>
      wait_while_busy (&c->devices[1]);
c0025ce5:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025ce9:	e8 27 fa ff ff       	call   c0025715 <wait_while_busy>
      if (check_device_type (&c->devices[0]))
c0025cee:	89 d8                	mov    %ebx,%eax
c0025cf0:	e8 03 f9 ff ff       	call   c00255f8 <check_device_type>
c0025cf5:	84 c0                	test   %al,%al
c0025cf7:	74 2f                	je     c0025d28 <ide_init+0x2a9>
        check_device_type (&c->devices[1]);
c0025cf9:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cfd:	e8 f6 f8 ff ff       	call   c00255f8 <check_device_type>
c0025d02:	eb 24                	jmp    c0025d28 <ide_init+0x2a9>
          identify_ata_device (&c->devices[dev_no]);
c0025d04:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025d08:	e8 85 fb ff ff       	call   c0025892 <identify_ata_device>
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025d0d:	83 c7 01             	add    $0x1,%edi
c0025d10:	83 44 24 1c 70       	addl   $0x70,0x1c(%esp)
c0025d15:	83 c5 70             	add    $0x70,%ebp
c0025d18:	83 44 24 20 02       	addl   $0x2,0x20(%esp)
c0025d1d:	83 ff 02             	cmp    $0x2,%edi
c0025d20:	0f 85 7a fd ff ff    	jne    c0025aa0 <ide_init+0x21>
c0025d26:	eb 15                	jmp    c0025d3d <ide_init+0x2be>
        if (c->devices[dev_no].is_ata)
c0025d28:	80 7b 10 00          	cmpb   $0x0,0x10(%ebx)
c0025d2c:	74 07                	je     c0025d35 <ide_init+0x2b6>
          identify_ata_device (&c->devices[dev_no]);
c0025d2e:	89 d8                	mov    %ebx,%eax
c0025d30:	e8 5d fb ff ff       	call   c0025892 <identify_ata_device>
        if (c->devices[dev_no].is_ata)
c0025d35:	80 7b 24 00          	cmpb   $0x0,0x24(%ebx)
c0025d39:	74 d2                	je     c0025d0d <ide_init+0x28e>
c0025d3b:	eb c7                	jmp    c0025d04 <ide_init+0x285>
}
c0025d3d:	83 c4 4c             	add    $0x4c,%esp
c0025d40:	5b                   	pop    %ebx
c0025d41:	5e                   	pop    %esi
c0025d42:	5f                   	pop    %edi
c0025d43:	5d                   	pop    %ebp
c0025d44:	c3                   	ret    

c0025d45 <input_init>:
static struct intq buffer;

/* Initializes the input buffer. */
void
input_init (void) 
{
c0025d45:	83 ec 1c             	sub    $0x1c,%esp
  intq_init (&buffer);
c0025d48:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d4f:	e8 11 01 00 00       	call   c0025e65 <intq_init>
}
c0025d54:	83 c4 1c             	add    $0x1c,%esp
c0025d57:	c3                   	ret    

c0025d58 <input_putc>:

/* Adds a key to the input buffer.
   Interrupts must be off and the buffer must not be full. */
void
input_putc (uint8_t key) 
{
c0025d58:	53                   	push   %ebx
c0025d59:	83 ec 28             	sub    $0x28,%esp
c0025d5c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025d60:	e8 5f bc ff ff       	call   c00219c4 <intr_get_level>
c0025d65:	85 c0                	test   %eax,%eax
c0025d67:	74 2c                	je     c0025d95 <input_putc+0x3d>
c0025d69:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025d70:	c0 
c0025d71:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025d78:	c0 
c0025d79:	c7 44 24 08 f2 d9 02 	movl   $0xc002d9f2,0x8(%esp)
c0025d80:	c0 
c0025d81:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c0025d88:	00 
c0025d89:	c7 04 24 e4 f6 02 c0 	movl   $0xc002f6e4,(%esp)
c0025d90:	e8 1e 2c 00 00       	call   c00289b3 <debug_panic>
  ASSERT (!intq_full (&buffer));
c0025d95:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d9c:	e8 40 01 00 00       	call   c0025ee1 <intq_full>
c0025da1:	84 c0                	test   %al,%al
c0025da3:	74 2c                	je     c0025dd1 <input_putc+0x79>
c0025da5:	c7 44 24 10 fa f6 02 	movl   $0xc002f6fa,0x10(%esp)
c0025dac:	c0 
c0025dad:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025db4:	c0 
c0025db5:	c7 44 24 08 f2 d9 02 	movl   $0xc002d9f2,0x8(%esp)
c0025dbc:	c0 
c0025dbd:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025dc4:	00 
c0025dc5:	c7 04 24 e4 f6 02 c0 	movl   $0xc002f6e4,(%esp)
c0025dcc:	e8 e2 2b 00 00       	call   c00289b3 <debug_panic>

  intq_putc (&buffer, key);
c0025dd1:	0f b6 db             	movzbl %bl,%ebx
c0025dd4:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0025dd8:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025ddf:	e8 a7 03 00 00       	call   c002618b <intq_putc>
  serial_notify ();
c0025de4:	e8 21 ee ff ff       	call   c0024c0a <serial_notify>
}
c0025de9:	83 c4 28             	add    $0x28,%esp
c0025dec:	5b                   	pop    %ebx
c0025ded:	c3                   	ret    

c0025dee <input_getc>:

/* Retrieves a key from the input buffer.
   If the buffer is empty, waits for a key to be pressed. */
uint8_t
input_getc (void) 
{
c0025dee:	56                   	push   %esi
c0025def:	53                   	push   %ebx
c0025df0:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level;
  uint8_t key;

  old_level = intr_disable ();
c0025df3:	e8 17 bc ff ff       	call   c0021a0f <intr_disable>
c0025df8:	89 c6                	mov    %eax,%esi
  key = intq_getc (&buffer);
c0025dfa:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025e01:	e8 b9 02 00 00       	call   c00260bf <intq_getc>
c0025e06:	89 c3                	mov    %eax,%ebx
  serial_notify ();
c0025e08:	e8 fd ed ff ff       	call   c0024c0a <serial_notify>
  intr_set_level (old_level);
c0025e0d:	89 34 24             	mov    %esi,(%esp)
c0025e10:	e8 01 bc ff ff       	call   c0021a16 <intr_set_level>
  
  return key;
}
c0025e15:	89 d8                	mov    %ebx,%eax
c0025e17:	83 c4 14             	add    $0x14,%esp
c0025e1a:	5b                   	pop    %ebx
c0025e1b:	5e                   	pop    %esi
c0025e1c:	c3                   	ret    

c0025e1d <input_full>:
/* Returns true if the input buffer is full,
   false otherwise.
   Interrupts must be off. */
bool
input_full (void) 
{
c0025e1d:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0025e20:	e8 9f bb ff ff       	call   c00219c4 <intr_get_level>
c0025e25:	85 c0                	test   %eax,%eax
c0025e27:	74 2c                	je     c0025e55 <input_full+0x38>
c0025e29:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025e30:	c0 
c0025e31:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025e38:	c0 
c0025e39:	c7 44 24 08 e7 d9 02 	movl   $0xc002d9e7,0x8(%esp)
c0025e40:	c0 
c0025e41:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c0025e48:	00 
c0025e49:	c7 04 24 e4 f6 02 c0 	movl   $0xc002f6e4,(%esp)
c0025e50:	e8 5e 2b 00 00       	call   c00289b3 <debug_panic>
  return intq_full (&buffer);
c0025e55:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025e5c:	e8 80 00 00 00       	call   c0025ee1 <intq_full>
}
c0025e61:	83 c4 2c             	add    $0x2c,%esp
c0025e64:	c3                   	ret    

c0025e65 <intq_init>:
static void signal (struct intq *q, struct thread **waiter);

/* Initializes interrupt queue Q. */
void
intq_init (struct intq *q) 
{
c0025e65:	53                   	push   %ebx
c0025e66:	83 ec 18             	sub    $0x18,%esp
c0025e69:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_init (&q->lock);
c0025e6d:	89 1c 24             	mov    %ebx,(%esp)
c0025e70:	e8 98 cf ff ff       	call   c0022e0d <lock_init>
  q->not_full = q->not_empty = NULL;
c0025e75:	c7 43 28 00 00 00 00 	movl   $0x0,0x28(%ebx)
c0025e7c:	c7 43 24 00 00 00 00 	movl   $0x0,0x24(%ebx)
  q->head = q->tail = 0;
c0025e83:	c7 43 70 00 00 00 00 	movl   $0x0,0x70(%ebx)
c0025e8a:	c7 43 6c 00 00 00 00 	movl   $0x0,0x6c(%ebx)
}
c0025e91:	83 c4 18             	add    $0x18,%esp
c0025e94:	5b                   	pop    %ebx
c0025e95:	c3                   	ret    

c0025e96 <intq_empty>:

/* Returns true if Q is empty, false otherwise. */
bool
intq_empty (const struct intq *q) 
{
c0025e96:	53                   	push   %ebx
c0025e97:	83 ec 28             	sub    $0x28,%esp
c0025e9a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025e9e:	e8 21 bb ff ff       	call   c00219c4 <intr_get_level>
c0025ea3:	85 c0                	test   %eax,%eax
c0025ea5:	74 2c                	je     c0025ed3 <intq_empty+0x3d>
c0025ea7:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025eae:	c0 
c0025eaf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025eb6:	c0 
c0025eb7:	c7 44 24 08 27 da 02 	movl   $0xc002da27,0x8(%esp)
c0025ebe:	c0 
c0025ebf:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025ec6:	00 
c0025ec7:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025ece:	e8 e0 2a 00 00       	call   c00289b3 <debug_panic>
  return q->head == q->tail;
c0025ed3:	8b 43 70             	mov    0x70(%ebx),%eax
c0025ed6:	39 43 6c             	cmp    %eax,0x6c(%ebx)
c0025ed9:	0f 94 c0             	sete   %al
}
c0025edc:	83 c4 28             	add    $0x28,%esp
c0025edf:	5b                   	pop    %ebx
c0025ee0:	c3                   	ret    

c0025ee1 <intq_full>:

/* Returns true if Q is full, false otherwise. */
bool
intq_full (const struct intq *q) 
{
c0025ee1:	53                   	push   %ebx
c0025ee2:	83 ec 28             	sub    $0x28,%esp
c0025ee5:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025ee9:	e8 d6 ba ff ff       	call   c00219c4 <intr_get_level>
c0025eee:	85 c0                	test   %eax,%eax
c0025ef0:	74 2c                	je     c0025f1e <intq_full+0x3d>
c0025ef2:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025ef9:	c0 
c0025efa:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025f01:	c0 
c0025f02:	c7 44 24 08 1d da 02 	movl   $0xc002da1d,0x8(%esp)
c0025f09:	c0 
c0025f0a:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c0025f11:	00 
c0025f12:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025f19:	e8 95 2a 00 00       	call   c00289b3 <debug_panic>

/* Returns the position after POS within an intq. */
static int
next (int pos) 
{
  return (pos + 1) % INTQ_BUFSIZE;
c0025f1e:	8b 43 6c             	mov    0x6c(%ebx),%eax
c0025f21:	8d 50 01             	lea    0x1(%eax),%edx
c0025f24:	89 d0                	mov    %edx,%eax
c0025f26:	c1 f8 1f             	sar    $0x1f,%eax
c0025f29:	c1 e8 1a             	shr    $0x1a,%eax
c0025f2c:	01 c2                	add    %eax,%edx
c0025f2e:	83 e2 3f             	and    $0x3f,%edx
c0025f31:	29 c2                	sub    %eax,%edx
  return next (q->head) == q->tail;
c0025f33:	39 53 70             	cmp    %edx,0x70(%ebx)
c0025f36:	0f 94 c0             	sete   %al
}
c0025f39:	83 c4 28             	add    $0x28,%esp
c0025f3c:	5b                   	pop    %ebx
c0025f3d:	c3                   	ret    

c0025f3e <wait>:

/* WAITER must be the address of Q's not_empty or not_full
   member.  Waits until the given condition is true. */
static void
wait (struct intq *q UNUSED, struct thread **waiter) 
{
c0025f3e:	56                   	push   %esi
c0025f3f:	53                   	push   %ebx
c0025f40:	83 ec 24             	sub    $0x24,%esp
c0025f43:	89 c3                	mov    %eax,%ebx
c0025f45:	89 d6                	mov    %edx,%esi
  ASSERT (!intr_context ());
c0025f47:	e8 25 bd ff ff       	call   c0021c71 <intr_context>
c0025f4c:	84 c0                	test   %al,%al
c0025f4e:	74 2c                	je     c0025f7c <wait+0x3e>
c0025f50:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0025f57:	c0 
c0025f58:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025f5f:	c0 
c0025f60:	c7 44 24 08 0e da 02 	movl   $0xc002da0e,0x8(%esp)
c0025f67:	c0 
c0025f68:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c0025f6f:	00 
c0025f70:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025f77:	e8 37 2a 00 00       	call   c00289b3 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0025f7c:	e8 43 ba ff ff       	call   c00219c4 <intr_get_level>
c0025f81:	85 c0                	test   %eax,%eax
c0025f83:	74 2c                	je     c0025fb1 <wait+0x73>
c0025f85:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c0025f8c:	c0 
c0025f8d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025f94:	c0 
c0025f95:	c7 44 24 08 0e da 02 	movl   $0xc002da0e,0x8(%esp)
c0025f9c:	c0 
c0025f9d:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c0025fa4:	00 
c0025fa5:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025fac:	e8 02 2a 00 00       	call   c00289b3 <debug_panic>
  ASSERT ((waiter == &q->not_empty && intq_empty (q))
c0025fb1:	8d 43 28             	lea    0x28(%ebx),%eax
c0025fb4:	39 c6                	cmp    %eax,%esi
c0025fb6:	75 0c                	jne    c0025fc4 <wait+0x86>
c0025fb8:	89 1c 24             	mov    %ebx,(%esp)
c0025fbb:	e8 d6 fe ff ff       	call   c0025e96 <intq_empty>
c0025fc0:	84 c0                	test   %al,%al
c0025fc2:	75 3f                	jne    c0026003 <wait+0xc5>
c0025fc4:	8d 43 24             	lea    0x24(%ebx),%eax
c0025fc7:	39 c6                	cmp    %eax,%esi
c0025fc9:	75 0c                	jne    c0025fd7 <wait+0x99>
c0025fcb:	89 1c 24             	mov    %ebx,(%esp)
c0025fce:	e8 0e ff ff ff       	call   c0025ee1 <intq_full>
c0025fd3:	84 c0                	test   %al,%al
c0025fd5:	75 2c                	jne    c0026003 <wait+0xc5>
c0025fd7:	c7 44 24 10 24 f7 02 	movl   $0xc002f724,0x10(%esp)
c0025fde:	c0 
c0025fdf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0025fe6:	c0 
c0025fe7:	c7 44 24 08 0e da 02 	movl   $0xc002da0e,0x8(%esp)
c0025fee:	c0 
c0025fef:	c7 44 24 04 5c 00 00 	movl   $0x5c,0x4(%esp)
c0025ff6:	00 
c0025ff7:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0025ffe:	e8 b0 29 00 00       	call   c00289b3 <debug_panic>
          || (waiter == &q->not_full && intq_full (q)));

  *waiter = thread_current ();
c0026003:	e8 24 ae ff ff       	call   c0020e2c <thread_current>
c0026008:	89 06                	mov    %eax,(%esi)
  thread_block ();
c002600a:	e8 5b b3 ff ff       	call   c002136a <thread_block>
}
c002600f:	83 c4 24             	add    $0x24,%esp
c0026012:	5b                   	pop    %ebx
c0026013:	5e                   	pop    %esi
c0026014:	c3                   	ret    

c0026015 <signal>:
   member, and the associated condition must be true.  If a
   thread is waiting for the condition, wakes it up and resets
   the waiting thread. */
static void
signal (struct intq *q UNUSED, struct thread **waiter) 
{
c0026015:	56                   	push   %esi
c0026016:	53                   	push   %ebx
c0026017:	83 ec 24             	sub    $0x24,%esp
c002601a:	89 c6                	mov    %eax,%esi
c002601c:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c002601e:	e8 a1 b9 ff ff       	call   c00219c4 <intr_get_level>
c0026023:	85 c0                	test   %eax,%eax
c0026025:	74 2c                	je     c0026053 <signal+0x3e>
c0026027:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c002602e:	c0 
c002602f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0026036:	c0 
c0026037:	c7 44 24 08 07 da 02 	movl   $0xc002da07,0x8(%esp)
c002603e:	c0 
c002603f:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0026046:	00 
c0026047:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c002604e:	e8 60 29 00 00       	call   c00289b3 <debug_panic>
  ASSERT ((waiter == &q->not_empty && !intq_empty (q))
c0026053:	8d 46 28             	lea    0x28(%esi),%eax
c0026056:	39 c3                	cmp    %eax,%ebx
c0026058:	75 0c                	jne    c0026066 <signal+0x51>
c002605a:	89 34 24             	mov    %esi,(%esp)
c002605d:	e8 34 fe ff ff       	call   c0025e96 <intq_empty>
c0026062:	84 c0                	test   %al,%al
c0026064:	74 3f                	je     c00260a5 <signal+0x90>
c0026066:	8d 46 24             	lea    0x24(%esi),%eax
c0026069:	39 c3                	cmp    %eax,%ebx
c002606b:	75 0c                	jne    c0026079 <signal+0x64>
c002606d:	89 34 24             	mov    %esi,(%esp)
c0026070:	e8 6c fe ff ff       	call   c0025ee1 <intq_full>
c0026075:	84 c0                	test   %al,%al
c0026077:	74 2c                	je     c00260a5 <signal+0x90>
c0026079:	c7 44 24 10 80 f7 02 	movl   $0xc002f780,0x10(%esp)
c0026080:	c0 
c0026081:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0026088:	c0 
c0026089:	c7 44 24 08 07 da 02 	movl   $0xc002da07,0x8(%esp)
c0026090:	c0 
c0026091:	c7 44 24 04 6b 00 00 	movl   $0x6b,0x4(%esp)
c0026098:	00 
c0026099:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c00260a0:	e8 0e 29 00 00       	call   c00289b3 <debug_panic>
          || (waiter == &q->not_full && !intq_full (q)));

  if (*waiter != NULL) 
c00260a5:	8b 03                	mov    (%ebx),%eax
c00260a7:	85 c0                	test   %eax,%eax
c00260a9:	74 0e                	je     c00260b9 <signal+0xa4>
    {
      thread_unblock (*waiter);
c00260ab:	89 04 24             	mov    %eax,(%esp)
c00260ae:	e8 a0 ac ff ff       	call   c0020d53 <thread_unblock>
      *waiter = NULL;
c00260b3:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
    }
}
c00260b9:	83 c4 24             	add    $0x24,%esp
c00260bc:	5b                   	pop    %ebx
c00260bd:	5e                   	pop    %esi
c00260be:	c3                   	ret    

c00260bf <intq_getc>:
{
c00260bf:	56                   	push   %esi
c00260c0:	53                   	push   %ebx
c00260c1:	83 ec 24             	sub    $0x24,%esp
c00260c4:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c00260c8:	e8 f7 b8 ff ff       	call   c00219c4 <intr_get_level>
c00260cd:	85 c0                	test   %eax,%eax
c00260cf:	75 05                	jne    c00260d6 <intq_getc+0x17>
      wait (q, &q->not_empty);
c00260d1:	8d 73 28             	lea    0x28(%ebx),%esi
c00260d4:	eb 7a                	jmp    c0026150 <intq_getc+0x91>
  ASSERT (intr_get_level () == INTR_OFF);
c00260d6:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00260dd:	c0 
c00260de:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00260e5:	c0 
c00260e6:	c7 44 24 08 13 da 02 	movl   $0xc002da13,0x8(%esp)
c00260ed:	c0 
c00260ee:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c00260f5:	00 
c00260f6:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c00260fd:	e8 b1 28 00 00       	call   c00289b3 <debug_panic>
      ASSERT (!intr_context ());
c0026102:	e8 6a bb ff ff       	call   c0021c71 <intr_context>
c0026107:	84 c0                	test   %al,%al
c0026109:	74 2c                	je     c0026137 <intq_getc+0x78>
c002610b:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c0026112:	c0 
c0026113:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002611a:	c0 
c002611b:	c7 44 24 08 13 da 02 	movl   $0xc002da13,0x8(%esp)
c0026122:	c0 
c0026123:	c7 44 24 04 2d 00 00 	movl   $0x2d,0x4(%esp)
c002612a:	00 
c002612b:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0026132:	e8 7c 28 00 00       	call   c00289b3 <debug_panic>
      lock_acquire (&q->lock);
c0026137:	89 1c 24             	mov    %ebx,(%esp)
c002613a:	e8 6b cd ff ff       	call   c0022eaa <lock_acquire>
      wait (q, &q->not_empty);
c002613f:	89 f2                	mov    %esi,%edx
c0026141:	89 d8                	mov    %ebx,%eax
c0026143:	e8 f6 fd ff ff       	call   c0025f3e <wait>
      lock_release (&q->lock);
c0026148:	89 1c 24             	mov    %ebx,(%esp)
c002614b:	e8 24 cf ff ff       	call   c0023074 <lock_release>
  while (intq_empty (q)) 
c0026150:	89 1c 24             	mov    %ebx,(%esp)
c0026153:	e8 3e fd ff ff       	call   c0025e96 <intq_empty>
c0026158:	84 c0                	test   %al,%al
c002615a:	75 a6                	jne    c0026102 <intq_getc+0x43>
  byte = q->buf[q->tail];
c002615c:	8b 4b 70             	mov    0x70(%ebx),%ecx
c002615f:	0f b6 74 0b 2c       	movzbl 0x2c(%ebx,%ecx,1),%esi
  return (pos + 1) % INTQ_BUFSIZE;
c0026164:	83 c1 01             	add    $0x1,%ecx
c0026167:	89 ca                	mov    %ecx,%edx
c0026169:	c1 fa 1f             	sar    $0x1f,%edx
c002616c:	c1 ea 1a             	shr    $0x1a,%edx
c002616f:	01 d1                	add    %edx,%ecx
c0026171:	83 e1 3f             	and    $0x3f,%ecx
c0026174:	29 d1                	sub    %edx,%ecx
  q->tail = next (q->tail);
c0026176:	89 4b 70             	mov    %ecx,0x70(%ebx)
  signal (q, &q->not_full);
c0026179:	8d 53 24             	lea    0x24(%ebx),%edx
c002617c:	89 d8                	mov    %ebx,%eax
c002617e:	e8 92 fe ff ff       	call   c0026015 <signal>
}
c0026183:	89 f0                	mov    %esi,%eax
c0026185:	83 c4 24             	add    $0x24,%esp
c0026188:	5b                   	pop    %ebx
c0026189:	5e                   	pop    %esi
c002618a:	c3                   	ret    

c002618b <intq_putc>:
{
c002618b:	57                   	push   %edi
c002618c:	56                   	push   %esi
c002618d:	53                   	push   %ebx
c002618e:	83 ec 20             	sub    $0x20,%esp
c0026191:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0026195:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0026199:	e8 26 b8 ff ff       	call   c00219c4 <intr_get_level>
c002619e:	85 c0                	test   %eax,%eax
c00261a0:	75 05                	jne    c00261a7 <intq_putc+0x1c>
      wait (q, &q->not_full);
c00261a2:	8d 73 24             	lea    0x24(%ebx),%esi
c00261a5:	eb 7a                	jmp    c0026221 <intq_putc+0x96>
  ASSERT (intr_get_level () == INTR_OFF);
c00261a7:	c7 44 24 10 4c e5 02 	movl   $0xc002e54c,0x10(%esp)
c00261ae:	c0 
c00261af:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00261b6:	c0 
c00261b7:	c7 44 24 08 fd d9 02 	movl   $0xc002d9fd,0x8(%esp)
c00261be:	c0 
c00261bf:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c00261c6:	00 
c00261c7:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c00261ce:	e8 e0 27 00 00       	call   c00289b3 <debug_panic>
      ASSERT (!intr_context ());
c00261d3:	e8 99 ba ff ff       	call   c0021c71 <intr_context>
c00261d8:	84 c0                	test   %al,%al
c00261da:	74 2c                	je     c0026208 <intq_putc+0x7d>
c00261dc:	c7 44 24 10 e2 e5 02 	movl   $0xc002e5e2,0x10(%esp)
c00261e3:	c0 
c00261e4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00261eb:	c0 
c00261ec:	c7 44 24 08 fd d9 02 	movl   $0xc002d9fd,0x8(%esp)
c00261f3:	c0 
c00261f4:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
c00261fb:	00 
c00261fc:	c7 04 24 0f f7 02 c0 	movl   $0xc002f70f,(%esp)
c0026203:	e8 ab 27 00 00       	call   c00289b3 <debug_panic>
      lock_acquire (&q->lock);
c0026208:	89 1c 24             	mov    %ebx,(%esp)
c002620b:	e8 9a cc ff ff       	call   c0022eaa <lock_acquire>
      wait (q, &q->not_full);
c0026210:	89 f2                	mov    %esi,%edx
c0026212:	89 d8                	mov    %ebx,%eax
c0026214:	e8 25 fd ff ff       	call   c0025f3e <wait>
      lock_release (&q->lock);
c0026219:	89 1c 24             	mov    %ebx,(%esp)
c002621c:	e8 53 ce ff ff       	call   c0023074 <lock_release>
  while (intq_full (q))
c0026221:	89 1c 24             	mov    %ebx,(%esp)
c0026224:	e8 b8 fc ff ff       	call   c0025ee1 <intq_full>
c0026229:	84 c0                	test   %al,%al
c002622b:	75 a6                	jne    c00261d3 <intq_putc+0x48>
  q->buf[q->head] = byte;
c002622d:	8b 53 6c             	mov    0x6c(%ebx),%edx
c0026230:	89 f8                	mov    %edi,%eax
c0026232:	88 44 13 2c          	mov    %al,0x2c(%ebx,%edx,1)
  return (pos + 1) % INTQ_BUFSIZE;
c0026236:	83 c2 01             	add    $0x1,%edx
c0026239:	89 d0                	mov    %edx,%eax
c002623b:	c1 f8 1f             	sar    $0x1f,%eax
c002623e:	c1 e8 1a             	shr    $0x1a,%eax
c0026241:	01 c2                	add    %eax,%edx
c0026243:	83 e2 3f             	and    $0x3f,%edx
c0026246:	29 c2                	sub    %eax,%edx
  q->head = next (q->head);
c0026248:	89 53 6c             	mov    %edx,0x6c(%ebx)
  signal (q, &q->not_empty);
c002624b:	8d 53 28             	lea    0x28(%ebx),%edx
c002624e:	89 d8                	mov    %ebx,%eax
c0026250:	e8 c0 fd ff ff       	call   c0026015 <signal>
}
c0026255:	83 c4 20             	add    $0x20,%esp
c0026258:	5b                   	pop    %ebx
c0026259:	5e                   	pop    %esi
c002625a:	5f                   	pop    %edi
c002625b:	c3                   	ret    

c002625c <rtc_get_time>:

/* Returns number of seconds since Unix epoch of January 1,
   1970. */
time_t
rtc_get_time (void)
{
c002625c:	55                   	push   %ebp
c002625d:	57                   	push   %edi
c002625e:	56                   	push   %esi
c002625f:	53                   	push   %ebx
c0026260:	83 ec 03             	sub    $0x3,%esp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026263:	bb 00 00 00 00       	mov    $0x0,%ebx
c0026268:	bd 02 00 00 00       	mov    $0x2,%ebp
c002626d:	89 d8                	mov    %ebx,%eax
c002626f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026271:	e4 71                	in     $0x71,%al

/* Returns the integer value of the given BCD byte. */
static int
bcd_to_bin (uint8_t x)
{
  return (x & 0x0f) + ((x >> 4) * 10);
c0026273:	89 c2                	mov    %eax,%edx
c0026275:	83 e2 0f             	and    $0xf,%edx
c0026278:	c0 e8 04             	shr    $0x4,%al
c002627b:	0f b6 c0             	movzbl %al,%eax
c002627e:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0026281:	8d 0c 42             	lea    (%edx,%eax,2),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026284:	89 e8                	mov    %ebp,%eax
c0026286:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026288:	e4 71                	in     $0x71,%al
c002628a:	88 04 24             	mov    %al,(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002628d:	b8 04 00 00 00       	mov    $0x4,%eax
c0026292:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026294:	e4 71                	in     $0x71,%al
c0026296:	88 44 24 01          	mov    %al,0x1(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002629a:	b8 07 00 00 00       	mov    $0x7,%eax
c002629f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262a1:	e4 71                	in     $0x71,%al
c00262a3:	88 44 24 02          	mov    %al,0x2(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00262a7:	b8 08 00 00 00       	mov    $0x8,%eax
c00262ac:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262ae:	e4 71                	in     $0x71,%al
c00262b0:	89 c6                	mov    %eax,%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00262b2:	b8 09 00 00 00       	mov    $0x9,%eax
c00262b7:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262b9:	e4 71                	in     $0x71,%al
c00262bb:	89 c7                	mov    %eax,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00262bd:	89 d8                	mov    %ebx,%eax
c00262bf:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00262c1:	e4 71                	in     $0x71,%al
c00262c3:	89 c2                	mov    %eax,%edx
c00262c5:	89 d0                	mov    %edx,%eax
c00262c7:	83 e0 0f             	and    $0xf,%eax
c00262ca:	c0 ea 04             	shr    $0x4,%dl
c00262cd:	0f b6 d2             	movzbl %dl,%edx
c00262d0:	8d 14 92             	lea    (%edx,%edx,4),%edx
c00262d3:	8d 04 50             	lea    (%eax,%edx,2),%eax
  while (sec != bcd_to_bin (cmos_read (RTC_REG_SEC)));
c00262d6:	39 c1                	cmp    %eax,%ecx
c00262d8:	75 93                	jne    c002626d <rtc_get_time+0x11>
  return (x & 0x0f) + ((x >> 4) * 10);
c00262da:	89 fa                	mov    %edi,%edx
c00262dc:	83 e2 0f             	and    $0xf,%edx
c00262df:	89 f8                	mov    %edi,%eax
c00262e1:	c0 e8 04             	shr    $0x4,%al
c00262e4:	0f b6 f8             	movzbl %al,%edi
c00262e7:	8d 04 bf             	lea    (%edi,%edi,4),%eax
  if (year < 70)
c00262ea:	8d 04 42             	lea    (%edx,%eax,2),%eax
    year += 100;
c00262ed:	8d 50 64             	lea    0x64(%eax),%edx
c00262f0:	83 f8 45             	cmp    $0x45,%eax
c00262f3:	0f 4e c2             	cmovle %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c00262f6:	89 f2                	mov    %esi,%edx
c00262f8:	83 e2 0f             	and    $0xf,%edx
c00262fb:	89 f3                	mov    %esi,%ebx
c00262fd:	c0 eb 04             	shr    $0x4,%bl
c0026300:	0f b6 f3             	movzbl %bl,%esi
c0026303:	8d 1c b6             	lea    (%esi,%esi,4),%ebx
c0026306:	8d 34 5a             	lea    (%edx,%ebx,2),%esi
  year -= 70;
c0026309:	8d 78 ba             	lea    -0x46(%eax),%edi
  time = (year * 365 + (year - 1) / 4) * 24 * 60 * 60;
c002630c:	69 df 6d 01 00 00    	imul   $0x16d,%edi,%ebx
c0026312:	8d 50 bc             	lea    -0x44(%eax),%edx
c0026315:	83 e8 47             	sub    $0x47,%eax
c0026318:	0f 48 c2             	cmovs  %edx,%eax
c002631b:	c1 f8 02             	sar    $0x2,%eax
c002631e:	01 d8                	add    %ebx,%eax
c0026320:	69 c0 80 51 01 00    	imul   $0x15180,%eax,%eax
  for (i = 1; i <= mon; i++)
c0026326:	85 f6                	test   %esi,%esi
c0026328:	7e 19                	jle    c0026343 <rtc_get_time+0xe7>
c002632a:	ba 01 00 00 00       	mov    $0x1,%edx
    time += days_per_month[i - 1] * 24 * 60 * 60;
c002632f:	69 1c 95 3c da 02 c0 	imul   $0x15180,-0x3ffd25c4(,%edx,4),%ebx
c0026336:	80 51 01 00 
c002633a:	01 d8                	add    %ebx,%eax
  for (i = 1; i <= mon; i++)
c002633c:	83 c2 01             	add    $0x1,%edx
c002633f:	39 f2                	cmp    %esi,%edx
c0026341:	7e ec                	jle    c002632f <rtc_get_time+0xd3>
  if (mon > 2 && year % 4 == 0)
c0026343:	83 fe 02             	cmp    $0x2,%esi
c0026346:	7e 0e                	jle    c0026356 <rtc_get_time+0xfa>
c0026348:	83 e7 03             	and    $0x3,%edi
    time += 24 * 60 * 60;
c002634b:	8d 90 80 51 01 00    	lea    0x15180(%eax),%edx
c0026351:	85 ff                	test   %edi,%edi
c0026353:	0f 44 c2             	cmove  %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c0026356:	0f b6 54 24 01       	movzbl 0x1(%esp),%edx
c002635b:	89 d3                	mov    %edx,%ebx
c002635d:	83 e3 0f             	and    $0xf,%ebx
c0026360:	c0 ea 04             	shr    $0x4,%dl
c0026363:	0f b6 d2             	movzbl %dl,%edx
c0026366:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026369:	8d 1c 53             	lea    (%ebx,%edx,2),%ebx
  time += hour * 60 * 60;
c002636c:	69 db 10 0e 00 00    	imul   $0xe10,%ebx,%ebx
  return (x & 0x0f) + ((x >> 4) * 10);
c0026372:	0f b6 14 24          	movzbl (%esp),%edx
c0026376:	89 d6                	mov    %edx,%esi
c0026378:	83 e6 0f             	and    $0xf,%esi
c002637b:	c0 ea 04             	shr    $0x4,%dl
c002637e:	0f b6 d2             	movzbl %dl,%edx
c0026381:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026384:	8d 14 56             	lea    (%esi,%edx,2),%edx
  time += min * 60;
c0026387:	6b d2 3c             	imul   $0x3c,%edx,%edx
  time += (mday - 1) * 24 * 60 * 60;
c002638a:	01 da                	add    %ebx,%edx
  time += hour * 60 * 60;
c002638c:	01 d1                	add    %edx,%ecx
  return (x & 0x0f) + ((x >> 4) * 10);
c002638e:	0f b6 54 24 02       	movzbl 0x2(%esp),%edx
c0026393:	89 d3                	mov    %edx,%ebx
c0026395:	83 e3 0f             	and    $0xf,%ebx
c0026398:	c0 ea 04             	shr    $0x4,%dl
c002639b:	0f b6 d2             	movzbl %dl,%edx
c002639e:	8d 14 92             	lea    (%edx,%edx,4),%edx
  time += (mday - 1) * 24 * 60 * 60;
c00263a1:	8d 54 53 ff          	lea    -0x1(%ebx,%edx,2),%edx
c00263a5:	69 d2 80 51 01 00    	imul   $0x15180,%edx,%edx
  time += min * 60;
c00263ab:	01 d1                	add    %edx,%ecx
  time += sec;
c00263ad:	01 c8                	add    %ecx,%eax
}
c00263af:	83 c4 03             	add    $0x3,%esp
c00263b2:	5b                   	pop    %ebx
c00263b3:	5e                   	pop    %esi
c00263b4:	5f                   	pop    %edi
c00263b5:	5d                   	pop    %ebp
c00263b6:	c3                   	ret    
c00263b7:	90                   	nop
c00263b8:	90                   	nop
c00263b9:	90                   	nop
c00263ba:	90                   	nop
c00263bb:	90                   	nop
c00263bc:	90                   	nop
c00263bd:	90                   	nop
c00263be:	90                   	nop
c00263bf:	90                   	nop

c00263c0 <shutdown_configure>:
/* Sets TYPE as the way that machine will shut down when Pintos
   execution is complete. */
void
shutdown_configure (enum shutdown_type type)
{
  how = type;
c00263c0:	8b 44 24 04          	mov    0x4(%esp),%eax
c00263c4:	a3 94 79 03 c0       	mov    %eax,0xc0037994
c00263c9:	c3                   	ret    

c00263ca <shutdown_reboot>:
}

/* Reboots the machine via the keyboard controller. */
void
shutdown_reboot (void)
{
c00263ca:	56                   	push   %esi
c00263cb:	53                   	push   %ebx
c00263cc:	83 ec 14             	sub    $0x14,%esp
  printf ("Rebooting...\n");
c00263cf:	c7 04 24 db f7 02 c0 	movl   $0xc002f7db,(%esp)
c00263d6:	e8 00 43 00 00       	call   c002a6db <puts>
    {
      int i;

      /* Poll keyboard controller's status byte until
       * 'input buffer empty' is reported. */
      for (i = 0; i < 0x10000; i++)
c00263db:	bb 00 00 00 00       	mov    $0x0,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00263e0:	be fe ff ff ff       	mov    $0xfffffffe,%esi
c00263e5:	eb 1d                	jmp    c0026404 <shutdown_reboot+0x3a>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00263e7:	e4 64                	in     $0x64,%al
        {
          if ((inb (CONTROL_REG) & 0x02) == 0)
c00263e9:	a8 02                	test   $0x2,%al
c00263eb:	74 1f                	je     c002640c <shutdown_reboot+0x42>
            break;
          timer_udelay (2);
c00263ed:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00263f4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263fb:	00 
c00263fc:	e8 2a e0 ff ff       	call   c002442b <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c0026401:	83 c3 01             	add    $0x1,%ebx
c0026404:	81 fb ff ff 00 00    	cmp    $0xffff,%ebx
c002640a:	7e db                	jle    c00263e7 <shutdown_reboot+0x1d>
        }

      timer_udelay (50);
c002640c:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c0026413:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002641a:	00 
c002641b:	e8 0b e0 ff ff       	call   c002442b <timer_udelay>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026420:	89 f0                	mov    %esi,%eax
c0026422:	e6 64                	out    %al,$0x64

      /* Pulse bit 0 of the output port P2 of the keyboard controller.
       * This will reset the CPU. */
      outb (CONTROL_REG, 0xfe);
      timer_udelay (50);
c0026424:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c002642b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026432:	00 
c0026433:	e8 f3 df ff ff       	call   c002442b <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c0026438:	bb 00 00 00 00       	mov    $0x0,%ebx
    }
c002643d:	eb c5                	jmp    c0026404 <shutdown_reboot+0x3a>

c002643f <shutdown_power_off>:

/* Powers down the machine we're running on,
   as long as we're running on Bochs or QEMU. */
void
shutdown_power_off (void)
{
c002643f:	83 ec 2c             	sub    $0x2c,%esp
  const char s[] = "Shutdown";
c0026442:	c7 44 24 17 53 68 75 	movl   $0x74756853,0x17(%esp)
c0026449:	74 
c002644a:	c7 44 24 1b 64 6f 77 	movl   $0x6e776f64,0x1b(%esp)
c0026451:	6e 
c0026452:	c6 44 24 1f 00       	movb   $0x0,0x1f(%esp)

/* Print statistics about Pintos execution. */
static void
print_stats (void)
{
  timer_print_stats ();
c0026457:	e8 01 e0 ff ff       	call   c002445d <timer_print_stats>
  thread_print_stats ();
c002645c:	e8 a9 a8 ff ff       	call   c0020d0a <thread_print_stats>
#ifdef FILESYS
  block_print_stats ();
#endif
  console_print_stats ();
c0026461:	e8 0e 42 00 00       	call   c002a674 <console_print_stats>
  kbd_print_stats ();
c0026466:	e8 33 e2 ff ff       	call   c002469e <kbd_print_stats>
  printf ("Powering off...\n");
c002646b:	c7 04 24 e8 f7 02 c0 	movl   $0xc002f7e8,(%esp)
c0026472:	e8 64 42 00 00       	call   c002a6db <puts>
  serial_flush ();
c0026477:	e8 50 e7 ff ff       	call   c0024bcc <serial_flush>
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c002647c:	ba 04 b0 ff ff       	mov    $0xffffb004,%edx
c0026481:	b8 00 20 00 00       	mov    $0x2000,%eax
c0026486:	66 ef                	out    %ax,(%dx)
  for (p = s; *p != '\0'; p++)
c0026488:	0f b6 44 24 17       	movzbl 0x17(%esp),%eax
c002648d:	84 c0                	test   %al,%al
c002648f:	74 14                	je     c00264a5 <shutdown_power_off+0x66>
c0026491:	8d 4c 24 17          	lea    0x17(%esp),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026495:	ba 00 89 ff ff       	mov    $0xffff8900,%edx
c002649a:	ee                   	out    %al,(%dx)
c002649b:	83 c1 01             	add    $0x1,%ecx
c002649e:	0f b6 01             	movzbl (%ecx),%eax
c00264a1:	84 c0                	test   %al,%al
c00264a3:	75 f5                	jne    c002649a <shutdown_power_off+0x5b>
c00264a5:	ba 01 05 00 00       	mov    $0x501,%edx
c00264aa:	b8 31 00 00 00       	mov    $0x31,%eax
c00264af:	ee                   	out    %al,(%dx)
  asm volatile ("cli; hlt" : : : "memory");
c00264b0:	fa                   	cli    
c00264b1:	f4                   	hlt    
  printf ("still running...\n");
c00264b2:	c7 04 24 f8 f7 02 c0 	movl   $0xc002f7f8,(%esp)
c00264b9:	e8 1d 42 00 00       	call   c002a6db <puts>
c00264be:	eb fe                	jmp    c00264be <shutdown_power_off+0x7f>

c00264c0 <shutdown>:
{
c00264c0:	83 ec 0c             	sub    $0xc,%esp
  switch (how)
c00264c3:	a1 94 79 03 c0       	mov    0xc0037994,%eax
c00264c8:	83 f8 01             	cmp    $0x1,%eax
c00264cb:	74 07                	je     c00264d4 <shutdown+0x14>
c00264cd:	83 f8 02             	cmp    $0x2,%eax
c00264d0:	74 07                	je     c00264d9 <shutdown+0x19>
c00264d2:	eb 11                	jmp    c00264e5 <shutdown+0x25>
      shutdown_power_off ();
c00264d4:	e8 66 ff ff ff       	call   c002643f <shutdown_power_off>
c00264d9:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
      shutdown_reboot ();
c00264e0:	e8 e5 fe ff ff       	call   c00263ca <shutdown_reboot>
}
c00264e5:	83 c4 0c             	add    $0xc,%esp
c00264e8:	c3                   	ret    
c00264e9:	90                   	nop
c00264ea:	90                   	nop
c00264eb:	90                   	nop
c00264ec:	90                   	nop
c00264ed:	90                   	nop
c00264ee:	90                   	nop
c00264ef:	90                   	nop

c00264f0 <speaker_off>:

/* Turn off the PC speaker, by disconnecting the timer channel's
   output from the speaker. */
void
speaker_off (void)
{
c00264f0:	83 ec 1c             	sub    $0x1c,%esp
  enum intr_level old_level = intr_disable ();
c00264f3:	e8 17 b5 ff ff       	call   c0021a0f <intr_disable>
c00264f8:	89 c2                	mov    %eax,%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00264fa:	e4 61                	in     $0x61,%al
  outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) & ~SPEAKER_GATE_ENABLE);
c00264fc:	83 e0 fc             	and    $0xfffffffc,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00264ff:	e6 61                	out    %al,$0x61
  intr_set_level (old_level);
c0026501:	89 14 24             	mov    %edx,(%esp)
c0026504:	e8 0d b5 ff ff       	call   c0021a16 <intr_set_level>
}
c0026509:	83 c4 1c             	add    $0x1c,%esp
c002650c:	c3                   	ret    

c002650d <speaker_on>:
{
c002650d:	56                   	push   %esi
c002650e:	53                   	push   %ebx
c002650f:	83 ec 14             	sub    $0x14,%esp
c0026512:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (frequency >= 20 && frequency <= 20000)
c0026516:	8d 43 ec             	lea    -0x14(%ebx),%eax
c0026519:	3d 0c 4e 00 00       	cmp    $0x4e0c,%eax
c002651e:	77 30                	ja     c0026550 <speaker_on+0x43>
      enum intr_level old_level = intr_disable ();
c0026520:	e8 ea b4 ff ff       	call   c0021a0f <intr_disable>
c0026525:	89 c6                	mov    %eax,%esi
      pit_configure_channel (2, 3, frequency);
c0026527:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002652b:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c0026532:	00 
c0026533:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c002653a:	e8 20 d8 ff ff       	call   c0023d5f <pit_configure_channel>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002653f:	e4 61                	in     $0x61,%al
      outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) | SPEAKER_GATE_ENABLE);
c0026541:	83 c8 03             	or     $0x3,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026544:	e6 61                	out    %al,$0x61
      intr_set_level (old_level);
c0026546:	89 34 24             	mov    %esi,(%esp)
c0026549:	e8 c8 b4 ff ff       	call   c0021a16 <intr_set_level>
c002654e:	eb 05                	jmp    c0026555 <speaker_on+0x48>
      speaker_off ();
c0026550:	e8 9b ff ff ff       	call   c00264f0 <speaker_off>
}
c0026555:	83 c4 14             	add    $0x14,%esp
c0026558:	5b                   	pop    %ebx
c0026559:	5e                   	pop    %esi
c002655a:	c3                   	ret    

c002655b <speaker_beep>:

/* Briefly beep the PC speaker. */
void
speaker_beep (void)
{
c002655b:	83 ec 1c             	sub    $0x1c,%esp

     We can't just enable interrupts while we sleep.  For one
     thing, we get called (indirectly) from printf, which should
     always work, even during boot before we're ready to enable
     interrupts. */
  if (intr_get_level () == INTR_ON)
c002655e:	e8 61 b4 ff ff       	call   c00219c4 <intr_get_level>
c0026563:	83 f8 01             	cmp    $0x1,%eax
c0026566:	75 25                	jne    c002658d <speaker_beep+0x32>
    {
      speaker_on (440);
c0026568:	c7 04 24 b8 01 00 00 	movl   $0x1b8,(%esp)
c002656f:	e8 99 ff ff ff       	call   c002650d <speaker_on>
      timer_msleep (250);
c0026574:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002657b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026582:	00 
c0026583:	e8 3f de ff ff       	call   c00243c7 <timer_msleep>
      speaker_off ();
c0026588:	e8 63 ff ff ff       	call   c00264f0 <speaker_off>
    }
}
c002658d:	83 c4 1c             	add    $0x1c,%esp
c0026590:	c3                   	ret    

c0026591 <debug_backtrace>:
   each of the functions we are nested within.  gdb or addr2line
   may be applied to kernel.o to translate these into file names,
   line numbers, and function names.  */
void
debug_backtrace (void) 
{
c0026591:	55                   	push   %ebp
c0026592:	89 e5                	mov    %esp,%ebp
c0026594:	53                   	push   %ebx
c0026595:	83 ec 14             	sub    $0x14,%esp
  static bool explained;
  void **frame;
  
  printf ("Call stack: %p", __builtin_return_address (0));
c0026598:	8b 45 04             	mov    0x4(%ebp),%eax
c002659b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002659f:	c7 04 24 09 f8 02 c0 	movl   $0xc002f809,(%esp)
c00265a6:	e8 b3 05 00 00       	call   c0026b5e <printf>
  for (frame = __builtin_frame_address (1);
c00265ab:	8b 5d 00             	mov    0x0(%ebp),%ebx
c00265ae:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00265b4:	76 27                	jbe    c00265dd <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c00265b6:	83 3b 00             	cmpl   $0x0,(%ebx)
c00265b9:	74 22                	je     c00265dd <debug_backtrace+0x4c>
       frame = frame[0]) 
    printf (" %p", frame[1]);
c00265bb:	8b 43 04             	mov    0x4(%ebx),%eax
c00265be:	89 44 24 04          	mov    %eax,0x4(%esp)
c00265c2:	c7 04 24 14 f8 02 c0 	movl   $0xc002f814,(%esp)
c00265c9:	e8 90 05 00 00       	call   c0026b5e <printf>
       frame = frame[0]) 
c00265ce:	8b 1b                	mov    (%ebx),%ebx
  for (frame = __builtin_frame_address (1);
c00265d0:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c00265d6:	76 05                	jbe    c00265dd <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c00265d8:	83 3b 00             	cmpl   $0x0,(%ebx)
c00265db:	75 de                	jne    c00265bb <debug_backtrace+0x2a>
  printf (".\n");
c00265dd:	c7 04 24 ab f3 02 c0 	movl   $0xc002f3ab,(%esp)
c00265e4:	e8 f2 40 00 00       	call   c002a6db <puts>

  if (!explained) 
c00265e9:	80 3d 98 79 03 c0 00 	cmpb   $0x0,0xc0037998
c00265f0:	75 13                	jne    c0026605 <debug_backtrace+0x74>
    {
      explained = true;
c00265f2:	c6 05 98 79 03 c0 01 	movb   $0x1,0xc0037998
      printf ("The `backtrace' program can make call stacks useful.\n"
c00265f9:	c7 04 24 18 f8 02 c0 	movl   $0xc002f818,(%esp)
c0026600:	e8 d6 40 00 00       	call   c002a6db <puts>
              "Read \"Backtraces\" in the \"Debugging Tools\" chapter\n"
              "of the Pintos documentation for more information.\n");
    }
}
c0026605:	83 c4 14             	add    $0x14,%esp
c0026608:	5b                   	pop    %ebx
c0026609:	5d                   	pop    %ebp
c002660a:	c3                   	ret    

c002660b <random_init>:
{
  uint8_t *seedp = (uint8_t *) &seed;
  int i;
  uint8_t j;

  for (i = 0; i < 256; i++) 
c002660b:	b8 00 00 00 00       	mov    $0x0,%eax
    s[i] = i;
c0026610:	88 80 c0 79 03 c0    	mov    %al,-0x3ffc8640(%eax)
  for (i = 0; i < 256; i++) 
c0026616:	83 c0 01             	add    $0x1,%eax
c0026619:	3d 00 01 00 00       	cmp    $0x100,%eax
c002661e:	75 f0                	jne    c0026610 <random_init+0x5>
{
c0026620:	56                   	push   %esi
c0026621:	53                   	push   %ebx
  for (i = 0; i < 256; i++) 
c0026622:	be 00 00 00 00       	mov    $0x0,%esi
c0026627:	66 b8 00 00          	mov    $0x0,%ax
  for (i = j = 0; i < 256; i++) 
    {
      j += s[i] + seedp[i % sizeof seed];
c002662b:	89 c1                	mov    %eax,%ecx
c002662d:	83 e1 03             	and    $0x3,%ecx
c0026630:	0f b6 98 c0 79 03 c0 	movzbl -0x3ffc8640(%eax),%ebx
c0026637:	89 da                	mov    %ebx,%edx
c0026639:	02 54 0c 0c          	add    0xc(%esp,%ecx,1),%dl
c002663d:	89 d1                	mov    %edx,%ecx
c002663f:	01 ce                	add    %ecx,%esi
      swap_byte (s + i, s + j);
c0026641:	89 f2                	mov    %esi,%edx
c0026643:	0f b6 ca             	movzbl %dl,%ecx
  *a = *b;
c0026646:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c002664d:	88 90 c0 79 03 c0    	mov    %dl,-0x3ffc8640(%eax)
  *b = t;
c0026653:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)
  for (i = j = 0; i < 256; i++) 
c0026659:	83 c0 01             	add    $0x1,%eax
c002665c:	3d 00 01 00 00       	cmp    $0x100,%eax
c0026661:	75 c8                	jne    c002662b <random_init+0x20>
    }

  s_i = s_j = 0;
c0026663:	c6 05 a1 79 03 c0 00 	movb   $0x0,0xc00379a1
c002666a:	c6 05 a2 79 03 c0 00 	movb   $0x0,0xc00379a2
  inited = true;
c0026671:	c6 05 a0 79 03 c0 01 	movb   $0x1,0xc00379a0
}
c0026678:	5b                   	pop    %ebx
c0026679:	5e                   	pop    %esi
c002667a:	c3                   	ret    

c002667b <random_bytes>:

/* Writes SIZE random bytes into BUF. */
void
random_bytes (void *buf_, size_t size) 
{
c002667b:	55                   	push   %ebp
c002667c:	57                   	push   %edi
c002667d:	56                   	push   %esi
c002667e:	53                   	push   %ebx
c002667f:	83 ec 0c             	sub    $0xc,%esp
  uint8_t *buf;

  if (!inited)
c0026682:	80 3d a0 79 03 c0 00 	cmpb   $0x0,0xc00379a0
c0026689:	75 0c                	jne    c0026697 <random_bytes+0x1c>
    random_init (0);
c002668b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0026692:	e8 74 ff ff ff       	call   c002660b <random_init>

  for (buf = buf_; size-- > 0; buf++)
c0026697:	8b 44 24 24          	mov    0x24(%esp),%eax
c002669b:	83 e8 01             	sub    $0x1,%eax
c002669e:	89 44 24 08          	mov    %eax,0x8(%esp)
c00266a2:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c00266a7:	0f 84 87 00 00 00    	je     c0026734 <random_bytes+0xb9>
c00266ad:	0f b6 1d a1 79 03 c0 	movzbl 0xc00379a1,%ebx
c00266b4:	b8 00 00 00 00       	mov    $0x0,%eax
c00266b9:	0f b6 35 a2 79 03 c0 	movzbl 0xc00379a2,%esi
c00266c0:	83 c6 01             	add    $0x1,%esi
c00266c3:	89 f5                	mov    %esi,%ebp
c00266c5:	8d 14 06             	lea    (%esi,%eax,1),%edx
    {
      uint8_t s_k;
      
      s_i++;
      s_j += s[s_i];
c00266c8:	0f b6 d2             	movzbl %dl,%edx
c00266cb:	02 9a c0 79 03 c0    	add    -0x3ffc8640(%edx),%bl
c00266d1:	88 5c 24 07          	mov    %bl,0x7(%esp)
      swap_byte (s + s_i, s + s_j);
c00266d5:	0f b6 cb             	movzbl %bl,%ecx
  uint8_t t = *a;
c00266d8:	0f b6 ba c0 79 03 c0 	movzbl -0x3ffc8640(%edx),%edi
  *a = *b;
c00266df:	0f b6 99 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%ebx
c00266e6:	88 9a c0 79 03 c0    	mov    %bl,-0x3ffc8640(%edx)
  *b = t;
c00266ec:	89 fb                	mov    %edi,%ebx
c00266ee:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)

      s_k = s[s_i] + s[s_j];
c00266f4:	89 f9                	mov    %edi,%ecx
c00266f6:	02 8a c0 79 03 c0    	add    -0x3ffc8640(%edx),%cl
      *buf = s[s_k];
c00266fc:	0f b6 c9             	movzbl %cl,%ecx
c00266ff:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c0026706:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002670a:	88 14 07             	mov    %dl,(%edi,%eax,1)
c002670d:	83 c0 01             	add    $0x1,%eax
  for (buf = buf_; size-- > 0; buf++)
c0026710:	3b 44 24 24          	cmp    0x24(%esp),%eax
c0026714:	74 07                	je     c002671d <random_bytes+0xa2>
      s_j += s[s_i];
c0026716:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c002671b:	eb a6                	jmp    c00266c3 <random_bytes+0x48>
c002671d:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c0026722:	0f b6 44 24 08       	movzbl 0x8(%esp),%eax
c0026727:	01 e8                	add    %ebp,%eax
c0026729:	a2 a2 79 03 c0       	mov    %al,0xc00379a2
c002672e:	88 1d a1 79 03 c0    	mov    %bl,0xc00379a1
    }
}
c0026734:	83 c4 0c             	add    $0xc,%esp
c0026737:	5b                   	pop    %ebx
c0026738:	5e                   	pop    %esi
c0026739:	5f                   	pop    %edi
c002673a:	5d                   	pop    %ebp
c002673b:	c3                   	ret    

c002673c <random_ulong>:
/* Returns a pseudo-random unsigned long.
   Use random_ulong() % n to obtain a random number in the range
   0...n (exclusive). */
unsigned long
random_ulong (void) 
{
c002673c:	83 ec 18             	sub    $0x18,%esp
  unsigned long ul;
  random_bytes (&ul, sizeof ul);
c002673f:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c0026746:	00 
c0026747:	8d 44 24 14          	lea    0x14(%esp),%eax
c002674b:	89 04 24             	mov    %eax,(%esp)
c002674e:	e8 28 ff ff ff       	call   c002667b <random_bytes>
  return ul;
}
c0026753:	8b 44 24 14          	mov    0x14(%esp),%eax
c0026757:	83 c4 18             	add    $0x18,%esp
c002675a:	c3                   	ret    
c002675b:	90                   	nop
c002675c:	90                   	nop
c002675d:	90                   	nop
c002675e:	90                   	nop
c002675f:	90                   	nop

c0026760 <vsnprintf_helper>:
}

/* Helper function for vsnprintf(). */
static void
vsnprintf_helper (char ch, void *aux_)
{
c0026760:	53                   	push   %ebx
c0026761:	8b 5c 24 08          	mov    0x8(%esp),%ebx
c0026765:	8b 44 24 0c          	mov    0xc(%esp),%eax
  struct vsnprintf_aux *aux = aux_;

  if (aux->length++ < aux->max_length)
c0026769:	8b 50 04             	mov    0x4(%eax),%edx
c002676c:	8d 4a 01             	lea    0x1(%edx),%ecx
c002676f:	89 48 04             	mov    %ecx,0x4(%eax)
c0026772:	3b 50 08             	cmp    0x8(%eax),%edx
c0026775:	7d 09                	jge    c0026780 <vsnprintf_helper+0x20>
    *aux->p++ = ch;
c0026777:	8b 10                	mov    (%eax),%edx
c0026779:	8d 4a 01             	lea    0x1(%edx),%ecx
c002677c:	89 08                	mov    %ecx,(%eax)
c002677e:	88 1a                	mov    %bl,(%edx)
}
c0026780:	5b                   	pop    %ebx
c0026781:	c3                   	ret    

c0026782 <output_dup>:
}

/* Writes CH to OUTPUT with auxiliary data AUX, CNT times. */
static void
output_dup (char ch, size_t cnt, void (*output) (char, void *), void *aux) 
{
c0026782:	55                   	push   %ebp
c0026783:	57                   	push   %edi
c0026784:	56                   	push   %esi
c0026785:	53                   	push   %ebx
c0026786:	83 ec 1c             	sub    $0x1c,%esp
c0026789:	8b 7c 24 30          	mov    0x30(%esp),%edi
  while (cnt-- > 0)
c002678d:	85 d2                	test   %edx,%edx
c002678f:	74 15                	je     c00267a6 <output_dup+0x24>
c0026791:	89 ce                	mov    %ecx,%esi
c0026793:	89 d3                	mov    %edx,%ebx
    output (ch, aux);
c0026795:	0f be e8             	movsbl %al,%ebp
c0026798:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002679c:	89 2c 24             	mov    %ebp,(%esp)
c002679f:	ff d6                	call   *%esi
  while (cnt-- > 0)
c00267a1:	83 eb 01             	sub    $0x1,%ebx
c00267a4:	75 f2                	jne    c0026798 <output_dup+0x16>
}
c00267a6:	83 c4 1c             	add    $0x1c,%esp
c00267a9:	5b                   	pop    %ebx
c00267aa:	5e                   	pop    %esi
c00267ab:	5f                   	pop    %edi
c00267ac:	5d                   	pop    %ebp
c00267ad:	c3                   	ret    

c00267ae <format_integer>:
{
c00267ae:	55                   	push   %ebp
c00267af:	57                   	push   %edi
c00267b0:	56                   	push   %esi
c00267b1:	53                   	push   %ebx
c00267b2:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c00267b8:	89 c6                	mov    %eax,%esi
c00267ba:	89 d7                	mov    %edx,%edi
c00267bc:	8b 84 24 a0 00 00 00 	mov    0xa0(%esp),%eax
  sign = 0;
c00267c3:	c7 44 24 30 00 00 00 	movl   $0x0,0x30(%esp)
c00267ca:	00 
  if (is_signed) 
c00267cb:	84 c9                	test   %cl,%cl
c00267cd:	74 4c                	je     c002681b <format_integer+0x6d>
      if (c->flags & PLUS)
c00267cf:	8b 8c 24 a8 00 00 00 	mov    0xa8(%esp),%ecx
c00267d6:	8b 11                	mov    (%ecx),%edx
c00267d8:	f6 c2 02             	test   $0x2,%dl
c00267db:	74 14                	je     c00267f1 <format_integer+0x43>
        sign = negative ? '-' : '+';
c00267dd:	3c 01                	cmp    $0x1,%al
c00267df:	19 c0                	sbb    %eax,%eax
c00267e1:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267e5:	83 64 24 30 fe       	andl   $0xfffffffe,0x30(%esp)
c00267ea:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c00267ef:	eb 2a                	jmp    c002681b <format_integer+0x6d>
      else if (c->flags & SPACE)
c00267f1:	f6 c2 04             	test   $0x4,%dl
c00267f4:	74 14                	je     c002680a <format_integer+0x5c>
        sign = negative ? '-' : ' ';
c00267f6:	3c 01                	cmp    $0x1,%al
c00267f8:	19 c0                	sbb    %eax,%eax
c00267fa:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267fe:	83 64 24 30 f3       	andl   $0xfffffff3,0x30(%esp)
c0026803:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c0026808:	eb 11                	jmp    c002681b <format_integer+0x6d>
  sign = 0;
c002680a:	3c 01                	cmp    $0x1,%al
c002680c:	19 c0                	sbb    %eax,%eax
c002680e:	89 44 24 30          	mov    %eax,0x30(%esp)
c0026812:	f7 54 24 30          	notl   0x30(%esp)
c0026816:	83 64 24 30 2d       	andl   $0x2d,0x30(%esp)
  x = (c->flags & POUND) && value ? b->x : 0;
c002681b:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026822:	8b 00                	mov    (%eax),%eax
c0026824:	89 44 24 38          	mov    %eax,0x38(%esp)
c0026828:	83 e0 08             	and    $0x8,%eax
c002682b:	89 44 24 3c          	mov    %eax,0x3c(%esp)
c002682f:	74 5c                	je     c002688d <format_integer+0xdf>
c0026831:	89 f8                	mov    %edi,%eax
c0026833:	09 f0                	or     %esi,%eax
c0026835:	0f 84 e9 00 00 00    	je     c0026924 <format_integer+0x176>
c002683b:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026842:	8b 40 08             	mov    0x8(%eax),%eax
c0026845:	89 44 24 34          	mov    %eax,0x34(%esp)
c0026849:	eb 08                	jmp    c0026853 <format_integer+0xa5>
c002684b:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c0026852:	00 
      *cp++ = b->digits[value % b->base];
c0026853:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c002685a:	8b 40 04             	mov    0x4(%eax),%eax
c002685d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026861:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026868:	8b 00                	mov    (%eax),%eax
c002686a:	89 44 24 18          	mov    %eax,0x18(%esp)
c002686e:	89 c1                	mov    %eax,%ecx
c0026870:	c1 f9 1f             	sar    $0x1f,%ecx
c0026873:	89 4c 24 1c          	mov    %ecx,0x1c(%esp)
c0026877:	bb 00 00 00 00       	mov    $0x0,%ebx
c002687c:	8d 6c 24 40          	lea    0x40(%esp),%ebp
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026880:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026884:	83 e0 20             	and    $0x20,%eax
c0026887:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c002688b:	eb 17                	jmp    c00268a4 <format_integer+0xf6>
  while (value > 0) 
c002688d:	89 f8                	mov    %edi,%eax
c002688f:	09 f0                	or     %esi,%eax
c0026891:	75 b8                	jne    c002684b <format_integer+0x9d>
  x = (c->flags & POUND) && value ? b->x : 0;
c0026893:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c002689a:	00 
  cp = buf;
c002689b:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c002689f:	e9 92 00 00 00       	jmp    c0026936 <format_integer+0x188>
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c00268a4:	83 7c 24 2c 00       	cmpl   $0x0,0x2c(%esp)
c00268a9:	74 1c                	je     c00268c7 <format_integer+0x119>
c00268ab:	85 db                	test   %ebx,%ebx
c00268ad:	7e 18                	jle    c00268c7 <format_integer+0x119>
c00268af:	8b 8c 24 a4 00 00 00 	mov    0xa4(%esp),%ecx
c00268b6:	89 d8                	mov    %ebx,%eax
c00268b8:	99                   	cltd   
c00268b9:	f7 79 0c             	idivl  0xc(%ecx)
c00268bc:	85 d2                	test   %edx,%edx
c00268be:	75 07                	jne    c00268c7 <format_integer+0x119>
        *cp++ = ',';
c00268c0:	c6 45 00 2c          	movb   $0x2c,0x0(%ebp)
c00268c4:	8d 6d 01             	lea    0x1(%ebp),%ebp
      *cp++ = b->digits[value % b->base];
c00268c7:	8d 45 01             	lea    0x1(%ebp),%eax
c00268ca:	89 44 24 24          	mov    %eax,0x24(%esp)
c00268ce:	8b 44 24 18          	mov    0x18(%esp),%eax
c00268d2:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00268d6:	89 44 24 08          	mov    %eax,0x8(%esp)
c00268da:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00268de:	89 34 24             	mov    %esi,(%esp)
c00268e1:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00268e5:	e8 a0 1a 00 00       	call   c002838a <__umoddi3>
c00268ea:	8b 4c 24 28          	mov    0x28(%esp),%ecx
c00268ee:	0f b6 04 01          	movzbl (%ecx,%eax,1),%eax
c00268f2:	88 45 00             	mov    %al,0x0(%ebp)
      value /= b->base;
c00268f5:	8b 44 24 18          	mov    0x18(%esp),%eax
c00268f9:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00268fd:	89 44 24 08          	mov    %eax,0x8(%esp)
c0026901:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0026905:	89 34 24             	mov    %esi,(%esp)
c0026908:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002690c:	e8 56 1a 00 00       	call   c0028367 <__udivdi3>
c0026911:	89 c6                	mov    %eax,%esi
c0026913:	89 d7                	mov    %edx,%edi
      digit_cnt++;
c0026915:	83 c3 01             	add    $0x1,%ebx
  while (value > 0) 
c0026918:	89 d1                	mov    %edx,%ecx
c002691a:	09 c1                	or     %eax,%ecx
c002691c:	74 14                	je     c0026932 <format_integer+0x184>
      *cp++ = b->digits[value % b->base];
c002691e:	8b 6c 24 24          	mov    0x24(%esp),%ebp
c0026922:	eb 80                	jmp    c00268a4 <format_integer+0xf6>
  x = (c->flags & POUND) && value ? b->x : 0;
c0026924:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c002692b:	00 
  cp = buf;
c002692c:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c0026930:	eb 04                	jmp    c0026936 <format_integer+0x188>
c0026932:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  precision = c->precision < 0 ? 1 : c->precision;
c0026936:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c002693d:	8b 50 08             	mov    0x8(%eax),%edx
c0026940:	85 d2                	test   %edx,%edx
c0026942:	b8 01 00 00 00       	mov    $0x1,%eax
c0026947:	0f 48 d0             	cmovs  %eax,%edx
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002694a:	8d 7c 24 40          	lea    0x40(%esp),%edi
c002694e:	89 d8                	mov    %ebx,%eax
c0026950:	29 f8                	sub    %edi,%eax
c0026952:	39 c2                	cmp    %eax,%edx
c0026954:	7e 1f                	jle    c0026975 <format_integer+0x1c7>
c0026956:	8d 44 24 7f          	lea    0x7f(%esp),%eax
c002695a:	39 c3                	cmp    %eax,%ebx
c002695c:	73 17                	jae    c0026975 <format_integer+0x1c7>
c002695e:	89 f9                	mov    %edi,%ecx
c0026960:	89 c6                	mov    %eax,%esi
    *cp++ = '0';
c0026962:	83 c3 01             	add    $0x1,%ebx
c0026965:	c6 43 ff 30          	movb   $0x30,-0x1(%ebx)
c0026969:	89 d8                	mov    %ebx,%eax
c002696b:	29 c8                	sub    %ecx,%eax
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002696d:	39 c2                	cmp    %eax,%edx
c002696f:	7e 04                	jle    c0026975 <format_integer+0x1c7>
c0026971:	39 f3                	cmp    %esi,%ebx
c0026973:	75 ed                	jne    c0026962 <format_integer+0x1b4>
  if ((c->flags & POUND) && b->base == 8 && (cp == buf || cp[-1] != '0'))
c0026975:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002697a:	74 20                	je     c002699c <format_integer+0x1ee>
c002697c:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026983:	83 38 08             	cmpl   $0x8,(%eax)
c0026986:	75 14                	jne    c002699c <format_integer+0x1ee>
c0026988:	8d 44 24 40          	lea    0x40(%esp),%eax
c002698c:	39 c3                	cmp    %eax,%ebx
c002698e:	74 06                	je     c0026996 <format_integer+0x1e8>
c0026990:	80 7b ff 30          	cmpb   $0x30,-0x1(%ebx)
c0026994:	74 06                	je     c002699c <format_integer+0x1ee>
    *cp++ = '0';
c0026996:	c6 03 30             	movb   $0x30,(%ebx)
c0026999:	8d 5b 01             	lea    0x1(%ebx),%ebx
  pad_cnt = c->width - (cp - buf) - (x ? 2 : 0) - (sign != 0);
c002699c:	29 df                	sub    %ebx,%edi
c002699e:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c00269a5:	03 78 04             	add    0x4(%eax),%edi
c00269a8:	83 7c 24 34 01       	cmpl   $0x1,0x34(%esp)
c00269ad:	19 c0                	sbb    %eax,%eax
c00269af:	f7 d0                	not    %eax
c00269b1:	83 e0 02             	and    $0x2,%eax
c00269b4:	83 7c 24 30 00       	cmpl   $0x0,0x30(%esp)
c00269b9:	0f 95 c1             	setne  %cl
c00269bc:	89 ce                	mov    %ecx,%esi
c00269be:	29 c7                	sub    %eax,%edi
c00269c0:	0f b6 c1             	movzbl %cl,%eax
c00269c3:	29 c7                	sub    %eax,%edi
c00269c5:	b8 00 00 00 00       	mov    $0x0,%eax
c00269ca:	0f 48 f8             	cmovs  %eax,%edi
  if ((c->flags & (MINUS | ZERO)) == 0)
c00269cd:	f6 44 24 38 11       	testb  $0x11,0x38(%esp)
c00269d2:	75 1d                	jne    c00269f1 <format_integer+0x243>
    output_dup (' ', pad_cnt, output, aux);
c00269d4:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269db:	89 04 24             	mov    %eax,(%esp)
c00269de:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c00269e5:	89 fa                	mov    %edi,%edx
c00269e7:	b8 20 00 00 00       	mov    $0x20,%eax
c00269ec:	e8 91 fd ff ff       	call   c0026782 <output_dup>
  if (sign)
c00269f1:	89 f0                	mov    %esi,%eax
c00269f3:	84 c0                	test   %al,%al
c00269f5:	74 19                	je     c0026a10 <format_integer+0x262>
    output (sign, aux);
c00269f7:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269fe:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026a02:	8b 44 24 30          	mov    0x30(%esp),%eax
c0026a06:	89 04 24             	mov    %eax,(%esp)
c0026a09:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (x) 
c0026a10:	83 7c 24 34 00       	cmpl   $0x0,0x34(%esp)
c0026a15:	74 33                	je     c0026a4a <format_integer+0x29c>
      output ('0', aux);
c0026a17:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a1e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026a22:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
c0026a29:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
      output (x, aux); 
c0026a30:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a37:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026a3b:	0f be 44 24 34       	movsbl 0x34(%esp),%eax
c0026a40:	89 04 24             	mov    %eax,(%esp)
c0026a43:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (c->flags & ZERO)
c0026a4a:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a51:	f6 00 10             	testb  $0x10,(%eax)
c0026a54:	74 1d                	je     c0026a73 <format_integer+0x2c5>
    output_dup ('0', pad_cnt, output, aux);
c0026a56:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a5d:	89 04 24             	mov    %eax,(%esp)
c0026a60:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a67:	89 fa                	mov    %edi,%edx
c0026a69:	b8 30 00 00 00       	mov    $0x30,%eax
c0026a6e:	e8 0f fd ff ff       	call   c0026782 <output_dup>
  while (cp > buf)
c0026a73:	8d 44 24 40          	lea    0x40(%esp),%eax
c0026a77:	39 c3                	cmp    %eax,%ebx
c0026a79:	76 2b                	jbe    c0026aa6 <format_integer+0x2f8>
c0026a7b:	89 c6                	mov    %eax,%esi
c0026a7d:	89 7c 24 18          	mov    %edi,0x18(%esp)
c0026a81:	8b bc 24 ac 00 00 00 	mov    0xac(%esp),%edi
c0026a88:	8b ac 24 b0 00 00 00 	mov    0xb0(%esp),%ebp
    output (*--cp, aux);
c0026a8f:	83 eb 01             	sub    $0x1,%ebx
c0026a92:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0026a96:	0f be 03             	movsbl (%ebx),%eax
c0026a99:	89 04 24             	mov    %eax,(%esp)
c0026a9c:	ff d7                	call   *%edi
  while (cp > buf)
c0026a9e:	39 f3                	cmp    %esi,%ebx
c0026aa0:	75 ed                	jne    c0026a8f <format_integer+0x2e1>
c0026aa2:	8b 7c 24 18          	mov    0x18(%esp),%edi
  if (c->flags & MINUS)
c0026aa6:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026aad:	f6 00 01             	testb  $0x1,(%eax)
c0026ab0:	74 1d                	je     c0026acf <format_integer+0x321>
    output_dup (' ', pad_cnt, output, aux);
c0026ab2:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026ab9:	89 04 24             	mov    %eax,(%esp)
c0026abc:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026ac3:	89 fa                	mov    %edi,%edx
c0026ac5:	b8 20 00 00 00       	mov    $0x20,%eax
c0026aca:	e8 b3 fc ff ff       	call   c0026782 <output_dup>
}
c0026acf:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c0026ad5:	5b                   	pop    %ebx
c0026ad6:	5e                   	pop    %esi
c0026ad7:	5f                   	pop    %edi
c0026ad8:	5d                   	pop    %ebp
c0026ad9:	c3                   	ret    

c0026ada <format_string>:
   auxiliary data AUX. */
static void
format_string (const char *string, int length,
               struct printf_conversion *c,
               void (*output) (char, void *), void *aux) 
{
c0026ada:	55                   	push   %ebp
c0026adb:	57                   	push   %edi
c0026adc:	56                   	push   %esi
c0026add:	53                   	push   %ebx
c0026ade:	83 ec 1c             	sub    $0x1c,%esp
c0026ae1:	89 c5                	mov    %eax,%ebp
c0026ae3:	89 d3                	mov    %edx,%ebx
c0026ae5:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026ae9:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0026aed:	8b 74 24 30          	mov    0x30(%esp),%esi
c0026af1:	8b 7c 24 34          	mov    0x34(%esp),%edi
  int i;
  if (c->width > length && (c->flags & MINUS) == 0)
c0026af5:	8b 51 04             	mov    0x4(%ecx),%edx
c0026af8:	39 da                	cmp    %ebx,%edx
c0026afa:	7e 16                	jle    c0026b12 <format_string+0x38>
c0026afc:	f6 01 01             	testb  $0x1,(%ecx)
c0026aff:	75 11                	jne    c0026b12 <format_string+0x38>
    output_dup (' ', c->width - length, output, aux);
c0026b01:	29 da                	sub    %ebx,%edx
c0026b03:	89 3c 24             	mov    %edi,(%esp)
c0026b06:	89 f1                	mov    %esi,%ecx
c0026b08:	b8 20 00 00 00       	mov    $0x20,%eax
c0026b0d:	e8 70 fc ff ff       	call   c0026782 <output_dup>
  for (i = 0; i < length; i++)
c0026b12:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026b16:	85 c0                	test   %eax,%eax
c0026b18:	7e 17                	jle    c0026b31 <format_string+0x57>
c0026b1a:	89 eb                	mov    %ebp,%ebx
c0026b1c:	01 c5                	add    %eax,%ebp
    output (string[i], aux);
c0026b1e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0026b22:	0f be 03             	movsbl (%ebx),%eax
c0026b25:	89 04 24             	mov    %eax,(%esp)
c0026b28:	ff d6                	call   *%esi
c0026b2a:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < length; i++)
c0026b2d:	39 eb                	cmp    %ebp,%ebx
c0026b2f:	75 ed                	jne    c0026b1e <format_string+0x44>
  if (c->width > length && (c->flags & MINUS) != 0)
c0026b31:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0026b35:	8b 50 04             	mov    0x4(%eax),%edx
c0026b38:	39 54 24 08          	cmp    %edx,0x8(%esp)
c0026b3c:	7d 18                	jge    c0026b56 <format_string+0x7c>
c0026b3e:	f6 00 01             	testb  $0x1,(%eax)
c0026b41:	74 13                	je     c0026b56 <format_string+0x7c>
    output_dup (' ', c->width - length, output, aux);
c0026b43:	2b 54 24 08          	sub    0x8(%esp),%edx
c0026b47:	89 3c 24             	mov    %edi,(%esp)
c0026b4a:	89 f1                	mov    %esi,%ecx
c0026b4c:	b8 20 00 00 00       	mov    $0x20,%eax
c0026b51:	e8 2c fc ff ff       	call   c0026782 <output_dup>
}
c0026b56:	83 c4 1c             	add    $0x1c,%esp
c0026b59:	5b                   	pop    %ebx
c0026b5a:	5e                   	pop    %esi
c0026b5b:	5f                   	pop    %edi
c0026b5c:	5d                   	pop    %ebp
c0026b5d:	c3                   	ret    

c0026b5e <printf>:
{
c0026b5e:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0026b61:	8d 44 24 24          	lea    0x24(%esp),%eax
  retval = vprintf (format, args);
c0026b65:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b69:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b6d:	89 04 24             	mov    %eax,(%esp)
c0026b70:	e8 25 3b 00 00       	call   c002a69a <vprintf>
}
c0026b75:	83 c4 1c             	add    $0x1c,%esp
c0026b78:	c3                   	ret    

c0026b79 <__printf>:
/* Wrapper for __vprintf() that converts varargs into a
   va_list. */
void
__printf (const char *format,
          void (*output) (char, void *), void *aux, ...) 
{
c0026b79:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;

  va_start (args, aux);
c0026b7c:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  __vprintf (format, args, output, aux);
c0026b80:	8b 54 24 28          	mov    0x28(%esp),%edx
c0026b84:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0026b88:	8b 54 24 24          	mov    0x24(%esp),%edx
c0026b8c:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026b90:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b94:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b98:	89 04 24             	mov    %eax,(%esp)
c0026b9b:	e8 04 00 00 00       	call   c0026ba4 <__vprintf>
  va_end (args);
}
c0026ba0:	83 c4 1c             	add    $0x1c,%esp
c0026ba3:	c3                   	ret    

c0026ba4 <__vprintf>:
{
c0026ba4:	55                   	push   %ebp
c0026ba5:	57                   	push   %edi
c0026ba6:	56                   	push   %esi
c0026ba7:	53                   	push   %ebx
c0026ba8:	83 ec 5c             	sub    $0x5c,%esp
c0026bab:	8b 7c 24 70          	mov    0x70(%esp),%edi
c0026baf:	8b 6c 24 74          	mov    0x74(%esp),%ebp
  for (; *format != '\0'; format++)
c0026bb3:	0f b6 07             	movzbl (%edi),%eax
c0026bb6:	84 c0                	test   %al,%al
c0026bb8:	0f 84 1c 06 00 00    	je     c00271da <__vprintf+0x636>
      if (*format != '%') 
c0026bbe:	3c 25                	cmp    $0x25,%al
c0026bc0:	74 19                	je     c0026bdb <__vprintf+0x37>
          output (*format, aux);
c0026bc2:	8b 5c 24 7c          	mov    0x7c(%esp),%ebx
c0026bc6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0026bca:	0f be c0             	movsbl %al,%eax
c0026bcd:	89 04 24             	mov    %eax,(%esp)
c0026bd0:	ff 54 24 78          	call   *0x78(%esp)
          continue;
c0026bd4:	89 fb                	mov    %edi,%ebx
c0026bd6:	e9 d5 05 00 00       	jmp    c00271b0 <__vprintf+0x60c>
      format++;
c0026bdb:	8d 77 01             	lea    0x1(%edi),%esi
      if (*format == '%') 
c0026bde:	b9 00 00 00 00       	mov    $0x0,%ecx
c0026be3:	80 7f 01 25          	cmpb   $0x25,0x1(%edi)
c0026be7:	75 1c                	jne    c0026c05 <__vprintf+0x61>
          output ('%', aux);
c0026be9:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0026bed:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026bf1:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
c0026bf8:	ff 54 24 78          	call   *0x78(%esp)
      format++;
c0026bfc:	89 f3                	mov    %esi,%ebx
          continue;
c0026bfe:	e9 ad 05 00 00       	jmp    c00271b0 <__vprintf+0x60c>
      switch (*format++) 
c0026c03:	89 d6                	mov    %edx,%esi
c0026c05:	8d 56 01             	lea    0x1(%esi),%edx
c0026c08:	0f b6 5a ff          	movzbl -0x1(%edx),%ebx
c0026c0c:	8d 43 e0             	lea    -0x20(%ebx),%eax
c0026c0f:	3c 10                	cmp    $0x10,%al
c0026c11:	77 29                	ja     c0026c3c <__vprintf+0x98>
c0026c13:	0f b6 c0             	movzbl %al,%eax
c0026c16:	ff 24 85 70 da 02 c0 	jmp    *-0x3ffd2590(,%eax,4)
          c->flags |= MINUS;
c0026c1d:	83 c9 01             	or     $0x1,%ecx
c0026c20:	eb e1                	jmp    c0026c03 <__vprintf+0x5f>
          c->flags |= PLUS;
c0026c22:	83 c9 02             	or     $0x2,%ecx
c0026c25:	eb dc                	jmp    c0026c03 <__vprintf+0x5f>
          c->flags |= SPACE;
c0026c27:	83 c9 04             	or     $0x4,%ecx
c0026c2a:	eb d7                	jmp    c0026c03 <__vprintf+0x5f>
          c->flags |= POUND;
c0026c2c:	83 c9 08             	or     $0x8,%ecx
c0026c2f:	90                   	nop
c0026c30:	eb d1                	jmp    c0026c03 <__vprintf+0x5f>
          c->flags |= ZERO;
c0026c32:	83 c9 10             	or     $0x10,%ecx
c0026c35:	eb cc                	jmp    c0026c03 <__vprintf+0x5f>
          c->flags |= GROUP;
c0026c37:	83 c9 20             	or     $0x20,%ecx
c0026c3a:	eb c7                	jmp    c0026c03 <__vprintf+0x5f>
      switch (*format++) 
c0026c3c:	89 f0                	mov    %esi,%eax
c0026c3e:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & MINUS)
c0026c42:	f6 c1 01             	test   $0x1,%cl
c0026c45:	74 07                	je     c0026c4e <__vprintf+0xaa>
    c->flags &= ~ZERO;
c0026c47:	83 e1 ef             	and    $0xffffffef,%ecx
c0026c4a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & PLUS)
c0026c4e:	8b 4c 24 40          	mov    0x40(%esp),%ecx
c0026c52:	f6 c1 02             	test   $0x2,%cl
c0026c55:	74 07                	je     c0026c5e <__vprintf+0xba>
    c->flags &= ~SPACE;
c0026c57:	83 e1 fb             	and    $0xfffffffb,%ecx
c0026c5a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  c->width = 0;
c0026c5e:	c7 44 24 44 00 00 00 	movl   $0x0,0x44(%esp)
c0026c65:	00 
  if (*format == '*')
c0026c66:	80 fb 2a             	cmp    $0x2a,%bl
c0026c69:	74 15                	je     c0026c80 <__vprintf+0xdc>
      for (; isdigit (*format); format++)
c0026c6b:	0f b6 00             	movzbl (%eax),%eax
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0026c6e:	0f be c8             	movsbl %al,%ecx
c0026c71:	83 e9 30             	sub    $0x30,%ecx
c0026c74:	ba 00 00 00 00       	mov    $0x0,%edx
c0026c79:	83 f9 09             	cmp    $0x9,%ecx
c0026c7c:	76 10                	jbe    c0026c8e <__vprintf+0xea>
c0026c7e:	eb 40                	jmp    c0026cc0 <__vprintf+0x11c>
      c->width = va_arg (*args, int);
c0026c80:	8b 45 00             	mov    0x0(%ebp),%eax
c0026c83:	89 44 24 44          	mov    %eax,0x44(%esp)
c0026c87:	8d 6d 04             	lea    0x4(%ebp),%ebp
      switch (*format++) 
c0026c8a:	89 d6                	mov    %edx,%esi
c0026c8c:	eb 1f                	jmp    c0026cad <__vprintf+0x109>
        c->width = c->width * 10 + *format - '0';
c0026c8e:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026c91:	0f be c0             	movsbl %al,%eax
c0026c94:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
      for (; isdigit (*format); format++)
c0026c98:	83 c6 01             	add    $0x1,%esi
c0026c9b:	0f b6 06             	movzbl (%esi),%eax
c0026c9e:	0f be c8             	movsbl %al,%ecx
c0026ca1:	83 e9 30             	sub    $0x30,%ecx
c0026ca4:	83 f9 09             	cmp    $0x9,%ecx
c0026ca7:	76 e5                	jbe    c0026c8e <__vprintf+0xea>
c0026ca9:	89 54 24 44          	mov    %edx,0x44(%esp)
  if (c->width < 0) 
c0026cad:	8b 44 24 44          	mov    0x44(%esp),%eax
c0026cb1:	85 c0                	test   %eax,%eax
c0026cb3:	79 0b                	jns    c0026cc0 <__vprintf+0x11c>
      c->width = -c->width;
c0026cb5:	f7 d8                	neg    %eax
c0026cb7:	89 44 24 44          	mov    %eax,0x44(%esp)
      c->flags |= MINUS;
c0026cbb:	83 4c 24 40 01       	orl    $0x1,0x40(%esp)
  c->precision = -1;
c0026cc0:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026cc7:	ff 
  if (*format == '.') 
c0026cc8:	80 3e 2e             	cmpb   $0x2e,(%esi)
c0026ccb:	0f 85 f0 04 00 00    	jne    c00271c1 <__vprintf+0x61d>
      if (*format == '*') 
c0026cd1:	80 7e 01 2a          	cmpb   $0x2a,0x1(%esi)
c0026cd5:	75 0f                	jne    c0026ce6 <__vprintf+0x142>
          format++;
c0026cd7:	83 c6 02             	add    $0x2,%esi
          c->precision = va_arg (*args, int);
c0026cda:	8b 45 00             	mov    0x0(%ebp),%eax
c0026cdd:	89 44 24 48          	mov    %eax,0x48(%esp)
c0026ce1:	8d 6d 04             	lea    0x4(%ebp),%ebp
c0026ce4:	eb 44                	jmp    c0026d2a <__vprintf+0x186>
      format++;
c0026ce6:	8d 56 01             	lea    0x1(%esi),%edx
          c->precision = 0;
c0026ce9:	c7 44 24 48 00 00 00 	movl   $0x0,0x48(%esp)
c0026cf0:	00 
          for (; isdigit (*format); format++)
c0026cf1:	0f b6 46 01          	movzbl 0x1(%esi),%eax
c0026cf5:	0f be c8             	movsbl %al,%ecx
c0026cf8:	83 e9 30             	sub    $0x30,%ecx
c0026cfb:	83 f9 09             	cmp    $0x9,%ecx
c0026cfe:	0f 87 c6 04 00 00    	ja     c00271ca <__vprintf+0x626>
c0026d04:	b9 00 00 00 00       	mov    $0x0,%ecx
            c->precision = c->precision * 10 + *format - '0';
c0026d09:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0026d0c:	0f be c0             	movsbl %al,%eax
c0026d0f:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
          for (; isdigit (*format); format++)
c0026d13:	83 c2 01             	add    $0x1,%edx
c0026d16:	0f b6 02             	movzbl (%edx),%eax
c0026d19:	0f be d8             	movsbl %al,%ebx
c0026d1c:	83 eb 30             	sub    $0x30,%ebx
c0026d1f:	83 fb 09             	cmp    $0x9,%ebx
c0026d22:	76 e5                	jbe    c0026d09 <__vprintf+0x165>
c0026d24:	89 4c 24 48          	mov    %ecx,0x48(%esp)
c0026d28:	89 d6                	mov    %edx,%esi
      if (c->precision < 0) 
c0026d2a:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0026d2f:	0f 89 97 04 00 00    	jns    c00271cc <__vprintf+0x628>
        c->precision = -1;
c0026d35:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026d3c:	ff 
c0026d3d:	e9 7f 04 00 00       	jmp    c00271c1 <__vprintf+0x61d>
  c->type = INT;
c0026d42:	c7 44 24 4c 03 00 00 	movl   $0x3,0x4c(%esp)
c0026d49:	00 
  switch (*format++) 
c0026d4a:	8d 5e 01             	lea    0x1(%esi),%ebx
c0026d4d:	0f b6 3e             	movzbl (%esi),%edi
c0026d50:	8d 57 98             	lea    -0x68(%edi),%edx
c0026d53:	80 fa 12             	cmp    $0x12,%dl
c0026d56:	77 62                	ja     c0026dba <__vprintf+0x216>
c0026d58:	0f b6 d2             	movzbl %dl,%edx
c0026d5b:	ff 24 95 b4 da 02 c0 	jmp    *-0x3ffd254c(,%edx,4)
      if (*format == 'h') 
c0026d62:	80 7e 01 68          	cmpb   $0x68,0x1(%esi)
c0026d66:	75 0d                	jne    c0026d75 <__vprintf+0x1d1>
          format++;
c0026d68:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = CHAR;
c0026d6b:	c7 44 24 4c 01 00 00 	movl   $0x1,0x4c(%esp)
c0026d72:	00 
c0026d73:	eb 47                	jmp    c0026dbc <__vprintf+0x218>
        c->type = SHORT;
c0026d75:	c7 44 24 4c 02 00 00 	movl   $0x2,0x4c(%esp)
c0026d7c:	00 
c0026d7d:	eb 3d                	jmp    c0026dbc <__vprintf+0x218>
      c->type = INTMAX;
c0026d7f:	c7 44 24 4c 04 00 00 	movl   $0x4,0x4c(%esp)
c0026d86:	00 
c0026d87:	eb 33                	jmp    c0026dbc <__vprintf+0x218>
      if (*format == 'l')
c0026d89:	80 7e 01 6c          	cmpb   $0x6c,0x1(%esi)
c0026d8d:	75 0d                	jne    c0026d9c <__vprintf+0x1f8>
          format++;
c0026d8f:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = LONGLONG;
c0026d92:	c7 44 24 4c 06 00 00 	movl   $0x6,0x4c(%esp)
c0026d99:	00 
c0026d9a:	eb 20                	jmp    c0026dbc <__vprintf+0x218>
        c->type = LONG;
c0026d9c:	c7 44 24 4c 05 00 00 	movl   $0x5,0x4c(%esp)
c0026da3:	00 
c0026da4:	eb 16                	jmp    c0026dbc <__vprintf+0x218>
      c->type = PTRDIFFT;
c0026da6:	c7 44 24 4c 07 00 00 	movl   $0x7,0x4c(%esp)
c0026dad:	00 
c0026dae:	eb 0c                	jmp    c0026dbc <__vprintf+0x218>
      c->type = SIZET;
c0026db0:	c7 44 24 4c 08 00 00 	movl   $0x8,0x4c(%esp)
c0026db7:	00 
c0026db8:	eb 02                	jmp    c0026dbc <__vprintf+0x218>
  switch (*format++) 
c0026dba:	89 f3                	mov    %esi,%ebx
      switch (*format) 
c0026dbc:	0f b6 0b             	movzbl (%ebx),%ecx
c0026dbf:	8d 51 bb             	lea    -0x45(%ecx),%edx
c0026dc2:	80 fa 33             	cmp    $0x33,%dl
c0026dc5:	0f 87 c2 03 00 00    	ja     c002718d <__vprintf+0x5e9>
c0026dcb:	0f b6 d2             	movzbl %dl,%edx
c0026dce:	ff 24 95 00 db 02 c0 	jmp    *-0x3ffd2500(,%edx,4)
            switch (c.type) 
c0026dd5:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026dda:	0f 87 c9 00 00 00    	ja     c0026ea9 <__vprintf+0x305>
c0026de0:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026de4:	ff 24 85 d0 db 02 c0 	jmp    *-0x3ffd2430(,%eax,4)
                value = (signed char) va_arg (args, int);
c0026deb:	0f be 75 00          	movsbl 0x0(%ebp),%esi
c0026def:	89 f0                	mov    %esi,%eax
c0026df1:	99                   	cltd   
c0026df2:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026df6:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026dfa:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dfd:	e9 cb 00 00 00       	jmp    c0026ecd <__vprintf+0x329>
                value = (short) va_arg (args, int);
c0026e02:	0f bf 75 00          	movswl 0x0(%ebp),%esi
c0026e06:	89 f0                	mov    %esi,%eax
c0026e08:	99                   	cltd   
c0026e09:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e0d:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e11:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e14:	e9 b4 00 00 00       	jmp    c0026ecd <__vprintf+0x329>
                value = va_arg (args, int);
c0026e19:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e1c:	89 f0                	mov    %esi,%eax
c0026e1e:	99                   	cltd   
c0026e1f:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e23:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e27:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e2a:	e9 9e 00 00 00       	jmp    c0026ecd <__vprintf+0x329>
                value = va_arg (args, intmax_t);
c0026e2f:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e32:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e35:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e39:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e3d:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e40:	e9 88 00 00 00       	jmp    c0026ecd <__vprintf+0x329>
                value = va_arg (args, long);
c0026e45:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e48:	89 f0                	mov    %esi,%eax
c0026e4a:	99                   	cltd   
c0026e4b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e4f:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e53:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e56:	eb 75                	jmp    c0026ecd <__vprintf+0x329>
                value = va_arg (args, long long);
c0026e58:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e5b:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e5e:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e62:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e66:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e69:	eb 62                	jmp    c0026ecd <__vprintf+0x329>
                value = va_arg (args, ptrdiff_t);
c0026e6b:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e6e:	89 f0                	mov    %esi,%eax
c0026e70:	99                   	cltd   
c0026e71:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e75:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e79:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e7c:	eb 4f                	jmp    c0026ecd <__vprintf+0x329>
                value = va_arg (args, size_t);
c0026e7e:	8d 45 04             	lea    0x4(%ebp),%eax
                if (value > SIZE_MAX / 2)
c0026e81:	8b 7d 00             	mov    0x0(%ebp),%edi
c0026e84:	bd 00 00 00 00       	mov    $0x0,%ebp
c0026e89:	89 fe                	mov    %edi,%esi
c0026e8b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e8f:	89 6c 24 1c          	mov    %ebp,0x1c(%esp)
                value = va_arg (args, size_t);
c0026e93:	89 c5                	mov    %eax,%ebp
                if (value > SIZE_MAX / 2)
c0026e95:	81 fe ff ff ff 7f    	cmp    $0x7fffffff,%esi
c0026e9b:	76 30                	jbe    c0026ecd <__vprintf+0x329>
                  value = value - SIZE_MAX - 1;
c0026e9d:	83 44 24 18 00       	addl   $0x0,0x18(%esp)
c0026ea2:	83 54 24 1c ff       	adcl   $0xffffffff,0x1c(%esp)
c0026ea7:	eb 24                	jmp    c0026ecd <__vprintf+0x329>
                NOT_REACHED ();
c0026ea9:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0026eb0:	c0 
c0026eb1:	c7 44 24 08 18 dc 02 	movl   $0xc002dc18,0x8(%esp)
c0026eb8:	c0 
c0026eb9:	c7 44 24 04 dc 00 00 	movl   $0xdc,0x4(%esp)
c0026ec0:	00 
c0026ec1:	c7 04 24 b9 f8 02 c0 	movl   $0xc002f8b9,(%esp)
c0026ec8:	e8 e6 1a 00 00       	call   c00289b3 <debug_panic>
            format_integer (value < 0 ? -value : value,
c0026ecd:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0026ed1:	c1 fa 1f             	sar    $0x1f,%edx
c0026ed4:	89 d7                	mov    %edx,%edi
c0026ed6:	33 7c 24 18          	xor    0x18(%esp),%edi
c0026eda:	89 7c 24 20          	mov    %edi,0x20(%esp)
c0026ede:	89 d7                	mov    %edx,%edi
c0026ee0:	33 7c 24 1c          	xor    0x1c(%esp),%edi
c0026ee4:	89 7c 24 24          	mov    %edi,0x24(%esp)
c0026ee8:	8b 74 24 20          	mov    0x20(%esp),%esi
c0026eec:	8b 7c 24 24          	mov    0x24(%esp),%edi
c0026ef0:	29 d6                	sub    %edx,%esi
c0026ef2:	19 d7                	sbb    %edx,%edi
c0026ef4:	89 f0                	mov    %esi,%eax
c0026ef6:	89 fa                	mov    %edi,%edx
c0026ef8:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0026efc:	89 7c 24 10          	mov    %edi,0x10(%esp)
c0026f00:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0026f04:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0026f08:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0026f0c:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0026f10:	c7 44 24 04 54 dc 02 	movl   $0xc002dc54,0x4(%esp)
c0026f17:	c0 
c0026f18:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0026f1c:	c1 e9 1f             	shr    $0x1f,%ecx
c0026f1f:	89 0c 24             	mov    %ecx,(%esp)
c0026f22:	b9 01 00 00 00       	mov    $0x1,%ecx
c0026f27:	e8 82 f8 ff ff       	call   c00267ae <format_integer>
          break;
c0026f2c:	e9 7f 02 00 00       	jmp    c00271b0 <__vprintf+0x60c>
            switch (c.type) 
c0026f31:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026f36:	0f 87 b7 00 00 00    	ja     c0026ff3 <__vprintf+0x44f>
c0026f3c:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026f40:	ff 24 85 f4 db 02 c0 	jmp    *-0x3ffd240c(,%eax,4)
                value = (unsigned char) va_arg (args, unsigned);
c0026f47:	0f b6 45 00          	movzbl 0x0(%ebp),%eax
c0026f4b:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f4f:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f56:	00 
c0026f57:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f5a:	e9 b8 00 00 00       	jmp    c0027017 <__vprintf+0x473>
                value = (unsigned short) va_arg (args, unsigned);
c0026f5f:	0f b7 45 00          	movzwl 0x0(%ebp),%eax
c0026f63:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f67:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f6e:	00 
c0026f6f:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f72:	e9 a0 00 00 00       	jmp    c0027017 <__vprintf+0x473>
                value = va_arg (args, unsigned);
c0026f77:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f7a:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f7f:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f83:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f87:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f8a:	e9 88 00 00 00       	jmp    c0027017 <__vprintf+0x473>
                value = va_arg (args, uintmax_t);
c0026f8f:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f92:	8b 55 04             	mov    0x4(%ebp),%edx
c0026f95:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f99:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f9d:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026fa0:	eb 75                	jmp    c0027017 <__vprintf+0x473>
                value = va_arg (args, unsigned long);
c0026fa2:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fa5:	ba 00 00 00 00       	mov    $0x0,%edx
c0026faa:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fae:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fb2:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fb5:	eb 60                	jmp    c0027017 <__vprintf+0x473>
                value = va_arg (args, unsigned long long);
c0026fb7:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fba:	8b 55 04             	mov    0x4(%ebp),%edx
c0026fbd:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fc1:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fc5:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026fc8:	eb 4d                	jmp    c0027017 <__vprintf+0x473>
                value &= ((uintmax_t) PTRDIFF_MAX << 1) | 1;
c0026fca:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fcd:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fd1:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026fd8:	00 
                value = va_arg (args, ptrdiff_t);
c0026fd9:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fdc:	eb 39                	jmp    c0027017 <__vprintf+0x473>
                value = va_arg (args, size_t);
c0026fde:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fe1:	ba 00 00 00 00       	mov    $0x0,%edx
c0026fe6:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026fea:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fee:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026ff1:	eb 24                	jmp    c0027017 <__vprintf+0x473>
                NOT_REACHED ();
c0026ff3:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c0026ffa:	c0 
c0026ffb:	c7 44 24 08 18 dc 02 	movl   $0xc002dc18,0x8(%esp)
c0027002:	c0 
c0027003:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c002700a:	00 
c002700b:	c7 04 24 b9 f8 02 c0 	movl   $0xc002f8b9,(%esp)
c0027012:	e8 9c 19 00 00       	call   c00289b3 <debug_panic>
            switch (*format) 
c0027017:	80 f9 6f             	cmp    $0x6f,%cl
c002701a:	74 4d                	je     c0027069 <__vprintf+0x4c5>
c002701c:	80 f9 6f             	cmp    $0x6f,%cl
c002701f:	7f 07                	jg     c0027028 <__vprintf+0x484>
c0027021:	80 f9 58             	cmp    $0x58,%cl
c0027024:	74 18                	je     c002703e <__vprintf+0x49a>
c0027026:	eb 1d                	jmp    c0027045 <__vprintf+0x4a1>
c0027028:	80 f9 75             	cmp    $0x75,%cl
c002702b:	90                   	nop
c002702c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027030:	74 3e                	je     c0027070 <__vprintf+0x4cc>
c0027032:	80 f9 78             	cmp    $0x78,%cl
c0027035:	75 0e                	jne    c0027045 <__vprintf+0x4a1>
              case 'x': b = &base_x; break;
c0027037:	b8 34 dc 02 c0       	mov    $0xc002dc34,%eax
c002703c:	eb 37                	jmp    c0027075 <__vprintf+0x4d1>
              case 'X': b = &base_X; break;
c002703e:	b8 24 dc 02 c0       	mov    $0xc002dc24,%eax
c0027043:	eb 30                	jmp    c0027075 <__vprintf+0x4d1>
              default: NOT_REACHED ();
c0027045:	c7 44 24 0c 8c e6 02 	movl   $0xc002e68c,0xc(%esp)
c002704c:	c0 
c002704d:	c7 44 24 08 18 dc 02 	movl   $0xc002dc18,0x8(%esp)
c0027054:	c0 
c0027055:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
c002705c:	00 
c002705d:	c7 04 24 b9 f8 02 c0 	movl   $0xc002f8b9,(%esp)
c0027064:	e8 4a 19 00 00       	call   c00289b3 <debug_panic>
              case 'o': b = &base_o; break;
c0027069:	b8 44 dc 02 c0       	mov    $0xc002dc44,%eax
c002706e:	eb 05                	jmp    c0027075 <__vprintf+0x4d1>
              case 'u': b = &base_d; break;
c0027070:	b8 54 dc 02 c0       	mov    $0xc002dc54,%eax
            format_integer (value, false, false, b, &c, output, aux);
c0027075:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027079:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002707d:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0027081:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027085:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027089:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002708d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027091:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0027098:	b9 00 00 00 00       	mov    $0x0,%ecx
c002709d:	8b 44 24 28          	mov    0x28(%esp),%eax
c00270a1:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c00270a5:	e8 04 f7 ff ff       	call   c00267ae <format_integer>
          break;
c00270aa:	e9 01 01 00 00       	jmp    c00271b0 <__vprintf+0x60c>
            char ch = va_arg (args, int);
c00270af:	8d 75 04             	lea    0x4(%ebp),%esi
c00270b2:	8b 45 00             	mov    0x0(%ebp),%eax
c00270b5:	88 44 24 3f          	mov    %al,0x3f(%esp)
            format_string (&ch, 1, &c, output, aux);
c00270b9:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c00270bd:	89 44 24 04          	mov    %eax,0x4(%esp)
c00270c1:	8b 44 24 78          	mov    0x78(%esp),%eax
c00270c5:	89 04 24             	mov    %eax,(%esp)
c00270c8:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c00270cc:	ba 01 00 00 00       	mov    $0x1,%edx
c00270d1:	8d 44 24 3f          	lea    0x3f(%esp),%eax
c00270d5:	e8 00 fa ff ff       	call   c0026ada <format_string>
            char ch = va_arg (args, int);
c00270da:	89 f5                	mov    %esi,%ebp
          break;
c00270dc:	e9 cf 00 00 00       	jmp    c00271b0 <__vprintf+0x60c>
            const char *s = va_arg (args, char *);
c00270e1:	8d 75 04             	lea    0x4(%ebp),%esi
c00270e4:	8b 7d 00             	mov    0x0(%ebp),%edi
              s = "(null)";
c00270e7:	85 ff                	test   %edi,%edi
c00270e9:	ba b2 f8 02 c0       	mov    $0xc002f8b2,%edx
c00270ee:	0f 44 fa             	cmove  %edx,%edi
            format_string (s, strnlen (s, c.precision), &c, output, aux);
c00270f1:	89 44 24 04          	mov    %eax,0x4(%esp)
c00270f5:	89 3c 24             	mov    %edi,(%esp)
c00270f8:	e8 9d 0e 00 00       	call   c0027f9a <strnlen>
c00270fd:	8b 4c 24 7c          	mov    0x7c(%esp),%ecx
c0027101:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0027105:	8b 4c 24 78          	mov    0x78(%esp),%ecx
c0027109:	89 0c 24             	mov    %ecx,(%esp)
c002710c:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c0027110:	89 c2                	mov    %eax,%edx
c0027112:	89 f8                	mov    %edi,%eax
c0027114:	e8 c1 f9 ff ff       	call   c0026ada <format_string>
            const char *s = va_arg (args, char *);
c0027119:	89 f5                	mov    %esi,%ebp
          break;
c002711b:	e9 90 00 00 00       	jmp    c00271b0 <__vprintf+0x60c>
            void *p = va_arg (args, void *);
c0027120:	8d 75 04             	lea    0x4(%ebp),%esi
c0027123:	8b 45 00             	mov    0x0(%ebp),%eax
            c.flags = POUND;
c0027126:	c7 44 24 40 08 00 00 	movl   $0x8,0x40(%esp)
c002712d:	00 
            format_integer ((uintptr_t) p, false, false,
c002712e:	ba 00 00 00 00       	mov    $0x0,%edx
c0027133:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027137:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002713b:	8b 7c 24 78          	mov    0x78(%esp),%edi
c002713f:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027143:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027147:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002714b:	c7 44 24 04 34 dc 02 	movl   $0xc002dc34,0x4(%esp)
c0027152:	c0 
c0027153:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002715a:	b9 00 00 00 00       	mov    $0x0,%ecx
c002715f:	e8 4a f6 ff ff       	call   c00267ae <format_integer>
            void *p = va_arg (args, void *);
c0027164:	89 f5                	mov    %esi,%ebp
          break;
c0027166:	eb 48                	jmp    c00271b0 <__vprintf+0x60c>
          __printf ("<<no %%%c in kernel>>", output, aux, *format);
c0027168:	0f be c9             	movsbl %cl,%ecx
c002716b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002716f:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027173:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027177:	8b 44 24 78          	mov    0x78(%esp),%eax
c002717b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002717f:	c7 04 24 cb f8 02 c0 	movl   $0xc002f8cb,(%esp)
c0027186:	e8 ee f9 ff ff       	call   c0026b79 <__printf>
          break;
c002718b:	eb 23                	jmp    c00271b0 <__vprintf+0x60c>
          __printf ("<<no %%%c conversion>>", output, aux, *format);
c002718d:	0f be c9             	movsbl %cl,%ecx
c0027190:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0027194:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027198:	89 44 24 08          	mov    %eax,0x8(%esp)
c002719c:	8b 44 24 78          	mov    0x78(%esp),%eax
c00271a0:	89 44 24 04          	mov    %eax,0x4(%esp)
c00271a4:	c7 04 24 e1 f8 02 c0 	movl   $0xc002f8e1,(%esp)
c00271ab:	e8 c9 f9 ff ff       	call   c0026b79 <__printf>
  for (; *format != '\0'; format++)
c00271b0:	8d 7b 01             	lea    0x1(%ebx),%edi
c00271b3:	0f b6 43 01          	movzbl 0x1(%ebx),%eax
c00271b7:	84 c0                	test   %al,%al
c00271b9:	0f 85 ff f9 ff ff    	jne    c0026bbe <__vprintf+0x1a>
c00271bf:	eb 19                	jmp    c00271da <__vprintf+0x636>
  if (c->precision >= 0)
c00271c1:	8b 44 24 48          	mov    0x48(%esp),%eax
c00271c5:	e9 78 fb ff ff       	jmp    c0026d42 <__vprintf+0x19e>
      format++;
c00271ca:	89 d6                	mov    %edx,%esi
  if (c->precision >= 0)
c00271cc:	8b 44 24 48          	mov    0x48(%esp),%eax
    c->flags &= ~ZERO;
c00271d0:	83 64 24 40 ef       	andl   $0xffffffef,0x40(%esp)
c00271d5:	e9 68 fb ff ff       	jmp    c0026d42 <__vprintf+0x19e>
}
c00271da:	83 c4 5c             	add    $0x5c,%esp
c00271dd:	5b                   	pop    %ebx
c00271de:	5e                   	pop    %esi
c00271df:	5f                   	pop    %edi
c00271e0:	5d                   	pop    %ebp
c00271e1:	c3                   	ret    

c00271e2 <vsnprintf>:
{
c00271e2:	53                   	push   %ebx
c00271e3:	83 ec 28             	sub    $0x28,%esp
c00271e6:	8b 44 24 34          	mov    0x34(%esp),%eax
c00271ea:	8b 54 24 38          	mov    0x38(%esp),%edx
c00271ee:	8b 4c 24 3c          	mov    0x3c(%esp),%ecx
  aux.p = buffer;
c00271f2:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00271f6:	89 5c 24 14          	mov    %ebx,0x14(%esp)
  aux.length = 0;
c00271fa:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c0027201:	00 
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c0027202:	85 c0                	test   %eax,%eax
c0027204:	74 2c                	je     c0027232 <vsnprintf+0x50>
c0027206:	83 e8 01             	sub    $0x1,%eax
c0027209:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  __vprintf (format, args, vsnprintf_helper, &aux);
c002720d:	8d 44 24 14          	lea    0x14(%esp),%eax
c0027211:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027215:	c7 44 24 08 60 67 02 	movl   $0xc0026760,0x8(%esp)
c002721c:	c0 
c002721d:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0027221:	89 14 24             	mov    %edx,(%esp)
c0027224:	e8 7b f9 ff ff       	call   c0026ba4 <__vprintf>
    *aux.p = '\0';
c0027229:	8b 44 24 14          	mov    0x14(%esp),%eax
c002722d:	c6 00 00             	movb   $0x0,(%eax)
c0027230:	eb 24                	jmp    c0027256 <vsnprintf+0x74>
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c0027232:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c0027239:	00 
  __vprintf (format, args, vsnprintf_helper, &aux);
c002723a:	8d 44 24 14          	lea    0x14(%esp),%eax
c002723e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027242:	c7 44 24 08 60 67 02 	movl   $0xc0026760,0x8(%esp)
c0027249:	c0 
c002724a:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002724e:	89 14 24             	mov    %edx,(%esp)
c0027251:	e8 4e f9 ff ff       	call   c0026ba4 <__vprintf>
  return aux.length;
c0027256:	8b 44 24 18          	mov    0x18(%esp),%eax
}
c002725a:	83 c4 28             	add    $0x28,%esp
c002725d:	5b                   	pop    %ebx
c002725e:	c3                   	ret    

c002725f <snprintf>:
{
c002725f:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0027262:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  retval = vsnprintf (buffer, buf_size, format, args);
c0027266:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002726a:	8b 44 24 28          	mov    0x28(%esp),%eax
c002726e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027272:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027276:	89 44 24 04          	mov    %eax,0x4(%esp)
c002727a:	8b 44 24 20          	mov    0x20(%esp),%eax
c002727e:	89 04 24             	mov    %eax,(%esp)
c0027281:	e8 5c ff ff ff       	call   c00271e2 <vsnprintf>
}
c0027286:	83 c4 1c             	add    $0x1c,%esp
c0027289:	c3                   	ret    

c002728a <hex_dump>:
   starting at OFS for the first byte in BUF.  If ASCII is true
   then the corresponding ASCII characters are also rendered
   alongside. */   
void
hex_dump (uintptr_t ofs, const void *buf_, size_t size, bool ascii)
{
c002728a:	55                   	push   %ebp
c002728b:	57                   	push   %edi
c002728c:	56                   	push   %esi
c002728d:	53                   	push   %ebx
c002728e:	83 ec 2c             	sub    $0x2c,%esp
c0027291:	0f b6 44 24 4c       	movzbl 0x4c(%esp),%eax
c0027296:	88 44 24 1f          	mov    %al,0x1f(%esp)
  const uint8_t *buf = buf_;
  const size_t per_line = 16; /* Maximum bytes per line. */

  while (size > 0)
c002729a:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c002729f:	0f 84 7c 01 00 00    	je     c0027421 <hex_dump+0x197>
    {
      size_t start, end, n;
      size_t i;
      
      /* Number of bytes on this line. */
      start = ofs % per_line;
c00272a5:	8b 7c 24 40          	mov    0x40(%esp),%edi
c00272a9:	83 e7 0f             	and    $0xf,%edi
      end = per_line;
      if (end - start > size)
c00272ac:	b8 10 00 00 00       	mov    $0x10,%eax
c00272b1:	29 f8                	sub    %edi,%eax
        end = start + size;
c00272b3:	89 fe                	mov    %edi,%esi
c00272b5:	03 74 24 48          	add    0x48(%esp),%esi
c00272b9:	3b 44 24 48          	cmp    0x48(%esp),%eax
c00272bd:	b8 10 00 00 00       	mov    $0x10,%eax
c00272c2:	0f 46 f0             	cmovbe %eax,%esi
      n = end - start;
c00272c5:	89 f0                	mov    %esi,%eax
c00272c7:	29 f8                	sub    %edi,%eax
c00272c9:	89 44 24 18          	mov    %eax,0x18(%esp)

      /* Print line. */
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
c00272cd:	8b 44 24 40          	mov    0x40(%esp),%eax
c00272d1:	83 e0 f0             	and    $0xfffffff0,%eax
c00272d4:	89 44 24 04          	mov    %eax,0x4(%esp)
c00272d8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00272df:	00 
c00272e0:	c7 04 24 f8 f8 02 c0 	movl   $0xc002f8f8,(%esp)
c00272e7:	e8 72 f8 ff ff       	call   c0026b5e <printf>
      for (i = 0; i < start; i++)
c00272ec:	85 ff                	test   %edi,%edi
c00272ee:	74 1a                	je     c002730a <hex_dump+0x80>
c00272f0:	bb 00 00 00 00       	mov    $0x0,%ebx
        printf ("   ");
c00272f5:	c7 04 24 00 f9 02 c0 	movl   $0xc002f900,(%esp)
c00272fc:	e8 5d f8 ff ff       	call   c0026b5e <printf>
      for (i = 0; i < start; i++)
c0027301:	83 c3 01             	add    $0x1,%ebx
c0027304:	39 fb                	cmp    %edi,%ebx
c0027306:	75 ed                	jne    c00272f5 <hex_dump+0x6b>
c0027308:	eb 08                	jmp    c0027312 <hex_dump+0x88>
c002730a:	89 fb                	mov    %edi,%ebx
c002730c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027310:	eb 02                	jmp    c0027314 <hex_dump+0x8a>
c0027312:	89 fb                	mov    %edi,%ebx
      for (; i < end; i++) 
c0027314:	39 de                	cmp    %ebx,%esi
c0027316:	76 38                	jbe    c0027350 <hex_dump+0xc6>
c0027318:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c002731c:	29 fd                	sub    %edi,%ebp
        printf ("%02hhx%c",
c002731e:	83 fb 07             	cmp    $0x7,%ebx
c0027321:	b8 2d 00 00 00       	mov    $0x2d,%eax
c0027326:	b9 20 00 00 00       	mov    $0x20,%ecx
c002732b:	0f 45 c1             	cmovne %ecx,%eax
c002732e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027332:	0f b6 44 1d 00       	movzbl 0x0(%ebp,%ebx,1),%eax
c0027337:	89 44 24 04          	mov    %eax,0x4(%esp)
c002733b:	c7 04 24 04 f9 02 c0 	movl   $0xc002f904,(%esp)
c0027342:	e8 17 f8 ff ff       	call   c0026b5e <printf>
      for (; i < end; i++) 
c0027347:	83 c3 01             	add    $0x1,%ebx
c002734a:	39 de                	cmp    %ebx,%esi
c002734c:	77 d0                	ja     c002731e <hex_dump+0x94>
c002734e:	89 f3                	mov    %esi,%ebx
                buf[i - start], i == per_line / 2 - 1? '-' : ' ');
      if (ascii) 
c0027350:	80 7c 24 1f 00       	cmpb   $0x0,0x1f(%esp)
c0027355:	0f 84 a4 00 00 00    	je     c00273ff <hex_dump+0x175>
        {
          for (; i < per_line; i++)
c002735b:	83 fb 0f             	cmp    $0xf,%ebx
c002735e:	77 14                	ja     c0027374 <hex_dump+0xea>
            printf ("   ");
c0027360:	c7 04 24 00 f9 02 c0 	movl   $0xc002f900,(%esp)
c0027367:	e8 f2 f7 ff ff       	call   c0026b5e <printf>
          for (; i < per_line; i++)
c002736c:	83 c3 01             	add    $0x1,%ebx
c002736f:	83 fb 10             	cmp    $0x10,%ebx
c0027372:	75 ec                	jne    c0027360 <hex_dump+0xd6>
          printf ("|");
c0027374:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c002737b:	e8 cc 33 00 00       	call   c002a74c <putchar>
          for (i = 0; i < start; i++)
c0027380:	85 ff                	test   %edi,%edi
c0027382:	74 1a                	je     c002739e <hex_dump+0x114>
c0027384:	bb 00 00 00 00       	mov    $0x0,%ebx
            printf (" ");
c0027389:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0027390:	e8 b7 33 00 00       	call   c002a74c <putchar>
          for (i = 0; i < start; i++)
c0027395:	83 c3 01             	add    $0x1,%ebx
c0027398:	39 fb                	cmp    %edi,%ebx
c002739a:	75 ed                	jne    c0027389 <hex_dump+0xff>
c002739c:	eb 04                	jmp    c00273a2 <hex_dump+0x118>
c002739e:	89 fb                	mov    %edi,%ebx
c00273a0:	eb 02                	jmp    c00273a4 <hex_dump+0x11a>
c00273a2:	89 fb                	mov    %edi,%ebx
          for (; i < end; i++)
c00273a4:	39 de                	cmp    %ebx,%esi
c00273a6:	76 30                	jbe    c00273d8 <hex_dump+0x14e>
c00273a8:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00273ac:	29 fd                	sub    %edi,%ebp
            printf ("%c",
c00273ae:	bf 2e 00 00 00       	mov    $0x2e,%edi
                    isprint (buf[i - start]) ? buf[i - start] : '.');
c00273b3:	0f b6 54 1d 00       	movzbl 0x0(%ebp,%ebx,1),%edx
static inline int isprint (int c) { return c >= 32 && c < 127; }
c00273b8:	0f b6 c2             	movzbl %dl,%eax
            printf ("%c",
c00273bb:	8d 40 e0             	lea    -0x20(%eax),%eax
c00273be:	0f b6 d2             	movzbl %dl,%edx
c00273c1:	83 f8 5e             	cmp    $0x5e,%eax
c00273c4:	0f 47 d7             	cmova  %edi,%edx
c00273c7:	89 14 24             	mov    %edx,(%esp)
c00273ca:	e8 7d 33 00 00       	call   c002a74c <putchar>
          for (; i < end; i++)
c00273cf:	83 c3 01             	add    $0x1,%ebx
c00273d2:	39 de                	cmp    %ebx,%esi
c00273d4:	77 dd                	ja     c00273b3 <hex_dump+0x129>
c00273d6:	eb 02                	jmp    c00273da <hex_dump+0x150>
c00273d8:	89 de                	mov    %ebx,%esi
          for (; i < per_line; i++)
c00273da:	83 fe 0f             	cmp    $0xf,%esi
c00273dd:	77 14                	ja     c00273f3 <hex_dump+0x169>
            printf (" ");
c00273df:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c00273e6:	e8 61 33 00 00       	call   c002a74c <putchar>
          for (; i < per_line; i++)
c00273eb:	83 c6 01             	add    $0x1,%esi
c00273ee:	83 fe 10             	cmp    $0x10,%esi
c00273f1:	75 ec                	jne    c00273df <hex_dump+0x155>
          printf ("|");
c00273f3:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c00273fa:	e8 4d 33 00 00       	call   c002a74c <putchar>
        }
      printf ("\n");
c00273ff:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0027406:	e8 41 33 00 00       	call   c002a74c <putchar>

      ofs += n;
c002740b:	8b 44 24 18          	mov    0x18(%esp),%eax
c002740f:	01 44 24 40          	add    %eax,0x40(%esp)
      buf += n;
c0027413:	01 44 24 44          	add    %eax,0x44(%esp)
  while (size > 0)
c0027417:	29 44 24 48          	sub    %eax,0x48(%esp)
c002741b:	0f 85 84 fe ff ff    	jne    c00272a5 <hex_dump+0x1b>
      size -= n;
    }
}
c0027421:	83 c4 2c             	add    $0x2c,%esp
c0027424:	5b                   	pop    %ebx
c0027425:	5e                   	pop    %esi
c0027426:	5f                   	pop    %edi
c0027427:	5d                   	pop    %ebp
c0027428:	c3                   	ret    

c0027429 <print_human_readable_size>:

/* Prints SIZE, which represents a number of bytes, in a
   human-readable format, e.g. "256 kB". */
void
print_human_readable_size (uint64_t size) 
{
c0027429:	56                   	push   %esi
c002742a:	53                   	push   %ebx
c002742b:	83 ec 14             	sub    $0x14,%esp
c002742e:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c0027432:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (size == 1)
c0027436:	89 c8                	mov    %ecx,%eax
c0027438:	83 f0 01             	xor    $0x1,%eax
c002743b:	09 d8                	or     %ebx,%eax
c002743d:	74 22                	je     c0027461 <print_human_readable_size+0x38>
  else 
    {
      static const char *factors[] = {"bytes", "kB", "MB", "GB", "TB", NULL};
      const char **fp;

      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002743f:	83 fb 00             	cmp    $0x0,%ebx
c0027442:	77 0d                	ja     c0027451 <print_human_readable_size+0x28>
c0027444:	be 7c 5a 03 c0       	mov    $0xc0035a7c,%esi
c0027449:	81 f9 ff 03 00 00    	cmp    $0x3ff,%ecx
c002744f:	76 42                	jbe    c0027493 <print_human_readable_size+0x6a>
c0027451:	be 7c 5a 03 c0       	mov    $0xc0035a7c,%esi
c0027456:	83 3d 80 5a 03 c0 00 	cmpl   $0x0,0xc0035a80
c002745d:	75 10                	jne    c002746f <print_human_readable_size+0x46>
c002745f:	eb 32                	jmp    c0027493 <print_human_readable_size+0x6a>
    printf ("1 byte");
c0027461:	c7 04 24 0d f9 02 c0 	movl   $0xc002f90d,(%esp)
c0027468:	e8 f1 f6 ff ff       	call   c0026b5e <printf>
c002746d:	eb 3e                	jmp    c00274ad <print_human_readable_size+0x84>
        size /= 1024;
c002746f:	89 c8                	mov    %ecx,%eax
c0027471:	89 da                	mov    %ebx,%edx
c0027473:	0f ac d8 0a          	shrd   $0xa,%ebx,%eax
c0027477:	c1 ea 0a             	shr    $0xa,%edx
c002747a:	89 c1                	mov    %eax,%ecx
c002747c:	89 d3                	mov    %edx,%ebx
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002747e:	83 c6 04             	add    $0x4,%esi
c0027481:	83 fa 00             	cmp    $0x0,%edx
c0027484:	77 07                	ja     c002748d <print_human_readable_size+0x64>
c0027486:	3d ff 03 00 00       	cmp    $0x3ff,%eax
c002748b:	76 06                	jbe    c0027493 <print_human_readable_size+0x6a>
c002748d:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0027491:	75 dc                	jne    c002746f <print_human_readable_size+0x46>
      printf ("%"PRIu64" %s", size, *fp);
c0027493:	8b 06                	mov    (%esi),%eax
c0027495:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027499:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002749d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00274a1:	c7 04 24 14 f9 02 c0 	movl   $0xc002f914,(%esp)
c00274a8:	e8 b1 f6 ff ff       	call   c0026b5e <printf>
    }
}
c00274ad:	83 c4 14             	add    $0x14,%esp
c00274b0:	5b                   	pop    %ebx
c00274b1:	5e                   	pop    %esi
c00274b2:	c3                   	ret    
c00274b3:	90                   	nop
c00274b4:	90                   	nop
c00274b5:	90                   	nop
c00274b6:	90                   	nop
c00274b7:	90                   	nop
c00274b8:	90                   	nop
c00274b9:	90                   	nop
c00274ba:	90                   	nop
c00274bb:	90                   	nop
c00274bc:	90                   	nop
c00274bd:	90                   	nop
c00274be:	90                   	nop
c00274bf:	90                   	nop

c00274c0 <compare_thunk>:
}

/* Compares A and B by calling the AUX function. */
static int
compare_thunk (const void *a, const void *b, void *aux) 
{
c00274c0:	83 ec 1c             	sub    $0x1c,%esp
  int (**compare) (const void *, const void *) = aux;
  return (*compare) (a, b);
c00274c3:	8b 44 24 24          	mov    0x24(%esp),%eax
c00274c7:	89 44 24 04          	mov    %eax,0x4(%esp)
c00274cb:	8b 44 24 20          	mov    0x20(%esp),%eax
c00274cf:	89 04 24             	mov    %eax,(%esp)
c00274d2:	8b 44 24 28          	mov    0x28(%esp),%eax
c00274d6:	ff 10                	call   *(%eax)
}
c00274d8:	83 c4 1c             	add    $0x1c,%esp
c00274db:	c3                   	ret    

c00274dc <do_swap>:

/* Swaps elements with 1-based indexes A_IDX and B_IDX in ARRAY
   with elements of SIZE bytes each. */
static void
do_swap (unsigned char *array, size_t a_idx, size_t b_idx, size_t size)
{
c00274dc:	57                   	push   %edi
c00274dd:	56                   	push   %esi
c00274de:	53                   	push   %ebx
c00274df:	8b 7c 24 10          	mov    0x10(%esp),%edi
  unsigned char *a = array + (a_idx - 1) * size;
c00274e3:	8d 5a ff             	lea    -0x1(%edx),%ebx
c00274e6:	0f af df             	imul   %edi,%ebx
c00274e9:	01 c3                	add    %eax,%ebx
  unsigned char *b = array + (b_idx - 1) * size;
c00274eb:	8d 51 ff             	lea    -0x1(%ecx),%edx
c00274ee:	0f af d7             	imul   %edi,%edx
c00274f1:	01 d0                	add    %edx,%eax
  size_t i;

  for (i = 0; i < size; i++)
c00274f3:	85 ff                	test   %edi,%edi
c00274f5:	74 1c                	je     c0027513 <do_swap+0x37>
c00274f7:	ba 00 00 00 00       	mov    $0x0,%edx
    {
      unsigned char t = a[i];
c00274fc:	0f b6 34 13          	movzbl (%ebx,%edx,1),%esi
      a[i] = b[i];
c0027500:	0f b6 0c 10          	movzbl (%eax,%edx,1),%ecx
c0027504:	88 0c 13             	mov    %cl,(%ebx,%edx,1)
      b[i] = t;
c0027507:	89 f1                	mov    %esi,%ecx
c0027509:	88 0c 10             	mov    %cl,(%eax,%edx,1)
  for (i = 0; i < size; i++)
c002750c:	83 c2 01             	add    $0x1,%edx
c002750f:	39 fa                	cmp    %edi,%edx
c0027511:	75 e9                	jne    c00274fc <do_swap+0x20>
    }
}
c0027513:	5b                   	pop    %ebx
c0027514:	5e                   	pop    %esi
c0027515:	5f                   	pop    %edi
c0027516:	c3                   	ret    

c0027517 <heapify>:
   elements, passing AUX as auxiliary data. */
static void
heapify (unsigned char *array, size_t i, size_t cnt, size_t size,
         int (*compare) (const void *, const void *, void *aux),
         void *aux) 
{
c0027517:	55                   	push   %ebp
c0027518:	57                   	push   %edi
c0027519:	56                   	push   %esi
c002751a:	53                   	push   %ebx
c002751b:	83 ec 2c             	sub    $0x2c,%esp
c002751e:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0027522:	89 d3                	mov    %edx,%ebx
c0027524:	89 4c 24 18          	mov    %ecx,0x18(%esp)
  for (;;) 
    {
      /* Set `max' to the index of the largest element among I
         and its children (if any). */
      size_t left = 2 * i;
c0027528:	8d 3c 1b             	lea    (%ebx,%ebx,1),%edi
      size_t right = 2 * i + 1;
c002752b:	8d 6f 01             	lea    0x1(%edi),%ebp
      size_t max = i;
c002752e:	89 de                	mov    %ebx,%esi
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027530:	3b 7c 24 18          	cmp    0x18(%esp),%edi
c0027534:	77 30                	ja     c0027566 <heapify+0x4f>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c0027536:	8b 44 24 48          	mov    0x48(%esp),%eax
c002753a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002753e:	8d 43 ff             	lea    -0x1(%ebx),%eax
c0027541:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027546:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002754a:	01 d0                	add    %edx,%eax
c002754c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027550:	8d 47 ff             	lea    -0x1(%edi),%eax
c0027553:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027558:	01 d0                	add    %edx,%eax
c002755a:	89 04 24             	mov    %eax,(%esp)
c002755d:	ff 54 24 44          	call   *0x44(%esp)
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027561:	85 c0                	test   %eax,%eax
      size_t max = i;
c0027563:	0f 4f f7             	cmovg  %edi,%esi
        max = left;
      if (right <= cnt
c0027566:	3b 6c 24 18          	cmp    0x18(%esp),%ebp
c002756a:	77 2d                	ja     c0027599 <heapify+0x82>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c002756c:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027570:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027574:	8d 46 ff             	lea    -0x1(%esi),%eax
c0027577:	0f af 44 24 40       	imul   0x40(%esp),%eax
c002757c:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0027580:	01 c8                	add    %ecx,%eax
c0027582:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027586:	0f af 7c 24 40       	imul   0x40(%esp),%edi
c002758b:	01 cf                	add    %ecx,%edi
c002758d:	89 3c 24             	mov    %edi,(%esp)
c0027590:	ff 54 24 44          	call   *0x44(%esp)
          && do_compare (array, right, max, size, compare, aux) > 0) 
c0027594:	85 c0                	test   %eax,%eax
        max = right;
c0027596:	0f 4f f5             	cmovg  %ebp,%esi

      /* If the maximum value is already in element I, we're
         done. */
      if (max == i)
c0027599:	39 de                	cmp    %ebx,%esi
c002759b:	74 1b                	je     c00275b8 <heapify+0xa1>
        break;

      /* Swap and continue down the heap. */
      do_swap (array, i, max, size);
c002759d:	8b 44 24 40          	mov    0x40(%esp),%eax
c00275a1:	89 04 24             	mov    %eax,(%esp)
c00275a4:	89 f1                	mov    %esi,%ecx
c00275a6:	89 da                	mov    %ebx,%edx
c00275a8:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c00275ac:	e8 2b ff ff ff       	call   c00274dc <do_swap>
      i = max;
c00275b1:	89 f3                	mov    %esi,%ebx
    }
c00275b3:	e9 70 ff ff ff       	jmp    c0027528 <heapify+0x11>
}
c00275b8:	83 c4 2c             	add    $0x2c,%esp
c00275bb:	5b                   	pop    %ebx
c00275bc:	5e                   	pop    %esi
c00275bd:	5f                   	pop    %edi
c00275be:	5d                   	pop    %ebp
c00275bf:	c3                   	ret    

c00275c0 <atoi>:
{
c00275c0:	57                   	push   %edi
c00275c1:	56                   	push   %esi
c00275c2:	53                   	push   %ebx
c00275c3:	83 ec 20             	sub    $0x20,%esp
c00275c6:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c00275ca:	85 d2                	test   %edx,%edx
c00275cc:	75 2f                	jne    c00275fd <atoi+0x3d>
c00275ce:	c7 44 24 10 5a fa 02 	movl   $0xc002fa5a,0x10(%esp)
c00275d5:	c0 
c00275d6:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00275dd:	c0 
c00275de:	c7 44 24 08 69 dc 02 	movl   $0xc002dc69,0x8(%esp)
c00275e5:	c0 
c00275e6:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
c00275ed:	00 
c00275ee:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c00275f5:	e8 b9 13 00 00       	call   c00289b3 <debug_panic>
    s++;
c00275fa:	83 c2 01             	add    $0x1,%edx
  while (isspace ((unsigned char) *s))
c00275fd:	0f b6 02             	movzbl (%edx),%eax
c0027600:	0f b6 c8             	movzbl %al,%ecx
          || c == '\r' || c == '\t' || c == '\v');
c0027603:	83 f9 20             	cmp    $0x20,%ecx
c0027606:	74 f2                	je     c00275fa <atoi+0x3a>
  return (c == ' ' || c == '\f' || c == '\n'
c0027608:	8d 58 f4             	lea    -0xc(%eax),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c002760b:	80 fb 01             	cmp    $0x1,%bl
c002760e:	76 ea                	jbe    c00275fa <atoi+0x3a>
c0027610:	83 f9 0a             	cmp    $0xa,%ecx
c0027613:	74 e5                	je     c00275fa <atoi+0x3a>
c0027615:	89 c1                	mov    %eax,%ecx
c0027617:	83 e1 fd             	and    $0xfffffffd,%ecx
c002761a:	80 f9 09             	cmp    $0x9,%cl
c002761d:	74 db                	je     c00275fa <atoi+0x3a>
  if (*s == '+')
c002761f:	3c 2b                	cmp    $0x2b,%al
c0027621:	75 0a                	jne    c002762d <atoi+0x6d>
    s++;
c0027623:	83 c2 01             	add    $0x1,%edx
  negative = false;
c0027626:	be 00 00 00 00       	mov    $0x0,%esi
c002762b:	eb 11                	jmp    c002763e <atoi+0x7e>
c002762d:	be 00 00 00 00       	mov    $0x0,%esi
  else if (*s == '-')
c0027632:	3c 2d                	cmp    $0x2d,%al
c0027634:	75 08                	jne    c002763e <atoi+0x7e>
      s++;
c0027636:	8d 52 01             	lea    0x1(%edx),%edx
      negative = true;
c0027639:	be 01 00 00 00       	mov    $0x1,%esi
  for (value = 0; isdigit (*s); s++)
c002763e:	0f b6 0a             	movzbl (%edx),%ecx
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0027641:	0f be c1             	movsbl %cl,%eax
c0027644:	83 e8 30             	sub    $0x30,%eax
c0027647:	83 f8 09             	cmp    $0x9,%eax
c002764a:	77 2a                	ja     c0027676 <atoi+0xb6>
c002764c:	b8 00 00 00 00       	mov    $0x0,%eax
    value = value * 10 - (*s - '0');
c0027651:	bf 30 00 00 00       	mov    $0x30,%edi
c0027656:	8d 1c 80             	lea    (%eax,%eax,4),%ebx
c0027659:	0f be c9             	movsbl %cl,%ecx
c002765c:	89 f8                	mov    %edi,%eax
c002765e:	29 c8                	sub    %ecx,%eax
c0027660:	8d 04 58             	lea    (%eax,%ebx,2),%eax
  for (value = 0; isdigit (*s); s++)
c0027663:	83 c2 01             	add    $0x1,%edx
c0027666:	0f b6 0a             	movzbl (%edx),%ecx
c0027669:	0f be d9             	movsbl %cl,%ebx
c002766c:	83 eb 30             	sub    $0x30,%ebx
c002766f:	83 fb 09             	cmp    $0x9,%ebx
c0027672:	76 e2                	jbe    c0027656 <atoi+0x96>
c0027674:	eb 05                	jmp    c002767b <atoi+0xbb>
c0027676:	b8 00 00 00 00       	mov    $0x0,%eax
    value = -value;
c002767b:	89 c2                	mov    %eax,%edx
c002767d:	f7 da                	neg    %edx
c002767f:	89 f3                	mov    %esi,%ebx
c0027681:	84 db                	test   %bl,%bl
c0027683:	0f 44 c2             	cmove  %edx,%eax
}
c0027686:	83 c4 20             	add    $0x20,%esp
c0027689:	5b                   	pop    %ebx
c002768a:	5e                   	pop    %esi
c002768b:	5f                   	pop    %edi
c002768c:	c3                   	ret    

c002768d <sort>:
   B.  Runs in O(n lg n) time and O(1) space in CNT. */
void
sort (void *array, size_t cnt, size_t size,
      int (*compare) (const void *, const void *, void *aux),
      void *aux) 
{
c002768d:	55                   	push   %ebp
c002768e:	57                   	push   %edi
c002768f:	56                   	push   %esi
c0027690:	53                   	push   %ebx
c0027691:	83 ec 2c             	sub    $0x2c,%esp
c0027694:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0027698:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c002769c:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  size_t i;

  ASSERT (array != NULL || cnt == 0);
c00276a0:	85 ff                	test   %edi,%edi
c00276a2:	75 30                	jne    c00276d4 <sort+0x47>
c00276a4:	85 db                	test   %ebx,%ebx
c00276a6:	74 2c                	je     c00276d4 <sort+0x47>
c00276a8:	c7 44 24 10 77 f9 02 	movl   $0xc002f977,0x10(%esp)
c00276af:	c0 
c00276b0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00276b7:	c0 
c00276b8:	c7 44 24 08 64 dc 02 	movl   $0xc002dc64,0x8(%esp)
c00276bf:	c0 
c00276c0:	c7 44 24 04 8a 00 00 	movl   $0x8a,0x4(%esp)
c00276c7:	00 
c00276c8:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c00276cf:	e8 df 12 00 00       	call   c00289b3 <debug_panic>
  ASSERT (compare != NULL);
c00276d4:	83 7c 24 4c 00       	cmpl   $0x0,0x4c(%esp)
c00276d9:	75 2c                	jne    c0027707 <sort+0x7a>
c00276db:	c7 44 24 10 91 f9 02 	movl   $0xc002f991,0x10(%esp)
c00276e2:	c0 
c00276e3:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00276ea:	c0 
c00276eb:	c7 44 24 08 64 dc 02 	movl   $0xc002dc64,0x8(%esp)
c00276f2:	c0 
c00276f3:	c7 44 24 04 8b 00 00 	movl   $0x8b,0x4(%esp)
c00276fa:	00 
c00276fb:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c0027702:	e8 ac 12 00 00       	call   c00289b3 <debug_panic>
  ASSERT (size > 0);
c0027707:	85 ed                	test   %ebp,%ebp
c0027709:	75 2c                	jne    c0027737 <sort+0xaa>
c002770b:	c7 44 24 10 a1 f9 02 	movl   $0xc002f9a1,0x10(%esp)
c0027712:	c0 
c0027713:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002771a:	c0 
c002771b:	c7 44 24 08 64 dc 02 	movl   $0xc002dc64,0x8(%esp)
c0027722:	c0 
c0027723:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c002772a:	00 
c002772b:	c7 04 24 64 f9 02 c0 	movl   $0xc002f964,(%esp)
c0027732:	e8 7c 12 00 00       	call   c00289b3 <debug_panic>

  /* Build a heap. */
  for (i = cnt / 2; i > 0; i--)
c0027737:	89 de                	mov    %ebx,%esi
c0027739:	d1 ee                	shr    %esi
c002773b:	74 23                	je     c0027760 <sort+0xd3>
    heapify (array, i, cnt, size, compare, aux);
c002773d:	8b 44 24 50          	mov    0x50(%esp),%eax
c0027741:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027745:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027749:	89 44 24 04          	mov    %eax,0x4(%esp)
c002774d:	89 2c 24             	mov    %ebp,(%esp)
c0027750:	89 d9                	mov    %ebx,%ecx
c0027752:	89 f2                	mov    %esi,%edx
c0027754:	89 f8                	mov    %edi,%eax
c0027756:	e8 bc fd ff ff       	call   c0027517 <heapify>
  for (i = cnt / 2; i > 0; i--)
c002775b:	83 ee 01             	sub    $0x1,%esi
c002775e:	75 dd                	jne    c002773d <sort+0xb0>

  /* Sort the heap. */
  for (i = cnt; i > 1; i--) 
c0027760:	83 fb 01             	cmp    $0x1,%ebx
c0027763:	76 3a                	jbe    c002779f <sort+0x112>
c0027765:	8b 74 24 50          	mov    0x50(%esp),%esi
    {
      do_swap (array, 1, i, size);
c0027769:	89 2c 24             	mov    %ebp,(%esp)
c002776c:	89 d9                	mov    %ebx,%ecx
c002776e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027773:	89 f8                	mov    %edi,%eax
c0027775:	e8 62 fd ff ff       	call   c00274dc <do_swap>
      heapify (array, 1, i - 1, size, compare, aux); 
c002777a:	83 eb 01             	sub    $0x1,%ebx
c002777d:	89 74 24 08          	mov    %esi,0x8(%esp)
c0027781:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027785:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027789:	89 2c 24             	mov    %ebp,(%esp)
c002778c:	89 d9                	mov    %ebx,%ecx
c002778e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027793:	89 f8                	mov    %edi,%eax
c0027795:	e8 7d fd ff ff       	call   c0027517 <heapify>
  for (i = cnt; i > 1; i--) 
c002779a:	83 fb 01             	cmp    $0x1,%ebx
c002779d:	75 ca                	jne    c0027769 <sort+0xdc>
    }
}
c002779f:	83 c4 2c             	add    $0x2c,%esp
c00277a2:	5b                   	pop    %ebx
c00277a3:	5e                   	pop    %esi
c00277a4:	5f                   	pop    %edi
c00277a5:	5d                   	pop    %ebp
c00277a6:	c3                   	ret    

c00277a7 <qsort>:
{
c00277a7:	83 ec 2c             	sub    $0x2c,%esp
  sort (array, cnt, size, compare_thunk, &compare);
c00277aa:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c00277ae:	89 44 24 10          	mov    %eax,0x10(%esp)
c00277b2:	c7 44 24 0c c0 74 02 	movl   $0xc00274c0,0xc(%esp)
c00277b9:	c0 
c00277ba:	8b 44 24 38          	mov    0x38(%esp),%eax
c00277be:	89 44 24 08          	mov    %eax,0x8(%esp)
c00277c2:	8b 44 24 34          	mov    0x34(%esp),%eax
c00277c6:	89 44 24 04          	mov    %eax,0x4(%esp)
c00277ca:	8b 44 24 30          	mov    0x30(%esp),%eax
c00277ce:	89 04 24             	mov    %eax,(%esp)
c00277d1:	e8 b7 fe ff ff       	call   c002768d <sort>
}
c00277d6:	83 c4 2c             	add    $0x2c,%esp
c00277d9:	c3                   	ret    

c00277da <binary_search>:
   B. */
void *
binary_search (const void *key, const void *array, size_t cnt, size_t size,
               int (*compare) (const void *, const void *, void *aux),
               void *aux) 
{
c00277da:	55                   	push   %ebp
c00277db:	57                   	push   %edi
c00277dc:	56                   	push   %esi
c00277dd:	53                   	push   %ebx
c00277de:	83 ec 1c             	sub    $0x1c,%esp
c00277e1:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c00277e5:	8b 74 24 3c          	mov    0x3c(%esp),%esi
  const unsigned char *first = array;
  const unsigned char *last = array + size * cnt;
c00277e9:	89 f5                	mov    %esi,%ebp
c00277eb:	0f af 6c 24 38       	imul   0x38(%esp),%ebp
c00277f0:	01 dd                	add    %ebx,%ebp

  while (first < last) 
c00277f2:	39 eb                	cmp    %ebp,%ebx
c00277f4:	73 44                	jae    c002783a <binary_search+0x60>
    {
      size_t range = (last - first) / size;
c00277f6:	89 e8                	mov    %ebp,%eax
c00277f8:	29 d8                	sub    %ebx,%eax
c00277fa:	ba 00 00 00 00       	mov    $0x0,%edx
c00277ff:	f7 f6                	div    %esi
      const unsigned char *middle = first + (range / 2) * size;
c0027801:	d1 e8                	shr    %eax
c0027803:	0f af c6             	imul   %esi,%eax
c0027806:	89 c7                	mov    %eax,%edi
c0027808:	01 df                	add    %ebx,%edi
      int cmp = compare (key, middle, aux);
c002780a:	8b 44 24 44          	mov    0x44(%esp),%eax
c002780e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027812:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0027816:	8b 44 24 30          	mov    0x30(%esp),%eax
c002781a:	89 04 24             	mov    %eax,(%esp)
c002781d:	ff 54 24 40          	call   *0x40(%esp)

      if (cmp < 0) 
c0027821:	85 c0                	test   %eax,%eax
c0027823:	78 0d                	js     c0027832 <binary_search+0x58>
        last = middle;
      else if (cmp > 0) 
c0027825:	85 c0                	test   %eax,%eax
c0027827:	7e 19                	jle    c0027842 <binary_search+0x68>
        first = middle + size;
c0027829:	8d 1c 37             	lea    (%edi,%esi,1),%ebx
c002782c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0027830:	eb 02                	jmp    c0027834 <binary_search+0x5a>
      const unsigned char *middle = first + (range / 2) * size;
c0027832:	89 fd                	mov    %edi,%ebp
  while (first < last) 
c0027834:	39 dd                	cmp    %ebx,%ebp
c0027836:	77 be                	ja     c00277f6 <binary_search+0x1c>
c0027838:	eb 0c                	jmp    c0027846 <binary_search+0x6c>
      else
        return (void *) middle;
    }
  
  return NULL;
c002783a:	b8 00 00 00 00       	mov    $0x0,%eax
c002783f:	90                   	nop
c0027840:	eb 09                	jmp    c002784b <binary_search+0x71>
      const unsigned char *middle = first + (range / 2) * size;
c0027842:	89 f8                	mov    %edi,%eax
c0027844:	eb 05                	jmp    c002784b <binary_search+0x71>
  return NULL;
c0027846:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002784b:	83 c4 1c             	add    $0x1c,%esp
c002784e:	5b                   	pop    %ebx
c002784f:	5e                   	pop    %esi
c0027850:	5f                   	pop    %edi
c0027851:	5d                   	pop    %ebp
c0027852:	c3                   	ret    

c0027853 <bsearch>:
{
c0027853:	83 ec 2c             	sub    $0x2c,%esp
  return binary_search (key, array, cnt, size, compare_thunk, &compare);
c0027856:	8d 44 24 40          	lea    0x40(%esp),%eax
c002785a:	89 44 24 14          	mov    %eax,0x14(%esp)
c002785e:	c7 44 24 10 c0 74 02 	movl   $0xc00274c0,0x10(%esp)
c0027865:	c0 
c0027866:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c002786a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002786e:	8b 44 24 38          	mov    0x38(%esp),%eax
c0027872:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027876:	8b 44 24 34          	mov    0x34(%esp),%eax
c002787a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002787e:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027882:	89 04 24             	mov    %eax,(%esp)
c0027885:	e8 50 ff ff ff       	call   c00277da <binary_search>
}
c002788a:	83 c4 2c             	add    $0x2c,%esp
c002788d:	c3                   	ret    
c002788e:	90                   	nop
c002788f:	90                   	nop

c0027890 <memcpy>:

/* Copies SIZE bytes from SRC to DST, which must not overlap.
   Returns DST. */
void *
memcpy (void *dst_, const void *src_, size_t size) 
{
c0027890:	56                   	push   %esi
c0027891:	53                   	push   %ebx
c0027892:	83 ec 24             	sub    $0x24,%esp
c0027895:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027899:	8b 74 24 34          	mov    0x34(%esp),%esi
c002789d:	8b 5c 24 38          	mov    0x38(%esp),%ebx
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c00278a1:	85 db                	test   %ebx,%ebx
c00278a3:	0f 94 c2             	sete   %dl
c00278a6:	85 c0                	test   %eax,%eax
c00278a8:	75 30                	jne    c00278da <memcpy+0x4a>
c00278aa:	84 d2                	test   %dl,%dl
c00278ac:	75 2c                	jne    c00278da <memcpy+0x4a>
c00278ae:	c7 44 24 10 aa f9 02 	movl   $0xc002f9aa,0x10(%esp)
c00278b5:	c0 
c00278b6:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00278bd:	c0 
c00278be:	c7 44 24 08 b9 dc 02 	movl   $0xc002dcb9,0x8(%esp)
c00278c5:	c0 
c00278c6:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c00278cd:	00 
c00278ce:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00278d5:	e8 d9 10 00 00       	call   c00289b3 <debug_panic>
  ASSERT (src != NULL || size == 0);
c00278da:	85 f6                	test   %esi,%esi
c00278dc:	75 04                	jne    c00278e2 <memcpy+0x52>
c00278de:	84 d2                	test   %dl,%dl
c00278e0:	74 0b                	je     c00278ed <memcpy+0x5d>

  while (size-- > 0)
c00278e2:	ba 00 00 00 00       	mov    $0x0,%edx
c00278e7:	85 db                	test   %ebx,%ebx
c00278e9:	75 2e                	jne    c0027919 <memcpy+0x89>
c00278eb:	eb 3a                	jmp    c0027927 <memcpy+0x97>
  ASSERT (src != NULL || size == 0);
c00278ed:	c7 44 24 10 d6 f9 02 	movl   $0xc002f9d6,0x10(%esp)
c00278f4:	c0 
c00278f5:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00278fc:	c0 
c00278fd:	c7 44 24 08 b9 dc 02 	movl   $0xc002dcb9,0x8(%esp)
c0027904:	c0 
c0027905:	c7 44 24 04 0d 00 00 	movl   $0xd,0x4(%esp)
c002790c:	00 
c002790d:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027914:	e8 9a 10 00 00       	call   c00289b3 <debug_panic>
    *dst++ = *src++;
c0027919:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
c002791d:	88 0c 10             	mov    %cl,(%eax,%edx,1)
c0027920:	83 c2 01             	add    $0x1,%edx
  while (size-- > 0)
c0027923:	39 da                	cmp    %ebx,%edx
c0027925:	75 f2                	jne    c0027919 <memcpy+0x89>

  return dst_;
}
c0027927:	83 c4 24             	add    $0x24,%esp
c002792a:	5b                   	pop    %ebx
c002792b:	5e                   	pop    %esi
c002792c:	c3                   	ret    

c002792d <memmove>:

/* Copies SIZE bytes from SRC to DST, which are allowed to
   overlap.  Returns DST. */
void *
memmove (void *dst_, const void *src_, size_t size) 
{
c002792d:	57                   	push   %edi
c002792e:	56                   	push   %esi
c002792f:	53                   	push   %ebx
c0027930:	83 ec 20             	sub    $0x20,%esp
c0027933:	8b 74 24 30          	mov    0x30(%esp),%esi
c0027937:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c002793b:	8b 7c 24 38          	mov    0x38(%esp),%edi
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c002793f:	85 ff                	test   %edi,%edi
c0027941:	0f 94 c2             	sete   %dl
c0027944:	85 f6                	test   %esi,%esi
c0027946:	75 30                	jne    c0027978 <memmove+0x4b>
c0027948:	84 d2                	test   %dl,%dl
c002794a:	75 2c                	jne    c0027978 <memmove+0x4b>
c002794c:	c7 44 24 10 aa f9 02 	movl   $0xc002f9aa,0x10(%esp)
c0027953:	c0 
c0027954:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002795b:	c0 
c002795c:	c7 44 24 08 b1 dc 02 	movl   $0xc002dcb1,0x8(%esp)
c0027963:	c0 
c0027964:	c7 44 24 04 1d 00 00 	movl   $0x1d,0x4(%esp)
c002796b:	00 
c002796c:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027973:	e8 3b 10 00 00       	call   c00289b3 <debug_panic>
  ASSERT (src != NULL || size == 0);
c0027978:	85 db                	test   %ebx,%ebx
c002797a:	75 30                	jne    c00279ac <memmove+0x7f>
c002797c:	84 d2                	test   %dl,%dl
c002797e:	75 2c                	jne    c00279ac <memmove+0x7f>
c0027980:	c7 44 24 10 d6 f9 02 	movl   $0xc002f9d6,0x10(%esp)
c0027987:	c0 
c0027988:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002798f:	c0 
c0027990:	c7 44 24 08 b1 dc 02 	movl   $0xc002dcb1,0x8(%esp)
c0027997:	c0 
c0027998:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002799f:	00 
c00279a0:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00279a7:	e8 07 10 00 00       	call   c00289b3 <debug_panic>

  if (dst < src) 
c00279ac:	39 de                	cmp    %ebx,%esi
c00279ae:	73 1b                	jae    c00279cb <memmove+0x9e>
    {
      while (size-- > 0)
c00279b0:	85 ff                	test   %edi,%edi
c00279b2:	74 40                	je     c00279f4 <memmove+0xc7>
c00279b4:	ba 00 00 00 00       	mov    $0x0,%edx
        *dst++ = *src++;
c00279b9:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
c00279bd:	88 0c 16             	mov    %cl,(%esi,%edx,1)
c00279c0:	83 c2 01             	add    $0x1,%edx
      while (size-- > 0)
c00279c3:	39 fa                	cmp    %edi,%edx
c00279c5:	75 f2                	jne    c00279b9 <memmove+0x8c>
c00279c7:	01 fe                	add    %edi,%esi
c00279c9:	eb 29                	jmp    c00279f4 <memmove+0xc7>
    }
  else 
    {
      dst += size;
c00279cb:	8d 04 3e             	lea    (%esi,%edi,1),%eax
      src += size;
c00279ce:	01 fb                	add    %edi,%ebx
      while (size-- > 0)
c00279d0:	8d 57 ff             	lea    -0x1(%edi),%edx
c00279d3:	85 ff                	test   %edi,%edi
c00279d5:	74 1b                	je     c00279f2 <memmove+0xc5>
c00279d7:	f7 df                	neg    %edi
c00279d9:	89 f9                	mov    %edi,%ecx
c00279db:	01 fb                	add    %edi,%ebx
c00279dd:	01 c1                	add    %eax,%ecx
c00279df:	89 ce                	mov    %ecx,%esi
        *--dst = *--src;
c00279e1:	0f b6 04 13          	movzbl (%ebx,%edx,1),%eax
c00279e5:	88 04 11             	mov    %al,(%ecx,%edx,1)
      while (size-- > 0)
c00279e8:	83 ea 01             	sub    $0x1,%edx
c00279eb:	83 fa ff             	cmp    $0xffffffff,%edx
c00279ee:	75 ef                	jne    c00279df <memmove+0xb2>
c00279f0:	eb 02                	jmp    c00279f4 <memmove+0xc7>
      dst += size;
c00279f2:	89 c6                	mov    %eax,%esi
    }

  return dst;
}
c00279f4:	89 f0                	mov    %esi,%eax
c00279f6:	83 c4 20             	add    $0x20,%esp
c00279f9:	5b                   	pop    %ebx
c00279fa:	5e                   	pop    %esi
c00279fb:	5f                   	pop    %edi
c00279fc:	c3                   	ret    

c00279fd <memcmp>:
   at A and B.  Returns a positive value if the byte in A is
   greater, a negative value if the byte in B is greater, or zero
   if blocks A and B are equal. */
int
memcmp (const void *a_, const void *b_, size_t size) 
{
c00279fd:	57                   	push   %edi
c00279fe:	56                   	push   %esi
c00279ff:	53                   	push   %ebx
c0027a00:	83 ec 20             	sub    $0x20,%esp
c0027a03:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027a07:	8b 74 24 34          	mov    0x34(%esp),%esi
c0027a0b:	8b 44 24 38          	mov    0x38(%esp),%eax
  const unsigned char *a = a_;
  const unsigned char *b = b_;

  ASSERT (a != NULL || size == 0);
c0027a0f:	85 c0                	test   %eax,%eax
c0027a11:	0f 94 c2             	sete   %dl
c0027a14:	85 db                	test   %ebx,%ebx
c0027a16:	75 30                	jne    c0027a48 <memcmp+0x4b>
c0027a18:	84 d2                	test   %dl,%dl
c0027a1a:	75 2c                	jne    c0027a48 <memcmp+0x4b>
c0027a1c:	c7 44 24 10 ef f9 02 	movl   $0xc002f9ef,0x10(%esp)
c0027a23:	c0 
c0027a24:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027a2b:	c0 
c0027a2c:	c7 44 24 08 aa dc 02 	movl   $0xc002dcaa,0x8(%esp)
c0027a33:	c0 
c0027a34:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
c0027a3b:	00 
c0027a3c:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027a43:	e8 6b 0f 00 00       	call   c00289b3 <debug_panic>
  ASSERT (b != NULL || size == 0);
c0027a48:	85 f6                	test   %esi,%esi
c0027a4a:	75 04                	jne    c0027a50 <memcmp+0x53>
c0027a4c:	84 d2                	test   %dl,%dl
c0027a4e:	74 18                	je     c0027a68 <memcmp+0x6b>

  for (; size-- > 0; a++, b++)
c0027a50:	8d 78 ff             	lea    -0x1(%eax),%edi
c0027a53:	85 c0                	test   %eax,%eax
c0027a55:	74 64                	je     c0027abb <memcmp+0xbe>
    if (*a != *b)
c0027a57:	0f b6 13             	movzbl (%ebx),%edx
c0027a5a:	0f b6 0e             	movzbl (%esi),%ecx
c0027a5d:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a62:	38 ca                	cmp    %cl,%dl
c0027a64:	74 4a                	je     c0027ab0 <memcmp+0xb3>
c0027a66:	eb 3c                	jmp    c0027aa4 <memcmp+0xa7>
  ASSERT (b != NULL || size == 0);
c0027a68:	c7 44 24 10 06 fa 02 	movl   $0xc002fa06,0x10(%esp)
c0027a6f:	c0 
c0027a70:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027a77:	c0 
c0027a78:	c7 44 24 08 aa dc 02 	movl   $0xc002dcaa,0x8(%esp)
c0027a7f:	c0 
c0027a80:	c7 44 24 04 3b 00 00 	movl   $0x3b,0x4(%esp)
c0027a87:	00 
c0027a88:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027a8f:	e8 1f 0f 00 00       	call   c00289b3 <debug_panic>
    if (*a != *b)
c0027a94:	0f b6 54 03 01       	movzbl 0x1(%ebx,%eax,1),%edx
c0027a99:	83 c0 01             	add    $0x1,%eax
c0027a9c:	0f b6 0c 06          	movzbl (%esi,%eax,1),%ecx
c0027aa0:	38 ca                	cmp    %cl,%dl
c0027aa2:	74 0c                	je     c0027ab0 <memcmp+0xb3>
      return *a > *b ? +1 : -1;
c0027aa4:	38 d1                	cmp    %dl,%cl
c0027aa6:	19 c0                	sbb    %eax,%eax
c0027aa8:	83 e0 02             	and    $0x2,%eax
c0027aab:	83 e8 01             	sub    $0x1,%eax
c0027aae:	eb 10                	jmp    c0027ac0 <memcmp+0xc3>
  for (; size-- > 0; a++, b++)
c0027ab0:	39 f8                	cmp    %edi,%eax
c0027ab2:	75 e0                	jne    c0027a94 <memcmp+0x97>
  return 0;
c0027ab4:	b8 00 00 00 00       	mov    $0x0,%eax
c0027ab9:	eb 05                	jmp    c0027ac0 <memcmp+0xc3>
c0027abb:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027ac0:	83 c4 20             	add    $0x20,%esp
c0027ac3:	5b                   	pop    %ebx
c0027ac4:	5e                   	pop    %esi
c0027ac5:	5f                   	pop    %edi
c0027ac6:	c3                   	ret    

c0027ac7 <strcmp>:
   char) is greater, a negative value if the character in B (as
   an unsigned char) is greater, or zero if strings A and B are
   equal. */
int
strcmp (const char *a_, const char *b_) 
{
c0027ac7:	83 ec 2c             	sub    $0x2c,%esp
c0027aca:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c0027ace:	8b 54 24 34          	mov    0x34(%esp),%edx
  const unsigned char *a = (const unsigned char *) a_;
  const unsigned char *b = (const unsigned char *) b_;

  ASSERT (a != NULL);
c0027ad2:	85 c9                	test   %ecx,%ecx
c0027ad4:	75 2c                	jne    c0027b02 <strcmp+0x3b>
c0027ad6:	c7 44 24 10 59 ea 02 	movl   $0xc002ea59,0x10(%esp)
c0027add:	c0 
c0027ade:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027ae5:	c0 
c0027ae6:	c7 44 24 08 a3 dc 02 	movl   $0xc002dca3,0x8(%esp)
c0027aed:	c0 
c0027aee:	c7 44 24 04 4e 00 00 	movl   $0x4e,0x4(%esp)
c0027af5:	00 
c0027af6:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027afd:	e8 b1 0e 00 00       	call   c00289b3 <debug_panic>
  ASSERT (b != NULL);
c0027b02:	85 d2                	test   %edx,%edx
c0027b04:	74 0e                	je     c0027b14 <strcmp+0x4d>

  while (*a != '\0' && *a == *b) 
c0027b06:	0f b6 01             	movzbl (%ecx),%eax
c0027b09:	84 c0                	test   %al,%al
c0027b0b:	74 44                	je     c0027b51 <strcmp+0x8a>
c0027b0d:	3a 02                	cmp    (%edx),%al
c0027b0f:	90                   	nop
c0027b10:	74 2e                	je     c0027b40 <strcmp+0x79>
c0027b12:	eb 3d                	jmp    c0027b51 <strcmp+0x8a>
  ASSERT (b != NULL);
c0027b14:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0027b1b:	c0 
c0027b1c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027b23:	c0 
c0027b24:	c7 44 24 08 a3 dc 02 	movl   $0xc002dca3,0x8(%esp)
c0027b2b:	c0 
c0027b2c:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c0027b33:	00 
c0027b34:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027b3b:	e8 73 0e 00 00       	call   c00289b3 <debug_panic>
    {
      a++;
c0027b40:	83 c1 01             	add    $0x1,%ecx
      b++;
c0027b43:	83 c2 01             	add    $0x1,%edx
  while (*a != '\0' && *a == *b) 
c0027b46:	0f b6 01             	movzbl (%ecx),%eax
c0027b49:	84 c0                	test   %al,%al
c0027b4b:	74 04                	je     c0027b51 <strcmp+0x8a>
c0027b4d:	3a 02                	cmp    (%edx),%al
c0027b4f:	74 ef                	je     c0027b40 <strcmp+0x79>
    }

  return *a < *b ? -1 : *a > *b;
c0027b51:	0f b6 12             	movzbl (%edx),%edx
c0027b54:	38 c2                	cmp    %al,%dl
c0027b56:	77 0a                	ja     c0027b62 <strcmp+0x9b>
c0027b58:	38 d0                	cmp    %dl,%al
c0027b5a:	0f 97 c0             	seta   %al
c0027b5d:	0f b6 c0             	movzbl %al,%eax
c0027b60:	eb 05                	jmp    c0027b67 <strcmp+0xa0>
c0027b62:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0027b67:	83 c4 2c             	add    $0x2c,%esp
c0027b6a:	c3                   	ret    

c0027b6b <memchr>:
/* Returns a pointer to the first occurrence of CH in the first
   SIZE bytes starting at BLOCK.  Returns a null pointer if CH
   does not occur in BLOCK. */
void *
memchr (const void *block_, int ch_, size_t size) 
{
c0027b6b:	56                   	push   %esi
c0027b6c:	53                   	push   %ebx
c0027b6d:	83 ec 24             	sub    $0x24,%esp
c0027b70:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027b74:	8b 74 24 34          	mov    0x34(%esp),%esi
c0027b78:	8b 54 24 38          	mov    0x38(%esp),%edx
  const unsigned char *block = block_;
  unsigned char ch = ch_;
c0027b7c:	89 f3                	mov    %esi,%ebx

  ASSERT (block != NULL || size == 0);
c0027b7e:	85 c0                	test   %eax,%eax
c0027b80:	75 04                	jne    c0027b86 <memchr+0x1b>
c0027b82:	85 d2                	test   %edx,%edx
c0027b84:	75 14                	jne    c0027b9a <memchr+0x2f>

  for (; size-- > 0; block++)
c0027b86:	8d 4a ff             	lea    -0x1(%edx),%ecx
c0027b89:	85 d2                	test   %edx,%edx
c0027b8b:	74 4e                	je     c0027bdb <memchr+0x70>
    if (*block == ch)
c0027b8d:	89 f2                	mov    %esi,%edx
c0027b8f:	38 10                	cmp    %dl,(%eax)
c0027b91:	74 4d                	je     c0027be0 <memchr+0x75>
c0027b93:	ba 00 00 00 00       	mov    $0x0,%edx
c0027b98:	eb 33                	jmp    c0027bcd <memchr+0x62>
  ASSERT (block != NULL || size == 0);
c0027b9a:	c7 44 24 10 27 fa 02 	movl   $0xc002fa27,0x10(%esp)
c0027ba1:	c0 
c0027ba2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027ba9:	c0 
c0027baa:	c7 44 24 08 9c dc 02 	movl   $0xc002dc9c,0x8(%esp)
c0027bb1:	c0 
c0027bb2:	c7 44 24 04 63 00 00 	movl   $0x63,0x4(%esp)
c0027bb9:	00 
c0027bba:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027bc1:	e8 ed 0d 00 00       	call   c00289b3 <debug_panic>
c0027bc6:	83 c2 01             	add    $0x1,%edx
    if (*block == ch)
c0027bc9:	38 18                	cmp    %bl,(%eax)
c0027bcb:	74 13                	je     c0027be0 <memchr+0x75>
  for (; size-- > 0; block++)
c0027bcd:	83 c0 01             	add    $0x1,%eax
c0027bd0:	39 ca                	cmp    %ecx,%edx
c0027bd2:	75 f2                	jne    c0027bc6 <memchr+0x5b>
      return (void *) block;

  return NULL;
c0027bd4:	b8 00 00 00 00       	mov    $0x0,%eax
c0027bd9:	eb 05                	jmp    c0027be0 <memchr+0x75>
c0027bdb:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027be0:	83 c4 24             	add    $0x24,%esp
c0027be3:	5b                   	pop    %ebx
c0027be4:	5e                   	pop    %esi
c0027be5:	c3                   	ret    

c0027be6 <strchr>:
   null pointer if C does not appear in STRING.  If C == '\0'
   then returns a pointer to the null terminator at the end of
   STRING. */
char *
strchr (const char *string, int c_) 
{
c0027be6:	53                   	push   %ebx
c0027be7:	83 ec 28             	sub    $0x28,%esp
c0027bea:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027bee:	8b 54 24 34          	mov    0x34(%esp),%edx
  char c = c_;

  ASSERT (string != NULL);
c0027bf2:	85 c0                	test   %eax,%eax
c0027bf4:	74 0b                	je     c0027c01 <strchr+0x1b>
c0027bf6:	89 d1                	mov    %edx,%ecx

  for (;;) 
    if (*string == c)
c0027bf8:	0f b6 18             	movzbl (%eax),%ebx
c0027bfb:	38 d3                	cmp    %dl,%bl
c0027bfd:	75 2e                	jne    c0027c2d <strchr+0x47>
c0027bff:	eb 4e                	jmp    c0027c4f <strchr+0x69>
  ASSERT (string != NULL);
c0027c01:	c7 44 24 10 42 fa 02 	movl   $0xc002fa42,0x10(%esp)
c0027c08:	c0 
c0027c09:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027c10:	c0 
c0027c11:	c7 44 24 08 95 dc 02 	movl   $0xc002dc95,0x8(%esp)
c0027c18:	c0 
c0027c19:	c7 44 24 04 75 00 00 	movl   $0x75,0x4(%esp)
c0027c20:	00 
c0027c21:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027c28:	e8 86 0d 00 00       	call   c00289b3 <debug_panic>
      return (char *) string;
    else if (*string == '\0')
c0027c2d:	84 db                	test   %bl,%bl
c0027c2f:	75 06                	jne    c0027c37 <strchr+0x51>
c0027c31:	eb 10                	jmp    c0027c43 <strchr+0x5d>
c0027c33:	84 d2                	test   %dl,%dl
c0027c35:	74 13                	je     c0027c4a <strchr+0x64>
      return NULL;
    else
      string++;
c0027c37:	83 c0 01             	add    $0x1,%eax
    if (*string == c)
c0027c3a:	0f b6 10             	movzbl (%eax),%edx
c0027c3d:	38 ca                	cmp    %cl,%dl
c0027c3f:	75 f2                	jne    c0027c33 <strchr+0x4d>
c0027c41:	eb 0c                	jmp    c0027c4f <strchr+0x69>
      return NULL;
c0027c43:	b8 00 00 00 00       	mov    $0x0,%eax
c0027c48:	eb 05                	jmp    c0027c4f <strchr+0x69>
c0027c4a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027c4f:	83 c4 28             	add    $0x28,%esp
c0027c52:	5b                   	pop    %ebx
c0027c53:	c3                   	ret    

c0027c54 <strcspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters that are not in STOP. */
size_t
strcspn (const char *string, const char *stop) 
{
c0027c54:	57                   	push   %edi
c0027c55:	56                   	push   %esi
c0027c56:	53                   	push   %ebx
c0027c57:	83 ec 10             	sub    $0x10,%esp
c0027c5a:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027c5e:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;

  for (length = 0; string[length] != '\0'; length++)
c0027c62:	0f b6 16             	movzbl (%esi),%edx
c0027c65:	84 d2                	test   %dl,%dl
c0027c67:	74 25                	je     c0027c8e <strcspn+0x3a>
c0027c69:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (stop, string[length]) != NULL)
c0027c6e:	0f be d2             	movsbl %dl,%edx
c0027c71:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c75:	89 3c 24             	mov    %edi,(%esp)
c0027c78:	e8 69 ff ff ff       	call   c0027be6 <strchr>
c0027c7d:	85 c0                	test   %eax,%eax
c0027c7f:	75 12                	jne    c0027c93 <strcspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027c81:	83 c3 01             	add    $0x1,%ebx
c0027c84:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027c88:	84 d2                	test   %dl,%dl
c0027c8a:	75 e2                	jne    c0027c6e <strcspn+0x1a>
c0027c8c:	eb 05                	jmp    c0027c93 <strcspn+0x3f>
c0027c8e:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027c93:	89 d8                	mov    %ebx,%eax
c0027c95:	83 c4 10             	add    $0x10,%esp
c0027c98:	5b                   	pop    %ebx
c0027c99:	5e                   	pop    %esi
c0027c9a:	5f                   	pop    %edi
c0027c9b:	c3                   	ret    

c0027c9c <strpbrk>:
/* Returns a pointer to the first character in STRING that is
   also in STOP.  If no character in STRING is in STOP, returns a
   null pointer. */
char *
strpbrk (const char *string, const char *stop) 
{
c0027c9c:	56                   	push   %esi
c0027c9d:	53                   	push   %ebx
c0027c9e:	83 ec 14             	sub    $0x14,%esp
c0027ca1:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0027ca5:	8b 74 24 24          	mov    0x24(%esp),%esi
  for (; *string != '\0'; string++)
c0027ca9:	0f b6 13             	movzbl (%ebx),%edx
c0027cac:	84 d2                	test   %dl,%dl
c0027cae:	74 1f                	je     c0027ccf <strpbrk+0x33>
    if (strchr (stop, *string) != NULL)
c0027cb0:	0f be d2             	movsbl %dl,%edx
c0027cb3:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027cb7:	89 34 24             	mov    %esi,(%esp)
c0027cba:	e8 27 ff ff ff       	call   c0027be6 <strchr>
c0027cbf:	85 c0                	test   %eax,%eax
c0027cc1:	75 13                	jne    c0027cd6 <strpbrk+0x3a>
  for (; *string != '\0'; string++)
c0027cc3:	83 c3 01             	add    $0x1,%ebx
c0027cc6:	0f b6 13             	movzbl (%ebx),%edx
c0027cc9:	84 d2                	test   %dl,%dl
c0027ccb:	75 e3                	jne    c0027cb0 <strpbrk+0x14>
c0027ccd:	eb 09                	jmp    c0027cd8 <strpbrk+0x3c>
      return (char *) string;
  return NULL;
c0027ccf:	b8 00 00 00 00       	mov    $0x0,%eax
c0027cd4:	eb 02                	jmp    c0027cd8 <strpbrk+0x3c>
c0027cd6:	89 d8                	mov    %ebx,%eax
}
c0027cd8:	83 c4 14             	add    $0x14,%esp
c0027cdb:	5b                   	pop    %ebx
c0027cdc:	5e                   	pop    %esi
c0027cdd:	c3                   	ret    

c0027cde <strrchr>:

/* Returns a pointer to the last occurrence of C in STRING.
   Returns a null pointer if C does not occur in STRING. */
char *
strrchr (const char *string, int c_) 
{
c0027cde:	53                   	push   %ebx
c0027cdf:	8b 54 24 08          	mov    0x8(%esp),%edx
  char c = c_;
c0027ce3:	0f b6 5c 24 0c       	movzbl 0xc(%esp),%ebx
  const char *p = NULL;

  for (; *string != '\0'; string++)
c0027ce8:	0f b6 0a             	movzbl (%edx),%ecx
c0027ceb:	84 c9                	test   %cl,%cl
c0027ced:	74 16                	je     c0027d05 <strrchr+0x27>
  const char *p = NULL;
c0027cef:	b8 00 00 00 00       	mov    $0x0,%eax
c0027cf4:	38 cb                	cmp    %cl,%bl
c0027cf6:	0f 44 c2             	cmove  %edx,%eax
  for (; *string != '\0'; string++)
c0027cf9:	83 c2 01             	add    $0x1,%edx
c0027cfc:	0f b6 0a             	movzbl (%edx),%ecx
c0027cff:	84 c9                	test   %cl,%cl
c0027d01:	75 f1                	jne    c0027cf4 <strrchr+0x16>
c0027d03:	eb 05                	jmp    c0027d0a <strrchr+0x2c>
  const char *p = NULL;
c0027d05:	b8 00 00 00 00       	mov    $0x0,%eax
    if (*string == c)
      p = string;
  return (char *) p;
}
c0027d0a:	5b                   	pop    %ebx
c0027d0b:	c3                   	ret    

c0027d0c <strspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters in SKIP. */
size_t
strspn (const char *string, const char *skip) 
{
c0027d0c:	57                   	push   %edi
c0027d0d:	56                   	push   %esi
c0027d0e:	53                   	push   %ebx
c0027d0f:	83 ec 10             	sub    $0x10,%esp
c0027d12:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027d16:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;
  
  for (length = 0; string[length] != '\0'; length++)
c0027d1a:	0f b6 16             	movzbl (%esi),%edx
c0027d1d:	84 d2                	test   %dl,%dl
c0027d1f:	74 25                	je     c0027d46 <strspn+0x3a>
c0027d21:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (skip, string[length]) == NULL)
c0027d26:	0f be d2             	movsbl %dl,%edx
c0027d29:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027d2d:	89 3c 24             	mov    %edi,(%esp)
c0027d30:	e8 b1 fe ff ff       	call   c0027be6 <strchr>
c0027d35:	85 c0                	test   %eax,%eax
c0027d37:	74 12                	je     c0027d4b <strspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027d39:	83 c3 01             	add    $0x1,%ebx
c0027d3c:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027d40:	84 d2                	test   %dl,%dl
c0027d42:	75 e2                	jne    c0027d26 <strspn+0x1a>
c0027d44:	eb 05                	jmp    c0027d4b <strspn+0x3f>
c0027d46:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027d4b:	89 d8                	mov    %ebx,%eax
c0027d4d:	83 c4 10             	add    $0x10,%esp
c0027d50:	5b                   	pop    %ebx
c0027d51:	5e                   	pop    %esi
c0027d52:	5f                   	pop    %edi
c0027d53:	c3                   	ret    

c0027d54 <strtok_r>:
     'to'
     'tokenize.'
*/
char *
strtok_r (char *s, const char *delimiters, char **save_ptr) 
{
c0027d54:	55                   	push   %ebp
c0027d55:	57                   	push   %edi
c0027d56:	56                   	push   %esi
c0027d57:	53                   	push   %ebx
c0027d58:	83 ec 2c             	sub    $0x2c,%esp
c0027d5b:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c0027d5f:	8b 74 24 44          	mov    0x44(%esp),%esi
  char *token;
  
  ASSERT (delimiters != NULL);
c0027d63:	85 f6                	test   %esi,%esi
c0027d65:	75 2c                	jne    c0027d93 <strtok_r+0x3f>
c0027d67:	c7 44 24 10 51 fa 02 	movl   $0xc002fa51,0x10(%esp)
c0027d6e:	c0 
c0027d6f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027d76:	c0 
c0027d77:	c7 44 24 08 8c dc 02 	movl   $0xc002dc8c,0x8(%esp)
c0027d7e:	c0 
c0027d7f:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0027d86:	00 
c0027d87:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027d8e:	e8 20 0c 00 00       	call   c00289b3 <debug_panic>
  ASSERT (save_ptr != NULL);
c0027d93:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0027d98:	75 2c                	jne    c0027dc6 <strtok_r+0x72>
c0027d9a:	c7 44 24 10 64 fa 02 	movl   $0xc002fa64,0x10(%esp)
c0027da1:	c0 
c0027da2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027da9:	c0 
c0027daa:	c7 44 24 08 8c dc 02 	movl   $0xc002dc8c,0x8(%esp)
c0027db1:	c0 
c0027db2:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c0027db9:	00 
c0027dba:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027dc1:	e8 ed 0b 00 00       	call   c00289b3 <debug_panic>

  /* If S is nonnull, start from it.
     If S is null, start from saved position. */
  if (s == NULL)
c0027dc6:	85 db                	test   %ebx,%ebx
c0027dc8:	75 4c                	jne    c0027e16 <strtok_r+0xc2>
    s = *save_ptr;
c0027dca:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027dce:	8b 18                	mov    (%eax),%ebx
  ASSERT (s != NULL);
c0027dd0:	85 db                	test   %ebx,%ebx
c0027dd2:	75 42                	jne    c0027e16 <strtok_r+0xc2>
c0027dd4:	c7 44 24 10 5a fa 02 	movl   $0xc002fa5a,0x10(%esp)
c0027ddb:	c0 
c0027ddc:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027de3:	c0 
c0027de4:	c7 44 24 08 8c dc 02 	movl   $0xc002dc8c,0x8(%esp)
c0027deb:	c0 
c0027dec:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0027df3:	00 
c0027df4:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027dfb:	e8 b3 0b 00 00       	call   c00289b3 <debug_panic>
  while (strchr (delimiters, *s) != NULL) 
    {
      /* strchr() will always return nonnull if we're searching
         for a null byte, because every string contains a null
         byte (at the end). */
      if (*s == '\0')
c0027e00:	89 f8                	mov    %edi,%eax
c0027e02:	84 c0                	test   %al,%al
c0027e04:	75 0d                	jne    c0027e13 <strtok_r+0xbf>
        {
          *save_ptr = s;
c0027e06:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e0a:	89 18                	mov    %ebx,(%eax)
          return NULL;
c0027e0c:	b8 00 00 00 00       	mov    $0x0,%eax
c0027e11:	eb 56                	jmp    c0027e69 <strtok_r+0x115>
        }

      s++;
c0027e13:	83 c3 01             	add    $0x1,%ebx
  while (strchr (delimiters, *s) != NULL) 
c0027e16:	0f b6 3b             	movzbl (%ebx),%edi
c0027e19:	89 f8                	mov    %edi,%eax
c0027e1b:	0f be c0             	movsbl %al,%eax
c0027e1e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027e22:	89 34 24             	mov    %esi,(%esp)
c0027e25:	e8 bc fd ff ff       	call   c0027be6 <strchr>
c0027e2a:	85 c0                	test   %eax,%eax
c0027e2c:	75 d2                	jne    c0027e00 <strtok_r+0xac>
c0027e2e:	89 df                	mov    %ebx,%edi
    }

  /* Skip any non-DELIMITERS up to the end of the string. */
  token = s;
  while (strchr (delimiters, *s) == NULL)
    s++;
c0027e30:	83 c7 01             	add    $0x1,%edi
  while (strchr (delimiters, *s) == NULL)
c0027e33:	0f b6 2f             	movzbl (%edi),%ebp
c0027e36:	89 e8                	mov    %ebp,%eax
c0027e38:	0f be c0             	movsbl %al,%eax
c0027e3b:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027e3f:	89 34 24             	mov    %esi,(%esp)
c0027e42:	e8 9f fd ff ff       	call   c0027be6 <strchr>
c0027e47:	85 c0                	test   %eax,%eax
c0027e49:	74 e5                	je     c0027e30 <strtok_r+0xdc>
  if (*s != '\0') 
c0027e4b:	89 e8                	mov    %ebp,%eax
c0027e4d:	84 c0                	test   %al,%al
c0027e4f:	74 10                	je     c0027e61 <strtok_r+0x10d>
    {
      *s = '\0';
c0027e51:	c6 07 00             	movb   $0x0,(%edi)
      *save_ptr = s + 1;
c0027e54:	83 c7 01             	add    $0x1,%edi
c0027e57:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e5b:	89 38                	mov    %edi,(%eax)
c0027e5d:	89 d8                	mov    %ebx,%eax
c0027e5f:	eb 08                	jmp    c0027e69 <strtok_r+0x115>
    }
  else 
    *save_ptr = s;
c0027e61:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e65:	89 38                	mov    %edi,(%eax)
c0027e67:	89 d8                	mov    %ebx,%eax
  return token;
}
c0027e69:	83 c4 2c             	add    $0x2c,%esp
c0027e6c:	5b                   	pop    %ebx
c0027e6d:	5e                   	pop    %esi
c0027e6e:	5f                   	pop    %edi
c0027e6f:	5d                   	pop    %ebp
c0027e70:	c3                   	ret    

c0027e71 <memset>:

/* Sets the SIZE bytes in DST to VALUE. */
void *
memset (void *dst_, int value, size_t size) 
{
c0027e71:	56                   	push   %esi
c0027e72:	53                   	push   %ebx
c0027e73:	83 ec 24             	sub    $0x24,%esp
c0027e76:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027e7a:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c0027e7e:	8b 74 24 38          	mov    0x38(%esp),%esi
  unsigned char *dst = dst_;

  ASSERT (dst != NULL || size == 0);
c0027e82:	85 c0                	test   %eax,%eax
c0027e84:	75 04                	jne    c0027e8a <memset+0x19>
c0027e86:	85 f6                	test   %esi,%esi
c0027e88:	75 0b                	jne    c0027e95 <memset+0x24>
c0027e8a:	8d 0c 30             	lea    (%eax,%esi,1),%ecx
  
  while (size-- > 0)
c0027e8d:	89 c2                	mov    %eax,%edx
c0027e8f:	85 f6                	test   %esi,%esi
c0027e91:	75 2e                	jne    c0027ec1 <memset+0x50>
c0027e93:	eb 36                	jmp    c0027ecb <memset+0x5a>
  ASSERT (dst != NULL || size == 0);
c0027e95:	c7 44 24 10 aa f9 02 	movl   $0xc002f9aa,0x10(%esp)
c0027e9c:	c0 
c0027e9d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027ea4:	c0 
c0027ea5:	c7 44 24 08 85 dc 02 	movl   $0xc002dc85,0x8(%esp)
c0027eac:	c0 
c0027ead:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c0027eb4:	00 
c0027eb5:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027ebc:	e8 f2 0a 00 00       	call   c00289b3 <debug_panic>
    *dst++ = value;
c0027ec1:	83 c2 01             	add    $0x1,%edx
c0027ec4:	88 5a ff             	mov    %bl,-0x1(%edx)
  while (size-- > 0)
c0027ec7:	39 ca                	cmp    %ecx,%edx
c0027ec9:	75 f6                	jne    c0027ec1 <memset+0x50>

  return dst_;
}
c0027ecb:	83 c4 24             	add    $0x24,%esp
c0027ece:	5b                   	pop    %ebx
c0027ecf:	5e                   	pop    %esi
c0027ed0:	c3                   	ret    

c0027ed1 <strlen>:

/* Returns the length of STRING. */
size_t
strlen (const char *string) 
{
c0027ed1:	83 ec 2c             	sub    $0x2c,%esp
c0027ed4:	8b 54 24 30          	mov    0x30(%esp),%edx
  const char *p;

  ASSERT (string != NULL);
c0027ed8:	85 d2                	test   %edx,%edx
c0027eda:	74 09                	je     c0027ee5 <strlen+0x14>

  for (p = string; *p != '\0'; p++)
c0027edc:	89 d0                	mov    %edx,%eax
c0027ede:	80 3a 00             	cmpb   $0x0,(%edx)
c0027ee1:	74 38                	je     c0027f1b <strlen+0x4a>
c0027ee3:	eb 2c                	jmp    c0027f11 <strlen+0x40>
  ASSERT (string != NULL);
c0027ee5:	c7 44 24 10 42 fa 02 	movl   $0xc002fa42,0x10(%esp)
c0027eec:	c0 
c0027eed:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027ef4:	c0 
c0027ef5:	c7 44 24 08 7e dc 02 	movl   $0xc002dc7e,0x8(%esp)
c0027efc:	c0 
c0027efd:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c0027f04:	00 
c0027f05:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0027f0c:	e8 a2 0a 00 00       	call   c00289b3 <debug_panic>
  for (p = string; *p != '\0'; p++)
c0027f11:	89 d0                	mov    %edx,%eax
c0027f13:	83 c0 01             	add    $0x1,%eax
c0027f16:	80 38 00             	cmpb   $0x0,(%eax)
c0027f19:	75 f8                	jne    c0027f13 <strlen+0x42>
    continue;
  return p - string;
c0027f1b:	29 d0                	sub    %edx,%eax
}
c0027f1d:	83 c4 2c             	add    $0x2c,%esp
c0027f20:	c3                   	ret    

c0027f21 <strstr>:
{
c0027f21:	55                   	push   %ebp
c0027f22:	57                   	push   %edi
c0027f23:	56                   	push   %esi
c0027f24:	53                   	push   %ebx
c0027f25:	83 ec 1c             	sub    $0x1c,%esp
c0027f28:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  size_t haystack_len = strlen (haystack);
c0027f2c:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c0027f31:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0027f35:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f3a:	89 d9                	mov    %ebx,%ecx
c0027f3c:	f2 ae                	repnz scas %es:(%edi),%al
c0027f3e:	f7 d1                	not    %ecx
c0027f40:	8d 51 ff             	lea    -0x1(%ecx),%edx
  size_t needle_len = strlen (needle);
c0027f43:	89 ef                	mov    %ebp,%edi
c0027f45:	89 d9                	mov    %ebx,%ecx
c0027f47:	f2 ae                	repnz scas %es:(%edi),%al
c0027f49:	f7 d1                	not    %ecx
c0027f4b:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (haystack_len >= needle_len) 
c0027f4e:	39 fa                	cmp    %edi,%edx
c0027f50:	72 30                	jb     c0027f82 <strstr+0x61>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f52:	29 fa                	sub    %edi,%edx
c0027f54:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0027f58:	bb 00 00 00 00       	mov    $0x0,%ebx
c0027f5d:	89 de                	mov    %ebx,%esi
c0027f5f:	03 74 24 30          	add    0x30(%esp),%esi
        if (!memcmp (haystack + i, needle, needle_len))
c0027f63:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0027f67:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0027f6b:	89 34 24             	mov    %esi,(%esp)
c0027f6e:	e8 8a fa ff ff       	call   c00279fd <memcmp>
c0027f73:	85 c0                	test   %eax,%eax
c0027f75:	74 12                	je     c0027f89 <strstr+0x68>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f77:	83 c3 01             	add    $0x1,%ebx
c0027f7a:	3b 5c 24 0c          	cmp    0xc(%esp),%ebx
c0027f7e:	76 dd                	jbe    c0027f5d <strstr+0x3c>
c0027f80:	eb 0b                	jmp    c0027f8d <strstr+0x6c>
  return NULL;
c0027f82:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f87:	eb 09                	jmp    c0027f92 <strstr+0x71>
        if (!memcmp (haystack + i, needle, needle_len))
c0027f89:	89 f0                	mov    %esi,%eax
c0027f8b:	eb 05                	jmp    c0027f92 <strstr+0x71>
  return NULL;
c0027f8d:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027f92:	83 c4 1c             	add    $0x1c,%esp
c0027f95:	5b                   	pop    %ebx
c0027f96:	5e                   	pop    %esi
c0027f97:	5f                   	pop    %edi
c0027f98:	5d                   	pop    %ebp
c0027f99:	c3                   	ret    

c0027f9a <strnlen>:

/* If STRING is less than MAXLEN characters in length, returns
   its actual length.  Otherwise, returns MAXLEN. */
size_t
strnlen (const char *string, size_t maxlen) 
{
c0027f9a:	8b 54 24 04          	mov    0x4(%esp),%edx
c0027f9e:	8b 4c 24 08          	mov    0x8(%esp),%ecx
  size_t length;

  for (length = 0; string[length] != '\0' && length < maxlen; length++)
c0027fa2:	80 3a 00             	cmpb   $0x0,(%edx)
c0027fa5:	74 18                	je     c0027fbf <strnlen+0x25>
c0027fa7:	b8 00 00 00 00       	mov    $0x0,%eax
c0027fac:	85 c9                	test   %ecx,%ecx
c0027fae:	74 14                	je     c0027fc4 <strnlen+0x2a>
c0027fb0:	83 c0 01             	add    $0x1,%eax
c0027fb3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
c0027fb7:	74 0b                	je     c0027fc4 <strnlen+0x2a>
c0027fb9:	39 c8                	cmp    %ecx,%eax
c0027fbb:	74 07                	je     c0027fc4 <strnlen+0x2a>
c0027fbd:	eb f1                	jmp    c0027fb0 <strnlen+0x16>
c0027fbf:	b8 00 00 00 00       	mov    $0x0,%eax
    continue;
  return length;
}
c0027fc4:	f3 c3                	repz ret 

c0027fc6 <strlcpy>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcpy (char *dst, const char *src, size_t size) 
{
c0027fc6:	57                   	push   %edi
c0027fc7:	56                   	push   %esi
c0027fc8:	53                   	push   %ebx
c0027fc9:	83 ec 20             	sub    $0x20,%esp
c0027fcc:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027fd0:	8b 54 24 34          	mov    0x34(%esp),%edx
c0027fd4:	8b 74 24 38          	mov    0x38(%esp),%esi
  size_t src_len;

  ASSERT (dst != NULL);
c0027fd8:	85 db                	test   %ebx,%ebx
c0027fda:	75 2c                	jne    c0028008 <strlcpy+0x42>
c0027fdc:	c7 44 24 10 75 fa 02 	movl   $0xc002fa75,0x10(%esp)
c0027fe3:	c0 
c0027fe4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0027feb:	c0 
c0027fec:	c7 44 24 08 76 dc 02 	movl   $0xc002dc76,0x8(%esp)
c0027ff3:	c0 
c0027ff4:	c7 44 24 04 4a 01 00 	movl   $0x14a,0x4(%esp)
c0027ffb:	00 
c0027ffc:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0028003:	e8 ab 09 00 00       	call   c00289b3 <debug_panic>
  ASSERT (src != NULL);
c0028008:	85 d2                	test   %edx,%edx
c002800a:	75 2c                	jne    c0028038 <strlcpy+0x72>
c002800c:	c7 44 24 10 81 fa 02 	movl   $0xc002fa81,0x10(%esp)
c0028013:	c0 
c0028014:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002801b:	c0 
c002801c:	c7 44 24 08 76 dc 02 	movl   $0xc002dc76,0x8(%esp)
c0028023:	c0 
c0028024:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
c002802b:	00 
c002802c:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c0028033:	e8 7b 09 00 00       	call   c00289b3 <debug_panic>

  src_len = strlen (src);
c0028038:	89 d7                	mov    %edx,%edi
c002803a:	b8 00 00 00 00       	mov    $0x0,%eax
c002803f:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028044:	f2 ae                	repnz scas %es:(%edi),%al
c0028046:	f7 d1                	not    %ecx
c0028048:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (size > 0) 
c002804b:	85 f6                	test   %esi,%esi
c002804d:	74 1c                	je     c002806b <strlcpy+0xa5>
    {
      size_t dst_len = size - 1;
c002804f:	83 ee 01             	sub    $0x1,%esi
c0028052:	39 f7                	cmp    %esi,%edi
c0028054:	0f 46 f7             	cmovbe %edi,%esi
      if (src_len < dst_len)
        dst_len = src_len;
      memcpy (dst, src, dst_len);
c0028057:	89 74 24 08          	mov    %esi,0x8(%esp)
c002805b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002805f:	89 1c 24             	mov    %ebx,(%esp)
c0028062:	e8 29 f8 ff ff       	call   c0027890 <memcpy>
      dst[dst_len] = '\0';
c0028067:	c6 04 33 00          	movb   $0x0,(%ebx,%esi,1)
    }
  return src_len;
}
c002806b:	89 f8                	mov    %edi,%eax
c002806d:	83 c4 20             	add    $0x20,%esp
c0028070:	5b                   	pop    %ebx
c0028071:	5e                   	pop    %esi
c0028072:	5f                   	pop    %edi
c0028073:	c3                   	ret    

c0028074 <strlcat>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcat (char *dst, const char *src, size_t size) 
{
c0028074:	55                   	push   %ebp
c0028075:	57                   	push   %edi
c0028076:	56                   	push   %esi
c0028077:	53                   	push   %ebx
c0028078:	83 ec 2c             	sub    $0x2c,%esp
c002807b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
c002807f:	8b 54 24 44          	mov    0x44(%esp),%edx
  size_t src_len, dst_len;

  ASSERT (dst != NULL);
c0028083:	85 ed                	test   %ebp,%ebp
c0028085:	75 2c                	jne    c00280b3 <strlcat+0x3f>
c0028087:	c7 44 24 10 75 fa 02 	movl   $0xc002fa75,0x10(%esp)
c002808e:	c0 
c002808f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028096:	c0 
c0028097:	c7 44 24 08 6e dc 02 	movl   $0xc002dc6e,0x8(%esp)
c002809e:	c0 
c002809f:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
c00280a6:	00 
c00280a7:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00280ae:	e8 00 09 00 00       	call   c00289b3 <debug_panic>
  ASSERT (src != NULL);
c00280b3:	85 d2                	test   %edx,%edx
c00280b5:	75 2c                	jne    c00280e3 <strlcat+0x6f>
c00280b7:	c7 44 24 10 81 fa 02 	movl   $0xc002fa81,0x10(%esp)
c00280be:	c0 
c00280bf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00280c6:	c0 
c00280c7:	c7 44 24 08 6e dc 02 	movl   $0xc002dc6e,0x8(%esp)
c00280ce:	c0 
c00280cf:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
c00280d6:	00 
c00280d7:	c7 04 24 c3 f9 02 c0 	movl   $0xc002f9c3,(%esp)
c00280de:	e8 d0 08 00 00       	call   c00289b3 <debug_panic>

  src_len = strlen (src);
c00280e3:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c00280e8:	89 d7                	mov    %edx,%edi
c00280ea:	b8 00 00 00 00       	mov    $0x0,%eax
c00280ef:	89 d9                	mov    %ebx,%ecx
c00280f1:	f2 ae                	repnz scas %es:(%edi),%al
c00280f3:	f7 d1                	not    %ecx
c00280f5:	8d 71 ff             	lea    -0x1(%ecx),%esi
  dst_len = strlen (dst);
c00280f8:	89 ef                	mov    %ebp,%edi
c00280fa:	89 d9                	mov    %ebx,%ecx
c00280fc:	f2 ae                	repnz scas %es:(%edi),%al
c00280fe:	89 cb                	mov    %ecx,%ebx
c0028100:	f7 d3                	not    %ebx
c0028102:	83 eb 01             	sub    $0x1,%ebx
  if (size > 0 && dst_len < size) 
c0028105:	3b 5c 24 48          	cmp    0x48(%esp),%ebx
c0028109:	73 2c                	jae    c0028137 <strlcat+0xc3>
c002810b:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0028110:	74 25                	je     c0028137 <strlcat+0xc3>
    {
      size_t copy_cnt = size - dst_len - 1;
c0028112:	8b 44 24 48          	mov    0x48(%esp),%eax
c0028116:	8d 78 ff             	lea    -0x1(%eax),%edi
c0028119:	29 df                	sub    %ebx,%edi
c002811b:	39 f7                	cmp    %esi,%edi
c002811d:	0f 47 fe             	cmova  %esi,%edi
      if (src_len < copy_cnt)
        copy_cnt = src_len;
      memcpy (dst + dst_len, src, copy_cnt);
c0028120:	01 dd                	add    %ebx,%ebp
c0028122:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0028126:	89 54 24 04          	mov    %edx,0x4(%esp)
c002812a:	89 2c 24             	mov    %ebp,(%esp)
c002812d:	e8 5e f7 ff ff       	call   c0027890 <memcpy>
      dst[dst_len + copy_cnt] = '\0';
c0028132:	c6 44 3d 00 00       	movb   $0x0,0x0(%ebp,%edi,1)
    }
  return src_len + dst_len;
c0028137:	8d 04 33             	lea    (%ebx,%esi,1),%eax
}
c002813a:	83 c4 2c             	add    $0x2c,%esp
c002813d:	5b                   	pop    %ebx
c002813e:	5e                   	pop    %esi
c002813f:	5f                   	pop    %edi
c0028140:	5d                   	pop    %ebp
c0028141:	c3                   	ret    
c0028142:	90                   	nop
c0028143:	90                   	nop
c0028144:	90                   	nop
c0028145:	90                   	nop
c0028146:	90                   	nop
c0028147:	90                   	nop
c0028148:	90                   	nop
c0028149:	90                   	nop
c002814a:	90                   	nop
c002814b:	90                   	nop
c002814c:	90                   	nop
c002814d:	90                   	nop
c002814e:	90                   	nop
c002814f:	90                   	nop

c0028150 <udiv64>:

/* Divides unsigned 64-bit N by unsigned 64-bit D and returns the
   quotient. */
static uint64_t
udiv64 (uint64_t n, uint64_t d)
{
c0028150:	55                   	push   %ebp
c0028151:	57                   	push   %edi
c0028152:	56                   	push   %esi
c0028153:	53                   	push   %ebx
c0028154:	83 ec 1c             	sub    $0x1c,%esp
c0028157:	89 04 24             	mov    %eax,(%esp)
c002815a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002815e:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0028162:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  if ((d >> 32) == 0) 
c0028166:	89 ea                	mov    %ebp,%edx
c0028168:	85 ed                	test   %ebp,%ebp
c002816a:	75 37                	jne    c00281a3 <udiv64+0x53>
             <=> [b - 1/d] < b
         which is a tautology.

         Therefore, this code is correct and will not trap. */
      uint64_t b = 1ULL << 32;
      uint32_t n1 = n >> 32;
c002816c:	8b 44 24 04          	mov    0x4(%esp),%eax
      uint32_t n0 = n; 
      uint32_t d0 = d;

      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c0028170:	ba 00 00 00 00       	mov    $0x0,%edx
c0028175:	f7 f7                	div    %edi
c0028177:	89 c6                	mov    %eax,%esi
c0028179:	89 d3                	mov    %edx,%ebx
c002817b:	b9 00 00 00 00       	mov    $0x0,%ecx
c0028180:	8b 04 24             	mov    (%esp),%eax
c0028183:	ba 00 00 00 00       	mov    $0x0,%edx
c0028188:	01 c8                	add    %ecx,%eax
c002818a:	11 da                	adc    %ebx,%edx
  asm ("divl %4"
c002818c:	f7 f7                	div    %edi
      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c002818e:	ba 00 00 00 00       	mov    $0x0,%edx
c0028193:	89 f7                	mov    %esi,%edi
c0028195:	be 00 00 00 00       	mov    $0x0,%esi
c002819a:	01 f0                	add    %esi,%eax
c002819c:	11 fa                	adc    %edi,%edx
c002819e:	e9 f2 00 00 00       	jmp    c0028295 <udiv64+0x145>
    }
  else 
    {
      /* Based on the algorithm and proof available from
         http://www.hackersdelight.org/revisions.pdf. */
      if (n < d)
c00281a3:	3b 6c 24 04          	cmp    0x4(%esp),%ebp
c00281a7:	0f 87 d4 00 00 00    	ja     c0028281 <udiv64+0x131>
c00281ad:	72 09                	jb     c00281b8 <udiv64+0x68>
c00281af:	3b 3c 24             	cmp    (%esp),%edi
c00281b2:	0f 87 c9 00 00 00    	ja     c0028281 <udiv64+0x131>
        return 0;
      else 
        {
          uint32_t d1 = d >> 32;
c00281b8:	89 d0                	mov    %edx,%eax
  int n = 0;
c00281ba:	b9 00 00 00 00       	mov    $0x0,%ecx
  if (x <= 0x0000FFFF)
c00281bf:	81 fa ff ff 00 00    	cmp    $0xffff,%edx
c00281c5:	77 05                	ja     c00281cc <udiv64+0x7c>
      x <<= 16; 
c00281c7:	c1 e0 10             	shl    $0x10,%eax
      n += 16;
c00281ca:	b1 10                	mov    $0x10,%cl
  if (x <= 0x00FFFFFF)
c00281cc:	3d ff ff ff 00       	cmp    $0xffffff,%eax
c00281d1:	77 06                	ja     c00281d9 <udiv64+0x89>
      n += 8;
c00281d3:	83 c1 08             	add    $0x8,%ecx
      x <<= 8; 
c00281d6:	c1 e0 08             	shl    $0x8,%eax
  if (x <= 0x0FFFFFFF)
c00281d9:	3d ff ff ff 0f       	cmp    $0xfffffff,%eax
c00281de:	77 06                	ja     c00281e6 <udiv64+0x96>
      n += 4;
c00281e0:	83 c1 04             	add    $0x4,%ecx
      x <<= 4;
c00281e3:	c1 e0 04             	shl    $0x4,%eax
  if (x <= 0x3FFFFFFF)
c00281e6:	3d ff ff ff 3f       	cmp    $0x3fffffff,%eax
c00281eb:	77 06                	ja     c00281f3 <udiv64+0xa3>
      n += 2;
c00281ed:	83 c1 02             	add    $0x2,%ecx
      x <<= 2; 
c00281f0:	c1 e0 02             	shl    $0x2,%eax
    n++;
c00281f3:	3d 00 00 00 80       	cmp    $0x80000000,%eax
c00281f8:	83 d1 00             	adc    $0x0,%ecx
          int s = nlz (d1);
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c00281fb:	8b 04 24             	mov    (%esp),%eax
c00281fe:	8b 54 24 04          	mov    0x4(%esp),%edx
c0028202:	0f ac d0 01          	shrd   $0x1,%edx,%eax
c0028206:	d1 ea                	shr    %edx
c0028208:	89 fb                	mov    %edi,%ebx
c002820a:	89 ee                	mov    %ebp,%esi
c002820c:	0f a5 fe             	shld   %cl,%edi,%esi
c002820f:	d3 e3                	shl    %cl,%ebx
c0028211:	f6 c1 20             	test   $0x20,%cl
c0028214:	74 02                	je     c0028218 <udiv64+0xc8>
c0028216:	89 de                	mov    %ebx,%esi
c0028218:	89 74 24 0c          	mov    %esi,0xc(%esp)
  asm ("divl %4"
c002821c:	f7 74 24 0c          	divl   0xc(%esp)
c0028220:	89 c6                	mov    %eax,%esi
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c0028222:	b8 1f 00 00 00       	mov    $0x1f,%eax
c0028227:	29 c8                	sub    %ecx,%eax
c0028229:	89 c1                	mov    %eax,%ecx
c002822b:	d3 ee                	shr    %cl,%esi
c002822d:	89 74 24 10          	mov    %esi,0x10(%esp)
c0028231:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0028238:	00 
          return n - (q - 1) * d < d ? q - 1 : q; 
c0028239:	8b 44 24 10          	mov    0x10(%esp),%eax
c002823d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028241:	83 c0 ff             	add    $0xffffffff,%eax
c0028244:	83 d2 ff             	adc    $0xffffffff,%edx
c0028247:	89 44 24 08          	mov    %eax,0x8(%esp)
c002824b:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002824f:	89 c1                	mov    %eax,%ecx
c0028251:	0f af d7             	imul   %edi,%edx
c0028254:	0f af cd             	imul   %ebp,%ecx
c0028257:	8d 34 0a             	lea    (%edx,%ecx,1),%esi
c002825a:	8b 44 24 08          	mov    0x8(%esp),%eax
c002825e:	f7 e7                	mul    %edi
c0028260:	01 f2                	add    %esi,%edx
c0028262:	8b 1c 24             	mov    (%esp),%ebx
c0028265:	8b 74 24 04          	mov    0x4(%esp),%esi
c0028269:	29 c3                	sub    %eax,%ebx
c002826b:	19 d6                	sbb    %edx,%esi
c002826d:	39 f5                	cmp    %esi,%ebp
c002826f:	72 1c                	jb     c002828d <udiv64+0x13d>
c0028271:	77 04                	ja     c0028277 <udiv64+0x127>
c0028273:	39 df                	cmp    %ebx,%edi
c0028275:	76 16                	jbe    c002828d <udiv64+0x13d>
c0028277:	8b 44 24 08          	mov    0x8(%esp),%eax
c002827b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002827f:	eb 14                	jmp    c0028295 <udiv64+0x145>
        return 0;
c0028281:	b8 00 00 00 00       	mov    $0x0,%eax
c0028286:	ba 00 00 00 00       	mov    $0x0,%edx
c002828b:	eb 08                	jmp    c0028295 <udiv64+0x145>
          return n - (q - 1) * d < d ? q - 1 : q; 
c002828d:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028291:	8b 54 24 14          	mov    0x14(%esp),%edx
        }
    }
}
c0028295:	83 c4 1c             	add    $0x1c,%esp
c0028298:	5b                   	pop    %ebx
c0028299:	5e                   	pop    %esi
c002829a:	5f                   	pop    %edi
c002829b:	5d                   	pop    %ebp
c002829c:	c3                   	ret    

c002829d <sdiv64>:

/* Divides signed 64-bit N by signed 64-bit D and returns the
   quotient. */
static int64_t
sdiv64 (int64_t n, int64_t d)
{
c002829d:	57                   	push   %edi
c002829e:	56                   	push   %esi
c002829f:	53                   	push   %ebx
c00282a0:	83 ec 10             	sub    $0x10,%esp
c00282a3:	89 44 24 08          	mov    %eax,0x8(%esp)
c00282a7:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00282ab:	8b 74 24 20          	mov    0x20(%esp),%esi
c00282af:	8b 7c 24 24          	mov    0x24(%esp),%edi
  uint64_t n_abs = n >= 0 ? (uint64_t) n : -(uint64_t) n;
c00282b3:	85 d2                	test   %edx,%edx
c00282b5:	79 0f                	jns    c00282c6 <sdiv64+0x29>
c00282b7:	8b 44 24 08          	mov    0x8(%esp),%eax
c00282bb:	8b 54 24 0c          	mov    0xc(%esp),%edx
c00282bf:	f7 d8                	neg    %eax
c00282c1:	83 d2 00             	adc    $0x0,%edx
c00282c4:	f7 da                	neg    %edx
  uint64_t d_abs = d >= 0 ? (uint64_t) d : -(uint64_t) d;
c00282c6:	85 ff                	test   %edi,%edi
c00282c8:	78 06                	js     c00282d0 <sdiv64+0x33>
c00282ca:	89 f1                	mov    %esi,%ecx
c00282cc:	89 fb                	mov    %edi,%ebx
c00282ce:	eb 0b                	jmp    c00282db <sdiv64+0x3e>
c00282d0:	89 f1                	mov    %esi,%ecx
c00282d2:	89 fb                	mov    %edi,%ebx
c00282d4:	f7 d9                	neg    %ecx
c00282d6:	83 d3 00             	adc    $0x0,%ebx
c00282d9:	f7 db                	neg    %ebx
  uint64_t q_abs = udiv64 (n_abs, d_abs);
c00282db:	89 0c 24             	mov    %ecx,(%esp)
c00282de:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00282e2:	e8 69 fe ff ff       	call   c0028150 <udiv64>
  return (n < 0) == (d < 0) ? (int64_t) q_abs : -(int64_t) q_abs;
c00282e7:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
c00282eb:	f7 d1                	not    %ecx
c00282ed:	c1 e9 1f             	shr    $0x1f,%ecx
c00282f0:	89 fb                	mov    %edi,%ebx
c00282f2:	c1 eb 1f             	shr    $0x1f,%ebx
c00282f5:	89 c6                	mov    %eax,%esi
c00282f7:	89 d7                	mov    %edx,%edi
c00282f9:	f7 de                	neg    %esi
c00282fb:	83 d7 00             	adc    $0x0,%edi
c00282fe:	f7 df                	neg    %edi
c0028300:	39 cb                	cmp    %ecx,%ebx
c0028302:	74 04                	je     c0028308 <sdiv64+0x6b>
c0028304:	89 c6                	mov    %eax,%esi
c0028306:	89 d7                	mov    %edx,%edi
}
c0028308:	89 f0                	mov    %esi,%eax
c002830a:	89 fa                	mov    %edi,%edx
c002830c:	83 c4 10             	add    $0x10,%esp
c002830f:	5b                   	pop    %ebx
c0028310:	5e                   	pop    %esi
c0028311:	5f                   	pop    %edi
c0028312:	c3                   	ret    

c0028313 <__divdi3>:
unsigned long long __umoddi3 (unsigned long long n, unsigned long long d);

/* Signed 64-bit division. */
long long
__divdi3 (long long n, long long d) 
{
c0028313:	83 ec 0c             	sub    $0xc,%esp
  return sdiv64 (n, d);
c0028316:	8b 44 24 18          	mov    0x18(%esp),%eax
c002831a:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002831e:	89 04 24             	mov    %eax,(%esp)
c0028321:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028325:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028329:	8b 54 24 14          	mov    0x14(%esp),%edx
c002832d:	e8 6b ff ff ff       	call   c002829d <sdiv64>
}
c0028332:	83 c4 0c             	add    $0xc,%esp
c0028335:	c3                   	ret    

c0028336 <__moddi3>:

/* Signed 64-bit remainder. */
long long
__moddi3 (long long n, long long d) 
{
c0028336:	56                   	push   %esi
c0028337:	53                   	push   %ebx
c0028338:	83 ec 0c             	sub    $0xc,%esp
c002833b:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c002833f:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * sdiv64 (n, d);
c0028343:	89 34 24             	mov    %esi,(%esp)
c0028346:	8b 44 24 24          	mov    0x24(%esp),%eax
c002834a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002834e:	89 d8                	mov    %ebx,%eax
c0028350:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028354:	e8 44 ff ff ff       	call   c002829d <sdiv64>
c0028359:	0f af f0             	imul   %eax,%esi
c002835c:	89 d8                	mov    %ebx,%eax
c002835e:	29 f0                	sub    %esi,%eax
  return smod64 (n, d);
c0028360:	99                   	cltd   
}
c0028361:	83 c4 0c             	add    $0xc,%esp
c0028364:	5b                   	pop    %ebx
c0028365:	5e                   	pop    %esi
c0028366:	c3                   	ret    

c0028367 <__udivdi3>:

/* Unsigned 64-bit division. */
unsigned long long
__udivdi3 (unsigned long long n, unsigned long long d) 
{
c0028367:	83 ec 0c             	sub    $0xc,%esp
  return udiv64 (n, d);
c002836a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002836e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028372:	89 04 24             	mov    %eax,(%esp)
c0028375:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028379:	8b 44 24 10          	mov    0x10(%esp),%eax
c002837d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028381:	e8 ca fd ff ff       	call   c0028150 <udiv64>
}
c0028386:	83 c4 0c             	add    $0xc,%esp
c0028389:	c3                   	ret    

c002838a <__umoddi3>:

/* Unsigned 64-bit remainder. */
unsigned long long
__umoddi3 (unsigned long long n, unsigned long long d) 
{
c002838a:	56                   	push   %esi
c002838b:	53                   	push   %ebx
c002838c:	83 ec 0c             	sub    $0xc,%esp
c002838f:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c0028393:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * udiv64 (n, d);
c0028397:	89 34 24             	mov    %esi,(%esp)
c002839a:	8b 44 24 24          	mov    0x24(%esp),%eax
c002839e:	89 44 24 04          	mov    %eax,0x4(%esp)
c00283a2:	89 d8                	mov    %ebx,%eax
c00283a4:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00283a8:	e8 a3 fd ff ff       	call   c0028150 <udiv64>
c00283ad:	0f af f0             	imul   %eax,%esi
c00283b0:	89 d8                	mov    %ebx,%eax
c00283b2:	29 f0                	sub    %esi,%eax
  return umod64 (n, d);
c00283b4:	ba 00 00 00 00       	mov    $0x0,%edx
}
c00283b9:	83 c4 0c             	add    $0xc,%esp
c00283bc:	5b                   	pop    %ebx
c00283bd:	5e                   	pop    %esi
c00283be:	c3                   	ret    

c00283bf <parse_octal_field>:
   seems ambiguous as to whether these fields must be padded on
   the left with '0's, so we accept any field that fits in the
   available space, regardless of whether it fills the space. */
static bool
parse_octal_field (const char *s, size_t size, unsigned long int *value)
{
c00283bf:	55                   	push   %ebp
c00283c0:	57                   	push   %edi
c00283c1:	56                   	push   %esi
c00283c2:	53                   	push   %ebx
c00283c3:	83 ec 04             	sub    $0x4,%esp
c00283c6:	89 04 24             	mov    %eax,(%esp)
c00283c9:	89 d5                	mov    %edx,%ebp
  size_t ofs;

  *value = 0;
c00283cb:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
          return false;
        }
    }

  /* Field did not end in space or null byte. */
  return false;
c00283d1:	b8 00 00 00 00       	mov    $0x0,%eax
  for (ofs = 0; ofs < size; ofs++)
c00283d6:	85 d2                	test   %edx,%edx
c00283d8:	74 66                	je     c0028440 <parse_octal_field+0x81>
c00283da:	eb 45                	jmp    c0028421 <parse_octal_field+0x62>
      char c = s[ofs];
c00283dc:	8b 04 24             	mov    (%esp),%eax
c00283df:	0f b6 14 18          	movzbl (%eax,%ebx,1),%edx
      if (c >= '0' && c <= '7')
c00283e3:	8d 7a d0             	lea    -0x30(%edx),%edi
c00283e6:	89 f8                	mov    %edi,%eax
c00283e8:	3c 07                	cmp    $0x7,%al
c00283ea:	77 24                	ja     c0028410 <parse_octal_field+0x51>
          if (*value > ULONG_MAX / 8)
c00283ec:	81 fe ff ff ff 1f    	cmp    $0x1fffffff,%esi
c00283f2:	77 47                	ja     c002843b <parse_octal_field+0x7c>
          *value = c - '0' + *value * 8;
c00283f4:	0f be fa             	movsbl %dl,%edi
c00283f7:	8d 74 f7 d0          	lea    -0x30(%edi,%esi,8),%esi
c00283fb:	89 31                	mov    %esi,(%ecx)
  for (ofs = 0; ofs < size; ofs++)
c00283fd:	83 c3 01             	add    $0x1,%ebx
c0028400:	39 eb                	cmp    %ebp,%ebx
c0028402:	75 d8                	jne    c00283dc <parse_octal_field+0x1d>
  return false;
c0028404:	b8 00 00 00 00       	mov    $0x0,%eax
c0028409:	eb 35                	jmp    c0028440 <parse_octal_field+0x81>
  for (ofs = 0; ofs < size; ofs++)
c002840b:	bb 00 00 00 00       	mov    $0x0,%ebx
          return false;
c0028410:	b8 00 00 00 00       	mov    $0x0,%eax
      else if (c == ' ' || c == '\0')
c0028415:	f6 c2 df             	test   $0xdf,%dl
c0028418:	75 26                	jne    c0028440 <parse_octal_field+0x81>
          return ofs > 0;
c002841a:	85 db                	test   %ebx,%ebx
c002841c:	0f 95 c0             	setne  %al
c002841f:	eb 1f                	jmp    c0028440 <parse_octal_field+0x81>
      char c = s[ofs];
c0028421:	8b 04 24             	mov    (%esp),%eax
c0028424:	0f b6 10             	movzbl (%eax),%edx
      if (c >= '0' && c <= '7')
c0028427:	8d 5a d0             	lea    -0x30(%edx),%ebx
c002842a:	80 fb 07             	cmp    $0x7,%bl
c002842d:	77 dc                	ja     c002840b <parse_octal_field+0x4c>
          if (*value > ULONG_MAX / 8)
c002842f:	be 00 00 00 00       	mov    $0x0,%esi
  for (ofs = 0; ofs < size; ofs++)
c0028434:	bb 00 00 00 00       	mov    $0x0,%ebx
c0028439:	eb b9                	jmp    c00283f4 <parse_octal_field+0x35>
              return false;
c002843b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028440:	83 c4 04             	add    $0x4,%esp
c0028443:	5b                   	pop    %ebx
c0028444:	5e                   	pop    %esi
c0028445:	5f                   	pop    %edi
c0028446:	5d                   	pop    %ebp
c0028447:	c3                   	ret    

c0028448 <strip_antisocial_prefixes>:
{
c0028448:	57                   	push   %edi
c0028449:	56                   	push   %esi
c002844a:	53                   	push   %ebx
c002844b:	83 ec 10             	sub    $0x10,%esp
c002844e:	89 c3                	mov    %eax,%ebx
  while (*file_name == '/'
c0028450:	eb 13                	jmp    c0028465 <strip_antisocial_prefixes+0x1d>
    file_name = strchr (file_name, '/') + 1;
c0028452:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0028459:	00 
c002845a:	89 1c 24             	mov    %ebx,(%esp)
c002845d:	e8 84 f7 ff ff       	call   c0027be6 <strchr>
c0028462:	8d 58 01             	lea    0x1(%eax),%ebx
  while (*file_name == '/'
c0028465:	0f b6 33             	movzbl (%ebx),%esi
c0028468:	89 f0                	mov    %esi,%eax
c002846a:	3c 2f                	cmp    $0x2f,%al
c002846c:	74 e4                	je     c0028452 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "./", 2)
c002846e:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
c0028475:	00 
c0028476:	c7 44 24 04 25 ee 02 	movl   $0xc002ee25,0x4(%esp)
c002847d:	c0 
c002847e:	89 1c 24             	mov    %ebx,(%esp)
c0028481:	e8 77 f5 ff ff       	call   c00279fd <memcmp>
c0028486:	85 c0                	test   %eax,%eax
c0028488:	74 c8                	je     c0028452 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "../", 3))
c002848a:	c7 44 24 08 03 00 00 	movl   $0x3,0x8(%esp)
c0028491:	00 
c0028492:	c7 44 24 04 8d fa 02 	movl   $0xc002fa8d,0x4(%esp)
c0028499:	c0 
c002849a:	89 1c 24             	mov    %ebx,(%esp)
c002849d:	e8 5b f5 ff ff       	call   c00279fd <memcmp>
c00284a2:	85 c0                	test   %eax,%eax
c00284a4:	74 ac                	je     c0028452 <strip_antisocial_prefixes+0xa>
  return *file_name == '\0' || !strcmp (file_name, "..") ? "." : file_name;
c00284a6:	b8 ab f3 02 c0       	mov    $0xc002f3ab,%eax
c00284ab:	89 f2                	mov    %esi,%edx
c00284ad:	84 d2                	test   %dl,%dl
c00284af:	74 23                	je     c00284d4 <strip_antisocial_prefixes+0x8c>
c00284b1:	bf aa f3 02 c0       	mov    $0xc002f3aa,%edi
c00284b6:	b9 03 00 00 00       	mov    $0x3,%ecx
c00284bb:	89 de                	mov    %ebx,%esi
c00284bd:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00284bf:	0f 97 c0             	seta   %al
c00284c2:	0f 92 c2             	setb   %dl
c00284c5:	29 d0                	sub    %edx,%eax
c00284c7:	0f be c0             	movsbl %al,%eax
c00284ca:	85 c0                	test   %eax,%eax
c00284cc:	b8 ab f3 02 c0       	mov    $0xc002f3ab,%eax
c00284d1:	0f 45 c3             	cmovne %ebx,%eax
}
c00284d4:	83 c4 10             	add    $0x10,%esp
c00284d7:	5b                   	pop    %ebx
c00284d8:	5e                   	pop    %esi
c00284d9:	5f                   	pop    %edi
c00284da:	c3                   	ret    

c00284db <ustar_make_header>:
{
c00284db:	55                   	push   %ebp
c00284dc:	57                   	push   %edi
c00284dd:	56                   	push   %esi
c00284de:	53                   	push   %ebx
c00284df:	83 ec 2c             	sub    $0x2c,%esp
c00284e2:	8b 5c 24 4c          	mov    0x4c(%esp),%ebx
  ASSERT (type == USTAR_REGULAR || type == USTAR_DIRECTORY);
c00284e6:	83 7c 24 44 30       	cmpl   $0x30,0x44(%esp)
c00284eb:	0f 94 c0             	sete   %al
c00284ee:	89 c6                	mov    %eax,%esi
c00284f0:	88 44 24 1f          	mov    %al,0x1f(%esp)
c00284f4:	83 7c 24 44 35       	cmpl   $0x35,0x44(%esp)
c00284f9:	0f 94 c0             	sete   %al
c00284fc:	89 f2                	mov    %esi,%edx
c00284fe:	08 d0                	or     %dl,%al
c0028500:	75 2c                	jne    c002852e <ustar_make_header+0x53>
c0028502:	c7 44 24 10 78 fb 02 	movl   $0xc002fb78,0x10(%esp)
c0028509:	c0 
c002850a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028511:	c0 
c0028512:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028519:	c0 
c002851a:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c0028521:	00 
c0028522:	c7 04 24 91 fa 02 c0 	movl   $0xc002fa91,(%esp)
c0028529:	e8 85 04 00 00       	call   c00289b3 <debug_panic>
c002852e:	89 c5                	mov    %eax,%ebp
  file_name = strip_antisocial_prefixes (file_name);
c0028530:	8b 44 24 40          	mov    0x40(%esp),%eax
c0028534:	e8 0f ff ff ff       	call   c0028448 <strip_antisocial_prefixes>
c0028539:	89 c2                	mov    %eax,%edx
  if (strlen (file_name) > 99)
c002853b:	89 c7                	mov    %eax,%edi
c002853d:	b8 00 00 00 00       	mov    $0x0,%eax
c0028542:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028547:	f2 ae                	repnz scas %es:(%edi),%al
c0028549:	f7 d1                	not    %ecx
c002854b:	83 e9 01             	sub    $0x1,%ecx
c002854e:	83 f9 63             	cmp    $0x63,%ecx
c0028551:	76 1a                	jbe    c002856d <ustar_make_header+0x92>
      printf ("%s: file name too long\n", file_name);
c0028553:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028557:	c7 04 24 a3 fa 02 c0 	movl   $0xc002faa3,(%esp)
c002855e:	e8 fb e5 ff ff       	call   c0026b5e <printf>
      return false;
c0028563:	bd 00 00 00 00       	mov    $0x0,%ebp
c0028568:	e9 d0 01 00 00       	jmp    c002873d <ustar_make_header+0x262>
  memset (h, 0, sizeof *h);
c002856d:	89 df                	mov    %ebx,%edi
c002856f:	be 00 02 00 00       	mov    $0x200,%esi
c0028574:	f6 c3 01             	test   $0x1,%bl
c0028577:	74 0a                	je     c0028583 <ustar_make_header+0xa8>
c0028579:	c6 03 00             	movb   $0x0,(%ebx)
c002857c:	8d 7b 01             	lea    0x1(%ebx),%edi
c002857f:	66 be ff 01          	mov    $0x1ff,%si
c0028583:	f7 c7 02 00 00 00    	test   $0x2,%edi
c0028589:	74 0b                	je     c0028596 <ustar_make_header+0xbb>
c002858b:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0028590:	83 c7 02             	add    $0x2,%edi
c0028593:	83 ee 02             	sub    $0x2,%esi
c0028596:	89 f1                	mov    %esi,%ecx
c0028598:	c1 e9 02             	shr    $0x2,%ecx
c002859b:	b8 00 00 00 00       	mov    $0x0,%eax
c00285a0:	f3 ab                	rep stos %eax,%es:(%edi)
c00285a2:	f7 c6 02 00 00 00    	test   $0x2,%esi
c00285a8:	74 08                	je     c00285b2 <ustar_make_header+0xd7>
c00285aa:	66 c7 07 00 00       	movw   $0x0,(%edi)
c00285af:	83 c7 02             	add    $0x2,%edi
c00285b2:	f7 c6 01 00 00 00    	test   $0x1,%esi
c00285b8:	74 03                	je     c00285bd <ustar_make_header+0xe2>
c00285ba:	c6 07 00             	movb   $0x0,(%edi)
  strlcpy (h->name, file_name, sizeof h->name);
c00285bd:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c00285c4:	00 
c00285c5:	89 54 24 04          	mov    %edx,0x4(%esp)
c00285c9:	89 1c 24             	mov    %ebx,(%esp)
c00285cc:	e8 f5 f9 ff ff       	call   c0027fc6 <strlcpy>
  snprintf (h->mode, sizeof h->mode, "%07o",
c00285d1:	80 7c 24 1f 01       	cmpb   $0x1,0x1f(%esp)
c00285d6:	19 c0                	sbb    %eax,%eax
c00285d8:	83 e0 49             	and    $0x49,%eax
c00285db:	05 a4 01 00 00       	add    $0x1a4,%eax
c00285e0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00285e4:	c7 44 24 08 bb fa 02 	movl   $0xc002fabb,0x8(%esp)
c00285eb:	c0 
c00285ec:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c00285f3:	00 
c00285f4:	8d 43 64             	lea    0x64(%ebx),%eax
c00285f7:	89 04 24             	mov    %eax,(%esp)
c00285fa:	e8 60 ec ff ff       	call   c002725f <snprintf>
  strlcpy (h->uid, "0000000", sizeof h->uid);
c00285ff:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c0028606:	00 
c0028607:	c7 44 24 04 c0 fa 02 	movl   $0xc002fac0,0x4(%esp)
c002860e:	c0 
c002860f:	8d 43 6c             	lea    0x6c(%ebx),%eax
c0028612:	89 04 24             	mov    %eax,(%esp)
c0028615:	e8 ac f9 ff ff       	call   c0027fc6 <strlcpy>
  strlcpy (h->gid, "0000000", sizeof h->gid);
c002861a:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c0028621:	00 
c0028622:	c7 44 24 04 c0 fa 02 	movl   $0xc002fac0,0x4(%esp)
c0028629:	c0 
c002862a:	8d 43 74             	lea    0x74(%ebx),%eax
c002862d:	89 04 24             	mov    %eax,(%esp)
c0028630:	e8 91 f9 ff ff       	call   c0027fc6 <strlcpy>
  snprintf (h->size, sizeof h->size, "%011o", size);
c0028635:	8b 44 24 48          	mov    0x48(%esp),%eax
c0028639:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002863d:	c7 44 24 08 c8 fa 02 	movl   $0xc002fac8,0x8(%esp)
c0028644:	c0 
c0028645:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002864c:	00 
c002864d:	8d 43 7c             	lea    0x7c(%ebx),%eax
c0028650:	89 04 24             	mov    %eax,(%esp)
c0028653:	e8 07 ec ff ff       	call   c002725f <snprintf>
  snprintf (h->mtime, sizeof h->size, "%011o", 1136102400);
c0028658:	c7 44 24 0c 00 8c b7 	movl   $0x43b78c00,0xc(%esp)
c002865f:	43 
c0028660:	c7 44 24 08 c8 fa 02 	movl   $0xc002fac8,0x8(%esp)
c0028667:	c0 
c0028668:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002866f:	00 
c0028670:	8d 83 88 00 00 00    	lea    0x88(%ebx),%eax
c0028676:	89 04 24             	mov    %eax,(%esp)
c0028679:	e8 e1 eb ff ff       	call   c002725f <snprintf>
  h->typeflag = type;
c002867e:	0f b6 44 24 44       	movzbl 0x44(%esp),%eax
c0028683:	88 83 9c 00 00 00    	mov    %al,0x9c(%ebx)
  strlcpy (h->magic, "ustar", sizeof h->magic);
c0028689:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028690:	00 
c0028691:	c7 44 24 04 ce fa 02 	movl   $0xc002face,0x4(%esp)
c0028698:	c0 
c0028699:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002869f:	89 04 24             	mov    %eax,(%esp)
c00286a2:	e8 1f f9 ff ff       	call   c0027fc6 <strlcpy>
  h->version[0] = h->version[1] = '0';
c00286a7:	c6 83 08 01 00 00 30 	movb   $0x30,0x108(%ebx)
c00286ae:	c6 83 07 01 00 00 30 	movb   $0x30,0x107(%ebx)
  strlcpy (h->gname, "root", sizeof h->gname);
c00286b5:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c00286bc:	00 
c00286bd:	c7 44 24 04 dc ef 02 	movl   $0xc002efdc,0x4(%esp)
c00286c4:	c0 
c00286c5:	8d 83 29 01 00 00    	lea    0x129(%ebx),%eax
c00286cb:	89 04 24             	mov    %eax,(%esp)
c00286ce:	e8 f3 f8 ff ff       	call   c0027fc6 <strlcpy>
  strlcpy (h->uname, "root", sizeof h->uname);
c00286d3:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c00286da:	00 
c00286db:	c7 44 24 04 dc ef 02 	movl   $0xc002efdc,0x4(%esp)
c00286e2:	c0 
c00286e3:	8d 83 09 01 00 00    	lea    0x109(%ebx),%eax
c00286e9:	89 04 24             	mov    %eax,(%esp)
c00286ec:	e8 d5 f8 ff ff       	call   c0027fc6 <strlcpy>
c00286f1:	b8 6c ff ff ff       	mov    $0xffffff6c,%eax
  chksum = 0;
c00286f6:	ba 00 00 00 00       	mov    $0x0,%edx
      chksum += in_chksum_field ? ' ' : header[i];
c00286fb:	83 f8 07             	cmp    $0x7,%eax
c00286fe:	76 0a                	jbe    c002870a <ustar_make_header+0x22f>
c0028700:	0f b6 8c 03 94 00 00 	movzbl 0x94(%ebx,%eax,1),%ecx
c0028707:	00 
c0028708:	eb 05                	jmp    c002870f <ustar_make_header+0x234>
c002870a:	b9 20 00 00 00       	mov    $0x20,%ecx
c002870f:	01 ca                	add    %ecx,%edx
c0028711:	83 c0 01             	add    $0x1,%eax
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c0028714:	3d 6c 01 00 00       	cmp    $0x16c,%eax
c0028719:	75 e0                	jne    c00286fb <ustar_make_header+0x220>
  snprintf (h->chksum, sizeof h->chksum, "%07o", calculate_chksum (h));
c002871b:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002871f:	c7 44 24 08 bb fa 02 	movl   $0xc002fabb,0x8(%esp)
c0028726:	c0 
c0028727:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c002872e:	00 
c002872f:	81 c3 94 00 00 00    	add    $0x94,%ebx
c0028735:	89 1c 24             	mov    %ebx,(%esp)
c0028738:	e8 22 eb ff ff       	call   c002725f <snprintf>
}
c002873d:	89 e8                	mov    %ebp,%eax
c002873f:	83 c4 2c             	add    $0x2c,%esp
c0028742:	5b                   	pop    %ebx
c0028743:	5e                   	pop    %esi
c0028744:	5f                   	pop    %edi
c0028745:	5d                   	pop    %ebp
c0028746:	c3                   	ret    

c0028747 <ustar_parse_header>:
   and returns a null pointer.  On failure, returns a
   human-readable error message. */
const char *
ustar_parse_header (const char header[USTAR_HEADER_SIZE],
                    const char **file_name, enum ustar_type *type, int *size)
{
c0028747:	53                   	push   %ebx
c0028748:	83 ec 28             	sub    $0x28,%esp
c002874b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002874f:	8d 8b 00 02 00 00    	lea    0x200(%ebx),%ecx
c0028755:	89 da                	mov    %ebx,%edx
    if (*block++ != 0)
c0028757:	83 c2 01             	add    $0x1,%edx
c002875a:	80 7a ff 00          	cmpb   $0x0,-0x1(%edx)
c002875e:	0f 85 25 01 00 00    	jne    c0028889 <ustar_parse_header+0x142>
  while (cnt-- > 0)
c0028764:	39 ca                	cmp    %ecx,%edx
c0028766:	75 ef                	jne    c0028757 <ustar_parse_header+0x10>
c0028768:	e9 4b 01 00 00       	jmp    c00288b8 <ustar_parse_header+0x171>

  /* Validate ustar header. */
  if (memcmp (h->magic, "ustar", 6))
    return "not a ustar archive";
  else if (h->version[0] != '0' || h->version[1] != '0')
    return "invalid ustar version";
c002876d:	b8 e8 fa 02 c0       	mov    $0xc002fae8,%eax
  else if (h->version[0] != '0' || h->version[1] != '0')
c0028772:	80 bb 07 01 00 00 30 	cmpb   $0x30,0x107(%ebx)
c0028779:	0f 85 5c 01 00 00    	jne    c00288db <ustar_parse_header+0x194>
c002877f:	80 bb 08 01 00 00 30 	cmpb   $0x30,0x108(%ebx)
c0028786:	0f 85 4f 01 00 00    	jne    c00288db <ustar_parse_header+0x194>
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c002878c:	8d 83 94 00 00 00    	lea    0x94(%ebx),%eax
c0028792:	8d 4c 24 1c          	lea    0x1c(%esp),%ecx
c0028796:	ba 08 00 00 00       	mov    $0x8,%edx
c002879b:	e8 1f fc ff ff       	call   c00283bf <parse_octal_field>
c00287a0:	89 c2                	mov    %eax,%edx
    return "corrupt chksum field";
c00287a2:	b8 fe fa 02 c0       	mov    $0xc002fafe,%eax
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c00287a7:	84 d2                	test   %dl,%dl
c00287a9:	0f 84 2c 01 00 00    	je     c00288db <ustar_parse_header+0x194>
c00287af:	ba 6c ff ff ff       	mov    $0xffffff6c,%edx
c00287b4:	b9 00 00 00 00       	mov    $0x0,%ecx
      chksum += in_chksum_field ? ' ' : header[i];
c00287b9:	83 fa 07             	cmp    $0x7,%edx
c00287bc:	76 0a                	jbe    c00287c8 <ustar_parse_header+0x81>
c00287be:	0f b6 84 13 94 00 00 	movzbl 0x94(%ebx,%edx,1),%eax
c00287c5:	00 
c00287c6:	eb 05                	jmp    c00287cd <ustar_parse_header+0x86>
c00287c8:	b8 20 00 00 00       	mov    $0x20,%eax
c00287cd:	01 c1                	add    %eax,%ecx
c00287cf:	83 c2 01             	add    $0x1,%edx
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c00287d2:	81 fa 6c 01 00 00    	cmp    $0x16c,%edx
c00287d8:	75 df                	jne    c00287b9 <ustar_parse_header+0x72>
  else if (chksum != calculate_chksum (h))
    return "checksum mismatch";
c00287da:	b8 13 fb 02 c0       	mov    $0xc002fb13,%eax
  else if (chksum != calculate_chksum (h))
c00287df:	39 4c 24 1c          	cmp    %ecx,0x1c(%esp)
c00287e3:	0f 85 f2 00 00 00    	jne    c00288db <ustar_parse_header+0x194>
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
    return "file name too long";
c00287e9:	b8 25 fb 02 c0       	mov    $0xc002fb25,%eax
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
c00287ee:	80 7b 63 00          	cmpb   $0x0,0x63(%ebx)
c00287f2:	0f 85 e3 00 00 00    	jne    c00288db <ustar_parse_header+0x194>
c00287f8:	80 bb 59 01 00 00 00 	cmpb   $0x0,0x159(%ebx)
c00287ff:	0f 85 d6 00 00 00    	jne    c00288db <ustar_parse_header+0x194>
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c0028805:	0f b6 93 9c 00 00 00 	movzbl 0x9c(%ebx),%edx
c002880c:	80 fa 35             	cmp    $0x35,%dl
c002880f:	74 0e                	je     c002881f <ustar_parse_header+0xd8>
    return "unimplemented file type";
c0028811:	b8 38 fb 02 c0       	mov    $0xc002fb38,%eax
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c0028816:	80 fa 30             	cmp    $0x30,%dl
c0028819:	0f 85 bc 00 00 00    	jne    c00288db <ustar_parse_header+0x194>
  if (h->typeflag == USTAR_REGULAR)
c002881f:	80 fa 30             	cmp    $0x30,%dl
c0028822:	75 32                	jne    c0028856 <ustar_parse_header+0x10f>
    {
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c0028824:	8d 43 7c             	lea    0x7c(%ebx),%eax
c0028827:	8d 4c 24 18          	lea    0x18(%esp),%ecx
c002882b:	ba 0c 00 00 00       	mov    $0xc,%edx
c0028830:	e8 8a fb ff ff       	call   c00283bf <parse_octal_field>
c0028835:	89 c2                	mov    %eax,%edx
        return "corrupt file size field";
c0028837:	b8 50 fb 02 c0       	mov    $0xc002fb50,%eax
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c002883c:	84 d2                	test   %dl,%dl
c002883e:	0f 84 97 00 00 00    	je     c00288db <ustar_parse_header+0x194>
      else if (size_ul > INT_MAX)
        return "file too large";
c0028844:	b8 68 fb 02 c0       	mov    $0xc002fb68,%eax
      else if (size_ul > INT_MAX)
c0028849:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c002884e:	0f 88 87 00 00 00    	js     c00288db <ustar_parse_header+0x194>
c0028854:	eb 08                	jmp    c002885e <ustar_parse_header+0x117>
    }
  else
    size_ul = 0;
c0028856:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c002885d:	00 

  /* Success. */
  *file_name = strip_antisocial_prefixes (h->name);
c002885e:	89 d8                	mov    %ebx,%eax
c0028860:	e8 e3 fb ff ff       	call   c0028448 <strip_antisocial_prefixes>
c0028865:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0028869:	89 01                	mov    %eax,(%ecx)
  *type = h->typeflag;
c002886b:	0f be 83 9c 00 00 00 	movsbl 0x9c(%ebx),%eax
c0028872:	8b 5c 24 38          	mov    0x38(%esp),%ebx
c0028876:	89 03                	mov    %eax,(%ebx)
  *size = size_ul;
c0028878:	8b 44 24 18          	mov    0x18(%esp),%eax
c002887c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
c0028880:	89 03                	mov    %eax,(%ebx)
  return NULL;
c0028882:	b8 00 00 00 00       	mov    $0x0,%eax
c0028887:	eb 52                	jmp    c00288db <ustar_parse_header+0x194>
  if (memcmp (h->magic, "ustar", 6))
c0028889:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028890:	00 
c0028891:	c7 44 24 04 ce fa 02 	movl   $0xc002face,0x4(%esp)
c0028898:	c0 
c0028899:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002889f:	89 04 24             	mov    %eax,(%esp)
c00288a2:	e8 56 f1 ff ff       	call   c00279fd <memcmp>
c00288a7:	89 c2                	mov    %eax,%edx
    return "not a ustar archive";
c00288a9:	b8 d4 fa 02 c0       	mov    $0xc002fad4,%eax
  if (memcmp (h->magic, "ustar", 6))
c00288ae:	85 d2                	test   %edx,%edx
c00288b0:	0f 84 b7 fe ff ff    	je     c002876d <ustar_parse_header+0x26>
c00288b6:	eb 23                	jmp    c00288db <ustar_parse_header+0x194>
      *file_name = NULL;
c00288b8:	8b 44 24 34          	mov    0x34(%esp),%eax
c00288bc:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      *type = USTAR_EOF;
c00288c2:	8b 44 24 38          	mov    0x38(%esp),%eax
c00288c6:	c7 00 ff ff ff ff    	movl   $0xffffffff,(%eax)
      *size = 0;
c00288cc:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c00288d0:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      return NULL;
c00288d6:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00288db:	83 c4 28             	add    $0x28,%esp
c00288de:	5b                   	pop    %ebx
c00288df:	c3                   	ret    

c00288e0 <print_stacktrace>:

/* Print call stack of a thread.
   The thread may be running, ready, or blocked. */
static void
print_stacktrace(struct thread *t, void *aux UNUSED)
{
c00288e0:	55                   	push   %ebp
c00288e1:	89 e5                	mov    %esp,%ebp
c00288e3:	53                   	push   %ebx
c00288e4:	83 ec 14             	sub    $0x14,%esp
c00288e7:	8b 5d 08             	mov    0x8(%ebp),%ebx
  void *retaddr = NULL, **frame = NULL;
  const char *status = "UNKNOWN";

  switch (t->status) {
c00288ea:	8b 43 04             	mov    0x4(%ebx),%eax
    case THREAD_RUNNING:  
      status = "RUNNING";
      break;

    case THREAD_READY:  
      status = "READY";
c00288ed:	ba a9 fb 02 c0       	mov    $0xc002fba9,%edx
  switch (t->status) {
c00288f2:	83 f8 01             	cmp    $0x1,%eax
c00288f5:	74 1a                	je     c0028911 <print_stacktrace+0x31>
      status = "RUNNING";
c00288f7:	ba c9 e5 02 c0       	mov    $0xc002e5c9,%edx
  switch (t->status) {
c00288fc:	83 f8 01             	cmp    $0x1,%eax
c00288ff:	72 10                	jb     c0028911 <print_stacktrace+0x31>
c0028901:	83 f8 02             	cmp    $0x2,%eax
  const char *status = "UNKNOWN";
c0028904:	b8 af fb 02 c0       	mov    $0xc002fbaf,%eax
c0028909:	ba 83 e5 02 c0       	mov    $0xc002e583,%edx
c002890e:	0f 45 d0             	cmovne %eax,%edx

    default:
      break;
  }

  printf ("Call stack of thread `%s' (status %s):", t->name, status);
c0028911:	89 54 24 08          	mov    %edx,0x8(%esp)
c0028915:	8d 43 08             	lea    0x8(%ebx),%eax
c0028918:	89 44 24 04          	mov    %eax,0x4(%esp)
c002891c:	c7 04 24 d4 fb 02 c0 	movl   $0xc002fbd4,(%esp)
c0028923:	e8 36 e2 ff ff       	call   c0026b5e <printf>

  if (t == thread_current()) 
c0028928:	e8 ff 84 ff ff       	call   c0020e2c <thread_current>
c002892d:	39 d8                	cmp    %ebx,%eax
c002892f:	75 08                	jne    c0028939 <print_stacktrace+0x59>
    {
      frame = __builtin_frame_address (1);
c0028931:	8b 5d 00             	mov    0x0(%ebp),%ebx
      retaddr = __builtin_return_address (0);
c0028934:	8b 55 04             	mov    0x4(%ebp),%edx
c0028937:	eb 29                	jmp    c0028962 <print_stacktrace+0x82>
    {
      /* Retrieve the values of the base and instruction pointers
         as they were saved when this thread called switch_threads. */
      struct switch_threads_frame * saved_frame;

      saved_frame = (struct switch_threads_frame *)t->stack;
c0028939:	8b 43 18             	mov    0x18(%ebx),%eax
         list, but have never been scheduled.
         We can identify because their `stack' member either points 
         at the top of their kernel stack page, or the 
         switch_threads_frame's 'eip' member points at switch_entry.
         See also threads.c. */
      if (t->stack == (uint8_t *)t + PGSIZE || saved_frame->eip == switch_entry)
c002893c:	81 c3 00 10 00 00    	add    $0x1000,%ebx
c0028942:	39 d8                	cmp    %ebx,%eax
c0028944:	74 0b                	je     c0028951 <print_stacktrace+0x71>
c0028946:	8b 50 10             	mov    0x10(%eax),%edx
c0028949:	81 fa 5b 18 02 c0    	cmp    $0xc002185b,%edx
c002894f:	75 0e                	jne    c002895f <print_stacktrace+0x7f>
        {
          printf (" thread was never scheduled.\n");
c0028951:	c7 04 24 b7 fb 02 c0 	movl   $0xc002fbb7,(%esp)
c0028958:	e8 7e 1d 00 00       	call   c002a6db <puts>
          return;
c002895d:	eb 4e                	jmp    c00289ad <print_stacktrace+0xcd>
        }

      frame = (void **) saved_frame->ebp;
c002895f:	8b 58 08             	mov    0x8(%eax),%ebx
      retaddr = (void *) saved_frame->eip;
    }

  printf (" %p", retaddr);
c0028962:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028966:	c7 04 24 14 f8 02 c0 	movl   $0xc002f814,(%esp)
c002896d:	e8 ec e1 ff ff       	call   c0026b5e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028972:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0028978:	76 27                	jbe    c00289a1 <print_stacktrace+0xc1>
c002897a:	83 3b 00             	cmpl   $0x0,(%ebx)
c002897d:	74 22                	je     c00289a1 <print_stacktrace+0xc1>
    printf (" %p", frame[1]);
c002897f:	8b 43 04             	mov    0x4(%ebx),%eax
c0028982:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028986:	c7 04 24 14 f8 02 c0 	movl   $0xc002f814,(%esp)
c002898d:	e8 cc e1 ff ff       	call   c0026b5e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028992:	8b 1b                	mov    (%ebx),%ebx
c0028994:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c002899a:	76 05                	jbe    c00289a1 <print_stacktrace+0xc1>
c002899c:	83 3b 00             	cmpl   $0x0,(%ebx)
c002899f:	75 de                	jne    c002897f <print_stacktrace+0x9f>
  printf (".\n");
c00289a1:	c7 04 24 ab f3 02 c0 	movl   $0xc002f3ab,(%esp)
c00289a8:	e8 2e 1d 00 00       	call   c002a6db <puts>
}
c00289ad:	83 c4 14             	add    $0x14,%esp
c00289b0:	5b                   	pop    %ebx
c00289b1:	5d                   	pop    %ebp
c00289b2:	c3                   	ret    

c00289b3 <debug_panic>:
{
c00289b3:	57                   	push   %edi
c00289b4:	56                   	push   %esi
c00289b5:	53                   	push   %ebx
c00289b6:	83 ec 10             	sub    $0x10,%esp
c00289b9:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c00289bd:	8b 74 24 24          	mov    0x24(%esp),%esi
c00289c1:	8b 7c 24 28          	mov    0x28(%esp),%edi
  intr_disable ();
c00289c5:	e8 45 90 ff ff       	call   c0021a0f <intr_disable>
  console_panic ();
c00289ca:	e8 9d 1c 00 00       	call   c002a66c <console_panic>
  level++;
c00289cf:	a1 c0 7a 03 c0       	mov    0xc0037ac0,%eax
c00289d4:	83 c0 01             	add    $0x1,%eax
c00289d7:	a3 c0 7a 03 c0       	mov    %eax,0xc0037ac0
  if (level == 1) 
c00289dc:	83 f8 01             	cmp    $0x1,%eax
c00289df:	75 3f                	jne    c0028a20 <debug_panic+0x6d>
      printf ("Kernel PANIC at %s:%d in %s(): ", file, line, function);
c00289e1:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00289e5:	89 74 24 08          	mov    %esi,0x8(%esp)
c00289e9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00289ed:	c7 04 24 fc fb 02 c0 	movl   $0xc002fbfc,(%esp)
c00289f4:	e8 65 e1 ff ff       	call   c0026b5e <printf>
      va_start (args, message);
c00289f9:	8d 44 24 30          	lea    0x30(%esp),%eax
      vprintf (message, args);
c00289fd:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028a01:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c0028a05:	89 04 24             	mov    %eax,(%esp)
c0028a08:	e8 8d 1c 00 00       	call   c002a69a <vprintf>
      printf ("\n");
c0028a0d:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0028a14:	e8 33 1d 00 00       	call   c002a74c <putchar>
      debug_backtrace ();
c0028a19:	e8 73 db ff ff       	call   c0026591 <debug_backtrace>
c0028a1e:	eb 1d                	jmp    c0028a3d <debug_panic+0x8a>
  else if (level == 2)
c0028a20:	83 f8 02             	cmp    $0x2,%eax
c0028a23:	75 18                	jne    c0028a3d <debug_panic+0x8a>
    printf ("Kernel PANIC recursion at %s:%d in %s().\n",
c0028a25:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0028a29:	89 74 24 08          	mov    %esi,0x8(%esp)
c0028a2d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0028a31:	c7 04 24 1c fc 02 c0 	movl   $0xc002fc1c,(%esp)
c0028a38:	e8 21 e1 ff ff       	call   c0026b5e <printf>
  serial_flush ();
c0028a3d:	e8 8a c1 ff ff       	call   c0024bcc <serial_flush>
  shutdown ();
c0028a42:	e8 79 da ff ff       	call   c00264c0 <shutdown>
c0028a47:	eb fe                	jmp    c0028a47 <debug_panic+0x94>

c0028a49 <debug_backtrace_all>:

/* Prints call stack of all threads. */
void
debug_backtrace_all (void)
{
c0028a49:	53                   	push   %ebx
c0028a4a:	83 ec 18             	sub    $0x18,%esp
  enum intr_level oldlevel = intr_disable ();
c0028a4d:	e8 bd 8f ff ff       	call   c0021a0f <intr_disable>
c0028a52:	89 c3                	mov    %eax,%ebx

  thread_foreach (print_stacktrace, 0);
c0028a54:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0028a5b:	00 
c0028a5c:	c7 04 24 e0 88 02 c0 	movl   $0xc00288e0,(%esp)
c0028a63:	e8 a5 84 ff ff       	call   c0020f0d <thread_foreach>
  intr_set_level (oldlevel);
c0028a68:	89 1c 24             	mov    %ebx,(%esp)
c0028a6b:	e8 a6 8f ff ff       	call   c0021a16 <intr_set_level>
}
c0028a70:	83 c4 18             	add    $0x18,%esp
c0028a73:	5b                   	pop    %ebx
c0028a74:	c3                   	ret    
c0028a75:	90                   	nop
c0028a76:	90                   	nop
c0028a77:	90                   	nop
c0028a78:	90                   	nop
c0028a79:	90                   	nop
c0028a7a:	90                   	nop
c0028a7b:	90                   	nop
c0028a7c:	90                   	nop
c0028a7d:	90                   	nop
c0028a7e:	90                   	nop
c0028a7f:	90                   	nop

c0028a80 <list_init>:
}

/* Initializes LIST as an empty list. */
void
list_init (struct list *list)
{
c0028a80:	83 ec 2c             	sub    $0x2c,%esp
c0028a83:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028a87:	85 c0                	test   %eax,%eax
c0028a89:	75 2c                	jne    c0028ab7 <list_init+0x37>
c0028a8b:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028a92:	c0 
c0028a93:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028a9a:	c0 
c0028a9b:	c7 44 24 08 a5 dd 02 	movl   $0xc002dda5,0x8(%esp)
c0028aa2:	c0 
c0028aa3:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0028aaa:	00 
c0028aab:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028ab2:	e8 fc fe ff ff       	call   c00289b3 <debug_panic>
  list->head.prev = NULL;
c0028ab7:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  list->head.next = &list->tail;
c0028abd:	8d 50 08             	lea    0x8(%eax),%edx
c0028ac0:	89 50 04             	mov    %edx,0x4(%eax)
  list->tail.prev = &list->head;
c0028ac3:	89 40 08             	mov    %eax,0x8(%eax)
  list->tail.next = NULL;
c0028ac6:	c7 40 0c 00 00 00 00 	movl   $0x0,0xc(%eax)
}
c0028acd:	83 c4 2c             	add    $0x2c,%esp
c0028ad0:	c3                   	ret    

c0028ad1 <list_begin>:

/* Returns the beginning of LIST.  */
struct list_elem *
list_begin (struct list *list)
{
c0028ad1:	83 ec 2c             	sub    $0x2c,%esp
c0028ad4:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028ad8:	85 c0                	test   %eax,%eax
c0028ada:	75 2c                	jne    c0028b08 <list_begin+0x37>
c0028adc:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028ae3:	c0 
c0028ae4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028aeb:	c0 
c0028aec:	c7 44 24 08 9a dd 02 	movl   $0xc002dd9a,0x8(%esp)
c0028af3:	c0 
c0028af4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0028afb:	00 
c0028afc:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028b03:	e8 ab fe ff ff       	call   c00289b3 <debug_panic>
  return list->head.next;
c0028b08:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028b0b:	83 c4 2c             	add    $0x2c,%esp
c0028b0e:	c3                   	ret    

c0028b0f <list_next>:
/* Returns the element after ELEM in its list.  If ELEM is the
   last element in its list, returns the list tail.  Results are
   undefined if ELEM is itself a list tail. */
struct list_elem *
list_next (struct list_elem *elem)
{
c0028b0f:	83 ec 2c             	sub    $0x2c,%esp
c0028b12:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev == NULL && elem->next != NULL;
c0028b16:	85 c0                	test   %eax,%eax
c0028b18:	74 16                	je     c0028b30 <list_next+0x21>
c0028b1a:	83 38 00             	cmpl   $0x0,(%eax)
c0028b1d:	75 06                	jne    c0028b25 <list_next+0x16>
c0028b1f:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028b23:	75 37                	jne    c0028b5c <list_next+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028b25:	83 38 00             	cmpl   $0x0,(%eax)
c0028b28:	74 06                	je     c0028b30 <list_next+0x21>
c0028b2a:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028b2e:	75 2c                	jne    c0028b5c <list_next+0x4d>
  ASSERT (is_head (elem) || is_interior (elem));
c0028b30:	c7 44 24 10 fc fc 02 	movl   $0xc002fcfc,0x10(%esp)
c0028b37:	c0 
c0028b38:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028b3f:	c0 
c0028b40:	c7 44 24 08 90 dd 02 	movl   $0xc002dd90,0x8(%esp)
c0028b47:	c0 
c0028b48:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0028b4f:	00 
c0028b50:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028b57:	e8 57 fe ff ff       	call   c00289b3 <debug_panic>
  return elem->next;
c0028b5c:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028b5f:	83 c4 2c             	add    $0x2c,%esp
c0028b62:	c3                   	ret    

c0028b63 <list_end>:
   list_end() is often used in iterating through a list from
   front to back.  See the big comment at the top of list.h for
   an example. */
struct list_elem *
list_end (struct list *list)
{
c0028b63:	83 ec 2c             	sub    $0x2c,%esp
c0028b66:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b6a:	85 c0                	test   %eax,%eax
c0028b6c:	75 2c                	jne    c0028b9a <list_end+0x37>
c0028b6e:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028b75:	c0 
c0028b76:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028b7d:	c0 
c0028b7e:	c7 44 24 08 87 dd 02 	movl   $0xc002dd87,0x8(%esp)
c0028b85:	c0 
c0028b86:	c7 44 24 04 60 00 00 	movl   $0x60,0x4(%esp)
c0028b8d:	00 
c0028b8e:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028b95:	e8 19 fe ff ff       	call   c00289b3 <debug_panic>
  return &list->tail;
c0028b9a:	83 c0 08             	add    $0x8,%eax
}
c0028b9d:	83 c4 2c             	add    $0x2c,%esp
c0028ba0:	c3                   	ret    

c0028ba1 <list_rbegin>:

/* Returns the LIST's reverse beginning, for iterating through
   LIST in reverse order, from back to front. */
struct list_elem *
list_rbegin (struct list *list) 
{
c0028ba1:	83 ec 2c             	sub    $0x2c,%esp
c0028ba4:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028ba8:	85 c0                	test   %eax,%eax
c0028baa:	75 2c                	jne    c0028bd8 <list_rbegin+0x37>
c0028bac:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028bb3:	c0 
c0028bb4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028bbb:	c0 
c0028bbc:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0028bc3:	c0 
c0028bc4:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0028bcb:	00 
c0028bcc:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028bd3:	e8 db fd ff ff       	call   c00289b3 <debug_panic>
  return list->tail.prev;
c0028bd8:	8b 40 08             	mov    0x8(%eax),%eax
}
c0028bdb:	83 c4 2c             	add    $0x2c,%esp
c0028bde:	c3                   	ret    

c0028bdf <list_prev>:
/* Returns the element before ELEM in its list.  If ELEM is the
   first element in its list, returns the list head.  Results are
   undefined if ELEM is itself a list head. */
struct list_elem *
list_prev (struct list_elem *elem)
{
c0028bdf:	83 ec 2c             	sub    $0x2c,%esp
c0028be2:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028be6:	85 c0                	test   %eax,%eax
c0028be8:	74 16                	je     c0028c00 <list_prev+0x21>
c0028bea:	83 38 00             	cmpl   $0x0,(%eax)
c0028bed:	74 06                	je     c0028bf5 <list_prev+0x16>
c0028bef:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028bf3:	75 37                	jne    c0028c2c <list_prev+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028bf5:	83 38 00             	cmpl   $0x0,(%eax)
c0028bf8:	74 06                	je     c0028c00 <list_prev+0x21>
c0028bfa:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028bfe:	74 2c                	je     c0028c2c <list_prev+0x4d>
  ASSERT (is_interior (elem) || is_tail (elem));
c0028c00:	c7 44 24 10 24 fd 02 	movl   $0xc002fd24,0x10(%esp)
c0028c07:	c0 
c0028c08:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028c0f:	c0 
c0028c10:	c7 44 24 08 71 dd 02 	movl   $0xc002dd71,0x8(%esp)
c0028c17:	c0 
c0028c18:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c0028c1f:	00 
c0028c20:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028c27:	e8 87 fd ff ff       	call   c00289b3 <debug_panic>
  return elem->prev;
c0028c2c:	8b 00                	mov    (%eax),%eax
}
c0028c2e:	83 c4 2c             	add    $0x2c,%esp
c0028c31:	c3                   	ret    

c0028c32 <find_end_of_run>:
   run.
   A through B (exclusive) must form a non-empty range. */
static struct list_elem *
find_end_of_run (struct list_elem *a, struct list_elem *b,
                 list_less_func *less, void *aux)
{
c0028c32:	55                   	push   %ebp
c0028c33:	57                   	push   %edi
c0028c34:	56                   	push   %esi
c0028c35:	53                   	push   %ebx
c0028c36:	83 ec 2c             	sub    $0x2c,%esp
c0028c39:	89 c3                	mov    %eax,%ebx
c0028c3b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (a != NULL);
c0028c3f:	85 c0                	test   %eax,%eax
c0028c41:	75 2c                	jne    c0028c6f <find_end_of_run+0x3d>
c0028c43:	c7 44 24 10 59 ea 02 	movl   $0xc002ea59,0x10(%esp)
c0028c4a:	c0 
c0028c4b:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028c52:	c0 
c0028c53:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028c5a:	c0 
c0028c5b:	c7 44 24 04 6a 01 00 	movl   $0x16a,0x4(%esp)
c0028c62:	00 
c0028c63:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028c6a:	e8 44 fd ff ff       	call   c00289b3 <debug_panic>
c0028c6f:	89 d6                	mov    %edx,%esi
c0028c71:	89 cf                	mov    %ecx,%edi
  ASSERT (b != NULL);
c0028c73:	85 d2                	test   %edx,%edx
c0028c75:	75 2c                	jne    c0028ca3 <find_end_of_run+0x71>
c0028c77:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0028c7e:	c0 
c0028c7f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028c86:	c0 
c0028c87:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028c8e:	c0 
c0028c8f:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c0028c96:	00 
c0028c97:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028c9e:	e8 10 fd ff ff       	call   c00289b3 <debug_panic>
  ASSERT (less != NULL);
c0028ca3:	85 c9                	test   %ecx,%ecx
c0028ca5:	75 2c                	jne    c0028cd3 <find_end_of_run+0xa1>
c0028ca7:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c0028cae:	c0 
c0028caf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028cb6:	c0 
c0028cb7:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028cbe:	c0 
c0028cbf:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c0028cc6:	00 
c0028cc7:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028cce:	e8 e0 fc ff ff       	call   c00289b3 <debug_panic>
  ASSERT (a != b);
c0028cd3:	39 d0                	cmp    %edx,%eax
c0028cd5:	75 2c                	jne    c0028d03 <find_end_of_run+0xd1>
c0028cd7:	c7 44 24 10 78 fc 02 	movl   $0xc002fc78,0x10(%esp)
c0028cde:	c0 
c0028cdf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028ce6:	c0 
c0028ce7:	c7 44 24 08 00 dd 02 	movl   $0xc002dd00,0x8(%esp)
c0028cee:	c0 
c0028cef:	c7 44 24 04 6d 01 00 	movl   $0x16d,0x4(%esp)
c0028cf6:	00 
c0028cf7:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028cfe:	e8 b0 fc ff ff       	call   c00289b3 <debug_panic>
  
  do 
    {
      a = list_next (a);
c0028d03:	89 1c 24             	mov    %ebx,(%esp)
c0028d06:	e8 04 fe ff ff       	call   c0028b0f <list_next>
c0028d0b:	89 c3                	mov    %eax,%ebx
    }
  while (a != b && !less (a, list_prev (a), aux));
c0028d0d:	39 f0                	cmp    %esi,%eax
c0028d0f:	74 19                	je     c0028d2a <find_end_of_run+0xf8>
c0028d11:	89 04 24             	mov    %eax,(%esp)
c0028d14:	e8 c6 fe ff ff       	call   c0028bdf <list_prev>
c0028d19:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0028d1d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028d21:	89 1c 24             	mov    %ebx,(%esp)
c0028d24:	ff d7                	call   *%edi
c0028d26:	84 c0                	test   %al,%al
c0028d28:	74 d9                	je     c0028d03 <find_end_of_run+0xd1>
  return a;
}
c0028d2a:	89 d8                	mov    %ebx,%eax
c0028d2c:	83 c4 2c             	add    $0x2c,%esp
c0028d2f:	5b                   	pop    %ebx
c0028d30:	5e                   	pop    %esi
c0028d31:	5f                   	pop    %edi
c0028d32:	5d                   	pop    %ebp
c0028d33:	c3                   	ret    

c0028d34 <is_sorted>:
{
c0028d34:	55                   	push   %ebp
c0028d35:	57                   	push   %edi
c0028d36:	56                   	push   %esi
c0028d37:	53                   	push   %ebx
c0028d38:	83 ec 1c             	sub    $0x1c,%esp
c0028d3b:	89 c3                	mov    %eax,%ebx
c0028d3d:	89 d6                	mov    %edx,%esi
c0028d3f:	89 cd                	mov    %ecx,%ebp
c0028d41:	8b 7c 24 30          	mov    0x30(%esp),%edi
  if (a != b)
c0028d45:	39 d0                	cmp    %edx,%eax
c0028d47:	75 1b                	jne    c0028d64 <is_sorted+0x30>
c0028d49:	eb 2e                	jmp    c0028d79 <is_sorted+0x45>
      if (less (a, list_prev (a), aux))
c0028d4b:	89 1c 24             	mov    %ebx,(%esp)
c0028d4e:	e8 8c fe ff ff       	call   c0028bdf <list_prev>
c0028d53:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0028d57:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028d5b:	89 1c 24             	mov    %ebx,(%esp)
c0028d5e:	ff d5                	call   *%ebp
c0028d60:	84 c0                	test   %al,%al
c0028d62:	75 1c                	jne    c0028d80 <is_sorted+0x4c>
    while ((a = list_next (a)) != b) 
c0028d64:	89 1c 24             	mov    %ebx,(%esp)
c0028d67:	e8 a3 fd ff ff       	call   c0028b0f <list_next>
c0028d6c:	89 c3                	mov    %eax,%ebx
c0028d6e:	39 f0                	cmp    %esi,%eax
c0028d70:	75 d9                	jne    c0028d4b <is_sorted+0x17>
  return true;
c0028d72:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d77:	eb 0c                	jmp    c0028d85 <is_sorted+0x51>
c0028d79:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d7e:	eb 05                	jmp    c0028d85 <is_sorted+0x51>
        return false;
c0028d80:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028d85:	83 c4 1c             	add    $0x1c,%esp
c0028d88:	5b                   	pop    %ebx
c0028d89:	5e                   	pop    %esi
c0028d8a:	5f                   	pop    %edi
c0028d8b:	5d                   	pop    %ebp
c0028d8c:	c3                   	ret    

c0028d8d <list_rend>:
{
c0028d8d:	83 ec 2c             	sub    $0x2c,%esp
c0028d90:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028d94:	85 c0                	test   %eax,%eax
c0028d96:	75 2c                	jne    c0028dc4 <list_rend+0x37>
c0028d98:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028d9f:	c0 
c0028da0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028da7:	c0 
c0028da8:	c7 44 24 08 67 dd 02 	movl   $0xc002dd67,0x8(%esp)
c0028daf:	c0 
c0028db0:	c7 44 24 04 87 00 00 	movl   $0x87,0x4(%esp)
c0028db7:	00 
c0028db8:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028dbf:	e8 ef fb ff ff       	call   c00289b3 <debug_panic>
}
c0028dc4:	83 c4 2c             	add    $0x2c,%esp
c0028dc7:	c3                   	ret    

c0028dc8 <list_head>:
{
c0028dc8:	83 ec 2c             	sub    $0x2c,%esp
c0028dcb:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028dcf:	85 c0                	test   %eax,%eax
c0028dd1:	75 2c                	jne    c0028dff <list_head+0x37>
c0028dd3:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028dda:	c0 
c0028ddb:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028de2:	c0 
c0028de3:	c7 44 24 08 5d dd 02 	movl   $0xc002dd5d,0x8(%esp)
c0028dea:	c0 
c0028deb:	c7 44 24 04 99 00 00 	movl   $0x99,0x4(%esp)
c0028df2:	00 
c0028df3:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028dfa:	e8 b4 fb ff ff       	call   c00289b3 <debug_panic>
}
c0028dff:	83 c4 2c             	add    $0x2c,%esp
c0028e02:	c3                   	ret    

c0028e03 <list_tail>:
{
c0028e03:	83 ec 2c             	sub    $0x2c,%esp
c0028e06:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028e0a:	85 c0                	test   %eax,%eax
c0028e0c:	75 2c                	jne    c0028e3a <list_tail+0x37>
c0028e0e:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0028e15:	c0 
c0028e16:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028e1d:	c0 
c0028e1e:	c7 44 24 08 53 dd 02 	movl   $0xc002dd53,0x8(%esp)
c0028e25:	c0 
c0028e26:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c0028e2d:	00 
c0028e2e:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028e35:	e8 79 fb ff ff       	call   c00289b3 <debug_panic>
  return &list->tail;
c0028e3a:	83 c0 08             	add    $0x8,%eax
}
c0028e3d:	83 c4 2c             	add    $0x2c,%esp
c0028e40:	c3                   	ret    

c0028e41 <list_insert>:
{
c0028e41:	83 ec 2c             	sub    $0x2c,%esp
c0028e44:	8b 44 24 30          	mov    0x30(%esp),%eax
c0028e48:	8b 54 24 34          	mov    0x34(%esp),%edx
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028e4c:	85 c0                	test   %eax,%eax
c0028e4e:	74 56                	je     c0028ea6 <list_insert+0x65>
c0028e50:	83 38 00             	cmpl   $0x0,(%eax)
c0028e53:	74 06                	je     c0028e5b <list_insert+0x1a>
c0028e55:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e59:	75 0b                	jne    c0028e66 <list_insert+0x25>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028e5b:	83 38 00             	cmpl   $0x0,(%eax)
c0028e5e:	74 46                	je     c0028ea6 <list_insert+0x65>
c0028e60:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e64:	75 40                	jne    c0028ea6 <list_insert+0x65>
  ASSERT (elem != NULL);
c0028e66:	85 d2                	test   %edx,%edx
c0028e68:	75 2c                	jne    c0028e96 <list_insert+0x55>
c0028e6a:	c7 44 24 10 7f fc 02 	movl   $0xc002fc7f,0x10(%esp)
c0028e71:	c0 
c0028e72:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028e79:	c0 
c0028e7a:	c7 44 24 08 47 dd 02 	movl   $0xc002dd47,0x8(%esp)
c0028e81:	c0 
c0028e82:	c7 44 24 04 ac 00 00 	movl   $0xac,0x4(%esp)
c0028e89:	00 
c0028e8a:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028e91:	e8 1d fb ff ff       	call   c00289b3 <debug_panic>
  elem->prev = before->prev;
c0028e96:	8b 08                	mov    (%eax),%ecx
c0028e98:	89 0a                	mov    %ecx,(%edx)
  elem->next = before;
c0028e9a:	89 42 04             	mov    %eax,0x4(%edx)
  before->prev->next = elem;
c0028e9d:	8b 08                	mov    (%eax),%ecx
c0028e9f:	89 51 04             	mov    %edx,0x4(%ecx)
  before->prev = elem;
c0028ea2:	89 10                	mov    %edx,(%eax)
c0028ea4:	eb 2c                	jmp    c0028ed2 <list_insert+0x91>
  ASSERT (is_interior (before) || is_tail (before));
c0028ea6:	c7 44 24 10 4c fd 02 	movl   $0xc002fd4c,0x10(%esp)
c0028ead:	c0 
c0028eae:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028eb5:	c0 
c0028eb6:	c7 44 24 08 47 dd 02 	movl   $0xc002dd47,0x8(%esp)
c0028ebd:	c0 
c0028ebe:	c7 44 24 04 ab 00 00 	movl   $0xab,0x4(%esp)
c0028ec5:	00 
c0028ec6:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028ecd:	e8 e1 fa ff ff       	call   c00289b3 <debug_panic>
}
c0028ed2:	83 c4 2c             	add    $0x2c,%esp
c0028ed5:	c3                   	ret    

c0028ed6 <list_splice>:
{
c0028ed6:	56                   	push   %esi
c0028ed7:	53                   	push   %ebx
c0028ed8:	83 ec 24             	sub    $0x24,%esp
c0028edb:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0028edf:	8b 74 24 34          	mov    0x34(%esp),%esi
c0028ee3:	8b 44 24 38          	mov    0x38(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ee7:	85 db                	test   %ebx,%ebx
c0028ee9:	74 4d                	je     c0028f38 <list_splice+0x62>
c0028eeb:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028eee:	74 06                	je     c0028ef6 <list_splice+0x20>
c0028ef0:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028ef4:	75 0b                	jne    c0028f01 <list_splice+0x2b>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028ef6:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028ef9:	74 3d                	je     c0028f38 <list_splice+0x62>
c0028efb:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028eff:	75 37                	jne    c0028f38 <list_splice+0x62>
  if (first == last)
c0028f01:	39 c6                	cmp    %eax,%esi
c0028f03:	0f 84 cf 00 00 00    	je     c0028fd8 <list_splice+0x102>
  last = list_prev (last);
c0028f09:	89 04 24             	mov    %eax,(%esp)
c0028f0c:	e8 ce fc ff ff       	call   c0028bdf <list_prev>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028f11:	85 f6                	test   %esi,%esi
c0028f13:	74 4f                	je     c0028f64 <list_splice+0x8e>
c0028f15:	8b 16                	mov    (%esi),%edx
c0028f17:	85 d2                	test   %edx,%edx
c0028f19:	74 49                	je     c0028f64 <list_splice+0x8e>
c0028f1b:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0028f1f:	75 6f                	jne    c0028f90 <list_splice+0xba>
c0028f21:	eb 41                	jmp    c0028f64 <list_splice+0x8e>
c0028f23:	83 38 00             	cmpl   $0x0,(%eax)
c0028f26:	74 6c                	je     c0028f94 <list_splice+0xbe>
c0028f28:	8b 48 04             	mov    0x4(%eax),%ecx
c0028f2b:	85 c9                	test   %ecx,%ecx
c0028f2d:	8d 76 00             	lea    0x0(%esi),%esi
c0028f30:	0f 85 8a 00 00 00    	jne    c0028fc0 <list_splice+0xea>
c0028f36:	eb 5c                	jmp    c0028f94 <list_splice+0xbe>
  ASSERT (is_interior (before) || is_tail (before));
c0028f38:	c7 44 24 10 4c fd 02 	movl   $0xc002fd4c,0x10(%esp)
c0028f3f:	c0 
c0028f40:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028f47:	c0 
c0028f48:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028f4f:	c0 
c0028f50:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c0028f57:	00 
c0028f58:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028f5f:	e8 4f fa ff ff       	call   c00289b3 <debug_panic>
  ASSERT (is_interior (first));
c0028f64:	c7 44 24 10 8c fc 02 	movl   $0xc002fc8c,0x10(%esp)
c0028f6b:	c0 
c0028f6c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028f73:	c0 
c0028f74:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028f7b:	c0 
c0028f7c:	c7 44 24 04 c0 00 00 	movl   $0xc0,0x4(%esp)
c0028f83:	00 
c0028f84:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028f8b:	e8 23 fa ff ff       	call   c00289b3 <debug_panic>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028f90:	85 c0                	test   %eax,%eax
c0028f92:	75 8f                	jne    c0028f23 <list_splice+0x4d>
  ASSERT (is_interior (last));
c0028f94:	c7 44 24 10 a0 fc 02 	movl   $0xc002fca0,0x10(%esp)
c0028f9b:	c0 
c0028f9c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0028fa3:	c0 
c0028fa4:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028fab:	c0 
c0028fac:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0028fb3:	00 
c0028fb4:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0028fbb:	e8 f3 f9 ff ff       	call   c00289b3 <debug_panic>
  first->prev->next = last->next;
c0028fc0:	89 4a 04             	mov    %ecx,0x4(%edx)
  last->next->prev = first->prev;
c0028fc3:	8b 50 04             	mov    0x4(%eax),%edx
c0028fc6:	8b 0e                	mov    (%esi),%ecx
c0028fc8:	89 0a                	mov    %ecx,(%edx)
  first->prev = before->prev;
c0028fca:	8b 13                	mov    (%ebx),%edx
c0028fcc:	89 16                	mov    %edx,(%esi)
  last->next = before;
c0028fce:	89 58 04             	mov    %ebx,0x4(%eax)
  before->prev->next = first;
c0028fd1:	8b 13                	mov    (%ebx),%edx
c0028fd3:	89 72 04             	mov    %esi,0x4(%edx)
  before->prev = last;
c0028fd6:	89 03                	mov    %eax,(%ebx)
}
c0028fd8:	83 c4 24             	add    $0x24,%esp
c0028fdb:	5b                   	pop    %ebx
c0028fdc:	5e                   	pop    %esi
c0028fdd:	c3                   	ret    

c0028fde <list_push_front>:
{
c0028fde:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_begin (list), elem);
c0028fe1:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028fe5:	89 04 24             	mov    %eax,(%esp)
c0028fe8:	e8 e4 fa ff ff       	call   c0028ad1 <list_begin>
c0028fed:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028ff1:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028ff5:	89 04 24             	mov    %eax,(%esp)
c0028ff8:	e8 44 fe ff ff       	call   c0028e41 <list_insert>
}
c0028ffd:	83 c4 1c             	add    $0x1c,%esp
c0029000:	c3                   	ret    

c0029001 <list_push_back>:
{
c0029001:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_end (list), elem);
c0029004:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029008:	89 04 24             	mov    %eax,(%esp)
c002900b:	e8 53 fb ff ff       	call   c0028b63 <list_end>
c0029010:	8b 54 24 24          	mov    0x24(%esp),%edx
c0029014:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029018:	89 04 24             	mov    %eax,(%esp)
c002901b:	e8 21 fe ff ff       	call   c0028e41 <list_insert>
}
c0029020:	83 c4 1c             	add    $0x1c,%esp
c0029023:	c3                   	ret    

c0029024 <list_remove>:
{
c0029024:	83 ec 2c             	sub    $0x2c,%esp
c0029027:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c002902b:	85 c0                	test   %eax,%eax
c002902d:	74 0d                	je     c002903c <list_remove+0x18>
c002902f:	8b 10                	mov    (%eax),%edx
c0029031:	85 d2                	test   %edx,%edx
c0029033:	74 07                	je     c002903c <list_remove+0x18>
c0029035:	8b 48 04             	mov    0x4(%eax),%ecx
c0029038:	85 c9                	test   %ecx,%ecx
c002903a:	75 2c                	jne    c0029068 <list_remove+0x44>
  ASSERT (is_interior (elem));
c002903c:	c7 44 24 10 b3 fc 02 	movl   $0xc002fcb3,0x10(%esp)
c0029043:	c0 
c0029044:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002904b:	c0 
c002904c:	c7 44 24 08 2f dd 02 	movl   $0xc002dd2f,0x8(%esp)
c0029053:	c0 
c0029054:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
c002905b:	00 
c002905c:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029063:	e8 4b f9 ff ff       	call   c00289b3 <debug_panic>
  elem->prev->next = elem->next;
c0029068:	89 4a 04             	mov    %ecx,0x4(%edx)
  elem->next->prev = elem->prev;
c002906b:	8b 50 04             	mov    0x4(%eax),%edx
c002906e:	8b 08                	mov    (%eax),%ecx
c0029070:	89 0a                	mov    %ecx,(%edx)
  return elem->next;
c0029072:	8b 40 04             	mov    0x4(%eax),%eax
}
c0029075:	83 c4 2c             	add    $0x2c,%esp
c0029078:	c3                   	ret    

c0029079 <list_size>:
{
c0029079:	57                   	push   %edi
c002907a:	56                   	push   %esi
c002907b:	53                   	push   %ebx
c002907c:	83 ec 10             	sub    $0x10,%esp
c002907f:	8b 7c 24 20          	mov    0x20(%esp),%edi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029083:	89 3c 24             	mov    %edi,(%esp)
c0029086:	e8 46 fa ff ff       	call   c0028ad1 <list_begin>
c002908b:	89 c3                	mov    %eax,%ebx
  size_t cnt = 0;
c002908d:	be 00 00 00 00       	mov    $0x0,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029092:	eb 0d                	jmp    c00290a1 <list_size+0x28>
    cnt++;
c0029094:	83 c6 01             	add    $0x1,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029097:	89 1c 24             	mov    %ebx,(%esp)
c002909a:	e8 70 fa ff ff       	call   c0028b0f <list_next>
c002909f:	89 c3                	mov    %eax,%ebx
c00290a1:	89 3c 24             	mov    %edi,(%esp)
c00290a4:	e8 ba fa ff ff       	call   c0028b63 <list_end>
c00290a9:	39 d8                	cmp    %ebx,%eax
c00290ab:	75 e7                	jne    c0029094 <list_size+0x1b>
}
c00290ad:	89 f0                	mov    %esi,%eax
c00290af:	83 c4 10             	add    $0x10,%esp
c00290b2:	5b                   	pop    %ebx
c00290b3:	5e                   	pop    %esi
c00290b4:	5f                   	pop    %edi
c00290b5:	c3                   	ret    

c00290b6 <list_empty>:
{
c00290b6:	56                   	push   %esi
c00290b7:	53                   	push   %ebx
c00290b8:	83 ec 14             	sub    $0x14,%esp
c00290bb:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  return list_begin (list) == list_end (list);
c00290bf:	89 1c 24             	mov    %ebx,(%esp)
c00290c2:	e8 0a fa ff ff       	call   c0028ad1 <list_begin>
c00290c7:	89 c6                	mov    %eax,%esi
c00290c9:	89 1c 24             	mov    %ebx,(%esp)
c00290cc:	e8 92 fa ff ff       	call   c0028b63 <list_end>
c00290d1:	39 c6                	cmp    %eax,%esi
c00290d3:	0f 94 c0             	sete   %al
}
c00290d6:	83 c4 14             	add    $0x14,%esp
c00290d9:	5b                   	pop    %ebx
c00290da:	5e                   	pop    %esi
c00290db:	c3                   	ret    

c00290dc <list_front>:
{
c00290dc:	53                   	push   %ebx
c00290dd:	83 ec 28             	sub    $0x28,%esp
c00290e0:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c00290e4:	89 1c 24             	mov    %ebx,(%esp)
c00290e7:	e8 ca ff ff ff       	call   c00290b6 <list_empty>
c00290ec:	84 c0                	test   %al,%al
c00290ee:	74 2c                	je     c002911c <list_front+0x40>
c00290f0:	c7 44 24 10 c6 fc 02 	movl   $0xc002fcc6,0x10(%esp)
c00290f7:	c0 
c00290f8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00290ff:	c0 
c0029100:	c7 44 24 08 24 dd 02 	movl   $0xc002dd24,0x8(%esp)
c0029107:	c0 
c0029108:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c002910f:	00 
c0029110:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029117:	e8 97 f8 ff ff       	call   c00289b3 <debug_panic>
  return list->head.next;
c002911c:	8b 43 04             	mov    0x4(%ebx),%eax
}
c002911f:	83 c4 28             	add    $0x28,%esp
c0029122:	5b                   	pop    %ebx
c0029123:	c3                   	ret    

c0029124 <list_pop_front>:
{
c0029124:	53                   	push   %ebx
c0029125:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *front = list_front (list);
c0029128:	8b 44 24 20          	mov    0x20(%esp),%eax
c002912c:	89 04 24             	mov    %eax,(%esp)
c002912f:	e8 a8 ff ff ff       	call   c00290dc <list_front>
c0029134:	89 c3                	mov    %eax,%ebx
  list_remove (front);
c0029136:	89 04 24             	mov    %eax,(%esp)
c0029139:	e8 e6 fe ff ff       	call   c0029024 <list_remove>
}
c002913e:	89 d8                	mov    %ebx,%eax
c0029140:	83 c4 18             	add    $0x18,%esp
c0029143:	5b                   	pop    %ebx
c0029144:	c3                   	ret    

c0029145 <list_back>:
{
c0029145:	53                   	push   %ebx
c0029146:	83 ec 28             	sub    $0x28,%esp
c0029149:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c002914d:	89 1c 24             	mov    %ebx,(%esp)
c0029150:	e8 61 ff ff ff       	call   c00290b6 <list_empty>
c0029155:	84 c0                	test   %al,%al
c0029157:	74 2c                	je     c0029185 <list_back+0x40>
c0029159:	c7 44 24 10 c6 fc 02 	movl   $0xc002fcc6,0x10(%esp)
c0029160:	c0 
c0029161:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029168:	c0 
c0029169:	c7 44 24 08 1a dd 02 	movl   $0xc002dd1a,0x8(%esp)
c0029170:	c0 
c0029171:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
c0029178:	00 
c0029179:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029180:	e8 2e f8 ff ff       	call   c00289b3 <debug_panic>
  return list->tail.prev;
c0029185:	8b 43 08             	mov    0x8(%ebx),%eax
}
c0029188:	83 c4 28             	add    $0x28,%esp
c002918b:	5b                   	pop    %ebx
c002918c:	c3                   	ret    

c002918d <list_pop_back>:
{
c002918d:	53                   	push   %ebx
c002918e:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *back = list_back (list);
c0029191:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029195:	89 04 24             	mov    %eax,(%esp)
c0029198:	e8 a8 ff ff ff       	call   c0029145 <list_back>
c002919d:	89 c3                	mov    %eax,%ebx
  list_remove (back);
c002919f:	89 04 24             	mov    %eax,(%esp)
c00291a2:	e8 7d fe ff ff       	call   c0029024 <list_remove>
}
c00291a7:	89 d8                	mov    %ebx,%eax
c00291a9:	83 c4 18             	add    $0x18,%esp
c00291ac:	5b                   	pop    %ebx
c00291ad:	c3                   	ret    

c00291ae <list_reverse>:
{
c00291ae:	56                   	push   %esi
c00291af:	53                   	push   %ebx
c00291b0:	83 ec 14             	sub    $0x14,%esp
c00291b3:	8b 74 24 20          	mov    0x20(%esp),%esi
  if (!list_empty (list)) 
c00291b7:	89 34 24             	mov    %esi,(%esp)
c00291ba:	e8 f7 fe ff ff       	call   c00290b6 <list_empty>
c00291bf:	84 c0                	test   %al,%al
c00291c1:	75 3a                	jne    c00291fd <list_reverse+0x4f>
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c00291c3:	89 34 24             	mov    %esi,(%esp)
c00291c6:	e8 06 f9 ff ff       	call   c0028ad1 <list_begin>
c00291cb:	89 c3                	mov    %eax,%ebx
c00291cd:	eb 0c                	jmp    c00291db <list_reverse+0x2d>
  struct list_elem *t = *a;
c00291cf:	8b 13                	mov    (%ebx),%edx
  *a = *b;
c00291d1:	8b 43 04             	mov    0x4(%ebx),%eax
c00291d4:	89 03                	mov    %eax,(%ebx)
  *b = t;
c00291d6:	89 53 04             	mov    %edx,0x4(%ebx)
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c00291d9:	89 c3                	mov    %eax,%ebx
c00291db:	89 34 24             	mov    %esi,(%esp)
c00291de:	e8 80 f9 ff ff       	call   c0028b63 <list_end>
c00291e3:	39 d8                	cmp    %ebx,%eax
c00291e5:	75 e8                	jne    c00291cf <list_reverse+0x21>
  struct list_elem *t = *a;
c00291e7:	8b 46 04             	mov    0x4(%esi),%eax
  *a = *b;
c00291ea:	8b 56 08             	mov    0x8(%esi),%edx
c00291ed:	89 56 04             	mov    %edx,0x4(%esi)
  *b = t;
c00291f0:	89 46 08             	mov    %eax,0x8(%esi)
  struct list_elem *t = *a;
c00291f3:	8b 0a                	mov    (%edx),%ecx
  *a = *b;
c00291f5:	8b 58 04             	mov    0x4(%eax),%ebx
c00291f8:	89 1a                	mov    %ebx,(%edx)
  *b = t;
c00291fa:	89 48 04             	mov    %ecx,0x4(%eax)
}
c00291fd:	83 c4 14             	add    $0x14,%esp
c0029200:	5b                   	pop    %ebx
c0029201:	5e                   	pop    %esi
c0029202:	c3                   	ret    

c0029203 <list_sort>:
/* Sorts LIST according to LESS given auxiliary data AUX, using a
   natural iterative merge sort that runs in O(n lg n) time and
   O(1) space in the number of elements in LIST. */
void
list_sort (struct list *list, list_less_func *less, void *aux)
{
c0029203:	55                   	push   %ebp
c0029204:	57                   	push   %edi
c0029205:	56                   	push   %esi
c0029206:	53                   	push   %ebx
c0029207:	83 ec 2c             	sub    $0x2c,%esp
c002920a:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c002920e:	8b 7c 24 48          	mov    0x48(%esp),%edi
  size_t output_run_cnt;        /* Number of runs output in current pass. */

  ASSERT (list != NULL);
c0029212:	83 7c 24 40 00       	cmpl   $0x0,0x40(%esp)
c0029217:	75 2c                	jne    c0029245 <list_sort+0x42>
c0029219:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c0029220:	c0 
c0029221:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029228:	c0 
c0029229:	c7 44 24 08 10 dd 02 	movl   $0xc002dd10,0x8(%esp)
c0029230:	c0 
c0029231:	c7 44 24 04 9a 01 00 	movl   $0x19a,0x4(%esp)
c0029238:	00 
c0029239:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029240:	e8 6e f7 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (less != NULL);
c0029245:	85 ed                	test   %ebp,%ebp
c0029247:	75 2c                	jne    c0029275 <list_sort+0x72>
c0029249:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c0029250:	c0 
c0029251:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029258:	c0 
c0029259:	c7 44 24 08 10 dd 02 	movl   $0xc002dd10,0x8(%esp)
c0029260:	c0 
c0029261:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c0029268:	00 
c0029269:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029270:	e8 3e f7 ff ff       	call   c00289b3 <debug_panic>
      struct list_elem *a0;     /* Start of first run. */
      struct list_elem *a1b0;   /* End of first run, start of second. */
      struct list_elem *b1;     /* End of second run. */

      output_run_cnt = 0;
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0029275:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029279:	89 04 24             	mov    %eax,(%esp)
c002927c:	e8 50 f8 ff ff       	call   c0028ad1 <list_begin>
c0029281:	89 c6                	mov    %eax,%esi
      output_run_cnt = 0;
c0029283:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002928a:	00 
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c002928b:	e9 99 01 00 00       	jmp    c0029429 <list_sort+0x226>
        {
          /* Each iteration produces one output run. */
          output_run_cnt++;
c0029290:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)

          /* Locate two adjacent runs of nondecreasing elements
             A0...A1B0 and A1B0...B1. */
          a1b0 = find_end_of_run (a0, list_end (list), less, aux);
c0029295:	89 3c 24             	mov    %edi,(%esp)
c0029298:	89 e9                	mov    %ebp,%ecx
c002929a:	89 c2                	mov    %eax,%edx
c002929c:	89 f0                	mov    %esi,%eax
c002929e:	e8 8f f9 ff ff       	call   c0028c32 <find_end_of_run>
c00292a3:	89 c3                	mov    %eax,%ebx
          if (a1b0 == list_end (list))
c00292a5:	8b 44 24 40          	mov    0x40(%esp),%eax
c00292a9:	89 04 24             	mov    %eax,(%esp)
c00292ac:	e8 b2 f8 ff ff       	call   c0028b63 <list_end>
c00292b1:	39 d8                	cmp    %ebx,%eax
c00292b3:	0f 84 84 01 00 00    	je     c002943d <list_sort+0x23a>
            break;
          b1 = find_end_of_run (a1b0, list_end (list), less, aux);
c00292b9:	89 3c 24             	mov    %edi,(%esp)
c00292bc:	89 e9                	mov    %ebp,%ecx
c00292be:	89 c2                	mov    %eax,%edx
c00292c0:	89 d8                	mov    %ebx,%eax
c00292c2:	e8 6b f9 ff ff       	call   c0028c32 <find_end_of_run>
c00292c7:	89 44 24 18          	mov    %eax,0x18(%esp)
  ASSERT (a0 != NULL);
c00292cb:	85 f6                	test   %esi,%esi
c00292cd:	75 2c                	jne    c00292fb <list_sort+0xf8>
c00292cf:	c7 44 24 10 d9 fc 02 	movl   $0xc002fcd9,0x10(%esp)
c00292d6:	c0 
c00292d7:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00292de:	c0 
c00292df:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c00292e6:	c0 
c00292e7:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
c00292ee:	00 
c00292ef:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00292f6:	e8 b8 f6 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (a1b0 != NULL);
c00292fb:	85 db                	test   %ebx,%ebx
c00292fd:	75 2c                	jne    c002932b <list_sort+0x128>
c00292ff:	c7 44 24 10 e4 fc 02 	movl   $0xc002fce4,0x10(%esp)
c0029306:	c0 
c0029307:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002930e:	c0 
c002930f:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c0029316:	c0 
c0029317:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
c002931e:	00 
c002931f:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029326:	e8 88 f6 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (b1 != NULL);
c002932b:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c0029330:	75 2c                	jne    c002935e <list_sort+0x15b>
c0029332:	c7 44 24 10 f1 fc 02 	movl   $0xc002fcf1,0x10(%esp)
c0029339:	c0 
c002933a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029341:	c0 
c0029342:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c0029349:	c0 
c002934a:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
c0029351:	00 
c0029352:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029359:	e8 55 f6 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (is_sorted (a0, a1b0, less, aux));
c002935e:	89 3c 24             	mov    %edi,(%esp)
c0029361:	89 e9                	mov    %ebp,%ecx
c0029363:	89 da                	mov    %ebx,%edx
c0029365:	89 f0                	mov    %esi,%eax
c0029367:	e8 c8 f9 ff ff       	call   c0028d34 <is_sorted>
c002936c:	84 c0                	test   %al,%al
c002936e:	75 2c                	jne    c002939c <list_sort+0x199>
c0029370:	c7 44 24 10 78 fd 02 	movl   $0xc002fd78,0x10(%esp)
c0029377:	c0 
c0029378:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002937f:	c0 
c0029380:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c0029387:	c0 
c0029388:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
c002938f:	00 
c0029390:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029397:	e8 17 f6 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (is_sorted (a1b0, b1, less, aux));
c002939c:	89 3c 24             	mov    %edi,(%esp)
c002939f:	89 e9                	mov    %ebp,%ecx
c00293a1:	8b 54 24 18          	mov    0x18(%esp),%edx
c00293a5:	89 d8                	mov    %ebx,%eax
c00293a7:	e8 88 f9 ff ff       	call   c0028d34 <is_sorted>
c00293ac:	84 c0                	test   %al,%al
c00293ae:	75 6b                	jne    c002941b <list_sort+0x218>
c00293b0:	c7 44 24 10 98 fd 02 	movl   $0xc002fd98,0x10(%esp)
c00293b7:	c0 
c00293b8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00293bf:	c0 
c00293c0:	c7 44 24 08 f2 dc 02 	movl   $0xc002dcf2,0x8(%esp)
c00293c7:	c0 
c00293c8:	c7 44 24 04 86 01 00 	movl   $0x186,0x4(%esp)
c00293cf:	00 
c00293d0:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00293d7:	e8 d7 f5 ff ff       	call   c00289b3 <debug_panic>
    if (!less (a1b0, a0, aux)) 
c00293dc:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00293e0:	89 74 24 04          	mov    %esi,0x4(%esp)
c00293e4:	89 1c 24             	mov    %ebx,(%esp)
c00293e7:	ff d5                	call   *%ebp
c00293e9:	84 c0                	test   %al,%al
c00293eb:	75 0c                	jne    c00293f9 <list_sort+0x1f6>
      a0 = list_next (a0);
c00293ed:	89 34 24             	mov    %esi,(%esp)
c00293f0:	e8 1a f7 ff ff       	call   c0028b0f <list_next>
c00293f5:	89 c6                	mov    %eax,%esi
c00293f7:	eb 22                	jmp    c002941b <list_sort+0x218>
        a1b0 = list_next (a1b0);
c00293f9:	89 1c 24             	mov    %ebx,(%esp)
c00293fc:	e8 0e f7 ff ff       	call   c0028b0f <list_next>
c0029401:	89 c3                	mov    %eax,%ebx
        list_splice (a0, list_prev (a1b0), a1b0);
c0029403:	89 04 24             	mov    %eax,(%esp)
c0029406:	e8 d4 f7 ff ff       	call   c0028bdf <list_prev>
c002940b:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002940f:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029413:	89 34 24             	mov    %esi,(%esp)
c0029416:	e8 bb fa ff ff       	call   c0028ed6 <list_splice>
  while (a0 != a1b0 && a1b0 != b1)
c002941b:	39 5c 24 18          	cmp    %ebx,0x18(%esp)
c002941f:	74 04                	je     c0029425 <list_sort+0x222>
c0029421:	39 f3                	cmp    %esi,%ebx
c0029423:	75 b7                	jne    c00293dc <list_sort+0x1d9>
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0029425:	8b 74 24 18          	mov    0x18(%esp),%esi
c0029429:	8b 44 24 40          	mov    0x40(%esp),%eax
c002942d:	89 04 24             	mov    %eax,(%esp)
c0029430:	e8 2e f7 ff ff       	call   c0028b63 <list_end>
c0029435:	39 f0                	cmp    %esi,%eax
c0029437:	0f 85 53 fe ff ff    	jne    c0029290 <list_sort+0x8d>

          /* Merge the runs. */
          inplace_merge (a0, a1b0, b1, less, aux);
        }
    }
  while (output_run_cnt > 1);
c002943d:	83 7c 24 1c 01       	cmpl   $0x1,0x1c(%esp)
c0029442:	0f 87 2d fe ff ff    	ja     c0029275 <list_sort+0x72>

  ASSERT (is_sorted (list_begin (list), list_end (list), less, aux));
c0029448:	8b 44 24 40          	mov    0x40(%esp),%eax
c002944c:	89 04 24             	mov    %eax,(%esp)
c002944f:	e8 0f f7 ff ff       	call   c0028b63 <list_end>
c0029454:	89 c3                	mov    %eax,%ebx
c0029456:	8b 44 24 40          	mov    0x40(%esp),%eax
c002945a:	89 04 24             	mov    %eax,(%esp)
c002945d:	e8 6f f6 ff ff       	call   c0028ad1 <list_begin>
c0029462:	89 3c 24             	mov    %edi,(%esp)
c0029465:	89 e9                	mov    %ebp,%ecx
c0029467:	89 da                	mov    %ebx,%edx
c0029469:	e8 c6 f8 ff ff       	call   c0028d34 <is_sorted>
c002946e:	84 c0                	test   %al,%al
c0029470:	75 2c                	jne    c002949e <list_sort+0x29b>
c0029472:	c7 44 24 10 b8 fd 02 	movl   $0xc002fdb8,0x10(%esp)
c0029479:	c0 
c002947a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029481:	c0 
c0029482:	c7 44 24 08 10 dd 02 	movl   $0xc002dd10,0x8(%esp)
c0029489:	c0 
c002948a:	c7 44 24 04 b8 01 00 	movl   $0x1b8,0x4(%esp)
c0029491:	00 
c0029492:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029499:	e8 15 f5 ff ff       	call   c00289b3 <debug_panic>
}
c002949e:	83 c4 2c             	add    $0x2c,%esp
c00294a1:	5b                   	pop    %ebx
c00294a2:	5e                   	pop    %esi
c00294a3:	5f                   	pop    %edi
c00294a4:	5d                   	pop    %ebp
c00294a5:	c3                   	ret    

c00294a6 <list_insert_ordered>:
   sorted according to LESS given auxiliary data AUX.
   Runs in O(n) average case in the number of elements in LIST. */
void
list_insert_ordered (struct list *list, struct list_elem *elem,
                     list_less_func *less, void *aux)
{
c00294a6:	55                   	push   %ebp
c00294a7:	57                   	push   %edi
c00294a8:	56                   	push   %esi
c00294a9:	53                   	push   %ebx
c00294aa:	83 ec 2c             	sub    $0x2c,%esp
c00294ad:	8b 74 24 40          	mov    0x40(%esp),%esi
c00294b1:	8b 7c 24 44          	mov    0x44(%esp),%edi
c00294b5:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *e;

  ASSERT (list != NULL);
c00294b9:	85 f6                	test   %esi,%esi
c00294bb:	75 2c                	jne    c00294e9 <list_insert_ordered+0x43>
c00294bd:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c00294c4:	c0 
c00294c5:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00294cc:	c0 
c00294cd:	c7 44 24 08 de dc 02 	movl   $0xc002dcde,0x8(%esp)
c00294d4:	c0 
c00294d5:	c7 44 24 04 c4 01 00 	movl   $0x1c4,0x4(%esp)
c00294dc:	00 
c00294dd:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00294e4:	e8 ca f4 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (elem != NULL);
c00294e9:	85 ff                	test   %edi,%edi
c00294eb:	75 2c                	jne    c0029519 <list_insert_ordered+0x73>
c00294ed:	c7 44 24 10 7f fc 02 	movl   $0xc002fc7f,0x10(%esp)
c00294f4:	c0 
c00294f5:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00294fc:	c0 
c00294fd:	c7 44 24 08 de dc 02 	movl   $0xc002dcde,0x8(%esp)
c0029504:	c0 
c0029505:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
c002950c:	00 
c002950d:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029514:	e8 9a f4 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (less != NULL);
c0029519:	85 ed                	test   %ebp,%ebp
c002951b:	75 2c                	jne    c0029549 <list_insert_ordered+0xa3>
c002951d:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c0029524:	c0 
c0029525:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002952c:	c0 
c002952d:	c7 44 24 08 de dc 02 	movl   $0xc002dcde,0x8(%esp)
c0029534:	c0 
c0029535:	c7 44 24 04 c6 01 00 	movl   $0x1c6,0x4(%esp)
c002953c:	00 
c002953d:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c0029544:	e8 6a f4 ff ff       	call   c00289b3 <debug_panic>

  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029549:	89 34 24             	mov    %esi,(%esp)
c002954c:	e8 80 f5 ff ff       	call   c0028ad1 <list_begin>
c0029551:	89 c3                	mov    %eax,%ebx
c0029553:	eb 1f                	jmp    c0029574 <list_insert_ordered+0xce>
    if (less (elem, e, aux))
c0029555:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029559:	89 44 24 08          	mov    %eax,0x8(%esp)
c002955d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029561:	89 3c 24             	mov    %edi,(%esp)
c0029564:	ff d5                	call   *%ebp
c0029566:	84 c0                	test   %al,%al
c0029568:	75 16                	jne    c0029580 <list_insert_ordered+0xda>
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c002956a:	89 1c 24             	mov    %ebx,(%esp)
c002956d:	e8 9d f5 ff ff       	call   c0028b0f <list_next>
c0029572:	89 c3                	mov    %eax,%ebx
c0029574:	89 34 24             	mov    %esi,(%esp)
c0029577:	e8 e7 f5 ff ff       	call   c0028b63 <list_end>
c002957c:	39 d8                	cmp    %ebx,%eax
c002957e:	75 d5                	jne    c0029555 <list_insert_ordered+0xaf>
      break;
  return list_insert (e, elem);
c0029580:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029584:	89 1c 24             	mov    %ebx,(%esp)
c0029587:	e8 b5 f8 ff ff       	call   c0028e41 <list_insert>
}
c002958c:	83 c4 2c             	add    $0x2c,%esp
c002958f:	5b                   	pop    %ebx
c0029590:	5e                   	pop    %esi
c0029591:	5f                   	pop    %edi
c0029592:	5d                   	pop    %ebp
c0029593:	c3                   	ret    

c0029594 <list_unique>:
   given auxiliary data AUX.  If DUPLICATES is non-null, then the
   elements from LIST are appended to DUPLICATES. */
void
list_unique (struct list *list, struct list *duplicates,
             list_less_func *less, void *aux)
{
c0029594:	55                   	push   %ebp
c0029595:	57                   	push   %edi
c0029596:	56                   	push   %esi
c0029597:	53                   	push   %ebx
c0029598:	83 ec 2c             	sub    $0x2c,%esp
c002959b:	8b 7c 24 40          	mov    0x40(%esp),%edi
c002959f:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *elem, *next;

  ASSERT (list != NULL);
c00295a3:	85 ff                	test   %edi,%edi
c00295a5:	75 2c                	jne    c00295d3 <list_unique+0x3f>
c00295a7:	c7 44 24 10 46 fc 02 	movl   $0xc002fc46,0x10(%esp)
c00295ae:	c0 
c00295af:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00295b6:	c0 
c00295b7:	c7 44 24 08 d2 dc 02 	movl   $0xc002dcd2,0x8(%esp)
c00295be:	c0 
c00295bf:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
c00295c6:	00 
c00295c7:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00295ce:	e8 e0 f3 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (less != NULL);
c00295d3:	85 ed                	test   %ebp,%ebp
c00295d5:	75 2c                	jne    c0029603 <list_unique+0x6f>
c00295d7:	c7 44 24 10 6b fc 02 	movl   $0xc002fc6b,0x10(%esp)
c00295de:	c0 
c00295df:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00295e6:	c0 
c00295e7:	c7 44 24 08 d2 dc 02 	movl   $0xc002dcd2,0x8(%esp)
c00295ee:	c0 
c00295ef:	c7 44 24 04 d9 01 00 	movl   $0x1d9,0x4(%esp)
c00295f6:	00 
c00295f7:	c7 04 24 53 fc 02 c0 	movl   $0xc002fc53,(%esp)
c00295fe:	e8 b0 f3 ff ff       	call   c00289b3 <debug_panic>
  if (list_empty (list))
c0029603:	89 3c 24             	mov    %edi,(%esp)
c0029606:	e8 ab fa ff ff       	call   c00290b6 <list_empty>
c002960b:	84 c0                	test   %al,%al
c002960d:	75 73                	jne    c0029682 <list_unique+0xee>
    return;

  elem = list_begin (list);
c002960f:	89 3c 24             	mov    %edi,(%esp)
c0029612:	e8 ba f4 ff ff       	call   c0028ad1 <list_begin>
c0029617:	89 c6                	mov    %eax,%esi
  while ((next = list_next (elem)) != list_end (list))
c0029619:	eb 51                	jmp    c002966c <list_unique+0xd8>
    if (!less (elem, next, aux) && !less (next, elem, aux)) 
c002961b:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c002961f:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029623:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029627:	89 34 24             	mov    %esi,(%esp)
c002962a:	ff d5                	call   *%ebp
c002962c:	84 c0                	test   %al,%al
c002962e:	75 3a                	jne    c002966a <list_unique+0xd6>
c0029630:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029634:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029638:	89 74 24 04          	mov    %esi,0x4(%esp)
c002963c:	89 1c 24             	mov    %ebx,(%esp)
c002963f:	ff d5                	call   *%ebp
c0029641:	84 c0                	test   %al,%al
c0029643:	75 25                	jne    c002966a <list_unique+0xd6>
      {
        list_remove (next);
c0029645:	89 1c 24             	mov    %ebx,(%esp)
c0029648:	e8 d7 f9 ff ff       	call   c0029024 <list_remove>
        if (duplicates != NULL)
c002964d:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c0029652:	74 14                	je     c0029668 <list_unique+0xd4>
          list_push_back (duplicates, next);
c0029654:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029658:	8b 44 24 44          	mov    0x44(%esp),%eax
c002965c:	89 04 24             	mov    %eax,(%esp)
c002965f:	e8 9d f9 ff ff       	call   c0029001 <list_push_back>
c0029664:	89 f3                	mov    %esi,%ebx
c0029666:	eb 02                	jmp    c002966a <list_unique+0xd6>
c0029668:	89 f3                	mov    %esi,%ebx
c002966a:	89 de                	mov    %ebx,%esi
  while ((next = list_next (elem)) != list_end (list))
c002966c:	89 34 24             	mov    %esi,(%esp)
c002966f:	e8 9b f4 ff ff       	call   c0028b0f <list_next>
c0029674:	89 c3                	mov    %eax,%ebx
c0029676:	89 3c 24             	mov    %edi,(%esp)
c0029679:	e8 e5 f4 ff ff       	call   c0028b63 <list_end>
c002967e:	39 c3                	cmp    %eax,%ebx
c0029680:	75 99                	jne    c002961b <list_unique+0x87>
      }
    else
      elem = next;
}
c0029682:	83 c4 2c             	add    $0x2c,%esp
c0029685:	5b                   	pop    %ebx
c0029686:	5e                   	pop    %esi
c0029687:	5f                   	pop    %edi
c0029688:	5d                   	pop    %ebp
c0029689:	c3                   	ret    

c002968a <list_max>:
   to LESS given auxiliary data AUX.  If there is more than one
   maximum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_max (struct list *list, list_less_func *less, void *aux)
{
c002968a:	55                   	push   %ebp
c002968b:	57                   	push   %edi
c002968c:	56                   	push   %esi
c002968d:	53                   	push   %ebx
c002968e:	83 ec 1c             	sub    $0x1c,%esp
c0029691:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0029695:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *max = list_begin (list);
c0029699:	89 3c 24             	mov    %edi,(%esp)
c002969c:	e8 30 f4 ff ff       	call   c0028ad1 <list_begin>
c00296a1:	89 c6                	mov    %eax,%esi
  if (max != list_end (list)) 
c00296a3:	89 3c 24             	mov    %edi,(%esp)
c00296a6:	e8 b8 f4 ff ff       	call   c0028b63 <list_end>
c00296ab:	39 f0                	cmp    %esi,%eax
c00296ad:	74 36                	je     c00296e5 <list_max+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c00296af:	89 34 24             	mov    %esi,(%esp)
c00296b2:	e8 58 f4 ff ff       	call   c0028b0f <list_next>
c00296b7:	89 c3                	mov    %eax,%ebx
c00296b9:	eb 1e                	jmp    c00296d9 <list_max+0x4f>
        if (less (max, e, aux))
c00296bb:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00296bf:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00296c3:	89 34 24             	mov    %esi,(%esp)
c00296c6:	ff 54 24 34          	call   *0x34(%esp)
c00296ca:	84 c0                	test   %al,%al
          max = e; 
c00296cc:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c00296cf:	89 1c 24             	mov    %ebx,(%esp)
c00296d2:	e8 38 f4 ff ff       	call   c0028b0f <list_next>
c00296d7:	89 c3                	mov    %eax,%ebx
c00296d9:	89 3c 24             	mov    %edi,(%esp)
c00296dc:	e8 82 f4 ff ff       	call   c0028b63 <list_end>
c00296e1:	39 d8                	cmp    %ebx,%eax
c00296e3:	75 d6                	jne    c00296bb <list_max+0x31>
    }
  return max;
}
c00296e5:	89 f0                	mov    %esi,%eax
c00296e7:	83 c4 1c             	add    $0x1c,%esp
c00296ea:	5b                   	pop    %ebx
c00296eb:	5e                   	pop    %esi
c00296ec:	5f                   	pop    %edi
c00296ed:	5d                   	pop    %ebp
c00296ee:	c3                   	ret    

c00296ef <list_min>:
   to LESS given auxiliary data AUX.  If there is more than one
   minimum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_min (struct list *list, list_less_func *less, void *aux)
{
c00296ef:	55                   	push   %ebp
c00296f0:	57                   	push   %edi
c00296f1:	56                   	push   %esi
c00296f2:	53                   	push   %ebx
c00296f3:	83 ec 1c             	sub    $0x1c,%esp
c00296f6:	8b 7c 24 30          	mov    0x30(%esp),%edi
c00296fa:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *min = list_begin (list);
c00296fe:	89 3c 24             	mov    %edi,(%esp)
c0029701:	e8 cb f3 ff ff       	call   c0028ad1 <list_begin>
c0029706:	89 c6                	mov    %eax,%esi
  if (min != list_end (list)) 
c0029708:	89 3c 24             	mov    %edi,(%esp)
c002970b:	e8 53 f4 ff ff       	call   c0028b63 <list_end>
c0029710:	39 f0                	cmp    %esi,%eax
c0029712:	74 36                	je     c002974a <list_min+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c0029714:	89 34 24             	mov    %esi,(%esp)
c0029717:	e8 f3 f3 ff ff       	call   c0028b0f <list_next>
c002971c:	89 c3                	mov    %eax,%ebx
c002971e:	eb 1e                	jmp    c002973e <list_min+0x4f>
        if (less (e, min, aux))
c0029720:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0029724:	89 74 24 04          	mov    %esi,0x4(%esp)
c0029728:	89 1c 24             	mov    %ebx,(%esp)
c002972b:	ff 54 24 34          	call   *0x34(%esp)
c002972f:	84 c0                	test   %al,%al
          min = e; 
c0029731:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c0029734:	89 1c 24             	mov    %ebx,(%esp)
c0029737:	e8 d3 f3 ff ff       	call   c0028b0f <list_next>
c002973c:	89 c3                	mov    %eax,%ebx
c002973e:	89 3c 24             	mov    %edi,(%esp)
c0029741:	e8 1d f4 ff ff       	call   c0028b63 <list_end>
c0029746:	39 d8                	cmp    %ebx,%eax
c0029748:	75 d6                	jne    c0029720 <list_min+0x31>
    }
  return min;
}
c002974a:	89 f0                	mov    %esi,%eax
c002974c:	83 c4 1c             	add    $0x1c,%esp
c002974f:	5b                   	pop    %ebx
c0029750:	5e                   	pop    %esi
c0029751:	5f                   	pop    %edi
c0029752:	5d                   	pop    %ebp
c0029753:	c3                   	ret    
c0029754:	90                   	nop
c0029755:	90                   	nop
c0029756:	90                   	nop
c0029757:	90                   	nop
c0029758:	90                   	nop
c0029759:	90                   	nop
c002975a:	90                   	nop
c002975b:	90                   	nop
c002975c:	90                   	nop
c002975d:	90                   	nop
c002975e:	90                   	nop
c002975f:	90                   	nop

c0029760 <bitmap_buf_size>:

/* Returns the number of elements required for BIT_CNT bits. */
static inline size_t
elem_cnt (size_t bit_cnt)
{
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029760:	8b 44 24 04          	mov    0x4(%esp),%eax
c0029764:	83 c0 1f             	add    $0x1f,%eax
c0029767:	c1 e8 05             	shr    $0x5,%eax
/* Returns the number of bytes required to accomodate a bitmap
   with BIT_CNT bits (for use with bitmap_create_in_buf()). */
size_t
bitmap_buf_size (size_t bit_cnt) 
{
  return sizeof (struct bitmap) + byte_cnt (bit_cnt);
c002976a:	8d 04 85 08 00 00 00 	lea    0x8(,%eax,4),%eax
}
c0029771:	c3                   	ret    

c0029772 <bitmap_destroy>:

/* Destroys bitmap B, freeing its storage.
   Not for use on bitmaps created by bitmap_create_in_buf(). */
void
bitmap_destroy (struct bitmap *b) 
{
c0029772:	53                   	push   %ebx
c0029773:	83 ec 18             	sub    $0x18,%esp
c0029776:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (b != NULL) 
c002977a:	85 db                	test   %ebx,%ebx
c002977c:	74 13                	je     c0029791 <bitmap_destroy+0x1f>
    {
      free (b->bits);
c002977e:	8b 43 04             	mov    0x4(%ebx),%eax
c0029781:	89 04 24             	mov    %eax,(%esp)
c0029784:	e8 72 a4 ff ff       	call   c0023bfb <free>
      free (b);
c0029789:	89 1c 24             	mov    %ebx,(%esp)
c002978c:	e8 6a a4 ff ff       	call   c0023bfb <free>
    }
}
c0029791:	83 c4 18             	add    $0x18,%esp
c0029794:	5b                   	pop    %ebx
c0029795:	c3                   	ret    

c0029796 <bitmap_size>:

/* Returns the number of bits in B. */
size_t
bitmap_size (const struct bitmap *b)
{
  return b->bit_cnt;
c0029796:	8b 44 24 04          	mov    0x4(%esp),%eax
c002979a:	8b 00                	mov    (%eax),%eax
}
c002979c:	c3                   	ret    

c002979d <bitmap_mark>:
}

/* Atomically sets the bit numbered BIT_IDX in B to true. */
void
bitmap_mark (struct bitmap *b, size_t bit_idx) 
{
c002979d:	53                   	push   %ebx
c002979e:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c00297a2:	89 ca                	mov    %ecx,%edx
c00297a4:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] |= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the OR instruction in [IA32-v2b]. */
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c00297a7:	8b 44 24 08          	mov    0x8(%esp),%eax
c00297ab:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00297ae:	bb 01 00 00 00       	mov    $0x1,%ebx
c00297b3:	d3 e3                	shl    %cl,%ebx
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c00297b5:	09 1c 90             	or     %ebx,(%eax,%edx,4)
}
c00297b8:	5b                   	pop    %ebx
c00297b9:	c3                   	ret    

c00297ba <bitmap_reset>:

/* Atomically sets the bit numbered BIT_IDX in B to false. */
void
bitmap_reset (struct bitmap *b, size_t bit_idx) 
{
c00297ba:	53                   	push   %ebx
c00297bb:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c00297bf:	89 ca                	mov    %ecx,%edx
c00297c1:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] &= ~mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the AND instruction in [IA32-v2a]. */
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c00297c4:	8b 44 24 08          	mov    0x8(%esp),%eax
c00297c8:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00297cb:	bb 01 00 00 00       	mov    $0x1,%ebx
c00297d0:	d3 e3                	shl    %cl,%ebx
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c00297d2:	f7 d3                	not    %ebx
c00297d4:	21 1c 90             	and    %ebx,(%eax,%edx,4)
}
c00297d7:	5b                   	pop    %ebx
c00297d8:	c3                   	ret    

c00297d9 <bitmap_set>:
{
c00297d9:	83 ec 2c             	sub    $0x2c,%esp
c00297dc:	8b 44 24 30          	mov    0x30(%esp),%eax
c00297e0:	8b 54 24 34          	mov    0x34(%esp),%edx
c00297e4:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  ASSERT (b != NULL);
c00297e8:	85 c0                	test   %eax,%eax
c00297ea:	75 2c                	jne    c0029818 <bitmap_set+0x3f>
c00297ec:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c00297f3:	c0 
c00297f4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00297fb:	c0 
c00297fc:	c7 44 24 08 07 de 02 	movl   $0xc002de07,0x8(%esp)
c0029803:	c0 
c0029804:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
c002980b:	00 
c002980c:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029813:	e8 9b f1 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c0029818:	39 10                	cmp    %edx,(%eax)
c002981a:	77 2c                	ja     c0029848 <bitmap_set+0x6f>
c002981c:	c7 44 24 10 0c fe 02 	movl   $0xc002fe0c,0x10(%esp)
c0029823:	c0 
c0029824:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002982b:	c0 
c002982c:	c7 44 24 08 07 de 02 	movl   $0xc002de07,0x8(%esp)
c0029833:	c0 
c0029834:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
c002983b:	00 
c002983c:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029843:	e8 6b f1 ff ff       	call   c00289b3 <debug_panic>
  if (value)
c0029848:	84 c9                	test   %cl,%cl
c002984a:	74 0e                	je     c002985a <bitmap_set+0x81>
    bitmap_mark (b, idx);
c002984c:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029850:	89 04 24             	mov    %eax,(%esp)
c0029853:	e8 45 ff ff ff       	call   c002979d <bitmap_mark>
c0029858:	eb 0c                	jmp    c0029866 <bitmap_set+0x8d>
    bitmap_reset (b, idx);
c002985a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002985e:	89 04 24             	mov    %eax,(%esp)
c0029861:	e8 54 ff ff ff       	call   c00297ba <bitmap_reset>
}
c0029866:	83 c4 2c             	add    $0x2c,%esp
c0029869:	c3                   	ret    

c002986a <bitmap_flip>:
/* Atomically toggles the bit numbered IDX in B;
   that is, if it is true, makes it false,
   and if it is false, makes it true. */
void
bitmap_flip (struct bitmap *b, size_t bit_idx) 
{
c002986a:	53                   	push   %ebx
c002986b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002986f:	89 ca                	mov    %ecx,%edx
c0029871:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] ^= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the XOR instruction in [IA32-v2b]. */
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029874:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029878:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002987b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029880:	d3 e3                	shl    %cl,%ebx
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029882:	31 1c 90             	xor    %ebx,(%eax,%edx,4)
}
c0029885:	5b                   	pop    %ebx
c0029886:	c3                   	ret    

c0029887 <bitmap_test>:

/* Returns the value of the bit numbered IDX in B. */
bool
bitmap_test (const struct bitmap *b, size_t idx) 
{
c0029887:	53                   	push   %ebx
c0029888:	83 ec 28             	sub    $0x28,%esp
c002988b:	8b 44 24 30          	mov    0x30(%esp),%eax
c002988f:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (b != NULL);
c0029893:	85 c0                	test   %eax,%eax
c0029895:	75 2c                	jne    c00298c3 <bitmap_test+0x3c>
c0029897:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c002989e:	c0 
c002989f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00298a6:	c0 
c00298a7:	c7 44 24 08 fb dd 02 	movl   $0xc002ddfb,0x8(%esp)
c00298ae:	c0 
c00298af:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
c00298b6:	00 
c00298b7:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c00298be:	e8 f0 f0 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c00298c3:	39 08                	cmp    %ecx,(%eax)
c00298c5:	77 2c                	ja     c00298f3 <bitmap_test+0x6c>
c00298c7:	c7 44 24 10 0c fe 02 	movl   $0xc002fe0c,0x10(%esp)
c00298ce:	c0 
c00298cf:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00298d6:	c0 
c00298d7:	c7 44 24 08 fb dd 02 	movl   $0xc002ddfb,0x8(%esp)
c00298de:	c0 
c00298df:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c00298e6:	00 
c00298e7:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c00298ee:	e8 c0 f0 ff ff       	call   c00289b3 <debug_panic>
  return bit_idx / ELEM_BITS;
c00298f3:	89 ca                	mov    %ecx,%edx
c00298f5:	c1 ea 05             	shr    $0x5,%edx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00298f8:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00298fb:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029900:	d3 e3                	shl    %cl,%ebx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c0029902:	85 1c 90             	test   %ebx,(%eax,%edx,4)
c0029905:	0f 95 c0             	setne  %al
}
c0029908:	83 c4 28             	add    $0x28,%esp
c002990b:	5b                   	pop    %ebx
c002990c:	c3                   	ret    

c002990d <bitmap_set_multiple>:
}

/* Sets the CNT bits starting at START in B to VALUE. */
void
bitmap_set_multiple (struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c002990d:	55                   	push   %ebp
c002990e:	57                   	push   %edi
c002990f:	56                   	push   %esi
c0029910:	53                   	push   %ebx
c0029911:	83 ec 2c             	sub    $0x2c,%esp
c0029914:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029918:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c002991c:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029920:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  size_t i;
  
  ASSERT (b != NULL);
c0029925:	85 f6                	test   %esi,%esi
c0029927:	75 2c                	jne    c0029955 <bitmap_set_multiple+0x48>
c0029929:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029930:	c0 
c0029931:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029938:	c0 
c0029939:	c7 44 24 08 d8 dd 02 	movl   $0xc002ddd8,0x8(%esp)
c0029940:	c0 
c0029941:	c7 44 24 04 de 00 00 	movl   $0xde,0x4(%esp)
c0029948:	00 
c0029949:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029950:	e8 5e f0 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029955:	8b 16                	mov    (%esi),%edx
c0029957:	39 da                	cmp    %ebx,%edx
c0029959:	73 2c                	jae    c0029987 <bitmap_set_multiple+0x7a>
c002995b:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029962:	c0 
c0029963:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002996a:	c0 
c002996b:	c7 44 24 08 d8 dd 02 	movl   $0xc002ddd8,0x8(%esp)
c0029972:	c0 
c0029973:	c7 44 24 04 df 00 00 	movl   $0xdf,0x4(%esp)
c002997a:	00 
c002997b:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029982:	e8 2c f0 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029987:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c002998a:	39 fa                	cmp    %edi,%edx
c002998c:	72 09                	jb     c0029997 <bitmap_set_multiple+0x8a>

  for (i = 0; i < cnt; i++)
    bitmap_set (b, start + i, value);
c002998e:	0f b6 e9             	movzbl %cl,%ebp
  for (i = 0; i < cnt; i++)
c0029991:	85 c0                	test   %eax,%eax
c0029993:	75 2e                	jne    c00299c3 <bitmap_set_multiple+0xb6>
c0029995:	eb 43                	jmp    c00299da <bitmap_set_multiple+0xcd>
  ASSERT (start + cnt <= b->bit_cnt);
c0029997:	c7 44 24 10 31 fe 02 	movl   $0xc002fe31,0x10(%esp)
c002999e:	c0 
c002999f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c00299a6:	c0 
c00299a7:	c7 44 24 08 d8 dd 02 	movl   $0xc002ddd8,0x8(%esp)
c00299ae:	c0 
c00299af:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c00299b6:	00 
c00299b7:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c00299be:	e8 f0 ef ff ff       	call   c00289b3 <debug_panic>
    bitmap_set (b, start + i, value);
c00299c3:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00299c7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00299cb:	89 34 24             	mov    %esi,(%esp)
c00299ce:	e8 06 fe ff ff       	call   c00297d9 <bitmap_set>
c00299d3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c00299d6:	39 df                	cmp    %ebx,%edi
c00299d8:	75 e9                	jne    c00299c3 <bitmap_set_multiple+0xb6>
}
c00299da:	83 c4 2c             	add    $0x2c,%esp
c00299dd:	5b                   	pop    %ebx
c00299de:	5e                   	pop    %esi
c00299df:	5f                   	pop    %edi
c00299e0:	5d                   	pop    %ebp
c00299e1:	c3                   	ret    

c00299e2 <bitmap_set_all>:
{
c00299e2:	83 ec 2c             	sub    $0x2c,%esp
c00299e5:	8b 44 24 30          	mov    0x30(%esp),%eax
c00299e9:	8b 54 24 34          	mov    0x34(%esp),%edx
  ASSERT (b != NULL);
c00299ed:	85 c0                	test   %eax,%eax
c00299ef:	75 2c                	jne    c0029a1d <bitmap_set_all+0x3b>
c00299f1:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c00299f8:	c0 
c00299f9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029a00:	c0 
c0029a01:	c7 44 24 08 ec dd 02 	movl   $0xc002ddec,0x8(%esp)
c0029a08:	c0 
c0029a09:	c7 44 24 04 d3 00 00 	movl   $0xd3,0x4(%esp)
c0029a10:	00 
c0029a11:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029a18:	e8 96 ef ff ff       	call   c00289b3 <debug_panic>
  bitmap_set_multiple (b, 0, bitmap_size (b), value);
c0029a1d:	0f b6 d2             	movzbl %dl,%edx
c0029a20:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0029a24:	8b 10                	mov    (%eax),%edx
c0029a26:	89 54 24 08          	mov    %edx,0x8(%esp)
c0029a2a:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a31:	00 
c0029a32:	89 04 24             	mov    %eax,(%esp)
c0029a35:	e8 d3 fe ff ff       	call   c002990d <bitmap_set_multiple>
}
c0029a3a:	83 c4 2c             	add    $0x2c,%esp
c0029a3d:	c3                   	ret    

c0029a3e <bitmap_create>:
{
c0029a3e:	56                   	push   %esi
c0029a3f:	53                   	push   %ebx
c0029a40:	83 ec 14             	sub    $0x14,%esp
c0029a43:	8b 74 24 20          	mov    0x20(%esp),%esi
  struct bitmap *b = malloc (sizeof *b);
c0029a47:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c0029a4e:	e8 21 a0 ff ff       	call   c0023a74 <malloc>
c0029a53:	89 c3                	mov    %eax,%ebx
  if (b != NULL)
c0029a55:	85 c0                	test   %eax,%eax
c0029a57:	74 41                	je     c0029a9a <bitmap_create+0x5c>
      b->bit_cnt = bit_cnt;
c0029a59:	89 30                	mov    %esi,(%eax)
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029a5b:	8d 46 1f             	lea    0x1f(%esi),%eax
c0029a5e:	c1 e8 05             	shr    $0x5,%eax
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029a61:	c1 e0 02             	shl    $0x2,%eax
      b->bits = malloc (byte_cnt (bit_cnt));
c0029a64:	89 04 24             	mov    %eax,(%esp)
c0029a67:	e8 08 a0 ff ff       	call   c0023a74 <malloc>
c0029a6c:	89 43 04             	mov    %eax,0x4(%ebx)
      if (b->bits != NULL || bit_cnt == 0)
c0029a6f:	85 c0                	test   %eax,%eax
c0029a71:	75 04                	jne    c0029a77 <bitmap_create+0x39>
c0029a73:	85 f6                	test   %esi,%esi
c0029a75:	75 14                	jne    c0029a8b <bitmap_create+0x4d>
          bitmap_set_all (b, false);
c0029a77:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a7e:	00 
c0029a7f:	89 1c 24             	mov    %ebx,(%esp)
c0029a82:	e8 5b ff ff ff       	call   c00299e2 <bitmap_set_all>
          return b;
c0029a87:	89 d8                	mov    %ebx,%eax
c0029a89:	eb 14                	jmp    c0029a9f <bitmap_create+0x61>
      free (b);
c0029a8b:	89 1c 24             	mov    %ebx,(%esp)
c0029a8e:	e8 68 a1 ff ff       	call   c0023bfb <free>
  return NULL;
c0029a93:	b8 00 00 00 00       	mov    $0x0,%eax
c0029a98:	eb 05                	jmp    c0029a9f <bitmap_create+0x61>
c0029a9a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029a9f:	83 c4 14             	add    $0x14,%esp
c0029aa2:	5b                   	pop    %ebx
c0029aa3:	5e                   	pop    %esi
c0029aa4:	c3                   	ret    

c0029aa5 <bitmap_create_in_buf>:
{
c0029aa5:	56                   	push   %esi
c0029aa6:	53                   	push   %ebx
c0029aa7:	83 ec 24             	sub    $0x24,%esp
c0029aaa:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029aae:	8b 5c 24 34          	mov    0x34(%esp),%ebx
  ASSERT (block_size >= bitmap_buf_size (bit_cnt));
c0029ab2:	89 34 24             	mov    %esi,(%esp)
c0029ab5:	e8 a6 fc ff ff       	call   c0029760 <bitmap_buf_size>
c0029aba:	3b 44 24 38          	cmp    0x38(%esp),%eax
c0029abe:	76 2c                	jbe    c0029aec <bitmap_create_in_buf+0x47>
c0029ac0:	c7 44 24 10 4c fe 02 	movl   $0xc002fe4c,0x10(%esp)
c0029ac7:	c0 
c0029ac8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029acf:	c0 
c0029ad0:	c7 44 24 08 12 de 02 	movl   $0xc002de12,0x8(%esp)
c0029ad7:	c0 
c0029ad8:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
c0029adf:	00 
c0029ae0:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029ae7:	e8 c7 ee ff ff       	call   c00289b3 <debug_panic>
  b->bit_cnt = bit_cnt;
c0029aec:	89 33                	mov    %esi,(%ebx)
  b->bits = (elem_type *) (b + 1);
c0029aee:	8d 43 08             	lea    0x8(%ebx),%eax
c0029af1:	89 43 04             	mov    %eax,0x4(%ebx)
  bitmap_set_all (b, false);
c0029af4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029afb:	00 
c0029afc:	89 1c 24             	mov    %ebx,(%esp)
c0029aff:	e8 de fe ff ff       	call   c00299e2 <bitmap_set_all>
}
c0029b04:	89 d8                	mov    %ebx,%eax
c0029b06:	83 c4 24             	add    $0x24,%esp
c0029b09:	5b                   	pop    %ebx
c0029b0a:	5e                   	pop    %esi
c0029b0b:	c3                   	ret    

c0029b0c <bitmap_count>:

/* Returns the number of bits in B between START and START + CNT,
   exclusive, that are set to VALUE. */
size_t
bitmap_count (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029b0c:	55                   	push   %ebp
c0029b0d:	57                   	push   %edi
c0029b0e:	56                   	push   %esi
c0029b0f:	53                   	push   %ebx
c0029b10:	83 ec 2c             	sub    $0x2c,%esp
c0029b13:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0029b17:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029b1b:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029b1f:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
c0029b24:	88 4c 24 1f          	mov    %cl,0x1f(%esp)
  size_t i, value_cnt;

  ASSERT (b != NULL);
c0029b28:	85 ff                	test   %edi,%edi
c0029b2a:	75 2c                	jne    c0029b58 <bitmap_count+0x4c>
c0029b2c:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029b33:	c0 
c0029b34:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029b3b:	c0 
c0029b3c:	c7 44 24 08 cb dd 02 	movl   $0xc002ddcb,0x8(%esp)
c0029b43:	c0 
c0029b44:	c7 44 24 04 ed 00 00 	movl   $0xed,0x4(%esp)
c0029b4b:	00 
c0029b4c:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029b53:	e8 5b ee ff ff       	call   c00289b3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029b58:	8b 17                	mov    (%edi),%edx
c0029b5a:	39 da                	cmp    %ebx,%edx
c0029b5c:	73 2c                	jae    c0029b8a <bitmap_count+0x7e>
c0029b5e:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029b65:	c0 
c0029b66:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029b6d:	c0 
c0029b6e:	c7 44 24 08 cb dd 02 	movl   $0xc002ddcb,0x8(%esp)
c0029b75:	c0 
c0029b76:	c7 44 24 04 ee 00 00 	movl   $0xee,0x4(%esp)
c0029b7d:	00 
c0029b7e:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029b85:	e8 29 ee ff ff       	call   c00289b3 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b8a:	8d 2c 03             	lea    (%ebx,%eax,1),%ebp
c0029b8d:	39 ea                	cmp    %ebp,%edx
c0029b8f:	72 0b                	jb     c0029b9c <bitmap_count+0x90>

  value_cnt = 0;
  for (i = 0; i < cnt; i++)
c0029b91:	be 00 00 00 00       	mov    $0x0,%esi
c0029b96:	85 c0                	test   %eax,%eax
c0029b98:	75 2e                	jne    c0029bc8 <bitmap_count+0xbc>
c0029b9a:	eb 4b                	jmp    c0029be7 <bitmap_count+0xdb>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b9c:	c7 44 24 10 31 fe 02 	movl   $0xc002fe31,0x10(%esp)
c0029ba3:	c0 
c0029ba4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029bab:	c0 
c0029bac:	c7 44 24 08 cb dd 02 	movl   $0xc002ddcb,0x8(%esp)
c0029bb3:	c0 
c0029bb4:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0029bbb:	00 
c0029bbc:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029bc3:	e8 eb ed ff ff       	call   c00289b3 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029bc8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029bcc:	89 3c 24             	mov    %edi,(%esp)
c0029bcf:	e8 b3 fc ff ff       	call   c0029887 <bitmap_test>
      value_cnt++;
c0029bd4:	3a 44 24 1f          	cmp    0x1f(%esp),%al
c0029bd8:	0f 94 c0             	sete   %al
c0029bdb:	0f b6 c0             	movzbl %al,%eax
c0029bde:	01 c6                	add    %eax,%esi
c0029be0:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029be3:	39 dd                	cmp    %ebx,%ebp
c0029be5:	75 e1                	jne    c0029bc8 <bitmap_count+0xbc>
  return value_cnt;
}
c0029be7:	89 f0                	mov    %esi,%eax
c0029be9:	83 c4 2c             	add    $0x2c,%esp
c0029bec:	5b                   	pop    %ebx
c0029bed:	5e                   	pop    %esi
c0029bee:	5f                   	pop    %edi
c0029bef:	5d                   	pop    %ebp
c0029bf0:	c3                   	ret    

c0029bf1 <bitmap_contains>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to VALUE, and false otherwise. */
bool
bitmap_contains (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029bf1:	55                   	push   %ebp
c0029bf2:	57                   	push   %edi
c0029bf3:	56                   	push   %esi
c0029bf4:	53                   	push   %ebx
c0029bf5:	83 ec 2c             	sub    $0x2c,%esp
c0029bf8:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029bfc:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029c00:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029c04:	0f b6 6c 24 4c       	movzbl 0x4c(%esp),%ebp
  size_t i;
  
  ASSERT (b != NULL);
c0029c09:	85 f6                	test   %esi,%esi
c0029c0b:	75 2c                	jne    c0029c39 <bitmap_contains+0x48>
c0029c0d:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029c14:	c0 
c0029c15:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029c1c:	c0 
c0029c1d:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c0029c24:	c0 
c0029c25:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
c0029c2c:	00 
c0029c2d:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029c34:	e8 7a ed ff ff       	call   c00289b3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029c39:	8b 16                	mov    (%esi),%edx
c0029c3b:	39 da                	cmp    %ebx,%edx
c0029c3d:	73 2c                	jae    c0029c6b <bitmap_contains+0x7a>
c0029c3f:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029c46:	c0 
c0029c47:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029c4e:	c0 
c0029c4f:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c0029c56:	c0 
c0029c57:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
c0029c5e:	00 
c0029c5f:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029c66:	e8 48 ed ff ff       	call   c00289b3 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c6b:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c0029c6e:	39 fa                	cmp    %edi,%edx
c0029c70:	72 06                	jb     c0029c78 <bitmap_contains+0x87>

  for (i = 0; i < cnt; i++)
c0029c72:	85 c0                	test   %eax,%eax
c0029c74:	75 2e                	jne    c0029ca4 <bitmap_contains+0xb3>
c0029c76:	eb 53                	jmp    c0029ccb <bitmap_contains+0xda>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c78:	c7 44 24 10 31 fe 02 	movl   $0xc002fe31,0x10(%esp)
c0029c7f:	c0 
c0029c80:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029c87:	c0 
c0029c88:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c0029c8f:	c0 
c0029c90:	c7 44 24 04 01 01 00 	movl   $0x101,0x4(%esp)
c0029c97:	00 
c0029c98:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029c9f:	e8 0f ed ff ff       	call   c00289b3 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029ca4:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029ca8:	89 34 24             	mov    %esi,(%esp)
c0029cab:	e8 d7 fb ff ff       	call   c0029887 <bitmap_test>
c0029cb0:	89 e9                	mov    %ebp,%ecx
c0029cb2:	38 c8                	cmp    %cl,%al
c0029cb4:	74 09                	je     c0029cbf <bitmap_contains+0xce>
c0029cb6:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029cb9:	39 df                	cmp    %ebx,%edi
c0029cbb:	75 e7                	jne    c0029ca4 <bitmap_contains+0xb3>
c0029cbd:	eb 07                	jmp    c0029cc6 <bitmap_contains+0xd5>
      return true;
c0029cbf:	b8 01 00 00 00       	mov    $0x1,%eax
c0029cc4:	eb 05                	jmp    c0029ccb <bitmap_contains+0xda>
  return false;
c0029cc6:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029ccb:	83 c4 2c             	add    $0x2c,%esp
c0029cce:	5b                   	pop    %ebx
c0029ccf:	5e                   	pop    %esi
c0029cd0:	5f                   	pop    %edi
c0029cd1:	5d                   	pop    %ebp
c0029cd2:	c3                   	ret    

c0029cd3 <bitmap_any>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_any (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cd3:	83 ec 1c             	sub    $0x1c,%esp
  return bitmap_contains (b, start, cnt, true);
c0029cd6:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029cdd:	00 
c0029cde:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029ce2:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029ce6:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029cea:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029cee:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029cf2:	89 04 24             	mov    %eax,(%esp)
c0029cf5:	e8 f7 fe ff ff       	call   c0029bf1 <bitmap_contains>
}
c0029cfa:	83 c4 1c             	add    $0x1c,%esp
c0029cfd:	c3                   	ret    

c0029cfe <bitmap_none>:

/* Returns true if no bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_none (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cfe:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, true);
c0029d01:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029d08:	00 
c0029d09:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029d0d:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029d11:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029d15:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029d19:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029d1d:	89 04 24             	mov    %eax,(%esp)
c0029d20:	e8 cc fe ff ff       	call   c0029bf1 <bitmap_contains>
c0029d25:	83 f0 01             	xor    $0x1,%eax
}
c0029d28:	83 c4 1c             	add    $0x1c,%esp
c0029d2b:	c3                   	ret    

c0029d2c <bitmap_all>:

/* Returns true if every bit in B between START and START + CNT,
   exclusive, is set to true, and false otherwise. */
bool
bitmap_all (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029d2c:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, false);
c0029d2f:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029d36:	00 
c0029d37:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029d3b:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029d3f:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029d43:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029d47:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029d4b:	89 04 24             	mov    %eax,(%esp)
c0029d4e:	e8 9e fe ff ff       	call   c0029bf1 <bitmap_contains>
c0029d53:	83 f0 01             	xor    $0x1,%eax
}
c0029d56:	83 c4 1c             	add    $0x1c,%esp
c0029d59:	c3                   	ret    

c0029d5a <bitmap_scan>:
   consecutive bits in B at or after START that are all set to
   VALUE.
   If there is no such group, returns BITMAP_ERROR. */
size_t
bitmap_scan (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029d5a:	55                   	push   %ebp
c0029d5b:	57                   	push   %edi
c0029d5c:	56                   	push   %esi
c0029d5d:	53                   	push   %ebx
c0029d5e:	83 ec 2c             	sub    $0x2c,%esp
c0029d61:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029d65:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029d69:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0029d6d:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  ASSERT (b != NULL);
c0029d72:	85 f6                	test   %esi,%esi
c0029d74:	75 2c                	jne    c0029da2 <bitmap_scan+0x48>
c0029d76:	c7 44 24 10 1d fa 02 	movl   $0xc002fa1d,0x10(%esp)
c0029d7d:	c0 
c0029d7e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029d85:	c0 
c0029d86:	c7 44 24 08 af dd 02 	movl   $0xc002ddaf,0x8(%esp)
c0029d8d:	c0 
c0029d8e:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0029d95:	00 
c0029d96:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029d9d:	e8 11 ec ff ff       	call   c00289b3 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029da2:	8b 16                	mov    (%esi),%edx
c0029da4:	39 da                	cmp    %ebx,%edx
c0029da6:	73 2c                	jae    c0029dd4 <bitmap_scan+0x7a>
c0029da8:	c7 44 24 10 1d fe 02 	movl   $0xc002fe1d,0x10(%esp)
c0029daf:	c0 
c0029db0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029db7:	c0 
c0029db8:	c7 44 24 08 af dd 02 	movl   $0xc002ddaf,0x8(%esp)
c0029dbf:	c0 
c0029dc0:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0029dc7:	00 
c0029dc8:	c7 04 24 f2 fd 02 c0 	movl   $0xc002fdf2,(%esp)
c0029dcf:	e8 df eb ff ff       	call   c00289b3 <debug_panic>
      size_t i;
      for (i = start; i <= last; i++)
        if (!bitmap_contains (b, i, cnt, !value))
          return i; 
    }
  return BITMAP_ERROR;
c0029dd4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  if (cnt <= b->bit_cnt) 
c0029dd9:	39 fa                	cmp    %edi,%edx
c0029ddb:	72 45                	jb     c0029e22 <bitmap_scan+0xc8>
      size_t last = b->bit_cnt - cnt;
c0029ddd:	29 fa                	sub    %edi,%edx
c0029ddf:	89 54 24 1c          	mov    %edx,0x1c(%esp)
      for (i = start; i <= last; i++)
c0029de3:	39 d3                	cmp    %edx,%ebx
c0029de5:	77 2b                	ja     c0029e12 <bitmap_scan+0xb8>
        if (!bitmap_contains (b, i, cnt, !value))
c0029de7:	83 f1 01             	xor    $0x1,%ecx
c0029dea:	0f b6 e9             	movzbl %cl,%ebp
c0029ded:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029df1:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029df5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029df9:	89 34 24             	mov    %esi,(%esp)
c0029dfc:	e8 f0 fd ff ff       	call   c0029bf1 <bitmap_contains>
c0029e01:	84 c0                	test   %al,%al
c0029e03:	74 14                	je     c0029e19 <bitmap_scan+0xbf>
      for (i = start; i <= last; i++)
c0029e05:	83 c3 01             	add    $0x1,%ebx
c0029e08:	39 5c 24 1c          	cmp    %ebx,0x1c(%esp)
c0029e0c:	73 df                	jae    c0029ded <bitmap_scan+0x93>
c0029e0e:	66 90                	xchg   %ax,%ax
c0029e10:	eb 0b                	jmp    c0029e1d <bitmap_scan+0xc3>
  return BITMAP_ERROR;
c0029e12:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0029e17:	eb 09                	jmp    c0029e22 <bitmap_scan+0xc8>
c0029e19:	89 d8                	mov    %ebx,%eax
c0029e1b:	eb 05                	jmp    c0029e22 <bitmap_scan+0xc8>
c0029e1d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0029e22:	83 c4 2c             	add    $0x2c,%esp
c0029e25:	5b                   	pop    %ebx
c0029e26:	5e                   	pop    %esi
c0029e27:	5f                   	pop    %edi
c0029e28:	5d                   	pop    %ebp
c0029e29:	c3                   	ret    

c0029e2a <bitmap_scan_and_flip>:
   If CNT is zero, returns 0.
   Bits are set atomically, but testing bits is not atomic with
   setting them. */
size_t
bitmap_scan_and_flip (struct bitmap *b, size_t start, size_t cnt, bool value)
{
c0029e2a:	55                   	push   %ebp
c0029e2b:	57                   	push   %edi
c0029e2c:	56                   	push   %esi
c0029e2d:	53                   	push   %ebx
c0029e2e:	83 ec 1c             	sub    $0x1c,%esp
c0029e31:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029e35:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0029e39:	8b 6c 24 3c          	mov    0x3c(%esp),%ebp
  size_t idx = bitmap_scan (b, start, cnt, value);
c0029e3d:	89 e8                	mov    %ebp,%eax
c0029e3f:	0f b6 c0             	movzbl %al,%eax
c0029e42:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0029e46:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e4a:	8b 44 24 34          	mov    0x34(%esp),%eax
c0029e4e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e52:	89 34 24             	mov    %esi,(%esp)
c0029e55:	e8 00 ff ff ff       	call   c0029d5a <bitmap_scan>
c0029e5a:	89 c3                	mov    %eax,%ebx
  if (idx != BITMAP_ERROR) 
c0029e5c:	83 f8 ff             	cmp    $0xffffffff,%eax
c0029e5f:	74 1c                	je     c0029e7d <bitmap_scan_and_flip+0x53>
    bitmap_set_multiple (b, idx, cnt, !value);
c0029e61:	89 e8                	mov    %ebp,%eax
c0029e63:	83 f0 01             	xor    $0x1,%eax
c0029e66:	0f b6 e8             	movzbl %al,%ebp
c0029e69:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029e6d:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e71:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029e75:	89 34 24             	mov    %esi,(%esp)
c0029e78:	e8 90 fa ff ff       	call   c002990d <bitmap_set_multiple>
  return idx;
}
c0029e7d:	89 d8                	mov    %ebx,%eax
c0029e7f:	83 c4 1c             	add    $0x1c,%esp
c0029e82:	5b                   	pop    %ebx
c0029e83:	5e                   	pop    %esi
c0029e84:	5f                   	pop    %edi
c0029e85:	5d                   	pop    %ebp
c0029e86:	c3                   	ret    

c0029e87 <bitmap_dump>:
/* Debugging. */

/* Dumps the contents of B to the console as hexadecimal. */
void
bitmap_dump (const struct bitmap *b) 
{
c0029e87:	83 ec 1c             	sub    $0x1c,%esp
c0029e8a:	8b 44 24 20          	mov    0x20(%esp),%eax
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e8e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029e95:	00 
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029e96:	8b 08                	mov    (%eax),%ecx
c0029e98:	8d 51 1f             	lea    0x1f(%ecx),%edx
c0029e9b:	c1 ea 05             	shr    $0x5,%edx
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029e9e:	c1 e2 02             	shl    $0x2,%edx
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029ea1:	89 54 24 08          	mov    %edx,0x8(%esp)
c0029ea5:	8b 40 04             	mov    0x4(%eax),%eax
c0029ea8:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029eac:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0029eb3:	e8 d2 d3 ff ff       	call   c002728a <hex_dump>
}
c0029eb8:	83 c4 1c             	add    $0x1c,%esp
c0029ebb:	c3                   	ret    
c0029ebc:	90                   	nop
c0029ebd:	90                   	nop
c0029ebe:	90                   	nop
c0029ebf:	90                   	nop

c0029ec0 <find_bucket>:
}

/* Returns the bucket in H that E belongs in. */
static struct list *
find_bucket (struct hash *h, struct hash_elem *e) 
{
c0029ec0:	53                   	push   %ebx
c0029ec1:	83 ec 18             	sub    $0x18,%esp
c0029ec4:	89 c3                	mov    %eax,%ebx
  size_t bucket_idx = h->hash (e, h->aux) & (h->bucket_cnt - 1);
c0029ec6:	8b 40 14             	mov    0x14(%eax),%eax
c0029ec9:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029ecd:	89 14 24             	mov    %edx,(%esp)
c0029ed0:	ff 53 0c             	call   *0xc(%ebx)
c0029ed3:	8b 4b 04             	mov    0x4(%ebx),%ecx
c0029ed6:	8d 51 ff             	lea    -0x1(%ecx),%edx
c0029ed9:	21 d0                	and    %edx,%eax
  return &h->buckets[bucket_idx];
c0029edb:	c1 e0 04             	shl    $0x4,%eax
c0029ede:	03 43 08             	add    0x8(%ebx),%eax
}
c0029ee1:	83 c4 18             	add    $0x18,%esp
c0029ee4:	5b                   	pop    %ebx
c0029ee5:	c3                   	ret    

c0029ee6 <find_elem>:

/* Searches BUCKET in H for a hash element equal to E.  Returns
   it if found or a null pointer otherwise. */
static struct hash_elem *
find_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
c0029ee6:	55                   	push   %ebp
c0029ee7:	57                   	push   %edi
c0029ee8:	56                   	push   %esi
c0029ee9:	53                   	push   %ebx
c0029eea:	83 ec 1c             	sub    $0x1c,%esp
c0029eed:	89 c6                	mov    %eax,%esi
c0029eef:	89 d5                	mov    %edx,%ebp
c0029ef1:	89 cf                	mov    %ecx,%edi
  struct list_elem *i;

  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029ef3:	89 14 24             	mov    %edx,(%esp)
c0029ef6:	e8 d6 eb ff ff       	call   c0028ad1 <list_begin>
c0029efb:	89 c3                	mov    %eax,%ebx
c0029efd:	eb 34                	jmp    c0029f33 <find_elem+0x4d>
    {
      struct hash_elem *hi = list_elem_to_hash_elem (i);
      if (!h->less (hi, e, h->aux) && !h->less (e, hi, h->aux))
c0029eff:	8b 46 14             	mov    0x14(%esi),%eax
c0029f02:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029f06:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029f0a:	89 1c 24             	mov    %ebx,(%esp)
c0029f0d:	ff 56 10             	call   *0x10(%esi)
c0029f10:	84 c0                	test   %al,%al
c0029f12:	75 15                	jne    c0029f29 <find_elem+0x43>
c0029f14:	8b 46 14             	mov    0x14(%esi),%eax
c0029f17:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029f1b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029f1f:	89 3c 24             	mov    %edi,(%esp)
c0029f22:	ff 56 10             	call   *0x10(%esi)
c0029f25:	84 c0                	test   %al,%al
c0029f27:	74 1d                	je     c0029f46 <find_elem+0x60>
  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029f29:	89 1c 24             	mov    %ebx,(%esp)
c0029f2c:	e8 de eb ff ff       	call   c0028b0f <list_next>
c0029f31:	89 c3                	mov    %eax,%ebx
c0029f33:	89 2c 24             	mov    %ebp,(%esp)
c0029f36:	e8 28 ec ff ff       	call   c0028b63 <list_end>
c0029f3b:	39 d8                	cmp    %ebx,%eax
c0029f3d:	75 c0                	jne    c0029eff <find_elem+0x19>
        return hi; 
    }
  return NULL;
c0029f3f:	b8 00 00 00 00       	mov    $0x0,%eax
c0029f44:	eb 02                	jmp    c0029f48 <find_elem+0x62>
c0029f46:	89 d8                	mov    %ebx,%eax
}
c0029f48:	83 c4 1c             	add    $0x1c,%esp
c0029f4b:	5b                   	pop    %ebx
c0029f4c:	5e                   	pop    %esi
c0029f4d:	5f                   	pop    %edi
c0029f4e:	5d                   	pop    %ebp
c0029f4f:	c3                   	ret    

c0029f50 <rehash>:
   ideal.  This function can fail because of an out-of-memory
   condition, but that'll just make hash accesses less efficient;
   we can still continue. */
static void
rehash (struct hash *h) 
{
c0029f50:	55                   	push   %ebp
c0029f51:	57                   	push   %edi
c0029f52:	56                   	push   %esi
c0029f53:	53                   	push   %ebx
c0029f54:	83 ec 3c             	sub    $0x3c,%esp
c0029f57:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  size_t old_bucket_cnt, new_bucket_cnt;
  struct list *new_buckets, *old_buckets;
  size_t i;

  ASSERT (h != NULL);
c0029f5b:	85 c0                	test   %eax,%eax
c0029f5d:	75 2c                	jne    c0029f8b <rehash+0x3b>
c0029f5f:	c7 44 24 10 74 fe 02 	movl   $0xc002fe74,0x10(%esp)
c0029f66:	c0 
c0029f67:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c0029f6e:	c0 
c0029f6f:	c7 44 24 08 5e de 02 	movl   $0xc002de5e,0x8(%esp)
c0029f76:	c0 
c0029f77:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0029f7e:	00 
c0029f7f:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c0029f86:	e8 28 ea ff ff       	call   c00289b3 <debug_panic>

  /* Save old bucket info for later use. */
  old_buckets = h->buckets;
c0029f8b:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029f8f:	8b 48 08             	mov    0x8(%eax),%ecx
c0029f92:	89 4c 24 2c          	mov    %ecx,0x2c(%esp)
  old_bucket_cnt = h->bucket_cnt;
c0029f96:	8b 48 04             	mov    0x4(%eax),%ecx
c0029f99:	89 4c 24 28          	mov    %ecx,0x28(%esp)

  /* Calculate the number of buckets to use now.
     We want one bucket for about every BEST_ELEMS_PER_BUCKET.
     We must have at least four buckets, and the number of
     buckets must be a power of 2. */
  new_bucket_cnt = h->elem_cnt / BEST_ELEMS_PER_BUCKET;
c0029f9d:	8b 00                	mov    (%eax),%eax
c0029f9f:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029fa3:	89 c3                	mov    %eax,%ebx
c0029fa5:	d1 eb                	shr    %ebx
  if (new_bucket_cnt < 4)
    new_bucket_cnt = 4;
c0029fa7:	83 fb 03             	cmp    $0x3,%ebx
c0029faa:	b8 04 00 00 00       	mov    $0x4,%eax
c0029faf:	0f 46 d8             	cmovbe %eax,%ebx
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029fb2:	85 db                	test   %ebx,%ebx
c0029fb4:	0f 84 d2 00 00 00    	je     c002a08c <rehash+0x13c>
  return x & (x - 1);
c0029fba:	8d 43 ff             	lea    -0x1(%ebx),%eax
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029fbd:	85 d8                	test   %ebx,%eax
c0029fbf:	0f 85 c7 00 00 00    	jne    c002a08c <rehash+0x13c>
c0029fc5:	e9 cc 00 00 00       	jmp    c002a096 <rehash+0x146>
  /* Don't do anything if the bucket count wouldn't change. */
  if (new_bucket_cnt == old_bucket_cnt)
    return;

  /* Allocate new buckets and initialize them as empty. */
  new_buckets = malloc (sizeof *new_buckets * new_bucket_cnt);
c0029fca:	89 d8                	mov    %ebx,%eax
c0029fcc:	c1 e0 04             	shl    $0x4,%eax
c0029fcf:	89 04 24             	mov    %eax,(%esp)
c0029fd2:	e8 9d 9a ff ff       	call   c0023a74 <malloc>
c0029fd7:	89 c5                	mov    %eax,%ebp
  if (new_buckets == NULL) 
c0029fd9:	85 c0                	test   %eax,%eax
c0029fdb:	0f 84 bf 00 00 00    	je     c002a0a0 <rehash+0x150>
      /* Allocation failed.  This means that use of the hash table will
         be less efficient.  However, it is still usable, so
         there's no reason for it to be an error. */
      return;
    }
  for (i = 0; i < new_bucket_cnt; i++) 
c0029fe1:	85 db                	test   %ebx,%ebx
c0029fe3:	74 19                	je     c0029ffe <rehash+0xae>
c0029fe5:	89 c7                	mov    %eax,%edi
c0029fe7:	be 00 00 00 00       	mov    $0x0,%esi
    list_init (&new_buckets[i]);
c0029fec:	89 3c 24             	mov    %edi,(%esp)
c0029fef:	e8 8c ea ff ff       	call   c0028a80 <list_init>
  for (i = 0; i < new_bucket_cnt; i++) 
c0029ff4:	83 c6 01             	add    $0x1,%esi
c0029ff7:	83 c7 10             	add    $0x10,%edi
c0029ffa:	39 de                	cmp    %ebx,%esi
c0029ffc:	75 ee                	jne    c0029fec <rehash+0x9c>

  /* Install new bucket info. */
  h->buckets = new_buckets;
c0029ffe:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a002:	89 68 08             	mov    %ebp,0x8(%eax)
  h->bucket_cnt = new_bucket_cnt;
c002a005:	89 58 04             	mov    %ebx,0x4(%eax)

  /* Move each old element into the appropriate new bucket. */
  for (i = 0; i < old_bucket_cnt; i++) 
c002a008:	83 7c 24 28 00       	cmpl   $0x0,0x28(%esp)
c002a00d:	74 6f                	je     c002a07e <rehash+0x12e>
c002a00f:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a013:	89 44 24 20          	mov    %eax,0x20(%esp)
c002a017:	c7 44 24 24 00 00 00 	movl   $0x0,0x24(%esp)
c002a01e:	00 
    {
      struct list *old_bucket;
      struct list_elem *elem, *next;

      old_bucket = &old_buckets[i];
c002a01f:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a023:	89 c5                	mov    %eax,%ebp
      for (elem = list_begin (old_bucket);
c002a025:	89 04 24             	mov    %eax,(%esp)
c002a028:	e8 a4 ea ff ff       	call   c0028ad1 <list_begin>
c002a02d:	89 c3                	mov    %eax,%ebx
c002a02f:	eb 2d                	jmp    c002a05e <rehash+0x10e>
           elem != list_end (old_bucket); elem = next) 
        {
          struct list *new_bucket
c002a031:	89 da                	mov    %ebx,%edx
c002a033:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a037:	e8 84 fe ff ff       	call   c0029ec0 <find_bucket>
c002a03c:	89 c7                	mov    %eax,%edi
            = find_bucket (h, list_elem_to_hash_elem (elem));
          next = list_next (elem);
c002a03e:	89 1c 24             	mov    %ebx,(%esp)
c002a041:	e8 c9 ea ff ff       	call   c0028b0f <list_next>
c002a046:	89 c6                	mov    %eax,%esi
          list_remove (elem);
c002a048:	89 1c 24             	mov    %ebx,(%esp)
c002a04b:	e8 d4 ef ff ff       	call   c0029024 <list_remove>
          list_push_front (new_bucket, elem);
c002a050:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002a054:	89 3c 24             	mov    %edi,(%esp)
c002a057:	e8 82 ef ff ff       	call   c0028fde <list_push_front>
           elem != list_end (old_bucket); elem = next) 
c002a05c:	89 f3                	mov    %esi,%ebx
c002a05e:	89 2c 24             	mov    %ebp,(%esp)
c002a061:	e8 fd ea ff ff       	call   c0028b63 <list_end>
      for (elem = list_begin (old_bucket);
c002a066:	39 d8                	cmp    %ebx,%eax
c002a068:	75 c7                	jne    c002a031 <rehash+0xe1>
  for (i = 0; i < old_bucket_cnt; i++) 
c002a06a:	83 44 24 24 01       	addl   $0x1,0x24(%esp)
c002a06f:	83 44 24 20 10       	addl   $0x10,0x20(%esp)
c002a074:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a078:	39 44 24 24          	cmp    %eax,0x24(%esp)
c002a07c:	75 a1                	jne    c002a01f <rehash+0xcf>
        }
    }

  free (old_buckets);
c002a07e:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a082:	89 04 24             	mov    %eax,(%esp)
c002a085:	e8 71 9b ff ff       	call   c0023bfb <free>
c002a08a:	eb 14                	jmp    c002a0a0 <rehash+0x150>
  return x & (x - 1);
c002a08c:	8d 43 ff             	lea    -0x1(%ebx),%eax
c002a08f:	21 c3                	and    %eax,%ebx
c002a091:	e9 1c ff ff ff       	jmp    c0029fb2 <rehash+0x62>
  if (new_bucket_cnt == old_bucket_cnt)
c002a096:	3b 5c 24 28          	cmp    0x28(%esp),%ebx
c002a09a:	0f 85 2a ff ff ff    	jne    c0029fca <rehash+0x7a>
}
c002a0a0:	83 c4 3c             	add    $0x3c,%esp
c002a0a3:	5b                   	pop    %ebx
c002a0a4:	5e                   	pop    %esi
c002a0a5:	5f                   	pop    %edi
c002a0a6:	5d                   	pop    %ebp
c002a0a7:	c3                   	ret    

c002a0a8 <hash_clear>:
{
c002a0a8:	55                   	push   %ebp
c002a0a9:	57                   	push   %edi
c002a0aa:	56                   	push   %esi
c002a0ab:	53                   	push   %ebx
c002a0ac:	83 ec 1c             	sub    $0x1c,%esp
c002a0af:	8b 74 24 30          	mov    0x30(%esp),%esi
c002a0b3:	8b 7c 24 34          	mov    0x34(%esp),%edi
  for (i = 0; i < h->bucket_cnt; i++) 
c002a0b7:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c002a0bb:	74 43                	je     c002a100 <hash_clear+0x58>
c002a0bd:	bd 00 00 00 00       	mov    $0x0,%ebp
c002a0c2:	89 eb                	mov    %ebp,%ebx
c002a0c4:	c1 e3 04             	shl    $0x4,%ebx
      struct list *bucket = &h->buckets[i];
c002a0c7:	03 5e 08             	add    0x8(%esi),%ebx
      if (destructor != NULL) 
c002a0ca:	85 ff                	test   %edi,%edi
c002a0cc:	75 16                	jne    c002a0e4 <hash_clear+0x3c>
c002a0ce:	eb 20                	jmp    c002a0f0 <hash_clear+0x48>
            struct list_elem *list_elem = list_pop_front (bucket);
c002a0d0:	89 1c 24             	mov    %ebx,(%esp)
c002a0d3:	e8 4c f0 ff ff       	call   c0029124 <list_pop_front>
            destructor (hash_elem, h->aux);
c002a0d8:	8b 56 14             	mov    0x14(%esi),%edx
c002a0db:	89 54 24 04          	mov    %edx,0x4(%esp)
c002a0df:	89 04 24             	mov    %eax,(%esp)
c002a0e2:	ff d7                	call   *%edi
        while (!list_empty (bucket)) 
c002a0e4:	89 1c 24             	mov    %ebx,(%esp)
c002a0e7:	e8 ca ef ff ff       	call   c00290b6 <list_empty>
c002a0ec:	84 c0                	test   %al,%al
c002a0ee:	74 e0                	je     c002a0d0 <hash_clear+0x28>
      list_init (bucket); 
c002a0f0:	89 1c 24             	mov    %ebx,(%esp)
c002a0f3:	e8 88 e9 ff ff       	call   c0028a80 <list_init>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a0f8:	83 c5 01             	add    $0x1,%ebp
c002a0fb:	39 6e 04             	cmp    %ebp,0x4(%esi)
c002a0fe:	77 c2                	ja     c002a0c2 <hash_clear+0x1a>
  h->elem_cnt = 0;
c002a100:	c7 06 00 00 00 00    	movl   $0x0,(%esi)
}
c002a106:	83 c4 1c             	add    $0x1c,%esp
c002a109:	5b                   	pop    %ebx
c002a10a:	5e                   	pop    %esi
c002a10b:	5f                   	pop    %edi
c002a10c:	5d                   	pop    %ebp
c002a10d:	c3                   	ret    

c002a10e <hash_init>:
{
c002a10e:	53                   	push   %ebx
c002a10f:	83 ec 18             	sub    $0x18,%esp
c002a112:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  h->elem_cnt = 0;
c002a116:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  h->bucket_cnt = 4;
c002a11c:	c7 43 04 04 00 00 00 	movl   $0x4,0x4(%ebx)
  h->buckets = malloc (sizeof *h->buckets * h->bucket_cnt);
c002a123:	c7 04 24 40 00 00 00 	movl   $0x40,(%esp)
c002a12a:	e8 45 99 ff ff       	call   c0023a74 <malloc>
c002a12f:	89 c2                	mov    %eax,%edx
c002a131:	89 43 08             	mov    %eax,0x8(%ebx)
  h->hash = hash;
c002a134:	8b 44 24 24          	mov    0x24(%esp),%eax
c002a138:	89 43 0c             	mov    %eax,0xc(%ebx)
  h->less = less;
c002a13b:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a13f:	89 43 10             	mov    %eax,0x10(%ebx)
  h->aux = aux;
c002a142:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a146:	89 43 14             	mov    %eax,0x14(%ebx)
    return false;
c002a149:	b8 00 00 00 00       	mov    $0x0,%eax
  if (h->buckets != NULL) 
c002a14e:	85 d2                	test   %edx,%edx
c002a150:	74 15                	je     c002a167 <hash_init+0x59>
      hash_clear (h, NULL);
c002a152:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002a159:	00 
c002a15a:	89 1c 24             	mov    %ebx,(%esp)
c002a15d:	e8 46 ff ff ff       	call   c002a0a8 <hash_clear>
      return true;
c002a162:	b8 01 00 00 00       	mov    $0x1,%eax
}
c002a167:	83 c4 18             	add    $0x18,%esp
c002a16a:	5b                   	pop    %ebx
c002a16b:	c3                   	ret    

c002a16c <hash_destroy>:
{
c002a16c:	53                   	push   %ebx
c002a16d:	83 ec 18             	sub    $0x18,%esp
c002a170:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a174:	8b 44 24 24          	mov    0x24(%esp),%eax
  if (destructor != NULL)
c002a178:	85 c0                	test   %eax,%eax
c002a17a:	74 0c                	je     c002a188 <hash_destroy+0x1c>
    hash_clear (h, destructor);
c002a17c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a180:	89 1c 24             	mov    %ebx,(%esp)
c002a183:	e8 20 ff ff ff       	call   c002a0a8 <hash_clear>
  free (h->buckets);
c002a188:	8b 43 08             	mov    0x8(%ebx),%eax
c002a18b:	89 04 24             	mov    %eax,(%esp)
c002a18e:	e8 68 9a ff ff       	call   c0023bfb <free>
}
c002a193:	83 c4 18             	add    $0x18,%esp
c002a196:	5b                   	pop    %ebx
c002a197:	c3                   	ret    

c002a198 <hash_insert>:
{
c002a198:	55                   	push   %ebp
c002a199:	57                   	push   %edi
c002a19a:	56                   	push   %esi
c002a19b:	53                   	push   %ebx
c002a19c:	83 ec 1c             	sub    $0x1c,%esp
c002a19f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a1a3:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a1a7:	89 f2                	mov    %esi,%edx
c002a1a9:	89 d8                	mov    %ebx,%eax
c002a1ab:	e8 10 fd ff ff       	call   c0029ec0 <find_bucket>
c002a1b0:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a1b2:	89 f1                	mov    %esi,%ecx
c002a1b4:	89 c2                	mov    %eax,%edx
c002a1b6:	89 d8                	mov    %ebx,%eax
c002a1b8:	e8 29 fd ff ff       	call   c0029ee6 <find_elem>
c002a1bd:	89 c7                	mov    %eax,%edi
  if (old == NULL) 
c002a1bf:	85 c0                	test   %eax,%eax
c002a1c1:	75 0f                	jne    c002a1d2 <hash_insert+0x3a>

/* Inserts E into BUCKET (in hash table H). */
static void
insert_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
  h->elem_cnt++;
c002a1c3:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a1c6:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a1ca:	89 2c 24             	mov    %ebp,(%esp)
c002a1cd:	e8 0c ee ff ff       	call   c0028fde <list_push_front>
  rehash (h);
c002a1d2:	89 d8                	mov    %ebx,%eax
c002a1d4:	e8 77 fd ff ff       	call   c0029f50 <rehash>
}
c002a1d9:	89 f8                	mov    %edi,%eax
c002a1db:	83 c4 1c             	add    $0x1c,%esp
c002a1de:	5b                   	pop    %ebx
c002a1df:	5e                   	pop    %esi
c002a1e0:	5f                   	pop    %edi
c002a1e1:	5d                   	pop    %ebp
c002a1e2:	c3                   	ret    

c002a1e3 <hash_replace>:
{
c002a1e3:	55                   	push   %ebp
c002a1e4:	57                   	push   %edi
c002a1e5:	56                   	push   %esi
c002a1e6:	53                   	push   %ebx
c002a1e7:	83 ec 1c             	sub    $0x1c,%esp
c002a1ea:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a1ee:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a1f2:	89 f2                	mov    %esi,%edx
c002a1f4:	89 d8                	mov    %ebx,%eax
c002a1f6:	e8 c5 fc ff ff       	call   c0029ec0 <find_bucket>
c002a1fb:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a1fd:	89 f1                	mov    %esi,%ecx
c002a1ff:	89 c2                	mov    %eax,%edx
c002a201:	89 d8                	mov    %ebx,%eax
c002a203:	e8 de fc ff ff       	call   c0029ee6 <find_elem>
c002a208:	89 c7                	mov    %eax,%edi
  if (old != NULL)
c002a20a:	85 c0                	test   %eax,%eax
c002a20c:	74 0b                	je     c002a219 <hash_replace+0x36>

/* Removes E from hash table H. */
static void
remove_elem (struct hash *h, struct hash_elem *e) 
{
  h->elem_cnt--;
c002a20e:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a211:	89 04 24             	mov    %eax,(%esp)
c002a214:	e8 0b ee ff ff       	call   c0029024 <list_remove>
  h->elem_cnt++;
c002a219:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a21c:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a220:	89 2c 24             	mov    %ebp,(%esp)
c002a223:	e8 b6 ed ff ff       	call   c0028fde <list_push_front>
  rehash (h);
c002a228:	89 d8                	mov    %ebx,%eax
c002a22a:	e8 21 fd ff ff       	call   c0029f50 <rehash>
}
c002a22f:	89 f8                	mov    %edi,%eax
c002a231:	83 c4 1c             	add    $0x1c,%esp
c002a234:	5b                   	pop    %ebx
c002a235:	5e                   	pop    %esi
c002a236:	5f                   	pop    %edi
c002a237:	5d                   	pop    %ebp
c002a238:	c3                   	ret    

c002a239 <hash_find>:
{
c002a239:	56                   	push   %esi
c002a23a:	53                   	push   %ebx
c002a23b:	83 ec 04             	sub    $0x4,%esp
c002a23e:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a242:	8b 74 24 14          	mov    0x14(%esp),%esi
  return find_elem (h, find_bucket (h, e), e);
c002a246:	89 f2                	mov    %esi,%edx
c002a248:	89 d8                	mov    %ebx,%eax
c002a24a:	e8 71 fc ff ff       	call   c0029ec0 <find_bucket>
c002a24f:	89 f1                	mov    %esi,%ecx
c002a251:	89 c2                	mov    %eax,%edx
c002a253:	89 d8                	mov    %ebx,%eax
c002a255:	e8 8c fc ff ff       	call   c0029ee6 <find_elem>
}
c002a25a:	83 c4 04             	add    $0x4,%esp
c002a25d:	5b                   	pop    %ebx
c002a25e:	5e                   	pop    %esi
c002a25f:	c3                   	ret    

c002a260 <hash_delete>:
{
c002a260:	56                   	push   %esi
c002a261:	53                   	push   %ebx
c002a262:	83 ec 14             	sub    $0x14,%esp
c002a265:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a269:	8b 74 24 24          	mov    0x24(%esp),%esi
  struct hash_elem *found = find_elem (h, find_bucket (h, e), e);
c002a26d:	89 f2                	mov    %esi,%edx
c002a26f:	89 d8                	mov    %ebx,%eax
c002a271:	e8 4a fc ff ff       	call   c0029ec0 <find_bucket>
c002a276:	89 f1                	mov    %esi,%ecx
c002a278:	89 c2                	mov    %eax,%edx
c002a27a:	89 d8                	mov    %ebx,%eax
c002a27c:	e8 65 fc ff ff       	call   c0029ee6 <find_elem>
c002a281:	89 c6                	mov    %eax,%esi
  if (found != NULL) 
c002a283:	85 c0                	test   %eax,%eax
c002a285:	74 12                	je     c002a299 <hash_delete+0x39>
  h->elem_cnt--;
c002a287:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a28a:	89 04 24             	mov    %eax,(%esp)
c002a28d:	e8 92 ed ff ff       	call   c0029024 <list_remove>
      rehash (h); 
c002a292:	89 d8                	mov    %ebx,%eax
c002a294:	e8 b7 fc ff ff       	call   c0029f50 <rehash>
}
c002a299:	89 f0                	mov    %esi,%eax
c002a29b:	83 c4 14             	add    $0x14,%esp
c002a29e:	5b                   	pop    %ebx
c002a29f:	5e                   	pop    %esi
c002a2a0:	c3                   	ret    

c002a2a1 <hash_apply>:
{
c002a2a1:	55                   	push   %ebp
c002a2a2:	57                   	push   %edi
c002a2a3:	56                   	push   %esi
c002a2a4:	53                   	push   %ebx
c002a2a5:	83 ec 2c             	sub    $0x2c,%esp
c002a2a8:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (action != NULL);
c002a2ac:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c002a2b1:	74 10                	je     c002a2c3 <hash_apply+0x22>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a2b3:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a2ba:	00 
c002a2bb:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c002a2bf:	75 2e                	jne    c002a2ef <hash_apply+0x4e>
c002a2c1:	eb 76                	jmp    c002a339 <hash_apply+0x98>
  ASSERT (action != NULL);
c002a2c3:	c7 44 24 10 96 fe 02 	movl   $0xc002fe96,0x10(%esp)
c002a2ca:	c0 
c002a2cb:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a2d2:	c0 
c002a2d3:	c7 44 24 08 53 de 02 	movl   $0xc002de53,0x8(%esp)
c002a2da:	c0 
c002a2db:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
c002a2e2:	00 
c002a2e3:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a2ea:	e8 c4 e6 ff ff       	call   c00289b3 <debug_panic>
c002a2ef:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
c002a2f3:	c1 e7 04             	shl    $0x4,%edi
      struct list *bucket = &h->buckets[i];
c002a2f6:	03 7d 08             	add    0x8(%ebp),%edi
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a2f9:	89 3c 24             	mov    %edi,(%esp)
c002a2fc:	e8 d0 e7 ff ff       	call   c0028ad1 <list_begin>
c002a301:	89 c3                	mov    %eax,%ebx
c002a303:	eb 1a                	jmp    c002a31f <hash_apply+0x7e>
          next = list_next (elem);
c002a305:	89 1c 24             	mov    %ebx,(%esp)
c002a308:	e8 02 e8 ff ff       	call   c0028b0f <list_next>
c002a30d:	89 c6                	mov    %eax,%esi
          action (list_elem_to_hash_elem (elem), h->aux);
c002a30f:	8b 45 14             	mov    0x14(%ebp),%eax
c002a312:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a316:	89 1c 24             	mov    %ebx,(%esp)
c002a319:	ff 54 24 44          	call   *0x44(%esp)
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a31d:	89 f3                	mov    %esi,%ebx
c002a31f:	89 3c 24             	mov    %edi,(%esp)
c002a322:	e8 3c e8 ff ff       	call   c0028b63 <list_end>
c002a327:	39 d8                	cmp    %ebx,%eax
c002a329:	75 da                	jne    c002a305 <hash_apply+0x64>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a32b:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)
c002a330:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a334:	39 45 04             	cmp    %eax,0x4(%ebp)
c002a337:	77 b6                	ja     c002a2ef <hash_apply+0x4e>
}
c002a339:	83 c4 2c             	add    $0x2c,%esp
c002a33c:	5b                   	pop    %ebx
c002a33d:	5e                   	pop    %esi
c002a33e:	5f                   	pop    %edi
c002a33f:	5d                   	pop    %ebp
c002a340:	c3                   	ret    

c002a341 <hash_first>:
{
c002a341:	53                   	push   %ebx
c002a342:	83 ec 28             	sub    $0x28,%esp
c002a345:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a349:	8b 44 24 34          	mov    0x34(%esp),%eax
  ASSERT (i != NULL);
c002a34d:	85 db                	test   %ebx,%ebx
c002a34f:	75 2c                	jne    c002a37d <hash_first+0x3c>
c002a351:	c7 44 24 10 a5 fe 02 	movl   $0xc002fea5,0x10(%esp)
c002a358:	c0 
c002a359:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a360:	c0 
c002a361:	c7 44 24 08 48 de 02 	movl   $0xc002de48,0x8(%esp)
c002a368:	c0 
c002a369:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
c002a370:	00 
c002a371:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a378:	e8 36 e6 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (h != NULL);
c002a37d:	85 c0                	test   %eax,%eax
c002a37f:	75 2c                	jne    c002a3ad <hash_first+0x6c>
c002a381:	c7 44 24 10 74 fe 02 	movl   $0xc002fe74,0x10(%esp)
c002a388:	c0 
c002a389:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a390:	c0 
c002a391:	c7 44 24 08 48 de 02 	movl   $0xc002de48,0x8(%esp)
c002a398:	c0 
c002a399:	c7 44 24 04 cb 00 00 	movl   $0xcb,0x4(%esp)
c002a3a0:	00 
c002a3a1:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a3a8:	e8 06 e6 ff ff       	call   c00289b3 <debug_panic>
  i->hash = h;
c002a3ad:	89 03                	mov    %eax,(%ebx)
  i->bucket = i->hash->buckets;
c002a3af:	8b 40 08             	mov    0x8(%eax),%eax
c002a3b2:	89 43 04             	mov    %eax,0x4(%ebx)
  i->elem = list_elem_to_hash_elem (list_head (i->bucket));
c002a3b5:	89 04 24             	mov    %eax,(%esp)
c002a3b8:	e8 0b ea ff ff       	call   c0028dc8 <list_head>
c002a3bd:	89 43 08             	mov    %eax,0x8(%ebx)
}
c002a3c0:	83 c4 28             	add    $0x28,%esp
c002a3c3:	5b                   	pop    %ebx
c002a3c4:	c3                   	ret    

c002a3c5 <hash_next>:
{
c002a3c5:	56                   	push   %esi
c002a3c6:	53                   	push   %ebx
c002a3c7:	83 ec 24             	sub    $0x24,%esp
c002a3ca:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (i != NULL);
c002a3ce:	85 db                	test   %ebx,%ebx
c002a3d0:	75 2c                	jne    c002a3fe <hash_next+0x39>
c002a3d2:	c7 44 24 10 a5 fe 02 	movl   $0xc002fea5,0x10(%esp)
c002a3d9:	c0 
c002a3da:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a3e1:	c0 
c002a3e2:	c7 44 24 08 3e de 02 	movl   $0xc002de3e,0x8(%esp)
c002a3e9:	c0 
c002a3ea:	c7 44 24 04 dd 00 00 	movl   $0xdd,0x4(%esp)
c002a3f1:	00 
c002a3f2:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a3f9:	e8 b5 e5 ff ff       	call   c00289b3 <debug_panic>
  i->elem = list_elem_to_hash_elem (list_next (&i->elem->list_elem));
c002a3fe:	8b 43 08             	mov    0x8(%ebx),%eax
c002a401:	89 04 24             	mov    %eax,(%esp)
c002a404:	e8 06 e7 ff ff       	call   c0028b0f <list_next>
c002a409:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a40c:	eb 2c                	jmp    c002a43a <hash_next+0x75>
      if (++i->bucket >= i->hash->buckets + i->hash->bucket_cnt)
c002a40e:	8b 43 04             	mov    0x4(%ebx),%eax
c002a411:	83 c0 10             	add    $0x10,%eax
c002a414:	89 43 04             	mov    %eax,0x4(%ebx)
c002a417:	8b 13                	mov    (%ebx),%edx
c002a419:	8b 4a 04             	mov    0x4(%edx),%ecx
c002a41c:	c1 e1 04             	shl    $0x4,%ecx
c002a41f:	03 4a 08             	add    0x8(%edx),%ecx
c002a422:	39 c8                	cmp    %ecx,%eax
c002a424:	72 09                	jb     c002a42f <hash_next+0x6a>
          i->elem = NULL;
c002a426:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
          break;
c002a42d:	eb 1d                	jmp    c002a44c <hash_next+0x87>
      i->elem = list_elem_to_hash_elem (list_begin (i->bucket));
c002a42f:	89 04 24             	mov    %eax,(%esp)
c002a432:	e8 9a e6 ff ff       	call   c0028ad1 <list_begin>
c002a437:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a43a:	8b 73 08             	mov    0x8(%ebx),%esi
c002a43d:	8b 43 04             	mov    0x4(%ebx),%eax
c002a440:	89 04 24             	mov    %eax,(%esp)
c002a443:	e8 1b e7 ff ff       	call   c0028b63 <list_end>
c002a448:	39 c6                	cmp    %eax,%esi
c002a44a:	74 c2                	je     c002a40e <hash_next+0x49>
  return i->elem;
c002a44c:	8b 43 08             	mov    0x8(%ebx),%eax
}
c002a44f:	83 c4 24             	add    $0x24,%esp
c002a452:	5b                   	pop    %ebx
c002a453:	5e                   	pop    %esi
c002a454:	c3                   	ret    

c002a455 <hash_cur>:
  return i->elem;
c002a455:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a459:	8b 40 08             	mov    0x8(%eax),%eax
}
c002a45c:	c3                   	ret    

c002a45d <hash_size>:
  return h->elem_cnt;
c002a45d:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a461:	8b 00                	mov    (%eax),%eax
}
c002a463:	c3                   	ret    

c002a464 <hash_empty>:
  return h->elem_cnt == 0;
c002a464:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a468:	83 38 00             	cmpl   $0x0,(%eax)
c002a46b:	0f 94 c0             	sete   %al
}
c002a46e:	c3                   	ret    

c002a46f <hash_bytes>:
{
c002a46f:	53                   	push   %ebx
c002a470:	83 ec 28             	sub    $0x28,%esp
c002a473:	8b 54 24 30          	mov    0x30(%esp),%edx
c002a477:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (buf != NULL);
c002a47b:	85 d2                	test   %edx,%edx
c002a47d:	74 0e                	je     c002a48d <hash_bytes+0x1e>
c002a47f:	8d 1c 0a             	lea    (%edx,%ecx,1),%ebx
  while (size-- > 0)
c002a482:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a487:	85 c9                	test   %ecx,%ecx
c002a489:	75 2e                	jne    c002a4b9 <hash_bytes+0x4a>
c002a48b:	eb 3f                	jmp    c002a4cc <hash_bytes+0x5d>
  ASSERT (buf != NULL);
c002a48d:	c7 44 24 10 af fe 02 	movl   $0xc002feaf,0x10(%esp)
c002a494:	c0 
c002a495:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a49c:	c0 
c002a49d:	c7 44 24 08 33 de 02 	movl   $0xc002de33,0x8(%esp)
c002a4a4:	c0 
c002a4a5:	c7 44 24 04 10 01 00 	movl   $0x110,0x4(%esp)
c002a4ac:	00 
c002a4ad:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a4b4:	e8 fa e4 ff ff       	call   c00289b3 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *buf++;
c002a4b9:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a4bf:	83 c2 01             	add    $0x1,%edx
c002a4c2:	0f b6 4a ff          	movzbl -0x1(%edx),%ecx
c002a4c6:	31 c8                	xor    %ecx,%eax
  while (size-- > 0)
c002a4c8:	39 da                	cmp    %ebx,%edx
c002a4ca:	75 ed                	jne    c002a4b9 <hash_bytes+0x4a>
} 
c002a4cc:	83 c4 28             	add    $0x28,%esp
c002a4cf:	5b                   	pop    %ebx
c002a4d0:	c3                   	ret    

c002a4d1 <hash_string>:
{
c002a4d1:	83 ec 2c             	sub    $0x2c,%esp
c002a4d4:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002a4d8:	85 d2                	test   %edx,%edx
c002a4da:	74 0e                	je     c002a4ea <hash_string+0x19>
  while (*s != '\0')
c002a4dc:	0f b6 0a             	movzbl (%edx),%ecx
c002a4df:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a4e4:	84 c9                	test   %cl,%cl
c002a4e6:	75 2e                	jne    c002a516 <hash_string+0x45>
c002a4e8:	eb 41                	jmp    c002a52b <hash_string+0x5a>
  ASSERT (s != NULL);
c002a4ea:	c7 44 24 10 5a fa 02 	movl   $0xc002fa5a,0x10(%esp)
c002a4f1:	c0 
c002a4f2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a4f9:	c0 
c002a4fa:	c7 44 24 08 27 de 02 	movl   $0xc002de27,0x8(%esp)
c002a501:	c0 
c002a502:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c002a509:	00 
c002a50a:	c7 04 24 7e fe 02 c0 	movl   $0xc002fe7e,(%esp)
c002a511:	e8 9d e4 ff ff       	call   c00289b3 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *s++;
c002a516:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a51c:	83 c2 01             	add    $0x1,%edx
c002a51f:	0f b6 c9             	movzbl %cl,%ecx
c002a522:	31 c8                	xor    %ecx,%eax
  while (*s != '\0')
c002a524:	0f b6 0a             	movzbl (%edx),%ecx
c002a527:	84 c9                	test   %cl,%cl
c002a529:	75 eb                	jne    c002a516 <hash_string+0x45>
}
c002a52b:	83 c4 2c             	add    $0x2c,%esp
c002a52e:	c3                   	ret    

c002a52f <hash_int>:
{
c002a52f:	83 ec 1c             	sub    $0x1c,%esp
  return hash_bytes (&i, sizeof i);
c002a532:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002a539:	00 
c002a53a:	8d 44 24 20          	lea    0x20(%esp),%eax
c002a53e:	89 04 24             	mov    %eax,(%esp)
c002a541:	e8 29 ff ff ff       	call   c002a46f <hash_bytes>
}
c002a546:	83 c4 1c             	add    $0x1c,%esp
c002a549:	c3                   	ret    

c002a54a <putchar_have_lock>:
/* Writes C to the vga display and serial port.
   The caller has already acquired the console lock if
   appropriate. */
static void
putchar_have_lock (uint8_t c) 
{
c002a54a:	53                   	push   %ebx
c002a54b:	83 ec 28             	sub    $0x28,%esp
c002a54e:	89 c3                	mov    %eax,%ebx
  return (intr_context ()
c002a550:	e8 1c 77 ff ff       	call   c0021c71 <intr_context>
          || lock_held_by_current_thread (&console_lock));
c002a555:	84 c0                	test   %al,%al
c002a557:	75 45                	jne    c002a59e <putchar_have_lock+0x54>
          || !use_console_lock
c002a559:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a560:	74 3c                	je     c002a59e <putchar_have_lock+0x54>
          || lock_held_by_current_thread (&console_lock));
c002a562:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a569:	e8 f3 88 ff ff       	call   c0022e61 <lock_held_by_current_thread>
  ASSERT (console_locked_by_current_thread ());
c002a56e:	84 c0                	test   %al,%al
c002a570:	75 2c                	jne    c002a59e <putchar_have_lock+0x54>
c002a572:	c7 44 24 10 bc fe 02 	movl   $0xc002febc,0x10(%esp)
c002a579:	c0 
c002a57a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a581:	c0 
c002a582:	c7 44 24 08 65 de 02 	movl   $0xc002de65,0x8(%esp)
c002a589:	c0 
c002a58a:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c002a591:	00 
c002a592:	c7 04 24 01 ff 02 c0 	movl   $0xc002ff01,(%esp)
c002a599:	e8 15 e4 ff ff       	call   c00289b3 <debug_panic>
  write_cnt++;
c002a59e:	83 05 e0 7a 03 c0 01 	addl   $0x1,0xc0037ae0
c002a5a5:	83 15 e4 7a 03 c0 00 	adcl   $0x0,0xc0037ae4
  serial_putc (c);
c002a5ac:	0f b6 db             	movzbl %bl,%ebx
c002a5af:	89 1c 24             	mov    %ebx,(%esp)
c002a5b2:	e8 95 a5 ff ff       	call   c0024b4c <serial_putc>
  vga_putc (c);
c002a5b7:	89 1c 24             	mov    %ebx,(%esp)
c002a5ba:	e8 aa a1 ff ff       	call   c0024769 <vga_putc>
}
c002a5bf:	83 c4 28             	add    $0x28,%esp
c002a5c2:	5b                   	pop    %ebx
c002a5c3:	c3                   	ret    

c002a5c4 <vprintf_helper>:
{
c002a5c4:	83 ec 0c             	sub    $0xc,%esp
c002a5c7:	8b 44 24 14          	mov    0x14(%esp),%eax
  (*char_cnt)++;
c002a5cb:	83 00 01             	addl   $0x1,(%eax)
  putchar_have_lock (c);
c002a5ce:	0f b6 44 24 10       	movzbl 0x10(%esp),%eax
c002a5d3:	e8 72 ff ff ff       	call   c002a54a <putchar_have_lock>
}
c002a5d8:	83 c4 0c             	add    $0xc,%esp
c002a5db:	c3                   	ret    

c002a5dc <acquire_console>:
{
c002a5dc:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a5df:	e8 8d 76 ff ff       	call   c0021c71 <intr_context>
c002a5e4:	84 c0                	test   %al,%al
c002a5e6:	75 2e                	jne    c002a616 <acquire_console+0x3a>
c002a5e8:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a5ef:	74 25                	je     c002a616 <acquire_console+0x3a>
      if (lock_held_by_current_thread (&console_lock)) 
c002a5f1:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5f8:	e8 64 88 ff ff       	call   c0022e61 <lock_held_by_current_thread>
c002a5fd:	84 c0                	test   %al,%al
c002a5ff:	74 09                	je     c002a60a <acquire_console+0x2e>
        console_lock_depth++; 
c002a601:	83 05 e8 7a 03 c0 01 	addl   $0x1,0xc0037ae8
c002a608:	eb 0c                	jmp    c002a616 <acquire_console+0x3a>
        lock_acquire (&console_lock); 
c002a60a:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a611:	e8 94 88 ff ff       	call   c0022eaa <lock_acquire>
}
c002a616:	83 c4 1c             	add    $0x1c,%esp
c002a619:	c3                   	ret    

c002a61a <release_console>:
{
c002a61a:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a61d:	e8 4f 76 ff ff       	call   c0021c71 <intr_context>
c002a622:	84 c0                	test   %al,%al
c002a624:	75 28                	jne    c002a64e <release_console+0x34>
c002a626:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a62d:	74 1f                	je     c002a64e <release_console+0x34>
      if (console_lock_depth > 0)
c002a62f:	a1 e8 7a 03 c0       	mov    0xc0037ae8,%eax
c002a634:	85 c0                	test   %eax,%eax
c002a636:	7e 0a                	jle    c002a642 <release_console+0x28>
        console_lock_depth--;
c002a638:	83 e8 01             	sub    $0x1,%eax
c002a63b:	a3 e8 7a 03 c0       	mov    %eax,0xc0037ae8
c002a640:	eb 0c                	jmp    c002a64e <release_console+0x34>
        lock_release (&console_lock); 
c002a642:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a649:	e8 26 8a ff ff       	call   c0023074 <lock_release>
}
c002a64e:	83 c4 1c             	add    $0x1c,%esp
c002a651:	c3                   	ret    

c002a652 <console_init>:
{
c002a652:	83 ec 1c             	sub    $0x1c,%esp
  lock_init (&console_lock);
c002a655:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a65c:	e8 ac 87 ff ff       	call   c0022e0d <lock_init>
  use_console_lock = true;
c002a661:	c6 05 ec 7a 03 c0 01 	movb   $0x1,0xc0037aec
}
c002a668:	83 c4 1c             	add    $0x1c,%esp
c002a66b:	c3                   	ret    

c002a66c <console_panic>:
  use_console_lock = false;
c002a66c:	c6 05 ec 7a 03 c0 00 	movb   $0x0,0xc0037aec
c002a673:	c3                   	ret    

c002a674 <console_print_stats>:
{
c002a674:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Console: %lld characters output\n", write_cnt);
c002a677:	a1 e0 7a 03 c0       	mov    0xc0037ae0,%eax
c002a67c:	8b 15 e4 7a 03 c0    	mov    0xc0037ae4,%edx
c002a682:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a686:	89 54 24 08          	mov    %edx,0x8(%esp)
c002a68a:	c7 04 24 e0 fe 02 c0 	movl   $0xc002fee0,(%esp)
c002a691:	e8 c8 c4 ff ff       	call   c0026b5e <printf>
}
c002a696:	83 c4 1c             	add    $0x1c,%esp
c002a699:	c3                   	ret    

c002a69a <vprintf>:
{
c002a69a:	83 ec 2c             	sub    $0x2c,%esp
  int char_cnt = 0;
c002a69d:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a6a4:	00 
  acquire_console ();
c002a6a5:	e8 32 ff ff ff       	call   c002a5dc <acquire_console>
  __vprintf (format, args, vprintf_helper, &char_cnt);
c002a6aa:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c002a6ae:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002a6b2:	c7 44 24 08 c4 a5 02 	movl   $0xc002a5c4,0x8(%esp)
c002a6b9:	c0 
c002a6ba:	8b 44 24 34          	mov    0x34(%esp),%eax
c002a6be:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a6c2:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a6c6:	89 04 24             	mov    %eax,(%esp)
c002a6c9:	e8 d6 c4 ff ff       	call   c0026ba4 <__vprintf>
  release_console ();
c002a6ce:	e8 47 ff ff ff       	call   c002a61a <release_console>
}
c002a6d3:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a6d7:	83 c4 2c             	add    $0x2c,%esp
c002a6da:	c3                   	ret    

c002a6db <puts>:
{
c002a6db:	53                   	push   %ebx
c002a6dc:	83 ec 08             	sub    $0x8,%esp
c002a6df:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a6e3:	e8 f4 fe ff ff       	call   c002a5dc <acquire_console>
  while (*s != '\0')
c002a6e8:	0f b6 03             	movzbl (%ebx),%eax
c002a6eb:	84 c0                	test   %al,%al
c002a6ed:	74 12                	je     c002a701 <puts+0x26>
    putchar_have_lock (*s++);
c002a6ef:	83 c3 01             	add    $0x1,%ebx
c002a6f2:	0f b6 c0             	movzbl %al,%eax
c002a6f5:	e8 50 fe ff ff       	call   c002a54a <putchar_have_lock>
  while (*s != '\0')
c002a6fa:	0f b6 03             	movzbl (%ebx),%eax
c002a6fd:	84 c0                	test   %al,%al
c002a6ff:	75 ee                	jne    c002a6ef <puts+0x14>
  putchar_have_lock ('\n');
c002a701:	b8 0a 00 00 00       	mov    $0xa,%eax
c002a706:	e8 3f fe ff ff       	call   c002a54a <putchar_have_lock>
  release_console ();
c002a70b:	e8 0a ff ff ff       	call   c002a61a <release_console>
}
c002a710:	b8 00 00 00 00       	mov    $0x0,%eax
c002a715:	83 c4 08             	add    $0x8,%esp
c002a718:	5b                   	pop    %ebx
c002a719:	c3                   	ret    

c002a71a <putbuf>:
{
c002a71a:	56                   	push   %esi
c002a71b:	53                   	push   %ebx
c002a71c:	83 ec 04             	sub    $0x4,%esp
c002a71f:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a723:	8b 74 24 14          	mov    0x14(%esp),%esi
  acquire_console ();
c002a727:	e8 b0 fe ff ff       	call   c002a5dc <acquire_console>
  while (n-- > 0)
c002a72c:	85 f6                	test   %esi,%esi
c002a72e:	74 11                	je     c002a741 <putbuf+0x27>
    putchar_have_lock (*buffer++);
c002a730:	83 c3 01             	add    $0x1,%ebx
c002a733:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
c002a737:	e8 0e fe ff ff       	call   c002a54a <putchar_have_lock>
  while (n-- > 0)
c002a73c:	83 ee 01             	sub    $0x1,%esi
c002a73f:	75 ef                	jne    c002a730 <putbuf+0x16>
  release_console ();
c002a741:	e8 d4 fe ff ff       	call   c002a61a <release_console>
}
c002a746:	83 c4 04             	add    $0x4,%esp
c002a749:	5b                   	pop    %ebx
c002a74a:	5e                   	pop    %esi
c002a74b:	c3                   	ret    

c002a74c <putchar>:
{
c002a74c:	53                   	push   %ebx
c002a74d:	83 ec 08             	sub    $0x8,%esp
c002a750:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a754:	e8 83 fe ff ff       	call   c002a5dc <acquire_console>
  putchar_have_lock (c);
c002a759:	0f b6 c3             	movzbl %bl,%eax
c002a75c:	e8 e9 fd ff ff       	call   c002a54a <putchar_have_lock>
  release_console ();
c002a761:	e8 b4 fe ff ff       	call   c002a61a <release_console>
}
c002a766:	89 d8                	mov    %ebx,%eax
c002a768:	83 c4 08             	add    $0x8,%esp
c002a76b:	5b                   	pop    %ebx
c002a76c:	c3                   	ret    

c002a76d <msg>:
/* Prints FORMAT as if with printf(),
   prefixing the output by the name of the test
   and following it with a new-line character. */
void
msg (const char *format, ...) 
{
c002a76d:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) ", test_name);
c002a770:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a775:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a779:	c7 04 24 1c ff 02 c0 	movl   $0xc002ff1c,(%esp)
c002a780:	e8 d9 c3 ff ff       	call   c0026b5e <printf>
  va_start (args, format);
c002a785:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a789:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a78d:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a791:	89 04 24             	mov    %eax,(%esp)
c002a794:	e8 01 ff ff ff       	call   c002a69a <vprintf>
  va_end (args);
  putchar ('\n');
c002a799:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a7a0:	e8 a7 ff ff ff       	call   c002a74c <putchar>
}
c002a7a5:	83 c4 1c             	add    $0x1c,%esp
c002a7a8:	c3                   	ret    

c002a7a9 <run_test>:
{
c002a7a9:	56                   	push   %esi
c002a7aa:	53                   	push   %ebx
c002a7ab:	83 ec 24             	sub    $0x24,%esp
c002a7ae:	8b 74 24 30          	mov    0x30(%esp),%esi
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a7b2:	bb a0 de 02 c0       	mov    $0xc002dea0,%ebx
    if (!strcmp (name, t->name))
c002a7b7:	8b 03                	mov    (%ebx),%eax
c002a7b9:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a7bd:	89 34 24             	mov    %esi,(%esp)
c002a7c0:	e8 02 d3 ff ff       	call   c0027ac7 <strcmp>
c002a7c5:	85 c0                	test   %eax,%eax
c002a7c7:	75 23                	jne    c002a7ec <run_test+0x43>
        test_name = name;
c002a7c9:	89 35 24 7b 03 c0    	mov    %esi,0xc0037b24
        msg ("begin");
c002a7cf:	c7 04 24 22 ff 02 c0 	movl   $0xc002ff22,(%esp)
c002a7d6:	e8 92 ff ff ff       	call   c002a76d <msg>
        t->function ();
c002a7db:	ff 53 04             	call   *0x4(%ebx)
        msg ("end");
c002a7de:	c7 04 24 28 ff 02 c0 	movl   $0xc002ff28,(%esp)
c002a7e5:	e8 83 ff ff ff       	call   c002a76d <msg>
c002a7ea:	eb 33                	jmp    c002a81f <run_test+0x76>
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a7ec:	83 c3 08             	add    $0x8,%ebx
c002a7ef:	81 fb 78 df 02 c0    	cmp    $0xc002df78,%ebx
c002a7f5:	72 c0                	jb     c002a7b7 <run_test+0xe>
  PANIC ("no test named \"%s\"", name);
c002a7f7:	89 74 24 10          	mov    %esi,0x10(%esp)
c002a7fb:	c7 44 24 0c 2c ff 02 	movl   $0xc002ff2c,0xc(%esp)
c002a802:	c0 
c002a803:	c7 44 24 08 85 de 02 	movl   $0xc002de85,0x8(%esp)
c002a80a:	c0 
c002a80b:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a812:	00 
c002a813:	c7 04 24 3f ff 02 c0 	movl   $0xc002ff3f,(%esp)
c002a81a:	e8 94 e1 ff ff       	call   c00289b3 <debug_panic>
}
c002a81f:	83 c4 24             	add    $0x24,%esp
c002a822:	5b                   	pop    %ebx
c002a823:	5e                   	pop    %esi
c002a824:	c3                   	ret    

c002a825 <fail>:
   prefixing the output by the name of the test and FAIL:
   and following it with a new-line character,
   and then panics the kernel. */
void
fail (const char *format, ...) 
{
c002a825:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) FAIL: ", test_name);
c002a828:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a82d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a831:	c7 04 24 5b ff 02 c0 	movl   $0xc002ff5b,(%esp)
c002a838:	e8 21 c3 ff ff       	call   c0026b5e <printf>
  va_start (args, format);
c002a83d:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a841:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a845:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a849:	89 04 24             	mov    %eax,(%esp)
c002a84c:	e8 49 fe ff ff       	call   c002a69a <vprintf>
  va_end (args);
  putchar ('\n');
c002a851:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a858:	e8 ef fe ff ff       	call   c002a74c <putchar>

  PANIC ("test failed");
c002a85d:	c7 44 24 0c 67 ff 02 	movl   $0xc002ff67,0xc(%esp)
c002a864:	c0 
c002a865:	c7 44 24 08 80 de 02 	movl   $0xc002de80,0x8(%esp)
c002a86c:	c0 
c002a86d:	c7 44 24 04 5d 00 00 	movl   $0x5d,0x4(%esp)
c002a874:	00 
c002a875:	c7 04 24 3f ff 02 c0 	movl   $0xc002ff3f,(%esp)
c002a87c:	e8 32 e1 ff ff       	call   c00289b3 <debug_panic>

c002a881 <pass>:
}

/* Prints a message indicating the current test passed. */
void
pass (void) 
{
c002a881:	83 ec 1c             	sub    $0x1c,%esp
  printf ("(%s) PASS\n", test_name);
c002a884:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a889:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a88d:	c7 04 24 73 ff 02 c0 	movl   $0xc002ff73,(%esp)
c002a894:	e8 c5 c2 ff ff       	call   c0026b5e <printf>
}
c002a899:	83 c4 1c             	add    $0x1c,%esp
c002a89c:	c3                   	ret    
c002a89d:	90                   	nop
c002a89e:	90                   	nop
c002a89f:	90                   	nop

c002a8a0 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *t_) 
{
c002a8a0:	55                   	push   %ebp
c002a8a1:	57                   	push   %edi
c002a8a2:	56                   	push   %esi
c002a8a3:	53                   	push   %ebx
c002a8a4:	83 ec 1c             	sub    $0x1c,%esp
  struct sleep_thread *t = t_;
  struct sleep_test *test = t->test;
c002a8a7:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a8ab:	8b 18                	mov    (%eax),%ebx
  int i;

  for (i = 1; i <= test->iterations; i++) 
c002a8ad:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002a8b1:	7e 63                	jle    c002a916 <sleeper+0x76>
c002a8b3:	bd 01 00 00 00       	mov    $0x1,%ebp
    {
      int64_t sleep_until = test->start + i * t->duration;
      timer_sleep (sleep_until - timer_ticks ());
      lock_acquire (&test->output_lock);
c002a8b8:	8d 43 0c             	lea    0xc(%ebx),%eax
c002a8bb:	89 44 24 0c          	mov    %eax,0xc(%esp)
      int64_t sleep_until = test->start + i * t->duration;
c002a8bf:	89 e8                	mov    %ebp,%eax
c002a8c1:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a8c5:	0f af 41 08          	imul   0x8(%ecx),%eax
c002a8c9:	99                   	cltd   
c002a8ca:	03 03                	add    (%ebx),%eax
c002a8cc:	13 53 04             	adc    0x4(%ebx),%edx
c002a8cf:	89 c6                	mov    %eax,%esi
c002a8d1:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002a8d3:	e8 6c 99 ff ff       	call   c0024244 <timer_ticks>
c002a8d8:	29 c6                	sub    %eax,%esi
c002a8da:	19 d7                	sbb    %edx,%edi
c002a8dc:	89 34 24             	mov    %esi,(%esp)
c002a8df:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a8e3:	e8 a4 99 ff ff       	call   c002428c <timer_sleep>
      lock_acquire (&test->output_lock);
c002a8e8:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c002a8ec:	89 3c 24             	mov    %edi,(%esp)
c002a8ef:	e8 b6 85 ff ff       	call   c0022eaa <lock_acquire>
      *test->output_pos++ = t->id;
c002a8f4:	8b 43 30             	mov    0x30(%ebx),%eax
c002a8f7:	8d 50 04             	lea    0x4(%eax),%edx
c002a8fa:	89 53 30             	mov    %edx,0x30(%ebx)
c002a8fd:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a901:	8b 51 04             	mov    0x4(%ecx),%edx
c002a904:	89 10                	mov    %edx,(%eax)
      lock_release (&test->output_lock);
c002a906:	89 3c 24             	mov    %edi,(%esp)
c002a909:	e8 66 87 ff ff       	call   c0023074 <lock_release>
  for (i = 1; i <= test->iterations; i++) 
c002a90e:	83 c5 01             	add    $0x1,%ebp
c002a911:	39 6b 08             	cmp    %ebp,0x8(%ebx)
c002a914:	7d a9                	jge    c002a8bf <sleeper+0x1f>
    }
}
c002a916:	83 c4 1c             	add    $0x1c,%esp
c002a919:	5b                   	pop    %ebx
c002a91a:	5e                   	pop    %esi
c002a91b:	5f                   	pop    %edi
c002a91c:	5d                   	pop    %ebp
c002a91d:	c3                   	ret    

c002a91e <test_sleep>:
{
c002a91e:	55                   	push   %ebp
c002a91f:	57                   	push   %edi
c002a920:	56                   	push   %esi
c002a921:	53                   	push   %ebx
c002a922:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c002a928:	89 44 24 20          	mov    %eax,0x20(%esp)
c002a92c:	89 54 24 2c          	mov    %edx,0x2c(%esp)
  ASSERT (!thread_mlfqs);
c002a930:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002a937:	74 2c                	je     c002a965 <test_sleep+0x47>
c002a939:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002a940:	c0 
c002a941:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002a948:	c0 
c002a949:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002a950:	c0 
c002a951:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a958:	00 
c002a959:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002a960:	e8 4e e0 ff ff       	call   c00289b3 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002a965:	8b 74 24 2c          	mov    0x2c(%esp),%esi
c002a969:	89 74 24 08          	mov    %esi,0x8(%esp)
c002a96d:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002a971:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a975:	c7 04 24 a4 01 03 c0 	movl   $0xc00301a4,(%esp)
c002a97c:	e8 ec fd ff ff       	call   c002a76d <msg>
  msg ("Thread 0 sleeps 10 ticks each time,");
c002a981:	c7 04 24 d0 01 03 c0 	movl   $0xc00301d0,(%esp)
c002a988:	e8 e0 fd ff ff       	call   c002a76d <msg>
  msg ("thread 1 sleeps 20 ticks each time, and so on.");
c002a98d:	c7 04 24 f4 01 03 c0 	movl   $0xc00301f4,(%esp)
c002a994:	e8 d4 fd ff ff       	call   c002a76d <msg>
  msg ("If successful, product of iteration count and");
c002a999:	c7 04 24 24 02 03 c0 	movl   $0xc0030224,(%esp)
c002a9a0:	e8 c8 fd ff ff       	call   c002a76d <msg>
  msg ("sleep duration will appear in nondescending order.");
c002a9a5:	c7 04 24 54 02 03 c0 	movl   $0xc0030254,(%esp)
c002a9ac:	e8 bc fd ff ff       	call   c002a76d <msg>
  threads = malloc (sizeof *threads * thread_cnt);
c002a9b1:	89 f8                	mov    %edi,%eax
c002a9b3:	c1 e0 04             	shl    $0x4,%eax
c002a9b6:	89 04 24             	mov    %eax,(%esp)
c002a9b9:	e8 b6 90 ff ff       	call   c0023a74 <malloc>
c002a9be:	89 c3                	mov    %eax,%ebx
c002a9c0:	89 44 24 24          	mov    %eax,0x24(%esp)
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002a9c4:	8d 04 f5 00 00 00 00 	lea    0x0(,%esi,8),%eax
c002a9cb:	0f af c7             	imul   %edi,%eax
c002a9ce:	89 04 24             	mov    %eax,(%esp)
c002a9d1:	e8 9e 90 ff ff       	call   c0023a74 <malloc>
c002a9d6:	89 44 24 28          	mov    %eax,0x28(%esp)
  if (threads == NULL || output == NULL)
c002a9da:	85 c0                	test   %eax,%eax
c002a9dc:	74 04                	je     c002a9e2 <test_sleep+0xc4>
c002a9de:	85 db                	test   %ebx,%ebx
c002a9e0:	75 24                	jne    c002aa06 <test_sleep+0xe8>
    PANIC ("couldn't allocate memory for test");
c002a9e2:	c7 44 24 0c 88 02 03 	movl   $0xc0030288,0xc(%esp)
c002a9e9:	c0 
c002a9ea:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002a9f1:	c0 
c002a9f2:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c002a9f9:	00 
c002a9fa:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002aa01:	e8 ad df ff ff       	call   c00289b3 <debug_panic>
  test.start = timer_ticks () + 100;
c002aa06:	e8 39 98 ff ff       	call   c0024244 <timer_ticks>
c002aa0b:	83 c0 64             	add    $0x64,%eax
c002aa0e:	83 d2 00             	adc    $0x0,%edx
c002aa11:	89 44 24 4c          	mov    %eax,0x4c(%esp)
c002aa15:	89 54 24 50          	mov    %edx,0x50(%esp)
  test.iterations = iterations;
c002aa19:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002aa1d:	89 44 24 54          	mov    %eax,0x54(%esp)
  lock_init (&test.output_lock);
c002aa21:	8d 44 24 58          	lea    0x58(%esp),%eax
c002aa25:	89 04 24             	mov    %eax,(%esp)
c002aa28:	e8 e0 83 ff ff       	call   c0022e0d <lock_init>
  test.output_pos = output;
c002aa2d:	8b 44 24 28          	mov    0x28(%esp),%eax
c002aa31:	89 44 24 7c          	mov    %eax,0x7c(%esp)
  ASSERT (output != NULL);
c002aa35:	85 c0                	test   %eax,%eax
c002aa37:	74 1e                	je     c002aa57 <test_sleep+0x139>
c002aa39:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  for (i = 0; i < thread_cnt; i++)
c002aa3d:	be 0a 00 00 00       	mov    $0xa,%esi
c002aa42:	b8 00 00 00 00       	mov    $0x0,%eax
      snprintf (name, sizeof name, "thread %d", i);
c002aa47:	8d 6c 24 3c          	lea    0x3c(%esp),%ebp
  for (i = 0; i < thread_cnt; i++)
c002aa4b:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c002aa50:	7f 31                	jg     c002aa83 <test_sleep+0x165>
c002aa52:	e9 8a 00 00 00       	jmp    c002aae1 <test_sleep+0x1c3>
  ASSERT (output != NULL);
c002aa57:	c7 44 24 10 4a 01 03 	movl   $0xc003014a,0x10(%esp)
c002aa5e:	c0 
c002aa5f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002aa66:	c0 
c002aa67:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002aa6e:	c0 
c002aa6f:	c7 44 24 04 51 00 00 	movl   $0x51,0x4(%esp)
c002aa76:	00 
c002aa77:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002aa7e:	e8 30 df ff ff       	call   c00289b3 <debug_panic>
      t->test = &test;
c002aa83:	8d 4c 24 4c          	lea    0x4c(%esp),%ecx
c002aa87:	89 0b                	mov    %ecx,(%ebx)
      t->id = i;
c002aa89:	89 43 04             	mov    %eax,0x4(%ebx)
      t->duration = (i + 1) * 10;
c002aa8c:	8d 78 01             	lea    0x1(%eax),%edi
c002aa8f:	89 73 08             	mov    %esi,0x8(%ebx)
      t->iterations = 0;
c002aa92:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
      snprintf (name, sizeof name, "thread %d", i);
c002aa99:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002aa9d:	c7 44 24 08 59 01 03 	movl   $0xc0030159,0x8(%esp)
c002aaa4:	c0 
c002aaa5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002aaac:	00 
c002aaad:	89 2c 24             	mov    %ebp,(%esp)
c002aab0:	e8 aa c7 ff ff       	call   c002725f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, t);
c002aab5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002aab9:	c7 44 24 08 a0 a8 02 	movl   $0xc002a8a0,0x8(%esp)
c002aac0:	c0 
c002aac1:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002aac8:	00 
c002aac9:	89 2c 24             	mov    %ebp,(%esp)
c002aacc:	e8 b1 6a ff ff       	call   c0021582 <thread_create>
c002aad1:	83 c3 10             	add    $0x10,%ebx
c002aad4:	83 c6 0a             	add    $0xa,%esi
  for (i = 0; i < thread_cnt; i++)
c002aad7:	3b 7c 24 20          	cmp    0x20(%esp),%edi
c002aadb:	74 04                	je     c002aae1 <test_sleep+0x1c3>
c002aadd:	89 f8                	mov    %edi,%eax
c002aadf:	eb a2                	jmp    c002aa83 <test_sleep+0x165>
  timer_sleep (100 + thread_cnt * iterations * 10 + 100);
c002aae1:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002aae5:	89 f8                	mov    %edi,%eax
c002aae7:	0f af 44 24 2c       	imul   0x2c(%esp),%eax
c002aaec:	8d 04 80             	lea    (%eax,%eax,4),%eax
c002aaef:	8d 84 00 c8 00 00 00 	lea    0xc8(%eax,%eax,1),%eax
c002aaf6:	89 04 24             	mov    %eax,(%esp)
c002aaf9:	89 c1                	mov    %eax,%ecx
c002aafb:	c1 f9 1f             	sar    $0x1f,%ecx
c002aafe:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002ab02:	e8 85 97 ff ff       	call   c002428c <timer_sleep>
  lock_acquire (&test.output_lock);
c002ab07:	8d 44 24 58          	lea    0x58(%esp),%eax
c002ab0b:	89 04 24             	mov    %eax,(%esp)
c002ab0e:	e8 97 83 ff ff       	call   c0022eaa <lock_acquire>
  for (op = output; op < test.output_pos; op++) 
c002ab13:	8b 44 24 28          	mov    0x28(%esp),%eax
c002ab17:	3b 44 24 7c          	cmp    0x7c(%esp),%eax
c002ab1b:	0f 83 bb 00 00 00    	jae    c002abdc <test_sleep+0x2be>
      ASSERT (*op >= 0 && *op < thread_cnt);
c002ab21:	8b 18                	mov    (%eax),%ebx
c002ab23:	85 db                	test   %ebx,%ebx
c002ab25:	78 1b                	js     c002ab42 <test_sleep+0x224>
c002ab27:	39 df                	cmp    %ebx,%edi
c002ab29:	7f 43                	jg     c002ab6e <test_sleep+0x250>
c002ab2b:	90                   	nop
c002ab2c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c002ab30:	eb 10                	jmp    c002ab42 <test_sleep+0x224>
c002ab32:	8b 1f                	mov    (%edi),%ebx
c002ab34:	85 db                	test   %ebx,%ebx
c002ab36:	78 0a                	js     c002ab42 <test_sleep+0x224>
c002ab38:	39 5c 24 20          	cmp    %ebx,0x20(%esp)
c002ab3c:	7e 04                	jle    c002ab42 <test_sleep+0x224>
c002ab3e:	89 f5                	mov    %esi,%ebp
c002ab40:	eb 35                	jmp    c002ab77 <test_sleep+0x259>
c002ab42:	c7 44 24 10 63 01 03 	movl   $0xc0030163,0x10(%esp)
c002ab49:	c0 
c002ab4a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ab51:	c0 
c002ab52:	c7 44 24 08 78 df 02 	movl   $0xc002df78,0x8(%esp)
c002ab59:	c0 
c002ab5a:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
c002ab61:	00 
c002ab62:	c7 04 24 80 01 03 c0 	movl   $0xc0030180,(%esp)
c002ab69:	e8 45 de ff ff       	call   c00289b3 <debug_panic>
  for (op = output; op < test.output_pos; op++) 
c002ab6e:	8b 7c 24 28          	mov    0x28(%esp),%edi
  product = 0;
c002ab72:	bd 00 00 00 00       	mov    $0x0,%ebp
      t = threads + *op;
c002ab77:	c1 e3 04             	shl    $0x4,%ebx
c002ab7a:	03 5c 24 24          	add    0x24(%esp),%ebx
      new_prod = ++t->iterations * t->duration;
c002ab7e:	8b 43 0c             	mov    0xc(%ebx),%eax
c002ab81:	83 c0 01             	add    $0x1,%eax
c002ab84:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ab87:	8b 53 08             	mov    0x8(%ebx),%edx
c002ab8a:	89 c6                	mov    %eax,%esi
c002ab8c:	0f af f2             	imul   %edx,%esi
      msg ("thread %d: duration=%d, iteration=%d, product=%d",
c002ab8f:	89 74 24 10          	mov    %esi,0x10(%esp)
c002ab93:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ab97:	89 54 24 08          	mov    %edx,0x8(%esp)
c002ab9b:	8b 43 04             	mov    0x4(%ebx),%eax
c002ab9e:	89 44 24 04          	mov    %eax,0x4(%esp)
c002aba2:	c7 04 24 ac 02 03 c0 	movl   $0xc00302ac,(%esp)
c002aba9:	e8 bf fb ff ff       	call   c002a76d <msg>
      if (new_prod >= product)
c002abae:	39 ee                	cmp    %ebp,%esi
c002abb0:	7d 1d                	jge    c002abcf <test_sleep+0x2b1>
        fail ("thread %d woke up out of order (%d > %d)!",
c002abb2:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002abb6:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002abba:	8b 43 04             	mov    0x4(%ebx),%eax
c002abbd:	89 44 24 04          	mov    %eax,0x4(%esp)
c002abc1:	c7 04 24 e0 02 03 c0 	movl   $0xc00302e0,(%esp)
c002abc8:	e8 58 fc ff ff       	call   c002a825 <fail>
c002abcd:	89 ee                	mov    %ebp,%esi
  for (op = output; op < test.output_pos; op++) 
c002abcf:	83 c7 04             	add    $0x4,%edi
c002abd2:	39 7c 24 7c          	cmp    %edi,0x7c(%esp)
c002abd6:	0f 87 56 ff ff ff    	ja     c002ab32 <test_sleep+0x214>
  for (i = 0; i < thread_cnt; i++)
c002abdc:	8b 6c 24 20          	mov    0x20(%esp),%ebp
c002abe0:	85 ed                	test   %ebp,%ebp
c002abe2:	7e 36                	jle    c002ac1a <test_sleep+0x2fc>
c002abe4:	8b 74 24 24          	mov    0x24(%esp),%esi
c002abe8:	bb 00 00 00 00       	mov    $0x0,%ebx
c002abed:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
    if (threads[i].iterations != iterations)
c002abf1:	8b 46 0c             	mov    0xc(%esi),%eax
c002abf4:	39 f8                	cmp    %edi,%eax
c002abf6:	74 18                	je     c002ac10 <test_sleep+0x2f2>
      fail ("thread %d woke up %d times instead of %d",
c002abf8:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002abfc:	89 44 24 08          	mov    %eax,0x8(%esp)
c002ac00:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002ac04:	c7 04 24 0c 03 03 c0 	movl   $0xc003030c,(%esp)
c002ac0b:	e8 15 fc ff ff       	call   c002a825 <fail>
  for (i = 0; i < thread_cnt; i++)
c002ac10:	83 c3 01             	add    $0x1,%ebx
c002ac13:	83 c6 10             	add    $0x10,%esi
c002ac16:	39 eb                	cmp    %ebp,%ebx
c002ac18:	75 d7                	jne    c002abf1 <test_sleep+0x2d3>
  lock_release (&test.output_lock);
c002ac1a:	8d 44 24 58          	lea    0x58(%esp),%eax
c002ac1e:	89 04 24             	mov    %eax,(%esp)
c002ac21:	e8 4e 84 ff ff       	call   c0023074 <lock_release>
  free (output);
c002ac26:	8b 44 24 28          	mov    0x28(%esp),%eax
c002ac2a:	89 04 24             	mov    %eax,(%esp)
c002ac2d:	e8 c9 8f ff ff       	call   c0023bfb <free>
  free (threads);
c002ac32:	8b 44 24 24          	mov    0x24(%esp),%eax
c002ac36:	89 04 24             	mov    %eax,(%esp)
c002ac39:	e8 bd 8f ff ff       	call   c0023bfb <free>
}
c002ac3e:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c002ac44:	5b                   	pop    %ebx
c002ac45:	5e                   	pop    %esi
c002ac46:	5f                   	pop    %edi
c002ac47:	5d                   	pop    %ebp
c002ac48:	c3                   	ret    

c002ac49 <test_alarm_single>:
{
c002ac49:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 1);
c002ac4c:	ba 01 00 00 00       	mov    $0x1,%edx
c002ac51:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac56:	e8 c3 fc ff ff       	call   c002a91e <test_sleep>
}
c002ac5b:	83 c4 0c             	add    $0xc,%esp
c002ac5e:	c3                   	ret    

c002ac5f <test_alarm_multiple>:
{
c002ac5f:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 7);
c002ac62:	ba 07 00 00 00       	mov    $0x7,%edx
c002ac67:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac6c:	e8 ad fc ff ff       	call   c002a91e <test_sleep>
}
c002ac71:	83 c4 0c             	add    $0xc,%esp
c002ac74:	c3                   	ret    

c002ac75 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *test_) 
{
c002ac75:	55                   	push   %ebp
c002ac76:	57                   	push   %edi
c002ac77:	56                   	push   %esi
c002ac78:	53                   	push   %ebx
c002ac79:	83 ec 1c             	sub    $0x1c,%esp
c002ac7c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  struct sleep_test *test = test_;
  int i;

  /* Make sure we're at the beginning of a timer tick. */
  timer_sleep (1);
c002ac80:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c002ac87:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ac8e:	00 
c002ac8f:	e8 f8 95 ff ff       	call   c002428c <timer_sleep>

  for (i = 1; i <= test->iterations; i++) 
c002ac94:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002ac98:	7e 56                	jle    c002acf0 <sleeper+0x7b>
c002ac9a:	bd 0a 00 00 00       	mov    $0xa,%ebp
c002ac9f:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c002aca6:	00 
    {
      int64_t sleep_until = test->start + i * 10;
c002aca7:	89 ee                	mov    %ebp,%esi
c002aca9:	89 ef                	mov    %ebp,%edi
c002acab:	c1 ff 1f             	sar    $0x1f,%edi
c002acae:	03 33                	add    (%ebx),%esi
c002acb0:	13 7b 04             	adc    0x4(%ebx),%edi
      timer_sleep (sleep_until - timer_ticks ());
c002acb3:	e8 8c 95 ff ff       	call   c0024244 <timer_ticks>
c002acb8:	29 c6                	sub    %eax,%esi
c002acba:	19 d7                	sbb    %edx,%edi
c002acbc:	89 34 24             	mov    %esi,(%esp)
c002acbf:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002acc3:	e8 c4 95 ff ff       	call   c002428c <timer_sleep>
      *test->output_pos++ = timer_ticks () - test->start;
c002acc8:	8b 73 0c             	mov    0xc(%ebx),%esi
c002accb:	8d 46 04             	lea    0x4(%esi),%eax
c002acce:	89 43 0c             	mov    %eax,0xc(%ebx)
c002acd1:	e8 6e 95 ff ff       	call   c0024244 <timer_ticks>
c002acd6:	2b 03                	sub    (%ebx),%eax
c002acd8:	89 06                	mov    %eax,(%esi)
      thread_yield ();
c002acda:	e8 01 68 ff ff       	call   c00214e0 <thread_yield>
  for (i = 1; i <= test->iterations; i++) 
c002acdf:	83 44 24 0c 01       	addl   $0x1,0xc(%esp)
c002ace4:	83 c5 0a             	add    $0xa,%ebp
c002ace7:	8b 44 24 0c          	mov    0xc(%esp),%eax
c002aceb:	39 43 08             	cmp    %eax,0x8(%ebx)
c002acee:	7d b7                	jge    c002aca7 <sleeper+0x32>
    }
}
c002acf0:	83 c4 1c             	add    $0x1c,%esp
c002acf3:	5b                   	pop    %ebx
c002acf4:	5e                   	pop    %esi
c002acf5:	5f                   	pop    %edi
c002acf6:	5d                   	pop    %ebp
c002acf7:	c3                   	ret    

c002acf8 <test_alarm_simultaneous>:
{
c002acf8:	55                   	push   %ebp
c002acf9:	57                   	push   %edi
c002acfa:	56                   	push   %esi
c002acfb:	53                   	push   %ebx
c002acfc:	83 ec 4c             	sub    $0x4c,%esp
  ASSERT (!thread_mlfqs);
c002acff:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002ad06:	74 2c                	je     c002ad34 <test_alarm_simultaneous+0x3c>
c002ad08:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002ad0f:	c0 
c002ad10:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ad17:	c0 
c002ad18:	c7 44 24 08 83 df 02 	movl   $0xc002df83,0x8(%esp)
c002ad1f:	c0 
c002ad20:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002ad27:	00 
c002ad28:	c7 04 24 38 03 03 c0 	movl   $0xc0030338,(%esp)
c002ad2f:	e8 7f dc ff ff       	call   c00289b3 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002ad34:	c7 44 24 08 05 00 00 	movl   $0x5,0x8(%esp)
c002ad3b:	00 
c002ad3c:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c002ad43:	00 
c002ad44:	c7 04 24 a4 01 03 c0 	movl   $0xc00301a4,(%esp)
c002ad4b:	e8 1d fa ff ff       	call   c002a76d <msg>
  msg ("Each thread sleeps 10 ticks each time.");
c002ad50:	c7 04 24 64 03 03 c0 	movl   $0xc0030364,(%esp)
c002ad57:	e8 11 fa ff ff       	call   c002a76d <msg>
  msg ("Within an iteration, all threads should wake up on the same tick.");
c002ad5c:	c7 04 24 8c 03 03 c0 	movl   $0xc003038c,(%esp)
c002ad63:	e8 05 fa ff ff       	call   c002a76d <msg>
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002ad68:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
c002ad6f:	e8 00 8d ff ff       	call   c0023a74 <malloc>
c002ad74:	89 c3                	mov    %eax,%ebx
  if (output == NULL)
c002ad76:	85 c0                	test   %eax,%eax
c002ad78:	75 24                	jne    c002ad9e <test_alarm_simultaneous+0xa6>
    PANIC ("couldn't allocate memory for test");
c002ad7a:	c7 44 24 0c 88 02 03 	movl   $0xc0030288,0xc(%esp)
c002ad81:	c0 
c002ad82:	c7 44 24 08 83 df 02 	movl   $0xc002df83,0x8(%esp)
c002ad89:	c0 
c002ad8a:	c7 44 24 04 31 00 00 	movl   $0x31,0x4(%esp)
c002ad91:	00 
c002ad92:	c7 04 24 38 03 03 c0 	movl   $0xc0030338,(%esp)
c002ad99:	e8 15 dc ff ff       	call   c00289b3 <debug_panic>
  test.start = timer_ticks () + 100;
c002ad9e:	e8 a1 94 ff ff       	call   c0024244 <timer_ticks>
c002ada3:	83 c0 64             	add    $0x64,%eax
c002ada6:	83 d2 00             	adc    $0x0,%edx
c002ada9:	89 44 24 20          	mov    %eax,0x20(%esp)
c002adad:	89 54 24 24          	mov    %edx,0x24(%esp)
  test.iterations = iterations;
c002adb1:	c7 44 24 28 05 00 00 	movl   $0x5,0x28(%esp)
c002adb8:	00 
  test.output_pos = output;
c002adb9:	89 5c 24 2c          	mov    %ebx,0x2c(%esp)
c002adbd:	be 00 00 00 00       	mov    $0x0,%esi
      snprintf (name, sizeof name, "thread %d", i);
c002adc2:	8d 7c 24 30          	lea    0x30(%esp),%edi
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002adc6:	8d 6c 24 20          	lea    0x20(%esp),%ebp
      snprintf (name, sizeof name, "thread %d", i);
c002adca:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002adce:	c7 44 24 08 59 01 03 	movl   $0xc0030159,0x8(%esp)
c002add5:	c0 
c002add6:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002addd:	00 
c002adde:	89 3c 24             	mov    %edi,(%esp)
c002ade1:	e8 79 c4 ff ff       	call   c002725f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002ade6:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c002adea:	c7 44 24 08 75 ac 02 	movl   $0xc002ac75,0x8(%esp)
c002adf1:	c0 
c002adf2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002adf9:	00 
c002adfa:	89 3c 24             	mov    %edi,(%esp)
c002adfd:	e8 80 67 ff ff       	call   c0021582 <thread_create>
  for (i = 0; i < thread_cnt; i++)
c002ae02:	83 c6 01             	add    $0x1,%esi
c002ae05:	83 fe 03             	cmp    $0x3,%esi
c002ae08:	75 c0                	jne    c002adca <test_alarm_simultaneous+0xd2>
  timer_sleep (100 + iterations * 10 + 100);
c002ae0a:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002ae11:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ae18:	00 
c002ae19:	e8 6e 94 ff ff       	call   c002428c <timer_sleep>
  msg ("iteration 0, thread 0: woke up after %d ticks", output[0]);
c002ae1e:	8b 03                	mov    (%ebx),%eax
c002ae20:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ae24:	c7 04 24 d0 03 03 c0 	movl   $0xc00303d0,(%esp)
c002ae2b:	e8 3d f9 ff ff       	call   c002a76d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae30:	89 df                	mov    %ebx,%edi
c002ae32:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae36:	29 d8                	sub    %ebx,%eax
c002ae38:	83 f8 07             	cmp    $0x7,%eax
c002ae3b:	7e 4a                	jle    c002ae87 <test_alarm_simultaneous+0x18f>
c002ae3d:	66 be 01 00          	mov    $0x1,%si
    msg ("iteration %d, thread %d: woke up %d ticks later",
c002ae41:	bd 56 55 55 55       	mov    $0x55555556,%ebp
c002ae46:	8b 04 b3             	mov    (%ebx,%esi,4),%eax
c002ae49:	2b 44 b3 fc          	sub    -0x4(%ebx,%esi,4),%eax
c002ae4d:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ae51:	89 f0                	mov    %esi,%eax
c002ae53:	f7 ed                	imul   %ebp
c002ae55:	89 f0                	mov    %esi,%eax
c002ae57:	c1 f8 1f             	sar    $0x1f,%eax
c002ae5a:	29 c2                	sub    %eax,%edx
c002ae5c:	8d 04 52             	lea    (%edx,%edx,2),%eax
c002ae5f:	89 f1                	mov    %esi,%ecx
c002ae61:	29 c1                	sub    %eax,%ecx
c002ae63:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002ae67:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ae6b:	c7 04 24 00 04 03 c0 	movl   $0xc0030400,(%esp)
c002ae72:	e8 f6 f8 ff ff       	call   c002a76d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae77:	83 c6 01             	add    $0x1,%esi
c002ae7a:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae7e:	29 f8                	sub    %edi,%eax
c002ae80:	c1 f8 02             	sar    $0x2,%eax
c002ae83:	39 c6                	cmp    %eax,%esi
c002ae85:	7c bf                	jl     c002ae46 <test_alarm_simultaneous+0x14e>
  free (output);
c002ae87:	89 1c 24             	mov    %ebx,(%esp)
c002ae8a:	e8 6c 8d ff ff       	call   c0023bfb <free>
}
c002ae8f:	83 c4 4c             	add    $0x4c,%esp
c002ae92:	5b                   	pop    %ebx
c002ae93:	5e                   	pop    %esi
c002ae94:	5f                   	pop    %edi
c002ae95:	5d                   	pop    %ebp
c002ae96:	c3                   	ret    

c002ae97 <alarm_priority_thread>:
    sema_down (&wait_sema);
}

static void
alarm_priority_thread (void *aux UNUSED) 
{
c002ae97:	57                   	push   %edi
c002ae98:	56                   	push   %esi
c002ae99:	83 ec 14             	sub    $0x14,%esp
  /* Busy-wait until the current time changes. */
  int64_t start_time = timer_ticks ();
c002ae9c:	e8 a3 93 ff ff       	call   c0024244 <timer_ticks>
c002aea1:	89 c6                	mov    %eax,%esi
c002aea3:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) == 0)
c002aea5:	89 34 24             	mov    %esi,(%esp)
c002aea8:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002aeac:	e8 bf 93 ff ff       	call   c0024270 <timer_elapsed>
c002aeb1:	09 c2                	or     %eax,%edx
c002aeb3:	74 f0                	je     c002aea5 <alarm_priority_thread+0xe>
    continue;

  /* Now we know we're at the very beginning of a timer tick, so
     we can call timer_sleep() without worrying about races
     between checking the time and a timer interrupt. */
  timer_sleep (wake_time - timer_ticks ());
c002aeb5:	8b 35 40 7b 03 c0    	mov    0xc0037b40,%esi
c002aebb:	8b 3d 44 7b 03 c0    	mov    0xc0037b44,%edi
c002aec1:	e8 7e 93 ff ff       	call   c0024244 <timer_ticks>
c002aec6:	29 c6                	sub    %eax,%esi
c002aec8:	19 d7                	sbb    %edx,%edi
c002aeca:	89 34 24             	mov    %esi,(%esp)
c002aecd:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002aed1:	e8 b6 93 ff ff       	call   c002428c <timer_sleep>

  /* Print a message on wake-up. */
  msg ("Thread %s woke up.", thread_name ());
c002aed6:	e8 15 60 ff ff       	call   c0020ef0 <thread_name>
c002aedb:	89 44 24 04          	mov    %eax,0x4(%esp)
c002aedf:	c7 04 24 30 04 03 c0 	movl   $0xc0030430,(%esp)
c002aee6:	e8 82 f8 ff ff       	call   c002a76d <msg>

  sema_up (&wait_sema);
c002aeeb:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002aef2:	e8 a0 7d ff ff       	call   c0022c97 <sema_up>
}
c002aef7:	83 c4 14             	add    $0x14,%esp
c002aefa:	5e                   	pop    %esi
c002aefb:	5f                   	pop    %edi
c002aefc:	c3                   	ret    

c002aefd <test_alarm_priority>:
{
c002aefd:	55                   	push   %ebp
c002aefe:	57                   	push   %edi
c002aeff:	56                   	push   %esi
c002af00:	53                   	push   %ebx
c002af01:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002af04:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002af0b:	74 2c                	je     c002af39 <test_alarm_priority+0x3c>
c002af0d:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002af14:	c0 
c002af15:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002af1c:	c0 
c002af1d:	c7 44 24 08 8e df 02 	movl   $0xc002df8e,0x8(%esp)
c002af24:	c0 
c002af25:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002af2c:	00 
c002af2d:	c7 04 24 50 04 03 c0 	movl   $0xc0030450,(%esp)
c002af34:	e8 7a da ff ff       	call   c00289b3 <debug_panic>
  wake_time = timer_ticks () + 5 * TIMER_FREQ;
c002af39:	e8 06 93 ff ff       	call   c0024244 <timer_ticks>
c002af3e:	05 f4 01 00 00       	add    $0x1f4,%eax
c002af43:	83 d2 00             	adc    $0x0,%edx
c002af46:	a3 40 7b 03 c0       	mov    %eax,0xc0037b40
c002af4b:	89 15 44 7b 03 c0    	mov    %edx,0xc0037b44
  sema_init (&wait_sema, 0);
c002af51:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002af58:	00 
c002af59:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002af60:	e8 d1 7b ff ff       	call   c0022b36 <sema_init>
c002af65:	bb 05 00 00 00       	mov    $0x5,%ebx
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af6a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002af6f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af73:	89 d8                	mov    %ebx,%eax
c002af75:	f7 ed                	imul   %ebp
c002af77:	c1 fa 02             	sar    $0x2,%edx
c002af7a:	89 d8                	mov    %ebx,%eax
c002af7c:	c1 f8 1f             	sar    $0x1f,%eax
c002af7f:	29 c2                	sub    %eax,%edx
c002af81:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002af84:	01 c0                	add    %eax,%eax
c002af86:	29 d8                	sub    %ebx,%eax
c002af88:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002af8b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002af8f:	c7 44 24 08 43 04 03 	movl   $0xc0030443,0x8(%esp)
c002af96:	c0 
c002af97:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002af9e:	00 
c002af9f:	89 3c 24             	mov    %edi,(%esp)
c002afa2:	e8 b8 c2 ff ff       	call   c002725f <snprintf>
      thread_create (name, priority, alarm_priority_thread, NULL);
c002afa7:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002afae:	00 
c002afaf:	c7 44 24 08 97 ae 02 	movl   $0xc002ae97,0x8(%esp)
c002afb6:	c0 
c002afb7:	89 74 24 04          	mov    %esi,0x4(%esp)
c002afbb:	89 3c 24             	mov    %edi,(%esp)
c002afbe:	e8 bf 65 ff ff       	call   c0021582 <thread_create>
c002afc3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002afc6:	83 fb 0f             	cmp    $0xf,%ebx
c002afc9:	75 a8                	jne    c002af73 <test_alarm_priority+0x76>
  thread_set_priority (PRI_MIN);
c002afcb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002afd2:	e8 19 67 ff ff       	call   c00216f0 <thread_set_priority>
c002afd7:	b3 0a                	mov    $0xa,%bl
    sema_down (&wait_sema);
c002afd9:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002afe0:	e8 9d 7b ff ff       	call   c0022b82 <sema_down>
  for (i = 0; i < 10; i++)
c002afe5:	83 eb 01             	sub    $0x1,%ebx
c002afe8:	75 ef                	jne    c002afd9 <test_alarm_priority+0xdc>
}
c002afea:	83 c4 3c             	add    $0x3c,%esp
c002afed:	5b                   	pop    %ebx
c002afee:	5e                   	pop    %esi
c002afef:	5f                   	pop    %edi
c002aff0:	5d                   	pop    %ebp
c002aff1:	c3                   	ret    

c002aff2 <test_alarm_zero>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_zero (void) 
{
c002aff2:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (0);
c002aff5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002affc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002b003:	00 
c002b004:	e8 83 92 ff ff       	call   c002428c <timer_sleep>
  pass ();
c002b009:	e8 73 f8 ff ff       	call   c002a881 <pass>
}
c002b00e:	83 c4 1c             	add    $0x1c,%esp
c002b011:	c3                   	ret    

c002b012 <test_alarm_negative>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_negative (void) 
{
c002b012:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (-100);
c002b015:	c7 04 24 9c ff ff ff 	movl   $0xffffff9c,(%esp)
c002b01c:	c7 44 24 04 ff ff ff 	movl   $0xffffffff,0x4(%esp)
c002b023:	ff 
c002b024:	e8 63 92 ff ff       	call   c002428c <timer_sleep>
  pass ();
c002b029:	e8 53 f8 ff ff       	call   c002a881 <pass>
}
c002b02e:	83 c4 1c             	add    $0x1c,%esp
c002b031:	c3                   	ret    

c002b032 <changing_thread>:
  msg ("Thread 2 should have just exited.");
}

static void
changing_thread (void *aux UNUSED) 
{
c002b032:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread 2 now lowering priority.");
c002b035:	c7 04 24 78 04 03 c0 	movl   $0xc0030478,(%esp)
c002b03c:	e8 2c f7 ff ff       	call   c002a76d <msg>
  thread_set_priority (PRI_DEFAULT - 1);
c002b041:	c7 04 24 1e 00 00 00 	movl   $0x1e,(%esp)
c002b048:	e8 a3 66 ff ff       	call   c00216f0 <thread_set_priority>
  msg ("Thread 2 exiting.");
c002b04d:	c7 04 24 36 05 03 c0 	movl   $0xc0030536,(%esp)
c002b054:	e8 14 f7 ff ff       	call   c002a76d <msg>
}
c002b059:	83 c4 1c             	add    $0x1c,%esp
c002b05c:	c3                   	ret    

c002b05d <test_priority_change>:
{
c002b05d:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002b060:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b067:	74 2c                	je     c002b095 <test_priority_change+0x38>
c002b069:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b070:	c0 
c002b071:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b078:	c0 
c002b079:	c7 44 24 08 a2 df 02 	movl   $0xc002dfa2,0x8(%esp)
c002b080:	c0 
c002b081:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002b088:	00 
c002b089:	c7 04 24 98 04 03 c0 	movl   $0xc0030498,(%esp)
c002b090:	e8 1e d9 ff ff       	call   c00289b3 <debug_panic>
  msg ("Creating a high-priority thread 2.");
c002b095:	c7 04 24 c0 04 03 c0 	movl   $0xc00304c0,(%esp)
c002b09c:	e8 cc f6 ff ff       	call   c002a76d <msg>
  thread_create ("thread 2", PRI_DEFAULT + 1, changing_thread, NULL);
c002b0a1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b0a8:	00 
c002b0a9:	c7 44 24 08 32 b0 02 	movl   $0xc002b032,0x8(%esp)
c002b0b0:	c0 
c002b0b1:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b0b8:	00 
c002b0b9:	c7 04 24 48 05 03 c0 	movl   $0xc0030548,(%esp)
c002b0c0:	e8 bd 64 ff ff       	call   c0021582 <thread_create>
  msg ("Thread 2 should have just lowered its priority.");
c002b0c5:	c7 04 24 e4 04 03 c0 	movl   $0xc00304e4,(%esp)
c002b0cc:	e8 9c f6 ff ff       	call   c002a76d <msg>
  thread_set_priority (PRI_DEFAULT - 2);
c002b0d1:	c7 04 24 1d 00 00 00 	movl   $0x1d,(%esp)
c002b0d8:	e8 13 66 ff ff       	call   c00216f0 <thread_set_priority>
  msg ("Thread 2 should have just exited.");
c002b0dd:	c7 04 24 14 05 03 c0 	movl   $0xc0030514,(%esp)
c002b0e4:	e8 84 f6 ff ff       	call   c002a76d <msg>
}
c002b0e9:	83 c4 2c             	add    $0x2c,%esp
c002b0ec:	c3                   	ret    

c002b0ed <acquire2_thread_func>:
  msg ("acquire1: done");
}

static void
acquire2_thread_func (void *lock_) 
{
c002b0ed:	53                   	push   %ebx
c002b0ee:	83 ec 18             	sub    $0x18,%esp
c002b0f1:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b0f5:	89 1c 24             	mov    %ebx,(%esp)
c002b0f8:	e8 ad 7d ff ff       	call   c0022eaa <lock_acquire>
  msg ("acquire2: got the lock");
c002b0fd:	c7 04 24 51 05 03 c0 	movl   $0xc0030551,(%esp)
c002b104:	e8 64 f6 ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002b109:	89 1c 24             	mov    %ebx,(%esp)
c002b10c:	e8 63 7f ff ff       	call   c0023074 <lock_release>
  msg ("acquire2: done");
c002b111:	c7 04 24 68 05 03 c0 	movl   $0xc0030568,(%esp)
c002b118:	e8 50 f6 ff ff       	call   c002a76d <msg>
}
c002b11d:	83 c4 18             	add    $0x18,%esp
c002b120:	5b                   	pop    %ebx
c002b121:	c3                   	ret    

c002b122 <acquire1_thread_func>:
{
c002b122:	53                   	push   %ebx
c002b123:	83 ec 18             	sub    $0x18,%esp
c002b126:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b12a:	89 1c 24             	mov    %ebx,(%esp)
c002b12d:	e8 78 7d ff ff       	call   c0022eaa <lock_acquire>
  msg ("acquire1: got the lock");
c002b132:	c7 04 24 77 05 03 c0 	movl   $0xc0030577,(%esp)
c002b139:	e8 2f f6 ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002b13e:	89 1c 24             	mov    %ebx,(%esp)
c002b141:	e8 2e 7f ff ff       	call   c0023074 <lock_release>
  msg ("acquire1: done");
c002b146:	c7 04 24 8e 05 03 c0 	movl   $0xc003058e,(%esp)
c002b14d:	e8 1b f6 ff ff       	call   c002a76d <msg>
}
c002b152:	83 c4 18             	add    $0x18,%esp
c002b155:	5b                   	pop    %ebx
c002b156:	c3                   	ret    

c002b157 <test_priority_donate_one>:
{
c002b157:	53                   	push   %ebx
c002b158:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002b15b:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b162:	74 2c                	je     c002b190 <test_priority_donate_one+0x39>
c002b164:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b16b:	c0 
c002b16c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b173:	c0 
c002b174:	c7 44 24 08 b7 df 02 	movl   $0xc002dfb7,0x8(%esp)
c002b17b:	c0 
c002b17c:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b183:	00 
c002b184:	c7 04 24 b0 05 03 c0 	movl   $0xc00305b0,(%esp)
c002b18b:	e8 23 d8 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b190:	e8 f8 5d ff ff       	call   c0020f8d <thread_get_priority>
c002b195:	83 f8 1f             	cmp    $0x1f,%eax
c002b198:	74 2c                	je     c002b1c6 <test_priority_donate_one+0x6f>
c002b19a:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b1a1:	c0 
c002b1a2:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b1a9:	c0 
c002b1aa:	c7 44 24 08 b7 df 02 	movl   $0xc002dfb7,0x8(%esp)
c002b1b1:	c0 
c002b1b2:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b1b9:	00 
c002b1ba:	c7 04 24 b0 05 03 c0 	movl   $0xc00305b0,(%esp)
c002b1c1:	e8 ed d7 ff ff       	call   c00289b3 <debug_panic>
  lock_init (&lock);
c002b1c6:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002b1ca:	89 1c 24             	mov    %ebx,(%esp)
c002b1cd:	e8 3b 7c ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&lock);
c002b1d2:	89 1c 24             	mov    %ebx,(%esp)
c002b1d5:	e8 d0 7c ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("acquire1", PRI_DEFAULT + 1, acquire1_thread_func, &lock);
c002b1da:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b1de:	c7 44 24 08 22 b1 02 	movl   $0xc002b122,0x8(%esp)
c002b1e5:	c0 
c002b1e6:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b1ed:	00 
c002b1ee:	c7 04 24 9d 05 03 c0 	movl   $0xc003059d,(%esp)
c002b1f5:	e8 88 63 ff ff       	call   c0021582 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b1fa:	e8 8e 5d ff ff       	call   c0020f8d <thread_get_priority>
c002b1ff:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b203:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b20a:	00 
c002b20b:	c7 04 24 04 06 03 c0 	movl   $0xc0030604,(%esp)
c002b212:	e8 56 f5 ff ff       	call   c002a76d <msg>
  thread_create ("acquire2", PRI_DEFAULT + 2, acquire2_thread_func, &lock);
c002b217:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b21b:	c7 44 24 08 ed b0 02 	movl   $0xc002b0ed,0x8(%esp)
c002b222:	c0 
c002b223:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b22a:	00 
c002b22b:	c7 04 24 a6 05 03 c0 	movl   $0xc00305a6,(%esp)
c002b232:	e8 4b 63 ff ff       	call   c0021582 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b237:	e8 51 5d ff ff       	call   c0020f8d <thread_get_priority>
c002b23c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b240:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b247:	00 
c002b248:	c7 04 24 04 06 03 c0 	movl   $0xc0030604,(%esp)
c002b24f:	e8 19 f5 ff ff       	call   c002a76d <msg>
  lock_release (&lock);
c002b254:	89 1c 24             	mov    %ebx,(%esp)
c002b257:	e8 18 7e ff ff       	call   c0023074 <lock_release>
  msg ("acquire2, acquire1 must already have finished, in that order.");
c002b25c:	c7 04 24 40 06 03 c0 	movl   $0xc0030640,(%esp)
c002b263:	e8 05 f5 ff ff       	call   c002a76d <msg>
  msg ("This should be the last line before finishing this test.");
c002b268:	c7 04 24 80 06 03 c0 	movl   $0xc0030680,(%esp)
c002b26f:	e8 f9 f4 ff ff       	call   c002a76d <msg>
}
c002b274:	83 c4 58             	add    $0x58,%esp
c002b277:	5b                   	pop    %ebx
c002b278:	c3                   	ret    

c002b279 <b_thread_func>:
  msg ("Thread a finished.");
}

static void
b_thread_func (void *lock_) 
{
c002b279:	53                   	push   %ebx
c002b27a:	83 ec 18             	sub    $0x18,%esp
c002b27d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b281:	89 1c 24             	mov    %ebx,(%esp)
c002b284:	e8 21 7c ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b289:	c7 04 24 b9 06 03 c0 	movl   $0xc00306b9,(%esp)
c002b290:	e8 d8 f4 ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002b295:	89 1c 24             	mov    %ebx,(%esp)
c002b298:	e8 d7 7d ff ff       	call   c0023074 <lock_release>
  msg ("Thread b finished.");
c002b29d:	c7 04 24 d3 06 03 c0 	movl   $0xc00306d3,(%esp)
c002b2a4:	e8 c4 f4 ff ff       	call   c002a76d <msg>
}
c002b2a9:	83 c4 18             	add    $0x18,%esp
c002b2ac:	5b                   	pop    %ebx
c002b2ad:	c3                   	ret    

c002b2ae <a_thread_func>:
{
c002b2ae:	53                   	push   %ebx
c002b2af:	83 ec 18             	sub    $0x18,%esp
c002b2b2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b2b6:	89 1c 24             	mov    %ebx,(%esp)
c002b2b9:	e8 ec 7b ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b2be:	c7 04 24 e6 06 03 c0 	movl   $0xc00306e6,(%esp)
c002b2c5:	e8 a3 f4 ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002b2ca:	89 1c 24             	mov    %ebx,(%esp)
c002b2cd:	e8 a2 7d ff ff       	call   c0023074 <lock_release>
  msg ("Thread a finished.");
c002b2d2:	c7 04 24 00 07 03 c0 	movl   $0xc0030700,(%esp)
c002b2d9:	e8 8f f4 ff ff       	call   c002a76d <msg>
}
c002b2de:	83 c4 18             	add    $0x18,%esp
c002b2e1:	5b                   	pop    %ebx
c002b2e2:	c3                   	ret    

c002b2e3 <test_priority_donate_multiple>:
{
c002b2e3:	56                   	push   %esi
c002b2e4:	53                   	push   %ebx
c002b2e5:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b2e8:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b2ef:	74 2c                	je     c002b31d <test_priority_donate_multiple+0x3a>
c002b2f1:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b2f8:	c0 
c002b2f9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b300:	c0 
c002b301:	c7 44 24 08 d0 df 02 	movl   $0xc002dfd0,0x8(%esp)
c002b308:	c0 
c002b309:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b310:	00 
c002b311:	c7 04 24 14 07 03 c0 	movl   $0xc0030714,(%esp)
c002b318:	e8 96 d6 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b31d:	e8 6b 5c ff ff       	call   c0020f8d <thread_get_priority>
c002b322:	83 f8 1f             	cmp    $0x1f,%eax
c002b325:	74 2c                	je     c002b353 <test_priority_donate_multiple+0x70>
c002b327:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b32e:	c0 
c002b32f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b336:	c0 
c002b337:	c7 44 24 08 d0 df 02 	movl   $0xc002dfd0,0x8(%esp)
c002b33e:	c0 
c002b33f:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b346:	00 
c002b347:	c7 04 24 14 07 03 c0 	movl   $0xc0030714,(%esp)
c002b34e:	e8 60 d6 ff ff       	call   c00289b3 <debug_panic>
  lock_init (&a);
c002b353:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b357:	89 1c 24             	mov    %ebx,(%esp)
c002b35a:	e8 ae 7a ff ff       	call   c0022e0d <lock_init>
  lock_init (&b);
c002b35f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b363:	89 34 24             	mov    %esi,(%esp)
c002b366:	e8 a2 7a ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&a);
c002b36b:	89 1c 24             	mov    %ebx,(%esp)
c002b36e:	e8 37 7b ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (&b);
c002b373:	89 34 24             	mov    %esi,(%esp)
c002b376:	e8 2f 7b ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 1, a_thread_func, &a);
c002b37b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b37f:	c7 44 24 08 ae b2 02 	movl   $0xc002b2ae,0x8(%esp)
c002b386:	c0 
c002b387:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b38e:	00 
c002b38f:	c7 04 24 b3 f2 02 c0 	movl   $0xc002f2b3,(%esp)
c002b396:	e8 e7 61 ff ff       	call   c0021582 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b39b:	e8 ed 5b ff ff       	call   c0020f8d <thread_get_priority>
c002b3a0:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3a4:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b3ab:	00 
c002b3ac:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b3b3:	e8 b5 f3 ff ff       	call   c002a76d <msg>
  thread_create ("b", PRI_DEFAULT + 2, b_thread_func, &b);
c002b3b8:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b3bc:	c7 44 24 08 79 b2 02 	movl   $0xc002b279,0x8(%esp)
c002b3c3:	c0 
c002b3c4:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b3cb:	00 
c002b3cc:	c7 04 24 7d fc 02 c0 	movl   $0xc002fc7d,(%esp)
c002b3d3:	e8 aa 61 ff ff       	call   c0021582 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3d8:	e8 b0 5b ff ff       	call   c0020f8d <thread_get_priority>
c002b3dd:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3e1:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b3e8:	00 
c002b3e9:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b3f0:	e8 78 f3 ff ff       	call   c002a76d <msg>
  lock_release (&b);
c002b3f5:	89 34 24             	mov    %esi,(%esp)
c002b3f8:	e8 77 7c ff ff       	call   c0023074 <lock_release>
  msg ("Thread b should have just finished.");
c002b3fd:	c7 04 24 80 07 03 c0 	movl   $0xc0030780,(%esp)
c002b404:	e8 64 f3 ff ff       	call   c002a76d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b409:	e8 7f 5b ff ff       	call   c0020f8d <thread_get_priority>
c002b40e:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b412:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b419:	00 
c002b41a:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b421:	e8 47 f3 ff ff       	call   c002a76d <msg>
  lock_release (&a);
c002b426:	89 1c 24             	mov    %ebx,(%esp)
c002b429:	e8 46 7c ff ff       	call   c0023074 <lock_release>
  msg ("Thread a should have just finished.");
c002b42e:	c7 04 24 a4 07 03 c0 	movl   $0xc00307a4,(%esp)
c002b435:	e8 33 f3 ff ff       	call   c002a76d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b43a:	e8 4e 5b ff ff       	call   c0020f8d <thread_get_priority>
c002b43f:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b443:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b44a:	00 
c002b44b:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b452:	e8 16 f3 ff ff       	call   c002a76d <msg>
}
c002b457:	83 c4 74             	add    $0x74,%esp
c002b45a:	5b                   	pop    %ebx
c002b45b:	5e                   	pop    %esi
c002b45c:	c3                   	ret    

c002b45d <c_thread_func>:
  msg ("Thread b finished.");
}

static void
c_thread_func (void *a_ UNUSED) 
{
c002b45d:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread c finished.");
c002b460:	c7 04 24 c8 07 03 c0 	movl   $0xc00307c8,(%esp)
c002b467:	e8 01 f3 ff ff       	call   c002a76d <msg>
}
c002b46c:	83 c4 1c             	add    $0x1c,%esp
c002b46f:	c3                   	ret    

c002b470 <b_thread_func>:
{
c002b470:	53                   	push   %ebx
c002b471:	83 ec 18             	sub    $0x18,%esp
c002b474:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b478:	89 1c 24             	mov    %ebx,(%esp)
c002b47b:	e8 2a 7a ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b480:	c7 04 24 b9 06 03 c0 	movl   $0xc00306b9,(%esp)
c002b487:	e8 e1 f2 ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002b48c:	89 1c 24             	mov    %ebx,(%esp)
c002b48f:	e8 e0 7b ff ff       	call   c0023074 <lock_release>
  msg ("Thread b finished.");
c002b494:	c7 04 24 d3 06 03 c0 	movl   $0xc00306d3,(%esp)
c002b49b:	e8 cd f2 ff ff       	call   c002a76d <msg>
}
c002b4a0:	83 c4 18             	add    $0x18,%esp
c002b4a3:	5b                   	pop    %ebx
c002b4a4:	c3                   	ret    

c002b4a5 <a_thread_func>:
{
c002b4a5:	53                   	push   %ebx
c002b4a6:	83 ec 18             	sub    $0x18,%esp
c002b4a9:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b4ad:	89 1c 24             	mov    %ebx,(%esp)
c002b4b0:	e8 f5 79 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b4b5:	c7 04 24 e6 06 03 c0 	movl   $0xc00306e6,(%esp)
c002b4bc:	e8 ac f2 ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002b4c1:	89 1c 24             	mov    %ebx,(%esp)
c002b4c4:	e8 ab 7b ff ff       	call   c0023074 <lock_release>
  msg ("Thread a finished.");
c002b4c9:	c7 04 24 00 07 03 c0 	movl   $0xc0030700,(%esp)
c002b4d0:	e8 98 f2 ff ff       	call   c002a76d <msg>
}
c002b4d5:	83 c4 18             	add    $0x18,%esp
c002b4d8:	5b                   	pop    %ebx
c002b4d9:	c3                   	ret    

c002b4da <test_priority_donate_multiple2>:
{
c002b4da:	56                   	push   %esi
c002b4db:	53                   	push   %ebx
c002b4dc:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b4df:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b4e6:	74 2c                	je     c002b514 <test_priority_donate_multiple2+0x3a>
c002b4e8:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b4ef:	c0 
c002b4f0:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b4f7:	c0 
c002b4f8:	c7 44 24 08 f0 df 02 	movl   $0xc002dff0,0x8(%esp)
c002b4ff:	c0 
c002b500:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b507:	00 
c002b508:	c7 04 24 dc 07 03 c0 	movl   $0xc00307dc,(%esp)
c002b50f:	e8 9f d4 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b514:	e8 74 5a ff ff       	call   c0020f8d <thread_get_priority>
c002b519:	83 f8 1f             	cmp    $0x1f,%eax
c002b51c:	74 2c                	je     c002b54a <test_priority_donate_multiple2+0x70>
c002b51e:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b525:	c0 
c002b526:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b52d:	c0 
c002b52e:	c7 44 24 08 f0 df 02 	movl   $0xc002dff0,0x8(%esp)
c002b535:	c0 
c002b536:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b53d:	00 
c002b53e:	c7 04 24 dc 07 03 c0 	movl   $0xc00307dc,(%esp)
c002b545:	e8 69 d4 ff ff       	call   c00289b3 <debug_panic>
  lock_init (&a);
c002b54a:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b54e:	89 34 24             	mov    %esi,(%esp)
c002b551:	e8 b7 78 ff ff       	call   c0022e0d <lock_init>
  lock_init (&b);
c002b556:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b55a:	89 1c 24             	mov    %ebx,(%esp)
c002b55d:	e8 ab 78 ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&a);
c002b562:	89 34 24             	mov    %esi,(%esp)
c002b565:	e8 40 79 ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (&b);
c002b56a:	89 1c 24             	mov    %ebx,(%esp)
c002b56d:	e8 38 79 ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 3, a_thread_func, &a);
c002b572:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b576:	c7 44 24 08 a5 b4 02 	movl   $0xc002b4a5,0x8(%esp)
c002b57d:	c0 
c002b57e:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b585:	00 
c002b586:	c7 04 24 b3 f2 02 c0 	movl   $0xc002f2b3,(%esp)
c002b58d:	e8 f0 5f ff ff       	call   c0021582 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b592:	e8 f6 59 ff ff       	call   c0020f8d <thread_get_priority>
c002b597:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b59b:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b5a2:	00 
c002b5a3:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b5aa:	e8 be f1 ff ff       	call   c002a76d <msg>
  thread_create ("c", PRI_DEFAULT + 1, c_thread_func, NULL);
c002b5af:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b5b6:	00 
c002b5b7:	c7 44 24 08 5d b4 02 	movl   $0xc002b45d,0x8(%esp)
c002b5be:	c0 
c002b5bf:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b5c6:	00 
c002b5c7:	c7 04 24 9e f6 02 c0 	movl   $0xc002f69e,(%esp)
c002b5ce:	e8 af 5f ff ff       	call   c0021582 <thread_create>
  thread_create ("b", PRI_DEFAULT + 5, b_thread_func, &b);
c002b5d3:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b5d7:	c7 44 24 08 70 b4 02 	movl   $0xc002b470,0x8(%esp)
c002b5de:	c0 
c002b5df:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5e6:	00 
c002b5e7:	c7 04 24 7d fc 02 c0 	movl   $0xc002fc7d,(%esp)
c002b5ee:	e8 8f 5f ff ff       	call   c0021582 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5f3:	e8 95 59 ff ff       	call   c0020f8d <thread_get_priority>
c002b5f8:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5fc:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b603:	00 
c002b604:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b60b:	e8 5d f1 ff ff       	call   c002a76d <msg>
  lock_release (&a);
c002b610:	89 34 24             	mov    %esi,(%esp)
c002b613:	e8 5c 7a ff ff       	call   c0023074 <lock_release>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b618:	e8 70 59 ff ff       	call   c0020f8d <thread_get_priority>
c002b61d:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b621:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b628:	00 
c002b629:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b630:	e8 38 f1 ff ff       	call   c002a76d <msg>
  lock_release (&b);
c002b635:	89 1c 24             	mov    %ebx,(%esp)
c002b638:	e8 37 7a ff ff       	call   c0023074 <lock_release>
  msg ("Threads b, a, c should have just finished, in that order.");
c002b63d:	c7 04 24 0c 08 03 c0 	movl   $0xc003080c,(%esp)
c002b644:	e8 24 f1 ff ff       	call   c002a76d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b649:	e8 3f 59 ff ff       	call   c0020f8d <thread_get_priority>
c002b64e:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b652:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b659:	00 
c002b65a:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002b661:	e8 07 f1 ff ff       	call   c002a76d <msg>
}
c002b666:	83 c4 74             	add    $0x74,%esp
c002b669:	5b                   	pop    %ebx
c002b66a:	5e                   	pop    %esi
c002b66b:	c3                   	ret    

c002b66c <high_thread_func>:
  msg ("Middle thread finished.");
}

static void
high_thread_func (void *lock_) 
{
c002b66c:	53                   	push   %ebx
c002b66d:	83 ec 18             	sub    $0x18,%esp
c002b670:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b674:	89 1c 24             	mov    %ebx,(%esp)
c002b677:	e8 2e 78 ff ff       	call   c0022eaa <lock_acquire>
  msg ("High thread got the lock.");
c002b67c:	c7 04 24 46 08 03 c0 	movl   $0xc0030846,(%esp)
c002b683:	e8 e5 f0 ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002b688:	89 1c 24             	mov    %ebx,(%esp)
c002b68b:	e8 e4 79 ff ff       	call   c0023074 <lock_release>
  msg ("High thread finished.");
c002b690:	c7 04 24 60 08 03 c0 	movl   $0xc0030860,(%esp)
c002b697:	e8 d1 f0 ff ff       	call   c002a76d <msg>
}
c002b69c:	83 c4 18             	add    $0x18,%esp
c002b69f:	5b                   	pop    %ebx
c002b6a0:	c3                   	ret    

c002b6a1 <medium_thread_func>:
{
c002b6a1:	53                   	push   %ebx
c002b6a2:	83 ec 18             	sub    $0x18,%esp
c002b6a5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (locks->b);
c002b6a9:	8b 43 04             	mov    0x4(%ebx),%eax
c002b6ac:	89 04 24             	mov    %eax,(%esp)
c002b6af:	e8 f6 77 ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (locks->a);
c002b6b4:	8b 03                	mov    (%ebx),%eax
c002b6b6:	89 04 24             	mov    %eax,(%esp)
c002b6b9:	e8 ec 77 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Medium thread should have priority %d.  Actual priority: %d.",
c002b6be:	e8 ca 58 ff ff       	call   c0020f8d <thread_get_priority>
c002b6c3:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b6c7:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b6ce:	00 
c002b6cf:	c7 04 24 b8 08 03 c0 	movl   $0xc00308b8,(%esp)
c002b6d6:	e8 92 f0 ff ff       	call   c002a76d <msg>
  msg ("Medium thread got the lock.");
c002b6db:	c7 04 24 76 08 03 c0 	movl   $0xc0030876,(%esp)
c002b6e2:	e8 86 f0 ff ff       	call   c002a76d <msg>
  lock_release (locks->a);
c002b6e7:	8b 03                	mov    (%ebx),%eax
c002b6e9:	89 04 24             	mov    %eax,(%esp)
c002b6ec:	e8 83 79 ff ff       	call   c0023074 <lock_release>
  thread_yield ();
c002b6f1:	e8 ea 5d ff ff       	call   c00214e0 <thread_yield>
  lock_release (locks->b);
c002b6f6:	8b 43 04             	mov    0x4(%ebx),%eax
c002b6f9:	89 04 24             	mov    %eax,(%esp)
c002b6fc:	e8 73 79 ff ff       	call   c0023074 <lock_release>
  thread_yield ();
c002b701:	e8 da 5d ff ff       	call   c00214e0 <thread_yield>
  msg ("High thread should have just finished.");
c002b706:	c7 04 24 f8 08 03 c0 	movl   $0xc00308f8,(%esp)
c002b70d:	e8 5b f0 ff ff       	call   c002a76d <msg>
  msg ("Middle thread finished.");
c002b712:	c7 04 24 92 08 03 c0 	movl   $0xc0030892,(%esp)
c002b719:	e8 4f f0 ff ff       	call   c002a76d <msg>
}
c002b71e:	83 c4 18             	add    $0x18,%esp
c002b721:	5b                   	pop    %ebx
c002b722:	c3                   	ret    

c002b723 <test_priority_donate_nest>:
{
c002b723:	56                   	push   %esi
c002b724:	53                   	push   %ebx
c002b725:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b728:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b72f:	74 2c                	je     c002b75d <test_priority_donate_nest+0x3a>
c002b731:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b738:	c0 
c002b739:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b740:	c0 
c002b741:	c7 44 24 08 0f e0 02 	movl   $0xc002e00f,0x8(%esp)
c002b748:	c0 
c002b749:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b750:	00 
c002b751:	c7 04 24 20 09 03 c0 	movl   $0xc0030920,(%esp)
c002b758:	e8 56 d2 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b75d:	e8 2b 58 ff ff       	call   c0020f8d <thread_get_priority>
c002b762:	83 f8 1f             	cmp    $0x1f,%eax
c002b765:	74 2c                	je     c002b793 <test_priority_donate_nest+0x70>
c002b767:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b76e:	c0 
c002b76f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b776:	c0 
c002b777:	c7 44 24 08 0f e0 02 	movl   $0xc002e00f,0x8(%esp)
c002b77e:	c0 
c002b77f:	c7 44 24 04 25 00 00 	movl   $0x25,0x4(%esp)
c002b786:	00 
c002b787:	c7 04 24 20 09 03 c0 	movl   $0xc0030920,(%esp)
c002b78e:	e8 20 d2 ff ff       	call   c00289b3 <debug_panic>
  lock_init (&a);
c002b793:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b797:	89 1c 24             	mov    %ebx,(%esp)
c002b79a:	e8 6e 76 ff ff       	call   c0022e0d <lock_init>
  lock_init (&b);
c002b79f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b7a3:	89 34 24             	mov    %esi,(%esp)
c002b7a6:	e8 62 76 ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&a);
c002b7ab:	89 1c 24             	mov    %ebx,(%esp)
c002b7ae:	e8 f7 76 ff ff       	call   c0022eaa <lock_acquire>
  locks.a = &a;
c002b7b3:	89 5c 24 20          	mov    %ebx,0x20(%esp)
  locks.b = &b;
c002b7b7:	89 74 24 24          	mov    %esi,0x24(%esp)
  thread_create ("medium", PRI_DEFAULT + 1, medium_thread_func, &locks);
c002b7bb:	8d 44 24 20          	lea    0x20(%esp),%eax
c002b7bf:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002b7c3:	c7 44 24 08 a1 b6 02 	movl   $0xc002b6a1,0x8(%esp)
c002b7ca:	c0 
c002b7cb:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b7d2:	00 
c002b7d3:	c7 04 24 aa 08 03 c0 	movl   $0xc00308aa,(%esp)
c002b7da:	e8 a3 5d ff ff       	call   c0021582 <thread_create>
  thread_yield ();
c002b7df:	e8 fc 5c ff ff       	call   c00214e0 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b7e4:	e8 a4 57 ff ff       	call   c0020f8d <thread_get_priority>
c002b7e9:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b7ed:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b7f4:	00 
c002b7f5:	c7 04 24 4c 09 03 c0 	movl   $0xc003094c,(%esp)
c002b7fc:	e8 6c ef ff ff       	call   c002a76d <msg>
  thread_create ("high", PRI_DEFAULT + 2, high_thread_func, &b);
c002b801:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b805:	c7 44 24 08 6c b6 02 	movl   $0xc002b66c,0x8(%esp)
c002b80c:	c0 
c002b80d:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b814:	00 
c002b815:	c7 04 24 b1 08 03 c0 	movl   $0xc00308b1,(%esp)
c002b81c:	e8 61 5d ff ff       	call   c0021582 <thread_create>
  thread_yield ();
c002b821:	e8 ba 5c ff ff       	call   c00214e0 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b826:	e8 62 57 ff ff       	call   c0020f8d <thread_get_priority>
c002b82b:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b82f:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b836:	00 
c002b837:	c7 04 24 4c 09 03 c0 	movl   $0xc003094c,(%esp)
c002b83e:	e8 2a ef ff ff       	call   c002a76d <msg>
  lock_release (&a);
c002b843:	89 1c 24             	mov    %ebx,(%esp)
c002b846:	e8 29 78 ff ff       	call   c0023074 <lock_release>
  thread_yield ();
c002b84b:	e8 90 5c ff ff       	call   c00214e0 <thread_yield>
  msg ("Medium thread should just have finished.");
c002b850:	c7 04 24 88 09 03 c0 	movl   $0xc0030988,(%esp)
c002b857:	e8 11 ef ff ff       	call   c002a76d <msg>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b85c:	e8 2c 57 ff ff       	call   c0020f8d <thread_get_priority>
c002b861:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b865:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b86c:	00 
c002b86d:	c7 04 24 4c 09 03 c0 	movl   $0xc003094c,(%esp)
c002b874:	e8 f4 ee ff ff       	call   c002a76d <msg>
}
c002b879:	83 c4 74             	add    $0x74,%esp
c002b87c:	5b                   	pop    %ebx
c002b87d:	5e                   	pop    %esi
c002b87e:	c3                   	ret    

c002b87f <h_thread_func>:
  msg ("Thread M finished.");
}

static void
h_thread_func (void *ls_) 
{
c002b87f:	53                   	push   %ebx
c002b880:	83 ec 18             	sub    $0x18,%esp
c002b883:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock_and_sema *ls = ls_;

  lock_acquire (&ls->lock);
c002b887:	89 1c 24             	mov    %ebx,(%esp)
c002b88a:	e8 1b 76 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread H acquired lock.");
c002b88f:	c7 04 24 b1 09 03 c0 	movl   $0xc00309b1,(%esp)
c002b896:	e8 d2 ee ff ff       	call   c002a76d <msg>

  sema_up (&ls->sema);
c002b89b:	8d 43 24             	lea    0x24(%ebx),%eax
c002b89e:	89 04 24             	mov    %eax,(%esp)
c002b8a1:	e8 f1 73 ff ff       	call   c0022c97 <sema_up>
  lock_release (&ls->lock);
c002b8a6:	89 1c 24             	mov    %ebx,(%esp)
c002b8a9:	e8 c6 77 ff ff       	call   c0023074 <lock_release>
  msg ("Thread H finished.");
c002b8ae:	c7 04 24 c9 09 03 c0 	movl   $0xc00309c9,(%esp)
c002b8b5:	e8 b3 ee ff ff       	call   c002a76d <msg>
}
c002b8ba:	83 c4 18             	add    $0x18,%esp
c002b8bd:	5b                   	pop    %ebx
c002b8be:	c3                   	ret    

c002b8bf <m_thread_func>:
{
c002b8bf:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&ls->sema);
c002b8c2:	8b 44 24 20          	mov    0x20(%esp),%eax
c002b8c6:	83 c0 24             	add    $0x24,%eax
c002b8c9:	89 04 24             	mov    %eax,(%esp)
c002b8cc:	e8 b1 72 ff ff       	call   c0022b82 <sema_down>
  msg ("Thread M finished.");
c002b8d1:	c7 04 24 dc 09 03 c0 	movl   $0xc00309dc,(%esp)
c002b8d8:	e8 90 ee ff ff       	call   c002a76d <msg>
}
c002b8dd:	83 c4 1c             	add    $0x1c,%esp
c002b8e0:	c3                   	ret    

c002b8e1 <l_thread_func>:
{
c002b8e1:	53                   	push   %ebx
c002b8e2:	83 ec 18             	sub    $0x18,%esp
c002b8e5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (&ls->lock);
c002b8e9:	89 1c 24             	mov    %ebx,(%esp)
c002b8ec:	e8 b9 75 ff ff       	call   c0022eaa <lock_acquire>
  msg ("Thread L acquired lock.");
c002b8f1:	c7 04 24 ef 09 03 c0 	movl   $0xc00309ef,(%esp)
c002b8f8:	e8 70 ee ff ff       	call   c002a76d <msg>
  sema_down (&ls->sema);
c002b8fd:	8d 43 24             	lea    0x24(%ebx),%eax
c002b900:	89 04 24             	mov    %eax,(%esp)
c002b903:	e8 7a 72 ff ff       	call   c0022b82 <sema_down>
  msg ("Thread L downed semaphore.");
c002b908:	c7 04 24 07 0a 03 c0 	movl   $0xc0030a07,(%esp)
c002b90f:	e8 59 ee ff ff       	call   c002a76d <msg>
  lock_release (&ls->lock);
c002b914:	89 1c 24             	mov    %ebx,(%esp)
c002b917:	e8 58 77 ff ff       	call   c0023074 <lock_release>
  msg ("Thread L finished.");
c002b91c:	c7 04 24 22 0a 03 c0 	movl   $0xc0030a22,(%esp)
c002b923:	e8 45 ee ff ff       	call   c002a76d <msg>
}
c002b928:	83 c4 18             	add    $0x18,%esp
c002b92b:	5b                   	pop    %ebx
c002b92c:	c3                   	ret    

c002b92d <test_priority_donate_sema>:
{
c002b92d:	56                   	push   %esi
c002b92e:	53                   	push   %ebx
c002b92f:	83 ec 64             	sub    $0x64,%esp
  ASSERT (!thread_mlfqs);
c002b932:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b939:	74 2c                	je     c002b967 <test_priority_donate_sema+0x3a>
c002b93b:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002b942:	c0 
c002b943:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b94a:	c0 
c002b94b:	c7 44 24 08 29 e0 02 	movl   $0xc002e029,0x8(%esp)
c002b952:	c0 
c002b953:	c7 44 24 04 23 00 00 	movl   $0x23,0x4(%esp)
c002b95a:	00 
c002b95b:	c7 04 24 54 0a 03 c0 	movl   $0xc0030a54,(%esp)
c002b962:	e8 4c d0 ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b967:	e8 21 56 ff ff       	call   c0020f8d <thread_get_priority>
c002b96c:	83 f8 1f             	cmp    $0x1f,%eax
c002b96f:	74 2c                	je     c002b99d <test_priority_donate_sema+0x70>
c002b971:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002b978:	c0 
c002b979:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002b980:	c0 
c002b981:	c7 44 24 08 29 e0 02 	movl   $0xc002e029,0x8(%esp)
c002b988:	c0 
c002b989:	c7 44 24 04 26 00 00 	movl   $0x26,0x4(%esp)
c002b990:	00 
c002b991:	c7 04 24 54 0a 03 c0 	movl   $0xc0030a54,(%esp)
c002b998:	e8 16 d0 ff ff       	call   c00289b3 <debug_panic>
  lock_init (&ls.lock);
c002b99d:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b9a1:	89 1c 24             	mov    %ebx,(%esp)
c002b9a4:	e8 64 74 ff ff       	call   c0022e0d <lock_init>
  sema_init (&ls.sema, 0);
c002b9a9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002b9b0:	00 
c002b9b1:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b9b5:	89 34 24             	mov    %esi,(%esp)
c002b9b8:	e8 79 71 ff ff       	call   c0022b36 <sema_init>
  thread_create ("low", PRI_DEFAULT + 1, l_thread_func, &ls);
c002b9bd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9c1:	c7 44 24 08 e1 b8 02 	movl   $0xc002b8e1,0x8(%esp)
c002b9c8:	c0 
c002b9c9:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b9d0:	00 
c002b9d1:	c7 04 24 35 0a 03 c0 	movl   $0xc0030a35,(%esp)
c002b9d8:	e8 a5 5b ff ff       	call   c0021582 <thread_create>
  thread_create ("med", PRI_DEFAULT + 3, m_thread_func, &ls);
c002b9dd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9e1:	c7 44 24 08 bf b8 02 	movl   $0xc002b8bf,0x8(%esp)
c002b9e8:	c0 
c002b9e9:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b9f0:	00 
c002b9f1:	c7 04 24 39 0a 03 c0 	movl   $0xc0030a39,(%esp)
c002b9f8:	e8 85 5b ff ff       	call   c0021582 <thread_create>
  thread_create ("high", PRI_DEFAULT + 5, h_thread_func, &ls);
c002b9fd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002ba01:	c7 44 24 08 7f b8 02 	movl   $0xc002b87f,0x8(%esp)
c002ba08:	c0 
c002ba09:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002ba10:	00 
c002ba11:	c7 04 24 b1 08 03 c0 	movl   $0xc00308b1,(%esp)
c002ba18:	e8 65 5b ff ff       	call   c0021582 <thread_create>
  sema_up (&ls.sema);
c002ba1d:	89 34 24             	mov    %esi,(%esp)
c002ba20:	e8 72 72 ff ff       	call   c0022c97 <sema_up>
  msg ("Main thread finished.");
c002ba25:	c7 04 24 3d 0a 03 c0 	movl   $0xc0030a3d,(%esp)
c002ba2c:	e8 3c ed ff ff       	call   c002a76d <msg>
}
c002ba31:	83 c4 64             	add    $0x64,%esp
c002ba34:	5b                   	pop    %ebx
c002ba35:	5e                   	pop    %esi
c002ba36:	c3                   	ret    

c002ba37 <acquire_thread_func>:
       PRI_DEFAULT - 10, thread_get_priority ());
}

static void
acquire_thread_func (void *lock_) 
{
c002ba37:	53                   	push   %ebx
c002ba38:	83 ec 18             	sub    $0x18,%esp
c002ba3b:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002ba3f:	89 1c 24             	mov    %ebx,(%esp)
c002ba42:	e8 63 74 ff ff       	call   c0022eaa <lock_acquire>
  msg ("acquire: got the lock");
c002ba47:	c7 04 24 7f 0a 03 c0 	movl   $0xc0030a7f,(%esp)
c002ba4e:	e8 1a ed ff ff       	call   c002a76d <msg>
  lock_release (lock);
c002ba53:	89 1c 24             	mov    %ebx,(%esp)
c002ba56:	e8 19 76 ff ff       	call   c0023074 <lock_release>
  msg ("acquire: done");
c002ba5b:	c7 04 24 95 0a 03 c0 	movl   $0xc0030a95,(%esp)
c002ba62:	e8 06 ed ff ff       	call   c002a76d <msg>
}
c002ba67:	83 c4 18             	add    $0x18,%esp
c002ba6a:	5b                   	pop    %ebx
c002ba6b:	c3                   	ret    

c002ba6c <test_priority_donate_lower>:
{
c002ba6c:	53                   	push   %ebx
c002ba6d:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002ba70:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002ba77:	74 2c                	je     c002baa5 <test_priority_donate_lower+0x39>
c002ba79:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002ba80:	c0 
c002ba81:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ba88:	c0 
c002ba89:	c7 44 24 08 43 e0 02 	movl   $0xc002e043,0x8(%esp)
c002ba90:	c0 
c002ba91:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002ba98:	00 
c002ba99:	c7 04 24 c8 0a 03 c0 	movl   $0xc0030ac8,(%esp)
c002baa0:	e8 0e cf ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002baa5:	e8 e3 54 ff ff       	call   c0020f8d <thread_get_priority>
c002baaa:	83 f8 1f             	cmp    $0x1f,%eax
c002baad:	74 2c                	je     c002badb <test_priority_donate_lower+0x6f>
c002baaf:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002bab6:	c0 
c002bab7:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002babe:	c0 
c002babf:	c7 44 24 08 43 e0 02 	movl   $0xc002e043,0x8(%esp)
c002bac6:	c0 
c002bac7:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002bace:	00 
c002bacf:	c7 04 24 c8 0a 03 c0 	movl   $0xc0030ac8,(%esp)
c002bad6:	e8 d8 ce ff ff       	call   c00289b3 <debug_panic>
  lock_init (&lock);
c002badb:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002badf:	89 1c 24             	mov    %ebx,(%esp)
c002bae2:	e8 26 73 ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&lock);
c002bae7:	89 1c 24             	mov    %ebx,(%esp)
c002baea:	e8 bb 73 ff ff       	call   c0022eaa <lock_acquire>
  thread_create ("acquire", PRI_DEFAULT + 10, acquire_thread_func, &lock);
c002baef:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002baf3:	c7 44 24 08 37 ba 02 	movl   $0xc002ba37,0x8(%esp)
c002bafa:	c0 
c002bafb:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb02:	00 
c002bb03:	c7 04 24 a3 0a 03 c0 	movl   $0xc0030aa3,(%esp)
c002bb0a:	e8 73 5a ff ff       	call   c0021582 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb0f:	e8 79 54 ff ff       	call   c0020f8d <thread_get_priority>
c002bb14:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb18:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb1f:	00 
c002bb20:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002bb27:	e8 41 ec ff ff       	call   c002a76d <msg>
  msg ("Lowering base priority...");
c002bb2c:	c7 04 24 ab 0a 03 c0 	movl   $0xc0030aab,(%esp)
c002bb33:	e8 35 ec ff ff       	call   c002a76d <msg>
  thread_set_priority (PRI_DEFAULT - 10);
c002bb38:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
c002bb3f:	e8 ac 5b ff ff       	call   c00216f0 <thread_set_priority>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb44:	e8 44 54 ff ff       	call   c0020f8d <thread_get_priority>
c002bb49:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb4d:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb54:	00 
c002bb55:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002bb5c:	e8 0c ec ff ff       	call   c002a76d <msg>
  lock_release (&lock);
c002bb61:	89 1c 24             	mov    %ebx,(%esp)
c002bb64:	e8 0b 75 ff ff       	call   c0023074 <lock_release>
  msg ("acquire must already have finished.");
c002bb69:	c7 04 24 f4 0a 03 c0 	movl   $0xc0030af4,(%esp)
c002bb70:	e8 f8 eb ff ff       	call   c002a76d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb75:	e8 13 54 ff ff       	call   c0020f8d <thread_get_priority>
c002bb7a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb7e:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bb85:	00 
c002bb86:	c7 04 24 44 07 03 c0 	movl   $0xc0030744,(%esp)
c002bb8d:	e8 db eb ff ff       	call   c002a76d <msg>
}
c002bb92:	83 c4 58             	add    $0x58,%esp
c002bb95:	5b                   	pop    %ebx
c002bb96:	c3                   	ret    
c002bb97:	90                   	nop
c002bb98:	90                   	nop
c002bb99:	90                   	nop
c002bb9a:	90                   	nop
c002bb9b:	90                   	nop
c002bb9c:	90                   	nop
c002bb9d:	90                   	nop
c002bb9e:	90                   	nop
c002bb9f:	90                   	nop

c002bba0 <simple_thread_func>:
    }
}

static void 
simple_thread_func (void *data_) 
{
c002bba0:	56                   	push   %esi
c002bba1:	53                   	push   %ebx
c002bba2:	83 ec 14             	sub    $0x14,%esp
c002bba5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002bba9:	be 10 00 00 00       	mov    $0x10,%esi
  struct simple_thread_data *data = data_;
  int i;
  
  for (i = 0; i < ITER_CNT; i++) 
    {
      lock_acquire (data->lock);
c002bbae:	8b 43 08             	mov    0x8(%ebx),%eax
c002bbb1:	89 04 24             	mov    %eax,(%esp)
c002bbb4:	e8 f1 72 ff ff       	call   c0022eaa <lock_acquire>
      *(*data->op)++ = data->id;
c002bbb9:	8b 53 0c             	mov    0xc(%ebx),%edx
c002bbbc:	8b 02                	mov    (%edx),%eax
c002bbbe:	8d 48 04             	lea    0x4(%eax),%ecx
c002bbc1:	89 0a                	mov    %ecx,(%edx)
c002bbc3:	8b 13                	mov    (%ebx),%edx
c002bbc5:	89 10                	mov    %edx,(%eax)
      lock_release (data->lock);
c002bbc7:	8b 43 08             	mov    0x8(%ebx),%eax
c002bbca:	89 04 24             	mov    %eax,(%esp)
c002bbcd:	e8 a2 74 ff ff       	call   c0023074 <lock_release>
      thread_yield ();
c002bbd2:	e8 09 59 ff ff       	call   c00214e0 <thread_yield>
  for (i = 0; i < ITER_CNT; i++) 
c002bbd7:	83 ee 01             	sub    $0x1,%esi
c002bbda:	75 d2                	jne    c002bbae <simple_thread_func+0xe>
    }
}
c002bbdc:	83 c4 14             	add    $0x14,%esp
c002bbdf:	5b                   	pop    %ebx
c002bbe0:	5e                   	pop    %esi
c002bbe1:	c3                   	ret    

c002bbe2 <test_priority_fifo>:
{
c002bbe2:	55                   	push   %ebp
c002bbe3:	57                   	push   %edi
c002bbe4:	56                   	push   %esi
c002bbe5:	53                   	push   %ebx
c002bbe6:	81 ec 6c 01 00 00    	sub    $0x16c,%esp
  ASSERT (!thread_mlfqs);
c002bbec:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002bbf3:	74 2c                	je     c002bc21 <test_priority_fifo+0x3f>
c002bbf5:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002bbfc:	c0 
c002bbfd:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bc04:	c0 
c002bc05:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bc0c:	c0 
c002bc0d:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002bc14:	00 
c002bc15:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bc1c:	e8 92 cd ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002bc21:	e8 67 53 ff ff       	call   c0020f8d <thread_get_priority>
c002bc26:	83 f8 1f             	cmp    $0x1f,%eax
c002bc29:	74 2c                	je     c002bc57 <test_priority_fifo+0x75>
c002bc2b:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002bc32:	c0 
c002bc33:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bc3a:	c0 
c002bc3b:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bc42:	c0 
c002bc43:	c7 44 24 04 2b 00 00 	movl   $0x2b,0x4(%esp)
c002bc4a:	00 
c002bc4b:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bc52:	e8 5c cd ff ff       	call   c00289b3 <debug_panic>
  msg ("%d threads will iterate %d times in the same order each time.",
c002bc57:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c002bc5e:	00 
c002bc5f:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bc66:	00 
c002bc67:	c7 04 24 6c 0b 03 c0 	movl   $0xc0030b6c,(%esp)
c002bc6e:	e8 fa ea ff ff       	call   c002a76d <msg>
  msg ("If the order varies then there is a bug.");
c002bc73:	c7 04 24 ac 0b 03 c0 	movl   $0xc0030bac,(%esp)
c002bc7a:	e8 ee ea ff ff       	call   c002a76d <msg>
  output = op = malloc (sizeof *output * THREAD_CNT * ITER_CNT * 2);
c002bc7f:	c7 04 24 00 08 00 00 	movl   $0x800,(%esp)
c002bc86:	e8 e9 7d ff ff       	call   c0023a74 <malloc>
c002bc8b:	89 c6                	mov    %eax,%esi
c002bc8d:	89 44 24 38          	mov    %eax,0x38(%esp)
  ASSERT (output != NULL);
c002bc91:	85 c0                	test   %eax,%eax
c002bc93:	75 2c                	jne    c002bcc1 <test_priority_fifo+0xdf>
c002bc95:	c7 44 24 10 4a 01 03 	movl   $0xc003014a,0x10(%esp)
c002bc9c:	c0 
c002bc9d:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bca4:	c0 
c002bca5:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bcac:	c0 
c002bcad:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c002bcb4:	00 
c002bcb5:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bcbc:	e8 f2 cc ff ff       	call   c00289b3 <debug_panic>
  lock_init (&lock);
c002bcc1:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bcc5:	89 04 24             	mov    %eax,(%esp)
c002bcc8:	e8 40 71 ff ff       	call   c0022e0d <lock_init>
  thread_set_priority (PRI_DEFAULT + 2);
c002bccd:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c002bcd4:	e8 17 5a ff ff       	call   c00216f0 <thread_set_priority>
c002bcd9:	8d 5c 24 60          	lea    0x60(%esp),%ebx
  for (i = 0; i < THREAD_CNT; i++) 
c002bcdd:	bf 00 00 00 00       	mov    $0x0,%edi
      snprintf (name, sizeof name, "%d", i);
c002bce2:	8d 6c 24 28          	lea    0x28(%esp),%ebp
c002bce6:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002bcea:	c7 44 24 08 60 01 03 	movl   $0xc0030160,0x8(%esp)
c002bcf1:	c0 
c002bcf2:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bcf9:	00 
c002bcfa:	89 2c 24             	mov    %ebp,(%esp)
c002bcfd:	e8 5d b5 ff ff       	call   c002725f <snprintf>
      d->id = i;
c002bd02:	89 3b                	mov    %edi,(%ebx)
      d->iterations = 0;
c002bd04:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
      d->lock = &lock;
c002bd0b:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bd0f:	89 43 08             	mov    %eax,0x8(%ebx)
      d->op = &op;
c002bd12:	8d 44 24 38          	lea    0x38(%esp),%eax
c002bd16:	89 43 0c             	mov    %eax,0xc(%ebx)
      thread_create (name, PRI_DEFAULT + 1, simple_thread_func, d);
c002bd19:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bd1d:	c7 44 24 08 a0 bb 02 	movl   $0xc002bba0,0x8(%esp)
c002bd24:	c0 
c002bd25:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bd2c:	00 
c002bd2d:	89 2c 24             	mov    %ebp,(%esp)
c002bd30:	e8 4d 58 ff ff       	call   c0021582 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002bd35:	83 c7 01             	add    $0x1,%edi
c002bd38:	83 c3 10             	add    $0x10,%ebx
c002bd3b:	83 ff 10             	cmp    $0x10,%edi
c002bd3e:	75 a6                	jne    c002bce6 <test_priority_fifo+0x104>
  thread_set_priority (PRI_DEFAULT);
c002bd40:	c7 04 24 1f 00 00 00 	movl   $0x1f,(%esp)
c002bd47:	e8 a4 59 ff ff       	call   c00216f0 <thread_set_priority>
  ASSERT (lock.holder == NULL);
c002bd4c:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002bd51:	75 13                	jne    c002bd66 <test_priority_fifo+0x184>
  for (; output < op; output++) 
c002bd53:	3b 74 24 38          	cmp    0x38(%esp),%esi
c002bd57:	0f 83 be 00 00 00    	jae    c002be1b <test_priority_fifo+0x239>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd5d:	8b 3e                	mov    (%esi),%edi
c002bd5f:	83 ff 0f             	cmp    $0xf,%edi
c002bd62:	76 61                	jbe    c002bdc5 <test_priority_fifo+0x1e3>
c002bd64:	eb 33                	jmp    c002bd99 <test_priority_fifo+0x1b7>
  ASSERT (lock.holder == NULL);
c002bd66:	c7 44 24 10 18 0b 03 	movl   $0xc0030b18,0x10(%esp)
c002bd6d:	c0 
c002bd6e:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bd75:	c0 
c002bd76:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bd7d:	c0 
c002bd7e:	c7 44 24 04 44 00 00 	movl   $0x44,0x4(%esp)
c002bd85:	00 
c002bd86:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bd8d:	e8 21 cc ff ff       	call   c00289b3 <debug_panic>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd92:	8b 3e                	mov    (%esi),%edi
c002bd94:	83 ff 0f             	cmp    $0xf,%edi
c002bd97:	76 31                	jbe    c002bdca <test_priority_fifo+0x1e8>
c002bd99:	c7 44 24 10 d8 0b 03 	movl   $0xc0030bd8,0x10(%esp)
c002bda0:	c0 
c002bda1:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bda8:	c0 
c002bda9:	c7 44 24 08 5e e0 02 	movl   $0xc002e05e,0x8(%esp)
c002bdb0:	c0 
c002bdb1:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002bdb8:	00 
c002bdb9:	c7 04 24 48 0b 03 c0 	movl   $0xc0030b48,(%esp)
c002bdc0:	e8 ee cb ff ff       	call   c00289b3 <debug_panic>
c002bdc5:	bb 00 00 00 00       	mov    $0x0,%ebx
      d = data + *output;
c002bdca:	c1 e7 04             	shl    $0x4,%edi
c002bdcd:	8d 44 24 60          	lea    0x60(%esp),%eax
c002bdd1:	01 c7                	add    %eax,%edi
      if (cnt % THREAD_CNT == 0)
c002bdd3:	f6 c3 0f             	test   $0xf,%bl
c002bdd6:	75 0c                	jne    c002bde4 <test_priority_fifo+0x202>
        printf ("(priority-fifo) iteration:");
c002bdd8:	c7 04 24 2c 0b 03 c0 	movl   $0xc0030b2c,(%esp)
c002bddf:	e8 7a ad ff ff       	call   c0026b5e <printf>
      printf (" %d", d->id);
c002bde4:	8b 07                	mov    (%edi),%eax
c002bde6:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bdea:	c7 04 24 5f 01 03 c0 	movl   $0xc003015f,(%esp)
c002bdf1:	e8 68 ad ff ff       	call   c0026b5e <printf>
      if (++cnt % THREAD_CNT == 0)
c002bdf6:	83 c3 01             	add    $0x1,%ebx
c002bdf9:	f6 c3 0f             	test   $0xf,%bl
c002bdfc:	75 0c                	jne    c002be0a <test_priority_fifo+0x228>
        printf ("\n");
c002bdfe:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002be05:	e8 42 e9 ff ff       	call   c002a74c <putchar>
      d->iterations++;
c002be0a:	83 47 04 01          	addl   $0x1,0x4(%edi)
  for (; output < op; output++) 
c002be0e:	83 c6 04             	add    $0x4,%esi
c002be11:	39 74 24 38          	cmp    %esi,0x38(%esp)
c002be15:	0f 87 77 ff ff ff    	ja     c002bd92 <test_priority_fifo+0x1b0>
}
c002be1b:	81 c4 6c 01 00 00    	add    $0x16c,%esp
c002be21:	5b                   	pop    %ebx
c002be22:	5e                   	pop    %esi
c002be23:	5f                   	pop    %edi
c002be24:	5d                   	pop    %ebp
c002be25:	c3                   	ret    

c002be26 <simple_thread_func>:
  msg ("The high-priority thread should have already completed.");
}

static void 
simple_thread_func (void *aux UNUSED) 
{
c002be26:	53                   	push   %ebx
c002be27:	83 ec 18             	sub    $0x18,%esp
  int i;
  
  for (i = 0; i < 5; i++) 
c002be2a:	bb 00 00 00 00       	mov    $0x0,%ebx
    {
      msg ("Thread %s iteration %d", thread_name (), i);
c002be2f:	e8 bc 50 ff ff       	call   c0020ef0 <thread_name>
c002be34:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002be38:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be3c:	c7 04 24 fd 0b 03 c0 	movl   $0xc0030bfd,(%esp)
c002be43:	e8 25 e9 ff ff       	call   c002a76d <msg>
      thread_yield ();
c002be48:	e8 93 56 ff ff       	call   c00214e0 <thread_yield>
  for (i = 0; i < 5; i++) 
c002be4d:	83 c3 01             	add    $0x1,%ebx
c002be50:	83 fb 05             	cmp    $0x5,%ebx
c002be53:	75 da                	jne    c002be2f <simple_thread_func+0x9>
    }
  msg ("Thread %s done!", thread_name ());
c002be55:	e8 96 50 ff ff       	call   c0020ef0 <thread_name>
c002be5a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be5e:	c7 04 24 14 0c 03 c0 	movl   $0xc0030c14,(%esp)
c002be65:	e8 03 e9 ff ff       	call   c002a76d <msg>
}
c002be6a:	83 c4 18             	add    $0x18,%esp
c002be6d:	5b                   	pop    %ebx
c002be6e:	c3                   	ret    

c002be6f <test_priority_preempt>:
{
c002be6f:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002be72:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002be79:	74 2c                	je     c002bea7 <test_priority_preempt+0x38>
c002be7b:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002be82:	c0 
c002be83:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002be8a:	c0 
c002be8b:	c7 44 24 08 71 e0 02 	movl   $0xc002e071,0x8(%esp)
c002be92:	c0 
c002be93:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002be9a:	00 
c002be9b:	c7 04 24 34 0c 03 c0 	movl   $0xc0030c34,(%esp)
c002bea2:	e8 0c cb ff ff       	call   c00289b3 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002bea7:	e8 e1 50 ff ff       	call   c0020f8d <thread_get_priority>
c002beac:	83 f8 1f             	cmp    $0x1f,%eax
c002beaf:	74 2c                	je     c002bedd <test_priority_preempt+0x6e>
c002beb1:	c7 44 24 10 dc 05 03 	movl   $0xc00305dc,0x10(%esp)
c002beb8:	c0 
c002beb9:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bec0:	c0 
c002bec1:	c7 44 24 08 71 e0 02 	movl   $0xc002e071,0x8(%esp)
c002bec8:	c0 
c002bec9:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002bed0:	00 
c002bed1:	c7 04 24 34 0c 03 c0 	movl   $0xc0030c34,(%esp)
c002bed8:	e8 d6 ca ff ff       	call   c00289b3 <debug_panic>
  thread_create ("high-priority", PRI_DEFAULT + 1, simple_thread_func, NULL);
c002bedd:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bee4:	00 
c002bee5:	c7 44 24 08 26 be 02 	movl   $0xc002be26,0x8(%esp)
c002beec:	c0 
c002beed:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bef4:	00 
c002bef5:	c7 04 24 24 0c 03 c0 	movl   $0xc0030c24,(%esp)
c002befc:	e8 81 56 ff ff       	call   c0021582 <thread_create>
  msg ("The high-priority thread should have already completed.");
c002bf01:	c7 04 24 5c 0c 03 c0 	movl   $0xc0030c5c,(%esp)
c002bf08:	e8 60 e8 ff ff       	call   c002a76d <msg>
}
c002bf0d:	83 c4 2c             	add    $0x2c,%esp
c002bf10:	c3                   	ret    

c002bf11 <priority_sema_thread>:
    }
}

static void
priority_sema_thread (void *aux UNUSED) 
{
c002bf11:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&sema);
c002bf14:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bf1b:	e8 62 6c ff ff       	call   c0022b82 <sema_down>
  msg ("Thread %s woke up.", thread_name ());
c002bf20:	e8 cb 4f ff ff       	call   c0020ef0 <thread_name>
c002bf25:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bf29:	c7 04 24 30 04 03 c0 	movl   $0xc0030430,(%esp)
c002bf30:	e8 38 e8 ff ff       	call   c002a76d <msg>
}
c002bf35:	83 c4 1c             	add    $0x1c,%esp
c002bf38:	c3                   	ret    

c002bf39 <test_priority_sema>:
{
c002bf39:	55                   	push   %ebp
c002bf3a:	57                   	push   %edi
c002bf3b:	56                   	push   %esi
c002bf3c:	53                   	push   %ebx
c002bf3d:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002bf40:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002bf47:	74 2c                	je     c002bf75 <test_priority_sema+0x3c>
c002bf49:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002bf50:	c0 
c002bf51:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002bf58:	c0 
c002bf59:	c7 44 24 08 87 e0 02 	movl   $0xc002e087,0x8(%esp)
c002bf60:	c0 
c002bf61:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bf68:	00 
c002bf69:	c7 04 24 ac 0c 03 c0 	movl   $0xc0030cac,(%esp)
c002bf70:	e8 3e ca ff ff       	call   c00289b3 <debug_panic>
  sema_init (&sema, 0);
c002bf75:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002bf7c:	00 
c002bf7d:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bf84:	e8 ad 6b ff ff       	call   c0022b36 <sema_init>
  thread_set_priority (PRI_MIN);
c002bf89:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002bf90:	e8 5b 57 ff ff       	call   c00216f0 <thread_set_priority>
c002bf95:	bb 03 00 00 00       	mov    $0x3,%ebx
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bf9a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002bf9f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bfa3:	89 d8                	mov    %ebx,%eax
c002bfa5:	f7 ed                	imul   %ebp
c002bfa7:	c1 fa 02             	sar    $0x2,%edx
c002bfaa:	89 d8                	mov    %ebx,%eax
c002bfac:	c1 f8 1f             	sar    $0x1f,%eax
c002bfaf:	29 c2                	sub    %eax,%edx
c002bfb1:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002bfb4:	01 c0                	add    %eax,%eax
c002bfb6:	29 d8                	sub    %ebx,%eax
c002bfb8:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002bfbb:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002bfbf:	c7 44 24 08 43 04 03 	movl   $0xc0030443,0x8(%esp)
c002bfc6:	c0 
c002bfc7:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bfce:	00 
c002bfcf:	89 3c 24             	mov    %edi,(%esp)
c002bfd2:	e8 88 b2 ff ff       	call   c002725f <snprintf>
      thread_create (name, priority, priority_sema_thread, NULL);
c002bfd7:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bfde:	00 
c002bfdf:	c7 44 24 08 11 bf 02 	movl   $0xc002bf11,0x8(%esp)
c002bfe6:	c0 
c002bfe7:	89 74 24 04          	mov    %esi,0x4(%esp)
c002bfeb:	89 3c 24             	mov    %edi,(%esp)
c002bfee:	e8 8f 55 ff ff       	call   c0021582 <thread_create>
c002bff3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002bff6:	83 fb 0d             	cmp    $0xd,%ebx
c002bff9:	75 a8                	jne    c002bfa3 <test_priority_sema+0x6a>
c002bffb:	b3 0a                	mov    $0xa,%bl
      sema_up (&sema);
c002bffd:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002c004:	e8 8e 6c ff ff       	call   c0022c97 <sema_up>
      msg ("Back in main thread."); 
c002c009:	c7 04 24 94 0c 03 c0 	movl   $0xc0030c94,(%esp)
c002c010:	e8 58 e7 ff ff       	call   c002a76d <msg>
  for (i = 0; i < 10; i++) 
c002c015:	83 eb 01             	sub    $0x1,%ebx
c002c018:	75 e3                	jne    c002bffd <test_priority_sema+0xc4>
}
c002c01a:	83 c4 3c             	add    $0x3c,%esp
c002c01d:	5b                   	pop    %ebx
c002c01e:	5e                   	pop    %esi
c002c01f:	5f                   	pop    %edi
c002c020:	5d                   	pop    %ebp
c002c021:	c3                   	ret    

c002c022 <priority_condvar_thread>:
    }
}

static void
priority_condvar_thread (void *aux UNUSED) 
{
c002c022:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread %s starting.", thread_name ());
c002c025:	e8 c6 4e ff ff       	call   c0020ef0 <thread_name>
c002c02a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c02e:	c7 04 24 d0 0c 03 c0 	movl   $0xc0030cd0,(%esp)
c002c035:	e8 33 e7 ff ff       	call   c002a76d <msg>
  lock_acquire (&lock);
c002c03a:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c041:	e8 64 6e ff ff       	call   c0022eaa <lock_acquire>
  cond_wait (&condition, &lock);
c002c046:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c04d:	c0 
c002c04e:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c055:	e8 56 71 ff ff       	call   c00231b0 <cond_wait>
  msg ("Thread %s woke up.", thread_name ());
c002c05a:	e8 91 4e ff ff       	call   c0020ef0 <thread_name>
c002c05f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c063:	c7 04 24 30 04 03 c0 	movl   $0xc0030430,(%esp)
c002c06a:	e8 fe e6 ff ff       	call   c002a76d <msg>
  lock_release (&lock);
c002c06f:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c076:	e8 f9 6f ff ff       	call   c0023074 <lock_release>
}
c002c07b:	83 c4 1c             	add    $0x1c,%esp
c002c07e:	c3                   	ret    

c002c07f <test_priority_condvar>:
{
c002c07f:	55                   	push   %ebp
c002c080:	57                   	push   %edi
c002c081:	56                   	push   %esi
c002c082:	53                   	push   %ebx
c002c083:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002c086:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c08d:	74 2c                	je     c002c0bb <test_priority_condvar+0x3c>
c002c08f:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002c096:	c0 
c002c097:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c09e:	c0 
c002c09f:	c7 44 24 08 9a e0 02 	movl   $0xc002e09a,0x8(%esp)
c002c0a6:	c0 
c002c0a7:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002c0ae:	00 
c002c0af:	c7 04 24 f4 0c 03 c0 	movl   $0xc0030cf4,(%esp)
c002c0b6:	e8 f8 c8 ff ff       	call   c00289b3 <debug_panic>
  lock_init (&lock);
c002c0bb:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c0c2:	e8 46 6d ff ff       	call   c0022e0d <lock_init>
  cond_init (&condition);
c002c0c7:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c0ce:	e8 9a 70 ff ff       	call   c002316d <cond_init>
  thread_set_priority (PRI_MIN);
c002c0d3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c0da:	e8 11 56 ff ff       	call   c00216f0 <thread_set_priority>
c002c0df:	bb 07 00 00 00       	mov    $0x7,%ebx
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0e4:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002c0e9:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0ed:	89 d8                	mov    %ebx,%eax
c002c0ef:	f7 ed                	imul   %ebp
c002c0f1:	c1 fa 02             	sar    $0x2,%edx
c002c0f4:	89 d8                	mov    %ebx,%eax
c002c0f6:	c1 f8 1f             	sar    $0x1f,%eax
c002c0f9:	29 c2                	sub    %eax,%edx
c002c0fb:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002c0fe:	01 c0                	add    %eax,%eax
c002c100:	29 d8                	sub    %ebx,%eax
c002c102:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002c105:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c109:	c7 44 24 08 43 04 03 	movl   $0xc0030443,0x8(%esp)
c002c110:	c0 
c002c111:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c118:	00 
c002c119:	89 3c 24             	mov    %edi,(%esp)
c002c11c:	e8 3e b1 ff ff       	call   c002725f <snprintf>
      thread_create (name, priority, priority_condvar_thread, NULL);
c002c121:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c128:	00 
c002c129:	c7 44 24 08 22 c0 02 	movl   $0xc002c022,0x8(%esp)
c002c130:	c0 
c002c131:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c135:	89 3c 24             	mov    %edi,(%esp)
c002c138:	e8 45 54 ff ff       	call   c0021582 <thread_create>
c002c13d:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002c140:	83 fb 11             	cmp    $0x11,%ebx
c002c143:	75 a8                	jne    c002c0ed <test_priority_condvar+0x6e>
c002c145:	b3 0a                	mov    $0xa,%bl
      lock_acquire (&lock);
c002c147:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c14e:	e8 57 6d ff ff       	call   c0022eaa <lock_acquire>
      msg ("Signaling...");
c002c153:	c7 04 24 e4 0c 03 c0 	movl   $0xc0030ce4,(%esp)
c002c15a:	e8 0e e6 ff ff       	call   c002a76d <msg>
      cond_signal (&condition, &lock);
c002c15f:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c166:	c0 
c002c167:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c16e:	e8 66 71 ff ff       	call   c00232d9 <cond_signal>
      lock_release (&lock);
c002c173:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c17a:	e8 f5 6e ff ff       	call   c0023074 <lock_release>
  for (i = 0; i < 10; i++) 
c002c17f:	83 eb 01             	sub    $0x1,%ebx
c002c182:	75 c3                	jne    c002c147 <test_priority_condvar+0xc8>
}
c002c184:	83 c4 3c             	add    $0x3c,%esp
c002c187:	5b                   	pop    %ebx
c002c188:	5e                   	pop    %esi
c002c189:	5f                   	pop    %edi
c002c18a:	5d                   	pop    %ebp
c002c18b:	c3                   	ret    

c002c18c <interloper_thread_func>:
                                         thread_get_priority ());
}

static void
interloper_thread_func (void *arg_ UNUSED)
{
c002c18c:	83 ec 1c             	sub    $0x1c,%esp
  msg ("%s finished.", thread_name ());
c002c18f:	e8 5c 4d ff ff       	call   c0020ef0 <thread_name>
c002c194:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c198:	c7 04 24 1b 0d 03 c0 	movl   $0xc0030d1b,(%esp)
c002c19f:	e8 c9 e5 ff ff       	call   c002a76d <msg>
}
c002c1a4:	83 c4 1c             	add    $0x1c,%esp
c002c1a7:	c3                   	ret    

c002c1a8 <donor_thread_func>:
{
c002c1a8:	56                   	push   %esi
c002c1a9:	53                   	push   %ebx
c002c1aa:	83 ec 14             	sub    $0x14,%esp
c002c1ad:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (locks->first)
c002c1b1:	8b 43 04             	mov    0x4(%ebx),%eax
c002c1b4:	85 c0                	test   %eax,%eax
c002c1b6:	74 08                	je     c002c1c0 <donor_thread_func+0x18>
    lock_acquire (locks->first);
c002c1b8:	89 04 24             	mov    %eax,(%esp)
c002c1bb:	e8 ea 6c ff ff       	call   c0022eaa <lock_acquire>
  lock_acquire (locks->second);
c002c1c0:	8b 03                	mov    (%ebx),%eax
c002c1c2:	89 04 24             	mov    %eax,(%esp)
c002c1c5:	e8 e0 6c ff ff       	call   c0022eaa <lock_acquire>
  msg ("%s got lock", thread_name ());
c002c1ca:	e8 21 4d ff ff       	call   c0020ef0 <thread_name>
c002c1cf:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1d3:	c7 04 24 28 0d 03 c0 	movl   $0xc0030d28,(%esp)
c002c1da:	e8 8e e5 ff ff       	call   c002a76d <msg>
  lock_release (locks->second);
c002c1df:	8b 03                	mov    (%ebx),%eax
c002c1e1:	89 04 24             	mov    %eax,(%esp)
c002c1e4:	e8 8b 6e ff ff       	call   c0023074 <lock_release>
  msg ("%s should have priority %d. Actual priority: %d", 
c002c1e9:	e8 9f 4d ff ff       	call   c0020f8d <thread_get_priority>
c002c1ee:	89 c6                	mov    %eax,%esi
c002c1f0:	e8 fb 4c ff ff       	call   c0020ef0 <thread_name>
c002c1f5:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c1f9:	c7 44 24 08 15 00 00 	movl   $0x15,0x8(%esp)
c002c200:	00 
c002c201:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c205:	c7 04 24 50 0d 03 c0 	movl   $0xc0030d50,(%esp)
c002c20c:	e8 5c e5 ff ff       	call   c002a76d <msg>
  if (locks->first)
c002c211:	8b 43 04             	mov    0x4(%ebx),%eax
c002c214:	85 c0                	test   %eax,%eax
c002c216:	74 08                	je     c002c220 <donor_thread_func+0x78>
    lock_release (locks->first);
c002c218:	89 04 24             	mov    %eax,(%esp)
c002c21b:	e8 54 6e ff ff       	call   c0023074 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c220:	e8 68 4d ff ff       	call   c0020f8d <thread_get_priority>
c002c225:	89 c3                	mov    %eax,%ebx
c002c227:	e8 c4 4c ff ff       	call   c0020ef0 <thread_name>
c002c22c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c230:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c234:	c7 04 24 80 0d 03 c0 	movl   $0xc0030d80,(%esp)
c002c23b:	e8 2d e5 ff ff       	call   c002a76d <msg>
}
c002c240:	83 c4 14             	add    $0x14,%esp
c002c243:	5b                   	pop    %ebx
c002c244:	5e                   	pop    %esi
c002c245:	c3                   	ret    

c002c246 <test_priority_donate_chain>:
{
c002c246:	55                   	push   %ebp
c002c247:	57                   	push   %edi
c002c248:	56                   	push   %esi
c002c249:	53                   	push   %ebx
c002c24a:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
  ASSERT (!thread_mlfqs);
c002c250:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c257:	74 2c                	je     c002c285 <test_priority_donate_chain+0x3f>
c002c259:	c7 44 24 10 3c 01 03 	movl   $0xc003013c,0x10(%esp)
c002c260:	c0 
c002c261:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c268:	c0 
c002c269:	c7 44 24 08 b0 e0 02 	movl   $0xc002e0b0,0x8(%esp)
c002c270:	c0 
c002c271:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c002c278:	00 
c002c279:	c7 04 24 a0 0d 03 c0 	movl   $0xc0030da0,(%esp)
c002c280:	e8 2e c7 ff ff       	call   c00289b3 <debug_panic>
  thread_set_priority (PRI_MIN);
c002c285:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c28c:	e8 5f 54 ff ff       	call   c00216f0 <thread_set_priority>
c002c291:	8d 5c 24 74          	lea    0x74(%esp),%ebx
c002c295:	8d b4 24 70 01 00 00 	lea    0x170(%esp),%esi
    lock_init (&locks[i]);
c002c29c:	89 1c 24             	mov    %ebx,(%esp)
c002c29f:	e8 69 6b ff ff       	call   c0022e0d <lock_init>
c002c2a4:	83 c3 24             	add    $0x24,%ebx
  for (i = 0; i < NESTING_DEPTH - 1; i++)
c002c2a7:	39 f3                	cmp    %esi,%ebx
c002c2a9:	75 f1                	jne    c002c29c <test_priority_donate_chain+0x56>
  lock_acquire (&locks[0]);
c002c2ab:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c2af:	89 04 24             	mov    %eax,(%esp)
c002c2b2:	e8 f3 6b ff ff       	call   c0022eaa <lock_acquire>
  msg ("%s got lock.", thread_name ());
c002c2b7:	e8 34 4c ff ff       	call   c0020ef0 <thread_name>
c002c2bc:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c2c0:	c7 04 24 34 0d 03 c0 	movl   $0xc0030d34,(%esp)
c002c2c7:	e8 a1 e4 ff ff       	call   c002a76d <msg>
c002c2cc:	8d 84 24 98 00 00 00 	lea    0x98(%esp),%eax
c002c2d3:	89 44 24 14          	mov    %eax,0x14(%esp)
c002c2d7:	8d 74 24 40          	lea    0x40(%esp),%esi
c002c2db:	bf 03 00 00 00       	mov    $0x3,%edi
  for (i = 1; i < NESTING_DEPTH; i++)
c002c2e0:	bb 01 00 00 00       	mov    $0x1,%ebx
      snprintf (name, sizeof name, "thread %d", i);
c002c2e5:	8d 6c 24 24          	lea    0x24(%esp),%ebp
c002c2e9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c2ed:	c7 44 24 08 59 01 03 	movl   $0xc0030159,0x8(%esp)
c002c2f4:	c0 
c002c2f5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c2fc:	00 
c002c2fd:	89 2c 24             	mov    %ebp,(%esp)
c002c300:	e8 5a af ff ff       	call   c002725f <snprintf>
      lock_pairs[i].first = i < NESTING_DEPTH - 1 ? locks + i: NULL;
c002c305:	83 fb 06             	cmp    $0x6,%ebx
c002c308:	b8 00 00 00 00       	mov    $0x0,%eax
c002c30d:	8b 54 24 14          	mov    0x14(%esp),%edx
c002c311:	0f 4e c2             	cmovle %edx,%eax
c002c314:	89 06                	mov    %eax,(%esi)
c002c316:	89 d0                	mov    %edx,%eax
c002c318:	83 e8 24             	sub    $0x24,%eax
c002c31b:	89 46 fc             	mov    %eax,-0x4(%esi)
c002c31e:	8d 46 fc             	lea    -0x4(%esi),%eax
      thread_create (name, thread_priority, donor_thread_func, lock_pairs + i);
c002c321:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c325:	c7 44 24 08 a8 c1 02 	movl   $0xc002c1a8,0x8(%esp)
c002c32c:	c0 
c002c32d:	89 7c 24 18          	mov    %edi,0x18(%esp)
c002c331:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c335:	89 2c 24             	mov    %ebp,(%esp)
c002c338:	e8 45 52 ff ff       	call   c0021582 <thread_create>
      msg ("%s should have priority %d.  Actual priority: %d.",
c002c33d:	e8 4b 4c ff ff       	call   c0020f8d <thread_get_priority>
c002c342:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002c346:	e8 a5 4b ff ff       	call   c0020ef0 <thread_name>
c002c34b:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c34f:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002c353:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c002c357:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002c35b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c35f:	c7 04 24 cc 0d 03 c0 	movl   $0xc0030dcc,(%esp)
c002c366:	e8 02 e4 ff ff       	call   c002a76d <msg>
      snprintf (name, sizeof name, "interloper %d", i);
c002c36b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c36f:	c7 44 24 08 41 0d 03 	movl   $0xc0030d41,0x8(%esp)
c002c376:	c0 
c002c377:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c37e:	00 
c002c37f:	89 2c 24             	mov    %ebp,(%esp)
c002c382:	e8 d8 ae ff ff       	call   c002725f <snprintf>
      thread_create (name, thread_priority - 1, interloper_thread_func, NULL);
c002c387:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c38e:	00 
c002c38f:	c7 44 24 08 8c c1 02 	movl   $0xc002c18c,0x8(%esp)
c002c396:	c0 
c002c397:	8d 47 ff             	lea    -0x1(%edi),%eax
c002c39a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c39e:	89 2c 24             	mov    %ebp,(%esp)
c002c3a1:	e8 dc 51 ff ff       	call   c0021582 <thread_create>
  for (i = 1; i < NESTING_DEPTH; i++)
c002c3a6:	83 c3 01             	add    $0x1,%ebx
c002c3a9:	83 44 24 14 24       	addl   $0x24,0x14(%esp)
c002c3ae:	83 c6 08             	add    $0x8,%esi
c002c3b1:	83 c7 03             	add    $0x3,%edi
c002c3b4:	83 fb 08             	cmp    $0x8,%ebx
c002c3b7:	0f 85 2c ff ff ff    	jne    c002c2e9 <test_priority_donate_chain+0xa3>
  lock_release (&locks[0]);
c002c3bd:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c3c1:	89 04 24             	mov    %eax,(%esp)
c002c3c4:	e8 ab 6c ff ff       	call   c0023074 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c3c9:	e8 bf 4b ff ff       	call   c0020f8d <thread_get_priority>
c002c3ce:	89 c3                	mov    %eax,%ebx
c002c3d0:	e8 1b 4b ff ff       	call   c0020ef0 <thread_name>
c002c3d5:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c3d9:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c3dd:	c7 04 24 80 0d 03 c0 	movl   $0xc0030d80,(%esp)
c002c3e4:	e8 84 e3 ff ff       	call   c002a76d <msg>
}
c002c3e9:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002c3ef:	5b                   	pop    %ebx
c002c3f0:	5e                   	pop    %esi
c002c3f1:	5f                   	pop    %edi
c002c3f2:	5d                   	pop    %ebp
c002c3f3:	c3                   	ret    
c002c3f4:	90                   	nop
c002c3f5:	90                   	nop
c002c3f6:	90                   	nop
c002c3f7:	90                   	nop
c002c3f8:	90                   	nop
c002c3f9:	90                   	nop
c002c3fa:	90                   	nop
c002c3fb:	90                   	nop
c002c3fc:	90                   	nop
c002c3fd:	90                   	nop
c002c3fe:	90                   	nop
c002c3ff:	90                   	nop

c002c400 <test_mlfqs_load_1>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_mlfqs_load_1 (void) 
{
c002c400:	57                   	push   %edi
c002c401:	56                   	push   %esi
c002c402:	53                   	push   %ebx
c002c403:	83 ec 20             	sub    $0x20,%esp
  int64_t start_time;
  int elapsed;
  int load_avg;
  
  ASSERT (thread_mlfqs);
c002c406:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c40d:	75 2c                	jne    c002c43b <test_mlfqs_load_1+0x3b>
c002c40f:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002c416:	c0 
c002c417:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c41e:	c0 
c002c41f:	c7 44 24 08 cb e0 02 	movl   $0xc002e0cb,0x8(%esp)
c002c426:	c0 
c002c427:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002c42e:	00 
c002c42f:	c7 04 24 28 0e 03 c0 	movl   $0xc0030e28,(%esp)
c002c436:	e8 78 c5 ff ff       	call   c00289b3 <debug_panic>

  msg ("spinning for up to 45 seconds, please wait...");
c002c43b:	c7 04 24 4c 0e 03 c0 	movl   $0xc0030e4c,(%esp)
c002c442:	e8 26 e3 ff ff       	call   c002a76d <msg>

  start_time = timer_ticks ();
c002c447:	e8 f8 7d ff ff       	call   c0024244 <timer_ticks>
c002c44c:	89 44 24 18          	mov    %eax,0x18(%esp)
c002c450:	89 54 24 1c          	mov    %edx,0x1c(%esp)
    {
      load_avg = thread_get_load_avg ();
      ASSERT (load_avg >= 0);
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
      if (load_avg > 100)
        fail ("load average is %d.%02d "
c002c454:	bf 1f 85 eb 51       	mov    $0x51eb851f,%edi
      load_avg = thread_get_load_avg ();
c002c459:	e8 4d 4b ff ff       	call   c0020fab <thread_get_load_avg>
c002c45e:	89 c3                	mov    %eax,%ebx
      ASSERT (load_avg >= 0);
c002c460:	85 c0                	test   %eax,%eax
c002c462:	79 2c                	jns    c002c490 <test_mlfqs_load_1+0x90>
c002c464:	c7 44 24 10 fe 0d 03 	movl   $0xc0030dfe,0x10(%esp)
c002c46b:	c0 
c002c46c:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c473:	c0 
c002c474:	c7 44 24 08 cb e0 02 	movl   $0xc002e0cb,0x8(%esp)
c002c47b:	c0 
c002c47c:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002c483:	00 
c002c484:	c7 04 24 28 0e 03 c0 	movl   $0xc0030e28,(%esp)
c002c48b:	e8 23 c5 ff ff       	call   c00289b3 <debug_panic>
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
c002c490:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c494:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c498:	89 04 24             	mov    %eax,(%esp)
c002c49b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c49f:	e8 cc 7d ff ff       	call   c0024270 <timer_elapsed>
c002c4a4:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c4ab:	00 
c002c4ac:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c4b3:	00 
c002c4b4:	89 04 24             	mov    %eax,(%esp)
c002c4b7:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c4bb:	e8 53 be ff ff       	call   c0028313 <__divdi3>
c002c4c0:	89 c6                	mov    %eax,%esi
      if (load_avg > 100)
c002c4c2:	83 fb 64             	cmp    $0x64,%ebx
c002c4c5:	7e 30                	jle    c002c4f7 <test_mlfqs_load_1+0xf7>
        fail ("load average is %d.%02d "
c002c4c7:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c4cb:	89 d8                	mov    %ebx,%eax
c002c4cd:	f7 ef                	imul   %edi
c002c4cf:	c1 fa 05             	sar    $0x5,%edx
c002c4d2:	89 d8                	mov    %ebx,%eax
c002c4d4:	c1 f8 1f             	sar    $0x1f,%eax
c002c4d7:	29 c2                	sub    %eax,%edx
c002c4d9:	6b c2 64             	imul   $0x64,%edx,%eax
c002c4dc:	29 c3                	sub    %eax,%ebx
c002c4de:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c4e2:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c4e6:	c7 04 24 7c 0e 03 c0 	movl   $0xc0030e7c,(%esp)
c002c4ed:	e8 33 e3 ff ff       	call   c002a825 <fail>
c002c4f2:	e9 62 ff ff ff       	jmp    c002c459 <test_mlfqs_load_1+0x59>
              "but should be between 0 and 1 (after %d seconds)",
              load_avg / 100, load_avg % 100, elapsed);
      else if (load_avg > 50)
c002c4f7:	83 fb 32             	cmp    $0x32,%ebx
c002c4fa:	7f 1b                	jg     c002c517 <test_mlfqs_load_1+0x117>
        break;
      else if (elapsed > 45)
c002c4fc:	83 f8 2d             	cmp    $0x2d,%eax
c002c4ff:	90                   	nop
c002c500:	0f 8e 53 ff ff ff    	jle    c002c459 <test_mlfqs_load_1+0x59>
        fail ("load average stayed below 0.5 for more than 45 seconds");
c002c506:	c7 04 24 c8 0e 03 c0 	movl   $0xc0030ec8,(%esp)
c002c50d:	e8 13 e3 ff ff       	call   c002a825 <fail>
c002c512:	e9 42 ff ff ff       	jmp    c002c459 <test_mlfqs_load_1+0x59>
    }

  if (elapsed < 38)
c002c517:	83 f8 25             	cmp    $0x25,%eax
c002c51a:	7f 10                	jg     c002c52c <test_mlfqs_load_1+0x12c>
    fail ("load average took only %d seconds to rise above 0.5", elapsed);
c002c51c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c520:	c7 04 24 00 0f 03 c0 	movl   $0xc0030f00,(%esp)
c002c527:	e8 f9 e2 ff ff       	call   c002a825 <fail>
  msg ("load average rose to 0.5 after %d seconds", elapsed);
c002c52c:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c530:	c7 04 24 34 0f 03 c0 	movl   $0xc0030f34,(%esp)
c002c537:	e8 31 e2 ff ff       	call   c002a76d <msg>

  msg ("sleeping for another 10 seconds, please wait...");
c002c53c:	c7 04 24 60 0f 03 c0 	movl   $0xc0030f60,(%esp)
c002c543:	e8 25 e2 ff ff       	call   c002a76d <msg>
  timer_sleep (TIMER_FREQ * 10);
c002c548:	c7 04 24 e8 03 00 00 	movl   $0x3e8,(%esp)
c002c54f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002c556:	00 
c002c557:	e8 30 7d ff ff       	call   c002428c <timer_sleep>

  load_avg = thread_get_load_avg ();
c002c55c:	e8 4a 4a ff ff       	call   c0020fab <thread_get_load_avg>
c002c561:	89 c3                	mov    %eax,%ebx
  if (load_avg < 0)
c002c563:	85 c0                	test   %eax,%eax
c002c565:	79 0c                	jns    c002c573 <test_mlfqs_load_1+0x173>
    fail ("load average fell below 0");
c002c567:	c7 04 24 0c 0e 03 c0 	movl   $0xc0030e0c,(%esp)
c002c56e:	e8 b2 e2 ff ff       	call   c002a825 <fail>
  if (load_avg > 50)
c002c573:	83 fb 32             	cmp    $0x32,%ebx
c002c576:	7e 0c                	jle    c002c584 <test_mlfqs_load_1+0x184>
    fail ("load average stayed above 0.5 for more than 10 seconds");
c002c578:	c7 04 24 90 0f 03 c0 	movl   $0xc0030f90,(%esp)
c002c57f:	e8 a1 e2 ff ff       	call   c002a825 <fail>
  msg ("load average fell back below 0.5 (to %d.%02d)",
c002c584:	ba 1f 85 eb 51       	mov    $0x51eb851f,%edx
c002c589:	89 d8                	mov    %ebx,%eax
c002c58b:	f7 ea                	imul   %edx
c002c58d:	c1 fa 05             	sar    $0x5,%edx
c002c590:	89 d8                	mov    %ebx,%eax
c002c592:	c1 f8 1f             	sar    $0x1f,%eax
c002c595:	29 c2                	sub    %eax,%edx
c002c597:	6b c2 64             	imul   $0x64,%edx,%eax
c002c59a:	29 c3                	sub    %eax,%ebx
c002c59c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c5a0:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5a4:	c7 04 24 c8 0f 03 c0 	movl   $0xc0030fc8,(%esp)
c002c5ab:	e8 bd e1 ff ff       	call   c002a76d <msg>
       load_avg / 100, load_avg % 100);

  pass ();
c002c5b0:	e8 cc e2 ff ff       	call   c002a881 <pass>
}
c002c5b5:	83 c4 20             	add    $0x20,%esp
c002c5b8:	5b                   	pop    %ebx
c002c5b9:	5e                   	pop    %esi
c002c5ba:	5f                   	pop    %edi
c002c5bb:	c3                   	ret    
c002c5bc:	90                   	nop
c002c5bd:	90                   	nop
c002c5be:	90                   	nop
c002c5bf:	90                   	nop

c002c5c0 <load_thread>:
    }
}

static void
load_thread (void *aux UNUSED) 
{
c002c5c0:	53                   	push   %ebx
c002c5c1:	83 ec 18             	sub    $0x18,%esp
  int64_t sleep_time = 10 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 60 * TIMER_FREQ;
  int64_t exit_time = spin_time + 60 * TIMER_FREQ;

  thread_set_nice (20);
c002c5c4:	c7 04 24 14 00 00 00 	movl   $0x14,(%esp)
c002c5cb:	e8 d8 51 ff ff       	call   c00217a8 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c5d0:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5d5:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5db:	89 04 24             	mov    %eax,(%esp)
c002c5de:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5e2:	e8 89 7c ff ff       	call   c0024270 <timer_elapsed>
c002c5e7:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002c5ec:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c5f1:	29 c1                	sub    %eax,%ecx
c002c5f3:	19 d3                	sbb    %edx,%ebx
c002c5f5:	89 0c 24             	mov    %ecx,(%esp)
c002c5f8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c5fc:	e8 8b 7c ff ff       	call   c002428c <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c601:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c606:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c60c:	89 04 24             	mov    %eax,(%esp)
c002c60f:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c613:	e8 58 7c ff ff       	call   c0024270 <timer_elapsed>
c002c618:	85 d2                	test   %edx,%edx
c002c61a:	7f 0b                	jg     c002c627 <load_thread+0x67>
c002c61c:	85 d2                	test   %edx,%edx
c002c61e:	78 e1                	js     c002c601 <load_thread+0x41>
c002c620:	3d 57 1b 00 00       	cmp    $0x1b57,%eax
c002c625:	76 da                	jbe    c002c601 <load_thread+0x41>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c627:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c62c:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c632:	89 04 24             	mov    %eax,(%esp)
c002c635:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c639:	e8 32 7c ff ff       	call   c0024270 <timer_elapsed>
c002c63e:	b9 c8 32 00 00       	mov    $0x32c8,%ecx
c002c643:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c648:	29 c1                	sub    %eax,%ecx
c002c64a:	19 d3                	sbb    %edx,%ebx
c002c64c:	89 0c 24             	mov    %ecx,(%esp)
c002c64f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c653:	e8 34 7c ff ff       	call   c002428c <timer_sleep>
}
c002c658:	83 c4 18             	add    $0x18,%esp
c002c65b:	5b                   	pop    %ebx
c002c65c:	c3                   	ret    

c002c65d <test_mlfqs_load_60>:
{
c002c65d:	55                   	push   %ebp
c002c65e:	57                   	push   %edi
c002c65f:	56                   	push   %esi
c002c660:	53                   	push   %ebx
c002c661:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c664:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c66b:	75 2c                	jne    c002c699 <test_mlfqs_load_60+0x3c>
c002c66d:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002c674:	c0 
c002c675:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c67c:	c0 
c002c67d:	c7 44 24 08 dd e0 02 	movl   $0xc002e0dd,0x8(%esp)
c002c684:	c0 
c002c685:	c7 44 24 04 77 00 00 	movl   $0x77,0x4(%esp)
c002c68c:	00 
c002c68d:	c7 04 24 00 10 03 c0 	movl   $0xc0031000,(%esp)
c002c694:	e8 1a c3 ff ff       	call   c00289b3 <debug_panic>
  start_time = timer_ticks ();
c002c699:	e8 a6 7b ff ff       	call   c0024244 <timer_ticks>
c002c69e:	a3 a8 7b 03 c0       	mov    %eax,0xc0037ba8
c002c6a3:	89 15 ac 7b 03 c0    	mov    %edx,0xc0037bac
  msg ("Starting %d niced load threads...", THREAD_CNT);
c002c6a9:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c6b0:	00 
c002c6b1:	c7 04 24 24 10 03 c0 	movl   $0xc0031024,(%esp)
c002c6b8:	e8 b0 e0 ff ff       	call   c002a76d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c6bd:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c6c2:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c6c6:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c6ca:	c7 44 24 08 f6 0f 03 	movl   $0xc0030ff6,0x8(%esp)
c002c6d1:	c0 
c002c6d2:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c6d9:	00 
c002c6da:	89 34 24             	mov    %esi,(%esp)
c002c6dd:	e8 7d ab ff ff       	call   c002725f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, NULL);
c002c6e2:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c6e9:	00 
c002c6ea:	c7 44 24 08 c0 c5 02 	movl   $0xc002c5c0,0x8(%esp)
c002c6f1:	c0 
c002c6f2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c6f9:	00 
c002c6fa:	89 34 24             	mov    %esi,(%esp)
c002c6fd:	e8 80 4e ff ff       	call   c0021582 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c702:	83 c3 01             	add    $0x1,%ebx
c002c705:	83 fb 3c             	cmp    $0x3c,%ebx
c002c708:	75 bc                	jne    c002c6c6 <test_mlfqs_load_60+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c70a:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c70f:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c715:	89 04 24             	mov    %eax,(%esp)
c002c718:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c71c:	e8 4f 7b ff ff       	call   c0024270 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c721:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c728:	00 
c002c729:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c730:	00 
c002c731:	89 04 24             	mov    %eax,(%esp)
c002c734:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c738:	e8 d6 bb ff ff       	call   c0028313 <__divdi3>
c002c73d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c741:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c745:	c7 04 24 48 10 03 c0 	movl   $0xc0031048,(%esp)
c002c74c:	e8 1c e0 ff ff       	call   c002a76d <msg>
c002c751:	b3 00                	mov    $0x0,%bl
c002c753:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c758:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c75d:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c762:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c766:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c76a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c76e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c772:	03 05 a8 7b 03 c0    	add    0xc0037ba8,%eax
c002c778:	13 15 ac 7b 03 c0    	adc    0xc0037bac,%edx
c002c77e:	89 c6                	mov    %eax,%esi
c002c780:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c782:	e8 bd 7a ff ff       	call   c0024244 <timer_ticks>
c002c787:	29 c6                	sub    %eax,%esi
c002c789:	19 d7                	sbb    %edx,%edi
c002c78b:	89 34 24             	mov    %esi,(%esp)
c002c78e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c792:	e8 f5 7a ff ff       	call   c002428c <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c797:	e8 0f 48 ff ff       	call   c0020fab <thread_get_load_avg>
c002c79c:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c79e:	f7 ed                	imul   %ebp
c002c7a0:	c1 fa 05             	sar    $0x5,%edx
c002c7a3:	89 c8                	mov    %ecx,%eax
c002c7a5:	c1 f8 1f             	sar    $0x1f,%eax
c002c7a8:	29 c2                	sub    %eax,%edx
c002c7aa:	6b c2 64             	imul   $0x64,%edx,%eax
c002c7ad:	29 c1                	sub    %eax,%ecx
c002c7af:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c7b3:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c7b7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c7bb:	c7 04 24 6c 10 03 c0 	movl   $0xc003106c,(%esp)
c002c7c2:	e8 a6 df ff ff       	call   c002a76d <msg>
c002c7c7:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c7ce:	00 
c002c7cf:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c7d4:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c7d7:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c7dd:	75 8b                	jne    c002c76a <test_mlfqs_load_60+0x10d>
}
c002c7df:	83 c4 3c             	add    $0x3c,%esp
c002c7e2:	5b                   	pop    %ebx
c002c7e3:	5e                   	pop    %esi
c002c7e4:	5f                   	pop    %edi
c002c7e5:	5d                   	pop    %ebp
c002c7e6:	c3                   	ret    
c002c7e7:	90                   	nop
c002c7e8:	90                   	nop
c002c7e9:	90                   	nop
c002c7ea:	90                   	nop
c002c7eb:	90                   	nop
c002c7ec:	90                   	nop
c002c7ed:	90                   	nop
c002c7ee:	90                   	nop
c002c7ef:	90                   	nop

c002c7f0 <load_thread>:
    }
}

static void
load_thread (void *seq_no_) 
{
c002c7f0:	57                   	push   %edi
c002c7f1:	56                   	push   %esi
c002c7f2:	53                   	push   %ebx
c002c7f3:	83 ec 10             	sub    $0x10,%esp
  int seq_no = (int) seq_no_;
  int sleep_time = TIMER_FREQ * (10 + seq_no);
c002c7f6:	8b 44 24 20          	mov    0x20(%esp),%eax
c002c7fa:	8d 70 0a             	lea    0xa(%eax),%esi
c002c7fd:	6b f6 64             	imul   $0x64,%esi,%esi
  int spin_time = sleep_time + TIMER_FREQ * THREAD_CNT;
c002c800:	8d 9e 70 17 00 00    	lea    0x1770(%esi),%ebx
  int exit_time = TIMER_FREQ * (THREAD_CNT * 2);

  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c806:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c80b:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c811:	89 04 24             	mov    %eax,(%esp)
c002c814:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c818:	e8 53 7a ff ff       	call   c0024270 <timer_elapsed>
c002c81d:	89 f7                	mov    %esi,%edi
c002c81f:	c1 ff 1f             	sar    $0x1f,%edi
c002c822:	29 c6                	sub    %eax,%esi
c002c824:	19 d7                	sbb    %edx,%edi
c002c826:	89 34 24             	mov    %esi,(%esp)
c002c829:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c82d:	e8 5a 7a ff ff       	call   c002428c <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c832:	89 df                	mov    %ebx,%edi
c002c834:	c1 ff 1f             	sar    $0x1f,%edi
c002c837:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c83c:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c842:	89 04 24             	mov    %eax,(%esp)
c002c845:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c849:	e8 22 7a ff ff       	call   c0024270 <timer_elapsed>
c002c84e:	39 fa                	cmp    %edi,%edx
c002c850:	7f 06                	jg     c002c858 <load_thread+0x68>
c002c852:	7c e3                	jl     c002c837 <load_thread+0x47>
c002c854:	39 d8                	cmp    %ebx,%eax
c002c856:	72 df                	jb     c002c837 <load_thread+0x47>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c858:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c85d:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c863:	89 04 24             	mov    %eax,(%esp)
c002c866:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c86a:	e8 01 7a ff ff       	call   c0024270 <timer_elapsed>
c002c86f:	b9 e0 2e 00 00       	mov    $0x2ee0,%ecx
c002c874:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c879:	29 c1                	sub    %eax,%ecx
c002c87b:	19 d3                	sbb    %edx,%ebx
c002c87d:	89 0c 24             	mov    %ecx,(%esp)
c002c880:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c884:	e8 03 7a ff ff       	call   c002428c <timer_sleep>
}
c002c889:	83 c4 10             	add    $0x10,%esp
c002c88c:	5b                   	pop    %ebx
c002c88d:	5e                   	pop    %esi
c002c88e:	5f                   	pop    %edi
c002c88f:	c3                   	ret    

c002c890 <test_mlfqs_load_avg>:
{
c002c890:	55                   	push   %ebp
c002c891:	57                   	push   %edi
c002c892:	56                   	push   %esi
c002c893:	53                   	push   %ebx
c002c894:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c897:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c89e:	75 2c                	jne    c002c8cc <test_mlfqs_load_avg+0x3c>
c002c8a0:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002c8a7:	c0 
c002c8a8:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002c8af:	c0 
c002c8b0:	c7 44 24 08 f0 e0 02 	movl   $0xc002e0f0,0x8(%esp)
c002c8b7:	c0 
c002c8b8:	c7 44 24 04 82 00 00 	movl   $0x82,0x4(%esp)
c002c8bf:	00 
c002c8c0:	c7 04 24 b0 10 03 c0 	movl   $0xc00310b0,(%esp)
c002c8c7:	e8 e7 c0 ff ff       	call   c00289b3 <debug_panic>
  start_time = timer_ticks ();
c002c8cc:	e8 73 79 ff ff       	call   c0024244 <timer_ticks>
c002c8d1:	a3 b0 7b 03 c0       	mov    %eax,0xc0037bb0
c002c8d6:	89 15 b4 7b 03 c0    	mov    %edx,0xc0037bb4
  msg ("Starting %d load threads...", THREAD_CNT);
c002c8dc:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c8e3:	00 
c002c8e4:	c7 04 24 94 10 03 c0 	movl   $0xc0031094,(%esp)
c002c8eb:	e8 7d de ff ff       	call   c002a76d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c8f0:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c8f5:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c8f9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c8fd:	c7 44 24 08 f6 0f 03 	movl   $0xc0030ff6,0x8(%esp)
c002c904:	c0 
c002c905:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c90c:	00 
c002c90d:	89 34 24             	mov    %esi,(%esp)
c002c910:	e8 4a a9 ff ff       	call   c002725f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, (void *) i);
c002c915:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c919:	c7 44 24 08 f0 c7 02 	movl   $0xc002c7f0,0x8(%esp)
c002c920:	c0 
c002c921:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c928:	00 
c002c929:	89 34 24             	mov    %esi,(%esp)
c002c92c:	e8 51 4c ff ff       	call   c0021582 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c931:	83 c3 01             	add    $0x1,%ebx
c002c934:	83 fb 3c             	cmp    $0x3c,%ebx
c002c937:	75 c0                	jne    c002c8f9 <test_mlfqs_load_avg+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c939:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c93e:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c944:	89 04 24             	mov    %eax,(%esp)
c002c947:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c94b:	e8 20 79 ff ff       	call   c0024270 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c950:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c957:	00 
c002c958:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c95f:	00 
c002c960:	89 04 24             	mov    %eax,(%esp)
c002c963:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c967:	e8 a7 b9 ff ff       	call   c0028313 <__divdi3>
c002c96c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c970:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c974:	c7 04 24 48 10 03 c0 	movl   $0xc0031048,(%esp)
c002c97b:	e8 ed dd ff ff       	call   c002a76d <msg>
  thread_set_nice (-20);
c002c980:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002c987:	e8 1c 4e ff ff       	call   c00217a8 <thread_set_nice>
c002c98c:	b3 00                	mov    $0x0,%bl
c002c98e:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c993:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c998:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c99d:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c9a1:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c9a5:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c9a9:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c9ad:	03 05 b0 7b 03 c0    	add    0xc0037bb0,%eax
c002c9b3:	13 15 b4 7b 03 c0    	adc    0xc0037bb4,%edx
c002c9b9:	89 c6                	mov    %eax,%esi
c002c9bb:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c9bd:	e8 82 78 ff ff       	call   c0024244 <timer_ticks>
c002c9c2:	29 c6                	sub    %eax,%esi
c002c9c4:	19 d7                	sbb    %edx,%edi
c002c9c6:	89 34 24             	mov    %esi,(%esp)
c002c9c9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c9cd:	e8 ba 78 ff ff       	call   c002428c <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c9d2:	e8 d4 45 ff ff       	call   c0020fab <thread_get_load_avg>
c002c9d7:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c9d9:	f7 ed                	imul   %ebp
c002c9db:	c1 fa 05             	sar    $0x5,%edx
c002c9de:	89 c8                	mov    %ecx,%eax
c002c9e0:	c1 f8 1f             	sar    $0x1f,%eax
c002c9e3:	29 c2                	sub    %eax,%edx
c002c9e5:	6b c2 64             	imul   $0x64,%edx,%eax
c002c9e8:	29 c1                	sub    %eax,%ecx
c002c9ea:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c9ee:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c9f2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c9f6:	c7 04 24 6c 10 03 c0 	movl   $0xc003106c,(%esp)
c002c9fd:	e8 6b dd ff ff       	call   c002a76d <msg>
c002ca02:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002ca09:	00 
c002ca0a:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002ca0f:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002ca12:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002ca18:	75 8b                	jne    c002c9a5 <test_mlfqs_load_avg+0x115>
}
c002ca1a:	83 c4 3c             	add    $0x3c,%esp
c002ca1d:	5b                   	pop    %ebx
c002ca1e:	5e                   	pop    %esi
c002ca1f:	5f                   	pop    %edi
c002ca20:	5d                   	pop    %ebp
c002ca21:	c3                   	ret    

c002ca22 <test_mlfqs_recent_1>:
/* Sensitive to assumption that recent_cpu updates happen exactly
   when timer_ticks() % TIMER_FREQ == 0. */

void
test_mlfqs_recent_1 (void) 
{
c002ca22:	55                   	push   %ebp
c002ca23:	57                   	push   %edi
c002ca24:	56                   	push   %esi
c002ca25:	53                   	push   %ebx
c002ca26:	83 ec 2c             	sub    $0x2c,%esp
  int64_t start_time;
  int last_elapsed = 0;
  
  ASSERT (thread_mlfqs);
c002ca29:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002ca30:	75 2c                	jne    c002ca5e <test_mlfqs_recent_1+0x3c>
c002ca32:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002ca39:	c0 
c002ca3a:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002ca41:	c0 
c002ca42:	c7 44 24 08 04 e1 02 	movl   $0xc002e104,0x8(%esp)
c002ca49:	c0 
c002ca4a:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c002ca51:	00 
c002ca52:	c7 04 24 d8 10 03 c0 	movl   $0xc00310d8,(%esp)
c002ca59:	e8 55 bf ff ff       	call   c00289b3 <debug_panic>

  do 
    {
      msg ("Sleeping 10 seconds to allow recent_cpu to decay, please wait...");
c002ca5e:	c7 04 24 00 11 03 c0 	movl   $0xc0031100,(%esp)
c002ca65:	e8 03 dd ff ff       	call   c002a76d <msg>
      start_time = timer_ticks ();
c002ca6a:	e8 d5 77 ff ff       	call   c0024244 <timer_ticks>
c002ca6f:	89 c7                	mov    %eax,%edi
c002ca71:	89 d5                	mov    %edx,%ebp
      timer_sleep (DIV_ROUND_UP (start_time, TIMER_FREQ) - start_time
c002ca73:	83 c0 63             	add    $0x63,%eax
c002ca76:	83 d2 00             	adc    $0x0,%edx
c002ca79:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002ca80:	00 
c002ca81:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002ca88:	00 
c002ca89:	89 04 24             	mov    %eax,(%esp)
c002ca8c:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca90:	e8 7e b8 ff ff       	call   c0028313 <__divdi3>
c002ca95:	29 f8                	sub    %edi,%eax
c002ca97:	19 ea                	sbb    %ebp,%edx
c002ca99:	05 e8 03 00 00       	add    $0x3e8,%eax
c002ca9e:	83 d2 00             	adc    $0x0,%edx
c002caa1:	89 04 24             	mov    %eax,(%esp)
c002caa4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002caa8:	e8 df 77 ff ff       	call   c002428c <timer_sleep>
                   + 10 * TIMER_FREQ);
    }
  while (thread_get_recent_cpu () > 700);
c002caad:	e8 0f 45 ff ff       	call   c0020fc1 <thread_get_recent_cpu>
c002cab2:	3d bc 02 00 00       	cmp    $0x2bc,%eax
c002cab7:	7f a5                	jg     c002ca5e <test_mlfqs_recent_1+0x3c>

  start_time = timer_ticks ();
c002cab9:	e8 86 77 ff ff       	call   c0024244 <timer_ticks>
c002cabe:	89 44 24 18          	mov    %eax,0x18(%esp)
c002cac2:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  int last_elapsed = 0;
c002cac6:	be 00 00 00 00       	mov    $0x0,%esi
  for (;;) 
    {
      int elapsed = timer_elapsed (start_time);
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002cacb:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002cad0:	eb 02                	jmp    c002cad4 <test_mlfqs_recent_1+0xb2>
c002cad2:	89 de                	mov    %ebx,%esi
      int elapsed = timer_elapsed (start_time);
c002cad4:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cad8:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cadc:	89 04 24             	mov    %eax,(%esp)
c002cadf:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cae3:	e8 88 77 ff ff       	call   c0024270 <timer_elapsed>
c002cae8:	89 c3                	mov    %eax,%ebx
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002caea:	f7 ed                	imul   %ebp
c002caec:	c1 fa 06             	sar    $0x6,%edx
c002caef:	89 d8                	mov    %ebx,%eax
c002caf1:	c1 f8 1f             	sar    $0x1f,%eax
c002caf4:	29 c2                	sub    %eax,%edx
c002caf6:	69 d2 c8 00 00 00    	imul   $0xc8,%edx,%edx
c002cafc:	39 d3                	cmp    %edx,%ebx
c002cafe:	75 d2                	jne    c002cad2 <test_mlfqs_recent_1+0xb0>
c002cb00:	39 de                	cmp    %ebx,%esi
c002cb02:	7d ce                	jge    c002cad2 <test_mlfqs_recent_1+0xb0>
        {
          int recent_cpu = thread_get_recent_cpu ();
c002cb04:	e8 b8 44 ff ff       	call   c0020fc1 <thread_get_recent_cpu>
c002cb09:	89 c6                	mov    %eax,%esi
          int load_avg = thread_get_load_avg ();
c002cb0b:	e8 9b 44 ff ff       	call   c0020fab <thread_get_load_avg>
c002cb10:	89 c1                	mov    %eax,%ecx
          int elapsed_seconds = elapsed / TIMER_FREQ;
c002cb12:	89 d8                	mov    %ebx,%eax
c002cb14:	f7 ed                	imul   %ebp
c002cb16:	89 d7                	mov    %edx,%edi
c002cb18:	c1 ff 05             	sar    $0x5,%edi
c002cb1b:	89 d8                	mov    %ebx,%eax
c002cb1d:	c1 f8 1f             	sar    $0x1f,%eax
c002cb20:	29 c7                	sub    %eax,%edi
          msg ("After %d seconds, recent_cpu is %d.%02d, load_avg is %d.%02d.",
c002cb22:	89 c8                	mov    %ecx,%eax
c002cb24:	f7 ed                	imul   %ebp
c002cb26:	c1 fa 05             	sar    $0x5,%edx
c002cb29:	89 c8                	mov    %ecx,%eax
c002cb2b:	c1 f8 1f             	sar    $0x1f,%eax
c002cb2e:	29 c2                	sub    %eax,%edx
c002cb30:	6b c2 64             	imul   $0x64,%edx,%eax
c002cb33:	29 c1                	sub    %eax,%ecx
c002cb35:	89 4c 24 14          	mov    %ecx,0x14(%esp)
c002cb39:	89 54 24 10          	mov    %edx,0x10(%esp)
c002cb3d:	89 f0                	mov    %esi,%eax
c002cb3f:	f7 ed                	imul   %ebp
c002cb41:	c1 fa 05             	sar    $0x5,%edx
c002cb44:	89 f0                	mov    %esi,%eax
c002cb46:	c1 f8 1f             	sar    $0x1f,%eax
c002cb49:	29 c2                	sub    %eax,%edx
c002cb4b:	6b c2 64             	imul   $0x64,%edx,%eax
c002cb4e:	29 c6                	sub    %eax,%esi
c002cb50:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002cb54:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cb58:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002cb5c:	c7 04 24 44 11 03 c0 	movl   $0xc0031144,(%esp)
c002cb63:	e8 05 dc ff ff       	call   c002a76d <msg>
               elapsed_seconds,
               recent_cpu / 100, recent_cpu % 100,
               load_avg / 100, load_avg % 100);
          if (elapsed_seconds >= 180)
c002cb68:	81 ff b3 00 00 00    	cmp    $0xb3,%edi
c002cb6e:	0f 8e 5e ff ff ff    	jle    c002cad2 <test_mlfqs_recent_1+0xb0>
            break;
        } 
      last_elapsed = elapsed;
    }
}
c002cb74:	83 c4 2c             	add    $0x2c,%esp
c002cb77:	5b                   	pop    %ebx
c002cb78:	5e                   	pop    %esi
c002cb79:	5f                   	pop    %edi
c002cb7a:	5d                   	pop    %ebp
c002cb7b:	c3                   	ret    
c002cb7c:	90                   	nop
c002cb7d:	90                   	nop
c002cb7e:	90                   	nop
c002cb7f:	90                   	nop

c002cb80 <test_mlfqs_fair>:

static void load_thread (void *aux);

static void
test_mlfqs_fair (int thread_cnt, int nice_min, int nice_step)
{
c002cb80:	55                   	push   %ebp
c002cb81:	57                   	push   %edi
c002cb82:	56                   	push   %esi
c002cb83:	53                   	push   %ebx
c002cb84:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
c002cb8a:	89 4c 24 14          	mov    %ecx,0x14(%esp)
  struct thread_info info[MAX_THREAD_CNT];
  int64_t start_time;
  int nice;
  int i;

  ASSERT (thread_mlfqs);
c002cb8e:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002cb95:	75 2c                	jne    c002cbc3 <test_mlfqs_fair+0x43>
c002cb97:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002cb9e:	c0 
c002cb9f:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cba6:	c0 
c002cba7:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cbae:	c0 
c002cbaf:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
c002cbb6:	00 
c002cbb7:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cbbe:	e8 f0 bd ff ff       	call   c00289b3 <debug_panic>
c002cbc3:	89 c5                	mov    %eax,%ebp
c002cbc5:	89 d7                	mov    %edx,%edi
  ASSERT (thread_cnt <= MAX_THREAD_CNT);
c002cbc7:	83 f8 14             	cmp    $0x14,%eax
c002cbca:	7e 2c                	jle    c002cbf8 <test_mlfqs_fair+0x78>
c002cbcc:	c7 44 24 10 82 11 03 	movl   $0xc0031182,0x10(%esp)
c002cbd3:	c0 
c002cbd4:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cbdb:	c0 
c002cbdc:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cbe3:	c0 
c002cbe4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c002cbeb:	00 
c002cbec:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cbf3:	e8 bb bd ff ff       	call   c00289b3 <debug_panic>
  ASSERT (nice_min >= -10);
c002cbf8:	83 fa f6             	cmp    $0xfffffff6,%edx
c002cbfb:	7d 2c                	jge    c002cc29 <test_mlfqs_fair+0xa9>
c002cbfd:	c7 44 24 10 9f 11 03 	movl   $0xc003119f,0x10(%esp)
c002cc04:	c0 
c002cc05:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cc0c:	c0 
c002cc0d:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cc14:	c0 
c002cc15:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002cc1c:	00 
c002cc1d:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cc24:	e8 8a bd ff ff       	call   c00289b3 <debug_panic>
  ASSERT (nice_step >= 0);
c002cc29:	83 7c 24 14 00       	cmpl   $0x0,0x14(%esp)
c002cc2e:	79 2c                	jns    c002cc5c <test_mlfqs_fair+0xdc>
c002cc30:	c7 44 24 10 af 11 03 	movl   $0xc00311af,0x10(%esp)
c002cc37:	c0 
c002cc38:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cc3f:	c0 
c002cc40:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cc47:	c0 
c002cc48:	c7 44 24 04 4c 00 00 	movl   $0x4c,0x4(%esp)
c002cc4f:	00 
c002cc50:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cc57:	e8 57 bd ff ff       	call   c00289b3 <debug_panic>
  ASSERT (nice_min + nice_step * (thread_cnt - 1) <= 20);
c002cc5c:	8d 40 ff             	lea    -0x1(%eax),%eax
c002cc5f:	0f af 44 24 14       	imul   0x14(%esp),%eax
c002cc64:	01 d0                	add    %edx,%eax
c002cc66:	83 f8 14             	cmp    $0x14,%eax
c002cc69:	7e 2c                	jle    c002cc97 <test_mlfqs_fair+0x117>
c002cc6b:	c7 44 24 10 18 12 03 	movl   $0xc0031218,0x10(%esp)
c002cc72:	c0 
c002cc73:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cc7a:	c0 
c002cc7b:	c7 44 24 08 18 e1 02 	movl   $0xc002e118,0x8(%esp)
c002cc82:	c0 
c002cc83:	c7 44 24 04 4d 00 00 	movl   $0x4d,0x4(%esp)
c002cc8a:	00 
c002cc8b:	c7 04 24 f4 11 03 c0 	movl   $0xc00311f4,(%esp)
c002cc92:	e8 1c bd ff ff       	call   c00289b3 <debug_panic>

  thread_set_nice (-20);
c002cc97:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002cc9e:	e8 05 4b ff ff       	call   c00217a8 <thread_set_nice>

  start_time = timer_ticks ();
c002cca3:	e8 9c 75 ff ff       	call   c0024244 <timer_ticks>
c002cca8:	89 44 24 18          	mov    %eax,0x18(%esp)
c002ccac:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  msg ("Starting %d threads...", thread_cnt);
c002ccb0:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002ccb4:	c7 04 24 be 11 03 c0 	movl   $0xc00311be,(%esp)
c002ccbb:	e8 ad da ff ff       	call   c002a76d <msg>
  nice = nice_min;
  for (i = 0; i < thread_cnt; i++) 
c002ccc0:	85 ed                	test   %ebp,%ebp
c002ccc2:	0f 8e e1 00 00 00    	jle    c002cda9 <test_mlfqs_fair+0x229>
c002ccc8:	8d 5c 24 30          	lea    0x30(%esp),%ebx
c002cccc:	be 00 00 00 00       	mov    $0x0,%esi
    {
      struct thread_info *ti = &info[i];
      char name[16];

      ti->start_time = start_time;
c002ccd1:	8b 44 24 18          	mov    0x18(%esp),%eax
c002ccd5:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002ccd9:	89 03                	mov    %eax,(%ebx)
c002ccdb:	89 53 04             	mov    %edx,0x4(%ebx)
      ti->tick_count = 0;
c002ccde:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
      ti->nice = nice;
c002cce5:	89 7b 0c             	mov    %edi,0xc(%ebx)

      snprintf(name, sizeof name, "load %d", i);
c002cce8:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ccec:	c7 44 24 08 f6 0f 03 	movl   $0xc0030ff6,0x8(%esp)
c002ccf3:	c0 
c002ccf4:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002ccfb:	00 
c002ccfc:	8d 44 24 20          	lea    0x20(%esp),%eax
c002cd00:	89 04 24             	mov    %eax,(%esp)
c002cd03:	e8 57 a5 ff ff       	call   c002725f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, ti);
c002cd08:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cd0c:	c7 44 24 08 fc cd 02 	movl   $0xc002cdfc,0x8(%esp)
c002cd13:	c0 
c002cd14:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cd1b:	00 
c002cd1c:	8d 44 24 20          	lea    0x20(%esp),%eax
c002cd20:	89 04 24             	mov    %eax,(%esp)
c002cd23:	e8 5a 48 ff ff       	call   c0021582 <thread_create>

      nice += nice_step;
c002cd28:	03 7c 24 14          	add    0x14(%esp),%edi
  for (i = 0; i < thread_cnt; i++) 
c002cd2c:	83 c6 01             	add    $0x1,%esi
c002cd2f:	83 c3 10             	add    $0x10,%ebx
c002cd32:	39 ee                	cmp    %ebp,%esi
c002cd34:	75 9b                	jne    c002ccd1 <test_mlfqs_fair+0x151>
    }
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cd36:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cd3a:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cd3e:	89 04 24             	mov    %eax,(%esp)
c002cd41:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cd45:	e8 26 75 ff ff       	call   c0024270 <timer_elapsed>
c002cd4a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cd4e:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd52:	c7 04 24 48 12 03 c0 	movl   $0xc0031248,(%esp)
c002cd59:	e8 0f da ff ff       	call   c002a76d <msg>

  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cd5e:	c7 04 24 6c 12 03 c0 	movl   $0xc003126c,(%esp)
c002cd65:	e8 03 da ff ff       	call   c002a76d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cd6a:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cd71:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cd78:	00 
c002cd79:	e8 0e 75 ff ff       	call   c002428c <timer_sleep>
  
  for (i = 0; i < thread_cnt; i++)
c002cd7e:	bb 00 00 00 00       	mov    $0x0,%ebx
c002cd83:	89 d8                	mov    %ebx,%eax
c002cd85:	c1 e0 04             	shl    $0x4,%eax
    msg ("Thread %d received %d ticks.", i, info[i].tick_count);
c002cd88:	8b 44 04 38          	mov    0x38(%esp,%eax,1),%eax
c002cd8c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002cd90:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002cd94:	c7 04 24 d5 11 03 c0 	movl   $0xc00311d5,(%esp)
c002cd9b:	e8 cd d9 ff ff       	call   c002a76d <msg>
  for (i = 0; i < thread_cnt; i++)
c002cda0:	83 c3 01             	add    $0x1,%ebx
c002cda3:	39 eb                	cmp    %ebp,%ebx
c002cda5:	75 dc                	jne    c002cd83 <test_mlfqs_fair+0x203>
c002cda7:	eb 48                	jmp    c002cdf1 <test_mlfqs_fair+0x271>
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cda9:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cdad:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cdb1:	89 04 24             	mov    %eax,(%esp)
c002cdb4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cdb8:	e8 b3 74 ff ff       	call   c0024270 <timer_elapsed>
c002cdbd:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cdc1:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cdc5:	c7 04 24 48 12 03 c0 	movl   $0xc0031248,(%esp)
c002cdcc:	e8 9c d9 ff ff       	call   c002a76d <msg>
  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cdd1:	c7 04 24 6c 12 03 c0 	movl   $0xc003126c,(%esp)
c002cdd8:	e8 90 d9 ff ff       	call   c002a76d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cddd:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cde4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cdeb:	00 
c002cdec:	e8 9b 74 ff ff       	call   c002428c <timer_sleep>
}
c002cdf1:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002cdf7:	5b                   	pop    %ebx
c002cdf8:	5e                   	pop    %esi
c002cdf9:	5f                   	pop    %edi
c002cdfa:	5d                   	pop    %ebp
c002cdfb:	c3                   	ret    

c002cdfc <load_thread>:

static void
load_thread (void *ti_) 
{
c002cdfc:	57                   	push   %edi
c002cdfd:	56                   	push   %esi
c002cdfe:	53                   	push   %ebx
c002cdff:	83 ec 10             	sub    $0x10,%esp
c002ce02:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread_info *ti = ti_;
  int64_t sleep_time = 5 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 30 * TIMER_FREQ;
  int64_t last_time = 0;

  thread_set_nice (ti->nice);
c002ce06:	8b 43 0c             	mov    0xc(%ebx),%eax
c002ce09:	89 04 24             	mov    %eax,(%esp)
c002ce0c:	e8 97 49 ff ff       	call   c00217a8 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (ti->start_time));
c002ce11:	8b 03                	mov    (%ebx),%eax
c002ce13:	8b 53 04             	mov    0x4(%ebx),%edx
c002ce16:	89 04 24             	mov    %eax,(%esp)
c002ce19:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ce1d:	e8 4e 74 ff ff       	call   c0024270 <timer_elapsed>
c002ce22:	be f4 01 00 00       	mov    $0x1f4,%esi
c002ce27:	bf 00 00 00 00       	mov    $0x0,%edi
c002ce2c:	29 c6                	sub    %eax,%esi
c002ce2e:	19 d7                	sbb    %edx,%edi
c002ce30:	89 34 24             	mov    %esi,(%esp)
c002ce33:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ce37:	e8 50 74 ff ff       	call   c002428c <timer_sleep>
  int64_t last_time = 0;
c002ce3c:	bf 00 00 00 00       	mov    $0x0,%edi
c002ce41:	be 00 00 00 00       	mov    $0x0,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce46:	eb 15                	jmp    c002ce5d <load_thread+0x61>
    {
      int64_t cur_time = timer_ticks ();
c002ce48:	e8 f7 73 ff ff       	call   c0024244 <timer_ticks>
      if (cur_time != last_time)
c002ce4d:	31 d6                	xor    %edx,%esi
c002ce4f:	31 c7                	xor    %eax,%edi
c002ce51:	09 fe                	or     %edi,%esi
c002ce53:	74 04                	je     c002ce59 <load_thread+0x5d>
        ti->tick_count++;
c002ce55:	83 43 08 01          	addl   $0x1,0x8(%ebx)
{
c002ce59:	89 c7                	mov    %eax,%edi
c002ce5b:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce5d:	8b 03                	mov    (%ebx),%eax
c002ce5f:	8b 53 04             	mov    0x4(%ebx),%edx
c002ce62:	89 04 24             	mov    %eax,(%esp)
c002ce65:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ce69:	e8 02 74 ff ff       	call   c0024270 <timer_elapsed>
c002ce6e:	85 d2                	test   %edx,%edx
c002ce70:	78 d6                	js     c002ce48 <load_thread+0x4c>
c002ce72:	85 d2                	test   %edx,%edx
c002ce74:	7f 07                	jg     c002ce7d <load_thread+0x81>
c002ce76:	3d ab 0d 00 00       	cmp    $0xdab,%eax
c002ce7b:	76 cb                	jbe    c002ce48 <load_thread+0x4c>
      last_time = cur_time;
    }
}
c002ce7d:	83 c4 10             	add    $0x10,%esp
c002ce80:	5b                   	pop    %ebx
c002ce81:	5e                   	pop    %esi
c002ce82:	5f                   	pop    %edi
c002ce83:	c3                   	ret    

c002ce84 <test_mlfqs_fair_2>:
{
c002ce84:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 0);
c002ce87:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce8c:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce91:	b8 02 00 00 00       	mov    $0x2,%eax
c002ce96:	e8 e5 fc ff ff       	call   c002cb80 <test_mlfqs_fair>
}
c002ce9b:	83 c4 0c             	add    $0xc,%esp
c002ce9e:	c3                   	ret    

c002ce9f <test_mlfqs_fair_20>:
{
c002ce9f:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (20, 0, 0);
c002cea2:	b9 00 00 00 00       	mov    $0x0,%ecx
c002cea7:	ba 00 00 00 00       	mov    $0x0,%edx
c002ceac:	b8 14 00 00 00       	mov    $0x14,%eax
c002ceb1:	e8 ca fc ff ff       	call   c002cb80 <test_mlfqs_fair>
}
c002ceb6:	83 c4 0c             	add    $0xc,%esp
c002ceb9:	c3                   	ret    

c002ceba <test_mlfqs_nice_2>:
{
c002ceba:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 5);
c002cebd:	b9 05 00 00 00       	mov    $0x5,%ecx
c002cec2:	ba 00 00 00 00       	mov    $0x0,%edx
c002cec7:	b8 02 00 00 00       	mov    $0x2,%eax
c002cecc:	e8 af fc ff ff       	call   c002cb80 <test_mlfqs_fair>
}
c002ced1:	83 c4 0c             	add    $0xc,%esp
c002ced4:	c3                   	ret    

c002ced5 <test_mlfqs_nice_10>:
{
c002ced5:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (10, 0, 1);
c002ced8:	b9 01 00 00 00       	mov    $0x1,%ecx
c002cedd:	ba 00 00 00 00       	mov    $0x0,%edx
c002cee2:	b8 0a 00 00 00       	mov    $0xa,%eax
c002cee7:	e8 94 fc ff ff       	call   c002cb80 <test_mlfqs_fair>
}
c002ceec:	83 c4 0c             	add    $0xc,%esp
c002ceef:	c3                   	ret    

c002cef0 <block_thread>:
  msg ("Block thread should have already acquired lock.");
}

static void
block_thread (void *lock_) 
{
c002cef0:	56                   	push   %esi
c002cef1:	53                   	push   %ebx
c002cef2:	83 ec 14             	sub    $0x14,%esp
  struct lock *lock = lock_;
  int64_t start_time;

  msg ("Block thread spinning for 20 seconds...");
c002cef5:	c7 04 24 a4 12 03 c0 	movl   $0xc00312a4,(%esp)
c002cefc:	e8 6c d8 ff ff       	call   c002a76d <msg>
  start_time = timer_ticks ();
c002cf01:	e8 3e 73 ff ff       	call   c0024244 <timer_ticks>
c002cf06:	89 c3                	mov    %eax,%ebx
c002cf08:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 20 * TIMER_FREQ)
c002cf0a:	89 1c 24             	mov    %ebx,(%esp)
c002cf0d:	89 74 24 04          	mov    %esi,0x4(%esp)
c002cf11:	e8 5a 73 ff ff       	call   c0024270 <timer_elapsed>
c002cf16:	85 d2                	test   %edx,%edx
c002cf18:	7f 0b                	jg     c002cf25 <block_thread+0x35>
c002cf1a:	85 d2                	test   %edx,%edx
c002cf1c:	78 ec                	js     c002cf0a <block_thread+0x1a>
c002cf1e:	3d cf 07 00 00       	cmp    $0x7cf,%eax
c002cf23:	76 e5                	jbe    c002cf0a <block_thread+0x1a>
    continue;

  msg ("Block thread acquiring lock...");
c002cf25:	c7 04 24 cc 12 03 c0 	movl   $0xc00312cc,(%esp)
c002cf2c:	e8 3c d8 ff ff       	call   c002a76d <msg>
  lock_acquire (lock);
c002cf31:	8b 44 24 20          	mov    0x20(%esp),%eax
c002cf35:	89 04 24             	mov    %eax,(%esp)
c002cf38:	e8 6d 5f ff ff       	call   c0022eaa <lock_acquire>

  msg ("...got it.");
c002cf3d:	c7 04 24 a4 13 03 c0 	movl   $0xc00313a4,(%esp)
c002cf44:	e8 24 d8 ff ff       	call   c002a76d <msg>
}
c002cf49:	83 c4 14             	add    $0x14,%esp
c002cf4c:	5b                   	pop    %ebx
c002cf4d:	5e                   	pop    %esi
c002cf4e:	c3                   	ret    

c002cf4f <test_mlfqs_block>:
{
c002cf4f:	56                   	push   %esi
c002cf50:	53                   	push   %ebx
c002cf51:	83 ec 54             	sub    $0x54,%esp
  ASSERT (thread_mlfqs);
c002cf54:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002cf5b:	75 2c                	jne    c002cf89 <test_mlfqs_block+0x3a>
c002cf5d:	c7 44 24 10 3d 01 03 	movl   $0xc003013d,0x10(%esp)
c002cf64:	c0 
c002cf65:	c7 44 24 0c b1 e1 02 	movl   $0xc002e1b1,0xc(%esp)
c002cf6c:	c0 
c002cf6d:	c7 44 24 08 28 e1 02 	movl   $0xc002e128,0x8(%esp)
c002cf74:	c0 
c002cf75:	c7 44 24 04 1c 00 00 	movl   $0x1c,0x4(%esp)
c002cf7c:	00 
c002cf7d:	c7 04 24 ec 12 03 c0 	movl   $0xc00312ec,(%esp)
c002cf84:	e8 2a ba ff ff       	call   c00289b3 <debug_panic>
  msg ("Main thread acquiring lock.");
c002cf89:	c7 04 24 af 13 03 c0 	movl   $0xc00313af,(%esp)
c002cf90:	e8 d8 d7 ff ff       	call   c002a76d <msg>
  lock_init (&lock);
c002cf95:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002cf99:	89 1c 24             	mov    %ebx,(%esp)
c002cf9c:	e8 6c 5e ff ff       	call   c0022e0d <lock_init>
  lock_acquire (&lock);
c002cfa1:	89 1c 24             	mov    %ebx,(%esp)
c002cfa4:	e8 01 5f ff ff       	call   c0022eaa <lock_acquire>
  msg ("Main thread creating block thread, sleeping 25 seconds...");
c002cfa9:	c7 04 24 10 13 03 c0 	movl   $0xc0031310,(%esp)
c002cfb0:	e8 b8 d7 ff ff       	call   c002a76d <msg>
  thread_create ("block", PRI_DEFAULT, block_thread, &lock);
c002cfb5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cfb9:	c7 44 24 08 f0 ce 02 	movl   $0xc002cef0,0x8(%esp)
c002cfc0:	c0 
c002cfc1:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cfc8:	00 
c002cfc9:	c7 04 24 36 01 03 c0 	movl   $0xc0030136,(%esp)
c002cfd0:	e8 ad 45 ff ff       	call   c0021582 <thread_create>
  timer_sleep (25 * TIMER_FREQ);
c002cfd5:	c7 04 24 c4 09 00 00 	movl   $0x9c4,(%esp)
c002cfdc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cfe3:	00 
c002cfe4:	e8 a3 72 ff ff       	call   c002428c <timer_sleep>
  msg ("Main thread spinning for 5 seconds...");
c002cfe9:	c7 04 24 4c 13 03 c0 	movl   $0xc003134c,(%esp)
c002cff0:	e8 78 d7 ff ff       	call   c002a76d <msg>
  start_time = timer_ticks ();
c002cff5:	e8 4a 72 ff ff       	call   c0024244 <timer_ticks>
c002cffa:	89 c3                	mov    %eax,%ebx
c002cffc:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 5 * TIMER_FREQ)
c002cffe:	89 1c 24             	mov    %ebx,(%esp)
c002d001:	89 74 24 04          	mov    %esi,0x4(%esp)
c002d005:	e8 66 72 ff ff       	call   c0024270 <timer_elapsed>
c002d00a:	85 d2                	test   %edx,%edx
c002d00c:	7f 0b                	jg     c002d019 <test_mlfqs_block+0xca>
c002d00e:	85 d2                	test   %edx,%edx
c002d010:	78 ec                	js     c002cffe <test_mlfqs_block+0xaf>
c002d012:	3d f3 01 00 00       	cmp    $0x1f3,%eax
c002d017:	76 e5                	jbe    c002cffe <test_mlfqs_block+0xaf>
  msg ("Main thread releasing lock.");
c002d019:	c7 04 24 cb 13 03 c0 	movl   $0xc00313cb,(%esp)
c002d020:	e8 48 d7 ff ff       	call   c002a76d <msg>
  lock_release (&lock);
c002d025:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c002d029:	89 04 24             	mov    %eax,(%esp)
c002d02c:	e8 43 60 ff ff       	call   c0023074 <lock_release>
  msg ("Block thread should have already acquired lock.");
c002d031:	c7 04 24 74 13 03 c0 	movl   $0xc0031374,(%esp)
c002d038:	e8 30 d7 ff ff       	call   c002a76d <msg>
}
c002d03d:	83 c4 54             	add    $0x54,%esp
c002d040:	5b                   	pop    %ebx
c002d041:	5e                   	pop    %esi
c002d042:	c3                   	ret    
