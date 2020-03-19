PRODUCT := StationeryPalette

install: clean
	xcodebuild -workspace '$(PRODUCT).xcworkspace' -scheme $(PRODUCT) -configuration Release install DSTROOT=${HOME}

clean:
	xcodebuild -workspace '$(PRODUCT).xcworkspace' -scheme $(PRODUCT) -configuration Release clean
