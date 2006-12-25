tell application "Finder"
	set theLocation to insertion location
	
	try
		-- error occur when Finder window is in search mode
		if class of theLocation is not in {folder, disk} then
			set theLocation to folder of theLocation
		end if
	end try
	set shouldCheckSelection to false
	set theLocationText to theLocation as Unicode text
	if exists Finder window 1 then
		if current view of Finder window 1 is group view then
			set shouldCheckSelection to true --when Finder window is in search mode
		else
			set shouldCheckSelection to (target of Finder window 1 as Unicode text) is theLocationText
		end if
	end if
	
	if not shouldCheckSelection then
		set shouldCheckSelection to (desktop as Unicode text) is theLocationText
	end if
	
	if shouldCheckSelection then
		set theSelection to selection
		if theSelection is not {} then
			set theSelection to item 1 of theSelection
			if (theSelection as Unicode text) ends with ":" then
				set theLocation to theSelection
			else if class of theSelection is alias file then
				set theOriginal to original item of theSelection
				if (theOriginal as Unicode text) ends with ":" then
					set theLocation to theOriginal
				else
					set theLocation to folder of theSelection
				end if
			else
				set theLocation to folder of theSelection
			end if
		end if
	end if
	
	set theLocation to theLocation as alias
end tell

return POSIX path of theLocation