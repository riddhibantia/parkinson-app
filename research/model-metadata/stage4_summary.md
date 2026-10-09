# Stage 4.4 — Layer 1 results

| model | view | ROC-AUC | AP | F1 | subjects | notes |
|---|---|---|---|---|---|---|
| rf | pooled | 0.600 ± 0.019 | 0.796 ± 0.051 | 0.801 ± 0.066 | 297 |  |
| rf | tappy | 0.486 ± 0.075 | 0.774 ± 0.089 | 0.808 ± 0.029 | 212 |  |
| rf | neuroqwerty | 0.818 ± 0.070 | 0.875 ± 0.037 | 0.748 ± 0.047 | 85 |  |
| rf | train_tappy_test_neuroqwerty | 0.684 | 0.734 | 0.688 | 85 |  |
| rf | train_neuroqwerty_test_tappy | 0.576 | 0.817 | 0.785 | 212 |  |
| tabpfn_pretrained | pooled | 0.563 ± 0.062 | 0.765 ± 0.047 | 0.784 ± 0.086 | 297 |  |
| tabpfn_pretrained | tappy | 0.461 ± 0.097 | 0.755 ± 0.096 | 0.818 ± 0.022 | 212 |  |
| tabpfn_pretrained | neuroqwerty | 0.825 ± 0.071 | 0.888 ± 0.037 | 0.724 ± 0.057 | 85 |  |
| tabpfn_pretrained | train_tappy_test_neuroqwerty | 0.732 | 0.785 | 0.682 | 85 |  |
| tabpfn_pretrained | train_neuroqwerty_test_tappy | 0.566 | 0.807 | 0.820 | 212 |  |
| rf | demo_subset:typing_only | 0.572 ± 0.060 | 0.824 ± 0.081 | 0.779 ± 0.070 | 176 | complete-case Tappy only |
| rf | demo_subset:with_demo | 0.545 ± 0.055 | 0.808 ± 0.082 | 0.815 ± 0.080 | 176 | complete-case Tappy only |
| tabpfn_pretrained | demo_subset:typing_only | 0.579 ± 0.058 | 0.821 ± 0.079 | 0.793 ± 0.079 | 176 | complete-case Tappy only |
| tabpfn_pretrained | demo_subset:with_demo | 0.556 ± 0.051 | 0.791 ± 0.114 | 0.785 ± 0.046 | 176 | complete-case Tappy only |
| tabpfn_finetuned | pooled | 0.551 ± 0.045 | 0.755 ± 0.049 | 0.792 ± 0.093 | 297 | epochs=30 gpu=Tesla T4 |

## Readout
- Tappy-only signal is near chance for both families; neuroQWERTY carries the pooled result. Expected per Stage 4.0.
- Pretrained TabPFN v2 does not clearly outperform the Random Forest baseline on any view.
- Adding age/sex on the complete-case Tappy subset does not improve either family; the typing-only primary stands.
- No thresholds were tuned; probabilities are saved per fold under models/experiments/* for later threshold work.

## Fine-tuning status: COMPLETED on Colab T4 GPU
Config: tabpfn==9.0.0, model_version=v2, epochs=30, lr=1e-05, gpu=Tesla T4, errors=0.
Pooled result is in the table above (tabpfn_finetuned row). Per the locked decision, fine-tuning was an adaptation experiment, not a dependency — and it did not beat the Random Forest primary.
