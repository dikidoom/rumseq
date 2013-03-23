#lang racket

;; midi ruckus
;; TODO
;; - scroll events ???
;; - bpm timer

(require (planet evhan/coremidi)
         ;; gl
         "gl-window.rkt"
         "gl-timer.rkt"
         ;; other
         "models.rkt"
         "editor.rkt"
         "board.rkt"
         "tracks.rkt"
         sgl)

;; ============================================================ Model
;; gl-areas
(define full-area (gl-area 0
                           0
                           (window-width main-window)
                           (window-height main-window)))
(define editor-area (gl-area (/ (window-width main-window) 2) ; bottom right
                             0
                             (/ (window-width main-window) 2)
                             (/ (window-height main-window) 2)))
(define board-area (gl-area 0                                 ; top
                            (/ (window-height main-window) 2)
                            (window-width main-window)
                            (/ (window-height main-window) 2)))
(define tracks-area (gl-area 0                                ; bottom left
                             0
                             (/ (window-width main-window) 2)
                             (/ (window-height main-window) 2)))

;; ============================================================ Function
(define (draw-views!)
  ;; clear all
  (apply gl-viewport (gl-area->list full-area))
  (apply gl-scissor (gl-area->list full-area))
  (gl-clear-color .96 .95 .71 1)
  (gl-clear 'color-buffer-bit 'depth-buffer-bit)
  ;;
  (draw-editor! editor-area)
  (draw-board! board-area)
  (draw-tracks! tracks-area))

;; TODO remove code duplication (w/ macro?)
(define (route-event e)
  (let ([x (send e get-x)]
        [y (send e get-y)])
    (when (gl-area-hit? editor-area x y)
      (let-values ([(x y) (gl-area-relative-event-position editor-area e)])
        (editor-event e x y)))
    (when (gl-area-hit? board-area x y)
      (let-values ([(x y) (gl-area-relative-event-position board-area e)])
        (board-event e x y)))
    (when (gl-area-hit? tracks-area x y)
      (let-values ([(x y) (gl-area-relative-event-position tracks-area e)])
        (tracks-event e x y)))))

;; TODO think about keyboard interface after first live test run
(define (route-char e) #f)

;; ============================================================ to go
(send canvas paint-with draw-views!)
(send canvas on-event-with route-event)
(send canvas on-char-with route-char)
(send timer start 16)
