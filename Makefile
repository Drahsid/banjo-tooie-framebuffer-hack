BASENAME = banjotooie
CORE1 = core1
TARGET = $(BUILD_DIR)/$(BASENAME)

PERFORMANCE_HACKS?=0

BUILD_DIR = build
TOOLS_DIR = tools

N64CRC = $(TOOLS_DIR)/n64crc
PYTHON = python3
INFLATE = $(PYTHON) $(TOOLS_DIR)/rareunzip.py
DEFLATE0 = gzip-1.2.4/gzip -c --no-name -9
DEFLATE1 = $(PYTHON) $(TOOLS_DIR)/rarezip.py
SPLIT = $(PYTHON) $(TOOLS_DIR)/splat/split.py
ASM_PROCESSOR_DIR = $(TOOLS_DIR)/asm-processor
ASM_PROCESSOR = $(PYTHON) $(ASM_PROCESSOR_DIR)/asm_processor.py

DEFLATE0_POSTAMBLE = | head --bytes=-8 | tail --bytes=+11 >

CROSS = mips-linux-gnu-
AS = $(CROSS)as
CC = $(TOOLS_DIR)/ido_recomp/linux/7.1/cc
LD = $(CROSS)ld -b elf32-tradbigmips
OBJCOPY = $(CROSS)objcopy

OPT_FLAG = -O2
ARCH_FLAG = -mips2
WX_FLAGS = -Xfullwarn -Xcpluscomm -Wab,-r4300_mul -woff 649,838
AI_FLAGS = -I include
I_FLAGS = $(AI_FLAGS) -I ultralib/include
D_FLAGS = -D_LANGUAGE_C -D_FINALROM -DF3DEX_GBI

ifeq ($(PERFORMANCE_HACKS),1)
D_FLAGS += -DPERFORMANCE_CHANGES
endif

AS_FLAGS = -EB -mtune=vr4300 -march=vr4300 -mabi=32 -mips3 $(AI_FLAGS)
CC_FLAGS = -c -G0 -signed -nostdinc -non_shared  $(WX_FLAGS) $(I_FLAGS) $(D_FLAGS) $(OPT_FLAG) $(ARCH_FLAG)
CC_FLAGS_CORE1 = -c -G0 -signed -nostdinc -non_shared  $(WX_FLAGS) $(I_FLAGS) $(D_FLAGS) $(OPT_FLAG) $(ARCH_FLAG)
LD_FLAGS = -T undefined_syms_auto.txt -T undefined_funcs_auto.txt -T undefined_funcs.txt -T undefined_syms.txt --no-check-sections
OBJCOPY_FLAGS = -O binary

