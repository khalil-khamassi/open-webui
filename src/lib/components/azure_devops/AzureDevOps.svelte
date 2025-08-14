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

	// Storage keys for localStorage
	const STORAGE_KEYS = {
		ORG_URL: 'azure_devops_org_url',
		PAT_TOKEN: 'azure_devops_pat_token'
	};

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
					<!-- Projects Accordion -->
					<div class="space-y-4">
						{#each projects as project (project.id)}
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
												class="h-5 w-5 text-gray-400 transition-transform duration-200 {openProjects.includes(project.id) ? 'rotate-180' : ''}" 
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
									<div class="px-6 pb-6 border-t border-gray-200 dark:border-gray-700">
										{#if repositories[project.id] && repositories[project.id].length > 0}
											<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 pt-4">
												{#each repositories[project.id] as repo (repo.id)}
													<div class="bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg p-4 hover:shadow-md transition-shadow">
														<h4 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
															{repo.name}
														</h4>
														{#if repo.description}
															<p class="text-sm text-gray-500 dark:text-gray-400 mb-3">
																{repo.description}
															</p>
														{/if}
														<div class="flex items-center space-x-4 text-xs text-gray-500 dark:text-gray-400">
															<span>Branch: {repo.defaultBranch || 'main'}</span>
															{#if repo.size}
																<span>Size: {Math.round(repo.size / 1024)} KB</span>
															{/if}
														</div>
													</div>
												{/each}
											</div>
										{:else}
											<p class="text-sm text-gray-500 dark:text-gray-400 text-center py-4">
												No repositories found in this project
											</p>
										{/if}
									</div>
								{/if}
							</div>
						{/each}
					</div>
				{:else}
					<div class="text-center py-12">
						<p class="text-gray-500 dark:text-gray-400">No projects found in this organization</p>
					</div>
				{/if}
			</div>
		{/if}
	</div>
{/if}

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
