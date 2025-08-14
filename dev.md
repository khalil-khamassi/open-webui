## 1. Top-Level Folder and File Structure

- **`src/`**: Frontend application (SvelteKit).
  - `routes/`: SvelteKit routing (pages, layouts, error handling).
  - `lib/`: Shared frontend logic (components, utilities, types, i18n, API wrappers).
- **`backend/`**: Backend application (Python).
  - `open_webui/`: Core backend logic.
    - Routers: API endpoints (e.g., `routers/openai.py`).
    - Models: Data models for database interactions.
    - Sockets: Real-time communication (e.g., `socket/main.py`).
    - Storage/Retrieval: Data storage and retrieval.
    - Internal Utilities: Helper functions and modules.
    - Configuration: Environment and dynamic config (e.g., `config.py`, `env.py`).
  - `data/`: Application data storage.
  - `migrations/`: Database migration scripts (Alembic).
  - `test/`: Backend unit and integration tests.
  - `requirements.txt`: Python dependencies.
- **`static/`**: Static assets for frontend (images, fonts).
- **`docs/`**: Documentation (e.g., `README.md`).
- **`scripts/`**: Utility scripts (Pyodide, setup).
- **`kubernetes/`**: Kubernetes deployment manifests (Helm, Kustomize).
- **`test/`**: Frontend-specific tests.
- **`cypress/`**: End-to-end testing (Cypress).
- **Configuration Files**:
  - `Dockerfile`: Docker container definition.
  - `docker-compose.*.yaml`: Configurations for different environments (GPU, Ollama, Playwright).
  - `pyproject.toml`: Python project metadata.
  - `environment.yml`: Conda environment configuration.
  - `vite.config.ts`: Vite build configuration.
  - `svelte.config.js`: SvelteKit configuration (SSR, static builds, version polling).
  - `tailwind.config.js`: Tailwind CSS configuration.

## 2. Frontend (`src/`) Structure

### 2.1 Main Entry Point
- **File**: `src/routes/+layout.svelte`
  - **Purpose**: Root layout for the SvelteKit application.
  - **Responsibilities**:
    - Initializes global state, theming, internationalization (i18n), and Socket.IO connection.
    - Serves as the parent layout for all routes/pages rendered as children.

### 2.2 Pages, Layouts, Error Boundaries
- **Layouts**:
  - **`src/routes/+layout.svelte`**: Global layout handling session, configuration, socket setup, and theming.
  - **`src/routes/(app)/+layout.svelte`**: Layout for authenticated routes, enforcing user authentication.
- **Pages**:
  - SvelteKit uses file-based routing.
    - Example: `src/routes/auth/+page.svelte` for authentication page.
    - Example: `src/routes/(app)/home/+page.svelte` for the home page.
- **Error Boundaries**:
  - **File**: `src/routes/+error.svelte`
    - **Purpose**: Global error boundary for displaying error status and messages.

### 2.3 Routing Structure & Authentication
- **Route Groups**:
  - **`(app)/`**: Authenticated routes (e.g., `src/routes/(app)/`).
  - **`auth/`**: Public authentication routes (e.g., `src/routes/auth/`).
- **Authentication Management**:
  - **File**: `src/routes/(app)/+layout.svelte`
    - **Logic**: Uses `onMount` to check the `$user` store. If undefined or null, redirects to `/auth`:
      ```ts
      onMount(async () => {
        if ($user === undefined || $user === null) {
          await goto('/auth');
        }
      });
      ```
    - **Purpose**: Ensures all routes under `(app)` require authentication.
  - **Public vs. Authenticated**:
    - Public routes: `/auth`, possibly `/error`.
    - Protected routes: All under `(app)` require a valid user session.

### 2.4 Global State Handling
- **File**: `src/lib/stores/index.ts`
  - **Purpose**: Defines Svelte `writable` stores for global state management.
  - **Key Stores**:
    ```ts
    export const user: Writable<SessionUser | undefined> = writable(undefined);
    export const config: Writable<Config | undefined> = writable(undefined);
    export const socket: Writable<null | Socket> = writable(null);
    export const models: Writable<Model[] | null> = writable(null);
    export const chats: Writable<Chat[] | null> = writable(null);
    ```
  - **Details**:
    - Stores include `user`, `config`, `settings`, `theme`, `socket`, `models`, `chats`, etc.
    - `user` store is set post-login and used for access control.
    - Other stores (`settings`, `models`, etc.) are populated after session establishment.

### 2.5 Key Stores/Utilities
- **`theme`**: Manages theme modes (`'system'`, `'light'`, `'dark'`).
- **`socket`**: Stores the Socket.IO client instance for real-time features.
- **`settings`**: Stores user UI preferences, synced with backend or localStorage.
- **`models`, `chats`, `channels`**: Manage application data, updated via API.
- **Reactive Utilities**: Svelte stores enable reactive updates across components.

