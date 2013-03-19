#lang racket

(provide notes->events
         (rename-out [area-draw! draw-editor!])
         editor-event)

;; ============================================================
(require "models.rkt"
         "pattern.rkt"
         "gl-geometry.rkt"
         "gl-timer.rkt"
         sgl)

;; ============================================================ Model
(define pattern (new pattern%))

;; ============================================================ Functions
;; turn a list of '(start-step note-value length-in-steps) into events
(define (notes->events notes [step 500] [init '()])
  (match notes
    ['() (sort init
               (lambda (a b)
                 (if (= (event-time a)
                        (event-time b))
                     ;; at same time, note-off takes precedence
                     (if (and (not (note-event-on a))
                              (note-event-on b))
                         #t
                         #f)
                     ;; else
                     (< (event-time a)
                        (event-time b))))
               ;; #:key event-time
               )]
    [(cons head tail)
     (notes->events tail
                    step
                    (append (list (note-event (* step (car head)) ; time
                                              #t                  ; on
                                              (cadr head) ; note
                                              127)        ; velo
                                  (note-event (+ (* step (car head))
                                                 (* step (caddr head))) ; time
                                              #f          ; off
                                              (cadr head) ; note
                                              127))       ; velo
                            init))]))

;; helpers
(define (x->step x)
  (floor (/ x 1/16)))

(define (y->value y) ; range should be [72..36] inclusive
  (- 72
     (floor (/ y 1/37))))

(define (step->x wndw step)
  (* step (/ (gl-area-width wndw)
          16)))

(define (value->y wndw value)
  (* (- 72 value)
     (/ (gl-area-height wndw)
                37)))

;; ============================================================ GL
;; geometry
(define gl-note (quad))
(define white-key (quad #:color '(1 1 1 1)))
(define black-key (quad #:color '(.9 .9 .9 1)))
(define x-raster (quad #:color '(0 0 0 .1)))
(define klaviatur (reverse (for/list ([i 36])
                             (case (modulo i 12)
                               [(0 2 4 5 7 9 11) white-key]
                               [else black-key]))))

;; draw
(define (area-draw! wndw)
  ;; restrict drawing to WNDW area
  (apply gl-viewport (gl-area->list wndw))
  (apply gl-scissor (gl-area->list wndw))
  (gl-clear-color .8 .9 1 1)
  (gl-clear 'color-buffer-bit 'depth-buffer-bit)
  ;; projection
  (gl-matrix-mode 'projection)
  (gl-load-identity)
  (gl-ortho 0 (gl-area-width wndw)      ; x left, right
            (gl-area-height wndw) 0     ; y bottom, top
            0 10)                       ; z
  (gl-translate 0 0 -1)
  ;; model view
  (gl-matrix-mode 'modelview)
  (gl-load-identity)
  ;; 36 rows, that's 3 octaves of b/w keys
  ;; 1 row is left empty for the pattern-length handle
  (gl-push-matrix)
  (gl-polygon-mode 'front-and-back 'fill)
  (gl-scale (gl-area-width wndw)
            (/ (gl-area-height wndw) 37)
            1)
  (gl-translate 0 1 0)
  (for ([key klaviatur])
    (key)
    (gl-translate 0 1 0))
  (gl-pop-matrix)
  ;; draw raster for 16 steps
  (gl-polygon-mode 'front-and-back 'line)
  (gl-push-matrix)
  (gl-translate 0 -1 0)
  (gl-scale (/ (gl-area-width wndw) 16)
            (+ (gl-area-height wndw) 1)
            1)
  (for ([i 8])
    (x-raster)
    (gl-translate 2 0 0))
  (gl-pop-matrix)
  ;; draw notes on top
  (hash-for-each (send pattern get-notes)
                 (lambda (k v)
                   (gl-push-matrix)
                   (gl-translate (step->x wndw (note-step v))
                                 (value->y wndw (note-value v))
                                 0)
                   (gl-scale (/ (gl-area-width wndw) 16)
                             (/ (gl-area-height wndw) 37)
                             1)
                   ;; fill
                   (gl-polygon-mode 'front-and-back 'fill)
                   (gl-color 0 0 0 .5)
                   (gl-note)
                   ;; outline
                   (gl-polygon-mode 'front-and-back 'line)
                   (gl-color 0 0 0 1)
                   (gl-note)
                   (gl-pop-matrix))))

;; ============================================================ Events
(define (editor-event e x y)
  (let ([L-down? (send e button-down? 'left)]
        [L-up? (send e button-up? 'left)]
        [R-down? (send e button-down? 'right)])
    ;; add note
    (when L-down?
      (send pattern add-note
            (x->step x)
            (y->value y))
      ;(display (send pattern get-notes))
      ;(newline)
      )
    ;; remove note
    (when R-down?
      (send pattern remove-note
            (x->step x)
            (y->value y))
      ;(display (send pattern get-notes))
      ;(newline)
      )))

