
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
c00201a6:	e8 73 69 00 00       	call   c0026b1e <printf>
#ifdef USERPROG
  process_wait (process_execute (task));
#else
  run_test (task);
c00201ab:	89 1c 24             	mov    %ebx,(%esp)
c00201ae:	e8 b6 a5 00 00       	call   c002a769 <run_test>
#endif
  printf ("Execution of '%s' complete.\n", task);
c00201b3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00201b7:	c7 04 24 0a e1 02 c0 	movl   $0xc002e10a,(%esp)
c00201be:	e8 5b 69 00 00       	call   c0026b1e <printf>
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
c00201d4:	2d 88 5a 03 c0       	sub    $0xc0035a88,%eax
c00201d9:	89 44 24 08          	mov    %eax,0x8(%esp)
c00201dd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00201e4:	00 
c00201e5:	c7 04 24 88 5a 03 c0 	movl   $0xc0035a88,(%esp)
c00201ec:	e8 40 7c 00 00       	call   c0027e31 <memset>
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
c0020236:	e8 38 87 00 00       	call   c0028973 <debug_panic>
      argv[i] = p;
c002023b:	89 1c b5 a0 5a 03 c0 	mov    %ebx,-0x3ffca560(,%esi,4)
      p += strnlen (p, end - p) + 1;
c0020242:	89 e8                	mov    %ebp,%eax
c0020244:	29 d8                	sub    %ebx,%eax
c0020246:	89 44 24 04          	mov    %eax,0x4(%esp)
c002024a:	89 1c 24             	mov    %ebx,(%esp)
c002024d:	e8 08 7d 00 00       	call   c0027f5a <strnlen>
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
c002026f:	e8 aa 68 00 00       	call   c0026b1e <printf>
  for (i = 0; i < argc; i++)
c0020274:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (argv[i], ' ') == NULL)
c0020279:	8b 34 9d a0 5a 03 c0 	mov    -0x3ffca560(,%ebx,4),%esi
c0020280:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c0020287:	00 
c0020288:	89 34 24             	mov    %esi,(%esp)
c002028b:	e8 16 79 00 00       	call   c0027ba6 <strchr>
c0020290:	85 c0                	test   %eax,%eax
c0020292:	75 12                	jne    c00202a6 <pintos_init+0xde>
      printf (" %s", argv[i]);
c0020294:	89 74 24 04          	mov    %esi,0x4(%esp)
c0020298:	c7 04 24 47 ef 02 c0 	movl   $0xc002ef47,(%esp)
c002029f:	e8 7a 68 00 00       	call   c0026b1e <printf>
c00202a4:	eb 10                	jmp    c00202b6 <pintos_init+0xee>
      printf (" '%s'", argv[i]);
c00202a6:	89 74 24 04          	mov    %esi,0x4(%esp)
c00202aa:	c7 04 24 3c e1 02 c0 	movl   $0xc002e13c,(%esp)
c00202b1:	e8 68 68 00 00       	call   c0026b1e <printf>
  for (i = 0; i < argc; i++)
c00202b6:	83 c3 01             	add    $0x1,%ebx
c00202b9:	39 df                	cmp    %ebx,%edi
c00202bb:	75 bc                	jne    c0020279 <pintos_init+0xb1>
  printf ("\n");
c00202bd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00202c4:	e8 43 a4 00 00       	call   c002a70c <putchar>
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
c00202f7:	e8 18 7a 00 00       	call   c0027d14 <strtok_r>
c00202fc:	89 c3                	mov    %eax,%ebx
      char *value = strtok_r (NULL, "", &save_ptr);
c00202fe:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c0020302:	89 44 24 08          	mov    %eax,0x8(%esp)
c0020306:	c7 44 24 04 eb ed 02 	movl   $0xc002edeb,0x4(%esp)
c002030d:	c0 
c002030e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0020315:	e8 fa 79 00 00       	call   c0027d14 <strtok_r>
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
c0020339:	e8 5d a3 00 00       	call   c002a69b <puts>
          "  -mlfqs             Use multi-level feedback queue scheduler.\n"
#ifdef USERPROG
          "  -ul=COUNT          Limit user memory to COUNT pages.\n"
#endif
          );
  shutdown_power_off ();
c002033e:	e8 bc 60 00 00       	call   c00263ff <shutdown_power_off>
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
c0020362:	e8 19 60 00 00       	call   c0026380 <shutdown_configure>
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
c002038b:	e8 f0 5f 00 00       	call   c0026380 <shutdown_configure>
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
c00203ad:	e8 ce 71 00 00       	call   c0027580 <atoi>
c00203b2:	89 04 24             	mov    %eax,(%esp)
c00203b5:	e8 11 62 00 00       	call   c00265cb <random_init>
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
c00203d4:	c6 05 c0 7b 03 c0 01 	movb   $0x1,0xc0037bc0
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
c0020400:	e8 6e 85 00 00       	call   c0028973 <debug_panic>
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
c0020427:	e8 f0 5d 00 00       	call   c002621c <rtc_get_time>
c002042c:	89 04 24             	mov    %eax,(%esp)
c002042f:	e8 97 61 00 00       	call   c00265cb <random_init>
  thread_init ();
c0020434:	e8 44 06 00 00       	call   c0020a7d <thread_init>
  console_init ();  
c0020439:	e8 d4 a1 00 00       	call   c002a612 <console_init>
          init_ram_pages * PGSIZE / 1024);
c002043e:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c0020443:	c1 e0 0c             	shl    $0xc,%eax
  printf ("Pintos booting with %'"PRIu32" kB RAM...\n",
c0020446:	c1 e8 0a             	shr    $0xa,%eax
c0020449:	89 44 24 04          	mov    %eax,0x4(%esp)
c002044d:	c7 04 24 4c e4 02 c0 	movl   $0xc002e44c,(%esp)
c0020454:	e8 c5 66 00 00       	call   c0026b1e <printf>
  palloc_init (user_page_limit);
c0020459:	c7 04 24 ff ff ff ff 	movl   $0xffffffff,(%esp)
c0020460:	e8 eb 2e 00 00       	call   c0023350 <palloc_init>
  malloc_init ();
c0020465:	e8 6d 33 00 00       	call   c00237d7 <malloc_init>
  pd = init_page_dir = palloc_get_page (PAL_ASSERT | PAL_ZERO);
c002046a:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
c0020471:	e8 40 30 00 00       	call   c00234b6 <palloc_get_page>
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
c00204d0:	e8 9e 84 00 00       	call   c0028973 <debug_panic>
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
c0020526:	e8 8b 2f 00 00       	call   c00234b6 <palloc_get_page>
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
c002055b:	e8 13 84 00 00       	call   c0028973 <debug_panic>
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
c002058e:	e8 e0 83 00 00       	call   c0028973 <debug_panic>

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
c00205d8:	e8 96 83 00 00       	call   c0028973 <debug_panic>
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
c0020638:	e8 36 83 00 00       	call   c0028973 <debug_panic>
  return (uintptr_t) vaddr - (uintptr_t) PHYS_BASE;
c002063d:	05 00 00 00 40       	add    $0x40000000,%eax
c0020642:	0f 22 d8             	mov    %eax,%cr3
  intr_init ();
c0020645:	e8 27 12 00 00       	call   c0021871 <intr_init>
  timer_init ();
c002064a:	e8 80 3a 00 00       	call   c00240cf <timer_init>
  kbd_init ();
c002064f:	e8 e7 3f 00 00       	call   c002463b <kbd_init>
  input_init ();
c0020654:	e8 ac 56 00 00       	call   c0025d05 <input_init>
  thread_start ();
c0020659:	e8 8f 0e 00 00       	call   c00214ed <thread_start>
c002065e:	66 90                	xchg   %ax,%ax
  serial_init_queue ();
c0020660:	e8 21 44 00 00       	call   c0024a86 <serial_init_queue>
  timer_calibrate ();
c0020665:	e8 b0 3a 00 00       	call   c002411a <timer_calibrate>
  printf ("Boot complete.\n");
c002066a:	c7 04 24 db e1 02 c0 	movl   $0xc002e1db,(%esp)
c0020671:	e8 25 a0 00 00       	call   c002a69b <puts>
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
c00206a0:	e8 e2 73 00 00       	call   c0027a87 <strcmp>
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
c00206e6:	e8 88 82 00 00       	call   c0028973 <debug_panic>
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
c002071c:	e8 52 82 00 00       	call   c0028973 <debug_panic>
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
c0020766:	e8 1b 78 00 00       	call   c0027f86 <strlcpy>
      printf("ICS143A>");
c002076b:	c7 04 24 ea e1 02 c0 	movl   $0xc002e1ea,(%esp)
c0020772:	e8 a7 63 00 00       	call   c0026b1e <printf>
        char l = input_getc();
c0020777:	e8 32 56 00 00       	call   c0025dae <input_getc>
c002077c:	89 c3                	mov    %eax,%ebx
        while(l != '\n'){
c002077e:	3c 0a                	cmp    $0xa,%al
c0020780:	74 24                	je     c00207a6 <pintos_init+0x5de>
c0020782:	be 00 00 00 00       	mov    $0x0,%esi
          printf("%c",l);
c0020787:	0f be c3             	movsbl %bl,%eax
c002078a:	89 04 24             	mov    %eax,(%esp)
c002078d:	e8 7a 9f 00 00       	call   c002a70c <putchar>
          cmdline[i] = l;
c0020792:	88 5c 34 3c          	mov    %bl,0x3c(%esp,%esi,1)
          l = input_getc();
c0020796:	e8 13 56 00 00       	call   c0025dae <input_getc>
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
c00207ce:	e8 c8 9e 00 00       	call   c002a69b <puts>
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
c00207f6:	e8 11 9f 00 00       	call   c002a70c <putchar>
c00207fb:	eb 26                	jmp    c0020823 <pintos_init+0x65b>
          printf("\ninvalid command\n");
c00207fd:	c7 04 24 0c e2 02 c0 	movl   $0xc002e20c,(%esp)
c0020804:	e8 92 9e 00 00       	call   c002a69b <puts>
        memset(&cmdline[0], 0, sizeof(cmdline));
c0020809:	b9 0c 00 00 00       	mov    $0xc,%ecx
c002080e:	b8 00 00 00 00       	mov    $0x0,%eax
c0020813:	8d 7c 24 3c          	lea    0x3c(%esp),%edi
c0020817:	f3 ab                	rep stos %eax,%es:(%edi)
c0020819:	66 c7 07 00 00       	movw   $0x0,(%edi)
    }
c002081e:	e9 2c ff ff ff       	jmp    c002074f <pintos_init+0x587>
  shutdown ();
c0020823:	e8 58 5c 00 00       	call   c0026480 <shutdown>
  thread_exit ();
c0020828:	e8 2d 0a 00 00       	call   c002125a <thread_exit>
  argv[argc] = NULL;
c002082d:	c7 04 bd a0 5a 03 c0 	movl   $0x0,-0x3ffca560(,%edi,4)
c0020834:	00 00 00 00 
  printf ("Kernel command line:");
c0020838:	c7 04 24 1d e2 02 c0 	movl   $0xc002e21d,(%esp)
c002083f:	e8 da 62 00 00       	call   c0026b1e <printf>
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
c002088e:	c7 44 24 04 c8 02 00 	movl   $0x2c8,0x4(%esp)
c0020895:	00 
c0020896:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c002089d:	e8 d1 80 00 00       	call   c0028973 <debug_panic>
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
c00208c1:	c7 44 24 04 c7 02 00 	movl   $0x2c7,0x4(%esp)
c00208c8:	00 
c00208c9:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00208d0:	e8 9e 80 00 00       	call   c0028973 <debug_panic>

  t->stack -= size;
c00208d5:	8b 40 18             	mov    0x18(%eax),%eax
c00208d8:	29 d0                	sub    %edx,%eax
c00208da:	89 41 18             	mov    %eax,0x18(%ecx)
  return t->stack;
}
c00208dd:	83 c4 2c             	add    $0x2c,%esp
c00208e0:	c3                   	ret    

c00208e1 <init_thread>:
{
c00208e1:	55                   	push   %ebp
c00208e2:	57                   	push   %edi
c00208e3:	56                   	push   %esi
c00208e4:	53                   	push   %ebx
c00208e5:	83 ec 2c             	sub    $0x2c,%esp
c00208e8:	89 c3                	mov    %eax,%ebx
  ASSERT (t != NULL);
c00208ea:	85 c0                	test   %eax,%eax
c00208ec:	75 2c                	jne    c002091a <init_thread+0x39>
c00208ee:	c7 44 24 10 37 fa 02 	movl   $0xc002fa37,0x10(%esp)
c00208f5:	c0 
c00208f6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00208fd:	c0 
c00208fe:	c7 44 24 08 26 d1 02 	movl   $0xc002d126,0x8(%esp)
c0020905:	c0 
c0020906:	c7 44 24 04 9b 02 00 	movl   $0x29b,0x4(%esp)
c002090d:	00 
c002090e:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020915:	e8 59 80 00 00       	call   c0028973 <debug_panic>
c002091a:	89 ce                	mov    %ecx,%esi
  ASSERT (PRI_MIN <= priority && priority <= PRI_MAX);
c002091c:	83 f9 3f             	cmp    $0x3f,%ecx
c002091f:	76 2c                	jbe    c002094d <init_thread+0x6c>
c0020921:	c7 44 24 10 e0 e5 02 	movl   $0xc002e5e0,0x10(%esp)
c0020928:	c0 
c0020929:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020930:	c0 
c0020931:	c7 44 24 08 26 d1 02 	movl   $0xc002d126,0x8(%esp)
c0020938:	c0 
c0020939:	c7 44 24 04 9c 02 00 	movl   $0x29c,0x4(%esp)
c0020940:	00 
c0020941:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020948:	e8 26 80 00 00       	call   c0028973 <debug_panic>
  ASSERT (name != NULL);
c002094d:	85 d2                	test   %edx,%edx
c002094f:	75 2c                	jne    c002097d <init_thread+0x9c>
c0020951:	c7 44 24 10 ff e4 02 	movl   $0xc002e4ff,0x10(%esp)
c0020958:	c0 
c0020959:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020960:	c0 
c0020961:	c7 44 24 08 26 d1 02 	movl   $0xc002d126,0x8(%esp)
c0020968:	c0 
c0020969:	c7 44 24 04 9d 02 00 	movl   $0x29d,0x4(%esp)
c0020970:	00 
c0020971:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020978:	e8 f6 7f 00 00       	call   c0028973 <debug_panic>
  memset (t, 0, sizeof *t);
c002097d:	89 c7                	mov    %eax,%edi
c002097f:	bd 5c 00 00 00       	mov    $0x5c,%ebp
c0020984:	a8 01                	test   $0x1,%al
c0020986:	74 0a                	je     c0020992 <init_thread+0xb1>
c0020988:	c6 00 00             	movb   $0x0,(%eax)
c002098b:	8d 78 01             	lea    0x1(%eax),%edi
c002098e:	66 bd 5b 00          	mov    $0x5b,%bp
c0020992:	f7 c7 02 00 00 00    	test   $0x2,%edi
c0020998:	74 0b                	je     c00209a5 <init_thread+0xc4>
c002099a:	66 c7 07 00 00       	movw   $0x0,(%edi)
c002099f:	83 c7 02             	add    $0x2,%edi
c00209a2:	83 ed 02             	sub    $0x2,%ebp
c00209a5:	89 e9                	mov    %ebp,%ecx
c00209a7:	c1 e9 02             	shr    $0x2,%ecx
c00209aa:	b8 00 00 00 00       	mov    $0x0,%eax
c00209af:	f3 ab                	rep stos %eax,%es:(%edi)
c00209b1:	f7 c5 02 00 00 00    	test   $0x2,%ebp
c00209b7:	74 08                	je     c00209c1 <init_thread+0xe0>
c00209b9:	66 c7 07 00 00       	movw   $0x0,(%edi)
c00209be:	83 c7 02             	add    $0x2,%edi
c00209c1:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c00209c7:	74 03                	je     c00209cc <init_thread+0xeb>
c00209c9:	c6 07 00             	movb   $0x0,(%edi)
  t->status = THREAD_BLOCKED;
c00209cc:	c7 43 04 02 00 00 00 	movl   $0x2,0x4(%ebx)
  strlcpy (t->name, name, sizeof t->name);
c00209d3:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c00209da:	00 
c00209db:	89 54 24 04          	mov    %edx,0x4(%esp)
c00209df:	8d 43 08             	lea    0x8(%ebx),%eax
c00209e2:	89 04 24             	mov    %eax,(%esp)
c00209e5:	e8 9c 75 00 00       	call   c0027f86 <strlcpy>
  t->stack = (uint8_t *) t + PGSIZE;
c00209ea:	8d 83 00 10 00 00    	lea    0x1000(%ebx),%eax
c00209f0:	89 43 18             	mov    %eax,0x18(%ebx)
  t->priority = priority;
c00209f3:	89 73 1c             	mov    %esi,0x1c(%ebx)
  t->magic = THREAD_MAGIC;
c00209f6:	c7 43 30 4b bf 6a cd 	movl   $0xcd6abf4b,0x30(%ebx)
  list_push_back (&all_list, &t->allelem);
c00209fd:	8d 43 20             	lea    0x20(%ebx),%eax
c0020a00:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020a04:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020a0b:	e8 b1 85 00 00       	call   c0028fc1 <list_push_back>
  if(thread_mlfqs)
c0020a10:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020a17:	74 44                	je     c0020a5d <init_thread+0x17c>
    t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020a19:	8b 43 58             	mov    0x58(%ebx),%eax
c0020a1c:	8d 50 03             	lea    0x3(%eax),%edx
c0020a1f:	85 c0                	test   %eax,%eax
c0020a21:	0f 48 c2             	cmovs  %edx,%eax
c0020a24:	c1 f8 02             	sar    $0x2,%eax
c0020a27:	89 04 24             	mov    %eax,(%esp)
c0020a2a:	e8 e2 31 00 00       	call   c0023c11 <convertXtoIntRoundNear>
c0020a2f:	ba 3f 00 00 00       	mov    $0x3f,%edx
c0020a34:	29 c2                	sub    %eax,%edx
c0020a36:	89 d0                	mov    %edx,%eax
c0020a38:	8b 53 54             	mov    0x54(%ebx),%edx
c0020a3b:	f7 da                	neg    %edx
c0020a3d:	8d 04 50             	lea    (%eax,%edx,2),%eax
    if(t->priority > PRI_MAX){
c0020a40:	83 f8 3f             	cmp    $0x3f,%eax
c0020a43:	7e 09                	jle    c0020a4e <init_thread+0x16d>
      t->priority = PRI_MAX;
c0020a45:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c0020a4c:	eb 15                	jmp    c0020a63 <init_thread+0x182>
    t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020a4e:	85 c0                	test   %eax,%eax
c0020a50:	ba 00 00 00 00       	mov    $0x0,%edx
c0020a55:	0f 48 c2             	cmovs  %edx,%eax
c0020a58:	89 43 1c             	mov    %eax,0x1c(%ebx)
c0020a5b:	eb 06                	jmp    c0020a63 <init_thread+0x182>
    t->priority = priority;
c0020a5d:	89 73 1c             	mov    %esi,0x1c(%ebx)
    t->old_priority = priority;
c0020a60:	89 73 3c             	mov    %esi,0x3c(%ebx)
  list_init (&t->locks_held);
c0020a63:	8d 43 40             	lea    0x40(%ebx),%eax
c0020a66:	89 04 24             	mov    %eax,(%esp)
c0020a69:	e8 d2 7f 00 00       	call   c0028a40 <list_init>
  t->wait_on_lock = NULL;
c0020a6e:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
}
c0020a75:	83 c4 2c             	add    $0x2c,%esp
c0020a78:	5b                   	pop    %ebx
c0020a79:	5e                   	pop    %esi
c0020a7a:	5f                   	pop    %edi
c0020a7b:	5d                   	pop    %ebp
c0020a7c:	c3                   	ret    

c0020a7d <thread_init>:
{
c0020a7d:	56                   	push   %esi
c0020a7e:	53                   	push   %ebx
c0020a7f:	83 ec 24             	sub    $0x24,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0020a82:	e8 7d 0d 00 00       	call   c0021804 <intr_get_level>
c0020a87:	85 c0                	test   %eax,%eax
c0020a89:	74 2c                	je     c0020ab7 <thread_init+0x3a>
c0020a8b:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0020a92:	c0 
c0020a93:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020a9a:	c0 
c0020a9b:	c7 44 24 08 32 d1 02 	movl   $0xc002d132,0x8(%esp)
c0020aa2:	c0 
c0020aa3:	c7 44 24 04 79 00 00 	movl   $0x79,0x4(%esp)
c0020aaa:	00 
c0020aab:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020ab2:	e8 bc 7e 00 00       	call   c0028973 <debug_panic>
  lock_init (&tid_lock);
c0020ab7:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020abe:	e8 8a 21 00 00       	call   c0022c4d <lock_init>
  list_init (&all_list);
c0020ac3:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020aca:	e8 71 7f 00 00       	call   c0028a40 <list_init>
  if(thread_mlfqs) {
c0020acf:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020ad6:	74 1b                	je     c0020af3 <thread_init+0x76>
c0020ad8:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0020add:	be 20 60 03 c0       	mov    $0xc0036020,%esi
      list_init (&mlfqs_list[i]);
c0020ae2:	89 1c 24             	mov    %ebx,(%esp)
c0020ae5:	e8 56 7f 00 00       	call   c0028a40 <list_init>
c0020aea:	83 c3 10             	add    $0x10,%ebx
    for(i=0;i<64;i++)
c0020aed:	39 f3                	cmp    %esi,%ebx
c0020aef:	75 f1                	jne    c0020ae2 <thread_init+0x65>
c0020af1:	eb 0c                	jmp    c0020aff <thread_init+0x82>
    list_init (&ready_list);
c0020af3:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020afa:	e8 41 7f 00 00       	call   c0028a40 <list_init>
  f = power(2,14);
c0020aff:	c7 44 24 04 0e 00 00 	movl   $0xe,0x4(%esp)
c0020b06:	00 
c0020b07:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c0020b0e:	e8 8c 30 00 00       	call   c0023b9f <power>
c0020b13:	a3 bc 7b 03 c0       	mov    %eax,0xc0037bbc
  initial_thread->nice = 0; //nice value of first thread is zero
c0020b18:	a1 04 5c 03 c0       	mov    0xc0035c04,%eax
c0020b1d:	c7 40 54 00 00 00 00 	movl   $0x0,0x54(%eax)
  initial_thread->recent_cpu = 0; //recent_cpu of first thread is zero
c0020b24:	c7 40 58 00 00 00 00 	movl   $0x0,0x58(%eax)
  asm ("mov %%esp, %0" : "=g" (esp));
c0020b2b:	89 e0                	mov    %esp,%eax
  return (void *) ((uintptr_t) va & ~PGMASK);
c0020b2d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  initial_thread = running_thread ();
c0020b32:	a3 04 5c 03 c0       	mov    %eax,0xc0035c04
  init_thread (initial_thread, "main", PRI_DEFAULT);
c0020b37:	b9 1f 00 00 00       	mov    $0x1f,%ecx
c0020b3c:	ba 2a e5 02 c0       	mov    $0xc002e52a,%edx
c0020b41:	e8 9b fd ff ff       	call   c00208e1 <init_thread>
  initial_thread->status = THREAD_RUNNING;
c0020b46:	8b 1d 04 5c 03 c0    	mov    0xc0035c04,%ebx
c0020b4c:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
allocate_tid (void) 
{
  static tid_t next_tid = 1;
  tid_t tid;

  lock_acquire (&tid_lock);
c0020b53:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020b5a:	e8 8b 21 00 00       	call   c0022cea <lock_acquire>
  tid = next_tid++;
c0020b5f:	8b 35 44 56 03 c0    	mov    0xc0035644,%esi
c0020b65:	8d 46 01             	lea    0x1(%esi),%eax
c0020b68:	a3 44 56 03 c0       	mov    %eax,0xc0035644
  lock_release (&tid_lock);
c0020b6d:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0020b74:	e8 3b 23 00 00       	call   c0022eb4 <lock_release>
  initial_thread->tid = allocate_tid ();
c0020b79:	89 33                	mov    %esi,(%ebx)
}
c0020b7b:	83 c4 24             	add    $0x24,%esp
c0020b7e:	5b                   	pop    %ebx
c0020b7f:	5e                   	pop    %esi
c0020b80:	c3                   	ret    

c0020b81 <thread_print_stats>:
{
c0020b81:	83 ec 2c             	sub    $0x2c,%esp
  printf ("Thread: %lld idle ticks, %lld kernel ticks, %lld user ticks\n",
c0020b84:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c0020b8b:	00 
c0020b8c:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c0020b93:	00 
c0020b94:	a1 c8 5b 03 c0       	mov    0xc0035bc8,%eax
c0020b99:	8b 15 cc 5b 03 c0    	mov    0xc0035bcc,%edx
c0020b9f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0020ba3:	89 54 24 10          	mov    %edx,0x10(%esp)
c0020ba7:	a1 d0 5b 03 c0       	mov    0xc0035bd0,%eax
c0020bac:	8b 15 d4 5b 03 c0    	mov    0xc0035bd4,%edx
c0020bb2:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020bb6:	89 54 24 08          	mov    %edx,0x8(%esp)
c0020bba:	c7 04 24 0c e6 02 c0 	movl   $0xc002e60c,(%esp)
c0020bc1:	e8 58 5f 00 00       	call   c0026b1e <printf>
}
c0020bc6:	83 c4 2c             	add    $0x2c,%esp
c0020bc9:	c3                   	ret    

c0020bca <thread_unblock>:
{
c0020bca:	56                   	push   %esi
c0020bcb:	53                   	push   %ebx
c0020bcc:	83 ec 24             	sub    $0x24,%esp
c0020bcf:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  return t != NULL && t->magic == THREAD_MAGIC;
c0020bd3:	85 db                	test   %ebx,%ebx
c0020bd5:	0f 84 96 00 00 00    	je     c0020c71 <thread_unblock+0xa7>
c0020bdb:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c0020be2:	0f 85 89 00 00 00    	jne    c0020c71 <thread_unblock+0xa7>
c0020be8:	eb 75                	jmp    c0020c5f <thread_unblock+0x95>
  ASSERT (t->status == THREAD_BLOCKED);
c0020bea:	c7 44 24 10 2f e5 02 	movl   $0xc002e52f,0x10(%esp)
c0020bf1:	c0 
c0020bf2:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020bf9:	c0 
c0020bfa:	c7 44 24 08 d9 d0 02 	movl   $0xc002d0d9,0x8(%esp)
c0020c01:	c0 
c0020c02:	c7 44 24 04 33 01 00 	movl   $0x133,0x4(%esp)
c0020c09:	00 
c0020c0a:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020c11:	e8 5d 7d 00 00       	call   c0028973 <debug_panic>
  if(thread_mlfqs) {
c0020c16:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0020c1d:	74 1c                	je     c0020c3b <thread_unblock+0x71>
    list_push_back (&mlfqs_list[t->priority], &t->elem);
c0020c1f:	8d 43 28             	lea    0x28(%ebx),%eax
c0020c22:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020c26:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0020c29:	c1 e0 04             	shl    $0x4,%eax
c0020c2c:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c0020c31:	89 04 24             	mov    %eax,(%esp)
c0020c34:	e8 88 83 00 00       	call   c0028fc1 <list_push_back>
c0020c39:	eb 13                	jmp    c0020c4e <thread_unblock+0x84>
    list_push_back (&ready_list, &t->elem);
c0020c3b:	8d 53 28             	lea    0x28(%ebx),%edx
c0020c3e:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020c42:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c0020c49:	e8 73 83 00 00       	call   c0028fc1 <list_push_back>
  t->status = THREAD_READY;
c0020c4e:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  intr_set_level (old_level);
c0020c55:	89 34 24             	mov    %esi,(%esp)
c0020c58:	e8 f9 0b 00 00       	call   c0021856 <intr_set_level>
c0020c5d:	eb 3e                	jmp    c0020c9d <thread_unblock+0xd3>
  old_level = intr_disable ();
c0020c5f:	e8 eb 0b 00 00       	call   c002184f <intr_disable>
c0020c64:	89 c6                	mov    %eax,%esi
  ASSERT (t->status == THREAD_BLOCKED);
c0020c66:	83 7b 04 02          	cmpl   $0x2,0x4(%ebx)
c0020c6a:	74 aa                	je     c0020c16 <thread_unblock+0x4c>
c0020c6c:	e9 79 ff ff ff       	jmp    c0020bea <thread_unblock+0x20>
  ASSERT (is_thread (t));
c0020c71:	c7 44 24 10 f1 e4 02 	movl   $0xc002e4f1,0x10(%esp)
c0020c78:	c0 
c0020c79:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020c80:	c0 
c0020c81:	c7 44 24 08 d9 d0 02 	movl   $0xc002d0d9,0x8(%esp)
c0020c88:	c0 
c0020c89:	c7 44 24 04 30 01 00 	movl   $0x130,0x4(%esp)
c0020c90:	00 
c0020c91:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020c98:	e8 d6 7c 00 00       	call   c0028973 <debug_panic>
}
c0020c9d:	83 c4 24             	add    $0x24,%esp
c0020ca0:	5b                   	pop    %ebx
c0020ca1:	5e                   	pop    %esi
c0020ca2:	c3                   	ret    

c0020ca3 <thread_current>:
{
c0020ca3:	83 ec 2c             	sub    $0x2c,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0020ca6:	89 e0                	mov    %esp,%eax
  return t != NULL && t->magic == THREAD_MAGIC;
c0020ca8:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0020cad:	74 3f                	je     c0020cee <thread_current+0x4b>
c0020caf:	81 78 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%eax)
c0020cb6:	75 36                	jne    c0020cee <thread_current+0x4b>
c0020cb8:	eb 2c                	jmp    c0020ce6 <thread_current+0x43>
  ASSERT (t->status == THREAD_RUNNING);
c0020cba:	c7 44 24 10 4b e5 02 	movl   $0xc002e54b,0x10(%esp)
c0020cc1:	c0 
c0020cc2:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020cc9:	c0 
c0020cca:	c7 44 24 08 ca d0 02 	movl   $0xc002d0ca,0x8(%esp)
c0020cd1:	c0 
c0020cd2:	c7 44 24 04 57 01 00 	movl   $0x157,0x4(%esp)
c0020cd9:	00 
c0020cda:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020ce1:	e8 8d 7c 00 00       	call   c0028973 <debug_panic>
c0020ce6:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0020cea:	74 2e                	je     c0020d1a <thread_current+0x77>
c0020cec:	eb cc                	jmp    c0020cba <thread_current+0x17>
  ASSERT (is_thread (t));
c0020cee:	c7 44 24 10 f1 e4 02 	movl   $0xc002e4f1,0x10(%esp)
c0020cf5:	c0 
c0020cf6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020cfd:	c0 
c0020cfe:	c7 44 24 08 ca d0 02 	movl   $0xc002d0ca,0x8(%esp)
c0020d05:	c0 
c0020d06:	c7 44 24 04 56 01 00 	movl   $0x156,0x4(%esp)
c0020d0d:	00 
c0020d0e:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020d15:	e8 59 7c 00 00       	call   c0028973 <debug_panic>
}
c0020d1a:	83 c4 2c             	add    $0x2c,%esp
c0020d1d:	c3                   	ret    

c0020d1e <thread_tick>:
{
c0020d1e:	83 ec 0c             	sub    $0xc,%esp
  struct thread *t = thread_current ();
c0020d21:	e8 7d ff ff ff       	call   c0020ca3 <thread_current>
  if (t == idle_thread)
c0020d26:	3b 05 08 5c 03 c0    	cmp    0xc0035c08,%eax
c0020d2c:	75 10                	jne    c0020d3e <thread_tick+0x20>
    idle_ticks++;
c0020d2e:	83 05 d0 5b 03 c0 01 	addl   $0x1,0xc0035bd0
c0020d35:	83 15 d4 5b 03 c0 00 	adcl   $0x0,0xc0035bd4
c0020d3c:	eb 0e                	jmp    c0020d4c <thread_tick+0x2e>
    kernel_ticks++;
c0020d3e:	83 05 c8 5b 03 c0 01 	addl   $0x1,0xc0035bc8
c0020d45:	83 15 cc 5b 03 c0 00 	adcl   $0x0,0xc0035bcc
  if (++thread_ticks >= TIME_SLICE)
c0020d4c:	a1 c0 5b 03 c0       	mov    0xc0035bc0,%eax
c0020d51:	83 c0 01             	add    $0x1,%eax
c0020d54:	a3 c0 5b 03 c0       	mov    %eax,0xc0035bc0
c0020d59:	83 f8 03             	cmp    $0x3,%eax
c0020d5c:	76 05                	jbe    c0020d63 <thread_tick+0x45>
    intr_yield_on_return ();
c0020d5e:	e8 56 0d 00 00       	call   c0021ab9 <intr_yield_on_return>
}
c0020d63:	83 c4 0c             	add    $0xc,%esp
c0020d66:	c3                   	ret    

c0020d67 <thread_name>:
{
c0020d67:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->name;
c0020d6a:	e8 34 ff ff ff       	call   c0020ca3 <thread_current>
c0020d6f:	83 c0 08             	add    $0x8,%eax
}
c0020d72:	83 c4 0c             	add    $0xc,%esp
c0020d75:	c3                   	ret    

c0020d76 <thread_tid>:
{
c0020d76:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->tid;
c0020d79:	e8 25 ff ff ff       	call   c0020ca3 <thread_current>
c0020d7e:	8b 00                	mov    (%eax),%eax
}
c0020d80:	83 c4 0c             	add    $0xc,%esp
c0020d83:	c3                   	ret    

c0020d84 <thread_foreach>:
{
c0020d84:	57                   	push   %edi
c0020d85:	56                   	push   %esi
c0020d86:	53                   	push   %ebx
c0020d87:	83 ec 20             	sub    $0x20,%esp
c0020d8a:	8b 74 24 30          	mov    0x30(%esp),%esi
c0020d8e:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0020d92:	e8 6d 0a 00 00       	call   c0021804 <intr_get_level>
c0020d97:	85 c0                	test   %eax,%eax
c0020d99:	74 2c                	je     c0020dc7 <thread_foreach+0x43>
c0020d9b:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0020da2:	c0 
c0020da3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020daa:	c0 
c0020dab:	c7 44 24 08 a2 d0 02 	movl   $0xc002d0a2,0x8(%esp)
c0020db2:	c0 
c0020db3:	c7 44 24 04 9c 01 00 	movl   $0x19c,0x4(%esp)
c0020dba:	00 
c0020dbb:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020dc2:	e8 ac 7b 00 00       	call   c0028973 <debug_panic>
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020dc7:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020dce:	e8 be 7c 00 00       	call   c0028a91 <list_begin>
c0020dd3:	89 c3                	mov    %eax,%ebx
c0020dd5:	eb 16                	jmp    c0020ded <thread_foreach+0x69>
      func (t, aux);
c0020dd7:	89 7c 24 04          	mov    %edi,0x4(%esp)
      struct thread *t = list_entry (e, struct thread, allelem);
c0020ddb:	8d 43 e0             	lea    -0x20(%ebx),%eax
      func (t, aux);
c0020dde:	89 04 24             	mov    %eax,(%esp)
c0020de1:	ff d6                	call   *%esi
       e = list_next (e))
c0020de3:	89 1c 24             	mov    %ebx,(%esp)
c0020de6:	e8 e4 7c 00 00       	call   c0028acf <list_next>
c0020deb:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_list); e != list_end (&all_list);
c0020ded:	c7 04 24 0c 5c 03 c0 	movl   $0xc0035c0c,(%esp)
c0020df4:	e8 2a 7d 00 00       	call   c0028b23 <list_end>
c0020df9:	39 d8                	cmp    %ebx,%eax
c0020dfb:	75 da                	jne    c0020dd7 <thread_foreach+0x53>
}
c0020dfd:	83 c4 20             	add    $0x20,%esp
c0020e00:	5b                   	pop    %ebx
c0020e01:	5e                   	pop    %esi
c0020e02:	5f                   	pop    %edi
c0020e03:	c3                   	ret    

c0020e04 <thread_get_priority>:
{
c0020e04:	83 ec 0c             	sub    $0xc,%esp
  return thread_current ()->priority;
c0020e07:	e8 97 fe ff ff       	call   c0020ca3 <thread_current>
c0020e0c:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0020e0f:	83 c4 0c             	add    $0xc,%esp
c0020e12:	c3                   	ret    

c0020e13 <thread_get_nice>:
{
c0020e13:	83 ec 0c             	sub    $0xc,%esp
  return thread_current()->nice;
c0020e16:	e8 88 fe ff ff       	call   c0020ca3 <thread_current>
c0020e1b:	8b 40 54             	mov    0x54(%eax),%eax
}
c0020e1e:	83 c4 0c             	add    $0xc,%esp
c0020e21:	c3                   	ret    

c0020e22 <thread_get_load_avg>:
{
c0020e22:	83 ec 1c             	sub    $0x1c,%esp
  int i = multXbyN(system_load_avg,100);
c0020e25:	c7 44 24 04 64 00 00 	movl   $0x64,0x4(%esp)
c0020e2c:	00 
c0020e2d:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0020e32:	89 04 24             	mov    %eax,(%esp)
c0020e35:	e8 8d 2e 00 00       	call   c0023cc7 <multXbyN>
  return convertXtoIntRoundNear(i);
c0020e3a:	89 04 24             	mov    %eax,(%esp)
c0020e3d:	e8 cf 2d 00 00       	call   c0023c11 <convertXtoIntRoundNear>
}
c0020e42:	83 c4 1c             	add    $0x1c,%esp
c0020e45:	c3                   	ret    

c0020e46 <thread_get_recent_cpu>:
{
c0020e46:	83 ec 1c             	sub    $0x1c,%esp
  int i = multXbyN(thread_current()->recent_cpu,100);
c0020e49:	e8 55 fe ff ff       	call   c0020ca3 <thread_current>
c0020e4e:	c7 44 24 04 64 00 00 	movl   $0x64,0x4(%esp)
c0020e55:	00 
c0020e56:	8b 40 58             	mov    0x58(%eax),%eax
c0020e59:	89 04 24             	mov    %eax,(%esp)
c0020e5c:	e8 66 2e 00 00       	call   c0023cc7 <multXbyN>
  return convertXtoIntRoundNear(i);
c0020e61:	89 04 24             	mov    %eax,(%esp)
c0020e64:	e8 a8 2d 00 00       	call   c0023c11 <convertXtoIntRoundNear>
}
c0020e69:	83 c4 1c             	add    $0x1c,%esp
c0020e6c:	c3                   	ret    

c0020e6d <calculate_recent_cpu>:
{
c0020e6d:	56                   	push   %esi
c0020e6e:	53                   	push   %ebx
c0020e6f:	83 ec 14             	sub    $0x14,%esp
c0020e72:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  int doub_load = 2 * system_load_avg;
c0020e76:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0020e7b:	8d 34 00             	lea    (%eax,%eax,1),%esi
  int denom = addXandN(doub_load, 1);
c0020e7e:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0020e85:	00 
c0020e86:	89 34 24             	mov    %esi,(%esp)
c0020e89:	e8 c7 2d 00 00       	call   c0023c55 <addXandN>
  int first_part = divXbyY(doub_load,denom);
c0020e8e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0020e92:	89 34 24             	mov    %esi,(%esp)
c0020e95:	e8 37 2e 00 00       	call   c0023cd1 <divXbyY>
  first_part = multXbyY(first_part,t->recent_cpu);
c0020e9a:	8b 53 58             	mov    0x58(%ebx),%edx
c0020e9d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020ea1:	89 04 24             	mov    %eax,(%esp)
c0020ea4:	e8 d0 2d 00 00       	call   c0023c79 <multXbyY>
  t->recent_cpu = addXandN(first_part,t->nice);
c0020ea9:	8b 53 54             	mov    0x54(%ebx),%edx
c0020eac:	89 54 24 04          	mov    %edx,0x4(%esp)
c0020eb0:	89 04 24             	mov    %eax,(%esp)
c0020eb3:	e8 9d 2d 00 00       	call   c0023c55 <addXandN>
c0020eb8:	89 43 58             	mov    %eax,0x58(%ebx)
}
c0020ebb:	83 c4 14             	add    $0x14,%esp
c0020ebe:	5b                   	pop    %ebx
c0020ebf:	5e                   	pop    %esi
c0020ec0:	c3                   	ret    

c0020ec1 <calcPrio>:
{
c0020ec1:	56                   	push   %esi
c0020ec2:	53                   	push   %ebx
c0020ec3:	83 ec 14             	sub    $0x14,%esp
c0020ec6:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  int oldPrio = t->priority;
c0020eca:	8b 73 1c             	mov    0x1c(%ebx),%esi
  t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020ecd:	8b 43 58             	mov    0x58(%ebx),%eax
c0020ed0:	8d 50 03             	lea    0x3(%eax),%edx
c0020ed3:	85 c0                	test   %eax,%eax
c0020ed5:	0f 48 c2             	cmovs  %edx,%eax
c0020ed8:	c1 f8 02             	sar    $0x2,%eax
c0020edb:	89 04 24             	mov    %eax,(%esp)
c0020ede:	e8 2e 2d 00 00       	call   c0023c11 <convertXtoIntRoundNear>
c0020ee3:	ba 3f 00 00 00       	mov    $0x3f,%edx
c0020ee8:	29 c2                	sub    %eax,%edx
c0020eea:	89 d0                	mov    %edx,%eax
c0020eec:	8b 53 54             	mov    0x54(%ebx),%edx
c0020eef:	f7 da                	neg    %edx
c0020ef1:	8d 04 50             	lea    (%eax,%edx,2),%eax
  if(t->priority > PRI_MAX)
c0020ef4:	83 f8 3f             	cmp    $0x3f,%eax
c0020ef7:	7e 09                	jle    c0020f02 <calcPrio+0x41>
    t->priority = PRI_MAX;
c0020ef9:	c7 43 1c 3f 00 00 00 	movl   $0x3f,0x1c(%ebx)
c0020f00:	eb 0d                	jmp    c0020f0f <calcPrio+0x4e>
  t->priority = PRI_MAX - convertXtoIntRoundNear(t->recent_cpu / 4) - (t->nice * 2);
c0020f02:	85 c0                	test   %eax,%eax
c0020f04:	ba 00 00 00 00       	mov    $0x0,%edx
c0020f09:	0f 48 c2             	cmovs  %edx,%eax
c0020f0c:	89 43 1c             	mov    %eax,0x1c(%ebx)
  if(oldPrio != t->priority && t->status == THREAD_READY)
c0020f0f:	39 73 1c             	cmp    %esi,0x1c(%ebx)
c0020f12:	74 28                	je     c0020f3c <calcPrio+0x7b>
c0020f14:	83 7b 04 01          	cmpl   $0x1,0x4(%ebx)
c0020f18:	75 22                	jne    c0020f3c <calcPrio+0x7b>
     list_remove(&t->elem);
c0020f1a:	8d 73 28             	lea    0x28(%ebx),%esi
c0020f1d:	89 34 24             	mov    %esi,(%esp)
c0020f20:	e8 bf 80 00 00       	call   c0028fe4 <list_remove>
     list_push_back (&mlfqs_list[t->priority], &t->elem);
c0020f25:	89 74 24 04          	mov    %esi,0x4(%esp)
c0020f29:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0020f2c:	c1 e0 04             	shl    $0x4,%eax
c0020f2f:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c0020f34:	89 04 24             	mov    %eax,(%esp)
c0020f37:	e8 85 80 00 00       	call   c0028fc1 <list_push_back>
}
c0020f3c:	83 c4 14             	add    $0x14,%esp
c0020f3f:	5b                   	pop    %ebx
c0020f40:	5e                   	pop    %esi
c0020f41:	c3                   	ret    

c0020f42 <get_ready_threads>:
{
c0020f42:	57                   	push   %edi
c0020f43:	56                   	push   %esi
c0020f44:	53                   	push   %ebx
c0020f45:	83 ec 10             	sub    $0x10,%esp
c0020f48:	bb 20 5c 03 c0       	mov    $0xc0035c20,%ebx
c0020f4d:	bf 20 60 03 c0       	mov    $0xc0036020,%edi
  int all_ready = 0;
c0020f52:	be 00 00 00 00       	mov    $0x0,%esi
     all_ready += list_size(&mlfqs_list[i]);
c0020f57:	89 1c 24             	mov    %ebx,(%esp)
c0020f5a:	e8 da 80 00 00       	call   c0029039 <list_size>
c0020f5f:	01 c6                	add    %eax,%esi
c0020f61:	83 c3 10             	add    $0x10,%ebx
  for(i=0;i<64;i++)
c0020f64:	39 fb                	cmp    %edi,%ebx
c0020f66:	75 ef                	jne    c0020f57 <get_ready_threads+0x15>
  asm ("mov %%esp, %0" : "=g" (esp));
c0020f68:	89 e0                	mov    %esp,%eax
c0020f6a:	25 00 f0 ff ff       	and    $0xfffff000,%eax
     all_ready++;
c0020f6f:	39 05 08 5c 03 c0    	cmp    %eax,0xc0035c08
c0020f75:	0f 95 c0             	setne  %al
c0020f78:	0f b6 c0             	movzbl %al,%eax
c0020f7b:	01 c6                	add    %eax,%esi
}
c0020f7d:	89 f0                	mov    %esi,%eax
c0020f7f:	83 c4 10             	add    $0x10,%esp
c0020f82:	5b                   	pop    %ebx
c0020f83:	5e                   	pop    %esi
c0020f84:	5f                   	pop    %edi
c0020f85:	c3                   	ret    

c0020f86 <getLoadAv>:
}
c0020f86:	a1 1c 5c 03 c0       	mov    0xc0035c1c,%eax
c0020f8b:	c3                   	ret    

c0020f8c <setLoadAv>:
  system_load_avg = load;
c0020f8c:	8b 44 24 04          	mov    0x4(%esp),%eax
c0020f90:	a3 1c 5c 03 c0       	mov    %eax,0xc0035c1c
c0020f95:	c3                   	ret    

c0020f96 <get_idle_thread>:
}
c0020f96:	a1 08 5c 03 c0       	mov    0xc0035c08,%eax
c0020f9b:	c3                   	ret    

c0020f9c <thread_schedule_tail>:
{
c0020f9c:	56                   	push   %esi
c0020f9d:	53                   	push   %ebx
c0020f9e:	83 ec 24             	sub    $0x24,%esp
c0020fa1:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  asm ("mov %%esp, %0" : "=g" (esp));
c0020fa5:	89 e6                	mov    %esp,%esi
c0020fa7:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
  ASSERT (intr_get_level () == INTR_OFF);
c0020fad:	e8 52 08 00 00       	call   c0021804 <intr_get_level>
c0020fb2:	85 c0                	test   %eax,%eax
c0020fb4:	74 2c                	je     c0020fe2 <thread_schedule_tail+0x46>
c0020fb6:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0020fbd:	c0 
c0020fbe:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0020fc5:	c0 
c0020fc6:	c7 44 24 08 79 d0 02 	movl   $0xc002d079,0x8(%esp)
c0020fcd:	c0 
c0020fce:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
c0020fd5:	00 
c0020fd6:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0020fdd:	e8 91 79 00 00       	call   c0028973 <debug_panic>
  cur->status = THREAD_RUNNING;
c0020fe2:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
  thread_ticks = 0;
c0020fe9:	c7 05 c0 5b 03 c0 00 	movl   $0x0,0xc0035bc0
c0020ff0:	00 00 00 
  if (prev != NULL && prev->status == THREAD_DYING && prev != initial_thread) 
c0020ff3:	85 db                	test   %ebx,%ebx
c0020ff5:	74 46                	je     c002103d <thread_schedule_tail+0xa1>
c0020ff7:	83 7b 04 03          	cmpl   $0x3,0x4(%ebx)
c0020ffb:	75 40                	jne    c002103d <thread_schedule_tail+0xa1>
c0020ffd:	3b 1d 04 5c 03 c0    	cmp    0xc0035c04,%ebx
c0021003:	74 38                	je     c002103d <thread_schedule_tail+0xa1>
      ASSERT (prev != cur);
c0021005:	39 f3                	cmp    %esi,%ebx
c0021007:	75 2c                	jne    c0021035 <thread_schedule_tail+0x99>
c0021009:	c7 44 24 10 67 e5 02 	movl   $0xc002e567,0x10(%esp)
c0021010:	c0 
c0021011:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021018:	c0 
c0021019:	c7 44 24 08 79 d0 02 	movl   $0xc002d079,0x8(%esp)
c0021020:	c0 
c0021021:	c7 44 24 04 21 03 00 	movl   $0x321,0x4(%esp)
c0021028:	00 
c0021029:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021030:	e8 3e 79 00 00       	call   c0028973 <debug_panic>
      palloc_free_page (prev);
c0021035:	89 1c 24             	mov    %ebx,(%esp)
c0021038:	e8 e3 25 00 00       	call   c0023620 <palloc_free_page>
}
c002103d:	83 c4 24             	add    $0x24,%esp
c0021040:	5b                   	pop    %ebx
c0021041:	5e                   	pop    %esi
c0021042:	c3                   	ret    

c0021043 <schedule>:
{
c0021043:	57                   	push   %edi
c0021044:	56                   	push   %esi
c0021045:	53                   	push   %ebx
c0021046:	83 ec 20             	sub    $0x20,%esp
  asm ("mov %%esp, %0" : "=g" (esp));
c0021049:	89 e7                	mov    %esp,%edi
c002104b:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
  if(thread_mlfqs)
c0021051:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0021058:	74 2a                	je     c0021084 <schedule+0x41>
c002105a:	be 10 60 03 c0       	mov    $0xc0036010,%esi
c002105f:	bb 3f 00 00 00       	mov    $0x3f,%ebx
      if(list_empty(&mlfqs_list[i])){
c0021064:	89 34 24             	mov    %esi,(%esp)
c0021067:	e8 0a 80 00 00       	call   c0029076 <list_empty>
c002106c:	84 c0                	test   %al,%al
c002106e:	0f 84 db 00 00 00    	je     c002114f <schedule+0x10c>
         i--;
c0021074:	83 eb 01             	sub    $0x1,%ebx
c0021077:	83 ee 10             	sub    $0x10,%esi
    while(i>=0){
c002107a:	83 fb ff             	cmp    $0xffffffff,%ebx
c002107d:	75 e5                	jne    c0021064 <schedule+0x21>
c002107f:	e9 e4 00 00 00       	jmp    c0021168 <schedule+0x125>
    if (list_empty (&ready_list))
c0021084:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c002108b:	e8 e6 7f 00 00       	call   c0029076 <list_empty>
      return idle_thread;
c0021090:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
    if (list_empty (&ready_list))
c0021096:	84 c0                	test   %al,%al
c0021098:	75 29                	jne    c00210c3 <schedule+0x80>
      struct list_elem *temp = list_max (&ready_list,threadPrioCompare,NULL); 
c002109a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00210a1:	00 
c00210a2:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c00210a9:	c0 
c00210aa:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c00210b1:	e8 94 85 00 00       	call   c002964a <list_max>
c00210b6:	89 c3                	mov    %eax,%ebx
      list_remove(temp);
c00210b8:	89 04 24             	mov    %eax,(%esp)
c00210bb:	e8 24 7f 00 00       	call   c0028fe4 <list_remove>
      return list_entry(temp,struct thread,elem);
c00210c0:	83 eb 28             	sub    $0x28,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c00210c3:	e8 3c 07 00 00       	call   c0021804 <intr_get_level>
c00210c8:	85 c0                	test   %eax,%eax
c00210ca:	74 2c                	je     c00210f8 <schedule+0xb5>
c00210cc:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c00210d3:	c0 
c00210d4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00210db:	c0 
c00210dc:	c7 44 24 08 e8 d0 02 	movl   $0xc002d0e8,0x8(%esp)
c00210e3:	c0 
c00210e4:	c7 44 24 04 33 03 00 	movl   $0x333,0x4(%esp)
c00210eb:	00 
c00210ec:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00210f3:	e8 7b 78 00 00       	call   c0028973 <debug_panic>
  ASSERT (cur->status != THREAD_RUNNING);
c00210f8:	83 7f 04 00          	cmpl   $0x0,0x4(%edi)
c00210fc:	75 2c                	jne    c002112a <schedule+0xe7>
c00210fe:	c7 44 24 10 73 e5 02 	movl   $0xc002e573,0x10(%esp)
c0021105:	c0 
c0021106:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002110d:	c0 
c002110e:	c7 44 24 08 e8 d0 02 	movl   $0xc002d0e8,0x8(%esp)
c0021115:	c0 
c0021116:	c7 44 24 04 34 03 00 	movl   $0x334,0x4(%esp)
c002111d:	00 
c002111e:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021125:	e8 49 78 00 00       	call   c0028973 <debug_panic>
  return t != NULL && t->magic == THREAD_MAGIC;
c002112a:	85 db                	test   %ebx,%ebx
c002112c:	74 50                	je     c002117e <schedule+0x13b>
c002112e:	81 7b 30 4b bf 6a cd 	cmpl   $0xcd6abf4b,0x30(%ebx)
c0021135:	75 47                	jne    c002117e <schedule+0x13b>
c0021137:	eb 3a                	jmp    c0021173 <schedule+0x130>
    prev = switch_threads (cur, next);
c0021139:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002113d:	89 3c 24             	mov    %edi,(%esp)
c0021140:	e8 40 05 00 00       	call   c0021685 <switch_threads>
  thread_schedule_tail (prev);
c0021145:	89 04 24             	mov    %eax,(%esp)
c0021148:	e8 4f fe ff ff       	call   c0020f9c <thread_schedule_tail>
c002114d:	eb 5b                	jmp    c00211aa <schedule+0x167>
      return list_entry(list_pop_front (&mlfqs_list[i]), struct thread, elem); 
c002114f:	c1 e3 04             	shl    $0x4,%ebx
c0021152:	81 c3 20 5c 03 c0    	add    $0xc0035c20,%ebx
c0021158:	89 1c 24             	mov    %ebx,(%esp)
c002115b:	e8 84 7f 00 00       	call   c00290e4 <list_pop_front>
c0021160:	8d 58 d8             	lea    -0x28(%eax),%ebx
c0021163:	e9 5b ff ff ff       	jmp    c00210c3 <schedule+0x80>
      return idle_thread;
c0021168:	8b 1d 08 5c 03 c0    	mov    0xc0035c08,%ebx
c002116e:	e9 50 ff ff ff       	jmp    c00210c3 <schedule+0x80>
  struct thread *prev = NULL;
c0021173:	b8 00 00 00 00       	mov    $0x0,%eax
  if (cur != next)
c0021178:	39 df                	cmp    %ebx,%edi
c002117a:	74 c9                	je     c0021145 <schedule+0x102>
c002117c:	eb bb                	jmp    c0021139 <schedule+0xf6>
  ASSERT (is_thread (next));
c002117e:	c7 44 24 10 91 e5 02 	movl   $0xc002e591,0x10(%esp)
c0021185:	c0 
c0021186:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002118d:	c0 
c002118e:	c7 44 24 08 e8 d0 02 	movl   $0xc002d0e8,0x8(%esp)
c0021195:	c0 
c0021196:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
c002119d:	00 
c002119e:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00211a5:	e8 c9 77 00 00       	call   c0028973 <debug_panic>
}
c00211aa:	83 c4 20             	add    $0x20,%esp
c00211ad:	5b                   	pop    %ebx
c00211ae:	5e                   	pop    %esi
c00211af:	5f                   	pop    %edi
c00211b0:	c3                   	ret    

c00211b1 <thread_block>:
{
c00211b1:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c00211b4:	e8 f8 08 00 00       	call   c0021ab1 <intr_context>
c00211b9:	84 c0                	test   %al,%al
c00211bb:	74 2c                	je     c00211e9 <thread_block+0x38>
c00211bd:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00211c4:	c0 
c00211c5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00211cc:	c0 
c00211cd:	c7 44 24 08 f1 d0 02 	movl   $0xc002d0f1,0x8(%esp)
c00211d4:	c0 
c00211d5:	c7 44 24 04 1d 01 00 	movl   $0x11d,0x4(%esp)
c00211dc:	00 
c00211dd:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00211e4:	e8 8a 77 00 00       	call   c0028973 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c00211e9:	e8 16 06 00 00       	call   c0021804 <intr_get_level>
c00211ee:	85 c0                	test   %eax,%eax
c00211f0:	74 2c                	je     c002121e <thread_block+0x6d>
c00211f2:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c00211f9:	c0 
c00211fa:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021201:	c0 
c0021202:	c7 44 24 08 f1 d0 02 	movl   $0xc002d0f1,0x8(%esp)
c0021209:	c0 
c002120a:	c7 44 24 04 1e 01 00 	movl   $0x11e,0x4(%esp)
c0021211:	00 
c0021212:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021219:	e8 55 77 00 00       	call   c0028973 <debug_panic>
  thread_current ()->status = THREAD_BLOCKED;
c002121e:	e8 80 fa ff ff       	call   c0020ca3 <thread_current>
c0021223:	c7 40 04 02 00 00 00 	movl   $0x2,0x4(%eax)
  schedule ();
c002122a:	e8 14 fe ff ff       	call   c0021043 <schedule>
}
c002122f:	83 c4 2c             	add    $0x2c,%esp
c0021232:	c3                   	ret    

c0021233 <idle>:
{
c0021233:	83 ec 1c             	sub    $0x1c,%esp
  idle_thread = thread_current ();
c0021236:	e8 68 fa ff ff       	call   c0020ca3 <thread_current>
c002123b:	a3 08 5c 03 c0       	mov    %eax,0xc0035c08
  sema_up (idle_started);
c0021240:	8b 44 24 20          	mov    0x20(%esp),%eax
c0021244:	89 04 24             	mov    %eax,(%esp)
c0021247:	e8 8b 18 00 00       	call   c0022ad7 <sema_up>
      intr_disable ();
c002124c:	e8 fe 05 00 00       	call   c002184f <intr_disable>
      thread_block ();
c0021251:	e8 5b ff ff ff       	call   c00211b1 <thread_block>
      asm volatile ("sti; hlt" : : : "memory");
c0021256:	fb                   	sti    
c0021257:	f4                   	hlt    
c0021258:	eb f2                	jmp    c002124c <idle+0x19>

c002125a <thread_exit>:
{
c002125a:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!intr_context ());
c002125d:	e8 4f 08 00 00       	call   c0021ab1 <intr_context>
c0021262:	84 c0                	test   %al,%al
c0021264:	74 2c                	je     c0021292 <thread_exit+0x38>
c0021266:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c002126d:	c0 
c002126e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021275:	c0 
c0021276:	c7 44 24 08 be d0 02 	movl   $0xc002d0be,0x8(%esp)
c002127d:	c0 
c002127e:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
c0021285:	00 
c0021286:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c002128d:	e8 e1 76 00 00       	call   c0028973 <debug_panic>
  intr_disable ();
c0021292:	e8 b8 05 00 00       	call   c002184f <intr_disable>
  list_remove (&thread_current()->allelem);
c0021297:	e8 07 fa ff ff       	call   c0020ca3 <thread_current>
c002129c:	83 c0 20             	add    $0x20,%eax
c002129f:	89 04 24             	mov    %eax,(%esp)
c00212a2:	e8 3d 7d 00 00       	call   c0028fe4 <list_remove>
  thread_current ()->status = THREAD_DYING;
c00212a7:	e8 f7 f9 ff ff       	call   c0020ca3 <thread_current>
c00212ac:	c7 40 04 03 00 00 00 	movl   $0x3,0x4(%eax)
  schedule ();
c00212b3:	e8 8b fd ff ff       	call   c0021043 <schedule>
  NOT_REACHED ();
c00212b8:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c00212bf:	c0 
c00212c0:	c7 44 24 08 be d0 02 	movl   $0xc002d0be,0x8(%esp)
c00212c7:	c0 
c00212c8:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
c00212cf:	00 
c00212d0:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00212d7:	e8 97 76 00 00       	call   c0028973 <debug_panic>

c00212dc <kernel_thread>:
{
c00212dc:	53                   	push   %ebx
c00212dd:	83 ec 28             	sub    $0x28,%esp
c00212e0:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (function != NULL);
c00212e4:	85 db                	test   %ebx,%ebx
c00212e6:	75 2c                	jne    c0021314 <kernel_thread+0x38>
c00212e8:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c00212ef:	c0 
c00212f0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00212f7:	c0 
c00212f8:	c7 44 24 08 0a d1 02 	movl   $0xc002d10a,0x8(%esp)
c00212ff:	c0 
c0021300:	c7 44 24 04 79 02 00 	movl   $0x279,0x4(%esp)
c0021307:	00 
c0021308:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c002130f:	e8 5f 76 00 00       	call   c0028973 <debug_panic>
  intr_enable ();       /* The scheduler runs with interrupts off. */
c0021314:	e8 f4 04 00 00       	call   c002180d <intr_enable>
  function (aux);       /* Execute the thread function. */
c0021319:	8b 44 24 34          	mov    0x34(%esp),%eax
c002131d:	89 04 24             	mov    %eax,(%esp)
c0021320:	ff d3                	call   *%ebx
  thread_exit ();       /* If function() returns, kill the thread. */
c0021322:	e8 33 ff ff ff       	call   c002125a <thread_exit>

c0021327 <thread_yield>:
{
c0021327:	56                   	push   %esi
c0021328:	53                   	push   %ebx
c0021329:	83 ec 24             	sub    $0x24,%esp
  struct thread *cur = thread_current ();
c002132c:	e8 72 f9 ff ff       	call   c0020ca3 <thread_current>
c0021331:	89 c3                	mov    %eax,%ebx
  ASSERT (!intr_context ());
c0021333:	e8 79 07 00 00       	call   c0021ab1 <intr_context>
c0021338:	84 c0                	test   %al,%al
c002133a:	74 2c                	je     c0021368 <thread_yield+0x41>
c002133c:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0021343:	c0 
c0021344:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002134b:	c0 
c002134c:	c7 44 24 08 b1 d0 02 	movl   $0xc002d0b1,0x8(%esp)
c0021353:	c0 
c0021354:	c7 44 24 04 80 01 00 	movl   $0x180,0x4(%esp)
c002135b:	00 
c002135c:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021363:	e8 0b 76 00 00       	call   c0028973 <debug_panic>
  old_level = intr_disable ();
c0021368:	e8 e2 04 00 00       	call   c002184f <intr_disable>
c002136d:	89 c6                	mov    %eax,%esi
  if (cur != idle_thread) 
c002136f:	3b 1d 08 5c 03 c0    	cmp    0xc0035c08,%ebx
c0021375:	74 38                	je     c00213af <thread_yield+0x88>
    if(thread_mlfqs) {
c0021377:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002137e:	74 1c                	je     c002139c <thread_yield+0x75>
      list_push_back (&mlfqs_list[cur->priority], &cur->elem);
c0021380:	8d 43 28             	lea    0x28(%ebx),%eax
c0021383:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021387:	8b 43 1c             	mov    0x1c(%ebx),%eax
c002138a:	c1 e0 04             	shl    $0x4,%eax
c002138d:	05 20 5c 03 c0       	add    $0xc0035c20,%eax
c0021392:	89 04 24             	mov    %eax,(%esp)
c0021395:	e8 27 7c 00 00       	call   c0028fc1 <list_push_back>
c002139a:	eb 13                	jmp    c00213af <thread_yield+0x88>
      list_push_back (&ready_list, &cur->elem);
c002139c:	8d 43 28             	lea    0x28(%ebx),%eax
c002139f:	89 44 24 04          	mov    %eax,0x4(%esp)
c00213a3:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c00213aa:	e8 12 7c 00 00       	call   c0028fc1 <list_push_back>
  cur->status = THREAD_READY;
c00213af:	c7 43 04 01 00 00 00 	movl   $0x1,0x4(%ebx)
  schedule ();
c00213b6:	e8 88 fc ff ff       	call   c0021043 <schedule>
  intr_set_level (old_level);
c00213bb:	89 34 24             	mov    %esi,(%esp)
c00213be:	e8 93 04 00 00       	call   c0021856 <intr_set_level>
}
c00213c3:	83 c4 24             	add    $0x24,%esp
c00213c6:	5b                   	pop    %ebx
c00213c7:	5e                   	pop    %esi
c00213c8:	c3                   	ret    

c00213c9 <thread_create>:
{
c00213c9:	55                   	push   %ebp
c00213ca:	57                   	push   %edi
c00213cb:	56                   	push   %esi
c00213cc:	53                   	push   %ebx
c00213cd:	83 ec 2c             	sub    $0x2c,%esp
c00213d0:	8b 7c 24 48          	mov    0x48(%esp),%edi
  ASSERT (function != NULL);
c00213d4:	85 ff                	test   %edi,%edi
c00213d6:	75 2c                	jne    c0021404 <thread_create+0x3b>
c00213d8:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c00213df:	c0 
c00213e0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00213e7:	c0 
c00213e8:	c7 44 24 08 18 d1 02 	movl   $0xc002d118,0x8(%esp)
c00213ef:	c0 
c00213f0:	c7 44 24 04 e1 00 00 	movl   $0xe1,0x4(%esp)
c00213f7:	00 
c00213f8:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c00213ff:	e8 6f 75 00 00       	call   c0028973 <debug_panic>
  t = palloc_get_page (PAL_ZERO);
c0021404:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c002140b:	e8 a6 20 00 00       	call   c00234b6 <palloc_get_page>
c0021410:	89 c3                	mov    %eax,%ebx
  if (t == NULL)
c0021412:	85 c0                	test   %eax,%eax
c0021414:	0f 84 c4 00 00 00    	je     c00214de <thread_create+0x115>
  t->nice = thread_current()->nice; //get parent's nice value
c002141a:	e8 84 f8 ff ff       	call   c0020ca3 <thread_current>
c002141f:	8b 40 54             	mov    0x54(%eax),%eax
c0021422:	89 43 54             	mov    %eax,0x54(%ebx)
  t->recent_cpu = thread_current()->recent_cpu; //get parent's recent_cpu value
c0021425:	e8 79 f8 ff ff       	call   c0020ca3 <thread_current>
c002142a:	8b 40 58             	mov    0x58(%eax),%eax
c002142d:	89 43 58             	mov    %eax,0x58(%ebx)
  init_thread (t, name, priority);
c0021430:	8b 4c 24 44          	mov    0x44(%esp),%ecx
c0021434:	8b 54 24 40          	mov    0x40(%esp),%edx
c0021438:	89 d8                	mov    %ebx,%eax
c002143a:	e8 a2 f4 ff ff       	call   c00208e1 <init_thread>
  lock_acquire (&tid_lock);
c002143f:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0021446:	e8 9f 18 00 00       	call   c0022cea <lock_acquire>
  tid = next_tid++;
c002144b:	8b 35 44 56 03 c0    	mov    0xc0035644,%esi
c0021451:	8d 46 01             	lea    0x1(%esi),%eax
c0021454:	a3 44 56 03 c0       	mov    %eax,0xc0035644
  lock_release (&tid_lock);
c0021459:	c7 04 24 e0 5b 03 c0 	movl   $0xc0035be0,(%esp)
c0021460:	e8 4f 1a 00 00       	call   c0022eb4 <lock_release>
  tid = t->tid = allocate_tid ();
c0021465:	89 33                	mov    %esi,(%ebx)
  old_level = intr_disable ();
c0021467:	e8 e3 03 00 00       	call   c002184f <intr_disable>
c002146c:	89 c5                	mov    %eax,%ebp
  kf = alloc_frame (t, sizeof *kf);
c002146e:	ba 0c 00 00 00       	mov    $0xc,%edx
c0021473:	89 d8                	mov    %ebx,%eax
c0021475:	e8 e8 f3 ff ff       	call   c0020862 <alloc_frame>
  kf->eip = NULL;
c002147a:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  kf->function = function;
c0021480:	89 78 04             	mov    %edi,0x4(%eax)
  kf->aux = aux;
c0021483:	8b 54 24 4c          	mov    0x4c(%esp),%edx
c0021487:	89 50 08             	mov    %edx,0x8(%eax)
  ef = alloc_frame (t, sizeof *ef);
c002148a:	ba 04 00 00 00       	mov    $0x4,%edx
c002148f:	89 d8                	mov    %ebx,%eax
c0021491:	e8 cc f3 ff ff       	call   c0020862 <alloc_frame>
  ef->eip = (void (*) (void)) kernel_thread;
c0021496:	c7 00 dc 12 02 c0    	movl   $0xc00212dc,(%eax)
  sf = alloc_frame (t, sizeof *sf);
c002149c:	ba 1c 00 00 00       	mov    $0x1c,%edx
c00214a1:	89 d8                	mov    %ebx,%eax
c00214a3:	e8 ba f3 ff ff       	call   c0020862 <alloc_frame>
  sf->eip = switch_entry;
c00214a8:	c7 40 10 a2 16 02 c0 	movl   $0xc00216a2,0x10(%eax)
  sf->ebp = 0;
c00214af:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
  intr_set_level (old_level);
c00214b6:	89 2c 24             	mov    %ebp,(%esp)
c00214b9:	e8 98 03 00 00       	call   c0021856 <intr_set_level>
  thread_unblock (t);
c00214be:	89 1c 24             	mov    %ebx,(%esp)
c00214c1:	e8 04 f7 ff ff       	call   c0020bca <thread_unblock>
  if(t->priority > thread_current()->priority)
c00214c6:	e8 d8 f7 ff ff       	call   c0020ca3 <thread_current>
  return tid;
c00214cb:	89 f2                	mov    %esi,%edx
  if(t->priority > thread_current()->priority)
c00214cd:	8b 40 1c             	mov    0x1c(%eax),%eax
c00214d0:	39 43 1c             	cmp    %eax,0x1c(%ebx)
c00214d3:	7e 0e                	jle    c00214e3 <thread_create+0x11a>
    thread_yield();
c00214d5:	e8 4d fe ff ff       	call   c0021327 <thread_yield>
  return tid;
c00214da:	89 f2                	mov    %esi,%edx
c00214dc:	eb 05                	jmp    c00214e3 <thread_create+0x11a>
    return TID_ERROR;
c00214de:	ba ff ff ff ff       	mov    $0xffffffff,%edx
}
c00214e3:	89 d0                	mov    %edx,%eax
c00214e5:	83 c4 2c             	add    $0x2c,%esp
c00214e8:	5b                   	pop    %ebx
c00214e9:	5e                   	pop    %esi
c00214ea:	5f                   	pop    %edi
c00214eb:	5d                   	pop    %ebp
c00214ec:	c3                   	ret    

c00214ed <thread_start>:
{
c00214ed:	53                   	push   %ebx
c00214ee:	83 ec 38             	sub    $0x38,%esp
  sema_init (&idle_started, 0);
c00214f1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00214f8:	00 
c00214f9:	8d 5c 24 1c          	lea    0x1c(%esp),%ebx
c00214fd:	89 1c 24             	mov    %ebx,(%esp)
c0021500:	e8 71 14 00 00       	call   c0022976 <sema_init>
  thread_create ("idle", PRI_MIN, idle, &idle_started);
c0021505:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0021509:	c7 44 24 08 33 12 02 	movl   $0xc0021233,0x8(%esp)
c0021510:	c0 
c0021511:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0021518:	00 
c0021519:	c7 04 24 c4 e5 02 c0 	movl   $0xc002e5c4,(%esp)
c0021520:	e8 a4 fe ff ff       	call   c00213c9 <thread_create>
  intr_enable ();
c0021525:	e8 e3 02 00 00       	call   c002180d <intr_enable>
  sema_down (&idle_started);
c002152a:	89 1c 24             	mov    %ebx,(%esp)
c002152d:	e8 90 14 00 00       	call   c00229c2 <sema_down>
}
c0021532:	83 c4 38             	add    $0x38,%esp
c0021535:	5b                   	pop    %ebx
c0021536:	c3                   	ret    

c0021537 <thread_set_priority>:
{
c0021537:	56                   	push   %esi
c0021538:	53                   	push   %ebx
c0021539:	83 ec 24             	sub    $0x24,%esp
c002153c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT(thread_mlfqs == false);
c0021540:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0021547:	74 2c                	je     c0021575 <thread_set_priority+0x3e>
c0021549:	c7 44 24 10 c9 e5 02 	movl   $0xc002e5c9,0x10(%esp)
c0021550:	c0 
c0021551:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021558:	c0 
c0021559:	c7 44 24 08 8e d0 02 	movl   $0xc002d08e,0x8(%esp)
c0021560:	c0 
c0021561:	c7 44 24 04 ab 01 00 	movl   $0x1ab,0x4(%esp)
c0021568:	00 
c0021569:	c7 04 24 da e4 02 c0 	movl   $0xc002e4da,(%esp)
c0021570:	e8 fe 73 00 00       	call   c0028973 <debug_panic>
  old_level = intr_disable ();
c0021575:	e8 d5 02 00 00       	call   c002184f <intr_disable>
c002157a:	89 c6                	mov    %eax,%esi
  if(new_priority >= PRI_MIN && new_priority <= PRI_MAX) //REMOVE COMMENT: flipped this
c002157c:	83 fb 3f             	cmp    $0x3f,%ebx
c002157f:	77 68                	ja     c00215e9 <thread_set_priority+0xb2>
    if(new_priority > thread_current ()->priority)
c0021581:	e8 1d f7 ff ff       	call   c0020ca3 <thread_current>
c0021586:	89 c2                	mov    %eax,%edx
c0021588:	8b 40 1c             	mov    0x1c(%eax),%eax
c002158b:	39 c3                	cmp    %eax,%ebx
c002158d:	7e 0d                	jle    c002159c <thread_set_priority+0x65>
      thread_current ()->priority = new_priority;
c002158f:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c0021592:	e8 0c f7 ff ff       	call   c0020ca3 <thread_current>
c0021597:	89 58 3c             	mov    %ebx,0x3c(%eax)
c002159a:	eb 15                	jmp    c00215b1 <thread_set_priority+0x7a>
    else if(thread_current ()->priority == thread_current ()->old_priority)
c002159c:	3b 42 3c             	cmp    0x3c(%edx),%eax
c002159f:	75 0d                	jne    c00215ae <thread_set_priority+0x77>
      thread_current ()->priority = new_priority;
c00215a1:	89 5a 1c             	mov    %ebx,0x1c(%edx)
      thread_current ()->old_priority = new_priority;
c00215a4:	e8 fa f6 ff ff       	call   c0020ca3 <thread_current>
c00215a9:	89 58 3c             	mov    %ebx,0x3c(%eax)
c00215ac:	eb 03                	jmp    c00215b1 <thread_set_priority+0x7a>
      thread_current ()->old_priority = new_priority;
c00215ae:	89 5a 3c             	mov    %ebx,0x3c(%edx)
    intr_set_level (old_level);
c00215b1:	89 34 24             	mov    %esi,(%esp)
c00215b4:	e8 9d 02 00 00       	call   c0021856 <intr_set_level>
    int max_prio = list_entry(list_max (&ready_list,threadPrioCompare,NULL),struct thread,elem)->priority;
c00215b9:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c00215c0:	00 
c00215c1:	c7 44 24 04 50 08 02 	movl   $0xc0020850,0x4(%esp)
c00215c8:	c0 
c00215c9:	c7 04 24 20 60 03 c0 	movl   $0xc0036020,(%esp)
c00215d0:	e8 75 80 00 00       	call   c002964a <list_max>
c00215d5:	89 c3                	mov    %eax,%ebx
    if(max_prio > thread_current ()->priority)
c00215d7:	e8 c7 f6 ff ff       	call   c0020ca3 <thread_current>
c00215dc:	8b 40 1c             	mov    0x1c(%eax),%eax
c00215df:	39 43 f4             	cmp    %eax,-0xc(%ebx)
c00215e2:	7e 05                	jle    c00215e9 <thread_set_priority+0xb2>
      thread_yield();
c00215e4:	e8 3e fd ff ff       	call   c0021327 <thread_yield>
}
c00215e9:	83 c4 24             	add    $0x24,%esp
c00215ec:	5b                   	pop    %ebx
c00215ed:	5e                   	pop    %esi
c00215ee:	c3                   	ret    

c00215ef <thread_set_nice>:
{
c00215ef:	57                   	push   %edi
c00215f0:	56                   	push   %esi
c00215f1:	53                   	push   %ebx
c00215f2:	83 ec 10             	sub    $0x10,%esp
c00215f5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread *curr_thread = thread_current();
c00215f9:	e8 a5 f6 ff ff       	call   c0020ca3 <thread_current>
c00215fe:	89 c7                	mov    %eax,%edi
  if(nice >= -20 && nice <= 20)
c0021600:	8d 43 14             	lea    0x14(%ebx),%eax
c0021603:	83 f8 28             	cmp    $0x28,%eax
c0021606:	77 03                	ja     c002160b <thread_set_nice+0x1c>
    curr_thread->nice = nice;
c0021608:	89 5f 54             	mov    %ebx,0x54(%edi)
  curr_thread->priority = PRI_MAX - convertXtoIntRoundNear(curr_thread->recent_cpu / 4) - (curr_thread->nice * 2);
c002160b:	8b 47 58             	mov    0x58(%edi),%eax
c002160e:	8d 50 03             	lea    0x3(%eax),%edx
c0021611:	85 c0                	test   %eax,%eax
c0021613:	0f 48 c2             	cmovs  %edx,%eax
c0021616:	c1 f8 02             	sar    $0x2,%eax
c0021619:	89 04 24             	mov    %eax,(%esp)
c002161c:	e8 f0 25 00 00       	call   c0023c11 <convertXtoIntRoundNear>
c0021621:	ba 3f 00 00 00       	mov    $0x3f,%edx
c0021626:	29 c2                	sub    %eax,%edx
c0021628:	89 d0                	mov    %edx,%eax
c002162a:	8b 57 54             	mov    0x54(%edi),%edx
c002162d:	f7 da                	neg    %edx
c002162f:	8d 04 50             	lea    (%eax,%edx,2),%eax
  if(curr_thread->priority > PRI_MAX)
c0021632:	83 f8 3f             	cmp    $0x3f,%eax
c0021635:	7e 09                	jle    c0021640 <thread_set_nice+0x51>
    curr_thread->priority = PRI_MAX;
c0021637:	c7 47 1c 3f 00 00 00 	movl   $0x3f,0x1c(%edi)
c002163e:	eb 32                	jmp    c0021672 <thread_set_nice+0x83>
    curr_thread->priority = PRI_MIN;
c0021640:	85 c0                	test   %eax,%eax
c0021642:	ba 00 00 00 00       	mov    $0x0,%edx
c0021647:	0f 48 c2             	cmovs  %edx,%eax
c002164a:	89 47 1c             	mov    %eax,0x1c(%edi)
c002164d:	eb 23                	jmp    c0021672 <thread_set_nice+0x83>
    if(list_empty(&mlfqs_list[i]) && curr_thread->priority > i){
c002164f:	89 34 24             	mov    %esi,(%esp)
c0021652:	e8 1f 7a 00 00       	call   c0029076 <list_empty>
c0021657:	84 c0                	test   %al,%al
c0021659:	74 0a                	je     c0021665 <thread_set_nice+0x76>
c002165b:	39 5f 1c             	cmp    %ebx,0x1c(%edi)
c002165e:	7e 05                	jle    c0021665 <thread_set_nice+0x76>
      thread_yield();  
c0021660:	e8 c2 fc ff ff       	call   c0021327 <thread_yield>
  for(i = 0; i < 64; i++){
c0021665:	83 c3 01             	add    $0x1,%ebx
c0021668:	83 c6 10             	add    $0x10,%esi
c002166b:	83 fb 40             	cmp    $0x40,%ebx
c002166e:	75 df                	jne    c002164f <thread_set_nice+0x60>
c0021670:	eb 0c                	jmp    c002167e <thread_set_nice+0x8f>
c0021672:	be 20 5c 03 c0       	mov    $0xc0035c20,%esi
{
c0021677:	bb 00 00 00 00       	mov    $0x0,%ebx
c002167c:	eb d1                	jmp    c002164f <thread_set_nice+0x60>
}
c002167e:	83 c4 10             	add    $0x10,%esp
c0021681:	5b                   	pop    %ebx
c0021682:	5e                   	pop    %esi
c0021683:	5f                   	pop    %edi
c0021684:	c3                   	ret    

c0021685 <switch_threads>:
	# but requires us to preserve %ebx, %ebp, %esi, %edi.  See
	# [SysV-ABI-386] pages 3-11 and 3-12 for details.
	#
	# This stack frame must match the one set up by thread_create()
	# in size.
	pushl %ebx
c0021685:	53                   	push   %ebx
	pushl %ebp
c0021686:	55                   	push   %ebp
	pushl %esi
c0021687:	56                   	push   %esi
	pushl %edi
c0021688:	57                   	push   %edi

	# Get offsetof (struct thread, stack).
.globl thread_stack_ofs
	mov thread_stack_ofs, %edx
c0021689:	8b 15 48 56 03 c0    	mov    0xc0035648,%edx

	# Save current stack pointer to old thread's stack, if any.
	movl SWITCH_CUR(%esp), %eax
c002168f:	8b 44 24 14          	mov    0x14(%esp),%eax
	movl %esp, (%eax,%edx,1)
c0021693:	89 24 10             	mov    %esp,(%eax,%edx,1)

	# Restore stack pointer from new thread's stack.
	movl SWITCH_NEXT(%esp), %ecx
c0021696:	8b 4c 24 18          	mov    0x18(%esp),%ecx
	movl (%ecx,%edx,1), %esp
c002169a:	8b 24 11             	mov    (%ecx,%edx,1),%esp

	# Restore caller's register state.
	popl %edi
c002169d:	5f                   	pop    %edi
	popl %esi
c002169e:	5e                   	pop    %esi
	popl %ebp
c002169f:	5d                   	pop    %ebp
	popl %ebx
c00216a0:	5b                   	pop    %ebx
        ret
c00216a1:	c3                   	ret    

c00216a2 <switch_entry>:

.globl switch_entry
.func switch_entry
switch_entry:
	# Discard switch_threads() arguments.
	addl $8, %esp
c00216a2:	83 c4 08             	add    $0x8,%esp

	# Call thread_schedule_tail(prev).
	pushl %eax
c00216a5:	50                   	push   %eax
.globl thread_schedule_tail
	call thread_schedule_tail
c00216a6:	e8 f1 f8 ff ff       	call   c0020f9c <thread_schedule_tail>
	addl $4, %esp
c00216ab:	83 c4 04             	add    $0x4,%esp

	# Start thread proper.
	ret
c00216ae:	c3                   	ret    
c00216af:	90                   	nop

c00216b0 <make_gate>:
   disables interrupts, but entering a trap gate does not.  See
   [IA32-v3a] section 5.12.1.2 "Flag Usage By Exception- or
   Interrupt-Handler Procedure" for discussion. */
static uint64_t
make_gate (void (*function) (void), int dpl, int type)
{
c00216b0:	53                   	push   %ebx
c00216b1:	83 ec 28             	sub    $0x28,%esp
  uint32_t e0, e1;

  ASSERT (function != NULL);
c00216b4:	85 c0                	test   %eax,%eax
c00216b6:	75 2c                	jne    c00216e4 <make_gate+0x34>
c00216b8:	c7 44 24 10 b3 e5 02 	movl   $0xc002e5b3,0x10(%esp)
c00216bf:	c0 
c00216c0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00216c7:	c0 
c00216c8:	c7 44 24 08 aa d1 02 	movl   $0xc002d1aa,0x8(%esp)
c00216cf:	c0 
c00216d0:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c00216d7:	00 
c00216d8:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c00216df:	e8 8f 72 00 00       	call   c0028973 <debug_panic>
  ASSERT (dpl >= 0 && dpl <= 3);
c00216e4:	83 fa 03             	cmp    $0x3,%edx
c00216e7:	76 2c                	jbe    c0021715 <make_gate+0x65>
c00216e9:	c7 44 24 10 88 e6 02 	movl   $0xc002e688,0x10(%esp)
c00216f0:	c0 
c00216f1:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00216f8:	c0 
c00216f9:	c7 44 24 08 aa d1 02 	movl   $0xc002d1aa,0x8(%esp)
c0021700:	c0 
c0021701:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0021708:	00 
c0021709:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021710:	e8 5e 72 00 00       	call   c0028973 <debug_panic>
  ASSERT (type >= 0 && type <= 15);
c0021715:	83 f9 0f             	cmp    $0xf,%ecx
c0021718:	76 2c                	jbe    c0021746 <make_gate+0x96>
c002171a:	c7 44 24 10 9d e6 02 	movl   $0xc002e69d,0x10(%esp)
c0021721:	c0 
c0021722:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021729:	c0 
c002172a:	c7 44 24 08 aa d1 02 	movl   $0xc002d1aa,0x8(%esp)
c0021731:	c0 
c0021732:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
c0021739:	00 
c002173a:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021741:	e8 2d 72 00 00       	call   c0028973 <debug_panic>

  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
        | (1 << 15)                        /* Present. */
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
        | (0 << 12)                        /* System. */
        | ((uint32_t) type << 8));         /* Gate type. */
c0021746:	c1 e1 08             	shl    $0x8,%ecx
        | ((uint32_t) dpl << 13)           /* Descriptor privilege level. */
c0021749:	80 cd 80             	or     $0x80,%ch
c002174c:	89 d3                	mov    %edx,%ebx
c002174e:	c1 e3 0d             	shl    $0xd,%ebx
        | ((uint32_t) type << 8));         /* Gate type. */
c0021751:	09 d9                	or     %ebx,%ecx
c0021753:	89 ca                	mov    %ecx,%edx
  e1 = (((uint32_t) function & 0xffff0000) /* Offset 31:16. */
c0021755:	89 c3                	mov    %eax,%ebx
c0021757:	66 bb 00 00          	mov    $0x0,%bx
c002175b:	09 da                	or     %ebx,%edx
  e0 = (((uint32_t) function & 0xffff)     /* Offset 15:0. */
c002175d:	0f b7 c0             	movzwl %ax,%eax
c0021760:	0d 00 00 08 00       	or     $0x80000,%eax

  return e0 | ((uint64_t) e1 << 32);
}
c0021765:	83 c4 28             	add    $0x28,%esp
c0021768:	5b                   	pop    %ebx
c0021769:	c3                   	ret    

c002176a <register_handler>:
{
c002176a:	53                   	push   %ebx
c002176b:	83 ec 28             	sub    $0x28,%esp
  ASSERT (intr_handlers[vec_no] == NULL);
c002176e:	0f b6 d8             	movzbl %al,%ebx
c0021771:	83 3c 9d 60 68 03 c0 	cmpl   $0x0,-0x3ffc97a0(,%ebx,4)
c0021778:	00 
c0021779:	74 2c                	je     c00217a7 <register_handler+0x3d>
c002177b:	c7 44 24 10 b5 e6 02 	movl   $0xc002e6b5,0x10(%esp)
c0021782:	c0 
c0021783:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002178a:	c0 
c002178b:	c7 44 24 08 87 d1 02 	movl   $0xc002d187,0x8(%esp)
c0021792:	c0 
c0021793:	c7 44 24 04 a8 00 00 	movl   $0xa8,0x4(%esp)
c002179a:	00 
c002179b:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c00217a2:	e8 cc 71 00 00       	call   c0028973 <debug_panic>
  if (level == INTR_ON)
c00217a7:	83 f9 01             	cmp    $0x1,%ecx
c00217aa:	75 1e                	jne    c00217ca <register_handler+0x60>
/* Creates a trap gate that invokes FUNCTION with the given
   DPL. */
static uint64_t
make_trap_gate (void (*function) (void), int dpl)
{
  return make_gate (function, dpl, 15);
c00217ac:	8b 04 9d 4c 56 03 c0 	mov    -0x3ffca9b4(,%ebx,4),%eax
c00217b3:	b1 0f                	mov    $0xf,%cl
c00217b5:	e8 f6 fe ff ff       	call   c00216b0 <make_gate>
    idt[vec_no] = make_trap_gate (intr_stubs[vec_no], dpl);
c00217ba:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c00217c1:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
c00217c8:	eb 1f                	jmp    c00217e9 <register_handler+0x7f>
  return make_gate (function, dpl, 14);
c00217ca:	8b 04 9d 4c 56 03 c0 	mov    -0x3ffca9b4(,%ebx,4),%eax
c00217d1:	b9 0e 00 00 00       	mov    $0xe,%ecx
c00217d6:	e8 d5 fe ff ff       	call   c00216b0 <make_gate>
    idt[vec_no] = make_intr_gate (intr_stubs[vec_no], dpl);
c00217db:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c00217e2:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  intr_handlers[vec_no] = handler;
c00217e9:	8b 44 24 30          	mov    0x30(%esp),%eax
c00217ed:	89 04 9d 60 68 03 c0 	mov    %eax,-0x3ffc97a0(,%ebx,4)
  intr_names[vec_no] = name;
c00217f4:	8b 44 24 34          	mov    0x34(%esp),%eax
c00217f8:	89 04 9d 60 64 03 c0 	mov    %eax,-0x3ffc9ba0(,%ebx,4)
}
c00217ff:	83 c4 28             	add    $0x28,%esp
c0021802:	5b                   	pop    %ebx
c0021803:	c3                   	ret    

c0021804 <intr_get_level>:
  asm volatile ("pushfl; popl %0" : "=g" (flags));
c0021804:	9c                   	pushf  
c0021805:	58                   	pop    %eax
  return flags & FLAG_IF ? INTR_ON : INTR_OFF;
c0021806:	c1 e8 09             	shr    $0x9,%eax
c0021809:	83 e0 01             	and    $0x1,%eax
}
c002180c:	c3                   	ret    

c002180d <intr_enable>:
{
c002180d:	83 ec 2c             	sub    $0x2c,%esp
  enum intr_level old_level = intr_get_level ();
c0021810:	e8 ef ff ff ff       	call   c0021804 <intr_get_level>
  ASSERT (!intr_context ());
c0021815:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c002181c:	74 2c                	je     c002184a <intr_enable+0x3d>
c002181e:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0021825:	c0 
c0021826:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002182d:	c0 
c002182e:	c7 44 24 08 b4 d1 02 	movl   $0xc002d1b4,0x8(%esp)
c0021835:	c0 
c0021836:	c7 44 24 04 5b 00 00 	movl   $0x5b,0x4(%esp)
c002183d:	00 
c002183e:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021845:	e8 29 71 00 00       	call   c0028973 <debug_panic>
  asm volatile ("sti");
c002184a:	fb                   	sti    
}
c002184b:	83 c4 2c             	add    $0x2c,%esp
c002184e:	c3                   	ret    

c002184f <intr_disable>:
  enum intr_level old_level = intr_get_level ();
c002184f:	e8 b0 ff ff ff       	call   c0021804 <intr_get_level>
  asm volatile ("cli" : : : "memory");
c0021854:	fa                   	cli    
}
c0021855:	c3                   	ret    

c0021856 <intr_set_level>:
{
c0021856:	83 ec 0c             	sub    $0xc,%esp
  return level == INTR_ON ? intr_enable () : intr_disable ();
c0021859:	83 7c 24 10 01       	cmpl   $0x1,0x10(%esp)
c002185e:	75 07                	jne    c0021867 <intr_set_level+0x11>
c0021860:	e8 a8 ff ff ff       	call   c002180d <intr_enable>
c0021865:	eb 05                	jmp    c002186c <intr_set_level+0x16>
c0021867:	e8 e3 ff ff ff       	call   c002184f <intr_disable>
}
c002186c:	83 c4 0c             	add    $0xc,%esp
c002186f:	90                   	nop
c0021870:	c3                   	ret    

c0021871 <intr_init>:
{
c0021871:	53                   	push   %ebx
c0021872:	83 ec 18             	sub    $0x18,%esp
/* Writes byte DATA to PORT. */
static inline void
outb (uint16_t port, uint8_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0021875:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c002187a:	e6 21                	out    %al,$0x21
c002187c:	e6 a1                	out    %al,$0xa1
c002187e:	b8 11 00 00 00       	mov    $0x11,%eax
c0021883:	e6 20                	out    %al,$0x20
c0021885:	b8 20 00 00 00       	mov    $0x20,%eax
c002188a:	e6 21                	out    %al,$0x21
c002188c:	b8 04 00 00 00       	mov    $0x4,%eax
c0021891:	e6 21                	out    %al,$0x21
c0021893:	b8 01 00 00 00       	mov    $0x1,%eax
c0021898:	e6 21                	out    %al,$0x21
c002189a:	b8 11 00 00 00       	mov    $0x11,%eax
c002189f:	e6 a0                	out    %al,$0xa0
c00218a1:	b8 28 00 00 00       	mov    $0x28,%eax
c00218a6:	e6 a1                	out    %al,$0xa1
c00218a8:	b8 02 00 00 00       	mov    $0x2,%eax
c00218ad:	e6 a1                	out    %al,$0xa1
c00218af:	b8 01 00 00 00       	mov    $0x1,%eax
c00218b4:	e6 a1                	out    %al,$0xa1
c00218b6:	b8 00 00 00 00       	mov    $0x0,%eax
c00218bb:	e6 21                	out    %al,$0x21
c00218bd:	e6 a1                	out    %al,$0xa1
  for (i = 0; i < INTR_CNT; i++)
c00218bf:	bb 00 00 00 00       	mov    $0x0,%ebx
  return make_gate (function, dpl, 14);
c00218c4:	8b 04 9d 4c 56 03 c0 	mov    -0x3ffca9b4(,%ebx,4),%eax
c00218cb:	b9 0e 00 00 00       	mov    $0xe,%ecx
c00218d0:	ba 00 00 00 00       	mov    $0x0,%edx
c00218d5:	e8 d6 fd ff ff       	call   c00216b0 <make_gate>
    idt[i] = make_intr_gate (intr_stubs[i], 0);
c00218da:	89 04 dd 60 6c 03 c0 	mov    %eax,-0x3ffc93a0(,%ebx,8)
c00218e1:	89 14 dd 64 6c 03 c0 	mov    %edx,-0x3ffc939c(,%ebx,8)
  for (i = 0; i < INTR_CNT; i++)
c00218e8:	83 c3 01             	add    $0x1,%ebx
c00218eb:	81 fb 00 01 00 00    	cmp    $0x100,%ebx
c00218f1:	75 d1                	jne    c00218c4 <intr_init+0x53>
/* Returns a descriptor that yields the given LIMIT and BASE when
   used as an operand for the LIDT instruction. */
static inline uint64_t
make_idtr_operand (uint16_t limit, void *base)
{
  return limit | ((uint64_t) (uint32_t) base << 16);
c00218f3:	b8 60 6c 03 c0       	mov    $0xc0036c60,%eax
c00218f8:	ba 00 00 00 00       	mov    $0x0,%edx
c00218fd:	0f a4 c2 10          	shld   $0x10,%eax,%edx
c0021901:	c1 e0 10             	shl    $0x10,%eax
c0021904:	0d ff 07 00 00       	or     $0x7ff,%eax
c0021909:	89 44 24 08          	mov    %eax,0x8(%esp)
c002190d:	89 54 24 0c          	mov    %edx,0xc(%esp)
  asm volatile ("lidt %0" : : "m" (idtr_operand));
c0021911:	0f 01 5c 24 08       	lidtl  0x8(%esp)
  for (i = 0; i < INTR_CNT; i++)
c0021916:	b8 00 00 00 00       	mov    $0x0,%eax
    intr_names[i] = "unknown";
c002191b:	c7 04 85 60 64 03 c0 	movl   $0xc002e6d3,-0x3ffc9ba0(,%eax,4)
c0021922:	d3 e6 02 c0 
  for (i = 0; i < INTR_CNT; i++)
c0021926:	83 c0 01             	add    $0x1,%eax
c0021929:	3d 00 01 00 00       	cmp    $0x100,%eax
c002192e:	75 eb                	jne    c002191b <intr_init+0xaa>
  intr_names[0] = "#DE Divide Error";
c0021930:	c7 05 60 64 03 c0 db 	movl   $0xc002e6db,0xc0036460
c0021937:	e6 02 c0 
  intr_names[1] = "#DB Debug Exception";
c002193a:	c7 05 64 64 03 c0 ec 	movl   $0xc002e6ec,0xc0036464
c0021941:	e6 02 c0 
  intr_names[2] = "NMI Interrupt";
c0021944:	c7 05 68 64 03 c0 00 	movl   $0xc002e700,0xc0036468
c002194b:	e7 02 c0 
  intr_names[3] = "#BP Breakpoint Exception";
c002194e:	c7 05 6c 64 03 c0 0e 	movl   $0xc002e70e,0xc003646c
c0021955:	e7 02 c0 
  intr_names[4] = "#OF Overflow Exception";
c0021958:	c7 05 70 64 03 c0 27 	movl   $0xc002e727,0xc0036470
c002195f:	e7 02 c0 
  intr_names[5] = "#BR BOUND Range Exceeded Exception";
c0021962:	c7 05 74 64 03 c0 64 	movl   $0xc002e864,0xc0036474
c0021969:	e8 02 c0 
  intr_names[6] = "#UD Invalid Opcode Exception";
c002196c:	c7 05 78 64 03 c0 3e 	movl   $0xc002e73e,0xc0036478
c0021973:	e7 02 c0 
  intr_names[7] = "#NM Device Not Available Exception";
c0021976:	c7 05 7c 64 03 c0 88 	movl   $0xc002e888,0xc003647c
c002197d:	e8 02 c0 
  intr_names[8] = "#DF Double Fault Exception";
c0021980:	c7 05 80 64 03 c0 5b 	movl   $0xc002e75b,0xc0036480
c0021987:	e7 02 c0 
  intr_names[9] = "Coprocessor Segment Overrun";
c002198a:	c7 05 84 64 03 c0 76 	movl   $0xc002e776,0xc0036484
c0021991:	e7 02 c0 
  intr_names[10] = "#TS Invalid TSS Exception";
c0021994:	c7 05 88 64 03 c0 92 	movl   $0xc002e792,0xc0036488
c002199b:	e7 02 c0 
  intr_names[11] = "#NP Segment Not Present";
c002199e:	c7 05 8c 64 03 c0 ac 	movl   $0xc002e7ac,0xc003648c
c00219a5:	e7 02 c0 
  intr_names[12] = "#SS Stack Fault Exception";
c00219a8:	c7 05 90 64 03 c0 c4 	movl   $0xc002e7c4,0xc0036490
c00219af:	e7 02 c0 
  intr_names[13] = "#GP General Protection Exception";
c00219b2:	c7 05 94 64 03 c0 ac 	movl   $0xc002e8ac,0xc0036494
c00219b9:	e8 02 c0 
  intr_names[14] = "#PF Page-Fault Exception";
c00219bc:	c7 05 98 64 03 c0 de 	movl   $0xc002e7de,0xc0036498
c00219c3:	e7 02 c0 
  intr_names[16] = "#MF x87 FPU Floating-Point Error";
c00219c6:	c7 05 a0 64 03 c0 d0 	movl   $0xc002e8d0,0xc00364a0
c00219cd:	e8 02 c0 
  intr_names[17] = "#AC Alignment Check Exception";
c00219d0:	c7 05 a4 64 03 c0 f7 	movl   $0xc002e7f7,0xc00364a4
c00219d7:	e7 02 c0 
  intr_names[18] = "#MC Machine-Check Exception";
c00219da:	c7 05 a8 64 03 c0 15 	movl   $0xc002e815,0xc00364a8
c00219e1:	e8 02 c0 
  intr_names[19] = "#XF SIMD Floating-Point Exception";
c00219e4:	c7 05 ac 64 03 c0 f4 	movl   $0xc002e8f4,0xc00364ac
c00219eb:	e8 02 c0 
}
c00219ee:	83 c4 18             	add    $0x18,%esp
c00219f1:	5b                   	pop    %ebx
c00219f2:	c3                   	ret    

c00219f3 <intr_register_ext>:
{
c00219f3:	83 ec 2c             	sub    $0x2c,%esp
c00219f6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no >= 0x20 && vec_no <= 0x2f);
c00219fa:	8d 50 e0             	lea    -0x20(%eax),%edx
c00219fd:	80 fa 0f             	cmp    $0xf,%dl
c0021a00:	76 2c                	jbe    c0021a2e <intr_register_ext+0x3b>
c0021a02:	c7 44 24 10 18 e9 02 	movl   $0xc002e918,0x10(%esp)
c0021a09:	c0 
c0021a0a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021a11:	c0 
c0021a12:	c7 44 24 08 98 d1 02 	movl   $0xc002d198,0x8(%esp)
c0021a19:	c0 
c0021a1a:	c7 44 24 04 b8 00 00 	movl   $0xb8,0x4(%esp)
c0021a21:	00 
c0021a22:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021a29:	e8 45 6f 00 00       	call   c0028973 <debug_panic>
  register_handler (vec_no, 0, INTR_OFF, handler, name);
c0021a2e:	0f b6 c0             	movzbl %al,%eax
c0021a31:	8b 54 24 38          	mov    0x38(%esp),%edx
c0021a35:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021a39:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021a3d:	89 14 24             	mov    %edx,(%esp)
c0021a40:	b9 00 00 00 00       	mov    $0x0,%ecx
c0021a45:	ba 00 00 00 00       	mov    $0x0,%edx
c0021a4a:	e8 1b fd ff ff       	call   c002176a <register_handler>
}
c0021a4f:	83 c4 2c             	add    $0x2c,%esp
c0021a52:	c3                   	ret    

c0021a53 <intr_register_int>:
{
c0021a53:	83 ec 2c             	sub    $0x2c,%esp
c0021a56:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (vec_no < 0x20 || vec_no > 0x2f);
c0021a5a:	8d 50 e0             	lea    -0x20(%eax),%edx
c0021a5d:	80 fa 0f             	cmp    $0xf,%dl
c0021a60:	77 2c                	ja     c0021a8e <intr_register_int+0x3b>
c0021a62:	c7 44 24 10 3c e9 02 	movl   $0xc002e93c,0x10(%esp)
c0021a69:	c0 
c0021a6a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021a71:	c0 
c0021a72:	c7 44 24 08 75 d1 02 	movl   $0xc002d175,0x8(%esp)
c0021a79:	c0 
c0021a7a:	c7 44 24 04 cd 00 00 	movl   $0xcd,0x4(%esp)
c0021a81:	00 
c0021a82:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021a89:	e8 e5 6e 00 00       	call   c0028973 <debug_panic>
  register_handler (vec_no, dpl, level, handler, name);
c0021a8e:	0f b6 c0             	movzbl %al,%eax
c0021a91:	8b 54 24 40          	mov    0x40(%esp),%edx
c0021a95:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021a99:	8b 54 24 3c          	mov    0x3c(%esp),%edx
c0021a9d:	89 14 24             	mov    %edx,(%esp)
c0021aa0:	8b 4c 24 38          	mov    0x38(%esp),%ecx
c0021aa4:	8b 54 24 34          	mov    0x34(%esp),%edx
c0021aa8:	e8 bd fc ff ff       	call   c002176a <register_handler>
}
c0021aad:	83 c4 2c             	add    $0x2c,%esp
c0021ab0:	c3                   	ret    

c0021ab1 <intr_context>:
}
c0021ab1:	0f b6 05 41 60 03 c0 	movzbl 0xc0036041,%eax
c0021ab8:	c3                   	ret    

c0021ab9 <intr_yield_on_return>:
  ASSERT (intr_context ());
c0021ab9:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021ac0:	75 2f                	jne    c0021af1 <intr_yield_on_return+0x38>
{
c0021ac2:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_context ());
c0021ac5:	c7 44 24 10 a3 e5 02 	movl   $0xc002e5a3,0x10(%esp)
c0021acc:	c0 
c0021acd:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021ad4:	c0 
c0021ad5:	c7 44 24 08 60 d1 02 	movl   $0xc002d160,0x8(%esp)
c0021adc:	c0 
c0021add:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c0021ae4:	00 
c0021ae5:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021aec:	e8 82 6e 00 00       	call   c0028973 <debug_panic>
  yield_on_return = true;
c0021af1:	c6 05 40 60 03 c0 01 	movb   $0x1,0xc0036040
c0021af8:	c3                   	ret    

c0021af9 <intr_handler>:
   function is called by the assembly language interrupt stubs in
   intr-stubs.S.  FRAME describes the interrupt and the
   interrupted thread's registers. */
void
intr_handler (struct intr_frame *frame) 
{
c0021af9:	56                   	push   %esi
c0021afa:	53                   	push   %ebx
c0021afb:	83 ec 24             	sub    $0x24,%esp
c0021afe:	8b 5c 24 30          	mov    0x30(%esp),%ebx

  /* External interrupts are special.
     We only handle one at a time (so interrupts must be off)
     and they need to be acknowledged on the PIC (see below).
     An external interrupt handler cannot sleep. */
  external = frame->vec_no >= 0x20 && frame->vec_no < 0x30;
c0021b02:	8b 43 30             	mov    0x30(%ebx),%eax
c0021b05:	83 e8 20             	sub    $0x20,%eax
c0021b08:	83 f8 0f             	cmp    $0xf,%eax
  if (external) 
c0021b0b:	0f 96 c0             	setbe  %al
c0021b0e:	89 c6                	mov    %eax,%esi
c0021b10:	77 78                	ja     c0021b8a <intr_handler+0x91>
    {
      ASSERT (intr_get_level () == INTR_OFF);
c0021b12:	e8 ed fc ff ff       	call   c0021804 <intr_get_level>
c0021b17:	85 c0                	test   %eax,%eax
c0021b19:	74 2c                	je     c0021b47 <intr_handler+0x4e>
c0021b1b:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0021b22:	c0 
c0021b23:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021b2a:	c0 
c0021b2b:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021b32:	c0 
c0021b33:	c7 44 24 04 65 01 00 	movl   $0x165,0x4(%esp)
c0021b3a:	00 
c0021b3b:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021b42:	e8 2c 6e 00 00       	call   c0028973 <debug_panic>
      ASSERT (!intr_context ());
c0021b47:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021b4e:	74 2c                	je     c0021b7c <intr_handler+0x83>
c0021b50:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0021b57:	c0 
c0021b58:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021b5f:	c0 
c0021b60:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021b67:	c0 
c0021b68:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0021b6f:	00 
c0021b70:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021b77:	e8 f7 6d 00 00       	call   c0028973 <debug_panic>

      in_external_intr = true;
c0021b7c:	c6 05 41 60 03 c0 01 	movb   $0x1,0xc0036041
      yield_on_return = false;
c0021b83:	c6 05 40 60 03 c0 00 	movb   $0x0,0xc0036040
    }

  /* Invoke the interrupt's handler. */
  handler = intr_handlers[frame->vec_no];
c0021b8a:	8b 53 30             	mov    0x30(%ebx),%edx
c0021b8d:	8b 04 95 60 68 03 c0 	mov    -0x3ffc97a0(,%edx,4),%eax
  if (handler != NULL)
c0021b94:	85 c0                	test   %eax,%eax
c0021b96:	74 07                	je     c0021b9f <intr_handler+0xa6>
    handler (frame);
c0021b98:	89 1c 24             	mov    %ebx,(%esp)
c0021b9b:	ff d0                	call   *%eax
c0021b9d:	eb 3a                	jmp    c0021bd9 <intr_handler+0xe0>
  else if (frame->vec_no == 0x27 || frame->vec_no == 0x2f)
c0021b9f:	89 d0                	mov    %edx,%eax
c0021ba1:	83 e0 f7             	and    $0xfffffff7,%eax
c0021ba4:	83 f8 27             	cmp    $0x27,%eax
c0021ba7:	74 30                	je     c0021bd9 <intr_handler+0xe0>
   unexpected interrupt is one that has no registered handler. */
static void
unexpected_interrupt (const struct intr_frame *f)
{
  /* Count the number so far. */
  unsigned int n = ++unexpected_cnt[f->vec_no];
c0021ba9:	8b 04 95 60 60 03 c0 	mov    -0x3ffc9fa0(,%edx,4),%eax
c0021bb0:	8d 48 01             	lea    0x1(%eax),%ecx
c0021bb3:	89 0c 95 60 60 03 c0 	mov    %ecx,-0x3ffc9fa0(,%edx,4)
  /* If the number is a power of 2, print a message.  This rate
     limiting means that we get information about an uncommon
     unexpected interrupt the first time and fairly often after
     that, but one that occurs many times will not overwhelm the
     console. */
  if ((n & (n - 1)) == 0)
c0021bba:	85 c1                	test   %eax,%ecx
c0021bbc:	75 1b                	jne    c0021bd9 <intr_handler+0xe0>
    printf ("Unexpected interrupt %#04x (%s)\n",
c0021bbe:	8b 04 95 60 64 03 c0 	mov    -0x3ffc9ba0(,%edx,4),%eax
c0021bc5:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021bc9:	89 54 24 04          	mov    %edx,0x4(%esp)
c0021bcd:	c7 04 24 5c e9 02 c0 	movl   $0xc002e95c,(%esp)
c0021bd4:	e8 45 4f 00 00       	call   c0026b1e <printf>
  if (external) 
c0021bd9:	89 f0                	mov    %esi,%eax
c0021bdb:	84 c0                	test   %al,%al
c0021bdd:	0f 84 c4 00 00 00    	je     c0021ca7 <intr_handler+0x1ae>
      ASSERT (intr_get_level () == INTR_OFF);
c0021be3:	e8 1c fc ff ff       	call   c0021804 <intr_get_level>
c0021be8:	85 c0                	test   %eax,%eax
c0021bea:	74 2c                	je     c0021c18 <intr_handler+0x11f>
c0021bec:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0021bf3:	c0 
c0021bf4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021bfb:	c0 
c0021bfc:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021c03:	c0 
c0021c04:	c7 44 24 04 7c 01 00 	movl   $0x17c,0x4(%esp)
c0021c0b:	00 
c0021c0c:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021c13:	e8 5b 6d 00 00       	call   c0028973 <debug_panic>
      ASSERT (intr_context ());
c0021c18:	80 3d 41 60 03 c0 00 	cmpb   $0x0,0xc0036041
c0021c1f:	75 2c                	jne    c0021c4d <intr_handler+0x154>
c0021c21:	c7 44 24 10 a3 e5 02 	movl   $0xc002e5a3,0x10(%esp)
c0021c28:	c0 
c0021c29:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021c30:	c0 
c0021c31:	c7 44 24 08 53 d1 02 	movl   $0xc002d153,0x8(%esp)
c0021c38:	c0 
c0021c39:	c7 44 24 04 7d 01 00 	movl   $0x17d,0x4(%esp)
c0021c40:	00 
c0021c41:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021c48:	e8 26 6d 00 00       	call   c0028973 <debug_panic>
      in_external_intr = false;
c0021c4d:	c6 05 41 60 03 c0 00 	movb   $0x0,0xc0036041
      pic_end_of_interrupt (frame->vec_no); 
c0021c54:	8b 53 30             	mov    0x30(%ebx),%edx
  ASSERT (irq >= 0x20 && irq < 0x30);
c0021c57:	8d 42 e0             	lea    -0x20(%edx),%eax
c0021c5a:	83 f8 0f             	cmp    $0xf,%eax
c0021c5d:	76 2c                	jbe    c0021c8b <intr_handler+0x192>
c0021c5f:	c7 44 24 10 31 e8 02 	movl   $0xc002e831,0x10(%esp)
c0021c66:	c0 
c0021c67:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0021c6e:	c0 
c0021c6f:	c7 44 24 08 3e d1 02 	movl   $0xc002d13e,0x8(%esp)
c0021c76:	c0 
c0021c77:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0021c7e:	00 
c0021c7f:	c7 04 24 6e e6 02 c0 	movl   $0xc002e66e,(%esp)
c0021c86:	e8 e8 6c 00 00       	call   c0028973 <debug_panic>
c0021c8b:	b8 20 00 00 00       	mov    $0x20,%eax
c0021c90:	e6 20                	out    %al,$0x20
  if (irq >= 0x28)
c0021c92:	83 fa 27             	cmp    $0x27,%edx
c0021c95:	7e 02                	jle    c0021c99 <intr_handler+0x1a0>
c0021c97:	e6 a0                	out    %al,$0xa0
      if (yield_on_return) 
c0021c99:	80 3d 40 60 03 c0 00 	cmpb   $0x0,0xc0036040
c0021ca0:	74 05                	je     c0021ca7 <intr_handler+0x1ae>
        thread_yield (); 
c0021ca2:	e8 80 f6 ff ff       	call   c0021327 <thread_yield>
}
c0021ca7:	83 c4 24             	add    $0x24,%esp
c0021caa:	5b                   	pop    %ebx
c0021cab:	5e                   	pop    %esi
c0021cac:	c3                   	ret    

c0021cad <intr_dump_frame>:
}

/* Dumps interrupt frame F to the console, for debugging. */
void
intr_dump_frame (const struct intr_frame *f) 
{
c0021cad:	56                   	push   %esi
c0021cae:	53                   	push   %ebx
c0021caf:	83 ec 24             	sub    $0x24,%esp
c0021cb2:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  /* Store current value of CR2 into `cr2'.
     CR2 is the linear address of the last page fault.
     See [IA32-v2a] "MOV--Move to/from Control Registers" and
     [IA32-v3a] 5.14 "Interrupt 14--Page Fault Exception
     (#PF)". */
  asm ("movl %%cr2, %0" : "=r" (cr2));
c0021cb6:	0f 20 d6             	mov    %cr2,%esi

  printf ("Interrupt %#04x (%s) at eip=%p\n",
          f->vec_no, intr_names[f->vec_no], f->eip);
c0021cb9:	8b 43 30             	mov    0x30(%ebx),%eax
  printf ("Interrupt %#04x (%s) at eip=%p\n",
c0021cbc:	8b 53 3c             	mov    0x3c(%ebx),%edx
c0021cbf:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0021cc3:	8b 14 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%edx
c0021cca:	89 54 24 08          	mov    %edx,0x8(%esp)
c0021cce:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021cd2:	c7 04 24 80 e9 02 c0 	movl   $0xc002e980,(%esp)
c0021cd9:	e8 40 4e 00 00       	call   c0026b1e <printf>
  printf (" cr2=%08"PRIx32" error=%08"PRIx32"\n", cr2, f->error_code);
c0021cde:	8b 43 34             	mov    0x34(%ebx),%eax
c0021ce1:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021ce5:	89 74 24 04          	mov    %esi,0x4(%esp)
c0021ce9:	c7 04 24 4b e8 02 c0 	movl   $0xc002e84b,(%esp)
c0021cf0:	e8 29 4e 00 00       	call   c0026b1e <printf>
  printf (" eax=%08"PRIx32" ebx=%08"PRIx32" ecx=%08"PRIx32" edx=%08"PRIx32"\n",
c0021cf5:	8b 43 14             	mov    0x14(%ebx),%eax
c0021cf8:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021cfc:	8b 43 18             	mov    0x18(%ebx),%eax
c0021cff:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021d03:	8b 43 10             	mov    0x10(%ebx),%eax
c0021d06:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021d0a:	8b 43 1c             	mov    0x1c(%ebx),%eax
c0021d0d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021d11:	c7 04 24 a0 e9 02 c0 	movl   $0xc002e9a0,(%esp)
c0021d18:	e8 01 4e 00 00       	call   c0026b1e <printf>
          f->eax, f->ebx, f->ecx, f->edx);
  printf (" esi=%08"PRIx32" edi=%08"PRIx32" esp=%08"PRIx32" ebp=%08"PRIx32"\n",
c0021d1d:	8b 43 08             	mov    0x8(%ebx),%eax
c0021d20:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021d24:	8b 43 48             	mov    0x48(%ebx),%eax
c0021d27:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021d2b:	8b 03                	mov    (%ebx),%eax
c0021d2d:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021d31:	8b 43 04             	mov    0x4(%ebx),%eax
c0021d34:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021d38:	c7 04 24 c8 e9 02 c0 	movl   $0xc002e9c8,(%esp)
c0021d3f:	e8 da 4d 00 00       	call   c0026b1e <printf>
          f->esi, f->edi, (uint32_t) f->esp, f->ebp);
  printf (" cs=%04"PRIx16" ds=%04"PRIx16" es=%04"PRIx16" ss=%04"PRIx16"\n",
c0021d44:	0f b7 43 4c          	movzwl 0x4c(%ebx),%eax
c0021d48:	89 44 24 10          	mov    %eax,0x10(%esp)
c0021d4c:	0f b7 43 28          	movzwl 0x28(%ebx),%eax
c0021d50:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0021d54:	0f b7 43 2c          	movzwl 0x2c(%ebx),%eax
c0021d58:	89 44 24 08          	mov    %eax,0x8(%esp)
c0021d5c:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
c0021d60:	89 44 24 04          	mov    %eax,0x4(%esp)
c0021d64:	c7 04 24 f0 e9 02 c0 	movl   $0xc002e9f0,(%esp)
c0021d6b:	e8 ae 4d 00 00       	call   c0026b1e <printf>
          f->cs, f->ds, f->es, f->ss);
}
c0021d70:	83 c4 24             	add    $0x24,%esp
c0021d73:	5b                   	pop    %ebx
c0021d74:	5e                   	pop    %esi
c0021d75:	c3                   	ret    

c0021d76 <intr_name>:

/* Returns the name of interrupt VEC. */
const char *
intr_name (uint8_t vec) 
{
  return intr_names[vec];
c0021d76:	0f b6 44 24 04       	movzbl 0x4(%esp),%eax
c0021d7b:	8b 04 85 60 64 03 c0 	mov    -0x3ffc9ba0(,%eax,4),%eax
}
c0021d82:	c3                   	ret    

c0021d83 <intr_entry>:
   We "fall through" to intr_exit to return from the interrupt.
*/
.func intr_entry
intr_entry:
	/* Save caller's registers. */
	pushl %ds
c0021d83:	1e                   	push   %ds
	pushl %es
c0021d84:	06                   	push   %es
	pushl %fs
c0021d85:	0f a0                	push   %fs
	pushl %gs
c0021d87:	0f a8                	push   %gs
	pushal
c0021d89:	60                   	pusha  
        
	/* Set up kernel environment. */
	cld			/* String instructions go upward. */
c0021d8a:	fc                   	cld    
	mov $SEL_KDSEG, %eax	/* Initialize segment registers. */
c0021d8b:	b8 10 00 00 00       	mov    $0x10,%eax
	mov %eax, %ds
c0021d90:	8e d8                	mov    %eax,%ds
	mov %eax, %es
c0021d92:	8e c0                	mov    %eax,%es
	leal 56(%esp), %ebp	/* Set up frame pointer. */
c0021d94:	8d 6c 24 38          	lea    0x38(%esp),%ebp

	/* Call interrupt handler. */
	pushl %esp
c0021d98:	54                   	push   %esp
.globl intr_handler
	call intr_handler
c0021d99:	e8 5b fd ff ff       	call   c0021af9 <intr_handler>
	addl $4, %esp
c0021d9e:	83 c4 04             	add    $0x4,%esp

c0021da1 <intr_exit>:
   userprog/process.c). */
.globl intr_exit
.func intr_exit
intr_exit:
        /* Restore caller's registers. */
	popal
c0021da1:	61                   	popa   
	popl %gs
c0021da2:	0f a9                	pop    %gs
	popl %fs
c0021da4:	0f a1                	pop    %fs
	popl %es
c0021da6:	07                   	pop    %es
	popl %ds
c0021da7:	1f                   	pop    %ds

        /* Discard `struct intr_frame' vec_no, error_code,
           frame_pointer members. */
	addl $12, %esp
c0021da8:	83 c4 0c             	add    $0xc,%esp

        /* Return to caller. */
	iret
c0021dab:	cf                   	iret   

c0021dac <intr00_stub>:
                                                \
	.data;                                  \
	.long intr##NUMBER##_stub;

/* All the stubs. */
STUB(00, zero) STUB(01, zero) STUB(02, zero) STUB(03, zero)
c0021dac:	55                   	push   %ebp
c0021dad:	6a 00                	push   $0x0
c0021daf:	6a 00                	push   $0x0
c0021db1:	eb d0                	jmp    c0021d83 <intr_entry>

c0021db3 <intr01_stub>:
c0021db3:	55                   	push   %ebp
c0021db4:	6a 00                	push   $0x0
c0021db6:	6a 01                	push   $0x1
c0021db8:	eb c9                	jmp    c0021d83 <intr_entry>

c0021dba <intr02_stub>:
c0021dba:	55                   	push   %ebp
c0021dbb:	6a 00                	push   $0x0
c0021dbd:	6a 02                	push   $0x2
c0021dbf:	eb c2                	jmp    c0021d83 <intr_entry>

c0021dc1 <intr03_stub>:
c0021dc1:	55                   	push   %ebp
c0021dc2:	6a 00                	push   $0x0
c0021dc4:	6a 03                	push   $0x3
c0021dc6:	eb bb                	jmp    c0021d83 <intr_entry>

c0021dc8 <intr04_stub>:
STUB(04, zero) STUB(05, zero) STUB(06, zero) STUB(07, zero)
c0021dc8:	55                   	push   %ebp
c0021dc9:	6a 00                	push   $0x0
c0021dcb:	6a 04                	push   $0x4
c0021dcd:	eb b4                	jmp    c0021d83 <intr_entry>

c0021dcf <intr05_stub>:
c0021dcf:	55                   	push   %ebp
c0021dd0:	6a 00                	push   $0x0
c0021dd2:	6a 05                	push   $0x5
c0021dd4:	eb ad                	jmp    c0021d83 <intr_entry>

c0021dd6 <intr06_stub>:
c0021dd6:	55                   	push   %ebp
c0021dd7:	6a 00                	push   $0x0
c0021dd9:	6a 06                	push   $0x6
c0021ddb:	eb a6                	jmp    c0021d83 <intr_entry>

c0021ddd <intr07_stub>:
c0021ddd:	55                   	push   %ebp
c0021dde:	6a 00                	push   $0x0
c0021de0:	6a 07                	push   $0x7
c0021de2:	eb 9f                	jmp    c0021d83 <intr_entry>

c0021de4 <intr08_stub>:
STUB(08, REAL) STUB(09, zero) STUB(0a, REAL) STUB(0b, REAL)
c0021de4:	ff 34 24             	pushl  (%esp)
c0021de7:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021deb:	6a 08                	push   $0x8
c0021ded:	eb 94                	jmp    c0021d83 <intr_entry>

c0021def <intr09_stub>:
c0021def:	55                   	push   %ebp
c0021df0:	6a 00                	push   $0x0
c0021df2:	6a 09                	push   $0x9
c0021df4:	eb 8d                	jmp    c0021d83 <intr_entry>

c0021df6 <intr0a_stub>:
c0021df6:	ff 34 24             	pushl  (%esp)
c0021df9:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021dfd:	6a 0a                	push   $0xa
c0021dff:	eb 82                	jmp    c0021d83 <intr_entry>

c0021e01 <intr0b_stub>:
c0021e01:	ff 34 24             	pushl  (%esp)
c0021e04:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021e08:	6a 0b                	push   $0xb
c0021e0a:	e9 74 ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e0f <intr0c_stub>:
STUB(0c, zero) STUB(0d, REAL) STUB(0e, REAL) STUB(0f, zero)
c0021e0f:	55                   	push   %ebp
c0021e10:	6a 00                	push   $0x0
c0021e12:	6a 0c                	push   $0xc
c0021e14:	e9 6a ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e19 <intr0d_stub>:
c0021e19:	ff 34 24             	pushl  (%esp)
c0021e1c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021e20:	6a 0d                	push   $0xd
c0021e22:	e9 5c ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e27 <intr0e_stub>:
c0021e27:	ff 34 24             	pushl  (%esp)
c0021e2a:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021e2e:	6a 0e                	push   $0xe
c0021e30:	e9 4e ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e35 <intr0f_stub>:
c0021e35:	55                   	push   %ebp
c0021e36:	6a 00                	push   $0x0
c0021e38:	6a 0f                	push   $0xf
c0021e3a:	e9 44 ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e3f <intr10_stub>:

STUB(10, zero) STUB(11, REAL) STUB(12, zero) STUB(13, zero)
c0021e3f:	55                   	push   %ebp
c0021e40:	6a 00                	push   $0x0
c0021e42:	6a 10                	push   $0x10
c0021e44:	e9 3a ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e49 <intr11_stub>:
c0021e49:	ff 34 24             	pushl  (%esp)
c0021e4c:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021e50:	6a 11                	push   $0x11
c0021e52:	e9 2c ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e57 <intr12_stub>:
c0021e57:	55                   	push   %ebp
c0021e58:	6a 00                	push   $0x0
c0021e5a:	6a 12                	push   $0x12
c0021e5c:	e9 22 ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e61 <intr13_stub>:
c0021e61:	55                   	push   %ebp
c0021e62:	6a 00                	push   $0x0
c0021e64:	6a 13                	push   $0x13
c0021e66:	e9 18 ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e6b <intr14_stub>:
STUB(14, zero) STUB(15, zero) STUB(16, zero) STUB(17, zero)
c0021e6b:	55                   	push   %ebp
c0021e6c:	6a 00                	push   $0x0
c0021e6e:	6a 14                	push   $0x14
c0021e70:	e9 0e ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e75 <intr15_stub>:
c0021e75:	55                   	push   %ebp
c0021e76:	6a 00                	push   $0x0
c0021e78:	6a 15                	push   $0x15
c0021e7a:	e9 04 ff ff ff       	jmp    c0021d83 <intr_entry>

c0021e7f <intr16_stub>:
c0021e7f:	55                   	push   %ebp
c0021e80:	6a 00                	push   $0x0
c0021e82:	6a 16                	push   $0x16
c0021e84:	e9 fa fe ff ff       	jmp    c0021d83 <intr_entry>

c0021e89 <intr17_stub>:
c0021e89:	55                   	push   %ebp
c0021e8a:	6a 00                	push   $0x0
c0021e8c:	6a 17                	push   $0x17
c0021e8e:	e9 f0 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021e93 <intr18_stub>:
STUB(18, REAL) STUB(19, zero) STUB(1a, REAL) STUB(1b, REAL)
c0021e93:	ff 34 24             	pushl  (%esp)
c0021e96:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021e9a:	6a 18                	push   $0x18
c0021e9c:	e9 e2 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021ea1 <intr19_stub>:
c0021ea1:	55                   	push   %ebp
c0021ea2:	6a 00                	push   $0x0
c0021ea4:	6a 19                	push   $0x19
c0021ea6:	e9 d8 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021eab <intr1a_stub>:
c0021eab:	ff 34 24             	pushl  (%esp)
c0021eae:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021eb2:	6a 1a                	push   $0x1a
c0021eb4:	e9 ca fe ff ff       	jmp    c0021d83 <intr_entry>

c0021eb9 <intr1b_stub>:
c0021eb9:	ff 34 24             	pushl  (%esp)
c0021ebc:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021ec0:	6a 1b                	push   $0x1b
c0021ec2:	e9 bc fe ff ff       	jmp    c0021d83 <intr_entry>

c0021ec7 <intr1c_stub>:
STUB(1c, zero) STUB(1d, REAL) STUB(1e, REAL) STUB(1f, zero)
c0021ec7:	55                   	push   %ebp
c0021ec8:	6a 00                	push   $0x0
c0021eca:	6a 1c                	push   $0x1c
c0021ecc:	e9 b2 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021ed1 <intr1d_stub>:
c0021ed1:	ff 34 24             	pushl  (%esp)
c0021ed4:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021ed8:	6a 1d                	push   $0x1d
c0021eda:	e9 a4 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021edf <intr1e_stub>:
c0021edf:	ff 34 24             	pushl  (%esp)
c0021ee2:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0021ee6:	6a 1e                	push   $0x1e
c0021ee8:	e9 96 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021eed <intr1f_stub>:
c0021eed:	55                   	push   %ebp
c0021eee:	6a 00                	push   $0x0
c0021ef0:	6a 1f                	push   $0x1f
c0021ef2:	e9 8c fe ff ff       	jmp    c0021d83 <intr_entry>

c0021ef7 <intr20_stub>:

STUB(20, zero) STUB(21, zero) STUB(22, zero) STUB(23, zero)
c0021ef7:	55                   	push   %ebp
c0021ef8:	6a 00                	push   $0x0
c0021efa:	6a 20                	push   $0x20
c0021efc:	e9 82 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f01 <intr21_stub>:
c0021f01:	55                   	push   %ebp
c0021f02:	6a 00                	push   $0x0
c0021f04:	6a 21                	push   $0x21
c0021f06:	e9 78 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f0b <intr22_stub>:
c0021f0b:	55                   	push   %ebp
c0021f0c:	6a 00                	push   $0x0
c0021f0e:	6a 22                	push   $0x22
c0021f10:	e9 6e fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f15 <intr23_stub>:
c0021f15:	55                   	push   %ebp
c0021f16:	6a 00                	push   $0x0
c0021f18:	6a 23                	push   $0x23
c0021f1a:	e9 64 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f1f <intr24_stub>:
STUB(24, zero) STUB(25, zero) STUB(26, zero) STUB(27, zero)
c0021f1f:	55                   	push   %ebp
c0021f20:	6a 00                	push   $0x0
c0021f22:	6a 24                	push   $0x24
c0021f24:	e9 5a fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f29 <intr25_stub>:
c0021f29:	55                   	push   %ebp
c0021f2a:	6a 00                	push   $0x0
c0021f2c:	6a 25                	push   $0x25
c0021f2e:	e9 50 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f33 <intr26_stub>:
c0021f33:	55                   	push   %ebp
c0021f34:	6a 00                	push   $0x0
c0021f36:	6a 26                	push   $0x26
c0021f38:	e9 46 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f3d <intr27_stub>:
c0021f3d:	55                   	push   %ebp
c0021f3e:	6a 00                	push   $0x0
c0021f40:	6a 27                	push   $0x27
c0021f42:	e9 3c fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f47 <intr28_stub>:
STUB(28, zero) STUB(29, zero) STUB(2a, zero) STUB(2b, zero)
c0021f47:	55                   	push   %ebp
c0021f48:	6a 00                	push   $0x0
c0021f4a:	6a 28                	push   $0x28
c0021f4c:	e9 32 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f51 <intr29_stub>:
c0021f51:	55                   	push   %ebp
c0021f52:	6a 00                	push   $0x0
c0021f54:	6a 29                	push   $0x29
c0021f56:	e9 28 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f5b <intr2a_stub>:
c0021f5b:	55                   	push   %ebp
c0021f5c:	6a 00                	push   $0x0
c0021f5e:	6a 2a                	push   $0x2a
c0021f60:	e9 1e fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f65 <intr2b_stub>:
c0021f65:	55                   	push   %ebp
c0021f66:	6a 00                	push   $0x0
c0021f68:	6a 2b                	push   $0x2b
c0021f6a:	e9 14 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f6f <intr2c_stub>:
STUB(2c, zero) STUB(2d, zero) STUB(2e, zero) STUB(2f, zero)
c0021f6f:	55                   	push   %ebp
c0021f70:	6a 00                	push   $0x0
c0021f72:	6a 2c                	push   $0x2c
c0021f74:	e9 0a fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f79 <intr2d_stub>:
c0021f79:	55                   	push   %ebp
c0021f7a:	6a 00                	push   $0x0
c0021f7c:	6a 2d                	push   $0x2d
c0021f7e:	e9 00 fe ff ff       	jmp    c0021d83 <intr_entry>

c0021f83 <intr2e_stub>:
c0021f83:	55                   	push   %ebp
c0021f84:	6a 00                	push   $0x0
c0021f86:	6a 2e                	push   $0x2e
c0021f88:	e9 f6 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021f8d <intr2f_stub>:
c0021f8d:	55                   	push   %ebp
c0021f8e:	6a 00                	push   $0x0
c0021f90:	6a 2f                	push   $0x2f
c0021f92:	e9 ec fd ff ff       	jmp    c0021d83 <intr_entry>

c0021f97 <intr30_stub>:

STUB(30, zero) STUB(31, zero) STUB(32, zero) STUB(33, zero)
c0021f97:	55                   	push   %ebp
c0021f98:	6a 00                	push   $0x0
c0021f9a:	6a 30                	push   $0x30
c0021f9c:	e9 e2 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fa1 <intr31_stub>:
c0021fa1:	55                   	push   %ebp
c0021fa2:	6a 00                	push   $0x0
c0021fa4:	6a 31                	push   $0x31
c0021fa6:	e9 d8 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fab <intr32_stub>:
c0021fab:	55                   	push   %ebp
c0021fac:	6a 00                	push   $0x0
c0021fae:	6a 32                	push   $0x32
c0021fb0:	e9 ce fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fb5 <intr33_stub>:
c0021fb5:	55                   	push   %ebp
c0021fb6:	6a 00                	push   $0x0
c0021fb8:	6a 33                	push   $0x33
c0021fba:	e9 c4 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fbf <intr34_stub>:
STUB(34, zero) STUB(35, zero) STUB(36, zero) STUB(37, zero)
c0021fbf:	55                   	push   %ebp
c0021fc0:	6a 00                	push   $0x0
c0021fc2:	6a 34                	push   $0x34
c0021fc4:	e9 ba fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fc9 <intr35_stub>:
c0021fc9:	55                   	push   %ebp
c0021fca:	6a 00                	push   $0x0
c0021fcc:	6a 35                	push   $0x35
c0021fce:	e9 b0 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fd3 <intr36_stub>:
c0021fd3:	55                   	push   %ebp
c0021fd4:	6a 00                	push   $0x0
c0021fd6:	6a 36                	push   $0x36
c0021fd8:	e9 a6 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fdd <intr37_stub>:
c0021fdd:	55                   	push   %ebp
c0021fde:	6a 00                	push   $0x0
c0021fe0:	6a 37                	push   $0x37
c0021fe2:	e9 9c fd ff ff       	jmp    c0021d83 <intr_entry>

c0021fe7 <intr38_stub>:
STUB(38, zero) STUB(39, zero) STUB(3a, zero) STUB(3b, zero)
c0021fe7:	55                   	push   %ebp
c0021fe8:	6a 00                	push   $0x0
c0021fea:	6a 38                	push   $0x38
c0021fec:	e9 92 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021ff1 <intr39_stub>:
c0021ff1:	55                   	push   %ebp
c0021ff2:	6a 00                	push   $0x0
c0021ff4:	6a 39                	push   $0x39
c0021ff6:	e9 88 fd ff ff       	jmp    c0021d83 <intr_entry>

c0021ffb <intr3a_stub>:
c0021ffb:	55                   	push   %ebp
c0021ffc:	6a 00                	push   $0x0
c0021ffe:	6a 3a                	push   $0x3a
c0022000:	e9 7e fd ff ff       	jmp    c0021d83 <intr_entry>

c0022005 <intr3b_stub>:
c0022005:	55                   	push   %ebp
c0022006:	6a 00                	push   $0x0
c0022008:	6a 3b                	push   $0x3b
c002200a:	e9 74 fd ff ff       	jmp    c0021d83 <intr_entry>

c002200f <intr3c_stub>:
STUB(3c, zero) STUB(3d, zero) STUB(3e, zero) STUB(3f, zero)
c002200f:	55                   	push   %ebp
c0022010:	6a 00                	push   $0x0
c0022012:	6a 3c                	push   $0x3c
c0022014:	e9 6a fd ff ff       	jmp    c0021d83 <intr_entry>

c0022019 <intr3d_stub>:
c0022019:	55                   	push   %ebp
c002201a:	6a 00                	push   $0x0
c002201c:	6a 3d                	push   $0x3d
c002201e:	e9 60 fd ff ff       	jmp    c0021d83 <intr_entry>

c0022023 <intr3e_stub>:
c0022023:	55                   	push   %ebp
c0022024:	6a 00                	push   $0x0
c0022026:	6a 3e                	push   $0x3e
c0022028:	e9 56 fd ff ff       	jmp    c0021d83 <intr_entry>

c002202d <intr3f_stub>:
c002202d:	55                   	push   %ebp
c002202e:	6a 00                	push   $0x0
c0022030:	6a 3f                	push   $0x3f
c0022032:	e9 4c fd ff ff       	jmp    c0021d83 <intr_entry>

c0022037 <intr40_stub>:

STUB(40, zero) STUB(41, zero) STUB(42, zero) STUB(43, zero)
c0022037:	55                   	push   %ebp
c0022038:	6a 00                	push   $0x0
c002203a:	6a 40                	push   $0x40
c002203c:	e9 42 fd ff ff       	jmp    c0021d83 <intr_entry>

c0022041 <intr41_stub>:
c0022041:	55                   	push   %ebp
c0022042:	6a 00                	push   $0x0
c0022044:	6a 41                	push   $0x41
c0022046:	e9 38 fd ff ff       	jmp    c0021d83 <intr_entry>

c002204b <intr42_stub>:
c002204b:	55                   	push   %ebp
c002204c:	6a 00                	push   $0x0
c002204e:	6a 42                	push   $0x42
c0022050:	e9 2e fd ff ff       	jmp    c0021d83 <intr_entry>

c0022055 <intr43_stub>:
c0022055:	55                   	push   %ebp
c0022056:	6a 00                	push   $0x0
c0022058:	6a 43                	push   $0x43
c002205a:	e9 24 fd ff ff       	jmp    c0021d83 <intr_entry>

c002205f <intr44_stub>:
STUB(44, zero) STUB(45, zero) STUB(46, zero) STUB(47, zero)
c002205f:	55                   	push   %ebp
c0022060:	6a 00                	push   $0x0
c0022062:	6a 44                	push   $0x44
c0022064:	e9 1a fd ff ff       	jmp    c0021d83 <intr_entry>

c0022069 <intr45_stub>:
c0022069:	55                   	push   %ebp
c002206a:	6a 00                	push   $0x0
c002206c:	6a 45                	push   $0x45
c002206e:	e9 10 fd ff ff       	jmp    c0021d83 <intr_entry>

c0022073 <intr46_stub>:
c0022073:	55                   	push   %ebp
c0022074:	6a 00                	push   $0x0
c0022076:	6a 46                	push   $0x46
c0022078:	e9 06 fd ff ff       	jmp    c0021d83 <intr_entry>

c002207d <intr47_stub>:
c002207d:	55                   	push   %ebp
c002207e:	6a 00                	push   $0x0
c0022080:	6a 47                	push   $0x47
c0022082:	e9 fc fc ff ff       	jmp    c0021d83 <intr_entry>

c0022087 <intr48_stub>:
STUB(48, zero) STUB(49, zero) STUB(4a, zero) STUB(4b, zero)
c0022087:	55                   	push   %ebp
c0022088:	6a 00                	push   $0x0
c002208a:	6a 48                	push   $0x48
c002208c:	e9 f2 fc ff ff       	jmp    c0021d83 <intr_entry>

c0022091 <intr49_stub>:
c0022091:	55                   	push   %ebp
c0022092:	6a 00                	push   $0x0
c0022094:	6a 49                	push   $0x49
c0022096:	e9 e8 fc ff ff       	jmp    c0021d83 <intr_entry>

c002209b <intr4a_stub>:
c002209b:	55                   	push   %ebp
c002209c:	6a 00                	push   $0x0
c002209e:	6a 4a                	push   $0x4a
c00220a0:	e9 de fc ff ff       	jmp    c0021d83 <intr_entry>

c00220a5 <intr4b_stub>:
c00220a5:	55                   	push   %ebp
c00220a6:	6a 00                	push   $0x0
c00220a8:	6a 4b                	push   $0x4b
c00220aa:	e9 d4 fc ff ff       	jmp    c0021d83 <intr_entry>

c00220af <intr4c_stub>:
STUB(4c, zero) STUB(4d, zero) STUB(4e, zero) STUB(4f, zero)
c00220af:	55                   	push   %ebp
c00220b0:	6a 00                	push   $0x0
c00220b2:	6a 4c                	push   $0x4c
c00220b4:	e9 ca fc ff ff       	jmp    c0021d83 <intr_entry>

c00220b9 <intr4d_stub>:
c00220b9:	55                   	push   %ebp
c00220ba:	6a 00                	push   $0x0
c00220bc:	6a 4d                	push   $0x4d
c00220be:	e9 c0 fc ff ff       	jmp    c0021d83 <intr_entry>

c00220c3 <intr4e_stub>:
c00220c3:	55                   	push   %ebp
c00220c4:	6a 00                	push   $0x0
c00220c6:	6a 4e                	push   $0x4e
c00220c8:	e9 b6 fc ff ff       	jmp    c0021d83 <intr_entry>

c00220cd <intr4f_stub>:
c00220cd:	55                   	push   %ebp
c00220ce:	6a 00                	push   $0x0
c00220d0:	6a 4f                	push   $0x4f
c00220d2:	e9 ac fc ff ff       	jmp    c0021d83 <intr_entry>

c00220d7 <intr50_stub>:

STUB(50, zero) STUB(51, zero) STUB(52, zero) STUB(53, zero)
c00220d7:	55                   	push   %ebp
c00220d8:	6a 00                	push   $0x0
c00220da:	6a 50                	push   $0x50
c00220dc:	e9 a2 fc ff ff       	jmp    c0021d83 <intr_entry>

c00220e1 <intr51_stub>:
c00220e1:	55                   	push   %ebp
c00220e2:	6a 00                	push   $0x0
c00220e4:	6a 51                	push   $0x51
c00220e6:	e9 98 fc ff ff       	jmp    c0021d83 <intr_entry>

c00220eb <intr52_stub>:
c00220eb:	55                   	push   %ebp
c00220ec:	6a 00                	push   $0x0
c00220ee:	6a 52                	push   $0x52
c00220f0:	e9 8e fc ff ff       	jmp    c0021d83 <intr_entry>

c00220f5 <intr53_stub>:
c00220f5:	55                   	push   %ebp
c00220f6:	6a 00                	push   $0x0
c00220f8:	6a 53                	push   $0x53
c00220fa:	e9 84 fc ff ff       	jmp    c0021d83 <intr_entry>

c00220ff <intr54_stub>:
STUB(54, zero) STUB(55, zero) STUB(56, zero) STUB(57, zero)
c00220ff:	55                   	push   %ebp
c0022100:	6a 00                	push   $0x0
c0022102:	6a 54                	push   $0x54
c0022104:	e9 7a fc ff ff       	jmp    c0021d83 <intr_entry>

c0022109 <intr55_stub>:
c0022109:	55                   	push   %ebp
c002210a:	6a 00                	push   $0x0
c002210c:	6a 55                	push   $0x55
c002210e:	e9 70 fc ff ff       	jmp    c0021d83 <intr_entry>

c0022113 <intr56_stub>:
c0022113:	55                   	push   %ebp
c0022114:	6a 00                	push   $0x0
c0022116:	6a 56                	push   $0x56
c0022118:	e9 66 fc ff ff       	jmp    c0021d83 <intr_entry>

c002211d <intr57_stub>:
c002211d:	55                   	push   %ebp
c002211e:	6a 00                	push   $0x0
c0022120:	6a 57                	push   $0x57
c0022122:	e9 5c fc ff ff       	jmp    c0021d83 <intr_entry>

c0022127 <intr58_stub>:
STUB(58, zero) STUB(59, zero) STUB(5a, zero) STUB(5b, zero)
c0022127:	55                   	push   %ebp
c0022128:	6a 00                	push   $0x0
c002212a:	6a 58                	push   $0x58
c002212c:	e9 52 fc ff ff       	jmp    c0021d83 <intr_entry>

c0022131 <intr59_stub>:
c0022131:	55                   	push   %ebp
c0022132:	6a 00                	push   $0x0
c0022134:	6a 59                	push   $0x59
c0022136:	e9 48 fc ff ff       	jmp    c0021d83 <intr_entry>

c002213b <intr5a_stub>:
c002213b:	55                   	push   %ebp
c002213c:	6a 00                	push   $0x0
c002213e:	6a 5a                	push   $0x5a
c0022140:	e9 3e fc ff ff       	jmp    c0021d83 <intr_entry>

c0022145 <intr5b_stub>:
c0022145:	55                   	push   %ebp
c0022146:	6a 00                	push   $0x0
c0022148:	6a 5b                	push   $0x5b
c002214a:	e9 34 fc ff ff       	jmp    c0021d83 <intr_entry>

c002214f <intr5c_stub>:
STUB(5c, zero) STUB(5d, zero) STUB(5e, zero) STUB(5f, zero)
c002214f:	55                   	push   %ebp
c0022150:	6a 00                	push   $0x0
c0022152:	6a 5c                	push   $0x5c
c0022154:	e9 2a fc ff ff       	jmp    c0021d83 <intr_entry>

c0022159 <intr5d_stub>:
c0022159:	55                   	push   %ebp
c002215a:	6a 00                	push   $0x0
c002215c:	6a 5d                	push   $0x5d
c002215e:	e9 20 fc ff ff       	jmp    c0021d83 <intr_entry>

c0022163 <intr5e_stub>:
c0022163:	55                   	push   %ebp
c0022164:	6a 00                	push   $0x0
c0022166:	6a 5e                	push   $0x5e
c0022168:	e9 16 fc ff ff       	jmp    c0021d83 <intr_entry>

c002216d <intr5f_stub>:
c002216d:	55                   	push   %ebp
c002216e:	6a 00                	push   $0x0
c0022170:	6a 5f                	push   $0x5f
c0022172:	e9 0c fc ff ff       	jmp    c0021d83 <intr_entry>

c0022177 <intr60_stub>:

STUB(60, zero) STUB(61, zero) STUB(62, zero) STUB(63, zero)
c0022177:	55                   	push   %ebp
c0022178:	6a 00                	push   $0x0
c002217a:	6a 60                	push   $0x60
c002217c:	e9 02 fc ff ff       	jmp    c0021d83 <intr_entry>

c0022181 <intr61_stub>:
c0022181:	55                   	push   %ebp
c0022182:	6a 00                	push   $0x0
c0022184:	6a 61                	push   $0x61
c0022186:	e9 f8 fb ff ff       	jmp    c0021d83 <intr_entry>

c002218b <intr62_stub>:
c002218b:	55                   	push   %ebp
c002218c:	6a 00                	push   $0x0
c002218e:	6a 62                	push   $0x62
c0022190:	e9 ee fb ff ff       	jmp    c0021d83 <intr_entry>

c0022195 <intr63_stub>:
c0022195:	55                   	push   %ebp
c0022196:	6a 00                	push   $0x0
c0022198:	6a 63                	push   $0x63
c002219a:	e9 e4 fb ff ff       	jmp    c0021d83 <intr_entry>

c002219f <intr64_stub>:
STUB(64, zero) STUB(65, zero) STUB(66, zero) STUB(67, zero)
c002219f:	55                   	push   %ebp
c00221a0:	6a 00                	push   $0x0
c00221a2:	6a 64                	push   $0x64
c00221a4:	e9 da fb ff ff       	jmp    c0021d83 <intr_entry>

c00221a9 <intr65_stub>:
c00221a9:	55                   	push   %ebp
c00221aa:	6a 00                	push   $0x0
c00221ac:	6a 65                	push   $0x65
c00221ae:	e9 d0 fb ff ff       	jmp    c0021d83 <intr_entry>

c00221b3 <intr66_stub>:
c00221b3:	55                   	push   %ebp
c00221b4:	6a 00                	push   $0x0
c00221b6:	6a 66                	push   $0x66
c00221b8:	e9 c6 fb ff ff       	jmp    c0021d83 <intr_entry>

c00221bd <intr67_stub>:
c00221bd:	55                   	push   %ebp
c00221be:	6a 00                	push   $0x0
c00221c0:	6a 67                	push   $0x67
c00221c2:	e9 bc fb ff ff       	jmp    c0021d83 <intr_entry>

c00221c7 <intr68_stub>:
STUB(68, zero) STUB(69, zero) STUB(6a, zero) STUB(6b, zero)
c00221c7:	55                   	push   %ebp
c00221c8:	6a 00                	push   $0x0
c00221ca:	6a 68                	push   $0x68
c00221cc:	e9 b2 fb ff ff       	jmp    c0021d83 <intr_entry>

c00221d1 <intr69_stub>:
c00221d1:	55                   	push   %ebp
c00221d2:	6a 00                	push   $0x0
c00221d4:	6a 69                	push   $0x69
c00221d6:	e9 a8 fb ff ff       	jmp    c0021d83 <intr_entry>

c00221db <intr6a_stub>:
c00221db:	55                   	push   %ebp
c00221dc:	6a 00                	push   $0x0
c00221de:	6a 6a                	push   $0x6a
c00221e0:	e9 9e fb ff ff       	jmp    c0021d83 <intr_entry>

c00221e5 <intr6b_stub>:
c00221e5:	55                   	push   %ebp
c00221e6:	6a 00                	push   $0x0
c00221e8:	6a 6b                	push   $0x6b
c00221ea:	e9 94 fb ff ff       	jmp    c0021d83 <intr_entry>

c00221ef <intr6c_stub>:
STUB(6c, zero) STUB(6d, zero) STUB(6e, zero) STUB(6f, zero)
c00221ef:	55                   	push   %ebp
c00221f0:	6a 00                	push   $0x0
c00221f2:	6a 6c                	push   $0x6c
c00221f4:	e9 8a fb ff ff       	jmp    c0021d83 <intr_entry>

c00221f9 <intr6d_stub>:
c00221f9:	55                   	push   %ebp
c00221fa:	6a 00                	push   $0x0
c00221fc:	6a 6d                	push   $0x6d
c00221fe:	e9 80 fb ff ff       	jmp    c0021d83 <intr_entry>

c0022203 <intr6e_stub>:
c0022203:	55                   	push   %ebp
c0022204:	6a 00                	push   $0x0
c0022206:	6a 6e                	push   $0x6e
c0022208:	e9 76 fb ff ff       	jmp    c0021d83 <intr_entry>

c002220d <intr6f_stub>:
c002220d:	55                   	push   %ebp
c002220e:	6a 00                	push   $0x0
c0022210:	6a 6f                	push   $0x6f
c0022212:	e9 6c fb ff ff       	jmp    c0021d83 <intr_entry>

c0022217 <intr70_stub>:

STUB(70, zero) STUB(71, zero) STUB(72, zero) STUB(73, zero)
c0022217:	55                   	push   %ebp
c0022218:	6a 00                	push   $0x0
c002221a:	6a 70                	push   $0x70
c002221c:	e9 62 fb ff ff       	jmp    c0021d83 <intr_entry>

c0022221 <intr71_stub>:
c0022221:	55                   	push   %ebp
c0022222:	6a 00                	push   $0x0
c0022224:	6a 71                	push   $0x71
c0022226:	e9 58 fb ff ff       	jmp    c0021d83 <intr_entry>

c002222b <intr72_stub>:
c002222b:	55                   	push   %ebp
c002222c:	6a 00                	push   $0x0
c002222e:	6a 72                	push   $0x72
c0022230:	e9 4e fb ff ff       	jmp    c0021d83 <intr_entry>

c0022235 <intr73_stub>:
c0022235:	55                   	push   %ebp
c0022236:	6a 00                	push   $0x0
c0022238:	6a 73                	push   $0x73
c002223a:	e9 44 fb ff ff       	jmp    c0021d83 <intr_entry>

c002223f <intr74_stub>:
STUB(74, zero) STUB(75, zero) STUB(76, zero) STUB(77, zero)
c002223f:	55                   	push   %ebp
c0022240:	6a 00                	push   $0x0
c0022242:	6a 74                	push   $0x74
c0022244:	e9 3a fb ff ff       	jmp    c0021d83 <intr_entry>

c0022249 <intr75_stub>:
c0022249:	55                   	push   %ebp
c002224a:	6a 00                	push   $0x0
c002224c:	6a 75                	push   $0x75
c002224e:	e9 30 fb ff ff       	jmp    c0021d83 <intr_entry>

c0022253 <intr76_stub>:
c0022253:	55                   	push   %ebp
c0022254:	6a 00                	push   $0x0
c0022256:	6a 76                	push   $0x76
c0022258:	e9 26 fb ff ff       	jmp    c0021d83 <intr_entry>

c002225d <intr77_stub>:
c002225d:	55                   	push   %ebp
c002225e:	6a 00                	push   $0x0
c0022260:	6a 77                	push   $0x77
c0022262:	e9 1c fb ff ff       	jmp    c0021d83 <intr_entry>

c0022267 <intr78_stub>:
STUB(78, zero) STUB(79, zero) STUB(7a, zero) STUB(7b, zero)
c0022267:	55                   	push   %ebp
c0022268:	6a 00                	push   $0x0
c002226a:	6a 78                	push   $0x78
c002226c:	e9 12 fb ff ff       	jmp    c0021d83 <intr_entry>

c0022271 <intr79_stub>:
c0022271:	55                   	push   %ebp
c0022272:	6a 00                	push   $0x0
c0022274:	6a 79                	push   $0x79
c0022276:	e9 08 fb ff ff       	jmp    c0021d83 <intr_entry>

c002227b <intr7a_stub>:
c002227b:	55                   	push   %ebp
c002227c:	6a 00                	push   $0x0
c002227e:	6a 7a                	push   $0x7a
c0022280:	e9 fe fa ff ff       	jmp    c0021d83 <intr_entry>

c0022285 <intr7b_stub>:
c0022285:	55                   	push   %ebp
c0022286:	6a 00                	push   $0x0
c0022288:	6a 7b                	push   $0x7b
c002228a:	e9 f4 fa ff ff       	jmp    c0021d83 <intr_entry>

c002228f <intr7c_stub>:
STUB(7c, zero) STUB(7d, zero) STUB(7e, zero) STUB(7f, zero)
c002228f:	55                   	push   %ebp
c0022290:	6a 00                	push   $0x0
c0022292:	6a 7c                	push   $0x7c
c0022294:	e9 ea fa ff ff       	jmp    c0021d83 <intr_entry>

c0022299 <intr7d_stub>:
c0022299:	55                   	push   %ebp
c002229a:	6a 00                	push   $0x0
c002229c:	6a 7d                	push   $0x7d
c002229e:	e9 e0 fa ff ff       	jmp    c0021d83 <intr_entry>

c00222a3 <intr7e_stub>:
c00222a3:	55                   	push   %ebp
c00222a4:	6a 00                	push   $0x0
c00222a6:	6a 7e                	push   $0x7e
c00222a8:	e9 d6 fa ff ff       	jmp    c0021d83 <intr_entry>

c00222ad <intr7f_stub>:
c00222ad:	55                   	push   %ebp
c00222ae:	6a 00                	push   $0x0
c00222b0:	6a 7f                	push   $0x7f
c00222b2:	e9 cc fa ff ff       	jmp    c0021d83 <intr_entry>

c00222b7 <intr80_stub>:

STUB(80, zero) STUB(81, zero) STUB(82, zero) STUB(83, zero)
c00222b7:	55                   	push   %ebp
c00222b8:	6a 00                	push   $0x0
c00222ba:	68 80 00 00 00       	push   $0x80
c00222bf:	e9 bf fa ff ff       	jmp    c0021d83 <intr_entry>

c00222c4 <intr81_stub>:
c00222c4:	55                   	push   %ebp
c00222c5:	6a 00                	push   $0x0
c00222c7:	68 81 00 00 00       	push   $0x81
c00222cc:	e9 b2 fa ff ff       	jmp    c0021d83 <intr_entry>

c00222d1 <intr82_stub>:
c00222d1:	55                   	push   %ebp
c00222d2:	6a 00                	push   $0x0
c00222d4:	68 82 00 00 00       	push   $0x82
c00222d9:	e9 a5 fa ff ff       	jmp    c0021d83 <intr_entry>

c00222de <intr83_stub>:
c00222de:	55                   	push   %ebp
c00222df:	6a 00                	push   $0x0
c00222e1:	68 83 00 00 00       	push   $0x83
c00222e6:	e9 98 fa ff ff       	jmp    c0021d83 <intr_entry>

c00222eb <intr84_stub>:
STUB(84, zero) STUB(85, zero) STUB(86, zero) STUB(87, zero)
c00222eb:	55                   	push   %ebp
c00222ec:	6a 00                	push   $0x0
c00222ee:	68 84 00 00 00       	push   $0x84
c00222f3:	e9 8b fa ff ff       	jmp    c0021d83 <intr_entry>

c00222f8 <intr85_stub>:
c00222f8:	55                   	push   %ebp
c00222f9:	6a 00                	push   $0x0
c00222fb:	68 85 00 00 00       	push   $0x85
c0022300:	e9 7e fa ff ff       	jmp    c0021d83 <intr_entry>

c0022305 <intr86_stub>:
c0022305:	55                   	push   %ebp
c0022306:	6a 00                	push   $0x0
c0022308:	68 86 00 00 00       	push   $0x86
c002230d:	e9 71 fa ff ff       	jmp    c0021d83 <intr_entry>

c0022312 <intr87_stub>:
c0022312:	55                   	push   %ebp
c0022313:	6a 00                	push   $0x0
c0022315:	68 87 00 00 00       	push   $0x87
c002231a:	e9 64 fa ff ff       	jmp    c0021d83 <intr_entry>

c002231f <intr88_stub>:
STUB(88, zero) STUB(89, zero) STUB(8a, zero) STUB(8b, zero)
c002231f:	55                   	push   %ebp
c0022320:	6a 00                	push   $0x0
c0022322:	68 88 00 00 00       	push   $0x88
c0022327:	e9 57 fa ff ff       	jmp    c0021d83 <intr_entry>

c002232c <intr89_stub>:
c002232c:	55                   	push   %ebp
c002232d:	6a 00                	push   $0x0
c002232f:	68 89 00 00 00       	push   $0x89
c0022334:	e9 4a fa ff ff       	jmp    c0021d83 <intr_entry>

c0022339 <intr8a_stub>:
c0022339:	55                   	push   %ebp
c002233a:	6a 00                	push   $0x0
c002233c:	68 8a 00 00 00       	push   $0x8a
c0022341:	e9 3d fa ff ff       	jmp    c0021d83 <intr_entry>

c0022346 <intr8b_stub>:
c0022346:	55                   	push   %ebp
c0022347:	6a 00                	push   $0x0
c0022349:	68 8b 00 00 00       	push   $0x8b
c002234e:	e9 30 fa ff ff       	jmp    c0021d83 <intr_entry>

c0022353 <intr8c_stub>:
STUB(8c, zero) STUB(8d, zero) STUB(8e, zero) STUB(8f, zero)
c0022353:	55                   	push   %ebp
c0022354:	6a 00                	push   $0x0
c0022356:	68 8c 00 00 00       	push   $0x8c
c002235b:	e9 23 fa ff ff       	jmp    c0021d83 <intr_entry>

c0022360 <intr8d_stub>:
c0022360:	55                   	push   %ebp
c0022361:	6a 00                	push   $0x0
c0022363:	68 8d 00 00 00       	push   $0x8d
c0022368:	e9 16 fa ff ff       	jmp    c0021d83 <intr_entry>

c002236d <intr8e_stub>:
c002236d:	55                   	push   %ebp
c002236e:	6a 00                	push   $0x0
c0022370:	68 8e 00 00 00       	push   $0x8e
c0022375:	e9 09 fa ff ff       	jmp    c0021d83 <intr_entry>

c002237a <intr8f_stub>:
c002237a:	55                   	push   %ebp
c002237b:	6a 00                	push   $0x0
c002237d:	68 8f 00 00 00       	push   $0x8f
c0022382:	e9 fc f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022387 <intr90_stub>:

STUB(90, zero) STUB(91, zero) STUB(92, zero) STUB(93, zero)
c0022387:	55                   	push   %ebp
c0022388:	6a 00                	push   $0x0
c002238a:	68 90 00 00 00       	push   $0x90
c002238f:	e9 ef f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022394 <intr91_stub>:
c0022394:	55                   	push   %ebp
c0022395:	6a 00                	push   $0x0
c0022397:	68 91 00 00 00       	push   $0x91
c002239c:	e9 e2 f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223a1 <intr92_stub>:
c00223a1:	55                   	push   %ebp
c00223a2:	6a 00                	push   $0x0
c00223a4:	68 92 00 00 00       	push   $0x92
c00223a9:	e9 d5 f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223ae <intr93_stub>:
c00223ae:	55                   	push   %ebp
c00223af:	6a 00                	push   $0x0
c00223b1:	68 93 00 00 00       	push   $0x93
c00223b6:	e9 c8 f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223bb <intr94_stub>:
STUB(94, zero) STUB(95, zero) STUB(96, zero) STUB(97, zero)
c00223bb:	55                   	push   %ebp
c00223bc:	6a 00                	push   $0x0
c00223be:	68 94 00 00 00       	push   $0x94
c00223c3:	e9 bb f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223c8 <intr95_stub>:
c00223c8:	55                   	push   %ebp
c00223c9:	6a 00                	push   $0x0
c00223cb:	68 95 00 00 00       	push   $0x95
c00223d0:	e9 ae f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223d5 <intr96_stub>:
c00223d5:	55                   	push   %ebp
c00223d6:	6a 00                	push   $0x0
c00223d8:	68 96 00 00 00       	push   $0x96
c00223dd:	e9 a1 f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223e2 <intr97_stub>:
c00223e2:	55                   	push   %ebp
c00223e3:	6a 00                	push   $0x0
c00223e5:	68 97 00 00 00       	push   $0x97
c00223ea:	e9 94 f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223ef <intr98_stub>:
STUB(98, zero) STUB(99, zero) STUB(9a, zero) STUB(9b, zero)
c00223ef:	55                   	push   %ebp
c00223f0:	6a 00                	push   $0x0
c00223f2:	68 98 00 00 00       	push   $0x98
c00223f7:	e9 87 f9 ff ff       	jmp    c0021d83 <intr_entry>

c00223fc <intr99_stub>:
c00223fc:	55                   	push   %ebp
c00223fd:	6a 00                	push   $0x0
c00223ff:	68 99 00 00 00       	push   $0x99
c0022404:	e9 7a f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022409 <intr9a_stub>:
c0022409:	55                   	push   %ebp
c002240a:	6a 00                	push   $0x0
c002240c:	68 9a 00 00 00       	push   $0x9a
c0022411:	e9 6d f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022416 <intr9b_stub>:
c0022416:	55                   	push   %ebp
c0022417:	6a 00                	push   $0x0
c0022419:	68 9b 00 00 00       	push   $0x9b
c002241e:	e9 60 f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022423 <intr9c_stub>:
STUB(9c, zero) STUB(9d, zero) STUB(9e, zero) STUB(9f, zero)
c0022423:	55                   	push   %ebp
c0022424:	6a 00                	push   $0x0
c0022426:	68 9c 00 00 00       	push   $0x9c
c002242b:	e9 53 f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022430 <intr9d_stub>:
c0022430:	55                   	push   %ebp
c0022431:	6a 00                	push   $0x0
c0022433:	68 9d 00 00 00       	push   $0x9d
c0022438:	e9 46 f9 ff ff       	jmp    c0021d83 <intr_entry>

c002243d <intr9e_stub>:
c002243d:	55                   	push   %ebp
c002243e:	6a 00                	push   $0x0
c0022440:	68 9e 00 00 00       	push   $0x9e
c0022445:	e9 39 f9 ff ff       	jmp    c0021d83 <intr_entry>

c002244a <intr9f_stub>:
c002244a:	55                   	push   %ebp
c002244b:	6a 00                	push   $0x0
c002244d:	68 9f 00 00 00       	push   $0x9f
c0022452:	e9 2c f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022457 <intra0_stub>:

STUB(a0, zero) STUB(a1, zero) STUB(a2, zero) STUB(a3, zero)
c0022457:	55                   	push   %ebp
c0022458:	6a 00                	push   $0x0
c002245a:	68 a0 00 00 00       	push   $0xa0
c002245f:	e9 1f f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022464 <intra1_stub>:
c0022464:	55                   	push   %ebp
c0022465:	6a 00                	push   $0x0
c0022467:	68 a1 00 00 00       	push   $0xa1
c002246c:	e9 12 f9 ff ff       	jmp    c0021d83 <intr_entry>

c0022471 <intra2_stub>:
c0022471:	55                   	push   %ebp
c0022472:	6a 00                	push   $0x0
c0022474:	68 a2 00 00 00       	push   $0xa2
c0022479:	e9 05 f9 ff ff       	jmp    c0021d83 <intr_entry>

c002247e <intra3_stub>:
c002247e:	55                   	push   %ebp
c002247f:	6a 00                	push   $0x0
c0022481:	68 a3 00 00 00       	push   $0xa3
c0022486:	e9 f8 f8 ff ff       	jmp    c0021d83 <intr_entry>

c002248b <intra4_stub>:
STUB(a4, zero) STUB(a5, zero) STUB(a6, zero) STUB(a7, zero)
c002248b:	55                   	push   %ebp
c002248c:	6a 00                	push   $0x0
c002248e:	68 a4 00 00 00       	push   $0xa4
c0022493:	e9 eb f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022498 <intra5_stub>:
c0022498:	55                   	push   %ebp
c0022499:	6a 00                	push   $0x0
c002249b:	68 a5 00 00 00       	push   $0xa5
c00224a0:	e9 de f8 ff ff       	jmp    c0021d83 <intr_entry>

c00224a5 <intra6_stub>:
c00224a5:	55                   	push   %ebp
c00224a6:	6a 00                	push   $0x0
c00224a8:	68 a6 00 00 00       	push   $0xa6
c00224ad:	e9 d1 f8 ff ff       	jmp    c0021d83 <intr_entry>

c00224b2 <intra7_stub>:
c00224b2:	55                   	push   %ebp
c00224b3:	6a 00                	push   $0x0
c00224b5:	68 a7 00 00 00       	push   $0xa7
c00224ba:	e9 c4 f8 ff ff       	jmp    c0021d83 <intr_entry>

c00224bf <intra8_stub>:
STUB(a8, zero) STUB(a9, zero) STUB(aa, zero) STUB(ab, zero)
c00224bf:	55                   	push   %ebp
c00224c0:	6a 00                	push   $0x0
c00224c2:	68 a8 00 00 00       	push   $0xa8
c00224c7:	e9 b7 f8 ff ff       	jmp    c0021d83 <intr_entry>

c00224cc <intra9_stub>:
c00224cc:	55                   	push   %ebp
c00224cd:	6a 00                	push   $0x0
c00224cf:	68 a9 00 00 00       	push   $0xa9
c00224d4:	e9 aa f8 ff ff       	jmp    c0021d83 <intr_entry>

c00224d9 <intraa_stub>:
c00224d9:	55                   	push   %ebp
c00224da:	6a 00                	push   $0x0
c00224dc:	68 aa 00 00 00       	push   $0xaa
c00224e1:	e9 9d f8 ff ff       	jmp    c0021d83 <intr_entry>

c00224e6 <intrab_stub>:
c00224e6:	55                   	push   %ebp
c00224e7:	6a 00                	push   $0x0
c00224e9:	68 ab 00 00 00       	push   $0xab
c00224ee:	e9 90 f8 ff ff       	jmp    c0021d83 <intr_entry>

c00224f3 <intrac_stub>:
STUB(ac, zero) STUB(ad, zero) STUB(ae, zero) STUB(af, zero)
c00224f3:	55                   	push   %ebp
c00224f4:	6a 00                	push   $0x0
c00224f6:	68 ac 00 00 00       	push   $0xac
c00224fb:	e9 83 f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022500 <intrad_stub>:
c0022500:	55                   	push   %ebp
c0022501:	6a 00                	push   $0x0
c0022503:	68 ad 00 00 00       	push   $0xad
c0022508:	e9 76 f8 ff ff       	jmp    c0021d83 <intr_entry>

c002250d <intrae_stub>:
c002250d:	55                   	push   %ebp
c002250e:	6a 00                	push   $0x0
c0022510:	68 ae 00 00 00       	push   $0xae
c0022515:	e9 69 f8 ff ff       	jmp    c0021d83 <intr_entry>

c002251a <intraf_stub>:
c002251a:	55                   	push   %ebp
c002251b:	6a 00                	push   $0x0
c002251d:	68 af 00 00 00       	push   $0xaf
c0022522:	e9 5c f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022527 <intrb0_stub>:

STUB(b0, zero) STUB(b1, zero) STUB(b2, zero) STUB(b3, zero)
c0022527:	55                   	push   %ebp
c0022528:	6a 00                	push   $0x0
c002252a:	68 b0 00 00 00       	push   $0xb0
c002252f:	e9 4f f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022534 <intrb1_stub>:
c0022534:	55                   	push   %ebp
c0022535:	6a 00                	push   $0x0
c0022537:	68 b1 00 00 00       	push   $0xb1
c002253c:	e9 42 f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022541 <intrb2_stub>:
c0022541:	55                   	push   %ebp
c0022542:	6a 00                	push   $0x0
c0022544:	68 b2 00 00 00       	push   $0xb2
c0022549:	e9 35 f8 ff ff       	jmp    c0021d83 <intr_entry>

c002254e <intrb3_stub>:
c002254e:	55                   	push   %ebp
c002254f:	6a 00                	push   $0x0
c0022551:	68 b3 00 00 00       	push   $0xb3
c0022556:	e9 28 f8 ff ff       	jmp    c0021d83 <intr_entry>

c002255b <intrb4_stub>:
STUB(b4, zero) STUB(b5, zero) STUB(b6, zero) STUB(b7, zero)
c002255b:	55                   	push   %ebp
c002255c:	6a 00                	push   $0x0
c002255e:	68 b4 00 00 00       	push   $0xb4
c0022563:	e9 1b f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022568 <intrb5_stub>:
c0022568:	55                   	push   %ebp
c0022569:	6a 00                	push   $0x0
c002256b:	68 b5 00 00 00       	push   $0xb5
c0022570:	e9 0e f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022575 <intrb6_stub>:
c0022575:	55                   	push   %ebp
c0022576:	6a 00                	push   $0x0
c0022578:	68 b6 00 00 00       	push   $0xb6
c002257d:	e9 01 f8 ff ff       	jmp    c0021d83 <intr_entry>

c0022582 <intrb7_stub>:
c0022582:	55                   	push   %ebp
c0022583:	6a 00                	push   $0x0
c0022585:	68 b7 00 00 00       	push   $0xb7
c002258a:	e9 f4 f7 ff ff       	jmp    c0021d83 <intr_entry>

c002258f <intrb8_stub>:
STUB(b8, zero) STUB(b9, zero) STUB(ba, zero) STUB(bb, zero)
c002258f:	55                   	push   %ebp
c0022590:	6a 00                	push   $0x0
c0022592:	68 b8 00 00 00       	push   $0xb8
c0022597:	e9 e7 f7 ff ff       	jmp    c0021d83 <intr_entry>

c002259c <intrb9_stub>:
c002259c:	55                   	push   %ebp
c002259d:	6a 00                	push   $0x0
c002259f:	68 b9 00 00 00       	push   $0xb9
c00225a4:	e9 da f7 ff ff       	jmp    c0021d83 <intr_entry>

c00225a9 <intrba_stub>:
c00225a9:	55                   	push   %ebp
c00225aa:	6a 00                	push   $0x0
c00225ac:	68 ba 00 00 00       	push   $0xba
c00225b1:	e9 cd f7 ff ff       	jmp    c0021d83 <intr_entry>

c00225b6 <intrbb_stub>:
c00225b6:	55                   	push   %ebp
c00225b7:	6a 00                	push   $0x0
c00225b9:	68 bb 00 00 00       	push   $0xbb
c00225be:	e9 c0 f7 ff ff       	jmp    c0021d83 <intr_entry>

c00225c3 <intrbc_stub>:
STUB(bc, zero) STUB(bd, zero) STUB(be, zero) STUB(bf, zero)
c00225c3:	55                   	push   %ebp
c00225c4:	6a 00                	push   $0x0
c00225c6:	68 bc 00 00 00       	push   $0xbc
c00225cb:	e9 b3 f7 ff ff       	jmp    c0021d83 <intr_entry>

c00225d0 <intrbd_stub>:
c00225d0:	55                   	push   %ebp
c00225d1:	6a 00                	push   $0x0
c00225d3:	68 bd 00 00 00       	push   $0xbd
c00225d8:	e9 a6 f7 ff ff       	jmp    c0021d83 <intr_entry>

c00225dd <intrbe_stub>:
c00225dd:	55                   	push   %ebp
c00225de:	6a 00                	push   $0x0
c00225e0:	68 be 00 00 00       	push   $0xbe
c00225e5:	e9 99 f7 ff ff       	jmp    c0021d83 <intr_entry>

c00225ea <intrbf_stub>:
c00225ea:	55                   	push   %ebp
c00225eb:	6a 00                	push   $0x0
c00225ed:	68 bf 00 00 00       	push   $0xbf
c00225f2:	e9 8c f7 ff ff       	jmp    c0021d83 <intr_entry>

c00225f7 <intrc0_stub>:

STUB(c0, zero) STUB(c1, zero) STUB(c2, zero) STUB(c3, zero)
c00225f7:	55                   	push   %ebp
c00225f8:	6a 00                	push   $0x0
c00225fa:	68 c0 00 00 00       	push   $0xc0
c00225ff:	e9 7f f7 ff ff       	jmp    c0021d83 <intr_entry>

c0022604 <intrc1_stub>:
c0022604:	55                   	push   %ebp
c0022605:	6a 00                	push   $0x0
c0022607:	68 c1 00 00 00       	push   $0xc1
c002260c:	e9 72 f7 ff ff       	jmp    c0021d83 <intr_entry>

c0022611 <intrc2_stub>:
c0022611:	55                   	push   %ebp
c0022612:	6a 00                	push   $0x0
c0022614:	68 c2 00 00 00       	push   $0xc2
c0022619:	e9 65 f7 ff ff       	jmp    c0021d83 <intr_entry>

c002261e <intrc3_stub>:
c002261e:	55                   	push   %ebp
c002261f:	6a 00                	push   $0x0
c0022621:	68 c3 00 00 00       	push   $0xc3
c0022626:	e9 58 f7 ff ff       	jmp    c0021d83 <intr_entry>

c002262b <intrc4_stub>:
STUB(c4, zero) STUB(c5, zero) STUB(c6, zero) STUB(c7, zero)
c002262b:	55                   	push   %ebp
c002262c:	6a 00                	push   $0x0
c002262e:	68 c4 00 00 00       	push   $0xc4
c0022633:	e9 4b f7 ff ff       	jmp    c0021d83 <intr_entry>

c0022638 <intrc5_stub>:
c0022638:	55                   	push   %ebp
c0022639:	6a 00                	push   $0x0
c002263b:	68 c5 00 00 00       	push   $0xc5
c0022640:	e9 3e f7 ff ff       	jmp    c0021d83 <intr_entry>

c0022645 <intrc6_stub>:
c0022645:	55                   	push   %ebp
c0022646:	6a 00                	push   $0x0
c0022648:	68 c6 00 00 00       	push   $0xc6
c002264d:	e9 31 f7 ff ff       	jmp    c0021d83 <intr_entry>

c0022652 <intrc7_stub>:
c0022652:	55                   	push   %ebp
c0022653:	6a 00                	push   $0x0
c0022655:	68 c7 00 00 00       	push   $0xc7
c002265a:	e9 24 f7 ff ff       	jmp    c0021d83 <intr_entry>

c002265f <intrc8_stub>:
STUB(c8, zero) STUB(c9, zero) STUB(ca, zero) STUB(cb, zero)
c002265f:	55                   	push   %ebp
c0022660:	6a 00                	push   $0x0
c0022662:	68 c8 00 00 00       	push   $0xc8
c0022667:	e9 17 f7 ff ff       	jmp    c0021d83 <intr_entry>

c002266c <intrc9_stub>:
c002266c:	55                   	push   %ebp
c002266d:	6a 00                	push   $0x0
c002266f:	68 c9 00 00 00       	push   $0xc9
c0022674:	e9 0a f7 ff ff       	jmp    c0021d83 <intr_entry>

c0022679 <intrca_stub>:
c0022679:	55                   	push   %ebp
c002267a:	6a 00                	push   $0x0
c002267c:	68 ca 00 00 00       	push   $0xca
c0022681:	e9 fd f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022686 <intrcb_stub>:
c0022686:	55                   	push   %ebp
c0022687:	6a 00                	push   $0x0
c0022689:	68 cb 00 00 00       	push   $0xcb
c002268e:	e9 f0 f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022693 <intrcc_stub>:
STUB(cc, zero) STUB(cd, zero) STUB(ce, zero) STUB(cf, zero)
c0022693:	55                   	push   %ebp
c0022694:	6a 00                	push   $0x0
c0022696:	68 cc 00 00 00       	push   $0xcc
c002269b:	e9 e3 f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226a0 <intrcd_stub>:
c00226a0:	55                   	push   %ebp
c00226a1:	6a 00                	push   $0x0
c00226a3:	68 cd 00 00 00       	push   $0xcd
c00226a8:	e9 d6 f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226ad <intrce_stub>:
c00226ad:	55                   	push   %ebp
c00226ae:	6a 00                	push   $0x0
c00226b0:	68 ce 00 00 00       	push   $0xce
c00226b5:	e9 c9 f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226ba <intrcf_stub>:
c00226ba:	55                   	push   %ebp
c00226bb:	6a 00                	push   $0x0
c00226bd:	68 cf 00 00 00       	push   $0xcf
c00226c2:	e9 bc f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226c7 <intrd0_stub>:

STUB(d0, zero) STUB(d1, zero) STUB(d2, zero) STUB(d3, zero)
c00226c7:	55                   	push   %ebp
c00226c8:	6a 00                	push   $0x0
c00226ca:	68 d0 00 00 00       	push   $0xd0
c00226cf:	e9 af f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226d4 <intrd1_stub>:
c00226d4:	55                   	push   %ebp
c00226d5:	6a 00                	push   $0x0
c00226d7:	68 d1 00 00 00       	push   $0xd1
c00226dc:	e9 a2 f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226e1 <intrd2_stub>:
c00226e1:	55                   	push   %ebp
c00226e2:	6a 00                	push   $0x0
c00226e4:	68 d2 00 00 00       	push   $0xd2
c00226e9:	e9 95 f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226ee <intrd3_stub>:
c00226ee:	55                   	push   %ebp
c00226ef:	6a 00                	push   $0x0
c00226f1:	68 d3 00 00 00       	push   $0xd3
c00226f6:	e9 88 f6 ff ff       	jmp    c0021d83 <intr_entry>

c00226fb <intrd4_stub>:
STUB(d4, zero) STUB(d5, zero) STUB(d6, zero) STUB(d7, zero)
c00226fb:	55                   	push   %ebp
c00226fc:	6a 00                	push   $0x0
c00226fe:	68 d4 00 00 00       	push   $0xd4
c0022703:	e9 7b f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022708 <intrd5_stub>:
c0022708:	55                   	push   %ebp
c0022709:	6a 00                	push   $0x0
c002270b:	68 d5 00 00 00       	push   $0xd5
c0022710:	e9 6e f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022715 <intrd6_stub>:
c0022715:	55                   	push   %ebp
c0022716:	6a 00                	push   $0x0
c0022718:	68 d6 00 00 00       	push   $0xd6
c002271d:	e9 61 f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022722 <intrd7_stub>:
c0022722:	55                   	push   %ebp
c0022723:	6a 00                	push   $0x0
c0022725:	68 d7 00 00 00       	push   $0xd7
c002272a:	e9 54 f6 ff ff       	jmp    c0021d83 <intr_entry>

c002272f <intrd8_stub>:
STUB(d8, zero) STUB(d9, zero) STUB(da, zero) STUB(db, zero)
c002272f:	55                   	push   %ebp
c0022730:	6a 00                	push   $0x0
c0022732:	68 d8 00 00 00       	push   $0xd8
c0022737:	e9 47 f6 ff ff       	jmp    c0021d83 <intr_entry>

c002273c <intrd9_stub>:
c002273c:	55                   	push   %ebp
c002273d:	6a 00                	push   $0x0
c002273f:	68 d9 00 00 00       	push   $0xd9
c0022744:	e9 3a f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022749 <intrda_stub>:
c0022749:	55                   	push   %ebp
c002274a:	6a 00                	push   $0x0
c002274c:	68 da 00 00 00       	push   $0xda
c0022751:	e9 2d f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022756 <intrdb_stub>:
c0022756:	55                   	push   %ebp
c0022757:	6a 00                	push   $0x0
c0022759:	68 db 00 00 00       	push   $0xdb
c002275e:	e9 20 f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022763 <intrdc_stub>:
STUB(dc, zero) STUB(dd, zero) STUB(de, zero) STUB(df, zero)
c0022763:	55                   	push   %ebp
c0022764:	6a 00                	push   $0x0
c0022766:	68 dc 00 00 00       	push   $0xdc
c002276b:	e9 13 f6 ff ff       	jmp    c0021d83 <intr_entry>

c0022770 <intrdd_stub>:
c0022770:	55                   	push   %ebp
c0022771:	6a 00                	push   $0x0
c0022773:	68 dd 00 00 00       	push   $0xdd
c0022778:	e9 06 f6 ff ff       	jmp    c0021d83 <intr_entry>

c002277d <intrde_stub>:
c002277d:	55                   	push   %ebp
c002277e:	6a 00                	push   $0x0
c0022780:	68 de 00 00 00       	push   $0xde
c0022785:	e9 f9 f5 ff ff       	jmp    c0021d83 <intr_entry>

c002278a <intrdf_stub>:
c002278a:	55                   	push   %ebp
c002278b:	6a 00                	push   $0x0
c002278d:	68 df 00 00 00       	push   $0xdf
c0022792:	e9 ec f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022797 <intre0_stub>:

STUB(e0, zero) STUB(e1, zero) STUB(e2, zero) STUB(e3, zero)
c0022797:	55                   	push   %ebp
c0022798:	6a 00                	push   $0x0
c002279a:	68 e0 00 00 00       	push   $0xe0
c002279f:	e9 df f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227a4 <intre1_stub>:
c00227a4:	55                   	push   %ebp
c00227a5:	6a 00                	push   $0x0
c00227a7:	68 e1 00 00 00       	push   $0xe1
c00227ac:	e9 d2 f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227b1 <intre2_stub>:
c00227b1:	55                   	push   %ebp
c00227b2:	6a 00                	push   $0x0
c00227b4:	68 e2 00 00 00       	push   $0xe2
c00227b9:	e9 c5 f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227be <intre3_stub>:
c00227be:	55                   	push   %ebp
c00227bf:	6a 00                	push   $0x0
c00227c1:	68 e3 00 00 00       	push   $0xe3
c00227c6:	e9 b8 f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227cb <intre4_stub>:
STUB(e4, zero) STUB(e5, zero) STUB(e6, zero) STUB(e7, zero)
c00227cb:	55                   	push   %ebp
c00227cc:	6a 00                	push   $0x0
c00227ce:	68 e4 00 00 00       	push   $0xe4
c00227d3:	e9 ab f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227d8 <intre5_stub>:
c00227d8:	55                   	push   %ebp
c00227d9:	6a 00                	push   $0x0
c00227db:	68 e5 00 00 00       	push   $0xe5
c00227e0:	e9 9e f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227e5 <intre6_stub>:
c00227e5:	55                   	push   %ebp
c00227e6:	6a 00                	push   $0x0
c00227e8:	68 e6 00 00 00       	push   $0xe6
c00227ed:	e9 91 f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227f2 <intre7_stub>:
c00227f2:	55                   	push   %ebp
c00227f3:	6a 00                	push   $0x0
c00227f5:	68 e7 00 00 00       	push   $0xe7
c00227fa:	e9 84 f5 ff ff       	jmp    c0021d83 <intr_entry>

c00227ff <intre8_stub>:
STUB(e8, zero) STUB(e9, zero) STUB(ea, zero) STUB(eb, zero)
c00227ff:	55                   	push   %ebp
c0022800:	6a 00                	push   $0x0
c0022802:	68 e8 00 00 00       	push   $0xe8
c0022807:	e9 77 f5 ff ff       	jmp    c0021d83 <intr_entry>

c002280c <intre9_stub>:
c002280c:	55                   	push   %ebp
c002280d:	6a 00                	push   $0x0
c002280f:	68 e9 00 00 00       	push   $0xe9
c0022814:	e9 6a f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022819 <intrea_stub>:
c0022819:	55                   	push   %ebp
c002281a:	6a 00                	push   $0x0
c002281c:	68 ea 00 00 00       	push   $0xea
c0022821:	e9 5d f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022826 <intreb_stub>:
c0022826:	55                   	push   %ebp
c0022827:	6a 00                	push   $0x0
c0022829:	68 eb 00 00 00       	push   $0xeb
c002282e:	e9 50 f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022833 <intrec_stub>:
STUB(ec, zero) STUB(ed, zero) STUB(ee, zero) STUB(ef, zero)
c0022833:	55                   	push   %ebp
c0022834:	6a 00                	push   $0x0
c0022836:	68 ec 00 00 00       	push   $0xec
c002283b:	e9 43 f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022840 <intred_stub>:
c0022840:	55                   	push   %ebp
c0022841:	6a 00                	push   $0x0
c0022843:	68 ed 00 00 00       	push   $0xed
c0022848:	e9 36 f5 ff ff       	jmp    c0021d83 <intr_entry>

c002284d <intree_stub>:
c002284d:	55                   	push   %ebp
c002284e:	6a 00                	push   $0x0
c0022850:	68 ee 00 00 00       	push   $0xee
c0022855:	e9 29 f5 ff ff       	jmp    c0021d83 <intr_entry>

c002285a <intref_stub>:
c002285a:	55                   	push   %ebp
c002285b:	6a 00                	push   $0x0
c002285d:	68 ef 00 00 00       	push   $0xef
c0022862:	e9 1c f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022867 <intrf0_stub>:

STUB(f0, zero) STUB(f1, zero) STUB(f2, zero) STUB(f3, zero)
c0022867:	55                   	push   %ebp
c0022868:	6a 00                	push   $0x0
c002286a:	68 f0 00 00 00       	push   $0xf0
c002286f:	e9 0f f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022874 <intrf1_stub>:
c0022874:	55                   	push   %ebp
c0022875:	6a 00                	push   $0x0
c0022877:	68 f1 00 00 00       	push   $0xf1
c002287c:	e9 02 f5 ff ff       	jmp    c0021d83 <intr_entry>

c0022881 <intrf2_stub>:
c0022881:	55                   	push   %ebp
c0022882:	6a 00                	push   $0x0
c0022884:	68 f2 00 00 00       	push   $0xf2
c0022889:	e9 f5 f4 ff ff       	jmp    c0021d83 <intr_entry>

c002288e <intrf3_stub>:
c002288e:	55                   	push   %ebp
c002288f:	6a 00                	push   $0x0
c0022891:	68 f3 00 00 00       	push   $0xf3
c0022896:	e9 e8 f4 ff ff       	jmp    c0021d83 <intr_entry>

c002289b <intrf4_stub>:
STUB(f4, zero) STUB(f5, zero) STUB(f6, zero) STUB(f7, zero)
c002289b:	55                   	push   %ebp
c002289c:	6a 00                	push   $0x0
c002289e:	68 f4 00 00 00       	push   $0xf4
c00228a3:	e9 db f4 ff ff       	jmp    c0021d83 <intr_entry>

c00228a8 <intrf5_stub>:
c00228a8:	55                   	push   %ebp
c00228a9:	6a 00                	push   $0x0
c00228ab:	68 f5 00 00 00       	push   $0xf5
c00228b0:	e9 ce f4 ff ff       	jmp    c0021d83 <intr_entry>

c00228b5 <intrf6_stub>:
c00228b5:	55                   	push   %ebp
c00228b6:	6a 00                	push   $0x0
c00228b8:	68 f6 00 00 00       	push   $0xf6
c00228bd:	e9 c1 f4 ff ff       	jmp    c0021d83 <intr_entry>

c00228c2 <intrf7_stub>:
c00228c2:	55                   	push   %ebp
c00228c3:	6a 00                	push   $0x0
c00228c5:	68 f7 00 00 00       	push   $0xf7
c00228ca:	e9 b4 f4 ff ff       	jmp    c0021d83 <intr_entry>

c00228cf <intrf8_stub>:
STUB(f8, zero) STUB(f9, zero) STUB(fa, zero) STUB(fb, zero)
c00228cf:	55                   	push   %ebp
c00228d0:	6a 00                	push   $0x0
c00228d2:	68 f8 00 00 00       	push   $0xf8
c00228d7:	e9 a7 f4 ff ff       	jmp    c0021d83 <intr_entry>

c00228dc <intrf9_stub>:
c00228dc:	55                   	push   %ebp
c00228dd:	6a 00                	push   $0x0
c00228df:	68 f9 00 00 00       	push   $0xf9
c00228e4:	e9 9a f4 ff ff       	jmp    c0021d83 <intr_entry>

c00228e9 <intrfa_stub>:
c00228e9:	55                   	push   %ebp
c00228ea:	6a 00                	push   $0x0
c00228ec:	68 fa 00 00 00       	push   $0xfa
c00228f1:	e9 8d f4 ff ff       	jmp    c0021d83 <intr_entry>

c00228f6 <intrfb_stub>:
c00228f6:	55                   	push   %ebp
c00228f7:	6a 00                	push   $0x0
c00228f9:	68 fb 00 00 00       	push   $0xfb
c00228fe:	e9 80 f4 ff ff       	jmp    c0021d83 <intr_entry>

c0022903 <intrfc_stub>:
STUB(fc, zero) STUB(fd, zero) STUB(fe, zero) STUB(ff, zero)
c0022903:	55                   	push   %ebp
c0022904:	6a 00                	push   $0x0
c0022906:	68 fc 00 00 00       	push   $0xfc
c002290b:	e9 73 f4 ff ff       	jmp    c0021d83 <intr_entry>

c0022910 <intrfd_stub>:
c0022910:	55                   	push   %ebp
c0022911:	6a 00                	push   $0x0
c0022913:	68 fd 00 00 00       	push   $0xfd
c0022918:	e9 66 f4 ff ff       	jmp    c0021d83 <intr_entry>

c002291d <intrfe_stub>:
c002291d:	55                   	push   %ebp
c002291e:	6a 00                	push   $0x0
c0022920:	68 fe 00 00 00       	push   $0xfe
c0022925:	e9 59 f4 ff ff       	jmp    c0021d83 <intr_entry>

c002292a <intrff_stub>:
c002292a:	55                   	push   %ebp
c002292b:	6a 00                	push   $0x0
c002292d:	68 ff 00 00 00       	push   $0xff
c0022932:	e9 4c f4 ff ff       	jmp    c0021d83 <intr_entry>
c0022937:	90                   	nop
c0022938:	90                   	nop
c0022939:	90                   	nop
c002293a:	90                   	nop
c002293b:	90                   	nop
c002293c:	90                   	nop
c002293d:	90                   	nop
c002293e:	90                   	nop
c002293f:	90                   	nop

c0022940 <threadPrioCompare>:
static bool threadPrioCompare(const struct list_elem *t1,
                             const struct list_elem *t2, void *aux UNUSED)
{ 
  const struct thread *tPointer1 = list_entry (t1, struct thread, elem);
  const struct thread *tPointer2 = list_entry (t2, struct thread, elem);
  if(tPointer1->priority < tPointer2->priority){
c0022940:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022944:	8b 54 24 04          	mov    0x4(%esp),%edx
c0022948:	8b 40 f4             	mov    -0xc(%eax),%eax
c002294b:	39 42 f4             	cmp    %eax,-0xc(%edx)
c002294e:	0f 9c c0             	setl   %al
    return true;
  }
  else{
    return false;
  }
}
c0022951:	c3                   	ret    

c0022952 <lockPrioCompare>:
static bool lockPrioCompare(const struct list_elem *l1,
                             const struct list_elem *l2, void *aux UNUSED)
{
  const struct lock *lPointer1 = list_entry (l1, struct lock, elem);
  const struct lock *lPointer2 = list_entry (l2, struct lock, elem);
  if(lPointer1->max_priority > lPointer2->max_priority) {
c0022952:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022956:	8b 54 24 04          	mov    0x4(%esp),%edx
c002295a:	8b 40 08             	mov    0x8(%eax),%eax
c002295d:	39 42 08             	cmp    %eax,0x8(%edx)
c0022960:	0f 9f c0             	setg   %al
    return true;
  }
  else {
    return false;
  }
}
c0022963:	c3                   	ret    

c0022964 <semaPrioCompare>:
static bool semaPrioCompare(const struct list_elem *s1,
                             const struct list_elem *s2, void *aux UNUSED)
{
  const struct semaphore_elem *sPointer1 = list_entry (s1, struct semaphore_elem, elem);
  const struct semaphore_elem *sPointer2 = list_entry (s2, struct semaphore_elem, elem);
  if(sPointer1->priority < sPointer2->priority){
c0022964:	8b 44 24 08          	mov    0x8(%esp),%eax
c0022968:	8b 54 24 04          	mov    0x4(%esp),%edx
c002296c:	8b 40 1c             	mov    0x1c(%eax),%eax
c002296f:	39 42 1c             	cmp    %eax,0x1c(%edx)
c0022972:	0f 9c c0             	setl   %al
    return true;
  }
  else{
    return false;
  }
}
c0022975:	c3                   	ret    

c0022976 <sema_init>:
{
c0022976:	83 ec 2c             	sub    $0x2c,%esp
c0022979:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (sema != NULL);
c002297d:	85 c0                	test   %eax,%eax
c002297f:	75 2c                	jne    c00229ad <sema_init+0x37>
c0022981:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c0022988:	c0 
c0022989:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022990:	c0 
c0022991:	c7 44 24 08 60 d2 02 	movl   $0xc002d260,0x8(%esp)
c0022998:	c0 
c0022999:	c7 44 24 04 2b 00 00 	movl   $0x2b,0x4(%esp)
c00229a0:	00 
c00229a1:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00229a8:	e8 c6 5f 00 00       	call   c0028973 <debug_panic>
  sema->value = value;
c00229ad:	8b 54 24 34          	mov    0x34(%esp),%edx
c00229b1:	89 10                	mov    %edx,(%eax)
  list_init (&sema->waiters);
c00229b3:	83 c0 04             	add    $0x4,%eax
c00229b6:	89 04 24             	mov    %eax,(%esp)
c00229b9:	e8 82 60 00 00       	call   c0028a40 <list_init>
}
c00229be:	83 c4 2c             	add    $0x2c,%esp
c00229c1:	c3                   	ret    

c00229c2 <sema_down>:
{
c00229c2:	57                   	push   %edi
c00229c3:	56                   	push   %esi
c00229c4:	53                   	push   %ebx
c00229c5:	83 ec 20             	sub    $0x20,%esp
c00229c8:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c00229cc:	85 db                	test   %ebx,%ebx
c00229ce:	75 2c                	jne    c00229fc <sema_down+0x3a>
c00229d0:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c00229d7:	c0 
c00229d8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00229df:	c0 
c00229e0:	c7 44 24 08 56 d2 02 	movl   $0xc002d256,0x8(%esp)
c00229e7:	c0 
c00229e8:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c00229ef:	00 
c00229f0:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00229f7:	e8 77 5f 00 00       	call   c0028973 <debug_panic>
  ASSERT (!intr_context ());
c00229fc:	e8 b0 f0 ff ff       	call   c0021ab1 <intr_context>
c0022a01:	84 c0                	test   %al,%al
c0022a03:	74 2c                	je     c0022a31 <sema_down+0x6f>
c0022a05:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0022a0c:	c0 
c0022a0d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022a14:	c0 
c0022a15:	c7 44 24 08 56 d2 02 	movl   $0xc002d256,0x8(%esp)
c0022a1c:	c0 
c0022a1d:	c7 44 24 04 4c 00 00 	movl   $0x4c,0x4(%esp)
c0022a24:	00 
c0022a25:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022a2c:	e8 42 5f 00 00       	call   c0028973 <debug_panic>
  old_level = intr_disable ();
c0022a31:	e8 19 ee ff ff       	call   c002184f <intr_disable>
c0022a36:	89 c7                	mov    %eax,%edi
  while (sema->value == 0) 
c0022a38:	8b 13                	mov    (%ebx),%edx
c0022a3a:	85 d2                	test   %edx,%edx
c0022a3c:	75 22                	jne    c0022a60 <sema_down+0x9e>
      list_push_back (&sema->waiters, &thread_current ()->elem);
c0022a3e:	8d 73 04             	lea    0x4(%ebx),%esi
c0022a41:	e8 5d e2 ff ff       	call   c0020ca3 <thread_current>
c0022a46:	83 c0 28             	add    $0x28,%eax
c0022a49:	89 44 24 04          	mov    %eax,0x4(%esp)
c0022a4d:	89 34 24             	mov    %esi,(%esp)
c0022a50:	e8 6c 65 00 00       	call   c0028fc1 <list_push_back>
      thread_block ();
c0022a55:	e8 57 e7 ff ff       	call   c00211b1 <thread_block>
  while (sema->value == 0) 
c0022a5a:	8b 13                	mov    (%ebx),%edx
c0022a5c:	85 d2                	test   %edx,%edx
c0022a5e:	74 e1                	je     c0022a41 <sema_down+0x7f>
  sema->value--;
c0022a60:	83 ea 01             	sub    $0x1,%edx
c0022a63:	89 13                	mov    %edx,(%ebx)
  intr_set_level (old_level);
c0022a65:	89 3c 24             	mov    %edi,(%esp)
c0022a68:	e8 e9 ed ff ff       	call   c0021856 <intr_set_level>
}
c0022a6d:	83 c4 20             	add    $0x20,%esp
c0022a70:	5b                   	pop    %ebx
c0022a71:	5e                   	pop    %esi
c0022a72:	5f                   	pop    %edi
c0022a73:	c3                   	ret    

c0022a74 <sema_try_down>:
{
c0022a74:	56                   	push   %esi
c0022a75:	53                   	push   %ebx
c0022a76:	83 ec 24             	sub    $0x24,%esp
c0022a79:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (sema != NULL);
c0022a7d:	85 db                	test   %ebx,%ebx
c0022a7f:	75 2c                	jne    c0022aad <sema_try_down+0x39>
c0022a81:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c0022a88:	c0 
c0022a89:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022a90:	c0 
c0022a91:	c7 44 24 08 48 d2 02 	movl   $0xc002d248,0x8(%esp)
c0022a98:	c0 
c0022a99:	c7 44 24 04 62 00 00 	movl   $0x62,0x4(%esp)
c0022aa0:	00 
c0022aa1:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022aa8:	e8 c6 5e 00 00       	call   c0028973 <debug_panic>
  old_level = intr_disable ();
c0022aad:	e8 9d ed ff ff       	call   c002184f <intr_disable>
  if (sema->value > 0) 
c0022ab2:	8b 13                	mov    (%ebx),%edx
    success = false;
c0022ab4:	be 00 00 00 00       	mov    $0x0,%esi
  if (sema->value > 0) 
c0022ab9:	85 d2                	test   %edx,%edx
c0022abb:	74 0a                	je     c0022ac7 <sema_try_down+0x53>
      sema->value--;
c0022abd:	83 ea 01             	sub    $0x1,%edx
c0022ac0:	89 13                	mov    %edx,(%ebx)
      success = true; 
c0022ac2:	be 01 00 00 00       	mov    $0x1,%esi
  intr_set_level (old_level);
c0022ac7:	89 04 24             	mov    %eax,(%esp)
c0022aca:	e8 87 ed ff ff       	call   c0021856 <intr_set_level>
}
c0022acf:	89 f0                	mov    %esi,%eax
c0022ad1:	83 c4 24             	add    $0x24,%esp
c0022ad4:	5b                   	pop    %ebx
c0022ad5:	5e                   	pop    %esi
c0022ad6:	c3                   	ret    

c0022ad7 <sema_up>:
{
c0022ad7:	55                   	push   %ebp
c0022ad8:	57                   	push   %edi
c0022ad9:	56                   	push   %esi
c0022ada:	53                   	push   %ebx
c0022adb:	83 ec 2c             	sub    $0x2c,%esp
c0022ade:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  ASSERT (sema != NULL);
c0022ae2:	85 db                	test   %ebx,%ebx
c0022ae4:	75 2c                	jne    c0022b12 <sema_up+0x3b>
c0022ae6:	c7 44 24 10 16 ea 02 	movl   $0xc002ea16,0x10(%esp)
c0022aed:	c0 
c0022aee:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022af5:	c0 
c0022af6:	c7 44 24 08 40 d2 02 	movl   $0xc002d240,0x8(%esp)
c0022afd:	c0 
c0022afe:	c7 44 24 04 7d 00 00 	movl   $0x7d,0x4(%esp)
c0022b05:	00 
c0022b06:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022b0d:	e8 61 5e 00 00       	call   c0028973 <debug_panic>
  old_level = intr_disable ();
c0022b12:	e8 38 ed ff ff       	call   c002184f <intr_disable>
c0022b17:	89 c7                	mov    %eax,%edi
  if (!list_empty (&sema->waiters)) 
c0022b19:	8d 73 04             	lea    0x4(%ebx),%esi
c0022b1c:	89 34 24             	mov    %esi,(%esp)
c0022b1f:	e8 52 65 00 00       	call   c0029076 <list_empty>
c0022b24:	84 c0                	test   %al,%al
c0022b26:	75 55                	jne    c0022b7d <sema_up+0xa6>
    max_prio_sema = list_max (&sema->waiters,threadPrioCompare,0);
c0022b28:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0022b2f:	00 
c0022b30:	c7 44 24 04 40 29 02 	movl   $0xc0022940,0x4(%esp)
c0022b37:	c0 
c0022b38:	89 34 24             	mov    %esi,(%esp)
c0022b3b:	e8 0a 6b 00 00       	call   c002964a <list_max>
c0022b40:	89 c6                	mov    %eax,%esi
    list_remove(max_prio_sema);
c0022b42:	89 04 24             	mov    %eax,(%esp)
c0022b45:	e8 9a 64 00 00       	call   c0028fe4 <list_remove>
    freed_thread = list_entry(max_prio_sema,struct thread,elem);
c0022b4a:	8d 6e d8             	lea    -0x28(%esi),%ebp
    thread_unblock (freed_thread);
c0022b4d:	89 2c 24             	mov    %ebp,(%esp)
c0022b50:	e8 75 e0 ff ff       	call   c0020bca <thread_unblock>
  sema->value++;
c0022b55:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022b58:	89 3c 24             	mov    %edi,(%esp)
c0022b5b:	e8 f6 ec ff ff       	call   c0021856 <intr_set_level>
  if(old_level == INTR_ON && freed_thread!=NULL) {
c0022b60:	83 ff 01             	cmp    $0x1,%edi
c0022b63:	75 23                	jne    c0022b88 <sema_up+0xb1>
c0022b65:	85 ed                	test   %ebp,%ebp
c0022b67:	74 1f                	je     c0022b88 <sema_up+0xb1>
    if(thread_current()->priority < freed_thread->priority)
c0022b69:	e8 35 e1 ff ff       	call   c0020ca3 <thread_current>
c0022b6e:	8b 56 f4             	mov    -0xc(%esi),%edx
c0022b71:	39 50 1c             	cmp    %edx,0x1c(%eax)
c0022b74:	7d 12                	jge    c0022b88 <sema_up+0xb1>
      thread_yield ();
c0022b76:	e8 ac e7 ff ff       	call   c0021327 <thread_yield>
c0022b7b:	eb 0b                	jmp    c0022b88 <sema_up+0xb1>
  sema->value++;
c0022b7d:	83 03 01             	addl   $0x1,(%ebx)
  intr_set_level (old_level);
c0022b80:	89 3c 24             	mov    %edi,(%esp)
c0022b83:	e8 ce ec ff ff       	call   c0021856 <intr_set_level>
}
c0022b88:	83 c4 2c             	add    $0x2c,%esp
c0022b8b:	5b                   	pop    %ebx
c0022b8c:	5e                   	pop    %esi
c0022b8d:	5f                   	pop    %edi
c0022b8e:	5d                   	pop    %ebp
c0022b8f:	c3                   	ret    

c0022b90 <sema_test_helper>:
{
c0022b90:	57                   	push   %edi
c0022b91:	56                   	push   %esi
c0022b92:	53                   	push   %ebx
c0022b93:	83 ec 10             	sub    $0x10,%esp
c0022b96:	8b 74 24 20          	mov    0x20(%esp),%esi
c0022b9a:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[1]);
c0022b9f:	8d 7e 14             	lea    0x14(%esi),%edi
      sema_down (&sema[0]);
c0022ba2:	89 34 24             	mov    %esi,(%esp)
c0022ba5:	e8 18 fe ff ff       	call   c00229c2 <sema_down>
      sema_up (&sema[1]);
c0022baa:	89 3c 24             	mov    %edi,(%esp)
c0022bad:	e8 25 ff ff ff       	call   c0022ad7 <sema_up>
  for (i = 0; i < 10; i++) 
c0022bb2:	83 eb 01             	sub    $0x1,%ebx
c0022bb5:	75 eb                	jne    c0022ba2 <sema_test_helper+0x12>
}
c0022bb7:	83 c4 10             	add    $0x10,%esp
c0022bba:	5b                   	pop    %ebx
c0022bbb:	5e                   	pop    %esi
c0022bbc:	5f                   	pop    %edi
c0022bbd:	c3                   	ret    

c0022bbe <sema_self_test>:
{
c0022bbe:	57                   	push   %edi
c0022bbf:	56                   	push   %esi
c0022bc0:	53                   	push   %ebx
c0022bc1:	83 ec 40             	sub    $0x40,%esp
  printf ("Testing semaphores...");
c0022bc4:	c7 04 24 39 ea 02 c0 	movl   $0xc002ea39,(%esp)
c0022bcb:	e8 4e 3f 00 00       	call   c0026b1e <printf>
  sema_init (&sema[0], 0);
c0022bd0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022bd7:	00 
c0022bd8:	8d 5c 24 18          	lea    0x18(%esp),%ebx
c0022bdc:	89 1c 24             	mov    %ebx,(%esp)
c0022bdf:	e8 92 fd ff ff       	call   c0022976 <sema_init>
  sema_init (&sema[1], 0);
c0022be4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0022beb:	00 
c0022bec:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c0022bf0:	89 04 24             	mov    %eax,(%esp)
c0022bf3:	e8 7e fd ff ff       	call   c0022976 <sema_init>
  thread_create ("sema-test", PRI_DEFAULT, sema_test_helper, &sema);
c0022bf8:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0022bfc:	c7 44 24 08 90 2b 02 	movl   $0xc0022b90,0x8(%esp)
c0022c03:	c0 
c0022c04:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c0022c0b:	00 
c0022c0c:	c7 04 24 4f ea 02 c0 	movl   $0xc002ea4f,(%esp)
c0022c13:	e8 b1 e7 ff ff       	call   c00213c9 <thread_create>
c0022c18:	bb 0a 00 00 00       	mov    $0xa,%ebx
      sema_up (&sema[0]);
c0022c1d:	8d 7c 24 18          	lea    0x18(%esp),%edi
      sema_down (&sema[1]);
c0022c21:	8d 74 24 2c          	lea    0x2c(%esp),%esi
      sema_up (&sema[0]);
c0022c25:	89 3c 24             	mov    %edi,(%esp)
c0022c28:	e8 aa fe ff ff       	call   c0022ad7 <sema_up>
      sema_down (&sema[1]);
c0022c2d:	89 34 24             	mov    %esi,(%esp)
c0022c30:	e8 8d fd ff ff       	call   c00229c2 <sema_down>
  for (i = 0; i < 10; i++) 
c0022c35:	83 eb 01             	sub    $0x1,%ebx
c0022c38:	75 eb                	jne    c0022c25 <sema_self_test+0x67>
  printf ("done.\n");
c0022c3a:	c7 04 24 59 ea 02 c0 	movl   $0xc002ea59,(%esp)
c0022c41:	e8 55 7a 00 00       	call   c002a69b <puts>
}
c0022c46:	83 c4 40             	add    $0x40,%esp
c0022c49:	5b                   	pop    %ebx
c0022c4a:	5e                   	pop    %esi
c0022c4b:	5f                   	pop    %edi
c0022c4c:	c3                   	ret    

c0022c4d <lock_init>:
{
c0022c4d:	83 ec 2c             	sub    $0x2c,%esp
c0022c50:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022c54:	85 c0                	test   %eax,%eax
c0022c56:	75 2c                	jne    c0022c84 <lock_init+0x37>
c0022c58:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022c5f:	c0 
c0022c60:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022c67:	c0 
c0022c68:	c7 44 24 08 36 d2 02 	movl   $0xc002d236,0x8(%esp)
c0022c6f:	c0 
c0022c70:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
c0022c77:	00 
c0022c78:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022c7f:	e8 ef 5c 00 00       	call   c0028973 <debug_panic>
  lock->holder = NULL;
c0022c84:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  sema_init (&lock->semaphore, 1);
c0022c8a:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0022c91:	00 
c0022c92:	83 c0 04             	add    $0x4,%eax
c0022c95:	89 04 24             	mov    %eax,(%esp)
c0022c98:	e8 d9 fc ff ff       	call   c0022976 <sema_init>
}
c0022c9d:	83 c4 2c             	add    $0x2c,%esp
c0022ca0:	c3                   	ret    

c0022ca1 <lock_held_by_current_thread>:
{
c0022ca1:	53                   	push   %ebx
c0022ca2:	83 ec 28             	sub    $0x28,%esp
c0022ca5:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (lock != NULL);
c0022ca9:	85 c0                	test   %eax,%eax
c0022cab:	75 2c                	jne    c0022cd9 <lock_held_by_current_thread+0x38>
c0022cad:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022cb4:	c0 
c0022cb5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022cbc:	c0 
c0022cbd:	c7 44 24 08 ef d1 02 	movl   $0xc002d1ef,0x8(%esp)
c0022cc4:	c0 
c0022cc5:	c7 44 24 04 4d 01 00 	movl   $0x14d,0x4(%esp)
c0022ccc:	00 
c0022ccd:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022cd4:	e8 9a 5c 00 00       	call   c0028973 <debug_panic>
  return lock->holder == thread_current ();
c0022cd9:	8b 18                	mov    (%eax),%ebx
c0022cdb:	e8 c3 df ff ff       	call   c0020ca3 <thread_current>
c0022ce0:	39 c3                	cmp    %eax,%ebx
c0022ce2:	0f 94 c0             	sete   %al
}
c0022ce5:	83 c4 28             	add    $0x28,%esp
c0022ce8:	5b                   	pop    %ebx
c0022ce9:	c3                   	ret    

c0022cea <lock_acquire>:
{
c0022cea:	56                   	push   %esi
c0022ceb:	53                   	push   %ebx
c0022cec:	83 ec 24             	sub    $0x24,%esp
c0022cef:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022cf3:	85 db                	test   %ebx,%ebx
c0022cf5:	75 2c                	jne    c0022d23 <lock_acquire+0x39>
c0022cf7:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022cfe:	c0 
c0022cff:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022d06:	c0 
c0022d07:	c7 44 24 08 29 d2 02 	movl   $0xc002d229,0x8(%esp)
c0022d0e:	c0 
c0022d0f:	c7 44 24 04 e9 00 00 	movl   $0xe9,0x4(%esp)
c0022d16:	00 
c0022d17:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022d1e:	e8 50 5c 00 00       	call   c0028973 <debug_panic>
  ASSERT (!intr_context ());
c0022d23:	e8 89 ed ff ff       	call   c0021ab1 <intr_context>
c0022d28:	84 c0                	test   %al,%al
c0022d2a:	74 2c                	je     c0022d58 <lock_acquire+0x6e>
c0022d2c:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0022d33:	c0 
c0022d34:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022d3b:	c0 
c0022d3c:	c7 44 24 08 29 d2 02 	movl   $0xc002d229,0x8(%esp)
c0022d43:	c0 
c0022d44:	c7 44 24 04 ea 00 00 	movl   $0xea,0x4(%esp)
c0022d4b:	00 
c0022d4c:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022d53:	e8 1b 5c 00 00       	call   c0028973 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022d58:	89 1c 24             	mov    %ebx,(%esp)
c0022d5b:	e8 41 ff ff ff       	call   c0022ca1 <lock_held_by_current_thread>
c0022d60:	84 c0                	test   %al,%al
c0022d62:	74 2c                	je     c0022d90 <lock_acquire+0xa6>
c0022d64:	c7 44 24 10 7c ea 02 	movl   $0xc002ea7c,0x10(%esp)
c0022d6b:	c0 
c0022d6c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022d73:	c0 
c0022d74:	c7 44 24 08 29 d2 02 	movl   $0xc002d229,0x8(%esp)
c0022d7b:	c0 
c0022d7c:	c7 44 24 04 eb 00 00 	movl   $0xeb,0x4(%esp)
c0022d83:	00 
c0022d84:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022d8b:	e8 e3 5b 00 00       	call   c0028973 <debug_panic>
  old_level = intr_disable ();
c0022d90:	e8 ba ea ff ff       	call   c002184f <intr_disable>
c0022d95:	89 c6                	mov    %eax,%esi
  if(!thread_mlfqs && lock->holder != NULL)
c0022d97:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0022d9e:	75 20                	jne    c0022dc0 <lock_acquire+0xd6>
c0022da0:	83 3b 00             	cmpl   $0x0,(%ebx)
c0022da3:	74 1b                	je     c0022dc0 <lock_acquire+0xd6>
    int curr_prio = thread_get_priority();
c0022da5:	e8 5a e0 ff ff       	call   c0020e04 <thread_get_priority>
    struct lock * lock_copy = lock;
c0022daa:	89 da                	mov    %ebx,%edx
        l_holder = lock_copy->holder;
c0022dac:	8b 0a                	mov    (%edx),%ecx
        if( l_holder->priority < curr_prio)
c0022dae:	3b 41 1c             	cmp    0x1c(%ecx),%eax
c0022db1:	7e 06                	jle    c0022db9 <lock_acquire+0xcf>
          l_holder->priority = curr_prio;
c0022db3:	89 41 1c             	mov    %eax,0x1c(%ecx)
          lock_copy->max_priority = curr_prio;
c0022db6:	89 42 20             	mov    %eax,0x20(%edx)
        lock_copy = l_holder->wait_on_lock;
c0022db9:	8b 51 50             	mov    0x50(%ecx),%edx
    while(lock_copy != NULL){ 
c0022dbc:	85 d2                	test   %edx,%edx
c0022dbe:	75 ec                	jne    c0022dac <lock_acquire+0xc2>
  thread_current()->wait_on_lock = lock; //I'm waiting on this lock
c0022dc0:	e8 de de ff ff       	call   c0020ca3 <thread_current>
c0022dc5:	89 58 50             	mov    %ebx,0x50(%eax)
  intr_set_level (old_level);
c0022dc8:	89 34 24             	mov    %esi,(%esp)
c0022dcb:	e8 86 ea ff ff       	call   c0021856 <intr_set_level>
  sema_down (&lock->semaphore);          //lock acquired
c0022dd0:	8d 43 04             	lea    0x4(%ebx),%eax
c0022dd3:	89 04 24             	mov    %eax,(%esp)
c0022dd6:	e8 e7 fb ff ff       	call   c00229c2 <sema_down>
  lock->holder = thread_current ();      //Now I'm the owner of this lock
c0022ddb:	e8 c3 de ff ff       	call   c0020ca3 <thread_current>
c0022de0:	89 03                	mov    %eax,(%ebx)
  thread_current()->wait_on_lock = NULL; //and now no more waiting for this lock
c0022de2:	e8 bc de ff ff       	call   c0020ca3 <thread_current>
c0022de7:	c7 40 50 00 00 00 00 	movl   $0x0,0x50(%eax)
  list_insert_ordered(&(thread_current()->locks_held), &lock->elem, lockPrioCompare,NULL);
c0022dee:	e8 b0 de ff ff       	call   c0020ca3 <thread_current>
c0022df3:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0022dfa:	00 
c0022dfb:	c7 44 24 08 52 29 02 	movl   $0xc0022952,0x8(%esp)
c0022e02:	c0 
c0022e03:	8d 53 18             	lea    0x18(%ebx),%edx
c0022e06:	89 54 24 04          	mov    %edx,0x4(%esp)
c0022e0a:	83 c0 40             	add    $0x40,%eax
c0022e0d:	89 04 24             	mov    %eax,(%esp)
c0022e10:	e8 51 66 00 00       	call   c0029466 <list_insert_ordered>
  lock->max_priority = thread_get_priority();
c0022e15:	e8 ea df ff ff       	call   c0020e04 <thread_get_priority>
c0022e1a:	89 43 20             	mov    %eax,0x20(%ebx)
}
c0022e1d:	83 c4 24             	add    $0x24,%esp
c0022e20:	5b                   	pop    %ebx
c0022e21:	5e                   	pop    %esi
c0022e22:	c3                   	ret    

c0022e23 <lock_try_acquire>:
{
c0022e23:	56                   	push   %esi
c0022e24:	53                   	push   %ebx
c0022e25:	83 ec 24             	sub    $0x24,%esp
c0022e28:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022e2c:	85 db                	test   %ebx,%ebx
c0022e2e:	75 2c                	jne    c0022e5c <lock_try_acquire+0x39>
c0022e30:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022e37:	c0 
c0022e38:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022e3f:	c0 
c0022e40:	c7 44 24 08 18 d2 02 	movl   $0xc002d218,0x8(%esp)
c0022e47:	c0 
c0022e48:	c7 44 24 04 16 01 00 	movl   $0x116,0x4(%esp)
c0022e4f:	00 
c0022e50:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022e57:	e8 17 5b 00 00       	call   c0028973 <debug_panic>
  ASSERT (!lock_held_by_current_thread (lock));
c0022e5c:	89 1c 24             	mov    %ebx,(%esp)
c0022e5f:	e8 3d fe ff ff       	call   c0022ca1 <lock_held_by_current_thread>
c0022e64:	84 c0                	test   %al,%al
c0022e66:	74 2c                	je     c0022e94 <lock_try_acquire+0x71>
c0022e68:	c7 44 24 10 7c ea 02 	movl   $0xc002ea7c,0x10(%esp)
c0022e6f:	c0 
c0022e70:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022e77:	c0 
c0022e78:	c7 44 24 08 18 d2 02 	movl   $0xc002d218,0x8(%esp)
c0022e7f:	c0 
c0022e80:	c7 44 24 04 17 01 00 	movl   $0x117,0x4(%esp)
c0022e87:	00 
c0022e88:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022e8f:	e8 df 5a 00 00       	call   c0028973 <debug_panic>
  success = sema_try_down (&lock->semaphore);
c0022e94:	8d 43 04             	lea    0x4(%ebx),%eax
c0022e97:	89 04 24             	mov    %eax,(%esp)
c0022e9a:	e8 d5 fb ff ff       	call   c0022a74 <sema_try_down>
c0022e9f:	89 c6                	mov    %eax,%esi
  if (success)
c0022ea1:	84 c0                	test   %al,%al
c0022ea3:	74 07                	je     c0022eac <lock_try_acquire+0x89>
    lock->holder = thread_current ();
c0022ea5:	e8 f9 dd ff ff       	call   c0020ca3 <thread_current>
c0022eaa:	89 03                	mov    %eax,(%ebx)
}
c0022eac:	89 f0                	mov    %esi,%eax
c0022eae:	83 c4 24             	add    $0x24,%esp
c0022eb1:	5b                   	pop    %ebx
c0022eb2:	5e                   	pop    %esi
c0022eb3:	c3                   	ret    

c0022eb4 <lock_release>:
{
c0022eb4:	57                   	push   %edi
c0022eb5:	56                   	push   %esi
c0022eb6:	53                   	push   %ebx
c0022eb7:	83 ec 20             	sub    $0x20,%esp
c0022eba:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (lock != NULL);
c0022ebe:	85 db                	test   %ebx,%ebx
c0022ec0:	75 2c                	jne    c0022eee <lock_release+0x3a>
c0022ec2:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0022ec9:	c0 
c0022eca:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022ed1:	c0 
c0022ed2:	c7 44 24 08 0b d2 02 	movl   $0xc002d20b,0x8(%esp)
c0022ed9:	c0 
c0022eda:	c7 44 24 04 27 01 00 	movl   $0x127,0x4(%esp)
c0022ee1:	00 
c0022ee2:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022ee9:	e8 85 5a 00 00       	call   c0028973 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c0022eee:	89 1c 24             	mov    %ebx,(%esp)
c0022ef1:	e8 ab fd ff ff       	call   c0022ca1 <lock_held_by_current_thread>
c0022ef6:	84 c0                	test   %al,%al
c0022ef8:	75 2c                	jne    c0022f26 <lock_release+0x72>
c0022efa:	c7 44 24 10 a0 ea 02 	movl   $0xc002eaa0,0x10(%esp)
c0022f01:	c0 
c0022f02:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022f09:	c0 
c0022f0a:	c7 44 24 08 0b d2 02 	movl   $0xc002d20b,0x8(%esp)
c0022f11:	c0 
c0022f12:	c7 44 24 04 28 01 00 	movl   $0x128,0x4(%esp)
c0022f19:	00 
c0022f1a:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022f21:	e8 4d 5a 00 00       	call   c0028973 <debug_panic>
  old_level = intr_disable ();
c0022f26:	e8 24 e9 ff ff       	call   c002184f <intr_disable>
c0022f2b:	89 c6                	mov    %eax,%esi
  lock->holder = NULL;
c0022f2d:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  lock->max_priority = -1;
c0022f33:	c7 43 20 ff ff ff ff 	movl   $0xffffffff,0x20(%ebx)
  list_remove(&lock->elem);
c0022f3a:	8d 43 18             	lea    0x18(%ebx),%eax
c0022f3d:	89 04 24             	mov    %eax,(%esp)
c0022f40:	e8 9f 60 00 00       	call   c0028fe4 <list_remove>
  if(!thread_mlfqs)
c0022f45:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0022f4c:	75 45                	jne    c0022f93 <lock_release+0xdf>
    if(!list_empty(&(thread_current()->locks_held)))
c0022f4e:	e8 50 dd ff ff       	call   c0020ca3 <thread_current>
c0022f53:	83 c0 40             	add    $0x40,%eax
c0022f56:	89 04 24             	mov    %eax,(%esp)
c0022f59:	e8 18 61 00 00       	call   c0029076 <list_empty>
c0022f5e:	84 c0                	test   %al,%al
c0022f60:	75 1f                	jne    c0022f81 <lock_release+0xcd>
      struct list_elem *first_elem = list_begin(&(thread_current()->locks_held));
c0022f62:	e8 3c dd ff ff       	call   c0020ca3 <thread_current>
c0022f67:	83 c0 40             	add    $0x40,%eax
c0022f6a:	89 04 24             	mov    %eax,(%esp)
c0022f6d:	e8 1f 5b 00 00       	call   c0028a91 <list_begin>
c0022f72:	89 c7                	mov    %eax,%edi
      thread_current()->priority = l->max_priority;
c0022f74:	e8 2a dd ff ff       	call   c0020ca3 <thread_current>
c0022f79:	8b 57 08             	mov    0x8(%edi),%edx
c0022f7c:	89 50 1c             	mov    %edx,0x1c(%eax)
c0022f7f:	eb 12                	jmp    c0022f93 <lock_release+0xdf>
      thread_current()->priority = thread_current()->old_priority;
c0022f81:	e8 1d dd ff ff       	call   c0020ca3 <thread_current>
c0022f86:	89 c7                	mov    %eax,%edi
c0022f88:	e8 16 dd ff ff       	call   c0020ca3 <thread_current>
c0022f8d:	8b 40 3c             	mov    0x3c(%eax),%eax
c0022f90:	89 47 1c             	mov    %eax,0x1c(%edi)
  intr_set_level (old_level);
c0022f93:	89 34 24             	mov    %esi,(%esp)
c0022f96:	e8 bb e8 ff ff       	call   c0021856 <intr_set_level>
  sema_up (&lock->semaphore);
c0022f9b:	83 c3 04             	add    $0x4,%ebx
c0022f9e:	89 1c 24             	mov    %ebx,(%esp)
c0022fa1:	e8 31 fb ff ff       	call   c0022ad7 <sema_up>
}
c0022fa6:	83 c4 20             	add    $0x20,%esp
c0022fa9:	5b                   	pop    %ebx
c0022faa:	5e                   	pop    %esi
c0022fab:	5f                   	pop    %edi
c0022fac:	c3                   	ret    

c0022fad <cond_init>:
/* Initializes condition variable COND.  A condition variable
   allows one piece of code to signal a condition and cooperating
   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
c0022fad:	83 ec 2c             	sub    $0x2c,%esp
c0022fb0:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (cond != NULL);
c0022fb4:	85 c0                	test   %eax,%eax
c0022fb6:	75 2c                	jne    c0022fe4 <cond_init+0x37>
c0022fb8:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c0022fbf:	c0 
c0022fc0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0022fc7:	c0 
c0022fc8:	c7 44 24 08 e5 d1 02 	movl   $0xc002d1e5,0x8(%esp)
c0022fcf:	c0 
c0022fd0:	c7 44 24 04 70 01 00 	movl   $0x170,0x4(%esp)
c0022fd7:	00 
c0022fd8:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0022fdf:	e8 8f 59 00 00       	call   c0028973 <debug_panic>

  list_init (&cond->waiters);
c0022fe4:	89 04 24             	mov    %eax,(%esp)
c0022fe7:	e8 54 5a 00 00       	call   c0028a40 <list_init>
}
c0022fec:	83 c4 2c             	add    $0x2c,%esp
c0022fef:	c3                   	ret    

c0022ff0 <cond_wait>:
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
cond_wait (struct condition *cond, struct lock *lock) 
{
c0022ff0:	55                   	push   %ebp
c0022ff1:	57                   	push   %edi
c0022ff2:	56                   	push   %esi
c0022ff3:	53                   	push   %ebx
c0022ff4:	83 ec 4c             	sub    $0x4c,%esp
c0022ff7:	8b 74 24 60          	mov    0x60(%esp),%esi
c0022ffb:	8b 5c 24 64          	mov    0x64(%esp),%ebx
  struct semaphore_elem waiter;

  ASSERT (cond != NULL);
c0022fff:	85 f6                	test   %esi,%esi
c0023001:	75 2c                	jne    c002302f <cond_wait+0x3f>
c0023003:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c002300a:	c0 
c002300b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023012:	c0 
c0023013:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c002301a:	c0 
c002301b:	c7 44 24 04 8b 01 00 	movl   $0x18b,0x4(%esp)
c0023022:	00 
c0023023:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002302a:	e8 44 59 00 00       	call   c0028973 <debug_panic>
  ASSERT (lock != NULL);
c002302f:	85 db                	test   %ebx,%ebx
c0023031:	75 2c                	jne    c002305f <cond_wait+0x6f>
c0023033:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c002303a:	c0 
c002303b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023042:	c0 
c0023043:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c002304a:	c0 
c002304b:	c7 44 24 04 8c 01 00 	movl   $0x18c,0x4(%esp)
c0023052:	00 
c0023053:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002305a:	e8 14 59 00 00       	call   c0028973 <debug_panic>
  ASSERT (!intr_context ());
c002305f:	e8 4d ea ff ff       	call   c0021ab1 <intr_context>
c0023064:	84 c0                	test   %al,%al
c0023066:	74 2c                	je     c0023094 <cond_wait+0xa4>
c0023068:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c002306f:	c0 
c0023070:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023077:	c0 
c0023078:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c002307f:	c0 
c0023080:	c7 44 24 04 8d 01 00 	movl   $0x18d,0x4(%esp)
c0023087:	00 
c0023088:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002308f:	e8 df 58 00 00       	call   c0028973 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c0023094:	89 1c 24             	mov    %ebx,(%esp)
c0023097:	e8 05 fc ff ff       	call   c0022ca1 <lock_held_by_current_thread>
c002309c:	84 c0                	test   %al,%al
c002309e:	75 2c                	jne    c00230cc <cond_wait+0xdc>
c00230a0:	c7 44 24 10 a0 ea 02 	movl   $0xc002eaa0,0x10(%esp)
c00230a7:	c0 
c00230a8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00230af:	c0 
c00230b0:	c7 44 24 08 db d1 02 	movl   $0xc002d1db,0x8(%esp)
c00230b7:	c0 
c00230b8:	c7 44 24 04 8e 01 00 	movl   $0x18e,0x4(%esp)
c00230bf:	00 
c00230c0:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00230c7:	e8 a7 58 00 00       	call   c0028973 <debug_panic>
  
  sema_init (&waiter.semaphore, 0);
c00230cc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00230d3:	00 
c00230d4:	8d 6c 24 20          	lea    0x20(%esp),%ebp
c00230d8:	8d 7c 24 28          	lea    0x28(%esp),%edi
c00230dc:	89 3c 24             	mov    %edi,(%esp)
c00230df:	e8 92 f8 ff ff       	call   c0022976 <sema_init>
  waiter.priority = thread_get_priority(); //(ADDED) sets sema's prio value to the threads prio
c00230e4:	e8 1b dd ff ff       	call   c0020e04 <thread_get_priority>
c00230e9:	89 44 24 3c          	mov    %eax,0x3c(%esp)

  list_push_back (&cond->waiters, &waiter.elem);
c00230ed:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c00230f1:	89 34 24             	mov    %esi,(%esp)
c00230f4:	e8 c8 5e 00 00       	call   c0028fc1 <list_push_back>
  lock_release (lock);
c00230f9:	89 1c 24             	mov    %ebx,(%esp)
c00230fc:	e8 b3 fd ff ff       	call   c0022eb4 <lock_release>
  sema_down (&waiter.semaphore);
c0023101:	89 3c 24             	mov    %edi,(%esp)
c0023104:	e8 b9 f8 ff ff       	call   c00229c2 <sema_down>
  lock_acquire (lock);
c0023109:	89 1c 24             	mov    %ebx,(%esp)
c002310c:	e8 d9 fb ff ff       	call   c0022cea <lock_acquire>
}
c0023111:	83 c4 4c             	add    $0x4c,%esp
c0023114:	5b                   	pop    %ebx
c0023115:	5e                   	pop    %esi
c0023116:	5f                   	pop    %edi
c0023117:	5d                   	pop    %ebp
c0023118:	c3                   	ret    

c0023119 <cond_signal>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_signal (struct condition *cond, struct lock *lock UNUSED) 
{
c0023119:	56                   	push   %esi
c002311a:	53                   	push   %ebx
c002311b:	83 ec 24             	sub    $0x24,%esp
c002311e:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0023122:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c0023126:	85 db                	test   %ebx,%ebx
c0023128:	75 2c                	jne    c0023156 <cond_signal+0x3d>
c002312a:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c0023131:	c0 
c0023132:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023139:	c0 
c002313a:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c0023141:	c0 
c0023142:	c7 44 24 04 a2 01 00 	movl   $0x1a2,0x4(%esp)
c0023149:	00 
c002314a:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0023151:	e8 1d 58 00 00       	call   c0028973 <debug_panic>
  ASSERT (lock != NULL);
c0023156:	85 f6                	test   %esi,%esi
c0023158:	75 2c                	jne    c0023186 <cond_signal+0x6d>
c002315a:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c0023161:	c0 
c0023162:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023169:	c0 
c002316a:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c0023171:	c0 
c0023172:	c7 44 24 04 a3 01 00 	movl   $0x1a3,0x4(%esp)
c0023179:	00 
c002317a:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c0023181:	e8 ed 57 00 00       	call   c0028973 <debug_panic>
  ASSERT (!intr_context ());
c0023186:	e8 26 e9 ff ff       	call   c0021ab1 <intr_context>
c002318b:	84 c0                	test   %al,%al
c002318d:	74 2c                	je     c00231bb <cond_signal+0xa2>
c002318f:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0023196:	c0 
c0023197:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002319e:	c0 
c002319f:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c00231a6:	c0 
c00231a7:	c7 44 24 04 a4 01 00 	movl   $0x1a4,0x4(%esp)
c00231ae:	00 
c00231af:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00231b6:	e8 b8 57 00 00       	call   c0028973 <debug_panic>
  ASSERT (lock_held_by_current_thread (lock));
c00231bb:	89 34 24             	mov    %esi,(%esp)
c00231be:	e8 de fa ff ff       	call   c0022ca1 <lock_held_by_current_thread>
c00231c3:	84 c0                	test   %al,%al
c00231c5:	75 2c                	jne    c00231f3 <cond_signal+0xda>
c00231c7:	c7 44 24 10 a0 ea 02 	movl   $0xc002eaa0,0x10(%esp)
c00231ce:	c0 
c00231cf:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00231d6:	c0 
c00231d7:	c7 44 24 08 cf d1 02 	movl   $0xc002d1cf,0x8(%esp)
c00231de:	c0 
c00231df:	c7 44 24 04 a5 01 00 	movl   $0x1a5,0x4(%esp)
c00231e6:	00 
c00231e7:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c00231ee:	e8 80 57 00 00       	call   c0028973 <debug_panic>

  struct list_elem *max_cond_waiter; //(ADDED) to be used below
  if (!list_empty (&cond->waiters)) 
c00231f3:	89 1c 24             	mov    %ebx,(%esp)
c00231f6:	e8 7b 5e 00 00       	call   c0029076 <list_empty>
c00231fb:	84 c0                	test   %al,%al
c00231fd:	75 2d                	jne    c002322c <cond_signal+0x113>
  {
    //(ADDED) wakes max prio thread
    //sema_up (&list_entry (list_pop_front (&cond->waiters), struct semaphore_elem, elem)->semaphore);
    max_cond_waiter = list_max (&cond->waiters,semaPrioCompare,NULL);
c00231ff:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0023206:	00 
c0023207:	c7 44 24 04 64 29 02 	movl   $0xc0022964,0x4(%esp)
c002320e:	c0 
c002320f:	89 1c 24             	mov    %ebx,(%esp)
c0023212:	e8 33 64 00 00       	call   c002964a <list_max>
c0023217:	89 c3                	mov    %eax,%ebx
    list_remove(max_cond_waiter);
c0023219:	89 04 24             	mov    %eax,(%esp)
c002321c:	e8 c3 5d 00 00       	call   c0028fe4 <list_remove>
    sema_up (&list_entry(max_cond_waiter,struct semaphore_elem,elem)->semaphore);
c0023221:	83 c3 08             	add    $0x8,%ebx
c0023224:	89 1c 24             	mov    %ebx,(%esp)
c0023227:	e8 ab f8 ff ff       	call   c0022ad7 <sema_up>
  }
}
c002322c:	83 c4 24             	add    $0x24,%esp
c002322f:	5b                   	pop    %ebx
c0023230:	5e                   	pop    %esi
c0023231:	c3                   	ret    

c0023232 <cond_broadcast>:
   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock) 
{
c0023232:	56                   	push   %esi
c0023233:	53                   	push   %ebx
c0023234:	83 ec 24             	sub    $0x24,%esp
c0023237:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002323b:	8b 74 24 34          	mov    0x34(%esp),%esi
  ASSERT (cond != NULL);
c002323f:	85 db                	test   %ebx,%ebx
c0023241:	75 2c                	jne    c002326f <cond_broadcast+0x3d>
c0023243:	c7 44 24 10 6c ea 02 	movl   $0xc002ea6c,0x10(%esp)
c002324a:	c0 
c002324b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023252:	c0 
c0023253:	c7 44 24 08 c0 d1 02 	movl   $0xc002d1c0,0x8(%esp)
c002325a:	c0 
c002325b:	c7 44 24 04 ba 01 00 	movl   $0x1ba,0x4(%esp)
c0023262:	00 
c0023263:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002326a:	e8 04 57 00 00       	call   c0028973 <debug_panic>
  ASSERT (lock != NULL);
c002326f:	85 f6                	test   %esi,%esi
c0023271:	75 38                	jne    c00232ab <cond_broadcast+0x79>
c0023273:	c7 44 24 10 5f ea 02 	movl   $0xc002ea5f,0x10(%esp)
c002327a:	c0 
c002327b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023282:	c0 
c0023283:	c7 44 24 08 c0 d1 02 	movl   $0xc002d1c0,0x8(%esp)
c002328a:	c0 
c002328b:	c7 44 24 04 bb 01 00 	movl   $0x1bb,0x4(%esp)
c0023292:	00 
c0023293:	c7 04 24 23 ea 02 c0 	movl   $0xc002ea23,(%esp)
c002329a:	e8 d4 56 00 00       	call   c0028973 <debug_panic>

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
c002329f:	89 74 24 04          	mov    %esi,0x4(%esp)
c00232a3:	89 1c 24             	mov    %ebx,(%esp)
c00232a6:	e8 6e fe ff ff       	call   c0023119 <cond_signal>
  while (!list_empty (&cond->waiters))
c00232ab:	89 1c 24             	mov    %ebx,(%esp)
c00232ae:	e8 c3 5d 00 00       	call   c0029076 <list_empty>
c00232b3:	84 c0                	test   %al,%al
c00232b5:	74 e8                	je     c002329f <cond_broadcast+0x6d>
c00232b7:	83 c4 24             	add    $0x24,%esp
c00232ba:	5b                   	pop    %ebx
c00232bb:	5e                   	pop    %esi
c00232bc:	c3                   	ret    

c00232bd <init_pool>:

/* Initializes pool P as starting at START and ending at END,
   naming it NAME for debugging purposes. */
static void
init_pool (struct pool *p, void *base, size_t page_cnt, const char *name) 
{
c00232bd:	55                   	push   %ebp
c00232be:	57                   	push   %edi
c00232bf:	56                   	push   %esi
c00232c0:	53                   	push   %ebx
c00232c1:	83 ec 2c             	sub    $0x2c,%esp
c00232c4:	89 c7                	mov    %eax,%edi
c00232c6:	89 d5                	mov    %edx,%ebp
c00232c8:	89 cb                	mov    %ecx,%ebx
  /* We'll put the pool's used_map at its base.
     Calculate the space needed for the bitmap
     and subtract it from the pool's size. */
  size_t bm_pages = DIV_ROUND_UP (bitmap_buf_size (page_cnt), PGSIZE);
c00232ca:	89 0c 24             	mov    %ecx,(%esp)
c00232cd:	e8 4e 64 00 00       	call   c0029720 <bitmap_buf_size>
c00232d2:	8d b0 ff 0f 00 00    	lea    0xfff(%eax),%esi
c00232d8:	c1 ee 0c             	shr    $0xc,%esi
  if (bm_pages > page_cnt)
c00232db:	39 f3                	cmp    %esi,%ebx
c00232dd:	73 2c                	jae    c002330b <init_pool+0x4e>
    PANIC ("Not enough memory in %s for bitmap.", name);
c00232df:	8b 44 24 40          	mov    0x40(%esp),%eax
c00232e3:	89 44 24 10          	mov    %eax,0x10(%esp)
c00232e7:	c7 44 24 0c c4 ea 02 	movl   $0xc002eac4,0xc(%esp)
c00232ee:	c0 
c00232ef:	c7 44 24 08 93 d2 02 	movl   $0xc002d293,0x8(%esp)
c00232f6:	c0 
c00232f7:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c00232fe:	00 
c00232ff:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c0023306:	e8 68 56 00 00       	call   c0028973 <debug_panic>
  page_cnt -= bm_pages;
c002330b:	29 f3                	sub    %esi,%ebx

  printf ("%zu pages available in %s.\n", page_cnt, name);
c002330d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0023311:	89 44 24 08          	mov    %eax,0x8(%esp)
c0023315:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023319:	c7 04 24 2f eb 02 c0 	movl   $0xc002eb2f,(%esp)
c0023320:	e8 f9 37 00 00       	call   c0026b1e <printf>

  /* Initialize the pool. */
  lock_init (&p->lock);
c0023325:	89 3c 24             	mov    %edi,(%esp)
c0023328:	e8 20 f9 ff ff       	call   c0022c4d <lock_init>
  p->used_map = bitmap_create_in_buf (page_cnt, base, bm_pages * PGSIZE);
c002332d:	c1 e6 0c             	shl    $0xc,%esi
c0023330:	89 74 24 08          	mov    %esi,0x8(%esp)
c0023334:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0023338:	89 1c 24             	mov    %ebx,(%esp)
c002333b:	e8 25 67 00 00       	call   c0029a65 <bitmap_create_in_buf>
c0023340:	89 47 24             	mov    %eax,0x24(%edi)
  p->base = base + bm_pages * PGSIZE;
c0023343:	01 ee                	add    %ebp,%esi
c0023345:	89 77 28             	mov    %esi,0x28(%edi)
}
c0023348:	83 c4 2c             	add    $0x2c,%esp
c002334b:	5b                   	pop    %ebx
c002334c:	5e                   	pop    %esi
c002334d:	5f                   	pop    %edi
c002334e:	5d                   	pop    %ebp
c002334f:	c3                   	ret    

c0023350 <palloc_init>:
{
c0023350:	56                   	push   %esi
c0023351:	53                   	push   %ebx
c0023352:	83 ec 24             	sub    $0x24,%esp
c0023355:	8b 54 24 30          	mov    0x30(%esp),%edx
  uint8_t *free_end = ptov (init_ram_pages * PGSIZE);
c0023359:	a1 86 01 02 c0       	mov    0xc0020186,%eax
c002335e:	c1 e0 0c             	shl    $0xc,%eax
  ASSERT ((void *) paddr < PHYS_BASE);
c0023361:	3d ff ff ff bf       	cmp    $0xbfffffff,%eax
c0023366:	76 2c                	jbe    c0023394 <palloc_init+0x44>
c0023368:	c7 44 24 10 56 e1 02 	movl   $0xc002e156,0x10(%esp)
c002336f:	c0 
c0023370:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023377:	c0 
c0023378:	c7 44 24 08 9d d2 02 	movl   $0xc002d29d,0x8(%esp)
c002337f:	c0 
c0023380:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0023387:	00 
c0023388:	c7 04 24 88 e1 02 c0 	movl   $0xc002e188,(%esp)
c002338f:	e8 df 55 00 00       	call   c0028973 <debug_panic>
  size_t free_pages = (free_end - free_start) / PGSIZE;
c0023394:	8d b0 ff 0f f0 ff    	lea    -0xff001(%eax),%esi
c002339a:	2d 00 00 10 00       	sub    $0x100000,%eax
c002339f:	0f 49 f0             	cmovns %eax,%esi
c00233a2:	c1 fe 0c             	sar    $0xc,%esi
  size_t user_pages = free_pages / 2;
c00233a5:	89 f3                	mov    %esi,%ebx
c00233a7:	d1 eb                	shr    %ebx
c00233a9:	39 d3                	cmp    %edx,%ebx
c00233ab:	0f 47 da             	cmova  %edx,%ebx
  kernel_pages = free_pages - user_pages;
c00233ae:	29 de                	sub    %ebx,%esi
  init_pool (&kernel_pool, free_start, kernel_pages, "kernel pool");
c00233b0:	c7 04 24 4b eb 02 c0 	movl   $0xc002eb4b,(%esp)
c00233b7:	89 f1                	mov    %esi,%ecx
c00233b9:	ba 00 00 10 c0       	mov    $0xc0100000,%edx
c00233be:	b8 a0 74 03 c0       	mov    $0xc00374a0,%eax
c00233c3:	e8 f5 fe ff ff       	call   c00232bd <init_pool>
  init_pool (&user_pool, free_start + kernel_pages * PGSIZE,
c00233c8:	c1 e6 0c             	shl    $0xc,%esi
c00233cb:	8d 96 00 00 10 c0    	lea    -0x3ff00000(%esi),%edx
c00233d1:	c7 04 24 57 eb 02 c0 	movl   $0xc002eb57,(%esp)
c00233d8:	89 d9                	mov    %ebx,%ecx
c00233da:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c00233df:	e8 d9 fe ff ff       	call   c00232bd <init_pool>
}
c00233e4:	83 c4 24             	add    $0x24,%esp
c00233e7:	5b                   	pop    %ebx
c00233e8:	5e                   	pop    %esi
c00233e9:	c3                   	ret    

c00233ea <palloc_get_multiple>:
{
c00233ea:	55                   	push   %ebp
c00233eb:	57                   	push   %edi
c00233ec:	56                   	push   %esi
c00233ed:	53                   	push   %ebx
c00233ee:	83 ec 1c             	sub    $0x1c,%esp
c00233f1:	8b 74 24 30          	mov    0x30(%esp),%esi
c00233f5:	8b 7c 24 34          	mov    0x34(%esp),%edi
  struct pool *pool = flags & PAL_USER ? &user_pool : &kernel_pool;
c00233f9:	89 f0                	mov    %esi,%eax
c00233fb:	83 e0 04             	and    $0x4,%eax
c00233fe:	b8 60 74 03 c0       	mov    $0xc0037460,%eax
c0023403:	bb a0 74 03 c0       	mov    $0xc00374a0,%ebx
c0023408:	0f 45 d8             	cmovne %eax,%ebx
  if (page_cnt == 0)
c002340b:	85 ff                	test   %edi,%edi
c002340d:	0f 84 8f 00 00 00    	je     c00234a2 <palloc_get_multiple+0xb8>
  lock_acquire (&pool->lock);
c0023413:	89 1c 24             	mov    %ebx,(%esp)
c0023416:	e8 cf f8 ff ff       	call   c0022cea <lock_acquire>
  page_idx = bitmap_scan_and_flip (pool->used_map, 0, page_cnt, false);
c002341b:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023422:	00 
c0023423:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0023427:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002342e:	00 
c002342f:	8b 43 24             	mov    0x24(%ebx),%eax
c0023432:	89 04 24             	mov    %eax,(%esp)
c0023435:	e8 b0 69 00 00       	call   c0029dea <bitmap_scan_and_flip>
c002343a:	89 c5                	mov    %eax,%ebp
  lock_release (&pool->lock);
c002343c:	89 1c 24             	mov    %ebx,(%esp)
c002343f:	e8 70 fa ff ff       	call   c0022eb4 <lock_release>
  if (page_idx != BITMAP_ERROR)
c0023444:	83 fd ff             	cmp    $0xffffffff,%ebp
c0023447:	74 2d                	je     c0023476 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c0023449:	c1 e5 0c             	shl    $0xc,%ebp
  if (pages != NULL) 
c002344c:	03 6b 28             	add    0x28(%ebx),%ebp
c002344f:	74 25                	je     c0023476 <palloc_get_multiple+0x8c>
    pages = pool->base + PGSIZE * page_idx;
c0023451:	89 e8                	mov    %ebp,%eax
      if (flags & PAL_ZERO)
c0023453:	f7 c6 02 00 00 00    	test   $0x2,%esi
c0023459:	74 53                	je     c00234ae <palloc_get_multiple+0xc4>
        memset (pages, 0, PGSIZE * page_cnt);
c002345b:	c1 e7 0c             	shl    $0xc,%edi
c002345e:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0023462:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023469:	00 
c002346a:	89 2c 24             	mov    %ebp,(%esp)
c002346d:	e8 bf 49 00 00       	call   c0027e31 <memset>
    pages = pool->base + PGSIZE * page_idx;
c0023472:	89 e8                	mov    %ebp,%eax
c0023474:	eb 38                	jmp    c00234ae <palloc_get_multiple+0xc4>
      if (flags & PAL_ASSERT)
c0023476:	f7 c6 01 00 00 00    	test   $0x1,%esi
c002347c:	74 2b                	je     c00234a9 <palloc_get_multiple+0xbf>
        PANIC ("palloc_get: out of pages");
c002347e:	c7 44 24 0c 61 eb 02 	movl   $0xc002eb61,0xc(%esp)
c0023485:	c0 
c0023486:	c7 44 24 08 7f d2 02 	movl   $0xc002d27f,0x8(%esp)
c002348d:	c0 
c002348e:	c7 44 24 04 61 00 00 	movl   $0x61,0x4(%esp)
c0023495:	00 
c0023496:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c002349d:	e8 d1 54 00 00       	call   c0028973 <debug_panic>
    return NULL;
c00234a2:	b8 00 00 00 00       	mov    $0x0,%eax
c00234a7:	eb 05                	jmp    c00234ae <palloc_get_multiple+0xc4>
  return pages;
c00234a9:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00234ae:	83 c4 1c             	add    $0x1c,%esp
c00234b1:	5b                   	pop    %ebx
c00234b2:	5e                   	pop    %esi
c00234b3:	5f                   	pop    %edi
c00234b4:	5d                   	pop    %ebp
c00234b5:	c3                   	ret    

c00234b6 <palloc_get_page>:
{
c00234b6:	83 ec 1c             	sub    $0x1c,%esp
  return palloc_get_multiple (flags, 1);
c00234b9:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c00234c0:	00 
c00234c1:	8b 44 24 20          	mov    0x20(%esp),%eax
c00234c5:	89 04 24             	mov    %eax,(%esp)
c00234c8:	e8 1d ff ff ff       	call   c00233ea <palloc_get_multiple>
}
c00234cd:	83 c4 1c             	add    $0x1c,%esp
c00234d0:	c3                   	ret    

c00234d1 <palloc_free_multiple>:
{
c00234d1:	55                   	push   %ebp
c00234d2:	57                   	push   %edi
c00234d3:	56                   	push   %esi
c00234d4:	53                   	push   %ebx
c00234d5:	83 ec 2c             	sub    $0x2c,%esp
c00234d8:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c00234dc:	8b 74 24 44          	mov    0x44(%esp),%esi
  ASSERT (pg_ofs (pages) == 0);
c00234e0:	f7 c3 ff 0f 00 00    	test   $0xfff,%ebx
c00234e6:	74 2c                	je     c0023514 <palloc_free_multiple+0x43>
c00234e8:	c7 44 24 10 7a eb 02 	movl   $0xc002eb7a,0x10(%esp)
c00234ef:	c0 
c00234f0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00234f7:	c0 
c00234f8:	c7 44 24 08 6a d2 02 	movl   $0xc002d26a,0x8(%esp)
c00234ff:	c0 
c0023500:	c7 44 24 04 7b 00 00 	movl   $0x7b,0x4(%esp)
c0023507:	00 
c0023508:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c002350f:	e8 5f 54 00 00       	call   c0028973 <debug_panic>
  if (pages == NULL || page_cnt == 0)
c0023514:	85 db                	test   %ebx,%ebx
c0023516:	0f 84 fc 00 00 00    	je     c0023618 <palloc_free_multiple+0x147>
c002351c:	85 f6                	test   %esi,%esi
c002351e:	0f 84 f4 00 00 00    	je     c0023618 <palloc_free_multiple+0x147>
  return (uintptr_t) va >> PGBITS;
c0023524:	89 df                	mov    %ebx,%edi
c0023526:	c1 ef 0c             	shr    $0xc,%edi
c0023529:	8b 2d c8 74 03 c0    	mov    0xc00374c8,%ebp
c002352f:	c1 ed 0c             	shr    $0xc,%ebp
static bool
page_from_pool (const struct pool *pool, void *page) 
{
  size_t page_no = pg_no (page);
  size_t start_page = pg_no (pool->base);
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0023532:	a1 c4 74 03 c0       	mov    0xc00374c4,%eax
c0023537:	89 04 24             	mov    %eax,(%esp)
c002353a:	e8 17 62 00 00       	call   c0029756 <bitmap_size>
c002353f:	01 e8                	add    %ebp,%eax
  if (page_from_pool (&kernel_pool, pages))
c0023541:	39 c7                	cmp    %eax,%edi
c0023543:	73 04                	jae    c0023549 <palloc_free_multiple+0x78>
c0023545:	39 ef                	cmp    %ebp,%edi
c0023547:	73 44                	jae    c002358d <palloc_free_multiple+0xbc>
c0023549:	8b 2d 88 74 03 c0    	mov    0xc0037488,%ebp
c002354f:	c1 ed 0c             	shr    $0xc,%ebp
  size_t end_page = start_page + bitmap_size (pool->used_map);
c0023552:	a1 84 74 03 c0       	mov    0xc0037484,%eax
c0023557:	89 04 24             	mov    %eax,(%esp)
c002355a:	e8 f7 61 00 00       	call   c0029756 <bitmap_size>
c002355f:	01 e8                	add    %ebp,%eax
  else if (page_from_pool (&user_pool, pages))
c0023561:	39 c7                	cmp    %eax,%edi
c0023563:	73 04                	jae    c0023569 <palloc_free_multiple+0x98>
c0023565:	39 ef                	cmp    %ebp,%edi
c0023567:	73 2b                	jae    c0023594 <palloc_free_multiple+0xc3>
    NOT_REACHED ();
c0023569:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c0023570:	c0 
c0023571:	c7 44 24 08 6a d2 02 	movl   $0xc002d26a,0x8(%esp)
c0023578:	c0 
c0023579:	c7 44 24 04 84 00 00 	movl   $0x84,0x4(%esp)
c0023580:	00 
c0023581:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c0023588:	e8 e6 53 00 00       	call   c0028973 <debug_panic>
    pool = &kernel_pool;
c002358d:	bd a0 74 03 c0       	mov    $0xc00374a0,%ebp
c0023592:	eb 05                	jmp    c0023599 <palloc_free_multiple+0xc8>
    pool = &user_pool;
c0023594:	bd 60 74 03 c0       	mov    $0xc0037460,%ebp
c0023599:	8b 45 28             	mov    0x28(%ebp),%eax
c002359c:	c1 e8 0c             	shr    $0xc,%eax
  page_idx = pg_no (pages) - pg_no (pool->base);
c002359f:	29 c7                	sub    %eax,%edi
  memset (pages, 0xcc, PGSIZE * page_cnt);
c00235a1:	89 f0                	mov    %esi,%eax
c00235a3:	c1 e0 0c             	shl    $0xc,%eax
c00235a6:	89 44 24 08          	mov    %eax,0x8(%esp)
c00235aa:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c00235b1:	00 
c00235b2:	89 1c 24             	mov    %ebx,(%esp)
c00235b5:	e8 77 48 00 00       	call   c0027e31 <memset>
  ASSERT (bitmap_all (pool->used_map, page_idx, page_cnt));
c00235ba:	89 74 24 08          	mov    %esi,0x8(%esp)
c00235be:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00235c2:	8b 45 24             	mov    0x24(%ebp),%eax
c00235c5:	89 04 24             	mov    %eax,(%esp)
c00235c8:	e8 1f 67 00 00       	call   c0029cec <bitmap_all>
c00235cd:	84 c0                	test   %al,%al
c00235cf:	75 2c                	jne    c00235fd <palloc_free_multiple+0x12c>
c00235d1:	c7 44 24 10 e8 ea 02 	movl   $0xc002eae8,0x10(%esp)
c00235d8:	c0 
c00235d9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00235e0:	c0 
c00235e1:	c7 44 24 08 6a d2 02 	movl   $0xc002d26a,0x8(%esp)
c00235e8:	c0 
c00235e9:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c00235f0:	00 
c00235f1:	c7 04 24 18 eb 02 c0 	movl   $0xc002eb18,(%esp)
c00235f8:	e8 76 53 00 00       	call   c0028973 <debug_panic>
  bitmap_set_multiple (pool->used_map, page_idx, page_cnt, false);
c00235fd:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023604:	00 
c0023605:	89 74 24 08          	mov    %esi,0x8(%esp)
c0023609:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002360d:	8b 45 24             	mov    0x24(%ebp),%eax
c0023610:	89 04 24             	mov    %eax,(%esp)
c0023613:	e8 b5 62 00 00       	call   c00298cd <bitmap_set_multiple>
}
c0023618:	83 c4 2c             	add    $0x2c,%esp
c002361b:	5b                   	pop    %ebx
c002361c:	5e                   	pop    %esi
c002361d:	5f                   	pop    %edi
c002361e:	5d                   	pop    %ebp
c002361f:	c3                   	ret    

c0023620 <palloc_free_page>:
{
c0023620:	83 ec 1c             	sub    $0x1c,%esp
  palloc_free_multiple (page, 1);
c0023623:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c002362a:	00 
c002362b:	8b 44 24 20          	mov    0x20(%esp),%eax
c002362f:	89 04 24             	mov    %eax,(%esp)
c0023632:	e8 9a fe ff ff       	call   c00234d1 <palloc_free_multiple>
}
c0023637:	83 c4 1c             	add    $0x1c,%esp
c002363a:	c3                   	ret    
c002363b:	90                   	nop
c002363c:	90                   	nop
c002363d:	90                   	nop
c002363e:	90                   	nop
c002363f:	90                   	nop

c0023640 <arena_to_block>:
}

/* Returns the (IDX - 1)'th block within arena A. */
static struct block *
arena_to_block (struct arena *a, size_t idx) 
{
c0023640:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (a != NULL);
c0023643:	85 c0                	test   %eax,%eax
c0023645:	75 2c                	jne    c0023673 <arena_to_block+0x33>
c0023647:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c002364e:	c0 
c002364f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023656:	c0 
c0023657:	c7 44 24 08 b6 d2 02 	movl   $0xc002d2b6,0x8(%esp)
c002365e:	c0 
c002365f:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c0023666:	00 
c0023667:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c002366e:	e8 00 53 00 00       	call   c0028973 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c0023673:	81 38 ed 8e 54 9a    	cmpl   $0x9a548eed,(%eax)
c0023679:	74 2c                	je     c00236a7 <arena_to_block+0x67>
c002367b:	c7 44 24 10 a5 eb 02 	movl   $0xc002eba5,0x10(%esp)
c0023682:	c0 
c0023683:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002368a:	c0 
c002368b:	c7 44 24 08 b6 d2 02 	movl   $0xc002d2b6,0x8(%esp)
c0023692:	c0 
c0023693:	c7 44 24 04 21 01 00 	movl   $0x121,0x4(%esp)
c002369a:	00 
c002369b:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c00236a2:	e8 cc 52 00 00       	call   c0028973 <debug_panic>
  ASSERT (idx < a->desc->blocks_per_arena);
c00236a7:	8b 48 04             	mov    0x4(%eax),%ecx
c00236aa:	39 51 04             	cmp    %edx,0x4(%ecx)
c00236ad:	77 2c                	ja     c00236db <arena_to_block+0x9b>
c00236af:	c7 44 24 10 c0 eb 02 	movl   $0xc002ebc0,0x10(%esp)
c00236b6:	c0 
c00236b7:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00236be:	c0 
c00236bf:	c7 44 24 08 b6 d2 02 	movl   $0xc002d2b6,0x8(%esp)
c00236c6:	c0 
c00236c7:	c7 44 24 04 22 01 00 	movl   $0x122,0x4(%esp)
c00236ce:	00 
c00236cf:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c00236d6:	e8 98 52 00 00       	call   c0028973 <debug_panic>
  return (struct block *) ((uint8_t *) a
                           + sizeof *a
                           + idx * a->desc->block_size);
c00236db:	0f af 11             	imul   (%ecx),%edx
  return (struct block *) ((uint8_t *) a
c00236de:	8d 44 10 0c          	lea    0xc(%eax,%edx,1),%eax
}
c00236e2:	83 c4 2c             	add    $0x2c,%esp
c00236e5:	c3                   	ret    

c00236e6 <block_to_arena>:
{
c00236e6:	53                   	push   %ebx
c00236e7:	83 ec 28             	sub    $0x28,%esp
  ASSERT (a != NULL);
c00236ea:	89 c1                	mov    %eax,%ecx
c00236ec:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
c00236f2:	75 2c                	jne    c0023720 <block_to_arena+0x3a>
c00236f4:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c00236fb:	c0 
c00236fc:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023703:	c0 
c0023704:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c002370b:	c0 
c002370c:	c7 44 24 04 11 01 00 	movl   $0x111,0x4(%esp)
c0023713:	00 
c0023714:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c002371b:	e8 53 52 00 00       	call   c0028973 <debug_panic>
  ASSERT (a->magic == ARENA_MAGIC);
c0023720:	81 39 ed 8e 54 9a    	cmpl   $0x9a548eed,(%ecx)
c0023726:	74 2c                	je     c0023754 <block_to_arena+0x6e>
c0023728:	c7 44 24 10 a5 eb 02 	movl   $0xc002eba5,0x10(%esp)
c002372f:	c0 
c0023730:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023737:	c0 
c0023738:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c002373f:	c0 
c0023740:	c7 44 24 04 12 01 00 	movl   $0x112,0x4(%esp)
c0023747:	00 
c0023748:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c002374f:	e8 1f 52 00 00       	call   c0028973 <debug_panic>
  ASSERT (a->desc == NULL
c0023754:	8b 59 04             	mov    0x4(%ecx),%ebx
c0023757:	85 db                	test   %ebx,%ebx
c0023759:	74 3f                	je     c002379a <block_to_arena+0xb4>
  return (uintptr_t) va & PGMASK;
c002375b:	25 ff 0f 00 00       	and    $0xfff,%eax
c0023760:	8d 40 f4             	lea    -0xc(%eax),%eax
c0023763:	ba 00 00 00 00       	mov    $0x0,%edx
c0023768:	f7 33                	divl   (%ebx)
c002376a:	85 d2                	test   %edx,%edx
c002376c:	74 62                	je     c00237d0 <block_to_arena+0xea>
c002376e:	c7 44 24 10 e0 eb 02 	movl   $0xc002ebe0,0x10(%esp)
c0023775:	c0 
c0023776:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002377d:	c0 
c002377e:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c0023785:	c0 
c0023786:	c7 44 24 04 16 01 00 	movl   $0x116,0x4(%esp)
c002378d:	00 
c002378e:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c0023795:	e8 d9 51 00 00       	call   c0028973 <debug_panic>
c002379a:	25 ff 0f 00 00       	and    $0xfff,%eax
  ASSERT (a->desc != NULL || pg_ofs (b) == sizeof *a);
c002379f:	83 f8 0c             	cmp    $0xc,%eax
c00237a2:	74 2c                	je     c00237d0 <block_to_arena+0xea>
c00237a4:	c7 44 24 10 28 ec 02 	movl   $0xc002ec28,0x10(%esp)
c00237ab:	c0 
c00237ac:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00237b3:	c0 
c00237b4:	c7 44 24 08 a7 d2 02 	movl   $0xc002d2a7,0x8(%esp)
c00237bb:	c0 
c00237bc:	c7 44 24 04 17 01 00 	movl   $0x117,0x4(%esp)
c00237c3:	00 
c00237c4:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c00237cb:	e8 a3 51 00 00       	call   c0028973 <debug_panic>
}
c00237d0:	89 c8                	mov    %ecx,%eax
c00237d2:	83 c4 28             	add    $0x28,%esp
c00237d5:	5b                   	pop    %ebx
c00237d6:	c3                   	ret    

c00237d7 <malloc_init>:
{
c00237d7:	57                   	push   %edi
c00237d8:	56                   	push   %esi
c00237d9:	53                   	push   %ebx
c00237da:	83 ec 20             	sub    $0x20,%esp
      struct desc *d = &descs[desc_cnt++];
c00237dd:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c00237e2:	8d 50 01             	lea    0x1(%eax),%edx
c00237e5:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c00237eb:	6b c0 3c             	imul   $0x3c,%eax,%eax
c00237ee:	8d 98 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%ebx
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c00237f4:	83 fa 0a             	cmp    $0xa,%edx
c00237f7:	76 7e                	jbe    c0023877 <malloc_init+0xa0>
c00237f9:	eb 1c                	jmp    c0023817 <malloc_init+0x40>
      struct desc *d = &descs[desc_cnt++];
c00237fb:	a1 e0 74 03 c0       	mov    0xc00374e0,%eax
c0023800:	8d 50 01             	lea    0x1(%eax),%edx
c0023803:	89 15 e0 74 03 c0    	mov    %edx,0xc00374e0
c0023809:	6b c0 3c             	imul   $0x3c,%eax,%eax
c002380c:	8d b0 00 75 03 c0    	lea    -0x3ffc8b00(%eax),%esi
      ASSERT (desc_cnt <= sizeof descs / sizeof *descs);
c0023812:	83 fa 0a             	cmp    $0xa,%edx
c0023815:	76 2c                	jbe    c0023843 <malloc_init+0x6c>
c0023817:	c7 44 24 10 54 ec 02 	movl   $0xc002ec54,0x10(%esp)
c002381e:	c0 
c002381f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023826:	c0 
c0023827:	c7 44 24 08 c5 d2 02 	movl   $0xc002d2c5,0x8(%esp)
c002382e:	c0 
c002382f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c0023836:	00 
c0023837:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c002383e:	e8 30 51 00 00       	call   c0028973 <debug_panic>
      d->block_size = block_size;
c0023843:	89 98 00 75 03 c0    	mov    %ebx,-0x3ffc8b00(%eax)
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0023849:	89 f8                	mov    %edi,%eax
c002384b:	ba 00 00 00 00       	mov    $0x0,%edx
c0023850:	f7 f3                	div    %ebx
c0023852:	89 46 04             	mov    %eax,0x4(%esi)
      list_init (&d->free_list);
c0023855:	8d 46 08             	lea    0x8(%esi),%eax
c0023858:	89 04 24             	mov    %eax,(%esp)
c002385b:	e8 e0 51 00 00       	call   c0028a40 <list_init>
      lock_init (&d->lock);
c0023860:	83 c6 18             	add    $0x18,%esi
c0023863:	89 34 24             	mov    %esi,(%esp)
c0023866:	e8 e2 f3 ff ff       	call   c0022c4d <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c002386b:	01 db                	add    %ebx,%ebx
c002386d:	81 fb ff 07 00 00    	cmp    $0x7ff,%ebx
c0023873:	76 86                	jbe    c00237fb <malloc_init+0x24>
c0023875:	eb 36                	jmp    c00238ad <malloc_init+0xd6>
      d->block_size = block_size;
c0023877:	c7 80 00 75 03 c0 10 	movl   $0x10,-0x3ffc8b00(%eax)
c002387e:	00 00 00 
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c0023881:	c7 43 04 ff 00 00 00 	movl   $0xff,0x4(%ebx)
      list_init (&d->free_list);
c0023888:	8d 43 08             	lea    0x8(%ebx),%eax
c002388b:	89 04 24             	mov    %eax,(%esp)
c002388e:	e8 ad 51 00 00       	call   c0028a40 <list_init>
      lock_init (&d->lock);
c0023893:	83 c3 18             	add    $0x18,%ebx
c0023896:	89 1c 24             	mov    %ebx,(%esp)
c0023899:	e8 af f3 ff ff       	call   c0022c4d <lock_init>
  for (block_size = 16; block_size < PGSIZE / 2; block_size *= 2)
c002389e:	bb 20 00 00 00       	mov    $0x20,%ebx
      d->blocks_per_arena = (PGSIZE - sizeof (struct arena)) / block_size;
c00238a3:	bf f4 0f 00 00       	mov    $0xff4,%edi
c00238a8:	e9 4e ff ff ff       	jmp    c00237fb <malloc_init+0x24>
}
c00238ad:	83 c4 20             	add    $0x20,%esp
c00238b0:	5b                   	pop    %ebx
c00238b1:	5e                   	pop    %esi
c00238b2:	5f                   	pop    %edi
c00238b3:	c3                   	ret    

c00238b4 <malloc>:
{
c00238b4:	55                   	push   %ebp
c00238b5:	57                   	push   %edi
c00238b6:	56                   	push   %esi
c00238b7:	53                   	push   %ebx
c00238b8:	83 ec 1c             	sub    $0x1c,%esp
c00238bb:	8b 54 24 30          	mov    0x30(%esp),%edx
  if (size == 0)
c00238bf:	85 d2                	test   %edx,%edx
c00238c1:	0f 84 15 01 00 00    	je     c00239dc <malloc+0x128>
  for (d = descs; d < descs + desc_cnt; d++)
c00238c7:	6b 05 e0 74 03 c0 3c 	imul   $0x3c,0xc00374e0,%eax
c00238ce:	05 00 75 03 c0       	add    $0xc0037500,%eax
c00238d3:	3d 00 75 03 c0       	cmp    $0xc0037500,%eax
c00238d8:	76 1c                	jbe    c00238f6 <malloc+0x42>
    if (d->block_size >= size)
c00238da:	3b 15 00 75 03 c0    	cmp    0xc0037500,%edx
c00238e0:	76 1b                	jbe    c00238fd <malloc+0x49>
c00238e2:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c00238e7:	eb 04                	jmp    c00238ed <malloc+0x39>
c00238e9:	3b 13                	cmp    (%ebx),%edx
c00238eb:	76 15                	jbe    c0023902 <malloc+0x4e>
  for (d = descs; d < descs + desc_cnt; d++)
c00238ed:	83 c3 3c             	add    $0x3c,%ebx
c00238f0:	39 c3                	cmp    %eax,%ebx
c00238f2:	72 f5                	jb     c00238e9 <malloc+0x35>
c00238f4:	eb 0c                	jmp    c0023902 <malloc+0x4e>
c00238f6:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
c00238fb:	eb 05                	jmp    c0023902 <malloc+0x4e>
    if (d->block_size >= size)
c00238fd:	bb 00 75 03 c0       	mov    $0xc0037500,%ebx
  if (d == descs + desc_cnt) 
c0023902:	39 d8                	cmp    %ebx,%eax
c0023904:	75 39                	jne    c002393f <malloc+0x8b>
      size_t page_cnt = DIV_ROUND_UP (size + sizeof *a, PGSIZE);
c0023906:	8d 9a 0b 10 00 00    	lea    0x100b(%edx),%ebx
c002390c:	c1 eb 0c             	shr    $0xc,%ebx
      a = palloc_get_multiple (0, page_cnt);
c002390f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023913:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002391a:	e8 cb fa ff ff       	call   c00233ea <palloc_get_multiple>
      if (a == NULL)
c002391f:	85 c0                	test   %eax,%eax
c0023921:	0f 84 bc 00 00 00    	je     c00239e3 <malloc+0x12f>
      a->magic = ARENA_MAGIC;
c0023927:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = NULL;
c002392d:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
      a->free_cnt = page_cnt;
c0023934:	89 58 08             	mov    %ebx,0x8(%eax)
      return a + 1;
c0023937:	83 c0 0c             	add    $0xc,%eax
c002393a:	e9 a9 00 00 00       	jmp    c00239e8 <malloc+0x134>
  lock_acquire (&d->lock);
c002393f:	8d 43 18             	lea    0x18(%ebx),%eax
c0023942:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0023946:	89 04 24             	mov    %eax,(%esp)
c0023949:	e8 9c f3 ff ff       	call   c0022cea <lock_acquire>
  if (list_empty (&d->free_list))
c002394e:	8d 7b 08             	lea    0x8(%ebx),%edi
c0023951:	89 3c 24             	mov    %edi,(%esp)
c0023954:	e8 1d 57 00 00       	call   c0029076 <list_empty>
c0023959:	84 c0                	test   %al,%al
c002395b:	74 5c                	je     c00239b9 <malloc+0x105>
      a = palloc_get_page (0);
c002395d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0023964:	e8 4d fb ff ff       	call   c00234b6 <palloc_get_page>
c0023969:	89 c5                	mov    %eax,%ebp
      if (a == NULL) 
c002396b:	85 c0                	test   %eax,%eax
c002396d:	75 13                	jne    c0023982 <malloc+0xce>
          lock_release (&d->lock);
c002396f:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0023973:	89 04 24             	mov    %eax,(%esp)
c0023976:	e8 39 f5 ff ff       	call   c0022eb4 <lock_release>
          return NULL; 
c002397b:	b8 00 00 00 00       	mov    $0x0,%eax
c0023980:	eb 66                	jmp    c00239e8 <malloc+0x134>
      a->magic = ARENA_MAGIC;
c0023982:	c7 00 ed 8e 54 9a    	movl   $0x9a548eed,(%eax)
      a->desc = d;
c0023988:	89 58 04             	mov    %ebx,0x4(%eax)
      a->free_cnt = d->blocks_per_arena;
c002398b:	8b 43 04             	mov    0x4(%ebx),%eax
c002398e:	89 45 08             	mov    %eax,0x8(%ebp)
      for (i = 0; i < d->blocks_per_arena; i++) 
c0023991:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0023995:	74 22                	je     c00239b9 <malloc+0x105>
c0023997:	be 00 00 00 00       	mov    $0x0,%esi
          struct block *b = arena_to_block (a, i);
c002399c:	89 f2                	mov    %esi,%edx
c002399e:	89 e8                	mov    %ebp,%eax
c00239a0:	e8 9b fc ff ff       	call   c0023640 <arena_to_block>
          list_push_back (&d->free_list, &b->free_elem);
c00239a5:	89 44 24 04          	mov    %eax,0x4(%esp)
c00239a9:	89 3c 24             	mov    %edi,(%esp)
c00239ac:	e8 10 56 00 00       	call   c0028fc1 <list_push_back>
      for (i = 0; i < d->blocks_per_arena; i++) 
c00239b1:	83 c6 01             	add    $0x1,%esi
c00239b4:	39 73 04             	cmp    %esi,0x4(%ebx)
c00239b7:	77 e3                	ja     c002399c <malloc+0xe8>
  b = list_entry (list_pop_front (&d->free_list), struct block, free_elem);
c00239b9:	89 3c 24             	mov    %edi,(%esp)
c00239bc:	e8 23 57 00 00       	call   c00290e4 <list_pop_front>
c00239c1:	89 c3                	mov    %eax,%ebx
  a = block_to_arena (b);
c00239c3:	e8 1e fd ff ff       	call   c00236e6 <block_to_arena>
  a->free_cnt--;
c00239c8:	83 68 08 01          	subl   $0x1,0x8(%eax)
  lock_release (&d->lock);
c00239cc:	8b 44 24 0c          	mov    0xc(%esp),%eax
c00239d0:	89 04 24             	mov    %eax,(%esp)
c00239d3:	e8 dc f4 ff ff       	call   c0022eb4 <lock_release>
  return b;
c00239d8:	89 d8                	mov    %ebx,%eax
c00239da:	eb 0c                	jmp    c00239e8 <malloc+0x134>
    return NULL;
c00239dc:	b8 00 00 00 00       	mov    $0x0,%eax
c00239e1:	eb 05                	jmp    c00239e8 <malloc+0x134>
        return NULL;
c00239e3:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00239e8:	83 c4 1c             	add    $0x1c,%esp
c00239eb:	5b                   	pop    %ebx
c00239ec:	5e                   	pop    %esi
c00239ed:	5f                   	pop    %edi
c00239ee:	5d                   	pop    %ebp
c00239ef:	c3                   	ret    

c00239f0 <calloc>:
{
c00239f0:	56                   	push   %esi
c00239f1:	53                   	push   %ebx
c00239f2:	83 ec 14             	sub    $0x14,%esp
c00239f5:	8b 54 24 20          	mov    0x20(%esp),%edx
c00239f9:	8b 44 24 24          	mov    0x24(%esp),%eax
  size = a * b;
c00239fd:	89 d3                	mov    %edx,%ebx
c00239ff:	0f af d8             	imul   %eax,%ebx
  if (size < a || size < b)
c0023a02:	39 c3                	cmp    %eax,%ebx
c0023a04:	72 2a                	jb     c0023a30 <calloc+0x40>
c0023a06:	39 d3                	cmp    %edx,%ebx
c0023a08:	72 26                	jb     c0023a30 <calloc+0x40>
  p = malloc (size);
c0023a0a:	89 1c 24             	mov    %ebx,(%esp)
c0023a0d:	e8 a2 fe ff ff       	call   c00238b4 <malloc>
c0023a12:	89 c6                	mov    %eax,%esi
  if (p != NULL)
c0023a14:	85 f6                	test   %esi,%esi
c0023a16:	74 1d                	je     c0023a35 <calloc+0x45>
    memset (p, 0, size);
c0023a18:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023a1c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023a23:	00 
c0023a24:	89 34 24             	mov    %esi,(%esp)
c0023a27:	e8 05 44 00 00       	call   c0027e31 <memset>
  return p;
c0023a2c:	89 f0                	mov    %esi,%eax
c0023a2e:	eb 05                	jmp    c0023a35 <calloc+0x45>
    return NULL;
c0023a30:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0023a35:	83 c4 14             	add    $0x14,%esp
c0023a38:	5b                   	pop    %ebx
c0023a39:	5e                   	pop    %esi
c0023a3a:	c3                   	ret    

c0023a3b <free>:
{
c0023a3b:	55                   	push   %ebp
c0023a3c:	57                   	push   %edi
c0023a3d:	56                   	push   %esi
c0023a3e:	53                   	push   %ebx
c0023a3f:	83 ec 2c             	sub    $0x2c,%esp
c0023a42:	8b 5c 24 40          	mov    0x40(%esp),%ebx
  if (p != NULL)
c0023a46:	85 db                	test   %ebx,%ebx
c0023a48:	0f 84 ca 00 00 00    	je     c0023b18 <free+0xdd>
      struct arena *a = block_to_arena (b);
c0023a4e:	89 d8                	mov    %ebx,%eax
c0023a50:	e8 91 fc ff ff       	call   c00236e6 <block_to_arena>
c0023a55:	89 c7                	mov    %eax,%edi
      struct desc *d = a->desc;
c0023a57:	8b 70 04             	mov    0x4(%eax),%esi
      if (d != NULL) 
c0023a5a:	85 f6                	test   %esi,%esi
c0023a5c:	0f 84 a7 00 00 00    	je     c0023b09 <free+0xce>
          memset (b, 0xcc, d->block_size);
c0023a62:	8b 06                	mov    (%esi),%eax
c0023a64:	89 44 24 08          	mov    %eax,0x8(%esp)
c0023a68:	c7 44 24 04 cc 00 00 	movl   $0xcc,0x4(%esp)
c0023a6f:	00 
c0023a70:	89 1c 24             	mov    %ebx,(%esp)
c0023a73:	e8 b9 43 00 00       	call   c0027e31 <memset>
          lock_acquire (&d->lock);
c0023a78:	8d 6e 18             	lea    0x18(%esi),%ebp
c0023a7b:	89 2c 24             	mov    %ebp,(%esp)
c0023a7e:	e8 67 f2 ff ff       	call   c0022cea <lock_acquire>
          list_push_front (&d->free_list, &b->free_elem);
c0023a83:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023a87:	8d 46 08             	lea    0x8(%esi),%eax
c0023a8a:	89 04 24             	mov    %eax,(%esp)
c0023a8d:	e8 0c 55 00 00       	call   c0028f9e <list_push_front>
          if (++a->free_cnt >= d->blocks_per_arena) 
c0023a92:	8b 47 08             	mov    0x8(%edi),%eax
c0023a95:	83 c0 01             	add    $0x1,%eax
c0023a98:	89 47 08             	mov    %eax,0x8(%edi)
c0023a9b:	8b 56 04             	mov    0x4(%esi),%edx
c0023a9e:	39 d0                	cmp    %edx,%eax
c0023aa0:	72 5d                	jb     c0023aff <free+0xc4>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023aa2:	39 d0                	cmp    %edx,%eax
c0023aa4:	75 0c                	jne    c0023ab2 <free+0x77>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023aa6:	bb 00 00 00 00       	mov    $0x0,%ebx
c0023aab:	85 c0                	test   %eax,%eax
c0023aad:	75 2f                	jne    c0023ade <free+0xa3>
c0023aaf:	90                   	nop
c0023ab0:	eb 45                	jmp    c0023af7 <free+0xbc>
              ASSERT (a->free_cnt == d->blocks_per_arena);
c0023ab2:	c7 44 24 10 80 ec 02 	movl   $0xc002ec80,0x10(%esp)
c0023ab9:	c0 
c0023aba:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023ac1:	c0 
c0023ac2:	c7 44 24 08 a2 d2 02 	movl   $0xc002d2a2,0x8(%esp)
c0023ac9:	c0 
c0023aca:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0023ad1:	00 
c0023ad2:	c7 04 24 8e eb 02 c0 	movl   $0xc002eb8e,(%esp)
c0023ad9:	e8 95 4e 00 00       	call   c0028973 <debug_panic>
                  struct block *b = arena_to_block (a, i);
c0023ade:	89 da                	mov    %ebx,%edx
c0023ae0:	89 f8                	mov    %edi,%eax
c0023ae2:	e8 59 fb ff ff       	call   c0023640 <arena_to_block>
                  list_remove (&b->free_elem);
c0023ae7:	89 04 24             	mov    %eax,(%esp)
c0023aea:	e8 f5 54 00 00       	call   c0028fe4 <list_remove>
              for (i = 0; i < d->blocks_per_arena; i++) 
c0023aef:	83 c3 01             	add    $0x1,%ebx
c0023af2:	39 5e 04             	cmp    %ebx,0x4(%esi)
c0023af5:	77 e7                	ja     c0023ade <free+0xa3>
              palloc_free_page (a);
c0023af7:	89 3c 24             	mov    %edi,(%esp)
c0023afa:	e8 21 fb ff ff       	call   c0023620 <palloc_free_page>
          lock_release (&d->lock);
c0023aff:	89 2c 24             	mov    %ebp,(%esp)
c0023b02:	e8 ad f3 ff ff       	call   c0022eb4 <lock_release>
c0023b07:	eb 0f                	jmp    c0023b18 <free+0xdd>
          palloc_free_multiple (a, a->free_cnt);
c0023b09:	8b 40 08             	mov    0x8(%eax),%eax
c0023b0c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0023b10:	89 3c 24             	mov    %edi,(%esp)
c0023b13:	e8 b9 f9 ff ff       	call   c00234d1 <palloc_free_multiple>
}
c0023b18:	83 c4 2c             	add    $0x2c,%esp
c0023b1b:	5b                   	pop    %ebx
c0023b1c:	5e                   	pop    %esi
c0023b1d:	5f                   	pop    %edi
c0023b1e:	5d                   	pop    %ebp
c0023b1f:	c3                   	ret    

c0023b20 <realloc>:
{
c0023b20:	57                   	push   %edi
c0023b21:	56                   	push   %esi
c0023b22:	53                   	push   %ebx
c0023b23:	83 ec 10             	sub    $0x10,%esp
c0023b26:	8b 7c 24 20          	mov    0x20(%esp),%edi
c0023b2a:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (new_size == 0) 
c0023b2e:	85 db                	test   %ebx,%ebx
c0023b30:	75 0f                	jne    c0023b41 <realloc+0x21>
      free (old_block);
c0023b32:	89 3c 24             	mov    %edi,(%esp)
c0023b35:	e8 01 ff ff ff       	call   c0023a3b <free>
      return NULL;
c0023b3a:	b8 00 00 00 00       	mov    $0x0,%eax
c0023b3f:	eb 57                	jmp    c0023b98 <realloc+0x78>
      void *new_block = malloc (new_size);
c0023b41:	89 1c 24             	mov    %ebx,(%esp)
c0023b44:	e8 6b fd ff ff       	call   c00238b4 <malloc>
c0023b49:	89 c6                	mov    %eax,%esi
      if (old_block != NULL && new_block != NULL)
c0023b4b:	85 c0                	test   %eax,%eax
c0023b4d:	74 47                	je     c0023b96 <realloc+0x76>
c0023b4f:	85 ff                	test   %edi,%edi
c0023b51:	74 43                	je     c0023b96 <realloc+0x76>
  struct arena *a = block_to_arena (b);
c0023b53:	89 f8                	mov    %edi,%eax
c0023b55:	e8 8c fb ff ff       	call   c00236e6 <block_to_arena>
  struct desc *d = a->desc;
c0023b5a:	8b 50 04             	mov    0x4(%eax),%edx
  return d != NULL ? d->block_size : PGSIZE * a->free_cnt - pg_ofs (block);
c0023b5d:	85 d2                	test   %edx,%edx
c0023b5f:	74 04                	je     c0023b65 <realloc+0x45>
c0023b61:	8b 02                	mov    (%edx),%eax
c0023b63:	eb 10                	jmp    c0023b75 <realloc+0x55>
c0023b65:	8b 40 08             	mov    0x8(%eax),%eax
c0023b68:	c1 e0 0c             	shl    $0xc,%eax
c0023b6b:	89 fa                	mov    %edi,%edx
c0023b6d:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
c0023b73:	29 d0                	sub    %edx,%eax
          size_t min_size = new_size < old_size ? new_size : old_size;
c0023b75:	39 d8                	cmp    %ebx,%eax
c0023b77:	0f 46 d8             	cmovbe %eax,%ebx
          memcpy (new_block, old_block, min_size);
c0023b7a:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0023b7e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0023b82:	89 34 24             	mov    %esi,(%esp)
c0023b85:	e8 c6 3c 00 00       	call   c0027850 <memcpy>
          free (old_block);
c0023b8a:	89 3c 24             	mov    %edi,(%esp)
c0023b8d:	e8 a9 fe ff ff       	call   c0023a3b <free>
      return new_block;
c0023b92:	89 f0                	mov    %esi,%eax
c0023b94:	eb 02                	jmp    c0023b98 <realloc+0x78>
c0023b96:	89 f0                	mov    %esi,%eax
}
c0023b98:	83 c4 10             	add    $0x10,%esp
c0023b9b:	5b                   	pop    %ebx
c0023b9c:	5e                   	pop    %esi
c0023b9d:	5f                   	pop    %edi
c0023b9e:	c3                   	ret    

c0023b9f <power>:
#include "threads/switch.h"
#include "threads/synch.h"
#include "threads/vaddr.h"
int f;
int power(int base, int pow)
{
c0023b9f:	83 ec 1c             	sub    $0x1c,%esp
c0023ba2:	8b 54 24 24          	mov    0x24(%esp),%edx
  if (pow == 0)
    return 1;
c0023ba6:	b8 01 00 00 00       	mov    $0x1,%eax
  if (pow == 0)
c0023bab:	85 d2                	test   %edx,%edx
c0023bad:	74 46                	je     c0023bf5 <power+0x56>
  else if (pow % 2 == 0)
c0023baf:	f6 c2 01             	test   $0x1,%dl
c0023bb2:	75 1e                	jne    c0023bd2 <power+0x33>
    return power(base, pow / 2) * power(base, pow / 2);
c0023bb4:	89 d0                	mov    %edx,%eax
c0023bb6:	c1 e8 1f             	shr    $0x1f,%eax
c0023bb9:	01 c2                	add    %eax,%edx
c0023bbb:	d1 fa                	sar    %edx
c0023bbd:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023bc1:	8b 44 24 20          	mov    0x20(%esp),%eax
c0023bc5:	89 04 24             	mov    %eax,(%esp)
c0023bc8:	e8 d2 ff ff ff       	call   c0023b9f <power>
c0023bcd:	0f af c0             	imul   %eax,%eax
c0023bd0:	eb 23                	jmp    c0023bf5 <power+0x56>
  else
    return base * power(base, pow / 2) * power(base, pow / 2);
c0023bd2:	89 d0                	mov    %edx,%eax
c0023bd4:	c1 e8 1f             	shr    $0x1f,%eax
c0023bd7:	01 c2                	add    %eax,%edx
c0023bd9:	d1 fa                	sar    %edx
c0023bdb:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023bdf:	8b 44 24 20          	mov    0x20(%esp),%eax
c0023be3:	89 04 24             	mov    %eax,(%esp)
c0023be6:	e8 b4 ff ff ff       	call   c0023b9f <power>
c0023beb:	89 c2                	mov    %eax,%edx
c0023bed:	0f af 54 24 20       	imul   0x20(%esp),%edx
c0023bf2:	0f af c2             	imul   %edx,%eax
}
c0023bf5:	83 c4 1c             	add    $0x1c,%esp
c0023bf8:	c3                   	ret    

c0023bf9 <convertNtoFixedPoint>:

//Convert n to fixed point:    n * f
 int convertNtoFixedPoint(int n)
{
    return n * f;
c0023bf9:	8b 44 24 04          	mov    0x4(%esp),%eax
c0023bfd:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
}
c0023c04:	c3                   	ret    

c0023c05 <convertXtoInt>:

//Convert x to integer (rounding toward zero):    x / f
 int convertXtoInt(int x)
{
c0023c05:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / f;
c0023c09:	99                   	cltd   
c0023c0a:	f7 3d bc 7b 03 c0    	idivl  0xc0037bbc
}
c0023c10:	c3                   	ret    

c0023c11 <convertXtoIntRoundNear>:

//    (x + f / 2) / f if x >= 0,
// (x - f / 2) / f if x <= 0.
 int convertXtoIntRoundNear(int x)
{
c0023c11:	8b 44 24 04          	mov    0x4(%esp),%eax
    if(x >= 0)
c0023c15:	85 c0                	test   %eax,%eax
c0023c17:	78 15                	js     c0023c2e <convertXtoIntRoundNear+0x1d>
        return (x + f / 2) / f;
c0023c19:	8b 0d bc 7b 03 c0    	mov    0xc0037bbc,%ecx
c0023c1f:	89 ca                	mov    %ecx,%edx
c0023c21:	c1 ea 1f             	shr    $0x1f,%edx
c0023c24:	01 ca                	add    %ecx,%edx
c0023c26:	d1 fa                	sar    %edx
c0023c28:	01 d0                	add    %edx,%eax
c0023c2a:	99                   	cltd   
c0023c2b:	f7 f9                	idiv   %ecx
c0023c2d:	c3                   	ret    
    else
        return (x - f / 2) / f;
c0023c2e:	8b 0d bc 7b 03 c0    	mov    0xc0037bbc,%ecx
c0023c34:	89 ca                	mov    %ecx,%edx
c0023c36:	c1 ea 1f             	shr    $0x1f,%edx
c0023c39:	01 ca                	add    %ecx,%edx
c0023c3b:	d1 fa                	sar    %edx
c0023c3d:	29 d0                	sub    %edx,%eax
c0023c3f:	99                   	cltd   
c0023c40:	f7 f9                	idiv   %ecx
}
c0023c42:	c3                   	ret    

c0023c43 <addXandY>:

//x + y
 int addXandY(int x, int y)
{
    return x + y;
c0023c43:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023c47:	03 44 24 04          	add    0x4(%esp),%eax
}
c0023c4b:	c3                   	ret    

c0023c4c <subtractYfromX>:

// x - y
 int subtractYfromX(int x, int y)
{
    return x - y;
c0023c4c:	8b 44 24 04          	mov    0x4(%esp),%eax
c0023c50:	2b 44 24 08          	sub    0x8(%esp),%eax
}
c0023c54:	c3                   	ret    

c0023c55 <addXandN>:

//Add x and n:    x + n * f
 int addXandN(int x, int n)
{
    return x + (n * f);
c0023c55:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023c59:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
c0023c60:	03 44 24 04          	add    0x4(%esp),%eax
}
c0023c64:	c3                   	ret    

c0023c65 <subNfromX>:

//Subtract n from x:    x - n * f
 int subNfromX(int x, int n)
{
    return x - (n * f);
c0023c65:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023c69:	0f af 05 bc 7b 03 c0 	imul   0xc0037bbc,%eax
c0023c70:	8b 54 24 04          	mov    0x4(%esp),%edx
c0023c74:	29 c2                	sub    %eax,%edx
c0023c76:	89 d0                	mov    %edx,%eax
}
c0023c78:	c3                   	ret    

c0023c79 <multXbyY>:

//Multiply x by y:    ((int64_t) x) * y / f
 int multXbyY(int x, int y)
{
c0023c79:	57                   	push   %edi
c0023c7a:	56                   	push   %esi
c0023c7b:	53                   	push   %ebx
c0023c7c:	83 ec 10             	sub    $0x10,%esp
c0023c7f:	8b 54 24 20          	mov    0x20(%esp),%edx
c0023c83:	8b 44 24 24          	mov    0x24(%esp),%eax
    return ((int64_t) x) * y / f;
c0023c87:	89 d7                	mov    %edx,%edi
c0023c89:	c1 ff 1f             	sar    $0x1f,%edi
c0023c8c:	89 c3                	mov    %eax,%ebx
c0023c8e:	c1 fb 1f             	sar    $0x1f,%ebx
c0023c91:	89 fe                	mov    %edi,%esi
c0023c93:	0f af f0             	imul   %eax,%esi
c0023c96:	89 d9                	mov    %ebx,%ecx
c0023c98:	0f af ca             	imul   %edx,%ecx
c0023c9b:	01 f1                	add    %esi,%ecx
c0023c9d:	f7 e2                	mul    %edx
c0023c9f:	01 ca                	add    %ecx,%edx
c0023ca1:	8b 0d bc 7b 03 c0    	mov    0xc0037bbc,%ecx
c0023ca7:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0023cab:	89 cb                	mov    %ecx,%ebx
c0023cad:	c1 fb 1f             	sar    $0x1f,%ebx
c0023cb0:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0023cb4:	89 04 24             	mov    %eax,(%esp)
c0023cb7:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023cbb:	e8 13 46 00 00       	call   c00282d3 <__divdi3>
}
c0023cc0:	83 c4 10             	add    $0x10,%esp
c0023cc3:	5b                   	pop    %ebx
c0023cc4:	5e                   	pop    %esi
c0023cc5:	5f                   	pop    %edi
c0023cc6:	c3                   	ret    

c0023cc7 <multXbyN>:

//Multiply x by n:    x * n
 int multXbyN(int x, int n)
{
    return x * n;
c0023cc7:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023ccb:	0f af 44 24 04       	imul   0x4(%esp),%eax
}
c0023cd0:	c3                   	ret    

c0023cd1 <divXbyY>:

//Divide x by y:    ((int64_t) x) * f / y
 int divXbyY(int x, int y)
{
c0023cd1:	57                   	push   %edi
c0023cd2:	56                   	push   %esi
c0023cd3:	53                   	push   %ebx
c0023cd4:	83 ec 10             	sub    $0x10,%esp
c0023cd7:	8b 54 24 20          	mov    0x20(%esp),%edx
    return ((int64_t) x) * f / y;
c0023cdb:	89 d7                	mov    %edx,%edi
c0023cdd:	c1 ff 1f             	sar    $0x1f,%edi
c0023ce0:	a1 bc 7b 03 c0       	mov    0xc0037bbc,%eax
c0023ce5:	89 c3                	mov    %eax,%ebx
c0023ce7:	c1 fb 1f             	sar    $0x1f,%ebx
c0023cea:	89 fe                	mov    %edi,%esi
c0023cec:	0f af f0             	imul   %eax,%esi
c0023cef:	89 d9                	mov    %ebx,%ecx
c0023cf1:	0f af ca             	imul   %edx,%ecx
c0023cf4:	01 f1                	add    %esi,%ecx
c0023cf6:	f7 e2                	mul    %edx
c0023cf8:	01 ca                	add    %ecx,%edx
c0023cfa:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c0023cfe:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0023d02:	89 cb                	mov    %ecx,%ebx
c0023d04:	c1 fb 1f             	sar    $0x1f,%ebx
c0023d07:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0023d0b:	89 04 24             	mov    %eax,(%esp)
c0023d0e:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023d12:	e8 bc 45 00 00       	call   c00282d3 <__divdi3>
}
c0023d17:	83 c4 10             	add    $0x10,%esp
c0023d1a:	5b                   	pop    %ebx
c0023d1b:	5e                   	pop    %esi
c0023d1c:	5f                   	pop    %edi
c0023d1d:	c3                   	ret    

c0023d1e <divXbyN>:

//Divide x by n:    x / n
 int divXbyN(int x, int n)
{
c0023d1e:	8b 44 24 04          	mov    0x4(%esp),%eax
    return x / n;
c0023d22:	99                   	cltd   
c0023d23:	f7 7c 24 08          	idivl  0x8(%esp)
c0023d27:	c3                   	ret    

c0023d28 <pit_configure_channel>:
     - Other modes are less useful.

   FREQUENCY is the number of periods per second, in Hz. */
void
pit_configure_channel (int channel, int mode, int frequency)
{
c0023d28:	57                   	push   %edi
c0023d29:	56                   	push   %esi
c0023d2a:	53                   	push   %ebx
c0023d2b:	83 ec 20             	sub    $0x20,%esp
c0023d2e:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0023d32:	8b 7c 24 34          	mov    0x34(%esp),%edi
c0023d36:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  uint16_t count;
  enum intr_level old_level;

  ASSERT (channel == 0 || channel == 2);
c0023d3a:	f7 c3 fd ff ff ff    	test   $0xfffffffd,%ebx
c0023d40:	74 2c                	je     c0023d6e <pit_configure_channel+0x46>
c0023d42:	c7 44 24 10 a3 ec 02 	movl   $0xc002eca3,0x10(%esp)
c0023d49:	c0 
c0023d4a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023d51:	c0 
c0023d52:	c7 44 24 08 d1 d2 02 	movl   $0xc002d2d1,0x8(%esp)
c0023d59:	c0 
c0023d5a:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
c0023d61:	00 
c0023d62:	c7 04 24 c0 ec 02 c0 	movl   $0xc002ecc0,(%esp)
c0023d69:	e8 05 4c 00 00       	call   c0028973 <debug_panic>
  ASSERT (mode == 2 || mode == 3);
c0023d6e:	8d 47 fe             	lea    -0x2(%edi),%eax
c0023d71:	83 f8 01             	cmp    $0x1,%eax
c0023d74:	76 2c                	jbe    c0023da2 <pit_configure_channel+0x7a>
c0023d76:	c7 44 24 10 d4 ec 02 	movl   $0xc002ecd4,0x10(%esp)
c0023d7d:	c0 
c0023d7e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0023d85:	c0 
c0023d86:	c7 44 24 08 d1 d2 02 	movl   $0xc002d2d1,0x8(%esp)
c0023d8d:	c0 
c0023d8e:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c0023d95:	00 
c0023d96:	c7 04 24 c0 ec 02 c0 	movl   $0xc002ecc0,(%esp)
c0023d9d:	e8 d1 4b 00 00       	call   c0028973 <debug_panic>
    {
      /* Frequency is too low: the quotient would overflow the
         16-bit counter.  Force it to 0, which the PIT treats as
         65536, the highest possible count.  This yields a 18.2
         Hz timer, approximately. */
      count = 0;
c0023da2:	be 00 00 00 00       	mov    $0x0,%esi
  if (frequency < 19)
c0023da7:	83 f9 12             	cmp    $0x12,%ecx
c0023daa:	7e 20                	jle    c0023dcc <pit_configure_channel+0xa4>
      /* Frequency is too high: the quotient would underflow to
         0, which the PIT would interpret as 65536.  A count of 1
         is illegal in mode 2, so we force it to 2, which yields
         a 596.590 kHz timer, approximately.  (This timer rate is
         probably too fast to be useful anyhow.) */
      count = 2;
c0023dac:	be 02 00 00 00       	mov    $0x2,%esi
  else if (frequency > PIT_HZ)
c0023db1:	81 f9 dc 34 12 00    	cmp    $0x1234dc,%ecx
c0023db7:	7f 13                	jg     c0023dcc <pit_configure_channel+0xa4>
    }
  else
    count = (PIT_HZ + frequency / 2) / frequency;
c0023db9:	89 c8                	mov    %ecx,%eax
c0023dbb:	c1 e8 1f             	shr    $0x1f,%eax
c0023dbe:	01 c8                	add    %ecx,%eax
c0023dc0:	d1 f8                	sar    %eax
c0023dc2:	05 dc 34 12 00       	add    $0x1234dc,%eax
c0023dc7:	99                   	cltd   
c0023dc8:	f7 f9                	idiv   %ecx
c0023dca:	89 c6                	mov    %eax,%esi

  /* Configure the PIT mode and load its counters. */
  old_level = intr_disable ();
c0023dcc:	e8 7e da ff ff       	call   c002184f <intr_disable>
c0023dd1:	89 c1                	mov    %eax,%ecx
  outb (PIT_PORT_CONTROL, (channel << 6) | 0x30 | (mode << 1));
c0023dd3:	8d 04 3f             	lea    (%edi,%edi,1),%eax
c0023dd6:	83 c8 30             	or     $0x30,%eax
c0023dd9:	89 da                	mov    %ebx,%edx
c0023ddb:	c1 e2 06             	shl    $0x6,%edx
c0023dde:	09 d0                	or     %edx,%eax
c0023de0:	e6 43                	out    %al,$0x43
  outb (PIT_PORT_COUNTER (channel), count);
c0023de2:	8d 53 40             	lea    0x40(%ebx),%edx
c0023de5:	89 f0                	mov    %esi,%eax
c0023de7:	ee                   	out    %al,(%dx)
  outb (PIT_PORT_COUNTER (channel), count >> 8);
c0023de8:	89 f0                	mov    %esi,%eax
c0023dea:	66 c1 e8 08          	shr    $0x8,%ax
c0023dee:	ee                   	out    %al,(%dx)
  intr_set_level (old_level);
c0023def:	89 0c 24             	mov    %ecx,(%esp)
c0023df2:	e8 5f da ff ff       	call   c0021856 <intr_set_level>
}
c0023df7:	83 c4 20             	add    $0x20,%esp
c0023dfa:	5b                   	pop    %ebx
c0023dfb:	5e                   	pop    %esi
c0023dfc:	5f                   	pop    %edi
c0023dfd:	c3                   	ret    
c0023dfe:	90                   	nop
c0023dff:	90                   	nop

c0023e00 <compareSleep>:
        return true;
    }
    //then check if the wakeup times are equal
    else if (tPointer1->wakeup == tPointer1->wakeup) {
        //if they are, then comapare using priority
        if (tPointer1->priority > tPointer2->priority) {
c0023e00:	8b 44 24 08          	mov    0x8(%esp),%eax
c0023e04:	8b 54 24 04          	mov    0x4(%esp),%edx
c0023e08:	8b 40 f4             	mov    -0xc(%eax),%eax
c0023e0b:	39 42 f4             	cmp    %eax,-0xc(%edx)
c0023e0e:	0f 9f c0             	setg   %al
        }
    }
    //if all tests fail, return false
    return false;

}
c0023e11:	c3                   	ret    

c0023e12 <busy_wait>:
   affect timings, so that if this function was inlined
   differently in different places the results would be difficult
   to predict. */
static void NO_INLINE
busy_wait (int64_t loops) 
{
c0023e12:	53                   	push   %ebx
  while (loops-- > 0)
c0023e13:	89 c1                	mov    %eax,%ecx
c0023e15:	89 d3                	mov    %edx,%ebx
c0023e17:	83 c1 ff             	add    $0xffffffff,%ecx
c0023e1a:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023e1d:	85 d2                	test   %edx,%edx
c0023e1f:	78 18                	js     c0023e39 <busy_wait+0x27>
c0023e21:	85 d2                	test   %edx,%edx
c0023e23:	7f 05                	jg     c0023e2a <busy_wait+0x18>
c0023e25:	83 f8 00             	cmp    $0x0,%eax
c0023e28:	76 0f                	jbe    c0023e39 <busy_wait+0x27>
c0023e2a:	83 c1 ff             	add    $0xffffffff,%ecx
c0023e2d:	83 d3 ff             	adc    $0xffffffff,%ebx
c0023e30:	89 c8                	mov    %ecx,%eax
c0023e32:	21 d8                	and    %ebx,%eax
c0023e34:	83 f8 ff             	cmp    $0xffffffff,%eax
c0023e37:	75 f1                	jne    c0023e2a <busy_wait+0x18>
    barrier ();
}
c0023e39:	5b                   	pop    %ebx
c0023e3a:	c3                   	ret    

c0023e3b <too_many_loops>:
{
c0023e3b:	55                   	push   %ebp
c0023e3c:	57                   	push   %edi
c0023e3d:	56                   	push   %esi
c0023e3e:	53                   	push   %ebx
c0023e3f:	83 ec 04             	sub    $0x4,%esp
  int64_t start = ticks;
c0023e42:	8b 2d 70 77 03 c0    	mov    0xc0037770,%ebp
c0023e48:	8b 3d 74 77 03 c0    	mov    0xc0037774,%edi
  while (ticks == start)
c0023e4e:	8b 35 70 77 03 c0    	mov    0xc0037770,%esi
c0023e54:	8b 1d 74 77 03 c0    	mov    0xc0037774,%ebx
c0023e5a:	89 d9                	mov    %ebx,%ecx
c0023e5c:	31 f9                	xor    %edi,%ecx
c0023e5e:	89 f2                	mov    %esi,%edx
c0023e60:	31 ea                	xor    %ebp,%edx
c0023e62:	09 d1                	or     %edx,%ecx
c0023e64:	74 e8                	je     c0023e4e <too_many_loops+0x13>
  busy_wait (loops);
c0023e66:	ba 00 00 00 00       	mov    $0x0,%edx
c0023e6b:	e8 a2 ff ff ff       	call   c0023e12 <busy_wait>
  return start != ticks;
c0023e70:	33 35 70 77 03 c0    	xor    0xc0037770,%esi
c0023e76:	33 1d 74 77 03 c0    	xor    0xc0037774,%ebx
c0023e7c:	09 de                	or     %ebx,%esi
c0023e7e:	0f 95 c0             	setne  %al
}
c0023e81:	83 c4 04             	add    $0x4,%esp
c0023e84:	5b                   	pop    %ebx
c0023e85:	5e                   	pop    %esi
c0023e86:	5f                   	pop    %edi
c0023e87:	5d                   	pop    %ebp
c0023e88:	c3                   	ret    

c0023e89 <timer_interrupt>:
{
c0023e89:	56                   	push   %esi
c0023e8a:	53                   	push   %ebx
c0023e8b:	83 ec 14             	sub    $0x14,%esp
  ticks++;
c0023e8e:	83 05 70 77 03 c0 01 	addl   $0x1,0xc0037770
c0023e95:	83 15 74 77 03 c0 00 	adcl   $0x0,0xc0037774
  struct list_elem *e = list_begin(&sleep_list);
c0023e9c:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023ea3:	e8 e9 4b 00 00       	call   c0028a91 <list_begin>
c0023ea8:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023eaa:	eb 39                	jmp    c0023ee5 <timer_interrupt+0x5c>
      if(ticks >= t->wakeup)
c0023eac:	8b 53 0c             	mov    0xc(%ebx),%edx
c0023eaf:	8b 43 10             	mov    0x10(%ebx),%eax
c0023eb2:	3b 05 74 77 03 c0    	cmp    0xc0037774,%eax
c0023eb8:	7f 21                	jg     c0023edb <timer_interrupt+0x52>
c0023eba:	7c 08                	jl     c0023ec4 <timer_interrupt+0x3b>
c0023ebc:	3b 15 70 77 03 c0    	cmp    0xc0037770,%edx
c0023ec2:	77 17                	ja     c0023edb <timer_interrupt+0x52>
          e = list_remove(&t->elem);
c0023ec4:	8d 73 d8             	lea    -0x28(%ebx),%esi
c0023ec7:	89 1c 24             	mov    %ebx,(%esp)
c0023eca:	e8 15 51 00 00       	call   c0028fe4 <list_remove>
c0023ecf:	89 c3                	mov    %eax,%ebx
          thread_unblock(t);
c0023ed1:	89 34 24             	mov    %esi,(%esp)
c0023ed4:	e8 f1 cc ff ff       	call   c0020bca <thread_unblock>
c0023ed9:	eb 0a                	jmp    c0023ee5 <timer_interrupt+0x5c>
          e = list_next(e);
c0023edb:	89 1c 24             	mov    %ebx,(%esp)
c0023ede:	e8 ec 4b 00 00       	call   c0028acf <list_next>
c0023ee3:	89 c3                	mov    %eax,%ebx
  while(e != list_end(&sleep_list))
c0023ee5:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0023eec:	e8 32 4c 00 00       	call   c0028b23 <list_end>
c0023ef1:	39 d8                	cmp    %ebx,%eax
c0023ef3:	75 b7                	jne    c0023eac <timer_interrupt+0x23>
  if(thread_mlfqs)
c0023ef5:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c0023efc:	0f 84 fd 00 00 00    	je     c0023fff <timer_interrupt+0x176>
    if(thread_current() != get_idle_thread()){
c0023f02:	e8 9c cd ff ff       	call   c0020ca3 <thread_current>
c0023f07:	89 c3                	mov    %eax,%ebx
c0023f09:	e8 88 d0 ff ff       	call   c0020f96 <get_idle_thread>
c0023f0e:	39 c3                	cmp    %eax,%ebx
c0023f10:	74 22                	je     c0023f34 <timer_interrupt+0xab>
      thread_current()->recent_cpu = addXandN(thread_current()->recent_cpu,1);
c0023f12:	e8 8c cd ff ff       	call   c0020ca3 <thread_current>
c0023f17:	89 c3                	mov    %eax,%ebx
c0023f19:	e8 85 cd ff ff       	call   c0020ca3 <thread_current>
c0023f1e:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0023f25:	00 
c0023f26:	8b 40 58             	mov    0x58(%eax),%eax
c0023f29:	89 04 24             	mov    %eax,(%esp)
c0023f2c:	e8 24 fd ff ff       	call   c0023c55 <addXandN>
c0023f31:	89 43 58             	mov    %eax,0x58(%ebx)
    if(ticks % TIMER_FREQ == 0)
c0023f34:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0023f3b:	00 
c0023f3c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0023f43:	00 
c0023f44:	a1 70 77 03 c0       	mov    0xc0037770,%eax
c0023f49:	8b 15 74 77 03 c0    	mov    0xc0037774,%edx
c0023f4f:	89 04 24             	mov    %eax,(%esp)
c0023f52:	89 54 24 04          	mov    %edx,0x4(%esp)
c0023f56:	e8 9b 43 00 00       	call   c00282f6 <__moddi3>
c0023f5b:	09 c2                	or     %eax,%edx
c0023f5d:	75 7e                	jne    c0023fdd <timer_interrupt+0x154>
      setLoadAv(multXbyY(divXbyN(convertNtoFixedPoint(59),60),getLoadAv()) + multXbyN(divXbyN(convertNtoFixedPoint(1),60),get_ready_threads()));
c0023f5f:	e8 22 d0 ff ff       	call   c0020f86 <getLoadAv>
c0023f64:	89 c3                	mov    %eax,%ebx
c0023f66:	c7 04 24 3b 00 00 00 	movl   $0x3b,(%esp)
c0023f6d:	e8 87 fc ff ff       	call   c0023bf9 <convertNtoFixedPoint>
c0023f72:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c0023f79:	00 
c0023f7a:	89 04 24             	mov    %eax,(%esp)
c0023f7d:	e8 9c fd ff ff       	call   c0023d1e <divXbyN>
c0023f82:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0023f86:	89 04 24             	mov    %eax,(%esp)
c0023f89:	e8 eb fc ff ff       	call   c0023c79 <multXbyY>
c0023f8e:	89 c3                	mov    %eax,%ebx
c0023f90:	e8 ad cf ff ff       	call   c0020f42 <get_ready_threads>
c0023f95:	89 c6                	mov    %eax,%esi
c0023f97:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0023f9e:	e8 56 fc ff ff       	call   c0023bf9 <convertNtoFixedPoint>
c0023fa3:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c0023faa:	00 
c0023fab:	89 04 24             	mov    %eax,(%esp)
c0023fae:	e8 6b fd ff ff       	call   c0023d1e <divXbyN>
c0023fb3:	89 74 24 04          	mov    %esi,0x4(%esp)
c0023fb7:	89 04 24             	mov    %eax,(%esp)
c0023fba:	e8 08 fd ff ff       	call   c0023cc7 <multXbyN>
c0023fbf:	01 c3                	add    %eax,%ebx
c0023fc1:	89 1c 24             	mov    %ebx,(%esp)
c0023fc4:	e8 c3 cf ff ff       	call   c0020f8c <setLoadAv>
      thread_foreach (calculate_recent_cpu, 0);
c0023fc9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023fd0:	00 
c0023fd1:	c7 04 24 6d 0e 02 c0 	movl   $0xc0020e6d,(%esp)
c0023fd8:	e8 a7 cd ff ff       	call   c0020d84 <thread_foreach>
     if(ticks % 4 == 0) //--- responsible for test mlfqs-fair-20 passing
c0023fdd:	f6 05 70 77 03 c0 03 	testb  $0x3,0xc0037770
c0023fe4:	75 19                	jne    c0023fff <timer_interrupt+0x176>
       thread_foreach (calcPrio, 0);
c0023fe6:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0023fed:	00 
c0023fee:	c7 04 24 c1 0e 02 c0 	movl   $0xc0020ec1,(%esp)
c0023ff5:	e8 8a cd ff ff       	call   c0020d84 <thread_foreach>
       intr_yield_on_return ();
c0023ffa:	e8 ba da ff ff       	call   c0021ab9 <intr_yield_on_return>
  thread_tick (); 
c0023fff:	e8 1a cd ff ff       	call   c0020d1e <thread_tick>
}
c0024004:	83 c4 14             	add    $0x14,%esp
c0024007:	5b                   	pop    %ebx
c0024008:	5e                   	pop    %esi
c0024009:	c3                   	ret    

c002400a <real_time_delay>:
}

/* Busy-wait for approximately NUM/DENOM seconds. */
static void
real_time_delay (int64_t num, int32_t denom)
{
c002400a:	55                   	push   %ebp
c002400b:	57                   	push   %edi
c002400c:	56                   	push   %esi
c002400d:	53                   	push   %ebx
c002400e:	83 ec 2c             	sub    $0x2c,%esp
c0024011:	89 c7                	mov    %eax,%edi
c0024013:	89 d6                	mov    %edx,%esi
c0024015:	89 cb                	mov    %ecx,%ebx
  /* Scale the numerator and denominator down by 1000 to avoid
     the possibility of overflow. */
  ASSERT (denom % 1000 == 0);
c0024017:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c002401c:	89 c8                	mov    %ecx,%eax
c002401e:	f7 ea                	imul   %edx
c0024020:	c1 fa 06             	sar    $0x6,%edx
c0024023:	89 c8                	mov    %ecx,%eax
c0024025:	c1 f8 1f             	sar    $0x1f,%eax
c0024028:	29 c2                	sub    %eax,%edx
c002402a:	69 d2 e8 03 00 00    	imul   $0x3e8,%edx,%edx
c0024030:	39 d1                	cmp    %edx,%ecx
c0024032:	74 2c                	je     c0024060 <real_time_delay+0x56>
c0024034:	c7 44 24 10 eb ec 02 	movl   $0xc002eceb,0x10(%esp)
c002403b:	c0 
c002403c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024043:	c0 
c0024044:	c7 44 24 08 e7 d2 02 	movl   $0xc002d2e7,0x8(%esp)
c002404b:	c0 
c002404c:	c7 44 24 04 46 01 00 	movl   $0x146,0x4(%esp)
c0024053:	00 
c0024054:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c002405b:	e8 13 49 00 00       	call   c0028973 <debug_panic>
  busy_wait (loops_per_tick * num / 1000 * TIMER_FREQ / (denom / 1000)); 
c0024060:	a1 68 77 03 c0       	mov    0xc0037768,%eax
c0024065:	0f af f0             	imul   %eax,%esi
c0024068:	f7 e7                	mul    %edi
c002406a:	01 f2                	add    %esi,%edx
c002406c:	c7 44 24 08 e8 03 00 	movl   $0x3e8,0x8(%esp)
c0024073:	00 
c0024074:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002407b:	00 
c002407c:	89 04 24             	mov    %eax,(%esp)
c002407f:	89 54 24 04          	mov    %edx,0x4(%esp)
c0024083:	e8 4b 42 00 00       	call   c00282d3 <__divdi3>
c0024088:	6b ea 64             	imul   $0x64,%edx,%ebp
c002408b:	b9 64 00 00 00       	mov    $0x64,%ecx
c0024090:	f7 e1                	mul    %ecx
c0024092:	89 c6                	mov    %eax,%esi
c0024094:	89 d7                	mov    %edx,%edi
c0024096:	01 ef                	add    %ebp,%edi
c0024098:	ba d3 4d 62 10       	mov    $0x10624dd3,%edx
c002409d:	89 d8                	mov    %ebx,%eax
c002409f:	f7 ea                	imul   %edx
c00240a1:	c1 fa 06             	sar    $0x6,%edx
c00240a4:	c1 fb 1f             	sar    $0x1f,%ebx
c00240a7:	29 da                	sub    %ebx,%edx
c00240a9:	89 54 24 08          	mov    %edx,0x8(%esp)
c00240ad:	89 d0                	mov    %edx,%eax
c00240af:	c1 f8 1f             	sar    $0x1f,%eax
c00240b2:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00240b6:	89 34 24             	mov    %esi,(%esp)
c00240b9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00240bd:	e8 11 42 00 00       	call   c00282d3 <__divdi3>
c00240c2:	e8 4b fd ff ff       	call   c0023e12 <busy_wait>
c00240c7:	83 c4 2c             	add    $0x2c,%esp
c00240ca:	5b                   	pop    %ebx
c00240cb:	5e                   	pop    %esi
c00240cc:	5f                   	pop    %edi
c00240cd:	5d                   	pop    %ebp
c00240ce:	c3                   	ret    

c00240cf <timer_init>:
{
c00240cf:	83 ec 1c             	sub    $0x1c,%esp
  pit_configure_channel (0, 2, TIMER_FREQ);
c00240d2:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c00240d9:	00 
c00240da:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
c00240e1:	00 
c00240e2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c00240e9:	e8 3a fc ff ff       	call   c0023d28 <pit_configure_channel>
  intr_register_ext (0x20, timer_interrupt, "8254 Timer");
c00240ee:	c7 44 24 08 13 ed 02 	movl   $0xc002ed13,0x8(%esp)
c00240f5:	c0 
c00240f6:	c7 44 24 04 89 3e 02 	movl   $0xc0023e89,0x4(%esp)
c00240fd:	c0 
c00240fe:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0024105:	e8 e9 d8 ff ff       	call   c00219f3 <intr_register_ext>
  list_init (&sleep_list);
c002410a:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c0024111:	e8 2a 49 00 00       	call   c0028a40 <list_init>
}
c0024116:	83 c4 1c             	add    $0x1c,%esp
c0024119:	c3                   	ret    

c002411a <timer_calibrate>:
{
c002411a:	57                   	push   %edi
c002411b:	56                   	push   %esi
c002411c:	53                   	push   %ebx
c002411d:	83 ec 20             	sub    $0x20,%esp
  ASSERT (intr_get_level () == INTR_ON);
c0024120:	e8 df d6 ff ff       	call   c0021804 <intr_get_level>
c0024125:	83 f8 01             	cmp    $0x1,%eax
c0024128:	74 2c                	je     c0024156 <timer_calibrate+0x3c>
c002412a:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c0024131:	c0 
c0024132:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024139:	c0 
c002413a:	c7 44 24 08 13 d3 02 	movl   $0xc002d313,0x8(%esp)
c0024141:	c0 
c0024142:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
c0024149:	00 
c002414a:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c0024151:	e8 1d 48 00 00       	call   c0028973 <debug_panic>
  printf ("Calibrating timer...  ");
c0024156:	c7 04 24 3b ed 02 c0 	movl   $0xc002ed3b,(%esp)
c002415d:	e8 bc 29 00 00       	call   c0026b1e <printf>
  loops_per_tick = 1u << 10;
c0024162:	c7 05 68 77 03 c0 00 	movl   $0x400,0xc0037768
c0024169:	04 00 00 
  while (!too_many_loops (loops_per_tick << 1)) 
c002416c:	eb 36                	jmp    c00241a4 <timer_calibrate+0x8a>
      loops_per_tick <<= 1;
c002416e:	89 1d 68 77 03 c0    	mov    %ebx,0xc0037768
      ASSERT (loops_per_tick != 0);
c0024174:	85 db                	test   %ebx,%ebx
c0024176:	75 2c                	jne    c00241a4 <timer_calibrate+0x8a>
c0024178:	c7 44 24 10 52 ed 02 	movl   $0xc002ed52,0x10(%esp)
c002417f:	c0 
c0024180:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024187:	c0 
c0024188:	c7 44 24 08 13 d3 02 	movl   $0xc002d313,0x8(%esp)
c002418f:	c0 
c0024190:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c0024197:	00 
c0024198:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c002419f:	e8 cf 47 00 00       	call   c0028973 <debug_panic>
  while (!too_many_loops (loops_per_tick << 1)) 
c00241a4:	8b 35 68 77 03 c0    	mov    0xc0037768,%esi
c00241aa:	8d 1c 36             	lea    (%esi,%esi,1),%ebx
c00241ad:	89 d8                	mov    %ebx,%eax
c00241af:	e8 87 fc ff ff       	call   c0023e3b <too_many_loops>
c00241b4:	84 c0                	test   %al,%al
c00241b6:	74 b6                	je     c002416e <timer_calibrate+0x54>
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c00241b8:	89 f3                	mov    %esi,%ebx
c00241ba:	d1 eb                	shr    %ebx
c00241bc:	89 f7                	mov    %esi,%edi
c00241be:	c1 ef 0a             	shr    $0xa,%edi
c00241c1:	39 df                	cmp    %ebx,%edi
c00241c3:	74 19                	je     c00241de <timer_calibrate+0xc4>
    if (!too_many_loops (high_bit | test_bit))
c00241c5:	89 d8                	mov    %ebx,%eax
c00241c7:	09 f0                	or     %esi,%eax
c00241c9:	e8 6d fc ff ff       	call   c0023e3b <too_many_loops>
c00241ce:	84 c0                	test   %al,%al
c00241d0:	75 06                	jne    c00241d8 <timer_calibrate+0xbe>
      loops_per_tick |= test_bit;
c00241d2:	09 1d 68 77 03 c0    	or     %ebx,0xc0037768
  for (test_bit = high_bit >> 1; test_bit != high_bit >> 10; test_bit >>= 1)
c00241d8:	d1 eb                	shr    %ebx
c00241da:	39 df                	cmp    %ebx,%edi
c00241dc:	75 e7                	jne    c00241c5 <timer_calibrate+0xab>
  printf ("%'"PRIu64" loops/s.\n", (uint64_t) loops_per_tick * TIMER_FREQ);
c00241de:	b8 64 00 00 00       	mov    $0x64,%eax
c00241e3:	f7 25 68 77 03 c0    	mull   0xc0037768
c00241e9:	89 44 24 04          	mov    %eax,0x4(%esp)
c00241ed:	89 54 24 08          	mov    %edx,0x8(%esp)
c00241f1:	c7 04 24 66 ed 02 c0 	movl   $0xc002ed66,(%esp)
c00241f8:	e8 21 29 00 00       	call   c0026b1e <printf>
}
c00241fd:	83 c4 20             	add    $0x20,%esp
c0024200:	5b                   	pop    %ebx
c0024201:	5e                   	pop    %esi
c0024202:	5f                   	pop    %edi
c0024203:	c3                   	ret    

c0024204 <timer_ticks>:
{
c0024204:	56                   	push   %esi
c0024205:	53                   	push   %ebx
c0024206:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level = intr_disable ();
c0024209:	e8 41 d6 ff ff       	call   c002184f <intr_disable>
  int64_t t = ticks;
c002420e:	8b 15 70 77 03 c0    	mov    0xc0037770,%edx
c0024214:	8b 0d 74 77 03 c0    	mov    0xc0037774,%ecx
c002421a:	89 d3                	mov    %edx,%ebx
c002421c:	89 ce                	mov    %ecx,%esi
  intr_set_level (old_level);
c002421e:	89 04 24             	mov    %eax,(%esp)
c0024221:	e8 30 d6 ff ff       	call   c0021856 <intr_set_level>
}
c0024226:	89 d8                	mov    %ebx,%eax
c0024228:	89 f2                	mov    %esi,%edx
c002422a:	83 c4 14             	add    $0x14,%esp
c002422d:	5b                   	pop    %ebx
c002422e:	5e                   	pop    %esi
c002422f:	c3                   	ret    

c0024230 <timer_elapsed>:
{
c0024230:	57                   	push   %edi
c0024231:	56                   	push   %esi
c0024232:	83 ec 04             	sub    $0x4,%esp
c0024235:	8b 74 24 10          	mov    0x10(%esp),%esi
c0024239:	8b 7c 24 14          	mov    0x14(%esp),%edi
  return timer_ticks () - then;
c002423d:	e8 c2 ff ff ff       	call   c0024204 <timer_ticks>
c0024242:	29 f0                	sub    %esi,%eax
c0024244:	19 fa                	sbb    %edi,%edx
}
c0024246:	83 c4 04             	add    $0x4,%esp
c0024249:	5e                   	pop    %esi
c002424a:	5f                   	pop    %edi
c002424b:	c3                   	ret    

c002424c <timer_sleep>:
{
c002424c:	57                   	push   %edi
c002424d:	56                   	push   %esi
c002424e:	53                   	push   %ebx
c002424f:	83 ec 20             	sub    $0x20,%esp
c0024252:	8b 74 24 30          	mov    0x30(%esp),%esi
c0024256:	8b 7c 24 34          	mov    0x34(%esp),%edi
    ASSERT (intr_get_level () == INTR_ON);
c002425a:	e8 a5 d5 ff ff       	call   c0021804 <intr_get_level>
c002425f:	83 f8 01             	cmp    $0x1,%eax
c0024262:	74 2c                	je     c0024290 <timer_sleep+0x44>
c0024264:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c002426b:	c0 
c002426c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024273:	c0 
c0024274:	c7 44 24 08 07 d3 02 	movl   $0xc002d307,0x8(%esp)
c002427b:	c0 
c002427c:	c7 44 24 04 6d 00 00 	movl   $0x6d,0x4(%esp)
c0024283:	00 
c0024284:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c002428b:	e8 e3 46 00 00       	call   c0028973 <debug_panic>
    struct thread *cur = thread_current ();
c0024290:	e8 0e ca ff ff       	call   c0020ca3 <thread_current>
c0024295:	89 c3                	mov    %eax,%ebx
    cur->wakeup = timer_ticks () + ticks; //save the wakeup time of each thread as a struct attribute
c0024297:	e8 68 ff ff ff       	call   c0024204 <timer_ticks>
c002429c:	01 f0                	add    %esi,%eax
c002429e:	11 fa                	adc    %edi,%edx
c00242a0:	89 43 34             	mov    %eax,0x34(%ebx)
c00242a3:	89 53 38             	mov    %edx,0x38(%ebx)
    old_level = intr_disable ();
c00242a6:	e8 a4 d5 ff ff       	call   c002184f <intr_disable>
c00242ab:	89 c6                	mov    %eax,%esi
    list_insert_ordered(&sleep_list, &cur->elem, compareSleep, NULL); //add each thread as a list elem to the sleep_list based on wakeup time
c00242ad:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c00242b4:	00 
c00242b5:	c7 44 24 08 00 3e 02 	movl   $0xc0023e00,0x8(%esp)
c00242bc:	c0 
c00242bd:	83 c3 28             	add    $0x28,%ebx
c00242c0:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00242c4:	c7 04 24 58 77 03 c0 	movl   $0xc0037758,(%esp)
c00242cb:	e8 96 51 00 00       	call   c0029466 <list_insert_ordered>
    thread_block(); //block the thread 
c00242d0:	e8 dc ce ff ff       	call   c00211b1 <thread_block>
    intr_set_level (old_level); //set interrupts back to orginal status
c00242d5:	89 34 24             	mov    %esi,(%esp)
c00242d8:	e8 79 d5 ff ff       	call   c0021856 <intr_set_level>
}
c00242dd:	83 c4 20             	add    $0x20,%esp
c00242e0:	5b                   	pop    %ebx
c00242e1:	5e                   	pop    %esi
c00242e2:	5f                   	pop    %edi
c00242e3:	c3                   	ret    

c00242e4 <real_time_sleep>:
{
c00242e4:	55                   	push   %ebp
c00242e5:	57                   	push   %edi
c00242e6:	56                   	push   %esi
c00242e7:	53                   	push   %ebx
c00242e8:	83 ec 2c             	sub    $0x2c,%esp
c00242eb:	89 c7                	mov    %eax,%edi
c00242ed:	89 d6                	mov    %edx,%esi
c00242ef:	89 cd                	mov    %ecx,%ebp
  int64_t ticks = num * TIMER_FREQ / denom;
c00242f1:	6b ca 64             	imul   $0x64,%edx,%ecx
c00242f4:	b8 64 00 00 00       	mov    $0x64,%eax
c00242f9:	f7 e7                	mul    %edi
c00242fb:	01 ca                	add    %ecx,%edx
c00242fd:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0024301:	89 e9                	mov    %ebp,%ecx
c0024303:	c1 f9 1f             	sar    $0x1f,%ecx
c0024306:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002430a:	89 04 24             	mov    %eax,(%esp)
c002430d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0024311:	e8 bd 3f 00 00       	call   c00282d3 <__divdi3>
c0024316:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002431a:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_ON);
c002431c:	e8 e3 d4 ff ff       	call   c0021804 <intr_get_level>
c0024321:	83 f8 01             	cmp    $0x1,%eax
c0024324:	74 2c                	je     c0024352 <real_time_sleep+0x6e>
c0024326:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c002432d:	c0 
c002432e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024335:	c0 
c0024336:	c7 44 24 08 f7 d2 02 	movl   $0xc002d2f7,0x8(%esp)
c002433d:	c0 
c002433e:	c7 44 24 04 30 01 00 	movl   $0x130,0x4(%esp)
c0024345:	00 
c0024346:	c7 04 24 fd ec 02 c0 	movl   $0xc002ecfd,(%esp)
c002434d:	e8 21 46 00 00       	call   c0028973 <debug_panic>
  if (ticks > 0)
c0024352:	85 db                	test   %ebx,%ebx
c0024354:	78 1e                	js     c0024374 <real_time_sleep+0x90>
c0024356:	85 db                	test   %ebx,%ebx
c0024358:	7f 08                	jg     c0024362 <real_time_sleep+0x7e>
c002435a:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c002435f:	90                   	nop
c0024360:	76 12                	jbe    c0024374 <real_time_sleep+0x90>
      timer_sleep (ticks); 
c0024362:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0024366:	89 04 24             	mov    %eax,(%esp)
c0024369:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002436d:	e8 da fe ff ff       	call   c002424c <timer_sleep>
c0024372:	eb 0b                	jmp    c002437f <real_time_sleep+0x9b>
      real_time_delay (num, denom); 
c0024374:	89 e9                	mov    %ebp,%ecx
c0024376:	89 f8                	mov    %edi,%eax
c0024378:	89 f2                	mov    %esi,%edx
c002437a:	e8 8b fc ff ff       	call   c002400a <real_time_delay>
}
c002437f:	83 c4 2c             	add    $0x2c,%esp
c0024382:	5b                   	pop    %ebx
c0024383:	5e                   	pop    %esi
c0024384:	5f                   	pop    %edi
c0024385:	5d                   	pop    %ebp
c0024386:	c3                   	ret    

c0024387 <timer_msleep>:
{
c0024387:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ms, 1000);
c002438a:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002438f:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024393:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024397:	e8 48 ff ff ff       	call   c00242e4 <real_time_sleep>
}
c002439c:	83 c4 0c             	add    $0xc,%esp
c002439f:	c3                   	ret    

c00243a0 <timer_usleep>:
{
c00243a0:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (us, 1000 * 1000);
c00243a3:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00243a8:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243ac:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243b0:	e8 2f ff ff ff       	call   c00242e4 <real_time_sleep>
}
c00243b5:	83 c4 0c             	add    $0xc,%esp
c00243b8:	c3                   	ret    

c00243b9 <timer_nsleep>:
{
c00243b9:	83 ec 0c             	sub    $0xc,%esp
  real_time_sleep (ns, 1000 * 1000 * 1000);
c00243bc:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c00243c1:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243c5:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243c9:	e8 16 ff ff ff       	call   c00242e4 <real_time_sleep>
}
c00243ce:	83 c4 0c             	add    $0xc,%esp
c00243d1:	c3                   	ret    

c00243d2 <timer_mdelay>:
{
c00243d2:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ms, 1000);
c00243d5:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c00243da:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243de:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243e2:	e8 23 fc ff ff       	call   c002400a <real_time_delay>
}
c00243e7:	83 c4 0c             	add    $0xc,%esp
c00243ea:	c3                   	ret    

c00243eb <timer_udelay>:
{
c00243eb:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (us, 1000 * 1000);
c00243ee:	b9 40 42 0f 00       	mov    $0xf4240,%ecx
c00243f3:	8b 44 24 10          	mov    0x10(%esp),%eax
c00243f7:	8b 54 24 14          	mov    0x14(%esp),%edx
c00243fb:	e8 0a fc ff ff       	call   c002400a <real_time_delay>
}
c0024400:	83 c4 0c             	add    $0xc,%esp
c0024403:	c3                   	ret    

c0024404 <timer_ndelay>:
{
c0024404:	83 ec 0c             	sub    $0xc,%esp
  real_time_delay (ns, 1000 * 1000 * 1000);
c0024407:	b9 00 ca 9a 3b       	mov    $0x3b9aca00,%ecx
c002440c:	8b 44 24 10          	mov    0x10(%esp),%eax
c0024410:	8b 54 24 14          	mov    0x14(%esp),%edx
c0024414:	e8 f1 fb ff ff       	call   c002400a <real_time_delay>
}
c0024419:	83 c4 0c             	add    $0xc,%esp
c002441c:	c3                   	ret    

c002441d <timer_print_stats>:
{
c002441d:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Timer: %"PRId64" ticks\n", timer_ticks ());
c0024420:	e8 df fd ff ff       	call   c0024204 <timer_ticks>
c0024425:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024429:	89 54 24 08          	mov    %edx,0x8(%esp)
c002442d:	c7 04 24 76 ed 02 c0 	movl   $0xc002ed76,(%esp)
c0024434:	e8 e5 26 00 00       	call   c0026b1e <printf>
}
c0024439:	83 c4 1c             	add    $0x1c,%esp
c002443c:	c3                   	ret    
c002443d:	90                   	nop
c002443e:	90                   	nop
c002443f:	90                   	nop

c0024440 <map_key>:
   If found, sets *C to the corresponding character and returns
   true.
   If not found, returns false and C is ignored. */
static bool
map_key (const struct keymap k[], unsigned scancode, uint8_t *c) 
{
c0024440:	55                   	push   %ebp
c0024441:	57                   	push   %edi
c0024442:	56                   	push   %esi
c0024443:	53                   	push   %ebx
c0024444:	83 ec 04             	sub    $0x4,%esp
c0024447:	89 c3                	mov    %eax,%ebx
c0024449:	89 0c 24             	mov    %ecx,(%esp)
  for (; k->first_scancode != 0; k++)
c002444c:	0f b6 08             	movzbl (%eax),%ecx
c002444f:	84 c9                	test   %cl,%cl
c0024451:	74 41                	je     c0024494 <map_key+0x54>
    if (scancode >= k->first_scancode
        && scancode < k->first_scancode + strlen (k->chars)) 
c0024453:	b8 00 00 00 00       	mov    $0x0,%eax
    if (scancode >= k->first_scancode
c0024458:	0f b6 f1             	movzbl %cl,%esi
c002445b:	39 d6                	cmp    %edx,%esi
c002445d:	77 29                	ja     c0024488 <map_key+0x48>
        && scancode < k->first_scancode + strlen (k->chars)) 
c002445f:	8b 6b 04             	mov    0x4(%ebx),%ebp
c0024462:	89 ef                	mov    %ebp,%edi
c0024464:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0024469:	f2 ae                	repnz scas %es:(%edi),%al
c002446b:	f7 d1                	not    %ecx
c002446d:	8d 4c 0e ff          	lea    -0x1(%esi,%ecx,1),%ecx
c0024471:	39 ca                	cmp    %ecx,%edx
c0024473:	73 13                	jae    c0024488 <map_key+0x48>
      {
        *c = k->chars[scancode - k->first_scancode];
c0024475:	29 f2                	sub    %esi,%edx
c0024477:	0f b6 44 15 00       	movzbl 0x0(%ebp,%edx,1),%eax
c002447c:	8b 3c 24             	mov    (%esp),%edi
c002447f:	88 07                	mov    %al,(%edi)
        return true; 
c0024481:	b8 01 00 00 00       	mov    $0x1,%eax
c0024486:	eb 18                	jmp    c00244a0 <map_key+0x60>
  for (; k->first_scancode != 0; k++)
c0024488:	83 c3 08             	add    $0x8,%ebx
c002448b:	0f b6 0b             	movzbl (%ebx),%ecx
c002448e:	84 c9                	test   %cl,%cl
c0024490:	75 c6                	jne    c0024458 <map_key+0x18>
c0024492:	eb 07                	jmp    c002449b <map_key+0x5b>
      }

  return false;
c0024494:	b8 00 00 00 00       	mov    $0x0,%eax
c0024499:	eb 05                	jmp    c00244a0 <map_key+0x60>
c002449b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c00244a0:	83 c4 04             	add    $0x4,%esp
c00244a3:	5b                   	pop    %ebx
c00244a4:	5e                   	pop    %esi
c00244a5:	5f                   	pop    %edi
c00244a6:	5d                   	pop    %ebp
c00244a7:	c3                   	ret    

c00244a8 <keyboard_interrupt>:
{
c00244a8:	55                   	push   %ebp
c00244a9:	57                   	push   %edi
c00244aa:	56                   	push   %esi
c00244ab:	53                   	push   %ebx
c00244ac:	83 ec 2c             	sub    $0x2c,%esp
  bool shift = left_shift || right_shift;
c00244af:	0f b6 15 85 77 03 c0 	movzbl 0xc0037785,%edx
c00244b6:	80 3d 86 77 03 c0 00 	cmpb   $0x0,0xc0037786
c00244bd:	b8 01 00 00 00       	mov    $0x1,%eax
c00244c2:	0f 45 d0             	cmovne %eax,%edx
  bool alt = left_alt || right_alt;
c00244c5:	0f b6 3d 83 77 03 c0 	movzbl 0xc0037783,%edi
c00244cc:	80 3d 84 77 03 c0 00 	cmpb   $0x0,0xc0037784
c00244d3:	0f 45 f8             	cmovne %eax,%edi
  bool ctrl = left_ctrl || right_ctrl;
c00244d6:	0f b6 2d 81 77 03 c0 	movzbl 0xc0037781,%ebp
c00244dd:	80 3d 82 77 03 c0 00 	cmpb   $0x0,0xc0037782
c00244e4:	0f 45 e8             	cmovne %eax,%ebp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00244e7:	e4 60                	in     $0x60,%al
  code = inb (DATA_REG);
c00244e9:	0f b6 d8             	movzbl %al,%ebx
  if (code == 0xe0)
c00244ec:	81 fb e0 00 00 00    	cmp    $0xe0,%ebx
c00244f2:	75 08                	jne    c00244fc <keyboard_interrupt+0x54>
c00244f4:	e4 60                	in     $0x60,%al
    code = (code << 8) | inb (DATA_REG);
c00244f6:	0f b6 d8             	movzbl %al,%ebx
c00244f9:	80 cf e0             	or     $0xe0,%bh
  release = (code & 0x80) != 0;
c00244fc:	89 de                	mov    %ebx,%esi
c00244fe:	c1 ee 07             	shr    $0x7,%esi
c0024501:	83 e6 01             	and    $0x1,%esi
  code &= ~0x80u;
c0024504:	80 e3 7f             	and    $0x7f,%bl
  if (code == 0x3a) 
c0024507:	83 fb 3a             	cmp    $0x3a,%ebx
c002450a:	75 16                	jne    c0024522 <keyboard_interrupt+0x7a>
      if (!release)
c002450c:	89 f0                	mov    %esi,%eax
c002450e:	84 c0                	test   %al,%al
c0024510:	0f 85 1d 01 00 00    	jne    c0024633 <keyboard_interrupt+0x18b>
        caps_lock = !caps_lock;
c0024516:	80 35 80 77 03 c0 01 	xorb   $0x1,0xc0037780
c002451d:	e9 11 01 00 00       	jmp    c0024633 <keyboard_interrupt+0x18b>
  bool shift = left_shift || right_shift;
c0024522:	89 d0                	mov    %edx,%eax
c0024524:	83 e0 01             	and    $0x1,%eax
c0024527:	88 44 24 0f          	mov    %al,0xf(%esp)
  else if (map_key (invariant_keymap, code, &c)
c002452b:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002452f:	89 da                	mov    %ebx,%edx
c0024531:	b8 00 d4 02 c0       	mov    $0xc002d400,%eax
c0024536:	e8 05 ff ff ff       	call   c0024440 <map_key>
c002453b:	84 c0                	test   %al,%al
c002453d:	75 23                	jne    c0024562 <keyboard_interrupt+0xba>
           || (!shift && map_key (unshifted_keymap, code, &c))
c002453f:	80 7c 24 0f 00       	cmpb   $0x0,0xf(%esp)
c0024544:	0f 85 c5 00 00 00    	jne    c002460f <keyboard_interrupt+0x167>
c002454a:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c002454e:	89 da                	mov    %ebx,%edx
c0024550:	b8 c0 d3 02 c0       	mov    $0xc002d3c0,%eax
c0024555:	e8 e6 fe ff ff       	call   c0024440 <map_key>
c002455a:	84 c0                	test   %al,%al
c002455c:	0f 84 c5 00 00 00    	je     c0024627 <keyboard_interrupt+0x17f>
      if (!release) 
c0024562:	89 f0                	mov    %esi,%eax
c0024564:	84 c0                	test   %al,%al
c0024566:	0f 85 c7 00 00 00    	jne    c0024633 <keyboard_interrupt+0x18b>
          if (c == 0177 && ctrl && alt)
c002456c:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c0024571:	3c 7f                	cmp    $0x7f,%al
c0024573:	75 0f                	jne    c0024584 <keyboard_interrupt+0xdc>
c0024575:	21 fd                	and    %edi,%ebp
c0024577:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c002457d:	74 1b                	je     c002459a <keyboard_interrupt+0xf2>
            shutdown_reboot ();
c002457f:	e8 06 1e 00 00       	call   c002638a <shutdown_reboot>
          if (ctrl && c >= 0x40 && c < 0x60) 
c0024584:	f7 c5 01 00 00 00    	test   $0x1,%ebp
c002458a:	74 0e                	je     c002459a <keyboard_interrupt+0xf2>
c002458c:	8d 50 c0             	lea    -0x40(%eax),%edx
c002458f:	80 fa 1f             	cmp    $0x1f,%dl
c0024592:	77 06                	ja     c002459a <keyboard_interrupt+0xf2>
              c -= 0x40; 
c0024594:	88 54 24 1f          	mov    %dl,0x1f(%esp)
c0024598:	eb 20                	jmp    c00245ba <keyboard_interrupt+0x112>
          else if (shift == caps_lock)
c002459a:	0f b6 4c 24 0f       	movzbl 0xf(%esp),%ecx
c002459f:	3a 0d 80 77 03 c0    	cmp    0xc0037780,%cl
c00245a5:	75 13                	jne    c00245ba <keyboard_interrupt+0x112>
            c = tolower (c);
c00245a7:	0f b6 c0             	movzbl %al,%eax
#ifndef __LIB_CTYPE_H
#define __LIB_CTYPE_H

static inline int islower (int c) { return c >= 'a' && c <= 'z'; }
static inline int isupper (int c) { return c >= 'A' && c <= 'Z'; }
c00245aa:	8d 48 bf             	lea    -0x41(%eax),%ecx
static inline int isascii (int c) { return c >= 0 && c < 128; }
static inline int ispunct (int c) {
  return isprint (c) && !isalnum (c) && !isspace (c);
}

static inline int tolower (int c) { return isupper (c) ? c - 'A' + 'a' : c; }
c00245ad:	8d 50 20             	lea    0x20(%eax),%edx
c00245b0:	83 f9 19             	cmp    $0x19,%ecx
c00245b3:	0f 46 c2             	cmovbe %edx,%eax
c00245b6:	88 44 24 1f          	mov    %al,0x1f(%esp)
          if (alt)
c00245ba:	f7 c7 01 00 00 00    	test   $0x1,%edi
c00245c0:	74 05                	je     c00245c7 <keyboard_interrupt+0x11f>
            c += 0x80;
c00245c2:	80 44 24 1f 80       	addb   $0x80,0x1f(%esp)
          if (!input_full ())
c00245c7:	e8 11 18 00 00       	call   c0025ddd <input_full>
c00245cc:	84 c0                	test   %al,%al
c00245ce:	75 63                	jne    c0024633 <keyboard_interrupt+0x18b>
              key_cnt++;
c00245d0:	83 05 78 77 03 c0 01 	addl   $0x1,0xc0037778
c00245d7:	83 15 7c 77 03 c0 00 	adcl   $0x0,0xc003777c
              input_putc (c);
c00245de:	0f b6 44 24 1f       	movzbl 0x1f(%esp),%eax
c00245e3:	89 04 24             	mov    %eax,(%esp)
c00245e6:	e8 2d 17 00 00       	call   c0025d18 <input_putc>
c00245eb:	eb 46                	jmp    c0024633 <keyboard_interrupt+0x18b>
        if (key->scancode == code)
c00245ed:	39 d3                	cmp    %edx,%ebx
c00245ef:	75 13                	jne    c0024604 <keyboard_interrupt+0x15c>
c00245f1:	eb 05                	jmp    c00245f8 <keyboard_interrupt+0x150>
      for (key = shift_keys; key->scancode != 0; key++) 
c00245f3:	b8 40 d3 02 c0       	mov    $0xc002d340,%eax
            *key->state_var = !release;
c00245f8:	8b 40 04             	mov    0x4(%eax),%eax
c00245fb:	89 f2                	mov    %esi,%edx
c00245fd:	83 f2 01             	xor    $0x1,%edx
c0024600:	88 10                	mov    %dl,(%eax)
            break;
c0024602:	eb 2f                	jmp    c0024633 <keyboard_interrupt+0x18b>
      for (key = shift_keys; key->scancode != 0; key++) 
c0024604:	83 c0 08             	add    $0x8,%eax
c0024607:	8b 10                	mov    (%eax),%edx
c0024609:	85 d2                	test   %edx,%edx
c002460b:	75 e0                	jne    c00245ed <keyboard_interrupt+0x145>
c002460d:	eb 24                	jmp    c0024633 <keyboard_interrupt+0x18b>
           || (shift && map_key (shifted_keymap, code, &c)))
c002460f:	8d 4c 24 1f          	lea    0x1f(%esp),%ecx
c0024613:	89 da                	mov    %ebx,%edx
c0024615:	b8 80 d3 02 c0       	mov    $0xc002d380,%eax
c002461a:	e8 21 fe ff ff       	call   c0024440 <map_key>
c002461f:	84 c0                	test   %al,%al
c0024621:	0f 85 3b ff ff ff    	jne    c0024562 <keyboard_interrupt+0xba>
        if (key->scancode == code)
c0024627:	83 fb 2a             	cmp    $0x2a,%ebx
c002462a:	74 c7                	je     c00245f3 <keyboard_interrupt+0x14b>
      for (key = shift_keys; key->scancode != 0; key++) 
c002462c:	b8 40 d3 02 c0       	mov    $0xc002d340,%eax
c0024631:	eb d1                	jmp    c0024604 <keyboard_interrupt+0x15c>
}
c0024633:	83 c4 2c             	add    $0x2c,%esp
c0024636:	5b                   	pop    %ebx
c0024637:	5e                   	pop    %esi
c0024638:	5f                   	pop    %edi
c0024639:	5d                   	pop    %ebp
c002463a:	c3                   	ret    

c002463b <kbd_init>:
{
c002463b:	83 ec 1c             	sub    $0x1c,%esp
  intr_register_ext (0x21, keyboard_interrupt, "8042 Keyboard");
c002463e:	c7 44 24 08 89 ed 02 	movl   $0xc002ed89,0x8(%esp)
c0024645:	c0 
c0024646:	c7 44 24 04 a8 44 02 	movl   $0xc00244a8,0x4(%esp)
c002464d:	c0 
c002464e:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c0024655:	e8 99 d3 ff ff       	call   c00219f3 <intr_register_ext>
}
c002465a:	83 c4 1c             	add    $0x1c,%esp
c002465d:	c3                   	ret    

c002465e <kbd_print_stats>:
{
c002465e:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Keyboard: %lld keys pressed\n", key_cnt);
c0024661:	a1 78 77 03 c0       	mov    0xc0037778,%eax
c0024666:	8b 15 7c 77 03 c0    	mov    0xc003777c,%edx
c002466c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024670:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024674:	c7 04 24 97 ed 02 c0 	movl   $0xc002ed97,(%esp)
c002467b:	e8 9e 24 00 00       	call   c0026b1e <printf>
}
c0024680:	83 c4 1c             	add    $0x1c,%esp
c0024683:	c3                   	ret    
c0024684:	90                   	nop
c0024685:	90                   	nop
c0024686:	90                   	nop
c0024687:	90                   	nop
c0024688:	90                   	nop
c0024689:	90                   	nop
c002468a:	90                   	nop
c002468b:	90                   	nop
c002468c:	90                   	nop
c002468d:	90                   	nop
c002468e:	90                   	nop
c002468f:	90                   	nop

c0024690 <move_cursor>:
/* Moves the hardware cursor to (cx,cy). */
static void
move_cursor (void) 
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp = cx + COL_CNT * cy;
c0024690:	8b 0d 90 77 03 c0    	mov    0xc0037790,%ecx
c0024696:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0024699:	c1 e1 04             	shl    $0x4,%ecx
c002469c:	66 03 0d 94 77 03 c0 	add    0xc0037794,%cx
  outw (0x3d4, 0x0e | (cp & 0xff00));
c00246a3:	89 c8                	mov    %ecx,%eax
c00246a5:	b0 00                	mov    $0x0,%al
c00246a7:	83 c8 0e             	or     $0xe,%eax
/* Writes the 16-bit DATA to PORT. */
static inline void
outw (uint16_t port, uint16_t data)
{
  /* See [IA32-v2b] "OUT". */
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c00246aa:	ba d4 03 00 00       	mov    $0x3d4,%edx
c00246af:	66 ef                	out    %ax,(%dx)
  outw (0x3d4, 0x0f | (cp << 8));
c00246b1:	89 c8                	mov    %ecx,%eax
c00246b3:	c1 e0 08             	shl    $0x8,%eax
c00246b6:	83 c8 0f             	or     $0xf,%eax
c00246b9:	66 ef                	out    %ax,(%dx)
c00246bb:	c3                   	ret    

c00246bc <newline>:
  cx = 0;
c00246bc:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c00246c3:	00 00 00 
  cy++;
c00246c6:	a1 90 77 03 c0       	mov    0xc0037790,%eax
c00246cb:	83 c0 01             	add    $0x1,%eax
  if (cy >= ROW_CNT)
c00246ce:	83 f8 18             	cmp    $0x18,%eax
c00246d1:	77 06                	ja     c00246d9 <newline+0x1d>
  cy++;
c00246d3:	a3 90 77 03 c0       	mov    %eax,0xc0037790
c00246d8:	c3                   	ret    
{
c00246d9:	53                   	push   %ebx
c00246da:	83 ec 18             	sub    $0x18,%esp
      cy = ROW_CNT - 1;
c00246dd:	c7 05 90 77 03 c0 18 	movl   $0x18,0xc0037790
c00246e4:	00 00 00 
      memmove (&fb[0], &fb[1], sizeof fb[0] * (ROW_CNT - 1));
c00246e7:	8b 1d 8c 77 03 c0    	mov    0xc003778c,%ebx
c00246ed:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
c00246f4:	00 
c00246f5:	8d 83 a0 00 00 00    	lea    0xa0(%ebx),%eax
c00246fb:	89 44 24 04          	mov    %eax,0x4(%esp)
c00246ff:	89 1c 24             	mov    %ebx,(%esp)
c0024702:	e8 e6 31 00 00       	call   c00278ed <memmove>
  for (x = 0; x < COL_CNT; x++)
c0024707:	b8 00 00 00 00       	mov    $0x0,%eax
      fb[y][x][0] = ' ';
c002470c:	c6 84 43 00 0f 00 00 	movb   $0x20,0xf00(%ebx,%eax,2)
c0024713:	20 
      fb[y][x][1] = GRAY_ON_BLACK;
c0024714:	c6 84 43 01 0f 00 00 	movb   $0x7,0xf01(%ebx,%eax,2)
c002471b:	07 
  for (x = 0; x < COL_CNT; x++)
c002471c:	83 c0 01             	add    $0x1,%eax
c002471f:	83 f8 50             	cmp    $0x50,%eax
c0024722:	75 e8                	jne    c002470c <newline+0x50>
}
c0024724:	83 c4 18             	add    $0x18,%esp
c0024727:	5b                   	pop    %ebx
c0024728:	c3                   	ret    

c0024729 <vga_putc>:
{
c0024729:	57                   	push   %edi
c002472a:	56                   	push   %esi
c002472b:	53                   	push   %ebx
c002472c:	83 ec 10             	sub    $0x10,%esp
c002472f:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  enum intr_level old_level = intr_disable ();
c0024733:	e8 17 d1 ff ff       	call   c002184f <intr_disable>
c0024738:	89 c6                	mov    %eax,%esi
  if (!inited)
c002473a:	80 3d 88 77 03 c0 00 	cmpb   $0x0,0xc0037788
c0024741:	75 5e                	jne    c00247a1 <vga_putc+0x78>
      fb = ptov (0xb8000);
c0024743:	c7 05 8c 77 03 c0 00 	movl   $0xc00b8000,0xc003778c
c002474a:	80 0b c0 
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002474d:	ba d4 03 00 00       	mov    $0x3d4,%edx
c0024752:	b8 0e 00 00 00       	mov    $0xe,%eax
c0024757:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024758:	b9 d5 03 00 00       	mov    $0x3d5,%ecx
c002475d:	89 ca                	mov    %ecx,%edx
c002475f:	ec                   	in     (%dx),%al
{
  /* See [FREEVGA] under "Manipulating the Text-mode Cursor". */
  uint16_t cp;

  outb (0x3d4, 0x0e);
  cp = inb (0x3d5) << 8;
c0024760:	89 c7                	mov    %eax,%edi
c0024762:	c1 e7 08             	shl    $0x8,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024765:	b2 d4                	mov    $0xd4,%dl
c0024767:	b8 0f 00 00 00       	mov    $0xf,%eax
c002476c:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002476d:	89 ca                	mov    %ecx,%edx
c002476f:	ec                   	in     (%dx),%al

  outb (0x3d4, 0x0f);
  cp |= inb (0x3d5);
c0024770:	0f b6 d0             	movzbl %al,%edx
c0024773:	09 fa                	or     %edi,%edx

  *x = cp % COL_CNT;
c0024775:	0f b7 c2             	movzwl %dx,%eax
c0024778:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
c002477e:	c1 e8 16             	shr    $0x16,%eax
c0024781:	8d 0c 80             	lea    (%eax,%eax,4),%ecx
c0024784:	c1 e1 04             	shl    $0x4,%ecx
c0024787:	29 ca                	sub    %ecx,%edx
c0024789:	0f b7 d2             	movzwl %dx,%edx
c002478c:	89 15 94 77 03 c0    	mov    %edx,0xc0037794
  *y = cp / COL_CNT;
c0024792:	0f b7 c0             	movzwl %ax,%eax
c0024795:	a3 90 77 03 c0       	mov    %eax,0xc0037790
      inited = true; 
c002479a:	c6 05 88 77 03 c0 01 	movb   $0x1,0xc0037788
  switch (c) 
c00247a1:	8d 43 f9             	lea    -0x7(%ebx),%eax
c00247a4:	83 f8 06             	cmp    $0x6,%eax
c00247a7:	0f 87 b8 00 00 00    	ja     c0024865 <vga_putc+0x13c>
c00247ad:	ff 24 85 50 d4 02 c0 	jmp    *-0x3ffd2bb0(,%eax,4)
c00247b4:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
      fb[y][x][0] = ' ';
c00247b9:	bb 00 00 00 00       	mov    $0x0,%ebx
c00247be:	eb 28                	jmp    c00247e8 <vga_putc+0xbf>
      newline ();
c00247c0:	e8 f7 fe ff ff       	call   c00246bc <newline>
      break;
c00247c5:	e9 e7 00 00 00       	jmp    c00248b1 <vga_putc+0x188>
      fb[y][x][0] = ' ';
c00247ca:	c6 04 51 20          	movb   $0x20,(%ecx,%edx,2)
      fb[y][x][1] = GRAY_ON_BLACK;
c00247ce:	c6 44 51 01 07       	movb   $0x7,0x1(%ecx,%edx,2)
  for (x = 0; x < COL_CNT; x++)
c00247d3:	83 c2 01             	add    $0x1,%edx
c00247d6:	83 fa 50             	cmp    $0x50,%edx
c00247d9:	75 ef                	jne    c00247ca <vga_putc+0xa1>
  for (y = 0; y < ROW_CNT; y++)
c00247db:	83 c3 01             	add    $0x1,%ebx
c00247de:	05 a0 00 00 00       	add    $0xa0,%eax
c00247e3:	83 fb 19             	cmp    $0x19,%ebx
c00247e6:	74 09                	je     c00247f1 <vga_putc+0xc8>
      fb[y][x][0] = ' ';
c00247e8:	89 c1                	mov    %eax,%ecx
c00247ea:	ba 00 00 00 00       	mov    $0x0,%edx
c00247ef:	eb d9                	jmp    c00247ca <vga_putc+0xa1>
  cx = cy = 0;
c00247f1:	c7 05 90 77 03 c0 00 	movl   $0x0,0xc0037790
c00247f8:	00 00 00 
c00247fb:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024802:	00 00 00 
  move_cursor ();
c0024805:	e8 86 fe ff ff       	call   c0024690 <move_cursor>
c002480a:	e9 a2 00 00 00       	jmp    c00248b1 <vga_putc+0x188>
      if (cx > 0)
c002480f:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c0024814:	85 c0                	test   %eax,%eax
c0024816:	0f 84 95 00 00 00    	je     c00248b1 <vga_putc+0x188>
        cx--;
c002481c:	83 e8 01             	sub    $0x1,%eax
c002481f:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c0024824:	e9 88 00 00 00       	jmp    c00248b1 <vga_putc+0x188>
      cx = 0;
c0024829:	c7 05 94 77 03 c0 00 	movl   $0x0,0xc0037794
c0024830:	00 00 00 
      break;
c0024833:	eb 7c                	jmp    c00248b1 <vga_putc+0x188>
      cx = ROUND_UP (cx + 1, 8);
c0024835:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c002483a:	83 c0 08             	add    $0x8,%eax
c002483d:	83 e0 f8             	and    $0xfffffff8,%eax
c0024840:	a3 94 77 03 c0       	mov    %eax,0xc0037794
      if (cx >= COL_CNT)
c0024845:	83 f8 4f             	cmp    $0x4f,%eax
c0024848:	76 67                	jbe    c00248b1 <vga_putc+0x188>
        newline ();
c002484a:	e8 6d fe ff ff       	call   c00246bc <newline>
c002484f:	eb 60                	jmp    c00248b1 <vga_putc+0x188>
      intr_set_level (old_level);
c0024851:	89 34 24             	mov    %esi,(%esp)
c0024854:	e8 fd cf ff ff       	call   c0021856 <intr_set_level>
      speaker_beep ();
c0024859:	e8 bd 1c 00 00       	call   c002651b <speaker_beep>
      intr_disable ();
c002485e:	e8 ec cf ff ff       	call   c002184f <intr_disable>
      break;
c0024863:	eb 4c                	jmp    c00248b1 <vga_putc+0x188>
      fb[cy][cx][0] = c;
c0024865:	a1 8c 77 03 c0       	mov    0xc003778c,%eax
c002486a:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c0024870:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0024873:	c1 e2 05             	shl    $0x5,%edx
c0024876:	01 c2                	add    %eax,%edx
c0024878:	8b 0d 94 77 03 c0    	mov    0xc0037794,%ecx
c002487e:	88 1c 4a             	mov    %bl,(%edx,%ecx,2)
      fb[cy][cx][1] = GRAY_ON_BLACK;
c0024881:	8b 15 90 77 03 c0    	mov    0xc0037790,%edx
c0024887:	8d 14 92             	lea    (%edx,%edx,4),%edx
c002488a:	c1 e2 05             	shl    $0x5,%edx
c002488d:	01 d0                	add    %edx,%eax
c002488f:	8b 15 94 77 03 c0    	mov    0xc0037794,%edx
c0024895:	c6 44 50 01 07       	movb   $0x7,0x1(%eax,%edx,2)
      if (++cx >= COL_CNT)
c002489a:	a1 94 77 03 c0       	mov    0xc0037794,%eax
c002489f:	83 c0 01             	add    $0x1,%eax
c00248a2:	a3 94 77 03 c0       	mov    %eax,0xc0037794
c00248a7:	83 f8 4f             	cmp    $0x4f,%eax
c00248aa:	76 05                	jbe    c00248b1 <vga_putc+0x188>
        newline ();
c00248ac:	e8 0b fe ff ff       	call   c00246bc <newline>
  move_cursor ();
c00248b1:	e8 da fd ff ff       	call   c0024690 <move_cursor>
  intr_set_level (old_level);
c00248b6:	89 34 24             	mov    %esi,(%esp)
c00248b9:	e8 98 cf ff ff       	call   c0021856 <intr_set_level>
}
c00248be:	83 c4 10             	add    $0x10,%esp
c00248c1:	5b                   	pop    %ebx
c00248c2:	5e                   	pop    %esi
c00248c3:	5f                   	pop    %edi
c00248c4:	c3                   	ret    
c00248c5:	90                   	nop
c00248c6:	90                   	nop
c00248c7:	90                   	nop
c00248c8:	90                   	nop
c00248c9:	90                   	nop
c00248ca:	90                   	nop
c00248cb:	90                   	nop
c00248cc:	90                   	nop
c00248cd:	90                   	nop
c00248ce:	90                   	nop
c00248cf:	90                   	nop

c00248d0 <init_poll>:
   Polling mode busy-waits for the serial port to become free
   before writing to it.  It's slow, but until interrupts have
   been initialized it's all we can do. */
static void
init_poll (void) 
{
c00248d0:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (mode == UNINIT);
c00248d3:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c00248da:	74 2c                	je     c0024908 <init_poll+0x38>
c00248dc:	c7 44 24 10 10 ee 02 	movl   $0xc002ee10,0x10(%esp)
c00248e3:	c0 
c00248e4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00248eb:	c0 
c00248ec:	c7 44 24 08 8e d4 02 	movl   $0xc002d48e,0x8(%esp)
c00248f3:	c0 
c00248f4:	c7 44 24 04 45 00 00 	movl   $0x45,0x4(%esp)
c00248fb:	00 
c00248fc:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024903:	e8 6b 40 00 00       	call   c0028973 <debug_panic>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024908:	ba f9 03 00 00       	mov    $0x3f9,%edx
c002490d:	b8 00 00 00 00       	mov    $0x0,%eax
c0024912:	ee                   	out    %al,(%dx)
c0024913:	b2 fa                	mov    $0xfa,%dl
c0024915:	ee                   	out    %al,(%dx)
c0024916:	b2 fb                	mov    $0xfb,%dl
c0024918:	b8 83 ff ff ff       	mov    $0xffffff83,%eax
c002491d:	ee                   	out    %al,(%dx)
c002491e:	b2 f8                	mov    $0xf8,%dl
c0024920:	b8 0c 00 00 00       	mov    $0xc,%eax
c0024925:	ee                   	out    %al,(%dx)
c0024926:	b2 f9                	mov    $0xf9,%dl
c0024928:	b8 00 00 00 00       	mov    $0x0,%eax
c002492d:	ee                   	out    %al,(%dx)
c002492e:	b2 fb                	mov    $0xfb,%dl
c0024930:	b8 03 00 00 00       	mov    $0x3,%eax
c0024935:	ee                   	out    %al,(%dx)
c0024936:	b2 fc                	mov    $0xfc,%dl
c0024938:	b8 08 00 00 00       	mov    $0x8,%eax
c002493d:	ee                   	out    %al,(%dx)
  outb (IER_REG, 0);                    /* Turn off all interrupts. */
  outb (FCR_REG, 0);                    /* Disable FIFO. */
  set_serial (9600);                    /* 9.6 kbps, N-8-1. */
  outb (MCR_REG, MCR_OUT2);             /* Required to enable interrupts. */
  intq_init (&txq);
c002493e:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024945:	e8 db 14 00 00       	call   c0025e25 <intq_init>
  mode = POLL;
c002494a:	c7 05 14 78 03 c0 01 	movl   $0x1,0xc0037814
c0024951:	00 00 00 
} 
c0024954:	83 c4 2c             	add    $0x2c,%esp
c0024957:	c3                   	ret    

c0024958 <write_ier>:
}

/* Update interrupt enable register. */
static void
write_ier (void) 
{
c0024958:	53                   	push   %ebx
c0024959:	83 ec 28             	sub    $0x28,%esp
  uint8_t ier = 0;

  ASSERT (intr_get_level () == INTR_OFF);
c002495c:	e8 a3 ce ff ff       	call   c0021804 <intr_get_level>
c0024961:	85 c0                	test   %eax,%eax
c0024963:	74 2c                	je     c0024991 <write_ier+0x39>
c0024965:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c002496c:	c0 
c002496d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024974:	c0 
c0024975:	c7 44 24 08 84 d4 02 	movl   $0xc002d484,0x8(%esp)
c002497c:	c0 
c002497d:	c7 44 24 04 b5 00 00 	movl   $0xb5,0x4(%esp)
c0024984:	00 
c0024985:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c002498c:	e8 e2 3f 00 00       	call   c0028973 <debug_panic>

  /* Enable transmit interrupt if we have any characters to
     transmit. */
  if (!intq_empty (&txq))
c0024991:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024998:	e8 b9 14 00 00       	call   c0025e56 <intq_empty>
  uint8_t ier = 0;
c002499d:	3c 01                	cmp    $0x1,%al
c002499f:	19 db                	sbb    %ebx,%ebx
c00249a1:	83 e3 02             	and    $0x2,%ebx
    ier |= IER_XMIT;

  /* Enable receive interrupt if we have room to store any
     characters we receive. */
  if (!input_full ())
c00249a4:	e8 34 14 00 00       	call   c0025ddd <input_full>
    ier |= IER_RECV;
c00249a9:	89 da                	mov    %ebx,%edx
c00249ab:	83 ca 01             	or     $0x1,%edx
c00249ae:	84 c0                	test   %al,%al
c00249b0:	0f 44 da             	cmove  %edx,%ebx
c00249b3:	ba f9 03 00 00       	mov    $0x3f9,%edx
c00249b8:	89 d8                	mov    %ebx,%eax
c00249ba:	ee                   	out    %al,(%dx)
  
  outb (IER_REG, ier);
}
c00249bb:	83 c4 28             	add    $0x28,%esp
c00249be:	5b                   	pop    %ebx
c00249bf:	c3                   	ret    

c00249c0 <serial_interrupt>:
}

/* Serial interrupt handler. */
static void
serial_interrupt (struct intr_frame *f UNUSED) 
{
c00249c0:	56                   	push   %esi
c00249c1:	53                   	push   %ebx
c00249c2:	83 ec 14             	sub    $0x14,%esp
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00249c5:	ba fa 03 00 00       	mov    $0x3fa,%edx
c00249ca:	ec                   	in     (%dx),%al
c00249cb:	bb fd 03 00 00       	mov    $0x3fd,%ebx
c00249d0:	be f8 03 00 00       	mov    $0x3f8,%esi
c00249d5:	eb 0e                	jmp    c00249e5 <serial_interrupt+0x25>
c00249d7:	89 f2                	mov    %esi,%edx
c00249d9:	ec                   	in     (%dx),%al
  inb (IIR_REG);

  /* As long as we have room to receive a byte, and the hardware
     has a byte for us, receive a byte.  */
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
    input_putc (inb (RBR_REG));
c00249da:	0f b6 c0             	movzbl %al,%eax
c00249dd:	89 04 24             	mov    %eax,(%esp)
c00249e0:	e8 33 13 00 00       	call   c0025d18 <input_putc>
  while (!input_full () && (inb (LSR_REG) & LSR_DR) != 0)
c00249e5:	e8 f3 13 00 00       	call   c0025ddd <input_full>
c00249ea:	84 c0                	test   %al,%al
c00249ec:	74 0c                	je     c00249fa <serial_interrupt+0x3a>
c00249ee:	bb fd 03 00 00       	mov    $0x3fd,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00249f3:	be f8 03 00 00       	mov    $0x3f8,%esi
c00249f8:	eb 18                	jmp    c0024a12 <serial_interrupt+0x52>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00249fa:	89 da                	mov    %ebx,%edx
c00249fc:	ec                   	in     (%dx),%al
c00249fd:	a8 01                	test   $0x1,%al
c00249ff:	75 d6                	jne    c00249d7 <serial_interrupt+0x17>
c0024a01:	eb eb                	jmp    c00249ee <serial_interrupt+0x2e>

  /* As long as we have a byte to transmit, and the hardware is
     ready to accept a byte for transmission, transmit a byte. */
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
    outb (THR_REG, intq_getc (&txq));
c0024a03:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a0a:	e8 70 16 00 00       	call   c002607f <intq_getc>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a0f:	89 f2                	mov    %esi,%edx
c0024a11:	ee                   	out    %al,(%dx)
  while (!intq_empty (&txq) && (inb (LSR_REG) & LSR_THRE) != 0) 
c0024a12:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024a19:	e8 38 14 00 00       	call   c0025e56 <intq_empty>
c0024a1e:	84 c0                	test   %al,%al
c0024a20:	75 07                	jne    c0024a29 <serial_interrupt+0x69>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0024a22:	89 da                	mov    %ebx,%edx
c0024a24:	ec                   	in     (%dx),%al
c0024a25:	a8 20                	test   $0x20,%al
c0024a27:	75 da                	jne    c0024a03 <serial_interrupt+0x43>

  /* Update interrupt enable register based on queue status. */
  write_ier ();
c0024a29:	e8 2a ff ff ff       	call   c0024958 <write_ier>
}
c0024a2e:	83 c4 14             	add    $0x14,%esp
c0024a31:	5b                   	pop    %ebx
c0024a32:	5e                   	pop    %esi
c0024a33:	c3                   	ret    

c0024a34 <putc_poll>:
{
c0024a34:	53                   	push   %ebx
c0024a35:	83 ec 28             	sub    $0x28,%esp
c0024a38:	89 c3                	mov    %eax,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0024a3a:	e8 c5 cd ff ff       	call   c0021804 <intr_get_level>
c0024a3f:	85 c0                	test   %eax,%eax
c0024a41:	74 2c                	je     c0024a6f <putc_poll+0x3b>
c0024a43:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0024a4a:	c0 
c0024a4b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024a52:	c0 
c0024a53:	c7 44 24 08 7a d4 02 	movl   $0xc002d47a,0x8(%esp)
c0024a5a:	c0 
c0024a5b:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c0024a62:	00 
c0024a63:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024a6a:	e8 04 3f 00 00       	call   c0028973 <debug_panic>
c0024a6f:	ba fd 03 00 00       	mov    $0x3fd,%edx
c0024a74:	ec                   	in     (%dx),%al
  while ((inb (LSR_REG) & LSR_THRE) == 0)
c0024a75:	a8 20                	test   $0x20,%al
c0024a77:	74 fb                	je     c0024a74 <putc_poll+0x40>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0024a79:	ba f8 03 00 00       	mov    $0x3f8,%edx
c0024a7e:	89 d8                	mov    %ebx,%eax
c0024a80:	ee                   	out    %al,(%dx)
}
c0024a81:	83 c4 28             	add    $0x28,%esp
c0024a84:	5b                   	pop    %ebx
c0024a85:	c3                   	ret    

c0024a86 <serial_init_queue>:
{
c0024a86:	53                   	push   %ebx
c0024a87:	83 ec 28             	sub    $0x28,%esp
  if (mode == UNINIT)
c0024a8a:	83 3d 14 78 03 c0 00 	cmpl   $0x0,0xc0037814
c0024a91:	75 05                	jne    c0024a98 <serial_init_queue+0x12>
    init_poll ();
c0024a93:	e8 38 fe ff ff       	call   c00248d0 <init_poll>
  ASSERT (mode == POLL);
c0024a98:	83 3d 14 78 03 c0 01 	cmpl   $0x1,0xc0037814
c0024a9f:	74 2c                	je     c0024acd <serial_init_queue+0x47>
c0024aa1:	c7 44 24 10 36 ee 02 	movl   $0xc002ee36,0x10(%esp)
c0024aa8:	c0 
c0024aa9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024ab0:	c0 
c0024ab1:	c7 44 24 08 98 d4 02 	movl   $0xc002d498,0x8(%esp)
c0024ab8:	c0 
c0024ab9:	c7 44 24 04 58 00 00 	movl   $0x58,0x4(%esp)
c0024ac0:	00 
c0024ac1:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024ac8:	e8 a6 3e 00 00       	call   c0028973 <debug_panic>
  intr_register_ext (0x20 + 4, serial_interrupt, "serial");
c0024acd:	c7 44 24 08 43 ee 02 	movl   $0xc002ee43,0x8(%esp)
c0024ad4:	c0 
c0024ad5:	c7 44 24 04 c0 49 02 	movl   $0xc00249c0,0x4(%esp)
c0024adc:	c0 
c0024add:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
c0024ae4:	e8 0a cf ff ff       	call   c00219f3 <intr_register_ext>
  mode = QUEUE;
c0024ae9:	c7 05 14 78 03 c0 02 	movl   $0x2,0xc0037814
c0024af0:	00 00 00 
  old_level = intr_disable ();
c0024af3:	e8 57 cd ff ff       	call   c002184f <intr_disable>
c0024af8:	89 c3                	mov    %eax,%ebx
  write_ier ();
c0024afa:	e8 59 fe ff ff       	call   c0024958 <write_ier>
  intr_set_level (old_level);
c0024aff:	89 1c 24             	mov    %ebx,(%esp)
c0024b02:	e8 4f cd ff ff       	call   c0021856 <intr_set_level>
}
c0024b07:	83 c4 28             	add    $0x28,%esp
c0024b0a:	5b                   	pop    %ebx
c0024b0b:	c3                   	ret    

c0024b0c <serial_putc>:
{
c0024b0c:	56                   	push   %esi
c0024b0d:	53                   	push   %ebx
c0024b0e:	83 ec 14             	sub    $0x14,%esp
c0024b11:	8b 74 24 20          	mov    0x20(%esp),%esi
  enum intr_level old_level = intr_disable ();
c0024b15:	e8 35 cd ff ff       	call   c002184f <intr_disable>
c0024b1a:	89 c3                	mov    %eax,%ebx
  if (mode != QUEUE)
c0024b1c:	8b 15 14 78 03 c0    	mov    0xc0037814,%edx
c0024b22:	83 fa 02             	cmp    $0x2,%edx
c0024b25:	74 15                	je     c0024b3c <serial_putc+0x30>
      if (mode == UNINIT)
c0024b27:	85 d2                	test   %edx,%edx
c0024b29:	75 05                	jne    c0024b30 <serial_putc+0x24>
        init_poll ();
c0024b2b:	e8 a0 fd ff ff       	call   c00248d0 <init_poll>
      putc_poll (byte); 
c0024b30:	89 f0                	mov    %esi,%eax
c0024b32:	0f b6 c0             	movzbl %al,%eax
c0024b35:	e8 fa fe ff ff       	call   c0024a34 <putc_poll>
c0024b3a:	eb 42                	jmp    c0024b7e <serial_putc+0x72>
      if (old_level == INTR_OFF && intq_full (&txq)) 
c0024b3c:	85 c0                	test   %eax,%eax
c0024b3e:	75 24                	jne    c0024b64 <serial_putc+0x58>
c0024b40:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b47:	e8 55 13 00 00       	call   c0025ea1 <intq_full>
c0024b4c:	84 c0                	test   %al,%al
c0024b4e:	74 14                	je     c0024b64 <serial_putc+0x58>
          putc_poll (intq_getc (&txq)); 
c0024b50:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b57:	e8 23 15 00 00       	call   c002607f <intq_getc>
c0024b5c:	0f b6 c0             	movzbl %al,%eax
c0024b5f:	e8 d0 fe ff ff       	call   c0024a34 <putc_poll>
      intq_putc (&txq, byte); 
c0024b64:	89 f0                	mov    %esi,%eax
c0024b66:	0f b6 f0             	movzbl %al,%esi
c0024b69:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024b6d:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024b74:	e8 d2 15 00 00       	call   c002614b <intq_putc>
      write_ier ();
c0024b79:	e8 da fd ff ff       	call   c0024958 <write_ier>
  intr_set_level (old_level);
c0024b7e:	89 1c 24             	mov    %ebx,(%esp)
c0024b81:	e8 d0 cc ff ff       	call   c0021856 <intr_set_level>
}
c0024b86:	83 c4 14             	add    $0x14,%esp
c0024b89:	5b                   	pop    %ebx
c0024b8a:	5e                   	pop    %esi
c0024b8b:	c3                   	ret    

c0024b8c <serial_flush>:
{
c0024b8c:	53                   	push   %ebx
c0024b8d:	83 ec 18             	sub    $0x18,%esp
  enum intr_level old_level = intr_disable ();
c0024b90:	e8 ba cc ff ff       	call   c002184f <intr_disable>
c0024b95:	89 c3                	mov    %eax,%ebx
  while (!intq_empty (&txq))
c0024b97:	eb 14                	jmp    c0024bad <serial_flush+0x21>
    putc_poll (intq_getc (&txq));
c0024b99:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024ba0:	e8 da 14 00 00       	call   c002607f <intq_getc>
c0024ba5:	0f b6 c0             	movzbl %al,%eax
c0024ba8:	e8 87 fe ff ff       	call   c0024a34 <putc_poll>
  while (!intq_empty (&txq))
c0024bad:	c7 04 24 a0 77 03 c0 	movl   $0xc00377a0,(%esp)
c0024bb4:	e8 9d 12 00 00       	call   c0025e56 <intq_empty>
c0024bb9:	84 c0                	test   %al,%al
c0024bbb:	74 dc                	je     c0024b99 <serial_flush+0xd>
  intr_set_level (old_level);
c0024bbd:	89 1c 24             	mov    %ebx,(%esp)
c0024bc0:	e8 91 cc ff ff       	call   c0021856 <intr_set_level>
}
c0024bc5:	83 c4 18             	add    $0x18,%esp
c0024bc8:	5b                   	pop    %ebx
c0024bc9:	c3                   	ret    

c0024bca <serial_notify>:
{
c0024bca:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0024bcd:	e8 32 cc ff ff       	call   c0021804 <intr_get_level>
c0024bd2:	85 c0                	test   %eax,%eax
c0024bd4:	74 2c                	je     c0024c02 <serial_notify+0x38>
c0024bd6:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0024bdd:	c0 
c0024bde:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024be5:	c0 
c0024be6:	c7 44 24 08 6c d4 02 	movl   $0xc002d46c,0x8(%esp)
c0024bed:	c0 
c0024bee:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
c0024bf5:	00 
c0024bf6:	c7 04 24 1f ee 02 c0 	movl   $0xc002ee1f,(%esp)
c0024bfd:	e8 71 3d 00 00       	call   c0028973 <debug_panic>
  if (mode == QUEUE)
c0024c02:	83 3d 14 78 03 c0 02 	cmpl   $0x2,0xc0037814
c0024c09:	75 05                	jne    c0024c10 <serial_notify+0x46>
    write_ier ();
c0024c0b:	e8 48 fd ff ff       	call   c0024958 <write_ier>
}
c0024c10:	83 c4 2c             	add    $0x2c,%esp
c0024c13:	c3                   	ret    

c0024c14 <check_sector>:
/* Verifies that SECTOR is a valid offset within BLOCK.
   Panics if not. */
static void
check_sector (struct block *block, block_sector_t sector)
{
  if (sector >= block->size)
c0024c14:	8b 48 1c             	mov    0x1c(%eax),%ecx
c0024c17:	39 d1                	cmp    %edx,%ecx
c0024c19:	77 36                	ja     c0024c51 <check_sector+0x3d>
{
c0024c1b:	83 ec 2c             	sub    $0x2c,%esp
    {
      /* We do not use ASSERT because we want to panic here
         regardless of whether NDEBUG is defined. */
      PANIC ("Access past end of device %s (sector=%"PRDSNu", "
c0024c1e:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024c22:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024c26:	83 c0 08             	add    $0x8,%eax
c0024c29:	89 44 24 10          	mov    %eax,0x10(%esp)
c0024c2d:	c7 44 24 0c 4c ee 02 	movl   $0xc002ee4c,0xc(%esp)
c0024c34:	c0 
c0024c35:	c7 44 24 08 c7 d4 02 	movl   $0xc002d4c7,0x8(%esp)
c0024c3c:	c0 
c0024c3d:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
c0024c44:	00 
c0024c45:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024c4c:	e8 22 3d 00 00       	call   c0028973 <debug_panic>
c0024c51:	f3 c3                	repz ret 

c0024c53 <block_type_name>:
{
c0024c53:	83 ec 2c             	sub    $0x2c,%esp
c0024c56:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (type < BLOCK_CNT);
c0024c5a:	83 f8 05             	cmp    $0x5,%eax
c0024c5d:	76 2c                	jbe    c0024c8b <block_type_name+0x38>
c0024c5f:	c7 44 24 10 f0 ee 02 	movl   $0xc002eef0,0x10(%esp)
c0024c66:	c0 
c0024c67:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024c6e:	c0 
c0024c6f:	c7 44 24 08 0c d5 02 	movl   $0xc002d50c,0x8(%esp)
c0024c76:	c0 
c0024c77:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0024c7e:	00 
c0024c7f:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024c86:	e8 e8 3c 00 00       	call   c0028973 <debug_panic>
  return block_type_names[type];
c0024c8b:	8b 04 85 f4 d4 02 c0 	mov    -0x3ffd2b0c(,%eax,4),%eax
}
c0024c92:	83 c4 2c             	add    $0x2c,%esp
c0024c95:	c3                   	ret    

c0024c96 <block_get_role>:
{
c0024c96:	83 ec 2c             	sub    $0x2c,%esp
c0024c99:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024c9d:	83 f8 03             	cmp    $0x3,%eax
c0024ca0:	76 2c                	jbe    c0024cce <block_get_role+0x38>
c0024ca2:	c7 44 24 10 01 ef 02 	movl   $0xc002ef01,0x10(%esp)
c0024ca9:	c0 
c0024caa:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024cb1:	c0 
c0024cb2:	c7 44 24 08 e3 d4 02 	movl   $0xc002d4e3,0x8(%esp)
c0024cb9:	c0 
c0024cba:	c7 44 24 04 38 00 00 	movl   $0x38,0x4(%esp)
c0024cc1:	00 
c0024cc2:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024cc9:	e8 a5 3c 00 00       	call   c0028973 <debug_panic>
  return block_by_role[role];
c0024cce:	8b 04 85 18 78 03 c0 	mov    -0x3ffc87e8(,%eax,4),%eax
}
c0024cd5:	83 c4 2c             	add    $0x2c,%esp
c0024cd8:	c3                   	ret    

c0024cd9 <block_set_role>:
{
c0024cd9:	83 ec 2c             	sub    $0x2c,%esp
c0024cdc:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (role < BLOCK_ROLE_CNT);
c0024ce0:	83 f8 03             	cmp    $0x3,%eax
c0024ce3:	76 2c                	jbe    c0024d11 <block_set_role+0x38>
c0024ce5:	c7 44 24 10 01 ef 02 	movl   $0xc002ef01,0x10(%esp)
c0024cec:	c0 
c0024ced:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024cf4:	c0 
c0024cf5:	c7 44 24 08 d4 d4 02 	movl   $0xc002d4d4,0x8(%esp)
c0024cfc:	c0 
c0024cfd:	c7 44 24 04 40 00 00 	movl   $0x40,0x4(%esp)
c0024d04:	00 
c0024d05:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024d0c:	e8 62 3c 00 00       	call   c0028973 <debug_panic>
  block_by_role[role] = block;
c0024d11:	8b 54 24 34          	mov    0x34(%esp),%edx
c0024d15:	89 14 85 18 78 03 c0 	mov    %edx,-0x3ffc87e8(,%eax,4)
}
c0024d1c:	83 c4 2c             	add    $0x2c,%esp
c0024d1f:	c3                   	ret    

c0024d20 <block_first>:
{
c0024d20:	53                   	push   %ebx
c0024d21:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_begin (&all_blocks));
c0024d24:	c7 04 24 4c 5a 03 c0 	movl   $0xc0035a4c,(%esp)
c0024d2b:	e8 61 3d 00 00       	call   c0028a91 <list_begin>
c0024d30:	89 c3                	mov    %eax,%ebx
/* Returns the block device corresponding to LIST_ELEM, or a null
   pointer if LIST_ELEM is the list end of all_blocks. */
static struct block *
list_elem_to_block (struct list_elem *list_elem)
{
  return (list_elem != list_end (&all_blocks)
c0024d32:	c7 04 24 4c 5a 03 c0 	movl   $0xc0035a4c,(%esp)
c0024d39:	e8 e5 3d 00 00       	call   c0028b23 <list_end>
          ? list_entry (list_elem, struct block, list_elem)
          : NULL);
c0024d3e:	39 c3                	cmp    %eax,%ebx
c0024d40:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d45:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d48:	83 c4 18             	add    $0x18,%esp
c0024d4b:	5b                   	pop    %ebx
c0024d4c:	c3                   	ret    

c0024d4d <block_next>:
{
c0024d4d:	53                   	push   %ebx
c0024d4e:	83 ec 18             	sub    $0x18,%esp
  return list_elem_to_block (list_next (&block->list_elem));
c0024d51:	8b 44 24 20          	mov    0x20(%esp),%eax
c0024d55:	89 04 24             	mov    %eax,(%esp)
c0024d58:	e8 72 3d 00 00       	call   c0028acf <list_next>
c0024d5d:	89 c3                	mov    %eax,%ebx
  return (list_elem != list_end (&all_blocks)
c0024d5f:	c7 04 24 4c 5a 03 c0 	movl   $0xc0035a4c,(%esp)
c0024d66:	e8 b8 3d 00 00       	call   c0028b23 <list_end>
          : NULL);
c0024d6b:	39 c3                	cmp    %eax,%ebx
c0024d6d:	b8 00 00 00 00       	mov    $0x0,%eax
c0024d72:	0f 45 c3             	cmovne %ebx,%eax
}
c0024d75:	83 c4 18             	add    $0x18,%esp
c0024d78:	5b                   	pop    %ebx
c0024d79:	c3                   	ret    

c0024d7a <block_get_by_name>:
{
c0024d7a:	56                   	push   %esi
c0024d7b:	53                   	push   %ebx
c0024d7c:	83 ec 14             	sub    $0x14,%esp
c0024d7f:	8b 74 24 20          	mov    0x20(%esp),%esi
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024d83:	c7 04 24 4c 5a 03 c0 	movl   $0xc0035a4c,(%esp)
c0024d8a:	e8 02 3d 00 00       	call   c0028a91 <list_begin>
c0024d8f:	89 c3                	mov    %eax,%ebx
c0024d91:	eb 1d                	jmp    c0024db0 <block_get_by_name+0x36>
      if (!strcmp (name, block->name))
c0024d93:	8d 43 08             	lea    0x8(%ebx),%eax
c0024d96:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024d9a:	89 34 24             	mov    %esi,(%esp)
c0024d9d:	e8 e5 2c 00 00       	call   c0027a87 <strcmp>
c0024da2:	85 c0                	test   %eax,%eax
c0024da4:	74 21                	je     c0024dc7 <block_get_by_name+0x4d>
       e = list_next (e))
c0024da6:	89 1c 24             	mov    %ebx,(%esp)
c0024da9:	e8 21 3d 00 00       	call   c0028acf <list_next>
c0024dae:	89 c3                	mov    %eax,%ebx
  for (e = list_begin (&all_blocks); e != list_end (&all_blocks);
c0024db0:	c7 04 24 4c 5a 03 c0 	movl   $0xc0035a4c,(%esp)
c0024db7:	e8 67 3d 00 00       	call   c0028b23 <list_end>
c0024dbc:	39 d8                	cmp    %ebx,%eax
c0024dbe:	75 d3                	jne    c0024d93 <block_get_by_name+0x19>
  return NULL;
c0024dc0:	b8 00 00 00 00       	mov    $0x0,%eax
c0024dc5:	eb 02                	jmp    c0024dc9 <block_get_by_name+0x4f>
c0024dc7:	89 d8                	mov    %ebx,%eax
}
c0024dc9:	83 c4 14             	add    $0x14,%esp
c0024dcc:	5b                   	pop    %ebx
c0024dcd:	5e                   	pop    %esi
c0024dce:	c3                   	ret    

c0024dcf <block_read>:
{
c0024dcf:	56                   	push   %esi
c0024dd0:	53                   	push   %ebx
c0024dd1:	83 ec 14             	sub    $0x14,%esp
c0024dd4:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0024dd8:	8b 74 24 24          	mov    0x24(%esp),%esi
  check_sector (block, sector);
c0024ddc:	89 f2                	mov    %esi,%edx
c0024dde:	89 d8                	mov    %ebx,%eax
c0024de0:	e8 2f fe ff ff       	call   c0024c14 <check_sector>
  block->ops->read (block->aux, sector, buffer);
c0024de5:	8b 43 20             	mov    0x20(%ebx),%eax
c0024de8:	8b 54 24 28          	mov    0x28(%esp),%edx
c0024dec:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024df0:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024df4:	8b 53 24             	mov    0x24(%ebx),%edx
c0024df7:	89 14 24             	mov    %edx,(%esp)
c0024dfa:	ff 10                	call   *(%eax)
  block->read_cnt++;
c0024dfc:	83 43 28 01          	addl   $0x1,0x28(%ebx)
c0024e00:	83 53 2c 00          	adcl   $0x0,0x2c(%ebx)
}
c0024e04:	83 c4 14             	add    $0x14,%esp
c0024e07:	5b                   	pop    %ebx
c0024e08:	5e                   	pop    %esi
c0024e09:	c3                   	ret    

c0024e0a <block_write>:
{
c0024e0a:	56                   	push   %esi
c0024e0b:	53                   	push   %ebx
c0024e0c:	83 ec 24             	sub    $0x24,%esp
c0024e0f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0024e13:	8b 74 24 34          	mov    0x34(%esp),%esi
  check_sector (block, sector);
c0024e17:	89 f2                	mov    %esi,%edx
c0024e19:	89 d8                	mov    %ebx,%eax
c0024e1b:	e8 f4 fd ff ff       	call   c0024c14 <check_sector>
  ASSERT (block->type != BLOCK_FOREIGN);
c0024e20:	83 7b 18 05          	cmpl   $0x5,0x18(%ebx)
c0024e24:	75 2c                	jne    c0024e52 <block_write+0x48>
c0024e26:	c7 44 24 10 17 ef 02 	movl   $0xc002ef17,0x10(%esp)
c0024e2d:	c0 
c0024e2e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0024e35:	c0 
c0024e36:	c7 44 24 08 bb d4 02 	movl   $0xc002d4bb,0x8(%esp)
c0024e3d:	c0 
c0024e3e:	c7 44 24 04 89 00 00 	movl   $0x89,0x4(%esp)
c0024e45:	00 
c0024e46:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024e4d:	e8 21 3b 00 00       	call   c0028973 <debug_panic>
  block->ops->write (block->aux, sector, buffer);
c0024e52:	8b 43 20             	mov    0x20(%ebx),%eax
c0024e55:	8b 54 24 38          	mov    0x38(%esp),%edx
c0024e59:	89 54 24 08          	mov    %edx,0x8(%esp)
c0024e5d:	89 74 24 04          	mov    %esi,0x4(%esp)
c0024e61:	8b 53 24             	mov    0x24(%ebx),%edx
c0024e64:	89 14 24             	mov    %edx,(%esp)
c0024e67:	ff 50 04             	call   *0x4(%eax)
  block->write_cnt++;
c0024e6a:	83 43 30 01          	addl   $0x1,0x30(%ebx)
c0024e6e:	83 53 34 00          	adcl   $0x0,0x34(%ebx)
}
c0024e72:	83 c4 24             	add    $0x24,%esp
c0024e75:	5b                   	pop    %ebx
c0024e76:	5e                   	pop    %esi
c0024e77:	c3                   	ret    

c0024e78 <block_size>:
  return block->size;
c0024e78:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e7c:	8b 40 1c             	mov    0x1c(%eax),%eax
}
c0024e7f:	c3                   	ret    

c0024e80 <block_name>:
  return block->name;
c0024e80:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e84:	83 c0 08             	add    $0x8,%eax
}
c0024e87:	c3                   	ret    

c0024e88 <block_type>:
  return block->type;
c0024e88:	8b 44 24 04          	mov    0x4(%esp),%eax
c0024e8c:	8b 40 18             	mov    0x18(%eax),%eax
}
c0024e8f:	c3                   	ret    

c0024e90 <block_print_stats>:
{
c0024e90:	56                   	push   %esi
c0024e91:	53                   	push   %ebx
c0024e92:	83 ec 24             	sub    $0x24,%esp
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024e95:	be 00 00 00 00       	mov    $0x0,%esi
      struct block *block = block_by_role[i];
c0024e9a:	8b 1c b5 18 78 03 c0 	mov    -0x3ffc87e8(,%esi,4),%ebx
      if (block != NULL)
c0024ea1:	85 db                	test   %ebx,%ebx
c0024ea3:	74 3e                	je     c0024ee3 <block_print_stats+0x53>
          printf ("%s (%s): %llu reads, %llu writes\n",
c0024ea5:	8b 43 18             	mov    0x18(%ebx),%eax
c0024ea8:	89 04 24             	mov    %eax,(%esp)
c0024eab:	e8 a3 fd ff ff       	call   c0024c53 <block_type_name>
c0024eb0:	8b 53 30             	mov    0x30(%ebx),%edx
c0024eb3:	8b 4b 34             	mov    0x34(%ebx),%ecx
c0024eb6:	89 54 24 14          	mov    %edx,0x14(%esp)
c0024eba:	89 4c 24 18          	mov    %ecx,0x18(%esp)
c0024ebe:	8b 53 28             	mov    0x28(%ebx),%edx
c0024ec1:	8b 4b 2c             	mov    0x2c(%ebx),%ecx
c0024ec4:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0024ec8:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0024ecc:	89 44 24 08          	mov    %eax,0x8(%esp)
c0024ed0:	83 c3 08             	add    $0x8,%ebx
c0024ed3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024ed7:	c7 04 24 80 ee 02 c0 	movl   $0xc002ee80,(%esp)
c0024ede:	e8 3b 1c 00 00       	call   c0026b1e <printf>
  for (i = 0; i < BLOCK_ROLE_CNT; i++)
c0024ee3:	83 c6 01             	add    $0x1,%esi
c0024ee6:	83 fe 04             	cmp    $0x4,%esi
c0024ee9:	75 af                	jne    c0024e9a <block_print_stats+0xa>
}
c0024eeb:	83 c4 24             	add    $0x24,%esp
c0024eee:	5b                   	pop    %ebx
c0024eef:	5e                   	pop    %esi
c0024ef0:	c3                   	ret    

c0024ef1 <block_register>:
{
c0024ef1:	55                   	push   %ebp
c0024ef2:	57                   	push   %edi
c0024ef3:	56                   	push   %esi
c0024ef4:	53                   	push   %ebx
c0024ef5:	83 ec 1c             	sub    $0x1c,%esp
c0024ef8:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0024efc:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
  struct block *block = malloc (sizeof *block);
c0024f00:	c7 04 24 38 00 00 00 	movl   $0x38,(%esp)
c0024f07:	e8 a8 e9 ff ff       	call   c00238b4 <malloc>
c0024f0c:	89 c6                	mov    %eax,%esi
  if (block == NULL)
c0024f0e:	85 c0                	test   %eax,%eax
c0024f10:	75 24                	jne    c0024f36 <block_register+0x45>
    PANIC ("Failed to allocate memory for block device descriptor");
c0024f12:	c7 44 24 0c a4 ee 02 	movl   $0xc002eea4,0xc(%esp)
c0024f19:	c0 
c0024f1a:	c7 44 24 08 ac d4 02 	movl   $0xc002d4ac,0x8(%esp)
c0024f21:	c0 
c0024f22:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0024f29:	00 
c0024f2a:	c7 04 24 da ee 02 c0 	movl   $0xc002eeda,(%esp)
c0024f31:	e8 3d 3a 00 00       	call   c0028973 <debug_panic>
  list_push_back (&all_blocks, &block->list_elem);
c0024f36:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f3a:	c7 04 24 4c 5a 03 c0 	movl   $0xc0035a4c,(%esp)
c0024f41:	e8 7b 40 00 00       	call   c0028fc1 <list_push_back>
  strlcpy (block->name, name, sizeof block->name);
c0024f46:	8d 6e 08             	lea    0x8(%esi),%ebp
c0024f49:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c0024f50:	00 
c0024f51:	8b 44 24 30          	mov    0x30(%esp),%eax
c0024f55:	89 44 24 04          	mov    %eax,0x4(%esp)
c0024f59:	89 2c 24             	mov    %ebp,(%esp)
c0024f5c:	e8 25 30 00 00       	call   c0027f86 <strlcpy>
  block->type = type;
c0024f61:	8b 44 24 34          	mov    0x34(%esp),%eax
c0024f65:	89 46 18             	mov    %eax,0x18(%esi)
  block->size = size;
c0024f68:	89 5e 1c             	mov    %ebx,0x1c(%esi)
  block->ops = ops;
c0024f6b:	8b 44 24 40          	mov    0x40(%esp),%eax
c0024f6f:	89 46 20             	mov    %eax,0x20(%esi)
  block->aux = aux;
c0024f72:	8b 44 24 44          	mov    0x44(%esp),%eax
c0024f76:	89 46 24             	mov    %eax,0x24(%esi)
  block->read_cnt = 0;
c0024f79:	c7 46 28 00 00 00 00 	movl   $0x0,0x28(%esi)
c0024f80:	c7 46 2c 00 00 00 00 	movl   $0x0,0x2c(%esi)
  block->write_cnt = 0;
c0024f87:	c7 46 30 00 00 00 00 	movl   $0x0,0x30(%esi)
c0024f8e:	c7 46 34 00 00 00 00 	movl   $0x0,0x34(%esi)
  printf ("%s: %'"PRDSNu" sectors (", block->name, block->size);
c0024f95:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0024f99:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0024f9d:	c7 04 24 34 ef 02 c0 	movl   $0xc002ef34,(%esp)
c0024fa4:	e8 75 1b 00 00       	call   c0026b1e <printf>
  print_human_readable_size ((uint64_t) block->size * BLOCK_SECTOR_SIZE);
c0024fa9:	8b 4e 1c             	mov    0x1c(%esi),%ecx
c0024fac:	bb 00 00 00 00       	mov    $0x0,%ebx
c0024fb1:	0f a4 cb 09          	shld   $0x9,%ecx,%ebx
c0024fb5:	c1 e1 09             	shl    $0x9,%ecx
c0024fb8:	89 0c 24             	mov    %ecx,(%esp)
c0024fbb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0024fbf:	e8 25 24 00 00       	call   c00273e9 <print_human_readable_size>
  printf (")");
c0024fc4:	c7 04 24 29 00 00 00 	movl   $0x29,(%esp)
c0024fcb:	e8 3c 57 00 00       	call   c002a70c <putchar>
  if (extra_info != NULL)
c0024fd0:	85 ff                	test   %edi,%edi
c0024fd2:	74 10                	je     c0024fe4 <block_register+0xf3>
    printf (", %s", extra_info);
c0024fd4:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0024fd8:	c7 04 24 46 ef 02 c0 	movl   $0xc002ef46,(%esp)
c0024fdf:	e8 3a 1b 00 00       	call   c0026b1e <printf>
  printf ("\n");
c0024fe4:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0024feb:	e8 1c 57 00 00       	call   c002a70c <putchar>
}
c0024ff0:	89 f0                	mov    %esi,%eax
c0024ff2:	83 c4 1c             	add    $0x1c,%esp
c0024ff5:	5b                   	pop    %ebx
c0024ff6:	5e                   	pop    %esi
c0024ff7:	5f                   	pop    %edi
c0024ff8:	5d                   	pop    %ebp
c0024ff9:	c3                   	ret    

c0024ffa <partition_read>:

/* Reads sector SECTOR from partition P into BUFFER, which must
   have room for BLOCK_SECTOR_SIZE bytes. */
static void
partition_read (void *p_, block_sector_t sector, void *buffer)
{
c0024ffa:	83 ec 1c             	sub    $0x1c,%esp
c0024ffd:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_read (p->block, p->start + sector, buffer);
c0025001:	8b 54 24 28          	mov    0x28(%esp),%edx
c0025005:	89 54 24 08          	mov    %edx,0x8(%esp)
c0025009:	8b 54 24 24          	mov    0x24(%esp),%edx
c002500d:	03 50 04             	add    0x4(%eax),%edx
c0025010:	89 54 24 04          	mov    %edx,0x4(%esp)
c0025014:	8b 00                	mov    (%eax),%eax
c0025016:	89 04 24             	mov    %eax,(%esp)
c0025019:	e8 b1 fd ff ff       	call   c0024dcf <block_read>
}
c002501e:	83 c4 1c             	add    $0x1c,%esp
c0025021:	c3                   	ret    

c0025022 <read_partition_table>:
{
c0025022:	55                   	push   %ebp
c0025023:	57                   	push   %edi
c0025024:	56                   	push   %esi
c0025025:	53                   	push   %ebx
c0025026:	81 ec dc 00 00 00    	sub    $0xdc,%esp
c002502c:	89 c5                	mov    %eax,%ebp
c002502e:	89 d6                	mov    %edx,%esi
c0025030:	89 4c 24 20          	mov    %ecx,0x20(%esp)
  if (sector >= block_size (block))
c0025034:	89 04 24             	mov    %eax,(%esp)
c0025037:	e8 3c fe ff ff       	call   c0024e78 <block_size>
c002503c:	39 f0                	cmp    %esi,%eax
c002503e:	77 21                	ja     c0025061 <read_partition_table+0x3f>
      printf ("%s: Partition table at sector %"PRDSNu" past end of device.\n",
c0025040:	89 2c 24             	mov    %ebp,(%esp)
c0025043:	e8 38 fe ff ff       	call   c0024e80 <block_name>
c0025048:	89 74 24 08          	mov    %esi,0x8(%esp)
c002504c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025050:	c7 04 24 f8 f3 02 c0 	movl   $0xc002f3f8,(%esp)
c0025057:	e8 c2 1a 00 00       	call   c0026b1e <printf>
      return;
c002505c:	e9 3b 03 00 00       	jmp    c002539c <read_partition_table+0x37a>
  pt = malloc (sizeof *pt);
c0025061:	c7 04 24 00 02 00 00 	movl   $0x200,(%esp)
c0025068:	e8 47 e8 ff ff       	call   c00238b4 <malloc>
c002506d:	89 c7                	mov    %eax,%edi
  if (pt == NULL)
c002506f:	85 c0                	test   %eax,%eax
c0025071:	75 24                	jne    c0025097 <read_partition_table+0x75>
    PANIC ("Failed to allocate memory for partition table.");
c0025073:	c7 44 24 0c 30 f4 02 	movl   $0xc002f430,0xc(%esp)
c002507a:	c0 
c002507b:	c7 44 24 08 30 d9 02 	movl   $0xc002d930,0x8(%esp)
c0025082:	c0 
c0025083:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c002508a:	00 
c002508b:	c7 04 24 67 ef 02 c0 	movl   $0xc002ef67,(%esp)
c0025092:	e8 dc 38 00 00       	call   c0028973 <debug_panic>
  block_read (block, 0, pt);
c0025097:	89 44 24 08          	mov    %eax,0x8(%esp)
c002509b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00250a2:	00 
c00250a3:	89 2c 24             	mov    %ebp,(%esp)
c00250a6:	e8 24 fd ff ff       	call   c0024dcf <block_read>
  if (pt->signature != 0xaa55)
c00250ab:	66 81 bf fe 01 00 00 	cmpw   $0xaa55,0x1fe(%edi)
c00250b2:	55 aa 
c00250b4:	74 4a                	je     c0025100 <read_partition_table+0xde>
      if (primary_extended_sector == 0)
c00250b6:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c00250bb:	75 1a                	jne    c00250d7 <read_partition_table+0xb5>
        printf ("%s: Invalid partition table signature\n", block_name (block));
c00250bd:	89 2c 24             	mov    %ebp,(%esp)
c00250c0:	e8 bb fd ff ff       	call   c0024e80 <block_name>
c00250c5:	89 44 24 04          	mov    %eax,0x4(%esp)
c00250c9:	c7 04 24 60 f4 02 c0 	movl   $0xc002f460,(%esp)
c00250d0:	e8 49 1a 00 00       	call   c0026b1e <printf>
c00250d5:	eb 1c                	jmp    c00250f3 <read_partition_table+0xd1>
        printf ("%s: Invalid extended partition table in sector %"PRDSNu"\n",
c00250d7:	89 2c 24             	mov    %ebp,(%esp)
c00250da:	e8 a1 fd ff ff       	call   c0024e80 <block_name>
c00250df:	89 74 24 08          	mov    %esi,0x8(%esp)
c00250e3:	89 44 24 04          	mov    %eax,0x4(%esp)
c00250e7:	c7 04 24 88 f4 02 c0 	movl   $0xc002f488,(%esp)
c00250ee:	e8 2b 1a 00 00       	call   c0026b1e <printf>
      free (pt);
c00250f3:	89 3c 24             	mov    %edi,(%esp)
c00250f6:	e8 40 e9 ff ff       	call   c0023a3b <free>
      return;
c00250fb:	e9 9c 02 00 00       	jmp    c002539c <read_partition_table+0x37a>
c0025100:	89 fb                	mov    %edi,%ebx
  if (pt->signature != 0xaa55)
c0025102:	b8 04 00 00 00       	mov    $0x4,%eax
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025107:	89 7c 24 28          	mov    %edi,0x28(%esp)
c002510b:	89 74 24 24          	mov    %esi,0x24(%esp)
c002510f:	89 c6                	mov    %eax,%esi
c0025111:	89 df                	mov    %ebx,%edi
      if (e->size == 0 || e->type == 0)
c0025113:	83 bb ca 01 00 00 00 	cmpl   $0x0,0x1ca(%ebx)
c002511a:	0f 84 64 02 00 00    	je     c0025384 <read_partition_table+0x362>
c0025120:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c0025127:	84 c0                	test   %al,%al
c0025129:	0f 84 55 02 00 00    	je     c0025384 <read_partition_table+0x362>
               || e->type == 0x0f    /* Windows 98 extended partition. */
c002512f:	89 c2                	mov    %eax,%edx
c0025131:	83 e2 7f             	and    $0x7f,%edx
      else if (e->type == 0x05       /* Extended partition. */
c0025134:	80 fa 05             	cmp    $0x5,%dl
c0025137:	74 08                	je     c0025141 <read_partition_table+0x11f>
c0025139:	3c 0f                	cmp    $0xf,%al
c002513b:	74 04                	je     c0025141 <read_partition_table+0x11f>
               || e->type == 0xc5)   /* DR-DOS extended partition. */
c002513d:	3c c5                	cmp    $0xc5,%al
c002513f:	75 67                	jne    c00251a8 <read_partition_table+0x186>
          printf ("%s: Extended partition in sector %"PRDSNu"\n",
c0025141:	89 2c 24             	mov    %ebp,(%esp)
c0025144:	e8 37 fd ff ff       	call   c0024e80 <block_name>
c0025149:	8b 4c 24 24          	mov    0x24(%esp),%ecx
c002514d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0025151:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025155:	c7 04 24 bc f4 02 c0 	movl   $0xc002f4bc,(%esp)
c002515c:	e8 bd 19 00 00       	call   c0026b1e <printf>
          if (sector == 0)
c0025161:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0025166:	75 1e                	jne    c0025186 <read_partition_table+0x164>
            read_partition_table (block, e->offset, e->offset, part_nr);
c0025168:	8b 97 c6 01 00 00    	mov    0x1c6(%edi),%edx
c002516e:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c0025175:	89 04 24             	mov    %eax,(%esp)
c0025178:	89 d1                	mov    %edx,%ecx
c002517a:	89 e8                	mov    %ebp,%eax
c002517c:	e8 a1 fe ff ff       	call   c0025022 <read_partition_table>
c0025181:	e9 fe 01 00 00       	jmp    c0025384 <read_partition_table+0x362>
            read_partition_table (block, e->offset + primary_extended_sector,
c0025186:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c002518a:	89 ca                	mov    %ecx,%edx
c002518c:	03 97 c6 01 00 00    	add    0x1c6(%edi),%edx
c0025192:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c0025199:	89 04 24             	mov    %eax,(%esp)
c002519c:	89 e8                	mov    %ebp,%eax
c002519e:	e8 7f fe ff ff       	call   c0025022 <read_partition_table>
c00251a3:	e9 dc 01 00 00       	jmp    c0025384 <read_partition_table+0x362>
          ++*part_nr;
c00251a8:	8b 84 24 f0 00 00 00 	mov    0xf0(%esp),%eax
c00251af:	8b 00                	mov    (%eax),%eax
c00251b1:	83 c0 01             	add    $0x1,%eax
c00251b4:	89 44 24 34          	mov    %eax,0x34(%esp)
c00251b8:	8b 8c 24 f0 00 00 00 	mov    0xf0(%esp),%ecx
c00251bf:	89 01                	mov    %eax,(%ecx)
          found_partition (block, e->type, e->offset + sector,
c00251c1:	8b 83 ca 01 00 00    	mov    0x1ca(%ebx),%eax
c00251c7:	89 44 24 30          	mov    %eax,0x30(%esp)
c00251cb:	8b 44 24 24          	mov    0x24(%esp),%eax
c00251cf:	03 83 c6 01 00 00    	add    0x1c6(%ebx),%eax
c00251d5:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c00251d9:	0f b6 83 c2 01 00 00 	movzbl 0x1c2(%ebx),%eax
c00251e0:	88 44 24 3b          	mov    %al,0x3b(%esp)
  if (start >= block_size (block))
c00251e4:	89 2c 24             	mov    %ebp,(%esp)
c00251e7:	e8 8c fc ff ff       	call   c0024e78 <block_size>
c00251ec:	39 44 24 2c          	cmp    %eax,0x2c(%esp)
c00251f0:	72 2d                	jb     c002521f <read_partition_table+0x1fd>
    printf ("%s%d: Partition starts past end of device (sector %"PRDSNu")\n",
c00251f2:	89 2c 24             	mov    %ebp,(%esp)
c00251f5:	e8 86 fc ff ff       	call   c0024e80 <block_name>
c00251fa:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c00251fe:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0025202:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025206:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002520a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002520e:	c7 04 24 e4 f4 02 c0 	movl   $0xc002f4e4,(%esp)
c0025215:	e8 04 19 00 00       	call   c0026b1e <printf>
c002521a:	e9 65 01 00 00       	jmp    c0025384 <read_partition_table+0x362>
  else if (start + size < start || start + size > block_size (block))
c002521f:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
c0025223:	03 7c 24 30          	add    0x30(%esp),%edi
c0025227:	72 0c                	jb     c0025235 <read_partition_table+0x213>
c0025229:	89 2c 24             	mov    %ebp,(%esp)
c002522c:	e8 47 fc ff ff       	call   c0024e78 <block_size>
c0025231:	39 c7                	cmp    %eax,%edi
c0025233:	76 3d                	jbe    c0025272 <read_partition_table+0x250>
    printf ("%s%d: Partition end (%"PRDSNu") past end of device (%"PRDSNu")\n",
c0025235:	89 2c 24             	mov    %ebp,(%esp)
c0025238:	e8 3b fc ff ff       	call   c0024e78 <block_size>
c002523d:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c0025241:	89 2c 24             	mov    %ebp,(%esp)
c0025244:	e8 37 fc ff ff       	call   c0024e80 <block_name>
c0025249:	8b 4c 24 2c          	mov    0x2c(%esp),%ecx
c002524d:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0025251:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025255:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0025259:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002525d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025261:	c7 04 24 1c f5 02 c0 	movl   $0xc002f51c,(%esp)
c0025268:	e8 b1 18 00 00       	call   c0026b1e <printf>
c002526d:	e9 12 01 00 00       	jmp    c0025384 <read_partition_table+0x362>
      enum block_type type = (part_type == 0x20 ? BLOCK_KERNEL
c0025272:	c7 44 24 3c 00 00 00 	movl   $0x0,0x3c(%esp)
c0025279:	00 
c002527a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
c002527f:	3c 20                	cmp    $0x20,%al
c0025281:	74 28                	je     c00252ab <read_partition_table+0x289>
c0025283:	c7 44 24 3c 01 00 00 	movl   $0x1,0x3c(%esp)
c002528a:	00 
c002528b:	3c 21                	cmp    $0x21,%al
c002528d:	74 1c                	je     c00252ab <read_partition_table+0x289>
c002528f:	c7 44 24 3c 02 00 00 	movl   $0x2,0x3c(%esp)
c0025296:	00 
c0025297:	3c 22                	cmp    $0x22,%al
c0025299:	74 10                	je     c00252ab <read_partition_table+0x289>
c002529b:	3c 23                	cmp    $0x23,%al
c002529d:	0f 95 c0             	setne  %al
c00252a0:	0f b6 c0             	movzbl %al,%eax
c00252a3:	8d 44 00 03          	lea    0x3(%eax,%eax,1),%eax
c00252a7:	89 44 24 3c          	mov    %eax,0x3c(%esp)
      p = malloc (sizeof *p);
c00252ab:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c00252b2:	e8 fd e5 ff ff       	call   c00238b4 <malloc>
c00252b7:	89 c7                	mov    %eax,%edi
      if (p == NULL)
c00252b9:	85 c0                	test   %eax,%eax
c00252bb:	75 24                	jne    c00252e1 <read_partition_table+0x2bf>
        PANIC ("Failed to allocate memory for partition descriptor");
c00252bd:	c7 44 24 0c 50 f5 02 	movl   $0xc002f550,0xc(%esp)
c00252c4:	c0 
c00252c5:	c7 44 24 08 20 d9 02 	movl   $0xc002d920,0x8(%esp)
c00252cc:	c0 
c00252cd:	c7 44 24 04 b1 00 00 	movl   $0xb1,0x4(%esp)
c00252d4:	00 
c00252d5:	c7 04 24 67 ef 02 c0 	movl   $0xc002ef67,(%esp)
c00252dc:	e8 92 36 00 00       	call   c0028973 <debug_panic>
      p->block = block;
c00252e1:	89 28                	mov    %ebp,(%eax)
      p->start = start;
c00252e3:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00252e7:	89 47 04             	mov    %eax,0x4(%edi)
      snprintf (name, sizeof name, "%s%d", block_name (block), part_nr);
c00252ea:	89 2c 24             	mov    %ebp,(%esp)
c00252ed:	e8 8e fb ff ff       	call   c0024e80 <block_name>
c00252f2:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c00252f6:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c00252fa:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00252fe:	c7 44 24 08 81 ef 02 	movl   $0xc002ef81,0x8(%esp)
c0025305:	c0 
c0025306:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002530d:	00 
c002530e:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025312:	89 04 24             	mov    %eax,(%esp)
c0025315:	e8 05 1f 00 00       	call   c002721f <snprintf>
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c002531a:	0f b6 44 24 3b       	movzbl 0x3b(%esp),%eax
  return type_names[type] != NULL ? type_names[type] : "Unknown";
c002531f:	8b 14 85 20 d5 02 c0 	mov    -0x3ffd2ae0(,%eax,4),%edx
c0025326:	85 d2                	test   %edx,%edx
c0025328:	b9 5f ef 02 c0       	mov    $0xc002ef5f,%ecx
c002532d:	0f 44 d1             	cmove  %ecx,%edx
      snprintf (extra_info, sizeof extra_info, "%s (%02x)",
c0025330:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025334:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0025338:	c7 44 24 08 86 ef 02 	movl   $0xc002ef86,0x8(%esp)
c002533f:	c0 
c0025340:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025347:	00 
c0025348:	8d 44 24 50          	lea    0x50(%esp),%eax
c002534c:	89 04 24             	mov    %eax,(%esp)
c002534f:	e8 cb 1e 00 00       	call   c002721f <snprintf>
      block_register (name, type, extra_info, size, &partition_operations, p);
c0025354:	89 7c 24 14          	mov    %edi,0x14(%esp)
c0025358:	c7 44 24 10 5c 5a 03 	movl   $0xc0035a5c,0x10(%esp)
c002535f:	c0 
c0025360:	8b 44 24 30          	mov    0x30(%esp),%eax
c0025364:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025368:	8d 44 24 50          	lea    0x50(%esp),%eax
c002536c:	89 44 24 08          	mov    %eax,0x8(%esp)
c0025370:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c0025374:	89 44 24 04          	mov    %eax,0x4(%esp)
c0025378:	8d 44 24 40          	lea    0x40(%esp),%eax
c002537c:	89 04 24             	mov    %eax,(%esp)
c002537f:	e8 6d fb ff ff       	call   c0024ef1 <block_register>
c0025384:	83 c3 10             	add    $0x10,%ebx
  for (i = 0; i < sizeof pt->partitions / sizeof *pt->partitions; i++)
c0025387:	83 ee 01             	sub    $0x1,%esi
c002538a:	0f 85 81 fd ff ff    	jne    c0025111 <read_partition_table+0xef>
c0025390:	8b 7c 24 28          	mov    0x28(%esp),%edi
  free (pt);
c0025394:	89 3c 24             	mov    %edi,(%esp)
c0025397:	e8 9f e6 ff ff       	call   c0023a3b <free>
}
c002539c:	81 c4 dc 00 00 00    	add    $0xdc,%esp
c00253a2:	5b                   	pop    %ebx
c00253a3:	5e                   	pop    %esi
c00253a4:	5f                   	pop    %edi
c00253a5:	5d                   	pop    %ebp
c00253a6:	c3                   	ret    

c00253a7 <partition_write>:
/* Write sector SECTOR to partition P from BUFFER, which must
   contain BLOCK_SECTOR_SIZE bytes.  Returns after the block has
   acknowledged receiving the data. */
static void
partition_write (void *p_, block_sector_t sector, const void *buffer)
{
c00253a7:	83 ec 1c             	sub    $0x1c,%esp
c00253aa:	8b 44 24 20          	mov    0x20(%esp),%eax
  struct partition *p = p_;
  block_write (p->block, p->start + sector, buffer);
c00253ae:	8b 54 24 28          	mov    0x28(%esp),%edx
c00253b2:	89 54 24 08          	mov    %edx,0x8(%esp)
c00253b6:	8b 54 24 24          	mov    0x24(%esp),%edx
c00253ba:	03 50 04             	add    0x4(%eax),%edx
c00253bd:	89 54 24 04          	mov    %edx,0x4(%esp)
c00253c1:	8b 00                	mov    (%eax),%eax
c00253c3:	89 04 24             	mov    %eax,(%esp)
c00253c6:	e8 3f fa ff ff       	call   c0024e0a <block_write>
}
c00253cb:	83 c4 1c             	add    $0x1c,%esp
c00253ce:	c3                   	ret    

c00253cf <partition_scan>:
{
c00253cf:	53                   	push   %ebx
c00253d0:	83 ec 28             	sub    $0x28,%esp
c00253d3:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  int part_nr = 0;
c00253d7:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c00253de:	00 
  read_partition_table (block, 0, 0, &part_nr);
c00253df:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c00253e3:	89 04 24             	mov    %eax,(%esp)
c00253e6:	b9 00 00 00 00       	mov    $0x0,%ecx
c00253eb:	ba 00 00 00 00       	mov    $0x0,%edx
c00253f0:	89 d8                	mov    %ebx,%eax
c00253f2:	e8 2b fc ff ff       	call   c0025022 <read_partition_table>
  if (part_nr == 0)
c00253f7:	83 7c 24 1c 00       	cmpl   $0x0,0x1c(%esp)
c00253fc:	75 18                	jne    c0025416 <partition_scan+0x47>
    printf ("%s: Device contains no partitions\n", block_name (block));
c00253fe:	89 1c 24             	mov    %ebx,(%esp)
c0025401:	e8 7a fa ff ff       	call   c0024e80 <block_name>
c0025406:	89 44 24 04          	mov    %eax,0x4(%esp)
c002540a:	c7 04 24 84 f5 02 c0 	movl   $0xc002f584,(%esp)
c0025411:	e8 08 17 00 00       	call   c0026b1e <printf>
}
c0025416:	83 c4 28             	add    $0x28,%esp
c0025419:	5b                   	pop    %ebx
c002541a:	c3                   	ret    
c002541b:	90                   	nop
c002541c:	90                   	nop
c002541d:	90                   	nop
c002541e:	90                   	nop
c002541f:	90                   	nop

c0025420 <descramble_ata_string>:
/* Translates STRING, which consists of SIZE bytes in a funky
   format, into a null-terminated string in-place.  Drops
   trailing whitespace and null bytes.  Returns STRING.  */
static char *
descramble_ata_string (char *string, int size) 
{
c0025420:	57                   	push   %edi
c0025421:	56                   	push   %esi
c0025422:	53                   	push   %ebx
c0025423:	89 d7                	mov    %edx,%edi
  int i;

  /* Swap all pairs of bytes. */
  for (i = 0; i + 1 < size; i += 2)
c0025425:	83 fa 01             	cmp    $0x1,%edx
c0025428:	7e 1f                	jle    c0025449 <descramble_ata_string+0x29>
c002542a:	89 c1                	mov    %eax,%ecx
c002542c:	8d 5a fe             	lea    -0x2(%edx),%ebx
c002542f:	83 e3 fe             	and    $0xfffffffe,%ebx
c0025432:	8d 74 18 02          	lea    0x2(%eax,%ebx,1),%esi
    {
      char tmp = string[i];
c0025436:	0f b6 19             	movzbl (%ecx),%ebx
      string[i] = string[i + 1];
c0025439:	0f b6 51 01          	movzbl 0x1(%ecx),%edx
c002543d:	88 11                	mov    %dl,(%ecx)
      string[i + 1] = tmp;
c002543f:	88 59 01             	mov    %bl,0x1(%ecx)
c0025442:	83 c1 02             	add    $0x2,%ecx
  for (i = 0; i + 1 < size; i += 2)
c0025445:	39 f1                	cmp    %esi,%ecx
c0025447:	75 ed                	jne    c0025436 <descramble_ata_string+0x16>
    }

  /* Find the last non-white, non-null character. */
  for (size--; size > 0; size--)
c0025449:	8d 57 ff             	lea    -0x1(%edi),%edx
c002544c:	85 d2                	test   %edx,%edx
c002544e:	7e 24                	jle    c0025474 <descramble_ata_string+0x54>
    {
      int c = string[size - 1];
c0025450:	0f b6 4c 10 ff       	movzbl -0x1(%eax,%edx,1),%ecx
      if (c != '\0' && !isspace (c))
c0025455:	f6 c1 df             	test   $0xdf,%cl
c0025458:	74 15                	je     c002546f <descramble_ata_string+0x4f>
  return (c == ' ' || c == '\f' || c == '\n'
c002545a:	8d 59 f4             	lea    -0xc(%ecx),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c002545d:	80 fb 01             	cmp    $0x1,%bl
c0025460:	76 0d                	jbe    c002546f <descramble_ata_string+0x4f>
c0025462:	80 f9 0a             	cmp    $0xa,%cl
c0025465:	74 08                	je     c002546f <descramble_ata_string+0x4f>
c0025467:	83 e1 fd             	and    $0xfffffffd,%ecx
c002546a:	80 f9 09             	cmp    $0x9,%cl
c002546d:	75 05                	jne    c0025474 <descramble_ata_string+0x54>
  for (size--; size > 0; size--)
c002546f:	83 ea 01             	sub    $0x1,%edx
c0025472:	75 dc                	jne    c0025450 <descramble_ata_string+0x30>
        break; 
    }
  string[size] = '\0';
c0025474:	c6 04 10 00          	movb   $0x0,(%eax,%edx,1)

  return string;
}
c0025478:	5b                   	pop    %ebx
c0025479:	5e                   	pop    %esi
c002547a:	5f                   	pop    %edi
c002547b:	c3                   	ret    

c002547c <interrupt_handler>:
}

/* ATA interrupt handler. */
static void
interrupt_handler (struct intr_frame *f) 
{
c002547c:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c;

  for (c = channels; c < channels + CHANNEL_CNT; c++)
    if (f->vec_no == c->irq)
c002547f:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025483:	8b 40 30             	mov    0x30(%eax),%eax
c0025486:	0f b6 15 4a 78 03 c0 	movzbl 0xc003784a,%edx
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c002548d:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
    if (f->vec_no == c->irq)
c0025492:	39 d0                	cmp    %edx,%eax
c0025494:	75 3e                	jne    c00254d4 <interrupt_handler+0x58>
c0025496:	eb 0a                	jmp    c00254a2 <interrupt_handler+0x26>
c0025498:	0f b6 51 0a          	movzbl 0xa(%ecx),%edx
c002549c:	39 c2                	cmp    %eax,%edx
c002549e:	75 34                	jne    c00254d4 <interrupt_handler+0x58>
c00254a0:	eb 05                	jmp    c00254a7 <interrupt_handler+0x2b>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254a2:	b9 40 78 03 c0       	mov    $0xc0037840,%ecx
      {
        if (c->expecting_interrupt) 
c00254a7:	80 79 30 00          	cmpb   $0x0,0x30(%ecx)
c00254ab:	74 15                	je     c00254c2 <interrupt_handler+0x46>
          {
            inb (reg_status (c));               /* Acknowledge interrupt. */
c00254ad:	0f b7 41 08          	movzwl 0x8(%ecx),%eax
c00254b1:	8d 50 07             	lea    0x7(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00254b4:	ec                   	in     (%dx),%al
            sema_up (&c->completion_wait);      /* Wake up waiter. */
c00254b5:	83 c1 34             	add    $0x34,%ecx
c00254b8:	89 0c 24             	mov    %ecx,(%esp)
c00254bb:	e8 17 d6 ff ff       	call   c0022ad7 <sema_up>
c00254c0:	eb 41                	jmp    c0025503 <interrupt_handler+0x87>
          }
        else
          printf ("%s: unexpected interrupt\n", c->name);
c00254c2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00254c6:	c7 04 24 a7 f5 02 c0 	movl   $0xc002f5a7,(%esp)
c00254cd:	e8 4c 16 00 00       	call   c0026b1e <printf>
c00254d2:	eb 2f                	jmp    c0025503 <interrupt_handler+0x87>
  for (c = channels; c < channels + CHANNEL_CNT; c++)
c00254d4:	83 c1 70             	add    $0x70,%ecx
c00254d7:	81 f9 20 79 03 c0    	cmp    $0xc0037920,%ecx
c00254dd:	72 b9                	jb     c0025498 <interrupt_handler+0x1c>
        return;
      }

  NOT_REACHED ();
c00254df:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c00254e6:	c0 
c00254e7:	c7 44 24 08 8c d9 02 	movl   $0xc002d98c,0x8(%esp)
c00254ee:	c0 
c00254ef:	c7 44 24 04 0c 02 00 	movl   $0x20c,0x4(%esp)
c00254f6:	00 
c00254f7:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c00254fe:	e8 70 34 00 00       	call   c0028973 <debug_panic>
}
c0025503:	83 c4 1c             	add    $0x1c,%esp
c0025506:	c3                   	ret    

c0025507 <wait_until_idle>:
{
c0025507:	56                   	push   %esi
c0025508:	53                   	push   %ebx
c0025509:	83 ec 14             	sub    $0x14,%esp
c002550c:	89 c6                	mov    %eax,%esi
      if ((inb (reg_status (d->channel)) & (STA_BSY | STA_DRQ)) == 0)
c002550e:	8b 40 08             	mov    0x8(%eax),%eax
c0025511:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025515:	83 c2 07             	add    $0x7,%edx
c0025518:	ec                   	in     (%dx),%al
c0025519:	a8 88                	test   $0x88,%al
c002551b:	75 3c                	jne    c0025559 <wait_until_idle+0x52>
c002551d:	eb 55                	jmp    c0025574 <wait_until_idle+0x6d>
c002551f:	8b 46 08             	mov    0x8(%esi),%eax
c0025522:	0f b7 50 08          	movzwl 0x8(%eax),%edx
c0025526:	83 c2 07             	add    $0x7,%edx
c0025529:	ec                   	in     (%dx),%al
c002552a:	a8 88                	test   $0x88,%al
c002552c:	74 46                	je     c0025574 <wait_until_idle+0x6d>
      timer_usleep (10);
c002552e:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025535:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002553c:	00 
c002553d:	e8 5e ee ff ff       	call   c00243a0 <timer_usleep>
  for (i = 0; i < 1000; i++) 
c0025542:	83 eb 01             	sub    $0x1,%ebx
c0025545:	75 d8                	jne    c002551f <wait_until_idle+0x18>
  printf ("%s: idle timeout\n", d->name);
c0025547:	89 74 24 04          	mov    %esi,0x4(%esp)
c002554b:	c7 04 24 d5 f5 02 c0 	movl   $0xc002f5d5,(%esp)
c0025552:	e8 c7 15 00 00       	call   c0026b1e <printf>
c0025557:	eb 1b                	jmp    c0025574 <wait_until_idle+0x6d>
      timer_usleep (10);
c0025559:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025560:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025567:	00 
c0025568:	e8 33 ee ff ff       	call   c00243a0 <timer_usleep>
c002556d:	bb e7 03 00 00       	mov    $0x3e7,%ebx
c0025572:	eb ab                	jmp    c002551f <wait_until_idle+0x18>
}
c0025574:	83 c4 14             	add    $0x14,%esp
c0025577:	5b                   	pop    %ebx
c0025578:	5e                   	pop    %esi
c0025579:	c3                   	ret    

c002557a <select_device>:
{
c002557a:	83 ec 1c             	sub    $0x1c,%esp
  struct channel *c = d->channel;
c002557d:	8b 50 08             	mov    0x8(%eax),%edx
  if (d->dev_no == 1)
c0025580:	83 78 0c 01          	cmpl   $0x1,0xc(%eax)
  uint8_t dev = DEV_MBS;
c0025584:	b8 a0 ff ff ff       	mov    $0xffffffa0,%eax
c0025589:	b9 b0 ff ff ff       	mov    $0xffffffb0,%ecx
c002558e:	0f 44 c1             	cmove  %ecx,%eax
  outb (reg_device (c), dev);
c0025591:	0f b7 4a 08          	movzwl 0x8(%edx),%ecx
c0025595:	8d 51 06             	lea    0x6(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025598:	ee                   	out    %al,(%dx)
  inb (reg_alt_status (c));
c0025599:	8d 91 06 02 00 00    	lea    0x206(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002559f:	ec                   	in     (%dx),%al
  timer_nsleep (400);
c00255a0:	c7 04 24 90 01 00 00 	movl   $0x190,(%esp)
c00255a7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00255ae:	00 
c00255af:	e8 05 ee ff ff       	call   c00243b9 <timer_nsleep>
}
c00255b4:	83 c4 1c             	add    $0x1c,%esp
c00255b7:	c3                   	ret    

c00255b8 <check_device_type>:
{
c00255b8:	55                   	push   %ebp
c00255b9:	57                   	push   %edi
c00255ba:	56                   	push   %esi
c00255bb:	53                   	push   %ebx
c00255bc:	83 ec 0c             	sub    $0xc,%esp
c00255bf:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c00255c1:	8b 70 08             	mov    0x8(%eax),%esi
  select_device (d);
c00255c4:	e8 b1 ff ff ff       	call   c002557a <select_device>
  error = inb (reg_error (c));
c00255c9:	0f b7 4e 08          	movzwl 0x8(%esi),%ecx
c00255cd:	8d 51 01             	lea    0x1(%ecx),%edx
c00255d0:	ec                   	in     (%dx),%al
c00255d1:	89 c6                	mov    %eax,%esi
  lbam = inb (reg_lbam (c));
c00255d3:	8d 51 04             	lea    0x4(%ecx),%edx
c00255d6:	ec                   	in     (%dx),%al
c00255d7:	89 c7                	mov    %eax,%edi
  lbah = inb (reg_lbah (c));
c00255d9:	8d 51 05             	lea    0x5(%ecx),%edx
c00255dc:	ec                   	in     (%dx),%al
c00255dd:	89 c5                	mov    %eax,%ebp
  status = inb (reg_status (c));
c00255df:	8d 51 07             	lea    0x7(%ecx),%edx
c00255e2:	ec                   	in     (%dx),%al
  if ((error != 1 && (error != 0x81 || d->dev_no == 1))
c00255e3:	89 f1                	mov    %esi,%ecx
c00255e5:	80 f9 01             	cmp    $0x1,%cl
c00255e8:	74 0b                	je     c00255f5 <check_device_type+0x3d>
c00255ea:	80 f9 81             	cmp    $0x81,%cl
c00255ed:	75 0e                	jne    c00255fd <check_device_type+0x45>
c00255ef:	83 7b 0c 01          	cmpl   $0x1,0xc(%ebx)
c00255f3:	74 08                	je     c00255fd <check_device_type+0x45>
      || (status & STA_DRDY) == 0
c00255f5:	a8 40                	test   $0x40,%al
c00255f7:	74 04                	je     c00255fd <check_device_type+0x45>
      || (status & STA_BSY) != 0)
c00255f9:	84 c0                	test   %al,%al
c00255fb:	79 0d                	jns    c002560a <check_device_type+0x52>
      d->is_ata = false;
c00255fd:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return error != 0x81;      
c0025601:	89 f0                	mov    %esi,%eax
c0025603:	3c 81                	cmp    $0x81,%al
c0025605:	0f 95 c0             	setne  %al
c0025608:	eb 2b                	jmp    c0025635 <check_device_type+0x7d>
      d->is_ata = (lbam == 0 && lbah == 0) || (lbam == 0x3c && lbah == 0xc3);
c002560a:	b8 01 00 00 00       	mov    $0x1,%eax
c002560f:	89 ea                	mov    %ebp,%edx
c0025611:	89 f9                	mov    %edi,%ecx
c0025613:	08 ca                	or     %cl,%dl
c0025615:	74 12                	je     c0025629 <check_device_type+0x71>
c0025617:	89 e8                	mov    %ebp,%eax
c0025619:	3c c3                	cmp    $0xc3,%al
c002561b:	0f 94 c0             	sete   %al
c002561e:	80 f9 3c             	cmp    $0x3c,%cl
c0025621:	0f 94 c2             	sete   %dl
c0025624:	0f b6 d2             	movzbl %dl,%edx
c0025627:	21 d0                	and    %edx,%eax
c0025629:	88 43 10             	mov    %al,0x10(%ebx)
c002562c:	80 63 10 01          	andb   $0x1,0x10(%ebx)
      return true; 
c0025630:	b8 01 00 00 00       	mov    $0x1,%eax
}
c0025635:	83 c4 0c             	add    $0xc,%esp
c0025638:	5b                   	pop    %ebx
c0025639:	5e                   	pop    %esi
c002563a:	5f                   	pop    %edi
c002563b:	5d                   	pop    %ebp
c002563c:	c3                   	ret    

c002563d <select_sector>:
{
c002563d:	57                   	push   %edi
c002563e:	56                   	push   %esi
c002563f:	53                   	push   %ebx
c0025640:	83 ec 20             	sub    $0x20,%esp
c0025643:	89 c6                	mov    %eax,%esi
c0025645:	89 d3                	mov    %edx,%ebx
  struct channel *c = d->channel;
c0025647:	8b 78 08             	mov    0x8(%eax),%edi
  ASSERT (sec_no < (1UL << 28));
c002564a:	81 fa ff ff ff 0f    	cmp    $0xfffffff,%edx
c0025650:	76 2c                	jbe    c002567e <select_sector+0x41>
c0025652:	c7 44 24 10 e7 f5 02 	movl   $0xc002f5e7,0x10(%esp)
c0025659:	c0 
c002565a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025661:	c0 
c0025662:	c7 44 24 08 60 d9 02 	movl   $0xc002d960,0x8(%esp)
c0025669:	c0 
c002566a:	c7 44 24 04 89 01 00 	movl   $0x189,0x4(%esp)
c0025671:	00 
c0025672:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025679:	e8 f5 32 00 00       	call   c0028973 <debug_panic>
  wait_until_idle (d);
c002567e:	e8 84 fe ff ff       	call   c0025507 <wait_until_idle>
  select_device (d);
c0025683:	89 f0                	mov    %esi,%eax
c0025685:	e8 f0 fe ff ff       	call   c002557a <select_device>
  wait_until_idle (d);
c002568a:	89 f0                	mov    %esi,%eax
c002568c:	e8 76 fe ff ff       	call   c0025507 <wait_until_idle>
  outb (reg_nsect (c), 1);
c0025691:	0f b7 4f 08          	movzwl 0x8(%edi),%ecx
c0025695:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025698:	b8 01 00 00 00       	mov    $0x1,%eax
c002569d:	ee                   	out    %al,(%dx)
  outb (reg_lbal (c), sec_no);
c002569e:	8d 51 03             	lea    0x3(%ecx),%edx
c00256a1:	89 d8                	mov    %ebx,%eax
c00256a3:	ee                   	out    %al,(%dx)
c00256a4:	0f b6 c7             	movzbl %bh,%eax
  outb (reg_lbam (c), sec_no >> 8);
c00256a7:	8d 51 04             	lea    0x4(%ecx),%edx
c00256aa:	ee                   	out    %al,(%dx)
  outb (reg_lbah (c), (sec_no >> 16));
c00256ab:	89 d8                	mov    %ebx,%eax
c00256ad:	c1 e8 10             	shr    $0x10,%eax
c00256b0:	8d 51 05             	lea    0x5(%ecx),%edx
c00256b3:	ee                   	out    %al,(%dx)
  outb (reg_device (c),
c00256b4:	83 7e 0c 01          	cmpl   $0x1,0xc(%esi)
c00256b8:	b8 f0 ff ff ff       	mov    $0xfffffff0,%eax
c00256bd:	ba e0 ff ff ff       	mov    $0xffffffe0,%edx
c00256c2:	0f 45 c2             	cmovne %edx,%eax
        DEV_MBS | DEV_LBA | (d->dev_no == 1 ? DEV_DEV : 0) | (sec_no >> 24));
c00256c5:	c1 eb 18             	shr    $0x18,%ebx
  outb (reg_device (c),
c00256c8:	09 d8                	or     %ebx,%eax
c00256ca:	8d 51 06             	lea    0x6(%ecx),%edx
c00256cd:	ee                   	out    %al,(%dx)
}
c00256ce:	83 c4 20             	add    $0x20,%esp
c00256d1:	5b                   	pop    %ebx
c00256d2:	5e                   	pop    %esi
c00256d3:	5f                   	pop    %edi
c00256d4:	c3                   	ret    

c00256d5 <wait_while_busy>:
{
c00256d5:	57                   	push   %edi
c00256d6:	56                   	push   %esi
c00256d7:	53                   	push   %ebx
c00256d8:	83 ec 10             	sub    $0x10,%esp
c00256db:	89 c7                	mov    %eax,%edi
  struct channel *c = d->channel;
c00256dd:	8b 70 08             	mov    0x8(%eax),%esi
  for (i = 0; i < 3000; i++)
c00256e0:	bb 00 00 00 00       	mov    $0x0,%ebx
c00256e5:	eb 18                	jmp    c00256ff <wait_while_busy+0x2a>
      if (i == 700)
c00256e7:	81 fb bc 02 00 00    	cmp    $0x2bc,%ebx
c00256ed:	75 10                	jne    c00256ff <wait_while_busy+0x2a>
        printf ("%s: busy, waiting...", d->name);
c00256ef:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00256f3:	c7 04 24 fc f5 02 c0 	movl   $0xc002f5fc,(%esp)
c00256fa:	e8 1f 14 00 00       	call   c0026b1e <printf>
      if (!(inb (reg_alt_status (c)) & STA_BSY)) 
c00256ff:	0f b7 46 08          	movzwl 0x8(%esi),%eax
c0025703:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025709:	ec                   	in     (%dx),%al
c002570a:	84 c0                	test   %al,%al
c002570c:	78 26                	js     c0025734 <wait_while_busy+0x5f>
          if (i >= 700)
c002570e:	81 fb bb 02 00 00    	cmp    $0x2bb,%ebx
c0025714:	7e 0c                	jle    c0025722 <wait_while_busy+0x4d>
            printf ("ok\n");
c0025716:	c7 04 24 11 f6 02 c0 	movl   $0xc002f611,(%esp)
c002571d:	e8 79 4f 00 00       	call   c002a69b <puts>
          return (inb (reg_alt_status (c)) & STA_DRQ) != 0;
c0025722:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c0025726:	66 81 c2 06 02       	add    $0x206,%dx
c002572b:	ec                   	in     (%dx),%al
c002572c:	c0 e8 03             	shr    $0x3,%al
c002572f:	83 e0 01             	and    $0x1,%eax
c0025732:	eb 30                	jmp    c0025764 <wait_while_busy+0x8f>
      timer_msleep (10);
c0025734:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002573b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025742:	00 
c0025743:	e8 3f ec ff ff       	call   c0024387 <timer_msleep>
  for (i = 0; i < 3000; i++)
c0025748:	83 c3 01             	add    $0x1,%ebx
c002574b:	81 fb b8 0b 00 00    	cmp    $0xbb8,%ebx
c0025751:	75 94                	jne    c00256e7 <wait_while_busy+0x12>
  printf ("failed\n");
c0025753:	c7 04 24 2c ff 02 c0 	movl   $0xc002ff2c,(%esp)
c002575a:	e8 3c 4f 00 00       	call   c002a69b <puts>
  return false;
c002575f:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0025764:	83 c4 10             	add    $0x10,%esp
c0025767:	5b                   	pop    %ebx
c0025768:	5e                   	pop    %esi
c0025769:	5f                   	pop    %edi
c002576a:	c3                   	ret    

c002576b <issue_pio_command>:
{
c002576b:	56                   	push   %esi
c002576c:	53                   	push   %ebx
c002576d:	83 ec 24             	sub    $0x24,%esp
c0025770:	89 c3                	mov    %eax,%ebx
c0025772:	89 d6                	mov    %edx,%esi
  ASSERT (intr_get_level () == INTR_ON);
c0025774:	e8 8b c0 ff ff       	call   c0021804 <intr_get_level>
c0025779:	83 f8 01             	cmp    $0x1,%eax
c002577c:	74 2c                	je     c00257aa <issue_pio_command+0x3f>
c002577e:	c7 44 24 10 1e ed 02 	movl   $0xc002ed1e,0x10(%esp)
c0025785:	c0 
c0025786:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002578d:	c0 
c002578e:	c7 44 24 08 45 d9 02 	movl   $0xc002d945,0x8(%esp)
c0025795:	c0 
c0025796:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c002579d:	00 
c002579e:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c00257a5:	e8 c9 31 00 00       	call   c0028973 <debug_panic>
  c->expecting_interrupt = true;
c00257aa:	c6 43 30 01          	movb   $0x1,0x30(%ebx)
  outb (reg_command (c), command);
c00257ae:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c00257b2:	83 c2 07             	add    $0x7,%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00257b5:	89 f0                	mov    %esi,%eax
c00257b7:	ee                   	out    %al,(%dx)
}
c00257b8:	83 c4 24             	add    $0x24,%esp
c00257bb:	5b                   	pop    %ebx
c00257bc:	5e                   	pop    %esi
c00257bd:	c3                   	ret    

c00257be <ide_write>:
{
c00257be:	57                   	push   %edi
c00257bf:	56                   	push   %esi
c00257c0:	53                   	push   %ebx
c00257c1:	83 ec 20             	sub    $0x20,%esp
c00257c4:	8b 74 24 30          	mov    0x30(%esp),%esi
  struct channel *c = d->channel;
c00257c8:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00257cb:	8d 7b 0c             	lea    0xc(%ebx),%edi
c00257ce:	89 3c 24             	mov    %edi,(%esp)
c00257d1:	e8 14 d5 ff ff       	call   c0022cea <lock_acquire>
  select_sector (d, sec_no);
c00257d6:	8b 54 24 34          	mov    0x34(%esp),%edx
c00257da:	89 f0                	mov    %esi,%eax
c00257dc:	e8 5c fe ff ff       	call   c002563d <select_sector>
  issue_pio_command (c, CMD_WRITE_SECTOR_RETRY);
c00257e1:	ba 30 00 00 00       	mov    $0x30,%edx
c00257e6:	89 d8                	mov    %ebx,%eax
c00257e8:	e8 7e ff ff ff       	call   c002576b <issue_pio_command>
  if (!wait_while_busy (d))
c00257ed:	89 f0                	mov    %esi,%eax
c00257ef:	e8 e1 fe ff ff       	call   c00256d5 <wait_while_busy>
c00257f4:	84 c0                	test   %al,%al
c00257f6:	75 30                	jne    c0025828 <ide_write+0x6a>
    PANIC ("%s: disk write failed, sector=%"PRDSNu, d->name, sec_no);
c00257f8:	8b 44 24 34          	mov    0x34(%esp),%eax
c00257fc:	89 44 24 14          	mov    %eax,0x14(%esp)
c0025800:	89 74 24 10          	mov    %esi,0x10(%esp)
c0025804:	c7 44 24 0c 60 f6 02 	movl   $0xc002f660,0xc(%esp)
c002580b:	c0 
c002580c:	c7 44 24 08 6e d9 02 	movl   $0xc002d96e,0x8(%esp)
c0025813:	c0 
c0025814:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
c002581b:	00 
c002581c:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025823:	e8 4b 31 00 00       	call   c0028973 <debug_panic>
   CNT-halfword buffer starting at ADDR. */
static inline void
outsw (uint16_t port, const void *addr, size_t cnt)
{
  /* See [IA32-v2b] "OUTS". */
  asm volatile ("rep outsw" : "+S" (addr), "+c" (cnt) : "d" (port));
c0025828:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c002582c:	8b 74 24 38          	mov    0x38(%esp),%esi
c0025830:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025835:	66 f3 6f             	rep outsw %ds:(%esi),(%dx)
  sema_down (&c->completion_wait);
c0025838:	83 c3 34             	add    $0x34,%ebx
c002583b:	89 1c 24             	mov    %ebx,(%esp)
c002583e:	e8 7f d1 ff ff       	call   c00229c2 <sema_down>
  lock_release (&c->lock);
c0025843:	89 3c 24             	mov    %edi,(%esp)
c0025846:	e8 69 d6 ff ff       	call   c0022eb4 <lock_release>
}
c002584b:	83 c4 20             	add    $0x20,%esp
c002584e:	5b                   	pop    %ebx
c002584f:	5e                   	pop    %esi
c0025850:	5f                   	pop    %edi
c0025851:	c3                   	ret    

c0025852 <identify_ata_device>:
{
c0025852:	57                   	push   %edi
c0025853:	56                   	push   %esi
c0025854:	53                   	push   %ebx
c0025855:	81 ec a0 02 00 00    	sub    $0x2a0,%esp
c002585b:	89 c3                	mov    %eax,%ebx
  struct channel *c = d->channel;
c002585d:	8b 70 08             	mov    0x8(%eax),%esi
  ASSERT (d->is_ata);
c0025860:	80 78 10 00          	cmpb   $0x0,0x10(%eax)
c0025864:	75 2c                	jne    c0025892 <identify_ata_device+0x40>
c0025866:	c7 44 24 10 14 f6 02 	movl   $0xc002f614,0x10(%esp)
c002586d:	c0 
c002586e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025875:	c0 
c0025876:	c7 44 24 08 78 d9 02 	movl   $0xc002d978,0x8(%esp)
c002587d:	c0 
c002587e:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
c0025885:	00 
c0025886:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c002588d:	e8 e1 30 00 00       	call   c0028973 <debug_panic>
  wait_until_idle (d);
c0025892:	e8 70 fc ff ff       	call   c0025507 <wait_until_idle>
  select_device (d);
c0025897:	89 d8                	mov    %ebx,%eax
c0025899:	e8 dc fc ff ff       	call   c002557a <select_device>
  wait_until_idle (d);
c002589e:	89 d8                	mov    %ebx,%eax
c00258a0:	e8 62 fc ff ff       	call   c0025507 <wait_until_idle>
  issue_pio_command (c, CMD_IDENTIFY_DEVICE);
c00258a5:	ba ec 00 00 00       	mov    $0xec,%edx
c00258aa:	89 f0                	mov    %esi,%eax
c00258ac:	e8 ba fe ff ff       	call   c002576b <issue_pio_command>
  sema_down (&c->completion_wait);
c00258b1:	8d 46 34             	lea    0x34(%esi),%eax
c00258b4:	89 04 24             	mov    %eax,(%esp)
c00258b7:	e8 06 d1 ff ff       	call   c00229c2 <sema_down>
  if (!wait_while_busy (d))
c00258bc:	89 d8                	mov    %ebx,%eax
c00258be:	e8 12 fe ff ff       	call   c00256d5 <wait_while_busy>
c00258c3:	84 c0                	test   %al,%al
c00258c5:	75 09                	jne    c00258d0 <identify_ata_device+0x7e>
      d->is_ata = false;
c00258c7:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c00258cb:	e9 cf 00 00 00       	jmp    c002599f <identify_ata_device+0x14d>
  asm volatile ("rep insw" : "+D" (addr), "+c" (cnt) : "d" (port) : "memory");
c00258d0:	0f b7 56 08          	movzwl 0x8(%esi),%edx
c00258d4:	8d bc 24 a0 00 00 00 	lea    0xa0(%esp),%edi
c00258db:	b9 00 01 00 00       	mov    $0x100,%ecx
c00258e0:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  capacity = *(uint32_t *) &id[60 * 2];
c00258e3:	8b b4 24 18 01 00 00 	mov    0x118(%esp),%esi
  model = descramble_ata_string (&id[10 * 2], 20);
c00258ea:	ba 14 00 00 00       	mov    $0x14,%edx
c00258ef:	8d 84 24 b4 00 00 00 	lea    0xb4(%esp),%eax
c00258f6:	e8 25 fb ff ff       	call   c0025420 <descramble_ata_string>
c00258fb:	89 c7                	mov    %eax,%edi
  serial = descramble_ata_string (&id[27 * 2], 40);
c00258fd:	ba 28 00 00 00       	mov    $0x28,%edx
c0025902:	8d 84 24 d6 00 00 00 	lea    0xd6(%esp),%eax
c0025909:	e8 12 fb ff ff       	call   c0025420 <descramble_ata_string>
  snprintf (extra_info, sizeof extra_info,
c002590e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0025912:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025916:	c7 44 24 08 1e f6 02 	movl   $0xc002f61e,0x8(%esp)
c002591d:	c0 
c002591e:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
c0025925:	00 
c0025926:	8d 44 24 20          	lea    0x20(%esp),%eax
c002592a:	89 04 24             	mov    %eax,(%esp)
c002592d:	e8 ed 18 00 00       	call   c002721f <snprintf>
  if (capacity >= 1024 * 1024 * 1024 / BLOCK_SECTOR_SIZE)
c0025932:	81 fe ff ff 1f 00    	cmp    $0x1fffff,%esi
c0025938:	76 35                	jbe    c002596f <identify_ata_device+0x11d>
      printf ("%s: ignoring ", d->name);
c002593a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002593e:	c7 04 24 36 f6 02 c0 	movl   $0xc002f636,(%esp)
c0025945:	e8 d4 11 00 00       	call   c0026b1e <printf>
      print_human_readable_size (capacity * 512);
c002594a:	c1 e6 09             	shl    $0x9,%esi
c002594d:	89 34 24             	mov    %esi,(%esp)
c0025950:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025957:	00 
c0025958:	e8 8c 1a 00 00       	call   c00273e9 <print_human_readable_size>
      printf ("disk for safety\n");
c002595d:	c7 04 24 44 f6 02 c0 	movl   $0xc002f644,(%esp)
c0025964:	e8 32 4d 00 00       	call   c002a69b <puts>
      d->is_ata = false;
c0025969:	c6 43 10 00          	movb   $0x0,0x10(%ebx)
      return;
c002596d:	eb 30                	jmp    c002599f <identify_ata_device+0x14d>
  block = block_register (d->name, BLOCK_RAW, extra_info, capacity,
c002596f:	89 5c 24 14          	mov    %ebx,0x14(%esp)
c0025973:	c7 44 24 10 64 5a 03 	movl   $0xc0035a64,0x10(%esp)
c002597a:	c0 
c002597b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002597f:	8d 44 24 20          	lea    0x20(%esp),%eax
c0025983:	89 44 24 08          	mov    %eax,0x8(%esp)
c0025987:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002598e:	00 
c002598f:	89 1c 24             	mov    %ebx,(%esp)
c0025992:	e8 5a f5 ff ff       	call   c0024ef1 <block_register>
  partition_scan (block);
c0025997:	89 04 24             	mov    %eax,(%esp)
c002599a:	e8 30 fa ff ff       	call   c00253cf <partition_scan>
}
c002599f:	81 c4 a0 02 00 00    	add    $0x2a0,%esp
c00259a5:	5b                   	pop    %ebx
c00259a6:	5e                   	pop    %esi
c00259a7:	5f                   	pop    %edi
c00259a8:	c3                   	ret    

c00259a9 <ide_read>:
{
c00259a9:	55                   	push   %ebp
c00259aa:	57                   	push   %edi
c00259ab:	56                   	push   %esi
c00259ac:	53                   	push   %ebx
c00259ad:	83 ec 2c             	sub    $0x2c,%esp
c00259b0:	8b 74 24 40          	mov    0x40(%esp),%esi
  struct channel *c = d->channel;
c00259b4:	8b 5e 08             	mov    0x8(%esi),%ebx
  lock_acquire (&c->lock);
c00259b7:	8d 6b 0c             	lea    0xc(%ebx),%ebp
c00259ba:	89 2c 24             	mov    %ebp,(%esp)
c00259bd:	e8 28 d3 ff ff       	call   c0022cea <lock_acquire>
  select_sector (d, sec_no);
c00259c2:	8b 54 24 44          	mov    0x44(%esp),%edx
c00259c6:	89 f0                	mov    %esi,%eax
c00259c8:	e8 70 fc ff ff       	call   c002563d <select_sector>
  issue_pio_command (c, CMD_READ_SECTOR_RETRY);
c00259cd:	ba 20 00 00 00       	mov    $0x20,%edx
c00259d2:	89 d8                	mov    %ebx,%eax
c00259d4:	e8 92 fd ff ff       	call   c002576b <issue_pio_command>
  sema_down (&c->completion_wait);
c00259d9:	8d 43 34             	lea    0x34(%ebx),%eax
c00259dc:	89 04 24             	mov    %eax,(%esp)
c00259df:	e8 de cf ff ff       	call   c00229c2 <sema_down>
  if (!wait_while_busy (d))
c00259e4:	89 f0                	mov    %esi,%eax
c00259e6:	e8 ea fc ff ff       	call   c00256d5 <wait_while_busy>
c00259eb:	84 c0                	test   %al,%al
c00259ed:	75 30                	jne    c0025a1f <ide_read+0x76>
    PANIC ("%s: disk read failed, sector=%"PRDSNu, d->name, sec_no);
c00259ef:	8b 44 24 44          	mov    0x44(%esp),%eax
c00259f3:	89 44 24 14          	mov    %eax,0x14(%esp)
c00259f7:	89 74 24 10          	mov    %esi,0x10(%esp)
c00259fb:	c7 44 24 0c 84 f6 02 	movl   $0xc002f684,0xc(%esp)
c0025a02:	c0 
c0025a03:	c7 44 24 08 57 d9 02 	movl   $0xc002d957,0x8(%esp)
c0025a0a:	c0 
c0025a0b:	c7 44 24 04 62 01 00 	movl   $0x162,0x4(%esp)
c0025a12:	00 
c0025a13:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025a1a:	e8 54 2f 00 00       	call   c0028973 <debug_panic>
c0025a1f:	0f b7 53 08          	movzwl 0x8(%ebx),%edx
c0025a23:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0025a27:	b9 00 01 00 00       	mov    $0x100,%ecx
c0025a2c:	66 f3 6d             	rep insw (%dx),%es:(%edi)
  lock_release (&c->lock);
c0025a2f:	89 2c 24             	mov    %ebp,(%esp)
c0025a32:	e8 7d d4 ff ff       	call   c0022eb4 <lock_release>
}
c0025a37:	83 c4 2c             	add    $0x2c,%esp
c0025a3a:	5b                   	pop    %ebx
c0025a3b:	5e                   	pop    %esi
c0025a3c:	5f                   	pop    %edi
c0025a3d:	5d                   	pop    %ebp
c0025a3e:	c3                   	ret    

c0025a3f <ide_init>:
{
c0025a3f:	55                   	push   %ebp
c0025a40:	57                   	push   %edi
c0025a41:	56                   	push   %esi
c0025a42:	53                   	push   %ebx
c0025a43:	83 ec 4c             	sub    $0x4c,%esp
c0025a46:	c7 44 24 1c 9c 78 03 	movl   $0xc003789c,0x1c(%esp)
c0025a4d:	c0 
c0025a4e:	bd 88 78 03 c0       	mov    $0xc0037888,%ebp
c0025a53:	c7 44 24 20 61 00 00 	movl   $0x61,0x20(%esp)
c0025a5a:	00 
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025a5b:	bf 00 00 00 00       	mov    $0x0,%edi
c0025a60:	8d 75 b8             	lea    -0x48(%ebp),%esi
      snprintf (c->name, sizeof c->name, "ide%zu", chan_no);
c0025a63:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0025a67:	c7 44 24 08 54 f6 02 	movl   $0xc002f654,0x8(%esp)
c0025a6e:	c0 
c0025a6f:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025a76:	00 
c0025a77:	89 34 24             	mov    %esi,(%esp)
c0025a7a:	e8 a0 17 00 00       	call   c002721f <snprintf>
      switch (chan_no) 
c0025a7f:	85 ff                	test   %edi,%edi
c0025a81:	74 07                	je     c0025a8a <ide_init+0x4b>
c0025a83:	83 ff 01             	cmp    $0x1,%edi
c0025a86:	74 0e                	je     c0025a96 <ide_init+0x57>
c0025a88:	eb 18                	jmp    c0025aa2 <ide_init+0x63>
          c->reg_base = 0x1f0;
c0025a8a:	66 c7 45 c0 f0 01    	movw   $0x1f0,-0x40(%ebp)
          c->irq = 14 + 0x20;
c0025a90:	c6 45 c2 2e          	movb   $0x2e,-0x3e(%ebp)
          break;
c0025a94:	eb 30                	jmp    c0025ac6 <ide_init+0x87>
          c->reg_base = 0x170;
c0025a96:	66 c7 45 c0 70 01    	movw   $0x170,-0x40(%ebp)
          c->irq = 15 + 0x20;
c0025a9c:	c6 45 c2 2f          	movb   $0x2f,-0x3e(%ebp)
          break;
c0025aa0:	eb 24                	jmp    c0025ac6 <ide_init+0x87>
          NOT_REACHED ();
c0025aa2:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c0025aa9:	c0 
c0025aaa:	c7 44 24 08 9e d9 02 	movl   $0xc002d99e,0x8(%esp)
c0025ab1:	c0 
c0025ab2:	c7 44 24 04 7c 00 00 	movl   $0x7c,0x4(%esp)
c0025ab9:	00 
c0025aba:	c7 04 24 c1 f5 02 c0 	movl   $0xc002f5c1,(%esp)
c0025ac1:	e8 ad 2e 00 00       	call   c0028973 <debug_panic>
c0025ac6:	8d 45 c4             	lea    -0x3c(%ebp),%eax
      lock_init (&c->lock);
c0025ac9:	89 04 24             	mov    %eax,(%esp)
c0025acc:	e8 7c d1 ff ff       	call   c0022c4d <lock_init>
c0025ad1:	89 eb                	mov    %ebp,%ebx
      c->expecting_interrupt = false;
c0025ad3:	c6 45 e8 00          	movb   $0x0,-0x18(%ebp)
      sema_init (&c->completion_wait, 0);
c0025ad7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025ade:	00 
c0025adf:	8d 45 ec             	lea    -0x14(%ebp),%eax
c0025ae2:	89 04 24             	mov    %eax,(%esp)
c0025ae5:	e8 8c ce ff ff       	call   c0022976 <sema_init>
          snprintf (d->name, sizeof d->name,
c0025aea:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025aee:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025af2:	c7 44 24 08 5b f6 02 	movl   $0xc002f65b,0x8(%esp)
c0025af9:	c0 
c0025afa:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b01:	00 
c0025b02:	89 2c 24             	mov    %ebp,(%esp)
c0025b05:	e8 15 17 00 00       	call   c002721f <snprintf>
          d->channel = c;
c0025b0a:	89 75 08             	mov    %esi,0x8(%ebp)
          d->dev_no = dev_no;
c0025b0d:	c7 45 0c 00 00 00 00 	movl   $0x0,0xc(%ebp)
          d->is_ata = false;
c0025b14:	c6 45 10 00          	movb   $0x0,0x10(%ebp)
          snprintf (d->name, sizeof d->name,
c0025b18:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0025b1c:	89 4c 24 24          	mov    %ecx,0x24(%esp)
c0025b20:	8b 44 24 20          	mov    0x20(%esp),%eax
c0025b24:	83 c0 01             	add    $0x1,%eax
c0025b27:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0025b2b:	c7 44 24 08 5b f6 02 	movl   $0xc002f65b,0x8(%esp)
c0025b32:	c0 
c0025b33:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c0025b3a:	00 
c0025b3b:	89 0c 24             	mov    %ecx,(%esp)
c0025b3e:	e8 dc 16 00 00       	call   c002721f <snprintf>
          d->channel = c;
c0025b43:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0025b47:	89 70 08             	mov    %esi,0x8(%eax)
          d->dev_no = dev_no;
c0025b4a:	c7 40 0c 01 00 00 00 	movl   $0x1,0xc(%eax)
          d->is_ata = false;
c0025b51:	c6 45 24 00          	movb   $0x0,0x24(%ebp)
      intr_register_ext (c->irq, interrupt_handler, c->name);
c0025b55:	89 74 24 08          	mov    %esi,0x8(%esp)
c0025b59:	c7 44 24 04 7c 54 02 	movl   $0xc002547c,0x4(%esp)
c0025b60:	c0 
c0025b61:	0f b6 45 c2          	movzbl -0x3e(%ebp),%eax
c0025b65:	89 04 24             	mov    %eax,(%esp)
c0025b68:	e8 86 be ff ff       	call   c00219f3 <intr_register_ext>
c0025b6d:	8d 74 24 3e          	lea    0x3e(%esp),%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025b71:	89 7c 24 28          	mov    %edi,0x28(%esp)
c0025b75:	89 6c 24 2c          	mov    %ebp,0x2c(%esp)
      select_device (d);
c0025b79:	89 e8                	mov    %ebp,%eax
c0025b7b:	e8 fa f9 ff ff       	call   c002557a <select_device>
      outb (reg_nsect (c), 0x55);
c0025b80:	0f b7 7b c0          	movzwl -0x40(%ebx),%edi
c0025b84:	8d 4f 02             	lea    0x2(%edi),%ecx
c0025b87:	b8 55 00 00 00       	mov    $0x55,%eax
c0025b8c:	89 ca                	mov    %ecx,%edx
c0025b8e:	ee                   	out    %al,(%dx)
      outb (reg_lbal (c), 0xaa);
c0025b8f:	83 c7 03             	add    $0x3,%edi
c0025b92:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025b97:	89 fa                	mov    %edi,%edx
c0025b99:	ee                   	out    %al,(%dx)
c0025b9a:	89 ca                	mov    %ecx,%edx
c0025b9c:	ee                   	out    %al,(%dx)
c0025b9d:	b8 55 00 00 00       	mov    $0x55,%eax
c0025ba2:	89 fa                	mov    %edi,%edx
c0025ba4:	ee                   	out    %al,(%dx)
c0025ba5:	89 ca                	mov    %ecx,%edx
c0025ba7:	ee                   	out    %al,(%dx)
c0025ba8:	b8 aa ff ff ff       	mov    $0xffffffaa,%eax
c0025bad:	89 fa                	mov    %edi,%edx
c0025baf:	ee                   	out    %al,(%dx)
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025bb0:	89 ca                	mov    %ecx,%edx
c0025bb2:	ec                   	in     (%dx),%al
                         && inb (reg_lbal (c)) == 0xaa);
c0025bb3:	ba 00 00 00 00       	mov    $0x0,%edx
c0025bb8:	3c 55                	cmp    $0x55,%al
c0025bba:	75 0b                	jne    c0025bc7 <ide_init+0x188>
c0025bbc:	89 fa                	mov    %edi,%edx
c0025bbe:	ec                   	in     (%dx),%al
c0025bbf:	3c aa                	cmp    $0xaa,%al
c0025bc1:	0f 94 c2             	sete   %dl
c0025bc4:	0f b6 d2             	movzbl %dl,%edx
c0025bc7:	88 16                	mov    %dl,(%esi)
c0025bc9:	80 26 01             	andb   $0x1,(%esi)
c0025bcc:	83 c5 14             	add    $0x14,%ebp
c0025bcf:	83 c6 01             	add    $0x1,%esi
  for (dev_no = 0; dev_no < 2; dev_no++)
c0025bd2:	8d 44 24 40          	lea    0x40(%esp),%eax
c0025bd6:	39 c6                	cmp    %eax,%esi
c0025bd8:	75 9f                	jne    c0025b79 <ide_init+0x13a>
c0025bda:	8b 7c 24 28          	mov    0x28(%esp),%edi
c0025bde:	8b 6c 24 2c          	mov    0x2c(%esp),%ebp
  outb (reg_ctl (c), 0);
c0025be2:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025be6:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0025bec:	b8 00 00 00 00       	mov    $0x0,%eax
c0025bf1:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025bf2:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025bf9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c00:	00 
c0025c01:	e8 9a e7 ff ff       	call   c00243a0 <timer_usleep>
  outb (reg_ctl (c), CTL_SRST);
c0025c06:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c0a:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c10:	b8 04 00 00 00       	mov    $0x4,%eax
c0025c15:	ee                   	out    %al,(%dx)
  timer_usleep (10);
c0025c16:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c1d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c24:	00 
c0025c25:	e8 76 e7 ff ff       	call   c00243a0 <timer_usleep>
  outb (reg_ctl (c), 0);
c0025c2a:	0f b7 43 c0          	movzwl -0x40(%ebx),%eax
c0025c2e:	8d 90 06 02 00 00    	lea    0x206(%eax),%edx
c0025c34:	b8 00 00 00 00       	mov    $0x0,%eax
c0025c39:	ee                   	out    %al,(%dx)
  timer_msleep (150);
c0025c3a:	c7 04 24 96 00 00 00 	movl   $0x96,(%esp)
c0025c41:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c48:	00 
c0025c49:	e8 39 e7 ff ff       	call   c0024387 <timer_msleep>
  if (present[0]) 
c0025c4e:	80 7c 24 3e 00       	cmpb   $0x0,0x3e(%esp)
c0025c53:	74 0e                	je     c0025c63 <ide_init+0x224>
      select_device (&c->devices[0]);
c0025c55:	89 d8                	mov    %ebx,%eax
c0025c57:	e8 1e f9 ff ff       	call   c002557a <select_device>
      wait_while_busy (&c->devices[0]); 
c0025c5c:	89 d8                	mov    %ebx,%eax
c0025c5e:	e8 72 fa ff ff       	call   c00256d5 <wait_while_busy>
  if (present[1])
c0025c63:	80 7c 24 3f 00       	cmpb   $0x0,0x3f(%esp)
c0025c68:	74 44                	je     c0025cae <ide_init+0x26f>
      select_device (&c->devices[1]);
c0025c6a:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025c6e:	e8 07 f9 ff ff       	call   c002557a <select_device>
c0025c73:	be b8 0b 00 00       	mov    $0xbb8,%esi
          if (inb (reg_nsect (c)) == 1 && inb (reg_lbal (c)) == 1)
c0025c78:	0f b7 4b c0          	movzwl -0x40(%ebx),%ecx
c0025c7c:	8d 51 02             	lea    0x2(%ecx),%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0025c7f:	ec                   	in     (%dx),%al
c0025c80:	3c 01                	cmp    $0x1,%al
c0025c82:	75 08                	jne    c0025c8c <ide_init+0x24d>
c0025c84:	8d 51 03             	lea    0x3(%ecx),%edx
c0025c87:	ec                   	in     (%dx),%al
c0025c88:	3c 01                	cmp    $0x1,%al
c0025c8a:	74 19                	je     c0025ca5 <ide_init+0x266>
          timer_msleep (10);
c0025c8c:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0025c93:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0025c9a:	00 
c0025c9b:	e8 e7 e6 ff ff       	call   c0024387 <timer_msleep>
      for (i = 0; i < 3000; i++) 
c0025ca0:	83 ee 01             	sub    $0x1,%esi
c0025ca3:	75 d3                	jne    c0025c78 <ide_init+0x239>
      wait_while_busy (&c->devices[1]);
c0025ca5:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025ca9:	e8 27 fa ff ff       	call   c00256d5 <wait_while_busy>
      if (check_device_type (&c->devices[0]))
c0025cae:	89 d8                	mov    %ebx,%eax
c0025cb0:	e8 03 f9 ff ff       	call   c00255b8 <check_device_type>
c0025cb5:	84 c0                	test   %al,%al
c0025cb7:	74 2f                	je     c0025ce8 <ide_init+0x2a9>
        check_device_type (&c->devices[1]);
c0025cb9:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cbd:	e8 f6 f8 ff ff       	call   c00255b8 <check_device_type>
c0025cc2:	eb 24                	jmp    c0025ce8 <ide_init+0x2a9>
          identify_ata_device (&c->devices[dev_no]);
c0025cc4:	8b 44 24 24          	mov    0x24(%esp),%eax
c0025cc8:	e8 85 fb ff ff       	call   c0025852 <identify_ata_device>
  for (chan_no = 0; chan_no < CHANNEL_CNT; chan_no++)
c0025ccd:	83 c7 01             	add    $0x1,%edi
c0025cd0:	83 44 24 1c 70       	addl   $0x70,0x1c(%esp)
c0025cd5:	83 c5 70             	add    $0x70,%ebp
c0025cd8:	83 44 24 20 02       	addl   $0x2,0x20(%esp)
c0025cdd:	83 ff 02             	cmp    $0x2,%edi
c0025ce0:	0f 85 7a fd ff ff    	jne    c0025a60 <ide_init+0x21>
c0025ce6:	eb 15                	jmp    c0025cfd <ide_init+0x2be>
        if (c->devices[dev_no].is_ata)
c0025ce8:	80 7b 10 00          	cmpb   $0x0,0x10(%ebx)
c0025cec:	74 07                	je     c0025cf5 <ide_init+0x2b6>
          identify_ata_device (&c->devices[dev_no]);
c0025cee:	89 d8                	mov    %ebx,%eax
c0025cf0:	e8 5d fb ff ff       	call   c0025852 <identify_ata_device>
        if (c->devices[dev_no].is_ata)
c0025cf5:	80 7b 24 00          	cmpb   $0x0,0x24(%ebx)
c0025cf9:	74 d2                	je     c0025ccd <ide_init+0x28e>
c0025cfb:	eb c7                	jmp    c0025cc4 <ide_init+0x285>
}
c0025cfd:	83 c4 4c             	add    $0x4c,%esp
c0025d00:	5b                   	pop    %ebx
c0025d01:	5e                   	pop    %esi
c0025d02:	5f                   	pop    %edi
c0025d03:	5d                   	pop    %ebp
c0025d04:	c3                   	ret    

c0025d05 <input_init>:
static struct intq buffer;

/* Initializes the input buffer. */
void
input_init (void) 
{
c0025d05:	83 ec 1c             	sub    $0x1c,%esp
  intq_init (&buffer);
c0025d08:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d0f:	e8 11 01 00 00       	call   c0025e25 <intq_init>
}
c0025d14:	83 c4 1c             	add    $0x1c,%esp
c0025d17:	c3                   	ret    

c0025d18 <input_putc>:

/* Adds a key to the input buffer.
   Interrupts must be off and the buffer must not be full. */
void
input_putc (uint8_t key) 
{
c0025d18:	53                   	push   %ebx
c0025d19:	83 ec 28             	sub    $0x28,%esp
c0025d1c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025d20:	e8 df ba ff ff       	call   c0021804 <intr_get_level>
c0025d25:	85 c0                	test   %eax,%eax
c0025d27:	74 2c                	je     c0025d55 <input_putc+0x3d>
c0025d29:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025d30:	c0 
c0025d31:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025d38:	c0 
c0025d39:	c7 44 24 08 b2 d9 02 	movl   $0xc002d9b2,0x8(%esp)
c0025d40:	c0 
c0025d41:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c0025d48:	00 
c0025d49:	c7 04 24 a4 f6 02 c0 	movl   $0xc002f6a4,(%esp)
c0025d50:	e8 1e 2c 00 00       	call   c0028973 <debug_panic>
  ASSERT (!intq_full (&buffer));
c0025d55:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d5c:	e8 40 01 00 00       	call   c0025ea1 <intq_full>
c0025d61:	84 c0                	test   %al,%al
c0025d63:	74 2c                	je     c0025d91 <input_putc+0x79>
c0025d65:	c7 44 24 10 ba f6 02 	movl   $0xc002f6ba,0x10(%esp)
c0025d6c:	c0 
c0025d6d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025d74:	c0 
c0025d75:	c7 44 24 08 b2 d9 02 	movl   $0xc002d9b2,0x8(%esp)
c0025d7c:	c0 
c0025d7d:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025d84:	00 
c0025d85:	c7 04 24 a4 f6 02 c0 	movl   $0xc002f6a4,(%esp)
c0025d8c:	e8 e2 2b 00 00       	call   c0028973 <debug_panic>

  intq_putc (&buffer, key);
c0025d91:	0f b6 db             	movzbl %bl,%ebx
c0025d94:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0025d98:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025d9f:	e8 a7 03 00 00       	call   c002614b <intq_putc>
  serial_notify ();
c0025da4:	e8 21 ee ff ff       	call   c0024bca <serial_notify>
}
c0025da9:	83 c4 28             	add    $0x28,%esp
c0025dac:	5b                   	pop    %ebx
c0025dad:	c3                   	ret    

c0025dae <input_getc>:

/* Retrieves a key from the input buffer.
   If the buffer is empty, waits for a key to be pressed. */
uint8_t
input_getc (void) 
{
c0025dae:	56                   	push   %esi
c0025daf:	53                   	push   %ebx
c0025db0:	83 ec 14             	sub    $0x14,%esp
  enum intr_level old_level;
  uint8_t key;

  old_level = intr_disable ();
c0025db3:	e8 97 ba ff ff       	call   c002184f <intr_disable>
c0025db8:	89 c6                	mov    %eax,%esi
  key = intq_getc (&buffer);
c0025dba:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025dc1:	e8 b9 02 00 00       	call   c002607f <intq_getc>
c0025dc6:	89 c3                	mov    %eax,%ebx
  serial_notify ();
c0025dc8:	e8 fd ed ff ff       	call   c0024bca <serial_notify>
  intr_set_level (old_level);
c0025dcd:	89 34 24             	mov    %esi,(%esp)
c0025dd0:	e8 81 ba ff ff       	call   c0021856 <intr_set_level>
  
  return key;
}
c0025dd5:	89 d8                	mov    %ebx,%eax
c0025dd7:	83 c4 14             	add    $0x14,%esp
c0025dda:	5b                   	pop    %ebx
c0025ddb:	5e                   	pop    %esi
c0025ddc:	c3                   	ret    

c0025ddd <input_full>:
/* Returns true if the input buffer is full,
   false otherwise.
   Interrupts must be off. */
bool
input_full (void) 
{
c0025ddd:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (intr_get_level () == INTR_OFF);
c0025de0:	e8 1f ba ff ff       	call   c0021804 <intr_get_level>
c0025de5:	85 c0                	test   %eax,%eax
c0025de7:	74 2c                	je     c0025e15 <input_full+0x38>
c0025de9:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025df0:	c0 
c0025df1:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025df8:	c0 
c0025df9:	c7 44 24 08 a7 d9 02 	movl   $0xc002d9a7,0x8(%esp)
c0025e00:	c0 
c0025e01:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c0025e08:	00 
c0025e09:	c7 04 24 a4 f6 02 c0 	movl   $0xc002f6a4,(%esp)
c0025e10:	e8 5e 2b 00 00       	call   c0028973 <debug_panic>
  return intq_full (&buffer);
c0025e15:	c7 04 24 20 79 03 c0 	movl   $0xc0037920,(%esp)
c0025e1c:	e8 80 00 00 00       	call   c0025ea1 <intq_full>
}
c0025e21:	83 c4 2c             	add    $0x2c,%esp
c0025e24:	c3                   	ret    

c0025e25 <intq_init>:
static void signal (struct intq *q, struct thread **waiter);

/* Initializes interrupt queue Q. */
void
intq_init (struct intq *q) 
{
c0025e25:	53                   	push   %ebx
c0025e26:	83 ec 18             	sub    $0x18,%esp
c0025e29:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_init (&q->lock);
c0025e2d:	89 1c 24             	mov    %ebx,(%esp)
c0025e30:	e8 18 ce ff ff       	call   c0022c4d <lock_init>
  q->not_full = q->not_empty = NULL;
c0025e35:	c7 43 28 00 00 00 00 	movl   $0x0,0x28(%ebx)
c0025e3c:	c7 43 24 00 00 00 00 	movl   $0x0,0x24(%ebx)
  q->head = q->tail = 0;
c0025e43:	c7 43 70 00 00 00 00 	movl   $0x0,0x70(%ebx)
c0025e4a:	c7 43 6c 00 00 00 00 	movl   $0x0,0x6c(%ebx)
}
c0025e51:	83 c4 18             	add    $0x18,%esp
c0025e54:	5b                   	pop    %ebx
c0025e55:	c3                   	ret    

c0025e56 <intq_empty>:

/* Returns true if Q is empty, false otherwise. */
bool
intq_empty (const struct intq *q) 
{
c0025e56:	53                   	push   %ebx
c0025e57:	83 ec 28             	sub    $0x28,%esp
c0025e5a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025e5e:	e8 a1 b9 ff ff       	call   c0021804 <intr_get_level>
c0025e63:	85 c0                	test   %eax,%eax
c0025e65:	74 2c                	je     c0025e93 <intq_empty+0x3d>
c0025e67:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025e6e:	c0 
c0025e6f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025e76:	c0 
c0025e77:	c7 44 24 08 e7 d9 02 	movl   $0xc002d9e7,0x8(%esp)
c0025e7e:	c0 
c0025e7f:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c0025e86:	00 
c0025e87:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025e8e:	e8 e0 2a 00 00       	call   c0028973 <debug_panic>
  return q->head == q->tail;
c0025e93:	8b 43 70             	mov    0x70(%ebx),%eax
c0025e96:	39 43 6c             	cmp    %eax,0x6c(%ebx)
c0025e99:	0f 94 c0             	sete   %al
}
c0025e9c:	83 c4 28             	add    $0x28,%esp
c0025e9f:	5b                   	pop    %ebx
c0025ea0:	c3                   	ret    

c0025ea1 <intq_full>:

/* Returns true if Q is full, false otherwise. */
bool
intq_full (const struct intq *q) 
{
c0025ea1:	53                   	push   %ebx
c0025ea2:	83 ec 28             	sub    $0x28,%esp
c0025ea5:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025ea9:	e8 56 b9 ff ff       	call   c0021804 <intr_get_level>
c0025eae:	85 c0                	test   %eax,%eax
c0025eb0:	74 2c                	je     c0025ede <intq_full+0x3d>
c0025eb2:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025eb9:	c0 
c0025eba:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025ec1:	c0 
c0025ec2:	c7 44 24 08 dd d9 02 	movl   $0xc002d9dd,0x8(%esp)
c0025ec9:	c0 
c0025eca:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c0025ed1:	00 
c0025ed2:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025ed9:	e8 95 2a 00 00       	call   c0028973 <debug_panic>

/* Returns the position after POS within an intq. */
static int
next (int pos) 
{
  return (pos + 1) % INTQ_BUFSIZE;
c0025ede:	8b 43 6c             	mov    0x6c(%ebx),%eax
c0025ee1:	8d 50 01             	lea    0x1(%eax),%edx
c0025ee4:	89 d0                	mov    %edx,%eax
c0025ee6:	c1 f8 1f             	sar    $0x1f,%eax
c0025ee9:	c1 e8 1a             	shr    $0x1a,%eax
c0025eec:	01 c2                	add    %eax,%edx
c0025eee:	83 e2 3f             	and    $0x3f,%edx
c0025ef1:	29 c2                	sub    %eax,%edx
  return next (q->head) == q->tail;
c0025ef3:	39 53 70             	cmp    %edx,0x70(%ebx)
c0025ef6:	0f 94 c0             	sete   %al
}
c0025ef9:	83 c4 28             	add    $0x28,%esp
c0025efc:	5b                   	pop    %ebx
c0025efd:	c3                   	ret    

c0025efe <wait>:

/* WAITER must be the address of Q's not_empty or not_full
   member.  Waits until the given condition is true. */
static void
wait (struct intq *q UNUSED, struct thread **waiter) 
{
c0025efe:	56                   	push   %esi
c0025eff:	53                   	push   %ebx
c0025f00:	83 ec 24             	sub    $0x24,%esp
c0025f03:	89 c3                	mov    %eax,%ebx
c0025f05:	89 d6                	mov    %edx,%esi
  ASSERT (!intr_context ());
c0025f07:	e8 a5 bb ff ff       	call   c0021ab1 <intr_context>
c0025f0c:	84 c0                	test   %al,%al
c0025f0e:	74 2c                	je     c0025f3c <wait+0x3e>
c0025f10:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c0025f17:	c0 
c0025f18:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025f1f:	c0 
c0025f20:	c7 44 24 08 ce d9 02 	movl   $0xc002d9ce,0x8(%esp)
c0025f27:	c0 
c0025f28:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c0025f2f:	00 
c0025f30:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025f37:	e8 37 2a 00 00       	call   c0028973 <debug_panic>
  ASSERT (intr_get_level () == INTR_OFF);
c0025f3c:	e8 c3 b8 ff ff       	call   c0021804 <intr_get_level>
c0025f41:	85 c0                	test   %eax,%eax
c0025f43:	74 2c                	je     c0025f71 <wait+0x73>
c0025f45:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025f4c:	c0 
c0025f4d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025f54:	c0 
c0025f55:	c7 44 24 08 ce d9 02 	movl   $0xc002d9ce,0x8(%esp)
c0025f5c:	c0 
c0025f5d:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
c0025f64:	00 
c0025f65:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025f6c:	e8 02 2a 00 00       	call   c0028973 <debug_panic>
  ASSERT ((waiter == &q->not_empty && intq_empty (q))
c0025f71:	8d 43 28             	lea    0x28(%ebx),%eax
c0025f74:	39 c6                	cmp    %eax,%esi
c0025f76:	75 0c                	jne    c0025f84 <wait+0x86>
c0025f78:	89 1c 24             	mov    %ebx,(%esp)
c0025f7b:	e8 d6 fe ff ff       	call   c0025e56 <intq_empty>
c0025f80:	84 c0                	test   %al,%al
c0025f82:	75 3f                	jne    c0025fc3 <wait+0xc5>
c0025f84:	8d 43 24             	lea    0x24(%ebx),%eax
c0025f87:	39 c6                	cmp    %eax,%esi
c0025f89:	75 0c                	jne    c0025f97 <wait+0x99>
c0025f8b:	89 1c 24             	mov    %ebx,(%esp)
c0025f8e:	e8 0e ff ff ff       	call   c0025ea1 <intq_full>
c0025f93:	84 c0                	test   %al,%al
c0025f95:	75 2c                	jne    c0025fc3 <wait+0xc5>
c0025f97:	c7 44 24 10 e4 f6 02 	movl   $0xc002f6e4,0x10(%esp)
c0025f9e:	c0 
c0025f9f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025fa6:	c0 
c0025fa7:	c7 44 24 08 ce d9 02 	movl   $0xc002d9ce,0x8(%esp)
c0025fae:	c0 
c0025faf:	c7 44 24 04 5c 00 00 	movl   $0x5c,0x4(%esp)
c0025fb6:	00 
c0025fb7:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0025fbe:	e8 b0 29 00 00       	call   c0028973 <debug_panic>
          || (waiter == &q->not_full && intq_full (q)));

  *waiter = thread_current ();
c0025fc3:	e8 db ac ff ff       	call   c0020ca3 <thread_current>
c0025fc8:	89 06                	mov    %eax,(%esi)
  thread_block ();
c0025fca:	e8 e2 b1 ff ff       	call   c00211b1 <thread_block>
}
c0025fcf:	83 c4 24             	add    $0x24,%esp
c0025fd2:	5b                   	pop    %ebx
c0025fd3:	5e                   	pop    %esi
c0025fd4:	c3                   	ret    

c0025fd5 <signal>:
   member, and the associated condition must be true.  If a
   thread is waiting for the condition, wakes it up and resets
   the waiting thread. */
static void
signal (struct intq *q UNUSED, struct thread **waiter) 
{
c0025fd5:	56                   	push   %esi
c0025fd6:	53                   	push   %ebx
c0025fd7:	83 ec 24             	sub    $0x24,%esp
c0025fda:	89 c6                	mov    %eax,%esi
c0025fdc:	89 d3                	mov    %edx,%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0025fde:	e8 21 b8 ff ff       	call   c0021804 <intr_get_level>
c0025fe3:	85 c0                	test   %eax,%eax
c0025fe5:	74 2c                	je     c0026013 <signal+0x3e>
c0025fe7:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c0025fee:	c0 
c0025fef:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0025ff6:	c0 
c0025ff7:	c7 44 24 08 c7 d9 02 	movl   $0xc002d9c7,0x8(%esp)
c0025ffe:	c0 
c0025fff:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0026006:	00 
c0026007:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c002600e:	e8 60 29 00 00       	call   c0028973 <debug_panic>
  ASSERT ((waiter == &q->not_empty && !intq_empty (q))
c0026013:	8d 46 28             	lea    0x28(%esi),%eax
c0026016:	39 c3                	cmp    %eax,%ebx
c0026018:	75 0c                	jne    c0026026 <signal+0x51>
c002601a:	89 34 24             	mov    %esi,(%esp)
c002601d:	e8 34 fe ff ff       	call   c0025e56 <intq_empty>
c0026022:	84 c0                	test   %al,%al
c0026024:	74 3f                	je     c0026065 <signal+0x90>
c0026026:	8d 46 24             	lea    0x24(%esi),%eax
c0026029:	39 c3                	cmp    %eax,%ebx
c002602b:	75 0c                	jne    c0026039 <signal+0x64>
c002602d:	89 34 24             	mov    %esi,(%esp)
c0026030:	e8 6c fe ff ff       	call   c0025ea1 <intq_full>
c0026035:	84 c0                	test   %al,%al
c0026037:	74 2c                	je     c0026065 <signal+0x90>
c0026039:	c7 44 24 10 40 f7 02 	movl   $0xc002f740,0x10(%esp)
c0026040:	c0 
c0026041:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0026048:	c0 
c0026049:	c7 44 24 08 c7 d9 02 	movl   $0xc002d9c7,0x8(%esp)
c0026050:	c0 
c0026051:	c7 44 24 04 6b 00 00 	movl   $0x6b,0x4(%esp)
c0026058:	00 
c0026059:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c0026060:	e8 0e 29 00 00       	call   c0028973 <debug_panic>
          || (waiter == &q->not_full && !intq_full (q)));

  if (*waiter != NULL) 
c0026065:	8b 03                	mov    (%ebx),%eax
c0026067:	85 c0                	test   %eax,%eax
c0026069:	74 0e                	je     c0026079 <signal+0xa4>
    {
      thread_unblock (*waiter);
c002606b:	89 04 24             	mov    %eax,(%esp)
c002606e:	e8 57 ab ff ff       	call   c0020bca <thread_unblock>
      *waiter = NULL;
c0026073:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
    }
}
c0026079:	83 c4 24             	add    $0x24,%esp
c002607c:	5b                   	pop    %ebx
c002607d:	5e                   	pop    %esi
c002607e:	c3                   	ret    

c002607f <intq_getc>:
{
c002607f:	56                   	push   %esi
c0026080:	53                   	push   %ebx
c0026081:	83 ec 24             	sub    $0x24,%esp
c0026084:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (intr_get_level () == INTR_OFF);
c0026088:	e8 77 b7 ff ff       	call   c0021804 <intr_get_level>
c002608d:	85 c0                	test   %eax,%eax
c002608f:	75 05                	jne    c0026096 <intq_getc+0x17>
      wait (q, &q->not_empty);
c0026091:	8d 73 28             	lea    0x28(%ebx),%esi
c0026094:	eb 7a                	jmp    c0026110 <intq_getc+0x91>
  ASSERT (intr_get_level () == INTR_OFF);
c0026096:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c002609d:	c0 
c002609e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00260a5:	c0 
c00260a6:	c7 44 24 08 d3 d9 02 	movl   $0xc002d9d3,0x8(%esp)
c00260ad:	c0 
c00260ae:	c7 44 24 04 2a 00 00 	movl   $0x2a,0x4(%esp)
c00260b5:	00 
c00260b6:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c00260bd:	e8 b1 28 00 00       	call   c0028973 <debug_panic>
      ASSERT (!intr_context ());
c00260c2:	e8 ea b9 ff ff       	call   c0021ab1 <intr_context>
c00260c7:	84 c0                	test   %al,%al
c00260c9:	74 2c                	je     c00260f7 <intq_getc+0x78>
c00260cb:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00260d2:	c0 
c00260d3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00260da:	c0 
c00260db:	c7 44 24 08 d3 d9 02 	movl   $0xc002d9d3,0x8(%esp)
c00260e2:	c0 
c00260e3:	c7 44 24 04 2d 00 00 	movl   $0x2d,0x4(%esp)
c00260ea:	00 
c00260eb:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c00260f2:	e8 7c 28 00 00       	call   c0028973 <debug_panic>
      lock_acquire (&q->lock);
c00260f7:	89 1c 24             	mov    %ebx,(%esp)
c00260fa:	e8 eb cb ff ff       	call   c0022cea <lock_acquire>
      wait (q, &q->not_empty);
c00260ff:	89 f2                	mov    %esi,%edx
c0026101:	89 d8                	mov    %ebx,%eax
c0026103:	e8 f6 fd ff ff       	call   c0025efe <wait>
      lock_release (&q->lock);
c0026108:	89 1c 24             	mov    %ebx,(%esp)
c002610b:	e8 a4 cd ff ff       	call   c0022eb4 <lock_release>
  while (intq_empty (q)) 
c0026110:	89 1c 24             	mov    %ebx,(%esp)
c0026113:	e8 3e fd ff ff       	call   c0025e56 <intq_empty>
c0026118:	84 c0                	test   %al,%al
c002611a:	75 a6                	jne    c00260c2 <intq_getc+0x43>
  byte = q->buf[q->tail];
c002611c:	8b 4b 70             	mov    0x70(%ebx),%ecx
c002611f:	0f b6 74 0b 2c       	movzbl 0x2c(%ebx,%ecx,1),%esi
  return (pos + 1) % INTQ_BUFSIZE;
c0026124:	83 c1 01             	add    $0x1,%ecx
c0026127:	89 ca                	mov    %ecx,%edx
c0026129:	c1 fa 1f             	sar    $0x1f,%edx
c002612c:	c1 ea 1a             	shr    $0x1a,%edx
c002612f:	01 d1                	add    %edx,%ecx
c0026131:	83 e1 3f             	and    $0x3f,%ecx
c0026134:	29 d1                	sub    %edx,%ecx
  q->tail = next (q->tail);
c0026136:	89 4b 70             	mov    %ecx,0x70(%ebx)
  signal (q, &q->not_full);
c0026139:	8d 53 24             	lea    0x24(%ebx),%edx
c002613c:	89 d8                	mov    %ebx,%eax
c002613e:	e8 92 fe ff ff       	call   c0025fd5 <signal>
}
c0026143:	89 f0                	mov    %esi,%eax
c0026145:	83 c4 24             	add    $0x24,%esp
c0026148:	5b                   	pop    %ebx
c0026149:	5e                   	pop    %esi
c002614a:	c3                   	ret    

c002614b <intq_putc>:
{
c002614b:	57                   	push   %edi
c002614c:	56                   	push   %esi
c002614d:	53                   	push   %ebx
c002614e:	83 ec 20             	sub    $0x20,%esp
c0026151:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0026155:	8b 7c 24 34          	mov    0x34(%esp),%edi
  ASSERT (intr_get_level () == INTR_OFF);
c0026159:	e8 a6 b6 ff ff       	call   c0021804 <intr_get_level>
c002615e:	85 c0                	test   %eax,%eax
c0026160:	75 05                	jne    c0026167 <intq_putc+0x1c>
      wait (q, &q->not_full);
c0026162:	8d 73 24             	lea    0x24(%ebx),%esi
c0026165:	eb 7a                	jmp    c00261e1 <intq_putc+0x96>
  ASSERT (intr_get_level () == INTR_OFF);
c0026167:	c7 44 24 10 0c e5 02 	movl   $0xc002e50c,0x10(%esp)
c002616e:	c0 
c002616f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0026176:	c0 
c0026177:	c7 44 24 08 bd d9 02 	movl   $0xc002d9bd,0x8(%esp)
c002617e:	c0 
c002617f:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0026186:	00 
c0026187:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c002618e:	e8 e0 27 00 00       	call   c0028973 <debug_panic>
      ASSERT (!intr_context ());
c0026193:	e8 19 b9 ff ff       	call   c0021ab1 <intr_context>
c0026198:	84 c0                	test   %al,%al
c002619a:	74 2c                	je     c00261c8 <intq_putc+0x7d>
c002619c:	c7 44 24 10 a2 e5 02 	movl   $0xc002e5a2,0x10(%esp)
c00261a3:	c0 
c00261a4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00261ab:	c0 
c00261ac:	c7 44 24 08 bd d9 02 	movl   $0xc002d9bd,0x8(%esp)
c00261b3:	c0 
c00261b4:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
c00261bb:	00 
c00261bc:	c7 04 24 cf f6 02 c0 	movl   $0xc002f6cf,(%esp)
c00261c3:	e8 ab 27 00 00       	call   c0028973 <debug_panic>
      lock_acquire (&q->lock);
c00261c8:	89 1c 24             	mov    %ebx,(%esp)
c00261cb:	e8 1a cb ff ff       	call   c0022cea <lock_acquire>
      wait (q, &q->not_full);
c00261d0:	89 f2                	mov    %esi,%edx
c00261d2:	89 d8                	mov    %ebx,%eax
c00261d4:	e8 25 fd ff ff       	call   c0025efe <wait>
      lock_release (&q->lock);
c00261d9:	89 1c 24             	mov    %ebx,(%esp)
c00261dc:	e8 d3 cc ff ff       	call   c0022eb4 <lock_release>
  while (intq_full (q))
c00261e1:	89 1c 24             	mov    %ebx,(%esp)
c00261e4:	e8 b8 fc ff ff       	call   c0025ea1 <intq_full>
c00261e9:	84 c0                	test   %al,%al
c00261eb:	75 a6                	jne    c0026193 <intq_putc+0x48>
  q->buf[q->head] = byte;
c00261ed:	8b 53 6c             	mov    0x6c(%ebx),%edx
c00261f0:	89 f8                	mov    %edi,%eax
c00261f2:	88 44 13 2c          	mov    %al,0x2c(%ebx,%edx,1)
  return (pos + 1) % INTQ_BUFSIZE;
c00261f6:	83 c2 01             	add    $0x1,%edx
c00261f9:	89 d0                	mov    %edx,%eax
c00261fb:	c1 f8 1f             	sar    $0x1f,%eax
c00261fe:	c1 e8 1a             	shr    $0x1a,%eax
c0026201:	01 c2                	add    %eax,%edx
c0026203:	83 e2 3f             	and    $0x3f,%edx
c0026206:	29 c2                	sub    %eax,%edx
  q->head = next (q->head);
c0026208:	89 53 6c             	mov    %edx,0x6c(%ebx)
  signal (q, &q->not_empty);
c002620b:	8d 53 28             	lea    0x28(%ebx),%edx
c002620e:	89 d8                	mov    %ebx,%eax
c0026210:	e8 c0 fd ff ff       	call   c0025fd5 <signal>
}
c0026215:	83 c4 20             	add    $0x20,%esp
c0026218:	5b                   	pop    %ebx
c0026219:	5e                   	pop    %esi
c002621a:	5f                   	pop    %edi
c002621b:	c3                   	ret    

c002621c <rtc_get_time>:

/* Returns number of seconds since Unix epoch of January 1,
   1970. */
time_t
rtc_get_time (void)
{
c002621c:	55                   	push   %ebp
c002621d:	57                   	push   %edi
c002621e:	56                   	push   %esi
c002621f:	53                   	push   %ebx
c0026220:	83 ec 03             	sub    $0x3,%esp
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026223:	bb 00 00 00 00       	mov    $0x0,%ebx
c0026228:	bd 02 00 00 00       	mov    $0x2,%ebp
c002622d:	89 d8                	mov    %ebx,%eax
c002622f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026231:	e4 71                	in     $0x71,%al

/* Returns the integer value of the given BCD byte. */
static int
bcd_to_bin (uint8_t x)
{
  return (x & 0x0f) + ((x >> 4) * 10);
c0026233:	89 c2                	mov    %eax,%edx
c0026235:	83 e2 0f             	and    $0xf,%edx
c0026238:	c0 e8 04             	shr    $0x4,%al
c002623b:	0f b6 c0             	movzbl %al,%eax
c002623e:	8d 04 80             	lea    (%eax,%eax,4),%eax
c0026241:	8d 0c 42             	lea    (%edx,%eax,2),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026244:	89 e8                	mov    %ebp,%eax
c0026246:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026248:	e4 71                	in     $0x71,%al
c002624a:	88 04 24             	mov    %al,(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002624d:	b8 04 00 00 00       	mov    $0x4,%eax
c0026252:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026254:	e4 71                	in     $0x71,%al
c0026256:	88 44 24 01          	mov    %al,0x1(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002625a:	b8 07 00 00 00       	mov    $0x7,%eax
c002625f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026261:	e4 71                	in     $0x71,%al
c0026263:	88 44 24 02          	mov    %al,0x2(%esp)
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026267:	b8 08 00 00 00       	mov    $0x8,%eax
c002626c:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c002626e:	e4 71                	in     $0x71,%al
c0026270:	89 c6                	mov    %eax,%esi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026272:	b8 09 00 00 00       	mov    $0x9,%eax
c0026277:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026279:	e4 71                	in     $0x71,%al
c002627b:	89 c7                	mov    %eax,%edi
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c002627d:	89 d8                	mov    %ebx,%eax
c002627f:	e6 70                	out    %al,$0x70
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c0026281:	e4 71                	in     $0x71,%al
c0026283:	89 c2                	mov    %eax,%edx
c0026285:	89 d0                	mov    %edx,%eax
c0026287:	83 e0 0f             	and    $0xf,%eax
c002628a:	c0 ea 04             	shr    $0x4,%dl
c002628d:	0f b6 d2             	movzbl %dl,%edx
c0026290:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026293:	8d 04 50             	lea    (%eax,%edx,2),%eax
  while (sec != bcd_to_bin (cmos_read (RTC_REG_SEC)));
c0026296:	39 c1                	cmp    %eax,%ecx
c0026298:	75 93                	jne    c002622d <rtc_get_time+0x11>
  return (x & 0x0f) + ((x >> 4) * 10);
c002629a:	89 fa                	mov    %edi,%edx
c002629c:	83 e2 0f             	and    $0xf,%edx
c002629f:	89 f8                	mov    %edi,%eax
c00262a1:	c0 e8 04             	shr    $0x4,%al
c00262a4:	0f b6 f8             	movzbl %al,%edi
c00262a7:	8d 04 bf             	lea    (%edi,%edi,4),%eax
  if (year < 70)
c00262aa:	8d 04 42             	lea    (%edx,%eax,2),%eax
    year += 100;
c00262ad:	8d 50 64             	lea    0x64(%eax),%edx
c00262b0:	83 f8 45             	cmp    $0x45,%eax
c00262b3:	0f 4e c2             	cmovle %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c00262b6:	89 f2                	mov    %esi,%edx
c00262b8:	83 e2 0f             	and    $0xf,%edx
c00262bb:	89 f3                	mov    %esi,%ebx
c00262bd:	c0 eb 04             	shr    $0x4,%bl
c00262c0:	0f b6 f3             	movzbl %bl,%esi
c00262c3:	8d 1c b6             	lea    (%esi,%esi,4),%ebx
c00262c6:	8d 34 5a             	lea    (%edx,%ebx,2),%esi
  year -= 70;
c00262c9:	8d 78 ba             	lea    -0x46(%eax),%edi
  time = (year * 365 + (year - 1) / 4) * 24 * 60 * 60;
c00262cc:	69 df 6d 01 00 00    	imul   $0x16d,%edi,%ebx
c00262d2:	8d 50 bc             	lea    -0x44(%eax),%edx
c00262d5:	83 e8 47             	sub    $0x47,%eax
c00262d8:	0f 48 c2             	cmovs  %edx,%eax
c00262db:	c1 f8 02             	sar    $0x2,%eax
c00262de:	01 d8                	add    %ebx,%eax
c00262e0:	69 c0 80 51 01 00    	imul   $0x15180,%eax,%eax
  for (i = 1; i <= mon; i++)
c00262e6:	85 f6                	test   %esi,%esi
c00262e8:	7e 19                	jle    c0026303 <rtc_get_time+0xe7>
c00262ea:	ba 01 00 00 00       	mov    $0x1,%edx
    time += days_per_month[i - 1] * 24 * 60 * 60;
c00262ef:	69 1c 95 fc d9 02 c0 	imul   $0x15180,-0x3ffd2604(,%edx,4),%ebx
c00262f6:	80 51 01 00 
c00262fa:	01 d8                	add    %ebx,%eax
  for (i = 1; i <= mon; i++)
c00262fc:	83 c2 01             	add    $0x1,%edx
c00262ff:	39 f2                	cmp    %esi,%edx
c0026301:	7e ec                	jle    c00262ef <rtc_get_time+0xd3>
  if (mon > 2 && year % 4 == 0)
c0026303:	83 fe 02             	cmp    $0x2,%esi
c0026306:	7e 0e                	jle    c0026316 <rtc_get_time+0xfa>
c0026308:	83 e7 03             	and    $0x3,%edi
    time += 24 * 60 * 60;
c002630b:	8d 90 80 51 01 00    	lea    0x15180(%eax),%edx
c0026311:	85 ff                	test   %edi,%edi
c0026313:	0f 44 c2             	cmove  %edx,%eax
  return (x & 0x0f) + ((x >> 4) * 10);
c0026316:	0f b6 54 24 01       	movzbl 0x1(%esp),%edx
c002631b:	89 d3                	mov    %edx,%ebx
c002631d:	83 e3 0f             	and    $0xf,%ebx
c0026320:	c0 ea 04             	shr    $0x4,%dl
c0026323:	0f b6 d2             	movzbl %dl,%edx
c0026326:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026329:	8d 1c 53             	lea    (%ebx,%edx,2),%ebx
  time += hour * 60 * 60;
c002632c:	69 db 10 0e 00 00    	imul   $0xe10,%ebx,%ebx
  return (x & 0x0f) + ((x >> 4) * 10);
c0026332:	0f b6 14 24          	movzbl (%esp),%edx
c0026336:	89 d6                	mov    %edx,%esi
c0026338:	83 e6 0f             	and    $0xf,%esi
c002633b:	c0 ea 04             	shr    $0x4,%dl
c002633e:	0f b6 d2             	movzbl %dl,%edx
c0026341:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026344:	8d 14 56             	lea    (%esi,%edx,2),%edx
  time += min * 60;
c0026347:	6b d2 3c             	imul   $0x3c,%edx,%edx
  time += (mday - 1) * 24 * 60 * 60;
c002634a:	01 da                	add    %ebx,%edx
  time += hour * 60 * 60;
c002634c:	01 d1                	add    %edx,%ecx
  return (x & 0x0f) + ((x >> 4) * 10);
c002634e:	0f b6 54 24 02       	movzbl 0x2(%esp),%edx
c0026353:	89 d3                	mov    %edx,%ebx
c0026355:	83 e3 0f             	and    $0xf,%ebx
c0026358:	c0 ea 04             	shr    $0x4,%dl
c002635b:	0f b6 d2             	movzbl %dl,%edx
c002635e:	8d 14 92             	lea    (%edx,%edx,4),%edx
  time += (mday - 1) * 24 * 60 * 60;
c0026361:	8d 54 53 ff          	lea    -0x1(%ebx,%edx,2),%edx
c0026365:	69 d2 80 51 01 00    	imul   $0x15180,%edx,%edx
  time += min * 60;
c002636b:	01 d1                	add    %edx,%ecx
  time += sec;
c002636d:	01 c8                	add    %ecx,%eax
}
c002636f:	83 c4 03             	add    $0x3,%esp
c0026372:	5b                   	pop    %ebx
c0026373:	5e                   	pop    %esi
c0026374:	5f                   	pop    %edi
c0026375:	5d                   	pop    %ebp
c0026376:	c3                   	ret    
c0026377:	90                   	nop
c0026378:	90                   	nop
c0026379:	90                   	nop
c002637a:	90                   	nop
c002637b:	90                   	nop
c002637c:	90                   	nop
c002637d:	90                   	nop
c002637e:	90                   	nop
c002637f:	90                   	nop

c0026380 <shutdown_configure>:
/* Sets TYPE as the way that machine will shut down when Pintos
   execution is complete. */
void
shutdown_configure (enum shutdown_type type)
{
  how = type;
c0026380:	8b 44 24 04          	mov    0x4(%esp),%eax
c0026384:	a3 94 79 03 c0       	mov    %eax,0xc0037994
c0026389:	c3                   	ret    

c002638a <shutdown_reboot>:
}

/* Reboots the machine via the keyboard controller. */
void
shutdown_reboot (void)
{
c002638a:	56                   	push   %esi
c002638b:	53                   	push   %ebx
c002638c:	83 ec 14             	sub    $0x14,%esp
  printf ("Rebooting...\n");
c002638f:	c7 04 24 9b f7 02 c0 	movl   $0xc002f79b,(%esp)
c0026396:	e8 00 43 00 00       	call   c002a69b <puts>
    {
      int i;

      /* Poll keyboard controller's status byte until
       * 'input buffer empty' is reported. */
      for (i = 0; i < 0x10000; i++)
c002639b:	bb 00 00 00 00       	mov    $0x0,%ebx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00263a0:	be fe ff ff ff       	mov    $0xfffffffe,%esi
c00263a5:	eb 1d                	jmp    c00263c4 <shutdown_reboot+0x3a>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00263a7:	e4 64                	in     $0x64,%al
        {
          if ((inb (CONTROL_REG) & 0x02) == 0)
c00263a9:	a8 02                	test   $0x2,%al
c00263ab:	74 1f                	je     c00263cc <shutdown_reboot+0x42>
            break;
          timer_udelay (2);
c00263ad:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00263b4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263bb:	00 
c00263bc:	e8 2a e0 ff ff       	call   c00243eb <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c00263c1:	83 c3 01             	add    $0x1,%ebx
c00263c4:	81 fb ff ff 00 00    	cmp    $0xffff,%ebx
c00263ca:	7e db                	jle    c00263a7 <shutdown_reboot+0x1d>
        }

      timer_udelay (50);
c00263cc:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c00263d3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263da:	00 
c00263db:	e8 0b e0 ff ff       	call   c00243eb <timer_udelay>
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00263e0:	89 f0                	mov    %esi,%eax
c00263e2:	e6 64                	out    %al,$0x64

      /* Pulse bit 0 of the output port P2 of the keyboard controller.
       * This will reset the CPU. */
      outb (CONTROL_REG, 0xfe);
      timer_udelay (50);
c00263e4:	c7 04 24 32 00 00 00 	movl   $0x32,(%esp)
c00263eb:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00263f2:	00 
c00263f3:	e8 f3 df ff ff       	call   c00243eb <timer_udelay>
      for (i = 0; i < 0x10000; i++)
c00263f8:	bb 00 00 00 00       	mov    $0x0,%ebx
    }
c00263fd:	eb c5                	jmp    c00263c4 <shutdown_reboot+0x3a>

c00263ff <shutdown_power_off>:

/* Powers down the machine we're running on,
   as long as we're running on Bochs or QEMU. */
void
shutdown_power_off (void)
{
c00263ff:	83 ec 2c             	sub    $0x2c,%esp
  const char s[] = "Shutdown";
c0026402:	c7 44 24 17 53 68 75 	movl   $0x74756853,0x17(%esp)
c0026409:	74 
c002640a:	c7 44 24 1b 64 6f 77 	movl   $0x6e776f64,0x1b(%esp)
c0026411:	6e 
c0026412:	c6 44 24 1f 00       	movb   $0x0,0x1f(%esp)

/* Print statistics about Pintos execution. */
static void
print_stats (void)
{
  timer_print_stats ();
c0026417:	e8 01 e0 ff ff       	call   c002441d <timer_print_stats>
  thread_print_stats ();
c002641c:	e8 60 a7 ff ff       	call   c0020b81 <thread_print_stats>
#ifdef FILESYS
  block_print_stats ();
#endif
  console_print_stats ();
c0026421:	e8 0e 42 00 00       	call   c002a634 <console_print_stats>
  kbd_print_stats ();
c0026426:	e8 33 e2 ff ff       	call   c002465e <kbd_print_stats>
  printf ("Powering off...\n");
c002642b:	c7 04 24 a8 f7 02 c0 	movl   $0xc002f7a8,(%esp)
c0026432:	e8 64 42 00 00       	call   c002a69b <puts>
  serial_flush ();
c0026437:	e8 50 e7 ff ff       	call   c0024b8c <serial_flush>
  asm volatile ("outw %w0, %w1" : : "a" (data), "Nd" (port));
c002643c:	ba 04 b0 ff ff       	mov    $0xffffb004,%edx
c0026441:	b8 00 20 00 00       	mov    $0x2000,%eax
c0026446:	66 ef                	out    %ax,(%dx)
  for (p = s; *p != '\0'; p++)
c0026448:	0f b6 44 24 17       	movzbl 0x17(%esp),%eax
c002644d:	84 c0                	test   %al,%al
c002644f:	74 14                	je     c0026465 <shutdown_power_off+0x66>
c0026451:	8d 4c 24 17          	lea    0x17(%esp),%ecx
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026455:	ba 00 89 ff ff       	mov    $0xffff8900,%edx
c002645a:	ee                   	out    %al,(%dx)
c002645b:	83 c1 01             	add    $0x1,%ecx
c002645e:	0f b6 01             	movzbl (%ecx),%eax
c0026461:	84 c0                	test   %al,%al
c0026463:	75 f5                	jne    c002645a <shutdown_power_off+0x5b>
c0026465:	ba 01 05 00 00       	mov    $0x501,%edx
c002646a:	b8 31 00 00 00       	mov    $0x31,%eax
c002646f:	ee                   	out    %al,(%dx)
  asm volatile ("cli; hlt" : : : "memory");
c0026470:	fa                   	cli    
c0026471:	f4                   	hlt    
  printf ("still running...\n");
c0026472:	c7 04 24 b8 f7 02 c0 	movl   $0xc002f7b8,(%esp)
c0026479:	e8 1d 42 00 00       	call   c002a69b <puts>
c002647e:	eb fe                	jmp    c002647e <shutdown_power_off+0x7f>

c0026480 <shutdown>:
{
c0026480:	83 ec 0c             	sub    $0xc,%esp
  switch (how)
c0026483:	a1 94 79 03 c0       	mov    0xc0037994,%eax
c0026488:	83 f8 01             	cmp    $0x1,%eax
c002648b:	74 07                	je     c0026494 <shutdown+0x14>
c002648d:	83 f8 02             	cmp    $0x2,%eax
c0026490:	74 07                	je     c0026499 <shutdown+0x19>
c0026492:	eb 11                	jmp    c00264a5 <shutdown+0x25>
      shutdown_power_off ();
c0026494:	e8 66 ff ff ff       	call   c00263ff <shutdown_power_off>
c0026499:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
      shutdown_reboot ();
c00264a0:	e8 e5 fe ff ff       	call   c002638a <shutdown_reboot>
}
c00264a5:	83 c4 0c             	add    $0xc,%esp
c00264a8:	c3                   	ret    
c00264a9:	90                   	nop
c00264aa:	90                   	nop
c00264ab:	90                   	nop
c00264ac:	90                   	nop
c00264ad:	90                   	nop
c00264ae:	90                   	nop
c00264af:	90                   	nop

c00264b0 <speaker_off>:

/* Turn off the PC speaker, by disconnecting the timer channel's
   output from the speaker. */
void
speaker_off (void)
{
c00264b0:	83 ec 1c             	sub    $0x1c,%esp
  enum intr_level old_level = intr_disable ();
c00264b3:	e8 97 b3 ff ff       	call   c002184f <intr_disable>
c00264b8:	89 c2                	mov    %eax,%edx
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00264ba:	e4 61                	in     $0x61,%al
  outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) & ~SPEAKER_GATE_ENABLE);
c00264bc:	83 e0 fc             	and    $0xfffffffc,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c00264bf:	e6 61                	out    %al,$0x61
  intr_set_level (old_level);
c00264c1:	89 14 24             	mov    %edx,(%esp)
c00264c4:	e8 8d b3 ff ff       	call   c0021856 <intr_set_level>
}
c00264c9:	83 c4 1c             	add    $0x1c,%esp
c00264cc:	c3                   	ret    

c00264cd <speaker_on>:
{
c00264cd:	56                   	push   %esi
c00264ce:	53                   	push   %ebx
c00264cf:	83 ec 14             	sub    $0x14,%esp
c00264d2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (frequency >= 20 && frequency <= 20000)
c00264d6:	8d 43 ec             	lea    -0x14(%ebx),%eax
c00264d9:	3d 0c 4e 00 00       	cmp    $0x4e0c,%eax
c00264de:	77 30                	ja     c0026510 <speaker_on+0x43>
      enum intr_level old_level = intr_disable ();
c00264e0:	e8 6a b3 ff ff       	call   c002184f <intr_disable>
c00264e5:	89 c6                	mov    %eax,%esi
      pit_configure_channel (2, 3, frequency);
c00264e7:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00264eb:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c00264f2:	00 
c00264f3:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c00264fa:	e8 29 d8 ff ff       	call   c0023d28 <pit_configure_channel>
  asm volatile ("inb %w1, %b0" : "=a" (data) : "Nd" (port));
c00264ff:	e4 61                	in     $0x61,%al
      outb (SPEAKER_PORT_GATE, inb (SPEAKER_PORT_GATE) | SPEAKER_GATE_ENABLE);
c0026501:	83 c8 03             	or     $0x3,%eax
  asm volatile ("outb %b0, %w1" : : "a" (data), "Nd" (port));
c0026504:	e6 61                	out    %al,$0x61
      intr_set_level (old_level);
c0026506:	89 34 24             	mov    %esi,(%esp)
c0026509:	e8 48 b3 ff ff       	call   c0021856 <intr_set_level>
c002650e:	eb 05                	jmp    c0026515 <speaker_on+0x48>
      speaker_off ();
c0026510:	e8 9b ff ff ff       	call   c00264b0 <speaker_off>
}
c0026515:	83 c4 14             	add    $0x14,%esp
c0026518:	5b                   	pop    %ebx
c0026519:	5e                   	pop    %esi
c002651a:	c3                   	ret    

c002651b <speaker_beep>:

/* Briefly beep the PC speaker. */
void
speaker_beep (void)
{
c002651b:	83 ec 1c             	sub    $0x1c,%esp

     We can't just enable interrupts while we sleep.  For one
     thing, we get called (indirectly) from printf, which should
     always work, even during boot before we're ready to enable
     interrupts. */
  if (intr_get_level () == INTR_ON)
c002651e:	e8 e1 b2 ff ff       	call   c0021804 <intr_get_level>
c0026523:	83 f8 01             	cmp    $0x1,%eax
c0026526:	75 25                	jne    c002654d <speaker_beep+0x32>
    {
      speaker_on (440);
c0026528:	c7 04 24 b8 01 00 00 	movl   $0x1b8,(%esp)
c002652f:	e8 99 ff ff ff       	call   c00264cd <speaker_on>
      timer_msleep (250);
c0026534:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002653b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0026542:	00 
c0026543:	e8 3f de ff ff       	call   c0024387 <timer_msleep>
      speaker_off ();
c0026548:	e8 63 ff ff ff       	call   c00264b0 <speaker_off>
    }
}
c002654d:	83 c4 1c             	add    $0x1c,%esp
c0026550:	c3                   	ret    

c0026551 <debug_backtrace>:
   each of the functions we are nested within.  gdb or addr2line
   may be applied to kernel.o to translate these into file names,
   line numbers, and function names.  */
void
debug_backtrace (void) 
{
c0026551:	55                   	push   %ebp
c0026552:	89 e5                	mov    %esp,%ebp
c0026554:	53                   	push   %ebx
c0026555:	83 ec 14             	sub    $0x14,%esp
  static bool explained;
  void **frame;
  
  printf ("Call stack: %p", __builtin_return_address (0));
c0026558:	8b 45 04             	mov    0x4(%ebp),%eax
c002655b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002655f:	c7 04 24 c9 f7 02 c0 	movl   $0xc002f7c9,(%esp)
c0026566:	e8 b3 05 00 00       	call   c0026b1e <printf>
  for (frame = __builtin_frame_address (1);
c002656b:	8b 5d 00             	mov    0x0(%ebp),%ebx
c002656e:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0026574:	76 27                	jbe    c002659d <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c0026576:	83 3b 00             	cmpl   $0x0,(%ebx)
c0026579:	74 22                	je     c002659d <debug_backtrace+0x4c>
       frame = frame[0]) 
    printf (" %p", frame[1]);
c002657b:	8b 43 04             	mov    0x4(%ebx),%eax
c002657e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026582:	c7 04 24 d4 f7 02 c0 	movl   $0xc002f7d4,(%esp)
c0026589:	e8 90 05 00 00       	call   c0026b1e <printf>
       frame = frame[0]) 
c002658e:	8b 1b                	mov    (%ebx),%ebx
  for (frame = __builtin_frame_address (1);
c0026590:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0026596:	76 05                	jbe    c002659d <debug_backtrace+0x4c>
       (uintptr_t) frame >= 0x1000 && frame[0] != NULL;
c0026598:	83 3b 00             	cmpl   $0x0,(%ebx)
c002659b:	75 de                	jne    c002657b <debug_backtrace+0x2a>
  printf (".\n");
c002659d:	c7 04 24 6b f3 02 c0 	movl   $0xc002f36b,(%esp)
c00265a4:	e8 f2 40 00 00       	call   c002a69b <puts>

  if (!explained) 
c00265a9:	80 3d 98 79 03 c0 00 	cmpb   $0x0,0xc0037998
c00265b0:	75 13                	jne    c00265c5 <debug_backtrace+0x74>
    {
      explained = true;
c00265b2:	c6 05 98 79 03 c0 01 	movb   $0x1,0xc0037998
      printf ("The `backtrace' program can make call stacks useful.\n"
c00265b9:	c7 04 24 d8 f7 02 c0 	movl   $0xc002f7d8,(%esp)
c00265c0:	e8 d6 40 00 00       	call   c002a69b <puts>
              "Read \"Backtraces\" in the \"Debugging Tools\" chapter\n"
              "of the Pintos documentation for more information.\n");
    }
}
c00265c5:	83 c4 14             	add    $0x14,%esp
c00265c8:	5b                   	pop    %ebx
c00265c9:	5d                   	pop    %ebp
c00265ca:	c3                   	ret    

c00265cb <random_init>:
{
  uint8_t *seedp = (uint8_t *) &seed;
  int i;
  uint8_t j;

  for (i = 0; i < 256; i++) 
c00265cb:	b8 00 00 00 00       	mov    $0x0,%eax
    s[i] = i;
c00265d0:	88 80 c0 79 03 c0    	mov    %al,-0x3ffc8640(%eax)
  for (i = 0; i < 256; i++) 
c00265d6:	83 c0 01             	add    $0x1,%eax
c00265d9:	3d 00 01 00 00       	cmp    $0x100,%eax
c00265de:	75 f0                	jne    c00265d0 <random_init+0x5>
{
c00265e0:	56                   	push   %esi
c00265e1:	53                   	push   %ebx
  for (i = 0; i < 256; i++) 
c00265e2:	be 00 00 00 00       	mov    $0x0,%esi
c00265e7:	66 b8 00 00          	mov    $0x0,%ax
  for (i = j = 0; i < 256; i++) 
    {
      j += s[i] + seedp[i % sizeof seed];
c00265eb:	89 c1                	mov    %eax,%ecx
c00265ed:	83 e1 03             	and    $0x3,%ecx
c00265f0:	0f b6 98 c0 79 03 c0 	movzbl -0x3ffc8640(%eax),%ebx
c00265f7:	89 da                	mov    %ebx,%edx
c00265f9:	02 54 0c 0c          	add    0xc(%esp,%ecx,1),%dl
c00265fd:	89 d1                	mov    %edx,%ecx
c00265ff:	01 ce                	add    %ecx,%esi
      swap_byte (s + i, s + j);
c0026601:	89 f2                	mov    %esi,%edx
c0026603:	0f b6 ca             	movzbl %dl,%ecx
  *a = *b;
c0026606:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c002660d:	88 90 c0 79 03 c0    	mov    %dl,-0x3ffc8640(%eax)
  *b = t;
c0026613:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)
  for (i = j = 0; i < 256; i++) 
c0026619:	83 c0 01             	add    $0x1,%eax
c002661c:	3d 00 01 00 00       	cmp    $0x100,%eax
c0026621:	75 c8                	jne    c00265eb <random_init+0x20>
    }

  s_i = s_j = 0;
c0026623:	c6 05 a1 79 03 c0 00 	movb   $0x0,0xc00379a1
c002662a:	c6 05 a2 79 03 c0 00 	movb   $0x0,0xc00379a2
  inited = true;
c0026631:	c6 05 a0 79 03 c0 01 	movb   $0x1,0xc00379a0
}
c0026638:	5b                   	pop    %ebx
c0026639:	5e                   	pop    %esi
c002663a:	c3                   	ret    

c002663b <random_bytes>:

/* Writes SIZE random bytes into BUF. */
void
random_bytes (void *buf_, size_t size) 
{
c002663b:	55                   	push   %ebp
c002663c:	57                   	push   %edi
c002663d:	56                   	push   %esi
c002663e:	53                   	push   %ebx
c002663f:	83 ec 0c             	sub    $0xc,%esp
  uint8_t *buf;

  if (!inited)
c0026642:	80 3d a0 79 03 c0 00 	cmpb   $0x0,0xc00379a0
c0026649:	75 0c                	jne    c0026657 <random_bytes+0x1c>
    random_init (0);
c002664b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0026652:	e8 74 ff ff ff       	call   c00265cb <random_init>

  for (buf = buf_; size-- > 0; buf++)
c0026657:	8b 44 24 24          	mov    0x24(%esp),%eax
c002665b:	83 e8 01             	sub    $0x1,%eax
c002665e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0026662:	83 7c 24 24 00       	cmpl   $0x0,0x24(%esp)
c0026667:	0f 84 87 00 00 00    	je     c00266f4 <random_bytes+0xb9>
c002666d:	0f b6 1d a1 79 03 c0 	movzbl 0xc00379a1,%ebx
c0026674:	b8 00 00 00 00       	mov    $0x0,%eax
c0026679:	0f b6 35 a2 79 03 c0 	movzbl 0xc00379a2,%esi
c0026680:	83 c6 01             	add    $0x1,%esi
c0026683:	89 f5                	mov    %esi,%ebp
c0026685:	8d 14 06             	lea    (%esi,%eax,1),%edx
    {
      uint8_t s_k;
      
      s_i++;
      s_j += s[s_i];
c0026688:	0f b6 d2             	movzbl %dl,%edx
c002668b:	02 9a c0 79 03 c0    	add    -0x3ffc8640(%edx),%bl
c0026691:	88 5c 24 07          	mov    %bl,0x7(%esp)
      swap_byte (s + s_i, s + s_j);
c0026695:	0f b6 cb             	movzbl %bl,%ecx
  uint8_t t = *a;
c0026698:	0f b6 ba c0 79 03 c0 	movzbl -0x3ffc8640(%edx),%edi
  *a = *b;
c002669f:	0f b6 99 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%ebx
c00266a6:	88 9a c0 79 03 c0    	mov    %bl,-0x3ffc8640(%edx)
  *b = t;
c00266ac:	89 fb                	mov    %edi,%ebx
c00266ae:	88 99 c0 79 03 c0    	mov    %bl,-0x3ffc8640(%ecx)

      s_k = s[s_i] + s[s_j];
c00266b4:	89 f9                	mov    %edi,%ecx
c00266b6:	02 8a c0 79 03 c0    	add    -0x3ffc8640(%edx),%cl
      *buf = s[s_k];
c00266bc:	0f b6 c9             	movzbl %cl,%ecx
c00266bf:	0f b6 91 c0 79 03 c0 	movzbl -0x3ffc8640(%ecx),%edx
c00266c6:	8b 7c 24 20          	mov    0x20(%esp),%edi
c00266ca:	88 14 07             	mov    %dl,(%edi,%eax,1)
c00266cd:	83 c0 01             	add    $0x1,%eax
  for (buf = buf_; size-- > 0; buf++)
c00266d0:	3b 44 24 24          	cmp    0x24(%esp),%eax
c00266d4:	74 07                	je     c00266dd <random_bytes+0xa2>
      s_j += s[s_i];
c00266d6:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c00266db:	eb a6                	jmp    c0026683 <random_bytes+0x48>
c00266dd:	0f b6 5c 24 07       	movzbl 0x7(%esp),%ebx
c00266e2:	0f b6 44 24 08       	movzbl 0x8(%esp),%eax
c00266e7:	01 e8                	add    %ebp,%eax
c00266e9:	a2 a2 79 03 c0       	mov    %al,0xc00379a2
c00266ee:	88 1d a1 79 03 c0    	mov    %bl,0xc00379a1
    }
}
c00266f4:	83 c4 0c             	add    $0xc,%esp
c00266f7:	5b                   	pop    %ebx
c00266f8:	5e                   	pop    %esi
c00266f9:	5f                   	pop    %edi
c00266fa:	5d                   	pop    %ebp
c00266fb:	c3                   	ret    

c00266fc <random_ulong>:
/* Returns a pseudo-random unsigned long.
   Use random_ulong() % n to obtain a random number in the range
   0...n (exclusive). */
unsigned long
random_ulong (void) 
{
c00266fc:	83 ec 18             	sub    $0x18,%esp
  unsigned long ul;
  random_bytes (&ul, sizeof ul);
c00266ff:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c0026706:	00 
c0026707:	8d 44 24 14          	lea    0x14(%esp),%eax
c002670b:	89 04 24             	mov    %eax,(%esp)
c002670e:	e8 28 ff ff ff       	call   c002663b <random_bytes>
  return ul;
}
c0026713:	8b 44 24 14          	mov    0x14(%esp),%eax
c0026717:	83 c4 18             	add    $0x18,%esp
c002671a:	c3                   	ret    
c002671b:	90                   	nop
c002671c:	90                   	nop
c002671d:	90                   	nop
c002671e:	90                   	nop
c002671f:	90                   	nop

c0026720 <vsnprintf_helper>:
}

/* Helper function for vsnprintf(). */
static void
vsnprintf_helper (char ch, void *aux_)
{
c0026720:	53                   	push   %ebx
c0026721:	8b 5c 24 08          	mov    0x8(%esp),%ebx
c0026725:	8b 44 24 0c          	mov    0xc(%esp),%eax
  struct vsnprintf_aux *aux = aux_;

  if (aux->length++ < aux->max_length)
c0026729:	8b 50 04             	mov    0x4(%eax),%edx
c002672c:	8d 4a 01             	lea    0x1(%edx),%ecx
c002672f:	89 48 04             	mov    %ecx,0x4(%eax)
c0026732:	3b 50 08             	cmp    0x8(%eax),%edx
c0026735:	7d 09                	jge    c0026740 <vsnprintf_helper+0x20>
    *aux->p++ = ch;
c0026737:	8b 10                	mov    (%eax),%edx
c0026739:	8d 4a 01             	lea    0x1(%edx),%ecx
c002673c:	89 08                	mov    %ecx,(%eax)
c002673e:	88 1a                	mov    %bl,(%edx)
}
c0026740:	5b                   	pop    %ebx
c0026741:	c3                   	ret    

c0026742 <output_dup>:
}

/* Writes CH to OUTPUT with auxiliary data AUX, CNT times. */
static void
output_dup (char ch, size_t cnt, void (*output) (char, void *), void *aux) 
{
c0026742:	55                   	push   %ebp
c0026743:	57                   	push   %edi
c0026744:	56                   	push   %esi
c0026745:	53                   	push   %ebx
c0026746:	83 ec 1c             	sub    $0x1c,%esp
c0026749:	8b 7c 24 30          	mov    0x30(%esp),%edi
  while (cnt-- > 0)
c002674d:	85 d2                	test   %edx,%edx
c002674f:	74 15                	je     c0026766 <output_dup+0x24>
c0026751:	89 ce                	mov    %ecx,%esi
c0026753:	89 d3                	mov    %edx,%ebx
    output (ch, aux);
c0026755:	0f be e8             	movsbl %al,%ebp
c0026758:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002675c:	89 2c 24             	mov    %ebp,(%esp)
c002675f:	ff d6                	call   *%esi
  while (cnt-- > 0)
c0026761:	83 eb 01             	sub    $0x1,%ebx
c0026764:	75 f2                	jne    c0026758 <output_dup+0x16>
}
c0026766:	83 c4 1c             	add    $0x1c,%esp
c0026769:	5b                   	pop    %ebx
c002676a:	5e                   	pop    %esi
c002676b:	5f                   	pop    %edi
c002676c:	5d                   	pop    %ebp
c002676d:	c3                   	ret    

c002676e <format_integer>:
{
c002676e:	55                   	push   %ebp
c002676f:	57                   	push   %edi
c0026770:	56                   	push   %esi
c0026771:	53                   	push   %ebx
c0026772:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c0026778:	89 c6                	mov    %eax,%esi
c002677a:	89 d7                	mov    %edx,%edi
c002677c:	8b 84 24 a0 00 00 00 	mov    0xa0(%esp),%eax
  sign = 0;
c0026783:	c7 44 24 30 00 00 00 	movl   $0x0,0x30(%esp)
c002678a:	00 
  if (is_signed) 
c002678b:	84 c9                	test   %cl,%cl
c002678d:	74 4c                	je     c00267db <format_integer+0x6d>
      if (c->flags & PLUS)
c002678f:	8b 8c 24 a8 00 00 00 	mov    0xa8(%esp),%ecx
c0026796:	8b 11                	mov    (%ecx),%edx
c0026798:	f6 c2 02             	test   $0x2,%dl
c002679b:	74 14                	je     c00267b1 <format_integer+0x43>
        sign = negative ? '-' : '+';
c002679d:	3c 01                	cmp    $0x1,%al
c002679f:	19 c0                	sbb    %eax,%eax
c00267a1:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267a5:	83 64 24 30 fe       	andl   $0xfffffffe,0x30(%esp)
c00267aa:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c00267af:	eb 2a                	jmp    c00267db <format_integer+0x6d>
      else if (c->flags & SPACE)
c00267b1:	f6 c2 04             	test   $0x4,%dl
c00267b4:	74 14                	je     c00267ca <format_integer+0x5c>
        sign = negative ? '-' : ' ';
c00267b6:	3c 01                	cmp    $0x1,%al
c00267b8:	19 c0                	sbb    %eax,%eax
c00267ba:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267be:	83 64 24 30 f3       	andl   $0xfffffff3,0x30(%esp)
c00267c3:	83 44 24 30 2d       	addl   $0x2d,0x30(%esp)
c00267c8:	eb 11                	jmp    c00267db <format_integer+0x6d>
  sign = 0;
c00267ca:	3c 01                	cmp    $0x1,%al
c00267cc:	19 c0                	sbb    %eax,%eax
c00267ce:	89 44 24 30          	mov    %eax,0x30(%esp)
c00267d2:	f7 54 24 30          	notl   0x30(%esp)
c00267d6:	83 64 24 30 2d       	andl   $0x2d,0x30(%esp)
  x = (c->flags & POUND) && value ? b->x : 0;
c00267db:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c00267e2:	8b 00                	mov    (%eax),%eax
c00267e4:	89 44 24 38          	mov    %eax,0x38(%esp)
c00267e8:	83 e0 08             	and    $0x8,%eax
c00267eb:	89 44 24 3c          	mov    %eax,0x3c(%esp)
c00267ef:	74 5c                	je     c002684d <format_integer+0xdf>
c00267f1:	89 f8                	mov    %edi,%eax
c00267f3:	09 f0                	or     %esi,%eax
c00267f5:	0f 84 e9 00 00 00    	je     c00268e4 <format_integer+0x176>
c00267fb:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026802:	8b 40 08             	mov    0x8(%eax),%eax
c0026805:	89 44 24 34          	mov    %eax,0x34(%esp)
c0026809:	eb 08                	jmp    c0026813 <format_integer+0xa5>
c002680b:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c0026812:	00 
      *cp++ = b->digits[value % b->base];
c0026813:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c002681a:	8b 40 04             	mov    0x4(%eax),%eax
c002681d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026821:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026828:	8b 00                	mov    (%eax),%eax
c002682a:	89 44 24 18          	mov    %eax,0x18(%esp)
c002682e:	89 c1                	mov    %eax,%ecx
c0026830:	c1 f9 1f             	sar    $0x1f,%ecx
c0026833:	89 4c 24 1c          	mov    %ecx,0x1c(%esp)
c0026837:	bb 00 00 00 00       	mov    $0x0,%ebx
c002683c:	8d 6c 24 40          	lea    0x40(%esp),%ebp
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026840:	8b 44 24 38          	mov    0x38(%esp),%eax
c0026844:	83 e0 20             	and    $0x20,%eax
c0026847:	89 44 24 2c          	mov    %eax,0x2c(%esp)
c002684b:	eb 17                	jmp    c0026864 <format_integer+0xf6>
  while (value > 0) 
c002684d:	89 f8                	mov    %edi,%eax
c002684f:	09 f0                	or     %esi,%eax
c0026851:	75 b8                	jne    c002680b <format_integer+0x9d>
  x = (c->flags & POUND) && value ? b->x : 0;
c0026853:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c002685a:	00 
  cp = buf;
c002685b:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c002685f:	e9 92 00 00 00       	jmp    c00268f6 <format_integer+0x188>
      if ((c->flags & GROUP) && digit_cnt > 0 && digit_cnt % b->group == 0)
c0026864:	83 7c 24 2c 00       	cmpl   $0x0,0x2c(%esp)
c0026869:	74 1c                	je     c0026887 <format_integer+0x119>
c002686b:	85 db                	test   %ebx,%ebx
c002686d:	7e 18                	jle    c0026887 <format_integer+0x119>
c002686f:	8b 8c 24 a4 00 00 00 	mov    0xa4(%esp),%ecx
c0026876:	89 d8                	mov    %ebx,%eax
c0026878:	99                   	cltd   
c0026879:	f7 79 0c             	idivl  0xc(%ecx)
c002687c:	85 d2                	test   %edx,%edx
c002687e:	75 07                	jne    c0026887 <format_integer+0x119>
        *cp++ = ',';
c0026880:	c6 45 00 2c          	movb   $0x2c,0x0(%ebp)
c0026884:	8d 6d 01             	lea    0x1(%ebp),%ebp
      *cp++ = b->digits[value % b->base];
c0026887:	8d 45 01             	lea    0x1(%ebp),%eax
c002688a:	89 44 24 24          	mov    %eax,0x24(%esp)
c002688e:	8b 44 24 18          	mov    0x18(%esp),%eax
c0026892:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0026896:	89 44 24 08          	mov    %eax,0x8(%esp)
c002689a:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002689e:	89 34 24             	mov    %esi,(%esp)
c00268a1:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00268a5:	e8 a0 1a 00 00       	call   c002834a <__umoddi3>
c00268aa:	8b 4c 24 28          	mov    0x28(%esp),%ecx
c00268ae:	0f b6 04 01          	movzbl (%ecx,%eax,1),%eax
c00268b2:	88 45 00             	mov    %al,0x0(%ebp)
      value /= b->base;
c00268b5:	8b 44 24 18          	mov    0x18(%esp),%eax
c00268b9:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00268bd:	89 44 24 08          	mov    %eax,0x8(%esp)
c00268c1:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00268c5:	89 34 24             	mov    %esi,(%esp)
c00268c8:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00268cc:	e8 56 1a 00 00       	call   c0028327 <__udivdi3>
c00268d1:	89 c6                	mov    %eax,%esi
c00268d3:	89 d7                	mov    %edx,%edi
      digit_cnt++;
c00268d5:	83 c3 01             	add    $0x1,%ebx
  while (value > 0) 
c00268d8:	89 d1                	mov    %edx,%ecx
c00268da:	09 c1                	or     %eax,%ecx
c00268dc:	74 14                	je     c00268f2 <format_integer+0x184>
      *cp++ = b->digits[value % b->base];
c00268de:	8b 6c 24 24          	mov    0x24(%esp),%ebp
c00268e2:	eb 80                	jmp    c0026864 <format_integer+0xf6>
  x = (c->flags & POUND) && value ? b->x : 0;
c00268e4:	c7 44 24 34 00 00 00 	movl   $0x0,0x34(%esp)
c00268eb:	00 
  cp = buf;
c00268ec:	8d 5c 24 40          	lea    0x40(%esp),%ebx
c00268f0:	eb 04                	jmp    c00268f6 <format_integer+0x188>
c00268f2:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  precision = c->precision < 0 ? 1 : c->precision;
c00268f6:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c00268fd:	8b 50 08             	mov    0x8(%eax),%edx
c0026900:	85 d2                	test   %edx,%edx
c0026902:	b8 01 00 00 00       	mov    $0x1,%eax
c0026907:	0f 48 d0             	cmovs  %eax,%edx
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002690a:	8d 7c 24 40          	lea    0x40(%esp),%edi
c002690e:	89 d8                	mov    %ebx,%eax
c0026910:	29 f8                	sub    %edi,%eax
c0026912:	39 c2                	cmp    %eax,%edx
c0026914:	7e 1f                	jle    c0026935 <format_integer+0x1c7>
c0026916:	8d 44 24 7f          	lea    0x7f(%esp),%eax
c002691a:	39 c3                	cmp    %eax,%ebx
c002691c:	73 17                	jae    c0026935 <format_integer+0x1c7>
c002691e:	89 f9                	mov    %edi,%ecx
c0026920:	89 c6                	mov    %eax,%esi
    *cp++ = '0';
c0026922:	83 c3 01             	add    $0x1,%ebx
c0026925:	c6 43 ff 30          	movb   $0x30,-0x1(%ebx)
c0026929:	89 d8                	mov    %ebx,%eax
c002692b:	29 c8                	sub    %ecx,%eax
  while (cp - buf < precision && cp < buf + sizeof buf - 1)
c002692d:	39 c2                	cmp    %eax,%edx
c002692f:	7e 04                	jle    c0026935 <format_integer+0x1c7>
c0026931:	39 f3                	cmp    %esi,%ebx
c0026933:	75 ed                	jne    c0026922 <format_integer+0x1b4>
  if ((c->flags & POUND) && b->base == 8 && (cp == buf || cp[-1] != '0'))
c0026935:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002693a:	74 20                	je     c002695c <format_integer+0x1ee>
c002693c:	8b 84 24 a4 00 00 00 	mov    0xa4(%esp),%eax
c0026943:	83 38 08             	cmpl   $0x8,(%eax)
c0026946:	75 14                	jne    c002695c <format_integer+0x1ee>
c0026948:	8d 44 24 40          	lea    0x40(%esp),%eax
c002694c:	39 c3                	cmp    %eax,%ebx
c002694e:	74 06                	je     c0026956 <format_integer+0x1e8>
c0026950:	80 7b ff 30          	cmpb   $0x30,-0x1(%ebx)
c0026954:	74 06                	je     c002695c <format_integer+0x1ee>
    *cp++ = '0';
c0026956:	c6 03 30             	movb   $0x30,(%ebx)
c0026959:	8d 5b 01             	lea    0x1(%ebx),%ebx
  pad_cnt = c->width - (cp - buf) - (x ? 2 : 0) - (sign != 0);
c002695c:	29 df                	sub    %ebx,%edi
c002695e:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026965:	03 78 04             	add    0x4(%eax),%edi
c0026968:	83 7c 24 34 01       	cmpl   $0x1,0x34(%esp)
c002696d:	19 c0                	sbb    %eax,%eax
c002696f:	f7 d0                	not    %eax
c0026971:	83 e0 02             	and    $0x2,%eax
c0026974:	83 7c 24 30 00       	cmpl   $0x0,0x30(%esp)
c0026979:	0f 95 c1             	setne  %cl
c002697c:	89 ce                	mov    %ecx,%esi
c002697e:	29 c7                	sub    %eax,%edi
c0026980:	0f b6 c1             	movzbl %cl,%eax
c0026983:	29 c7                	sub    %eax,%edi
c0026985:	b8 00 00 00 00       	mov    $0x0,%eax
c002698a:	0f 48 f8             	cmovs  %eax,%edi
  if ((c->flags & (MINUS | ZERO)) == 0)
c002698d:	f6 44 24 38 11       	testb  $0x11,0x38(%esp)
c0026992:	75 1d                	jne    c00269b1 <format_integer+0x243>
    output_dup (' ', pad_cnt, output, aux);
c0026994:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c002699b:	89 04 24             	mov    %eax,(%esp)
c002699e:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c00269a5:	89 fa                	mov    %edi,%edx
c00269a7:	b8 20 00 00 00       	mov    $0x20,%eax
c00269ac:	e8 91 fd ff ff       	call   c0026742 <output_dup>
  if (sign)
c00269b1:	89 f0                	mov    %esi,%eax
c00269b3:	84 c0                	test   %al,%al
c00269b5:	74 19                	je     c00269d0 <format_integer+0x262>
    output (sign, aux);
c00269b7:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269be:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269c2:	8b 44 24 30          	mov    0x30(%esp),%eax
c00269c6:	89 04 24             	mov    %eax,(%esp)
c00269c9:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (x) 
c00269d0:	83 7c 24 34 00       	cmpl   $0x0,0x34(%esp)
c00269d5:	74 33                	je     c0026a0a <format_integer+0x29c>
      output ('0', aux);
c00269d7:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269de:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269e2:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
c00269e9:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
      output (x, aux); 
c00269f0:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c00269f7:	89 44 24 04          	mov    %eax,0x4(%esp)
c00269fb:	0f be 44 24 34       	movsbl 0x34(%esp),%eax
c0026a00:	89 04 24             	mov    %eax,(%esp)
c0026a03:	ff 94 24 ac 00 00 00 	call   *0xac(%esp)
  if (c->flags & ZERO)
c0026a0a:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a11:	f6 00 10             	testb  $0x10,(%eax)
c0026a14:	74 1d                	je     c0026a33 <format_integer+0x2c5>
    output_dup ('0', pad_cnt, output, aux);
c0026a16:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a1d:	89 04 24             	mov    %eax,(%esp)
c0026a20:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a27:	89 fa                	mov    %edi,%edx
c0026a29:	b8 30 00 00 00       	mov    $0x30,%eax
c0026a2e:	e8 0f fd ff ff       	call   c0026742 <output_dup>
  while (cp > buf)
c0026a33:	8d 44 24 40          	lea    0x40(%esp),%eax
c0026a37:	39 c3                	cmp    %eax,%ebx
c0026a39:	76 2b                	jbe    c0026a66 <format_integer+0x2f8>
c0026a3b:	89 c6                	mov    %eax,%esi
c0026a3d:	89 7c 24 18          	mov    %edi,0x18(%esp)
c0026a41:	8b bc 24 ac 00 00 00 	mov    0xac(%esp),%edi
c0026a48:	8b ac 24 b0 00 00 00 	mov    0xb0(%esp),%ebp
    output (*--cp, aux);
c0026a4f:	83 eb 01             	sub    $0x1,%ebx
c0026a52:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0026a56:	0f be 03             	movsbl (%ebx),%eax
c0026a59:	89 04 24             	mov    %eax,(%esp)
c0026a5c:	ff d7                	call   *%edi
  while (cp > buf)
c0026a5e:	39 f3                	cmp    %esi,%ebx
c0026a60:	75 ed                	jne    c0026a4f <format_integer+0x2e1>
c0026a62:	8b 7c 24 18          	mov    0x18(%esp),%edi
  if (c->flags & MINUS)
c0026a66:	8b 84 24 a8 00 00 00 	mov    0xa8(%esp),%eax
c0026a6d:	f6 00 01             	testb  $0x1,(%eax)
c0026a70:	74 1d                	je     c0026a8f <format_integer+0x321>
    output_dup (' ', pad_cnt, output, aux);
c0026a72:	8b 84 24 b0 00 00 00 	mov    0xb0(%esp),%eax
c0026a79:	89 04 24             	mov    %eax,(%esp)
c0026a7c:	8b 8c 24 ac 00 00 00 	mov    0xac(%esp),%ecx
c0026a83:	89 fa                	mov    %edi,%edx
c0026a85:	b8 20 00 00 00       	mov    $0x20,%eax
c0026a8a:	e8 b3 fc ff ff       	call   c0026742 <output_dup>
}
c0026a8f:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c0026a95:	5b                   	pop    %ebx
c0026a96:	5e                   	pop    %esi
c0026a97:	5f                   	pop    %edi
c0026a98:	5d                   	pop    %ebp
c0026a99:	c3                   	ret    

c0026a9a <format_string>:
   auxiliary data AUX. */
static void
format_string (const char *string, int length,
               struct printf_conversion *c,
               void (*output) (char, void *), void *aux) 
{
c0026a9a:	55                   	push   %ebp
c0026a9b:	57                   	push   %edi
c0026a9c:	56                   	push   %esi
c0026a9d:	53                   	push   %ebx
c0026a9e:	83 ec 1c             	sub    $0x1c,%esp
c0026aa1:	89 c5                	mov    %eax,%ebp
c0026aa3:	89 d3                	mov    %edx,%ebx
c0026aa5:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026aa9:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0026aad:	8b 74 24 30          	mov    0x30(%esp),%esi
c0026ab1:	8b 7c 24 34          	mov    0x34(%esp),%edi
  int i;
  if (c->width > length && (c->flags & MINUS) == 0)
c0026ab5:	8b 51 04             	mov    0x4(%ecx),%edx
c0026ab8:	39 da                	cmp    %ebx,%edx
c0026aba:	7e 16                	jle    c0026ad2 <format_string+0x38>
c0026abc:	f6 01 01             	testb  $0x1,(%ecx)
c0026abf:	75 11                	jne    c0026ad2 <format_string+0x38>
    output_dup (' ', c->width - length, output, aux);
c0026ac1:	29 da                	sub    %ebx,%edx
c0026ac3:	89 3c 24             	mov    %edi,(%esp)
c0026ac6:	89 f1                	mov    %esi,%ecx
c0026ac8:	b8 20 00 00 00       	mov    $0x20,%eax
c0026acd:	e8 70 fc ff ff       	call   c0026742 <output_dup>
  for (i = 0; i < length; i++)
c0026ad2:	8b 44 24 08          	mov    0x8(%esp),%eax
c0026ad6:	85 c0                	test   %eax,%eax
c0026ad8:	7e 17                	jle    c0026af1 <format_string+0x57>
c0026ada:	89 eb                	mov    %ebp,%ebx
c0026adc:	01 c5                	add    %eax,%ebp
    output (string[i], aux);
c0026ade:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0026ae2:	0f be 03             	movsbl (%ebx),%eax
c0026ae5:	89 04 24             	mov    %eax,(%esp)
c0026ae8:	ff d6                	call   *%esi
c0026aea:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < length; i++)
c0026aed:	39 eb                	cmp    %ebp,%ebx
c0026aef:	75 ed                	jne    c0026ade <format_string+0x44>
  if (c->width > length && (c->flags & MINUS) != 0)
c0026af1:	8b 44 24 0c          	mov    0xc(%esp),%eax
c0026af5:	8b 50 04             	mov    0x4(%eax),%edx
c0026af8:	39 54 24 08          	cmp    %edx,0x8(%esp)
c0026afc:	7d 18                	jge    c0026b16 <format_string+0x7c>
c0026afe:	f6 00 01             	testb  $0x1,(%eax)
c0026b01:	74 13                	je     c0026b16 <format_string+0x7c>
    output_dup (' ', c->width - length, output, aux);
c0026b03:	2b 54 24 08          	sub    0x8(%esp),%edx
c0026b07:	89 3c 24             	mov    %edi,(%esp)
c0026b0a:	89 f1                	mov    %esi,%ecx
c0026b0c:	b8 20 00 00 00       	mov    $0x20,%eax
c0026b11:	e8 2c fc ff ff       	call   c0026742 <output_dup>
}
c0026b16:	83 c4 1c             	add    $0x1c,%esp
c0026b19:	5b                   	pop    %ebx
c0026b1a:	5e                   	pop    %esi
c0026b1b:	5f                   	pop    %edi
c0026b1c:	5d                   	pop    %ebp
c0026b1d:	c3                   	ret    

c0026b1e <printf>:
{
c0026b1e:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0026b21:	8d 44 24 24          	lea    0x24(%esp),%eax
  retval = vprintf (format, args);
c0026b25:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b29:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b2d:	89 04 24             	mov    %eax,(%esp)
c0026b30:	e8 25 3b 00 00       	call   c002a65a <vprintf>
}
c0026b35:	83 c4 1c             	add    $0x1c,%esp
c0026b38:	c3                   	ret    

c0026b39 <__printf>:
/* Wrapper for __vprintf() that converts varargs into a
   va_list. */
void
__printf (const char *format,
          void (*output) (char, void *), void *aux, ...) 
{
c0026b39:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;

  va_start (args, aux);
c0026b3c:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  __vprintf (format, args, output, aux);
c0026b40:	8b 54 24 28          	mov    0x28(%esp),%edx
c0026b44:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0026b48:	8b 54 24 24          	mov    0x24(%esp),%edx
c0026b4c:	89 54 24 08          	mov    %edx,0x8(%esp)
c0026b50:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026b54:	8b 44 24 20          	mov    0x20(%esp),%eax
c0026b58:	89 04 24             	mov    %eax,(%esp)
c0026b5b:	e8 04 00 00 00       	call   c0026b64 <__vprintf>
  va_end (args);
}
c0026b60:	83 c4 1c             	add    $0x1c,%esp
c0026b63:	c3                   	ret    

c0026b64 <__vprintf>:
{
c0026b64:	55                   	push   %ebp
c0026b65:	57                   	push   %edi
c0026b66:	56                   	push   %esi
c0026b67:	53                   	push   %ebx
c0026b68:	83 ec 5c             	sub    $0x5c,%esp
c0026b6b:	8b 7c 24 70          	mov    0x70(%esp),%edi
c0026b6f:	8b 6c 24 74          	mov    0x74(%esp),%ebp
  for (; *format != '\0'; format++)
c0026b73:	0f b6 07             	movzbl (%edi),%eax
c0026b76:	84 c0                	test   %al,%al
c0026b78:	0f 84 1c 06 00 00    	je     c002719a <__vprintf+0x636>
      if (*format != '%') 
c0026b7e:	3c 25                	cmp    $0x25,%al
c0026b80:	74 19                	je     c0026b9b <__vprintf+0x37>
          output (*format, aux);
c0026b82:	8b 5c 24 7c          	mov    0x7c(%esp),%ebx
c0026b86:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0026b8a:	0f be c0             	movsbl %al,%eax
c0026b8d:	89 04 24             	mov    %eax,(%esp)
c0026b90:	ff 54 24 78          	call   *0x78(%esp)
          continue;
c0026b94:	89 fb                	mov    %edi,%ebx
c0026b96:	e9 d5 05 00 00       	jmp    c0027170 <__vprintf+0x60c>
      format++;
c0026b9b:	8d 77 01             	lea    0x1(%edi),%esi
      if (*format == '%') 
c0026b9e:	b9 00 00 00 00       	mov    $0x0,%ecx
c0026ba3:	80 7f 01 25          	cmpb   $0x25,0x1(%edi)
c0026ba7:	75 1c                	jne    c0026bc5 <__vprintf+0x61>
          output ('%', aux);
c0026ba9:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0026bad:	89 44 24 04          	mov    %eax,0x4(%esp)
c0026bb1:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
c0026bb8:	ff 54 24 78          	call   *0x78(%esp)
      format++;
c0026bbc:	89 f3                	mov    %esi,%ebx
          continue;
c0026bbe:	e9 ad 05 00 00       	jmp    c0027170 <__vprintf+0x60c>
      switch (*format++) 
c0026bc3:	89 d6                	mov    %edx,%esi
c0026bc5:	8d 56 01             	lea    0x1(%esi),%edx
c0026bc8:	0f b6 5a ff          	movzbl -0x1(%edx),%ebx
c0026bcc:	8d 43 e0             	lea    -0x20(%ebx),%eax
c0026bcf:	3c 10                	cmp    $0x10,%al
c0026bd1:	77 29                	ja     c0026bfc <__vprintf+0x98>
c0026bd3:	0f b6 c0             	movzbl %al,%eax
c0026bd6:	ff 24 85 30 da 02 c0 	jmp    *-0x3ffd25d0(,%eax,4)
          c->flags |= MINUS;
c0026bdd:	83 c9 01             	or     $0x1,%ecx
c0026be0:	eb e1                	jmp    c0026bc3 <__vprintf+0x5f>
          c->flags |= PLUS;
c0026be2:	83 c9 02             	or     $0x2,%ecx
c0026be5:	eb dc                	jmp    c0026bc3 <__vprintf+0x5f>
          c->flags |= SPACE;
c0026be7:	83 c9 04             	or     $0x4,%ecx
c0026bea:	eb d7                	jmp    c0026bc3 <__vprintf+0x5f>
          c->flags |= POUND;
c0026bec:	83 c9 08             	or     $0x8,%ecx
c0026bef:	90                   	nop
c0026bf0:	eb d1                	jmp    c0026bc3 <__vprintf+0x5f>
          c->flags |= ZERO;
c0026bf2:	83 c9 10             	or     $0x10,%ecx
c0026bf5:	eb cc                	jmp    c0026bc3 <__vprintf+0x5f>
          c->flags |= GROUP;
c0026bf7:	83 c9 20             	or     $0x20,%ecx
c0026bfa:	eb c7                	jmp    c0026bc3 <__vprintf+0x5f>
      switch (*format++) 
c0026bfc:	89 f0                	mov    %esi,%eax
c0026bfe:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & MINUS)
c0026c02:	f6 c1 01             	test   $0x1,%cl
c0026c05:	74 07                	je     c0026c0e <__vprintf+0xaa>
    c->flags &= ~ZERO;
c0026c07:	83 e1 ef             	and    $0xffffffef,%ecx
c0026c0a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  if (c->flags & PLUS)
c0026c0e:	8b 4c 24 40          	mov    0x40(%esp),%ecx
c0026c12:	f6 c1 02             	test   $0x2,%cl
c0026c15:	74 07                	je     c0026c1e <__vprintf+0xba>
    c->flags &= ~SPACE;
c0026c17:	83 e1 fb             	and    $0xfffffffb,%ecx
c0026c1a:	89 4c 24 40          	mov    %ecx,0x40(%esp)
  c->width = 0;
c0026c1e:	c7 44 24 44 00 00 00 	movl   $0x0,0x44(%esp)
c0026c25:	00 
  if (*format == '*')
c0026c26:	80 fb 2a             	cmp    $0x2a,%bl
c0026c29:	74 15                	je     c0026c40 <__vprintf+0xdc>
      for (; isdigit (*format); format++)
c0026c2b:	0f b6 00             	movzbl (%eax),%eax
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0026c2e:	0f be c8             	movsbl %al,%ecx
c0026c31:	83 e9 30             	sub    $0x30,%ecx
c0026c34:	ba 00 00 00 00       	mov    $0x0,%edx
c0026c39:	83 f9 09             	cmp    $0x9,%ecx
c0026c3c:	76 10                	jbe    c0026c4e <__vprintf+0xea>
c0026c3e:	eb 40                	jmp    c0026c80 <__vprintf+0x11c>
      c->width = va_arg (*args, int);
c0026c40:	8b 45 00             	mov    0x0(%ebp),%eax
c0026c43:	89 44 24 44          	mov    %eax,0x44(%esp)
c0026c47:	8d 6d 04             	lea    0x4(%ebp),%ebp
      switch (*format++) 
c0026c4a:	89 d6                	mov    %edx,%esi
c0026c4c:	eb 1f                	jmp    c0026c6d <__vprintf+0x109>
        c->width = c->width * 10 + *format - '0';
c0026c4e:	8d 14 92             	lea    (%edx,%edx,4),%edx
c0026c51:	0f be c0             	movsbl %al,%eax
c0026c54:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
      for (; isdigit (*format); format++)
c0026c58:	83 c6 01             	add    $0x1,%esi
c0026c5b:	0f b6 06             	movzbl (%esi),%eax
c0026c5e:	0f be c8             	movsbl %al,%ecx
c0026c61:	83 e9 30             	sub    $0x30,%ecx
c0026c64:	83 f9 09             	cmp    $0x9,%ecx
c0026c67:	76 e5                	jbe    c0026c4e <__vprintf+0xea>
c0026c69:	89 54 24 44          	mov    %edx,0x44(%esp)
  if (c->width < 0) 
c0026c6d:	8b 44 24 44          	mov    0x44(%esp),%eax
c0026c71:	85 c0                	test   %eax,%eax
c0026c73:	79 0b                	jns    c0026c80 <__vprintf+0x11c>
      c->width = -c->width;
c0026c75:	f7 d8                	neg    %eax
c0026c77:	89 44 24 44          	mov    %eax,0x44(%esp)
      c->flags |= MINUS;
c0026c7b:	83 4c 24 40 01       	orl    $0x1,0x40(%esp)
  c->precision = -1;
c0026c80:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026c87:	ff 
  if (*format == '.') 
c0026c88:	80 3e 2e             	cmpb   $0x2e,(%esi)
c0026c8b:	0f 85 f0 04 00 00    	jne    c0027181 <__vprintf+0x61d>
      if (*format == '*') 
c0026c91:	80 7e 01 2a          	cmpb   $0x2a,0x1(%esi)
c0026c95:	75 0f                	jne    c0026ca6 <__vprintf+0x142>
          format++;
c0026c97:	83 c6 02             	add    $0x2,%esi
          c->precision = va_arg (*args, int);
c0026c9a:	8b 45 00             	mov    0x0(%ebp),%eax
c0026c9d:	89 44 24 48          	mov    %eax,0x48(%esp)
c0026ca1:	8d 6d 04             	lea    0x4(%ebp),%ebp
c0026ca4:	eb 44                	jmp    c0026cea <__vprintf+0x186>
      format++;
c0026ca6:	8d 56 01             	lea    0x1(%esi),%edx
          c->precision = 0;
c0026ca9:	c7 44 24 48 00 00 00 	movl   $0x0,0x48(%esp)
c0026cb0:	00 
          for (; isdigit (*format); format++)
c0026cb1:	0f b6 46 01          	movzbl 0x1(%esi),%eax
c0026cb5:	0f be c8             	movsbl %al,%ecx
c0026cb8:	83 e9 30             	sub    $0x30,%ecx
c0026cbb:	83 f9 09             	cmp    $0x9,%ecx
c0026cbe:	0f 87 c6 04 00 00    	ja     c002718a <__vprintf+0x626>
c0026cc4:	b9 00 00 00 00       	mov    $0x0,%ecx
            c->precision = c->precision * 10 + *format - '0';
c0026cc9:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
c0026ccc:	0f be c0             	movsbl %al,%eax
c0026ccf:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
          for (; isdigit (*format); format++)
c0026cd3:	83 c2 01             	add    $0x1,%edx
c0026cd6:	0f b6 02             	movzbl (%edx),%eax
c0026cd9:	0f be d8             	movsbl %al,%ebx
c0026cdc:	83 eb 30             	sub    $0x30,%ebx
c0026cdf:	83 fb 09             	cmp    $0x9,%ebx
c0026ce2:	76 e5                	jbe    c0026cc9 <__vprintf+0x165>
c0026ce4:	89 4c 24 48          	mov    %ecx,0x48(%esp)
c0026ce8:	89 d6                	mov    %edx,%esi
      if (c->precision < 0) 
c0026cea:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0026cef:	0f 89 97 04 00 00    	jns    c002718c <__vprintf+0x628>
        c->precision = -1;
c0026cf5:	c7 44 24 48 ff ff ff 	movl   $0xffffffff,0x48(%esp)
c0026cfc:	ff 
c0026cfd:	e9 7f 04 00 00       	jmp    c0027181 <__vprintf+0x61d>
  c->type = INT;
c0026d02:	c7 44 24 4c 03 00 00 	movl   $0x3,0x4c(%esp)
c0026d09:	00 
  switch (*format++) 
c0026d0a:	8d 5e 01             	lea    0x1(%esi),%ebx
c0026d0d:	0f b6 3e             	movzbl (%esi),%edi
c0026d10:	8d 57 98             	lea    -0x68(%edi),%edx
c0026d13:	80 fa 12             	cmp    $0x12,%dl
c0026d16:	77 62                	ja     c0026d7a <__vprintf+0x216>
c0026d18:	0f b6 d2             	movzbl %dl,%edx
c0026d1b:	ff 24 95 74 da 02 c0 	jmp    *-0x3ffd258c(,%edx,4)
      if (*format == 'h') 
c0026d22:	80 7e 01 68          	cmpb   $0x68,0x1(%esi)
c0026d26:	75 0d                	jne    c0026d35 <__vprintf+0x1d1>
          format++;
c0026d28:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = CHAR;
c0026d2b:	c7 44 24 4c 01 00 00 	movl   $0x1,0x4c(%esp)
c0026d32:	00 
c0026d33:	eb 47                	jmp    c0026d7c <__vprintf+0x218>
        c->type = SHORT;
c0026d35:	c7 44 24 4c 02 00 00 	movl   $0x2,0x4c(%esp)
c0026d3c:	00 
c0026d3d:	eb 3d                	jmp    c0026d7c <__vprintf+0x218>
      c->type = INTMAX;
c0026d3f:	c7 44 24 4c 04 00 00 	movl   $0x4,0x4c(%esp)
c0026d46:	00 
c0026d47:	eb 33                	jmp    c0026d7c <__vprintf+0x218>
      if (*format == 'l')
c0026d49:	80 7e 01 6c          	cmpb   $0x6c,0x1(%esi)
c0026d4d:	75 0d                	jne    c0026d5c <__vprintf+0x1f8>
          format++;
c0026d4f:	8d 5e 02             	lea    0x2(%esi),%ebx
          c->type = LONGLONG;
c0026d52:	c7 44 24 4c 06 00 00 	movl   $0x6,0x4c(%esp)
c0026d59:	00 
c0026d5a:	eb 20                	jmp    c0026d7c <__vprintf+0x218>
        c->type = LONG;
c0026d5c:	c7 44 24 4c 05 00 00 	movl   $0x5,0x4c(%esp)
c0026d63:	00 
c0026d64:	eb 16                	jmp    c0026d7c <__vprintf+0x218>
      c->type = PTRDIFFT;
c0026d66:	c7 44 24 4c 07 00 00 	movl   $0x7,0x4c(%esp)
c0026d6d:	00 
c0026d6e:	eb 0c                	jmp    c0026d7c <__vprintf+0x218>
      c->type = SIZET;
c0026d70:	c7 44 24 4c 08 00 00 	movl   $0x8,0x4c(%esp)
c0026d77:	00 
c0026d78:	eb 02                	jmp    c0026d7c <__vprintf+0x218>
  switch (*format++) 
c0026d7a:	89 f3                	mov    %esi,%ebx
      switch (*format) 
c0026d7c:	0f b6 0b             	movzbl (%ebx),%ecx
c0026d7f:	8d 51 bb             	lea    -0x45(%ecx),%edx
c0026d82:	80 fa 33             	cmp    $0x33,%dl
c0026d85:	0f 87 c2 03 00 00    	ja     c002714d <__vprintf+0x5e9>
c0026d8b:	0f b6 d2             	movzbl %dl,%edx
c0026d8e:	ff 24 95 c0 da 02 c0 	jmp    *-0x3ffd2540(,%edx,4)
            switch (c.type) 
c0026d95:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026d9a:	0f 87 c9 00 00 00    	ja     c0026e69 <__vprintf+0x305>
c0026da0:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026da4:	ff 24 85 90 db 02 c0 	jmp    *-0x3ffd2470(,%eax,4)
                value = (signed char) va_arg (args, int);
c0026dab:	0f be 75 00          	movsbl 0x0(%ebp),%esi
c0026daf:	89 f0                	mov    %esi,%eax
c0026db1:	99                   	cltd   
c0026db2:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026db6:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026dba:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dbd:	e9 cb 00 00 00       	jmp    c0026e8d <__vprintf+0x329>
                value = (short) va_arg (args, int);
c0026dc2:	0f bf 75 00          	movswl 0x0(%ebp),%esi
c0026dc6:	89 f0                	mov    %esi,%eax
c0026dc8:	99                   	cltd   
c0026dc9:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026dcd:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026dd1:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dd4:	e9 b4 00 00 00       	jmp    c0026e8d <__vprintf+0x329>
                value = va_arg (args, int);
c0026dd9:	8b 75 00             	mov    0x0(%ebp),%esi
c0026ddc:	89 f0                	mov    %esi,%eax
c0026dde:	99                   	cltd   
c0026ddf:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026de3:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026de7:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026dea:	e9 9e 00 00 00       	jmp    c0026e8d <__vprintf+0x329>
                value = va_arg (args, intmax_t);
c0026def:	8b 45 00             	mov    0x0(%ebp),%eax
c0026df2:	8b 55 04             	mov    0x4(%ebp),%edx
c0026df5:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026df9:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026dfd:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e00:	e9 88 00 00 00       	jmp    c0026e8d <__vprintf+0x329>
                value = va_arg (args, long);
c0026e05:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e08:	89 f0                	mov    %esi,%eax
c0026e0a:	99                   	cltd   
c0026e0b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e0f:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e13:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e16:	eb 75                	jmp    c0026e8d <__vprintf+0x329>
                value = va_arg (args, long long);
c0026e18:	8b 45 00             	mov    0x0(%ebp),%eax
c0026e1b:	8b 55 04             	mov    0x4(%ebp),%edx
c0026e1e:	89 44 24 18          	mov    %eax,0x18(%esp)
c0026e22:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e26:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026e29:	eb 62                	jmp    c0026e8d <__vprintf+0x329>
                value = va_arg (args, ptrdiff_t);
c0026e2b:	8b 75 00             	mov    0x0(%ebp),%esi
c0026e2e:	89 f0                	mov    %esi,%eax
c0026e30:	99                   	cltd   
c0026e31:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e35:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0026e39:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026e3c:	eb 4f                	jmp    c0026e8d <__vprintf+0x329>
                value = va_arg (args, size_t);
c0026e3e:	8d 45 04             	lea    0x4(%ebp),%eax
                if (value > SIZE_MAX / 2)
c0026e41:	8b 7d 00             	mov    0x0(%ebp),%edi
c0026e44:	bd 00 00 00 00       	mov    $0x0,%ebp
c0026e49:	89 fe                	mov    %edi,%esi
c0026e4b:	89 74 24 18          	mov    %esi,0x18(%esp)
c0026e4f:	89 6c 24 1c          	mov    %ebp,0x1c(%esp)
                value = va_arg (args, size_t);
c0026e53:	89 c5                	mov    %eax,%ebp
                if (value > SIZE_MAX / 2)
c0026e55:	81 fe ff ff ff 7f    	cmp    $0x7fffffff,%esi
c0026e5b:	76 30                	jbe    c0026e8d <__vprintf+0x329>
                  value = value - SIZE_MAX - 1;
c0026e5d:	83 44 24 18 00       	addl   $0x0,0x18(%esp)
c0026e62:	83 54 24 1c ff       	adcl   $0xffffffff,0x1c(%esp)
c0026e67:	eb 24                	jmp    c0026e8d <__vprintf+0x329>
                NOT_REACHED ();
c0026e69:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c0026e70:	c0 
c0026e71:	c7 44 24 08 d8 db 02 	movl   $0xc002dbd8,0x8(%esp)
c0026e78:	c0 
c0026e79:	c7 44 24 04 dc 00 00 	movl   $0xdc,0x4(%esp)
c0026e80:	00 
c0026e81:	c7 04 24 79 f8 02 c0 	movl   $0xc002f879,(%esp)
c0026e88:	e8 e6 1a 00 00       	call   c0028973 <debug_panic>
            format_integer (value < 0 ? -value : value,
c0026e8d:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0026e91:	c1 fa 1f             	sar    $0x1f,%edx
c0026e94:	89 d7                	mov    %edx,%edi
c0026e96:	33 7c 24 18          	xor    0x18(%esp),%edi
c0026e9a:	89 7c 24 20          	mov    %edi,0x20(%esp)
c0026e9e:	89 d7                	mov    %edx,%edi
c0026ea0:	33 7c 24 1c          	xor    0x1c(%esp),%edi
c0026ea4:	89 7c 24 24          	mov    %edi,0x24(%esp)
c0026ea8:	8b 74 24 20          	mov    0x20(%esp),%esi
c0026eac:	8b 7c 24 24          	mov    0x24(%esp),%edi
c0026eb0:	29 d6                	sub    %edx,%esi
c0026eb2:	19 d7                	sbb    %edx,%edi
c0026eb4:	89 f0                	mov    %esi,%eax
c0026eb6:	89 fa                	mov    %edi,%edx
c0026eb8:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0026ebc:	89 7c 24 10          	mov    %edi,0x10(%esp)
c0026ec0:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0026ec4:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0026ec8:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0026ecc:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0026ed0:	c7 44 24 04 14 dc 02 	movl   $0xc002dc14,0x4(%esp)
c0026ed7:	c0 
c0026ed8:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0026edc:	c1 e9 1f             	shr    $0x1f,%ecx
c0026edf:	89 0c 24             	mov    %ecx,(%esp)
c0026ee2:	b9 01 00 00 00       	mov    $0x1,%ecx
c0026ee7:	e8 82 f8 ff ff       	call   c002676e <format_integer>
          break;
c0026eec:	e9 7f 02 00 00       	jmp    c0027170 <__vprintf+0x60c>
            switch (c.type) 
c0026ef1:	83 7c 24 4c 08       	cmpl   $0x8,0x4c(%esp)
c0026ef6:	0f 87 b7 00 00 00    	ja     c0026fb3 <__vprintf+0x44f>
c0026efc:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0026f00:	ff 24 85 b4 db 02 c0 	jmp    *-0x3ffd244c(,%eax,4)
                value = (unsigned char) va_arg (args, unsigned);
c0026f07:	0f b6 45 00          	movzbl 0x0(%ebp),%eax
c0026f0b:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f0f:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f16:	00 
c0026f17:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f1a:	e9 b8 00 00 00       	jmp    c0026fd7 <__vprintf+0x473>
                value = (unsigned short) va_arg (args, unsigned);
c0026f1f:	0f b7 45 00          	movzwl 0x0(%ebp),%eax
c0026f23:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f27:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f2e:	00 
c0026f2f:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f32:	e9 a0 00 00 00       	jmp    c0026fd7 <__vprintf+0x473>
                value = va_arg (args, unsigned);
c0026f37:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f3a:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f3f:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f43:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f47:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f4a:	e9 88 00 00 00       	jmp    c0026fd7 <__vprintf+0x473>
                value = va_arg (args, uintmax_t);
c0026f4f:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f52:	8b 55 04             	mov    0x4(%ebp),%edx
c0026f55:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f59:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f5d:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026f60:	eb 75                	jmp    c0026fd7 <__vprintf+0x473>
                value = va_arg (args, unsigned long);
c0026f62:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f65:	ba 00 00 00 00       	mov    $0x0,%edx
c0026f6a:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f6e:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f72:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f75:	eb 60                	jmp    c0026fd7 <__vprintf+0x473>
                value = va_arg (args, unsigned long long);
c0026f77:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f7a:	8b 55 04             	mov    0x4(%ebp),%edx
c0026f7d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f81:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026f85:	8d 6d 08             	lea    0x8(%ebp),%ebp
                break;
c0026f88:	eb 4d                	jmp    c0026fd7 <__vprintf+0x473>
                value &= ((uintmax_t) PTRDIFF_MAX << 1) | 1;
c0026f8a:	8b 45 00             	mov    0x0(%ebp),%eax
c0026f8d:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026f91:	c7 44 24 2c 00 00 00 	movl   $0x0,0x2c(%esp)
c0026f98:	00 
                value = va_arg (args, ptrdiff_t);
c0026f99:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026f9c:	eb 39                	jmp    c0026fd7 <__vprintf+0x473>
                value = va_arg (args, size_t);
c0026f9e:	8b 45 00             	mov    0x0(%ebp),%eax
c0026fa1:	ba 00 00 00 00       	mov    $0x0,%edx
c0026fa6:	89 44 24 28          	mov    %eax,0x28(%esp)
c0026faa:	89 54 24 2c          	mov    %edx,0x2c(%esp)
c0026fae:	8d 6d 04             	lea    0x4(%ebp),%ebp
                break;
c0026fb1:	eb 24                	jmp    c0026fd7 <__vprintf+0x473>
                NOT_REACHED ();
c0026fb3:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c0026fba:	c0 
c0026fbb:	c7 44 24 08 d8 db 02 	movl   $0xc002dbd8,0x8(%esp)
c0026fc2:	c0 
c0026fc3:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0026fca:	00 
c0026fcb:	c7 04 24 79 f8 02 c0 	movl   $0xc002f879,(%esp)
c0026fd2:	e8 9c 19 00 00       	call   c0028973 <debug_panic>
            switch (*format) 
c0026fd7:	80 f9 6f             	cmp    $0x6f,%cl
c0026fda:	74 4d                	je     c0027029 <__vprintf+0x4c5>
c0026fdc:	80 f9 6f             	cmp    $0x6f,%cl
c0026fdf:	7f 07                	jg     c0026fe8 <__vprintf+0x484>
c0026fe1:	80 f9 58             	cmp    $0x58,%cl
c0026fe4:	74 18                	je     c0026ffe <__vprintf+0x49a>
c0026fe6:	eb 1d                	jmp    c0027005 <__vprintf+0x4a1>
c0026fe8:	80 f9 75             	cmp    $0x75,%cl
c0026feb:	90                   	nop
c0026fec:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c0026ff0:	74 3e                	je     c0027030 <__vprintf+0x4cc>
c0026ff2:	80 f9 78             	cmp    $0x78,%cl
c0026ff5:	75 0e                	jne    c0027005 <__vprintf+0x4a1>
              case 'x': b = &base_x; break;
c0026ff7:	b8 f4 db 02 c0       	mov    $0xc002dbf4,%eax
c0026ffc:	eb 37                	jmp    c0027035 <__vprintf+0x4d1>
              case 'X': b = &base_X; break;
c0026ffe:	b8 e4 db 02 c0       	mov    $0xc002dbe4,%eax
c0027003:	eb 30                	jmp    c0027035 <__vprintf+0x4d1>
              default: NOT_REACHED ();
c0027005:	c7 44 24 0c 4c e6 02 	movl   $0xc002e64c,0xc(%esp)
c002700c:	c0 
c002700d:	c7 44 24 08 d8 db 02 	movl   $0xc002dbd8,0x8(%esp)
c0027014:	c0 
c0027015:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
c002701c:	00 
c002701d:	c7 04 24 79 f8 02 c0 	movl   $0xc002f879,(%esp)
c0027024:	e8 4a 19 00 00       	call   c0028973 <debug_panic>
              case 'o': b = &base_o; break;
c0027029:	b8 04 dc 02 c0       	mov    $0xc002dc04,%eax
c002702e:	eb 05                	jmp    c0027035 <__vprintf+0x4d1>
              case 'u': b = &base_d; break;
c0027030:	b8 14 dc 02 c0       	mov    $0xc002dc14,%eax
            format_integer (value, false, false, b, &c, output, aux);
c0027035:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c0027039:	89 7c 24 10          	mov    %edi,0x10(%esp)
c002703d:	8b 7c 24 78          	mov    0x78(%esp),%edi
c0027041:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027045:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027049:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002704d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027051:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0027058:	b9 00 00 00 00       	mov    $0x0,%ecx
c002705d:	8b 44 24 28          	mov    0x28(%esp),%eax
c0027061:	8b 54 24 2c          	mov    0x2c(%esp),%edx
c0027065:	e8 04 f7 ff ff       	call   c002676e <format_integer>
          break;
c002706a:	e9 01 01 00 00       	jmp    c0027170 <__vprintf+0x60c>
            char ch = va_arg (args, int);
c002706f:	8d 75 04             	lea    0x4(%ebp),%esi
c0027072:	8b 45 00             	mov    0x0(%ebp),%eax
c0027075:	88 44 24 3f          	mov    %al,0x3f(%esp)
            format_string (&ch, 1, &c, output, aux);
c0027079:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c002707d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027081:	8b 44 24 78          	mov    0x78(%esp),%eax
c0027085:	89 04 24             	mov    %eax,(%esp)
c0027088:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c002708c:	ba 01 00 00 00       	mov    $0x1,%edx
c0027091:	8d 44 24 3f          	lea    0x3f(%esp),%eax
c0027095:	e8 00 fa ff ff       	call   c0026a9a <format_string>
            char ch = va_arg (args, int);
c002709a:	89 f5                	mov    %esi,%ebp
          break;
c002709c:	e9 cf 00 00 00       	jmp    c0027170 <__vprintf+0x60c>
            const char *s = va_arg (args, char *);
c00270a1:	8d 75 04             	lea    0x4(%ebp),%esi
c00270a4:	8b 7d 00             	mov    0x0(%ebp),%edi
              s = "(null)";
c00270a7:	85 ff                	test   %edi,%edi
c00270a9:	ba 72 f8 02 c0       	mov    $0xc002f872,%edx
c00270ae:	0f 44 fa             	cmove  %edx,%edi
            format_string (s, strnlen (s, c.precision), &c, output, aux);
c00270b1:	89 44 24 04          	mov    %eax,0x4(%esp)
c00270b5:	89 3c 24             	mov    %edi,(%esp)
c00270b8:	e8 9d 0e 00 00       	call   c0027f5a <strnlen>
c00270bd:	8b 4c 24 7c          	mov    0x7c(%esp),%ecx
c00270c1:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00270c5:	8b 4c 24 78          	mov    0x78(%esp),%ecx
c00270c9:	89 0c 24             	mov    %ecx,(%esp)
c00270cc:	8d 4c 24 40          	lea    0x40(%esp),%ecx
c00270d0:	89 c2                	mov    %eax,%edx
c00270d2:	89 f8                	mov    %edi,%eax
c00270d4:	e8 c1 f9 ff ff       	call   c0026a9a <format_string>
            const char *s = va_arg (args, char *);
c00270d9:	89 f5                	mov    %esi,%ebp
          break;
c00270db:	e9 90 00 00 00       	jmp    c0027170 <__vprintf+0x60c>
            void *p = va_arg (args, void *);
c00270e0:	8d 75 04             	lea    0x4(%ebp),%esi
c00270e3:	8b 45 00             	mov    0x0(%ebp),%eax
            c.flags = POUND;
c00270e6:	c7 44 24 40 08 00 00 	movl   $0x8,0x40(%esp)
c00270ed:	00 
            format_integer ((uintptr_t) p, false, false,
c00270ee:	ba 00 00 00 00       	mov    $0x0,%edx
c00270f3:	8b 7c 24 7c          	mov    0x7c(%esp),%edi
c00270f7:	89 7c 24 10          	mov    %edi,0x10(%esp)
c00270fb:	8b 7c 24 78          	mov    0x78(%esp),%edi
c00270ff:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c0027103:	8d 7c 24 40          	lea    0x40(%esp),%edi
c0027107:	89 7c 24 08          	mov    %edi,0x8(%esp)
c002710b:	c7 44 24 04 f4 db 02 	movl   $0xc002dbf4,0x4(%esp)
c0027112:	c0 
c0027113:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002711a:	b9 00 00 00 00       	mov    $0x0,%ecx
c002711f:	e8 4a f6 ff ff       	call   c002676e <format_integer>
            void *p = va_arg (args, void *);
c0027124:	89 f5                	mov    %esi,%ebp
          break;
c0027126:	eb 48                	jmp    c0027170 <__vprintf+0x60c>
          __printf ("<<no %%%c in kernel>>", output, aux, *format);
c0027128:	0f be c9             	movsbl %cl,%ecx
c002712b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002712f:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027133:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027137:	8b 44 24 78          	mov    0x78(%esp),%eax
c002713b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002713f:	c7 04 24 8b f8 02 c0 	movl   $0xc002f88b,(%esp)
c0027146:	e8 ee f9 ff ff       	call   c0026b39 <__printf>
          break;
c002714b:	eb 23                	jmp    c0027170 <__vprintf+0x60c>
          __printf ("<<no %%%c conversion>>", output, aux, *format);
c002714d:	0f be c9             	movsbl %cl,%ecx
c0027150:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0027154:	8b 44 24 7c          	mov    0x7c(%esp),%eax
c0027158:	89 44 24 08          	mov    %eax,0x8(%esp)
c002715c:	8b 44 24 78          	mov    0x78(%esp),%eax
c0027160:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027164:	c7 04 24 a1 f8 02 c0 	movl   $0xc002f8a1,(%esp)
c002716b:	e8 c9 f9 ff ff       	call   c0026b39 <__printf>
  for (; *format != '\0'; format++)
c0027170:	8d 7b 01             	lea    0x1(%ebx),%edi
c0027173:	0f b6 43 01          	movzbl 0x1(%ebx),%eax
c0027177:	84 c0                	test   %al,%al
c0027179:	0f 85 ff f9 ff ff    	jne    c0026b7e <__vprintf+0x1a>
c002717f:	eb 19                	jmp    c002719a <__vprintf+0x636>
  if (c->precision >= 0)
c0027181:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027185:	e9 78 fb ff ff       	jmp    c0026d02 <__vprintf+0x19e>
      format++;
c002718a:	89 d6                	mov    %edx,%esi
  if (c->precision >= 0)
c002718c:	8b 44 24 48          	mov    0x48(%esp),%eax
    c->flags &= ~ZERO;
c0027190:	83 64 24 40 ef       	andl   $0xffffffef,0x40(%esp)
c0027195:	e9 68 fb ff ff       	jmp    c0026d02 <__vprintf+0x19e>
}
c002719a:	83 c4 5c             	add    $0x5c,%esp
c002719d:	5b                   	pop    %ebx
c002719e:	5e                   	pop    %esi
c002719f:	5f                   	pop    %edi
c00271a0:	5d                   	pop    %ebp
c00271a1:	c3                   	ret    

c00271a2 <vsnprintf>:
{
c00271a2:	53                   	push   %ebx
c00271a3:	83 ec 28             	sub    $0x28,%esp
c00271a6:	8b 44 24 34          	mov    0x34(%esp),%eax
c00271aa:	8b 54 24 38          	mov    0x38(%esp),%edx
c00271ae:	8b 4c 24 3c          	mov    0x3c(%esp),%ecx
  aux.p = buffer;
c00271b2:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00271b6:	89 5c 24 14          	mov    %ebx,0x14(%esp)
  aux.length = 0;
c00271ba:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c00271c1:	00 
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c00271c2:	85 c0                	test   %eax,%eax
c00271c4:	74 2c                	je     c00271f2 <vsnprintf+0x50>
c00271c6:	83 e8 01             	sub    $0x1,%eax
c00271c9:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  __vprintf (format, args, vsnprintf_helper, &aux);
c00271cd:	8d 44 24 14          	lea    0x14(%esp),%eax
c00271d1:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00271d5:	c7 44 24 08 20 67 02 	movl   $0xc0026720,0x8(%esp)
c00271dc:	c0 
c00271dd:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c00271e1:	89 14 24             	mov    %edx,(%esp)
c00271e4:	e8 7b f9 ff ff       	call   c0026b64 <__vprintf>
    *aux.p = '\0';
c00271e9:	8b 44 24 14          	mov    0x14(%esp),%eax
c00271ed:	c6 00 00             	movb   $0x0,(%eax)
c00271f0:	eb 24                	jmp    c0027216 <vsnprintf+0x74>
  aux.max_length = buf_size > 0 ? buf_size - 1 : 0;
c00271f2:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c00271f9:	00 
  __vprintf (format, args, vsnprintf_helper, &aux);
c00271fa:	8d 44 24 14          	lea    0x14(%esp),%eax
c00271fe:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027202:	c7 44 24 08 20 67 02 	movl   $0xc0026720,0x8(%esp)
c0027209:	c0 
c002720a:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002720e:	89 14 24             	mov    %edx,(%esp)
c0027211:	e8 4e f9 ff ff       	call   c0026b64 <__vprintf>
  return aux.length;
c0027216:	8b 44 24 18          	mov    0x18(%esp),%eax
}
c002721a:	83 c4 28             	add    $0x28,%esp
c002721d:	5b                   	pop    %ebx
c002721e:	c3                   	ret    

c002721f <snprintf>:
{
c002721f:	83 ec 1c             	sub    $0x1c,%esp
  va_start (args, format);
c0027222:	8d 44 24 2c          	lea    0x2c(%esp),%eax
  retval = vsnprintf (buffer, buf_size, format, args);
c0027226:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002722a:	8b 44 24 28          	mov    0x28(%esp),%eax
c002722e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027232:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027236:	89 44 24 04          	mov    %eax,0x4(%esp)
c002723a:	8b 44 24 20          	mov    0x20(%esp),%eax
c002723e:	89 04 24             	mov    %eax,(%esp)
c0027241:	e8 5c ff ff ff       	call   c00271a2 <vsnprintf>
}
c0027246:	83 c4 1c             	add    $0x1c,%esp
c0027249:	c3                   	ret    

c002724a <hex_dump>:
   starting at OFS for the first byte in BUF.  If ASCII is true
   then the corresponding ASCII characters are also rendered
   alongside. */   
void
hex_dump (uintptr_t ofs, const void *buf_, size_t size, bool ascii)
{
c002724a:	55                   	push   %ebp
c002724b:	57                   	push   %edi
c002724c:	56                   	push   %esi
c002724d:	53                   	push   %ebx
c002724e:	83 ec 2c             	sub    $0x2c,%esp
c0027251:	0f b6 44 24 4c       	movzbl 0x4c(%esp),%eax
c0027256:	88 44 24 1f          	mov    %al,0x1f(%esp)
  const uint8_t *buf = buf_;
  const size_t per_line = 16; /* Maximum bytes per line. */

  while (size > 0)
c002725a:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c002725f:	0f 84 7c 01 00 00    	je     c00273e1 <hex_dump+0x197>
    {
      size_t start, end, n;
      size_t i;
      
      /* Number of bytes on this line. */
      start = ofs % per_line;
c0027265:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0027269:	83 e7 0f             	and    $0xf,%edi
      end = per_line;
      if (end - start > size)
c002726c:	b8 10 00 00 00       	mov    $0x10,%eax
c0027271:	29 f8                	sub    %edi,%eax
        end = start + size;
c0027273:	89 fe                	mov    %edi,%esi
c0027275:	03 74 24 48          	add    0x48(%esp),%esi
c0027279:	3b 44 24 48          	cmp    0x48(%esp),%eax
c002727d:	b8 10 00 00 00       	mov    $0x10,%eax
c0027282:	0f 46 f0             	cmovbe %eax,%esi
      n = end - start;
c0027285:	89 f0                	mov    %esi,%eax
c0027287:	29 f8                	sub    %edi,%eax
c0027289:	89 44 24 18          	mov    %eax,0x18(%esp)

      /* Print line. */
      printf ("%08jx  ", (uintmax_t) ROUND_DOWN (ofs, per_line));
c002728d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0027291:	83 e0 f0             	and    $0xfffffff0,%eax
c0027294:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027298:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c002729f:	00 
c00272a0:	c7 04 24 b8 f8 02 c0 	movl   $0xc002f8b8,(%esp)
c00272a7:	e8 72 f8 ff ff       	call   c0026b1e <printf>
      for (i = 0; i < start; i++)
c00272ac:	85 ff                	test   %edi,%edi
c00272ae:	74 1a                	je     c00272ca <hex_dump+0x80>
c00272b0:	bb 00 00 00 00       	mov    $0x0,%ebx
        printf ("   ");
c00272b5:	c7 04 24 c0 f8 02 c0 	movl   $0xc002f8c0,(%esp)
c00272bc:	e8 5d f8 ff ff       	call   c0026b1e <printf>
      for (i = 0; i < start; i++)
c00272c1:	83 c3 01             	add    $0x1,%ebx
c00272c4:	39 fb                	cmp    %edi,%ebx
c00272c6:	75 ed                	jne    c00272b5 <hex_dump+0x6b>
c00272c8:	eb 08                	jmp    c00272d2 <hex_dump+0x88>
c00272ca:	89 fb                	mov    %edi,%ebx
c00272cc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c00272d0:	eb 02                	jmp    c00272d4 <hex_dump+0x8a>
c00272d2:	89 fb                	mov    %edi,%ebx
      for (; i < end; i++) 
c00272d4:	39 de                	cmp    %ebx,%esi
c00272d6:	76 38                	jbe    c0027310 <hex_dump+0xc6>
c00272d8:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00272dc:	29 fd                	sub    %edi,%ebp
        printf ("%02hhx%c",
c00272de:	83 fb 07             	cmp    $0x7,%ebx
c00272e1:	b8 2d 00 00 00       	mov    $0x2d,%eax
c00272e6:	b9 20 00 00 00       	mov    $0x20,%ecx
c00272eb:	0f 45 c1             	cmovne %ecx,%eax
c00272ee:	89 44 24 08          	mov    %eax,0x8(%esp)
c00272f2:	0f b6 44 1d 00       	movzbl 0x0(%ebp,%ebx,1),%eax
c00272f7:	89 44 24 04          	mov    %eax,0x4(%esp)
c00272fb:	c7 04 24 c4 f8 02 c0 	movl   $0xc002f8c4,(%esp)
c0027302:	e8 17 f8 ff ff       	call   c0026b1e <printf>
      for (; i < end; i++) 
c0027307:	83 c3 01             	add    $0x1,%ebx
c002730a:	39 de                	cmp    %ebx,%esi
c002730c:	77 d0                	ja     c00272de <hex_dump+0x94>
c002730e:	89 f3                	mov    %esi,%ebx
                buf[i - start], i == per_line / 2 - 1? '-' : ' ');
      if (ascii) 
c0027310:	80 7c 24 1f 00       	cmpb   $0x0,0x1f(%esp)
c0027315:	0f 84 a4 00 00 00    	je     c00273bf <hex_dump+0x175>
        {
          for (; i < per_line; i++)
c002731b:	83 fb 0f             	cmp    $0xf,%ebx
c002731e:	77 14                	ja     c0027334 <hex_dump+0xea>
            printf ("   ");
c0027320:	c7 04 24 c0 f8 02 c0 	movl   $0xc002f8c0,(%esp)
c0027327:	e8 f2 f7 ff ff       	call   c0026b1e <printf>
          for (; i < per_line; i++)
c002732c:	83 c3 01             	add    $0x1,%ebx
c002732f:	83 fb 10             	cmp    $0x10,%ebx
c0027332:	75 ec                	jne    c0027320 <hex_dump+0xd6>
          printf ("|");
c0027334:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c002733b:	e8 cc 33 00 00       	call   c002a70c <putchar>
          for (i = 0; i < start; i++)
c0027340:	85 ff                	test   %edi,%edi
c0027342:	74 1a                	je     c002735e <hex_dump+0x114>
c0027344:	bb 00 00 00 00       	mov    $0x0,%ebx
            printf (" ");
c0027349:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0027350:	e8 b7 33 00 00       	call   c002a70c <putchar>
          for (i = 0; i < start; i++)
c0027355:	83 c3 01             	add    $0x1,%ebx
c0027358:	39 fb                	cmp    %edi,%ebx
c002735a:	75 ed                	jne    c0027349 <hex_dump+0xff>
c002735c:	eb 04                	jmp    c0027362 <hex_dump+0x118>
c002735e:	89 fb                	mov    %edi,%ebx
c0027360:	eb 02                	jmp    c0027364 <hex_dump+0x11a>
c0027362:	89 fb                	mov    %edi,%ebx
          for (; i < end; i++)
c0027364:	39 de                	cmp    %ebx,%esi
c0027366:	76 30                	jbe    c0027398 <hex_dump+0x14e>
c0027368:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c002736c:	29 fd                	sub    %edi,%ebp
            printf ("%c",
c002736e:	bf 2e 00 00 00       	mov    $0x2e,%edi
                    isprint (buf[i - start]) ? buf[i - start] : '.');
c0027373:	0f b6 54 1d 00       	movzbl 0x0(%ebp,%ebx,1),%edx
static inline int isprint (int c) { return c >= 32 && c < 127; }
c0027378:	0f b6 c2             	movzbl %dl,%eax
            printf ("%c",
c002737b:	8d 40 e0             	lea    -0x20(%eax),%eax
c002737e:	0f b6 d2             	movzbl %dl,%edx
c0027381:	83 f8 5e             	cmp    $0x5e,%eax
c0027384:	0f 47 d7             	cmova  %edi,%edx
c0027387:	89 14 24             	mov    %edx,(%esp)
c002738a:	e8 7d 33 00 00       	call   c002a70c <putchar>
          for (; i < end; i++)
c002738f:	83 c3 01             	add    $0x1,%ebx
c0027392:	39 de                	cmp    %ebx,%esi
c0027394:	77 dd                	ja     c0027373 <hex_dump+0x129>
c0027396:	eb 02                	jmp    c002739a <hex_dump+0x150>
c0027398:	89 de                	mov    %ebx,%esi
          for (; i < per_line; i++)
c002739a:	83 fe 0f             	cmp    $0xf,%esi
c002739d:	77 14                	ja     c00273b3 <hex_dump+0x169>
            printf (" ");
c002739f:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c00273a6:	e8 61 33 00 00       	call   c002a70c <putchar>
          for (; i < per_line; i++)
c00273ab:	83 c6 01             	add    $0x1,%esi
c00273ae:	83 fe 10             	cmp    $0x10,%esi
c00273b1:	75 ec                	jne    c002739f <hex_dump+0x155>
          printf ("|");
c00273b3:	c7 04 24 7c 00 00 00 	movl   $0x7c,(%esp)
c00273ba:	e8 4d 33 00 00       	call   c002a70c <putchar>
        }
      printf ("\n");
c00273bf:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00273c6:	e8 41 33 00 00       	call   c002a70c <putchar>

      ofs += n;
c00273cb:	8b 44 24 18          	mov    0x18(%esp),%eax
c00273cf:	01 44 24 40          	add    %eax,0x40(%esp)
      buf += n;
c00273d3:	01 44 24 44          	add    %eax,0x44(%esp)
  while (size > 0)
c00273d7:	29 44 24 48          	sub    %eax,0x48(%esp)
c00273db:	0f 85 84 fe ff ff    	jne    c0027265 <hex_dump+0x1b>
      size -= n;
    }
}
c00273e1:	83 c4 2c             	add    $0x2c,%esp
c00273e4:	5b                   	pop    %ebx
c00273e5:	5e                   	pop    %esi
c00273e6:	5f                   	pop    %edi
c00273e7:	5d                   	pop    %ebp
c00273e8:	c3                   	ret    

c00273e9 <print_human_readable_size>:

/* Prints SIZE, which represents a number of bytes, in a
   human-readable format, e.g. "256 kB". */
void
print_human_readable_size (uint64_t size) 
{
c00273e9:	56                   	push   %esi
c00273ea:	53                   	push   %ebx
c00273eb:	83 ec 14             	sub    $0x14,%esp
c00273ee:	8b 4c 24 20          	mov    0x20(%esp),%ecx
c00273f2:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  if (size == 1)
c00273f6:	89 c8                	mov    %ecx,%eax
c00273f8:	83 f0 01             	xor    $0x1,%eax
c00273fb:	09 d8                	or     %ebx,%eax
c00273fd:	74 22                	je     c0027421 <print_human_readable_size+0x38>
  else 
    {
      static const char *factors[] = {"bytes", "kB", "MB", "GB", "TB", NULL};
      const char **fp;

      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c00273ff:	83 fb 00             	cmp    $0x0,%ebx
c0027402:	77 0d                	ja     c0027411 <print_human_readable_size+0x28>
c0027404:	be 6c 5a 03 c0       	mov    $0xc0035a6c,%esi
c0027409:	81 f9 ff 03 00 00    	cmp    $0x3ff,%ecx
c002740f:	76 42                	jbe    c0027453 <print_human_readable_size+0x6a>
c0027411:	be 6c 5a 03 c0       	mov    $0xc0035a6c,%esi
c0027416:	83 3d 70 5a 03 c0 00 	cmpl   $0x0,0xc0035a70
c002741d:	75 10                	jne    c002742f <print_human_readable_size+0x46>
c002741f:	eb 32                	jmp    c0027453 <print_human_readable_size+0x6a>
    printf ("1 byte");
c0027421:	c7 04 24 cd f8 02 c0 	movl   $0xc002f8cd,(%esp)
c0027428:	e8 f1 f6 ff ff       	call   c0026b1e <printf>
c002742d:	eb 3e                	jmp    c002746d <print_human_readable_size+0x84>
        size /= 1024;
c002742f:	89 c8                	mov    %ecx,%eax
c0027431:	89 da                	mov    %ebx,%edx
c0027433:	0f ac d8 0a          	shrd   $0xa,%ebx,%eax
c0027437:	c1 ea 0a             	shr    $0xa,%edx
c002743a:	89 c1                	mov    %eax,%ecx
c002743c:	89 d3                	mov    %edx,%ebx
      for (fp = factors; size >= 1024 && fp[1] != NULL; fp++)
c002743e:	83 c6 04             	add    $0x4,%esi
c0027441:	83 fa 00             	cmp    $0x0,%edx
c0027444:	77 07                	ja     c002744d <print_human_readable_size+0x64>
c0027446:	3d ff 03 00 00       	cmp    $0x3ff,%eax
c002744b:	76 06                	jbe    c0027453 <print_human_readable_size+0x6a>
c002744d:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0027451:	75 dc                	jne    c002742f <print_human_readable_size+0x46>
      printf ("%"PRIu64" %s", size, *fp);
c0027453:	8b 06                	mov    (%esi),%eax
c0027455:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0027459:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002745d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0027461:	c7 04 24 d4 f8 02 c0 	movl   $0xc002f8d4,(%esp)
c0027468:	e8 b1 f6 ff ff       	call   c0026b1e <printf>
    }
}
c002746d:	83 c4 14             	add    $0x14,%esp
c0027470:	5b                   	pop    %ebx
c0027471:	5e                   	pop    %esi
c0027472:	c3                   	ret    
c0027473:	90                   	nop
c0027474:	90                   	nop
c0027475:	90                   	nop
c0027476:	90                   	nop
c0027477:	90                   	nop
c0027478:	90                   	nop
c0027479:	90                   	nop
c002747a:	90                   	nop
c002747b:	90                   	nop
c002747c:	90                   	nop
c002747d:	90                   	nop
c002747e:	90                   	nop
c002747f:	90                   	nop

c0027480 <compare_thunk>:
}

/* Compares A and B by calling the AUX function. */
static int
compare_thunk (const void *a, const void *b, void *aux) 
{
c0027480:	83 ec 1c             	sub    $0x1c,%esp
  int (**compare) (const void *, const void *) = aux;
  return (*compare) (a, b);
c0027483:	8b 44 24 24          	mov    0x24(%esp),%eax
c0027487:	89 44 24 04          	mov    %eax,0x4(%esp)
c002748b:	8b 44 24 20          	mov    0x20(%esp),%eax
c002748f:	89 04 24             	mov    %eax,(%esp)
c0027492:	8b 44 24 28          	mov    0x28(%esp),%eax
c0027496:	ff 10                	call   *(%eax)
}
c0027498:	83 c4 1c             	add    $0x1c,%esp
c002749b:	c3                   	ret    

c002749c <do_swap>:

/* Swaps elements with 1-based indexes A_IDX and B_IDX in ARRAY
   with elements of SIZE bytes each. */
static void
do_swap (unsigned char *array, size_t a_idx, size_t b_idx, size_t size)
{
c002749c:	57                   	push   %edi
c002749d:	56                   	push   %esi
c002749e:	53                   	push   %ebx
c002749f:	8b 7c 24 10          	mov    0x10(%esp),%edi
  unsigned char *a = array + (a_idx - 1) * size;
c00274a3:	8d 5a ff             	lea    -0x1(%edx),%ebx
c00274a6:	0f af df             	imul   %edi,%ebx
c00274a9:	01 c3                	add    %eax,%ebx
  unsigned char *b = array + (b_idx - 1) * size;
c00274ab:	8d 51 ff             	lea    -0x1(%ecx),%edx
c00274ae:	0f af d7             	imul   %edi,%edx
c00274b1:	01 d0                	add    %edx,%eax
  size_t i;

  for (i = 0; i < size; i++)
c00274b3:	85 ff                	test   %edi,%edi
c00274b5:	74 1c                	je     c00274d3 <do_swap+0x37>
c00274b7:	ba 00 00 00 00       	mov    $0x0,%edx
    {
      unsigned char t = a[i];
c00274bc:	0f b6 34 13          	movzbl (%ebx,%edx,1),%esi
      a[i] = b[i];
c00274c0:	0f b6 0c 10          	movzbl (%eax,%edx,1),%ecx
c00274c4:	88 0c 13             	mov    %cl,(%ebx,%edx,1)
      b[i] = t;
c00274c7:	89 f1                	mov    %esi,%ecx
c00274c9:	88 0c 10             	mov    %cl,(%eax,%edx,1)
  for (i = 0; i < size; i++)
c00274cc:	83 c2 01             	add    $0x1,%edx
c00274cf:	39 fa                	cmp    %edi,%edx
c00274d1:	75 e9                	jne    c00274bc <do_swap+0x20>
    }
}
c00274d3:	5b                   	pop    %ebx
c00274d4:	5e                   	pop    %esi
c00274d5:	5f                   	pop    %edi
c00274d6:	c3                   	ret    

c00274d7 <heapify>:
   elements, passing AUX as auxiliary data. */
static void
heapify (unsigned char *array, size_t i, size_t cnt, size_t size,
         int (*compare) (const void *, const void *, void *aux),
         void *aux) 
{
c00274d7:	55                   	push   %ebp
c00274d8:	57                   	push   %edi
c00274d9:	56                   	push   %esi
c00274da:	53                   	push   %ebx
c00274db:	83 ec 2c             	sub    $0x2c,%esp
c00274de:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c00274e2:	89 d3                	mov    %edx,%ebx
c00274e4:	89 4c 24 18          	mov    %ecx,0x18(%esp)
  for (;;) 
    {
      /* Set `max' to the index of the largest element among I
         and its children (if any). */
      size_t left = 2 * i;
c00274e8:	8d 3c 1b             	lea    (%ebx,%ebx,1),%edi
      size_t right = 2 * i + 1;
c00274eb:	8d 6f 01             	lea    0x1(%edi),%ebp
      size_t max = i;
c00274ee:	89 de                	mov    %ebx,%esi
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c00274f0:	3b 7c 24 18          	cmp    0x18(%esp),%edi
c00274f4:	77 30                	ja     c0027526 <heapify+0x4f>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c00274f6:	8b 44 24 48          	mov    0x48(%esp),%eax
c00274fa:	89 44 24 08          	mov    %eax,0x8(%esp)
c00274fe:	8d 43 ff             	lea    -0x1(%ebx),%eax
c0027501:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027506:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002750a:	01 d0                	add    %edx,%eax
c002750c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027510:	8d 47 ff             	lea    -0x1(%edi),%eax
c0027513:	0f af 44 24 40       	imul   0x40(%esp),%eax
c0027518:	01 d0                	add    %edx,%eax
c002751a:	89 04 24             	mov    %eax,(%esp)
c002751d:	ff 54 24 44          	call   *0x44(%esp)
      if (left <= cnt && do_compare (array, left, max, size, compare, aux) > 0)
c0027521:	85 c0                	test   %eax,%eax
      size_t max = i;
c0027523:	0f 4f f7             	cmovg  %edi,%esi
        max = left;
      if (right <= cnt
c0027526:	3b 6c 24 18          	cmp    0x18(%esp),%ebp
c002752a:	77 2d                	ja     c0027559 <heapify+0x82>
  return compare (array + (a_idx - 1) * size, array + (b_idx - 1) * size, aux);
c002752c:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027530:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027534:	8d 46 ff             	lea    -0x1(%esi),%eax
c0027537:	0f af 44 24 40       	imul   0x40(%esp),%eax
c002753c:	8b 4c 24 1c          	mov    0x1c(%esp),%ecx
c0027540:	01 c8                	add    %ecx,%eax
c0027542:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027546:	0f af 7c 24 40       	imul   0x40(%esp),%edi
c002754b:	01 cf                	add    %ecx,%edi
c002754d:	89 3c 24             	mov    %edi,(%esp)
c0027550:	ff 54 24 44          	call   *0x44(%esp)
          && do_compare (array, right, max, size, compare, aux) > 0) 
c0027554:	85 c0                	test   %eax,%eax
        max = right;
c0027556:	0f 4f f5             	cmovg  %ebp,%esi

      /* If the maximum value is already in element I, we're
         done. */
      if (max == i)
c0027559:	39 de                	cmp    %ebx,%esi
c002755b:	74 1b                	je     c0027578 <heapify+0xa1>
        break;

      /* Swap and continue down the heap. */
      do_swap (array, i, max, size);
c002755d:	8b 44 24 40          	mov    0x40(%esp),%eax
c0027561:	89 04 24             	mov    %eax,(%esp)
c0027564:	89 f1                	mov    %esi,%ecx
c0027566:	89 da                	mov    %ebx,%edx
c0027568:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002756c:	e8 2b ff ff ff       	call   c002749c <do_swap>
      i = max;
c0027571:	89 f3                	mov    %esi,%ebx
    }
c0027573:	e9 70 ff ff ff       	jmp    c00274e8 <heapify+0x11>
}
c0027578:	83 c4 2c             	add    $0x2c,%esp
c002757b:	5b                   	pop    %ebx
c002757c:	5e                   	pop    %esi
c002757d:	5f                   	pop    %edi
c002757e:	5d                   	pop    %ebp
c002757f:	c3                   	ret    

c0027580 <atoi>:
{
c0027580:	57                   	push   %edi
c0027581:	56                   	push   %esi
c0027582:	53                   	push   %ebx
c0027583:	83 ec 20             	sub    $0x20,%esp
c0027586:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002758a:	85 d2                	test   %edx,%edx
c002758c:	75 2f                	jne    c00275bd <atoi+0x3d>
c002758e:	c7 44 24 10 1a fa 02 	movl   $0xc002fa1a,0x10(%esp)
c0027595:	c0 
c0027596:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002759d:	c0 
c002759e:	c7 44 24 08 29 dc 02 	movl   $0xc002dc29,0x8(%esp)
c00275a5:	c0 
c00275a6:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
c00275ad:	00 
c00275ae:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c00275b5:	e8 b9 13 00 00       	call   c0028973 <debug_panic>
    s++;
c00275ba:	83 c2 01             	add    $0x1,%edx
  while (isspace ((unsigned char) *s))
c00275bd:	0f b6 02             	movzbl (%edx),%eax
c00275c0:	0f b6 c8             	movzbl %al,%ecx
          || c == '\r' || c == '\t' || c == '\v');
c00275c3:	83 f9 20             	cmp    $0x20,%ecx
c00275c6:	74 f2                	je     c00275ba <atoi+0x3a>
  return (c == ' ' || c == '\f' || c == '\n'
c00275c8:	8d 58 f4             	lea    -0xc(%eax),%ebx
          || c == '\r' || c == '\t' || c == '\v');
c00275cb:	80 fb 01             	cmp    $0x1,%bl
c00275ce:	76 ea                	jbe    c00275ba <atoi+0x3a>
c00275d0:	83 f9 0a             	cmp    $0xa,%ecx
c00275d3:	74 e5                	je     c00275ba <atoi+0x3a>
c00275d5:	89 c1                	mov    %eax,%ecx
c00275d7:	83 e1 fd             	and    $0xfffffffd,%ecx
c00275da:	80 f9 09             	cmp    $0x9,%cl
c00275dd:	74 db                	je     c00275ba <atoi+0x3a>
  if (*s == '+')
c00275df:	3c 2b                	cmp    $0x2b,%al
c00275e1:	75 0a                	jne    c00275ed <atoi+0x6d>
    s++;
c00275e3:	83 c2 01             	add    $0x1,%edx
  negative = false;
c00275e6:	be 00 00 00 00       	mov    $0x0,%esi
c00275eb:	eb 11                	jmp    c00275fe <atoi+0x7e>
c00275ed:	be 00 00 00 00       	mov    $0x0,%esi
  else if (*s == '-')
c00275f2:	3c 2d                	cmp    $0x2d,%al
c00275f4:	75 08                	jne    c00275fe <atoi+0x7e>
      s++;
c00275f6:	8d 52 01             	lea    0x1(%edx),%edx
      negative = true;
c00275f9:	be 01 00 00 00       	mov    $0x1,%esi
  for (value = 0; isdigit (*s); s++)
c00275fe:	0f b6 0a             	movzbl (%edx),%ecx
static inline int isdigit (int c) { return c >= '0' && c <= '9'; }
c0027601:	0f be c1             	movsbl %cl,%eax
c0027604:	83 e8 30             	sub    $0x30,%eax
c0027607:	83 f8 09             	cmp    $0x9,%eax
c002760a:	77 2a                	ja     c0027636 <atoi+0xb6>
c002760c:	b8 00 00 00 00       	mov    $0x0,%eax
    value = value * 10 - (*s - '0');
c0027611:	bf 30 00 00 00       	mov    $0x30,%edi
c0027616:	8d 1c 80             	lea    (%eax,%eax,4),%ebx
c0027619:	0f be c9             	movsbl %cl,%ecx
c002761c:	89 f8                	mov    %edi,%eax
c002761e:	29 c8                	sub    %ecx,%eax
c0027620:	8d 04 58             	lea    (%eax,%ebx,2),%eax
  for (value = 0; isdigit (*s); s++)
c0027623:	83 c2 01             	add    $0x1,%edx
c0027626:	0f b6 0a             	movzbl (%edx),%ecx
c0027629:	0f be d9             	movsbl %cl,%ebx
c002762c:	83 eb 30             	sub    $0x30,%ebx
c002762f:	83 fb 09             	cmp    $0x9,%ebx
c0027632:	76 e2                	jbe    c0027616 <atoi+0x96>
c0027634:	eb 05                	jmp    c002763b <atoi+0xbb>
c0027636:	b8 00 00 00 00       	mov    $0x0,%eax
    value = -value;
c002763b:	89 c2                	mov    %eax,%edx
c002763d:	f7 da                	neg    %edx
c002763f:	89 f3                	mov    %esi,%ebx
c0027641:	84 db                	test   %bl,%bl
c0027643:	0f 44 c2             	cmove  %edx,%eax
}
c0027646:	83 c4 20             	add    $0x20,%esp
c0027649:	5b                   	pop    %ebx
c002764a:	5e                   	pop    %esi
c002764b:	5f                   	pop    %edi
c002764c:	c3                   	ret    

c002764d <sort>:
   B.  Runs in O(n lg n) time and O(1) space in CNT. */
void
sort (void *array, size_t cnt, size_t size,
      int (*compare) (const void *, const void *, void *aux),
      void *aux) 
{
c002764d:	55                   	push   %ebp
c002764e:	57                   	push   %edi
c002764f:	56                   	push   %esi
c0027650:	53                   	push   %ebx
c0027651:	83 ec 2c             	sub    $0x2c,%esp
c0027654:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0027658:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c002765c:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  size_t i;

  ASSERT (array != NULL || cnt == 0);
c0027660:	85 ff                	test   %edi,%edi
c0027662:	75 30                	jne    c0027694 <sort+0x47>
c0027664:	85 db                	test   %ebx,%ebx
c0027666:	74 2c                	je     c0027694 <sort+0x47>
c0027668:	c7 44 24 10 37 f9 02 	movl   $0xc002f937,0x10(%esp)
c002766f:	c0 
c0027670:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027677:	c0 
c0027678:	c7 44 24 08 24 dc 02 	movl   $0xc002dc24,0x8(%esp)
c002767f:	c0 
c0027680:	c7 44 24 04 8a 00 00 	movl   $0x8a,0x4(%esp)
c0027687:	00 
c0027688:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c002768f:	e8 df 12 00 00       	call   c0028973 <debug_panic>
  ASSERT (compare != NULL);
c0027694:	83 7c 24 4c 00       	cmpl   $0x0,0x4c(%esp)
c0027699:	75 2c                	jne    c00276c7 <sort+0x7a>
c002769b:	c7 44 24 10 51 f9 02 	movl   $0xc002f951,0x10(%esp)
c00276a2:	c0 
c00276a3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00276aa:	c0 
c00276ab:	c7 44 24 08 24 dc 02 	movl   $0xc002dc24,0x8(%esp)
c00276b2:	c0 
c00276b3:	c7 44 24 04 8b 00 00 	movl   $0x8b,0x4(%esp)
c00276ba:	00 
c00276bb:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c00276c2:	e8 ac 12 00 00       	call   c0028973 <debug_panic>
  ASSERT (size > 0);
c00276c7:	85 ed                	test   %ebp,%ebp
c00276c9:	75 2c                	jne    c00276f7 <sort+0xaa>
c00276cb:	c7 44 24 10 61 f9 02 	movl   $0xc002f961,0x10(%esp)
c00276d2:	c0 
c00276d3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00276da:	c0 
c00276db:	c7 44 24 08 24 dc 02 	movl   $0xc002dc24,0x8(%esp)
c00276e2:	c0 
c00276e3:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
c00276ea:	00 
c00276eb:	c7 04 24 24 f9 02 c0 	movl   $0xc002f924,(%esp)
c00276f2:	e8 7c 12 00 00       	call   c0028973 <debug_panic>

  /* Build a heap. */
  for (i = cnt / 2; i > 0; i--)
c00276f7:	89 de                	mov    %ebx,%esi
c00276f9:	d1 ee                	shr    %esi
c00276fb:	74 23                	je     c0027720 <sort+0xd3>
    heapify (array, i, cnt, size, compare, aux);
c00276fd:	8b 44 24 50          	mov    0x50(%esp),%eax
c0027701:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027705:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027709:	89 44 24 04          	mov    %eax,0x4(%esp)
c002770d:	89 2c 24             	mov    %ebp,(%esp)
c0027710:	89 d9                	mov    %ebx,%ecx
c0027712:	89 f2                	mov    %esi,%edx
c0027714:	89 f8                	mov    %edi,%eax
c0027716:	e8 bc fd ff ff       	call   c00274d7 <heapify>
  for (i = cnt / 2; i > 0; i--)
c002771b:	83 ee 01             	sub    $0x1,%esi
c002771e:	75 dd                	jne    c00276fd <sort+0xb0>

  /* Sort the heap. */
  for (i = cnt; i > 1; i--) 
c0027720:	83 fb 01             	cmp    $0x1,%ebx
c0027723:	76 3a                	jbe    c002775f <sort+0x112>
c0027725:	8b 74 24 50          	mov    0x50(%esp),%esi
    {
      do_swap (array, 1, i, size);
c0027729:	89 2c 24             	mov    %ebp,(%esp)
c002772c:	89 d9                	mov    %ebx,%ecx
c002772e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027733:	89 f8                	mov    %edi,%eax
c0027735:	e8 62 fd ff ff       	call   c002749c <do_swap>
      heapify (array, 1, i - 1, size, compare, aux); 
c002773a:	83 eb 01             	sub    $0x1,%ebx
c002773d:	89 74 24 08          	mov    %esi,0x8(%esp)
c0027741:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0027745:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027749:	89 2c 24             	mov    %ebp,(%esp)
c002774c:	89 d9                	mov    %ebx,%ecx
c002774e:	ba 01 00 00 00       	mov    $0x1,%edx
c0027753:	89 f8                	mov    %edi,%eax
c0027755:	e8 7d fd ff ff       	call   c00274d7 <heapify>
  for (i = cnt; i > 1; i--) 
c002775a:	83 fb 01             	cmp    $0x1,%ebx
c002775d:	75 ca                	jne    c0027729 <sort+0xdc>
    }
}
c002775f:	83 c4 2c             	add    $0x2c,%esp
c0027762:	5b                   	pop    %ebx
c0027763:	5e                   	pop    %esi
c0027764:	5f                   	pop    %edi
c0027765:	5d                   	pop    %ebp
c0027766:	c3                   	ret    

c0027767 <qsort>:
{
c0027767:	83 ec 2c             	sub    $0x2c,%esp
  sort (array, cnt, size, compare_thunk, &compare);
c002776a:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002776e:	89 44 24 10          	mov    %eax,0x10(%esp)
c0027772:	c7 44 24 0c 80 74 02 	movl   $0xc0027480,0xc(%esp)
c0027779:	c0 
c002777a:	8b 44 24 38          	mov    0x38(%esp),%eax
c002777e:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027782:	8b 44 24 34          	mov    0x34(%esp),%eax
c0027786:	89 44 24 04          	mov    %eax,0x4(%esp)
c002778a:	8b 44 24 30          	mov    0x30(%esp),%eax
c002778e:	89 04 24             	mov    %eax,(%esp)
c0027791:	e8 b7 fe ff ff       	call   c002764d <sort>
}
c0027796:	83 c4 2c             	add    $0x2c,%esp
c0027799:	c3                   	ret    

c002779a <binary_search>:
   B. */
void *
binary_search (const void *key, const void *array, size_t cnt, size_t size,
               int (*compare) (const void *, const void *, void *aux),
               void *aux) 
{
c002779a:	55                   	push   %ebp
c002779b:	57                   	push   %edi
c002779c:	56                   	push   %esi
c002779d:	53                   	push   %ebx
c002779e:	83 ec 1c             	sub    $0x1c,%esp
c00277a1:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c00277a5:	8b 74 24 3c          	mov    0x3c(%esp),%esi
  const unsigned char *first = array;
  const unsigned char *last = array + size * cnt;
c00277a9:	89 f5                	mov    %esi,%ebp
c00277ab:	0f af 6c 24 38       	imul   0x38(%esp),%ebp
c00277b0:	01 dd                	add    %ebx,%ebp

  while (first < last) 
c00277b2:	39 eb                	cmp    %ebp,%ebx
c00277b4:	73 44                	jae    c00277fa <binary_search+0x60>
    {
      size_t range = (last - first) / size;
c00277b6:	89 e8                	mov    %ebp,%eax
c00277b8:	29 d8                	sub    %ebx,%eax
c00277ba:	ba 00 00 00 00       	mov    $0x0,%edx
c00277bf:	f7 f6                	div    %esi
      const unsigned char *middle = first + (range / 2) * size;
c00277c1:	d1 e8                	shr    %eax
c00277c3:	0f af c6             	imul   %esi,%eax
c00277c6:	89 c7                	mov    %eax,%edi
c00277c8:	01 df                	add    %ebx,%edi
      int cmp = compare (key, middle, aux);
c00277ca:	8b 44 24 44          	mov    0x44(%esp),%eax
c00277ce:	89 44 24 08          	mov    %eax,0x8(%esp)
c00277d2:	89 7c 24 04          	mov    %edi,0x4(%esp)
c00277d6:	8b 44 24 30          	mov    0x30(%esp),%eax
c00277da:	89 04 24             	mov    %eax,(%esp)
c00277dd:	ff 54 24 40          	call   *0x40(%esp)

      if (cmp < 0) 
c00277e1:	85 c0                	test   %eax,%eax
c00277e3:	78 0d                	js     c00277f2 <binary_search+0x58>
        last = middle;
      else if (cmp > 0) 
c00277e5:	85 c0                	test   %eax,%eax
c00277e7:	7e 19                	jle    c0027802 <binary_search+0x68>
        first = middle + size;
c00277e9:	8d 1c 37             	lea    (%edi,%esi,1),%ebx
c00277ec:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c00277f0:	eb 02                	jmp    c00277f4 <binary_search+0x5a>
      const unsigned char *middle = first + (range / 2) * size;
c00277f2:	89 fd                	mov    %edi,%ebp
  while (first < last) 
c00277f4:	39 dd                	cmp    %ebx,%ebp
c00277f6:	77 be                	ja     c00277b6 <binary_search+0x1c>
c00277f8:	eb 0c                	jmp    c0027806 <binary_search+0x6c>
      else
        return (void *) middle;
    }
  
  return NULL;
c00277fa:	b8 00 00 00 00       	mov    $0x0,%eax
c00277ff:	90                   	nop
c0027800:	eb 09                	jmp    c002780b <binary_search+0x71>
      const unsigned char *middle = first + (range / 2) * size;
c0027802:	89 f8                	mov    %edi,%eax
c0027804:	eb 05                	jmp    c002780b <binary_search+0x71>
  return NULL;
c0027806:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002780b:	83 c4 1c             	add    $0x1c,%esp
c002780e:	5b                   	pop    %ebx
c002780f:	5e                   	pop    %esi
c0027810:	5f                   	pop    %edi
c0027811:	5d                   	pop    %ebp
c0027812:	c3                   	ret    

c0027813 <bsearch>:
{
c0027813:	83 ec 2c             	sub    $0x2c,%esp
  return binary_search (key, array, cnt, size, compare_thunk, &compare);
c0027816:	8d 44 24 40          	lea    0x40(%esp),%eax
c002781a:	89 44 24 14          	mov    %eax,0x14(%esp)
c002781e:	c7 44 24 10 80 74 02 	movl   $0xc0027480,0x10(%esp)
c0027825:	c0 
c0027826:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c002782a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002782e:	8b 44 24 38          	mov    0x38(%esp),%eax
c0027832:	89 44 24 08          	mov    %eax,0x8(%esp)
c0027836:	8b 44 24 34          	mov    0x34(%esp),%eax
c002783a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002783e:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027842:	89 04 24             	mov    %eax,(%esp)
c0027845:	e8 50 ff ff ff       	call   c002779a <binary_search>
}
c002784a:	83 c4 2c             	add    $0x2c,%esp
c002784d:	c3                   	ret    
c002784e:	90                   	nop
c002784f:	90                   	nop

c0027850 <memcpy>:

/* Copies SIZE bytes from SRC to DST, which must not overlap.
   Returns DST. */
void *
memcpy (void *dst_, const void *src_, size_t size) 
{
c0027850:	56                   	push   %esi
c0027851:	53                   	push   %ebx
c0027852:	83 ec 24             	sub    $0x24,%esp
c0027855:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027859:	8b 74 24 34          	mov    0x34(%esp),%esi
c002785d:	8b 5c 24 38          	mov    0x38(%esp),%ebx
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c0027861:	85 db                	test   %ebx,%ebx
c0027863:	0f 94 c2             	sete   %dl
c0027866:	85 c0                	test   %eax,%eax
c0027868:	75 30                	jne    c002789a <memcpy+0x4a>
c002786a:	84 d2                	test   %dl,%dl
c002786c:	75 2c                	jne    c002789a <memcpy+0x4a>
c002786e:	c7 44 24 10 6a f9 02 	movl   $0xc002f96a,0x10(%esp)
c0027875:	c0 
c0027876:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002787d:	c0 
c002787e:	c7 44 24 08 79 dc 02 	movl   $0xc002dc79,0x8(%esp)
c0027885:	c0 
c0027886:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002788d:	00 
c002788e:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027895:	e8 d9 10 00 00       	call   c0028973 <debug_panic>
  ASSERT (src != NULL || size == 0);
c002789a:	85 f6                	test   %esi,%esi
c002789c:	75 04                	jne    c00278a2 <memcpy+0x52>
c002789e:	84 d2                	test   %dl,%dl
c00278a0:	74 0b                	je     c00278ad <memcpy+0x5d>

  while (size-- > 0)
c00278a2:	ba 00 00 00 00       	mov    $0x0,%edx
c00278a7:	85 db                	test   %ebx,%ebx
c00278a9:	75 2e                	jne    c00278d9 <memcpy+0x89>
c00278ab:	eb 3a                	jmp    c00278e7 <memcpy+0x97>
  ASSERT (src != NULL || size == 0);
c00278ad:	c7 44 24 10 96 f9 02 	movl   $0xc002f996,0x10(%esp)
c00278b4:	c0 
c00278b5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00278bc:	c0 
c00278bd:	c7 44 24 08 79 dc 02 	movl   $0xc002dc79,0x8(%esp)
c00278c4:	c0 
c00278c5:	c7 44 24 04 0d 00 00 	movl   $0xd,0x4(%esp)
c00278cc:	00 
c00278cd:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c00278d4:	e8 9a 10 00 00       	call   c0028973 <debug_panic>
    *dst++ = *src++;
c00278d9:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
c00278dd:	88 0c 10             	mov    %cl,(%eax,%edx,1)
c00278e0:	83 c2 01             	add    $0x1,%edx
  while (size-- > 0)
c00278e3:	39 da                	cmp    %ebx,%edx
c00278e5:	75 f2                	jne    c00278d9 <memcpy+0x89>

  return dst_;
}
c00278e7:	83 c4 24             	add    $0x24,%esp
c00278ea:	5b                   	pop    %ebx
c00278eb:	5e                   	pop    %esi
c00278ec:	c3                   	ret    

c00278ed <memmove>:

/* Copies SIZE bytes from SRC to DST, which are allowed to
   overlap.  Returns DST. */
void *
memmove (void *dst_, const void *src_, size_t size) 
{
c00278ed:	57                   	push   %edi
c00278ee:	56                   	push   %esi
c00278ef:	53                   	push   %ebx
c00278f0:	83 ec 20             	sub    $0x20,%esp
c00278f3:	8b 74 24 30          	mov    0x30(%esp),%esi
c00278f7:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c00278fb:	8b 7c 24 38          	mov    0x38(%esp),%edi
  unsigned char *dst = dst_;
  const unsigned char *src = src_;

  ASSERT (dst != NULL || size == 0);
c00278ff:	85 ff                	test   %edi,%edi
c0027901:	0f 94 c2             	sete   %dl
c0027904:	85 f6                	test   %esi,%esi
c0027906:	75 30                	jne    c0027938 <memmove+0x4b>
c0027908:	84 d2                	test   %dl,%dl
c002790a:	75 2c                	jne    c0027938 <memmove+0x4b>
c002790c:	c7 44 24 10 6a f9 02 	movl   $0xc002f96a,0x10(%esp)
c0027913:	c0 
c0027914:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002791b:	c0 
c002791c:	c7 44 24 08 71 dc 02 	movl   $0xc002dc71,0x8(%esp)
c0027923:	c0 
c0027924:	c7 44 24 04 1d 00 00 	movl   $0x1d,0x4(%esp)
c002792b:	00 
c002792c:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027933:	e8 3b 10 00 00       	call   c0028973 <debug_panic>
  ASSERT (src != NULL || size == 0);
c0027938:	85 db                	test   %ebx,%ebx
c002793a:	75 30                	jne    c002796c <memmove+0x7f>
c002793c:	84 d2                	test   %dl,%dl
c002793e:	75 2c                	jne    c002796c <memmove+0x7f>
c0027940:	c7 44 24 10 96 f9 02 	movl   $0xc002f996,0x10(%esp)
c0027947:	c0 
c0027948:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002794f:	c0 
c0027950:	c7 44 24 08 71 dc 02 	movl   $0xc002dc71,0x8(%esp)
c0027957:	c0 
c0027958:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002795f:	00 
c0027960:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027967:	e8 07 10 00 00       	call   c0028973 <debug_panic>

  if (dst < src) 
c002796c:	39 de                	cmp    %ebx,%esi
c002796e:	73 1b                	jae    c002798b <memmove+0x9e>
    {
      while (size-- > 0)
c0027970:	85 ff                	test   %edi,%edi
c0027972:	74 40                	je     c00279b4 <memmove+0xc7>
c0027974:	ba 00 00 00 00       	mov    $0x0,%edx
        *dst++ = *src++;
c0027979:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
c002797d:	88 0c 16             	mov    %cl,(%esi,%edx,1)
c0027980:	83 c2 01             	add    $0x1,%edx
      while (size-- > 0)
c0027983:	39 fa                	cmp    %edi,%edx
c0027985:	75 f2                	jne    c0027979 <memmove+0x8c>
c0027987:	01 fe                	add    %edi,%esi
c0027989:	eb 29                	jmp    c00279b4 <memmove+0xc7>
    }
  else 
    {
      dst += size;
c002798b:	8d 04 3e             	lea    (%esi,%edi,1),%eax
      src += size;
c002798e:	01 fb                	add    %edi,%ebx
      while (size-- > 0)
c0027990:	8d 57 ff             	lea    -0x1(%edi),%edx
c0027993:	85 ff                	test   %edi,%edi
c0027995:	74 1b                	je     c00279b2 <memmove+0xc5>
c0027997:	f7 df                	neg    %edi
c0027999:	89 f9                	mov    %edi,%ecx
c002799b:	01 fb                	add    %edi,%ebx
c002799d:	01 c1                	add    %eax,%ecx
c002799f:	89 ce                	mov    %ecx,%esi
        *--dst = *--src;
c00279a1:	0f b6 04 13          	movzbl (%ebx,%edx,1),%eax
c00279a5:	88 04 11             	mov    %al,(%ecx,%edx,1)
      while (size-- > 0)
c00279a8:	83 ea 01             	sub    $0x1,%edx
c00279ab:	83 fa ff             	cmp    $0xffffffff,%edx
c00279ae:	75 ef                	jne    c002799f <memmove+0xb2>
c00279b0:	eb 02                	jmp    c00279b4 <memmove+0xc7>
      dst += size;
c00279b2:	89 c6                	mov    %eax,%esi
    }

  return dst;
}
c00279b4:	89 f0                	mov    %esi,%eax
c00279b6:	83 c4 20             	add    $0x20,%esp
c00279b9:	5b                   	pop    %ebx
c00279ba:	5e                   	pop    %esi
c00279bb:	5f                   	pop    %edi
c00279bc:	c3                   	ret    

c00279bd <memcmp>:
   at A and B.  Returns a positive value if the byte in A is
   greater, a negative value if the byte in B is greater, or zero
   if blocks A and B are equal. */
int
memcmp (const void *a_, const void *b_, size_t size) 
{
c00279bd:	57                   	push   %edi
c00279be:	56                   	push   %esi
c00279bf:	53                   	push   %ebx
c00279c0:	83 ec 20             	sub    $0x20,%esp
c00279c3:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c00279c7:	8b 74 24 34          	mov    0x34(%esp),%esi
c00279cb:	8b 44 24 38          	mov    0x38(%esp),%eax
  const unsigned char *a = a_;
  const unsigned char *b = b_;

  ASSERT (a != NULL || size == 0);
c00279cf:	85 c0                	test   %eax,%eax
c00279d1:	0f 94 c2             	sete   %dl
c00279d4:	85 db                	test   %ebx,%ebx
c00279d6:	75 30                	jne    c0027a08 <memcmp+0x4b>
c00279d8:	84 d2                	test   %dl,%dl
c00279da:	75 2c                	jne    c0027a08 <memcmp+0x4b>
c00279dc:	c7 44 24 10 af f9 02 	movl   $0xc002f9af,0x10(%esp)
c00279e3:	c0 
c00279e4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00279eb:	c0 
c00279ec:	c7 44 24 08 6a dc 02 	movl   $0xc002dc6a,0x8(%esp)
c00279f3:	c0 
c00279f4:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
c00279fb:	00 
c00279fc:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027a03:	e8 6b 0f 00 00       	call   c0028973 <debug_panic>
  ASSERT (b != NULL || size == 0);
c0027a08:	85 f6                	test   %esi,%esi
c0027a0a:	75 04                	jne    c0027a10 <memcmp+0x53>
c0027a0c:	84 d2                	test   %dl,%dl
c0027a0e:	74 18                	je     c0027a28 <memcmp+0x6b>

  for (; size-- > 0; a++, b++)
c0027a10:	8d 78 ff             	lea    -0x1(%eax),%edi
c0027a13:	85 c0                	test   %eax,%eax
c0027a15:	74 64                	je     c0027a7b <memcmp+0xbe>
    if (*a != *b)
c0027a17:	0f b6 13             	movzbl (%ebx),%edx
c0027a1a:	0f b6 0e             	movzbl (%esi),%ecx
c0027a1d:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a22:	38 ca                	cmp    %cl,%dl
c0027a24:	74 4a                	je     c0027a70 <memcmp+0xb3>
c0027a26:	eb 3c                	jmp    c0027a64 <memcmp+0xa7>
  ASSERT (b != NULL || size == 0);
c0027a28:	c7 44 24 10 c6 f9 02 	movl   $0xc002f9c6,0x10(%esp)
c0027a2f:	c0 
c0027a30:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027a37:	c0 
c0027a38:	c7 44 24 08 6a dc 02 	movl   $0xc002dc6a,0x8(%esp)
c0027a3f:	c0 
c0027a40:	c7 44 24 04 3b 00 00 	movl   $0x3b,0x4(%esp)
c0027a47:	00 
c0027a48:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027a4f:	e8 1f 0f 00 00       	call   c0028973 <debug_panic>
    if (*a != *b)
c0027a54:	0f b6 54 03 01       	movzbl 0x1(%ebx,%eax,1),%edx
c0027a59:	83 c0 01             	add    $0x1,%eax
c0027a5c:	0f b6 0c 06          	movzbl (%esi,%eax,1),%ecx
c0027a60:	38 ca                	cmp    %cl,%dl
c0027a62:	74 0c                	je     c0027a70 <memcmp+0xb3>
      return *a > *b ? +1 : -1;
c0027a64:	38 d1                	cmp    %dl,%cl
c0027a66:	19 c0                	sbb    %eax,%eax
c0027a68:	83 e0 02             	and    $0x2,%eax
c0027a6b:	83 e8 01             	sub    $0x1,%eax
c0027a6e:	eb 10                	jmp    c0027a80 <memcmp+0xc3>
  for (; size-- > 0; a++, b++)
c0027a70:	39 f8                	cmp    %edi,%eax
c0027a72:	75 e0                	jne    c0027a54 <memcmp+0x97>
  return 0;
c0027a74:	b8 00 00 00 00       	mov    $0x0,%eax
c0027a79:	eb 05                	jmp    c0027a80 <memcmp+0xc3>
c0027a7b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027a80:	83 c4 20             	add    $0x20,%esp
c0027a83:	5b                   	pop    %ebx
c0027a84:	5e                   	pop    %esi
c0027a85:	5f                   	pop    %edi
c0027a86:	c3                   	ret    

c0027a87 <strcmp>:
   char) is greater, a negative value if the character in B (as
   an unsigned char) is greater, or zero if strings A and B are
   equal. */
int
strcmp (const char *a_, const char *b_) 
{
c0027a87:	83 ec 2c             	sub    $0x2c,%esp
c0027a8a:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c0027a8e:	8b 54 24 34          	mov    0x34(%esp),%edx
  const unsigned char *a = (const unsigned char *) a_;
  const unsigned char *b = (const unsigned char *) b_;

  ASSERT (a != NULL);
c0027a92:	85 c9                	test   %ecx,%ecx
c0027a94:	75 2c                	jne    c0027ac2 <strcmp+0x3b>
c0027a96:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c0027a9d:	c0 
c0027a9e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027aa5:	c0 
c0027aa6:	c7 44 24 08 63 dc 02 	movl   $0xc002dc63,0x8(%esp)
c0027aad:	c0 
c0027aae:	c7 44 24 04 4e 00 00 	movl   $0x4e,0x4(%esp)
c0027ab5:	00 
c0027ab6:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027abd:	e8 b1 0e 00 00       	call   c0028973 <debug_panic>
  ASSERT (b != NULL);
c0027ac2:	85 d2                	test   %edx,%edx
c0027ac4:	74 0e                	je     c0027ad4 <strcmp+0x4d>

  while (*a != '\0' && *a == *b) 
c0027ac6:	0f b6 01             	movzbl (%ecx),%eax
c0027ac9:	84 c0                	test   %al,%al
c0027acb:	74 44                	je     c0027b11 <strcmp+0x8a>
c0027acd:	3a 02                	cmp    (%edx),%al
c0027acf:	90                   	nop
c0027ad0:	74 2e                	je     c0027b00 <strcmp+0x79>
c0027ad2:	eb 3d                	jmp    c0027b11 <strcmp+0x8a>
  ASSERT (b != NULL);
c0027ad4:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0027adb:	c0 
c0027adc:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027ae3:	c0 
c0027ae4:	c7 44 24 08 63 dc 02 	movl   $0xc002dc63,0x8(%esp)
c0027aeb:	c0 
c0027aec:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
c0027af3:	00 
c0027af4:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027afb:	e8 73 0e 00 00       	call   c0028973 <debug_panic>
    {
      a++;
c0027b00:	83 c1 01             	add    $0x1,%ecx
      b++;
c0027b03:	83 c2 01             	add    $0x1,%edx
  while (*a != '\0' && *a == *b) 
c0027b06:	0f b6 01             	movzbl (%ecx),%eax
c0027b09:	84 c0                	test   %al,%al
c0027b0b:	74 04                	je     c0027b11 <strcmp+0x8a>
c0027b0d:	3a 02                	cmp    (%edx),%al
c0027b0f:	74 ef                	je     c0027b00 <strcmp+0x79>
    }

  return *a < *b ? -1 : *a > *b;
c0027b11:	0f b6 12             	movzbl (%edx),%edx
c0027b14:	38 c2                	cmp    %al,%dl
c0027b16:	77 0a                	ja     c0027b22 <strcmp+0x9b>
c0027b18:	38 d0                	cmp    %dl,%al
c0027b1a:	0f 97 c0             	seta   %al
c0027b1d:	0f b6 c0             	movzbl %al,%eax
c0027b20:	eb 05                	jmp    c0027b27 <strcmp+0xa0>
c0027b22:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0027b27:	83 c4 2c             	add    $0x2c,%esp
c0027b2a:	c3                   	ret    

c0027b2b <memchr>:
/* Returns a pointer to the first occurrence of CH in the first
   SIZE bytes starting at BLOCK.  Returns a null pointer if CH
   does not occur in BLOCK. */
void *
memchr (const void *block_, int ch_, size_t size) 
{
c0027b2b:	56                   	push   %esi
c0027b2c:	53                   	push   %ebx
c0027b2d:	83 ec 24             	sub    $0x24,%esp
c0027b30:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027b34:	8b 74 24 34          	mov    0x34(%esp),%esi
c0027b38:	8b 54 24 38          	mov    0x38(%esp),%edx
  const unsigned char *block = block_;
  unsigned char ch = ch_;
c0027b3c:	89 f3                	mov    %esi,%ebx

  ASSERT (block != NULL || size == 0);
c0027b3e:	85 c0                	test   %eax,%eax
c0027b40:	75 04                	jne    c0027b46 <memchr+0x1b>
c0027b42:	85 d2                	test   %edx,%edx
c0027b44:	75 14                	jne    c0027b5a <memchr+0x2f>

  for (; size-- > 0; block++)
c0027b46:	8d 4a ff             	lea    -0x1(%edx),%ecx
c0027b49:	85 d2                	test   %edx,%edx
c0027b4b:	74 4e                	je     c0027b9b <memchr+0x70>
    if (*block == ch)
c0027b4d:	89 f2                	mov    %esi,%edx
c0027b4f:	38 10                	cmp    %dl,(%eax)
c0027b51:	74 4d                	je     c0027ba0 <memchr+0x75>
c0027b53:	ba 00 00 00 00       	mov    $0x0,%edx
c0027b58:	eb 33                	jmp    c0027b8d <memchr+0x62>
  ASSERT (block != NULL || size == 0);
c0027b5a:	c7 44 24 10 e7 f9 02 	movl   $0xc002f9e7,0x10(%esp)
c0027b61:	c0 
c0027b62:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027b69:	c0 
c0027b6a:	c7 44 24 08 5c dc 02 	movl   $0xc002dc5c,0x8(%esp)
c0027b71:	c0 
c0027b72:	c7 44 24 04 63 00 00 	movl   $0x63,0x4(%esp)
c0027b79:	00 
c0027b7a:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027b81:	e8 ed 0d 00 00       	call   c0028973 <debug_panic>
c0027b86:	83 c2 01             	add    $0x1,%edx
    if (*block == ch)
c0027b89:	38 18                	cmp    %bl,(%eax)
c0027b8b:	74 13                	je     c0027ba0 <memchr+0x75>
  for (; size-- > 0; block++)
c0027b8d:	83 c0 01             	add    $0x1,%eax
c0027b90:	39 ca                	cmp    %ecx,%edx
c0027b92:	75 f2                	jne    c0027b86 <memchr+0x5b>
      return (void *) block;

  return NULL;
c0027b94:	b8 00 00 00 00       	mov    $0x0,%eax
c0027b99:	eb 05                	jmp    c0027ba0 <memchr+0x75>
c0027b9b:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027ba0:	83 c4 24             	add    $0x24,%esp
c0027ba3:	5b                   	pop    %ebx
c0027ba4:	5e                   	pop    %esi
c0027ba5:	c3                   	ret    

c0027ba6 <strchr>:
   null pointer if C does not appear in STRING.  If C == '\0'
   then returns a pointer to the null terminator at the end of
   STRING. */
char *
strchr (const char *string, int c_) 
{
c0027ba6:	53                   	push   %ebx
c0027ba7:	83 ec 28             	sub    $0x28,%esp
c0027baa:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027bae:	8b 54 24 34          	mov    0x34(%esp),%edx
  char c = c_;

  ASSERT (string != NULL);
c0027bb2:	85 c0                	test   %eax,%eax
c0027bb4:	74 0b                	je     c0027bc1 <strchr+0x1b>
c0027bb6:	89 d1                	mov    %edx,%ecx

  for (;;) 
    if (*string == c)
c0027bb8:	0f b6 18             	movzbl (%eax),%ebx
c0027bbb:	38 d3                	cmp    %dl,%bl
c0027bbd:	75 2e                	jne    c0027bed <strchr+0x47>
c0027bbf:	eb 4e                	jmp    c0027c0f <strchr+0x69>
  ASSERT (string != NULL);
c0027bc1:	c7 44 24 10 02 fa 02 	movl   $0xc002fa02,0x10(%esp)
c0027bc8:	c0 
c0027bc9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027bd0:	c0 
c0027bd1:	c7 44 24 08 55 dc 02 	movl   $0xc002dc55,0x8(%esp)
c0027bd8:	c0 
c0027bd9:	c7 44 24 04 75 00 00 	movl   $0x75,0x4(%esp)
c0027be0:	00 
c0027be1:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027be8:	e8 86 0d 00 00       	call   c0028973 <debug_panic>
      return (char *) string;
    else if (*string == '\0')
c0027bed:	84 db                	test   %bl,%bl
c0027bef:	75 06                	jne    c0027bf7 <strchr+0x51>
c0027bf1:	eb 10                	jmp    c0027c03 <strchr+0x5d>
c0027bf3:	84 d2                	test   %dl,%dl
c0027bf5:	74 13                	je     c0027c0a <strchr+0x64>
      return NULL;
    else
      string++;
c0027bf7:	83 c0 01             	add    $0x1,%eax
    if (*string == c)
c0027bfa:	0f b6 10             	movzbl (%eax),%edx
c0027bfd:	38 ca                	cmp    %cl,%dl
c0027bff:	75 f2                	jne    c0027bf3 <strchr+0x4d>
c0027c01:	eb 0c                	jmp    c0027c0f <strchr+0x69>
      return NULL;
c0027c03:	b8 00 00 00 00       	mov    $0x0,%eax
c0027c08:	eb 05                	jmp    c0027c0f <strchr+0x69>
c0027c0a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027c0f:	83 c4 28             	add    $0x28,%esp
c0027c12:	5b                   	pop    %ebx
c0027c13:	c3                   	ret    

c0027c14 <strcspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters that are not in STOP. */
size_t
strcspn (const char *string, const char *stop) 
{
c0027c14:	57                   	push   %edi
c0027c15:	56                   	push   %esi
c0027c16:	53                   	push   %ebx
c0027c17:	83 ec 10             	sub    $0x10,%esp
c0027c1a:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027c1e:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;

  for (length = 0; string[length] != '\0'; length++)
c0027c22:	0f b6 16             	movzbl (%esi),%edx
c0027c25:	84 d2                	test   %dl,%dl
c0027c27:	74 25                	je     c0027c4e <strcspn+0x3a>
c0027c29:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (stop, string[length]) != NULL)
c0027c2e:	0f be d2             	movsbl %dl,%edx
c0027c31:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c35:	89 3c 24             	mov    %edi,(%esp)
c0027c38:	e8 69 ff ff ff       	call   c0027ba6 <strchr>
c0027c3d:	85 c0                	test   %eax,%eax
c0027c3f:	75 12                	jne    c0027c53 <strcspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027c41:	83 c3 01             	add    $0x1,%ebx
c0027c44:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027c48:	84 d2                	test   %dl,%dl
c0027c4a:	75 e2                	jne    c0027c2e <strcspn+0x1a>
c0027c4c:	eb 05                	jmp    c0027c53 <strcspn+0x3f>
c0027c4e:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027c53:	89 d8                	mov    %ebx,%eax
c0027c55:	83 c4 10             	add    $0x10,%esp
c0027c58:	5b                   	pop    %ebx
c0027c59:	5e                   	pop    %esi
c0027c5a:	5f                   	pop    %edi
c0027c5b:	c3                   	ret    

c0027c5c <strpbrk>:
/* Returns a pointer to the first character in STRING that is
   also in STOP.  If no character in STRING is in STOP, returns a
   null pointer. */
char *
strpbrk (const char *string, const char *stop) 
{
c0027c5c:	56                   	push   %esi
c0027c5d:	53                   	push   %ebx
c0027c5e:	83 ec 14             	sub    $0x14,%esp
c0027c61:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c0027c65:	8b 74 24 24          	mov    0x24(%esp),%esi
  for (; *string != '\0'; string++)
c0027c69:	0f b6 13             	movzbl (%ebx),%edx
c0027c6c:	84 d2                	test   %dl,%dl
c0027c6e:	74 1f                	je     c0027c8f <strpbrk+0x33>
    if (strchr (stop, *string) != NULL)
c0027c70:	0f be d2             	movsbl %dl,%edx
c0027c73:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027c77:	89 34 24             	mov    %esi,(%esp)
c0027c7a:	e8 27 ff ff ff       	call   c0027ba6 <strchr>
c0027c7f:	85 c0                	test   %eax,%eax
c0027c81:	75 13                	jne    c0027c96 <strpbrk+0x3a>
  for (; *string != '\0'; string++)
c0027c83:	83 c3 01             	add    $0x1,%ebx
c0027c86:	0f b6 13             	movzbl (%ebx),%edx
c0027c89:	84 d2                	test   %dl,%dl
c0027c8b:	75 e3                	jne    c0027c70 <strpbrk+0x14>
c0027c8d:	eb 09                	jmp    c0027c98 <strpbrk+0x3c>
      return (char *) string;
  return NULL;
c0027c8f:	b8 00 00 00 00       	mov    $0x0,%eax
c0027c94:	eb 02                	jmp    c0027c98 <strpbrk+0x3c>
c0027c96:	89 d8                	mov    %ebx,%eax
}
c0027c98:	83 c4 14             	add    $0x14,%esp
c0027c9b:	5b                   	pop    %ebx
c0027c9c:	5e                   	pop    %esi
c0027c9d:	c3                   	ret    

c0027c9e <strrchr>:

/* Returns a pointer to the last occurrence of C in STRING.
   Returns a null pointer if C does not occur in STRING. */
char *
strrchr (const char *string, int c_) 
{
c0027c9e:	53                   	push   %ebx
c0027c9f:	8b 54 24 08          	mov    0x8(%esp),%edx
  char c = c_;
c0027ca3:	0f b6 5c 24 0c       	movzbl 0xc(%esp),%ebx
  const char *p = NULL;

  for (; *string != '\0'; string++)
c0027ca8:	0f b6 0a             	movzbl (%edx),%ecx
c0027cab:	84 c9                	test   %cl,%cl
c0027cad:	74 16                	je     c0027cc5 <strrchr+0x27>
  const char *p = NULL;
c0027caf:	b8 00 00 00 00       	mov    $0x0,%eax
c0027cb4:	38 cb                	cmp    %cl,%bl
c0027cb6:	0f 44 c2             	cmove  %edx,%eax
  for (; *string != '\0'; string++)
c0027cb9:	83 c2 01             	add    $0x1,%edx
c0027cbc:	0f b6 0a             	movzbl (%edx),%ecx
c0027cbf:	84 c9                	test   %cl,%cl
c0027cc1:	75 f1                	jne    c0027cb4 <strrchr+0x16>
c0027cc3:	eb 05                	jmp    c0027cca <strrchr+0x2c>
  const char *p = NULL;
c0027cc5:	b8 00 00 00 00       	mov    $0x0,%eax
    if (*string == c)
      p = string;
  return (char *) p;
}
c0027cca:	5b                   	pop    %ebx
c0027ccb:	c3                   	ret    

c0027ccc <strspn>:

/* Returns the length of the initial substring of STRING that
   consists of characters in SKIP. */
size_t
strspn (const char *string, const char *skip) 
{
c0027ccc:	57                   	push   %edi
c0027ccd:	56                   	push   %esi
c0027cce:	53                   	push   %ebx
c0027ccf:	83 ec 10             	sub    $0x10,%esp
c0027cd2:	8b 74 24 20          	mov    0x20(%esp),%esi
c0027cd6:	8b 7c 24 24          	mov    0x24(%esp),%edi
  size_t length;
  
  for (length = 0; string[length] != '\0'; length++)
c0027cda:	0f b6 16             	movzbl (%esi),%edx
c0027cdd:	84 d2                	test   %dl,%dl
c0027cdf:	74 25                	je     c0027d06 <strspn+0x3a>
c0027ce1:	bb 00 00 00 00       	mov    $0x0,%ebx
    if (strchr (skip, string[length]) == NULL)
c0027ce6:	0f be d2             	movsbl %dl,%edx
c0027ce9:	89 54 24 04          	mov    %edx,0x4(%esp)
c0027ced:	89 3c 24             	mov    %edi,(%esp)
c0027cf0:	e8 b1 fe ff ff       	call   c0027ba6 <strchr>
c0027cf5:	85 c0                	test   %eax,%eax
c0027cf7:	74 12                	je     c0027d0b <strspn+0x3f>
  for (length = 0; string[length] != '\0'; length++)
c0027cf9:	83 c3 01             	add    $0x1,%ebx
c0027cfc:	0f b6 14 1e          	movzbl (%esi,%ebx,1),%edx
c0027d00:	84 d2                	test   %dl,%dl
c0027d02:	75 e2                	jne    c0027ce6 <strspn+0x1a>
c0027d04:	eb 05                	jmp    c0027d0b <strspn+0x3f>
c0027d06:	bb 00 00 00 00       	mov    $0x0,%ebx
      break;
  return length;
}
c0027d0b:	89 d8                	mov    %ebx,%eax
c0027d0d:	83 c4 10             	add    $0x10,%esp
c0027d10:	5b                   	pop    %ebx
c0027d11:	5e                   	pop    %esi
c0027d12:	5f                   	pop    %edi
c0027d13:	c3                   	ret    

c0027d14 <strtok_r>:
     'to'
     'tokenize.'
*/
char *
strtok_r (char *s, const char *delimiters, char **save_ptr) 
{
c0027d14:	55                   	push   %ebp
c0027d15:	57                   	push   %edi
c0027d16:	56                   	push   %esi
c0027d17:	53                   	push   %ebx
c0027d18:	83 ec 2c             	sub    $0x2c,%esp
c0027d1b:	8b 5c 24 40          	mov    0x40(%esp),%ebx
c0027d1f:	8b 74 24 44          	mov    0x44(%esp),%esi
  char *token;
  
  ASSERT (delimiters != NULL);
c0027d23:	85 f6                	test   %esi,%esi
c0027d25:	75 2c                	jne    c0027d53 <strtok_r+0x3f>
c0027d27:	c7 44 24 10 11 fa 02 	movl   $0xc002fa11,0x10(%esp)
c0027d2e:	c0 
c0027d2f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027d36:	c0 
c0027d37:	c7 44 24 08 4c dc 02 	movl   $0xc002dc4c,0x8(%esp)
c0027d3e:	c0 
c0027d3f:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0027d46:	00 
c0027d47:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027d4e:	e8 20 0c 00 00       	call   c0028973 <debug_panic>
  ASSERT (save_ptr != NULL);
c0027d53:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c0027d58:	75 2c                	jne    c0027d86 <strtok_r+0x72>
c0027d5a:	c7 44 24 10 24 fa 02 	movl   $0xc002fa24,0x10(%esp)
c0027d61:	c0 
c0027d62:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027d69:	c0 
c0027d6a:	c7 44 24 08 4c dc 02 	movl   $0xc002dc4c,0x8(%esp)
c0027d71:	c0 
c0027d72:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c0027d79:	00 
c0027d7a:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027d81:	e8 ed 0b 00 00       	call   c0028973 <debug_panic>

  /* If S is nonnull, start from it.
     If S is null, start from saved position. */
  if (s == NULL)
c0027d86:	85 db                	test   %ebx,%ebx
c0027d88:	75 4c                	jne    c0027dd6 <strtok_r+0xc2>
    s = *save_ptr;
c0027d8a:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027d8e:	8b 18                	mov    (%eax),%ebx
  ASSERT (s != NULL);
c0027d90:	85 db                	test   %ebx,%ebx
c0027d92:	75 42                	jne    c0027dd6 <strtok_r+0xc2>
c0027d94:	c7 44 24 10 1a fa 02 	movl   $0xc002fa1a,0x10(%esp)
c0027d9b:	c0 
c0027d9c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027da3:	c0 
c0027da4:	c7 44 24 08 4c dc 02 	movl   $0xc002dc4c,0x8(%esp)
c0027dab:	c0 
c0027dac:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
c0027db3:	00 
c0027db4:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027dbb:	e8 b3 0b 00 00       	call   c0028973 <debug_panic>
  while (strchr (delimiters, *s) != NULL) 
    {
      /* strchr() will always return nonnull if we're searching
         for a null byte, because every string contains a null
         byte (at the end). */
      if (*s == '\0')
c0027dc0:	89 f8                	mov    %edi,%eax
c0027dc2:	84 c0                	test   %al,%al
c0027dc4:	75 0d                	jne    c0027dd3 <strtok_r+0xbf>
        {
          *save_ptr = s;
c0027dc6:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027dca:	89 18                	mov    %ebx,(%eax)
          return NULL;
c0027dcc:	b8 00 00 00 00       	mov    $0x0,%eax
c0027dd1:	eb 56                	jmp    c0027e29 <strtok_r+0x115>
        }

      s++;
c0027dd3:	83 c3 01             	add    $0x1,%ebx
  while (strchr (delimiters, *s) != NULL) 
c0027dd6:	0f b6 3b             	movzbl (%ebx),%edi
c0027dd9:	89 f8                	mov    %edi,%eax
c0027ddb:	0f be c0             	movsbl %al,%eax
c0027dde:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027de2:	89 34 24             	mov    %esi,(%esp)
c0027de5:	e8 bc fd ff ff       	call   c0027ba6 <strchr>
c0027dea:	85 c0                	test   %eax,%eax
c0027dec:	75 d2                	jne    c0027dc0 <strtok_r+0xac>
c0027dee:	89 df                	mov    %ebx,%edi
    }

  /* Skip any non-DELIMITERS up to the end of the string. */
  token = s;
  while (strchr (delimiters, *s) == NULL)
    s++;
c0027df0:	83 c7 01             	add    $0x1,%edi
  while (strchr (delimiters, *s) == NULL)
c0027df3:	0f b6 2f             	movzbl (%edi),%ebp
c0027df6:	89 e8                	mov    %ebp,%eax
c0027df8:	0f be c0             	movsbl %al,%eax
c0027dfb:	89 44 24 04          	mov    %eax,0x4(%esp)
c0027dff:	89 34 24             	mov    %esi,(%esp)
c0027e02:	e8 9f fd ff ff       	call   c0027ba6 <strchr>
c0027e07:	85 c0                	test   %eax,%eax
c0027e09:	74 e5                	je     c0027df0 <strtok_r+0xdc>
  if (*s != '\0') 
c0027e0b:	89 e8                	mov    %ebp,%eax
c0027e0d:	84 c0                	test   %al,%al
c0027e0f:	74 10                	je     c0027e21 <strtok_r+0x10d>
    {
      *s = '\0';
c0027e11:	c6 07 00             	movb   $0x0,(%edi)
      *save_ptr = s + 1;
c0027e14:	83 c7 01             	add    $0x1,%edi
c0027e17:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e1b:	89 38                	mov    %edi,(%eax)
c0027e1d:	89 d8                	mov    %ebx,%eax
c0027e1f:	eb 08                	jmp    c0027e29 <strtok_r+0x115>
    }
  else 
    *save_ptr = s;
c0027e21:	8b 44 24 48          	mov    0x48(%esp),%eax
c0027e25:	89 38                	mov    %edi,(%eax)
c0027e27:	89 d8                	mov    %ebx,%eax
  return token;
}
c0027e29:	83 c4 2c             	add    $0x2c,%esp
c0027e2c:	5b                   	pop    %ebx
c0027e2d:	5e                   	pop    %esi
c0027e2e:	5f                   	pop    %edi
c0027e2f:	5d                   	pop    %ebp
c0027e30:	c3                   	ret    

c0027e31 <memset>:

/* Sets the SIZE bytes in DST to VALUE. */
void *
memset (void *dst_, int value, size_t size) 
{
c0027e31:	56                   	push   %esi
c0027e32:	53                   	push   %ebx
c0027e33:	83 ec 24             	sub    $0x24,%esp
c0027e36:	8b 44 24 30          	mov    0x30(%esp),%eax
c0027e3a:	8b 5c 24 34          	mov    0x34(%esp),%ebx
c0027e3e:	8b 74 24 38          	mov    0x38(%esp),%esi
  unsigned char *dst = dst_;

  ASSERT (dst != NULL || size == 0);
c0027e42:	85 c0                	test   %eax,%eax
c0027e44:	75 04                	jne    c0027e4a <memset+0x19>
c0027e46:	85 f6                	test   %esi,%esi
c0027e48:	75 0b                	jne    c0027e55 <memset+0x24>
c0027e4a:	8d 0c 30             	lea    (%eax,%esi,1),%ecx
  
  while (size-- > 0)
c0027e4d:	89 c2                	mov    %eax,%edx
c0027e4f:	85 f6                	test   %esi,%esi
c0027e51:	75 2e                	jne    c0027e81 <memset+0x50>
c0027e53:	eb 36                	jmp    c0027e8b <memset+0x5a>
  ASSERT (dst != NULL || size == 0);
c0027e55:	c7 44 24 10 6a f9 02 	movl   $0xc002f96a,0x10(%esp)
c0027e5c:	c0 
c0027e5d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027e64:	c0 
c0027e65:	c7 44 24 08 45 dc 02 	movl   $0xc002dc45,0x8(%esp)
c0027e6c:	c0 
c0027e6d:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c0027e74:	00 
c0027e75:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027e7c:	e8 f2 0a 00 00       	call   c0028973 <debug_panic>
    *dst++ = value;
c0027e81:	83 c2 01             	add    $0x1,%edx
c0027e84:	88 5a ff             	mov    %bl,-0x1(%edx)
  while (size-- > 0)
c0027e87:	39 ca                	cmp    %ecx,%edx
c0027e89:	75 f6                	jne    c0027e81 <memset+0x50>

  return dst_;
}
c0027e8b:	83 c4 24             	add    $0x24,%esp
c0027e8e:	5b                   	pop    %ebx
c0027e8f:	5e                   	pop    %esi
c0027e90:	c3                   	ret    

c0027e91 <strlen>:

/* Returns the length of STRING. */
size_t
strlen (const char *string) 
{
c0027e91:	83 ec 2c             	sub    $0x2c,%esp
c0027e94:	8b 54 24 30          	mov    0x30(%esp),%edx
  const char *p;

  ASSERT (string != NULL);
c0027e98:	85 d2                	test   %edx,%edx
c0027e9a:	74 09                	je     c0027ea5 <strlen+0x14>

  for (p = string; *p != '\0'; p++)
c0027e9c:	89 d0                	mov    %edx,%eax
c0027e9e:	80 3a 00             	cmpb   $0x0,(%edx)
c0027ea1:	74 38                	je     c0027edb <strlen+0x4a>
c0027ea3:	eb 2c                	jmp    c0027ed1 <strlen+0x40>
  ASSERT (string != NULL);
c0027ea5:	c7 44 24 10 02 fa 02 	movl   $0xc002fa02,0x10(%esp)
c0027eac:	c0 
c0027ead:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027eb4:	c0 
c0027eb5:	c7 44 24 08 3e dc 02 	movl   $0xc002dc3e,0x8(%esp)
c0027ebc:	c0 
c0027ebd:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
c0027ec4:	00 
c0027ec5:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027ecc:	e8 a2 0a 00 00       	call   c0028973 <debug_panic>
  for (p = string; *p != '\0'; p++)
c0027ed1:	89 d0                	mov    %edx,%eax
c0027ed3:	83 c0 01             	add    $0x1,%eax
c0027ed6:	80 38 00             	cmpb   $0x0,(%eax)
c0027ed9:	75 f8                	jne    c0027ed3 <strlen+0x42>
    continue;
  return p - string;
c0027edb:	29 d0                	sub    %edx,%eax
}
c0027edd:	83 c4 2c             	add    $0x2c,%esp
c0027ee0:	c3                   	ret    

c0027ee1 <strstr>:
{
c0027ee1:	55                   	push   %ebp
c0027ee2:	57                   	push   %edi
c0027ee3:	56                   	push   %esi
c0027ee4:	53                   	push   %ebx
c0027ee5:	83 ec 1c             	sub    $0x1c,%esp
c0027ee8:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  size_t haystack_len = strlen (haystack);
c0027eec:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c0027ef1:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0027ef5:	b8 00 00 00 00       	mov    $0x0,%eax
c0027efa:	89 d9                	mov    %ebx,%ecx
c0027efc:	f2 ae                	repnz scas %es:(%edi),%al
c0027efe:	f7 d1                	not    %ecx
c0027f00:	8d 51 ff             	lea    -0x1(%ecx),%edx
  size_t needle_len = strlen (needle);
c0027f03:	89 ef                	mov    %ebp,%edi
c0027f05:	89 d9                	mov    %ebx,%ecx
c0027f07:	f2 ae                	repnz scas %es:(%edi),%al
c0027f09:	f7 d1                	not    %ecx
c0027f0b:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (haystack_len >= needle_len) 
c0027f0e:	39 fa                	cmp    %edi,%edx
c0027f10:	72 30                	jb     c0027f42 <strstr+0x61>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f12:	29 fa                	sub    %edi,%edx
c0027f14:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0027f18:	bb 00 00 00 00       	mov    $0x0,%ebx
c0027f1d:	89 de                	mov    %ebx,%esi
c0027f1f:	03 74 24 30          	add    0x30(%esp),%esi
        if (!memcmp (haystack + i, needle, needle_len))
c0027f23:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0027f27:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c0027f2b:	89 34 24             	mov    %esi,(%esp)
c0027f2e:	e8 8a fa ff ff       	call   c00279bd <memcmp>
c0027f33:	85 c0                	test   %eax,%eax
c0027f35:	74 12                	je     c0027f49 <strstr+0x68>
      for (i = 0; i <= haystack_len - needle_len; i++)
c0027f37:	83 c3 01             	add    $0x1,%ebx
c0027f3a:	3b 5c 24 0c          	cmp    0xc(%esp),%ebx
c0027f3e:	76 dd                	jbe    c0027f1d <strstr+0x3c>
c0027f40:	eb 0b                	jmp    c0027f4d <strstr+0x6c>
  return NULL;
c0027f42:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f47:	eb 09                	jmp    c0027f52 <strstr+0x71>
        if (!memcmp (haystack + i, needle, needle_len))
c0027f49:	89 f0                	mov    %esi,%eax
c0027f4b:	eb 05                	jmp    c0027f52 <strstr+0x71>
  return NULL;
c0027f4d:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0027f52:	83 c4 1c             	add    $0x1c,%esp
c0027f55:	5b                   	pop    %ebx
c0027f56:	5e                   	pop    %esi
c0027f57:	5f                   	pop    %edi
c0027f58:	5d                   	pop    %ebp
c0027f59:	c3                   	ret    

c0027f5a <strnlen>:

/* If STRING is less than MAXLEN characters in length, returns
   its actual length.  Otherwise, returns MAXLEN. */
size_t
strnlen (const char *string, size_t maxlen) 
{
c0027f5a:	8b 54 24 04          	mov    0x4(%esp),%edx
c0027f5e:	8b 4c 24 08          	mov    0x8(%esp),%ecx
  size_t length;

  for (length = 0; string[length] != '\0' && length < maxlen; length++)
c0027f62:	80 3a 00             	cmpb   $0x0,(%edx)
c0027f65:	74 18                	je     c0027f7f <strnlen+0x25>
c0027f67:	b8 00 00 00 00       	mov    $0x0,%eax
c0027f6c:	85 c9                	test   %ecx,%ecx
c0027f6e:	74 14                	je     c0027f84 <strnlen+0x2a>
c0027f70:	83 c0 01             	add    $0x1,%eax
c0027f73:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
c0027f77:	74 0b                	je     c0027f84 <strnlen+0x2a>
c0027f79:	39 c8                	cmp    %ecx,%eax
c0027f7b:	74 07                	je     c0027f84 <strnlen+0x2a>
c0027f7d:	eb f1                	jmp    c0027f70 <strnlen+0x16>
c0027f7f:	b8 00 00 00 00       	mov    $0x0,%eax
    continue;
  return length;
}
c0027f84:	f3 c3                	repz ret 

c0027f86 <strlcpy>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcpy (char *dst, const char *src, size_t size) 
{
c0027f86:	57                   	push   %edi
c0027f87:	56                   	push   %esi
c0027f88:	53                   	push   %ebx
c0027f89:	83 ec 20             	sub    $0x20,%esp
c0027f8c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0027f90:	8b 54 24 34          	mov    0x34(%esp),%edx
c0027f94:	8b 74 24 38          	mov    0x38(%esp),%esi
  size_t src_len;

  ASSERT (dst != NULL);
c0027f98:	85 db                	test   %ebx,%ebx
c0027f9a:	75 2c                	jne    c0027fc8 <strlcpy+0x42>
c0027f9c:	c7 44 24 10 35 fa 02 	movl   $0xc002fa35,0x10(%esp)
c0027fa3:	c0 
c0027fa4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027fab:	c0 
c0027fac:	c7 44 24 08 36 dc 02 	movl   $0xc002dc36,0x8(%esp)
c0027fb3:	c0 
c0027fb4:	c7 44 24 04 4a 01 00 	movl   $0x14a,0x4(%esp)
c0027fbb:	00 
c0027fbc:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027fc3:	e8 ab 09 00 00       	call   c0028973 <debug_panic>
  ASSERT (src != NULL);
c0027fc8:	85 d2                	test   %edx,%edx
c0027fca:	75 2c                	jne    c0027ff8 <strlcpy+0x72>
c0027fcc:	c7 44 24 10 41 fa 02 	movl   $0xc002fa41,0x10(%esp)
c0027fd3:	c0 
c0027fd4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0027fdb:	c0 
c0027fdc:	c7 44 24 08 36 dc 02 	movl   $0xc002dc36,0x8(%esp)
c0027fe3:	c0 
c0027fe4:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
c0027feb:	00 
c0027fec:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c0027ff3:	e8 7b 09 00 00       	call   c0028973 <debug_panic>

  src_len = strlen (src);
c0027ff8:	89 d7                	mov    %edx,%edi
c0027ffa:	b8 00 00 00 00       	mov    $0x0,%eax
c0027fff:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028004:	f2 ae                	repnz scas %es:(%edi),%al
c0028006:	f7 d1                	not    %ecx
c0028008:	8d 79 ff             	lea    -0x1(%ecx),%edi
  if (size > 0) 
c002800b:	85 f6                	test   %esi,%esi
c002800d:	74 1c                	je     c002802b <strlcpy+0xa5>
    {
      size_t dst_len = size - 1;
c002800f:	83 ee 01             	sub    $0x1,%esi
c0028012:	39 f7                	cmp    %esi,%edi
c0028014:	0f 46 f7             	cmovbe %edi,%esi
      if (src_len < dst_len)
        dst_len = src_len;
      memcpy (dst, src, dst_len);
c0028017:	89 74 24 08          	mov    %esi,0x8(%esp)
c002801b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002801f:	89 1c 24             	mov    %ebx,(%esp)
c0028022:	e8 29 f8 ff ff       	call   c0027850 <memcpy>
      dst[dst_len] = '\0';
c0028027:	c6 04 33 00          	movb   $0x0,(%ebx,%esi,1)
    }
  return src_len;
}
c002802b:	89 f8                	mov    %edi,%eax
c002802d:	83 c4 20             	add    $0x20,%esp
c0028030:	5b                   	pop    %ebx
c0028031:	5e                   	pop    %esi
c0028032:	5f                   	pop    %edi
c0028033:	c3                   	ret    

c0028034 <strlcat>:
   increasingly popular extension.  See
   http://www.courtesan.com/todd/papers/strlcpy.html for
   information on strlcpy(). */
size_t
strlcat (char *dst, const char *src, size_t size) 
{
c0028034:	55                   	push   %ebp
c0028035:	57                   	push   %edi
c0028036:	56                   	push   %esi
c0028037:	53                   	push   %ebx
c0028038:	83 ec 2c             	sub    $0x2c,%esp
c002803b:	8b 6c 24 40          	mov    0x40(%esp),%ebp
c002803f:	8b 54 24 44          	mov    0x44(%esp),%edx
  size_t src_len, dst_len;

  ASSERT (dst != NULL);
c0028043:	85 ed                	test   %ebp,%ebp
c0028045:	75 2c                	jne    c0028073 <strlcat+0x3f>
c0028047:	c7 44 24 10 35 fa 02 	movl   $0xc002fa35,0x10(%esp)
c002804e:	c0 
c002804f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028056:	c0 
c0028057:	c7 44 24 08 2e dc 02 	movl   $0xc002dc2e,0x8(%esp)
c002805e:	c0 
c002805f:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
c0028066:	00 
c0028067:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c002806e:	e8 00 09 00 00       	call   c0028973 <debug_panic>
  ASSERT (src != NULL);
c0028073:	85 d2                	test   %edx,%edx
c0028075:	75 2c                	jne    c00280a3 <strlcat+0x6f>
c0028077:	c7 44 24 10 41 fa 02 	movl   $0xc002fa41,0x10(%esp)
c002807e:	c0 
c002807f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028086:	c0 
c0028087:	c7 44 24 08 2e dc 02 	movl   $0xc002dc2e,0x8(%esp)
c002808e:	c0 
c002808f:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
c0028096:	00 
c0028097:	c7 04 24 83 f9 02 c0 	movl   $0xc002f983,(%esp)
c002809e:	e8 d0 08 00 00       	call   c0028973 <debug_panic>

  src_len = strlen (src);
c00280a3:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
c00280a8:	89 d7                	mov    %edx,%edi
c00280aa:	b8 00 00 00 00       	mov    $0x0,%eax
c00280af:	89 d9                	mov    %ebx,%ecx
c00280b1:	f2 ae                	repnz scas %es:(%edi),%al
c00280b3:	f7 d1                	not    %ecx
c00280b5:	8d 71 ff             	lea    -0x1(%ecx),%esi
  dst_len = strlen (dst);
c00280b8:	89 ef                	mov    %ebp,%edi
c00280ba:	89 d9                	mov    %ebx,%ecx
c00280bc:	f2 ae                	repnz scas %es:(%edi),%al
c00280be:	89 cb                	mov    %ecx,%ebx
c00280c0:	f7 d3                	not    %ebx
c00280c2:	83 eb 01             	sub    $0x1,%ebx
  if (size > 0 && dst_len < size) 
c00280c5:	3b 5c 24 48          	cmp    0x48(%esp),%ebx
c00280c9:	73 2c                	jae    c00280f7 <strlcat+0xc3>
c00280cb:	83 7c 24 48 00       	cmpl   $0x0,0x48(%esp)
c00280d0:	74 25                	je     c00280f7 <strlcat+0xc3>
    {
      size_t copy_cnt = size - dst_len - 1;
c00280d2:	8b 44 24 48          	mov    0x48(%esp),%eax
c00280d6:	8d 78 ff             	lea    -0x1(%eax),%edi
c00280d9:	29 df                	sub    %ebx,%edi
c00280db:	39 f7                	cmp    %esi,%edi
c00280dd:	0f 47 fe             	cmova  %esi,%edi
      if (src_len < copy_cnt)
        copy_cnt = src_len;
      memcpy (dst + dst_len, src, copy_cnt);
c00280e0:	01 dd                	add    %ebx,%ebp
c00280e2:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00280e6:	89 54 24 04          	mov    %edx,0x4(%esp)
c00280ea:	89 2c 24             	mov    %ebp,(%esp)
c00280ed:	e8 5e f7 ff ff       	call   c0027850 <memcpy>
      dst[dst_len + copy_cnt] = '\0';
c00280f2:	c6 44 3d 00 00       	movb   $0x0,0x0(%ebp,%edi,1)
    }
  return src_len + dst_len;
c00280f7:	8d 04 33             	lea    (%ebx,%esi,1),%eax
}
c00280fa:	83 c4 2c             	add    $0x2c,%esp
c00280fd:	5b                   	pop    %ebx
c00280fe:	5e                   	pop    %esi
c00280ff:	5f                   	pop    %edi
c0028100:	5d                   	pop    %ebp
c0028101:	c3                   	ret    
c0028102:	90                   	nop
c0028103:	90                   	nop
c0028104:	90                   	nop
c0028105:	90                   	nop
c0028106:	90                   	nop
c0028107:	90                   	nop
c0028108:	90                   	nop
c0028109:	90                   	nop
c002810a:	90                   	nop
c002810b:	90                   	nop
c002810c:	90                   	nop
c002810d:	90                   	nop
c002810e:	90                   	nop
c002810f:	90                   	nop

c0028110 <udiv64>:

/* Divides unsigned 64-bit N by unsigned 64-bit D and returns the
   quotient. */
static uint64_t
udiv64 (uint64_t n, uint64_t d)
{
c0028110:	55                   	push   %ebp
c0028111:	57                   	push   %edi
c0028112:	56                   	push   %esi
c0028113:	53                   	push   %ebx
c0028114:	83 ec 1c             	sub    $0x1c,%esp
c0028117:	89 04 24             	mov    %eax,(%esp)
c002811a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002811e:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0028122:	8b 6c 24 34          	mov    0x34(%esp),%ebp
  if ((d >> 32) == 0) 
c0028126:	89 ea                	mov    %ebp,%edx
c0028128:	85 ed                	test   %ebp,%ebp
c002812a:	75 37                	jne    c0028163 <udiv64+0x53>
             <=> [b - 1/d] < b
         which is a tautology.

         Therefore, this code is correct and will not trap. */
      uint64_t b = 1ULL << 32;
      uint32_t n1 = n >> 32;
c002812c:	8b 44 24 04          	mov    0x4(%esp),%eax
      uint32_t n0 = n; 
      uint32_t d0 = d;

      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c0028130:	ba 00 00 00 00       	mov    $0x0,%edx
c0028135:	f7 f7                	div    %edi
c0028137:	89 c6                	mov    %eax,%esi
c0028139:	89 d3                	mov    %edx,%ebx
c002813b:	b9 00 00 00 00       	mov    $0x0,%ecx
c0028140:	8b 04 24             	mov    (%esp),%eax
c0028143:	ba 00 00 00 00       	mov    $0x0,%edx
c0028148:	01 c8                	add    %ecx,%eax
c002814a:	11 da                	adc    %ebx,%edx
  asm ("divl %4"
c002814c:	f7 f7                	div    %edi
      return divl (b * (n1 % d0) + n0, d0) + b * (n1 / d0); 
c002814e:	ba 00 00 00 00       	mov    $0x0,%edx
c0028153:	89 f7                	mov    %esi,%edi
c0028155:	be 00 00 00 00       	mov    $0x0,%esi
c002815a:	01 f0                	add    %esi,%eax
c002815c:	11 fa                	adc    %edi,%edx
c002815e:	e9 f2 00 00 00       	jmp    c0028255 <udiv64+0x145>
    }
  else 
    {
      /* Based on the algorithm and proof available from
         http://www.hackersdelight.org/revisions.pdf. */
      if (n < d)
c0028163:	3b 6c 24 04          	cmp    0x4(%esp),%ebp
c0028167:	0f 87 d4 00 00 00    	ja     c0028241 <udiv64+0x131>
c002816d:	72 09                	jb     c0028178 <udiv64+0x68>
c002816f:	3b 3c 24             	cmp    (%esp),%edi
c0028172:	0f 87 c9 00 00 00    	ja     c0028241 <udiv64+0x131>
        return 0;
      else 
        {
          uint32_t d1 = d >> 32;
c0028178:	89 d0                	mov    %edx,%eax
  int n = 0;
c002817a:	b9 00 00 00 00       	mov    $0x0,%ecx
  if (x <= 0x0000FFFF)
c002817f:	81 fa ff ff 00 00    	cmp    $0xffff,%edx
c0028185:	77 05                	ja     c002818c <udiv64+0x7c>
      x <<= 16; 
c0028187:	c1 e0 10             	shl    $0x10,%eax
      n += 16;
c002818a:	b1 10                	mov    $0x10,%cl
  if (x <= 0x00FFFFFF)
c002818c:	3d ff ff ff 00       	cmp    $0xffffff,%eax
c0028191:	77 06                	ja     c0028199 <udiv64+0x89>
      n += 8;
c0028193:	83 c1 08             	add    $0x8,%ecx
      x <<= 8; 
c0028196:	c1 e0 08             	shl    $0x8,%eax
  if (x <= 0x0FFFFFFF)
c0028199:	3d ff ff ff 0f       	cmp    $0xfffffff,%eax
c002819e:	77 06                	ja     c00281a6 <udiv64+0x96>
      n += 4;
c00281a0:	83 c1 04             	add    $0x4,%ecx
      x <<= 4;
c00281a3:	c1 e0 04             	shl    $0x4,%eax
  if (x <= 0x3FFFFFFF)
c00281a6:	3d ff ff ff 3f       	cmp    $0x3fffffff,%eax
c00281ab:	77 06                	ja     c00281b3 <udiv64+0xa3>
      n += 2;
c00281ad:	83 c1 02             	add    $0x2,%ecx
      x <<= 2; 
c00281b0:	c1 e0 02             	shl    $0x2,%eax
    n++;
c00281b3:	3d 00 00 00 80       	cmp    $0x80000000,%eax
c00281b8:	83 d1 00             	adc    $0x0,%ecx
          int s = nlz (d1);
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c00281bb:	8b 04 24             	mov    (%esp),%eax
c00281be:	8b 54 24 04          	mov    0x4(%esp),%edx
c00281c2:	0f ac d0 01          	shrd   $0x1,%edx,%eax
c00281c6:	d1 ea                	shr    %edx
c00281c8:	89 fb                	mov    %edi,%ebx
c00281ca:	89 ee                	mov    %ebp,%esi
c00281cc:	0f a5 fe             	shld   %cl,%edi,%esi
c00281cf:	d3 e3                	shl    %cl,%ebx
c00281d1:	f6 c1 20             	test   $0x20,%cl
c00281d4:	74 02                	je     c00281d8 <udiv64+0xc8>
c00281d6:	89 de                	mov    %ebx,%esi
c00281d8:	89 74 24 0c          	mov    %esi,0xc(%esp)
  asm ("divl %4"
c00281dc:	f7 74 24 0c          	divl   0xc(%esp)
c00281e0:	89 c6                	mov    %eax,%esi
          uint64_t q = divl (n >> 1, (d << s) >> 32) >> (31 - s);
c00281e2:	b8 1f 00 00 00       	mov    $0x1f,%eax
c00281e7:	29 c8                	sub    %ecx,%eax
c00281e9:	89 c1                	mov    %eax,%ecx
c00281eb:	d3 ee                	shr    %cl,%esi
c00281ed:	89 74 24 10          	mov    %esi,0x10(%esp)
c00281f1:	c7 44 24 14 00 00 00 	movl   $0x0,0x14(%esp)
c00281f8:	00 
          return n - (q - 1) * d < d ? q - 1 : q; 
c00281f9:	8b 44 24 10          	mov    0x10(%esp),%eax
c00281fd:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028201:	83 c0 ff             	add    $0xffffffff,%eax
c0028204:	83 d2 ff             	adc    $0xffffffff,%edx
c0028207:	89 44 24 08          	mov    %eax,0x8(%esp)
c002820b:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002820f:	89 c1                	mov    %eax,%ecx
c0028211:	0f af d7             	imul   %edi,%edx
c0028214:	0f af cd             	imul   %ebp,%ecx
c0028217:	8d 34 0a             	lea    (%edx,%ecx,1),%esi
c002821a:	8b 44 24 08          	mov    0x8(%esp),%eax
c002821e:	f7 e7                	mul    %edi
c0028220:	01 f2                	add    %esi,%edx
c0028222:	8b 1c 24             	mov    (%esp),%ebx
c0028225:	8b 74 24 04          	mov    0x4(%esp),%esi
c0028229:	29 c3                	sub    %eax,%ebx
c002822b:	19 d6                	sbb    %edx,%esi
c002822d:	39 f5                	cmp    %esi,%ebp
c002822f:	72 1c                	jb     c002824d <udiv64+0x13d>
c0028231:	77 04                	ja     c0028237 <udiv64+0x127>
c0028233:	39 df                	cmp    %ebx,%edi
c0028235:	76 16                	jbe    c002824d <udiv64+0x13d>
c0028237:	8b 44 24 08          	mov    0x8(%esp),%eax
c002823b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002823f:	eb 14                	jmp    c0028255 <udiv64+0x145>
        return 0;
c0028241:	b8 00 00 00 00       	mov    $0x0,%eax
c0028246:	ba 00 00 00 00       	mov    $0x0,%edx
c002824b:	eb 08                	jmp    c0028255 <udiv64+0x145>
          return n - (q - 1) * d < d ? q - 1 : q; 
c002824d:	8b 44 24 10          	mov    0x10(%esp),%eax
c0028251:	8b 54 24 14          	mov    0x14(%esp),%edx
        }
    }
}
c0028255:	83 c4 1c             	add    $0x1c,%esp
c0028258:	5b                   	pop    %ebx
c0028259:	5e                   	pop    %esi
c002825a:	5f                   	pop    %edi
c002825b:	5d                   	pop    %ebp
c002825c:	c3                   	ret    

c002825d <sdiv64>:

/* Divides signed 64-bit N by signed 64-bit D and returns the
   quotient. */
static int64_t
sdiv64 (int64_t n, int64_t d)
{
c002825d:	57                   	push   %edi
c002825e:	56                   	push   %esi
c002825f:	53                   	push   %ebx
c0028260:	83 ec 10             	sub    $0x10,%esp
c0028263:	89 44 24 08          	mov    %eax,0x8(%esp)
c0028267:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002826b:	8b 74 24 20          	mov    0x20(%esp),%esi
c002826f:	8b 7c 24 24          	mov    0x24(%esp),%edi
  uint64_t n_abs = n >= 0 ? (uint64_t) n : -(uint64_t) n;
c0028273:	85 d2                	test   %edx,%edx
c0028275:	79 0f                	jns    c0028286 <sdiv64+0x29>
c0028277:	8b 44 24 08          	mov    0x8(%esp),%eax
c002827b:	8b 54 24 0c          	mov    0xc(%esp),%edx
c002827f:	f7 d8                	neg    %eax
c0028281:	83 d2 00             	adc    $0x0,%edx
c0028284:	f7 da                	neg    %edx
  uint64_t d_abs = d >= 0 ? (uint64_t) d : -(uint64_t) d;
c0028286:	85 ff                	test   %edi,%edi
c0028288:	78 06                	js     c0028290 <sdiv64+0x33>
c002828a:	89 f1                	mov    %esi,%ecx
c002828c:	89 fb                	mov    %edi,%ebx
c002828e:	eb 0b                	jmp    c002829b <sdiv64+0x3e>
c0028290:	89 f1                	mov    %esi,%ecx
c0028292:	89 fb                	mov    %edi,%ebx
c0028294:	f7 d9                	neg    %ecx
c0028296:	83 d3 00             	adc    $0x0,%ebx
c0028299:	f7 db                	neg    %ebx
  uint64_t q_abs = udiv64 (n_abs, d_abs);
c002829b:	89 0c 24             	mov    %ecx,(%esp)
c002829e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00282a2:	e8 69 fe ff ff       	call   c0028110 <udiv64>
  return (n < 0) == (d < 0) ? (int64_t) q_abs : -(int64_t) q_abs;
c00282a7:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
c00282ab:	f7 d1                	not    %ecx
c00282ad:	c1 e9 1f             	shr    $0x1f,%ecx
c00282b0:	89 fb                	mov    %edi,%ebx
c00282b2:	c1 eb 1f             	shr    $0x1f,%ebx
c00282b5:	89 c6                	mov    %eax,%esi
c00282b7:	89 d7                	mov    %edx,%edi
c00282b9:	f7 de                	neg    %esi
c00282bb:	83 d7 00             	adc    $0x0,%edi
c00282be:	f7 df                	neg    %edi
c00282c0:	39 cb                	cmp    %ecx,%ebx
c00282c2:	74 04                	je     c00282c8 <sdiv64+0x6b>
c00282c4:	89 c6                	mov    %eax,%esi
c00282c6:	89 d7                	mov    %edx,%edi
}
c00282c8:	89 f0                	mov    %esi,%eax
c00282ca:	89 fa                	mov    %edi,%edx
c00282cc:	83 c4 10             	add    $0x10,%esp
c00282cf:	5b                   	pop    %ebx
c00282d0:	5e                   	pop    %esi
c00282d1:	5f                   	pop    %edi
c00282d2:	c3                   	ret    

c00282d3 <__divdi3>:
unsigned long long __umoddi3 (unsigned long long n, unsigned long long d);

/* Signed 64-bit division. */
long long
__divdi3 (long long n, long long d) 
{
c00282d3:	83 ec 0c             	sub    $0xc,%esp
  return sdiv64 (n, d);
c00282d6:	8b 44 24 18          	mov    0x18(%esp),%eax
c00282da:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c00282de:	89 04 24             	mov    %eax,(%esp)
c00282e1:	89 54 24 04          	mov    %edx,0x4(%esp)
c00282e5:	8b 44 24 10          	mov    0x10(%esp),%eax
c00282e9:	8b 54 24 14          	mov    0x14(%esp),%edx
c00282ed:	e8 6b ff ff ff       	call   c002825d <sdiv64>
}
c00282f2:	83 c4 0c             	add    $0xc,%esp
c00282f5:	c3                   	ret    

c00282f6 <__moddi3>:

/* Signed 64-bit remainder. */
long long
__moddi3 (long long n, long long d) 
{
c00282f6:	56                   	push   %esi
c00282f7:	53                   	push   %ebx
c00282f8:	83 ec 0c             	sub    $0xc,%esp
c00282fb:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c00282ff:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * sdiv64 (n, d);
c0028303:	89 34 24             	mov    %esi,(%esp)
c0028306:	8b 44 24 24          	mov    0x24(%esp),%eax
c002830a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002830e:	89 d8                	mov    %ebx,%eax
c0028310:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028314:	e8 44 ff ff ff       	call   c002825d <sdiv64>
c0028319:	0f af f0             	imul   %eax,%esi
c002831c:	89 d8                	mov    %ebx,%eax
c002831e:	29 f0                	sub    %esi,%eax
  return smod64 (n, d);
c0028320:	99                   	cltd   
}
c0028321:	83 c4 0c             	add    $0xc,%esp
c0028324:	5b                   	pop    %ebx
c0028325:	5e                   	pop    %esi
c0028326:	c3                   	ret    

c0028327 <__udivdi3>:

/* Unsigned 64-bit division. */
unsigned long long
__udivdi3 (unsigned long long n, unsigned long long d) 
{
c0028327:	83 ec 0c             	sub    $0xc,%esp
  return udiv64 (n, d);
c002832a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002832e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028332:	89 04 24             	mov    %eax,(%esp)
c0028335:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028339:	8b 44 24 10          	mov    0x10(%esp),%eax
c002833d:	8b 54 24 14          	mov    0x14(%esp),%edx
c0028341:	e8 ca fd ff ff       	call   c0028110 <udiv64>
}
c0028346:	83 c4 0c             	add    $0xc,%esp
c0028349:	c3                   	ret    

c002834a <__umoddi3>:

/* Unsigned 64-bit remainder. */
unsigned long long
__umoddi3 (unsigned long long n, unsigned long long d) 
{
c002834a:	56                   	push   %esi
c002834b:	53                   	push   %ebx
c002834c:	83 ec 0c             	sub    $0xc,%esp
c002834f:	8b 5c 24 18          	mov    0x18(%esp),%ebx
c0028353:	8b 74 24 20          	mov    0x20(%esp),%esi
  return n - d * udiv64 (n, d);
c0028357:	89 34 24             	mov    %esi,(%esp)
c002835a:	8b 44 24 24          	mov    0x24(%esp),%eax
c002835e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028362:	89 d8                	mov    %ebx,%eax
c0028364:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c0028368:	e8 a3 fd ff ff       	call   c0028110 <udiv64>
c002836d:	0f af f0             	imul   %eax,%esi
c0028370:	89 d8                	mov    %ebx,%eax
c0028372:	29 f0                	sub    %esi,%eax
  return umod64 (n, d);
c0028374:	ba 00 00 00 00       	mov    $0x0,%edx
}
c0028379:	83 c4 0c             	add    $0xc,%esp
c002837c:	5b                   	pop    %ebx
c002837d:	5e                   	pop    %esi
c002837e:	c3                   	ret    

c002837f <parse_octal_field>:
   seems ambiguous as to whether these fields must be padded on
   the left with '0's, so we accept any field that fits in the
   available space, regardless of whether it fills the space. */
static bool
parse_octal_field (const char *s, size_t size, unsigned long int *value)
{
c002837f:	55                   	push   %ebp
c0028380:	57                   	push   %edi
c0028381:	56                   	push   %esi
c0028382:	53                   	push   %ebx
c0028383:	83 ec 04             	sub    $0x4,%esp
c0028386:	89 04 24             	mov    %eax,(%esp)
c0028389:	89 d5                	mov    %edx,%ebp
  size_t ofs;

  *value = 0;
c002838b:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
          return false;
        }
    }

  /* Field did not end in space or null byte. */
  return false;
c0028391:	b8 00 00 00 00       	mov    $0x0,%eax
  for (ofs = 0; ofs < size; ofs++)
c0028396:	85 d2                	test   %edx,%edx
c0028398:	74 66                	je     c0028400 <parse_octal_field+0x81>
c002839a:	eb 45                	jmp    c00283e1 <parse_octal_field+0x62>
      char c = s[ofs];
c002839c:	8b 04 24             	mov    (%esp),%eax
c002839f:	0f b6 14 18          	movzbl (%eax,%ebx,1),%edx
      if (c >= '0' && c <= '7')
c00283a3:	8d 7a d0             	lea    -0x30(%edx),%edi
c00283a6:	89 f8                	mov    %edi,%eax
c00283a8:	3c 07                	cmp    $0x7,%al
c00283aa:	77 24                	ja     c00283d0 <parse_octal_field+0x51>
          if (*value > ULONG_MAX / 8)
c00283ac:	81 fe ff ff ff 1f    	cmp    $0x1fffffff,%esi
c00283b2:	77 47                	ja     c00283fb <parse_octal_field+0x7c>
          *value = c - '0' + *value * 8;
c00283b4:	0f be fa             	movsbl %dl,%edi
c00283b7:	8d 74 f7 d0          	lea    -0x30(%edi,%esi,8),%esi
c00283bb:	89 31                	mov    %esi,(%ecx)
  for (ofs = 0; ofs < size; ofs++)
c00283bd:	83 c3 01             	add    $0x1,%ebx
c00283c0:	39 eb                	cmp    %ebp,%ebx
c00283c2:	75 d8                	jne    c002839c <parse_octal_field+0x1d>
  return false;
c00283c4:	b8 00 00 00 00       	mov    $0x0,%eax
c00283c9:	eb 35                	jmp    c0028400 <parse_octal_field+0x81>
  for (ofs = 0; ofs < size; ofs++)
c00283cb:	bb 00 00 00 00       	mov    $0x0,%ebx
          return false;
c00283d0:	b8 00 00 00 00       	mov    $0x0,%eax
      else if (c == ' ' || c == '\0')
c00283d5:	f6 c2 df             	test   $0xdf,%dl
c00283d8:	75 26                	jne    c0028400 <parse_octal_field+0x81>
          return ofs > 0;
c00283da:	85 db                	test   %ebx,%ebx
c00283dc:	0f 95 c0             	setne  %al
c00283df:	eb 1f                	jmp    c0028400 <parse_octal_field+0x81>
      char c = s[ofs];
c00283e1:	8b 04 24             	mov    (%esp),%eax
c00283e4:	0f b6 10             	movzbl (%eax),%edx
      if (c >= '0' && c <= '7')
c00283e7:	8d 5a d0             	lea    -0x30(%edx),%ebx
c00283ea:	80 fb 07             	cmp    $0x7,%bl
c00283ed:	77 dc                	ja     c00283cb <parse_octal_field+0x4c>
          if (*value > ULONG_MAX / 8)
c00283ef:	be 00 00 00 00       	mov    $0x0,%esi
  for (ofs = 0; ofs < size; ofs++)
c00283f4:	bb 00 00 00 00       	mov    $0x0,%ebx
c00283f9:	eb b9                	jmp    c00283b4 <parse_octal_field+0x35>
              return false;
c00283fb:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028400:	83 c4 04             	add    $0x4,%esp
c0028403:	5b                   	pop    %ebx
c0028404:	5e                   	pop    %esi
c0028405:	5f                   	pop    %edi
c0028406:	5d                   	pop    %ebp
c0028407:	c3                   	ret    

c0028408 <strip_antisocial_prefixes>:
{
c0028408:	57                   	push   %edi
c0028409:	56                   	push   %esi
c002840a:	53                   	push   %ebx
c002840b:	83 ec 10             	sub    $0x10,%esp
c002840e:	89 c3                	mov    %eax,%ebx
  while (*file_name == '/'
c0028410:	eb 13                	jmp    c0028425 <strip_antisocial_prefixes+0x1d>
    file_name = strchr (file_name, '/') + 1;
c0028412:	c7 44 24 04 2f 00 00 	movl   $0x2f,0x4(%esp)
c0028419:	00 
c002841a:	89 1c 24             	mov    %ebx,(%esp)
c002841d:	e8 84 f7 ff ff       	call   c0027ba6 <strchr>
c0028422:	8d 58 01             	lea    0x1(%eax),%ebx
  while (*file_name == '/'
c0028425:	0f b6 33             	movzbl (%ebx),%esi
c0028428:	89 f0                	mov    %esi,%eax
c002842a:	3c 2f                	cmp    $0x2f,%al
c002842c:	74 e4                	je     c0028412 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "./", 2)
c002842e:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
c0028435:	00 
c0028436:	c7 44 24 04 e5 ed 02 	movl   $0xc002ede5,0x4(%esp)
c002843d:	c0 
c002843e:	89 1c 24             	mov    %ebx,(%esp)
c0028441:	e8 77 f5 ff ff       	call   c00279bd <memcmp>
c0028446:	85 c0                	test   %eax,%eax
c0028448:	74 c8                	je     c0028412 <strip_antisocial_prefixes+0xa>
         || !memcmp (file_name, "../", 3))
c002844a:	c7 44 24 08 03 00 00 	movl   $0x3,0x8(%esp)
c0028451:	00 
c0028452:	c7 44 24 04 4d fa 02 	movl   $0xc002fa4d,0x4(%esp)
c0028459:	c0 
c002845a:	89 1c 24             	mov    %ebx,(%esp)
c002845d:	e8 5b f5 ff ff       	call   c00279bd <memcmp>
c0028462:	85 c0                	test   %eax,%eax
c0028464:	74 ac                	je     c0028412 <strip_antisocial_prefixes+0xa>
  return *file_name == '\0' || !strcmp (file_name, "..") ? "." : file_name;
c0028466:	b8 6b f3 02 c0       	mov    $0xc002f36b,%eax
c002846b:	89 f2                	mov    %esi,%edx
c002846d:	84 d2                	test   %dl,%dl
c002846f:	74 23                	je     c0028494 <strip_antisocial_prefixes+0x8c>
c0028471:	bf 6a f3 02 c0       	mov    $0xc002f36a,%edi
c0028476:	b9 03 00 00 00       	mov    $0x3,%ecx
c002847b:	89 de                	mov    %ebx,%esi
c002847d:	f3 a6                	repz cmpsb %es:(%edi),%ds:(%esi)
c002847f:	0f 97 c0             	seta   %al
c0028482:	0f 92 c2             	setb   %dl
c0028485:	29 d0                	sub    %edx,%eax
c0028487:	0f be c0             	movsbl %al,%eax
c002848a:	85 c0                	test   %eax,%eax
c002848c:	b8 6b f3 02 c0       	mov    $0xc002f36b,%eax
c0028491:	0f 45 c3             	cmovne %ebx,%eax
}
c0028494:	83 c4 10             	add    $0x10,%esp
c0028497:	5b                   	pop    %ebx
c0028498:	5e                   	pop    %esi
c0028499:	5f                   	pop    %edi
c002849a:	c3                   	ret    

c002849b <ustar_make_header>:
{
c002849b:	55                   	push   %ebp
c002849c:	57                   	push   %edi
c002849d:	56                   	push   %esi
c002849e:	53                   	push   %ebx
c002849f:	83 ec 2c             	sub    $0x2c,%esp
c00284a2:	8b 5c 24 4c          	mov    0x4c(%esp),%ebx
  ASSERT (type == USTAR_REGULAR || type == USTAR_DIRECTORY);
c00284a6:	83 7c 24 44 30       	cmpl   $0x30,0x44(%esp)
c00284ab:	0f 94 c0             	sete   %al
c00284ae:	89 c6                	mov    %eax,%esi
c00284b0:	88 44 24 1f          	mov    %al,0x1f(%esp)
c00284b4:	83 7c 24 44 35       	cmpl   $0x35,0x44(%esp)
c00284b9:	0f 94 c0             	sete   %al
c00284bc:	89 f2                	mov    %esi,%edx
c00284be:	08 d0                	or     %dl,%al
c00284c0:	75 2c                	jne    c00284ee <ustar_make_header+0x53>
c00284c2:	c7 44 24 10 38 fb 02 	movl   $0xc002fb38,0x10(%esp)
c00284c9:	c0 
c00284ca:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00284d1:	c0 
c00284d2:	c7 44 24 08 80 dc 02 	movl   $0xc002dc80,0x8(%esp)
c00284d9:	c0 
c00284da:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
c00284e1:	00 
c00284e2:	c7 04 24 51 fa 02 c0 	movl   $0xc002fa51,(%esp)
c00284e9:	e8 85 04 00 00       	call   c0028973 <debug_panic>
c00284ee:	89 c5                	mov    %eax,%ebp
  file_name = strip_antisocial_prefixes (file_name);
c00284f0:	8b 44 24 40          	mov    0x40(%esp),%eax
c00284f4:	e8 0f ff ff ff       	call   c0028408 <strip_antisocial_prefixes>
c00284f9:	89 c2                	mov    %eax,%edx
  if (strlen (file_name) > 99)
c00284fb:	89 c7                	mov    %eax,%edi
c00284fd:	b8 00 00 00 00       	mov    $0x0,%eax
c0028502:	b9 ff ff ff ff       	mov    $0xffffffff,%ecx
c0028507:	f2 ae                	repnz scas %es:(%edi),%al
c0028509:	f7 d1                	not    %ecx
c002850b:	83 e9 01             	sub    $0x1,%ecx
c002850e:	83 f9 63             	cmp    $0x63,%ecx
c0028511:	76 1a                	jbe    c002852d <ustar_make_header+0x92>
      printf ("%s: file name too long\n", file_name);
c0028513:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028517:	c7 04 24 63 fa 02 c0 	movl   $0xc002fa63,(%esp)
c002851e:	e8 fb e5 ff ff       	call   c0026b1e <printf>
      return false;
c0028523:	bd 00 00 00 00       	mov    $0x0,%ebp
c0028528:	e9 d0 01 00 00       	jmp    c00286fd <ustar_make_header+0x262>
  memset (h, 0, sizeof *h);
c002852d:	89 df                	mov    %ebx,%edi
c002852f:	be 00 02 00 00       	mov    $0x200,%esi
c0028534:	f6 c3 01             	test   $0x1,%bl
c0028537:	74 0a                	je     c0028543 <ustar_make_header+0xa8>
c0028539:	c6 03 00             	movb   $0x0,(%ebx)
c002853c:	8d 7b 01             	lea    0x1(%ebx),%edi
c002853f:	66 be ff 01          	mov    $0x1ff,%si
c0028543:	f7 c7 02 00 00 00    	test   $0x2,%edi
c0028549:	74 0b                	je     c0028556 <ustar_make_header+0xbb>
c002854b:	66 c7 07 00 00       	movw   $0x0,(%edi)
c0028550:	83 c7 02             	add    $0x2,%edi
c0028553:	83 ee 02             	sub    $0x2,%esi
c0028556:	89 f1                	mov    %esi,%ecx
c0028558:	c1 e9 02             	shr    $0x2,%ecx
c002855b:	b8 00 00 00 00       	mov    $0x0,%eax
c0028560:	f3 ab                	rep stos %eax,%es:(%edi)
c0028562:	f7 c6 02 00 00 00    	test   $0x2,%esi
c0028568:	74 08                	je     c0028572 <ustar_make_header+0xd7>
c002856a:	66 c7 07 00 00       	movw   $0x0,(%edi)
c002856f:	83 c7 02             	add    $0x2,%edi
c0028572:	f7 c6 01 00 00 00    	test   $0x1,%esi
c0028578:	74 03                	je     c002857d <ustar_make_header+0xe2>
c002857a:	c6 07 00             	movb   $0x0,(%edi)
  strlcpy (h->name, file_name, sizeof h->name);
c002857d:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c0028584:	00 
c0028585:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028589:	89 1c 24             	mov    %ebx,(%esp)
c002858c:	e8 f5 f9 ff ff       	call   c0027f86 <strlcpy>
  snprintf (h->mode, sizeof h->mode, "%07o",
c0028591:	80 7c 24 1f 01       	cmpb   $0x1,0x1f(%esp)
c0028596:	19 c0                	sbb    %eax,%eax
c0028598:	83 e0 49             	and    $0x49,%eax
c002859b:	05 a4 01 00 00       	add    $0x1a4,%eax
c00285a0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00285a4:	c7 44 24 08 7b fa 02 	movl   $0xc002fa7b,0x8(%esp)
c00285ab:	c0 
c00285ac:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c00285b3:	00 
c00285b4:	8d 43 64             	lea    0x64(%ebx),%eax
c00285b7:	89 04 24             	mov    %eax,(%esp)
c00285ba:	e8 60 ec ff ff       	call   c002721f <snprintf>
  strlcpy (h->uid, "0000000", sizeof h->uid);
c00285bf:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c00285c6:	00 
c00285c7:	c7 44 24 04 80 fa 02 	movl   $0xc002fa80,0x4(%esp)
c00285ce:	c0 
c00285cf:	8d 43 6c             	lea    0x6c(%ebx),%eax
c00285d2:	89 04 24             	mov    %eax,(%esp)
c00285d5:	e8 ac f9 ff ff       	call   c0027f86 <strlcpy>
  strlcpy (h->gid, "0000000", sizeof h->gid);
c00285da:	c7 44 24 08 08 00 00 	movl   $0x8,0x8(%esp)
c00285e1:	00 
c00285e2:	c7 44 24 04 80 fa 02 	movl   $0xc002fa80,0x4(%esp)
c00285e9:	c0 
c00285ea:	8d 43 74             	lea    0x74(%ebx),%eax
c00285ed:	89 04 24             	mov    %eax,(%esp)
c00285f0:	e8 91 f9 ff ff       	call   c0027f86 <strlcpy>
  snprintf (h->size, sizeof h->size, "%011o", size);
c00285f5:	8b 44 24 48          	mov    0x48(%esp),%eax
c00285f9:	89 44 24 0c          	mov    %eax,0xc(%esp)
c00285fd:	c7 44 24 08 88 fa 02 	movl   $0xc002fa88,0x8(%esp)
c0028604:	c0 
c0028605:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002860c:	00 
c002860d:	8d 43 7c             	lea    0x7c(%ebx),%eax
c0028610:	89 04 24             	mov    %eax,(%esp)
c0028613:	e8 07 ec ff ff       	call   c002721f <snprintf>
  snprintf (h->mtime, sizeof h->size, "%011o", 1136102400);
c0028618:	c7 44 24 0c 00 8c b7 	movl   $0x43b78c00,0xc(%esp)
c002861f:	43 
c0028620:	c7 44 24 08 88 fa 02 	movl   $0xc002fa88,0x8(%esp)
c0028627:	c0 
c0028628:	c7 44 24 04 0c 00 00 	movl   $0xc,0x4(%esp)
c002862f:	00 
c0028630:	8d 83 88 00 00 00    	lea    0x88(%ebx),%eax
c0028636:	89 04 24             	mov    %eax,(%esp)
c0028639:	e8 e1 eb ff ff       	call   c002721f <snprintf>
  h->typeflag = type;
c002863e:	0f b6 44 24 44       	movzbl 0x44(%esp),%eax
c0028643:	88 83 9c 00 00 00    	mov    %al,0x9c(%ebx)
  strlcpy (h->magic, "ustar", sizeof h->magic);
c0028649:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028650:	00 
c0028651:	c7 44 24 04 8e fa 02 	movl   $0xc002fa8e,0x4(%esp)
c0028658:	c0 
c0028659:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002865f:	89 04 24             	mov    %eax,(%esp)
c0028662:	e8 1f f9 ff ff       	call   c0027f86 <strlcpy>
  h->version[0] = h->version[1] = '0';
c0028667:	c6 83 08 01 00 00 30 	movb   $0x30,0x108(%ebx)
c002866e:	c6 83 07 01 00 00 30 	movb   $0x30,0x107(%ebx)
  strlcpy (h->gname, "root", sizeof h->gname);
c0028675:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c002867c:	00 
c002867d:	c7 44 24 04 9c ef 02 	movl   $0xc002ef9c,0x4(%esp)
c0028684:	c0 
c0028685:	8d 83 29 01 00 00    	lea    0x129(%ebx),%eax
c002868b:	89 04 24             	mov    %eax,(%esp)
c002868e:	e8 f3 f8 ff ff       	call   c0027f86 <strlcpy>
  strlcpy (h->uname, "root", sizeof h->uname);
c0028693:	c7 44 24 08 20 00 00 	movl   $0x20,0x8(%esp)
c002869a:	00 
c002869b:	c7 44 24 04 9c ef 02 	movl   $0xc002ef9c,0x4(%esp)
c00286a2:	c0 
c00286a3:	8d 83 09 01 00 00    	lea    0x109(%ebx),%eax
c00286a9:	89 04 24             	mov    %eax,(%esp)
c00286ac:	e8 d5 f8 ff ff       	call   c0027f86 <strlcpy>
c00286b1:	b8 6c ff ff ff       	mov    $0xffffff6c,%eax
  chksum = 0;
c00286b6:	ba 00 00 00 00       	mov    $0x0,%edx
      chksum += in_chksum_field ? ' ' : header[i];
c00286bb:	83 f8 07             	cmp    $0x7,%eax
c00286be:	76 0a                	jbe    c00286ca <ustar_make_header+0x22f>
c00286c0:	0f b6 8c 03 94 00 00 	movzbl 0x94(%ebx,%eax,1),%ecx
c00286c7:	00 
c00286c8:	eb 05                	jmp    c00286cf <ustar_make_header+0x234>
c00286ca:	b9 20 00 00 00       	mov    $0x20,%ecx
c00286cf:	01 ca                	add    %ecx,%edx
c00286d1:	83 c0 01             	add    $0x1,%eax
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c00286d4:	3d 6c 01 00 00       	cmp    $0x16c,%eax
c00286d9:	75 e0                	jne    c00286bb <ustar_make_header+0x220>
  snprintf (h->chksum, sizeof h->chksum, "%07o", calculate_chksum (h));
c00286db:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00286df:	c7 44 24 08 7b fa 02 	movl   $0xc002fa7b,0x8(%esp)
c00286e6:	c0 
c00286e7:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
c00286ee:	00 
c00286ef:	81 c3 94 00 00 00    	add    $0x94,%ebx
c00286f5:	89 1c 24             	mov    %ebx,(%esp)
c00286f8:	e8 22 eb ff ff       	call   c002721f <snprintf>
}
c00286fd:	89 e8                	mov    %ebp,%eax
c00286ff:	83 c4 2c             	add    $0x2c,%esp
c0028702:	5b                   	pop    %ebx
c0028703:	5e                   	pop    %esi
c0028704:	5f                   	pop    %edi
c0028705:	5d                   	pop    %ebp
c0028706:	c3                   	ret    

c0028707 <ustar_parse_header>:
   and returns a null pointer.  On failure, returns a
   human-readable error message. */
const char *
ustar_parse_header (const char header[USTAR_HEADER_SIZE],
                    const char **file_name, enum ustar_type *type, int *size)
{
c0028707:	53                   	push   %ebx
c0028708:	83 ec 28             	sub    $0x28,%esp
c002870b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002870f:	8d 8b 00 02 00 00    	lea    0x200(%ebx),%ecx
c0028715:	89 da                	mov    %ebx,%edx
    if (*block++ != 0)
c0028717:	83 c2 01             	add    $0x1,%edx
c002871a:	80 7a ff 00          	cmpb   $0x0,-0x1(%edx)
c002871e:	0f 85 25 01 00 00    	jne    c0028849 <ustar_parse_header+0x142>
  while (cnt-- > 0)
c0028724:	39 ca                	cmp    %ecx,%edx
c0028726:	75 ef                	jne    c0028717 <ustar_parse_header+0x10>
c0028728:	e9 4b 01 00 00       	jmp    c0028878 <ustar_parse_header+0x171>

  /* Validate ustar header. */
  if (memcmp (h->magic, "ustar", 6))
    return "not a ustar archive";
  else if (h->version[0] != '0' || h->version[1] != '0')
    return "invalid ustar version";
c002872d:	b8 a8 fa 02 c0       	mov    $0xc002faa8,%eax
  else if (h->version[0] != '0' || h->version[1] != '0')
c0028732:	80 bb 07 01 00 00 30 	cmpb   $0x30,0x107(%ebx)
c0028739:	0f 85 5c 01 00 00    	jne    c002889b <ustar_parse_header+0x194>
c002873f:	80 bb 08 01 00 00 30 	cmpb   $0x30,0x108(%ebx)
c0028746:	0f 85 4f 01 00 00    	jne    c002889b <ustar_parse_header+0x194>
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c002874c:	8d 83 94 00 00 00    	lea    0x94(%ebx),%eax
c0028752:	8d 4c 24 1c          	lea    0x1c(%esp),%ecx
c0028756:	ba 08 00 00 00       	mov    $0x8,%edx
c002875b:	e8 1f fc ff ff       	call   c002837f <parse_octal_field>
c0028760:	89 c2                	mov    %eax,%edx
    return "corrupt chksum field";
c0028762:	b8 be fa 02 c0       	mov    $0xc002fabe,%eax
  else if (!parse_octal_field (h->chksum, sizeof h->chksum, &chksum))
c0028767:	84 d2                	test   %dl,%dl
c0028769:	0f 84 2c 01 00 00    	je     c002889b <ustar_parse_header+0x194>
c002876f:	ba 6c ff ff ff       	mov    $0xffffff6c,%edx
c0028774:	b9 00 00 00 00       	mov    $0x0,%ecx
      chksum += in_chksum_field ? ' ' : header[i];
c0028779:	83 fa 07             	cmp    $0x7,%edx
c002877c:	76 0a                	jbe    c0028788 <ustar_parse_header+0x81>
c002877e:	0f b6 84 13 94 00 00 	movzbl 0x94(%ebx,%edx,1),%eax
c0028785:	00 
c0028786:	eb 05                	jmp    c002878d <ustar_parse_header+0x86>
c0028788:	b8 20 00 00 00       	mov    $0x20,%eax
c002878d:	01 c1                	add    %eax,%ecx
c002878f:	83 c2 01             	add    $0x1,%edx
  for (i = 0; i < USTAR_HEADER_SIZE; i++)
c0028792:	81 fa 6c 01 00 00    	cmp    $0x16c,%edx
c0028798:	75 df                	jne    c0028779 <ustar_parse_header+0x72>
  else if (chksum != calculate_chksum (h))
    return "checksum mismatch";
c002879a:	b8 d3 fa 02 c0       	mov    $0xc002fad3,%eax
  else if (chksum != calculate_chksum (h))
c002879f:	39 4c 24 1c          	cmp    %ecx,0x1c(%esp)
c00287a3:	0f 85 f2 00 00 00    	jne    c002889b <ustar_parse_header+0x194>
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
    return "file name too long";
c00287a9:	b8 e5 fa 02 c0       	mov    $0xc002fae5,%eax
  else if (h->name[sizeof h->name - 1] != '\0' || h->prefix[0] != '\0')
c00287ae:	80 7b 63 00          	cmpb   $0x0,0x63(%ebx)
c00287b2:	0f 85 e3 00 00 00    	jne    c002889b <ustar_parse_header+0x194>
c00287b8:	80 bb 59 01 00 00 00 	cmpb   $0x0,0x159(%ebx)
c00287bf:	0f 85 d6 00 00 00    	jne    c002889b <ustar_parse_header+0x194>
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c00287c5:	0f b6 93 9c 00 00 00 	movzbl 0x9c(%ebx),%edx
c00287cc:	80 fa 35             	cmp    $0x35,%dl
c00287cf:	74 0e                	je     c00287df <ustar_parse_header+0xd8>
    return "unimplemented file type";
c00287d1:	b8 f8 fa 02 c0       	mov    $0xc002faf8,%eax
  else if (h->typeflag != USTAR_REGULAR && h->typeflag != USTAR_DIRECTORY)
c00287d6:	80 fa 30             	cmp    $0x30,%dl
c00287d9:	0f 85 bc 00 00 00    	jne    c002889b <ustar_parse_header+0x194>
  if (h->typeflag == USTAR_REGULAR)
c00287df:	80 fa 30             	cmp    $0x30,%dl
c00287e2:	75 32                	jne    c0028816 <ustar_parse_header+0x10f>
    {
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c00287e4:	8d 43 7c             	lea    0x7c(%ebx),%eax
c00287e7:	8d 4c 24 18          	lea    0x18(%esp),%ecx
c00287eb:	ba 0c 00 00 00       	mov    $0xc,%edx
c00287f0:	e8 8a fb ff ff       	call   c002837f <parse_octal_field>
c00287f5:	89 c2                	mov    %eax,%edx
        return "corrupt file size field";
c00287f7:	b8 10 fb 02 c0       	mov    $0xc002fb10,%eax
      if (!parse_octal_field (h->size, sizeof h->size, &size_ul))
c00287fc:	84 d2                	test   %dl,%dl
c00287fe:	0f 84 97 00 00 00    	je     c002889b <ustar_parse_header+0x194>
      else if (size_ul > INT_MAX)
        return "file too large";
c0028804:	b8 28 fb 02 c0       	mov    $0xc002fb28,%eax
      else if (size_ul > INT_MAX)
c0028809:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c002880e:	0f 88 87 00 00 00    	js     c002889b <ustar_parse_header+0x194>
c0028814:	eb 08                	jmp    c002881e <ustar_parse_header+0x117>
    }
  else
    size_ul = 0;
c0028816:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%esp)
c002881d:	00 

  /* Success. */
  *file_name = strip_antisocial_prefixes (h->name);
c002881e:	89 d8                	mov    %ebx,%eax
c0028820:	e8 e3 fb ff ff       	call   c0028408 <strip_antisocial_prefixes>
c0028825:	8b 4c 24 34          	mov    0x34(%esp),%ecx
c0028829:	89 01                	mov    %eax,(%ecx)
  *type = h->typeflag;
c002882b:	0f be 83 9c 00 00 00 	movsbl 0x9c(%ebx),%eax
c0028832:	8b 5c 24 38          	mov    0x38(%esp),%ebx
c0028836:	89 03                	mov    %eax,(%ebx)
  *size = size_ul;
c0028838:	8b 44 24 18          	mov    0x18(%esp),%eax
c002883c:	8b 5c 24 3c          	mov    0x3c(%esp),%ebx
c0028840:	89 03                	mov    %eax,(%ebx)
  return NULL;
c0028842:	b8 00 00 00 00       	mov    $0x0,%eax
c0028847:	eb 52                	jmp    c002889b <ustar_parse_header+0x194>
  if (memcmp (h->magic, "ustar", 6))
c0028849:	c7 44 24 08 06 00 00 	movl   $0x6,0x8(%esp)
c0028850:	00 
c0028851:	c7 44 24 04 8e fa 02 	movl   $0xc002fa8e,0x4(%esp)
c0028858:	c0 
c0028859:	8d 83 01 01 00 00    	lea    0x101(%ebx),%eax
c002885f:	89 04 24             	mov    %eax,(%esp)
c0028862:	e8 56 f1 ff ff       	call   c00279bd <memcmp>
c0028867:	89 c2                	mov    %eax,%edx
    return "not a ustar archive";
c0028869:	b8 94 fa 02 c0       	mov    $0xc002fa94,%eax
  if (memcmp (h->magic, "ustar", 6))
c002886e:	85 d2                	test   %edx,%edx
c0028870:	0f 84 b7 fe ff ff    	je     c002872d <ustar_parse_header+0x26>
c0028876:	eb 23                	jmp    c002889b <ustar_parse_header+0x194>
      *file_name = NULL;
c0028878:	8b 44 24 34          	mov    0x34(%esp),%eax
c002887c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      *type = USTAR_EOF;
c0028882:	8b 44 24 38          	mov    0x38(%esp),%eax
c0028886:	c7 00 ff ff ff ff    	movl   $0xffffffff,(%eax)
      *size = 0;
c002888c:	8b 44 24 3c          	mov    0x3c(%esp),%eax
c0028890:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
      return NULL;
c0028896:	b8 00 00 00 00       	mov    $0x0,%eax
}
c002889b:	83 c4 28             	add    $0x28,%esp
c002889e:	5b                   	pop    %ebx
c002889f:	c3                   	ret    

c00288a0 <print_stacktrace>:

/* Print call stack of a thread.
   The thread may be running, ready, or blocked. */
static void
print_stacktrace(struct thread *t, void *aux UNUSED)
{
c00288a0:	55                   	push   %ebp
c00288a1:	89 e5                	mov    %esp,%ebp
c00288a3:	53                   	push   %ebx
c00288a4:	83 ec 14             	sub    $0x14,%esp
c00288a7:	8b 5d 08             	mov    0x8(%ebp),%ebx
  void *retaddr = NULL, **frame = NULL;
  const char *status = "UNKNOWN";

  switch (t->status) {
c00288aa:	8b 43 04             	mov    0x4(%ebx),%eax
    case THREAD_RUNNING:  
      status = "RUNNING";
      break;

    case THREAD_READY:  
      status = "READY";
c00288ad:	ba 69 fb 02 c0       	mov    $0xc002fb69,%edx
  switch (t->status) {
c00288b2:	83 f8 01             	cmp    $0x1,%eax
c00288b5:	74 1a                	je     c00288d1 <print_stacktrace+0x31>
      status = "RUNNING";
c00288b7:	ba 89 e5 02 c0       	mov    $0xc002e589,%edx
  switch (t->status) {
c00288bc:	83 f8 01             	cmp    $0x1,%eax
c00288bf:	72 10                	jb     c00288d1 <print_stacktrace+0x31>
c00288c1:	83 f8 02             	cmp    $0x2,%eax
  const char *status = "UNKNOWN";
c00288c4:	b8 6f fb 02 c0       	mov    $0xc002fb6f,%eax
c00288c9:	ba 43 e5 02 c0       	mov    $0xc002e543,%edx
c00288ce:	0f 45 d0             	cmovne %eax,%edx

    default:
      break;
  }

  printf ("Call stack of thread `%s' (status %s):", t->name, status);
c00288d1:	89 54 24 08          	mov    %edx,0x8(%esp)
c00288d5:	8d 43 08             	lea    0x8(%ebx),%eax
c00288d8:	89 44 24 04          	mov    %eax,0x4(%esp)
c00288dc:	c7 04 24 94 fb 02 c0 	movl   $0xc002fb94,(%esp)
c00288e3:	e8 36 e2 ff ff       	call   c0026b1e <printf>

  if (t == thread_current()) 
c00288e8:	e8 b6 83 ff ff       	call   c0020ca3 <thread_current>
c00288ed:	39 d8                	cmp    %ebx,%eax
c00288ef:	75 08                	jne    c00288f9 <print_stacktrace+0x59>
    {
      frame = __builtin_frame_address (1);
c00288f1:	8b 5d 00             	mov    0x0(%ebp),%ebx
      retaddr = __builtin_return_address (0);
c00288f4:	8b 55 04             	mov    0x4(%ebp),%edx
c00288f7:	eb 29                	jmp    c0028922 <print_stacktrace+0x82>
    {
      /* Retrieve the values of the base and instruction pointers
         as they were saved when this thread called switch_threads. */
      struct switch_threads_frame * saved_frame;

      saved_frame = (struct switch_threads_frame *)t->stack;
c00288f9:	8b 43 18             	mov    0x18(%ebx),%eax
         list, but have never been scheduled.
         We can identify because their `stack' member either points 
         at the top of their kernel stack page, or the 
         switch_threads_frame's 'eip' member points at switch_entry.
         See also threads.c. */
      if (t->stack == (uint8_t *)t + PGSIZE || saved_frame->eip == switch_entry)
c00288fc:	81 c3 00 10 00 00    	add    $0x1000,%ebx
c0028902:	39 d8                	cmp    %ebx,%eax
c0028904:	74 0b                	je     c0028911 <print_stacktrace+0x71>
c0028906:	8b 50 10             	mov    0x10(%eax),%edx
c0028909:	81 fa a2 16 02 c0    	cmp    $0xc00216a2,%edx
c002890f:	75 0e                	jne    c002891f <print_stacktrace+0x7f>
        {
          printf (" thread was never scheduled.\n");
c0028911:	c7 04 24 77 fb 02 c0 	movl   $0xc002fb77,(%esp)
c0028918:	e8 7e 1d 00 00       	call   c002a69b <puts>
          return;
c002891d:	eb 4e                	jmp    c002896d <print_stacktrace+0xcd>
        }

      frame = (void **) saved_frame->ebp;
c002891f:	8b 58 08             	mov    0x8(%eax),%ebx
      retaddr = (void *) saved_frame->eip;
    }

  printf (" %p", retaddr);
c0028922:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028926:	c7 04 24 d4 f7 02 c0 	movl   $0xc002f7d4,(%esp)
c002892d:	e8 ec e1 ff ff       	call   c0026b1e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028932:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c0028938:	76 27                	jbe    c0028961 <print_stacktrace+0xc1>
c002893a:	83 3b 00             	cmpl   $0x0,(%ebx)
c002893d:	74 22                	je     c0028961 <print_stacktrace+0xc1>
    printf (" %p", frame[1]);
c002893f:	8b 43 04             	mov    0x4(%ebx),%eax
c0028942:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028946:	c7 04 24 d4 f7 02 c0 	movl   $0xc002f7d4,(%esp)
c002894d:	e8 cc e1 ff ff       	call   c0026b1e <printf>
  for (; (uintptr_t) frame >= 0x1000 && frame[0] != NULL; frame = frame[0])
c0028952:	8b 1b                	mov    (%ebx),%ebx
c0028954:	81 fb ff 0f 00 00    	cmp    $0xfff,%ebx
c002895a:	76 05                	jbe    c0028961 <print_stacktrace+0xc1>
c002895c:	83 3b 00             	cmpl   $0x0,(%ebx)
c002895f:	75 de                	jne    c002893f <print_stacktrace+0x9f>
  printf (".\n");
c0028961:	c7 04 24 6b f3 02 c0 	movl   $0xc002f36b,(%esp)
c0028968:	e8 2e 1d 00 00       	call   c002a69b <puts>
}
c002896d:	83 c4 14             	add    $0x14,%esp
c0028970:	5b                   	pop    %ebx
c0028971:	5d                   	pop    %ebp
c0028972:	c3                   	ret    

c0028973 <debug_panic>:
{
c0028973:	57                   	push   %edi
c0028974:	56                   	push   %esi
c0028975:	53                   	push   %ebx
c0028976:	83 ec 10             	sub    $0x10,%esp
c0028979:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002897d:	8b 74 24 24          	mov    0x24(%esp),%esi
c0028981:	8b 7c 24 28          	mov    0x28(%esp),%edi
  intr_disable ();
c0028985:	e8 c5 8e ff ff       	call   c002184f <intr_disable>
  console_panic ();
c002898a:	e8 9d 1c 00 00       	call   c002a62c <console_panic>
  level++;
c002898f:	a1 c0 7a 03 c0       	mov    0xc0037ac0,%eax
c0028994:	83 c0 01             	add    $0x1,%eax
c0028997:	a3 c0 7a 03 c0       	mov    %eax,0xc0037ac0
  if (level == 1) 
c002899c:	83 f8 01             	cmp    $0x1,%eax
c002899f:	75 3f                	jne    c00289e0 <debug_panic+0x6d>
      printf ("Kernel PANIC at %s:%d in %s(): ", file, line, function);
c00289a1:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00289a5:	89 74 24 08          	mov    %esi,0x8(%esp)
c00289a9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00289ad:	c7 04 24 bc fb 02 c0 	movl   $0xc002fbbc,(%esp)
c00289b4:	e8 65 e1 ff ff       	call   c0026b1e <printf>
      va_start (args, message);
c00289b9:	8d 44 24 30          	lea    0x30(%esp),%eax
      vprintf (message, args);
c00289bd:	89 44 24 04          	mov    %eax,0x4(%esp)
c00289c1:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c00289c5:	89 04 24             	mov    %eax,(%esp)
c00289c8:	e8 8d 1c 00 00       	call   c002a65a <vprintf>
      printf ("\n");
c00289cd:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c00289d4:	e8 33 1d 00 00       	call   c002a70c <putchar>
      debug_backtrace ();
c00289d9:	e8 73 db ff ff       	call   c0026551 <debug_backtrace>
c00289de:	eb 1d                	jmp    c00289fd <debug_panic+0x8a>
  else if (level == 2)
c00289e0:	83 f8 02             	cmp    $0x2,%eax
c00289e3:	75 18                	jne    c00289fd <debug_panic+0x8a>
    printf ("Kernel PANIC recursion at %s:%d in %s().\n",
c00289e5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c00289e9:	89 74 24 08          	mov    %esi,0x8(%esp)
c00289ed:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00289f1:	c7 04 24 dc fb 02 c0 	movl   $0xc002fbdc,(%esp)
c00289f8:	e8 21 e1 ff ff       	call   c0026b1e <printf>
  serial_flush ();
c00289fd:	e8 8a c1 ff ff       	call   c0024b8c <serial_flush>
  shutdown ();
c0028a02:	e8 79 da ff ff       	call   c0026480 <shutdown>
c0028a07:	eb fe                	jmp    c0028a07 <debug_panic+0x94>

c0028a09 <debug_backtrace_all>:

/* Prints call stack of all threads. */
void
debug_backtrace_all (void)
{
c0028a09:	53                   	push   %ebx
c0028a0a:	83 ec 18             	sub    $0x18,%esp
  enum intr_level oldlevel = intr_disable ();
c0028a0d:	e8 3d 8e ff ff       	call   c002184f <intr_disable>
c0028a12:	89 c3                	mov    %eax,%ebx

  thread_foreach (print_stacktrace, 0);
c0028a14:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0028a1b:	00 
c0028a1c:	c7 04 24 a0 88 02 c0 	movl   $0xc00288a0,(%esp)
c0028a23:	e8 5c 83 ff ff       	call   c0020d84 <thread_foreach>
  intr_set_level (oldlevel);
c0028a28:	89 1c 24             	mov    %ebx,(%esp)
c0028a2b:	e8 26 8e ff ff       	call   c0021856 <intr_set_level>
}
c0028a30:	83 c4 18             	add    $0x18,%esp
c0028a33:	5b                   	pop    %ebx
c0028a34:	c3                   	ret    
c0028a35:	90                   	nop
c0028a36:	90                   	nop
c0028a37:	90                   	nop
c0028a38:	90                   	nop
c0028a39:	90                   	nop
c0028a3a:	90                   	nop
c0028a3b:	90                   	nop
c0028a3c:	90                   	nop
c0028a3d:	90                   	nop
c0028a3e:	90                   	nop
c0028a3f:	90                   	nop

c0028a40 <list_init>:
}

/* Initializes LIST as an empty list. */
void
list_init (struct list *list)
{
c0028a40:	83 ec 2c             	sub    $0x2c,%esp
c0028a43:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028a47:	85 c0                	test   %eax,%eax
c0028a49:	75 2c                	jne    c0028a77 <list_init+0x37>
c0028a4b:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028a52:	c0 
c0028a53:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028a5a:	c0 
c0028a5b:	c7 44 24 08 65 dd 02 	movl   $0xc002dd65,0x8(%esp)
c0028a62:	c0 
c0028a63:	c7 44 24 04 3f 00 00 	movl   $0x3f,0x4(%esp)
c0028a6a:	00 
c0028a6b:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028a72:	e8 fc fe ff ff       	call   c0028973 <debug_panic>
  list->head.prev = NULL;
c0028a77:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
  list->head.next = &list->tail;
c0028a7d:	8d 50 08             	lea    0x8(%eax),%edx
c0028a80:	89 50 04             	mov    %edx,0x4(%eax)
  list->tail.prev = &list->head;
c0028a83:	89 40 08             	mov    %eax,0x8(%eax)
  list->tail.next = NULL;
c0028a86:	c7 40 0c 00 00 00 00 	movl   $0x0,0xc(%eax)
}
c0028a8d:	83 c4 2c             	add    $0x2c,%esp
c0028a90:	c3                   	ret    

c0028a91 <list_begin>:

/* Returns the beginning of LIST.  */
struct list_elem *
list_begin (struct list *list)
{
c0028a91:	83 ec 2c             	sub    $0x2c,%esp
c0028a94:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028a98:	85 c0                	test   %eax,%eax
c0028a9a:	75 2c                	jne    c0028ac8 <list_begin+0x37>
c0028a9c:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028aa3:	c0 
c0028aa4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028aab:	c0 
c0028aac:	c7 44 24 08 5a dd 02 	movl   $0xc002dd5a,0x8(%esp)
c0028ab3:	c0 
c0028ab4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c0028abb:	00 
c0028abc:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028ac3:	e8 ab fe ff ff       	call   c0028973 <debug_panic>
  return list->head.next;
c0028ac8:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028acb:	83 c4 2c             	add    $0x2c,%esp
c0028ace:	c3                   	ret    

c0028acf <list_next>:
/* Returns the element after ELEM in its list.  If ELEM is the
   last element in its list, returns the list tail.  Results are
   undefined if ELEM is itself a list tail. */
struct list_elem *
list_next (struct list_elem *elem)
{
c0028acf:	83 ec 2c             	sub    $0x2c,%esp
c0028ad2:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev == NULL && elem->next != NULL;
c0028ad6:	85 c0                	test   %eax,%eax
c0028ad8:	74 16                	je     c0028af0 <list_next+0x21>
c0028ada:	83 38 00             	cmpl   $0x0,(%eax)
c0028add:	75 06                	jne    c0028ae5 <list_next+0x16>
c0028adf:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028ae3:	75 37                	jne    c0028b1c <list_next+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ae5:	83 38 00             	cmpl   $0x0,(%eax)
c0028ae8:	74 06                	je     c0028af0 <list_next+0x21>
c0028aea:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028aee:	75 2c                	jne    c0028b1c <list_next+0x4d>
  ASSERT (is_head (elem) || is_interior (elem));
c0028af0:	c7 44 24 10 bc fc 02 	movl   $0xc002fcbc,0x10(%esp)
c0028af7:	c0 
c0028af8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028aff:	c0 
c0028b00:	c7 44 24 08 50 dd 02 	movl   $0xc002dd50,0x8(%esp)
c0028b07:	c0 
c0028b08:	c7 44 24 04 54 00 00 	movl   $0x54,0x4(%esp)
c0028b0f:	00 
c0028b10:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028b17:	e8 57 fe ff ff       	call   c0028973 <debug_panic>
  return elem->next;
c0028b1c:	8b 40 04             	mov    0x4(%eax),%eax
}
c0028b1f:	83 c4 2c             	add    $0x2c,%esp
c0028b22:	c3                   	ret    

c0028b23 <list_end>:
   list_end() is often used in iterating through a list from
   front to back.  See the big comment at the top of list.h for
   an example. */
struct list_elem *
list_end (struct list *list)
{
c0028b23:	83 ec 2c             	sub    $0x2c,%esp
c0028b26:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b2a:	85 c0                	test   %eax,%eax
c0028b2c:	75 2c                	jne    c0028b5a <list_end+0x37>
c0028b2e:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028b35:	c0 
c0028b36:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028b3d:	c0 
c0028b3e:	c7 44 24 08 47 dd 02 	movl   $0xc002dd47,0x8(%esp)
c0028b45:	c0 
c0028b46:	c7 44 24 04 60 00 00 	movl   $0x60,0x4(%esp)
c0028b4d:	00 
c0028b4e:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028b55:	e8 19 fe ff ff       	call   c0028973 <debug_panic>
  return &list->tail;
c0028b5a:	83 c0 08             	add    $0x8,%eax
}
c0028b5d:	83 c4 2c             	add    $0x2c,%esp
c0028b60:	c3                   	ret    

c0028b61 <list_rbegin>:

/* Returns the LIST's reverse beginning, for iterating through
   LIST in reverse order, from back to front. */
struct list_elem *
list_rbegin (struct list *list) 
{
c0028b61:	83 ec 2c             	sub    $0x2c,%esp
c0028b64:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028b68:	85 c0                	test   %eax,%eax
c0028b6a:	75 2c                	jne    c0028b98 <list_rbegin+0x37>
c0028b6c:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028b73:	c0 
c0028b74:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028b7b:	c0 
c0028b7c:	c7 44 24 08 3b dd 02 	movl   $0xc002dd3b,0x8(%esp)
c0028b83:	c0 
c0028b84:	c7 44 24 04 69 00 00 	movl   $0x69,0x4(%esp)
c0028b8b:	00 
c0028b8c:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028b93:	e8 db fd ff ff       	call   c0028973 <debug_panic>
  return list->tail.prev;
c0028b98:	8b 40 08             	mov    0x8(%eax),%eax
}
c0028b9b:	83 c4 2c             	add    $0x2c,%esp
c0028b9e:	c3                   	ret    

c0028b9f <list_prev>:
/* Returns the element before ELEM in its list.  If ELEM is the
   first element in its list, returns the list head.  Results are
   undefined if ELEM is itself a list head. */
struct list_elem *
list_prev (struct list_elem *elem)
{
c0028b9f:	83 ec 2c             	sub    $0x2c,%esp
c0028ba2:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ba6:	85 c0                	test   %eax,%eax
c0028ba8:	74 16                	je     c0028bc0 <list_prev+0x21>
c0028baa:	83 38 00             	cmpl   $0x0,(%eax)
c0028bad:	74 06                	je     c0028bb5 <list_prev+0x16>
c0028baf:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028bb3:	75 37                	jne    c0028bec <list_prev+0x4d>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028bb5:	83 38 00             	cmpl   $0x0,(%eax)
c0028bb8:	74 06                	je     c0028bc0 <list_prev+0x21>
c0028bba:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028bbe:	74 2c                	je     c0028bec <list_prev+0x4d>
  ASSERT (is_interior (elem) || is_tail (elem));
c0028bc0:	c7 44 24 10 e4 fc 02 	movl   $0xc002fce4,0x10(%esp)
c0028bc7:	c0 
c0028bc8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028bcf:	c0 
c0028bd0:	c7 44 24 08 31 dd 02 	movl   $0xc002dd31,0x8(%esp)
c0028bd7:	c0 
c0028bd8:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c0028bdf:	00 
c0028be0:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028be7:	e8 87 fd ff ff       	call   c0028973 <debug_panic>
  return elem->prev;
c0028bec:	8b 00                	mov    (%eax),%eax
}
c0028bee:	83 c4 2c             	add    $0x2c,%esp
c0028bf1:	c3                   	ret    

c0028bf2 <find_end_of_run>:
   run.
   A through B (exclusive) must form a non-empty range. */
static struct list_elem *
find_end_of_run (struct list_elem *a, struct list_elem *b,
                 list_less_func *less, void *aux)
{
c0028bf2:	55                   	push   %ebp
c0028bf3:	57                   	push   %edi
c0028bf4:	56                   	push   %esi
c0028bf5:	53                   	push   %ebx
c0028bf6:	83 ec 2c             	sub    $0x2c,%esp
c0028bf9:	89 c3                	mov    %eax,%ebx
c0028bfb:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (a != NULL);
c0028bff:	85 c0                	test   %eax,%eax
c0028c01:	75 2c                	jne    c0028c2f <find_end_of_run+0x3d>
c0028c03:	c7 44 24 10 19 ea 02 	movl   $0xc002ea19,0x10(%esp)
c0028c0a:	c0 
c0028c0b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028c12:	c0 
c0028c13:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028c1a:	c0 
c0028c1b:	c7 44 24 04 6a 01 00 	movl   $0x16a,0x4(%esp)
c0028c22:	00 
c0028c23:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028c2a:	e8 44 fd ff ff       	call   c0028973 <debug_panic>
c0028c2f:	89 d6                	mov    %edx,%esi
c0028c31:	89 cf                	mov    %ecx,%edi
  ASSERT (b != NULL);
c0028c33:	85 d2                	test   %edx,%edx
c0028c35:	75 2c                	jne    c0028c63 <find_end_of_run+0x71>
c0028c37:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0028c3e:	c0 
c0028c3f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028c46:	c0 
c0028c47:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028c4e:	c0 
c0028c4f:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
c0028c56:	00 
c0028c57:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028c5e:	e8 10 fd ff ff       	call   c0028973 <debug_panic>
  ASSERT (less != NULL);
c0028c63:	85 c9                	test   %ecx,%ecx
c0028c65:	75 2c                	jne    c0028c93 <find_end_of_run+0xa1>
c0028c67:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c0028c6e:	c0 
c0028c6f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028c76:	c0 
c0028c77:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028c7e:	c0 
c0028c7f:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
c0028c86:	00 
c0028c87:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028c8e:	e8 e0 fc ff ff       	call   c0028973 <debug_panic>
  ASSERT (a != b);
c0028c93:	39 d0                	cmp    %edx,%eax
c0028c95:	75 2c                	jne    c0028cc3 <find_end_of_run+0xd1>
c0028c97:	c7 44 24 10 38 fc 02 	movl   $0xc002fc38,0x10(%esp)
c0028c9e:	c0 
c0028c9f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028ca6:	c0 
c0028ca7:	c7 44 24 08 c0 dc 02 	movl   $0xc002dcc0,0x8(%esp)
c0028cae:	c0 
c0028caf:	c7 44 24 04 6d 01 00 	movl   $0x16d,0x4(%esp)
c0028cb6:	00 
c0028cb7:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028cbe:	e8 b0 fc ff ff       	call   c0028973 <debug_panic>
  
  do 
    {
      a = list_next (a);
c0028cc3:	89 1c 24             	mov    %ebx,(%esp)
c0028cc6:	e8 04 fe ff ff       	call   c0028acf <list_next>
c0028ccb:	89 c3                	mov    %eax,%ebx
    }
  while (a != b && !less (a, list_prev (a), aux));
c0028ccd:	39 f0                	cmp    %esi,%eax
c0028ccf:	74 19                	je     c0028cea <find_end_of_run+0xf8>
c0028cd1:	89 04 24             	mov    %eax,(%esp)
c0028cd4:	e8 c6 fe ff ff       	call   c0028b9f <list_prev>
c0028cd9:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0028cdd:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028ce1:	89 1c 24             	mov    %ebx,(%esp)
c0028ce4:	ff d7                	call   *%edi
c0028ce6:	84 c0                	test   %al,%al
c0028ce8:	74 d9                	je     c0028cc3 <find_end_of_run+0xd1>
  return a;
}
c0028cea:	89 d8                	mov    %ebx,%eax
c0028cec:	83 c4 2c             	add    $0x2c,%esp
c0028cef:	5b                   	pop    %ebx
c0028cf0:	5e                   	pop    %esi
c0028cf1:	5f                   	pop    %edi
c0028cf2:	5d                   	pop    %ebp
c0028cf3:	c3                   	ret    

c0028cf4 <is_sorted>:
{
c0028cf4:	55                   	push   %ebp
c0028cf5:	57                   	push   %edi
c0028cf6:	56                   	push   %esi
c0028cf7:	53                   	push   %ebx
c0028cf8:	83 ec 1c             	sub    $0x1c,%esp
c0028cfb:	89 c3                	mov    %eax,%ebx
c0028cfd:	89 d6                	mov    %edx,%esi
c0028cff:	89 cd                	mov    %ecx,%ebp
c0028d01:	8b 7c 24 30          	mov    0x30(%esp),%edi
  if (a != b)
c0028d05:	39 d0                	cmp    %edx,%eax
c0028d07:	75 1b                	jne    c0028d24 <is_sorted+0x30>
c0028d09:	eb 2e                	jmp    c0028d39 <is_sorted+0x45>
      if (less (a, list_prev (a), aux))
c0028d0b:	89 1c 24             	mov    %ebx,(%esp)
c0028d0e:	e8 8c fe ff ff       	call   c0028b9f <list_prev>
c0028d13:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0028d17:	89 44 24 04          	mov    %eax,0x4(%esp)
c0028d1b:	89 1c 24             	mov    %ebx,(%esp)
c0028d1e:	ff d5                	call   *%ebp
c0028d20:	84 c0                	test   %al,%al
c0028d22:	75 1c                	jne    c0028d40 <is_sorted+0x4c>
    while ((a = list_next (a)) != b) 
c0028d24:	89 1c 24             	mov    %ebx,(%esp)
c0028d27:	e8 a3 fd ff ff       	call   c0028acf <list_next>
c0028d2c:	89 c3                	mov    %eax,%ebx
c0028d2e:	39 f0                	cmp    %esi,%eax
c0028d30:	75 d9                	jne    c0028d0b <is_sorted+0x17>
  return true;
c0028d32:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d37:	eb 0c                	jmp    c0028d45 <is_sorted+0x51>
c0028d39:	b8 01 00 00 00       	mov    $0x1,%eax
c0028d3e:	eb 05                	jmp    c0028d45 <is_sorted+0x51>
        return false;
c0028d40:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0028d45:	83 c4 1c             	add    $0x1c,%esp
c0028d48:	5b                   	pop    %ebx
c0028d49:	5e                   	pop    %esi
c0028d4a:	5f                   	pop    %edi
c0028d4b:	5d                   	pop    %ebp
c0028d4c:	c3                   	ret    

c0028d4d <list_rend>:
{
c0028d4d:	83 ec 2c             	sub    $0x2c,%esp
c0028d50:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028d54:	85 c0                	test   %eax,%eax
c0028d56:	75 2c                	jne    c0028d84 <list_rend+0x37>
c0028d58:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028d5f:	c0 
c0028d60:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028d67:	c0 
c0028d68:	c7 44 24 08 27 dd 02 	movl   $0xc002dd27,0x8(%esp)
c0028d6f:	c0 
c0028d70:	c7 44 24 04 87 00 00 	movl   $0x87,0x4(%esp)
c0028d77:	00 
c0028d78:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028d7f:	e8 ef fb ff ff       	call   c0028973 <debug_panic>
}
c0028d84:	83 c4 2c             	add    $0x2c,%esp
c0028d87:	c3                   	ret    

c0028d88 <list_head>:
{
c0028d88:	83 ec 2c             	sub    $0x2c,%esp
c0028d8b:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028d8f:	85 c0                	test   %eax,%eax
c0028d91:	75 2c                	jne    c0028dbf <list_head+0x37>
c0028d93:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028d9a:	c0 
c0028d9b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028da2:	c0 
c0028da3:	c7 44 24 08 1d dd 02 	movl   $0xc002dd1d,0x8(%esp)
c0028daa:	c0 
c0028dab:	c7 44 24 04 99 00 00 	movl   $0x99,0x4(%esp)
c0028db2:	00 
c0028db3:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028dba:	e8 b4 fb ff ff       	call   c0028973 <debug_panic>
}
c0028dbf:	83 c4 2c             	add    $0x2c,%esp
c0028dc2:	c3                   	ret    

c0028dc3 <list_tail>:
{
c0028dc3:	83 ec 2c             	sub    $0x2c,%esp
c0028dc6:	8b 44 24 30          	mov    0x30(%esp),%eax
  ASSERT (list != NULL);
c0028dca:	85 c0                	test   %eax,%eax
c0028dcc:	75 2c                	jne    c0028dfa <list_tail+0x37>
c0028dce:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0028dd5:	c0 
c0028dd6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028ddd:	c0 
c0028dde:	c7 44 24 08 13 dd 02 	movl   $0xc002dd13,0x8(%esp)
c0028de5:	c0 
c0028de6:	c7 44 24 04 a1 00 00 	movl   $0xa1,0x4(%esp)
c0028ded:	00 
c0028dee:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028df5:	e8 79 fb ff ff       	call   c0028973 <debug_panic>
  return &list->tail;
c0028dfa:	83 c0 08             	add    $0x8,%eax
}
c0028dfd:	83 c4 2c             	add    $0x2c,%esp
c0028e00:	c3                   	ret    

c0028e01 <list_insert>:
{
c0028e01:	83 ec 2c             	sub    $0x2c,%esp
c0028e04:	8b 44 24 30          	mov    0x30(%esp),%eax
c0028e08:	8b 54 24 34          	mov    0x34(%esp),%edx
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028e0c:	85 c0                	test   %eax,%eax
c0028e0e:	74 56                	je     c0028e66 <list_insert+0x65>
c0028e10:	83 38 00             	cmpl   $0x0,(%eax)
c0028e13:	74 06                	je     c0028e1b <list_insert+0x1a>
c0028e15:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e19:	75 0b                	jne    c0028e26 <list_insert+0x25>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028e1b:	83 38 00             	cmpl   $0x0,(%eax)
c0028e1e:	74 46                	je     c0028e66 <list_insert+0x65>
c0028e20:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
c0028e24:	75 40                	jne    c0028e66 <list_insert+0x65>
  ASSERT (elem != NULL);
c0028e26:	85 d2                	test   %edx,%edx
c0028e28:	75 2c                	jne    c0028e56 <list_insert+0x55>
c0028e2a:	c7 44 24 10 3f fc 02 	movl   $0xc002fc3f,0x10(%esp)
c0028e31:	c0 
c0028e32:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028e39:	c0 
c0028e3a:	c7 44 24 08 07 dd 02 	movl   $0xc002dd07,0x8(%esp)
c0028e41:	c0 
c0028e42:	c7 44 24 04 ac 00 00 	movl   $0xac,0x4(%esp)
c0028e49:	00 
c0028e4a:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028e51:	e8 1d fb ff ff       	call   c0028973 <debug_panic>
  elem->prev = before->prev;
c0028e56:	8b 08                	mov    (%eax),%ecx
c0028e58:	89 0a                	mov    %ecx,(%edx)
  elem->next = before;
c0028e5a:	89 42 04             	mov    %eax,0x4(%edx)
  before->prev->next = elem;
c0028e5d:	8b 08                	mov    (%eax),%ecx
c0028e5f:	89 51 04             	mov    %edx,0x4(%ecx)
  before->prev = elem;
c0028e62:	89 10                	mov    %edx,(%eax)
c0028e64:	eb 2c                	jmp    c0028e92 <list_insert+0x91>
  ASSERT (is_interior (before) || is_tail (before));
c0028e66:	c7 44 24 10 0c fd 02 	movl   $0xc002fd0c,0x10(%esp)
c0028e6d:	c0 
c0028e6e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028e75:	c0 
c0028e76:	c7 44 24 08 07 dd 02 	movl   $0xc002dd07,0x8(%esp)
c0028e7d:	c0 
c0028e7e:	c7 44 24 04 ab 00 00 	movl   $0xab,0x4(%esp)
c0028e85:	00 
c0028e86:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028e8d:	e8 e1 fa ff ff       	call   c0028973 <debug_panic>
}
c0028e92:	83 c4 2c             	add    $0x2c,%esp
c0028e95:	c3                   	ret    

c0028e96 <list_splice>:
{
c0028e96:	56                   	push   %esi
c0028e97:	53                   	push   %ebx
c0028e98:	83 ec 24             	sub    $0x24,%esp
c0028e9b:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c0028e9f:	8b 74 24 34          	mov    0x34(%esp),%esi
c0028ea3:	8b 44 24 38          	mov    0x38(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ea7:	85 db                	test   %ebx,%ebx
c0028ea9:	74 4d                	je     c0028ef8 <list_splice+0x62>
c0028eab:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028eae:	74 06                	je     c0028eb6 <list_splice+0x20>
c0028eb0:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028eb4:	75 0b                	jne    c0028ec1 <list_splice+0x2b>
  return elem != NULL && elem->prev != NULL && elem->next == NULL;
c0028eb6:	83 3b 00             	cmpl   $0x0,(%ebx)
c0028eb9:	74 3d                	je     c0028ef8 <list_splice+0x62>
c0028ebb:	83 7b 04 00          	cmpl   $0x0,0x4(%ebx)
c0028ebf:	75 37                	jne    c0028ef8 <list_splice+0x62>
  if (first == last)
c0028ec1:	39 c6                	cmp    %eax,%esi
c0028ec3:	0f 84 cf 00 00 00    	je     c0028f98 <list_splice+0x102>
  last = list_prev (last);
c0028ec9:	89 04 24             	mov    %eax,(%esp)
c0028ecc:	e8 ce fc ff ff       	call   c0028b9f <list_prev>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028ed1:	85 f6                	test   %esi,%esi
c0028ed3:	74 4f                	je     c0028f24 <list_splice+0x8e>
c0028ed5:	8b 16                	mov    (%esi),%edx
c0028ed7:	85 d2                	test   %edx,%edx
c0028ed9:	74 49                	je     c0028f24 <list_splice+0x8e>
c0028edb:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c0028edf:	75 6f                	jne    c0028f50 <list_splice+0xba>
c0028ee1:	eb 41                	jmp    c0028f24 <list_splice+0x8e>
c0028ee3:	83 38 00             	cmpl   $0x0,(%eax)
c0028ee6:	74 6c                	je     c0028f54 <list_splice+0xbe>
c0028ee8:	8b 48 04             	mov    0x4(%eax),%ecx
c0028eeb:	85 c9                	test   %ecx,%ecx
c0028eed:	8d 76 00             	lea    0x0(%esi),%esi
c0028ef0:	0f 85 8a 00 00 00    	jne    c0028f80 <list_splice+0xea>
c0028ef6:	eb 5c                	jmp    c0028f54 <list_splice+0xbe>
  ASSERT (is_interior (before) || is_tail (before));
c0028ef8:	c7 44 24 10 0c fd 02 	movl   $0xc002fd0c,0x10(%esp)
c0028eff:	c0 
c0028f00:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028f07:	c0 
c0028f08:	c7 44 24 08 fb dc 02 	movl   $0xc002dcfb,0x8(%esp)
c0028f0f:	c0 
c0028f10:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c0028f17:	00 
c0028f18:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028f1f:	e8 4f fa ff ff       	call   c0028973 <debug_panic>
  ASSERT (is_interior (first));
c0028f24:	c7 44 24 10 4c fc 02 	movl   $0xc002fc4c,0x10(%esp)
c0028f2b:	c0 
c0028f2c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028f33:	c0 
c0028f34:	c7 44 24 08 fb dc 02 	movl   $0xc002dcfb,0x8(%esp)
c0028f3b:	c0 
c0028f3c:	c7 44 24 04 c0 00 00 	movl   $0xc0,0x4(%esp)
c0028f43:	00 
c0028f44:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028f4b:	e8 23 fa ff ff       	call   c0028973 <debug_panic>
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028f50:	85 c0                	test   %eax,%eax
c0028f52:	75 8f                	jne    c0028ee3 <list_splice+0x4d>
  ASSERT (is_interior (last));
c0028f54:	c7 44 24 10 60 fc 02 	movl   $0xc002fc60,0x10(%esp)
c0028f5b:	c0 
c0028f5c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0028f63:	c0 
c0028f64:	c7 44 24 08 fb dc 02 	movl   $0xc002dcfb,0x8(%esp)
c0028f6b:	c0 
c0028f6c:	c7 44 24 04 c1 00 00 	movl   $0xc1,0x4(%esp)
c0028f73:	00 
c0028f74:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0028f7b:	e8 f3 f9 ff ff       	call   c0028973 <debug_panic>
  first->prev->next = last->next;
c0028f80:	89 4a 04             	mov    %ecx,0x4(%edx)
  last->next->prev = first->prev;
c0028f83:	8b 50 04             	mov    0x4(%eax),%edx
c0028f86:	8b 0e                	mov    (%esi),%ecx
c0028f88:	89 0a                	mov    %ecx,(%edx)
  first->prev = before->prev;
c0028f8a:	8b 13                	mov    (%ebx),%edx
c0028f8c:	89 16                	mov    %edx,(%esi)
  last->next = before;
c0028f8e:	89 58 04             	mov    %ebx,0x4(%eax)
  before->prev->next = first;
c0028f91:	8b 13                	mov    (%ebx),%edx
c0028f93:	89 72 04             	mov    %esi,0x4(%edx)
  before->prev = last;
c0028f96:	89 03                	mov    %eax,(%ebx)
}
c0028f98:	83 c4 24             	add    $0x24,%esp
c0028f9b:	5b                   	pop    %ebx
c0028f9c:	5e                   	pop    %esi
c0028f9d:	c3                   	ret    

c0028f9e <list_push_front>:
{
c0028f9e:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_begin (list), elem);
c0028fa1:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028fa5:	89 04 24             	mov    %eax,(%esp)
c0028fa8:	e8 e4 fa ff ff       	call   c0028a91 <list_begin>
c0028fad:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028fb1:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028fb5:	89 04 24             	mov    %eax,(%esp)
c0028fb8:	e8 44 fe ff ff       	call   c0028e01 <list_insert>
}
c0028fbd:	83 c4 1c             	add    $0x1c,%esp
c0028fc0:	c3                   	ret    

c0028fc1 <list_push_back>:
{
c0028fc1:	83 ec 1c             	sub    $0x1c,%esp
  list_insert (list_end (list), elem);
c0028fc4:	8b 44 24 20          	mov    0x20(%esp),%eax
c0028fc8:	89 04 24             	mov    %eax,(%esp)
c0028fcb:	e8 53 fb ff ff       	call   c0028b23 <list_end>
c0028fd0:	8b 54 24 24          	mov    0x24(%esp),%edx
c0028fd4:	89 54 24 04          	mov    %edx,0x4(%esp)
c0028fd8:	89 04 24             	mov    %eax,(%esp)
c0028fdb:	e8 21 fe ff ff       	call   c0028e01 <list_insert>
}
c0028fe0:	83 c4 1c             	add    $0x1c,%esp
c0028fe3:	c3                   	ret    

c0028fe4 <list_remove>:
{
c0028fe4:	83 ec 2c             	sub    $0x2c,%esp
c0028fe7:	8b 44 24 30          	mov    0x30(%esp),%eax
  return elem != NULL && elem->prev != NULL && elem->next != NULL;
c0028feb:	85 c0                	test   %eax,%eax
c0028fed:	74 0d                	je     c0028ffc <list_remove+0x18>
c0028fef:	8b 10                	mov    (%eax),%edx
c0028ff1:	85 d2                	test   %edx,%edx
c0028ff3:	74 07                	je     c0028ffc <list_remove+0x18>
c0028ff5:	8b 48 04             	mov    0x4(%eax),%ecx
c0028ff8:	85 c9                	test   %ecx,%ecx
c0028ffa:	75 2c                	jne    c0029028 <list_remove+0x44>
  ASSERT (is_interior (elem));
c0028ffc:	c7 44 24 10 73 fc 02 	movl   $0xc002fc73,0x10(%esp)
c0029003:	c0 
c0029004:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002900b:	c0 
c002900c:	c7 44 24 08 ef dc 02 	movl   $0xc002dcef,0x8(%esp)
c0029013:	c0 
c0029014:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
c002901b:	00 
c002901c:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029023:	e8 4b f9 ff ff       	call   c0028973 <debug_panic>
  elem->prev->next = elem->next;
c0029028:	89 4a 04             	mov    %ecx,0x4(%edx)
  elem->next->prev = elem->prev;
c002902b:	8b 50 04             	mov    0x4(%eax),%edx
c002902e:	8b 08                	mov    (%eax),%ecx
c0029030:	89 0a                	mov    %ecx,(%edx)
  return elem->next;
c0029032:	8b 40 04             	mov    0x4(%eax),%eax
}
c0029035:	83 c4 2c             	add    $0x2c,%esp
c0029038:	c3                   	ret    

c0029039 <list_size>:
{
c0029039:	57                   	push   %edi
c002903a:	56                   	push   %esi
c002903b:	53                   	push   %ebx
c002903c:	83 ec 10             	sub    $0x10,%esp
c002903f:	8b 7c 24 20          	mov    0x20(%esp),%edi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029043:	89 3c 24             	mov    %edi,(%esp)
c0029046:	e8 46 fa ff ff       	call   c0028a91 <list_begin>
c002904b:	89 c3                	mov    %eax,%ebx
  size_t cnt = 0;
c002904d:	be 00 00 00 00       	mov    $0x0,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029052:	eb 0d                	jmp    c0029061 <list_size+0x28>
    cnt++;
c0029054:	83 c6 01             	add    $0x1,%esi
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029057:	89 1c 24             	mov    %ebx,(%esp)
c002905a:	e8 70 fa ff ff       	call   c0028acf <list_next>
c002905f:	89 c3                	mov    %eax,%ebx
c0029061:	89 3c 24             	mov    %edi,(%esp)
c0029064:	e8 ba fa ff ff       	call   c0028b23 <list_end>
c0029069:	39 d8                	cmp    %ebx,%eax
c002906b:	75 e7                	jne    c0029054 <list_size+0x1b>
}
c002906d:	89 f0                	mov    %esi,%eax
c002906f:	83 c4 10             	add    $0x10,%esp
c0029072:	5b                   	pop    %ebx
c0029073:	5e                   	pop    %esi
c0029074:	5f                   	pop    %edi
c0029075:	c3                   	ret    

c0029076 <list_empty>:
{
c0029076:	56                   	push   %esi
c0029077:	53                   	push   %ebx
c0029078:	83 ec 14             	sub    $0x14,%esp
c002907b:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  return list_begin (list) == list_end (list);
c002907f:	89 1c 24             	mov    %ebx,(%esp)
c0029082:	e8 0a fa ff ff       	call   c0028a91 <list_begin>
c0029087:	89 c6                	mov    %eax,%esi
c0029089:	89 1c 24             	mov    %ebx,(%esp)
c002908c:	e8 92 fa ff ff       	call   c0028b23 <list_end>
c0029091:	39 c6                	cmp    %eax,%esi
c0029093:	0f 94 c0             	sete   %al
}
c0029096:	83 c4 14             	add    $0x14,%esp
c0029099:	5b                   	pop    %ebx
c002909a:	5e                   	pop    %esi
c002909b:	c3                   	ret    

c002909c <list_front>:
{
c002909c:	53                   	push   %ebx
c002909d:	83 ec 28             	sub    $0x28,%esp
c00290a0:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c00290a4:	89 1c 24             	mov    %ebx,(%esp)
c00290a7:	e8 ca ff ff ff       	call   c0029076 <list_empty>
c00290ac:	84 c0                	test   %al,%al
c00290ae:	74 2c                	je     c00290dc <list_front+0x40>
c00290b0:	c7 44 24 10 86 fc 02 	movl   $0xc002fc86,0x10(%esp)
c00290b7:	c0 
c00290b8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00290bf:	c0 
c00290c0:	c7 44 24 08 e4 dc 02 	movl   $0xc002dce4,0x8(%esp)
c00290c7:	c0 
c00290c8:	c7 44 24 04 1b 01 00 	movl   $0x11b,0x4(%esp)
c00290cf:	00 
c00290d0:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00290d7:	e8 97 f8 ff ff       	call   c0028973 <debug_panic>
  return list->head.next;
c00290dc:	8b 43 04             	mov    0x4(%ebx),%eax
}
c00290df:	83 c4 28             	add    $0x28,%esp
c00290e2:	5b                   	pop    %ebx
c00290e3:	c3                   	ret    

c00290e4 <list_pop_front>:
{
c00290e4:	53                   	push   %ebx
c00290e5:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *front = list_front (list);
c00290e8:	8b 44 24 20          	mov    0x20(%esp),%eax
c00290ec:	89 04 24             	mov    %eax,(%esp)
c00290ef:	e8 a8 ff ff ff       	call   c002909c <list_front>
c00290f4:	89 c3                	mov    %eax,%ebx
  list_remove (front);
c00290f6:	89 04 24             	mov    %eax,(%esp)
c00290f9:	e8 e6 fe ff ff       	call   c0028fe4 <list_remove>
}
c00290fe:	89 d8                	mov    %ebx,%eax
c0029100:	83 c4 18             	add    $0x18,%esp
c0029103:	5b                   	pop    %ebx
c0029104:	c3                   	ret    

c0029105 <list_back>:
{
c0029105:	53                   	push   %ebx
c0029106:	83 ec 28             	sub    $0x28,%esp
c0029109:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (!list_empty (list));
c002910d:	89 1c 24             	mov    %ebx,(%esp)
c0029110:	e8 61 ff ff ff       	call   c0029076 <list_empty>
c0029115:	84 c0                	test   %al,%al
c0029117:	74 2c                	je     c0029145 <list_back+0x40>
c0029119:	c7 44 24 10 86 fc 02 	movl   $0xc002fc86,0x10(%esp)
c0029120:	c0 
c0029121:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029128:	c0 
c0029129:	c7 44 24 08 da dc 02 	movl   $0xc002dcda,0x8(%esp)
c0029130:	c0 
c0029131:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
c0029138:	00 
c0029139:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029140:	e8 2e f8 ff ff       	call   c0028973 <debug_panic>
  return list->tail.prev;
c0029145:	8b 43 08             	mov    0x8(%ebx),%eax
}
c0029148:	83 c4 28             	add    $0x28,%esp
c002914b:	5b                   	pop    %ebx
c002914c:	c3                   	ret    

c002914d <list_pop_back>:
{
c002914d:	53                   	push   %ebx
c002914e:	83 ec 18             	sub    $0x18,%esp
  struct list_elem *back = list_back (list);
c0029151:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029155:	89 04 24             	mov    %eax,(%esp)
c0029158:	e8 a8 ff ff ff       	call   c0029105 <list_back>
c002915d:	89 c3                	mov    %eax,%ebx
  list_remove (back);
c002915f:	89 04 24             	mov    %eax,(%esp)
c0029162:	e8 7d fe ff ff       	call   c0028fe4 <list_remove>
}
c0029167:	89 d8                	mov    %ebx,%eax
c0029169:	83 c4 18             	add    $0x18,%esp
c002916c:	5b                   	pop    %ebx
c002916d:	c3                   	ret    

c002916e <list_reverse>:
{
c002916e:	56                   	push   %esi
c002916f:	53                   	push   %ebx
c0029170:	83 ec 14             	sub    $0x14,%esp
c0029173:	8b 74 24 20          	mov    0x20(%esp),%esi
  if (!list_empty (list)) 
c0029177:	89 34 24             	mov    %esi,(%esp)
c002917a:	e8 f7 fe ff ff       	call   c0029076 <list_empty>
c002917f:	84 c0                	test   %al,%al
c0029181:	75 3a                	jne    c00291bd <list_reverse+0x4f>
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c0029183:	89 34 24             	mov    %esi,(%esp)
c0029186:	e8 06 f9 ff ff       	call   c0028a91 <list_begin>
c002918b:	89 c3                	mov    %eax,%ebx
c002918d:	eb 0c                	jmp    c002919b <list_reverse+0x2d>
  struct list_elem *t = *a;
c002918f:	8b 13                	mov    (%ebx),%edx
  *a = *b;
c0029191:	8b 43 04             	mov    0x4(%ebx),%eax
c0029194:	89 03                	mov    %eax,(%ebx)
  *b = t;
c0029196:	89 53 04             	mov    %edx,0x4(%ebx)
      for (e = list_begin (list); e != list_end (list); e = e->prev)
c0029199:	89 c3                	mov    %eax,%ebx
c002919b:	89 34 24             	mov    %esi,(%esp)
c002919e:	e8 80 f9 ff ff       	call   c0028b23 <list_end>
c00291a3:	39 d8                	cmp    %ebx,%eax
c00291a5:	75 e8                	jne    c002918f <list_reverse+0x21>
  struct list_elem *t = *a;
c00291a7:	8b 46 04             	mov    0x4(%esi),%eax
  *a = *b;
c00291aa:	8b 56 08             	mov    0x8(%esi),%edx
c00291ad:	89 56 04             	mov    %edx,0x4(%esi)
  *b = t;
c00291b0:	89 46 08             	mov    %eax,0x8(%esi)
  struct list_elem *t = *a;
c00291b3:	8b 0a                	mov    (%edx),%ecx
  *a = *b;
c00291b5:	8b 58 04             	mov    0x4(%eax),%ebx
c00291b8:	89 1a                	mov    %ebx,(%edx)
  *b = t;
c00291ba:	89 48 04             	mov    %ecx,0x4(%eax)
}
c00291bd:	83 c4 14             	add    $0x14,%esp
c00291c0:	5b                   	pop    %ebx
c00291c1:	5e                   	pop    %esi
c00291c2:	c3                   	ret    

c00291c3 <list_sort>:
/* Sorts LIST according to LESS given auxiliary data AUX, using a
   natural iterative merge sort that runs in O(n lg n) time and
   O(1) space in the number of elements in LIST. */
void
list_sort (struct list *list, list_less_func *less, void *aux)
{
c00291c3:	55                   	push   %ebp
c00291c4:	57                   	push   %edi
c00291c5:	56                   	push   %esi
c00291c6:	53                   	push   %ebx
c00291c7:	83 ec 2c             	sub    $0x2c,%esp
c00291ca:	8b 6c 24 44          	mov    0x44(%esp),%ebp
c00291ce:	8b 7c 24 48          	mov    0x48(%esp),%edi
  size_t output_run_cnt;        /* Number of runs output in current pass. */

  ASSERT (list != NULL);
c00291d2:	83 7c 24 40 00       	cmpl   $0x0,0x40(%esp)
c00291d7:	75 2c                	jne    c0029205 <list_sort+0x42>
c00291d9:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c00291e0:	c0 
c00291e1:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00291e8:	c0 
c00291e9:	c7 44 24 08 d0 dc 02 	movl   $0xc002dcd0,0x8(%esp)
c00291f0:	c0 
c00291f1:	c7 44 24 04 9a 01 00 	movl   $0x19a,0x4(%esp)
c00291f8:	00 
c00291f9:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029200:	e8 6e f7 ff ff       	call   c0028973 <debug_panic>
  ASSERT (less != NULL);
c0029205:	85 ed                	test   %ebp,%ebp
c0029207:	75 2c                	jne    c0029235 <list_sort+0x72>
c0029209:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c0029210:	c0 
c0029211:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029218:	c0 
c0029219:	c7 44 24 08 d0 dc 02 	movl   $0xc002dcd0,0x8(%esp)
c0029220:	c0 
c0029221:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
c0029228:	00 
c0029229:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029230:	e8 3e f7 ff ff       	call   c0028973 <debug_panic>
      struct list_elem *a0;     /* Start of first run. */
      struct list_elem *a1b0;   /* End of first run, start of second. */
      struct list_elem *b1;     /* End of second run. */

      output_run_cnt = 0;
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c0029235:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029239:	89 04 24             	mov    %eax,(%esp)
c002923c:	e8 50 f8 ff ff       	call   c0028a91 <list_begin>
c0029241:	89 c6                	mov    %eax,%esi
      output_run_cnt = 0;
c0029243:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002924a:	00 
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c002924b:	e9 99 01 00 00       	jmp    c00293e9 <list_sort+0x226>
        {
          /* Each iteration produces one output run. */
          output_run_cnt++;
c0029250:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)

          /* Locate two adjacent runs of nondecreasing elements
             A0...A1B0 and A1B0...B1. */
          a1b0 = find_end_of_run (a0, list_end (list), less, aux);
c0029255:	89 3c 24             	mov    %edi,(%esp)
c0029258:	89 e9                	mov    %ebp,%ecx
c002925a:	89 c2                	mov    %eax,%edx
c002925c:	89 f0                	mov    %esi,%eax
c002925e:	e8 8f f9 ff ff       	call   c0028bf2 <find_end_of_run>
c0029263:	89 c3                	mov    %eax,%ebx
          if (a1b0 == list_end (list))
c0029265:	8b 44 24 40          	mov    0x40(%esp),%eax
c0029269:	89 04 24             	mov    %eax,(%esp)
c002926c:	e8 b2 f8 ff ff       	call   c0028b23 <list_end>
c0029271:	39 d8                	cmp    %ebx,%eax
c0029273:	0f 84 84 01 00 00    	je     c00293fd <list_sort+0x23a>
            break;
          b1 = find_end_of_run (a1b0, list_end (list), less, aux);
c0029279:	89 3c 24             	mov    %edi,(%esp)
c002927c:	89 e9                	mov    %ebp,%ecx
c002927e:	89 c2                	mov    %eax,%edx
c0029280:	89 d8                	mov    %ebx,%eax
c0029282:	e8 6b f9 ff ff       	call   c0028bf2 <find_end_of_run>
c0029287:	89 44 24 18          	mov    %eax,0x18(%esp)
  ASSERT (a0 != NULL);
c002928b:	85 f6                	test   %esi,%esi
c002928d:	75 2c                	jne    c00292bb <list_sort+0xf8>
c002928f:	c7 44 24 10 99 fc 02 	movl   $0xc002fc99,0x10(%esp)
c0029296:	c0 
c0029297:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002929e:	c0 
c002929f:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c00292a6:	c0 
c00292a7:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
c00292ae:	00 
c00292af:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00292b6:	e8 b8 f6 ff ff       	call   c0028973 <debug_panic>
  ASSERT (a1b0 != NULL);
c00292bb:	85 db                	test   %ebx,%ebx
c00292bd:	75 2c                	jne    c00292eb <list_sort+0x128>
c00292bf:	c7 44 24 10 a4 fc 02 	movl   $0xc002fca4,0x10(%esp)
c00292c6:	c0 
c00292c7:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00292ce:	c0 
c00292cf:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c00292d6:	c0 
c00292d7:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
c00292de:	00 
c00292df:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00292e6:	e8 88 f6 ff ff       	call   c0028973 <debug_panic>
  ASSERT (b1 != NULL);
c00292eb:	83 7c 24 18 00       	cmpl   $0x0,0x18(%esp)
c00292f0:	75 2c                	jne    c002931e <list_sort+0x15b>
c00292f2:	c7 44 24 10 b1 fc 02 	movl   $0xc002fcb1,0x10(%esp)
c00292f9:	c0 
c00292fa:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029301:	c0 
c0029302:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c0029309:	c0 
c002930a:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
c0029311:	00 
c0029312:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029319:	e8 55 f6 ff ff       	call   c0028973 <debug_panic>
  ASSERT (is_sorted (a0, a1b0, less, aux));
c002931e:	89 3c 24             	mov    %edi,(%esp)
c0029321:	89 e9                	mov    %ebp,%ecx
c0029323:	89 da                	mov    %ebx,%edx
c0029325:	89 f0                	mov    %esi,%eax
c0029327:	e8 c8 f9 ff ff       	call   c0028cf4 <is_sorted>
c002932c:	84 c0                	test   %al,%al
c002932e:	75 2c                	jne    c002935c <list_sort+0x199>
c0029330:	c7 44 24 10 38 fd 02 	movl   $0xc002fd38,0x10(%esp)
c0029337:	c0 
c0029338:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002933f:	c0 
c0029340:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c0029347:	c0 
c0029348:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
c002934f:	00 
c0029350:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029357:	e8 17 f6 ff ff       	call   c0028973 <debug_panic>
  ASSERT (is_sorted (a1b0, b1, less, aux));
c002935c:	89 3c 24             	mov    %edi,(%esp)
c002935f:	89 e9                	mov    %ebp,%ecx
c0029361:	8b 54 24 18          	mov    0x18(%esp),%edx
c0029365:	89 d8                	mov    %ebx,%eax
c0029367:	e8 88 f9 ff ff       	call   c0028cf4 <is_sorted>
c002936c:	84 c0                	test   %al,%al
c002936e:	75 6b                	jne    c00293db <list_sort+0x218>
c0029370:	c7 44 24 10 58 fd 02 	movl   $0xc002fd58,0x10(%esp)
c0029377:	c0 
c0029378:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002937f:	c0 
c0029380:	c7 44 24 08 b2 dc 02 	movl   $0xc002dcb2,0x8(%esp)
c0029387:	c0 
c0029388:	c7 44 24 04 86 01 00 	movl   $0x186,0x4(%esp)
c002938f:	00 
c0029390:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029397:	e8 d7 f5 ff ff       	call   c0028973 <debug_panic>
    if (!less (a1b0, a0, aux)) 
c002939c:	89 7c 24 08          	mov    %edi,0x8(%esp)
c00293a0:	89 74 24 04          	mov    %esi,0x4(%esp)
c00293a4:	89 1c 24             	mov    %ebx,(%esp)
c00293a7:	ff d5                	call   *%ebp
c00293a9:	84 c0                	test   %al,%al
c00293ab:	75 0c                	jne    c00293b9 <list_sort+0x1f6>
      a0 = list_next (a0);
c00293ad:	89 34 24             	mov    %esi,(%esp)
c00293b0:	e8 1a f7 ff ff       	call   c0028acf <list_next>
c00293b5:	89 c6                	mov    %eax,%esi
c00293b7:	eb 22                	jmp    c00293db <list_sort+0x218>
        a1b0 = list_next (a1b0);
c00293b9:	89 1c 24             	mov    %ebx,(%esp)
c00293bc:	e8 0e f7 ff ff       	call   c0028acf <list_next>
c00293c1:	89 c3                	mov    %eax,%ebx
        list_splice (a0, list_prev (a1b0), a1b0);
c00293c3:	89 04 24             	mov    %eax,(%esp)
c00293c6:	e8 d4 f7 ff ff       	call   c0028b9f <list_prev>
c00293cb:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c00293cf:	89 44 24 04          	mov    %eax,0x4(%esp)
c00293d3:	89 34 24             	mov    %esi,(%esp)
c00293d6:	e8 bb fa ff ff       	call   c0028e96 <list_splice>
  while (a0 != a1b0 && a1b0 != b1)
c00293db:	39 5c 24 18          	cmp    %ebx,0x18(%esp)
c00293df:	74 04                	je     c00293e5 <list_sort+0x222>
c00293e1:	39 f3                	cmp    %esi,%ebx
c00293e3:	75 b7                	jne    c002939c <list_sort+0x1d9>
      for (a0 = list_begin (list); a0 != list_end (list); a0 = b1)
c00293e5:	8b 74 24 18          	mov    0x18(%esp),%esi
c00293e9:	8b 44 24 40          	mov    0x40(%esp),%eax
c00293ed:	89 04 24             	mov    %eax,(%esp)
c00293f0:	e8 2e f7 ff ff       	call   c0028b23 <list_end>
c00293f5:	39 f0                	cmp    %esi,%eax
c00293f7:	0f 85 53 fe ff ff    	jne    c0029250 <list_sort+0x8d>

          /* Merge the runs. */
          inplace_merge (a0, a1b0, b1, less, aux);
        }
    }
  while (output_run_cnt > 1);
c00293fd:	83 7c 24 1c 01       	cmpl   $0x1,0x1c(%esp)
c0029402:	0f 87 2d fe ff ff    	ja     c0029235 <list_sort+0x72>

  ASSERT (is_sorted (list_begin (list), list_end (list), less, aux));
c0029408:	8b 44 24 40          	mov    0x40(%esp),%eax
c002940c:	89 04 24             	mov    %eax,(%esp)
c002940f:	e8 0f f7 ff ff       	call   c0028b23 <list_end>
c0029414:	89 c3                	mov    %eax,%ebx
c0029416:	8b 44 24 40          	mov    0x40(%esp),%eax
c002941a:	89 04 24             	mov    %eax,(%esp)
c002941d:	e8 6f f6 ff ff       	call   c0028a91 <list_begin>
c0029422:	89 3c 24             	mov    %edi,(%esp)
c0029425:	89 e9                	mov    %ebp,%ecx
c0029427:	89 da                	mov    %ebx,%edx
c0029429:	e8 c6 f8 ff ff       	call   c0028cf4 <is_sorted>
c002942e:	84 c0                	test   %al,%al
c0029430:	75 2c                	jne    c002945e <list_sort+0x29b>
c0029432:	c7 44 24 10 78 fd 02 	movl   $0xc002fd78,0x10(%esp)
c0029439:	c0 
c002943a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029441:	c0 
c0029442:	c7 44 24 08 d0 dc 02 	movl   $0xc002dcd0,0x8(%esp)
c0029449:	c0 
c002944a:	c7 44 24 04 b8 01 00 	movl   $0x1b8,0x4(%esp)
c0029451:	00 
c0029452:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029459:	e8 15 f5 ff ff       	call   c0028973 <debug_panic>
}
c002945e:	83 c4 2c             	add    $0x2c,%esp
c0029461:	5b                   	pop    %ebx
c0029462:	5e                   	pop    %esi
c0029463:	5f                   	pop    %edi
c0029464:	5d                   	pop    %ebp
c0029465:	c3                   	ret    

c0029466 <list_insert_ordered>:
   sorted according to LESS given auxiliary data AUX.
   Runs in O(n) average case in the number of elements in LIST. */
void
list_insert_ordered (struct list *list, struct list_elem *elem,
                     list_less_func *less, void *aux)
{
c0029466:	55                   	push   %ebp
c0029467:	57                   	push   %edi
c0029468:	56                   	push   %esi
c0029469:	53                   	push   %ebx
c002946a:	83 ec 2c             	sub    $0x2c,%esp
c002946d:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029471:	8b 7c 24 44          	mov    0x44(%esp),%edi
c0029475:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *e;

  ASSERT (list != NULL);
c0029479:	85 f6                	test   %esi,%esi
c002947b:	75 2c                	jne    c00294a9 <list_insert_ordered+0x43>
c002947d:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c0029484:	c0 
c0029485:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002948c:	c0 
c002948d:	c7 44 24 08 9e dc 02 	movl   $0xc002dc9e,0x8(%esp)
c0029494:	c0 
c0029495:	c7 44 24 04 c4 01 00 	movl   $0x1c4,0x4(%esp)
c002949c:	00 
c002949d:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00294a4:	e8 ca f4 ff ff       	call   c0028973 <debug_panic>
  ASSERT (elem != NULL);
c00294a9:	85 ff                	test   %edi,%edi
c00294ab:	75 2c                	jne    c00294d9 <list_insert_ordered+0x73>
c00294ad:	c7 44 24 10 3f fc 02 	movl   $0xc002fc3f,0x10(%esp)
c00294b4:	c0 
c00294b5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00294bc:	c0 
c00294bd:	c7 44 24 08 9e dc 02 	movl   $0xc002dc9e,0x8(%esp)
c00294c4:	c0 
c00294c5:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
c00294cc:	00 
c00294cd:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00294d4:	e8 9a f4 ff ff       	call   c0028973 <debug_panic>
  ASSERT (less != NULL);
c00294d9:	85 ed                	test   %ebp,%ebp
c00294db:	75 2c                	jne    c0029509 <list_insert_ordered+0xa3>
c00294dd:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c00294e4:	c0 
c00294e5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00294ec:	c0 
c00294ed:	c7 44 24 08 9e dc 02 	movl   $0xc002dc9e,0x8(%esp)
c00294f4:	c0 
c00294f5:	c7 44 24 04 c6 01 00 	movl   $0x1c6,0x4(%esp)
c00294fc:	00 
c00294fd:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c0029504:	e8 6a f4 ff ff       	call   c0028973 <debug_panic>

  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c0029509:	89 34 24             	mov    %esi,(%esp)
c002950c:	e8 80 f5 ff ff       	call   c0028a91 <list_begin>
c0029511:	89 c3                	mov    %eax,%ebx
c0029513:	eb 1f                	jmp    c0029534 <list_insert_ordered+0xce>
    if (less (elem, e, aux))
c0029515:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c0029519:	89 44 24 08          	mov    %eax,0x8(%esp)
c002951d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029521:	89 3c 24             	mov    %edi,(%esp)
c0029524:	ff d5                	call   *%ebp
c0029526:	84 c0                	test   %al,%al
c0029528:	75 16                	jne    c0029540 <list_insert_ordered+0xda>
  for (e = list_begin (list); e != list_end (list); e = list_next (e))
c002952a:	89 1c 24             	mov    %ebx,(%esp)
c002952d:	e8 9d f5 ff ff       	call   c0028acf <list_next>
c0029532:	89 c3                	mov    %eax,%ebx
c0029534:	89 34 24             	mov    %esi,(%esp)
c0029537:	e8 e7 f5 ff ff       	call   c0028b23 <list_end>
c002953c:	39 d8                	cmp    %ebx,%eax
c002953e:	75 d5                	jne    c0029515 <list_insert_ordered+0xaf>
      break;
  return list_insert (e, elem);
c0029540:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029544:	89 1c 24             	mov    %ebx,(%esp)
c0029547:	e8 b5 f8 ff ff       	call   c0028e01 <list_insert>
}
c002954c:	83 c4 2c             	add    $0x2c,%esp
c002954f:	5b                   	pop    %ebx
c0029550:	5e                   	pop    %esi
c0029551:	5f                   	pop    %edi
c0029552:	5d                   	pop    %ebp
c0029553:	c3                   	ret    

c0029554 <list_unique>:
   given auxiliary data AUX.  If DUPLICATES is non-null, then the
   elements from LIST are appended to DUPLICATES. */
void
list_unique (struct list *list, struct list *duplicates,
             list_less_func *less, void *aux)
{
c0029554:	55                   	push   %ebp
c0029555:	57                   	push   %edi
c0029556:	56                   	push   %esi
c0029557:	53                   	push   %ebx
c0029558:	83 ec 2c             	sub    $0x2c,%esp
c002955b:	8b 7c 24 40          	mov    0x40(%esp),%edi
c002955f:	8b 6c 24 48          	mov    0x48(%esp),%ebp
  struct list_elem *elem, *next;

  ASSERT (list != NULL);
c0029563:	85 ff                	test   %edi,%edi
c0029565:	75 2c                	jne    c0029593 <list_unique+0x3f>
c0029567:	c7 44 24 10 06 fc 02 	movl   $0xc002fc06,0x10(%esp)
c002956e:	c0 
c002956f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029576:	c0 
c0029577:	c7 44 24 08 92 dc 02 	movl   $0xc002dc92,0x8(%esp)
c002957e:	c0 
c002957f:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
c0029586:	00 
c0029587:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c002958e:	e8 e0 f3 ff ff       	call   c0028973 <debug_panic>
  ASSERT (less != NULL);
c0029593:	85 ed                	test   %ebp,%ebp
c0029595:	75 2c                	jne    c00295c3 <list_unique+0x6f>
c0029597:	c7 44 24 10 2b fc 02 	movl   $0xc002fc2b,0x10(%esp)
c002959e:	c0 
c002959f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00295a6:	c0 
c00295a7:	c7 44 24 08 92 dc 02 	movl   $0xc002dc92,0x8(%esp)
c00295ae:	c0 
c00295af:	c7 44 24 04 d9 01 00 	movl   $0x1d9,0x4(%esp)
c00295b6:	00 
c00295b7:	c7 04 24 13 fc 02 c0 	movl   $0xc002fc13,(%esp)
c00295be:	e8 b0 f3 ff ff       	call   c0028973 <debug_panic>
  if (list_empty (list))
c00295c3:	89 3c 24             	mov    %edi,(%esp)
c00295c6:	e8 ab fa ff ff       	call   c0029076 <list_empty>
c00295cb:	84 c0                	test   %al,%al
c00295cd:	75 73                	jne    c0029642 <list_unique+0xee>
    return;

  elem = list_begin (list);
c00295cf:	89 3c 24             	mov    %edi,(%esp)
c00295d2:	e8 ba f4 ff ff       	call   c0028a91 <list_begin>
c00295d7:	89 c6                	mov    %eax,%esi
  while ((next = list_next (elem)) != list_end (list))
c00295d9:	eb 51                	jmp    c002962c <list_unique+0xd8>
    if (!less (elem, next, aux) && !less (next, elem, aux)) 
c00295db:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c00295df:	89 44 24 08          	mov    %eax,0x8(%esp)
c00295e3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c00295e7:	89 34 24             	mov    %esi,(%esp)
c00295ea:	ff d5                	call   *%ebp
c00295ec:	84 c0                	test   %al,%al
c00295ee:	75 3a                	jne    c002962a <list_unique+0xd6>
c00295f0:	8b 44 24 4c          	mov    0x4c(%esp),%eax
c00295f4:	89 44 24 08          	mov    %eax,0x8(%esp)
c00295f8:	89 74 24 04          	mov    %esi,0x4(%esp)
c00295fc:	89 1c 24             	mov    %ebx,(%esp)
c00295ff:	ff d5                	call   *%ebp
c0029601:	84 c0                	test   %al,%al
c0029603:	75 25                	jne    c002962a <list_unique+0xd6>
      {
        list_remove (next);
c0029605:	89 1c 24             	mov    %ebx,(%esp)
c0029608:	e8 d7 f9 ff ff       	call   c0028fe4 <list_remove>
        if (duplicates != NULL)
c002960d:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c0029612:	74 14                	je     c0029628 <list_unique+0xd4>
          list_push_back (duplicates, next);
c0029614:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029618:	8b 44 24 44          	mov    0x44(%esp),%eax
c002961c:	89 04 24             	mov    %eax,(%esp)
c002961f:	e8 9d f9 ff ff       	call   c0028fc1 <list_push_back>
c0029624:	89 f3                	mov    %esi,%ebx
c0029626:	eb 02                	jmp    c002962a <list_unique+0xd6>
c0029628:	89 f3                	mov    %esi,%ebx
c002962a:	89 de                	mov    %ebx,%esi
  while ((next = list_next (elem)) != list_end (list))
c002962c:	89 34 24             	mov    %esi,(%esp)
c002962f:	e8 9b f4 ff ff       	call   c0028acf <list_next>
c0029634:	89 c3                	mov    %eax,%ebx
c0029636:	89 3c 24             	mov    %edi,(%esp)
c0029639:	e8 e5 f4 ff ff       	call   c0028b23 <list_end>
c002963e:	39 c3                	cmp    %eax,%ebx
c0029640:	75 99                	jne    c00295db <list_unique+0x87>
      }
    else
      elem = next;
}
c0029642:	83 c4 2c             	add    $0x2c,%esp
c0029645:	5b                   	pop    %ebx
c0029646:	5e                   	pop    %esi
c0029647:	5f                   	pop    %edi
c0029648:	5d                   	pop    %ebp
c0029649:	c3                   	ret    

c002964a <list_max>:
   to LESS given auxiliary data AUX.  If there is more than one
   maximum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_max (struct list *list, list_less_func *less, void *aux)
{
c002964a:	55                   	push   %ebp
c002964b:	57                   	push   %edi
c002964c:	56                   	push   %esi
c002964d:	53                   	push   %ebx
c002964e:	83 ec 1c             	sub    $0x1c,%esp
c0029651:	8b 7c 24 30          	mov    0x30(%esp),%edi
c0029655:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *max = list_begin (list);
c0029659:	89 3c 24             	mov    %edi,(%esp)
c002965c:	e8 30 f4 ff ff       	call   c0028a91 <list_begin>
c0029661:	89 c6                	mov    %eax,%esi
  if (max != list_end (list)) 
c0029663:	89 3c 24             	mov    %edi,(%esp)
c0029666:	e8 b8 f4 ff ff       	call   c0028b23 <list_end>
c002966b:	39 f0                	cmp    %esi,%eax
c002966d:	74 36                	je     c00296a5 <list_max+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c002966f:	89 34 24             	mov    %esi,(%esp)
c0029672:	e8 58 f4 ff ff       	call   c0028acf <list_next>
c0029677:	89 c3                	mov    %eax,%ebx
c0029679:	eb 1e                	jmp    c0029699 <list_max+0x4f>
        if (less (max, e, aux))
c002967b:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002967f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029683:	89 34 24             	mov    %esi,(%esp)
c0029686:	ff 54 24 34          	call   *0x34(%esp)
c002968a:	84 c0                	test   %al,%al
          max = e; 
c002968c:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (max); e != list_end (list); e = list_next (e))
c002968f:	89 1c 24             	mov    %ebx,(%esp)
c0029692:	e8 38 f4 ff ff       	call   c0028acf <list_next>
c0029697:	89 c3                	mov    %eax,%ebx
c0029699:	89 3c 24             	mov    %edi,(%esp)
c002969c:	e8 82 f4 ff ff       	call   c0028b23 <list_end>
c00296a1:	39 d8                	cmp    %ebx,%eax
c00296a3:	75 d6                	jne    c002967b <list_max+0x31>
    }
  return max;
}
c00296a5:	89 f0                	mov    %esi,%eax
c00296a7:	83 c4 1c             	add    $0x1c,%esp
c00296aa:	5b                   	pop    %ebx
c00296ab:	5e                   	pop    %esi
c00296ac:	5f                   	pop    %edi
c00296ad:	5d                   	pop    %ebp
c00296ae:	c3                   	ret    

c00296af <list_min>:
   to LESS given auxiliary data AUX.  If there is more than one
   minimum, returns the one that appears earlier in the list.  If
   the list is empty, returns its tail. */
struct list_elem *
list_min (struct list *list, list_less_func *less, void *aux)
{
c00296af:	55                   	push   %ebp
c00296b0:	57                   	push   %edi
c00296b1:	56                   	push   %esi
c00296b2:	53                   	push   %ebx
c00296b3:	83 ec 1c             	sub    $0x1c,%esp
c00296b6:	8b 7c 24 30          	mov    0x30(%esp),%edi
c00296ba:	8b 6c 24 38          	mov    0x38(%esp),%ebp
  struct list_elem *min = list_begin (list);
c00296be:	89 3c 24             	mov    %edi,(%esp)
c00296c1:	e8 cb f3 ff ff       	call   c0028a91 <list_begin>
c00296c6:	89 c6                	mov    %eax,%esi
  if (min != list_end (list)) 
c00296c8:	89 3c 24             	mov    %edi,(%esp)
c00296cb:	e8 53 f4 ff ff       	call   c0028b23 <list_end>
c00296d0:	39 f0                	cmp    %esi,%eax
c00296d2:	74 36                	je     c002970a <list_min+0x5b>
    {
      struct list_elem *e;
      
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c00296d4:	89 34 24             	mov    %esi,(%esp)
c00296d7:	e8 f3 f3 ff ff       	call   c0028acf <list_next>
c00296dc:	89 c3                	mov    %eax,%ebx
c00296de:	eb 1e                	jmp    c00296fe <list_min+0x4f>
        if (less (e, min, aux))
c00296e0:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c00296e4:	89 74 24 04          	mov    %esi,0x4(%esp)
c00296e8:	89 1c 24             	mov    %ebx,(%esp)
c00296eb:	ff 54 24 34          	call   *0x34(%esp)
c00296ef:	84 c0                	test   %al,%al
          min = e; 
c00296f1:	0f 45 f3             	cmovne %ebx,%esi
      for (e = list_next (min); e != list_end (list); e = list_next (e))
c00296f4:	89 1c 24             	mov    %ebx,(%esp)
c00296f7:	e8 d3 f3 ff ff       	call   c0028acf <list_next>
c00296fc:	89 c3                	mov    %eax,%ebx
c00296fe:	89 3c 24             	mov    %edi,(%esp)
c0029701:	e8 1d f4 ff ff       	call   c0028b23 <list_end>
c0029706:	39 d8                	cmp    %ebx,%eax
c0029708:	75 d6                	jne    c00296e0 <list_min+0x31>
    }
  return min;
}
c002970a:	89 f0                	mov    %esi,%eax
c002970c:	83 c4 1c             	add    $0x1c,%esp
c002970f:	5b                   	pop    %ebx
c0029710:	5e                   	pop    %esi
c0029711:	5f                   	pop    %edi
c0029712:	5d                   	pop    %ebp
c0029713:	c3                   	ret    
c0029714:	90                   	nop
c0029715:	90                   	nop
c0029716:	90                   	nop
c0029717:	90                   	nop
c0029718:	90                   	nop
c0029719:	90                   	nop
c002971a:	90                   	nop
c002971b:	90                   	nop
c002971c:	90                   	nop
c002971d:	90                   	nop
c002971e:	90                   	nop
c002971f:	90                   	nop

c0029720 <bitmap_buf_size>:

/* Returns the number of elements required for BIT_CNT bits. */
static inline size_t
elem_cnt (size_t bit_cnt)
{
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029720:	8b 44 24 04          	mov    0x4(%esp),%eax
c0029724:	83 c0 1f             	add    $0x1f,%eax
c0029727:	c1 e8 05             	shr    $0x5,%eax
/* Returns the number of bytes required to accomodate a bitmap
   with BIT_CNT bits (for use with bitmap_create_in_buf()). */
size_t
bitmap_buf_size (size_t bit_cnt) 
{
  return sizeof (struct bitmap) + byte_cnt (bit_cnt);
c002972a:	8d 04 85 08 00 00 00 	lea    0x8(,%eax,4),%eax
}
c0029731:	c3                   	ret    

c0029732 <bitmap_destroy>:

/* Destroys bitmap B, freeing its storage.
   Not for use on bitmaps created by bitmap_create_in_buf(). */
void
bitmap_destroy (struct bitmap *b) 
{
c0029732:	53                   	push   %ebx
c0029733:	83 ec 18             	sub    $0x18,%esp
c0029736:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (b != NULL) 
c002973a:	85 db                	test   %ebx,%ebx
c002973c:	74 13                	je     c0029751 <bitmap_destroy+0x1f>
    {
      free (b->bits);
c002973e:	8b 43 04             	mov    0x4(%ebx),%eax
c0029741:	89 04 24             	mov    %eax,(%esp)
c0029744:	e8 f2 a2 ff ff       	call   c0023a3b <free>
      free (b);
c0029749:	89 1c 24             	mov    %ebx,(%esp)
c002974c:	e8 ea a2 ff ff       	call   c0023a3b <free>
    }
}
c0029751:	83 c4 18             	add    $0x18,%esp
c0029754:	5b                   	pop    %ebx
c0029755:	c3                   	ret    

c0029756 <bitmap_size>:

/* Returns the number of bits in B. */
size_t
bitmap_size (const struct bitmap *b)
{
  return b->bit_cnt;
c0029756:	8b 44 24 04          	mov    0x4(%esp),%eax
c002975a:	8b 00                	mov    (%eax),%eax
}
c002975c:	c3                   	ret    

c002975d <bitmap_mark>:
}

/* Atomically sets the bit numbered BIT_IDX in B to true. */
void
bitmap_mark (struct bitmap *b, size_t bit_idx) 
{
c002975d:	53                   	push   %ebx
c002975e:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c0029762:	89 ca                	mov    %ecx,%edx
c0029764:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] |= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the OR instruction in [IA32-v2b]. */
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029767:	8b 44 24 08          	mov    0x8(%esp),%eax
c002976b:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002976e:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029773:	d3 e3                	shl    %cl,%ebx
  asm ("orl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029775:	09 1c 90             	or     %ebx,(%eax,%edx,4)
}
c0029778:	5b                   	pop    %ebx
c0029779:	c3                   	ret    

c002977a <bitmap_reset>:

/* Atomically sets the bit numbered BIT_IDX in B to false. */
void
bitmap_reset (struct bitmap *b, size_t bit_idx) 
{
c002977a:	53                   	push   %ebx
c002977b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002977f:	89 ca                	mov    %ecx,%edx
c0029781:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] &= ~mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the AND instruction in [IA32-v2a]. */
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c0029784:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029788:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002978b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029790:	d3 e3                	shl    %cl,%ebx
  asm ("andl %1, %0" : "=m" (b->bits[idx]) : "r" (~mask) : "cc");
c0029792:	f7 d3                	not    %ebx
c0029794:	21 1c 90             	and    %ebx,(%eax,%edx,4)
}
c0029797:	5b                   	pop    %ebx
c0029798:	c3                   	ret    

c0029799 <bitmap_set>:
{
c0029799:	83 ec 2c             	sub    $0x2c,%esp
c002979c:	8b 44 24 30          	mov    0x30(%esp),%eax
c00297a0:	8b 54 24 34          	mov    0x34(%esp),%edx
c00297a4:	8b 4c 24 38          	mov    0x38(%esp),%ecx
  ASSERT (b != NULL);
c00297a8:	85 c0                	test   %eax,%eax
c00297aa:	75 2c                	jne    c00297d8 <bitmap_set+0x3f>
c00297ac:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c00297b3:	c0 
c00297b4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00297bb:	c0 
c00297bc:	c7 44 24 08 c7 dd 02 	movl   $0xc002ddc7,0x8(%esp)
c00297c3:	c0 
c00297c4:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
c00297cb:	00 
c00297cc:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c00297d3:	e8 9b f1 ff ff       	call   c0028973 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c00297d8:	39 10                	cmp    %edx,(%eax)
c00297da:	77 2c                	ja     c0029808 <bitmap_set+0x6f>
c00297dc:	c7 44 24 10 cc fd 02 	movl   $0xc002fdcc,0x10(%esp)
c00297e3:	c0 
c00297e4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00297eb:	c0 
c00297ec:	c7 44 24 08 c7 dd 02 	movl   $0xc002ddc7,0x8(%esp)
c00297f3:	c0 
c00297f4:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
c00297fb:	00 
c00297fc:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029803:	e8 6b f1 ff ff       	call   c0028973 <debug_panic>
  if (value)
c0029808:	84 c9                	test   %cl,%cl
c002980a:	74 0e                	je     c002981a <bitmap_set+0x81>
    bitmap_mark (b, idx);
c002980c:	89 54 24 04          	mov    %edx,0x4(%esp)
c0029810:	89 04 24             	mov    %eax,(%esp)
c0029813:	e8 45 ff ff ff       	call   c002975d <bitmap_mark>
c0029818:	eb 0c                	jmp    c0029826 <bitmap_set+0x8d>
    bitmap_reset (b, idx);
c002981a:	89 54 24 04          	mov    %edx,0x4(%esp)
c002981e:	89 04 24             	mov    %eax,(%esp)
c0029821:	e8 54 ff ff ff       	call   c002977a <bitmap_reset>
}
c0029826:	83 c4 2c             	add    $0x2c,%esp
c0029829:	c3                   	ret    

c002982a <bitmap_flip>:
/* Atomically toggles the bit numbered IDX in B;
   that is, if it is true, makes it false,
   and if it is false, makes it true. */
void
bitmap_flip (struct bitmap *b, size_t bit_idx) 
{
c002982a:	53                   	push   %ebx
c002982b:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
  return bit_idx / ELEM_BITS;
c002982f:	89 ca                	mov    %ecx,%edx
c0029831:	c1 ea 05             	shr    $0x5,%edx
  elem_type mask = bit_mask (bit_idx);

  /* This is equivalent to `b->bits[idx] ^= mask' except that it
     is guaranteed to be atomic on a uniprocessor machine.  See
     the description of the XOR instruction in [IA32-v2b]. */
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029834:	8b 44 24 08          	mov    0x8(%esp),%eax
c0029838:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c002983b:	bb 01 00 00 00       	mov    $0x1,%ebx
c0029840:	d3 e3                	shl    %cl,%ebx
  asm ("xorl %1, %0" : "=m" (b->bits[idx]) : "r" (mask) : "cc");
c0029842:	31 1c 90             	xor    %ebx,(%eax,%edx,4)
}
c0029845:	5b                   	pop    %ebx
c0029846:	c3                   	ret    

c0029847 <bitmap_test>:

/* Returns the value of the bit numbered IDX in B. */
bool
bitmap_test (const struct bitmap *b, size_t idx) 
{
c0029847:	53                   	push   %ebx
c0029848:	83 ec 28             	sub    $0x28,%esp
c002984b:	8b 44 24 30          	mov    0x30(%esp),%eax
c002984f:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (b != NULL);
c0029853:	85 c0                	test   %eax,%eax
c0029855:	75 2c                	jne    c0029883 <bitmap_test+0x3c>
c0029857:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c002985e:	c0 
c002985f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029866:	c0 
c0029867:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c002986e:	c0 
c002986f:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
c0029876:	00 
c0029877:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c002987e:	e8 f0 f0 ff ff       	call   c0028973 <debug_panic>
  ASSERT (idx < b->bit_cnt);
c0029883:	39 08                	cmp    %ecx,(%eax)
c0029885:	77 2c                	ja     c00298b3 <bitmap_test+0x6c>
c0029887:	c7 44 24 10 cc fd 02 	movl   $0xc002fdcc,0x10(%esp)
c002988e:	c0 
c002988f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029896:	c0 
c0029897:	c7 44 24 08 bb dd 02 	movl   $0xc002ddbb,0x8(%esp)
c002989e:	c0 
c002989f:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
c00298a6:	00 
c00298a7:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c00298ae:	e8 c0 f0 ff ff       	call   c0028973 <debug_panic>
  return bit_idx / ELEM_BITS;
c00298b3:	89 ca                	mov    %ecx,%edx
c00298b5:	c1 ea 05             	shr    $0x5,%edx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00298b8:	8b 40 04             	mov    0x4(%eax),%eax
  return (elem_type) 1 << (bit_idx % ELEM_BITS);
c00298bb:	bb 01 00 00 00       	mov    $0x1,%ebx
c00298c0:	d3 e3                	shl    %cl,%ebx
  return (b->bits[elem_idx (idx)] & bit_mask (idx)) != 0;
c00298c2:	85 1c 90             	test   %ebx,(%eax,%edx,4)
c00298c5:	0f 95 c0             	setne  %al
}
c00298c8:	83 c4 28             	add    $0x28,%esp
c00298cb:	5b                   	pop    %ebx
c00298cc:	c3                   	ret    

c00298cd <bitmap_set_multiple>:
}

/* Sets the CNT bits starting at START in B to VALUE. */
void
bitmap_set_multiple (struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c00298cd:	55                   	push   %ebp
c00298ce:	57                   	push   %edi
c00298cf:	56                   	push   %esi
c00298d0:	53                   	push   %ebx
c00298d1:	83 ec 2c             	sub    $0x2c,%esp
c00298d4:	8b 74 24 40          	mov    0x40(%esp),%esi
c00298d8:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c00298dc:	8b 44 24 48          	mov    0x48(%esp),%eax
c00298e0:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  size_t i;
  
  ASSERT (b != NULL);
c00298e5:	85 f6                	test   %esi,%esi
c00298e7:	75 2c                	jne    c0029915 <bitmap_set_multiple+0x48>
c00298e9:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c00298f0:	c0 
c00298f1:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00298f8:	c0 
c00298f9:	c7 44 24 08 98 dd 02 	movl   $0xc002dd98,0x8(%esp)
c0029900:	c0 
c0029901:	c7 44 24 04 de 00 00 	movl   $0xde,0x4(%esp)
c0029908:	00 
c0029909:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029910:	e8 5e f0 ff ff       	call   c0028973 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029915:	8b 16                	mov    (%esi),%edx
c0029917:	39 da                	cmp    %ebx,%edx
c0029919:	73 2c                	jae    c0029947 <bitmap_set_multiple+0x7a>
c002991b:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029922:	c0 
c0029923:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002992a:	c0 
c002992b:	c7 44 24 08 98 dd 02 	movl   $0xc002dd98,0x8(%esp)
c0029932:	c0 
c0029933:	c7 44 24 04 df 00 00 	movl   $0xdf,0x4(%esp)
c002993a:	00 
c002993b:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029942:	e8 2c f0 ff ff       	call   c0028973 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029947:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c002994a:	39 fa                	cmp    %edi,%edx
c002994c:	72 09                	jb     c0029957 <bitmap_set_multiple+0x8a>

  for (i = 0; i < cnt; i++)
    bitmap_set (b, start + i, value);
c002994e:	0f b6 e9             	movzbl %cl,%ebp
  for (i = 0; i < cnt; i++)
c0029951:	85 c0                	test   %eax,%eax
c0029953:	75 2e                	jne    c0029983 <bitmap_set_multiple+0xb6>
c0029955:	eb 43                	jmp    c002999a <bitmap_set_multiple+0xcd>
  ASSERT (start + cnt <= b->bit_cnt);
c0029957:	c7 44 24 10 f1 fd 02 	movl   $0xc002fdf1,0x10(%esp)
c002995e:	c0 
c002995f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029966:	c0 
c0029967:	c7 44 24 08 98 dd 02 	movl   $0xc002dd98,0x8(%esp)
c002996e:	c0 
c002996f:	c7 44 24 04 e0 00 00 	movl   $0xe0,0x4(%esp)
c0029976:	00 
c0029977:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c002997e:	e8 f0 ef ff ff       	call   c0028973 <debug_panic>
    bitmap_set (b, start + i, value);
c0029983:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c0029987:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002998b:	89 34 24             	mov    %esi,(%esp)
c002998e:	e8 06 fe ff ff       	call   c0029799 <bitmap_set>
c0029993:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029996:	39 df                	cmp    %ebx,%edi
c0029998:	75 e9                	jne    c0029983 <bitmap_set_multiple+0xb6>
}
c002999a:	83 c4 2c             	add    $0x2c,%esp
c002999d:	5b                   	pop    %ebx
c002999e:	5e                   	pop    %esi
c002999f:	5f                   	pop    %edi
c00299a0:	5d                   	pop    %ebp
c00299a1:	c3                   	ret    

c00299a2 <bitmap_set_all>:
{
c00299a2:	83 ec 2c             	sub    $0x2c,%esp
c00299a5:	8b 44 24 30          	mov    0x30(%esp),%eax
c00299a9:	8b 54 24 34          	mov    0x34(%esp),%edx
  ASSERT (b != NULL);
c00299ad:	85 c0                	test   %eax,%eax
c00299af:	75 2c                	jne    c00299dd <bitmap_set_all+0x3b>
c00299b1:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c00299b8:	c0 
c00299b9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c00299c0:	c0 
c00299c1:	c7 44 24 08 ac dd 02 	movl   $0xc002ddac,0x8(%esp)
c00299c8:	c0 
c00299c9:	c7 44 24 04 d3 00 00 	movl   $0xd3,0x4(%esp)
c00299d0:	00 
c00299d1:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c00299d8:	e8 96 ef ff ff       	call   c0028973 <debug_panic>
  bitmap_set_multiple (b, 0, bitmap_size (b), value);
c00299dd:	0f b6 d2             	movzbl %dl,%edx
c00299e0:	89 54 24 0c          	mov    %edx,0xc(%esp)
c00299e4:	8b 10                	mov    (%eax),%edx
c00299e6:	89 54 24 08          	mov    %edx,0x8(%esp)
c00299ea:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c00299f1:	00 
c00299f2:	89 04 24             	mov    %eax,(%esp)
c00299f5:	e8 d3 fe ff ff       	call   c00298cd <bitmap_set_multiple>
}
c00299fa:	83 c4 2c             	add    $0x2c,%esp
c00299fd:	c3                   	ret    

c00299fe <bitmap_create>:
{
c00299fe:	56                   	push   %esi
c00299ff:	53                   	push   %ebx
c0029a00:	83 ec 14             	sub    $0x14,%esp
c0029a03:	8b 74 24 20          	mov    0x20(%esp),%esi
  struct bitmap *b = malloc (sizeof *b);
c0029a07:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c0029a0e:	e8 a1 9e ff ff       	call   c00238b4 <malloc>
c0029a13:	89 c3                	mov    %eax,%ebx
  if (b != NULL)
c0029a15:	85 c0                	test   %eax,%eax
c0029a17:	74 41                	je     c0029a5a <bitmap_create+0x5c>
      b->bit_cnt = bit_cnt;
c0029a19:	89 30                	mov    %esi,(%eax)
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029a1b:	8d 46 1f             	lea    0x1f(%esi),%eax
c0029a1e:	c1 e8 05             	shr    $0x5,%eax
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029a21:	c1 e0 02             	shl    $0x2,%eax
      b->bits = malloc (byte_cnt (bit_cnt));
c0029a24:	89 04 24             	mov    %eax,(%esp)
c0029a27:	e8 88 9e ff ff       	call   c00238b4 <malloc>
c0029a2c:	89 43 04             	mov    %eax,0x4(%ebx)
      if (b->bits != NULL || bit_cnt == 0)
c0029a2f:	85 c0                	test   %eax,%eax
c0029a31:	75 04                	jne    c0029a37 <bitmap_create+0x39>
c0029a33:	85 f6                	test   %esi,%esi
c0029a35:	75 14                	jne    c0029a4b <bitmap_create+0x4d>
          bitmap_set_all (b, false);
c0029a37:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029a3e:	00 
c0029a3f:	89 1c 24             	mov    %ebx,(%esp)
c0029a42:	e8 5b ff ff ff       	call   c00299a2 <bitmap_set_all>
          return b;
c0029a47:	89 d8                	mov    %ebx,%eax
c0029a49:	eb 14                	jmp    c0029a5f <bitmap_create+0x61>
      free (b);
c0029a4b:	89 1c 24             	mov    %ebx,(%esp)
c0029a4e:	e8 e8 9f ff ff       	call   c0023a3b <free>
  return NULL;
c0029a53:	b8 00 00 00 00       	mov    $0x0,%eax
c0029a58:	eb 05                	jmp    c0029a5f <bitmap_create+0x61>
c0029a5a:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029a5f:	83 c4 14             	add    $0x14,%esp
c0029a62:	5b                   	pop    %ebx
c0029a63:	5e                   	pop    %esi
c0029a64:	c3                   	ret    

c0029a65 <bitmap_create_in_buf>:
{
c0029a65:	56                   	push   %esi
c0029a66:	53                   	push   %ebx
c0029a67:	83 ec 24             	sub    $0x24,%esp
c0029a6a:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029a6e:	8b 5c 24 34          	mov    0x34(%esp),%ebx
  ASSERT (block_size >= bitmap_buf_size (bit_cnt));
c0029a72:	89 34 24             	mov    %esi,(%esp)
c0029a75:	e8 a6 fc ff ff       	call   c0029720 <bitmap_buf_size>
c0029a7a:	3b 44 24 38          	cmp    0x38(%esp),%eax
c0029a7e:	76 2c                	jbe    c0029aac <bitmap_create_in_buf+0x47>
c0029a80:	c7 44 24 10 0c fe 02 	movl   $0xc002fe0c,0x10(%esp)
c0029a87:	c0 
c0029a88:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029a8f:	c0 
c0029a90:	c7 44 24 08 d2 dd 02 	movl   $0xc002ddd2,0x8(%esp)
c0029a97:	c0 
c0029a98:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
c0029a9f:	00 
c0029aa0:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029aa7:	e8 c7 ee ff ff       	call   c0028973 <debug_panic>
  b->bit_cnt = bit_cnt;
c0029aac:	89 33                	mov    %esi,(%ebx)
  b->bits = (elem_type *) (b + 1);
c0029aae:	8d 43 08             	lea    0x8(%ebx),%eax
c0029ab1:	89 43 04             	mov    %eax,0x4(%ebx)
  bitmap_set_all (b, false);
c0029ab4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0029abb:	00 
c0029abc:	89 1c 24             	mov    %ebx,(%esp)
c0029abf:	e8 de fe ff ff       	call   c00299a2 <bitmap_set_all>
}
c0029ac4:	89 d8                	mov    %ebx,%eax
c0029ac6:	83 c4 24             	add    $0x24,%esp
c0029ac9:	5b                   	pop    %ebx
c0029aca:	5e                   	pop    %esi
c0029acb:	c3                   	ret    

c0029acc <bitmap_count>:

/* Returns the number of bits in B between START and START + CNT,
   exclusive, that are set to VALUE. */
size_t
bitmap_count (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029acc:	55                   	push   %ebp
c0029acd:	57                   	push   %edi
c0029ace:	56                   	push   %esi
c0029acf:	53                   	push   %ebx
c0029ad0:	83 ec 2c             	sub    $0x2c,%esp
c0029ad3:	8b 7c 24 40          	mov    0x40(%esp),%edi
c0029ad7:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029adb:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029adf:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
c0029ae4:	88 4c 24 1f          	mov    %cl,0x1f(%esp)
  size_t i, value_cnt;

  ASSERT (b != NULL);
c0029ae8:	85 ff                	test   %edi,%edi
c0029aea:	75 2c                	jne    c0029b18 <bitmap_count+0x4c>
c0029aec:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0029af3:	c0 
c0029af4:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029afb:	c0 
c0029afc:	c7 44 24 08 8b dd 02 	movl   $0xc002dd8b,0x8(%esp)
c0029b03:	c0 
c0029b04:	c7 44 24 04 ed 00 00 	movl   $0xed,0x4(%esp)
c0029b0b:	00 
c0029b0c:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029b13:	e8 5b ee ff ff       	call   c0028973 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029b18:	8b 17                	mov    (%edi),%edx
c0029b1a:	39 da                	cmp    %ebx,%edx
c0029b1c:	73 2c                	jae    c0029b4a <bitmap_count+0x7e>
c0029b1e:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029b25:	c0 
c0029b26:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029b2d:	c0 
c0029b2e:	c7 44 24 08 8b dd 02 	movl   $0xc002dd8b,0x8(%esp)
c0029b35:	c0 
c0029b36:	c7 44 24 04 ee 00 00 	movl   $0xee,0x4(%esp)
c0029b3d:	00 
c0029b3e:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029b45:	e8 29 ee ff ff       	call   c0028973 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b4a:	8d 2c 03             	lea    (%ebx,%eax,1),%ebp
c0029b4d:	39 ea                	cmp    %ebp,%edx
c0029b4f:	72 0b                	jb     c0029b5c <bitmap_count+0x90>

  value_cnt = 0;
  for (i = 0; i < cnt; i++)
c0029b51:	be 00 00 00 00       	mov    $0x0,%esi
c0029b56:	85 c0                	test   %eax,%eax
c0029b58:	75 2e                	jne    c0029b88 <bitmap_count+0xbc>
c0029b5a:	eb 4b                	jmp    c0029ba7 <bitmap_count+0xdb>
  ASSERT (start + cnt <= b->bit_cnt);
c0029b5c:	c7 44 24 10 f1 fd 02 	movl   $0xc002fdf1,0x10(%esp)
c0029b63:	c0 
c0029b64:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029b6b:	c0 
c0029b6c:	c7 44 24 08 8b dd 02 	movl   $0xc002dd8b,0x8(%esp)
c0029b73:	c0 
c0029b74:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0029b7b:	00 
c0029b7c:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029b83:	e8 eb ed ff ff       	call   c0028973 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029b88:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029b8c:	89 3c 24             	mov    %edi,(%esp)
c0029b8f:	e8 b3 fc ff ff       	call   c0029847 <bitmap_test>
      value_cnt++;
c0029b94:	3a 44 24 1f          	cmp    0x1f(%esp),%al
c0029b98:	0f 94 c0             	sete   %al
c0029b9b:	0f b6 c0             	movzbl %al,%eax
c0029b9e:	01 c6                	add    %eax,%esi
c0029ba0:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029ba3:	39 dd                	cmp    %ebx,%ebp
c0029ba5:	75 e1                	jne    c0029b88 <bitmap_count+0xbc>
  return value_cnt;
}
c0029ba7:	89 f0                	mov    %esi,%eax
c0029ba9:	83 c4 2c             	add    $0x2c,%esp
c0029bac:	5b                   	pop    %ebx
c0029bad:	5e                   	pop    %esi
c0029bae:	5f                   	pop    %edi
c0029baf:	5d                   	pop    %ebp
c0029bb0:	c3                   	ret    

c0029bb1 <bitmap_contains>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to VALUE, and false otherwise. */
bool
bitmap_contains (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029bb1:	55                   	push   %ebp
c0029bb2:	57                   	push   %edi
c0029bb3:	56                   	push   %esi
c0029bb4:	53                   	push   %ebx
c0029bb5:	83 ec 2c             	sub    $0x2c,%esp
c0029bb8:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029bbc:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029bc0:	8b 44 24 48          	mov    0x48(%esp),%eax
c0029bc4:	0f b6 6c 24 4c       	movzbl 0x4c(%esp),%ebp
  size_t i;
  
  ASSERT (b != NULL);
c0029bc9:	85 f6                	test   %esi,%esi
c0029bcb:	75 2c                	jne    c0029bf9 <bitmap_contains+0x48>
c0029bcd:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0029bd4:	c0 
c0029bd5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029bdc:	c0 
c0029bdd:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0029be4:	c0 
c0029be5:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
c0029bec:	00 
c0029bed:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029bf4:	e8 7a ed ff ff       	call   c0028973 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029bf9:	8b 16                	mov    (%esi),%edx
c0029bfb:	39 da                	cmp    %ebx,%edx
c0029bfd:	73 2c                	jae    c0029c2b <bitmap_contains+0x7a>
c0029bff:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029c06:	c0 
c0029c07:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029c0e:	c0 
c0029c0f:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0029c16:	c0 
c0029c17:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
c0029c1e:	00 
c0029c1f:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029c26:	e8 48 ed ff ff       	call   c0028973 <debug_panic>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c2b:	8d 3c 03             	lea    (%ebx,%eax,1),%edi
c0029c2e:	39 fa                	cmp    %edi,%edx
c0029c30:	72 06                	jb     c0029c38 <bitmap_contains+0x87>

  for (i = 0; i < cnt; i++)
c0029c32:	85 c0                	test   %eax,%eax
c0029c34:	75 2e                	jne    c0029c64 <bitmap_contains+0xb3>
c0029c36:	eb 53                	jmp    c0029c8b <bitmap_contains+0xda>
  ASSERT (start + cnt <= b->bit_cnt);
c0029c38:	c7 44 24 10 f1 fd 02 	movl   $0xc002fdf1,0x10(%esp)
c0029c3f:	c0 
c0029c40:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029c47:	c0 
c0029c48:	c7 44 24 08 7b dd 02 	movl   $0xc002dd7b,0x8(%esp)
c0029c4f:	c0 
c0029c50:	c7 44 24 04 01 01 00 	movl   $0x101,0x4(%esp)
c0029c57:	00 
c0029c58:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029c5f:	e8 0f ed ff ff       	call   c0028973 <debug_panic>
    if (bitmap_test (b, start + i) == value)
c0029c64:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029c68:	89 34 24             	mov    %esi,(%esp)
c0029c6b:	e8 d7 fb ff ff       	call   c0029847 <bitmap_test>
c0029c70:	89 e9                	mov    %ebp,%ecx
c0029c72:	38 c8                	cmp    %cl,%al
c0029c74:	74 09                	je     c0029c7f <bitmap_contains+0xce>
c0029c76:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < cnt; i++)
c0029c79:	39 df                	cmp    %ebx,%edi
c0029c7b:	75 e7                	jne    c0029c64 <bitmap_contains+0xb3>
c0029c7d:	eb 07                	jmp    c0029c86 <bitmap_contains+0xd5>
      return true;
c0029c7f:	b8 01 00 00 00       	mov    $0x1,%eax
c0029c84:	eb 05                	jmp    c0029c8b <bitmap_contains+0xda>
  return false;
c0029c86:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0029c8b:	83 c4 2c             	add    $0x2c,%esp
c0029c8e:	5b                   	pop    %ebx
c0029c8f:	5e                   	pop    %esi
c0029c90:	5f                   	pop    %edi
c0029c91:	5d                   	pop    %ebp
c0029c92:	c3                   	ret    

c0029c93 <bitmap_any>:

/* Returns true if any bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_any (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029c93:	83 ec 1c             	sub    $0x1c,%esp
  return bitmap_contains (b, start, cnt, true);
c0029c96:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029c9d:	00 
c0029c9e:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029ca2:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029ca6:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029caa:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029cae:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029cb2:	89 04 24             	mov    %eax,(%esp)
c0029cb5:	e8 f7 fe ff ff       	call   c0029bb1 <bitmap_contains>
}
c0029cba:	83 c4 1c             	add    $0x1c,%esp
c0029cbd:	c3                   	ret    

c0029cbe <bitmap_none>:

/* Returns true if no bits in B between START and START + CNT,
   exclusive, are set to true, and false otherwise.*/
bool
bitmap_none (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cbe:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, true);
c0029cc1:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c0029cc8:	00 
c0029cc9:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029ccd:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029cd1:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029cd5:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029cd9:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029cdd:	89 04 24             	mov    %eax,(%esp)
c0029ce0:	e8 cc fe ff ff       	call   c0029bb1 <bitmap_contains>
c0029ce5:	83 f0 01             	xor    $0x1,%eax
}
c0029ce8:	83 c4 1c             	add    $0x1c,%esp
c0029ceb:	c3                   	ret    

c0029cec <bitmap_all>:

/* Returns true if every bit in B between START and START + CNT,
   exclusive, is set to true, and false otherwise. */
bool
bitmap_all (const struct bitmap *b, size_t start, size_t cnt) 
{
c0029cec:	83 ec 1c             	sub    $0x1c,%esp
  return !bitmap_contains (b, start, cnt, false);
c0029cef:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029cf6:	00 
c0029cf7:	8b 44 24 28          	mov    0x28(%esp),%eax
c0029cfb:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029cff:	8b 44 24 24          	mov    0x24(%esp),%eax
c0029d03:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029d07:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029d0b:	89 04 24             	mov    %eax,(%esp)
c0029d0e:	e8 9e fe ff ff       	call   c0029bb1 <bitmap_contains>
c0029d13:	83 f0 01             	xor    $0x1,%eax
}
c0029d16:	83 c4 1c             	add    $0x1c,%esp
c0029d19:	c3                   	ret    

c0029d1a <bitmap_scan>:
   consecutive bits in B at or after START that are all set to
   VALUE.
   If there is no such group, returns BITMAP_ERROR. */
size_t
bitmap_scan (const struct bitmap *b, size_t start, size_t cnt, bool value) 
{
c0029d1a:	55                   	push   %ebp
c0029d1b:	57                   	push   %edi
c0029d1c:	56                   	push   %esi
c0029d1d:	53                   	push   %ebx
c0029d1e:	83 ec 2c             	sub    $0x2c,%esp
c0029d21:	8b 74 24 40          	mov    0x40(%esp),%esi
c0029d25:	8b 5c 24 44          	mov    0x44(%esp),%ebx
c0029d29:	8b 7c 24 48          	mov    0x48(%esp),%edi
c0029d2d:	0f b6 4c 24 4c       	movzbl 0x4c(%esp),%ecx
  ASSERT (b != NULL);
c0029d32:	85 f6                	test   %esi,%esi
c0029d34:	75 2c                	jne    c0029d62 <bitmap_scan+0x48>
c0029d36:	c7 44 24 10 dd f9 02 	movl   $0xc002f9dd,0x10(%esp)
c0029d3d:	c0 
c0029d3e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029d45:	c0 
c0029d46:	c7 44 24 08 6f dd 02 	movl   $0xc002dd6f,0x8(%esp)
c0029d4d:	c0 
c0029d4e:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
c0029d55:	00 
c0029d56:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029d5d:	e8 11 ec ff ff       	call   c0028973 <debug_panic>
  ASSERT (start <= b->bit_cnt);
c0029d62:	8b 16                	mov    (%esi),%edx
c0029d64:	39 da                	cmp    %ebx,%edx
c0029d66:	73 2c                	jae    c0029d94 <bitmap_scan+0x7a>
c0029d68:	c7 44 24 10 dd fd 02 	movl   $0xc002fddd,0x10(%esp)
c0029d6f:	c0 
c0029d70:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029d77:	c0 
c0029d78:	c7 44 24 08 6f dd 02 	movl   $0xc002dd6f,0x8(%esp)
c0029d7f:	c0 
c0029d80:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0029d87:	00 
c0029d88:	c7 04 24 b2 fd 02 c0 	movl   $0xc002fdb2,(%esp)
c0029d8f:	e8 df eb ff ff       	call   c0028973 <debug_panic>
      size_t i;
      for (i = start; i <= last; i++)
        if (!bitmap_contains (b, i, cnt, !value))
          return i; 
    }
  return BITMAP_ERROR;
c0029d94:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  if (cnt <= b->bit_cnt) 
c0029d99:	39 fa                	cmp    %edi,%edx
c0029d9b:	72 45                	jb     c0029de2 <bitmap_scan+0xc8>
      size_t last = b->bit_cnt - cnt;
c0029d9d:	29 fa                	sub    %edi,%edx
c0029d9f:	89 54 24 1c          	mov    %edx,0x1c(%esp)
      for (i = start; i <= last; i++)
c0029da3:	39 d3                	cmp    %edx,%ebx
c0029da5:	77 2b                	ja     c0029dd2 <bitmap_scan+0xb8>
        if (!bitmap_contains (b, i, cnt, !value))
c0029da7:	83 f1 01             	xor    $0x1,%ecx
c0029daa:	0f b6 e9             	movzbl %cl,%ebp
c0029dad:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029db1:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029db5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029db9:	89 34 24             	mov    %esi,(%esp)
c0029dbc:	e8 f0 fd ff ff       	call   c0029bb1 <bitmap_contains>
c0029dc1:	84 c0                	test   %al,%al
c0029dc3:	74 14                	je     c0029dd9 <bitmap_scan+0xbf>
      for (i = start; i <= last; i++)
c0029dc5:	83 c3 01             	add    $0x1,%ebx
c0029dc8:	39 5c 24 1c          	cmp    %ebx,0x1c(%esp)
c0029dcc:	73 df                	jae    c0029dad <bitmap_scan+0x93>
c0029dce:	66 90                	xchg   %ax,%ax
c0029dd0:	eb 0b                	jmp    c0029ddd <bitmap_scan+0xc3>
  return BITMAP_ERROR;
c0029dd2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0029dd7:	eb 09                	jmp    c0029de2 <bitmap_scan+0xc8>
c0029dd9:	89 d8                	mov    %ebx,%eax
c0029ddb:	eb 05                	jmp    c0029de2 <bitmap_scan+0xc8>
c0029ddd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
c0029de2:	83 c4 2c             	add    $0x2c,%esp
c0029de5:	5b                   	pop    %ebx
c0029de6:	5e                   	pop    %esi
c0029de7:	5f                   	pop    %edi
c0029de8:	5d                   	pop    %ebp
c0029de9:	c3                   	ret    

c0029dea <bitmap_scan_and_flip>:
   If CNT is zero, returns 0.
   Bits are set atomically, but testing bits is not atomic with
   setting them. */
size_t
bitmap_scan_and_flip (struct bitmap *b, size_t start, size_t cnt, bool value)
{
c0029dea:	55                   	push   %ebp
c0029deb:	57                   	push   %edi
c0029dec:	56                   	push   %esi
c0029ded:	53                   	push   %ebx
c0029dee:	83 ec 1c             	sub    $0x1c,%esp
c0029df1:	8b 74 24 30          	mov    0x30(%esp),%esi
c0029df5:	8b 7c 24 38          	mov    0x38(%esp),%edi
c0029df9:	8b 6c 24 3c          	mov    0x3c(%esp),%ebp
  size_t idx = bitmap_scan (b, start, cnt, value);
c0029dfd:	89 e8                	mov    %ebp,%eax
c0029dff:	0f b6 c0             	movzbl %al,%eax
c0029e02:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0029e06:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e0a:	8b 44 24 34          	mov    0x34(%esp),%eax
c0029e0e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e12:	89 34 24             	mov    %esi,(%esp)
c0029e15:	e8 00 ff ff ff       	call   c0029d1a <bitmap_scan>
c0029e1a:	89 c3                	mov    %eax,%ebx
  if (idx != BITMAP_ERROR) 
c0029e1c:	83 f8 ff             	cmp    $0xffffffff,%eax
c0029e1f:	74 1c                	je     c0029e3d <bitmap_scan_and_flip+0x53>
    bitmap_set_multiple (b, idx, cnt, !value);
c0029e21:	89 e8                	mov    %ebp,%eax
c0029e23:	83 f0 01             	xor    $0x1,%eax
c0029e26:	0f b6 e8             	movzbl %al,%ebp
c0029e29:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c0029e2d:	89 7c 24 08          	mov    %edi,0x8(%esp)
c0029e31:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029e35:	89 34 24             	mov    %esi,(%esp)
c0029e38:	e8 90 fa ff ff       	call   c00298cd <bitmap_set_multiple>
  return idx;
}
c0029e3d:	89 d8                	mov    %ebx,%eax
c0029e3f:	83 c4 1c             	add    $0x1c,%esp
c0029e42:	5b                   	pop    %ebx
c0029e43:	5e                   	pop    %esi
c0029e44:	5f                   	pop    %edi
c0029e45:	5d                   	pop    %ebp
c0029e46:	c3                   	ret    

c0029e47 <bitmap_dump>:
/* Debugging. */

/* Dumps the contents of B to the console as hexadecimal. */
void
bitmap_dump (const struct bitmap *b) 
{
c0029e47:	83 ec 1c             	sub    $0x1c,%esp
c0029e4a:	8b 44 24 20          	mov    0x20(%esp),%eax
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e4e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0029e55:	00 
  return DIV_ROUND_UP (bit_cnt, ELEM_BITS);
c0029e56:	8b 08                	mov    (%eax),%ecx
c0029e58:	8d 51 1f             	lea    0x1f(%ecx),%edx
c0029e5b:	c1 ea 05             	shr    $0x5,%edx
  return sizeof (elem_type) * elem_cnt (bit_cnt);
c0029e5e:	c1 e2 02             	shl    $0x2,%edx
  hex_dump (0, b->bits, byte_cnt (b->bit_cnt), false);
c0029e61:	89 54 24 08          	mov    %edx,0x8(%esp)
c0029e65:	8b 40 04             	mov    0x4(%eax),%eax
c0029e68:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e6c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0029e73:	e8 d2 d3 ff ff       	call   c002724a <hex_dump>
}
c0029e78:	83 c4 1c             	add    $0x1c,%esp
c0029e7b:	c3                   	ret    
c0029e7c:	90                   	nop
c0029e7d:	90                   	nop
c0029e7e:	90                   	nop
c0029e7f:	90                   	nop

c0029e80 <find_bucket>:
}

/* Returns the bucket in H that E belongs in. */
static struct list *
find_bucket (struct hash *h, struct hash_elem *e) 
{
c0029e80:	53                   	push   %ebx
c0029e81:	83 ec 18             	sub    $0x18,%esp
c0029e84:	89 c3                	mov    %eax,%ebx
  size_t bucket_idx = h->hash (e, h->aux) & (h->bucket_cnt - 1);
c0029e86:	8b 40 14             	mov    0x14(%eax),%eax
c0029e89:	89 44 24 04          	mov    %eax,0x4(%esp)
c0029e8d:	89 14 24             	mov    %edx,(%esp)
c0029e90:	ff 53 0c             	call   *0xc(%ebx)
c0029e93:	8b 4b 04             	mov    0x4(%ebx),%ecx
c0029e96:	8d 51 ff             	lea    -0x1(%ecx),%edx
c0029e99:	21 d0                	and    %edx,%eax
  return &h->buckets[bucket_idx];
c0029e9b:	c1 e0 04             	shl    $0x4,%eax
c0029e9e:	03 43 08             	add    0x8(%ebx),%eax
}
c0029ea1:	83 c4 18             	add    $0x18,%esp
c0029ea4:	5b                   	pop    %ebx
c0029ea5:	c3                   	ret    

c0029ea6 <find_elem>:

/* Searches BUCKET in H for a hash element equal to E.  Returns
   it if found or a null pointer otherwise. */
static struct hash_elem *
find_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
c0029ea6:	55                   	push   %ebp
c0029ea7:	57                   	push   %edi
c0029ea8:	56                   	push   %esi
c0029ea9:	53                   	push   %ebx
c0029eaa:	83 ec 1c             	sub    $0x1c,%esp
c0029ead:	89 c6                	mov    %eax,%esi
c0029eaf:	89 d5                	mov    %edx,%ebp
c0029eb1:	89 cf                	mov    %ecx,%edi
  struct list_elem *i;

  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029eb3:	89 14 24             	mov    %edx,(%esp)
c0029eb6:	e8 d6 eb ff ff       	call   c0028a91 <list_begin>
c0029ebb:	89 c3                	mov    %eax,%ebx
c0029ebd:	eb 34                	jmp    c0029ef3 <find_elem+0x4d>
    {
      struct hash_elem *hi = list_elem_to_hash_elem (i);
      if (!h->less (hi, e, h->aux) && !h->less (e, hi, h->aux))
c0029ebf:	8b 46 14             	mov    0x14(%esi),%eax
c0029ec2:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029ec6:	89 7c 24 04          	mov    %edi,0x4(%esp)
c0029eca:	89 1c 24             	mov    %ebx,(%esp)
c0029ecd:	ff 56 10             	call   *0x10(%esi)
c0029ed0:	84 c0                	test   %al,%al
c0029ed2:	75 15                	jne    c0029ee9 <find_elem+0x43>
c0029ed4:	8b 46 14             	mov    0x14(%esi),%eax
c0029ed7:	89 44 24 08          	mov    %eax,0x8(%esp)
c0029edb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c0029edf:	89 3c 24             	mov    %edi,(%esp)
c0029ee2:	ff 56 10             	call   *0x10(%esi)
c0029ee5:	84 c0                	test   %al,%al
c0029ee7:	74 1d                	je     c0029f06 <find_elem+0x60>
  for (i = list_begin (bucket); i != list_end (bucket); i = list_next (i)) 
c0029ee9:	89 1c 24             	mov    %ebx,(%esp)
c0029eec:	e8 de eb ff ff       	call   c0028acf <list_next>
c0029ef1:	89 c3                	mov    %eax,%ebx
c0029ef3:	89 2c 24             	mov    %ebp,(%esp)
c0029ef6:	e8 28 ec ff ff       	call   c0028b23 <list_end>
c0029efb:	39 d8                	cmp    %ebx,%eax
c0029efd:	75 c0                	jne    c0029ebf <find_elem+0x19>
        return hi; 
    }
  return NULL;
c0029eff:	b8 00 00 00 00       	mov    $0x0,%eax
c0029f04:	eb 02                	jmp    c0029f08 <find_elem+0x62>
c0029f06:	89 d8                	mov    %ebx,%eax
}
c0029f08:	83 c4 1c             	add    $0x1c,%esp
c0029f0b:	5b                   	pop    %ebx
c0029f0c:	5e                   	pop    %esi
c0029f0d:	5f                   	pop    %edi
c0029f0e:	5d                   	pop    %ebp
c0029f0f:	c3                   	ret    

c0029f10 <rehash>:
   ideal.  This function can fail because of an out-of-memory
   condition, but that'll just make hash accesses less efficient;
   we can still continue. */
static void
rehash (struct hash *h) 
{
c0029f10:	55                   	push   %ebp
c0029f11:	57                   	push   %edi
c0029f12:	56                   	push   %esi
c0029f13:	53                   	push   %ebx
c0029f14:	83 ec 3c             	sub    $0x3c,%esp
c0029f17:	89 44 24 1c          	mov    %eax,0x1c(%esp)
  size_t old_bucket_cnt, new_bucket_cnt;
  struct list *new_buckets, *old_buckets;
  size_t i;

  ASSERT (h != NULL);
c0029f1b:	85 c0                	test   %eax,%eax
c0029f1d:	75 2c                	jne    c0029f4b <rehash+0x3b>
c0029f1f:	c7 44 24 10 34 fe 02 	movl   $0xc002fe34,0x10(%esp)
c0029f26:	c0 
c0029f27:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c0029f2e:	c0 
c0029f2f:	c7 44 24 08 1e de 02 	movl   $0xc002de1e,0x8(%esp)
c0029f36:	c0 
c0029f37:	c7 44 24 04 66 01 00 	movl   $0x166,0x4(%esp)
c0029f3e:	00 
c0029f3f:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c0029f46:	e8 28 ea ff ff       	call   c0028973 <debug_panic>

  /* Save old bucket info for later use. */
  old_buckets = h->buckets;
c0029f4b:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029f4f:	8b 48 08             	mov    0x8(%eax),%ecx
c0029f52:	89 4c 24 2c          	mov    %ecx,0x2c(%esp)
  old_bucket_cnt = h->bucket_cnt;
c0029f56:	8b 48 04             	mov    0x4(%eax),%ecx
c0029f59:	89 4c 24 28          	mov    %ecx,0x28(%esp)

  /* Calculate the number of buckets to use now.
     We want one bucket for about every BEST_ELEMS_PER_BUCKET.
     We must have at least four buckets, and the number of
     buckets must be a power of 2. */
  new_bucket_cnt = h->elem_cnt / BEST_ELEMS_PER_BUCKET;
c0029f5d:	8b 00                	mov    (%eax),%eax
c0029f5f:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029f63:	89 c3                	mov    %eax,%ebx
c0029f65:	d1 eb                	shr    %ebx
  if (new_bucket_cnt < 4)
    new_bucket_cnt = 4;
c0029f67:	83 fb 03             	cmp    $0x3,%ebx
c0029f6a:	b8 04 00 00 00       	mov    $0x4,%eax
c0029f6f:	0f 46 d8             	cmovbe %eax,%ebx
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029f72:	85 db                	test   %ebx,%ebx
c0029f74:	0f 84 d2 00 00 00    	je     c002a04c <rehash+0x13c>
  return x & (x - 1);
c0029f7a:	8d 43 ff             	lea    -0x1(%ebx),%eax
  return x != 0 && turn_off_least_1bit (x) == 0;
c0029f7d:	85 d8                	test   %ebx,%eax
c0029f7f:	0f 85 c7 00 00 00    	jne    c002a04c <rehash+0x13c>
c0029f85:	e9 cc 00 00 00       	jmp    c002a056 <rehash+0x146>
  /* Don't do anything if the bucket count wouldn't change. */
  if (new_bucket_cnt == old_bucket_cnt)
    return;

  /* Allocate new buckets and initialize them as empty. */
  new_buckets = malloc (sizeof *new_buckets * new_bucket_cnt);
c0029f8a:	89 d8                	mov    %ebx,%eax
c0029f8c:	c1 e0 04             	shl    $0x4,%eax
c0029f8f:	89 04 24             	mov    %eax,(%esp)
c0029f92:	e8 1d 99 ff ff       	call   c00238b4 <malloc>
c0029f97:	89 c5                	mov    %eax,%ebp
  if (new_buckets == NULL) 
c0029f99:	85 c0                	test   %eax,%eax
c0029f9b:	0f 84 bf 00 00 00    	je     c002a060 <rehash+0x150>
      /* Allocation failed.  This means that use of the hash table will
         be less efficient.  However, it is still usable, so
         there's no reason for it to be an error. */
      return;
    }
  for (i = 0; i < new_bucket_cnt; i++) 
c0029fa1:	85 db                	test   %ebx,%ebx
c0029fa3:	74 19                	je     c0029fbe <rehash+0xae>
c0029fa5:	89 c7                	mov    %eax,%edi
c0029fa7:	be 00 00 00 00       	mov    $0x0,%esi
    list_init (&new_buckets[i]);
c0029fac:	89 3c 24             	mov    %edi,(%esp)
c0029faf:	e8 8c ea ff ff       	call   c0028a40 <list_init>
  for (i = 0; i < new_bucket_cnt; i++) 
c0029fb4:	83 c6 01             	add    $0x1,%esi
c0029fb7:	83 c7 10             	add    $0x10,%edi
c0029fba:	39 de                	cmp    %ebx,%esi
c0029fbc:	75 ee                	jne    c0029fac <rehash+0x9c>

  /* Install new bucket info. */
  h->buckets = new_buckets;
c0029fbe:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029fc2:	89 68 08             	mov    %ebp,0x8(%eax)
  h->bucket_cnt = new_bucket_cnt;
c0029fc5:	89 58 04             	mov    %ebx,0x4(%eax)

  /* Move each old element into the appropriate new bucket. */
  for (i = 0; i < old_bucket_cnt; i++) 
c0029fc8:	83 7c 24 28 00       	cmpl   $0x0,0x28(%esp)
c0029fcd:	74 6f                	je     c002a03e <rehash+0x12e>
c0029fcf:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c0029fd3:	89 44 24 20          	mov    %eax,0x20(%esp)
c0029fd7:	c7 44 24 24 00 00 00 	movl   $0x0,0x24(%esp)
c0029fde:	00 
    {
      struct list *old_bucket;
      struct list_elem *elem, *next;

      old_bucket = &old_buckets[i];
c0029fdf:	8b 44 24 20          	mov    0x20(%esp),%eax
c0029fe3:	89 c5                	mov    %eax,%ebp
      for (elem = list_begin (old_bucket);
c0029fe5:	89 04 24             	mov    %eax,(%esp)
c0029fe8:	e8 a4 ea ff ff       	call   c0028a91 <list_begin>
c0029fed:	89 c3                	mov    %eax,%ebx
c0029fef:	eb 2d                	jmp    c002a01e <rehash+0x10e>
           elem != list_end (old_bucket); elem = next) 
        {
          struct list *new_bucket
c0029ff1:	89 da                	mov    %ebx,%edx
c0029ff3:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c0029ff7:	e8 84 fe ff ff       	call   c0029e80 <find_bucket>
c0029ffc:	89 c7                	mov    %eax,%edi
            = find_bucket (h, list_elem_to_hash_elem (elem));
          next = list_next (elem);
c0029ffe:	89 1c 24             	mov    %ebx,(%esp)
c002a001:	e8 c9 ea ff ff       	call   c0028acf <list_next>
c002a006:	89 c6                	mov    %eax,%esi
          list_remove (elem);
c002a008:	89 1c 24             	mov    %ebx,(%esp)
c002a00b:	e8 d4 ef ff ff       	call   c0028fe4 <list_remove>
          list_push_front (new_bucket, elem);
c002a010:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002a014:	89 3c 24             	mov    %edi,(%esp)
c002a017:	e8 82 ef ff ff       	call   c0028f9e <list_push_front>
           elem != list_end (old_bucket); elem = next) 
c002a01c:	89 f3                	mov    %esi,%ebx
c002a01e:	89 2c 24             	mov    %ebp,(%esp)
c002a021:	e8 fd ea ff ff       	call   c0028b23 <list_end>
      for (elem = list_begin (old_bucket);
c002a026:	39 d8                	cmp    %ebx,%eax
c002a028:	75 c7                	jne    c0029ff1 <rehash+0xe1>
  for (i = 0; i < old_bucket_cnt; i++) 
c002a02a:	83 44 24 24 01       	addl   $0x1,0x24(%esp)
c002a02f:	83 44 24 20 10       	addl   $0x10,0x20(%esp)
c002a034:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a038:	39 44 24 24          	cmp    %eax,0x24(%esp)
c002a03c:	75 a1                	jne    c0029fdf <rehash+0xcf>
        }
    }

  free (old_buckets);
c002a03e:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a042:	89 04 24             	mov    %eax,(%esp)
c002a045:	e8 f1 99 ff ff       	call   c0023a3b <free>
c002a04a:	eb 14                	jmp    c002a060 <rehash+0x150>
  return x & (x - 1);
c002a04c:	8d 43 ff             	lea    -0x1(%ebx),%eax
c002a04f:	21 c3                	and    %eax,%ebx
c002a051:	e9 1c ff ff ff       	jmp    c0029f72 <rehash+0x62>
  if (new_bucket_cnt == old_bucket_cnt)
c002a056:	3b 5c 24 28          	cmp    0x28(%esp),%ebx
c002a05a:	0f 85 2a ff ff ff    	jne    c0029f8a <rehash+0x7a>
}
c002a060:	83 c4 3c             	add    $0x3c,%esp
c002a063:	5b                   	pop    %ebx
c002a064:	5e                   	pop    %esi
c002a065:	5f                   	pop    %edi
c002a066:	5d                   	pop    %ebp
c002a067:	c3                   	ret    

c002a068 <hash_clear>:
{
c002a068:	55                   	push   %ebp
c002a069:	57                   	push   %edi
c002a06a:	56                   	push   %esi
c002a06b:	53                   	push   %ebx
c002a06c:	83 ec 1c             	sub    $0x1c,%esp
c002a06f:	8b 74 24 30          	mov    0x30(%esp),%esi
c002a073:	8b 7c 24 34          	mov    0x34(%esp),%edi
  for (i = 0; i < h->bucket_cnt; i++) 
c002a077:	83 7e 04 00          	cmpl   $0x0,0x4(%esi)
c002a07b:	74 43                	je     c002a0c0 <hash_clear+0x58>
c002a07d:	bd 00 00 00 00       	mov    $0x0,%ebp
c002a082:	89 eb                	mov    %ebp,%ebx
c002a084:	c1 e3 04             	shl    $0x4,%ebx
      struct list *bucket = &h->buckets[i];
c002a087:	03 5e 08             	add    0x8(%esi),%ebx
      if (destructor != NULL) 
c002a08a:	85 ff                	test   %edi,%edi
c002a08c:	75 16                	jne    c002a0a4 <hash_clear+0x3c>
c002a08e:	eb 20                	jmp    c002a0b0 <hash_clear+0x48>
            struct list_elem *list_elem = list_pop_front (bucket);
c002a090:	89 1c 24             	mov    %ebx,(%esp)
c002a093:	e8 4c f0 ff ff       	call   c00290e4 <list_pop_front>
            destructor (hash_elem, h->aux);
c002a098:	8b 56 14             	mov    0x14(%esi),%edx
c002a09b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002a09f:	89 04 24             	mov    %eax,(%esp)
c002a0a2:	ff d7                	call   *%edi
        while (!list_empty (bucket)) 
c002a0a4:	89 1c 24             	mov    %ebx,(%esp)
c002a0a7:	e8 ca ef ff ff       	call   c0029076 <list_empty>
c002a0ac:	84 c0                	test   %al,%al
c002a0ae:	74 e0                	je     c002a090 <hash_clear+0x28>
      list_init (bucket); 
c002a0b0:	89 1c 24             	mov    %ebx,(%esp)
c002a0b3:	e8 88 e9 ff ff       	call   c0028a40 <list_init>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a0b8:	83 c5 01             	add    $0x1,%ebp
c002a0bb:	39 6e 04             	cmp    %ebp,0x4(%esi)
c002a0be:	77 c2                	ja     c002a082 <hash_clear+0x1a>
  h->elem_cnt = 0;
c002a0c0:	c7 06 00 00 00 00    	movl   $0x0,(%esi)
}
c002a0c6:	83 c4 1c             	add    $0x1c,%esp
c002a0c9:	5b                   	pop    %ebx
c002a0ca:	5e                   	pop    %esi
c002a0cb:	5f                   	pop    %edi
c002a0cc:	5d                   	pop    %ebp
c002a0cd:	c3                   	ret    

c002a0ce <hash_init>:
{
c002a0ce:	53                   	push   %ebx
c002a0cf:	83 ec 18             	sub    $0x18,%esp
c002a0d2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  h->elem_cnt = 0;
c002a0d6:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)
  h->bucket_cnt = 4;
c002a0dc:	c7 43 04 04 00 00 00 	movl   $0x4,0x4(%ebx)
  h->buckets = malloc (sizeof *h->buckets * h->bucket_cnt);
c002a0e3:	c7 04 24 40 00 00 00 	movl   $0x40,(%esp)
c002a0ea:	e8 c5 97 ff ff       	call   c00238b4 <malloc>
c002a0ef:	89 c2                	mov    %eax,%edx
c002a0f1:	89 43 08             	mov    %eax,0x8(%ebx)
  h->hash = hash;
c002a0f4:	8b 44 24 24          	mov    0x24(%esp),%eax
c002a0f8:	89 43 0c             	mov    %eax,0xc(%ebx)
  h->less = less;
c002a0fb:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a0ff:	89 43 10             	mov    %eax,0x10(%ebx)
  h->aux = aux;
c002a102:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a106:	89 43 14             	mov    %eax,0x14(%ebx)
    return false;
c002a109:	b8 00 00 00 00       	mov    $0x0,%eax
  if (h->buckets != NULL) 
c002a10e:	85 d2                	test   %edx,%edx
c002a110:	74 15                	je     c002a127 <hash_init+0x59>
      hash_clear (h, NULL);
c002a112:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002a119:	00 
c002a11a:	89 1c 24             	mov    %ebx,(%esp)
c002a11d:	e8 46 ff ff ff       	call   c002a068 <hash_clear>
      return true;
c002a122:	b8 01 00 00 00       	mov    $0x1,%eax
}
c002a127:	83 c4 18             	add    $0x18,%esp
c002a12a:	5b                   	pop    %ebx
c002a12b:	c3                   	ret    

c002a12c <hash_destroy>:
{
c002a12c:	53                   	push   %ebx
c002a12d:	83 ec 18             	sub    $0x18,%esp
c002a130:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a134:	8b 44 24 24          	mov    0x24(%esp),%eax
  if (destructor != NULL)
c002a138:	85 c0                	test   %eax,%eax
c002a13a:	74 0c                	je     c002a148 <hash_destroy+0x1c>
    hash_clear (h, destructor);
c002a13c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a140:	89 1c 24             	mov    %ebx,(%esp)
c002a143:	e8 20 ff ff ff       	call   c002a068 <hash_clear>
  free (h->buckets);
c002a148:	8b 43 08             	mov    0x8(%ebx),%eax
c002a14b:	89 04 24             	mov    %eax,(%esp)
c002a14e:	e8 e8 98 ff ff       	call   c0023a3b <free>
}
c002a153:	83 c4 18             	add    $0x18,%esp
c002a156:	5b                   	pop    %ebx
c002a157:	c3                   	ret    

c002a158 <hash_insert>:
{
c002a158:	55                   	push   %ebp
c002a159:	57                   	push   %edi
c002a15a:	56                   	push   %esi
c002a15b:	53                   	push   %ebx
c002a15c:	83 ec 1c             	sub    $0x1c,%esp
c002a15f:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a163:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a167:	89 f2                	mov    %esi,%edx
c002a169:	89 d8                	mov    %ebx,%eax
c002a16b:	e8 10 fd ff ff       	call   c0029e80 <find_bucket>
c002a170:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a172:	89 f1                	mov    %esi,%ecx
c002a174:	89 c2                	mov    %eax,%edx
c002a176:	89 d8                	mov    %ebx,%eax
c002a178:	e8 29 fd ff ff       	call   c0029ea6 <find_elem>
c002a17d:	89 c7                	mov    %eax,%edi
  if (old == NULL) 
c002a17f:	85 c0                	test   %eax,%eax
c002a181:	75 0f                	jne    c002a192 <hash_insert+0x3a>

/* Inserts E into BUCKET (in hash table H). */
static void
insert_elem (struct hash *h, struct list *bucket, struct hash_elem *e) 
{
  h->elem_cnt++;
c002a183:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a186:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a18a:	89 2c 24             	mov    %ebp,(%esp)
c002a18d:	e8 0c ee ff ff       	call   c0028f9e <list_push_front>
  rehash (h);
c002a192:	89 d8                	mov    %ebx,%eax
c002a194:	e8 77 fd ff ff       	call   c0029f10 <rehash>
}
c002a199:	89 f8                	mov    %edi,%eax
c002a19b:	83 c4 1c             	add    $0x1c,%esp
c002a19e:	5b                   	pop    %ebx
c002a19f:	5e                   	pop    %esi
c002a1a0:	5f                   	pop    %edi
c002a1a1:	5d                   	pop    %ebp
c002a1a2:	c3                   	ret    

c002a1a3 <hash_replace>:
{
c002a1a3:	55                   	push   %ebp
c002a1a4:	57                   	push   %edi
c002a1a5:	56                   	push   %esi
c002a1a6:	53                   	push   %ebx
c002a1a7:	83 ec 1c             	sub    $0x1c,%esp
c002a1aa:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a1ae:	8b 74 24 34          	mov    0x34(%esp),%esi
  struct list *bucket = find_bucket (h, new);
c002a1b2:	89 f2                	mov    %esi,%edx
c002a1b4:	89 d8                	mov    %ebx,%eax
c002a1b6:	e8 c5 fc ff ff       	call   c0029e80 <find_bucket>
c002a1bb:	89 c5                	mov    %eax,%ebp
  struct hash_elem *old = find_elem (h, bucket, new);
c002a1bd:	89 f1                	mov    %esi,%ecx
c002a1bf:	89 c2                	mov    %eax,%edx
c002a1c1:	89 d8                	mov    %ebx,%eax
c002a1c3:	e8 de fc ff ff       	call   c0029ea6 <find_elem>
c002a1c8:	89 c7                	mov    %eax,%edi
  if (old != NULL)
c002a1ca:	85 c0                	test   %eax,%eax
c002a1cc:	74 0b                	je     c002a1d9 <hash_replace+0x36>

/* Removes E from hash table H. */
static void
remove_elem (struct hash *h, struct hash_elem *e) 
{
  h->elem_cnt--;
c002a1ce:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a1d1:	89 04 24             	mov    %eax,(%esp)
c002a1d4:	e8 0b ee ff ff       	call   c0028fe4 <list_remove>
  h->elem_cnt++;
c002a1d9:	83 03 01             	addl   $0x1,(%ebx)
  list_push_front (bucket, &e->list_elem);
c002a1dc:	89 74 24 04          	mov    %esi,0x4(%esp)
c002a1e0:	89 2c 24             	mov    %ebp,(%esp)
c002a1e3:	e8 b6 ed ff ff       	call   c0028f9e <list_push_front>
  rehash (h);
c002a1e8:	89 d8                	mov    %ebx,%eax
c002a1ea:	e8 21 fd ff ff       	call   c0029f10 <rehash>
}
c002a1ef:	89 f8                	mov    %edi,%eax
c002a1f1:	83 c4 1c             	add    $0x1c,%esp
c002a1f4:	5b                   	pop    %ebx
c002a1f5:	5e                   	pop    %esi
c002a1f6:	5f                   	pop    %edi
c002a1f7:	5d                   	pop    %ebp
c002a1f8:	c3                   	ret    

c002a1f9 <hash_find>:
{
c002a1f9:	56                   	push   %esi
c002a1fa:	53                   	push   %ebx
c002a1fb:	83 ec 04             	sub    $0x4,%esp
c002a1fe:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a202:	8b 74 24 14          	mov    0x14(%esp),%esi
  return find_elem (h, find_bucket (h, e), e);
c002a206:	89 f2                	mov    %esi,%edx
c002a208:	89 d8                	mov    %ebx,%eax
c002a20a:	e8 71 fc ff ff       	call   c0029e80 <find_bucket>
c002a20f:	89 f1                	mov    %esi,%ecx
c002a211:	89 c2                	mov    %eax,%edx
c002a213:	89 d8                	mov    %ebx,%eax
c002a215:	e8 8c fc ff ff       	call   c0029ea6 <find_elem>
}
c002a21a:	83 c4 04             	add    $0x4,%esp
c002a21d:	5b                   	pop    %ebx
c002a21e:	5e                   	pop    %esi
c002a21f:	c3                   	ret    

c002a220 <hash_delete>:
{
c002a220:	56                   	push   %esi
c002a221:	53                   	push   %ebx
c002a222:	83 ec 14             	sub    $0x14,%esp
c002a225:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002a229:	8b 74 24 24          	mov    0x24(%esp),%esi
  struct hash_elem *found = find_elem (h, find_bucket (h, e), e);
c002a22d:	89 f2                	mov    %esi,%edx
c002a22f:	89 d8                	mov    %ebx,%eax
c002a231:	e8 4a fc ff ff       	call   c0029e80 <find_bucket>
c002a236:	89 f1                	mov    %esi,%ecx
c002a238:	89 c2                	mov    %eax,%edx
c002a23a:	89 d8                	mov    %ebx,%eax
c002a23c:	e8 65 fc ff ff       	call   c0029ea6 <find_elem>
c002a241:	89 c6                	mov    %eax,%esi
  if (found != NULL) 
c002a243:	85 c0                	test   %eax,%eax
c002a245:	74 12                	je     c002a259 <hash_delete+0x39>
  h->elem_cnt--;
c002a247:	83 2b 01             	subl   $0x1,(%ebx)
  list_remove (&e->list_elem);
c002a24a:	89 04 24             	mov    %eax,(%esp)
c002a24d:	e8 92 ed ff ff       	call   c0028fe4 <list_remove>
      rehash (h); 
c002a252:	89 d8                	mov    %ebx,%eax
c002a254:	e8 b7 fc ff ff       	call   c0029f10 <rehash>
}
c002a259:	89 f0                	mov    %esi,%eax
c002a25b:	83 c4 14             	add    $0x14,%esp
c002a25e:	5b                   	pop    %ebx
c002a25f:	5e                   	pop    %esi
c002a260:	c3                   	ret    

c002a261 <hash_apply>:
{
c002a261:	55                   	push   %ebp
c002a262:	57                   	push   %edi
c002a263:	56                   	push   %esi
c002a264:	53                   	push   %ebx
c002a265:	83 ec 2c             	sub    $0x2c,%esp
c002a268:	8b 6c 24 40          	mov    0x40(%esp),%ebp
  ASSERT (action != NULL);
c002a26c:	83 7c 24 44 00       	cmpl   $0x0,0x44(%esp)
c002a271:	74 10                	je     c002a283 <hash_apply+0x22>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a273:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a27a:	00 
c002a27b:	83 7d 04 00          	cmpl   $0x0,0x4(%ebp)
c002a27f:	75 2e                	jne    c002a2af <hash_apply+0x4e>
c002a281:	eb 76                	jmp    c002a2f9 <hash_apply+0x98>
  ASSERT (action != NULL);
c002a283:	c7 44 24 10 56 fe 02 	movl   $0xc002fe56,0x10(%esp)
c002a28a:	c0 
c002a28b:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a292:	c0 
c002a293:	c7 44 24 08 13 de 02 	movl   $0xc002de13,0x8(%esp)
c002a29a:	c0 
c002a29b:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
c002a2a2:	00 
c002a2a3:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a2aa:	e8 c4 e6 ff ff       	call   c0028973 <debug_panic>
c002a2af:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
c002a2b3:	c1 e7 04             	shl    $0x4,%edi
      struct list *bucket = &h->buckets[i];
c002a2b6:	03 7d 08             	add    0x8(%ebp),%edi
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a2b9:	89 3c 24             	mov    %edi,(%esp)
c002a2bc:	e8 d0 e7 ff ff       	call   c0028a91 <list_begin>
c002a2c1:	89 c3                	mov    %eax,%ebx
c002a2c3:	eb 1a                	jmp    c002a2df <hash_apply+0x7e>
          next = list_next (elem);
c002a2c5:	89 1c 24             	mov    %ebx,(%esp)
c002a2c8:	e8 02 e8 ff ff       	call   c0028acf <list_next>
c002a2cd:	89 c6                	mov    %eax,%esi
          action (list_elem_to_hash_elem (elem), h->aux);
c002a2cf:	8b 45 14             	mov    0x14(%ebp),%eax
c002a2d2:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a2d6:	89 1c 24             	mov    %ebx,(%esp)
c002a2d9:	ff 54 24 44          	call   *0x44(%esp)
      for (elem = list_begin (bucket); elem != list_end (bucket); elem = next) 
c002a2dd:	89 f3                	mov    %esi,%ebx
c002a2df:	89 3c 24             	mov    %edi,(%esp)
c002a2e2:	e8 3c e8 ff ff       	call   c0028b23 <list_end>
c002a2e7:	39 d8                	cmp    %ebx,%eax
c002a2e9:	75 da                	jne    c002a2c5 <hash_apply+0x64>
  for (i = 0; i < h->bucket_cnt; i++) 
c002a2eb:	83 44 24 1c 01       	addl   $0x1,0x1c(%esp)
c002a2f0:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a2f4:	39 45 04             	cmp    %eax,0x4(%ebp)
c002a2f7:	77 b6                	ja     c002a2af <hash_apply+0x4e>
}
c002a2f9:	83 c4 2c             	add    $0x2c,%esp
c002a2fc:	5b                   	pop    %ebx
c002a2fd:	5e                   	pop    %esi
c002a2fe:	5f                   	pop    %edi
c002a2ff:	5d                   	pop    %ebp
c002a300:	c3                   	ret    

c002a301 <hash_first>:
{
c002a301:	53                   	push   %ebx
c002a302:	83 ec 28             	sub    $0x28,%esp
c002a305:	8b 5c 24 30          	mov    0x30(%esp),%ebx
c002a309:	8b 44 24 34          	mov    0x34(%esp),%eax
  ASSERT (i != NULL);
c002a30d:	85 db                	test   %ebx,%ebx
c002a30f:	75 2c                	jne    c002a33d <hash_first+0x3c>
c002a311:	c7 44 24 10 65 fe 02 	movl   $0xc002fe65,0x10(%esp)
c002a318:	c0 
c002a319:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a320:	c0 
c002a321:	c7 44 24 08 08 de 02 	movl   $0xc002de08,0x8(%esp)
c002a328:	c0 
c002a329:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
c002a330:	00 
c002a331:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a338:	e8 36 e6 ff ff       	call   c0028973 <debug_panic>
  ASSERT (h != NULL);
c002a33d:	85 c0                	test   %eax,%eax
c002a33f:	75 2c                	jne    c002a36d <hash_first+0x6c>
c002a341:	c7 44 24 10 34 fe 02 	movl   $0xc002fe34,0x10(%esp)
c002a348:	c0 
c002a349:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a350:	c0 
c002a351:	c7 44 24 08 08 de 02 	movl   $0xc002de08,0x8(%esp)
c002a358:	c0 
c002a359:	c7 44 24 04 cb 00 00 	movl   $0xcb,0x4(%esp)
c002a360:	00 
c002a361:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a368:	e8 06 e6 ff ff       	call   c0028973 <debug_panic>
  i->hash = h;
c002a36d:	89 03                	mov    %eax,(%ebx)
  i->bucket = i->hash->buckets;
c002a36f:	8b 40 08             	mov    0x8(%eax),%eax
c002a372:	89 43 04             	mov    %eax,0x4(%ebx)
  i->elem = list_elem_to_hash_elem (list_head (i->bucket));
c002a375:	89 04 24             	mov    %eax,(%esp)
c002a378:	e8 0b ea ff ff       	call   c0028d88 <list_head>
c002a37d:	89 43 08             	mov    %eax,0x8(%ebx)
}
c002a380:	83 c4 28             	add    $0x28,%esp
c002a383:	5b                   	pop    %ebx
c002a384:	c3                   	ret    

c002a385 <hash_next>:
{
c002a385:	56                   	push   %esi
c002a386:	53                   	push   %ebx
c002a387:	83 ec 24             	sub    $0x24,%esp
c002a38a:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  ASSERT (i != NULL);
c002a38e:	85 db                	test   %ebx,%ebx
c002a390:	75 2c                	jne    c002a3be <hash_next+0x39>
c002a392:	c7 44 24 10 65 fe 02 	movl   $0xc002fe65,0x10(%esp)
c002a399:	c0 
c002a39a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a3a1:	c0 
c002a3a2:	c7 44 24 08 fe dd 02 	movl   $0xc002ddfe,0x8(%esp)
c002a3a9:	c0 
c002a3aa:	c7 44 24 04 dd 00 00 	movl   $0xdd,0x4(%esp)
c002a3b1:	00 
c002a3b2:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a3b9:	e8 b5 e5 ff ff       	call   c0028973 <debug_panic>
  i->elem = list_elem_to_hash_elem (list_next (&i->elem->list_elem));
c002a3be:	8b 43 08             	mov    0x8(%ebx),%eax
c002a3c1:	89 04 24             	mov    %eax,(%esp)
c002a3c4:	e8 06 e7 ff ff       	call   c0028acf <list_next>
c002a3c9:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a3cc:	eb 2c                	jmp    c002a3fa <hash_next+0x75>
      if (++i->bucket >= i->hash->buckets + i->hash->bucket_cnt)
c002a3ce:	8b 43 04             	mov    0x4(%ebx),%eax
c002a3d1:	83 c0 10             	add    $0x10,%eax
c002a3d4:	89 43 04             	mov    %eax,0x4(%ebx)
c002a3d7:	8b 13                	mov    (%ebx),%edx
c002a3d9:	8b 4a 04             	mov    0x4(%edx),%ecx
c002a3dc:	c1 e1 04             	shl    $0x4,%ecx
c002a3df:	03 4a 08             	add    0x8(%edx),%ecx
c002a3e2:	39 c8                	cmp    %ecx,%eax
c002a3e4:	72 09                	jb     c002a3ef <hash_next+0x6a>
          i->elem = NULL;
c002a3e6:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
          break;
c002a3ed:	eb 1d                	jmp    c002a40c <hash_next+0x87>
      i->elem = list_elem_to_hash_elem (list_begin (i->bucket));
c002a3ef:	89 04 24             	mov    %eax,(%esp)
c002a3f2:	e8 9a e6 ff ff       	call   c0028a91 <list_begin>
c002a3f7:	89 43 08             	mov    %eax,0x8(%ebx)
  while (i->elem == list_elem_to_hash_elem (list_end (i->bucket)))
c002a3fa:	8b 73 08             	mov    0x8(%ebx),%esi
c002a3fd:	8b 43 04             	mov    0x4(%ebx),%eax
c002a400:	89 04 24             	mov    %eax,(%esp)
c002a403:	e8 1b e7 ff ff       	call   c0028b23 <list_end>
c002a408:	39 c6                	cmp    %eax,%esi
c002a40a:	74 c2                	je     c002a3ce <hash_next+0x49>
  return i->elem;
c002a40c:	8b 43 08             	mov    0x8(%ebx),%eax
}
c002a40f:	83 c4 24             	add    $0x24,%esp
c002a412:	5b                   	pop    %ebx
c002a413:	5e                   	pop    %esi
c002a414:	c3                   	ret    

c002a415 <hash_cur>:
  return i->elem;
c002a415:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a419:	8b 40 08             	mov    0x8(%eax),%eax
}
c002a41c:	c3                   	ret    

c002a41d <hash_size>:
  return h->elem_cnt;
c002a41d:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a421:	8b 00                	mov    (%eax),%eax
}
c002a423:	c3                   	ret    

c002a424 <hash_empty>:
  return h->elem_cnt == 0;
c002a424:	8b 44 24 04          	mov    0x4(%esp),%eax
c002a428:	83 38 00             	cmpl   $0x0,(%eax)
c002a42b:	0f 94 c0             	sete   %al
}
c002a42e:	c3                   	ret    

c002a42f <hash_bytes>:
{
c002a42f:	53                   	push   %ebx
c002a430:	83 ec 28             	sub    $0x28,%esp
c002a433:	8b 54 24 30          	mov    0x30(%esp),%edx
c002a437:	8b 4c 24 34          	mov    0x34(%esp),%ecx
  ASSERT (buf != NULL);
c002a43b:	85 d2                	test   %edx,%edx
c002a43d:	74 0e                	je     c002a44d <hash_bytes+0x1e>
c002a43f:	8d 1c 0a             	lea    (%edx,%ecx,1),%ebx
  while (size-- > 0)
c002a442:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a447:	85 c9                	test   %ecx,%ecx
c002a449:	75 2e                	jne    c002a479 <hash_bytes+0x4a>
c002a44b:	eb 3f                	jmp    c002a48c <hash_bytes+0x5d>
  ASSERT (buf != NULL);
c002a44d:	c7 44 24 10 6f fe 02 	movl   $0xc002fe6f,0x10(%esp)
c002a454:	c0 
c002a455:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a45c:	c0 
c002a45d:	c7 44 24 08 f3 dd 02 	movl   $0xc002ddf3,0x8(%esp)
c002a464:	c0 
c002a465:	c7 44 24 04 10 01 00 	movl   $0x110,0x4(%esp)
c002a46c:	00 
c002a46d:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a474:	e8 fa e4 ff ff       	call   c0028973 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *buf++;
c002a479:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a47f:	83 c2 01             	add    $0x1,%edx
c002a482:	0f b6 4a ff          	movzbl -0x1(%edx),%ecx
c002a486:	31 c8                	xor    %ecx,%eax
  while (size-- > 0)
c002a488:	39 da                	cmp    %ebx,%edx
c002a48a:	75 ed                	jne    c002a479 <hash_bytes+0x4a>
} 
c002a48c:	83 c4 28             	add    $0x28,%esp
c002a48f:	5b                   	pop    %ebx
c002a490:	c3                   	ret    

c002a491 <hash_string>:
{
c002a491:	83 ec 2c             	sub    $0x2c,%esp
c002a494:	8b 54 24 30          	mov    0x30(%esp),%edx
  ASSERT (s != NULL);
c002a498:	85 d2                	test   %edx,%edx
c002a49a:	74 0e                	je     c002a4aa <hash_string+0x19>
  while (*s != '\0')
c002a49c:	0f b6 0a             	movzbl (%edx),%ecx
c002a49f:	b8 c5 9d 1c 81       	mov    $0x811c9dc5,%eax
c002a4a4:	84 c9                	test   %cl,%cl
c002a4a6:	75 2e                	jne    c002a4d6 <hash_string+0x45>
c002a4a8:	eb 41                	jmp    c002a4eb <hash_string+0x5a>
  ASSERT (s != NULL);
c002a4aa:	c7 44 24 10 1a fa 02 	movl   $0xc002fa1a,0x10(%esp)
c002a4b1:	c0 
c002a4b2:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a4b9:	c0 
c002a4ba:	c7 44 24 08 e7 dd 02 	movl   $0xc002dde7,0x8(%esp)
c002a4c1:	c0 
c002a4c2:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
c002a4c9:	00 
c002a4ca:	c7 04 24 3e fe 02 c0 	movl   $0xc002fe3e,(%esp)
c002a4d1:	e8 9d e4 ff ff       	call   c0028973 <debug_panic>
    hash = (hash * FNV_32_PRIME) ^ *s++;
c002a4d6:	69 c0 93 01 00 01    	imul   $0x1000193,%eax,%eax
c002a4dc:	83 c2 01             	add    $0x1,%edx
c002a4df:	0f b6 c9             	movzbl %cl,%ecx
c002a4e2:	31 c8                	xor    %ecx,%eax
  while (*s != '\0')
c002a4e4:	0f b6 0a             	movzbl (%edx),%ecx
c002a4e7:	84 c9                	test   %cl,%cl
c002a4e9:	75 eb                	jne    c002a4d6 <hash_string+0x45>
}
c002a4eb:	83 c4 2c             	add    $0x2c,%esp
c002a4ee:	c3                   	ret    

c002a4ef <hash_int>:
{
c002a4ef:	83 ec 1c             	sub    $0x1c,%esp
  return hash_bytes (&i, sizeof i);
c002a4f2:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
c002a4f9:	00 
c002a4fa:	8d 44 24 20          	lea    0x20(%esp),%eax
c002a4fe:	89 04 24             	mov    %eax,(%esp)
c002a501:	e8 29 ff ff ff       	call   c002a42f <hash_bytes>
}
c002a506:	83 c4 1c             	add    $0x1c,%esp
c002a509:	c3                   	ret    

c002a50a <putchar_have_lock>:
/* Writes C to the vga display and serial port.
   The caller has already acquired the console lock if
   appropriate. */
static void
putchar_have_lock (uint8_t c) 
{
c002a50a:	53                   	push   %ebx
c002a50b:	83 ec 28             	sub    $0x28,%esp
c002a50e:	89 c3                	mov    %eax,%ebx
  return (intr_context ()
c002a510:	e8 9c 75 ff ff       	call   c0021ab1 <intr_context>
          || lock_held_by_current_thread (&console_lock));
c002a515:	84 c0                	test   %al,%al
c002a517:	75 45                	jne    c002a55e <putchar_have_lock+0x54>
          || !use_console_lock
c002a519:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a520:	74 3c                	je     c002a55e <putchar_have_lock+0x54>
          || lock_held_by_current_thread (&console_lock));
c002a522:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a529:	e8 73 87 ff ff       	call   c0022ca1 <lock_held_by_current_thread>
  ASSERT (console_locked_by_current_thread ());
c002a52e:	84 c0                	test   %al,%al
c002a530:	75 2c                	jne    c002a55e <putchar_have_lock+0x54>
c002a532:	c7 44 24 10 7c fe 02 	movl   $0xc002fe7c,0x10(%esp)
c002a539:	c0 
c002a53a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a541:	c0 
c002a542:	c7 44 24 08 25 de 02 	movl   $0xc002de25,0x8(%esp)
c002a549:	c0 
c002a54a:	c7 44 24 04 bb 00 00 	movl   $0xbb,0x4(%esp)
c002a551:	00 
c002a552:	c7 04 24 c1 fe 02 c0 	movl   $0xc002fec1,(%esp)
c002a559:	e8 15 e4 ff ff       	call   c0028973 <debug_panic>
  write_cnt++;
c002a55e:	83 05 e0 7a 03 c0 01 	addl   $0x1,0xc0037ae0
c002a565:	83 15 e4 7a 03 c0 00 	adcl   $0x0,0xc0037ae4
  serial_putc (c);
c002a56c:	0f b6 db             	movzbl %bl,%ebx
c002a56f:	89 1c 24             	mov    %ebx,(%esp)
c002a572:	e8 95 a5 ff ff       	call   c0024b0c <serial_putc>
  vga_putc (c);
c002a577:	89 1c 24             	mov    %ebx,(%esp)
c002a57a:	e8 aa a1 ff ff       	call   c0024729 <vga_putc>
}
c002a57f:	83 c4 28             	add    $0x28,%esp
c002a582:	5b                   	pop    %ebx
c002a583:	c3                   	ret    

c002a584 <vprintf_helper>:
{
c002a584:	83 ec 0c             	sub    $0xc,%esp
c002a587:	8b 44 24 14          	mov    0x14(%esp),%eax
  (*char_cnt)++;
c002a58b:	83 00 01             	addl   $0x1,(%eax)
  putchar_have_lock (c);
c002a58e:	0f b6 44 24 10       	movzbl 0x10(%esp),%eax
c002a593:	e8 72 ff ff ff       	call   c002a50a <putchar_have_lock>
}
c002a598:	83 c4 0c             	add    $0xc,%esp
c002a59b:	c3                   	ret    

c002a59c <acquire_console>:
{
c002a59c:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a59f:	e8 0d 75 ff ff       	call   c0021ab1 <intr_context>
c002a5a4:	84 c0                	test   %al,%al
c002a5a6:	75 2e                	jne    c002a5d6 <acquire_console+0x3a>
c002a5a8:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a5af:	74 25                	je     c002a5d6 <acquire_console+0x3a>
      if (lock_held_by_current_thread (&console_lock)) 
c002a5b1:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5b8:	e8 e4 86 ff ff       	call   c0022ca1 <lock_held_by_current_thread>
c002a5bd:	84 c0                	test   %al,%al
c002a5bf:	74 09                	je     c002a5ca <acquire_console+0x2e>
        console_lock_depth++; 
c002a5c1:	83 05 e8 7a 03 c0 01 	addl   $0x1,0xc0037ae8
c002a5c8:	eb 0c                	jmp    c002a5d6 <acquire_console+0x3a>
        lock_acquire (&console_lock); 
c002a5ca:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a5d1:	e8 14 87 ff ff       	call   c0022cea <lock_acquire>
}
c002a5d6:	83 c4 1c             	add    $0x1c,%esp
c002a5d9:	c3                   	ret    

c002a5da <release_console>:
{
c002a5da:	83 ec 1c             	sub    $0x1c,%esp
  if (!intr_context () && use_console_lock) 
c002a5dd:	e8 cf 74 ff ff       	call   c0021ab1 <intr_context>
c002a5e2:	84 c0                	test   %al,%al
c002a5e4:	75 28                	jne    c002a60e <release_console+0x34>
c002a5e6:	80 3d ec 7a 03 c0 00 	cmpb   $0x0,0xc0037aec
c002a5ed:	74 1f                	je     c002a60e <release_console+0x34>
      if (console_lock_depth > 0)
c002a5ef:	a1 e8 7a 03 c0       	mov    0xc0037ae8,%eax
c002a5f4:	85 c0                	test   %eax,%eax
c002a5f6:	7e 0a                	jle    c002a602 <release_console+0x28>
        console_lock_depth--;
c002a5f8:	83 e8 01             	sub    $0x1,%eax
c002a5fb:	a3 e8 7a 03 c0       	mov    %eax,0xc0037ae8
c002a600:	eb 0c                	jmp    c002a60e <release_console+0x34>
        lock_release (&console_lock); 
c002a602:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a609:	e8 a6 88 ff ff       	call   c0022eb4 <lock_release>
}
c002a60e:	83 c4 1c             	add    $0x1c,%esp
c002a611:	c3                   	ret    

c002a612 <console_init>:
{
c002a612:	83 ec 1c             	sub    $0x1c,%esp
  lock_init (&console_lock);
c002a615:	c7 04 24 00 7b 03 c0 	movl   $0xc0037b00,(%esp)
c002a61c:	e8 2c 86 ff ff       	call   c0022c4d <lock_init>
  use_console_lock = true;
c002a621:	c6 05 ec 7a 03 c0 01 	movb   $0x1,0xc0037aec
}
c002a628:	83 c4 1c             	add    $0x1c,%esp
c002a62b:	c3                   	ret    

c002a62c <console_panic>:
  use_console_lock = false;
c002a62c:	c6 05 ec 7a 03 c0 00 	movb   $0x0,0xc0037aec
c002a633:	c3                   	ret    

c002a634 <console_print_stats>:
{
c002a634:	83 ec 1c             	sub    $0x1c,%esp
  printf ("Console: %lld characters output\n", write_cnt);
c002a637:	a1 e0 7a 03 c0       	mov    0xc0037ae0,%eax
c002a63c:	8b 15 e4 7a 03 c0    	mov    0xc0037ae4,%edx
c002a642:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a646:	89 54 24 08          	mov    %edx,0x8(%esp)
c002a64a:	c7 04 24 a0 fe 02 c0 	movl   $0xc002fea0,(%esp)
c002a651:	e8 c8 c4 ff ff       	call   c0026b1e <printf>
}
c002a656:	83 c4 1c             	add    $0x1c,%esp
c002a659:	c3                   	ret    

c002a65a <vprintf>:
{
c002a65a:	83 ec 2c             	sub    $0x2c,%esp
  int char_cnt = 0;
c002a65d:	c7 44 24 1c 00 00 00 	movl   $0x0,0x1c(%esp)
c002a664:	00 
  acquire_console ();
c002a665:	e8 32 ff ff ff       	call   c002a59c <acquire_console>
  __vprintf (format, args, vprintf_helper, &char_cnt);
c002a66a:	8d 44 24 1c          	lea    0x1c(%esp),%eax
c002a66e:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002a672:	c7 44 24 08 84 a5 02 	movl   $0xc002a584,0x8(%esp)
c002a679:	c0 
c002a67a:	8b 44 24 34          	mov    0x34(%esp),%eax
c002a67e:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a682:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a686:	89 04 24             	mov    %eax,(%esp)
c002a689:	e8 d6 c4 ff ff       	call   c0026b64 <__vprintf>
  release_console ();
c002a68e:	e8 47 ff ff ff       	call   c002a5da <release_console>
}
c002a693:	8b 44 24 1c          	mov    0x1c(%esp),%eax
c002a697:	83 c4 2c             	add    $0x2c,%esp
c002a69a:	c3                   	ret    

c002a69b <puts>:
{
c002a69b:	53                   	push   %ebx
c002a69c:	83 ec 08             	sub    $0x8,%esp
c002a69f:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a6a3:	e8 f4 fe ff ff       	call   c002a59c <acquire_console>
  while (*s != '\0')
c002a6a8:	0f b6 03             	movzbl (%ebx),%eax
c002a6ab:	84 c0                	test   %al,%al
c002a6ad:	74 12                	je     c002a6c1 <puts+0x26>
    putchar_have_lock (*s++);
c002a6af:	83 c3 01             	add    $0x1,%ebx
c002a6b2:	0f b6 c0             	movzbl %al,%eax
c002a6b5:	e8 50 fe ff ff       	call   c002a50a <putchar_have_lock>
  while (*s != '\0')
c002a6ba:	0f b6 03             	movzbl (%ebx),%eax
c002a6bd:	84 c0                	test   %al,%al
c002a6bf:	75 ee                	jne    c002a6af <puts+0x14>
  putchar_have_lock ('\n');
c002a6c1:	b8 0a 00 00 00       	mov    $0xa,%eax
c002a6c6:	e8 3f fe ff ff       	call   c002a50a <putchar_have_lock>
  release_console ();
c002a6cb:	e8 0a ff ff ff       	call   c002a5da <release_console>
}
c002a6d0:	b8 00 00 00 00       	mov    $0x0,%eax
c002a6d5:	83 c4 08             	add    $0x8,%esp
c002a6d8:	5b                   	pop    %ebx
c002a6d9:	c3                   	ret    

c002a6da <putbuf>:
{
c002a6da:	56                   	push   %esi
c002a6db:	53                   	push   %ebx
c002a6dc:	83 ec 04             	sub    $0x4,%esp
c002a6df:	8b 5c 24 10          	mov    0x10(%esp),%ebx
c002a6e3:	8b 74 24 14          	mov    0x14(%esp),%esi
  acquire_console ();
c002a6e7:	e8 b0 fe ff ff       	call   c002a59c <acquire_console>
  while (n-- > 0)
c002a6ec:	85 f6                	test   %esi,%esi
c002a6ee:	74 11                	je     c002a701 <putbuf+0x27>
    putchar_have_lock (*buffer++);
c002a6f0:	83 c3 01             	add    $0x1,%ebx
c002a6f3:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
c002a6f7:	e8 0e fe ff ff       	call   c002a50a <putchar_have_lock>
  while (n-- > 0)
c002a6fc:	83 ee 01             	sub    $0x1,%esi
c002a6ff:	75 ef                	jne    c002a6f0 <putbuf+0x16>
  release_console ();
c002a701:	e8 d4 fe ff ff       	call   c002a5da <release_console>
}
c002a706:	83 c4 04             	add    $0x4,%esp
c002a709:	5b                   	pop    %ebx
c002a70a:	5e                   	pop    %esi
c002a70b:	c3                   	ret    

c002a70c <putchar>:
{
c002a70c:	53                   	push   %ebx
c002a70d:	83 ec 08             	sub    $0x8,%esp
c002a710:	8b 5c 24 10          	mov    0x10(%esp),%ebx
  acquire_console ();
c002a714:	e8 83 fe ff ff       	call   c002a59c <acquire_console>
  putchar_have_lock (c);
c002a719:	0f b6 c3             	movzbl %bl,%eax
c002a71c:	e8 e9 fd ff ff       	call   c002a50a <putchar_have_lock>
  release_console ();
c002a721:	e8 b4 fe ff ff       	call   c002a5da <release_console>
}
c002a726:	89 d8                	mov    %ebx,%eax
c002a728:	83 c4 08             	add    $0x8,%esp
c002a72b:	5b                   	pop    %ebx
c002a72c:	c3                   	ret    

c002a72d <msg>:
/* Prints FORMAT as if with printf(),
   prefixing the output by the name of the test
   and following it with a new-line character. */
void
msg (const char *format, ...) 
{
c002a72d:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) ", test_name);
c002a730:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a735:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a739:	c7 04 24 dc fe 02 c0 	movl   $0xc002fedc,(%esp)
c002a740:	e8 d9 c3 ff ff       	call   c0026b1e <printf>
  va_start (args, format);
c002a745:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a749:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a74d:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a751:	89 04 24             	mov    %eax,(%esp)
c002a754:	e8 01 ff ff ff       	call   c002a65a <vprintf>
  va_end (args);
  putchar ('\n');
c002a759:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a760:	e8 a7 ff ff ff       	call   c002a70c <putchar>
}
c002a765:	83 c4 1c             	add    $0x1c,%esp
c002a768:	c3                   	ret    

c002a769 <run_test>:
{
c002a769:	56                   	push   %esi
c002a76a:	53                   	push   %ebx
c002a76b:	83 ec 24             	sub    $0x24,%esp
c002a76e:	8b 74 24 30          	mov    0x30(%esp),%esi
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a772:	bb 60 de 02 c0       	mov    $0xc002de60,%ebx
    if (!strcmp (name, t->name))
c002a777:	8b 03                	mov    (%ebx),%eax
c002a779:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a77d:	89 34 24             	mov    %esi,(%esp)
c002a780:	e8 02 d3 ff ff       	call   c0027a87 <strcmp>
c002a785:	85 c0                	test   %eax,%eax
c002a787:	75 23                	jne    c002a7ac <run_test+0x43>
        test_name = name;
c002a789:	89 35 24 7b 03 c0    	mov    %esi,0xc0037b24
        msg ("begin");
c002a78f:	c7 04 24 e2 fe 02 c0 	movl   $0xc002fee2,(%esp)
c002a796:	e8 92 ff ff ff       	call   c002a72d <msg>
        t->function ();
c002a79b:	ff 53 04             	call   *0x4(%ebx)
        msg ("end");
c002a79e:	c7 04 24 e8 fe 02 c0 	movl   $0xc002fee8,(%esp)
c002a7a5:	e8 83 ff ff ff       	call   c002a72d <msg>
c002a7aa:	eb 33                	jmp    c002a7df <run_test+0x76>
  for (t = tests; t < tests + sizeof tests / sizeof *tests; t++)
c002a7ac:	83 c3 08             	add    $0x8,%ebx
c002a7af:	81 fb 38 df 02 c0    	cmp    $0xc002df38,%ebx
c002a7b5:	72 c0                	jb     c002a777 <run_test+0xe>
  PANIC ("no test named \"%s\"", name);
c002a7b7:	89 74 24 10          	mov    %esi,0x10(%esp)
c002a7bb:	c7 44 24 0c ec fe 02 	movl   $0xc002feec,0xc(%esp)
c002a7c2:	c0 
c002a7c3:	c7 44 24 08 45 de 02 	movl   $0xc002de45,0x8(%esp)
c002a7ca:	c0 
c002a7cb:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a7d2:	00 
c002a7d3:	c7 04 24 ff fe 02 c0 	movl   $0xc002feff,(%esp)
c002a7da:	e8 94 e1 ff ff       	call   c0028973 <debug_panic>
}
c002a7df:	83 c4 24             	add    $0x24,%esp
c002a7e2:	5b                   	pop    %ebx
c002a7e3:	5e                   	pop    %esi
c002a7e4:	c3                   	ret    

c002a7e5 <fail>:
   prefixing the output by the name of the test and FAIL:
   and following it with a new-line character,
   and then panics the kernel. */
void
fail (const char *format, ...) 
{
c002a7e5:	83 ec 1c             	sub    $0x1c,%esp
  va_list args;
  
  printf ("(%s) FAIL: ", test_name);
c002a7e8:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a7ed:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a7f1:	c7 04 24 1b ff 02 c0 	movl   $0xc002ff1b,(%esp)
c002a7f8:	e8 21 c3 ff ff       	call   c0026b1e <printf>
  va_start (args, format);
c002a7fd:	8d 44 24 24          	lea    0x24(%esp),%eax
  vprintf (format, args);
c002a801:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a805:	8b 44 24 20          	mov    0x20(%esp),%eax
c002a809:	89 04 24             	mov    %eax,(%esp)
c002a80c:	e8 49 fe ff ff       	call   c002a65a <vprintf>
  va_end (args);
  putchar ('\n');
c002a811:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002a818:	e8 ef fe ff ff       	call   c002a70c <putchar>

  PANIC ("test failed");
c002a81d:	c7 44 24 0c 27 ff 02 	movl   $0xc002ff27,0xc(%esp)
c002a824:	c0 
c002a825:	c7 44 24 08 40 de 02 	movl   $0xc002de40,0x8(%esp)
c002a82c:	c0 
c002a82d:	c7 44 24 04 5d 00 00 	movl   $0x5d,0x4(%esp)
c002a834:	00 
c002a835:	c7 04 24 ff fe 02 c0 	movl   $0xc002feff,(%esp)
c002a83c:	e8 32 e1 ff ff       	call   c0028973 <debug_panic>

c002a841 <pass>:
}

/* Prints a message indicating the current test passed. */
void
pass (void) 
{
c002a841:	83 ec 1c             	sub    $0x1c,%esp
  printf ("(%s) PASS\n", test_name);
c002a844:	a1 24 7b 03 c0       	mov    0xc0037b24,%eax
c002a849:	89 44 24 04          	mov    %eax,0x4(%esp)
c002a84d:	c7 04 24 33 ff 02 c0 	movl   $0xc002ff33,(%esp)
c002a854:	e8 c5 c2 ff ff       	call   c0026b1e <printf>
}
c002a859:	83 c4 1c             	add    $0x1c,%esp
c002a85c:	c3                   	ret    
c002a85d:	90                   	nop
c002a85e:	90                   	nop
c002a85f:	90                   	nop

c002a860 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *t_) 
{
c002a860:	55                   	push   %ebp
c002a861:	57                   	push   %edi
c002a862:	56                   	push   %esi
c002a863:	53                   	push   %ebx
c002a864:	83 ec 1c             	sub    $0x1c,%esp
  struct sleep_thread *t = t_;
  struct sleep_test *test = t->test;
c002a867:	8b 44 24 30          	mov    0x30(%esp),%eax
c002a86b:	8b 18                	mov    (%eax),%ebx
  int i;

  for (i = 1; i <= test->iterations; i++) 
c002a86d:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002a871:	7e 63                	jle    c002a8d6 <sleeper+0x76>
c002a873:	bd 01 00 00 00       	mov    $0x1,%ebp
    {
      int64_t sleep_until = test->start + i * t->duration;
      timer_sleep (sleep_until - timer_ticks ());
      lock_acquire (&test->output_lock);
c002a878:	8d 43 0c             	lea    0xc(%ebx),%eax
c002a87b:	89 44 24 0c          	mov    %eax,0xc(%esp)
      int64_t sleep_until = test->start + i * t->duration;
c002a87f:	89 e8                	mov    %ebp,%eax
c002a881:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a885:	0f af 41 08          	imul   0x8(%ecx),%eax
c002a889:	99                   	cltd   
c002a88a:	03 03                	add    (%ebx),%eax
c002a88c:	13 53 04             	adc    0x4(%ebx),%edx
c002a88f:	89 c6                	mov    %eax,%esi
c002a891:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002a893:	e8 6c 99 ff ff       	call   c0024204 <timer_ticks>
c002a898:	29 c6                	sub    %eax,%esi
c002a89a:	19 d7                	sbb    %edx,%edi
c002a89c:	89 34 24             	mov    %esi,(%esp)
c002a89f:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a8a3:	e8 a4 99 ff ff       	call   c002424c <timer_sleep>
      lock_acquire (&test->output_lock);
c002a8a8:	8b 7c 24 0c          	mov    0xc(%esp),%edi
c002a8ac:	89 3c 24             	mov    %edi,(%esp)
c002a8af:	e8 36 84 ff ff       	call   c0022cea <lock_acquire>
      *test->output_pos++ = t->id;
c002a8b4:	8b 43 30             	mov    0x30(%ebx),%eax
c002a8b7:	8d 50 04             	lea    0x4(%eax),%edx
c002a8ba:	89 53 30             	mov    %edx,0x30(%ebx)
c002a8bd:	8b 4c 24 30          	mov    0x30(%esp),%ecx
c002a8c1:	8b 51 04             	mov    0x4(%ecx),%edx
c002a8c4:	89 10                	mov    %edx,(%eax)
      lock_release (&test->output_lock);
c002a8c6:	89 3c 24             	mov    %edi,(%esp)
c002a8c9:	e8 e6 85 ff ff       	call   c0022eb4 <lock_release>
  for (i = 1; i <= test->iterations; i++) 
c002a8ce:	83 c5 01             	add    $0x1,%ebp
c002a8d1:	39 6b 08             	cmp    %ebp,0x8(%ebx)
c002a8d4:	7d a9                	jge    c002a87f <sleeper+0x1f>
    }
}
c002a8d6:	83 c4 1c             	add    $0x1c,%esp
c002a8d9:	5b                   	pop    %ebx
c002a8da:	5e                   	pop    %esi
c002a8db:	5f                   	pop    %edi
c002a8dc:	5d                   	pop    %ebp
c002a8dd:	c3                   	ret    

c002a8de <test_sleep>:
{
c002a8de:	55                   	push   %ebp
c002a8df:	57                   	push   %edi
c002a8e0:	56                   	push   %esi
c002a8e1:	53                   	push   %ebx
c002a8e2:	81 ec 8c 00 00 00    	sub    $0x8c,%esp
c002a8e8:	89 44 24 20          	mov    %eax,0x20(%esp)
c002a8ec:	89 54 24 2c          	mov    %edx,0x2c(%esp)
  ASSERT (!thread_mlfqs);
c002a8f0:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002a8f7:	74 2c                	je     c002a925 <test_sleep+0x47>
c002a8f9:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002a900:	c0 
c002a901:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002a908:	c0 
c002a909:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002a910:	c0 
c002a911:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002a918:	00 
c002a919:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002a920:	e8 4e e0 ff ff       	call   c0028973 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002a925:	8b 74 24 2c          	mov    0x2c(%esp),%esi
c002a929:	89 74 24 08          	mov    %esi,0x8(%esp)
c002a92d:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002a931:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002a935:	c7 04 24 64 01 03 c0 	movl   $0xc0030164,(%esp)
c002a93c:	e8 ec fd ff ff       	call   c002a72d <msg>
  msg ("Thread 0 sleeps 10 ticks each time,");
c002a941:	c7 04 24 90 01 03 c0 	movl   $0xc0030190,(%esp)
c002a948:	e8 e0 fd ff ff       	call   c002a72d <msg>
  msg ("thread 1 sleeps 20 ticks each time, and so on.");
c002a94d:	c7 04 24 b4 01 03 c0 	movl   $0xc00301b4,(%esp)
c002a954:	e8 d4 fd ff ff       	call   c002a72d <msg>
  msg ("If successful, product of iteration count and");
c002a959:	c7 04 24 e4 01 03 c0 	movl   $0xc00301e4,(%esp)
c002a960:	e8 c8 fd ff ff       	call   c002a72d <msg>
  msg ("sleep duration will appear in nondescending order.");
c002a965:	c7 04 24 14 02 03 c0 	movl   $0xc0030214,(%esp)
c002a96c:	e8 bc fd ff ff       	call   c002a72d <msg>
  threads = malloc (sizeof *threads * thread_cnt);
c002a971:	89 f8                	mov    %edi,%eax
c002a973:	c1 e0 04             	shl    $0x4,%eax
c002a976:	89 04 24             	mov    %eax,(%esp)
c002a979:	e8 36 8f ff ff       	call   c00238b4 <malloc>
c002a97e:	89 c3                	mov    %eax,%ebx
c002a980:	89 44 24 24          	mov    %eax,0x24(%esp)
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002a984:	8d 04 f5 00 00 00 00 	lea    0x0(,%esi,8),%eax
c002a98b:	0f af c7             	imul   %edi,%eax
c002a98e:	89 04 24             	mov    %eax,(%esp)
c002a991:	e8 1e 8f ff ff       	call   c00238b4 <malloc>
c002a996:	89 44 24 28          	mov    %eax,0x28(%esp)
  if (threads == NULL || output == NULL)
c002a99a:	85 c0                	test   %eax,%eax
c002a99c:	74 04                	je     c002a9a2 <test_sleep+0xc4>
c002a99e:	85 db                	test   %ebx,%ebx
c002a9a0:	75 24                	jne    c002a9c6 <test_sleep+0xe8>
    PANIC ("couldn't allocate memory for test");
c002a9a2:	c7 44 24 0c 48 02 03 	movl   $0xc0030248,0xc(%esp)
c002a9a9:	c0 
c002a9aa:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002a9b1:	c0 
c002a9b2:	c7 44 24 04 48 00 00 	movl   $0x48,0x4(%esp)
c002a9b9:	00 
c002a9ba:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002a9c1:	e8 ad df ff ff       	call   c0028973 <debug_panic>
  test.start = timer_ticks () + 100;
c002a9c6:	e8 39 98 ff ff       	call   c0024204 <timer_ticks>
c002a9cb:	83 c0 64             	add    $0x64,%eax
c002a9ce:	83 d2 00             	adc    $0x0,%edx
c002a9d1:	89 44 24 4c          	mov    %eax,0x4c(%esp)
c002a9d5:	89 54 24 50          	mov    %edx,0x50(%esp)
  test.iterations = iterations;
c002a9d9:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002a9dd:	89 44 24 54          	mov    %eax,0x54(%esp)
  lock_init (&test.output_lock);
c002a9e1:	8d 44 24 58          	lea    0x58(%esp),%eax
c002a9e5:	89 04 24             	mov    %eax,(%esp)
c002a9e8:	e8 60 82 ff ff       	call   c0022c4d <lock_init>
  test.output_pos = output;
c002a9ed:	8b 44 24 28          	mov    0x28(%esp),%eax
c002a9f1:	89 44 24 7c          	mov    %eax,0x7c(%esp)
  ASSERT (output != NULL);
c002a9f5:	85 c0                	test   %eax,%eax
c002a9f7:	74 1e                	je     c002aa17 <test_sleep+0x139>
c002a9f9:	8b 5c 24 24          	mov    0x24(%esp),%ebx
  for (i = 0; i < thread_cnt; i++)
c002a9fd:	be 0a 00 00 00       	mov    $0xa,%esi
c002aa02:	b8 00 00 00 00       	mov    $0x0,%eax
      snprintf (name, sizeof name, "thread %d", i);
c002aa07:	8d 6c 24 3c          	lea    0x3c(%esp),%ebp
  for (i = 0; i < thread_cnt; i++)
c002aa0b:	83 7c 24 20 00       	cmpl   $0x0,0x20(%esp)
c002aa10:	7f 31                	jg     c002aa43 <test_sleep+0x165>
c002aa12:	e9 8a 00 00 00       	jmp    c002aaa1 <test_sleep+0x1c3>
  ASSERT (output != NULL);
c002aa17:	c7 44 24 10 0a 01 03 	movl   $0xc003010a,0x10(%esp)
c002aa1e:	c0 
c002aa1f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002aa26:	c0 
c002aa27:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002aa2e:	c0 
c002aa2f:	c7 44 24 04 51 00 00 	movl   $0x51,0x4(%esp)
c002aa36:	00 
c002aa37:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002aa3e:	e8 30 df ff ff       	call   c0028973 <debug_panic>
      t->test = &test;
c002aa43:	8d 4c 24 4c          	lea    0x4c(%esp),%ecx
c002aa47:	89 0b                	mov    %ecx,(%ebx)
      t->id = i;
c002aa49:	89 43 04             	mov    %eax,0x4(%ebx)
      t->duration = (i + 1) * 10;
c002aa4c:	8d 78 01             	lea    0x1(%eax),%edi
c002aa4f:	89 73 08             	mov    %esi,0x8(%ebx)
      t->iterations = 0;
c002aa52:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
      snprintf (name, sizeof name, "thread %d", i);
c002aa59:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002aa5d:	c7 44 24 08 19 01 03 	movl   $0xc0030119,0x8(%esp)
c002aa64:	c0 
c002aa65:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002aa6c:	00 
c002aa6d:	89 2c 24             	mov    %ebp,(%esp)
c002aa70:	e8 aa c7 ff ff       	call   c002721f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, t);
c002aa75:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002aa79:	c7 44 24 08 60 a8 02 	movl   $0xc002a860,0x8(%esp)
c002aa80:	c0 
c002aa81:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002aa88:	00 
c002aa89:	89 2c 24             	mov    %ebp,(%esp)
c002aa8c:	e8 38 69 ff ff       	call   c00213c9 <thread_create>
c002aa91:	83 c3 10             	add    $0x10,%ebx
c002aa94:	83 c6 0a             	add    $0xa,%esi
  for (i = 0; i < thread_cnt; i++)
c002aa97:	3b 7c 24 20          	cmp    0x20(%esp),%edi
c002aa9b:	74 04                	je     c002aaa1 <test_sleep+0x1c3>
c002aa9d:	89 f8                	mov    %edi,%eax
c002aa9f:	eb a2                	jmp    c002aa43 <test_sleep+0x165>
  timer_sleep (100 + thread_cnt * iterations * 10 + 100);
c002aaa1:	8b 7c 24 20          	mov    0x20(%esp),%edi
c002aaa5:	89 f8                	mov    %edi,%eax
c002aaa7:	0f af 44 24 2c       	imul   0x2c(%esp),%eax
c002aaac:	8d 04 80             	lea    (%eax,%eax,4),%eax
c002aaaf:	8d 84 00 c8 00 00 00 	lea    0xc8(%eax,%eax,1),%eax
c002aab6:	89 04 24             	mov    %eax,(%esp)
c002aab9:	89 c1                	mov    %eax,%ecx
c002aabb:	c1 f9 1f             	sar    $0x1f,%ecx
c002aabe:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c002aac2:	e8 85 97 ff ff       	call   c002424c <timer_sleep>
  lock_acquire (&test.output_lock);
c002aac7:	8d 44 24 58          	lea    0x58(%esp),%eax
c002aacb:	89 04 24             	mov    %eax,(%esp)
c002aace:	e8 17 82 ff ff       	call   c0022cea <lock_acquire>
  for (op = output; op < test.output_pos; op++) 
c002aad3:	8b 44 24 28          	mov    0x28(%esp),%eax
c002aad7:	3b 44 24 7c          	cmp    0x7c(%esp),%eax
c002aadb:	0f 83 bb 00 00 00    	jae    c002ab9c <test_sleep+0x2be>
      ASSERT (*op >= 0 && *op < thread_cnt);
c002aae1:	8b 18                	mov    (%eax),%ebx
c002aae3:	85 db                	test   %ebx,%ebx
c002aae5:	78 1b                	js     c002ab02 <test_sleep+0x224>
c002aae7:	39 df                	cmp    %ebx,%edi
c002aae9:	7f 43                	jg     c002ab2e <test_sleep+0x250>
c002aaeb:	90                   	nop
c002aaec:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
c002aaf0:	eb 10                	jmp    c002ab02 <test_sleep+0x224>
c002aaf2:	8b 1f                	mov    (%edi),%ebx
c002aaf4:	85 db                	test   %ebx,%ebx
c002aaf6:	78 0a                	js     c002ab02 <test_sleep+0x224>
c002aaf8:	39 5c 24 20          	cmp    %ebx,0x20(%esp)
c002aafc:	7e 04                	jle    c002ab02 <test_sleep+0x224>
c002aafe:	89 f5                	mov    %esi,%ebp
c002ab00:	eb 35                	jmp    c002ab37 <test_sleep+0x259>
c002ab02:	c7 44 24 10 23 01 03 	movl   $0xc0030123,0x10(%esp)
c002ab09:	c0 
c002ab0a:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ab11:	c0 
c002ab12:	c7 44 24 08 38 df 02 	movl   $0xc002df38,0x8(%esp)
c002ab19:	c0 
c002ab1a:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
c002ab21:	00 
c002ab22:	c7 04 24 40 01 03 c0 	movl   $0xc0030140,(%esp)
c002ab29:	e8 45 de ff ff       	call   c0028973 <debug_panic>
  for (op = output; op < test.output_pos; op++) 
c002ab2e:	8b 7c 24 28          	mov    0x28(%esp),%edi
  product = 0;
c002ab32:	bd 00 00 00 00       	mov    $0x0,%ebp
      t = threads + *op;
c002ab37:	c1 e3 04             	shl    $0x4,%ebx
c002ab3a:	03 5c 24 24          	add    0x24(%esp),%ebx
      new_prod = ++t->iterations * t->duration;
c002ab3e:	8b 43 0c             	mov    0xc(%ebx),%eax
c002ab41:	83 c0 01             	add    $0x1,%eax
c002ab44:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ab47:	8b 53 08             	mov    0x8(%ebx),%edx
c002ab4a:	89 c6                	mov    %eax,%esi
c002ab4c:	0f af f2             	imul   %edx,%esi
      msg ("thread %d: duration=%d, iteration=%d, product=%d",
c002ab4f:	89 74 24 10          	mov    %esi,0x10(%esp)
c002ab53:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ab57:	89 54 24 08          	mov    %edx,0x8(%esp)
c002ab5b:	8b 43 04             	mov    0x4(%ebx),%eax
c002ab5e:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ab62:	c7 04 24 6c 02 03 c0 	movl   $0xc003026c,(%esp)
c002ab69:	e8 bf fb ff ff       	call   c002a72d <msg>
      if (new_prod >= product)
c002ab6e:	39 ee                	cmp    %ebp,%esi
c002ab70:	7d 1d                	jge    c002ab8f <test_sleep+0x2b1>
        fail ("thread %d woke up out of order (%d > %d)!",
c002ab72:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ab76:	89 6c 24 08          	mov    %ebp,0x8(%esp)
c002ab7a:	8b 43 04             	mov    0x4(%ebx),%eax
c002ab7d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ab81:	c7 04 24 a0 02 03 c0 	movl   $0xc00302a0,(%esp)
c002ab88:	e8 58 fc ff ff       	call   c002a7e5 <fail>
c002ab8d:	89 ee                	mov    %ebp,%esi
  for (op = output; op < test.output_pos; op++) 
c002ab8f:	83 c7 04             	add    $0x4,%edi
c002ab92:	39 7c 24 7c          	cmp    %edi,0x7c(%esp)
c002ab96:	0f 87 56 ff ff ff    	ja     c002aaf2 <test_sleep+0x214>
  for (i = 0; i < thread_cnt; i++)
c002ab9c:	8b 6c 24 20          	mov    0x20(%esp),%ebp
c002aba0:	85 ed                	test   %ebp,%ebp
c002aba2:	7e 36                	jle    c002abda <test_sleep+0x2fc>
c002aba4:	8b 74 24 24          	mov    0x24(%esp),%esi
c002aba8:	bb 00 00 00 00       	mov    $0x0,%ebx
c002abad:	8b 7c 24 2c          	mov    0x2c(%esp),%edi
    if (threads[i].iterations != iterations)
c002abb1:	8b 46 0c             	mov    0xc(%esi),%eax
c002abb4:	39 f8                	cmp    %edi,%eax
c002abb6:	74 18                	je     c002abd0 <test_sleep+0x2f2>
      fail ("thread %d woke up %d times instead of %d",
c002abb8:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002abbc:	89 44 24 08          	mov    %eax,0x8(%esp)
c002abc0:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002abc4:	c7 04 24 cc 02 03 c0 	movl   $0xc00302cc,(%esp)
c002abcb:	e8 15 fc ff ff       	call   c002a7e5 <fail>
  for (i = 0; i < thread_cnt; i++)
c002abd0:	83 c3 01             	add    $0x1,%ebx
c002abd3:	83 c6 10             	add    $0x10,%esi
c002abd6:	39 eb                	cmp    %ebp,%ebx
c002abd8:	75 d7                	jne    c002abb1 <test_sleep+0x2d3>
  lock_release (&test.output_lock);
c002abda:	8d 44 24 58          	lea    0x58(%esp),%eax
c002abde:	89 04 24             	mov    %eax,(%esp)
c002abe1:	e8 ce 82 ff ff       	call   c0022eb4 <lock_release>
  free (output);
c002abe6:	8b 44 24 28          	mov    0x28(%esp),%eax
c002abea:	89 04 24             	mov    %eax,(%esp)
c002abed:	e8 49 8e ff ff       	call   c0023a3b <free>
  free (threads);
c002abf2:	8b 44 24 24          	mov    0x24(%esp),%eax
c002abf6:	89 04 24             	mov    %eax,(%esp)
c002abf9:	e8 3d 8e ff ff       	call   c0023a3b <free>
}
c002abfe:	81 c4 8c 00 00 00    	add    $0x8c,%esp
c002ac04:	5b                   	pop    %ebx
c002ac05:	5e                   	pop    %esi
c002ac06:	5f                   	pop    %edi
c002ac07:	5d                   	pop    %ebp
c002ac08:	c3                   	ret    

c002ac09 <test_alarm_single>:
{
c002ac09:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 1);
c002ac0c:	ba 01 00 00 00       	mov    $0x1,%edx
c002ac11:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac16:	e8 c3 fc ff ff       	call   c002a8de <test_sleep>
}
c002ac1b:	83 c4 0c             	add    $0xc,%esp
c002ac1e:	c3                   	ret    

c002ac1f <test_alarm_multiple>:
{
c002ac1f:	83 ec 0c             	sub    $0xc,%esp
  test_sleep (5, 7);
c002ac22:	ba 07 00 00 00       	mov    $0x7,%edx
c002ac27:	b8 05 00 00 00       	mov    $0x5,%eax
c002ac2c:	e8 ad fc ff ff       	call   c002a8de <test_sleep>
}
c002ac31:	83 c4 0c             	add    $0xc,%esp
c002ac34:	c3                   	ret    

c002ac35 <sleeper>:
}

/* Sleeper thread. */
static void
sleeper (void *test_) 
{
c002ac35:	55                   	push   %ebp
c002ac36:	57                   	push   %edi
c002ac37:	56                   	push   %esi
c002ac38:	53                   	push   %ebx
c002ac39:	83 ec 1c             	sub    $0x1c,%esp
c002ac3c:	8b 5c 24 30          	mov    0x30(%esp),%ebx
  struct sleep_test *test = test_;
  int i;

  /* Make sure we're at the beginning of a timer tick. */
  timer_sleep (1);
c002ac40:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c002ac47:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002ac4e:	00 
c002ac4f:	e8 f8 95 ff ff       	call   c002424c <timer_sleep>

  for (i = 1; i <= test->iterations; i++) 
c002ac54:	83 7b 08 00          	cmpl   $0x0,0x8(%ebx)
c002ac58:	7e 56                	jle    c002acb0 <sleeper+0x7b>
c002ac5a:	bd 0a 00 00 00       	mov    $0xa,%ebp
c002ac5f:	c7 44 24 0c 01 00 00 	movl   $0x1,0xc(%esp)
c002ac66:	00 
    {
      int64_t sleep_until = test->start + i * 10;
c002ac67:	89 ee                	mov    %ebp,%esi
c002ac69:	89 ef                	mov    %ebp,%edi
c002ac6b:	c1 ff 1f             	sar    $0x1f,%edi
c002ac6e:	03 33                	add    (%ebx),%esi
c002ac70:	13 7b 04             	adc    0x4(%ebx),%edi
      timer_sleep (sleep_until - timer_ticks ());
c002ac73:	e8 8c 95 ff ff       	call   c0024204 <timer_ticks>
c002ac78:	29 c6                	sub    %eax,%esi
c002ac7a:	19 d7                	sbb    %edx,%edi
c002ac7c:	89 34 24             	mov    %esi,(%esp)
c002ac7f:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ac83:	e8 c4 95 ff ff       	call   c002424c <timer_sleep>
      *test->output_pos++ = timer_ticks () - test->start;
c002ac88:	8b 73 0c             	mov    0xc(%ebx),%esi
c002ac8b:	8d 46 04             	lea    0x4(%esi),%eax
c002ac8e:	89 43 0c             	mov    %eax,0xc(%ebx)
c002ac91:	e8 6e 95 ff ff       	call   c0024204 <timer_ticks>
c002ac96:	2b 03                	sub    (%ebx),%eax
c002ac98:	89 06                	mov    %eax,(%esi)
      thread_yield ();
c002ac9a:	e8 88 66 ff ff       	call   c0021327 <thread_yield>
  for (i = 1; i <= test->iterations; i++) 
c002ac9f:	83 44 24 0c 01       	addl   $0x1,0xc(%esp)
c002aca4:	83 c5 0a             	add    $0xa,%ebp
c002aca7:	8b 44 24 0c          	mov    0xc(%esp),%eax
c002acab:	39 43 08             	cmp    %eax,0x8(%ebx)
c002acae:	7d b7                	jge    c002ac67 <sleeper+0x32>
    }
}
c002acb0:	83 c4 1c             	add    $0x1c,%esp
c002acb3:	5b                   	pop    %ebx
c002acb4:	5e                   	pop    %esi
c002acb5:	5f                   	pop    %edi
c002acb6:	5d                   	pop    %ebp
c002acb7:	c3                   	ret    

c002acb8 <test_alarm_simultaneous>:
{
c002acb8:	55                   	push   %ebp
c002acb9:	57                   	push   %edi
c002acba:	56                   	push   %esi
c002acbb:	53                   	push   %ebx
c002acbc:	83 ec 4c             	sub    $0x4c,%esp
  ASSERT (!thread_mlfqs);
c002acbf:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002acc6:	74 2c                	je     c002acf4 <test_alarm_simultaneous+0x3c>
c002acc8:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002accf:	c0 
c002acd0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002acd7:	c0 
c002acd8:	c7 44 24 08 43 df 02 	movl   $0xc002df43,0x8(%esp)
c002acdf:	c0 
c002ace0:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002ace7:	00 
c002ace8:	c7 04 24 f8 02 03 c0 	movl   $0xc00302f8,(%esp)
c002acef:	e8 7f dc ff ff       	call   c0028973 <debug_panic>
  msg ("Creating %d threads to sleep %d times each.", thread_cnt, iterations);
c002acf4:	c7 44 24 08 05 00 00 	movl   $0x5,0x8(%esp)
c002acfb:	00 
c002acfc:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c002ad03:	00 
c002ad04:	c7 04 24 64 01 03 c0 	movl   $0xc0030164,(%esp)
c002ad0b:	e8 1d fa ff ff       	call   c002a72d <msg>
  msg ("Each thread sleeps 10 ticks each time.");
c002ad10:	c7 04 24 24 03 03 c0 	movl   $0xc0030324,(%esp)
c002ad17:	e8 11 fa ff ff       	call   c002a72d <msg>
  msg ("Within an iteration, all threads should wake up on the same tick.");
c002ad1c:	c7 04 24 4c 03 03 c0 	movl   $0xc003034c,(%esp)
c002ad23:	e8 05 fa ff ff       	call   c002a72d <msg>
  output = malloc (sizeof *output * iterations * thread_cnt * 2);
c002ad28:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
c002ad2f:	e8 80 8b ff ff       	call   c00238b4 <malloc>
c002ad34:	89 c3                	mov    %eax,%ebx
  if (output == NULL)
c002ad36:	85 c0                	test   %eax,%eax
c002ad38:	75 24                	jne    c002ad5e <test_alarm_simultaneous+0xa6>
    PANIC ("couldn't allocate memory for test");
c002ad3a:	c7 44 24 0c 48 02 03 	movl   $0xc0030248,0xc(%esp)
c002ad41:	c0 
c002ad42:	c7 44 24 08 43 df 02 	movl   $0xc002df43,0x8(%esp)
c002ad49:	c0 
c002ad4a:	c7 44 24 04 31 00 00 	movl   $0x31,0x4(%esp)
c002ad51:	00 
c002ad52:	c7 04 24 f8 02 03 c0 	movl   $0xc00302f8,(%esp)
c002ad59:	e8 15 dc ff ff       	call   c0028973 <debug_panic>
  test.start = timer_ticks () + 100;
c002ad5e:	e8 a1 94 ff ff       	call   c0024204 <timer_ticks>
c002ad63:	83 c0 64             	add    $0x64,%eax
c002ad66:	83 d2 00             	adc    $0x0,%edx
c002ad69:	89 44 24 20          	mov    %eax,0x20(%esp)
c002ad6d:	89 54 24 24          	mov    %edx,0x24(%esp)
  test.iterations = iterations;
c002ad71:	c7 44 24 28 05 00 00 	movl   $0x5,0x28(%esp)
c002ad78:	00 
  test.output_pos = output;
c002ad79:	89 5c 24 2c          	mov    %ebx,0x2c(%esp)
c002ad7d:	be 00 00 00 00       	mov    $0x0,%esi
      snprintf (name, sizeof name, "thread %d", i);
c002ad82:	8d 7c 24 30          	lea    0x30(%esp),%edi
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002ad86:	8d 6c 24 20          	lea    0x20(%esp),%ebp
      snprintf (name, sizeof name, "thread %d", i);
c002ad8a:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ad8e:	c7 44 24 08 19 01 03 	movl   $0xc0030119,0x8(%esp)
c002ad95:	c0 
c002ad96:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002ad9d:	00 
c002ad9e:	89 3c 24             	mov    %edi,(%esp)
c002ada1:	e8 79 c4 ff ff       	call   c002721f <snprintf>
      thread_create (name, PRI_DEFAULT, sleeper, &test);
c002ada6:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
c002adaa:	c7 44 24 08 35 ac 02 	movl   $0xc002ac35,0x8(%esp)
c002adb1:	c0 
c002adb2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002adb9:	00 
c002adba:	89 3c 24             	mov    %edi,(%esp)
c002adbd:	e8 07 66 ff ff       	call   c00213c9 <thread_create>
  for (i = 0; i < thread_cnt; i++)
c002adc2:	83 c6 01             	add    $0x1,%esi
c002adc5:	83 fe 03             	cmp    $0x3,%esi
c002adc8:	75 c0                	jne    c002ad8a <test_alarm_simultaneous+0xd2>
  timer_sleep (100 + iterations * 10 + 100);
c002adca:	c7 04 24 fa 00 00 00 	movl   $0xfa,(%esp)
c002add1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002add8:	00 
c002add9:	e8 6e 94 ff ff       	call   c002424c <timer_sleep>
  msg ("iteration 0, thread 0: woke up after %d ticks", output[0]);
c002adde:	8b 03                	mov    (%ebx),%eax
c002ade0:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ade4:	c7 04 24 90 03 03 c0 	movl   $0xc0030390,(%esp)
c002adeb:	e8 3d f9 ff ff       	call   c002a72d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002adf0:	89 df                	mov    %ebx,%edi
c002adf2:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002adf6:	29 d8                	sub    %ebx,%eax
c002adf8:	83 f8 07             	cmp    $0x7,%eax
c002adfb:	7e 4a                	jle    c002ae47 <test_alarm_simultaneous+0x18f>
c002adfd:	66 be 01 00          	mov    $0x1,%si
    msg ("iteration %d, thread %d: woke up %d ticks later",
c002ae01:	bd 56 55 55 55       	mov    $0x55555556,%ebp
c002ae06:	8b 04 b3             	mov    (%ebx,%esi,4),%eax
c002ae09:	2b 44 b3 fc          	sub    -0x4(%ebx,%esi,4),%eax
c002ae0d:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002ae11:	89 f0                	mov    %esi,%eax
c002ae13:	f7 ed                	imul   %ebp
c002ae15:	89 f0                	mov    %esi,%eax
c002ae17:	c1 f8 1f             	sar    $0x1f,%eax
c002ae1a:	29 c2                	sub    %eax,%edx
c002ae1c:	8d 04 52             	lea    (%edx,%edx,2),%eax
c002ae1f:	89 f1                	mov    %esi,%ecx
c002ae21:	29 c1                	sub    %eax,%ecx
c002ae23:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002ae27:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ae2b:	c7 04 24 c0 03 03 c0 	movl   $0xc00303c0,(%esp)
c002ae32:	e8 f6 f8 ff ff       	call   c002a72d <msg>
  for (i = 1; i < test.output_pos - output; i++) 
c002ae37:	83 c6 01             	add    $0x1,%esi
c002ae3a:	8b 44 24 2c          	mov    0x2c(%esp),%eax
c002ae3e:	29 f8                	sub    %edi,%eax
c002ae40:	c1 f8 02             	sar    $0x2,%eax
c002ae43:	39 c6                	cmp    %eax,%esi
c002ae45:	7c bf                	jl     c002ae06 <test_alarm_simultaneous+0x14e>
  free (output);
c002ae47:	89 1c 24             	mov    %ebx,(%esp)
c002ae4a:	e8 ec 8b ff ff       	call   c0023a3b <free>
}
c002ae4f:	83 c4 4c             	add    $0x4c,%esp
c002ae52:	5b                   	pop    %ebx
c002ae53:	5e                   	pop    %esi
c002ae54:	5f                   	pop    %edi
c002ae55:	5d                   	pop    %ebp
c002ae56:	c3                   	ret    

c002ae57 <alarm_priority_thread>:
    sema_down (&wait_sema);
}

static void
alarm_priority_thread (void *aux UNUSED) 
{
c002ae57:	57                   	push   %edi
c002ae58:	56                   	push   %esi
c002ae59:	83 ec 14             	sub    $0x14,%esp
  /* Busy-wait until the current time changes. */
  int64_t start_time = timer_ticks ();
c002ae5c:	e8 a3 93 ff ff       	call   c0024204 <timer_ticks>
c002ae61:	89 c6                	mov    %eax,%esi
c002ae63:	89 d7                	mov    %edx,%edi
  while (timer_elapsed (start_time) == 0)
c002ae65:	89 34 24             	mov    %esi,(%esp)
c002ae68:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ae6c:	e8 bf 93 ff ff       	call   c0024230 <timer_elapsed>
c002ae71:	09 c2                	or     %eax,%edx
c002ae73:	74 f0                	je     c002ae65 <alarm_priority_thread+0xe>
    continue;

  /* Now we know we're at the very beginning of a timer tick, so
     we can call timer_sleep() without worrying about races
     between checking the time and a timer interrupt. */
  timer_sleep (wake_time - timer_ticks ());
c002ae75:	8b 35 40 7b 03 c0    	mov    0xc0037b40,%esi
c002ae7b:	8b 3d 44 7b 03 c0    	mov    0xc0037b44,%edi
c002ae81:	e8 7e 93 ff ff       	call   c0024204 <timer_ticks>
c002ae86:	29 c6                	sub    %eax,%esi
c002ae88:	19 d7                	sbb    %edx,%edi
c002ae8a:	89 34 24             	mov    %esi,(%esp)
c002ae8d:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002ae91:	e8 b6 93 ff ff       	call   c002424c <timer_sleep>

  /* Print a message on wake-up. */
  msg ("Thread %s woke up.", thread_name ());
c002ae96:	e8 cc 5e ff ff       	call   c0020d67 <thread_name>
c002ae9b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002ae9f:	c7 04 24 f0 03 03 c0 	movl   $0xc00303f0,(%esp)
c002aea6:	e8 82 f8 ff ff       	call   c002a72d <msg>

  sema_up (&wait_sema);
c002aeab:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002aeb2:	e8 20 7c ff ff       	call   c0022ad7 <sema_up>
}
c002aeb7:	83 c4 14             	add    $0x14,%esp
c002aeba:	5e                   	pop    %esi
c002aebb:	5f                   	pop    %edi
c002aebc:	c3                   	ret    

c002aebd <test_alarm_priority>:
{
c002aebd:	55                   	push   %ebp
c002aebe:	57                   	push   %edi
c002aebf:	56                   	push   %esi
c002aec0:	53                   	push   %ebx
c002aec1:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002aec4:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002aecb:	74 2c                	je     c002aef9 <test_alarm_priority+0x3c>
c002aecd:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002aed4:	c0 
c002aed5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002aedc:	c0 
c002aedd:	c7 44 24 08 4e df 02 	movl   $0xc002df4e,0x8(%esp)
c002aee4:	c0 
c002aee5:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002aeec:	00 
c002aeed:	c7 04 24 10 04 03 c0 	movl   $0xc0030410,(%esp)
c002aef4:	e8 7a da ff ff       	call   c0028973 <debug_panic>
  wake_time = timer_ticks () + 5 * TIMER_FREQ;
c002aef9:	e8 06 93 ff ff       	call   c0024204 <timer_ticks>
c002aefe:	05 f4 01 00 00       	add    $0x1f4,%eax
c002af03:	83 d2 00             	adc    $0x0,%edx
c002af06:	a3 40 7b 03 c0       	mov    %eax,0xc0037b40
c002af0b:	89 15 44 7b 03 c0    	mov    %edx,0xc0037b44
  sema_init (&wait_sema, 0);
c002af11:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002af18:	00 
c002af19:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002af20:	e8 51 7a ff ff       	call   c0022976 <sema_init>
c002af25:	bb 05 00 00 00       	mov    $0x5,%ebx
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af2a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002af2f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 5) % 10 - 1;
c002af33:	89 d8                	mov    %ebx,%eax
c002af35:	f7 ed                	imul   %ebp
c002af37:	c1 fa 02             	sar    $0x2,%edx
c002af3a:	89 d8                	mov    %ebx,%eax
c002af3c:	c1 f8 1f             	sar    $0x1f,%eax
c002af3f:	29 c2                	sub    %eax,%edx
c002af41:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002af44:	01 c0                	add    %eax,%eax
c002af46:	29 d8                	sub    %ebx,%eax
c002af48:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002af4b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002af4f:	c7 44 24 08 03 04 03 	movl   $0xc0030403,0x8(%esp)
c002af56:	c0 
c002af57:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002af5e:	00 
c002af5f:	89 3c 24             	mov    %edi,(%esp)
c002af62:	e8 b8 c2 ff ff       	call   c002721f <snprintf>
      thread_create (name, priority, alarm_priority_thread, NULL);
c002af67:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002af6e:	00 
c002af6f:	c7 44 24 08 57 ae 02 	movl   $0xc002ae57,0x8(%esp)
c002af76:	c0 
c002af77:	89 74 24 04          	mov    %esi,0x4(%esp)
c002af7b:	89 3c 24             	mov    %edi,(%esp)
c002af7e:	e8 46 64 ff ff       	call   c00213c9 <thread_create>
c002af83:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002af86:	83 fb 0f             	cmp    $0xf,%ebx
c002af89:	75 a8                	jne    c002af33 <test_alarm_priority+0x76>
  thread_set_priority (PRI_MIN);
c002af8b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002af92:	e8 a0 65 ff ff       	call   c0021537 <thread_set_priority>
c002af97:	b3 0a                	mov    $0xa,%bl
    sema_down (&wait_sema);
c002af99:	c7 04 24 28 7b 03 c0 	movl   $0xc0037b28,(%esp)
c002afa0:	e8 1d 7a ff ff       	call   c00229c2 <sema_down>
  for (i = 0; i < 10; i++)
c002afa5:	83 eb 01             	sub    $0x1,%ebx
c002afa8:	75 ef                	jne    c002af99 <test_alarm_priority+0xdc>
}
c002afaa:	83 c4 3c             	add    $0x3c,%esp
c002afad:	5b                   	pop    %ebx
c002afae:	5e                   	pop    %esi
c002afaf:	5f                   	pop    %edi
c002afb0:	5d                   	pop    %ebp
c002afb1:	c3                   	ret    

c002afb2 <test_alarm_zero>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_zero (void) 
{
c002afb2:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (0);
c002afb5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002afbc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002afc3:	00 
c002afc4:	e8 83 92 ff ff       	call   c002424c <timer_sleep>
  pass ();
c002afc9:	e8 73 f8 ff ff       	call   c002a841 <pass>
}
c002afce:	83 c4 1c             	add    $0x1c,%esp
c002afd1:	c3                   	ret    

c002afd2 <test_alarm_negative>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_alarm_negative (void) 
{
c002afd2:	83 ec 1c             	sub    $0x1c,%esp
  timer_sleep (-100);
c002afd5:	c7 04 24 9c ff ff ff 	movl   $0xffffff9c,(%esp)
c002afdc:	c7 44 24 04 ff ff ff 	movl   $0xffffffff,0x4(%esp)
c002afe3:	ff 
c002afe4:	e8 63 92 ff ff       	call   c002424c <timer_sleep>
  pass ();
c002afe9:	e8 53 f8 ff ff       	call   c002a841 <pass>
}
c002afee:	83 c4 1c             	add    $0x1c,%esp
c002aff1:	c3                   	ret    

c002aff2 <changing_thread>:
  msg ("Thread 2 should have just exited.");
}

static void
changing_thread (void *aux UNUSED) 
{
c002aff2:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread 2 now lowering priority.");
c002aff5:	c7 04 24 38 04 03 c0 	movl   $0xc0030438,(%esp)
c002affc:	e8 2c f7 ff ff       	call   c002a72d <msg>
  thread_set_priority (PRI_DEFAULT - 1);
c002b001:	c7 04 24 1e 00 00 00 	movl   $0x1e,(%esp)
c002b008:	e8 2a 65 ff ff       	call   c0021537 <thread_set_priority>
  msg ("Thread 2 exiting.");
c002b00d:	c7 04 24 f6 04 03 c0 	movl   $0xc00304f6,(%esp)
c002b014:	e8 14 f7 ff ff       	call   c002a72d <msg>
}
c002b019:	83 c4 1c             	add    $0x1c,%esp
c002b01c:	c3                   	ret    

c002b01d <test_priority_change>:
{
c002b01d:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002b020:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b027:	74 2c                	je     c002b055 <test_priority_change+0x38>
c002b029:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b030:	c0 
c002b031:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b038:	c0 
c002b039:	c7 44 24 08 62 df 02 	movl   $0xc002df62,0x8(%esp)
c002b040:	c0 
c002b041:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002b048:	00 
c002b049:	c7 04 24 58 04 03 c0 	movl   $0xc0030458,(%esp)
c002b050:	e8 1e d9 ff ff       	call   c0028973 <debug_panic>
  msg ("Creating a high-priority thread 2.");
c002b055:	c7 04 24 80 04 03 c0 	movl   $0xc0030480,(%esp)
c002b05c:	e8 cc f6 ff ff       	call   c002a72d <msg>
  thread_create ("thread 2", PRI_DEFAULT + 1, changing_thread, NULL);
c002b061:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b068:	00 
c002b069:	c7 44 24 08 f2 af 02 	movl   $0xc002aff2,0x8(%esp)
c002b070:	c0 
c002b071:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b078:	00 
c002b079:	c7 04 24 08 05 03 c0 	movl   $0xc0030508,(%esp)
c002b080:	e8 44 63 ff ff       	call   c00213c9 <thread_create>
  msg ("Thread 2 should have just lowered its priority.");
c002b085:	c7 04 24 a4 04 03 c0 	movl   $0xc00304a4,(%esp)
c002b08c:	e8 9c f6 ff ff       	call   c002a72d <msg>
  thread_set_priority (PRI_DEFAULT - 2);
c002b091:	c7 04 24 1d 00 00 00 	movl   $0x1d,(%esp)
c002b098:	e8 9a 64 ff ff       	call   c0021537 <thread_set_priority>
  msg ("Thread 2 should have just exited.");
c002b09d:	c7 04 24 d4 04 03 c0 	movl   $0xc00304d4,(%esp)
c002b0a4:	e8 84 f6 ff ff       	call   c002a72d <msg>
}
c002b0a9:	83 c4 2c             	add    $0x2c,%esp
c002b0ac:	c3                   	ret    

c002b0ad <acquire2_thread_func>:
  msg ("acquire1: done");
}

static void
acquire2_thread_func (void *lock_) 
{
c002b0ad:	53                   	push   %ebx
c002b0ae:	83 ec 18             	sub    $0x18,%esp
c002b0b1:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b0b5:	89 1c 24             	mov    %ebx,(%esp)
c002b0b8:	e8 2d 7c ff ff       	call   c0022cea <lock_acquire>
  msg ("acquire2: got the lock");
c002b0bd:	c7 04 24 11 05 03 c0 	movl   $0xc0030511,(%esp)
c002b0c4:	e8 64 f6 ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002b0c9:	89 1c 24             	mov    %ebx,(%esp)
c002b0cc:	e8 e3 7d ff ff       	call   c0022eb4 <lock_release>
  msg ("acquire2: done");
c002b0d1:	c7 04 24 28 05 03 c0 	movl   $0xc0030528,(%esp)
c002b0d8:	e8 50 f6 ff ff       	call   c002a72d <msg>
}
c002b0dd:	83 c4 18             	add    $0x18,%esp
c002b0e0:	5b                   	pop    %ebx
c002b0e1:	c3                   	ret    

c002b0e2 <acquire1_thread_func>:
{
c002b0e2:	53                   	push   %ebx
c002b0e3:	83 ec 18             	sub    $0x18,%esp
c002b0e6:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b0ea:	89 1c 24             	mov    %ebx,(%esp)
c002b0ed:	e8 f8 7b ff ff       	call   c0022cea <lock_acquire>
  msg ("acquire1: got the lock");
c002b0f2:	c7 04 24 37 05 03 c0 	movl   $0xc0030537,(%esp)
c002b0f9:	e8 2f f6 ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002b0fe:	89 1c 24             	mov    %ebx,(%esp)
c002b101:	e8 ae 7d ff ff       	call   c0022eb4 <lock_release>
  msg ("acquire1: done");
c002b106:	c7 04 24 4e 05 03 c0 	movl   $0xc003054e,(%esp)
c002b10d:	e8 1b f6 ff ff       	call   c002a72d <msg>
}
c002b112:	83 c4 18             	add    $0x18,%esp
c002b115:	5b                   	pop    %ebx
c002b116:	c3                   	ret    

c002b117 <test_priority_donate_one>:
{
c002b117:	53                   	push   %ebx
c002b118:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002b11b:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b122:	74 2c                	je     c002b150 <test_priority_donate_one+0x39>
c002b124:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b12b:	c0 
c002b12c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b133:	c0 
c002b134:	c7 44 24 08 77 df 02 	movl   $0xc002df77,0x8(%esp)
c002b13b:	c0 
c002b13c:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b143:	00 
c002b144:	c7 04 24 70 05 03 c0 	movl   $0xc0030570,(%esp)
c002b14b:	e8 23 d8 ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b150:	e8 af 5c ff ff       	call   c0020e04 <thread_get_priority>
c002b155:	83 f8 1f             	cmp    $0x1f,%eax
c002b158:	74 2c                	je     c002b186 <test_priority_donate_one+0x6f>
c002b15a:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b161:	c0 
c002b162:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b169:	c0 
c002b16a:	c7 44 24 08 77 df 02 	movl   $0xc002df77,0x8(%esp)
c002b171:	c0 
c002b172:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b179:	00 
c002b17a:	c7 04 24 70 05 03 c0 	movl   $0xc0030570,(%esp)
c002b181:	e8 ed d7 ff ff       	call   c0028973 <debug_panic>
  lock_init (&lock);
c002b186:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002b18a:	89 1c 24             	mov    %ebx,(%esp)
c002b18d:	e8 bb 7a ff ff       	call   c0022c4d <lock_init>
  lock_acquire (&lock);
c002b192:	89 1c 24             	mov    %ebx,(%esp)
c002b195:	e8 50 7b ff ff       	call   c0022cea <lock_acquire>
  thread_create ("acquire1", PRI_DEFAULT + 1, acquire1_thread_func, &lock);
c002b19a:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b19e:	c7 44 24 08 e2 b0 02 	movl   $0xc002b0e2,0x8(%esp)
c002b1a5:	c0 
c002b1a6:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b1ad:	00 
c002b1ae:	c7 04 24 5d 05 03 c0 	movl   $0xc003055d,(%esp)
c002b1b5:	e8 0f 62 ff ff       	call   c00213c9 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b1ba:	e8 45 5c ff ff       	call   c0020e04 <thread_get_priority>
c002b1bf:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b1c3:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b1ca:	00 
c002b1cb:	c7 04 24 c4 05 03 c0 	movl   $0xc00305c4,(%esp)
c002b1d2:	e8 56 f5 ff ff       	call   c002a72d <msg>
  thread_create ("acquire2", PRI_DEFAULT + 2, acquire2_thread_func, &lock);
c002b1d7:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b1db:	c7 44 24 08 ad b0 02 	movl   $0xc002b0ad,0x8(%esp)
c002b1e2:	c0 
c002b1e3:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b1ea:	00 
c002b1eb:	c7 04 24 66 05 03 c0 	movl   $0xc0030566,(%esp)
c002b1f2:	e8 d2 61 ff ff       	call   c00213c9 <thread_create>
  msg ("This thread should have priority %d.  Actual priority: %d.",
c002b1f7:	e8 08 5c ff ff       	call   c0020e04 <thread_get_priority>
c002b1fc:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b200:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b207:	00 
c002b208:	c7 04 24 c4 05 03 c0 	movl   $0xc00305c4,(%esp)
c002b20f:	e8 19 f5 ff ff       	call   c002a72d <msg>
  lock_release (&lock);
c002b214:	89 1c 24             	mov    %ebx,(%esp)
c002b217:	e8 98 7c ff ff       	call   c0022eb4 <lock_release>
  msg ("acquire2, acquire1 must already have finished, in that order.");
c002b21c:	c7 04 24 00 06 03 c0 	movl   $0xc0030600,(%esp)
c002b223:	e8 05 f5 ff ff       	call   c002a72d <msg>
  msg ("This should be the last line before finishing this test.");
c002b228:	c7 04 24 40 06 03 c0 	movl   $0xc0030640,(%esp)
c002b22f:	e8 f9 f4 ff ff       	call   c002a72d <msg>
}
c002b234:	83 c4 58             	add    $0x58,%esp
c002b237:	5b                   	pop    %ebx
c002b238:	c3                   	ret    

c002b239 <b_thread_func>:
  msg ("Thread a finished.");
}

static void
b_thread_func (void *lock_) 
{
c002b239:	53                   	push   %ebx
c002b23a:	83 ec 18             	sub    $0x18,%esp
c002b23d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b241:	89 1c 24             	mov    %ebx,(%esp)
c002b244:	e8 a1 7a ff ff       	call   c0022cea <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b249:	c7 04 24 79 06 03 c0 	movl   $0xc0030679,(%esp)
c002b250:	e8 d8 f4 ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002b255:	89 1c 24             	mov    %ebx,(%esp)
c002b258:	e8 57 7c ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread b finished.");
c002b25d:	c7 04 24 93 06 03 c0 	movl   $0xc0030693,(%esp)
c002b264:	e8 c4 f4 ff ff       	call   c002a72d <msg>
}
c002b269:	83 c4 18             	add    $0x18,%esp
c002b26c:	5b                   	pop    %ebx
c002b26d:	c3                   	ret    

c002b26e <a_thread_func>:
{
c002b26e:	53                   	push   %ebx
c002b26f:	83 ec 18             	sub    $0x18,%esp
c002b272:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b276:	89 1c 24             	mov    %ebx,(%esp)
c002b279:	e8 6c 7a ff ff       	call   c0022cea <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b27e:	c7 04 24 a6 06 03 c0 	movl   $0xc00306a6,(%esp)
c002b285:	e8 a3 f4 ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002b28a:	89 1c 24             	mov    %ebx,(%esp)
c002b28d:	e8 22 7c ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread a finished.");
c002b292:	c7 04 24 c0 06 03 c0 	movl   $0xc00306c0,(%esp)
c002b299:	e8 8f f4 ff ff       	call   c002a72d <msg>
}
c002b29e:	83 c4 18             	add    $0x18,%esp
c002b2a1:	5b                   	pop    %ebx
c002b2a2:	c3                   	ret    

c002b2a3 <test_priority_donate_multiple>:
{
c002b2a3:	56                   	push   %esi
c002b2a4:	53                   	push   %ebx
c002b2a5:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b2a8:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b2af:	74 2c                	je     c002b2dd <test_priority_donate_multiple+0x3a>
c002b2b1:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b2b8:	c0 
c002b2b9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b2c0:	c0 
c002b2c1:	c7 44 24 08 90 df 02 	movl   $0xc002df90,0x8(%esp)
c002b2c8:	c0 
c002b2c9:	c7 44 24 04 1b 00 00 	movl   $0x1b,0x4(%esp)
c002b2d0:	00 
c002b2d1:	c7 04 24 d4 06 03 c0 	movl   $0xc00306d4,(%esp)
c002b2d8:	e8 96 d6 ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b2dd:	e8 22 5b ff ff       	call   c0020e04 <thread_get_priority>
c002b2e2:	83 f8 1f             	cmp    $0x1f,%eax
c002b2e5:	74 2c                	je     c002b313 <test_priority_donate_multiple+0x70>
c002b2e7:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b2ee:	c0 
c002b2ef:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b2f6:	c0 
c002b2f7:	c7 44 24 08 90 df 02 	movl   $0xc002df90,0x8(%esp)
c002b2fe:	c0 
c002b2ff:	c7 44 24 04 1e 00 00 	movl   $0x1e,0x4(%esp)
c002b306:	00 
c002b307:	c7 04 24 d4 06 03 c0 	movl   $0xc00306d4,(%esp)
c002b30e:	e8 60 d6 ff ff       	call   c0028973 <debug_panic>
  lock_init (&a);
c002b313:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b317:	89 1c 24             	mov    %ebx,(%esp)
c002b31a:	e8 2e 79 ff ff       	call   c0022c4d <lock_init>
  lock_init (&b);
c002b31f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b323:	89 34 24             	mov    %esi,(%esp)
c002b326:	e8 22 79 ff ff       	call   c0022c4d <lock_init>
  lock_acquire (&a);
c002b32b:	89 1c 24             	mov    %ebx,(%esp)
c002b32e:	e8 b7 79 ff ff       	call   c0022cea <lock_acquire>
  lock_acquire (&b);
c002b333:	89 34 24             	mov    %esi,(%esp)
c002b336:	e8 af 79 ff ff       	call   c0022cea <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 1, a_thread_func, &a);
c002b33b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b33f:	c7 44 24 08 6e b2 02 	movl   $0xc002b26e,0x8(%esp)
c002b346:	c0 
c002b347:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b34e:	00 
c002b34f:	c7 04 24 73 f2 02 c0 	movl   $0xc002f273,(%esp)
c002b356:	e8 6e 60 ff ff       	call   c00213c9 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b35b:	e8 a4 5a ff ff       	call   c0020e04 <thread_get_priority>
c002b360:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b364:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b36b:	00 
c002b36c:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b373:	e8 b5 f3 ff ff       	call   c002a72d <msg>
  thread_create ("b", PRI_DEFAULT + 2, b_thread_func, &b);
c002b378:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b37c:	c7 44 24 08 39 b2 02 	movl   $0xc002b239,0x8(%esp)
c002b383:	c0 
c002b384:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b38b:	00 
c002b38c:	c7 04 24 3d fc 02 c0 	movl   $0xc002fc3d,(%esp)
c002b393:	e8 31 60 ff ff       	call   c00213c9 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b398:	e8 67 5a ff ff       	call   c0020e04 <thread_get_priority>
c002b39d:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3a1:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b3a8:	00 
c002b3a9:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b3b0:	e8 78 f3 ff ff       	call   c002a72d <msg>
  lock_release (&b);
c002b3b5:	89 34 24             	mov    %esi,(%esp)
c002b3b8:	e8 f7 7a ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread b should have just finished.");
c002b3bd:	c7 04 24 40 07 03 c0 	movl   $0xc0030740,(%esp)
c002b3c4:	e8 64 f3 ff ff       	call   c002a72d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3c9:	e8 36 5a ff ff       	call   c0020e04 <thread_get_priority>
c002b3ce:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b3d2:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b3d9:	00 
c002b3da:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b3e1:	e8 47 f3 ff ff       	call   c002a72d <msg>
  lock_release (&a);
c002b3e6:	89 1c 24             	mov    %ebx,(%esp)
c002b3e9:	e8 c6 7a ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread a should have just finished.");
c002b3ee:	c7 04 24 64 07 03 c0 	movl   $0xc0030764,(%esp)
c002b3f5:	e8 33 f3 ff ff       	call   c002a72d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b3fa:	e8 05 5a ff ff       	call   c0020e04 <thread_get_priority>
c002b3ff:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b403:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b40a:	00 
c002b40b:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b412:	e8 16 f3 ff ff       	call   c002a72d <msg>
}
c002b417:	83 c4 74             	add    $0x74,%esp
c002b41a:	5b                   	pop    %ebx
c002b41b:	5e                   	pop    %esi
c002b41c:	c3                   	ret    

c002b41d <c_thread_func>:
  msg ("Thread b finished.");
}

static void
c_thread_func (void *a_ UNUSED) 
{
c002b41d:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread c finished.");
c002b420:	c7 04 24 88 07 03 c0 	movl   $0xc0030788,(%esp)
c002b427:	e8 01 f3 ff ff       	call   c002a72d <msg>
}
c002b42c:	83 c4 1c             	add    $0x1c,%esp
c002b42f:	c3                   	ret    

c002b430 <b_thread_func>:
{
c002b430:	53                   	push   %ebx
c002b431:	83 ec 18             	sub    $0x18,%esp
c002b434:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b438:	89 1c 24             	mov    %ebx,(%esp)
c002b43b:	e8 aa 78 ff ff       	call   c0022cea <lock_acquire>
  msg ("Thread b acquired lock b.");
c002b440:	c7 04 24 79 06 03 c0 	movl   $0xc0030679,(%esp)
c002b447:	e8 e1 f2 ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002b44c:	89 1c 24             	mov    %ebx,(%esp)
c002b44f:	e8 60 7a ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread b finished.");
c002b454:	c7 04 24 93 06 03 c0 	movl   $0xc0030693,(%esp)
c002b45b:	e8 cd f2 ff ff       	call   c002a72d <msg>
}
c002b460:	83 c4 18             	add    $0x18,%esp
c002b463:	5b                   	pop    %ebx
c002b464:	c3                   	ret    

c002b465 <a_thread_func>:
{
c002b465:	53                   	push   %ebx
c002b466:	83 ec 18             	sub    $0x18,%esp
c002b469:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (lock);
c002b46d:	89 1c 24             	mov    %ebx,(%esp)
c002b470:	e8 75 78 ff ff       	call   c0022cea <lock_acquire>
  msg ("Thread a acquired lock a.");
c002b475:	c7 04 24 a6 06 03 c0 	movl   $0xc00306a6,(%esp)
c002b47c:	e8 ac f2 ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002b481:	89 1c 24             	mov    %ebx,(%esp)
c002b484:	e8 2b 7a ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread a finished.");
c002b489:	c7 04 24 c0 06 03 c0 	movl   $0xc00306c0,(%esp)
c002b490:	e8 98 f2 ff ff       	call   c002a72d <msg>
}
c002b495:	83 c4 18             	add    $0x18,%esp
c002b498:	5b                   	pop    %ebx
c002b499:	c3                   	ret    

c002b49a <test_priority_donate_multiple2>:
{
c002b49a:	56                   	push   %esi
c002b49b:	53                   	push   %ebx
c002b49c:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b49f:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b4a6:	74 2c                	je     c002b4d4 <test_priority_donate_multiple2+0x3a>
c002b4a8:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b4af:	c0 
c002b4b0:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b4b7:	c0 
c002b4b8:	c7 44 24 08 b0 df 02 	movl   $0xc002dfb0,0x8(%esp)
c002b4bf:	c0 
c002b4c0:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b4c7:	00 
c002b4c8:	c7 04 24 9c 07 03 c0 	movl   $0xc003079c,(%esp)
c002b4cf:	e8 9f d4 ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b4d4:	e8 2b 59 ff ff       	call   c0020e04 <thread_get_priority>
c002b4d9:	83 f8 1f             	cmp    $0x1f,%eax
c002b4dc:	74 2c                	je     c002b50a <test_priority_donate_multiple2+0x70>
c002b4de:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b4e5:	c0 
c002b4e6:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b4ed:	c0 
c002b4ee:	c7 44 24 08 b0 df 02 	movl   $0xc002dfb0,0x8(%esp)
c002b4f5:	c0 
c002b4f6:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b4fd:	00 
c002b4fe:	c7 04 24 9c 07 03 c0 	movl   $0xc003079c,(%esp)
c002b505:	e8 69 d4 ff ff       	call   c0028973 <debug_panic>
  lock_init (&a);
c002b50a:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b50e:	89 34 24             	mov    %esi,(%esp)
c002b511:	e8 37 77 ff ff       	call   c0022c4d <lock_init>
  lock_init (&b);
c002b516:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b51a:	89 1c 24             	mov    %ebx,(%esp)
c002b51d:	e8 2b 77 ff ff       	call   c0022c4d <lock_init>
  lock_acquire (&a);
c002b522:	89 34 24             	mov    %esi,(%esp)
c002b525:	e8 c0 77 ff ff       	call   c0022cea <lock_acquire>
  lock_acquire (&b);
c002b52a:	89 1c 24             	mov    %ebx,(%esp)
c002b52d:	e8 b8 77 ff ff       	call   c0022cea <lock_acquire>
  thread_create ("a", PRI_DEFAULT + 3, a_thread_func, &a);
c002b532:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b536:	c7 44 24 08 65 b4 02 	movl   $0xc002b465,0x8(%esp)
c002b53d:	c0 
c002b53e:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b545:	00 
c002b546:	c7 04 24 73 f2 02 c0 	movl   $0xc002f273,(%esp)
c002b54d:	e8 77 5e ff ff       	call   c00213c9 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b552:	e8 ad 58 ff ff       	call   c0020e04 <thread_get_priority>
c002b557:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b55b:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b562:	00 
c002b563:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b56a:	e8 be f1 ff ff       	call   c002a72d <msg>
  thread_create ("c", PRI_DEFAULT + 1, c_thread_func, NULL);
c002b56f:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002b576:	00 
c002b577:	c7 44 24 08 1d b4 02 	movl   $0xc002b41d,0x8(%esp)
c002b57e:	c0 
c002b57f:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b586:	00 
c002b587:	c7 04 24 5e f6 02 c0 	movl   $0xc002f65e,(%esp)
c002b58e:	e8 36 5e ff ff       	call   c00213c9 <thread_create>
  thread_create ("b", PRI_DEFAULT + 5, b_thread_func, &b);
c002b593:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b597:	c7 44 24 08 30 b4 02 	movl   $0xc002b430,0x8(%esp)
c002b59e:	c0 
c002b59f:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5a6:	00 
c002b5a7:	c7 04 24 3d fc 02 c0 	movl   $0xc002fc3d,(%esp)
c002b5ae:	e8 16 5e ff ff       	call   c00213c9 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5b3:	e8 4c 58 ff ff       	call   c0020e04 <thread_get_priority>
c002b5b8:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5bc:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5c3:	00 
c002b5c4:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b5cb:	e8 5d f1 ff ff       	call   c002a72d <msg>
  lock_release (&a);
c002b5d0:	89 34 24             	mov    %esi,(%esp)
c002b5d3:	e8 dc 78 ff ff       	call   c0022eb4 <lock_release>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b5d8:	e8 27 58 ff ff       	call   c0020e04 <thread_get_priority>
c002b5dd:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b5e1:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b5e8:	00 
c002b5e9:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b5f0:	e8 38 f1 ff ff       	call   c002a72d <msg>
  lock_release (&b);
c002b5f5:	89 1c 24             	mov    %ebx,(%esp)
c002b5f8:	e8 b7 78 ff ff       	call   c0022eb4 <lock_release>
  msg ("Threads b, a, c should have just finished, in that order.");
c002b5fd:	c7 04 24 cc 07 03 c0 	movl   $0xc00307cc,(%esp)
c002b604:	e8 24 f1 ff ff       	call   c002a72d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002b609:	e8 f6 57 ff ff       	call   c0020e04 <thread_get_priority>
c002b60e:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b612:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b619:	00 
c002b61a:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002b621:	e8 07 f1 ff ff       	call   c002a72d <msg>
}
c002b626:	83 c4 74             	add    $0x74,%esp
c002b629:	5b                   	pop    %ebx
c002b62a:	5e                   	pop    %esi
c002b62b:	c3                   	ret    

c002b62c <high_thread_func>:
  msg ("Middle thread finished.");
}

static void
high_thread_func (void *lock_) 
{
c002b62c:	53                   	push   %ebx
c002b62d:	83 ec 18             	sub    $0x18,%esp
c002b630:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b634:	89 1c 24             	mov    %ebx,(%esp)
c002b637:	e8 ae 76 ff ff       	call   c0022cea <lock_acquire>
  msg ("High thread got the lock.");
c002b63c:	c7 04 24 06 08 03 c0 	movl   $0xc0030806,(%esp)
c002b643:	e8 e5 f0 ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002b648:	89 1c 24             	mov    %ebx,(%esp)
c002b64b:	e8 64 78 ff ff       	call   c0022eb4 <lock_release>
  msg ("High thread finished.");
c002b650:	c7 04 24 20 08 03 c0 	movl   $0xc0030820,(%esp)
c002b657:	e8 d1 f0 ff ff       	call   c002a72d <msg>
}
c002b65c:	83 c4 18             	add    $0x18,%esp
c002b65f:	5b                   	pop    %ebx
c002b660:	c3                   	ret    

c002b661 <medium_thread_func>:
{
c002b661:	53                   	push   %ebx
c002b662:	83 ec 18             	sub    $0x18,%esp
c002b665:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (locks->b);
c002b669:	8b 43 04             	mov    0x4(%ebx),%eax
c002b66c:	89 04 24             	mov    %eax,(%esp)
c002b66f:	e8 76 76 ff ff       	call   c0022cea <lock_acquire>
  lock_acquire (locks->a);
c002b674:	8b 03                	mov    (%ebx),%eax
c002b676:	89 04 24             	mov    %eax,(%esp)
c002b679:	e8 6c 76 ff ff       	call   c0022cea <lock_acquire>
  msg ("Medium thread should have priority %d.  Actual priority: %d.",
c002b67e:	e8 81 57 ff ff       	call   c0020e04 <thread_get_priority>
c002b683:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b687:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b68e:	00 
c002b68f:	c7 04 24 78 08 03 c0 	movl   $0xc0030878,(%esp)
c002b696:	e8 92 f0 ff ff       	call   c002a72d <msg>
  msg ("Medium thread got the lock.");
c002b69b:	c7 04 24 36 08 03 c0 	movl   $0xc0030836,(%esp)
c002b6a2:	e8 86 f0 ff ff       	call   c002a72d <msg>
  lock_release (locks->a);
c002b6a7:	8b 03                	mov    (%ebx),%eax
c002b6a9:	89 04 24             	mov    %eax,(%esp)
c002b6ac:	e8 03 78 ff ff       	call   c0022eb4 <lock_release>
  thread_yield ();
c002b6b1:	e8 71 5c ff ff       	call   c0021327 <thread_yield>
  lock_release (locks->b);
c002b6b6:	8b 43 04             	mov    0x4(%ebx),%eax
c002b6b9:	89 04 24             	mov    %eax,(%esp)
c002b6bc:	e8 f3 77 ff ff       	call   c0022eb4 <lock_release>
  thread_yield ();
c002b6c1:	e8 61 5c ff ff       	call   c0021327 <thread_yield>
  msg ("High thread should have just finished.");
c002b6c6:	c7 04 24 b8 08 03 c0 	movl   $0xc00308b8,(%esp)
c002b6cd:	e8 5b f0 ff ff       	call   c002a72d <msg>
  msg ("Middle thread finished.");
c002b6d2:	c7 04 24 52 08 03 c0 	movl   $0xc0030852,(%esp)
c002b6d9:	e8 4f f0 ff ff       	call   c002a72d <msg>
}
c002b6de:	83 c4 18             	add    $0x18,%esp
c002b6e1:	5b                   	pop    %ebx
c002b6e2:	c3                   	ret    

c002b6e3 <test_priority_donate_nest>:
{
c002b6e3:	56                   	push   %esi
c002b6e4:	53                   	push   %ebx
c002b6e5:	83 ec 74             	sub    $0x74,%esp
  ASSERT (!thread_mlfqs);
c002b6e8:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b6ef:	74 2c                	je     c002b71d <test_priority_donate_nest+0x3a>
c002b6f1:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b6f8:	c0 
c002b6f9:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b700:	c0 
c002b701:	c7 44 24 08 cf df 02 	movl   $0xc002dfcf,0x8(%esp)
c002b708:	c0 
c002b709:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b710:	00 
c002b711:	c7 04 24 e0 08 03 c0 	movl   $0xc00308e0,(%esp)
c002b718:	e8 56 d2 ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b71d:	e8 e2 56 ff ff       	call   c0020e04 <thread_get_priority>
c002b722:	83 f8 1f             	cmp    $0x1f,%eax
c002b725:	74 2c                	je     c002b753 <test_priority_donate_nest+0x70>
c002b727:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b72e:	c0 
c002b72f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b736:	c0 
c002b737:	c7 44 24 08 cf df 02 	movl   $0xc002dfcf,0x8(%esp)
c002b73e:	c0 
c002b73f:	c7 44 24 04 25 00 00 	movl   $0x25,0x4(%esp)
c002b746:	00 
c002b747:	c7 04 24 e0 08 03 c0 	movl   $0xc00308e0,(%esp)
c002b74e:	e8 20 d2 ff ff       	call   c0028973 <debug_panic>
  lock_init (&a);
c002b753:	8d 5c 24 4c          	lea    0x4c(%esp),%ebx
c002b757:	89 1c 24             	mov    %ebx,(%esp)
c002b75a:	e8 ee 74 ff ff       	call   c0022c4d <lock_init>
  lock_init (&b);
c002b75f:	8d 74 24 28          	lea    0x28(%esp),%esi
c002b763:	89 34 24             	mov    %esi,(%esp)
c002b766:	e8 e2 74 ff ff       	call   c0022c4d <lock_init>
  lock_acquire (&a);
c002b76b:	89 1c 24             	mov    %ebx,(%esp)
c002b76e:	e8 77 75 ff ff       	call   c0022cea <lock_acquire>
  locks.a = &a;
c002b773:	89 5c 24 20          	mov    %ebx,0x20(%esp)
  locks.b = &b;
c002b777:	89 74 24 24          	mov    %esi,0x24(%esp)
  thread_create ("medium", PRI_DEFAULT + 1, medium_thread_func, &locks);
c002b77b:	8d 44 24 20          	lea    0x20(%esp),%eax
c002b77f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002b783:	c7 44 24 08 61 b6 02 	movl   $0xc002b661,0x8(%esp)
c002b78a:	c0 
c002b78b:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b792:	00 
c002b793:	c7 04 24 6a 08 03 c0 	movl   $0xc003086a,(%esp)
c002b79a:	e8 2a 5c ff ff       	call   c00213c9 <thread_create>
  thread_yield ();
c002b79f:	e8 83 5b ff ff       	call   c0021327 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b7a4:	e8 5b 56 ff ff       	call   c0020e04 <thread_get_priority>
c002b7a9:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b7ad:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b7b4:	00 
c002b7b5:	c7 04 24 0c 09 03 c0 	movl   $0xc003090c,(%esp)
c002b7bc:	e8 6c ef ff ff       	call   c002a72d <msg>
  thread_create ("high", PRI_DEFAULT + 2, high_thread_func, &b);
c002b7c1:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002b7c5:	c7 44 24 08 2c b6 02 	movl   $0xc002b62c,0x8(%esp)
c002b7cc:	c0 
c002b7cd:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b7d4:	00 
c002b7d5:	c7 04 24 71 08 03 c0 	movl   $0xc0030871,(%esp)
c002b7dc:	e8 e8 5b ff ff       	call   c00213c9 <thread_create>
  thread_yield ();
c002b7e1:	e8 41 5b ff ff       	call   c0021327 <thread_yield>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b7e6:	e8 19 56 ff ff       	call   c0020e04 <thread_get_priority>
c002b7eb:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b7ef:	c7 44 24 04 21 00 00 	movl   $0x21,0x4(%esp)
c002b7f6:	00 
c002b7f7:	c7 04 24 0c 09 03 c0 	movl   $0xc003090c,(%esp)
c002b7fe:	e8 2a ef ff ff       	call   c002a72d <msg>
  lock_release (&a);
c002b803:	89 1c 24             	mov    %ebx,(%esp)
c002b806:	e8 a9 76 ff ff       	call   c0022eb4 <lock_release>
  thread_yield ();
c002b80b:	e8 17 5b ff ff       	call   c0021327 <thread_yield>
  msg ("Medium thread should just have finished.");
c002b810:	c7 04 24 48 09 03 c0 	movl   $0xc0030948,(%esp)
c002b817:	e8 11 ef ff ff       	call   c002a72d <msg>
  msg ("Low thread should have priority %d.  Actual priority: %d.",
c002b81c:	e8 e3 55 ff ff       	call   c0020e04 <thread_get_priority>
c002b821:	89 44 24 08          	mov    %eax,0x8(%esp)
c002b825:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002b82c:	00 
c002b82d:	c7 04 24 0c 09 03 c0 	movl   $0xc003090c,(%esp)
c002b834:	e8 f4 ee ff ff       	call   c002a72d <msg>
}
c002b839:	83 c4 74             	add    $0x74,%esp
c002b83c:	5b                   	pop    %ebx
c002b83d:	5e                   	pop    %esi
c002b83e:	c3                   	ret    

c002b83f <h_thread_func>:
  msg ("Thread M finished.");
}

static void
h_thread_func (void *ls_) 
{
c002b83f:	53                   	push   %ebx
c002b840:	83 ec 18             	sub    $0x18,%esp
c002b843:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock_and_sema *ls = ls_;

  lock_acquire (&ls->lock);
c002b847:	89 1c 24             	mov    %ebx,(%esp)
c002b84a:	e8 9b 74 ff ff       	call   c0022cea <lock_acquire>
  msg ("Thread H acquired lock.");
c002b84f:	c7 04 24 71 09 03 c0 	movl   $0xc0030971,(%esp)
c002b856:	e8 d2 ee ff ff       	call   c002a72d <msg>

  sema_up (&ls->sema);
c002b85b:	8d 43 24             	lea    0x24(%ebx),%eax
c002b85e:	89 04 24             	mov    %eax,(%esp)
c002b861:	e8 71 72 ff ff       	call   c0022ad7 <sema_up>
  lock_release (&ls->lock);
c002b866:	89 1c 24             	mov    %ebx,(%esp)
c002b869:	e8 46 76 ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread H finished.");
c002b86e:	c7 04 24 89 09 03 c0 	movl   $0xc0030989,(%esp)
c002b875:	e8 b3 ee ff ff       	call   c002a72d <msg>
}
c002b87a:	83 c4 18             	add    $0x18,%esp
c002b87d:	5b                   	pop    %ebx
c002b87e:	c3                   	ret    

c002b87f <m_thread_func>:
{
c002b87f:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&ls->sema);
c002b882:	8b 44 24 20          	mov    0x20(%esp),%eax
c002b886:	83 c0 24             	add    $0x24,%eax
c002b889:	89 04 24             	mov    %eax,(%esp)
c002b88c:	e8 31 71 ff ff       	call   c00229c2 <sema_down>
  msg ("Thread M finished.");
c002b891:	c7 04 24 9c 09 03 c0 	movl   $0xc003099c,(%esp)
c002b898:	e8 90 ee ff ff       	call   c002a72d <msg>
}
c002b89d:	83 c4 1c             	add    $0x1c,%esp
c002b8a0:	c3                   	ret    

c002b8a1 <l_thread_func>:
{
c002b8a1:	53                   	push   %ebx
c002b8a2:	83 ec 18             	sub    $0x18,%esp
c002b8a5:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  lock_acquire (&ls->lock);
c002b8a9:	89 1c 24             	mov    %ebx,(%esp)
c002b8ac:	e8 39 74 ff ff       	call   c0022cea <lock_acquire>
  msg ("Thread L acquired lock.");
c002b8b1:	c7 04 24 af 09 03 c0 	movl   $0xc00309af,(%esp)
c002b8b8:	e8 70 ee ff ff       	call   c002a72d <msg>
  sema_down (&ls->sema);
c002b8bd:	8d 43 24             	lea    0x24(%ebx),%eax
c002b8c0:	89 04 24             	mov    %eax,(%esp)
c002b8c3:	e8 fa 70 ff ff       	call   c00229c2 <sema_down>
  msg ("Thread L downed semaphore.");
c002b8c8:	c7 04 24 c7 09 03 c0 	movl   $0xc00309c7,(%esp)
c002b8cf:	e8 59 ee ff ff       	call   c002a72d <msg>
  lock_release (&ls->lock);
c002b8d4:	89 1c 24             	mov    %ebx,(%esp)
c002b8d7:	e8 d8 75 ff ff       	call   c0022eb4 <lock_release>
  msg ("Thread L finished.");
c002b8dc:	c7 04 24 e2 09 03 c0 	movl   $0xc00309e2,(%esp)
c002b8e3:	e8 45 ee ff ff       	call   c002a72d <msg>
}
c002b8e8:	83 c4 18             	add    $0x18,%esp
c002b8eb:	5b                   	pop    %ebx
c002b8ec:	c3                   	ret    

c002b8ed <test_priority_donate_sema>:
{
c002b8ed:	56                   	push   %esi
c002b8ee:	53                   	push   %ebx
c002b8ef:	83 ec 64             	sub    $0x64,%esp
  ASSERT (!thread_mlfqs);
c002b8f2:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002b8f9:	74 2c                	je     c002b927 <test_priority_donate_sema+0x3a>
c002b8fb:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002b902:	c0 
c002b903:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b90a:	c0 
c002b90b:	c7 44 24 08 e9 df 02 	movl   $0xc002dfe9,0x8(%esp)
c002b912:	c0 
c002b913:	c7 44 24 04 23 00 00 	movl   $0x23,0x4(%esp)
c002b91a:	00 
c002b91b:	c7 04 24 14 0a 03 c0 	movl   $0xc0030a14,(%esp)
c002b922:	e8 4c d0 ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002b927:	e8 d8 54 ff ff       	call   c0020e04 <thread_get_priority>
c002b92c:	83 f8 1f             	cmp    $0x1f,%eax
c002b92f:	74 2c                	je     c002b95d <test_priority_donate_sema+0x70>
c002b931:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002b938:	c0 
c002b939:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002b940:	c0 
c002b941:	c7 44 24 08 e9 df 02 	movl   $0xc002dfe9,0x8(%esp)
c002b948:	c0 
c002b949:	c7 44 24 04 26 00 00 	movl   $0x26,0x4(%esp)
c002b950:	00 
c002b951:	c7 04 24 14 0a 03 c0 	movl   $0xc0030a14,(%esp)
c002b958:	e8 16 d0 ff ff       	call   c0028973 <debug_panic>
  lock_init (&ls.lock);
c002b95d:	8d 5c 24 28          	lea    0x28(%esp),%ebx
c002b961:	89 1c 24             	mov    %ebx,(%esp)
c002b964:	e8 e4 72 ff ff       	call   c0022c4d <lock_init>
  sema_init (&ls.sema, 0);
c002b969:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002b970:	00 
c002b971:	8d 74 24 4c          	lea    0x4c(%esp),%esi
c002b975:	89 34 24             	mov    %esi,(%esp)
c002b978:	e8 f9 6f ff ff       	call   c0022976 <sema_init>
  thread_create ("low", PRI_DEFAULT + 1, l_thread_func, &ls);
c002b97d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b981:	c7 44 24 08 a1 b8 02 	movl   $0xc002b8a1,0x8(%esp)
c002b988:	c0 
c002b989:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002b990:	00 
c002b991:	c7 04 24 f5 09 03 c0 	movl   $0xc00309f5,(%esp)
c002b998:	e8 2c 5a ff ff       	call   c00213c9 <thread_create>
  thread_create ("med", PRI_DEFAULT + 3, m_thread_func, &ls);
c002b99d:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9a1:	c7 44 24 08 7f b8 02 	movl   $0xc002b87f,0x8(%esp)
c002b9a8:	c0 
c002b9a9:	c7 44 24 04 22 00 00 	movl   $0x22,0x4(%esp)
c002b9b0:	00 
c002b9b1:	c7 04 24 f9 09 03 c0 	movl   $0xc00309f9,(%esp)
c002b9b8:	e8 0c 5a ff ff       	call   c00213c9 <thread_create>
  thread_create ("high", PRI_DEFAULT + 5, h_thread_func, &ls);
c002b9bd:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002b9c1:	c7 44 24 08 3f b8 02 	movl   $0xc002b83f,0x8(%esp)
c002b9c8:	c0 
c002b9c9:	c7 44 24 04 24 00 00 	movl   $0x24,0x4(%esp)
c002b9d0:	00 
c002b9d1:	c7 04 24 71 08 03 c0 	movl   $0xc0030871,(%esp)
c002b9d8:	e8 ec 59 ff ff       	call   c00213c9 <thread_create>
  sema_up (&ls.sema);
c002b9dd:	89 34 24             	mov    %esi,(%esp)
c002b9e0:	e8 f2 70 ff ff       	call   c0022ad7 <sema_up>
  msg ("Main thread finished.");
c002b9e5:	c7 04 24 fd 09 03 c0 	movl   $0xc00309fd,(%esp)
c002b9ec:	e8 3c ed ff ff       	call   c002a72d <msg>
}
c002b9f1:	83 c4 64             	add    $0x64,%esp
c002b9f4:	5b                   	pop    %ebx
c002b9f5:	5e                   	pop    %esi
c002b9f6:	c3                   	ret    

c002b9f7 <acquire_thread_func>:
       PRI_DEFAULT - 10, thread_get_priority ());
}

static void
acquire_thread_func (void *lock_) 
{
c002b9f7:	53                   	push   %ebx
c002b9f8:	83 ec 18             	sub    $0x18,%esp
c002b9fb:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct lock *lock = lock_;

  lock_acquire (lock);
c002b9ff:	89 1c 24             	mov    %ebx,(%esp)
c002ba02:	e8 e3 72 ff ff       	call   c0022cea <lock_acquire>
  msg ("acquire: got the lock");
c002ba07:	c7 04 24 3f 0a 03 c0 	movl   $0xc0030a3f,(%esp)
c002ba0e:	e8 1a ed ff ff       	call   c002a72d <msg>
  lock_release (lock);
c002ba13:	89 1c 24             	mov    %ebx,(%esp)
c002ba16:	e8 99 74 ff ff       	call   c0022eb4 <lock_release>
  msg ("acquire: done");
c002ba1b:	c7 04 24 55 0a 03 c0 	movl   $0xc0030a55,(%esp)
c002ba22:	e8 06 ed ff ff       	call   c002a72d <msg>
}
c002ba27:	83 c4 18             	add    $0x18,%esp
c002ba2a:	5b                   	pop    %ebx
c002ba2b:	c3                   	ret    

c002ba2c <test_priority_donate_lower>:
{
c002ba2c:	53                   	push   %ebx
c002ba2d:	83 ec 58             	sub    $0x58,%esp
  ASSERT (!thread_mlfqs);
c002ba30:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002ba37:	74 2c                	je     c002ba65 <test_priority_donate_lower+0x39>
c002ba39:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002ba40:	c0 
c002ba41:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ba48:	c0 
c002ba49:	c7 44 24 08 03 e0 02 	movl   $0xc002e003,0x8(%esp)
c002ba50:	c0 
c002ba51:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002ba58:	00 
c002ba59:	c7 04 24 88 0a 03 c0 	movl   $0xc0030a88,(%esp)
c002ba60:	e8 0e cf ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002ba65:	e8 9a 53 ff ff       	call   c0020e04 <thread_get_priority>
c002ba6a:	83 f8 1f             	cmp    $0x1f,%eax
c002ba6d:	74 2c                	je     c002ba9b <test_priority_donate_lower+0x6f>
c002ba6f:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002ba76:	c0 
c002ba77:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ba7e:	c0 
c002ba7f:	c7 44 24 08 03 e0 02 	movl   $0xc002e003,0x8(%esp)
c002ba86:	c0 
c002ba87:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002ba8e:	00 
c002ba8f:	c7 04 24 88 0a 03 c0 	movl   $0xc0030a88,(%esp)
c002ba96:	e8 d8 ce ff ff       	call   c0028973 <debug_panic>
  lock_init (&lock);
c002ba9b:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002ba9f:	89 1c 24             	mov    %ebx,(%esp)
c002baa2:	e8 a6 71 ff ff       	call   c0022c4d <lock_init>
  lock_acquire (&lock);
c002baa7:	89 1c 24             	mov    %ebx,(%esp)
c002baaa:	e8 3b 72 ff ff       	call   c0022cea <lock_acquire>
  thread_create ("acquire", PRI_DEFAULT + 10, acquire_thread_func, &lock);
c002baaf:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bab3:	c7 44 24 08 f7 b9 02 	movl   $0xc002b9f7,0x8(%esp)
c002baba:	c0 
c002babb:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bac2:	00 
c002bac3:	c7 04 24 63 0a 03 c0 	movl   $0xc0030a63,(%esp)
c002baca:	e8 fa 58 ff ff       	call   c00213c9 <thread_create>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bacf:	e8 30 53 ff ff       	call   c0020e04 <thread_get_priority>
c002bad4:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bad8:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002badf:	00 
c002bae0:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002bae7:	e8 41 ec ff ff       	call   c002a72d <msg>
  msg ("Lowering base priority...");
c002baec:	c7 04 24 6b 0a 03 c0 	movl   $0xc0030a6b,(%esp)
c002baf3:	e8 35 ec ff ff       	call   c002a72d <msg>
  thread_set_priority (PRI_DEFAULT - 10);
c002baf8:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
c002baff:	e8 33 5a ff ff       	call   c0021537 <thread_set_priority>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb04:	e8 fb 52 ff ff       	call   c0020e04 <thread_get_priority>
c002bb09:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb0d:	c7 44 24 04 29 00 00 	movl   $0x29,0x4(%esp)
c002bb14:	00 
c002bb15:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002bb1c:	e8 0c ec ff ff       	call   c002a72d <msg>
  lock_release (&lock);
c002bb21:	89 1c 24             	mov    %ebx,(%esp)
c002bb24:	e8 8b 73 ff ff       	call   c0022eb4 <lock_release>
  msg ("acquire must already have finished.");
c002bb29:	c7 04 24 b4 0a 03 c0 	movl   $0xc0030ab4,(%esp)
c002bb30:	e8 f8 eb ff ff       	call   c002a72d <msg>
  msg ("Main thread should have priority %d.  Actual priority: %d.",
c002bb35:	e8 ca 52 ff ff       	call   c0020e04 <thread_get_priority>
c002bb3a:	89 44 24 08          	mov    %eax,0x8(%esp)
c002bb3e:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bb45:	00 
c002bb46:	c7 04 24 04 07 03 c0 	movl   $0xc0030704,(%esp)
c002bb4d:	e8 db eb ff ff       	call   c002a72d <msg>
}
c002bb52:	83 c4 58             	add    $0x58,%esp
c002bb55:	5b                   	pop    %ebx
c002bb56:	c3                   	ret    
c002bb57:	90                   	nop
c002bb58:	90                   	nop
c002bb59:	90                   	nop
c002bb5a:	90                   	nop
c002bb5b:	90                   	nop
c002bb5c:	90                   	nop
c002bb5d:	90                   	nop
c002bb5e:	90                   	nop
c002bb5f:	90                   	nop

c002bb60 <simple_thread_func>:
    }
}

static void 
simple_thread_func (void *data_) 
{
c002bb60:	56                   	push   %esi
c002bb61:	53                   	push   %ebx
c002bb62:	83 ec 14             	sub    $0x14,%esp
c002bb65:	8b 5c 24 20          	mov    0x20(%esp),%ebx
c002bb69:	be 10 00 00 00       	mov    $0x10,%esi
  struct simple_thread_data *data = data_;
  int i;
  
  for (i = 0; i < ITER_CNT; i++) 
    {
      lock_acquire (data->lock);
c002bb6e:	8b 43 08             	mov    0x8(%ebx),%eax
c002bb71:	89 04 24             	mov    %eax,(%esp)
c002bb74:	e8 71 71 ff ff       	call   c0022cea <lock_acquire>
      *(*data->op)++ = data->id;
c002bb79:	8b 53 0c             	mov    0xc(%ebx),%edx
c002bb7c:	8b 02                	mov    (%edx),%eax
c002bb7e:	8d 48 04             	lea    0x4(%eax),%ecx
c002bb81:	89 0a                	mov    %ecx,(%edx)
c002bb83:	8b 13                	mov    (%ebx),%edx
c002bb85:	89 10                	mov    %edx,(%eax)
      lock_release (data->lock);
c002bb87:	8b 43 08             	mov    0x8(%ebx),%eax
c002bb8a:	89 04 24             	mov    %eax,(%esp)
c002bb8d:	e8 22 73 ff ff       	call   c0022eb4 <lock_release>
      thread_yield ();
c002bb92:	e8 90 57 ff ff       	call   c0021327 <thread_yield>
  for (i = 0; i < ITER_CNT; i++) 
c002bb97:	83 ee 01             	sub    $0x1,%esi
c002bb9a:	75 d2                	jne    c002bb6e <simple_thread_func+0xe>
    }
}
c002bb9c:	83 c4 14             	add    $0x14,%esp
c002bb9f:	5b                   	pop    %ebx
c002bba0:	5e                   	pop    %esi
c002bba1:	c3                   	ret    

c002bba2 <test_priority_fifo>:
{
c002bba2:	55                   	push   %ebp
c002bba3:	57                   	push   %edi
c002bba4:	56                   	push   %esi
c002bba5:	53                   	push   %ebx
c002bba6:	81 ec 6c 01 00 00    	sub    $0x16c,%esp
  ASSERT (!thread_mlfqs);
c002bbac:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002bbb3:	74 2c                	je     c002bbe1 <test_priority_fifo+0x3f>
c002bbb5:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002bbbc:	c0 
c002bbbd:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bbc4:	c0 
c002bbc5:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bbcc:	c0 
c002bbcd:	c7 44 24 04 28 00 00 	movl   $0x28,0x4(%esp)
c002bbd4:	00 
c002bbd5:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bbdc:	e8 92 cd ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002bbe1:	e8 1e 52 ff ff       	call   c0020e04 <thread_get_priority>
c002bbe6:	83 f8 1f             	cmp    $0x1f,%eax
c002bbe9:	74 2c                	je     c002bc17 <test_priority_fifo+0x75>
c002bbeb:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002bbf2:	c0 
c002bbf3:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bbfa:	c0 
c002bbfb:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bc02:	c0 
c002bc03:	c7 44 24 04 2b 00 00 	movl   $0x2b,0x4(%esp)
c002bc0a:	00 
c002bc0b:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bc12:	e8 5c cd ff ff       	call   c0028973 <debug_panic>
  msg ("%d threads will iterate %d times in the same order each time.",
c002bc17:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
c002bc1e:	00 
c002bc1f:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bc26:	00 
c002bc27:	c7 04 24 2c 0b 03 c0 	movl   $0xc0030b2c,(%esp)
c002bc2e:	e8 fa ea ff ff       	call   c002a72d <msg>
  msg ("If the order varies then there is a bug.");
c002bc33:	c7 04 24 6c 0b 03 c0 	movl   $0xc0030b6c,(%esp)
c002bc3a:	e8 ee ea ff ff       	call   c002a72d <msg>
  output = op = malloc (sizeof *output * THREAD_CNT * ITER_CNT * 2);
c002bc3f:	c7 04 24 00 08 00 00 	movl   $0x800,(%esp)
c002bc46:	e8 69 7c ff ff       	call   c00238b4 <malloc>
c002bc4b:	89 c6                	mov    %eax,%esi
c002bc4d:	89 44 24 38          	mov    %eax,0x38(%esp)
  ASSERT (output != NULL);
c002bc51:	85 c0                	test   %eax,%eax
c002bc53:	75 2c                	jne    c002bc81 <test_priority_fifo+0xdf>
c002bc55:	c7 44 24 10 0a 01 03 	movl   $0xc003010a,0x10(%esp)
c002bc5c:	c0 
c002bc5d:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bc64:	c0 
c002bc65:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bc6c:	c0 
c002bc6d:	c7 44 24 04 32 00 00 	movl   $0x32,0x4(%esp)
c002bc74:	00 
c002bc75:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bc7c:	e8 f2 cc ff ff       	call   c0028973 <debug_panic>
  lock_init (&lock);
c002bc81:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bc85:	89 04 24             	mov    %eax,(%esp)
c002bc88:	e8 c0 6f ff ff       	call   c0022c4d <lock_init>
  thread_set_priority (PRI_DEFAULT + 2);
c002bc8d:	c7 04 24 21 00 00 00 	movl   $0x21,(%esp)
c002bc94:	e8 9e 58 ff ff       	call   c0021537 <thread_set_priority>
c002bc99:	8d 5c 24 60          	lea    0x60(%esp),%ebx
  for (i = 0; i < THREAD_CNT; i++) 
c002bc9d:	bf 00 00 00 00       	mov    $0x0,%edi
      snprintf (name, sizeof name, "%d", i);
c002bca2:	8d 6c 24 28          	lea    0x28(%esp),%ebp
c002bca6:	89 7c 24 0c          	mov    %edi,0xc(%esp)
c002bcaa:	c7 44 24 08 20 01 03 	movl   $0xc0030120,0x8(%esp)
c002bcb1:	c0 
c002bcb2:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bcb9:	00 
c002bcba:	89 2c 24             	mov    %ebp,(%esp)
c002bcbd:	e8 5d b5 ff ff       	call   c002721f <snprintf>
      d->id = i;
c002bcc2:	89 3b                	mov    %edi,(%ebx)
      d->iterations = 0;
c002bcc4:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
      d->lock = &lock;
c002bccb:	8d 44 24 3c          	lea    0x3c(%esp),%eax
c002bccf:	89 43 08             	mov    %eax,0x8(%ebx)
      d->op = &op;
c002bcd2:	8d 44 24 38          	lea    0x38(%esp),%eax
c002bcd6:	89 43 0c             	mov    %eax,0xc(%ebx)
      thread_create (name, PRI_DEFAULT + 1, simple_thread_func, d);
c002bcd9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002bcdd:	c7 44 24 08 60 bb 02 	movl   $0xc002bb60,0x8(%esp)
c002bce4:	c0 
c002bce5:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002bcec:	00 
c002bced:	89 2c 24             	mov    %ebp,(%esp)
c002bcf0:	e8 d4 56 ff ff       	call   c00213c9 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002bcf5:	83 c7 01             	add    $0x1,%edi
c002bcf8:	83 c3 10             	add    $0x10,%ebx
c002bcfb:	83 ff 10             	cmp    $0x10,%edi
c002bcfe:	75 a6                	jne    c002bca6 <test_priority_fifo+0x104>
  thread_set_priority (PRI_DEFAULT);
c002bd00:	c7 04 24 1f 00 00 00 	movl   $0x1f,(%esp)
c002bd07:	e8 2b 58 ff ff       	call   c0021537 <thread_set_priority>
  ASSERT (lock.holder == NULL);
c002bd0c:	83 7c 24 3c 00       	cmpl   $0x0,0x3c(%esp)
c002bd11:	75 13                	jne    c002bd26 <test_priority_fifo+0x184>
  for (; output < op; output++) 
c002bd13:	3b 74 24 38          	cmp    0x38(%esp),%esi
c002bd17:	0f 83 be 00 00 00    	jae    c002bddb <test_priority_fifo+0x239>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd1d:	8b 3e                	mov    (%esi),%edi
c002bd1f:	83 ff 0f             	cmp    $0xf,%edi
c002bd22:	76 61                	jbe    c002bd85 <test_priority_fifo+0x1e3>
c002bd24:	eb 33                	jmp    c002bd59 <test_priority_fifo+0x1b7>
  ASSERT (lock.holder == NULL);
c002bd26:	c7 44 24 10 d8 0a 03 	movl   $0xc0030ad8,0x10(%esp)
c002bd2d:	c0 
c002bd2e:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bd35:	c0 
c002bd36:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bd3d:	c0 
c002bd3e:	c7 44 24 04 44 00 00 	movl   $0x44,0x4(%esp)
c002bd45:	00 
c002bd46:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bd4d:	e8 21 cc ff ff       	call   c0028973 <debug_panic>
      ASSERT (*output >= 0 && *output < THREAD_CNT);
c002bd52:	8b 3e                	mov    (%esi),%edi
c002bd54:	83 ff 0f             	cmp    $0xf,%edi
c002bd57:	76 31                	jbe    c002bd8a <test_priority_fifo+0x1e8>
c002bd59:	c7 44 24 10 98 0b 03 	movl   $0xc0030b98,0x10(%esp)
c002bd60:	c0 
c002bd61:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bd68:	c0 
c002bd69:	c7 44 24 08 1e e0 02 	movl   $0xc002e01e,0x8(%esp)
c002bd70:	c0 
c002bd71:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002bd78:	00 
c002bd79:	c7 04 24 08 0b 03 c0 	movl   $0xc0030b08,(%esp)
c002bd80:	e8 ee cb ff ff       	call   c0028973 <debug_panic>
c002bd85:	bb 00 00 00 00       	mov    $0x0,%ebx
      d = data + *output;
c002bd8a:	c1 e7 04             	shl    $0x4,%edi
c002bd8d:	8d 44 24 60          	lea    0x60(%esp),%eax
c002bd91:	01 c7                	add    %eax,%edi
      if (cnt % THREAD_CNT == 0)
c002bd93:	f6 c3 0f             	test   $0xf,%bl
c002bd96:	75 0c                	jne    c002bda4 <test_priority_fifo+0x202>
        printf ("(priority-fifo) iteration:");
c002bd98:	c7 04 24 ec 0a 03 c0 	movl   $0xc0030aec,(%esp)
c002bd9f:	e8 7a ad ff ff       	call   c0026b1e <printf>
      printf (" %d", d->id);
c002bda4:	8b 07                	mov    (%edi),%eax
c002bda6:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bdaa:	c7 04 24 1f 01 03 c0 	movl   $0xc003011f,(%esp)
c002bdb1:	e8 68 ad ff ff       	call   c0026b1e <printf>
      if (++cnt % THREAD_CNT == 0)
c002bdb6:	83 c3 01             	add    $0x1,%ebx
c002bdb9:	f6 c3 0f             	test   $0xf,%bl
c002bdbc:	75 0c                	jne    c002bdca <test_priority_fifo+0x228>
        printf ("\n");
c002bdbe:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c002bdc5:	e8 42 e9 ff ff       	call   c002a70c <putchar>
      d->iterations++;
c002bdca:	83 47 04 01          	addl   $0x1,0x4(%edi)
  for (; output < op; output++) 
c002bdce:	83 c6 04             	add    $0x4,%esi
c002bdd1:	39 74 24 38          	cmp    %esi,0x38(%esp)
c002bdd5:	0f 87 77 ff ff ff    	ja     c002bd52 <test_priority_fifo+0x1b0>
}
c002bddb:	81 c4 6c 01 00 00    	add    $0x16c,%esp
c002bde1:	5b                   	pop    %ebx
c002bde2:	5e                   	pop    %esi
c002bde3:	5f                   	pop    %edi
c002bde4:	5d                   	pop    %ebp
c002bde5:	c3                   	ret    

c002bde6 <simple_thread_func>:
  msg ("The high-priority thread should have already completed.");
}

static void 
simple_thread_func (void *aux UNUSED) 
{
c002bde6:	53                   	push   %ebx
c002bde7:	83 ec 18             	sub    $0x18,%esp
  int i;
  
  for (i = 0; i < 5; i++) 
c002bdea:	bb 00 00 00 00       	mov    $0x0,%ebx
    {
      msg ("Thread %s iteration %d", thread_name (), i);
c002bdef:	e8 73 4f ff ff       	call   c0020d67 <thread_name>
c002bdf4:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002bdf8:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bdfc:	c7 04 24 bd 0b 03 c0 	movl   $0xc0030bbd,(%esp)
c002be03:	e8 25 e9 ff ff       	call   c002a72d <msg>
      thread_yield ();
c002be08:	e8 1a 55 ff ff       	call   c0021327 <thread_yield>
  for (i = 0; i < 5; i++) 
c002be0d:	83 c3 01             	add    $0x1,%ebx
c002be10:	83 fb 05             	cmp    $0x5,%ebx
c002be13:	75 da                	jne    c002bdef <simple_thread_func+0x9>
    }
  msg ("Thread %s done!", thread_name ());
c002be15:	e8 4d 4f ff ff       	call   c0020d67 <thread_name>
c002be1a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002be1e:	c7 04 24 d4 0b 03 c0 	movl   $0xc0030bd4,(%esp)
c002be25:	e8 03 e9 ff ff       	call   c002a72d <msg>
}
c002be2a:	83 c4 18             	add    $0x18,%esp
c002be2d:	5b                   	pop    %ebx
c002be2e:	c3                   	ret    

c002be2f <test_priority_preempt>:
{
c002be2f:	83 ec 2c             	sub    $0x2c,%esp
  ASSERT (!thread_mlfqs);
c002be32:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002be39:	74 2c                	je     c002be67 <test_priority_preempt+0x38>
c002be3b:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002be42:	c0 
c002be43:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002be4a:	c0 
c002be4b:	c7 44 24 08 31 e0 02 	movl   $0xc002e031,0x8(%esp)
c002be52:	c0 
c002be53:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002be5a:	00 
c002be5b:	c7 04 24 f4 0b 03 c0 	movl   $0xc0030bf4,(%esp)
c002be62:	e8 0c cb ff ff       	call   c0028973 <debug_panic>
  ASSERT (thread_get_priority () == PRI_DEFAULT);
c002be67:	e8 98 4f ff ff       	call   c0020e04 <thread_get_priority>
c002be6c:	83 f8 1f             	cmp    $0x1f,%eax
c002be6f:	74 2c                	je     c002be9d <test_priority_preempt+0x6e>
c002be71:	c7 44 24 10 9c 05 03 	movl   $0xc003059c,0x10(%esp)
c002be78:	c0 
c002be79:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002be80:	c0 
c002be81:	c7 44 24 08 31 e0 02 	movl   $0xc002e031,0x8(%esp)
c002be88:	c0 
c002be89:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002be90:	00 
c002be91:	c7 04 24 f4 0b 03 c0 	movl   $0xc0030bf4,(%esp)
c002be98:	e8 d6 ca ff ff       	call   c0028973 <debug_panic>
  thread_create ("high-priority", PRI_DEFAULT + 1, simple_thread_func, NULL);
c002be9d:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bea4:	00 
c002bea5:	c7 44 24 08 e6 bd 02 	movl   $0xc002bde6,0x8(%esp)
c002beac:	c0 
c002bead:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002beb4:	00 
c002beb5:	c7 04 24 e4 0b 03 c0 	movl   $0xc0030be4,(%esp)
c002bebc:	e8 08 55 ff ff       	call   c00213c9 <thread_create>
  msg ("The high-priority thread should have already completed.");
c002bec1:	c7 04 24 1c 0c 03 c0 	movl   $0xc0030c1c,(%esp)
c002bec8:	e8 60 e8 ff ff       	call   c002a72d <msg>
}
c002becd:	83 c4 2c             	add    $0x2c,%esp
c002bed0:	c3                   	ret    

c002bed1 <priority_sema_thread>:
    }
}

static void
priority_sema_thread (void *aux UNUSED) 
{
c002bed1:	83 ec 1c             	sub    $0x1c,%esp
  sema_down (&sema);
c002bed4:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bedb:	e8 e2 6a ff ff       	call   c00229c2 <sema_down>
  msg ("Thread %s woke up.", thread_name ());
c002bee0:	e8 82 4e ff ff       	call   c0020d67 <thread_name>
c002bee5:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bee9:	c7 04 24 f0 03 03 c0 	movl   $0xc00303f0,(%esp)
c002bef0:	e8 38 e8 ff ff       	call   c002a72d <msg>
}
c002bef5:	83 c4 1c             	add    $0x1c,%esp
c002bef8:	c3                   	ret    

c002bef9 <test_priority_sema>:
{
c002bef9:	55                   	push   %ebp
c002befa:	57                   	push   %edi
c002befb:	56                   	push   %esi
c002befc:	53                   	push   %ebx
c002befd:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002bf00:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002bf07:	74 2c                	je     c002bf35 <test_priority_sema+0x3c>
c002bf09:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002bf10:	c0 
c002bf11:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002bf18:	c0 
c002bf19:	c7 44 24 08 47 e0 02 	movl   $0xc002e047,0x8(%esp)
c002bf20:	c0 
c002bf21:	c7 44 24 04 15 00 00 	movl   $0x15,0x4(%esp)
c002bf28:	00 
c002bf29:	c7 04 24 6c 0c 03 c0 	movl   $0xc0030c6c,(%esp)
c002bf30:	e8 3e ca ff ff       	call   c0028973 <debug_panic>
  sema_init (&sema, 0);
c002bf35:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002bf3c:	00 
c002bf3d:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bf44:	e8 2d 6a ff ff       	call   c0022976 <sema_init>
  thread_set_priority (PRI_MIN);
c002bf49:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002bf50:	e8 e2 55 ff ff       	call   c0021537 <thread_set_priority>
c002bf55:	bb 03 00 00 00       	mov    $0x3,%ebx
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bf5a:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002bf5f:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 3) % 10 - 1;
c002bf63:	89 d8                	mov    %ebx,%eax
c002bf65:	f7 ed                	imul   %ebp
c002bf67:	c1 fa 02             	sar    $0x2,%edx
c002bf6a:	89 d8                	mov    %ebx,%eax
c002bf6c:	c1 f8 1f             	sar    $0x1f,%eax
c002bf6f:	29 c2                	sub    %eax,%edx
c002bf71:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002bf74:	01 c0                	add    %eax,%eax
c002bf76:	29 d8                	sub    %ebx,%eax
c002bf78:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002bf7b:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002bf7f:	c7 44 24 08 03 04 03 	movl   $0xc0030403,0x8(%esp)
c002bf86:	c0 
c002bf87:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002bf8e:	00 
c002bf8f:	89 3c 24             	mov    %edi,(%esp)
c002bf92:	e8 88 b2 ff ff       	call   c002721f <snprintf>
      thread_create (name, priority, priority_sema_thread, NULL);
c002bf97:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002bf9e:	00 
c002bf9f:	c7 44 24 08 d1 be 02 	movl   $0xc002bed1,0x8(%esp)
c002bfa6:	c0 
c002bfa7:	89 74 24 04          	mov    %esi,0x4(%esp)
c002bfab:	89 3c 24             	mov    %edi,(%esp)
c002bfae:	e8 16 54 ff ff       	call   c00213c9 <thread_create>
c002bfb3:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002bfb6:	83 fb 0d             	cmp    $0xd,%ebx
c002bfb9:	75 a8                	jne    c002bf63 <test_priority_sema+0x6a>
c002bfbb:	b3 0a                	mov    $0xa,%bl
      sema_up (&sema);
c002bfbd:	c7 04 24 48 7b 03 c0 	movl   $0xc0037b48,(%esp)
c002bfc4:	e8 0e 6b ff ff       	call   c0022ad7 <sema_up>
      msg ("Back in main thread."); 
c002bfc9:	c7 04 24 54 0c 03 c0 	movl   $0xc0030c54,(%esp)
c002bfd0:	e8 58 e7 ff ff       	call   c002a72d <msg>
  for (i = 0; i < 10; i++) 
c002bfd5:	83 eb 01             	sub    $0x1,%ebx
c002bfd8:	75 e3                	jne    c002bfbd <test_priority_sema+0xc4>
}
c002bfda:	83 c4 3c             	add    $0x3c,%esp
c002bfdd:	5b                   	pop    %ebx
c002bfde:	5e                   	pop    %esi
c002bfdf:	5f                   	pop    %edi
c002bfe0:	5d                   	pop    %ebp
c002bfe1:	c3                   	ret    

c002bfe2 <priority_condvar_thread>:
    }
}

static void
priority_condvar_thread (void *aux UNUSED) 
{
c002bfe2:	83 ec 1c             	sub    $0x1c,%esp
  msg ("Thread %s starting.", thread_name ());
c002bfe5:	e8 7d 4d ff ff       	call   c0020d67 <thread_name>
c002bfea:	89 44 24 04          	mov    %eax,0x4(%esp)
c002bfee:	c7 04 24 90 0c 03 c0 	movl   $0xc0030c90,(%esp)
c002bff5:	e8 33 e7 ff ff       	call   c002a72d <msg>
  lock_acquire (&lock);
c002bffa:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c001:	e8 e4 6c ff ff       	call   c0022cea <lock_acquire>
  cond_wait (&condition, &lock);
c002c006:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c00d:	c0 
c002c00e:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c015:	e8 d6 6f ff ff       	call   c0022ff0 <cond_wait>
  msg ("Thread %s woke up.", thread_name ());
c002c01a:	e8 48 4d ff ff       	call   c0020d67 <thread_name>
c002c01f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c023:	c7 04 24 f0 03 03 c0 	movl   $0xc00303f0,(%esp)
c002c02a:	e8 fe e6 ff ff       	call   c002a72d <msg>
  lock_release (&lock);
c002c02f:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c036:	e8 79 6e ff ff       	call   c0022eb4 <lock_release>
}
c002c03b:	83 c4 1c             	add    $0x1c,%esp
c002c03e:	c3                   	ret    

c002c03f <test_priority_condvar>:
{
c002c03f:	55                   	push   %ebp
c002c040:	57                   	push   %edi
c002c041:	56                   	push   %esi
c002c042:	53                   	push   %ebx
c002c043:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (!thread_mlfqs);
c002c046:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c04d:	74 2c                	je     c002c07b <test_priority_condvar+0x3c>
c002c04f:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002c056:	c0 
c002c057:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c05e:	c0 
c002c05f:	c7 44 24 08 5a e0 02 	movl   $0xc002e05a,0x8(%esp)
c002c066:	c0 
c002c067:	c7 44 24 04 16 00 00 	movl   $0x16,0x4(%esp)
c002c06e:	00 
c002c06f:	c7 04 24 b4 0c 03 c0 	movl   $0xc0030cb4,(%esp)
c002c076:	e8 f8 c8 ff ff       	call   c0028973 <debug_panic>
  lock_init (&lock);
c002c07b:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c082:	e8 c6 6b ff ff       	call   c0022c4d <lock_init>
  cond_init (&condition);
c002c087:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c08e:	e8 1a 6f ff ff       	call   c0022fad <cond_init>
  thread_set_priority (PRI_MIN);
c002c093:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c09a:	e8 98 54 ff ff       	call   c0021537 <thread_set_priority>
c002c09f:	bb 07 00 00 00       	mov    $0x7,%ebx
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0a4:	bd 67 66 66 66       	mov    $0x66666667,%ebp
      snprintf (name, sizeof name, "priority %d", priority);
c002c0a9:	8d 7c 24 20          	lea    0x20(%esp),%edi
      int priority = PRI_DEFAULT - (i + 7) % 10 - 1;
c002c0ad:	89 d8                	mov    %ebx,%eax
c002c0af:	f7 ed                	imul   %ebp
c002c0b1:	c1 fa 02             	sar    $0x2,%edx
c002c0b4:	89 d8                	mov    %ebx,%eax
c002c0b6:	c1 f8 1f             	sar    $0x1f,%eax
c002c0b9:	29 c2                	sub    %eax,%edx
c002c0bb:	8d 04 92             	lea    (%edx,%edx,4),%eax
c002c0be:	01 c0                	add    %eax,%eax
c002c0c0:	29 d8                	sub    %ebx,%eax
c002c0c2:	8d 70 1e             	lea    0x1e(%eax),%esi
      snprintf (name, sizeof name, "priority %d", priority);
c002c0c5:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c0c9:	c7 44 24 08 03 04 03 	movl   $0xc0030403,0x8(%esp)
c002c0d0:	c0 
c002c0d1:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c0d8:	00 
c002c0d9:	89 3c 24             	mov    %edi,(%esp)
c002c0dc:	e8 3e b1 ff ff       	call   c002721f <snprintf>
      thread_create (name, priority, priority_condvar_thread, NULL);
c002c0e1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c0e8:	00 
c002c0e9:	c7 44 24 08 e2 bf 02 	movl   $0xc002bfe2,0x8(%esp)
c002c0f0:	c0 
c002c0f1:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c0f5:	89 3c 24             	mov    %edi,(%esp)
c002c0f8:	e8 cc 52 ff ff       	call   c00213c9 <thread_create>
c002c0fd:	83 c3 01             	add    $0x1,%ebx
  for (i = 0; i < 10; i++) 
c002c100:	83 fb 11             	cmp    $0x11,%ebx
c002c103:	75 a8                	jne    c002c0ad <test_priority_condvar+0x6e>
c002c105:	b3 0a                	mov    $0xa,%bl
      lock_acquire (&lock);
c002c107:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c10e:	e8 d7 6b ff ff       	call   c0022cea <lock_acquire>
      msg ("Signaling...");
c002c113:	c7 04 24 a4 0c 03 c0 	movl   $0xc0030ca4,(%esp)
c002c11a:	e8 0e e6 ff ff       	call   c002a72d <msg>
      cond_signal (&condition, &lock);
c002c11f:	c7 44 24 04 80 7b 03 	movl   $0xc0037b80,0x4(%esp)
c002c126:	c0 
c002c127:	c7 04 24 60 7b 03 c0 	movl   $0xc0037b60,(%esp)
c002c12e:	e8 e6 6f ff ff       	call   c0023119 <cond_signal>
      lock_release (&lock);
c002c133:	c7 04 24 80 7b 03 c0 	movl   $0xc0037b80,(%esp)
c002c13a:	e8 75 6d ff ff       	call   c0022eb4 <lock_release>
  for (i = 0; i < 10; i++) 
c002c13f:	83 eb 01             	sub    $0x1,%ebx
c002c142:	75 c3                	jne    c002c107 <test_priority_condvar+0xc8>
}
c002c144:	83 c4 3c             	add    $0x3c,%esp
c002c147:	5b                   	pop    %ebx
c002c148:	5e                   	pop    %esi
c002c149:	5f                   	pop    %edi
c002c14a:	5d                   	pop    %ebp
c002c14b:	c3                   	ret    

c002c14c <interloper_thread_func>:
                                         thread_get_priority ());
}

static void
interloper_thread_func (void *arg_ UNUSED)
{
c002c14c:	83 ec 1c             	sub    $0x1c,%esp
  msg ("%s finished.", thread_name ());
c002c14f:	e8 13 4c ff ff       	call   c0020d67 <thread_name>
c002c154:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c158:	c7 04 24 db 0c 03 c0 	movl   $0xc0030cdb,(%esp)
c002c15f:	e8 c9 e5 ff ff       	call   c002a72d <msg>
}
c002c164:	83 c4 1c             	add    $0x1c,%esp
c002c167:	c3                   	ret    

c002c168 <donor_thread_func>:
{
c002c168:	56                   	push   %esi
c002c169:	53                   	push   %ebx
c002c16a:	83 ec 14             	sub    $0x14,%esp
c002c16d:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  if (locks->first)
c002c171:	8b 43 04             	mov    0x4(%ebx),%eax
c002c174:	85 c0                	test   %eax,%eax
c002c176:	74 08                	je     c002c180 <donor_thread_func+0x18>
    lock_acquire (locks->first);
c002c178:	89 04 24             	mov    %eax,(%esp)
c002c17b:	e8 6a 6b ff ff       	call   c0022cea <lock_acquire>
  lock_acquire (locks->second);
c002c180:	8b 03                	mov    (%ebx),%eax
c002c182:	89 04 24             	mov    %eax,(%esp)
c002c185:	e8 60 6b ff ff       	call   c0022cea <lock_acquire>
  msg ("%s got lock", thread_name ());
c002c18a:	e8 d8 4b ff ff       	call   c0020d67 <thread_name>
c002c18f:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c193:	c7 04 24 e8 0c 03 c0 	movl   $0xc0030ce8,(%esp)
c002c19a:	e8 8e e5 ff ff       	call   c002a72d <msg>
  lock_release (locks->second);
c002c19f:	8b 03                	mov    (%ebx),%eax
c002c1a1:	89 04 24             	mov    %eax,(%esp)
c002c1a4:	e8 0b 6d ff ff       	call   c0022eb4 <lock_release>
  msg ("%s should have priority %d. Actual priority: %d", 
c002c1a9:	e8 56 4c ff ff       	call   c0020e04 <thread_get_priority>
c002c1ae:	89 c6                	mov    %eax,%esi
c002c1b0:	e8 b2 4b ff ff       	call   c0020d67 <thread_name>
c002c1b5:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002c1b9:	c7 44 24 08 15 00 00 	movl   $0x15,0x8(%esp)
c002c1c0:	00 
c002c1c1:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1c5:	c7 04 24 10 0d 03 c0 	movl   $0xc0030d10,(%esp)
c002c1cc:	e8 5c e5 ff ff       	call   c002a72d <msg>
  if (locks->first)
c002c1d1:	8b 43 04             	mov    0x4(%ebx),%eax
c002c1d4:	85 c0                	test   %eax,%eax
c002c1d6:	74 08                	je     c002c1e0 <donor_thread_func+0x78>
    lock_release (locks->first);
c002c1d8:	89 04 24             	mov    %eax,(%esp)
c002c1db:	e8 d4 6c ff ff       	call   c0022eb4 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c1e0:	e8 1f 4c ff ff       	call   c0020e04 <thread_get_priority>
c002c1e5:	89 c3                	mov    %eax,%ebx
c002c1e7:	e8 7b 4b ff ff       	call   c0020d67 <thread_name>
c002c1ec:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c1f0:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c1f4:	c7 04 24 40 0d 03 c0 	movl   $0xc0030d40,(%esp)
c002c1fb:	e8 2d e5 ff ff       	call   c002a72d <msg>
}
c002c200:	83 c4 14             	add    $0x14,%esp
c002c203:	5b                   	pop    %ebx
c002c204:	5e                   	pop    %esi
c002c205:	c3                   	ret    

c002c206 <test_priority_donate_chain>:
{
c002c206:	55                   	push   %ebp
c002c207:	57                   	push   %edi
c002c208:	56                   	push   %esi
c002c209:	53                   	push   %ebx
c002c20a:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
  ASSERT (!thread_mlfqs);
c002c210:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c217:	74 2c                	je     c002c245 <test_priority_donate_chain+0x3f>
c002c219:	c7 44 24 10 fc 00 03 	movl   $0xc00300fc,0x10(%esp)
c002c220:	c0 
c002c221:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c228:	c0 
c002c229:	c7 44 24 08 70 e0 02 	movl   $0xc002e070,0x8(%esp)
c002c230:	c0 
c002c231:	c7 44 24 04 34 00 00 	movl   $0x34,0x4(%esp)
c002c238:	00 
c002c239:	c7 04 24 60 0d 03 c0 	movl   $0xc0030d60,(%esp)
c002c240:	e8 2e c7 ff ff       	call   c0028973 <debug_panic>
  thread_set_priority (PRI_MIN);
c002c245:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c002c24c:	e8 e6 52 ff ff       	call   c0021537 <thread_set_priority>
c002c251:	8d 5c 24 74          	lea    0x74(%esp),%ebx
c002c255:	8d b4 24 70 01 00 00 	lea    0x170(%esp),%esi
    lock_init (&locks[i]);
c002c25c:	89 1c 24             	mov    %ebx,(%esp)
c002c25f:	e8 e9 69 ff ff       	call   c0022c4d <lock_init>
c002c264:	83 c3 24             	add    $0x24,%ebx
  for (i = 0; i < NESTING_DEPTH - 1; i++)
c002c267:	39 f3                	cmp    %esi,%ebx
c002c269:	75 f1                	jne    c002c25c <test_priority_donate_chain+0x56>
  lock_acquire (&locks[0]);
c002c26b:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c26f:	89 04 24             	mov    %eax,(%esp)
c002c272:	e8 73 6a ff ff       	call   c0022cea <lock_acquire>
  msg ("%s got lock.", thread_name ());
c002c277:	e8 eb 4a ff ff       	call   c0020d67 <thread_name>
c002c27c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c280:	c7 04 24 f4 0c 03 c0 	movl   $0xc0030cf4,(%esp)
c002c287:	e8 a1 e4 ff ff       	call   c002a72d <msg>
c002c28c:	8d 84 24 98 00 00 00 	lea    0x98(%esp),%eax
c002c293:	89 44 24 14          	mov    %eax,0x14(%esp)
c002c297:	8d 74 24 40          	lea    0x40(%esp),%esi
c002c29b:	bf 03 00 00 00       	mov    $0x3,%edi
  for (i = 1; i < NESTING_DEPTH; i++)
c002c2a0:	bb 01 00 00 00       	mov    $0x1,%ebx
      snprintf (name, sizeof name, "thread %d", i);
c002c2a5:	8d 6c 24 24          	lea    0x24(%esp),%ebp
c002c2a9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c2ad:	c7 44 24 08 19 01 03 	movl   $0xc0030119,0x8(%esp)
c002c2b4:	c0 
c002c2b5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c2bc:	00 
c002c2bd:	89 2c 24             	mov    %ebp,(%esp)
c002c2c0:	e8 5a af ff ff       	call   c002721f <snprintf>
      lock_pairs[i].first = i < NESTING_DEPTH - 1 ? locks + i: NULL;
c002c2c5:	83 fb 06             	cmp    $0x6,%ebx
c002c2c8:	b8 00 00 00 00       	mov    $0x0,%eax
c002c2cd:	8b 54 24 14          	mov    0x14(%esp),%edx
c002c2d1:	0f 4e c2             	cmovle %edx,%eax
c002c2d4:	89 06                	mov    %eax,(%esi)
c002c2d6:	89 d0                	mov    %edx,%eax
c002c2d8:	83 e8 24             	sub    $0x24,%eax
c002c2db:	89 46 fc             	mov    %eax,-0x4(%esi)
c002c2de:	8d 46 fc             	lea    -0x4(%esi),%eax
      thread_create (name, thread_priority, donor_thread_func, lock_pairs + i);
c002c2e1:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c2e5:	c7 44 24 08 68 c1 02 	movl   $0xc002c168,0x8(%esp)
c002c2ec:	c0 
c002c2ed:	89 7c 24 18          	mov    %edi,0x18(%esp)
c002c2f1:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c2f5:	89 2c 24             	mov    %ebp,(%esp)
c002c2f8:	e8 cc 50 ff ff       	call   c00213c9 <thread_create>
      msg ("%s should have priority %d.  Actual priority: %d.",
c002c2fd:	e8 02 4b ff ff       	call   c0020e04 <thread_get_priority>
c002c302:	89 44 24 1c          	mov    %eax,0x1c(%esp)
c002c306:	e8 5c 4a ff ff       	call   c0020d67 <thread_name>
c002c30b:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c30f:	89 54 24 0c          	mov    %edx,0xc(%esp)
c002c313:	8b 4c 24 18          	mov    0x18(%esp),%ecx
c002c317:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c002c31b:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c31f:	c7 04 24 8c 0d 03 c0 	movl   $0xc0030d8c,(%esp)
c002c326:	e8 02 e4 ff ff       	call   c002a72d <msg>
      snprintf (name, sizeof name, "interloper %d", i);
c002c32b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c32f:	c7 44 24 08 01 0d 03 	movl   $0xc0030d01,0x8(%esp)
c002c336:	c0 
c002c337:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c33e:	00 
c002c33f:	89 2c 24             	mov    %ebp,(%esp)
c002c342:	e8 d8 ae ff ff       	call   c002721f <snprintf>
      thread_create (name, thread_priority - 1, interloper_thread_func, NULL);
c002c347:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c34e:	00 
c002c34f:	c7 44 24 08 4c c1 02 	movl   $0xc002c14c,0x8(%esp)
c002c356:	c0 
c002c357:	8d 47 ff             	lea    -0x1(%edi),%eax
c002c35a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c35e:	89 2c 24             	mov    %ebp,(%esp)
c002c361:	e8 63 50 ff ff       	call   c00213c9 <thread_create>
  for (i = 1; i < NESTING_DEPTH; i++)
c002c366:	83 c3 01             	add    $0x1,%ebx
c002c369:	83 44 24 14 24       	addl   $0x24,0x14(%esp)
c002c36e:	83 c6 08             	add    $0x8,%esi
c002c371:	83 c7 03             	add    $0x3,%edi
c002c374:	83 fb 08             	cmp    $0x8,%ebx
c002c377:	0f 85 2c ff ff ff    	jne    c002c2a9 <test_priority_donate_chain+0xa3>
  lock_release (&locks[0]);
c002c37d:	8d 44 24 74          	lea    0x74(%esp),%eax
c002c381:	89 04 24             	mov    %eax,(%esp)
c002c384:	e8 2b 6b ff ff       	call   c0022eb4 <lock_release>
  msg ("%s finishing with priority %d.", thread_name (),
c002c389:	e8 76 4a ff ff       	call   c0020e04 <thread_get_priority>
c002c38e:	89 c3                	mov    %eax,%ebx
c002c390:	e8 d2 49 ff ff       	call   c0020d67 <thread_name>
c002c395:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c399:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c39d:	c7 04 24 40 0d 03 c0 	movl   $0xc0030d40,(%esp)
c002c3a4:	e8 84 e3 ff ff       	call   c002a72d <msg>
}
c002c3a9:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002c3af:	5b                   	pop    %ebx
c002c3b0:	5e                   	pop    %esi
c002c3b1:	5f                   	pop    %edi
c002c3b2:	5d                   	pop    %ebp
c002c3b3:	c3                   	ret    
c002c3b4:	90                   	nop
c002c3b5:	90                   	nop
c002c3b6:	90                   	nop
c002c3b7:	90                   	nop
c002c3b8:	90                   	nop
c002c3b9:	90                   	nop
c002c3ba:	90                   	nop
c002c3bb:	90                   	nop
c002c3bc:	90                   	nop
c002c3bd:	90                   	nop
c002c3be:	90                   	nop
c002c3bf:	90                   	nop

c002c3c0 <test_mlfqs_load_1>:
#include "threads/thread.h"
#include "devices/timer.h"

void
test_mlfqs_load_1 (void) 
{
c002c3c0:	57                   	push   %edi
c002c3c1:	56                   	push   %esi
c002c3c2:	53                   	push   %ebx
c002c3c3:	83 ec 20             	sub    $0x20,%esp
  int64_t start_time;
  int elapsed;
  int load_avg;
  
  ASSERT (thread_mlfqs);
c002c3c6:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c3cd:	75 2c                	jne    c002c3fb <test_mlfqs_load_1+0x3b>
c002c3cf:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002c3d6:	c0 
c002c3d7:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c3de:	c0 
c002c3df:	c7 44 24 08 8b e0 02 	movl   $0xc002e08b,0x8(%esp)
c002c3e6:	c0 
c002c3e7:	c7 44 24 04 18 00 00 	movl   $0x18,0x4(%esp)
c002c3ee:	00 
c002c3ef:	c7 04 24 e8 0d 03 c0 	movl   $0xc0030de8,(%esp)
c002c3f6:	e8 78 c5 ff ff       	call   c0028973 <debug_panic>

  msg ("spinning for up to 45 seconds, please wait...");
c002c3fb:	c7 04 24 0c 0e 03 c0 	movl   $0xc0030e0c,(%esp)
c002c402:	e8 26 e3 ff ff       	call   c002a72d <msg>

  start_time = timer_ticks ();
c002c407:	e8 f8 7d ff ff       	call   c0024204 <timer_ticks>
c002c40c:	89 44 24 18          	mov    %eax,0x18(%esp)
c002c410:	89 54 24 1c          	mov    %edx,0x1c(%esp)
    {
      load_avg = thread_get_load_avg ();
      ASSERT (load_avg >= 0);
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
      if (load_avg > 100)
        fail ("load average is %d.%02d "
c002c414:	bf 1f 85 eb 51       	mov    $0x51eb851f,%edi
      load_avg = thread_get_load_avg ();
c002c419:	e8 04 4a ff ff       	call   c0020e22 <thread_get_load_avg>
c002c41e:	89 c3                	mov    %eax,%ebx
      ASSERT (load_avg >= 0);
c002c420:	85 c0                	test   %eax,%eax
c002c422:	79 2c                	jns    c002c450 <test_mlfqs_load_1+0x90>
c002c424:	c7 44 24 10 be 0d 03 	movl   $0xc0030dbe,0x10(%esp)
c002c42b:	c0 
c002c42c:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c433:	c0 
c002c434:	c7 44 24 08 8b e0 02 	movl   $0xc002e08b,0x8(%esp)
c002c43b:	c0 
c002c43c:	c7 44 24 04 20 00 00 	movl   $0x20,0x4(%esp)
c002c443:	00 
c002c444:	c7 04 24 e8 0d 03 c0 	movl   $0xc0030de8,(%esp)
c002c44b:	e8 23 c5 ff ff       	call   c0028973 <debug_panic>
      elapsed = timer_elapsed (start_time) / TIMER_FREQ;
c002c450:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c454:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c458:	89 04 24             	mov    %eax,(%esp)
c002c45b:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c45f:	e8 cc 7d ff ff       	call   c0024230 <timer_elapsed>
c002c464:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c46b:	00 
c002c46c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c473:	00 
c002c474:	89 04 24             	mov    %eax,(%esp)
c002c477:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c47b:	e8 53 be ff ff       	call   c00282d3 <__divdi3>
c002c480:	89 c6                	mov    %eax,%esi
      if (load_avg > 100)
c002c482:	83 fb 64             	cmp    $0x64,%ebx
c002c485:	7e 30                	jle    c002c4b7 <test_mlfqs_load_1+0xf7>
        fail ("load average is %d.%02d "
c002c487:	89 44 24 0c          	mov    %eax,0xc(%esp)
c002c48b:	89 d8                	mov    %ebx,%eax
c002c48d:	f7 ef                	imul   %edi
c002c48f:	c1 fa 05             	sar    $0x5,%edx
c002c492:	89 d8                	mov    %ebx,%eax
c002c494:	c1 f8 1f             	sar    $0x1f,%eax
c002c497:	29 c2                	sub    %eax,%edx
c002c499:	6b c2 64             	imul   $0x64,%edx,%eax
c002c49c:	29 c3                	sub    %eax,%ebx
c002c49e:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c4a2:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c4a6:	c7 04 24 3c 0e 03 c0 	movl   $0xc0030e3c,(%esp)
c002c4ad:	e8 33 e3 ff ff       	call   c002a7e5 <fail>
c002c4b2:	e9 62 ff ff ff       	jmp    c002c419 <test_mlfqs_load_1+0x59>
              "but should be between 0 and 1 (after %d seconds)",
              load_avg / 100, load_avg % 100, elapsed);
      else if (load_avg > 50)
c002c4b7:	83 fb 32             	cmp    $0x32,%ebx
c002c4ba:	7f 1b                	jg     c002c4d7 <test_mlfqs_load_1+0x117>
        break;
      else if (elapsed > 45)
c002c4bc:	83 f8 2d             	cmp    $0x2d,%eax
c002c4bf:	90                   	nop
c002c4c0:	0f 8e 53 ff ff ff    	jle    c002c419 <test_mlfqs_load_1+0x59>
        fail ("load average stayed below 0.5 for more than 45 seconds");
c002c4c6:	c7 04 24 88 0e 03 c0 	movl   $0xc0030e88,(%esp)
c002c4cd:	e8 13 e3 ff ff       	call   c002a7e5 <fail>
c002c4d2:	e9 42 ff ff ff       	jmp    c002c419 <test_mlfqs_load_1+0x59>
    }

  if (elapsed < 38)
c002c4d7:	83 f8 25             	cmp    $0x25,%eax
c002c4da:	7f 10                	jg     c002c4ec <test_mlfqs_load_1+0x12c>
    fail ("load average took only %d seconds to rise above 0.5", elapsed);
c002c4dc:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c4e0:	c7 04 24 c0 0e 03 c0 	movl   $0xc0030ec0,(%esp)
c002c4e7:	e8 f9 e2 ff ff       	call   c002a7e5 <fail>
  msg ("load average rose to 0.5 after %d seconds", elapsed);
c002c4ec:	89 74 24 04          	mov    %esi,0x4(%esp)
c002c4f0:	c7 04 24 f4 0e 03 c0 	movl   $0xc0030ef4,(%esp)
c002c4f7:	e8 31 e2 ff ff       	call   c002a72d <msg>

  msg ("sleeping for another 10 seconds, please wait...");
c002c4fc:	c7 04 24 20 0f 03 c0 	movl   $0xc0030f20,(%esp)
c002c503:	e8 25 e2 ff ff       	call   c002a72d <msg>
  timer_sleep (TIMER_FREQ * 10);
c002c508:	c7 04 24 e8 03 00 00 	movl   $0x3e8,(%esp)
c002c50f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002c516:	00 
c002c517:	e8 30 7d ff ff       	call   c002424c <timer_sleep>

  load_avg = thread_get_load_avg ();
c002c51c:	e8 01 49 ff ff       	call   c0020e22 <thread_get_load_avg>
c002c521:	89 c3                	mov    %eax,%ebx
  if (load_avg < 0)
c002c523:	85 c0                	test   %eax,%eax
c002c525:	79 0c                	jns    c002c533 <test_mlfqs_load_1+0x173>
    fail ("load average fell below 0");
c002c527:	c7 04 24 cc 0d 03 c0 	movl   $0xc0030dcc,(%esp)
c002c52e:	e8 b2 e2 ff ff       	call   c002a7e5 <fail>
  if (load_avg > 50)
c002c533:	83 fb 32             	cmp    $0x32,%ebx
c002c536:	7e 0c                	jle    c002c544 <test_mlfqs_load_1+0x184>
    fail ("load average stayed above 0.5 for more than 10 seconds");
c002c538:	c7 04 24 50 0f 03 c0 	movl   $0xc0030f50,(%esp)
c002c53f:	e8 a1 e2 ff ff       	call   c002a7e5 <fail>
  msg ("load average fell back below 0.5 (to %d.%02d)",
c002c544:	ba 1f 85 eb 51       	mov    $0x51eb851f,%edx
c002c549:	89 d8                	mov    %ebx,%eax
c002c54b:	f7 ea                	imul   %edx
c002c54d:	c1 fa 05             	sar    $0x5,%edx
c002c550:	89 d8                	mov    %ebx,%eax
c002c552:	c1 f8 1f             	sar    $0x1f,%eax
c002c555:	29 c2                	sub    %eax,%edx
c002c557:	6b c2 64             	imul   $0x64,%edx,%eax
c002c55a:	29 c3                	sub    %eax,%ebx
c002c55c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c002c560:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c564:	c7 04 24 88 0f 03 c0 	movl   $0xc0030f88,(%esp)
c002c56b:	e8 bd e1 ff ff       	call   c002a72d <msg>
       load_avg / 100, load_avg % 100);

  pass ();
c002c570:	e8 cc e2 ff ff       	call   c002a841 <pass>
}
c002c575:	83 c4 20             	add    $0x20,%esp
c002c578:	5b                   	pop    %ebx
c002c579:	5e                   	pop    %esi
c002c57a:	5f                   	pop    %edi
c002c57b:	c3                   	ret    
c002c57c:	90                   	nop
c002c57d:	90                   	nop
c002c57e:	90                   	nop
c002c57f:	90                   	nop

c002c580 <load_thread>:
    }
}

static void
load_thread (void *aux UNUSED) 
{
c002c580:	53                   	push   %ebx
c002c581:	83 ec 18             	sub    $0x18,%esp
  int64_t sleep_time = 10 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 60 * TIMER_FREQ;
  int64_t exit_time = spin_time + 60 * TIMER_FREQ;

  thread_set_nice (20);
c002c584:	c7 04 24 14 00 00 00 	movl   $0x14,(%esp)
c002c58b:	e8 5f 50 ff ff       	call   c00215ef <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c590:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c595:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c59b:	89 04 24             	mov    %eax,(%esp)
c002c59e:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5a2:	e8 89 7c ff ff       	call   c0024230 <timer_elapsed>
c002c5a7:	b9 e8 03 00 00       	mov    $0x3e8,%ecx
c002c5ac:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c5b1:	29 c1                	sub    %eax,%ecx
c002c5b3:	19 d3                	sbb    %edx,%ebx
c002c5b5:	89 0c 24             	mov    %ecx,(%esp)
c002c5b8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c5bc:	e8 8b 7c ff ff       	call   c002424c <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c5c1:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5c6:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5cc:	89 04 24             	mov    %eax,(%esp)
c002c5cf:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5d3:	e8 58 7c ff ff       	call   c0024230 <timer_elapsed>
c002c5d8:	85 d2                	test   %edx,%edx
c002c5da:	7f 0b                	jg     c002c5e7 <load_thread+0x67>
c002c5dc:	85 d2                	test   %edx,%edx
c002c5de:	78 e1                	js     c002c5c1 <load_thread+0x41>
c002c5e0:	3d 57 1b 00 00       	cmp    $0x1b57,%eax
c002c5e5:	76 da                	jbe    c002c5c1 <load_thread+0x41>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c5e7:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c5ec:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c5f2:	89 04 24             	mov    %eax,(%esp)
c002c5f5:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c5f9:	e8 32 7c ff ff       	call   c0024230 <timer_elapsed>
c002c5fe:	b9 c8 32 00 00       	mov    $0x32c8,%ecx
c002c603:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c608:	29 c1                	sub    %eax,%ecx
c002c60a:	19 d3                	sbb    %edx,%ebx
c002c60c:	89 0c 24             	mov    %ecx,(%esp)
c002c60f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c613:	e8 34 7c ff ff       	call   c002424c <timer_sleep>
}
c002c618:	83 c4 18             	add    $0x18,%esp
c002c61b:	5b                   	pop    %ebx
c002c61c:	c3                   	ret    

c002c61d <test_mlfqs_load_60>:
{
c002c61d:	55                   	push   %ebp
c002c61e:	57                   	push   %edi
c002c61f:	56                   	push   %esi
c002c620:	53                   	push   %ebx
c002c621:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c624:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c62b:	75 2c                	jne    c002c659 <test_mlfqs_load_60+0x3c>
c002c62d:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002c634:	c0 
c002c635:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c63c:	c0 
c002c63d:	c7 44 24 08 9d e0 02 	movl   $0xc002e09d,0x8(%esp)
c002c644:	c0 
c002c645:	c7 44 24 04 77 00 00 	movl   $0x77,0x4(%esp)
c002c64c:	00 
c002c64d:	c7 04 24 c0 0f 03 c0 	movl   $0xc0030fc0,(%esp)
c002c654:	e8 1a c3 ff ff       	call   c0028973 <debug_panic>
  start_time = timer_ticks ();
c002c659:	e8 a6 7b ff ff       	call   c0024204 <timer_ticks>
c002c65e:	a3 a8 7b 03 c0       	mov    %eax,0xc0037ba8
c002c663:	89 15 ac 7b 03 c0    	mov    %edx,0xc0037bac
  msg ("Starting %d niced load threads...", THREAD_CNT);
c002c669:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c670:	00 
c002c671:	c7 04 24 e4 0f 03 c0 	movl   $0xc0030fe4,(%esp)
c002c678:	e8 b0 e0 ff ff       	call   c002a72d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c67d:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c682:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c686:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c68a:	c7 44 24 08 b6 0f 03 	movl   $0xc0030fb6,0x8(%esp)
c002c691:	c0 
c002c692:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c699:	00 
c002c69a:	89 34 24             	mov    %esi,(%esp)
c002c69d:	e8 7d ab ff ff       	call   c002721f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, NULL);
c002c6a2:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c6a9:	00 
c002c6aa:	c7 44 24 08 80 c5 02 	movl   $0xc002c580,0x8(%esp)
c002c6b1:	c0 
c002c6b2:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c6b9:	00 
c002c6ba:	89 34 24             	mov    %esi,(%esp)
c002c6bd:	e8 07 4d ff ff       	call   c00213c9 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c6c2:	83 c3 01             	add    $0x1,%ebx
c002c6c5:	83 fb 3c             	cmp    $0x3c,%ebx
c002c6c8:	75 bc                	jne    c002c686 <test_mlfqs_load_60+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c6ca:	a1 a8 7b 03 c0       	mov    0xc0037ba8,%eax
c002c6cf:	8b 15 ac 7b 03 c0    	mov    0xc0037bac,%edx
c002c6d5:	89 04 24             	mov    %eax,(%esp)
c002c6d8:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c6dc:	e8 4f 7b ff ff       	call   c0024230 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c6e1:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c6e8:	00 
c002c6e9:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c6f0:	00 
c002c6f1:	89 04 24             	mov    %eax,(%esp)
c002c6f4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c6f8:	e8 d6 bb ff ff       	call   c00282d3 <__divdi3>
c002c6fd:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c701:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c705:	c7 04 24 08 10 03 c0 	movl   $0xc0031008,(%esp)
c002c70c:	e8 1c e0 ff ff       	call   c002a72d <msg>
c002c711:	b3 00                	mov    $0x0,%bl
c002c713:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c718:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c71d:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c722:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c726:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c72a:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c72e:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c732:	03 05 a8 7b 03 c0    	add    0xc0037ba8,%eax
c002c738:	13 15 ac 7b 03 c0    	adc    0xc0037bac,%edx
c002c73e:	89 c6                	mov    %eax,%esi
c002c740:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c742:	e8 bd 7a ff ff       	call   c0024204 <timer_ticks>
c002c747:	29 c6                	sub    %eax,%esi
c002c749:	19 d7                	sbb    %edx,%edi
c002c74b:	89 34 24             	mov    %esi,(%esp)
c002c74e:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c752:	e8 f5 7a ff ff       	call   c002424c <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c757:	e8 c6 46 ff ff       	call   c0020e22 <thread_get_load_avg>
c002c75c:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c75e:	f7 ed                	imul   %ebp
c002c760:	c1 fa 05             	sar    $0x5,%edx
c002c763:	89 c8                	mov    %ecx,%eax
c002c765:	c1 f8 1f             	sar    $0x1f,%eax
c002c768:	29 c2                	sub    %eax,%edx
c002c76a:	6b c2 64             	imul   $0x64,%edx,%eax
c002c76d:	29 c1                	sub    %eax,%ecx
c002c76f:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c773:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c777:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c77b:	c7 04 24 2c 10 03 c0 	movl   $0xc003102c,(%esp)
c002c782:	e8 a6 df ff ff       	call   c002a72d <msg>
c002c787:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c78e:	00 
c002c78f:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c794:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c797:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c79d:	75 8b                	jne    c002c72a <test_mlfqs_load_60+0x10d>
}
c002c79f:	83 c4 3c             	add    $0x3c,%esp
c002c7a2:	5b                   	pop    %ebx
c002c7a3:	5e                   	pop    %esi
c002c7a4:	5f                   	pop    %edi
c002c7a5:	5d                   	pop    %ebp
c002c7a6:	c3                   	ret    
c002c7a7:	90                   	nop
c002c7a8:	90                   	nop
c002c7a9:	90                   	nop
c002c7aa:	90                   	nop
c002c7ab:	90                   	nop
c002c7ac:	90                   	nop
c002c7ad:	90                   	nop
c002c7ae:	90                   	nop
c002c7af:	90                   	nop

c002c7b0 <load_thread>:
    }
}

static void
load_thread (void *seq_no_) 
{
c002c7b0:	57                   	push   %edi
c002c7b1:	56                   	push   %esi
c002c7b2:	53                   	push   %ebx
c002c7b3:	83 ec 10             	sub    $0x10,%esp
  int seq_no = (int) seq_no_;
  int sleep_time = TIMER_FREQ * (10 + seq_no);
c002c7b6:	8b 44 24 20          	mov    0x20(%esp),%eax
c002c7ba:	8d 70 0a             	lea    0xa(%eax),%esi
c002c7bd:	6b f6 64             	imul   $0x64,%esi,%esi
  int spin_time = sleep_time + TIMER_FREQ * THREAD_CNT;
c002c7c0:	8d 9e 70 17 00 00    	lea    0x1770(%esi),%ebx
  int exit_time = TIMER_FREQ * (THREAD_CNT * 2);

  timer_sleep (sleep_time - timer_elapsed (start_time));
c002c7c6:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c7cb:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c7d1:	89 04 24             	mov    %eax,(%esp)
c002c7d4:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c7d8:	e8 53 7a ff ff       	call   c0024230 <timer_elapsed>
c002c7dd:	89 f7                	mov    %esi,%edi
c002c7df:	c1 ff 1f             	sar    $0x1f,%edi
c002c7e2:	29 c6                	sub    %eax,%esi
c002c7e4:	19 d7                	sbb    %edx,%edi
c002c7e6:	89 34 24             	mov    %esi,(%esp)
c002c7e9:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c7ed:	e8 5a 7a ff ff       	call   c002424c <timer_sleep>
  while (timer_elapsed (start_time) < spin_time)
c002c7f2:	89 df                	mov    %ebx,%edi
c002c7f4:	c1 ff 1f             	sar    $0x1f,%edi
c002c7f7:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c7fc:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c802:	89 04 24             	mov    %eax,(%esp)
c002c805:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c809:	e8 22 7a ff ff       	call   c0024230 <timer_elapsed>
c002c80e:	39 fa                	cmp    %edi,%edx
c002c810:	7f 06                	jg     c002c818 <load_thread+0x68>
c002c812:	7c e3                	jl     c002c7f7 <load_thread+0x47>
c002c814:	39 d8                	cmp    %ebx,%eax
c002c816:	72 df                	jb     c002c7f7 <load_thread+0x47>
    continue;
  timer_sleep (exit_time - timer_elapsed (start_time));
c002c818:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c81d:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c823:	89 04 24             	mov    %eax,(%esp)
c002c826:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c82a:	e8 01 7a ff ff       	call   c0024230 <timer_elapsed>
c002c82f:	b9 e0 2e 00 00       	mov    $0x2ee0,%ecx
c002c834:	bb 00 00 00 00       	mov    $0x0,%ebx
c002c839:	29 c1                	sub    %eax,%ecx
c002c83b:	19 d3                	sbb    %edx,%ebx
c002c83d:	89 0c 24             	mov    %ecx,(%esp)
c002c840:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c844:	e8 03 7a ff ff       	call   c002424c <timer_sleep>
}
c002c849:	83 c4 10             	add    $0x10,%esp
c002c84c:	5b                   	pop    %ebx
c002c84d:	5e                   	pop    %esi
c002c84e:	5f                   	pop    %edi
c002c84f:	c3                   	ret    

c002c850 <test_mlfqs_load_avg>:
{
c002c850:	55                   	push   %ebp
c002c851:	57                   	push   %edi
c002c852:	56                   	push   %esi
c002c853:	53                   	push   %ebx
c002c854:	83 ec 3c             	sub    $0x3c,%esp
  ASSERT (thread_mlfqs);
c002c857:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c85e:	75 2c                	jne    c002c88c <test_mlfqs_load_avg+0x3c>
c002c860:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002c867:	c0 
c002c868:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002c86f:	c0 
c002c870:	c7 44 24 08 b0 e0 02 	movl   $0xc002e0b0,0x8(%esp)
c002c877:	c0 
c002c878:	c7 44 24 04 82 00 00 	movl   $0x82,0x4(%esp)
c002c87f:	00 
c002c880:	c7 04 24 70 10 03 c0 	movl   $0xc0031070,(%esp)
c002c887:	e8 e7 c0 ff ff       	call   c0028973 <debug_panic>
  start_time = timer_ticks ();
c002c88c:	e8 73 79 ff ff       	call   c0024204 <timer_ticks>
c002c891:	a3 b0 7b 03 c0       	mov    %eax,0xc0037bb0
c002c896:	89 15 b4 7b 03 c0    	mov    %edx,0xc0037bb4
  msg ("Starting %d load threads...", THREAD_CNT);
c002c89c:	c7 44 24 04 3c 00 00 	movl   $0x3c,0x4(%esp)
c002c8a3:	00 
c002c8a4:	c7 04 24 54 10 03 c0 	movl   $0xc0031054,(%esp)
c002c8ab:	e8 7d de ff ff       	call   c002a72d <msg>
  for (i = 0; i < THREAD_CNT; i++) 
c002c8b0:	bb 00 00 00 00       	mov    $0x0,%ebx
      snprintf(name, sizeof name, "load %d", i);
c002c8b5:	8d 74 24 20          	lea    0x20(%esp),%esi
c002c8b9:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c8bd:	c7 44 24 08 b6 0f 03 	movl   $0xc0030fb6,0x8(%esp)
c002c8c4:	c0 
c002c8c5:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002c8cc:	00 
c002c8cd:	89 34 24             	mov    %esi,(%esp)
c002c8d0:	e8 4a a9 ff ff       	call   c002721f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, (void *) i);
c002c8d5:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002c8d9:	c7 44 24 08 b0 c7 02 	movl   $0xc002c7b0,0x8(%esp)
c002c8e0:	c0 
c002c8e1:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002c8e8:	00 
c002c8e9:	89 34 24             	mov    %esi,(%esp)
c002c8ec:	e8 d8 4a ff ff       	call   c00213c9 <thread_create>
  for (i = 0; i < THREAD_CNT; i++) 
c002c8f1:	83 c3 01             	add    $0x1,%ebx
c002c8f4:	83 fb 3c             	cmp    $0x3c,%ebx
c002c8f7:	75 c0                	jne    c002c8b9 <test_mlfqs_load_avg+0x69>
       timer_elapsed (start_time) / TIMER_FREQ);
c002c8f9:	a1 b0 7b 03 c0       	mov    0xc0037bb0,%eax
c002c8fe:	8b 15 b4 7b 03 c0    	mov    0xc0037bb4,%edx
c002c904:	89 04 24             	mov    %eax,(%esp)
c002c907:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c90b:	e8 20 79 ff ff       	call   c0024230 <timer_elapsed>
  msg ("Starting threads took %d seconds.",
c002c910:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002c917:	00 
c002c918:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002c91f:	00 
c002c920:	89 04 24             	mov    %eax,(%esp)
c002c923:	89 54 24 04          	mov    %edx,0x4(%esp)
c002c927:	e8 a7 b9 ff ff       	call   c00282d3 <__divdi3>
c002c92c:	89 44 24 04          	mov    %eax,0x4(%esp)
c002c930:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c934:	c7 04 24 08 10 03 c0 	movl   $0xc0031008,(%esp)
c002c93b:	e8 ed dd ff ff       	call   c002a72d <msg>
  thread_set_nice (-20);
c002c940:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002c947:	e8 a3 4c ff ff       	call   c00215ef <thread_set_nice>
c002c94c:	b3 00                	mov    $0x0,%bl
c002c94e:	be e8 03 00 00       	mov    $0x3e8,%esi
c002c953:	bf 00 00 00 00       	mov    $0x0,%edi
      msg ("After %d seconds, load average=%d.%02d.",
c002c958:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002c95d:	89 74 24 18          	mov    %esi,0x18(%esp)
c002c961:	89 7c 24 1c          	mov    %edi,0x1c(%esp)
      int64_t sleep_until = start_time + TIMER_FREQ * (2 * i + 10);
c002c965:	8b 44 24 18          	mov    0x18(%esp),%eax
c002c969:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002c96d:	03 05 b0 7b 03 c0    	add    0xc0037bb0,%eax
c002c973:	13 15 b4 7b 03 c0    	adc    0xc0037bb4,%edx
c002c979:	89 c6                	mov    %eax,%esi
c002c97b:	89 d7                	mov    %edx,%edi
      timer_sleep (sleep_until - timer_ticks ());
c002c97d:	e8 82 78 ff ff       	call   c0024204 <timer_ticks>
c002c982:	29 c6                	sub    %eax,%esi
c002c984:	19 d7                	sbb    %edx,%edi
c002c986:	89 34 24             	mov    %esi,(%esp)
c002c989:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002c98d:	e8 ba 78 ff ff       	call   c002424c <timer_sleep>
      load_avg = thread_get_load_avg ();
c002c992:	e8 8b 44 ff ff       	call   c0020e22 <thread_get_load_avg>
c002c997:	89 c1                	mov    %eax,%ecx
      msg ("After %d seconds, load average=%d.%02d.",
c002c999:	f7 ed                	imul   %ebp
c002c99b:	c1 fa 05             	sar    $0x5,%edx
c002c99e:	89 c8                	mov    %ecx,%eax
c002c9a0:	c1 f8 1f             	sar    $0x1f,%eax
c002c9a3:	29 c2                	sub    %eax,%edx
c002c9a5:	6b c2 64             	imul   $0x64,%edx,%eax
c002c9a8:	29 c1                	sub    %eax,%ecx
c002c9aa:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c002c9ae:	89 54 24 08          	mov    %edx,0x8(%esp)
c002c9b2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002c9b6:	c7 04 24 2c 10 03 c0 	movl   $0xc003102c,(%esp)
c002c9bd:	e8 6b dd ff ff       	call   c002a72d <msg>
c002c9c2:	81 44 24 18 c8 00 00 	addl   $0xc8,0x18(%esp)
c002c9c9:	00 
c002c9ca:	83 54 24 1c 00       	adcl   $0x0,0x1c(%esp)
c002c9cf:	83 c3 02             	add    $0x2,%ebx
  for (i = 0; i < 90; i++) 
c002c9d2:	81 fb b4 00 00 00    	cmp    $0xb4,%ebx
c002c9d8:	75 8b                	jne    c002c965 <test_mlfqs_load_avg+0x115>
}
c002c9da:	83 c4 3c             	add    $0x3c,%esp
c002c9dd:	5b                   	pop    %ebx
c002c9de:	5e                   	pop    %esi
c002c9df:	5f                   	pop    %edi
c002c9e0:	5d                   	pop    %ebp
c002c9e1:	c3                   	ret    

c002c9e2 <test_mlfqs_recent_1>:
/* Sensitive to assumption that recent_cpu updates happen exactly
   when timer_ticks() % TIMER_FREQ == 0. */

void
test_mlfqs_recent_1 (void) 
{
c002c9e2:	55                   	push   %ebp
c002c9e3:	57                   	push   %edi
c002c9e4:	56                   	push   %esi
c002c9e5:	53                   	push   %ebx
c002c9e6:	83 ec 2c             	sub    $0x2c,%esp
  int64_t start_time;
  int last_elapsed = 0;
  
  ASSERT (thread_mlfqs);
c002c9e9:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002c9f0:	75 2c                	jne    c002ca1e <test_mlfqs_recent_1+0x3c>
c002c9f2:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002c9f9:	c0 
c002c9fa:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002ca01:	c0 
c002ca02:	c7 44 24 08 c4 e0 02 	movl   $0xc002e0c4,0x8(%esp)
c002ca09:	c0 
c002ca0a:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
c002ca11:	00 
c002ca12:	c7 04 24 98 10 03 c0 	movl   $0xc0031098,(%esp)
c002ca19:	e8 55 bf ff ff       	call   c0028973 <debug_panic>

  do 
    {
      msg ("Sleeping 10 seconds to allow recent_cpu to decay, please wait...");
c002ca1e:	c7 04 24 c0 10 03 c0 	movl   $0xc00310c0,(%esp)
c002ca25:	e8 03 dd ff ff       	call   c002a72d <msg>
      start_time = timer_ticks ();
c002ca2a:	e8 d5 77 ff ff       	call   c0024204 <timer_ticks>
c002ca2f:	89 c7                	mov    %eax,%edi
c002ca31:	89 d5                	mov    %edx,%ebp
      timer_sleep (DIV_ROUND_UP (start_time, TIMER_FREQ) - start_time
c002ca33:	83 c0 63             	add    $0x63,%eax
c002ca36:	83 d2 00             	adc    $0x0,%edx
c002ca39:	c7 44 24 08 64 00 00 	movl   $0x64,0x8(%esp)
c002ca40:	00 
c002ca41:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c002ca48:	00 
c002ca49:	89 04 24             	mov    %eax,(%esp)
c002ca4c:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca50:	e8 7e b8 ff ff       	call   c00282d3 <__divdi3>
c002ca55:	29 f8                	sub    %edi,%eax
c002ca57:	19 ea                	sbb    %ebp,%edx
c002ca59:	05 e8 03 00 00       	add    $0x3e8,%eax
c002ca5e:	83 d2 00             	adc    $0x0,%edx
c002ca61:	89 04 24             	mov    %eax,(%esp)
c002ca64:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ca68:	e8 df 77 ff ff       	call   c002424c <timer_sleep>
                   + 10 * TIMER_FREQ);
    }
  while (thread_get_recent_cpu () > 700);
c002ca6d:	e8 d4 43 ff ff       	call   c0020e46 <thread_get_recent_cpu>
c002ca72:	3d bc 02 00 00       	cmp    $0x2bc,%eax
c002ca77:	7f a5                	jg     c002ca1e <test_mlfqs_recent_1+0x3c>

  start_time = timer_ticks ();
c002ca79:	e8 86 77 ff ff       	call   c0024204 <timer_ticks>
c002ca7e:	89 44 24 18          	mov    %eax,0x18(%esp)
c002ca82:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  int last_elapsed = 0;
c002ca86:	be 00 00 00 00       	mov    $0x0,%esi
  for (;;) 
    {
      int elapsed = timer_elapsed (start_time);
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002ca8b:	bd 1f 85 eb 51       	mov    $0x51eb851f,%ebp
c002ca90:	eb 02                	jmp    c002ca94 <test_mlfqs_recent_1+0xb2>
c002ca92:	89 de                	mov    %ebx,%esi
      int elapsed = timer_elapsed (start_time);
c002ca94:	8b 44 24 18          	mov    0x18(%esp),%eax
c002ca98:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002ca9c:	89 04 24             	mov    %eax,(%esp)
c002ca9f:	89 54 24 04          	mov    %edx,0x4(%esp)
c002caa3:	e8 88 77 ff ff       	call   c0024230 <timer_elapsed>
c002caa8:	89 c3                	mov    %eax,%ebx
      if (elapsed % (TIMER_FREQ * 2) == 0 && elapsed > last_elapsed) 
c002caaa:	f7 ed                	imul   %ebp
c002caac:	c1 fa 06             	sar    $0x6,%edx
c002caaf:	89 d8                	mov    %ebx,%eax
c002cab1:	c1 f8 1f             	sar    $0x1f,%eax
c002cab4:	29 c2                	sub    %eax,%edx
c002cab6:	69 d2 c8 00 00 00    	imul   $0xc8,%edx,%edx
c002cabc:	39 d3                	cmp    %edx,%ebx
c002cabe:	75 d2                	jne    c002ca92 <test_mlfqs_recent_1+0xb0>
c002cac0:	39 de                	cmp    %ebx,%esi
c002cac2:	7d ce                	jge    c002ca92 <test_mlfqs_recent_1+0xb0>
        {
          int recent_cpu = thread_get_recent_cpu ();
c002cac4:	e8 7d 43 ff ff       	call   c0020e46 <thread_get_recent_cpu>
c002cac9:	89 c6                	mov    %eax,%esi
          int load_avg = thread_get_load_avg ();
c002cacb:	e8 52 43 ff ff       	call   c0020e22 <thread_get_load_avg>
c002cad0:	89 c1                	mov    %eax,%ecx
          int elapsed_seconds = elapsed / TIMER_FREQ;
c002cad2:	89 d8                	mov    %ebx,%eax
c002cad4:	f7 ed                	imul   %ebp
c002cad6:	89 d7                	mov    %edx,%edi
c002cad8:	c1 ff 05             	sar    $0x5,%edi
c002cadb:	89 d8                	mov    %ebx,%eax
c002cadd:	c1 f8 1f             	sar    $0x1f,%eax
c002cae0:	29 c7                	sub    %eax,%edi
          msg ("After %d seconds, recent_cpu is %d.%02d, load_avg is %d.%02d.",
c002cae2:	89 c8                	mov    %ecx,%eax
c002cae4:	f7 ed                	imul   %ebp
c002cae6:	c1 fa 05             	sar    $0x5,%edx
c002cae9:	89 c8                	mov    %ecx,%eax
c002caeb:	c1 f8 1f             	sar    $0x1f,%eax
c002caee:	29 c2                	sub    %eax,%edx
c002caf0:	6b c2 64             	imul   $0x64,%edx,%eax
c002caf3:	29 c1                	sub    %eax,%ecx
c002caf5:	89 4c 24 14          	mov    %ecx,0x14(%esp)
c002caf9:	89 54 24 10          	mov    %edx,0x10(%esp)
c002cafd:	89 f0                	mov    %esi,%eax
c002caff:	f7 ed                	imul   %ebp
c002cb01:	c1 fa 05             	sar    $0x5,%edx
c002cb04:	89 f0                	mov    %esi,%eax
c002cb06:	c1 f8 1f             	sar    $0x1f,%eax
c002cb09:	29 c2                	sub    %eax,%edx
c002cb0b:	6b c2 64             	imul   $0x64,%edx,%eax
c002cb0e:	29 c6                	sub    %eax,%esi
c002cb10:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002cb14:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cb18:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002cb1c:	c7 04 24 04 11 03 c0 	movl   $0xc0031104,(%esp)
c002cb23:	e8 05 dc ff ff       	call   c002a72d <msg>
               elapsed_seconds,
               recent_cpu / 100, recent_cpu % 100,
               load_avg / 100, load_avg % 100);
          if (elapsed_seconds >= 180)
c002cb28:	81 ff b3 00 00 00    	cmp    $0xb3,%edi
c002cb2e:	0f 8e 5e ff ff ff    	jle    c002ca92 <test_mlfqs_recent_1+0xb0>
            break;
        } 
      last_elapsed = elapsed;
    }
}
c002cb34:	83 c4 2c             	add    $0x2c,%esp
c002cb37:	5b                   	pop    %ebx
c002cb38:	5e                   	pop    %esi
c002cb39:	5f                   	pop    %edi
c002cb3a:	5d                   	pop    %ebp
c002cb3b:	c3                   	ret    
c002cb3c:	90                   	nop
c002cb3d:	90                   	nop
c002cb3e:	90                   	nop
c002cb3f:	90                   	nop

c002cb40 <test_mlfqs_fair>:

static void load_thread (void *aux);

static void
test_mlfqs_fair (int thread_cnt, int nice_min, int nice_step)
{
c002cb40:	55                   	push   %ebp
c002cb41:	57                   	push   %edi
c002cb42:	56                   	push   %esi
c002cb43:	53                   	push   %ebx
c002cb44:	81 ec 7c 01 00 00    	sub    $0x17c,%esp
c002cb4a:	89 4c 24 14          	mov    %ecx,0x14(%esp)
  struct thread_info info[MAX_THREAD_CNT];
  int64_t start_time;
  int nice;
  int i;

  ASSERT (thread_mlfqs);
c002cb4e:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002cb55:	75 2c                	jne    c002cb83 <test_mlfqs_fair+0x43>
c002cb57:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002cb5e:	c0 
c002cb5f:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cb66:	c0 
c002cb67:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cb6e:	c0 
c002cb6f:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
c002cb76:	00 
c002cb77:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cb7e:	e8 f0 bd ff ff       	call   c0028973 <debug_panic>
c002cb83:	89 c5                	mov    %eax,%ebp
c002cb85:	89 d7                	mov    %edx,%edi
  ASSERT (thread_cnt <= MAX_THREAD_CNT);
c002cb87:	83 f8 14             	cmp    $0x14,%eax
c002cb8a:	7e 2c                	jle    c002cbb8 <test_mlfqs_fair+0x78>
c002cb8c:	c7 44 24 10 42 11 03 	movl   $0xc0031142,0x10(%esp)
c002cb93:	c0 
c002cb94:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cb9b:	c0 
c002cb9c:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cba3:	c0 
c002cba4:	c7 44 24 04 4a 00 00 	movl   $0x4a,0x4(%esp)
c002cbab:	00 
c002cbac:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cbb3:	e8 bb bd ff ff       	call   c0028973 <debug_panic>
  ASSERT (nice_min >= -10);
c002cbb8:	83 fa f6             	cmp    $0xfffffff6,%edx
c002cbbb:	7d 2c                	jge    c002cbe9 <test_mlfqs_fair+0xa9>
c002cbbd:	c7 44 24 10 5f 11 03 	movl   $0xc003115f,0x10(%esp)
c002cbc4:	c0 
c002cbc5:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cbcc:	c0 
c002cbcd:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cbd4:	c0 
c002cbd5:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
c002cbdc:	00 
c002cbdd:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cbe4:	e8 8a bd ff ff       	call   c0028973 <debug_panic>
  ASSERT (nice_step >= 0);
c002cbe9:	83 7c 24 14 00       	cmpl   $0x0,0x14(%esp)
c002cbee:	79 2c                	jns    c002cc1c <test_mlfqs_fair+0xdc>
c002cbf0:	c7 44 24 10 6f 11 03 	movl   $0xc003116f,0x10(%esp)
c002cbf7:	c0 
c002cbf8:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cbff:	c0 
c002cc00:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cc07:	c0 
c002cc08:	c7 44 24 04 4c 00 00 	movl   $0x4c,0x4(%esp)
c002cc0f:	00 
c002cc10:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cc17:	e8 57 bd ff ff       	call   c0028973 <debug_panic>
  ASSERT (nice_min + nice_step * (thread_cnt - 1) <= 20);
c002cc1c:	8d 40 ff             	lea    -0x1(%eax),%eax
c002cc1f:	0f af 44 24 14       	imul   0x14(%esp),%eax
c002cc24:	01 d0                	add    %edx,%eax
c002cc26:	83 f8 14             	cmp    $0x14,%eax
c002cc29:	7e 2c                	jle    c002cc57 <test_mlfqs_fair+0x117>
c002cc2b:	c7 44 24 10 d8 11 03 	movl   $0xc00311d8,0x10(%esp)
c002cc32:	c0 
c002cc33:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cc3a:	c0 
c002cc3b:	c7 44 24 08 d8 e0 02 	movl   $0xc002e0d8,0x8(%esp)
c002cc42:	c0 
c002cc43:	c7 44 24 04 4d 00 00 	movl   $0x4d,0x4(%esp)
c002cc4a:	00 
c002cc4b:	c7 04 24 b4 11 03 c0 	movl   $0xc00311b4,(%esp)
c002cc52:	e8 1c bd ff ff       	call   c0028973 <debug_panic>

  thread_set_nice (-20);
c002cc57:	c7 04 24 ec ff ff ff 	movl   $0xffffffec,(%esp)
c002cc5e:	e8 8c 49 ff ff       	call   c00215ef <thread_set_nice>

  start_time = timer_ticks ();
c002cc63:	e8 9c 75 ff ff       	call   c0024204 <timer_ticks>
c002cc68:	89 44 24 18          	mov    %eax,0x18(%esp)
c002cc6c:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  msg ("Starting %d threads...", thread_cnt);
c002cc70:	89 6c 24 04          	mov    %ebp,0x4(%esp)
c002cc74:	c7 04 24 7e 11 03 c0 	movl   $0xc003117e,(%esp)
c002cc7b:	e8 ad da ff ff       	call   c002a72d <msg>
  nice = nice_min;
  for (i = 0; i < thread_cnt; i++) 
c002cc80:	85 ed                	test   %ebp,%ebp
c002cc82:	0f 8e e1 00 00 00    	jle    c002cd69 <test_mlfqs_fair+0x229>
c002cc88:	8d 5c 24 30          	lea    0x30(%esp),%ebx
c002cc8c:	be 00 00 00 00       	mov    $0x0,%esi
    {
      struct thread_info *ti = &info[i];
      char name[16];

      ti->start_time = start_time;
c002cc91:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cc95:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cc99:	89 03                	mov    %eax,(%ebx)
c002cc9b:	89 53 04             	mov    %edx,0x4(%ebx)
      ti->tick_count = 0;
c002cc9e:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
      ti->nice = nice;
c002cca5:	89 7b 0c             	mov    %edi,0xc(%ebx)

      snprintf(name, sizeof name, "load %d", i);
c002cca8:	89 74 24 0c          	mov    %esi,0xc(%esp)
c002ccac:	c7 44 24 08 b6 0f 03 	movl   $0xc0030fb6,0x8(%esp)
c002ccb3:	c0 
c002ccb4:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c002ccbb:	00 
c002ccbc:	8d 44 24 20          	lea    0x20(%esp),%eax
c002ccc0:	89 04 24             	mov    %eax,(%esp)
c002ccc3:	e8 57 a5 ff ff       	call   c002721f <snprintf>
      thread_create (name, PRI_DEFAULT, load_thread, ti);
c002ccc8:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cccc:	c7 44 24 08 bc cd 02 	movl   $0xc002cdbc,0x8(%esp)
c002ccd3:	c0 
c002ccd4:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002ccdb:	00 
c002ccdc:	8d 44 24 20          	lea    0x20(%esp),%eax
c002cce0:	89 04 24             	mov    %eax,(%esp)
c002cce3:	e8 e1 46 ff ff       	call   c00213c9 <thread_create>

      nice += nice_step;
c002cce8:	03 7c 24 14          	add    0x14(%esp),%edi
  for (i = 0; i < thread_cnt; i++) 
c002ccec:	83 c6 01             	add    $0x1,%esi
c002ccef:	83 c3 10             	add    $0x10,%ebx
c002ccf2:	39 ee                	cmp    %ebp,%esi
c002ccf4:	75 9b                	jne    c002cc91 <test_mlfqs_fair+0x151>
    }
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002ccf6:	8b 44 24 18          	mov    0x18(%esp),%eax
c002ccfa:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002ccfe:	89 04 24             	mov    %eax,(%esp)
c002cd01:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cd05:	e8 26 75 ff ff       	call   c0024230 <timer_elapsed>
c002cd0a:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cd0e:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd12:	c7 04 24 08 12 03 c0 	movl   $0xc0031208,(%esp)
c002cd19:	e8 0f da ff ff       	call   c002a72d <msg>

  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cd1e:	c7 04 24 2c 12 03 c0 	movl   $0xc003122c,(%esp)
c002cd25:	e8 03 da ff ff       	call   c002a72d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cd2a:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cd31:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cd38:	00 
c002cd39:	e8 0e 75 ff ff       	call   c002424c <timer_sleep>
  
  for (i = 0; i < thread_cnt; i++)
c002cd3e:	bb 00 00 00 00       	mov    $0x0,%ebx
c002cd43:	89 d8                	mov    %ebx,%eax
c002cd45:	c1 e0 04             	shl    $0x4,%eax
    msg ("Thread %d received %d ticks.", i, info[i].tick_count);
c002cd48:	8b 44 04 38          	mov    0x38(%esp,%eax,1),%eax
c002cd4c:	89 44 24 08          	mov    %eax,0x8(%esp)
c002cd50:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c002cd54:	c7 04 24 95 11 03 c0 	movl   $0xc0031195,(%esp)
c002cd5b:	e8 cd d9 ff ff       	call   c002a72d <msg>
  for (i = 0; i < thread_cnt; i++)
c002cd60:	83 c3 01             	add    $0x1,%ebx
c002cd63:	39 eb                	cmp    %ebp,%ebx
c002cd65:	75 dc                	jne    c002cd43 <test_mlfqs_fair+0x203>
c002cd67:	eb 48                	jmp    c002cdb1 <test_mlfqs_fair+0x271>
  msg ("Starting threads took %"PRId64" ticks.", timer_elapsed (start_time));
c002cd69:	8b 44 24 18          	mov    0x18(%esp),%eax
c002cd6d:	8b 54 24 1c          	mov    0x1c(%esp),%edx
c002cd71:	89 04 24             	mov    %eax,(%esp)
c002cd74:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cd78:	e8 b3 74 ff ff       	call   c0024230 <timer_elapsed>
c002cd7d:	89 44 24 04          	mov    %eax,0x4(%esp)
c002cd81:	89 54 24 08          	mov    %edx,0x8(%esp)
c002cd85:	c7 04 24 08 12 03 c0 	movl   $0xc0031208,(%esp)
c002cd8c:	e8 9c d9 ff ff       	call   c002a72d <msg>
  msg ("Sleeping 40 seconds to let threads run, please wait...");
c002cd91:	c7 04 24 2c 12 03 c0 	movl   $0xc003122c,(%esp)
c002cd98:	e8 90 d9 ff ff       	call   c002a72d <msg>
  timer_sleep (40 * TIMER_FREQ);
c002cd9d:	c7 04 24 a0 0f 00 00 	movl   $0xfa0,(%esp)
c002cda4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cdab:	00 
c002cdac:	e8 9b 74 ff ff       	call   c002424c <timer_sleep>
}
c002cdb1:	81 c4 7c 01 00 00    	add    $0x17c,%esp
c002cdb7:	5b                   	pop    %ebx
c002cdb8:	5e                   	pop    %esi
c002cdb9:	5f                   	pop    %edi
c002cdba:	5d                   	pop    %ebp
c002cdbb:	c3                   	ret    

c002cdbc <load_thread>:

static void
load_thread (void *ti_) 
{
c002cdbc:	57                   	push   %edi
c002cdbd:	56                   	push   %esi
c002cdbe:	53                   	push   %ebx
c002cdbf:	83 ec 10             	sub    $0x10,%esp
c002cdc2:	8b 5c 24 20          	mov    0x20(%esp),%ebx
  struct thread_info *ti = ti_;
  int64_t sleep_time = 5 * TIMER_FREQ;
  int64_t spin_time = sleep_time + 30 * TIMER_FREQ;
  int64_t last_time = 0;

  thread_set_nice (ti->nice);
c002cdc6:	8b 43 0c             	mov    0xc(%ebx),%eax
c002cdc9:	89 04 24             	mov    %eax,(%esp)
c002cdcc:	e8 1e 48 ff ff       	call   c00215ef <thread_set_nice>
  timer_sleep (sleep_time - timer_elapsed (ti->start_time));
c002cdd1:	8b 03                	mov    (%ebx),%eax
c002cdd3:	8b 53 04             	mov    0x4(%ebx),%edx
c002cdd6:	89 04 24             	mov    %eax,(%esp)
c002cdd9:	89 54 24 04          	mov    %edx,0x4(%esp)
c002cddd:	e8 4e 74 ff ff       	call   c0024230 <timer_elapsed>
c002cde2:	be f4 01 00 00       	mov    $0x1f4,%esi
c002cde7:	bf 00 00 00 00       	mov    $0x0,%edi
c002cdec:	29 c6                	sub    %eax,%esi
c002cdee:	19 d7                	sbb    %edx,%edi
c002cdf0:	89 34 24             	mov    %esi,(%esp)
c002cdf3:	89 7c 24 04          	mov    %edi,0x4(%esp)
c002cdf7:	e8 50 74 ff ff       	call   c002424c <timer_sleep>
  int64_t last_time = 0;
c002cdfc:	bf 00 00 00 00       	mov    $0x0,%edi
c002ce01:	be 00 00 00 00       	mov    $0x0,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce06:	eb 15                	jmp    c002ce1d <load_thread+0x61>
    {
      int64_t cur_time = timer_ticks ();
c002ce08:	e8 f7 73 ff ff       	call   c0024204 <timer_ticks>
      if (cur_time != last_time)
c002ce0d:	31 d6                	xor    %edx,%esi
c002ce0f:	31 c7                	xor    %eax,%edi
c002ce11:	09 fe                	or     %edi,%esi
c002ce13:	74 04                	je     c002ce19 <load_thread+0x5d>
        ti->tick_count++;
c002ce15:	83 43 08 01          	addl   $0x1,0x8(%ebx)
{
c002ce19:	89 c7                	mov    %eax,%edi
c002ce1b:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (ti->start_time) < spin_time) 
c002ce1d:	8b 03                	mov    (%ebx),%eax
c002ce1f:	8b 53 04             	mov    0x4(%ebx),%edx
c002ce22:	89 04 24             	mov    %eax,(%esp)
c002ce25:	89 54 24 04          	mov    %edx,0x4(%esp)
c002ce29:	e8 02 74 ff ff       	call   c0024230 <timer_elapsed>
c002ce2e:	85 d2                	test   %edx,%edx
c002ce30:	78 d6                	js     c002ce08 <load_thread+0x4c>
c002ce32:	85 d2                	test   %edx,%edx
c002ce34:	7f 07                	jg     c002ce3d <load_thread+0x81>
c002ce36:	3d ab 0d 00 00       	cmp    $0xdab,%eax
c002ce3b:	76 cb                	jbe    c002ce08 <load_thread+0x4c>
      last_time = cur_time;
    }
}
c002ce3d:	83 c4 10             	add    $0x10,%esp
c002ce40:	5b                   	pop    %ebx
c002ce41:	5e                   	pop    %esi
c002ce42:	5f                   	pop    %edi
c002ce43:	c3                   	ret    

c002ce44 <test_mlfqs_fair_2>:
{
c002ce44:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 0);
c002ce47:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce4c:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce51:	b8 02 00 00 00       	mov    $0x2,%eax
c002ce56:	e8 e5 fc ff ff       	call   c002cb40 <test_mlfqs_fair>
}
c002ce5b:	83 c4 0c             	add    $0xc,%esp
c002ce5e:	c3                   	ret    

c002ce5f <test_mlfqs_fair_20>:
{
c002ce5f:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (20, 0, 0);
c002ce62:	b9 00 00 00 00       	mov    $0x0,%ecx
c002ce67:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce6c:	b8 14 00 00 00       	mov    $0x14,%eax
c002ce71:	e8 ca fc ff ff       	call   c002cb40 <test_mlfqs_fair>
}
c002ce76:	83 c4 0c             	add    $0xc,%esp
c002ce79:	c3                   	ret    

c002ce7a <test_mlfqs_nice_2>:
{
c002ce7a:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (2, 0, 5);
c002ce7d:	b9 05 00 00 00       	mov    $0x5,%ecx
c002ce82:	ba 00 00 00 00       	mov    $0x0,%edx
c002ce87:	b8 02 00 00 00       	mov    $0x2,%eax
c002ce8c:	e8 af fc ff ff       	call   c002cb40 <test_mlfqs_fair>
}
c002ce91:	83 c4 0c             	add    $0xc,%esp
c002ce94:	c3                   	ret    

c002ce95 <test_mlfqs_nice_10>:
{
c002ce95:	83 ec 0c             	sub    $0xc,%esp
  test_mlfqs_fair (10, 0, 1);
c002ce98:	b9 01 00 00 00       	mov    $0x1,%ecx
c002ce9d:	ba 00 00 00 00       	mov    $0x0,%edx
c002cea2:	b8 0a 00 00 00       	mov    $0xa,%eax
c002cea7:	e8 94 fc ff ff       	call   c002cb40 <test_mlfqs_fair>
}
c002ceac:	83 c4 0c             	add    $0xc,%esp
c002ceaf:	c3                   	ret    

c002ceb0 <block_thread>:
  msg ("Block thread should have already acquired lock.");
}

static void
block_thread (void *lock_) 
{
c002ceb0:	56                   	push   %esi
c002ceb1:	53                   	push   %ebx
c002ceb2:	83 ec 14             	sub    $0x14,%esp
  struct lock *lock = lock_;
  int64_t start_time;

  msg ("Block thread spinning for 20 seconds...");
c002ceb5:	c7 04 24 64 12 03 c0 	movl   $0xc0031264,(%esp)
c002cebc:	e8 6c d8 ff ff       	call   c002a72d <msg>
  start_time = timer_ticks ();
c002cec1:	e8 3e 73 ff ff       	call   c0024204 <timer_ticks>
c002cec6:	89 c3                	mov    %eax,%ebx
c002cec8:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 20 * TIMER_FREQ)
c002ceca:	89 1c 24             	mov    %ebx,(%esp)
c002cecd:	89 74 24 04          	mov    %esi,0x4(%esp)
c002ced1:	e8 5a 73 ff ff       	call   c0024230 <timer_elapsed>
c002ced6:	85 d2                	test   %edx,%edx
c002ced8:	7f 0b                	jg     c002cee5 <block_thread+0x35>
c002ceda:	85 d2                	test   %edx,%edx
c002cedc:	78 ec                	js     c002ceca <block_thread+0x1a>
c002cede:	3d cf 07 00 00       	cmp    $0x7cf,%eax
c002cee3:	76 e5                	jbe    c002ceca <block_thread+0x1a>
    continue;

  msg ("Block thread acquiring lock...");
c002cee5:	c7 04 24 8c 12 03 c0 	movl   $0xc003128c,(%esp)
c002ceec:	e8 3c d8 ff ff       	call   c002a72d <msg>
  lock_acquire (lock);
c002cef1:	8b 44 24 20          	mov    0x20(%esp),%eax
c002cef5:	89 04 24             	mov    %eax,(%esp)
c002cef8:	e8 ed 5d ff ff       	call   c0022cea <lock_acquire>

  msg ("...got it.");
c002cefd:	c7 04 24 64 13 03 c0 	movl   $0xc0031364,(%esp)
c002cf04:	e8 24 d8 ff ff       	call   c002a72d <msg>
}
c002cf09:	83 c4 14             	add    $0x14,%esp
c002cf0c:	5b                   	pop    %ebx
c002cf0d:	5e                   	pop    %esi
c002cf0e:	c3                   	ret    

c002cf0f <test_mlfqs_block>:
{
c002cf0f:	56                   	push   %esi
c002cf10:	53                   	push   %ebx
c002cf11:	83 ec 54             	sub    $0x54,%esp
  ASSERT (thread_mlfqs);
c002cf14:	80 3d c0 7b 03 c0 00 	cmpb   $0x0,0xc0037bc0
c002cf1b:	75 2c                	jne    c002cf49 <test_mlfqs_block+0x3a>
c002cf1d:	c7 44 24 10 fd 00 03 	movl   $0xc00300fd,0x10(%esp)
c002cf24:	c0 
c002cf25:	c7 44 24 0c 71 e1 02 	movl   $0xc002e171,0xc(%esp)
c002cf2c:	c0 
c002cf2d:	c7 44 24 08 e8 e0 02 	movl   $0xc002e0e8,0x8(%esp)
c002cf34:	c0 
c002cf35:	c7 44 24 04 1c 00 00 	movl   $0x1c,0x4(%esp)
c002cf3c:	00 
c002cf3d:	c7 04 24 ac 12 03 c0 	movl   $0xc00312ac,(%esp)
c002cf44:	e8 2a ba ff ff       	call   c0028973 <debug_panic>
  msg ("Main thread acquiring lock.");
c002cf49:	c7 04 24 6f 13 03 c0 	movl   $0xc003136f,(%esp)
c002cf50:	e8 d8 d7 ff ff       	call   c002a72d <msg>
  lock_init (&lock);
c002cf55:	8d 5c 24 2c          	lea    0x2c(%esp),%ebx
c002cf59:	89 1c 24             	mov    %ebx,(%esp)
c002cf5c:	e8 ec 5c ff ff       	call   c0022c4d <lock_init>
  lock_acquire (&lock);
c002cf61:	89 1c 24             	mov    %ebx,(%esp)
c002cf64:	e8 81 5d ff ff       	call   c0022cea <lock_acquire>
  msg ("Main thread creating block thread, sleeping 25 seconds...");
c002cf69:	c7 04 24 d0 12 03 c0 	movl   $0xc00312d0,(%esp)
c002cf70:	e8 b8 d7 ff ff       	call   c002a72d <msg>
  thread_create ("block", PRI_DEFAULT, block_thread, &lock);
c002cf75:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c002cf79:	c7 44 24 08 b0 ce 02 	movl   $0xc002ceb0,0x8(%esp)
c002cf80:	c0 
c002cf81:	c7 44 24 04 1f 00 00 	movl   $0x1f,0x4(%esp)
c002cf88:	00 
c002cf89:	c7 04 24 f6 00 03 c0 	movl   $0xc00300f6,(%esp)
c002cf90:	e8 34 44 ff ff       	call   c00213c9 <thread_create>
  timer_sleep (25 * TIMER_FREQ);
c002cf95:	c7 04 24 c4 09 00 00 	movl   $0x9c4,(%esp)
c002cf9c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c002cfa3:	00 
c002cfa4:	e8 a3 72 ff ff       	call   c002424c <timer_sleep>
  msg ("Main thread spinning for 5 seconds...");
c002cfa9:	c7 04 24 0c 13 03 c0 	movl   $0xc003130c,(%esp)
c002cfb0:	e8 78 d7 ff ff       	call   c002a72d <msg>
  start_time = timer_ticks ();
c002cfb5:	e8 4a 72 ff ff       	call   c0024204 <timer_ticks>
c002cfba:	89 c3                	mov    %eax,%ebx
c002cfbc:	89 d6                	mov    %edx,%esi
  while (timer_elapsed (start_time) < 5 * TIMER_FREQ)
c002cfbe:	89 1c 24             	mov    %ebx,(%esp)
c002cfc1:	89 74 24 04          	mov    %esi,0x4(%esp)
c002cfc5:	e8 66 72 ff ff       	call   c0024230 <timer_elapsed>
c002cfca:	85 d2                	test   %edx,%edx
c002cfcc:	7f 0b                	jg     c002cfd9 <test_mlfqs_block+0xca>
c002cfce:	85 d2                	test   %edx,%edx
c002cfd0:	78 ec                	js     c002cfbe <test_mlfqs_block+0xaf>
c002cfd2:	3d f3 01 00 00       	cmp    $0x1f3,%eax
c002cfd7:	76 e5                	jbe    c002cfbe <test_mlfqs_block+0xaf>
  msg ("Main thread releasing lock.");
c002cfd9:	c7 04 24 8b 13 03 c0 	movl   $0xc003138b,(%esp)
c002cfe0:	e8 48 d7 ff ff       	call   c002a72d <msg>
  lock_release (&lock);
c002cfe5:	8d 44 24 2c          	lea    0x2c(%esp),%eax
c002cfe9:	89 04 24             	mov    %eax,(%esp)
c002cfec:	e8 c3 5e ff ff       	call   c0022eb4 <lock_release>
  msg ("Block thread should have already acquired lock.");
c002cff1:	c7 04 24 34 13 03 c0 	movl   $0xc0031334,(%esp)
c002cff8:	e8 30 d7 ff ff       	call   c002a72d <msg>
}
c002cffd:	83 c4 54             	add    $0x54,%esp
c002d000:	5b                   	pop    %ebx
c002d001:	5e                   	pop    %esi
c002d002:	c3                   	ret    
