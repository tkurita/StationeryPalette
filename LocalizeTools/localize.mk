# nibs = MainMenu.nib FileTreeWindow.nib # specify in comannd line aruments
# target_lang = ja # specify in comannd line aruments
target_nibs = $(nibs:%.nib=$(target_lang).lproj/%.nib)
strings_files = $(target_nibs:%.nib=%.strings)

all: $(target_nibs)

$(strings_files): %.strings: 
	LocalizeTools/require_strings_file.sh $@

$(target_nibs): $(target_lang).lproj/%.nib: en.lproj/%.nib $(target_lang).lproj/%.strings
	make -f LocalizeTools/localize_ib.mk target_nib=$@ target_lang=$(target_lang)
#	./localize_ib.sh $< $@

clean_nibs:
	rm -r $(target_nibs)

clean_strings:
	rm $(strings_files)
