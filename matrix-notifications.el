;;; matrix-notifications.el --- Notifications support for matrix-client  -*- lexical-binding: t; -*-

;;; Commentary:

;; This file is not part of GNU Emacs.

;; This file is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation, either version 3 of the License,
;; or (at your option) any later version.
;;
;; This file is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

;;;; Requirements

(require 'notifications)

;;;; Variables

(defvar matrix-client-notify-hook
  '(matrix-client-notify)
  "List of functions called for events.
Each is called with the event-type and the event data.")

(defvar matrix-client-notifications nil
  "Alist of recent notifications mapping notification ID to related buffer.
Automatically trimmed to last 20 notifications.")

;;;; Functions

(defun matrix-client-notify (event-type data &rest rest)
  "Notify for an event of EVENT-TYPE with DATA."
  (let ((fn (intern-soft (concat "matrix-client-notify-" event-type))))
    (when (functionp fn)
      (apply #'funcall fn data rest))))

;; MAYBE: Use a macro to define the handlers, because they have to
;; define their arg lists in a certain way, and the macro would take
;; care of that automatically.

(cl-defun matrix-client-notify-m.room.message (data &key room &allow-other-keys)
  "Show notification for m.room.message events.
DATA should be the `data' variable from the
`defmatrix-client-handler'.  ROOM should be the room object."
  (pcase-let* (((map content sender event_id) data)
               ((map body) content)
               (display-name (matrix-client-displayname-from-user-id room sender))
               (buffer (oref room :buffer))
               (id (notifications-notify :title (format "<b>%s</b>" display-name)
                                         :body body
                                         :category "im.received"
                                         :timeout 5000
                                         :app-icon nil
                                         :actions '("default" "Show")
                                         :on-action #'matrix-client-notification-show)))
    (map-put matrix-client-notifications id (a-list 'buffer buffer
                                                    'event_id event_id))
    ;; Trim the list
    (setq matrix-client-notifications (-take 20 matrix-client-notifications))))

(defun matrix-client-notification-show (id key)
  "Show the buffer for a notification.
This function is called by `notifications-notify' when the user
activates a notification."
  (pcase-let* (((map (id notification)) matrix-client-notifications)
               ((map buffer event_id) notification)
               (window (get-buffer-window buffer)))
    (raise-frame)
    (if window
        (select-window window)
      (switch-to-buffer buffer))
    ;; Go to relevant event
    (or (cl-loop initially do (goto-char (point-max))
                 for value = (get-text-property (point) 'event_id)
                 thereis (equal value event_id)
                 while (when-let (pos (previous-single-property-change (point) 'event_id))
                         (goto-char pos)))
        ;; Not found: go to last line
        (goto-char (point-max)))))

;;;; Footer

(provide 'matrix-notifications)

;;; matrix-notifications.el ends here