# The Complete AI Engineer Guide - Orchestration, LangChain & LLM Systems

## Table of Contents
1. [Introduction to AI Engineering](#introduction-to-ai-engineering)
2. [LLM Fundamentals](#llm-fundamentals)
3. [Prompt Engineering](#prompt-engineering)
4. [LangChain Deep Dive](#langchain-deep-dive)
5. [RAG (Retrieval-Augmented Generation)](#rag-retrieval-augmented-generation)
6. [AI Agents & Orchestration](#ai-agents--orchestration)
7. [Vector Databases](#vector-databases)
8. [Model Integration & APIs](#model-integration--apis)
9. [Production AI Systems](#production-ai-systems)
10. [Advanced Patterns](#advanced-patterns)
11. [Tools & Frameworks](#tools--frameworks)
12. [Best Practices](#best-practices)

---

## Introduction to AI Engineering

### What is AI Engineering?

**AI Engineering** is the discipline of building, deploying, and maintaining AI systems in production. Unlike ML Engineering (which focuses on training models), AI Engineering focuses on:

- **LLM Orchestration**: Coordinating multiple models and services
- **Prompt Engineering**: Designing effective prompts
- **RAG Systems**: Building retrieval-augmented generation pipelines
- **AI Agents**: Creating autonomous systems that use tools
- **Production Deployment**: Scaling AI systems for real-world use

### AI Engineer vs ML Engineer

| Aspect | ML Engineer | AI Engineer |
|--------|-------------|-------------|
| **Focus** | Training custom models | Orchestrating pre-trained models |
| **Models** | Train from scratch | Use/fine-tune LLMs |
| **Data** | Large labeled datasets | Unstructured text, documents |
| **Deployment** | Model serving | API orchestration, agents |
| **Tools** | TensorFlow, PyTorch | LangChain, LlamaIndex, OpenAI |

### Key Concepts

#### LLM (Large Language Model)
- **Definition**: Pre-trained transformer models (GPT, Claude, Llama)
- **Capabilities**: Text generation, understanding, reasoning
- **Sizes**: 7B to 175B+ parameters

#### Orchestration
- **Definition**: Coordinating multiple AI components
- **Components**: Models, tools, databases, APIs
- **Purpose**: Build complex AI applications

#### Agents
- **Definition**: AI systems that use tools autonomously
- **Capabilities**: Tool use, planning, memory
- **Types**: ReAct, Plan-and-Execute, AutoGPT-style

---

## LLM Fundamentals

### Transformer Architecture

#### Attention Mechanism
- **Self-Attention**: Relate different positions in sequence
- **Formula**: Attention(Q,K,V) = softmax(QK^T / √d_k) * V
- **Multi-Head**: Multiple attention mechanisms in parallel
- **Purpose**: Understand context and relationships

#### Architecture Components
- **Encoder**: Processes input (BERT-style)
- **Decoder**: Generates output (GPT-style)
- **Encoder-Decoder**: Both (T5, BART)

#### Positional Encoding
- **Purpose**: Inject sequence order
- **Types**: 
  - Sinusoidal (original)
  - Learned embeddings
  - Rotary Position Embedding (RoPE)

### Pre-trained Models

#### GPT Family
- **GPT-3**: 175B parameters, few-shot learning
- **GPT-4**: Multimodal, improved reasoning
- **GPT-3.5-turbo**: Fast, cost-effective
- **Use Cases**: Text generation, completion, chat

#### Claude (Anthropic)
- **Claude 3**: Opus, Sonnet, Haiku variants
- **Strengths**: Safety, long context, analysis
- **Use Cases**: Analysis, writing, coding

#### Llama (Meta)
- **Llama 2**: Open-source, 7B-70B
- **Llama 3**: Improved performance
- **Use Cases**: Open-source alternatives, fine-tuning

#### Other Models
- **Gemini**: Google's multimodal model
- **Mistral**: Efficient open-source
- **Mixtral**: Mixture of Experts (MoE)

### Model Capabilities

#### Text Generation
- **Completion**: Continue text
- **Chat**: Conversational AI
- **Code Generation**: Write code
- **Creative Writing**: Stories, poems

#### Understanding
- **Classification**: Categorize text
- **Sentiment Analysis**: Positive/negative
- **Named Entity Recognition**: Extract entities
- **Question Answering**: Answer questions

#### Reasoning
- **Chain-of-Thought**: Step-by-step reasoning
- **Few-Shot Learning**: Learn from examples
- **Tool Use**: Call external functions
- **Planning**: Multi-step problem solving

### Model Limitations

#### Hallucinations
- **Definition**: Generate false information
- **Causes**: Training data, lack of knowledge
- **Mitigation**: RAG, fact-checking, citations

#### Context Windows
- **Limitation**: Maximum input length
- **GPT-3.5**: 16K tokens
- **GPT-4**: 128K tokens
- **Claude 3**: 200K tokens
- **Solutions**: Chunking, summarization

#### Token Limits
- **Tokens**: Sub-word units (not words)
- **Cost**: Based on tokens (input + output)
- **Optimization**: Shorter prompts, efficient encoding

#### Latency
- **Issue**: Slow response times
- **Factors**: Model size, infrastructure
- **Solutions**: Caching, smaller models, async

#### Cost
- **Pricing**: Per token (input/output)
- **Optimization**: 
  - Use smaller models when possible
  - Cache responses
  - Batch requests
  - Fine-tune for efficiency

---

## Prompt Engineering

### What is Prompt Engineering?

**Prompt Engineering** is the art and science of designing inputs (prompts) to get desired outputs from LLMs. It's crucial for:
- Getting accurate results
- Reducing hallucinations
- Controlling output format
- Improving efficiency

### Prompt Components

#### Instructions
- **Clear Task**: What to do
- **Format**: Desired output structure
- **Constraints**: Limitations, rules

#### Context
- **Background**: Relevant information
- **Examples**: Few-shot demonstrations
- **Data**: Input to process

#### Output Format
- **Structure**: JSON, markdown, list
- **Style**: Tone, length
- **Constraints**: Max length, specific format

### Prompting Techniques

#### Zero-Shot Prompting
```
Task: Classify sentiment
Input: "I love this product!"
Output: Positive
```

#### Few-Shot Prompting
```
Task: Translate to French
Examples:
English: Hello → French: Bonjour
English: Goodbye → French: Au revoir
English: Thank you → French: ?
```

#### Chain-of-Thought (CoT)
```
Problem: A store has 15 apples. They sell 6. How many left?
Step 1: Start with 15 apples
Step 2: Subtract 6 sold
Step 3: 15 - 6 = 9 apples remaining
```

#### Zero-Shot CoT
```
Add "Let's think step by step" to prompt
Model will show reasoning process
```

#### Self-Consistency
- **Definition**: Generate multiple answers, pick most common
- **Purpose**: Improve accuracy
- **Use Cases**: Math, reasoning

#### Tree of Thoughts
- **Definition**: Explore multiple reasoning paths
- **Structure**: Tree of possible solutions
- **Purpose**: Better problem-solving

#### ReAct (Reasoning + Acting)
```
Thought: I need to find the capital of France
Action: search_wikipedia("France capital")
Observation: Paris is the capital
Thought: The answer is Paris
```

### Advanced Prompting

#### Role-Playing
```
You are an expert data scientist. 
Explain machine learning to a beginner.
```

#### Chain-of-Thought with Examples
```
Problem: If 3x + 5 = 20, find x
Solution:
Step 1: 3x = 20 - 5
Step 2: 3x = 15
Step 3: x = 15 / 3
Step 4: x = 5

Problem: If 2y + 3 = 11, find y
Solution: [model continues pattern]
```

#### Prompt Templates
```python
template = """
You are a {role} helping with {task}.

Context:
{context}

Instructions:
{instructions}

Format your response as {format}.
"""
```

### Prompt Optimization

#### Iterative Refinement
1. Start with simple prompt
2. Test on examples
3. Identify failures
4. Refine prompt
5. Repeat

#### A/B Testing
- **Compare**: Different prompt versions
- **Metrics**: Accuracy, cost, latency
- **Tools**: LangSmith, Weights & Biases

#### Prompt Versioning
- **Track**: Prompt versions
- **Compare**: Performance over time
- **Tools**: Git, LangSmith

### Common Patterns

#### Classification
```
Classify the sentiment: {text}
Options: Positive, Negative, Neutral
```

#### Extraction
```
Extract key information from: {text}
Format as JSON with fields: {fields}
```

#### Summarization
```
Summarize in 3 sentences: {text}
Focus on: {topics}
```

#### Translation
```
Translate to {language}: {text}
Maintain: {style, tone}
```

#### Code Generation
```
Write a {language} function that {task}
Requirements: {requirements}
Include: {tests, docs}
```

---

## LangChain Deep Dive

### What is LangChain?

**LangChain** is a framework for building applications with LLMs. It provides:
- **Abstractions**: Chains, agents, memory
- **Tools**: 100+ integrations
- **Utilities**: Prompt templates, output parsers
- **Production**: LangSmith, LangServe

### Core Concepts

#### Components
- **LLMs**: Language model wrappers
- **Prompts**: Template management
- **Chains**: Combine components
- **Agents**: Use tools autonomously
- **Memory**: Conversation history
- **Retrievers**: Document retrieval

### Installation & Setup

```python
pip install langchain
pip install langchain-openai
pip install langchain-community
pip install langchain-core
```

### LLM Integration

#### OpenAI
```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="gpt-3.5-turbo",
    temperature=0.7,
    max_tokens=1000
)

response = llm.invoke("Hello!")
```

#### Anthropic (Claude)
```python
from langchain_anthropic import ChatAnthropic

llm = ChatAnthropic(
    model="claude-3-sonnet-20240229",
    temperature=0.7
)
```

#### Local Models (Ollama)
```python
from langchain_ollama import OllamaLLM

llm = OllamaLLM(model="llama2")
```

### Prompts

#### Prompt Templates
```python
from langchain.prompts import ChatPromptTemplate

template = ChatPromptTemplate.from_messages([
    ("system", "You are a helpful assistant"),
    ("human", "{input}")
])

prompt = template.format_messages(input="Hello")
```

#### Few-Shot Templates
```python
from langchain.prompts import FewShotChatMessagePromptTemplate

examples = [
    {"input": "happy", "output": "positive"},
    {"input": "sad", "output": "negative"}
]

example_prompt = ChatPromptTemplate.from_messages([
    ("human", "{input}"),
    ("ai", "{output}")
])

few_shot_prompt = FewShotChatMessagePromptTemplate(
    example_prompt=example_prompt,
    examples=examples
)
```

#### Output Parsers
```python
from langchain.output_parsers import PydanticOutputParser
from pydantic import BaseModel

class Answer(BaseModel):
    answer: str
    confidence: float

parser = PydanticOutputParser(pydantic_object=Answer)
prompt = ChatPromptTemplate.from_template(
    "Answer: {question}\n{format_instructions}"
)
```

### Chains

#### Simple Chain
```python
from langchain.chains import LLMChain

chain = LLMChain(llm=llm, prompt=prompt)
result = chain.run("What is AI?")
```

#### Sequential Chains
```python
from langchain.chains import SimpleSequentialChain

chain1 = LLMChain(llm=llm, prompt=prompt1)
chain2 = LLMChain(llm=llm, prompt=prompt2)

overall_chain = SimpleSequentialChain(
    chains=[chain1, chain2],
    verbose=True
)
```

#### Router Chains
```python
from langchain.chains.router import MultiPromptChain

chain = MultiPromptChain.from_prompts(
    llm=llm,
    prompts=[prompt1, prompt2],
    verbose=True
)
```

#### Transform Chain
```python
from langchain.chains import TransformChain

def transform_func(inputs):
    text = inputs["text"]
    return {"output": text.upper()}

transform_chain = TransformChain(
    input_variables=["text"],
    output_variables=["output"],
    transform=transform_func
)
```

### Memory

#### Conversation Buffer Memory
```python
from langchain.memory import ConversationBufferMemory

memory = ConversationBufferMemory()
chain = LLMChain(llm=llm, prompt=prompt, memory=memory)
```

#### Conversation Buffer Window Memory
```python
from langchain.memory import ConversationBufferWindowMemory

memory = ConversationBufferWindowMemory(k=5)  # Last 5 exchanges
```

#### Conversation Summary Memory
```python
from langchain.memory import ConversationSummaryMemory

memory = ConversationSummaryMemory(llm=llm)
```

#### Conversation Summary Buffer Memory
```python
from langchain.memory import ConversationSummaryBufferMemory

memory = ConversationSummaryBufferMemory(
    llm=llm,
    max_token_limit=1000
)
```

#### Vector Store Memory
```python
from langchain.memory import VectorStoreRetrieverMemory
from langchain.vectorstores import Chroma

retriever = Chroma(...).as_retriever()
memory = VectorStoreRetrieverMemory(retriever=retriever)
```

### Document Loaders

#### Text Files
```python
from langchain.document_loaders import TextLoader

loader = TextLoader("file.txt")
documents = loader.load()
```

#### PDFs
```python
from langchain.document_loaders import PyPDFLoader

loader = PyPDFLoader("document.pdf")
documents = loader.load()
```

#### Web Pages
```python
from langchain.document_loaders import WebBaseLoader

loader = WebBaseLoader("https://example.com")
documents = loader.load()
```

#### CSV
```python
from langchain.document_loaders import CSVLoader

loader = CSVLoader("data.csv")
documents = loader.load()
```

#### Directory
```python
from langchain.document_loaders import DirectoryLoader

loader = DirectoryLoader(
    "./docs",
    glob="**/*.txt"
)
documents = loader.load()
```

### Text Splitting

#### Character Text Splitter
```python
from langchain.text_splitter import CharacterTextSplitter

splitter = CharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200
)
chunks = splitter.split_documents(documents)
```

#### Recursive Character Text Splitter
```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
    separators=["\n\n", "\n", " ", ""]
)
```

#### Token Text Splitter
```python
from langchain.text_splitter import TokenTextSplitter

splitter = TokenTextSplitter(chunk_size=1000)
```

### Vector Stores

#### Chroma
```python
from langchain.vectorstores import Chroma
from langchain.embeddings import OpenAIEmbeddings

embeddings = OpenAIEmbeddings()
vectorstore = Chroma.from_documents(
    documents=chunks,
    embedding=embeddings
)
```

#### Pinecone
```python
from langchain.vectorstores import Pinecone
import pinecone

pinecone.init(api_key="...", environment="...")
vectorstore = Pinecone.from_documents(
    documents=chunks,
    embedding=embeddings,
    index_name="my-index"
)
```

#### Weaviate
```python
from langchain.vectorstores import Weaviate

vectorstore = Weaviate.from_documents(
    documents=chunks,
    embedding=embeddings
)
```

#### FAISS
```python
from langchain.vectorstores import FAISS

vectorstore = FAISS.from_documents(
    documents=chunks,
    embedding=embeddings
)
vectorstore.save_local("faiss_index")
```

### Retrievers

#### Vector Store Retriever
```python
retriever = vectorstore.as_retriever(
    search_kwargs={"k": 5}
)
docs = retriever.get_relevant_documents("query")
```

#### Multi-Query Retriever
```python
from langchain.retrievers.multi_query import MultiQueryRetriever

retriever = MultiQueryRetriever.from_llm(
    retriever=vectorstore.as_retriever(),
    llm=llm
)
```

#### Contextual Compression
```python
from langchain.retrievers import ContextualCompressionRetriever
from langchain.retrievers.document_compressors import LLMChainExtractor

compressor = LLMChainExtractor.from_llm(llm)
compression_retriever = ContextualCompressionRetriever(
    base_compressor=compressor,
    base_retriever=retriever
)
```

### Agents

#### ReAct Agent
```python
from langchain.agents import create_react_agent
from langchain.tools import Tool

tools = [
    Tool(
        name="Search",
        func=search_function,
        description="Search the web"
    )
]

agent = create_react_agent(llm, tools, prompt)
```

#### Plan-and-Execute Agent
```python
from langchain.agents import create_plan_and_execute_agent

agent = create_plan_and_execute_agent(
    llm=llm,
    tools=tools,
    verbose=True
)
```

#### Custom Tools
```python
from langchain.tools import tool

@tool
def calculate(expression: str) -> str:
    """Evaluate a mathematical expression."""
    return str(eval(expression))

tools = [calculate]
```

#### Tool Use
```python
from langchain.agents import AgentExecutor

executor = AgentExecutor(
    agent=agent,
    tools=tools,
    verbose=True
)

result = executor.invoke({"input": "What is 2+2?"})
```

### RAG Implementation

#### Basic RAG
```python
from langchain.chains import RetrievalQA

qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=retriever
)

result = qa_chain.run("What is the main topic?")
```

#### Conversational RAG
```python
from langchain.chains import ConversationalRetrievalChain

qa_chain = ConversationalRetrievalChain.from_llm(
    llm=llm,
    retriever=retriever,
    memory=memory
)

result = qa_chain({"question": "What is AI?"})
```

#### Advanced RAG Patterns
```python
# Parent Document Retriever
from langchain.retrievers import ParentDocumentRetriever

# Ensemble Retriever
from langchain.retrievers import EnsembleRetriever

# Self-Query Retriever
from langchain.retrievers import SelfQueryRetriever
```

### LangGraph (Advanced)

#### State Graph
```python
from langgraph.graph import StateGraph, END

def node1(state):
    return {"output": "processed"}

graph = StateGraph(dict)
graph.add_node("node1", node1)
graph.add_edge("node1", END)
```

#### Conditional Edges
```python
def should_continue(state):
    if state["step"] > 5:
        return END
    return "continue"

graph.add_conditional_edges(
    "node1",
    should_continue
)
```

---

## RAG (Retrieval-Augmented Generation)

### What is RAG?

**RAG** combines retrieval (finding relevant information) with generation (creating responses). It:
- Reduces hallucinations
- Provides up-to-date information
- Cites sources
- Handles long contexts

### RAG Architecture

#### Components
1. **Document Loader**: Load documents
2. **Text Splitter**: Chunk documents
3. **Embeddings**: Convert to vectors
4. **Vector Store**: Store embeddings
5. **Retriever**: Find relevant chunks
6. **LLM**: Generate response

### RAG Patterns

#### Naive RAG
```
Query → Retrieve → Generate
```

#### Advanced RAG
```
Query → Rewrite → Retrieve → Rerank → Generate
```

#### Modular RAG
```
Query → Multiple Retrievers → Fusion → Generate
```

### Chunking Strategies

#### Fixed Size
- **Simple**: Fixed character/token count
- **Pros**: Easy to implement
- **Cons**: May split sentences

#### Sentence-Aware
- **Split**: On sentence boundaries
- **Pros**: Preserves meaning
- **Cons**: Variable sizes

#### Semantic Chunking
- **Split**: On semantic boundaries
- **Pros**: Better coherence
- **Cons**: More complex

#### Hierarchical Chunking
- **Structure**: Parent-child relationships
- **Pros**: Preserves context
- **Cons**: Complex retrieval

### Embedding Models

#### OpenAI Embeddings
```python
from langchain.embeddings import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(model="text-embedding-3-large")
```

#### Sentence Transformers
```python
from langchain.embeddings import HuggingFaceEmbeddings

embeddings = HuggingFaceEmbeddings(
    model_name="sentence-transformers/all-MiniLM-L6-v2"
)
```

#### Custom Embeddings
```python
from langchain.embeddings.base import Embeddings

class CustomEmbeddings(Embeddings):
    def embed_documents(self, texts):
        # Your embedding logic
        pass
```

### Retrieval Strategies

#### Similarity Search
```python
docs = vectorstore.similarity_search("query", k=5)
```

#### Similarity Search with Score
```python
docs = vectorstore.similarity_search_with_score("query", k=5)
```

#### Max Marginal Relevance
```python
docs = vectorstore.max_marginal_relevance_search(
    "query",
    k=5,
    fetch_k=20
)
```

#### Hybrid Search
```python
# Combine vector and keyword search
from langchain.retrievers import BM25Retriever

bm25_retriever = BM25Retriever.from_documents(documents)
ensemble_retriever = EnsembleRetriever(
    retrievers=[vector_retriever, bm25_retriever],
    weights=[0.5, 0.5]
)
```

### Reranking

#### Cross-Encoder Reranking
```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")
reranked = reranker.rank(query, documents)
```

#### LLM Reranking
```python
# Use LLM to score relevance
prompt = f"Rate relevance 0-10: Query: {query}\nDoc: {doc}"
score = llm.invoke(prompt)
```

### RAG Optimization

#### Query Expansion
```python
# Generate multiple query variations
queries = [
    llm.invoke(f"Rewrite: {query}"),
    llm.invoke(f"Paraphrase: {query}")
]
```

#### Query Compression
```python
# Extract key terms
compressed = llm.invoke(f"Extract key terms: {query}")
```

#### Context Compression
```python
# Summarize retrieved context
compressed = llm.invoke(f"Summarize: {context}")
```

### RAG Evaluation

#### Metrics
- **Retrieval Accuracy**: % of relevant docs retrieved
- **Answer Accuracy**: Correctness of generated answer
- **Faithfulness**: Answer grounded in context
- **Relevance**: Answer relevance to query

#### Evaluation Framework
```python
from langchain.evaluation import EvaluatorType
from langchain.evaluation import load_evaluator

evaluator = load_evaluator(EvaluatorType.QA)
result = evaluator.evaluate(
    examples=examples,
    predictions=predictions
)
```

---

## AI Agents & Orchestration

### What are AI Agents?

**AI Agents** are autonomous systems that:
- Use tools to interact with environment
- Make decisions based on observations
- Plan multi-step tasks
- Maintain memory and context

### Agent Types

#### ReAct Agent
- **Pattern**: Reasoning + Acting
- **Process**: Think → Act → Observe → Repeat
- **Use Cases**: Tool use, problem-solving

#### Plan-and-Execute Agent
- **Pattern**: Plan first, then execute
- **Process**: Create plan → Execute steps
- **Use Cases**: Complex multi-step tasks

#### AutoGPT-Style Agent
- **Pattern**: Autonomous goal pursuit
- **Features**: Long-term memory, web search, file operations
- **Use Cases**: Research, automation

#### Tool-Using Agent
- **Pattern**: Use specific tools
- **Tools**: Calculator, search, code execution
- **Use Cases**: Specialized tasks

### Agent Architecture

#### Components
1. **LLM**: Reasoning engine
2. **Tools**: Available actions
3. **Memory**: Conversation/context history
4. **Planner**: Multi-step planning
5. **Executor**: Execute actions

### Building Agents

#### Simple Agent
```python
from langchain.agents import initialize_agent, AgentType

agent = initialize_agent(
    tools=tools,
    llm=llm,
    agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)

result = agent.run("What is the weather in NYC?")
```

#### Custom Agent
```python
from langchain.agents import AgentExecutor, create_react_agent

prompt = hub.pull("hwchase17/react")
agent = create_react_agent(llm, tools, prompt)
executor = AgentExecutor(agent=agent, tools=tools, verbose=True)
```

#### Multi-Agent Systems
```python
from langchain.agents import AgentExecutor
from langchain.agents import create_react_agent

# Agent 1: Researcher
researcher = create_react_agent(llm, research_tools, prompt)

# Agent 2: Writer
writer = create_react_agent(llm, writing_tools, prompt)

# Orchestrate
def orchestrate(query):
    research_result = researcher.run(f"Research: {query}")
    return writer.run(f"Write about: {research_result}")
```

### Tool Development

#### Custom Tool
```python
from langchain.tools import tool

@tool
def search_database(query: str) -> str:
    """Search internal database."""
    # Your search logic
    return results
```

#### Structured Tool
```python
from langchain.tools import StructuredTool
from pydantic import BaseModel

class SearchInput(BaseModel):
    query: str
    limit: int = 10

search_tool = StructuredTool.from_function(
    func=search_function,
    args_schema=SearchInput,
    name="search",
    description="Search database"
)
```

#### Tool Wrapper
```python
from langchain.tools import Tool

tool = Tool(
    name="Calculator",
    func=calculator,
    description="Perform calculations"
)
```

### Agent Memory

#### Conversation Memory
```python
from langchain.memory import ConversationBufferMemory

memory = ConversationBufferMemory(
    memory_key="chat_history",
    return_messages=True
)
```

#### Long-Term Memory
```python
from langchain.memory import VectorStoreRetrieverMemory

memory = VectorStoreRetrieverMemory(retriever=retriever)
```

### Orchestration Patterns

#### Sequential Orchestration
```python
def sequential_pipeline(query):
    # Step 1: Retrieve context
    context = retriever.get_relevant_documents(query)
    
    # Step 2: Generate answer
    answer = llm.invoke(f"Context: {context}\nQuery: {query}")
    
    # Step 3: Validate
    validation = validator.validate(answer)
    
    return answer if validation else "Unable to answer"
```

#### Parallel Orchestration
```python
import asyncio

async def parallel_pipeline(query):
    # Run multiple tasks in parallel
    results = await asyncio.gather(
        search_web(query),
        search_database(query),
        generate_answer(query)
    )
    return combine_results(results)
```

#### Conditional Orchestration
```python
def conditional_pipeline(query):
    if needs_research(query):
        context = research(query)
    else:
        context = retrieve_from_db(query)
    
    return generate(query, context)
```

### Error Handling

#### Retry Logic
```python
from tenacity import retry, stop_after_attempt

@retry(stop=stop_after_attempt(3))
def call_llm(prompt):
    return llm.invoke(prompt)
```

#### Fallback Strategies
```python
def robust_call(prompt):
    try:
        return primary_llm.invoke(prompt)
    except:
        return fallback_llm.invoke(prompt)
```

#### Validation
```python
def validate_response(response):
    if not response:
        raise ValueError("Empty response")
    if len(response) > max_length:
        raise ValueError("Response too long")
    return response
```

---

## Vector Databases

### What are Vector Databases?

**Vector Databases** store and query high-dimensional vectors (embeddings). They're optimized for:
- Similarity search
- Fast retrieval
- Scalability
- Metadata filtering

### Vector Database Options

#### Pinecone
- **Type**: Managed cloud service
- **Pros**: Easy setup, scalable, fast
- **Cons**: Cost, vendor lock-in
- **Use Cases**: Production applications

#### Weaviate
- **Type**: Open-source, self-hosted or cloud
- **Pros**: GraphQL API, hybrid search
- **Cons**: Setup complexity
- **Use Cases**: Enterprise applications

#### Chroma
- **Type**: Open-source, embedded
- **Pros**: Simple, Python-native
- **Cons**: Limited scalability
- **Use Cases**: Development, small apps

#### Qdrant
- **Type**: Open-source, Rust-based
- **Pros**: Fast, efficient, Docker-ready
- **Cons**: Less mature ecosystem
- **Use Cases**: High-performance applications

#### Milvus
- **Type**: Open-source, distributed
- **Pros**: Scalable, production-ready
- **Cons**: Complex setup
- **Use Cases**: Large-scale applications

#### FAISS (Facebook AI Similarity Search)
- **Type**: Library, not database
- **Pros**: Fast, flexible
- **Cons**: No persistence, no metadata
- **Use Cases**: Research, prototyping

### Vector Database Operations

#### Insertion
```python
vectorstore.add_documents(documents)
vectorstore.add_texts(texts, metadatas=metadatas)
```

#### Querying
```python
# Similarity search
results = vectorstore.similarity_search("query", k=5)

# With metadata filter
results = vectorstore.similarity_search(
    "query",
    k=5,
    filter={"category": "tech"}
)
```

#### Updates
```python
vectorstore.update_document(document_id, new_document)
```

#### Deletion
```python
vectorstore.delete([document_ids])
```

### Hybrid Search

#### Vector + Keyword
```python
# Combine semantic and keyword search
vector_results = vectorstore.similarity_search("query")
keyword_results = bm25_retriever.get_relevant_documents("query")
combined = merge_results(vector_results, keyword_results)
```

#### Metadata Filtering
```python
# Filter by metadata
results = vectorstore.similarity_search(
    "query",
    filter={"date": {"$gte": "2024-01-01"}}
)
```

### Performance Optimization

#### Indexing
- **HNSW**: Hierarchical Navigable Small World
- **IVF**: Inverted File Index
- **PQ**: Product Quantization

#### Batch Operations
```python
# Batch insert for efficiency
vectorstore.add_documents(documents, batch_size=100)
```

#### Caching
```python
# Cache frequent queries
from functools import lru_cache

@lru_cache(maxsize=100)
def cached_search(query):
    return vectorstore.similarity_search(query)
```

---

## Model Integration & APIs

### OpenAI API

#### Chat Completions
```python
from openai import OpenAI

client = OpenAI(api_key="...")

response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[
        {"role": "system", "content": "You are a helpful assistant"},
        {"role": "user", "content": "Hello!"}
    ],
    temperature=0.7,
    max_tokens=1000
)
```

#### Streaming
```python
stream = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=messages,
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

#### Function Calling
```python
functions = [
    {
        "name": "get_weather",
        "description": "Get weather for location",
        "parameters": {
            "type": "object",
            "properties": {
                "location": {"type": "string"}
            }
        }
    }
]

response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=messages,
    functions=functions
)
```

### Anthropic API

#### Claude API
```python
from anthropic import Anthropic

client = Anthropic(api_key="...")

message = client.messages.create(
    model="claude-3-sonnet-20240229",
    max_tokens=1000,
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)
```

### Local Models

#### Ollama
```python
from langchain_ollama import OllamaLLM

llm = OllamaLLM(model="llama2")
response = llm.invoke("Hello!")
```

#### vLLM
```python
# Fast inference server
# API compatible with OpenAI
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy"
)
```

### API Best Practices

#### Rate Limiting
```python
from tenacity import retry, wait_exponential

@retry(wait=wait_exponential(multiplier=1, min=4, max=10))
def call_api(prompt):
    return client.chat.completions.create(...)
```

#### Error Handling
```python
try:
    response = client.chat.completions.create(...)
except openai.RateLimitError:
    # Handle rate limit
    pass
except openai.APIError as e:
    # Handle API error
    pass
```

#### Cost Optimization
```python
# Use smaller models when possible
model = "gpt-3.5-turbo" if simple_task else "gpt-4"

# Cache responses
# Batch requests
# Use streaming for long responses
```

---

## Production AI Systems

### Architecture Patterns

#### Microservices
```
API Gateway → LLM Service → Vector DB → Cache
```

#### Serverless
```
API Gateway → Lambda → S3 (vector store) → DynamoDB
```

#### Event-Driven
```
Event → Queue → Worker → LLM → Response Queue
```

### Scaling Strategies

#### Horizontal Scaling
- **Load Balancer**: Distribute requests
- **Multiple Instances**: Run multiple LLM services
- **Auto-scaling**: Scale based on load

#### Caching
```python
from langchain.cache import InMemoryCache
from langchain.globals import set_llm_cache

set_llm_cache(InMemoryCache())
```

#### Batch Processing
```python
# Process multiple requests together
def batch_process(requests):
    prompts = [r.prompt for r in requests]
    responses = llm.batch(prompts)
    return responses
```

### Monitoring

#### Metrics
- **Latency**: Response time
- **Throughput**: Requests per second
- **Error Rate**: Failed requests
- **Token Usage**: Input/output tokens
- **Cost**: API costs

#### Logging
```python
import logging

logger = logging.getLogger(__name__)

def log_request(prompt, response, latency):
    logger.info({
        "prompt": prompt,
        "response": response,
        "latency": latency
    })
```

#### Observability
- **Tracing**: Request flow
- **Profiling**: Performance bottlenecks
- **Alerting**: Error notifications

### Security

#### API Keys
```python
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("OPENAI_API_KEY")
```

#### Input Validation
```python
def validate_input(prompt):
    if len(prompt) > max_length:
        raise ValueError("Prompt too long")
    if contains_sensitive_data(prompt):
        raise ValueError("Sensitive data detected")
    return prompt
```

#### Output Filtering
```python
def filter_output(response):
    # Remove PII
    # Check for harmful content
    # Validate format
    return sanitized_response
```

### Testing

#### Unit Tests
```python
def test_llm_call():
    response = llm.invoke("Test prompt")
    assert response is not None
    assert len(response) > 0
```

#### Integration Tests
```python
def test_rag_pipeline():
    result = rag_chain.invoke({"query": "test"})
    assert "answer" in result
```

#### Load Tests
```python
# Use tools like Locust, k6
# Test concurrent requests
# Measure latency, throughput
```

---

## Advanced Patterns

### Multi-Agent Systems

#### Agent Collaboration
```python
class ResearchAgent:
    def research(self, topic):
        return search_and_summarize(topic)

class WritingAgent:
    def write(self, research):
        return generate_article(research)

def collaborative_system(topic):
    research = ResearchAgent().research(topic)
    article = WritingAgent().write(research)
    return article
```

#### Agent Communication
```python
# Message passing between agents
class Agent:
    def send_message(self, recipient, message):
        recipient.receive_message(message)
```

### Fine-Tuning

#### When to Fine-Tune
- Domain-specific tasks
- Custom behavior
- Cost optimization
- Privacy requirements

#### Fine-Tuning Process
```python
# Prepare dataset
dataset = load_dataset("your_data")

# Fine-tune model
from transformers import Trainer, TrainingArguments

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset
)
trainer.train()
```

### Prompt Optimization

#### Automatic Prompt Engineering
```python
# Use LLM to optimize prompts
optimizer_prompt = f"""
Optimize this prompt for better results:
{original_prompt}
"""

optimized = llm.invoke(optimizer_prompt)
```

#### Prompt Templates
```python
from langchain.prompts import PromptTemplate

template = PromptTemplate.from_template(
    "You are a {role}. Task: {task}. Context: {context}"
)
```

### Advanced RAG

#### Graph RAG
```python
# Use knowledge graphs
from langchain.graphs import Neo4jGraph

graph = Neo4jGraph()
# Build graph from documents
# Query graph for context
```

#### Multi-Modal RAG
```python
# Handle images, audio, video
from langchain.document_loaders import ImageCaptionLoader

loader = ImageCaptionLoader("image.jpg")
documents = loader.load()
```

### Evaluation

#### RAG Evaluation
```python
from langchain.evaluation import load_evaluator

evaluator = load_evaluator("ragas")
results = evaluator.evaluate(
    questions=questions,
    answers=answers,
    contexts=contexts
)
```

#### Agent Evaluation
```python
# Test agent on tasks
def evaluate_agent(agent, test_cases):
    results = []
    for case in test_cases:
        result = agent.run(case.query)
        results.append({
            "query": case.query,
            "expected": case.expected,
            "actual": result,
            "correct": result == case.expected
        })
    return results
```

---

## Tools & Frameworks

### LangChain Ecosystem

#### LangChain Core
- **Base**: Core abstractions
- **LangChain**: Main framework
- **LangSmith**: Observability platform
- **LangServe**: Production deployment

#### LangChain Integrations
- **LangChain OpenAI**: OpenAI integration
- **LangChain Anthropic**: Claude integration
- **LangChain Community**: Community integrations

### Alternative Frameworks

#### LlamaIndex
- **Focus**: Data indexing and retrieval
- **Strengths**: RAG, data connectors
- **Use Cases**: Document Q&A, data applications

#### Haystack
- **Focus**: End-to-end NLP pipelines
- **Strengths**: Document processing, QA
- **Use Cases**: Enterprise search, Q&A

#### Semantic Kernel
- **Focus**: Microsoft's AI orchestration
- **Strengths**: .NET integration, plugins
- **Use Cases**: .NET applications

### Development Tools

#### LangSmith
- **Purpose**: Debug, test, evaluate
- **Features**: 
  - Tracing
  - Evaluation
  - Prompt management
  - Team collaboration

#### Weights & Biases
- **Purpose**: Experiment tracking
- **Features**: 
  - LLM logging
  - Prompt versioning
  - Evaluation metrics

#### PromptLayer
- **Purpose**: Prompt management
- **Features**: 
  - Version control
  - A/B testing
  - Analytics

---

## Best Practices

### Prompt Engineering

#### Clarity
- Be specific and clear
- Use examples when helpful
- Define output format

#### Iteration
- Test and refine prompts
- A/B test variations
- Track performance

#### Versioning
- Version control prompts
- Track changes
- Compare performance

### System Design

#### Modularity
- Separate components
- Reusable functions
- Clear interfaces

#### Error Handling
- Graceful degradation
- Retry logic
- Fallback strategies

#### Performance
- Caching
- Batching
- Async operations

### Security

#### API Keys
- Never commit keys
- Use environment variables
- Rotate regularly

#### Input Validation
- Validate all inputs
- Sanitize user data
- Check length limits

#### Output Filtering
- Remove PII
- Check for harmful content
- Validate format

### Testing

#### Unit Tests
- Test individual components
- Mock external APIs
- High coverage

#### Integration Tests
- Test full pipelines
- Use test datasets
- Validate outputs

#### Evaluation
- Regular evaluation
- Track metrics
- Compare versions

### Documentation

#### Code Documentation
- Clear docstrings
- Type hints
- Examples

#### System Documentation
- Architecture diagrams
- API documentation
- User guides

---

## Conclusion

AI Engineering is about building production-ready AI systems. Key takeaways:

1. **Master Prompting**: Foundation of LLM applications
2. **Learn LangChain**: Industry standard framework
3. **Understand RAG**: Essential for knowledge applications
4. **Build Agents**: Autonomous AI systems
5. **Production Focus**: Scalability, monitoring, security

The field evolves rapidly. Stay updated with:
- Research papers
- Framework updates
- Best practices
- Community discussions

**Build, deploy, and iterate! 🚀**


