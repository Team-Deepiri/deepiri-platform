"""
Multi-Modal Task Understanding Service
Unique feature: Understands tasks from text, images, code, documents, audio
"""
from typing import Dict, Optional, List, Any
import base64
import json
from ..logging_config import get_logger

logger = get_logger("pyagent.multimodal")


class MultimodalTaskUnderstanding:
    """Understands tasks from multiple input modalities."""
    
    def __init__(self):
        self.supported_modalities = ['text', 'image', 'code', 'document', 'audio', 'video']
    
    async def understand_task(
        self,
        content: Any,
        modality: str,
        metadata: Optional[Dict] = None
    ) -> Dict:
        """
        Understand task from various input types.
        
        Modalities:
        - text: Plain text task description
        - image: Screenshot, diagram, handwritten notes
        - code: Code files, repositories
        - document: PDFs, Word docs, markdown
        - audio: Voice notes, recordings
        - video: Screen recordings, tutorials
        """
        if modality not in self.supported_modalities:
            raise ValueError(f"Unsupported modality: {modality}")
        
        understanding = {
            'modality': modality,
            'extracted_task': None,
            'task_type': None,
            'complexity': None,
            'estimated_duration': None,
            'key_insights': [],
            'suggested_challenges': []
        }
        
        if modality == 'text':
            understanding = await self._understand_text(content, metadata)
        elif modality == 'image':
            understanding = await self._understand_image(content, metadata)
        elif modality == 'code':
            understanding = await self._understand_code(content, metadata)
        elif modality == 'document':
            understanding = await self._understand_document(content, metadata)
        elif modality == 'audio':
            understanding = await self._understand_audio(content, metadata)
        elif modality == 'video':
            understanding = await self._understand_video(content, metadata)
        
        logger.info("Task understood", modality=modality, task_type=understanding.get('task_type'))
        
        return understanding
    
    async def _understand_text(self, text: str, metadata: Optional[Dict]) -> Dict:
        """Extract task from text."""
        from .task_classifier import get_task_classifier
        
        classifier = get_task_classifier()
        classification = await classifier.classify_task(text)
        
        return {
            'modality': 'text',
            'extracted_task': text,
            'task_type': classification.get('type'),
            'complexity': classification.get('complexity'),
            'estimated_duration': classification.get('estimated_duration'),
            'key_insights': classification.get('keywords', []),
            'suggested_challenges': self._suggest_challenges(classification)
        }
    
    async def _understand_image(self, image_data: str, metadata: Optional[Dict]) -> Dict:
        """Extract task from image using vision model."""
        import openai
        from ..settings import settings
        
        if not settings.OPENAI_API_KEY:
            return {'error': 'Vision model not configured'}
        
        try:
            client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
            
            response = client.chat.completions.create(
                model="gpt-4-vision-preview",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "Extract any tasks, todos, or work items from this image. Return as JSON with task description, type, and complexity."},
                            {
                                "type": "image_url",
                                "image_url": {"url": image_data}
                            }
                        ]
                    }
                ],
                max_tokens=500
            )
            
            extracted = json.loads(response.choices[0].message.content)
            
            return {
                'modality': 'image',
                'extracted_task': extracted.get('task'),
                'task_type': extracted.get('type', 'manual'),
                'complexity': extracted.get('complexity', 'medium'),
                'estimated_duration': extracted.get('duration', 30),
                'key_insights': extracted.get('insights', []),
                'suggested_challenges': self._suggest_challenges(extracted)
            }
        except Exception as e:
            logger.error("Image understanding error", error=str(e))
            return {'error': str(e)}
    
    async def _understand_code(self, code: str, metadata: Optional[Dict]) -> Dict:
        """Extract tasks from code (comments, TODOs, structure)."""
        tasks = []
        lines = code.split('\n')
        
        for i, line in enumerate(lines):
            line_lower = line.lower().strip()
            if any(keyword in line_lower for keyword in ['todo', 'fixme', 'hack', 'xxx', 'note:']):
                task_text = line.split(':', 1)[-1].strip() if ':' in line else line.strip()
                tasks.append({
                    'line': i + 1,
                    'task': task_text,
                    'type': 'code'
                })
        
        return {
            'modality': 'code',
            'extracted_task': f"Code review: {len(tasks)} tasks found",
            'task_type': 'code',
            'complexity': 'medium',
            'estimated_duration': len(tasks) * 10,
            'key_insights': [t['task'] for t in tasks[:5]],
            'suggested_challenges': ['code_review', 'bug_fix', 'refactoring']
        }
    
    async def _understand_document(self, doc_content: str, metadata: Optional[Dict]) -> Dict:
        """Extract tasks from documents."""
        from .task_classifier import get_task_classifier
        
        classifier = get_task_classifier()
        classification = await classifier.classify_task(doc_content[:500])
        
        return {
            'modality': 'document',
            'extracted_task': doc_content[:200] + '...',
            'task_type': classification.get('type'),
            'complexity': classification.get('complexity'),
            'estimated_duration': classification.get('estimated_duration', 60),
            'key_insights': classification.get('keywords', []),
            'suggested_challenges': self._suggest_challenges(classification)
        }
    
    async def _understand_audio(self, audio_data: str, metadata: Optional[Dict]) -> Dict:
        """Extract task from audio (transcription needed)."""
        return {
            'modality': 'audio',
            'extracted_task': 'Audio transcription required',
            'task_type': 'manual',
            'complexity': 'medium',
            'estimated_duration': 30,
            'key_insights': [],
            'suggested_challenges': ['transcription', 'note_taking']
        }
    
    async def _understand_video(self, video_data: str, metadata: Optional[Dict]) -> Dict:
        """Extract tasks from video."""
        return {
            'modality': 'video',
            'extracted_task': 'Video analysis required',
            'task_type': 'study',
            'complexity': 'medium',
            'estimated_duration': 45,
            'key_insights': [],
            'suggested_challenges': ['video_summary', 'note_taking']
        }
    
    def _suggest_challenges(self, classification: Dict) -> List[str]:
        """Suggest challenge types based on classification."""
        task_type = classification.get('type', 'manual')
        mapping = {
            'study': ['quiz', 'flashcards', 'summary'],
            'code': ['coding_challenge', 'debug', 'refactor'],
            'creative': ['puzzle', 'brainstorm', 'design'],
            'manual': ['timed_completion', 'checklist', 'sprint']
        }
        return mapping.get(task_type, ['timed_completion'])


def get_multimodal_understanding() -> MultimodalTaskUnderstanding:
    """Get singleton MultimodalTaskUnderstanding instance."""
    global _multimodal_understanding
    if '_multimodal_understanding' not in globals():
        _multimodal_understanding = MultimodalTaskUnderstanding()
    return _multimodal_understanding

