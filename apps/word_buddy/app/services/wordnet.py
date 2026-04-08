from nltk.corpus import wordnet

def get_wordnet_data(word: str) -> list:
    synsets = wordnet.synsets(word)
    senses = []
    for syn in synsets[:3]: # Limit to top 3 senses
        sense_data = {
            "synset": syn.name(),
            "definition": syn.definition(),
            "examples": syn.examples(),
            "synonyms": [l.name() for l in syn.lemmas()],
            "hypernyms": [h.name() for h in syn.hypernyms()],
            "hyponyms": [h.name() for h in syn.hyponyms()]
        }
        senses.append(sense_data)
    return senses
