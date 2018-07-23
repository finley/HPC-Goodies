LeSI Best Recipe also have recommended (customers can still customize on top)
UEFI settings and it is validated with HPL (Linpack runs) to make sure
performance is within cpu spec.  18A.1 Best Recipe is available with this link:

    https://support.lenovo.com/us/en/solutions/HT506594


CMOS settings are there for both NextScale and SD530s under each of their
machine types.  I would disable Processors.C1EhancedMode and enable
Processors.CStates.

If you following the SD530 UEFI settings, it first informs
you to get it into “Maximum Performance”:

    set OperatingModes.ChooseOperatingMode "Maximum Performance" 

    
and then do another UEFI update that sets it to “Custom” and then to “Cooperative”:

    set OperatingModes.ChooseOperatingMode "Custom Mode"
    set Processors.CPUPstateControl Cooperative
 

Setting UEFI initially to “Maximum Performance” (ChooseOperatingMode) will
disable the following two settings [if you see them as enabled in your "show"
output]:

    set Processors.L1 Disable 
    set Processors.L0p Disable
 
 
Best regards,
Chulho Kim

Senior Technical Staff Member
HPC SW Development Architect
Lenovo US
Mobile Phone: +1 845 430-5169
Email: chulho@lenovo.com


