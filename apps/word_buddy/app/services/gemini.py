from vertexai.generative_models import GenerativeModel, Part
from app.core.config import GEMINI_MODEL_NAME
import json

def get_model():
    return GenerativeModel(GEMINI_MODEL_NAME)

def analyze_image(image_data: bytes, mime_type: str) -> str:
    model = get_model()
    image_part = Part.from_data(data=image_data, mime_type=mime_type)
    prompt = """
    Analyze this image and identify the key English vocabulary words that a learner should master. 
    Do NOT just extract all text like a standard OCR. 
    Focus on important nouns, verbs, adjectives, and adverbs that carry the main meaning or are educational.
    Ignore very common words like 'the', 'a', 'is', 'and', 'to', etc., unless they are part of a specific phrase or idiom shown.
    Return a clean JSON list of strings, e.g., ['word1', 'word2']. 
    Do not include any other text or markdown formatting.
    """
    response = model.generate_content([image_part, prompt])
    return response.text

def generate_word_details(word: str) -> str:
    model = get_model()
    prompt = f"""
    Provide detailed learning information for the English word: "{word}".
    Return a JSON object with the following structure:
    {{
        "word": "{word}",
        "phonetics": "Phonetic spelling or natural phonics guide",
        "etymology": "Brief root or etymology explanation",
        "meaning": "Chinese meaning",
        "sentences": [
            "Example sentence 1 in English with Chinese translation",
            "Example sentence 2 in English with Chinese translation"
        ]
    }}
    Ensure the response is ONLY the JSON object, no markdown formatting, no code blocks.
    """
    response = model.generate_content(prompt)
    return response.text

def generate_rich_word_details(words: list[str]) -> str:
    model = get_model()
    prompt = f"""
    Provide detailed learning information and a quiz question for the following English words: {words}.
    The explanations MUST be suitable for children (simple, easy to understand, no advanced vocabulary).
    
    Return a JSON list of objects, each with the following structure:
    {{
        "word": "the word",
        "phonetics": {{
            "uk": "British phonetic symbol",
            "us": "American phonetic symbol"
        }},
        "forms": {{
            "past_tense": "past tense if verb",
            "past_participle": "past participle if verb",
            "plural": "plural form if noun"
        }},
        "explanations": [
            {{
                "part_of_speech": "noun/verb/etc.",
                "meaning_en": "Simple English explanation suitable for children",
                "meaning_zh": "简单的中文释义"
            }}
        ],
        "synonyms": ["synonym1", "synonym2"],
        "antonyms": ["antonym1", "antonym2"],
        "sentences": [
            {{
                "en": "Example sentence 1 in English",
                "zh": "例句1的中文翻译"
            }},
            {{
                "en": "Example sentence 2 in English",
                "zh": "例句2的中文翻译"
            }}
        ],
        "quiz": {{
            "question": "A simple question about the word or a fill-in-the-blank sentence suitable for children.",
            "options": {{"A": "Option 1", "B": "Option 2", "C": "Option 3", "D": "Option 4"}},
            "answer": "A"
        }}
    }}
    Ensure the response is ONLY the JSON list, no markdown formatting, no code blocks.
    """
    response = model.generate_content(prompt)
    return response.text

