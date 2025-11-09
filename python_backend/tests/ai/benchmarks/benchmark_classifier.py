"""
Benchmark Task Classifier
Performance and accuracy benchmarks
"""
import asyncio
import time
import statistics
from app.services.task_classifier import get_task_classifier


class ClassifierBenchmark:
    """Benchmark task classifier."""
    
    def __init__(self):
        self.classifier = get_task_classifier()
        self.test_cases = [
            ("Write a Python function", "code"),
            ("Read chapter 3", "study"),
            ("Design a logo", "creative"),
            ("Fix the bug", "code"),
            ("Study for exam", "study"),
            ("Write blog post", "creative"),
            ("Attend meeting", "meeting"),
            ("Research topic", "research")
        ]
    
    async def benchmark_accuracy(self) -> float:
        """Benchmark classification accuracy."""
        correct = 0
        total = len(self.test_cases)
        
        for text, expected_type in self.test_cases:
            result = await self.classifier.classify_task(text)
            if result['type'] == expected_type:
                correct += 1
        
        accuracy = correct / total
        print(f"Accuracy: {accuracy:.2%} ({correct}/{total})")
        return accuracy
    
    async def benchmark_latency(self, iterations: int = 100) -> dict:
        """Benchmark classification latency."""
        latencies = []
        
        for _ in range(iterations):
            start = time.time()
            await self.classifier.classify_task("Test task for benchmarking")
            latencies.append((time.time() - start) * 1000)
        
        return {
            'mean': statistics.mean(latencies),
            'median': statistics.median(latencies),
            'p95': sorted(latencies)[int(len(latencies) * 0.95)],
            'p99': sorted(latencies)[int(len(latencies) * 0.99)],
            'min': min(latencies),
            'max': max(latencies)
        }
    
    async def benchmark_throughput(self, duration_seconds: int = 10) -> float:
        """Benchmark requests per second."""
        count = 0
        start = time.time()
        
        while time.time() - start < duration_seconds:
            await self.classifier.classify_task("Throughput test")
            count += 1
        
        rps = count / duration_seconds
        print(f"Throughput: {rps:.2f} requests/second")
        return rps
    
    async def run_full_benchmark(self):
        """Run complete benchmark suite."""
        print("=" * 60)
        print("Task Classifier Benchmark")
        print("=" * 60)
        
        accuracy = await self.benchmark_accuracy()
        latency = await self.benchmark_latency()
        throughput = await self.benchmark_throughput()
        
        print("\nResults:")
        print(f"Accuracy: {accuracy:.2%}")
        print(f"Mean Latency: {latency['mean']:.2f}ms")
        print(f"P95 Latency: {latency['p95']:.2f}ms")
        print(f"Throughput: {throughput:.2f} req/s")
        
        return {
            'accuracy': accuracy,
            'latency': latency,
            'throughput': throughput
        }


if __name__ == "__main__":
    benchmark = ClassifierBenchmark()
    asyncio.run(benchmark.run_full_benchmark())

