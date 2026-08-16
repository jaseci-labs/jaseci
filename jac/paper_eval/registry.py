"""Registry of paper-evaluated models: how to build a small instance + inputs,
and which transformers submodule GraphMend should scope-transform.

Small configs (no weight download) are used so break-counting is fast; graph
breaks are structural (code paths), not weight-dependent. torch.manual_seed is
fixed by the runner so the two modes (graphmend on/off) get identical weights,
making the output fingerprints directly comparable for correctness.
"""
import torch


def _t5():
    from transformers import T5Config, T5ForConditionalGeneration
    cfg = T5Config(vocab_size=128, d_model=64, d_ff=128, num_layers=2,
                   num_heads=2, d_kv=32)
    m = T5ForConditionalGeneration(cfg)
    ids = torch.randint(0, 128, (1, 8))
    dec = torch.randint(0, 128, (1, 8))
    return m, {"input_ids": ids, "decoder_input_ids": dec}


def _biogpt():
    from transformers import BioGptConfig, BioGptForCausalLM
    cfg = BioGptConfig(vocab_size=128, hidden_size=64, num_hidden_layers=2,
                       num_attention_heads=2, intermediate_size=128,
                       max_position_embeddings=64)
    m = BioGptForCausalLM(cfg)
    return m, {"input_ids": torch.randint(0, 128, (1, 8))}


def _blenderbot():
    from transformers import BlenderbotConfig, BlenderbotForConditionalGeneration
    cfg = BlenderbotConfig(vocab_size=128, d_model=64, encoder_layers=2,
                           decoder_layers=2, encoder_attention_heads=2,
                           decoder_attention_heads=2, encoder_ffn_dim=128,
                           decoder_ffn_dim=128, max_position_embeddings=64)
    m = BlenderbotForConditionalGeneration(cfg)
    ids = torch.randint(0, 128, (1, 8))
    dec = torch.randint(0, 128, (1, 8))
    return m, {"input_ids": ids, "decoder_input_ids": dec}



def _marian():
    from transformers import MarianConfig, MarianMTModel
    cfg = MarianConfig(vocab_size=128, d_model=64, encoder_layers=2,
                       decoder_layers=2, encoder_attention_heads=2,
                       decoder_attention_heads=2, encoder_ffn_dim=128,
                       decoder_ffn_dim=128, max_position_embeddings=64,
                       decoder_start_token_id=2, pad_token_id=1)
    m = MarianMTModel(cfg)
    ids = torch.randint(3, 128, (1, 8))
    dec = torch.randint(3, 128, (1, 8))
    return m, {"input_ids": ids, "decoder_input_ids": dec}


def _pegasus_causal():
    from transformers import PegasusConfig, PegasusForCausalLM
    cfg = PegasusConfig(vocab_size=128, d_model=64, decoder_layers=2,
                        decoder_attention_heads=2, decoder_ffn_dim=128,
                        max_position_embeddings=64)
    m = PegasusForCausalLM(cfg)
    return m, {"input_ids": torch.randint(0, 128, (1, 8))}


