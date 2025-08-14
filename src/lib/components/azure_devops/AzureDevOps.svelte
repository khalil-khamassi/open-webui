<script lang="ts">
	import { onMount, getContext } from 'svelte';
	import { WEBUI_NAME, config, user } from '$lib/stores';

	const i18n = getContext('i18n');

	let loaded = false;
	let showDialog = false;
	let orgUrl = '';
	let patToken = '';
	let isConnected = false;
	let isLoading = false;
	let projects = [];
	let repositories = {};
	let openProjects = [];
	let searchQuery = '';
	let filteredProjects = [];
	let hasSearchResults = true;

	// Storage keys for localStorage
	const STORAGE_KEYS = {
		ORG_URL: 'azure_devops_org_url',
		PAT_TOKEN: 'azure_devops_pat_token'
	};

	// Reactive statements for search functionality
	$: filteredProjects = getFilteredProjects(searchQuery, projects, repositories);
	$: hasSearchResults = filteredProjects.length > 0;
	$: console.log('Search query changed:', searchQuery, 'Filtered projects:', filteredProjects.length);
	$: console.log('Projects:', projects.length, 'Repositories:', Object.keys(repositories).length);

	onMount(async () => {
		loadSavedCredentials();
		loaded = true;
	});

	function loadSavedCredentials() {
		const savedOrgUrl = localStorage.getItem(STORAGE_KEYS.ORG_URL);
		const savedPatToken = localStorage.getItem(STORAGE_KEYS.PAT_TOKEN);
		
		if (savedOrgUrl && savedPatToken) {
			orgUrl = savedOrgUrl;
			patToken = savedPatToken;
			isConnected = true;
			fetchAzureDevOpsData();
		}
	}

	async function fetchAzureDevOpsData() {
		if (!orgUrl || !patToken) return;
		
		isLoading = true;
		try {
			const projectsResponse = await fetch(`${orgUrl}/_apis/projects?api-version=7.0`, {
				headers: {
					'Authorization': `Basic ${btoa(`:${patToken}`)}`,
					'Content-Type': 'application/json'
				}
			});

			if (projectsResponse.ok) {
				const projectsData = await projectsResponse.json();
				projects = projectsData.value || [];
				
				for (const project of projects) {
					await fetchRepositoriesForProject(project.id, project.name);
				}
			}
		} catch (error) {
			console.error('Error fetching Azure DevOps data:', error);
		} finally {
			isLoading = false;
		}
	}

	async function fetchRepositoriesForProject(projectId, projectName) {
		try {
			const reposResponse = await fetch(`${orgUrl}/${projectName}/_apis/git/repositories?api-version=7.0`, {
				headers: {
					'Authorization': `Basic ${btoa(`:${patToken}`)}`,
					'Content-Type': 'application/json'
				}
			});

			if (reposResponse.ok) {
				const reposData = await reposResponse.json();
				repositories[projectId] = reposData.value || [];
			}
		} catch (error) {
			repositories[projectId] = [];
		}
	}

	function saveCredentials() {
		localStorage.setItem(STORAGE_KEYS.ORG_URL, orgUrl);
		localStorage.setItem(STORAGE_KEYS.PAT_TOKEN, patToken);
	}

	function clearCredentials() {
		localStorage.removeItem(STORAGE_KEYS.ORG_URL);
		localStorage.removeItem(STORAGE_KEYS.PAT_TOKEN);
		orgUrl = '';
		patToken = '';
		isConnected = false;
		projects = [];
		repositories = {};
		openProjects = [];
		searchQuery = '';
	}

	function openDialog() {
		showDialog = true;
	}

	function closeDialog() {
		showDialog = false;
	}

	async function handleConnect() {
		saveCredentials();
		isConnected = true;
		closeDialog();
		await fetchAzureDevOpsData();
	}

	function handleDisconnect() {
		clearCredentials();
	}

	function toggleProject(projectId) {
		const index = openProjects.indexOf(projectId);
		if (index > -1) {
			openProjects.splice(index, 1);
		} else {
			openProjects.push(projectId);
		}
		openProjects = [...openProjects];
	}

	// Filter projects and repositories based on search query
	function getFilteredProjects(queryString, projectList, repoMap) {
		if (!queryString || !queryString.trim()) return projectList;
		
		const query = queryString.toLowerCase();
		return projectList.filter(project => {
			// Check if project name or description matches
			const projectMatches = project.name?.toLowerCase().includes(query) || 
								  (project.description && project.description.toLowerCase().includes(query));
			
			// Check if any repository in this project matches
			const repoMatches = repoMap[project.id]?.some(repo => 
				repo.name?.toLowerCase().includes(query) || 
				(repo.description && repo.description.toLowerCase().includes(query))
			) || false;
			
			return projectMatches || repoMatches;
		});
	}

	// Get filtered repositories for a specific project
	function getFilteredRepositories(projectId) {
		if (!searchQuery.trim()) return repositories[projectId] || [];
		
		const query = searchQuery.toLowerCase();
		return (repositories[projectId] || []).filter(repo => 
			repo.name.toLowerCase().includes(query) || 
			(repo.description && repo.description.toLowerCase().includes(query))
		);
	}

	// Check if a project should be shown (has matching repositories or project itself matches)
	function shouldShowProject(project) {
		if (!searchQuery.trim()) return true;
		
		const query = searchQuery.toLowerCase();
		const projectMatches = project.name.toLowerCase().includes(query) || 
							  (project.description && project.description.toLowerCase().includes(query));
		
		const hasMatchingRepos = getFilteredRepositories(project.id).length > 0;
		
		return projectMatches || hasMatchingRepos;
	}

	// Clear search
	function clearSearch() {
		searchQuery = '';
	}

	async function copyToClipboard(text: string) {
		try {
			await navigator.clipboard.writeText(text);
		} catch (e) {
			console.error('Clipboard copy failed', e);
		}
	}

	function getOrgSlugFromOrgUrl(urlStr: string): string {
		try {
			const u = new URL(urlStr);
			if (u.hostname === 'dev.azure.com') {
				const parts = u.pathname.split('/').filter(Boolean);
				if (parts.length > 0) return decodeURIComponent(parts[0]);
			}
			const visualMatch = u.hostname.match(/^([^.]+)\.visualstudio\.com$/i);
			if (visualMatch) return visualMatch[1];
			const parts2 = u.pathname.split('/').filter(Boolean);
			return parts2[0] ? decodeURIComponent(parts2[0]) : '';
		} catch (e) {
			return '';
		}
	}

	function buildCloneUrl(kind: 'https' | 'ssh', projectName: string, repoName: string): string {
		const encProject = encodeURIComponent(projectName);
		const encRepo = encodeURIComponent(repoName);
		let httpsUrl = '';
		try {
			const u = new URL(orgUrl);
			const orgSlug = getOrgSlugFromOrgUrl(orgUrl);
			if (u.hostname === 'dev.azure.com') {
				httpsUrl = `https://${orgSlug}@dev.azure.com/${orgSlug}/${encProject}/_git/${encRepo}`;
			} else if (/visualstudio\.com$/i.test(u.hostname)) {
				httpsUrl = `https://${u.hostname}/${encProject}/_git/${encRepo}`;
			} else {
				// Fallback to dev.azure.com style
				httpsUrl = `https://${orgSlug}@dev.azure.com/${orgSlug}/${encProject}/_git/${encRepo}`;
			}
			const sshUrl = `git@ssh.dev.azure.com:v3/${getOrgSlugFromOrgUrl(orgUrl)}/${encProject}/${encRepo}`;
			return kind === 'ssh' ? sshUrl : httpsUrl;
		} catch (e) {
			// Fallback minimal
			const orgSlug = getOrgSlugFromOrgUrl(orgUrl);
			const sshUrl = `git@ssh.dev.azure.com:v3/${orgSlug}/${encProject}/${encRepo}`;
			const httpsUrl2 = `https://${orgSlug}@dev.azure.com/${orgSlug}/${encProject}/_git/${encRepo}`;
			return kind === 'ssh' ? sshUrl : httpsUrl2;
		}
	}

	let lastCopiedRepoId: string | null = null;
	let lastCopiedType: 'https' | 'ssh' | null = null;
	let lastCopiedTimer: any;

	function handleCloneClick(kind: 'https' | 'ssh', projectName: string, repoName: string, repoId: string) {
		const url = buildCloneUrl(kind, projectName, repoName);
		copyToClipboard(`git clone ${url}`);
		lastCopiedRepoId = repoId;
		lastCopiedType = kind;
		clearTimeout(lastCopiedTimer);
		lastCopiedTimer = setTimeout(() => {
			lastCopiedRepoId = null;
			lastCopiedType = null;
		}, 1500);
	}