S_FILES = $(foreach dir,asm,$(wildcard $(dir)/*.s))
C_FILES = $(foreach dir,src,$(wildcard $(dir)/*.c))
BIN_FILES = $(foreach dir,assets,$(wildcard $(dir)/*.bin))
O_FILES = $(foreach file,$(S_FILES),$(BUILD_DIR)/$(file).o) \
           $(foreach file,$(C_FILES),$(BUILD_DIR)/$(file).o) \
           $(foreach file,$(BIN_FILES),$(BUILD_DIR)/$(file).o)

CORE1_S_DIRS = asm/$(CORE1) src/$(CORE1)

CORE1_S_FILES = $(foreach dir,$(CORE1_S_DIRS),$(wildcard $(dir)/*.s))
CORE1_C_FILES = $(foreach dir,src/$(CORE1),$(wildcard $(dir)/*.c))
CORE1_BIN_FILES = $(foreach dir,assets/$(CORE1),$(wildcard $(dir)/*.bin))
CORE1_O_FILES = $(foreach file,$(CORE1_S_FILES),$(BUILD_DIR)/$(file).o) \
           $(foreach file,$(CORE1_C_FILES),$(BUILD_DIR)/$(file).o) \
           $(foreach file,$(CORE1_BIN_FILES),$(BUILD_DIR)/$(file).o)

# Files requiring pre/post-processing
GREP = grep -rl
GLOBAL_ASM_C_FILES = $(shell $(GREP) GLOBAL_ASM src </dev/null 2>/dev/null)
GLOBAL_ASM_O_FILES = $(foreach file,$(GLOBAL_ASM_C_FILES),$(BUILD_DIR)/$(file).o)

CORE1_GLOBAL_ASM_C_FILES = $(shell $(GREP) GLOBAL_ASM src/code </dev/null 2>/dev/null)
CORE1_GLOBAL_ASM_O_FILES = $(foreach file,$(CORE1_GLOBAL_ASM_C_FILES),$(BUILD_DIR)/$(file).o)


default: $(BUILD_DIR)/assets/$(CORE1)_text.rzip.bin.o $(TARGET).z64

clean:
	rm -rf $(BUILD_DIR)

nuke:
	rm -rf assets
	rm -rf asm
	rm -rf $(BUILD_DIR)
	rm -f *auto.txt

setup:
	mkdir -p $(BUILD_DIR) $(BUILD_DIR)/src $(BUILD_DIR)/src/$(CORE1) $(BUILD_DIR)/asm $(BUILD_DIR)/asm/$(CORE1) $(BUILD_DIR)/assets $(BUILD_DIR)/assets/$(CORE1)
	$(SPLIT) $(BASENAME).yaml
	for rzip in assets/*.rzip.bin ; do \
		echo $(INFLATE) $$rzip $${rzip%.rzip.bin}.rbin ; \
		$(INFLATE) $$rzip $${rzip%.rzip.bin}.rbin ; \
	done
	$(foreach yaml,$(wildcard subyaml/*.yaml),$(SPLIT) $(yaml))

$(BUILD_DIR)/%.s.o: %.s
	$(AS) $(AS_FLAGS) -o $@ $<

$(BUILD_DIR)/%.bin.o: %.bin
	$(LD) -r -b binary -o $@ $<

$(GLOBAL_ASM_O_FILES): $(BUILD_DIR)/%.c.o: %.c
	$(ASM_PROCESSOR) $(OPT_FLAG) $< > $(BUILD_DIR)/$<
	$(CC) -32 $(CC_FLAGS) -o $@ $(BUILD_DIR)/$<
	$(ASM_PROCESSOR) $(OPT_FLAG) $< --post-process $@ \
		--assembler "$(AS) $(AS_FLAGS)" --asm-prelude $(ASM_PROCESSOR_DIR)/prelude.inc

$(CORE1_GLOBAL_ASM_O_FILES): $(BUILD_DIR)/%.c.o: %.c
	$(ASM_PROCESSOR) $(OPT_FLAG) $< > $(BUILD_DIR)/$<
	$(CC) -32 $(CC_FLAGS_CORE1) -o $@ $(BUILD_DIR)/$<
	$(ASM_PROCESSOR) $(OPT_FLAG) $< --post-process $@ \
		--assembler "$(AS) $(AS_FLAGS)" --asm-prelude $(ASM_PROCESSOR_DIR)/prelude.inc

$(TARGET).elf: $(O_FILES)
	$(LD) -T $(BASENAME).ld -Map $(TARGET).map $(LD_FLAGS) -o $@

$(TARGET).z64: $(TARGET).elf
	$(OBJCOPY) $(OBJCOPY_FLAGS) $< $@  --pad-to 0x2000000 --gap-fill 0xFF
	$(N64CRC) $@
	@sha1sum assets/$(CORE1)_text.rzip.bin
	@sha1sum $(BUILD_DIR)/assets/$(CORE1)_text.rzip.bin

$(BUILD_DIR)/$(CORE1)_text.rzip.elf: $(CORE1_O_FILES)
	$(LD) -T $(CORE1).ld -Map $(BUILD_DIR)/$(CORE1).map $(LD_FLAGS) -o $@

$(BUILD_DIR)/$(CORE1)_text.rzip.obj: $(BUILD_DIR)/$(CORE1)_text.rzip.elf
	$(OBJCOPY) $(OBJCOPY_FLAGS) $< $@

$(BUILD_DIR)/assets/$(CORE1)_text.rzip.bin: $(BUILD_DIR)/$(CORE1)_text.rzip.obj
	$(DEFLATE0) $< $(DEFLATE0_POSTAMBLE) $@.imm
	$(DEFLATE1) $@.imm $@

$(BUILD_DIR)/assets/$(CORE1)_text.rzip.bin.o: $(BUILD_DIR)/assets/$(CORE1)_text.rzip.bin
	$(LD) -r -b binary -o $@ $<

### Settings
.SECONDARY:
.PHONY: default
SHELL = /bin/bash -e -o pipefail

