;;; lisp/my-rust.el -*- lexical-binding: t; -*-
;;
;; Rust: smartparens для lifetimes, Cargo, отладка через dap-mode.




;;; Rust Cargo
;; Управление Rust-проектами через Cargo.
;; Маленькая буква r — обычный режим разработки.
;; Большая R — Release-режим.

(after! rustic
  (map! :localleader
        ;; Обычный режим разработки.
        :prefix ("r" . "Rust")
        "b" #'rustic-cargo-build
        "r" #'rustic-cargo-run
        "t" #'rustic-cargo-test
        "c" #'rustic-cargo-clippy

        ;; Отладка (dap-mode, настройка в блоке ниже).
        ;; Запуск отладки Rust: SPC m r d.
        ;; Выбирается шаблон запуска из списка адаптера.
        "d" #'+rust/debug
        ;; Поставить или снять брейкпоинт на текущей строке.
        "B" #'dap-breakpoint-toggle
        ;; Завершить сессию отладки.
        "q" #'dap-disconnect)

  ;; Release-сборка.
  ;; Отдельная ветка, не вложенная в Rust-префикс.
  (map! :localleader
        "R" (cons "Release Build"
                  (cmd! (rustic-cargo-build "--release")))))

;;; Rust Debugger (dap-mode)
;; dap-mode Doom больше не ставит сам, он подключён вручную
;; через packages.el. Работает только поверх lsp-mode, поэтому
;; в init.el нужен (lsp +peek), а не (lsp +eglot).

(use-package! dap-mode
  :after lsp-mode
  :config
  ;; Адаптер GDB/LLDB (Native Debug), он показан в галерее
  ;; dap-mode для Rust. Скачивается один раз командой
  ;; M-x dap-gdb-lldb-setup, без неё шаблоны запуска не заработают.
  (require 'dap-lldb)
  (setq dap-lldb-debug-program '("/usr/bin/lldb-dap"))
  (setq dap-lldb-debugged-program-function #'+rust/debug-binary)

  ;; Какие визуальные панели включать:
  ;;   sessions    список сессий (Debug Sessions)
  ;;   locals      локальные переменные текущего фрейма
  ;;   breakpoints список брейкпоинтов
  ;;   expressions панель watch-выражений
  ;;   controls    панель кнопок (continue, step и т. д.)
  (setq dap-auto-configure-features
        '(sessions locals breakpoints expressions controls))

  ;; Положение панели кнопок. Берётся из posframe,
  ;; поэтому он нужен в packages.el.
  (setq dap-ui-controls-screen-position
        #'posframe-poshandler-frame-top-center)

  ;; Включить dap-mode вместе с панелями из списка выше.
  ;; Без этого вызова панели не появятся.
  (dap-auto-configure-mode 1))

;;; Rust: сборка и запуск отладки одним хоткеем

(defun +rust/debug-binary ()
  "Собрать проект (cargo build) и вернуть путь к бинарнику.
Если бинарников несколько, спросит, какой запускать.
Emacs блокируется на время сборки."
  (let* ((default-directory (or (doom-project-root) default-directory))
         (exes nil))
    (with-temp-buffer
      ;; stdout (JSON) в буфер, stderr отбрасываем.
      (unless (zerop (call-process "cargo" nil (list t nil) nil
                                   "build" "--message-format=json"))
        (user-error "cargo build упал, ошибки смотрите через SPC m r b"))
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position))))
          ;; Каждая строка вывода cargo — отдельный JSON-объект.
          ;; Нас интересуют artifact-сообщения с непустым executable.
          (when (string-prefix-p "{" line)
            (let* ((msg (json-parse-string line :object-type 'alist
                                                :null-object nil))
                   (exe (alist-get 'executable msg)))
              (when (and exe (equal (alist-get 'reason msg) "compiler-artifact"))
                (push exe exes)))))
        (forward-line 1)))
    (setq exes (delete-dups (nreverse exes)))
    (pcase (length exes)
      (0 (user-error "Cargo не собрал ни одного бинарника"))
      (1 (car exes))
      (_ (completing-read "Бинарник: " exes nil t)))))

(defun +rust/debug ()
  "Сохранить файлы, собрать проект и сразу запустить отладку."
  (interactive)
  (save-some-buffers t)
  ;; :program nil заставляет dap-lldb вызвать
  ;; dap-lldb-debugged-program-function (см. блок dap-mode выше),
  ;; а он собирает проект и возвращает путь к бинарнику.
  (dap-debug (list :type "lldb-vscode"
                   :request "launch"
                   :name "Rust::Run"
                   :cwd (or (doom-project-root) default-directory)
                   :program nil)))