### 2.6 Backend Communication
- **REST API Wrapper**:
  - **File**: `src/lib/apis/index.ts`
    - **Size**: 1600+ lines.
    - **Purpose**: Exports async functions for all backend endpoints (e.g., `getModels`, `chatCompletion`, `getUserSettings`).
    - **Implementation**: Uses `fetch` with `WEBUI_BASE_URL`, handles tokens and errors.
- **WebSocket Wrapper**:
  - **Initialization**: In `src/routes/+layout.svelte`:
    ```js
    import { io } from 'socket.io-client';
    import { socket } from '$lib/stores';
    const _socket = io(`${WEBUI_BASE_URL}`, { ... });
    socket.set(_socket);
    ```
    - **Purpose**: Initializes Socket.IO client and stores it in the `socket` store for real-time features.
  - **Usage**: Enables real-time features like chat, presence, and collaborative editing.
  - **Collaborative Editing**: `src/lib/components/common/RichTextInput.svelte` integrates Yjs with Socket.IO for real-time document synchronization.
- **API/Socket Usage**:
  - REST API calls are used in components and layouts for data fetching.
  - Socket events handle real-time updates (e.g., chat messages, document changes).

### 2.7 Environment/Configuration Injection
- **Vite Environment Variables**:
  - Variables like `WEBUI_BASE_URL`, `WEBUI_API_BASE_URL` are defined in `src/lib/constants.ts` and injected via Vite at build time.
  - Version and build metadata are injected (referenced in `vite.config.ts`, `svelte.config.js`).

### 2.8 Reusable Components
- **Location**: `src/lib/components/`
  - **Organization**:
    - `common/`: Generic components (modals, dropdowns, editors).
    - `chat/`: Chat-specific components (messages, input).
    - `layout/`: Layout elements (Sidebar, Navbar, Overlay).
    - Other domains: `admin/`, `app/`, `channel/`, `icons/`.
- **Styling**:
  - Uses Tailwind CSS (`src/tailwind.css`, `tailwind.config.js`).
  - Consistent utility-first styling with dark mode support via `dark:` classes.

### 2.9 Theming & Responsiveness
- **Theming**:
  - Managed by the `theme` store (`'light'`, `'dark'`, `'system'`).
  - Tailwind’s `dark:` classes enable seamless dark mode support.
- **Responsiveness**:
  - Layout components (e.g., `layout/Sidebar.svelte`) use Tailwind’s responsive utilities (`md:`, `lg:`).
  - Mobile detection via the `mobile` store.

### 2.10 Major Frontend Libraries
- **Tiptap**:
  - **File**: `src/lib/components/common/RichTextInput.svelte`
    - **Purpose**: Rich text editor for chat input with custom extensions (AI autocompletion, Yjs collaboration).
    - **Supporting Files**:
      - `src/lib/components/common/RichTextInput/FormattingButtons.svelte`: Formatting controls.
      - `src/lib/components/common/RichTextInput/AutoCompletion.js`: AI-powered autocompletion.
- **CodeMirror**:
  - **File**: `src/lib/components/common/CodeEditor.svelte`
    - **Purpose**: Code editor for code blocks and execution, with language support and theming.
  - **Related**: `src/lib/components/chat/Messages/CodeBlock.svelte` for rendering code in chat.
- **Yjs**:
  - Integrated in `RichTextInput.svelte` with Socket.IO for real-time collaborative editing.
- **i18next**:
  - **File**: `src/lib/i18n/index.ts`
    - **Purpose**: Initializes i18n, loads translations from `src/lib/i18n/locales/{lang}/translation.json`.
    - **Details**:
      - Language detection via querystring, localStorage, or browser settings.
      - Uses Svelte context to provide i18n to components.
      - Supports runtime language changes (`changeLanguage`).
- **PWA**:
  - SvelteKit supports PWA features (manifest, offline support).
- **Other Libraries**:
  - `Chart.js`: Data visualization.
  - `Tippy.js`: Tooltips.
  - `Svelte Sonner`: Toasts.
  - `Mermaid`: Diagrams.
  - `Pyodide`: Python execution in the browser.

### 2.11 Chat Request-Response Cycle
- **User Input**:
  - **File**: `src/lib/components/chat/MessageInput.svelte`
    - **Component**: `<MessageInput />`
    - **Purpose**: Captures user input for chat messages.