</script>

<svelte:head>
	<title>
		{$i18n.t('Azure DevOps')} • {$WEBUI_NAME}
	</title>
</svelte:head>

{#if loaded}
	<div class="w-full min-h-full h-full">
		{#if !isConnected}
			<!-- Connection Screen -->
			<div class="flex flex-col items-center justify-center h-full min-h-[400px] text-center">
				<div class="max-w-md mx-auto">
					<div class="mb-6">
						<div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 dark:bg-blue-900">
							<svg
								class="h-6 w-6 text-blue-600 dark:text-blue-400"
								aria-hidden="true"
								xmlns="http://www.w3.org/2000/svg"
								fill="none"
								viewBox="0 0 24 24"
							>
								<path
									stroke="currentColor"
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"
								/>
							</svg>
						</div>
					</div>
					<h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">
						{$i18n.t('Azure DevOps Integration')}
					</h3>
					<p class="text-sm text-gray-500 dark:text-gray-400 mb-6">
						{$i18n.t('Connect to Azure DevOps to manage work items, repositories, and pipelines.')}
					</p>
					<button
						class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
						on:click={openDialog}
					>
						{$i18n.t('Connect Azure DevOps')}
					</button>
				</div>
			</div>
		{:else}
			<!-- Azure DevOps Data Display -->
			<div class="p-6">
				<!-- Header -->
				<div class="flex items-center justify-between mb-6">
					<div>
						<h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
							{$i18n.t('Azure DevOps')}
						</h2>
						<p class="text-sm text-gray-500 dark:text-gray-400">
							Organization: {orgUrl}
						</p>
					</div>
					<div class="flex space-x-3">
						<button
							class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-200 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 transition-colors"
							on:click={openDialog}
						>
							{$i18n.t('Reconfigure')}
						</button>
						<button
							class="px-4 py-2 text-sm font-medium text-red-700 dark:text-red-300 bg-white dark:bg-gray-800 border border-red-300 dark:border-red-600 rounded-md hover:bg-red-50 dark:hover:bg-red-900 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"
							on:click={handleDisconnect}
						>
							{$i18n.t('Disconnect')}
						</button>
					</div>
				</div>

				{#if isLoading}
					<div class="flex items-center justify-center py-12">
						<div class="text-center">
							<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
							<p class="text-gray-500 dark:text-gray-400">Loading Azure DevOps data...</p>
						</div>
					</div>
				{:else if projects.length > 0}
					<!-- Search Field -->
					<div class="mb-6">
						<div class="relative">
							<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
								<svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
								</svg>
							</div>
							<input
								type="text"
								bind:value={searchQuery}
								placeholder="Search projects or repositories..."
								class="block w-full pl-10 pr-10 py-3 border border-gray-300 dark:border-gray-600 rounded-lg shadow-sm placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:border-gray-600"
							/>
							{#if searchQuery}
								<button
									on:click={clearSearch}
									class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
								>
									<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
									</svg>
								</button>
							{/if}
						</div>
						{#if searchQuery}
							<div class="mt-2 text-sm text-gray-500 dark:text-gray-400">
								Searching for: "{searchQuery}"
							</div>
						{/if}
					</div>

					<!-- Projects Accordion -->
					<div class="space-y-4">
						{#each filteredProjects as project}
							{#if shouldShowProject(project)}
								<div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm">
									<!-- Project Header -->
									<button
										class="w-full px-6 py-4 text-left hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
										on:click={() => toggleProject(project.id)}
									>
										<div class="flex items-center justify-between">
											<div class="flex items-center space-x-3">
												<svg class="h-5 w-5 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
												</svg>
												<h3 class="text-lg font-medium text-gray-900 dark:text-gray-100">
													{project.name}
												</h3>
											</div>
											<div class="flex items-center space-x-3">
												<span class="text-sm text-gray-500 dark:text-gray-400">
													{repositories[project.id]?.length || 0} repositories
												</span>
												<svg 
													class={`h-5 w-5 text-gray-400 transition-transform duration-200 ${openProjects.includes(project.id) ? 'rotate-180' : ''}`}
													fill="none" 
													stroke="currentColor" 
													viewBox="0 0 24 24"
												>
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
												</svg>
											</div>
										</div>
										{#if project.description}
											<p class="text-sm text-gray-500 dark:text-gray-400 mt-2">
												{project.description}
											</p>
										{/if}
									</button>

									<!-- Repositories -->
									{#if openProjects.includes(project.id)}
										{#if getFilteredRepositories(project.id).length > 0}
											<div class="px-6 pb-6 border-t border-gray-200 dark:border-gray-700">
												<div class="space-y-4 pt-4">
													{#each getFilteredRepositories(project.id) as repo}
														<div class="bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg p-4 hover:shadow-md transition-shadow w-full">
															<div class="flex items-start justify-between">
																<div class="flex-1">
																	<h4 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
																		{repo.name}
																	</h4>
																	{#if repo.description}
																		<p class="text-sm text-gray-500 dark:text-gray-400 mb-3">
																			{repo.description}
																		</p>
																	{/if}
																	<div class="flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
																		<div class="flex items-center space-x-4">
																			<span class="flex items-center">
																				<svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
																					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"></path>
																				</svg>
																				{repo.defaultBranch || 'main'}
																			</span>
																			{#if repo.size}
																				<span class="flex items-center">
																					<svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
																						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"></path>
																					</svg>
																					{Math.round(repo.size / 1024)} KB
																				</span>
																			{/if}
																		</div>
																		<div class="ml-4">
																			<div class="relative group inline-block">
																				<button class="px-2 py-1 rounded-md border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 transition text-xs">
																					<span class="inline-flex items-center">
																						<svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2h-3.5a1.5 1.5 0 01-1.5-1.5V3h-6v.5A1.5 1.5 0 019.5 5H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
																						Clone
																					</span>
																				</button>
																				<div class="absolute right-0 mt-2 w-40 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-md shadow-lg hidden group-hover:block z-20">
																					<button class="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-700" on:click={() => handleCloneClick('https', project.name, repo.name, repo.id)}>
																						HTTPS
																					</button>
																					<button class="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-700" on:click={() => handleCloneClick('ssh', project.name, repo.name, repo.id)}>
																						SSH
																					</button>
																					{#if lastCopiedRepoId === repo.id}
																						<div class="px-3 py-2 text-xs text-green-600 dark:text-green-400 border-t border-gray-100 dark:border-gray-700">Copied {lastCopiedType ? lastCopiedType.toUpperCase() : ''}!</div>
																					{/if}
																				</div>
																			</div>
																		</div>
																	</div>
																</div>
															</div>
														</div>
													{/each}
												</div>
											</div>
										{:else}
											<div class="px-6 pb-6 border-t border-gray-200 dark:border-gray-700">
												<p class="text-sm text-gray-500 dark:text-gray-400 text-center py-4">
													No repositories found in this project
												</p>
											</div>
										{/if}
									{/if}
								</div>
							{/if}
						{/each}
						{#if searchQuery && !hasSearchResults}
							<div class="text-center py-12">
								<div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-gray-100 dark:bg-gray-800 mb-4">
									<svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
									</svg>
								</div>
								<h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">
									No results found
								</h3>
								<p class="text-sm text-gray-500 dark:text-gray-400">
									No projects or repositories match "{searchQuery}". Try a different search term.
								</p>
							</div>
						{/if}
					</div>
				{:else}
					<div class="text-center py-12">
						<p class="text-gray-500 dark:text-gray-400">No projects found in this organization</p>
					</div>
				{/if}
			</div>
		{/if}
	</div>
	<!-- Dialog Modal -->
	{#if showDialog}
		<div class="fixed inset-0 bg-black/30 backdrop-blur-sm overflow-y-auto h-full w-full z-50 flex items-center justify-center" on:click={closeDialog}>
			<div class="relative mx-auto p-6 border w-96 shadow-2xl rounded-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700" on:click|stopPropagation>
				<div class="mt-3">
					<h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">
						{$i18n.t('Connect to Azure DevOps')}
					</h3>
					<div class="space-y-4">
						<div>
							<label for="org-url" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
								{$i18n.t('Organization URL')}
							</label>
							<input
								id="org-url"
								type="url"
								bind:value={orgUrl}
								placeholder="https://dev.azure.com/your-org"
								class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
							/>
						</div>
						<div>
							<label for="pat-token" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
								{$i18n.t('Personal Access Token')}
							</label>
							<input
								id="pat-token"
								type="password"
								bind:value={patToken}
								placeholder="••••••••••••••••••••••••••••••••"
								class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
							/>
							<p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
								{$i18n.t('Your token will be stored securely and masked in the interface')}
							</p>
						</div>
					</div>
					<div class="flex justify-end space-x-3 mt-6">
						<button
							class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-200 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 transition-colors"
							on:click={closeDialog}
						>
							{$i18n.t('Cancel')}
						</button>
						<button
							class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
							on:click={handleConnect}
							disabled={!orgUrl || !patToken}
						>
							{$i18n.t('Connect')}
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}
{/if}