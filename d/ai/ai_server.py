from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
import os
import math

app = Flask(__name__)
CORS(app)

knowledge_base = {}
patterns = {}

def load_knowledge_base():
    global knowledge_base, patterns
    kb_path = os.path.join(os.path.dirname(__file__), 'knowledge_base.json')
    patterns_path = os.path.join(os.path.dirname(__file__), 'patterns.json')
    
    with open(kb_path, 'r', encoding='utf-8') as f:
        knowledge_base = json.load(f)
    
    with open(patterns_path, 'r', encoding='utf-8') as f:
        patterns = json.load(f)

def preprocess_question(question):
    question = question.lower().strip()
    question = re.sub(r'[^\w\s]', '', question)
    return question

def detect_category(question):
    question_lower = question.lower()
    for category, keywords in patterns.get('categories', {}).items():
        for keyword in keywords:
            if keyword in question_lower:
                return category
    return 'general'

def extract_entities(question):
    entities = []
    numbers = re.findall(r'\b\d+\b', question)
    entities.extend(numbers)
    
    words = question.split()
    for word in words:
        if word.istitle() or (len(word) > 2 and word[0].isupper()):
            entities.append(word)
    
    return entities

def calculate_math(question):
    question = question.lower()
    question = question.replace('x', '*').replace('×', '*')
    question = question.replace('÷', '/').replace('divided by', '/')
    question = question.replace('plus', '+').replace('minus', '-')
    question = question.replace('times', '*').replace('multiplied by', '*')
    question = question.replace('squared', '**2').replace('cubed', '**3')
    
    math_pattern = r'[\d\s\+\-\*\/\.\(\)]+'
    matches = re.findall(math_pattern, question)
    
    for match in matches:
        match = match.strip()
        if match and any(op in match for op in ['+', '-', '*', '/']):
            try:
                result = eval(match)
                return match, result
            except:
                continue
    
    return None, None

def find_answer(question):
    question_processed = preprocess_question(question)
    
    # Check for math operations first
    expression, result = calculate_math(question)
    if result is not None:
        return {
            'answer': f"The result is: {result}",
            'confidence': 0.95,
            'category': 'math',
            'expression': expression
        }
    
    category = detect_category(question)
    entities = extract_entities(question)
    
    # Remove common stop words for better matching
    stop_words = {'what', 'is', 'the', 'a', 'an', 'of', 'in', 'on', 'at', 'to', 'for', 'and', 'or', 'but', 'not', 'with', 'by', 'from', 'this', 'that', 'it', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'can', 'shall'}
    input_keywords = set(question_processed.split()) - stop_words
    
    best_match = None
    best_confidence = 0
    
    if category in knowledge_base:
        for item in knowledge_base[category]:
            question_keywords = set(item.get('question_words', []))
            
            overlap = question_keywords.intersection(input_keywords)
            confidence = len(overlap) / max(len(question_keywords), 1)
            
            if confidence > best_confidence and confidence > 0.3:
                best_confidence = confidence
                best_match = {
                    'answer': item['answer'],
                    'confidence': min(confidence, 0.95),
                    'category': category
                }
    
    if best_match:
        return best_match
    
    for category_name, items in knowledge_base.items():
        for item in items:
            if 'aliases' in item:
                for alias in item['aliases']:
                    if alias.lower() in question_processed:
                        return {
                            'answer': item['answer'],
                            'confidence': 0.8,
                            'category': category_name
                        }
    
    return {
        'answer': "I'm not sure about that. Could you rephrase your question?",
        'confidence': 0.0,
        'category': 'unknown'
    }

@app.route('/api/ask', methods=['POST'])
def ask_question():
    data = request.get_json()
    question = data.get('question', '')
    
    if not question:
        return jsonify({'error': 'No question provided'}), 400
    
    result = find_answer(question)
    return jsonify(result)

@app.route('/api/health', methods=['GET'])
def health_check():
    total_items = sum(len(items) for items in knowledge_base.values())
    return jsonify({
        'status': 'ok',
        'knowledge_count': total_items,
        'categories': list(knowledge_base.keys())
    })

@app.route('/api/categories', methods=['GET'])
def get_categories():
    return jsonify({
        'categories': list(knowledge_base.keys())
    })

if __name__ == '__main__':
    load_knowledge_base()
    print("AI Server starting...")
    print(f"Loaded {sum(len(items) for items in knowledge_base.values())} knowledge items")
    app.run(host='0.0.0.0', port=5000, debug=True)
