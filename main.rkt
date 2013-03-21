#lang racket

;; midi ruckus
;; TODO
;; - turn seq-timer into a step-timer that runs on steps (and not events),
;;   giving him the ability to run continuously (even on an empty list)
;; - eliminate the need to turn notes into note-events
;;   (even though this is more flexible, we just need a simpler step timer)
;; ...
;; - pattern collection
;; - tracks

(require (planet evhan/coremidi)
         ;; gl
         "gl-window.rkt"
         "gl-timer.rkt"
         ;; other
         "step-timer.rkt"
         "models.rkt"
         "editor.rkt"
         sgl)

;; ============================================================ Model
;; gl-areas
(define full-area (gl-area 0
                           0
                           (window-width main-window)
                           (window-height main-window)))
(define editor-area (gl-area (/ (window-width main-window) 2)
                             0
                             (/ (window-width main-window) 2)
                             (/ (window-height main-window) 2)))
;; wip timer/sequencer
(define seq-tick (new seq-timer%))

;; ============================================================ Function
(define (draw-views!)
  ;; clear all
  (apply gl-viewport (gl-area->list full-area))
  (apply gl-scissor (gl-area->list full-area))
  (gl-clear-color .96 .95 .71 1)
  (gl-clear 'color-buffer-bit 'depth-buffer-bit)
  ;;
  (draw-editor! editor-area))

(define (route-event e)
  (let ([x (send e get-x)]
        [y (send e get-y)])
    (when (gl-area-hit? editor-area x y)
      (let-values ([(x y) (gl-area-relative-event-position editor-area e)])
        (editor-event e x y)))))

(define (route-char e)
  (when (eq? (send e get-key-code)
             'release)    
    (send seq-tick use-notes (send pattern get-notes))
    (send seq-tick run)))

;; ============================================================ to go

;;(send seq-tick run)
;;(send seq-tick stop)
;;(send seq-tick close-midi)

(send canvas paint-with draw-views!)
(send canvas on-event-with route-event)
(send canvas on-char-with route-char)
;;
(send timer start 100)
