#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v ruby >/dev/null || { echo "Ruby is required to parse workflow YAML." >&2; exit 1; }
command -v bash >/dev/null || { echo "Bash is required for shell syntax checks." >&2; exit 1; }

ruby -ryaml -rpathname -e '
root, tmp = ARGV
counter = 0
manifest = File.join(tmp, "manifest.tsv")
File.open(manifest, "w") do |out|
  Dir.glob(File.join(root, ".github/workflows", "*.yml")).sort.each do |path|
    document = YAML.load_file(path, aliases: true)
    jobs = document.is_a?(Hash) ? document["jobs"] : nil
    next unless jobs.is_a?(Hash)

    jobs.each do |job_name, job|
      next unless job.is_a?(Hash) && job["steps"].is_a?(Array)
      runner = job["runs-on"].to_s

      job["steps"].each_with_index do |step, index|
        next unless step.is_a?(Hash) && step["run"].is_a?(String)
        shell = step["shell"].to_s
        shell = runner.include?("windows") ? "pwsh" : "bash" if shell.empty?
        next unless shell == "bash" || shell.start_with?("bash ")

        counter += 1
        output_path = File.join(tmp, "step-#{counter}.sh")
        File.write(output_path, step["run"])
        label = "#{Pathname.new(path).relative_path_from(Pathname.new(root))}: job #{job_name}, step #{index + 1}"
        out.puts([label, output_path].join("\t"))
      end
    end
  end
end
puts "Extracted #{counter} Bash workflow steps for syntax validation."
' "$ROOT_DIR" "$TMP_DIR"

while IFS=$'\t' read -r label path; do
  [[ -n "$path" ]] || continue
  if ! bash -n "$path"; then
    echo "Bash syntax error in $label" >&2
    exit 1
  fi
done < "$TMP_DIR/manifest.tsv"

echo "All extracted Bash workflow steps passed bash -n."
