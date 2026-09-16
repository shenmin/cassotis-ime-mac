#!/usr/bin/env python3
"""Keep model deployment metadata limited to runtime fields and provenance."""
import argparse
import json
from pathlib import Path


def runtime_metadata(name, value):
    """Project metadata onto reviewed fields; values read by the hosts stay exact."""
    def select(obj, keys):
        return {key: obj[key] for key in keys.split()}
    if name == 'local_repair':
        result = select(value, 'format enabled joint_bilateral joint_score_agreement model minimum_word_ratio no_context_refinement_passes '
                        'source_model source_revision license teacher_url checkpoint_sha256 '
                        'max_characters context_characters dictionary_constraints_sha256 files')
        for key in ('no_context', 'document_context'):
            result[key] = select(value[key], 'edit margin max_edits max_spans')
        return result
    result = select(value, 'format parameters model model_sha256 float_model_bytes int8_model_bytes vocab_sha256')
    result['fallback_generator'] = select(value['fallback_generator'],
        'model model_sha256 model_bytes parameters output_words minimum_confidence')
    result['config'] = select(value['config'], 'input_vocab_size word_vocab_size max_input_length candidate_count '
        'path_words path_feature_count type_vocab_size d_model heads layers feedforward dropout '
        'feature_schema candidate_layers candidate_feedforward')
    result['quantization'] = select(value['quantization'], 'weight_type operators fp32_protected')
    result['gate'] = {'dev': {'threshold': value['gate']['dev']['threshold']}}
    result['runtime_index'] = select(value['runtime_index'],
        'file sha256 bytes vocab_sha256 format anchors candidates candidate_limit')
    result['recall_selector'] = select(value['recall_selector'], 'type features trees model_sha256')
    return result



MODEL_MANIFESTS = (('local_repair', 'runtime_manifest.json'),
                   ('local_completion', 'model_manifest.json'))


def prepare(directory, check=False):
    for kind, filename in MODEL_MANIFESTS:
        path = directory/kind/filename
        value = json.loads(path.read_text())
        deployment = runtime_metadata(kind, value)
        if check:
            if value != deployment:
                raise ValueError(f'Unexpected deployment metadata fields: {kind}/{filename}')
        else:
            path.write_text(json.dumps(deployment, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    prepare(args.directory, args.check)