- **API Call**:
  - **File**: `src/lib/components/chat/Chat.svelte`
    - **Component**: `<Chat />`
    - **Function**: `sendMessage`
      ```js
      import { chatCompletion } from '$lib/apis/openai';
      ```
    - **API Function**: `chatCompletion` (`src/lib/apis/openai/index.ts`)
      - Sends request to `/api/chat/completions` with payload:
        - `model`: Selected model ID (e.g., `openai/gpt-4`, `ollama/llama3`).
        - `chat_id`: Current chat ID (if continuing a conversation).
        - `messages`: Array of `{ role: 'user'|'assistant', content: string }`.
        - Additional parameters: `temperature`, `top_p`, etc., from UI settings.
      - Uses `fetch` with `ReadableStream` to handle streaming:
        ```js
        const response = await fetch('/api/chat/completions', { ... });
        const reader = response.body.getReader();
        while (true) {
          const { value, done } = await reader.read();
          // Process and append streamed chunks
        }
        ```
- **Streaming Display**:
  - **Files**:
    - `src/lib/components/chat/Messages.svelte`: Renders list of messages, including streaming assistant message.
    - `src/lib/components/chat/Messages/ResponseMessage.svelte`: Renders single assistant response, updating with streamed content.
  - **State**: Messages stored in `chats` store (`src/lib/stores/index.ts`).
    - Streaming updates append to assistant message in store, triggering reactive UI updates.
- **Model Selection**:
  - **File**: `src/lib/components/chat/ModelSelector.svelte`
    - **Component**: `<ModelSelector />`
    - **Purpose**: UI dropdown for selecting LLM model.
  - **Propagation**: Model ID stored in `selectedModel` or `settings` store, included in API payload.
- **Model Metadata**:
  - **Store**: `models` (`src/lib/stores/index.ts`)
  - **File**: `src/lib/apis/index.ts`
    - **Function**: `getModels`
    - **Purpose**: Fetches models from backend and updates `models` store.
- **Extending Chat Experience**:
  - **Tool Buttons**:
    - **Files**: `MessageInput.svelte`, `ChatControls.svelte`
    - **Purpose**: Add buttons for file uploads, tool triggers, etc.
  - **RAG/Plugin Visualization**:
    - **Files**: `Messages/ResponseMessage.svelte`, `Messages/Citations.svelte`, `Messages/ContentRenderer.svelte`
    - **Purpose**: Render RAG results, citations, or plugin outputs.

### 2.12 Tools, Plugins, and Extensions
- **Tool Usage and Function Calling**:
  - **Backend**:
    - **Support**: Supports OpenAI function-calling and tool-call responses.
    - **Files**:
      - `backend/open_webui/routers/openai.py`: Processes `function_call` and `tool_calls` in LLM responses.
      - `backend/open_webui/routers/functions.py`: Registers and executes user-defined Python functions as tools.
      - `backend/open_webui/routers/tools.py`: Manages external tool server registration and invocation.
  - **Frontend**:
    - **Files**:
      - `src/lib/components/chat/Messages/ResponseMessage.svelte`: Renders function/tool call results.
      - `src/lib/components/chat/Tools/`: UI for tool selection and display.
      - `src/lib/apis/functions/index.ts`: API wrapper for tool/function execution.
      - `src/lib/apis/tools/index.ts`: API wrapper for tool server interactions.
    - **Rendering**: `ResponseMessage.svelte` checks for `function_call` or `tool_calls` and displays formatted function name/arguments or results.
- **RAG-Enhanced Responses**:
  - **Backend**:
    - **Files**:
      - `backend/open_webui/routers/retrieval.py`: Handles document retrieval and chunking.
      - `backend/open_webui/main.py` (in `chat_completion`): Prepends RAG document chunks to LLM prompt as system/context messages.
  - **Frontend**:
    - **Files**:
      - `src/lib/components/chat/Messages/Citations.svelte`: Renders citations or source document references.
      - `src/lib/components/chat/Messages/ResponseMessage.svelte`: Integrates RAG metadata rendering.
      - `src/lib/components/chat/Messages/ContentRenderer.svelte`: Renders rich content, including document previews or source chunks.
- **Plugin Interfaces**:
  - **Backend**:
    - **Pipelines**: Integrated via OpenAI-compatible endpoints in `routers/pipelines.py`.
    - **Tools/Functions**:
      - `routers/functions.py`: Registers and calls custom Python functions.
      - `routers/tools.py`: Manages external tool servers.
  - **Frontend**:
    - **Files**:
      - `src/lib/components/chat/Tools/ToolServersModal.svelte`: UI for managing tool servers.
      - `src/lib/components/chat/Tools/`: UI for tool selection and result display.
      - `src/lib/apis/tools/index.ts`: API wrapper for tool server interaction.
  - **Adding a New Tool**:
    - **Backend**: Implement function in `functions.py` or register tool server in `tools.py`.
    - **Frontend**: Add button in `MessageInput.svelte` or `ChatControls.svelte`; render results in `ResponseMessage.svelte` or new component (e.g., `ToolResult.svelte`).
