<!--
 This file is Free Software under the Apache-2.0 License
 without warranty, see README.md and LICENSES/Apache-2.0.txt for details.

 SPDX-License-Identifier: Apache-2.0

 SPDX-FileCopyrightText: 2024 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
 Software-Engineering: 2024 Intevation GmbH <https://intevation.de>
-->

<script lang="ts">
  import { appStore } from "$lib/store";
  import { onMount } from "svelte";
  import { request } from "$lib/utils";
  import { Button, ButtonGroup, Input, Label, Listgroup } from "flowbite-svelte";
  import ErrorMessage from "$lib/Errors/ErrorMessage.svelte";
  import { getErrorMessage } from "$lib/Errors/error";
  import AdvisoryTable from "$lib/Advisories/AdvisoryTable.svelte";

  let queries: any[] = [];
  $: sortedQueries = queries.sort((a: any, b: any) => {
    if (a.global && !b.global) {
      return -1;
    } else if (!a.global && b.global) {
      return 1;
    }
    return 0;
  });
  let selectedIndex = 0;
  let errorMessage = "";
  let isAdvancedParametersEnabled = false;
  let advancedQuery = "";
  let appliedAdvancedQuery = "";
  let isAdvancedQueryValid = true;
  let advancedQueryErrorMessage = "";
  let globalQueryButtonColor = "primary";
  let defaultQueryButtonClass = "flex flex-col p-0 focus:text-black hover:text-black";
  let queryButtonClass = "bg-white hover:bg-gray-100";
  let pressedQueryButtonClass = "bg-gray-200 text-black hover:!bg-gray-100";
  let globalQueryButtonClass = `border-${globalQueryButtonColor}-500 hover:!bg-${globalQueryButtonColor}-500 hover:!text-white`;
  let pressedGlobalQueryButtonClass = `border-white bg-${globalQueryButtonColor}-600 focus:text-white text-white hover:!bg-${globalQueryButtonColor}-500 hover:text-white`;

  const getClass = (isGlobal: boolean, isPressed: boolean) => {
    const addition = isGlobal
      ? isPressed
        ? pressedGlobalQueryButtonClass
        : globalQueryButtonClass
      : isPressed
        ? pressedQueryButtonClass
        : queryButtonClass;
    return `${defaultQueryButtonClass} ${addition}`;
  };
  let isPlaceholderListOpen = false;
  let placeholders = [
    {
      parameter: "current_release_date",
      placeholder: "$current_release_date now <hours>h duration - >="
    },
    { parameter: "cvss_v3_score", placeholder: "$cvss_v3_score <number> float >" },
    { parameter: "publisher", placeholder: `$publisher "<name>" =` },
    { parameter: "state", placeholder: "$state <state> workflow =" },
    { parameter: "title", placeholder: `$title "<title>" =` }
  ];
  let autocompleteString = "";
  $: autocompleteOptions = placeholders.filter((p) =>
    `$${p.parameter}`.startsWith(`${autocompleteString}`)
  );
  let focusedAutocompleteEntry = 0;
  let indexOfLastInput = 0;

  onMount(async () => {
    const response = await request("/api/queries", "GET");
    if (response.ok) {
      queries = response.content;
    } else if (response.error) {
      errorMessage = `Could not load user defined queries. ${getErrorMessage(response.error)}`;
    }
  });

  const selectQuery = (index: number) => {
    selectedIndex = index;
  };

  const toggleAdvancedParameters = () => {
    isAdvancedParametersEnabled = !isAdvancedParametersEnabled;
  };

  const testAdvancedQuery = async () => {
    advancedQueryErrorMessage = "";
    const selectedQuery = queries[selectedIndex];
    const query = `${selectedQuery.query} ${advancedQuery.length > 0 ? advancedQuery.concat(" and") : ""}`;
    const documentURL = encodeURI(
      `/api/documents?query=${query}&advisories=${selectedQuery.advisories}&count=1&order=${selectedQuery.orders?.join(" ") ?? ""}&limit=0&columns=${selectedQuery.columns.join(" ")}`
    );
    const result = await request(documentURL, "GET");
    isAdvancedQueryValid = result.ok;
    if (!result.ok) {
      advancedQueryErrorMessage = result.content;
    }
  };

  const handleInput = (event: any) => {
    indexOfLastInput = event.target.selectionStart;
    if (event.inputType === "deleteContentBackward") {
      autocompleteString = autocompleteString.slice(0, -1);
      if (autocompleteString === "") isPlaceholderListOpen = false;
      advancedQueryErrorMessage = "";
      return;
    }
    if (event.data === " ") {
      isPlaceholderListOpen = false;
      autocompleteString = "";
    }
    if (isPlaceholderListOpen) {
      autocompleteString = autocompleteString.concat(event.data);
    }
    const options = placeholders.filter((p) => {
      return `$${p.parameter}`.startsWith(`${autocompleteString}`);
    });
    if (event.data === "$") {
      isPlaceholderListOpen = true;
      autocompleteString = "$";
    }
    if (options.length === 0) {
      isPlaceholderListOpen = false;
    }
    if (focusedAutocompleteEntry > autocompleteOptions.length - 1) {
      focusedAutocompleteEntry = 0;
    }
    if (focusedAutocompleteEntry > options.length - 1) {
      focusedAutocompleteEntry = 0;
    }
    testAdvancedQuery();
  };

  const handleKeyDown = (event: any) => {
    if (isPlaceholderListOpen && ["ArrowDown", "ArrowUp"].includes(event.key))
      event.preventDefault();
    if (!isPlaceholderListOpen) return;
    if (event.key === "ArrowDown") {
      if (focusedAutocompleteEntry === autocompleteOptions.length - 1) {
        focusedAutocompleteEntry = 0;
      } else {
        focusedAutocompleteEntry++;
      }
    } else if (event.key === "ArrowUp") {
      if (focusedAutocompleteEntry === 0) {
        focusedAutocompleteEntry = autocompleteOptions.length - 1;
      } else {
        focusedAutocompleteEntry--;
      }
    } else if (event.key === "Enter") {
      selectPlaceholder(autocompleteOptions[focusedAutocompleteEntry].placeholder);
    }
  };

  const applyAdvancedQueries = () => {
    appliedAdvancedQuery = advancedQuery;
  };

  const selectPlaceholder = (placeholder: string) => {
    const firstPart = advancedQuery.slice(0, indexOfLastInput);
    const insertion = placeholder.replace(autocompleteString, "");
    const secondPart = advancedQuery.slice(indexOfLastInput);
    advancedQuery = `${firstPart}${insertion}${secondPart}`;
    isPlaceholderListOpen = false;
    testAdvancedQuery();
  };
