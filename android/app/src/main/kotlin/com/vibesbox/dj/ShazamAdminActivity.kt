package com.vibesbox.dj

import android.os.Bundle
import android.graphics.Color
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.shazam.shazamkit.*

class ShazamAdminActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ein ganz einfaches Layout erstellen
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            setPadding(50, 50, 50, 50)
        }

        val titleText = TextView(this).apply {
            text = "DJ Admin: Shazam Check"
            setTextColor(Color.WHITE)
            textSize = 24f
        }

        val statusText = TextView(this).apply {
            text = "Warte auf Musikerkennung..."
            setTextColor(Color.LTGRAY)
            textSize = 18f
        }

        layout.addView(titleText)
        layout.addView(statusText)
        setContentView(layout)

        // HIER kommt später dein Developer Token rein!
    }
}