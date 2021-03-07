
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
c002019f:	c7 04 24 b9 e0 02 c0 	movl   $0xc002e0b9,(%esp)
c00201a6:	e8 63 69 00 00       	call   c0026b0e <printf>
#ifdef USERPROG
  process_wait (process_execute (task));
#else
  run_test (task);
c00201ab:	89 1c 24             	mov    %ebx,(%esp)
c00201ae:	e8 a6 a5 00 00       	call   c002a759 <run_test>
#endif
  printf ("Execution of '%s' complete.\n", task);
c00201b3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00201b7:	c7 04 24 ca e0 02 c0 	movl   $0xc002e0ca,(%esp)
c00201be:	e8 4b 69 00 00       	call   c0026b0e <printf>
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
c00201d4:	2d 8c 5a 03 c0       	sub    $0xc0035a8c,%eax
c00201d9:	89 44 24 08          	mov    %eax,0x8(%esp)
c00201dd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00201e4:	00 
c00201e5:	c7 04 24 8c 5a 03 c0 	movl   $0xc0035a8c,(%esp)
c00201ec:	e8 30 7c 00 00       	call   c0027e21 <memset>
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
c0020217:	c7 44 24 0c f4 e1 02 	movl   $0xc002e1f4,0xc(%esp)
c002021e:	c0 
c002021f:	c7 44 24 08 47 d0 02 	movl   $0xc002d047,0x8(%esp)
c0020226:	c0 
c0020227:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c002022e:	00 
c002022f:	c7 04 24 e7 e0 02 c0 	movl   $0xc002e0e7,(%esp)
c0020236:	e8 28 87 00 00       	call   c0028963 <debug_panic>
      argv[i] = p;
c002023b:	89 1c b5 a0 5a 03 c0 	mov    %ebx,-0x3ffca560(,%esi,4)
      p += strnlen (p, end - p) + 1;
c0020242:	89 e8                	mov    %ebp,%eax
c0020244:	29 d8                	sub    %ebx,%eax
c0020246:	89 44 24 04          	mov    %eax,0x4(%esp)
c002024a:	89 1c 24             	mov    %ebx,(%esp)
c002024d:	e8 f8 7c 00 00       	call   c0027f4a <strnlen>
c0020252:	8d 5c 03 01          	lea    0x1(%ebx,%eax,1),%ebx
  for (i = 0; i < argc; i++) 
c0020256:	83 c6 01             	add    $0x1,%esi
c0020259:	39 f7                	cmp    %esi,%edi
c002025b:	75 b2                	jne    c002020f <pintos_init+0x47>
  argv[argc] = NULL;
c002025d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020264:	00 00 00 00 
  printf ("Kernel command line:");
c0020268:	c7 04 24 dd e1 02 c0 	movl   $0xc002e1dd,(%esp)
c002026f:	e8 9a 68 00 00       	call   c0026b0e <printf>
  for (i = 0; i < argc; i++)
c0020274:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (argv[i], ' ') == NULL)
c0020279:	8b 34 9d a0 5a 03 c0 	mov    -0x3ffca560(,%ebx,4),%esi
c0020280:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c0020287:	00 
c0020288:	89 34 24             	mov    %esi,(%esp)
c002028b:	e8 06 79 00 00       	call   c0027b96 <strchr>
c0020290:	85 c0                	test   %eax,%eax
c0020292:	75 12                	jne    c00202a6 <pintos_init+0xde>
      printf (" %s", argv[i]);
c0020294:	89 74 24 04          	mov    %esi,0x4(%esp)
c0020298:	c7 04 24 f3 ee 02 c0 	movl   $0xc002eef3,(%esp)
c002029f:	e8 6a 68 00 00       	call   c0026b0e <printf>
c00202a4:	eb 10                	jmp    c00202b6 <pintos_init+0xee>
      printf (" '%s'", argv[i]);
c00202a6:	89 74 24 04          	mov    %esi,0x4(%esp)
c00202aa:	c7 04 24 fc e0 02 c0 	movl   $0xc002e0fc,(%esp)
c00202b1:	e8 58 68 00 00       	call   c0026b0e <printf>
  for (i = 0; i < argc; i++)
c00202b6:	83 c3 01             	add    $0x1,%ebx
c00202b9:	39 df                	cmp    %ebx,%edi
c00202bb:	75 bc                	jne    c0020279 <pintos_init+0xb1>
  printf ("\n");
c00202bd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00202c4:	e8 33 a4 00 00       	call   c002a6fc <putchar>
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
c00202ec:	c7 44 24 04 85 ed 02 	movl   $0xc002ed85,0x4(%esp)
c00202f3:	c0 
c00202f4:	89 04 24             	mov    %eax,(%esp)
c00202f7:	e8 08 7a 00 00       	call   c0027d04 <strtok_r>
c00202fc:	89 c3                	mov    %eax,%ebx
      char *value = strtok_r (NULL, "", &save_ptr);
c00202fe:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020302:	89 44 24 08          	mov    %eax,0x8(%esp)
c0020306:	c7 44 24 04 97 ed 02 	movl   $0xc002ed97,0x4(%esp)
c002030d:	c0 
c002030e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0020315:	e8 ea 79 00 00       	call   c0027d04 <strtok_r>
      if (!strcmp (name, "-h"))
c002031a:	bf 02 e1 02 c0       	mov    $0xc002e102,%edi
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
c0020332:	c7 04 24 14 e2 02 c0 	movl   $0xc002e214,(%esp)
c0020339:	e8 4d a3 00 00       	call   c002a68b <puts>
          "  -mlfqs             Use multi-level feedback queue scheduler.\n"
#ifdef USERPROG
          "  -ul=COUNT          Limit user memory to COUNT pages.\n"
#endif
          );
  shutdown_power_off ();
c002033e:	e8 ac 60 00 00       	call   c00263ef <shutdown_power_off>
      else if (!strcmp (name, "-q"))
c0020343:	bf 05 e1 02 c0       	mov    $0xc002e105,%edi
c0020348:	89 de                	mov    %ebx,%esi
c002034a:	b9 03 00 00 00       	mov    $0x3,%ecx
c002034f:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c0020351:	0f 97 c1             	seta   %cl
c0020354:	0f 92 c2             	setb   %dl
c0020357:	38 d1                	cmp    %dl,%cl
c0020359:	75 11                	jne    c002036c <pintos_init+0x1a4>
        shutdown_configure (SHUTDOWN_POWER_OFF);
c002035b:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0020362:	e8 09 60 00 00       	call   c0026370 <shutdown_configure>
c0020367:	e9 99 00 00 00       	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-r"))
c002036c:	bf 08 e1 02 c0       	mov    $0xc002e108,%edi
c0020371:	89 de                	mov    %ebx,%esi
c0020373:	b9 03 00 00 00       	mov    $0x3,%ecx
c0020378:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c002037a:	0f 97 c1             	seta   %cl
c002037d:	0f 92 c2             	setb   %dl
c0020380:	38 d1                	cmp    %dl,%cl
c0020382:	75 0e                	jne    c0020392 <pintos_init+0x1ca>
        shutdown_configure (SHUTDOWN_REBOOT);
c0020384:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c002038b:	e8 e0 5f 00 00       	call   c0026370 <shutdown_configure>
c0020390:	eb 73                	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-rs"))
c0020392:	bf 0b e1 02 c0       	mov    $0xc002e10b,%edi
c0020397:	b9 04 00 00 00       	mov    $0x4,%ecx
c002039c:	89 de                	mov    %ebx,%esi
c002039e:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00203a0:	0f 97 c1             	seta   %cl
c00203a3:	0f 92 c2             	setb   %dl
c00203a6:	38 d1                	cmp    %dl,%cl
c00203a8:	75 12                	jne    c00203bc <pintos_init+0x1f4>
        random_init (atoi (value));
c00203aa:	89 04 24             	mov    %eax,(%esp)
c00203ad:	e8 be 71 00 00       	call   c0027570 <atoi>
c00203b2:	89 04 24             	mov    %eax,(%esp)
c00203b5:	e8 01 62 00 00       	call   c00265bb <random_init>
c00203ba:	eb 49                	jmp    c0020405 <pintos_init+0x23d>
      else if (!strcmp (name, "-mlfqs"))
c00203bc:	bf 0f e1 02 c0       	mov    $0xc002e10f,%edi
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
c00203e1:	c7 44 24 0c e4 e3 02 	movl   $0xc002e3e4,0xc(%esp)
c00203e8:	c0 
c00203e9:	c7 44 24 08 34 d0 02 	movl   $0xc002d034,0x8(%esp)
c00203f0:	c0 
c00203f1:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c00203f8:	00 
c00203f9:	c7 04 24 e7 e0 02 c0 	movl   $0xc002e0e7,(%esp)
c0020400:	e8 5e 85 00 00       	call   c0028963 <debug_panic>
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
c0020427:	e8 e0 5d 00 00       	call   c002620c <rtc_get_time>
c002042c:	89 04 24             	mov    %eax,(%esp)
c002042f:	e8 87 61 00 00       	call   c00265bb <random_init>
  thread_init ();
c0020434:	e8 8c 07 00 00       	call   c0020bc5 <thread_init>
  console_init ();  
c0020439:	e8 c4 a1 00 00       	call   c002a602 <console_init>
          init_ram_pages * PGSIZE / 1024);
c002043e:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c0020443:	c1 e0 0c             	shl    $0xc,%eax
  printf ("Pintos booting with %'"PRIu32" kB RAM...\n",
c0020446:	c1 e8 0a             	shr    $0xa,%eax
c0020449:	89 44 24 04          	mov    %eax,0x4(%esp)
c002044d:	c7 04 24 0c e4 02 c0 	movl   $0xc002e40c,(%esp)
c0020454:	e8 b5 66 00 00       	call   c0026b0e <printf>
  palloc_init (user_page_limit);
c0020459:	c7 04 24 ff ff ff ff 	movl   $0xffffffff,(%esp)
c0020460:	e8 3b 30 00 00       	call   c00234a0 <palloc_init>
  malloc_init ();
c0020465:	e8 bd 34 00 00       	call   c0023927 <malloc_init>
  pd = init_page_dir = palloc_get_page (PAL_ASSERT | PAL_ZERO);
c002046a:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
c0020471:	e8 90 31 00 00       	call   c0023606 <palloc_get_page>
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
c00204a9:	c7 44 24 10 16 e1 02 	movl   $0xc002e116,0x10(%esp)
c00204b0:	c0 
c00204b1:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00204b8:	c0 
c00204b9:	c7 44 24 08 42 d0 02 	movl   $0xc002d042,0x8(%esp)
c00204c0:	c0 
c00204c1:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c00204c8:	00 
c00204c9:	c7 04 24 48 e1 02 c0 	movl   $0xc002e148,(%esp)
c00204d0:	e8 8e 84 00 00       	call   c0028963 <debug_panic>
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
c0020526:	e8 db 30 00 00       	call   c0023606 <palloc_get_page>
  return (uintptr_t) va & PGMASK;
c002052b:	89 c2                	mov    %eax,%edx
#define PTE_A 0x20              /* 1=accessed, 0=not acccessed. */
#define PTE_D 0x40              /* 1=dirty, 0=not dirty (PTEs only). */

/* Returns a PDE that points to page table PT. */
static inline uint32_t pde_create (uint32_t *pt) {
  ASSERT (pg_ofs (pt) == 0);
c002052d:	a9 ff 0f 00 00       	test   $0xfff,%eax
c0020532:	74 2c                	je     c0020560 <pintos_init+0x398>
c0020534:	c7 44 24 10 5e e1 02 	movl   $0xc002e15e,0x10(%esp)
c002053b:	c0 
c002053c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020543:	c0 
c0020544:	c7 44 24 08 29 d0 02 	movl   $0xc002d029,0x8(%esp)
c002054b:	c0 
c002054c:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c0020553:	00 
c0020554:	c7 04 24 6f e1 02 c0 	movl   $0xc002e16f,(%esp)
c002055b:	e8 03 84 00 00       	call   c0028963 <debug_panic>
/* Returns physical address at which kernel virtual address VADDR
   is mapped. */
static inline uintptr_t
vtop (const void *vaddr)
{
  ASSERT (is_kernel_vaddr (vaddr));
c0020560:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c0020565:	77 2c                	ja     c0020593 <pintos_init+0x3cb>
c0020567:	c7 44 24 10 83 e1 02 	movl   $0xc002e183,0x10(%esp)
c002056e:	c0 
c002056f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020576:	c0 
c0020577:	c7 44 24 08 24 d0 02 	movl   $0xc002d024,0x8(%esp)
c002057e:	c0 
c002057f:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0020586:	00 
c0020587:	c7 04 24 48 e1 02 c0 	movl   $0xc002e148,(%esp)
c002058e:	e8 d0 83 00 00       	call   c0028963 <debug_panic>

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
c00205b1:	c7 44 24 10 83 e1 02 	movl   $0xc002e183,0x10(%esp)
c00205b8:	c0 
c00205b9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00205c0:	c0 
c00205c1:	c7 44 24 08 24 d0 02 	movl   $0xc002d024,0x8(%esp)
c00205c8:	c0 
c00205c9:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c00205d0:	00 
c00205d1:	c7 04 24 48 e1 02 c0 	movl   $0xc002e148,(%esp)
c00205d8:	e8 86 83 00 00       	call   c0028963 <debug_panic>
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
c0020611:	c7 44 24 10 83 e1 02 	movl   $0xc002e183,0x10(%esp)
c0020618:	c0 
c0020619:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020620:	c0 
c0020621:	c7 44 24 08 24 d0 02 	movl   $0xc002d024,0x8(%esp)
c0020628:	c0 
c0020629:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0020630:	00 
c0020631:	c7 04 24 48 e1 02 c0 	movl   $0xc002e148,(%esp)
c0020638:	e8 26 83 00 00       	call   c0028963 <debug_panic>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c002063d:	05 00 00 00 40       	add    $0x40000000,%eax
c0020642:	0f 22 d8             	mov    %eax,%cr3
  intr_init ();
c0020645:	e8 77 13 00 00       	call   c00219c1 <intr_init>
  timer_init ();
c002064a:	e8 2a 3a 00 00       	call   c0024079 <timer_init>
  kbd_init ();
c002064f:	e8 d7 3f 00 00       	call   c002462b <kbd_init>
  input_init ();
c0020654:	e8 9c 56 00 00       	call   c0025cf5 <input_init>
  thread_start ();
c0020659:	e8 ed 0f 00 00       	call   c002164b <thread_start>
c002065e:	66 90                	xchg   %ax,%ax
  serial_init_queue ();
c0020660:	e8 11 44 00 00       	call   c0024a76 <serial_init_queue>
  timer_calibrate ();
c0020665:	e8 9c 3a 00 00       	call   c0024106 <timer_calibrate>
  printf ("Boot complete.\n");
c002066a:	c7 04 24 9b e1 02 c0 	movl   $0xc002e19b,(%esp)
c0020671:	e8 15 a0 00 00       	call   c002a68b <puts>
  if (*argv != NULL) {
c0020676:	8b 75 00             	mov    0x0(%ebp),%esi
c0020679:	85 f6                	test   %esi,%esi
c002067b:	0f 84 c9 00 00 00    	je     c002074a <pintos_init+0x582>
        if (a->name == NULL)
c0020681:	b8 3a e7 02 c0       	mov    $0xc002e73a,%eax
  if (*argv != NULL) {
c0020686:	bb 0c d0 02 c0       	mov    $0xc002d00c,%ebx
c002068b:	eb 0c                	jmp    c0020699 <pintos_init+0x4d1>
        if (a->name == NULL)
c002068d:	b8 3a e7 02 c0       	mov    $0xc002e73a,%eax
  while (*argv != NULL)
c0020692:	ba 0c d0 02 c0       	mov    $0xc002d00c,%edx
c0020697:	89 d3                	mov    %edx,%ebx
        else if (!strcmp (*argv, a->name))
c0020699:	89 44 24 04          	mov    %eax,0x4(%esp)
c002069d:	89 34 24             	mov    %esi,(%esp)
c00206a0:	e8 d2 73 00 00       	call   c0027a77 <strcmp>
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
c00206c7:	c7 44 24 0c 30 e4 02 	movl   $0xc002e430,0xc(%esp)
c00206ce:	c0 
c00206cf:	c7 44 24 08 00 d0 02 	movl   $0xc002d000,0x8(%esp)
c00206d6:	c0 
c00206d7:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c00206de:	00 
c00206df:	c7 04 24 e7 e0 02 c0 	movl   $0xc002e0e7,(%esp)
c00206e6:	e8 78 82 00 00       	call   c0028963 <debug_panic>
        if (argv[i] == NULL)
c00206eb:	83 7c 85 00 00       	cmpl   $0x0,0x0(%ebp,%eax,4)
c00206f0:	75 34                	jne    c0020726 <pintos_init+0x55e>
          PANIC ("action `%s' requires %d argument(s)", *argv, a->argc - 1);
c00206f2:	83 ea 01             	sub    $0x1,%edx
c00206f5:	89 54 24 14          	mov    %edx,0x14(%esp)
c00206f9:	89 74 24 10          	mov    %esi,0x10(%esp)
c00206fd:	c7 44 24 0c 58 e4 02 	movl   $0xc002e458,0xc(%esp)
c0020704:	c0 
c0020705:	c7 44 24 08 00 d0 02 	movl   $0xc002d000,0x8(%esp)
c002070c:	c0 
c002070d:	c7 44 24 04 72 01 00 	movl   $0x172,0x4(%esp)
c0020714:	00 
c0020715:	c7 04 24 e7 e0 02 c0 	movl   $0xc002e0e7,(%esp)
c002071c:	e8 42 82 00 00       	call   c0028963 <debug_panic>
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
c0020757:	c7 44 24 04 97 ed 02 	movl   $0xc002ed97,0x4(%esp)
c002075e:	c0 
c002075f:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020763:	89 04 24             	mov    %eax,(%esp)
c0020766:	e8 0b 78 00 00       	call   c0027f76 <strlcpy>
      printf("ICS143A>");
c002076b:	c7 04 24 aa e1 02 c0 	movl   $0xc002e1aa,(%esp)
c0020772:	e8 97 63 00 00       	call   c0026b0e <printf>
        char l = input_getc();
c0020777:	e8 22 56 00 00       	call   c0025d9e <input_getc>
c002077c:	89 c3                	mov    %eax,%ebx
        while(l != '\n'){
c002077e:	3c 0a                	cmp    $0xa,%al
c0020780:	74 24                	je     c00207a6 <pintos_init+0x5de>
c0020782:	be 00 00 00 00       	mov    $0x0,%esi
          printf("%c",l);
c0020787:	0f be c3             	movsbl %bl,%eax
c002078a:	89 04 24             	mov    %eax,(%esp)
c002078d:	e8 6a 9f 00 00       	call   c002a6fc <putchar>
          cmdline[i] = l;
c0020792:	88 5c 34 3c          	mov    %bl,0x3c(%esp,%esi,1)
          l = input_getc();
c0020796:	e8 03 56 00 00       	call   c0025d9e <input_getc>
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
c00207b0:	bf b3 e1 02 c0       	mov    $0xc002e1b3,%edi
c00207b5:	8d 74 24 3c          	lea    0x3c(%esp),%esi
c00207b9:	89 e9                	mov    %ebp,%ecx
c00207bb:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00207bd:	0f 97 c2             	seta   %dl
c00207c0:	0f 92 c0             	setb   %al
c00207c3:	38 c2                	cmp    %al,%dl
c00207c5:	75 0e                	jne    c00207d5 <pintos_init+0x60d>
          printf("\nSydney Eads\n");
c00207c7:	c7 04 24 ba e1 02 c0 	movl   $0xc002e1ba,(%esp)
c00207ce:	e8 b8 9e 00 00       	call   c002a68b <puts>
c00207d3:	eb 34                	jmp    c0020809 <pintos_init+0x641>
        else if(!strcmp(cmdline,"exit")){
c00207d5:	bf c7 e1 02 c0       	mov    $0xc002e1c7,%edi
c00207da:	b9 05 00 00 00       	mov    $0x5,%ecx
c00207df:	8d 74 24 3c          	lea    0x3c(%esp),%esi
c00207e3:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c00207e5:	0f 97 c2             	seta   %dl
c00207e8:	0f 92 c0             	setb   %al
c00207eb:	38 c2                	cmp    %al,%dl
c00207ed:	75 0e                	jne    c00207fd <pintos_init+0x635>
          printf("\n");
c00207ef:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00207f6:	e8 01 9f 00 00       	call   c002a6fc <putchar>
c00207fb:	eb 26                	jmp    c0020823 <pintos_init+0x65b>
          printf("\ninvalid command\n");
c00207fd:	c7 04 24 cc e1 02 c0 	movl   $0xc002e1cc,(%esp)
c0020804:	e8 82 9e 00 00       	call   c002a68b <puts>
        memset(&cmdline[0], 0, sizeof(cmdline));
c0020809:	b9 0c 00 00 00       	mov    $0xc,%ecx
c002080e:	b8 00 00 00 00       	mov    $0x0,%eax
c0020813:	8d 7c 24 3c          	lea    0x3c(%esp),%edi
c0020817:	f3 ab                	rep stos %eax,%es:(%edi)
c0020819:	66 c7 07 00 00       	movw   $0x0,(%edi)
    }
c002081e:	e9 2c ff ff ff       	jmp    c002074f <pintos_init+0x587>
  shutdown ();
c0020823:	e8 48 5c 00 00       	call   c0026470 <shutdown>
  thread_exit ();
c0020828:	e8 8b 0b 00 00       	call   c00213b8 <thread_exit>
  argv[argc] = NULL;
c002082d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020834:	00 00 00 00 
  printf ("Kernel command line:");
c0020838:	c7 04 24 dd e1 02 c0 	movl   $0xc002e1dd,(%esp)
c002083f:	e8 ca 62 00 00       	call   c0026b0e <printf>
c0020844:	e9 74 fa ff ff       	jmp    c00202bd <pintos_init+0xf5>
c0020849:	90                   	nop
c002084a:	90                   	nop
c002084b:	90                   	nop
c002084c:	90                   	nop
c002084d:	90                   	nop
c002084e:	90                   	nop
c002084f:	90                   	nop

c0020850 <thread_priority_cmp>:
static bool thread_priority_cmp(const struct list_elem *t1_,
                             const struct list_elem *t2_, void *aux UNUSED)
{
  const struct thread *t1 = list_entry (t1_, struct thread, elem);
  const struct thread *t2 = list_entry (t2_, struct thread, elem);
  return t1->priority < t2->priority;
c0020850:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020854:	8b 54 24 04          	mov    0x4(%esp),%edx
c0020858:	8b 40 f4             	mov    -0xc(%eax),%eax
c002085b:	39 42 f4             	cmp    %eax,-0xc(%edx)
c002085e:	0f 9c c0             	setl   %al
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
c0020876:	c7 44 24 10 7c e4 02 	movl   $0xc002e47c,0x10(%esp)
c002087d:	c0 
c002087e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020885:	c0 
c0020886:	c7 44 24 08 ca d0 02 	movl   $0xc002d0ca,0x8(%esp)
c002088d:	c0 
c002088e:	c7 44 24 04 f8 02 00 	movl   $0x2f8,0x4(%esp)
c0020895:	00 
c0020896:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c002089d:	e8 c1 80 00 00       	call   c0028963 <debug_panic>
c00208a2:	f6 c2 03             	test   $0x3,%dl
c00208a5:	74 2e                	je     c00208d5 <alloc_frame+0x73>
c00208a7:	eb cd                	jmp    c0020876 <alloc_frame+0x14>
  ASSERT (is_thread (t));
c00208a9:	c7 44 24 10 b1 e4 02 	movl   $0xc002e4b1,0x10(%esp)
c00208b0:	c0 
c00208b1:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00208b8:	c0 
c00208b9:	c7 44 24 08 ca d0 02 	movl   $0xc002d0ca,0x8(%esp)
c00208c0:	c0 
c00208c1:	c7 44 24 04 f7 02 00 	movl   $0x2f7,0x4(%esp)
c00208c8:	00 
c00208c9:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c00208d0:	e8 8e 80 00 00       	call   c0028963 <debug_panic>

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
    while(i < q)
c00208ed:	83 e8 01             	sub    $0x1,%eax
c00208f0:	75 f9                	jne    c00208eb <init_f_value+0xa>
c00208f2:	89 15 30 60 03 c0    	mov    %edx,0xc0036030
c00208f8:	c3                   	ret    

c00208f9 <convert_to_fixed_point>:
    return n * f;
c00208f9:	8b 44 24 04          	mov    0x4(%esp),%eax
c00208fd:	0f af 05 30 60 03 c0 	imul   0xc0036030,%eax
}
c0020904:	c3                   	ret    

c0020905 <covert_to_integer>:
{
c0020905:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / f;
c0020909:	99                   	cltd   
c002090a:	f7 3d 30 60 03 c0    	idivl  0xc0036030
}
c0020910:	c3                   	ret    

c0020911 <covert_to_integer_round>:
{
c0020911:	8b 44 24 04          	mov    0x4(%esp),%eax
    if(x >= 0)
c0020915:	85 c0                	test   %eax,%eax
c0020917:	78 15                	js     c002092e <covert_to_integer_round+0x1d>
        return (x + f / 2) / f;
c0020919:	8b 0d 30 60 03 c0    	mov    0xc0036030,%ecx
c002091f:	89 ca                	mov    %ecx,%edx
c0020921:	c1 ea 1f             	shr    $0x1f,%edx
c0020924:	01 ca                	add    %ecx,%edx
c0020926:	d1 fa                	sar    %edx
c0020928:	01 d0                	add    %edx,%eax
c002092a:	99                   	cltd   
c002092b:	f7 f9                	idiv   %ecx
c002092d:	c3                   	ret    
        return (x - f / 2) / f;
c002092e:	8b 0d 30 60 03 c0    	mov    0xc0036030,%ecx
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
c0020950:	c7 44 24 10 e3 f9 02 	movl   $0xc002f9e3,0x10(%esp)
c0020957:	c0 
c0020958:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002095f:	c0 
c0020960:	c7 44 24 08 f2 d0 02 	movl   $0xc002d0f2,0x8(%esp)
c0020967:	c0 
c0020968:	c7 44 24 04 cf 02 00 	movl   $0x2cf,0x4(%esp)
c002096f:	00 
c0020970:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0020977:	e8 e7 7f 00 00       	call   c0028963 <debug_panic>
c002097c:	89 ce                	mov    %ecx,%esi
    ASSERT (PRI_MIN <= priority && priority <= PRI_MAX);
c002097e:	83 f9 3f             	cmp    $0x3f,%ecx
c0020981:	76 2c                	jbe    c00209af <init_thread+0x6c>
c0020983:	c7 44 24 10 8c e5 02 	movl   $0xc002e58c,0x10(%esp)
c002098a:	c0 
c002098b:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020992:	c0 
c0020993:	c7 44 24 08 f2 d0 02 	movl   $0xc002d0f2,0x8(%esp)
c002099a:	c0 
c002099b:	c7 44 24 04 d0 02 00 	movl   $0x2d0,0x4(%esp)
c00209a2:	00 
c00209a3:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c00209aa:	e8 b4 7f 00 00       	call   c0028963 <debug_panic>
    ASSERT (name != NULL);
c00209af:	85 d2                	test   %edx,%edx
c00209b1:	75 2c                	jne    c00209df <init_thread+0x9c>
c00209b3:	c7 44 24 10 bf e4 02 	movl   $0xc002e4bf,0x10(%esp)
c00209ba:	c0 
c00209bb:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00209c2:	c0 
c00209c3:	c7 44 24 08 f2 d0 02 	movl   $0xc002d0f2,0x8(%esp)
c00209ca:	c0 
c00209cb:	c7 44 24 04 d1 02 00 	movl   $0x2d1,0x4(%esp)
c00209d2:	00 
c00209d3:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c00209da:	e8 84 7f 00 00       	call   c0028963 <debug_panic>
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
c0020a47:	e8 2a 75 00 00       	call   c0027f76 <strlcpy>
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
c0020a6d:	e8 3f 85 00 00       	call   c0028fb1 <list_push_back>
  if(!thread_mlfqs)
c0020a72:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0020a79:	75 08                	jne    c0020a83 <init_thread+0x140>
    t->priority = priority;
c0020a7b:	89 73 1c             	mov    %esi,0x1c(%ebx)
    t->old_priority = priority;
c0020a7e:	89 73 3c             	mov    %esi,0x3c(%ebx)
c0020a81:	eb 43                	jmp    c0020ac6 <init_thread+0x183>
    t->priority = PRI_MAX - covert_to_integer_round(t->recent_cpu / 4) - (t->nice * 2);
c0020a83:	8b 43 58             	mov    0x58(%ebx),%eax
c0020a86:	8d 50 03             	lea    0x3(%eax),%edx
c0020a89:	85 c0                	test   %eax,%eax
c0020a8b:	0f 48 c2             	cmovs  %edx,%eax
c0020a8e:	c1 f8 02             	sar    $0x2,%eax
c0020a91:	89 04 24             	mov    %eax,(%esp)
c0020a94:	e8 78 fe ff ff       	call   c0020911 <covert_to_integer_round>
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
c0020acc:	e8 5f 7f 00 00       	call   c0028a30 <list_init>
  t->wait_on_lock = NULL;
c0020ad1:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
}
c0020ad8:	83 c4 2c             	add    $0x2c,%esp
c0020adb:	5b                   	pop    %ebx
c0020adc:	5e                   	pop    %esi
c0020add:	5f                   	pop    %edi
c0020ade:	5d                   	pop    %ebp
c0020adf:	c3                   	ret    

c0020ae0 <add_fixed_point>:
    return x + y;
c0020ae0:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020ae4:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020ae8:	c3                   	ret    

c0020ae9 <subtract_fixed_point>:
    return x - y;
c0020ae9:	8b 44 24 04          	mov    0x4(%esp),%eax
c0020aed:	2b 44 24 08          	sub    0x8(%esp),%eax
}
c0020af1:	c3                   	ret    

c0020af2 <add_fixed_and_integer>:
    return x + (n * f);
c0020af2:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020af6:	0f af 05 30 60 03 c0 	imul   0xc0036030,%eax
c0020afd:	03 44 24 04          	add    0x4(%esp),%eax
}
c0020b01:	c3                   	ret    

c0020b02 <sub_fixed_and_integer>:
    return x - (n * f);
c0020b02:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b06:	0f af 05 30 60 03 c0 	imul   0xc0036030,%eax
c0020b0d:	8b 54 24 04          	mov    0x4(%esp),%edx
c0020b11:	29 c2                	sub    %eax,%edx
c0020b13:	89 d0                	mov    %edx,%eax
}
c0020b15:	c3                   	ret    

c0020b16 <multiply_fixed_point>:
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
c0020b3e:	8b 0d 30 60 03 c0    	mov    0xc0036030,%ecx
c0020b44:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0020b48:	89 cb                	mov    %ecx,%ebx
c0020b4a:	c1 fb 1f             	sar    $0x1f,%ebx
c0020b4d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0020b51:	89 04 24             	mov    %eax,(%esp)
c0020b54:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020b58:	e8 66 77 00 00       	call   c00282c3 <__divdi3>
}
c0020b5d:	83 c4 10             	add    $0x10,%esp
c0020b60:	5b                   	pop    %ebx
c0020b61:	5e                   	pop    %esi
c0020b62:	5f                   	pop    %edi
c0020b63:	c3                   	ret    

c0020b64 <multiply_fixed_and_integer>:
    return x * n;
c0020b64:	8b 44 24 08          	mov    0x8(%esp),%eax
c0020b68:	0f af 44 24 04       	imul   0x4(%esp),%eax
}
c0020b6d:	c3                   	ret    

c0020b6e <divide_fixed_point>:
{
c0020b6e:	57                   	push   %edi
c0020b6f:	56                   	push   %esi
c0020b70:	53                   	push   %ebx
c0020b71:	83 ec 10             	sub    $0x10,%esp
c0020b74:	8b 54 24 20          	mov    0x20(%esp),%edx
    return ((int64_t) x) * f / y;
c0020b78:	89 d7                	mov    %edx,%edi
c0020b7a:	c1 ff 1f             	sar    $0x1f,%edi
c0020b7d:	a1 30 60 03 c0       	mov    0xc0036030,%eax
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
c0020baf:	e8 0f 77 00 00       	call   c00282c3 <__divdi3>
}
c0020bb4:	83 c4 10             	add    $0x10,%esp
c0020bb7:	5b                   	pop    %ebx
c0020bb8:	5e                   	pop    %esi
c0020bb9:	5f                   	pop    %edi
c0020bba:	c3                   	ret    

c0020bbb <divide_fixed_and_integer>:
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
c0020bca:	e8 85 0d 00 00       	call   c0021954 <intr_get_level>
c0020bcf:	85 c0                	test   %eax,%eax
c0020bd1:	74 2c                	je     c0020bff <thread_init+0x3a>
c0020bd3:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0020bda:	c0 
c0020bdb:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020be2:	c0 
c0020be3:	c7 44 24 08 fe d0 02 	movl   $0xc002d0fe,0x8(%esp)
c0020bea:	c0 
c0020beb:	c7 44 24 04 bc 00 00 	movl   $0xbc,0x4(%esp)
c0020bf2:	00 
c0020bf3:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0020bfa:	e8 64 7d 00 00       	call   c0028963 <debug_panic>
  lock_init (&tid_lock);
c0020bff:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020c06:	e8 92 21 00 00       	call   c0022d9d <lock_init>
  list_init (&all_list);
c0020c0b:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020c12:	e8 19 7e 00 00       	call   c0028a30 <list_init>
c0020c17:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0020c1c:	be 20 60 03 c0       	mov    $0xc0036020,%esi
  if(!thread_mlfqs)
c0020c21:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0020c28:	75 0e                	jne    c0020c38 <thread_init+0x73>
    list_init (&ready_list);
c0020c2a:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020c31:	e8 fa 7d 00 00       	call   c0028a30 <list_init>
c0020c36:	eb 0f                	jmp    c0020c47 <thread_init+0x82>
      list_init (&mlfqs_list[i]);
c0020c38:	89 1c 24             	mov    %ebx,(%esp)
c0020c3b:	e8 f0 7d 00 00       	call   c0028a30 <list_init>
c0020c40:	83 c3 10             	add    $0x10,%ebx
    for(i=0;i<64;i++)
c0020c43:	39 f3                	cmp    %esi,%ebx
c0020c45:	75 f1                	jne    c0020c38 <thread_init+0x73>
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
c0020c70:	ba ea e4 02 c0       	mov    $0xc002e4ea,%edx
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
c0020c8e:	e8 a7 21 00 00       	call   c0022e3a <lock_acquire>
  tid = next_tid++;
c0020c93:	8b 35 48 56 03 c0    	mov    0xc0035648,%esi
c0020c99:	8d 46 01             	lea    0x1(%esi),%eax
c0020c9c:	a3 48 56 03 c0       	mov    %eax,0xc0035648
  lock_release (&tid_lock);
c0020ca1:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020ca8:	e8 57 23 00 00       	call   c0023004 <lock_release>
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
c0020cee:	c7 04 24 b8 e5 02 c0 	movl   $0xc002e5b8,(%esp)
c0020cf5:	e8 14 5e 00 00       	call   c0026b0e <printf>
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
c0020d1c:	eb 76                	jmp    c0020d94 <thread_unblock+0x96>
  ASSERT (t->status == THREAD_BLOCKED);
c0020d1e:	c7 44 24 10 ef e4 02 	movl   $0xc002e4ef,0x10(%esp)
c0020d25:	c0 
c0020d26:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020d2d:	c0 
c0020d2e:	c7 44 24 08 a5 d0 02 	movl   $0xc002d0a5,0x8(%esp)
c0020d35:	c0 
c0020d36:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
c0020d3d:	00 
c0020d3e:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0020d45:	e8 19 7c 00 00       	call   c0028963 <debug_panic>
  if(!thread_mlfqs)
c0020d4a:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0020d51:	75 15                	jne    c0020d68 <thread_unblock+0x6a>
    list_push_back (&ready_list, &t->elem);
c0020d53:	8d 43 28             	lea    0x28(%ebx),%eax
c0020d56:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020d5a:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020d61:	e8 4b 82 00 00       	call   c0028fb1 <list_push_back>
c0020d66:	eb 1b                	jmp    c0020d83 <thread_unblock+0x85>
    list_push_back (&mlfqs_list[t->priority], &t->elem);
c0020d68:	8d 43 28             	lea    0x28(%ebx),%eax
c0020d6b:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020d6f:	8b 53 1c             	mov    0x1c(%ebx),%edx
c0020d72:	c1 e2 04             	shl    $0x4,%edx
c0020d75:	81 c2 20 5c 03 c0    	add    $0xc0035c20,%edx
c0020d7b:	89 14 24             	mov    %edx,(%esp)
c0020d7e:	e8 2e 82 00 00       	call   c0028fb1 <list_push_back>
  t->status = THREAD_READY;
c0020d83:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  intr_set_level (old_level);
c0020d8a:	89 34 24             	mov    %esi,(%esp)
c0020d8d:	e8 14 0c 00 00       	call   c00219a6 <intr_set_level>
c0020d92:	eb 3f                	jmp    c0020dd3 <thread_unblock+0xd5>
  old_level = intr_disable ();
c0020d94:	e8 06 0c 00 00       	call   c002199f <intr_disable>
c0020d99:	89 c6                	mov    %eax,%esi
  ASSERT (t->status == THREAD_BLOCKED);
c0020d9b:	83 7b 04 02          	cmpl   $0x2,0x4(%ebx)
c0020d9f:	90                   	nop
c0020da0:	74 a8                	je     c0020d4a <thread_unblock+0x4c>
c0020da2:	e9 77 ff ff ff       	jmp    c0020d1e <thread_unblock+0x20>
  ASSERT (is_thread (t));
c0020da7:	c7 44 24 10 b1 e4 02 	movl   $0xc002e4b1,0x10(%esp)
c0020dae:	c0 
c0020daf:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020db6:	c0 
c0020db7:	c7 44 24 08 a5 d0 02 	movl   $0xc002d0a5,0x8(%esp)
c0020dbe:	c0 
c0020dbf:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0020dc6:	00 
c0020dc7:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0020dce:	e8 90 7b 00 00       	call   c0028963 <debug_panic>
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
c0020df0:	c7 44 24 10 0b e5 02 	movl   $0xc002e50b,0x10(%esp)
c0020df7:	c0 
c0020df8:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020dff:	c0 
c0020e00:	c7 44 24 08 96 d0 02 	movl   $0xc002d096,0x8(%esp)
c0020e07:	c0 
c0020e08:	c7 44 24 04 91 01 00 	movl   $0x191,0x4(%esp)
c0020e0f:	00 
c0020e10:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0020e17:	e8 47 7b 00 00       	call   c0028963 <debug_panic>
c0020e1c:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0020e20:	74 2e                	je     c0020e50 <thread_current+0x77>
c0020e22:	eb cc                	jmp    c0020df0 <thread_current+0x17>
  ASSERT (is_thread (t));
c0020e24:	c7 44 24 10 b1 e4 02 	movl   $0xc002e4b1,0x10(%esp)
c0020e2b:	c0 
c0020e2c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020e33:	c0 
c0020e34:	c7 44 24 08 96 d0 02 	movl   $0xc002d096,0x8(%esp)
c0020e3b:	c0 
c0020e3c:	c7 44 24 04 90 01 00 	movl   $0x190,0x4(%esp)
c0020e43:	00 
c0020e44:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0020e4b:	e8 13 7b 00 00       	call   c0028963 <debug_panic>
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
c0020e82:	a1 c0 5b 03 c0       	mov    0xc0035bc0,%eax
c0020e87:	83 c0 01             	add    $0x1,%eax
c0020e8a:	a3 c0 5b 03 c0       	mov    %eax,0xc0035bc0
c0020e8f:	83 f8 03             	cmp    $0x3,%eax
c0020e92:	76 05                	jbe    c0020e99 <thread_tick+0x45>
    intr_yield_on_return ();
c0020e94:	e8 70 0d 00 00       	call   c0021c09 <intr_yield_on_return>
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
c0020ec8:	e8 87 0a 00 00       	call   c0021954 <intr_get_level>
c0020ecd:	85 c0                	test   %eax,%eax
c0020ecf:	74 2c                	je     c0020efd <thread_foreach+0x43>
c0020ed1:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0020ed8:	c0 
c0020ed9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0020ee0:	c0 
c0020ee1:	c7 44 24 08 6e d0 02 	movl   $0xc002d06e,0x8(%esp)
c0020ee8:	c0 
c0020ee9:	c7 44 24 04 d2 01 00 	movl   $0x1d2,0x4(%esp)
c0020ef0:	00 
c0020ef1:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0020ef8:	e8 66 7a 00 00       	call   c0028963 <debug_panic>
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020efd:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f04:	e8 78 7b 00 00       	call   c0028a81 <list_begin>
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
c0020f1c:	e8 9e 7b 00 00       	call   c0028abf <list_next>
c0020f21:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020f23:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020f2a:	e8 e4 7b 00 00       	call   c0028b13 <list_end>
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
  return covert_to_integer_round(i);
c0020f62:	89 04 24             	mov    %eax,(%esp)
c0020f65:	e8 a7 f9 ff ff       	call   c0020911 <covert_to_integer_round>
}
c0020f6a:	83 c4 04             	add    $0x4,%esp
c0020f6d:	c3                   	ret    

c0020f6e <thread_get_recent_cpu>:
{
c0020f6e:	83 ec 1c             	sub    $0x1c,%esp
  int i = multiply_fixed_and_integer(thread_current()->recent_cpu,100);
c0020f71:	e8 63 fe ff ff       	call   c0020dd9 <thread_current>
    return x * n;
c0020f76:	6b 40 58 64          	imul   $0x64,0x58(%eax),%eax
  return covert_to_integer_round(i);
c0020f7a:	89 04 24             	mov    %eax,(%esp)
c0020f7d:	e8 8f f9 ff ff       	call   c0020911 <covert_to_integer_round>
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
c0020f99:	8b 35 30 60 03 c0    	mov    0xc0036030,%esi
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
c0020fd9:	e8 e5 72 00 00       	call   c00282c3 <__divdi3>
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
c0021011:	e8 ad 72 00 00       	call   c00282c3 <__divdi3>
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
  t->priority = PRI_MAX - covert_to_integer_round(t->recent_cpu / 4) - (t->nice * 2);
c0021033:	8b 43 58             	mov    0x58(%ebx),%eax
c0021036:	8d 50 03             	lea    0x3(%eax),%edx
c0021039:	85 c0                	test   %eax,%eax
c002103b:	0f 48 c2             	cmovs  %edx,%eax
c002103e:	c1 f8 02             	sar    $0x2,%eax
c0021041:	89 04 24             	mov    %eax,(%esp)
c0021044:	e8 c8 f8 ff ff       	call   c0020911 <covert_to_integer_round>
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
c0021087:	e8 48 7f 00 00       	call   c0028fd4 <list_remove>
     list_push_back (&mlfqs_list[t->priority], &t->elem);
c002108c:	89 74 24 04          	mov    %esi,0x4(%esp)
c0021090:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021093:	c1 e0 04             	shl    $0x4,%eax
c0021096:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c002109b:	89 04 24             	mov    %eax,(%esp)
c002109e:	e8 0e 7f 00 00       	call   c0028fb1 <list_push_back>
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
c00210c1:	e8 63 7f 00 00       	call   c0029029 <list_size>
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
c0021114:	e8 3b 08 00 00       	call   c0021954 <intr_get_level>
c0021119:	85 c0                	test   %eax,%eax
c002111b:	74 2c                	je     c0021149 <thread_schedule_tail+0x46>
c002111d:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0021124:	c0 
c0021125:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002112c:	c0 
c002112d:	c7 44 24 08 59 d0 02 	movl   $0xc002d059,0x8(%esp)
c0021134:	c0 
c0021135:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
c002113c:	00 
c002113d:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0021144:	e8 1a 78 00 00       	call   c0028963 <debug_panic>
  cur->status = THREAD_RUNNING;
c0021149:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
  thread_ticks = 0;
c0021150:	c7 05 c0 5b 03 c0 00 	movl   $0x0,0xc0035bc0
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
c0021170:	c7 44 24 10 27 e5 02 	movl   $0xc002e527,0x10(%esp)
c0021177:	c0 
c0021178:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002117f:	c0 
c0021180:	c7 44 24 08 59 d0 02 	movl   $0xc002d059,0x8(%esp)
c0021187:	c0 
c0021188:	c7 44 24 04 44 03 00 	movl   $0x344,0x4(%esp)
c002118f:	00 
c0021190:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0021197:	e8 c7 77 00 00       	call   c0028963 <debug_panic>
      palloc_free_page (prev);
c002119c:	89 1c 24             	mov    %ebx,(%esp)
c002119f:	e8 cc 25 00 00       	call   c0023770 <palloc_free_page>
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
  if(!thread_mlfqs)
c00211b8:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c00211bf:	74 0c                	je     c00211cd <schedule+0x23>
c00211c1:	be 10 60 03 c0       	mov    $0xc0036010,%esi
c00211c6:	bb 3f 00 00 00       	mov    $0x3f,%ebx
c00211cb:	eb 4c                	jmp    c0021219 <schedule+0x6f>
    if (list_empty (&ready_list))
c00211cd:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c00211d4:	e8 8d 7e 00 00       	call   c0029066 <list_empty>
      return idle_thread;
c00211d9:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
    if (list_empty (&ready_list))
c00211df:	84 c0                	test   %al,%al
c00211e1:	75 62                	jne    c0021245 <schedule+0x9b>
      struct list_elem *e = list_max (&ready_list,thread_priority_cmp,NULL);
c00211e3:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00211ea:	00 
c00211eb:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c00211f2:	c0 
c00211f3:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c00211fa:	e8 3b 84 00 00       	call   c002963a <list_max>
c00211ff:	89 c3                	mov    %eax,%ebx
      list_remove(e);
c0021201:	89 04 24             	mov    %eax,(%esp)
c0021204:	e8 cb 7d 00 00       	call   c0028fd4 <list_remove>
      return list_entry(e,struct thread,elem);
c0021209:	83 eb 28             	sub    $0x28,%ebx
c002120c:	eb 37                	jmp    c0021245 <schedule+0x9b>
      i--;
c002120e:	83 eb 01             	sub    $0x1,%ebx
c0021211:	83 ee 10             	sub    $0x10,%esi
    while(i>=0 && list_empty(&mlfqs_list[i]))
c0021214:	83 fb ff             	cmp    $0xffffffff,%ebx
c0021217:	74 26                	je     c002123f <schedule+0x95>
c0021219:	89 34 24             	mov    %esi,(%esp)
c002121c:	e8 45 7e 00 00       	call   c0029066 <list_empty>
c0021221:	84 c0                	test   %al,%al
c0021223:	75 e9                	jne    c002120e <schedule+0x64>
    if(i>=0)
c0021225:	85 db                	test   %ebx,%ebx
c0021227:	78 16                	js     c002123f <schedule+0x95>
      return list_entry(list_pop_front (&mlfqs_list[i]), struct thread, elem);
c0021229:	c1 e3 04             	shl    $0x4,%ebx
c002122c:	81 c3 20 5c 03 c0    	add    $0xc0035c20,%ebx
c0021232:	89 1c 24             	mov    %ebx,(%esp)
c0021235:	e8 9a 7e 00 00       	call   c00290d4 <list_pop_front>
c002123a:	8d 58 d8             	lea    -0x28(%eax),%ebx
c002123d:	eb 06                	jmp    c0021245 <schedule+0x9b>
      return idle_thread;
c002123f:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0021245:	e8 0a 07 00 00       	call   c0021954 <intr_get_level>
c002124a:	85 c0                	test   %eax,%eax
c002124c:	74 2c                	je     c002127a <schedule+0xd0>
c002124e:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0021255:	c0 
c0021256:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002125d:	c0 
c002125e:	c7 44 24 08 b4 d0 02 	movl   $0xc002d0b4,0x8(%esp)
c0021265:	c0 
c0021266:	c7 44 24 04 56 03 00 	movl   $0x356,0x4(%esp)
c002126d:	00 
c002126e:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0021275:	e8 e9 76 00 00       	call   c0028963 <debug_panic>
  ASSERT (cur->status != THREAD_RUNNING);
c002127a:	83 7f 04 00          	cmpl   $0x0,0x4(%edi)
c002127e:	75 2c                	jne    c00212ac <schedule+0x102>
c0021280:	c7 44 24 10 33 e5 02 	movl   $0xc002e533,0x10(%esp)
c0021287:	c0 
c0021288:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002128f:	c0 
c0021290:	c7 44 24 08 b4 d0 02 	movl   $0xc002d0b4,0x8(%esp)
c0021297:	c0 
c0021298:	c7 44 24 04 57 03 00 	movl   $0x357,0x4(%esp)
c002129f:	00 
c00212a0:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c00212a7:	e8 b7 76 00 00       	call   c0028963 <debug_panic>
  return t != NULL && t->magic == THREAD_MAGIC;
c00212ac:	85 db                	test   %ebx,%ebx
c00212ae:	74 2c                	je     c00212dc <schedule+0x132>
c00212b0:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c00212b7:	75 23                	jne    c00212dc <schedule+0x132>
c00212b9:	eb 16                	jmp    c00212d1 <schedule+0x127>
    prev = switch_threads (cur, next);
c00212bb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00212bf:	89 3c 24             	mov    %edi,(%esp)
c00212c2:	e8 08 05 00 00       	call   c00217cf <switch_threads>
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
c00212dc:	c7 44 24 10 51 e5 02 	movl   $0xc002e551,0x10(%esp)
c00212e3:	c0 
c00212e4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00212eb:	c0 
c00212ec:	c7 44 24 08 b4 d0 02 	movl   $0xc002d0b4,0x8(%esp)
c00212f3:	c0 
c00212f4:	c7 44 24 04 58 03 00 	movl   $0x358,0x4(%esp)
c00212fb:	00 
c00212fc:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0021303:	e8 5b 76 00 00       	call   c0028963 <debug_panic>
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
c0021312:	e8 ea 08 00 00       	call   c0021c01 <intr_context>
c0021317:	84 c0                	test   %al,%al
c0021319:	74 2c                	je     c0021347 <thread_block+0x38>
c002131b:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c0021322:	c0 
c0021323:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002132a:	c0 
c002132b:	c7 44 24 08 bd d0 02 	movl   $0xc002d0bd,0x8(%esp)
c0021332:	c0 
c0021333:	c7 44 24 04 53 01 00 	movl   $0x153,0x4(%esp)
c002133a:	00 
c002133b:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0021342:	e8 1c 76 00 00       	call   c0028963 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0021347:	e8 08 06 00 00       	call   c0021954 <intr_get_level>
c002134c:	85 c0                	test   %eax,%eax
c002134e:	74 2c                	je     c002137c <thread_block+0x6d>
c0021350:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0021357:	c0 
c0021358:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002135f:	c0 
c0021360:	c7 44 24 08 bd d0 02 	movl   $0xc002d0bd,0x8(%esp)
c0021367:	c0 
c0021368:	c7 44 24 04 54 01 00 	movl   $0x154,0x4(%esp)
c002136f:	00 
c0021370:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0021377:	e8 e7 75 00 00       	call   c0028963 <debug_panic>
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
c00213a5:	e8 7d 18 00 00       	call   c0022c27 <sema_up>
      intr_disable ();
c00213aa:	e8 f0 05 00 00       	call   c002199f <intr_disable>
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
c00213bb:	e8 41 08 00 00       	call   c0021c01 <intr_context>
c00213c0:	84 c0                	test   %al,%al
c00213c2:	74 2c                	je     c00213f0 <thread_exit+0x38>
c00213c4:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c00213cb:	c0 
c00213cc:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00213d3:	c0 
c00213d4:	c7 44 24 08 8a d0 02 	movl   $0xc002d08a,0x8(%esp)
c00213db:	c0 
c00213dc:	c7 44 24 04 a2 01 00 	movl   $0x1a2,0x4(%esp)
c00213e3:	00 
c00213e4:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c00213eb:	e8 73 75 00 00       	call   c0028963 <debug_panic>
  intr_disable ();
c00213f0:	e8 aa 05 00 00       	call   c002199f <intr_disable>
  list_remove (&thread_current()->allelem);
c00213f5:	e8 df f9 ff ff       	call   c0020dd9 <thread_current>
c00213fa:	83 c0 20             	add    $0x20,%eax
c00213fd:	89 04 24             	mov    %eax,(%esp)
c0021400:	e8 cf 7b 00 00       	call   c0028fd4 <list_remove>
  thread_current ()->status = THREAD_DYING;
c0021405:	e8 cf f9 ff ff       	call   c0020dd9 <thread_current>
c002140a:	c7 40 04 03 00 00 00 	movl   $0x3,0x4(%eax)
  schedule ();
c0021411:	e8 94 fd ff ff       	call   c00211aa <schedule>
  NOT_REACHED ();
c0021416:	c7 44 24 0c f8 e5 02 	movl   $0xc002e5f8,0xc(%esp)
c002141d:	c0 
c002141e:	c7 44 24 08 8a d0 02 	movl   $0xc002d08a,0x8(%esp)
c0021425:	c0 
c0021426:	c7 44 24 04 af 01 00 	movl   $0x1af,0x4(%esp)
c002142d:	00 
c002142e:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c0021435:	e8 29 75 00 00       	call   c0028963 <debug_panic>

c002143a <kernel_thread>:
{
c002143a:	53                   	push   %ebx
c002143b:	83 ec 28             	sub    $0x28,%esp
c002143e:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (function != NULL);
c0021442:	85 db                	test   %ebx,%ebx
c0021444:	75 2c                	jne    c0021472 <kernel_thread+0x38>
c0021446:	c7 44 24 10 73 e5 02 	movl   $0xc002e573,0x10(%esp)
c002144d:	c0 
c002144e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021455:	c0 
c0021456:	c7 44 24 08 d6 d0 02 	movl   $0xc002d0d6,0x8(%esp)
c002145d:	c0 
c002145e:	c7 44 24 04 ad 02 00 	movl   $0x2ad,0x4(%esp)
c0021465:	00 
c0021466:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c002146d:	e8 f1 74 00 00       	call   c0028963 <debug_panic>
  intr_enable ();       /* The scheduler runs with interrupts off. */
c0021472:	e8 e6 04 00 00       	call   c002195d <intr_enable>
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
c0021491:	e8 6b 07 00 00       	call   c0021c01 <intr_context>
c0021496:	84 c0                	test   %al,%al
c0021498:	74 2c                	je     c00214c6 <thread_yield+0x41>
c002149a:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c00214a1:	c0 
c00214a2:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00214a9:	c0 
c00214aa:	c7 44 24 08 7d d0 02 	movl   $0xc002d07d,0x8(%esp)
c00214b1:	c0 
c00214b2:	c7 44 24 04 ba 01 00 	movl   $0x1ba,0x4(%esp)
c00214b9:	00 
c00214ba:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c00214c1:	e8 9d 74 00 00       	call   c0028963 <debug_panic>
  old_level = intr_disable ();
c00214c6:	e8 d4 04 00 00       	call   c002199f <intr_disable>
c00214cb:	89 c6                	mov    %eax,%esi
  if (cur != idle_thread) 
c00214cd:	3b 1d 08 5c 03 c0    	cmp    0xc0035c08,%ebx
c00214d3:	74 38                	je     c002150d <thread_yield+0x88>
    if(!thread_mlfqs)
c00214d5:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c00214dc:	75 15                	jne    c00214f3 <thread_yield+0x6e>
      list_push_back (&ready_list, &cur->elem);
c00214de:	8d 43 28             	lea    0x28(%ebx),%eax
c00214e1:	89 44 24 04          	mov    %eax,0x4(%esp)
c00214e5:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c00214ec:	e8 c0 7a 00 00       	call   c0028fb1 <list_push_back>
c00214f1:	eb 1a                	jmp    c002150d <thread_yield+0x88>
      list_push_back (&mlfqs_list[cur->priority], &cur->elem);
c00214f3:	8d 43 28             	lea    0x28(%ebx),%eax
c00214f6:	89 44 24 04          	mov    %eax,0x4(%esp)
c00214fa:	8b 43 1c             	mov    0x1c(%ebx),%eax
c00214fd:	c1 e0 04             	shl    $0x4,%eax
c0021500:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c0021505:	89 04 24             	mov    %eax,(%esp)
c0021508:	e8 a4 7a 00 00       	call   c0028fb1 <list_push_back>
  cur->status = THREAD_READY;
c002150d:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  schedule ();
c0021514:	e8 91 fc ff ff       	call   c00211aa <schedule>
  intr_set_level (old_level);
c0021519:	89 34 24             	mov    %esi,(%esp)
c002151c:	e8 85 04 00 00       	call   c00219a6 <intr_set_level>
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
c0021536:	c7 44 24 10 73 e5 02 	movl   $0xc002e573,0x10(%esp)
c002153d:	c0 
c002153e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021545:	c0 
c0021546:	c7 44 24 08 e4 d0 02 	movl   $0xc002d0e4,0x8(%esp)
c002154d:	c0 
c002154e:	c7 44 24 04 1d 01 00 	movl   $0x11d,0x4(%esp)
c0021555:	00 
c0021556:	c7 04 24 9a e4 02 c0 	movl   $0xc002e49a,(%esp)
c002155d:	e8 01 74 00 00       	call   c0028963 <debug_panic>
  t = palloc_get_page (PAL_ZERO);
c0021562:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c0021569:	e8 98 20 00 00       	call   c0023606 <palloc_get_page>
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
c00215a4:	e8 91 18 00 00       	call   c0022e3a <lock_acquire>
  tid = next_tid++;
c00215a9:	8b 35 48 56 03 c0    	mov    0xc0035648,%esi
c00215af:	8d 46 01             	lea    0x1(%esi),%eax
c00215b2:	a3 48 56 03 c0       	mov    %eax,0xc0035648
  lock_release (&tid_lock);
c00215b7:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c00215be:	e8 41 1a 00 00       	call   c0023004 <lock_release>
  tid = t->tid = allocate_tid ();
c00215c3:	89 33                	mov    %esi,(%ebx)
  old_level = intr_disable ();
c00215c5:	e8 d5 03 00 00       	call   c002199f <intr_disable>
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
c0021606:	c7 40 10 ec 17 02 c0 	movl   $0xc00217ec,0x10(%eax)
  sf->ebp = 0;
c002160d:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
  intr_set_level (old_level);
c0021614:	89 2c 24             	mov    %ebp,(%esp)
c0021617:	e8 8a 03 00 00       	call   c00219a6 <intr_set_level>
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
c002165e:	e8 63 14 00 00       	call   c0022ac6 <sema_init>
  thread_create ("idle", PRI_MIN, idle, &idle_started);
c0021663:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0021667:	c7 44 24 08 91 13 02 	movl   $0xc0021391,0x8(%esp)
c002166e:	c0 
c002166f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0021676:	00 
c0021677:	c7 04 24 84 e5 02 c0 	movl   $0xc002e584,(%esp)
c002167e:	e8 a4 fe ff ff       	call   c0021527 <thread_create>
  intr_enable ();
c0021683:	e8 d5 02 00 00       	call   c002195d <intr_enable>
  sema_down (&idle_started);
c0021688:	89 1c 24             	mov    %ebx,(%esp)
c002168b:	e8 82 14 00 00       	call   c0022b12 <sema_down>
}
c0021690:	83 c4 38             	add    $0x38,%esp
c0021693:	5b                   	pop    %ebx
c0021694:	c3                   	ret    

c0021695 <thread_set_priority>:
  if(thread_mlfqs)
c0021695:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002169c:	0f 85 94 00 00 00    	jne    c0021736 <thread_set_priority+0xa1>
{
c00216a2:	53                   	push   %ebx
c00216a3:	83 ec 18             	sub    $0x18,%esp
  old_level = intr_disable ();
c00216a6:	e8 f4 02 00 00       	call   c002199f <intr_disable>
c00216ab:	89 c3                	mov    %eax,%ebx
  if(new_priority <= PRI_MAX && new_priority >= PRI_MIN)
c00216ad:	83 7c 24 20 3f       	cmpl   $0x3f,0x20(%esp)
c00216b2:	77 7e                	ja     c0021732 <thread_set_priority+0x9d>
    if(new_priority > thread_current ()->priority)
c00216b4:	e8 20 f7 ff ff       	call   c0020dd9 <thread_current>
c00216b9:	89 c2                	mov    %eax,%edx
c00216bb:	8b 40 1c             	mov    0x1c(%eax),%eax
c00216be:	39 44 24 20          	cmp    %eax,0x20(%esp)
c00216c2:	7e 15                	jle    c00216d9 <thread_set_priority+0x44>
      thread_current ()->priority = new_priority;
c00216c4:	8b 44 24 20          	mov    0x20(%esp),%eax
c00216c8:	89 42 1c             	mov    %eax,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c00216cb:	e8 09 f7 ff ff       	call   c0020dd9 <thread_current>
c00216d0:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c00216d4:	89 48 3c             	mov    %ecx,0x3c(%eax)
c00216d7:	eb 21                	jmp    c00216fa <thread_set_priority+0x65>
    else if(thread_current ()->priority == thread_current ()->old_priority)
c00216d9:	3b 42 3c             	cmp    0x3c(%edx),%eax
c00216dc:	75 15                	jne    c00216f3 <thread_set_priority+0x5e>
      thread_current ()->priority = new_priority;
c00216de:	8b 44 24 20          	mov    0x20(%esp),%eax
c00216e2:	89 42 1c             	mov    %eax,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c00216e5:	e8 ef f6 ff ff       	call   c0020dd9 <thread_current>
c00216ea:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c00216ee:	89 48 3c             	mov    %ecx,0x3c(%eax)
c00216f1:	eb 07                	jmp    c00216fa <thread_set_priority+0x65>
      thread_current ()->old_priority = new_priority;
c00216f3:	8b 44 24 20          	mov    0x20(%esp),%eax
c00216f7:	89 42 3c             	mov    %eax,0x3c(%edx)
    intr_set_level (old_level);
c00216fa:	89 1c 24             	mov    %ebx,(%esp)
c00216fd:	e8 a4 02 00 00       	call   c00219a6 <intr_set_level>
    t = list_entry(list_max (&ready_list,thread_priority_cmp,NULL),struct thread,elem)->priority;
c0021702:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0021709:	00 
c002170a:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c0021711:	c0 
c0021712:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0021719:	e8 1c 7f 00 00       	call   c002963a <list_max>
c002171e:	89 c3                	mov    %eax,%ebx
    if(t > thread_current ()->priority)
c0021720:	e8 b4 f6 ff ff       	call   c0020dd9 <thread_current>
c0021725:	8b 40 1c             	mov    0x1c(%eax),%eax
c0021728:	39 43 f4             	cmp    %eax,-0xc(%ebx)
c002172b:	7e 05                	jle    c0021732 <thread_set_priority+0x9d>
      thread_yield();
c002172d:	e8 53 fd ff ff       	call   c0021485 <thread_yield>
}
c0021732:	83 c4 18             	add    $0x18,%esp
c0021735:	5b                   	pop    %ebx
c0021736:	f3 c3                	repz ret 

c0021738 <thread_set_nice>:
{
c0021738:	57                   	push   %edi
c0021739:	56                   	push   %esi
c002173a:	53                   	push   %ebx
c002173b:	83 ec 10             	sub    $0x10,%esp
c002173e:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread *cur = thread_current();
c0021742:	e8 92 f6 ff ff       	call   c0020dd9 <thread_current>
c0021747:	89 c7                	mov    %eax,%edi
  if(nice >= -20 && nice <= 20)
c0021749:	8d 43 14             	lea    0x14(%ebx),%eax
c002174c:	83 f8 28             	cmp    $0x28,%eax
c002174f:	77 03                	ja     c0021754 <thread_set_nice+0x1c>
    cur->nice = nice;
c0021751:	89 5f 54             	mov    %ebx,0x54(%edi)
  cur->priority = PRI_MAX - covert_to_integer_round(cur->recent_cpu / 4) - (cur->nice * 2);
c0021754:	8b 47 58             	mov    0x58(%edi),%eax
c0021757:	8d 50 03             	lea    0x3(%eax),%edx
c002175a:	85 c0                	test   %eax,%eax
c002175c:	0f 48 c2             	cmovs  %edx,%eax
c002175f:	c1 f8 02             	sar    $0x2,%eax
c0021762:	89 04 24             	mov    %eax,(%esp)
c0021765:	e8 a7 f1 ff ff       	call   c0020911 <covert_to_integer_round>
c002176a:	ba 3f 00 00 00       	mov    $0x3f,%edx
c002176f:	29 c2                	sub    %eax,%edx
c0021771:	89 d0                	mov    %edx,%eax
c0021773:	8b 57 54             	mov    0x54(%edi),%edx
c0021776:	f7 da                	neg    %edx
c0021778:	8d 04 50             	lea    (%eax,%edx,2),%eax
c002177b:	89 47 1c             	mov    %eax,0x1c(%edi)
  if(cur->priority > PRI_MAX)
c002177e:	83 f8 3f             	cmp    $0x3f,%eax
c0021781:	7e 09                	jle    c002178c <thread_set_nice+0x54>
    cur->priority = PRI_MAX;
c0021783:	c7 47 1c 3f 00 00 00 	movl   $0x3f,0x1c(%edi)
c002178a:	eb 30                	jmp    c00217bc <thread_set_nice+0x84>
  if(cur->priority < PRI_MIN)
c002178c:	85 c0                	test   %eax,%eax
c002178e:	79 2c                	jns    c00217bc <thread_set_nice+0x84>
    cur->priority = PRI_MIN;
c0021790:	c7 47 1c 00 00 00 00 	movl   $0x0,0x1c(%edi)
c0021797:	eb 23                	jmp    c00217bc <thread_set_nice+0x84>
    i--;
c0021799:	83 eb 01             	sub    $0x1,%ebx
c002179c:	83 ee 10             	sub    $0x10,%esi
  while(i>=0 && list_empty(&mlfqs_list[i]))
c002179f:	83 fb ff             	cmp    $0xffffffff,%ebx
c00217a2:	74 0c                	je     c00217b0 <thread_set_nice+0x78>
c00217a4:	89 34 24             	mov    %esi,(%esp)
c00217a7:	e8 ba 78 00 00       	call   c0029066 <list_empty>
c00217ac:	84 c0                	test   %al,%al
c00217ae:	75 e9                	jne    c0021799 <thread_set_nice+0x61>
  if(cur->priority < i)
c00217b0:	39 5f 1c             	cmp    %ebx,0x1c(%edi)
c00217b3:	7d 13                	jge    c00217c8 <thread_set_nice+0x90>
    thread_yield();
c00217b5:	e8 cb fc ff ff       	call   c0021485 <thread_yield>
c00217ba:	eb 0c                	jmp    c00217c8 <thread_set_nice+0x90>
c00217bc:	be 10 60 03 c0       	mov    $0xc0036010,%esi
{
c00217c1:	bb 3f 00 00 00       	mov    $0x3f,%ebx
c00217c6:	eb dc                	jmp    c00217a4 <thread_set_nice+0x6c>
}
c00217c8:	83 c4 10             	add    $0x10,%esp
c00217cb:	5b                   	pop    %ebx
c00217cc:	5e                   	pop    %esi
c00217cd:	5f                   	pop    %edi
c00217ce:	c3                   	ret    

c00217cf <switch_threads>:
	# but requires us to preserve %ebx, %ebp, %esi, %edi.  See
	# [SysV-ABI-386] pages 3-11 and 3-12 for details.
	#
	# This stack frame must match the one set up by thread_create()
	# in size.
	pushl %ebx
c00217cf:	53                   	push   %ebx
	pushl %ebp
c00217d0:	55                   	push   %ebp
	pushl %esi
c00217d1:	56                   	push   %esi
	pushl %edi
c00217d2:	57                   	push   %edi

	# Get offsetof (struct thread, stack).
.globl thread_stack_ofs
	mov thread_stack_ofs, %edx
c00217d3:	8b 15 4c 56 03 c0    	mov    0xc003564c,%edx

	# Save current stack pointer to old thread's stack, if any.
	movl SWITCH_CUR(%esp), %eax
c00217d9:	8b 44 24 14          	mov    0x14(%esp),%eax
	movl %esp, (%eax,%edx,1)
c00217dd:	89 24 10             	mov    %esp,(%eax,%edx,1)

	# Restore stack pointer from new thread's stack.
	movl SWITCH_NEXT(%esp), %ecx
c00217e0:	8b 4c 24 18          	mov    0x18(%esp),%ecx
	movl (%ecx,%edx,1), %esp
c00217e4:	8b 24 11             	mov    (%ecx,%edx,1),%esp

	# Restore caller's register state.
	popl %edi
c00217e7:	5f                   	pop    %edi
	popl %esi
c00217e8:	5e                   	pop    %esi
	popl %ebp
c00217e9:	5d                   	pop    %ebp
	popl %ebx
c00217ea:	5b                   	pop    %ebx
        ret
c00217eb:	c3                   	ret    

c00217ec <switch_entry>:

.globl switch_entry
.func switch_entry
switch_entry:
	# Discard switch_threads() arguments.
	addl $8, %esp
c00217ec:	83 c4 08             	add    $0x8,%esp

	# Call thread_schedule_tail(prev).
	pushl %eax
c00217ef:	50                   	push   %eax
.globl thread_schedule_tail
	call thread_schedule_tail
c00217f0:	e8 0e f9 ff ff       	call   c0021103 <thread_schedule_tail>
	addl $4, %esp
c00217f5:	83 c4 04             	add    $0x4,%esp

	# Start thread proper.
	ret
c00217f8:	c3                   	ret    
c00217f9:	90                   	nop
c00217fa:	90                   	nop
c00217fb:	90                   	nop
c00217fc:	90                   	nop
c00217fd:	90                   	nop
c00217fe:	90                   	nop
c00217ff:	90                   	nop

c0021800 <make_gate>:
   disables interrupts, but entering a trap gate does not.  See
   [IA32-v3a] section 5.12.1.2 "Flag Usage By Exception- or
   Interrupt-Handler Procedure" for discussion. */
static uint64_t
make_gate (void (*function) (void), int dpl, int type)
{
c0021800:	53                   	push   %ebx
c0021801:	83 ec 28             	sub    $0x28,%esp
  uint32_t e0, e1;

  ASSERT (function != NULL);
c0021804:	85 c0                	test   %eax,%eax
c0021806:	75 2c                	jne    c0021834 <make_gate+0x34>
c0021808:	c7 44 24 10 73 e5 02 	movl   $0xc002e573,0x10(%esp)
c002180f:	c0 
c0021810:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021817:	c0 
c0021818:	c7 44 24 08 76 d1 02 	movl   $0xc002d176,0x8(%esp)
c002181f:	c0 
c0021820:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0021827:	00 
c0021828:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c002182f:	e8 2f 71 00 00       	call   c0028963 <debug_panic>
  ASSERT (dpl >= 0 && dpl <= 3);
c0021834:	83 fa 03             	cmp    $0x3,%edx
c0021837:	76 2c                	jbe    c0021865 <make_gate+0x65>
c0021839:	c7 44 24 10 34 e6 02 	movl   $0xc002e634,0x10(%esp)
c0021840:	c0 
c0021841:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021848:	c0 
c0021849:	c7 44 24 08 76 d1 02 	movl   $0xc002d176,0x8(%esp)
c0021850:	c0 
c0021851:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0021858:	00 
c0021859:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021860:	e8 fe 70 00 00       	call   c0028963 <debug_panic>
  ASSERT (type >= 0 && type <= 15);
c0021865:	83 f9 0f             	cmp    $0xf,%ecx
c0021868:	76 2c                	jbe    c0021896 <make_gate+0x96>
c002186a:	c7 44 24 10 49 e6 02 	movl   $0xc002e649,0x10(%esp)
c0021871:	c0 
c0021872:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021879:	c0 
c002187a:	c7 44 24 08 76 d1 02 	movl   $0xc002d176,0x8(%esp)
c0021881:	c0 
c0021882:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
c0021889:	00 
c002188a:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021891:	e8 cd 70 00 00       	call   c0028963 <debug_panic>

  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
        | (1 << 15)                        /* Present. */
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
        | (0 << 12)                        /* System. */
        | ((uint32_t) type << 8));         /* Gate type. */
c0021896:	c1 e1 08             	shl    $0x8,%ecx
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
c0021899:	80 cd 80             	or     $0x80,%ch
c002189c:	89 d3                	mov    %edx,%ebx
c002189e:	c1 e3 0d             	shl    $0xd,%ebx
        | ((uint32_t) type << 8));         /* Gate type. */
c00218a1:	09 d9                	or     %ebx,%ecx
c00218a3:	89 ca                	mov    %ecx,%edx
  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
c00218a5:	89 c3                	mov    %eax,%ebx
c00218a7:	66 bb 00 00          	mov    $0x0,%bx
c00218ab:	09 da                	or     %ebx,%edx
  e0 = (((uint32_t) function & 0xffff)     /* Offset 15:0. */
c00218ad:	0f b7 c0             	movzwl %ax,%eax
c00218b0:	0d 00 00 08 00       	or     $0x80000,%eax

  return e0 | ((uint64_t) e1 << 32);
}
c00218b5:	83 c4 28             	add    $0x28,%esp
c00218b8:	5b                   	pop    %ebx
c00218b9:	c3                   	ret    

c00218ba <register_handler>:
{
c00218ba:	53                   	push   %ebx
c00218bb:	83 ec 28             	sub    $0x28,%esp
  ASSERT (intr_handlers[vec_no] == NULL);
c00218be:	0f b6 d8             	movzbl %al,%ebx
c00218c1:	83 3c 9d 60 68 03 c0 	cmpl   $0x0,-0x3ffc97a0(,%ebx,4)
c00218c8:	00 
c00218c9:	74 2c                	je     c00218f7 <register_handler+0x3d>
c00218cb:	c7 44 24 10 61 e6 02 	movl   $0xc002e661,0x10(%esp)
c00218d2:	c0 
c00218d3:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00218da:	c0 
c00218db:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c00218e2:	c0 
c00218e3:	c7 44 24 04 a8 00 00 	movl   $0xa8,0x4(%esp)
c00218ea:	00 
c00218eb:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c00218f2:	e8 6c 70 00 00       	call   c0028963 <debug_panic>
  if (level == INTR_ON)
c00218f7:	83 f9 01             	cmp    $0x1,%ecx
c00218fa:	75 1e                	jne    c002191a <register_handler+0x60>
/* Creates a trap gate that invokes FUNCTION with the given
   DPL. */
static uint64_t
make_trap_gate (void (*function) (void), int dpl)
{
  return make_gate (function, dpl, 15);
c00218fc:	8b 04 9d 50 56 03 c0 	mov    -0x3ffca9b0(,%ebx,4),%eax
c0021903:	b1 0f                	mov    $0xf,%cl
c0021905:	e8 f6 fe ff ff       	call   c0021800 <make_gate>
    idt[vec_no] = make_trap_gate (intr_stubs[vec_no], dpl);
c002190a:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021911:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
c0021918:	eb 1f                	jmp    c0021939 <register_handler+0x7f>
  return make_gate (function, dpl, 14);
c002191a:	8b 04 9d 50 56 03 c0 	mov    -0x3ffca9b0(,%ebx,4),%eax
c0021921:	b9 0e 00 00 00       	mov    $0xe,%ecx
c0021926:	e8 d5 fe ff ff       	call   c0021800 <make_gate>
    idt[vec_no] = make_intr_gate (intr_stubs[vec_no], dpl);
c002192b:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021932:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  intr_handlers[vec_no] = handler;
c0021939:	8b 44 24 30          	mov    0x30(%esp),%eax
c002193d:	89 04 9d 60 68 03 c0 	mov    %eax,-0x3ffc97a0(,%ebx,4)
  intr_names[vec_no] = name;
c0021944:	8b 44 24 34          	mov    0x34(%esp),%eax
c0021948:	89 04 9d 60 64 03 c0 	mov    %eax,-0x3ffc9ba0(,%ebx,4)
}
c002194f:	83 c4 28             	add    $0x28,%esp
c0021952:	5b                   	pop    %ebx
c0021953:	c3                   	ret    

c0021954 <intr_get_level>:
  asm volatile ("pushfl; popl %0" : "=g" (flags));
c0021954:	9c                   	pushf  
c0021955:	58                   	pop    %eax
  return flags & FLAG_IF ? INTR_ON : INTR_OFF;
c0021956:	c1 e8 09             	shr    $0x9,%eax
c0021959:	83 e0 01             	and    $0x1,%eax
}
c002195c:	c3                   	ret    

c002195d <intr_enable>:
{
c002195d:	83 ec 2c             	sub    $0x2c,%esp
  enum intr_level old_level = intr_get_level ();
c0021960:	e8 ef ff ff ff       	call   c0021954 <intr_get_level>
  ASSERT (!intr_context ());
c0021965:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c002196c:	74 2c                	je     c002199a <intr_enable+0x3d>
c002196e:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c0021975:	c0 
c0021976:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002197d:	c0 
c002197e:	c7 44 24 08 80 d1 02 	movl   $0xc002d180,0x8(%esp)
c0021985:	c0 
c0021986:	c7 44 24 04 5b 00 00 	movl   $0x5b,0x4(%esp)
c002198d:	00 
c002198e:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021995:	e8 c9 6f 00 00       	call   c0028963 <debug_panic>
  asm volatile ("sti");
c002199a:	fb                   	sti    
}
c002199b:	83 c4 2c             	add    $0x2c,%esp
c002199e:	c3                   	ret    

c002199f <intr_disable>:
  enum intr_level old_level = intr_get_level ();
c002199f:	e8 b0 ff ff ff       	call   c0021954 <intr_get_level>
  asm volatile ("cli" : : : "memory");
c00219a4:	fa                   	cli    
}
c00219a5:	c3                   	ret    

c00219a6 <intr_set_level>:
{
c00219a6:	83 ec 0c             	sub    $0xc,%esp
  return level == INTR_ON ? intr_enable () : intr_disable ();
c00219a9:	83 7c 24 10 01       	cmpl   $0x1,0x10(%esp)
c00219ae:	75 07                	jne    c00219b7 <intr_set_level+0x11>
c00219b0:	e8 a8 ff ff ff       	call   c002195d <intr_enable>
c00219b5:	eb 05                	jmp    c00219bc <intr_set_level+0x16>
c00219b7:	e8 e3 ff ff ff       	call   c002199f <intr_disable>
}
c00219bc:	83 c4 0c             	add    $0xc,%esp
c00219bf:	90                   	nop
c00219c0:	c3                   	ret    

c00219c1 <intr_init>:
{
c00219c1:	53                   	push   %ebx
c00219c2:	83 ec 18             	sub    $0x18,%esp
/* Writes byte DATA to PORT. */
static inline void
outb (uint16_t port, uint8_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00219c5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c00219ca:	e6 21                	out    %al,$0x21
c00219cc:	e6 a1                	out    %al,$0xa1
c00219ce:	b8 11 00 00 00       	mov    $0x11,%eax
c00219d3:	e6 20                	out    %al,$0x20
c00219d5:	b8 20 00 00 00       	mov    $0x20,%eax
c00219da:	e6 21                	out    %al,$0x21
c00219dc:	b8 04 00 00 00       	mov    $0x4,%eax
c00219e1:	e6 21                	out    %al,$0x21
c00219e3:	b8 01 00 00 00       	mov    $0x1,%eax
c00219e8:	e6 21                	out    %al,$0x21
c00219ea:	b8 11 00 00 00       	mov    $0x11,%eax
c00219ef:	e6 a0                	out    %al,$0xa0
c00219f1:	b8 28 00 00 00       	mov    $0x28,%eax
c00219f6:	e6 a1                	out    %al,$0xa1
c00219f8:	b8 02 00 00 00       	mov    $0x2,%eax
c00219fd:	e6 a1                	out    %al,$0xa1
c00219ff:	b8 01 00 00 00       	mov    $0x1,%eax
c0021a04:	e6 a1                	out    %al,$0xa1
c0021a06:	b8 00 00 00 00       	mov    $0x0,%eax
c0021a0b:	e6 21                	out    %al,$0x21
c0021a0d:	e6 a1                	out    %al,$0xa1
  for (i = 0; i < INTR_CNT; i++)
c0021a0f:	bb 00 00 00 00       	mov    $0x0,%ebx
  return make_gate (function, dpl, 14);
c0021a14:	8b 04 9d 50 56 03 c0 	mov    -0x3ffca9b0(,%ebx,4),%eax
c0021a1b:	b9 0e 00 00 00       	mov    $0xe,%ecx
c0021a20:	ba 00 00 00 00       	mov    $0x0,%edx
c0021a25:	e8 d6 fd ff ff       	call   c0021800 <make_gate>
    idt[i] = make_intr_gate (intr_stubs[i], 0);
c0021a2a:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c0021a31:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  for (i = 0; i < INTR_CNT; i++)
c0021a38:	83 c3 01             	add    $0x1,%ebx
c0021a3b:	81 fb 00 01 00 00    	cmp    $0x100,%ebx
c0021a41:	75 d1                	jne    c0021a14 <intr_init+0x53>
/* Returns a descriptor that yields the given LIMIT and BASE when
   used as an operand for the LIDT instruction. */
static inline uint64_t
make_idtr_operand (uint16_t limit, void *base)
{
  return limit | ((uint64_t) (uint32_t) base << 16);
c0021a43:	b8 60 6c 03 c0       	mov    $0xc0036c60,%eax
c0021a48:	ba 00 00 00 00       	mov    $0x0,%edx
c0021a4d:	0f a4 c2 10          	shld   $0x10,%eax,%edx
c0021a51:	c1 e0 10             	shl    $0x10,%eax
c0021a54:	0d ff 07 00 00       	or     $0x7ff,%eax
c0021a59:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021a5d:	89 54 24 0c          	mov    %edx,0xc(%esp)
  asm volatile ("lidt %0" : : "m" (idtr_operand));
c0021a61:	0f 01 5c 24 08       	lidtl  0x8(%esp)
  for (i = 0; i < INTR_CNT; i++)
c0021a66:	b8 00 00 00 00       	mov    $0x0,%eax
    intr_names[i] = "unknown";
c0021a6b:	c7 04 85 60 64 03 c0 	movl   $0xc002e67f,-0x3ffc9ba0(,%eax,4)
c0021a72:	7f e6 02 c0 
  for (i = 0; i < INTR_CNT; i++)
c0021a76:	83 c0 01             	add    $0x1,%eax
c0021a79:	3d 00 01 00 00       	cmp    $0x100,%eax
c0021a7e:	75 eb                	jne    c0021a6b <intr_init+0xaa>
  intr_names[0] = "#DE Divide Error";
c0021a80:	c7 05 60 64 03 c0 87 	movl   $0xc002e687,0xc0036460
c0021a87:	e6 02 c0 
  intr_names[1] = "#DB Debug Exception";
c0021a8a:	c7 05 64 64 03 c0 98 	movl   $0xc002e698,0xc0036464
c0021a91:	e6 02 c0 
  intr_names[2] = "NMI Interrupt";
c0021a94:	c7 05 68 64 03 c0 ac 	movl   $0xc002e6ac,0xc0036468
c0021a9b:	e6 02 c0 
  intr_names[3] = "#BP Breakpoint Exception";
c0021a9e:	c7 05 6c 64 03 c0 ba 	movl   $0xc002e6ba,0xc003646c
c0021aa5:	e6 02 c0 
  intr_names[4] = "#OF Overflow Exception";
c0021aa8:	c7 05 70 64 03 c0 d3 	movl   $0xc002e6d3,0xc0036470
c0021aaf:	e6 02 c0 
  intr_names[5] = "#BR BOUND Range Exceeded Exception";
c0021ab2:	c7 05 74 64 03 c0 10 	movl   $0xc002e810,0xc0036474
c0021ab9:	e8 02 c0 
  intr_names[6] = "#UD Invalid Opcode Exception";
c0021abc:	c7 05 78 64 03 c0 ea 	movl   $0xc002e6ea,0xc0036478
c0021ac3:	e6 02 c0 
  intr_names[7] = "#NM Device Not Available Exception";
c0021ac6:	c7 05 7c 64 03 c0 34 	movl   $0xc002e834,0xc003647c
c0021acd:	e8 02 c0 
  intr_names[8] = "#DF Double Fault Exception";
c0021ad0:	c7 05 80 64 03 c0 07 	movl   $0xc002e707,0xc0036480
c0021ad7:	e7 02 c0 
  intr_names[9] = "Coprocessor Segment Overrun";
c0021ada:	c7 05 84 64 03 c0 22 	movl   $0xc002e722,0xc0036484
c0021ae1:	e7 02 c0 
  intr_names[10] = "#TS Invalid TSS Exception";
c0021ae4:	c7 05 88 64 03 c0 3e 	movl   $0xc002e73e,0xc0036488
c0021aeb:	e7 02 c0 
  intr_names[11] = "#NP Segment Not Present";
c0021aee:	c7 05 8c 64 03 c0 58 	movl   $0xc002e758,0xc003648c
c0021af5:	e7 02 c0 
  intr_names[12] = "#SS Stack Fault Exception";
c0021af8:	c7 05 90 64 03 c0 70 	movl   $0xc002e770,0xc0036490
c0021aff:	e7 02 c0 
  intr_names[13] = "#GP General Protection Exception";
c0021b02:	c7 05 94 64 03 c0 58 	movl   $0xc002e858,0xc0036494
c0021b09:	e8 02 c0 
  intr_names[14] = "#PF Page-Fault Exception";
c0021b0c:	c7 05 98 64 03 c0 8a 	movl   $0xc002e78a,0xc0036498
c0021b13:	e7 02 c0 
  intr_names[16] = "#MF x87 FPU Floating-Point Error";
c0021b16:	c7 05 a0 64 03 c0 7c 	movl   $0xc002e87c,0xc00364a0
c0021b1d:	e8 02 c0 
  intr_names[17] = "#AC Alignment Check Exception";
c0021b20:	c7 05 a4 64 03 c0 a3 	movl   $0xc002e7a3,0xc00364a4
c0021b27:	e7 02 c0 
  intr_names[18] = "#MC Machine-Check Exception";
c0021b2a:	c7 05 a8 64 03 c0 c1 	movl   $0xc002e7c1,0xc00364a8
c0021b31:	e7 02 c0 
  intr_names[19] = "#XF SIMD Floating-Point Exception";
c0021b34:	c7 05 ac 64 03 c0 a0 	movl   $0xc002e8a0,0xc00364ac
c0021b3b:	e8 02 c0 
}
c0021b3e:	83 c4 18             	add    $0x18,%esp
c0021b41:	5b                   	pop    %ebx
c0021b42:	c3                   	ret    

c0021b43 <intr_register_ext>:
{
c0021b43:	83 ec 2c             	sub    $0x2c,%esp
c0021b46:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no >= 0x20 && vec_no <= 0x2f);
c0021b4a:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021b4d:	80 fa 0f             	cmp    $0xf,%dl
c0021b50:	76 2c                	jbe    c0021b7e <intr_register_ext+0x3b>
c0021b52:	c7 44 24 10 c4 e8 02 	movl   $0xc002e8c4,0x10(%esp)
c0021b59:	c0 
c0021b5a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021b61:	c0 
c0021b62:	c7 44 24 08 64 d1 02 	movl   $0xc002d164,0x8(%esp)
c0021b69:	c0 
c0021b6a:	c7 44 24 04 b8 00 00 	movl   $0xb8,0x4(%esp)
c0021b71:	00 
c0021b72:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021b79:	e8 e5 6d 00 00       	call   c0028963 <debug_panic>
  register_handler (vec_no, 0, INTR_OFF, handler, name);
c0021b7e:	0f b6 c0             	movzbl %al,%eax
c0021b81:	8b 54 24 38          	mov    0x38(%esp),%edx
c0021b85:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021b89:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021b8d:	89 14 24             	mov    %edx,(%esp)
c0021b90:	b9 00 00 00 00       	mov    $0x0,%ecx
c0021b95:	ba 00 00 00 00       	mov    $0x0,%edx
c0021b9a:	e8 1b fd ff ff       	call   c00218ba <register_handler>
}
c0021b9f:	83 c4 2c             	add    $0x2c,%esp
c0021ba2:	c3                   	ret    

c0021ba3 <intr_register_int>:
{
c0021ba3:	83 ec 2c             	sub    $0x2c,%esp
c0021ba6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no < 0x20 || vec_no > 0x2f);
c0021baa:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021bad:	80 fa 0f             	cmp    $0xf,%dl
c0021bb0:	77 2c                	ja     c0021bde <intr_register_int+0x3b>
c0021bb2:	c7 44 24 10 e8 e8 02 	movl   $0xc002e8e8,0x10(%esp)
c0021bb9:	c0 
c0021bba:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021bc1:	c0 
c0021bc2:	c7 44 24 08 41 d1 02 	movl   $0xc002d141,0x8(%esp)
c0021bc9:	c0 
c0021bca:	c7 44 24 04 cd 00 00 	movl   $0xcd,0x4(%esp)
c0021bd1:	00 
c0021bd2:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021bd9:	e8 85 6d 00 00       	call   c0028963 <debug_panic>
  register_handler (vec_no, dpl, level, handler, name);
c0021bde:	0f b6 c0             	movzbl %al,%eax
c0021be1:	8b 54 24 40          	mov    0x40(%esp),%edx
c0021be5:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021be9:	8b 54 24 3c          	mov    0x3c(%esp),%edx
c0021bed:	89 14 24             	mov    %edx,(%esp)
c0021bf0:	8b 4c 24 38          	mov    0x38(%esp),%ecx
c0021bf4:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021bf8:	e8 bd fc ff ff       	call   c00218ba <register_handler>
}
c0021bfd:	83 c4 2c             	add    $0x2c,%esp
c0021c00:	c3                   	ret    

c0021c01 <intr_context>:
}
c0021c01:	0f b6 05 41 60 03 c0 	movzbl 0xc0036041,%eax
c0021c08:	c3                   	ret    

c0021c09 <intr_yield_on_return>:
  ASSERT (intr_context ());
c0021c09:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021c10:	75 2f                	jne    c0021c41 <intr_yield_on_return+0x38>
{
c0021c12:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_context ());
c0021c15:	c7 44 24 10 63 e5 02 	movl   $0xc002e563,0x10(%esp)
c0021c1c:	c0 
c0021c1d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021c24:	c0 
c0021c25:	c7 44 24 08 2c d1 02 	movl   $0xc002d12c,0x8(%esp)
c0021c2c:	c0 
c0021c2d:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c0021c34:	00 
c0021c35:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021c3c:	e8 22 6d 00 00       	call   c0028963 <debug_panic>
  yield_on_return = true;
c0021c41:	c6 05 40 60 03 c0 01 	movb   $0x1,0xc0036040
c0021c48:	c3                   	ret    

c0021c49 <intr_handler>:
   function is called by the assembly language interrupt stubs in
   intr-stubs.S.  FRAME describes the interrupt and the
   interrupted thread's registers. */
void
intr_handler (struct intr_frame *frame) 
{
c0021c49:	56                   	push   %esi
c0021c4a:	53                   	push   %ebx
c0021c4b:	83 ec 24             	sub    $0x24,%esp
c0021c4e:	8b 5c 24 30          	mov    0x30(%esp),%ebx

  /* External interrupts are special.
     We only handle one at a time (so interrupts must be off)
     and they need to be acknowledged on the PIC (see below).
     An external interrupt handler cannot sleep. */
  external = frame->vec_no >= 0x20 && frame->vec_no < 0x30;
c0021c52:	8b 43 30             	mov    0x30(%ebx),%eax
c0021c55:	83 e8 20             	sub    $0x20,%eax
c0021c58:	83 f8 0f             	cmp    $0xf,%eax
  if (external) 
c0021c5b:	0f 96 c0             	setbe  %al
c0021c5e:	89 c6                	mov    %eax,%esi
c0021c60:	77 78                	ja     c0021cda <intr_handler+0x91>
    {
      ASSERT (intr_get_level () == INTR_OFF);
c0021c62:	e8 ed fc ff ff       	call   c0021954 <intr_get_level>
c0021c67:	85 c0                	test   %eax,%eax
c0021c69:	74 2c                	je     c0021c97 <intr_handler+0x4e>
c0021c6b:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0021c72:	c0 
c0021c73:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021c7a:	c0 
c0021c7b:	c7 44 24 08 1f d1 02 	movl   $0xc002d11f,0x8(%esp)
c0021c82:	c0 
c0021c83:	c7 44 24 04 65 01 00 	movl   $0x165,0x4(%esp)
c0021c8a:	00 
c0021c8b:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021c92:	e8 cc 6c 00 00       	call   c0028963 <debug_panic>
      ASSERT (!intr_context ());
c0021c97:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021c9e:	74 2c                	je     c0021ccc <intr_handler+0x83>
c0021ca0:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c0021ca7:	c0 
c0021ca8:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021caf:	c0 
c0021cb0:	c7 44 24 08 1f d1 02 	movl   $0xc002d11f,0x8(%esp)
c0021cb7:	c0 
c0021cb8:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0021cbf:	00 
c0021cc0:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021cc7:	e8 97 6c 00 00       	call   c0028963 <debug_panic>

      in_external_intr = true;
c0021ccc:	c6 05 41 60 03 c0 01 	movb   $0x1,0xc0036041
      yield_on_return = false;
c0021cd3:	c6 05 40 60 03 c0 00 	movb   $0x0,0xc0036040
    }

  /* Invoke the interrupt's handler. */
  handler = intr_handlers[frame->vec_no];
c0021cda:	8b 53 30             	mov    0x30(%ebx),%edx
c0021cdd:	8b 04 95 60 68 03 c0 	mov    -0x3ffc97a0(,%edx,4),%eax
  if (handler != NULL)
c0021ce4:	85 c0                	test   %eax,%eax
c0021ce6:	74 07                	je     c0021cef <intr_handler+0xa6>
    handler (frame);
c0021ce8:	89 1c 24             	mov    %ebx,(%esp)
c0021ceb:	ff d0                	call   *%eax
c0021ced:	eb 3a                	jmp    c0021d29 <intr_handler+0xe0>
  else if (frame->vec_no == 0x27 || frame->vec_no == 0x2f)
c0021cef:	89 d0                	mov    %edx,%eax
c0021cf1:	83 e0 f7             	and    $0xfffffff7,%eax
c0021cf4:	83 f8 27             	cmp    $0x27,%eax
c0021cf7:	74 30                	je     c0021d29 <intr_handler+0xe0>
   unexpected interrupt is one that has no registered handler. */
static void
unexpected_interrupt (const struct intr_frame *f)
{
  /* Count the number so far. */
  unsigned int n = ++unexpected_cnt[f->vec_no];
c0021cf9:	8b 04 95 60 60 03 c0 	mov    -0x3ffc9fa0(,%edx,4),%eax
c0021d00:	8d 48 01             	lea    0x1(%eax),%ecx
c0021d03:	89 0c 95 60 60 03 c0 	mov    %ecx,-0x3ffc9fa0(,%edx,4)
  /* If the number is a power of 2, print a message.  This rate
     limiting means that we get information about an uncommon
     unexpected interrupt the first time and fairly often after
     that, but one that occurs many times will not overwhelm the
     console. */
  if ((n & (n - 1)) == 0)
c0021d0a:	85 c1                	test   %eax,%ecx
c0021d0c:	75 1b                	jne    c0021d29 <intr_handler+0xe0>
    printf ("Unexpected interrupt %#04x (%s)\n",
c0021d0e:	8b 04 95 60 64 03 c0 	mov    -0x3ffc9ba0(,%edx,4),%eax
c0021d15:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021d19:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021d1d:	c7 04 24 08 e9 02 c0 	movl   $0xc002e908,(%esp)
c0021d24:	e8 e5 4d 00 00       	call   c0026b0e <printf>
  if (external) 
c0021d29:	89 f0                	mov    %esi,%eax
c0021d2b:	84 c0                	test   %al,%al
c0021d2d:	0f 84 c4 00 00 00    	je     c0021df7 <intr_handler+0x1ae>
      ASSERT (intr_get_level () == INTR_OFF);
c0021d33:	e8 1c fc ff ff       	call   c0021954 <intr_get_level>
c0021d38:	85 c0                	test   %eax,%eax
c0021d3a:	74 2c                	je     c0021d68 <intr_handler+0x11f>
c0021d3c:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0021d43:	c0 
c0021d44:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021d4b:	c0 
c0021d4c:	c7 44 24 08 1f d1 02 	movl   $0xc002d11f,0x8(%esp)
c0021d53:	c0 
c0021d54:	c7 44 24 04 7c 01 00 	movl   $0x17c,0x4(%esp)
c0021d5b:	00 
c0021d5c:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021d63:	e8 fb 6b 00 00       	call   c0028963 <debug_panic>
      ASSERT (intr_context ());
c0021d68:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021d6f:	75 2c                	jne    c0021d9d <intr_handler+0x154>
c0021d71:	c7 44 24 10 63 e5 02 	movl   $0xc002e563,0x10(%esp)
c0021d78:	c0 
c0021d79:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021d80:	c0 
c0021d81:	c7 44 24 08 1f d1 02 	movl   $0xc002d11f,0x8(%esp)
c0021d88:	c0 
c0021d89:	c7 44 24 04 7d 01 00 	movl   $0x17d,0x4(%esp)
c0021d90:	00 
c0021d91:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021d98:	e8 c6 6b 00 00       	call   c0028963 <debug_panic>
      in_external_intr = false;
c0021d9d:	c6 05 41 60 03 c0 00 	movb   $0x0,0xc0036041
      pic_end_of_interrupt (frame->vec_no); 
c0021da4:	8b 53 30             	mov    0x30(%ebx),%edx
  ASSERT (irq >= 0x20 && irq < 0x30);
c0021da7:	8d 42 e0             	lea    -0x20(%edx),%eax
c0021daa:	83 f8 0f             	cmp    $0xf,%eax
c0021dad:	76 2c                	jbe    c0021ddb <intr_handler+0x192>
c0021daf:	c7 44 24 10 dd e7 02 	movl   $0xc002e7dd,0x10(%esp)
c0021db6:	c0 
c0021db7:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0021dbe:	c0 
c0021dbf:	c7 44 24 08 0a d1 02 	movl   $0xc002d10a,0x8(%esp)
c0021dc6:	c0 
c0021dc7:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0021dce:	00 
c0021dcf:	c7 04 24 1a e6 02 c0 	movl   $0xc002e61a,(%esp)
c0021dd6:	e8 88 6b 00 00       	call   c0028963 <debug_panic>
c0021ddb:	b8 20 00 00 00       	mov    $0x20,%eax
c0021de0:	e6 20                	out    %al,$0x20
  if (irq >= 0x28)
c0021de2:	83 fa 27             	cmp    $0x27,%edx
c0021de5:	7e 02                	jle    c0021de9 <intr_handler+0x1a0>
c0021de7:	e6 a0                	out    %al,$0xa0
      if (yield_on_return) 
c0021de9:	80 3d 40 60 03 c0 00 	cmpb   $0x0,0xc0036040
c0021df0:	74 05                	je     c0021df7 <intr_handler+0x1ae>
        thread_yield (); 
c0021df2:	e8 8e f6 ff ff       	call   c0021485 <thread_yield>
}
c0021df7:	83 c4 24             	add    $0x24,%esp
c0021dfa:	5b                   	pop    %ebx
c0021dfb:	5e                   	pop    %esi
c0021dfc:	c3                   	ret    

c0021dfd <intr_dump_frame>:
}

/* Dumps interrupt frame F to the console, for debugging. */
void
intr_dump_frame (const struct intr_frame *f) 
{
c0021dfd:	56                   	push   %esi
c0021dfe:	53                   	push   %ebx
c0021dff:	83 ec 24             	sub    $0x24,%esp
c0021e02:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  /* Store current value of CR2 into `cr2'.
     CR2 is the linear address of the last page fault.
     See [IA32-v2a] "MOV--Move to/from Control Registers" and
     [IA32-v3a] 5.14 "Interrupt 14--Page Fault Exception
     (#PF)". */
  asm ("movl %%cr2, %0" : "=r" (cr2));
c0021e06:	0f 20 d6             	mov    %cr2,%esi

  printf ("Interrupt %#04x (%s) at eip=%p\n",
          f->vec_no, intr_names[f->vec_no], f->eip);
c0021e09:	8b 43 30             	mov    0x30(%ebx),%eax
  printf ("Interrupt %#04x (%s) at eip=%p\n",
c0021e0c:	8b 53 3c             	mov    0x3c(%ebx),%edx
c0021e0f:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0021e13:	8b 14 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%edx
c0021e1a:	89 54 24 08          	mov    %edx,0x8(%esp)
c0021e1e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021e22:	c7 04 24 2c e9 02 c0 	movl   $0xc002e92c,(%esp)
c0021e29:	e8 e0 4c 00 00       	call   c0026b0e <printf>
  printf (" cr2=%08"PRIx32" error=%08"PRIx32"\n", cr2, f->error_code);
c0021e2e:	8b 43 34             	mov    0x34(%ebx),%eax
c0021e31:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021e35:	89 74 24 04          	mov    %esi,0x4(%esp)
c0021e39:	c7 04 24 f7 e7 02 c0 	movl   $0xc002e7f7,(%esp)
c0021e40:	e8 c9 4c 00 00       	call   c0026b0e <printf>
  printf (" eax=%08"PRIx32" ebx=%08"PRIx32" ecx=%08"PRIx32" edx=%08"PRIx32"\n",
c0021e45:	8b 43 14             	mov    0x14(%ebx),%eax
c0021e48:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021e4c:	8b 43 18             	mov    0x18(%ebx),%eax
c0021e4f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021e53:	8b 43 10             	mov    0x10(%ebx),%eax
c0021e56:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021e5a:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021e5d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021e61:	c7 04 24 4c e9 02 c0 	movl   $0xc002e94c,(%esp)
c0021e68:	e8 a1 4c 00 00       	call   c0026b0e <printf>
          f->eax, f->ebx, f->ecx, f->edx);
  printf (" esi=%08"PRIx32" edi=%08"PRIx32" esp=%08"PRIx32" ebp=%08"PRIx32"\n",
c0021e6d:	8b 43 08             	mov    0x8(%ebx),%eax
c0021e70:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021e74:	8b 43 48             	mov    0x48(%ebx),%eax
c0021e77:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021e7b:	8b 03                	mov    (%ebx),%eax
c0021e7d:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021e81:	8b 43 04             	mov    0x4(%ebx),%eax
c0021e84:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021e88:	c7 04 24 74 e9 02 c0 	movl   $0xc002e974,(%esp)
c0021e8f:	e8 7a 4c 00 00       	call   c0026b0e <printf>
          f->esi, f->edi, (uint32_t) f->esp, f->ebp);
  printf (" cs=%04"PRIx16" ds=%04"PRIx16" es=%04"PRIx16" ss=%04"PRIx16"\n",
c0021e94:	0f b7 43 4c          	movzwl 0x4c(%ebx),%eax
c0021e98:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021e9c:	0f b7 43 28          	movzwl 0x28(%ebx),%eax
c0021ea0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021ea4:	0f b7 43 2c          	movzwl 0x2c(%ebx),%eax
c0021ea8:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021eac:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
c0021eb0:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021eb4:	c7 04 24 9c e9 02 c0 	movl   $0xc002e99c,(%esp)
c0021ebb:	e8 4e 4c 00 00       	call   c0026b0e <printf>
          f->cs, f->ds, f->es, f->ss);
}
c0021ec0:	83 c4 24             	add    $0x24,%esp
c0021ec3:	5b                   	pop    %ebx
c0021ec4:	5e                   	pop    %esi
c0021ec5:	c3                   	ret    

c0021ec6 <intr_name>:

/* Returns the name of interrupt VEC. */
const char *
intr_name (uint8_t vec) 
{
  return intr_names[vec];
c0021ec6:	0f b6 44 24 04       	movzbl 0x4(%esp),%eax
c0021ecb:	8b 04 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%eax
}
c0021ed2:	c3                   	ret    

c0021ed3 <intr_entry>:
   We "fall through" to intr_exit to return from the interrupt.
*/
.func intr_entry
intr_entry:
	/* Save caller's registers. */
	pushl %ds
c0021ed3:	1e                   	push   %ds
	pushl %es
c0021ed4:	06                   	push   %es
	pushl %fs
c0021ed5:	0f a0                	push   %fs
	pushl %gs
c0021ed7:	0f a8                	push   %gs
	pushal
c0021ed9:	60                   	pusha  
        
	/* Set up kernel environment. */
	cld			/* String instructions go upward. */
c0021eda:	fc                   	cld    
	mov $SEL_KDSEG, %eax	/* Initialize segment registers. */
c0021edb:	b8 10 00 00 00       	mov    $0x10,%eax
	mov %eax, %ds
c0021ee0:	8e d8                	mov    %eax,%ds
	mov %eax, %es
c0021ee2:	8e c0                	mov    %eax,%es
	leal 56(%esp), %ebp	/* Set up frame pointer. */
c0021ee4:	8d 6c 24 38          	lea    0x38(%esp),%ebp

	/* Call interrupt handler. */
	pushl %esp
c0021ee8:	54                   	push   %esp
.globl intr_handler
	call intr_handler
c0021ee9:	e8 5b fd ff ff       	call   c0021c49 <intr_handler>
	addl $4, %esp
c0021eee:	83 c4 04             	add    $0x4,%esp

c0021ef1 <intr_exit>:
   userprog/process.c). */
.globl intr_exit
.func intr_exit
intr_exit:
        /* Restore caller's registers. */
	popal
c0021ef1:	61                   	popa   
	popl %gs
c0021ef2:	0f a9                	pop    %gs
	popl %fs
c0021ef4:	0f a1                	pop    %fs
	popl %es
c0021ef6:	07                   	pop    %es
	popl %ds
c0021ef7:	1f                   	pop    %ds

        /* Discard `struct intr_frame' vec_no, error_code,
           frame_pointer members. */
	addl $12, %esp
c0021ef8:	83 c4 0c             	add    $0xc,%esp

        /* Return to caller. */
	iret
c0021efb:	cf                   	iret   

c0021efc <intr00_stub>:
                                                \
	.data;                                  \
	.long intr##NUMBER##_stub;

/* All the stubs. */
STUB(00, zero) STUB(01, zero) STUB(02, zero) STUB(03, zero)
c0021efc:	55                   	push   %ebp
c0021efd:	6a 00                	push   $0x0
c0021eff:	6a 00                	push   $0x0
c0021f01:	eb d0                	jmp    c0021ed3 <intr_entry>

c0021f03 <intr01_stub>:
c0021f03:	55                   	push   %ebp
c0021f04:	6a 00                	push   $0x0
c0021f06:	6a 01                	push   $0x1
c0021f08:	eb c9                	jmp    c0021ed3 <intr_entry>

c0021f0a <intr02_stub>:
c0021f0a:	55                   	push   %ebp
c0021f0b:	6a 00                	push   $0x0
c0021f0d:	6a 02                	push   $0x2
c0021f0f:	eb c2                	jmp    c0021ed3 <intr_entry>

c0021f11 <intr03_stub>:
c0021f11:	55                   	push   %ebp
c0021f12:	6a 00                	push   $0x0
c0021f14:	6a 03                	push   $0x3
c0021f16:	eb bb                	jmp    c0021ed3 <intr_entry>

c0021f18 <intr04_stub>:
STUB(04, zero) STUB(05, zero) STUB(06, zero) STUB(07, zero)
c0021f18:	55                   	push   %ebp
c0021f19:	6a 00                	push   $0x0
c0021f1b:	6a 04                	push   $0x4
c0021f1d:	eb b4                	jmp    c0021ed3 <intr_entry>

c0021f1f <intr05_stub>:
c0021f1f:	55                   	push   %ebp
c0021f20:	6a 00                	push   $0x0
c0021f22:	6a 05                	push   $0x5
c0021f24:	eb ad                	jmp    c0021ed3 <intr_entry>

c0021f26 <intr06_stub>:
c0021f26:	55                   	push   %ebp
c0021f27:	6a 00                	push   $0x0
c0021f29:	6a 06                	push   $0x6
c0021f2b:	eb a6                	jmp    c0021ed3 <intr_entry>

c0021f2d <intr07_stub>:
c0021f2d:	55                   	push   %ebp
c0021f2e:	6a 00                	push   $0x0
c0021f30:	6a 07                	push   $0x7
c0021f32:	eb 9f                	jmp    c0021ed3 <intr_entry>

c0021f34 <intr08_stub>:
STUB(08, REAL) STUB(09, zero) STUB(0a, REAL) STUB(0b, REAL)
c0021f34:	ff 34 24             	pushl  (%esp)
c0021f37:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f3b:	6a 08                	push   $0x8
c0021f3d:	eb 94                	jmp    c0021ed3 <intr_entry>

c0021f3f <intr09_stub>:
c0021f3f:	55                   	push   %ebp
c0021f40:	6a 00                	push   $0x0
c0021f42:	6a 09                	push   $0x9
c0021f44:	eb 8d                	jmp    c0021ed3 <intr_entry>

c0021f46 <intr0a_stub>:
c0021f46:	ff 34 24             	pushl  (%esp)
c0021f49:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f4d:	6a 0a                	push   $0xa
c0021f4f:	eb 82                	jmp    c0021ed3 <intr_entry>

c0021f51 <intr0b_stub>:
c0021f51:	ff 34 24             	pushl  (%esp)
c0021f54:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f58:	6a 0b                	push   $0xb
c0021f5a:	e9 74 ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021f5f <intr0c_stub>:
STUB(0c, zero) STUB(0d, REAL) STUB(0e, REAL) STUB(0f, zero)
c0021f5f:	55                   	push   %ebp
c0021f60:	6a 00                	push   $0x0
c0021f62:	6a 0c                	push   $0xc
c0021f64:	e9 6a ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021f69 <intr0d_stub>:
c0021f69:	ff 34 24             	pushl  (%esp)
c0021f6c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f70:	6a 0d                	push   $0xd
c0021f72:	e9 5c ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021f77 <intr0e_stub>:
c0021f77:	ff 34 24             	pushl  (%esp)
c0021f7a:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021f7e:	6a 0e                	push   $0xe
c0021f80:	e9 4e ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021f85 <intr0f_stub>:
c0021f85:	55                   	push   %ebp
c0021f86:	6a 00                	push   $0x0
c0021f88:	6a 0f                	push   $0xf
c0021f8a:	e9 44 ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021f8f <intr10_stub>:

STUB(10, zero) STUB(11, REAL) STUB(12, zero) STUB(13, zero)
c0021f8f:	55                   	push   %ebp
c0021f90:	6a 00                	push   $0x0
c0021f92:	6a 10                	push   $0x10
c0021f94:	e9 3a ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021f99 <intr11_stub>:
c0021f99:	ff 34 24             	pushl  (%esp)
c0021f9c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fa0:	6a 11                	push   $0x11
c0021fa2:	e9 2c ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021fa7 <intr12_stub>:
c0021fa7:	55                   	push   %ebp
c0021fa8:	6a 00                	push   $0x0
c0021faa:	6a 12                	push   $0x12
c0021fac:	e9 22 ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021fb1 <intr13_stub>:
c0021fb1:	55                   	push   %ebp
c0021fb2:	6a 00                	push   $0x0
c0021fb4:	6a 13                	push   $0x13
c0021fb6:	e9 18 ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021fbb <intr14_stub>:
STUB(14, zero) STUB(15, zero) STUB(16, zero) STUB(17, zero)
c0021fbb:	55                   	push   %ebp
c0021fbc:	6a 00                	push   $0x0
c0021fbe:	6a 14                	push   $0x14
c0021fc0:	e9 0e ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021fc5 <intr15_stub>:
c0021fc5:	55                   	push   %ebp
c0021fc6:	6a 00                	push   $0x0
c0021fc8:	6a 15                	push   $0x15
c0021fca:	e9 04 ff ff ff       	jmp    c0021ed3 <intr_entry>

c0021fcf <intr16_stub>:
c0021fcf:	55                   	push   %ebp
c0021fd0:	6a 00                	push   $0x0
c0021fd2:	6a 16                	push   $0x16
c0021fd4:	e9 fa fe ff ff       	jmp    c0021ed3 <intr_entry>

c0021fd9 <intr17_stub>:
c0021fd9:	55                   	push   %ebp
c0021fda:	6a 00                	push   $0x0
c0021fdc:	6a 17                	push   $0x17
c0021fde:	e9 f0 fe ff ff       	jmp    c0021ed3 <intr_entry>

c0021fe3 <intr18_stub>:
STUB(18, REAL) STUB(19, zero) STUB(1a, REAL) STUB(1b, REAL)
c0021fe3:	ff 34 24             	pushl  (%esp)
c0021fe6:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021fea:	6a 18                	push   $0x18
c0021fec:	e9 e2 fe ff ff       	jmp    c0021ed3 <intr_entry>

c0021ff1 <intr19_stub>:
c0021ff1:	55                   	push   %ebp
c0021ff2:	6a 00                	push   $0x0
c0021ff4:	6a 19                	push   $0x19
c0021ff6:	e9 d8 fe ff ff       	jmp    c0021ed3 <intr_entry>

c0021ffb <intr1a_stub>:
c0021ffb:	ff 34 24             	pushl  (%esp)
c0021ffe:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022002:	6a 1a                	push   $0x1a
c0022004:	e9 ca fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022009 <intr1b_stub>:
c0022009:	ff 34 24             	pushl  (%esp)
c002200c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022010:	6a 1b                	push   $0x1b
c0022012:	e9 bc fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022017 <intr1c_stub>:
STUB(1c, zero) STUB(1d, REAL) STUB(1e, REAL) STUB(1f, zero)
c0022017:	55                   	push   %ebp
c0022018:	6a 00                	push   $0x0
c002201a:	6a 1c                	push   $0x1c
c002201c:	e9 b2 fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022021 <intr1d_stub>:
c0022021:	ff 34 24             	pushl  (%esp)
c0022024:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022028:	6a 1d                	push   $0x1d
c002202a:	e9 a4 fe ff ff       	jmp    c0021ed3 <intr_entry>

c002202f <intr1e_stub>:
c002202f:	ff 34 24             	pushl  (%esp)
c0022032:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0022036:	6a 1e                	push   $0x1e
c0022038:	e9 96 fe ff ff       	jmp    c0021ed3 <intr_entry>

c002203d <intr1f_stub>:
c002203d:	55                   	push   %ebp
c002203e:	6a 00                	push   $0x0
c0022040:	6a 1f                	push   $0x1f
c0022042:	e9 8c fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022047 <intr20_stub>:

STUB(20, zero) STUB(21, zero) STUB(22, zero) STUB(23, zero)
c0022047:	55                   	push   %ebp
c0022048:	6a 00                	push   $0x0
c002204a:	6a 20                	push   $0x20
c002204c:	e9 82 fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022051 <intr21_stub>:
c0022051:	55                   	push   %ebp
c0022052:	6a 00                	push   $0x0
c0022054:	6a 21                	push   $0x21
c0022056:	e9 78 fe ff ff       	jmp    c0021ed3 <intr_entry>

c002205b <intr22_stub>:
c002205b:	55                   	push   %ebp
c002205c:	6a 00                	push   $0x0
c002205e:	6a 22                	push   $0x22
c0022060:	e9 6e fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022065 <intr23_stub>:
c0022065:	55                   	push   %ebp
c0022066:	6a 00                	push   $0x0
c0022068:	6a 23                	push   $0x23
c002206a:	e9 64 fe ff ff       	jmp    c0021ed3 <intr_entry>

c002206f <intr24_stub>:
STUB(24, zero) STUB(25, zero) STUB(26, zero) STUB(27, zero)
c002206f:	55                   	push   %ebp
c0022070:	6a 00                	push   $0x0
c0022072:	6a 24                	push   $0x24
c0022074:	e9 5a fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022079 <intr25_stub>:
c0022079:	55                   	push   %ebp
c002207a:	6a 00                	push   $0x0
c002207c:	6a 25                	push   $0x25
c002207e:	e9 50 fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022083 <intr26_stub>:
c0022083:	55                   	push   %ebp
c0022084:	6a 00                	push   $0x0
c0022086:	6a 26                	push   $0x26
c0022088:	e9 46 fe ff ff       	jmp    c0021ed3 <intr_entry>

c002208d <intr27_stub>:
c002208d:	55                   	push   %ebp
c002208e:	6a 00                	push   $0x0
c0022090:	6a 27                	push   $0x27
c0022092:	e9 3c fe ff ff       	jmp    c0021ed3 <intr_entry>

c0022097 <intr28_stub>:
STUB(28, zero) STUB(29, zero) STUB(2a, zero) STUB(2b, zero)
c0022097:	55                   	push   %ebp
c0022098:	6a 00                	push   $0x0
c002209a:	6a 28                	push   $0x28
c002209c:	e9 32 fe ff ff       	jmp    c0021ed3 <intr_entry>

c00220a1 <intr29_stub>:
c00220a1:	55                   	push   %ebp
c00220a2:	6a 00                	push   $0x0
c00220a4:	6a 29                	push   $0x29
c00220a6:	e9 28 fe ff ff       	jmp    c0021ed3 <intr_entry>

c00220ab <intr2a_stub>:
c00220ab:	55                   	push   %ebp
c00220ac:	6a 00                	push   $0x0
c00220ae:	6a 2a                	push   $0x2a
c00220b0:	e9 1e fe ff ff       	jmp    c0021ed3 <intr_entry>

c00220b5 <intr2b_stub>:
c00220b5:	55                   	push   %ebp
c00220b6:	6a 00                	push   $0x0
c00220b8:	6a 2b                	push   $0x2b
c00220ba:	e9 14 fe ff ff       	jmp    c0021ed3 <intr_entry>

c00220bf <intr2c_stub>:
STUB(2c, zero) STUB(2d, zero) STUB(2e, zero) STUB(2f, zero)
c00220bf:	55                   	push   %ebp
c00220c0:	6a 00                	push   $0x0
c00220c2:	6a 2c                	push   $0x2c
c00220c4:	e9 0a fe ff ff       	jmp    c0021ed3 <intr_entry>

c00220c9 <intr2d_stub>:
c00220c9:	55                   	push   %ebp
c00220ca:	6a 00                	push   $0x0
c00220cc:	6a 2d                	push   $0x2d
c00220ce:	e9 00 fe ff ff       	jmp    c0021ed3 <intr_entry>

c00220d3 <intr2e_stub>:
c00220d3:	55                   	push   %ebp
c00220d4:	6a 00                	push   $0x0
c00220d6:	6a 2e                	push   $0x2e
c00220d8:	e9 f6 fd ff ff       	jmp    c0021ed3 <intr_entry>

c00220dd <intr2f_stub>:
c00220dd:	55                   	push   %ebp
c00220de:	6a 00                	push   $0x0
c00220e0:	6a 2f                	push   $0x2f
c00220e2:	e9 ec fd ff ff       	jmp    c0021ed3 <intr_entry>

c00220e7 <intr30_stub>:

STUB(30, zero) STUB(31, zero) STUB(32, zero) STUB(33, zero)
c00220e7:	55                   	push   %ebp
c00220e8:	6a 00                	push   $0x0
c00220ea:	6a 30                	push   $0x30
c00220ec:	e9 e2 fd ff ff       	jmp    c0021ed3 <intr_entry>

c00220f1 <intr31_stub>:
c00220f1:	55                   	push   %ebp
c00220f2:	6a 00                	push   $0x0
c00220f4:	6a 31                	push   $0x31
c00220f6:	e9 d8 fd ff ff       	jmp    c0021ed3 <intr_entry>

c00220fb <intr32_stub>:
c00220fb:	55                   	push   %ebp
c00220fc:	6a 00                	push   $0x0
c00220fe:	6a 32                	push   $0x32
c0022100:	e9 ce fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022105 <intr33_stub>:
c0022105:	55                   	push   %ebp
c0022106:	6a 00                	push   $0x0
c0022108:	6a 33                	push   $0x33
c002210a:	e9 c4 fd ff ff       	jmp    c0021ed3 <intr_entry>

c002210f <intr34_stub>:
STUB(34, zero) STUB(35, zero) STUB(36, zero) STUB(37, zero)
c002210f:	55                   	push   %ebp
c0022110:	6a 00                	push   $0x0
c0022112:	6a 34                	push   $0x34
c0022114:	e9 ba fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022119 <intr35_stub>:
c0022119:	55                   	push   %ebp
c002211a:	6a 00                	push   $0x0
c002211c:	6a 35                	push   $0x35
c002211e:	e9 b0 fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022123 <intr36_stub>:
c0022123:	55                   	push   %ebp
c0022124:	6a 00                	push   $0x0
c0022126:	6a 36                	push   $0x36
c0022128:	e9 a6 fd ff ff       	jmp    c0021ed3 <intr_entry>

c002212d <intr37_stub>:
c002212d:	55                   	push   %ebp
c002212e:	6a 00                	push   $0x0
c0022130:	6a 37                	push   $0x37
c0022132:	e9 9c fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022137 <intr38_stub>:
STUB(38, zero) STUB(39, zero) STUB(3a, zero) STUB(3b, zero)
c0022137:	55                   	push   %ebp
c0022138:	6a 00                	push   $0x0
c002213a:	6a 38                	push   $0x38
c002213c:	e9 92 fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022141 <intr39_stub>:
c0022141:	55                   	push   %ebp
c0022142:	6a 00                	push   $0x0
c0022144:	6a 39                	push   $0x39
c0022146:	e9 88 fd ff ff       	jmp    c0021ed3 <intr_entry>

c002214b <intr3a_stub>:
c002214b:	55                   	push   %ebp
c002214c:	6a 00                	push   $0x0
c002214e:	6a 3a                	push   $0x3a
c0022150:	e9 7e fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022155 <intr3b_stub>:
c0022155:	55                   	push   %ebp
c0022156:	6a 00                	push   $0x0
c0022158:	6a 3b                	push   $0x3b
c002215a:	e9 74 fd ff ff       	jmp    c0021ed3 <intr_entry>

c002215f <intr3c_stub>:
STUB(3c, zero) STUB(3d, zero) STUB(3e, zero) STUB(3f, zero)
c002215f:	55                   	push   %ebp
c0022160:	6a 00                	push   $0x0
c0022162:	6a 3c                	push   $0x3c
c0022164:	e9 6a fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022169 <intr3d_stub>:
c0022169:	55                   	push   %ebp
c002216a:	6a 00                	push   $0x0
c002216c:	6a 3d                	push   $0x3d
c002216e:	e9 60 fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022173 <intr3e_stub>:
c0022173:	55                   	push   %ebp
c0022174:	6a 00                	push   $0x0
c0022176:	6a 3e                	push   $0x3e
c0022178:	e9 56 fd ff ff       	jmp    c0021ed3 <intr_entry>

c002217d <intr3f_stub>:
c002217d:	55                   	push   %ebp
c002217e:	6a 00                	push   $0x0
c0022180:	6a 3f                	push   $0x3f
c0022182:	e9 4c fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022187 <intr40_stub>:

STUB(40, zero) STUB(41, zero) STUB(42, zero) STUB(43, zero)
c0022187:	55                   	push   %ebp
c0022188:	6a 00                	push   $0x0
c002218a:	6a 40                	push   $0x40
c002218c:	e9 42 fd ff ff       	jmp    c0021ed3 <intr_entry>

c0022191 <intr41_stub>:
c0022191:	55                   	push   %ebp
c0022192:	6a 00                	push   $0x0
c0022194:	6a 41                	push   $0x41
c0022196:	e9 38 fd ff ff       	jmp    c0021ed3 <intr_entry>

c002219b <intr42_stub>:
c002219b:	55                   	push   %ebp
c002219c:	6a 00                	push   $0x0
c002219e:	6a 42                	push   $0x42
c00221a0:	e9 2e fd ff ff       	jmp    c0021ed3 <intr_entry>

c00221a5 <intr43_stub>:
c00221a5:	55                   	push   %ebp
c00221a6:	6a 00                	push   $0x0
c00221a8:	6a 43                	push   $0x43
c00221aa:	e9 24 fd ff ff       	jmp    c0021ed3 <intr_entry>

c00221af <intr44_stub>:
STUB(44, zero) STUB(45, zero) STUB(46, zero) STUB(47, zero)
c00221af:	55                   	push   %ebp
c00221b0:	6a 00                	push   $0x0
c00221b2:	6a 44                	push   $0x44
c00221b4:	e9 1a fd ff ff       	jmp    c0021ed3 <intr_entry>

c00221b9 <intr45_stub>:
c00221b9:	55                   	push   %ebp
c00221ba:	6a 00                	push   $0x0
c00221bc:	6a 45                	push   $0x45
c00221be:	e9 10 fd ff ff       	jmp    c0021ed3 <intr_entry>

c00221c3 <intr46_stub>:
c00221c3:	55                   	push   %ebp
c00221c4:	6a 00                	push   $0x0
c00221c6:	6a 46                	push   $0x46
c00221c8:	e9 06 fd ff ff       	jmp    c0021ed3 <intr_entry>

c00221cd <intr47_stub>:
c00221cd:	55                   	push   %ebp
c00221ce:	6a 00                	push   $0x0
c00221d0:	6a 47                	push   $0x47
c00221d2:	e9 fc fc ff ff       	jmp    c0021ed3 <intr_entry>

c00221d7 <intr48_stub>:
STUB(48, zero) STUB(49, zero) STUB(4a, zero) STUB(4b, zero)
c00221d7:	55                   	push   %ebp
c00221d8:	6a 00                	push   $0x0
c00221da:	6a 48                	push   $0x48
c00221dc:	e9 f2 fc ff ff       	jmp    c0021ed3 <intr_entry>

c00221e1 <intr49_stub>:
c00221e1:	55                   	push   %ebp
c00221e2:	6a 00                	push   $0x0
c00221e4:	6a 49                	push   $0x49
c00221e6:	e9 e8 fc ff ff       	jmp    c0021ed3 <intr_entry>

c00221eb <intr4a_stub>:
c00221eb:	55                   	push   %ebp
c00221ec:	6a 00                	push   $0x0
c00221ee:	6a 4a                	push   $0x4a
c00221f0:	e9 de fc ff ff       	jmp    c0021ed3 <intr_entry>

c00221f5 <intr4b_stub>:
c00221f5:	55                   	push   %ebp
c00221f6:	6a 00                	push   $0x0
c00221f8:	6a 4b                	push   $0x4b
c00221fa:	e9 d4 fc ff ff       	jmp    c0021ed3 <intr_entry>

c00221ff <intr4c_stub>:
STUB(4c, zero) STUB(4d, zero) STUB(4e, zero) STUB(4f, zero)
c00221ff:	55                   	push   %ebp
c0022200:	6a 00                	push   $0x0
c0022202:	6a 4c                	push   $0x4c
c0022204:	e9 ca fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022209 <intr4d_stub>:
c0022209:	55                   	push   %ebp
c002220a:	6a 00                	push   $0x0
c002220c:	6a 4d                	push   $0x4d
c002220e:	e9 c0 fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022213 <intr4e_stub>:
c0022213:	55                   	push   %ebp
c0022214:	6a 00                	push   $0x0
c0022216:	6a 4e                	push   $0x4e
c0022218:	e9 b6 fc ff ff       	jmp    c0021ed3 <intr_entry>

c002221d <intr4f_stub>:
c002221d:	55                   	push   %ebp
c002221e:	6a 00                	push   $0x0
c0022220:	6a 4f                	push   $0x4f
c0022222:	e9 ac fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022227 <intr50_stub>:

STUB(50, zero) STUB(51, zero) STUB(52, zero) STUB(53, zero)
c0022227:	55                   	push   %ebp
c0022228:	6a 00                	push   $0x0
c002222a:	6a 50                	push   $0x50
c002222c:	e9 a2 fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022231 <intr51_stub>:
c0022231:	55                   	push   %ebp
c0022232:	6a 00                	push   $0x0
c0022234:	6a 51                	push   $0x51
c0022236:	e9 98 fc ff ff       	jmp    c0021ed3 <intr_entry>

c002223b <intr52_stub>:
c002223b:	55                   	push   %ebp
c002223c:	6a 00                	push   $0x0
c002223e:	6a 52                	push   $0x52
c0022240:	e9 8e fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022245 <intr53_stub>:
c0022245:	55                   	push   %ebp
c0022246:	6a 00                	push   $0x0
c0022248:	6a 53                	push   $0x53
c002224a:	e9 84 fc ff ff       	jmp    c0021ed3 <intr_entry>

c002224f <intr54_stub>:
STUB(54, zero) STUB(55, zero) STUB(56, zero) STUB(57, zero)
c002224f:	55                   	push   %ebp
c0022250:	6a 00                	push   $0x0
c0022252:	6a 54                	push   $0x54
c0022254:	e9 7a fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022259 <intr55_stub>:
c0022259:	55                   	push   %ebp
c002225a:	6a 00                	push   $0x0
c002225c:	6a 55                	push   $0x55
c002225e:	e9 70 fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022263 <intr56_stub>:
c0022263:	55                   	push   %ebp
c0022264:	6a 00                	push   $0x0
c0022266:	6a 56                	push   $0x56
c0022268:	e9 66 fc ff ff       	jmp    c0021ed3 <intr_entry>

c002226d <intr57_stub>:
c002226d:	55                   	push   %ebp
c002226e:	6a 00                	push   $0x0
c0022270:	6a 57                	push   $0x57
c0022272:	e9 5c fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022277 <intr58_stub>:
STUB(58, zero) STUB(59, zero) STUB(5a, zero) STUB(5b, zero)
c0022277:	55                   	push   %ebp
c0022278:	6a 00                	push   $0x0
c002227a:	6a 58                	push   $0x58
c002227c:	e9 52 fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022281 <intr59_stub>:
c0022281:	55                   	push   %ebp
c0022282:	6a 00                	push   $0x0
c0022284:	6a 59                	push   $0x59
c0022286:	e9 48 fc ff ff       	jmp    c0021ed3 <intr_entry>

c002228b <intr5a_stub>:
c002228b:	55                   	push   %ebp
c002228c:	6a 00                	push   $0x0
c002228e:	6a 5a                	push   $0x5a
c0022290:	e9 3e fc ff ff       	jmp    c0021ed3 <intr_entry>

c0022295 <intr5b_stub>:
c0022295:	55                   	push   %ebp
c0022296:	6a 00                	push   $0x0
c0022298:	6a 5b                	push   $0x5b
c002229a:	e9 34 fc ff ff       	jmp    c0021ed3 <intr_entry>

c002229f <intr5c_stub>:
STUB(5c, zero) STUB(5d, zero) STUB(5e, zero) STUB(5f, zero)
c002229f:	55                   	push   %ebp
c00222a0:	6a 00                	push   $0x0
c00222a2:	6a 5c                	push   $0x5c
c00222a4:	e9 2a fc ff ff       	jmp    c0021ed3 <intr_entry>

c00222a9 <intr5d_stub>:
c00222a9:	55                   	push   %ebp
c00222aa:	6a 00                	push   $0x0
c00222ac:	6a 5d                	push   $0x5d
c00222ae:	e9 20 fc ff ff       	jmp    c0021ed3 <intr_entry>

c00222b3 <intr5e_stub>:
c00222b3:	55                   	push   %ebp
c00222b4:	6a 00                	push   $0x0
c00222b6:	6a 5e                	push   $0x5e
c00222b8:	e9 16 fc ff ff       	jmp    c0021ed3 <intr_entry>

c00222bd <intr5f_stub>:
c00222bd:	55                   	push   %ebp
c00222be:	6a 00                	push   $0x0
c00222c0:	6a 5f                	push   $0x5f
c00222c2:	e9 0c fc ff ff       	jmp    c0021ed3 <intr_entry>

c00222c7 <intr60_stub>:

STUB(60, zero) STUB(61, zero) STUB(62, zero) STUB(63, zero)
c00222c7:	55                   	push   %ebp
c00222c8:	6a 00                	push   $0x0
c00222ca:	6a 60                	push   $0x60
c00222cc:	e9 02 fc ff ff       	jmp    c0021ed3 <intr_entry>

c00222d1 <intr61_stub>:
c00222d1:	55                   	push   %ebp
c00222d2:	6a 00                	push   $0x0
c00222d4:	6a 61                	push   $0x61
c00222d6:	e9 f8 fb ff ff       	jmp    c0021ed3 <intr_entry>

c00222db <intr62_stub>:
c00222db:	55                   	push   %ebp
c00222dc:	6a 00                	push   $0x0
c00222de:	6a 62                	push   $0x62
c00222e0:	e9 ee fb ff ff       	jmp    c0021ed3 <intr_entry>

c00222e5 <intr63_stub>:
c00222e5:	55                   	push   %ebp
c00222e6:	6a 00                	push   $0x0
c00222e8:	6a 63                	push   $0x63
c00222ea:	e9 e4 fb ff ff       	jmp    c0021ed3 <intr_entry>

c00222ef <intr64_stub>:
STUB(64, zero) STUB(65, zero) STUB(66, zero) STUB(67, zero)
c00222ef:	55                   	push   %ebp
c00222f0:	6a 00                	push   $0x0
c00222f2:	6a 64                	push   $0x64
c00222f4:	e9 da fb ff ff       	jmp    c0021ed3 <intr_entry>

c00222f9 <intr65_stub>:
c00222f9:	55                   	push   %ebp
c00222fa:	6a 00                	push   $0x0
c00222fc:	6a 65                	push   $0x65
c00222fe:	e9 d0 fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022303 <intr66_stub>:
c0022303:	55                   	push   %ebp
c0022304:	6a 00                	push   $0x0
c0022306:	6a 66                	push   $0x66
c0022308:	e9 c6 fb ff ff       	jmp    c0021ed3 <intr_entry>

c002230d <intr67_stub>:
c002230d:	55                   	push   %ebp
c002230e:	6a 00                	push   $0x0
c0022310:	6a 67                	push   $0x67
c0022312:	e9 bc fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022317 <intr68_stub>:
STUB(68, zero) STUB(69, zero) STUB(6a, zero) STUB(6b, zero)
c0022317:	55                   	push   %ebp
c0022318:	6a 00                	push   $0x0
c002231a:	6a 68                	push   $0x68
c002231c:	e9 b2 fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022321 <intr69_stub>:
c0022321:	55                   	push   %ebp
c0022322:	6a 00                	push   $0x0
c0022324:	6a 69                	push   $0x69
c0022326:	e9 a8 fb ff ff       	jmp    c0021ed3 <intr_entry>

c002232b <intr6a_stub>:
c002232b:	55                   	push   %ebp
c002232c:	6a 00                	push   $0x0
c002232e:	6a 6a                	push   $0x6a
c0022330:	e9 9e fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022335 <intr6b_stub>:
c0022335:	55                   	push   %ebp
c0022336:	6a 00                	push   $0x0
c0022338:	6a 6b                	push   $0x6b
c002233a:	e9 94 fb ff ff       	jmp    c0021ed3 <intr_entry>

c002233f <intr6c_stub>:
STUB(6c, zero) STUB(6d, zero) STUB(6e, zero) STUB(6f, zero)
c002233f:	55                   	push   %ebp
c0022340:	6a 00                	push   $0x0
c0022342:	6a 6c                	push   $0x6c
c0022344:	e9 8a fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022349 <intr6d_stub>:
c0022349:	55                   	push   %ebp
c002234a:	6a 00                	push   $0x0
c002234c:	6a 6d                	push   $0x6d
c002234e:	e9 80 fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022353 <intr6e_stub>:
c0022353:	55                   	push   %ebp
c0022354:	6a 00                	push   $0x0
c0022356:	6a 6e                	push   $0x6e
c0022358:	e9 76 fb ff ff       	jmp    c0021ed3 <intr_entry>

c002235d <intr6f_stub>:
c002235d:	55                   	push   %ebp
c002235e:	6a 00                	push   $0x0
c0022360:	6a 6f                	push   $0x6f
c0022362:	e9 6c fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022367 <intr70_stub>:

STUB(70, zero) STUB(71, zero) STUB(72, zero) STUB(73, zero)
c0022367:	55                   	push   %ebp
c0022368:	6a 00                	push   $0x0
c002236a:	6a 70                	push   $0x70
c002236c:	e9 62 fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022371 <intr71_stub>:
c0022371:	55                   	push   %ebp
c0022372:	6a 00                	push   $0x0
c0022374:	6a 71                	push   $0x71
c0022376:	e9 58 fb ff ff       	jmp    c0021ed3 <intr_entry>

c002237b <intr72_stub>:
c002237b:	55                   	push   %ebp
c002237c:	6a 00                	push   $0x0
c002237e:	6a 72                	push   $0x72
c0022380:	e9 4e fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022385 <intr73_stub>:
c0022385:	55                   	push   %ebp
c0022386:	6a 00                	push   $0x0
c0022388:	6a 73                	push   $0x73
c002238a:	e9 44 fb ff ff       	jmp    c0021ed3 <intr_entry>

c002238f <intr74_stub>:
STUB(74, zero) STUB(75, zero) STUB(76, zero) STUB(77, zero)
c002238f:	55                   	push   %ebp
c0022390:	6a 00                	push   $0x0
c0022392:	6a 74                	push   $0x74
c0022394:	e9 3a fb ff ff       	jmp    c0021ed3 <intr_entry>

c0022399 <intr75_stub>:
c0022399:	55                   	push   %ebp
c002239a:	6a 00                	push   $0x0
c002239c:	6a 75                	push   $0x75
c002239e:	e9 30 fb ff ff       	jmp    c0021ed3 <intr_entry>

c00223a3 <intr76_stub>:
c00223a3:	55                   	push   %ebp
c00223a4:	6a 00                	push   $0x0
c00223a6:	6a 76                	push   $0x76
c00223a8:	e9 26 fb ff ff       	jmp    c0021ed3 <intr_entry>

c00223ad <intr77_stub>:
c00223ad:	55                   	push   %ebp
c00223ae:	6a 00                	push   $0x0
c00223b0:	6a 77                	push   $0x77
c00223b2:	e9 1c fb ff ff       	jmp    c0021ed3 <intr_entry>

c00223b7 <intr78_stub>:
STUB(78, zero) STUB(79, zero) STUB(7a, zero) STUB(7b, zero)
c00223b7:	55                   	push   %ebp
c00223b8:	6a 00                	push   $0x0
c00223ba:	6a 78                	push   $0x78
c00223bc:	e9 12 fb ff ff       	jmp    c0021ed3 <intr_entry>

c00223c1 <intr79_stub>:
c00223c1:	55                   	push   %ebp
c00223c2:	6a 00                	push   $0x0
c00223c4:	6a 79                	push   $0x79
c00223c6:	e9 08 fb ff ff       	jmp    c0021ed3 <intr_entry>

c00223cb <intr7a_stub>:
c00223cb:	55                   	push   %ebp
c00223cc:	6a 00                	push   $0x0
c00223ce:	6a 7a                	push   $0x7a
c00223d0:	e9 fe fa ff ff       	jmp    c0021ed3 <intr_entry>

c00223d5 <intr7b_stub>:
c00223d5:	55                   	push   %ebp
c00223d6:	6a 00                	push   $0x0
c00223d8:	6a 7b                	push   $0x7b
c00223da:	e9 f4 fa ff ff       	jmp    c0021ed3 <intr_entry>

c00223df <intr7c_stub>:
STUB(7c, zero) STUB(7d, zero) STUB(7e, zero) STUB(7f, zero)
c00223df:	55                   	push   %ebp
c00223e0:	6a 00                	push   $0x0
c00223e2:	6a 7c                	push   $0x7c
c00223e4:	e9 ea fa ff ff       	jmp    c0021ed3 <intr_entry>

c00223e9 <intr7d_stub>:
c00223e9:	55                   	push   %ebp
c00223ea:	6a 00                	push   $0x0
c00223ec:	6a 7d                	push   $0x7d
c00223ee:	e9 e0 fa ff ff       	jmp    c0021ed3 <intr_entry>

c00223f3 <intr7e_stub>:
c00223f3:	55                   	push   %ebp
c00223f4:	6a 00                	push   $0x0
c00223f6:	6a 7e                	push   $0x7e
c00223f8:	e9 d6 fa ff ff       	jmp    c0021ed3 <intr_entry>

c00223fd <intr7f_stub>:
c00223fd:	55                   	push   %ebp
c00223fe:	6a 00                	push   $0x0
c0022400:	6a 7f                	push   $0x7f
c0022402:	e9 cc fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022407 <intr80_stub>:

STUB(80, zero) STUB(81, zero) STUB(82, zero) STUB(83, zero)
c0022407:	55                   	push   %ebp
c0022408:	6a 00                	push   $0x0
c002240a:	68 80 00 00 00       	push   $0x80
c002240f:	e9 bf fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022414 <intr81_stub>:
c0022414:	55                   	push   %ebp
c0022415:	6a 00                	push   $0x0
c0022417:	68 81 00 00 00       	push   $0x81
c002241c:	e9 b2 fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022421 <intr82_stub>:
c0022421:	55                   	push   %ebp
c0022422:	6a 00                	push   $0x0
c0022424:	68 82 00 00 00       	push   $0x82
c0022429:	e9 a5 fa ff ff       	jmp    c0021ed3 <intr_entry>

c002242e <intr83_stub>:
c002242e:	55                   	push   %ebp
c002242f:	6a 00                	push   $0x0
c0022431:	68 83 00 00 00       	push   $0x83
c0022436:	e9 98 fa ff ff       	jmp    c0021ed3 <intr_entry>

c002243b <intr84_stub>:
STUB(84, zero) STUB(85, zero) STUB(86, zero) STUB(87, zero)
c002243b:	55                   	push   %ebp
c002243c:	6a 00                	push   $0x0
c002243e:	68 84 00 00 00       	push   $0x84
c0022443:	e9 8b fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022448 <intr85_stub>:
c0022448:	55                   	push   %ebp
c0022449:	6a 00                	push   $0x0
c002244b:	68 85 00 00 00       	push   $0x85
c0022450:	e9 7e fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022455 <intr86_stub>:
c0022455:	55                   	push   %ebp
c0022456:	6a 00                	push   $0x0
c0022458:	68 86 00 00 00       	push   $0x86
c002245d:	e9 71 fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022462 <intr87_stub>:
c0022462:	55                   	push   %ebp
c0022463:	6a 00                	push   $0x0
c0022465:	68 87 00 00 00       	push   $0x87
c002246a:	e9 64 fa ff ff       	jmp    c0021ed3 <intr_entry>

c002246f <intr88_stub>:
STUB(88, zero) STUB(89, zero) STUB(8a, zero) STUB(8b, zero)
c002246f:	55                   	push   %ebp
c0022470:	6a 00                	push   $0x0
c0022472:	68 88 00 00 00       	push   $0x88
c0022477:	e9 57 fa ff ff       	jmp    c0021ed3 <intr_entry>

c002247c <intr89_stub>:
c002247c:	55                   	push   %ebp
c002247d:	6a 00                	push   $0x0
c002247f:	68 89 00 00 00       	push   $0x89
c0022484:	e9 4a fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022489 <intr8a_stub>:
c0022489:	55                   	push   %ebp
c002248a:	6a 00                	push   $0x0
c002248c:	68 8a 00 00 00       	push   $0x8a
c0022491:	e9 3d fa ff ff       	jmp    c0021ed3 <intr_entry>

c0022496 <intr8b_stub>:
c0022496:	55                   	push   %ebp
c0022497:	6a 00                	push   $0x0
c0022499:	68 8b 00 00 00       	push   $0x8b
c002249e:	e9 30 fa ff ff       	jmp    c0021ed3 <intr_entry>

c00224a3 <intr8c_stub>:
STUB(8c, zero) STUB(8d, zero) STUB(8e, zero) STUB(8f, zero)
c00224a3:	55                   	push   %ebp
c00224a4:	6a 00                	push   $0x0
c00224a6:	68 8c 00 00 00       	push   $0x8c
c00224ab:	e9 23 fa ff ff       	jmp    c0021ed3 <intr_entry>

c00224b0 <intr8d_stub>:
c00224b0:	55                   	push   %ebp
c00224b1:	6a 00                	push   $0x0
c00224b3:	68 8d 00 00 00       	push   $0x8d
c00224b8:	e9 16 fa ff ff       	jmp    c0021ed3 <intr_entry>

c00224bd <intr8e_stub>:
c00224bd:	55                   	push   %ebp
c00224be:	6a 00                	push   $0x0
c00224c0:	68 8e 00 00 00       	push   $0x8e
c00224c5:	e9 09 fa ff ff       	jmp    c0021ed3 <intr_entry>

c00224ca <intr8f_stub>:
c00224ca:	55                   	push   %ebp
c00224cb:	6a 00                	push   $0x0
c00224cd:	68 8f 00 00 00       	push   $0x8f
c00224d2:	e9 fc f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00224d7 <intr90_stub>:

STUB(90, zero) STUB(91, zero) STUB(92, zero) STUB(93, zero)
c00224d7:	55                   	push   %ebp
c00224d8:	6a 00                	push   $0x0
c00224da:	68 90 00 00 00       	push   $0x90
c00224df:	e9 ef f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00224e4 <intr91_stub>:
c00224e4:	55                   	push   %ebp
c00224e5:	6a 00                	push   $0x0
c00224e7:	68 91 00 00 00       	push   $0x91
c00224ec:	e9 e2 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00224f1 <intr92_stub>:
c00224f1:	55                   	push   %ebp
c00224f2:	6a 00                	push   $0x0
c00224f4:	68 92 00 00 00       	push   $0x92
c00224f9:	e9 d5 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00224fe <intr93_stub>:
c00224fe:	55                   	push   %ebp
c00224ff:	6a 00                	push   $0x0
c0022501:	68 93 00 00 00       	push   $0x93
c0022506:	e9 c8 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c002250b <intr94_stub>:
STUB(94, zero) STUB(95, zero) STUB(96, zero) STUB(97, zero)
c002250b:	55                   	push   %ebp
c002250c:	6a 00                	push   $0x0
c002250e:	68 94 00 00 00       	push   $0x94
c0022513:	e9 bb f9 ff ff       	jmp    c0021ed3 <intr_entry>

c0022518 <intr95_stub>:
c0022518:	55                   	push   %ebp
c0022519:	6a 00                	push   $0x0
c002251b:	68 95 00 00 00       	push   $0x95
c0022520:	e9 ae f9 ff ff       	jmp    c0021ed3 <intr_entry>

c0022525 <intr96_stub>:
c0022525:	55                   	push   %ebp
c0022526:	6a 00                	push   $0x0
c0022528:	68 96 00 00 00       	push   $0x96
c002252d:	e9 a1 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c0022532 <intr97_stub>:
c0022532:	55                   	push   %ebp
c0022533:	6a 00                	push   $0x0
c0022535:	68 97 00 00 00       	push   $0x97
c002253a:	e9 94 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c002253f <intr98_stub>:
STUB(98, zero) STUB(99, zero) STUB(9a, zero) STUB(9b, zero)
c002253f:	55                   	push   %ebp
c0022540:	6a 00                	push   $0x0
c0022542:	68 98 00 00 00       	push   $0x98
c0022547:	e9 87 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c002254c <intr99_stub>:
c002254c:	55                   	push   %ebp
c002254d:	6a 00                	push   $0x0
c002254f:	68 99 00 00 00       	push   $0x99
c0022554:	e9 7a f9 ff ff       	jmp    c0021ed3 <intr_entry>

c0022559 <intr9a_stub>:
c0022559:	55                   	push   %ebp
c002255a:	6a 00                	push   $0x0
c002255c:	68 9a 00 00 00       	push   $0x9a
c0022561:	e9 6d f9 ff ff       	jmp    c0021ed3 <intr_entry>

c0022566 <intr9b_stub>:
c0022566:	55                   	push   %ebp
c0022567:	6a 00                	push   $0x0
c0022569:	68 9b 00 00 00       	push   $0x9b
c002256e:	e9 60 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c0022573 <intr9c_stub>:
STUB(9c, zero) STUB(9d, zero) STUB(9e, zero) STUB(9f, zero)
c0022573:	55                   	push   %ebp
c0022574:	6a 00                	push   $0x0
c0022576:	68 9c 00 00 00       	push   $0x9c
c002257b:	e9 53 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c0022580 <intr9d_stub>:
c0022580:	55                   	push   %ebp
c0022581:	6a 00                	push   $0x0
c0022583:	68 9d 00 00 00       	push   $0x9d
c0022588:	e9 46 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c002258d <intr9e_stub>:
c002258d:	55                   	push   %ebp
c002258e:	6a 00                	push   $0x0
c0022590:	68 9e 00 00 00       	push   $0x9e
c0022595:	e9 39 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c002259a <intr9f_stub>:
c002259a:	55                   	push   %ebp
c002259b:	6a 00                	push   $0x0
c002259d:	68 9f 00 00 00       	push   $0x9f
c00225a2:	e9 2c f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00225a7 <intra0_stub>:

STUB(a0, zero) STUB(a1, zero) STUB(a2, zero) STUB(a3, zero)
c00225a7:	55                   	push   %ebp
c00225a8:	6a 00                	push   $0x0
c00225aa:	68 a0 00 00 00       	push   $0xa0
c00225af:	e9 1f f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00225b4 <intra1_stub>:
c00225b4:	55                   	push   %ebp
c00225b5:	6a 00                	push   $0x0
c00225b7:	68 a1 00 00 00       	push   $0xa1
c00225bc:	e9 12 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00225c1 <intra2_stub>:
c00225c1:	55                   	push   %ebp
c00225c2:	6a 00                	push   $0x0
c00225c4:	68 a2 00 00 00       	push   $0xa2
c00225c9:	e9 05 f9 ff ff       	jmp    c0021ed3 <intr_entry>

c00225ce <intra3_stub>:
c00225ce:	55                   	push   %ebp
c00225cf:	6a 00                	push   $0x0
c00225d1:	68 a3 00 00 00       	push   $0xa3
c00225d6:	e9 f8 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c00225db <intra4_stub>:
STUB(a4, zero) STUB(a5, zero) STUB(a6, zero) STUB(a7, zero)
c00225db:	55                   	push   %ebp
c00225dc:	6a 00                	push   $0x0
c00225de:	68 a4 00 00 00       	push   $0xa4
c00225e3:	e9 eb f8 ff ff       	jmp    c0021ed3 <intr_entry>

c00225e8 <intra5_stub>:
c00225e8:	55                   	push   %ebp
c00225e9:	6a 00                	push   $0x0
c00225eb:	68 a5 00 00 00       	push   $0xa5
c00225f0:	e9 de f8 ff ff       	jmp    c0021ed3 <intr_entry>

c00225f5 <intra6_stub>:
c00225f5:	55                   	push   %ebp
c00225f6:	6a 00                	push   $0x0
c00225f8:	68 a6 00 00 00       	push   $0xa6
c00225fd:	e9 d1 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022602 <intra7_stub>:
c0022602:	55                   	push   %ebp
c0022603:	6a 00                	push   $0x0
c0022605:	68 a7 00 00 00       	push   $0xa7
c002260a:	e9 c4 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c002260f <intra8_stub>:
STUB(a8, zero) STUB(a9, zero) STUB(aa, zero) STUB(ab, zero)
c002260f:	55                   	push   %ebp
c0022610:	6a 00                	push   $0x0
c0022612:	68 a8 00 00 00       	push   $0xa8
c0022617:	e9 b7 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c002261c <intra9_stub>:
c002261c:	55                   	push   %ebp
c002261d:	6a 00                	push   $0x0
c002261f:	68 a9 00 00 00       	push   $0xa9
c0022624:	e9 aa f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022629 <intraa_stub>:
c0022629:	55                   	push   %ebp
c002262a:	6a 00                	push   $0x0
c002262c:	68 aa 00 00 00       	push   $0xaa
c0022631:	e9 9d f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022636 <intrab_stub>:
c0022636:	55                   	push   %ebp
c0022637:	6a 00                	push   $0x0
c0022639:	68 ab 00 00 00       	push   $0xab
c002263e:	e9 90 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022643 <intrac_stub>:
STUB(ac, zero) STUB(ad, zero) STUB(ae, zero) STUB(af, zero)
c0022643:	55                   	push   %ebp
c0022644:	6a 00                	push   $0x0
c0022646:	68 ac 00 00 00       	push   $0xac
c002264b:	e9 83 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022650 <intrad_stub>:
c0022650:	55                   	push   %ebp
c0022651:	6a 00                	push   $0x0
c0022653:	68 ad 00 00 00       	push   $0xad
c0022658:	e9 76 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c002265d <intrae_stub>:
c002265d:	55                   	push   %ebp
c002265e:	6a 00                	push   $0x0
c0022660:	68 ae 00 00 00       	push   $0xae
c0022665:	e9 69 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c002266a <intraf_stub>:
c002266a:	55                   	push   %ebp
c002266b:	6a 00                	push   $0x0
c002266d:	68 af 00 00 00       	push   $0xaf
c0022672:	e9 5c f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022677 <intrb0_stub>:

STUB(b0, zero) STUB(b1, zero) STUB(b2, zero) STUB(b3, zero)
c0022677:	55                   	push   %ebp
c0022678:	6a 00                	push   $0x0
c002267a:	68 b0 00 00 00       	push   $0xb0
c002267f:	e9 4f f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022684 <intrb1_stub>:
c0022684:	55                   	push   %ebp
c0022685:	6a 00                	push   $0x0
c0022687:	68 b1 00 00 00       	push   $0xb1
c002268c:	e9 42 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c0022691 <intrb2_stub>:
c0022691:	55                   	push   %ebp
c0022692:	6a 00                	push   $0x0
c0022694:	68 b2 00 00 00       	push   $0xb2
c0022699:	e9 35 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c002269e <intrb3_stub>:
c002269e:	55                   	push   %ebp
c002269f:	6a 00                	push   $0x0
c00226a1:	68 b3 00 00 00       	push   $0xb3
c00226a6:	e9 28 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c00226ab <intrb4_stub>:
STUB(b4, zero) STUB(b5, zero) STUB(b6, zero) STUB(b7, zero)
c00226ab:	55                   	push   %ebp
c00226ac:	6a 00                	push   $0x0
c00226ae:	68 b4 00 00 00       	push   $0xb4
c00226b3:	e9 1b f8 ff ff       	jmp    c0021ed3 <intr_entry>

c00226b8 <intrb5_stub>:
c00226b8:	55                   	push   %ebp
c00226b9:	6a 00                	push   $0x0
c00226bb:	68 b5 00 00 00       	push   $0xb5
c00226c0:	e9 0e f8 ff ff       	jmp    c0021ed3 <intr_entry>

c00226c5 <intrb6_stub>:
c00226c5:	55                   	push   %ebp
c00226c6:	6a 00                	push   $0x0
c00226c8:	68 b6 00 00 00       	push   $0xb6
c00226cd:	e9 01 f8 ff ff       	jmp    c0021ed3 <intr_entry>

c00226d2 <intrb7_stub>:
c00226d2:	55                   	push   %ebp
c00226d3:	6a 00                	push   $0x0
c00226d5:	68 b7 00 00 00       	push   $0xb7
c00226da:	e9 f4 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c00226df <intrb8_stub>:
STUB(b8, zero) STUB(b9, zero) STUB(ba, zero) STUB(bb, zero)
c00226df:	55                   	push   %ebp
c00226e0:	6a 00                	push   $0x0
c00226e2:	68 b8 00 00 00       	push   $0xb8
c00226e7:	e9 e7 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c00226ec <intrb9_stub>:
c00226ec:	55                   	push   %ebp
c00226ed:	6a 00                	push   $0x0
c00226ef:	68 b9 00 00 00       	push   $0xb9
c00226f4:	e9 da f7 ff ff       	jmp    c0021ed3 <intr_entry>

c00226f9 <intrba_stub>:
c00226f9:	55                   	push   %ebp
c00226fa:	6a 00                	push   $0x0
c00226fc:	68 ba 00 00 00       	push   $0xba
c0022701:	e9 cd f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022706 <intrbb_stub>:
c0022706:	55                   	push   %ebp
c0022707:	6a 00                	push   $0x0
c0022709:	68 bb 00 00 00       	push   $0xbb
c002270e:	e9 c0 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022713 <intrbc_stub>:
STUB(bc, zero) STUB(bd, zero) STUB(be, zero) STUB(bf, zero)
c0022713:	55                   	push   %ebp
c0022714:	6a 00                	push   $0x0
c0022716:	68 bc 00 00 00       	push   $0xbc
c002271b:	e9 b3 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022720 <intrbd_stub>:
c0022720:	55                   	push   %ebp
c0022721:	6a 00                	push   $0x0
c0022723:	68 bd 00 00 00       	push   $0xbd
c0022728:	e9 a6 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c002272d <intrbe_stub>:
c002272d:	55                   	push   %ebp
c002272e:	6a 00                	push   $0x0
c0022730:	68 be 00 00 00       	push   $0xbe
c0022735:	e9 99 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c002273a <intrbf_stub>:
c002273a:	55                   	push   %ebp
c002273b:	6a 00                	push   $0x0
c002273d:	68 bf 00 00 00       	push   $0xbf
c0022742:	e9 8c f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022747 <intrc0_stub>:

STUB(c0, zero) STUB(c1, zero) STUB(c2, zero) STUB(c3, zero)
c0022747:	55                   	push   %ebp
c0022748:	6a 00                	push   $0x0
c002274a:	68 c0 00 00 00       	push   $0xc0
c002274f:	e9 7f f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022754 <intrc1_stub>:
c0022754:	55                   	push   %ebp
c0022755:	6a 00                	push   $0x0
c0022757:	68 c1 00 00 00       	push   $0xc1
c002275c:	e9 72 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022761 <intrc2_stub>:
c0022761:	55                   	push   %ebp
c0022762:	6a 00                	push   $0x0
c0022764:	68 c2 00 00 00       	push   $0xc2
c0022769:	e9 65 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c002276e <intrc3_stub>:
c002276e:	55                   	push   %ebp
c002276f:	6a 00                	push   $0x0
c0022771:	68 c3 00 00 00       	push   $0xc3
c0022776:	e9 58 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c002277b <intrc4_stub>:
STUB(c4, zero) STUB(c5, zero) STUB(c6, zero) STUB(c7, zero)
c002277b:	55                   	push   %ebp
c002277c:	6a 00                	push   $0x0
c002277e:	68 c4 00 00 00       	push   $0xc4
c0022783:	e9 4b f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022788 <intrc5_stub>:
c0022788:	55                   	push   %ebp
c0022789:	6a 00                	push   $0x0
c002278b:	68 c5 00 00 00       	push   $0xc5
c0022790:	e9 3e f7 ff ff       	jmp    c0021ed3 <intr_entry>

c0022795 <intrc6_stub>:
c0022795:	55                   	push   %ebp
c0022796:	6a 00                	push   $0x0
c0022798:	68 c6 00 00 00       	push   $0xc6
c002279d:	e9 31 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c00227a2 <intrc7_stub>:
c00227a2:	55                   	push   %ebp
c00227a3:	6a 00                	push   $0x0
c00227a5:	68 c7 00 00 00       	push   $0xc7
c00227aa:	e9 24 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c00227af <intrc8_stub>:
STUB(c8, zero) STUB(c9, zero) STUB(ca, zero) STUB(cb, zero)
c00227af:	55                   	push   %ebp
c00227b0:	6a 00                	push   $0x0
c00227b2:	68 c8 00 00 00       	push   $0xc8
c00227b7:	e9 17 f7 ff ff       	jmp    c0021ed3 <intr_entry>

c00227bc <intrc9_stub>:
c00227bc:	55                   	push   %ebp
c00227bd:	6a 00                	push   $0x0
c00227bf:	68 c9 00 00 00       	push   $0xc9
c00227c4:	e9 0a f7 ff ff       	jmp    c0021ed3 <intr_entry>

c00227c9 <intrca_stub>:
c00227c9:	55                   	push   %ebp
c00227ca:	6a 00                	push   $0x0
c00227cc:	68 ca 00 00 00       	push   $0xca
c00227d1:	e9 fd f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00227d6 <intrcb_stub>:
c00227d6:	55                   	push   %ebp
c00227d7:	6a 00                	push   $0x0
c00227d9:	68 cb 00 00 00       	push   $0xcb
c00227de:	e9 f0 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00227e3 <intrcc_stub>:
STUB(cc, zero) STUB(cd, zero) STUB(ce, zero) STUB(cf, zero)
c00227e3:	55                   	push   %ebp
c00227e4:	6a 00                	push   $0x0
c00227e6:	68 cc 00 00 00       	push   $0xcc
c00227eb:	e9 e3 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00227f0 <intrcd_stub>:
c00227f0:	55                   	push   %ebp
c00227f1:	6a 00                	push   $0x0
c00227f3:	68 cd 00 00 00       	push   $0xcd
c00227f8:	e9 d6 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00227fd <intrce_stub>:
c00227fd:	55                   	push   %ebp
c00227fe:	6a 00                	push   $0x0
c0022800:	68 ce 00 00 00       	push   $0xce
c0022805:	e9 c9 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c002280a <intrcf_stub>:
c002280a:	55                   	push   %ebp
c002280b:	6a 00                	push   $0x0
c002280d:	68 cf 00 00 00       	push   $0xcf
c0022812:	e9 bc f6 ff ff       	jmp    c0021ed3 <intr_entry>

c0022817 <intrd0_stub>:

STUB(d0, zero) STUB(d1, zero) STUB(d2, zero) STUB(d3, zero)
c0022817:	55                   	push   %ebp
c0022818:	6a 00                	push   $0x0
c002281a:	68 d0 00 00 00       	push   $0xd0
c002281f:	e9 af f6 ff ff       	jmp    c0021ed3 <intr_entry>

c0022824 <intrd1_stub>:
c0022824:	55                   	push   %ebp
c0022825:	6a 00                	push   $0x0
c0022827:	68 d1 00 00 00       	push   $0xd1
c002282c:	e9 a2 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c0022831 <intrd2_stub>:
c0022831:	55                   	push   %ebp
c0022832:	6a 00                	push   $0x0
c0022834:	68 d2 00 00 00       	push   $0xd2
c0022839:	e9 95 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c002283e <intrd3_stub>:
c002283e:	55                   	push   %ebp
c002283f:	6a 00                	push   $0x0
c0022841:	68 d3 00 00 00       	push   $0xd3
c0022846:	e9 88 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c002284b <intrd4_stub>:
STUB(d4, zero) STUB(d5, zero) STUB(d6, zero) STUB(d7, zero)
c002284b:	55                   	push   %ebp
c002284c:	6a 00                	push   $0x0
c002284e:	68 d4 00 00 00       	push   $0xd4
c0022853:	e9 7b f6 ff ff       	jmp    c0021ed3 <intr_entry>

c0022858 <intrd5_stub>:
c0022858:	55                   	push   %ebp
c0022859:	6a 00                	push   $0x0
c002285b:	68 d5 00 00 00       	push   $0xd5
c0022860:	e9 6e f6 ff ff       	jmp    c0021ed3 <intr_entry>

c0022865 <intrd6_stub>:
c0022865:	55                   	push   %ebp
c0022866:	6a 00                	push   $0x0
c0022868:	68 d6 00 00 00       	push   $0xd6
c002286d:	e9 61 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c0022872 <intrd7_stub>:
c0022872:	55                   	push   %ebp
c0022873:	6a 00                	push   $0x0
c0022875:	68 d7 00 00 00       	push   $0xd7
c002287a:	e9 54 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c002287f <intrd8_stub>:
STUB(d8, zero) STUB(d9, zero) STUB(da, zero) STUB(db, zero)
c002287f:	55                   	push   %ebp
c0022880:	6a 00                	push   $0x0
c0022882:	68 d8 00 00 00       	push   $0xd8
c0022887:	e9 47 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c002288c <intrd9_stub>:
c002288c:	55                   	push   %ebp
c002288d:	6a 00                	push   $0x0
c002288f:	68 d9 00 00 00       	push   $0xd9
c0022894:	e9 3a f6 ff ff       	jmp    c0021ed3 <intr_entry>

c0022899 <intrda_stub>:
c0022899:	55                   	push   %ebp
c002289a:	6a 00                	push   $0x0
c002289c:	68 da 00 00 00       	push   $0xda
c00228a1:	e9 2d f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00228a6 <intrdb_stub>:
c00228a6:	55                   	push   %ebp
c00228a7:	6a 00                	push   $0x0
c00228a9:	68 db 00 00 00       	push   $0xdb
c00228ae:	e9 20 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00228b3 <intrdc_stub>:
STUB(dc, zero) STUB(dd, zero) STUB(de, zero) STUB(df, zero)
c00228b3:	55                   	push   %ebp
c00228b4:	6a 00                	push   $0x0
c00228b6:	68 dc 00 00 00       	push   $0xdc
c00228bb:	e9 13 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00228c0 <intrdd_stub>:
c00228c0:	55                   	push   %ebp
c00228c1:	6a 00                	push   $0x0
c00228c3:	68 dd 00 00 00       	push   $0xdd
c00228c8:	e9 06 f6 ff ff       	jmp    c0021ed3 <intr_entry>

c00228cd <intrde_stub>:
c00228cd:	55                   	push   %ebp
c00228ce:	6a 00                	push   $0x0
c00228d0:	68 de 00 00 00       	push   $0xde
c00228d5:	e9 f9 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c00228da <intrdf_stub>:
c00228da:	55                   	push   %ebp
c00228db:	6a 00                	push   $0x0
c00228dd:	68 df 00 00 00       	push   $0xdf
c00228e2:	e9 ec f5 ff ff       	jmp    c0021ed3 <intr_entry>

c00228e7 <intre0_stub>:

STUB(e0, zero) STUB(e1, zero) STUB(e2, zero) STUB(e3, zero)
c00228e7:	55                   	push   %ebp
c00228e8:	6a 00                	push   $0x0
c00228ea:	68 e0 00 00 00       	push   $0xe0
c00228ef:	e9 df f5 ff ff       	jmp    c0021ed3 <intr_entry>

c00228f4 <intre1_stub>:
c00228f4:	55                   	push   %ebp
c00228f5:	6a 00                	push   $0x0
c00228f7:	68 e1 00 00 00       	push   $0xe1
c00228fc:	e9 d2 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022901 <intre2_stub>:
c0022901:	55                   	push   %ebp
c0022902:	6a 00                	push   $0x0
c0022904:	68 e2 00 00 00       	push   $0xe2
c0022909:	e9 c5 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c002290e <intre3_stub>:
c002290e:	55                   	push   %ebp
c002290f:	6a 00                	push   $0x0
c0022911:	68 e3 00 00 00       	push   $0xe3
c0022916:	e9 b8 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c002291b <intre4_stub>:
STUB(e4, zero) STUB(e5, zero) STUB(e6, zero) STUB(e7, zero)
c002291b:	55                   	push   %ebp
c002291c:	6a 00                	push   $0x0
c002291e:	68 e4 00 00 00       	push   $0xe4
c0022923:	e9 ab f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022928 <intre5_stub>:
c0022928:	55                   	push   %ebp
c0022929:	6a 00                	push   $0x0
c002292b:	68 e5 00 00 00       	push   $0xe5
c0022930:	e9 9e f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022935 <intre6_stub>:
c0022935:	55                   	push   %ebp
c0022936:	6a 00                	push   $0x0
c0022938:	68 e6 00 00 00       	push   $0xe6
c002293d:	e9 91 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022942 <intre7_stub>:
c0022942:	55                   	push   %ebp
c0022943:	6a 00                	push   $0x0
c0022945:	68 e7 00 00 00       	push   $0xe7
c002294a:	e9 84 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c002294f <intre8_stub>:
STUB(e8, zero) STUB(e9, zero) STUB(ea, zero) STUB(eb, zero)
c002294f:	55                   	push   %ebp
c0022950:	6a 00                	push   $0x0
c0022952:	68 e8 00 00 00       	push   $0xe8
c0022957:	e9 77 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c002295c <intre9_stub>:
c002295c:	55                   	push   %ebp
c002295d:	6a 00                	push   $0x0
c002295f:	68 e9 00 00 00       	push   $0xe9
c0022964:	e9 6a f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022969 <intrea_stub>:
c0022969:	55                   	push   %ebp
c002296a:	6a 00                	push   $0x0
c002296c:	68 ea 00 00 00       	push   $0xea
c0022971:	e9 5d f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022976 <intreb_stub>:
c0022976:	55                   	push   %ebp
c0022977:	6a 00                	push   $0x0
c0022979:	68 eb 00 00 00       	push   $0xeb
c002297e:	e9 50 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022983 <intrec_stub>:
STUB(ec, zero) STUB(ed, zero) STUB(ee, zero) STUB(ef, zero)
c0022983:	55                   	push   %ebp
c0022984:	6a 00                	push   $0x0
c0022986:	68 ec 00 00 00       	push   $0xec
c002298b:	e9 43 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c0022990 <intred_stub>:
c0022990:	55                   	push   %ebp
c0022991:	6a 00                	push   $0x0
c0022993:	68 ed 00 00 00       	push   $0xed
c0022998:	e9 36 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c002299d <intree_stub>:
c002299d:	55                   	push   %ebp
c002299e:	6a 00                	push   $0x0
c00229a0:	68 ee 00 00 00       	push   $0xee
c00229a5:	e9 29 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c00229aa <intref_stub>:
c00229aa:	55                   	push   %ebp
c00229ab:	6a 00                	push   $0x0
c00229ad:	68 ef 00 00 00       	push   $0xef
c00229b2:	e9 1c f5 ff ff       	jmp    c0021ed3 <intr_entry>

c00229b7 <intrf0_stub>:

STUB(f0, zero) STUB(f1, zero) STUB(f2, zero) STUB(f3, zero)
c00229b7:	55                   	push   %ebp
c00229b8:	6a 00                	push   $0x0
c00229ba:	68 f0 00 00 00       	push   $0xf0
c00229bf:	e9 0f f5 ff ff       	jmp    c0021ed3 <intr_entry>

c00229c4 <intrf1_stub>:
c00229c4:	55                   	push   %ebp
c00229c5:	6a 00                	push   $0x0
c00229c7:	68 f1 00 00 00       	push   $0xf1
c00229cc:	e9 02 f5 ff ff       	jmp    c0021ed3 <intr_entry>

c00229d1 <intrf2_stub>:
c00229d1:	55                   	push   %ebp
c00229d2:	6a 00                	push   $0x0
c00229d4:	68 f2 00 00 00       	push   $0xf2
c00229d9:	e9 f5 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c00229de <intrf3_stub>:
c00229de:	55                   	push   %ebp
c00229df:	6a 00                	push   $0x0
c00229e1:	68 f3 00 00 00       	push   $0xf3
c00229e6:	e9 e8 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c00229eb <intrf4_stub>:
STUB(f4, zero) STUB(f5, zero) STUB(f6, zero) STUB(f7, zero)
c00229eb:	55                   	push   %ebp
c00229ec:	6a 00                	push   $0x0
c00229ee:	68 f4 00 00 00       	push   $0xf4
c00229f3:	e9 db f4 ff ff       	jmp    c0021ed3 <intr_entry>

c00229f8 <intrf5_stub>:
c00229f8:	55                   	push   %ebp
c00229f9:	6a 00                	push   $0x0
c00229fb:	68 f5 00 00 00       	push   $0xf5
c0022a00:	e9 ce f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a05 <intrf6_stub>:
c0022a05:	55                   	push   %ebp
c0022a06:	6a 00                	push   $0x0
c0022a08:	68 f6 00 00 00       	push   $0xf6
c0022a0d:	e9 c1 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a12 <intrf7_stub>:
c0022a12:	55                   	push   %ebp
c0022a13:	6a 00                	push   $0x0
c0022a15:	68 f7 00 00 00       	push   $0xf7
c0022a1a:	e9 b4 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a1f <intrf8_stub>:
STUB(f8, zero) STUB(f9, zero) STUB(fa, zero) STUB(fb, zero)
c0022a1f:	55                   	push   %ebp
c0022a20:	6a 00                	push   $0x0
c0022a22:	68 f8 00 00 00       	push   $0xf8
c0022a27:	e9 a7 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a2c <intrf9_stub>:
c0022a2c:	55                   	push   %ebp
c0022a2d:	6a 00                	push   $0x0
c0022a2f:	68 f9 00 00 00       	push   $0xf9
c0022a34:	e9 9a f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a39 <intrfa_stub>:
c0022a39:	55                   	push   %ebp
c0022a3a:	6a 00                	push   $0x0
c0022a3c:	68 fa 00 00 00       	push   $0xfa
c0022a41:	e9 8d f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a46 <intrfb_stub>:
c0022a46:	55                   	push   %ebp
c0022a47:	6a 00                	push   $0x0
c0022a49:	68 fb 00 00 00       	push   $0xfb
c0022a4e:	e9 80 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a53 <intrfc_stub>:
STUB(fc, zero) STUB(fd, zero) STUB(fe, zero) STUB(ff, zero)
c0022a53:	55                   	push   %ebp
c0022a54:	6a 00                	push   $0x0
c0022a56:	68 fc 00 00 00       	push   $0xfc
c0022a5b:	e9 73 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a60 <intrfd_stub>:
c0022a60:	55                   	push   %ebp
c0022a61:	6a 00                	push   $0x0
c0022a63:	68 fd 00 00 00       	push   $0xfd
c0022a68:	e9 66 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a6d <intrfe_stub>:
c0022a6d:	55                   	push   %ebp
c0022a6e:	6a 00                	push   $0x0
c0022a70:	68 fe 00 00 00       	push   $0xfe
c0022a75:	e9 59 f4 ff ff       	jmp    c0021ed3 <intr_entry>

c0022a7a <intrff_stub>:
c0022a7a:	55                   	push   %ebp
c0022a7b:	6a 00                	push   $0x0
c0022a7d:	68 ff 00 00 00       	push   $0xff
c0022a82:	e9 4c f4 ff ff       	jmp    c0021ed3 <intr_entry>
c0022a87:	90                   	nop
c0022a88:	90                   	nop
c0022a89:	90                   	nop
c0022a8a:	90                   	nop
c0022a8b:	90                   	nop
c0022a8c:	90                   	nop
c0022a8d:	90                   	nop
c0022a8e:	90                   	nop
c0022a8f:	90                   	nop

c0022a90 <thread_pri_cmp>:
static bool thread_pri_cmp(const struct list_elem *t1_,
                             const struct list_elem *t2_, void *aux UNUSED)
{
  const struct thread *t1 = list_entry (t1_, struct thread, elem);
  const struct thread *t2 = list_entry (t2_, struct thread, elem);
  return t1->priority < t2->priority;
c0022a90:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022a94:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022a98:	8b 40 f4             	mov    -0xc(%eax),%eax
c0022a9b:	39 42 f4             	cmp    %eax,-0xc(%edx)
c0022a9e:	0f 9c c0             	setl   %al
}
c0022aa1:	c3                   	ret    

c0022aa2 <lock_pri_cmp>:
static bool lock_pri_cmp(const struct list_elem *l1_,
                             const struct list_elem *l2_, void *aux UNUSED)
{
  const struct lock *l1 = list_entry (l1_, struct lock, elem);
  const struct lock *l2 = list_entry (l2_, struct lock, elem);
  return l1->max_priority > l2->max_priority;
c0022aa2:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022aa6:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022aaa:	8b 40 08             	mov    0x8(%eax),%eax
c0022aad:	39 42 08             	cmp    %eax,0x8(%edx)
c0022ab0:	0f 9f c0             	setg   %al
}
c0022ab3:	c3                   	ret    

c0022ab4 <cond_pri_cmp>:
static bool cond_pri_cmp(const struct list_elem *s1_,
                             const struct list_elem *s2_, void *aux UNUSED)
{
  const struct semaphore_elem *s1 = list_entry (s1_, struct semaphore_elem, elem);
  const struct semaphore_elem *s2 = list_entry (s2_, struct semaphore_elem, elem);
  return s1->priority < s2->priority;
c0022ab4:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022ab8:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022abc:	8b 40 1c             	mov    0x1c(%eax),%eax
c0022abf:	39 42 1c             	cmp    %eax,0x1c(%edx)
c0022ac2:	0f 9c c0             	setl   %al
}
c0022ac5:	c3                   	ret    

c0022ac6 <sema_init>:
{
c0022ac6:	83 ec 2c             	sub    $0x2c,%esp
c0022ac9:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (sema != NULL);
c0022acd:	85 c0                	test   %eax,%eax
c0022acf:	75 2c                	jne    c0022afd <sema_init+0x37>
c0022ad1:	c7 44 24 10 c2 e9 02 	movl   $0xc002e9c2,0x10(%esp)
c0022ad8:	c0 
c0022ad9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022ae0:	c0 
c0022ae1:	c7 44 24 08 2c d2 02 	movl   $0xc002d22c,0x8(%esp)
c0022ae8:	c0 
c0022ae9:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c0022af0:	00 
c0022af1:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022af8:	e8 66 5e 00 00       	call   c0028963 <debug_panic>
  sema->value = value;
c0022afd:	8b 54 24 34          	mov    0x34(%esp),%edx
c0022b01:	89 10                	mov    %edx,(%eax)
  list_init (&sema->waiters);
c0022b03:	83 c0 04             	add    $0x4,%eax
c0022b06:	89 04 24             	mov    %eax,(%esp)
c0022b09:	e8 22 5f 00 00       	call   c0028a30 <list_init>
}
c0022b0e:	83 c4 2c             	add    $0x2c,%esp
c0022b11:	c3                   	ret    

c0022b12 <sema_down>:
{
c0022b12:	57                   	push   %edi
c0022b13:	56                   	push   %esi
c0022b14:	53                   	push   %ebx
c0022b15:	83 ec 20             	sub    $0x20,%esp
c0022b18:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c0022b1c:	85 db                	test   %ebx,%ebx
c0022b1e:	75 2c                	jne    c0022b4c <sema_down+0x3a>
c0022b20:	c7 44 24 10 c2 e9 02 	movl   $0xc002e9c2,0x10(%esp)
c0022b27:	c0 
c0022b28:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022b2f:	c0 
c0022b30:	c7 44 24 08 22 d2 02 	movl   $0xc002d222,0x8(%esp)
c0022b37:	c0 
c0022b38:	c7 44 24 04 44 00 00 	movl   $0x44,0x4(%esp)
c0022b3f:	00 
c0022b40:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022b47:	e8 17 5e 00 00       	call   c0028963 <debug_panic>
  ASSERT (!intr_context ());
c0022b4c:	e8 b0 f0 ff ff       	call   c0021c01 <intr_context>
c0022b51:	84 c0                	test   %al,%al
c0022b53:	74 2c                	je     c0022b81 <sema_down+0x6f>
c0022b55:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c0022b5c:	c0 
c0022b5d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022b64:	c0 
c0022b65:	c7 44 24 08 22 d2 02 	movl   $0xc002d222,0x8(%esp)
c0022b6c:	c0 
c0022b6d:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c0022b74:	00 
c0022b75:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022b7c:	e8 e2 5d 00 00       	call   c0028963 <debug_panic>
  old_level = intr_disable ();
c0022b81:	e8 19 ee ff ff       	call   c002199f <intr_disable>
c0022b86:	89 c7                	mov    %eax,%edi
  while (sema->value == 0) 
c0022b88:	8b 13                	mov    (%ebx),%edx
c0022b8a:	85 d2                	test   %edx,%edx
c0022b8c:	75 22                	jne    c0022bb0 <sema_down+0x9e>
      list_push_back (&sema->waiters, &thread_current ()->elem);
c0022b8e:	8d 73 04             	lea    0x4(%ebx),%esi
c0022b91:	e8 43 e2 ff ff       	call   c0020dd9 <thread_current>
c0022b96:	83 c0 28             	add    $0x28,%eax
c0022b99:	89 44 24 04          	mov    %eax,0x4(%esp)
c0022b9d:	89 34 24             	mov    %esi,(%esp)
c0022ba0:	e8 0c 64 00 00       	call   c0028fb1 <list_push_back>
      thread_block ();
c0022ba5:	e8 65 e7 ff ff       	call   c002130f <thread_block>
  while (sema->value == 0) 
c0022baa:	8b 13                	mov    (%ebx),%edx
c0022bac:	85 d2                	test   %edx,%edx
c0022bae:	74 e1                	je     c0022b91 <sema_down+0x7f>
  sema->value--;
c0022bb0:	83 ea 01             	sub    $0x1,%edx
c0022bb3:	89 13                	mov    %edx,(%ebx)
  intr_set_level (old_level);
c0022bb5:	89 3c 24             	mov    %edi,(%esp)
c0022bb8:	e8 e9 ed ff ff       	call   c00219a6 <intr_set_level>
}
c0022bbd:	83 c4 20             	add    $0x20,%esp
c0022bc0:	5b                   	pop    %ebx
c0022bc1:	5e                   	pop    %esi
c0022bc2:	5f                   	pop    %edi
c0022bc3:	c3                   	ret    

c0022bc4 <sema_try_down>:
{
c0022bc4:	56                   	push   %esi
c0022bc5:	53                   	push   %ebx
c0022bc6:	83 ec 24             	sub    $0x24,%esp
c0022bc9:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c0022bcd:	85 db                	test   %ebx,%ebx
c0022bcf:	75 2c                	jne    c0022bfd <sema_try_down+0x39>
c0022bd1:	c7 44 24 10 c2 e9 02 	movl   $0xc002e9c2,0x10(%esp)
c0022bd8:	c0 
c0022bd9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022be0:	c0 
c0022be1:	c7 44 24 08 14 d2 02 	movl   $0xc002d214,0x8(%esp)
c0022be8:	c0 
c0022be9:	c7 44 24 04 5b 00 00 	movl   $0x5b,0x4(%esp)
c0022bf0:	00 
c0022bf1:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022bf8:	e8 66 5d 00 00       	call   c0028963 <debug_panic>
  old_level = intr_disable ();
c0022bfd:	e8 9d ed ff ff       	call   c002199f <intr_disable>
  if (sema->value > 0) 
c0022c02:	8b 13                	mov    (%ebx),%edx
    success = false;
c0022c04:	be 00 00 00 00       	mov    $0x0,%esi
  if (sema->value > 0) 
c0022c09:	85 d2                	test   %edx,%edx
c0022c0b:	74 0a                	je     c0022c17 <sema_try_down+0x53>
      sema->value--;
c0022c0d:	83 ea 01             	sub    $0x1,%edx
c0022c10:	89 13                	mov    %edx,(%ebx)
      success = true; 
c0022c12:	be 01 00 00 00       	mov    $0x1,%esi
  intr_set_level (old_level);
c0022c17:	89 04 24             	mov    %eax,(%esp)
c0022c1a:	e8 87 ed ff ff       	call   c00219a6 <intr_set_level>
}
c0022c1f:	89 f0                	mov    %esi,%eax
c0022c21:	83 c4 24             	add    $0x24,%esp
c0022c24:	5b                   	pop    %ebx
c0022c25:	5e                   	pop    %esi
c0022c26:	c3                   	ret    

c0022c27 <sema_up>:
{
c0022c27:	55                   	push   %ebp
c0022c28:	57                   	push   %edi
c0022c29:	56                   	push   %esi
c0022c2a:	53                   	push   %ebx
c0022c2b:	83 ec 2c             	sub    $0x2c,%esp
c0022c2e:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  ASSERT (sema != NULL);
c0022c32:	85 db                	test   %ebx,%ebx
c0022c34:	75 2c                	jne    c0022c62 <sema_up+0x3b>
c0022c36:	c7 44 24 10 c2 e9 02 	movl   $0xc002e9c2,0x10(%esp)
c0022c3d:	c0 
c0022c3e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022c45:	c0 
c0022c46:	c7 44 24 08 0c d2 02 	movl   $0xc002d20c,0x8(%esp)
c0022c4d:	c0 
c0022c4e:	c7 44 24 04 74 00 00 	movl   $0x74,0x4(%esp)
c0022c55:	00 
c0022c56:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022c5d:	e8 01 5d 00 00       	call   c0028963 <debug_panic>
  old_level = intr_disable ();
c0022c62:	e8 38 ed ff ff       	call   c002199f <intr_disable>
c0022c67:	89 c7                	mov    %eax,%edi
  if (!list_empty (&sema->waiters)) 
c0022c69:	8d 73 04             	lea    0x4(%ebx),%esi
c0022c6c:	89 34 24             	mov    %esi,(%esp)
c0022c6f:	e8 f2 63 00 00       	call   c0029066 <list_empty>
c0022c74:	84 c0                	test   %al,%al
c0022c76:	75 55                	jne    c0022ccd <sema_up+0xa6>
    e = list_max (&sema->waiters,thread_pri_cmp,NULL);
c0022c78:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0022c7f:	00 
c0022c80:	c7 44 24 04 90 2a 02 	movl   $0xc0022a90,0x4(%esp)
c0022c87:	c0 
c0022c88:	89 34 24             	mov    %esi,(%esp)
c0022c8b:	e8 aa 69 00 00       	call   c002963a <list_max>
c0022c90:	89 c6                	mov    %eax,%esi
    list_remove(e);
c0022c92:	89 04 24             	mov    %eax,(%esp)
c0022c95:	e8 3a 63 00 00       	call   c0028fd4 <list_remove>
    t = list_entry(e,struct thread,elem);
c0022c9a:	8d 6e d8             	lea    -0x28(%esi),%ebp
    thread_unblock (t);
c0022c9d:	89 2c 24             	mov    %ebp,(%esp)
c0022ca0:	e8 59 e0 ff ff       	call   c0020cfe <thread_unblock>
  sema->value++;
c0022ca5:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022ca8:	89 3c 24             	mov    %edi,(%esp)
c0022cab:	e8 f6 ec ff ff       	call   c00219a6 <intr_set_level>
  if(old_level == INTR_ON && t!=NULL) {
c0022cb0:	83 ff 01             	cmp    $0x1,%edi
c0022cb3:	75 23                	jne    c0022cd8 <sema_up+0xb1>
c0022cb5:	85 ed                	test   %ebp,%ebp
c0022cb7:	74 1f                	je     c0022cd8 <sema_up+0xb1>
    if(thread_current()->priority < t->priority)
c0022cb9:	e8 1b e1 ff ff       	call   c0020dd9 <thread_current>
c0022cbe:	8b 56 f4             	mov    -0xc(%esi),%edx
c0022cc1:	39 50 1c             	cmp    %edx,0x1c(%eax)
c0022cc4:	7d 12                	jge    c0022cd8 <sema_up+0xb1>
      thread_yield ();
c0022cc6:	e8 ba e7 ff ff       	call   c0021485 <thread_yield>
c0022ccb:	eb 0b                	jmp    c0022cd8 <sema_up+0xb1>
  sema->value++;
c0022ccd:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022cd0:	89 3c 24             	mov    %edi,(%esp)
c0022cd3:	e8 ce ec ff ff       	call   c00219a6 <intr_set_level>
}
c0022cd8:	83 c4 2c             	add    $0x2c,%esp
c0022cdb:	5b                   	pop    %ebx
c0022cdc:	5e                   	pop    %esi
c0022cdd:	5f                   	pop    %edi
c0022cde:	5d                   	pop    %ebp
c0022cdf:	c3                   	ret    

c0022ce0 <sema_test_helper>:
{
c0022ce0:	57                   	push   %edi
c0022ce1:	56                   	push   %esi
c0022ce2:	53                   	push   %ebx
c0022ce3:	83 ec 10             	sub    $0x10,%esp
c0022ce6:	8b 74 24 20          	mov    0x20(%esp),%esi
c0022cea:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[1]);
c0022cef:	8d 7e 14             	lea    0x14(%esi),%edi
      sema_down (&sema[0]);
c0022cf2:	89 34 24             	mov    %esi,(%esp)
c0022cf5:	e8 18 fe ff ff       	call   c0022b12 <sema_down>
      sema_up (&sema[1]);
c0022cfa:	89 3c 24             	mov    %edi,(%esp)
c0022cfd:	e8 25 ff ff ff       	call   c0022c27 <sema_up>
  for (i = 0; i < 10; i++) 
c0022d02:	83 eb 01             	sub    $0x1,%ebx
c0022d05:	75 eb                	jne    c0022cf2 <sema_test_helper+0x12>
}
c0022d07:	83 c4 10             	add    $0x10,%esp
c0022d0a:	5b                   	pop    %ebx
c0022d0b:	5e                   	pop    %esi
c0022d0c:	5f                   	pop    %edi
c0022d0d:	c3                   	ret    

c0022d0e <sema_self_test>:
{
c0022d0e:	57                   	push   %edi
c0022d0f:	56                   	push   %esi
c0022d10:	53                   	push   %ebx
c0022d11:	83 ec 40             	sub    $0x40,%esp
  printf ("Testing semaphores...");
c0022d14:	c7 04 24 e5 e9 02 c0 	movl   $0xc002e9e5,(%esp)
c0022d1b:	e8 ee 3d 00 00       	call   c0026b0e <printf>
  sema_init (&sema[0], 0);
c0022d20:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022d27:	00 
c0022d28:	8d 5c 24 18          	lea    0x18(%esp),%ebx
c0022d2c:	89 1c 24             	mov    %ebx,(%esp)
c0022d2f:	e8 92 fd ff ff       	call   c0022ac6 <sema_init>
  sema_init (&sema[1], 0);
c0022d34:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022d3b:	00 
c0022d3c:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c0022d40:	89 04 24             	mov    %eax,(%esp)
c0022d43:	e8 7e fd ff ff       	call   c0022ac6 <sema_init>
  thread_create ("sema-test", PRI_DEFAULT, sema_test_helper, &sema);
c0022d48:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0022d4c:	c7 44 24 08 e0 2c 02 	movl   $0xc0022ce0,0x8(%esp)
c0022d53:	c0 
c0022d54:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c0022d5b:	00 
c0022d5c:	c7 04 24 fb e9 02 c0 	movl   $0xc002e9fb,(%esp)
c0022d63:	e8 bf e7 ff ff       	call   c0021527 <thread_create>
c0022d68:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[0]);
c0022d6d:	8d 7c 24 18          	lea    0x18(%esp),%edi
      sema_down (&sema[1]);
c0022d71:	8d 74 24 2c          	lea    0x2c(%esp),%esi
      sema_up (&sema[0]);
c0022d75:	89 3c 24             	mov    %edi,(%esp)
c0022d78:	e8 aa fe ff ff       	call   c0022c27 <sema_up>
      sema_down (&sema[1]);
c0022d7d:	89 34 24             	mov    %esi,(%esp)
c0022d80:	e8 8d fd ff ff       	call   c0022b12 <sema_down>
  for (i = 0; i < 10; i++) 
c0022d85:	83 eb 01             	sub    $0x1,%ebx
c0022d88:	75 eb                	jne    c0022d75 <sema_self_test+0x67>
  printf ("done.\n");
c0022d8a:	c7 04 24 05 ea 02 c0 	movl   $0xc002ea05,(%esp)
c0022d91:	e8 f5 78 00 00       	call   c002a68b <puts>
}
c0022d96:	83 c4 40             	add    $0x40,%esp
c0022d99:	5b                   	pop    %ebx
c0022d9a:	5e                   	pop    %esi
c0022d9b:	5f                   	pop    %edi
c0022d9c:	c3                   	ret    

c0022d9d <lock_init>:
{
c0022d9d:	83 ec 2c             	sub    $0x2c,%esp
c0022da0:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022da4:	85 c0                	test   %eax,%eax
c0022da6:	75 2c                	jne    c0022dd4 <lock_init+0x37>
c0022da8:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c0022daf:	c0 
c0022db0:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022db7:	c0 
c0022db8:	c7 44 24 08 02 d2 02 	movl   $0xc002d202,0x8(%esp)
c0022dbf:	c0 
c0022dc0:	c7 44 24 04 bf 00 00 	movl   $0xbf,0x4(%esp)
c0022dc7:	00 
c0022dc8:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022dcf:	e8 8f 5b 00 00       	call   c0028963 <debug_panic>
  lock->holder = NULL;
c0022dd4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  sema_init (&lock->semaphore, 1);
c0022dda:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0022de1:	00 
c0022de2:	83 c0 04             	add    $0x4,%eax
c0022de5:	89 04 24             	mov    %eax,(%esp)
c0022de8:	e8 d9 fc ff ff       	call   c0022ac6 <sema_init>
}
c0022ded:	83 c4 2c             	add    $0x2c,%esp
c0022df0:	c3                   	ret    

c0022df1 <lock_held_by_current_thread>:
{
c0022df1:	53                   	push   %ebx
c0022df2:	83 ec 28             	sub    $0x28,%esp
c0022df5:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022df9:	85 c0                	test   %eax,%eax
c0022dfb:	75 2c                	jne    c0022e29 <lock_held_by_current_thread+0x38>
c0022dfd:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c0022e04:	c0 
c0022e05:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022e0c:	c0 
c0022e0d:	c7 44 24 08 bb d1 02 	movl   $0xc002d1bb,0x8(%esp)
c0022e14:	c0 
c0022e15:	c7 44 24 04 38 01 00 	movl   $0x138,0x4(%esp)
c0022e1c:	00 
c0022e1d:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022e24:	e8 3a 5b 00 00       	call   c0028963 <debug_panic>
  return lock->holder == thread_current ();
c0022e29:	8b 18                	mov    (%eax),%ebx
c0022e2b:	e8 a9 df ff ff       	call   c0020dd9 <thread_current>
c0022e30:	39 c3                	cmp    %eax,%ebx
c0022e32:	0f 94 c0             	sete   %al
}
c0022e35:	83 c4 28             	add    $0x28,%esp
c0022e38:	5b                   	pop    %ebx
c0022e39:	c3                   	ret    

c0022e3a <lock_acquire>:
{
c0022e3a:	56                   	push   %esi
c0022e3b:	53                   	push   %ebx
c0022e3c:	83 ec 24             	sub    $0x24,%esp
c0022e3f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022e43:	85 db                	test   %ebx,%ebx
c0022e45:	75 2c                	jne    c0022e73 <lock_acquire+0x39>
c0022e47:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c0022e4e:	c0 
c0022e4f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022e56:	c0 
c0022e57:	c7 44 24 08 f5 d1 02 	movl   $0xc002d1f5,0x8(%esp)
c0022e5e:	c0 
c0022e5f:	c7 44 24 04 d9 00 00 	movl   $0xd9,0x4(%esp)
c0022e66:	00 
c0022e67:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022e6e:	e8 f0 5a 00 00       	call   c0028963 <debug_panic>
  ASSERT (!intr_context ());
c0022e73:	e8 89 ed ff ff       	call   c0021c01 <intr_context>
c0022e78:	84 c0                	test   %al,%al
c0022e7a:	74 2c                	je     c0022ea8 <lock_acquire+0x6e>
c0022e7c:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c0022e83:	c0 
c0022e84:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022e8b:	c0 
c0022e8c:	c7 44 24 08 f5 d1 02 	movl   $0xc002d1f5,0x8(%esp)
c0022e93:	c0 
c0022e94:	c7 44 24 04 da 00 00 	movl   $0xda,0x4(%esp)
c0022e9b:	00 
c0022e9c:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022ea3:	e8 bb 5a 00 00       	call   c0028963 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022ea8:	89 1c 24             	mov    %ebx,(%esp)
c0022eab:	e8 41 ff ff ff       	call   c0022df1 <lock_held_by_current_thread>
c0022eb0:	84 c0                	test   %al,%al
c0022eb2:	74 2c                	je     c0022ee0 <lock_acquire+0xa6>
c0022eb4:	c7 44 24 10 28 ea 02 	movl   $0xc002ea28,0x10(%esp)
c0022ebb:	c0 
c0022ebc:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022ec3:	c0 
c0022ec4:	c7 44 24 08 f5 d1 02 	movl   $0xc002d1f5,0x8(%esp)
c0022ecb:	c0 
c0022ecc:	c7 44 24 04 db 00 00 	movl   $0xdb,0x4(%esp)
c0022ed3:	00 
c0022ed4:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022edb:	e8 83 5a 00 00       	call   c0028963 <debug_panic>
  old_level = intr_disable ();
c0022ee0:	e8 ba ea ff ff       	call   c002199f <intr_disable>
c0022ee5:	89 c6                	mov    %eax,%esi
  if(!thread_mlfqs && lock->holder != NULL)
c0022ee7:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0022eee:	75 20                	jne    c0022f10 <lock_acquire+0xd6>
c0022ef0:	83 3b 00             	cmpl   $0x0,(%ebx)
c0022ef3:	74 1b                	je     c0022f10 <lock_acquire+0xd6>
    int p = thread_get_priority();
c0022ef5:	e8 40 e0 ff ff       	call   c0020f3a <thread_get_priority>
    struct lock * l = lock;
c0022efa:	89 da                	mov    %ebx,%edx
       t = l->holder;
c0022efc:	8b 0a                	mov    (%edx),%ecx
       if( t->priority < p)
c0022efe:	3b 41 1c             	cmp    0x1c(%ecx),%eax
c0022f01:	7e 06                	jle    c0022f09 <lock_acquire+0xcf>
         t->priority = p;
c0022f03:	89 41 1c             	mov    %eax,0x1c(%ecx)
         l->max_priority = p;
c0022f06:	89 42 20             	mov    %eax,0x20(%edx)
       l = t->wait_on_lock;
c0022f09:	8b 51 50             	mov    0x50(%ecx),%edx
     } while(l != NULL);
c0022f0c:	85 d2                	test   %edx,%edx
c0022f0e:	75 ec                	jne    c0022efc <lock_acquire+0xc2>
  thread_current()->wait_on_lock = lock; //I'm waiting on this lock
c0022f10:	e8 c4 de ff ff       	call   c0020dd9 <thread_current>
c0022f15:	89 58 50             	mov    %ebx,0x50(%eax)
  intr_set_level (old_level);
c0022f18:	89 34 24             	mov    %esi,(%esp)
c0022f1b:	e8 86 ea ff ff       	call   c00219a6 <intr_set_level>
  sema_down (&lock->semaphore);          //lock acquired
c0022f20:	8d 43 04             	lea    0x4(%ebx),%eax
c0022f23:	89 04 24             	mov    %eax,(%esp)
c0022f26:	e8 e7 fb ff ff       	call   c0022b12 <sema_down>
  lock->holder = thread_current ();      //Now I'm the owner of this lock
c0022f2b:	e8 a9 de ff ff       	call   c0020dd9 <thread_current>
c0022f30:	89 03                	mov    %eax,(%ebx)
  thread_current()->wait_on_lock = NULL; //and now no more waiting for this lock
c0022f32:	e8 a2 de ff ff       	call   c0020dd9 <thread_current>
c0022f37:	c7 40 50 00 00 00 00 	movl   $0x0,0x50(%eax)
  list_insert_ordered(&(thread_current()->locks_held), &lock->elem, lock_pri_cmp,NULL);
c0022f3e:	e8 96 de ff ff       	call   c0020dd9 <thread_current>
c0022f43:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0022f4a:	00 
c0022f4b:	c7 44 24 08 a2 2a 02 	movl   $0xc0022aa2,0x8(%esp)
c0022f52:	c0 
c0022f53:	8d 53 18             	lea    0x18(%ebx),%edx
c0022f56:	89 54 24 04          	mov    %edx,0x4(%esp)
c0022f5a:	83 c0 40             	add    $0x40,%eax
c0022f5d:	89 04 24             	mov    %eax,(%esp)
c0022f60:	e8 f1 64 00 00       	call   c0029456 <list_insert_ordered>
  lock->max_priority = thread_get_priority();
c0022f65:	e8 d0 df ff ff       	call   c0020f3a <thread_get_priority>
c0022f6a:	89 43 20             	mov    %eax,0x20(%ebx)
}
c0022f6d:	83 c4 24             	add    $0x24,%esp
c0022f70:	5b                   	pop    %ebx
c0022f71:	5e                   	pop    %esi
c0022f72:	c3                   	ret    

c0022f73 <lock_try_acquire>:
{
c0022f73:	56                   	push   %esi
c0022f74:	53                   	push   %ebx
c0022f75:	83 ec 24             	sub    $0x24,%esp
c0022f78:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022f7c:	85 db                	test   %ebx,%ebx
c0022f7e:	75 2c                	jne    c0022fac <lock_try_acquire+0x39>
c0022f80:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c0022f87:	c0 
c0022f88:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022f8f:	c0 
c0022f90:	c7 44 24 08 e4 d1 02 	movl   $0xc002d1e4,0x8(%esp)
c0022f97:	c0 
c0022f98:	c7 44 24 04 04 01 00 	movl   $0x104,0x4(%esp)
c0022f9f:	00 
c0022fa0:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022fa7:	e8 b7 59 00 00       	call   c0028963 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022fac:	89 1c 24             	mov    %ebx,(%esp)
c0022faf:	e8 3d fe ff ff       	call   c0022df1 <lock_held_by_current_thread>
c0022fb4:	84 c0                	test   %al,%al
c0022fb6:	74 2c                	je     c0022fe4 <lock_try_acquire+0x71>
c0022fb8:	c7 44 24 10 28 ea 02 	movl   $0xc002ea28,0x10(%esp)
c0022fbf:	c0 
c0022fc0:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0022fc7:	c0 
c0022fc8:	c7 44 24 08 e4 d1 02 	movl   $0xc002d1e4,0x8(%esp)
c0022fcf:	c0 
c0022fd0:	c7 44 24 04 05 01 00 	movl   $0x105,0x4(%esp)
c0022fd7:	00 
c0022fd8:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0022fdf:	e8 7f 59 00 00       	call   c0028963 <debug_panic>
  success = sema_try_down (&lock->semaphore);
c0022fe4:	8d 43 04             	lea    0x4(%ebx),%eax
c0022fe7:	89 04 24             	mov    %eax,(%esp)
c0022fea:	e8 d5 fb ff ff       	call   c0022bc4 <sema_try_down>
c0022fef:	89 c6                	mov    %eax,%esi
  if (success)
c0022ff1:	84 c0                	test   %al,%al
c0022ff3:	74 07                	je     c0022ffc <lock_try_acquire+0x89>
    lock->holder = thread_current ();
c0022ff5:	e8 df dd ff ff       	call   c0020dd9 <thread_current>
c0022ffa:	89 03                	mov    %eax,(%ebx)
}
c0022ffc:	89 f0                	mov    %esi,%eax
c0022ffe:	83 c4 24             	add    $0x24,%esp
c0023001:	5b                   	pop    %ebx
c0023002:	5e                   	pop    %esi
c0023003:	c3                   	ret    

c0023004 <lock_release>:
{
c0023004:	57                   	push   %edi
c0023005:	56                   	push   %esi
c0023006:	53                   	push   %ebx
c0023007:	83 ec 20             	sub    $0x20,%esp
c002300a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c002300e:	85 db                	test   %ebx,%ebx
c0023010:	75 2c                	jne    c002303e <lock_release+0x3a>
c0023012:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c0023019:	c0 
c002301a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023021:	c0 
c0023022:	c7 44 24 08 d7 d1 02 	movl   $0xc002d1d7,0x8(%esp)
c0023029:	c0 
c002302a:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
c0023031:	00 
c0023032:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0023039:	e8 25 59 00 00       	call   c0028963 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c002303e:	89 1c 24             	mov    %ebx,(%esp)
c0023041:	e8 ab fd ff ff       	call   c0022df1 <lock_held_by_current_thread>
c0023046:	84 c0                	test   %al,%al
c0023048:	75 2c                	jne    c0023076 <lock_release+0x72>
c002304a:	c7 44 24 10 4c ea 02 	movl   $0xc002ea4c,0x10(%esp)
c0023051:	c0 
c0023052:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023059:	c0 
c002305a:	c7 44 24 08 d7 d1 02 	movl   $0xc002d1d7,0x8(%esp)
c0023061:	c0 
c0023062:	c7 44 24 04 15 01 00 	movl   $0x115,0x4(%esp)
c0023069:	00 
c002306a:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0023071:	e8 ed 58 00 00       	call   c0028963 <debug_panic>
  old_level = intr_disable ();
c0023076:	e8 24 e9 ff ff       	call   c002199f <intr_disable>
c002307b:	89 c6                	mov    %eax,%esi
  lock->holder = NULL;
c002307d:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  lock->max_priority = -1;
c0023083:	c7 43 20 ff ff ff ff 	movl   $0xffffffff,0x20(%ebx)
  list_remove(&lock->elem);
c002308a:	8d 43 18             	lea    0x18(%ebx),%eax
c002308d:	89 04 24             	mov    %eax,(%esp)
c0023090:	e8 3f 5f 00 00       	call   c0028fd4 <list_remove>
  if(!thread_mlfqs)
c0023095:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002309c:	75 45                	jne    c00230e3 <lock_release+0xdf>
    if(list_empty(&(thread_current()->locks_held)))
c002309e:	e8 36 dd ff ff       	call   c0020dd9 <thread_current>
c00230a3:	83 c0 40             	add    $0x40,%eax
c00230a6:	89 04 24             	mov    %eax,(%esp)
c00230a9:	e8 b8 5f 00 00       	call   c0029066 <list_empty>
c00230ae:	84 c0                	test   %al,%al
c00230b0:	74 14                	je     c00230c6 <lock_release+0xc2>
      thread_current()->priority = thread_current()->old_priority;
c00230b2:	e8 22 dd ff ff       	call   c0020dd9 <thread_current>
c00230b7:	89 c7                	mov    %eax,%edi
c00230b9:	e8 1b dd ff ff       	call   c0020dd9 <thread_current>
c00230be:	8b 40 3c             	mov    0x3c(%eax),%eax
c00230c1:	89 47 1c             	mov    %eax,0x1c(%edi)
c00230c4:	eb 1d                	jmp    c00230e3 <lock_release+0xdf>
      struct list_elem *elem1 = list_begin(&(thread_current()->locks_held));
c00230c6:	e8 0e dd ff ff       	call   c0020dd9 <thread_current>
c00230cb:	83 c0 40             	add    $0x40,%eax
c00230ce:	89 04 24             	mov    %eax,(%esp)
c00230d1:	e8 ab 59 00 00       	call   c0028a81 <list_begin>
c00230d6:	89 c7                	mov    %eax,%edi
      thread_current()->priority = next->max_priority;
c00230d8:	e8 fc dc ff ff       	call   c0020dd9 <thread_current>
c00230dd:	8b 57 08             	mov    0x8(%edi),%edx
c00230e0:	89 50 1c             	mov    %edx,0x1c(%eax)
  intr_set_level (old_level);
c00230e3:	89 34 24             	mov    %esi,(%esp)
c00230e6:	e8 bb e8 ff ff       	call   c00219a6 <intr_set_level>
  sema_up (&lock->semaphore);
c00230eb:	83 c3 04             	add    $0x4,%ebx
c00230ee:	89 1c 24             	mov    %ebx,(%esp)
c00230f1:	e8 31 fb ff ff       	call   c0022c27 <sema_up>
}
c00230f6:	83 c4 20             	add    $0x20,%esp
c00230f9:	5b                   	pop    %ebx
c00230fa:	5e                   	pop    %esi
c00230fb:	5f                   	pop    %edi
c00230fc:	c3                   	ret    

c00230fd <cond_init>:
/* Initializes condition variable COND.  A condition variable
   allows one piece of code to signal a condition and cooperating
   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
c00230fd:	83 ec 2c             	sub    $0x2c,%esp
c0023100:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (cond != NULL);
c0023104:	85 c0                	test   %eax,%eax
c0023106:	75 2c                	jne    c0023134 <cond_init+0x37>
c0023108:	c7 44 24 10 18 ea 02 	movl   $0xc002ea18,0x10(%esp)
c002310f:	c0 
c0023110:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023117:	c0 
c0023118:	c7 44 24 08 b1 d1 02 	movl   $0xc002d1b1,0x8(%esp)
c002311f:	c0 
c0023120:	c7 44 24 04 56 01 00 	movl   $0x156,0x4(%esp)
c0023127:	00 
c0023128:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c002312f:	e8 2f 58 00 00       	call   c0028963 <debug_panic>

  list_init (&cond->waiters);
c0023134:	89 04 24             	mov    %eax,(%esp)
c0023137:	e8 f4 58 00 00       	call   c0028a30 <list_init>
}
c002313c:	83 c4 2c             	add    $0x2c,%esp
c002313f:	c3                   	ret    

c0023140 <cond_wait>:
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
cond_wait (struct condition *cond, struct lock *lock) 
{
c0023140:	55                   	push   %ebp
c0023141:	57                   	push   %edi
c0023142:	56                   	push   %esi
c0023143:	53                   	push   %ebx
c0023144:	83 ec 4c             	sub    $0x4c,%esp
c0023147:	8b 74 24 60          	mov    0x60(%esp),%esi
c002314b:	8b 5c 24 64          	mov    0x64(%esp),%ebx
  struct semaphore_elem waiter;

  ASSERT (cond != NULL);
c002314f:	85 f6                	test   %esi,%esi
c0023151:	75 2c                	jne    c002317f <cond_wait+0x3f>
c0023153:	c7 44 24 10 18 ea 02 	movl   $0xc002ea18,0x10(%esp)
c002315a:	c0 
c002315b:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023162:	c0 
c0023163:	c7 44 24 08 a7 d1 02 	movl   $0xc002d1a7,0x8(%esp)
c002316a:	c0 
c002316b:	c7 44 24 04 71 01 00 	movl   $0x171,0x4(%esp)
c0023172:	00 
c0023173:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c002317a:	e8 e4 57 00 00       	call   c0028963 <debug_panic>
  ASSERT (lock != NULL);
c002317f:	85 db                	test   %ebx,%ebx
c0023181:	75 2c                	jne    c00231af <cond_wait+0x6f>
c0023183:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c002318a:	c0 
c002318b:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023192:	c0 
c0023193:	c7 44 24 08 a7 d1 02 	movl   $0xc002d1a7,0x8(%esp)
c002319a:	c0 
c002319b:	c7 44 24 04 72 01 00 	movl   $0x172,0x4(%esp)
c00231a2:	00 
c00231a3:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c00231aa:	e8 b4 57 00 00       	call   c0028963 <debug_panic>
  ASSERT (!intr_context ());
c00231af:	e8 4d ea ff ff       	call   c0021c01 <intr_context>
c00231b4:	84 c0                	test   %al,%al
c00231b6:	74 2c                	je     c00231e4 <cond_wait+0xa4>
c00231b8:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c00231bf:	c0 
c00231c0:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00231c7:	c0 
c00231c8:	c7 44 24 08 a7 d1 02 	movl   $0xc002d1a7,0x8(%esp)
c00231cf:	c0 
c00231d0:	c7 44 24 04 73 01 00 	movl   $0x173,0x4(%esp)
c00231d7:	00 
c00231d8:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c00231df:	e8 7f 57 00 00       	call   c0028963 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c00231e4:	89 1c 24             	mov    %ebx,(%esp)
c00231e7:	e8 05 fc ff ff       	call   c0022df1 <lock_held_by_current_thread>
c00231ec:	84 c0                	test   %al,%al
c00231ee:	75 2c                	jne    c002321c <cond_wait+0xdc>
c00231f0:	c7 44 24 10 4c ea 02 	movl   $0xc002ea4c,0x10(%esp)
c00231f7:	c0 
c00231f8:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00231ff:	c0 
c0023200:	c7 44 24 08 a7 d1 02 	movl   $0xc002d1a7,0x8(%esp)
c0023207:	c0 
c0023208:	c7 44 24 04 74 01 00 	movl   $0x174,0x4(%esp)
c002320f:	00 
c0023210:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0023217:	e8 47 57 00 00       	call   c0028963 <debug_panic>
  
  sema_init (&waiter.semaphore, 0);
c002321c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023223:	00 
c0023224:	8d 6c 24 20          	lea    0x20(%esp),%ebp
c0023228:	8d 7c 24 28          	lea    0x28(%esp),%edi
c002322c:	89 3c 24             	mov    %edi,(%esp)
c002322f:	e8 92 f8 ff ff       	call   c0022ac6 <sema_init>
  waiter.priority = thread_get_priority();
c0023234:	e8 01 dd ff ff       	call   c0020f3a <thread_get_priority>
c0023239:	89 44 24 3c          	mov    %eax,0x3c(%esp)

  list_push_back (&cond->waiters, &waiter.elem);
c002323d:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0023241:	89 34 24             	mov    %esi,(%esp)
c0023244:	e8 68 5d 00 00       	call   c0028fb1 <list_push_back>
  lock_release (lock);
c0023249:	89 1c 24             	mov    %ebx,(%esp)
c002324c:	e8 b3 fd ff ff       	call   c0023004 <lock_release>
  sema_down (&waiter.semaphore);
c0023251:	89 3c 24             	mov    %edi,(%esp)
c0023254:	e8 b9 f8 ff ff       	call   c0022b12 <sema_down>
  lock_acquire (lock);
c0023259:	89 1c 24             	mov    %ebx,(%esp)
c002325c:	e8 d9 fb ff ff       	call   c0022e3a <lock_acquire>
}
c0023261:	83 c4 4c             	add    $0x4c,%esp
c0023264:	5b                   	pop    %ebx
c0023265:	5e                   	pop    %esi
c0023266:	5f                   	pop    %edi
c0023267:	5d                   	pop    %ebp
c0023268:	c3                   	ret    

c0023269 <cond_signal>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_signal (struct condition *cond, struct lock *lock UNUSED) 
{
c0023269:	56                   	push   %esi
c002326a:	53                   	push   %ebx
c002326b:	83 ec 24             	sub    $0x24,%esp
c002326e:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0023272:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c0023276:	85 db                	test   %ebx,%ebx
c0023278:	75 2c                	jne    c00232a6 <cond_signal+0x3d>
c002327a:	c7 44 24 10 18 ea 02 	movl   $0xc002ea18,0x10(%esp)
c0023281:	c0 
c0023282:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023289:	c0 
c002328a:	c7 44 24 08 9b d1 02 	movl   $0xc002d19b,0x8(%esp)
c0023291:	c0 
c0023292:	c7 44 24 04 88 01 00 	movl   $0x188,0x4(%esp)
c0023299:	00 
c002329a:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c00232a1:	e8 bd 56 00 00       	call   c0028963 <debug_panic>
  ASSERT (lock != NULL);
c00232a6:	85 f6                	test   %esi,%esi
c00232a8:	75 2c                	jne    c00232d6 <cond_signal+0x6d>
c00232aa:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c00232b1:	c0 
c00232b2:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00232b9:	c0 
c00232ba:	c7 44 24 08 9b d1 02 	movl   $0xc002d19b,0x8(%esp)
c00232c1:	c0 
c00232c2:	c7 44 24 04 89 01 00 	movl   $0x189,0x4(%esp)
c00232c9:	00 
c00232ca:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c00232d1:	e8 8d 56 00 00       	call   c0028963 <debug_panic>
  ASSERT (!intr_context ());
c00232d6:	e8 26 e9 ff ff       	call   c0021c01 <intr_context>
c00232db:	84 c0                	test   %al,%al
c00232dd:	74 2c                	je     c002330b <cond_signal+0xa2>
c00232df:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c00232e6:	c0 
c00232e7:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00232ee:	c0 
c00232ef:	c7 44 24 08 9b d1 02 	movl   $0xc002d19b,0x8(%esp)
c00232f6:	c0 
c00232f7:	c7 44 24 04 8a 01 00 	movl   $0x18a,0x4(%esp)
c00232fe:	00 
c00232ff:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c0023306:	e8 58 56 00 00       	call   c0028963 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c002330b:	89 34 24             	mov    %esi,(%esp)
c002330e:	e8 de fa ff ff       	call   c0022df1 <lock_held_by_current_thread>
c0023313:	84 c0                	test   %al,%al
c0023315:	75 2c                	jne    c0023343 <cond_signal+0xda>
c0023317:	c7 44 24 10 4c ea 02 	movl   $0xc002ea4c,0x10(%esp)
c002331e:	c0 
c002331f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023326:	c0 
c0023327:	c7 44 24 08 9b d1 02 	movl   $0xc002d19b,0x8(%esp)
c002332e:	c0 
c002332f:	c7 44 24 04 8b 01 00 	movl   $0x18b,0x4(%esp)
c0023336:	00 
c0023337:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c002333e:	e8 20 56 00 00       	call   c0028963 <debug_panic>

  struct list_elem *e;
  if (!list_empty (&cond->waiters)) 
c0023343:	89 1c 24             	mov    %ebx,(%esp)
c0023346:	e8 1b 5d 00 00       	call   c0029066 <list_empty>
c002334b:	84 c0                	test   %al,%al
c002334d:	75 2d                	jne    c002337c <cond_signal+0x113>
  {
    /* MODIFY PRIORITY: max priority blocked thread on cond should be woken up */
    //sema_up (&list_entry (list_pop_front (&cond->waiters), struct semaphore_elem, elem)->semaphore);
    e = list_max (&cond->waiters,cond_pri_cmp,NULL);
c002334f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0023356:	00 
c0023357:	c7 44 24 04 b4 2a 02 	movl   $0xc0022ab4,0x4(%esp)
c002335e:	c0 
c002335f:	89 1c 24             	mov    %ebx,(%esp)
c0023362:	e8 d3 62 00 00       	call   c002963a <list_max>
c0023367:	89 c3                	mov    %eax,%ebx
    list_remove(e);
c0023369:	89 04 24             	mov    %eax,(%esp)
c002336c:	e8 63 5c 00 00       	call   c0028fd4 <list_remove>
    sema_up (&list_entry(e,struct semaphore_elem,elem)->semaphore);
c0023371:	83 c3 08             	add    $0x8,%ebx
c0023374:	89 1c 24             	mov    %ebx,(%esp)
c0023377:	e8 ab f8 ff ff       	call   c0022c27 <sema_up>
  }
}
c002337c:	83 c4 24             	add    $0x24,%esp
c002337f:	5b                   	pop    %ebx
c0023380:	5e                   	pop    %esi
c0023381:	c3                   	ret    

c0023382 <cond_broadcast>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock) 
{
c0023382:	56                   	push   %esi
c0023383:	53                   	push   %ebx
c0023384:	83 ec 24             	sub    $0x24,%esp
c0023387:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002338b:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c002338f:	85 db                	test   %ebx,%ebx
c0023391:	75 2c                	jne    c00233bf <cond_broadcast+0x3d>
c0023393:	c7 44 24 10 18 ea 02 	movl   $0xc002ea18,0x10(%esp)
c002339a:	c0 
c002339b:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00233a2:	c0 
c00233a3:	c7 44 24 08 8c d1 02 	movl   $0xc002d18c,0x8(%esp)
c00233aa:	c0 
c00233ab:	c7 44 24 04 a0 01 00 	movl   $0x1a0,0x4(%esp)
c00233b2:	00 
c00233b3:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c00233ba:	e8 a4 55 00 00       	call   c0028963 <debug_panic>
  ASSERT (lock != NULL);
c00233bf:	85 f6                	test   %esi,%esi
c00233c1:	75 38                	jne    c00233fb <cond_broadcast+0x79>
c00233c3:	c7 44 24 10 0b ea 02 	movl   $0xc002ea0b,0x10(%esp)
c00233ca:	c0 
c00233cb:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00233d2:	c0 
c00233d3:	c7 44 24 08 8c d1 02 	movl   $0xc002d18c,0x8(%esp)
c00233da:	c0 
c00233db:	c7 44 24 04 a1 01 00 	movl   $0x1a1,0x4(%esp)
c00233e2:	00 
c00233e3:	c7 04 24 cf e9 02 c0 	movl   $0xc002e9cf,(%esp)
c00233ea:	e8 74 55 00 00       	call   c0028963 <debug_panic>

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
c00233ef:	89 74 24 04          	mov    %esi,0x4(%esp)
c00233f3:	89 1c 24             	mov    %ebx,(%esp)
c00233f6:	e8 6e fe ff ff       	call   c0023269 <cond_signal>
  while (!list_empty (&cond->waiters))
c00233fb:	89 1c 24             	mov    %ebx,(%esp)
c00233fe:	e8 63 5c 00 00       	call   c0029066 <list_empty>
c0023403:	84 c0                	test   %al,%al
c0023405:	74 e8                	je     c00233ef <cond_broadcast+0x6d>
c0023407:	83 c4 24             	add    $0x24,%esp
c002340a:	5b                   	pop    %ebx
c002340b:	5e                   	pop    %esi
c002340c:	c3                   	ret    

c002340d <init_pool>:

/* Initializes pool P as starting at START and ending at END,
   naming it NAME for debugging purposes. */
static void
init_pool (struct pool *p, void *base, size_t page_cnt, const char *name) 
{
c002340d:	55                   	push   %ebp
c002340e:	57                   	push   %edi
c002340f:	56                   	push   %esi
c0023410:	53                   	push   %ebx
c0023411:	83 ec 2c             	sub    $0x2c,%esp
c0023414:	89 c7                	mov    %eax,%edi
c0023416:	89 d5                	mov    %edx,%ebp
c0023418:	89 cb                	mov    %ecx,%ebx
  /* We'll put the pool's used_map at its base.
     Calculate the space needed for the bitmap
     and subtract it from the pool's size. */
  size_t bm_pages = DIV_ROUND_UP (bitmap_buf_size (page_cnt), PGSIZE);
c002341a:	89 0c 24             	mov    %ecx,(%esp)
c002341d:	e8 ee 62 00 00       	call   c0029710 <bitmap_buf_size>
c0023422:	8d b0 ff 0f 00 00    	lea    0xfff(%eax),%esi
c0023428:	c1 ee 0c             	shr    $0xc,%esi
  if (bm_pages > page_cnt)
c002342b:	39 f3                	cmp    %esi,%ebx
c002342d:	73 2c                	jae    c002345b <init_pool+0x4e>
    PANIC ("Not enough memory in %s for bitmap.", name);
c002342f:	8b 44 24 40          	mov    0x40(%esp),%eax
c0023433:	89 44 24 10          	mov    %eax,0x10(%esp)
c0023437:	c7 44 24 0c 70 ea 02 	movl   $0xc002ea70,0xc(%esp)
c002343e:	c0 
c002343f:	c7 44 24 08 5f d2 02 	movl   $0xc002d25f,0x8(%esp)
c0023446:	c0 
c0023447:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c002344e:	00 
c002344f:	c7 04 24 c4 ea 02 c0 	movl   $0xc002eac4,(%esp)
c0023456:	e8 08 55 00 00       	call   c0028963 <debug_panic>
  page_cnt -= bm_pages;
c002345b:	29 f3                	sub    %esi,%ebx

  printf ("%zu pages available in %s.\n", page_cnt, name);
c002345d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0023461:	89 44 24 08          	mov    %eax,0x8(%esp)
c0023465:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023469:	c7 04 24 db ea 02 c0 	movl   $0xc002eadb,(%esp)
c0023470:	e8 99 36 00 00       	call   c0026b0e <printf>

  /* Initialize the pool. */
  lock_init (&p->lock);
c0023475:	89 3c 24             	mov    %edi,(%esp)
c0023478:	e8 20 f9 ff ff       	call   c0022d9d <lock_init>
  p->used_map = bitmap_create_in_buf (page_cnt, base, bm_pages * PGSIZE);
c002347d:	c1 e6 0c             	shl    $0xc,%esi
c0023480:	89 74 24 08          	mov    %esi,0x8(%esp)
c0023484:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0023488:	89 1c 24             	mov    %ebx,(%esp)
c002348b:	e8 c5 65 00 00       	call   c0029a55 <bitmap_create_in_buf>
c0023490:	89 47 24             	mov    %eax,0x24(%edi)
  p->base = base + bm_pages * PGSIZE;
c0023493:	01 ee                	add    %ebp,%esi
c0023495:	89 77 28             	mov    %esi,0x28(%edi)
}
c0023498:	83 c4 2c             	add    $0x2c,%esp
c002349b:	5b                   	pop    %ebx
c002349c:	5e                   	pop    %esi
c002349d:	5f                   	pop    %edi
c002349e:	5d                   	pop    %ebp
c002349f:	c3                   	ret    

c00234a0 <palloc_init>:
{
c00234a0:	56                   	push   %esi
c00234a1:	53                   	push   %ebx
c00234a2:	83 ec 24             	sub    $0x24,%esp
c00234a5:	8b 54 24 30          	mov    0x30(%esp),%edx
  uint8_t *free_end = ptov (init_ram_pages * PGSIZE);
c00234a9:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c00234ae:	c1 e0 0c             	shl    $0xc,%eax
  ASSERT ((void *) paddr < PHYS_BASE);
c00234b1:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c00234b6:	76 2c                	jbe    c00234e4 <palloc_init+0x44>
c00234b8:	c7 44 24 10 16 e1 02 	movl   $0xc002e116,0x10(%esp)
c00234bf:	c0 
c00234c0:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00234c7:	c0 
c00234c8:	c7 44 24 08 69 d2 02 	movl   $0xc002d269,0x8(%esp)
c00234cf:	c0 
c00234d0:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c00234d7:	00 
c00234d8:	c7 04 24 48 e1 02 c0 	movl   $0xc002e148,(%esp)
c00234df:	e8 7f 54 00 00       	call   c0028963 <debug_panic>
  size_t free_pages = (free_end - free_start) / PGSIZE;
c00234e4:	8d b0 ff 0f f0 ff    	lea    -0xff001(%eax),%esi
c00234ea:	2d 00 00 10 00       	sub    $0x100000,%eax
c00234ef:	0f 49 f0             	cmovns %eax,%esi
c00234f2:	c1 fe 0c             	sar    $0xc,%esi
  size_t user_pages = free_pages / 2;
c00234f5:	89 f3                	mov    %esi,%ebx
c00234f7:	d1 eb                	shr    %ebx
c00234f9:	39 d3                	cmp    %edx,%ebx
c00234fb:	0f 47 da             	cmova  %edx,%ebx
  kernel_pages = free_pages - user_pages;
c00234fe:	29 de                	sub    %ebx,%esi
  init_pool (&kernel_pool, free_start, kernel_pages, "kernel pool");
c0023500:	c7 04 24 f7 ea 02 c0 	movl   $0xc002eaf7,(%esp)
c0023507:	89 f1                	mov    %esi,%ecx
c0023509:	ba 00 00 10 c0       	mov    $0xc0100000,%edx
c002350e:	b8 a0 74 03 c0       	mov    $0xc00374a0,%eax
c0023513:	e8 f5 fe ff ff       	call   c002340d <init_pool>
  init_pool (&user_pool, free_start + kernel_pages * PGSIZE,
c0023518:	c1 e6 0c             	shl    $0xc,%esi
c002351b:	8d 96 00 00 10 c0    	lea    -0x3ff00000(%esi),%edx
c0023521:	c7 04 24 03 eb 02 c0 	movl   $0xc002eb03,(%esp)
c0023528:	89 d9                	mov    %ebx,%ecx
c002352a:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c002352f:	e8 d9 fe ff ff       	call   c002340d <init_pool>
}
c0023534:	83 c4 24             	add    $0x24,%esp
c0023537:	5b                   	pop    %ebx
c0023538:	5e                   	pop    %esi
c0023539:	c3                   	ret    

c002353a <palloc_get_multiple>:
{
c002353a:	55                   	push   %ebp
c002353b:	57                   	push   %edi
c002353c:	56                   	push   %esi
c002353d:	53                   	push   %ebx
c002353e:	83 ec 1c             	sub    $0x1c,%esp
c0023541:	8b 74 24 30          	mov    0x30(%esp),%esi
c0023545:	8b 7c 24 34          	mov    0x34(%esp),%edi
  struct pool *pool = flags & PAL_USER ? &user_pool : &kernel_pool;
c0023549:	89 f0                	mov    %esi,%eax
c002354b:	83 e0 04             	and    $0x4,%eax
c002354e:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c0023553:	bb a0 74 03 c0       	mov    $0xc00374a0,%ebx
c0023558:	0f 45 d8             	cmovne %eax,%ebx
  if (page_cnt == 0)
c002355b:	85 ff                	test   %edi,%edi
c002355d:	0f 84 8f 00 00 00    	je     c00235f2 <palloc_get_multiple+0xb8>
  lock_acquire (&pool->lock);
c0023563:	89 1c 24             	mov    %ebx,(%esp)
c0023566:	e8 cf f8 ff ff       	call   c0022e3a <lock_acquire>
  page_idx = bitmap_scan_and_flip (pool->used_map, 0, page_cnt, false);
c002356b:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023572:	00 
c0023573:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0023577:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002357e:	00 
c002357f:	8b 43 24             	mov    0x24(%ebx),%eax
c0023582:	89 04 24             	mov    %eax,(%esp)
c0023585:	e8 50 68 00 00       	call   c0029dda <bitmap_scan_and_flip>
c002358a:	89 c5                	mov    %eax,%ebp
  lock_release (&pool->lock);
c002358c:	89 1c 24             	mov    %ebx,(%esp)
c002358f:	e8 70 fa ff ff       	call   c0023004 <lock_release>
  if (page_idx != BITMAP_ERROR)
c0023594:	83 fd ff             	cmp    $0xffffffff,%ebp
c0023597:	74 2d                	je     c00235c6 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c0023599:	c1 e5 0c             	shl    $0xc,%ebp
  if (pages != NULL) 
c002359c:	03 6b 28             	add    0x28(%ebx),%ebp
c002359f:	74 25                	je     c00235c6 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c00235a1:	89 e8                	mov    %ebp,%eax
      if (flags & PAL_ZERO)
c00235a3:	f7 c6 02 00 00 00    	test   $0x2,%esi
c00235a9:	74 53                	je     c00235fe <palloc_get_multiple+0xc4>
        memset (pages, 0, PGSIZE * page_cnt);
c00235ab:	c1 e7 0c             	shl    $0xc,%edi
c00235ae:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00235b2:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00235b9:	00 
c00235ba:	89 2c 24             	mov    %ebp,(%esp)
c00235bd:	e8 5f 48 00 00       	call   c0027e21 <memset>
    pages = pool->base + PGSIZE * page_idx;
c00235c2:	89 e8                	mov    %ebp,%eax
c00235c4:	eb 38                	jmp    c00235fe <palloc_get_multiple+0xc4>
      if (flags & PAL_ASSERT)
c00235c6:	f7 c6 01 00 00 00    	test   $0x1,%esi
c00235cc:	74 2b                	je     c00235f9 <palloc_get_multiple+0xbf>
        PANIC ("palloc_get: out of pages");
c00235ce:	c7 44 24 0c 0d eb 02 	movl   $0xc002eb0d,0xc(%esp)
c00235d5:	c0 
c00235d6:	c7 44 24 08 4b d2 02 	movl   $0xc002d24b,0x8(%esp)
c00235dd:	c0 
c00235de:	c7 44 24 04 61 00 00 	movl   $0x61,0x4(%esp)
c00235e5:	00 
c00235e6:	c7 04 24 c4 ea 02 c0 	movl   $0xc002eac4,(%esp)
c00235ed:	e8 71 53 00 00       	call   c0028963 <debug_panic>
    return NULL;
c00235f2:	b8 00 00 00 00       	mov    $0x0,%eax
c00235f7:	eb 05                	jmp    c00235fe <palloc_get_multiple+0xc4>
  return pages;
c00235f9:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00235fe:	83 c4 1c             	add    $0x1c,%esp
c0023601:	5b                   	pop    %ebx
c0023602:	5e                   	pop    %esi
c0023603:	5f                   	pop    %edi
c0023604:	5d                   	pop    %ebp
c0023605:	c3                   	ret    

c0023606 <palloc_get_page>:
{
c0023606:	83 ec 1c             	sub    $0x1c,%esp
  return palloc_get_multiple (flags, 1);
c0023609:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023610:	00 
c0023611:	8b 44 24 20          	mov    0x20(%esp),%eax
c0023615:	89 04 24             	mov    %eax,(%esp)
c0023618:	e8 1d ff ff ff       	call   c002353a <palloc_get_multiple>
}
c002361d:	83 c4 1c             	add    $0x1c,%esp
c0023620:	c3                   	ret    

c0023621 <palloc_free_multiple>:
{
c0023621:	55                   	push   %ebp
c0023622:	57                   	push   %edi
c0023623:	56                   	push   %esi
c0023624:	53                   	push   %ebx
c0023625:	83 ec 2c             	sub    $0x2c,%esp
c0023628:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c002362c:	8b 74 24 44          	mov    0x44(%esp),%esi
  ASSERT (pg_ofs (pages) == 0);
c0023630:	f7 c3 ff 0f 00 00    	test   $0xfff,%ebx
c0023636:	74 2c                	je     c0023664 <palloc_free_multiple+0x43>
c0023638:	c7 44 24 10 26 eb 02 	movl   $0xc002eb26,0x10(%esp)
c002363f:	c0 
c0023640:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023647:	c0 
c0023648:	c7 44 24 08 36 d2 02 	movl   $0xc002d236,0x8(%esp)
c002364f:	c0 
c0023650:	c7 44 24 04 7b 00 00 	movl   $0x7b,0x4(%esp)
c0023657:	00 
c0023658:	c7 04 24 c4 ea 02 c0 	movl   $0xc002eac4,(%esp)
c002365f:	e8 ff 52 00 00       	call   c0028963 <debug_panic>
  if (pages == NULL || page_cnt == 0)
c0023664:	85 db                	test   %ebx,%ebx
c0023666:	0f 84 fc 00 00 00    	je     c0023768 <palloc_free_multiple+0x147>
c002366c:	85 f6                	test   %esi,%esi
c002366e:	0f 84 f4 00 00 00    	je     c0023768 <palloc_free_multiple+0x147>
  return (uintptr_t) va >> PGBITS;
c0023674:	89 df                	mov    %ebx,%edi
c0023676:	c1 ef 0c             	shr    $0xc,%edi
c0023679:	8b 2d c8 74 03 c0    	mov    0xc00374c8,%ebp
c002367f:	c1 ed 0c             	shr    $0xc,%ebp
static bool
page_from_pool (const struct pool *pool, void *page) 
{
  size_t page_no = pg_no (page);
  size_t start_page = pg_no (pool->base);
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0023682:	a1 c4 74 03 c0       	mov    0xc00374c4,%eax
c0023687:	89 04 24             	mov    %eax,(%esp)
c002368a:	e8 b7 60 00 00       	call   c0029746 <bitmap_size>
c002368f:	01 e8                	add    %ebp,%eax
  if (page_from_pool (&kernel_pool, pages))
c0023691:	39 c7                	cmp    %eax,%edi
c0023693:	73 04                	jae    c0023699 <palloc_free_multiple+0x78>
c0023695:	39 ef                	cmp    %ebp,%edi
c0023697:	73 44                	jae    c00236dd <palloc_free_multiple+0xbc>
c0023699:	8b 2d 88 74 03 c0    	mov    0xc0037488,%ebp
c002369f:	c1 ed 0c             	shr    $0xc,%ebp
  size_t end_page = start_page + bitmap_size (pool->used_map);
c00236a2:	a1 84 74 03 c0       	mov    0xc0037484,%eax
c00236a7:	89 04 24             	mov    %eax,(%esp)
c00236aa:	e8 97 60 00 00       	call   c0029746 <bitmap_size>
c00236af:	01 e8                	add    %ebp,%eax
  else if (page_from_pool (&user_pool, pages))
c00236b1:	39 c7                	cmp    %eax,%edi
c00236b3:	73 04                	jae    c00236b9 <palloc_free_multiple+0x98>
c00236b5:	39 ef                	cmp    %ebp,%edi
c00236b7:	73 2b                	jae    c00236e4 <palloc_free_multiple+0xc3>
    NOT_REACHED ();
c00236b9:	c7 44 24 0c f8 e5 02 	movl   $0xc002e5f8,0xc(%esp)
c00236c0:	c0 
c00236c1:	c7 44 24 08 36 d2 02 	movl   $0xc002d236,0x8(%esp)
c00236c8:	c0 
c00236c9:	c7 44 24 04 84 00 00 	movl   $0x84,0x4(%esp)
c00236d0:	00 
c00236d1:	c7 04 24 c4 ea 02 c0 	movl   $0xc002eac4,(%esp)
c00236d8:	e8 86 52 00 00       	call   c0028963 <debug_panic>
    pool = &kernel_pool;
c00236dd:	bd a0 74 03 c0       	mov    $0xc00374a0,%ebp
c00236e2:	eb 05                	jmp    c00236e9 <palloc_free_multiple+0xc8>
    pool = &user_pool;
c00236e4:	bd 60 74 03 c0       	mov    $0xc0037460,%ebp
c00236e9:	8b 45 28             	mov    0x28(%ebp),%eax
c00236ec:	c1 e8 0c             	shr    $0xc,%eax
  page_idx = pg_no (pages) - pg_no (pool->base);
c00236ef:	29 c7                	sub    %eax,%edi
  memset (pages, 0xcc, PGSIZE * page_cnt);
c00236f1:	89 f0                	mov    %esi,%eax
c00236f3:	c1 e0 0c             	shl    $0xc,%eax
c00236f6:	89 44 24 08          	mov    %eax,0x8(%esp)
c00236fa:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c0023701:	00 
c0023702:	89 1c 24             	mov    %ebx,(%esp)
c0023705:	e8 17 47 00 00       	call   c0027e21 <memset>
  ASSERT (bitmap_all (pool->used_map, page_idx, page_cnt));
c002370a:	89 74 24 08          	mov    %esi,0x8(%esp)
c002370e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023712:	8b 45 24             	mov    0x24(%ebp),%eax
c0023715:	89 04 24             	mov    %eax,(%esp)
c0023718:	e8 bf 65 00 00       	call   c0029cdc <bitmap_all>
c002371d:	84 c0                	test   %al,%al
c002371f:	75 2c                	jne    c002374d <palloc_free_multiple+0x12c>
c0023721:	c7 44 24 10 94 ea 02 	movl   $0xc002ea94,0x10(%esp)
c0023728:	c0 
c0023729:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023730:	c0 
c0023731:	c7 44 24 08 36 d2 02 	movl   $0xc002d236,0x8(%esp)
c0023738:	c0 
c0023739:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c0023740:	00 
c0023741:	c7 04 24 c4 ea 02 c0 	movl   $0xc002eac4,(%esp)
c0023748:	e8 16 52 00 00       	call   c0028963 <debug_panic>
  bitmap_set_multiple (pool->used_map, page_idx, page_cnt, false);
c002374d:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023754:	00 
c0023755:	89 74 24 08          	mov    %esi,0x8(%esp)
c0023759:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002375d:	8b 45 24             	mov    0x24(%ebp),%eax
c0023760:	89 04 24             	mov    %eax,(%esp)
c0023763:	e8 55 61 00 00       	call   c00298bd <bitmap_set_multiple>
}
c0023768:	83 c4 2c             	add    $0x2c,%esp
c002376b:	5b                   	pop    %ebx
c002376c:	5e                   	pop    %esi
c002376d:	5f                   	pop    %edi
c002376e:	5d                   	pop    %ebp
c002376f:	c3                   	ret    

c0023770 <palloc_free_page>:
{
c0023770:	83 ec 1c             	sub    $0x1c,%esp
  palloc_free_multiple (page, 1);
c0023773:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c002377a:	00 
c002377b:	8b 44 24 20          	mov    0x20(%esp),%eax
c002377f:	89 04 24             	mov    %eax,(%esp)
c0023782:	e8 9a fe ff ff       	call   c0023621 <palloc_free_multiple>
}
c0023787:	83 c4 1c             	add    $0x1c,%esp
c002378a:	c3                   	ret    
c002378b:	90                   	nop
c002378c:	90                   	nop
c002378d:	90                   	nop
c002378e:	90                   	nop
c002378f:	90                   	nop

c0023790 <arena_to_block>:
}

/* Returns the (IDX - 1)'th block within arena A. */
static struct block *
arena_to_block (struct arena *a, size_t idx) 
{
c0023790:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (a != NULL);
c0023793:	85 c0                	test   %eax,%eax
c0023795:	75 2c                	jne    c00237c3 <arena_to_block+0x33>
c0023797:	c7 44 24 10 c5 e9 02 	movl   $0xc002e9c5,0x10(%esp)
c002379e:	c0 
c002379f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00237a6:	c0 
c00237a7:	c7 44 24 08 82 d2 02 	movl   $0xc002d282,0x8(%esp)
c00237ae:	c0 
c00237af:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c00237b6:	00 
c00237b7:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c00237be:	e8 a0 51 00 00       	call   c0028963 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c00237c3:	81 38 ed 8e 54 9a    	cmpl   $0x9a548eed,(%eax)
c00237c9:	74 2c                	je     c00237f7 <arena_to_block+0x67>
c00237cb:	c7 44 24 10 51 eb 02 	movl   $0xc002eb51,0x10(%esp)
c00237d2:	c0 
c00237d3:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00237da:	c0 
c00237db:	c7 44 24 08 82 d2 02 	movl   $0xc002d282,0x8(%esp)
c00237e2:	c0 
c00237e3:	c7 44 24 04 21 01 00 	movl   $0x121,0x4(%esp)
c00237ea:	00 
c00237eb:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c00237f2:	e8 6c 51 00 00       	call   c0028963 <debug_panic>
  ASSERT (idx < a->desc->blocks_per_arena);
c00237f7:	8b 48 04             	mov    0x4(%eax),%ecx
c00237fa:	39 51 04             	cmp    %edx,0x4(%ecx)
c00237fd:	77 2c                	ja     c002382b <arena_to_block+0x9b>
c00237ff:	c7 44 24 10 6c eb 02 	movl   $0xc002eb6c,0x10(%esp)
c0023806:	c0 
c0023807:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002380e:	c0 
c002380f:	c7 44 24 08 82 d2 02 	movl   $0xc002d282,0x8(%esp)
c0023816:	c0 
c0023817:	c7 44 24 04 22 01 00 	movl   $0x122,0x4(%esp)
c002381e:	00 
c002381f:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c0023826:	e8 38 51 00 00       	call   c0028963 <debug_panic>
  return (struct block *) ((uint8_t *) a
                           + sizeof *a
                           + idx * a->desc->block_size);
c002382b:	0f af 11             	imul   (%ecx),%edx
  return (struct block *) ((uint8_t *) a
c002382e:	8d 44 10 0c          	lea    0xc(%eax,%edx,1),%eax
}
c0023832:	83 c4 2c             	add    $0x2c,%esp
c0023835:	c3                   	ret    

c0023836 <block_to_arena>:
{
c0023836:	53                   	push   %ebx
c0023837:	83 ec 28             	sub    $0x28,%esp
  ASSERT (a != NULL);
c002383a:	89 c1                	mov    %eax,%ecx
c002383c:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
c0023842:	75 2c                	jne    c0023870 <block_to_arena+0x3a>
c0023844:	c7 44 24 10 c5 e9 02 	movl   $0xc002e9c5,0x10(%esp)
c002384b:	c0 
c002384c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023853:	c0 
c0023854:	c7 44 24 08 73 d2 02 	movl   $0xc002d273,0x8(%esp)
c002385b:	c0 
c002385c:	c7 44 24 04 11 01 00 	movl   $0x111,0x4(%esp)
c0023863:	00 
c0023864:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c002386b:	e8 f3 50 00 00       	call   c0028963 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c0023870:	81 39 ed 8e 54 9a    	cmpl   $0x9a548eed,(%ecx)
c0023876:	74 2c                	je     c00238a4 <block_to_arena+0x6e>
c0023878:	c7 44 24 10 51 eb 02 	movl   $0xc002eb51,0x10(%esp)
c002387f:	c0 
c0023880:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023887:	c0 
c0023888:	c7 44 24 08 73 d2 02 	movl   $0xc002d273,0x8(%esp)
c002388f:	c0 
c0023890:	c7 44 24 04 12 01 00 	movl   $0x112,0x4(%esp)
c0023897:	00 
c0023898:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c002389f:	e8 bf 50 00 00       	call   c0028963 <debug_panic>
  ASSERT (a->desc == NULL
c00238a4:	8b 59 04             	mov    0x4(%ecx),%ebx
c00238a7:	85 db                	test   %ebx,%ebx
c00238a9:	74 3f                	je     c00238ea <block_to_arena+0xb4>
  return (uintptr_t) va & PGMASK;
c00238ab:	25 ff 0f 00 00       	and    $0xfff,%eax
c00238b0:	8d 40 f4             	lea    -0xc(%eax),%eax
c00238b3:	ba 00 00 00 00       	mov    $0x0,%edx
c00238b8:	f7 33                	divl   (%ebx)
c00238ba:	85 d2                	test   %edx,%edx
c00238bc:	74 62                	je     c0023920 <block_to_arena+0xea>
c00238be:	c7 44 24 10 8c eb 02 	movl   $0xc002eb8c,0x10(%esp)
c00238c5:	c0 
c00238c6:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00238cd:	c0 
c00238ce:	c7 44 24 08 73 d2 02 	movl   $0xc002d273,0x8(%esp)
c00238d5:	c0 
c00238d6:	c7 44 24 04 16 01 00 	movl   $0x116,0x4(%esp)
c00238dd:	00 
c00238de:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c00238e5:	e8 79 50 00 00       	call   c0028963 <debug_panic>
c00238ea:	25 ff 0f 00 00       	and    $0xfff,%eax
  ASSERT (a->desc != NULL || pg_ofs (b) == sizeof *a);
c00238ef:	83 f8 0c             	cmp    $0xc,%eax
c00238f2:	74 2c                	je     c0023920 <block_to_arena+0xea>
c00238f4:	c7 44 24 10 d4 eb 02 	movl   $0xc002ebd4,0x10(%esp)
c00238fb:	c0 
c00238fc:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023903:	c0 
c0023904:	c7 44 24 08 73 d2 02 	movl   $0xc002d273,0x8(%esp)
c002390b:	c0 
c002390c:	c7 44 24 04 17 01 00 	movl   $0x117,0x4(%esp)
c0023913:	00 
c0023914:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c002391b:	e8 43 50 00 00       	call   c0028963 <debug_panic>
}
c0023920:	89 c8                	mov    %ecx,%eax
c0023922:	83 c4 28             	add    $0x28,%esp
c0023925:	5b                   	pop    %ebx
c0023926:	c3                   	ret    

c0023927 <malloc_init>:
{
c0023927:	57                   	push   %edi
c0023928:	56                   	push   %esi
c0023929:	53                   	push   %ebx
c002392a:	83 ec 20             	sub    $0x20,%esp
      struct desc *d = &descs[desc_cnt++];
c002392d:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c0023932:	8d 50 01             	lea    0x1(%eax),%edx
c0023935:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c002393b:	6b c0 3c             	imul   $0x3c,%eax,%eax
c002393e:	8d 98 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%ebx
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0023944:	83 fa 0a             	cmp    $0xa,%edx
c0023947:	76 7e                	jbe    c00239c7 <malloc_init+0xa0>
c0023949:	eb 1c                	jmp    c0023967 <malloc_init+0x40>
      struct desc *d = &descs[desc_cnt++];
c002394b:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c0023950:	8d 50 01             	lea    0x1(%eax),%edx
c0023953:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c0023959:	6b c0 3c             	imul   $0x3c,%eax,%eax
c002395c:	8d b0 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%esi
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0023962:	83 fa 0a             	cmp    $0xa,%edx
c0023965:	76 2c                	jbe    c0023993 <malloc_init+0x6c>
c0023967:	c7 44 24 10 00 ec 02 	movl   $0xc002ec00,0x10(%esp)
c002396e:	c0 
c002396f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023976:	c0 
c0023977:	c7 44 24 08 91 d2 02 	movl   $0xc002d291,0x8(%esp)
c002397e:	c0 
c002397f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c0023986:	00 
c0023987:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c002398e:	e8 d0 4f 00 00       	call   c0028963 <debug_panic>
      d->block_size = block_size;
c0023993:	89 98 00 75 03 c0    	mov    %ebx,-0x3ffc8b00(%eax)
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0023999:	89 f8                	mov    %edi,%eax
c002399b:	ba 00 00 00 00       	mov    $0x0,%edx
c00239a0:	f7 f3                	div    %ebx
c00239a2:	89 46 04             	mov    %eax,0x4(%esi)
      list_init (&d->free_list);
c00239a5:	8d 46 08             	lea    0x8(%esi),%eax
c00239a8:	89 04 24             	mov    %eax,(%esp)
c00239ab:	e8 80 50 00 00       	call   c0028a30 <list_init>
      lock_init (&d->lock);
c00239b0:	83 c6 18             	add    $0x18,%esi
c00239b3:	89 34 24             	mov    %esi,(%esp)
c00239b6:	e8 e2 f3 ff ff       	call   c0022d9d <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c00239bb:	01 db                	add    %ebx,%ebx
c00239bd:	81 fb ff 07 00 00    	cmp    $0x7ff,%ebx
c00239c3:	76 86                	jbe    c002394b <malloc_init+0x24>
c00239c5:	eb 36                	jmp    c00239fd <malloc_init+0xd6>
      d->block_size = block_size;
c00239c7:	c7 80 00 75 03 c0 10 	movl   $0x10,-0x3ffc8b00(%eax)
c00239ce:	00 00 00 
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c00239d1:	c7 43 04 ff 00 00 00 	movl   $0xff,0x4(%ebx)
      list_init (&d->free_list);
c00239d8:	8d 43 08             	lea    0x8(%ebx),%eax
c00239db:	89 04 24             	mov    %eax,(%esp)
c00239de:	e8 4d 50 00 00       	call   c0028a30 <list_init>
      lock_init (&d->lock);
c00239e3:	83 c3 18             	add    $0x18,%ebx
c00239e6:	89 1c 24             	mov    %ebx,(%esp)
c00239e9:	e8 af f3 ff ff       	call   c0022d9d <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c00239ee:	bb 20 00 00 00       	mov    $0x20,%ebx
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c00239f3:	bf f4 0f 00 00       	mov    $0xff4,%edi
c00239f8:	e9 4e ff ff ff       	jmp    c002394b <malloc_init+0x24>
}
c00239fd:	83 c4 20             	add    $0x20,%esp
c0023a00:	5b                   	pop    %ebx
c0023a01:	5e                   	pop    %esi
c0023a02:	5f                   	pop    %edi
c0023a03:	c3                   	ret    

c0023a04 <malloc>:
{
c0023a04:	55                   	push   %ebp
c0023a05:	57                   	push   %edi
c0023a06:	56                   	push   %esi
c0023a07:	53                   	push   %ebx
c0023a08:	83 ec 1c             	sub    $0x1c,%esp
c0023a0b:	8b 54 24 30          	mov    0x30(%esp),%edx
  if (size == 0)
c0023a0f:	85 d2                	test   %edx,%edx
c0023a11:	0f 84 15 01 00 00    	je     c0023b2c <malloc+0x128>
  for (d = descs; d < descs + desc_cnt; d++)
c0023a17:	6b 05 e0 74 03 c0 3c 	imul   $0x3c,0xc00374e0,%eax
c0023a1e:	05 00 75 03 c0       	add    $0xc0037500,%eax
c0023a23:	3d 00 75 03 c0       	cmp    $0xc0037500,%eax
c0023a28:	76 1c                	jbe    c0023a46 <malloc+0x42>
    if (d->block_size >= size)
c0023a2a:	3b 15 00 75 03 c0    	cmp    0xc0037500,%edx
c0023a30:	76 1b                	jbe    c0023a4d <malloc+0x49>
c0023a32:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c0023a37:	eb 04                	jmp    c0023a3d <malloc+0x39>
c0023a39:	3b 13                	cmp    (%ebx),%edx
c0023a3b:	76 15                	jbe    c0023a52 <malloc+0x4e>
  for (d = descs; d < descs + desc_cnt; d++)
c0023a3d:	83 c3 3c             	add    $0x3c,%ebx
c0023a40:	39 c3                	cmp    %eax,%ebx
c0023a42:	72 f5                	jb     c0023a39 <malloc+0x35>
c0023a44:	eb 0c                	jmp    c0023a52 <malloc+0x4e>
c0023a46:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c0023a4b:	eb 05                	jmp    c0023a52 <malloc+0x4e>
    if (d->block_size >= size)
c0023a4d:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
  if (d == descs + desc_cnt) 
c0023a52:	39 d8                	cmp    %ebx,%eax
c0023a54:	75 39                	jne    c0023a8f <malloc+0x8b>
      size_t page_cnt = DIV_ROUND_UP (size + sizeof *a, PGSIZE);
c0023a56:	8d 9a 0b 10 00 00    	lea    0x100b(%edx),%ebx
c0023a5c:	c1 eb 0c             	shr    $0xc,%ebx
      a = palloc_get_multiple (0, page_cnt);
c0023a5f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023a63:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0023a6a:	e8 cb fa ff ff       	call   c002353a <palloc_get_multiple>
      if (a == NULL)
c0023a6f:	85 c0                	test   %eax,%eax
c0023a71:	0f 84 bc 00 00 00    	je     c0023b33 <malloc+0x12f>
      a->magic = ARENA_MAGIC;
c0023a77:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = NULL;
c0023a7d:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
      a->free_cnt = page_cnt;
c0023a84:	89 58 08             	mov    %ebx,0x8(%eax)
      return a + 1;
c0023a87:	83 c0 0c             	add    $0xc,%eax
c0023a8a:	e9 a9 00 00 00       	jmp    c0023b38 <malloc+0x134>
  lock_acquire (&d->lock);
c0023a8f:	8d 43 18             	lea    0x18(%ebx),%eax
c0023a92:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0023a96:	89 04 24             	mov    %eax,(%esp)
c0023a99:	e8 9c f3 ff ff       	call   c0022e3a <lock_acquire>
  if (list_empty (&d->free_list))
c0023a9e:	8d 7b 08             	lea    0x8(%ebx),%edi
c0023aa1:	89 3c 24             	mov    %edi,(%esp)
c0023aa4:	e8 bd 55 00 00       	call   c0029066 <list_empty>
c0023aa9:	84 c0                	test   %al,%al
c0023aab:	74 5c                	je     c0023b09 <malloc+0x105>
      a = palloc_get_page (0);
c0023aad:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0023ab4:	e8 4d fb ff ff       	call   c0023606 <palloc_get_page>
c0023ab9:	89 c5                	mov    %eax,%ebp
      if (a == NULL) 
c0023abb:	85 c0                	test   %eax,%eax
c0023abd:	75 13                	jne    c0023ad2 <malloc+0xce>
          lock_release (&d->lock);
c0023abf:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0023ac3:	89 04 24             	mov    %eax,(%esp)
c0023ac6:	e8 39 f5 ff ff       	call   c0023004 <lock_release>
          return NULL; 
c0023acb:	b8 00 00 00 00       	mov    $0x0,%eax
c0023ad0:	eb 66                	jmp    c0023b38 <malloc+0x134>
      a->magic = ARENA_MAGIC;
c0023ad2:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = d;
c0023ad8:	89 58 04             	mov    %ebx,0x4(%eax)
      a->free_cnt = d->blocks_per_arena;
c0023adb:	8b 43 04             	mov    0x4(%ebx),%eax
c0023ade:	89 45 08             	mov    %eax,0x8(%ebp)
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023ae1:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0023ae5:	74 22                	je     c0023b09 <malloc+0x105>
c0023ae7:	be 00 00 00 00       	mov    $0x0,%esi
          struct block *b = arena_to_block (a, i);
c0023aec:	89 f2                	mov    %esi,%edx
c0023aee:	89 e8                	mov    %ebp,%eax
c0023af0:	e8 9b fc ff ff       	call   c0023790 <arena_to_block>
          list_push_back (&d->free_list, &b->free_elem);
c0023af5:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023af9:	89 3c 24             	mov    %edi,(%esp)
c0023afc:	e8 b0 54 00 00       	call   c0028fb1 <list_push_back>
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023b01:	83 c6 01             	add    $0x1,%esi
c0023b04:	39 73 04             	cmp    %esi,0x4(%ebx)
c0023b07:	77 e3                	ja     c0023aec <malloc+0xe8>
  b = list_entry (list_pop_front (&d->free_list), struct block, free_elem);
c0023b09:	89 3c 24             	mov    %edi,(%esp)
c0023b0c:	e8 c3 55 00 00       	call   c00290d4 <list_pop_front>
c0023b11:	89 c3                	mov    %eax,%ebx
  a = block_to_arena (b);
c0023b13:	e8 1e fd ff ff       	call   c0023836 <block_to_arena>
  a->free_cnt--;
c0023b18:	83 68 08 01          	subl   $0x1,0x8(%eax)
  lock_release (&d->lock);
c0023b1c:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0023b20:	89 04 24             	mov    %eax,(%esp)
c0023b23:	e8 dc f4 ff ff       	call   c0023004 <lock_release>
  return b;
c0023b28:	89 d8                	mov    %ebx,%eax
c0023b2a:	eb 0c                	jmp    c0023b38 <malloc+0x134>
    return NULL;
c0023b2c:	b8 00 00 00 00       	mov    $0x0,%eax
c0023b31:	eb 05                	jmp    c0023b38 <malloc+0x134>
        return NULL;
c0023b33:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023b38:	83 c4 1c             	add    $0x1c,%esp
c0023b3b:	5b                   	pop    %ebx
c0023b3c:	5e                   	pop    %esi
c0023b3d:	5f                   	pop    %edi
c0023b3e:	5d                   	pop    %ebp
c0023b3f:	c3                   	ret    

c0023b40 <calloc>:
{
c0023b40:	56                   	push   %esi
c0023b41:	53                   	push   %ebx
c0023b42:	83 ec 14             	sub    $0x14,%esp
c0023b45:	8b 54 24 20          	mov    0x20(%esp),%edx
c0023b49:	8b 44 24 24          	mov    0x24(%esp),%eax
  size = a * b;
c0023b4d:	89 d3                	mov    %edx,%ebx
c0023b4f:	0f af d8             	imul   %eax,%ebx
  if (size < a || size < b)
c0023b52:	39 c3                	cmp    %eax,%ebx
c0023b54:	72 2a                	jb     c0023b80 <calloc+0x40>
c0023b56:	39 d3                	cmp    %edx,%ebx
c0023b58:	72 26                	jb     c0023b80 <calloc+0x40>
  p = malloc (size);
c0023b5a:	89 1c 24             	mov    %ebx,(%esp)
c0023b5d:	e8 a2 fe ff ff       	call   c0023a04 <malloc>
c0023b62:	89 c6                	mov    %eax,%esi
  if (p != NULL)
c0023b64:	85 f6                	test   %esi,%esi
c0023b66:	74 1d                	je     c0023b85 <calloc+0x45>
    memset (p, 0, size);
c0023b68:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023b6c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023b73:	00 
c0023b74:	89 34 24             	mov    %esi,(%esp)
c0023b77:	e8 a5 42 00 00       	call   c0027e21 <memset>
  return p;
c0023b7c:	89 f0                	mov    %esi,%eax
c0023b7e:	eb 05                	jmp    c0023b85 <calloc+0x45>
    return NULL;
c0023b80:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023b85:	83 c4 14             	add    $0x14,%esp
c0023b88:	5b                   	pop    %ebx
c0023b89:	5e                   	pop    %esi
c0023b8a:	c3                   	ret    

c0023b8b <free>:
{
c0023b8b:	55                   	push   %ebp
c0023b8c:	57                   	push   %edi
c0023b8d:	56                   	push   %esi
c0023b8e:	53                   	push   %ebx
c0023b8f:	83 ec 2c             	sub    $0x2c,%esp
c0023b92:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  if (p != NULL)
c0023b96:	85 db                	test   %ebx,%ebx
c0023b98:	0f 84 ca 00 00 00    	je     c0023c68 <free+0xdd>
      struct arena *a = block_to_arena (b);
c0023b9e:	89 d8                	mov    %ebx,%eax
c0023ba0:	e8 91 fc ff ff       	call   c0023836 <block_to_arena>
c0023ba5:	89 c7                	mov    %eax,%edi
      struct desc *d = a->desc;
c0023ba7:	8b 70 04             	mov    0x4(%eax),%esi
      if (d != NULL) 
c0023baa:	85 f6                	test   %esi,%esi
c0023bac:	0f 84 a7 00 00 00    	je     c0023c59 <free+0xce>
          memset (b, 0xcc, d->block_size);
c0023bb2:	8b 06                	mov    (%esi),%eax
c0023bb4:	89 44 24 08          	mov    %eax,0x8(%esp)
c0023bb8:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c0023bbf:	00 
c0023bc0:	89 1c 24             	mov    %ebx,(%esp)
c0023bc3:	e8 59 42 00 00       	call   c0027e21 <memset>
          lock_acquire (&d->lock);
c0023bc8:	8d 6e 18             	lea    0x18(%esi),%ebp
c0023bcb:	89 2c 24             	mov    %ebp,(%esp)
c0023bce:	e8 67 f2 ff ff       	call   c0022e3a <lock_acquire>
          list_push_front (&d->free_list, &b->free_elem);
c0023bd3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023bd7:	8d 46 08             	lea    0x8(%esi),%eax
c0023bda:	89 04 24             	mov    %eax,(%esp)
c0023bdd:	e8 ac 53 00 00       	call   c0028f8e <list_push_front>
          if (++a->free_cnt >= d->blocks_per_arena) 
c0023be2:	8b 47 08             	mov    0x8(%edi),%eax
c0023be5:	83 c0 01             	add    $0x1,%eax
c0023be8:	89 47 08             	mov    %eax,0x8(%edi)
c0023beb:	8b 56 04             	mov    0x4(%esi),%edx
c0023bee:	39 d0                	cmp    %edx,%eax
c0023bf0:	72 5d                	jb     c0023c4f <free+0xc4>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023bf2:	39 d0                	cmp    %edx,%eax
c0023bf4:	75 0c                	jne    c0023c02 <free+0x77>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023bf6:	bb 00 00 00 00       	mov    $0x0,%ebx
c0023bfb:	85 c0                	test   %eax,%eax
c0023bfd:	75 2f                	jne    c0023c2e <free+0xa3>
c0023bff:	90                   	nop
c0023c00:	eb 45                	jmp    c0023c47 <free+0xbc>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023c02:	c7 44 24 10 2c ec 02 	movl   $0xc002ec2c,0x10(%esp)
c0023c09:	c0 
c0023c0a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023c11:	c0 
c0023c12:	c7 44 24 08 6e d2 02 	movl   $0xc002d26e,0x8(%esp)
c0023c19:	c0 
c0023c1a:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0023c21:	00 
c0023c22:	c7 04 24 3a eb 02 c0 	movl   $0xc002eb3a,(%esp)
c0023c29:	e8 35 4d 00 00       	call   c0028963 <debug_panic>
                  struct block *b = arena_to_block (a, i);
c0023c2e:	89 da                	mov    %ebx,%edx
c0023c30:	89 f8                	mov    %edi,%eax
c0023c32:	e8 59 fb ff ff       	call   c0023790 <arena_to_block>
                  list_remove (&b->free_elem);
c0023c37:	89 04 24             	mov    %eax,(%esp)
c0023c3a:	e8 95 53 00 00       	call   c0028fd4 <list_remove>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023c3f:	83 c3 01             	add    $0x1,%ebx
c0023c42:	39 5e 04             	cmp    %ebx,0x4(%esi)
c0023c45:	77 e7                	ja     c0023c2e <free+0xa3>
              palloc_free_page (a);
c0023c47:	89 3c 24             	mov    %edi,(%esp)
c0023c4a:	e8 21 fb ff ff       	call   c0023770 <palloc_free_page>
          lock_release (&d->lock);
c0023c4f:	89 2c 24             	mov    %ebp,(%esp)
c0023c52:	e8 ad f3 ff ff       	call   c0023004 <lock_release>
c0023c57:	eb 0f                	jmp    c0023c68 <free+0xdd>
          palloc_free_multiple (a, a->free_cnt);
c0023c59:	8b 40 08             	mov    0x8(%eax),%eax
c0023c5c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023c60:	89 3c 24             	mov    %edi,(%esp)
c0023c63:	e8 b9 f9 ff ff       	call   c0023621 <palloc_free_multiple>
}
c0023c68:	83 c4 2c             	add    $0x2c,%esp
c0023c6b:	5b                   	pop    %ebx
c0023c6c:	5e                   	pop    %esi
c0023c6d:	5f                   	pop    %edi
c0023c6e:	5d                   	pop    %ebp
c0023c6f:	c3                   	ret    

c0023c70 <realloc>:
{
c0023c70:	57                   	push   %edi
c0023c71:	56                   	push   %esi
c0023c72:	53                   	push   %ebx
c0023c73:	83 ec 10             	sub    $0x10,%esp
c0023c76:	8b 7c 24 20          	mov    0x20(%esp),%edi
c0023c7a:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (new_size == 0) 
c0023c7e:	85 db                	test   %ebx,%ebx
c0023c80:	75 0f                	jne    c0023c91 <realloc+0x21>
      free (old_block);
c0023c82:	89 3c 24             	mov    %edi,(%esp)
c0023c85:	e8 01 ff ff ff       	call   c0023b8b <free>
      return NULL;
c0023c8a:	b8 00 00 00 00       	mov    $0x0,%eax
c0023c8f:	eb 57                	jmp    c0023ce8 <realloc+0x78>
      void *new_block = malloc (new_size);
c0023c91:	89 1c 24             	mov    %ebx,(%esp)
c0023c94:	e8 6b fd ff ff       	call   c0023a04 <malloc>
c0023c99:	89 c6                	mov    %eax,%esi
      if (old_block != NULL && new_block != NULL)
c0023c9b:	85 c0                	test   %eax,%eax
c0023c9d:	74 47                	je     c0023ce6 <realloc+0x76>
c0023c9f:	85 ff                	test   %edi,%edi
c0023ca1:	74 43                	je     c0023ce6 <realloc+0x76>
  struct arena *a = block_to_arena (b);
c0023ca3:	89 f8                	mov    %edi,%eax
c0023ca5:	e8 8c fb ff ff       	call   c0023836 <block_to_arena>
  struct desc *d = a->desc;
c0023caa:	8b 50 04             	mov    0x4(%eax),%edx
  return d != NULL ? d->block_size : PGSIZE * a->free_cnt - pg_ofs (block);
c0023cad:	85 d2                	test   %edx,%edx
c0023caf:	74 04                	je     c0023cb5 <realloc+0x45>
c0023cb1:	8b 02                	mov    (%edx),%eax
c0023cb3:	eb 10                	jmp    c0023cc5 <realloc+0x55>
c0023cb5:	8b 40 08             	mov    0x8(%eax),%eax
c0023cb8:	c1 e0 0c             	shl    $0xc,%eax
c0023cbb:	89 fa                	mov    %edi,%edx
c0023cbd:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
c0023cc3:	29 d0                	sub    %edx,%eax
          size_t min_size = new_size < old_size ? new_size : old_size;
c0023cc5:	39 d8                	cmp    %ebx,%eax
c0023cc7:	0f 46 d8             	cmovbe %eax,%ebx
          memcpy (new_block, old_block, min_size);
c0023cca:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023cce:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023cd2:	89 34 24             	mov    %esi,(%esp)
c0023cd5:	e8 66 3b 00 00       	call   c0027840 <memcpy>
          free (old_block);
c0023cda:	89 3c 24             	mov    %edi,(%esp)
c0023cdd:	e8 a9 fe ff ff       	call   c0023b8b <free>
      return new_block;
c0023ce2:	89 f0                	mov    %esi,%eax
c0023ce4:	eb 02                	jmp    c0023ce8 <realloc+0x78>
c0023ce6:	89 f0                	mov    %esi,%eax
}
c0023ce8:	83 c4 10             	add    $0x10,%esp
c0023ceb:	5b                   	pop    %ebx
c0023cec:	5e                   	pop    %esi
c0023ced:	5f                   	pop    %edi
c0023cee:	c3                   	ret    

c0023cef <pit_configure_channel>:
     - Other modes are less useful.

   FREQUENCY is the number of periods per second, in Hz. */
void
pit_configure_channel (int channel, int mode, int frequency)
{
c0023cef:	57                   	push   %edi
c0023cf0:	56                   	push   %esi
c0023cf1:	53                   	push   %ebx
c0023cf2:	83 ec 20             	sub    $0x20,%esp
c0023cf5:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0023cf9:	8b 7c 24 34          	mov    0x34(%esp),%edi
c0023cfd:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  uint16_t count;
  enum intr_level old_level;

  ASSERT (channel == 0 || channel == 2);
c0023d01:	f7 c3 fd ff ff ff    	test   $0xfffffffd,%ebx
c0023d07:	74 2c                	je     c0023d35 <pit_configure_channel+0x46>
c0023d09:	c7 44 24 10 4f ec 02 	movl   $0xc002ec4f,0x10(%esp)
c0023d10:	c0 
c0023d11:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023d18:	c0 
c0023d19:	c7 44 24 08 9d d2 02 	movl   $0xc002d29d,0x8(%esp)
c0023d20:	c0 
c0023d21:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
c0023d28:	00 
c0023d29:	c7 04 24 6c ec 02 c0 	movl   $0xc002ec6c,(%esp)
c0023d30:	e8 2e 4c 00 00       	call   c0028963 <debug_panic>
  ASSERT (mode == 2 || mode == 3);
c0023d35:	8d 47 fe             	lea    -0x2(%edi),%eax
c0023d38:	83 f8 01             	cmp    $0x1,%eax
c0023d3b:	76 2c                	jbe    c0023d69 <pit_configure_channel+0x7a>
c0023d3d:	c7 44 24 10 80 ec 02 	movl   $0xc002ec80,0x10(%esp)
c0023d44:	c0 
c0023d45:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023d4c:	c0 
c0023d4d:	c7 44 24 08 9d d2 02 	movl   $0xc002d29d,0x8(%esp)
c0023d54:	c0 
c0023d55:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c0023d5c:	00 
c0023d5d:	c7 04 24 6c ec 02 c0 	movl   $0xc002ec6c,(%esp)
c0023d64:	e8 fa 4b 00 00       	call   c0028963 <debug_panic>
    {
      /* Frequency is too low: the quotient would overflow the
         16-bit counter.  Force it to 0, which the PIT treats as
         65536, the highest possible count.  This yields a 18.2
         Hz timer, approximately. */
      count = 0;
c0023d69:	be 00 00 00 00       	mov    $0x0,%esi
  if (frequency < 19)
c0023d6e:	83 f9 12             	cmp    $0x12,%ecx
c0023d71:	7e 20                	jle    c0023d93 <pit_configure_channel+0xa4>
      /* Frequency is too high: the quotient would underflow to
         0, which the PIT would interpret as 65536.  A count of 1
         is illegal in mode 2, so we force it to 2, which yields
         a 596.590 kHz timer, approximately.  (This timer rate is
         probably too fast to be useful anyhow.) */
      count = 2;
c0023d73:	be 02 00 00 00       	mov    $0x2,%esi
  else if (frequency > PIT_HZ)
c0023d78:	81 f9 dc 34 12 00    	cmp    $0x1234dc,%ecx
c0023d7e:	7f 13                	jg     c0023d93 <pit_configure_channel+0xa4>
    }
  else
    count = (PIT_HZ + frequency / 2) / frequency;
c0023d80:	89 c8                	mov    %ecx,%eax
c0023d82:	c1 e8 1f             	shr    $0x1f,%eax
c0023d85:	01 c8                	add    %ecx,%eax
c0023d87:	d1 f8                	sar    %eax
c0023d89:	05 dc 34 12 00       	add    $0x1234dc,%eax
c0023d8e:	99                   	cltd   
c0023d8f:	f7 f9                	idiv   %ecx
c0023d91:	89 c6                	mov    %eax,%esi

  /* Configure the PIT mode and load its counters. */
  old_level = intr_disable ();
c0023d93:	e8 07 dc ff ff       	call   c002199f <intr_disable>
c0023d98:	89 c1                	mov    %eax,%ecx
  outb (PIT_PORT_CONTROL, (channel << 6) | 0x30 | (mode << 1));
c0023d9a:	8d 04 3f             	lea    (%edi,%edi,1),%eax
c0023d9d:	83 c8 30             	or     $0x30,%eax
c0023da0:	89 da                	mov    %ebx,%edx
c0023da2:	c1 e2 06             	shl    $0x6,%edx
c0023da5:	09 d0                	or     %edx,%eax
c0023da7:	e6 43                	out    %al,$0x43
  outb (PIT_PORT_COUNTER (channel), count);
c0023da9:	8d 53 40             	lea    0x40(%ebx),%edx
c0023dac:	89 f0                	mov    %esi,%eax
c0023dae:	ee                   	out    %al,(%dx)
  outb (PIT_PORT_COUNTER (channel), count >> 8);
c0023daf:	89 f0                	mov    %esi,%eax
c0023db1:	66 c1 e8 08          	shr    $0x8,%ax
c0023db5:	ee                   	out    %al,(%dx)
  intr_set_level (old_level);
c0023db6:	89 0c 24             	mov    %ecx,(%esp)
c0023db9:	e8 e8 db ff ff       	call   c00219a6 <intr_set_level>
}
c0023dbe:	83 c4 20             	add    $0x20,%esp
c0023dc1:	5b                   	pop    %ebx
c0023dc2:	5e                   	pop    %esi
c0023dc3:	5f                   	pop    %edi
c0023dc4:	c3                   	ret    
c0023dc5:	90                   	nop
c0023dc6:	90                   	nop
c0023dc7:	90                   	nop
c0023dc8:	90                   	nop
c0023dc9:	90                   	nop
c0023dca:	90                   	nop
c0023dcb:	90                   	nop
c0023dcc:	90                   	nop
c0023dcd:	90                   	nop
c0023dce:	90                   	nop
c0023dcf:	90                   	nop

c0023dd0 <compareSleep>:
        return true;
    }
    //then check if the wakeup times are equal
    else if (tPointer1->wakeup == tPointer1->wakeup) {
        //if they are, then comapare using priority
        if (tPointer1->priority > tPointer2->priority) {
c0023dd0:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023dd4:	8b 54 24 04          	mov    0x4(%esp),%edx
c0023dd8:	8b 40 f4             	mov    -0xc(%eax),%eax
c0023ddb:	39 42 f4             	cmp    %eax,-0xc(%edx)
c0023dde:	0f 9f c0             	setg   %al
        }
    }
    //if all tests fail, return false
    return false;

}
c0023de1:	c3                   	ret    

c0023de2 <busy_wait>:
   affect timings, so that if this function was inlined
   differently in different places the results would be difficult
   to predict. */
static void NO_INLINE
busy_wait (int64_t loops) 
{
c0023de2:	53                   	push   %ebx
  while (loops-- > 0)
c0023de3:	89 c1                	mov    %eax,%ecx
c0023de5:	89 d3                	mov    %edx,%ebx
c0023de7:	83 c1 ff             	add    $0xffffffff,%ecx
c0023dea:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023ded:	85 d2                	test   %edx,%edx
c0023def:	78 18                	js     c0023e09 <busy_wait+0x27>
c0023df1:	85 d2                	test   %edx,%edx
c0023df3:	7f 05                	jg     c0023dfa <busy_wait+0x18>
c0023df5:	83 f8 00             	cmp    $0x0,%eax
c0023df8:	76 0f                	jbe    c0023e09 <busy_wait+0x27>
c0023dfa:	83 c1 ff             	add    $0xffffffff,%ecx
c0023dfd:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023e00:	89 c8                	mov    %ecx,%eax
c0023e02:	21 d8                	and    %ebx,%eax
c0023e04:	83 f8 ff             	cmp    $0xffffffff,%eax
c0023e07:	75 f1                	jne    c0023dfa <busy_wait+0x18>
    barrier ();
}
c0023e09:	5b                   	pop    %ebx
c0023e0a:	c3                   	ret    

c0023e0b <too_many_loops>:
{
c0023e0b:	55                   	push   %ebp
c0023e0c:	57                   	push   %edi
c0023e0d:	56                   	push   %esi
c0023e0e:	53                   	push   %ebx
c0023e0f:	83 ec 04             	sub    $0x4,%esp
  int64_t start = ticks;
c0023e12:	8b 2d 70 77 03 c0    	mov    0xc0037770,%ebp
c0023e18:	8b 3d 74 77 03 c0    	mov    0xc0037774,%edi
  while (ticks == start)
c0023e1e:	8b 35 70 77 03 c0    	mov    0xc0037770,%esi
c0023e24:	8b 1d 74 77 03 c0    	mov    0xc0037774,%ebx
c0023e2a:	89 d9                	mov    %ebx,%ecx
c0023e2c:	31 f9                	xor    %edi,%ecx
c0023e2e:	89 f2                	mov    %esi,%edx
c0023e30:	31 ea                	xor    %ebp,%edx
c0023e32:	09 d1                	or     %edx,%ecx
c0023e34:	74 e8                	je     c0023e1e <too_many_loops+0x13>
  busy_wait (loops);
c0023e36:	ba 00 00 00 00       	mov    $0x0,%edx
c0023e3b:	e8 a2 ff ff ff       	call   c0023de2 <busy_wait>
  return start != ticks;
c0023e40:	33 35 70 77 03 c0    	xor    0xc0037770,%esi
c0023e46:	33 1d 74 77 03 c0    	xor    0xc0037774,%ebx
c0023e4c:	09 de                	or     %ebx,%esi
c0023e4e:	0f 95 c0             	setne  %al
}
c0023e51:	83 c4 04             	add    $0x4,%esp
c0023e54:	5b                   	pop    %ebx
c0023e55:	5e                   	pop    %esi
c0023e56:	5f                   	pop    %edi
c0023e57:	5d                   	pop    %ebp
c0023e58:	c3                   	ret    

c0023e59 <timer_interrupt>:
{
c0023e59:	56                   	push   %esi
c0023e5a:	53                   	push   %ebx
c0023e5b:	83 ec 14             	sub    $0x14,%esp
  ticks++;
c0023e5e:	83 05 70 77 03 c0 01 	addl   $0x1,0xc0037770
c0023e65:	83 15 74 77 03 c0 00 	adcl   $0x0,0xc0037774
  struct list_elem *e = list_begin(&sleep_list);
c0023e6c:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023e73:	e8 09 4c 00 00       	call   c0028a81 <list_begin>
c0023e78:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023e7a:	eb 39                	jmp    c0023eb5 <timer_interrupt+0x5c>
      if(ticks >= t->wakeup)
c0023e7c:	8b 53 0c             	mov    0xc(%ebx),%edx
c0023e7f:	8b 43 10             	mov    0x10(%ebx),%eax
c0023e82:	3b 05 74 77 03 c0    	cmp    0xc0037774,%eax
c0023e88:	7f 21                	jg     c0023eab <timer_interrupt+0x52>
c0023e8a:	7c 08                	jl     c0023e94 <timer_interrupt+0x3b>
c0023e8c:	3b 15 70 77 03 c0    	cmp    0xc0037770,%edx
c0023e92:	77 17                	ja     c0023eab <timer_interrupt+0x52>
          e = list_remove(&t->elem);
c0023e94:	8d 73 d8             	lea    -0x28(%ebx),%esi
c0023e97:	89 1c 24             	mov    %ebx,(%esp)
c0023e9a:	e8 35 51 00 00       	call   c0028fd4 <list_remove>
c0023e9f:	89 c3                	mov    %eax,%ebx
          thread_unblock(t);
c0023ea1:	89 34 24             	mov    %esi,(%esp)
c0023ea4:	e8 55 ce ff ff       	call   c0020cfe <thread_unblock>
c0023ea9:	eb 0a                	jmp    c0023eb5 <timer_interrupt+0x5c>
          e = list_next(e);
c0023eab:	89 1c 24             	mov    %ebx,(%esp)
c0023eae:	e8 0c 4c 00 00       	call   c0028abf <list_next>
c0023eb3:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023eb5:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023ebc:	e8 52 4c 00 00       	call   c0028b13 <list_end>
c0023ec1:	39 d8                	cmp    %ebx,%eax
c0023ec3:	75 b7                	jne    c0023e7c <timer_interrupt+0x23>
  if(thread_mlfqs)
c0023ec5:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c0023ecc:	0f 84 d7 00 00 00    	je     c0023fa9 <timer_interrupt+0x150>
    if(thread_current() != get_idle_thread())
c0023ed2:	e8 02 cf ff ff       	call   c0020dd9 <thread_current>
c0023ed7:	89 c3                	mov    %eax,%ebx
c0023ed9:	e8 1f d2 ff ff       	call   c00210fd <get_idle_thread>
c0023ede:	39 c3                	cmp    %eax,%ebx
c0023ee0:	74 22                	je     c0023f04 <timer_interrupt+0xab>
      thread_current()->recent_cpu = add_fixed_and_integer(thread_current()->recent_cpu,1);
c0023ee2:	e8 f2 ce ff ff       	call   c0020dd9 <thread_current>
c0023ee7:	89 c3                	mov    %eax,%ebx
c0023ee9:	e8 eb ce ff ff       	call   c0020dd9 <thread_current>
c0023eee:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023ef5:	00 
c0023ef6:	8b 40 58             	mov    0x58(%eax),%eax
c0023ef9:	89 04 24             	mov    %eax,(%esp)
c0023efc:	e8 f1 cb ff ff       	call   c0020af2 <add_fixed_and_integer>
c0023f01:	89 43 58             	mov    %eax,0x58(%ebx)
    if(ticks % TIMER_FREQ == 0)
c0023f04:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0023f0b:	00 
c0023f0c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023f13:	00 
c0023f14:	a1 70 77 03 c0       	mov    0xc0037770,%eax
c0023f19:	8b 15 74 77 03 c0    	mov    0xc0037774,%edx
c0023f1f:	89 04 24             	mov    %eax,(%esp)
c0023f22:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023f26:	e8 bb 43 00 00       	call   c00282e6 <__moddi3>
c0023f2b:	09 c2                	or     %eax,%edx
c0023f2d:	75 58                	jne    c0023f87 <timer_interrupt+0x12e>
       i = multiply_fixed_point(constant1,get_system_load_avg());
c0023f2f:	e8 b9 d1 ff ff       	call   c00210ed <get_system_load_avg>
c0023f34:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023f38:	a1 cc 7b 03 c0       	mov    0xc0037bcc,%eax
c0023f3d:	89 04 24             	mov    %eax,(%esp)
c0023f40:	e8 d1 cb ff ff       	call   c0020b16 <multiply_fixed_point>
c0023f45:	a3 c8 7b 03 c0       	mov    %eax,0xc0037bc8
       j = multiply_fixed_and_integer(constant2,get_ready_threads());
c0023f4a:	e8 5a d1 ff ff       	call   c00210a9 <get_ready_threads>
c0023f4f:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023f53:	a1 c4 7b 03 c0       	mov    0xc0037bc4,%eax
c0023f58:	89 04 24             	mov    %eax,(%esp)
c0023f5b:	e8 04 cc ff ff       	call   c0020b64 <multiply_fixed_and_integer>
c0023f60:	a3 c0 7b 03 c0       	mov    %eax,0xc0037bc0
       set_system_load_avg(i + j);
c0023f65:	03 05 c8 7b 03 c0    	add    0xc0037bc8,%eax
c0023f6b:	89 04 24             	mov    %eax,(%esp)
c0023f6e:	e8 80 d1 ff ff       	call   c00210f3 <set_system_load_avg>
       thread_foreach (calculate_recent_cpu, 0);
c0023f73:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023f7a:	00 
c0023f7b:	c7 04 24 86 0f 02 c0 	movl   $0xc0020f86,(%esp)
c0023f82:	e8 33 cf ff ff       	call   c0020eba <thread_foreach>
    if(ticks % 4 == 0)
c0023f87:	f6 05 70 77 03 c0 03 	testb  $0x3,0xc0037770
c0023f8e:	75 19                	jne    c0023fa9 <timer_interrupt+0x150>
      thread_foreach (calculate_priority, 0);
c0023f90:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023f97:	00 
c0023f98:	c7 04 24 27 10 02 c0 	movl   $0xc0021027,(%esp)
c0023f9f:	e8 16 cf ff ff       	call   c0020eba <thread_foreach>
      intr_yield_on_return ();
c0023fa4:	e8 60 dc ff ff       	call   c0021c09 <intr_yield_on_return>
  thread_tick ();
c0023fa9:	e8 a6 ce ff ff       	call   c0020e54 <thread_tick>
}
c0023fae:	83 c4 14             	add    $0x14,%esp
c0023fb1:	5b                   	pop    %ebx
c0023fb2:	5e                   	pop    %esi
c0023fb3:	c3                   	ret    

c0023fb4 <real_time_delay>:
}

/* Busy-wait for approximately NUM/DENOM seconds. */
static void
real_time_delay (int64_t num, int32_t denom)
{
c0023fb4:	55                   	push   %ebp
c0023fb5:	57                   	push   %edi
c0023fb6:	56                   	push   %esi
c0023fb7:	53                   	push   %ebx
c0023fb8:	83 ec 2c             	sub    $0x2c,%esp
c0023fbb:	89 c7                	mov    %eax,%edi
c0023fbd:	89 d6                	mov    %edx,%esi
c0023fbf:	89 cb                	mov    %ecx,%ebx
  /* Scale the numerator and denominator down by 1000 to avoid
     the possibility of overflow. */
  ASSERT (denom % 1000 == 0);
c0023fc1:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c0023fc6:	89 c8                	mov    %ecx,%eax
c0023fc8:	f7 ea                	imul   %edx
c0023fca:	c1 fa 06             	sar    $0x6,%edx
c0023fcd:	89 c8                	mov    %ecx,%eax
c0023fcf:	c1 f8 1f             	sar    $0x1f,%eax
c0023fd2:	29 c2                	sub    %eax,%edx
c0023fd4:	69 d2 e8 03 00 00    	imul   $0x3e8,%edx,%edx
c0023fda:	39 d1                	cmp    %edx,%ecx
c0023fdc:	74 2c                	je     c002400a <real_time_delay+0x56>
c0023fde:	c7 44 24 10 97 ec 02 	movl   $0xc002ec97,0x10(%esp)
c0023fe5:	c0 
c0023fe6:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0023fed:	c0 
c0023fee:	c7 44 24 08 b3 d2 02 	movl   $0xc002d2b3,0x8(%esp)
c0023ff5:	c0 
c0023ff6:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
c0023ffd:	00 
c0023ffe:	c7 04 24 a9 ec 02 c0 	movl   $0xc002eca9,(%esp)
c0024005:	e8 59 49 00 00       	call   c0028963 <debug_panic>
  busy_wait (loops_per_tick * num / 1000 * TIMER_FREQ / (denom / 1000)); 
c002400a:	a1 68 77 03 c0       	mov    0xc0037768,%eax
c002400f:	0f af f0             	imul   %eax,%esi
c0024012:	f7 e7                	mul    %edi
c0024014:	01 f2                	add    %esi,%edx
c0024016:	c7 44 24 08 e8 03 00 	movl   $0x3e8,0x8(%esp)
c002401d:	00 
c002401e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0024025:	00 
c0024026:	89 04 24             	mov    %eax,(%esp)
c0024029:	89 54 24 04          	mov    %edx,0x4(%esp)
c002402d:	e8 91 42 00 00       	call   c00282c3 <__divdi3>
c0024032:	6b ea 64             	imul   $0x64,%edx,%ebp
c0024035:	b9 64 00 00 00       	mov    $0x64,%ecx
c002403a:	f7 e1                	mul    %ecx
c002403c:	89 c6                	mov    %eax,%esi
c002403e:	89 d7                	mov    %edx,%edi
c0024040:	01 ef                	add    %ebp,%edi
c0024042:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c0024047:	89 d8                	mov    %ebx,%eax
c0024049:	f7 ea                	imul   %edx
c002404b:	c1 fa 06             	sar    $0x6,%edx
c002404e:	c1 fb 1f             	sar    $0x1f,%ebx
c0024051:	29 da                	sub    %ebx,%edx
c0024053:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024057:	89 d0                	mov    %edx,%eax
c0024059:	c1 f8 1f             	sar    $0x1f,%eax
c002405c:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0024060:	89 34 24             	mov    %esi,(%esp)
c0024063:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0024067:	e8 57 42 00 00       	call   c00282c3 <__divdi3>
c002406c:	e8 71 fd ff ff       	call   c0023de2 <busy_wait>
c0024071:	83 c4 2c             	add    $0x2c,%esp
c0024074:	5b                   	pop    %ebx
c0024075:	5e                   	pop    %esi
c0024076:	5f                   	pop    %edi
c0024077:	5d                   	pop    %ebp
c0024078:	c3                   	ret    

c0024079 <timer_init>:
{
c0024079:	83 ec 1c             	sub    $0x1c,%esp
  pit_configure_channel (0, 2, TIMER_FREQ);
c002407c:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0024083:	00 
c0024084:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
c002408b:	00 
c002408c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0024093:	e8 57 fc ff ff       	call   c0023cef <pit_configure_channel>
  intr_register_ext (0x20, timer_interrupt, "8254 Timer");
c0024098:	c7 44 24 08 bf ec 02 	movl   $0xc002ecbf,0x8(%esp)
c002409f:	c0 
c00240a0:	c7 44 24 04 59 3e 02 	movl   $0xc0023e59,0x4(%esp)
c00240a7:	c0 
c00240a8:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c00240af:	e8 8f da ff ff       	call   c0021b43 <intr_register_ext>
  list_init (&sleep_list);
c00240b4:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c00240bb:	e8 70 49 00 00       	call   c0028a30 <list_init>
  constant1 = divide_fixed_and_integer(convert_to_fixed_point(59),60);
c00240c0:	c7 04 24 3b 00 00 00 	movl   $0x3b,(%esp)
c00240c7:	e8 2d c8 ff ff       	call   c00208f9 <convert_to_fixed_point>
c00240cc:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c00240d3:	00 
c00240d4:	89 04 24             	mov    %eax,(%esp)
c00240d7:	e8 df ca ff ff       	call   c0020bbb <divide_fixed_and_integer>
c00240dc:	a3 cc 7b 03 c0       	mov    %eax,0xc0037bcc
  constant2 = divide_fixed_and_integer(convert_to_fixed_point(1),60);
c00240e1:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c00240e8:	e8 0c c8 ff ff       	call   c00208f9 <convert_to_fixed_point>
c00240ed:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c00240f4:	00 
c00240f5:	89 04 24             	mov    %eax,(%esp)
c00240f8:	e8 be ca ff ff       	call   c0020bbb <divide_fixed_and_integer>
c00240fd:	a3 c4 7b 03 c0       	mov    %eax,0xc0037bc4
}
c0024102:	83 c4 1c             	add    $0x1c,%esp
c0024105:	c3                   	ret    

c0024106 <timer_calibrate>:
{
c0024106:	57                   	push   %edi
c0024107:	56                   	push   %esi
c0024108:	53                   	push   %ebx
c0024109:	83 ec 20             	sub    $0x20,%esp
  ASSERT (intr_get_level () == INTR_ON);
c002410c:	e8 43 d8 ff ff       	call   c0021954 <intr_get_level>
c0024111:	83 f8 01             	cmp    $0x1,%eax
c0024114:	74 2c                	je     c0024142 <timer_calibrate+0x3c>
c0024116:	c7 44 24 10 ca ec 02 	movl   $0xc002ecca,0x10(%esp)
c002411d:	c0 
c002411e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024125:	c0 
c0024126:	c7 44 24 08 df d2 02 	movl   $0xc002d2df,0x8(%esp)
c002412d:	c0 
c002412e:	c7 44 24 04 43 00 00 	movl   $0x43,0x4(%esp)
c0024135:	00 
c0024136:	c7 04 24 a9 ec 02 c0 	movl   $0xc002eca9,(%esp)
c002413d:	e8 21 48 00 00       	call   c0028963 <debug_panic>
  printf ("Calibrating timer...  ");
c0024142:	c7 04 24 e7 ec 02 c0 	movl   $0xc002ece7,(%esp)
c0024149:	e8 c0 29 00 00       	call   c0026b0e <printf>
  loops_per_tick = 1u << 10;
c002414e:	c7 05 68 77 03 c0 00 	movl   $0x400,0xc0037768
c0024155:	04 00 00 
  while (!too_many_loops (loops_per_tick << 1)) 
c0024158:	eb 36                	jmp    c0024190 <timer_calibrate+0x8a>
      loops_per_tick <<= 1;
c002415a:	89 1d 68 77 03 c0    	mov    %ebx,0xc0037768
      ASSERT (loops_per_tick != 0);
c0024160:	85 db                	test   %ebx,%ebx
c0024162:	75 2c                	jne    c0024190 <timer_calibrate+0x8a>
c0024164:	c7 44 24 10 fe ec 02 	movl   $0xc002ecfe,0x10(%esp)
c002416b:	c0 
c002416c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024173:	c0 
c0024174:	c7 44 24 08 df d2 02 	movl   $0xc002d2df,0x8(%esp)
c002417b:	c0 
c002417c:	c7 44 24 04 4c 00 00 	movl   $0x4c,0x4(%esp)
c0024183:	00 
c0024184:	c7 04 24 a9 ec 02 c0 	movl   $0xc002eca9,(%esp)
c002418b:	e8 d3 47 00 00       	call   c0028963 <debug_panic>
  while (!too_many_loops (loops_per_tick << 1)) 
c0024190:	8b 35 68 77 03 c0    	mov    0xc0037768,%esi
c0024196:	8d 1c 36             	lea    (%esi,%esi,1),%ebx
c0024199:	89 d8                	mov    %ebx,%eax
c002419b:	e8 6b fc ff ff       	call   c0023e0b <too_many_loops>
c00241a0:	84 c0                	test   %al,%al
c00241a2:	74 b6                	je     c002415a <timer_calibrate+0x54>
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c00241a4:	89 f3                	mov    %esi,%ebx
c00241a6:	d1 eb                	shr    %ebx
c00241a8:	89 f7                	mov    %esi,%edi
c00241aa:	c1 ef 0a             	shr    $0xa,%edi
c00241ad:	39 df                	cmp    %ebx,%edi
c00241af:	74 19                	je     c00241ca <timer_calibrate+0xc4>
    if (!too_many_loops (high_bit | test_bit))
c00241b1:	89 d8                	mov    %ebx,%eax
c00241b3:	09 f0                	or     %esi,%eax
c00241b5:	e8 51 fc ff ff       	call   c0023e0b <too_many_loops>
c00241ba:	84 c0                	test   %al,%al
c00241bc:	75 06                	jne    c00241c4 <timer_calibrate+0xbe>
      loops_per_tick |= test_bit;
c00241be:	09 1d 68 77 03 c0    	or     %ebx,0xc0037768
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c00241c4:	d1 eb                	shr    %ebx
c00241c6:	39 df                	cmp    %ebx,%edi
c00241c8:	75 e7                	jne    c00241b1 <timer_calibrate+0xab>
  printf ("%'"PRIu64" loops/s.\n", (uint64_t) loops_per_tick * TIMER_FREQ);
c00241ca:	b8 64 00 00 00       	mov    $0x64,%eax
c00241cf:	f7 25 68 77 03 c0    	mull   0xc0037768
c00241d5:	89 44 24 04          	mov    %eax,0x4(%esp)
c00241d9:	89 54 24 08          	mov    %edx,0x8(%esp)
c00241dd:	c7 04 24 12 ed 02 c0 	movl   $0xc002ed12,(%esp)
c00241e4:	e8 25 29 00 00       	call   c0026b0e <printf>
}
c00241e9:	83 c4 20             	add    $0x20,%esp
c00241ec:	5b                   	pop    %ebx
c00241ed:	5e                   	pop    %esi
c00241ee:	5f                   	pop    %edi
c00241ef:	c3                   	ret    

c00241f0 <timer_ticks>:
{
c00241f0:	56                   	push   %esi
c00241f1:	53                   	push   %ebx
c00241f2:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level = intr_disable ();
c00241f5:	e8 a5 d7 ff ff       	call   c002199f <intr_disable>
  int64_t t = ticks;
c00241fa:	8b 15 70 77 03 c0    	mov    0xc0037770,%edx
c0024200:	8b 0d 74 77 03 c0    	mov    0xc0037774,%ecx
c0024206:	89 d3                	mov    %edx,%ebx
c0024208:	89 ce                	mov    %ecx,%esi
  intr_set_level (old_level);
c002420a:	89 04 24             	mov    %eax,(%esp)
c002420d:	e8 94 d7 ff ff       	call   c00219a6 <intr_set_level>
}
c0024212:	89 d8                	mov    %ebx,%eax
c0024214:	89 f2                	mov    %esi,%edx
c0024216:	83 c4 14             	add    $0x14,%esp
c0024219:	5b                   	pop    %ebx
c002421a:	5e                   	pop    %esi
c002421b:	c3                   	ret    

c002421c <timer_elapsed>:
{
c002421c:	57                   	push   %edi
c002421d:	56                   	push   %esi
c002421e:	83 ec 04             	sub    $0x4,%esp
c0024221:	8b 74 24 10          	mov    0x10(%esp),%esi
c0024225:	8b 7c 24 14          	mov    0x14(%esp),%edi
  return timer_ticks () - then;
c0024229:	e8 c2 ff ff ff       	call   c00241f0 <timer_ticks>
c002422e:	29 f0                	sub    %esi,%eax
c0024230:	19 fa                	sbb    %edi,%edx
}
c0024232:	83 c4 04             	add    $0x4,%esp
c0024235:	5e                   	pop    %esi
c0024236:	5f                   	pop    %edi
c0024237:	c3                   	ret    

c0024238 <timer_sleep>:
{
c0024238:	57                   	push   %edi
c0024239:	56                   	push   %esi
c002423a:	53                   	push   %ebx
c002423b:	83 ec 20             	sub    $0x20,%esp
c002423e:	8b 74 24 30          	mov    0x30(%esp),%esi
c0024242:	8b 7c 24 34          	mov    0x34(%esp),%edi
    ASSERT (intr_get_level () == INTR_ON);
c0024246:	e8 09 d7 ff ff       	call   c0021954 <intr_get_level>
c002424b:	83 f8 01             	cmp    $0x1,%eax
c002424e:	74 2c                	je     c002427c <timer_sleep+0x44>
c0024250:	c7 44 24 10 ca ec 02 	movl   $0xc002ecca,0x10(%esp)
c0024257:	c0 
c0024258:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002425f:	c0 
c0024260:	c7 44 24 08 d3 d2 02 	movl   $0xc002d2d3,0x8(%esp)
c0024267:	c0 
c0024268:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
c002426f:	00 
c0024270:	c7 04 24 a9 ec 02 c0 	movl   $0xc002eca9,(%esp)
c0024277:	e8 e7 46 00 00       	call   c0028963 <debug_panic>
    struct thread *cur = thread_current ();
c002427c:	e8 58 cb ff ff       	call   c0020dd9 <thread_current>
c0024281:	89 c3                	mov    %eax,%ebx
    int64_t uptime = timer_ticks () + ticks;
c0024283:	e8 68 ff ff ff       	call   c00241f0 <timer_ticks>
c0024288:	01 f0                	add    %esi,%eax
c002428a:	11 fa                	adc    %edi,%edx
c002428c:	89 43 34             	mov    %eax,0x34(%ebx)
c002428f:	89 53 38             	mov    %edx,0x38(%ebx)
    old_level = intr_disable ();
c0024292:	e8 08 d7 ff ff       	call   c002199f <intr_disable>
c0024297:	89 c6                	mov    %eax,%esi
    list_insert_ordered(&sleep_list, &cur->elem, compareSleep, 0);
c0024299:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00242a0:	00 
c00242a1:	c7 44 24 08 d0 3d 02 	movl   $0xc0023dd0,0x8(%esp)
c00242a8:	c0 
c00242a9:	83 c3 28             	add    $0x28,%ebx
c00242ac:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00242b0:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c00242b7:	e8 9a 51 00 00       	call   c0029456 <list_insert_ordered>
    thread_block();
c00242bc:	e8 4e d0 ff ff       	call   c002130f <thread_block>
    intr_set_level (old_level);
c00242c1:	89 34 24             	mov    %esi,(%esp)
c00242c4:	e8 dd d6 ff ff       	call   c00219a6 <intr_set_level>
}
c00242c9:	83 c4 20             	add    $0x20,%esp
c00242cc:	5b                   	pop    %ebx
c00242cd:	5e                   	pop    %esi
c00242ce:	5f                   	pop    %edi
c00242cf:	c3                   	ret    

c00242d0 <real_time_sleep>:
{
c00242d0:	55                   	push   %ebp
c00242d1:	57                   	push   %edi
c00242d2:	56                   	push   %esi
c00242d3:	53                   	push   %ebx
c00242d4:	83 ec 2c             	sub    $0x2c,%esp
c00242d7:	89 c7                	mov    %eax,%edi
c00242d9:	89 d6                	mov    %edx,%esi
c00242db:	89 cd                	mov    %ecx,%ebp
  int64_t ticks = num * TIMER_FREQ / denom;
c00242dd:	6b ca 64             	imul   $0x64,%edx,%ecx
c00242e0:	b8 64 00 00 00       	mov    $0x64,%eax
c00242e5:	f7 e7                	mul    %edi
c00242e7:	01 ca                	add    %ecx,%edx
c00242e9:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00242ed:	89 e9                	mov    %ebp,%ecx
c00242ef:	c1 f9 1f             	sar    $0x1f,%ecx
c00242f2:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c00242f6:	89 04 24             	mov    %eax,(%esp)
c00242f9:	89 54 24 04          	mov    %edx,0x4(%esp)
c00242fd:	e8 c1 3f 00 00       	call   c00282c3 <__divdi3>
c0024302:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c0024306:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_ON);
c0024308:	e8 47 d6 ff ff       	call   c0021954 <intr_get_level>
c002430d:	83 f8 01             	cmp    $0x1,%eax
c0024310:	74 2c                	je     c002433e <real_time_sleep+0x6e>
c0024312:	c7 44 24 10 ca ec 02 	movl   $0xc002ecca,0x10(%esp)
c0024319:	c0 
c002431a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024321:	c0 
c0024322:	c7 44 24 08 c3 d2 02 	movl   $0xc002d2c3,0x8(%esp)
c0024329:	c0 
c002432a:	c7 44 24 04 35 01 00 	movl   $0x135,0x4(%esp)
c0024331:	00 
c0024332:	c7 04 24 a9 ec 02 c0 	movl   $0xc002eca9,(%esp)
c0024339:	e8 25 46 00 00       	call   c0028963 <debug_panic>
  if (ticks > 0)
c002433e:	85 db                	test   %ebx,%ebx
c0024340:	78 1d                	js     c002435f <real_time_sleep+0x8f>
c0024342:	85 db                	test   %ebx,%ebx
c0024344:	7f 07                	jg     c002434d <real_time_sleep+0x7d>
c0024346:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c002434b:	76 12                	jbe    c002435f <real_time_sleep+0x8f>
      timer_sleep (ticks); 
c002434d:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0024351:	89 04 24             	mov    %eax,(%esp)
c0024354:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024358:	e8 db fe ff ff       	call   c0024238 <timer_sleep>
c002435d:	eb 0b                	jmp    c002436a <real_time_sleep+0x9a>
      real_time_delay (num, denom); 
c002435f:	89 e9                	mov    %ebp,%ecx
c0024361:	89 f8                	mov    %edi,%eax
c0024363:	89 f2                	mov    %esi,%edx
c0024365:	e8 4a fc ff ff       	call   c0023fb4 <real_time_delay>
}
c002436a:	83 c4 2c             	add    $0x2c,%esp
c002436d:	5b                   	pop    %ebx
c002436e:	5e                   	pop    %esi
c002436f:	5f                   	pop    %edi
c0024370:	5d                   	pop    %ebp
c0024371:	c3                   	ret    

c0024372 <timer_msleep>:
{
c0024372:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ms, 1000);
c0024375:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002437a:	8b 44 24 10          	mov    0x10(%esp),%eax
c002437e:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024382:	e8 49 ff ff ff       	call   c00242d0 <real_time_sleep>
}
c0024387:	83 c4 0c             	add    $0xc,%esp
c002438a:	c3                   	ret    

c002438b <timer_usleep>:
{
c002438b:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (us, 1000 * 1000);
c002438e:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c0024393:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024397:	8b 54 24 14          	mov    0x14(%esp),%edx
c002439b:	e8 30 ff ff ff       	call   c00242d0 <real_time_sleep>
}
c00243a0:	83 c4 0c             	add    $0xc,%esp
c00243a3:	c3                   	ret    

c00243a4 <timer_nsleep>:
{
c00243a4:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ns, 1000 * 1000 * 1000);
c00243a7:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c00243ac:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243b0:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243b4:	e8 17 ff ff ff       	call   c00242d0 <real_time_sleep>
}
c00243b9:	83 c4 0c             	add    $0xc,%esp
c00243bc:	c3                   	ret    

c00243bd <timer_mdelay>:
{
c00243bd:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ms, 1000);
c00243c0:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c00243c5:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243c9:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243cd:	e8 e2 fb ff ff       	call   c0023fb4 <real_time_delay>
}
c00243d2:	83 c4 0c             	add    $0xc,%esp
c00243d5:	c3                   	ret    

c00243d6 <timer_udelay>:
{
c00243d6:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (us, 1000 * 1000);
c00243d9:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00243de:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243e2:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243e6:	e8 c9 fb ff ff       	call   c0023fb4 <real_time_delay>
}
c00243eb:	83 c4 0c             	add    $0xc,%esp
c00243ee:	c3                   	ret    

c00243ef <timer_ndelay>:
{
c00243ef:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ns, 1000 * 1000 * 1000);
c00243f2:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c00243f7:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243fb:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243ff:	e8 b0 fb ff ff       	call   c0023fb4 <real_time_delay>
}
c0024404:	83 c4 0c             	add    $0xc,%esp
c0024407:	c3                   	ret    

c0024408 <timer_print_stats>:
{
c0024408:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Timer: %"PRId64" ticks\n", timer_ticks ());
c002440b:	e8 e0 fd ff ff       	call   c00241f0 <timer_ticks>
c0024410:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024414:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024418:	c7 04 24 22 ed 02 c0 	movl   $0xc002ed22,(%esp)
c002441f:	e8 ea 26 00 00       	call   c0026b0e <printf>
}
c0024424:	83 c4 1c             	add    $0x1c,%esp
c0024427:	c3                   	ret    
c0024428:	90                   	nop
c0024429:	90                   	nop
c002442a:	90                   	nop
c002442b:	90                   	nop
c002442c:	90                   	nop
c002442d:	90                   	nop
c002442e:	90                   	nop
c002442f:	90                   	nop

c0024430 <map_key>:
   If found, sets *C to the corresponding character and returns
   true.
   If not found, returns false and C is ignored. */
static bool
map_key (const struct keymap k[], unsigned scancode, uint8_t *c) 
{
c0024430:	55                   	push   %ebp
c0024431:	57                   	push   %edi
c0024432:	56                   	push   %esi
c0024433:	53                   	push   %ebx
c0024434:	83 ec 04             	sub    $0x4,%esp
c0024437:	89 c3                	mov    %eax,%ebx
c0024439:	89 0c 24             	mov    %ecx,(%esp)
  for (; k->first_scancode != 0; k++)
c002443c:	0f b6 08             	movzbl (%eax),%ecx
c002443f:	84 c9                	test   %cl,%cl
c0024441:	74 41                	je     c0024484 <map_key+0x54>
    if (scancode >= k->first_scancode
        && scancode < k->first_scancode + strlen (k->chars)) 
c0024443:	b8 00 00 00 00       	mov    $0x0,%eax
    if (scancode >= k->first_scancode
c0024448:	0f b6 f1             	movzbl %cl,%esi
c002444b:	39 d6                	cmp    %edx,%esi
c002444d:	77 29                	ja     c0024478 <map_key+0x48>
        && scancode < k->first_scancode + strlen (k->chars)) 
c002444f:	8b 6b 04             	mov    0x4(%ebx),%ebp
c0024452:	89 ef                	mov    %ebp,%edi
c0024454:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0024459:	f2 ae                	repnz scas %es:(%edi),%al
c002445b:	f7 d1                	not    %ecx
c002445d:	8d 4c 0e ff          	lea    -0x1(%esi,%ecx,1),%ecx
c0024461:	39 ca                	cmp    %ecx,%edx
c0024463:	73 13                	jae    c0024478 <map_key+0x48>
      {
        *c = k->chars[scancode - k->first_scancode];
c0024465:	29 f2                	sub    %esi,%edx
c0024467:	0f b6 44 15 00       	movzbl 0x0(%ebp,%edx,1),%eax
c002446c:	8b 3c 24             	mov    (%esp),%edi
c002446f:	88 07                	mov    %al,(%edi)
        return true; 
c0024471:	b8 01 00 00 00       	mov    $0x1,%eax
c0024476:	eb 18                	jmp    c0024490 <map_key+0x60>
  for (; k->first_scancode != 0; k++)
c0024478:	83 c3 08             	add    $0x8,%ebx
c002447b:	0f b6 0b             	movzbl (%ebx),%ecx
c002447e:	84 c9                	test   %cl,%cl
c0024480:	75 c6                	jne    c0024448 <map_key+0x18>
c0024482:	eb 07                	jmp    c002448b <map_key+0x5b>
      }

  return false;
c0024484:	b8 00 00 00 00       	mov    $0x0,%eax
c0024489:	eb 05                	jmp    c0024490 <map_key+0x60>
c002448b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0024490:	83 c4 04             	add    $0x4,%esp
c0024493:	5b                   	pop    %ebx
c0024494:	5e                   	pop    %esi
c0024495:	5f                   	pop    %edi
c0024496:	5d                   	pop    %ebp
c0024497:	c3                   	ret    

c0024498 <keyboard_interrupt>:
{
c0024498:	55                   	push   %ebp
c0024499:	57                   	push   %edi
c002449a:	56                   	push   %esi
c002449b:	53                   	push   %ebx
c002449c:	83 ec 2c             	sub    $0x2c,%esp
  bool shift = left_shift || right_shift;
c002449f:	0f b6 15 85 77 03 c0 	movzbl 0xc0037785,%edx
c00244a6:	80 3d 86 77 03 c0 00 	cmpb   $0x0,0xc0037786
c00244ad:	b8 01 00 00 00       	mov    $0x1,%eax
c00244b2:	0f 45 d0             	cmovne %eax,%edx
  bool alt = left_alt || right_alt;
c00244b5:	0f b6 3d 83 77 03 c0 	movzbl 0xc0037783,%edi
c00244bc:	80 3d 84 77 03 c0 00 	cmpb   $0x0,0xc0037784
c00244c3:	0f 45 f8             	cmovne %eax,%edi
  bool ctrl = left_ctrl || right_ctrl;
c00244c6:	0f b6 2d 81 77 03 c0 	movzbl 0xc0037781,%ebp
c00244cd:	80 3d 82 77 03 c0 00 	cmpb   $0x0,0xc0037782
c00244d4:	0f 45 e8             	cmovne %eax,%ebp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00244d7:	e4 60                	in     $0x60,%al
  code = inb (DATA_REG);
c00244d9:	0f b6 d8             	movzbl %al,%ebx
  if (code == 0xe0)
c00244dc:	81 fb e0 00 00 00    	cmp    $0xe0,%ebx
c00244e2:	75 08                	jne    c00244ec <keyboard_interrupt+0x54>
c00244e4:	e4 60                	in     $0x60,%al
    code = (code << 8) | inb (DATA_REG);
c00244e6:	0f b6 d8             	movzbl %al,%ebx
c00244e9:	80 cf e0             	or     $0xe0,%bh
  release = (code & 0x80) != 0;
c00244ec:	89 de                	mov    %ebx,%esi
c00244ee:	c1 ee 07             	shr    $0x7,%esi
c00244f1:	83 e6 01             	and    $0x1,%esi
  code &= ~0x80u;
c00244f4:	80 e3 7f             	and    $0x7f,%bl
  if (code == 0x3a) 
c00244f7:	83 fb 3a             	cmp    $0x3a,%ebx
c00244fa:	75 16                	jne    c0024512 <keyboard_interrupt+0x7a>
      if (!release)
c00244fc:	89 f0                	mov    %esi,%eax
c00244fe:	84 c0                	test   %al,%al
c0024500:	0f 85 1d 01 00 00    	jne    c0024623 <keyboard_interrupt+0x18b>
        caps_lock = !caps_lock;
c0024506:	80 35 80 77 03 c0 01 	xorb   $0x1,0xc0037780
c002450d:	e9 11 01 00 00       	jmp    c0024623 <keyboard_interrupt+0x18b>
  bool shift = left_shift || right_shift;
c0024512:	89 d0                	mov    %edx,%eax
c0024514:	83 e0 01             	and    $0x1,%eax
c0024517:	88 44 24 0f          	mov    %al,0xf(%esp)
  else if (map_key (invariant_keymap, code, &c)
c002451b:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002451f:	89 da                	mov    %ebx,%edx
c0024521:	b8 c0 d3 02 c0       	mov    $0xc002d3c0,%eax
c0024526:	e8 05 ff ff ff       	call   c0024430 <map_key>
c002452b:	84 c0                	test   %al,%al
c002452d:	75 23                	jne    c0024552 <keyboard_interrupt+0xba>
           || (!shift && map_key (unshifted_keymap, code, &c))
c002452f:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0024534:	0f 85 c5 00 00 00    	jne    c00245ff <keyboard_interrupt+0x167>
c002453a:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002453e:	89 da                	mov    %ebx,%edx
c0024540:	b8 80 d3 02 c0       	mov    $0xc002d380,%eax
c0024545:	e8 e6 fe ff ff       	call   c0024430 <map_key>
c002454a:	84 c0                	test   %al,%al
c002454c:	0f 84 c5 00 00 00    	je     c0024617 <keyboard_interrupt+0x17f>
      if (!release) 
c0024552:	89 f0                	mov    %esi,%eax
c0024554:	84 c0                	test   %al,%al
c0024556:	0f 85 c7 00 00 00    	jne    c0024623 <keyboard_interrupt+0x18b>
          if (c == 0177 && ctrl && alt)
c002455c:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c0024561:	3c 7f                	cmp    $0x7f,%al
c0024563:	75 0f                	jne    c0024574 <keyboard_interrupt+0xdc>
c0024565:	21 fd                	and    %edi,%ebp
c0024567:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c002456d:	74 1b                	je     c002458a <keyboard_interrupt+0xf2>
            shutdown_reboot ();
c002456f:	e8 06 1e 00 00       	call   c002637a <shutdown_reboot>
          if (ctrl && c >= 0x40 && c < 0x60) 
c0024574:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c002457a:	74 0e                	je     c002458a <keyboard_interrupt+0xf2>
c002457c:	8d 50 c0             	lea    -0x40(%eax),%edx
c002457f:	80 fa 1f             	cmp    $0x1f,%dl
c0024582:	77 06                	ja     c002458a <keyboard_interrupt+0xf2>
              c -= 0x40; 
c0024584:	88 54 24 1f          	mov    %dl,0x1f(%esp)
c0024588:	eb 20                	jmp    c00245aa <keyboard_interrupt+0x112>
          else if (shift == caps_lock)
c002458a:	0f b6 4c 24 0f       	movzbl 0xf(%esp),%ecx
c002458f:	3a 0d 80 77 03 c0    	cmp    0xc0037780,%cl
c0024595:	75 13                	jne    c00245aa <keyboard_interrupt+0x112>
            c = tolower (c);
c0024597:	0f b6 c0             	movzbl %al,%eax
#ifndef __LIB_CTYPE_H
#define __LIB_CTYPE_H

static inline int islower (int c) { return c >= 'a' && c <= 'z'; }
static inline int isupper (int c) { return c >= 'A' && c <= 'Z'; }
c002459a:	8d 48 bf             	lea    -0x41(%eax),%ecx
static inline int isascii (int c) { return c >= 0 && c < 128; }
static inline int ispunct (int c) {
  return isprint (c) && !isalnum (c) && !isspace (c);
}

static inline int tolower (int c) { return isupper (c) ? c - 'A' + 'a' : c; }
c002459d:	8d 50 20             	lea    0x20(%eax),%edx
c00245a0:	83 f9 19             	cmp    $0x19,%ecx
c00245a3:	0f 46 c2             	cmovbe %edx,%eax
c00245a6:	88 44 24 1f          	mov    %al,0x1f(%esp)
          if (alt)
c00245aa:	f7 c7 01 00 00 00    	test   $0x1,%edi
c00245b0:	74 05                	je     c00245b7 <keyboard_interrupt+0x11f>
            c += 0x80;
c00245b2:	80 44 24 1f 80       	addb   $0x80,0x1f(%esp)
          if (!input_full ())
c00245b7:	e8 11 18 00 00       	call   c0025dcd <input_full>
c00245bc:	84 c0                	test   %al,%al
c00245be:	75 63                	jne    c0024623 <keyboard_interrupt+0x18b>
              key_cnt++;
c00245c0:	83 05 78 77 03 c0 01 	addl   $0x1,0xc0037778
c00245c7:	83 15 7c 77 03 c0 00 	adcl   $0x0,0xc003777c
              input_putc (c);
c00245ce:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c00245d3:	89 04 24             	mov    %eax,(%esp)
c00245d6:	e8 2d 17 00 00       	call   c0025d08 <input_putc>
c00245db:	eb 46                	jmp    c0024623 <keyboard_interrupt+0x18b>
        if (key->scancode == code)
c00245dd:	39 d3                	cmp    %edx,%ebx
c00245df:	75 13                	jne    c00245f4 <keyboard_interrupt+0x15c>
c00245e1:	eb 05                	jmp    c00245e8 <keyboard_interrupt+0x150>
      for (key = shift_keys; key->scancode != 0; key++) 
c00245e3:	b8 00 d3 02 c0       	mov    $0xc002d300,%eax
            *key->state_var = !release;
c00245e8:	8b 40 04             	mov    0x4(%eax),%eax
c00245eb:	89 f2                	mov    %esi,%edx
c00245ed:	83 f2 01             	xor    $0x1,%edx
c00245f0:	88 10                	mov    %dl,(%eax)
            break;
c00245f2:	eb 2f                	jmp    c0024623 <keyboard_interrupt+0x18b>
      for (key = shift_keys; key->scancode != 0; key++) 
c00245f4:	83 c0 08             	add    $0x8,%eax
c00245f7:	8b 10                	mov    (%eax),%edx
c00245f9:	85 d2                	test   %edx,%edx
c00245fb:	75 e0                	jne    c00245dd <keyboard_interrupt+0x145>
c00245fd:	eb 24                	jmp    c0024623 <keyboard_interrupt+0x18b>
           || (shift && map_key (shifted_keymap, code, &c)))
c00245ff:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c0024603:	89 da                	mov    %ebx,%edx
c0024605:	b8 40 d3 02 c0       	mov    $0xc002d340,%eax
c002460a:	e8 21 fe ff ff       	call   c0024430 <map_key>
c002460f:	84 c0                	test   %al,%al
c0024611:	0f 85 3b ff ff ff    	jne    c0024552 <keyboard_interrupt+0xba>
        if (key->scancode == code)
c0024617:	83 fb 2a             	cmp    $0x2a,%ebx
c002461a:	74 c7                	je     c00245e3 <keyboard_interrupt+0x14b>
      for (key = shift_keys; key->scancode != 0; key++) 
c002461c:	b8 00 d3 02 c0       	mov    $0xc002d300,%eax
c0024621:	eb d1                	jmp    c00245f4 <keyboard_interrupt+0x15c>
}
c0024623:	83 c4 2c             	add    $0x2c,%esp
c0024626:	5b                   	pop    %ebx
c0024627:	5e                   	pop    %esi
c0024628:	5f                   	pop    %edi
c0024629:	5d                   	pop    %ebp
c002462a:	c3                   	ret    

c002462b <kbd_init>:
{
c002462b:	83 ec 1c             	sub    $0x1c,%esp
  intr_register_ext (0x21, keyboard_interrupt, "8042 Keyboard");
c002462e:	c7 44 24 08 35 ed 02 	movl   $0xc002ed35,0x8(%esp)
c0024635:	c0 
c0024636:	c7 44 24 04 98 44 02 	movl   $0xc0024498,0x4(%esp)
c002463d:	c0 
c002463e:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c0024645:	e8 f9 d4 ff ff       	call   c0021b43 <intr_register_ext>
}
c002464a:	83 c4 1c             	add    $0x1c,%esp
c002464d:	c3                   	ret    

c002464e <kbd_print_stats>:
{
c002464e:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Keyboard: %lld keys pressed\n", key_cnt);
c0024651:	a1 78 77 03 c0       	mov    0xc0037778,%eax
c0024656:	8b 15 7c 77 03 c0    	mov    0xc003777c,%edx
c002465c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024660:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024664:	c7 04 24 43 ed 02 c0 	movl   $0xc002ed43,(%esp)
c002466b:	e8 9e 24 00 00       	call   c0026b0e <printf>
}
c0024670:	83 c4 1c             	add    $0x1c,%esp
c0024673:	c3                   	ret    
c0024674:	90                   	nop
c0024675:	90                   	nop
c0024676:	90                   	nop
c0024677:	90                   	nop
c0024678:	90                   	nop
c0024679:	90                   	nop
c002467a:	90                   	nop
c002467b:	90                   	nop
c002467c:	90                   	nop
c002467d:	90                   	nop
c002467e:	90                   	nop
c002467f:	90                   	nop

c0024680 <move_cursor>:
/* Moves the hardware cursor to (cx,cy). */
static void
move_cursor (void) 
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp = cx + COL_CNT * cy;
c0024680:	8b 0d 90 77 03 c0    	mov    0xc0037790,%ecx
c0024686:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0024689:	c1 e1 04             	shl    $0x4,%ecx
c002468c:	66 03 0d 94 77 03 c0 	add    0xc0037794,%cx
  outw (0x3d4, 0x0e | (cp & 0xff00));
c0024693:	89 c8                	mov    %ecx,%eax
c0024695:	b0 00                	mov    $0x0,%al
c0024697:	83 c8 0e             	or     $0xe,%eax
/* Writes the 16-bit DATA to PORT. */
static inline void
outw (uint16_t port, uint16_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c002469a:	ba d4 03 00 00       	mov    $0x3d4,%edx
c002469f:	66 ef                	out    %ax,(%dx)
  outw (0x3d4, 0x0f | (cp << 8));
c00246a1:	89 c8                	mov    %ecx,%eax
c00246a3:	c1 e0 08             	shl    $0x8,%eax
c00246a6:	83 c8 0f             	or     $0xf,%eax
c00246a9:	66 ef                	out    %ax,(%dx)
c00246ab:	c3                   	ret    

c00246ac <newline>:
  cx = 0;
c00246ac:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c00246b3:	00 00 00 
  cy++;
c00246b6:	a1 90 77 03 c0       	mov    0xc0037790,%eax
c00246bb:	83 c0 01             	add    $0x1,%eax
  if (cy >= ROW_CNT)
c00246be:	83 f8 18             	cmp    $0x18,%eax
c00246c1:	77 06                	ja     c00246c9 <newline+0x1d>
  cy++;
c00246c3:	a3 90 77 03 c0       	mov    %eax,0xc0037790
c00246c8:	c3                   	ret    
{
c00246c9:	53                   	push   %ebx
c00246ca:	83 ec 18             	sub    $0x18,%esp
      cy = ROW_CNT - 1;
c00246cd:	c7 05 90 77 03 c0 18 	movl   $0x18,0xc0037790
c00246d4:	00 00 00 
      memmove (&fb[0], &fb[1], sizeof fb[0] * (ROW_CNT - 1));
c00246d7:	8b 1d 8c 77 03 c0    	mov    0xc003778c,%ebx
c00246dd:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
c00246e4:	00 
c00246e5:	8d 83 a0 00 00 00    	lea    0xa0(%ebx),%eax
c00246eb:	89 44 24 04          	mov    %eax,0x4(%esp)
c00246ef:	89 1c 24             	mov    %ebx,(%esp)
c00246f2:	e8 e6 31 00 00       	call   c00278dd <memmove>
  for (x = 0; x < COL_CNT; x++)
c00246f7:	b8 00 00 00 00       	mov    $0x0,%eax
      fb[y][x][0] = ' ';
c00246fc:	c6 84 43 00 0f 00 00 	movb   $0x20,0xf00(%ebx,%eax,2)
c0024703:	20 
      fb[y][x][1] = GRAY_ON_BLACK;
c0024704:	c6 84 43 01 0f 00 00 	movb   $0x7,0xf01(%ebx,%eax,2)
c002470b:	07 
  for (x = 0; x < COL_CNT; x++)
c002470c:	83 c0 01             	add    $0x1,%eax
c002470f:	83 f8 50             	cmp    $0x50,%eax
c0024712:	75 e8                	jne    c00246fc <newline+0x50>
}
c0024714:	83 c4 18             	add    $0x18,%esp
c0024717:	5b                   	pop    %ebx
c0024718:	c3                   	ret    

c0024719 <vga_putc>:
{
c0024719:	57                   	push   %edi
c002471a:	56                   	push   %esi
c002471b:	53                   	push   %ebx
c002471c:	83 ec 10             	sub    $0x10,%esp
c002471f:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  enum intr_level old_level = intr_disable ();
c0024723:	e8 77 d2 ff ff       	call   c002199f <intr_disable>
c0024728:	89 c6                	mov    %eax,%esi
  if (!inited)
c002472a:	80 3d 88 77 03 c0 00 	cmpb   $0x0,0xc0037788
c0024731:	75 5e                	jne    c0024791 <vga_putc+0x78>
      fb = ptov (0xb8000);
c0024733:	c7 05 8c 77 03 c0 00 	movl   $0xc00b8000,0xc003778c
c002473a:	80 0b c0 
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002473d:	ba d4 03 00 00       	mov    $0x3d4,%edx
c0024742:	b8 0e 00 00 00       	mov    $0xe,%eax
c0024747:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024748:	b9 d5 03 00 00       	mov    $0x3d5,%ecx
c002474d:	89 ca                	mov    %ecx,%edx
c002474f:	ec                   	in     (%dx),%al
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp;

  outb (0x3d4, 0x0e);
  cp = inb (0x3d5) << 8;
c0024750:	89 c7                	mov    %eax,%edi
c0024752:	c1 e7 08             	shl    $0x8,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024755:	b2 d4                	mov    $0xd4,%dl
c0024757:	b8 0f 00 00 00       	mov    $0xf,%eax
c002475c:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002475d:	89 ca                	mov    %ecx,%edx
c002475f:	ec                   	in     (%dx),%al

  outb (0x3d4, 0x0f);
  cp |= inb (0x3d5);
c0024760:	0f b6 d0             	movzbl %al,%edx
c0024763:	09 fa                	or     %edi,%edx

  *x = cp % COL_CNT;
c0024765:	0f b7 c2             	movzwl %dx,%eax
c0024768:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
c002476e:	c1 e8 16             	shr    $0x16,%eax
c0024771:	8d 0c 80             	lea    (%eax,%eax,4),%ecx
c0024774:	c1 e1 04             	shl    $0x4,%ecx
c0024777:	29 ca                	sub    %ecx,%edx
c0024779:	0f b7 d2             	movzwl %dx,%edx
c002477c:	89 15 94 77 03 c0    	mov    %edx,0xc0037794
  *y = cp / COL_CNT;
c0024782:	0f b7 c0             	movzwl %ax,%eax
c0024785:	a3 90 77 03 c0       	mov    %eax,0xc0037790
      inited = true; 
c002478a:	c6 05 88 77 03 c0 01 	movb   $0x1,0xc0037788
  switch (c) 
c0024791:	8d 43 f9             	lea    -0x7(%ebx),%eax
c0024794:	83 f8 06             	cmp    $0x6,%eax
c0024797:	0f 87 b8 00 00 00    	ja     c0024855 <vga_putc+0x13c>
c002479d:	ff 24 85 10 d4 02 c0 	jmp    *-0x3ffd2bf0(,%eax,4)
c00247a4:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
      fb[y][x][0] = ' ';
c00247a9:	bb 00 00 00 00       	mov    $0x0,%ebx
c00247ae:	eb 28                	jmp    c00247d8 <vga_putc+0xbf>
      newline ();
c00247b0:	e8 f7 fe ff ff       	call   c00246ac <newline>
      break;
c00247b5:	e9 e7 00 00 00       	jmp    c00248a1 <vga_putc+0x188>
      fb[y][x][0] = ' ';
c00247ba:	c6 04 51 20          	movb   $0x20,(%ecx,%edx,2)
      fb[y][x][1] = GRAY_ON_BLACK;
c00247be:	c6 44 51 01 07       	movb   $0x7,0x1(%ecx,%edx,2)
  for (x = 0; x < COL_CNT; x++)
c00247c3:	83 c2 01             	add    $0x1,%edx
c00247c6:	83 fa 50             	cmp    $0x50,%edx
c00247c9:	75 ef                	jne    c00247ba <vga_putc+0xa1>
  for (y = 0; y < ROW_CNT; y++)
c00247cb:	83 c3 01             	add    $0x1,%ebx
c00247ce:	05 a0 00 00 00       	add    $0xa0,%eax
c00247d3:	83 fb 19             	cmp    $0x19,%ebx
c00247d6:	74 09                	je     c00247e1 <vga_putc+0xc8>
      fb[y][x][0] = ' ';
c00247d8:	89 c1                	mov    %eax,%ecx
c00247da:	ba 00 00 00 00       	mov    $0x0,%edx
c00247df:	eb d9                	jmp    c00247ba <vga_putc+0xa1>
  cx = cy = 0;
c00247e1:	c7 05 90 77 03 c0 00 	movl   $0x0,0xc0037790
c00247e8:	00 00 00 
c00247eb:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c00247f2:	00 00 00 
  move_cursor ();
c00247f5:	e8 86 fe ff ff       	call   c0024680 <move_cursor>
c00247fa:	e9 a2 00 00 00       	jmp    c00248a1 <vga_putc+0x188>
      if (cx > 0)
c00247ff:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c0024804:	85 c0                	test   %eax,%eax
c0024806:	0f 84 95 00 00 00    	je     c00248a1 <vga_putc+0x188>
        cx--;
c002480c:	83 e8 01             	sub    $0x1,%eax
c002480f:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c0024814:	e9 88 00 00 00       	jmp    c00248a1 <vga_putc+0x188>
      cx = 0;
c0024819:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024820:	00 00 00 
      break;
c0024823:	eb 7c                	jmp    c00248a1 <vga_putc+0x188>
      cx = ROUND_UP (cx + 1, 8);
c0024825:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c002482a:	83 c0 08             	add    $0x8,%eax
c002482d:	83 e0 f8             	and    $0xfffffff8,%eax
c0024830:	a3 94 77 03 c0       	mov    %eax,0xc0037794
      if (cx >= COL_CNT)
c0024835:	83 f8 4f             	cmp    $0x4f,%eax
c0024838:	76 67                	jbe    c00248a1 <vga_putc+0x188>
        newline ();
c002483a:	e8 6d fe ff ff       	call   c00246ac <newline>
c002483f:	eb 60                	jmp    c00248a1 <vga_putc+0x188>
      intr_set_level (old_level);
c0024841:	89 34 24             	mov    %esi,(%esp)
c0024844:	e8 5d d1 ff ff       	call   c00219a6 <intr_set_level>
      speaker_beep ();
c0024849:	e8 bd 1c 00 00       	call   c002650b <speaker_beep>
      intr_disable ();
c002484e:	e8 4c d1 ff ff       	call   c002199f <intr_disable>
      break;
c0024853:	eb 4c                	jmp    c00248a1 <vga_putc+0x188>
      fb[cy][cx][0] = c;
c0024855:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
c002485a:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c0024860:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0024863:	c1 e2 05             	shl    $0x5,%edx
c0024866:	01 c2                	add    %eax,%edx
c0024868:	8b 0d 94 77 03 c0    	mov    0xc0037794,%ecx
c002486e:	88 1c 4a             	mov    %bl,(%edx,%ecx,2)
      fb[cy][cx][1] = GRAY_ON_BLACK;
c0024871:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c0024877:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002487a:	c1 e2 05             	shl    $0x5,%edx
c002487d:	01 d0                	add    %edx,%eax
c002487f:	8b 15 94 77 03 c0    	mov    0xc0037794,%edx
c0024885:	c6 44 50 01 07       	movb   $0x7,0x1(%eax,%edx,2)
      if (++cx >= COL_CNT)
c002488a:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c002488f:	83 c0 01             	add    $0x1,%eax
c0024892:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c0024897:	83 f8 4f             	cmp    $0x4f,%eax
c002489a:	76 05                	jbe    c00248a1 <vga_putc+0x188>
        newline ();
c002489c:	e8 0b fe ff ff       	call   c00246ac <newline>
  move_cursor ();
c00248a1:	e8 da fd ff ff       	call   c0024680 <move_cursor>
  intr_set_level (old_level);
c00248a6:	89 34 24             	mov    %esi,(%esp)
c00248a9:	e8 f8 d0 ff ff       	call   c00219a6 <intr_set_level>
}
c00248ae:	83 c4 10             	add    $0x10,%esp
c00248b1:	5b                   	pop    %ebx
c00248b2:	5e                   	pop    %esi
c00248b3:	5f                   	pop    %edi
c00248b4:	c3                   	ret    
c00248b5:	90                   	nop
c00248b6:	90                   	nop
c00248b7:	90                   	nop
c00248b8:	90                   	nop
c00248b9:	90                   	nop
c00248ba:	90                   	nop
c00248bb:	90                   	nop
c00248bc:	90                   	nop
c00248bd:	90                   	nop
c00248be:	90                   	nop
c00248bf:	90                   	nop

c00248c0 <init_poll>:
   Polling mode busy-waits for the serial port to become free
   before writing to it.  It's slow, but until interrupts have
   been initialized it's all we can do. */
static void
init_poll (void) 
{
c00248c0:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (mode == UNINIT);
c00248c3:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c00248ca:	74 2c                	je     c00248f8 <init_poll+0x38>
c00248cc:	c7 44 24 10 bc ed 02 	movl   $0xc002edbc,0x10(%esp)
c00248d3:	c0 
c00248d4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00248db:	c0 
c00248dc:	c7 44 24 08 4e d4 02 	movl   $0xc002d44e,0x8(%esp)
c00248e3:	c0 
c00248e4:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c00248eb:	00 
c00248ec:	c7 04 24 cb ed 02 c0 	movl   $0xc002edcb,(%esp)
c00248f3:	e8 6b 40 00 00       	call   c0028963 <debug_panic>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00248f8:	ba f9 03 00 00       	mov    $0x3f9,%edx
c00248fd:	b8 00 00 00 00       	mov    $0x0,%eax
c0024902:	ee                   	out    %al,(%dx)
c0024903:	b2 fa                	mov    $0xfa,%dl
c0024905:	ee                   	out    %al,(%dx)
c0024906:	b2 fb                	mov    $0xfb,%dl
c0024908:	b8 83 ff ff ff       	mov    $0xffffff83,%eax
c002490d:	ee                   	out    %al,(%dx)
c002490e:	b2 f8                	mov    $0xf8,%dl
c0024910:	b8 0c 00 00 00       	mov    $0xc,%eax
c0024915:	ee                   	out    %al,(%dx)
c0024916:	b2 f9                	mov    $0xf9,%dl
c0024918:	b8 00 00 00 00       	mov    $0x0,%eax
c002491d:	ee                   	out    %al,(%dx)
c002491e:	b2 fb                	mov    $0xfb,%dl
c0024920:	b8 03 00 00 00       	mov    $0x3,%eax
c0024925:	ee                   	out    %al,(%dx)
c0024926:	b2 fc                	mov    $0xfc,%dl
c0024928:	b8 08 00 00 00       	mov    $0x8,%eax
c002492d:	ee                   	out    %al,(%dx)
  outb (IER_REG, 0);                    /* Turn off all interrupts. */
  outb (FCR_REG, 0);                    /* Disable FIFO. */
  set_serial (9600);                    /* 9.6 kbps, N-8-1. */
  outb (MCR_REG, MCR_OUT2);             /* Required to enable interrupts. */
  intq_init (&txq);
c002492e:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024935:	e8 db 14 00 00       	call   c0025e15 <intq_init>
  mode = POLL;
c002493a:	c7 05 14 78 03 c0 01 	movl   $0x1,0xc0037814
c0024941:	00 00 00 
} 
c0024944:	83 c4 2c             	add    $0x2c,%esp
c0024947:	c3                   	ret    

c0024948 <write_ier>:
}

/* Update interrupt enable register. */
static void
write_ier (void) 
{
c0024948:	53                   	push   %ebx
c0024949:	83 ec 28             	sub    $0x28,%esp
  uint8_t ier = 0;

  ASSERT (intr_get_level () == INTR_OFF);
c002494c:	e8 03 d0 ff ff       	call   c0021954 <intr_get_level>
c0024951:	85 c0                	test   %eax,%eax
c0024953:	74 2c                	je     c0024981 <write_ier+0x39>
c0024955:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c002495c:	c0 
c002495d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024964:	c0 
c0024965:	c7 44 24 08 44 d4 02 	movl   $0xc002d444,0x8(%esp)
c002496c:	c0 
c002496d:	c7 44 24 04 b5 00 00 	movl   $0xb5,0x4(%esp)
c0024974:	00 
c0024975:	c7 04 24 cb ed 02 c0 	movl   $0xc002edcb,(%esp)
c002497c:	e8 e2 3f 00 00       	call   c0028963 <debug_panic>

  /* Enable transmit interrupt if we have any characters to
     transmit. */
  if (!intq_empty (&txq))
c0024981:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024988:	e8 b9 14 00 00       	call   c0025e46 <intq_empty>
  uint8_t ier = 0;
c002498d:	3c 01                	cmp    $0x1,%al
c002498f:	19 db                	sbb    %ebx,%ebx
c0024991:	83 e3 02             	and    $0x2,%ebx
    ier |= IER_XMIT;

  /* Enable receive interrupt if we have room to store any
     characters we receive. */
  if (!input_full ())
c0024994:	e8 34 14 00 00       	call   c0025dcd <input_full>
    ier |= IER_RECV;
c0024999:	89 da                	mov    %ebx,%edx
c002499b:	83 ca 01             	or     $0x1,%edx
c002499e:	84 c0                	test   %al,%al
c00249a0:	0f 44 da             	cmove  %edx,%ebx
c00249a3:	ba f9 03 00 00       	mov    $0x3f9,%edx
c00249a8:	89 d8                	mov    %ebx,%eax
c00249aa:	ee                   	out    %al,(%dx)
  
  outb (IER_REG, ier);
}
c00249ab:	83 c4 28             	add    $0x28,%esp
c00249ae:	5b                   	pop    %ebx
c00249af:	c3                   	ret    

c00249b0 <serial_interrupt>:
}

/* Serial interrupt handler. */
static void
serial_interrupt (struct intr_frame *f UNUSED) 
{
c00249b0:	56                   	push   %esi
c00249b1:	53                   	push   %ebx
c00249b2:	83 ec 14             	sub    $0x14,%esp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00249b5:	ba fa 03 00 00       	mov    $0x3fa,%edx
c00249ba:	ec                   	in     (%dx),%al
c00249bb:	bb fd 03 00 00       	mov    $0x3fd,%ebx
c00249c0:	be f8 03 00 00       	mov    $0x3f8,%esi
c00249c5:	eb 0e                	jmp    c00249d5 <serial_interrupt+0x25>
c00249c7:	89 f2                	mov    %esi,%edx
c00249c9:	ec                   	in     (%dx),%al
  inb (IIR_REG);

  /* As long as we have room to receive a byte, and the hardware
     has a byte for us, receive a byte.  */
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
    input_putc (inb (RBR_REG));
c00249ca:	0f b6 c0             	movzbl %al,%eax
c00249cd:	89 04 24             	mov    %eax,(%esp)
c00249d0:	e8 33 13 00 00       	call   c0025d08 <input_putc>
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
c00249d5:	e8 f3 13 00 00       	call   c0025dcd <input_full>
c00249da:	84 c0                	test   %al,%al
c00249dc:	74 0c                	je     c00249ea <serial_interrupt+0x3a>
c00249de:	bb fd 03 00 00       	mov    $0x3fd,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00249e3:	be f8 03 00 00       	mov    $0x3f8,%esi
c00249e8:	eb 18                	jmp    c0024a02 <serial_interrupt+0x52>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00249ea:	89 da                	mov    %ebx,%edx
c00249ec:	ec                   	in     (%dx),%al
c00249ed:	a8 01                	test   $0x1,%al
c00249ef:	75 d6                	jne    c00249c7 <serial_interrupt+0x17>
c00249f1:	eb eb                	jmp    c00249de <serial_interrupt+0x2e>

  /* As long as we have a byte to transmit, and the hardware is
     ready to accept a byte for transmission, transmit a byte. */
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
    outb (THR_REG, intq_getc (&txq));
c00249f3:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c00249fa:	e8 70 16 00 00       	call   c002606f <intq_getc>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00249ff:	89 f2                	mov    %esi,%edx
c0024a01:	ee                   	out    %al,(%dx)
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
c0024a02:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a09:	e8 38 14 00 00       	call   c0025e46 <intq_empty>
c0024a0e:	84 c0                	test   %al,%al
c0024a10:	75 07                	jne    c0024a19 <serial_interrupt+0x69>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a12:	89 da                	mov    %ebx,%edx
c0024a14:	ec                   	in     (%dx),%al
c0024a15:	a8 20                	test   $0x20,%al
c0024a17:	75 da                	jne    c00249f3 <serial_interrupt+0x43>

  /* Update interrupt enable register based on queue status. */
  write_ier ();
c0024a19:	e8 2a ff ff ff       	call   c0024948 <write_ier>
}
c0024a1e:	83 c4 14             	add    $0x14,%esp
c0024a21:	5b                   	pop    %ebx
c0024a22:	5e                   	pop    %esi
c0024a23:	c3                   	ret    

c0024a24 <putc_poll>:
{
c0024a24:	53                   	push   %ebx
c0024a25:	83 ec 28             	sub    $0x28,%esp
c0024a28:	89 c3                	mov    %eax,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0024a2a:	e8 25 cf ff ff       	call   c0021954 <intr_get_level>
c0024a2f:	85 c0                	test   %eax,%eax
c0024a31:	74 2c                	je     c0024a5f <putc_poll+0x3b>
c0024a33:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0024a3a:	c0 
c0024a3b:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024a42:	c0 
c0024a43:	c7 44 24 08 3a d4 02 	movl   $0xc002d43a,0x8(%esp)
c0024a4a:	c0 
c0024a4b:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c0024a52:	00 
c0024a53:	c7 04 24 cb ed 02 c0 	movl   $0xc002edcb,(%esp)
c0024a5a:	e8 04 3f 00 00       	call   c0028963 <debug_panic>
c0024a5f:	ba fd 03 00 00       	mov    $0x3fd,%edx
c0024a64:	ec                   	in     (%dx),%al
  while ((inb (LSR_REG) & LSR_THRE) == 0)
c0024a65:	a8 20                	test   $0x20,%al
c0024a67:	74 fb                	je     c0024a64 <putc_poll+0x40>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a69:	ba f8 03 00 00       	mov    $0x3f8,%edx
c0024a6e:	89 d8                	mov    %ebx,%eax
c0024a70:	ee                   	out    %al,(%dx)
}
c0024a71:	83 c4 28             	add    $0x28,%esp
c0024a74:	5b                   	pop    %ebx
c0024a75:	c3                   	ret    

c0024a76 <serial_init_queue>:
{
c0024a76:	53                   	push   %ebx
c0024a77:	83 ec 28             	sub    $0x28,%esp
  if (mode == UNINIT)
c0024a7a:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c0024a81:	75 05                	jne    c0024a88 <serial_init_queue+0x12>
    init_poll ();
c0024a83:	e8 38 fe ff ff       	call   c00248c0 <init_poll>
  ASSERT (mode == POLL);
c0024a88:	83 3d 14 78 03 c0 01 	cmpl   $0x1,0xc0037814
c0024a8f:	74 2c                	je     c0024abd <serial_init_queue+0x47>
c0024a91:	c7 44 24 10 e2 ed 02 	movl   $0xc002ede2,0x10(%esp)
c0024a98:	c0 
c0024a99:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024aa0:	c0 
c0024aa1:	c7 44 24 08 58 d4 02 	movl   $0xc002d458,0x8(%esp)
c0024aa8:	c0 
c0024aa9:	c7 44 24 04 58 00 00 	movl   $0x58,0x4(%esp)
c0024ab0:	00 
c0024ab1:	c7 04 24 cb ed 02 c0 	movl   $0xc002edcb,(%esp)
c0024ab8:	e8 a6 3e 00 00       	call   c0028963 <debug_panic>
  intr_register_ext (0x20 + 4, serial_interrupt, "serial");
c0024abd:	c7 44 24 08 ef ed 02 	movl   $0xc002edef,0x8(%esp)
c0024ac4:	c0 
c0024ac5:	c7 44 24 04 b0 49 02 	movl   $0xc00249b0,0x4(%esp)
c0024acc:	c0 
c0024acd:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
c0024ad4:	e8 6a d0 ff ff       	call   c0021b43 <intr_register_ext>
  mode = QUEUE;
c0024ad9:	c7 05 14 78 03 c0 02 	movl   $0x2,0xc0037814
c0024ae0:	00 00 00 
  old_level = intr_disable ();
c0024ae3:	e8 b7 ce ff ff       	call   c002199f <intr_disable>
c0024ae8:	89 c3                	mov    %eax,%ebx
  write_ier ();
c0024aea:	e8 59 fe ff ff       	call   c0024948 <write_ier>
  intr_set_level (old_level);
c0024aef:	89 1c 24             	mov    %ebx,(%esp)
c0024af2:	e8 af ce ff ff       	call   c00219a6 <intr_set_level>
}
c0024af7:	83 c4 28             	add    $0x28,%esp
c0024afa:	5b                   	pop    %ebx
c0024afb:	c3                   	ret    

c0024afc <serial_putc>:
{
c0024afc:	56                   	push   %esi
c0024afd:	53                   	push   %ebx
c0024afe:	83 ec 14             	sub    $0x14,%esp
c0024b01:	8b 74 24 20          	mov    0x20(%esp),%esi
  enum intr_level old_level = intr_disable ();
c0024b05:	e8 95 ce ff ff       	call   c002199f <intr_disable>
c0024b0a:	89 c3                	mov    %eax,%ebx
  if (mode != QUEUE)
c0024b0c:	8b 15 14 78 03 c0    	mov    0xc0037814,%edx
c0024b12:	83 fa 02             	cmp    $0x2,%edx
c0024b15:	74 15                	je     c0024b2c <serial_putc+0x30>
      if (mode == UNINIT)
c0024b17:	85 d2                	test   %edx,%edx
c0024b19:	75 05                	jne    c0024b20 <serial_putc+0x24>
        init_poll ();
c0024b1b:	e8 a0 fd ff ff       	call   c00248c0 <init_poll>
      putc_poll (byte); 
c0024b20:	89 f0                	mov    %esi,%eax
c0024b22:	0f b6 c0             	movzbl %al,%eax
c0024b25:	e8 fa fe ff ff       	call   c0024a24 <putc_poll>
c0024b2a:	eb 42                	jmp    c0024b6e <serial_putc+0x72>
      if (old_level == INTR_OFF && intq_full (&txq)) 
c0024b2c:	85 c0                	test   %eax,%eax
c0024b2e:	75 24                	jne    c0024b54 <serial_putc+0x58>
c0024b30:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b37:	e8 55 13 00 00       	call   c0025e91 <intq_full>
c0024b3c:	84 c0                	test   %al,%al
c0024b3e:	74 14                	je     c0024b54 <serial_putc+0x58>
          putc_poll (intq_getc (&txq)); 
c0024b40:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b47:	e8 23 15 00 00       	call   c002606f <intq_getc>
c0024b4c:	0f b6 c0             	movzbl %al,%eax
c0024b4f:	e8 d0 fe ff ff       	call   c0024a24 <putc_poll>
      intq_putc (&txq, byte); 
c0024b54:	89 f0                	mov    %esi,%eax
c0024b56:	0f b6 f0             	movzbl %al,%esi
c0024b59:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024b5d:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b64:	e8 d2 15 00 00       	call   c002613b <intq_putc>
      write_ier ();
c0024b69:	e8 da fd ff ff       	call   c0024948 <write_ier>
  intr_set_level (old_level);
c0024b6e:	89 1c 24             	mov    %ebx,(%esp)
c0024b71:	e8 30 ce ff ff       	call   c00219a6 <intr_set_level>
}
c0024b76:	83 c4 14             	add    $0x14,%esp
c0024b79:	5b                   	pop    %ebx
c0024b7a:	5e                   	pop    %esi
c0024b7b:	c3                   	ret    

c0024b7c <serial_flush>:
{
c0024b7c:	53                   	push   %ebx
c0024b7d:	83 ec 18             	sub    $0x18,%esp
  enum intr_level old_level = intr_disable ();
c0024b80:	e8 1a ce ff ff       	call   c002199f <intr_disable>
c0024b85:	89 c3                	mov    %eax,%ebx
  while (!intq_empty (&txq))
c0024b87:	eb 14                	jmp    c0024b9d <serial_flush+0x21>
    putc_poll (intq_getc (&txq));
c0024b89:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b90:	e8 da 14 00 00       	call   c002606f <intq_getc>
c0024b95:	0f b6 c0             	movzbl %al,%eax
c0024b98:	e8 87 fe ff ff       	call   c0024a24 <putc_poll>
  while (!intq_empty (&txq))
c0024b9d:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024ba4:	e8 9d 12 00 00       	call   c0025e46 <intq_empty>
c0024ba9:	84 c0                	test   %al,%al
c0024bab:	74 dc                	je     c0024b89 <serial_flush+0xd>
  intr_set_level (old_level);
c0024bad:	89 1c 24             	mov    %ebx,(%esp)
c0024bb0:	e8 f1 cd ff ff       	call   c00219a6 <intr_set_level>
}
c0024bb5:	83 c4 18             	add    $0x18,%esp
c0024bb8:	5b                   	pop    %ebx
c0024bb9:	c3                   	ret    

c0024bba <serial_notify>:
{
c0024bba:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0024bbd:	e8 92 cd ff ff       	call   c0021954 <intr_get_level>
c0024bc2:	85 c0                	test   %eax,%eax
c0024bc4:	74 2c                	je     c0024bf2 <serial_notify+0x38>
c0024bc6:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0024bcd:	c0 
c0024bce:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024bd5:	c0 
c0024bd6:	c7 44 24 08 2c d4 02 	movl   $0xc002d42c,0x8(%esp)
c0024bdd:	c0 
c0024bde:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
c0024be5:	00 
c0024be6:	c7 04 24 cb ed 02 c0 	movl   $0xc002edcb,(%esp)
c0024bed:	e8 71 3d 00 00       	call   c0028963 <debug_panic>
  if (mode == QUEUE)
c0024bf2:	83 3d 14 78 03 c0 02 	cmpl   $0x2,0xc0037814
c0024bf9:	75 05                	jne    c0024c00 <serial_notify+0x46>
    write_ier ();
c0024bfb:	e8 48 fd ff ff       	call   c0024948 <write_ier>
}
c0024c00:	83 c4 2c             	add    $0x2c,%esp
c0024c03:	c3                   	ret    

c0024c04 <check_sector>:
/* Verifies that SECTOR is a valid offset within BLOCK.
   Panics if not. */
static void
check_sector (struct block *block, block_sector_t sector)
{
  if (sector >= block->size)
c0024c04:	8b 48 1c             	mov    0x1c(%eax),%ecx
c0024c07:	39 d1                	cmp    %edx,%ecx
c0024c09:	77 36                	ja     c0024c41 <check_sector+0x3d>
{
c0024c0b:	83 ec 2c             	sub    $0x2c,%esp
    {
      /* We do not use ASSERT because we want to panic here
         regardless of whether NDEBUG is defined. */
      PANIC ("Access past end of device %s (sector=%"PRDSNu", "
c0024c0e:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024c12:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024c16:	83 c0 08             	add    $0x8,%eax
c0024c19:	89 44 24 10          	mov    %eax,0x10(%esp)
c0024c1d:	c7 44 24 0c f8 ed 02 	movl   $0xc002edf8,0xc(%esp)
c0024c24:	c0 
c0024c25:	c7 44 24 08 87 d4 02 	movl   $0xc002d487,0x8(%esp)
c0024c2c:	c0 
c0024c2d:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
c0024c34:	00 
c0024c35:	c7 04 24 86 ee 02 c0 	movl   $0xc002ee86,(%esp)
c0024c3c:	e8 22 3d 00 00       	call   c0028963 <debug_panic>
c0024c41:	f3 c3                	repz ret 

c0024c43 <block_type_name>:
{
c0024c43:	83 ec 2c             	sub    $0x2c,%esp
c0024c46:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (type < BLOCK_CNT);
c0024c4a:	83 f8 05             	cmp    $0x5,%eax
c0024c4d:	76 2c                	jbe    c0024c7b <block_type_name+0x38>
c0024c4f:	c7 44 24 10 9c ee 02 	movl   $0xc002ee9c,0x10(%esp)
c0024c56:	c0 
c0024c57:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024c5e:	c0 
c0024c5f:	c7 44 24 08 cc d4 02 	movl   $0xc002d4cc,0x8(%esp)
c0024c66:	c0 
c0024c67:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0024c6e:	00 
c0024c6f:	c7 04 24 86 ee 02 c0 	movl   $0xc002ee86,(%esp)
c0024c76:	e8 e8 3c 00 00       	call   c0028963 <debug_panic>
  return block_type_names[type];
c0024c7b:	8b 04 85 b4 d4 02 c0 	mov    -0x3ffd2b4c(,%eax,4),%eax
}
c0024c82:	83 c4 2c             	add    $0x2c,%esp
c0024c85:	c3                   	ret    

c0024c86 <block_get_role>:
{
c0024c86:	83 ec 2c             	sub    $0x2c,%esp
c0024c89:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024c8d:	83 f8 03             	cmp    $0x3,%eax
c0024c90:	76 2c                	jbe    c0024cbe <block_get_role+0x38>
c0024c92:	c7 44 24 10 ad ee 02 	movl   $0xc002eead,0x10(%esp)
c0024c99:	c0 
c0024c9a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024ca1:	c0 
c0024ca2:	c7 44 24 08 a3 d4 02 	movl   $0xc002d4a3,0x8(%esp)
c0024ca9:	c0 
c0024caa:	c7 44 24 04 38 00 00 	movl   $0x38,0x4(%esp)
c0024cb1:	00 
c0024cb2:	c7 04 24 86 ee 02 c0 	movl   $0xc002ee86,(%esp)
c0024cb9:	e8 a5 3c 00 00       	call   c0028963 <debug_panic>
  return block_by_role[role];
c0024cbe:	8b 04 85 18 78 03 c0 	mov    -0x3ffc87e8(,%eax,4),%eax
}
c0024cc5:	83 c4 2c             	add    $0x2c,%esp
c0024cc8:	c3                   	ret    

c0024cc9 <block_set_role>:
{
c0024cc9:	83 ec 2c             	sub    $0x2c,%esp
c0024ccc:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024cd0:	83 f8 03             	cmp    $0x3,%eax
c0024cd3:	76 2c                	jbe    c0024d01 <block_set_role+0x38>
c0024cd5:	c7 44 24 10 ad ee 02 	movl   $0xc002eead,0x10(%esp)
c0024cdc:	c0 
c0024cdd:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024ce4:	c0 
c0024ce5:	c7 44 24 08 94 d4 02 	movl   $0xc002d494,0x8(%esp)
c0024cec:	c0 
c0024ced:	c7 44 24 04 40 00 00 	movl   $0x40,0x4(%esp)
c0024cf4:	00 
c0024cf5:	c7 04 24 86 ee 02 c0 	movl   $0xc002ee86,(%esp)
c0024cfc:	e8 62 3c 00 00       	call   c0028963 <debug_panic>
  block_by_role[role] = block;
c0024d01:	8b 54 24 34          	mov    0x34(%esp),%edx
c0024d05:	89 14 85 18 78 03 c0 	mov    %edx,-0x3ffc87e8(,%eax,4)
}
c0024d0c:	83 c4 2c             	add    $0x2c,%esp
c0024d0f:	c3                   	ret    

c0024d10 <block_first>:
{
c0024d10:	53                   	push   %ebx
c0024d11:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_begin (&all_blocks));
c0024d14:	c7 04 24 50 5a 03 c0 	movl   $0xc0035a50,(%esp)
c0024d1b:	e8 61 3d 00 00       	call   c0028a81 <list_begin>
c0024d20:	89 c3                	mov    %eax,%ebx
/* Returns the block device corresponding to LIST_ELEM, or a null
   pointer if LIST_ELEM is the list end of all_blocks. */
static struct block *
list_elem_to_block (struct list_elem *list_elem)
{
  return (list_elem != list_end (&all_blocks)
c0024d22:	c7 04 24 50 5a 03 c0 	movl   $0xc0035a50,(%esp)
c0024d29:	e8 e5 3d 00 00       	call   c0028b13 <list_end>
          ? list_entry (list_elem, struct block, list_elem)
          : NULL);
c0024d2e:	39 c3                	cmp    %eax,%ebx
c0024d30:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d35:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d38:	83 c4 18             	add    $0x18,%esp
c0024d3b:	5b                   	pop    %ebx
c0024d3c:	c3                   	ret    

c0024d3d <block_next>:
{
c0024d3d:	53                   	push   %ebx
c0024d3e:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_next (&block->list_elem));
c0024d41:	8b 44 24 20          	mov    0x20(%esp),%eax
c0024d45:	89 04 24             	mov    %eax,(%esp)
c0024d48:	e8 72 3d 00 00       	call   c0028abf <list_next>
c0024d4d:	89 c3                	mov    %eax,%ebx
  return (list_elem != list_end (&all_blocks)
c0024d4f:	c7 04 24 50 5a 03 c0 	movl   $0xc0035a50,(%esp)
c0024d56:	e8 b8 3d 00 00       	call   c0028b13 <list_end>
          : NULL);
c0024d5b:	39 c3                	cmp    %eax,%ebx
c0024d5d:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d62:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d65:	83 c4 18             	add    $0x18,%esp
c0024d68:	5b                   	pop    %ebx
c0024d69:	c3                   	ret    

c0024d6a <block_get_by_name>:
{
c0024d6a:	56                   	push   %esi
c0024d6b:	53                   	push   %ebx
c0024d6c:	83 ec 14             	sub    $0x14,%esp
c0024d6f:	8b 74 24 20          	mov    0x20(%esp),%esi
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024d73:	c7 04 24 50 5a 03 c0 	movl   $0xc0035a50,(%esp)
c0024d7a:	e8 02 3d 00 00       	call   c0028a81 <list_begin>
c0024d7f:	89 c3                	mov    %eax,%ebx
c0024d81:	eb 1d                	jmp    c0024da0 <block_get_by_name+0x36>
      if (!strcmp (name, block->name))
c0024d83:	8d 43 08             	lea    0x8(%ebx),%eax
c0024d86:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024d8a:	89 34 24             	mov    %esi,(%esp)
c0024d8d:	e8 e5 2c 00 00       	call   c0027a77 <strcmp>
c0024d92:	85 c0                	test   %eax,%eax
c0024d94:	74 21                	je     c0024db7 <block_get_by_name+0x4d>
       e = list_next (e))
c0024d96:	89 1c 24             	mov    %ebx,(%esp)
c0024d99:	e8 21 3d 00 00       	call   c0028abf <list_next>
c0024d9e:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024da0:	c7 04 24 50 5a 03 c0 	movl   $0xc0035a50,(%esp)
c0024da7:	e8 67 3d 00 00       	call   c0028b13 <list_end>
c0024dac:	39 d8                	cmp    %ebx,%eax
c0024dae:	75 d3                	jne    c0024d83 <block_get_by_name+0x19>
  return NULL;
c0024db0:	b8 00 00 00 00       	mov    $0x0,%eax
c0024db5:	eb 02                	jmp    c0024db9 <block_get_by_name+0x4f>
c0024db7:	89 d8                	mov    %ebx,%eax
}
c0024db9:	83 c4 14             	add    $0x14,%esp
c0024dbc:	5b                   	pop    %ebx
c0024dbd:	5e                   	pop    %esi
c0024dbe:	c3                   	ret    

c0024dbf <block_read>:
{
c0024dbf:	56                   	push   %esi
c0024dc0:	53                   	push   %ebx
c0024dc1:	83 ec 14             	sub    $0x14,%esp
c0024dc4:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0024dc8:	8b 74 24 24          	mov    0x24(%esp),%esi
  check_sector (block, sector);
c0024dcc:	89 f2                	mov    %esi,%edx
c0024dce:	89 d8                	mov    %ebx,%eax
c0024dd0:	e8 2f fe ff ff       	call   c0024c04 <check_sector>
  block->ops->read (block->aux, sector, buffer);
c0024dd5:	8b 43 20             	mov    0x20(%ebx),%eax
c0024dd8:	8b 54 24 28          	mov    0x28(%esp),%edx
c0024ddc:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024de0:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024de4:	8b 53 24             	mov    0x24(%ebx),%edx
c0024de7:	89 14 24             	mov    %edx,(%esp)
c0024dea:	ff 10                	call   *(%eax)
  block->read_cnt++;
c0024dec:	83 43 28 01          	addl   $0x1,0x28(%ebx)
c0024df0:	83 53 2c 00          	adcl   $0x0,0x2c(%ebx)
}
c0024df4:	83 c4 14             	add    $0x14,%esp
c0024df7:	5b                   	pop    %ebx
c0024df8:	5e                   	pop    %esi
c0024df9:	c3                   	ret    

c0024dfa <block_write>:
{
c0024dfa:	56                   	push   %esi
c0024dfb:	53                   	push   %ebx
c0024dfc:	83 ec 24             	sub    $0x24,%esp
c0024dff:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0024e03:	8b 74 24 34          	mov    0x34(%esp),%esi
  check_sector (block, sector);
c0024e07:	89 f2                	mov    %esi,%edx
c0024e09:	89 d8                	mov    %ebx,%eax
c0024e0b:	e8 f4 fd ff ff       	call   c0024c04 <check_sector>
  ASSERT (block->type != BLOCK_FOREIGN);
c0024e10:	83 7b 18 05          	cmpl   $0x5,0x18(%ebx)
c0024e14:	75 2c                	jne    c0024e42 <block_write+0x48>
c0024e16:	c7 44 24 10 c3 ee 02 	movl   $0xc002eec3,0x10(%esp)
c0024e1d:	c0 
c0024e1e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0024e25:	c0 
c0024e26:	c7 44 24 08 7b d4 02 	movl   $0xc002d47b,0x8(%esp)
c0024e2d:	c0 
c0024e2e:	c7 44 24 04 89 00 00 	movl   $0x89,0x4(%esp)
c0024e35:	00 
c0024e36:	c7 04 24 86 ee 02 c0 	movl   $0xc002ee86,(%esp)
c0024e3d:	e8 21 3b 00 00       	call   c0028963 <debug_panic>
  block->ops->write (block->aux, sector, buffer);
c0024e42:	8b 43 20             	mov    0x20(%ebx),%eax
c0024e45:	8b 54 24 38          	mov    0x38(%esp),%edx
c0024e49:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024e4d:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024e51:	8b 53 24             	mov    0x24(%ebx),%edx
c0024e54:	89 14 24             	mov    %edx,(%esp)
c0024e57:	ff 50 04             	call   *0x4(%eax)
  block->write_cnt++;
c0024e5a:	83 43 30 01          	addl   $0x1,0x30(%ebx)
c0024e5e:	83 53 34 00          	adcl   $0x0,0x34(%ebx)
}
c0024e62:	83 c4 24             	add    $0x24,%esp
c0024e65:	5b                   	pop    %ebx
c0024e66:	5e                   	pop    %esi
c0024e67:	c3                   	ret    

c0024e68 <block_size>:
  return block->size;
c0024e68:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e6c:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0024e6f:	c3                   	ret    

c0024e70 <block_name>:
  return block->name;
c0024e70:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e74:	83 c0 08             	add    $0x8,%eax
}
c0024e77:	c3                   	ret    

c0024e78 <block_type>:
  return block->type;
c0024e78:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e7c:	8b 40 18             	mov    0x18(%eax),%eax
}
c0024e7f:	c3                   	ret    

c0024e80 <block_print_stats>:
{
c0024e80:	56                   	push   %esi
c0024e81:	53                   	push   %ebx
c0024e82:	83 ec 24             	sub    $0x24,%esp
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024e85:	be 00 00 00 00       	mov    $0x0,%esi
      struct block *block = block_by_role[i];
c0024e8a:	8b 1c b5 18 78 03 c0 	mov    -0x3ffc87e8(,%esi,4),%ebx
      if (block != NULL)
c0024e91:	85 db                	test   %ebx,%ebx
c0024e93:	74 3e                	je     c0024ed3 <block_print_stats+0x53>
          printf ("%s (%s): %llu reads, %llu writes\n",
c0024e95:	8b 43 18             	mov    0x18(%ebx),%eax
c0024e98:	89 04 24             	mov    %eax,(%esp)
c0024e9b:	e8 a3 fd ff ff       	call   c0024c43 <block_type_name>
c0024ea0:	8b 53 30             	mov    0x30(%ebx),%edx
c0024ea3:	8b 4b 34             	mov    0x34(%ebx),%ecx
c0024ea6:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024eaa:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024eae:	8b 53 28             	mov    0x28(%ebx),%edx
c0024eb1:	8b 4b 2c             	mov    0x2c(%ebx),%ecx
c0024eb4:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0024eb8:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0024ebc:	89 44 24 08          	mov    %eax,0x8(%esp)
c0024ec0:	83 c3 08             	add    $0x8,%ebx
c0024ec3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024ec7:	c7 04 24 2c ee 02 c0 	movl   $0xc002ee2c,(%esp)
c0024ece:	e8 3b 1c 00 00       	call   c0026b0e <printf>
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024ed3:	83 c6 01             	add    $0x1,%esi
c0024ed6:	83 fe 04             	cmp    $0x4,%esi
c0024ed9:	75 af                	jne    c0024e8a <block_print_stats+0xa>
}
c0024edb:	83 c4 24             	add    $0x24,%esp
c0024ede:	5b                   	pop    %ebx
c0024edf:	5e                   	pop    %esi
c0024ee0:	c3                   	ret    

c0024ee1 <block_register>:
{
c0024ee1:	55                   	push   %ebp
c0024ee2:	57                   	push   %edi
c0024ee3:	56                   	push   %esi
c0024ee4:	53                   	push   %ebx
c0024ee5:	83 ec 1c             	sub    $0x1c,%esp
c0024ee8:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0024eec:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
  struct block *block = malloc (sizeof *block);
c0024ef0:	c7 04 24 38 00 00 00 	movl   $0x38,(%esp)
c0024ef7:	e8 08 eb ff ff       	call   c0023a04 <malloc>
c0024efc:	89 c6                	mov    %eax,%esi
  if (block == NULL)
c0024efe:	85 c0                	test   %eax,%eax
c0024f00:	75 24                	jne    c0024f26 <block_register+0x45>
    PANIC ("Failed to allocate memory for block device descriptor");
c0024f02:	c7 44 24 0c 50 ee 02 	movl   $0xc002ee50,0xc(%esp)
c0024f09:	c0 
c0024f0a:	c7 44 24 08 6c d4 02 	movl   $0xc002d46c,0x8(%esp)
c0024f11:	c0 
c0024f12:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0024f19:	00 
c0024f1a:	c7 04 24 86 ee 02 c0 	movl   $0xc002ee86,(%esp)
c0024f21:	e8 3d 3a 00 00       	call   c0028963 <debug_panic>
  list_push_back (&all_blocks, &block->list_elem);
c0024f26:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f2a:	c7 04 24 50 5a 03 c0 	movl   $0xc0035a50,(%esp)
c0024f31:	e8 7b 40 00 00       	call   c0028fb1 <list_push_back>
  strlcpy (block->name, name, sizeof block->name);
c0024f36:	8d 6e 08             	lea    0x8(%esi),%ebp
c0024f39:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c0024f40:	00 
c0024f41:	8b 44 24 30          	mov    0x30(%esp),%eax
c0024f45:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f49:	89 2c 24             	mov    %ebp,(%esp)
c0024f4c:	e8 25 30 00 00       	call   c0027f76 <strlcpy>
  block->type = type;
c0024f51:	8b 44 24 34          	mov    0x34(%esp),%eax
c0024f55:	89 46 18             	mov    %eax,0x18(%esi)
  block->size = size;
c0024f58:	89 5e 1c             	mov    %ebx,0x1c(%esi)
  block->ops = ops;
c0024f5b:	8b 44 24 40          	mov    0x40(%esp),%eax
c0024f5f:	89 46 20             	mov    %eax,0x20(%esi)
  block->aux = aux;
c0024f62:	8b 44 24 44          	mov    0x44(%esp),%eax
c0024f66:	89 46 24             	mov    %eax,0x24(%esi)
  block->read_cnt = 0;
c0024f69:	c7 46 28 00 00 00 00 	movl   $0x0,0x28(%esi)
c0024f70:	c7 46 2c 00 00 00 00 	movl   $0x0,0x2c(%esi)
  block->write_cnt = 0;
c0024f77:	c7 46 30 00 00 00 00 	movl   $0x0,0x30(%esi)
c0024f7e:	c7 46 34 00 00 00 00 	movl   $0x0,0x34(%esi)
  printf ("%s: %'"PRDSNu" sectors (", block->name, block->size);
c0024f85:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0024f89:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0024f8d:	c7 04 24 e0 ee 02 c0 	movl   $0xc002eee0,(%esp)
c0024f94:	e8 75 1b 00 00       	call   c0026b0e <printf>
  print_human_readable_size ((uint64_t) block->size * BLOCK_SECTOR_SIZE);
c0024f99:	8b 4e 1c             	mov    0x1c(%esi),%ecx
c0024f9c:	bb 00 00 00 00       	mov    $0x0,%ebx
c0024fa1:	0f a4 cb 09          	shld   $0x9,%ecx,%ebx
c0024fa5:	c1 e1 09             	shl    $0x9,%ecx
c0024fa8:	89 0c 24             	mov    %ecx,(%esp)
c0024fab:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024faf:	e8 25 24 00 00       	call   c00273d9 <print_human_readable_size>
  printf (")");
c0024fb4:	c7 04 24 29 00 00 00 	movl   $0x29,(%esp)
c0024fbb:	e8 3c 57 00 00       	call   c002a6fc <putchar>
  if (extra_info != NULL)
c0024fc0:	85 ff                	test   %edi,%edi
c0024fc2:	74 10                	je     c0024fd4 <block_register+0xf3>
    printf (", %s", extra_info);
c0024fc4:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0024fc8:	c7 04 24 f2 ee 02 c0 	movl   $0xc002eef2,(%esp)
c0024fcf:	e8 3a 1b 00 00       	call   c0026b0e <printf>
  printf ("\n");
c0024fd4:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0024fdb:	e8 1c 57 00 00       	call   c002a6fc <putchar>
}
c0024fe0:	89 f0                	mov    %esi,%eax
c0024fe2:	83 c4 1c             	add    $0x1c,%esp
c0024fe5:	5b                   	pop    %ebx
c0024fe6:	5e                   	pop    %esi
c0024fe7:	5f                   	pop    %edi
c0024fe8:	5d                   	pop    %ebp
c0024fe9:	c3                   	ret    

c0024fea <partition_read>:

/* Reads sector SECTOR from partition P into BUFFER, which must
   have room for BLOCK_SECTOR_SIZE bytes. */
static void
partition_read (void *p_, block_sector_t sector, void *buffer)
{
c0024fea:	83 ec 1c             	sub    $0x1c,%esp
c0024fed:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_read (p->block, p->start + sector, buffer);
c0024ff1:	8b 54 24 28          	mov    0x28(%esp),%edx
c0024ff5:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024ff9:	8b 54 24 24          	mov    0x24(%esp),%edx
c0024ffd:	03 50 04             	add    0x4(%eax),%edx
c0025000:	89 54 24 04          	mov    %edx,0x4(%esp)
c0025004:	8b 00                	mov    (%eax),%eax
c0025006:	89 04 24             	mov    %eax,(%esp)
c0025009:	e8 b1 fd ff ff       	call   c0024dbf <block_read>
}
c002500e:	83 c4 1c             	add    $0x1c,%esp
c0025011:	c3                   	ret    

c0025012 <read_partition_table>:
{
c0025012:	55                   	push   %ebp
c0025013:	57                   	push   %edi
c0025014:	56                   	push   %esi
c0025015:	53                   	push   %ebx
c0025016:	81 ec dc 00 00 00    	sub    $0xdc,%esp
c002501c:	89 c5                	mov    %eax,%ebp
c002501e:	89 d6                	mov    %edx,%esi
c0025020:	89 4c 24 20          	mov    %ecx,0x20(%esp)
  if (sector >= block_size (block))
c0025024:	89 04 24             	mov    %eax,(%esp)
c0025027:	e8 3c fe ff ff       	call   c0024e68 <block_size>
c002502c:	39 f0                	cmp    %esi,%eax
c002502e:	77 21                	ja     c0025051 <read_partition_table+0x3f>
      printf ("%s: Partition table at sector %"PRDSNu" past end of device.\n",
c0025030:	89 2c 24             	mov    %ebp,(%esp)
c0025033:	e8 38 fe ff ff       	call   c0024e70 <block_name>
c0025038:	89 74 24 08          	mov    %esi,0x8(%esp)
c002503c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025040:	c7 04 24 a4 f3 02 c0 	movl   $0xc002f3a4,(%esp)
c0025047:	e8 c2 1a 00 00       	call   c0026b0e <printf>
      return;
c002504c:	e9 3b 03 00 00       	jmp    c002538c <read_partition_table+0x37a>
  pt = malloc (sizeof *pt);
c0025051:	c7 04 24 00 02 00 00 	movl   $0x200,(%esp)
c0025058:	e8 a7 e9 ff ff       	call   c0023a04 <malloc>
c002505d:	89 c7                	mov    %eax,%edi
  if (pt == NULL)
c002505f:	85 c0                	test   %eax,%eax
c0025061:	75 24                	jne    c0025087 <read_partition_table+0x75>
    PANIC ("Failed to allocate memory for partition table.");
c0025063:	c7 44 24 0c dc f3 02 	movl   $0xc002f3dc,0xc(%esp)
c002506a:	c0 
c002506b:	c7 44 24 08 f0 d8 02 	movl   $0xc002d8f0,0x8(%esp)
c0025072:	c0 
c0025073:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c002507a:	00 
c002507b:	c7 04 24 13 ef 02 c0 	movl   $0xc002ef13,(%esp)
c0025082:	e8 dc 38 00 00       	call   c0028963 <debug_panic>
  block_read (block, 0, pt);
c0025087:	89 44 24 08          	mov    %eax,0x8(%esp)
c002508b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025092:	00 
c0025093:	89 2c 24             	mov    %ebp,(%esp)
c0025096:	e8 24 fd ff ff       	call   c0024dbf <block_read>
  if (pt->signature != 0xaa55)
c002509b:	66 81 bf fe 01 00 00 	cmpw   $0xaa55,0x1fe(%edi)
c00250a2:	55 aa 
c00250a4:	74 4a                	je     c00250f0 <read_partition_table+0xde>
      if (primary_extended_sector == 0)
c00250a6:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c00250ab:	75 1a                	jne    c00250c7 <read_partition_table+0xb5>
        printf ("%s: Invalid partition table signature\n", block_name (block));
c00250ad:	89 2c 24             	mov    %ebp,(%esp)
c00250b0:	e8 bb fd ff ff       	call   c0024e70 <block_name>
c00250b5:	89 44 24 04          	mov    %eax,0x4(%esp)
c00250b9:	c7 04 24 0c f4 02 c0 	movl   $0xc002f40c,(%esp)
c00250c0:	e8 49 1a 00 00       	call   c0026b0e <printf>
c00250c5:	eb 1c                	jmp    c00250e3 <read_partition_table+0xd1>
        printf ("%s: Invalid extended partition table in sector %"PRDSNu"\n",
c00250c7:	89 2c 24             	mov    %ebp,(%esp)
c00250ca:	e8 a1 fd ff ff       	call   c0024e70 <block_name>
c00250cf:	89 74 24 08          	mov    %esi,0x8(%esp)
c00250d3:	89 44 24 04          	mov    %eax,0x4(%esp)
c00250d7:	c7 04 24 34 f4 02 c0 	movl   $0xc002f434,(%esp)
c00250de:	e8 2b 1a 00 00       	call   c0026b0e <printf>
      free (pt);
c00250e3:	89 3c 24             	mov    %edi,(%esp)
c00250e6:	e8 a0 ea ff ff       	call   c0023b8b <free>
      return;
c00250eb:	e9 9c 02 00 00       	jmp    c002538c <read_partition_table+0x37a>
c00250f0:	89 fb                	mov    %edi,%ebx
  if (pt->signature != 0xaa55)
c00250f2:	b8 04 00 00 00       	mov    $0x4,%eax
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c00250f7:	89 7c 24 28          	mov    %edi,0x28(%esp)
c00250fb:	89 74 24 24          	mov    %esi,0x24(%esp)
c00250ff:	89 c6                	mov    %eax,%esi
c0025101:	89 df                	mov    %ebx,%edi
      if (e->size == 0 || e->type == 0)
c0025103:	83 bb ca 01 00 00 00 	cmpl   $0x0,0x1ca(%ebx)
c002510a:	0f 84 64 02 00 00    	je     c0025374 <read_partition_table+0x362>
c0025110:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c0025117:	84 c0                	test   %al,%al
c0025119:	0f 84 55 02 00 00    	je     c0025374 <read_partition_table+0x362>
               || e->type == 0x0f    /* Windows 98 extended partition. */
c002511f:	89 c2                	mov    %eax,%edx
c0025121:	83 e2 7f             	and    $0x7f,%edx
      else if (e->type == 0x05       /* Extended partition. */
c0025124:	80 fa 05             	cmp    $0x5,%dl
c0025127:	74 08                	je     c0025131 <read_partition_table+0x11f>
c0025129:	3c 0f                	cmp    $0xf,%al
c002512b:	74 04                	je     c0025131 <read_partition_table+0x11f>
               || e->type == 0xc5)   /* DR-DOS extended partition. */
c002512d:	3c c5                	cmp    $0xc5,%al
c002512f:	75 67                	jne    c0025198 <read_partition_table+0x186>
          printf ("%s: Extended partition in sector %"PRDSNu"\n",
c0025131:	89 2c 24             	mov    %ebp,(%esp)
c0025134:	e8 37 fd ff ff       	call   c0024e70 <block_name>
c0025139:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c002513d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0025141:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025145:	c7 04 24 68 f4 02 c0 	movl   $0xc002f468,(%esp)
c002514c:	e8 bd 19 00 00       	call   c0026b0e <printf>
          if (sector == 0)
c0025151:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0025156:	75 1e                	jne    c0025176 <read_partition_table+0x164>
            read_partition_table (block, e->offset, e->offset, part_nr);
c0025158:	8b 97 c6 01 00 00    	mov    0x1c6(%edi),%edx
c002515e:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c0025165:	89 04 24             	mov    %eax,(%esp)
c0025168:	89 d1                	mov    %edx,%ecx
c002516a:	89 e8                	mov    %ebp,%eax
c002516c:	e8 a1 fe ff ff       	call   c0025012 <read_partition_table>
c0025171:	e9 fe 01 00 00       	jmp    c0025374 <read_partition_table+0x362>
            read_partition_table (block, e->offset + primary_extended_sector,
c0025176:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c002517a:	89 ca                	mov    %ecx,%edx
c002517c:	03 97 c6 01 00 00    	add    0x1c6(%edi),%edx
c0025182:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c0025189:	89 04 24             	mov    %eax,(%esp)
c002518c:	89 e8                	mov    %ebp,%eax
c002518e:	e8 7f fe ff ff       	call   c0025012 <read_partition_table>
c0025193:	e9 dc 01 00 00       	jmp    c0025374 <read_partition_table+0x362>
          ++*part_nr;
c0025198:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c002519f:	8b 00                	mov    (%eax),%eax
c00251a1:	83 c0 01             	add    $0x1,%eax
c00251a4:	89 44 24 34          	mov    %eax,0x34(%esp)
c00251a8:	8b 8c 24 f0 00 00 00 	mov    0xf0(%esp),%ecx
c00251af:	89 01                	mov    %eax,(%ecx)
          found_partition (block, e->type, e->offset + sector,
c00251b1:	8b 83 ca 01 00 00    	mov    0x1ca(%ebx),%eax
c00251b7:	89 44 24 30          	mov    %eax,0x30(%esp)
c00251bb:	8b 44 24 24          	mov    0x24(%esp),%eax
c00251bf:	03 83 c6 01 00 00    	add    0x1c6(%ebx),%eax
c00251c5:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c00251c9:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c00251d0:	88 44 24 3b          	mov    %al,0x3b(%esp)
  if (start >= block_size (block))
c00251d4:	89 2c 24             	mov    %ebp,(%esp)
c00251d7:	e8 8c fc ff ff       	call   c0024e68 <block_size>
c00251dc:	39 44 24 2c          	cmp    %eax,0x2c(%esp)
c00251e0:	72 2d                	jb     c002520f <read_partition_table+0x1fd>
    printf ("%s%d: Partition starts past end of device (sector %"PRDSNu")\n",
c00251e2:	89 2c 24             	mov    %ebp,(%esp)
c00251e5:	e8 86 fc ff ff       	call   c0024e70 <block_name>
c00251ea:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c00251ee:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c00251f2:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c00251f6:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c00251fa:	89 44 24 04          	mov    %eax,0x4(%esp)
c00251fe:	c7 04 24 90 f4 02 c0 	movl   $0xc002f490,(%esp)
c0025205:	e8 04 19 00 00       	call   c0026b0e <printf>
c002520a:	e9 65 01 00 00       	jmp    c0025374 <read_partition_table+0x362>
  else if (start + size < start || start + size > block_size (block))
c002520f:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
c0025213:	03 7c 24 30          	add    0x30(%esp),%edi
c0025217:	72 0c                	jb     c0025225 <read_partition_table+0x213>
c0025219:	89 2c 24             	mov    %ebp,(%esp)
c002521c:	e8 47 fc ff ff       	call   c0024e68 <block_size>
c0025221:	39 c7                	cmp    %eax,%edi
c0025223:	76 3d                	jbe    c0025262 <read_partition_table+0x250>
    printf ("%s%d: Partition end (%"PRDSNu") past end of device (%"PRDSNu")\n",
c0025225:	89 2c 24             	mov    %ebp,(%esp)
c0025228:	e8 3b fc ff ff       	call   c0024e68 <block_size>
c002522d:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c0025231:	89 2c 24             	mov    %ebp,(%esp)
c0025234:	e8 37 fc ff ff       	call   c0024e70 <block_name>
c0025239:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002523d:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0025241:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025245:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025249:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002524d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025251:	c7 04 24 c8 f4 02 c0 	movl   $0xc002f4c8,(%esp)
c0025258:	e8 b1 18 00 00       	call   c0026b0e <printf>
c002525d:	e9 12 01 00 00       	jmp    c0025374 <read_partition_table+0x362>
      enum block_type type = (part_type == 0x20 ? BLOCK_KERNEL
c0025262:	c7 44 24 3c 00 00 00 	movl   $0x0,0x3c(%esp)
c0025269:	00 
c002526a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
c002526f:	3c 20                	cmp    $0x20,%al
c0025271:	74 28                	je     c002529b <read_partition_table+0x289>
c0025273:	c7 44 24 3c 01 00 00 	movl   $0x1,0x3c(%esp)
c002527a:	00 
c002527b:	3c 21                	cmp    $0x21,%al
c002527d:	74 1c                	je     c002529b <read_partition_table+0x289>
c002527f:	c7 44 24 3c 02 00 00 	movl   $0x2,0x3c(%esp)
c0025286:	00 
c0025287:	3c 22                	cmp    $0x22,%al
c0025289:	74 10                	je     c002529b <read_partition_table+0x289>
c002528b:	3c 23                	cmp    $0x23,%al
c002528d:	0f 95 c0             	setne  %al
c0025290:	0f b6 c0             	movzbl %al,%eax
c0025293:	8d 44 00 03          	lea    0x3(%eax,%eax,1),%eax
c0025297:	89 44 24 3c          	mov    %eax,0x3c(%esp)
      p = malloc (sizeof *p);
c002529b:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c00252a2:	e8 5d e7 ff ff       	call   c0023a04 <malloc>
c00252a7:	89 c7                	mov    %eax,%edi
      if (p == NULL)
c00252a9:	85 c0                	test   %eax,%eax
c00252ab:	75 24                	jne    c00252d1 <read_partition_table+0x2bf>
        PANIC ("Failed to allocate memory for partition descriptor");
c00252ad:	c7 44 24 0c fc f4 02 	movl   $0xc002f4fc,0xc(%esp)
c00252b4:	c0 
c00252b5:	c7 44 24 08 e0 d8 02 	movl   $0xc002d8e0,0x8(%esp)
c00252bc:	c0 
c00252bd:	c7 44 24 04 b1 00 00 	movl   $0xb1,0x4(%esp)
c00252c4:	00 
c00252c5:	c7 04 24 13 ef 02 c0 	movl   $0xc002ef13,(%esp)
c00252cc:	e8 92 36 00 00       	call   c0028963 <debug_panic>
      p->block = block;
c00252d1:	89 28                	mov    %ebp,(%eax)
      p->start = start;
c00252d3:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00252d7:	89 47 04             	mov    %eax,0x4(%edi)
      snprintf (name, sizeof name, "%s%d", block_name (block), part_nr);
c00252da:	89 2c 24             	mov    %ebp,(%esp)
c00252dd:	e8 8e fb ff ff       	call   c0024e70 <block_name>
c00252e2:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c00252e6:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c00252ea:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00252ee:	c7 44 24 08 2d ef 02 	movl   $0xc002ef2d,0x8(%esp)
c00252f5:	c0 
c00252f6:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c00252fd:	00 
c00252fe:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025302:	89 04 24             	mov    %eax,(%esp)
c0025305:	e8 05 1f 00 00       	call   c002720f <snprintf>
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c002530a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c002530f:	8b 14 85 e0 d4 02 c0 	mov    -0x3ffd2b20(,%eax,4),%edx
c0025316:	85 d2                	test   %edx,%edx
c0025318:	b9 0b ef 02 c0       	mov    $0xc002ef0b,%ecx
c002531d:	0f 44 d1             	cmove  %ecx,%edx
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025320:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025324:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0025328:	c7 44 24 08 32 ef 02 	movl   $0xc002ef32,0x8(%esp)
c002532f:	c0 
c0025330:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025337:	00 
c0025338:	8d 44 24 50          	lea    0x50(%esp),%eax
c002533c:	89 04 24             	mov    %eax,(%esp)
c002533f:	e8 cb 1e 00 00       	call   c002720f <snprintf>
      block_register (name, type, extra_info, size, &partition_operations, p);
c0025344:	89 7c 24 14          	mov    %edi,0x14(%esp)
c0025348:	c7 44 24 10 60 5a 03 	movl   $0xc0035a60,0x10(%esp)
c002534f:	c0 
c0025350:	8b 44 24 30          	mov    0x30(%esp),%eax
c0025354:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025358:	8d 44 24 50          	lea    0x50(%esp),%eax
c002535c:	89 44 24 08          	mov    %eax,0x8(%esp)
c0025360:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c0025364:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025368:	8d 44 24 40          	lea    0x40(%esp),%eax
c002536c:	89 04 24             	mov    %eax,(%esp)
c002536f:	e8 6d fb ff ff       	call   c0024ee1 <block_register>
c0025374:	83 c3 10             	add    $0x10,%ebx
  for (i = 0; i < sizeof pt->partitions / sizeof *pt->partitions; i++)
c0025377:	83 ee 01             	sub    $0x1,%esi
c002537a:	0f 85 81 fd ff ff    	jne    c0025101 <read_partition_table+0xef>
c0025380:	8b 7c 24 28          	mov    0x28(%esp),%edi
  free (pt);
c0025384:	89 3c 24             	mov    %edi,(%esp)
c0025387:	e8 ff e7 ff ff       	call   c0023b8b <free>
}
c002538c:	81 c4 dc 00 00 00    	add    $0xdc,%esp
c0025392:	5b                   	pop    %ebx
c0025393:	5e                   	pop    %esi
c0025394:	5f                   	pop    %edi
c0025395:	5d                   	pop    %ebp
c0025396:	c3                   	ret    

c0025397 <partition_write>:
/* Write sector SECTOR to partition P from BUFFER, which must
   contain BLOCK_SECTOR_SIZE bytes.  Returns after the block has
   acknowledged receiving the data. */
static void
partition_write (void *p_, block_sector_t sector, const void *buffer)
{
c0025397:	83 ec 1c             	sub    $0x1c,%esp
c002539a:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_write (p->block, p->start + sector, buffer);
c002539e:	8b 54 24 28          	mov    0x28(%esp),%edx
c00253a2:	89 54 24 08          	mov    %edx,0x8(%esp)
c00253a6:	8b 54 24 24          	mov    0x24(%esp),%edx
c00253aa:	03 50 04             	add    0x4(%eax),%edx
c00253ad:	89 54 24 04          	mov    %edx,0x4(%esp)
c00253b1:	8b 00                	mov    (%eax),%eax
c00253b3:	89 04 24             	mov    %eax,(%esp)
c00253b6:	e8 3f fa ff ff       	call   c0024dfa <block_write>
}
c00253bb:	83 c4 1c             	add    $0x1c,%esp
c00253be:	c3                   	ret    

c00253bf <partition_scan>:
{
c00253bf:	53                   	push   %ebx
c00253c0:	83 ec 28             	sub    $0x28,%esp
c00253c3:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  int part_nr = 0;
c00253c7:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c00253ce:	00 
  read_partition_table (block, 0, 0, &part_nr);
c00253cf:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c00253d3:	89 04 24             	mov    %eax,(%esp)
c00253d6:	b9 00 00 00 00       	mov    $0x0,%ecx
c00253db:	ba 00 00 00 00       	mov    $0x0,%edx
c00253e0:	89 d8                	mov    %ebx,%eax
c00253e2:	e8 2b fc ff ff       	call   c0025012 <read_partition_table>
  if (part_nr == 0)
c00253e7:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c00253ec:	75 18                	jne    c0025406 <partition_scan+0x47>
    printf ("%s: Device contains no partitions\n", block_name (block));
c00253ee:	89 1c 24             	mov    %ebx,(%esp)
c00253f1:	e8 7a fa ff ff       	call   c0024e70 <block_name>
c00253f6:	89 44 24 04          	mov    %eax,0x4(%esp)
c00253fa:	c7 04 24 30 f5 02 c0 	movl   $0xc002f530,(%esp)
c0025401:	e8 08 17 00 00       	call   c0026b0e <printf>
}
c0025406:	83 c4 28             	add    $0x28,%esp
c0025409:	5b                   	pop    %ebx
c002540a:	c3                   	ret    
c002540b:	90                   	nop
c002540c:	90                   	nop
c002540d:	90                   	nop
c002540e:	90                   	nop
c002540f:	90                   	nop

c0025410 <descramble_ata_string>:
/* Translates STRING, which consists of SIZE bytes in a funky
   format, into a null-terminated string in-place.  Drops
   trailing whitespace and null bytes.  Returns STRING.  */
static char *
descramble_ata_string (char *string, int size) 
{
c0025410:	57                   	push   %edi
c0025411:	56                   	push   %esi
c0025412:	53                   	push   %ebx
c0025413:	89 d7                	mov    %edx,%edi
  int i;

  /* Swap all pairs of bytes. */
  for (i = 0; i + 1 < size; i += 2)
c0025415:	83 fa 01             	cmp    $0x1,%edx
c0025418:	7e 1f                	jle    c0025439 <descramble_ata_string+0x29>
c002541a:	89 c1                	mov    %eax,%ecx
c002541c:	8d 5a fe             	lea    -0x2(%edx),%ebx
c002541f:	83 e3 fe             	and    $0xfffffffe,%ebx
c0025422:	8d 74 18 02          	lea    0x2(%eax,%ebx,1),%esi
    {
      char tmp = string[i];
c0025426:	0f b6 19             	movzbl (%ecx),%ebx
      string[i] = string[i + 1];
c0025429:	0f b6 51 01          	movzbl 0x1(%ecx),%edx
c002542d:	88 11                	mov    %dl,(%ecx)
      string[i + 1] = tmp;
c002542f:	88 59 01             	mov    %bl,0x1(%ecx)
c0025432:	83 c1 02             	add    $0x2,%ecx
  for (i = 0; i + 1 < size; i += 2)
c0025435:	39 f1                	cmp    %esi,%ecx
c0025437:	75 ed                	jne    c0025426 <descramble_ata_string+0x16>
    }

  /* Find the last non-white, non-null character. */
  for (size--; size > 0; size--)
c0025439:	8d 57 ff             	lea    -0x1(%edi),%edx
c002543c:	85 d2                	test   %edx,%edx
c002543e:	7e 24                	jle    c0025464 <descramble_ata_string+0x54>
    {
      int c = string[size - 1];
c0025440:	0f b6 4c 10 ff       	movzbl -0x1(%eax,%edx,1),%ecx
      if (c != '\0' && !isspace (c))
c0025445:	f6 c1 df             	test   $0xdf,%cl
c0025448:	74 15                	je     c002545f <descramble_ata_string+0x4f>
  return (c == ' ' || c == '\f' || c == '\n'
c002544a:	8d 59 f4             	lea    -0xc(%ecx),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c002544d:	80 fb 01             	cmp    $0x1,%bl
c0025450:	76 0d                	jbe    c002545f <descramble_ata_string+0x4f>
c0025452:	80 f9 0a             	cmp    $0xa,%cl
c0025455:	74 08                	je     c002545f <descramble_ata_string+0x4f>
c0025457:	83 e1 fd             	and    $0xfffffffd,%ecx
c002545a:	80 f9 09             	cmp    $0x9,%cl
c002545d:	75 05                	jne    c0025464 <descramble_ata_string+0x54>
  for (size--; size > 0; size--)
c002545f:	83 ea 01             	sub    $0x1,%edx
c0025462:	75 dc                	jne    c0025440 <descramble_ata_string+0x30>
        break; 
    }
  string[size] = '\0';
c0025464:	c6 04 10 00          	movb   $0x0,(%eax,%edx,1)

  return string;
}
c0025468:	5b                   	pop    %ebx
c0025469:	5e                   	pop    %esi
c002546a:	5f                   	pop    %edi
c002546b:	c3                   	ret    

c002546c <interrupt_handler>:
}

/* ATA interrupt handler. */
static void
interrupt_handler (struct intr_frame *f) 
{
c002546c:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c;

  for (c = channels; c < channels + CHANNEL_CNT; c++)
    if (f->vec_no == c->irq)
c002546f:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025473:	8b 40 30             	mov    0x30(%eax),%eax
c0025476:	0f b6 15 4a 78 03 c0 	movzbl 0xc003784a,%edx
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c002547d:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
    if (f->vec_no == c->irq)
c0025482:	39 d0                	cmp    %edx,%eax
c0025484:	75 3e                	jne    c00254c4 <interrupt_handler+0x58>
c0025486:	eb 0a                	jmp    c0025492 <interrupt_handler+0x26>
c0025488:	0f b6 51 0a          	movzbl 0xa(%ecx),%edx
c002548c:	39 c2                	cmp    %eax,%edx
c002548e:	75 34                	jne    c00254c4 <interrupt_handler+0x58>
c0025490:	eb 05                	jmp    c0025497 <interrupt_handler+0x2b>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c0025492:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
      {
        if (c->expecting_interrupt) 
c0025497:	80 79 30 00          	cmpb   $0x0,0x30(%ecx)
c002549b:	74 15                	je     c00254b2 <interrupt_handler+0x46>
          {
            inb (reg_status (c));               /* Acknowledge interrupt. */
c002549d:	0f b7 41 08          	movzwl 0x8(%ecx),%eax
c00254a1:	8d 50 07             	lea    0x7(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00254a4:	ec                   	in     (%dx),%al
            sema_up (&c->completion_wait);      /* Wake up waiter. */
c00254a5:	83 c1 34             	add    $0x34,%ecx
c00254a8:	89 0c 24             	mov    %ecx,(%esp)
c00254ab:	e8 77 d7 ff ff       	call   c0022c27 <sema_up>
c00254b0:	eb 41                	jmp    c00254f3 <interrupt_handler+0x87>
          }
        else
          printf ("%s: unexpected interrupt\n", c->name);
c00254b2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00254b6:	c7 04 24 53 f5 02 c0 	movl   $0xc002f553,(%esp)
c00254bd:	e8 4c 16 00 00       	call   c0026b0e <printf>
c00254c2:	eb 2f                	jmp    c00254f3 <interrupt_handler+0x87>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254c4:	83 c1 70             	add    $0x70,%ecx
c00254c7:	81 f9 20 79 03 c0    	cmp    $0xc0037920,%ecx
c00254cd:	72 b9                	jb     c0025488 <interrupt_handler+0x1c>
        return;
      }

  NOT_REACHED ();
c00254cf:	c7 44 24 0c f8 e5 02 	movl   $0xc002e5f8,0xc(%esp)
c00254d6:	c0 
c00254d7:	c7 44 24 08 4c d9 02 	movl   $0xc002d94c,0x8(%esp)
c00254de:	c0 
c00254df:	c7 44 24 04 0c 02 00 	movl   $0x20c,0x4(%esp)
c00254e6:	00 
c00254e7:	c7 04 24 6d f5 02 c0 	movl   $0xc002f56d,(%esp)
c00254ee:	e8 70 34 00 00       	call   c0028963 <debug_panic>
}
c00254f3:	83 c4 1c             	add    $0x1c,%esp
c00254f6:	c3                   	ret    

c00254f7 <wait_until_idle>:
{
c00254f7:	56                   	push   %esi
c00254f8:	53                   	push   %ebx
c00254f9:	83 ec 14             	sub    $0x14,%esp
c00254fc:	89 c6                	mov    %eax,%esi
      if ((inb (reg_status (d->channel)) & (STA_BSY | STA_DRQ)) == 0)
c00254fe:	8b 40 08             	mov    0x8(%eax),%eax
c0025501:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025505:	83 c2 07             	add    $0x7,%edx
c0025508:	ec                   	in     (%dx),%al
c0025509:	a8 88                	test   $0x88,%al
c002550b:	75 3c                	jne    c0025549 <wait_until_idle+0x52>
c002550d:	eb 55                	jmp    c0025564 <wait_until_idle+0x6d>
c002550f:	8b 46 08             	mov    0x8(%esi),%eax
c0025512:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025516:	83 c2 07             	add    $0x7,%edx
c0025519:	ec                   	in     (%dx),%al
c002551a:	a8 88                	test   $0x88,%al
c002551c:	74 46                	je     c0025564 <wait_until_idle+0x6d>
      timer_usleep (10);
c002551e:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025525:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002552c:	00 
c002552d:	e8 59 ee ff ff       	call   c002438b <timer_usleep>
  for (i = 0; i < 1000; i++) 
c0025532:	83 eb 01             	sub    $0x1,%ebx
c0025535:	75 d8                	jne    c002550f <wait_until_idle+0x18>
  printf ("%s: idle timeout\n", d->name);
c0025537:	89 74 24 04          	mov    %esi,0x4(%esp)
c002553b:	c7 04 24 81 f5 02 c0 	movl   $0xc002f581,(%esp)
c0025542:	e8 c7 15 00 00       	call   c0026b0e <printf>
c0025547:	eb 1b                	jmp    c0025564 <wait_until_idle+0x6d>
      timer_usleep (10);
c0025549:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025550:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025557:	00 
c0025558:	e8 2e ee ff ff       	call   c002438b <timer_usleep>
c002555d:	bb e7 03 00 00       	mov    $0x3e7,%ebx
c0025562:	eb ab                	jmp    c002550f <wait_until_idle+0x18>
}
c0025564:	83 c4 14             	add    $0x14,%esp
c0025567:	5b                   	pop    %ebx
c0025568:	5e                   	pop    %esi
c0025569:	c3                   	ret    

c002556a <select_device>:
{
c002556a:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c = d->channel;
c002556d:	8b 50 08             	mov    0x8(%eax),%edx
  if (d->dev_no == 1)
c0025570:	83 78 0c 01          	cmpl   $0x1,0xc(%eax)
  uint8_t dev = DEV_MBS;
c0025574:	b8 a0 ff ff ff       	mov    $0xffffffa0,%eax
c0025579:	b9 b0 ff ff ff       	mov    $0xffffffb0,%ecx
c002557e:	0f 44 c1             	cmove  %ecx,%eax
  outb (reg_device (c), dev);
c0025581:	0f b7 4a 08          	movzwl 0x8(%edx),%ecx
c0025585:	8d 51 06             	lea    0x6(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025588:	ee                   	out    %al,(%dx)
  inb (reg_alt_status (c));
c0025589:	8d 91 06 02 00 00    	lea    0x206(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002558f:	ec                   	in     (%dx),%al
  timer_nsleep (400);
c0025590:	c7 04 24 90 01 00 00 	movl   $0x190,(%esp)
c0025597:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002559e:	00 
c002559f:	e8 00 ee ff ff       	call   c00243a4 <timer_nsleep>
}
c00255a4:	83 c4 1c             	add    $0x1c,%esp
c00255a7:	c3                   	ret    

c00255a8 <check_device_type>:
{
c00255a8:	55                   	push   %ebp
c00255a9:	57                   	push   %edi
c00255aa:	56                   	push   %esi
c00255ab:	53                   	push   %ebx
c00255ac:	83 ec 0c             	sub    $0xc,%esp
c00255af:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c00255b1:	8b 70 08             	mov    0x8(%eax),%esi
  select_device (d);
c00255b4:	e8 b1 ff ff ff       	call   c002556a <select_device>
  error = inb (reg_error (c));
c00255b9:	0f b7 4e 08          	movzwl 0x8(%esi),%ecx
c00255bd:	8d 51 01             	lea    0x1(%ecx),%edx
c00255c0:	ec                   	in     (%dx),%al
c00255c1:	89 c6                	mov    %eax,%esi
  lbam = inb (reg_lbam (c));
c00255c3:	8d 51 04             	lea    0x4(%ecx),%edx
c00255c6:	ec                   	in     (%dx),%al
c00255c7:	89 c7                	mov    %eax,%edi
  lbah = inb (reg_lbah (c));
c00255c9:	8d 51 05             	lea    0x5(%ecx),%edx
c00255cc:	ec                   	in     (%dx),%al
c00255cd:	89 c5                	mov    %eax,%ebp
  status = inb (reg_status (c));
c00255cf:	8d 51 07             	lea    0x7(%ecx),%edx
c00255d2:	ec                   	in     (%dx),%al
  if ((error != 1 && (error != 0x81 || d->dev_no == 1))
c00255d3:	89 f1                	mov    %esi,%ecx
c00255d5:	80 f9 01             	cmp    $0x1,%cl
c00255d8:	74 0b                	je     c00255e5 <check_device_type+0x3d>
c00255da:	80 f9 81             	cmp    $0x81,%cl
c00255dd:	75 0e                	jne    c00255ed <check_device_type+0x45>
c00255df:	83 7b 0c 01          	cmpl   $0x1,0xc(%ebx)
c00255e3:	74 08                	je     c00255ed <check_device_type+0x45>
      || (status & STA_DRDY) == 0
c00255e5:	a8 40                	test   $0x40,%al
c00255e7:	74 04                	je     c00255ed <check_device_type+0x45>
      || (status & STA_BSY) != 0)
c00255e9:	84 c0                	test   %al,%al
c00255eb:	79 0d                	jns    c00255fa <check_device_type+0x52>
      d->is_ata = false;
c00255ed:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return error != 0x81;      
c00255f1:	89 f0                	mov    %esi,%eax
c00255f3:	3c 81                	cmp    $0x81,%al
c00255f5:	0f 95 c0             	setne  %al
c00255f8:	eb 2b                	jmp    c0025625 <check_device_type+0x7d>
      d->is_ata = (lbam == 0 && lbah == 0) || (lbam == 0x3c && lbah == 0xc3);
c00255fa:	b8 01 00 00 00       	mov    $0x1,%eax
c00255ff:	89 ea                	mov    %ebp,%edx
c0025601:	89 f9                	mov    %edi,%ecx
c0025603:	08 ca                	or     %cl,%dl
c0025605:	74 12                	je     c0025619 <check_device_type+0x71>
c0025607:	89 e8                	mov    %ebp,%eax
c0025609:	3c c3                	cmp    $0xc3,%al
c002560b:	0f 94 c0             	sete   %al
c002560e:	80 f9 3c             	cmp    $0x3c,%cl
c0025611:	0f 94 c2             	sete   %dl
c0025614:	0f b6 d2             	movzbl %dl,%edx
c0025617:	21 d0                	and    %edx,%eax
c0025619:	88 43 10             	mov    %al,0x10(%ebx)
c002561c:	80 63 10 01          	andb   $0x1,0x10(%ebx)
      return true; 
c0025620:	b8 01 00 00 00       	mov    $0x1,%eax
}
c0025625:	83 c4 0c             	add    $0xc,%esp
c0025628:	5b                   	pop    %ebx
c0025629:	5e                   	pop    %esi
c002562a:	5f                   	pop    %edi
c002562b:	5d                   	pop    %ebp
c002562c:	c3                   	ret    

c002562d <select_sector>:
{
c002562d:	57                   	push   %edi
c002562e:	56                   	push   %esi
c002562f:	53                   	push   %ebx
c0025630:	83 ec 20             	sub    $0x20,%esp
c0025633:	89 c6                	mov    %eax,%esi
c0025635:	89 d3                	mov    %edx,%ebx
  struct channel *c = d->channel;
c0025637:	8b 78 08             	mov    0x8(%eax),%edi
  ASSERT (sec_no < (1UL << 28));
c002563a:	81 fa ff ff ff 0f    	cmp    $0xfffffff,%edx
c0025640:	76 2c                	jbe    c002566e <select_sector+0x41>
c0025642:	c7 44 24 10 93 f5 02 	movl   $0xc002f593,0x10(%esp)
c0025649:	c0 
c002564a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025651:	c0 
c0025652:	c7 44 24 08 20 d9 02 	movl   $0xc002d920,0x8(%esp)
c0025659:	c0 
c002565a:	c7 44 24 04 89 01 00 	movl   $0x189,0x4(%esp)
c0025661:	00 
c0025662:	c7 04 24 6d f5 02 c0 	movl   $0xc002f56d,(%esp)
c0025669:	e8 f5 32 00 00       	call   c0028963 <debug_panic>
  wait_until_idle (d);
c002566e:	e8 84 fe ff ff       	call   c00254f7 <wait_until_idle>
  select_device (d);
c0025673:	89 f0                	mov    %esi,%eax
c0025675:	e8 f0 fe ff ff       	call   c002556a <select_device>
  wait_until_idle (d);
c002567a:	89 f0                	mov    %esi,%eax
c002567c:	e8 76 fe ff ff       	call   c00254f7 <wait_until_idle>
  outb (reg_nsect (c), 1);
c0025681:	0f b7 4f 08          	movzwl 0x8(%edi),%ecx
c0025685:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025688:	b8 01 00 00 00       	mov    $0x1,%eax
c002568d:	ee                   	out    %al,(%dx)
  outb (reg_lbal (c), sec_no);
c002568e:	8d 51 03             	lea    0x3(%ecx),%edx
c0025691:	89 d8                	mov    %ebx,%eax
c0025693:	ee                   	out    %al,(%dx)
c0025694:	0f b6 c7             	movzbl %bh,%eax
  outb (reg_lbam (c), sec_no >> 8);
c0025697:	8d 51 04             	lea    0x4(%ecx),%edx
c002569a:	ee                   	out    %al,(%dx)
  outb (reg_lbah (c), (sec_no >> 16));
c002569b:	89 d8                	mov    %ebx,%eax
c002569d:	c1 e8 10             	shr    $0x10,%eax
c00256a0:	8d 51 05             	lea    0x5(%ecx),%edx
c00256a3:	ee                   	out    %al,(%dx)
  outb (reg_device (c),
c00256a4:	83 7e 0c 01          	cmpl   $0x1,0xc(%esi)
c00256a8:	b8 f0 ff ff ff       	mov    $0xfffffff0,%eax
c00256ad:	ba e0 ff ff ff       	mov    $0xffffffe0,%edx
c00256b2:	0f 45 c2             	cmovne %edx,%eax
        DEV_MBS | DEV_LBA | (d->dev_no == 1 ? DEV_DEV : 0) | (sec_no >> 24));
c00256b5:	c1 eb 18             	shr    $0x18,%ebx
  outb (reg_device (c),
c00256b8:	09 d8                	or     %ebx,%eax
c00256ba:	8d 51 06             	lea    0x6(%ecx),%edx
c00256bd:	ee                   	out    %al,(%dx)
}
c00256be:	83 c4 20             	add    $0x20,%esp
c00256c1:	5b                   	pop    %ebx
c00256c2:	5e                   	pop    %esi
c00256c3:	5f                   	pop    %edi
c00256c4:	c3                   	ret    

c00256c5 <wait_while_busy>:
{
c00256c5:	57                   	push   %edi
c00256c6:	56                   	push   %esi
c00256c7:	53                   	push   %ebx
c00256c8:	83 ec 10             	sub    $0x10,%esp
c00256cb:	89 c7                	mov    %eax,%edi
  struct channel *c = d->channel;
c00256cd:	8b 70 08             	mov    0x8(%eax),%esi
  for (i = 0; i < 3000; i++)
c00256d0:	bb 00 00 00 00       	mov    $0x0,%ebx
c00256d5:	eb 18                	jmp    c00256ef <wait_while_busy+0x2a>
      if (i == 700)
c00256d7:	81 fb bc 02 00 00    	cmp    $0x2bc,%ebx
c00256dd:	75 10                	jne    c00256ef <wait_while_busy+0x2a>
        printf ("%s: busy, waiting...", d->name);
c00256df:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00256e3:	c7 04 24 a8 f5 02 c0 	movl   $0xc002f5a8,(%esp)
c00256ea:	e8 1f 14 00 00       	call   c0026b0e <printf>
      if (!(inb (reg_alt_status (c)) & STA_BSY)) 
c00256ef:	0f b7 46 08          	movzwl 0x8(%esi),%eax
c00256f3:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00256f9:	ec                   	in     (%dx),%al
c00256fa:	84 c0                	test   %al,%al
c00256fc:	78 26                	js     c0025724 <wait_while_busy+0x5f>
          if (i >= 700)
c00256fe:	81 fb bb 02 00 00    	cmp    $0x2bb,%ebx
c0025704:	7e 0c                	jle    c0025712 <wait_while_busy+0x4d>
            printf ("ok\n");
c0025706:	c7 04 24 bd f5 02 c0 	movl   $0xc002f5bd,(%esp)
c002570d:	e8 79 4f 00 00       	call   c002a68b <puts>
          return (inb (reg_alt_status (c)) & STA_DRQ) != 0;
c0025712:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c0025716:	66 81 c2 06 02       	add    $0x206,%dx
c002571b:	ec                   	in     (%dx),%al
c002571c:	c0 e8 03             	shr    $0x3,%al
c002571f:	83 e0 01             	and    $0x1,%eax
c0025722:	eb 30                	jmp    c0025754 <wait_while_busy+0x8f>
      timer_msleep (10);
c0025724:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002572b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025732:	00 
c0025733:	e8 3a ec ff ff       	call   c0024372 <timer_msleep>
  for (i = 0; i < 3000; i++)
c0025738:	83 c3 01             	add    $0x1,%ebx
c002573b:	81 fb b8 0b 00 00    	cmp    $0xbb8,%ebx
c0025741:	75 94                	jne    c00256d7 <wait_while_busy+0x12>
  printf ("failed\n");
c0025743:	c7 04 24 d8 fe 02 c0 	movl   $0xc002fed8,(%esp)
c002574a:	e8 3c 4f 00 00       	call   c002a68b <puts>
  return false;
c002574f:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0025754:	83 c4 10             	add    $0x10,%esp
c0025757:	5b                   	pop    %ebx
c0025758:	5e                   	pop    %esi
c0025759:	5f                   	pop    %edi
c002575a:	c3                   	ret    

c002575b <issue_pio_command>:
{
c002575b:	56                   	push   %esi
c002575c:	53                   	push   %ebx
c002575d:	83 ec 24             	sub    $0x24,%esp
c0025760:	89 c3                	mov    %eax,%ebx
c0025762:	89 d6                	mov    %edx,%esi
  ASSERT (intr_get_level () == INTR_ON);
c0025764:	e8 eb c1 ff ff       	call   c0021954 <intr_get_level>
c0025769:	83 f8 01             	cmp    $0x1,%eax
c002576c:	74 2c                	je     c002579a <issue_pio_command+0x3f>
c002576e:	c7 44 24 10 ca ec 02 	movl   $0xc002ecca,0x10(%esp)
c0025775:	c0 
c0025776:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002577d:	c0 
c002577e:	c7 44 24 08 05 d9 02 	movl   $0xc002d905,0x8(%esp)
c0025785:	c0 
c0025786:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c002578d:	00 
c002578e:	c7 04 24 6d f5 02 c0 	movl   $0xc002f56d,(%esp)
c0025795:	e8 c9 31 00 00       	call   c0028963 <debug_panic>
  c->expecting_interrupt = true;
c002579a:	c6 43 30 01          	movb   $0x1,0x30(%ebx)
  outb (reg_command (c), command);
c002579e:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c00257a2:	83 c2 07             	add    $0x7,%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00257a5:	89 f0                	mov    %esi,%eax
c00257a7:	ee                   	out    %al,(%dx)
}
c00257a8:	83 c4 24             	add    $0x24,%esp
c00257ab:	5b                   	pop    %ebx
c00257ac:	5e                   	pop    %esi
c00257ad:	c3                   	ret    

c00257ae <ide_write>:
{
c00257ae:	57                   	push   %edi
c00257af:	56                   	push   %esi
c00257b0:	53                   	push   %ebx
c00257b1:	83 ec 20             	sub    $0x20,%esp
c00257b4:	8b 74 24 30          	mov    0x30(%esp),%esi
  struct channel *c = d->channel;
c00257b8:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00257bb:	8d 7b 0c             	lea    0xc(%ebx),%edi
c00257be:	89 3c 24             	mov    %edi,(%esp)
c00257c1:	e8 74 d6 ff ff       	call   c0022e3a <lock_acquire>
  select_sector (d, sec_no);
c00257c6:	8b 54 24 34          	mov    0x34(%esp),%edx
c00257ca:	89 f0                	mov    %esi,%eax
c00257cc:	e8 5c fe ff ff       	call   c002562d <select_sector>
  issue_pio_command (c, CMD_WRITE_SECTOR_RETRY);
c00257d1:	ba 30 00 00 00       	mov    $0x30,%edx
c00257d6:	89 d8                	mov    %ebx,%eax
c00257d8:	e8 7e ff ff ff       	call   c002575b <issue_pio_command>
  if (!wait_while_busy (d))
c00257dd:	89 f0                	mov    %esi,%eax
c00257df:	e8 e1 fe ff ff       	call   c00256c5 <wait_while_busy>
c00257e4:	84 c0                	test   %al,%al
c00257e6:	75 30                	jne    c0025818 <ide_write+0x6a>
    PANIC ("%s: disk write failed, sector=%"PRDSNu, d->name, sec_no);
c00257e8:	8b 44 24 34          	mov    0x34(%esp),%eax
c00257ec:	89 44 24 14          	mov    %eax,0x14(%esp)
c00257f0:	89 74 24 10          	mov    %esi,0x10(%esp)
c00257f4:	c7 44 24 0c 0c f6 02 	movl   $0xc002f60c,0xc(%esp)
c00257fb:	c0 
c00257fc:	c7 44 24 08 2e d9 02 	movl   $0xc002d92e,0x8(%esp)
c0025803:	c0 
c0025804:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
c002580b:	00 
c002580c:	c7 04 24 6d f5 02 c0 	movl   $0xc002f56d,(%esp)
c0025813:	e8 4b 31 00 00       	call   c0028963 <debug_panic>
   CNT-halfword buffer starting at ADDR. */
static inline void
outsw (uint16_t port, const void *addr, size_t cnt)
{
  /* See [IA32-v2b] "OUTS". */
  asm volatile ("rep outsw" : "+S" (addr), "+c" (cnt) : "d" (port));
c0025818:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c002581c:	8b 74 24 38          	mov    0x38(%esp),%esi
c0025820:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025825:	66 f3 6f             	rep outsw %ds:(%esi),(%dx)
  sema_down (&c->completion_wait);
c0025828:	83 c3 34             	add    $0x34,%ebx
c002582b:	89 1c 24             	mov    %ebx,(%esp)
c002582e:	e8 df d2 ff ff       	call   c0022b12 <sema_down>
  lock_release (&c->lock);
c0025833:	89 3c 24             	mov    %edi,(%esp)
c0025836:	e8 c9 d7 ff ff       	call   c0023004 <lock_release>
}
c002583b:	83 c4 20             	add    $0x20,%esp
c002583e:	5b                   	pop    %ebx
c002583f:	5e                   	pop    %esi
c0025840:	5f                   	pop    %edi
c0025841:	c3                   	ret    

c0025842 <identify_ata_device>:
{
c0025842:	57                   	push   %edi
c0025843:	56                   	push   %esi
c0025844:	53                   	push   %ebx
c0025845:	81 ec a0 02 00 00    	sub    $0x2a0,%esp
c002584b:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c002584d:	8b 70 08             	mov    0x8(%eax),%esi
  ASSERT (d->is_ata);
c0025850:	80 78 10 00          	cmpb   $0x0,0x10(%eax)
c0025854:	75 2c                	jne    c0025882 <identify_ata_device+0x40>
c0025856:	c7 44 24 10 c0 f5 02 	movl   $0xc002f5c0,0x10(%esp)
c002585d:	c0 
c002585e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025865:	c0 
c0025866:	c7 44 24 08 38 d9 02 	movl   $0xc002d938,0x8(%esp)
c002586d:	c0 
c002586e:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
c0025875:	00 
c0025876:	c7 04 24 6d f5 02 c0 	movl   $0xc002f56d,(%esp)
c002587d:	e8 e1 30 00 00       	call   c0028963 <debug_panic>
  wait_until_idle (d);
c0025882:	e8 70 fc ff ff       	call   c00254f7 <wait_until_idle>
  select_device (d);
c0025887:	89 d8                	mov    %ebx,%eax
c0025889:	e8 dc fc ff ff       	call   c002556a <select_device>
  wait_until_idle (d);
c002588e:	89 d8                	mov    %ebx,%eax
c0025890:	e8 62 fc ff ff       	call   c00254f7 <wait_until_idle>
  issue_pio_command (c, CMD_IDENTIFY_DEVICE);
c0025895:	ba ec 00 00 00       	mov    $0xec,%edx
c002589a:	89 f0                	mov    %esi,%eax
c002589c:	e8 ba fe ff ff       	call   c002575b <issue_pio_command>
  sema_down (&c->completion_wait);
c00258a1:	8d 46 34             	lea    0x34(%esi),%eax
c00258a4:	89 04 24             	mov    %eax,(%esp)
c00258a7:	e8 66 d2 ff ff       	call   c0022b12 <sema_down>
  if (!wait_while_busy (d))
c00258ac:	89 d8                	mov    %ebx,%eax
c00258ae:	e8 12 fe ff ff       	call   c00256c5 <wait_while_busy>
c00258b3:	84 c0                	test   %al,%al
c00258b5:	75 09                	jne    c00258c0 <identify_ata_device+0x7e>
      d->is_ata = false;
c00258b7:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c00258bb:	e9 cf 00 00 00       	jmp    c002598f <identify_ata_device+0x14d>
  asm volatile ("rep insw" : "+D" (addr), "+c" (cnt) : "d" (port) : "memory");
c00258c0:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c00258c4:	8d bc 24 a0 00 00 00 	lea    0xa0(%esp),%edi
c00258cb:	b9 00 01 00 00       	mov    $0x100,%ecx
c00258d0:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  capacity = *(uint32_t *) &id[60 * 2];
c00258d3:	8b b4 24 18 01 00 00 	mov    0x118(%esp),%esi
  model = descramble_ata_string (&id[10 * 2], 20);
c00258da:	ba 14 00 00 00       	mov    $0x14,%edx
c00258df:	8d 84 24 b4 00 00 00 	lea    0xb4(%esp),%eax
c00258e6:	e8 25 fb ff ff       	call   c0025410 <descramble_ata_string>
c00258eb:	89 c7                	mov    %eax,%edi
  serial = descramble_ata_string (&id[27 * 2], 40);
c00258ed:	ba 28 00 00 00       	mov    $0x28,%edx
c00258f2:	8d 84 24 d6 00 00 00 	lea    0xd6(%esp),%eax
c00258f9:	e8 12 fb ff ff       	call   c0025410 <descramble_ata_string>
  snprintf (extra_info, sizeof extra_info,
c00258fe:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025902:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025906:	c7 44 24 08 ca f5 02 	movl   $0xc002f5ca,0x8(%esp)
c002590d:	c0 
c002590e:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025915:	00 
c0025916:	8d 44 24 20          	lea    0x20(%esp),%eax
c002591a:	89 04 24             	mov    %eax,(%esp)
c002591d:	e8 ed 18 00 00       	call   c002720f <snprintf>
  if (capacity >= 1024 * 1024 * 1024 / BLOCK_SECTOR_SIZE)
c0025922:	81 fe ff ff 1f 00    	cmp    $0x1fffff,%esi
c0025928:	76 35                	jbe    c002595f <identify_ata_device+0x11d>
      printf ("%s: ignoring ", d->name);
c002592a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002592e:	c7 04 24 e2 f5 02 c0 	movl   $0xc002f5e2,(%esp)
c0025935:	e8 d4 11 00 00       	call   c0026b0e <printf>
      print_human_readable_size (capacity * 512);
c002593a:	c1 e6 09             	shl    $0x9,%esi
c002593d:	89 34 24             	mov    %esi,(%esp)
c0025940:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025947:	00 
c0025948:	e8 8c 1a 00 00       	call   c00273d9 <print_human_readable_size>
      printf ("disk for safety\n");
c002594d:	c7 04 24 f0 f5 02 c0 	movl   $0xc002f5f0,(%esp)
c0025954:	e8 32 4d 00 00       	call   c002a68b <puts>
      d->is_ata = false;
c0025959:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c002595d:	eb 30                	jmp    c002598f <identify_ata_device+0x14d>
  block = block_register (d->name, BLOCK_RAW, extra_info, capacity,
c002595f:	89 5c 24 14          	mov    %ebx,0x14(%esp)
c0025963:	c7 44 24 10 68 5a 03 	movl   $0xc0035a68,0x10(%esp)
c002596a:	c0 
c002596b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002596f:	8d 44 24 20          	lea    0x20(%esp),%eax
c0025973:	89 44 24 08          	mov    %eax,0x8(%esp)
c0025977:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002597e:	00 
c002597f:	89 1c 24             	mov    %ebx,(%esp)
c0025982:	e8 5a f5 ff ff       	call   c0024ee1 <block_register>
  partition_scan (block);
c0025987:	89 04 24             	mov    %eax,(%esp)
c002598a:	e8 30 fa ff ff       	call   c00253bf <partition_scan>
}
c002598f:	81 c4 a0 02 00 00    	add    $0x2a0,%esp
c0025995:	5b                   	pop    %ebx
c0025996:	5e                   	pop    %esi
c0025997:	5f                   	pop    %edi
c0025998:	c3                   	ret    

c0025999 <ide_read>:
{
c0025999:	55                   	push   %ebp
c002599a:	57                   	push   %edi
c002599b:	56                   	push   %esi
c002599c:	53                   	push   %ebx
c002599d:	83 ec 2c             	sub    $0x2c,%esp
c00259a0:	8b 74 24 40          	mov    0x40(%esp),%esi
  struct channel *c = d->channel;
c00259a4:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00259a7:	8d 6b 0c             	lea    0xc(%ebx),%ebp
c00259aa:	89 2c 24             	mov    %ebp,(%esp)
c00259ad:	e8 88 d4 ff ff       	call   c0022e3a <lock_acquire>
  select_sector (d, sec_no);
c00259b2:	8b 54 24 44          	mov    0x44(%esp),%edx
c00259b6:	89 f0                	mov    %esi,%eax
c00259b8:	e8 70 fc ff ff       	call   c002562d <select_sector>
  issue_pio_command (c, CMD_READ_SECTOR_RETRY);
c00259bd:	ba 20 00 00 00       	mov    $0x20,%edx
c00259c2:	89 d8                	mov    %ebx,%eax
c00259c4:	e8 92 fd ff ff       	call   c002575b <issue_pio_command>
  sema_down (&c->completion_wait);
c00259c9:	8d 43 34             	lea    0x34(%ebx),%eax
c00259cc:	89 04 24             	mov    %eax,(%esp)
c00259cf:	e8 3e d1 ff ff       	call   c0022b12 <sema_down>
  if (!wait_while_busy (d))
c00259d4:	89 f0                	mov    %esi,%eax
c00259d6:	e8 ea fc ff ff       	call   c00256c5 <wait_while_busy>
c00259db:	84 c0                	test   %al,%al
c00259dd:	75 30                	jne    c0025a0f <ide_read+0x76>
    PANIC ("%s: disk read failed, sector=%"PRDSNu, d->name, sec_no);
c00259df:	8b 44 24 44          	mov    0x44(%esp),%eax
c00259e3:	89 44 24 14          	mov    %eax,0x14(%esp)
c00259e7:	89 74 24 10          	mov    %esi,0x10(%esp)
c00259eb:	c7 44 24 0c 30 f6 02 	movl   $0xc002f630,0xc(%esp)
c00259f2:	c0 
c00259f3:	c7 44 24 08 17 d9 02 	movl   $0xc002d917,0x8(%esp)
c00259fa:	c0 
c00259fb:	c7 44 24 04 62 01 00 	movl   $0x162,0x4(%esp)
c0025a02:	00 
c0025a03:	c7 04 24 6d f5 02 c0 	movl   $0xc002f56d,(%esp)
c0025a0a:	e8 54 2f 00 00       	call   c0028963 <debug_panic>
c0025a0f:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c0025a13:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0025a17:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025a1c:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  lock_release (&c->lock);
c0025a1f:	89 2c 24             	mov    %ebp,(%esp)
c0025a22:	e8 dd d5 ff ff       	call   c0023004 <lock_release>
}
c0025a27:	83 c4 2c             	add    $0x2c,%esp
c0025a2a:	5b                   	pop    %ebx
c0025a2b:	5e                   	pop    %esi
c0025a2c:	5f                   	pop    %edi
c0025a2d:	5d                   	pop    %ebp
c0025a2e:	c3                   	ret    

c0025a2f <ide_init>:
{
c0025a2f:	55                   	push   %ebp
c0025a30:	57                   	push   %edi
c0025a31:	56                   	push   %esi
c0025a32:	53                   	push   %ebx
c0025a33:	83 ec 4c             	sub    $0x4c,%esp
c0025a36:	c7 44 24 1c 9c 78 03 	movl   $0xc003789c,0x1c(%esp)
c0025a3d:	c0 
c0025a3e:	bd 88 78 03 c0       	mov    $0xc0037888,%ebp
c0025a43:	c7 44 24 20 61 00 00 	movl   $0x61,0x20(%esp)
c0025a4a:	00 
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025a4b:	bf 00 00 00 00       	mov    $0x0,%edi
c0025a50:	8d 75 b8             	lea    -0x48(%ebp),%esi
      snprintf (c->name, sizeof c->name, "ide%zu", chan_no);
c0025a53:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025a57:	c7 44 24 08 00 f6 02 	movl   $0xc002f600,0x8(%esp)
c0025a5e:	c0 
c0025a5f:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025a66:	00 
c0025a67:	89 34 24             	mov    %esi,(%esp)
c0025a6a:	e8 a0 17 00 00       	call   c002720f <snprintf>
      switch (chan_no) 
c0025a6f:	85 ff                	test   %edi,%edi
c0025a71:	74 07                	je     c0025a7a <ide_init+0x4b>
c0025a73:	83 ff 01             	cmp    $0x1,%edi
c0025a76:	74 0e                	je     c0025a86 <ide_init+0x57>
c0025a78:	eb 18                	jmp    c0025a92 <ide_init+0x63>
          c->reg_base = 0x1f0;
c0025a7a:	66 c7 45 c0 f0 01    	movw   $0x1f0,-0x40(%ebp)
          c->irq = 14 + 0x20;
c0025a80:	c6 45 c2 2e          	movb   $0x2e,-0x3e(%ebp)
          break;
c0025a84:	eb 30                	jmp    c0025ab6 <ide_init+0x87>
          c->reg_base = 0x170;
c0025a86:	66 c7 45 c0 70 01    	movw   $0x170,-0x40(%ebp)
          c->irq = 15 + 0x20;
c0025a8c:	c6 45 c2 2f          	movb   $0x2f,-0x3e(%ebp)
          break;
c0025a90:	eb 24                	jmp    c0025ab6 <ide_init+0x87>
          NOT_REACHED ();
c0025a92:	c7 44 24 0c f8 e5 02 	movl   $0xc002e5f8,0xc(%esp)
c0025a99:	c0 
c0025a9a:	c7 44 24 08 5e d9 02 	movl   $0xc002d95e,0x8(%esp)
c0025aa1:	c0 
c0025aa2:	c7 44 24 04 7c 00 00 	movl   $0x7c,0x4(%esp)
c0025aa9:	00 
c0025aaa:	c7 04 24 6d f5 02 c0 	movl   $0xc002f56d,(%esp)
c0025ab1:	e8 ad 2e 00 00       	call   c0028963 <debug_panic>
c0025ab6:	8d 45 c4             	lea    -0x3c(%ebp),%eax
      lock_init (&c->lock);
c0025ab9:	89 04 24             	mov    %eax,(%esp)
c0025abc:	e8 dc d2 ff ff       	call   c0022d9d <lock_init>
c0025ac1:	89 eb                	mov    %ebp,%ebx
      c->expecting_interrupt = false;
c0025ac3:	c6 45 e8 00          	movb   $0x0,-0x18(%ebp)
      sema_init (&c->completion_wait, 0);
c0025ac7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025ace:	00 
c0025acf:	8d 45 ec             	lea    -0x14(%ebp),%eax
c0025ad2:	89 04 24             	mov    %eax,(%esp)
c0025ad5:	e8 ec cf ff ff       	call   c0022ac6 <sema_init>
          snprintf (d->name, sizeof d->name,
c0025ada:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025ade:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025ae2:	c7 44 24 08 07 f6 02 	movl   $0xc002f607,0x8(%esp)
c0025ae9:	c0 
c0025aea:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025af1:	00 
c0025af2:	89 2c 24             	mov    %ebp,(%esp)
c0025af5:	e8 15 17 00 00       	call   c002720f <snprintf>
          d->channel = c;
c0025afa:	89 75 08             	mov    %esi,0x8(%ebp)
          d->dev_no = dev_no;
c0025afd:	c7 45 0c 00 00 00 00 	movl   $0x0,0xc(%ebp)
          d->is_ata = false;
c0025b04:	c6 45 10 00          	movb   $0x0,0x10(%ebp)
          snprintf (d->name, sizeof d->name,
c0025b08:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0025b0c:	89 4c 24 24          	mov    %ecx,0x24(%esp)
c0025b10:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025b14:	83 c0 01             	add    $0x1,%eax
c0025b17:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b1b:	c7 44 24 08 07 f6 02 	movl   $0xc002f607,0x8(%esp)
c0025b22:	c0 
c0025b23:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b2a:	00 
c0025b2b:	89 0c 24             	mov    %ecx,(%esp)
c0025b2e:	e8 dc 16 00 00       	call   c002720f <snprintf>
          d->channel = c;
c0025b33:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0025b37:	89 70 08             	mov    %esi,0x8(%eax)
          d->dev_no = dev_no;
c0025b3a:	c7 40 0c 01 00 00 00 	movl   $0x1,0xc(%eax)
          d->is_ata = false;
c0025b41:	c6 45 24 00          	movb   $0x0,0x24(%ebp)
      intr_register_ext (c->irq, interrupt_handler, c->name);
c0025b45:	89 74 24 08          	mov    %esi,0x8(%esp)
c0025b49:	c7 44 24 04 6c 54 02 	movl   $0xc002546c,0x4(%esp)
c0025b50:	c0 
c0025b51:	0f b6 45 c2          	movzbl -0x3e(%ebp),%eax
c0025b55:	89 04 24             	mov    %eax,(%esp)
c0025b58:	e8 e6 bf ff ff       	call   c0021b43 <intr_register_ext>
c0025b5d:	8d 74 24 3e          	lea    0x3e(%esp),%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025b61:	89 7c 24 28          	mov    %edi,0x28(%esp)
c0025b65:	89 6c 24 2c          	mov    %ebp,0x2c(%esp)
      select_device (d);
c0025b69:	89 e8                	mov    %ebp,%eax
c0025b6b:	e8 fa f9 ff ff       	call   c002556a <select_device>
      outb (reg_nsect (c), 0x55);
c0025b70:	0f b7 7b c0          	movzwl -0x40(%ebx),%edi
c0025b74:	8d 4f 02             	lea    0x2(%edi),%ecx
c0025b77:	b8 55 00 00 00       	mov    $0x55,%eax
c0025b7c:	89 ca                	mov    %ecx,%edx
c0025b7e:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0025b7f:	83 c7 03             	add    $0x3,%edi
c0025b82:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025b87:	89 fa                	mov    %edi,%edx
c0025b89:	ee                   	out    %al,(%dx)
c0025b8a:	89 ca                	mov    %ecx,%edx
c0025b8c:	ee                   	out    %al,(%dx)
c0025b8d:	b8 55 00 00 00       	mov    $0x55,%eax
c0025b92:	89 fa                	mov    %edi,%edx
c0025b94:	ee                   	out    %al,(%dx)
c0025b95:	89 ca                	mov    %ecx,%edx
c0025b97:	ee                   	out    %al,(%dx)
c0025b98:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025b9d:	89 fa                	mov    %edi,%edx
c0025b9f:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025ba0:	89 ca                	mov    %ecx,%edx
c0025ba2:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0025ba3:	ba 00 00 00 00       	mov    $0x0,%edx
c0025ba8:	3c 55                	cmp    $0x55,%al
c0025baa:	75 0b                	jne    c0025bb7 <ide_init+0x188>
c0025bac:	89 fa                	mov    %edi,%edx
c0025bae:	ec                   	in     (%dx),%al
c0025baf:	3c aa                	cmp    $0xaa,%al
c0025bb1:	0f 94 c2             	sete   %dl
c0025bb4:	0f b6 d2             	movzbl %dl,%edx
c0025bb7:	88 16                	mov    %dl,(%esi)
c0025bb9:	80 26 01             	andb   $0x1,(%esi)
c0025bbc:	83 c5 14             	add    $0x14,%ebp
c0025bbf:	83 c6 01             	add    $0x1,%esi
  for (dev_no = 0; dev_no < 2; dev_no++)
c0025bc2:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025bc6:	39 c6                	cmp    %eax,%esi
c0025bc8:	75 9f                	jne    c0025b69 <ide_init+0x13a>
c0025bca:	8b 7c 24 28          	mov    0x28(%esp),%edi
c0025bce:	8b 6c 24 2c          	mov    0x2c(%esp),%ebp
  outb (reg_ctl (c), 0);
c0025bd2:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025bd6:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025bdc:	b8 00 00 00 00       	mov    $0x0,%eax
c0025be1:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025be2:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025be9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025bf0:	00 
c0025bf1:	e8 95 e7 ff ff       	call   c002438b <timer_usleep>
  outb (reg_ctl (c), CTL_SRST);
c0025bf6:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025bfa:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c00:	b8 04 00 00 00       	mov    $0x4,%eax
c0025c05:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c06:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c0d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c14:	00 
c0025c15:	e8 71 e7 ff ff       	call   c002438b <timer_usleep>
  outb (reg_ctl (c), 0);
c0025c1a:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c1e:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c24:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c29:	ee                   	out    %al,(%dx)
  timer_msleep (150);
c0025c2a:	c7 04 24 96 00 00 00 	movl   $0x96,(%esp)
c0025c31:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c38:	00 
c0025c39:	e8 34 e7 ff ff       	call   c0024372 <timer_msleep>
  if (present[0]) 
c0025c3e:	80 7c 24 3e 00       	cmpb   $0x0,0x3e(%esp)
c0025c43:	74 0e                	je     c0025c53 <ide_init+0x224>
      select_device (&c->devices[0]);
c0025c45:	89 d8                	mov    %ebx,%eax
c0025c47:	e8 1e f9 ff ff       	call   c002556a <select_device>
      wait_while_busy (&c->devices[0]); 
c0025c4c:	89 d8                	mov    %ebx,%eax
c0025c4e:	e8 72 fa ff ff       	call   c00256c5 <wait_while_busy>
  if (present[1])
c0025c53:	80 7c 24 3f 00       	cmpb   $0x0,0x3f(%esp)
c0025c58:	74 44                	je     c0025c9e <ide_init+0x26f>
      select_device (&c->devices[1]);
c0025c5a:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025c5e:	e8 07 f9 ff ff       	call   c002556a <select_device>
c0025c63:	be b8 0b 00 00       	mov    $0xbb8,%esi
          if (inb (reg_nsect (c)) == 1 && inb (reg_lbal (c)) == 1)
c0025c68:	0f b7 4b c0          	movzwl -0x40(%ebx),%ecx
c0025c6c:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025c6f:	ec                   	in     (%dx),%al
c0025c70:	3c 01                	cmp    $0x1,%al
c0025c72:	75 08                	jne    c0025c7c <ide_init+0x24d>
c0025c74:	8d 51 03             	lea    0x3(%ecx),%edx
c0025c77:	ec                   	in     (%dx),%al
c0025c78:	3c 01                	cmp    $0x1,%al
c0025c7a:	74 19                	je     c0025c95 <ide_init+0x266>
          timer_msleep (10);
c0025c7c:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c83:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c8a:	00 
c0025c8b:	e8 e2 e6 ff ff       	call   c0024372 <timer_msleep>
      for (i = 0; i < 3000; i++) 
c0025c90:	83 ee 01             	sub    $0x1,%esi
c0025c93:	75 d3                	jne    c0025c68 <ide_init+0x239>
      wait_while_busy (&c->devices[1]);
c0025c95:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025c99:	e8 27 fa ff ff       	call   c00256c5 <wait_while_busy>
      if (check_device_type (&c->devices[0]))
c0025c9e:	89 d8                	mov    %ebx,%eax
c0025ca0:	e8 03 f9 ff ff       	call   c00255a8 <check_device_type>
c0025ca5:	84 c0                	test   %al,%al
c0025ca7:	74 2f                	je     c0025cd8 <ide_init+0x2a9>
        check_device_type (&c->devices[1]);
c0025ca9:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cad:	e8 f6 f8 ff ff       	call   c00255a8 <check_device_type>
c0025cb2:	eb 24                	jmp    c0025cd8 <ide_init+0x2a9>
          identify_ata_device (&c->devices[dev_no]);
c0025cb4:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cb8:	e8 85 fb ff ff       	call   c0025842 <identify_ata_device>
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025cbd:	83 c7 01             	add    $0x1,%edi
c0025cc0:	83 44 24 1c 70       	addl   $0x70,0x1c(%esp)
c0025cc5:	83 c5 70             	add    $0x70,%ebp
c0025cc8:	83 44 24 20 02       	addl   $0x2,0x20(%esp)
c0025ccd:	83 ff 02             	cmp    $0x2,%edi
c0025cd0:	0f 85 7a fd ff ff    	jne    c0025a50 <ide_init+0x21>
c0025cd6:	eb 15                	jmp    c0025ced <ide_init+0x2be>
        if (c->devices[dev_no].is_ata)
c0025cd8:	80 7b 10 00          	cmpb   $0x0,0x10(%ebx)
c0025cdc:	74 07                	je     c0025ce5 <ide_init+0x2b6>
          identify_ata_device (&c->devices[dev_no]);
c0025cde:	89 d8                	mov    %ebx,%eax
c0025ce0:	e8 5d fb ff ff       	call   c0025842 <identify_ata_device>
        if (c->devices[dev_no].is_ata)
c0025ce5:	80 7b 24 00          	cmpb   $0x0,0x24(%ebx)
c0025ce9:	74 d2                	je     c0025cbd <ide_init+0x28e>
c0025ceb:	eb c7                	jmp    c0025cb4 <ide_init+0x285>
}
c0025ced:	83 c4 4c             	add    $0x4c,%esp
c0025cf0:	5b                   	pop    %ebx
c0025cf1:	5e                   	pop    %esi
c0025cf2:	5f                   	pop    %edi
c0025cf3:	5d                   	pop    %ebp
c0025cf4:	c3                   	ret    

c0025cf5 <input_init>:
static struct intq buffer;

/* Initializes the input buffer. */
void
input_init (void) 
{
c0025cf5:	83 ec 1c             	sub    $0x1c,%esp
  intq_init (&buffer);
c0025cf8:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025cff:	e8 11 01 00 00       	call   c0025e15 <intq_init>
}
c0025d04:	83 c4 1c             	add    $0x1c,%esp
c0025d07:	c3                   	ret    

c0025d08 <input_putc>:

/* Adds a key to the input buffer.
   Interrupts must be off and the buffer must not be full. */
void
input_putc (uint8_t key) 
{
c0025d08:	53                   	push   %ebx
c0025d09:	83 ec 28             	sub    $0x28,%esp
c0025d0c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025d10:	e8 3f bc ff ff       	call   c0021954 <intr_get_level>
c0025d15:	85 c0                	test   %eax,%eax
c0025d17:	74 2c                	je     c0025d45 <input_putc+0x3d>
c0025d19:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0025d20:	c0 
c0025d21:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025d28:	c0 
c0025d29:	c7 44 24 08 72 d9 02 	movl   $0xc002d972,0x8(%esp)
c0025d30:	c0 
c0025d31:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c0025d38:	00 
c0025d39:	c7 04 24 50 f6 02 c0 	movl   $0xc002f650,(%esp)
c0025d40:	e8 1e 2c 00 00       	call   c0028963 <debug_panic>
  ASSERT (!intq_full (&buffer));
c0025d45:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d4c:	e8 40 01 00 00       	call   c0025e91 <intq_full>
c0025d51:	84 c0                	test   %al,%al
c0025d53:	74 2c                	je     c0025d81 <input_putc+0x79>
c0025d55:	c7 44 24 10 66 f6 02 	movl   $0xc002f666,0x10(%esp)
c0025d5c:	c0 
c0025d5d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025d64:	c0 
c0025d65:	c7 44 24 08 72 d9 02 	movl   $0xc002d972,0x8(%esp)
c0025d6c:	c0 
c0025d6d:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025d74:	00 
c0025d75:	c7 04 24 50 f6 02 c0 	movl   $0xc002f650,(%esp)
c0025d7c:	e8 e2 2b 00 00       	call   c0028963 <debug_panic>

  intq_putc (&buffer, key);
c0025d81:	0f b6 db             	movzbl %bl,%ebx
c0025d84:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0025d88:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d8f:	e8 a7 03 00 00       	call   c002613b <intq_putc>
  serial_notify ();
c0025d94:	e8 21 ee ff ff       	call   c0024bba <serial_notify>
}
c0025d99:	83 c4 28             	add    $0x28,%esp
c0025d9c:	5b                   	pop    %ebx
c0025d9d:	c3                   	ret    

c0025d9e <input_getc>:

/* Retrieves a key from the input buffer.
   If the buffer is empty, waits for a key to be pressed. */
uint8_t
input_getc (void) 
{
c0025d9e:	56                   	push   %esi
c0025d9f:	53                   	push   %ebx
c0025da0:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level;
  uint8_t key;

  old_level = intr_disable ();
c0025da3:	e8 f7 bb ff ff       	call   c002199f <intr_disable>
c0025da8:	89 c6                	mov    %eax,%esi
  key = intq_getc (&buffer);
c0025daa:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025db1:	e8 b9 02 00 00       	call   c002606f <intq_getc>
c0025db6:	89 c3                	mov    %eax,%ebx
  serial_notify ();
c0025db8:	e8 fd ed ff ff       	call   c0024bba <serial_notify>
  intr_set_level (old_level);
c0025dbd:	89 34 24             	mov    %esi,(%esp)
c0025dc0:	e8 e1 bb ff ff       	call   c00219a6 <intr_set_level>
  
  return key;
}
c0025dc5:	89 d8                	mov    %ebx,%eax
c0025dc7:	83 c4 14             	add    $0x14,%esp
c0025dca:	5b                   	pop    %ebx
c0025dcb:	5e                   	pop    %esi
c0025dcc:	c3                   	ret    

c0025dcd <input_full>:
/* Returns true if the input buffer is full,
   false otherwise.
   Interrupts must be off. */
bool
input_full (void) 
{
c0025dcd:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0025dd0:	e8 7f bb ff ff       	call   c0021954 <intr_get_level>
c0025dd5:	85 c0                	test   %eax,%eax
c0025dd7:	74 2c                	je     c0025e05 <input_full+0x38>
c0025dd9:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0025de0:	c0 
c0025de1:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025de8:	c0 
c0025de9:	c7 44 24 08 67 d9 02 	movl   $0xc002d967,0x8(%esp)
c0025df0:	c0 
c0025df1:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c0025df8:	00 
c0025df9:	c7 04 24 50 f6 02 c0 	movl   $0xc002f650,(%esp)
c0025e00:	e8 5e 2b 00 00       	call   c0028963 <debug_panic>
  return intq_full (&buffer);
c0025e05:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025e0c:	e8 80 00 00 00       	call   c0025e91 <intq_full>
}
c0025e11:	83 c4 2c             	add    $0x2c,%esp
c0025e14:	c3                   	ret    

c0025e15 <intq_init>:
static void signal (struct intq *q, struct thread **waiter);

/* Initializes interrupt queue Q. */
void
intq_init (struct intq *q) 
{
c0025e15:	53                   	push   %ebx
c0025e16:	83 ec 18             	sub    $0x18,%esp
c0025e19:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_init (&q->lock);
c0025e1d:	89 1c 24             	mov    %ebx,(%esp)
c0025e20:	e8 78 cf ff ff       	call   c0022d9d <lock_init>
  q->not_full = q->not_empty = NULL;
c0025e25:	c7 43 28 00 00 00 00 	movl   $0x0,0x28(%ebx)
c0025e2c:	c7 43 24 00 00 00 00 	movl   $0x0,0x24(%ebx)
  q->head = q->tail = 0;
c0025e33:	c7 43 70 00 00 00 00 	movl   $0x0,0x70(%ebx)
c0025e3a:	c7 43 6c 00 00 00 00 	movl   $0x0,0x6c(%ebx)
}
c0025e41:	83 c4 18             	add    $0x18,%esp
c0025e44:	5b                   	pop    %ebx
c0025e45:	c3                   	ret    

c0025e46 <intq_empty>:

/* Returns true if Q is empty, false otherwise. */
bool
intq_empty (const struct intq *q) 
{
c0025e46:	53                   	push   %ebx
c0025e47:	83 ec 28             	sub    $0x28,%esp
c0025e4a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025e4e:	e8 01 bb ff ff       	call   c0021954 <intr_get_level>
c0025e53:	85 c0                	test   %eax,%eax
c0025e55:	74 2c                	je     c0025e83 <intq_empty+0x3d>
c0025e57:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0025e5e:	c0 
c0025e5f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025e66:	c0 
c0025e67:	c7 44 24 08 a7 d9 02 	movl   $0xc002d9a7,0x8(%esp)
c0025e6e:	c0 
c0025e6f:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025e76:	00 
c0025e77:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c0025e7e:	e8 e0 2a 00 00       	call   c0028963 <debug_panic>
  return q->head == q->tail;
c0025e83:	8b 43 70             	mov    0x70(%ebx),%eax
c0025e86:	39 43 6c             	cmp    %eax,0x6c(%ebx)
c0025e89:	0f 94 c0             	sete   %al
}
c0025e8c:	83 c4 28             	add    $0x28,%esp
c0025e8f:	5b                   	pop    %ebx
c0025e90:	c3                   	ret    

c0025e91 <intq_full>:

/* Returns true if Q is full, false otherwise. */
bool
intq_full (const struct intq *q) 
{
c0025e91:	53                   	push   %ebx
c0025e92:	83 ec 28             	sub    $0x28,%esp
c0025e95:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025e99:	e8 b6 ba ff ff       	call   c0021954 <intr_get_level>
c0025e9e:	85 c0                	test   %eax,%eax
c0025ea0:	74 2c                	je     c0025ece <intq_full+0x3d>
c0025ea2:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0025ea9:	c0 
c0025eaa:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025eb1:	c0 
c0025eb2:	c7 44 24 08 9d d9 02 	movl   $0xc002d99d,0x8(%esp)
c0025eb9:	c0 
c0025eba:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c0025ec1:	00 
c0025ec2:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c0025ec9:	e8 95 2a 00 00       	call   c0028963 <debug_panic>

/* Returns the position after POS within an intq. */
static int
next (int pos) 
{
  return (pos + 1) % INTQ_BUFSIZE;
c0025ece:	8b 43 6c             	mov    0x6c(%ebx),%eax
c0025ed1:	8d 50 01             	lea    0x1(%eax),%edx
c0025ed4:	89 d0                	mov    %edx,%eax
c0025ed6:	c1 f8 1f             	sar    $0x1f,%eax
c0025ed9:	c1 e8 1a             	shr    $0x1a,%eax
c0025edc:	01 c2                	add    %eax,%edx
c0025ede:	83 e2 3f             	and    $0x3f,%edx
c0025ee1:	29 c2                	sub    %eax,%edx
  return next (q->head) == q->tail;
c0025ee3:	39 53 70             	cmp    %edx,0x70(%ebx)
c0025ee6:	0f 94 c0             	sete   %al
}
c0025ee9:	83 c4 28             	add    $0x28,%esp
c0025eec:	5b                   	pop    %ebx
c0025eed:	c3                   	ret    

c0025eee <wait>:

/* WAITER must be the address of Q's not_empty or not_full
   member.  Waits until the given condition is true. */
static void
wait (struct intq *q UNUSED, struct thread **waiter) 
{
c0025eee:	56                   	push   %esi
c0025eef:	53                   	push   %ebx
c0025ef0:	83 ec 24             	sub    $0x24,%esp
c0025ef3:	89 c3                	mov    %eax,%ebx
c0025ef5:	89 d6                	mov    %edx,%esi
  ASSERT (!intr_context ());
c0025ef7:	e8 05 bd ff ff       	call   c0021c01 <intr_context>
c0025efc:	84 c0                	test   %al,%al
c0025efe:	74 2c                	je     c0025f2c <wait+0x3e>
c0025f00:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c0025f07:	c0 
c0025f08:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025f0f:	c0 
c0025f10:	c7 44 24 08 8e d9 02 	movl   $0xc002d98e,0x8(%esp)
c0025f17:	c0 
c0025f18:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c0025f1f:	00 
c0025f20:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c0025f27:	e8 37 2a 00 00       	call   c0028963 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0025f2c:	e8 23 ba ff ff       	call   c0021954 <intr_get_level>
c0025f31:	85 c0                	test   %eax,%eax
c0025f33:	74 2c                	je     c0025f61 <wait+0x73>
c0025f35:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0025f3c:	c0 
c0025f3d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025f44:	c0 
c0025f45:	c7 44 24 08 8e d9 02 	movl   $0xc002d98e,0x8(%esp)
c0025f4c:	c0 
c0025f4d:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c0025f54:	00 
c0025f55:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c0025f5c:	e8 02 2a 00 00       	call   c0028963 <debug_panic>
  ASSERT ((waiter == &q->not_empty && intq_empty (q))
c0025f61:	8d 43 28             	lea    0x28(%ebx),%eax
c0025f64:	39 c6                	cmp    %eax,%esi
c0025f66:	75 0c                	jne    c0025f74 <wait+0x86>
c0025f68:	89 1c 24             	mov    %ebx,(%esp)
c0025f6b:	e8 d6 fe ff ff       	call   c0025e46 <intq_empty>
c0025f70:	84 c0                	test   %al,%al
c0025f72:	75 3f                	jne    c0025fb3 <wait+0xc5>
c0025f74:	8d 43 24             	lea    0x24(%ebx),%eax
c0025f77:	39 c6                	cmp    %eax,%esi
c0025f79:	75 0c                	jne    c0025f87 <wait+0x99>
c0025f7b:	89 1c 24             	mov    %ebx,(%esp)
c0025f7e:	e8 0e ff ff ff       	call   c0025e91 <intq_full>
c0025f83:	84 c0                	test   %al,%al
c0025f85:	75 2c                	jne    c0025fb3 <wait+0xc5>
c0025f87:	c7 44 24 10 90 f6 02 	movl   $0xc002f690,0x10(%esp)
c0025f8e:	c0 
c0025f8f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025f96:	c0 
c0025f97:	c7 44 24 08 8e d9 02 	movl   $0xc002d98e,0x8(%esp)
c0025f9e:	c0 
c0025f9f:	c7 44 24 04 5c 00 00 	movl   $0x5c,0x4(%esp)
c0025fa6:	00 
c0025fa7:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c0025fae:	e8 b0 29 00 00       	call   c0028963 <debug_panic>
          || (waiter == &q->not_full && intq_full (q)));

  *waiter = thread_current ();
c0025fb3:	e8 21 ae ff ff       	call   c0020dd9 <thread_current>
c0025fb8:	89 06                	mov    %eax,(%esi)
  thread_block ();
c0025fba:	e8 50 b3 ff ff       	call   c002130f <thread_block>
}
c0025fbf:	83 c4 24             	add    $0x24,%esp
c0025fc2:	5b                   	pop    %ebx
c0025fc3:	5e                   	pop    %esi
c0025fc4:	c3                   	ret    

c0025fc5 <signal>:
   member, and the associated condition must be true.  If a
   thread is waiting for the condition, wakes it up and resets
   the waiting thread. */
static void
signal (struct intq *q UNUSED, struct thread **waiter) 
{
c0025fc5:	56                   	push   %esi
c0025fc6:	53                   	push   %ebx
c0025fc7:	83 ec 24             	sub    $0x24,%esp
c0025fca:	89 c6                	mov    %eax,%esi
c0025fcc:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025fce:	e8 81 b9 ff ff       	call   c0021954 <intr_get_level>
c0025fd3:	85 c0                	test   %eax,%eax
c0025fd5:	74 2c                	je     c0026003 <signal+0x3e>
c0025fd7:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c0025fde:	c0 
c0025fdf:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0025fe6:	c0 
c0025fe7:	c7 44 24 08 87 d9 02 	movl   $0xc002d987,0x8(%esp)
c0025fee:	c0 
c0025fef:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0025ff6:	00 
c0025ff7:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c0025ffe:	e8 60 29 00 00       	call   c0028963 <debug_panic>
  ASSERT ((waiter == &q->not_empty && !intq_empty (q))
c0026003:	8d 46 28             	lea    0x28(%esi),%eax
c0026006:	39 c3                	cmp    %eax,%ebx
c0026008:	75 0c                	jne    c0026016 <signal+0x51>
c002600a:	89 34 24             	mov    %esi,(%esp)
c002600d:	e8 34 fe ff ff       	call   c0025e46 <intq_empty>
c0026012:	84 c0                	test   %al,%al
c0026014:	74 3f                	je     c0026055 <signal+0x90>
c0026016:	8d 46 24             	lea    0x24(%esi),%eax
c0026019:	39 c3                	cmp    %eax,%ebx
c002601b:	75 0c                	jne    c0026029 <signal+0x64>
c002601d:	89 34 24             	mov    %esi,(%esp)
c0026020:	e8 6c fe ff ff       	call   c0025e91 <intq_full>
c0026025:	84 c0                	test   %al,%al
c0026027:	74 2c                	je     c0026055 <signal+0x90>
c0026029:	c7 44 24 10 ec f6 02 	movl   $0xc002f6ec,0x10(%esp)
c0026030:	c0 
c0026031:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0026038:	c0 
c0026039:	c7 44 24 08 87 d9 02 	movl   $0xc002d987,0x8(%esp)
c0026040:	c0 
c0026041:	c7 44 24 04 6b 00 00 	movl   $0x6b,0x4(%esp)
c0026048:	00 
c0026049:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c0026050:	e8 0e 29 00 00       	call   c0028963 <debug_panic>
          || (waiter == &q->not_full && !intq_full (q)));

  if (*waiter != NULL) 
c0026055:	8b 03                	mov    (%ebx),%eax
c0026057:	85 c0                	test   %eax,%eax
c0026059:	74 0e                	je     c0026069 <signal+0xa4>
    {
      thread_unblock (*waiter);
c002605b:	89 04 24             	mov    %eax,(%esp)
c002605e:	e8 9b ac ff ff       	call   c0020cfe <thread_unblock>
      *waiter = NULL;
c0026063:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
    }
}
c0026069:	83 c4 24             	add    $0x24,%esp
c002606c:	5b                   	pop    %ebx
c002606d:	5e                   	pop    %esi
c002606e:	c3                   	ret    

c002606f <intq_getc>:
{
c002606f:	56                   	push   %esi
c0026070:	53                   	push   %ebx
c0026071:	83 ec 24             	sub    $0x24,%esp
c0026074:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0026078:	e8 d7 b8 ff ff       	call   c0021954 <intr_get_level>
c002607d:	85 c0                	test   %eax,%eax
c002607f:	75 05                	jne    c0026086 <intq_getc+0x17>
      wait (q, &q->not_empty);
c0026081:	8d 73 28             	lea    0x28(%ebx),%esi
c0026084:	eb 7a                	jmp    c0026100 <intq_getc+0x91>
  ASSERT (intr_get_level () == INTR_OFF);
c0026086:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c002608d:	c0 
c002608e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0026095:	c0 
c0026096:	c7 44 24 08 93 d9 02 	movl   $0xc002d993,0x8(%esp)
c002609d:	c0 
c002609e:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c00260a5:	00 
c00260a6:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c00260ad:	e8 b1 28 00 00       	call   c0028963 <debug_panic>
      ASSERT (!intr_context ());
c00260b2:	e8 4a bb ff ff       	call   c0021c01 <intr_context>
c00260b7:	84 c0                	test   %al,%al
c00260b9:	74 2c                	je     c00260e7 <intq_getc+0x78>
c00260bb:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c00260c2:	c0 
c00260c3:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00260ca:	c0 
c00260cb:	c7 44 24 08 93 d9 02 	movl   $0xc002d993,0x8(%esp)
c00260d2:	c0 
c00260d3:	c7 44 24 04 2d 00 00 	movl   $0x2d,0x4(%esp)
c00260da:	00 
c00260db:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c00260e2:	e8 7c 28 00 00       	call   c0028963 <debug_panic>
      lock_acquire (&q->lock);
c00260e7:	89 1c 24             	mov    %ebx,(%esp)
c00260ea:	e8 4b cd ff ff       	call   c0022e3a <lock_acquire>
      wait (q, &q->not_empty);
c00260ef:	89 f2                	mov    %esi,%edx
c00260f1:	89 d8                	mov    %ebx,%eax
c00260f3:	e8 f6 fd ff ff       	call   c0025eee <wait>
      lock_release (&q->lock);
c00260f8:	89 1c 24             	mov    %ebx,(%esp)
c00260fb:	e8 04 cf ff ff       	call   c0023004 <lock_release>
  while (intq_empty (q)) 
c0026100:	89 1c 24             	mov    %ebx,(%esp)
c0026103:	e8 3e fd ff ff       	call   c0025e46 <intq_empty>
c0026108:	84 c0                	test   %al,%al
c002610a:	75 a6                	jne    c00260b2 <intq_getc+0x43>
  byte = q->buf[q->tail];
c002610c:	8b 4b 70             	mov    0x70(%ebx),%ecx
c002610f:	0f b6 74 0b 2c       	movzbl 0x2c(%ebx,%ecx,1),%esi
  return (pos + 1) % INTQ_BUFSIZE;
c0026114:	83 c1 01             	add    $0x1,%ecx
c0026117:	89 ca                	mov    %ecx,%edx
c0026119:	c1 fa 1f             	sar    $0x1f,%edx
c002611c:	c1 ea 1a             	shr    $0x1a,%edx
c002611f:	01 d1                	add    %edx,%ecx
c0026121:	83 e1 3f             	and    $0x3f,%ecx
c0026124:	29 d1                	sub    %edx,%ecx
  q->tail = next (q->tail);
c0026126:	89 4b 70             	mov    %ecx,0x70(%ebx)
  signal (q, &q->not_full);
c0026129:	8d 53 24             	lea    0x24(%ebx),%edx
c002612c:	89 d8                	mov    %ebx,%eax
c002612e:	e8 92 fe ff ff       	call   c0025fc5 <signal>
}
c0026133:	89 f0                	mov    %esi,%eax
c0026135:	83 c4 24             	add    $0x24,%esp
c0026138:	5b                   	pop    %ebx
c0026139:	5e                   	pop    %esi
c002613a:	c3                   	ret    

c002613b <intq_putc>:
{
c002613b:	57                   	push   %edi
c002613c:	56                   	push   %esi
c002613d:	53                   	push   %ebx
c002613e:	83 ec 20             	sub    $0x20,%esp
c0026141:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0026145:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0026149:	e8 06 b8 ff ff       	call   c0021954 <intr_get_level>
c002614e:	85 c0                	test   %eax,%eax
c0026150:	75 05                	jne    c0026157 <intq_putc+0x1c>
      wait (q, &q->not_full);
c0026152:	8d 73 24             	lea    0x24(%ebx),%esi
c0026155:	eb 7a                	jmp    c00261d1 <intq_putc+0x96>
  ASSERT (intr_get_level () == INTR_OFF);
c0026157:	c7 44 24 10 cc e4 02 	movl   $0xc002e4cc,0x10(%esp)
c002615e:	c0 
c002615f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0026166:	c0 
c0026167:	c7 44 24 08 7d d9 02 	movl   $0xc002d97d,0x8(%esp)
c002616e:	c0 
c002616f:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0026176:	00 
c0026177:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c002617e:	e8 e0 27 00 00       	call   c0028963 <debug_panic>
      ASSERT (!intr_context ());
c0026183:	e8 79 ba ff ff       	call   c0021c01 <intr_context>
c0026188:	84 c0                	test   %al,%al
c002618a:	74 2c                	je     c00261b8 <intq_putc+0x7d>
c002618c:	c7 44 24 10 62 e5 02 	movl   $0xc002e562,0x10(%esp)
c0026193:	c0 
c0026194:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002619b:	c0 
c002619c:	c7 44 24 08 7d d9 02 	movl   $0xc002d97d,0x8(%esp)
c00261a3:	c0 
c00261a4:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
c00261ab:	00 
c00261ac:	c7 04 24 7b f6 02 c0 	movl   $0xc002f67b,(%esp)
c00261b3:	e8 ab 27 00 00       	call   c0028963 <debug_panic>
      lock_acquire (&q->lock);
c00261b8:	89 1c 24             	mov    %ebx,(%esp)
c00261bb:	e8 7a cc ff ff       	call   c0022e3a <lock_acquire>
      wait (q, &q->not_full);
c00261c0:	89 f2                	mov    %esi,%edx
c00261c2:	89 d8                	mov    %ebx,%eax
c00261c4:	e8 25 fd ff ff       	call   c0025eee <wait>
      lock_release (&q->lock);
c00261c9:	89 1c 24             	mov    %ebx,(%esp)
c00261cc:	e8 33 ce ff ff       	call   c0023004 <lock_release>
  while (intq_full (q))
c00261d1:	89 1c 24             	mov    %ebx,(%esp)
c00261d4:	e8 b8 fc ff ff       	call   c0025e91 <intq_full>
c00261d9:	84 c0                	test   %al,%al
c00261db:	75 a6                	jne    c0026183 <intq_putc+0x48>
  q->buf[q->head] = byte;
c00261dd:	8b 53 6c             	mov    0x6c(%ebx),%edx
c00261e0:	89 f8                	mov    %edi,%eax
c00261e2:	88 44 13 2c          	mov    %al,0x2c(%ebx,%edx,1)
  return (pos + 1) % INTQ_BUFSIZE;
c00261e6:	83 c2 01             	add    $0x1,%edx
c00261e9:	89 d0                	mov    %edx,%eax
c00261eb:	c1 f8 1f             	sar    $0x1f,%eax
c00261ee:	c1 e8 1a             	shr    $0x1a,%eax
c00261f1:	01 c2                	add    %eax,%edx
c00261f3:	83 e2 3f             	and    $0x3f,%edx
c00261f6:	29 c2                	sub    %eax,%edx
  q->head = next (q->head);
c00261f8:	89 53 6c             	mov    %edx,0x6c(%ebx)
  signal (q, &q->not_empty);
c00261fb:	8d 53 28             	lea    0x28(%ebx),%edx
c00261fe:	89 d8                	mov    %ebx,%eax
c0026200:	e8 c0 fd ff ff       	call   c0025fc5 <signal>
}
c0026205:	83 c4 20             	add    $0x20,%esp
c0026208:	5b                   	pop    %ebx
c0026209:	5e                   	pop    %esi
c002620a:	5f                   	pop    %edi
c002620b:	c3                   	ret    

c002620c <rtc_get_time>:

/* Returns number of seconds since Unix epoch of January 1,
   1970. */
time_t
rtc_get_time (void)
{
c002620c:	55                   	push   %ebp
c002620d:	57                   	push   %edi
c002620e:	56                   	push   %esi
c002620f:	53                   	push   %ebx
c0026210:	83 ec 03             	sub    $0x3,%esp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026213:	bb 00 00 00 00       	mov    $0x0,%ebx
c0026218:	bd 02 00 00 00       	mov    $0x2,%ebp
c002621d:	89 d8                	mov    %ebx,%eax
c002621f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026221:	e4 71                	in     $0x71,%al

/* Returns the integer value of the given BCD byte. */
static int
bcd_to_bin (uint8_t x)
{
  return (x & 0x0f) + ((x >> 4) * 10);
c0026223:	89 c2                	mov    %eax,%edx
c0026225:	83 e2 0f             	and    $0xf,%edx
c0026228:	c0 e8 04             	shr    $0x4,%al
c002622b:	0f b6 c0             	movzbl %al,%eax
c002622e:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0026231:	8d 0c 42             	lea    (%edx,%eax,2),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026234:	89 e8                	mov    %ebp,%eax
c0026236:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026238:	e4 71                	in     $0x71,%al
c002623a:	88 04 24             	mov    %al,(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002623d:	b8 04 00 00 00       	mov    $0x4,%eax
c0026242:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026244:	e4 71                	in     $0x71,%al
c0026246:	88 44 24 01          	mov    %al,0x1(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002624a:	b8 07 00 00 00       	mov    $0x7,%eax
c002624f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026251:	e4 71                	in     $0x71,%al
c0026253:	88 44 24 02          	mov    %al,0x2(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026257:	b8 08 00 00 00       	mov    $0x8,%eax
c002625c:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002625e:	e4 71                	in     $0x71,%al
c0026260:	89 c6                	mov    %eax,%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026262:	b8 09 00 00 00       	mov    $0x9,%eax
c0026267:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026269:	e4 71                	in     $0x71,%al
c002626b:	89 c7                	mov    %eax,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002626d:	89 d8                	mov    %ebx,%eax
c002626f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026271:	e4 71                	in     $0x71,%al
c0026273:	89 c2                	mov    %eax,%edx
c0026275:	89 d0                	mov    %edx,%eax
c0026277:	83 e0 0f             	and    $0xf,%eax
c002627a:	c0 ea 04             	shr    $0x4,%dl
c002627d:	0f b6 d2             	movzbl %dl,%edx
c0026280:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026283:	8d 04 50             	lea    (%eax,%edx,2),%eax
  while (sec != bcd_to_bin (cmos_read (RTC_REG_SEC)));
c0026286:	39 c1                	cmp    %eax,%ecx
c0026288:	75 93                	jne    c002621d <rtc_get_time+0x11>
  return (x & 0x0f) + ((x >> 4) * 10);
c002628a:	89 fa                	mov    %edi,%edx
c002628c:	83 e2 0f             	and    $0xf,%edx
c002628f:	89 f8                	mov    %edi,%eax
c0026291:	c0 e8 04             	shr    $0x4,%al
c0026294:	0f b6 f8             	movzbl %al,%edi
c0026297:	8d 04 bf             	lea    (%edi,%edi,4),%eax
  if (year < 70)
c002629a:	8d 04 42             	lea    (%edx,%eax,2),%eax
    year += 100;
c002629d:	8d 50 64             	lea    0x64(%eax),%edx
c00262a0:	83 f8 45             	cmp    $0x45,%eax
c00262a3:	0f 4e c2             	cmovle %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c00262a6:	89 f2                	mov    %esi,%edx
c00262a8:	83 e2 0f             	and    $0xf,%edx
c00262ab:	89 f3                	mov    %esi,%ebx
c00262ad:	c0 eb 04             	shr    $0x4,%bl
c00262b0:	0f b6 f3             	movzbl %bl,%esi
c00262b3:	8d 1c b6             	lea    (%esi,%esi,4),%ebx
c00262b6:	8d 34 5a             	lea    (%edx,%ebx,2),%esi
  year -= 70;
c00262b9:	8d 78 ba             	lea    -0x46(%eax),%edi
  time = (year * 365 + (year - 1) / 4) * 24 * 60 * 60;
c00262bc:	69 df 6d 01 00 00    	imul   $0x16d,%edi,%ebx
c00262c2:	8d 50 bc             	lea    -0x44(%eax),%edx
c00262c5:	83 e8 47             	sub    $0x47,%eax
c00262c8:	0f 48 c2             	cmovs  %edx,%eax
c00262cb:	c1 f8 02             	sar    $0x2,%eax
c00262ce:	01 d8                	add    %ebx,%eax
c00262d0:	69 c0 80 51 01 00    	imul   $0x15180,%eax,%eax
  for (i = 1; i <= mon; i++)
c00262d6:	85 f6                	test   %esi,%esi
c00262d8:	7e 19                	jle    c00262f3 <rtc_get_time+0xe7>
c00262da:	ba 01 00 00 00       	mov    $0x1,%edx
    time += days_per_month[i - 1] * 24 * 60 * 60;
c00262df:	69 1c 95 bc d9 02 c0 	imul   $0x15180,-0x3ffd2644(,%edx,4),%ebx
c00262e6:	80 51 01 00 
c00262ea:	01 d8                	add    %ebx,%eax
  for (i = 1; i <= mon; i++)
c00262ec:	83 c2 01             	add    $0x1,%edx
c00262ef:	39 f2                	cmp    %esi,%edx
c00262f1:	7e ec                	jle    c00262df <rtc_get_time+0xd3>
  if (mon > 2 && year % 4 == 0)
c00262f3:	83 fe 02             	cmp    $0x2,%esi
c00262f6:	7e 0e                	jle    c0026306 <rtc_get_time+0xfa>
c00262f8:	83 e7 03             	and    $0x3,%edi
    time += 24 * 60 * 60;
c00262fb:	8d 90 80 51 01 00    	lea    0x15180(%eax),%edx
c0026301:	85 ff                	test   %edi,%edi
c0026303:	0f 44 c2             	cmove  %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c0026306:	0f b6 54 24 01       	movzbl 0x1(%esp),%edx
c002630b:	89 d3                	mov    %edx,%ebx
c002630d:	83 e3 0f             	and    $0xf,%ebx
c0026310:	c0 ea 04             	shr    $0x4,%dl
c0026313:	0f b6 d2             	movzbl %dl,%edx
c0026316:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026319:	8d 1c 53             	lea    (%ebx,%edx,2),%ebx
  time += hour * 60 * 60;
c002631c:	69 db 10 0e 00 00    	imul   $0xe10,%ebx,%ebx
  return (x & 0x0f) + ((x >> 4) * 10);
c0026322:	0f b6 14 24          	movzbl (%esp),%edx
c0026326:	89 d6                	mov    %edx,%esi
c0026328:	83 e6 0f             	and    $0xf,%esi
c002632b:	c0 ea 04             	shr    $0x4,%dl
c002632e:	0f b6 d2             	movzbl %dl,%edx
c0026331:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026334:	8d 14 56             	lea    (%esi,%edx,2),%edx
  time += min * 60;
c0026337:	6b d2 3c             	imul   $0x3c,%edx,%edx
  time += (mday - 1) * 24 * 60 * 60;
c002633a:	01 da                	add    %ebx,%edx
  time += hour * 60 * 60;
c002633c:	01 d1                	add    %edx,%ecx
  return (x & 0x0f) + ((x >> 4) * 10);
c002633e:	0f b6 54 24 02       	movzbl 0x2(%esp),%edx
c0026343:	89 d3                	mov    %edx,%ebx
c0026345:	83 e3 0f             	and    $0xf,%ebx
c0026348:	c0 ea 04             	shr    $0x4,%dl
c002634b:	0f b6 d2             	movzbl %dl,%edx
c002634e:	8d 14 92             	lea    (%edx,%edx,4),%edx
  time += (mday - 1) * 24 * 60 * 60;
c0026351:	8d 54 53 ff          	lea    -0x1(%ebx,%edx,2),%edx
c0026355:	69 d2 80 51 01 00    	imul   $0x15180,%edx,%edx
  time += min * 60;
c002635b:	01 d1                	add    %edx,%ecx
  time += sec;
c002635d:	01 c8                	add    %ecx,%eax
}
c002635f:	83 c4 03             	add    $0x3,%esp
c0026362:	5b                   	pop    %ebx
c0026363:	5e                   	pop    %esi
c0026364:	5f                   	pop    %edi
c0026365:	5d                   	pop    %ebp
c0026366:	c3                   	ret    
c0026367:	90                   	nop
c0026368:	90                   	nop
c0026369:	90                   	nop
c002636a:	90                   	nop
c002636b:	90                   	nop
c002636c:	90                   	nop
c002636d:	90                   	nop
c002636e:	90                   	nop
c002636f:	90                   	nop

c0026370 <shutdown_configure>:
/* Sets TYPE as the way that machine will shut down when Pintos
   execution is complete. */
void
shutdown_configure (enum shutdown_type type)
{
  how = type;
c0026370:	8b 44 24 04          	mov    0x4(%esp),%eax
c0026374:	a3 94 79 03 c0       	mov    %eax,0xc0037994
c0026379:	c3                   	ret    

c002637a <shutdown_reboot>:
}

/* Reboots the machine via the keyboard controller. */
void
shutdown_reboot (void)
{
c002637a:	56                   	push   %esi
c002637b:	53                   	push   %ebx
c002637c:	83 ec 14             	sub    $0x14,%esp
  printf ("Rebooting...\n");
c002637f:	c7 04 24 47 f7 02 c0 	movl   $0xc002f747,(%esp)
c0026386:	e8 00 43 00 00       	call   c002a68b <puts>
    {
      int i;

      /* Poll keyboard controller's status byte until
       * 'input buffer empty' is reported. */
      for (i = 0; i < 0x10000; i++)
c002638b:	bb 00 00 00 00       	mov    $0x0,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026390:	be fe ff ff ff       	mov    $0xfffffffe,%esi
c0026395:	eb 1d                	jmp    c00263b4 <shutdown_reboot+0x3a>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026397:	e4 64                	in     $0x64,%al
        {
          if ((inb (CONTROL_REG) & 0x02) == 0)
c0026399:	a8 02                	test   $0x2,%al
c002639b:	74 1f                	je     c00263bc <shutdown_reboot+0x42>
            break;
          timer_udelay (2);
c002639d:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00263a4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263ab:	00 
c00263ac:	e8 25 e0 ff ff       	call   c00243d6 <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c00263b1:	83 c3 01             	add    $0x1,%ebx
c00263b4:	81 fb ff ff 00 00    	cmp    $0xffff,%ebx
c00263ba:	7e db                	jle    c0026397 <shutdown_reboot+0x1d>
        }

      timer_udelay (50);
c00263bc:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c00263c3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263ca:	00 
c00263cb:	e8 06 e0 ff ff       	call   c00243d6 <timer_udelay>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00263d0:	89 f0                	mov    %esi,%eax
c00263d2:	e6 64                	out    %al,$0x64

      /* Pulse bit 0 of the output port P2 of the keyboard controller.
       * This will reset the CPU. */
      outb (CONTROL_REG, 0xfe);
      timer_udelay (50);
c00263d4:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c00263db:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263e2:	00 
c00263e3:	e8 ee df ff ff       	call   c00243d6 <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c00263e8:	bb 00 00 00 00       	mov    $0x0,%ebx
    }
c00263ed:	eb c5                	jmp    c00263b4 <shutdown_reboot+0x3a>

c00263ef <shutdown_power_off>:

/* Powers down the machine we're running on,
   as long as we're running on Bochs or QEMU. */
void
shutdown_power_off (void)
{
c00263ef:	83 ec 2c             	sub    $0x2c,%esp
  const char s[] = "Shutdown";
c00263f2:	c7 44 24 17 53 68 75 	movl   $0x74756853,0x17(%esp)
c00263f9:	74 
c00263fa:	c7 44 24 1b 64 6f 77 	movl   $0x6e776f64,0x1b(%esp)
c0026401:	6e 
c0026402:	c6 44 24 1f 00       	movb   $0x0,0x1f(%esp)

/* Print statistics about Pintos execution. */
static void
print_stats (void)
{
  timer_print_stats ();
c0026407:	e8 fc df ff ff       	call   c0024408 <timer_print_stats>
  thread_print_stats ();
c002640c:	e8 a4 a8 ff ff       	call   c0020cb5 <thread_print_stats>
#ifdef FILESYS
  block_print_stats ();
#endif
  console_print_stats ();
c0026411:	e8 0e 42 00 00       	call   c002a624 <console_print_stats>
  kbd_print_stats ();
c0026416:	e8 33 e2 ff ff       	call   c002464e <kbd_print_stats>
  printf ("Powering off...\n");
c002641b:	c7 04 24 54 f7 02 c0 	movl   $0xc002f754,(%esp)
c0026422:	e8 64 42 00 00       	call   c002a68b <puts>
  serial_flush ();
c0026427:	e8 50 e7 ff ff       	call   c0024b7c <serial_flush>
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c002642c:	ba 04 b0 ff ff       	mov    $0xffffb004,%edx
c0026431:	b8 00 20 00 00       	mov    $0x2000,%eax
c0026436:	66 ef                	out    %ax,(%dx)
  for (p = s; *p != '\0'; p++)
c0026438:	0f b6 44 24 17       	movzbl 0x17(%esp),%eax
c002643d:	84 c0                	test   %al,%al
c002643f:	74 14                	je     c0026455 <shutdown_power_off+0x66>
c0026441:	8d 4c 24 17          	lea    0x17(%esp),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026445:	ba 00 89 ff ff       	mov    $0xffff8900,%edx
c002644a:	ee                   	out    %al,(%dx)
c002644b:	83 c1 01             	add    $0x1,%ecx
c002644e:	0f b6 01             	movzbl (%ecx),%eax
c0026451:	84 c0                	test   %al,%al
c0026453:	75 f5                	jne    c002644a <shutdown_power_off+0x5b>
c0026455:	ba 01 05 00 00       	mov    $0x501,%edx
c002645a:	b8 31 00 00 00       	mov    $0x31,%eax
c002645f:	ee                   	out    %al,(%dx)
  asm volatile ("cli; hlt" : : : "memory");
c0026460:	fa                   	cli    
c0026461:	f4                   	hlt    
  printf ("still running...\n");
c0026462:	c7 04 24 64 f7 02 c0 	movl   $0xc002f764,(%esp)
c0026469:	e8 1d 42 00 00       	call   c002a68b <puts>
c002646e:	eb fe                	jmp    c002646e <shutdown_power_off+0x7f>

c0026470 <shutdown>:
{
c0026470:	83 ec 0c             	sub    $0xc,%esp
  switch (how)
c0026473:	a1 94 79 03 c0       	mov    0xc0037994,%eax
c0026478:	83 f8 01             	cmp    $0x1,%eax
c002647b:	74 07                	je     c0026484 <shutdown+0x14>
c002647d:	83 f8 02             	cmp    $0x2,%eax
c0026480:	74 07                	je     c0026489 <shutdown+0x19>
c0026482:	eb 11                	jmp    c0026495 <shutdown+0x25>
      shutdown_power_off ();
c0026484:	e8 66 ff ff ff       	call   c00263ef <shutdown_power_off>
c0026489:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
      shutdown_reboot ();
c0026490:	e8 e5 fe ff ff       	call   c002637a <shutdown_reboot>
}
c0026495:	83 c4 0c             	add    $0xc,%esp
c0026498:	c3                   	ret    
c0026499:	90                   	nop
c002649a:	90                   	nop
c002649b:	90                   	nop
c002649c:	90                   	nop
c002649d:	90                   	nop
c002649e:	90                   	nop
c002649f:	90                   	nop

c00264a0 <speaker_off>:

/* Turn off the PC speaker, by disconnecting the timer channel's
   output from the speaker. */
void
speaker_off (void)
{
c00264a0:	83 ec 1c             	sub    $0x1c,%esp
  enum intr_level old_level = intr_disable ();
c00264a3:	e8 f7 b4 ff ff       	call   c002199f <intr_disable>
c00264a8:	89 c2                	mov    %eax,%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00264aa:	e4 61                	in     $0x61,%al
  outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) & ~SPEAKER_GATE_ENABLE);
c00264ac:	83 e0 fc             	and    $0xfffffffc,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00264af:	e6 61                	out    %al,$0x61
  intr_set_level (old_level);
c00264b1:	89 14 24             	mov    %edx,(%esp)
c00264b4:	e8 ed b4 ff ff       	call   c00219a6 <intr_set_level>
}
c00264b9:	83 c4 1c             	add    $0x1c,%esp
c00264bc:	c3                   	ret    

c00264bd <speaker_on>:
{
c00264bd:	56                   	push   %esi
c00264be:	53                   	push   %ebx
c00264bf:	83 ec 14             	sub    $0x14,%esp
c00264c2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (frequency >= 20 && frequency <= 20000)
c00264c6:	8d 43 ec             	lea    -0x14(%ebx),%eax
c00264c9:	3d 0c 4e 00 00       	cmp    $0x4e0c,%eax
c00264ce:	77 30                	ja     c0026500 <speaker_on+0x43>
      enum intr_level old_level = intr_disable ();
c00264d0:	e8 ca b4 ff ff       	call   c002199f <intr_disable>
c00264d5:	89 c6                	mov    %eax,%esi
      pit_configure_channel (2, 3, frequency);
c00264d7:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00264db:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c00264e2:	00 
c00264e3:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00264ea:	e8 00 d8 ff ff       	call   c0023cef <pit_configure_channel>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00264ef:	e4 61                	in     $0x61,%al
      outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) | SPEAKER_GATE_ENABLE);
c00264f1:	83 c8 03             	or     $0x3,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00264f4:	e6 61                	out    %al,$0x61
      intr_set_level (old_level);
c00264f6:	89 34 24             	mov    %esi,(%esp)
c00264f9:	e8 a8 b4 ff ff       	call   c00219a6 <intr_set_level>
c00264fe:	eb 05                	jmp    c0026505 <speaker_on+0x48>
      speaker_off ();
c0026500:	e8 9b ff ff ff       	call   c00264a0 <speaker_off>
}
c0026505:	83 c4 14             	add    $0x14,%esp
c0026508:	5b                   	pop    %ebx
c0026509:	5e                   	pop    %esi
c002650a:	c3                   	ret    

c002650b <speaker_beep>:

/* Briefly beep the PC speaker. */
void
speaker_beep (void)
{
c002650b:	83 ec 1c             	sub    $0x1c,%esp

     We can't just enable interrupts while we sleep.  For one
     thing, we get called (indirectly) from printf, which should
     always work, even during boot before we're ready to enable
     interrupts. */
  if (intr_get_level () == INTR_ON)
c002650e:	e8 41 b4 ff ff       	call   c0021954 <intr_get_level>
c0026513:	83 f8 01             	cmp    $0x1,%eax
c0026516:	75 25                	jne    c002653d <speaker_beep+0x32>
    {
      speaker_on (440);
c0026518:	c7 04 24 b8 01 00 00 	movl   $0x1b8,(%esp)
c002651f:	e8 99 ff ff ff       	call   c00264bd <speaker_on>
      timer_msleep (250);
c0026524:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002652b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026532:	00 
c0026533:	e8 3a de ff ff       	call   c0024372 <timer_msleep>
      speaker_off ();
c0026538:	e8 63 ff ff ff       	call   c00264a0 <speaker_off>
    }
}
c002653d:	83 c4 1c             	add    $0x1c,%esp
c0026540:	c3                   	ret    

c0026541 <debug_backtrace>:
   each of the functions we are nested within.  gdb or addr2line
   may be applied to kernel.o to translate these into file names,
   line numbers, and function names.  */
void
debug_backtrace (void) 
{
c0026541:	55                   	push   %ebp
c0026542:	89 e5                	mov    %esp,%ebp
c0026544:	53                   	push   %ebx
c0026545:	83 ec 14             	sub    $0x14,%esp
  static bool explained;
  void **frame;
  
  printf ("Call stack: %p", __builtin_return_address (0));
c0026548:	8b 45 04             	mov    0x4(%ebp),%eax
c002654b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002654f:	c7 04 24 75 f7 02 c0 	movl   $0xc002f775,(%esp)
c0026556:	e8 b3 05 00 00       	call   c0026b0e <printf>
  for (frame = __builtin_frame_address (1);
c002655b:	8b 5d 00             	mov    0x0(%ebp),%ebx
c002655e:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0026564:	76 27                	jbe    c002658d <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c0026566:	83 3b 00             	cmpl   $0x0,(%ebx)
c0026569:	74 22                	je     c002658d <debug_backtrace+0x4c>
       frame = frame[0]) 
    printf (" %p", frame[1]);
c002656b:	8b 43 04             	mov    0x4(%ebx),%eax
c002656e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026572:	c7 04 24 80 f7 02 c0 	movl   $0xc002f780,(%esp)
c0026579:	e8 90 05 00 00       	call   c0026b0e <printf>
       frame = frame[0]) 
c002657e:	8b 1b                	mov    (%ebx),%ebx
  for (frame = __builtin_frame_address (1);
c0026580:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0026586:	76 05                	jbe    c002658d <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c0026588:	83 3b 00             	cmpl   $0x0,(%ebx)
c002658b:	75 de                	jne    c002656b <debug_backtrace+0x2a>
  printf (".\n");
c002658d:	c7 04 24 17 f3 02 c0 	movl   $0xc002f317,(%esp)
c0026594:	e8 f2 40 00 00       	call   c002a68b <puts>

  if (!explained) 
c0026599:	80 3d 98 79 03 c0 00 	cmpb   $0x0,0xc0037998
c00265a0:	75 13                	jne    c00265b5 <debug_backtrace+0x74>
    {
      explained = true;
c00265a2:	c6 05 98 79 03 c0 01 	movb   $0x1,0xc0037998
      printf ("The `backtrace' program can make call stacks useful.\n"
c00265a9:	c7 04 24 84 f7 02 c0 	movl   $0xc002f784,(%esp)
c00265b0:	e8 d6 40 00 00       	call   c002a68b <puts>
              "Read \"Backtraces\" in the \"Debugging Tools\" chapter\n"
              "of the Pintos documentation for more information.\n");
    }
}
c00265b5:	83 c4 14             	add    $0x14,%esp
c00265b8:	5b                   	pop    %ebx
c00265b9:	5d                   	pop    %ebp
c00265ba:	c3                   	ret    

c00265bb <random_init>:
{
  uint8_t *seedp = (uint8_t *) &seed;
  int i;
  uint8_t j;

  for (i = 0; i < 256; i++) 
c00265bb:	b8 00 00 00 00       	mov    $0x0,%eax
    s[i] = i;
c00265c0:	88 80 c0 79 03 c0    	mov    %al,-0x3ffc8640(%eax)
  for (i = 0; i < 256; i++) 
c00265c6:	83 c0 01             	add    $0x1,%eax
c00265c9:	3d 00 01 00 00       	cmp    $0x100,%eax
c00265ce:	75 f0                	jne    c00265c0 <random_init+0x5>
{
c00265d0:	56                   	push   %esi
c00265d1:	53                   	push   %ebx
  for (i = 0; i < 256; i++) 
c00265d2:	be 00 00 00 00       	mov    $0x0,%esi
c00265d7:	66 b8 00 00          	mov    $0x0,%ax
  for (i = j = 0; i < 256; i++) 
    {
      j += s[i] + seedp[i % sizeof seed];
c00265db:	89 c1                	mov    %eax,%ecx
c00265dd:	83 e1 03             	and    $0x3,%ecx
c00265e0:	0f b6 98 c0 79 03 c0 	movzbl -0x3ffc8640(%eax),%ebx
c00265e7:	89 da                	mov    %ebx,%edx
c00265e9:	02 54 0c 0c          	add    0xc(%esp,%ecx,1),%dl
c00265ed:	89 d1                	mov    %edx,%ecx
c00265ef:	01 ce                	add    %ecx,%esi
      swap_byte (s + i, s + j);
c00265f1:	89 f2                	mov    %esi,%edx
c00265f3:	0f b6 ca             	movzbl %dl,%ecx
  *a = *b;
c00265f6:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c00265fd:	88 90 c0 79 03 c0    	mov    %dl,-0x3ffc8640(%eax)
  *b = t;
c0026603:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)
  for (i = j = 0; i < 256; i++) 
c0026609:	83 c0 01             	add    $0x1,%eax
c002660c:	3d 00 01 00 00       	cmp    $0x100,%eax
c0026611:	75 c8                	jne    c00265db <random_init+0x20>
    }

  s_i = s_j = 0;
c0026613:	c6 05 a1 79 03 c0 00 	movb   $0x0,0xc00379a1
c002661a:	c6 05 a2 79 03 c0 00 	movb   $0x0,0xc00379a2
  inited = true;
c0026621:	c6 05 a0 79 03 c0 01 	movb   $0x1,0xc00379a0
}
c0026628:	5b                   	pop    %ebx
c0026629:	5e                   	pop    %esi
c002662a:	c3                   	ret    

c002662b <random_bytes>:

/* Writes SIZE random bytes into BUF. */
void
random_bytes (void *buf_, size_t size) 
{
c002662b:	55                   	push   %ebp
c002662c:	57                   	push   %edi
c002662d:	56                   	push   %esi
c002662e:	53                   	push   %ebx
c002662f:	83 ec 0c             	sub    $0xc,%esp
  uint8_t *buf;

  if (!inited)
c0026632:	80 3d a0 79 03 c0 00 	cmpb   $0x0,0xc00379a0
c0026639:	75 0c                	jne    c0026647 <random_bytes+0x1c>
    random_init (0);
c002663b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0026642:	e8 74 ff ff ff       	call   c00265bb <random_init>

  for (buf = buf_; size-- > 0; buf++)
c0026647:	8b 44 24 24          	mov    0x24(%esp),%eax
c002664b:	83 e8 01             	sub    $0x1,%eax
c002664e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0026652:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0026657:	0f 84 87 00 00 00    	je     c00266e4 <random_bytes+0xb9>
c002665d:	0f b6 1d a1 79 03 c0 	movzbl 0xc00379a1,%ebx
c0026664:	b8 00 00 00 00       	mov    $0x0,%eax
c0026669:	0f b6 35 a2 79 03 c0 	movzbl 0xc00379a2,%esi
c0026670:	83 c6 01             	add    $0x1,%esi
c0026673:	89 f5                	mov    %esi,%ebp
c0026675:	8d 14 06             	lea    (%esi,%eax,1),%edx
    {
      uint8_t s_k;
      
      s_i++;
      s_j += s[s_i];
c0026678:	0f b6 d2             	movzbl %dl,%edx
c002667b:	02 9a c0 79 03 c0    	add    -0x3ffc8640(%edx),%bl
c0026681:	88 5c 24 07          	mov    %bl,0x7(%esp)
      swap_byte (s + s_i, s + s_j);
c0026685:	0f b6 cb             	movzbl %bl,%ecx
  uint8_t t = *a;
c0026688:	0f b6 ba c0 79 03 c0 	movzbl -0x3ffc8640(%edx),%edi
  *a = *b;
c002668f:	0f b6 99 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%ebx
c0026696:	88 9a c0 79 03 c0    	mov    %bl,-0x3ffc8640(%edx)
  *b = t;
c002669c:	89 fb                	mov    %edi,%ebx
c002669e:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)

      s_k = s[s_i] + s[s_j];
c00266a4:	89 f9                	mov    %edi,%ecx
c00266a6:	02 8a c0 79 03 c0    	add    -0x3ffc8640(%edx),%cl
      *buf = s[s_k];
c00266ac:	0f b6 c9             	movzbl %cl,%ecx
c00266af:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c00266b6:	8b 7c 24 20          	mov    0x20(%esp),%edi
c00266ba:	88 14 07             	mov    %dl,(%edi,%eax,1)
c00266bd:	83 c0 01             	add    $0x1,%eax
  for (buf = buf_; size-- > 0; buf++)
c00266c0:	3b 44 24 24          	cmp    0x24(%esp),%eax
c00266c4:	74 07                	je     c00266cd <random_bytes+0xa2>
      s_j += s[s_i];
c00266c6:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c00266cb:	eb a6                	jmp    c0026673 <random_bytes+0x48>
c00266cd:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c00266d2:	0f b6 44 24 08       	movzbl 0x8(%esp),%eax
c00266d7:	01 e8                	add    %ebp,%eax
c00266d9:	a2 a2 79 03 c0       	mov    %al,0xc00379a2
c00266de:	88 1d a1 79 03 c0    	mov    %bl,0xc00379a1
    }
}
c00266e4:	83 c4 0c             	add    $0xc,%esp
c00266e7:	5b                   	pop    %ebx
c00266e8:	5e                   	pop    %esi
c00266e9:	5f                   	pop    %edi
c00266ea:	5d                   	pop    %ebp
c00266eb:	c3                   	ret    

c00266ec <random_ulong>:
/* Returns a pseudo-random unsigned long.
   Use random_ulong() % n to obtain a random number in the range
   0...n (exclusive). */
unsigned long
random_ulong (void) 
{
c00266ec:	83 ec 18             	sub    $0x18,%esp
  unsigned long ul;
  random_bytes (&ul, sizeof ul);
c00266ef:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c00266f6:	00 
c00266f7:	8d 44 24 14          	lea    0x14(%esp),%eax
c00266fb:	89 04 24             	mov    %eax,(%esp)
c00266fe:	e8 28 ff ff ff       	call   c002662b <random_bytes>
  return ul;
}
c0026703:	8b 44 24 14          	mov    0x14(%esp),%eax
c0026707:	83 c4 18             	add    $0x18,%esp
c002670a:	c3                   	ret    
c002670b:	90                   	nop
c002670c:	90                   	nop
c002670d:	90                   	nop
c002670e:	90                   	nop
c002670f:	90                   	nop

c0026710 <vsnprintf_helper>:
}

/* Helper function for vsnprintf(). */
static void
vsnprintf_helper (char ch, void *aux_)
{
c0026710:	53                   	push   %ebx
c0026711:	8b 5c 24 08          	mov    0x8(%esp),%ebx
c0026715:	8b 44 24 0c          	mov    0xc(%esp),%eax
  struct vsnprintf_aux *aux = aux_;

  if (aux->length++ < aux->max_length)
c0026719:	8b 50 04             	mov    0x4(%eax),%edx
c002671c:	8d 4a 01             	lea    0x1(%edx),%ecx
c002671f:	89 48 04             	mov    %ecx,0x4(%eax)
c0026722:	3b 50 08             	cmp    0x8(%eax),%edx
c0026725:	7d 09                	jge    c0026730 <vsnprintf_helper+0x20>
    *aux->p++ = ch;
c0026727:	8b 10                	mov    (%eax),%edx
c0026729:	8d 4a 01             	lea    0x1(%edx),%ecx
c002672c:	89 08                	mov    %ecx,(%eax)
c002672e:	88 1a                	mov    %bl,(%edx)
}
c0026730:	5b                   	pop    %ebx
c0026731:	c3                   	ret    

c0026732 <output_dup>:
}

/* Writes CH to OUTPUT with auxiliary data AUX, CNT times. */
static void
output_dup (char ch, size_t cnt, void (*output) (char, void *), void *aux) 
{
c0026732:	55                   	push   %ebp
c0026733:	57                   	push   %edi
c0026734:	56                   	push   %esi
c0026735:	53                   	push   %ebx
c0026736:	83 ec 1c             	sub    $0x1c,%esp
c0026739:	8b 7c 24 30          	mov    0x30(%esp),%edi
  while (cnt-- > 0)
c002673d:	85 d2                	test   %edx,%edx
c002673f:	74 15                	je     c0026756 <output_dup+0x24>
c0026741:	89 ce                	mov    %ecx,%esi
c0026743:	89 d3                	mov    %edx,%ebx
    output (ch, aux);
c0026745:	0f be e8             	movsbl %al,%ebp
c0026748:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002674c:	89 2c 24             	mov    %ebp,(%esp)
c002674f:	ff d6                	call   *%esi
  while (cnt-- > 0)
c0026751:	83 eb 01             	sub    $0x1,%ebx
c0026754:	75 f2                	jne    c0026748 <output_dup+0x16>
}
c0026756:	83 c4 1c             	add    $0x1c,%esp
c0026759:	5b                   	pop    %ebx
c002675a:	5e                   	pop    %esi
c002675b:	5f                   	pop    %edi
c002675c:	5d                   	pop    %ebp
c002675d:	c3                   	ret    

c002675e <format_integer>:
{
c002675e:	55                   	push   %ebp
c002675f:	57                   	push   %edi
c0026760:	56                   	push   %esi
c0026761:	53                   	push   %ebx
c0026762:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c0026768:	89 c6                	mov    %eax,%esi
c002676a:	89 d7                	mov    %edx,%edi
c002676c:	8b 84 24 a0 00 00 00 	mov    0xa0(%esp),%eax
  sign = 0;
c0026773:	c7 44 24 30 00 00 00 	movl   $0x0,0x30(%esp)
c002677a:	00 
  if (is_signed) 
c002677b:	84 c9                	test   %cl,%cl
c002677d:	74 4c                	je     c00267cb <format_integer+0x6d>
      if (c->flags & PLUS)
c002677f:	8b 8c 24 a8 00 00 00 	mov    0xa8(%esp),%ecx
c0026786:	8b 11                	mov    (%ecx),%edx
c0026788:	f6 c2 02             	test   $0x2,%dl
c002678b:	74 14                	je     c00267a1 <format_integer+0x43>
        sign = negative ? '-' : '+';
c002678d:	3c 01                	cmp    $0x1,%al
c002678f:	19 c0                	sbb    %eax,%eax
c0026791:	89 44 24 30          	mov    %eax,0x30(%esp)
c0026795:	83 64 24 30 fe       	andl   $0xfffffffe,0x30(%esp)
c002679a:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c002679f:	eb 2a                	jmp    c00267cb <format_integer+0x6d>
      else if (c->flags & SPACE)
c00267a1:	f6 c2 04             	test   $0x4,%dl
c00267a4:	74 14                	je     c00267ba <format_integer+0x5c>
        sign = negative ? '-' : ' ';
c00267a6:	3c 01                	cmp    $0x1,%al
c00267a8:	19 c0                	sbb    %eax,%eax
c00267aa:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267ae:	83 64 24 30 f3       	andl   $0xfffffff3,0x30(%esp)
c00267b3:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c00267b8:	eb 11                	jmp    c00267cb <format_integer+0x6d>
  sign = 0;
c00267ba:	3c 01                	cmp    $0x1,%al
c00267bc:	19 c0                	sbb    %eax,%eax
c00267be:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267c2:	f7 54 24 30          	notl   0x30(%esp)
c00267c6:	83 64 24 30 2d       	andl   $0x2d,0x30(%esp)
  x = (c->flags & POUND) && value ? b->x : 0;
c00267cb:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c00267d2:	8b 00                	mov    (%eax),%eax
c00267d4:	89 44 24 38          	mov    %eax,0x38(%esp)
c00267d8:	83 e0 08             	and    $0x8,%eax
c00267db:	89 44 24 3c          	mov    %eax,0x3c(%esp)
c00267df:	74 5c                	je     c002683d <format_integer+0xdf>
c00267e1:	89 f8                	mov    %edi,%eax
c00267e3:	09 f0                	or     %esi,%eax
c00267e5:	0f 84 e9 00 00 00    	je     c00268d4 <format_integer+0x176>
c00267eb:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c00267f2:	8b 40 08             	mov    0x8(%eax),%eax
c00267f5:	89 44 24 34          	mov    %eax,0x34(%esp)
c00267f9:	eb 08                	jmp    c0026803 <format_integer+0xa5>
c00267fb:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c0026802:	00 
      *cp++ = b->digits[value % b->base];
c0026803:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c002680a:	8b 40 04             	mov    0x4(%eax),%eax
c002680d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026811:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026818:	8b 00                	mov    (%eax),%eax
c002681a:	89 44 24 18          	mov    %eax,0x18(%esp)
c002681e:	89 c1                	mov    %eax,%ecx
c0026820:	c1 f9 1f             	sar    $0x1f,%ecx
c0026823:	89 4c 24 1c          	mov    %ecx,0x1c(%esp)
c0026827:	bb 00 00 00 00       	mov    $0x0,%ebx
c002682c:	8d 6c 24 40          	lea    0x40(%esp),%ebp
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026830:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026834:	83 e0 20             	and    $0x20,%eax
c0026837:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c002683b:	eb 17                	jmp    c0026854 <format_integer+0xf6>
  while (value > 0) 
c002683d:	89 f8                	mov    %edi,%eax
c002683f:	09 f0                	or     %esi,%eax
c0026841:	75 b8                	jne    c00267fb <format_integer+0x9d>
  x = (c->flags & POUND) && value ? b->x : 0;
c0026843:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c002684a:	00 
  cp = buf;
c002684b:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c002684f:	e9 92 00 00 00       	jmp    c00268e6 <format_integer+0x188>
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026854:	83 7c 24 2c 00       	cmpl   $0x0,0x2c(%esp)
c0026859:	74 1c                	je     c0026877 <format_integer+0x119>
c002685b:	85 db                	test   %ebx,%ebx
c002685d:	7e 18                	jle    c0026877 <format_integer+0x119>
c002685f:	8b 8c 24 a4 00 00 00 	mov    0xa4(%esp),%ecx
c0026866:	89 d8                	mov    %ebx,%eax
c0026868:	99                   	cltd   
c0026869:	f7 79 0c             	idivl  0xc(%ecx)
c002686c:	85 d2                	test   %edx,%edx
c002686e:	75 07                	jne    c0026877 <format_integer+0x119>
        *cp++ = ',';
c0026870:	c6 45 00 2c          	movb   $0x2c,0x0(%ebp)
c0026874:	8d 6d 01             	lea    0x1(%ebp),%ebp
      *cp++ = b->digits[value % b->base];
c0026877:	8d 45 01             	lea    0x1(%ebp),%eax
c002687a:	89 44 24 24          	mov    %eax,0x24(%esp)
c002687e:	8b 44 24 18          	mov    0x18(%esp),%eax
c0026882:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0026886:	89 44 24 08          	mov    %eax,0x8(%esp)
c002688a:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002688e:	89 34 24             	mov    %esi,(%esp)
c0026891:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0026895:	e8 a0 1a 00 00       	call   c002833a <__umoddi3>
c002689a:	8b 4c 24 28          	mov    0x28(%esp),%ecx
c002689e:	0f b6 04 01          	movzbl (%ecx,%eax,1),%eax
c00268a2:	88 45 00             	mov    %al,0x0(%ebp)
      value /= b->base;
c00268a5:	8b 44 24 18          	mov    0x18(%esp),%eax
c00268a9:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00268ad:	89 44 24 08          	mov    %eax,0x8(%esp)
c00268b1:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00268b5:	89 34 24             	mov    %esi,(%esp)
c00268b8:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00268bc:	e8 56 1a 00 00       	call   c0028317 <__udivdi3>
c00268c1:	89 c6                	mov    %eax,%esi
c00268c3:	89 d7                	mov    %edx,%edi
      digit_cnt++;
c00268c5:	83 c3 01             	add    $0x1,%ebx
  while (value > 0) 
c00268c8:	89 d1                	mov    %edx,%ecx
c00268ca:	09 c1                	or     %eax,%ecx
c00268cc:	74 14                	je     c00268e2 <format_integer+0x184>
      *cp++ = b->digits[value % b->base];
c00268ce:	8b 6c 24 24          	mov    0x24(%esp),%ebp
c00268d2:	eb 80                	jmp    c0026854 <format_integer+0xf6>
  x = (c->flags & POUND) && value ? b->x : 0;
c00268d4:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c00268db:	00 
  cp = buf;
c00268dc:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c00268e0:	eb 04                	jmp    c00268e6 <format_integer+0x188>
c00268e2:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  precision = c->precision < 0 ? 1 : c->precision;
c00268e6:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c00268ed:	8b 50 08             	mov    0x8(%eax),%edx
c00268f0:	85 d2                	test   %edx,%edx
c00268f2:	b8 01 00 00 00       	mov    $0x1,%eax
c00268f7:	0f 48 d0             	cmovs  %eax,%edx
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c00268fa:	8d 7c 24 40          	lea    0x40(%esp),%edi
c00268fe:	89 d8                	mov    %ebx,%eax
c0026900:	29 f8                	sub    %edi,%eax
c0026902:	39 c2                	cmp    %eax,%edx
c0026904:	7e 1f                	jle    c0026925 <format_integer+0x1c7>
c0026906:	8d 44 24 7f          	lea    0x7f(%esp),%eax
c002690a:	39 c3                	cmp    %eax,%ebx
c002690c:	73 17                	jae    c0026925 <format_integer+0x1c7>
c002690e:	89 f9                	mov    %edi,%ecx
c0026910:	89 c6                	mov    %eax,%esi
    *cp++ = '0';
c0026912:	83 c3 01             	add    $0x1,%ebx
c0026915:	c6 43 ff 30          	movb   $0x30,-0x1(%ebx)
c0026919:	89 d8                	mov    %ebx,%eax
c002691b:	29 c8                	sub    %ecx,%eax
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002691d:	39 c2                	cmp    %eax,%edx
c002691f:	7e 04                	jle    c0026925 <format_integer+0x1c7>
c0026921:	39 f3                	cmp    %esi,%ebx
c0026923:	75 ed                	jne    c0026912 <format_integer+0x1b4>
  if ((c->flags & POUND) && b->base == 8 && (cp == buf || cp[-1] != '0'))
c0026925:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002692a:	74 20                	je     c002694c <format_integer+0x1ee>
c002692c:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026933:	83 38 08             	cmpl   $0x8,(%eax)
c0026936:	75 14                	jne    c002694c <format_integer+0x1ee>
c0026938:	8d 44 24 40          	lea    0x40(%esp),%eax
c002693c:	39 c3                	cmp    %eax,%ebx
c002693e:	74 06                	je     c0026946 <format_integer+0x1e8>
c0026940:	80 7b ff 30          	cmpb   $0x30,-0x1(%ebx)
c0026944:	74 06                	je     c002694c <format_integer+0x1ee>
    *cp++ = '0';
c0026946:	c6 03 30             	movb   $0x30,(%ebx)
c0026949:	8d 5b 01             	lea    0x1(%ebx),%ebx
  pad_cnt = c->width - (cp - buf) - (x ? 2 : 0) - (sign != 0);
c002694c:	29 df                	sub    %ebx,%edi
c002694e:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026955:	03 78 04             	add    0x4(%eax),%edi
c0026958:	83 7c 24 34 01       	cmpl   $0x1,0x34(%esp)
c002695d:	19 c0                	sbb    %eax,%eax
c002695f:	f7 d0                	not    %eax
c0026961:	83 e0 02             	and    $0x2,%eax
c0026964:	83 7c 24 30 00       	cmpl   $0x0,0x30(%esp)
c0026969:	0f 95 c1             	setne  %cl
c002696c:	89 ce                	mov    %ecx,%esi
c002696e:	29 c7                	sub    %eax,%edi
c0026970:	0f b6 c1             	movzbl %cl,%eax
c0026973:	29 c7                	sub    %eax,%edi
c0026975:	b8 00 00 00 00       	mov    $0x0,%eax
c002697a:	0f 48 f8             	cmovs  %eax,%edi
  if ((c->flags & (MINUS | ZERO)) == 0)
c002697d:	f6 44 24 38 11       	testb  $0x11,0x38(%esp)
c0026982:	75 1d                	jne    c00269a1 <format_integer+0x243>
    output_dup (' ', pad_cnt, output, aux);
c0026984:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c002698b:	89 04 24             	mov    %eax,(%esp)
c002698e:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026995:	89 fa                	mov    %edi,%edx
c0026997:	b8 20 00 00 00       	mov    $0x20,%eax
c002699c:	e8 91 fd ff ff       	call   c0026732 <output_dup>
  if (sign)
c00269a1:	89 f0                	mov    %esi,%eax
c00269a3:	84 c0                	test   %al,%al
c00269a5:	74 19                	je     c00269c0 <format_integer+0x262>
    output (sign, aux);
c00269a7:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269ae:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269b2:	8b 44 24 30          	mov    0x30(%esp),%eax
c00269b6:	89 04 24             	mov    %eax,(%esp)
c00269b9:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (x) 
c00269c0:	83 7c 24 34 00       	cmpl   $0x0,0x34(%esp)
c00269c5:	74 33                	je     c00269fa <format_integer+0x29c>
      output ('0', aux);
c00269c7:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269ce:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269d2:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
c00269d9:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
      output (x, aux); 
c00269e0:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269e7:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269eb:	0f be 44 24 34       	movsbl 0x34(%esp),%eax
c00269f0:	89 04 24             	mov    %eax,(%esp)
c00269f3:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (c->flags & ZERO)
c00269fa:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a01:	f6 00 10             	testb  $0x10,(%eax)
c0026a04:	74 1d                	je     c0026a23 <format_integer+0x2c5>
    output_dup ('0', pad_cnt, output, aux);
c0026a06:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a0d:	89 04 24             	mov    %eax,(%esp)
c0026a10:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a17:	89 fa                	mov    %edi,%edx
c0026a19:	b8 30 00 00 00       	mov    $0x30,%eax
c0026a1e:	e8 0f fd ff ff       	call   c0026732 <output_dup>
  while (cp > buf)
c0026a23:	8d 44 24 40          	lea    0x40(%esp),%eax
c0026a27:	39 c3                	cmp    %eax,%ebx
c0026a29:	76 2b                	jbe    c0026a56 <format_integer+0x2f8>
c0026a2b:	89 c6                	mov    %eax,%esi
c0026a2d:	89 7c 24 18          	mov    %edi,0x18(%esp)
c0026a31:	8b bc 24 ac 00 00 00 	mov    0xac(%esp),%edi
c0026a38:	8b ac 24 b0 00 00 00 	mov    0xb0(%esp),%ebp
    output (*--cp, aux);
c0026a3f:	83 eb 01             	sub    $0x1,%ebx
c0026a42:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0026a46:	0f be 03             	movsbl (%ebx),%eax
c0026a49:	89 04 24             	mov    %eax,(%esp)
c0026a4c:	ff d7                	call   *%edi
  while (cp > buf)
c0026a4e:	39 f3                	cmp    %esi,%ebx
c0026a50:	75 ed                	jne    c0026a3f <format_integer+0x2e1>
c0026a52:	8b 7c 24 18          	mov    0x18(%esp),%edi
  if (c->flags & MINUS)
c0026a56:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a5d:	f6 00 01             	testb  $0x1,(%eax)
c0026a60:	74 1d                	je     c0026a7f <format_integer+0x321>
    output_dup (' ', pad_cnt, output, aux);
c0026a62:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a69:	89 04 24             	mov    %eax,(%esp)
c0026a6c:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a73:	89 fa                	mov    %edi,%edx
c0026a75:	b8 20 00 00 00       	mov    $0x20,%eax
c0026a7a:	e8 b3 fc ff ff       	call   c0026732 <output_dup>
}
c0026a7f:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c0026a85:	5b                   	pop    %ebx
c0026a86:	5e                   	pop    %esi
c0026a87:	5f                   	pop    %edi
c0026a88:	5d                   	pop    %ebp
c0026a89:	c3                   	ret    

c0026a8a <format_string>:
   auxiliary data AUX. */
static void
format_string (const char *string, int length,
               struct printf_conversion *c,
               void (*output) (char, void *), void *aux) 
{
c0026a8a:	55                   	push   %ebp
c0026a8b:	57                   	push   %edi
c0026a8c:	56                   	push   %esi
c0026a8d:	53                   	push   %ebx
c0026a8e:	83 ec 1c             	sub    $0x1c,%esp
c0026a91:	89 c5                	mov    %eax,%ebp
c0026a93:	89 d3                	mov    %edx,%ebx
c0026a95:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026a99:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0026a9d:	8b 74 24 30          	mov    0x30(%esp),%esi
c0026aa1:	8b 7c 24 34          	mov    0x34(%esp),%edi
  int i;
  if (c->width > length && (c->flags & MINUS) == 0)
c0026aa5:	8b 51 04             	mov    0x4(%ecx),%edx
c0026aa8:	39 da                	cmp    %ebx,%edx
c0026aaa:	7e 16                	jle    c0026ac2 <format_string+0x38>
c0026aac:	f6 01 01             	testb  $0x1,(%ecx)
c0026aaf:	75 11                	jne    c0026ac2 <format_string+0x38>
    output_dup (' ', c->width - length, output, aux);
c0026ab1:	29 da                	sub    %ebx,%edx
c0026ab3:	89 3c 24             	mov    %edi,(%esp)
c0026ab6:	89 f1                	mov    %esi,%ecx
c0026ab8:	b8 20 00 00 00       	mov    $0x20,%eax
c0026abd:	e8 70 fc ff ff       	call   c0026732 <output_dup>
  for (i = 0; i < length; i++)
c0026ac2:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026ac6:	85 c0                	test   %eax,%eax
c0026ac8:	7e 17                	jle    c0026ae1 <format_string+0x57>
c0026aca:	89 eb                	mov    %ebp,%ebx
c0026acc:	01 c5                	add    %eax,%ebp
    output (string[i], aux);
c0026ace:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0026ad2:	0f be 03             	movsbl (%ebx),%eax
c0026ad5:	89 04 24             	mov    %eax,(%esp)
c0026ad8:	ff d6                	call   *%esi
c0026ada:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < length; i++)
c0026add:	39 eb                	cmp    %ebp,%ebx
c0026adf:	75 ed                	jne    c0026ace <format_string+0x44>
  if (c->width > length && (c->flags & MINUS) != 0)
c0026ae1:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0026ae5:	8b 50 04             	mov    0x4(%eax),%edx
c0026ae8:	39 54 24 08          	cmp    %edx,0x8(%esp)
c0026aec:	7d 18                	jge    c0026b06 <format_string+0x7c>
c0026aee:	f6 00 01             	testb  $0x1,(%eax)
c0026af1:	74 13                	je     c0026b06 <format_string+0x7c>
    output_dup (' ', c->width - length, output, aux);
c0026af3:	2b 54 24 08          	sub    0x8(%esp),%edx
c0026af7:	89 3c 24             	mov    %edi,(%esp)
c0026afa:	89 f1                	mov    %esi,%ecx
c0026afc:	b8 20 00 00 00       	mov    $0x20,%eax
c0026b01:	e8 2c fc ff ff       	call   c0026732 <output_dup>
}
c0026b06:	83 c4 1c             	add    $0x1c,%esp
c0026b09:	5b                   	pop    %ebx
c0026b0a:	5e                   	pop    %esi
c0026b0b:	5f                   	pop    %edi
c0026b0c:	5d                   	pop    %ebp
c0026b0d:	c3                   	ret    

c0026b0e <printf>:
{
c0026b0e:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0026b11:	8d 44 24 24          	lea    0x24(%esp),%eax
  retval = vprintf (format, args);
c0026b15:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b19:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b1d:	89 04 24             	mov    %eax,(%esp)
c0026b20:	e8 25 3b 00 00       	call   c002a64a <vprintf>
}
c0026b25:	83 c4 1c             	add    $0x1c,%esp
c0026b28:	c3                   	ret    

c0026b29 <__printf>:
/* Wrapper for __vprintf() that converts varargs into a
   va_list. */
void
__printf (const char *format,
          void (*output) (char, void *), void *aux, ...) 
{
c0026b29:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;

  va_start (args, aux);
c0026b2c:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  __vprintf (format, args, output, aux);
c0026b30:	8b 54 24 28          	mov    0x28(%esp),%edx
c0026b34:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0026b38:	8b 54 24 24          	mov    0x24(%esp),%edx
c0026b3c:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026b40:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b44:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b48:	89 04 24             	mov    %eax,(%esp)
c0026b4b:	e8 04 00 00 00       	call   c0026b54 <__vprintf>
  va_end (args);
}
c0026b50:	83 c4 1c             	add    $0x1c,%esp
c0026b53:	c3                   	ret    

c0026b54 <__vprintf>:
{
c0026b54:	55                   	push   %ebp
c0026b55:	57                   	push   %edi
c0026b56:	56                   	push   %esi
c0026b57:	53                   	push   %ebx
c0026b58:	83 ec 5c             	sub    $0x5c,%esp
c0026b5b:	8b 7c 24 70          	mov    0x70(%esp),%edi
c0026b5f:	8b 6c 24 74          	mov    0x74(%esp),%ebp
  for (; *format != '\0'; format++)
c0026b63:	0f b6 07             	movzbl (%edi),%eax
c0026b66:	84 c0                	test   %al,%al
c0026b68:	0f 84 1c 06 00 00    	je     c002718a <__vprintf+0x636>
      if (*format != '%') 
c0026b6e:	3c 25                	cmp    $0x25,%al
c0026b70:	74 19                	je     c0026b8b <__vprintf+0x37>
          output (*format, aux);
c0026b72:	8b 5c 24 7c          	mov    0x7c(%esp),%ebx
c0026b76:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0026b7a:	0f be c0             	movsbl %al,%eax
c0026b7d:	89 04 24             	mov    %eax,(%esp)
c0026b80:	ff 54 24 78          	call   *0x78(%esp)
          continue;
c0026b84:	89 fb                	mov    %edi,%ebx
c0026b86:	e9 d5 05 00 00       	jmp    c0027160 <__vprintf+0x60c>
      format++;
c0026b8b:	8d 77 01             	lea    0x1(%edi),%esi
      if (*format == '%') 
c0026b8e:	b9 00 00 00 00       	mov    $0x0,%ecx
c0026b93:	80 7f 01 25          	cmpb   $0x25,0x1(%edi)
c0026b97:	75 1c                	jne    c0026bb5 <__vprintf+0x61>
          output ('%', aux);
c0026b99:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0026b9d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026ba1:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
c0026ba8:	ff 54 24 78          	call   *0x78(%esp)
      format++;
c0026bac:	89 f3                	mov    %esi,%ebx
          continue;
c0026bae:	e9 ad 05 00 00       	jmp    c0027160 <__vprintf+0x60c>
      switch (*format++) 
c0026bb3:	89 d6                	mov    %edx,%esi
c0026bb5:	8d 56 01             	lea    0x1(%esi),%edx
c0026bb8:	0f b6 5a ff          	movzbl -0x1(%edx),%ebx
c0026bbc:	8d 43 e0             	lea    -0x20(%ebx),%eax
c0026bbf:	3c 10                	cmp    $0x10,%al
c0026bc1:	77 29                	ja     c0026bec <__vprintf+0x98>
c0026bc3:	0f b6 c0             	movzbl %al,%eax
c0026bc6:	ff 24 85 f0 d9 02 c0 	jmp    *-0x3ffd2610(,%eax,4)
          c->flags |= MINUS;
c0026bcd:	83 c9 01             	or     $0x1,%ecx
c0026bd0:	eb e1                	jmp    c0026bb3 <__vprintf+0x5f>
          c->flags |= PLUS;
c0026bd2:	83 c9 02             	or     $0x2,%ecx
c0026bd5:	eb dc                	jmp    c0026bb3 <__vprintf+0x5f>
          c->flags |= SPACE;
c0026bd7:	83 c9 04             	or     $0x4,%ecx
c0026bda:	eb d7                	jmp    c0026bb3 <__vprintf+0x5f>
          c->flags |= POUND;
c0026bdc:	83 c9 08             	or     $0x8,%ecx
c0026bdf:	90                   	nop
c0026be0:	eb d1                	jmp    c0026bb3 <__vprintf+0x5f>
          c->flags |= ZERO;
c0026be2:	83 c9 10             	or     $0x10,%ecx
c0026be5:	eb cc                	jmp    c0026bb3 <__vprintf+0x5f>
          c->flags |= GROUP;
c0026be7:	83 c9 20             	or     $0x20,%ecx
c0026bea:	eb c7                	jmp    c0026bb3 <__vprintf+0x5f>
      switch (*format++) 
c0026bec:	89 f0                	mov    %esi,%eax
c0026bee:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & MINUS)
c0026bf2:	f6 c1 01             	test   $0x1,%cl
c0026bf5:	74 07                	je     c0026bfe <__vprintf+0xaa>
    c->flags &= ~ZERO;
c0026bf7:	83 e1 ef             	and    $0xffffffef,%ecx
c0026bfa:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & PLUS)
c0026bfe:	8b 4c 24 40          	mov    0x40(%esp),%ecx
c0026c02:	f6 c1 02             	test   $0x2,%cl
c0026c05:	74 07                	je     c0026c0e <__vprintf+0xba>
    c->flags &= ~SPACE;
c0026c07:	83 e1 fb             	and    $0xfffffffb,%ecx
c0026c0a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  c->width = 0;
c0026c0e:	c7 44 24 44 00 00 00 	movl   $0x0,0x44(%esp)
c0026c15:	00 
  if (*format == '*')
c0026c16:	80 fb 2a             	cmp    $0x2a,%bl
c0026c19:	74 15                	je     c0026c30 <__vprintf+0xdc>
      for (; isdigit (*format); format++)
c0026c1b:	0f b6 00             	movzbl (%eax),%eax
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0026c1e:	0f be c8             	movsbl %al,%ecx
c0026c21:	83 e9 30             	sub    $0x30,%ecx
c0026c24:	ba 00 00 00 00       	mov    $0x0,%edx
c0026c29:	83 f9 09             	cmp    $0x9,%ecx
c0026c2c:	76 10                	jbe    c0026c3e <__vprintf+0xea>
c0026c2e:	eb 40                	jmp    c0026c70 <__vprintf+0x11c>
      c->width = va_arg (*args, int);
c0026c30:	8b 45 00             	mov    0x0(%ebp),%eax
c0026c33:	89 44 24 44          	mov    %eax,0x44(%esp)
c0026c37:	8d 6d 04             	lea    0x4(%ebp),%ebp
      switch (*format++) 
c0026c3a:	89 d6                	mov    %edx,%esi
c0026c3c:	eb 1f                	jmp    c0026c5d <__vprintf+0x109>
        c->width = c->width * 10 + *format - '0';
c0026c3e:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026c41:	0f be c0             	movsbl %al,%eax
c0026c44:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
      for (; isdigit (*format); format++)
c0026c48:	83 c6 01             	add    $0x1,%esi
c0026c4b:	0f b6 06             	movzbl (%esi),%eax
c0026c4e:	0f be c8             	movsbl %al,%ecx
c0026c51:	83 e9 30             	sub    $0x30,%ecx
c0026c54:	83 f9 09             	cmp    $0x9,%ecx
c0026c57:	76 e5                	jbe    c0026c3e <__vprintf+0xea>
c0026c59:	89 54 24 44          	mov    %edx,0x44(%esp)
  if (c->width < 0) 
c0026c5d:	8b 44 24 44          	mov    0x44(%esp),%eax
c0026c61:	85 c0                	test   %eax,%eax
c0026c63:	79 0b                	jns    c0026c70 <__vprintf+0x11c>
      c->width = -c->width;
c0026c65:	f7 d8                	neg    %eax
c0026c67:	89 44 24 44          	mov    %eax,0x44(%esp)
      c->flags |= MINUS;
c0026c6b:	83 4c 24 40 01       	orl    $0x1,0x40(%esp)
  c->precision = -1;
c0026c70:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026c77:	ff 
  if (*format == '.') 
c0026c78:	80 3e 2e             	cmpb   $0x2e,(%esi)
c0026c7b:	0f 85 f0 04 00 00    	jne    c0027171 <__vprintf+0x61d>
      if (*format == '*') 
c0026c81:	80 7e 01 2a          	cmpb   $0x2a,0x1(%esi)
c0026c85:	75 0f                	jne    c0026c96 <__vprintf+0x142>
          format++;
c0026c87:	83 c6 02             	add    $0x2,%esi
          c->precision = va_arg (*args, int);
c0026c8a:	8b 45 00             	mov    0x0(%ebp),%eax
c0026c8d:	89 44 24 48          	mov    %eax,0x48(%esp)
c0026c91:	8d 6d 04             	lea    0x4(%ebp),%ebp
c0026c94:	eb 44                	jmp    c0026cda <__vprintf+0x186>
      format++;
c0026c96:	8d 56 01             	lea    0x1(%esi),%edx
          c->precision = 0;
c0026c99:	c7 44 24 48 00 00 00 	movl   $0x0,0x48(%esp)
c0026ca0:	00 
          for (; isdigit (*format); format++)
c0026ca1:	0f b6 46 01          	movzbl 0x1(%esi),%eax
c0026ca5:	0f be c8             	movsbl %al,%ecx
c0026ca8:	83 e9 30             	sub    $0x30,%ecx
c0026cab:	83 f9 09             	cmp    $0x9,%ecx
c0026cae:	0f 87 c6 04 00 00    	ja     c002717a <__vprintf+0x626>
c0026cb4:	b9 00 00 00 00       	mov    $0x0,%ecx
            c->precision = c->precision * 10 + *format - '0';
c0026cb9:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0026cbc:	0f be c0             	movsbl %al,%eax
c0026cbf:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
          for (; isdigit (*format); format++)
c0026cc3:	83 c2 01             	add    $0x1,%edx
c0026cc6:	0f b6 02             	movzbl (%edx),%eax
c0026cc9:	0f be d8             	movsbl %al,%ebx
c0026ccc:	83 eb 30             	sub    $0x30,%ebx
c0026ccf:	83 fb 09             	cmp    $0x9,%ebx
c0026cd2:	76 e5                	jbe    c0026cb9 <__vprintf+0x165>
c0026cd4:	89 4c 24 48          	mov    %ecx,0x48(%esp)
c0026cd8:	89 d6                	mov    %edx,%esi
      if (c->precision < 0) 
c0026cda:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0026cdf:	0f 89 97 04 00 00    	jns    c002717c <__vprintf+0x628>
        c->precision = -1;
c0026ce5:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026cec:	ff 
c0026ced:	e9 7f 04 00 00       	jmp    c0027171 <__vprintf+0x61d>
  c->type = INT;
c0026cf2:	c7 44 24 4c 03 00 00 	movl   $0x3,0x4c(%esp)
c0026cf9:	00 
  switch (*format++) 
c0026cfa:	8d 5e 01             	lea    0x1(%esi),%ebx
c0026cfd:	0f b6 3e             	movzbl (%esi),%edi
c0026d00:	8d 57 98             	lea    -0x68(%edi),%edx
c0026d03:	80 fa 12             	cmp    $0x12,%dl
c0026d06:	77 62                	ja     c0026d6a <__vprintf+0x216>
c0026d08:	0f b6 d2             	movzbl %dl,%edx
c0026d0b:	ff 24 95 34 da 02 c0 	jmp    *-0x3ffd25cc(,%edx,4)
      if (*format == 'h') 
c0026d12:	80 7e 01 68          	cmpb   $0x68,0x1(%esi)
c0026d16:	75 0d                	jne    c0026d25 <__vprintf+0x1d1>
          format++;
c0026d18:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = CHAR;
c0026d1b:	c7 44 24 4c 01 00 00 	movl   $0x1,0x4c(%esp)
c0026d22:	00 
c0026d23:	eb 47                	jmp    c0026d6c <__vprintf+0x218>
        c->type = SHORT;
c0026d25:	c7 44 24 4c 02 00 00 	movl   $0x2,0x4c(%esp)
c0026d2c:	00 
c0026d2d:	eb 3d                	jmp    c0026d6c <__vprintf+0x218>
      c->type = INTMAX;
c0026d2f:	c7 44 24 4c 04 00 00 	movl   $0x4,0x4c(%esp)
c0026d36:	00 
c0026d37:	eb 33                	jmp    c0026d6c <__vprintf+0x218>
      if (*format == 'l')
c0026d39:	80 7e 01 6c          	cmpb   $0x6c,0x1(%esi)
c0026d3d:	75 0d                	jne    c0026d4c <__vprintf+0x1f8>
          format++;
c0026d3f:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = LONGLONG;
c0026d42:	c7 44 24 4c 06 00 00 	movl   $0x6,0x4c(%esp)
c0026d49:	00 
c0026d4a:	eb 20                	jmp    c0026d6c <__vprintf+0x218>
        c->type = LONG;
c0026d4c:	c7 44 24 4c 05 00 00 	movl   $0x5,0x4c(%esp)
c0026d53:	00 
c0026d54:	eb 16                	jmp    c0026d6c <__vprintf+0x218>
      c->type = PTRDIFFT;
c0026d56:	c7 44 24 4c 07 00 00 	movl   $0x7,0x4c(%esp)
c0026d5d:	00 
c0026d5e:	eb 0c                	jmp    c0026d6c <__vprintf+0x218>
      c->type = SIZET;
c0026d60:	c7 44 24 4c 08 00 00 	movl   $0x8,0x4c(%esp)
c0026d67:	00 
c0026d68:	eb 02                	jmp    c0026d6c <__vprintf+0x218>
  switch (*format++) 
c0026d6a:	89 f3                	mov    %esi,%ebx
      switch (*format) 
c0026d6c:	0f b6 0b             	movzbl (%ebx),%ecx
c0026d6f:	8d 51 bb             	lea    -0x45(%ecx),%edx
c0026d72:	80 fa 33             	cmp    $0x33,%dl
c0026d75:	0f 87 c2 03 00 00    	ja     c002713d <__vprintf+0x5e9>
c0026d7b:	0f b6 d2             	movzbl %dl,%edx
c0026d7e:	ff 24 95 80 da 02 c0 	jmp    *-0x3ffd2580(,%edx,4)
            switch (c.type) 
c0026d85:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026d8a:	0f 87 c9 00 00 00    	ja     c0026e59 <__vprintf+0x305>
c0026d90:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026d94:	ff 24 85 50 db 02 c0 	jmp    *-0x3ffd24b0(,%eax,4)
                value = (signed char) va_arg (args, int);
c0026d9b:	0f be 75 00          	movsbl 0x0(%ebp),%esi
c0026d9f:	89 f0                	mov    %esi,%eax
c0026da1:	99                   	cltd   
c0026da2:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026da6:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026daa:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dad:	e9 cb 00 00 00       	jmp    c0026e7d <__vprintf+0x329>
                value = (short) va_arg (args, int);
c0026db2:	0f bf 75 00          	movswl 0x0(%ebp),%esi
c0026db6:	89 f0                	mov    %esi,%eax
c0026db8:	99                   	cltd   
c0026db9:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026dbd:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026dc1:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dc4:	e9 b4 00 00 00       	jmp    c0026e7d <__vprintf+0x329>
                value = va_arg (args, int);
c0026dc9:	8b 75 00             	mov    0x0(%ebp),%esi
c0026dcc:	89 f0                	mov    %esi,%eax
c0026dce:	99                   	cltd   
c0026dcf:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026dd3:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026dd7:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dda:	e9 9e 00 00 00       	jmp    c0026e7d <__vprintf+0x329>
                value = va_arg (args, intmax_t);
c0026ddf:	8b 45 00             	mov    0x0(%ebp),%eax
c0026de2:	8b 55 04             	mov    0x4(%ebp),%edx
c0026de5:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026de9:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026ded:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026df0:	e9 88 00 00 00       	jmp    c0026e7d <__vprintf+0x329>
                value = va_arg (args, long);
c0026df5:	8b 75 00             	mov    0x0(%ebp),%esi
c0026df8:	89 f0                	mov    %esi,%eax
c0026dfa:	99                   	cltd   
c0026dfb:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026dff:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e03:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e06:	eb 75                	jmp    c0026e7d <__vprintf+0x329>
                value = va_arg (args, long long);
c0026e08:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e0b:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e0e:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e12:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e16:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e19:	eb 62                	jmp    c0026e7d <__vprintf+0x329>
                value = va_arg (args, ptrdiff_t);
c0026e1b:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e1e:	89 f0                	mov    %esi,%eax
c0026e20:	99                   	cltd   
c0026e21:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e25:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e29:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e2c:	eb 4f                	jmp    c0026e7d <__vprintf+0x329>
                value = va_arg (args, size_t);
c0026e2e:	8d 45 04             	lea    0x4(%ebp),%eax
                if (value > SIZE_MAX / 2)
c0026e31:	8b 7d 00             	mov    0x0(%ebp),%edi
c0026e34:	bd 00 00 00 00       	mov    $0x0,%ebp
c0026e39:	89 fe                	mov    %edi,%esi
c0026e3b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e3f:	89 6c 24 1c          	mov    %ebp,0x1c(%esp)
                value = va_arg (args, size_t);
c0026e43:	89 c5                	mov    %eax,%ebp
                if (value > SIZE_MAX / 2)
c0026e45:	81 fe ff ff ff 7f    	cmp    $0x7fffffff,%esi
c0026e4b:	76 30                	jbe    c0026e7d <__vprintf+0x329>
                  value = value - SIZE_MAX - 1;
c0026e4d:	83 44 24 18 00       	addl   $0x0,0x18(%esp)
c0026e52:	83 54 24 1c ff       	adcl   $0xffffffff,0x1c(%esp)
c0026e57:	eb 24                	jmp    c0026e7d <__vprintf+0x329>
                NOT_REACHED ();
c0026e59:	c7 44 24 0c f8 e5 02 	movl   $0xc002e5f8,0xc(%esp)
c0026e60:	c0 
c0026e61:	c7 44 24 08 98 db 02 	movl   $0xc002db98,0x8(%esp)
c0026e68:	c0 
c0026e69:	c7 44 24 04 dc 00 00 	movl   $0xdc,0x4(%esp)
c0026e70:	00 
c0026e71:	c7 04 24 25 f8 02 c0 	movl   $0xc002f825,(%esp)
c0026e78:	e8 e6 1a 00 00       	call   c0028963 <debug_panic>
            format_integer (value < 0 ? -value : value,
c0026e7d:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0026e81:	c1 fa 1f             	sar    $0x1f,%edx
c0026e84:	89 d7                	mov    %edx,%edi
c0026e86:	33 7c 24 18          	xor    0x18(%esp),%edi
c0026e8a:	89 7c 24 20          	mov    %edi,0x20(%esp)
c0026e8e:	89 d7                	mov    %edx,%edi
c0026e90:	33 7c 24 1c          	xor    0x1c(%esp),%edi
c0026e94:	89 7c 24 24          	mov    %edi,0x24(%esp)
c0026e98:	8b 74 24 20          	mov    0x20(%esp),%esi
c0026e9c:	8b 7c 24 24          	mov    0x24(%esp),%edi
c0026ea0:	29 d6                	sub    %edx,%esi
c0026ea2:	19 d7                	sbb    %edx,%edi
c0026ea4:	89 f0                	mov    %esi,%eax
c0026ea6:	89 fa                	mov    %edi,%edx
c0026ea8:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0026eac:	89 7c 24 10          	mov    %edi,0x10(%esp)
c0026eb0:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0026eb4:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0026eb8:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0026ebc:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0026ec0:	c7 44 24 04 d4 db 02 	movl   $0xc002dbd4,0x4(%esp)
c0026ec7:	c0 
c0026ec8:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0026ecc:	c1 e9 1f             	shr    $0x1f,%ecx
c0026ecf:	89 0c 24             	mov    %ecx,(%esp)
c0026ed2:	b9 01 00 00 00       	mov    $0x1,%ecx
c0026ed7:	e8 82 f8 ff ff       	call   c002675e <format_integer>
          break;
c0026edc:	e9 7f 02 00 00       	jmp    c0027160 <__vprintf+0x60c>
            switch (c.type) 
c0026ee1:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026ee6:	0f 87 b7 00 00 00    	ja     c0026fa3 <__vprintf+0x44f>
c0026eec:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026ef0:	ff 24 85 74 db 02 c0 	jmp    *-0x3ffd248c(,%eax,4)
                value = (unsigned char) va_arg (args, unsigned);
c0026ef7:	0f b6 45 00          	movzbl 0x0(%ebp),%eax
c0026efb:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026eff:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f06:	00 
c0026f07:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f0a:	e9 b8 00 00 00       	jmp    c0026fc7 <__vprintf+0x473>
                value = (unsigned short) va_arg (args, unsigned);
c0026f0f:	0f b7 45 00          	movzwl 0x0(%ebp),%eax
c0026f13:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f17:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f1e:	00 
c0026f1f:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f22:	e9 a0 00 00 00       	jmp    c0026fc7 <__vprintf+0x473>
                value = va_arg (args, unsigned);
c0026f27:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f2a:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f2f:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f33:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f37:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f3a:	e9 88 00 00 00       	jmp    c0026fc7 <__vprintf+0x473>
                value = va_arg (args, uintmax_t);
c0026f3f:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f42:	8b 55 04             	mov    0x4(%ebp),%edx
c0026f45:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f49:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f4d:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026f50:	eb 75                	jmp    c0026fc7 <__vprintf+0x473>
                value = va_arg (args, unsigned long);
c0026f52:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f55:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f5a:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f5e:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f62:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f65:	eb 60                	jmp    c0026fc7 <__vprintf+0x473>
                value = va_arg (args, unsigned long long);
c0026f67:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f6a:	8b 55 04             	mov    0x4(%ebp),%edx
c0026f6d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f71:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f75:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026f78:	eb 4d                	jmp    c0026fc7 <__vprintf+0x473>
                value &= ((uintmax_t) PTRDIFF_MAX << 1) | 1;
c0026f7a:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f7d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f81:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f88:	00 
                value = va_arg (args, ptrdiff_t);
c0026f89:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f8c:	eb 39                	jmp    c0026fc7 <__vprintf+0x473>
                value = va_arg (args, size_t);
c0026f8e:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f91:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f96:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f9a:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f9e:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fa1:	eb 24                	jmp    c0026fc7 <__vprintf+0x473>
                NOT_REACHED ();
c0026fa3:	c7 44 24 0c f8 e5 02 	movl   $0xc002e5f8,0xc(%esp)
c0026faa:	c0 
c0026fab:	c7 44 24 08 98 db 02 	movl   $0xc002db98,0x8(%esp)
c0026fb2:	c0 
c0026fb3:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0026fba:	00 
c0026fbb:	c7 04 24 25 f8 02 c0 	movl   $0xc002f825,(%esp)
c0026fc2:	e8 9c 19 00 00       	call   c0028963 <debug_panic>
            switch (*format) 
c0026fc7:	80 f9 6f             	cmp    $0x6f,%cl
c0026fca:	74 4d                	je     c0027019 <__vprintf+0x4c5>
c0026fcc:	80 f9 6f             	cmp    $0x6f,%cl
c0026fcf:	7f 07                	jg     c0026fd8 <__vprintf+0x484>
c0026fd1:	80 f9 58             	cmp    $0x58,%cl
c0026fd4:	74 18                	je     c0026fee <__vprintf+0x49a>
c0026fd6:	eb 1d                	jmp    c0026ff5 <__vprintf+0x4a1>
c0026fd8:	80 f9 75             	cmp    $0x75,%cl
c0026fdb:	90                   	nop
c0026fdc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0026fe0:	74 3e                	je     c0027020 <__vprintf+0x4cc>
c0026fe2:	80 f9 78             	cmp    $0x78,%cl
c0026fe5:	75 0e                	jne    c0026ff5 <__vprintf+0x4a1>
              case 'x': b = &base_x; break;
c0026fe7:	b8 b4 db 02 c0       	mov    $0xc002dbb4,%eax
c0026fec:	eb 37                	jmp    c0027025 <__vprintf+0x4d1>
              case 'X': b = &base_X; break;
c0026fee:	b8 a4 db 02 c0       	mov    $0xc002dba4,%eax
c0026ff3:	eb 30                	jmp    c0027025 <__vprintf+0x4d1>
              default: NOT_REACHED ();
c0026ff5:	c7 44 24 0c f8 e5 02 	movl   $0xc002e5f8,0xc(%esp)
c0026ffc:	c0 
c0026ffd:	c7 44 24 08 98 db 02 	movl   $0xc002db98,0x8(%esp)
c0027004:	c0 
c0027005:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
c002700c:	00 
c002700d:	c7 04 24 25 f8 02 c0 	movl   $0xc002f825,(%esp)
c0027014:	e8 4a 19 00 00       	call   c0028963 <debug_panic>
              case 'o': b = &base_o; break;
c0027019:	b8 c4 db 02 c0       	mov    $0xc002dbc4,%eax
c002701e:	eb 05                	jmp    c0027025 <__vprintf+0x4d1>
              case 'u': b = &base_d; break;
c0027020:	b8 d4 db 02 c0       	mov    $0xc002dbd4,%eax
            format_integer (value, false, false, b, &c, output, aux);
c0027025:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027029:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002702d:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0027031:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027035:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027039:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002703d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027041:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0027048:	b9 00 00 00 00       	mov    $0x0,%ecx
c002704d:	8b 44 24 28          	mov    0x28(%esp),%eax
c0027051:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c0027055:	e8 04 f7 ff ff       	call   c002675e <format_integer>
          break;
c002705a:	e9 01 01 00 00       	jmp    c0027160 <__vprintf+0x60c>
            char ch = va_arg (args, int);
c002705f:	8d 75 04             	lea    0x4(%ebp),%esi
c0027062:	8b 45 00             	mov    0x0(%ebp),%eax
c0027065:	88 44 24 3f          	mov    %al,0x3f(%esp)
            format_string (&ch, 1, &c, output, aux);
c0027069:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c002706d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027071:	8b 44 24 78          	mov    0x78(%esp),%eax
c0027075:	89 04 24             	mov    %eax,(%esp)
c0027078:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c002707c:	ba 01 00 00 00       	mov    $0x1,%edx
c0027081:	8d 44 24 3f          	lea    0x3f(%esp),%eax
c0027085:	e8 00 fa ff ff       	call   c0026a8a <format_string>
            char ch = va_arg (args, int);
c002708a:	89 f5                	mov    %esi,%ebp
          break;
c002708c:	e9 cf 00 00 00       	jmp    c0027160 <__vprintf+0x60c>
            const char *s = va_arg (args, char *);
c0027091:	8d 75 04             	lea    0x4(%ebp),%esi
c0027094:	8b 7d 00             	mov    0x0(%ebp),%edi
              s = "(null)";
c0027097:	85 ff                	test   %edi,%edi
c0027099:	ba 1e f8 02 c0       	mov    $0xc002f81e,%edx
c002709e:	0f 44 fa             	cmove  %edx,%edi
            format_string (s, strnlen (s, c.precision), &c, output, aux);
c00270a1:	89 44 24 04          	mov    %eax,0x4(%esp)
c00270a5:	89 3c 24             	mov    %edi,(%esp)
c00270a8:	e8 9d 0e 00 00       	call   c0027f4a <strnlen>
c00270ad:	8b 4c 24 7c          	mov    0x7c(%esp),%ecx
c00270b1:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00270b5:	8b 4c 24 78          	mov    0x78(%esp),%ecx
c00270b9:	89 0c 24             	mov    %ecx,(%esp)
c00270bc:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c00270c0:	89 c2                	mov    %eax,%edx
c00270c2:	89 f8                	mov    %edi,%eax
c00270c4:	e8 c1 f9 ff ff       	call   c0026a8a <format_string>
            const char *s = va_arg (args, char *);
c00270c9:	89 f5                	mov    %esi,%ebp
          break;
c00270cb:	e9 90 00 00 00       	jmp    c0027160 <__vprintf+0x60c>
            void *p = va_arg (args, void *);
c00270d0:	8d 75 04             	lea    0x4(%ebp),%esi
c00270d3:	8b 45 00             	mov    0x0(%ebp),%eax
            c.flags = POUND;
c00270d6:	c7 44 24 40 08 00 00 	movl   $0x8,0x40(%esp)
c00270dd:	00 
            format_integer ((uintptr_t) p, false, false,
c00270de:	ba 00 00 00 00       	mov    $0x0,%edx
c00270e3:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c00270e7:	89 7c 24 10          	mov    %edi,0x10(%esp)
c00270eb:	8b 7c 24 78          	mov    0x78(%esp),%edi
c00270ef:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00270f3:	8d 7c 24 40          	lea    0x40(%esp),%edi
c00270f7:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00270fb:	c7 44 24 04 b4 db 02 	movl   $0xc002dbb4,0x4(%esp)
c0027102:	c0 
c0027103:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002710a:	b9 00 00 00 00       	mov    $0x0,%ecx
c002710f:	e8 4a f6 ff ff       	call   c002675e <format_integer>
            void *p = va_arg (args, void *);
c0027114:	89 f5                	mov    %esi,%ebp
          break;
c0027116:	eb 48                	jmp    c0027160 <__vprintf+0x60c>
          __printf ("<<no %%%c in kernel>>", output, aux, *format);
c0027118:	0f be c9             	movsbl %cl,%ecx
c002711b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002711f:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027123:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027127:	8b 44 24 78          	mov    0x78(%esp),%eax
c002712b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002712f:	c7 04 24 37 f8 02 c0 	movl   $0xc002f837,(%esp)
c0027136:	e8 ee f9 ff ff       	call   c0026b29 <__printf>
          break;
c002713b:	eb 23                	jmp    c0027160 <__vprintf+0x60c>
          __printf ("<<no %%%c conversion>>", output, aux, *format);
c002713d:	0f be c9             	movsbl %cl,%ecx
c0027140:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0027144:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027148:	89 44 24 08          	mov    %eax,0x8(%esp)
c002714c:	8b 44 24 78          	mov    0x78(%esp),%eax
c0027150:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027154:	c7 04 24 4d f8 02 c0 	movl   $0xc002f84d,(%esp)
c002715b:	e8 c9 f9 ff ff       	call   c0026b29 <__printf>
  for (; *format != '\0'; format++)
c0027160:	8d 7b 01             	lea    0x1(%ebx),%edi
c0027163:	0f b6 43 01          	movzbl 0x1(%ebx),%eax
c0027167:	84 c0                	test   %al,%al
c0027169:	0f 85 ff f9 ff ff    	jne    c0026b6e <__vprintf+0x1a>
c002716f:	eb 19                	jmp    c002718a <__vprintf+0x636>
  if (c->precision >= 0)
c0027171:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027175:	e9 78 fb ff ff       	jmp    c0026cf2 <__vprintf+0x19e>
      format++;
c002717a:	89 d6                	mov    %edx,%esi
  if (c->precision >= 0)
c002717c:	8b 44 24 48          	mov    0x48(%esp),%eax
    c->flags &= ~ZERO;
c0027180:	83 64 24 40 ef       	andl   $0xffffffef,0x40(%esp)
c0027185:	e9 68 fb ff ff       	jmp    c0026cf2 <__vprintf+0x19e>
}
c002718a:	83 c4 5c             	add    $0x5c,%esp
c002718d:	5b                   	pop    %ebx
c002718e:	5e                   	pop    %esi
c002718f:	5f                   	pop    %edi
c0027190:	5d                   	pop    %ebp
c0027191:	c3                   	ret    

c0027192 <vsnprintf>:
{
c0027192:	53                   	push   %ebx
c0027193:	83 ec 28             	sub    $0x28,%esp
c0027196:	8b 44 24 34          	mov    0x34(%esp),%eax
c002719a:	8b 54 24 38          	mov    0x38(%esp),%edx
c002719e:	8b 4c 24 3c          	mov    0x3c(%esp),%ecx
  aux.p = buffer;
c00271a2:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00271a6:	89 5c 24 14          	mov    %ebx,0x14(%esp)
  aux.length = 0;
c00271aa:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c00271b1:	00 
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c00271b2:	85 c0                	test   %eax,%eax
c00271b4:	74 2c                	je     c00271e2 <vsnprintf+0x50>
c00271b6:	83 e8 01             	sub    $0x1,%eax
c00271b9:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  __vprintf (format, args, vsnprintf_helper, &aux);
c00271bd:	8d 44 24 14          	lea    0x14(%esp),%eax
c00271c1:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00271c5:	c7 44 24 08 10 67 02 	movl   $0xc0026710,0x8(%esp)
c00271cc:	c0 
c00271cd:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00271d1:	89 14 24             	mov    %edx,(%esp)
c00271d4:	e8 7b f9 ff ff       	call   c0026b54 <__vprintf>
    *aux.p = '\0';
c00271d9:	8b 44 24 14          	mov    0x14(%esp),%eax
c00271dd:	c6 00 00             	movb   $0x0,(%eax)
c00271e0:	eb 24                	jmp    c0027206 <vsnprintf+0x74>
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c00271e2:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c00271e9:	00 
  __vprintf (format, args, vsnprintf_helper, &aux);
c00271ea:	8d 44 24 14          	lea    0x14(%esp),%eax
c00271ee:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00271f2:	c7 44 24 08 10 67 02 	movl   $0xc0026710,0x8(%esp)
c00271f9:	c0 
c00271fa:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00271fe:	89 14 24             	mov    %edx,(%esp)
c0027201:	e8 4e f9 ff ff       	call   c0026b54 <__vprintf>
  return aux.length;
c0027206:	8b 44 24 18          	mov    0x18(%esp),%eax
}
c002720a:	83 c4 28             	add    $0x28,%esp
c002720d:	5b                   	pop    %ebx
c002720e:	c3                   	ret    

c002720f <snprintf>:
{
c002720f:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0027212:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  retval = vsnprintf (buffer, buf_size, format, args);
c0027216:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002721a:	8b 44 24 28          	mov    0x28(%esp),%eax
c002721e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027222:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027226:	89 44 24 04          	mov    %eax,0x4(%esp)
c002722a:	8b 44 24 20          	mov    0x20(%esp),%eax
c002722e:	89 04 24             	mov    %eax,(%esp)
c0027231:	e8 5c ff ff ff       	call   c0027192 <vsnprintf>
}
c0027236:	83 c4 1c             	add    $0x1c,%esp
c0027239:	c3                   	ret    

c002723a <hex_dump>:
   starting at OFS for the first byte in BUF.  If ASCII is true
   then the corresponding ASCII characters are also rendered
   alongside. */   
void
hex_dump (uintptr_t ofs, const void *buf_, size_t size, bool ascii)
{
c002723a:	55                   	push   %ebp
c002723b:	57                   	push   %edi
c002723c:	56                   	push   %esi
c002723d:	53                   	push   %ebx
c002723e:	83 ec 2c             	sub    $0x2c,%esp
c0027241:	0f b6 44 24 4c       	movzbl 0x4c(%esp),%eax
c0027246:	88 44 24 1f          	mov    %al,0x1f(%esp)
  const uint8_t *buf = buf_;
  const size_t per_line = 16; /* Maximum bytes per line. */

  while (size > 0)
c002724a:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c002724f:	0f 84 7c 01 00 00    	je     c00273d1 <hex_dump+0x197>
    {
      size_t start, end, n;
      size_t i;
      
      /* Number of bytes on this line. */
      start = ofs % per_line;
c0027255:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0027259:	83 e7 0f             	and    $0xf,%edi
      end = per_line;
      if (end - start > size)
c002725c:	b8 10 00 00 00       	mov    $0x10,%eax
c0027261:	29 f8                	sub    %edi,%eax
        end = start + size;
c0027263:	89 fe                	mov    %edi,%esi
c0027265:	03 74 24 48          	add    0x48(%esp),%esi
c0027269:	3b 44 24 48          	cmp    0x48(%esp),%eax
c002726d:	b8 10 00 00 00       	mov    $0x10,%eax
c0027272:	0f 46 f0             	cmovbe %eax,%esi
      n = end - start;
c0027275:	89 f0                	mov    %esi,%eax
c0027277:	29 f8                	sub    %edi,%eax
c0027279:	89 44 24 18          	mov    %eax,0x18(%esp)

      /* Print line. */
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
c002727d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0027281:	83 e0 f0             	and    $0xfffffff0,%eax
c0027284:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027288:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c002728f:	00 
c0027290:	c7 04 24 64 f8 02 c0 	movl   $0xc002f864,(%esp)
c0027297:	e8 72 f8 ff ff       	call   c0026b0e <printf>
      for (i = 0; i < start; i++)
c002729c:	85 ff                	test   %edi,%edi
c002729e:	74 1a                	je     c00272ba <hex_dump+0x80>
c00272a0:	bb 00 00 00 00       	mov    $0x0,%ebx
        printf ("   ");
c00272a5:	c7 04 24 6c f8 02 c0 	movl   $0xc002f86c,(%esp)
c00272ac:	e8 5d f8 ff ff       	call   c0026b0e <printf>
      for (i = 0; i < start; i++)
c00272b1:	83 c3 01             	add    $0x1,%ebx
c00272b4:	39 fb                	cmp    %edi,%ebx
c00272b6:	75 ed                	jne    c00272a5 <hex_dump+0x6b>
c00272b8:	eb 08                	jmp    c00272c2 <hex_dump+0x88>
c00272ba:	89 fb                	mov    %edi,%ebx
c00272bc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c00272c0:	eb 02                	jmp    c00272c4 <hex_dump+0x8a>
c00272c2:	89 fb                	mov    %edi,%ebx
      for (; i < end; i++) 
c00272c4:	39 de                	cmp    %ebx,%esi
c00272c6:	76 38                	jbe    c0027300 <hex_dump+0xc6>
c00272c8:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00272cc:	29 fd                	sub    %edi,%ebp
        printf ("%02hhx%c",
c00272ce:	83 fb 07             	cmp    $0x7,%ebx
c00272d1:	b8 2d 00 00 00       	mov    $0x2d,%eax
c00272d6:	b9 20 00 00 00       	mov    $0x20,%ecx
c00272db:	0f 45 c1             	cmovne %ecx,%eax
c00272de:	89 44 24 08          	mov    %eax,0x8(%esp)
c00272e2:	0f b6 44 1d 00       	movzbl 0x0(%ebp,%ebx,1),%eax
c00272e7:	89 44 24 04          	mov    %eax,0x4(%esp)
c00272eb:	c7 04 24 70 f8 02 c0 	movl   $0xc002f870,(%esp)
c00272f2:	e8 17 f8 ff ff       	call   c0026b0e <printf>
      for (; i < end; i++) 
c00272f7:	83 c3 01             	add    $0x1,%ebx
c00272fa:	39 de                	cmp    %ebx,%esi
c00272fc:	77 d0                	ja     c00272ce <hex_dump+0x94>
c00272fe:	89 f3                	mov    %esi,%ebx
                buf[i - start], i == per_line / 2 - 1? '-' : ' ');
      if (ascii) 
c0027300:	80 7c 24 1f 00       	cmpb   $0x0,0x1f(%esp)
c0027305:	0f 84 a4 00 00 00    	je     c00273af <hex_dump+0x175>
        {
          for (; i < per_line; i++)
c002730b:	83 fb 0f             	cmp    $0xf,%ebx
c002730e:	77 14                	ja     c0027324 <hex_dump+0xea>
            printf ("   ");
c0027310:	c7 04 24 6c f8 02 c0 	movl   $0xc002f86c,(%esp)
c0027317:	e8 f2 f7 ff ff       	call   c0026b0e <printf>
          for (; i < per_line; i++)
c002731c:	83 c3 01             	add    $0x1,%ebx
c002731f:	83 fb 10             	cmp    $0x10,%ebx
c0027322:	75 ec                	jne    c0027310 <hex_dump+0xd6>
          printf ("|");
c0027324:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c002732b:	e8 cc 33 00 00       	call   c002a6fc <putchar>
          for (i = 0; i < start; i++)
c0027330:	85 ff                	test   %edi,%edi
c0027332:	74 1a                	je     c002734e <hex_dump+0x114>
c0027334:	bb 00 00 00 00       	mov    $0x0,%ebx
            printf (" ");
c0027339:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0027340:	e8 b7 33 00 00       	call   c002a6fc <putchar>
          for (i = 0; i < start; i++)
c0027345:	83 c3 01             	add    $0x1,%ebx
c0027348:	39 fb                	cmp    %edi,%ebx
c002734a:	75 ed                	jne    c0027339 <hex_dump+0xff>
c002734c:	eb 04                	jmp    c0027352 <hex_dump+0x118>
c002734e:	89 fb                	mov    %edi,%ebx
c0027350:	eb 02                	jmp    c0027354 <hex_dump+0x11a>
c0027352:	89 fb                	mov    %edi,%ebx
          for (; i < end; i++)
c0027354:	39 de                	cmp    %ebx,%esi
c0027356:	76 30                	jbe    c0027388 <hex_dump+0x14e>
c0027358:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c002735c:	29 fd                	sub    %edi,%ebp
            printf ("%c",
c002735e:	bf 2e 00 00 00       	mov    $0x2e,%edi
                    isprint (buf[i - start]) ? buf[i - start] : '.');
c0027363:	0f b6 54 1d 00       	movzbl 0x0(%ebp,%ebx,1),%edx
static inline int isprint (int c) { return c >= 32 && c < 127; }
c0027368:	0f b6 c2             	movzbl %dl,%eax
            printf ("%c",
c002736b:	8d 40 e0             	lea    -0x20(%eax),%eax
c002736e:	0f b6 d2             	movzbl %dl,%edx
c0027371:	83 f8 5e             	cmp    $0x5e,%eax
c0027374:	0f 47 d7             	cmova  %edi,%edx
c0027377:	89 14 24             	mov    %edx,(%esp)
c002737a:	e8 7d 33 00 00       	call   c002a6fc <putchar>
          for (; i < end; i++)
c002737f:	83 c3 01             	add    $0x1,%ebx
c0027382:	39 de                	cmp    %ebx,%esi
c0027384:	77 dd                	ja     c0027363 <hex_dump+0x129>
c0027386:	eb 02                	jmp    c002738a <hex_dump+0x150>
c0027388:	89 de                	mov    %ebx,%esi
          for (; i < per_line; i++)
c002738a:	83 fe 0f             	cmp    $0xf,%esi
c002738d:	77 14                	ja     c00273a3 <hex_dump+0x169>
            printf (" ");
c002738f:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0027396:	e8 61 33 00 00       	call   c002a6fc <putchar>
          for (; i < per_line; i++)
c002739b:	83 c6 01             	add    $0x1,%esi
c002739e:	83 fe 10             	cmp    $0x10,%esi
c00273a1:	75 ec                	jne    c002738f <hex_dump+0x155>
          printf ("|");
c00273a3:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c00273aa:	e8 4d 33 00 00       	call   c002a6fc <putchar>
        }
      printf ("\n");
c00273af:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00273b6:	e8 41 33 00 00       	call   c002a6fc <putchar>

      ofs += n;
c00273bb:	8b 44 24 18          	mov    0x18(%esp),%eax
c00273bf:	01 44 24 40          	add    %eax,0x40(%esp)
      buf += n;
c00273c3:	01 44 24 44          	add    %eax,0x44(%esp)
  while (size > 0)
c00273c7:	29 44 24 48          	sub    %eax,0x48(%esp)
c00273cb:	0f 85 84 fe ff ff    	jne    c0027255 <hex_dump+0x1b>
      size -= n;
    }
}
c00273d1:	83 c4 2c             	add    $0x2c,%esp
c00273d4:	5b                   	pop    %ebx
c00273d5:	5e                   	pop    %esi
c00273d6:	5f                   	pop    %edi
c00273d7:	5d                   	pop    %ebp
c00273d8:	c3                   	ret    

c00273d9 <print_human_readable_size>:

/* Prints SIZE, which represents a number of bytes, in a
   human-readable format, e.g. "256 kB". */
void
print_human_readable_size (uint64_t size) 
{
c00273d9:	56                   	push   %esi
c00273da:	53                   	push   %ebx
c00273db:	83 ec 14             	sub    $0x14,%esp
c00273de:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c00273e2:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (size == 1)
c00273e6:	89 c8                	mov    %ecx,%eax
c00273e8:	83 f0 01             	xor    $0x1,%eax
c00273eb:	09 d8                	or     %ebx,%eax
c00273ed:	74 22                	je     c0027411 <print_human_readable_size+0x38>
  else 
    {
      static const char *factors[] = {"bytes", "kB", "MB", "GB", "TB", NULL};
      const char **fp;

      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c00273ef:	83 fb 00             	cmp    $0x0,%ebx
c00273f2:	77 0d                	ja     c0027401 <print_human_readable_size+0x28>
c00273f4:	be 70 5a 03 c0       	mov    $0xc0035a70,%esi
c00273f9:	81 f9 ff 03 00 00    	cmp    $0x3ff,%ecx
c00273ff:	76 42                	jbe    c0027443 <print_human_readable_size+0x6a>
c0027401:	be 70 5a 03 c0       	mov    $0xc0035a70,%esi
c0027406:	83 3d 74 5a 03 c0 00 	cmpl   $0x0,0xc0035a74
c002740d:	75 10                	jne    c002741f <print_human_readable_size+0x46>
c002740f:	eb 32                	jmp    c0027443 <print_human_readable_size+0x6a>
    printf ("1 byte");
c0027411:	c7 04 24 79 f8 02 c0 	movl   $0xc002f879,(%esp)
c0027418:	e8 f1 f6 ff ff       	call   c0026b0e <printf>
c002741d:	eb 3e                	jmp    c002745d <print_human_readable_size+0x84>
        size /= 1024;
c002741f:	89 c8                	mov    %ecx,%eax
c0027421:	89 da                	mov    %ebx,%edx
c0027423:	0f ac d8 0a          	shrd   $0xa,%ebx,%eax
c0027427:	c1 ea 0a             	shr    $0xa,%edx
c002742a:	89 c1                	mov    %eax,%ecx
c002742c:	89 d3                	mov    %edx,%ebx
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002742e:	83 c6 04             	add    $0x4,%esi
c0027431:	83 fa 00             	cmp    $0x0,%edx
c0027434:	77 07                	ja     c002743d <print_human_readable_size+0x64>
c0027436:	3d ff 03 00 00       	cmp    $0x3ff,%eax
c002743b:	76 06                	jbe    c0027443 <print_human_readable_size+0x6a>
c002743d:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0027441:	75 dc                	jne    c002741f <print_human_readable_size+0x46>
      printf ("%"PRIu64" %s", size, *fp);
c0027443:	8b 06                	mov    (%esi),%eax
c0027445:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027449:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002744d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0027451:	c7 04 24 80 f8 02 c0 	movl   $0xc002f880,(%esp)
c0027458:	e8 b1 f6 ff ff       	call   c0026b0e <printf>
    }
}
c002745d:	83 c4 14             	add    $0x14,%esp
c0027460:	5b                   	pop    %ebx
c0027461:	5e                   	pop    %esi
c0027462:	c3                   	ret    
c0027463:	90                   	nop
c0027464:	90                   	nop
c0027465:	90                   	nop
c0027466:	90                   	nop
c0027467:	90                   	nop
c0027468:	90                   	nop
c0027469:	90                   	nop
c002746a:	90                   	nop
c002746b:	90                   	nop
c002746c:	90                   	nop
c002746d:	90                   	nop
c002746e:	90                   	nop
c002746f:	90                   	nop

c0027470 <compare_thunk>:
}

/* Compares A and B by calling the AUX function. */
static int
compare_thunk (const void *a, const void *b, void *aux) 
{
c0027470:	83 ec 1c             	sub    $0x1c,%esp
  int (**compare) (const void *, const void *) = aux;
  return (*compare) (a, b);
c0027473:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027477:	89 44 24 04          	mov    %eax,0x4(%esp)
c002747b:	8b 44 24 20          	mov    0x20(%esp),%eax
c002747f:	89 04 24             	mov    %eax,(%esp)
c0027482:	8b 44 24 28          	mov    0x28(%esp),%eax
c0027486:	ff 10                	call   *(%eax)
}
c0027488:	83 c4 1c             	add    $0x1c,%esp
c002748b:	c3                   	ret    

c002748c <do_swap>:

/* Swaps elements with 1-based indexes A_IDX and B_IDX in ARRAY
   with elements of SIZE bytes each. */
static void
do_swap (unsigned char *array, size_t a_idx, size_t b_idx, size_t size)
{
c002748c:	57                   	push   %edi
c002748d:	56                   	push   %esi
c002748e:	53                   	push   %ebx
c002748f:	8b 7c 24 10          	mov    0x10(%esp),%edi
  unsigned char *a = array + (a_idx - 1) * size;
c0027493:	8d 5a ff             	lea    -0x1(%edx),%ebx
c0027496:	0f af df             	imul   %edi,%ebx
c0027499:	01 c3                	add    %eax,%ebx
  unsigned char *b = array + (b_idx - 1) * size;
c002749b:	8d 51 ff             	lea    -0x1(%ecx),%edx
c002749e:	0f af d7             	imul   %edi,%edx
c00274a1:	01 d0                	add    %edx,%eax
  size_t i;

  for (i = 0; i < size; i++)
c00274a3:	85 ff                	test   %edi,%edi
c00274a5:	74 1c                	je     c00274c3 <do_swap+0x37>
c00274a7:	ba 00 00 00 00       	mov    $0x0,%edx
    {
      unsigned char t = a[i];
c00274ac:	0f b6 34 13          	movzbl (%ebx,%edx,1),%esi
      a[i] = b[i];
c00274b0:	0f b6 0c 10          	movzbl (%eax,%edx,1),%ecx
c00274b4:	88 0c 13             	mov    %cl,(%ebx,%edx,1)
      b[i] = t;
c00274b7:	89 f1                	mov    %esi,%ecx
c00274b9:	88 0c 10             	mov    %cl,(%eax,%edx,1)
  for (i = 0; i < size; i++)
c00274bc:	83 c2 01             	add    $0x1,%edx
c00274bf:	39 fa                	cmp    %edi,%edx
c00274c1:	75 e9                	jne    c00274ac <do_swap+0x20>
    }
}
c00274c3:	5b                   	pop    %ebx
c00274c4:	5e                   	pop    %esi
c00274c5:	5f                   	pop    %edi
c00274c6:	c3                   	ret    

c00274c7 <heapify>:
   elements, passing AUX as auxiliary data. */
static void
heapify (unsigned char *array, size_t i, size_t cnt, size_t size,
         int (*compare) (const void *, const void *, void *aux),
         void *aux) 
{
c00274c7:	55                   	push   %ebp
c00274c8:	57                   	push   %edi
c00274c9:	56                   	push   %esi
c00274ca:	53                   	push   %ebx
c00274cb:	83 ec 2c             	sub    $0x2c,%esp
c00274ce:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c00274d2:	89 d3                	mov    %edx,%ebx
c00274d4:	89 4c 24 18          	mov    %ecx,0x18(%esp)
  for (;;) 
    {
      /* Set `max' to the index of the largest element among I
         and its children (if any). */
      size_t left = 2 * i;
c00274d8:	8d 3c 1b             	lea    (%ebx,%ebx,1),%edi
      size_t right = 2 * i + 1;
c00274db:	8d 6f 01             	lea    0x1(%edi),%ebp
      size_t max = i;
c00274de:	89 de                	mov    %ebx,%esi
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c00274e0:	3b 7c 24 18          	cmp    0x18(%esp),%edi
c00274e4:	77 30                	ja     c0027516 <heapify+0x4f>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c00274e6:	8b 44 24 48          	mov    0x48(%esp),%eax
c00274ea:	89 44 24 08          	mov    %eax,0x8(%esp)
c00274ee:	8d 43 ff             	lea    -0x1(%ebx),%eax
c00274f1:	0f af 44 24 40       	imul   0x40(%esp),%eax
c00274f6:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00274fa:	01 d0                	add    %edx,%eax
c00274fc:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027500:	8d 47 ff             	lea    -0x1(%edi),%eax
c0027503:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027508:	01 d0                	add    %edx,%eax
c002750a:	89 04 24             	mov    %eax,(%esp)
c002750d:	ff 54 24 44          	call   *0x44(%esp)
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027511:	85 c0                	test   %eax,%eax
      size_t max = i;
c0027513:	0f 4f f7             	cmovg  %edi,%esi
        max = left;
      if (right <= cnt
c0027516:	3b 6c 24 18          	cmp    0x18(%esp),%ebp
c002751a:	77 2d                	ja     c0027549 <heapify+0x82>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c002751c:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027520:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027524:	8d 46 ff             	lea    -0x1(%esi),%eax
c0027527:	0f af 44 24 40       	imul   0x40(%esp),%eax
c002752c:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0027530:	01 c8                	add    %ecx,%eax
c0027532:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027536:	0f af 7c 24 40       	imul   0x40(%esp),%edi
c002753b:	01 cf                	add    %ecx,%edi
c002753d:	89 3c 24             	mov    %edi,(%esp)
c0027540:	ff 54 24 44          	call   *0x44(%esp)
          && do_compare (array, right, max, size, compare, aux) > 0) 
c0027544:	85 c0                	test   %eax,%eax
        max = right;
c0027546:	0f 4f f5             	cmovg  %ebp,%esi

      /* If the maximum value is already in element I, we're
         done. */
      if (max == i)
c0027549:	39 de                	cmp    %ebx,%esi
c002754b:	74 1b                	je     c0027568 <heapify+0xa1>
        break;

      /* Swap and continue down the heap. */
      do_swap (array, i, max, size);
c002754d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0027551:	89 04 24             	mov    %eax,(%esp)
c0027554:	89 f1                	mov    %esi,%ecx
c0027556:	89 da                	mov    %ebx,%edx
c0027558:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002755c:	e8 2b ff ff ff       	call   c002748c <do_swap>
      i = max;
c0027561:	89 f3                	mov    %esi,%ebx
    }
c0027563:	e9 70 ff ff ff       	jmp    c00274d8 <heapify+0x11>
}
c0027568:	83 c4 2c             	add    $0x2c,%esp
c002756b:	5b                   	pop    %ebx
c002756c:	5e                   	pop    %esi
c002756d:	5f                   	pop    %edi
c002756e:	5d                   	pop    %ebp
c002756f:	c3                   	ret    

c0027570 <atoi>:
{
c0027570:	57                   	push   %edi
c0027571:	56                   	push   %esi
c0027572:	53                   	push   %ebx
c0027573:	83 ec 20             	sub    $0x20,%esp
c0027576:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002757a:	85 d2                	test   %edx,%edx
c002757c:	75 2f                	jne    c00275ad <atoi+0x3d>
c002757e:	c7 44 24 10 c6 f9 02 	movl   $0xc002f9c6,0x10(%esp)
c0027585:	c0 
c0027586:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002758d:	c0 
c002758e:	c7 44 24 08 e9 db 02 	movl   $0xc002dbe9,0x8(%esp)
c0027595:	c0 
c0027596:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
c002759d:	00 
c002759e:	c7 04 24 d0 f8 02 c0 	movl   $0xc002f8d0,(%esp)
c00275a5:	e8 b9 13 00 00       	call   c0028963 <debug_panic>
    s++;
c00275aa:	83 c2 01             	add    $0x1,%edx
  while (isspace ((unsigned char) *s))
c00275ad:	0f b6 02             	movzbl (%edx),%eax
c00275b0:	0f b6 c8             	movzbl %al,%ecx
          || c == '\r' || c == '\t' || c == '\v');
c00275b3:	83 f9 20             	cmp    $0x20,%ecx
c00275b6:	74 f2                	je     c00275aa <atoi+0x3a>
  return (c == ' ' || c == '\f' || c == '\n'
c00275b8:	8d 58 f4             	lea    -0xc(%eax),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c00275bb:	80 fb 01             	cmp    $0x1,%bl
c00275be:	76 ea                	jbe    c00275aa <atoi+0x3a>
c00275c0:	83 f9 0a             	cmp    $0xa,%ecx
c00275c3:	74 e5                	je     c00275aa <atoi+0x3a>
c00275c5:	89 c1                	mov    %eax,%ecx
c00275c7:	83 e1 fd             	and    $0xfffffffd,%ecx
c00275ca:	80 f9 09             	cmp    $0x9,%cl
c00275cd:	74 db                	je     c00275aa <atoi+0x3a>
  if (*s == '+')
c00275cf:	3c 2b                	cmp    $0x2b,%al
c00275d1:	75 0a                	jne    c00275dd <atoi+0x6d>
    s++;
c00275d3:	83 c2 01             	add    $0x1,%edx
  negative = false;
c00275d6:	be 00 00 00 00       	mov    $0x0,%esi
c00275db:	eb 11                	jmp    c00275ee <atoi+0x7e>
c00275dd:	be 00 00 00 00       	mov    $0x0,%esi
  else if (*s == '-')
c00275e2:	3c 2d                	cmp    $0x2d,%al
c00275e4:	75 08                	jne    c00275ee <atoi+0x7e>
      s++;
c00275e6:	8d 52 01             	lea    0x1(%edx),%edx
      negative = true;
c00275e9:	be 01 00 00 00       	mov    $0x1,%esi
  for (value = 0; isdigit (*s); s++)
c00275ee:	0f b6 0a             	movzbl (%edx),%ecx
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c00275f1:	0f be c1             	movsbl %cl,%eax
c00275f4:	83 e8 30             	sub    $0x30,%eax
c00275f7:	83 f8 09             	cmp    $0x9,%eax
c00275fa:	77 2a                	ja     c0027626 <atoi+0xb6>
c00275fc:	b8 00 00 00 00       	mov    $0x0,%eax
    value = value * 10 - (*s - '0');
c0027601:	bf 30 00 00 00       	mov    $0x30,%edi
c0027606:	8d 1c 80             	lea    (%eax,%eax,4),%ebx
c0027609:	0f be c9             	movsbl %cl,%ecx
c002760c:	89 f8                	mov    %edi,%eax
c002760e:	29 c8                	sub    %ecx,%eax
c0027610:	8d 04 58             	lea    (%eax,%ebx,2),%eax
  for (value = 0; isdigit (*s); s++)
c0027613:	83 c2 01             	add    $0x1,%edx
c0027616:	0f b6 0a             	movzbl (%edx),%ecx
c0027619:	0f be d9             	movsbl %cl,%ebx
c002761c:	83 eb 30             	sub    $0x30,%ebx
c002761f:	83 fb 09             	cmp    $0x9,%ebx
c0027622:	76 e2                	jbe    c0027606 <atoi+0x96>
c0027624:	eb 05                	jmp    c002762b <atoi+0xbb>
c0027626:	b8 00 00 00 00       	mov    $0x0,%eax
    value = -value;
c002762b:	89 c2                	mov    %eax,%edx
c002762d:	f7 da                	neg    %edx
c002762f:	89 f3                	mov    %esi,%ebx
c0027631:	84 db                	test   %bl,%bl
c0027633:	0f 44 c2             	cmove  %edx,%eax
}
c0027636:	83 c4 20             	add    $0x20,%esp
c0027639:	5b                   	pop    %ebx
c002763a:	5e                   	pop    %esi
c002763b:	5f                   	pop    %edi
c002763c:	c3                   	ret    

c002763d <sort>:
   B.  Runs in O(n lg n) time and O(1) space in CNT. */
void
sort (void *array, size_t cnt, size_t size,
      int (*compare) (const void *, const void *, void *aux),
      void *aux) 
{
c002763d:	55                   	push   %ebp
c002763e:	57                   	push   %edi
c002763f:	56                   	push   %esi
c0027640:	53                   	push   %ebx
c0027641:	83 ec 2c             	sub    $0x2c,%esp
c0027644:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0027648:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c002764c:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  size_t i;

  ASSERT (array != NULL || cnt == 0);
c0027650:	85 ff                	test   %edi,%edi
c0027652:	75 30                	jne    c0027684 <sort+0x47>
c0027654:	85 db                	test   %ebx,%ebx
c0027656:	74 2c                	je     c0027684 <sort+0x47>
c0027658:	c7 44 24 10 e3 f8 02 	movl   $0xc002f8e3,0x10(%esp)
c002765f:	c0 
c0027660:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027667:	c0 
c0027668:	c7 44 24 08 e4 db 02 	movl   $0xc002dbe4,0x8(%esp)
c002766f:	c0 
c0027670:	c7 44 24 04 8a 00 00 	movl   $0x8a,0x4(%esp)
c0027677:	00 
c0027678:	c7 04 24 d0 f8 02 c0 	movl   $0xc002f8d0,(%esp)
c002767f:	e8 df 12 00 00       	call   c0028963 <debug_panic>
  ASSERT (compare != NULL);
c0027684:	83 7c 24 4c 00       	cmpl   $0x0,0x4c(%esp)
c0027689:	75 2c                	jne    c00276b7 <sort+0x7a>
c002768b:	c7 44 24 10 fd f8 02 	movl   $0xc002f8fd,0x10(%esp)
c0027692:	c0 
c0027693:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002769a:	c0 
c002769b:	c7 44 24 08 e4 db 02 	movl   $0xc002dbe4,0x8(%esp)
c00276a2:	c0 
c00276a3:	c7 44 24 04 8b 00 00 	movl   $0x8b,0x4(%esp)
c00276aa:	00 
c00276ab:	c7 04 24 d0 f8 02 c0 	movl   $0xc002f8d0,(%esp)
c00276b2:	e8 ac 12 00 00       	call   c0028963 <debug_panic>
  ASSERT (size > 0);
c00276b7:	85 ed                	test   %ebp,%ebp
c00276b9:	75 2c                	jne    c00276e7 <sort+0xaa>
c00276bb:	c7 44 24 10 0d f9 02 	movl   $0xc002f90d,0x10(%esp)
c00276c2:	c0 
c00276c3:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00276ca:	c0 
c00276cb:	c7 44 24 08 e4 db 02 	movl   $0xc002dbe4,0x8(%esp)
c00276d2:	c0 
c00276d3:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c00276da:	00 
c00276db:	c7 04 24 d0 f8 02 c0 	movl   $0xc002f8d0,(%esp)
c00276e2:	e8 7c 12 00 00       	call   c0028963 <debug_panic>

  /* Build a heap. */
  for (i = cnt / 2; i > 0; i--)
c00276e7:	89 de                	mov    %ebx,%esi
c00276e9:	d1 ee                	shr    %esi
c00276eb:	74 23                	je     c0027710 <sort+0xd3>
    heapify (array, i, cnt, size, compare, aux);
c00276ed:	8b 44 24 50          	mov    0x50(%esp),%eax
c00276f1:	89 44 24 08          	mov    %eax,0x8(%esp)
c00276f5:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c00276f9:	89 44 24 04          	mov    %eax,0x4(%esp)
c00276fd:	89 2c 24             	mov    %ebp,(%esp)
c0027700:	89 d9                	mov    %ebx,%ecx
c0027702:	89 f2                	mov    %esi,%edx
c0027704:	89 f8                	mov    %edi,%eax
c0027706:	e8 bc fd ff ff       	call   c00274c7 <heapify>
  for (i = cnt / 2; i > 0; i--)
c002770b:	83 ee 01             	sub    $0x1,%esi
c002770e:	75 dd                	jne    c00276ed <sort+0xb0>

  /* Sort the heap. */
  for (i = cnt; i > 1; i--) 
c0027710:	83 fb 01             	cmp    $0x1,%ebx
c0027713:	76 3a                	jbe    c002774f <sort+0x112>
c0027715:	8b 74 24 50          	mov    0x50(%esp),%esi
    {
      do_swap (array, 1, i, size);
c0027719:	89 2c 24             	mov    %ebp,(%esp)
c002771c:	89 d9                	mov    %ebx,%ecx
c002771e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027723:	89 f8                	mov    %edi,%eax
c0027725:	e8 62 fd ff ff       	call   c002748c <do_swap>
      heapify (array, 1, i - 1, size, compare, aux); 
c002772a:	83 eb 01             	sub    $0x1,%ebx
c002772d:	89 74 24 08          	mov    %esi,0x8(%esp)
c0027731:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027735:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027739:	89 2c 24             	mov    %ebp,(%esp)
c002773c:	89 d9                	mov    %ebx,%ecx
c002773e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027743:	89 f8                	mov    %edi,%eax
c0027745:	e8 7d fd ff ff       	call   c00274c7 <heapify>
  for (i = cnt; i > 1; i--) 
c002774a:	83 fb 01             	cmp    $0x1,%ebx
c002774d:	75 ca                	jne    c0027719 <sort+0xdc>
    }
}
c002774f:	83 c4 2c             	add    $0x2c,%esp
c0027752:	5b                   	pop    %ebx
c0027753:	5e                   	pop    %esi
c0027754:	5f                   	pop    %edi
c0027755:	5d                   	pop    %ebp
c0027756:	c3                   	ret    

c0027757 <qsort>:
{
c0027757:	83 ec 2c             	sub    $0x2c,%esp
  sort (array, cnt, size, compare_thunk, &compare);
c002775a:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002775e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0027762:	c7 44 24 0c 70 74 02 	movl   $0xc0027470,0xc(%esp)
c0027769:	c0 
c002776a:	8b 44 24 38          	mov    0x38(%esp),%eax
c002776e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027772:	8b 44 24 34          	mov    0x34(%esp),%eax
c0027776:	89 44 24 04          	mov    %eax,0x4(%esp)
c002777a:	8b 44 24 30          	mov    0x30(%esp),%eax
c002777e:	89 04 24             	mov    %eax,(%esp)
c0027781:	e8 b7 fe ff ff       	call   c002763d <sort>
}
c0027786:	83 c4 2c             	add    $0x2c,%esp
c0027789:	c3                   	ret    

c002778a <binary_search>:
   B. */
void *
binary_search (const void *key, const void *array, size_t cnt, size_t size,
               int (*compare) (const void *, const void *, void *aux),
               void *aux) 
{
c002778a:	55                   	push   %ebp
c002778b:	57                   	push   %edi
c002778c:	56                   	push   %esi
c002778d:	53                   	push   %ebx
c002778e:	83 ec 1c             	sub    $0x1c,%esp
c0027791:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c0027795:	8b 74 24 3c          	mov    0x3c(%esp),%esi
  const unsigned char *first = array;
  const unsigned char *last = array + size * cnt;
c0027799:	89 f5                	mov    %esi,%ebp
c002779b:	0f af 6c 24 38       	imul   0x38(%esp),%ebp
c00277a0:	01 dd                	add    %ebx,%ebp

  while (first < last) 
c00277a2:	39 eb                	cmp    %ebp,%ebx
c00277a4:	73 44                	jae    c00277ea <binary_search+0x60>
    {
      size_t range = (last - first) / size;
c00277a6:	89 e8                	mov    %ebp,%eax
c00277a8:	29 d8                	sub    %ebx,%eax
c00277aa:	ba 00 00 00 00       	mov    $0x0,%edx
c00277af:	f7 f6                	div    %esi
      const unsigned char *middle = first + (range / 2) * size;
c00277b1:	d1 e8                	shr    %eax
c00277b3:	0f af c6             	imul   %esi,%eax
c00277b6:	89 c7                	mov    %eax,%edi
c00277b8:	01 df                	add    %ebx,%edi
      int cmp = compare (key, middle, aux);
c00277ba:	8b 44 24 44          	mov    0x44(%esp),%eax
c00277be:	89 44 24 08          	mov    %eax,0x8(%esp)
c00277c2:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00277c6:	8b 44 24 30          	mov    0x30(%esp),%eax
c00277ca:	89 04 24             	mov    %eax,(%esp)
c00277cd:	ff 54 24 40          	call   *0x40(%esp)

      if (cmp < 0) 
c00277d1:	85 c0                	test   %eax,%eax
c00277d3:	78 0d                	js     c00277e2 <binary_search+0x58>
        last = middle;
      else if (cmp > 0) 
c00277d5:	85 c0                	test   %eax,%eax
c00277d7:	7e 19                	jle    c00277f2 <binary_search+0x68>
        first = middle + size;
c00277d9:	8d 1c 37             	lea    (%edi,%esi,1),%ebx
c00277dc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c00277e0:	eb 02                	jmp    c00277e4 <binary_search+0x5a>
      const unsigned char *middle = first + (range / 2) * size;
c00277e2:	89 fd                	mov    %edi,%ebp
  while (first < last) 
c00277e4:	39 dd                	cmp    %ebx,%ebp
c00277e6:	77 be                	ja     c00277a6 <binary_search+0x1c>
c00277e8:	eb 0c                	jmp    c00277f6 <binary_search+0x6c>
      else
        return (void *) middle;
    }
  
  return NULL;
c00277ea:	b8 00 00 00 00       	mov    $0x0,%eax
c00277ef:	90                   	nop
c00277f0:	eb 09                	jmp    c00277fb <binary_search+0x71>
      const unsigned char *middle = first + (range / 2) * size;
c00277f2:	89 f8                	mov    %edi,%eax
c00277f4:	eb 05                	jmp    c00277fb <binary_search+0x71>
  return NULL;
c00277f6:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00277fb:	83 c4 1c             	add    $0x1c,%esp
c00277fe:	5b                   	pop    %ebx
c00277ff:	5e                   	pop    %esi
c0027800:	5f                   	pop    %edi
c0027801:	5d                   	pop    %ebp
c0027802:	c3                   	ret    

c0027803 <bsearch>:
{
c0027803:	83 ec 2c             	sub    $0x2c,%esp
  return binary_search (key, array, cnt, size, compare_thunk, &compare);
c0027806:	8d 44 24 40          	lea    0x40(%esp),%eax
c002780a:	89 44 24 14          	mov    %eax,0x14(%esp)
c002780e:	c7 44 24 10 70 74 02 	movl   $0xc0027470,0x10(%esp)
c0027815:	c0 
c0027816:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c002781a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002781e:	8b 44 24 38          	mov    0x38(%esp),%eax
c0027822:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027826:	8b 44 24 34          	mov    0x34(%esp),%eax
c002782a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002782e:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027832:	89 04 24             	mov    %eax,(%esp)
c0027835:	e8 50 ff ff ff       	call   c002778a <binary_search>
}
c002783a:	83 c4 2c             	add    $0x2c,%esp
c002783d:	c3                   	ret    
c002783e:	90                   	nop
c002783f:	90                   	nop

c0027840 <memcpy>:

/* Copies SIZE bytes from SRC to DST, which must not overlap.
   Returns DST. */
void *
memcpy (void *dst_, const void *src_, size_t size) 
{
c0027840:	56                   	push   %esi
c0027841:	53                   	push   %ebx
c0027842:	83 ec 24             	sub    $0x24,%esp
c0027845:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027849:	8b 74 24 34          	mov    0x34(%esp),%esi
c002784d:	8b 5c 24 38          	mov    0x38(%esp),%ebx
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c0027851:	85 db                	test   %ebx,%ebx
c0027853:	0f 94 c2             	sete   %dl
c0027856:	85 c0                	test   %eax,%eax
c0027858:	75 30                	jne    c002788a <memcpy+0x4a>
c002785a:	84 d2                	test   %dl,%dl
c002785c:	75 2c                	jne    c002788a <memcpy+0x4a>
c002785e:	c7 44 24 10 16 f9 02 	movl   $0xc002f916,0x10(%esp)
c0027865:	c0 
c0027866:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002786d:	c0 
c002786e:	c7 44 24 08 39 dc 02 	movl   $0xc002dc39,0x8(%esp)
c0027875:	c0 
c0027876:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002787d:	00 
c002787e:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027885:	e8 d9 10 00 00       	call   c0028963 <debug_panic>
  ASSERT (src != NULL || size == 0);
c002788a:	85 f6                	test   %esi,%esi
c002788c:	75 04                	jne    c0027892 <memcpy+0x52>
c002788e:	84 d2                	test   %dl,%dl
c0027890:	74 0b                	je     c002789d <memcpy+0x5d>

  while (size-- > 0)
c0027892:	ba 00 00 00 00       	mov    $0x0,%edx
c0027897:	85 db                	test   %ebx,%ebx
c0027899:	75 2e                	jne    c00278c9 <memcpy+0x89>
c002789b:	eb 3a                	jmp    c00278d7 <memcpy+0x97>
  ASSERT (src != NULL || size == 0);
c002789d:	c7 44 24 10 42 f9 02 	movl   $0xc002f942,0x10(%esp)
c00278a4:	c0 
c00278a5:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00278ac:	c0 
c00278ad:	c7 44 24 08 39 dc 02 	movl   $0xc002dc39,0x8(%esp)
c00278b4:	c0 
c00278b5:	c7 44 24 04 0d 00 00 	movl   $0xd,0x4(%esp)
c00278bc:	00 
c00278bd:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c00278c4:	e8 9a 10 00 00       	call   c0028963 <debug_panic>
    *dst++ = *src++;
c00278c9:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
c00278cd:	88 0c 10             	mov    %cl,(%eax,%edx,1)
c00278d0:	83 c2 01             	add    $0x1,%edx
  while (size-- > 0)
c00278d3:	39 da                	cmp    %ebx,%edx
c00278d5:	75 f2                	jne    c00278c9 <memcpy+0x89>

  return dst_;
}
c00278d7:	83 c4 24             	add    $0x24,%esp
c00278da:	5b                   	pop    %ebx
c00278db:	5e                   	pop    %esi
c00278dc:	c3                   	ret    

c00278dd <memmove>:

/* Copies SIZE bytes from SRC to DST, which are allowed to
   overlap.  Returns DST. */
void *
memmove (void *dst_, const void *src_, size_t size) 
{
c00278dd:	57                   	push   %edi
c00278de:	56                   	push   %esi
c00278df:	53                   	push   %ebx
c00278e0:	83 ec 20             	sub    $0x20,%esp
c00278e3:	8b 74 24 30          	mov    0x30(%esp),%esi
c00278e7:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c00278eb:	8b 7c 24 38          	mov    0x38(%esp),%edi
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c00278ef:	85 ff                	test   %edi,%edi
c00278f1:	0f 94 c2             	sete   %dl
c00278f4:	85 f6                	test   %esi,%esi
c00278f6:	75 30                	jne    c0027928 <memmove+0x4b>
c00278f8:	84 d2                	test   %dl,%dl
c00278fa:	75 2c                	jne    c0027928 <memmove+0x4b>
c00278fc:	c7 44 24 10 16 f9 02 	movl   $0xc002f916,0x10(%esp)
c0027903:	c0 
c0027904:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002790b:	c0 
c002790c:	c7 44 24 08 31 dc 02 	movl   $0xc002dc31,0x8(%esp)
c0027913:	c0 
c0027914:	c7 44 24 04 1d 00 00 	movl   $0x1d,0x4(%esp)
c002791b:	00 
c002791c:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027923:	e8 3b 10 00 00       	call   c0028963 <debug_panic>
  ASSERT (src != NULL || size == 0);
c0027928:	85 db                	test   %ebx,%ebx
c002792a:	75 30                	jne    c002795c <memmove+0x7f>
c002792c:	84 d2                	test   %dl,%dl
c002792e:	75 2c                	jne    c002795c <memmove+0x7f>
c0027930:	c7 44 24 10 42 f9 02 	movl   $0xc002f942,0x10(%esp)
c0027937:	c0 
c0027938:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002793f:	c0 
c0027940:	c7 44 24 08 31 dc 02 	movl   $0xc002dc31,0x8(%esp)
c0027947:	c0 
c0027948:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002794f:	00 
c0027950:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027957:	e8 07 10 00 00       	call   c0028963 <debug_panic>

  if (dst < src) 
c002795c:	39 de                	cmp    %ebx,%esi
c002795e:	73 1b                	jae    c002797b <memmove+0x9e>
    {
      while (size-- > 0)
c0027960:	85 ff                	test   %edi,%edi
c0027962:	74 40                	je     c00279a4 <memmove+0xc7>
c0027964:	ba 00 00 00 00       	mov    $0x0,%edx
        *dst++ = *src++;
c0027969:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
c002796d:	88 0c 16             	mov    %cl,(%esi,%edx,1)
c0027970:	83 c2 01             	add    $0x1,%edx
      while (size-- > 0)
c0027973:	39 fa                	cmp    %edi,%edx
c0027975:	75 f2                	jne    c0027969 <memmove+0x8c>
c0027977:	01 fe                	add    %edi,%esi
c0027979:	eb 29                	jmp    c00279a4 <memmove+0xc7>
    }
  else 
    {
      dst += size;
c002797b:	8d 04 3e             	lea    (%esi,%edi,1),%eax
      src += size;
c002797e:	01 fb                	add    %edi,%ebx
      while (size-- > 0)
c0027980:	8d 57 ff             	lea    -0x1(%edi),%edx
c0027983:	85 ff                	test   %edi,%edi
c0027985:	74 1b                	je     c00279a2 <memmove+0xc5>
c0027987:	f7 df                	neg    %edi
c0027989:	89 f9                	mov    %edi,%ecx
c002798b:	01 fb                	add    %edi,%ebx
c002798d:	01 c1                	add    %eax,%ecx
c002798f:	89 ce                	mov    %ecx,%esi
        *--dst = *--src;
c0027991:	0f b6 04 13          	movzbl (%ebx,%edx,1),%eax
c0027995:	88 04 11             	mov    %al,(%ecx,%edx,1)
      while (size-- > 0)
c0027998:	83 ea 01             	sub    $0x1,%edx
c002799b:	83 fa ff             	cmp    $0xffffffff,%edx
c002799e:	75 ef                	jne    c002798f <memmove+0xb2>
c00279a0:	eb 02                	jmp    c00279a4 <memmove+0xc7>
      dst += size;
c00279a2:	89 c6                	mov    %eax,%esi
    }

  return dst;
}
c00279a4:	89 f0                	mov    %esi,%eax
c00279a6:	83 c4 20             	add    $0x20,%esp
c00279a9:	5b                   	pop    %ebx
c00279aa:	5e                   	pop    %esi
c00279ab:	5f                   	pop    %edi
c00279ac:	c3                   	ret    

c00279ad <memcmp>:
   at A and B.  Returns a positive value if the byte in A is
   greater, a negative value if the byte in B is greater, or zero
   if blocks A and B are equal. */
int
memcmp (const void *a_, const void *b_, size_t size) 
{
c00279ad:	57                   	push   %edi
c00279ae:	56                   	push   %esi
c00279af:	53                   	push   %ebx
c00279b0:	83 ec 20             	sub    $0x20,%esp
c00279b3:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00279b7:	8b 74 24 34          	mov    0x34(%esp),%esi
c00279bb:	8b 44 24 38          	mov    0x38(%esp),%eax
  const unsigned char *a = a_;
  const unsigned char *b = b_;

  ASSERT (a != NULL || size == 0);
c00279bf:	85 c0                	test   %eax,%eax
c00279c1:	0f 94 c2             	sete   %dl
c00279c4:	85 db                	test   %ebx,%ebx
c00279c6:	75 30                	jne    c00279f8 <memcmp+0x4b>
c00279c8:	84 d2                	test   %dl,%dl
c00279ca:	75 2c                	jne    c00279f8 <memcmp+0x4b>
c00279cc:	c7 44 24 10 5b f9 02 	movl   $0xc002f95b,0x10(%esp)
c00279d3:	c0 
c00279d4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00279db:	c0 
c00279dc:	c7 44 24 08 2a dc 02 	movl   $0xc002dc2a,0x8(%esp)
c00279e3:	c0 
c00279e4:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
c00279eb:	00 
c00279ec:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c00279f3:	e8 6b 0f 00 00       	call   c0028963 <debug_panic>
  ASSERT (b != NULL || size == 0);
c00279f8:	85 f6                	test   %esi,%esi
c00279fa:	75 04                	jne    c0027a00 <memcmp+0x53>
c00279fc:	84 d2                	test   %dl,%dl
c00279fe:	74 18                	je     c0027a18 <memcmp+0x6b>

  for (; size-- > 0; a++, b++)
c0027a00:	8d 78 ff             	lea    -0x1(%eax),%edi
c0027a03:	85 c0                	test   %eax,%eax
c0027a05:	74 64                	je     c0027a6b <memcmp+0xbe>
    if (*a != *b)
c0027a07:	0f b6 13             	movzbl (%ebx),%edx
c0027a0a:	0f b6 0e             	movzbl (%esi),%ecx
c0027a0d:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a12:	38 ca                	cmp    %cl,%dl
c0027a14:	74 4a                	je     c0027a60 <memcmp+0xb3>
c0027a16:	eb 3c                	jmp    c0027a54 <memcmp+0xa7>
  ASSERT (b != NULL || size == 0);
c0027a18:	c7 44 24 10 72 f9 02 	movl   $0xc002f972,0x10(%esp)
c0027a1f:	c0 
c0027a20:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027a27:	c0 
c0027a28:	c7 44 24 08 2a dc 02 	movl   $0xc002dc2a,0x8(%esp)
c0027a2f:	c0 
c0027a30:	c7 44 24 04 3b 00 00 	movl   $0x3b,0x4(%esp)
c0027a37:	00 
c0027a38:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027a3f:	e8 1f 0f 00 00       	call   c0028963 <debug_panic>
    if (*a != *b)
c0027a44:	0f b6 54 03 01       	movzbl 0x1(%ebx,%eax,1),%edx
c0027a49:	83 c0 01             	add    $0x1,%eax
c0027a4c:	0f b6 0c 06          	movzbl (%esi,%eax,1),%ecx
c0027a50:	38 ca                	cmp    %cl,%dl
c0027a52:	74 0c                	je     c0027a60 <memcmp+0xb3>
      return *a > *b ? +1 : -1;
c0027a54:	38 d1                	cmp    %dl,%cl
c0027a56:	19 c0                	sbb    %eax,%eax
c0027a58:	83 e0 02             	and    $0x2,%eax
c0027a5b:	83 e8 01             	sub    $0x1,%eax
c0027a5e:	eb 10                	jmp    c0027a70 <memcmp+0xc3>
  for (; size-- > 0; a++, b++)
c0027a60:	39 f8                	cmp    %edi,%eax
c0027a62:	75 e0                	jne    c0027a44 <memcmp+0x97>
  return 0;
c0027a64:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a69:	eb 05                	jmp    c0027a70 <memcmp+0xc3>
c0027a6b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027a70:	83 c4 20             	add    $0x20,%esp
c0027a73:	5b                   	pop    %ebx
c0027a74:	5e                   	pop    %esi
c0027a75:	5f                   	pop    %edi
c0027a76:	c3                   	ret    

c0027a77 <strcmp>:
   char) is greater, a negative value if the character in B (as
   an unsigned char) is greater, or zero if strings A and B are
   equal. */
int
strcmp (const char *a_, const char *b_) 
{
c0027a77:	83 ec 2c             	sub    $0x2c,%esp
c0027a7a:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c0027a7e:	8b 54 24 34          	mov    0x34(%esp),%edx
  const unsigned char *a = (const unsigned char *) a_;
  const unsigned char *b = (const unsigned char *) b_;

  ASSERT (a != NULL);
c0027a82:	85 c9                	test   %ecx,%ecx
c0027a84:	75 2c                	jne    c0027ab2 <strcmp+0x3b>
c0027a86:	c7 44 24 10 c5 e9 02 	movl   $0xc002e9c5,0x10(%esp)
c0027a8d:	c0 
c0027a8e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027a95:	c0 
c0027a96:	c7 44 24 08 23 dc 02 	movl   $0xc002dc23,0x8(%esp)
c0027a9d:	c0 
c0027a9e:	c7 44 24 04 4e 00 00 	movl   $0x4e,0x4(%esp)
c0027aa5:	00 
c0027aa6:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027aad:	e8 b1 0e 00 00       	call   c0028963 <debug_panic>
  ASSERT (b != NULL);
c0027ab2:	85 d2                	test   %edx,%edx
c0027ab4:	74 0e                	je     c0027ac4 <strcmp+0x4d>

  while (*a != '\0' && *a == *b) 
c0027ab6:	0f b6 01             	movzbl (%ecx),%eax
c0027ab9:	84 c0                	test   %al,%al
c0027abb:	74 44                	je     c0027b01 <strcmp+0x8a>
c0027abd:	3a 02                	cmp    (%edx),%al
c0027abf:	90                   	nop
c0027ac0:	74 2e                	je     c0027af0 <strcmp+0x79>
c0027ac2:	eb 3d                	jmp    c0027b01 <strcmp+0x8a>
  ASSERT (b != NULL);
c0027ac4:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c0027acb:	c0 
c0027acc:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027ad3:	c0 
c0027ad4:	c7 44 24 08 23 dc 02 	movl   $0xc002dc23,0x8(%esp)
c0027adb:	c0 
c0027adc:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c0027ae3:	00 
c0027ae4:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027aeb:	e8 73 0e 00 00       	call   c0028963 <debug_panic>
    {
      a++;
c0027af0:	83 c1 01             	add    $0x1,%ecx
      b++;
c0027af3:	83 c2 01             	add    $0x1,%edx
  while (*a != '\0' && *a == *b) 
c0027af6:	0f b6 01             	movzbl (%ecx),%eax
c0027af9:	84 c0                	test   %al,%al
c0027afb:	74 04                	je     c0027b01 <strcmp+0x8a>
c0027afd:	3a 02                	cmp    (%edx),%al
c0027aff:	74 ef                	je     c0027af0 <strcmp+0x79>
    }

  return *a < *b ? -1 : *a > *b;
c0027b01:	0f b6 12             	movzbl (%edx),%edx
c0027b04:	38 c2                	cmp    %al,%dl
c0027b06:	77 0a                	ja     c0027b12 <strcmp+0x9b>
c0027b08:	38 d0                	cmp    %dl,%al
c0027b0a:	0f 97 c0             	seta   %al
c0027b0d:	0f b6 c0             	movzbl %al,%eax
c0027b10:	eb 05                	jmp    c0027b17 <strcmp+0xa0>
c0027b12:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0027b17:	83 c4 2c             	add    $0x2c,%esp
c0027b1a:	c3                   	ret    

c0027b1b <memchr>:
/* Returns a pointer to the first occurrence of CH in the first
   SIZE bytes starting at BLOCK.  Returns a null pointer if CH
   does not occur in BLOCK. */
void *
memchr (const void *block_, int ch_, size_t size) 
{
c0027b1b:	56                   	push   %esi
c0027b1c:	53                   	push   %ebx
c0027b1d:	83 ec 24             	sub    $0x24,%esp
c0027b20:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027b24:	8b 74 24 34          	mov    0x34(%esp),%esi
c0027b28:	8b 54 24 38          	mov    0x38(%esp),%edx
  const unsigned char *block = block_;
  unsigned char ch = ch_;
c0027b2c:	89 f3                	mov    %esi,%ebx

  ASSERT (block != NULL || size == 0);
c0027b2e:	85 c0                	test   %eax,%eax
c0027b30:	75 04                	jne    c0027b36 <memchr+0x1b>
c0027b32:	85 d2                	test   %edx,%edx
c0027b34:	75 14                	jne    c0027b4a <memchr+0x2f>

  for (; size-- > 0; block++)
c0027b36:	8d 4a ff             	lea    -0x1(%edx),%ecx
c0027b39:	85 d2                	test   %edx,%edx
c0027b3b:	74 4e                	je     c0027b8b <memchr+0x70>
    if (*block == ch)
c0027b3d:	89 f2                	mov    %esi,%edx
c0027b3f:	38 10                	cmp    %dl,(%eax)
c0027b41:	74 4d                	je     c0027b90 <memchr+0x75>
c0027b43:	ba 00 00 00 00       	mov    $0x0,%edx
c0027b48:	eb 33                	jmp    c0027b7d <memchr+0x62>
  ASSERT (block != NULL || size == 0);
c0027b4a:	c7 44 24 10 93 f9 02 	movl   $0xc002f993,0x10(%esp)
c0027b51:	c0 
c0027b52:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027b59:	c0 
c0027b5a:	c7 44 24 08 1c dc 02 	movl   $0xc002dc1c,0x8(%esp)
c0027b61:	c0 
c0027b62:	c7 44 24 04 63 00 00 	movl   $0x63,0x4(%esp)
c0027b69:	00 
c0027b6a:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027b71:	e8 ed 0d 00 00       	call   c0028963 <debug_panic>
c0027b76:	83 c2 01             	add    $0x1,%edx
    if (*block == ch)
c0027b79:	38 18                	cmp    %bl,(%eax)
c0027b7b:	74 13                	je     c0027b90 <memchr+0x75>
  for (; size-- > 0; block++)
c0027b7d:	83 c0 01             	add    $0x1,%eax
c0027b80:	39 ca                	cmp    %ecx,%edx
c0027b82:	75 f2                	jne    c0027b76 <memchr+0x5b>
      return (void *) block;

  return NULL;
c0027b84:	b8 00 00 00 00       	mov    $0x0,%eax
c0027b89:	eb 05                	jmp    c0027b90 <memchr+0x75>
c0027b8b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027b90:	83 c4 24             	add    $0x24,%esp
c0027b93:	5b                   	pop    %ebx
c0027b94:	5e                   	pop    %esi
c0027b95:	c3                   	ret    

c0027b96 <strchr>:
   null pointer if C does not appear in STRING.  If C == '\0'
   then returns a pointer to the null terminator at the end of
   STRING. */
char *
strchr (const char *string, int c_) 
{
c0027b96:	53                   	push   %ebx
c0027b97:	83 ec 28             	sub    $0x28,%esp
c0027b9a:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027b9e:	8b 54 24 34          	mov    0x34(%esp),%edx
  char c = c_;

  ASSERT (string != NULL);
c0027ba2:	85 c0                	test   %eax,%eax
c0027ba4:	74 0b                	je     c0027bb1 <strchr+0x1b>
c0027ba6:	89 d1                	mov    %edx,%ecx

  for (;;) 
    if (*string == c)
c0027ba8:	0f b6 18             	movzbl (%eax),%ebx
c0027bab:	38 d3                	cmp    %dl,%bl
c0027bad:	75 2e                	jne    c0027bdd <strchr+0x47>
c0027baf:	eb 4e                	jmp    c0027bff <strchr+0x69>
  ASSERT (string != NULL);
c0027bb1:	c7 44 24 10 ae f9 02 	movl   $0xc002f9ae,0x10(%esp)
c0027bb8:	c0 
c0027bb9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027bc0:	c0 
c0027bc1:	c7 44 24 08 15 dc 02 	movl   $0xc002dc15,0x8(%esp)
c0027bc8:	c0 
c0027bc9:	c7 44 24 04 75 00 00 	movl   $0x75,0x4(%esp)
c0027bd0:	00 
c0027bd1:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027bd8:	e8 86 0d 00 00       	call   c0028963 <debug_panic>
      return (char *) string;
    else if (*string == '\0')
c0027bdd:	84 db                	test   %bl,%bl
c0027bdf:	75 06                	jne    c0027be7 <strchr+0x51>
c0027be1:	eb 10                	jmp    c0027bf3 <strchr+0x5d>
c0027be3:	84 d2                	test   %dl,%dl
c0027be5:	74 13                	je     c0027bfa <strchr+0x64>
      return NULL;
    else
      string++;
c0027be7:	83 c0 01             	add    $0x1,%eax
    if (*string == c)
c0027bea:	0f b6 10             	movzbl (%eax),%edx
c0027bed:	38 ca                	cmp    %cl,%dl
c0027bef:	75 f2                	jne    c0027be3 <strchr+0x4d>
c0027bf1:	eb 0c                	jmp    c0027bff <strchr+0x69>
      return NULL;
c0027bf3:	b8 00 00 00 00       	mov    $0x0,%eax
c0027bf8:	eb 05                	jmp    c0027bff <strchr+0x69>
c0027bfa:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027bff:	83 c4 28             	add    $0x28,%esp
c0027c02:	5b                   	pop    %ebx
c0027c03:	c3                   	ret    

c0027c04 <strcspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters that are not in STOP. */
size_t
strcspn (const char *string, const char *stop) 
{
c0027c04:	57                   	push   %edi
c0027c05:	56                   	push   %esi
c0027c06:	53                   	push   %ebx
c0027c07:	83 ec 10             	sub    $0x10,%esp
c0027c0a:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027c0e:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;

  for (length = 0; string[length] != '\0'; length++)
c0027c12:	0f b6 16             	movzbl (%esi),%edx
c0027c15:	84 d2                	test   %dl,%dl
c0027c17:	74 25                	je     c0027c3e <strcspn+0x3a>
c0027c19:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (stop, string[length]) != NULL)
c0027c1e:	0f be d2             	movsbl %dl,%edx
c0027c21:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c25:	89 3c 24             	mov    %edi,(%esp)
c0027c28:	e8 69 ff ff ff       	call   c0027b96 <strchr>
c0027c2d:	85 c0                	test   %eax,%eax
c0027c2f:	75 12                	jne    c0027c43 <strcspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027c31:	83 c3 01             	add    $0x1,%ebx
c0027c34:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027c38:	84 d2                	test   %dl,%dl
c0027c3a:	75 e2                	jne    c0027c1e <strcspn+0x1a>
c0027c3c:	eb 05                	jmp    c0027c43 <strcspn+0x3f>
c0027c3e:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027c43:	89 d8                	mov    %ebx,%eax
c0027c45:	83 c4 10             	add    $0x10,%esp
c0027c48:	5b                   	pop    %ebx
c0027c49:	5e                   	pop    %esi
c0027c4a:	5f                   	pop    %edi
c0027c4b:	c3                   	ret    

c0027c4c <strpbrk>:
/* Returns a pointer to the first character in STRING that is
   also in STOP.  If no character in STRING is in STOP, returns a
   null pointer. */
char *
strpbrk (const char *string, const char *stop) 
{
c0027c4c:	56                   	push   %esi
c0027c4d:	53                   	push   %ebx
c0027c4e:	83 ec 14             	sub    $0x14,%esp
c0027c51:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0027c55:	8b 74 24 24          	mov    0x24(%esp),%esi
  for (; *string != '\0'; string++)
c0027c59:	0f b6 13             	movzbl (%ebx),%edx
c0027c5c:	84 d2                	test   %dl,%dl
c0027c5e:	74 1f                	je     c0027c7f <strpbrk+0x33>
    if (strchr (stop, *string) != NULL)
c0027c60:	0f be d2             	movsbl %dl,%edx
c0027c63:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c67:	89 34 24             	mov    %esi,(%esp)
c0027c6a:	e8 27 ff ff ff       	call   c0027b96 <strchr>
c0027c6f:	85 c0                	test   %eax,%eax
c0027c71:	75 13                	jne    c0027c86 <strpbrk+0x3a>
  for (; *string != '\0'; string++)
c0027c73:	83 c3 01             	add    $0x1,%ebx
c0027c76:	0f b6 13             	movzbl (%ebx),%edx
c0027c79:	84 d2                	test   %dl,%dl
c0027c7b:	75 e3                	jne    c0027c60 <strpbrk+0x14>
c0027c7d:	eb 09                	jmp    c0027c88 <strpbrk+0x3c>
      return (char *) string;
  return NULL;
c0027c7f:	b8 00 00 00 00       	mov    $0x0,%eax
c0027c84:	eb 02                	jmp    c0027c88 <strpbrk+0x3c>
c0027c86:	89 d8                	mov    %ebx,%eax
}
c0027c88:	83 c4 14             	add    $0x14,%esp
c0027c8b:	5b                   	pop    %ebx
c0027c8c:	5e                   	pop    %esi
c0027c8d:	c3                   	ret    

c0027c8e <strrchr>:

/* Returns a pointer to the last occurrence of C in STRING.
   Returns a null pointer if C does not occur in STRING. */
char *
strrchr (const char *string, int c_) 
{
c0027c8e:	53                   	push   %ebx
c0027c8f:	8b 54 24 08          	mov    0x8(%esp),%edx
  char c = c_;
c0027c93:	0f b6 5c 24 0c       	movzbl 0xc(%esp),%ebx
  const char *p = NULL;

  for (; *string != '\0'; string++)
c0027c98:	0f b6 0a             	movzbl (%edx),%ecx
c0027c9b:	84 c9                	test   %cl,%cl
c0027c9d:	74 16                	je     c0027cb5 <strrchr+0x27>
  const char *p = NULL;
c0027c9f:	b8 00 00 00 00       	mov    $0x0,%eax
c0027ca4:	38 cb                	cmp    %cl,%bl
c0027ca6:	0f 44 c2             	cmove  %edx,%eax
  for (; *string != '\0'; string++)
c0027ca9:	83 c2 01             	add    $0x1,%edx
c0027cac:	0f b6 0a             	movzbl (%edx),%ecx
c0027caf:	84 c9                	test   %cl,%cl
c0027cb1:	75 f1                	jne    c0027ca4 <strrchr+0x16>
c0027cb3:	eb 05                	jmp    c0027cba <strrchr+0x2c>
  const char *p = NULL;
c0027cb5:	b8 00 00 00 00       	mov    $0x0,%eax
    if (*string == c)
      p = string;
  return (char *) p;
}
c0027cba:	5b                   	pop    %ebx
c0027cbb:	c3                   	ret    

c0027cbc <strspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters in SKIP. */
size_t
strspn (const char *string, const char *skip) 
{
c0027cbc:	57                   	push   %edi
c0027cbd:	56                   	push   %esi
c0027cbe:	53                   	push   %ebx
c0027cbf:	83 ec 10             	sub    $0x10,%esp
c0027cc2:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027cc6:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;
  
  for (length = 0; string[length] != '\0'; length++)
c0027cca:	0f b6 16             	movzbl (%esi),%edx
c0027ccd:	84 d2                	test   %dl,%dl
c0027ccf:	74 25                	je     c0027cf6 <strspn+0x3a>
c0027cd1:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (skip, string[length]) == NULL)
c0027cd6:	0f be d2             	movsbl %dl,%edx
c0027cd9:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027cdd:	89 3c 24             	mov    %edi,(%esp)
c0027ce0:	e8 b1 fe ff ff       	call   c0027b96 <strchr>
c0027ce5:	85 c0                	test   %eax,%eax
c0027ce7:	74 12                	je     c0027cfb <strspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027ce9:	83 c3 01             	add    $0x1,%ebx
c0027cec:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027cf0:	84 d2                	test   %dl,%dl
c0027cf2:	75 e2                	jne    c0027cd6 <strspn+0x1a>
c0027cf4:	eb 05                	jmp    c0027cfb <strspn+0x3f>
c0027cf6:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027cfb:	89 d8                	mov    %ebx,%eax
c0027cfd:	83 c4 10             	add    $0x10,%esp
c0027d00:	5b                   	pop    %ebx
c0027d01:	5e                   	pop    %esi
c0027d02:	5f                   	pop    %edi
c0027d03:	c3                   	ret    

c0027d04 <strtok_r>:
     'to'
     'tokenize.'
*/
char *
strtok_r (char *s, const char *delimiters, char **save_ptr) 
{
c0027d04:	55                   	push   %ebp
c0027d05:	57                   	push   %edi
c0027d06:	56                   	push   %esi
c0027d07:	53                   	push   %ebx
c0027d08:	83 ec 2c             	sub    $0x2c,%esp
c0027d0b:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c0027d0f:	8b 74 24 44          	mov    0x44(%esp),%esi
  char *token;
  
  ASSERT (delimiters != NULL);
c0027d13:	85 f6                	test   %esi,%esi
c0027d15:	75 2c                	jne    c0027d43 <strtok_r+0x3f>
c0027d17:	c7 44 24 10 bd f9 02 	movl   $0xc002f9bd,0x10(%esp)
c0027d1e:	c0 
c0027d1f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027d26:	c0 
c0027d27:	c7 44 24 08 0c dc 02 	movl   $0xc002dc0c,0x8(%esp)
c0027d2e:	c0 
c0027d2f:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0027d36:	00 
c0027d37:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027d3e:	e8 20 0c 00 00       	call   c0028963 <debug_panic>
  ASSERT (save_ptr != NULL);
c0027d43:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0027d48:	75 2c                	jne    c0027d76 <strtok_r+0x72>
c0027d4a:	c7 44 24 10 d0 f9 02 	movl   $0xc002f9d0,0x10(%esp)
c0027d51:	c0 
c0027d52:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027d59:	c0 
c0027d5a:	c7 44 24 08 0c dc 02 	movl   $0xc002dc0c,0x8(%esp)
c0027d61:	c0 
c0027d62:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c0027d69:	00 
c0027d6a:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027d71:	e8 ed 0b 00 00       	call   c0028963 <debug_panic>

  /* If S is nonnull, start from it.
     If S is null, start from saved position. */
  if (s == NULL)
c0027d76:	85 db                	test   %ebx,%ebx
c0027d78:	75 4c                	jne    c0027dc6 <strtok_r+0xc2>
    s = *save_ptr;
c0027d7a:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027d7e:	8b 18                	mov    (%eax),%ebx
  ASSERT (s != NULL);
c0027d80:	85 db                	test   %ebx,%ebx
c0027d82:	75 42                	jne    c0027dc6 <strtok_r+0xc2>
c0027d84:	c7 44 24 10 c6 f9 02 	movl   $0xc002f9c6,0x10(%esp)
c0027d8b:	c0 
c0027d8c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027d93:	c0 
c0027d94:	c7 44 24 08 0c dc 02 	movl   $0xc002dc0c,0x8(%esp)
c0027d9b:	c0 
c0027d9c:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0027da3:	00 
c0027da4:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027dab:	e8 b3 0b 00 00       	call   c0028963 <debug_panic>
  while (strchr (delimiters, *s) != NULL) 
    {
      /* strchr() will always return nonnull if we're searching
         for a null byte, because every string contains a null
         byte (at the end). */
      if (*s == '\0')
c0027db0:	89 f8                	mov    %edi,%eax
c0027db2:	84 c0                	test   %al,%al
c0027db4:	75 0d                	jne    c0027dc3 <strtok_r+0xbf>
        {
          *save_ptr = s;
c0027db6:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027dba:	89 18                	mov    %ebx,(%eax)
          return NULL;
c0027dbc:	b8 00 00 00 00       	mov    $0x0,%eax
c0027dc1:	eb 56                	jmp    c0027e19 <strtok_r+0x115>
        }

      s++;
c0027dc3:	83 c3 01             	add    $0x1,%ebx
  while (strchr (delimiters, *s) != NULL) 
c0027dc6:	0f b6 3b             	movzbl (%ebx),%edi
c0027dc9:	89 f8                	mov    %edi,%eax
c0027dcb:	0f be c0             	movsbl %al,%eax
c0027dce:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027dd2:	89 34 24             	mov    %esi,(%esp)
c0027dd5:	e8 bc fd ff ff       	call   c0027b96 <strchr>
c0027dda:	85 c0                	test   %eax,%eax
c0027ddc:	75 d2                	jne    c0027db0 <strtok_r+0xac>
c0027dde:	89 df                	mov    %ebx,%edi
    }

  /* Skip any non-DELIMITERS up to the end of the string. */
  token = s;
  while (strchr (delimiters, *s) == NULL)
    s++;
c0027de0:	83 c7 01             	add    $0x1,%edi
  while (strchr (delimiters, *s) == NULL)
c0027de3:	0f b6 2f             	movzbl (%edi),%ebp
c0027de6:	89 e8                	mov    %ebp,%eax
c0027de8:	0f be c0             	movsbl %al,%eax
c0027deb:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027def:	89 34 24             	mov    %esi,(%esp)
c0027df2:	e8 9f fd ff ff       	call   c0027b96 <strchr>
c0027df7:	85 c0                	test   %eax,%eax
c0027df9:	74 e5                	je     c0027de0 <strtok_r+0xdc>
  if (*s != '\0') 
c0027dfb:	89 e8                	mov    %ebp,%eax
c0027dfd:	84 c0                	test   %al,%al
c0027dff:	74 10                	je     c0027e11 <strtok_r+0x10d>
    {
      *s = '\0';
c0027e01:	c6 07 00             	movb   $0x0,(%edi)
      *save_ptr = s + 1;
c0027e04:	83 c7 01             	add    $0x1,%edi
c0027e07:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e0b:	89 38                	mov    %edi,(%eax)
c0027e0d:	89 d8                	mov    %ebx,%eax
c0027e0f:	eb 08                	jmp    c0027e19 <strtok_r+0x115>
    }
  else 
    *save_ptr = s;
c0027e11:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e15:	89 38                	mov    %edi,(%eax)
c0027e17:	89 d8                	mov    %ebx,%eax
  return token;
}
c0027e19:	83 c4 2c             	add    $0x2c,%esp
c0027e1c:	5b                   	pop    %ebx
c0027e1d:	5e                   	pop    %esi
c0027e1e:	5f                   	pop    %edi
c0027e1f:	5d                   	pop    %ebp
c0027e20:	c3                   	ret    

c0027e21 <memset>:

/* Sets the SIZE bytes in DST to VALUE. */
void *
memset (void *dst_, int value, size_t size) 
{
c0027e21:	56                   	push   %esi
c0027e22:	53                   	push   %ebx
c0027e23:	83 ec 24             	sub    $0x24,%esp
c0027e26:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027e2a:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c0027e2e:	8b 74 24 38          	mov    0x38(%esp),%esi
  unsigned char *dst = dst_;

  ASSERT (dst != NULL || size == 0);
c0027e32:	85 c0                	test   %eax,%eax
c0027e34:	75 04                	jne    c0027e3a <memset+0x19>
c0027e36:	85 f6                	test   %esi,%esi
c0027e38:	75 0b                	jne    c0027e45 <memset+0x24>
c0027e3a:	8d 0c 30             	lea    (%eax,%esi,1),%ecx
  
  while (size-- > 0)
c0027e3d:	89 c2                	mov    %eax,%edx
c0027e3f:	85 f6                	test   %esi,%esi
c0027e41:	75 2e                	jne    c0027e71 <memset+0x50>
c0027e43:	eb 36                	jmp    c0027e7b <memset+0x5a>
  ASSERT (dst != NULL || size == 0);
c0027e45:	c7 44 24 10 16 f9 02 	movl   $0xc002f916,0x10(%esp)
c0027e4c:	c0 
c0027e4d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027e54:	c0 
c0027e55:	c7 44 24 08 05 dc 02 	movl   $0xc002dc05,0x8(%esp)
c0027e5c:	c0 
c0027e5d:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c0027e64:	00 
c0027e65:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027e6c:	e8 f2 0a 00 00       	call   c0028963 <debug_panic>
    *dst++ = value;
c0027e71:	83 c2 01             	add    $0x1,%edx
c0027e74:	88 5a ff             	mov    %bl,-0x1(%edx)
  while (size-- > 0)
c0027e77:	39 ca                	cmp    %ecx,%edx
c0027e79:	75 f6                	jne    c0027e71 <memset+0x50>

  return dst_;
}
c0027e7b:	83 c4 24             	add    $0x24,%esp
c0027e7e:	5b                   	pop    %ebx
c0027e7f:	5e                   	pop    %esi
c0027e80:	c3                   	ret    

c0027e81 <strlen>:

/* Returns the length of STRING. */
size_t
strlen (const char *string) 
{
c0027e81:	83 ec 2c             	sub    $0x2c,%esp
c0027e84:	8b 54 24 30          	mov    0x30(%esp),%edx
  const char *p;

  ASSERT (string != NULL);
c0027e88:	85 d2                	test   %edx,%edx
c0027e8a:	74 09                	je     c0027e95 <strlen+0x14>

  for (p = string; *p != '\0'; p++)
c0027e8c:	89 d0                	mov    %edx,%eax
c0027e8e:	80 3a 00             	cmpb   $0x0,(%edx)
c0027e91:	74 38                	je     c0027ecb <strlen+0x4a>
c0027e93:	eb 2c                	jmp    c0027ec1 <strlen+0x40>
  ASSERT (string != NULL);
c0027e95:	c7 44 24 10 ae f9 02 	movl   $0xc002f9ae,0x10(%esp)
c0027e9c:	c0 
c0027e9d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027ea4:	c0 
c0027ea5:	c7 44 24 08 fe db 02 	movl   $0xc002dbfe,0x8(%esp)
c0027eac:	c0 
c0027ead:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c0027eb4:	00 
c0027eb5:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027ebc:	e8 a2 0a 00 00       	call   c0028963 <debug_panic>
  for (p = string; *p != '\0'; p++)
c0027ec1:	89 d0                	mov    %edx,%eax
c0027ec3:	83 c0 01             	add    $0x1,%eax
c0027ec6:	80 38 00             	cmpb   $0x0,(%eax)
c0027ec9:	75 f8                	jne    c0027ec3 <strlen+0x42>
    continue;
  return p - string;
c0027ecb:	29 d0                	sub    %edx,%eax
}
c0027ecd:	83 c4 2c             	add    $0x2c,%esp
c0027ed0:	c3                   	ret    

c0027ed1 <strstr>:
{
c0027ed1:	55                   	push   %ebp
c0027ed2:	57                   	push   %edi
c0027ed3:	56                   	push   %esi
c0027ed4:	53                   	push   %ebx
c0027ed5:	83 ec 1c             	sub    $0x1c,%esp
c0027ed8:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  size_t haystack_len = strlen (haystack);
c0027edc:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c0027ee1:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0027ee5:	b8 00 00 00 00       	mov    $0x0,%eax
c0027eea:	89 d9                	mov    %ebx,%ecx
c0027eec:	f2 ae                	repnz scas %es:(%edi),%al
c0027eee:	f7 d1                	not    %ecx
c0027ef0:	8d 51 ff             	lea    -0x1(%ecx),%edx
  size_t needle_len = strlen (needle);
c0027ef3:	89 ef                	mov    %ebp,%edi
c0027ef5:	89 d9                	mov    %ebx,%ecx
c0027ef7:	f2 ae                	repnz scas %es:(%edi),%al
c0027ef9:	f7 d1                	not    %ecx
c0027efb:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (haystack_len >= needle_len) 
c0027efe:	39 fa                	cmp    %edi,%edx
c0027f00:	72 30                	jb     c0027f32 <strstr+0x61>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f02:	29 fa                	sub    %edi,%edx
c0027f04:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0027f08:	bb 00 00 00 00       	mov    $0x0,%ebx
c0027f0d:	89 de                	mov    %ebx,%esi
c0027f0f:	03 74 24 30          	add    0x30(%esp),%esi
        if (!memcmp (haystack + i, needle, needle_len))
c0027f13:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0027f17:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0027f1b:	89 34 24             	mov    %esi,(%esp)
c0027f1e:	e8 8a fa ff ff       	call   c00279ad <memcmp>
c0027f23:	85 c0                	test   %eax,%eax
c0027f25:	74 12                	je     c0027f39 <strstr+0x68>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f27:	83 c3 01             	add    $0x1,%ebx
c0027f2a:	3b 5c 24 0c          	cmp    0xc(%esp),%ebx
c0027f2e:	76 dd                	jbe    c0027f0d <strstr+0x3c>
c0027f30:	eb 0b                	jmp    c0027f3d <strstr+0x6c>
  return NULL;
c0027f32:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f37:	eb 09                	jmp    c0027f42 <strstr+0x71>
        if (!memcmp (haystack + i, needle, needle_len))
c0027f39:	89 f0                	mov    %esi,%eax
c0027f3b:	eb 05                	jmp    c0027f42 <strstr+0x71>
  return NULL;
c0027f3d:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027f42:	83 c4 1c             	add    $0x1c,%esp
c0027f45:	5b                   	pop    %ebx
c0027f46:	5e                   	pop    %esi
c0027f47:	5f                   	pop    %edi
c0027f48:	5d                   	pop    %ebp
c0027f49:	c3                   	ret    

c0027f4a <strnlen>:

/* If STRING is less than MAXLEN characters in length, returns
   its actual length.  Otherwise, returns MAXLEN. */
size_t
strnlen (const char *string, size_t maxlen) 
{
c0027f4a:	8b 54 24 04          	mov    0x4(%esp),%edx
c0027f4e:	8b 4c 24 08          	mov    0x8(%esp),%ecx
  size_t length;

  for (length = 0; string[length] != '\0' && length < maxlen; length++)
c0027f52:	80 3a 00             	cmpb   $0x0,(%edx)
c0027f55:	74 18                	je     c0027f6f <strnlen+0x25>
c0027f57:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f5c:	85 c9                	test   %ecx,%ecx
c0027f5e:	74 14                	je     c0027f74 <strnlen+0x2a>
c0027f60:	83 c0 01             	add    $0x1,%eax
c0027f63:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
c0027f67:	74 0b                	je     c0027f74 <strnlen+0x2a>
c0027f69:	39 c8                	cmp    %ecx,%eax
c0027f6b:	74 07                	je     c0027f74 <strnlen+0x2a>
c0027f6d:	eb f1                	jmp    c0027f60 <strnlen+0x16>
c0027f6f:	b8 00 00 00 00       	mov    $0x0,%eax
    continue;
  return length;
}
c0027f74:	f3 c3                	repz ret 

c0027f76 <strlcpy>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcpy (char *dst, const char *src, size_t size) 
{
c0027f76:	57                   	push   %edi
c0027f77:	56                   	push   %esi
c0027f78:	53                   	push   %ebx
c0027f79:	83 ec 20             	sub    $0x20,%esp
c0027f7c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027f80:	8b 54 24 34          	mov    0x34(%esp),%edx
c0027f84:	8b 74 24 38          	mov    0x38(%esp),%esi
  size_t src_len;

  ASSERT (dst != NULL);
c0027f88:	85 db                	test   %ebx,%ebx
c0027f8a:	75 2c                	jne    c0027fb8 <strlcpy+0x42>
c0027f8c:	c7 44 24 10 e1 f9 02 	movl   $0xc002f9e1,0x10(%esp)
c0027f93:	c0 
c0027f94:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027f9b:	c0 
c0027f9c:	c7 44 24 08 f6 db 02 	movl   $0xc002dbf6,0x8(%esp)
c0027fa3:	c0 
c0027fa4:	c7 44 24 04 4a 01 00 	movl   $0x14a,0x4(%esp)
c0027fab:	00 
c0027fac:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027fb3:	e8 ab 09 00 00       	call   c0028963 <debug_panic>
  ASSERT (src != NULL);
c0027fb8:	85 d2                	test   %edx,%edx
c0027fba:	75 2c                	jne    c0027fe8 <strlcpy+0x72>
c0027fbc:	c7 44 24 10 ed f9 02 	movl   $0xc002f9ed,0x10(%esp)
c0027fc3:	c0 
c0027fc4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0027fcb:	c0 
c0027fcc:	c7 44 24 08 f6 db 02 	movl   $0xc002dbf6,0x8(%esp)
c0027fd3:	c0 
c0027fd4:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
c0027fdb:	00 
c0027fdc:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c0027fe3:	e8 7b 09 00 00       	call   c0028963 <debug_panic>

  src_len = strlen (src);
c0027fe8:	89 d7                	mov    %edx,%edi
c0027fea:	b8 00 00 00 00       	mov    $0x0,%eax
c0027fef:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0027ff4:	f2 ae                	repnz scas %es:(%edi),%al
c0027ff6:	f7 d1                	not    %ecx
c0027ff8:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (size > 0) 
c0027ffb:	85 f6                	test   %esi,%esi
c0027ffd:	74 1c                	je     c002801b <strlcpy+0xa5>
    {
      size_t dst_len = size - 1;
c0027fff:	83 ee 01             	sub    $0x1,%esi
c0028002:	39 f7                	cmp    %esi,%edi
c0028004:	0f 46 f7             	cmovbe %edi,%esi
      if (src_len < dst_len)
        dst_len = src_len;
      memcpy (dst, src, dst_len);
c0028007:	89 74 24 08          	mov    %esi,0x8(%esp)
c002800b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002800f:	89 1c 24             	mov    %ebx,(%esp)
c0028012:	e8 29 f8 ff ff       	call   c0027840 <memcpy>
      dst[dst_len] = '\0';
c0028017:	c6 04 33 00          	movb   $0x0,(%ebx,%esi,1)
    }
  return src_len;
}
c002801b:	89 f8                	mov    %edi,%eax
c002801d:	83 c4 20             	add    $0x20,%esp
c0028020:	5b                   	pop    %ebx
c0028021:	5e                   	pop    %esi
c0028022:	5f                   	pop    %edi
c0028023:	c3                   	ret    

c0028024 <strlcat>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcat (char *dst, const char *src, size_t size) 
{
c0028024:	55                   	push   %ebp
c0028025:	57                   	push   %edi
c0028026:	56                   	push   %esi
c0028027:	53                   	push   %ebx
c0028028:	83 ec 2c             	sub    $0x2c,%esp
c002802b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
c002802f:	8b 54 24 44          	mov    0x44(%esp),%edx
  size_t src_len, dst_len;

  ASSERT (dst != NULL);
c0028033:	85 ed                	test   %ebp,%ebp
c0028035:	75 2c                	jne    c0028063 <strlcat+0x3f>
c0028037:	c7 44 24 10 e1 f9 02 	movl   $0xc002f9e1,0x10(%esp)
c002803e:	c0 
c002803f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028046:	c0 
c0028047:	c7 44 24 08 ee db 02 	movl   $0xc002dbee,0x8(%esp)
c002804e:	c0 
c002804f:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
c0028056:	00 
c0028057:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c002805e:	e8 00 09 00 00       	call   c0028963 <debug_panic>
  ASSERT (src != NULL);
c0028063:	85 d2                	test   %edx,%edx
c0028065:	75 2c                	jne    c0028093 <strlcat+0x6f>
c0028067:	c7 44 24 10 ed f9 02 	movl   $0xc002f9ed,0x10(%esp)
c002806e:	c0 
c002806f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028076:	c0 
c0028077:	c7 44 24 08 ee db 02 	movl   $0xc002dbee,0x8(%esp)
c002807e:	c0 
c002807f:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
c0028086:	00 
c0028087:	c7 04 24 2f f9 02 c0 	movl   $0xc002f92f,(%esp)
c002808e:	e8 d0 08 00 00       	call   c0028963 <debug_panic>

  src_len = strlen (src);
c0028093:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c0028098:	89 d7                	mov    %edx,%edi
c002809a:	b8 00 00 00 00       	mov    $0x0,%eax
c002809f:	89 d9                	mov    %ebx,%ecx
c00280a1:	f2 ae                	repnz scas %es:(%edi),%al
c00280a3:	f7 d1                	not    %ecx
c00280a5:	8d 71 ff             	lea    -0x1(%ecx),%esi
  dst_len = strlen (dst);
c00280a8:	89 ef                	mov    %ebp,%edi
c00280aa:	89 d9                	mov    %ebx,%ecx
c00280ac:	f2 ae                	repnz scas %es:(%edi),%al
c00280ae:	89 cb                	mov    %ecx,%ebx
c00280b0:	f7 d3                	not    %ebx
c00280b2:	83 eb 01             	sub    $0x1,%ebx
  if (size > 0 && dst_len < size) 
c00280b5:	3b 5c 24 48          	cmp    0x48(%esp),%ebx
c00280b9:	73 2c                	jae    c00280e7 <strlcat+0xc3>
c00280bb:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c00280c0:	74 25                	je     c00280e7 <strlcat+0xc3>
    {
      size_t copy_cnt = size - dst_len - 1;
c00280c2:	8b 44 24 48          	mov    0x48(%esp),%eax
c00280c6:	8d 78 ff             	lea    -0x1(%eax),%edi
c00280c9:	29 df                	sub    %ebx,%edi
c00280cb:	39 f7                	cmp    %esi,%edi
c00280cd:	0f 47 fe             	cmova  %esi,%edi
      if (src_len < copy_cnt)
        copy_cnt = src_len;
      memcpy (dst + dst_len, src, copy_cnt);
c00280d0:	01 dd                	add    %ebx,%ebp
c00280d2:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00280d6:	89 54 24 04          	mov    %edx,0x4(%esp)
c00280da:	89 2c 24             	mov    %ebp,(%esp)
c00280dd:	e8 5e f7 ff ff       	call   c0027840 <memcpy>
      dst[dst_len + copy_cnt] = '\0';
c00280e2:	c6 44 3d 00 00       	movb   $0x0,0x0(%ebp,%edi,1)
    }
  return src_len + dst_len;
c00280e7:	8d 04 33             	lea    (%ebx,%esi,1),%eax
}
c00280ea:	83 c4 2c             	add    $0x2c,%esp
c00280ed:	5b                   	pop    %ebx
c00280ee:	5e                   	pop    %esi
c00280ef:	5f                   	pop    %edi
c00280f0:	5d                   	pop    %ebp
c00280f1:	c3                   	ret    
c00280f2:	90                   	nop
c00280f3:	90                   	nop
c00280f4:	90                   	nop
c00280f5:	90                   	nop
c00280f6:	90                   	nop
c00280f7:	90                   	nop
c00280f8:	90                   	nop
c00280f9:	90                   	nop
c00280fa:	90                   	nop
c00280fb:	90                   	nop
c00280fc:	90                   	nop
c00280fd:	90                   	nop
c00280fe:	90                   	nop
c00280ff:	90                   	nop

c0028100 <udiv64>:

/* Divides unsigned 64-bit N by unsigned 64-bit D and returns the
   quotient. */
static uint64_t
udiv64 (uint64_t n, uint64_t d)
{
c0028100:	55                   	push   %ebp
c0028101:	57                   	push   %edi
c0028102:	56                   	push   %esi
c0028103:	53                   	push   %ebx
c0028104:	83 ec 1c             	sub    $0x1c,%esp
c0028107:	89 04 24             	mov    %eax,(%esp)
c002810a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002810e:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0028112:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  if ((d >> 32) == 0) 
c0028116:	89 ea                	mov    %ebp,%edx
c0028118:	85 ed                	test   %ebp,%ebp
c002811a:	75 37                	jne    c0028153 <udiv64+0x53>
             <=> [b - 1/d] < b
         which is a tautology.

         Therefore, this code is correct and will not trap. */
      uint64_t b = 1ULL << 32;
      uint32_t n1 = n >> 32;
c002811c:	8b 44 24 04          	mov    0x4(%esp),%eax
      uint32_t n0 = n; 
      uint32_t d0 = d;

      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c0028120:	ba 00 00 00 00       	mov    $0x0,%edx
c0028125:	f7 f7                	div    %edi
c0028127:	89 c6                	mov    %eax,%esi
c0028129:	89 d3                	mov    %edx,%ebx
c002812b:	b9 00 00 00 00       	mov    $0x0,%ecx
c0028130:	8b 04 24             	mov    (%esp),%eax
c0028133:	ba 00 00 00 00       	mov    $0x0,%edx
c0028138:	01 c8                	add    %ecx,%eax
c002813a:	11 da                	adc    %ebx,%edx
  asm ("divl %4"
c002813c:	f7 f7                	div    %edi
      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c002813e:	ba 00 00 00 00       	mov    $0x0,%edx
c0028143:	89 f7                	mov    %esi,%edi
c0028145:	be 00 00 00 00       	mov    $0x0,%esi
c002814a:	01 f0                	add    %esi,%eax
c002814c:	11 fa                	adc    %edi,%edx
c002814e:	e9 f2 00 00 00       	jmp    c0028245 <udiv64+0x145>
    }
  else 
    {
      /* Based on the algorithm and proof available from
         http://www.hackersdelight.org/revisions.pdf. */
      if (n < d)
c0028153:	3b 6c 24 04          	cmp    0x4(%esp),%ebp
c0028157:	0f 87 d4 00 00 00    	ja     c0028231 <udiv64+0x131>
c002815d:	72 09                	jb     c0028168 <udiv64+0x68>
c002815f:	3b 3c 24             	cmp    (%esp),%edi
c0028162:	0f 87 c9 00 00 00    	ja     c0028231 <udiv64+0x131>
        return 0;
      else 
        {
          uint32_t d1 = d >> 32;
c0028168:	89 d0                	mov    %edx,%eax
  int n = 0;
c002816a:	b9 00 00 00 00       	mov    $0x0,%ecx
  if (x <= 0x0000FFFF)
c002816f:	81 fa ff ff 00 00    	cmp    $0xffff,%edx
c0028175:	77 05                	ja     c002817c <udiv64+0x7c>
      x <<= 16; 
c0028177:	c1 e0 10             	shl    $0x10,%eax
      n += 16;
c002817a:	b1 10                	mov    $0x10,%cl
  if (x <= 0x00FFFFFF)
c002817c:	3d ff ff ff 00       	cmp    $0xffffff,%eax
c0028181:	77 06                	ja     c0028189 <udiv64+0x89>
      n += 8;
c0028183:	83 c1 08             	add    $0x8,%ecx
      x <<= 8; 
c0028186:	c1 e0 08             	shl    $0x8,%eax
  if (x <= 0x0FFFFFFF)
c0028189:	3d ff ff ff 0f       	cmp    $0xfffffff,%eax
c002818e:	77 06                	ja     c0028196 <udiv64+0x96>
      n += 4;
c0028190:	83 c1 04             	add    $0x4,%ecx
      x <<= 4;
c0028193:	c1 e0 04             	shl    $0x4,%eax
  if (x <= 0x3FFFFFFF)
c0028196:	3d ff ff ff 3f       	cmp    $0x3fffffff,%eax
c002819b:	77 06                	ja     c00281a3 <udiv64+0xa3>
      n += 2;
c002819d:	83 c1 02             	add    $0x2,%ecx
      x <<= 2; 
c00281a0:	c1 e0 02             	shl    $0x2,%eax
    n++;
c00281a3:	3d 00 00 00 80       	cmp    $0x80000000,%eax
c00281a8:	83 d1 00             	adc    $0x0,%ecx
          int s = nlz (d1);
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c00281ab:	8b 04 24             	mov    (%esp),%eax
c00281ae:	8b 54 24 04          	mov    0x4(%esp),%edx
c00281b2:	0f ac d0 01          	shrd   $0x1,%edx,%eax
c00281b6:	d1 ea                	shr    %edx
c00281b8:	89 fb                	mov    %edi,%ebx
c00281ba:	89 ee                	mov    %ebp,%esi
c00281bc:	0f a5 fe             	shld   %cl,%edi,%esi
c00281bf:	d3 e3                	shl    %cl,%ebx
c00281c1:	f6 c1 20             	test   $0x20,%cl
c00281c4:	74 02                	je     c00281c8 <udiv64+0xc8>
c00281c6:	89 de                	mov    %ebx,%esi
c00281c8:	89 74 24 0c          	mov    %esi,0xc(%esp)
  asm ("divl %4"
c00281cc:	f7 74 24 0c          	divl   0xc(%esp)
c00281d0:	89 c6                	mov    %eax,%esi
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c00281d2:	b8 1f 00 00 00       	mov    $0x1f,%eax
c00281d7:	29 c8                	sub    %ecx,%eax
c00281d9:	89 c1                	mov    %eax,%ecx
c00281db:	d3 ee                	shr    %cl,%esi
c00281dd:	89 74 24 10          	mov    %esi,0x10(%esp)
c00281e1:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c00281e8:	00 
          return n - (q - 1) * d < d ? q - 1 : q; 
c00281e9:	8b 44 24 10          	mov    0x10(%esp),%eax
c00281ed:	8b 54 24 14          	mov    0x14(%esp),%edx
c00281f1:	83 c0 ff             	add    $0xffffffff,%eax
c00281f4:	83 d2 ff             	adc    $0xffffffff,%edx
c00281f7:	89 44 24 08          	mov    %eax,0x8(%esp)
c00281fb:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00281ff:	89 c1                	mov    %eax,%ecx
c0028201:	0f af d7             	imul   %edi,%edx
c0028204:	0f af cd             	imul   %ebp,%ecx
c0028207:	8d 34 0a             	lea    (%edx,%ecx,1),%esi
c002820a:	8b 44 24 08          	mov    0x8(%esp),%eax
c002820e:	f7 e7                	mul    %edi
c0028210:	01 f2                	add    %esi,%edx
c0028212:	8b 1c 24             	mov    (%esp),%ebx
c0028215:	8b 74 24 04          	mov    0x4(%esp),%esi
c0028219:	29 c3                	sub    %eax,%ebx
c002821b:	19 d6                	sbb    %edx,%esi
c002821d:	39 f5                	cmp    %esi,%ebp
c002821f:	72 1c                	jb     c002823d <udiv64+0x13d>
c0028221:	77 04                	ja     c0028227 <udiv64+0x127>
c0028223:	39 df                	cmp    %ebx,%edi
c0028225:	76 16                	jbe    c002823d <udiv64+0x13d>
c0028227:	8b 44 24 08          	mov    0x8(%esp),%eax
c002822b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002822f:	eb 14                	jmp    c0028245 <udiv64+0x145>
        return 0;
c0028231:	b8 00 00 00 00       	mov    $0x0,%eax
c0028236:	ba 00 00 00 00       	mov    $0x0,%edx
c002823b:	eb 08                	jmp    c0028245 <udiv64+0x145>
          return n - (q - 1) * d < d ? q - 1 : q; 
c002823d:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028241:	8b 54 24 14          	mov    0x14(%esp),%edx
        }
    }
}
c0028245:	83 c4 1c             	add    $0x1c,%esp
c0028248:	5b                   	pop    %ebx
c0028249:	5e                   	pop    %esi
c002824a:	5f                   	pop    %edi
c002824b:	5d                   	pop    %ebp
c002824c:	c3                   	ret    

c002824d <sdiv64>:

/* Divides signed 64-bit N by signed 64-bit D and returns the
   quotient. */
static int64_t
sdiv64 (int64_t n, int64_t d)
{
c002824d:	57                   	push   %edi
c002824e:	56                   	push   %esi
c002824f:	53                   	push   %ebx
c0028250:	83 ec 10             	sub    $0x10,%esp
c0028253:	89 44 24 08          	mov    %eax,0x8(%esp)
c0028257:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002825b:	8b 74 24 20          	mov    0x20(%esp),%esi
c002825f:	8b 7c 24 24          	mov    0x24(%esp),%edi
  uint64_t n_abs = n >= 0 ? (uint64_t) n : -(uint64_t) n;
c0028263:	85 d2                	test   %edx,%edx
c0028265:	79 0f                	jns    c0028276 <sdiv64+0x29>
c0028267:	8b 44 24 08          	mov    0x8(%esp),%eax
c002826b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002826f:	f7 d8                	neg    %eax
c0028271:	83 d2 00             	adc    $0x0,%edx
c0028274:	f7 da                	neg    %edx
  uint64_t d_abs = d >= 0 ? (uint64_t) d : -(uint64_t) d;
c0028276:	85 ff                	test   %edi,%edi
c0028278:	78 06                	js     c0028280 <sdiv64+0x33>
c002827a:	89 f1                	mov    %esi,%ecx
c002827c:	89 fb                	mov    %edi,%ebx
c002827e:	eb 0b                	jmp    c002828b <sdiv64+0x3e>
c0028280:	89 f1                	mov    %esi,%ecx
c0028282:	89 fb                	mov    %edi,%ebx
c0028284:	f7 d9                	neg    %ecx
c0028286:	83 d3 00             	adc    $0x0,%ebx
c0028289:	f7 db                	neg    %ebx
  uint64_t q_abs = udiv64 (n_abs, d_abs);
c002828b:	89 0c 24             	mov    %ecx,(%esp)
c002828e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0028292:	e8 69 fe ff ff       	call   c0028100 <udiv64>
  return (n < 0) == (d < 0) ? (int64_t) q_abs : -(int64_t) q_abs;
c0028297:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
c002829b:	f7 d1                	not    %ecx
c002829d:	c1 e9 1f             	shr    $0x1f,%ecx
c00282a0:	89 fb                	mov    %edi,%ebx
c00282a2:	c1 eb 1f             	shr    $0x1f,%ebx
c00282a5:	89 c6                	mov    %eax,%esi
c00282a7:	89 d7                	mov    %edx,%edi
c00282a9:	f7 de                	neg    %esi
c00282ab:	83 d7 00             	adc    $0x0,%edi
c00282ae:	f7 df                	neg    %edi
c00282b0:	39 cb                	cmp    %ecx,%ebx
c00282b2:	74 04                	je     c00282b8 <sdiv64+0x6b>
c00282b4:	89 c6                	mov    %eax,%esi
c00282b6:	89 d7                	mov    %edx,%edi
}
c00282b8:	89 f0                	mov    %esi,%eax
c00282ba:	89 fa                	mov    %edi,%edx
c00282bc:	83 c4 10             	add    $0x10,%esp
c00282bf:	5b                   	pop    %ebx
c00282c0:	5e                   	pop    %esi
c00282c1:	5f                   	pop    %edi
c00282c2:	c3                   	ret    

c00282c3 <__divdi3>:
unsigned long long __umoddi3 (unsigned long long n, unsigned long long d);

/* Signed 64-bit division. */
long long
__divdi3 (long long n, long long d) 
{
c00282c3:	83 ec 0c             	sub    $0xc,%esp
  return sdiv64 (n, d);
c00282c6:	8b 44 24 18          	mov    0x18(%esp),%eax
c00282ca:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00282ce:	89 04 24             	mov    %eax,(%esp)
c00282d1:	89 54 24 04          	mov    %edx,0x4(%esp)
c00282d5:	8b 44 24 10          	mov    0x10(%esp),%eax
c00282d9:	8b 54 24 14          	mov    0x14(%esp),%edx
c00282dd:	e8 6b ff ff ff       	call   c002824d <sdiv64>
}
c00282e2:	83 c4 0c             	add    $0xc,%esp
c00282e5:	c3                   	ret    

c00282e6 <__moddi3>:

/* Signed 64-bit remainder. */
long long
__moddi3 (long long n, long long d) 
{
c00282e6:	56                   	push   %esi
c00282e7:	53                   	push   %ebx
c00282e8:	83 ec 0c             	sub    $0xc,%esp
c00282eb:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c00282ef:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * sdiv64 (n, d);
c00282f3:	89 34 24             	mov    %esi,(%esp)
c00282f6:	8b 44 24 24          	mov    0x24(%esp),%eax
c00282fa:	89 44 24 04          	mov    %eax,0x4(%esp)
c00282fe:	89 d8                	mov    %ebx,%eax
c0028300:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028304:	e8 44 ff ff ff       	call   c002824d <sdiv64>
c0028309:	0f af f0             	imul   %eax,%esi
c002830c:	89 d8                	mov    %ebx,%eax
c002830e:	29 f0                	sub    %esi,%eax
  return smod64 (n, d);
c0028310:	99                   	cltd   
}
c0028311:	83 c4 0c             	add    $0xc,%esp
c0028314:	5b                   	pop    %ebx
c0028315:	5e                   	pop    %esi
c0028316:	c3                   	ret    

c0028317 <__udivdi3>:

/* Unsigned 64-bit division. */
unsigned long long
__udivdi3 (unsigned long long n, unsigned long long d) 
{
c0028317:	83 ec 0c             	sub    $0xc,%esp
  return udiv64 (n, d);
c002831a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002831e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028322:	89 04 24             	mov    %eax,(%esp)
c0028325:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028329:	8b 44 24 10          	mov    0x10(%esp),%eax
c002832d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028331:	e8 ca fd ff ff       	call   c0028100 <udiv64>
}
c0028336:	83 c4 0c             	add    $0xc,%esp
c0028339:	c3                   	ret    

c002833a <__umoddi3>:

/* Unsigned 64-bit remainder. */
unsigned long long
__umoddi3 (unsigned long long n, unsigned long long d) 
{
c002833a:	56                   	push   %esi
c002833b:	53                   	push   %ebx
c002833c:	83 ec 0c             	sub    $0xc,%esp
c002833f:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c0028343:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * udiv64 (n, d);
c0028347:	89 34 24             	mov    %esi,(%esp)
c002834a:	8b 44 24 24          	mov    0x24(%esp),%eax
c002834e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028352:	89 d8                	mov    %ebx,%eax
c0028354:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028358:	e8 a3 fd ff ff       	call   c0028100 <udiv64>
c002835d:	0f af f0             	imul   %eax,%esi
c0028360:	89 d8                	mov    %ebx,%eax
c0028362:	29 f0                	sub    %esi,%eax
  return umod64 (n, d);
c0028364:	ba 00 00 00 00       	mov    $0x0,%edx
}
c0028369:	83 c4 0c             	add    $0xc,%esp
c002836c:	5b                   	pop    %ebx
c002836d:	5e                   	pop    %esi
c002836e:	c3                   	ret    

c002836f <parse_octal_field>:
   seems ambiguous as to whether these fields must be padded on
   the left with '0's, so we accept any field that fits in the
   available space, regardless of whether it fills the space. */
static bool
parse_octal_field (const char *s, size_t size, unsigned long int *value)
{
c002836f:	55                   	push   %ebp
c0028370:	57                   	push   %edi
c0028371:	56                   	push   %esi
c0028372:	53                   	push   %ebx
c0028373:	83 ec 04             	sub    $0x4,%esp
c0028376:	89 04 24             	mov    %eax,(%esp)
c0028379:	89 d5                	mov    %edx,%ebp
  size_t ofs;

  *value = 0;
c002837b:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
          return false;
        }
    }

  /* Field did not end in space or null byte. */
  return false;
c0028381:	b8 00 00 00 00       	mov    $0x0,%eax
  for (ofs = 0; ofs < size; ofs++)
c0028386:	85 d2                	test   %edx,%edx
c0028388:	74 66                	je     c00283f0 <parse_octal_field+0x81>
c002838a:	eb 45                	jmp    c00283d1 <parse_octal_field+0x62>
      char c = s[ofs];
c002838c:	8b 04 24             	mov    (%esp),%eax
c002838f:	0f b6 14 18          	movzbl (%eax,%ebx,1),%edx
      if (c >= '0' && c <= '7')
c0028393:	8d 7a d0             	lea    -0x30(%edx),%edi
c0028396:	89 f8                	mov    %edi,%eax
c0028398:	3c 07                	cmp    $0x7,%al
c002839a:	77 24                	ja     c00283c0 <parse_octal_field+0x51>
          if (*value > ULONG_MAX / 8)
c002839c:	81 fe ff ff ff 1f    	cmp    $0x1fffffff,%esi
c00283a2:	77 47                	ja     c00283eb <parse_octal_field+0x7c>
          *value = c - '0' + *value * 8;
c00283a4:	0f be fa             	movsbl %dl,%edi
c00283a7:	8d 74 f7 d0          	lea    -0x30(%edi,%esi,8),%esi
c00283ab:	89 31                	mov    %esi,(%ecx)
  for (ofs = 0; ofs < size; ofs++)
c00283ad:	83 c3 01             	add    $0x1,%ebx
c00283b0:	39 eb                	cmp    %ebp,%ebx
c00283b2:	75 d8                	jne    c002838c <parse_octal_field+0x1d>
  return false;
c00283b4:	b8 00 00 00 00       	mov    $0x0,%eax
c00283b9:	eb 35                	jmp    c00283f0 <parse_octal_field+0x81>
  for (ofs = 0; ofs < size; ofs++)
c00283bb:	bb 00 00 00 00       	mov    $0x0,%ebx
          return false;
c00283c0:	b8 00 00 00 00       	mov    $0x0,%eax
      else if (c == ' ' || c == '\0')
c00283c5:	f6 c2 df             	test   $0xdf,%dl
c00283c8:	75 26                	jne    c00283f0 <parse_octal_field+0x81>
          return ofs > 0;
c00283ca:	85 db                	test   %ebx,%ebx
c00283cc:	0f 95 c0             	setne  %al
c00283cf:	eb 1f                	jmp    c00283f0 <parse_octal_field+0x81>
      char c = s[ofs];
c00283d1:	8b 04 24             	mov    (%esp),%eax
c00283d4:	0f b6 10             	movzbl (%eax),%edx
      if (c >= '0' && c <= '7')
c00283d7:	8d 5a d0             	lea    -0x30(%edx),%ebx
c00283da:	80 fb 07             	cmp    $0x7,%bl
c00283dd:	77 dc                	ja     c00283bb <parse_octal_field+0x4c>
          if (*value > ULONG_MAX / 8)
c00283df:	be 00 00 00 00       	mov    $0x0,%esi
  for (ofs = 0; ofs < size; ofs++)
c00283e4:	bb 00 00 00 00       	mov    $0x0,%ebx
c00283e9:	eb b9                	jmp    c00283a4 <parse_octal_field+0x35>
              return false;
c00283eb:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00283f0:	83 c4 04             	add    $0x4,%esp
c00283f3:	5b                   	pop    %ebx
c00283f4:	5e                   	pop    %esi
c00283f5:	5f                   	pop    %edi
c00283f6:	5d                   	pop    %ebp
c00283f7:	c3                   	ret    

c00283f8 <strip_antisocial_prefixes>:
{
c00283f8:	57                   	push   %edi
c00283f9:	56                   	push   %esi
c00283fa:	53                   	push   %ebx
c00283fb:	83 ec 10             	sub    $0x10,%esp
c00283fe:	89 c3                	mov    %eax,%ebx
  while (*file_name == '/'
c0028400:	eb 13                	jmp    c0028415 <strip_antisocial_prefixes+0x1d>
    file_name = strchr (file_name, '/') + 1;
c0028402:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0028409:	00 
c002840a:	89 1c 24             	mov    %ebx,(%esp)
c002840d:	e8 84 f7 ff ff       	call   c0027b96 <strchr>
c0028412:	8d 58 01             	lea    0x1(%eax),%ebx
  while (*file_name == '/'
c0028415:	0f b6 33             	movzbl (%ebx),%esi
c0028418:	89 f0                	mov    %esi,%eax
c002841a:	3c 2f                	cmp    $0x2f,%al
c002841c:	74 e4                	je     c0028402 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "./", 2)
c002841e:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
c0028425:	00 
c0028426:	c7 44 24 04 91 ed 02 	movl   $0xc002ed91,0x4(%esp)
c002842d:	c0 
c002842e:	89 1c 24             	mov    %ebx,(%esp)
c0028431:	e8 77 f5 ff ff       	call   c00279ad <memcmp>
c0028436:	85 c0                	test   %eax,%eax
c0028438:	74 c8                	je     c0028402 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "../", 3))
c002843a:	c7 44 24 08 03 00 00 	movl   $0x3,0x8(%esp)
c0028441:	00 
c0028442:	c7 44 24 04 f9 f9 02 	movl   $0xc002f9f9,0x4(%esp)
c0028449:	c0 
c002844a:	89 1c 24             	mov    %ebx,(%esp)
c002844d:	e8 5b f5 ff ff       	call   c00279ad <memcmp>
c0028452:	85 c0                	test   %eax,%eax
c0028454:	74 ac                	je     c0028402 <strip_antisocial_prefixes+0xa>
  return *file_name == '\0' || !strcmp (file_name, "..") ? "." : file_name;
c0028456:	b8 17 f3 02 c0       	mov    $0xc002f317,%eax
c002845b:	89 f2                	mov    %esi,%edx
c002845d:	84 d2                	test   %dl,%dl
c002845f:	74 23                	je     c0028484 <strip_antisocial_prefixes+0x8c>
c0028461:	bf 16 f3 02 c0       	mov    $0xc002f316,%edi
c0028466:	b9 03 00 00 00       	mov    $0x3,%ecx
c002846b:	89 de                	mov    %ebx,%esi
c002846d:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c002846f:	0f 97 c0             	seta   %al
c0028472:	0f 92 c2             	setb   %dl
c0028475:	29 d0                	sub    %edx,%eax
c0028477:	0f be c0             	movsbl %al,%eax
c002847a:	85 c0                	test   %eax,%eax
c002847c:	b8 17 f3 02 c0       	mov    $0xc002f317,%eax
c0028481:	0f 45 c3             	cmovne %ebx,%eax
}
c0028484:	83 c4 10             	add    $0x10,%esp
c0028487:	5b                   	pop    %ebx
c0028488:	5e                   	pop    %esi
c0028489:	5f                   	pop    %edi
c002848a:	c3                   	ret    

c002848b <ustar_make_header>:
{
c002848b:	55                   	push   %ebp
c002848c:	57                   	push   %edi
c002848d:	56                   	push   %esi
c002848e:	53                   	push   %ebx
c002848f:	83 ec 2c             	sub    $0x2c,%esp
c0028492:	8b 5c 24 4c          	mov    0x4c(%esp),%ebx
  ASSERT (type == USTAR_REGULAR || type == USTAR_DIRECTORY);
c0028496:	83 7c 24 44 30       	cmpl   $0x30,0x44(%esp)
c002849b:	0f 94 c0             	sete   %al
c002849e:	89 c6                	mov    %eax,%esi
c00284a0:	88 44 24 1f          	mov    %al,0x1f(%esp)
c00284a4:	83 7c 24 44 35       	cmpl   $0x35,0x44(%esp)
c00284a9:	0f 94 c0             	sete   %al
c00284ac:	89 f2                	mov    %esi,%edx
c00284ae:	08 d0                	or     %dl,%al
c00284b0:	75 2c                	jne    c00284de <ustar_make_header+0x53>
c00284b2:	c7 44 24 10 e4 fa 02 	movl   $0xc002fae4,0x10(%esp)
c00284b9:	c0 
c00284ba:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00284c1:	c0 
c00284c2:	c7 44 24 08 40 dc 02 	movl   $0xc002dc40,0x8(%esp)
c00284c9:	c0 
c00284ca:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c00284d1:	00 
c00284d2:	c7 04 24 fd f9 02 c0 	movl   $0xc002f9fd,(%esp)
c00284d9:	e8 85 04 00 00       	call   c0028963 <debug_panic>
c00284de:	89 c5                	mov    %eax,%ebp
  file_name = strip_antisocial_prefixes (file_name);
c00284e0:	8b 44 24 40          	mov    0x40(%esp),%eax
c00284e4:	e8 0f ff ff ff       	call   c00283f8 <strip_antisocial_prefixes>
c00284e9:	89 c2                	mov    %eax,%edx
  if (strlen (file_name) > 99)
c00284eb:	89 c7                	mov    %eax,%edi
c00284ed:	b8 00 00 00 00       	mov    $0x0,%eax
c00284f2:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c00284f7:	f2 ae                	repnz scas %es:(%edi),%al
c00284f9:	f7 d1                	not    %ecx
c00284fb:	83 e9 01             	sub    $0x1,%ecx
c00284fe:	83 f9 63             	cmp    $0x63,%ecx
c0028501:	76 1a                	jbe    c002851d <ustar_make_header+0x92>
      printf ("%s: file name too long\n", file_name);
c0028503:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028507:	c7 04 24 0f fa 02 c0 	movl   $0xc002fa0f,(%esp)
c002850e:	e8 fb e5 ff ff       	call   c0026b0e <printf>
      return false;
c0028513:	bd 00 00 00 00       	mov    $0x0,%ebp
c0028518:	e9 d0 01 00 00       	jmp    c00286ed <ustar_make_header+0x262>
  memset (h, 0, sizeof *h);
c002851d:	89 df                	mov    %ebx,%edi
c002851f:	be 00 02 00 00       	mov    $0x200,%esi
c0028524:	f6 c3 01             	test   $0x1,%bl
c0028527:	74 0a                	je     c0028533 <ustar_make_header+0xa8>
c0028529:	c6 03 00             	movb   $0x0,(%ebx)
c002852c:	8d 7b 01             	lea    0x1(%ebx),%edi
c002852f:	66 be ff 01          	mov    $0x1ff,%si
c0028533:	f7 c7 02 00 00 00    	test   $0x2,%edi
c0028539:	74 0b                	je     c0028546 <ustar_make_header+0xbb>
c002853b:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0028540:	83 c7 02             	add    $0x2,%edi
c0028543:	83 ee 02             	sub    $0x2,%esi
c0028546:	89 f1                	mov    %esi,%ecx
c0028548:	c1 e9 02             	shr    $0x2,%ecx
c002854b:	b8 00 00 00 00       	mov    $0x0,%eax
c0028550:	f3 ab                	rep stos %eax,%es:(%edi)
c0028552:	f7 c6 02 00 00 00    	test   $0x2,%esi
c0028558:	74 08                	je     c0028562 <ustar_make_header+0xd7>
c002855a:	66 c7 07 00 00       	movw   $0x0,(%edi)
c002855f:	83 c7 02             	add    $0x2,%edi
c0028562:	f7 c6 01 00 00 00    	test   $0x1,%esi
c0028568:	74 03                	je     c002856d <ustar_make_header+0xe2>
c002856a:	c6 07 00             	movb   $0x0,(%edi)
  strlcpy (h->name, file_name, sizeof h->name);
c002856d:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0028574:	00 
c0028575:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028579:	89 1c 24             	mov    %ebx,(%esp)
c002857c:	e8 f5 f9 ff ff       	call   c0027f76 <strlcpy>
  snprintf (h->mode, sizeof h->mode, "%07o",
c0028581:	80 7c 24 1f 01       	cmpb   $0x1,0x1f(%esp)
c0028586:	19 c0                	sbb    %eax,%eax
c0028588:	83 e0 49             	and    $0x49,%eax
c002858b:	05 a4 01 00 00       	add    $0x1a4,%eax
c0028590:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0028594:	c7 44 24 08 27 fa 02 	movl   $0xc002fa27,0x8(%esp)
c002859b:	c0 
c002859c:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c00285a3:	00 
c00285a4:	8d 43 64             	lea    0x64(%ebx),%eax
c00285a7:	89 04 24             	mov    %eax,(%esp)
c00285aa:	e8 60 ec ff ff       	call   c002720f <snprintf>
  strlcpy (h->uid, "0000000", sizeof h->uid);
c00285af:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c00285b6:	00 
c00285b7:	c7 44 24 04 2c fa 02 	movl   $0xc002fa2c,0x4(%esp)
c00285be:	c0 
c00285bf:	8d 43 6c             	lea    0x6c(%ebx),%eax
c00285c2:	89 04 24             	mov    %eax,(%esp)
c00285c5:	e8 ac f9 ff ff       	call   c0027f76 <strlcpy>
  strlcpy (h->gid, "0000000", sizeof h->gid);
c00285ca:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c00285d1:	00 
c00285d2:	c7 44 24 04 2c fa 02 	movl   $0xc002fa2c,0x4(%esp)
c00285d9:	c0 
c00285da:	8d 43 74             	lea    0x74(%ebx),%eax
c00285dd:	89 04 24             	mov    %eax,(%esp)
c00285e0:	e8 91 f9 ff ff       	call   c0027f76 <strlcpy>
  snprintf (h->size, sizeof h->size, "%011o", size);
c00285e5:	8b 44 24 48          	mov    0x48(%esp),%eax
c00285e9:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00285ed:	c7 44 24 08 34 fa 02 	movl   $0xc002fa34,0x8(%esp)
c00285f4:	c0 
c00285f5:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c00285fc:	00 
c00285fd:	8d 43 7c             	lea    0x7c(%ebx),%eax
c0028600:	89 04 24             	mov    %eax,(%esp)
c0028603:	e8 07 ec ff ff       	call   c002720f <snprintf>
  snprintf (h->mtime, sizeof h->size, "%011o", 1136102400);
c0028608:	c7 44 24 0c 00 8c b7 	movl   $0x43b78c00,0xc(%esp)
c002860f:	43 
c0028610:	c7 44 24 08 34 fa 02 	movl   $0xc002fa34,0x8(%esp)
c0028617:	c0 
c0028618:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002861f:	00 
c0028620:	8d 83 88 00 00 00    	lea    0x88(%ebx),%eax
c0028626:	89 04 24             	mov    %eax,(%esp)
c0028629:	e8 e1 eb ff ff       	call   c002720f <snprintf>
  h->typeflag = type;
c002862e:	0f b6 44 24 44       	movzbl 0x44(%esp),%eax
c0028633:	88 83 9c 00 00 00    	mov    %al,0x9c(%ebx)
  strlcpy (h->magic, "ustar", sizeof h->magic);
c0028639:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028640:	00 
c0028641:	c7 44 24 04 3a fa 02 	movl   $0xc002fa3a,0x4(%esp)
c0028648:	c0 
c0028649:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002864f:	89 04 24             	mov    %eax,(%esp)
c0028652:	e8 1f f9 ff ff       	call   c0027f76 <strlcpy>
  h->version[0] = h->version[1] = '0';
c0028657:	c6 83 08 01 00 00 30 	movb   $0x30,0x108(%ebx)
c002865e:	c6 83 07 01 00 00 30 	movb   $0x30,0x107(%ebx)
  strlcpy (h->gname, "root", sizeof h->gname);
c0028665:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c002866c:	00 
c002866d:	c7 44 24 04 48 ef 02 	movl   $0xc002ef48,0x4(%esp)
c0028674:	c0 
c0028675:	8d 83 29 01 00 00    	lea    0x129(%ebx),%eax
c002867b:	89 04 24             	mov    %eax,(%esp)
c002867e:	e8 f3 f8 ff ff       	call   c0027f76 <strlcpy>
  strlcpy (h->uname, "root", sizeof h->uname);
c0028683:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c002868a:	00 
c002868b:	c7 44 24 04 48 ef 02 	movl   $0xc002ef48,0x4(%esp)
c0028692:	c0 
c0028693:	8d 83 09 01 00 00    	lea    0x109(%ebx),%eax
c0028699:	89 04 24             	mov    %eax,(%esp)
c002869c:	e8 d5 f8 ff ff       	call   c0027f76 <strlcpy>
c00286a1:	b8 6c ff ff ff       	mov    $0xffffff6c,%eax
  chksum = 0;
c00286a6:	ba 00 00 00 00       	mov    $0x0,%edx
      chksum += in_chksum_field ? ' ' : header[i];
c00286ab:	83 f8 07             	cmp    $0x7,%eax
c00286ae:	76 0a                	jbe    c00286ba <ustar_make_header+0x22f>
c00286b0:	0f b6 8c 03 94 00 00 	movzbl 0x94(%ebx,%eax,1),%ecx
c00286b7:	00 
c00286b8:	eb 05                	jmp    c00286bf <ustar_make_header+0x234>
c00286ba:	b9 20 00 00 00       	mov    $0x20,%ecx
c00286bf:	01 ca                	add    %ecx,%edx
c00286c1:	83 c0 01             	add    $0x1,%eax
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c00286c4:	3d 6c 01 00 00       	cmp    $0x16c,%eax
c00286c9:	75 e0                	jne    c00286ab <ustar_make_header+0x220>
  snprintf (h->chksum, sizeof h->chksum, "%07o", calculate_chksum (h));
c00286cb:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00286cf:	c7 44 24 08 27 fa 02 	movl   $0xc002fa27,0x8(%esp)
c00286d6:	c0 
c00286d7:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c00286de:	00 
c00286df:	81 c3 94 00 00 00    	add    $0x94,%ebx
c00286e5:	89 1c 24             	mov    %ebx,(%esp)
c00286e8:	e8 22 eb ff ff       	call   c002720f <snprintf>
}
c00286ed:	89 e8                	mov    %ebp,%eax
c00286ef:	83 c4 2c             	add    $0x2c,%esp
c00286f2:	5b                   	pop    %ebx
c00286f3:	5e                   	pop    %esi
c00286f4:	5f                   	pop    %edi
c00286f5:	5d                   	pop    %ebp
c00286f6:	c3                   	ret    

c00286f7 <ustar_parse_header>:
   and returns a null pointer.  On failure, returns a
   human-readable error message. */
const char *
ustar_parse_header (const char header[USTAR_HEADER_SIZE],
                    const char **file_name, enum ustar_type *type, int *size)
{
c00286f7:	53                   	push   %ebx
c00286f8:	83 ec 28             	sub    $0x28,%esp
c00286fb:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00286ff:	8d 8b 00 02 00 00    	lea    0x200(%ebx),%ecx
c0028705:	89 da                	mov    %ebx,%edx
    if (*block++ != 0)
c0028707:	83 c2 01             	add    $0x1,%edx
c002870a:	80 7a ff 00          	cmpb   $0x0,-0x1(%edx)
c002870e:	0f 85 25 01 00 00    	jne    c0028839 <ustar_parse_header+0x142>
  while (cnt-- > 0)
c0028714:	39 ca                	cmp    %ecx,%edx
c0028716:	75 ef                	jne    c0028707 <ustar_parse_header+0x10>
c0028718:	e9 4b 01 00 00       	jmp    c0028868 <ustar_parse_header+0x171>

  /* Validate ustar header. */
  if (memcmp (h->magic, "ustar", 6))
    return "not a ustar archive";
  else if (h->version[0] != '0' || h->version[1] != '0')
    return "invalid ustar version";
c002871d:	b8 54 fa 02 c0       	mov    $0xc002fa54,%eax
  else if (h->version[0] != '0' || h->version[1] != '0')
c0028722:	80 bb 07 01 00 00 30 	cmpb   $0x30,0x107(%ebx)
c0028729:	0f 85 5c 01 00 00    	jne    c002888b <ustar_parse_header+0x194>
c002872f:	80 bb 08 01 00 00 30 	cmpb   $0x30,0x108(%ebx)
c0028736:	0f 85 4f 01 00 00    	jne    c002888b <ustar_parse_header+0x194>
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c002873c:	8d 83 94 00 00 00    	lea    0x94(%ebx),%eax
c0028742:	8d 4c 24 1c          	lea    0x1c(%esp),%ecx
c0028746:	ba 08 00 00 00       	mov    $0x8,%edx
c002874b:	e8 1f fc ff ff       	call   c002836f <parse_octal_field>
c0028750:	89 c2                	mov    %eax,%edx
    return "corrupt chksum field";
c0028752:	b8 6a fa 02 c0       	mov    $0xc002fa6a,%eax
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c0028757:	84 d2                	test   %dl,%dl
c0028759:	0f 84 2c 01 00 00    	je     c002888b <ustar_parse_header+0x194>
c002875f:	ba 6c ff ff ff       	mov    $0xffffff6c,%edx
c0028764:	b9 00 00 00 00       	mov    $0x0,%ecx
      chksum += in_chksum_field ? ' ' : header[i];
c0028769:	83 fa 07             	cmp    $0x7,%edx
c002876c:	76 0a                	jbe    c0028778 <ustar_parse_header+0x81>
c002876e:	0f b6 84 13 94 00 00 	movzbl 0x94(%ebx,%edx,1),%eax
c0028775:	00 
c0028776:	eb 05                	jmp    c002877d <ustar_parse_header+0x86>
c0028778:	b8 20 00 00 00       	mov    $0x20,%eax
c002877d:	01 c1                	add    %eax,%ecx
c002877f:	83 c2 01             	add    $0x1,%edx
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c0028782:	81 fa 6c 01 00 00    	cmp    $0x16c,%edx
c0028788:	75 df                	jne    c0028769 <ustar_parse_header+0x72>
  else if (chksum != calculate_chksum (h))
    return "checksum mismatch";
c002878a:	b8 7f fa 02 c0       	mov    $0xc002fa7f,%eax
  else if (chksum != calculate_chksum (h))
c002878f:	39 4c 24 1c          	cmp    %ecx,0x1c(%esp)
c0028793:	0f 85 f2 00 00 00    	jne    c002888b <ustar_parse_header+0x194>
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
    return "file name too long";
c0028799:	b8 91 fa 02 c0       	mov    $0xc002fa91,%eax
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
c002879e:	80 7b 63 00          	cmpb   $0x0,0x63(%ebx)
c00287a2:	0f 85 e3 00 00 00    	jne    c002888b <ustar_parse_header+0x194>
c00287a8:	80 bb 59 01 00 00 00 	cmpb   $0x0,0x159(%ebx)
c00287af:	0f 85 d6 00 00 00    	jne    c002888b <ustar_parse_header+0x194>
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c00287b5:	0f b6 93 9c 00 00 00 	movzbl 0x9c(%ebx),%edx
c00287bc:	80 fa 35             	cmp    $0x35,%dl
c00287bf:	74 0e                	je     c00287cf <ustar_parse_header+0xd8>
    return "unimplemented file type";
c00287c1:	b8 a4 fa 02 c0       	mov    $0xc002faa4,%eax
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c00287c6:	80 fa 30             	cmp    $0x30,%dl
c00287c9:	0f 85 bc 00 00 00    	jne    c002888b <ustar_parse_header+0x194>
  if (h->typeflag == USTAR_REGULAR)
c00287cf:	80 fa 30             	cmp    $0x30,%dl
c00287d2:	75 32                	jne    c0028806 <ustar_parse_header+0x10f>
    {
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c00287d4:	8d 43 7c             	lea    0x7c(%ebx),%eax
c00287d7:	8d 4c 24 18          	lea    0x18(%esp),%ecx
c00287db:	ba 0c 00 00 00       	mov    $0xc,%edx
c00287e0:	e8 8a fb ff ff       	call   c002836f <parse_octal_field>
c00287e5:	89 c2                	mov    %eax,%edx
        return "corrupt file size field";
c00287e7:	b8 bc fa 02 c0       	mov    $0xc002fabc,%eax
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c00287ec:	84 d2                	test   %dl,%dl
c00287ee:	0f 84 97 00 00 00    	je     c002888b <ustar_parse_header+0x194>
      else if (size_ul > INT_MAX)
        return "file too large";
c00287f4:	b8 d4 fa 02 c0       	mov    $0xc002fad4,%eax
      else if (size_ul > INT_MAX)
c00287f9:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c00287fe:	0f 88 87 00 00 00    	js     c002888b <ustar_parse_header+0x194>
c0028804:	eb 08                	jmp    c002880e <ustar_parse_header+0x117>
    }
  else
    size_ul = 0;
c0028806:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c002880d:	00 

  /* Success. */
  *file_name = strip_antisocial_prefixes (h->name);
c002880e:	89 d8                	mov    %ebx,%eax
c0028810:	e8 e3 fb ff ff       	call   c00283f8 <strip_antisocial_prefixes>
c0028815:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0028819:	89 01                	mov    %eax,(%ecx)
  *type = h->typeflag;
c002881b:	0f be 83 9c 00 00 00 	movsbl 0x9c(%ebx),%eax
c0028822:	8b 5c 24 38          	mov    0x38(%esp),%ebx
c0028826:	89 03                	mov    %eax,(%ebx)
  *size = size_ul;
c0028828:	8b 44 24 18          	mov    0x18(%esp),%eax
c002882c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
c0028830:	89 03                	mov    %eax,(%ebx)
  return NULL;
c0028832:	b8 00 00 00 00       	mov    $0x0,%eax
c0028837:	eb 52                	jmp    c002888b <ustar_parse_header+0x194>
  if (memcmp (h->magic, "ustar", 6))
c0028839:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028840:	00 
c0028841:	c7 44 24 04 3a fa 02 	movl   $0xc002fa3a,0x4(%esp)
c0028848:	c0 
c0028849:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002884f:	89 04 24             	mov    %eax,(%esp)
c0028852:	e8 56 f1 ff ff       	call   c00279ad <memcmp>
c0028857:	89 c2                	mov    %eax,%edx
    return "not a ustar archive";
c0028859:	b8 40 fa 02 c0       	mov    $0xc002fa40,%eax
  if (memcmp (h->magic, "ustar", 6))
c002885e:	85 d2                	test   %edx,%edx
c0028860:	0f 84 b7 fe ff ff    	je     c002871d <ustar_parse_header+0x26>
c0028866:	eb 23                	jmp    c002888b <ustar_parse_header+0x194>
      *file_name = NULL;
c0028868:	8b 44 24 34          	mov    0x34(%esp),%eax
c002886c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      *type = USTAR_EOF;
c0028872:	8b 44 24 38          	mov    0x38(%esp),%eax
c0028876:	c7 00 ff ff ff ff    	movl   $0xffffffff,(%eax)
      *size = 0;
c002887c:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c0028880:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      return NULL;
c0028886:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002888b:	83 c4 28             	add    $0x28,%esp
c002888e:	5b                   	pop    %ebx
c002888f:	c3                   	ret    

c0028890 <print_stacktrace>:

/* Print call stack of a thread.
   The thread may be running, ready, or blocked. */
static void
print_stacktrace(struct thread *t, void *aux UNUSED)
{
c0028890:	55                   	push   %ebp
c0028891:	89 e5                	mov    %esp,%ebp
c0028893:	53                   	push   %ebx
c0028894:	83 ec 14             	sub    $0x14,%esp
c0028897:	8b 5d 08             	mov    0x8(%ebp),%ebx
  void *retaddr = NULL, **frame = NULL;
  const char *status = "UNKNOWN";

  switch (t->status) {
c002889a:	8b 43 04             	mov    0x4(%ebx),%eax
    case THREAD_RUNNING:  
      status = "RUNNING";
      break;

    case THREAD_READY:  
      status = "READY";
c002889d:	ba 15 fb 02 c0       	mov    $0xc002fb15,%edx
  switch (t->status) {
c00288a2:	83 f8 01             	cmp    $0x1,%eax
c00288a5:	74 1a                	je     c00288c1 <print_stacktrace+0x31>
      status = "RUNNING";
c00288a7:	ba 49 e5 02 c0       	mov    $0xc002e549,%edx
  switch (t->status) {
c00288ac:	83 f8 01             	cmp    $0x1,%eax
c00288af:	72 10                	jb     c00288c1 <print_stacktrace+0x31>
c00288b1:	83 f8 02             	cmp    $0x2,%eax
  const char *status = "UNKNOWN";
c00288b4:	b8 1b fb 02 c0       	mov    $0xc002fb1b,%eax
c00288b9:	ba 03 e5 02 c0       	mov    $0xc002e503,%edx
c00288be:	0f 45 d0             	cmovne %eax,%edx

    default:
      break;
  }

  printf ("Call stack of thread `%s' (status %s):", t->name, status);
c00288c1:	89 54 24 08          	mov    %edx,0x8(%esp)
c00288c5:	8d 43 08             	lea    0x8(%ebx),%eax
c00288c8:	89 44 24 04          	mov    %eax,0x4(%esp)
c00288cc:	c7 04 24 40 fb 02 c0 	movl   $0xc002fb40,(%esp)
c00288d3:	e8 36 e2 ff ff       	call   c0026b0e <printf>

  if (t == thread_current()) 
c00288d8:	e8 fc 84 ff ff       	call   c0020dd9 <thread_current>
c00288dd:	39 d8                	cmp    %ebx,%eax
c00288df:	75 08                	jne    c00288e9 <print_stacktrace+0x59>
    {
      frame = __builtin_frame_address (1);
c00288e1:	8b 5d 00             	mov    0x0(%ebp),%ebx
      retaddr = __builtin_return_address (0);
c00288e4:	8b 55 04             	mov    0x4(%ebp),%edx
c00288e7:	eb 29                	jmp    c0028912 <print_stacktrace+0x82>
    {
      /* Retrieve the values of the base and instruction pointers
         as they were saved when this thread called switch_threads. */
      struct switch_threads_frame * saved_frame;

      saved_frame = (struct switch_threads_frame *)t->stack;
c00288e9:	8b 43 18             	mov    0x18(%ebx),%eax
         list, but have never been scheduled.
         We can identify because their `stack' member either points 
         at the top of their kernel stack page, or the 
         switch_threads_frame's 'eip' member points at switch_entry.
         See also threads.c. */
      if (t->stack == (uint8_t *)t + PGSIZE || saved_frame->eip == switch_entry)
c00288ec:	81 c3 00 10 00 00    	add    $0x1000,%ebx
c00288f2:	39 d8                	cmp    %ebx,%eax
c00288f4:	74 0b                	je     c0028901 <print_stacktrace+0x71>
c00288f6:	8b 50 10             	mov    0x10(%eax),%edx
c00288f9:	81 fa ec 17 02 c0    	cmp    $0xc00217ec,%edx
c00288ff:	75 0e                	jne    c002890f <print_stacktrace+0x7f>
        {
          printf (" thread was never scheduled.\n");
c0028901:	c7 04 24 23 fb 02 c0 	movl   $0xc002fb23,(%esp)
c0028908:	e8 7e 1d 00 00       	call   c002a68b <puts>
          return;
c002890d:	eb 4e                	jmp    c002895d <print_stacktrace+0xcd>
        }

      frame = (void **) saved_frame->ebp;
c002890f:	8b 58 08             	mov    0x8(%eax),%ebx
      retaddr = (void *) saved_frame->eip;
    }

  printf (" %p", retaddr);
c0028912:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028916:	c7 04 24 80 f7 02 c0 	movl   $0xc002f780,(%esp)
c002891d:	e8 ec e1 ff ff       	call   c0026b0e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028922:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0028928:	76 27                	jbe    c0028951 <print_stacktrace+0xc1>
c002892a:	83 3b 00             	cmpl   $0x0,(%ebx)
c002892d:	74 22                	je     c0028951 <print_stacktrace+0xc1>
    printf (" %p", frame[1]);
c002892f:	8b 43 04             	mov    0x4(%ebx),%eax
c0028932:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028936:	c7 04 24 80 f7 02 c0 	movl   $0xc002f780,(%esp)
c002893d:	e8 cc e1 ff ff       	call   c0026b0e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028942:	8b 1b                	mov    (%ebx),%ebx
c0028944:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c002894a:	76 05                	jbe    c0028951 <print_stacktrace+0xc1>
c002894c:	83 3b 00             	cmpl   $0x0,(%ebx)
c002894f:	75 de                	jne    c002892f <print_stacktrace+0x9f>
  printf (".\n");
c0028951:	c7 04 24 17 f3 02 c0 	movl   $0xc002f317,(%esp)
c0028958:	e8 2e 1d 00 00       	call   c002a68b <puts>
}
c002895d:	83 c4 14             	add    $0x14,%esp
c0028960:	5b                   	pop    %ebx
c0028961:	5d                   	pop    %ebp
c0028962:	c3                   	ret    

c0028963 <debug_panic>:
{
c0028963:	57                   	push   %edi
c0028964:	56                   	push   %esi
c0028965:	53                   	push   %ebx
c0028966:	83 ec 10             	sub    $0x10,%esp
c0028969:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002896d:	8b 74 24 24          	mov    0x24(%esp),%esi
c0028971:	8b 7c 24 28          	mov    0x28(%esp),%edi
  intr_disable ();
c0028975:	e8 25 90 ff ff       	call   c002199f <intr_disable>
  console_panic ();
c002897a:	e8 9d 1c 00 00       	call   c002a61c <console_panic>
  level++;
c002897f:	a1 c0 7a 03 c0       	mov    0xc0037ac0,%eax
c0028984:	83 c0 01             	add    $0x1,%eax
c0028987:	a3 c0 7a 03 c0       	mov    %eax,0xc0037ac0
  if (level == 1) 
c002898c:	83 f8 01             	cmp    $0x1,%eax
c002898f:	75 3f                	jne    c00289d0 <debug_panic+0x6d>
      printf ("Kernel PANIC at %s:%d in %s(): ", file, line, function);
c0028991:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0028995:	89 74 24 08          	mov    %esi,0x8(%esp)
c0028999:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002899d:	c7 04 24 68 fb 02 c0 	movl   $0xc002fb68,(%esp)
c00289a4:	e8 65 e1 ff ff       	call   c0026b0e <printf>
      va_start (args, message);
c00289a9:	8d 44 24 30          	lea    0x30(%esp),%eax
      vprintf (message, args);
c00289ad:	89 44 24 04          	mov    %eax,0x4(%esp)
c00289b1:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00289b5:	89 04 24             	mov    %eax,(%esp)
c00289b8:	e8 8d 1c 00 00       	call   c002a64a <vprintf>
      printf ("\n");
c00289bd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00289c4:	e8 33 1d 00 00       	call   c002a6fc <putchar>
      debug_backtrace ();
c00289c9:	e8 73 db ff ff       	call   c0026541 <debug_backtrace>
c00289ce:	eb 1d                	jmp    c00289ed <debug_panic+0x8a>
  else if (level == 2)
c00289d0:	83 f8 02             	cmp    $0x2,%eax
c00289d3:	75 18                	jne    c00289ed <debug_panic+0x8a>
    printf ("Kernel PANIC recursion at %s:%d in %s().\n",
c00289d5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00289d9:	89 74 24 08          	mov    %esi,0x8(%esp)
c00289dd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00289e1:	c7 04 24 88 fb 02 c0 	movl   $0xc002fb88,(%esp)
c00289e8:	e8 21 e1 ff ff       	call   c0026b0e <printf>
  serial_flush ();
c00289ed:	e8 8a c1 ff ff       	call   c0024b7c <serial_flush>
  shutdown ();
c00289f2:	e8 79 da ff ff       	call   c0026470 <shutdown>
c00289f7:	eb fe                	jmp    c00289f7 <debug_panic+0x94>

c00289f9 <debug_backtrace_all>:

/* Prints call stack of all threads. */
void
debug_backtrace_all (void)
{
c00289f9:	53                   	push   %ebx
c00289fa:	83 ec 18             	sub    $0x18,%esp
  enum intr_level oldlevel = intr_disable ();
c00289fd:	e8 9d 8f ff ff       	call   c002199f <intr_disable>
c0028a02:	89 c3                	mov    %eax,%ebx

  thread_foreach (print_stacktrace, 0);
c0028a04:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0028a0b:	00 
c0028a0c:	c7 04 24 90 88 02 c0 	movl   $0xc0028890,(%esp)
c0028a13:	e8 a2 84 ff ff       	call   c0020eba <thread_foreach>
  intr_set_level (oldlevel);
c0028a18:	89 1c 24             	mov    %ebx,(%esp)
c0028a1b:	e8 86 8f ff ff       	call   c00219a6 <intr_set_level>
}
c0028a20:	83 c4 18             	add    $0x18,%esp
c0028a23:	5b                   	pop    %ebx
c0028a24:	c3                   	ret    
c0028a25:	90                   	nop
c0028a26:	90                   	nop
c0028a27:	90                   	nop
c0028a28:	90                   	nop
c0028a29:	90                   	nop
c0028a2a:	90                   	nop
c0028a2b:	90                   	nop
c0028a2c:	90                   	nop
c0028a2d:	90                   	nop
c0028a2e:	90                   	nop
c0028a2f:	90                   	nop

c0028a30 <list_init>:
}

/* Initializes LIST as an empty list. */
void
list_init (struct list *list)
{
c0028a30:	83 ec 2c             	sub    $0x2c,%esp
c0028a33:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028a37:	85 c0                	test   %eax,%eax
c0028a39:	75 2c                	jne    c0028a67 <list_init+0x37>
c0028a3b:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0028a42:	c0 
c0028a43:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028a4a:	c0 
c0028a4b:	c7 44 24 08 25 dd 02 	movl   $0xc002dd25,0x8(%esp)
c0028a52:	c0 
c0028a53:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0028a5a:	00 
c0028a5b:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028a62:	e8 fc fe ff ff       	call   c0028963 <debug_panic>
  list->head.prev = NULL;
c0028a67:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  list->head.next = &list->tail;
c0028a6d:	8d 50 08             	lea    0x8(%eax),%edx
c0028a70:	89 50 04             	mov    %edx,0x4(%eax)
  list->tail.prev = &list->head;
c0028a73:	89 40 08             	mov    %eax,0x8(%eax)
  list->tail.next = NULL;
c0028a76:	c7 40 0c 00 00 00 00 	movl   $0x0,0xc(%eax)
}
c0028a7d:	83 c4 2c             	add    $0x2c,%esp
c0028a80:	c3                   	ret    

c0028a81 <list_begin>:

/* Returns the beginning of LIST.  */
struct list_elem *
list_begin (struct list *list)
{
c0028a81:	83 ec 2c             	sub    $0x2c,%esp
c0028a84:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028a88:	85 c0                	test   %eax,%eax
c0028a8a:	75 2c                	jne    c0028ab8 <list_begin+0x37>
c0028a8c:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0028a93:	c0 
c0028a94:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028a9b:	c0 
c0028a9c:	c7 44 24 08 1a dd 02 	movl   $0xc002dd1a,0x8(%esp)
c0028aa3:	c0 
c0028aa4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0028aab:	00 
c0028aac:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028ab3:	e8 ab fe ff ff       	call   c0028963 <debug_panic>
  return list->head.next;
c0028ab8:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028abb:	83 c4 2c             	add    $0x2c,%esp
c0028abe:	c3                   	ret    

c0028abf <list_next>:
/* Returns the element after ELEM in its list.  If ELEM is the
   last element in its list, returns the list tail.  Results are
   undefined if ELEM is itself a list tail. */
struct list_elem *
list_next (struct list_elem *elem)
{
c0028abf:	83 ec 2c             	sub    $0x2c,%esp
c0028ac2:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev == NULL && elem->next != NULL;
c0028ac6:	85 c0                	test   %eax,%eax
c0028ac8:	74 16                	je     c0028ae0 <list_next+0x21>
c0028aca:	83 38 00             	cmpl   $0x0,(%eax)
c0028acd:	75 06                	jne    c0028ad5 <list_next+0x16>
c0028acf:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028ad3:	75 37                	jne    c0028b0c <list_next+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ad5:	83 38 00             	cmpl   $0x0,(%eax)
c0028ad8:	74 06                	je     c0028ae0 <list_next+0x21>
c0028ada:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028ade:	75 2c                	jne    c0028b0c <list_next+0x4d>
  ASSERT (is_head (elem) || is_interior (elem));
c0028ae0:	c7 44 24 10 68 fc 02 	movl   $0xc002fc68,0x10(%esp)
c0028ae7:	c0 
c0028ae8:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028aef:	c0 
c0028af0:	c7 44 24 08 10 dd 02 	movl   $0xc002dd10,0x8(%esp)
c0028af7:	c0 
c0028af8:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0028aff:	00 
c0028b00:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028b07:	e8 57 fe ff ff       	call   c0028963 <debug_panic>
  return elem->next;
c0028b0c:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028b0f:	83 c4 2c             	add    $0x2c,%esp
c0028b12:	c3                   	ret    

c0028b13 <list_end>:
   list_end() is often used in iterating through a list from
   front to back.  See the big comment at the top of list.h for
   an example. */
struct list_elem *
list_end (struct list *list)
{
c0028b13:	83 ec 2c             	sub    $0x2c,%esp
c0028b16:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b1a:	85 c0                	test   %eax,%eax
c0028b1c:	75 2c                	jne    c0028b4a <list_end+0x37>
c0028b1e:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0028b25:	c0 
c0028b26:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028b2d:	c0 
c0028b2e:	c7 44 24 08 07 dd 02 	movl   $0xc002dd07,0x8(%esp)
c0028b35:	c0 
c0028b36:	c7 44 24 04 60 00 00 	movl   $0x60,0x4(%esp)
c0028b3d:	00 
c0028b3e:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028b45:	e8 19 fe ff ff       	call   c0028963 <debug_panic>
  return &list->tail;
c0028b4a:	83 c0 08             	add    $0x8,%eax
}
c0028b4d:	83 c4 2c             	add    $0x2c,%esp
c0028b50:	c3                   	ret    

c0028b51 <list_rbegin>:

/* Returns the LIST's reverse beginning, for iterating through
   LIST in reverse order, from back to front. */
struct list_elem *
list_rbegin (struct list *list) 
{
c0028b51:	83 ec 2c             	sub    $0x2c,%esp
c0028b54:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b58:	85 c0                	test   %eax,%eax
c0028b5a:	75 2c                	jne    c0028b88 <list_rbegin+0x37>
c0028b5c:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0028b63:	c0 
c0028b64:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028b6b:	c0 
c0028b6c:	c7 44 24 08 fb dc 02 	movl   $0xc002dcfb,0x8(%esp)
c0028b73:	c0 
c0028b74:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0028b7b:	00 
c0028b7c:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028b83:	e8 db fd ff ff       	call   c0028963 <debug_panic>
  return list->tail.prev;
c0028b88:	8b 40 08             	mov    0x8(%eax),%eax
}
c0028b8b:	83 c4 2c             	add    $0x2c,%esp
c0028b8e:	c3                   	ret    

c0028b8f <list_prev>:
/* Returns the element before ELEM in its list.  If ELEM is the
   first element in its list, returns the list head.  Results are
   undefined if ELEM is itself a list head. */
struct list_elem *
list_prev (struct list_elem *elem)
{
c0028b8f:	83 ec 2c             	sub    $0x2c,%esp
c0028b92:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028b96:	85 c0                	test   %eax,%eax
c0028b98:	74 16                	je     c0028bb0 <list_prev+0x21>
c0028b9a:	83 38 00             	cmpl   $0x0,(%eax)
c0028b9d:	74 06                	je     c0028ba5 <list_prev+0x16>
c0028b9f:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028ba3:	75 37                	jne    c0028bdc <list_prev+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028ba5:	83 38 00             	cmpl   $0x0,(%eax)
c0028ba8:	74 06                	je     c0028bb0 <list_prev+0x21>
c0028baa:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028bae:	74 2c                	je     c0028bdc <list_prev+0x4d>
  ASSERT (is_interior (elem) || is_tail (elem));
c0028bb0:	c7 44 24 10 90 fc 02 	movl   $0xc002fc90,0x10(%esp)
c0028bb7:	c0 
c0028bb8:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028bbf:	c0 
c0028bc0:	c7 44 24 08 f1 dc 02 	movl   $0xc002dcf1,0x8(%esp)
c0028bc7:	c0 
c0028bc8:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c0028bcf:	00 
c0028bd0:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028bd7:	e8 87 fd ff ff       	call   c0028963 <debug_panic>
  return elem->prev;
c0028bdc:	8b 00                	mov    (%eax),%eax
}
c0028bde:	83 c4 2c             	add    $0x2c,%esp
c0028be1:	c3                   	ret    

c0028be2 <find_end_of_run>:
   run.
   A through B (exclusive) must form a non-empty range. */
static struct list_elem *
find_end_of_run (struct list_elem *a, struct list_elem *b,
                 list_less_func *less, void *aux)
{
c0028be2:	55                   	push   %ebp
c0028be3:	57                   	push   %edi
c0028be4:	56                   	push   %esi
c0028be5:	53                   	push   %ebx
c0028be6:	83 ec 2c             	sub    $0x2c,%esp
c0028be9:	89 c3                	mov    %eax,%ebx
c0028beb:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (a != NULL);
c0028bef:	85 c0                	test   %eax,%eax
c0028bf1:	75 2c                	jne    c0028c1f <find_end_of_run+0x3d>
c0028bf3:	c7 44 24 10 c5 e9 02 	movl   $0xc002e9c5,0x10(%esp)
c0028bfa:	c0 
c0028bfb:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028c02:	c0 
c0028c03:	c7 44 24 08 80 dc 02 	movl   $0xc002dc80,0x8(%esp)
c0028c0a:	c0 
c0028c0b:	c7 44 24 04 6a 01 00 	movl   $0x16a,0x4(%esp)
c0028c12:	00 
c0028c13:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028c1a:	e8 44 fd ff ff       	call   c0028963 <debug_panic>
c0028c1f:	89 d6                	mov    %edx,%esi
c0028c21:	89 cf                	mov    %ecx,%edi
  ASSERT (b != NULL);
c0028c23:	85 d2                	test   %edx,%edx
c0028c25:	75 2c                	jne    c0028c53 <find_end_of_run+0x71>
c0028c27:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c0028c2e:	c0 
c0028c2f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028c36:	c0 
c0028c37:	c7 44 24 08 80 dc 02 	movl   $0xc002dc80,0x8(%esp)
c0028c3e:	c0 
c0028c3f:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c0028c46:	00 
c0028c47:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028c4e:	e8 10 fd ff ff       	call   c0028963 <debug_panic>
  ASSERT (less != NULL);
c0028c53:	85 c9                	test   %ecx,%ecx
c0028c55:	75 2c                	jne    c0028c83 <find_end_of_run+0xa1>
c0028c57:	c7 44 24 10 d7 fb 02 	movl   $0xc002fbd7,0x10(%esp)
c0028c5e:	c0 
c0028c5f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028c66:	c0 
c0028c67:	c7 44 24 08 80 dc 02 	movl   $0xc002dc80,0x8(%esp)
c0028c6e:	c0 
c0028c6f:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c0028c76:	00 
c0028c77:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028c7e:	e8 e0 fc ff ff       	call   c0028963 <debug_panic>
  ASSERT (a != b);
c0028c83:	39 d0                	cmp    %edx,%eax
c0028c85:	75 2c                	jne    c0028cb3 <find_end_of_run+0xd1>
c0028c87:	c7 44 24 10 e4 fb 02 	movl   $0xc002fbe4,0x10(%esp)
c0028c8e:	c0 
c0028c8f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028c96:	c0 
c0028c97:	c7 44 24 08 80 dc 02 	movl   $0xc002dc80,0x8(%esp)
c0028c9e:	c0 
c0028c9f:	c7 44 24 04 6d 01 00 	movl   $0x16d,0x4(%esp)
c0028ca6:	00 
c0028ca7:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028cae:	e8 b0 fc ff ff       	call   c0028963 <debug_panic>
  
  do 
    {
      a = list_next (a);
c0028cb3:	89 1c 24             	mov    %ebx,(%esp)
c0028cb6:	e8 04 fe ff ff       	call   c0028abf <list_next>
c0028cbb:	89 c3                	mov    %eax,%ebx
    }
  while (a != b && !less (a, list_prev (a), aux));
c0028cbd:	39 f0                	cmp    %esi,%eax
c0028cbf:	74 19                	je     c0028cda <find_end_of_run+0xf8>
c0028cc1:	89 04 24             	mov    %eax,(%esp)
c0028cc4:	e8 c6 fe ff ff       	call   c0028b8f <list_prev>
c0028cc9:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0028ccd:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028cd1:	89 1c 24             	mov    %ebx,(%esp)
c0028cd4:	ff d7                	call   *%edi
c0028cd6:	84 c0                	test   %al,%al
c0028cd8:	74 d9                	je     c0028cb3 <find_end_of_run+0xd1>
  return a;
}
c0028cda:	89 d8                	mov    %ebx,%eax
c0028cdc:	83 c4 2c             	add    $0x2c,%esp
c0028cdf:	5b                   	pop    %ebx
c0028ce0:	5e                   	pop    %esi
c0028ce1:	5f                   	pop    %edi
c0028ce2:	5d                   	pop    %ebp
c0028ce3:	c3                   	ret    

c0028ce4 <is_sorted>:
{
c0028ce4:	55                   	push   %ebp
c0028ce5:	57                   	push   %edi
c0028ce6:	56                   	push   %esi
c0028ce7:	53                   	push   %ebx
c0028ce8:	83 ec 1c             	sub    $0x1c,%esp
c0028ceb:	89 c3                	mov    %eax,%ebx
c0028ced:	89 d6                	mov    %edx,%esi
c0028cef:	89 cd                	mov    %ecx,%ebp
c0028cf1:	8b 7c 24 30          	mov    0x30(%esp),%edi
  if (a != b)
c0028cf5:	39 d0                	cmp    %edx,%eax
c0028cf7:	75 1b                	jne    c0028d14 <is_sorted+0x30>
c0028cf9:	eb 2e                	jmp    c0028d29 <is_sorted+0x45>
      if (less (a, list_prev (a), aux))
c0028cfb:	89 1c 24             	mov    %ebx,(%esp)
c0028cfe:	e8 8c fe ff ff       	call   c0028b8f <list_prev>
c0028d03:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0028d07:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028d0b:	89 1c 24             	mov    %ebx,(%esp)
c0028d0e:	ff d5                	call   *%ebp
c0028d10:	84 c0                	test   %al,%al
c0028d12:	75 1c                	jne    c0028d30 <is_sorted+0x4c>
    while ((a = list_next (a)) != b) 
c0028d14:	89 1c 24             	mov    %ebx,(%esp)
c0028d17:	e8 a3 fd ff ff       	call   c0028abf <list_next>
c0028d1c:	89 c3                	mov    %eax,%ebx
c0028d1e:	39 f0                	cmp    %esi,%eax
c0028d20:	75 d9                	jne    c0028cfb <is_sorted+0x17>
  return true;
c0028d22:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d27:	eb 0c                	jmp    c0028d35 <is_sorted+0x51>
c0028d29:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d2e:	eb 05                	jmp    c0028d35 <is_sorted+0x51>
        return false;
c0028d30:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028d35:	83 c4 1c             	add    $0x1c,%esp
c0028d38:	5b                   	pop    %ebx
c0028d39:	5e                   	pop    %esi
c0028d3a:	5f                   	pop    %edi
c0028d3b:	5d                   	pop    %ebp
c0028d3c:	c3                   	ret    

c0028d3d <list_rend>:
{
c0028d3d:	83 ec 2c             	sub    $0x2c,%esp
c0028d40:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028d44:	85 c0                	test   %eax,%eax
c0028d46:	75 2c                	jne    c0028d74 <list_rend+0x37>
c0028d48:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0028d4f:	c0 
c0028d50:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028d57:	c0 
c0028d58:	c7 44 24 08 e7 dc 02 	movl   $0xc002dce7,0x8(%esp)
c0028d5f:	c0 
c0028d60:	c7 44 24 04 87 00 00 	movl   $0x87,0x4(%esp)
c0028d67:	00 
c0028d68:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028d6f:	e8 ef fb ff ff       	call   c0028963 <debug_panic>
}
c0028d74:	83 c4 2c             	add    $0x2c,%esp
c0028d77:	c3                   	ret    

c0028d78 <list_head>:
{
c0028d78:	83 ec 2c             	sub    $0x2c,%esp
c0028d7b:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028d7f:	85 c0                	test   %eax,%eax
c0028d81:	75 2c                	jne    c0028daf <list_head+0x37>
c0028d83:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0028d8a:	c0 
c0028d8b:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028d92:	c0 
c0028d93:	c7 44 24 08 dd dc 02 	movl   $0xc002dcdd,0x8(%esp)
c0028d9a:	c0 
c0028d9b:	c7 44 24 04 99 00 00 	movl   $0x99,0x4(%esp)
c0028da2:	00 
c0028da3:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028daa:	e8 b4 fb ff ff       	call   c0028963 <debug_panic>
}
c0028daf:	83 c4 2c             	add    $0x2c,%esp
c0028db2:	c3                   	ret    

c0028db3 <list_tail>:
{
c0028db3:	83 ec 2c             	sub    $0x2c,%esp
c0028db6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028dba:	85 c0                	test   %eax,%eax
c0028dbc:	75 2c                	jne    c0028dea <list_tail+0x37>
c0028dbe:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0028dc5:	c0 
c0028dc6:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028dcd:	c0 
c0028dce:	c7 44 24 08 d3 dc 02 	movl   $0xc002dcd3,0x8(%esp)
c0028dd5:	c0 
c0028dd6:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c0028ddd:	00 
c0028dde:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028de5:	e8 79 fb ff ff       	call   c0028963 <debug_panic>
  return &list->tail;
c0028dea:	83 c0 08             	add    $0x8,%eax
}
c0028ded:	83 c4 2c             	add    $0x2c,%esp
c0028df0:	c3                   	ret    

c0028df1 <list_insert>:
{
c0028df1:	83 ec 2c             	sub    $0x2c,%esp
c0028df4:	8b 44 24 30          	mov    0x30(%esp),%eax
c0028df8:	8b 54 24 34          	mov    0x34(%esp),%edx
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028dfc:	85 c0                	test   %eax,%eax
c0028dfe:	74 56                	je     c0028e56 <list_insert+0x65>
c0028e00:	83 38 00             	cmpl   $0x0,(%eax)
c0028e03:	74 06                	je     c0028e0b <list_insert+0x1a>
c0028e05:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e09:	75 0b                	jne    c0028e16 <list_insert+0x25>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028e0b:	83 38 00             	cmpl   $0x0,(%eax)
c0028e0e:	74 46                	je     c0028e56 <list_insert+0x65>
c0028e10:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e14:	75 40                	jne    c0028e56 <list_insert+0x65>
  ASSERT (elem != NULL);
c0028e16:	85 d2                	test   %edx,%edx
c0028e18:	75 2c                	jne    c0028e46 <list_insert+0x55>
c0028e1a:	c7 44 24 10 eb fb 02 	movl   $0xc002fbeb,0x10(%esp)
c0028e21:	c0 
c0028e22:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028e29:	c0 
c0028e2a:	c7 44 24 08 c7 dc 02 	movl   $0xc002dcc7,0x8(%esp)
c0028e31:	c0 
c0028e32:	c7 44 24 04 ac 00 00 	movl   $0xac,0x4(%esp)
c0028e39:	00 
c0028e3a:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028e41:	e8 1d fb ff ff       	call   c0028963 <debug_panic>
  elem->prev = before->prev;
c0028e46:	8b 08                	mov    (%eax),%ecx
c0028e48:	89 0a                	mov    %ecx,(%edx)
  elem->next = before;
c0028e4a:	89 42 04             	mov    %eax,0x4(%edx)
  before->prev->next = elem;
c0028e4d:	8b 08                	mov    (%eax),%ecx
c0028e4f:	89 51 04             	mov    %edx,0x4(%ecx)
  before->prev = elem;
c0028e52:	89 10                	mov    %edx,(%eax)
c0028e54:	eb 2c                	jmp    c0028e82 <list_insert+0x91>
  ASSERT (is_interior (before) || is_tail (before));
c0028e56:	c7 44 24 10 b8 fc 02 	movl   $0xc002fcb8,0x10(%esp)
c0028e5d:	c0 
c0028e5e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028e65:	c0 
c0028e66:	c7 44 24 08 c7 dc 02 	movl   $0xc002dcc7,0x8(%esp)
c0028e6d:	c0 
c0028e6e:	c7 44 24 04 ab 00 00 	movl   $0xab,0x4(%esp)
c0028e75:	00 
c0028e76:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028e7d:	e8 e1 fa ff ff       	call   c0028963 <debug_panic>
}
c0028e82:	83 c4 2c             	add    $0x2c,%esp
c0028e85:	c3                   	ret    

c0028e86 <list_splice>:
{
c0028e86:	56                   	push   %esi
c0028e87:	53                   	push   %ebx
c0028e88:	83 ec 24             	sub    $0x24,%esp
c0028e8b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0028e8f:	8b 74 24 34          	mov    0x34(%esp),%esi
c0028e93:	8b 44 24 38          	mov    0x38(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028e97:	85 db                	test   %ebx,%ebx
c0028e99:	74 4d                	je     c0028ee8 <list_splice+0x62>
c0028e9b:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028e9e:	74 06                	je     c0028ea6 <list_splice+0x20>
c0028ea0:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028ea4:	75 0b                	jne    c0028eb1 <list_splice+0x2b>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028ea6:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028ea9:	74 3d                	je     c0028ee8 <list_splice+0x62>
c0028eab:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028eaf:	75 37                	jne    c0028ee8 <list_splice+0x62>
  if (first == last)
c0028eb1:	39 c6                	cmp    %eax,%esi
c0028eb3:	0f 84 cf 00 00 00    	je     c0028f88 <list_splice+0x102>
  last = list_prev (last);
c0028eb9:	89 04 24             	mov    %eax,(%esp)
c0028ebc:	e8 ce fc ff ff       	call   c0028b8f <list_prev>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ec1:	85 f6                	test   %esi,%esi
c0028ec3:	74 4f                	je     c0028f14 <list_splice+0x8e>
c0028ec5:	8b 16                	mov    (%esi),%edx
c0028ec7:	85 d2                	test   %edx,%edx
c0028ec9:	74 49                	je     c0028f14 <list_splice+0x8e>
c0028ecb:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0028ecf:	75 6f                	jne    c0028f40 <list_splice+0xba>
c0028ed1:	eb 41                	jmp    c0028f14 <list_splice+0x8e>
c0028ed3:	83 38 00             	cmpl   $0x0,(%eax)
c0028ed6:	74 6c                	je     c0028f44 <list_splice+0xbe>
c0028ed8:	8b 48 04             	mov    0x4(%eax),%ecx
c0028edb:	85 c9                	test   %ecx,%ecx
c0028edd:	8d 76 00             	lea    0x0(%esi),%esi
c0028ee0:	0f 85 8a 00 00 00    	jne    c0028f70 <list_splice+0xea>
c0028ee6:	eb 5c                	jmp    c0028f44 <list_splice+0xbe>
  ASSERT (is_interior (before) || is_tail (before));
c0028ee8:	c7 44 24 10 b8 fc 02 	movl   $0xc002fcb8,0x10(%esp)
c0028eef:	c0 
c0028ef0:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028ef7:	c0 
c0028ef8:	c7 44 24 08 bb dc 02 	movl   $0xc002dcbb,0x8(%esp)
c0028eff:	c0 
c0028f00:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c0028f07:	00 
c0028f08:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028f0f:	e8 4f fa ff ff       	call   c0028963 <debug_panic>
  ASSERT (is_interior (first));
c0028f14:	c7 44 24 10 f8 fb 02 	movl   $0xc002fbf8,0x10(%esp)
c0028f1b:	c0 
c0028f1c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028f23:	c0 
c0028f24:	c7 44 24 08 bb dc 02 	movl   $0xc002dcbb,0x8(%esp)
c0028f2b:	c0 
c0028f2c:	c7 44 24 04 c0 00 00 	movl   $0xc0,0x4(%esp)
c0028f33:	00 
c0028f34:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028f3b:	e8 23 fa ff ff       	call   c0028963 <debug_panic>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028f40:	85 c0                	test   %eax,%eax
c0028f42:	75 8f                	jne    c0028ed3 <list_splice+0x4d>
  ASSERT (is_interior (last));
c0028f44:	c7 44 24 10 0c fc 02 	movl   $0xc002fc0c,0x10(%esp)
c0028f4b:	c0 
c0028f4c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028f53:	c0 
c0028f54:	c7 44 24 08 bb dc 02 	movl   $0xc002dcbb,0x8(%esp)
c0028f5b:	c0 
c0028f5c:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0028f63:	00 
c0028f64:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0028f6b:	e8 f3 f9 ff ff       	call   c0028963 <debug_panic>
  first->prev->next = last->next;
c0028f70:	89 4a 04             	mov    %ecx,0x4(%edx)
  last->next->prev = first->prev;
c0028f73:	8b 50 04             	mov    0x4(%eax),%edx
c0028f76:	8b 0e                	mov    (%esi),%ecx
c0028f78:	89 0a                	mov    %ecx,(%edx)
  first->prev = before->prev;
c0028f7a:	8b 13                	mov    (%ebx),%edx
c0028f7c:	89 16                	mov    %edx,(%esi)
  last->next = before;
c0028f7e:	89 58 04             	mov    %ebx,0x4(%eax)
  before->prev->next = first;
c0028f81:	8b 13                	mov    (%ebx),%edx
c0028f83:	89 72 04             	mov    %esi,0x4(%edx)
  before->prev = last;
c0028f86:	89 03                	mov    %eax,(%ebx)
}
c0028f88:	83 c4 24             	add    $0x24,%esp
c0028f8b:	5b                   	pop    %ebx
c0028f8c:	5e                   	pop    %esi
c0028f8d:	c3                   	ret    

c0028f8e <list_push_front>:
{
c0028f8e:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_begin (list), elem);
c0028f91:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028f95:	89 04 24             	mov    %eax,(%esp)
c0028f98:	e8 e4 fa ff ff       	call   c0028a81 <list_begin>
c0028f9d:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028fa1:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028fa5:	89 04 24             	mov    %eax,(%esp)
c0028fa8:	e8 44 fe ff ff       	call   c0028df1 <list_insert>
}
c0028fad:	83 c4 1c             	add    $0x1c,%esp
c0028fb0:	c3                   	ret    

c0028fb1 <list_push_back>:
{
c0028fb1:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_end (list), elem);
c0028fb4:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028fb8:	89 04 24             	mov    %eax,(%esp)
c0028fbb:	e8 53 fb ff ff       	call   c0028b13 <list_end>
c0028fc0:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028fc4:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028fc8:	89 04 24             	mov    %eax,(%esp)
c0028fcb:	e8 21 fe ff ff       	call   c0028df1 <list_insert>
}
c0028fd0:	83 c4 1c             	add    $0x1c,%esp
c0028fd3:	c3                   	ret    

c0028fd4 <list_remove>:
{
c0028fd4:	83 ec 2c             	sub    $0x2c,%esp
c0028fd7:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028fdb:	85 c0                	test   %eax,%eax
c0028fdd:	74 0d                	je     c0028fec <list_remove+0x18>
c0028fdf:	8b 10                	mov    (%eax),%edx
c0028fe1:	85 d2                	test   %edx,%edx
c0028fe3:	74 07                	je     c0028fec <list_remove+0x18>
c0028fe5:	8b 48 04             	mov    0x4(%eax),%ecx
c0028fe8:	85 c9                	test   %ecx,%ecx
c0028fea:	75 2c                	jne    c0029018 <list_remove+0x44>
  ASSERT (is_interior (elem));
c0028fec:	c7 44 24 10 1f fc 02 	movl   $0xc002fc1f,0x10(%esp)
c0028ff3:	c0 
c0028ff4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0028ffb:	c0 
c0028ffc:	c7 44 24 08 af dc 02 	movl   $0xc002dcaf,0x8(%esp)
c0029003:	c0 
c0029004:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
c002900b:	00 
c002900c:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029013:	e8 4b f9 ff ff       	call   c0028963 <debug_panic>
  elem->prev->next = elem->next;
c0029018:	89 4a 04             	mov    %ecx,0x4(%edx)
  elem->next->prev = elem->prev;
c002901b:	8b 50 04             	mov    0x4(%eax),%edx
c002901e:	8b 08                	mov    (%eax),%ecx
c0029020:	89 0a                	mov    %ecx,(%edx)
  return elem->next;
c0029022:	8b 40 04             	mov    0x4(%eax),%eax
}
c0029025:	83 c4 2c             	add    $0x2c,%esp
c0029028:	c3                   	ret    

c0029029 <list_size>:
{
c0029029:	57                   	push   %edi
c002902a:	56                   	push   %esi
c002902b:	53                   	push   %ebx
c002902c:	83 ec 10             	sub    $0x10,%esp
c002902f:	8b 7c 24 20          	mov    0x20(%esp),%edi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029033:	89 3c 24             	mov    %edi,(%esp)
c0029036:	e8 46 fa ff ff       	call   c0028a81 <list_begin>
c002903b:	89 c3                	mov    %eax,%ebx
  size_t cnt = 0;
c002903d:	be 00 00 00 00       	mov    $0x0,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029042:	eb 0d                	jmp    c0029051 <list_size+0x28>
    cnt++;
c0029044:	83 c6 01             	add    $0x1,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029047:	89 1c 24             	mov    %ebx,(%esp)
c002904a:	e8 70 fa ff ff       	call   c0028abf <list_next>
c002904f:	89 c3                	mov    %eax,%ebx
c0029051:	89 3c 24             	mov    %edi,(%esp)
c0029054:	e8 ba fa ff ff       	call   c0028b13 <list_end>
c0029059:	39 d8                	cmp    %ebx,%eax
c002905b:	75 e7                	jne    c0029044 <list_size+0x1b>
}
c002905d:	89 f0                	mov    %esi,%eax
c002905f:	83 c4 10             	add    $0x10,%esp
c0029062:	5b                   	pop    %ebx
c0029063:	5e                   	pop    %esi
c0029064:	5f                   	pop    %edi
c0029065:	c3                   	ret    

c0029066 <list_empty>:
{
c0029066:	56                   	push   %esi
c0029067:	53                   	push   %ebx
c0029068:	83 ec 14             	sub    $0x14,%esp
c002906b:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  return list_begin (list) == list_end (list);
c002906f:	89 1c 24             	mov    %ebx,(%esp)
c0029072:	e8 0a fa ff ff       	call   c0028a81 <list_begin>
c0029077:	89 c6                	mov    %eax,%esi
c0029079:	89 1c 24             	mov    %ebx,(%esp)
c002907c:	e8 92 fa ff ff       	call   c0028b13 <list_end>
c0029081:	39 c6                	cmp    %eax,%esi
c0029083:	0f 94 c0             	sete   %al
}
c0029086:	83 c4 14             	add    $0x14,%esp
c0029089:	5b                   	pop    %ebx
c002908a:	5e                   	pop    %esi
c002908b:	c3                   	ret    

c002908c <list_front>:
{
c002908c:	53                   	push   %ebx
c002908d:	83 ec 28             	sub    $0x28,%esp
c0029090:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c0029094:	89 1c 24             	mov    %ebx,(%esp)
c0029097:	e8 ca ff ff ff       	call   c0029066 <list_empty>
c002909c:	84 c0                	test   %al,%al
c002909e:	74 2c                	je     c00290cc <list_front+0x40>
c00290a0:	c7 44 24 10 32 fc 02 	movl   $0xc002fc32,0x10(%esp)
c00290a7:	c0 
c00290a8:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00290af:	c0 
c00290b0:	c7 44 24 08 a4 dc 02 	movl   $0xc002dca4,0x8(%esp)
c00290b7:	c0 
c00290b8:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c00290bf:	00 
c00290c0:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c00290c7:	e8 97 f8 ff ff       	call   c0028963 <debug_panic>
  return list->head.next;
c00290cc:	8b 43 04             	mov    0x4(%ebx),%eax
}
c00290cf:	83 c4 28             	add    $0x28,%esp
c00290d2:	5b                   	pop    %ebx
c00290d3:	c3                   	ret    

c00290d4 <list_pop_front>:
{
c00290d4:	53                   	push   %ebx
c00290d5:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *front = list_front (list);
c00290d8:	8b 44 24 20          	mov    0x20(%esp),%eax
c00290dc:	89 04 24             	mov    %eax,(%esp)
c00290df:	e8 a8 ff ff ff       	call   c002908c <list_front>
c00290e4:	89 c3                	mov    %eax,%ebx
  list_remove (front);
c00290e6:	89 04 24             	mov    %eax,(%esp)
c00290e9:	e8 e6 fe ff ff       	call   c0028fd4 <list_remove>
}
c00290ee:	89 d8                	mov    %ebx,%eax
c00290f0:	83 c4 18             	add    $0x18,%esp
c00290f3:	5b                   	pop    %ebx
c00290f4:	c3                   	ret    

c00290f5 <list_back>:
{
c00290f5:	53                   	push   %ebx
c00290f6:	83 ec 28             	sub    $0x28,%esp
c00290f9:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c00290fd:	89 1c 24             	mov    %ebx,(%esp)
c0029100:	e8 61 ff ff ff       	call   c0029066 <list_empty>
c0029105:	84 c0                	test   %al,%al
c0029107:	74 2c                	je     c0029135 <list_back+0x40>
c0029109:	c7 44 24 10 32 fc 02 	movl   $0xc002fc32,0x10(%esp)
c0029110:	c0 
c0029111:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029118:	c0 
c0029119:	c7 44 24 08 9a dc 02 	movl   $0xc002dc9a,0x8(%esp)
c0029120:	c0 
c0029121:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
c0029128:	00 
c0029129:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029130:	e8 2e f8 ff ff       	call   c0028963 <debug_panic>
  return list->tail.prev;
c0029135:	8b 43 08             	mov    0x8(%ebx),%eax
}
c0029138:	83 c4 28             	add    $0x28,%esp
c002913b:	5b                   	pop    %ebx
c002913c:	c3                   	ret    

c002913d <list_pop_back>:
{
c002913d:	53                   	push   %ebx
c002913e:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *back = list_back (list);
c0029141:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029145:	89 04 24             	mov    %eax,(%esp)
c0029148:	e8 a8 ff ff ff       	call   c00290f5 <list_back>
c002914d:	89 c3                	mov    %eax,%ebx
  list_remove (back);
c002914f:	89 04 24             	mov    %eax,(%esp)
c0029152:	e8 7d fe ff ff       	call   c0028fd4 <list_remove>
}
c0029157:	89 d8                	mov    %ebx,%eax
c0029159:	83 c4 18             	add    $0x18,%esp
c002915c:	5b                   	pop    %ebx
c002915d:	c3                   	ret    

c002915e <list_reverse>:
{
c002915e:	56                   	push   %esi
c002915f:	53                   	push   %ebx
c0029160:	83 ec 14             	sub    $0x14,%esp
c0029163:	8b 74 24 20          	mov    0x20(%esp),%esi
  if (!list_empty (list)) 
c0029167:	89 34 24             	mov    %esi,(%esp)
c002916a:	e8 f7 fe ff ff       	call   c0029066 <list_empty>
c002916f:	84 c0                	test   %al,%al
c0029171:	75 3a                	jne    c00291ad <list_reverse+0x4f>
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c0029173:	89 34 24             	mov    %esi,(%esp)
c0029176:	e8 06 f9 ff ff       	call   c0028a81 <list_begin>
c002917b:	89 c3                	mov    %eax,%ebx
c002917d:	eb 0c                	jmp    c002918b <list_reverse+0x2d>
  struct list_elem *t = *a;
c002917f:	8b 13                	mov    (%ebx),%edx
  *a = *b;
c0029181:	8b 43 04             	mov    0x4(%ebx),%eax
c0029184:	89 03                	mov    %eax,(%ebx)
  *b = t;
c0029186:	89 53 04             	mov    %edx,0x4(%ebx)
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c0029189:	89 c3                	mov    %eax,%ebx
c002918b:	89 34 24             	mov    %esi,(%esp)
c002918e:	e8 80 f9 ff ff       	call   c0028b13 <list_end>
c0029193:	39 d8                	cmp    %ebx,%eax
c0029195:	75 e8                	jne    c002917f <list_reverse+0x21>
  struct list_elem *t = *a;
c0029197:	8b 46 04             	mov    0x4(%esi),%eax
  *a = *b;
c002919a:	8b 56 08             	mov    0x8(%esi),%edx
c002919d:	89 56 04             	mov    %edx,0x4(%esi)
  *b = t;
c00291a0:	89 46 08             	mov    %eax,0x8(%esi)
  struct list_elem *t = *a;
c00291a3:	8b 0a                	mov    (%edx),%ecx
  *a = *b;
c00291a5:	8b 58 04             	mov    0x4(%eax),%ebx
c00291a8:	89 1a                	mov    %ebx,(%edx)
  *b = t;
c00291aa:	89 48 04             	mov    %ecx,0x4(%eax)
}
c00291ad:	83 c4 14             	add    $0x14,%esp
c00291b0:	5b                   	pop    %ebx
c00291b1:	5e                   	pop    %esi
c00291b2:	c3                   	ret    

c00291b3 <list_sort>:
/* Sorts LIST according to LESS given auxiliary data AUX, using a
   natural iterative merge sort that runs in O(n lg n) time and
   O(1) space in the number of elements in LIST. */
void
list_sort (struct list *list, list_less_func *less, void *aux)
{
c00291b3:	55                   	push   %ebp
c00291b4:	57                   	push   %edi
c00291b5:	56                   	push   %esi
c00291b6:	53                   	push   %ebx
c00291b7:	83 ec 2c             	sub    $0x2c,%esp
c00291ba:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00291be:	8b 7c 24 48          	mov    0x48(%esp),%edi
  size_t output_run_cnt;        /* Number of runs output in current pass. */

  ASSERT (list != NULL);
c00291c2:	83 7c 24 40 00       	cmpl   $0x0,0x40(%esp)
c00291c7:	75 2c                	jne    c00291f5 <list_sort+0x42>
c00291c9:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c00291d0:	c0 
c00291d1:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00291d8:	c0 
c00291d9:	c7 44 24 08 90 dc 02 	movl   $0xc002dc90,0x8(%esp)
c00291e0:	c0 
c00291e1:	c7 44 24 04 9a 01 00 	movl   $0x19a,0x4(%esp)
c00291e8:	00 
c00291e9:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c00291f0:	e8 6e f7 ff ff       	call   c0028963 <debug_panic>
  ASSERT (less != NULL);
c00291f5:	85 ed                	test   %ebp,%ebp
c00291f7:	75 2c                	jne    c0029225 <list_sort+0x72>
c00291f9:	c7 44 24 10 d7 fb 02 	movl   $0xc002fbd7,0x10(%esp)
c0029200:	c0 
c0029201:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029208:	c0 
c0029209:	c7 44 24 08 90 dc 02 	movl   $0xc002dc90,0x8(%esp)
c0029210:	c0 
c0029211:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c0029218:	00 
c0029219:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029220:	e8 3e f7 ff ff       	call   c0028963 <debug_panic>
      struct list_elem *a0;     /* Start of first run. */
      struct list_elem *a1b0;   /* End of first run, start of second. */
      struct list_elem *b1;     /* End of second run. */

      output_run_cnt = 0;
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0029225:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029229:	89 04 24             	mov    %eax,(%esp)
c002922c:	e8 50 f8 ff ff       	call   c0028a81 <list_begin>
c0029231:	89 c6                	mov    %eax,%esi
      output_run_cnt = 0;
c0029233:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002923a:	00 
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c002923b:	e9 99 01 00 00       	jmp    c00293d9 <list_sort+0x226>
        {
          /* Each iteration produces one output run. */
          output_run_cnt++;
c0029240:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)

          /* Locate two adjacent runs of nondecreasing elements
             A0...A1B0 and A1B0...B1. */
          a1b0 = find_end_of_run (a0, list_end (list), less, aux);
c0029245:	89 3c 24             	mov    %edi,(%esp)
c0029248:	89 e9                	mov    %ebp,%ecx
c002924a:	89 c2                	mov    %eax,%edx
c002924c:	89 f0                	mov    %esi,%eax
c002924e:	e8 8f f9 ff ff       	call   c0028be2 <find_end_of_run>
c0029253:	89 c3                	mov    %eax,%ebx
          if (a1b0 == list_end (list))
c0029255:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029259:	89 04 24             	mov    %eax,(%esp)
c002925c:	e8 b2 f8 ff ff       	call   c0028b13 <list_end>
c0029261:	39 d8                	cmp    %ebx,%eax
c0029263:	0f 84 84 01 00 00    	je     c00293ed <list_sort+0x23a>
            break;
          b1 = find_end_of_run (a1b0, list_end (list), less, aux);
c0029269:	89 3c 24             	mov    %edi,(%esp)
c002926c:	89 e9                	mov    %ebp,%ecx
c002926e:	89 c2                	mov    %eax,%edx
c0029270:	89 d8                	mov    %ebx,%eax
c0029272:	e8 6b f9 ff ff       	call   c0028be2 <find_end_of_run>
c0029277:	89 44 24 18          	mov    %eax,0x18(%esp)
  ASSERT (a0 != NULL);
c002927b:	85 f6                	test   %esi,%esi
c002927d:	75 2c                	jne    c00292ab <list_sort+0xf8>
c002927f:	c7 44 24 10 45 fc 02 	movl   $0xc002fc45,0x10(%esp)
c0029286:	c0 
c0029287:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002928e:	c0 
c002928f:	c7 44 24 08 72 dc 02 	movl   $0xc002dc72,0x8(%esp)
c0029296:	c0 
c0029297:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
c002929e:	00 
c002929f:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c00292a6:	e8 b8 f6 ff ff       	call   c0028963 <debug_panic>
  ASSERT (a1b0 != NULL);
c00292ab:	85 db                	test   %ebx,%ebx
c00292ad:	75 2c                	jne    c00292db <list_sort+0x128>
c00292af:	c7 44 24 10 50 fc 02 	movl   $0xc002fc50,0x10(%esp)
c00292b6:	c0 
c00292b7:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00292be:	c0 
c00292bf:	c7 44 24 08 72 dc 02 	movl   $0xc002dc72,0x8(%esp)
c00292c6:	c0 
c00292c7:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
c00292ce:	00 
c00292cf:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c00292d6:	e8 88 f6 ff ff       	call   c0028963 <debug_panic>
  ASSERT (b1 != NULL);
c00292db:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c00292e0:	75 2c                	jne    c002930e <list_sort+0x15b>
c00292e2:	c7 44 24 10 5d fc 02 	movl   $0xc002fc5d,0x10(%esp)
c00292e9:	c0 
c00292ea:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00292f1:	c0 
c00292f2:	c7 44 24 08 72 dc 02 	movl   $0xc002dc72,0x8(%esp)
c00292f9:	c0 
c00292fa:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
c0029301:	00 
c0029302:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029309:	e8 55 f6 ff ff       	call   c0028963 <debug_panic>
  ASSERT (is_sorted (a0, a1b0, less, aux));
c002930e:	89 3c 24             	mov    %edi,(%esp)
c0029311:	89 e9                	mov    %ebp,%ecx
c0029313:	89 da                	mov    %ebx,%edx
c0029315:	89 f0                	mov    %esi,%eax
c0029317:	e8 c8 f9 ff ff       	call   c0028ce4 <is_sorted>
c002931c:	84 c0                	test   %al,%al
c002931e:	75 2c                	jne    c002934c <list_sort+0x199>
c0029320:	c7 44 24 10 e4 fc 02 	movl   $0xc002fce4,0x10(%esp)
c0029327:	c0 
c0029328:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002932f:	c0 
c0029330:	c7 44 24 08 72 dc 02 	movl   $0xc002dc72,0x8(%esp)
c0029337:	c0 
c0029338:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
c002933f:	00 
c0029340:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029347:	e8 17 f6 ff ff       	call   c0028963 <debug_panic>
  ASSERT (is_sorted (a1b0, b1, less, aux));
c002934c:	89 3c 24             	mov    %edi,(%esp)
c002934f:	89 e9                	mov    %ebp,%ecx
c0029351:	8b 54 24 18          	mov    0x18(%esp),%edx
c0029355:	89 d8                	mov    %ebx,%eax
c0029357:	e8 88 f9 ff ff       	call   c0028ce4 <is_sorted>
c002935c:	84 c0                	test   %al,%al
c002935e:	75 6b                	jne    c00293cb <list_sort+0x218>
c0029360:	c7 44 24 10 04 fd 02 	movl   $0xc002fd04,0x10(%esp)
c0029367:	c0 
c0029368:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002936f:	c0 
c0029370:	c7 44 24 08 72 dc 02 	movl   $0xc002dc72,0x8(%esp)
c0029377:	c0 
c0029378:	c7 44 24 04 86 01 00 	movl   $0x186,0x4(%esp)
c002937f:	00 
c0029380:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029387:	e8 d7 f5 ff ff       	call   c0028963 <debug_panic>
    if (!less (a1b0, a0, aux)) 
c002938c:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029390:	89 74 24 04          	mov    %esi,0x4(%esp)
c0029394:	89 1c 24             	mov    %ebx,(%esp)
c0029397:	ff d5                	call   *%ebp
c0029399:	84 c0                	test   %al,%al
c002939b:	75 0c                	jne    c00293a9 <list_sort+0x1f6>
      a0 = list_next (a0);
c002939d:	89 34 24             	mov    %esi,(%esp)
c00293a0:	e8 1a f7 ff ff       	call   c0028abf <list_next>
c00293a5:	89 c6                	mov    %eax,%esi
c00293a7:	eb 22                	jmp    c00293cb <list_sort+0x218>
        a1b0 = list_next (a1b0);
c00293a9:	89 1c 24             	mov    %ebx,(%esp)
c00293ac:	e8 0e f7 ff ff       	call   c0028abf <list_next>
c00293b1:	89 c3                	mov    %eax,%ebx
        list_splice (a0, list_prev (a1b0), a1b0);
c00293b3:	89 04 24             	mov    %eax,(%esp)
c00293b6:	e8 d4 f7 ff ff       	call   c0028b8f <list_prev>
c00293bb:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00293bf:	89 44 24 04          	mov    %eax,0x4(%esp)
c00293c3:	89 34 24             	mov    %esi,(%esp)
c00293c6:	e8 bb fa ff ff       	call   c0028e86 <list_splice>
  while (a0 != a1b0 && a1b0 != b1)
c00293cb:	39 5c 24 18          	cmp    %ebx,0x18(%esp)
c00293cf:	74 04                	je     c00293d5 <list_sort+0x222>
c00293d1:	39 f3                	cmp    %esi,%ebx
c00293d3:	75 b7                	jne    c002938c <list_sort+0x1d9>
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c00293d5:	8b 74 24 18          	mov    0x18(%esp),%esi
c00293d9:	8b 44 24 40          	mov    0x40(%esp),%eax
c00293dd:	89 04 24             	mov    %eax,(%esp)
c00293e0:	e8 2e f7 ff ff       	call   c0028b13 <list_end>
c00293e5:	39 f0                	cmp    %esi,%eax
c00293e7:	0f 85 53 fe ff ff    	jne    c0029240 <list_sort+0x8d>

          /* Merge the runs. */
          inplace_merge (a0, a1b0, b1, less, aux);
        }
    }
  while (output_run_cnt > 1);
c00293ed:	83 7c 24 1c 01       	cmpl   $0x1,0x1c(%esp)
c00293f2:	0f 87 2d fe ff ff    	ja     c0029225 <list_sort+0x72>

  ASSERT (is_sorted (list_begin (list), list_end (list), less, aux));
c00293f8:	8b 44 24 40          	mov    0x40(%esp),%eax
c00293fc:	89 04 24             	mov    %eax,(%esp)
c00293ff:	e8 0f f7 ff ff       	call   c0028b13 <list_end>
c0029404:	89 c3                	mov    %eax,%ebx
c0029406:	8b 44 24 40          	mov    0x40(%esp),%eax
c002940a:	89 04 24             	mov    %eax,(%esp)
c002940d:	e8 6f f6 ff ff       	call   c0028a81 <list_begin>
c0029412:	89 3c 24             	mov    %edi,(%esp)
c0029415:	89 e9                	mov    %ebp,%ecx
c0029417:	89 da                	mov    %ebx,%edx
c0029419:	e8 c6 f8 ff ff       	call   c0028ce4 <is_sorted>
c002941e:	84 c0                	test   %al,%al
c0029420:	75 2c                	jne    c002944e <list_sort+0x29b>
c0029422:	c7 44 24 10 24 fd 02 	movl   $0xc002fd24,0x10(%esp)
c0029429:	c0 
c002942a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029431:	c0 
c0029432:	c7 44 24 08 90 dc 02 	movl   $0xc002dc90,0x8(%esp)
c0029439:	c0 
c002943a:	c7 44 24 04 b8 01 00 	movl   $0x1b8,0x4(%esp)
c0029441:	00 
c0029442:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029449:	e8 15 f5 ff ff       	call   c0028963 <debug_panic>
}
c002944e:	83 c4 2c             	add    $0x2c,%esp
c0029451:	5b                   	pop    %ebx
c0029452:	5e                   	pop    %esi
c0029453:	5f                   	pop    %edi
c0029454:	5d                   	pop    %ebp
c0029455:	c3                   	ret    

c0029456 <list_insert_ordered>:
   sorted according to LESS given auxiliary data AUX.
   Runs in O(n) average case in the number of elements in LIST. */
void
list_insert_ordered (struct list *list, struct list_elem *elem,
                     list_less_func *less, void *aux)
{
c0029456:	55                   	push   %ebp
c0029457:	57                   	push   %edi
c0029458:	56                   	push   %esi
c0029459:	53                   	push   %ebx
c002945a:	83 ec 2c             	sub    $0x2c,%esp
c002945d:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029461:	8b 7c 24 44          	mov    0x44(%esp),%edi
c0029465:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *e;

  ASSERT (list != NULL);
c0029469:	85 f6                	test   %esi,%esi
c002946b:	75 2c                	jne    c0029499 <list_insert_ordered+0x43>
c002946d:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c0029474:	c0 
c0029475:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002947c:	c0 
c002947d:	c7 44 24 08 5e dc 02 	movl   $0xc002dc5e,0x8(%esp)
c0029484:	c0 
c0029485:	c7 44 24 04 c4 01 00 	movl   $0x1c4,0x4(%esp)
c002948c:	00 
c002948d:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c0029494:	e8 ca f4 ff ff       	call   c0028963 <debug_panic>
  ASSERT (elem != NULL);
c0029499:	85 ff                	test   %edi,%edi
c002949b:	75 2c                	jne    c00294c9 <list_insert_ordered+0x73>
c002949d:	c7 44 24 10 eb fb 02 	movl   $0xc002fbeb,0x10(%esp)
c00294a4:	c0 
c00294a5:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00294ac:	c0 
c00294ad:	c7 44 24 08 5e dc 02 	movl   $0xc002dc5e,0x8(%esp)
c00294b4:	c0 
c00294b5:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
c00294bc:	00 
c00294bd:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c00294c4:	e8 9a f4 ff ff       	call   c0028963 <debug_panic>
  ASSERT (less != NULL);
c00294c9:	85 ed                	test   %ebp,%ebp
c00294cb:	75 2c                	jne    c00294f9 <list_insert_ordered+0xa3>
c00294cd:	c7 44 24 10 d7 fb 02 	movl   $0xc002fbd7,0x10(%esp)
c00294d4:	c0 
c00294d5:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00294dc:	c0 
c00294dd:	c7 44 24 08 5e dc 02 	movl   $0xc002dc5e,0x8(%esp)
c00294e4:	c0 
c00294e5:	c7 44 24 04 c6 01 00 	movl   $0x1c6,0x4(%esp)
c00294ec:	00 
c00294ed:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c00294f4:	e8 6a f4 ff ff       	call   c0028963 <debug_panic>

  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c00294f9:	89 34 24             	mov    %esi,(%esp)
c00294fc:	e8 80 f5 ff ff       	call   c0028a81 <list_begin>
c0029501:	89 c3                	mov    %eax,%ebx
c0029503:	eb 1f                	jmp    c0029524 <list_insert_ordered+0xce>
    if (less (elem, e, aux))
c0029505:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029509:	89 44 24 08          	mov    %eax,0x8(%esp)
c002950d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029511:	89 3c 24             	mov    %edi,(%esp)
c0029514:	ff d5                	call   *%ebp
c0029516:	84 c0                	test   %al,%al
c0029518:	75 16                	jne    c0029530 <list_insert_ordered+0xda>
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c002951a:	89 1c 24             	mov    %ebx,(%esp)
c002951d:	e8 9d f5 ff ff       	call   c0028abf <list_next>
c0029522:	89 c3                	mov    %eax,%ebx
c0029524:	89 34 24             	mov    %esi,(%esp)
c0029527:	e8 e7 f5 ff ff       	call   c0028b13 <list_end>
c002952c:	39 d8                	cmp    %ebx,%eax
c002952e:	75 d5                	jne    c0029505 <list_insert_ordered+0xaf>
      break;
  return list_insert (e, elem);
c0029530:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029534:	89 1c 24             	mov    %ebx,(%esp)
c0029537:	e8 b5 f8 ff ff       	call   c0028df1 <list_insert>
}
c002953c:	83 c4 2c             	add    $0x2c,%esp
c002953f:	5b                   	pop    %ebx
c0029540:	5e                   	pop    %esi
c0029541:	5f                   	pop    %edi
c0029542:	5d                   	pop    %ebp
c0029543:	c3                   	ret    

c0029544 <list_unique>:
   given auxiliary data AUX.  If DUPLICATES is non-null, then the
   elements from LIST are appended to DUPLICATES. */
void
list_unique (struct list *list, struct list *duplicates,
             list_less_func *less, void *aux)
{
c0029544:	55                   	push   %ebp
c0029545:	57                   	push   %edi
c0029546:	56                   	push   %esi
c0029547:	53                   	push   %ebx
c0029548:	83 ec 2c             	sub    $0x2c,%esp
c002954b:	8b 7c 24 40          	mov    0x40(%esp),%edi
c002954f:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *elem, *next;

  ASSERT (list != NULL);
c0029553:	85 ff                	test   %edi,%edi
c0029555:	75 2c                	jne    c0029583 <list_unique+0x3f>
c0029557:	c7 44 24 10 b2 fb 02 	movl   $0xc002fbb2,0x10(%esp)
c002955e:	c0 
c002955f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029566:	c0 
c0029567:	c7 44 24 08 52 dc 02 	movl   $0xc002dc52,0x8(%esp)
c002956e:	c0 
c002956f:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
c0029576:	00 
c0029577:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c002957e:	e8 e0 f3 ff ff       	call   c0028963 <debug_panic>
  ASSERT (less != NULL);
c0029583:	85 ed                	test   %ebp,%ebp
c0029585:	75 2c                	jne    c00295b3 <list_unique+0x6f>
c0029587:	c7 44 24 10 d7 fb 02 	movl   $0xc002fbd7,0x10(%esp)
c002958e:	c0 
c002958f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029596:	c0 
c0029597:	c7 44 24 08 52 dc 02 	movl   $0xc002dc52,0x8(%esp)
c002959e:	c0 
c002959f:	c7 44 24 04 d9 01 00 	movl   $0x1d9,0x4(%esp)
c00295a6:	00 
c00295a7:	c7 04 24 bf fb 02 c0 	movl   $0xc002fbbf,(%esp)
c00295ae:	e8 b0 f3 ff ff       	call   c0028963 <debug_panic>
  if (list_empty (list))
c00295b3:	89 3c 24             	mov    %edi,(%esp)
c00295b6:	e8 ab fa ff ff       	call   c0029066 <list_empty>
c00295bb:	84 c0                	test   %al,%al
c00295bd:	75 73                	jne    c0029632 <list_unique+0xee>
    return;

  elem = list_begin (list);
c00295bf:	89 3c 24             	mov    %edi,(%esp)
c00295c2:	e8 ba f4 ff ff       	call   c0028a81 <list_begin>
c00295c7:	89 c6                	mov    %eax,%esi
  while ((next = list_next (elem)) != list_end (list))
c00295c9:	eb 51                	jmp    c002961c <list_unique+0xd8>
    if (!less (elem, next, aux) && !less (next, elem, aux)) 
c00295cb:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c00295cf:	89 44 24 08          	mov    %eax,0x8(%esp)
c00295d3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00295d7:	89 34 24             	mov    %esi,(%esp)
c00295da:	ff d5                	call   *%ebp
c00295dc:	84 c0                	test   %al,%al
c00295de:	75 3a                	jne    c002961a <list_unique+0xd6>
c00295e0:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c00295e4:	89 44 24 08          	mov    %eax,0x8(%esp)
c00295e8:	89 74 24 04          	mov    %esi,0x4(%esp)
c00295ec:	89 1c 24             	mov    %ebx,(%esp)
c00295ef:	ff d5                	call   *%ebp
c00295f1:	84 c0                	test   %al,%al
c00295f3:	75 25                	jne    c002961a <list_unique+0xd6>
      {
        list_remove (next);
c00295f5:	89 1c 24             	mov    %ebx,(%esp)
c00295f8:	e8 d7 f9 ff ff       	call   c0028fd4 <list_remove>
        if (duplicates != NULL)
c00295fd:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c0029602:	74 14                	je     c0029618 <list_unique+0xd4>
          list_push_back (duplicates, next);
c0029604:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029608:	8b 44 24 44          	mov    0x44(%esp),%eax
c002960c:	89 04 24             	mov    %eax,(%esp)
c002960f:	e8 9d f9 ff ff       	call   c0028fb1 <list_push_back>
c0029614:	89 f3                	mov    %esi,%ebx
c0029616:	eb 02                	jmp    c002961a <list_unique+0xd6>
c0029618:	89 f3                	mov    %esi,%ebx
c002961a:	89 de                	mov    %ebx,%esi
  while ((next = list_next (elem)) != list_end (list))
c002961c:	89 34 24             	mov    %esi,(%esp)
c002961f:	e8 9b f4 ff ff       	call   c0028abf <list_next>
c0029624:	89 c3                	mov    %eax,%ebx
c0029626:	89 3c 24             	mov    %edi,(%esp)
c0029629:	e8 e5 f4 ff ff       	call   c0028b13 <list_end>
c002962e:	39 c3                	cmp    %eax,%ebx
c0029630:	75 99                	jne    c00295cb <list_unique+0x87>
      }
    else
      elem = next;
}
c0029632:	83 c4 2c             	add    $0x2c,%esp
c0029635:	5b                   	pop    %ebx
c0029636:	5e                   	pop    %esi
c0029637:	5f                   	pop    %edi
c0029638:	5d                   	pop    %ebp
c0029639:	c3                   	ret    

c002963a <list_max>:
   to LESS given auxiliary data AUX.  If there is more than one
   maximum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_max (struct list *list, list_less_func *less, void *aux)
{
c002963a:	55                   	push   %ebp
c002963b:	57                   	push   %edi
c002963c:	56                   	push   %esi
c002963d:	53                   	push   %ebx
c002963e:	83 ec 1c             	sub    $0x1c,%esp
c0029641:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0029645:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *max = list_begin (list);
c0029649:	89 3c 24             	mov    %edi,(%esp)
c002964c:	e8 30 f4 ff ff       	call   c0028a81 <list_begin>
c0029651:	89 c6                	mov    %eax,%esi
  if (max != list_end (list)) 
c0029653:	89 3c 24             	mov    %edi,(%esp)
c0029656:	e8 b8 f4 ff ff       	call   c0028b13 <list_end>
c002965b:	39 f0                	cmp    %esi,%eax
c002965d:	74 36                	je     c0029695 <list_max+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c002965f:	89 34 24             	mov    %esi,(%esp)
c0029662:	e8 58 f4 ff ff       	call   c0028abf <list_next>
c0029667:	89 c3                	mov    %eax,%ebx
c0029669:	eb 1e                	jmp    c0029689 <list_max+0x4f>
        if (less (max, e, aux))
c002966b:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002966f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029673:	89 34 24             	mov    %esi,(%esp)
c0029676:	ff 54 24 34          	call   *0x34(%esp)
c002967a:	84 c0                	test   %al,%al
          max = e; 
c002967c:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c002967f:	89 1c 24             	mov    %ebx,(%esp)
c0029682:	e8 38 f4 ff ff       	call   c0028abf <list_next>
c0029687:	89 c3                	mov    %eax,%ebx
c0029689:	89 3c 24             	mov    %edi,(%esp)
c002968c:	e8 82 f4 ff ff       	call   c0028b13 <list_end>
c0029691:	39 d8                	cmp    %ebx,%eax
c0029693:	75 d6                	jne    c002966b <list_max+0x31>
    }
  return max;
}
c0029695:	89 f0                	mov    %esi,%eax
c0029697:	83 c4 1c             	add    $0x1c,%esp
c002969a:	5b                   	pop    %ebx
c002969b:	5e                   	pop    %esi
c002969c:	5f                   	pop    %edi
c002969d:	5d                   	pop    %ebp
c002969e:	c3                   	ret    

c002969f <list_min>:
   to LESS given auxiliary data AUX.  If there is more than one
   minimum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_min (struct list *list, list_less_func *less, void *aux)
{
c002969f:	55                   	push   %ebp
c00296a0:	57                   	push   %edi
c00296a1:	56                   	push   %esi
c00296a2:	53                   	push   %ebx
c00296a3:	83 ec 1c             	sub    $0x1c,%esp
c00296a6:	8b 7c 24 30          	mov    0x30(%esp),%edi
c00296aa:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *min = list_begin (list);
c00296ae:	89 3c 24             	mov    %edi,(%esp)
c00296b1:	e8 cb f3 ff ff       	call   c0028a81 <list_begin>
c00296b6:	89 c6                	mov    %eax,%esi
  if (min != list_end (list)) 
c00296b8:	89 3c 24             	mov    %edi,(%esp)
c00296bb:	e8 53 f4 ff ff       	call   c0028b13 <list_end>
c00296c0:	39 f0                	cmp    %esi,%eax
c00296c2:	74 36                	je     c00296fa <list_min+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c00296c4:	89 34 24             	mov    %esi,(%esp)
c00296c7:	e8 f3 f3 ff ff       	call   c0028abf <list_next>
c00296cc:	89 c3                	mov    %eax,%ebx
c00296ce:	eb 1e                	jmp    c00296ee <list_min+0x4f>
        if (less (e, min, aux))
c00296d0:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00296d4:	89 74 24 04          	mov    %esi,0x4(%esp)
c00296d8:	89 1c 24             	mov    %ebx,(%esp)
c00296db:	ff 54 24 34          	call   *0x34(%esp)
c00296df:	84 c0                	test   %al,%al
          min = e; 
c00296e1:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c00296e4:	89 1c 24             	mov    %ebx,(%esp)
c00296e7:	e8 d3 f3 ff ff       	call   c0028abf <list_next>
c00296ec:	89 c3                	mov    %eax,%ebx
c00296ee:	89 3c 24             	mov    %edi,(%esp)
c00296f1:	e8 1d f4 ff ff       	call   c0028b13 <list_end>
c00296f6:	39 d8                	cmp    %ebx,%eax
c00296f8:	75 d6                	jne    c00296d0 <list_min+0x31>
    }
  return min;
}
c00296fa:	89 f0                	mov    %esi,%eax
c00296fc:	83 c4 1c             	add    $0x1c,%esp
c00296ff:	5b                   	pop    %ebx
c0029700:	5e                   	pop    %esi
c0029701:	5f                   	pop    %edi
c0029702:	5d                   	pop    %ebp
c0029703:	c3                   	ret    
c0029704:	90                   	nop
c0029705:	90                   	nop
c0029706:	90                   	nop
c0029707:	90                   	nop
c0029708:	90                   	nop
c0029709:	90                   	nop
c002970a:	90                   	nop
c002970b:	90                   	nop
c002970c:	90                   	nop
c002970d:	90                   	nop
c002970e:	90                   	nop
c002970f:	90                   	nop

c0029710 <bitmap_buf_size>:

/* Returns the number of elements required for BIT_CNT bits. */
static inline size_t
elem_cnt (size_t bit_cnt)
{
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029710:	8b 44 24 04          	mov    0x4(%esp),%eax
c0029714:	83 c0 1f             	add    $0x1f,%eax
c0029717:	c1 e8 05             	shr    $0x5,%eax
/* Returns the number of bytes required to accomodate a bitmap
   with BIT_CNT bits (for use with bitmap_create_in_buf()). */
size_t
bitmap_buf_size (size_t bit_cnt) 
{
  return sizeof (struct bitmap) + byte_cnt (bit_cnt);
c002971a:	8d 04 85 08 00 00 00 	lea    0x8(,%eax,4),%eax
}
c0029721:	c3                   	ret    

c0029722 <bitmap_destroy>:

/* Destroys bitmap B, freeing its storage.
   Not for use on bitmaps created by bitmap_create_in_buf(). */
void
bitmap_destroy (struct bitmap *b) 
{
c0029722:	53                   	push   %ebx
c0029723:	83 ec 18             	sub    $0x18,%esp
c0029726:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (b != NULL) 
c002972a:	85 db                	test   %ebx,%ebx
c002972c:	74 13                	je     c0029741 <bitmap_destroy+0x1f>
    {
      free (b->bits);
c002972e:	8b 43 04             	mov    0x4(%ebx),%eax
c0029731:	89 04 24             	mov    %eax,(%esp)
c0029734:	e8 52 a4 ff ff       	call   c0023b8b <free>
      free (b);
c0029739:	89 1c 24             	mov    %ebx,(%esp)
c002973c:	e8 4a a4 ff ff       	call   c0023b8b <free>
    }
}
c0029741:	83 c4 18             	add    $0x18,%esp
c0029744:	5b                   	pop    %ebx
c0029745:	c3                   	ret    

c0029746 <bitmap_size>:

/* Returns the number of bits in B. */
size_t
bitmap_size (const struct bitmap *b)
{
  return b->bit_cnt;
c0029746:	8b 44 24 04          	mov    0x4(%esp),%eax
c002974a:	8b 00                	mov    (%eax),%eax
}
c002974c:	c3                   	ret    

c002974d <bitmap_mark>:
}

/* Atomically sets the bit numbered BIT_IDX in B to true. */
void
bitmap_mark (struct bitmap *b, size_t bit_idx) 
{
c002974d:	53                   	push   %ebx
c002974e:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c0029752:	89 ca                	mov    %ecx,%edx
c0029754:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] |= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the OR instruction in [IA32-v2b]. */
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029757:	8b 44 24 08          	mov    0x8(%esp),%eax
c002975b:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002975e:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029763:	d3 e3                	shl    %cl,%ebx
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029765:	09 1c 90             	or     %ebx,(%eax,%edx,4)
}
c0029768:	5b                   	pop    %ebx
c0029769:	c3                   	ret    

c002976a <bitmap_reset>:

/* Atomically sets the bit numbered BIT_IDX in B to false. */
void
bitmap_reset (struct bitmap *b, size_t bit_idx) 
{
c002976a:	53                   	push   %ebx
c002976b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002976f:	89 ca                	mov    %ecx,%edx
c0029771:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] &= ~mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the AND instruction in [IA32-v2a]. */
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c0029774:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029778:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002977b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029780:	d3 e3                	shl    %cl,%ebx
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c0029782:	f7 d3                	not    %ebx
c0029784:	21 1c 90             	and    %ebx,(%eax,%edx,4)
}
c0029787:	5b                   	pop    %ebx
c0029788:	c3                   	ret    

c0029789 <bitmap_set>:
{
c0029789:	83 ec 2c             	sub    $0x2c,%esp
c002978c:	8b 44 24 30          	mov    0x30(%esp),%eax
c0029790:	8b 54 24 34          	mov    0x34(%esp),%edx
c0029794:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  ASSERT (b != NULL);
c0029798:	85 c0                	test   %eax,%eax
c002979a:	75 2c                	jne    c00297c8 <bitmap_set+0x3f>
c002979c:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c00297a3:	c0 
c00297a4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00297ab:	c0 
c00297ac:	c7 44 24 08 87 dd 02 	movl   $0xc002dd87,0x8(%esp)
c00297b3:	c0 
c00297b4:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
c00297bb:	00 
c00297bc:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c00297c3:	e8 9b f1 ff ff       	call   c0028963 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c00297c8:	39 10                	cmp    %edx,(%eax)
c00297ca:	77 2c                	ja     c00297f8 <bitmap_set+0x6f>
c00297cc:	c7 44 24 10 78 fd 02 	movl   $0xc002fd78,0x10(%esp)
c00297d3:	c0 
c00297d4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00297db:	c0 
c00297dc:	c7 44 24 08 87 dd 02 	movl   $0xc002dd87,0x8(%esp)
c00297e3:	c0 
c00297e4:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
c00297eb:	00 
c00297ec:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c00297f3:	e8 6b f1 ff ff       	call   c0028963 <debug_panic>
  if (value)
c00297f8:	84 c9                	test   %cl,%cl
c00297fa:	74 0e                	je     c002980a <bitmap_set+0x81>
    bitmap_mark (b, idx);
c00297fc:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029800:	89 04 24             	mov    %eax,(%esp)
c0029803:	e8 45 ff ff ff       	call   c002974d <bitmap_mark>
c0029808:	eb 0c                	jmp    c0029816 <bitmap_set+0x8d>
    bitmap_reset (b, idx);
c002980a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002980e:	89 04 24             	mov    %eax,(%esp)
c0029811:	e8 54 ff ff ff       	call   c002976a <bitmap_reset>
}
c0029816:	83 c4 2c             	add    $0x2c,%esp
c0029819:	c3                   	ret    

c002981a <bitmap_flip>:
/* Atomically toggles the bit numbered IDX in B;
   that is, if it is true, makes it false,
   and if it is false, makes it true. */
void
bitmap_flip (struct bitmap *b, size_t bit_idx) 
{
c002981a:	53                   	push   %ebx
c002981b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002981f:	89 ca                	mov    %ecx,%edx
c0029821:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] ^= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the XOR instruction in [IA32-v2b]. */
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029824:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029828:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002982b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029830:	d3 e3                	shl    %cl,%ebx
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029832:	31 1c 90             	xor    %ebx,(%eax,%edx,4)
}
c0029835:	5b                   	pop    %ebx
c0029836:	c3                   	ret    

c0029837 <bitmap_test>:

/* Returns the value of the bit numbered IDX in B. */
bool
bitmap_test (const struct bitmap *b, size_t idx) 
{
c0029837:	53                   	push   %ebx
c0029838:	83 ec 28             	sub    $0x28,%esp
c002983b:	8b 44 24 30          	mov    0x30(%esp),%eax
c002983f:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (b != NULL);
c0029843:	85 c0                	test   %eax,%eax
c0029845:	75 2c                	jne    c0029873 <bitmap_test+0x3c>
c0029847:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c002984e:	c0 
c002984f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029856:	c0 
c0029857:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c002985e:	c0 
c002985f:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
c0029866:	00 
c0029867:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c002986e:	e8 f0 f0 ff ff       	call   c0028963 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c0029873:	39 08                	cmp    %ecx,(%eax)
c0029875:	77 2c                	ja     c00298a3 <bitmap_test+0x6c>
c0029877:	c7 44 24 10 78 fd 02 	movl   $0xc002fd78,0x10(%esp)
c002987e:	c0 
c002987f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029886:	c0 
c0029887:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c002988e:	c0 
c002988f:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c0029896:	00 
c0029897:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c002989e:	e8 c0 f0 ff ff       	call   c0028963 <debug_panic>
  return bit_idx / ELEM_BITS;
c00298a3:	89 ca                	mov    %ecx,%edx
c00298a5:	c1 ea 05             	shr    $0x5,%edx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00298a8:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00298ab:	bb 01 00 00 00       	mov    $0x1,%ebx
c00298b0:	d3 e3                	shl    %cl,%ebx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00298b2:	85 1c 90             	test   %ebx,(%eax,%edx,4)
c00298b5:	0f 95 c0             	setne  %al
}
c00298b8:	83 c4 28             	add    $0x28,%esp
c00298bb:	5b                   	pop    %ebx
c00298bc:	c3                   	ret    

c00298bd <bitmap_set_multiple>:
}

/* Sets the CNT bits starting at START in B to VALUE. */
void
bitmap_set_multiple (struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c00298bd:	55                   	push   %ebp
c00298be:	57                   	push   %edi
c00298bf:	56                   	push   %esi
c00298c0:	53                   	push   %ebx
c00298c1:	83 ec 2c             	sub    $0x2c,%esp
c00298c4:	8b 74 24 40          	mov    0x40(%esp),%esi
c00298c8:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c00298cc:	8b 44 24 48          	mov    0x48(%esp),%eax
c00298d0:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  size_t i;
  
  ASSERT (b != NULL);
c00298d5:	85 f6                	test   %esi,%esi
c00298d7:	75 2c                	jne    c0029905 <bitmap_set_multiple+0x48>
c00298d9:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c00298e0:	c0 
c00298e1:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00298e8:	c0 
c00298e9:	c7 44 24 08 58 dd 02 	movl   $0xc002dd58,0x8(%esp)
c00298f0:	c0 
c00298f1:	c7 44 24 04 de 00 00 	movl   $0xde,0x4(%esp)
c00298f8:	00 
c00298f9:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029900:	e8 5e f0 ff ff       	call   c0028963 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029905:	8b 16                	mov    (%esi),%edx
c0029907:	39 da                	cmp    %ebx,%edx
c0029909:	73 2c                	jae    c0029937 <bitmap_set_multiple+0x7a>
c002990b:	c7 44 24 10 89 fd 02 	movl   $0xc002fd89,0x10(%esp)
c0029912:	c0 
c0029913:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002991a:	c0 
c002991b:	c7 44 24 08 58 dd 02 	movl   $0xc002dd58,0x8(%esp)
c0029922:	c0 
c0029923:	c7 44 24 04 df 00 00 	movl   $0xdf,0x4(%esp)
c002992a:	00 
c002992b:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029932:	e8 2c f0 ff ff       	call   c0028963 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029937:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c002993a:	39 fa                	cmp    %edi,%edx
c002993c:	72 09                	jb     c0029947 <bitmap_set_multiple+0x8a>

  for (i = 0; i < cnt; i++)
    bitmap_set (b, start + i, value);
c002993e:	0f b6 e9             	movzbl %cl,%ebp
  for (i = 0; i < cnt; i++)
c0029941:	85 c0                	test   %eax,%eax
c0029943:	75 2e                	jne    c0029973 <bitmap_set_multiple+0xb6>
c0029945:	eb 43                	jmp    c002998a <bitmap_set_multiple+0xcd>
  ASSERT (start + cnt <= b->bit_cnt);
c0029947:	c7 44 24 10 9d fd 02 	movl   $0xc002fd9d,0x10(%esp)
c002994e:	c0 
c002994f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029956:	c0 
c0029957:	c7 44 24 08 58 dd 02 	movl   $0xc002dd58,0x8(%esp)
c002995e:	c0 
c002995f:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c0029966:	00 
c0029967:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c002996e:	e8 f0 ef ff ff       	call   c0028963 <debug_panic>
    bitmap_set (b, start + i, value);
c0029973:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0029977:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002997b:	89 34 24             	mov    %esi,(%esp)
c002997e:	e8 06 fe ff ff       	call   c0029789 <bitmap_set>
c0029983:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029986:	39 df                	cmp    %ebx,%edi
c0029988:	75 e9                	jne    c0029973 <bitmap_set_multiple+0xb6>
}
c002998a:	83 c4 2c             	add    $0x2c,%esp
c002998d:	5b                   	pop    %ebx
c002998e:	5e                   	pop    %esi
c002998f:	5f                   	pop    %edi
c0029990:	5d                   	pop    %ebp
c0029991:	c3                   	ret    

c0029992 <bitmap_set_all>:
{
c0029992:	83 ec 2c             	sub    $0x2c,%esp
c0029995:	8b 44 24 30          	mov    0x30(%esp),%eax
c0029999:	8b 54 24 34          	mov    0x34(%esp),%edx
  ASSERT (b != NULL);
c002999d:	85 c0                	test   %eax,%eax
c002999f:	75 2c                	jne    c00299cd <bitmap_set_all+0x3b>
c00299a1:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c00299a8:	c0 
c00299a9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c00299b0:	c0 
c00299b1:	c7 44 24 08 6c dd 02 	movl   $0xc002dd6c,0x8(%esp)
c00299b8:	c0 
c00299b9:	c7 44 24 04 d3 00 00 	movl   $0xd3,0x4(%esp)
c00299c0:	00 
c00299c1:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c00299c8:	e8 96 ef ff ff       	call   c0028963 <debug_panic>
  bitmap_set_multiple (b, 0, bitmap_size (b), value);
c00299cd:	0f b6 d2             	movzbl %dl,%edx
c00299d0:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00299d4:	8b 10                	mov    (%eax),%edx
c00299d6:	89 54 24 08          	mov    %edx,0x8(%esp)
c00299da:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00299e1:	00 
c00299e2:	89 04 24             	mov    %eax,(%esp)
c00299e5:	e8 d3 fe ff ff       	call   c00298bd <bitmap_set_multiple>
}
c00299ea:	83 c4 2c             	add    $0x2c,%esp
c00299ed:	c3                   	ret    

c00299ee <bitmap_create>:
{
c00299ee:	56                   	push   %esi
c00299ef:	53                   	push   %ebx
c00299f0:	83 ec 14             	sub    $0x14,%esp
c00299f3:	8b 74 24 20          	mov    0x20(%esp),%esi
  struct bitmap *b = malloc (sizeof *b);
c00299f7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c00299fe:	e8 01 a0 ff ff       	call   c0023a04 <malloc>
c0029a03:	89 c3                	mov    %eax,%ebx
  if (b != NULL)
c0029a05:	85 c0                	test   %eax,%eax
c0029a07:	74 41                	je     c0029a4a <bitmap_create+0x5c>
      b->bit_cnt = bit_cnt;
c0029a09:	89 30                	mov    %esi,(%eax)
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029a0b:	8d 46 1f             	lea    0x1f(%esi),%eax
c0029a0e:	c1 e8 05             	shr    $0x5,%eax
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029a11:	c1 e0 02             	shl    $0x2,%eax
      b->bits = malloc (byte_cnt (bit_cnt));
c0029a14:	89 04 24             	mov    %eax,(%esp)
c0029a17:	e8 e8 9f ff ff       	call   c0023a04 <malloc>
c0029a1c:	89 43 04             	mov    %eax,0x4(%ebx)
      if (b->bits != NULL || bit_cnt == 0)
c0029a1f:	85 c0                	test   %eax,%eax
c0029a21:	75 04                	jne    c0029a27 <bitmap_create+0x39>
c0029a23:	85 f6                	test   %esi,%esi
c0029a25:	75 14                	jne    c0029a3b <bitmap_create+0x4d>
          bitmap_set_all (b, false);
c0029a27:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a2e:	00 
c0029a2f:	89 1c 24             	mov    %ebx,(%esp)
c0029a32:	e8 5b ff ff ff       	call   c0029992 <bitmap_set_all>
          return b;
c0029a37:	89 d8                	mov    %ebx,%eax
c0029a39:	eb 14                	jmp    c0029a4f <bitmap_create+0x61>
      free (b);
c0029a3b:	89 1c 24             	mov    %ebx,(%esp)
c0029a3e:	e8 48 a1 ff ff       	call   c0023b8b <free>
  return NULL;
c0029a43:	b8 00 00 00 00       	mov    $0x0,%eax
c0029a48:	eb 05                	jmp    c0029a4f <bitmap_create+0x61>
c0029a4a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029a4f:	83 c4 14             	add    $0x14,%esp
c0029a52:	5b                   	pop    %ebx
c0029a53:	5e                   	pop    %esi
c0029a54:	c3                   	ret    

c0029a55 <bitmap_create_in_buf>:
{
c0029a55:	56                   	push   %esi
c0029a56:	53                   	push   %ebx
c0029a57:	83 ec 24             	sub    $0x24,%esp
c0029a5a:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029a5e:	8b 5c 24 34          	mov    0x34(%esp),%ebx
  ASSERT (block_size >= bitmap_buf_size (bit_cnt));
c0029a62:	89 34 24             	mov    %esi,(%esp)
c0029a65:	e8 a6 fc ff ff       	call   c0029710 <bitmap_buf_size>
c0029a6a:	3b 44 24 38          	cmp    0x38(%esp),%eax
c0029a6e:	76 2c                	jbe    c0029a9c <bitmap_create_in_buf+0x47>
c0029a70:	c7 44 24 10 b8 fd 02 	movl   $0xc002fdb8,0x10(%esp)
c0029a77:	c0 
c0029a78:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029a7f:	c0 
c0029a80:	c7 44 24 08 92 dd 02 	movl   $0xc002dd92,0x8(%esp)
c0029a87:	c0 
c0029a88:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
c0029a8f:	00 
c0029a90:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029a97:	e8 c7 ee ff ff       	call   c0028963 <debug_panic>
  b->bit_cnt = bit_cnt;
c0029a9c:	89 33                	mov    %esi,(%ebx)
  b->bits = (elem_type *) (b + 1);
c0029a9e:	8d 43 08             	lea    0x8(%ebx),%eax
c0029aa1:	89 43 04             	mov    %eax,0x4(%ebx)
  bitmap_set_all (b, false);
c0029aa4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029aab:	00 
c0029aac:	89 1c 24             	mov    %ebx,(%esp)
c0029aaf:	e8 de fe ff ff       	call   c0029992 <bitmap_set_all>
}
c0029ab4:	89 d8                	mov    %ebx,%eax
c0029ab6:	83 c4 24             	add    $0x24,%esp
c0029ab9:	5b                   	pop    %ebx
c0029aba:	5e                   	pop    %esi
c0029abb:	c3                   	ret    

c0029abc <bitmap_count>:

/* Returns the number of bits in B between START and START + CNT,
   exclusive, that are set to VALUE. */
size_t
bitmap_count (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029abc:	55                   	push   %ebp
c0029abd:	57                   	push   %edi
c0029abe:	56                   	push   %esi
c0029abf:	53                   	push   %ebx
c0029ac0:	83 ec 2c             	sub    $0x2c,%esp
c0029ac3:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0029ac7:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029acb:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029acf:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
c0029ad4:	88 4c 24 1f          	mov    %cl,0x1f(%esp)
  size_t i, value_cnt;

  ASSERT (b != NULL);
c0029ad8:	85 ff                	test   %edi,%edi
c0029ada:	75 2c                	jne    c0029b08 <bitmap_count+0x4c>
c0029adc:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c0029ae3:	c0 
c0029ae4:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029aeb:	c0 
c0029aec:	c7 44 24 08 4b dd 02 	movl   $0xc002dd4b,0x8(%esp)
c0029af3:	c0 
c0029af4:	c7 44 24 04 ed 00 00 	movl   $0xed,0x4(%esp)
c0029afb:	00 
c0029afc:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029b03:	e8 5b ee ff ff       	call   c0028963 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029b08:	8b 17                	mov    (%edi),%edx
c0029b0a:	39 da                	cmp    %ebx,%edx
c0029b0c:	73 2c                	jae    c0029b3a <bitmap_count+0x7e>
c0029b0e:	c7 44 24 10 89 fd 02 	movl   $0xc002fd89,0x10(%esp)
c0029b15:	c0 
c0029b16:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029b1d:	c0 
c0029b1e:	c7 44 24 08 4b dd 02 	movl   $0xc002dd4b,0x8(%esp)
c0029b25:	c0 
c0029b26:	c7 44 24 04 ee 00 00 	movl   $0xee,0x4(%esp)
c0029b2d:	00 
c0029b2e:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029b35:	e8 29 ee ff ff       	call   c0028963 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b3a:	8d 2c 03             	lea    (%ebx,%eax,1),%ebp
c0029b3d:	39 ea                	cmp    %ebp,%edx
c0029b3f:	72 0b                	jb     c0029b4c <bitmap_count+0x90>

  value_cnt = 0;
  for (i = 0; i < cnt; i++)
c0029b41:	be 00 00 00 00       	mov    $0x0,%esi
c0029b46:	85 c0                	test   %eax,%eax
c0029b48:	75 2e                	jne    c0029b78 <bitmap_count+0xbc>
c0029b4a:	eb 4b                	jmp    c0029b97 <bitmap_count+0xdb>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b4c:	c7 44 24 10 9d fd 02 	movl   $0xc002fd9d,0x10(%esp)
c0029b53:	c0 
c0029b54:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029b5b:	c0 
c0029b5c:	c7 44 24 08 4b dd 02 	movl   $0xc002dd4b,0x8(%esp)
c0029b63:	c0 
c0029b64:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0029b6b:	00 
c0029b6c:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029b73:	e8 eb ed ff ff       	call   c0028963 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029b78:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029b7c:	89 3c 24             	mov    %edi,(%esp)
c0029b7f:	e8 b3 fc ff ff       	call   c0029837 <bitmap_test>
      value_cnt++;
c0029b84:	3a 44 24 1f          	cmp    0x1f(%esp),%al
c0029b88:	0f 94 c0             	sete   %al
c0029b8b:	0f b6 c0             	movzbl %al,%eax
c0029b8e:	01 c6                	add    %eax,%esi
c0029b90:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029b93:	39 dd                	cmp    %ebx,%ebp
c0029b95:	75 e1                	jne    c0029b78 <bitmap_count+0xbc>
  return value_cnt;
}
c0029b97:	89 f0                	mov    %esi,%eax
c0029b99:	83 c4 2c             	add    $0x2c,%esp
c0029b9c:	5b                   	pop    %ebx
c0029b9d:	5e                   	pop    %esi
c0029b9e:	5f                   	pop    %edi
c0029b9f:	5d                   	pop    %ebp
c0029ba0:	c3                   	ret    

c0029ba1 <bitmap_contains>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to VALUE, and false otherwise. */
bool
bitmap_contains (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029ba1:	55                   	push   %ebp
c0029ba2:	57                   	push   %edi
c0029ba3:	56                   	push   %esi
c0029ba4:	53                   	push   %ebx
c0029ba5:	83 ec 2c             	sub    $0x2c,%esp
c0029ba8:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029bac:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029bb0:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029bb4:	0f b6 6c 24 4c       	movzbl 0x4c(%esp),%ebp
  size_t i;
  
  ASSERT (b != NULL);
c0029bb9:	85 f6                	test   %esi,%esi
c0029bbb:	75 2c                	jne    c0029be9 <bitmap_contains+0x48>
c0029bbd:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c0029bc4:	c0 
c0029bc5:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029bcc:	c0 
c0029bcd:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0029bd4:	c0 
c0029bd5:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
c0029bdc:	00 
c0029bdd:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029be4:	e8 7a ed ff ff       	call   c0028963 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029be9:	8b 16                	mov    (%esi),%edx
c0029beb:	39 da                	cmp    %ebx,%edx
c0029bed:	73 2c                	jae    c0029c1b <bitmap_contains+0x7a>
c0029bef:	c7 44 24 10 89 fd 02 	movl   $0xc002fd89,0x10(%esp)
c0029bf6:	c0 
c0029bf7:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029bfe:	c0 
c0029bff:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0029c06:	c0 
c0029c07:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
c0029c0e:	00 
c0029c0f:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029c16:	e8 48 ed ff ff       	call   c0028963 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c1b:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c0029c1e:	39 fa                	cmp    %edi,%edx
c0029c20:	72 06                	jb     c0029c28 <bitmap_contains+0x87>

  for (i = 0; i < cnt; i++)
c0029c22:	85 c0                	test   %eax,%eax
c0029c24:	75 2e                	jne    c0029c54 <bitmap_contains+0xb3>
c0029c26:	eb 53                	jmp    c0029c7b <bitmap_contains+0xda>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c28:	c7 44 24 10 9d fd 02 	movl   $0xc002fd9d,0x10(%esp)
c0029c2f:	c0 
c0029c30:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029c37:	c0 
c0029c38:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0029c3f:	c0 
c0029c40:	c7 44 24 04 01 01 00 	movl   $0x101,0x4(%esp)
c0029c47:	00 
c0029c48:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029c4f:	e8 0f ed ff ff       	call   c0028963 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029c54:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029c58:	89 34 24             	mov    %esi,(%esp)
c0029c5b:	e8 d7 fb ff ff       	call   c0029837 <bitmap_test>
c0029c60:	89 e9                	mov    %ebp,%ecx
c0029c62:	38 c8                	cmp    %cl,%al
c0029c64:	74 09                	je     c0029c6f <bitmap_contains+0xce>
c0029c66:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029c69:	39 df                	cmp    %ebx,%edi
c0029c6b:	75 e7                	jne    c0029c54 <bitmap_contains+0xb3>
c0029c6d:	eb 07                	jmp    c0029c76 <bitmap_contains+0xd5>
      return true;
c0029c6f:	b8 01 00 00 00       	mov    $0x1,%eax
c0029c74:	eb 05                	jmp    c0029c7b <bitmap_contains+0xda>
  return false;
c0029c76:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029c7b:	83 c4 2c             	add    $0x2c,%esp
c0029c7e:	5b                   	pop    %ebx
c0029c7f:	5e                   	pop    %esi
c0029c80:	5f                   	pop    %edi
c0029c81:	5d                   	pop    %ebp
c0029c82:	c3                   	ret    

c0029c83 <bitmap_any>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_any (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029c83:	83 ec 1c             	sub    $0x1c,%esp
  return bitmap_contains (b, start, cnt, true);
c0029c86:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029c8d:	00 
c0029c8e:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029c92:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029c96:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029c9a:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029c9e:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029ca2:	89 04 24             	mov    %eax,(%esp)
c0029ca5:	e8 f7 fe ff ff       	call   c0029ba1 <bitmap_contains>
}
c0029caa:	83 c4 1c             	add    $0x1c,%esp
c0029cad:	c3                   	ret    

c0029cae <bitmap_none>:

/* Returns true if no bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_none (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cae:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, true);
c0029cb1:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029cb8:	00 
c0029cb9:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029cbd:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029cc1:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029cc5:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029cc9:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029ccd:	89 04 24             	mov    %eax,(%esp)
c0029cd0:	e8 cc fe ff ff       	call   c0029ba1 <bitmap_contains>
c0029cd5:	83 f0 01             	xor    $0x1,%eax
}
c0029cd8:	83 c4 1c             	add    $0x1c,%esp
c0029cdb:	c3                   	ret    

c0029cdc <bitmap_all>:

/* Returns true if every bit in B between START and START + CNT,
   exclusive, is set to true, and false otherwise. */
bool
bitmap_all (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cdc:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, false);
c0029cdf:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029ce6:	00 
c0029ce7:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029ceb:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029cef:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029cf3:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029cf7:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029cfb:	89 04 24             	mov    %eax,(%esp)
c0029cfe:	e8 9e fe ff ff       	call   c0029ba1 <bitmap_contains>
c0029d03:	83 f0 01             	xor    $0x1,%eax
}
c0029d06:	83 c4 1c             	add    $0x1c,%esp
c0029d09:	c3                   	ret    

c0029d0a <bitmap_scan>:
   consecutive bits in B at or after START that are all set to
   VALUE.
   If there is no such group, returns BITMAP_ERROR. */
size_t
bitmap_scan (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029d0a:	55                   	push   %ebp
c0029d0b:	57                   	push   %edi
c0029d0c:	56                   	push   %esi
c0029d0d:	53                   	push   %ebx
c0029d0e:	83 ec 2c             	sub    $0x2c,%esp
c0029d11:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029d15:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029d19:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0029d1d:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  ASSERT (b != NULL);
c0029d22:	85 f6                	test   %esi,%esi
c0029d24:	75 2c                	jne    c0029d52 <bitmap_scan+0x48>
c0029d26:	c7 44 24 10 89 f9 02 	movl   $0xc002f989,0x10(%esp)
c0029d2d:	c0 
c0029d2e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029d35:	c0 
c0029d36:	c7 44 24 08 2f dd 02 	movl   $0xc002dd2f,0x8(%esp)
c0029d3d:	c0 
c0029d3e:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0029d45:	00 
c0029d46:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029d4d:	e8 11 ec ff ff       	call   c0028963 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029d52:	8b 16                	mov    (%esi),%edx
c0029d54:	39 da                	cmp    %ebx,%edx
c0029d56:	73 2c                	jae    c0029d84 <bitmap_scan+0x7a>
c0029d58:	c7 44 24 10 89 fd 02 	movl   $0xc002fd89,0x10(%esp)
c0029d5f:	c0 
c0029d60:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029d67:	c0 
c0029d68:	c7 44 24 08 2f dd 02 	movl   $0xc002dd2f,0x8(%esp)
c0029d6f:	c0 
c0029d70:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0029d77:	00 
c0029d78:	c7 04 24 5e fd 02 c0 	movl   $0xc002fd5e,(%esp)
c0029d7f:	e8 df eb ff ff       	call   c0028963 <debug_panic>
      size_t i;
      for (i = start; i <= last; i++)
        if (!bitmap_contains (b, i, cnt, !value))
          return i; 
    }
  return BITMAP_ERROR;
c0029d84:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  if (cnt <= b->bit_cnt) 
c0029d89:	39 fa                	cmp    %edi,%edx
c0029d8b:	72 45                	jb     c0029dd2 <bitmap_scan+0xc8>
      size_t last = b->bit_cnt - cnt;
c0029d8d:	29 fa                	sub    %edi,%edx
c0029d8f:	89 54 24 1c          	mov    %edx,0x1c(%esp)
      for (i = start; i <= last; i++)
c0029d93:	39 d3                	cmp    %edx,%ebx
c0029d95:	77 2b                	ja     c0029dc2 <bitmap_scan+0xb8>
        if (!bitmap_contains (b, i, cnt, !value))
c0029d97:	83 f1 01             	xor    $0x1,%ecx
c0029d9a:	0f b6 e9             	movzbl %cl,%ebp
c0029d9d:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029da1:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029da5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029da9:	89 34 24             	mov    %esi,(%esp)
c0029dac:	e8 f0 fd ff ff       	call   c0029ba1 <bitmap_contains>
c0029db1:	84 c0                	test   %al,%al
c0029db3:	74 14                	je     c0029dc9 <bitmap_scan+0xbf>
      for (i = start; i <= last; i++)
c0029db5:	83 c3 01             	add    $0x1,%ebx
c0029db8:	39 5c 24 1c          	cmp    %ebx,0x1c(%esp)
c0029dbc:	73 df                	jae    c0029d9d <bitmap_scan+0x93>
c0029dbe:	66 90                	xchg   %ax,%ax
c0029dc0:	eb 0b                	jmp    c0029dcd <bitmap_scan+0xc3>
  return BITMAP_ERROR;
c0029dc2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0029dc7:	eb 09                	jmp    c0029dd2 <bitmap_scan+0xc8>
c0029dc9:	89 d8                	mov    %ebx,%eax
c0029dcb:	eb 05                	jmp    c0029dd2 <bitmap_scan+0xc8>
c0029dcd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0029dd2:	83 c4 2c             	add    $0x2c,%esp
c0029dd5:	5b                   	pop    %ebx
c0029dd6:	5e                   	pop    %esi
c0029dd7:	5f                   	pop    %edi
c0029dd8:	5d                   	pop    %ebp
c0029dd9:	c3                   	ret    

c0029dda <bitmap_scan_and_flip>:
   If CNT is zero, returns 0.
   Bits are set atomically, but testing bits is not atomic with
   setting them. */
size_t
bitmap_scan_and_flip (struct bitmap *b, size_t start, size_t cnt, bool value)
{
c0029dda:	55                   	push   %ebp
c0029ddb:	57                   	push   %edi
c0029ddc:	56                   	push   %esi
c0029ddd:	53                   	push   %ebx
c0029dde:	83 ec 1c             	sub    $0x1c,%esp
c0029de1:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029de5:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0029de9:	8b 6c 24 3c          	mov    0x3c(%esp),%ebp
  size_t idx = bitmap_scan (b, start, cnt, value);
c0029ded:	89 e8                	mov    %ebp,%eax
c0029def:	0f b6 c0             	movzbl %al,%eax
c0029df2:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0029df6:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029dfa:	8b 44 24 34          	mov    0x34(%esp),%eax
c0029dfe:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e02:	89 34 24             	mov    %esi,(%esp)
c0029e05:	e8 00 ff ff ff       	call   c0029d0a <bitmap_scan>
c0029e0a:	89 c3                	mov    %eax,%ebx
  if (idx != BITMAP_ERROR) 
c0029e0c:	83 f8 ff             	cmp    $0xffffffff,%eax
c0029e0f:	74 1c                	je     c0029e2d <bitmap_scan_and_flip+0x53>
    bitmap_set_multiple (b, idx, cnt, !value);
c0029e11:	89 e8                	mov    %ebp,%eax
c0029e13:	83 f0 01             	xor    $0x1,%eax
c0029e16:	0f b6 e8             	movzbl %al,%ebp
c0029e19:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029e1d:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e21:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029e25:	89 34 24             	mov    %esi,(%esp)
c0029e28:	e8 90 fa ff ff       	call   c00298bd <bitmap_set_multiple>
  return idx;
}
c0029e2d:	89 d8                	mov    %ebx,%eax
c0029e2f:	83 c4 1c             	add    $0x1c,%esp
c0029e32:	5b                   	pop    %ebx
c0029e33:	5e                   	pop    %esi
c0029e34:	5f                   	pop    %edi
c0029e35:	5d                   	pop    %ebp
c0029e36:	c3                   	ret    

c0029e37 <bitmap_dump>:
/* Debugging. */

/* Dumps the contents of B to the console as hexadecimal. */
void
bitmap_dump (const struct bitmap *b) 
{
c0029e37:	83 ec 1c             	sub    $0x1c,%esp
c0029e3a:	8b 44 24 20          	mov    0x20(%esp),%eax
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e3e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029e45:	00 
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029e46:	8b 08                	mov    (%eax),%ecx
c0029e48:	8d 51 1f             	lea    0x1f(%ecx),%edx
c0029e4b:	c1 ea 05             	shr    $0x5,%edx
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029e4e:	c1 e2 02             	shl    $0x2,%edx
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e51:	89 54 24 08          	mov    %edx,0x8(%esp)
c0029e55:	8b 40 04             	mov    0x4(%eax),%eax
c0029e58:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e5c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0029e63:	e8 d2 d3 ff ff       	call   c002723a <hex_dump>
}
c0029e68:	83 c4 1c             	add    $0x1c,%esp
c0029e6b:	c3                   	ret    
c0029e6c:	90                   	nop
c0029e6d:	90                   	nop
c0029e6e:	90                   	nop
c0029e6f:	90                   	nop

c0029e70 <find_bucket>:
}

/* Returns the bucket in H that E belongs in. */
static struct list *
find_bucket (struct hash *h, struct hash_elem *e) 
{
c0029e70:	53                   	push   %ebx
c0029e71:	83 ec 18             	sub    $0x18,%esp
c0029e74:	89 c3                	mov    %eax,%ebx
  size_t bucket_idx = h->hash (e, h->aux) & (h->bucket_cnt - 1);
c0029e76:	8b 40 14             	mov    0x14(%eax),%eax
c0029e79:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e7d:	89 14 24             	mov    %edx,(%esp)
c0029e80:	ff 53 0c             	call   *0xc(%ebx)
c0029e83:	8b 4b 04             	mov    0x4(%ebx),%ecx
c0029e86:	8d 51 ff             	lea    -0x1(%ecx),%edx
c0029e89:	21 d0                	and    %edx,%eax
  return &h->buckets[bucket_idx];
c0029e8b:	c1 e0 04             	shl    $0x4,%eax
c0029e8e:	03 43 08             	add    0x8(%ebx),%eax
}
c0029e91:	83 c4 18             	add    $0x18,%esp
c0029e94:	5b                   	pop    %ebx
c0029e95:	c3                   	ret    

c0029e96 <find_elem>:

/* Searches BUCKET in H for a hash element equal to E.  Returns
   it if found or a null pointer otherwise. */
static struct hash_elem *
find_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
c0029e96:	55                   	push   %ebp
c0029e97:	57                   	push   %edi
c0029e98:	56                   	push   %esi
c0029e99:	53                   	push   %ebx
c0029e9a:	83 ec 1c             	sub    $0x1c,%esp
c0029e9d:	89 c6                	mov    %eax,%esi
c0029e9f:	89 d5                	mov    %edx,%ebp
c0029ea1:	89 cf                	mov    %ecx,%edi
  struct list_elem *i;

  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029ea3:	89 14 24             	mov    %edx,(%esp)
c0029ea6:	e8 d6 eb ff ff       	call   c0028a81 <list_begin>
c0029eab:	89 c3                	mov    %eax,%ebx
c0029ead:	eb 34                	jmp    c0029ee3 <find_elem+0x4d>
    {
      struct hash_elem *hi = list_elem_to_hash_elem (i);
      if (!h->less (hi, e, h->aux) && !h->less (e, hi, h->aux))
c0029eaf:	8b 46 14             	mov    0x14(%esi),%eax
c0029eb2:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029eb6:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029eba:	89 1c 24             	mov    %ebx,(%esp)
c0029ebd:	ff 56 10             	call   *0x10(%esi)
c0029ec0:	84 c0                	test   %al,%al
c0029ec2:	75 15                	jne    c0029ed9 <find_elem+0x43>
c0029ec4:	8b 46 14             	mov    0x14(%esi),%eax
c0029ec7:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029ecb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029ecf:	89 3c 24             	mov    %edi,(%esp)
c0029ed2:	ff 56 10             	call   *0x10(%esi)
c0029ed5:	84 c0                	test   %al,%al
c0029ed7:	74 1d                	je     c0029ef6 <find_elem+0x60>
  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029ed9:	89 1c 24             	mov    %ebx,(%esp)
c0029edc:	e8 de eb ff ff       	call   c0028abf <list_next>
c0029ee1:	89 c3                	mov    %eax,%ebx
c0029ee3:	89 2c 24             	mov    %ebp,(%esp)
c0029ee6:	e8 28 ec ff ff       	call   c0028b13 <list_end>
c0029eeb:	39 d8                	cmp    %ebx,%eax
c0029eed:	75 c0                	jne    c0029eaf <find_elem+0x19>
        return hi; 
    }
  return NULL;
c0029eef:	b8 00 00 00 00       	mov    $0x0,%eax
c0029ef4:	eb 02                	jmp    c0029ef8 <find_elem+0x62>
c0029ef6:	89 d8                	mov    %ebx,%eax
}
c0029ef8:	83 c4 1c             	add    $0x1c,%esp
c0029efb:	5b                   	pop    %ebx
c0029efc:	5e                   	pop    %esi
c0029efd:	5f                   	pop    %edi
c0029efe:	5d                   	pop    %ebp
c0029eff:	c3                   	ret    

c0029f00 <rehash>:
   ideal.  This function can fail because of an out-of-memory
   condition, but that'll just make hash accesses less efficient;
   we can still continue. */
static void
rehash (struct hash *h) 
{
c0029f00:	55                   	push   %ebp
c0029f01:	57                   	push   %edi
c0029f02:	56                   	push   %esi
c0029f03:	53                   	push   %ebx
c0029f04:	83 ec 3c             	sub    $0x3c,%esp
c0029f07:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  size_t old_bucket_cnt, new_bucket_cnt;
  struct list *new_buckets, *old_buckets;
  size_t i;

  ASSERT (h != NULL);
c0029f0b:	85 c0                	test   %eax,%eax
c0029f0d:	75 2c                	jne    c0029f3b <rehash+0x3b>
c0029f0f:	c7 44 24 10 e0 fd 02 	movl   $0xc002fde0,0x10(%esp)
c0029f16:	c0 
c0029f17:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c0029f1e:	c0 
c0029f1f:	c7 44 24 08 de dd 02 	movl   $0xc002ddde,0x8(%esp)
c0029f26:	c0 
c0029f27:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0029f2e:	00 
c0029f2f:	c7 04 24 ea fd 02 c0 	movl   $0xc002fdea,(%esp)
c0029f36:	e8 28 ea ff ff       	call   c0028963 <debug_panic>

  /* Save old bucket info for later use. */
  old_buckets = h->buckets;
c0029f3b:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029f3f:	8b 48 08             	mov    0x8(%eax),%ecx
c0029f42:	89 4c 24 2c          	mov    %ecx,0x2c(%esp)
  old_bucket_cnt = h->bucket_cnt;
c0029f46:	8b 48 04             	mov    0x4(%eax),%ecx
c0029f49:	89 4c 24 28          	mov    %ecx,0x28(%esp)

  /* Calculate the number of buckets to use now.
     We want one bucket for about every BEST_ELEMS_PER_BUCKET.
     We must have at least four buckets, and the number of
     buckets must be a power of 2. */
  new_bucket_cnt = h->elem_cnt / BEST_ELEMS_PER_BUCKET;
c0029f4d:	8b 00                	mov    (%eax),%eax
c0029f4f:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029f53:	89 c3                	mov    %eax,%ebx
c0029f55:	d1 eb                	shr    %ebx
  if (new_bucket_cnt < 4)
    new_bucket_cnt = 4;
c0029f57:	83 fb 03             	cmp    $0x3,%ebx
c0029f5a:	b8 04 00 00 00       	mov    $0x4,%eax
c0029f5f:	0f 46 d8             	cmovbe %eax,%ebx
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029f62:	85 db                	test   %ebx,%ebx
c0029f64:	0f 84 d2 00 00 00    	je     c002a03c <rehash+0x13c>
  return x & (x - 1);
c0029f6a:	8d 43 ff             	lea    -0x1(%ebx),%eax
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029f6d:	85 d8                	test   %ebx,%eax
c0029f6f:	0f 85 c7 00 00 00    	jne    c002a03c <rehash+0x13c>
c0029f75:	e9 cc 00 00 00       	jmp    c002a046 <rehash+0x146>
  /* Don't do anything if the bucket count wouldn't change. */
  if (new_bucket_cnt == old_bucket_cnt)
    return;

  /* Allocate new buckets and initialize them as empty. */
  new_buckets = malloc (sizeof *new_buckets * new_bucket_cnt);
c0029f7a:	89 d8                	mov    %ebx,%eax
c0029f7c:	c1 e0 04             	shl    $0x4,%eax
c0029f7f:	89 04 24             	mov    %eax,(%esp)
c0029f82:	e8 7d 9a ff ff       	call   c0023a04 <malloc>
c0029f87:	89 c5                	mov    %eax,%ebp
  if (new_buckets == NULL) 
c0029f89:	85 c0                	test   %eax,%eax
c0029f8b:	0f 84 bf 00 00 00    	je     c002a050 <rehash+0x150>
      /* Allocation failed.  This means that use of the hash table will
         be less efficient.  However, it is still usable, so
         there's no reason for it to be an error. */
      return;
    }
  for (i = 0; i < new_bucket_cnt; i++) 
c0029f91:	85 db                	test   %ebx,%ebx
c0029f93:	74 19                	je     c0029fae <rehash+0xae>
c0029f95:	89 c7                	mov    %eax,%edi
c0029f97:	be 00 00 00 00       	mov    $0x0,%esi
    list_init (&new_buckets[i]);
c0029f9c:	89 3c 24             	mov    %edi,(%esp)
c0029f9f:	e8 8c ea ff ff       	call   c0028a30 <list_init>
  for (i = 0; i < new_bucket_cnt; i++) 
c0029fa4:	83 c6 01             	add    $0x1,%esi
c0029fa7:	83 c7 10             	add    $0x10,%edi
c0029faa:	39 de                	cmp    %ebx,%esi
c0029fac:	75 ee                	jne    c0029f9c <rehash+0x9c>

  /* Install new bucket info. */
  h->buckets = new_buckets;
c0029fae:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029fb2:	89 68 08             	mov    %ebp,0x8(%eax)
  h->bucket_cnt = new_bucket_cnt;
c0029fb5:	89 58 04             	mov    %ebx,0x4(%eax)

  /* Move each old element into the appropriate new bucket. */
  for (i = 0; i < old_bucket_cnt; i++) 
c0029fb8:	83 7c 24 28 00       	cmpl   $0x0,0x28(%esp)
c0029fbd:	74 6f                	je     c002a02e <rehash+0x12e>
c0029fbf:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c0029fc3:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029fc7:	c7 44 24 24 00 00 00 	movl   $0x0,0x24(%esp)
c0029fce:	00 
    {
      struct list *old_bucket;
      struct list_elem *elem, *next;

      old_bucket = &old_buckets[i];
c0029fcf:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029fd3:	89 c5                	mov    %eax,%ebp
      for (elem = list_begin (old_bucket);
c0029fd5:	89 04 24             	mov    %eax,(%esp)
c0029fd8:	e8 a4 ea ff ff       	call   c0028a81 <list_begin>
c0029fdd:	89 c3                	mov    %eax,%ebx
c0029fdf:	eb 2d                	jmp    c002a00e <rehash+0x10e>
           elem != list_end (old_bucket); elem = next) 
        {
          struct list *new_bucket
c0029fe1:	89 da                	mov    %ebx,%edx
c0029fe3:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029fe7:	e8 84 fe ff ff       	call   c0029e70 <find_bucket>
c0029fec:	89 c7                	mov    %eax,%edi
            = find_bucket (h, list_elem_to_hash_elem (elem));
          next = list_next (elem);
c0029fee:	89 1c 24             	mov    %ebx,(%esp)
c0029ff1:	e8 c9 ea ff ff       	call   c0028abf <list_next>
c0029ff6:	89 c6                	mov    %eax,%esi
          list_remove (elem);
c0029ff8:	89 1c 24             	mov    %ebx,(%esp)
c0029ffb:	e8 d4 ef ff ff       	call   c0028fd4 <list_remove>
          list_push_front (new_bucket, elem);
c002a000:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002a004:	89 3c 24             	mov    %edi,(%esp)
c002a007:	e8 82 ef ff ff       	call   c0028f8e <list_push_front>
           elem != list_end (old_bucket); elem = next) 
c002a00c:	89 f3                	mov    %esi,%ebx
c002a00e:	89 2c 24             	mov    %ebp,(%esp)
c002a011:	e8 fd ea ff ff       	call   c0028b13 <list_end>
      for (elem = list_begin (old_bucket);
c002a016:	39 d8                	cmp    %ebx,%eax
c002a018:	75 c7                	jne    c0029fe1 <rehash+0xe1>
  for (i = 0; i < old_bucket_cnt; i++) 
c002a01a:	83 44 24 24 01       	addl   $0x1,0x24(%esp)
c002a01f:	83 44 24 20 10       	addl   $0x10,0x20(%esp)
c002a024:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a028:	39 44 24 24          	cmp    %eax,0x24(%esp)
c002a02c:	75 a1                	jne    c0029fcf <rehash+0xcf>
        }
    }

  free (old_buckets);
c002a02e:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a032:	89 04 24             	mov    %eax,(%esp)
c002a035:	e8 51 9b ff ff       	call   c0023b8b <free>
c002a03a:	eb 14                	jmp    c002a050 <rehash+0x150>
  return x & (x - 1);
c002a03c:	8d 43 ff             	lea    -0x1(%ebx),%eax
c002a03f:	21 c3                	and    %eax,%ebx
c002a041:	e9 1c ff ff ff       	jmp    c0029f62 <rehash+0x62>
  if (new_bucket_cnt == old_bucket_cnt)
c002a046:	3b 5c 24 28          	cmp    0x28(%esp),%ebx
c002a04a:	0f 85 2a ff ff ff    	jne    c0029f7a <rehash+0x7a>
}
c002a050:	83 c4 3c             	add    $0x3c,%esp
c002a053:	5b                   	pop    %ebx
c002a054:	5e                   	pop    %esi
c002a055:	5f                   	pop    %edi
c002a056:	5d                   	pop    %ebp
c002a057:	c3                   	ret    

c002a058 <hash_clear>:
{
c002a058:	55                   	push   %ebp
c002a059:	57                   	push   %edi
c002a05a:	56                   	push   %esi
c002a05b:	53                   	push   %ebx
c002a05c:	83 ec 1c             	sub    $0x1c,%esp
c002a05f:	8b 74 24 30          	mov    0x30(%esp),%esi
c002a063:	8b 7c 24 34          	mov    0x34(%esp),%edi
  for (i = 0; i < h->bucket_cnt; i++) 
c002a067:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c002a06b:	74 43                	je     c002a0b0 <hash_clear+0x58>
c002a06d:	bd 00 00 00 00       	mov    $0x0,%ebp
c002a072:	89 eb                	mov    %ebp,%ebx
c002a074:	c1 e3 04             	shl    $0x4,%ebx
      struct list *bucket = &h->buckets[i];
c002a077:	03 5e 08             	add    0x8(%esi),%ebx
      if (destructor != NULL) 
c002a07a:	85 ff                	test   %edi,%edi
c002a07c:	75 16                	jne    c002a094 <hash_clear+0x3c>
c002a07e:	eb 20                	jmp    c002a0a0 <hash_clear+0x48>
            struct list_elem *list_elem = list_pop_front (bucket);
c002a080:	89 1c 24             	mov    %ebx,(%esp)
c002a083:	e8 4c f0 ff ff       	call   c00290d4 <list_pop_front>
            destructor (hash_elem, h->aux);
c002a088:	8b 56 14             	mov    0x14(%esi),%edx
c002a08b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002a08f:	89 04 24             	mov    %eax,(%esp)
c002a092:	ff d7                	call   *%edi
        while (!list_empty (bucket)) 
c002a094:	89 1c 24             	mov    %ebx,(%esp)
c002a097:	e8 ca ef ff ff       	call   c0029066 <list_empty>
c002a09c:	84 c0                	test   %al,%al
c002a09e:	74 e0                	je     c002a080 <hash_clear+0x28>
      list_init (bucket); 
c002a0a0:	89 1c 24             	mov    %ebx,(%esp)
c002a0a3:	e8 88 e9 ff ff       	call   c0028a30 <list_init>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a0a8:	83 c5 01             	add    $0x1,%ebp
c002a0ab:	39 6e 04             	cmp    %ebp,0x4(%esi)
c002a0ae:	77 c2                	ja     c002a072 <hash_clear+0x1a>
  h->elem_cnt = 0;
c002a0b0:	c7 06 00 00 00 00    	movl   $0x0,(%esi)
}
c002a0b6:	83 c4 1c             	add    $0x1c,%esp
c002a0b9:	5b                   	pop    %ebx
c002a0ba:	5e                   	pop    %esi
c002a0bb:	5f                   	pop    %edi
c002a0bc:	5d                   	pop    %ebp
c002a0bd:	c3                   	ret    

c002a0be <hash_init>:
{
c002a0be:	53                   	push   %ebx
c002a0bf:	83 ec 18             	sub    $0x18,%esp
c002a0c2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  h->elem_cnt = 0;
c002a0c6:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  h->bucket_cnt = 4;
c002a0cc:	c7 43 04 04 00 00 00 	movl   $0x4,0x4(%ebx)
  h->buckets = malloc (sizeof *h->buckets * h->bucket_cnt);
c002a0d3:	c7 04 24 40 00 00 00 	movl   $0x40,(%esp)
c002a0da:	e8 25 99 ff ff       	call   c0023a04 <malloc>
c002a0df:	89 c2                	mov    %eax,%edx
c002a0e1:	89 43 08             	mov    %eax,0x8(%ebx)
  h->hash = hash;
c002a0e4:	8b 44 24 24          	mov    0x24(%esp),%eax
c002a0e8:	89 43 0c             	mov    %eax,0xc(%ebx)
  h->less = less;
c002a0eb:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a0ef:	89 43 10             	mov    %eax,0x10(%ebx)
  h->aux = aux;
c002a0f2:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a0f6:	89 43 14             	mov    %eax,0x14(%ebx)
    return false;
c002a0f9:	b8 00 00 00 00       	mov    $0x0,%eax
  if (h->buckets != NULL) 
c002a0fe:	85 d2                	test   %edx,%edx
c002a100:	74 15                	je     c002a117 <hash_init+0x59>
      hash_clear (h, NULL);
c002a102:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002a109:	00 
c002a10a:	89 1c 24             	mov    %ebx,(%esp)
c002a10d:	e8 46 ff ff ff       	call   c002a058 <hash_clear>
      return true;
c002a112:	b8 01 00 00 00       	mov    $0x1,%eax
}
c002a117:	83 c4 18             	add    $0x18,%esp
c002a11a:	5b                   	pop    %ebx
c002a11b:	c3                   	ret    

c002a11c <hash_destroy>:
{
c002a11c:	53                   	push   %ebx
c002a11d:	83 ec 18             	sub    $0x18,%esp
c002a120:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a124:	8b 44 24 24          	mov    0x24(%esp),%eax
  if (destructor != NULL)
c002a128:	85 c0                	test   %eax,%eax
c002a12a:	74 0c                	je     c002a138 <hash_destroy+0x1c>
    hash_clear (h, destructor);
c002a12c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a130:	89 1c 24             	mov    %ebx,(%esp)
c002a133:	e8 20 ff ff ff       	call   c002a058 <hash_clear>
  free (h->buckets);
c002a138:	8b 43 08             	mov    0x8(%ebx),%eax
c002a13b:	89 04 24             	mov    %eax,(%esp)
c002a13e:	e8 48 9a ff ff       	call   c0023b8b <free>
}
c002a143:	83 c4 18             	add    $0x18,%esp
c002a146:	5b                   	pop    %ebx
c002a147:	c3                   	ret    

c002a148 <hash_insert>:
{
c002a148:	55                   	push   %ebp
c002a149:	57                   	push   %edi
c002a14a:	56                   	push   %esi
c002a14b:	53                   	push   %ebx
c002a14c:	83 ec 1c             	sub    $0x1c,%esp
c002a14f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a153:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a157:	89 f2                	mov    %esi,%edx
c002a159:	89 d8                	mov    %ebx,%eax
c002a15b:	e8 10 fd ff ff       	call   c0029e70 <find_bucket>
c002a160:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a162:	89 f1                	mov    %esi,%ecx
c002a164:	89 c2                	mov    %eax,%edx
c002a166:	89 d8                	mov    %ebx,%eax
c002a168:	e8 29 fd ff ff       	call   c0029e96 <find_elem>
c002a16d:	89 c7                	mov    %eax,%edi
  if (old == NULL) 
c002a16f:	85 c0                	test   %eax,%eax
c002a171:	75 0f                	jne    c002a182 <hash_insert+0x3a>

/* Inserts E into BUCKET (in hash table H). */
static void
insert_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
  h->elem_cnt++;
c002a173:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a176:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a17a:	89 2c 24             	mov    %ebp,(%esp)
c002a17d:	e8 0c ee ff ff       	call   c0028f8e <list_push_front>
  rehash (h);
c002a182:	89 d8                	mov    %ebx,%eax
c002a184:	e8 77 fd ff ff       	call   c0029f00 <rehash>
}
c002a189:	89 f8                	mov    %edi,%eax
c002a18b:	83 c4 1c             	add    $0x1c,%esp
c002a18e:	5b                   	pop    %ebx
c002a18f:	5e                   	pop    %esi
c002a190:	5f                   	pop    %edi
c002a191:	5d                   	pop    %ebp
c002a192:	c3                   	ret    

c002a193 <hash_replace>:
{
c002a193:	55                   	push   %ebp
c002a194:	57                   	push   %edi
c002a195:	56                   	push   %esi
c002a196:	53                   	push   %ebx
c002a197:	83 ec 1c             	sub    $0x1c,%esp
c002a19a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a19e:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a1a2:	89 f2                	mov    %esi,%edx
c002a1a4:	89 d8                	mov    %ebx,%eax
c002a1a6:	e8 c5 fc ff ff       	call   c0029e70 <find_bucket>
c002a1ab:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a1ad:	89 f1                	mov    %esi,%ecx
c002a1af:	89 c2                	mov    %eax,%edx
c002a1b1:	89 d8                	mov    %ebx,%eax
c002a1b3:	e8 de fc ff ff       	call   c0029e96 <find_elem>
c002a1b8:	89 c7                	mov    %eax,%edi
  if (old != NULL)
c002a1ba:	85 c0                	test   %eax,%eax
c002a1bc:	74 0b                	je     c002a1c9 <hash_replace+0x36>

/* Removes E from hash table H. */
static void
remove_elem (struct hash *h, struct hash_elem *e) 
{
  h->elem_cnt--;
c002a1be:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a1c1:	89 04 24             	mov    %eax,(%esp)
c002a1c4:	e8 0b ee ff ff       	call   c0028fd4 <list_remove>
  h->elem_cnt++;
c002a1c9:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a1cc:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a1d0:	89 2c 24             	mov    %ebp,(%esp)
c002a1d3:	e8 b6 ed ff ff       	call   c0028f8e <list_push_front>
  rehash (h);
c002a1d8:	89 d8                	mov    %ebx,%eax
c002a1da:	e8 21 fd ff ff       	call   c0029f00 <rehash>
}
c002a1df:	89 f8                	mov    %edi,%eax
c002a1e1:	83 c4 1c             	add    $0x1c,%esp
c002a1e4:	5b                   	pop    %ebx
c002a1e5:	5e                   	pop    %esi
c002a1e6:	5f                   	pop    %edi
c002a1e7:	5d                   	pop    %ebp
c002a1e8:	c3                   	ret    

c002a1e9 <hash_find>:
{
c002a1e9:	56                   	push   %esi
c002a1ea:	53                   	push   %ebx
c002a1eb:	83 ec 04             	sub    $0x4,%esp
c002a1ee:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a1f2:	8b 74 24 14          	mov    0x14(%esp),%esi
  return find_elem (h, find_bucket (h, e), e);
c002a1f6:	89 f2                	mov    %esi,%edx
c002a1f8:	89 d8                	mov    %ebx,%eax
c002a1fa:	e8 71 fc ff ff       	call   c0029e70 <find_bucket>
c002a1ff:	89 f1                	mov    %esi,%ecx
c002a201:	89 c2                	mov    %eax,%edx
c002a203:	89 d8                	mov    %ebx,%eax
c002a205:	e8 8c fc ff ff       	call   c0029e96 <find_elem>
}
c002a20a:	83 c4 04             	add    $0x4,%esp
c002a20d:	5b                   	pop    %ebx
c002a20e:	5e                   	pop    %esi
c002a20f:	c3                   	ret    

c002a210 <hash_delete>:
{
c002a210:	56                   	push   %esi
c002a211:	53                   	push   %ebx
c002a212:	83 ec 14             	sub    $0x14,%esp
c002a215:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a219:	8b 74 24 24          	mov    0x24(%esp),%esi
  struct hash_elem *found = find_elem (h, find_bucket (h, e), e);
c002a21d:	89 f2                	mov    %esi,%edx
c002a21f:	89 d8                	mov    %ebx,%eax
c002a221:	e8 4a fc ff ff       	call   c0029e70 <find_bucket>
c002a226:	89 f1                	mov    %esi,%ecx
c002a228:	89 c2                	mov    %eax,%edx
c002a22a:	89 d8                	mov    %ebx,%eax
c002a22c:	e8 65 fc ff ff       	call   c0029e96 <find_elem>
c002a231:	89 c6                	mov    %eax,%esi
  if (found != NULL) 
c002a233:	85 c0                	test   %eax,%eax
c002a235:	74 12                	je     c002a249 <hash_delete+0x39>
  h->elem_cnt--;
c002a237:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a23a:	89 04 24             	mov    %eax,(%esp)
c002a23d:	e8 92 ed ff ff       	call   c0028fd4 <list_remove>
      rehash (h); 
c002a242:	89 d8                	mov    %ebx,%eax
c002a244:	e8 b7 fc ff ff       	call   c0029f00 <rehash>
}
c002a249:	89 f0                	mov    %esi,%eax
c002a24b:	83 c4 14             	add    $0x14,%esp
c002a24e:	5b                   	pop    %ebx
c002a24f:	5e                   	pop    %esi
c002a250:	c3                   	ret    

c002a251 <hash_apply>:
{
c002a251:	55                   	push   %ebp
c002a252:	57                   	push   %edi
c002a253:	56                   	push   %esi
c002a254:	53                   	push   %ebx
c002a255:	83 ec 2c             	sub    $0x2c,%esp
c002a258:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (action != NULL);
c002a25c:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c002a261:	74 10                	je     c002a273 <hash_apply+0x22>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a263:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a26a:	00 
c002a26b:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c002a26f:	75 2e                	jne    c002a29f <hash_apply+0x4e>
c002a271:	eb 76                	jmp    c002a2e9 <hash_apply+0x98>
  ASSERT (action != NULL);
c002a273:	c7 44 24 10 02 fe 02 	movl   $0xc002fe02,0x10(%esp)
c002a27a:	c0 
c002a27b:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a282:	c0 
c002a283:	c7 44 24 08 d3 dd 02 	movl   $0xc002ddd3,0x8(%esp)
c002a28a:	c0 
c002a28b:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
c002a292:	00 
c002a293:	c7 04 24 ea fd 02 c0 	movl   $0xc002fdea,(%esp)
c002a29a:	e8 c4 e6 ff ff       	call   c0028963 <debug_panic>
c002a29f:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
c002a2a3:	c1 e7 04             	shl    $0x4,%edi
      struct list *bucket = &h->buckets[i];
c002a2a6:	03 7d 08             	add    0x8(%ebp),%edi
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a2a9:	89 3c 24             	mov    %edi,(%esp)
c002a2ac:	e8 d0 e7 ff ff       	call   c0028a81 <list_begin>
c002a2b1:	89 c3                	mov    %eax,%ebx
c002a2b3:	eb 1a                	jmp    c002a2cf <hash_apply+0x7e>
          next = list_next (elem);
c002a2b5:	89 1c 24             	mov    %ebx,(%esp)
c002a2b8:	e8 02 e8 ff ff       	call   c0028abf <list_next>
c002a2bd:	89 c6                	mov    %eax,%esi
          action (list_elem_to_hash_elem (elem), h->aux);
c002a2bf:	8b 45 14             	mov    0x14(%ebp),%eax
c002a2c2:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a2c6:	89 1c 24             	mov    %ebx,(%esp)
c002a2c9:	ff 54 24 44          	call   *0x44(%esp)
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a2cd:	89 f3                	mov    %esi,%ebx
c002a2cf:	89 3c 24             	mov    %edi,(%esp)
c002a2d2:	e8 3c e8 ff ff       	call   c0028b13 <list_end>
c002a2d7:	39 d8                	cmp    %ebx,%eax
c002a2d9:	75 da                	jne    c002a2b5 <hash_apply+0x64>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a2db:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)
c002a2e0:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a2e4:	39 45 04             	cmp    %eax,0x4(%ebp)
c002a2e7:	77 b6                	ja     c002a29f <hash_apply+0x4e>
}
c002a2e9:	83 c4 2c             	add    $0x2c,%esp
c002a2ec:	5b                   	pop    %ebx
c002a2ed:	5e                   	pop    %esi
c002a2ee:	5f                   	pop    %edi
c002a2ef:	5d                   	pop    %ebp
c002a2f0:	c3                   	ret    

c002a2f1 <hash_first>:
{
c002a2f1:	53                   	push   %ebx
c002a2f2:	83 ec 28             	sub    $0x28,%esp
c002a2f5:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a2f9:	8b 44 24 34          	mov    0x34(%esp),%eax
  ASSERT (i != NULL);
c002a2fd:	85 db                	test   %ebx,%ebx
c002a2ff:	75 2c                	jne    c002a32d <hash_first+0x3c>
c002a301:	c7 44 24 10 11 fe 02 	movl   $0xc002fe11,0x10(%esp)
c002a308:	c0 
c002a309:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a310:	c0 
c002a311:	c7 44 24 08 c8 dd 02 	movl   $0xc002ddc8,0x8(%esp)
c002a318:	c0 
c002a319:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
c002a320:	00 
c002a321:	c7 04 24 ea fd 02 c0 	movl   $0xc002fdea,(%esp)
c002a328:	e8 36 e6 ff ff       	call   c0028963 <debug_panic>
  ASSERT (h != NULL);
c002a32d:	85 c0                	test   %eax,%eax
c002a32f:	75 2c                	jne    c002a35d <hash_first+0x6c>
c002a331:	c7 44 24 10 e0 fd 02 	movl   $0xc002fde0,0x10(%esp)
c002a338:	c0 
c002a339:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a340:	c0 
c002a341:	c7 44 24 08 c8 dd 02 	movl   $0xc002ddc8,0x8(%esp)
c002a348:	c0 
c002a349:	c7 44 24 04 cb 00 00 	movl   $0xcb,0x4(%esp)
c002a350:	00 
c002a351:	c7 04 24 ea fd 02 c0 	movl   $0xc002fdea,(%esp)
c002a358:	e8 06 e6 ff ff       	call   c0028963 <debug_panic>
  i->hash = h;
c002a35d:	89 03                	mov    %eax,(%ebx)
  i->bucket = i->hash->buckets;
c002a35f:	8b 40 08             	mov    0x8(%eax),%eax
c002a362:	89 43 04             	mov    %eax,0x4(%ebx)
  i->elem = list_elem_to_hash_elem (list_head (i->bucket));
c002a365:	89 04 24             	mov    %eax,(%esp)
c002a368:	e8 0b ea ff ff       	call   c0028d78 <list_head>
c002a36d:	89 43 08             	mov    %eax,0x8(%ebx)
}
c002a370:	83 c4 28             	add    $0x28,%esp
c002a373:	5b                   	pop    %ebx
c002a374:	c3                   	ret    

c002a375 <hash_next>:
{
c002a375:	56                   	push   %esi
c002a376:	53                   	push   %ebx
c002a377:	83 ec 24             	sub    $0x24,%esp
c002a37a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (i != NULL);
c002a37e:	85 db                	test   %ebx,%ebx
c002a380:	75 2c                	jne    c002a3ae <hash_next+0x39>
c002a382:	c7 44 24 10 11 fe 02 	movl   $0xc002fe11,0x10(%esp)
c002a389:	c0 
c002a38a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a391:	c0 
c002a392:	c7 44 24 08 be dd 02 	movl   $0xc002ddbe,0x8(%esp)
c002a399:	c0 
c002a39a:	c7 44 24 04 dd 00 00 	movl   $0xdd,0x4(%esp)
c002a3a1:	00 
c002a3a2:	c7 04 24 ea fd 02 c0 	movl   $0xc002fdea,(%esp)
c002a3a9:	e8 b5 e5 ff ff       	call   c0028963 <debug_panic>
  i->elem = list_elem_to_hash_elem (list_next (&i->elem->list_elem));
c002a3ae:	8b 43 08             	mov    0x8(%ebx),%eax
c002a3b1:	89 04 24             	mov    %eax,(%esp)
c002a3b4:	e8 06 e7 ff ff       	call   c0028abf <list_next>
c002a3b9:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a3bc:	eb 2c                	jmp    c002a3ea <hash_next+0x75>
      if (++i->bucket >= i->hash->buckets + i->hash->bucket_cnt)
c002a3be:	8b 43 04             	mov    0x4(%ebx),%eax
c002a3c1:	83 c0 10             	add    $0x10,%eax
c002a3c4:	89 43 04             	mov    %eax,0x4(%ebx)
c002a3c7:	8b 13                	mov    (%ebx),%edx
c002a3c9:	8b 4a 04             	mov    0x4(%edx),%ecx
c002a3cc:	c1 e1 04             	shl    $0x4,%ecx
c002a3cf:	03 4a 08             	add    0x8(%edx),%ecx
c002a3d2:	39 c8                	cmp    %ecx,%eax
c002a3d4:	72 09                	jb     c002a3df <hash_next+0x6a>
          i->elem = NULL;
c002a3d6:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
          break;
c002a3dd:	eb 1d                	jmp    c002a3fc <hash_next+0x87>
      i->elem = list_elem_to_hash_elem (list_begin (i->bucket));
c002a3df:	89 04 24             	mov    %eax,(%esp)
c002a3e2:	e8 9a e6 ff ff       	call   c0028a81 <list_begin>
c002a3e7:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a3ea:	8b 73 08             	mov    0x8(%ebx),%esi
c002a3ed:	8b 43 04             	mov    0x4(%ebx),%eax
c002a3f0:	89 04 24             	mov    %eax,(%esp)
c002a3f3:	e8 1b e7 ff ff       	call   c0028b13 <list_end>
c002a3f8:	39 c6                	cmp    %eax,%esi
c002a3fa:	74 c2                	je     c002a3be <hash_next+0x49>
  return i->elem;
c002a3fc:	8b 43 08             	mov    0x8(%ebx),%eax
}
c002a3ff:	83 c4 24             	add    $0x24,%esp
c002a402:	5b                   	pop    %ebx
c002a403:	5e                   	pop    %esi
c002a404:	c3                   	ret    

c002a405 <hash_cur>:
  return i->elem;
c002a405:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a409:	8b 40 08             	mov    0x8(%eax),%eax
}
c002a40c:	c3                   	ret    

c002a40d <hash_size>:
  return h->elem_cnt;
c002a40d:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a411:	8b 00                	mov    (%eax),%eax
}
c002a413:	c3                   	ret    

c002a414 <hash_empty>:
  return h->elem_cnt == 0;
c002a414:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a418:	83 38 00             	cmpl   $0x0,(%eax)
c002a41b:	0f 94 c0             	sete   %al
}
c002a41e:	c3                   	ret    

c002a41f <hash_bytes>:
{
c002a41f:	53                   	push   %ebx
c002a420:	83 ec 28             	sub    $0x28,%esp
c002a423:	8b 54 24 30          	mov    0x30(%esp),%edx
c002a427:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (buf != NULL);
c002a42b:	85 d2                	test   %edx,%edx
c002a42d:	74 0e                	je     c002a43d <hash_bytes+0x1e>
c002a42f:	8d 1c 0a             	lea    (%edx,%ecx,1),%ebx
  while (size-- > 0)
c002a432:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a437:	85 c9                	test   %ecx,%ecx
c002a439:	75 2e                	jne    c002a469 <hash_bytes+0x4a>
c002a43b:	eb 3f                	jmp    c002a47c <hash_bytes+0x5d>
  ASSERT (buf != NULL);
c002a43d:	c7 44 24 10 1b fe 02 	movl   $0xc002fe1b,0x10(%esp)
c002a444:	c0 
c002a445:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a44c:	c0 
c002a44d:	c7 44 24 08 b3 dd 02 	movl   $0xc002ddb3,0x8(%esp)
c002a454:	c0 
c002a455:	c7 44 24 04 10 01 00 	movl   $0x110,0x4(%esp)
c002a45c:	00 
c002a45d:	c7 04 24 ea fd 02 c0 	movl   $0xc002fdea,(%esp)
c002a464:	e8 fa e4 ff ff       	call   c0028963 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *buf++;
c002a469:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a46f:	83 c2 01             	add    $0x1,%edx
c002a472:	0f b6 4a ff          	movzbl -0x1(%edx),%ecx
c002a476:	31 c8                	xor    %ecx,%eax
  while (size-- > 0)
c002a478:	39 da                	cmp    %ebx,%edx
c002a47a:	75 ed                	jne    c002a469 <hash_bytes+0x4a>
} 
c002a47c:	83 c4 28             	add    $0x28,%esp
c002a47f:	5b                   	pop    %ebx
c002a480:	c3                   	ret    

c002a481 <hash_string>:
{
c002a481:	83 ec 2c             	sub    $0x2c,%esp
c002a484:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002a488:	85 d2                	test   %edx,%edx
c002a48a:	74 0e                	je     c002a49a <hash_string+0x19>
  while (*s != '\0')
c002a48c:	0f b6 0a             	movzbl (%edx),%ecx
c002a48f:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a494:	84 c9                	test   %cl,%cl
c002a496:	75 2e                	jne    c002a4c6 <hash_string+0x45>
c002a498:	eb 41                	jmp    c002a4db <hash_string+0x5a>
  ASSERT (s != NULL);
c002a49a:	c7 44 24 10 c6 f9 02 	movl   $0xc002f9c6,0x10(%esp)
c002a4a1:	c0 
c002a4a2:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a4a9:	c0 
c002a4aa:	c7 44 24 08 a7 dd 02 	movl   $0xc002dda7,0x8(%esp)
c002a4b1:	c0 
c002a4b2:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c002a4b9:	00 
c002a4ba:	c7 04 24 ea fd 02 c0 	movl   $0xc002fdea,(%esp)
c002a4c1:	e8 9d e4 ff ff       	call   c0028963 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *s++;
c002a4c6:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a4cc:	83 c2 01             	add    $0x1,%edx
c002a4cf:	0f b6 c9             	movzbl %cl,%ecx
c002a4d2:	31 c8                	xor    %ecx,%eax
  while (*s != '\0')
c002a4d4:	0f b6 0a             	movzbl (%edx),%ecx
c002a4d7:	84 c9                	test   %cl,%cl
c002a4d9:	75 eb                	jne    c002a4c6 <hash_string+0x45>
}
c002a4db:	83 c4 2c             	add    $0x2c,%esp
c002a4de:	c3                   	ret    

c002a4df <hash_int>:
{
c002a4df:	83 ec 1c             	sub    $0x1c,%esp
  return hash_bytes (&i, sizeof i);
c002a4e2:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002a4e9:	00 
c002a4ea:	8d 44 24 20          	lea    0x20(%esp),%eax
c002a4ee:	89 04 24             	mov    %eax,(%esp)
c002a4f1:	e8 29 ff ff ff       	call   c002a41f <hash_bytes>
}
c002a4f6:	83 c4 1c             	add    $0x1c,%esp
c002a4f9:	c3                   	ret    

c002a4fa <putchar_have_lock>:
/* Writes C to the vga display and serial port.
   The caller has already acquired the console lock if
   appropriate. */
static void
putchar_have_lock (uint8_t c) 
{
c002a4fa:	53                   	push   %ebx
c002a4fb:	83 ec 28             	sub    $0x28,%esp
c002a4fe:	89 c3                	mov    %eax,%ebx
  return (intr_context ()
c002a500:	e8 fc 76 ff ff       	call   c0021c01 <intr_context>
          || lock_held_by_current_thread (&console_lock));
c002a505:	84 c0                	test   %al,%al
c002a507:	75 45                	jne    c002a54e <putchar_have_lock+0x54>
          || !use_console_lock
c002a509:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a510:	74 3c                	je     c002a54e <putchar_have_lock+0x54>
          || lock_held_by_current_thread (&console_lock));
c002a512:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a519:	e8 d3 88 ff ff       	call   c0022df1 <lock_held_by_current_thread>
  ASSERT (console_locked_by_current_thread ());
c002a51e:	84 c0                	test   %al,%al
c002a520:	75 2c                	jne    c002a54e <putchar_have_lock+0x54>
c002a522:	c7 44 24 10 28 fe 02 	movl   $0xc002fe28,0x10(%esp)
c002a529:	c0 
c002a52a:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a531:	c0 
c002a532:	c7 44 24 08 e5 dd 02 	movl   $0xc002dde5,0x8(%esp)
c002a539:	c0 
c002a53a:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c002a541:	00 
c002a542:	c7 04 24 6d fe 02 c0 	movl   $0xc002fe6d,(%esp)
c002a549:	e8 15 e4 ff ff       	call   c0028963 <debug_panic>
  write_cnt++;
c002a54e:	83 05 e0 7a 03 c0 01 	addl   $0x1,0xc0037ae0
c002a555:	83 15 e4 7a 03 c0 00 	adcl   $0x0,0xc0037ae4
  serial_putc (c);
c002a55c:	0f b6 db             	movzbl %bl,%ebx
c002a55f:	89 1c 24             	mov    %ebx,(%esp)
c002a562:	e8 95 a5 ff ff       	call   c0024afc <serial_putc>
  vga_putc (c);
c002a567:	89 1c 24             	mov    %ebx,(%esp)
c002a56a:	e8 aa a1 ff ff       	call   c0024719 <vga_putc>
}
c002a56f:	83 c4 28             	add    $0x28,%esp
c002a572:	5b                   	pop    %ebx
c002a573:	c3                   	ret    

c002a574 <vprintf_helper>:
{
c002a574:	83 ec 0c             	sub    $0xc,%esp
c002a577:	8b 44 24 14          	mov    0x14(%esp),%eax
  (*char_cnt)++;
c002a57b:	83 00 01             	addl   $0x1,(%eax)
  putchar_have_lock (c);
c002a57e:	0f b6 44 24 10       	movzbl 0x10(%esp),%eax
c002a583:	e8 72 ff ff ff       	call   c002a4fa <putchar_have_lock>
}
c002a588:	83 c4 0c             	add    $0xc,%esp
c002a58b:	c3                   	ret    

c002a58c <acquire_console>:
{
c002a58c:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a58f:	e8 6d 76 ff ff       	call   c0021c01 <intr_context>
c002a594:	84 c0                	test   %al,%al
c002a596:	75 2e                	jne    c002a5c6 <acquire_console+0x3a>
c002a598:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a59f:	74 25                	je     c002a5c6 <acquire_console+0x3a>
      if (lock_held_by_current_thread (&console_lock)) 
c002a5a1:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5a8:	e8 44 88 ff ff       	call   c0022df1 <lock_held_by_current_thread>
c002a5ad:	84 c0                	test   %al,%al
c002a5af:	74 09                	je     c002a5ba <acquire_console+0x2e>
        console_lock_depth++; 
c002a5b1:	83 05 e8 7a 03 c0 01 	addl   $0x1,0xc0037ae8
c002a5b8:	eb 0c                	jmp    c002a5c6 <acquire_console+0x3a>
        lock_acquire (&console_lock); 
c002a5ba:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5c1:	e8 74 88 ff ff       	call   c0022e3a <lock_acquire>
}
c002a5c6:	83 c4 1c             	add    $0x1c,%esp
c002a5c9:	c3                   	ret    

c002a5ca <release_console>:
{
c002a5ca:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a5cd:	e8 2f 76 ff ff       	call   c0021c01 <intr_context>
c002a5d2:	84 c0                	test   %al,%al
c002a5d4:	75 28                	jne    c002a5fe <release_console+0x34>
c002a5d6:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a5dd:	74 1f                	je     c002a5fe <release_console+0x34>
      if (console_lock_depth > 0)
c002a5df:	a1 e8 7a 03 c0       	mov    0xc0037ae8,%eax
c002a5e4:	85 c0                	test   %eax,%eax
c002a5e6:	7e 0a                	jle    c002a5f2 <release_console+0x28>
        console_lock_depth--;
c002a5e8:	83 e8 01             	sub    $0x1,%eax
c002a5eb:	a3 e8 7a 03 c0       	mov    %eax,0xc0037ae8
c002a5f0:	eb 0c                	jmp    c002a5fe <release_console+0x34>
        lock_release (&console_lock); 
c002a5f2:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5f9:	e8 06 8a ff ff       	call   c0023004 <lock_release>
}
c002a5fe:	83 c4 1c             	add    $0x1c,%esp
c002a601:	c3                   	ret    

c002a602 <console_init>:
{
c002a602:	83 ec 1c             	sub    $0x1c,%esp
  lock_init (&console_lock);
c002a605:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a60c:	e8 8c 87 ff ff       	call   c0022d9d <lock_init>
  use_console_lock = true;
c002a611:	c6 05 ec 7a 03 c0 01 	movb   $0x1,0xc0037aec
}
c002a618:	83 c4 1c             	add    $0x1c,%esp
c002a61b:	c3                   	ret    

c002a61c <console_panic>:
  use_console_lock = false;
c002a61c:	c6 05 ec 7a 03 c0 00 	movb   $0x0,0xc0037aec
c002a623:	c3                   	ret    

c002a624 <console_print_stats>:
{
c002a624:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Console: %lld characters output\n", write_cnt);
c002a627:	a1 e0 7a 03 c0       	mov    0xc0037ae0,%eax
c002a62c:	8b 15 e4 7a 03 c0    	mov    0xc0037ae4,%edx
c002a632:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a636:	89 54 24 08          	mov    %edx,0x8(%esp)
c002a63a:	c7 04 24 4c fe 02 c0 	movl   $0xc002fe4c,(%esp)
c002a641:	e8 c8 c4 ff ff       	call   c0026b0e <printf>
}
c002a646:	83 c4 1c             	add    $0x1c,%esp
c002a649:	c3                   	ret    

c002a64a <vprintf>:
{
c002a64a:	83 ec 2c             	sub    $0x2c,%esp
  int char_cnt = 0;
c002a64d:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a654:	00 
  acquire_console ();
c002a655:	e8 32 ff ff ff       	call   c002a58c <acquire_console>
  __vprintf (format, args, vprintf_helper, &char_cnt);
c002a65a:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c002a65e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002a662:	c7 44 24 08 74 a5 02 	movl   $0xc002a574,0x8(%esp)
c002a669:	c0 
c002a66a:	8b 44 24 34          	mov    0x34(%esp),%eax
c002a66e:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a672:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a676:	89 04 24             	mov    %eax,(%esp)
c002a679:	e8 d6 c4 ff ff       	call   c0026b54 <__vprintf>
  release_console ();
c002a67e:	e8 47 ff ff ff       	call   c002a5ca <release_console>
}
c002a683:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a687:	83 c4 2c             	add    $0x2c,%esp
c002a68a:	c3                   	ret    

c002a68b <puts>:
{
c002a68b:	53                   	push   %ebx
c002a68c:	83 ec 08             	sub    $0x8,%esp
c002a68f:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a693:	e8 f4 fe ff ff       	call   c002a58c <acquire_console>
  while (*s != '\0')
c002a698:	0f b6 03             	movzbl (%ebx),%eax
c002a69b:	84 c0                	test   %al,%al
c002a69d:	74 12                	je     c002a6b1 <puts+0x26>
    putchar_have_lock (*s++);
c002a69f:	83 c3 01             	add    $0x1,%ebx
c002a6a2:	0f b6 c0             	movzbl %al,%eax
c002a6a5:	e8 50 fe ff ff       	call   c002a4fa <putchar_have_lock>
  while (*s != '\0')
c002a6aa:	0f b6 03             	movzbl (%ebx),%eax
c002a6ad:	84 c0                	test   %al,%al
c002a6af:	75 ee                	jne    c002a69f <puts+0x14>
  putchar_have_lock ('\n');
c002a6b1:	b8 0a 00 00 00       	mov    $0xa,%eax
c002a6b6:	e8 3f fe ff ff       	call   c002a4fa <putchar_have_lock>
  release_console ();
c002a6bb:	e8 0a ff ff ff       	call   c002a5ca <release_console>
}
c002a6c0:	b8 00 00 00 00       	mov    $0x0,%eax
c002a6c5:	83 c4 08             	add    $0x8,%esp
c002a6c8:	5b                   	pop    %ebx
c002a6c9:	c3                   	ret    

c002a6ca <putbuf>:
{
c002a6ca:	56                   	push   %esi
c002a6cb:	53                   	push   %ebx
c002a6cc:	83 ec 04             	sub    $0x4,%esp
c002a6cf:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a6d3:	8b 74 24 14          	mov    0x14(%esp),%esi
  acquire_console ();
c002a6d7:	e8 b0 fe ff ff       	call   c002a58c <acquire_console>
  while (n-- > 0)
c002a6dc:	85 f6                	test   %esi,%esi
c002a6de:	74 11                	je     c002a6f1 <putbuf+0x27>
    putchar_have_lock (*buffer++);
c002a6e0:	83 c3 01             	add    $0x1,%ebx
c002a6e3:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
c002a6e7:	e8 0e fe ff ff       	call   c002a4fa <putchar_have_lock>
  while (n-- > 0)
c002a6ec:	83 ee 01             	sub    $0x1,%esi
c002a6ef:	75 ef                	jne    c002a6e0 <putbuf+0x16>
  release_console ();
c002a6f1:	e8 d4 fe ff ff       	call   c002a5ca <release_console>
}
c002a6f6:	83 c4 04             	add    $0x4,%esp
c002a6f9:	5b                   	pop    %ebx
c002a6fa:	5e                   	pop    %esi
c002a6fb:	c3                   	ret    

c002a6fc <putchar>:
{
c002a6fc:	53                   	push   %ebx
c002a6fd:	83 ec 08             	sub    $0x8,%esp
c002a700:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a704:	e8 83 fe ff ff       	call   c002a58c <acquire_console>
  putchar_have_lock (c);
c002a709:	0f b6 c3             	movzbl %bl,%eax
c002a70c:	e8 e9 fd ff ff       	call   c002a4fa <putchar_have_lock>
  release_console ();
c002a711:	e8 b4 fe ff ff       	call   c002a5ca <release_console>
}
c002a716:	89 d8                	mov    %ebx,%eax
c002a718:	83 c4 08             	add    $0x8,%esp
c002a71b:	5b                   	pop    %ebx
c002a71c:	c3                   	ret    

c002a71d <msg>:
/* Prints FORMAT as if with printf(),
   prefixing the output by the name of the test
   and following it with a new-line character. */
void
msg (const char *format, ...) 
{
c002a71d:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) ", test_name);
c002a720:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a725:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a729:	c7 04 24 88 fe 02 c0 	movl   $0xc002fe88,(%esp)
c002a730:	e8 d9 c3 ff ff       	call   c0026b0e <printf>
  va_start (args, format);
c002a735:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a739:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a73d:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a741:	89 04 24             	mov    %eax,(%esp)
c002a744:	e8 01 ff ff ff       	call   c002a64a <vprintf>
  va_end (args);
  putchar ('\n');
c002a749:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a750:	e8 a7 ff ff ff       	call   c002a6fc <putchar>
}
c002a755:	83 c4 1c             	add    $0x1c,%esp
c002a758:	c3                   	ret    

c002a759 <run_test>:
{
c002a759:	56                   	push   %esi
c002a75a:	53                   	push   %ebx
c002a75b:	83 ec 24             	sub    $0x24,%esp
c002a75e:	8b 74 24 30          	mov    0x30(%esp),%esi
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a762:	bb 20 de 02 c0       	mov    $0xc002de20,%ebx
    if (!strcmp (name, t->name))
c002a767:	8b 03                	mov    (%ebx),%eax
c002a769:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a76d:	89 34 24             	mov    %esi,(%esp)
c002a770:	e8 02 d3 ff ff       	call   c0027a77 <strcmp>
c002a775:	85 c0                	test   %eax,%eax
c002a777:	75 23                	jne    c002a79c <run_test+0x43>
        test_name = name;
c002a779:	89 35 24 7b 03 c0    	mov    %esi,0xc0037b24
        msg ("begin");
c002a77f:	c7 04 24 8e fe 02 c0 	movl   $0xc002fe8e,(%esp)
c002a786:	e8 92 ff ff ff       	call   c002a71d <msg>
        t->function ();
c002a78b:	ff 53 04             	call   *0x4(%ebx)
        msg ("end");
c002a78e:	c7 04 24 94 fe 02 c0 	movl   $0xc002fe94,(%esp)
c002a795:	e8 83 ff ff ff       	call   c002a71d <msg>
c002a79a:	eb 33                	jmp    c002a7cf <run_test+0x76>
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a79c:	83 c3 08             	add    $0x8,%ebx
c002a79f:	81 fb f8 de 02 c0    	cmp    $0xc002def8,%ebx
c002a7a5:	72 c0                	jb     c002a767 <run_test+0xe>
  PANIC ("no test named \"%s\"", name);
c002a7a7:	89 74 24 10          	mov    %esi,0x10(%esp)
c002a7ab:	c7 44 24 0c 98 fe 02 	movl   $0xc002fe98,0xc(%esp)
c002a7b2:	c0 
c002a7b3:	c7 44 24 08 05 de 02 	movl   $0xc002de05,0x8(%esp)
c002a7ba:	c0 
c002a7bb:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a7c2:	00 
c002a7c3:	c7 04 24 ab fe 02 c0 	movl   $0xc002feab,(%esp)
c002a7ca:	e8 94 e1 ff ff       	call   c0028963 <debug_panic>
}
c002a7cf:	83 c4 24             	add    $0x24,%esp
c002a7d2:	5b                   	pop    %ebx
c002a7d3:	5e                   	pop    %esi
c002a7d4:	c3                   	ret    

c002a7d5 <fail>:
   prefixing the output by the name of the test and FAIL:
   and following it with a new-line character,
   and then panics the kernel. */
void
fail (const char *format, ...) 
{
c002a7d5:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) FAIL: ", test_name);
c002a7d8:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a7dd:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a7e1:	c7 04 24 c7 fe 02 c0 	movl   $0xc002fec7,(%esp)
c002a7e8:	e8 21 c3 ff ff       	call   c0026b0e <printf>
  va_start (args, format);
c002a7ed:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a7f1:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a7f5:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a7f9:	89 04 24             	mov    %eax,(%esp)
c002a7fc:	e8 49 fe ff ff       	call   c002a64a <vprintf>
  va_end (args);
  putchar ('\n');
c002a801:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a808:	e8 ef fe ff ff       	call   c002a6fc <putchar>

  PANIC ("test failed");
c002a80d:	c7 44 24 0c d3 fe 02 	movl   $0xc002fed3,0xc(%esp)
c002a814:	c0 
c002a815:	c7 44 24 08 00 de 02 	movl   $0xc002de00,0x8(%esp)
c002a81c:	c0 
c002a81d:	c7 44 24 04 5d 00 00 	movl   $0x5d,0x4(%esp)
c002a824:	00 
c002a825:	c7 04 24 ab fe 02 c0 	movl   $0xc002feab,(%esp)
c002a82c:	e8 32 e1 ff ff       	call   c0028963 <debug_panic>

c002a831 <pass>:
}

/* Prints a message indicating the current test passed. */
void
pass (void) 
{
c002a831:	83 ec 1c             	sub    $0x1c,%esp
  printf ("(%s) PASS\n", test_name);
c002a834:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a839:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a83d:	c7 04 24 df fe 02 c0 	movl   $0xc002fedf,(%esp)
c002a844:	e8 c5 c2 ff ff       	call   c0026b0e <printf>
}
c002a849:	83 c4 1c             	add    $0x1c,%esp
c002a84c:	c3                   	ret    
c002a84d:	90                   	nop
c002a84e:	90                   	nop
c002a84f:	90                   	nop

c002a850 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *t_) 
{
c002a850:	55                   	push   %ebp
c002a851:	57                   	push   %edi
c002a852:	56                   	push   %esi
c002a853:	53                   	push   %ebx
c002a854:	83 ec 1c             	sub    $0x1c,%esp
  struct sleep_thread *t = t_;
  struct sleep_test *test = t->test;
c002a857:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a85b:	8b 18                	mov    (%eax),%ebx
  int i;

  for (i = 1; i <= test->iterations; i++) 
c002a85d:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002a861:	7e 63                	jle    c002a8c6 <sleeper+0x76>
c002a863:	bd 01 00 00 00       	mov    $0x1,%ebp
    {
      int64_t sleep_until = test->start + i * t->duration;
      timer_sleep (sleep_until - timer_ticks ());
      lock_acquire (&test->output_lock);
c002a868:	8d 43 0c             	lea    0xc(%ebx),%eax
c002a86b:	89 44 24 0c          	mov    %eax,0xc(%esp)
      int64_t sleep_until = test->start + i * t->duration;
c002a86f:	89 e8                	mov    %ebp,%eax
c002a871:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a875:	0f af 41 08          	imul   0x8(%ecx),%eax
c002a879:	99                   	cltd   
c002a87a:	03 03                	add    (%ebx),%eax
c002a87c:	13 53 04             	adc    0x4(%ebx),%edx
c002a87f:	89 c6                	mov    %eax,%esi
c002a881:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002a883:	e8 68 99 ff ff       	call   c00241f0 <timer_ticks>
c002a888:	29 c6                	sub    %eax,%esi
c002a88a:	19 d7                	sbb    %edx,%edi
c002a88c:	89 34 24             	mov    %esi,(%esp)
c002a88f:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a893:	e8 a0 99 ff ff       	call   c0024238 <timer_sleep>
      lock_acquire (&test->output_lock);
c002a898:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c002a89c:	89 3c 24             	mov    %edi,(%esp)
c002a89f:	e8 96 85 ff ff       	call   c0022e3a <lock_acquire>
      *test->output_pos++ = t->id;
c002a8a4:	8b 43 30             	mov    0x30(%ebx),%eax
c002a8a7:	8d 50 04             	lea    0x4(%eax),%edx
c002a8aa:	89 53 30             	mov    %edx,0x30(%ebx)
c002a8ad:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a8b1:	8b 51 04             	mov    0x4(%ecx),%edx
c002a8b4:	89 10                	mov    %edx,(%eax)
      lock_release (&test->output_lock);
c002a8b6:	89 3c 24             	mov    %edi,(%esp)
c002a8b9:	e8 46 87 ff ff       	call   c0023004 <lock_release>
  for (i = 1; i <= test->iterations; i++) 
c002a8be:	83 c5 01             	add    $0x1,%ebp
c002a8c1:	39 6b 08             	cmp    %ebp,0x8(%ebx)
c002a8c4:	7d a9                	jge    c002a86f <sleeper+0x1f>
    }
}
c002a8c6:	83 c4 1c             	add    $0x1c,%esp
c002a8c9:	5b                   	pop    %ebx
c002a8ca:	5e                   	pop    %esi
c002a8cb:	5f                   	pop    %edi
c002a8cc:	5d                   	pop    %ebp
c002a8cd:	c3                   	ret    

c002a8ce <test_sleep>:
{
c002a8ce:	55                   	push   %ebp
c002a8cf:	57                   	push   %edi
c002a8d0:	56                   	push   %esi
c002a8d1:	53                   	push   %ebx
c002a8d2:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c002a8d8:	89 44 24 20          	mov    %eax,0x20(%esp)
c002a8dc:	89 54 24 2c          	mov    %edx,0x2c(%esp)
  ASSERT (!thread_mlfqs);
c002a8e0:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002a8e7:	74 2c                	je     c002a915 <test_sleep+0x47>
c002a8e9:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002a8f0:	c0 
c002a8f1:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002a8f8:	c0 
c002a8f9:	c7 44 24 08 f8 de 02 	movl   $0xc002def8,0x8(%esp)
c002a900:	c0 
c002a901:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a908:	00 
c002a909:	c7 04 24 ec 00 03 c0 	movl   $0xc00300ec,(%esp)
c002a910:	e8 4e e0 ff ff       	call   c0028963 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002a915:	8b 74 24 2c          	mov    0x2c(%esp),%esi
c002a919:	89 74 24 08          	mov    %esi,0x8(%esp)
c002a91d:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002a921:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a925:	c7 04 24 10 01 03 c0 	movl   $0xc0030110,(%esp)
c002a92c:	e8 ec fd ff ff       	call   c002a71d <msg>
  msg ("Thread 0 sleeps 10 ticks each time,");
c002a931:	c7 04 24 3c 01 03 c0 	movl   $0xc003013c,(%esp)
c002a938:	e8 e0 fd ff ff       	call   c002a71d <msg>
  msg ("thread 1 sleeps 20 ticks each time, and so on.");
c002a93d:	c7 04 24 60 01 03 c0 	movl   $0xc0030160,(%esp)
c002a944:	e8 d4 fd ff ff       	call   c002a71d <msg>
  msg ("If successful, product of iteration count and");
c002a949:	c7 04 24 90 01 03 c0 	movl   $0xc0030190,(%esp)
c002a950:	e8 c8 fd ff ff       	call   c002a71d <msg>
  msg ("sleep duration will appear in nondescending order.");
c002a955:	c7 04 24 c0 01 03 c0 	movl   $0xc00301c0,(%esp)
c002a95c:	e8 bc fd ff ff       	call   c002a71d <msg>
  threads = malloc (sizeof *threads * thread_cnt);
c002a961:	89 f8                	mov    %edi,%eax
c002a963:	c1 e0 04             	shl    $0x4,%eax
c002a966:	89 04 24             	mov    %eax,(%esp)
c002a969:	e8 96 90 ff ff       	call   c0023a04 <malloc>
c002a96e:	89 c3                	mov    %eax,%ebx
c002a970:	89 44 24 24          	mov    %eax,0x24(%esp)
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002a974:	8d 04 f5 00 00 00 00 	lea    0x0(,%esi,8),%eax
c002a97b:	0f af c7             	imul   %edi,%eax
c002a97e:	89 04 24             	mov    %eax,(%esp)
c002a981:	e8 7e 90 ff ff       	call   c0023a04 <malloc>
c002a986:	89 44 24 28          	mov    %eax,0x28(%esp)
  if (threads == NULL || output == NULL)
c002a98a:	85 c0                	test   %eax,%eax
c002a98c:	74 04                	je     c002a992 <test_sleep+0xc4>
c002a98e:	85 db                	test   %ebx,%ebx
c002a990:	75 24                	jne    c002a9b6 <test_sleep+0xe8>
    PANIC ("couldn't allocate memory for test");
c002a992:	c7 44 24 0c f4 01 03 	movl   $0xc00301f4,0xc(%esp)
c002a999:	c0 
c002a99a:	c7 44 24 08 f8 de 02 	movl   $0xc002def8,0x8(%esp)
c002a9a1:	c0 
c002a9a2:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c002a9a9:	00 
c002a9aa:	c7 04 24 ec 00 03 c0 	movl   $0xc00300ec,(%esp)
c002a9b1:	e8 ad df ff ff       	call   c0028963 <debug_panic>
  test.start = timer_ticks () + 100;
c002a9b6:	e8 35 98 ff ff       	call   c00241f0 <timer_ticks>
c002a9bb:	83 c0 64             	add    $0x64,%eax
c002a9be:	83 d2 00             	adc    $0x0,%edx
c002a9c1:	89 44 24 4c          	mov    %eax,0x4c(%esp)
c002a9c5:	89 54 24 50          	mov    %edx,0x50(%esp)
  test.iterations = iterations;
c002a9c9:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a9cd:	89 44 24 54          	mov    %eax,0x54(%esp)
  lock_init (&test.output_lock);
c002a9d1:	8d 44 24 58          	lea    0x58(%esp),%eax
c002a9d5:	89 04 24             	mov    %eax,(%esp)
c002a9d8:	e8 c0 83 ff ff       	call   c0022d9d <lock_init>
  test.output_pos = output;
c002a9dd:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a9e1:	89 44 24 7c          	mov    %eax,0x7c(%esp)
  ASSERT (output != NULL);
c002a9e5:	85 c0                	test   %eax,%eax
c002a9e7:	74 1e                	je     c002aa07 <test_sleep+0x139>
c002a9e9:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  for (i = 0; i < thread_cnt; i++)
c002a9ed:	be 0a 00 00 00       	mov    $0xa,%esi
c002a9f2:	b8 00 00 00 00       	mov    $0x0,%eax
      snprintf (name, sizeof name, "thread %d", i);
c002a9f7:	8d 6c 24 3c          	lea    0x3c(%esp),%ebp
  for (i = 0; i < thread_cnt; i++)
c002a9fb:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c002aa00:	7f 31                	jg     c002aa33 <test_sleep+0x165>
c002aa02:	e9 8a 00 00 00       	jmp    c002aa91 <test_sleep+0x1c3>
  ASSERT (output != NULL);
c002aa07:	c7 44 24 10 b6 00 03 	movl   $0xc00300b6,0x10(%esp)
c002aa0e:	c0 
c002aa0f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002aa16:	c0 
c002aa17:	c7 44 24 08 f8 de 02 	movl   $0xc002def8,0x8(%esp)
c002aa1e:	c0 
c002aa1f:	c7 44 24 04 51 00 00 	movl   $0x51,0x4(%esp)
c002aa26:	00 
c002aa27:	c7 04 24 ec 00 03 c0 	movl   $0xc00300ec,(%esp)
c002aa2e:	e8 30 df ff ff       	call   c0028963 <debug_panic>
      t->test = &test;
c002aa33:	8d 4c 24 4c          	lea    0x4c(%esp),%ecx
c002aa37:	89 0b                	mov    %ecx,(%ebx)
      t->id = i;
c002aa39:	89 43 04             	mov    %eax,0x4(%ebx)
      t->duration = (i + 1) * 10;
c002aa3c:	8d 78 01             	lea    0x1(%eax),%edi
c002aa3f:	89 73 08             	mov    %esi,0x8(%ebx)
      t->iterations = 0;
c002aa42:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
      snprintf (name, sizeof name, "thread %d", i);
c002aa49:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002aa4d:	c7 44 24 08 c5 00 03 	movl   $0xc00300c5,0x8(%esp)
c002aa54:	c0 
c002aa55:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002aa5c:	00 
c002aa5d:	89 2c 24             	mov    %ebp,(%esp)
c002aa60:	e8 aa c7 ff ff       	call   c002720f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, t);
c002aa65:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002aa69:	c7 44 24 08 50 a8 02 	movl   $0xc002a850,0x8(%esp)
c002aa70:	c0 
c002aa71:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002aa78:	00 
c002aa79:	89 2c 24             	mov    %ebp,(%esp)
c002aa7c:	e8 a6 6a ff ff       	call   c0021527 <thread_create>
c002aa81:	83 c3 10             	add    $0x10,%ebx
c002aa84:	83 c6 0a             	add    $0xa,%esi
  for (i = 0; i < thread_cnt; i++)
c002aa87:	3b 7c 24 20          	cmp    0x20(%esp),%edi
c002aa8b:	74 04                	je     c002aa91 <test_sleep+0x1c3>
c002aa8d:	89 f8                	mov    %edi,%eax
c002aa8f:	eb a2                	jmp    c002aa33 <test_sleep+0x165>
  timer_sleep (100 + thread_cnt * iterations * 10 + 100);
c002aa91:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002aa95:	89 f8                	mov    %edi,%eax
c002aa97:	0f af 44 24 2c       	imul   0x2c(%esp),%eax
c002aa9c:	8d 04 80             	lea    (%eax,%eax,4),%eax
c002aa9f:	8d 84 00 c8 00 00 00 	lea    0xc8(%eax,%eax,1),%eax
c002aaa6:	89 04 24             	mov    %eax,(%esp)
c002aaa9:	89 c1                	mov    %eax,%ecx
c002aaab:	c1 f9 1f             	sar    $0x1f,%ecx
c002aaae:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002aab2:	e8 81 97 ff ff       	call   c0024238 <timer_sleep>
  lock_acquire (&test.output_lock);
c002aab7:	8d 44 24 58          	lea    0x58(%esp),%eax
c002aabb:	89 04 24             	mov    %eax,(%esp)
c002aabe:	e8 77 83 ff ff       	call   c0022e3a <lock_acquire>
  for (op = output; op < test.output_pos; op++) 
c002aac3:	8b 44 24 28          	mov    0x28(%esp),%eax
c002aac7:	3b 44 24 7c          	cmp    0x7c(%esp),%eax
c002aacb:	0f 83 bb 00 00 00    	jae    c002ab8c <test_sleep+0x2be>
      ASSERT (*op >= 0 && *op < thread_cnt);
c002aad1:	8b 18                	mov    (%eax),%ebx
c002aad3:	85 db                	test   %ebx,%ebx
c002aad5:	78 1b                	js     c002aaf2 <test_sleep+0x224>
c002aad7:	39 df                	cmp    %ebx,%edi
c002aad9:	7f 43                	jg     c002ab1e <test_sleep+0x250>
c002aadb:	90                   	nop
c002aadc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c002aae0:	eb 10                	jmp    c002aaf2 <test_sleep+0x224>
c002aae2:	8b 1f                	mov    (%edi),%ebx
c002aae4:	85 db                	test   %ebx,%ebx
c002aae6:	78 0a                	js     c002aaf2 <test_sleep+0x224>
c002aae8:	39 5c 24 20          	cmp    %ebx,0x20(%esp)
c002aaec:	7e 04                	jle    c002aaf2 <test_sleep+0x224>
c002aaee:	89 f5                	mov    %esi,%ebp
c002aaf0:	eb 35                	jmp    c002ab27 <test_sleep+0x259>
c002aaf2:	c7 44 24 10 cf 00 03 	movl   $0xc00300cf,0x10(%esp)
c002aaf9:	c0 
c002aafa:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002ab01:	c0 
c002ab02:	c7 44 24 08 f8 de 02 	movl   $0xc002def8,0x8(%esp)
c002ab09:	c0 
c002ab0a:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
c002ab11:	00 
c002ab12:	c7 04 24 ec 00 03 c0 	movl   $0xc00300ec,(%esp)
c002ab19:	e8 45 de ff ff       	call   c0028963 <debug_panic>
  for (op = output; op < test.output_pos; op++) 
c002ab1e:	8b 7c 24 28          	mov    0x28(%esp),%edi
  product = 0;
c002ab22:	bd 00 00 00 00       	mov    $0x0,%ebp
      t = threads + *op;
c002ab27:	c1 e3 04             	shl    $0x4,%ebx
c002ab2a:	03 5c 24 24          	add    0x24(%esp),%ebx
      new_prod = ++t->iterations * t->duration;
c002ab2e:	8b 43 0c             	mov    0xc(%ebx),%eax
c002ab31:	83 c0 01             	add    $0x1,%eax
c002ab34:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ab37:	8b 53 08             	mov    0x8(%ebx),%edx
c002ab3a:	89 c6                	mov    %eax,%esi
c002ab3c:	0f af f2             	imul   %edx,%esi
      msg ("thread %d: duration=%d, iteration=%d, product=%d",
c002ab3f:	89 74 24 10          	mov    %esi,0x10(%esp)
c002ab43:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ab47:	89 54 24 08          	mov    %edx,0x8(%esp)
c002ab4b:	8b 43 04             	mov    0x4(%ebx),%eax
c002ab4e:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ab52:	c7 04 24 18 02 03 c0 	movl   $0xc0030218,(%esp)
c002ab59:	e8 bf fb ff ff       	call   c002a71d <msg>
      if (new_prod >= product)
c002ab5e:	39 ee                	cmp    %ebp,%esi
c002ab60:	7d 1d                	jge    c002ab7f <test_sleep+0x2b1>
        fail ("thread %d woke up out of order (%d > %d)!",
c002ab62:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ab66:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002ab6a:	8b 43 04             	mov    0x4(%ebx),%eax
c002ab6d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ab71:	c7 04 24 4c 02 03 c0 	movl   $0xc003024c,(%esp)
c002ab78:	e8 58 fc ff ff       	call   c002a7d5 <fail>
c002ab7d:	89 ee                	mov    %ebp,%esi
  for (op = output; op < test.output_pos; op++) 
c002ab7f:	83 c7 04             	add    $0x4,%edi
c002ab82:	39 7c 24 7c          	cmp    %edi,0x7c(%esp)
c002ab86:	0f 87 56 ff ff ff    	ja     c002aae2 <test_sleep+0x214>
  for (i = 0; i < thread_cnt; i++)
c002ab8c:	8b 6c 24 20          	mov    0x20(%esp),%ebp
c002ab90:	85 ed                	test   %ebp,%ebp
c002ab92:	7e 36                	jle    c002abca <test_sleep+0x2fc>
c002ab94:	8b 74 24 24          	mov    0x24(%esp),%esi
c002ab98:	bb 00 00 00 00       	mov    $0x0,%ebx
c002ab9d:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
    if (threads[i].iterations != iterations)
c002aba1:	8b 46 0c             	mov    0xc(%esi),%eax
c002aba4:	39 f8                	cmp    %edi,%eax
c002aba6:	74 18                	je     c002abc0 <test_sleep+0x2f2>
      fail ("thread %d woke up %d times instead of %d",
c002aba8:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002abac:	89 44 24 08          	mov    %eax,0x8(%esp)
c002abb0:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002abb4:	c7 04 24 78 02 03 c0 	movl   $0xc0030278,(%esp)
c002abbb:	e8 15 fc ff ff       	call   c002a7d5 <fail>
  for (i = 0; i < thread_cnt; i++)
c002abc0:	83 c3 01             	add    $0x1,%ebx
c002abc3:	83 c6 10             	add    $0x10,%esi
c002abc6:	39 eb                	cmp    %ebp,%ebx
c002abc8:	75 d7                	jne    c002aba1 <test_sleep+0x2d3>
  lock_release (&test.output_lock);
c002abca:	8d 44 24 58          	lea    0x58(%esp),%eax
c002abce:	89 04 24             	mov    %eax,(%esp)
c002abd1:	e8 2e 84 ff ff       	call   c0023004 <lock_release>
  free (output);
c002abd6:	8b 44 24 28          	mov    0x28(%esp),%eax
c002abda:	89 04 24             	mov    %eax,(%esp)
c002abdd:	e8 a9 8f ff ff       	call   c0023b8b <free>
  free (threads);
c002abe2:	8b 44 24 24          	mov    0x24(%esp),%eax
c002abe6:	89 04 24             	mov    %eax,(%esp)
c002abe9:	e8 9d 8f ff ff       	call   c0023b8b <free>
}
c002abee:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c002abf4:	5b                   	pop    %ebx
c002abf5:	5e                   	pop    %esi
c002abf6:	5f                   	pop    %edi
c002abf7:	5d                   	pop    %ebp
c002abf8:	c3                   	ret    

c002abf9 <test_alarm_single>:
{
c002abf9:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 1);
c002abfc:	ba 01 00 00 00       	mov    $0x1,%edx
c002ac01:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac06:	e8 c3 fc ff ff       	call   c002a8ce <test_sleep>
}
c002ac0b:	83 c4 0c             	add    $0xc,%esp
c002ac0e:	c3                   	ret    

c002ac0f <test_alarm_multiple>:
{
c002ac0f:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 7);
c002ac12:	ba 07 00 00 00       	mov    $0x7,%edx
c002ac17:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac1c:	e8 ad fc ff ff       	call   c002a8ce <test_sleep>
}
c002ac21:	83 c4 0c             	add    $0xc,%esp
c002ac24:	c3                   	ret    

c002ac25 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *test_) 
{
c002ac25:	55                   	push   %ebp
c002ac26:	57                   	push   %edi
c002ac27:	56                   	push   %esi
c002ac28:	53                   	push   %ebx
c002ac29:	83 ec 1c             	sub    $0x1c,%esp
c002ac2c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  struct sleep_test *test = test_;
  int i;

  /* Make sure we're at the beginning of a timer tick. */
  timer_sleep (1);
c002ac30:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c002ac37:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ac3e:	00 
c002ac3f:	e8 f4 95 ff ff       	call   c0024238 <timer_sleep>

  for (i = 1; i <= test->iterations; i++) 
c002ac44:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002ac48:	7e 56                	jle    c002aca0 <sleeper+0x7b>
c002ac4a:	bd 0a 00 00 00       	mov    $0xa,%ebp
c002ac4f:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c002ac56:	00 
    {
      int64_t sleep_until = test->start + i * 10;
c002ac57:	89 ee                	mov    %ebp,%esi
c002ac59:	89 ef                	mov    %ebp,%edi
c002ac5b:	c1 ff 1f             	sar    $0x1f,%edi
c002ac5e:	03 33                	add    (%ebx),%esi
c002ac60:	13 7b 04             	adc    0x4(%ebx),%edi
      timer_sleep (sleep_until - timer_ticks ());
c002ac63:	e8 88 95 ff ff       	call   c00241f0 <timer_ticks>
c002ac68:	29 c6                	sub    %eax,%esi
c002ac6a:	19 d7                	sbb    %edx,%edi
c002ac6c:	89 34 24             	mov    %esi,(%esp)
c002ac6f:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ac73:	e8 c0 95 ff ff       	call   c0024238 <timer_sleep>
      *test->output_pos++ = timer_ticks () - test->start;
c002ac78:	8b 73 0c             	mov    0xc(%ebx),%esi
c002ac7b:	8d 46 04             	lea    0x4(%esi),%eax
c002ac7e:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ac81:	e8 6a 95 ff ff       	call   c00241f0 <timer_ticks>
c002ac86:	2b 03                	sub    (%ebx),%eax
c002ac88:	89 06                	mov    %eax,(%esi)
      thread_yield ();
c002ac8a:	e8 f6 67 ff ff       	call   c0021485 <thread_yield>
  for (i = 1; i <= test->iterations; i++) 
c002ac8f:	83 44 24 0c 01       	addl   $0x1,0xc(%esp)
c002ac94:	83 c5 0a             	add    $0xa,%ebp
c002ac97:	8b 44 24 0c          	mov    0xc(%esp),%eax
c002ac9b:	39 43 08             	cmp    %eax,0x8(%ebx)
c002ac9e:	7d b7                	jge    c002ac57 <sleeper+0x32>
    }
}
c002aca0:	83 c4 1c             	add    $0x1c,%esp
c002aca3:	5b                   	pop    %ebx
c002aca4:	5e                   	pop    %esi
c002aca5:	5f                   	pop    %edi
c002aca6:	5d                   	pop    %ebp
c002aca7:	c3                   	ret    

c002aca8 <test_alarm_simultaneous>:
{
c002aca8:	55                   	push   %ebp
c002aca9:	57                   	push   %edi
c002acaa:	56                   	push   %esi
c002acab:	53                   	push   %ebx
c002acac:	83 ec 4c             	sub    $0x4c,%esp
  ASSERT (!thread_mlfqs);
c002acaf:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002acb6:	74 2c                	je     c002ace4 <test_alarm_simultaneous+0x3c>
c002acb8:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002acbf:	c0 
c002acc0:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002acc7:	c0 
c002acc8:	c7 44 24 08 03 df 02 	movl   $0xc002df03,0x8(%esp)
c002accf:	c0 
c002acd0:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002acd7:	00 
c002acd8:	c7 04 24 a4 02 03 c0 	movl   $0xc00302a4,(%esp)
c002acdf:	e8 7f dc ff ff       	call   c0028963 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002ace4:	c7 44 24 08 05 00 00 	movl   $0x5,0x8(%esp)
c002aceb:	00 
c002acec:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c002acf3:	00 
c002acf4:	c7 04 24 10 01 03 c0 	movl   $0xc0030110,(%esp)
c002acfb:	e8 1d fa ff ff       	call   c002a71d <msg>
  msg ("Each thread sleeps 10 ticks each time.");
c002ad00:	c7 04 24 d0 02 03 c0 	movl   $0xc00302d0,(%esp)
c002ad07:	e8 11 fa ff ff       	call   c002a71d <msg>
  msg ("Within an iteration, all threads should wake up on the same tick.");
c002ad0c:	c7 04 24 f8 02 03 c0 	movl   $0xc00302f8,(%esp)
c002ad13:	e8 05 fa ff ff       	call   c002a71d <msg>
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002ad18:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
c002ad1f:	e8 e0 8c ff ff       	call   c0023a04 <malloc>
c002ad24:	89 c3                	mov    %eax,%ebx
  if (output == NULL)
c002ad26:	85 c0                	test   %eax,%eax
c002ad28:	75 24                	jne    c002ad4e <test_alarm_simultaneous+0xa6>
    PANIC ("couldn't allocate memory for test");
c002ad2a:	c7 44 24 0c f4 01 03 	movl   $0xc00301f4,0xc(%esp)
c002ad31:	c0 
c002ad32:	c7 44 24 08 03 df 02 	movl   $0xc002df03,0x8(%esp)
c002ad39:	c0 
c002ad3a:	c7 44 24 04 31 00 00 	movl   $0x31,0x4(%esp)
c002ad41:	00 
c002ad42:	c7 04 24 a4 02 03 c0 	movl   $0xc00302a4,(%esp)
c002ad49:	e8 15 dc ff ff       	call   c0028963 <debug_panic>
  test.start = timer_ticks () + 100;
c002ad4e:	e8 9d 94 ff ff       	call   c00241f0 <timer_ticks>
c002ad53:	83 c0 64             	add    $0x64,%eax
c002ad56:	83 d2 00             	adc    $0x0,%edx
c002ad59:	89 44 24 20          	mov    %eax,0x20(%esp)
c002ad5d:	89 54 24 24          	mov    %edx,0x24(%esp)
  test.iterations = iterations;
c002ad61:	c7 44 24 28 05 00 00 	movl   $0x5,0x28(%esp)
c002ad68:	00 
  test.output_pos = output;
c002ad69:	89 5c 24 2c          	mov    %ebx,0x2c(%esp)
c002ad6d:	be 00 00 00 00       	mov    $0x0,%esi
      snprintf (name, sizeof name, "thread %d", i);
c002ad72:	8d 7c 24 30          	lea    0x30(%esp),%edi
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002ad76:	8d 6c 24 20          	lea    0x20(%esp),%ebp
      snprintf (name, sizeof name, "thread %d", i);
c002ad7a:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ad7e:	c7 44 24 08 c5 00 03 	movl   $0xc00300c5,0x8(%esp)
c002ad85:	c0 
c002ad86:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002ad8d:	00 
c002ad8e:	89 3c 24             	mov    %edi,(%esp)
c002ad91:	e8 79 c4 ff ff       	call   c002720f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002ad96:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c002ad9a:	c7 44 24 08 25 ac 02 	movl   $0xc002ac25,0x8(%esp)
c002ada1:	c0 
c002ada2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002ada9:	00 
c002adaa:	89 3c 24             	mov    %edi,(%esp)
c002adad:	e8 75 67 ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < thread_cnt; i++)
c002adb2:	83 c6 01             	add    $0x1,%esi
c002adb5:	83 fe 03             	cmp    $0x3,%esi
c002adb8:	75 c0                	jne    c002ad7a <test_alarm_simultaneous+0xd2>
  timer_sleep (100 + iterations * 10 + 100);
c002adba:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002adc1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002adc8:	00 
c002adc9:	e8 6a 94 ff ff       	call   c0024238 <timer_sleep>
  msg ("iteration 0, thread 0: woke up after %d ticks", output[0]);
c002adce:	8b 03                	mov    (%ebx),%eax
c002add0:	89 44 24 04          	mov    %eax,0x4(%esp)
c002add4:	c7 04 24 3c 03 03 c0 	movl   $0xc003033c,(%esp)
c002addb:	e8 3d f9 ff ff       	call   c002a71d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ade0:	89 df                	mov    %ebx,%edi
c002ade2:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ade6:	29 d8                	sub    %ebx,%eax
c002ade8:	83 f8 07             	cmp    $0x7,%eax
c002adeb:	7e 4a                	jle    c002ae37 <test_alarm_simultaneous+0x18f>
c002aded:	66 be 01 00          	mov    $0x1,%si
    msg ("iteration %d, thread %d: woke up %d ticks later",
c002adf1:	bd 56 55 55 55       	mov    $0x55555556,%ebp
c002adf6:	8b 04 b3             	mov    (%ebx,%esi,4),%eax
c002adf9:	2b 44 b3 fc          	sub    -0x4(%ebx,%esi,4),%eax
c002adfd:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ae01:	89 f0                	mov    %esi,%eax
c002ae03:	f7 ed                	imul   %ebp
c002ae05:	89 f0                	mov    %esi,%eax
c002ae07:	c1 f8 1f             	sar    $0x1f,%eax
c002ae0a:	29 c2                	sub    %eax,%edx
c002ae0c:	8d 04 52             	lea    (%edx,%edx,2),%eax
c002ae0f:	89 f1                	mov    %esi,%ecx
c002ae11:	29 c1                	sub    %eax,%ecx
c002ae13:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002ae17:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ae1b:	c7 04 24 6c 03 03 c0 	movl   $0xc003036c,(%esp)
c002ae22:	e8 f6 f8 ff ff       	call   c002a71d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae27:	83 c6 01             	add    $0x1,%esi
c002ae2a:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae2e:	29 f8                	sub    %edi,%eax
c002ae30:	c1 f8 02             	sar    $0x2,%eax
c002ae33:	39 c6                	cmp    %eax,%esi
c002ae35:	7c bf                	jl     c002adf6 <test_alarm_simultaneous+0x14e>
  free (output);
c002ae37:	89 1c 24             	mov    %ebx,(%esp)
c002ae3a:	e8 4c 8d ff ff       	call   c0023b8b <free>
}
c002ae3f:	83 c4 4c             	add    $0x4c,%esp
c002ae42:	5b                   	pop    %ebx
c002ae43:	5e                   	pop    %esi
c002ae44:	5f                   	pop    %edi
c002ae45:	5d                   	pop    %ebp
c002ae46:	c3                   	ret    

c002ae47 <alarm_priority_thread>:
    sema_down (&wait_sema);
}

static void
alarm_priority_thread (void *aux UNUSED) 
{
c002ae47:	57                   	push   %edi
c002ae48:	56                   	push   %esi
c002ae49:	83 ec 14             	sub    $0x14,%esp
  /* Busy-wait until the current time changes. */
  int64_t start_time = timer_ticks ();
c002ae4c:	e8 9f 93 ff ff       	call   c00241f0 <timer_ticks>
c002ae51:	89 c6                	mov    %eax,%esi
c002ae53:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) == 0)
c002ae55:	89 34 24             	mov    %esi,(%esp)
c002ae58:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ae5c:	e8 bb 93 ff ff       	call   c002421c <timer_elapsed>
c002ae61:	09 c2                	or     %eax,%edx
c002ae63:	74 f0                	je     c002ae55 <alarm_priority_thread+0xe>
    continue;

  /* Now we know we're at the very beginning of a timer tick, so
     we can call timer_sleep() without worrying about races
     between checking the time and a timer interrupt. */
  timer_sleep (wake_time - timer_ticks ());
c002ae65:	8b 35 40 7b 03 c0    	mov    0xc0037b40,%esi
c002ae6b:	8b 3d 44 7b 03 c0    	mov    0xc0037b44,%edi
c002ae71:	e8 7a 93 ff ff       	call   c00241f0 <timer_ticks>
c002ae76:	29 c6                	sub    %eax,%esi
c002ae78:	19 d7                	sbb    %edx,%edi
c002ae7a:	89 34 24             	mov    %esi,(%esp)
c002ae7d:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ae81:	e8 b2 93 ff ff       	call   c0024238 <timer_sleep>

  /* Print a message on wake-up. */
  msg ("Thread %s woke up.", thread_name ());
c002ae86:	e8 12 60 ff ff       	call   c0020e9d <thread_name>
c002ae8b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ae8f:	c7 04 24 9c 03 03 c0 	movl   $0xc003039c,(%esp)
c002ae96:	e8 82 f8 ff ff       	call   c002a71d <msg>

  sema_up (&wait_sema);
c002ae9b:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002aea2:	e8 80 7d ff ff       	call   c0022c27 <sema_up>
}
c002aea7:	83 c4 14             	add    $0x14,%esp
c002aeaa:	5e                   	pop    %esi
c002aeab:	5f                   	pop    %edi
c002aeac:	c3                   	ret    

c002aead <test_alarm_priority>:
{
c002aead:	55                   	push   %ebp
c002aeae:	57                   	push   %edi
c002aeaf:	56                   	push   %esi
c002aeb0:	53                   	push   %ebx
c002aeb1:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002aeb4:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002aebb:	74 2c                	je     c002aee9 <test_alarm_priority+0x3c>
c002aebd:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002aec4:	c0 
c002aec5:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002aecc:	c0 
c002aecd:	c7 44 24 08 0e df 02 	movl   $0xc002df0e,0x8(%esp)
c002aed4:	c0 
c002aed5:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002aedc:	00 
c002aedd:	c7 04 24 bc 03 03 c0 	movl   $0xc00303bc,(%esp)
c002aee4:	e8 7a da ff ff       	call   c0028963 <debug_panic>
  wake_time = timer_ticks () + 5 * TIMER_FREQ;
c002aee9:	e8 02 93 ff ff       	call   c00241f0 <timer_ticks>
c002aeee:	05 f4 01 00 00       	add    $0x1f4,%eax
c002aef3:	83 d2 00             	adc    $0x0,%edx
c002aef6:	a3 40 7b 03 c0       	mov    %eax,0xc0037b40
c002aefb:	89 15 44 7b 03 c0    	mov    %edx,0xc0037b44
  sema_init (&wait_sema, 0);
c002af01:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002af08:	00 
c002af09:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002af10:	e8 b1 7b ff ff       	call   c0022ac6 <sema_init>
c002af15:	bb 05 00 00 00       	mov    $0x5,%ebx
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af1a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002af1f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af23:	89 d8                	mov    %ebx,%eax
c002af25:	f7 ed                	imul   %ebp
c002af27:	c1 fa 02             	sar    $0x2,%edx
c002af2a:	89 d8                	mov    %ebx,%eax
c002af2c:	c1 f8 1f             	sar    $0x1f,%eax
c002af2f:	29 c2                	sub    %eax,%edx
c002af31:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002af34:	01 c0                	add    %eax,%eax
c002af36:	29 d8                	sub    %ebx,%eax
c002af38:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002af3b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002af3f:	c7 44 24 08 af 03 03 	movl   $0xc00303af,0x8(%esp)
c002af46:	c0 
c002af47:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002af4e:	00 
c002af4f:	89 3c 24             	mov    %edi,(%esp)
c002af52:	e8 b8 c2 ff ff       	call   c002720f <snprintf>
      thread_create (name, priority, alarm_priority_thread, NULL);
c002af57:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002af5e:	00 
c002af5f:	c7 44 24 08 47 ae 02 	movl   $0xc002ae47,0x8(%esp)
c002af66:	c0 
c002af67:	89 74 24 04          	mov    %esi,0x4(%esp)
c002af6b:	89 3c 24             	mov    %edi,(%esp)
c002af6e:	e8 b4 65 ff ff       	call   c0021527 <thread_create>
c002af73:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002af76:	83 fb 0f             	cmp    $0xf,%ebx
c002af79:	75 a8                	jne    c002af23 <test_alarm_priority+0x76>
  thread_set_priority (PRI_MIN);
c002af7b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002af82:	e8 0e 67 ff ff       	call   c0021695 <thread_set_priority>
c002af87:	b3 0a                	mov    $0xa,%bl
    sema_down (&wait_sema);
c002af89:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002af90:	e8 7d 7b ff ff       	call   c0022b12 <sema_down>
  for (i = 0; i < 10; i++)
c002af95:	83 eb 01             	sub    $0x1,%ebx
c002af98:	75 ef                	jne    c002af89 <test_alarm_priority+0xdc>
}
c002af9a:	83 c4 3c             	add    $0x3c,%esp
c002af9d:	5b                   	pop    %ebx
c002af9e:	5e                   	pop    %esi
c002af9f:	5f                   	pop    %edi
c002afa0:	5d                   	pop    %ebp
c002afa1:	c3                   	ret    

c002afa2 <test_alarm_zero>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_zero (void) 
{
c002afa2:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (0);
c002afa5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002afac:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002afb3:	00 
c002afb4:	e8 7f 92 ff ff       	call   c0024238 <timer_sleep>
  pass ();
c002afb9:	e8 73 f8 ff ff       	call   c002a831 <pass>
}
c002afbe:	83 c4 1c             	add    $0x1c,%esp
c002afc1:	c3                   	ret    

c002afc2 <test_alarm_negative>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_negative (void) 
{
c002afc2:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (-100);
c002afc5:	c7 04 24 9c ff ff ff 	movl   $0xffffff9c,(%esp)
c002afcc:	c7 44 24 04 ff ff ff 	movl   $0xffffffff,0x4(%esp)
c002afd3:	ff 
c002afd4:	e8 5f 92 ff ff       	call   c0024238 <timer_sleep>
  pass ();
c002afd9:	e8 53 f8 ff ff       	call   c002a831 <pass>
}
c002afde:	83 c4 1c             	add    $0x1c,%esp
c002afe1:	c3                   	ret    

c002afe2 <changing_thread>:
  msg ("Thread 2 should have just exited.");
}

static void
changing_thread (void *aux UNUSED) 
{
c002afe2:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread 2 now lowering priority.");
c002afe5:	c7 04 24 e4 03 03 c0 	movl   $0xc00303e4,(%esp)
c002afec:	e8 2c f7 ff ff       	call   c002a71d <msg>
  thread_set_priority (PRI_DEFAULT - 1);
c002aff1:	c7 04 24 1e 00 00 00 	movl   $0x1e,(%esp)
c002aff8:	e8 98 66 ff ff       	call   c0021695 <thread_set_priority>
  msg ("Thread 2 exiting.");
c002affd:	c7 04 24 a2 04 03 c0 	movl   $0xc00304a2,(%esp)
c002b004:	e8 14 f7 ff ff       	call   c002a71d <msg>
}
c002b009:	83 c4 1c             	add    $0x1c,%esp
c002b00c:	c3                   	ret    

c002b00d <test_priority_change>:
{
c002b00d:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002b010:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b017:	74 2c                	je     c002b045 <test_priority_change+0x38>
c002b019:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002b020:	c0 
c002b021:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b028:	c0 
c002b029:	c7 44 24 08 22 df 02 	movl   $0xc002df22,0x8(%esp)
c002b030:	c0 
c002b031:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002b038:	00 
c002b039:	c7 04 24 04 04 03 c0 	movl   $0xc0030404,(%esp)
c002b040:	e8 1e d9 ff ff       	call   c0028963 <debug_panic>
  msg ("Creating a high-priority thread 2.");
c002b045:	c7 04 24 2c 04 03 c0 	movl   $0xc003042c,(%esp)
c002b04c:	e8 cc f6 ff ff       	call   c002a71d <msg>
  thread_create ("thread 2", PRI_DEFAULT + 1, changing_thread, NULL);
c002b051:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b058:	00 
c002b059:	c7 44 24 08 e2 af 02 	movl   $0xc002afe2,0x8(%esp)
c002b060:	c0 
c002b061:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b068:	00 
c002b069:	c7 04 24 b4 04 03 c0 	movl   $0xc00304b4,(%esp)
c002b070:	e8 b2 64 ff ff       	call   c0021527 <thread_create>
  msg ("Thread 2 should have just lowered its priority.");
c002b075:	c7 04 24 50 04 03 c0 	movl   $0xc0030450,(%esp)
c002b07c:	e8 9c f6 ff ff       	call   c002a71d <msg>
  thread_set_priority (PRI_DEFAULT - 2);
c002b081:	c7 04 24 1d 00 00 00 	movl   $0x1d,(%esp)
c002b088:	e8 08 66 ff ff       	call   c0021695 <thread_set_priority>
  msg ("Thread 2 should have just exited.");
c002b08d:	c7 04 24 80 04 03 c0 	movl   $0xc0030480,(%esp)
c002b094:	e8 84 f6 ff ff       	call   c002a71d <msg>
}
c002b099:	83 c4 2c             	add    $0x2c,%esp
c002b09c:	c3                   	ret    

c002b09d <acquire2_thread_func>:
  msg ("acquire1: done");
}

static void
acquire2_thread_func (void *lock_) 
{
c002b09d:	53                   	push   %ebx
c002b09e:	83 ec 18             	sub    $0x18,%esp
c002b0a1:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b0a5:	89 1c 24             	mov    %ebx,(%esp)
c002b0a8:	e8 8d 7d ff ff       	call   c0022e3a <lock_acquire>
  msg ("acquire2: got the lock");
c002b0ad:	c7 04 24 bd 04 03 c0 	movl   $0xc00304bd,(%esp)
c002b0b4:	e8 64 f6 ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002b0b9:	89 1c 24             	mov    %ebx,(%esp)
c002b0bc:	e8 43 7f ff ff       	call   c0023004 <lock_release>
  msg ("acquire2: done");
c002b0c1:	c7 04 24 d4 04 03 c0 	movl   $0xc00304d4,(%esp)
c002b0c8:	e8 50 f6 ff ff       	call   c002a71d <msg>
}
c002b0cd:	83 c4 18             	add    $0x18,%esp
c002b0d0:	5b                   	pop    %ebx
c002b0d1:	c3                   	ret    

c002b0d2 <acquire1_thread_func>:
{
c002b0d2:	53                   	push   %ebx
c002b0d3:	83 ec 18             	sub    $0x18,%esp
c002b0d6:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b0da:	89 1c 24             	mov    %ebx,(%esp)
c002b0dd:	e8 58 7d ff ff       	call   c0022e3a <lock_acquire>
  msg ("acquire1: got the lock");
c002b0e2:	c7 04 24 e3 04 03 c0 	movl   $0xc00304e3,(%esp)
c002b0e9:	e8 2f f6 ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002b0ee:	89 1c 24             	mov    %ebx,(%esp)
c002b0f1:	e8 0e 7f ff ff       	call   c0023004 <lock_release>
  msg ("acquire1: done");
c002b0f6:	c7 04 24 fa 04 03 c0 	movl   $0xc00304fa,(%esp)
c002b0fd:	e8 1b f6 ff ff       	call   c002a71d <msg>
}
c002b102:	83 c4 18             	add    $0x18,%esp
c002b105:	5b                   	pop    %ebx
c002b106:	c3                   	ret    

c002b107 <test_priority_donate_one>:
{
c002b107:	53                   	push   %ebx
c002b108:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002b10b:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b112:	74 2c                	je     c002b140 <test_priority_donate_one+0x39>
c002b114:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002b11b:	c0 
c002b11c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b123:	c0 
c002b124:	c7 44 24 08 37 df 02 	movl   $0xc002df37,0x8(%esp)
c002b12b:	c0 
c002b12c:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b133:	00 
c002b134:	c7 04 24 1c 05 03 c0 	movl   $0xc003051c,(%esp)
c002b13b:	e8 23 d8 ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b140:	e8 f5 5d ff ff       	call   c0020f3a <thread_get_priority>
c002b145:	83 f8 1f             	cmp    $0x1f,%eax
c002b148:	74 2c                	je     c002b176 <test_priority_donate_one+0x6f>
c002b14a:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002b151:	c0 
c002b152:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b159:	c0 
c002b15a:	c7 44 24 08 37 df 02 	movl   $0xc002df37,0x8(%esp)
c002b161:	c0 
c002b162:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b169:	00 
c002b16a:	c7 04 24 1c 05 03 c0 	movl   $0xc003051c,(%esp)
c002b171:	e8 ed d7 ff ff       	call   c0028963 <debug_panic>
  lock_init (&lock);
c002b176:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002b17a:	89 1c 24             	mov    %ebx,(%esp)
c002b17d:	e8 1b 7c ff ff       	call   c0022d9d <lock_init>
  lock_acquire (&lock);
c002b182:	89 1c 24             	mov    %ebx,(%esp)
c002b185:	e8 b0 7c ff ff       	call   c0022e3a <lock_acquire>
  thread_create ("acquire1", PRI_DEFAULT + 1, acquire1_thread_func, &lock);
c002b18a:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b18e:	c7 44 24 08 d2 b0 02 	movl   $0xc002b0d2,0x8(%esp)
c002b195:	c0 
c002b196:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b19d:	00 
c002b19e:	c7 04 24 09 05 03 c0 	movl   $0xc0030509,(%esp)
c002b1a5:	e8 7d 63 ff ff       	call   c0021527 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b1aa:	e8 8b 5d ff ff       	call   c0020f3a <thread_get_priority>
c002b1af:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b1b3:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b1ba:	00 
c002b1bb:	c7 04 24 70 05 03 c0 	movl   $0xc0030570,(%esp)
c002b1c2:	e8 56 f5 ff ff       	call   c002a71d <msg>
  thread_create ("acquire2", PRI_DEFAULT + 2, acquire2_thread_func, &lock);
c002b1c7:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b1cb:	c7 44 24 08 9d b0 02 	movl   $0xc002b09d,0x8(%esp)
c002b1d2:	c0 
c002b1d3:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b1da:	00 
c002b1db:	c7 04 24 12 05 03 c0 	movl   $0xc0030512,(%esp)
c002b1e2:	e8 40 63 ff ff       	call   c0021527 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b1e7:	e8 4e 5d ff ff       	call   c0020f3a <thread_get_priority>
c002b1ec:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b1f0:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b1f7:	00 
c002b1f8:	c7 04 24 70 05 03 c0 	movl   $0xc0030570,(%esp)
c002b1ff:	e8 19 f5 ff ff       	call   c002a71d <msg>
  lock_release (&lock);
c002b204:	89 1c 24             	mov    %ebx,(%esp)
c002b207:	e8 f8 7d ff ff       	call   c0023004 <lock_release>
  msg ("acquire2, acquire1 must already have finished, in that order.");
c002b20c:	c7 04 24 ac 05 03 c0 	movl   $0xc00305ac,(%esp)
c002b213:	e8 05 f5 ff ff       	call   c002a71d <msg>
  msg ("This should be the last line before finishing this test.");
c002b218:	c7 04 24 ec 05 03 c0 	movl   $0xc00305ec,(%esp)
c002b21f:	e8 f9 f4 ff ff       	call   c002a71d <msg>
}
c002b224:	83 c4 58             	add    $0x58,%esp
c002b227:	5b                   	pop    %ebx
c002b228:	c3                   	ret    

c002b229 <b_thread_func>:
  msg ("Thread a finished.");
}

static void
b_thread_func (void *lock_) 
{
c002b229:	53                   	push   %ebx
c002b22a:	83 ec 18             	sub    $0x18,%esp
c002b22d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b231:	89 1c 24             	mov    %ebx,(%esp)
c002b234:	e8 01 7c ff ff       	call   c0022e3a <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b239:	c7 04 24 25 06 03 c0 	movl   $0xc0030625,(%esp)
c002b240:	e8 d8 f4 ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002b245:	89 1c 24             	mov    %ebx,(%esp)
c002b248:	e8 b7 7d ff ff       	call   c0023004 <lock_release>
  msg ("Thread b finished.");
c002b24d:	c7 04 24 3f 06 03 c0 	movl   $0xc003063f,(%esp)
c002b254:	e8 c4 f4 ff ff       	call   c002a71d <msg>
}
c002b259:	83 c4 18             	add    $0x18,%esp
c002b25c:	5b                   	pop    %ebx
c002b25d:	c3                   	ret    

c002b25e <a_thread_func>:
{
c002b25e:	53                   	push   %ebx
c002b25f:	83 ec 18             	sub    $0x18,%esp
c002b262:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b266:	89 1c 24             	mov    %ebx,(%esp)
c002b269:	e8 cc 7b ff ff       	call   c0022e3a <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b26e:	c7 04 24 52 06 03 c0 	movl   $0xc0030652,(%esp)
c002b275:	e8 a3 f4 ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002b27a:	89 1c 24             	mov    %ebx,(%esp)
c002b27d:	e8 82 7d ff ff       	call   c0023004 <lock_release>
  msg ("Thread a finished.");
c002b282:	c7 04 24 6c 06 03 c0 	movl   $0xc003066c,(%esp)
c002b289:	e8 8f f4 ff ff       	call   c002a71d <msg>
}
c002b28e:	83 c4 18             	add    $0x18,%esp
c002b291:	5b                   	pop    %ebx
c002b292:	c3                   	ret    

c002b293 <test_priority_donate_multiple>:
{
c002b293:	56                   	push   %esi
c002b294:	53                   	push   %ebx
c002b295:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b298:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b29f:	74 2c                	je     c002b2cd <test_priority_donate_multiple+0x3a>
c002b2a1:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002b2a8:	c0 
c002b2a9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b2b0:	c0 
c002b2b1:	c7 44 24 08 50 df 02 	movl   $0xc002df50,0x8(%esp)
c002b2b8:	c0 
c002b2b9:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b2c0:	00 
c002b2c1:	c7 04 24 80 06 03 c0 	movl   $0xc0030680,(%esp)
c002b2c8:	e8 96 d6 ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b2cd:	e8 68 5c ff ff       	call   c0020f3a <thread_get_priority>
c002b2d2:	83 f8 1f             	cmp    $0x1f,%eax
c002b2d5:	74 2c                	je     c002b303 <test_priority_donate_multiple+0x70>
c002b2d7:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002b2de:	c0 
c002b2df:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b2e6:	c0 
c002b2e7:	c7 44 24 08 50 df 02 	movl   $0xc002df50,0x8(%esp)
c002b2ee:	c0 
c002b2ef:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b2f6:	00 
c002b2f7:	c7 04 24 80 06 03 c0 	movl   $0xc0030680,(%esp)
c002b2fe:	e8 60 d6 ff ff       	call   c0028963 <debug_panic>
  lock_init (&a);
c002b303:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b307:	89 1c 24             	mov    %ebx,(%esp)
c002b30a:	e8 8e 7a ff ff       	call   c0022d9d <lock_init>
  lock_init (&b);
c002b30f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b313:	89 34 24             	mov    %esi,(%esp)
c002b316:	e8 82 7a ff ff       	call   c0022d9d <lock_init>
  lock_acquire (&a);
c002b31b:	89 1c 24             	mov    %ebx,(%esp)
c002b31e:	e8 17 7b ff ff       	call   c0022e3a <lock_acquire>
  lock_acquire (&b);
c002b323:	89 34 24             	mov    %esi,(%esp)
c002b326:	e8 0f 7b ff ff       	call   c0022e3a <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 1, a_thread_func, &a);
c002b32b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b32f:	c7 44 24 08 5e b2 02 	movl   $0xc002b25e,0x8(%esp)
c002b336:	c0 
c002b337:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b33e:	00 
c002b33f:	c7 04 24 1f f2 02 c0 	movl   $0xc002f21f,(%esp)
c002b346:	e8 dc 61 ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b34b:	e8 ea 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b350:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b354:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b35b:	00 
c002b35c:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b363:	e8 b5 f3 ff ff       	call   c002a71d <msg>
  thread_create ("b", PRI_DEFAULT + 2, b_thread_func, &b);
c002b368:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b36c:	c7 44 24 08 29 b2 02 	movl   $0xc002b229,0x8(%esp)
c002b373:	c0 
c002b374:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b37b:	00 
c002b37c:	c7 04 24 e9 fb 02 c0 	movl   $0xc002fbe9,(%esp)
c002b383:	e8 9f 61 ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b388:	e8 ad 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b38d:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b391:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b398:	00 
c002b399:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b3a0:	e8 78 f3 ff ff       	call   c002a71d <msg>
  lock_release (&b);
c002b3a5:	89 34 24             	mov    %esi,(%esp)
c002b3a8:	e8 57 7c ff ff       	call   c0023004 <lock_release>
  msg ("Thread b should have just finished.");
c002b3ad:	c7 04 24 ec 06 03 c0 	movl   $0xc00306ec,(%esp)
c002b3b4:	e8 64 f3 ff ff       	call   c002a71d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3b9:	e8 7c 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b3be:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3c2:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b3c9:	00 
c002b3ca:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b3d1:	e8 47 f3 ff ff       	call   c002a71d <msg>
  lock_release (&a);
c002b3d6:	89 1c 24             	mov    %ebx,(%esp)
c002b3d9:	e8 26 7c ff ff       	call   c0023004 <lock_release>
  msg ("Thread a should have just finished.");
c002b3de:	c7 04 24 10 07 03 c0 	movl   $0xc0030710,(%esp)
c002b3e5:	e8 33 f3 ff ff       	call   c002a71d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3ea:	e8 4b 5b ff ff       	call   c0020f3a <thread_get_priority>
c002b3ef:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3f3:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b3fa:	00 
c002b3fb:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b402:	e8 16 f3 ff ff       	call   c002a71d <msg>
}
c002b407:	83 c4 74             	add    $0x74,%esp
c002b40a:	5b                   	pop    %ebx
c002b40b:	5e                   	pop    %esi
c002b40c:	c3                   	ret    

c002b40d <c_thread_func>:
  msg ("Thread b finished.");
}

static void
c_thread_func (void *a_ UNUSED) 
{
c002b40d:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread c finished.");
c002b410:	c7 04 24 34 07 03 c0 	movl   $0xc0030734,(%esp)
c002b417:	e8 01 f3 ff ff       	call   c002a71d <msg>
}
c002b41c:	83 c4 1c             	add    $0x1c,%esp
c002b41f:	c3                   	ret    

c002b420 <b_thread_func>:
{
c002b420:	53                   	push   %ebx
c002b421:	83 ec 18             	sub    $0x18,%esp
c002b424:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b428:	89 1c 24             	mov    %ebx,(%esp)
c002b42b:	e8 0a 7a ff ff       	call   c0022e3a <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b430:	c7 04 24 25 06 03 c0 	movl   $0xc0030625,(%esp)
c002b437:	e8 e1 f2 ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002b43c:	89 1c 24             	mov    %ebx,(%esp)
c002b43f:	e8 c0 7b ff ff       	call   c0023004 <lock_release>
  msg ("Thread b finished.");
c002b444:	c7 04 24 3f 06 03 c0 	movl   $0xc003063f,(%esp)
c002b44b:	e8 cd f2 ff ff       	call   c002a71d <msg>
}
c002b450:	83 c4 18             	add    $0x18,%esp
c002b453:	5b                   	pop    %ebx
c002b454:	c3                   	ret    

c002b455 <a_thread_func>:
{
c002b455:	53                   	push   %ebx
c002b456:	83 ec 18             	sub    $0x18,%esp
c002b459:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b45d:	89 1c 24             	mov    %ebx,(%esp)
c002b460:	e8 d5 79 ff ff       	call   c0022e3a <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b465:	c7 04 24 52 06 03 c0 	movl   $0xc0030652,(%esp)
c002b46c:	e8 ac f2 ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002b471:	89 1c 24             	mov    %ebx,(%esp)
c002b474:	e8 8b 7b ff ff       	call   c0023004 <lock_release>
  msg ("Thread a finished.");
c002b479:	c7 04 24 6c 06 03 c0 	movl   $0xc003066c,(%esp)
c002b480:	e8 98 f2 ff ff       	call   c002a71d <msg>
}
c002b485:	83 c4 18             	add    $0x18,%esp
c002b488:	5b                   	pop    %ebx
c002b489:	c3                   	ret    

c002b48a <test_priority_donate_multiple2>:
{
c002b48a:	56                   	push   %esi
c002b48b:	53                   	push   %ebx
c002b48c:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b48f:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b496:	74 2c                	je     c002b4c4 <test_priority_donate_multiple2+0x3a>
c002b498:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002b49f:	c0 
c002b4a0:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b4a7:	c0 
c002b4a8:	c7 44 24 08 70 df 02 	movl   $0xc002df70,0x8(%esp)
c002b4af:	c0 
c002b4b0:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b4b7:	00 
c002b4b8:	c7 04 24 48 07 03 c0 	movl   $0xc0030748,(%esp)
c002b4bf:	e8 9f d4 ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b4c4:	e8 71 5a ff ff       	call   c0020f3a <thread_get_priority>
c002b4c9:	83 f8 1f             	cmp    $0x1f,%eax
c002b4cc:	74 2c                	je     c002b4fa <test_priority_donate_multiple2+0x70>
c002b4ce:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002b4d5:	c0 
c002b4d6:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b4dd:	c0 
c002b4de:	c7 44 24 08 70 df 02 	movl   $0xc002df70,0x8(%esp)
c002b4e5:	c0 
c002b4e6:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b4ed:	00 
c002b4ee:	c7 04 24 48 07 03 c0 	movl   $0xc0030748,(%esp)
c002b4f5:	e8 69 d4 ff ff       	call   c0028963 <debug_panic>
  lock_init (&a);
c002b4fa:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b4fe:	89 34 24             	mov    %esi,(%esp)
c002b501:	e8 97 78 ff ff       	call   c0022d9d <lock_init>
  lock_init (&b);
c002b506:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b50a:	89 1c 24             	mov    %ebx,(%esp)
c002b50d:	e8 8b 78 ff ff       	call   c0022d9d <lock_init>
  lock_acquire (&a);
c002b512:	89 34 24             	mov    %esi,(%esp)
c002b515:	e8 20 79 ff ff       	call   c0022e3a <lock_acquire>
  lock_acquire (&b);
c002b51a:	89 1c 24             	mov    %ebx,(%esp)
c002b51d:	e8 18 79 ff ff       	call   c0022e3a <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 3, a_thread_func, &a);
c002b522:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b526:	c7 44 24 08 55 b4 02 	movl   $0xc002b455,0x8(%esp)
c002b52d:	c0 
c002b52e:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b535:	00 
c002b536:	c7 04 24 1f f2 02 c0 	movl   $0xc002f21f,(%esp)
c002b53d:	e8 e5 5f ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b542:	e8 f3 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b547:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b54b:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b552:	00 
c002b553:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b55a:	e8 be f1 ff ff       	call   c002a71d <msg>
  thread_create ("c", PRI_DEFAULT + 1, c_thread_func, NULL);
c002b55f:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b566:	00 
c002b567:	c7 44 24 08 0d b4 02 	movl   $0xc002b40d,0x8(%esp)
c002b56e:	c0 
c002b56f:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b576:	00 
c002b577:	c7 04 24 0a f6 02 c0 	movl   $0xc002f60a,(%esp)
c002b57e:	e8 a4 5f ff ff       	call   c0021527 <thread_create>
  thread_create ("b", PRI_DEFAULT + 5, b_thread_func, &b);
c002b583:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b587:	c7 44 24 08 20 b4 02 	movl   $0xc002b420,0x8(%esp)
c002b58e:	c0 
c002b58f:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b596:	00 
c002b597:	c7 04 24 e9 fb 02 c0 	movl   $0xc002fbe9,(%esp)
c002b59e:	e8 84 5f ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5a3:	e8 92 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b5a8:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5ac:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5b3:	00 
c002b5b4:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b5bb:	e8 5d f1 ff ff       	call   c002a71d <msg>
  lock_release (&a);
c002b5c0:	89 34 24             	mov    %esi,(%esp)
c002b5c3:	e8 3c 7a ff ff       	call   c0023004 <lock_release>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5c8:	e8 6d 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b5cd:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5d1:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5d8:	00 
c002b5d9:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b5e0:	e8 38 f1 ff ff       	call   c002a71d <msg>
  lock_release (&b);
c002b5e5:	89 1c 24             	mov    %ebx,(%esp)
c002b5e8:	e8 17 7a ff ff       	call   c0023004 <lock_release>
  msg ("Threads b, a, c should have just finished, in that order.");
c002b5ed:	c7 04 24 78 07 03 c0 	movl   $0xc0030778,(%esp)
c002b5f4:	e8 24 f1 ff ff       	call   c002a71d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5f9:	e8 3c 59 ff ff       	call   c0020f3a <thread_get_priority>
c002b5fe:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b602:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b609:	00 
c002b60a:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002b611:	e8 07 f1 ff ff       	call   c002a71d <msg>
}
c002b616:	83 c4 74             	add    $0x74,%esp
c002b619:	5b                   	pop    %ebx
c002b61a:	5e                   	pop    %esi
c002b61b:	c3                   	ret    

c002b61c <high_thread_func>:
  msg ("Middle thread finished.");
}

static void
high_thread_func (void *lock_) 
{
c002b61c:	53                   	push   %ebx
c002b61d:	83 ec 18             	sub    $0x18,%esp
c002b620:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b624:	89 1c 24             	mov    %ebx,(%esp)
c002b627:	e8 0e 78 ff ff       	call   c0022e3a <lock_acquire>
  msg ("High thread got the lock.");
c002b62c:	c7 04 24 b2 07 03 c0 	movl   $0xc00307b2,(%esp)
c002b633:	e8 e5 f0 ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002b638:	89 1c 24             	mov    %ebx,(%esp)
c002b63b:	e8 c4 79 ff ff       	call   c0023004 <lock_release>
  msg ("High thread finished.");
c002b640:	c7 04 24 cc 07 03 c0 	movl   $0xc00307cc,(%esp)
c002b647:	e8 d1 f0 ff ff       	call   c002a71d <msg>
}
c002b64c:	83 c4 18             	add    $0x18,%esp
c002b64f:	5b                   	pop    %ebx
c002b650:	c3                   	ret    

c002b651 <medium_thread_func>:
{
c002b651:	53                   	push   %ebx
c002b652:	83 ec 18             	sub    $0x18,%esp
c002b655:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (locks->b);
c002b659:	8b 43 04             	mov    0x4(%ebx),%eax
c002b65c:	89 04 24             	mov    %eax,(%esp)
c002b65f:	e8 d6 77 ff ff       	call   c0022e3a <lock_acquire>
  lock_acquire (locks->a);
c002b664:	8b 03                	mov    (%ebx),%eax
c002b666:	89 04 24             	mov    %eax,(%esp)
c002b669:	e8 cc 77 ff ff       	call   c0022e3a <lock_acquire>
  msg ("Medium thread should have priority %d.  Actual priority: %d.",
c002b66e:	e8 c7 58 ff ff       	call   c0020f3a <thread_get_priority>
c002b673:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b677:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b67e:	00 
c002b67f:	c7 04 24 24 08 03 c0 	movl   $0xc0030824,(%esp)
c002b686:	e8 92 f0 ff ff       	call   c002a71d <msg>
  msg ("Medium thread got the lock.");
c002b68b:	c7 04 24 e2 07 03 c0 	movl   $0xc00307e2,(%esp)
c002b692:	e8 86 f0 ff ff       	call   c002a71d <msg>
  lock_release (locks->a);
c002b697:	8b 03                	mov    (%ebx),%eax
c002b699:	89 04 24             	mov    %eax,(%esp)
c002b69c:	e8 63 79 ff ff       	call   c0023004 <lock_release>
  thread_yield ();
c002b6a1:	e8 df 5d ff ff       	call   c0021485 <thread_yield>
  lock_release (locks->b);
c002b6a6:	8b 43 04             	mov    0x4(%ebx),%eax
c002b6a9:	89 04 24             	mov    %eax,(%esp)
c002b6ac:	e8 53 79 ff ff       	call   c0023004 <lock_release>
  thread_yield ();
c002b6b1:	e8 cf 5d ff ff       	call   c0021485 <thread_yield>
  msg ("High thread should have just finished.");
c002b6b6:	c7 04 24 64 08 03 c0 	movl   $0xc0030864,(%esp)
c002b6bd:	e8 5b f0 ff ff       	call   c002a71d <msg>
  msg ("Middle thread finished.");
c002b6c2:	c7 04 24 fe 07 03 c0 	movl   $0xc00307fe,(%esp)
c002b6c9:	e8 4f f0 ff ff       	call   c002a71d <msg>
}
c002b6ce:	83 c4 18             	add    $0x18,%esp
c002b6d1:	5b                   	pop    %ebx
c002b6d2:	c3                   	ret    

c002b6d3 <test_priority_donate_nest>:
{
c002b6d3:	56                   	push   %esi
c002b6d4:	53                   	push   %ebx
c002b6d5:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b6d8:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b6df:	74 2c                	je     c002b70d <test_priority_donate_nest+0x3a>
c002b6e1:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002b6e8:	c0 
c002b6e9:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b6f0:	c0 
c002b6f1:	c7 44 24 08 8f df 02 	movl   $0xc002df8f,0x8(%esp)
c002b6f8:	c0 
c002b6f9:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b700:	00 
c002b701:	c7 04 24 8c 08 03 c0 	movl   $0xc003088c,(%esp)
c002b708:	e8 56 d2 ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b70d:	e8 28 58 ff ff       	call   c0020f3a <thread_get_priority>
c002b712:	83 f8 1f             	cmp    $0x1f,%eax
c002b715:	74 2c                	je     c002b743 <test_priority_donate_nest+0x70>
c002b717:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002b71e:	c0 
c002b71f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b726:	c0 
c002b727:	c7 44 24 08 8f df 02 	movl   $0xc002df8f,0x8(%esp)
c002b72e:	c0 
c002b72f:	c7 44 24 04 25 00 00 	movl   $0x25,0x4(%esp)
c002b736:	00 
c002b737:	c7 04 24 8c 08 03 c0 	movl   $0xc003088c,(%esp)
c002b73e:	e8 20 d2 ff ff       	call   c0028963 <debug_panic>
  lock_init (&a);
c002b743:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b747:	89 1c 24             	mov    %ebx,(%esp)
c002b74a:	e8 4e 76 ff ff       	call   c0022d9d <lock_init>
  lock_init (&b);
c002b74f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b753:	89 34 24             	mov    %esi,(%esp)
c002b756:	e8 42 76 ff ff       	call   c0022d9d <lock_init>
  lock_acquire (&a);
c002b75b:	89 1c 24             	mov    %ebx,(%esp)
c002b75e:	e8 d7 76 ff ff       	call   c0022e3a <lock_acquire>
  locks.a = &a;
c002b763:	89 5c 24 20          	mov    %ebx,0x20(%esp)
  locks.b = &b;
c002b767:	89 74 24 24          	mov    %esi,0x24(%esp)
  thread_create ("medium", PRI_DEFAULT + 1, medium_thread_func, &locks);
c002b76b:	8d 44 24 20          	lea    0x20(%esp),%eax
c002b76f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002b773:	c7 44 24 08 51 b6 02 	movl   $0xc002b651,0x8(%esp)
c002b77a:	c0 
c002b77b:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b782:	00 
c002b783:	c7 04 24 16 08 03 c0 	movl   $0xc0030816,(%esp)
c002b78a:	e8 98 5d ff ff       	call   c0021527 <thread_create>
  thread_yield ();
c002b78f:	e8 f1 5c ff ff       	call   c0021485 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b794:	e8 a1 57 ff ff       	call   c0020f3a <thread_get_priority>
c002b799:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b79d:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b7a4:	00 
c002b7a5:	c7 04 24 b8 08 03 c0 	movl   $0xc00308b8,(%esp)
c002b7ac:	e8 6c ef ff ff       	call   c002a71d <msg>
  thread_create ("high", PRI_DEFAULT + 2, high_thread_func, &b);
c002b7b1:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b7b5:	c7 44 24 08 1c b6 02 	movl   $0xc002b61c,0x8(%esp)
c002b7bc:	c0 
c002b7bd:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b7c4:	00 
c002b7c5:	c7 04 24 1d 08 03 c0 	movl   $0xc003081d,(%esp)
c002b7cc:	e8 56 5d ff ff       	call   c0021527 <thread_create>
  thread_yield ();
c002b7d1:	e8 af 5c ff ff       	call   c0021485 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b7d6:	e8 5f 57 ff ff       	call   c0020f3a <thread_get_priority>
c002b7db:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b7df:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b7e6:	00 
c002b7e7:	c7 04 24 b8 08 03 c0 	movl   $0xc00308b8,(%esp)
c002b7ee:	e8 2a ef ff ff       	call   c002a71d <msg>
  lock_release (&a);
c002b7f3:	89 1c 24             	mov    %ebx,(%esp)
c002b7f6:	e8 09 78 ff ff       	call   c0023004 <lock_release>
  thread_yield ();
c002b7fb:	e8 85 5c ff ff       	call   c0021485 <thread_yield>
  msg ("Medium thread should just have finished.");
c002b800:	c7 04 24 f4 08 03 c0 	movl   $0xc00308f4,(%esp)
c002b807:	e8 11 ef ff ff       	call   c002a71d <msg>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b80c:	e8 29 57 ff ff       	call   c0020f3a <thread_get_priority>
c002b811:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b815:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b81c:	00 
c002b81d:	c7 04 24 b8 08 03 c0 	movl   $0xc00308b8,(%esp)
c002b824:	e8 f4 ee ff ff       	call   c002a71d <msg>
}
c002b829:	83 c4 74             	add    $0x74,%esp
c002b82c:	5b                   	pop    %ebx
c002b82d:	5e                   	pop    %esi
c002b82e:	c3                   	ret    

c002b82f <h_thread_func>:
  msg ("Thread M finished.");
}

static void
h_thread_func (void *ls_) 
{
c002b82f:	53                   	push   %ebx
c002b830:	83 ec 18             	sub    $0x18,%esp
c002b833:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock_and_sema *ls = ls_;

  lock_acquire (&ls->lock);
c002b837:	89 1c 24             	mov    %ebx,(%esp)
c002b83a:	e8 fb 75 ff ff       	call   c0022e3a <lock_acquire>
  msg ("Thread H acquired lock.");
c002b83f:	c7 04 24 1d 09 03 c0 	movl   $0xc003091d,(%esp)
c002b846:	e8 d2 ee ff ff       	call   c002a71d <msg>

  sema_up (&ls->sema);
c002b84b:	8d 43 24             	lea    0x24(%ebx),%eax
c002b84e:	89 04 24             	mov    %eax,(%esp)
c002b851:	e8 d1 73 ff ff       	call   c0022c27 <sema_up>
  lock_release (&ls->lock);
c002b856:	89 1c 24             	mov    %ebx,(%esp)
c002b859:	e8 a6 77 ff ff       	call   c0023004 <lock_release>
  msg ("Thread H finished.");
c002b85e:	c7 04 24 35 09 03 c0 	movl   $0xc0030935,(%esp)
c002b865:	e8 b3 ee ff ff       	call   c002a71d <msg>
}
c002b86a:	83 c4 18             	add    $0x18,%esp
c002b86d:	5b                   	pop    %ebx
c002b86e:	c3                   	ret    

c002b86f <m_thread_func>:
{
c002b86f:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&ls->sema);
c002b872:	8b 44 24 20          	mov    0x20(%esp),%eax
c002b876:	83 c0 24             	add    $0x24,%eax
c002b879:	89 04 24             	mov    %eax,(%esp)
c002b87c:	e8 91 72 ff ff       	call   c0022b12 <sema_down>
  msg ("Thread M finished.");
c002b881:	c7 04 24 48 09 03 c0 	movl   $0xc0030948,(%esp)
c002b888:	e8 90 ee ff ff       	call   c002a71d <msg>
}
c002b88d:	83 c4 1c             	add    $0x1c,%esp
c002b890:	c3                   	ret    

c002b891 <l_thread_func>:
{
c002b891:	53                   	push   %ebx
c002b892:	83 ec 18             	sub    $0x18,%esp
c002b895:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (&ls->lock);
c002b899:	89 1c 24             	mov    %ebx,(%esp)
c002b89c:	e8 99 75 ff ff       	call   c0022e3a <lock_acquire>
  msg ("Thread L acquired lock.");
c002b8a1:	c7 04 24 5b 09 03 c0 	movl   $0xc003095b,(%esp)
c002b8a8:	e8 70 ee ff ff       	call   c002a71d <msg>
  sema_down (&ls->sema);
c002b8ad:	8d 43 24             	lea    0x24(%ebx),%eax
c002b8b0:	89 04 24             	mov    %eax,(%esp)
c002b8b3:	e8 5a 72 ff ff       	call   c0022b12 <sema_down>
  msg ("Thread L downed semaphore.");
c002b8b8:	c7 04 24 73 09 03 c0 	movl   $0xc0030973,(%esp)
c002b8bf:	e8 59 ee ff ff       	call   c002a71d <msg>
  lock_release (&ls->lock);
c002b8c4:	89 1c 24             	mov    %ebx,(%esp)
c002b8c7:	e8 38 77 ff ff       	call   c0023004 <lock_release>
  msg ("Thread L finished.");
c002b8cc:	c7 04 24 8e 09 03 c0 	movl   $0xc003098e,(%esp)
c002b8d3:	e8 45 ee ff ff       	call   c002a71d <msg>
}
c002b8d8:	83 c4 18             	add    $0x18,%esp
c002b8db:	5b                   	pop    %ebx
c002b8dc:	c3                   	ret    

c002b8dd <test_priority_donate_sema>:
{
c002b8dd:	56                   	push   %esi
c002b8de:	53                   	push   %ebx
c002b8df:	83 ec 64             	sub    $0x64,%esp
  ASSERT (!thread_mlfqs);
c002b8e2:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002b8e9:	74 2c                	je     c002b917 <test_priority_donate_sema+0x3a>
c002b8eb:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002b8f2:	c0 
c002b8f3:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b8fa:	c0 
c002b8fb:	c7 44 24 08 a9 df 02 	movl   $0xc002dfa9,0x8(%esp)
c002b902:	c0 
c002b903:	c7 44 24 04 23 00 00 	movl   $0x23,0x4(%esp)
c002b90a:	00 
c002b90b:	c7 04 24 c0 09 03 c0 	movl   $0xc00309c0,(%esp)
c002b912:	e8 4c d0 ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b917:	e8 1e 56 ff ff       	call   c0020f3a <thread_get_priority>
c002b91c:	83 f8 1f             	cmp    $0x1f,%eax
c002b91f:	74 2c                	je     c002b94d <test_priority_donate_sema+0x70>
c002b921:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002b928:	c0 
c002b929:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002b930:	c0 
c002b931:	c7 44 24 08 a9 df 02 	movl   $0xc002dfa9,0x8(%esp)
c002b938:	c0 
c002b939:	c7 44 24 04 26 00 00 	movl   $0x26,0x4(%esp)
c002b940:	00 
c002b941:	c7 04 24 c0 09 03 c0 	movl   $0xc00309c0,(%esp)
c002b948:	e8 16 d0 ff ff       	call   c0028963 <debug_panic>
  lock_init (&ls.lock);
c002b94d:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b951:	89 1c 24             	mov    %ebx,(%esp)
c002b954:	e8 44 74 ff ff       	call   c0022d9d <lock_init>
  sema_init (&ls.sema, 0);
c002b959:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002b960:	00 
c002b961:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b965:	89 34 24             	mov    %esi,(%esp)
c002b968:	e8 59 71 ff ff       	call   c0022ac6 <sema_init>
  thread_create ("low", PRI_DEFAULT + 1, l_thread_func, &ls);
c002b96d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b971:	c7 44 24 08 91 b8 02 	movl   $0xc002b891,0x8(%esp)
c002b978:	c0 
c002b979:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b980:	00 
c002b981:	c7 04 24 a1 09 03 c0 	movl   $0xc00309a1,(%esp)
c002b988:	e8 9a 5b ff ff       	call   c0021527 <thread_create>
  thread_create ("med", PRI_DEFAULT + 3, m_thread_func, &ls);
c002b98d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b991:	c7 44 24 08 6f b8 02 	movl   $0xc002b86f,0x8(%esp)
c002b998:	c0 
c002b999:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b9a0:	00 
c002b9a1:	c7 04 24 a5 09 03 c0 	movl   $0xc00309a5,(%esp)
c002b9a8:	e8 7a 5b ff ff       	call   c0021527 <thread_create>
  thread_create ("high", PRI_DEFAULT + 5, h_thread_func, &ls);
c002b9ad:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9b1:	c7 44 24 08 2f b8 02 	movl   $0xc002b82f,0x8(%esp)
c002b9b8:	c0 
c002b9b9:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b9c0:	00 
c002b9c1:	c7 04 24 1d 08 03 c0 	movl   $0xc003081d,(%esp)
c002b9c8:	e8 5a 5b ff ff       	call   c0021527 <thread_create>
  sema_up (&ls.sema);
c002b9cd:	89 34 24             	mov    %esi,(%esp)
c002b9d0:	e8 52 72 ff ff       	call   c0022c27 <sema_up>
  msg ("Main thread finished.");
c002b9d5:	c7 04 24 a9 09 03 c0 	movl   $0xc00309a9,(%esp)
c002b9dc:	e8 3c ed ff ff       	call   c002a71d <msg>
}
c002b9e1:	83 c4 64             	add    $0x64,%esp
c002b9e4:	5b                   	pop    %ebx
c002b9e5:	5e                   	pop    %esi
c002b9e6:	c3                   	ret    

c002b9e7 <acquire_thread_func>:
       PRI_DEFAULT - 10, thread_get_priority ());
}

static void
acquire_thread_func (void *lock_) 
{
c002b9e7:	53                   	push   %ebx
c002b9e8:	83 ec 18             	sub    $0x18,%esp
c002b9eb:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b9ef:	89 1c 24             	mov    %ebx,(%esp)
c002b9f2:	e8 43 74 ff ff       	call   c0022e3a <lock_acquire>
  msg ("acquire: got the lock");
c002b9f7:	c7 04 24 eb 09 03 c0 	movl   $0xc00309eb,(%esp)
c002b9fe:	e8 1a ed ff ff       	call   c002a71d <msg>
  lock_release (lock);
c002ba03:	89 1c 24             	mov    %ebx,(%esp)
c002ba06:	e8 f9 75 ff ff       	call   c0023004 <lock_release>
  msg ("acquire: done");
c002ba0b:	c7 04 24 01 0a 03 c0 	movl   $0xc0030a01,(%esp)
c002ba12:	e8 06 ed ff ff       	call   c002a71d <msg>
}
c002ba17:	83 c4 18             	add    $0x18,%esp
c002ba1a:	5b                   	pop    %ebx
c002ba1b:	c3                   	ret    

c002ba1c <test_priority_donate_lower>:
{
c002ba1c:	53                   	push   %ebx
c002ba1d:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002ba20:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002ba27:	74 2c                	je     c002ba55 <test_priority_donate_lower+0x39>
c002ba29:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002ba30:	c0 
c002ba31:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002ba38:	c0 
c002ba39:	c7 44 24 08 c3 df 02 	movl   $0xc002dfc3,0x8(%esp)
c002ba40:	c0 
c002ba41:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002ba48:	00 
c002ba49:	c7 04 24 34 0a 03 c0 	movl   $0xc0030a34,(%esp)
c002ba50:	e8 0e cf ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002ba55:	e8 e0 54 ff ff       	call   c0020f3a <thread_get_priority>
c002ba5a:	83 f8 1f             	cmp    $0x1f,%eax
c002ba5d:	74 2c                	je     c002ba8b <test_priority_donate_lower+0x6f>
c002ba5f:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002ba66:	c0 
c002ba67:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002ba6e:	c0 
c002ba6f:	c7 44 24 08 c3 df 02 	movl   $0xc002dfc3,0x8(%esp)
c002ba76:	c0 
c002ba77:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002ba7e:	00 
c002ba7f:	c7 04 24 34 0a 03 c0 	movl   $0xc0030a34,(%esp)
c002ba86:	e8 d8 ce ff ff       	call   c0028963 <debug_panic>
  lock_init (&lock);
c002ba8b:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002ba8f:	89 1c 24             	mov    %ebx,(%esp)
c002ba92:	e8 06 73 ff ff       	call   c0022d9d <lock_init>
  lock_acquire (&lock);
c002ba97:	89 1c 24             	mov    %ebx,(%esp)
c002ba9a:	e8 9b 73 ff ff       	call   c0022e3a <lock_acquire>
  thread_create ("acquire", PRI_DEFAULT + 10, acquire_thread_func, &lock);
c002ba9f:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002baa3:	c7 44 24 08 e7 b9 02 	movl   $0xc002b9e7,0x8(%esp)
c002baaa:	c0 
c002baab:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bab2:	00 
c002bab3:	c7 04 24 0f 0a 03 c0 	movl   $0xc0030a0f,(%esp)
c002baba:	e8 68 5a ff ff       	call   c0021527 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002babf:	e8 76 54 ff ff       	call   c0020f3a <thread_get_priority>
c002bac4:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bac8:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bacf:	00 
c002bad0:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002bad7:	e8 41 ec ff ff       	call   c002a71d <msg>
  msg ("Lowering base priority...");
c002badc:	c7 04 24 17 0a 03 c0 	movl   $0xc0030a17,(%esp)
c002bae3:	e8 35 ec ff ff       	call   c002a71d <msg>
  thread_set_priority (PRI_DEFAULT - 10);
c002bae8:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
c002baef:	e8 a1 5b ff ff       	call   c0021695 <thread_set_priority>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002baf4:	e8 41 54 ff ff       	call   c0020f3a <thread_get_priority>
c002baf9:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bafd:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb04:	00 
c002bb05:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002bb0c:	e8 0c ec ff ff       	call   c002a71d <msg>
  lock_release (&lock);
c002bb11:	89 1c 24             	mov    %ebx,(%esp)
c002bb14:	e8 eb 74 ff ff       	call   c0023004 <lock_release>
  msg ("acquire must already have finished.");
c002bb19:	c7 04 24 60 0a 03 c0 	movl   $0xc0030a60,(%esp)
c002bb20:	e8 f8 eb ff ff       	call   c002a71d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb25:	e8 10 54 ff ff       	call   c0020f3a <thread_get_priority>
c002bb2a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb2e:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bb35:	00 
c002bb36:	c7 04 24 b0 06 03 c0 	movl   $0xc00306b0,(%esp)
c002bb3d:	e8 db eb ff ff       	call   c002a71d <msg>
}
c002bb42:	83 c4 58             	add    $0x58,%esp
c002bb45:	5b                   	pop    %ebx
c002bb46:	c3                   	ret    
c002bb47:	90                   	nop
c002bb48:	90                   	nop
c002bb49:	90                   	nop
c002bb4a:	90                   	nop
c002bb4b:	90                   	nop
c002bb4c:	90                   	nop
c002bb4d:	90                   	nop
c002bb4e:	90                   	nop
c002bb4f:	90                   	nop

c002bb50 <simple_thread_func>:
    }
}

static void 
simple_thread_func (void *data_) 
{
c002bb50:	56                   	push   %esi
c002bb51:	53                   	push   %ebx
c002bb52:	83 ec 14             	sub    $0x14,%esp
c002bb55:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002bb59:	be 10 00 00 00       	mov    $0x10,%esi
  struct simple_thread_data *data = data_;
  int i;
  
  for (i = 0; i < ITER_CNT; i++) 
    {
      lock_acquire (data->lock);
c002bb5e:	8b 43 08             	mov    0x8(%ebx),%eax
c002bb61:	89 04 24             	mov    %eax,(%esp)
c002bb64:	e8 d1 72 ff ff       	call   c0022e3a <lock_acquire>
      *(*data->op)++ = data->id;
c002bb69:	8b 53 0c             	mov    0xc(%ebx),%edx
c002bb6c:	8b 02                	mov    (%edx),%eax
c002bb6e:	8d 48 04             	lea    0x4(%eax),%ecx
c002bb71:	89 0a                	mov    %ecx,(%edx)
c002bb73:	8b 13                	mov    (%ebx),%edx
c002bb75:	89 10                	mov    %edx,(%eax)
      lock_release (data->lock);
c002bb77:	8b 43 08             	mov    0x8(%ebx),%eax
c002bb7a:	89 04 24             	mov    %eax,(%esp)
c002bb7d:	e8 82 74 ff ff       	call   c0023004 <lock_release>
      thread_yield ();
c002bb82:	e8 fe 58 ff ff       	call   c0021485 <thread_yield>
  for (i = 0; i < ITER_CNT; i++) 
c002bb87:	83 ee 01             	sub    $0x1,%esi
c002bb8a:	75 d2                	jne    c002bb5e <simple_thread_func+0xe>
    }
}
c002bb8c:	83 c4 14             	add    $0x14,%esp
c002bb8f:	5b                   	pop    %ebx
c002bb90:	5e                   	pop    %esi
c002bb91:	c3                   	ret    

c002bb92 <test_priority_fifo>:
{
c002bb92:	55                   	push   %ebp
c002bb93:	57                   	push   %edi
c002bb94:	56                   	push   %esi
c002bb95:	53                   	push   %ebx
c002bb96:	81 ec 6c 01 00 00    	sub    $0x16c,%esp
  ASSERT (!thread_mlfqs);
c002bb9c:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002bba3:	74 2c                	je     c002bbd1 <test_priority_fifo+0x3f>
c002bba5:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002bbac:	c0 
c002bbad:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002bbb4:	c0 
c002bbb5:	c7 44 24 08 de df 02 	movl   $0xc002dfde,0x8(%esp)
c002bbbc:	c0 
c002bbbd:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002bbc4:	00 
c002bbc5:	c7 04 24 b4 0a 03 c0 	movl   $0xc0030ab4,(%esp)
c002bbcc:	e8 92 cd ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002bbd1:	e8 64 53 ff ff       	call   c0020f3a <thread_get_priority>
c002bbd6:	83 f8 1f             	cmp    $0x1f,%eax
c002bbd9:	74 2c                	je     c002bc07 <test_priority_fifo+0x75>
c002bbdb:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002bbe2:	c0 
c002bbe3:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002bbea:	c0 
c002bbeb:	c7 44 24 08 de df 02 	movl   $0xc002dfde,0x8(%esp)
c002bbf2:	c0 
c002bbf3:	c7 44 24 04 2b 00 00 	movl   $0x2b,0x4(%esp)
c002bbfa:	00 
c002bbfb:	c7 04 24 b4 0a 03 c0 	movl   $0xc0030ab4,(%esp)
c002bc02:	e8 5c cd ff ff       	call   c0028963 <debug_panic>
  msg ("%d threads will iterate %d times in the same order each time.",
c002bc07:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c002bc0e:	00 
c002bc0f:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bc16:	00 
c002bc17:	c7 04 24 d8 0a 03 c0 	movl   $0xc0030ad8,(%esp)
c002bc1e:	e8 fa ea ff ff       	call   c002a71d <msg>
  msg ("If the order varies then there is a bug.");
c002bc23:	c7 04 24 18 0b 03 c0 	movl   $0xc0030b18,(%esp)
c002bc2a:	e8 ee ea ff ff       	call   c002a71d <msg>
  output = op = malloc (sizeof *output * THREAD_CNT * ITER_CNT * 2);
c002bc2f:	c7 04 24 00 08 00 00 	movl   $0x800,(%esp)
c002bc36:	e8 c9 7d ff ff       	call   c0023a04 <malloc>
c002bc3b:	89 c6                	mov    %eax,%esi
c002bc3d:	89 44 24 38          	mov    %eax,0x38(%esp)
  ASSERT (output != NULL);
c002bc41:	85 c0                	test   %eax,%eax
c002bc43:	75 2c                	jne    c002bc71 <test_priority_fifo+0xdf>
c002bc45:	c7 44 24 10 b6 00 03 	movl   $0xc00300b6,0x10(%esp)
c002bc4c:	c0 
c002bc4d:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002bc54:	c0 
c002bc55:	c7 44 24 08 de df 02 	movl   $0xc002dfde,0x8(%esp)
c002bc5c:	c0 
c002bc5d:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c002bc64:	00 
c002bc65:	c7 04 24 b4 0a 03 c0 	movl   $0xc0030ab4,(%esp)
c002bc6c:	e8 f2 cc ff ff       	call   c0028963 <debug_panic>
  lock_init (&lock);
c002bc71:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bc75:	89 04 24             	mov    %eax,(%esp)
c002bc78:	e8 20 71 ff ff       	call   c0022d9d <lock_init>
  thread_set_priority (PRI_DEFAULT + 2);
c002bc7d:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c002bc84:	e8 0c 5a ff ff       	call   c0021695 <thread_set_priority>
c002bc89:	8d 5c 24 60          	lea    0x60(%esp),%ebx
  for (i = 0; i < THREAD_CNT; i++) 
c002bc8d:	bf 00 00 00 00       	mov    $0x0,%edi
      snprintf (name, sizeof name, "%d", i);
c002bc92:	8d 6c 24 28          	lea    0x28(%esp),%ebp
c002bc96:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002bc9a:	c7 44 24 08 cc 00 03 	movl   $0xc00300cc,0x8(%esp)
c002bca1:	c0 
c002bca2:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bca9:	00 
c002bcaa:	89 2c 24             	mov    %ebp,(%esp)
c002bcad:	e8 5d b5 ff ff       	call   c002720f <snprintf>
      d->id = i;
c002bcb2:	89 3b                	mov    %edi,(%ebx)
      d->iterations = 0;
c002bcb4:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
      d->lock = &lock;
c002bcbb:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bcbf:	89 43 08             	mov    %eax,0x8(%ebx)
      d->op = &op;
c002bcc2:	8d 44 24 38          	lea    0x38(%esp),%eax
c002bcc6:	89 43 0c             	mov    %eax,0xc(%ebx)
      thread_create (name, PRI_DEFAULT + 1, simple_thread_func, d);
c002bcc9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bccd:	c7 44 24 08 50 bb 02 	movl   $0xc002bb50,0x8(%esp)
c002bcd4:	c0 
c002bcd5:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bcdc:	00 
c002bcdd:	89 2c 24             	mov    %ebp,(%esp)
c002bce0:	e8 42 58 ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002bce5:	83 c7 01             	add    $0x1,%edi
c002bce8:	83 c3 10             	add    $0x10,%ebx
c002bceb:	83 ff 10             	cmp    $0x10,%edi
c002bcee:	75 a6                	jne    c002bc96 <test_priority_fifo+0x104>
  thread_set_priority (PRI_DEFAULT);
c002bcf0:	c7 04 24 1f 00 00 00 	movl   $0x1f,(%esp)
c002bcf7:	e8 99 59 ff ff       	call   c0021695 <thread_set_priority>
  ASSERT (lock.holder == NULL);
c002bcfc:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002bd01:	75 13                	jne    c002bd16 <test_priority_fifo+0x184>
  for (; output < op; output++) 
c002bd03:	3b 74 24 38          	cmp    0x38(%esp),%esi
c002bd07:	0f 83 be 00 00 00    	jae    c002bdcb <test_priority_fifo+0x239>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd0d:	8b 3e                	mov    (%esi),%edi
c002bd0f:	83 ff 0f             	cmp    $0xf,%edi
c002bd12:	76 61                	jbe    c002bd75 <test_priority_fifo+0x1e3>
c002bd14:	eb 33                	jmp    c002bd49 <test_priority_fifo+0x1b7>
  ASSERT (lock.holder == NULL);
c002bd16:	c7 44 24 10 84 0a 03 	movl   $0xc0030a84,0x10(%esp)
c002bd1d:	c0 
c002bd1e:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002bd25:	c0 
c002bd26:	c7 44 24 08 de df 02 	movl   $0xc002dfde,0x8(%esp)
c002bd2d:	c0 
c002bd2e:	c7 44 24 04 44 00 00 	movl   $0x44,0x4(%esp)
c002bd35:	00 
c002bd36:	c7 04 24 b4 0a 03 c0 	movl   $0xc0030ab4,(%esp)
c002bd3d:	e8 21 cc ff ff       	call   c0028963 <debug_panic>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd42:	8b 3e                	mov    (%esi),%edi
c002bd44:	83 ff 0f             	cmp    $0xf,%edi
c002bd47:	76 31                	jbe    c002bd7a <test_priority_fifo+0x1e8>
c002bd49:	c7 44 24 10 44 0b 03 	movl   $0xc0030b44,0x10(%esp)
c002bd50:	c0 
c002bd51:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002bd58:	c0 
c002bd59:	c7 44 24 08 de df 02 	movl   $0xc002dfde,0x8(%esp)
c002bd60:	c0 
c002bd61:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002bd68:	00 
c002bd69:	c7 04 24 b4 0a 03 c0 	movl   $0xc0030ab4,(%esp)
c002bd70:	e8 ee cb ff ff       	call   c0028963 <debug_panic>
c002bd75:	bb 00 00 00 00       	mov    $0x0,%ebx
      d = data + *output;
c002bd7a:	c1 e7 04             	shl    $0x4,%edi
c002bd7d:	8d 44 24 60          	lea    0x60(%esp),%eax
c002bd81:	01 c7                	add    %eax,%edi
      if (cnt % THREAD_CNT == 0)
c002bd83:	f6 c3 0f             	test   $0xf,%bl
c002bd86:	75 0c                	jne    c002bd94 <test_priority_fifo+0x202>
        printf ("(priority-fifo) iteration:");
c002bd88:	c7 04 24 98 0a 03 c0 	movl   $0xc0030a98,(%esp)
c002bd8f:	e8 7a ad ff ff       	call   c0026b0e <printf>
      printf (" %d", d->id);
c002bd94:	8b 07                	mov    (%edi),%eax
c002bd96:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bd9a:	c7 04 24 cb 00 03 c0 	movl   $0xc00300cb,(%esp)
c002bda1:	e8 68 ad ff ff       	call   c0026b0e <printf>
      if (++cnt % THREAD_CNT == 0)
c002bda6:	83 c3 01             	add    $0x1,%ebx
c002bda9:	f6 c3 0f             	test   $0xf,%bl
c002bdac:	75 0c                	jne    c002bdba <test_priority_fifo+0x228>
        printf ("\n");
c002bdae:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002bdb5:	e8 42 e9 ff ff       	call   c002a6fc <putchar>
      d->iterations++;
c002bdba:	83 47 04 01          	addl   $0x1,0x4(%edi)
  for (; output < op; output++) 
c002bdbe:	83 c6 04             	add    $0x4,%esi
c002bdc1:	39 74 24 38          	cmp    %esi,0x38(%esp)
c002bdc5:	0f 87 77 ff ff ff    	ja     c002bd42 <test_priority_fifo+0x1b0>
}
c002bdcb:	81 c4 6c 01 00 00    	add    $0x16c,%esp
c002bdd1:	5b                   	pop    %ebx
c002bdd2:	5e                   	pop    %esi
c002bdd3:	5f                   	pop    %edi
c002bdd4:	5d                   	pop    %ebp
c002bdd5:	c3                   	ret    

c002bdd6 <simple_thread_func>:
  msg ("The high-priority thread should have already completed.");
}

static void 
simple_thread_func (void *aux UNUSED) 
{
c002bdd6:	53                   	push   %ebx
c002bdd7:	83 ec 18             	sub    $0x18,%esp
  int i;
  
  for (i = 0; i < 5; i++) 
c002bdda:	bb 00 00 00 00       	mov    $0x0,%ebx
    {
      msg ("Thread %s iteration %d", thread_name (), i);
c002bddf:	e8 b9 50 ff ff       	call   c0020e9d <thread_name>
c002bde4:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002bde8:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bdec:	c7 04 24 69 0b 03 c0 	movl   $0xc0030b69,(%esp)
c002bdf3:	e8 25 e9 ff ff       	call   c002a71d <msg>
      thread_yield ();
c002bdf8:	e8 88 56 ff ff       	call   c0021485 <thread_yield>
  for (i = 0; i < 5; i++) 
c002bdfd:	83 c3 01             	add    $0x1,%ebx
c002be00:	83 fb 05             	cmp    $0x5,%ebx
c002be03:	75 da                	jne    c002bddf <simple_thread_func+0x9>
    }
  msg ("Thread %s done!", thread_name ());
c002be05:	e8 93 50 ff ff       	call   c0020e9d <thread_name>
c002be0a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be0e:	c7 04 24 80 0b 03 c0 	movl   $0xc0030b80,(%esp)
c002be15:	e8 03 e9 ff ff       	call   c002a71d <msg>
}
c002be1a:	83 c4 18             	add    $0x18,%esp
c002be1d:	5b                   	pop    %ebx
c002be1e:	c3                   	ret    

c002be1f <test_priority_preempt>:
{
c002be1f:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002be22:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002be29:	74 2c                	je     c002be57 <test_priority_preempt+0x38>
c002be2b:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002be32:	c0 
c002be33:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002be3a:	c0 
c002be3b:	c7 44 24 08 f1 df 02 	movl   $0xc002dff1,0x8(%esp)
c002be42:	c0 
c002be43:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002be4a:	00 
c002be4b:	c7 04 24 a0 0b 03 c0 	movl   $0xc0030ba0,(%esp)
c002be52:	e8 0c cb ff ff       	call   c0028963 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002be57:	e8 de 50 ff ff       	call   c0020f3a <thread_get_priority>
c002be5c:	83 f8 1f             	cmp    $0x1f,%eax
c002be5f:	74 2c                	je     c002be8d <test_priority_preempt+0x6e>
c002be61:	c7 44 24 10 48 05 03 	movl   $0xc0030548,0x10(%esp)
c002be68:	c0 
c002be69:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002be70:	c0 
c002be71:	c7 44 24 08 f1 df 02 	movl   $0xc002dff1,0x8(%esp)
c002be78:	c0 
c002be79:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002be80:	00 
c002be81:	c7 04 24 a0 0b 03 c0 	movl   $0xc0030ba0,(%esp)
c002be88:	e8 d6 ca ff ff       	call   c0028963 <debug_panic>
  thread_create ("high-priority", PRI_DEFAULT + 1, simple_thread_func, NULL);
c002be8d:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002be94:	00 
c002be95:	c7 44 24 08 d6 bd 02 	movl   $0xc002bdd6,0x8(%esp)
c002be9c:	c0 
c002be9d:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bea4:	00 
c002bea5:	c7 04 24 90 0b 03 c0 	movl   $0xc0030b90,(%esp)
c002beac:	e8 76 56 ff ff       	call   c0021527 <thread_create>
  msg ("The high-priority thread should have already completed.");
c002beb1:	c7 04 24 c8 0b 03 c0 	movl   $0xc0030bc8,(%esp)
c002beb8:	e8 60 e8 ff ff       	call   c002a71d <msg>
}
c002bebd:	83 c4 2c             	add    $0x2c,%esp
c002bec0:	c3                   	ret    

c002bec1 <priority_sema_thread>:
    }
}

static void
priority_sema_thread (void *aux UNUSED) 
{
c002bec1:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&sema);
c002bec4:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002becb:	e8 42 6c ff ff       	call   c0022b12 <sema_down>
  msg ("Thread %s woke up.", thread_name ());
c002bed0:	e8 c8 4f ff ff       	call   c0020e9d <thread_name>
c002bed5:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bed9:	c7 04 24 9c 03 03 c0 	movl   $0xc003039c,(%esp)
c002bee0:	e8 38 e8 ff ff       	call   c002a71d <msg>
}
c002bee5:	83 c4 1c             	add    $0x1c,%esp
c002bee8:	c3                   	ret    

c002bee9 <test_priority_sema>:
{
c002bee9:	55                   	push   %ebp
c002beea:	57                   	push   %edi
c002beeb:	56                   	push   %esi
c002beec:	53                   	push   %ebx
c002beed:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002bef0:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002bef7:	74 2c                	je     c002bf25 <test_priority_sema+0x3c>
c002bef9:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002bf00:	c0 
c002bf01:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002bf08:	c0 
c002bf09:	c7 44 24 08 07 e0 02 	movl   $0xc002e007,0x8(%esp)
c002bf10:	c0 
c002bf11:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bf18:	00 
c002bf19:	c7 04 24 18 0c 03 c0 	movl   $0xc0030c18,(%esp)
c002bf20:	e8 3e ca ff ff       	call   c0028963 <debug_panic>
  sema_init (&sema, 0);
c002bf25:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002bf2c:	00 
c002bf2d:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bf34:	e8 8d 6b ff ff       	call   c0022ac6 <sema_init>
  thread_set_priority (PRI_MIN);
c002bf39:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002bf40:	e8 50 57 ff ff       	call   c0021695 <thread_set_priority>
c002bf45:	bb 03 00 00 00       	mov    $0x3,%ebx
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bf4a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002bf4f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bf53:	89 d8                	mov    %ebx,%eax
c002bf55:	f7 ed                	imul   %ebp
c002bf57:	c1 fa 02             	sar    $0x2,%edx
c002bf5a:	89 d8                	mov    %ebx,%eax
c002bf5c:	c1 f8 1f             	sar    $0x1f,%eax
c002bf5f:	29 c2                	sub    %eax,%edx
c002bf61:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002bf64:	01 c0                	add    %eax,%eax
c002bf66:	29 d8                	sub    %ebx,%eax
c002bf68:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002bf6b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002bf6f:	c7 44 24 08 af 03 03 	movl   $0xc00303af,0x8(%esp)
c002bf76:	c0 
c002bf77:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bf7e:	00 
c002bf7f:	89 3c 24             	mov    %edi,(%esp)
c002bf82:	e8 88 b2 ff ff       	call   c002720f <snprintf>
      thread_create (name, priority, priority_sema_thread, NULL);
c002bf87:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bf8e:	00 
c002bf8f:	c7 44 24 08 c1 be 02 	movl   $0xc002bec1,0x8(%esp)
c002bf96:	c0 
c002bf97:	89 74 24 04          	mov    %esi,0x4(%esp)
c002bf9b:	89 3c 24             	mov    %edi,(%esp)
c002bf9e:	e8 84 55 ff ff       	call   c0021527 <thread_create>
c002bfa3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002bfa6:	83 fb 0d             	cmp    $0xd,%ebx
c002bfa9:	75 a8                	jne    c002bf53 <test_priority_sema+0x6a>
c002bfab:	b3 0a                	mov    $0xa,%bl
      sema_up (&sema);
c002bfad:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bfb4:	e8 6e 6c ff ff       	call   c0022c27 <sema_up>
      msg ("Back in main thread."); 
c002bfb9:	c7 04 24 00 0c 03 c0 	movl   $0xc0030c00,(%esp)
c002bfc0:	e8 58 e7 ff ff       	call   c002a71d <msg>
  for (i = 0; i < 10; i++) 
c002bfc5:	83 eb 01             	sub    $0x1,%ebx
c002bfc8:	75 e3                	jne    c002bfad <test_priority_sema+0xc4>
}
c002bfca:	83 c4 3c             	add    $0x3c,%esp
c002bfcd:	5b                   	pop    %ebx
c002bfce:	5e                   	pop    %esi
c002bfcf:	5f                   	pop    %edi
c002bfd0:	5d                   	pop    %ebp
c002bfd1:	c3                   	ret    

c002bfd2 <priority_condvar_thread>:
    }
}

static void
priority_condvar_thread (void *aux UNUSED) 
{
c002bfd2:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread %s starting.", thread_name ());
c002bfd5:	e8 c3 4e ff ff       	call   c0020e9d <thread_name>
c002bfda:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bfde:	c7 04 24 3c 0c 03 c0 	movl   $0xc0030c3c,(%esp)
c002bfe5:	e8 33 e7 ff ff       	call   c002a71d <msg>
  lock_acquire (&lock);
c002bfea:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002bff1:	e8 44 6e ff ff       	call   c0022e3a <lock_acquire>
  cond_wait (&condition, &lock);
c002bff6:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002bffd:	c0 
c002bffe:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c005:	e8 36 71 ff ff       	call   c0023140 <cond_wait>
  msg ("Thread %s woke up.", thread_name ());
c002c00a:	e8 8e 4e ff ff       	call   c0020e9d <thread_name>
c002c00f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c013:	c7 04 24 9c 03 03 c0 	movl   $0xc003039c,(%esp)
c002c01a:	e8 fe e6 ff ff       	call   c002a71d <msg>
  lock_release (&lock);
c002c01f:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c026:	e8 d9 6f ff ff       	call   c0023004 <lock_release>
}
c002c02b:	83 c4 1c             	add    $0x1c,%esp
c002c02e:	c3                   	ret    

c002c02f <test_priority_condvar>:
{
c002c02f:	55                   	push   %ebp
c002c030:	57                   	push   %edi
c002c031:	56                   	push   %esi
c002c032:	53                   	push   %ebx
c002c033:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002c036:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c03d:	74 2c                	je     c002c06b <test_priority_condvar+0x3c>
c002c03f:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002c046:	c0 
c002c047:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002c04e:	c0 
c002c04f:	c7 44 24 08 1a e0 02 	movl   $0xc002e01a,0x8(%esp)
c002c056:	c0 
c002c057:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002c05e:	00 
c002c05f:	c7 04 24 60 0c 03 c0 	movl   $0xc0030c60,(%esp)
c002c066:	e8 f8 c8 ff ff       	call   c0028963 <debug_panic>
  lock_init (&lock);
c002c06b:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c072:	e8 26 6d ff ff       	call   c0022d9d <lock_init>
  cond_init (&condition);
c002c077:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c07e:	e8 7a 70 ff ff       	call   c00230fd <cond_init>
  thread_set_priority (PRI_MIN);
c002c083:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c08a:	e8 06 56 ff ff       	call   c0021695 <thread_set_priority>
c002c08f:	bb 07 00 00 00       	mov    $0x7,%ebx
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c094:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002c099:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c09d:	89 d8                	mov    %ebx,%eax
c002c09f:	f7 ed                	imul   %ebp
c002c0a1:	c1 fa 02             	sar    $0x2,%edx
c002c0a4:	89 d8                	mov    %ebx,%eax
c002c0a6:	c1 f8 1f             	sar    $0x1f,%eax
c002c0a9:	29 c2                	sub    %eax,%edx
c002c0ab:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002c0ae:	01 c0                	add    %eax,%eax
c002c0b0:	29 d8                	sub    %ebx,%eax
c002c0b2:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002c0b5:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c0b9:	c7 44 24 08 af 03 03 	movl   $0xc00303af,0x8(%esp)
c002c0c0:	c0 
c002c0c1:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c0c8:	00 
c002c0c9:	89 3c 24             	mov    %edi,(%esp)
c002c0cc:	e8 3e b1 ff ff       	call   c002720f <snprintf>
      thread_create (name, priority, priority_condvar_thread, NULL);
c002c0d1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c0d8:	00 
c002c0d9:	c7 44 24 08 d2 bf 02 	movl   $0xc002bfd2,0x8(%esp)
c002c0e0:	c0 
c002c0e1:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c0e5:	89 3c 24             	mov    %edi,(%esp)
c002c0e8:	e8 3a 54 ff ff       	call   c0021527 <thread_create>
c002c0ed:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002c0f0:	83 fb 11             	cmp    $0x11,%ebx
c002c0f3:	75 a8                	jne    c002c09d <test_priority_condvar+0x6e>
c002c0f5:	b3 0a                	mov    $0xa,%bl
      lock_acquire (&lock);
c002c0f7:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c0fe:	e8 37 6d ff ff       	call   c0022e3a <lock_acquire>
      msg ("Signaling...");
c002c103:	c7 04 24 50 0c 03 c0 	movl   $0xc0030c50,(%esp)
c002c10a:	e8 0e e6 ff ff       	call   c002a71d <msg>
      cond_signal (&condition, &lock);
c002c10f:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c116:	c0 
c002c117:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c11e:	e8 46 71 ff ff       	call   c0023269 <cond_signal>
      lock_release (&lock);
c002c123:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c12a:	e8 d5 6e ff ff       	call   c0023004 <lock_release>
  for (i = 0; i < 10; i++) 
c002c12f:	83 eb 01             	sub    $0x1,%ebx
c002c132:	75 c3                	jne    c002c0f7 <test_priority_condvar+0xc8>
}
c002c134:	83 c4 3c             	add    $0x3c,%esp
c002c137:	5b                   	pop    %ebx
c002c138:	5e                   	pop    %esi
c002c139:	5f                   	pop    %edi
c002c13a:	5d                   	pop    %ebp
c002c13b:	c3                   	ret    

c002c13c <interloper_thread_func>:
                                         thread_get_priority ());
}

static void
interloper_thread_func (void *arg_ UNUSED)
{
c002c13c:	83 ec 1c             	sub    $0x1c,%esp
  msg ("%s finished.", thread_name ());
c002c13f:	e8 59 4d ff ff       	call   c0020e9d <thread_name>
c002c144:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c148:	c7 04 24 87 0c 03 c0 	movl   $0xc0030c87,(%esp)
c002c14f:	e8 c9 e5 ff ff       	call   c002a71d <msg>
}
c002c154:	83 c4 1c             	add    $0x1c,%esp
c002c157:	c3                   	ret    

c002c158 <donor_thread_func>:
{
c002c158:	56                   	push   %esi
c002c159:	53                   	push   %ebx
c002c15a:	83 ec 14             	sub    $0x14,%esp
c002c15d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (locks->first)
c002c161:	8b 43 04             	mov    0x4(%ebx),%eax
c002c164:	85 c0                	test   %eax,%eax
c002c166:	74 08                	je     c002c170 <donor_thread_func+0x18>
    lock_acquire (locks->first);
c002c168:	89 04 24             	mov    %eax,(%esp)
c002c16b:	e8 ca 6c ff ff       	call   c0022e3a <lock_acquire>
  lock_acquire (locks->second);
c002c170:	8b 03                	mov    (%ebx),%eax
c002c172:	89 04 24             	mov    %eax,(%esp)
c002c175:	e8 c0 6c ff ff       	call   c0022e3a <lock_acquire>
  msg ("%s got lock", thread_name ());
c002c17a:	e8 1e 4d ff ff       	call   c0020e9d <thread_name>
c002c17f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c183:	c7 04 24 94 0c 03 c0 	movl   $0xc0030c94,(%esp)
c002c18a:	e8 8e e5 ff ff       	call   c002a71d <msg>
  lock_release (locks->second);
c002c18f:	8b 03                	mov    (%ebx),%eax
c002c191:	89 04 24             	mov    %eax,(%esp)
c002c194:	e8 6b 6e ff ff       	call   c0023004 <lock_release>
  msg ("%s should have priority %d. Actual priority: %d", 
c002c199:	e8 9c 4d ff ff       	call   c0020f3a <thread_get_priority>
c002c19e:	89 c6                	mov    %eax,%esi
c002c1a0:	e8 f8 4c ff ff       	call   c0020e9d <thread_name>
c002c1a5:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c1a9:	c7 44 24 08 15 00 00 	movl   $0x15,0x8(%esp)
c002c1b0:	00 
c002c1b1:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1b5:	c7 04 24 bc 0c 03 c0 	movl   $0xc0030cbc,(%esp)
c002c1bc:	e8 5c e5 ff ff       	call   c002a71d <msg>
  if (locks->first)
c002c1c1:	8b 43 04             	mov    0x4(%ebx),%eax
c002c1c4:	85 c0                	test   %eax,%eax
c002c1c6:	74 08                	je     c002c1d0 <donor_thread_func+0x78>
    lock_release (locks->first);
c002c1c8:	89 04 24             	mov    %eax,(%esp)
c002c1cb:	e8 34 6e ff ff       	call   c0023004 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c1d0:	e8 65 4d ff ff       	call   c0020f3a <thread_get_priority>
c002c1d5:	89 c3                	mov    %eax,%ebx
c002c1d7:	e8 c1 4c ff ff       	call   c0020e9d <thread_name>
c002c1dc:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c1e0:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1e4:	c7 04 24 ec 0c 03 c0 	movl   $0xc0030cec,(%esp)
c002c1eb:	e8 2d e5 ff ff       	call   c002a71d <msg>
}
c002c1f0:	83 c4 14             	add    $0x14,%esp
c002c1f3:	5b                   	pop    %ebx
c002c1f4:	5e                   	pop    %esi
c002c1f5:	c3                   	ret    

c002c1f6 <test_priority_donate_chain>:
{
c002c1f6:	55                   	push   %ebp
c002c1f7:	57                   	push   %edi
c002c1f8:	56                   	push   %esi
c002c1f9:	53                   	push   %ebx
c002c1fa:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
  ASSERT (!thread_mlfqs);
c002c200:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c207:	74 2c                	je     c002c235 <test_priority_donate_chain+0x3f>
c002c209:	c7 44 24 10 a8 00 03 	movl   $0xc00300a8,0x10(%esp)
c002c210:	c0 
c002c211:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002c218:	c0 
c002c219:	c7 44 24 08 30 e0 02 	movl   $0xc002e030,0x8(%esp)
c002c220:	c0 
c002c221:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c002c228:	00 
c002c229:	c7 04 24 0c 0d 03 c0 	movl   $0xc0030d0c,(%esp)
c002c230:	e8 2e c7 ff ff       	call   c0028963 <debug_panic>
  thread_set_priority (PRI_MIN);
c002c235:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c23c:	e8 54 54 ff ff       	call   c0021695 <thread_set_priority>
c002c241:	8d 5c 24 74          	lea    0x74(%esp),%ebx
c002c245:	8d b4 24 70 01 00 00 	lea    0x170(%esp),%esi
    lock_init (&locks[i]);
c002c24c:	89 1c 24             	mov    %ebx,(%esp)
c002c24f:	e8 49 6b ff ff       	call   c0022d9d <lock_init>
c002c254:	83 c3 24             	add    $0x24,%ebx
  for (i = 0; i < NESTING_DEPTH - 1; i++)
c002c257:	39 f3                	cmp    %esi,%ebx
c002c259:	75 f1                	jne    c002c24c <test_priority_donate_chain+0x56>
  lock_acquire (&locks[0]);
c002c25b:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c25f:	89 04 24             	mov    %eax,(%esp)
c002c262:	e8 d3 6b ff ff       	call   c0022e3a <lock_acquire>
  msg ("%s got lock.", thread_name ());
c002c267:	e8 31 4c ff ff       	call   c0020e9d <thread_name>
c002c26c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c270:	c7 04 24 a0 0c 03 c0 	movl   $0xc0030ca0,(%esp)
c002c277:	e8 a1 e4 ff ff       	call   c002a71d <msg>
c002c27c:	8d 84 24 98 00 00 00 	lea    0x98(%esp),%eax
c002c283:	89 44 24 14          	mov    %eax,0x14(%esp)
c002c287:	8d 74 24 40          	lea    0x40(%esp),%esi
c002c28b:	bf 03 00 00 00       	mov    $0x3,%edi
  for (i = 1; i < NESTING_DEPTH; i++)
c002c290:	bb 01 00 00 00       	mov    $0x1,%ebx
      snprintf (name, sizeof name, "thread %d", i);
c002c295:	8d 6c 24 24          	lea    0x24(%esp),%ebp
c002c299:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c29d:	c7 44 24 08 c5 00 03 	movl   $0xc00300c5,0x8(%esp)
c002c2a4:	c0 
c002c2a5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c2ac:	00 
c002c2ad:	89 2c 24             	mov    %ebp,(%esp)
c002c2b0:	e8 5a af ff ff       	call   c002720f <snprintf>
      lock_pairs[i].first = i < NESTING_DEPTH - 1 ? locks + i: NULL;
c002c2b5:	83 fb 06             	cmp    $0x6,%ebx
c002c2b8:	b8 00 00 00 00       	mov    $0x0,%eax
c002c2bd:	8b 54 24 14          	mov    0x14(%esp),%edx
c002c2c1:	0f 4e c2             	cmovle %edx,%eax
c002c2c4:	89 06                	mov    %eax,(%esi)
c002c2c6:	89 d0                	mov    %edx,%eax
c002c2c8:	83 e8 24             	sub    $0x24,%eax
c002c2cb:	89 46 fc             	mov    %eax,-0x4(%esi)
c002c2ce:	8d 46 fc             	lea    -0x4(%esi),%eax
      thread_create (name, thread_priority, donor_thread_func, lock_pairs + i);
c002c2d1:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c2d5:	c7 44 24 08 58 c1 02 	movl   $0xc002c158,0x8(%esp)
c002c2dc:	c0 
c002c2dd:	89 7c 24 18          	mov    %edi,0x18(%esp)
c002c2e1:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c2e5:	89 2c 24             	mov    %ebp,(%esp)
c002c2e8:	e8 3a 52 ff ff       	call   c0021527 <thread_create>
      msg ("%s should have priority %d.  Actual priority: %d.",
c002c2ed:	e8 48 4c ff ff       	call   c0020f3a <thread_get_priority>
c002c2f2:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002c2f6:	e8 a2 4b ff ff       	call   c0020e9d <thread_name>
c002c2fb:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c2ff:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002c303:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c002c307:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002c30b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c30f:	c7 04 24 38 0d 03 c0 	movl   $0xc0030d38,(%esp)
c002c316:	e8 02 e4 ff ff       	call   c002a71d <msg>
      snprintf (name, sizeof name, "interloper %d", i);
c002c31b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c31f:	c7 44 24 08 ad 0c 03 	movl   $0xc0030cad,0x8(%esp)
c002c326:	c0 
c002c327:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c32e:	00 
c002c32f:	89 2c 24             	mov    %ebp,(%esp)
c002c332:	e8 d8 ae ff ff       	call   c002720f <snprintf>
      thread_create (name, thread_priority - 1, interloper_thread_func, NULL);
c002c337:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c33e:	00 
c002c33f:	c7 44 24 08 3c c1 02 	movl   $0xc002c13c,0x8(%esp)
c002c346:	c0 
c002c347:	8d 47 ff             	lea    -0x1(%edi),%eax
c002c34a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c34e:	89 2c 24             	mov    %ebp,(%esp)
c002c351:	e8 d1 51 ff ff       	call   c0021527 <thread_create>
  for (i = 1; i < NESTING_DEPTH; i++)
c002c356:	83 c3 01             	add    $0x1,%ebx
c002c359:	83 44 24 14 24       	addl   $0x24,0x14(%esp)
c002c35e:	83 c6 08             	add    $0x8,%esi
c002c361:	83 c7 03             	add    $0x3,%edi
c002c364:	83 fb 08             	cmp    $0x8,%ebx
c002c367:	0f 85 2c ff ff ff    	jne    c002c299 <test_priority_donate_chain+0xa3>
  lock_release (&locks[0]);
c002c36d:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c371:	89 04 24             	mov    %eax,(%esp)
c002c374:	e8 8b 6c ff ff       	call   c0023004 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c379:	e8 bc 4b ff ff       	call   c0020f3a <thread_get_priority>
c002c37e:	89 c3                	mov    %eax,%ebx
c002c380:	e8 18 4b ff ff       	call   c0020e9d <thread_name>
c002c385:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c389:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c38d:	c7 04 24 ec 0c 03 c0 	movl   $0xc0030cec,(%esp)
c002c394:	e8 84 e3 ff ff       	call   c002a71d <msg>
}
c002c399:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002c39f:	5b                   	pop    %ebx
c002c3a0:	5e                   	pop    %esi
c002c3a1:	5f                   	pop    %edi
c002c3a2:	5d                   	pop    %ebp
c002c3a3:	c3                   	ret    
c002c3a4:	90                   	nop
c002c3a5:	90                   	nop
c002c3a6:	90                   	nop
c002c3a7:	90                   	nop
c002c3a8:	90                   	nop
c002c3a9:	90                   	nop
c002c3aa:	90                   	nop
c002c3ab:	90                   	nop
c002c3ac:	90                   	nop
c002c3ad:	90                   	nop
c002c3ae:	90                   	nop
c002c3af:	90                   	nop

c002c3b0 <test_mlfqs_load_1>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_mlfqs_load_1 (void) 
{
c002c3b0:	57                   	push   %edi
c002c3b1:	56                   	push   %esi
c002c3b2:	53                   	push   %ebx
c002c3b3:	83 ec 20             	sub    $0x20,%esp
  int64_t start_time;
  int elapsed;
  int load_avg;
  
  ASSERT (thread_mlfqs);
c002c3b6:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c3bd:	75 2c                	jne    c002c3eb <test_mlfqs_load_1+0x3b>
c002c3bf:	c7 44 24 10 a9 00 03 	movl   $0xc00300a9,0x10(%esp)
c002c3c6:	c0 
c002c3c7:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002c3ce:	c0 
c002c3cf:	c7 44 24 08 4b e0 02 	movl   $0xc002e04b,0x8(%esp)
c002c3d6:	c0 
c002c3d7:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002c3de:	00 
c002c3df:	c7 04 24 94 0d 03 c0 	movl   $0xc0030d94,(%esp)
c002c3e6:	e8 78 c5 ff ff       	call   c0028963 <debug_panic>

  msg ("spinning for up to 45 seconds, please wait...");
c002c3eb:	c7 04 24 b8 0d 03 c0 	movl   $0xc0030db8,(%esp)
c002c3f2:	e8 26 e3 ff ff       	call   c002a71d <msg>

  start_time = timer_ticks ();
c002c3f7:	e8 f4 7d ff ff       	call   c00241f0 <timer_ticks>
c002c3fc:	89 44 24 18          	mov    %eax,0x18(%esp)
c002c400:	89 54 24 1c          	mov    %edx,0x1c(%esp)
    {
      load_avg = thread_get_load_avg ();
      ASSERT (load_avg >= 0);
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
      if (load_avg > 100)
        fail ("load average is %d.%02d "
c002c404:	bf 1f 85 eb 51       	mov    $0x51eb851f,%edi
      load_avg = thread_get_load_avg ();
c002c409:	e8 4a 4b ff ff       	call   c0020f58 <thread_get_load_avg>
c002c40e:	89 c3                	mov    %eax,%ebx
      ASSERT (load_avg >= 0);
c002c410:	85 c0                	test   %eax,%eax
c002c412:	79 2c                	jns    c002c440 <test_mlfqs_load_1+0x90>
c002c414:	c7 44 24 10 6a 0d 03 	movl   $0xc0030d6a,0x10(%esp)
c002c41b:	c0 
c002c41c:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002c423:	c0 
c002c424:	c7 44 24 08 4b e0 02 	movl   $0xc002e04b,0x8(%esp)
c002c42b:	c0 
c002c42c:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002c433:	00 
c002c434:	c7 04 24 94 0d 03 c0 	movl   $0xc0030d94,(%esp)
c002c43b:	e8 23 c5 ff ff       	call   c0028963 <debug_panic>
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
c002c440:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c444:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c448:	89 04 24             	mov    %eax,(%esp)
c002c44b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c44f:	e8 c8 7d ff ff       	call   c002421c <timer_elapsed>
c002c454:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c45b:	00 
c002c45c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c463:	00 
c002c464:	89 04 24             	mov    %eax,(%esp)
c002c467:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c46b:	e8 53 be ff ff       	call   c00282c3 <__divdi3>
c002c470:	89 c6                	mov    %eax,%esi
      if (load_avg > 100)
c002c472:	83 fb 64             	cmp    $0x64,%ebx
c002c475:	7e 30                	jle    c002c4a7 <test_mlfqs_load_1+0xf7>
        fail ("load average is %d.%02d "
c002c477:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c47b:	89 d8                	mov    %ebx,%eax
c002c47d:	f7 ef                	imul   %edi
c002c47f:	c1 fa 05             	sar    $0x5,%edx
c002c482:	89 d8                	mov    %ebx,%eax
c002c484:	c1 f8 1f             	sar    $0x1f,%eax
c002c487:	29 c2                	sub    %eax,%edx
c002c489:	6b c2 64             	imul   $0x64,%edx,%eax
c002c48c:	29 c3                	sub    %eax,%ebx
c002c48e:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c492:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c496:	c7 04 24 e8 0d 03 c0 	movl   $0xc0030de8,(%esp)
c002c49d:	e8 33 e3 ff ff       	call   c002a7d5 <fail>
c002c4a2:	e9 62 ff ff ff       	jmp    c002c409 <test_mlfqs_load_1+0x59>
              "but should be between 0 and 1 (after %d seconds)",
              load_avg / 100, load_avg % 100, elapsed);
      else if (load_avg > 50)
c002c4a7:	83 fb 32             	cmp    $0x32,%ebx
c002c4aa:	7f 1b                	jg     c002c4c7 <test_mlfqs_load_1+0x117>
        break;
      else if (elapsed > 45)
c002c4ac:	83 f8 2d             	cmp    $0x2d,%eax
c002c4af:	90                   	nop
c002c4b0:	0f 8e 53 ff ff ff    	jle    c002c409 <test_mlfqs_load_1+0x59>
        fail ("load average stayed below 0.5 for more than 45 seconds");
c002c4b6:	c7 04 24 34 0e 03 c0 	movl   $0xc0030e34,(%esp)
c002c4bd:	e8 13 e3 ff ff       	call   c002a7d5 <fail>
c002c4c2:	e9 42 ff ff ff       	jmp    c002c409 <test_mlfqs_load_1+0x59>
    }

  if (elapsed < 38)
c002c4c7:	83 f8 25             	cmp    $0x25,%eax
c002c4ca:	7f 10                	jg     c002c4dc <test_mlfqs_load_1+0x12c>
    fail ("load average took only %d seconds to rise above 0.5", elapsed);
c002c4cc:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c4d0:	c7 04 24 6c 0e 03 c0 	movl   $0xc0030e6c,(%esp)
c002c4d7:	e8 f9 e2 ff ff       	call   c002a7d5 <fail>
  msg ("load average rose to 0.5 after %d seconds", elapsed);
c002c4dc:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c4e0:	c7 04 24 a0 0e 03 c0 	movl   $0xc0030ea0,(%esp)
c002c4e7:	e8 31 e2 ff ff       	call   c002a71d <msg>

  msg ("sleeping for another 10 seconds, please wait...");
c002c4ec:	c7 04 24 cc 0e 03 c0 	movl   $0xc0030ecc,(%esp)
c002c4f3:	e8 25 e2 ff ff       	call   c002a71d <msg>
  timer_sleep (TIMER_FREQ * 10);
c002c4f8:	c7 04 24 e8 03 00 00 	movl   $0x3e8,(%esp)
c002c4ff:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002c506:	00 
c002c507:	e8 2c 7d ff ff       	call   c0024238 <timer_sleep>

  load_avg = thread_get_load_avg ();
c002c50c:	e8 47 4a ff ff       	call   c0020f58 <thread_get_load_avg>
c002c511:	89 c3                	mov    %eax,%ebx
  if (load_avg < 0)
c002c513:	85 c0                	test   %eax,%eax
c002c515:	79 0c                	jns    c002c523 <test_mlfqs_load_1+0x173>
    fail ("load average fell below 0");
c002c517:	c7 04 24 78 0d 03 c0 	movl   $0xc0030d78,(%esp)
c002c51e:	e8 b2 e2 ff ff       	call   c002a7d5 <fail>
  if (load_avg > 50)
c002c523:	83 fb 32             	cmp    $0x32,%ebx
c002c526:	7e 0c                	jle    c002c534 <test_mlfqs_load_1+0x184>
    fail ("load average stayed above 0.5 for more than 10 seconds");
c002c528:	c7 04 24 fc 0e 03 c0 	movl   $0xc0030efc,(%esp)
c002c52f:	e8 a1 e2 ff ff       	call   c002a7d5 <fail>
  msg ("load average fell back below 0.5 (to %d.%02d)",
c002c534:	ba 1f 85 eb 51       	mov    $0x51eb851f,%edx
c002c539:	89 d8                	mov    %ebx,%eax
c002c53b:	f7 ea                	imul   %edx
c002c53d:	c1 fa 05             	sar    $0x5,%edx
c002c540:	89 d8                	mov    %ebx,%eax
c002c542:	c1 f8 1f             	sar    $0x1f,%eax
c002c545:	29 c2                	sub    %eax,%edx
c002c547:	6b c2 64             	imul   $0x64,%edx,%eax
c002c54a:	29 c3                	sub    %eax,%ebx
c002c54c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c550:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c554:	c7 04 24 34 0f 03 c0 	movl   $0xc0030f34,(%esp)
c002c55b:	e8 bd e1 ff ff       	call   c002a71d <msg>
       load_avg / 100, load_avg % 100);

  pass ();
c002c560:	e8 cc e2 ff ff       	call   c002a831 <pass>
}
c002c565:	83 c4 20             	add    $0x20,%esp
c002c568:	5b                   	pop    %ebx
c002c569:	5e                   	pop    %esi
c002c56a:	5f                   	pop    %edi
c002c56b:	c3                   	ret    
c002c56c:	90                   	nop
c002c56d:	90                   	nop
c002c56e:	90                   	nop
c002c56f:	90                   	nop

c002c570 <load_thread>:
    }
}

static void
load_thread (void *aux UNUSED) 
{
c002c570:	53                   	push   %ebx
c002c571:	83 ec 18             	sub    $0x18,%esp
  int64_t sleep_time = 10 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 60 * TIMER_FREQ;
  int64_t exit_time = spin_time + 60 * TIMER_FREQ;

  thread_set_nice (20);
c002c574:	c7 04 24 14 00 00 00 	movl   $0x14,(%esp)
c002c57b:	e8 b8 51 ff ff       	call   c0021738 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c580:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c585:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c58b:	89 04 24             	mov    %eax,(%esp)
c002c58e:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c592:	e8 85 7c ff ff       	call   c002421c <timer_elapsed>
c002c597:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002c59c:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c5a1:	29 c1                	sub    %eax,%ecx
c002c5a3:	19 d3                	sbb    %edx,%ebx
c002c5a5:	89 0c 24             	mov    %ecx,(%esp)
c002c5a8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c5ac:	e8 87 7c ff ff       	call   c0024238 <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c5b1:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5b6:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5bc:	89 04 24             	mov    %eax,(%esp)
c002c5bf:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5c3:	e8 54 7c ff ff       	call   c002421c <timer_elapsed>
c002c5c8:	85 d2                	test   %edx,%edx
c002c5ca:	7f 0b                	jg     c002c5d7 <load_thread+0x67>
c002c5cc:	85 d2                	test   %edx,%edx
c002c5ce:	78 e1                	js     c002c5b1 <load_thread+0x41>
c002c5d0:	3d 57 1b 00 00       	cmp    $0x1b57,%eax
c002c5d5:	76 da                	jbe    c002c5b1 <load_thread+0x41>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c5d7:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5dc:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5e2:	89 04 24             	mov    %eax,(%esp)
c002c5e5:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5e9:	e8 2e 7c ff ff       	call   c002421c <timer_elapsed>
c002c5ee:	b9 c8 32 00 00       	mov    $0x32c8,%ecx
c002c5f3:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c5f8:	29 c1                	sub    %eax,%ecx
c002c5fa:	19 d3                	sbb    %edx,%ebx
c002c5fc:	89 0c 24             	mov    %ecx,(%esp)
c002c5ff:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c603:	e8 30 7c ff ff       	call   c0024238 <timer_sleep>
}
c002c608:	83 c4 18             	add    $0x18,%esp
c002c60b:	5b                   	pop    %ebx
c002c60c:	c3                   	ret    

c002c60d <test_mlfqs_load_60>:
{
c002c60d:	55                   	push   %ebp
c002c60e:	57                   	push   %edi
c002c60f:	56                   	push   %esi
c002c610:	53                   	push   %ebx
c002c611:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c614:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c61b:	75 2c                	jne    c002c649 <test_mlfqs_load_60+0x3c>
c002c61d:	c7 44 24 10 a9 00 03 	movl   $0xc00300a9,0x10(%esp)
c002c624:	c0 
c002c625:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002c62c:	c0 
c002c62d:	c7 44 24 08 5d e0 02 	movl   $0xc002e05d,0x8(%esp)
c002c634:	c0 
c002c635:	c7 44 24 04 77 00 00 	movl   $0x77,0x4(%esp)
c002c63c:	00 
c002c63d:	c7 04 24 6c 0f 03 c0 	movl   $0xc0030f6c,(%esp)
c002c644:	e8 1a c3 ff ff       	call   c0028963 <debug_panic>
  start_time = timer_ticks ();
c002c649:	e8 a2 7b ff ff       	call   c00241f0 <timer_ticks>
c002c64e:	a3 a8 7b 03 c0       	mov    %eax,0xc0037ba8
c002c653:	89 15 ac 7b 03 c0    	mov    %edx,0xc0037bac
  msg ("Starting %d niced load threads...", THREAD_CNT);
c002c659:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c660:	00 
c002c661:	c7 04 24 90 0f 03 c0 	movl   $0xc0030f90,(%esp)
c002c668:	e8 b0 e0 ff ff       	call   c002a71d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c66d:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c672:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c676:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c67a:	c7 44 24 08 62 0f 03 	movl   $0xc0030f62,0x8(%esp)
c002c681:	c0 
c002c682:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c689:	00 
c002c68a:	89 34 24             	mov    %esi,(%esp)
c002c68d:	e8 7d ab ff ff       	call   c002720f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, NULL);
c002c692:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c699:	00 
c002c69a:	c7 44 24 08 70 c5 02 	movl   $0xc002c570,0x8(%esp)
c002c6a1:	c0 
c002c6a2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c6a9:	00 
c002c6aa:	89 34 24             	mov    %esi,(%esp)
c002c6ad:	e8 75 4e ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c6b2:	83 c3 01             	add    $0x1,%ebx
c002c6b5:	83 fb 3c             	cmp    $0x3c,%ebx
c002c6b8:	75 bc                	jne    c002c676 <test_mlfqs_load_60+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c6ba:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c6bf:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c6c5:	89 04 24             	mov    %eax,(%esp)
c002c6c8:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c6cc:	e8 4b 7b ff ff       	call   c002421c <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c6d1:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c6d8:	00 
c002c6d9:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c6e0:	00 
c002c6e1:	89 04 24             	mov    %eax,(%esp)
c002c6e4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c6e8:	e8 d6 bb ff ff       	call   c00282c3 <__divdi3>
c002c6ed:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c6f1:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c6f5:	c7 04 24 b4 0f 03 c0 	movl   $0xc0030fb4,(%esp)
c002c6fc:	e8 1c e0 ff ff       	call   c002a71d <msg>
c002c701:	b3 00                	mov    $0x0,%bl
c002c703:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c708:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c70d:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c712:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c716:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c71a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c71e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c722:	03 05 a8 7b 03 c0    	add    0xc0037ba8,%eax
c002c728:	13 15 ac 7b 03 c0    	adc    0xc0037bac,%edx
c002c72e:	89 c6                	mov    %eax,%esi
c002c730:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c732:	e8 b9 7a ff ff       	call   c00241f0 <timer_ticks>
c002c737:	29 c6                	sub    %eax,%esi
c002c739:	19 d7                	sbb    %edx,%edi
c002c73b:	89 34 24             	mov    %esi,(%esp)
c002c73e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c742:	e8 f1 7a ff ff       	call   c0024238 <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c747:	e8 0c 48 ff ff       	call   c0020f58 <thread_get_load_avg>
c002c74c:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c74e:	f7 ed                	imul   %ebp
c002c750:	c1 fa 05             	sar    $0x5,%edx
c002c753:	89 c8                	mov    %ecx,%eax
c002c755:	c1 f8 1f             	sar    $0x1f,%eax
c002c758:	29 c2                	sub    %eax,%edx
c002c75a:	6b c2 64             	imul   $0x64,%edx,%eax
c002c75d:	29 c1                	sub    %eax,%ecx
c002c75f:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c763:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c767:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c76b:	c7 04 24 d8 0f 03 c0 	movl   $0xc0030fd8,(%esp)
c002c772:	e8 a6 df ff ff       	call   c002a71d <msg>
c002c777:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c77e:	00 
c002c77f:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c784:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c787:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c78d:	75 8b                	jne    c002c71a <test_mlfqs_load_60+0x10d>
}
c002c78f:	83 c4 3c             	add    $0x3c,%esp
c002c792:	5b                   	pop    %ebx
c002c793:	5e                   	pop    %esi
c002c794:	5f                   	pop    %edi
c002c795:	5d                   	pop    %ebp
c002c796:	c3                   	ret    
c002c797:	90                   	nop
c002c798:	90                   	nop
c002c799:	90                   	nop
c002c79a:	90                   	nop
c002c79b:	90                   	nop
c002c79c:	90                   	nop
c002c79d:	90                   	nop
c002c79e:	90                   	nop
c002c79f:	90                   	nop

c002c7a0 <load_thread>:
    }
}

static void
load_thread (void *seq_no_) 
{
c002c7a0:	57                   	push   %edi
c002c7a1:	56                   	push   %esi
c002c7a2:	53                   	push   %ebx
c002c7a3:	83 ec 10             	sub    $0x10,%esp
  int seq_no = (int) seq_no_;
  int sleep_time = TIMER_FREQ * (10 + seq_no);
c002c7a6:	8b 44 24 20          	mov    0x20(%esp),%eax
c002c7aa:	8d 70 0a             	lea    0xa(%eax),%esi
c002c7ad:	6b f6 64             	imul   $0x64,%esi,%esi
  int spin_time = sleep_time + TIMER_FREQ * THREAD_CNT;
c002c7b0:	8d 9e 70 17 00 00    	lea    0x1770(%esi),%ebx
  int exit_time = TIMER_FREQ * (THREAD_CNT * 2);

  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c7b6:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c7bb:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c7c1:	89 04 24             	mov    %eax,(%esp)
c002c7c4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c7c8:	e8 4f 7a ff ff       	call   c002421c <timer_elapsed>
c002c7cd:	89 f7                	mov    %esi,%edi
c002c7cf:	c1 ff 1f             	sar    $0x1f,%edi
c002c7d2:	29 c6                	sub    %eax,%esi
c002c7d4:	19 d7                	sbb    %edx,%edi
c002c7d6:	89 34 24             	mov    %esi,(%esp)
c002c7d9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c7dd:	e8 56 7a ff ff       	call   c0024238 <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c7e2:	89 df                	mov    %ebx,%edi
c002c7e4:	c1 ff 1f             	sar    $0x1f,%edi
c002c7e7:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c7ec:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c7f2:	89 04 24             	mov    %eax,(%esp)
c002c7f5:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c7f9:	e8 1e 7a ff ff       	call   c002421c <timer_elapsed>
c002c7fe:	39 fa                	cmp    %edi,%edx
c002c800:	7f 06                	jg     c002c808 <load_thread+0x68>
c002c802:	7c e3                	jl     c002c7e7 <load_thread+0x47>
c002c804:	39 d8                	cmp    %ebx,%eax
c002c806:	72 df                	jb     c002c7e7 <load_thread+0x47>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c808:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c80d:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c813:	89 04 24             	mov    %eax,(%esp)
c002c816:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c81a:	e8 fd 79 ff ff       	call   c002421c <timer_elapsed>
c002c81f:	b9 e0 2e 00 00       	mov    $0x2ee0,%ecx
c002c824:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c829:	29 c1                	sub    %eax,%ecx
c002c82b:	19 d3                	sbb    %edx,%ebx
c002c82d:	89 0c 24             	mov    %ecx,(%esp)
c002c830:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c834:	e8 ff 79 ff ff       	call   c0024238 <timer_sleep>
}
c002c839:	83 c4 10             	add    $0x10,%esp
c002c83c:	5b                   	pop    %ebx
c002c83d:	5e                   	pop    %esi
c002c83e:	5f                   	pop    %edi
c002c83f:	c3                   	ret    

c002c840 <test_mlfqs_load_avg>:
{
c002c840:	55                   	push   %ebp
c002c841:	57                   	push   %edi
c002c842:	56                   	push   %esi
c002c843:	53                   	push   %ebx
c002c844:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c847:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c84e:	75 2c                	jne    c002c87c <test_mlfqs_load_avg+0x3c>
c002c850:	c7 44 24 10 a9 00 03 	movl   $0xc00300a9,0x10(%esp)
c002c857:	c0 
c002c858:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002c85f:	c0 
c002c860:	c7 44 24 08 70 e0 02 	movl   $0xc002e070,0x8(%esp)
c002c867:	c0 
c002c868:	c7 44 24 04 82 00 00 	movl   $0x82,0x4(%esp)
c002c86f:	00 
c002c870:	c7 04 24 1c 10 03 c0 	movl   $0xc003101c,(%esp)
c002c877:	e8 e7 c0 ff ff       	call   c0028963 <debug_panic>
  start_time = timer_ticks ();
c002c87c:	e8 6f 79 ff ff       	call   c00241f0 <timer_ticks>
c002c881:	a3 b0 7b 03 c0       	mov    %eax,0xc0037bb0
c002c886:	89 15 b4 7b 03 c0    	mov    %edx,0xc0037bb4
  msg ("Starting %d load threads...", THREAD_CNT);
c002c88c:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c893:	00 
c002c894:	c7 04 24 00 10 03 c0 	movl   $0xc0031000,(%esp)
c002c89b:	e8 7d de ff ff       	call   c002a71d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c8a0:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c8a5:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c8a9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c8ad:	c7 44 24 08 62 0f 03 	movl   $0xc0030f62,0x8(%esp)
c002c8b4:	c0 
c002c8b5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c8bc:	00 
c002c8bd:	89 34 24             	mov    %esi,(%esp)
c002c8c0:	e8 4a a9 ff ff       	call   c002720f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, (void *) i);
c002c8c5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c8c9:	c7 44 24 08 a0 c7 02 	movl   $0xc002c7a0,0x8(%esp)
c002c8d0:	c0 
c002c8d1:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c8d8:	00 
c002c8d9:	89 34 24             	mov    %esi,(%esp)
c002c8dc:	e8 46 4c ff ff       	call   c0021527 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c8e1:	83 c3 01             	add    $0x1,%ebx
c002c8e4:	83 fb 3c             	cmp    $0x3c,%ebx
c002c8e7:	75 c0                	jne    c002c8a9 <test_mlfqs_load_avg+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c8e9:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c8ee:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c8f4:	89 04 24             	mov    %eax,(%esp)
c002c8f7:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c8fb:	e8 1c 79 ff ff       	call   c002421c <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c900:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c907:	00 
c002c908:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c90f:	00 
c002c910:	89 04 24             	mov    %eax,(%esp)
c002c913:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c917:	e8 a7 b9 ff ff       	call   c00282c3 <__divdi3>
c002c91c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c920:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c924:	c7 04 24 b4 0f 03 c0 	movl   $0xc0030fb4,(%esp)
c002c92b:	e8 ed dd ff ff       	call   c002a71d <msg>
  thread_set_nice (-20);
c002c930:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002c937:	e8 fc 4d ff ff       	call   c0021738 <thread_set_nice>
c002c93c:	b3 00                	mov    $0x0,%bl
c002c93e:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c943:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c948:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c94d:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c951:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c955:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c959:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c95d:	03 05 b0 7b 03 c0    	add    0xc0037bb0,%eax
c002c963:	13 15 b4 7b 03 c0    	adc    0xc0037bb4,%edx
c002c969:	89 c6                	mov    %eax,%esi
c002c96b:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c96d:	e8 7e 78 ff ff       	call   c00241f0 <timer_ticks>
c002c972:	29 c6                	sub    %eax,%esi
c002c974:	19 d7                	sbb    %edx,%edi
c002c976:	89 34 24             	mov    %esi,(%esp)
c002c979:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c97d:	e8 b6 78 ff ff       	call   c0024238 <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c982:	e8 d1 45 ff ff       	call   c0020f58 <thread_get_load_avg>
c002c987:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c989:	f7 ed                	imul   %ebp
c002c98b:	c1 fa 05             	sar    $0x5,%edx
c002c98e:	89 c8                	mov    %ecx,%eax
c002c990:	c1 f8 1f             	sar    $0x1f,%eax
c002c993:	29 c2                	sub    %eax,%edx
c002c995:	6b c2 64             	imul   $0x64,%edx,%eax
c002c998:	29 c1                	sub    %eax,%ecx
c002c99a:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c99e:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c9a2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c9a6:	c7 04 24 d8 0f 03 c0 	movl   $0xc0030fd8,(%esp)
c002c9ad:	e8 6b dd ff ff       	call   c002a71d <msg>
c002c9b2:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c9b9:	00 
c002c9ba:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c9bf:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c9c2:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c9c8:	75 8b                	jne    c002c955 <test_mlfqs_load_avg+0x115>
}
c002c9ca:	83 c4 3c             	add    $0x3c,%esp
c002c9cd:	5b                   	pop    %ebx
c002c9ce:	5e                   	pop    %esi
c002c9cf:	5f                   	pop    %edi
c002c9d0:	5d                   	pop    %ebp
c002c9d1:	c3                   	ret    

c002c9d2 <test_mlfqs_recent_1>:
/* Sensitive to assumption that recent_cpu updates happen exactly
   when timer_ticks() % TIMER_FREQ == 0. */

void
test_mlfqs_recent_1 (void) 
{
c002c9d2:	55                   	push   %ebp
c002c9d3:	57                   	push   %edi
c002c9d4:	56                   	push   %esi
c002c9d5:	53                   	push   %ebx
c002c9d6:	83 ec 2c             	sub    $0x2c,%esp
  int64_t start_time;
  int last_elapsed = 0;
  
  ASSERT (thread_mlfqs);
c002c9d9:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002c9e0:	75 2c                	jne    c002ca0e <test_mlfqs_recent_1+0x3c>
c002c9e2:	c7 44 24 10 a9 00 03 	movl   $0xc00300a9,0x10(%esp)
c002c9e9:	c0 
c002c9ea:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002c9f1:	c0 
c002c9f2:	c7 44 24 08 84 e0 02 	movl   $0xc002e084,0x8(%esp)
c002c9f9:	c0 
c002c9fa:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c002ca01:	00 
c002ca02:	c7 04 24 44 10 03 c0 	movl   $0xc0031044,(%esp)
c002ca09:	e8 55 bf ff ff       	call   c0028963 <debug_panic>

  do 
    {
      msg ("Sleeping 10 seconds to allow recent_cpu to decay, please wait...");
c002ca0e:	c7 04 24 6c 10 03 c0 	movl   $0xc003106c,(%esp)
c002ca15:	e8 03 dd ff ff       	call   c002a71d <msg>
      start_time = timer_ticks ();
c002ca1a:	e8 d1 77 ff ff       	call   c00241f0 <timer_ticks>
c002ca1f:	89 c7                	mov    %eax,%edi
c002ca21:	89 d5                	mov    %edx,%ebp
      timer_sleep (DIV_ROUND_UP (start_time, TIMER_FREQ) - start_time
c002ca23:	83 c0 63             	add    $0x63,%eax
c002ca26:	83 d2 00             	adc    $0x0,%edx
c002ca29:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002ca30:	00 
c002ca31:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002ca38:	00 
c002ca39:	89 04 24             	mov    %eax,(%esp)
c002ca3c:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca40:	e8 7e b8 ff ff       	call   c00282c3 <__divdi3>
c002ca45:	29 f8                	sub    %edi,%eax
c002ca47:	19 ea                	sbb    %ebp,%edx
c002ca49:	05 e8 03 00 00       	add    $0x3e8,%eax
c002ca4e:	83 d2 00             	adc    $0x0,%edx
c002ca51:	89 04 24             	mov    %eax,(%esp)
c002ca54:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca58:	e8 db 77 ff ff       	call   c0024238 <timer_sleep>
                   + 10 * TIMER_FREQ);
    }
  while (thread_get_recent_cpu () > 700);
c002ca5d:	e8 0c 45 ff ff       	call   c0020f6e <thread_get_recent_cpu>
c002ca62:	3d bc 02 00 00       	cmp    $0x2bc,%eax
c002ca67:	7f a5                	jg     c002ca0e <test_mlfqs_recent_1+0x3c>

  start_time = timer_ticks ();
c002ca69:	e8 82 77 ff ff       	call   c00241f0 <timer_ticks>
c002ca6e:	89 44 24 18          	mov    %eax,0x18(%esp)
c002ca72:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  int last_elapsed = 0;
c002ca76:	be 00 00 00 00       	mov    $0x0,%esi
  for (;;) 
    {
      int elapsed = timer_elapsed (start_time);
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002ca7b:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002ca80:	eb 02                	jmp    c002ca84 <test_mlfqs_recent_1+0xb2>
c002ca82:	89 de                	mov    %ebx,%esi
      int elapsed = timer_elapsed (start_time);
c002ca84:	8b 44 24 18          	mov    0x18(%esp),%eax
c002ca88:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002ca8c:	89 04 24             	mov    %eax,(%esp)
c002ca8f:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca93:	e8 84 77 ff ff       	call   c002421c <timer_elapsed>
c002ca98:	89 c3                	mov    %eax,%ebx
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002ca9a:	f7 ed                	imul   %ebp
c002ca9c:	c1 fa 06             	sar    $0x6,%edx
c002ca9f:	89 d8                	mov    %ebx,%eax
c002caa1:	c1 f8 1f             	sar    $0x1f,%eax
c002caa4:	29 c2                	sub    %eax,%edx
c002caa6:	69 d2 c8 00 00 00    	imul   $0xc8,%edx,%edx
c002caac:	39 d3                	cmp    %edx,%ebx
c002caae:	75 d2                	jne    c002ca82 <test_mlfqs_recent_1+0xb0>
c002cab0:	39 de                	cmp    %ebx,%esi
c002cab2:	7d ce                	jge    c002ca82 <test_mlfqs_recent_1+0xb0>
        {
          int recent_cpu = thread_get_recent_cpu ();
c002cab4:	e8 b5 44 ff ff       	call   c0020f6e <thread_get_recent_cpu>
c002cab9:	89 c6                	mov    %eax,%esi
          int load_avg = thread_get_load_avg ();
c002cabb:	e8 98 44 ff ff       	call   c0020f58 <thread_get_load_avg>
c002cac0:	89 c1                	mov    %eax,%ecx
          int elapsed_seconds = elapsed / TIMER_FREQ;
c002cac2:	89 d8                	mov    %ebx,%eax
c002cac4:	f7 ed                	imul   %ebp
c002cac6:	89 d7                	mov    %edx,%edi
c002cac8:	c1 ff 05             	sar    $0x5,%edi
c002cacb:	89 d8                	mov    %ebx,%eax
c002cacd:	c1 f8 1f             	sar    $0x1f,%eax
c002cad0:	29 c7                	sub    %eax,%edi
          msg ("After %d seconds, recent_cpu is %d.%02d, load_avg is %d.%02d.",
c002cad2:	89 c8                	mov    %ecx,%eax
c002cad4:	f7 ed                	imul   %ebp
c002cad6:	c1 fa 05             	sar    $0x5,%edx
c002cad9:	89 c8                	mov    %ecx,%eax
c002cadb:	c1 f8 1f             	sar    $0x1f,%eax
c002cade:	29 c2                	sub    %eax,%edx
c002cae0:	6b c2 64             	imul   $0x64,%edx,%eax
c002cae3:	29 c1                	sub    %eax,%ecx
c002cae5:	89 4c 24 14          	mov    %ecx,0x14(%esp)
c002cae9:	89 54 24 10          	mov    %edx,0x10(%esp)
c002caed:	89 f0                	mov    %esi,%eax
c002caef:	f7 ed                	imul   %ebp
c002caf1:	c1 fa 05             	sar    $0x5,%edx
c002caf4:	89 f0                	mov    %esi,%eax
c002caf6:	c1 f8 1f             	sar    $0x1f,%eax
c002caf9:	29 c2                	sub    %eax,%edx
c002cafb:	6b c2 64             	imul   $0x64,%edx,%eax
c002cafe:	29 c6                	sub    %eax,%esi
c002cb00:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002cb04:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cb08:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002cb0c:	c7 04 24 b0 10 03 c0 	movl   $0xc00310b0,(%esp)
c002cb13:	e8 05 dc ff ff       	call   c002a71d <msg>
               elapsed_seconds,
               recent_cpu / 100, recent_cpu % 100,
               load_avg / 100, load_avg % 100);
          if (elapsed_seconds >= 180)
c002cb18:	81 ff b3 00 00 00    	cmp    $0xb3,%edi
c002cb1e:	0f 8e 5e ff ff ff    	jle    c002ca82 <test_mlfqs_recent_1+0xb0>
            break;
        } 
      last_elapsed = elapsed;
    }
}
c002cb24:	83 c4 2c             	add    $0x2c,%esp
c002cb27:	5b                   	pop    %ebx
c002cb28:	5e                   	pop    %esi
c002cb29:	5f                   	pop    %edi
c002cb2a:	5d                   	pop    %ebp
c002cb2b:	c3                   	ret    
c002cb2c:	90                   	nop
c002cb2d:	90                   	nop
c002cb2e:	90                   	nop
c002cb2f:	90                   	nop

c002cb30 <test_mlfqs_fair>:

static void load_thread (void *aux);

static void
test_mlfqs_fair (int thread_cnt, int nice_min, int nice_step)
{
c002cb30:	55                   	push   %ebp
c002cb31:	57                   	push   %edi
c002cb32:	56                   	push   %esi
c002cb33:	53                   	push   %ebx
c002cb34:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
c002cb3a:	89 4c 24 14          	mov    %ecx,0x14(%esp)
  struct thread_info info[MAX_THREAD_CNT];
  int64_t start_time;
  int nice;
  int i;

  ASSERT (thread_mlfqs);
c002cb3e:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002cb45:	75 2c                	jne    c002cb73 <test_mlfqs_fair+0x43>
c002cb47:	c7 44 24 10 a9 00 03 	movl   $0xc00300a9,0x10(%esp)
c002cb4e:	c0 
c002cb4f:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002cb56:	c0 
c002cb57:	c7 44 24 08 98 e0 02 	movl   $0xc002e098,0x8(%esp)
c002cb5e:	c0 
c002cb5f:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
c002cb66:	00 
c002cb67:	c7 04 24 60 11 03 c0 	movl   $0xc0031160,(%esp)
c002cb6e:	e8 f0 bd ff ff       	call   c0028963 <debug_panic>
c002cb73:	89 c5                	mov    %eax,%ebp
c002cb75:	89 d7                	mov    %edx,%edi
  ASSERT (thread_cnt <= MAX_THREAD_CNT);
c002cb77:	83 f8 14             	cmp    $0x14,%eax
c002cb7a:	7e 2c                	jle    c002cba8 <test_mlfqs_fair+0x78>
c002cb7c:	c7 44 24 10 ee 10 03 	movl   $0xc00310ee,0x10(%esp)
c002cb83:	c0 
c002cb84:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002cb8b:	c0 
c002cb8c:	c7 44 24 08 98 e0 02 	movl   $0xc002e098,0x8(%esp)
c002cb93:	c0 
c002cb94:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c002cb9b:	00 
c002cb9c:	c7 04 24 60 11 03 c0 	movl   $0xc0031160,(%esp)
c002cba3:	e8 bb bd ff ff       	call   c0028963 <debug_panic>
  ASSERT (nice_min >= -10);
c002cba8:	83 fa f6             	cmp    $0xfffffff6,%edx
c002cbab:	7d 2c                	jge    c002cbd9 <test_mlfqs_fair+0xa9>
c002cbad:	c7 44 24 10 0b 11 03 	movl   $0xc003110b,0x10(%esp)
c002cbb4:	c0 
c002cbb5:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002cbbc:	c0 
c002cbbd:	c7 44 24 08 98 e0 02 	movl   $0xc002e098,0x8(%esp)
c002cbc4:	c0 
c002cbc5:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002cbcc:	00 
c002cbcd:	c7 04 24 60 11 03 c0 	movl   $0xc0031160,(%esp)
c002cbd4:	e8 8a bd ff ff       	call   c0028963 <debug_panic>
  ASSERT (nice_step >= 0);
c002cbd9:	83 7c 24 14 00       	cmpl   $0x0,0x14(%esp)
c002cbde:	79 2c                	jns    c002cc0c <test_mlfqs_fair+0xdc>
c002cbe0:	c7 44 24 10 1b 11 03 	movl   $0xc003111b,0x10(%esp)
c002cbe7:	c0 
c002cbe8:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002cbef:	c0 
c002cbf0:	c7 44 24 08 98 e0 02 	movl   $0xc002e098,0x8(%esp)
c002cbf7:	c0 
c002cbf8:	c7 44 24 04 4c 00 00 	movl   $0x4c,0x4(%esp)
c002cbff:	00 
c002cc00:	c7 04 24 60 11 03 c0 	movl   $0xc0031160,(%esp)
c002cc07:	e8 57 bd ff ff       	call   c0028963 <debug_panic>
  ASSERT (nice_min + nice_step * (thread_cnt - 1) <= 20);
c002cc0c:	8d 40 ff             	lea    -0x1(%eax),%eax
c002cc0f:	0f af 44 24 14       	imul   0x14(%esp),%eax
c002cc14:	01 d0                	add    %edx,%eax
c002cc16:	83 f8 14             	cmp    $0x14,%eax
c002cc19:	7e 2c                	jle    c002cc47 <test_mlfqs_fair+0x117>
c002cc1b:	c7 44 24 10 84 11 03 	movl   $0xc0031184,0x10(%esp)
c002cc22:	c0 
c002cc23:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002cc2a:	c0 
c002cc2b:	c7 44 24 08 98 e0 02 	movl   $0xc002e098,0x8(%esp)
c002cc32:	c0 
c002cc33:	c7 44 24 04 4d 00 00 	movl   $0x4d,0x4(%esp)
c002cc3a:	00 
c002cc3b:	c7 04 24 60 11 03 c0 	movl   $0xc0031160,(%esp)
c002cc42:	e8 1c bd ff ff       	call   c0028963 <debug_panic>

  thread_set_nice (-20);
c002cc47:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002cc4e:	e8 e5 4a ff ff       	call   c0021738 <thread_set_nice>

  start_time = timer_ticks ();
c002cc53:	e8 98 75 ff ff       	call   c00241f0 <timer_ticks>
c002cc58:	89 44 24 18          	mov    %eax,0x18(%esp)
c002cc5c:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  msg ("Starting %d threads...", thread_cnt);
c002cc60:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002cc64:	c7 04 24 2a 11 03 c0 	movl   $0xc003112a,(%esp)
c002cc6b:	e8 ad da ff ff       	call   c002a71d <msg>
  nice = nice_min;
  for (i = 0; i < thread_cnt; i++) 
c002cc70:	85 ed                	test   %ebp,%ebp
c002cc72:	0f 8e e1 00 00 00    	jle    c002cd59 <test_mlfqs_fair+0x229>
c002cc78:	8d 5c 24 30          	lea    0x30(%esp),%ebx
c002cc7c:	be 00 00 00 00       	mov    $0x0,%esi
    {
      struct thread_info *ti = &info[i];
      char name[16];

      ti->start_time = start_time;
c002cc81:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cc85:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cc89:	89 03                	mov    %eax,(%ebx)
c002cc8b:	89 53 04             	mov    %edx,0x4(%ebx)
      ti->tick_count = 0;
c002cc8e:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
      ti->nice = nice;
c002cc95:	89 7b 0c             	mov    %edi,0xc(%ebx)

      snprintf(name, sizeof name, "load %d", i);
c002cc98:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002cc9c:	c7 44 24 08 62 0f 03 	movl   $0xc0030f62,0x8(%esp)
c002cca3:	c0 
c002cca4:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002ccab:	00 
c002ccac:	8d 44 24 20          	lea    0x20(%esp),%eax
c002ccb0:	89 04 24             	mov    %eax,(%esp)
c002ccb3:	e8 57 a5 ff ff       	call   c002720f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, ti);
c002ccb8:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002ccbc:	c7 44 24 08 ac cd 02 	movl   $0xc002cdac,0x8(%esp)
c002ccc3:	c0 
c002ccc4:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cccb:	00 
c002cccc:	8d 44 24 20          	lea    0x20(%esp),%eax
c002ccd0:	89 04 24             	mov    %eax,(%esp)
c002ccd3:	e8 4f 48 ff ff       	call   c0021527 <thread_create>

      nice += nice_step;
c002ccd8:	03 7c 24 14          	add    0x14(%esp),%edi
  for (i = 0; i < thread_cnt; i++) 
c002ccdc:	83 c6 01             	add    $0x1,%esi
c002ccdf:	83 c3 10             	add    $0x10,%ebx
c002cce2:	39 ee                	cmp    %ebp,%esi
c002cce4:	75 9b                	jne    c002cc81 <test_mlfqs_fair+0x151>
    }
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cce6:	8b 44 24 18          	mov    0x18(%esp),%eax
c002ccea:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002ccee:	89 04 24             	mov    %eax,(%esp)
c002ccf1:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ccf5:	e8 22 75 ff ff       	call   c002421c <timer_elapsed>
c002ccfa:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ccfe:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd02:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cd09:	e8 0f da ff ff       	call   c002a71d <msg>

  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cd0e:	c7 04 24 d8 11 03 c0 	movl   $0xc00311d8,(%esp)
c002cd15:	e8 03 da ff ff       	call   c002a71d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cd1a:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cd21:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cd28:	00 
c002cd29:	e8 0a 75 ff ff       	call   c0024238 <timer_sleep>
  
  for (i = 0; i < thread_cnt; i++)
c002cd2e:	bb 00 00 00 00       	mov    $0x0,%ebx
c002cd33:	89 d8                	mov    %ebx,%eax
c002cd35:	c1 e0 04             	shl    $0x4,%eax
    msg ("Thread %d received %d ticks.", i, info[i].tick_count);
c002cd38:	8b 44 04 38          	mov    0x38(%esp,%eax,1),%eax
c002cd3c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002cd40:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002cd44:	c7 04 24 41 11 03 c0 	movl   $0xc0031141,(%esp)
c002cd4b:	e8 cd d9 ff ff       	call   c002a71d <msg>
  for (i = 0; i < thread_cnt; i++)
c002cd50:	83 c3 01             	add    $0x1,%ebx
c002cd53:	39 eb                	cmp    %ebp,%ebx
c002cd55:	75 dc                	jne    c002cd33 <test_mlfqs_fair+0x203>
c002cd57:	eb 48                	jmp    c002cda1 <test_mlfqs_fair+0x271>
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cd59:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cd5d:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cd61:	89 04 24             	mov    %eax,(%esp)
c002cd64:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cd68:	e8 af 74 ff ff       	call   c002421c <timer_elapsed>
c002cd6d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cd71:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd75:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cd7c:	e8 9c d9 ff ff       	call   c002a71d <msg>
  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cd81:	c7 04 24 d8 11 03 c0 	movl   $0xc00311d8,(%esp)
c002cd88:	e8 90 d9 ff ff       	call   c002a71d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cd8d:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cd94:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cd9b:	00 
c002cd9c:	e8 97 74 ff ff       	call   c0024238 <timer_sleep>
}
c002cda1:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002cda7:	5b                   	pop    %ebx
c002cda8:	5e                   	pop    %esi
c002cda9:	5f                   	pop    %edi
c002cdaa:	5d                   	pop    %ebp
c002cdab:	c3                   	ret    

c002cdac <load_thread>:

static void
load_thread (void *ti_) 
{
c002cdac:	57                   	push   %edi
c002cdad:	56                   	push   %esi
c002cdae:	53                   	push   %ebx
c002cdaf:	83 ec 10             	sub    $0x10,%esp
c002cdb2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread_info *ti = ti_;
  int64_t sleep_time = 5 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 30 * TIMER_FREQ;
  int64_t last_time = 0;

  thread_set_nice (ti->nice);
c002cdb6:	8b 43 0c             	mov    0xc(%ebx),%eax
c002cdb9:	89 04 24             	mov    %eax,(%esp)
c002cdbc:	e8 77 49 ff ff       	call   c0021738 <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (ti->start_time));
c002cdc1:	8b 03                	mov    (%ebx),%eax
c002cdc3:	8b 53 04             	mov    0x4(%ebx),%edx
c002cdc6:	89 04 24             	mov    %eax,(%esp)
c002cdc9:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cdcd:	e8 4a 74 ff ff       	call   c002421c <timer_elapsed>
c002cdd2:	be f4 01 00 00       	mov    $0x1f4,%esi
c002cdd7:	bf 00 00 00 00       	mov    $0x0,%edi
c002cddc:	29 c6                	sub    %eax,%esi
c002cdde:	19 d7                	sbb    %edx,%edi
c002cde0:	89 34 24             	mov    %esi,(%esp)
c002cde3:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002cde7:	e8 4c 74 ff ff       	call   c0024238 <timer_sleep>
  int64_t last_time = 0;
c002cdec:	bf 00 00 00 00       	mov    $0x0,%edi
c002cdf1:	be 00 00 00 00       	mov    $0x0,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002cdf6:	eb 15                	jmp    c002ce0d <load_thread+0x61>
    {
      int64_t cur_time = timer_ticks ();
c002cdf8:	e8 f3 73 ff ff       	call   c00241f0 <timer_ticks>
      if (cur_time != last_time)
c002cdfd:	31 d6                	xor    %edx,%esi
c002cdff:	31 c7                	xor    %eax,%edi
c002ce01:	09 fe                	or     %edi,%esi
c002ce03:	74 04                	je     c002ce09 <load_thread+0x5d>
        ti->tick_count++;
c002ce05:	83 43 08 01          	addl   $0x1,0x8(%ebx)
{
c002ce09:	89 c7                	mov    %eax,%edi
c002ce0b:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce0d:	8b 03                	mov    (%ebx),%eax
c002ce0f:	8b 53 04             	mov    0x4(%ebx),%edx
c002ce12:	89 04 24             	mov    %eax,(%esp)
c002ce15:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ce19:	e8 fe 73 ff ff       	call   c002421c <timer_elapsed>
c002ce1e:	85 d2                	test   %edx,%edx
c002ce20:	78 d6                	js     c002cdf8 <load_thread+0x4c>
c002ce22:	85 d2                	test   %edx,%edx
c002ce24:	7f 07                	jg     c002ce2d <load_thread+0x81>
c002ce26:	3d ab 0d 00 00       	cmp    $0xdab,%eax
c002ce2b:	76 cb                	jbe    c002cdf8 <load_thread+0x4c>
      last_time = cur_time;
    }
}
c002ce2d:	83 c4 10             	add    $0x10,%esp
c002ce30:	5b                   	pop    %ebx
c002ce31:	5e                   	pop    %esi
c002ce32:	5f                   	pop    %edi
c002ce33:	c3                   	ret    

c002ce34 <test_mlfqs_fair_2>:
{
c002ce34:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 0);
c002ce37:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce3c:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce41:	b8 02 00 00 00       	mov    $0x2,%eax
c002ce46:	e8 e5 fc ff ff       	call   c002cb30 <test_mlfqs_fair>
}
c002ce4b:	83 c4 0c             	add    $0xc,%esp
c002ce4e:	c3                   	ret    

c002ce4f <test_mlfqs_fair_20>:
{
c002ce4f:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (20, 0, 0);
c002ce52:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce57:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce5c:	b8 14 00 00 00       	mov    $0x14,%eax
c002ce61:	e8 ca fc ff ff       	call   c002cb30 <test_mlfqs_fair>
}
c002ce66:	83 c4 0c             	add    $0xc,%esp
c002ce69:	c3                   	ret    

c002ce6a <test_mlfqs_nice_2>:
{
c002ce6a:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 5);
c002ce6d:	b9 05 00 00 00       	mov    $0x5,%ecx
c002ce72:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce77:	b8 02 00 00 00       	mov    $0x2,%eax
c002ce7c:	e8 af fc ff ff       	call   c002cb30 <test_mlfqs_fair>
}
c002ce81:	83 c4 0c             	add    $0xc,%esp
c002ce84:	c3                   	ret    

c002ce85 <test_mlfqs_nice_10>:
{
c002ce85:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (10, 0, 1);
c002ce88:	b9 01 00 00 00       	mov    $0x1,%ecx
c002ce8d:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce92:	b8 0a 00 00 00       	mov    $0xa,%eax
c002ce97:	e8 94 fc ff ff       	call   c002cb30 <test_mlfqs_fair>
}
c002ce9c:	83 c4 0c             	add    $0xc,%esp
c002ce9f:	c3                   	ret    

c002cea0 <block_thread>:
  msg ("Block thread should have already acquired lock.");
}

static void
block_thread (void *lock_) 
{
c002cea0:	56                   	push   %esi
c002cea1:	53                   	push   %ebx
c002cea2:	83 ec 14             	sub    $0x14,%esp
  struct lock *lock = lock_;
  int64_t start_time;

  msg ("Block thread spinning for 20 seconds...");
c002cea5:	c7 04 24 10 12 03 c0 	movl   $0xc0031210,(%esp)
c002ceac:	e8 6c d8 ff ff       	call   c002a71d <msg>
  start_time = timer_ticks ();
c002ceb1:	e8 3a 73 ff ff       	call   c00241f0 <timer_ticks>
c002ceb6:	89 c3                	mov    %eax,%ebx
c002ceb8:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 20 * TIMER_FREQ)
c002ceba:	89 1c 24             	mov    %ebx,(%esp)
c002cebd:	89 74 24 04          	mov    %esi,0x4(%esp)
c002cec1:	e8 56 73 ff ff       	call   c002421c <timer_elapsed>
c002cec6:	85 d2                	test   %edx,%edx
c002cec8:	7f 0b                	jg     c002ced5 <block_thread+0x35>
c002ceca:	85 d2                	test   %edx,%edx
c002cecc:	78 ec                	js     c002ceba <block_thread+0x1a>
c002cece:	3d cf 07 00 00       	cmp    $0x7cf,%eax
c002ced3:	76 e5                	jbe    c002ceba <block_thread+0x1a>
    continue;

  msg ("Block thread acquiring lock...");
c002ced5:	c7 04 24 38 12 03 c0 	movl   $0xc0031238,(%esp)
c002cedc:	e8 3c d8 ff ff       	call   c002a71d <msg>
  lock_acquire (lock);
c002cee1:	8b 44 24 20          	mov    0x20(%esp),%eax
c002cee5:	89 04 24             	mov    %eax,(%esp)
c002cee8:	e8 4d 5f ff ff       	call   c0022e3a <lock_acquire>

  msg ("...got it.");
c002ceed:	c7 04 24 10 13 03 c0 	movl   $0xc0031310,(%esp)
c002cef4:	e8 24 d8 ff ff       	call   c002a71d <msg>
}
c002cef9:	83 c4 14             	add    $0x14,%esp
c002cefc:	5b                   	pop    %ebx
c002cefd:	5e                   	pop    %esi
c002cefe:	c3                   	ret    

c002ceff <test_mlfqs_block>:
{
c002ceff:	56                   	push   %esi
c002cf00:	53                   	push   %ebx
c002cf01:	83 ec 54             	sub    $0x54,%esp
  ASSERT (thread_mlfqs);
c002cf04:	80 3d bc 7b 03 c0 00 	cmpb   $0x0,0xc0037bbc
c002cf0b:	75 2c                	jne    c002cf39 <test_mlfqs_block+0x3a>
c002cf0d:	c7 44 24 10 a9 00 03 	movl   $0xc00300a9,0x10(%esp)
c002cf14:	c0 
c002cf15:	c7 44 24 0c 31 e1 02 	movl   $0xc002e131,0xc(%esp)
c002cf1c:	c0 
c002cf1d:	c7 44 24 08 a8 e0 02 	movl   $0xc002e0a8,0x8(%esp)
c002cf24:	c0 
c002cf25:	c7 44 24 04 1c 00 00 	movl   $0x1c,0x4(%esp)
c002cf2c:	00 
c002cf2d:	c7 04 24 58 12 03 c0 	movl   $0xc0031258,(%esp)
c002cf34:	e8 2a ba ff ff       	call   c0028963 <debug_panic>
  msg ("Main thread acquiring lock.");
c002cf39:	c7 04 24 1b 13 03 c0 	movl   $0xc003131b,(%esp)
c002cf40:	e8 d8 d7 ff ff       	call   c002a71d <msg>
  lock_init (&lock);
c002cf45:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002cf49:	89 1c 24             	mov    %ebx,(%esp)
c002cf4c:	e8 4c 5e ff ff       	call   c0022d9d <lock_init>
  lock_acquire (&lock);
c002cf51:	89 1c 24             	mov    %ebx,(%esp)
c002cf54:	e8 e1 5e ff ff       	call   c0022e3a <lock_acquire>
  msg ("Main thread creating block thread, sleeping 25 seconds...");
c002cf59:	c7 04 24 7c 12 03 c0 	movl   $0xc003127c,(%esp)
c002cf60:	e8 b8 d7 ff ff       	call   c002a71d <msg>
  thread_create ("block", PRI_DEFAULT, block_thread, &lock);
c002cf65:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cf69:	c7 44 24 08 a0 ce 02 	movl   $0xc002cea0,0x8(%esp)
c002cf70:	c0 
c002cf71:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cf78:	00 
c002cf79:	c7 04 24 a2 00 03 c0 	movl   $0xc00300a2,(%esp)
c002cf80:	e8 a2 45 ff ff       	call   c0021527 <thread_create>
  timer_sleep (25 * TIMER_FREQ);
c002cf85:	c7 04 24 c4 09 00 00 	movl   $0x9c4,(%esp)
c002cf8c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cf93:	00 
c002cf94:	e8 9f 72 ff ff       	call   c0024238 <timer_sleep>
  msg ("Main thread spinning for 5 seconds...");
c002cf99:	c7 04 24 b8 12 03 c0 	movl   $0xc00312b8,(%esp)
c002cfa0:	e8 78 d7 ff ff       	call   c002a71d <msg>
  start_time = timer_ticks ();
c002cfa5:	e8 46 72 ff ff       	call   c00241f0 <timer_ticks>
c002cfaa:	89 c3                	mov    %eax,%ebx
c002cfac:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 5 * TIMER_FREQ)
c002cfae:	89 1c 24             	mov    %ebx,(%esp)
c002cfb1:	89 74 24 04          	mov    %esi,0x4(%esp)
c002cfb5:	e8 62 72 ff ff       	call   c002421c <timer_elapsed>
c002cfba:	85 d2                	test   %edx,%edx
c002cfbc:	7f 0b                	jg     c002cfc9 <test_mlfqs_block+0xca>
c002cfbe:	85 d2                	test   %edx,%edx
c002cfc0:	78 ec                	js     c002cfae <test_mlfqs_block+0xaf>
c002cfc2:	3d f3 01 00 00       	cmp    $0x1f3,%eax
c002cfc7:	76 e5                	jbe    c002cfae <test_mlfqs_block+0xaf>
  msg ("Main thread releasing lock.");
c002cfc9:	c7 04 24 37 13 03 c0 	movl   $0xc0031337,(%esp)
c002cfd0:	e8 48 d7 ff ff       	call   c002a71d <msg>
  lock_release (&lock);
c002cfd5:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c002cfd9:	89 04 24             	mov    %eax,(%esp)
c002cfdc:	e8 23 60 ff ff       	call   c0023004 <lock_release>
  msg ("Block thread should have already acquired lock.");
c002cfe1:	c7 04 24 e0 12 03 c0 	movl   $0xc00312e0,(%esp)
c002cfe8:	e8 30 d7 ff ff       	call   c002a71d <msg>
}
c002cfed:	83 c4 54             	add    $0x54,%esp
c002cff0:	5b                   	pop    %ebx
c002cff1:	5e                   	pop    %esi
c002cff2:	c3                   	ret    
