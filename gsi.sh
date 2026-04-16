#!/bin/bash
# Load your local secrets
source .env

# 3. The Crave Run Command
crave run --projectID 93 --no-patch -- '
  
  # List the specific folders that cause issues for creek
  remove=(
    out/soong
    out/target
  )

  # Efficiently remove all of them
  for folder in "${remove[@]}"; do
      rm -rf "$folder"
      echo "    Cleaned: $folder"
  done

  # Remove local manifests
  rm -rf .repo/local_manifests/
  
  # ROM source repo
  repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs
  
  # Clone local_manifests repository
  git clone https://github.com/MisterZtr/treble_manifest.git .repo/local_manifests -b lineage-23.0
  
  # Sync the repositories
  /opt/crave/resync.sh
  
  # Apply GSI patches
  if [ -d "LineageOS_gsi" ]; then
      bash LineageOS_gsi/patches/apply-patches.sh
  fi
  
  # Set up build environment
  source build/envsetup.sh

  # Lunch (The GSI Choice)
  # arm64 = Architecture
  # b = AB partition (Standard for SM6225)
  # g = GApps included (if target supports it)
  # N = No VNDK enforcement (allows older vendor to work)
  # // lunch lineage_arm64_bgNE-bp2a-userdebug
  
  # Breakfast
  breakfast lineage_arm64_bgNE-bp2a-userdebug

  # Build only system
  make systemimage -j$(nproc --all)

  mka bacon'
