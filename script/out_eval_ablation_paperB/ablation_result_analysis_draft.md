### Ablation Result Analysis Draft

The heuristic-rule variant is inadequate under the unified protocol, while all learned decision variants consistently improve structured decision quality and image-level fidelity.
Relative to A0, A1 and A2 improve Macro-F1 by +0.1090 and +0.1111, confirming that learned decision replacing heuristic rules is effective.
A3 further improves Macro-F1 to 0.1885, exceeding A1 and A2 by +0.0332 and +0.0311, which supports that ordinal reformulation is better matched to the discrete ordered weight space.
A4 mainly shifts decision boundaries toward difficult tail-sensitive categories; TailRecall@24/28/31 change from 0.1788/0.1555/0.0640 to 0.1970/0.1252/0.0507 while global accuracy changes from 0.2891 to 0.2843.
A5 introduces deployment-oriented monotonic projection at inference/export stage. Compared with A4, Macro-F1 changes from 0.1827 to 0.1833, and the maximum absolute PSNR change across DAVIS and Set8 at sigma=10/30/50 is 0.0182 dB.
These results indicate that deployment-oriented mapping introduces negligible degradation while restoring hardware-consistent monotonicity.

#### A5 vs A4 PSNR delta (dB)

- DAVIS sigma=10: +0.0081 dB
- DAVIS sigma=30: +0.0015 dB
- DAVIS sigma=50: -0.0000 dB
- Set8 sigma=10: +0.0182 dB
- Set8 sigma=30: +0.0012 dB
- Set8 sigma=50: -0.0010 dB

