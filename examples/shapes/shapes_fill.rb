Shoes.app do
    shape do
        fill "blue"
        stroke "green" # Lines use stroke, not fill, for their color
        line 0,0, 100, 100

        fill "red"
        stroke "black" # Change the stroke back to black for the star
        star 23, 0, 6, 50, 25
    end
end