- **Design Recommendation**:
  - **New Tool with UI Button**:
    - **Frontend**: Add button in `MessageInput.svelte` or `ChatControls.svelte` to trigger tool logic or open modal.
  - **Backend Action with Structured JSON**:
    - **Backend**: Register function in `functions.py` or tool server in `tools.py`, returning JSON (e.g., `{ "result": ..., "metadata": ... }`).
  - **Formatted Display**:
    - **Frontend**: Extend `ResponseMessage.svelte` to render tool results, or create new component (e.g., `ToolResult.svelte`) for rich/structured output.

## 3. Backend (`backend/`) Structure

### 3.1 Entry Point & App Initialization
- **File**: `backend/open_webui/main.py`
  - **Purpose**: Main entry point for the FastAPI application.
  - **App Creation**:
    ```python
    app = FastAPI(
        docs_url=None,
        redoc_url=None,
        lifespan=lifespan,
        # ...
    )
    ```
  - **Startup Events & Lifespan**: Uses `@asynccontextmanager` for startup/shutdown events (e.g., database connections, background tasks like `periodic_usage_pool_cleanup`, configuration loading).
  - **Middleware**:
    - `CORSMiddleware`: Handles Cross-Origin Resource Sharing.
    - `AuditLoggingMiddleware`: Audits requests.
    - `SessionMiddleware`: Manages user sessions.
    - Custom middlewares for URL checking, redirecting, and database session management.

### 3.2 Routers & API Endpoints
- **Router Registration**:
  - Routers are imported from `backend/open_webui/routers/` and included in `main.py`:
    ```python
    app.include_router(auths.router, prefix="/api/v1", tags=["auths"])
    app.include_router(users.router, prefix="/api/v1", tags=["users"])
    app.include_router(chats.router, prefix="/api/v1", tags=["chats"])
    # ... and many more
    ```
  - **Endpoint Grouping**: Routers are organized by functionality in `routers/`:
    - `auths.py`: User authentication, login, registration.
    - `models.py`: Model management, listing, configuration.
    - `chats.py`: Chat history and management.
    - `configs.py`: Application configuration.
    - `openai.py`: OpenAI-compatible endpoints.
    - `retrieval.py`: RAG and document management.
    - `functions.py`: User-defined function execution.
    - `tools.py`: External tool server management.
  - **OpenAI-Compatible Endpoints**: `routers/openai.py` implements endpoints like `/openai/chat/completions`, `/openai/models` for OpenAI-compatible LLM interactions.
- **Typical API Call Flow** (e.g., `POST /api/v1/chats/new`):
  1. Frontend sends request with payload and JWT in `Authorization` header.
  2. Request passes through middlewares.
  3. `Depends` injects dependencies (e.g., `get_verified_user` from `open_webui/utils/auth.py` to decode JWT and verify user).
  4. Request body is validated using Pydantic models (e.g., `ChatForm` in `routers/chats.py`).
  5. Endpoint executes business logic, interacting with database or external APIs.
  6. FastAPI returns JSON response.

### 3.3 WebSocket & Real-Time Communication
- **File**: `backend/open_webui/socket/main.py`
  - **Setup**: Creates a `socketio.AsyncServer` instance, optionally using `socketio.AsyncRedisManager` for Redis-based scaling (`WEBSOCKET_MANAGER == "redis"`):
    ```python
    mgr = socketio.AsyncRedisManager(WEBSOCKET_REDIS_URL)
    sio = socketio.AsyncServer(
        # ...
        client_manager=mgr,
    )
    ```
  - **Mounting**: The `sio` app is mounted onto the FastAPI app in `main.py`.
- **Real-Time Events**:
  - Registered using `@sio.on('event-name')`.
  - **Key Events**:
    - `connect`, `disconnect`: Handle client connections.
    - `user-join`: Manages user session joins.
    - `channel-events`: Broadcasts to specific channels/rooms.
    - `ydoc:document:join`, `ydoc:document:update`, `ydoc:awareness:update`: Handle Yjs-based real-time collaborative editing (document state, user cursors/presence).

### 3.4 Plugins & Extensibility
- **File**: `backend/open_webui/routers/pipelines.py`
  - **Framework**: "Pipelines" framework integrates with a separate Pipelines server (e.g., `open-webui/pipelines`).
  - **Mechanism**: Proxies requests to the Pipelines server (configured as an OpenAI-compatible endpoint) for request/response modification (e.g., function calling, rate limiting, content filtering).
  - **Extensibility**: Plugins operate on the backend, modifying LLM output without direct frontend integration.
  - **Integration**: Purely URL-based configuration; no direct code hooks in `open-webui`.
    - Admins configure Pipelines server URL as an OpenAI-compatible endpoint.
    - Requests are sent to the Pipelines server, which processes and forwards to the LLM.
  - **Customization**: Custom logic (e.g., moderation, tool calling) resides in the Pipelines server, or can be added in `routers/openai.py:generate_chat_completion` before the `aiohttp` request.

