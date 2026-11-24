;;; lisp/my-peek.el -*- lexical-binding: t; -*-
;;
;; Peek: рамка с соседними строками поверх приглушённого окна (F8 / SPC o l).
;; Зависит от my/indent-line-by-previous из my-editing.el, поэтому грузится после него.

;;; ------------------------------------------------------------------
;;; Peek: рамка с соседними строками поверх приглушённого окна.
;;; F8 или SPC o l открывает; j/k или стрелки двигают; Esc, q, C-g закрывают.
;;; ------------------------------------------------------------------
(require 'posframe)

(defconst my/peek--box "*peek-box*")
(defvar my/peek--origin-window nil)
(defvar my/peek--dimmed nil)

(defvar my/peek-context 3
  "Сколько строк показывать выше и ниже средней.")
(defvar my/peek-scale 1.8
  "Во сколько раз крупнее шрифт средней строки.")
(defvar my/peek-dim-level 0.08
  "Яркость приглушённого текста в основном окне: меньше = темнее.")
(defvar my/peek-context-dim 0.15
  "Яркость серых боковых строк в рамке: меньше = темнее, ближе к фону.")

(defun my/peek--blend (fg bg k)
  "Смешать цвета FG и BG; K = доля FG."
  (let ((a (color-name-to-rgb fg))
        (b (color-name-to-rgb bg)))
    (when (and a b)
      (apply #'color-rgb-to-hex
             (append (cl-mapcar (lambda (x y) (+ (* k x) (* (- 1 k) y))) a b)
                     '(2))))))

(defun my/peek--dim-buffers ()
  "Приглушить цвета текста во всех видимых буферах."
  (let ((bg (face-background 'default nil t))
        (seen nil))
    (dolist (win (window-list nil 'no-mini))
      (let ((buf (window-buffer win)))
        (unless (memq buf seen)
          (push buf seen)
          (let (cookies)
            (with-current-buffer buf
              (dolist (face (face-list))
                (let* ((fg (face-foreground face nil t))
                       (new (and (stringp fg)
                                 (my/peek--blend fg bg my/peek-dim-level))))
                  (when new
                    (push (face-remap-add-relative face :foreground new)
                          cookies)))))
            (push (cons buf cookies) my/peek--dimmed)))))))

(defun my/peek--undim-buffers ()
  "Вернуть прежние цвета во всех приглушённых буферах."
  (dolist (entry my/peek--dimmed)
    (when (buffer-live-p (car entry))
      (with-current-buffer (car entry)
        (mapc #'face-remap-remove-relative (cdr entry)))))
  (setq my/peek--dimmed nil))

(defun my/peek--fontify (beg end)
  "Подсветить строки BEG..END в основном буфере с полным контекстом файла."
  (let ((base (or (buffer-base-buffer) (current-buffer))))
    (with-current-buffer base
      (save-restriction
        (widen)
        (font-lock-ensure beg end)))))

(defun my/peek--trim-indent ()
  "Скрыть общую для всех строк рамки часть отступа (невидимый текст)."
  (let ((min-ind nil))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (skip-chars-forward " \t")
        (unless (eolp)
          (let ((ind (current-column)))
            (setq min-ind (if min-ind (min min-ind ind) ind))))
        (forward-line 1)))
    (when (and min-ind (> min-ind 0))
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (let ((b (point)))
            (skip-chars-forward " \t")
            (unless (eolp)
              (let ((e (point)))
                (goto-char b)
                (move-to-column min-ind)
                (when (> (current-column) min-ind)
                  (backward-char))
                (when (> (point) b)
                  (let ((ov (make-overlay b (point))))
                    (overlay-put ov 'my-peek t)
                    (overlay-put ov 'invisible t)))
                (goto-char e))))
          (forward-line 1))))))

(defun my/peek--render (col)
  "Показать строки вокруг текущей: текущая посередине и с подсветкой, остальные серые."
  (let ((n my/peek-context) above below beg end)
    (widen)
    (remove-overlays (point-min) (point-max) 'my-peek t)
    (save-excursion
      (beginning-of-line)
      (setq above (min n (count-lines (point-min) (point))))
      (forward-line (- above))
      (setq beg (point)))
    (save-excursion
      (end-of-line)
      (setq below (if (>= (point) (point-max))
                      0
                    (min n (count-lines (1+ (point)) (point-max)))))
      (forward-line below)
      (end-of-line)
      (setq end (point)))
    (my/peek--fontify beg end)
    (narrow-to-region beg end)
	;; Подчёркивания ошибок. Оверлеи flycheck принадлежат основному
    ;; буферу, поэтому копируем их сюда для видимого диапазона.
    (let ((base (buffer-base-buffer)))
      (when base
        (dolist (ov (with-current-buffer base (overlays-in beg end)))
          (when (overlay-get ov 'flycheck-error)
            (let ((new (make-overlay (max beg (overlay-start ov))
                                     (min end (overlay-end ov)))))
              (overlay-put new 'my-peek t)
              (overlay-put new 'face (overlay-get ov 'face))
              (overlay-put new 'priority 20))))))
    ;; пустые строки сверху и снизу у краёв файла
    (when (< above n)
      (let ((ov (make-overlay (point-min) (point-min))))
        (overlay-put ov 'my-peek t)
        (overlay-put ov 'before-string (make-string (- n above) ?\n))))
    (when (< below n)
      (let ((ov (make-overlay (point-max) (point-max))))
        (overlay-put ov 'my-peek t)
        (overlay-put ov 'after-string
                     (concat (make-string (- n below) ?\n) " "))))
    (let* ((lb (line-beginning-position))
           (le (min (point-max) (1+ (line-end-position))))
           (gray (or (my/peek--blend
                      (or (face-foreground 'default nil t) "#ffffff")
                      (or (face-background 'default nil t) "#000000")
                      my/peek-context-dim)
                     "gray50")))
      ;; серые боковые строки
      (dolist (range (list (cons (point-min) lb) (cons le (point-max))))
        (when (< (car range) (cdr range))
          (let ((ov (make-overlay (car range) (cdr range))))
            (overlay-put ov 'my-peek t)
            (overlay-put ov 'face `(:foreground ,gray))
            (overlay-put ov 'priority 10))))
      ;; крупный шрифт у средней строки
      (let ((ov (make-overlay lb le)))
        (overlay-put ov 'my-peek t)
        (overlay-put ov 'face `(:height ,my/peek-scale))
        (overlay-put ov 'priority 10)))
    (move-to-column col)
	(my/peek--trim-indent)
    (my/peek--note-state)))

(defun my/peek--sync-origin (pos)
  "Подвести основное окно к POS, чтобы подсветка дошла до строк рамки."
  (when (window-live-p my/peek--origin-window)
    (with-selected-window my/peek--origin-window
      (save-restriction
        (widen)
        (goto-char pos)
        (recenter)
        (let (b e)
          (save-excursion
            (forward-line (- my/peek-context))
            (setq b (point))
            (goto-char pos)
            (forward-line my/peek-context)
            (end-of-line)
            (setq e (point)))
          (jit-lock-fontify-now b e))))))

(defvar my/peek--last-line nil)
(defvar my/peek--last-count nil)

(defun my/peek--note-state ()
  "Запомнить, какая строка и сколько строк были при последней отрисовке."
  (setq my/peek--last-line (line-number-at-pos (point) t)
        my/peek--last-count (count-lines (point-min) (point-max))))

(defun my/peek--refresh ()
  "Перерисовать рамку так, чтобы строка с кареткой стала средней."
  (let ((col (current-column)))
    (my/peek--sync-origin (point))
    (my/peek--render col)
    (let ((w (get-buffer-window (current-buffer) t)))
      (when w
        (set-window-start w (point-min))
        (set-window-point w (point))))
    (my/peek--reposition)))

(defun my/peek--post-command ()
  "После команды в рамке: перерисовать при смене строки или числа строк, поправить сдвиг."
  (when (and (get-buffer my/peek--box)
             (eq (current-buffer) (get-buffer my/peek--box)))
    (when (or (not (eql my/peek--last-line (line-number-at-pos (point) t)))
              (not (eql my/peek--last-count
                        (count-lines (point-min) (point-max)))))
      (my/peek--refresh))
    (my/peek--fix-hscroll)))

(defun my/peek--fix-hscroll ()
  "Горизонтальный сдвиг рамки: 0, пока каретка помещается; иначе сдвигать рывком, когда она подошла к краю."
  (let ((w (get-buffer-window my/peek--box t)))
    (when w
      (with-current-buffer my/peek--box
        (let* ((cw (frame-char-width))
               (bw (window-body-width w t))
               (margin (* 6 cw))
               (x (car (window-text-pixel-size
                        w (line-beginning-position) (point) 100000)))
               (cur (* (window-hscroll w) cw)))
          (cond
           ((< x (- bw margin))
            (set-window-hscroll w 0))
           ((or (< x (+ cur margin))
                (> x (- (+ cur bw) margin)))
            (set-window-hscroll w (max 0 (/ (- x (/ bw 2)) cw))))))))))

(defun my/peek--reposition ()
  "Подогнать размер рамки и заново поставить её по центру, не пересоздавая."
  (let ((buf (get-buffer my/peek--box)))
    (when buf
      (let ((pt (with-current-buffer buf (point)))
            (w (get-buffer-window buf t)))
        (when w
          (set-window-start w (with-current-buffer buf (point-min)))
          (set-window-point w pt))
        (when (fboundp 'posframe-refresh)
          (posframe-refresh buf))
        (let* ((f (buffer-local-value 'posframe--frame buf))
               (p (and (frame-live-p f) (frame-parent f))))
          (when p
            (set-frame-position
             f
             (max 0 (/ (- (frame-pixel-width p) (frame-pixel-width f)) 2))
             (max 0 (/ (- (frame-pixel-height p) (frame-pixel-height f)) 2)))))
        (when w
          (set-window-point w pt))
        (my/peek--fix-hscroll)))))

(defvar my/peek--parent-size nil)

(defun my/peek--on-resize (frame)
  "При смене размера основного фрейма заново центрировать рамку."
  (when (and (get-buffer my/peek--box)
             (window-live-p my/peek--origin-window)
             (eq frame (window-frame my/peek--origin-window))
             (not (equal my/peek--parent-size
                         (cons (frame-pixel-width frame)
                               (frame-pixel-height frame)))))
    (setq my/peek--parent-size
          (cons (frame-pixel-width frame) (frame-pixel-height frame)))
    (my/peek--reposition)))

(defun my/peek-move (n)
  "Сдвинуть содержимое на N строк, каретка остаётся посередине."
  (let ((col (current-column)))
    (widen)
    (forward-line n)
	(my/peek--sync-origin (point))
    (my/peek--render col)
    (let ((w (get-buffer-window (current-buffer) t)))
      (when w (set-window-start w (point-min))))
    (my/peek--reposition)))

(defvar my/peek--exit nil
  "Функция, снимающая временную раскладку клавиш peek.")

(defun my/peek-up ()
  (interactive)
  (with-current-buffer my/peek--box (my/peek-move -1)))

(defun my/peek-down ()
  (interactive)
  (with-current-buffer my/peek--box (my/peek-move 1)))

(defun my/peek--show-frame ()
  "Показать или пересчитать рамку. Размер зависит от масштаба шрифта в ней."
  (let ((k (with-current-buffer my/peek--box
             (expt text-scale-mode-step
                   (or (bound-and-true-p text-scale-mode-amount) 0)))))
    (posframe-show my/peek--box
                   :poshandler #'posframe-poshandler-frame-center
                   :min-width (round (* 60 k))
                   :max-width (round (* 100 k))
                   :min-height (round (* (1+ (* 2 my/peek-context)) k))
                   :lines-truncate t
                   :internal-border-width 3
                   :internal-border-color (face-foreground 'default nil t)
                   :background-color (face-background 'default nil t)
                   :foreground-color (face-foreground 'default nil t)
                   :accept-focus t)))

(defun my/peek-zoom (delta)
  "Изменить шрифт в рамке на DELTA шагов и подогнать размер рамки."
  (let ((pt (with-current-buffer my/peek--box
              (text-scale-increase delta)
              (point))))
    (my/peek--show-frame)
    ;; posframe сбрасывает позицию в окне, возвращаем на прежнюю строку
    (let ((w (get-buffer-window my/peek--box t)))
      (when w
        (set-window-start w (with-current-buffer my/peek--box (point-min)))
        (set-window-point w pt)))))

(defun my/peek-bigger ()
  (interactive)
  (my/peek-zoom 1))

(defun my/peek-smaller ()
  (interactive)
  (my/peek-zoom -1))

(defun my/peek-close ()
  "Закрыть рамку, снять затемнение, вернуть каретку на выбранную строку."
  (interactive)
  (let ((pos (if (buffer-live-p (get-buffer my/peek--box))
                 (with-current-buffer my/peek--box (point))
               (point))))
    (my/peek--undim-buffers)
    (when my/peek--exit
      (ignore-errors (funcall my/peek--exit))
      (setq my/peek--exit nil))
    (ignore-errors (posframe-hide my/peek--box))
    (when (get-buffer my/peek--box)
      (kill-buffer my/peek--box))
    (when (window-live-p my/peek--origin-window)
      (let ((frame (window-frame my/peek--origin-window)))
        (select-frame-set-input-focus frame)
        (select-window my/peek--origin-window)
        (goto-char pos)
        ;; Повторный запрос фокуса, когда X/i3 уже обработали скрытие рамки.
        (run-with-timer 0.1 nil
                        (lambda (f)
                          (when (frame-live-p f)
                            (select-frame-set-input-focus f)))
                        frame)))))

(defun my/peek--normal-only (cmd)
  "Вернуть CMD только в normal state; иначе nil, и клавиша пойдёт как обычный ввод."
  (and (eq (bound-and-true-p evil-state) 'normal) cmd))

(defconst my/peek-map
  (let ((map (make-sparse-keymap)))
    ;; всегда закрывают
    (dolist (k '("C-g" "<f8>"))
      (define-key map (kbd k) #'my/peek-close))
    ;; закрывают только в normal state; в insert Esc выходит из insert, q печатается
    (dolist (k '("<escape>" "q"))
      (define-key map (kbd k)
        '(menu-item "" my/peek-close :filter my/peek--normal-only)))
    ;; стрелки двигают всегда
    (define-key map (kbd "<up>") #'my/peek-up)
    (define-key map (kbd "<down>") #'my/peek-down)
    ;; j и k двигают только в normal state
    (define-key map (kbd "k")
      '(menu-item "" my/peek-up :filter my/peek--normal-only))
    (define-key map (kbd "j")
      '(menu-item "" my/peek-down :filter my/peek--normal-only))
    ;; масштаб рамки вместе с шрифтом (только в normal state)
    (dolist (k '("+" "="))
      (define-key map (kbd k)
        '(menu-item "" my/peek-bigger :filter my/peek--normal-only)))
    (define-key map (kbd "-")
      '(menu-item "" my/peek-smaller :filter my/peek--normal-only))
    ;; колесо мыши: одна ступень = одна строка, как j/k
    (dolist (k '("<wheel-up>" "<mouse-4>"
                 "<double-wheel-up>" "<triple-wheel-up>"))
      (define-key map (kbd k) #'my/peek-up))
    (dolist (k '("<wheel-down>" "<mouse-5>"
                 "<double-wheel-down>" "<triple-wheel-down>"))
      (define-key map (kbd k) #'my/peek-down))
    ;; горизонтальную прокрутку колесом в рамке гасим
    (dolist (k '("<wheel-left>" "<wheel-right>"))
      (define-key map (kbd k) #'ignore))
    map))

(defvar my/peek--mid nil
  "Позиция каретки на средней строке в буфере рамки.")

;; Включает smartparens в indirect-буфере и копирует пары и синтаксис исходного буфера.
(defun my/peek--enable-sp (origin)
  (when (fboundp 'smartparens-mode)
    (set-syntax-table (with-current-buffer origin (syntax-table)))
    (setq-local indent-line-function #'my/indent-line-by-previous)
    (smartparens-mode 1)
    ;; Пары берём готовым списком из основного буфера, чтобы поведение совпадало.
    (setq-local sp-local-pairs
                (copy-tree (buffer-local-value 'sp-local-pairs origin)))))

(defun my/peek-line ()
  "Открыть рамку с кареткой и соседними строками; повторный вызов закрывает."
  (interactive)
  (if (get-buffer my/peek--box)
      (my/peek-close)
    (my/peek--undim-buffers)
    (setq my/peek--origin-window (selected-window))
    (let ((origin (current-buffer))
          (pt (point)))
      ;;(with-current-buffer (make-indirect-buffer origin my/peek--box nil t)
        ;;(goto-char pt)
        ;;(setq-local mode-line-format nil
                    ;;header-line-format nil
                    ;;truncate-lines t
                    ;;scroll-margin 0)
      (with-current-buffer (make-indirect-buffer origin my/peek--box nil nil)
        (goto-char pt)
		(my/peek--enable-sp origin)
		;; Настройки отступов берём из исходного буфера
        (dolist (v '(tab-width indent-tabs-mode standard-indent
                     evil-shift-width evil-auto-indent
                     rust-indent-offset c-basic-offset
                     python-indent-offset js-indent-level
                     tab-always-indent))
          (when (boundp v)
            (set (make-local-variable v) (buffer-local-value v origin))))
        (setq-local mode-line-format nil
                    header-line-format nil
                    truncate-lines t
					auto-hscroll-mode nil
                    scroll-margin 0)
        ;; Правки в этом буфере не запускают хуки основного буфера,
        ;; поэтому LSP о них не узнает. Передаём уведомления вручную.
        (add-hook 'before-change-functions
                  (lambda (beg end)
                    (let ((base (buffer-base-buffer)))
                      (when base
                        (with-current-buffer base
                          (run-hook-with-args 'before-change-functions beg end)))))
                  nil t)
        (add-hook 'after-change-functions
                  (lambda (beg end len)
                    (let ((base (buffer-base-buffer)))
                      (when base
                        (with-current-buffer base
                          (run-hook-with-args 'after-change-functions beg end len)))))
                  nil t)
        (when (bound-and-true-p evil-mode)
          (evil-local-mode 1)
          (evil-normal-state))
		(add-hook 'post-command-hook #'my/peek--post-command nil t)
		(my/peek--sync-origin (point))
        (my/peek--render (current-column))
        (setq my/peek--mid (point)))
      (my/peek--dim-buffers)
      (setq my/peek--exit
            (set-transient-map my/peek-map
                               (lambda () (and (get-buffer my/peek--box) t))))
      (let ((frame (my/peek--show-frame)))
        ;; posframe ставит точку окна в начало буфера; возвращаем на среднюю строку
        (let ((w (get-buffer-window my/peek--box t)))
          (when (and w my/peek--mid)
            (set-window-start w (with-current-buffer my/peek--box (point-min)))
            (set-window-point w my/peek--mid)))
		(my/peek--fix-hscroll)
        (select-frame-set-input-focus frame)))))

(defun my/peek--trim-ok (beg end)
  "Не стричь диапазон, в котором каретка рамки."
  (let ((box (get-buffer my/peek--box)))
    (not (and box
              (<= beg (with-current-buffer box (point)) end)))))

(defun my/ws-trim-ok (beg end)
  "Чистить хвостовые пробелы после текста и всё после последнего непробельного символа файла. Строки из одних отступов в середине кода не трогать. Участок с кареткой peek не трогать."
  (and (my/peek--trim-ok beg end)
       (save-excursion
         (goto-char end)
         (skip-chars-forward " \t\r\n")
         (or (eobp)
             (progn
               (goto-char beg)
               (not (bolp)))))))

(after! ws-butler
  (setq ws-butler-trim-predicate #'my/ws-trim-ok))

(map! :leader :desc "Peek line" "o l" #'my/peek-line)
(map! :nvi "<f8>" #'my/peek-line)
(add-hook 'window-size-change-functions #'my/peek--on-resize)


