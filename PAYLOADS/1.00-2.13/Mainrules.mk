EE_CC = ee-gcc
EE_LD = ee-ld
EE_AS = ee-as
EE_OBJCOPY = ee-objcopy

IOP_CC = iop-gcc
IOP_LD = iop-ld
IOP_AS = iop-as
IOP_OBJCOPY = iop-objcopy
IOP_OBJDUMP = iop-objdump

IOP_SYMBOLS = -DREAD_SECTORS=$(IOP_READ_SECTORS) -DORIGINAL_RETURN_ADDRESS=$(IOP_ORIGINAL_RETURN_ADDRESS) -DRETURN_ADDRESS_LOCATION=$(IOP_RETURN_ADDRESS_LOCATION)
IOP_CFLAGS = -O2 -G 0 -nostartfiles -nostdlib -ffreestanding -g $(IOP_SYMBOLS)

EE_CFLAGS = -O2 -G 0 -nostartfiles -nostdlib -ffreestanding -Wl,-z,max-page-size=0x1

IOP_STAGE1_SIZE = `stat -c '%s' stage1.iop.bin`
IOP_PAYLOAD_SIZE = `stat -c '%s' ioppayload.iop.bin`

dvd.iso: dvd.base.iso stage1.iop.bin ioppayload.iop.bin
	#genisoimage -udf -o dvd.iso udf/
	# @echo Insert 0x00000048 to offset 0x0818AC in dvd.iso
	# @echo Insert 0x00004000 to offset 0x0818B0 in dvd.iso
	# @echo Insert 0x000B7548 to offset 0x0818F4 in dvd.iso

	# For now it's easier to just use a base dvd rather than attempting to generate an image and patch it
	cp dvd.base.iso dvd.iso

	# Return address 0x00818f4 = 530676
	printf $(STAGE1_LOAD_ADDRESS_STRING) | dd of=dvd.iso bs=1 seek=530676 count=4 conv=notrunc

	# Old toolchains don't support this option, so just copy byte-by-byte...
	# bs=4096 iflag=skip_bytes,count_bytes
	
	# 0x820f8 = 532728
	dd if=stage1.iop.bin of=dvd.iso bs=1 seek=532728 count=$(IOP_STAGE1_SIZE) conv=notrunc
	# 0x700000 = 7340032
	dd if=ioppayload.iop.bin of=dvd.iso bs=1 seek=7340032 count=$(IOP_PAYLOAD_SIZE) conv=notrunc

%.iop.bin: %.iop.elf
	$(IOP_OBJCOPY) -O binary $< $@

%.iop.o: %.iop.S
	$(IOP_AS) $< -o $@

stage1.iop.elf: stage1.iop.S ioppayload.iop.bin
	$(IOP_OBJDUMP) -t ioppayload.iop.elf | grep " _start"
	$(IOP_CC) -Ttext=$(STAGE1_LOAD_ADDRESS) $< -DENTRY=$(IOP_PAYLOAD_ENTRY) -DIOP_PAYLOAD_SIZE=$(IOP_PAYLOAD_SIZE) $(IOP_CFLAGS) -o $@

ioppayload.iop.elf: ioppayload.iop.c eepayload.ee.bin
	$(IOP_CC) -Ttext=$(IOP_PAYLOAD_ADDRESS) -DLOAD_ELF_FROM_OFFSET=$(LOAD_ELF_FROM_OFFSET) ioppayload.iop.c $(IOP_CFLAGS) -o $@


%.ee.bin: %.ee.elf
	$(EE_OBJCOPY) -O binary $< $@ -Wl,-z,max-page-size=0x1

%.ee.o: %.ee.S
	$(EE_AS) $< -o $@

eepayload.ee.elf: eecrt0.ee.o syscalls.ee.o eepayload.ee.c
	$(EE_CC) -Ttext=$(EE_PAYLOAD_ADDRESS) $^ $(EE_CFLAGS) -o $@

clean:
	rm -rf *.elf *.bin *.o dvd.iso