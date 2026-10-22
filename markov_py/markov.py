# credits: https://github.com/jsvine/markovify
import markovify
from psdocs import *
from random import randint
markovify.splitters.abbr_capped=[]
def split_into_sentences(text):
	potential_end_pat = re.compile(
		r"".join(
			[
				r"([\w\.'&\]\)]+[\.\?!;])",
				r"(['\"\)\]]*)",
				r"(\s+(?![a-z\-–—]))",
			]
		),
		re.U,
	)
	dot_iter = re.finditer(potential_end_pat, text)
	end_indices = [
		(x.start() + len(x.group(1)) + len(x.group(2)))
		for x in dot_iter
		if is_sentence_ender(x.group(1))
	]
	spans = zip([None] + end_indices, end_indices + [None])
	sentences = [text[start:end].strip() for start, end in spans]
	return sentences

markovify.splitters.split_into_sentences=split_into_sentences

docs=training_doc1,training_doc2,training_doc3,training_doc4,training_doc5
text='\n'.join(docs)
text_model = markovify.Text(text)
e=''
while True:
	command=input()
	if command == "gen":
		print(text_model.make_sentence(),flush=True)
	elif command == "exit":
		break
	else:
		print("Invalid command!",flush=True)