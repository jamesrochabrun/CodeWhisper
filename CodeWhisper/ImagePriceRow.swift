//
//  ImagePriceRow.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/17/25.
//

import SwiftUI

struct ImagePriceRow: View {
  let imageName: String
  let price: Double

  var body: some View {
    HStack(spacing: 16) {
      // Leading image
      Image(systemName: imageName)
        .resizable()
        .scaledToFit()
        .frame(width: 60, height: 60)
        .foregroundStyle(.white)
        .padding(12)
        .background {
          RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.1))
        }

      Spacer()

      // Trailing price
      Text(formattedPrice)
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background {
      RoundedRectangle(cornerRadius: 16)
        .fill(.black.opacity(0.3))
        .stroke(.white.opacity(0.2), lineWidth: 1)
    }
  }

  private var formattedPrice: String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
  }
}

#Preview {
  ZStack {
    Color.black.ignoresSafeArea()

    VStack(spacing: 20) {
      ImagePriceRow(imageName: "cart.fill", price: 29.99)
      ImagePriceRow(imageName: "bag.fill", price: 149.99)
      ImagePriceRow(imageName: "gift.fill", price: 9.99)
    }
    .padding()
  }
}
