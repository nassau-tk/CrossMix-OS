#!/bin/bash
PATH="/mnt/SDCARD/System/bin:$PATH"

echo performance >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 1416000 >/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

silent=false
for arg in "$@"; do
  if [ "$arg" = "-s" ]; then
    silent=true
    break
  fi
done

EmuCleanerPath="$(dirname "$0")/"
RomsFolder="/mnt/SDCARD/Roms"
EmuFolder="/mnt/SDCARD/Emus"
json_file="/mnt/SDCARD/Emus/show.json"

NumRemoved=0
NumAdded=0

if [ "$silent" = false ]; then
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$EmuCleanerPath/background.jpg"
fi

write_entry() {
  label="$1"
  show="$2"
  echo "{"
  echo -e "\t\"label\": \"$label\","
  echo -e "\t\"show\": $show"
  echo "},"
}

echo "[" >$json_file

# We check if some emulators must be hidden from /mnt/SDCARD/Emus
for subfolder in $EmuFolder/*/; do
  # Check if the config.json file exists
  if [ -f "$subfolder/config.json" ]; then
    # Extract the rompath, label, and extlist from the config.json using jq
    RomPath=$(jq -r '.rompath' "$subfolder/config.json")
    RomFolderName=$(basename "$RomPath")

    Label=$(jq -r '.label' "$subfolder/config.json")
    ExtList=$(jq -r '.extlist' "$subfolder/config.json")

    echo "--$Label--"

    # Build the find command with extensions from extlist
    if [ -z "$ExtList" ] || [ "$ExtList" = "null" ]; then
      find_cmd="find \"$RomsFolder/$RomFolderName\" '!' -name '*.db' '!' -name '.gitkeep' '!' -name '*.launch' -mindepth 1 -maxdepth 2"
    else
      set -- $(echo $ExtList | tr '|' ' ')
      find_cmd="find \"$RomsFolder/$RomFolderName\""
      first=1
      for ext in "$@"; do
        if [ $first -eq 1 ]; then
          find_cmd="$find_cmd -iname '*.$ext'"
          first=0
        else
          find_cmd="$find_cmd -o -iname '*.$ext'"
        fi
      done
      find_cmd="$find_cmd '!' -name '*.launch' -mindepth 1 -maxdepth 2"
    fi

    # Check if the ROM folder contains any files with the specified extensions
    if ! eval "$find_cmd | read"; then
      echo "Removing $Label emulator (no roms in $RomFolderName folder)."
      write_entry "$Label" 0 >>$json_file
      NumRemoved=$((NumRemoved + 1))
    else
      echo "Adding $Label emulator (roms found in $RomFolderName folder)."
      write_entry "$Label" 1 >>$json_file
      NumAdded=$((NumAdded + 1))
    fi
  fi
done

sed -i '$ s/,$//' $json_file
echo "]" >>$json_file
sync

if [ "$silent" = false ]; then
	# Refresh Emus list
	jq '(.list[].tabstate[] | select(has("pagestart"))).pagestart = 0 | (.list[].tabstate[] | select(has("pageend"))).pageend = 7' /tmp/state.json >/tmp/state.tmp && mv /tmp/state.tmp /tmp/state.json
fi

sync

echo -ne "\n=============================\n"
echo -ne "${NumRemoved} hidden emulator(s)\n${NumAdded} displayed emulator(s)\n"
echo -ne "=============================\n\n"

if [ "$silent" = false ]; then
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$EmuCleanerPath/background-info.jpg" -m "${NumAdded} displayed emulator(s).      ${NumRemoved} hidden emulator(s)." -t 2.5
fi
