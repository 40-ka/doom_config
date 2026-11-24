;;; lisp/my-editing.el -*- lexical-binding: t; -*-
;;
;; Поведение редактора: автосохранение, скобки, отступы, пустые строки.







;; Automatically save visited files after 1 second of inactivity.
(use-package! files
  :config
  (setq auto-save-visited-interval 1)
  (auto-save-visited-mode 1))

;; Evil normal: x на пустой паре () {} [] удаляет обе скобки вместе с пробелами, табами и переводами строк между ними, на любом другом символе работает как обычный x.
;; Заменяет sp-delete-char, который не удалял, а перепрыгивал через скобки.
(defun my/evil-x-pair ()
  (interactive)
  (if (looking-at "([ \t\n]*)\\|{[ \t\n]*}\\|\\[[ \t\n]*\\]")
      (delete-region (point) (match-end 0))
    (call-interactively #'evil-delete-char)))

(map! :n "x" #'my/evil-x-pair)

;; Автоудаление пары через перевод строки только если отступ закрывающей скобки равен отступу строки с открывающей.
(after! smartparens
  (defun my/sp--closer-indent-matches-p ()
    (let ((open-indent (current-indentation)))
      (save-excursion
        (and (re-search-forward "[^ \t\n]" nil t)
             (progn (backward-char) (looking-at "[)}\\]]"))
             (= (current-indentation) open-indent)))))
  (defun my/sp-delete-pair-indent-match (fn &rest args)
    (let ((sp-autodelete-pair
           (and sp-autodelete-pair
                (or (not (looking-at "[ \t]*\n"))
                    (my/sp--closer-indent-matches-p)))))
      (apply fn args)))
  (advice-add 'sp-delete-pair :around #'my/sp-delete-pair-indent-match))

(defun my/disable-rust-angle-pair ()
  (when (bound-and-true-p smartparens-mode)
    (sp-local-pair major-mode "<" ">" :actions nil)
    (setq-local sp-local-pairs
                (mapcar (lambda (p)
                          (if (equal (plist-get p :open) "<")
                              (plist-put (copy-sequence p) :actions nil)
                            p))
                        sp-local-pairs))))


(after! smartparens
  (dolist (mode '(rust-mode rustic-mode rust-ts-mode))
    (when (fboundp 'my/sp-rust-lifetime-p)
      (sp-local-pair mode "'" "'" :unless '(:add my/sp-rust-lifetime-p)))
    (sp-local-pair mode "{" nil :post-handlers '(("||\n[i]" "RET")))))

(add-hook 'smartparens-enabled-hook #'my/disable-rust-angle-pair 95)



;; Отступ строки делает основной буфер: у indirect-буфера нет функции отступа режима.
(defun my/indent-line-by-previous ()
  "Отступ по предыдущей непустой строке: +1 уровень после открывающей скобки, -1 перед закрывающей. Строку пропускает, если слева от каретки уже есть текст (кроме строк, начинающихся с закрывающей скобки). Каретка остаётся на месте, если была правее отступа. Невидимый текст (скрытый отступ peek) при расчёте не учитывается."
  (unless (and (save-excursion
                 (skip-chars-backward " \t")
                 (not (bolp)))
               (not (save-excursion
                      (beginning-of-line)
                      (looking-at "[ \t]*[])}]"))))
    (let* ((buffer-invisibility-spec nil)
           (unit (if indent-tabs-mode
                     tab-width
                   (or (and (boundp 'rust-indent-offset) rust-indent-offset)
                       standard-indent)))
           (target
            (save-excursion
              (save-restriction
                (widen)
                (beginning-of-line)
                (let ((closer (looking-at "[ \t]*[])}]")))
                  (if (re-search-backward "[^ \t\n]" nil t)
                      (max 0 (+ (current-indentation)
                                (if (looking-at "[[{(]") unit 0)
                                (if closer (- unit) 0)))
                    0)))))
           (pos (- (point-max) (point))))
      (indent-line-to target)
      (when (> (- (point-max) pos) (point))
        (goto-char (- (point-max) pos))))))

;; Вставка пустой строки с отступом без входа в insert (глобально)
(defun my/blank-line-below ()
  "Пустая строка с отступом ниже текущей; каретка на ней, normal state."
  (interactive)
  (end-of-line)
  (newline)
  (my/indent-line-by-previous))

(defun my/blank-line-above ()
  "Пустая строка с отступом выше текущей; каретка на ней, normal state."
  (interactive)
  (beginning-of-line)
  (newline)
  (forward-line -1)
  (my/indent-line-by-previous))

(map! :ni "M-o" #'my/blank-line-below
      :ni "M-O" #'my/blank-line-above)

;; Единый расчёт отступа для o, O, RET в программных режимах
(defun my/use-common-indent ()
  (when (derived-mode-p 'prog-mode)
    (setq-local indent-line-function #'my/indent-line-by-previous)))
(add-hook 'after-change-major-mode-hook #'my/use-common-indent)





;; Не стирать автоотступ на пустой строке при выходе из insert
(advice-add 'evil-maybe-remove-spaces :override #'ignore)


;; Shift+Tab: убрать один уровень отступа сразу у всех выделенных строк.
;; Visual (v, V, C-v): работает всегда, выделение остаётся.
;; Insert: только пока есть активное выделение (Shift+стрелки, мышь, C-SPC).
;; Без выделения в insert клавиша работает как раньше (yasnippet, completion, org).
;; Шаг отступа берётся из `evil-shift-width', как у команды `<'.
(defun my/dedent-visual ()
  "Сдвинуть влево строки выделения на один отступ, выделение сохранить."
  (interactive)
  (call-interactively #'evil-shift-left)
  (evil-normal-state)
  (evil-visual-restore))

(defun my/dedent-region ()
  "Сдвинуть влево строки активного региона на один отступ, регион сохранить."
  (interactive)
  (let ((deactivate-mark nil)
        (pt (copy-marker (point)))
        (mk (copy-marker (mark))))
    (evil-shift-left (region-beginning) (region-end))
    (goto-char pt)
    (set-mark mk)
    (set-marker pt nil)
    (set-marker mk nil)))

(defun my/dedent--when-region (cmd)
  "Вернуть CMD только при активном выделении; иначе nil, и клавиша пойдёт дальше."
  (and (use-region-p) cmd))

(after! evil
  (define-key evil-visual-state-map (kbd "<backtab>") #'my/dedent-visual)
  (define-key evil-insert-state-map (kbd "<backtab>")
    '(menu-item "" my/dedent-region :filter my/dedent--when-region)))