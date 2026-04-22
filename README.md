# f01 — The Terminal

Companion repository for the **[f01 — The Terminal](https://thecodingidiot.com/chapters/f01-the-terminal)** chapter on [thecodingidiot.com](https://thecodingidiot.com).

---

## Follow my journey

You are working through the implementation pages. Use the tester to verify your work after completing the challenges.

```bash
git clone https://github.com/thecodingidiot-com/f01-the-terminal.git
cd f01-the-terminal
bash test.sh
```

The tester is stateful — it remembers which challenges you have passed. Run it after each implementation page and it will pick up where it left off. Use `bash test.sh --help` to see all options.

---

## Follow your journey

You built it independently. Run the tester to check your solution against the project brief:

```bash
git clone https://github.com/thecodingidiot-com/f01-the-terminal.git
cd f01-the-terminal
bash test.sh
```

Each challenge maps to one deliverable from the project brief. The tester prints `PASS` or `FAIL` with a short explanation for each. If you want to see how a specific challenge is solved, run `bash test.sh --solution N` where N is the challenge number.

---

## What the tester checks

1. Navigate to a directory and create a file there.
2. Copy a file, rename the copy, and delete the original.
3. Write an executable shell script that outputs a word.
4. Extract matching lines from a log file using `grep`.
5. Find all files with a given extension and save the sorted list.
6. Build a pipeline to filter, sort, and deduplicate log output.
7. Append a line to a file without overwriting its contents.
8. Terminate a background process by PID.
9. Export an environment variable from `~/.bashrc` and source it.
10. Replace a word in a file using `vim` or `sed`.
11. Install NetHack.

---

## License

[GPLv2](LICENSE) — the tester code is free to read, modify, and redistribute under the same terms.
