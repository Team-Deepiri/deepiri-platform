import os
import json
from dataclasses import dataclass
from typing import List, Dict, Any


@dataclass
class TrainingExample:
    prompt: str
    completion: str


def load_dataset(path: str) -> List[TrainingExample]:
    examples: List[TrainingExample] = []
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            row = json.loads(line)
            examples.append(TrainingExample(prompt=row['prompt'], completion=row['completion']))
    return examples


def to_openai_format(examples: List[TrainingExample]) -> Dict[str, Any]:
    # Converts to OpenAI fine-tuning JSONL messages format
    records = []
    for ex in examples:
        records.append({
            "messages": [
                {"role": "system", "content": "You are tripblip Agent."},
                {"role": "user", "content": ex.prompt},
                {"role": "assistant", "content": ex.completion},
            ]
        })
    return {"records": records}


def save_records_jsonl(records: List[Dict[str, Any]], out_path: str):
    with open(out_path, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def main():
    dataset_path = os.getenv('TRAIN_DATASET', 'python_backend/train/sample_dataset.jsonl')
    output_jsonl = os.getenv('TRAIN_OUT', 'python_backend/train/ft_records.jsonl')

    examples = load_dataset(dataset_path)
    formatted = to_openai_format(examples)
    save_records_jsonl(formatted["records"], output_jsonl)
    print(f"Prepared {len(formatted['records'])} records at {output_jsonl}")
    print("Next steps: upload JSONL to OpenAI and start a fine-tune job.")


if __name__ == '__main__':
    main()


