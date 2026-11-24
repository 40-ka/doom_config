;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Основной конфиг разбит на файлы в lisp/. Здесь только базовые настройки Doom
;; и загрузчик. Порядок load! важен: my-editing раньше my-peek.

;; Некоторые модули используют это, чтобы узнать, кто вы (GPG, почта, шаблоны).
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Шрифты: см. `doom-font`, `doom-variable-pitch-font` и др. (C-h v doom-font).

;; Тема
(setq doom-theme 'doom-one)

;; Стиль номеров строк: t, nil или `relative`.
(setq display-line-numbers-type t)

;; Каталог org-файлов. Задаётся до загрузки org.
(setq org-directory "~/org/")

;; --- Подключение частей ---
(load! "lisp/my-lsp")
(load! "lisp/my-ui")
(load! "lisp/my-editing")
(load! "lisp/my-peek")
(load! "lisp/my-rust")
(load! "lisp/my-debug-tmp")
(load! "lisp/my-workspace")
(load! "lisp/my-folds")
