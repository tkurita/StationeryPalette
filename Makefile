PRODUCT := StationeryPalette

install:
	xcodebuild -workspace '$(PRODUCT).xcworkspace' -scheme $(PRODUCT) -configuration Release clean install DSTROOT=${HOME}

clean:
	xcodebuild -workspace '$(PRODUCT).xcworkspace' -scheme $(PRODUCT) -configuration Release clean DSTROOT=${HOME}
