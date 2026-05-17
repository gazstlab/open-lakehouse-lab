document.addEventListener("click", async (event) => {
  const button = event.target.closest(".copy");

  if (!button) {
    return;
  }

  const code = button.nextElementSibling?.innerText ?? "";

  try {
    await navigator.clipboard.writeText(code);
    button.textContent = "copiado";
    window.setTimeout(() => {
      button.textContent = "copiar";
    }, 1400);
  } catch {
    button.textContent = "selecione";
  }
});
