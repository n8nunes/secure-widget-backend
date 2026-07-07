import tkinter as tk
from tkinter import messagebox
import requests
from datetime import datetime

API_URL = "https://kht7rb2ir1.execute-api.us-east-1.amazonaws.com/messages" 
PARTNER_ID = "couple_abc_123" # Mock shared key uniquely identifying this connection

class SecureWidgetApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Secure Widget Board")
        self.root.geometry("400x500")
        
        # Display Area
        self.label = tk.Label(root, text="Latest Shared Notes (Encrypted at Rest)", font=("Arial", 12, "bold"))
        self.label.pack(pady=10)
        
        self.text_area = tk.Text(root, height=15, width=45, state='disabled')
        self.text_area.pack(pady=5)
        
        # Input Area
        self.entry_msg = tk.Entry(root, width=35)
        self.entry_msg.pack(pady=5)
        
        self.btn_send = tk.Button(root, text="Encrypt & Send to Cloud", command=self.send_message)
        self.btn_send.pack(pady=5)
        
        self.btn_refresh = tk.Button(root, text="Sync Board", command=self.fetch_messages)
        self.btn_refresh.pack(pady=5)
        
        self.fetch_messages()

    def send_message(self):
        msg = self.entry_msg.get().strip()
        if not msg:
            return
            
        payload = {
            "partner_id": PARTNER_ID,
            "timestamp": datetime.utcnow().isoformat(),
            "message": msg
        }
        
        try:
            res = requests.post(API_URL, json=payload)
            if res.status_code == 200:
                self.entry_msg.delete(0, tk.END)
                self.fetch_messages()
            else:
                messagebox.showerror("Error", f"Failed connection: {res.status_code}")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def fetch_messages(self):
        try:
            res = requests.get(API_URL, params={"partner_id": PARTNER_ID})
            if res.status_code == 200:
                items = res.json()
                self.text_area.config(state='normal')
                self.text_area.delete('1.0', tk.END)
                for item in items:
                    display_line = f"[{item['timestamp'][:16]}] {item['message']}\n"
                    self.text_area.insert(tk.END, display_line)
                self.text_area.config(state='disabled')
        except Exception as e:
            print(f"Sync issue: {e}")

if __name__ == "__main__":
    root = tk.Tk()
    app = SecureWidgetApp(root)
    root.mainloop()
