KERNEL_RELEASE ?= $(shell uname -r)
KERNEL_BUILD ?= /lib/modules/$(KERNEL_RELEASE)/build

all:
	$(MAKE) -C $(KERNEL_BUILD) M=$(CURDIR)/src modules

clean:
	$(MAKE) -C $(KERNEL_BUILD) M=$(CURDIR)/src clean

.PHONY: all clean