### 3.5 Configuration & Environment Management
- **`.env` Loading**:
  - **File**: `backend/open_webui/env.py`
    - **Purpose**: Uses `python-dotenv` to load environment variables from `.env` (e.g., `DATABASE_URL`, `OLLAMA_BASE_URL`, `WEBUI_AUTH`).
- **Dynamic Configuration**:
  - **File**: `backend/open_webui/config.py`
    - **Purpose**: Manages runtime configuration stored in the database, merging with default `config.json`.
    - **Endpoints**: `routers/configs.py` exposes `POST /api/v1/configs` for admin users to update settings via the UI.
- **Runtime Configuration**: Supports runtime changes through the settings panel and API.

### 3.6 Models, Database, and Storage
- **ORM**:
  - Uses **SQLAlchemy Core and ORM** for database interactions.
  - **Location**: `backend/open_webui/models/` (e.g., `users.py`, `chats.py`, `models.py`), inheriting from a declarative base in `open_webui/internal/db.py`.
- **Migrations**:
  - Handled by **Alembic** in `backend/open_webui/migrations/versions/`.
  - Run automatically on startup via `run_migrations()` in `config.py`.
- **Vector DB Integrations**:
  - **Location**: `backend/open_webui/retrieval/`, `backend/open_webui/routers/retrieval.py`
  - **Abstraction**: `retrieval/__init__.py` dynamically imports and configures vector stores (Chroma, Qdrant, Milvus, Pinecone) using `get_retriever` based on configuration.
- **Model Registry**:
  - **File**: `backend/open_webui/models/models.py`
    - **Table**: `models` table with fields:
      - `id` (string): Unique identifier (e.g., `ollama/llama3`, `openai/gpt-4`).
      - `name` (string): User-friendly display name.
      - `base_model_id` (string, optional): Base model reference.
      - `params` (JSON): Model parameters (e.g., `temperature`, `top_p`, `ollama` or `openai` configs).
      - `meta` (JSON): Metadata (description, image URL, capabilities).
    - **Backend Determination**: Based on `id` prefix (e.g., `ollama/`, `openai/`) and `params` structure.
  - **Loading Models**:
    - **File**: `backend/open_webui/main.py`
    - **Function**: `get_models(request: Request, refresh: bool = False, user=Depends(get_verified_user))`
    - **Process**: Fetches models from database, Ollama (`ollama.get_ollama_models`), and OpenAI-compatible endpoints (`openai.get_all_models`), merges them, updates database, and returns to frontend.
- **Chat Storage**:
  - **Metadata**:
    - **File**: `backend/open_webui/models/chats.py`
    - **Table**: `chats` table with fields: `id`, `user_id`, `title`, `created_at`, `updated_at`, `history` (JSON).
  - **Messages**:
    - Stored in `history` JSON column as an array of `{role: 'user'|'assistant', content: string}` objects.
    - **Insertion**:
      - User message saved before LLM call via `Chats.insert_chat` or `chat.history["messages"].append` in `main.py:chat_completion`.
      - Assistant message saved after streaming via `Chats.update_chat_by_id` in `main.py:chat_completed` (background task).
  - **RAG Metadata**:
    - Not stored persistently; retrieved chunks are injected into `messages` list during query processing and not saved in `history`.

### 3.7 Authentication & User Sessions
- **JWT**:
  - **File**: `open_webui/utils/auth.py`
    - **Purpose**: Handles JWT creation and verification.
- **OAuth**:
  - **File**: `routers/auths.py`
    - **Purpose**: Supports OAuth 2.0 for Google, GitHub, Microsoft Entra ID, and OIDC using `Authlib`. Creates users in the database and issues JWTs.
- **Token Storage**: Tokens are stored in the browser’s `localStorage` and sent in the `Authorization` header.
- **User Data**:
  - Stored in the `users` table (`models/users.py`) with fields like email, name, role, hashed password.
  - `get_verified_user` dependency retrieves user data from JWT and attaches `UserModel` to the request.

### 3.8 LLM Usage & External APIs
- **LLM Handling**:
  - **Files**: `routers/openai.py`, `routers/ollama.py`
    - **Mechanism**: Separate functions handle calls to different services (Ollama, OpenAI-compatible APIs, Azure OpenAI) with dynamic payload construction.
    - **Streaming**: Uses `StreamingResponse` in `routers/openai.py` (e.g., `generate_chat_completion`) to yield LLM response chunks.
- **LangChain and RAG**:
  - **Location**: `backend/open_webui/retrieval/`
  - **RAG Flow**:
    1. File uploads are processed (chunked, embedded) using embedding models (e.g., Sentence Transformers).
    2. Embeddings are stored in a vector database.
    3. Queries referencing documents (e.g., with `#`) trigger similarity searches in the vector DB.
    4. Retrieved chunks are added to the LLM’s context for response generation.

