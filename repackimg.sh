#!/bin/sh
# AIK-Linux/repackimg: repack ramdisk and build image
# osm0sis @ xda-developers

abort() { cd "$aik"; echo "Error!"; }

case $1 in
  --help) echo "usage: repackimg.sh [--original] [--level <0-9>]"; exit 1;
esac;

aik="${BASH_SOURCE:-$0}";
aik="$(dirname "$(readlink -f "$aik")")";

cd "$aik";
chmod -R 755 bin *.sh;
chmod 644 bin/magic bin/androidbootimg.magic bin/chromeos/*;

arch=`uname -m`;

if [ -z "$(ls split_img/* 2>/dev/null)" -o -z "$(ls ramdisk/* 2>/dev/null)" ]; then
  echo "No files found to be packed/built.";
  abort;
  exit 1;
fi;

clear;
echo " ";
echo "Android Image Kitchen - RepackImg Script";
echo "by osm0sis @ xda-developers";
echo " ";

if [ ! -z "$(ls *-new.* 2>/dev/null)" ]; then
  echo "Warning: Overwriting existing files!";
  echo " ";
fi;

if [ "$(stat -c %U ramdisk/* | head -n 1)" = "root" ]; then
  sumsg=" (as root)";
  rel="../";
fi;

rm -f "*-new.*";
case $1 in
  --original)
    echo "Repacking with original ramdisk...";;
  --level|*)
    echo "Packing ramdisk$sumsg...";
    echo " ";
    ramdiskcomp=`cat split_img/*-ramdiskcomp`;
    if [ "$1" = "--level" -a "$2" ]; then
      level="-$2";
      lvltxt=" - Level: $2";
    elif [ "$ramdiskcomp" = "xz" ]; then
      level=-1;
    fi;
    echo "Using compression: $ramdiskcomp$lvltxt";
    repackcmd="$ramdiskcomp $level";
    compext=$ramdiskcomp;
    case $ramdiskcomp in
      gzip) compext=gz;;
      lzop) compext=lzo;;
      xz) repackcmd="xz $level -Ccrc32";;
      lzma) repackcmd="xz $level -Flzma";;
      bzip2) compext=bz2;;
      lz4) repackcmd=$rel"bin/$arch/lz4 $level -l";;
      *) abort; exit 1;;
    esac;
    if [ "$sumsg" ]; then
      cd ramdisk;
      sudo find . | sudo cpio -H newc -o 2> /dev/null | $repackcmd > ../ramdisk-new.cpio.$compext;
      cd ..;
    else
      bin/$arch/mkbootfs ramdisk | $repackcmd > ramdisk-new.cpio.$compext;
    fi;
    if [ ! $? -eq "0" ]; then
      abort;
      exit 1;
    fi;;
esac;

echo " ";
echo "Getting build information...";
cd split_img;
kernel=`ls *-zImage`;               echo "kernel = $kernel";
kernel="split_img/$kernel";
if [ "$1" = "--original" ]; then
  ramdisk=`ls *-ramdisk.cpio*`;     echo "ramdisk = $ramdisk";
  ramdisk="split_img/$ramdisk";
else
  ramdisk="ramdisk-new.cpio.$compext";
fi;
if [ -f *-second ]; then
  second=`ls *-second`;             echo "second = $second";  
  second="--second split_img/$second";
fi;
if [ -f *-cmdline ]; then
  cmdline=`cat *-cmdline`;          echo "cmdline = $cmdline";
fi;
if [ -f *-board ]; then
  board=`cat *-board`;              echo "board = $board";
fi;
base=`cat *-base`;                  echo "base = $base";
pagesize=`cat *-pagesize`;          echo "pagesize = $pagesize";
kerneloff=`cat *-kernel_offset`;        echo "kernel_offset = $kerneloff";
ramdiskoff=`cat *-ramdisk_offset`;      echo "ramdisk_offset = $ramdiskoff";
if [ -f *-second_offset ]; then
  secondoff=`cat *-second_offset`;      echo "second_offset = $secondoff";
fi;
if [ -f *-tags_offset ]; then
  tagsoff=`cat *-tags_offset`;          echo "tags_offset = $tagsoff";
fi;

if [ -f *-header_version ]; then
  headerver=`cat *-header_version`;          echo "header_version = $headerver";
fi;
if [ -f *-os_version ]; then
  osver=`cat *-os_version`;          echo "os_version = $osver";
fi;
if [ -f *-os_patch_level ]; then
  oslvl=`cat *-os_patch_level`;            echo "os_patch_level = $oslvl";
fi;
if [ -f *-hash ]; then
  hash=`cat *-hash`;                echo "hash = $hash";
  hash="--hash $hash";
fi;
if [ -f *-dtb ]; then
  dtb=`ls *-dtb`;                   echo "dtb = $dtb";
  dtb="--dtb split_img/$dtb";
fi;
cd ..;

if [ -f split_img/*-mtktype ]; then
  mtktype=`cat split_img/*-mtktype`;
  echo " ";
  echo "Generating MTK headers...";
  echo " ";
  echo "Using ramdisk type: $mtktype";
  bin/$arch/mkmtkhdr --kernel "$kernel" --$mtktype "$ramdisk" >/dev/null;
  if [ ! $? -eq "0" ]; then
    abort;
    exit 1;
  fi;
  mv -f $(basename $kernel)-mtk kernel-new.mtk;
  mv -f $(basename $ramdisk)-mtk $mtktype-new.mtk;
  kernel=kernel-new.mtk;
  ramdisk=$mtktype-new.mtk;
fi;

if [ -f split_img/*-sigtype ]; then
  outname=unsigned-new.img;
else
  outname=image-new.img;
fi;

imgtype=`cat split_img/*-imgtype`;
if [ "$imgtype" = "ELF" ]; then
  imgtype=AOSP;
  echo " ";
  echo "Warning: ELF format detected; will be repacked using AOSP format!";
fi;

echo " ";
echo "Building image...";
echo " ";
echo "Using format: $imgtype";
echo " ";
case $imgtype in
  AOSP) 
    #bin/$arch/mkbootimg --kernel "$kernel" --ramdisk "$ramdisk" $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --second_offset "$secondoff" --tags_offset "$tagsoff" --os_version "$osver" --os_patch_level "$oslvl" --header_version "$headerver" $hash $dtb -o $outname;
    python3 mkbootimg.py --kernel "$kernel" --ramdisk "$ramdisk" $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --second_offset "$secondoff" --tags_offset "$tagsoff" --os_version "$osver" --os_patch_level "$oslvl" --header_version "$headerver" $hash $dtb -o $outname;
    echo python3 mkbootimg.py --kernel "$kernel" --ramdisk "$ramdisk" $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff --second_offset "$secondoff" --tags_offset "$tagsoff" --os_version "$osver" --os_patch_level "$oslvl" --header_version "$headerver" $hash $dtb -o $outname;;
esac;
if [ ! $? -eq "0" ]; then
  abort;
  exit 1;
fi;

if [ -f split_img/*-sigtype ]; then
  sigtype=`cat split_img/*-sigtype`;
  if [ -f split_img/*-blobtype ]; then
    blobtype=" $(cat split_img/*-blobtype)";
  fi;
  echo "Signing new image...";
  echo " ";
  echo "Using signature: $sigtype$blobtype";
  echo " ";
  case $sigtype in
    CHROMEOS) bin/$arch/futility vbutil_kernel --pack image-new.img --keyblock bin/chromeos/kernel.keyblock --signprivate bin/chromeos/kernel_data_key.vbprivk --version 1 --vmlinuz unsigned-new.img --bootloader bin/chromeos/empty --config bin/chromeos/empty --arch arm --flags 0x1;;
    BLOB)
      awk 'BEGIN { printf "-SIGNED-BY-SIGNBLOB-\00\00\00\00\00\00\00\00" }' > image-new.img;
      bin/$arch/blobpack tempblob $blobtype unsigned-new.img >/dev/null;
      cat tempblob >> image-new.img;
      rm -rf tempblob;
    ;;
  esac;
  if [ ! $? -eq "0" ]; then
    abort;
    exit 1;
  fi;
fi;

if [ -f split_img/*-lokitype ]; then
  lokitype=`cat split_img/*-lokitype`;
  echo "Loki patching new image...";
  echo " ";
  echo "Using type: $lokitype";
  echo " ";
  mv -f image-new.img unlokied-new.img;
  if [ -f aboot.img ]; then
    bin/$arch/loki_tool patch $lokitype aboot.img unlokied-new.img image-new.img >/dev/null;
    if [ ! $? -eq "0" ]; then
      echo "Patching failed.";
      abort;
      exit 1;
    fi;
  else
    echo "Device aboot.img required in script directory to find Loki patch offset.";
    abort;
    exit 1;
  fi;
fi;

if [ -f split_img/*-tailtype ]; then
  tailtype=`cat split_img/*-tailtype`;
  echo "Appending footer...";
  echo " ";
  echo "Using type: $tailtype";
  echo " ";
  case $tailtype in
    SEAndroid) printf 'SEANDROIDENFORCE' >> image-new.img;;
    Bump) awk 'BEGIN { printf "\x41\xA9\xE4\x67\x74\x4D\x1D\x1B\xA4\x29\xF2\xEC\xEA\x65\x52\x79" }' >> image-new.img;;
  esac;
fi;

echo "Done!";
exit 0;

