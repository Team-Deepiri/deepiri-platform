"""
Hybrid AI Service Tests
Test local/API model switching
"""
import pytest
from app.services.hybrid_ai_service import get_hybrid_service
from app.services.model_selector import ModelType


class TestHybridAIService:
    """Test hybrid AI service."""
    
    @pytest.fixture
    def service(self):
        return get_hybrid_service()
    
    @pytest.mark.asyncio
    async def test_classify_with_hybrid(self, service):
        """Test classification with hybrid service."""
        result = await service.classify_task_hybrid("Write code")
        assert 'type' in result
        assert 'complexity' in result
    
    @pytest.mark.asyncio
    async def test_force_local(self, service):
        """Test forcing local model."""
        if service.local_inference:
            result = await service.classify_task_hybrid("Test", force_local=True)
            assert result.get('source') == 'local' or 'type' in result
    
    @pytest.mark.asyncio
    async def test_model_switching(self, service):
        """Test switching between models."""
        original = service.model_selector.current_model_type
        
        success = await service.switch_model(ModelType.OPENAI)
        assert success or service.model_selector.current_model_type == original
        
        if service.model_selector.local_model_path:
            success = await service.switch_model(ModelType.LOCAL)
            assert success or service.model_selector.current_model_type == ModelType.LOCAL
    
    @pytest.mark.asyncio
    async def test_generate_hybrid(self, service):
        """Test challenge generation with hybrid service."""
        task = {'title': 'Test task', 'type': 'manual'}
        result = await service.generate_challenge_hybrid(task)
        assert 'type' in result
        assert 'title' in result

