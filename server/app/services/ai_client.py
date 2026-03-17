"""OpenAI-compatible vision API client for OCR."""

from __future__ import annotations

import base64
import json
from pathlib import Path

import openai

from ..config import get_config
from ..utils.helpers import guess_mime

PROMPT = """你是一个试卷题目提取助手。请分析图片中的所有题目。

对每道题目，返回：
1. 该题目在图片中的垂直位置（占图片高度的百分比）
2. 该题目的Markdown格式文本内容

严格按以下JSON格式返回，不要添加任何其他文字：
```json
{
  "questions": [
    {
      "start_percent": 0,
      "end_percent": 35,
      "markdown": "1. 已知函数 $f(x) = x^2 + 2x + 1$，求 $f(3)$ 的值。"
    }
  ]
}
```

注意：
- start_percent和end_percent是题目区域在图片中的垂直起止位置(0-100)
- markdown中如有图表无法用文字表达，标注[图表]
- 保持题目原始编号"""


def _encode_image(path: str) -> tuple[str, str]:
    """Return (base64_data, mime_type)."""
    mime = guess_mime(path)
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode(), mime


async def call_vision(image_path: str) -> list[dict]:
    """Send image to AI and return parsed questions list.

    Each item: {"start_percent": int, "end_percent": int, "markdown": str}
    """
    cfg = get_config()
    if not cfg.ai.api_key:
        raise RuntimeError("AI API key not configured")

    b64, mime = _encode_image(image_path)

    client = openai.OpenAI(base_url=cfg.ai.base_url, api_key=cfg.ai.api_key)
    response = client.chat.completions.create(
        model=cfg.ai.model,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime};base64,{b64}"},
                    },
                ],
            }
        ],
        max_tokens=4096,
    )

    raw = response.choices[0].message.content.strip()

    # Strip markdown code fences if present
    if raw.startswith("```"):
        lines = raw.split("\n")
        # Remove first and last fence lines
        lines = [l for l in lines if not l.strip().startswith("```")]
        raw = "\n".join(lines)

    result = json.loads(raw)
    questions = result.get("questions", [])

    # Validate
    for q in questions:
        assert "start_percent" in q and "end_percent" in q and "markdown" in q

    return questions
