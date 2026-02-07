# Push Hamro Sewa to GitHub – Full Instructions (Step 1 to Last)

Use this folder: **d:\hamro-sewa**  
GitHub repo: **https://github.com/NirjalaGhimire/Nirjala_Ghimire_HamroSeva**

---

## Option: Create 60 commits (final files, no more changes)

If this is your **final code** and you only need **about 60 commits** (e.g. for project submission) without changing files again:

1. **Run the script (from `d:\hamro-sewa`):**
   ```powershell
   cd d:\hamro-sewa
   .\create_60_commits.ps1
   ```
   This will: remove existing `.git` (if any), run `git init`, then add and commit your project in **~60 small batches** (e.g. backend core, auth, services, then frontend features). You’ll get roughly 60 commits.

2. **Then add remote and push (replace old repo):**
   ```powershell
   git remote add origin https://github.com/NirjalaGhimire/Nirjala_Ghimire_HamroSeva.git
   git branch -M main
   git push -u origin main --force
   ```

After that, GitHub will show ~60 commits and your full project. No need to do Part A below (the script does the “many commits” for you).

---

## Part A: First-time setup – one commit (replace old repo code)

Do these steps **once** to connect this folder to GitHub and replace the old code on the repo.

---

**Step 1 – Open PowerShell and go to the project folder**

```powershell
cd d:\hamro-sewa
```

---

**Step 2 – Initialize Git in this folder**

```powershell
git init
```

You should see: `Initialized empty Git repository in d:\hamro-sewa\.git\`

---

**Step 3 – Stage all files**

```powershell
git add .
```

This adds every file in the folder (respecting `.gitignore`). Nothing is pushed yet.

---

**Step 4 – Create the first commit**

```powershell
git commit -m "Replace repo with correct Hamro Sewa code (frontend + backend)"
```

This creates **one commit** with the whole project. It exists only on your PC until you push.

**Will I be stuck with only one commit?** No. This is just the **first** commit. Later, every time you run `git add .` and then `git commit -m "your message"` again, Git creates a **new** commit (2nd, 3rd, 4th…). So you get many commits: the first has all files; the rest only have the changes you made since the last commit.

---

**Step 5 – Add the GitHub repo as “origin”**

```powershell
git remote add origin https://github.com/NirjalaGhimire/Nirjala_Ghimire_HamroSeva.git
```

If you see **“remote origin already exists”**, run this instead:

```powershell
git remote set-url origin https://github.com/NirjalaGhimire/Nirjala_Ghimire_HamroSeva.git
```

---

**Step 6 – Make sure your branch is named “main”**

```powershell
git branch -M main
```

(GitHub’s default is `main`. If your repo uses `master`, use `git branch -M master` and then use `master` in Step 7.)

---

**Step 7 – Push and replace the code on GitHub (force push)**

```powershell
git push -u origin main --force
```

- **First time:** You may be asked to sign in to GitHub (browser or credentials).
- This **replaces** everything on the repo with this folder’s code. The old commits from the other folder are overwritten.
- After this, GitHub has one commit: “Replace repo with correct Hamro Sewa code”.

**If your default branch on GitHub is `master`:**  
Use `git push -u origin master --force` instead.

---

**Step 8 – Check on GitHub**

Open: **https://github.com/NirjalaGhimire/Nirjala_Ghimire_HamroSeva**

You should see the structure of **this** folder (`backend/`, `frontend/`, etc.), not the old `frontend/hamroseva_app` layout. The old code is gone.

---

## Part B: Daily work – many commits, then push

After Part A, you work with **many commits** and push when you want. The whole folder is **not** replaced again.

---

**Step 9 – Edit your code** as usual in `d:\hamro-sewa`.

---

**Step 10 – Stage changes**

Either everything that changed:

```powershell
git add .
```

Or specific files:

```powershell
git add frontend\lib\main.dart
git add backend\services\views.py
```

---

**Step 11 – Commit (you can do this many times)**

```powershell
git commit -m "feat: add login screen"
```

Examples of messages:

- `git commit -m "fix: payment redirect"`
- `git commit -m "feat: provider verification"`
- `git commit -m "chore: update dependencies"`

You can repeat Step 10 and Step 11 as often as you want (many commits).

---

**Step 12 – Push your new commits to GitHub**

```powershell
git push
```

No `--force` needed. Only your **new commits** are sent. GitHub will show: first “Replace” commit + your new commits. The whole folder is not re-uploaded each time.

---

**Step 13 – Repeat 9 → 10 → 11 → 12** whenever you make changes and want to save them on GitHub.

---

## Quick reference

| What you want              | Command |
|---------------------------|--------|
| Go to project              | `cd d:\hamro-sewa` |
| First-time: init + 1 push  | Steps 1–7 (once) |
| Stage all changes          | `git add .` |
| Commit                     | `git commit -m "your message"` |
| Push (after first time)    | `git push` |
| See status                 | `git status` |
| See commit history         | `git log --oneline` |

---

## If something goes wrong

- **“remote origin already exists”**  
  Use: `git remote set-url origin https://github.com/NirjalaGhimire/Nirjala_Ghimire_HamroSeva.git`

- **Push rejected (e.g. branch is `master` on GitHub)**  
  Use: `git branch -M master` then `git push -u origin master --force` (only for the first push).

- **Nothing to commit**  
  Run `git status`. If no files are listed under “Changes to be committed”, run `git add .` again after saving your files.

- **Want to see what’s staged**  
  `git status` shows staged (green) and unstaged (red) files.