</script>

{#if $appStore.app.isUserLoggedIn}
  {#if queries.length > 0}
    <div class="mb-4 flex gap-x-4">
      <ButtonGroup>
        {#each sortedQueries as query, index}
          <Button
            on:click={() => selectQuery(index)}
            class={getClass(query.global, index === selectedIndex)}
          >
            <span title={query.description} class="m-2 h-full w-full">{query.name}</span>
          </Button>
        {/each}
      </ButtonGroup>
      <Button on:click={toggleAdvancedParameters} color="light">
        <span>Advanced</span>
        {#if isAdvancedParametersEnabled}
          <i class="bx bx-chevron-up text-xl"></i>
        {:else}
          <i class="bx bx-chevron-down text-xl"></i>
        {/if}
      </Button>
    </div>
    {#if isAdvancedParametersEnabled}
      <div class="flex items-end gap-x-2">
        <div>
          <Label for="advanced-parameters">Parameters:</Label>
          <div class="flex gap-x-2">
            <div class="flex flex-col">
              <Input let:props>
                <input
                  id="advanced-parameters"
                  on:input={handleInput}
                  on:keydown={handleKeyDown}
                  bind:value={advancedQuery}
                  {...props}
                  type="text"
                />
              </Input>
              {#if isPlaceholderListOpen}
                <div class="relative">
                  <Listgroup
                    on:click={(e) => selectPlaceholder(e.detail.placeholder)}
                    class="absolute z-10 min-w-80"
                    active
                    items={autocompleteOptions}
                    let:index
                  >
                    <div
                      class={`flex ${index === focusedAutocompleteEntry ? "text-primary-700" : ""}`}
                    >
                      <span class="font-bold">{autocompleteString}</span>
                      <span class="whitespace-nowrap">
                        {autocompleteOptions[index].placeholder.replace(autocompleteString, "")}
                      </span>
                    </div>
                  </Listgroup>
                </div>
              {/if}
            </div>
            <Button on:click={applyAdvancedQueries} disabled={!isAdvancedQueryValid}>Apply</Button>
          </div>
        </div>
      </div>
      {#if advancedQueryErrorMessage.length > 0}
        <ErrorMessage message={advancedQueryErrorMessage}></ErrorMessage>
      {/if}
    {/if}
    {@const query = queries[selectedIndex]}
    <AdvisoryTable
      columns={query.columns}
      loadAdvisories={query.advisories}
      query={`${query.query} ${appliedAdvancedQuery.length > 0 ? appliedAdvancedQuery.concat(" and") : ""}`}
      orderBy={query.orders?.join(" ") ?? ""}
    ></AdvisoryTable>
  {/if}
  <ErrorMessage message={errorMessage}></ErrorMessage>
{/if}
