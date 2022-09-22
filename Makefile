pre:
	sdx.kit qwrap bible.tcl
	sdx.kit unwrap bible.kit
	cp -r resources bible.vfs/resources

all: pre
	sdx.kit wrap bible -runtime /usr/bin/tclkit-dyn

clean:
	rm -rf bible.vfs bible bible.kit

install: all
	cp bible /usr/bin/bible