### 3.9 Chat Completion Request-Response Cycle
- **Frontend Flow**:
  - **User Input**:
    - **File**: `src/lib/components/chat/MessageInput.svelte`
      - **Component**: `<MessageInput />`
      - **Purpose**: Captures user input for chat messages.
  - **API Call**:
    - **File**: `src/lib/components/chat/Chat.svelte`
      - **Component**: `<Chat />`
      - **Function**: `sendMessage`
        ```js
        import { chatCompletion } from '$lib/apis/openai';
        ```
      - **API Function**: `chatCompletion` (`src/lib/apis/openai/index.ts`)
        - Sends request to `/api/chat/completions` with payload:
          - `model`: Selected model ID (e.g., `openai/gpt-4`, `ollama/llama3`).
          - `chat_id`: Current chat ID (if continuing a conversation).
          - `messages`: Array of `{ role: 'user'|'assistant', content: string }`.
          - Additional parameters: `temperature`, `top_p`, etc., from UI settings.
        - Uses `fetch` with `ReadableStream` to handle streaming:
          ```js
          const response = await fetch('/api/chat/completions', { ... });
          const reader = response.body.getReader();
          while (true) {
            const { value, done } = await reader.read();
            // Process and append streamed chunks
          }
          ```
  - **Streaming Display**:
    - **Files**:
      - `src/lib/components/chat/Messages.svelte`: Renders list of messages, including streaming assistant message.
      - `src/lib/components/chat/Messages/ResponseMessage.svelte`: Renders single assistant response, updating with streamed content.
    - **State**: Messages stored in `chats` store (`src/lib/stores/index.ts`).
      - Streaming updates append to assistant message in store, triggering reactive UI updates.
  - **Model Selection**:
    - **File**: `src/lib/components/chat/ModelSelector.svelte`
      - **Component**: `<ModelSelector />`
      - **Purpose**: UI dropdown for selecting LLM model.
    - **Propagation**: Model ID stored in `selectedModel` or `settings` store, included in API payload.
  - **Model Metadata**:
    - **Store**: `models` (`src/lib/stores/index.ts`)
    - **File**: `src/lib/apis/index.ts`
      - **Function**: `getModels`
      - **Purpose**: Fetches models from backend and updates `models` store.
  - **Extending Chat Experience**:
    - **Tool Buttons**:
      - **Files**: `MessageInput.svelte`, `ChatControls.svelte`
      - **Purpose**: Add buttons for file uploads, tool triggers, etc.
    - **RAG/Plugin Visualization**:
      - **Files**: `Messages/ResponseMessage.svelte`, `Messages/Citations.svelte`, `Messages/ContentRenderer.svelte`
      - **Purpose**: Render RAG results, citations, or plugin outputs.
- **Backend Flow**:
  - **Primary Endpoint**: `POST /api/chat/completions` in `backend/open_webui/main.py`
  - **Flow**:
    1. **Entry Point** (`main.py:chat_completion`):
       - **Function**: `chat_completion(request: Request, form_data: dict, user=Depends(get_verified_user), bg_tasks: BackgroundTasks)`
       - **Authentication**:
         - Uses `get_verified_user` (`utils/auth.py`) to decode JWT from `Authorization` header, fetch user from database, and verify status.
       - **Message Storage & RAG**:
         - Extracts `messages`, `model`, `chat_id` from `form_data`.
         - Creates new chat if no `chat_id` via `Chats.insert_chat` (`models/chats.py`).
         - For RAG queries (e.g., with `#`), calls `search` (`routers/retrieval.py`) to fetch document chunks and adds them to `messages` as context.
       - **Dispatch**: Routes to appropriate backend (e.g., `openai.generate_chat_completion` for OpenAI-compatible models).
    2. **OpenAI Proxy** (`routers/openai.py:generate_chat_completion`):
       - **Model Details**: Fetches configuration via `get_model_by_id` (`models/models.py`).
       - **Prompt Formatting**:
         - Uses `apply_model_system_prompt_to_body` and `apply_model_params_to_body_openai` (`utils/payload.py`) to inject system prompt and model parameters.
       - **Streaming**: Makes `POST` request to LLM URL with `aiohttp.ClientSession` (`stream=True`) and yields chunks via `StreamingResponse`.
    3. **Response & Storage**:
       - Streams chunks to frontend for real-time display.
       - Background task (`main.py:chat_completed`) saves full assistant message to database via `update_chat_by_id` (`models/chats.py`).
  - **Pipelines Interception**:
    - Proxies requests to Pipelines server (if configured as model URL) for request/response modification, transparent to Open WebUI.

## 4. Tech Stack

