FFT RTL: STAGE7 512x45 memory-wrapper version

Change summary:
1. fft512_dit_sdf_stage.v:
   - STAGE < 7 remains register-based small delay.
   - STAGE == 7 is changed from the previous REG/FF pair delay to sram512x45_sp.
   - STAGE == 8 remains sram512x45_sp.
   - The old 128x64 memory wrapper is no longer instantiated.

2. Effective large-memory count in the public RTL:
   - 512x45 input ping buffer: 1
   - 512x45 input pong buffer: 1
   - 512x45 FFT512 STAGE7 Delay128 pair buffer: 1
   - 512x45 FFT512 STAGE8 Delay256 pair buffer: 1
   - 512x45 Radix3 B0 align: 1
   - 512x45 Radix3 B1 align: 1
   - 512x45 output natural-order buffer: 1
   Total 512x45 memory-wrapper instances: 7

3. Recommended file list:
   - RTL simulation: filelist_rtl_sim_512only.f

4. sram128x64_1r1w.v and sram128x64_sp.v are kept in this folder only for legacy
   reference. They are not listed in the new filelists and should not be needed by
   this version.
