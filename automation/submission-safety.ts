/** Runs inside the portal browser. Never supplies or changes an answer. */
export function requiredAnswerBlockers(): string[] {
  const blockers: string[] = [];
  const controls = document.querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>(
    "input[required], select[required], textarea[required], input[aria-required='true'], select[aria-required='true'], textarea[aria-required='true']",
  );
  for (const control of controls) {
    if (control.disabled || (control instanceof HTMLInputElement && control.type === "hidden")) continue;
    const label = control.getAttribute("aria-label") || control.labels?.[0]?.textContent?.trim() || control.name || control.id || "Required answer";
    if (control instanceof HTMLInputElement && control.type === "radio") {
      const group = control.name ? Array.from(document.getElementsByName(control.name)) : [control];
      if (!group.some(input => input instanceof HTMLInputElement && input.checked)) blockers.push(label);
    } else if (control instanceof HTMLInputElement && control.type === "checkbox") {
      if (!control.checked) blockers.push(label);
    } else if (control instanceof HTMLInputElement && control.type === "file") {
      if (!control.files?.length) blockers.push(label);
    } else if (!control.value.trim() || !control.validity.valid) {
      blockers.push(label);
    }
  }
  return [...new Set(blockers)];
}