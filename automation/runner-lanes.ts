export type RunnerLane = "grants" | "jobs" | "freelancer";
export function runnerLanes(setting: string | undefined): RunnerLane[] {
  if (!setting || setting === "all") return ["grants", "jobs", "freelancer"];
  const lanes = setting.split(",").map(l => l.trim()).filter((l): l is RunnerLane => ["grants", "jobs", "freelancer"].includes(l));
  if (!lanes.length) throw new Error("RUNNER_LANES must include grants, jobs or freelancer");
  return [...new Set(lanes)];
}