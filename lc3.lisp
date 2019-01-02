(defparameter *memory* (make-array #xFFFF :element-type '(unsigned-byte 16)))
(defparameter *registers* (make-array 10 :element-type '(unsigned-byte 16))
  "R0-R7 are for general purpose
   R8 is the program counter
   R9 is the conditional")
(defparameter *flags* '(1 0 -1)
  "Sign of u16 written to the conditional register")
(defparameter *operations* '(br add ld st jsr and ldr str
                             rti not ldi sti jmp res lea trap
                             ret)
  "List of the operations")
(defparameter *spec*
  '((br (n 1 11) (z 1 10) (p 1 9) (pcoffset9 9 0))
    (add (dr 3 9) (sr1 3 6) (mode 1 5) (sr2 3 0) (imm5 5 0))
    (ld (dr 3 9) (pcoffset9 9 0))
    (st (sr 3 9) (pcoffset9 9 0))
    (jsr (mode 1 11) (pcoffset11 11 0) (baser 3 6))
    (and (dr 3 9) (sr1 3 6) (mode 1 5) (sr2 3 0) (imm5 5 0))
    (ldr (dr 3 9) (baser 3 6) (offset6 6 0))
    (str (sr 3 9) (baser 3 6) (offset6 6 0))
    (rti)
    (not (dr 3 9) (sr 3 6))
    (ldi (dr 3 9) (pcoffset9 9 0))
    (sti (sr 3 9) (pcoffset9 9 0))
    (jmp (baser 3 6))
    (res)
    (lea (dr 3 9) (pcoffset9 9 0))
    (trap (trapvect8 8 0))
    (ret))
  "Specification of an operation (name size position)")

(defun wrap (op)
  "Handle overflowing registers"
  (ldb (byte 16 0) op))

(defun u16->s16 (u16)
  "Convert uint16 to an integer"
  (if (= (ldb (byte 1 15) u16) 0)
      u16
      (logxor #xFFFF (1- (- u16)))))

(defun s16->u16 (int)
  "Convert integer to a uint16"
  (ldb (byte 16 0) int))

(defun sign-extend (uint bits)
  "Sign extend to 16 bits"
  (if (= (ldb (byte 1 (1- bits)) uint) 0)
      uint
      (1+ (logxor (ash #xFFFF (+ -16 bits)) (- uint)))))

(defun update-conditional-register (u16)
  "LC3 sets the conditional register R9 with u16's sign when it writes
   a register"
  (setf (aref *registers* 9) (position (signum (u16->int u16)) *flags*)))

(defun mem (addr)
  "Get block of memory at the address"
  (aref *memory* addr))

(defun (setf mem) (u16 addr)
  "Set the block of memory "
  (setf (aref *memory* addr) u16))

(defun reg (idx)
  "Get the register at the index"
  (aref *registers* idx))

(defun (setf reg) (u16 idx)
  "Write to registers with SETF form and update the conditional register"
  (prog1 (setf (aref *registers* idx) u16)
    (update-conditional-register u16)))

(defmacro with-spec (spec instr &body body)
  "Bind specification to instruction"
  `(let ,(loop for s in spec
               for name = (first s)
               for byte = (apply #'byte (rest s))
               collect (list name `(ldb ',byte ,instr)))
     ,@body))

;; ADD R7, R7, -1
;; #b0001 1111 1110 111
;; #x1FFF

;; ADD
(funcall #'(lambda (instr)
             (with-spec ((dr 3 9) (sr1 3 6) (mode 1 5) (sr2 3 0) (imm5 5 0)) instr
               (setf (reg dr)
                     (wrap (+ (reg sr1) (if (= mode 0) (reg sr2) (sign-extend imm5 5)))))
               (print (map 'vector #'u16->int *registers*))))
         #x1fe1)

;; LDI R7, 1
;; #b1010 1110 0000 0001
(with-spec ((dr 3 9) (pcoffset9 9 0)) #xae01
  (setf (reg dr) (mem (mem (+ (sign-extend pcoffset9 9) (reg 8)))))
  (print (map 'vector #'u16->int *registers*)))

;; AND R7, R1, R7
;; #b0101111001000111
(with-spec ((dr 3 9) (sr1 3 6) (mode 1 5) (sr2 3 0) (imm5 5 0))  #b0101111001000111
  (setf (reg dr)
        (logand (reg sr1) (if (= mode 0) (reg sr2) (sign-extend imm5 5))))
  (print (map 'vector #'u16->int *registers*)))
