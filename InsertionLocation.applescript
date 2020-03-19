property InsertionLocator : "@module"
property _ : script "ModuleLoader"'s setup(me)

tell (make InsertionLocator)
    set_use_gui_scripting(true)
    set_allow_closed_folder(false)
    set a_location to do()
end tell
if a_location is not missing value
    set a_location to POSIX Path of a_location
end if
return a_location
