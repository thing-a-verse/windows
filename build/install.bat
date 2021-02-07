@ECHO OFF
rem
rem INSTALL.BAT
rem
rem Try to full install windows 10
rem
rem m.marsden, 31/01/21, v1.1
rem            07/02/21, v2.0 - remove BCD rubbish, pull disk part into this script
rem

SETLOCAL enableextensions EnableDelayedExpansion
rem
rem Drive letter assignments
rem
set WINDOWS=C
set RECOVER=R
set SYSTEM=S
set TARGET=C
rem
rem probably...
rem
set winPE=X
set winPEBoot=D
rem
rem Which Image
rem
set defaultImage=6

echo Select Partition
echo ========================
echo.

rem
rem Select the Disk to use
rem
echo list disk | diskpart
echo.

set selectedDisk=0
set /p selectedDisk=Which disk to partition (default - %selectedDisk%):?
echo.
echo WARNING: Make sure the disk you want to edit is disk %selectedDisk% (or modify the script)
echo.

:newWay
set partScript=CreatePartition-new.txt
rem
rem
echo rem %partScript%: Built at %DATE% - %TIME%    > %partScript%
rem
echo select disk %selectedDisk%                    >> %partScript%
echo clean                                         >> %partScript%
echo convert gpt                                   >> %partScript%
rem
rem == 1. System partition =========================
rem
echo create partition efi size=105                 >> %partScript%

rem    ** NOTE: For Advanced Format 4Kn drives,
rem               change this value to size = 260 **


echo format quick fs=fat32 label="SYSTEM"          >> %partScript%
echo assign letter="%SYSTEM%"                      >> %partScript%
REM set id="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"  >> %partScript%
rem
rem == 2. Microsoft Reserved (MSR) partition =======
rem
echo create partition msr size=16                  >> %partScript%

rem == 3. Windows partition ========================
rem ==    a. Create the Windows partition ==========

echo create partition primary                      >> %partScript%

rem ==    b. Create space for the recovery tools ===
rem       ** Update this size to match the size of
rem          the recovery tools (winre.wim)
rem          plus some free space.

echo shrink minimum=800                            >> %partScript%

rem ==    c. Prepare the Windows partition =========

echo format quick fs=ntfs label="WINDOWS"          >> %partScript%
echo assign letter="%WINDOWS%"                     >> %partScript%


rem === 4. Recovery tools partition ================

echo create partition primary                      >> %partScript%
echo format quick fs=ntfs label="RECOVER"          >> %partScript%
echo assign letter="%RECOVER%"                     >> %partScript%
echo set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac" >> %partScript%
echo gpt attributes=0x8000000000000001             >> %partScript%
echo exit                                          >> %partScript%

rem
rem PartScript now contains the partition build
rem

rem
rem ===============================================================================
rem
goto :whichImage

:whichImage
echo Select Windows Image
echo ========================
echo.
rem
rem Select the image to install
rem
dism /Get-WimInfo /WimFile:%winPEBoot%:\sources\install.swm
rem
echo.
set selectedImage=%defaultImage%
set /p selectedImage=Which windows Image to install (default - %selectedImage%):?
echo.
goto :isReadyToStart

:isReadyToStart
set ready=n
set /p ready=Ready to start [y/n] (default - %ready%):?
if "%ready%"=="y" (
    GOTO buildPartitions
) else (
    echo Abort
    goto :eof
)
GOTO endPartBuild

:buildPartitions
echo Building Partition Table
echo ========================
echo.
DiskPart /s %partScript%

:endPartBuild
echo Partition Build Done
echo list vol | diskpart

rem
rem ===============================================================================
rem

echo.
echo Windows (now)        --^> %WINDOWS%
echo System (EFI)         --^> %SYSTEM%
echo WinPE                --^> %winPE%
echo WinPE (boot)         --^> %WinPEBoot%  [you are here now]
echo Windows (eventually) --^> %TARGET%
echo.
echo Ready to copy EFI files from %winPE%:\ to %SYSTEM%:\

goto runSetup

rem
rem ===============================================================================
rem
:runSetup
echo.
echo Running Setup
echo ========================
echo.

:startSetup
echo Using DISM to install instead
dism /Apply-Image /ImageFile:%winPEBoot%:\sources\install.swm /SWMFile:%winPEBoot%:\sources\install*.swm /Index:%selectedImage% /ApplyDir:%WINDOWS%:\
rem
rem Do this last, once windows exists?
rem
bcdboot %WINDOWS%:\windows /s %SYSTEM%:

:endSetup
echo Setup Done. Exit all setup windows, reboot and remove the memory key
echo.