### Frontend
- **Framework**: SvelteKit (Svelte 4) for SPA/PWA.
- **Styling**: Tailwind CSS, PostCSS (responsive, utility-first).
- **Build Tool**: Vite (fast development and production builds).
- **Testing**: Cypress (end-to-end), Vitest (unit testing).
- **Libraries**:
  - `i18next`: Internationalization.
  - `Tiptap`: Rich text editing.
  - `CodeMirror`: Code editing.
  - `Chart.js`: Data visualization.
  - `Pyodide`: Python in browser.
  - PWA support.

### Backend
- **Framework**: FastAPI (ASGI, Python 3.11+).
- **Real-time**: `python-socketio` (WebSocket, Redis message broker).
- **Database**:
  - `SQLAlchemy`: ORM for relational databases (Postgres, MySQL).
  - `Alembic`: Database migrations.
  - Support for MongoDB, Redis, vector DBs (ChromaDB, Milvus, Qdrant, Pinecone).
- **Authentication**:
  - `python-jose`: JWT-based auth.
  - `passlib`: Password hashing.
  - OAuth: Google, Microsoft, GitHub, OIDC.
- **Libraries**:
  - `LangChain`: Language model integration.
  - APIs: OpenAI, Anthropic, Google.
  - `transformers`: Hugging Face NLP models.
  - `APScheduler`: Task scheduling.
  - `Boto3`: AWS integration.

### DevOps/Infrastructure
- **Containerization**: Docker, Docker Compose.
- **Orchestration**: Kubernetes (Helm, Kustomize).
- **CI/CD**: Makefile, shell scripts.
- **Environment**: `.env` files, configuration scripts.

## 5. Architectural Pattern
- **Monolithic but Modular**:
  - **Backend**: Single FastAPI app, modularized into routers, models, sockets, and plugins. Includes a plugin/pipeline framework (`pipelines` router) for extensibility.
  - **Frontend**: SvelteKit SPA/PWA, organized by routes and reusable components.
- **Separation of Concerns**: Clear division between frontend (UI/UX), backend (API, real-time, data), and deployment (Docker, Kubernetes).

## 6. Frontend–Backend Communication
- **REST API**:
  - Endpoints under `/api/` (e.g., `/api/models`, `/api/chat/completions`, `/api/config`).
  - OpenAI-compatible API (`/api/openai/...`) for LLM interactions.
- **WebSocket**:
  - Real-time features (chat, document collaboration, presence) via `python-socketio` (backend) and likely `socket.io-client` (frontend).
  - Redis as message broker for scaling.
- **Static Serving**:
  - Backend serves built frontend from `static/` in production.

## 7. Customization of Chat Completion Flow
- **Add System Message**:
  - **File**: `backend/open_webui/utils/payload.py`
  - **Function**: `apply_model_system_prompt_to_body(body: dict, system: str, messages=[]) -> dict`
  - **Example**:
    ```python
    CUSTOM_MESSAGE = "You are a helpful assistant."
    system = f"{CUSTOM_MESSAGE}\n{system}" if system else CUSTOM_MESSAGE
    ```
- **Support New Model Backend**:
  - Create new router in `routers/new_backend.py` with `generate_chat_completion`.
  - Update `main.py:chat_completion` to dispatch to new backend.
  - Update frontend and `config.py` to support new model selection.
- **Customize Streaming**:
  - **File**: `routers/openai.py:stream_res`
  - **Example**:
    ```python
    async def stream_res(response, session):
        try:
            async for line in response.content.iter_any():
                if line:
                    modified_line = line.replace(b"secret", b"REDACTED")
                    yield modified_line
        finally:
            # ... cleanup logic
    ```

## 8. Tools, Plugins, and Extensions
- **Tool Usage and Function Calling**:
  - **Backend**:
    - **Support**: Supports OpenAI function-calling and tool-call responses.
    - **Files**:
      - `backend/open_webui/routers/openai.py`: Processes `function_call` and `tool_calls` in LLM responses.
      - `backend/open_webui/routers/functions.py`: Registers and executes user-defined Python functions as tools.
      - `backend/open_webui/routers/tools.py`: Manages external tool server registration and invocation.
  - **Frontend**:
    - **Files**:
      - `src/lib/components/chat/Messages/ResponseMessage.svelte`: Renders function/tool call results.
      - `src/lib/components/chat/Tools/`: UI for tool selection and display.
      - `src/lib/apis/functions/index.ts`: API wrapper for tool/function execution.
      - `src/lib/apis/tools/index.ts`: API wrapper for tool server interactions.
    - **Rendering**: `ResponseMessage.svelte` checks for `function_call` or `tool_calls` and displays formatted function name/arguments or results.
- **RAG-Enhanced Responses**:
  - **Backend**:
    - **Files**:
      - `backend/open_webui/routers/retrieval.py`: Handles document retrieval and chunking.
      - `backend/open_webui/main.py` (in `chat_completion`): Prepends RAG document chunks to LLM prompt as system/context messages.
  - **Frontend**:
    - **Files**:
      - `src/lib/components/chat/Messages/Citations.svelte`: Renders citations or source document references.
      - `src/lib/components/chat/Messages/ResponseMessage.svelte`: Integrates RAG metadata rendering.
      - `src/lib/components/chat/Messages/ContentRenderer.svelte`: Renders rich content, including document previews or source chunks.