def _phi3_longrope():
    """Phi-4-mini's LongRoPE path -- the paper's Figure 3 worked example.

    `rope_scaling.type = "longrope"` is what routes the forward through
    `longrope_frequency_update`, whose `seq_len > original_max_position_embeddings`
    test is the data-dependent branch [Where] rewrites. Without longrope the
    model takes the default rope path and exhibits no DC break at all.

    short/long_factor must each have length (hidden_size // num_attention_heads) // 2.
    """
    from transformers import Phi3Config, Phi3ForCausalLM
    hidden, heads = 64, 2
    n = (hidden // heads) // 2
    cfg = Phi3Config(
        vocab_size=128, hidden_size=hidden, intermediate_size=128, pad_token_id=0,
        num_hidden_layers=2, num_attention_heads=heads, num_key_value_heads=heads,
        max_position_embeddings=64, original_max_position_embeddings=16,
        rope_scaling={"type": "longrope",
                      "short_factor": [1.0] * n,
                      "long_factor": [2.0] * n},
    )
    m = Phi3ForCausalLM(cfg)
    return m, {"input_ids": torch.randint(0, 128, (1, 8))}


def _molformer():
    """MoLFormer-XL: the paper's [Trap] / validation-guard model (Table 2, VG 5).

    Its `MolformerSelfAttention.forward` holds the Figure 5 pattern verbatim --
    `if not torch.equal(attention_mask, ...): raise ValueError(...)`.

    Two things make this entry unlike the others. It is Hub REMOTE CODE, so it
    needs network access; and the revision is pinned, because the 2026-07
    "Fix deprecated code" commit retargeted the model at a newer transformers
    (it imports `transformers.masking_utils`, absent in the paper's pinned
    4.52.4). `7b12d946c181` is the last revision contemporary with the paper.
    """
    from transformers import AutoConfig
    from transformers.dynamic_module_utils import get_class_from_dynamic_module
    repo, rev = "ibm/MoLFormer-XL-both-10pct", "7b12d946c181"
    cfg = AutoConfig.from_pretrained(repo, trust_remote_code=True, revision=rev)
    for k, v in [("hidden_size", 64), ("num_hidden_layers", 2),
                 ("num_attention_heads", 2), ("intermediate_size", 128),
                 ("max_position_embeddings", 64)]:
        if hasattr(cfg, k):
            setattr(cfg, k, v)
    cls = get_class_from_dynamic_module(
        "modeling_molformer.MolformerModel", repo, revision=rev)
    m = cls(cfg)
    return m, {"input_ids": torch.randint(0, 32, (1, 8)),
               "attention_mask": torch.ones(1, 8, dtype=torch.long)}


def _whisper():
    """Covers whisper-large-v3 / whisper-small / whisper-base (LC rows).

    All three are the same modeling code; the paper lists 3 logger-call breaks
    for each. Whisper takes `input_features`, not `input_ids`.
    """
    from transformers import WhisperConfig, WhisperForConditionalGeneration
    cfg = WhisperConfig(vocab_size=128, d_model=64, encoder_layers=2,
                        decoder_layers=2, encoder_attention_heads=2,
                        decoder_attention_heads=2, encoder_ffn_dim=128,
                        decoder_ffn_dim=128, num_mel_bins=80,
                        max_source_positions=64, max_target_positions=64,
                        decoder_start_token_id=2, pad_token_id=0,
                        bos_token_id=1, eos_token_id=2)
    m = WhisperForConditionalGeneration(cfg)
    feats = torch.randn(1, 80, 128)
    dec = torch.randint(0, 128, (1, 8))
    return m, {"input_features": feats, "decoder_input_ids": dec}


def _bart():
    """Covers bart-large-cnn / bart-base / rebel-large (DC 4 + LC 3 rows)."""
    from transformers import BartConfig, BartForConditionalGeneration
    cfg = BartConfig(vocab_size=128, d_model=64, encoder_layers=2,
                     decoder_layers=2, encoder_attention_heads=2,
                     decoder_attention_heads=2, encoder_ffn_dim=128,
                     decoder_ffn_dim=128, max_position_embeddings=64)
    m = BartForConditionalGeneration(cfg)
    ids = torch.randint(3, 128, (1, 8))
    dec = torch.randint(3, 128, (1, 8))
    return m, {"input_ids": ids, "decoder_input_ids": dec}


def _layoutlmv3():
    """layoutlmv3-base (LC 2)."""
    from transformers import LayoutLMv3Config, LayoutLMv3Model
    # The spatial embeddings are concatenated, so
    # 4*coordinate_size + 2*shape_size must equal hidden_size, and the h/w
    # tables are indexed after a clip to 1023, so max_2d stays at its default.
    cfg = LayoutLMv3Config(vocab_size=128, hidden_size=64, num_hidden_layers=2,
                           num_attention_heads=2, intermediate_size=128,
                           max_position_embeddings=64, max_2d_position_embeddings=1024,
                           coordinate_size=8, shape_size=16,
                           input_size=32, patch_size=16, visual_embed=False)
    m = LayoutLMv3Model(cfg)
    ids = torch.randint(0, 128, (1, 8))
    bbox = torch.zeros(1, 8, 4, dtype=torch.long)
    return m, {"input_ids": ids, "bbox": bbox}


def _longformer():
    """longformer-base-4096 (LC 3 + TI 2; paper fixes 40% -- the 2 tensor.item()
    breaks are declared out of scope, so the expected result here is partial)."""
    from transformers import LongformerConfig, LongformerModel
    cfg = LongformerConfig(vocab_size=128, hidden_size=64, num_hidden_layers=2,
                           num_attention_heads=2, intermediate_size=128,
                           max_position_embeddings=512, attention_window=8)
    m = LongformerModel(cfg)
    # The seq length must NOT be a multiple of attention_window: the logger call
    # lives under `if padding_len > 0`, so a 16-token input with window 8 gives
    # padding_len == 0, the branch never runs, and the LC breaks the paper counts
    # never appear. 20 tokens gives padding_len == 4.
    return m, {"input_ids": torch.randint(0, 128, (1, 20))}


def _grounding_dino():
    """grounding-dino-tiny / -base (DS 3 + DO 3 + DC 11; paper fixes 58%).

    Only the 11 data-dependent control-flow breaks are in scope; the dynamic
    shape and data-dependent operator breaks are the paper's declared
    out-of-scope categories, so a full fix is not the expected result here.
    """
    from transformers import (GroundingDinoConfig, GroundingDinoModel,
                              SwinConfig, BertConfig)
    backbone = SwinConfig(image_size=32, patch_size=4, embed_dim=16,
                          depths=[1, 1], num_heads=[1, 1], window_size=2,
                          out_features=["stage1", "stage2"])
    text = BertConfig(vocab_size=128, hidden_size=64, num_hidden_layers=2,
                      num_attention_heads=2, intermediate_size=128,
                      max_position_embeddings=64)
    cfg = GroundingDinoConfig(backbone_config=backbone, text_config=text,
                              d_model=64, encoder_layers=1, decoder_layers=1,
                              encoder_attention_heads=2, decoder_attention_heads=2,
                              encoder_ffn_dim=128, decoder_ffn_dim=128,
                              num_queries=4, num_feature_levels=2,
                              use_timm_backbone=False)
    m = GroundingDinoModel(cfg)
    return m, {"pixel_values": torch.randn(1, 3, 32, 32),
               "input_ids": torch.randint(0, 128, (1, 8))}


def _chronos_bolt():
    """chronos-bolt-small (LC 6).

    Its repo carries no modeling .py: the code lives in the `chronos` pip
    package (chronos.chronos_bolt), layered on T5. So it is scoped to that
    package, not to transformers_modules, and it is a genuinely separate
    measurement from the plain t5 entry rather than being covered by it.
    """
    from transformers import AutoConfig
    from chronos.chronos_bolt import ChronosBoltModelForForecasting
    cfg = AutoConfig.from_pretrained("amazon/chronos-bolt-small")
    cfg.chronos_config["context_length"] = 64
    cfg.chronos_config["prediction_length"] = 8
    m = ChronosBoltModelForForecasting(cfg)
    return m, {"context": torch.randn(1, 64)}


def _florence2():
    """Florence-2-large (DC 7): the largest pure data-dependent control flow row,
    so it is the strongest real-model exercise of [Where] after Phi-4."""
    from transformers import AutoConfig
    from transformers.dynamic_module_utils import get_class_from_dynamic_module
    repo = "microsoft/Florence-2-base"
    cfg = AutoConfig.from_pretrained(repo, trust_remote_code=True)
    # Only the language stack is shrunk. Shrinking the vision tower removed the
    # code paths carrying Florence-2's data-dependent branches, so the row read
    # 0 breaks and proved nothing.
    for holder, key, val in [(cfg.text_config, "encoder_layers", 1),
                             (cfg.text_config, "decoder_layers", 1)]:
        try:
            setattr(holder, key, val)
        except Exception:
            pass
    cls = get_class_from_dynamic_module(
        "modeling_florence2.Florence2ForConditionalGeneration", repo)
    m = cls(cfg)
    return m, {"input_ids": torch.randint(0, 100, (1, 8)),
               "decoder_input_ids": torch.randint(0, 100, (1, 8)),
               "pixel_values": torch.randn(1, 3, 768, 768)}


def _stella():
    """stella-en-400M-v5 (DO + DS, 0% in Table 2). Hub remote code."""
    from transformers import AutoConfig, AutoModel
    repo = "NovaSearch/stella_en_400M_v5"
    cfg = AutoConfig.from_pretrained(repo, trust_remote_code=True)
    for k, v in [("num_hidden_layers", 2), ("hidden_size", 64),
                 ("num_attention_heads", 2), ("intermediate_size", 128),
                 ("vocab_size", 512)]:
        if hasattr(cfg, k):
            setattr(cfg, k, v)
    m = AutoModel.from_config(cfg, trust_remote_code=True)
    return m, {"input_ids": torch.randint(0, 512, (1, 8)),
               "attention_mask": torch.ones(1, 8, dtype=torch.long)}


def _moe_minicpm():
    """moe-minicpm-x4-base (DS 15, 0% in Table 2). Hub remote code."""
    from transformers import AutoConfig, AutoModelForCausalLM
    repo = "babybirdprd/moe-minicpm-x4-base"
    cfg = AutoConfig.from_pretrained(repo, trust_remote_code=True)
    for k, v in [("num_hidden_layers", 2), ("hidden_size", 64),
                 ("num_attention_heads", 2), ("intermediate_size", 128),
                 ("vocab_size", 512)]:
        if hasattr(cfg, k):
            setattr(cfg, k, v)
    m = AutoModelForCausalLM.from_config(cfg, trust_remote_code=True)
    return m, {"input_ids": torch.randint(0, 512, (1, 8))}


def _clap():
    """clap-htsat-fused (DS 4, 0% in Table 2).

    Expected to stay unfixed: its breaks are dynamic shape operators, which the
    paper declares out of scope. Registered so the row is measured rather than
    asserted -- a 0% claim still has to show the breaks exist and are declined.
    """
    from transformers import ClapConfig, ClapModel
    cfg = ClapConfig()
    cfg.text_config.vocab_size = 128
    cfg.text_config.hidden_size = 64
    cfg.text_config.num_hidden_layers = 1
    cfg.text_config.num_attention_heads = 2
    cfg.text_config.intermediate_size = 128
    cfg.projection_dim = 32
    # The row is "clap-htsat-FUSED" and the dynamic-shape breaks live in the
    # fusion path, which is off by default. Without this the model traces
    # cleanly and the row reports 0 breaks, measuring nothing.
    cfg.audio_config.enable_fusion = True
    m = ClapModel(cfg)
    n_mel = cfg.audio_config.num_mel_bins
    return m, {"input_ids": torch.randint(0, 128, (1, 8)),
               "attention_mask": torch.ones(1, 8, dtype=torch.long),
               "input_features": torch.randn(1, 4, 1001, n_mel),
               "is_longer": torch.ones(1, 1, dtype=torch.bool)}


def _qwen_audio():
    """Qwen-Audio-Chat (DC 2). Hub remote code, so it needs network + trust."""
    from transformers import AutoConfig
    from transformers.dynamic_module_utils import get_class_from_dynamic_module
    repo = "Qwen/Qwen-Audio-Chat"
    cfg = AutoConfig.from_pretrained(repo, trust_remote_code=True)
    # Only depth and vocab are reduced. Changing hidden_size breaks the audio
    # cross-attention wiring ("too many values to unpack"), because the audio
    # tower's projection dims are derived independently of the LM width.
    for k, v in [("num_hidden_layers", 2), ("vocab_size", 4096)]:
        if hasattr(cfg, k):
            setattr(cfg, k, v)
    cfg.use_flash_attn = False
    cls = get_class_from_dynamic_module("modeling_qwen.QWenLMHeadModel", repo)
    m = cls(cfg)
    return m, {"input_ids": torch.randint(0, 512, (1, 8))}


MODELS = {
    "t5-small":       {"build": _t5,         "scope": ["transformers.models.t5"]},
    "clap-htsat-fused": {"build": _clap, "scope": ["transformers.models.clap"]},
    "stella-en-400M-v5": {"build": _stella, "scope": ["transformers_modules"]},
    "moe-minicpm-x4-base": {"build": _moe_minicpm, "scope": ["transformers_modules"]},
    "Qwen-Audio-Chat": {"build": _qwen_audio, "scope": ["transformers_modules"]},
    # Same modeling code as t5-base / t5-3b / flan-t5-large /
    # inclusively-reformulation-it5 / chronos-bolt-small, which is why one t5
    # entry stands in for those Table 2 rows.
    "whisper":        {"build": _whisper,    "scope": ["transformers.models.whisper"]},
    "bart":           {"build": _bart,       "scope": ["transformers.models.bart"]},
    # Its breaks are not in the model package at all: they are `warnings.warn`
    # calls in the SHARED transformers.modeling_utils, so the scope must name
    # that module too (same lesson as Phi-4 and modeling_rope_utils).
    "layoutlmv3-base": {"build": _layoutlmv3,
                        "scope": ["transformers.models.layoutlmv3",
                                  "transformers.modeling_utils"]},
    "longformer-base-4096": {"build": _longformer,
                             "scope": ["transformers.models.longformer"]},
    "grounding-dino": {"build": _grounding_dino,
                       "scope": ["transformers.models.grounding_dino"]},
    # Its own package holds the model class, but the breaks are logger calls in
    # transformers' T5 that it builds on, so both have to be in scope.
    "chronos-bolt-small": {"build": _chronos_bolt,
                           "scope": ["chronos", "transformers.models.t5"]},
    "Florence-2": {"build": _florence2, "scope": ["transformers_modules"],
                   "call": "generate"},
    "biogpt":         {"build": _biogpt,     "scope": ["transformers.models.biogpt"]},
    "blenderbot-400M-distill": {"build": _blenderbot, "scope": ["transformers.models.blenderbot"]},
    "opus-mt-fr-en":  {"build": _marian,        "scope": ["transformers.models.marian"]},
    "PegasusForCausalLM": {"build": _pegasus_causal, "scope": ["transformers.models.pegasus"]},
    # Phi-4-mini exercises [Where]. Its break site is `longrope_frequency_update`
    # in the SHARED top-level `transformers.modeling_rope_utils`, not under
    # `transformers.models.phi3` -- scoping only the model package silently
    # misses it and the model appears to be fixed by [Defer] alone.
    "Phi-4-mini-instruct": {"build": _phi3_longrope,
                            "scope": ["transformers.models.phi3",
                                      "transformers.modeling_rope_utils"]},
    # [Trap]. Opt-in: needs network + trust_remote_code, so it is excluded from
    # the default run (see NETWORK_MODELS). Hub remote code lands under the
    # `transformers_modules.*` namespace; scoping it works because jaclang hooks
    # the source loader as well as sys.meta_path (transformers builds the spec
    # directly, so a meta-path finder alone never sees these modules).
    "MoLFormer-XL-both10pct": {"build": _molformer,
                               "scope": ["transformers_modules"]},
}

# Models the default `python -m paper_eval.run_eval` skips: they download code or
# weights, which the rest of the harness deliberately avoids. Run them by name.
NETWORK_MODELS = {"MoLFormer-XL-both10pct", "chronos-bolt-small", "Florence-2",
                  "Qwen-Audio-Chat", "stella-en-400M-v5", "moe-minicpm-x4-base"}

# Table 2 rows that share modeling code with an entry above. Registering them
# explicitly turns "inferred from shared code" into a measured row. They
# exercise the same code paths as their twin, so a matching result is
# confirmatory rather than independent evidence: what it rules out is a row
# being claimed on an inference nobody ever ran.
_SHARED_CODE_ROWS = {
    "t5-base": "t5-small",
    "t5-3b": "t5-small",
    "flan-t5-large": "t5-small",
    "inclusively-reformulation-it5": "t5-small",
    "whisper-small": "whisper",
    "whisper-base": "whisper",
    "bart-base": "bart",
    "rebel-large": "bart",
    "grounding-dino-base": "grounding-dino",
}
for _row, _twin in _SHARED_CODE_ROWS.items():
    MODELS[_row] = dict(MODELS[_twin])