- **Plugin Interfaces**:
  - **Backend**:
    - **Pipelines**: Integrated via OpenAI-compatible endpoints in `routers/pipelines.py`.
    - **Tools/Functions**:
      - `routers/functions.py`: Registers and calls custom Python functions.
      - `routers/tools.py`: Manages external tool servers.
  - **Frontend**:
    - **Files**:
      - `src/lib/components/chat/Tools/ToolServersModal.svelte`: UI for managing tool servers.
      - `src/lib/components/chat/Tools/`: UI for tool selection and result display.
      - `src/lib/apis/tools/index.ts`: API wrapper for tool server interaction.
  - **Adding a New Tool**:
    - **Backend**: Implement function in `functions.py` or register tool server in `tools.py`.
    - **Frontend**: Add button in `MessageInput.svelte` or `ChatControls.svelte`; render results in `ResponseMessage.svelte` or new component (e.g., `ToolResult.svelte`).
- **Design Recommendation**:
  - **New Tool with UI Button**:
    - **Frontend**: Add button in `MessageInput.svelte` or `ChatControls.svelte` to trigger tool logic or open modal.
  - **Backend Action with Structured JSON**:
    - **Backend**: Register function in `functions.py` or tool server in `tools.py`, returning JSON (e.g., `{ "result": ..., "metadata": ... }`).
  - **Formatted Display**:
    - **Frontend**: Extend `ResponseMessage.svelte` to render tool results, or create new component (e.g., `ToolResult.svelte`) for rich/structured output.

## 9. Summary Tables

### 9.1 General Architecture
| **Layer**       | **Tech/Pattern**                     | **Details/Responsibilities**                                      |
|-----------------|--------------------------------------|------------------------------------------------------------------|
| Frontend        | SvelteKit, Tailwind, Vite            | SPA/PWA, routing, components, i18n, rich text, code editing      |
| Backend         | FastAPI, python-socketio             | REST API, OpenAI API, WebSocket, auth, RAG, plugins              |
| Database        | SQLAlchemy, Alembic, Redis           | Relational/vector DBs, migrations, session/cache                 |
| Real-time       | python-socketio, Redis               | Chat, presence, collaborative docs, real-time events             |
| Styling         | Tailwind CSS, PostCSS                | Utility-first, responsive, themeable styling                     |
| Config          | .env, config.py, Docker              | Environment variables, dynamic config, secrets                   |
| DevOps          | Docker, Kubernetes, Makefile         | Containerization, orchestration, CI/CD automation                |

### 9.2 Chat Request-Response Cycle
| **Area**                | **File/Component/Function**                          | **Purpose**                                    |
|-------------------------|------------------------------------------------------|------------------------------------------------|
| User Input              | `MessageInput.svelte`                                | Captures user input for chat messages           |
| API Call                | `Chat.svelte` → `chatCompletion`                     | Sends request to `/api/chat/completions`       |
| Streaming Handling      | `chatCompletion` (API), `Messages.svelte` (UI)       | Processes and displays streamed response        |
| Streaming State         | `chats` store (`src/lib/stores/index.ts`)            | Stores messages, updated reactively            |
| Model Selection         | `ModelSelector.svelte`                               | UI dropdown for selecting LLM model            |
| Model Metadata          | `src/lib/apis/index.ts` → `getModels`                | Fetches and updates `models` store             |

### 9.3 Tools, Plugins, and Extensions
| **Area**                | **File/Component/Function**                          | **Purpose/Pattern**                            |
|-------------------------|------------------------------------------------------|------------------------------------------------|
| Tool Calls (Backend)    | `routers/functions.py`, `routers/tools.py`           | Register/execute Python tools or tool servers   |
| Tool Calls (API)        | `apis/functions/index.ts`, `apis/tools/index.ts`     | API wrappers for tool/function execution       |
| Tool Calls (UI)         | `chat/Tools/`, `Messages/ResponseMessage.svelte`     | Tool selection and result display              |
| Function Call Render    | `Messages/ResponseMessage.svelte`                    | Renders function/tool call results             |
| RAG Prompt Inject       | `main.py` (chat_completion), `routers/retrieval.py`  | Prepends RAG docs to LLM prompt                |
| RAG UI                 | `Messages/Citations.svelte`, `ContentRenderer.svelte`| Renders citations/source chunks                |
| Plugin/Pipeline         | `routers/pipelines.py`                               | OpenAI-compatible plugin integration           |
| Tool Server UI          | `chat/Tools/ToolServersModal.svelte`                 | Manages tool servers in UI                     |
